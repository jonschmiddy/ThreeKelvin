extends Node

## The 45 tank (Jon, Oct 17): cap, event floor, hint and HUD readout, each read off the game.
## DATA (science) after FUEL on the bar: inside its clip, clear of FUEL, the worst case fitting.
## Price and rescue run in a used run (Jon, Oct 18), as a fresh run never meets that rule.
## Why: docs/why/FuelTest.md#fuel-tank-test

var _tree: SceneTree
var h := Harness.new()


func _ok(what: String, c: bool) -> bool:
	return h._ok(what, c)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_tree = get_tree()
	await Harness.frames(_tree, 2)
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	_cap()
	_price_and_rescue()
	_floor()
	_events_scaled()
	_flee_and_pulsar()
	await _hint()
	await _hud()
	_finish()


# ------------------------------------------------------------------ the cap

func _cap() -> void:
	_ok("a new run starts full: %d of %d" % [Run.fuel, Run.fuel_cap()],
		Run.fuel == 45 and Run.fuel_cap() == 45 and Run.start_fuel() == 45)
	Run.fuel = 200
	_ok("the setter holds a write under the top (200 -> %d)" % Run.fuel, Run.fuel == 45)
	Run.fuel = 40
	Run.fuel += 30
	_ok("a grant past the top stops at it (40 + 30 -> %d)" % Run.fuel, Run.fuel == 45)

	var dock := _a_station()
	if not _ok("a station to refuel at", dock != null):
		return
	Run.credits = 500
	Run.fuel = 45
	var c0 := Run.credits
	_ok("a full tank: REFUEL says TANK FULL and sells nothing",
		Run.refuel_blocked(dock) == "TANK FULL" and not Run.buy_refuel(dock) and Run.credits == c0)
	Run.fuel = 30
	var o := Run.refuel_offer(dock)
	var can := Market.refuel_price(dock)
	_ok("a top-up is the room left (%d), charged by the unit (%d of a can's %d)"
		% [int(o.units), int(o.cost), can],
		int(o.units) == 15 and int(o.cost) == int(ceil(can * 15.0 / Market.REFUEL_UNITS)))
	_ok("and buying it fills the tank for that price",
		Run.buy_refuel(dock) and Run.fuel == 45 and Run.credits == c0 - int(o.cost))
	Run.fuel = 10
	o = Run.refuel_offer(dock)
	_ok("an emptier tank buys a whole can at a can's price",
		int(o.units) == Market.REFUEL_UNITS and int(o.cost) == can)
	Run.fuel = 45


# ------------------------------------------------- the price and the way out

const STATION := MapGen.NodeType.STATION


## A hop flown as a jump flies one -- the fuel, the arrival, the chart --
## without `Run.jump_to`'s signal, which would open the arrival's screens.
func _hop(t: MapGen.MapNode) -> void:
	Run.fuel -= Run.fuel_cost_to(t)
	Run.at = t.index
	Run.trail.append(t.index)
	t.visited = true
	Run.chart_from(t)
	Run.jumps += 1


