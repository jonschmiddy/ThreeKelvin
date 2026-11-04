extends Node

## WHAT EACH ROUTINE DOES, WHERE IT HAPPENS (science, Phase 12, plan S3):
##   godot --headless --path . -- sheet=RoutineTest
##
## The Lab writes routines into the flight computer (`DB.routines`), and each
## one is read where the thing it changes happens: the six numbers in RunState's
## stat functions, the four fight ones in Combat, BLACK BOX in
## `take_hull_damage`. Every check starts from a USED run (hull down, some heat,
## the kit fitted), because a full, cold, empty ship hides half of what a
## routine can get wrong.
##
## Routines are owned either the way a player owns them (a board step bought
## with DATA, `Run.buy_step`) or through the test seam `Run.routines_granted`,
## which is how all twelve can be owned at once when a board holds nine.
##
##  - the six stat routines, each read before and after: DAMAGE CONTROL carries
##    the damage (full stays full, 7 down stays 7 down), dodge stops at 0.6,
##    FUEL TRIM is 0.81 with Deep Tanks and never under 0.3, trims a long hop
##    and the way-out floor and not a science reading's burn, SPARE CELLS powers
##    a part 3 cells over the old cap with the energy unchanged;
##  - each pip routine moves its gauge by exactly 1, and VENT TIMING moves heat
##    capacity by 0 (here and not in AttrTest, whose file is another lane's);
##  - WARM START and FIRST LOOK on the first turn only, a late joiner too;
##  - COLD OPEN 10 to 6, 2 to 0, and no line at 0;
##  - PATCH CREW +3 capped, +6 with Calyx's three, on a pacify, never on a flee;
##  - BLACK BOX on PlayerDeathTest's seed 6061 against a cutter: the ship lives
##    at 1, the box is spent, the next killing hit kills, and so does an event's
##    toll; overheat and junk count as the fight's;
##  - a hull swap with all twelve: full stays full, BACK OUT restores the hull,
##    the yard's reading of a new frame includes the +7, a new run clears all;
##  - the two orders S2 could not test: a new run's hull is filled after the
##    last run's science is gone, and a load reads the science before the hull;
##  - `-- sim routines=`'s parse and grant.

var _tree: SceneTree
var _fails := 0
var _logs: Array[String] = []

const SEED := 4242
## PlayerDeathTest's seed and setup (Korvan medium, a cutter).
const DEATH_SEED := 6061


func _ok(what: String, c: bool) -> bool:
	print("  %s %s" % ["ok  " if c else "FAIL", what])
	if not c:
		_fails += 1
	return c


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_tree = get_tree()
	await _tree.process_frame
	Sig.log_line.connect(func(text: String, _k: StringName) -> void: _logs.append(text))
	print("-- the stat routines")
	_damage_control()
	_vent_and_gauges()
	_dodge_cap()
	_fuel_trim()
	_spare_cells()
	print("-- the fight routines")
	_opening_turn()
	_cold_open()
	_patch_crew()
	_black_box()
	print("-- a hull swap")
	_swap()
	print("-- the orders")
	_new_run_order()
	_load_order()
	print("-- the sim's routines=")
	_sim_hook()
	print("routinetest: %s" % ("PASS" if _fails == 0 else "%d FAILURES" % _fails))
	_tree.quit(1 if _fails > 0 else 0)


# ------------------------------------------------------------------- helpers

## A used run: the kit fitted, 9 hull down, some heat.
func _used(at_seed := SEED, w := HullData.Weight.MEDIUM) -> void:
	Rng.forced = at_seed
	Run.start_new_run(&"korvan", int(w))
	Run.hp = maxi(1, Run.max_hp() - 9)
	Run.heat = 5
	Sig.ship_changed.emit()


## Own these routines through the test seam, as a step bought would: the ship
## changes, so the hull carries its damage to the new max (`_clamp_hp`).
func _own(ids: Array) -> void:
	var a: Array[StringName] = []
	for id in ids:
		a.append(StringName(id))
	Run.routines_granted = a
	Sig.ship_changed.emit()


## A board whose FRAME starts with DAMAGE CONTROL (QUIET RUNNING dropped), the
## way a deal can lay it out, with the DATA to buy it.
func _board_with_damage_control() -> void:
	var b: Array[StringName] = [&"damage_control", &"patch_crew", &"black_box",
		&"spare_cells", &"vent_timing", &"cold_open",
		&"wide_sweep", &"fuel_trim", &"evasion_tables"]
	Run.board = b
	Run.board_owned = PackedInt32Array([0, 0, 0])
	Run.data = 99


