extends RefCounted

## Scramble live state before loading so nothing survives by accident; floats to nine decimals.
## Why: docs/why/SaveTest.md#round-trip-method

var fails: int = 0

## `RunHistory.path` points at a test file: clearing the real one wiped the player's record.
## Why: docs/why/SaveTest.md#history-file
const HISTORY := "user://savetest_history.json"
const SEED_SCRAMBLE := 99

func check(what: String, a: Variant, b: Variant) -> void:
	if str(a) != str(b):
		fails += 1
		print("  MISMATCH %s\n    before: %s\n    after:  %s" % [what, a, b])

func fingerprint() -> Dictionary:
	var mods := func(list: Array) -> Array:
		var out: Array = []
		for raw in list:
			# A crate has only an id and a cell, the two fields it can lose.
			var mat := raw as MaterialData
			if mat != null:
				out.append("%s|h%d,%d" % [mat.id, mat.hold_at.x, mat.hold_at.y])
				continue
			var m := raw as ModuleData
			var af: Array = []
			for a in m.affixes:
				af.append(a.name)
			# Position is fingerprinted too: a save that dropped every position used to pass.
			# (and the Lab's mark, VERSION 42: once per part, ever)
			out.append("%s|%d|%d|%s|m%d|h%d,%d|a%d" % [m.id, int(m.rarity),
				m.scrap_value, ",".join(af), m.mount, m.hold_at.x, m.hold_at.y,
				int(m.augmented)])
		return out
	var nodes: Array = []
	for e in Run.map:
		var n: MapGen.MapNode = e
		var shop: Array = []
		for m in n.shop:
			# The price is derived, so the part must survive; the quote is checked separately.
			shop.append("%s:%d" % [m.id, m.scrap_value])
		nodes.append("%d/%d/%d/%d/%d/%s/%s/%s/%.9f,%.9f/%.9f,%.9f/%s/%s/%s/%s/%s/%s/%s/%s/%s/%s/%s/%s/%s/%s/%s/%s" % [
			n.index, n.layer, n.row, n.rows_in_layer, n.danger,
			n.type, n.region, n.development,
			n.pos.x, n.pos.y, n.gal.x, n.gal.y,
			n.visited, n.cleared, n.eaten, n.inspected, n.fled,
			# An unstocked shelf rerolls and an unsaturated market pays full price; both silent.
			n.stocked, n.trades,
			Array(n.links), n.berths, shop,
			# What the system is offering. Rolled on arrival and fixed from then
			# on, so losing it across a save is a re-roll the player can force.
			n.foes, n.event_key,
			# `taken` is not `cleared`: losing it re-offers used options and nothing else notices.
			Array(n.taken),
			# `taken` indexes `options`, so losing the list renumbers what counts as spent.
			n.options,
			# Never covered before: losing `ambush_rolled` rerolls each redraw until it bites.
			# Why: docs/why/SaveTest.md#ambush-fingerprint
			n.ambush_pending, n.ambush_rolled])
	# Cards (VERSION 29), sorted: a dictionary rebuilt from arrays need not hash in write order.
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
		# Parked position (VERSION 30), fixtured since an empty record round-trips to empty.
		parked = _parked(),
		# AND EACH SYSTEM'S MAP CLOCK (VERSION 39), which those spots were left
		# at and a binary's suns turn by. Fixtured below, for the same reason.
		clocks = _clocks(),
		# Perks must be fingerprinted: the loader never calls `at_tier`, so lost perks read PASS.
		# Why: docs/why/SaveTest.md#grade-perks
		hull = "%s|%d|%d|%d|%d|%d|%.9f|%d|%.9f|%d|%d|%d|%s|%s" % [
			Run.hull.name, Run.hull.tier, Run.hull.reactor, Run.hull.hand_size,
			Run.hull.max_hull, Run.hull.heat_cap, Run.hull.dodge,
			Run.hull.initiative, Run.hull.fuel_factor, Run.hull.weapon_slots,
			Run.hull.system_slots, Run.hull.utility_slots, Run.hull.perk_id,
			",".join(Array(Run.hull.tier_perks).map(func(x: StringName) -> String:
				return String(x)))],
		installed = mods.call(Run.installed),
		cargo = mods.call(Run.cargo),
		# The pad is not cargo and is the newest field; fixtured as empty equals empty.
		pad = mods.call(Run.pad),
		# Old hull is saved (VERSION 36): without it a save drew those parts nowhere (Jon, Oct 23).
		# Why: docs/why/SaveTest.md#old-hull
		old_hull = "%s|%d|%d|%s" % [Run.old_hull.name, Run.old_hull.tier,
			Run.old_hull.max_hull, Run.old_hull.perk_id] if Run.old_hull != null else "",
		econ = [Run.hp, Run.heat, Run.heat_cap_bonus, Run.credits,
			Run.fuel, Run.dross_count(), Run.whale_boon, Run.data],
		# SCIENCE (VERSION 42): the board as dealt, the steps bought on it and the
		# black box. Fixtured below with a board the seed would NOT deal, so a
		# save that dropped it and dealt again at the load shows here.
		science = [",".join(Array(Run.board).map(func(x: StringName) -> String: return String(x))),
			Array(Run.board_owned), Run.black_box_spent,
			",".join(Array(Run.owned_routines()).map(func(x: StringName) -> String: return String(x)))],
		# WHAT THE WORLD MAY HOLD (VERSION 34). Fixtured below to three, so a
		# load that fell back to the profile's own (Korvan alone here) shows.
		unlocked = ",".join(Array(Run.unlocked_manufacturers).map(
			func(m: StringName) -> String: return String(m))),
		# Every material as a sorted list, so String and StringName keys still compare equal.
		materials = _materials(),
		# Quotes test all that prices derive from (axes, saturation, roll, perk) at once.
		quotes = _quotes(),
		pos = [Run.at, Array(Run.trail), Run.jumps, Run.kills],
		# THE LEAD SHIP'S JUMPS (VERSION 40), which a co-op Custodian grows on.
		# Fixtured above your own, so a save that dropped it shows here.
		party = [Run.party_jumps, Run.custodian_jumps()],
		# The move counter seeds `Rng.derive`, so losing it is a different walk, not a reset.
		hellbender = [Run.hellbender_at, Run.hellbender_hp, Run.hellbender_max,
			Run.hellbender_moves, Run.hellbender_ticks],
		# THE ASCENSION LEVEL (VERSION 41), which decides whether there is one.
		ascension = Run.ascension,
		galaxy = [Run.galaxy_kind, Run.galaxy_seed, "%.9f" % Run.galaxy_spin,
			Run.galaxy_name, Run.galaxy_title],
		gparams = _round_floats(Run.galaxy),
		nodes = nodes,
		# Sky and twin layout are fingerprinted: a save dropping `twin` used to pass.
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

