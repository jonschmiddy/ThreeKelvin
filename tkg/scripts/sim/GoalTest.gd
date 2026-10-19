extends Node

## THE GOAL LINE (`GoalLine`), on the real screens, headless:
##   godot --headless --path . -- sheet=GoalTest
##
## Tutorial direction B (Jon, Oct 17): "GOAL: REACH THE CORE" always, and the
## next step under it while one is pending, quiet and small, under the HUD,
## never covering anything, and not looking pressable. Walked through a new
## run as it is played: LOCAL at launch (open STARCHART, the tab outlined), the
## chart (pick a star), the first jump (that step done), the sector map with
## events (click one, then GO), LOCAL (open SECTOR), an event's band up (that
## step done), a fight; and hidden over the cutaway and the escape menu.
##
## THE BOX TEST, on every screen it shows on: its rect is inside the picture
## and clear of the HUD, the side bar, every piece of the toolbar row, LOCAL's
## event band and the bar under it, the hand, your hull, every enemy's hull and
## the words over and under it, and an event's subject. The list is gathered
## here, apart from `GoalLine.avoid_rects`, so the line cannot pass by agreeing
## with itself. Written against the node by its name, so it runs (and fails) on
## a build without the line.
##
## The steps are tutorial, so they follow the hints (`Hints.enabled`): on here
## by hand, in the harness settings file; GOAL shows either way.

var _tree: SceneTree
var _fails := 0
## the goal's rect where first seen up: every screen after has it the same
var _goal_rect := Rect2()


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
	Hints.forced = true
	Hints.set_process(false)
	Hints.reset()
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Router.show_local()
	await _frames(40)

	# ---- LOCAL at launch
	var g := _goal()
	if not _ok("the goal line exists, hosted by the HUD", g != null):
		return _finish()
	_check(g, "LOCAL at launch", "Open STARCHART. Pick a star in range, then JUMP.")
	_ok("LOCAL at launch: the STARCHART tab is outlined (cue %s)" % g.get("cue"),
		g.get("cue") == &"chart" and Router.hud.tab_rect(&"chart").size != Vector2.ZERO)
	_not_pressable(g)

	# ---- the chart
	Router.show_starchart()
	await _frames(40)
	_check(g, "the chart", "Pick a star in range, then JUMP.")
	_ok("the chart: no tab outlined (you are on it)", g.get("cue") == &"")

	# ---- the start system's map: the jump is still the step
	Router.show_system()
	await _frames(40)
	_check(g, "the start system's map", "Open STARCHART. Pick a star in range, then JUMP.")

	# ---- the first jump, to a neighbour with an event open
	var to := _neighbour_with_events()
	if not _ok("a neighbour in range with an event in it", to != null):
		return _finish()
	Router.commit_jump(to.index, true)
	await _frames(60)
	_ok("jumped (%d jump, on %s)" % [Run.jumps, _name(Router.current)], Run.jumps == 1)
	_ok("the jump step is done for good", Hints.seen(&"step_jump"))
	Router.show_system()
	await _frames(40)
	_check(g, "the map after the first jump", "Click an event, then GO.")
	Router.show_local()
	await _frames(40)
	_check(g, "LOCAL after the first jump", "Open SECTOR. Click an event, then GO.")
	_ok("LOCAL after the first jump: the SECTOR tab is outlined", g.get("cue") == &"sector")

	# ---- an event's band up on LOCAL: that step is done; the line keeps off it
	var sc := Router.current as SectorScreen
	var oi := _open_event(Run.node_at())
	if _ok("an event to open here", sc != null and oi >= 0):
		sc._events.open(oi)
		await _frames(30)
		_check(g, "LOCAL with an event's band up", "")
		_ok("the event step is done for good", Hints.seen(&"step_event"))
		sc._events.not_now()
		await _frames(20)
		_check(g, "LOCAL after NOT NOW", "")

	# ---- a fight
	Router.start_combat(DB.enemies[&"cutter"], [], false, false)
	await _frames(60)
	sc = Router.current as SectorScreen
	if _ok("a fight is up", sc != null and sc.fighting()):
		_check(g, "a fight", "")
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Router.show_local()
	await _frames(40)

	# ---- hidden over the cutaway, and the escape menu
	sc = Router.current as SectorScreen
	if sc != null:
		var cut := sc.open_cutaway()
		await _frames(10)
		_ok("hidden over the cutaway", cut != null and not g.visible)
		if cut != null:
			cut.close_now()
		await _frames(10)
		_ok("back when the cutaway shuts", g.visible)
	var main: Node = Router.content
	while main != null and not main.has_method("toggle_menu"):
		main = main.get_parent()
	if main != null:
		main.toggle_menu()
		await _frames(5)
		_ok("hidden under the escape menu", not g.visible)
		main.toggle_menu(false)
		await _frames(5)

	# ---- steps off under a harness that did not ask for hints; GOAL stays
	Hints.forced = false
	Hints.reset()
	Router.show_local()
	await _frames(40)
	_ok("hints off: GOAL still shows, with no step under it (step \"%s\")" % _step_text(g),
		g.visible and _goal_text(g) == "GOAL: REACH THE CORE" and _step_text(g) == "")
	_finish()


