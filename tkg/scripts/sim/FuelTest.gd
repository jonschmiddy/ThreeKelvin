extends Node

## THE 45 TANK (Jon, Oct 17: "fuel:A warn:A events:A"), headless:
##   godot --headless --path . -- sheet=FuelTest
##
## Four things, each read off the game rather than restated here:
##
## - THE CAP. A run starts full at 45 and no write can overfill it: the
##   setter, a refuel, a grant. REFUEL at a full tank says TANK FULL and takes
##   nothing; a top-up is the room left, charged by the unit.
## - THE EVENT FLOOR (`Run.drain_fuel`). An event leaves the fuel to reach a dock
##   in sight, or three of the cheapest jumps with none; it never adds fuel; and
##   every event outcome in `OptionTable` drains through it, at the 45 scale.
## - THE HINT. Not above a third of the tank, at it; its second line names the
##   nearest dock the tank can reach and the jumps to it -- checked against a
##   search written here, not the game's -- or says what to do with none.
## - THE HUD READOUT. "FUEL [bar] 23/45" at full, a third and near empty: the
##   figure, the bar's fill, the colour (ice, amber, red, with or without hints,
##   so a party is warned too); and the box test -- every piece inside the bar,
##   on screen, clear of every other thing on the row, of the goal line and of
##   the band under it on the left, and every spot A.S.H. can stand in; with dev
##   mode's two extra
##   tabs too. Not pressable: no button, no focus, the arrow cursor.

var _tree: SceneTree
var _fails := 0


func _ok(what: String, c: bool) -> bool:
	print("  %s %s" % ["ok  " if c else "FAIL", what])
	if not c:
		_fails += 1
	return c


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await _tree.process_frame


func _run() -> void:
	_tree = get_tree()
	await _frames(2)
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	_cap()
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


## Every event outcome drains through the floor and none moves more than a few
## units: the 109 drains and 47 grants were rescaled from a 279 tank to 45
## (round(n * 45 / 279), at least 1), so the largest of either is 6. Counted
## at least, not exactly, so a branch that adds an event (feat/fauna-events'
## `in_the_wake`) passes once its drain goes through `drain_fuel` at the scale.
## FLEE AND THE PULSAR ON THE 45 SCALE (Jon: "flee:A", "pulsar:C"). A flee burns
## 1, and 2 more on a partial, through the floor; the pulsar pays 14 + danger,
## about half a tank, held under the top.
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
	await _frames(40)
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
			and (line == want or int(game.jumps) == int(mine.jumps)))
	# A DOCK ONE JUMP OFF AND ONE FURTHER, wherever the map has them: the line
	# names it, with the jumps, and agrees with this test's own search
	var cases := {1: false, 2: false}
	# Docks you have been to stay on the chart (`Run.charted`), so a remembered
	# one out of sight can be the nearest, two jumps through a star you can see.
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
		var k := 1 if int(m.jumps) == 1 else 2
		if cases[k]:
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
		SystemMapScreen._parked.erase(st.index)
		_ok("in a station's system, not at the station: \"%s\"" % Hints.fuel_dock_line(),
			Hints.fuel_dock_line() == "Fly to the station here to refuel.")
		Router.park_at_station(st)
		_ok("at the station: \"%s\"" % Hints.fuel_dock_line(), Hints.fuel_dock_line() == "Refuel here before you leave.")
	Hints._close(false)
	Hints.forced = false
	Run.fuel = 45


func _poll(secs: float) -> void:
	var t := 0.0
	while t < secs:
		Hints.poll(1.0 / 30.0)
		await _tree.process_frame
		t += 1.0 / 30.0


## Fewest jumps to a station, then least fuel, over the systems the chart draws,
## each hop priced as the game prices a hop from where it starts. Written apart
## from `Run.nearest_dock` so the two can disagree.
func _my_nearest_dock() -> Dictionary:
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
				if t.index == from.index or not Run.charted(t) or not Run.reachable_from(from, t):
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
	await _frames(40)
	var hud: HudBar = Router.hud
	if not _ok("the HUD is up", hud != null and hud.is_visible_in_tree()):
		return
	for dev in [false, true]:
		DevMode.enabled = dev
		Sig.dev_mode_changed.emit()
		await _frames(4)
		var tag := "dev mode %s" % ("on" if dev else "off")
		for screen in [&"local", &"chart"]:
			if screen == &"chart":
				Router.show_starchart()
			else:
				Router.show_local()
			await _frames(40)
			for f in [45, 15, 1]:
				Run.fuel = f
				hud.refresh()
				await _frames(2)
				_readout(hud, f, "%s, %s, %d/45" % [tag, screen, f])
	DevMode.enabled = false
	Sig.dev_mode_changed.emit()
	await _frames(4)
	# with hints off, as in a party, the readout still warns
	Hints.forced = false
	_ok("hints are off here, as in a party", not Hints.enabled())
	for pair in [[15, 1], [1, 2]]:
		Run.fuel = pair[0]
		hud.refresh()
		await _frames(2)
		var v := hud._fuel.get_node("Value") as Label
		_ok("hints off, %d/45: the figure still turns %s" % [pair[0], ["", "amber", "red"][pair[1]]],
			v.get_theme_color("font_color") == HudBar.FUEL_INK[pair[1]] and HudBar.fuel_state() == pair[1])
	Run.fuel = 45
	hud.refresh()


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
	print("fueltest: %s" % ("PASS" if _fails == 0 else "%d FAILURES" % _fails))
	_tree.quit(0 if _fails == 0 else 1)