## A saved run with none of VERSION 42's keys.
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

## Counted per catalogue id so shuffled cells still match; `-- holdtest` covers placement.
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
	# Materials have one flat value, so a crate contributes its identity only.
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
	# At ascension 7, so the run has a Hellbender to save mid-chase (Jon, Nov 8:
	# it flies only there), and the level is a field that has to come back.
	Run.forced_ascension = Run.HELLBENDER_ASCENSION
	Run.start_new_run()
	Run.forced_ascension = -1
	check("the round trip's run has a Hellbender to save (ascension %d)" % Run.ascension, true, Run.hellbender_alive())

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
		# One option consumed at an unfinished system: the case a single boolean cannot hold.
		if i % 3 == 1:
			Run.node_at().taken = PackedInt32Array([2])
		Run.node_at().inspected = (i % 3 == 0)
		Run.node_at().fled = (i % 4 == 0)
	Run.hp = maxi(1, Run.hp - 9)
	Run.heat = 5
	Run.heat_cap_bonus = 2
	# Placed by hand: no probe buys a hull, so an empty pad would only prove empty survives.
	# Why: docs/why/SaveTest.md#pad-fixture
	for stranded in [&"plate", &"coolant"]:
		var sm := (DB.modules[stranded] as ModuleData).duplicate(true) as ModuleData
		sm.hold_at = -Vector2i.ONE
		Run.pad.append(sm)
	# Ids are read with no `has` guard, so a rename fails here instead of seeding nothing.
	assert(Run.pad.size() == 2)
	Run.credits += 37
	# All three materials, kept aboard not in the sector: String keys after JSON compare wrong.
	# Why: docs/why/SaveTest.md#material-fixtures
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
	# Arrange the hold: first fit alone hid a writer that dropped every cell.
	# Why: docs/why/SaveTest.md#hold-arrangement
	if not Run.cargo.is_empty():
		# `HoldItem`: this proves a position survives a round trip, true of anything with cells.
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
	# A rolled shelf and sold-into market are silent when lost; unstocked rerolls inventory.
	st.stocked = true
	st.trades = 3
	# A second market, saturated differently, so a single value restored to every
	# node would still show up as a mismatch.
	for e in Run.map:
		var n2: MapGen.MapNode = e
		if n2.index % 7 == 0:
			n2.stocked = true
			n2.trades = n2.index % 5
	# Fight and hail rolls already made, or a save hands a fresh draw on each resume.
	for e in Run.map:
		var n: MapGen.MapNode = e
		if n.type == MapGen.NodeType.SYSTEM and not n.cleared and n.foes.is_empty():
			n.foes = [&"cutter", &"lancer"]
		elif n.type == MapGen.NodeType.SYSTEM and not n.cleared and n.event_key.is_empty():
			n.event_key = "Dead station"
		# Roll options as arriving would: empty lists round-trip to empty and prove nothing.
		if n.type != MapGen.NodeType.STATION and n.type != MapGen.NodeType.CORE 				and n.options.is_empty():
			n.options = OptionTable.roll_for(n)
		# Ambush fields must be on some nodes and not others, or all-false proves nothing.
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
			# The same three writes Hellbender.land() makes, because a cleared node
			# with an empty `taken` is backfilled on load and would mismatch.
			nd.cleared = true
			nd.eaten = true
			nd.taken.append(MapGen.OPTION_WHOLE)
			break

	# A half-worked system, written as `OptionResolve.take` does; empty maps prove nothing.
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

	# Parked in orbit and in open space, written as `SystemMapScreen._keep_ship` writes them.
	SystemMapScreen._parked.clear()
	SystemMapScreen._parked[Run.at] = {"at": 1, "p": Vector2(212.5, -40.25), "v": Vector2(0.75, -1.5), "head": 2.25, "mode": &"rail"}
	SystemMapScreen._parked[card_node if card_node >= 0 else 0] = {"at": -9, "p": Vector2(-318.125, 96.5), "v": Vector2.ZERO, "head": -0.625, "mode": &"free"}
	# Star B close orbit (ruling 20): force a twin so the case exists whatever the run rolled.
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
	# Wide orbit stores centre, radius and sense so the map restores it (saves review, Oct 31).
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
	# Map clocks (VERSION 39), written as the map writes them, plus one system with no ship kept.
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

	# SCIENCE (VERSION 42): DATA in hand, FRAME two steps in and DRIVE one, the
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
	# The streams' cursors are 64-bit and the file is JSON: they must come back exactly.
	var rng_saved := str(Rng.state())

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
	Run.ascension = 0
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
	Rng.reseed(SEED_SCRAMBLE)
	Rng.loot.randi()

	if not SaveGame.load_into_run():
		print("  FAIL: load_into_run() returned false"); fails += 1; return
	if SaveGame.has_save():
		print("  FAIL: save survived the load — suspend model broken"); fails += 1

	check("the streams' cursors read back exactly", rng_saved, str(Rng.state()))
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

	# Walk-away must survive a reload (Jon): LEFT ALONE stays, and taking it clears it.
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