func _goal() -> Control:
	if Router.hud == null:
		return null
	var root := Router.hud.get_parent()
	return root.get_node_or_null("GoalLine") as Control if root != null else null


func _goal_text(g: Control) -> String:
	var ls := g.find_children("*", "Label", true, false)
	return (ls[0] as Label).text if ls.size() > 0 else ""


func _step_text(g: Control) -> String:
	var ls := g.find_children("*", "Label", true, false)
	return (ls[1] as Label).text if ls.size() > 1 and (ls[1] as Label).visible else ""


## Up, saying GOAL and `step`, and clear of everything on this screen.
func _check(g: Control, where: String, step: String) -> void:
	if not _ok("%s: the goal line is up" % where, g.is_visible_in_tree() and g.modulate.a > 0.99):
		return
	_ok("%s: GOAL: REACH THE CORE, and the step \"%s\" (has \"%s\")" % [where, step, _step_text(g)],
		_goal_text(g) == "GOAL: REACH THE CORE" and _step_text(g) == step)
	var r := Rect2(g.global_position, g.size)
	var screen := g.get_viewport_rect()
	_ok("%s: inside the picture (%s)" % [where, r], screen.encloses(r) and r.size.x > 10.0)
	# ONE PLACE (Jon, Oct 18: "Can we have the goal: xxx always be in this
	# location?"): the same rect on every screen it shows on
	if _goal_rect == Rect2():
		_goal_rect = r
	_ok("%s: in its one place (%s; first seen %s)" % [where, r, _goal_rect], r == _goal_rect)
	# and the step's line, while one is pending, boxed the same
	var sr: Rect2 = g.call("step_rect") if g.has_method("step_rect") else Rect2()
	if sr.size != Vector2.ZERO:
		var shits: Array[String] = []
		for pair in _boxes(Router.current):
			var b2: Rect2 = pair[1]
			if b2.size.x > 0.0 and b2.size.y > 0.0 and sr.intersects(b2):
				shits.append("%s %s" % [pair[0], b2])
		var inner2: Control = Router.current.get("_chart") if Router.current is StarchartScreen else (Router.current.get("_frame") if Router.current is SystemMapScreen else null)
		if inner2 != null and sr.intersects(inner2.get_parent_control().get_global_rect()) and not inner2.get_global_rect().encloses(sr):
			shits.append("the picture's frame")
		_ok("%s: the step's line clear of everything (%s)" % [where, "nothing under it" if shits.is_empty() else ", ".join(shits)], shits.is_empty() and screen.encloses(sr))
	var hits: Array[String] = []
	# the map's and the chart's frame: off it, or wholly inside its picture
	var inner: Control = null
	if Router.current is StarchartScreen:
		inner = Router.current.get("_chart")
	elif Router.current is SystemMapScreen:
		inner = Router.current.get("_frame")
	if inner != null:
		var outer := inner.get_parent_control().get_global_rect()
		if r.intersects(outer) and not inner.get_global_rect().encloses(r):
			hits.append("the picture's frame %s" % outer)
	for pair in _boxes(Router.current):
		var b: Rect2 = pair[1]
		if b.size.x > 0.0 and b.size.y > 0.0 and r.intersects(b):
			hits.append("%s %s" % [pair[0], b])
	_ok("%s: clear of everything (%s)" % [where, "nothing under it" if hits.is_empty() else ", ".join(hits)],
		hits.is_empty())
	# and nothing it draws reaches past its own box but the tab outline
	_ok("%s: under the HUD (top %.0f, the HUD's bottom %.0f)" % [where, r.position.y, Router.hud.get_global_rect().end.y],
		r.position.y >= Router.hud.get_global_rect().end.y)


