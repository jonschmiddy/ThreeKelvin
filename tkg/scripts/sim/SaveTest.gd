extends RefCounted

## Round-trip test for SaveGame and RunHistory.
##
##   godot --headless --path . -- savetest
##
## RUN THIS AFTER TOUCHING EITHER FILE. A save system fails silently by nature:
## a field someone forgot to serialise does not crash, it just comes back as a
## default, and the run continues around it looking almost right. The only way
## to catch that is to compare a run against itself.
##
## The method is deliberately blunt. Play a run forward into a messy state,
## fingerprint every field that matters, save, SCRAMBLE the live state so
## nothing can survive by accident, load, and fingerprint again. A field the
## save does not carry shows up as a mismatch rather than as a value that
## happened to already be right.
##
## Floats are compared to nine decimals. JSON does not round-trip doubles
## bit-exactly — see the note in SaveGame.save() — and nine decimals is three
## orders of magnitude stricter than anything the game can observe while still
## catching a genuinely wrong number.
##
## Loaded by path rather than by class_name, so a test costs nothing in the
## global class cache that every screen pays to look through.

var fails: int = 0

## The flight record the history checks write and clear. `RunHistory.path`
## points here while they run: clearing the real one deleted the player's whole
## record, and every unlock read from it, on every gate run.
const HISTORY := "user://savetest_history.json"

func check(what: String, a: Variant, b: Variant) -> void:
	if str(a) != str(b):
		fails += 1
		print("  MISMATCH %s\n    before: %s\n    after:  %s" % [what, a, b])

func fingerprint() -> Dictionary:
	var mods := func(list: Array) -> Array:
		var out: Array = []
		for raw in list:
			# A CRATE HAS AN ID AND A CELL AND NOTHING ELSE TO LOSE. The hold
			# carries materials now, and everything below this line is a
			# module's -- affixes, rarity, scrap value, mount. A material that
			# came back in the wrong place, or did not come back, still shows
			# up: those are the two fields it has.
			var mat := raw as MaterialData
			if mat != null:
				out.append("%s|h%d,%d" % [mat.id, mat.hold_at.x, mat.hold_at.y])
				continue
			var m := raw as ModuleData
			var af: Array = []
			for a in m.affixes:
				af.append(a.name)
			# WHERE it is, as well as what it is. Neither `mount` nor `hold_at`
			# was fingerprinted before, so this test passed on a save that
			# dropped every position — the loadout you built came back as the
			# same parts in a different arrangement and nothing here noticed.
			# That is the exact failure mode the scramble exists to catch.
			# (and the Lab's mark, VERSION 41: once per part, ever)
			out.append("%s|%d|%d|%s|m%d|h%d,%d|a%d" % [m.id, int(m.rarity),
				m.scrap_value, ",".join(af), m.mount, m.hold_at.x, m.hold_at.y,
				int(m.augmented)])
		return out
	var nodes: Array = []
	for e in Run.map:
		var n: MapGen.MapNode = e
		var shop: Array = []
		for m in n.shop:
			# The price is no longer ON the item — Market derives it from the
			# place and the part — so what has to survive is the part. The
			# quoted price is checked separately, below, against the market that
			# quotes it.
			shop.append("%s:%d" % [m.id, m.scrap_value])
		nodes.append("%d/%d/%d/%d/%d/%s/%s/%s/%.9f,%.9f/%.9f,%.9f/%s/%s/%s/%s/%s/%s/%s/%s/%s/%s/%s/%s/%s/%s/%s/%s" % [
			n.index, n.layer, n.row, n.rows_in_layer, n.danger,
			n.type, n.region, n.development,
			n.pos.x, n.pos.y, n.gal.x, n.gal.y,
			n.visited, n.cleared, n.eaten, n.inspected, n.fled,
			# A shelf that came back un-stocked re-rolls on the next visit, and a
			# market that came back un-saturated pays full price again. Both are
			# run marks and both are silent when lost.
			n.stocked, n.trades,
			Array(n.links), n.berths, shop,
			# What the system is offering. Rolled on arrival and fixed from then
			# on, so losing it across a save is a re-roll the player can force.
			n.foes, n.event_key,
			# WHICH options are used up, which is not the same question as
			# whether the system is finished. A system with three things to do
			# and one of them taken comes back with all three on offer if this
			# is lost, and `cleared` is false either way — so nothing else in
			# this fingerprint would notice.
			Array(n.taken),
			# AND WHAT THOSE THINGS ARE. `taken` above is a list of INDICES into
			# this one, so losing it does not merely re-roll the system -- it
			# renumbers what `taken` refers to, and option 2 of the new list is
			# marked spent because option 2 of the old one was. Nothing else here
			# would see it: `cleared` is false either way and the counts match.
			n.options,
			# WHETHER A FIGHT IS OWED HERE, and whether the roll has happened at
			# all. Never covered before this: the old `ambush` array was not in
			# the fingerprint either, so the save could have dropped it silently
			# for as long as it existed. Losing `ambush_pending` hands back a
			# system that quietly forgets it was about to jump you; losing
			# `ambush_rolled` re-rolls it on the next redraw until something
			# bites, which is worse.
			n.ambush_pending, n.ambush_rolled])
	# WHAT EACH SYSTEM'S CARDS SAY (VERSION 29): the bands, the walk-aways and
	# the outcome lines, by option index. Sorted, because a dictionary rebuilt
	# from two arrays need not hash in the order it was written.
	var cards: Array = []
	for e in Run.map:
		var n: MapGen.MapNode = e
		if n.results.is_empty() and n.left.is_empty() and n.said.is_empty():
			continue
		var bits: Array = []
		for k in n.results:
			bits.append("r%d=%s" % [int(k), String(n.results[k])])
		for k in n.left:
			bits.append("l%d=%s" % [int(k), String(n.left[k])])
		for k in n.said:
			bits.append("s%d=%s" % [int(k), "|".join(Array(n.said[k]))])
		bits.sort()
		cards.append("%d:%s" % [n.index, ";".join(bits)])
	return {
		cards = cards,
		# WHERE THE SHIP WAS LEFT, by system (VERSION 30): the world it orbits,
		# or the spot in open space it was flying at. Fixtured below, because
		# an empty record round-trips to empty whatever the save does.
		parked = _parked(),
		# AND EACH SYSTEM'S MAP CLOCK (VERSION 39), which those spots were left
		# at and a binary's suns turn by. Fixtured below, for the same reason.
		clocks = _clocks(),
		# THE GRADE'S PERKS ARE IN THE FINGERPRINT, and they have to be. The
		# loader does not call `at_tier`, so nothing regrants them on the way
		# back in — an S-tier ship that lost all three would come back with
		# every number here identical and three perks missing, and this test
		# would have said PASS. `perk_id` alone could not see it: that one is
		# the MANUFACTURER's and survives on the frame.
		hull = "%s|%d|%d|%d|%d|%d|%.9f|%d|%.9f|%d|%d|%d|%s|%s" % [
			Run.hull.name, Run.hull.tier, Run.hull.reactor, Run.hull.hand_size,
			Run.hull.max_hull, Run.hull.heat_cap, Run.hull.dodge,
			Run.hull.initiative, Run.hull.fuel_factor, Run.hull.weapon_slots,
			Run.hull.system_slots, Run.hull.utility_slots, Run.hull.perk_id,
			",".join(Array(Run.hull.tier_perks).map(func(x: StringName) -> String:
				return String(x)))],
		installed = mods.call(Run.installed),
		cargo = mods.call(Run.cargo),
		# THE PAD, WHICH IS NOT CARGO. It holds what came off a frame with
		# nowhere to go, and it is the newest thing in the file -- so it is
		# exactly the field a round-trip is worth running against. Fixtured
		# below, because an empty pad compares equal to a pad the writer forgot.
		pad = mods.call(Run.pad),
		# THE FRAME THE PAD CAME OFF (VERSION 36). The move draws its left half,
		# and the parts still bolted to it, from this; a save without it came
		# back with those parts drawn nowhere (Jon, Oct 23). Fixtured below by
		# the `transfer_to_hull` that fills the pad.
		old_hull = "%s|%d|%d|%s" % [Run.old_hull.name, Run.old_hull.tier,
			Run.old_hull.max_hull, Run.old_hull.perk_id] if Run.old_hull != null else "",
		econ = [Run.hp, Run.heat, Run.heat_cap_bonus, Run.credits,
			Run.fuel, Run.dross_count(), Run.whale_boon, Run.data],
		# SCIENCE (VERSION 41): the board as dealt, the steps bought on it and the
		# black box. Fixtured below with a board the seed would NOT deal, so a
		# save that dropped it and dealt again at the load shows here.
		science = [",".join(Array(Run.board).map(func(x: StringName) -> String: return String(x))),
			Array(Run.board_owned), Run.black_box_spent,
			",".join(Array(Run.owned_routines()).map(func(x: StringName) -> String: return String(x)))],
		# WHAT THE WORLD MAY HOLD (VERSION 34). Fixtured below to three, so a
		# load that fell back to the profile's own (Korvan alone here) shows.
		unlocked = ",".join(Array(Run.unlocked_manufacturers).map(
			func(m: StringName) -> String: return String(m))),
		# Every material, not just the one that used to be a field. Written as a
		# sorted list so a ledger that came back with the same counts under
		# String keys instead of StringName ones still compares equal — the
		# counts are what the run is made of, not how the dictionary hashes.
		materials = _materials(),
		# What the market here would quote for the shelf and the hold. Prices are
		# derived rather than stored, so this is not testing the save — it is
		# testing that everything the derivation reads (the node's axes, its
		# saturation, the part's roll, the hull perk) came back intact. A price
		# is the most sensitive reading of all of them at once.
		quotes = _quotes(),
		pos = [Run.at, Array(Run.trail), Run.jumps, Run.kills],
		# THE LEAD SHIP'S JUMPS (VERSION 40), which a co-op Custodian grows on.
		# Fixtured above your own, so a save that dropped it shows here.
		party = [Run.party_jumps, Run.custodian_jumps()],
		# The roamer. The move counter is a SEED SOURCE — Rng.derive keys each
		# hop on it — so losing it is not a cosmetic reset, it is a different
		# walk from the same position.
		hellbender = [Run.hellbender_at, Run.hellbender_hp, Run.hellbender_max,
			Run.hellbender_moves, Run.hellbender_ticks],
		galaxy = [Run.galaxy_kind, Run.galaxy_seed, "%.9f" % Run.galaxy_spin,
			Run.galaxy_name, Run.galaxy_title],
		gparams = _round_floats(Run.galaxy),
		nodes = nodes,
		# EACH SYSTEM'S SKY (VERSION 25, and two suns, 38): which options it may
		# hold, and for two suns its whole layout -- which world goes round which
		# star, every body's index. None of it was in the fingerprint before, so
		# a save that dropped `twin` would have come back with every pair a lone
		# sun and its parked ships and wrecks on other bodies, and this said PASS.
		sky = _sky(),
		derived = ["%.9f" % Run.jump_range(), Run.max_hp(), Run.heat_cap(),
			Run.reactor(), Run.hand_size(), Run.dissipation()],
	}