func _price_and_rescue() -> void:
	Rng.forced = 4243
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	# A used run: a fresh run has one dock charted and a full tank, which this rule never meets.
	var docks := 0
	var guard := 0
	while docks < 2 and guard < 40:
		guard += 1
		var pick: MapGen.MapNode = null
		for raw in Run.in_range():
			var t: MapGen.MapNode = raw
			if not Run.can_jump_to(t) or t.type == MapGen.NodeType.CORE or t.visited:
				continue
			if pick == null or (t.type == STATION and pick.type != STATION) \
					or (t.type == pick.type and Run.fuel_cost_to(t) < Run.fuel_cost_to(pick)):
				pick = t
		if pick == null:
			break
		_hop(pick)
		if pick.type == STATION:
			docks += 1
			if docks == 1:
				Run.credits = 300
				Run.hp = Run.max_hp() - 6
				Run.buy_refuel(pick)
				Run.add_credits(-Market.repair_price(pick, 6))
				Run.heal(6)
	var dock := Run.node_at()
	if not _ok("a used run: %d jumps, %d docks visited, %d credits, docked at %s"
			% [Run.jumps, docks, Run.credits, MapGen.star_name(dock)],
			docks == 2 and dock.type == STATION and Run.jumps >= 2 and Run.credits < 300):
		return

	# THE PRICE. A whole tank from empty, bought through the game's own REFUEL
	# at each rung of the service ladder, this dock standing in for each.
	var dev0 := dock.development
	var tank: Array = []
	for dev in 5:
		dock.development = dev as MapGen.Development
		Run.fuel = 0
		Run.credits = 999
		var g := 0
		while Run.refuel_blocked(dock) == "" and g < 6:
			g += 1
			if not Run.buy_refuel(dock):
				break
		tank.append(999 - Run.credits if Run.fuel == 45 else -1)
	dock.development = dev0
	_ok("a whole tank from empty at an outpost costs %d credits (55-60)" % int(tank[1]),
		int(tank[1]) >= 55 and int(tank[1]) <= 60)
	_ok("and follows the service ladder: unclaimed %d, outpost %d, settlement %d, city %d, capital %d"
		% tank, int(tank[0]) > int(tank[1]) and int(tank[1]) > int(tank[2])
		and int(tank[2]) > int(tank[3]) and int(tank[3]) > int(tank[4]) and int(tank[4]) > 0)

	# THE WAY OUT. The cheapest other dock, the game's against this test's.
	var game := Run.nearest_other_dock()
	var mine := _my_cheapest_other_dock()
	if not _ok("the cheapest other dock: the game's %s at %d fuel, this test's %s at %d"
			% [MapGen.star_name(game.node) if not game.is_empty() else "none", int(game.get("fuel", -1)),
				MapGen.star_name(mine.node) if not mine.is_empty() else "none", int(mine.get("fuel", -1))],
			not game.is_empty() and not mine.is_empty() and int(game.fuel) == int(mine.fuel)
			and int(game.fuel) > 0 and (game.node as MapGen.MapNode).index != dock.index):
		return
	var need := int(game.fuel)
	var name := MapGen.star_name(game.node)
	var can := Market.refuel_price(dock)
	var priced := int(ceil(can * float(need) / Market.REFUEL_UNITS))

	# Broke, on an empty tank: exactly the fuel to the dock, for every credit.
	Run.fuel = 0
	Run.credits = mini(can - 1, priced)
	var c0 := Run.credits
	var o := Run.refuel_offer(dock)
	_ok("broke (%d credits, a can is %d) on an empty tank: REFUEL offers the %d fuel to reach %s, for %d"
		% [c0, can, int(o.units), name, int(o.cost)],
		o.get("rescue", false) and int(o.units) == need and int(o.cost) == c0
		and (o.dock as MapGen.MapNode).index == (game.node as MapGen.MapNode).index)
	_ok("its line, plain: \"%s\"" % Run.rescue_line(o),
		Run.rescue_line(o) == "Enough fuel to reach %s: all your credits." % name)
	_ok("bought: the tank holds %d, exactly the way to the dock, and credits are %d"
		% [Run.fuel if Run.buy_refuel(dock) else -1, Run.credits],
		Run.fuel == need and Run.credits == 0)
	var again := Run.refuel_offer(dock)
	_ok("again: no way out offered (the dock is in reach), and nothing more sells (tank %d, %d credits)"
		% [Run.fuel, Run.credits],
		not again.get("rescue", false) and not Run.buy_refuel(dock) and Run.fuel == need and Run.credits == 0)
	# One short of the dock, with nothing: one unit, free, and no more.
	Run.fuel = need - 1
	o = Run.refuel_offer(dock)
	_ok("one short with 0 credits: one unit, free: \"%s\"" % Run.rescue_line(o),
		o.get("rescue", false) and int(o.units) == 1 and int(o.cost) == 0
		and Run.rescue_line(o) == "Enough fuel to reach %s. You have no credits, so it is free." % name)
	Run.buy_refuel(dock)
	Run.buy_refuel(dock)
	Run.buy_refuel(dock)
	_ok("three presses later the tank holds %d, still the way to the dock" % Run.fuel, Run.fuel == need)
	# Some credits, not a can's worth, and the fuel costs less than them: the
	# fuel's price, not the purse.
	if priced < can - 1:
		Run.fuel = 0
		Run.credits = can - 1
		o = Run.refuel_offer(dock)
		_ok("%d credits, the fuel to the dock priced %d: it costs %d and leaves %d"
			% [can - 1, priced, int(o.cost), can - 1 - int(o.cost)],
			o.get("rescue", false) and int(o.cost) == priced
			and Run.rescue_line(o) == "Enough fuel to reach %s: %d credits." % [name, priced])

	# Not offered when the can is affordable, when a dock is in reach, or away.
	Run.fuel = 0
	Run.credits = can
	o = Run.refuel_offer(dock)
	_ok("a can's price in hand (%d): the ordinary can, %d fuel for %d" % [can, int(o.units), int(o.cost)],
		not o.get("rescue", false) and int(o.units) == Market.REFUEL_UNITS and int(o.cost) == can)
	Run.fuel = need
	Run.credits = 0
	_ok("the dock already in reach (%d fuel), broke: no way-out offer" % need,
		Run.dock_rescue(dock).is_empty() and not Run.refuel_offer(dock).get("rescue", false))
	var away: MapGen.MapNode = null
	for raw in Run.in_range():
		if (raw as MapGen.MapNode).type != STATION and (raw as MapGen.MapNode).type != MapGen.NodeType.CORE:
			away = raw
			break
	if away != null:
		Run.at = away.index
		Run.fuel = 0
		_ok("broke and empty but not at the dock: no way-out offer from it",
			Run.dock_rescue(dock).is_empty() and not Run.refuel_offer(dock).get("rescue", false))
		Run.at = dock.index

	# AND THEN FLOWN: the rescue's fuel, along this test's path, hop by hop on
	# the chart's own rule (`can_jump_to`), lands on a dock.
	Run.fuel = need
	var path: Array = mine.path
	var flew := true
	for raw in path:
		var t: MapGen.MapNode = raw
		if not Run.can_jump_to(t):
			flew = false
			break
		_hop(t)
	_ok("flown on %d fuel: %d hop%s, landed on %s with %d left"
		% [need, path.size(), "" if path.size() == 1 else "s", MapGen.star_name(Run.node_at()), Run.fuel],
		flew and Run.node_at().type == STATION and Run.fuel >= 0)

	# A FAR DOCK TOO: on a heavy frame (dearer hops), the dock in this galaxy
	# whose cheapest other dock is the furthest, as the chart around it shows.
	Run.fit_chassis(&"korvan", HullData.Weight.HEAVY)
	var far: MapGen.MapNode = null
	var far_d := {}
	for raw in Run.map:
		var s: MapGen.MapNode = raw
		if s.type != STATION:
			continue
		_stand(s)
		var d := _my_cheapest_other_dock()
		if not d.is_empty() and (far_d.is_empty() or int(d.fuel) > int(far_d.fuel)):
			far = s
			far_d = d
	# Docks sit a hop apart, so the nearest are taken out of sight until the way out is two hops.
	if far != null:
		_stand(far)
		var hid := 0
		while not far_d.is_empty() and (far_d.path as Array).size() < 2 and hid < 8:
			(far_d.path[0] as MapGen.MapNode).sensed = false
			hid += 1
			far_d = _my_cheapest_other_dock()
	if not _ok("a dock far from the next one it knows: %s, %d fuel and %d hops on a heavy frame"
			% [MapGen.star_name(far) if far != null else "none", int(far_d.get("fuel", 0)),
				(far_d.get("path", []) as Array).size()],
			far != null and not far_d.is_empty() and int(far_d.fuel) >= 4 and (far_d.path as Array).size() >= 2):
		return
	game = Run.nearest_other_dock()
	need = int(far_d.fuel)
	Run.fuel = 0
	Run.credits = 5
	o = Run.refuel_offer(far)
	_ok("broke (5 credits) and empty there: the offer is %d fuel to %s for %d (the game's search: %d)"
		% [int(o.get("units", 0)), MapGen.star_name(o.dock) if o.has("dock") else "none",
			int(o.get("cost", -1)), int(game.get("fuel", -1))],
		o.get("rescue", false) and int(o.units) == need and int(game.fuel) == need and int(o.cost) == 5)
	Run.buy_refuel(far)
	_ok("bought: %d fuel, 0 credits, and pressing again sells nothing" % Run.fuel,
		Run.fuel == need and Run.credits == 0 and not Run.buy_refuel(far) and Run.fuel == need)
	flew = true
	var why := ""
	for raw in far_d.path:
		var t: MapGen.MapNode = raw
		if not Run.can_jump_to(t):
			why = " (refused %s: sensed %s, visited %s, reach %s, costs %d of %d)" % [MapGen.star_name(t),
				t.sensed, t.visited, Run.reachable(t), Run.fuel_cost_to(t), Run.fuel]
			flew = false
			break
		_hop(t)
	_ok("flown: %d hops, landed on %s with %d left%s"
		% [(far_d.path as Array).size(), MapGen.star_name(Run.node_at()), Run.fuel, why],
		flew and Run.node_at().type == STATION and Run.fuel >= 0)
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))


