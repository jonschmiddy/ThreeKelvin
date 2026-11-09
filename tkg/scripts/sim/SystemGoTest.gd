extends Node

## GO IS THE OBVIOUS BUTTON ON THE SYSTEM MAP'S PANEL (issue #35), headless:
##   -- sheet=SystemGoTest
## On every world page with an open event the ship is not at: GO is the text
## column wide, in the commit ink; FLY HERE and PLOT NEXT JUMP are quiet; on
## the event's own page GO is in the ink and wider than a quiet ALL EVENTS.

const SEEDS := [4242, 7, 1999]
## systems with events looked at, a seed
const SYSTEMS := 5

var h := Harness.new()
var _pages := 0


func _ready() -> void:
	_run.call_deferred()


func _idle() -> void:
	for i in 900:
		if not ZoomLadder.busy() and ZoomLadder.chain == &"":
			return
		await get_tree().process_frame


func _map() -> SystemMapScreen:
	Router.show_system()
	await _idle()
	for i in 240:
		var m := Router.current as SystemMapScreen
		if m != null and m.flight != null and m.view.layout != null:
			await Harness.frames(get_tree(), 4)
			return m
		await get_tree().process_frame
	return null


func _ember(b: Button, state: String) -> bool:
	var sb := b.get_theme_stylebox(state) as StyleBoxFlat
	return sb != null and sb.border_color.is_equal_approx(UITheme.EMBER)


func _quiet(b: Button) -> bool:
	var sb := b.get_theme_stylebox(&"normal") as StyleBoxFlat
	return sb != null and sb.bg_color.a == 0.0


func _buttons(root: Node, text: String) -> Array:
	return root.find_children("*", "Button", true, false).filter(
		func(c: Node) -> bool: return (c as Button).text == text and (c as Button).is_visible_in_tree())


func _run() -> void:
	await get_tree().process_frame
	for s: int in SEEDS:
		h.seed_run(s)
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
		await Harness.frames(get_tree(), 6)
		var looked := 0
		for raw in Run.map:
			var n: MapGen.MapNode = raw
			if n.type != MapGen.NodeType.SYSTEM or looked >= SYSTEMS:
				continue
			OptionTable.ensure(n)
			if n.options.is_empty():
				continue
			looked += 1
			Run.at = n.index
			var m := await _map()
			if not h._ok("seed %d, system %d: the map is up" % [s, n.index], m != null):
				continue
			await _system(m, s)
	h._ok("some world pages were measured (%d)" % _pages, _pages > 0)
	h.verdict("systemgotest")
	get_tree().quit(h.code())


func _system(m: SystemMapScreen, s: int) -> void:
	var P = m.panel
	var L: SystemLayout = m.view.layout
	var panel_r: Rect2 = P.get_global_rect()
	for bi in L.bodies.size():
		if m.ship_reached(bi) or not P._has_open_event(bi):
			continue
		m.select_body(bi)
		await Harness.frames(get_tree(), 3)
		_pages += 1
		var where := "seed %d, %s" % [s, L.bodies[bi].name]
		var gos: Array = P._box.find_children("Go", "Button", true, false)
		h._ok("%s: its page has a GO" % where, not gos.is_empty())
		for g: Button in gos:
			var r := g.get_global_rect()
			h._ok("%s: GO is the column's width and tall (%.0f x %.0f of %d)" % [where, r.size.x, r.size.y, P.TEXT_W],
				absf(r.size.x - P.TEXT_W) < 0.5 and r.size.y >= P.GO_H)
			h._ok("%s: GO is inside the panel" % where, panel_r.grow(0.5).encloses(r))
			if not g.disabled:
				h._ok("%s: GO wears the commit ink" % where, _ember(g, "normal"))
			else:
				var sb := g.get_theme_stylebox(&"disabled") as StyleBoxFlat
				h._ok("%s: a GO that cannot go is not ember" % where,
					sb != null and not sb.border_color.is_equal_approx(UITheme.EMBER))
		var fly := _buttons(P._box, "FLY HERE")
		if not fly.is_empty():
			h._ok("%s: FLY HERE is quiet and still pressable" % where,
				_quiet(fly[0]) and not (fly[0] as Button).disabled)
		var plot := _buttons(P._foot, "PLOT NEXT JUMP")
		h._ok("%s: PLOT NEXT JUMP is there and quiet" % where, plot.size() == 1 and _quiet(plot[0]))
		# the event's own page, from the first open one here
		for bc in L.bodies[bi].beacons:
			if bc.opt >= 0 and P._is_open(bc.opt):
				m.open_beacon(bi, bc)
				await Harness.frames(get_tree(), 3)
				var pg := P._foot.find_child("Go", true, false) as Button
				var back := _buttons(P._foot, "ALL EVENTS")
				h._ok("%s: the event page's GO wears the ink and is wider than ALL EVENTS" % where,
					pg != null and back.size() == 1 and (_ember(pg, "normal") or pg.disabled)
					and pg.size.x > (back[0] as Button).size.x and _quiet(back[0]))
				break
		m.panel_back()
		await Harness.frames(get_tree(), 2)