## A whole, valid board that is not `dealt`: in each branch, the routine after
## the one the deal dropped is dropped instead, the three left in rank order.
func _other_board(dealt: Array[StringName]) -> Array[StringName]:
	var out: Array[StringName] = []
	for b in DB.BRANCHES.size():
		var four := DB.routines_in(DB.BRANCHES[b])
		var gone := 0
		for k in four.size():
			if not dealt.has(four[k]):
				gone = k
		for k in four.size():
			if k != (gone + 1) % four.size():
				out.append(four[k])
	return out

## A saved run's parts with no Lab mark, the shape a 40 build wrote them in.
func _erase_marks(save: Dictionary) -> void:
	for key in ["installed", "cargo", "pad"]:
		for e in save.get(key, []):
			if typeof(e) == TYPE_DICTIONARY:
				(e as Dictionary).erase("augmented")

## A saved run with none of VERSION 41's keys.
func _erase_science(save: Dictionary) -> void:
	for key in ["data", "board", "board_owned", "black_box_spent"]:
		save.erase(key)
	_erase_marks(save)

func _write(save: Dictionary) -> void:
	var w := FileAccess.open(SaveGame.path, FileAccess.WRITE)
	if w != null:
		w.store_string(JSON.stringify(save, "", true, true))
		w.close()

func _read_save() -> Dictionary:
	var f := FileAccess.open(SaveGame.path, FileAccess.READ)
	var out: Dictionary = JSON.parse_string(f.get_as_text()) if f != null else {}
	if f != null:
		f.close()
	return out

## How many parts, fitted, in the hold or on the pad, carry the Lab's mark.
func _marked() -> int:
	var n := 0
	for list in [Run.installed, Run.cargo, Run.pad]:
		for raw in list:
			if raw is ModuleData and (raw as ModuleData).augmented:
				n += 1
	return n

## Every system's star, giant, pulsar neighbour and second sun, one string.
func _sky() -> String:
	var out: PackedStringArray = []
	var twins := 0
	for e in Run.map:
		var n: MapGen.MapNode = e
		out.append("%d%d%d%d" % [int(n.star), int(n.gas_giant), int(n.near_pulsar), int(n.twin)])
		twins += int(n.twin)
	# (and how many have two suns, so a run with none shows: about one in four
	# ordinary systems has them)
	return "%d:%s" % [twins, ",".join(out)]