## This test's own search for the least fuel to another dock, restating the jump formula.
func _my_cheapest_other_dock() -> Dictionary:
	var here := Run.node_at()
	var cost := {here.index: 0}
	var prev := {}
	var todo: Array = [here.index]
	var seen := {}
	while not todo.is_empty():
		todo.sort_custom(func(a: int, b: int) -> bool: return int(cost[a]) < int(cost[b]))
		var i: int = todo.pop_front()
		if seen.has(i):
			continue
		seen[i] = true
		var at: MapGen.MapNode = Run.map[i]
		if at.type == STATION and i != here.index:
			var path: Array = []
			var k := i
			while k != here.index:
				path.push_front(Run.map[k])
				k = int(prev[k])
			return {node = at, fuel = int(cost[i]), path = path}
		for raw in Run.map:
			var t: MapGen.MapNode = raw
			if seen.has(t.index) or t.type == MapGen.NodeType.CORE or not Run.reachable_from(at, t):
				continue
			if not (t.sensed if i == here.index else MapGen.hop_distance(at, t) <= Run.sense_radius_of(at)):
				continue
			var hop := clampi(int(round(Run.fuel_factor() * MapGen.hop_distance(at, t)
				* Run.FUEL_PER_DISC_RADIUS)), 1, Run.FUEL_MAX_HOP)
			var c := int(cost[i]) + hop
			if c > 45 or (cost.has(t.index) and int(cost[t.index]) <= c):
				continue
			cost[t.index] = c
			prev[t.index] = i
			todo.append(t.index)
	return {}


# ------------------------------------------------------------------ the floor

