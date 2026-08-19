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
			out.append("%s|%d|%d|%s" % [m.id, int(m.rarity), m.scrap_value, ",".join(af)])
		return out
	var nodes: Array = []
	for e in Run.map:
		var n: MapGen.MapNode = e
		var shop: Array = []
		for m in n.shop:
			shop.append(str(m.id) + ":" + str(m.scrap_value))
		nodes.append("%d/%d/%d/%d/%d/%s/%s/%s/%.9f,%.9f/%.9f,%.9f/%s/%s/%s/%s/%s/%s" % [
			n.index, n.layer, n.row, n.rows_in_layer, n.danger,
			n.type, n.region, n.development,
			n.pos.x, n.pos.y, n.gal.x, n.gal.y,
			n.visited, n.cleared, n.inspected,
			Array(n.links), n.makers, shop])
	return {
		hull = "%s|%d|%d|%d|%d|%d|%.9f|%d|%.9f|%d|%d|%d|%s" % [
			Run.hull.name, Run.hull.tier, Run.hull.reactor, Run.hull.hand_size,
			Run.hull.max_hull, Run.hull.heat_cap, Run.hull.dodge,
			Run.hull.initiative, Run.hull.fuel_factor, Run.hull.weapon_slots,
			Run.hull.system_slots, Run.hull.utility_slots, Run.hull.perk_id],
		installed = mods.call(Run.installed),
		cargo = mods.call(Run.cargo),
		econ = [Run.hp, Run.heat, Run.heat_cap_bonus, Run.scrap, Run.exotic,
			Run.fuel, Run.dross, Run.whale_boon],
		pos = [Run.at, Array(Run.trail), Run.jumps, Run.kills],
		galaxy = [Run.galaxy_kind, Run.galaxy_seed, "%.9f" % Run.galaxy_spin,
			Run.galaxy_name, Run.galaxy_title],
		gparams = _round_floats(Run.galaxy),
		nodes = nodes,
		derived = ["%.9f" % Run.jump_range(), Run.max_hp(), Run.heat_cap(),
			Run.reactor(), Run.hand_size(), Run.dissipation()],
	}

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
		Run.node_at().inspected = (i % 3 == 0)
	Run.hp = maxi(1, Run.hp - 9)
	Run.heat = 5
	Run.heat_cap_bonus = 2
	Run.scrap += 37
	Run.exotic = 3
	Run.dross = 2
	Run.whale_boon = true
	Run.kills = 4
	for i in 4:
		Run.cargo.append(LootGen.roll_module(3 + i, &"", true))
	Run.install_module(Run.cargo[0])
	Run.found_hull = LootGen.roll_hull(4)
	Run.transfer_to_hull(LootGen.roll_hull(5))
	# A station with stock already rolled, and a hull on the pad.
	var st: MapGen.MapNode = Run.map[Run.at]
	st.shop = [LootGen.roll_module(2), LootGen.roll_module(4, &"", true)]
	st.shop_hull = LootGen.roll_hull(3)

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
	Run.scrap = 0
	Run.exotic = 0
	Run.fuel = 0
	Run.dross = 0
	Run.whale_boon = false
	Run.jumps = 0
	Run.kills = 0
	Run.at = 0
	Run.trail = PackedInt32Array()
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