## `Run.map_clock` as a stable string, sorted by system, to the nanosecond.
func _clocks() -> String:
	var keys: Array = Run.map_clock.keys()
	keys.sort()
	var parts: PackedStringArray = []
	for k in keys:
		parts.append("%d:%.9f" % [int(k), float(Run.map_clock[k])])
	return " ".join(parts)

## `SystemMapScreen._parked` as a stable string, sorted by system.
func _parked() -> String:
	var keys: Array = SystemMapScreen._parked.keys()
	keys.sort()
	var parts: PackedStringArray = []
	for k in keys:
		var e: Dictionary = SystemMapScreen._parked[k]
		var p: Vector2 = e.get("p", Vector2.ZERO)
		var v: Vector2 = e.get("v", Vector2.ZERO)
		parts.append("%d:at=%d p=%.6f,%.6f v=%.6f,%.6f head=%.6f mode=%s" % [int(k), int(e.get("at", -9)),
			p.x, p.y, v.x, v.y, float(e.get("head", 0.0)), String(e.get("mode", &""))])
		# (settled on a wide orbit: round what, how wide, which way)
		if e.has("r"):
			parts.append("%d:cen=%d r=%.6f sense=%.1f" % [int(k), int(e.get("cen", -99)), float(e.r), float(e.get("sense", 0.0))])
	return " ".join(parts)

## What you are carrying, as a stable string. Off the HOLD, because that is the
## only store now -- see `RunState.material`. Counted per catalogue id rather
## than listed per instance, so a round trip that kept every crate but shuffled
## their cells still compares equal: this probe is about survival, and
## `-- holdtest` is about placement.
func _materials() -> String:
	var seen: Dictionary = {}
	for raw in Run.cargo:
		var m := raw as MaterialData
		if m != null:
			seen[m.id] = int(seen.get(m.id, 0)) + 1
	var keys: Array = seen.keys()
	keys.sort()
	var parts: Array[String] = []
	for k in keys:
		parts.append("%s=%d" % [str(k), int(seen[k])])
	return ", ".join(parts)


func _quotes() -> String:
	var n: MapGen.MapNode = Run.node_at()
	var parts: PackedStringArray = ["repair=%.4f" % Market.repair_rate(n),
		"refuel=%d" % Market.refuel_price(n)]
	for m in n.shop:
		parts.append("ask:%s=%d" % [m.id, Market.ask(n, m)])
	# PARTS QUOTE, MATERIALS PRICE. `bid` and `melt` are a module's two numbers
	# -- what a counter offers and what a furnace pays -- and a material has
	# neither. It has one flat value and the row below already quotes every one
	# of those, so a crate in the hold contributes its identity and nothing else.
	for raw in Run.cargo:
		var m := raw as ModuleData
		if m == null:
			parts.append("hold:%s" % (raw as MaterialData).id)
			continue
		parts.append("bid:%s=%d/melt=%d" % [m.id, Market.bid(n, m), Market.melt(m)])
	for d in MaterialTable.all():
		parts.append("mat:%s=%d" % [d.id, Market.material_price(n, d.id)])
	return " ".join(parts)

## Nine decimals, matching the fingerprint's float format.
func _round_floats(d: Dictionary) -> String:
	var keys: Array = d.keys()
	keys.sort()
	var parts: PackedStringArray = []
	for k in keys:
		var v: Variant = d[k]
		parts.append("%s=%s" % [k, ("%.9f" % (v as float)) if typeof(v) == TYPE_FLOAT else str(v)])
	return " ".join(parts)