func _floor() -> void:
	# A system with a dock in sight and range, and one with none.
	var with_dock: MapGen.MapNode = null
	var without: MapGen.MapNode = null
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		if n.type == MapGen.NodeType.STATION or n.type == MapGen.NodeType.CORE:
			continue
		Run.at = n.index
		Run.chart_from(n)
		var dock := false
		for t in Run.in_range():
			if (t as MapGen.MapNode).sensed and (t as MapGen.MapNode).type == MapGen.NodeType.STATION:
				dock = true
		if dock and with_dock == null:
			with_dock = n
		elif not dock and without == null:
			without = n
		if with_dock != null and without != null:
			break
	if _ok("a system with a dock in sight", with_dock != null):
		_stand(with_dock)
		var keep := 999
		for t in Run.in_range():
			var tn: MapGen.MapNode = t
			if tn.sensed and tn.type == MapGen.NodeType.STATION:
				keep = mini(keep, Run.fuel_cost_to(tn))
		Run.fuel = 40
		Run.drain_fuel(100)
		_ok("an event taking 100 of 40 leaves the fuel to reach the dock (%d, the dock costs %d)"
			% [Run.fuel, keep], Run.fuel == keep)
	if _ok("a system with no dock in sight", without != null):
		_stand(without)
		var limp := 999
		for t in Run.in_range():
			var tn: MapGen.MapNode = t
			if tn.sensed:
				limp = mini(limp, Run.fuel_cost_to(tn))
		Run.fuel = 40
		Run.drain_fuel(100)
		_ok("with none, it leaves three of the cheapest jump (%d = 3 x %d)" % [Run.fuel, limp],
			Run.fuel == 3 * limp)
		Run.fuel = 2
		Run.drain_fuel(10)
		_ok("it never adds fuel: 2 stays 2 (%d)" % Run.fuel, Run.fuel == 2)
		Run.fuel = 40
		Run.drain_fuel(2)
		_ok("a small drain is taken whole (40 - 2 = %d)" % Run.fuel, Run.fuel == 38)
	Run.fuel = 45


## Drains and grants were rescaled from a 279 tank to 45, so counted at least, not exactly.
## Flee and the pulsar are on the 45 scale (Jon: flee:A, pulsar:C).
## Why: docs/why/FuelTest.md#event-drains
func _flee_and_pulsar() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/systems/Combat.gd")
	var bare := RegEx.create_from_string("Run\\.fuel\\s*=\\s*maxi\\(0").search_all(src)
	_ok("a flee costs %d, %d more on a partial, and burns through the floor (%d bare writes)"
		% [Combat.FLEE_FUEL, Combat.FLEE_FUEL_PARTIAL, bare.size()],
		Combat.FLEE_FUEL == 1 and Combat.FLEE_FUEL_PARTIAL == 2 and bare.is_empty()
		and src.contains("Run.drain_fuel(FLEE_FUEL)") and src.contains("Run.drain_fuel(FLEE_FUEL_PARTIAL)"))
	var p: MapGen.MapNode = null
	for raw in Run.map:
		if (raw as MapGen.MapNode).type == MapGen.NodeType.PULSAR and not (raw as MapGen.MapNode).cleared:
			p = raw
			break
	if not _ok("a pulsar to fly", p != null):
		return
	var at0 := Run.at
	Run.at = p.index
	Run.chart_from(p)
	Run.hp = Run.max_hp()
	Run.fuel = 10
	Run.harvest_pulsar()
	_ok("the beam pays 14 + danger %d: 10 -> %d" % [p.danger, Run.fuel],
		Run.fuel == mini(45, 10 + 14 + p.danger))
	p.cleared = false
	Run.hp = Run.max_hp()
	Run.fuel = 40
	Run.harvest_pulsar()
	_ok("and stops at the top: 40 -> %d" % Run.fuel, Run.fuel == 45)
	p.cleared = false
	Run.at = at0
	Run.chart_from(Run.node_at())
	Run.hp = Run.max_hp()
	Run.heat = 0
	Run.fuel = 45


func _events_scaled() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/systems/OptionTable.gd")
	for f in DirAccess.get_files_at("res://scripts/systems/options"):
		if f.ends_with(".gd"):
			src += FileAccess.get_file_as_string("res://scripts/systems/options/" + f)
	var raw := RegEx.create_from_string("Run\\.fuel\\s*=\\s*maxi\\(0,\\s*Run\\.fuel\\s*-").search_all(src)
	_ok("no event outcome takes fuel past the floor (%d bare drains)" % raw.size(), raw.is_empty())
	var drains := RegEx.create_from_string("Run\\.drain_fuel\\((\\d+)\\)").search_all(src)
	var grants := RegEx.create_from_string("Run\\.fuel \\+= (\\d+)").search_all(src)
	var big := 0
	for m in drains + grants:
		big = maxi(big, int(m.get_string(1)))
	_ok("%d drains and %d grants (109 and 47 when rescaled), none over 6 units (largest %d)"
		% [drains.size(), grants.size(), big],
		drains.size() >= 109 and grants.size() >= 47 and big <= 6)


# ------------------------------------------------------------------ the hint