func _gauge(key: StringName, bare := false) -> int:
	for a in Run.attributes():
		if a.key == key:
			return int(a.base if bare else a.value)
	return -99


func _logged(part: String) -> int:
	var n := 0
	for t in _logs:
		if part in t:
			n += 1
	return n


func _fight(id: StringName = &"cutter") -> Combat:
	var cb := Combat.new()
	cb.plan(DB.enemies[id], 1)
	return cb


## The cutter's hardest-hitting intent, as PlayerDeathTest aims it.
func _hit(e: Combat.EnemyState) -> IntentData:
	var best: IntentData = null
	for raw in e.template.loop:
		var i := raw as IntentData
		if best == null or i.damage * maxi(1, i.hits) > best.damage * maxi(1, best.hits):
			best = i
	return best


## The same intent with no damage, for an enemy turn that must not kill.
func _harmless(e: Combat.EnemyState) -> void:
	var i := _hit(e).duplicate(true) as IntentData
	i.damage = 0
	e.intent = i


# ------------------------------------------------------------ stat routines

func _damage_control() -> void:
	# Bought off the board, the way a player gets it: full stays full.
	_used()
	_board_with_damage_control()
	var n0 := Run.max_hp()
	Run.hp = n0
	Sig.ship_changed.emit()
	_ok("DAMAGE CONTROL bought off the board", Run.buy_step(0) and Run.has_routine(&"damage_control"))
	_ok("a full ship stays full: %d/%d to %d/%d" % [n0, n0, Run.hp, Run.max_hp()],
		Run.max_hp() == n0 + 7 and Run.hp == n0 + 7)
	_ok("the bare reading leaves it out (%d)" % Run.max_hp(true), Run.max_hp(true) == Run.hull.max_hull)
	# And a damaged one stays as far down as it was.
	_used()
	_board_with_damage_control()
	n0 = Run.max_hp()
	Run.hp = n0 - 7
	Sig.ship_changed.emit()
	Run.buy_step(0)
	_ok("a ship 7 down stays 7 down: %d/%d to %d/%d" % [n0 - 7, n0, Run.hp, Run.max_hp()],
		Run.max_hp() == n0 + 7 and Run.hp == n0)


func _vent_and_gauges() -> void:
	_used()
	Run.heat = 0
	var cap0 := Run.heat_cap()
	var d0 := Run.dissipation()
	var thm0 := _gauge(&"thermal")
	_own([&"vent_timing"])
	_ok("VENT TIMING: dissipation %d to %d" % [d0, Run.dissipation()], Run.dissipation() == d0 + 1)
	_ok("and heat capacity by 0 (%d to %d; THERMAL %d to %d)" % [cap0, Run.heat_cap(), thm0,
		_gauge(&"thermal")], Run.heat_cap() == cap0)
	# EACH PIP ROUTINE MOVES ITS GAUGE BY EXACTLY ONE, cold and at full hull,
	# and leaves the bare reading where it was (they count as fitted, call 15).
	for row in [[&"damage_control", &"hull"], [&"evasion_tables", &"maneuver"],
			[&"wide_sweep", &"sensors"], [&"quiet_running", &"stealth"]]:
		_used()
		Run.heat = 0
		Run.hp = Run.max_hp()
		Sig.ship_changed.emit()
		var g0 := _gauge(row[1])
		var b0 := _gauge(row[1], true)
		_own([row[0]])
		var g1 := _gauge(row[1])
		_ok("%s: %s %d to %d, bare %d to %d" % [DB.routines[row[0]].name, String(row[1]).to_upper(),
			g0, g1, b0, _gauge(row[1], true)], g1 == g0 + 1 and _gauge(row[1], true) == b0)
	# The raw numbers under two of them.
	_used()
	var s0 := Run.attr_sensors()
	var t0 := Run.attr_stealth()
	_own([&"wide_sweep", &"quiet_running"])
	_ok("WIDE SWEEP +1 sensors (%d to %d)" % [s0, Run.attr_sensors()], Run.attr_sensors() == s0 + 1)
	Run.heat = 0
	var cold := Run.attr_stealth()
	Run.heat = Run.heat_cap()
	_ok("QUIET RUNNING +1 stealth, before the heat comes off (%d at 5 heat; %d cold, %d at capacity)"
		% [t0, cold, Run.attr_stealth()], Run.attr_stealth() < cold)