func run() -> void:
	print("\n=== SAVE ROUND-TRIP ===")
	SaveGame.clear()
	Run.start_new_run()

	# Push the run somewhere non-trivial: move, spend, take damage, pick up
	# loot, clear nodes, and roll a station's stock.
	for i in 6:
		var opts := Run.in_range()
		var pick: MapGen.MapNode = null
		for n in opts:
			if Run.can_jump_to(n):
				pick = n
				break
		if pick == null:
			break
		Run.jump_to(pick.index)
		Run.node_at().cleared = (i % 2 == 0)
		# One option consumed at a system that is NOT finished. The case a
		# single boolean cannot hold, and therefore the case a save written
		# against the boolean silently drops.
		if i % 3 == 1:
			Run.node_at().taken = PackedInt32Array([2])
		Run.node_at().inspected = (i % 3 == 0)
		Run.node_at().fled = (i % 4 == 0)
	Run.hp = maxi(1, Run.hp - 9)
	Run.heat = 5
	Run.heat_cap_bonus = 2
	# TWO THINGS ON THE DOCK. `pad` is populated by a hull swap that overflowed,
	# and no probe in this file buys a hull -- so without a fixture the round
	# trip would be checking that an empty array survives being written as an
	# empty array. Placed by hand rather than through `transfer_to_hull` for the
	# same reason the materials above are: a probe wants the STATE, not the
	# journey that usually produces it.
	for stranded in [&"plate", &"coolant"]:
		var sm := (DB.modules[stranded] as ModuleData).duplicate(true) as ModuleData
		sm.hold_at = -Vector2i.ONE
		Run.pad.append(sm)
	# LOUD IF THE FIXTURE STOPS FIXTURING. Both ids are read straight out of the
	# catalogue with no `has` guard, so a rename fails here rather than seeding
	# nothing and leaving the probe comparing an empty array to an empty array.
	assert(Run.pad.size() == 2)
	Run.credits += 37
	# All three materials, not just the one that used to be a bare field. A
	# ledger keyed by StringName and reloaded from JSON's String keys is exactly
	# the kind of thing that comes back looking right and compares wrong.
	# ABOARD, because the probe is asking whether a save keeps what you are
	# CARRYING. `add_material` leaves them in the sector, which is the right
	# answer for a reward and the wrong one for a fixture.
	for seeded in [&"exotic", &"exotic", &"exotic", &"relic", &"relic"]:
		Run.stow(MaterialData.of(MaterialTable.by_id(seeded)))
	Run.dross = [&"slag", &"arcfault"] as Array[StringName]
	Run.whale_boon = true
	Run.unlocked_manufacturers = [&"korvan", &"solari", &"probate"] as Array[StringName]
	Run.kills = 4
	# a co-op dive's lead ship, ahead of this one
	Run.party_jumps = Run.jumps + 9
	for i in 4:
		Run.place_in_hold(LootGen.roll_module(3 + i, &"", true))
	# THE FIRST PART, not the first thing in the hold. Materials are stowed
	# above, so `cargo[0]` is a crate of exotic now and nothing installs a crate.
	for raw in Run.cargo:
		var part := raw as ModuleData
		if part != null:
			Run.install_module(part)
			break
	Run.found_hull = LootGen.roll_hull(4)
	Run.transfer_to_hull(LootGen.roll_hull(5))
	# ARRANGE the hold, do not just fill it.
	#
	# Everything above lands by first fit, and the loader re-packs anything that
	# comes back without a position by running that same first fit — so a save
	# that dropped every cell still reproduced the identical layout and this test
	# passed. Verified by deliberately breaking the writer: it did not fail.
	#
	# Moving one part somewhere first fit would never have put it is what makes
	# the saved value load-bearing, which is what a player rearranging their hold
	# does every time they touch it.
	if not Run.cargo.is_empty():
		# `HoldItem`: the last thing in the hold may be a crate, and what this
		# block is proving is that a POSITION survives a round trip, which is
		# true of anything that occupies cells.
		var last: HoldItem = Run.cargo[Run.cargo.size() - 1]
		var home := last.hold_at
		var g := Run.hold_grid()
		for y in range(g.y - 1, -1, -1):
			for x in range(g.x - 1, -1, -1):
				var at := Vector2i(x, y)
				if at != home and Run.can_place(last, at):
					last.hold_at = at
					break
			if last.hold_at != home:
				break
	# A station with stock already rolled, and a hull on the pad.
	var st: MapGen.MapNode = Run.map[Run.at]
	st.shop = [LootGen.roll_module(2), LootGen.roll_module(4, &"", true)]
	st.shop_hull = LootGen.roll_hull(3)
	# A shelf that has been rolled and a market that has been sold into. Both are
	# silent when lost: a station that comes back un-stocked re-rolls its whole
	# inventory on the next visit, which is the exploit this run of work closed.
	st.stocked = true
	st.trades = 3
	# A second market, saturated differently, so a single value restored to every
	# node would still show up as a mismatch.
	for e in Run.map:
		var n2: MapGen.MapNode = e
		if n2.index % 7 == 0:
			n2.stocked = true
			n2.trades = n2.index % 5
	# A fight and a hail with their rolls already made. These are the fields that
	# decide what is waiting at a system, so a save that forgets them hands the
	# player a fresh draw every time they quit and resume.
	for e in Run.map:
		var n: MapGen.MapNode = e
		if n.type == MapGen.NodeType.SYSTEM and not n.cleared and n.foes.is_empty():
			n.foes = [&"cutter", &"lancer"]
		elif n.type == MapGen.NodeType.SYSTEM and not n.cleared and n.event_key.is_empty():
			n.event_key = "Dead station"
		# AND WHAT THE SYSTEM IS OFFERING, rolled the way arriving would roll it.
		#
		# Without this every node's list is empty, empty round-trips to empty,
		# and the fingerprint above proves nothing -- verified by deleting the
		# field from `_node_to` and watching the test still pass.
		if n.type != MapGen.NodeType.STATION and n.type != MapGen.NodeType.CORE \
				and n.options.is_empty():
			n.options = OptionTable.roll_for(n)
		# A fight owed on arrival, and a roll already made. Both have to be on
		# some nodes and not others, or an all-false field round-trips to
		# all-false whatever the save does.
		if n.type != MapGen.NodeType.SYSTEM and n.type != MapGen.NodeType.CORE:
			n.ambush_rolled = n.index % 2 == 0
			n.ambush_pending = n.index % 4 == 0

	# The hellbender mid-chase: hurt, mid-stride, and having eaten something — the
	# state a resume has to hand back exactly, or the pursuit resets.
	if Run.hellbender_alive():
		Run.hellbender_hp = maxi(1, Run.hellbender_max / 3)
		Run.hellbender_ticks = 2
	for e in Run.map:
		var nd: MapGen.MapNode = e
		if nd.type == MapGen.NodeType.SYSTEM and not nd.cleared:
			# The same three writes hellbender_land() makes, because a cleared node
			# with an empty `taken` is backfilled on load and would mismatch.
			nd.cleared = true
			nd.eaten = true
			nd.taken.append(MapGen.OPTION_WHOLE)
			break

	# A SYSTEM HALF WORKED THROUGH, as its cards show it: option 0 taken with a
	# band and a line of what came of it, option 1 walked away from. Written the
	# way `OptionResolve.take` writes them. Without a fixture both maps are empty
	# everywhere and round-trip to empty whatever the save does.
	var card_node := -1
	for e in Run.map:
		var nc: MapGen.MapNode = e
		if nc.type == MapGen.NodeType.SYSTEM and not nc.cleared and nc.options.size() >= 2:
			card_node = nc.index
			nc.taken.append(MapGen.OPTION_SITE)
			nc.results[0] = MapGen.R_SUCCESS
			OptionResolve._remember(nc, 0, {"stay": false, "res": {"text": "You put sixteen units across. Nobody aboard sounds surprised."},
				"bill": EncounterDrawer.bill_rows({"fuel": 40}, {"fuel": 24})})
			OptionResolve._remember(nc, 1, {"stay": true, "res": {"text": "You let it tumble on. The transponder is still going."}, "bill": []})
			break
	if card_node < 0:
		print("  FAIL: no system to hold the card fixture"); fails += 1
	# AND A READING TAKEN IN ANOTHER, its line with DATA in it (science, Jon's
	# 2A, Nov 4): DATA is the bill's fifth row, last, so the line reads
	# "FUEL -2 · DATA +5" and the card above, which paid none, reads as it did.
	var read_node := -1
	for e in Run.map:
		var nr: MapGen.MapNode = e
		if nr.type == MapGen.NodeType.SYSTEM and not nr.cleared and nr.options.size() >= 1 \
				and nr.index != card_node and nr.index != Run.at:
			read_node = nr.index
			nr.taken.append(MapGen.OPTION_SITE)
			nr.results[0] = MapGen.R_SUCCESS
			OptionResolve._remember(nr, 0, {"stay": false, "res": {"text": "You took the readings and climbed back out. The film can wait."},
				"bill": EncounterDrawer.bill_rows({"fuel": 40, "data": 16}, {"fuel": 38, "data": 21})})
			break
	if read_node < 0:
		print("  FAIL: no system to hold the reading's card fixture"); fails += 1

	# PARKED IN TWO SYSTEMS, two ways: in orbit of a world (the map's rail),
	# and stopped in open space where it was flown by hand. Written the way the
	# map writes them (`SystemMapScreen._keep_ship`).
	SystemMapScreen._parked.clear()
	SystemMapScreen._parked[Run.at] = {"at": 1, "p": Vector2(212.5, -40.25), "v": Vector2(0.75, -1.5), "head": 2.25, "mode": &"rail"}
	SystemMapScreen._parked[card_node if card_node >= 0 else 0] = {"at": -9, "p": Vector2(-318.125, 96.5), "v": Vector2.ZERO, "head": -0.625, "mode": &"free"}
	# AND IN STAR B'S CLOSE ORBIT, in a system with two suns (ruling 20): a
	# system that may have them made a twin, as a harness may (`n.twin`), so the
	# case is there whatever this run rolled. `at` is SystemLayout.STAR_B, -4.
	var twin_node := -1
	for e in Run.map:
		var nt: MapGen.MapNode = e
		if MapGen.twin_ok(nt) and nt.index != Run.at and nt.index != card_node:
			twin_node = nt.index
			nt.twin = true
			SystemMapScreen._parked[nt.index] = {"at": SystemLayout.STAR_B, "p": Vector2(402.5, -61.75), "v": Vector2(-12.5, 30.25), "head": 1.125, "mode": &"rail"}
			break
	if twin_node < 0:
		print("  FAIL: no system that may have two suns, for the star B fixture"); fails += 1
	# AND SETTLED ON A WIDE ORBIT ROUND STAR B, in another of them: round what,
	# how wide and which way (`cen`, `r`, `sense`), so the map puts it back on
	# that orbit and not on the arrival orbit's radius (the saves review, Oct 31)
	var wide_node := -1
	for e in Run.map:
		var nw: MapGen.MapNode = e
		if MapGen.twin_ok(nw) and nw.index != Run.at and nw.index != card_node and nw.index != twin_node:
			wide_node = nw.index
			nw.twin = true
			SystemMapScreen._parked[nw.index] = {"at": -9, "p": Vector2(361.25, -88.5), "v": Vector2(-20.5, 14.25), "head": 0.75, "mode": &"free",
				"cen": SystemLayout.STAR_B, "r": 69.375, "sense": -1.0}
			break
	if wide_node < 0:
		print("  FAIL: no second system that may have two suns, for the wide orbit fixture"); fails += 1
	# EACH SYSTEM'S MAP CLOCK (VERSION 39), written the way the map writes it
	# (`SystemMapScreen._keep_ship`): the two binaries' suns turned to where
	# those spots were left, and one system at a clock with no ship kept
	Run.map_clock.clear()
	Run.map_clock[Run.at] = 37.6875
	var twin_clock := 412.375
	if twin_node >= 0:
		# (a quarter of its pair's lap, whatever kind it is: a close pair laps in
		# 6 to 7 minutes, so a fixed time could find it nearly back where it began)
		var lt0 := SystemLayout.of(Run.map[twin_node])
		if lt0.pair_n > 0.0:
			twin_clock = 0.25 * TAU / lt0.pair_n
		Run.map_clock[twin_node] = twin_clock
	if wide_node >= 0:
		Run.map_clock[wide_node] = 1033.515625
	Run.map_clock[card_node if card_node >= 0 else 0] = 0.25

	# SCIENCE (VERSION 41): DATA in hand, FRAME two steps in and DRIVE one, the
	# black box spent, and a board the seed would not deal (each branch drops a
	# different routine), so a save that kept no board and dealt one again at the
	# load cannot come back equal. And the Lab's mark on a part in each place a
	# part can be: fitted, in the hold, on the pad.
	Run.data = 37
	var dealt := Run.board.duplicate()
	Run.board = _other_board(dealt)
	Run.board_owned = PackedInt32Array([2, 0, 1])
	Run.black_box_spent = true
	check("the fixture's board is not the one the seed deals", true, Run.board != dealt)
	# (the hull swap above left everything on the pad, with nothing fitted and
	# no part in the hold, so one goes onto the new hull and one into its hold:
	# a mark the save dropped from either place would round-trip unseen)
	var off_pad: Array[ModuleData] = []
	for raw in Run.pad:
		if raw is ModuleData:
			off_pad.append(raw as ModuleData)
	if off_pad.size() >= 3:
		Run.install_module(off_pad[0])
		Run.place_in_hold(off_pad[1])
	var marked := 0
	for list in [Run.installed, Run.cargo, Run.pad]:
		for raw in list:
			var mm := raw as ModuleData
			if mm != null:
				mm.augmented = true
				marked += 1
				break
	check("an augmented part fitted, in the hold and on the pad", 3, marked)

	var before := fingerprint()
	var jumps_before := Run.jumps

	SaveGame.save()
	if not SaveGame.has_save():
		print("  FAIL: no save written"); fails += 1; return

	var sum := SaveGame.summary()
	check("summary.jumps", jumps_before, int(sum.jumps))
	check("summary.hp", Run.hp, int(sum.hp))
	check("summary.system", MapGen.star_name(Run.node_at()), str(sum.system))
	if not SaveGame.has_save():
		print("  FAIL: summary() consumed the save"); fails += 1

	# Scramble everything the load has to restore, so a field the save forgot
	# shows up as a mismatch rather than as a value that happened to survive.
	Run.hp = 1
	Run.heat = 99
	Run.heat_cap_bonus = 0
	Run.credits = 0
	Run.fuel = 0
	Run.dross = [] as Array[StringName]
	Run.whale_boon = false
	Run.data = 0
	Run.board = [] as Array[StringName]
	Run.board_owned = PackedInt32Array([0, 0, 0])
	Run.black_box_spent = false
	Run.unlocked_manufacturers = [&"calyx"] as Array[StringName]
	Run.jumps = 0
	Run.party_jumps = 0
	Run.custodian_seen = 0
	Run.kills = 0
	Run.at = 0
	Run.trail = PackedInt32Array()
	Run.hellbender_at = -1
	Run.hellbender_hp = 0
	Run.hellbender_max = 0
	Run.hellbender_moves = 0
	Run.hellbender_ticks = 0
	Run.map = []
	Run.installed = []
	Run.cargo = []
	Run.hull = (DB.hull_frames[0] as HullData).duplicate(true) as HullData
	Run.found_hull = null
	Run.old_hull = (DB.hull_frames[2] as HullData).duplicate(true) as HullData
	Run.galaxy_kind = 0
	Run.galaxy = GalaxyGen.params(0).duplicate()
	Run.galaxy_seed = 0
	Run.galaxy_spin = 0.0
	Run.galaxy_name = ""
	Run.galaxy_title = ""
	Run._range_cache.clear()
	SystemMapScreen._parked = {3: {"at": 0, "p": Vector2.ONE, "v": Vector2.ZERO, "head": 0.0, "mode": &"rail"}}
	Run.map_clock = {3: 9.0, 5: 99.5}

	if not SaveGame.load_into_run():
		print("  FAIL: load_into_run() returned false"); fails += 1; return
	if SaveGame.has_save():
		print("  FAIL: save survived the load — suspend model broken"); fails += 1

	var after := fingerprint()
	for k in before.keys():
		if k == "nodes":
			check("node count", (before[k] as Array).size(), (after[k] as Array).size())
			var a: Array = before[k]
			var b: Array = after[k]
			for i in mini(a.size(), b.size()):
				check("node[%d]" % i, a[i], b[i])
		else:
			check(k, before[k], after[k])

	# THE SHIP IN STAR B'S CLOSE ORBIT, read back: its system still has two suns,
	# the row is at star B, and that is where the run says the ship is there
	if twin_node >= 0:
		var nt2: MapGen.MapNode = Run.map[twin_node]
		check("star B's system has two suns after reload", true, nt2.twin and SystemLayout.of(nt2).twin)
		check("the ship parked in star B's close orbit", SystemLayout.STAR_B, int(SystemMapScreen._parked.get(twin_node, {}).get("at", -9)))
		check("and the run's place for it there", SystemLayout.STAR_B, Run.site_here(nt2))
		print("  twin cases: 1 (a ship parked at star B of %s)" % MapGen.star_name(nt2))
	if wide_node >= 0:
		var ew: Dictionary = SystemMapScreen._parked.get(wide_node, {})
		check("the ship settled round star B, read back round it, as wide, the same way", "-4 69.375 -1",
			"%d %.3f %d" % [int(ew.get("cen", -99)), float(ew.get("r", -1.0)), int(ew.get("sense", 0.0))])
		print("  twin cases: 2 (and one settled round star B of %s)" % MapGen.star_name(Run.map[wide_node]))
	# THE SUNS WHERE THEY WERE LEFT: the binary's clock read back, so its map
	# opens with the pair at the angle the parked spot was made at
	if twin_node >= 0:
		check("star B's system's map clock read back", "%.9f" % twin_clock, "%.9f" % Run.map_t(twin_node))
		var lt := SystemLayout.of(Run.map[twin_node])
		check("and its suns there turned off where they were laid out", true,
			lt.pair_n == 0.0 or lt.star_pos(SystemLayout.STAR_B, Run.map_t(twin_node)).distance_to(lt.star2_at0) > 1.0)
	check("a system never opened: map clock 0", 0.0, Run.map_t(Run.map.size() + 7))

	# AND THE CARDS READ IT BACK: the walk-away is still LEFT ALONE after the
	# reload (Jon: "left alone should survive a reload"), the taken one keeps its
	# band and its line, and taking the walked-away one afterwards clears it.
	if card_node >= 0:
		var nl: MapGen.MapNode = Run.map[card_node]
		check("card 1 after reload", "left", String(EncounterDrawer.option_state(nl, 1).kind))
		check("card 0 after reload", "band SUCCESS", "%s %s" % [EncounterDrawer.option_state(nl, 0).kind, EncounterDrawer.option_state(nl, 0).word])
		check("card 0's line after reload", "FUEL -16|You put sixteen units across.", "|".join(Array(nl.said.get(0, []))))
		OptionResolve._remember(nl, 1, {"stay": false, "res": {"text": "Taken after all."}, "bill": []})
		nl.taken.append(MapGen.OPTION_SITE + 1)
		check("card 1 once taken", "band", String(EncounterDrawer.option_state(nl, 1).kind))
		check("card 1 no longer left alone", false, nl.left.has(1))
	if read_node >= 0:
		check("the reading's line after reload, DATA and all", "FUEL -2 · DATA +5|You took the readings and climbed back out.",
			"|".join(Array((Run.map[read_node] as MapGen.MapNode).said.get(0, []))))

	# Galaxy params must come back with their ORIGINAL TYPES, not as the floats
	# JSON would hand back. `arms` is a loop count.
	check("typeof(arms)", typeof(GalaxyGen.params(Run.galaxy_kind).arms),
		typeof(Run.galaxy.arms))
	check("typeof(bar)", TYPE_FLOAT, typeof(Run.galaxy.bar))

	print("=== %s (%d mismatches) ===\n" % ["PASS" if fails == 0 else "FAIL", fails])