func _hint() -> void:
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Hints.forced = true
	Hints.set_process(false)
	Hints.set_process_input(false)
	Hints.reset()
	for id in Hints.ORDER:
		if id != &"fuel":
			Hints.mark_seen(id)
	_ok("low is a third of the tank: %d of %d" % [Run.fuel_low_at(), Run.fuel_cap()],
		Run.fuel_low_at() == 15)
	Router.show_starchart()
	await Harness.frames(_tree, 40)
	Run.fuel = 16
	await _poll(1.5)
	_ok("16 of 45: no fuel hint", Hints.card == null and Hints.probe(&"fuel").is_empty())
	Run.fuel = 15
	await _poll(1.5)
	var up := Hints.card != null and is_instance_valid(Hints.card) and Hints.card.id == &"fuel"
	_ok("15 of 45: the fuel hint shows on the chart", up)
	var line := Hints.fuel_dock_line()
	var drawn: Array = []
	if up:
		for l in Hints.card.find_children("*", "Label", true, false):
			drawn.append((l as Label).text)
	_ok("the card reads %s" % [drawn],
		drawn == ["Fuel is low. Run dry and the run ends.", line])
	# the dock it names, against a search written here
	var mine := _my_nearest_dock()
	if mine.is_empty():
		_ok("no dock in reach on 15: it says what to do", line.begins_with("No dock in reach."))
	else:
		var want := "Nearest dock: %s, %d jump%s." % [MapGen.star_name(mine.node), int(mine.jumps),
			"" if int(mine.jumps) == 1 else "s"]
		var game := Run.nearest_dock()
		_ok("it names the nearest dock in reach (%s; this test's search: %d jumps, the game's: %d)"
			% [line, int(mine.jumps), int(game.get("jumps", -1))],
			not game.is_empty() and int(game.jumps) == int(mine.jumps)
			and (game.node as MapGen.MapNode).type == MapGen.NodeType.STATION
			and line == "Nearest dock: %s, %d jump%s." % [MapGen.star_name(game.node),
				int(game.jumps), "" if int(game.jumps) == 1 else "s"]
			and line == want)
	# A DOCK ONE JUMP OFF AND ONE FURTHER, wherever the map has them: the line
	# names it, with the jumps, and agrees with this test's own search
	var cases := {1: false, 2: false}
	# Visited docks stay charted; one out of sight counts once a star on the way sees it.
	for raw in Run.map:
		if (raw as MapGen.MapNode).type == MapGen.NodeType.STATION:
			(raw as MapGen.MapNode).visited = true
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		if n.type != MapGen.NodeType.SYSTEM or (cases[1] and cases[2]):
			continue
		_stand(n)
		Run.fuel = 15
		var m := _my_nearest_dock()
		if m.is_empty():
			continue
		var k := int(m.jumps)
		if k != 1 and k != 2 or cases[k]:
			continue
		cases[k] = true
		var g := Run.nearest_dock()
		var j := int(m.jumps)
		var want_line := "Nearest dock: %s, %d jump%s." % [MapGen.star_name(g.get("node", n)), j, "" if j == 1 else "s"]
		_ok("%d jump%s from a dock: \"%s\" (this test's search: %s, %d jumps)" % [j, "" if j == 1 else "s",
			Hints.fuel_dock_line(), MapGen.star_name(m.node), j],
			not g.is_empty() and int(g.jumps) == j and int(g.fuel) == int(m.fuel)
			and (g.node as MapGen.MapNode).type == MapGen.NodeType.STATION
			and Hints.fuel_dock_line() == want_line)
	_ok("found a dock one jump off and one further off to name", cases[1] and cases[2])
	_hint_unflyable()
	# with nothing in the tank there is no dock in reach
	Run.fuel = 0
	_ok("an empty tank: \"%s\"" % Hints.fuel_dock_line(),
		Hints.fuel_dock_line() == "No dock in reach. Make short jumps and look for one.")
	# in a station's system: refuel here at the station itself, and elsewhere in
	# its system fly to it (the dock is only offered there, dock:A)
	var st := _a_station()
	if st != null:
		Run.at = st.index
		Run.chart_from(st)
		Run.fuel = 10
		ParkedShips.spots.erase(st.index)
		_ok("in a station's system, not at the station: \"%s\"" % Hints.fuel_dock_line(),
			Hints.fuel_dock_line() == "Fly to the station here to refuel.")
		Router.park_at_station(st)
		_ok("at the station: \"%s\"" % Hints.fuel_dock_line(), Hints.fuel_dock_line() == "Refuel here before you leave.")
	Hints._close(false)
	Hints.forced = false
	Run.fuel = 45


## Jon, Oct 18: a heavy frame reaches past its dish, so the chart showed unflyable docks.
## Why: docs/why/FuelTest.md#unflyable-dock-hint
func _hint_unflyable() -> void:
	Run.fit_chassis(&"korvan", HullData.Weight.HEAVY)
	var at0 := Run.at
	var found := false
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		if n.type != MapGen.NodeType.SYSTEM:
			continue
		_stand(n)
		Run.fuel = 15
		var chart := _my_nearest_dock(true)
		if chart.is_empty() or int(chart.jumps) != 1 or (chart.node as MapGen.MapNode).sensed:
			continue
		found = true
		var bad: MapGen.MapNode = chart.node
		var mine := _my_nearest_dock()
		var game := Run.nearest_dock()
		var line := Hints.fuel_dock_line()
		var want := "No dock in reach. Make short jumps and look for one."
		if not mine.is_empty():
			var j := int(mine.jumps)
			want = "Nearest dock: %s, %d jump%s." % [MapGen.star_name(mine.node), j, "" if j == 1 else "s"]
		_ok("the chart's route names %s, 1 jump, which the ship cannot fly to (can_jump_to %s)"
			% [MapGen.star_name(bad), Run.can_jump_to(bad)], not Run.can_jump_to(bad))
		_ok("the hint names the dock it can reach: \"%s\" (this test's search: %s)"
			% [line, "none" if mine.is_empty() else "%s, %d jumps" % [MapGen.star_name(mine.node), int(mine.jumps)]],
			line == want and not (not game.is_empty() and game.node == bad and int(game.jumps) == 1)
			and (mine.is_empty() == game.is_empty())
			and (mine.is_empty() or (int(game.jumps) == int(mine.jumps) and int(game.fuel) == int(mine.fuel))))
		var v := Hints.values(&"fuel")
		_ok("A.S.H.'s fields agree: %s" % [v],
			(mine.is_empty() and not v.has("name"))
			or (not mine.is_empty() and String(v.get("name", "")) == MapGen.star_name(game.node)
				and int(v.get("jumps", -1)) == int(game.jumps)))
		if not mine.is_empty():
			# and that dock really is flown to, hop by hop on the game's rule
			var path := _fly_to_dock(int(mine.jumps))
			_ok("flown there on 15: %s" % path, path.ends_with(", dock"))
		break
	_ok("found a dock the chart draws in reach and out of sight", found)
	Run.fit_chassis(&"korvan", HullData.Weight.MEDIUM)
	_stand(Run.map[at0])


