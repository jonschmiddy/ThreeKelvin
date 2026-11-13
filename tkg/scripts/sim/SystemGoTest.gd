extends Node

## GO IS THE OBVIOUS BUTTON ON THE SYSTEM MAP'S PANEL (issue #35), headless:
##   -- sheet=SystemGoTest
## World pages with an open event the ship is not at: GO column-wide, in ember.
## No FLY HERE (F-C, Nov 11: the tag says CLICK AGAIN), PLOT NEXT JUMP only once
## the system is done, and the event page's foot GO alone.

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
		h._ok("%s: no FLY HERE beside the GO (%d)" % [where, fly.size()], fly.is_empty())
		var tip: Array = m.overlay._click_line(bi)
		h._ok("%s: the selected world's tag ends on what a second click does (%s)" % [where, tip],
			tip.size() == 1 and String(tip[0][0]).begins_with("CLICK AGAIN"))
		var plot := _buttons(P._foot, "PLOT NEXT JUMP")
		h._ok("%s: no PLOT NEXT JUMP while events are open (%d)" % [where, plot.size()], plot.is_empty())
		# the event's own page, from the first open one here
		for bc in L.bodies[bi].beacons:
			if bc.opt >= 0 and P._is_open(bc.opt):
				m.open_beacon(bi, bc)
				await Harness.frames(get_tree(), 3)
				var pg := P._foot.find_child("Go", true, false) as Button
				var back := _buttons(P._foot, "ALL EVENTS")
				var top := _buttons(P._box, "< ALL EVENTS")
				h._ok("%s: the event page's foot is GO alone, in the ink, the foot's width; \"< ALL EVENTS\" up top (%d foot backs, %d top)" % [where, back.size(), top.size()],
					pg != null and back.is_empty() and top.size() == 1 and (_ember(pg, "normal") or pg.disabled)
					and absf(pg.size.x - P._foot.size.x) < 0.5)
				break
		m.panel_back()
		await Harness.frames(get_tree(), 2)
	# THE SYSTEM DONE: PLOT NEXT JUMP comes, lit as the one thing to do
	var n: MapGen.MapNode = m.view.node
	var taken := n.taken.duplicate()
	var results := n.results.duplicate()
	for i in n.options.size():
		if not n.taken.has(MapGen.OPTION_SITE + i):
			n.taken.append(MapGen.OPTION_SITE + i)
			n.results[i] = MapGen.R_DONE
	P.show_system()
	await Harness.frames(get_tree(), 3)
	var lit := _buttons(P._foot, "PLOT NEXT JUMP")
	h._ok("seed %d, system %d done: PLOT NEXT JUMP shows, in ember (%d)" % [s, n.index, lit.size()],
		P.system_done() and lit.size() == 1 and _ember(lit[0], "normal") and not (lit[0] as Button).disabled)
	n.taken = taken
	n.results = results
	P.show_system()
	await Harness.frames(get_tree(), 2)