## A file from the version before this one is REFUSED, and a flight record
## from before a rename is still READ. The two rules look contradictory and
## are not, which is exactly why neither had a test.
##
## Both were broken at once by the vocabulary pass: it renamed keys in three
## serialisers and raised none of the numbers guarding them. Nothing failed.
## A save stamped 10 was read with keys that were not in it and came back as a
## galaxy with no berths and no contracts, and every past run stopped
## unlocking its manufacturer because the record said `chassis_maker` and the
## reader had moved on to `chassis_manufacturer`.
##
## THE SAVE DISCARDS AND THE RECORD DOES NOT, because they are different
## kinds of file. A suspend save is one run in progress; refusing it costs
## that run and protects everything else. The flight record is append-only
## and holds every run ever flown, so refusing it deletes the lot -- which is
## why RunHistory keeps VERSION at 1 and reads the old key instead.
func run_version_test() -> void:
	print("=== VERSION GATES ===")
	var fails_before := fails

	# SAVE & EXIT MID-FIGHT: the fight is noted on the save and comes back on
	# load, so CONTINUE can start it over. And a save without one brings none.
	Run.start_new_run(&"korvan", 1)
	SaveGame.save()
	var fight := {ids = ["raider", "raider"], clears = true, share = true}
	SaveGame.mark_fight(fight)
	Router.fight_on_resume = {}
	SaveGame.load_into_run()
	check("a fight saved out of comes back on load", str(fight.ids),
		str(Router.fight_on_resume.get("ids", [])))
	SaveGame.save()
	SaveGame.load_into_run()
	check("and an ordinary save brings no fight with it", true, Router.fight_on_resume.is_empty())
	Router.fight_on_resume = {}

	# THE MAP CLOCKS (VERSION 39): this build writes 39, and a 38 save -- this
	# shape without `clocks` -- loads with every system at t 0, its suns where
	# they were laid out, which is the picture a 38 build drew on every visit
	Run.start_new_run(&"korvan", 1)
	Run.map_clock[Run.at] = 512.5
	SystemMapScreen._parked[Run.at] = {"at": -9, "p": Vector2(140.5, -60.25), "v": Vector2.ZERO, "head": 0.5, "mode": &"free"}
	SaveGame.save()
	var f38 := FileAccess.open(SaveGame.path, FileAccess.READ)
	var save38: Dictionary = JSON.parse_string(f38.get_as_text()) if f38 != null else {}
	if f38 != null:
		f38.close()
	check("a 39 save carries its map clocks", 1, (save38.get("clocks", []) as Array).size())
	save38["version"] = 38
	save38.erase("clocks")
	save38.erase("party_jumps")
	_erase_science(save38)
	var w38 := FileAccess.open(SaveGame.path, FileAccess.WRITE)
	if w38 != null:
		w38.store_string(JSON.stringify(save38, "", true, true))
		w38.close()
	Run.map_clock[Run.at] = 77.0
	check("a save of version 38 (no map clocks) still loads", true, SaveGame.load_into_run())
	check("and with no map clocks: every system at t 0", "0 0.000", "%d %.3f" % [Run.map_clock.size(), Run.map_t(Run.at)])
	check("and its parked spot where it was made", "-9 140.50 -60.25", "%d %.2f %.2f" % [int(SystemMapScreen._parked.get(Run.at, {}).get("at", 0)),
		(SystemMapScreen._parked.get(Run.at, {}).get("p", Vector2.ZERO) as Vector2).x, (SystemMapScreen._parked.get(Run.at, {}).get("p", Vector2.ZERO) as Vector2).y])
	# (and the rows' reader drops what it cannot place: a system off this map,
	# a clock that is not a time)
	check("clock rows off the map or not a time are dropped", "1 2.500",
		"%d %.3f" % [SaveGame._clocks_from([{index = 2, t = 2.5}, {index = 9999, t = 1.0}, {index = 3, t = -4.0}, {index = 4, t = INF}, "x"], 100).size(),
		float(SaveGame._clocks_from([{index = 2, t = 2.5}], 100).get(2, 0.0))])
	# A NEW RUN STARTS EVERY CLOCK AGAIN: its systems are not the last run's
	Run.map_clock[Run.at] = 3.0
	Run.start_new_run(&"korvan", 1)
	check("a new run keeps no map clock of the last", 0, Run.map_clock.size())

	# THE LEAD SHIP'S JUMPS (VERSION 40, Jon, Nov 4). The Custodian grows on `Run.custodian_jumps()`, the lead ship's jumps in co-op,
	# so they are saved; a 39 save has none and grows on its own jumps, as a 39
	# build did. The load counts the count as seen, so CONTINUE replays no
	# arrival; a new run clears it.
	Run.start_new_run(&"korvan", 1)
	Run.jumps = 7
	Run.party_jumps = 21
	Run.custodian_seen = 3
	SaveGame.save()
	var f39 := FileAccess.open(SaveGame.path, FileAccess.READ)
	var save39: Dictionary = JSON.parse_string(f39.get_as_text()) if f39 != null else {}
	if f39 != null:
		f39.close()
	check("a 40 save carries the lead ship's jumps", 21, int(save39.get("party_jumps", -1)))
	Run.party_jumps = 0
	Run.custodian_seen = 0
	SaveGame.load_into_run()
	check("and loads them back, its count the lead ship's and seen (jumps, party, count, seen)",
		"7 21 21 21", "%d %d %d %d" % [Run.jumps, Run.party_jumps, Run.custodian_jumps(), Run.custodian_seen])
	save39["version"] = 39
	save39.erase("party_jumps")
	_erase_science(save39)
	var w39 := FileAccess.open(SaveGame.path, FileAccess.WRITE)
	if w39 != null:
		w39.store_string(JSON.stringify(save39, "", true, true))
		w39.close()
	Run.party_jumps = 30
	check("a save of version 39 (no lead ship's jumps) still loads", true, SaveGame.load_into_run())
	check("and its count is its own jumps, seen (jumps, party, count, seen)", "7 0 7 7",
		"%d %d %d %d" % [Run.jumps, Run.party_jumps, Run.custodian_jumps(), Run.custodian_seen])
	save39["version"] = 40
	save39["party_jumps"] = -12
	w39 = FileAccess.open(SaveGame.path, FileAccess.WRITE)
	if w39 != null:
		w39.store_string(JSON.stringify(save39, "", true, true))
		w39.close()
	SaveGame.load_into_run()
	check("a negative one reads 0", 0, Run.party_jumps)
	Run.party_jumps = 18
	Run.start_new_run(&"korvan", 1)
	check("a new run clears the lead ship's jumps and the badge's seen count", "0 0",
		"%d %d" % [Run.party_jumps, Run.custodian_seen])

	_science_versions()

	# THE ONE BEFORE STILL READS (VERSION 30): a 29 save is this shape without
	# `parked`, and loads with every ship at its system's edge, as it did.
	Run.start_new_run(&"korvan", 1)
	SystemMapScreen._parked[Run.at] = {"at": 0, "p": Vector2.ZERO, "v": Vector2.ZERO, "head": 0.0, "mode": &"rail"}
	SaveGame.save()
	var fr := FileAccess.open(SaveGame.path, FileAccess.READ)
	var old_save: Dictionary = JSON.parse_string(fr.get_as_text()) if fr != null else {}
	if fr != null:
		fr.close()
	old_save["version"] = SaveGame.OLDEST_READ
	old_save.erase("parked")
	old_save.erase("clocks")
	old_save.erase("unlocked")
	old_save.erase("party_jumps")
	_erase_science(old_save)
	# (and from before two suns, VERSION 38: no node says `twin`)
	var twins_written := 0
	for nd in old_save.get("map", []):
		if typeof(nd) == TYPE_DICTIONARY:
			if bool((nd as Dictionary).get("twin", false)):
				twins_written += 1
			(nd as Dictionary).erase("twin")
	Run.unlocked_manufacturers = [&"korvan"] as Array[StringName]
	var fo := FileAccess.open(SaveGame.path, FileAccess.WRITE)
	if fo != null:
		fo.store_string(JSON.stringify(old_save, "", true, true))
		fo.close()
	check("a save of version %d (no parked spot) still loads" % SaveGame.OLDEST_READ, true, SaveGame.load_into_run())
	check("and with no parked spot: every ship at its edge", 0, SystemMapScreen._parked.size())
	var twins_read := 0
	for e2 in Run.map:
		if (e2 as MapGen.MapNode).twin:
			twins_read += 1
	check("and from before two suns (%d written as twins): no system has two" % twins_written, 0, twins_read)
	# VERSION 34: a save from before `unlocked` rolls on from every manufacturer,
	# which is what the build that wrote it was rolling.
	check("and with no unlocked list: every manufacturer, as it was", str(Unlocks.CHAIN),
		str(Run.unlocked_manufacturers))

	# A save older than that must not load, whatever is inside it -- the same
	# whole file, so it is the number that refuses it and not a missing map.
	var stale := old_save.duplicate(true)
	stale["version"] = SaveGame.OLDEST_READ - 1
	var f := FileAccess.open(SaveGame.path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(stale))
		f.close()
	check("a save older than version %d is refused" % SaveGame.OLDEST_READ, false, SaveGame.load_into_run())

	# And a flight record written before the rename still unlocks.
	RunHistory.path = HISTORY
	RunHistory.clear()
	var old := {"version": RunHistory.VERSION, "runs": [{
		"outcome": int(RunHistory.Outcome.WON), "chassis_maker": "korvan"}]}
	var g := FileAccess.open(RunHistory.path, FileAccess.WRITE)
	if g != null:
		g.store_string(JSON.stringify(old))
		g.close()
	var won := Unlocks.won_with()
	check("a pre-rename record still unlocks its manufacturer",
		true, won.has(&"korvan"))
	RunHistory.clear()
	RunHistory.path = RunHistory.PATH

	print("=== %s (%d mismatches) ===
"
		% ["PASS" if fails == fails_before else "FAIL", fails - fails_before])