func _dodge_cap() -> void:
	_used()
	var d0 := Run.dodge()
	_own([&"evasion_tables"])
	_ok("EVASION TABLES: dodge %.4f to %.4f" % [d0, Run.dodge()],
		absf(Run.dodge() - (d0 + 1.0 / 23.0)) < 0.0001)
	Run.hull.dodge = 0.59
	_ok("and dodge stops at 0.6 (%.3f)" % Run.dodge(), Run.dodge() == 0.6)


func _fuel_trim() -> void:
	_used()
	Run.installed.clear()
	Run.hull.fuel_factor = 1.0
	if not Run.hull.has_perk(&"deep_tanks"):
		Run.hull.tier_perks.append(&"deep_tanks")
	var f0 := Run.fuel_factor()
	_own([&"fuel_trim"])
	_ok("FUEL TRIM with Deep Tanks: %.3f to %.3f" % [f0, Run.fuel_factor()],
		absf(f0 - 0.9) < 0.0001 and absf(Run.fuel_factor() - 0.81) < 0.0001)
	_ok("and the bare reading leaves it out (%.3f)" % Run.fuel_factor(true), absf(Run.fuel_factor(true) - 0.9) < 0.0001)
	Run.hull.fuel_factor = 0.32
	_ok("and never under 0.3 (%.3f)" % Run.fuel_factor(), Run.fuel_factor() == 0.3)

	# A long hop drops, and none rises.
	_used()
	for raw in Run.map:
		(raw as MapGen.MapNode).sensed = true
	var here: MapGen.MapNode = Run.node_at()
	var dropped := ""
	var rose := 0
	for raw in Run.map:
		var t := raw as MapGen.MapNode
		_own([])
		var plain := Run._hop_cost(here, t)
		_own([&"fuel_trim"])
		var trim := Run._hop_cost(here, t)
		if trim > plain:
			rose += 1
		if trim < plain and plain >= 4 and dropped == "":
			dropped = "%d to %d" % [plain, trim]
	_ok("a long hop costs less (%s), and no hop more (%d)" % [dropped, rose], dropped != "" and rose == 0)

	# The way out `drain_fuel` keeps reads the trimmed factor too: somewhere on
	# this map it is lower with FUEL TRIM.
	Run.fuel = 40
	var lower := ""
	var higher := 0
	for raw in Run.map:
		Run.at = (raw as MapGen.MapNode).index
		_own([])
		Run._range_cache.clear()
		var plain := Run.fuel_floor()
		_own([&"fuel_trim"])
		Run._range_cache.clear()
		var trim := Run.fuel_floor()
		if trim > plain:
			higher += 1
		if trim < plain and lower == "":
			lower = "%d to %d at %d" % [plain, trim, Run.at]
	_ok("the way-out floor is trimmed (%s), and never raised (%d)" % [lower, higher],
		lower != "" and higher == 0)
	# A science reading's burn is a number of fuel, not a jump: not trimmed.
	Run.at = 0
	Run._range_cache.clear()
	Run.fuel = 40
	Run.drain_fuel(2)
	_ok("an event's fuel is not trimmed (40 less 2 is %d)" % Run.fuel, Run.fuel == 38)


func _spare_cells() -> void:
	_used()
	var cap0 := Run.power_cap()
	var e0 := Run.reactor()
	var lv0 := Run.reactor_level()
	# Parts that draw and raise nothing: one cell to fill to the cap, then
	# three and four cells over it.
	var by_cells := {}
	for id in DB.modules:
		var m := DB.modules[id] as ModuleData
		if m.reactor == 0 and m.affix_int(&"reactor") == 0 and not by_cells.has(m.cells()):
			by_cells[m.cells()] = m
	if not _ok("parts of 1, 3 and 4 cells to fit", by_cells.has(1) and by_cells.has(3) and by_cells.has(4)):
		return
	while Run.power_draw() < Run.power_cap():
		var f := (by_cells[1] as ModuleData).duplicate(true) as ModuleData
		Run.installed.append(f)
	var three := (by_cells[3] as ModuleData).duplicate(true) as ModuleData
	var four := (by_cells[4] as ModuleData).duplicate(true) as ModuleData
	var refused := not Run.can_power(three)
	_own([&"spare_cells"])
	_ok("SPARE CELLS: a part 3 cells over the cap refused before (%s), powered after (%s); cap %d to %d"
		% [refused, Run.can_power(three), cap0, Run.power_cap()],
		refused and Run.can_power(three) and Run.power_cap() == cap0 + 3)
	_ok("and one 4 over is still refused", not Run.can_power(four))
	_ok("and the reactor is not raised: energy %d to %d, level %d to %d" % [e0, Run.reactor(),
		lv0, Run.reactor_level()], Run.reactor() == e0 and Run.reactor_level() == lv0)