## Flies the hint's route as a pilot would, each hop to a star `can_jump_to` allows.
func _fly_to_dock(jumps: int) -> String:
	var said: Array = []
	for i in jumps:
		var g := Run.nearest_dock()
		if g.is_empty():
			return "stopped, no dock in reach after %s" % [said]
		if int(g.jumps) == 0:
			break
		var next: MapGen.MapNode = null
		var goal: MapGen.MapNode = g.node
		if int(g.jumps) == 1:
			next = goal
		else:
			for raw in Run.in_range():
				var t: MapGen.MapNode = raw
				if not Run.can_jump_to(t) or t.type == MapGen.NodeType.CORE:
					continue
				var f0 := Run.fuel
				var at0 := Run.at
				Run.fuel -= Run.fuel_cost_to(t)
				Run.at = t.index
				Run.chart_from(t)
				var after := Run.nearest_dock()
				Run.at = at0
				Run.fuel = f0
				Run.chart_from(Run.node_at())
				if not after.is_empty() and int(after.jumps) == int(g.jumps) - 1:
					next = t
					break
		if next == null or not Run.can_jump_to(next):
			return "stopped at %s, %s refused" % [MapGen.star_name(Run.node_at()),
				"nothing" if next == null else MapGen.star_name(next)]
		said.append(MapGen.star_name(next))
		_hop(next)
	return "%s, %d left, %s" % [said, Run.fuel, "dock" if Run.node_at().type == MapGen.NodeType.STATION else "no dock"]


func _poll(secs: float) -> void:
	var t := 0.0
	while t < secs:
		Hints.poll(1.0 / 30.0)
		await _tree.process_frame
		t += 1.0 / 30.0


## Written apart from `Run.nearest_dock` so the two can disagree. `by_chart` is the old buggy rule.
## Why: docs/why/FuelTest.md#nearest-dock-search
func _my_nearest_dock(by_chart := false) -> Dictionary:
	var here := Run.node_at()
	var cost := {here.index: 0}
	var layer: Array = [here]
	for jumps in range(1, 40):
		var next: Array = []
		var best: Dictionary = {}
		for a in layer:
			var from: MapGen.MapNode = a
			for raw in Run.map:
				var t: MapGen.MapNode = raw
				if t.index == from.index or not Run.reachable_from(from, t):
					continue
				if by_chart and not Run.charted(t):
					continue
				if not by_chart and (t.type == MapGen.NodeType.CORE or not (t.sensed if from == here
						else MapGen.hop_distance(from, t) <= Run.sense_radius_of(from))):
					continue
				var d := MapGen.hop_distance(from, t)
				var c: int = int(cost[from.index]) + clampi(int(round(Run.fuel_factor() * d
					* Run.FUEL_PER_DISC_RADIUS)), 1, Run.FUEL_MAX_HOP)
				if c > Run.fuel or (cost.has(t.index) and int(cost[t.index]) <= c):
					continue
				cost[t.index] = c
				next.append(t)
				if t.type == MapGen.NodeType.STATION and (best.is_empty() or c < int(best.fuel)):
					best = {node = t, jumps = jumps, fuel = c}
		if not best.is_empty():
			return best
		if next.is_empty():
			return {}
		layer = next
	return {}


# ------------------------------------------------------------------ the HUD