## SCIENCE (VERSION 41, Phase 12): this build writes 41. A 40 save loads with
## no DATA, nothing bought, the black box unspent, no part augmented, and the
## board its seed and seat deal; a malformed one is mended, not refused; and a
## new run after a used one starts clean.
func _science_versions() -> void:
	check("this build writes VERSION 41", 41, SaveGame.VERSION)
	Run.start_new_run(&"korvan", 1)
	var dealt := Run.board.duplicate()
	check("a new run is dealt a whole board", 9, dealt.size())
	Run.data = 23
	Run.board_owned = PackedInt32Array([1, 2, 0])
	Run.black_box_spent = true
	for m in Run.installed:
		m.augmented = true
		break
	SaveGame.save()
	var s41 := _read_save()
	check("a 41 save carries DATA, the board's ids, the steps and the box",
		"23 %s [1, 2, 0] true" % ",".join(Array(dealt).map(func(x: StringName) -> String: return String(x))),
		"%d %s %s %s" % [int(s41.get("data", -1)), ",".join(Array(s41.get("board", []))),
			str(Array(s41.get("board_owned", [])).map(func(x: Variant) -> int: return int(x))),
			str(s41.get("black_box_spent", false))])
	check("and the fitted part's mark", true,
		Array(s41.get("installed", [])).any(func(e: Variant) -> bool: return bool((e as Dictionary).get("augmented", false))))

	# A 40 SAVE: this shape with none of 41's keys. Loaded over a live run that
	# has DATA, a different board, steps bought and a mark, so nothing can pass
	# by being left over.
	var s40 := s41.duplicate(true)
	s40["version"] = 40
	_erase_science(s40)
	_write(s40)
	Run.board = _other_board(dealt)
	Run.board_owned = PackedInt32Array([3, 3, 3])
	Run.data = 99
	check("a save of version 40 (no science) still loads", true, SaveGame.load_into_run())
	check("and with 0 DATA, nothing owned, the box unspent, nothing augmented",
		"0 [0, 0, 0] false 0 0", "%d %s %s %d %d" % [Run.data, str(Array(Run.board_owned)),
			str(Run.black_box_spent), Run.owned_routines().size(), _marked()])
	check("and its board the one its seed and seat deal", str(dealt), str(Run.board))
	Run.deal_board()
	check("which is what dealing it again gives", str(dealt), str(Run.board))

	# MALFORMED, MENDED: a board with an unknown id, one cut short and one in the
	# wrong order are dealt again; owned [5, -1] reads [3, 0, 0]; data -12 reads 0
	var bad := s41.duplicate(true)
	var cases := {
		"an unknown id": ["nope"] + Array(bad.board).slice(1),
		"cut short": Array(bad.board).slice(0, 6),
		"out of its branches": Array(bad.board).slice(3) + Array(bad.board).slice(0, 3),
		"none at all": null,
	}
	for what in cases:
		bad["board"] = cases[what]
		bad["board_owned"] = [5, -1]
		bad["data"] = -12
		_write(bad)
		Run.board = _other_board(dealt)
		SaveGame.load_into_run()
		check("a board %s is dealt again" % what, str(dealt), str(Run.board))
	check("owned [5, -1] reads [3, 0, 0]", "[3, 0, 0]", str(Array(Run.board_owned)))
	check("DATA -12 reads 0", 0, Run.data)
	# (and a board in its shape that the seed would not deal is kept as saved)
	bad["board"] = Array(_other_board(dealt)).map(func(x: StringName) -> String: return String(x))
	_write(bad)
	SaveGame.load_into_run()
	check("a whole board the seed would not deal is kept as saved", str(_other_board(dealt)), str(Run.board))

	# A NEW RUN AFTER A USED ONE: no DATA, nothing owned, the box unspent, and
	# full hull (fitted with nothing of the last run's on it)
	Run.data = 50
	Run.board_owned = PackedInt32Array([3, 3, 3])
	Run.black_box_spent = true
	Run.start_new_run(&"korvan", 1)
	check("a new run after a used one: 0 DATA, nothing owned, the box unspent, a board",
		"0 [0, 0, 0] false 0 9", "%d %s %s %d %d" % [Run.data, str(Array(Run.board_owned)),
			str(Run.black_box_spent), Run.owned_routines().size(), Run.board.size()])
	check("and its hull full at the bare frame's max", Run.max_hp(), Run.hp)
	# AND THE CHASSIS SELECT KEEPS THE BOARD the new run dealt. It is the screen
	# `Router.new_run` opens right after `start_new_run`, and LAUNCH deals
	# nothing; it used to clear science on entry, so every real run flew with
	# an empty board and the first autosave wrote `board: []`.
	var fresh := Run.board.duplicate()
	var pick := ChassisSelect.new()
	# (out of the tree: the root is busy setting up this run's own children)
	pick.setup()
	check("the chassis select keeps the new run's board, nine dealt", "9 %s" % str(fresh),
		"%d %s" % [Run.board.size(), str(Run.board)])
	Run.deal_board()
	check("and it is the board the run's seed and seat deal", str(fresh), str(Run.board))
	pick.free()