## The save discards but the record does not: refusing the flight record deletes every run flown.
## Why: docs/why/SaveTest.md#version-rules
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

	# VERSION 39: a 38 save without `clocks` loads with every system at t 0, as a 38 build drew.
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

	# VERSION 40 (Jon, Nov 4) saves the lead ship's jumps; a 39 save grows on its own jumps.
	# Why: docs/why/SaveTest.md#version-rules
	# (this build writes 43; the lead ship's jumps came in at 40)
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

	# THE ASCENSION LEVEL (VERSION 41, Jon, Nov 8; this build writes 43, moored's). The
	# Hellbender flies only at 7 and up, so the level is saved and comes back;
	# a 40 save has none and loads at 0, the game a 40 build played, and keeps
	# a live Hellbender it already had (pulling one mid-chase is worse).
	Run.forced_ascension = 7
	Run.start_new_run(&"korvan", 1)
	Run.forced_ascension = -1
	check("a run started at ascension 7 is at 7, with its Hellbender", "7 true",
		"%d %s" % [Run.ascension, Run.hellbender_alive()])
	SaveGame.save()
	var f40 := FileAccess.open(SaveGame.path, FileAccess.READ)
	var save40: Dictionary = JSON.parse_string(f40.get_as_text()) if f40 != null else {}
	if f40 != null:
		f40.close()
	check("a 41 save carries its ascension", 7, int(save40.get("ascension", -1)))
	var hb40 := [Run.hellbender_at, Run.hellbender_hp, Run.hellbender_max]
	Run.ascension = 0
	SaveGame.load_into_run()
	check("and loads it back", 7, Run.ascension)
	save40["version"] = 40
	save40.erase("ascension")
	var w40 := FileAccess.open(SaveGame.path, FileAccess.WRITE)
	if w40 != null:
		w40.store_string(JSON.stringify(save40, "", true, true))
		w40.close()
	Run.ascension = 9
	check("a save of version 40 (no ascension) still loads", true, SaveGame.load_into_run())
	check("and at ascension 0", 0, Run.ascension)
	check("and keeps the live Hellbender it had (at, hp, max)", str(hb40),
		str([Run.hellbender_at, Run.hellbender_hp, Run.hellbender_max]))
	save40["version"] = 41
	save40["ascension"] = 99
	w40 = FileAccess.open(SaveGame.path, FileAccess.WRITE)
	if w40 != null:
		w40.store_string(JSON.stringify(save40, "", true, true))
		w40.close()
	SaveGame.load_into_run()
	check("an ascension past the ladder reads its top (%d)" % Run.ASCENSION_MAX, Run.ASCENSION_MAX, Run.ascension)
	Run.start_new_run(&"korvan", 1)
	check("a new run with nothing asked starts at 0, with no Hellbender", "0 false 0",
		"%d %s %d" % [Run.ascension, Run.hellbender_alive(), Run.hellbender_max])
	_science_versions()
	_moored_versions()

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
	old_save.erase("ascension")
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