func _hud() -> void:
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Router.show_local()
	await Harness.frames(_tree, 40)
	var hud: HudBar = Router.hud
	if not _ok("the HUD is up", hud != null and hud.is_visible_in_tree()):
		return
	for dev in [false, true]:
		DevMode.enabled = dev
		Sig.dev_mode_changed.emit()
		await Harness.frames(_tree, 4)
		var tag := "dev mode %s" % ("on" if dev else "off")
		for screen in [&"local", &"chart"]:
			if screen == &"chart":
				Router.show_starchart()
			else:
				Router.show_local()
			await Harness.frames(_tree, 40)
			for f in [45, 15, 1]:
				Run.fuel = f
				hud.refresh()
				await Harness.frames(_tree, 2)
				_readout(hud, f, "%s, %s, %d/45" % [tag, screen, f])
	DevMode.enabled = false
	Sig.dev_mode_changed.emit()
	await Harness.frames(_tree, 4)
	# with hints off, as in a party, the readout still warns
	Hints.forced = false
	_ok("hints are off here, as in a party", not Hints.enabled())
	for pair in [[15, 1], [1, 2]]:
		Run.fuel = pair[0]
		hud.refresh()
		await Harness.frames(_tree, 2)
		var v := hud._fuel.get_node("Value") as Label
		_ok("hints off, %d/45: the figure still turns %s" % [pair[0], ["", "amber", "red"][pair[1]]],
			v.get_theme_color("font_color") == HudBar.FUEL_INK[pair[1]] and HudBar.fuel_state() == pair[1])
	Run.fuel = 45
	hud.refresh()
	await _worst(hud)


func _readout(hud: HudBar, f: int, tag: String) -> void:
	var v := hud._fuel.get_node("Value") as Label
	var state := 0 if f == 45 else (1 if f == 15 else 2)
	_ok("%s: reads \"%s\"" % [tag, v.text], v.text == "%d/45" % f)
	_ok("%s: state %d, the figure's colour and the bar's fill agree" % [tag, HudBar.fuel_state()],
		HudBar.fuel_state() == state and v.get_theme_color("font_color") == HudBar.FUEL_INK[state]
		and hud._fuel_bar.state == state)
	var inner := HudBar.FuelBar.W - 2
	_ok("%s: the bar lights %d of %d pixels" % [tag, hud._fuel_bar.lit_px(), inner],
		hud._fuel_bar.lit_px() == clampi(int(round(f / 45.0 * inner)), 1, inner))
	# THE BOX TEST
	var view := hud.get_viewport().get_visible_rect()
	var bar := hud.get_global_rect()
	var parts: Array = hud.fuel_parts()
	var whole := hud.fuel_rect()
	var inside := true
	for p in parts:
		var r := (p as Control).get_global_rect()
		inside = inside and bar.encloses(r) and view.encloses(r) and r.size.x > 0.0
	_ok("%s: FUEL, the bar and the figure are inside the HUD and on screen (%s in %s)"
		% [tag, whole, bar], inside and parts.size() == 3)
	# nothing laid out has run past the clip: the row fits the bar
	var row: Control = hud._row
	var clip: Control = row.get_parent()
	_ok("%s: the row fits its bar (wants %d of %d)" % [tag, int(row.get_combined_minimum_size().x),
		int(clip.size.x)], row.get_combined_minimum_size().x <= clip.size.x)
	# clear of every other thing on the bar
	var hits: Array = []
	for c in row.find_children("*", "Control", true, false):
		var cc: Control = c
		if not cc.is_visible_in_tree() or cc.size.x <= 0.0 or cc == hud._fuel or hud._fuel.is_ancestor_of(cc):
			continue
		if cc.is_ancestor_of(hud._fuel) or cc.get_child_count() > 0 and not (cc is Button):
			continue
		if cc.get_global_rect().intersects(whole):
			hits.append(cc.name)
	_ok("%s: clear of every tab, gauge and readout on the bar %s" % [tag, hits], hits.is_empty())
	var g := hud.goal_rect()
	_ok("%s: clear of the goal line (%s)" % [tag, g], g.size == Vector2.ZERO or not g.intersects(whole))
	_ok("%s: never below the bar, where the goal line and A.S.H.'s corner are, and on the right half"
		% tag, whole.end.y <= bar.end.y and whole.position.x > view.size.x * 0.5)
	# A.S.H.'s every spot (`Ash.survey_boxes`: top left first, all eight) on LOCAL
	var cur := Router.current as Control
	if cur is SectorScreen:
		var spots := Ash.survey_boxes(cur)
		var on: Array = []
		for sp: Dictionary in spots:
			if (sp.rect as Rect2).intersects(whole):
				on.append(sp.name)
		_ok("%s: clear of all %d of A.S.H.'s spots, top left first %s" % [tag, spots.size(), on],
			spots.size() > 0 and on.is_empty())
	# not pressable
	var pressable := false
	for p in parts:
		var pc: Control = p
		pressable = pressable or pc is BaseButton or pc.focus_mode != Control.FOCUS_NONE \
			or pc.mouse_default_cursor_shape != Control.CURSOR_ARROW
	_ok("%s: not pressable (no button, no focus, the arrow cursor)" % tag, not pressable)
	_data_box(hud, tag, whole)


