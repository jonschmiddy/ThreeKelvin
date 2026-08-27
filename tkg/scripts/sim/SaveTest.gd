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

func check(what: String, a: Variant, b: Variant) -> void:
	if str(a) != str(b):
		fails += 1
		print("  MISMATCH %s\n    before: %s\n    after:  %s" % [what, a, b])

func fingerprint() -> Dictionary:
	var mods := func(list: Array) -> Array:
		var out: Array = []
		for m in list:
			var af: Array = []
			for a in m.affixes:
				af.append(a.name)
			# WHERE it is, as well as what it is. Neither `mount` nor `hold_at`
			# was fingerprinted before, so this test passed on a save that
			# dropped every position — the loadout you built came back as the
			# same parts in a different arrangement and nothing here noticed.
			# That is the exact failure mode the scramble exists to catch.
			out.append("%s|%d|%d|%s|m%d|h%d,%d" % [m.id, int(m.rarity),
				m.scrap_value, ",".join(af), m.mount, m.hold_at.x, m.hold_at.y])
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
	return {
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
		econ = [Run.hp, Run.heat, Run.heat_cap_bonus, Run.credits,
			Run.fuel, Run.dross_count(), Run.whale_boon],
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
		# The roamer. The move counter is a SEED SOURCE — Rng.derive keys each
		# hop on it — so losing it is not a cosmetic reset, it is a different
		# walk from the same position.
		hellbender = [Run.hellbender_at, Run.hellbender_hp, Run.hellbender_max,
			Run.hellbender_moves, Run.hellbender_ticks],
		galaxy = [Run.galaxy_kind, Run.galaxy_seed, "%.9f" % Run.galaxy_spin,
			Run.galaxy_name, Run.galaxy_title],
		gparams = _round_floats(Run.galaxy),
		nodes = nodes,
		derived = ["%.9f" % Run.jump_range(), Run.max_hp(), Run.heat_cap(),
			Run.reactor(), Run.hand_size(), Run.dissipation()],
	}

func _materials() -> String:
	var keys: Array = Run.materials.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
	var parts: PackedStringArray = []
	for k in keys:
		parts.append("%s=%d" % [str(k), int(Run.materials[k])])
	return " ".join(parts)

func _quotes() -> String:
	var n: MapGen.MapNode = Run.node_at()
	var parts: PackedStringArray = ["repair=%.4f" % Market.repair_rate(n),
		"refuel=%d" % Market.refuel_price(n), "coolant=%d" % Market.coolant_price(n)]
	for m in n.shop:
		parts.append("ask:%s=%d" % [m.id, Market.ask(n, m)])
	for m in Run.cargo:
		parts.append("bid:%s=%d/melt=%d" % [m.id, Market.bid(n, m), Market.melt(m)])
	for d in DB.MATERIALS:
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
	Run.credits += 37
	# All three materials, not just the one that used to be a bare field. A
	# ledger keyed by StringName and reloaded from JSON's String keys is exactly
	# the kind of thing that comes back looking right and compares wrong.
	Run.exotic = 3
	Run.add_material(&"exotic", 7)
	Run.add_material(&"relic", 2)
	Run.dross = [&"slag", &"arcfault"] as Array[StringName]
	Run.whale_boon = true
	Run.kills = 4
	for i in 4:
		Run.place_in_hold(LootGen.roll_module(3 + i, &"", true))
	Run.install_module(Run.cargo[0])
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
		var last: ModuleData = Run.cargo[Run.cargo.size() - 1]
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
		if n.type != MapGen.NodeType.STATION and n.type != MapGen.NodeType.CORE 				and n.options.is_empty():
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
	Run.materials = {}
	Run.fuel = 0
	Run.dross = [] as Array[StringName]
	Run.whale_boon = false
	Run.jumps = 0
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
	Run.galaxy_kind = 0
	Run.galaxy = GalaxyGen.params(0).duplicate()
	Run.galaxy_seed = 0
	Run.galaxy_spin = 0.0
	Run.galaxy_name = ""
	Run.galaxy_title = ""
	Run._range_cache.clear()

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

	# A save one version behind must not load, whatever is inside it.
	var stale := {"version": SaveGame.VERSION - 1, "hp": 99}
	var f := FileAccess.open(SaveGame.PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(stale))
		f.close()
	check("a save one version behind is refused", false, SaveGame.load_into_run())

	# And a flight record written before the rename still unlocks.
	RunHistory.clear()
	var old := {"version": RunHistory.VERSION, "runs": [{
		"outcome": int(RunHistory.Outcome.WON), "chassis_maker": "korvan"}]}
	var g := FileAccess.open(RunHistory.PATH, FileAccess.WRITE)
	if g != null:
		g.store_string(JSON.stringify(old))
		g.close()
	var won := Unlocks.won_with()
	check("a pre-rename record still unlocks its manufacturer",
		true, won.has(&"korvan"))
	RunHistory.clear()

	print("=== %s (%d mismatches) ===
"
		% ["PASS" if fails == fails_before else "FAIL", fails - fails_before])

func run_history_test() -> void:
	print("=== HISTORY ===")
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
	print("=== %s (%d total mismatches) ===\n" % ["PASS" if fails == 0 else "FAIL", fails])