## MOORED ON THE STATION'S RIGHT (VERSION 43, Nov 13): the save keeps the station
## node, a load puts it back, and a 42 save (none) loads moored on the left.
func _moored_versions() -> void:
	Run.start_new_run(&"korvan", 1)
	Moored.moor(Run.at)
	SaveGame.save()
	var s43 := _read_save()
	check("a 43 save keeps where you are moored", Run.at, int(s43.get("moored_right", -9)))
	Moored.at = -1
	check("and loads it back", true, SaveGame.load_into_run() and Moored.at == Run.at)
	s43["version"] = 42
	s43.erase("moored_right")
	var w := FileAccess.open(SaveGame.path, FileAccess.WRITE)
	if w != null:
		w.store_string(JSON.stringify(s43, "", true, true))
		w.close()
	check("a 42 save (none) loads moored on the left", true, SaveGame.load_into_run() and Moored.at == -1)
	Moored.at = -1


## SCIENCE (VERSION 42, Phase 12): this build writes 43. A 41 save (the Hellbender's
## build, its `ascension` key unread here) and a 40 one load with
## no DATA, nothing bought, the black box unspent, no part augmented, and the
## board its seed and seat deal; a malformed one is mended, not refused; and a
## new run after a used one starts clean.
func _science_versions() -> void:
	check("this build writes VERSION 43 (42's science, and where you are moored)", 43, SaveGame.VERSION)
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
	var s42 := _read_save()
	check("a 42 save carries DATA, the board's ids, the steps and the box",
		"23 %s [1, 2, 0] true" % ",".join(Array(dealt).map(func(x: StringName) -> String: return String(x))),
		"%d %s %s %s" % [int(s42.get("data", -1)), ",".join(Array(s42.get("board", []))),
			str(Array(s42.get("board_owned", [])).map(func(x: Variant) -> int: return int(x))),
			str(s42.get("black_box_spent", false))])
	check("and the fitted part's mark", true,
		Array(s42.get("installed", [])).any(func(e: Variant) -> bool: return bool((e as Dictionary).get("augmented", false))))

	# A 41 SAVE AND A 40 ONE: this shape with none of 42's keys, the 41 one with
	# the Hellbender's `ascension` (41 is its build's, landed first). Each loaded
	# over a live run that has DATA, a different board, steps bought and a mark,
	# so nothing can pass by being left over.
	for v in [41, 40]:
		var sv := s42.duplicate(true)
		sv["version"] = v
		_erase_science(sv)
		if v == 41:
			sv["ascension"] = 7
		_write(sv)
		Run.board = _other_board(dealt)
		Run.board_owned = PackedInt32Array([3, 3, 3])
		Run.data = 99
		Run.ascension = 3
		check("a save of version %d (no science) still loads" % v, true, SaveGame.load_into_run())
		check("and with 0 DATA, nothing owned, the box unspent, nothing augmented (%d)" % v,
			"0 [0, 0, 0] false 0 0", "%d %s %s %d %d" % [Run.data, str(Array(Run.board_owned)),
				str(Run.black_box_spent), Run.owned_routines().size(), _marked()])
		check("and its board the one its seed and seat deal (%d)" % v, str(dealt), str(Run.board))
		# (the Hellbender's 41 keeps its ascension; a 40 save has none and reads 0)
		check("and its ascension (%d)" % v, 7 if v == 41 else 0, Run.ascension)
	Run.deal_board()
	check("which is what dealing it again gives", str(dealt), str(Run.board))

	# MALFORMED, MENDED: a board with an unknown id, one cut short and one in the
	# wrong order are dealt again; owned [5, -1] reads [3, 0, 0]; data -12 reads 0
	var bad := s42.duplicate(true)
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

	# AN AFFIX BY ITS OLD NAME (Jon, Nov 5: "Stripped" is "Lightened" now): a
	# save whose fitted part holds "Stripped" loads it as Lightened, +2 maneuver -1
	# hull, not dropped; and Lightened is written and read back as itself
	var old := s42.duplicate(true)
	var fit: Array = old.get("installed", [])
	if not fit.is_empty():
		(fit[0] as Dictionary)["affixes"] = ["Stripped", "Reinforced"]
	_write(old)
	SaveGame.load_into_run()
	var first: ModuleData = Run.installed[0] if not Run.installed.is_empty() else null
	var got: Array = [] if first == null else first.affixes.map(func(a: AffixData) -> String: return "%s %+d %+d" % [a.name, a.maneuver, a.hull])
	check("a save's \"Stripped\" loads as Lightened", "[\"Lightened +2 -1\", \"Reinforced +0 +1\"]", str(got))
	SaveGame.save()
	var again: Array = Array(_read_save().get("installed", []))
	check("and is written back as Lightened", "[\"Lightened\", \"Reinforced\"]",
		str((again[0] as Dictionary).get("affixes", [])) if not again.is_empty() else "none")

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
	# A write that cannot finish leaves the old file whole: block the temp file with a folder.
	var tmp := ProjectSettings.globalize_path(HISTORY + ".tmp")
	DirAccess.make_dir_absolute(tmp)
	Run.start_new_run()
	RunHistory.record(RunHistory.Outcome.DIED, "Never lands.")
	check("a failed write leaves the history whole", 3, RunHistory.load_all().size())
	check("and says it failed", false, SafeFile.write_text(HISTORY, "{}"))
	DirAccess.remove_absolute(tmp)
	RunHistory.record(RunHistory.Outcome.DIED, "Lands.")
	check("the next write lands", 4, RunHistory.load_all().size())
	check("and leaves no temp file behind", false, FileAccess.file_exists(HISTORY + ".tmp"))
	RunHistory.clear()
	RunHistory.path = RunHistory.PATH
	print("=== %s (%d total mismatches) ===\n" % ["PASS" if fails == 0 else "FAIL", fails])