## DATA (science, pick 1A), after FUEL: its word and figure inside the bar's
## CLIP (932 at a 960 window, the bar less its padding: what is past it is cut,
## not drawn) and on screen, clear of FUEL and right of it, reading the run's
## DATA. Shown from launch at 0 (plan call 9), so no state hides it.
func _data_box(hud: HudBar, tag: String, fuel: Rect2) -> void:
	var view := hud.get_viewport().get_visible_rect()
	var clip := (hud._row.get_parent() as Control).get_global_rect()
	var parts: Array = hud._data.get_children() if hud._data != null else []
	var d := hud.data_rect()
	var inside := parts.size() == 2
	for p in parts:
		var r := (p as Control).get_global_rect()
		inside = inside and clip.encloses(r) and view.encloses(r) and r.size.x > 0.0
	_ok("%s: DATA, its word and figure, inside the bar's %d px clip and on screen (%s in %s)"
		% [tag, int(clip.size.x), d, clip], inside)
	_ok("%s: DATA clear of FUEL and after it (%s, FUEL %s)" % [tag, d, fuel],
		d.size.x > 0.0 and not d.intersects(fuel) and d.position.x >= fuel.end.x)
	var v: Label = hud._data.get_node("Value") as Label if hud._data != null else null
	_ok("%s: DATA reads the run's %d (\"%s\")" % [tag, Run.data, v.text if v != null else "?"],
		v != null and v.text == str(Run.data))
	_ok("%s: DATA in stat_nodes, for a reading's result to fly to" % tag,
		hud._data != null and hud.stat_nodes("data") == [hud._data])
	# The hovers: DATA says what DATA is, word and figure alike; CREDITS says
	# both, since that is where a player asks what the new number beside it is.
	var data_tip := Widgets.tip(CreditChit.WHAT_DATA_IS)
	var both_tip := Widgets.tip("%s\n%s" % [CreditChit.WHAT_MONEY_IS, CreditChit.WHAT_DATA_IS])
	var tips_ok := hud._data != null and hud._data.tooltip_text == data_tip \
		and hud._scrap.tooltip_text == both_tip
	for p in parts:
		tips_ok = tips_ok and (p as Control).tooltip_text == data_tip
	for p in hud._scrap.get_children():
		tips_ok = tips_ok and (p as Control).tooltip_text == both_tip
	_ok("%s: DATA's hover says what DATA is, CREDITS' says money then DATA" % tag, tips_ok)


## THE WORST CASE THE BAR CAN BE ASKED TO HOLD: in a party (the PARTY tab
## shows), over the heat cap (the long "41 — 19 HULL" form), 9999 credits and
## 99 DATA. In player mode the row must fit its 932 clip; in developer mode
## (CARDS, MODULES and the gap before them) it may clip, and the figure prints
## so the next thing added here can be weighed against it.
func _worst(hud: HudBar) -> void:
	var was_state = Net.state
	var was := [Run.credits, Run.data, Run.heat]
	Net.state = Net.State.HOSTING
	Run.credits = 9999
	Run.data = 99
	Run.heat = Run.heat_cap() + 19
	for dev in [false, true]:
		DevMode.enabled = dev
		Sig.dev_mode_changed.emit()
		await Harness.frames(_tree, 4)
		Router.show_local()
		await Harness.frames(_tree, 40)
		hud.refresh()
		await Harness.frames(_tree, 2)
		var tag := "the worst case, dev mode %s" % ("on" if dev else "off")
		var clip := hud._row.get_parent() as Control
		var need := int(hud._row.get_combined_minimum_size().x)
		print("  %s: hud row wants %d of %d" % [tag, need, int(clip.size.x)])
		if dev:
			continue
		var heat_v := hud._heat_text.text
		var credits_v := (hud._scrap.get_node("Value") as Label).text
		_ok("%s: PARTY shows, heat reads over the cap (\"%s\"), credits \"%s\""
			% [tag, heat_v, credits_v],
			hud._tab_party.is_visible_in_tree() and heat_v.ends_with("19 HULL") and credits_v == "9999")
		_ok("%s: the row fits its %d px clip (wants %d)" % [tag, int(clip.size.x), need],
			need <= int(clip.size.x))
		_data_box(hud, tag, hud.fuel_rect())
		# THE "00" HOLD. The money group is pinned right, so a DATA figure that
		# grew would shove CREDITS and FUEL left: 0, 14 and 99 must leave them
		# where they are. Past 99 the third figure comes out of the slack; the
		# test prints what 199 and 999 want so the next thing added sees it.
		var at := {}
		for d in [0, 14, 99, 199, 999]:
			Run.data = d
			hud.refresh()
			await Harness.frames(_tree, 2)
			if d <= 99:
				at[d] = [hud.fuel_rect().position.x, hud._scrap.get_global_rect().position.x]
			else:
				print("  %s, %d DATA: hud row wants %d of %d"
					% [tag, d, int(hud._row.get_combined_minimum_size().x), int(clip.size.x)])
		_ok("%s: DATA at 0, 14 and 99 leaves CREDITS and FUEL where they were (%s)" % [tag, at],
			at[0] == at[14] and at[0] == at[99])
		Run.data = 99
	Net.state = was_state
	Run.credits = was[0]
	Run.data = was[1]
	Run.heat = was[2]
	DevMode.enabled = false
	Sig.dev_mode_changed.emit()
	await Harness.frames(_tree, 4)
	hud.refresh()


# ------------------------------------------------------------------ helpers

func _stand(n: MapGen.MapNode) -> void:
	Run.at = n.index
	Run.chart_from(n)


func _a_station() -> MapGen.MapNode:
	for raw in Run.map:
		if (raw as MapGen.MapNode).type == MapGen.NodeType.STATION:
			return raw
	return null


func _finish() -> void:
	h.verdict("fueltest")
	_tree.quit(h.code())