# ----------------------------------------------------------- fight routines

func _opening_turn() -> void:
	for owned in [false, true]:
		_used()
		_own([&"warm_start", &"first_look"] if owned else [])
		Run.hp = 999
		var cb := _fight()
		cb.begin(null)
		var e1 := cb.energy
		var h1 := cb.hand.size()
		_harmless(cb.enemies[0])
		cb.end_turn()
		var e2 := cb.energy
		var h2 := cb.hand.size()
		var add_e := 1 if owned else 0
		var add_h := 2 if owned else 0
		_ok("%s: turn 1 energy %d of %d, hand %d of %d; turn 2 energy %d, hand %d" % [
			"WARM START and FIRST LOOK" if owned else "without them", e1, Run.reactor(), h1,
			Run.hand_size(), e2, h2],
			e1 == Run.reactor() + add_e and h1 == Run.hand_size() + add_h
			and e2 == Run.reactor() and h2 <= Run.hand_size() and cb.turn == 2)
	# A ship joining on the party's turn seven has a first turn of its own.
	_used()
	_own([&"warm_start", &"first_look"])
	Run.hp = 999
	var late := _fight()
	late.turn = 7
	late.begin(null)
	_ok("a late joiner on turn 7 gets both (energy %d, hand %d)" % [late.energy, late.hand.size()],
		late.energy == Run.reactor() + 1 and late.hand.size() == Run.hand_size() + 2)


func _cold_open() -> void:
	for row in [[10, 6, true], [2, 0, true], [0, 0, true], [10, 10, false]]:
		_used()
		_own([&"cold_open"] if row[2] else [])
		Run.heat = row[0]
		var said := _logged("Cold open")
		var cb := _fight()
		cb.begin(null)
		var lines := _logged("Cold open") - said
		var want_line := 1 if row[0] != row[1] else 0
		_ok("COLD OPEN %s: heat %d to %d, %d line" % ["owned" if row[2] else "not owned", row[0],
			Run.heat, lines], Run.heat == row[1] and lines == want_line)


func _patch_crew() -> void:
	# [owned, calyx three, how far down, what it mends]
	for row in [[true, false, 10, 3], [true, false, 1, 1], [false, false, 10, 0],
			[true, true, 10, 6], [false, true, 10, 3]]:
		_used()
		_own([&"patch_crew"] if row[0] else [])
		if row[1]:
			Run.hull.manufacturer = &"calyx"
			for i in 2:
				Run.installed[i].manufacturer = &"calyx"
		Run.hp = Run.max_hp() - row[2]
		var hp0 := Run.hp
		var cb := _fight()
		cb.begin(null)
		cb._victory()
		_ok("a fight won, %s%s, %d down: +%d" % ["PATCH CREW" if row[0] else "no PATCH CREW",
			" and Calyx's three" if row[1] else "", row[2], Run.hp - hp0],
			Run.hp - hp0 == row[3] and Run.hp <= Run.max_hp())
	_used()
	_own([&"patch_crew"])
	Run.hp = Run.max_hp() - 10
	var hp1 := Run.hp
	var pod := _fight()
	pod.begin(null)
	pod._pacify()
	_ok("a fight pacified: +%d" % (Run.hp - hp1), Run.hp - hp1 == 3)
	# A flee mends nothing. A botched burn is a turn of fire, so try until one
	# gets away clean.
	var fled := false
	for i in 20:
		_used(SEED + 1 + i)
		_own([&"patch_crew"])
		Run.hp = Run.max_hp() - 10
		var hp2 := Run.hp
		var cb := _fight()
		cb.begin(null)
		cb.flee()
		if cb.result == &"fled":
			fled = true
			_ok("a fight fled: +%d" % (Run.hp - hp2), Run.hp == hp2)
			break
	_ok("a flee got away within 20 tries", fled)