## Everything the line must not cover, [name, global rect], gathered here.
func _boxes(cur: Control) -> Array:
	var out: Array = [["HUD", Router.hud.get_global_rect()]]
	if cur.has_method("ladder_side"):
		var side: Control = cur.call("ladder_side")
		if side != null and side.is_visible_in_tree():
			out.append(["side bar", side.get_global_rect()])
	if cur.has_method("ladder_bar"):
		var bar: Control = cur.call("ladder_bar")
		if bar != null and bar.is_visible_in_tree():
			for c in bar.find_children("*", "", true, false):
				var k := c as Control
				if k != null and k.is_visible_in_tree() and (k is Label or k is BaseButton or k is Panel):
					out.append(["toolbar %s" % k.get_class(), k.get_global_rect()])
	var sc := cur as SectorScreen
	if sc != null:
		if sc._events != null and sc._events.visible:
			out.append(["event band", sc._events.get_global_rect()])
		if sc._quiet_holder != null and sc._quiet_holder.is_visible_in_tree():
			out.append(["bar under the view", sc._quiet_holder.get_global_rect()])
		if sc._hand != null and sc._hand.is_visible_in_tree():
			out.append(["hand", sc._hand.get_global_rect()])
		if sc._end_button != null and sc._end_button.is_visible_in_tree():
			out.append(["END TURN", sc._end_button.get_global_rect()])
		var ship := sc._view.ship_view()
		if ship != null and ship.is_visible_in_tree():
			out.append(["your hull", ship.get_global_transform() * ship.ship_rect()])
		if sc._self_plate != null and sc._self_plate.is_visible_in_tree():
			out.append(["your plate", sc._self_plate.get_global_rect()])
		for i in 12:
			var sl := sc._view.slot(i)
			if sl == null or not sl.is_visible_in_tree():
				continue
			out.append(["enemy %d hull" % i, sl.get_global_transform() * sl.ink_rect()])
			out.append(["enemy %d words" % i, sl.intent_rect_global()])
			out.append(["enemy %d readout" % i, sl.readout_rect_global()])
		var subj := LocalSubject.of(sc._view)
		if subj != null:
			for r: Rect2 in subj.drawn_rects():
				out.append(["event subject", r])
	return out


## Not a control: it and everything in it ignore the mouse, nothing in it is a
## button, and it shows no hand.
func _not_pressable(g: Control) -> void:
	var all: Array = [g]
	all.append_array(g.find_children("*", "", true, false))
	var bad: Array[String] = []
	for n in all:
		var c := n as Control
		if c == null:
			continue
		if c.mouse_filter != Control.MOUSE_FILTER_IGNORE or c is BaseButton \
				or c.mouse_default_cursor_shape != Control.CURSOR_ARROW or c.focus_mode != Control.FOCUS_NONE:
			bad.append(c.name)
	_ok("not pressable: ignores the mouse, no button, no hand, no focus (%s)" % ("all of it" if bad.is_empty() else ", ".join(bad)),
		bad.is_empty())


func _neighbour_with_events() -> MapGen.MapNode:
	var here := Run.node_at()
	for raw in Run.in_range():
		var n: MapGen.MapNode = raw
		if n == here or not Run.can_jump_to(n) or n.type != MapGen.NodeType.SYSTEM:
			continue
		OptionTable.ensure(n)
		if _open_event(n) >= 0:
			return n
	return null


## An open event at `n` that is not a fight (its band, not a fight, opens).
func _open_event(n: MapGen.MapNode) -> int:
	if n == null:
		return -1
	OptionTable.ensure(n)
	for i in n.options.size():
		var o := OptionTable.by_id(n.options[i])
		var kind: StringName = EncounterDrawer.option_state(n, i).kind
		if (kind == &"open" or kind == &"left") and (o.get("choices", []) as Array).size() > 0:
			return i
	return -1


func _name(c: Node) -> String:
	return c.get_script().get_global_name() if c != null and c.get_script() != null else "none"


func _finish() -> void:
	Hints.forced = false
	Hints.set_process(true)
	Hints.reset()
	print("goaltest: %s" % ("PASS" if _fails == 0 else "%d FAILURES" % _fails))
	_tree.quit(1 if _fails > 0 else 0)