func run_history_test() -> void:
	print("=== HISTORY ===")
	RunHistory.path = HISTORY
	RunHistory.clear()
	Run.start_new_run()
	Run.jumps = 11
	Run.kills = 7
	RunHistory.record(RunHistory.Outcome.DIED, "Test death.")
	Run.start_new_run()
	Run.jumps = 30
	Run.kills = 19
	RunHistory.record(RunHistory.Outcome.WON, "Test win.")
	Run.start_new_run()
	RunHistory.record(RunHistory.Outcome.ABANDONED, "Test abandon.")
	var s := RunHistory.stats()
	check("runs", 3, int(s.runs))
	check("finished", 2, int(s.finished))
	check("wins", 1, int(s.wins))
	check("win_rate", "50", "%.0f" % float(s.win_rate))
	check("kills", 26, int(s.kills))
	check("best_kills", 19, int(s.best_kills))
	var recent := RunHistory.recent()
	check("newest first", int(RunHistory.Outcome.ABANDONED),
		int((recent[0] as Dictionary).outcome))
	check("depth_text", true, RunHistory.depth_text(recent[1]).ends_with(
		"/%d shells" % MapGen.LAYERS))
	RunHistory.clear()
	RunHistory.path = RunHistory.PATH
	print("=== %s (%d total mismatches) ===\n" % ["PASS" if fails == 0 else "FAIL", fails])