func _black_box() -> void:
	# Enemy fire, as PlayerDeathTest aims it.
	Rng.forced = DEATH_SEED
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Run.hull.dodge = 0.0
	Run.installed.clear()
	_own([&"black_box"])
	var cb := _fight()
	cb.begin(null)
	var e: Combat.EnemyState = cb.enemies[0]
	var hit := _hit(e)
	var dmg := hit.damage * maxi(1, hit.hits)
	e.intent = hit
	cb.block = 0
	cb.brace = 0
	Run.hp = 5
	var said := _logged("BLACK BOX")
	cb._enemy_act()
	_ok("BLACK BOX: %s for %d at 5 hull leaves %d, alive, the box spent, one line" % [hit.name, dmg, Run.hp],
		dmg >= 5 and Run.hp == 1 and not Run.dead and Run.black_box_spent
		and _logged("BLACK BOX") - said == 1 and not cb.finished)
	e.intent = hit
	cb.block = 0
	cb.brace = 0
	cb._enemy_act()
	_ok("and the next killing hit kills (%s)" % Run.death_reason, Run.dead and cb.result == &"dead")

	# Without it the same hit kills: the control.
	Rng.forced = DEATH_SEED
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Run.hull.dodge = 0.0
	Run.installed.clear()
	var c0 := _fight()
	c0.begin(null)
	c0.enemies[0].intent = _hit(c0.enemies[0])
	c0.block = 0
	c0.brace = 0
	Run.hp = 5
	c0._enemy_act()
	_ok("without it the same hit kills", Run.dead)

	# An event's toll is not the fight's: it still kills.
	Rng.forced = DEATH_SEED
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	_own([&"black_box"])
	Run.hp = 3
	Run.take_hull_damage(10, "An event's toll.")
	_ok("an event's toll still kills, the box unspent", Run.dead and not Run.black_box_spent)

	# Overheat and junk are the fight's own damage: the box holds for each.
	for what in ["overheat", "junk"]:
		Rng.forced = DEATH_SEED
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
		_own([&"black_box"])
		var c2 := _fight()
		c2.begin(null)
		_harmless(c2.enemies[0])
		c2.hand.clear()
		Run.hp = 5
		if what == "overheat":
			Run.heat = Run.heat_cap() + 20
		else:
			Run.heat = 0
			var junk := CardData.new()
			junk.name = "Test Junk"
			junk.unplayable = true
			junk.hand_damage = 20
			c2.hand.append(junk)
		c2.end_turn()
		_ok("%s that would kill leaves %d, alive, the box spent" % [what, Run.hp],
			Run.hp == 1 and not Run.dead and Run.black_box_spent)


# -------------------------------------------------------------- a hull swap

func _swap() -> void:
	_used()
	_own(_all())
	Run.hp = Run.max_hp()
	var heavy := DB.at_tier(DB.hull_for(&"korvan", HullData.Weight.HEAVY), 0)
	var hp0 := Run.hp
	var mine := Run.hull
	_ok("all twelve owned", Run.owned_routines().size() == 12)
	Run.transfer_to_hull(heavy)
	_ok("full stays full into a heavy: %d/%d (the frame's %d and 7)" % [Run.hp, Run.max_hp(), heavy.max_hull],
		Run.max_hp() == heavy.max_hull + 7 and Run.hp == Run.max_hp())
	_ok("all twelve still owned after the move", Run.owned_routines().size() == 12)
	Run.abandon_move()
	_ok("BACK OUT restores the hull: %d (was %d), the old frame, all twelve" % [Run.hp, hp0],
		Run.hp == hp0 and Run.hull == mine and Run.owned_routines().size() == 12)
	# A damaged ship lands at the same share of the new max.
	Run.hp = Run.max_hp() - 20
	var ratio := float(Run.hp) / float(Run.max_hp())
	Run.transfer_to_hull(heavy)
	var want := maxi(6, int(round((heavy.max_hull + 7) * ratio)))
	_ok("20 down lands at the same share of the new max: %d, want %d" % [Run.hp, want], Run.hp == want)
	Run.abandon_move()
	# The yard's reading of a frame on the blocks: full, with the +7.
	var hull_pips := -1
	for a in Run.hull_attributes(heavy):
		if a.key == &"hull":
			hull_pips = int(a.value)
	var full_pips := maxi(0, int(round(Run.ATTR_MAX * float(heavy.max_hull + 7) / Run.HULL_REF)))
	_ok("the yard reads a new frame at full with DAMAGE CONTROL: HULL %d, want %d" % [hull_pips, full_pips],
		hull_pips == full_pips)
	# A new run clears it all.
	Run.data = 30
	Run.black_box_spent = true
	Rng.forced = SEED
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	_ok("a new run clears it: %d owned, %d DATA, owned %s, box spent %s, board %d, hull %d/%d"
		% [Run.owned_routines().size(), Run.data, str(Array(Run.board_owned)), Run.black_box_spent,
			Run.board.size(), Run.hp, Run.max_hp()],
		Run.owned_routines().is_empty() and Run.data == 0 and Run.board_owned == PackedInt32Array([0, 0, 0])
		and not Run.black_box_spent and Run.board.size() == 9 and Run.routines_granted.is_empty()
		and Run.routine_int(&"max_hull") == 0 and Run.hp == Run.max_hp())


func _all() -> Array:
	var out: Array = []
	for b in DB.BRANCHES:
		out.append_array(DB.routines_in(b))
	return out


# --------------------------------------------------------------- the orders

## A USED RUN WITH DAMAGE CONTROL, THEN A NEW RUN (S2's order, untestable
## there): `start_new_run` clears the last run's science BEFORE `fit_chassis`
## fills the hull. Swapped, the hull fills to the last run's +7, and the clear
## after it leaves 47 on a 40 frame until the `dross` setter's `ship_changed`
## clamps it; the fuel setter's `resources_changed` comes first, and anything
## drawing the hull then (the HUD) reads 47/40. So every `resources_changed` of
## the new run is watched, not only where it ends.
func _new_run_order() -> void:
	_used()
	_board_with_damage_control()
	Run.buy_step(0)
	Run.hp = Run.max_hp()
	var seen := {over = 0, worst = ""}
	var look := func() -> void:
		if Run.hull != null and Run.hp > Run.max_hp():
			seen["over"] = int(seen["over"]) + 1
			seen["worst"] = "%d/%d" % [Run.hp, Run.max_hp()]
	Sig.resources_changed.connect(look)
	Rng.forced = SEED + 7
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Sig.resources_changed.disconnect(look)
	_ok("a new run after DAMAGE CONTROL never shows more hull than its max (%d times, %s); ends %d/%d with +%d"
		% [int(seen.over), seen.worst, Run.hp, Run.max_hp(), Run.routine_int(&"max_hull")],
		int(seen.over) == 0 and Run.hp == Run.max_hp() and Run.routine_int(&"max_hull") == 0)


## A SAVE WITH DAMAGE CONTROL OWNED AND THE HULL AT BARE + 7 loads at bare + 7
## (S2's order): the science is read before the hull, so the load's clamp sees
## the +7 and leaves the hull alone. Read after the hull, the fuel setter's
## `resources_changed` shows 47/40 before it is read, and read after the load's
## own `ship_changed` the clamp takes the 7 for good. Watched the same way.
func _load_order() -> void:
	_used()
	_board_with_damage_control()
	Run.buy_step(0)
	Run.hp = Run.max_hp()
	var want := Run.hp
	var bare := Run.max_hp() - 7
	SaveGame.save()
	Rng.forced = SEED + 9
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var seen := {over = 0, worst = ""}
	var look := func() -> void:
		if Run.hull != null and Run.hp > Run.max_hp():
			seen["over"] = int(seen["over"]) + 1
			seen["worst"] = "%d/%d" % [Run.hp, Run.max_hp()]
	Sig.resources_changed.connect(look)
	var loaded := SaveGame.load_into_run()
	Sig.resources_changed.disconnect(look)
	_ok("a save with DAMAGE CONTROL at %d (bare %d) loads at %d/%d, never over its max (%d times, %s)"
		% [want, bare, Run.hp, Run.max_hp(), int(seen.over), seen.worst],
		loaded and Run.has_routine(&"damage_control") and Run.hp == want and Run.max_hp() == want
		and int(seen.over) == 0)
	SaveGame.clear()


# ---------------------------------------------------------------- the sim

func _sim_hook() -> void:
	var all := HeadlessSim.parse_routines("all")
	_ok("routines=all is the twelve (%d)" % all.size(), all.size() == 12 and Array(all) == _all())
	var some := HeadlessSim.parse_routines("damage_control,no_such,damage_control,fuel_trim")
	_ok("routines=a,b keeps the known, once each (%s)" % str(some),
		Array(some) == [&"damage_control", &"fuel_trim"])
	var sim := HeadlessSim.new()
	sim.grant_routines = some
	_used()
	sim.grant_at_launch()
	_ok("granted at launch: owned %s, hull %d/%d" % [str(Run.owned_routines()), Run.hp, Run.max_hp()],
		Run.has_routine(&"damage_control") and Run.has_routine(&"fuel_trim") and Run.hp == Run.max_hp())
	Rng.forced = SEED
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	_ok("and the next run's clear takes them away", Run.owned_routines().is_empty())
