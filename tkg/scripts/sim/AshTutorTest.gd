extends Node

## A.S.H. TEACHING (Jon picked how A for the tutorial, Oct 17: "A.S.H. replaces
## the hint cards"), on the real screens, headless:
##   godot --headless --fixed-fps 60 --path . -- sheet=AshTutorTest
##
## THE USED STATE, NOT THE FRESH ONE: a run already under way, a line of hers
## already said, a settings file with hints seen, reset once and one seen
## since, in the harness's settings file. The hints' clock is stepped by hand
## (`Hints.poll`); hers runs on the game's.
##
## THE LINES are Jon's picks, character for character, their fields filled from
## the live game (the hand, the heat cap, the dock and its jumps, the keys), and
## every one fits her frame on every screen.
##
## EACH MOMENT, through the real screens in the order a first run meets them:
## the goal steps on LOCAL, the chart and the map; the chart's list; the map's
## events; LOCAL's wreck, loot and ship; the cutaway; the event band; a wreck's
## window; a fight's hand, intent, END TURN, brace and heat (five lines, one
## fight); the station's decks, its yard's ship and its cutaway; fuel low with a
## dock in reach, none, and here. Each is her line with the right words, in her
## corner and not a card, the outline on the hint's own subject, held until a
## click (a goal step goes after its reading time), and the click spends it.
##
## THE BOX TEST on every screen she speaks on: her box inside the view and clear
## of a list gathered HERE, apart from `Ash.tut_avoid_rects`, so she cannot pass
## by agreeing with herself -- the HUD, the goal line, every button and word on
## the screen, every control that takes the mouse (but the backdrops that hold
## the whole view), what she points at, and in the pictures what a click picks
## (the chart's systems, the map's worlds, beacons, star and belts, its orbits,
## the yard's drones and its TAKE IT), each asked of the picture's own hit test
## at every 2 px.
##
## A BARK NEVER INTERRUPTS A TEACHING LINE, and a teaching line cuts a bark.
## HER INTRODUCTION (intro:A) is the exception: a fresh profile's first launch
## says launch_04 first, the step waits for it and follows; never forced again.
## HER VOICE: no take is silence and the words alone at her text pace; a take
## types at its pace, and the shown words (numbers and names in them) end when
## she stops; what she says has no field and no live number. OFF: her switch
## off brings back today's cards, exactly, mid-lesson too; and in a party there
## is no teaching at all.

var _tree: SceneTree
var _fails := 0
var _checks := 0
var _screens: Dictionary = {}

## Jon's picks, as he wrote them (the brief of Oct 17), to hold the game to.
const JON := {
	&"chart": "These stars are in reach. Left bar is danger. Right bar is fuel.",
	&"events": "Click an event to read it. GO flies us there.",
	&"drawer": "Pick one. Some choices show the odds. The rest are a surprise.",
	&"hand": "Drag a card onto an enemy to fire. Top left is its energy cost.",
	&"intent": "That's what it will do when you press END TURN.",
	&"endturn": "Out of energy. Press END TURN. They act, then you draw {hand} cards.",
	&"brace": "Brace stops damage till gone. Holding it costs 1 heat a turn.",
	&"heat": "Heat. Past {cap}, we lose 1 hull per point over, at end of turn.",
	&"salvage": "Drag a part into the hold. Double-click works too.",
	&"wreck": "Click a wreck to loot it. Its parts and credits are ours.",
	&"loot": "SECTOR LOOT is what's loose here. It stays until you take it.",
	&"dock": "Stations repair, refuel and trade. Pick a deck on the left.",
	&"fuel_dock": "Fuel is low. Run dry and the run ends. Nearest dock is {jumps} jumps: {name}.",
	&"fuel_none": "Fuel is low, and empty ends the run. No dock in reach. Jump short and look.",
	&"fuel_here": "Fuel is low. Run dry and the run ends. Refuel here before we go.",
	&"ship": "Click the ship to open it up. You fit and swap parts in there.",
	&"step_jump": "Open STARCHART. Pick a star in range, then press JUMP.",
	&"step_jump_chart": "Pick a star in range, then press JUMP.",
	&"step_event": "Open SECTOR. Click an event, then press GO.",
	&"step_event_map": "Click an event, then press GO.",
}


func _ok(what: String, c: bool) -> bool:
	_checks += 1
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
	_ok("off under a harness that did not ask", not Ash.teaches() and not Hints.enabled())
	Ash.forced = true
	Ash.reload()
	Ash.set_on(true)
	Hints.set_process(false)
	Hints.set_process_input(false)
	_lines()
	await _used_state()
	await _flow()
	await _bark_and_lesson()
	await _voice()
	await _switch()
	await _intro()
	await _first_launch()
	await _coop()
	_finish()


# ------------------------------------------------------------------ helpers

func _press() -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	return ev


func _local() -> SectorScreen:
	Router.show_local()
	await _frames(40)
	return Router.current as SectorScreen


## The first ordinary system, with the ship at it.
func _system() -> MapGen.MapNode:
	for raw in Run.map:
		var m: MapGen.MapNode = raw
		if m.type == MapGen.NodeType.SYSTEM and not m.cleared and not Router.no_fights_at(m):
			Run.at = m.index
			m.visited = true
			SectorScreen._approached_at = m.index
			OptionTable.ensure(m)
			return m
	return null


func _plant_event(n: MapGen.MapNode) -> int:
	for o in OptionTable.all():
		if (o.get("choices", []) as Array).size() >= 2 and not (o.get("tags", []) as Array).has(&"fight"):
			n.options.append(StringName(o.id))
			return n.options.size() - 1
	return -1


## Step the hints until she is saying line `lid` (or `secs` of the clock pass).
func _until_said(lid: StringName, secs: float = 6.0) -> bool:
	for i in int(secs * 10.0):
		Hints.poll(0.1)
		await _tree.process_frame
		if Ash.lesson == lid and Ash.lesson_up():
			return true
	return false


## Hint `id` comes as her line `lid`: the words, the corner not a card, the
## outline on its subject, the box test; held, then spent by a click.
func _expect(id: StringName, lid: StringName = &"", words: String = "") -> void:
	if lid == &"":
		lid = id
	var up: bool = await _until_said(lid)
	var got := "%s / card %s" % [Ash.lesson, Hints.card.id if Hints.card != null else &"none"]
	if not _ok("%s: she says it (got %s)" % [lid, got], up):
		return
	var want := words if words != "" else AshTutorLines.fill(lid, Hints.values(id))
	var p := Ash.portrait
	_ok("%s: the words are the line, filled (\"%s\")" % [lid, p.line], p.line == want and not p.line.contains("{"))
	_ok("%s: in her corner, no card" % lid, Hints.card == null and Hints.lesson == id and p.visible)
	var subj: Rect2 = Hints.probe(id).get("subject", Rect2())
	var want_o := Rect2(subj.position.round(), subj.size.round()).grow(1.0)
	_ok("%s: the outline is on its subject (%s, subject %s)" % [lid, Ash.outline_rect(), subj],
		subj.size != Vector2.ZERO and Ash.outline_rect().is_equal_approx(want_o))
	await _box(String(lid))
	# HELD until a click: a while left alone, still up and unspent
	for i in 30:
		Hints.poll(0.2)
		await _tree.process_frame
	_ok("%s: left alone, it stays up and unspent" % lid, Ash.lesson == lid and Ash.lesson_up() and not Hints.seen(id))
	var took := Hints.click(_press())
	await _tree.process_frame
	_ok("%s: a click spends it and she goes" % lid, took and Hints.seen(id) and Hints.lesson == &""
		and Ash.lesson == &"" and not Ash.portrait.speaking() and Ash.outline_rect() == Rect2())
	Hints.poll(Hints.GAP_S + 0.1)


## A goal step's line: said once as it starts, no outline of her own, and gone
## after her reading time on the game's clock.
func _expect_step(lid: StringName) -> void:
	var up: bool = await _until_said(lid)
	if not _ok("%s: she says the step as it starts" % lid, up):
		return
	var p := Ash.portrait
	_ok("%s: the words (\"%s\")" % [lid, p.line], p.line == String(JON[lid]))
	_ok("%s: no outline of hers (the goal line outlines its tab)" % lid, Ash.outline_rect() == Rect2())
	await _box(String(lid))
	var t0 := GameClock.now()
	var held_from := -1.0
	while p.speaking() and GameClock.now() - t0 < 15.0:
		Hints.poll(1.0 / 60.0)
		await _tree.process_frame
		if held_from < 0.0 and p.phase == AshPortrait.Phase.HOLDING:
			held_from = GameClock.now()
	var held := GameClock.now() - held_from
	var need := AshPortrait.HOLD_MIN_S + AshPortrait.HOLD_PER_CHAR_S * float(p.line.length())
	_ok("%s: typed, held %.2f s to read (wants %.2f), then went on its own" % [lid, held, need],
		held_from > 0.0 and held >= need - 0.05 and not p.speaking())
	_ok("%s: said for good" % lid, Hints.said(lid))
	Hints.poll(0.1)


## Nothing of hers about `lid` comes over a few seconds.
func _never(lid: StringName, what: String) -> void:
	var said := false
	for i in 30:
		Hints.poll(0.1)
		await _tree.process_frame
		if Ash.lesson == lid:
			said = true
	_ok(what, not said)


# ------------------------------------------------------------------ the box test

## Her box on the screen up now, against everything gathered here.
func _box(name: String) -> void:
	var cur := Router.current
	var r := Ash.portrait.rect()
	var hits: Array[String] = []
	var v := Ash.tut_view_rect(cur)
	if not v.grow(0.5).encloses(r):
		hits.append("outside the view %s" % v)
	if not Ash.portrait.get_viewport_rect().encloses(r):
		hits.append("off the screen")
	for b: Array in _gather(cur, v):
		var x: Rect2 = b[1]
		if x.size.x > 0.0 and x.size.y > 0.0 and r.intersects(x):
			hits.append("%s %s" % [b[0], x])
	hits.append_array(_picture_hits(cur, r))
	# WHY NOT THE SPOTS BEFORE IT, by this test's own list (for the record)
	var why: Array[String] = []
	for s: Dictionary in Ash.tut_spot_boxes(cur, r.size):
		if s.name == Ash.said_log.back().spot:
			break
		var first := ""
		if not v.grow(0.5).encloses(s.rect):
			first = "outside the view"
		for b: Array in _gather(cur, v):
			if first == "" and (b[1] as Rect2).size.x > 0.0 and (s.rect as Rect2).intersects(b[1]):
				first = String(b[0])
		if first == "":
			var ph := _picture_hits(cur, s.rect)
			first = ph[0] if not ph.is_empty() else ""
		if first == "":
			for x: Rect2 in Ash.tut_avoid_rects(cur):
				if first == "" and x.size.x > 0.0 and (s.rect as Rect2).intersects(x):
					first = "her own list's %s" % x
			if first == "":
				first = Ash.covers(cur, s.rect)
		why.append("%s: %s" % [s.name, first])
	if not why.is_empty():
		print("    (%s: not %s)" % [name, "; ".join(why)])
	_screens[name] = "%s at %s" % [Ash.said_log.back().spot, r]
	_ok("%s: box test at %s %s (%s)" % [name, Ash.said_log.back().spot, r,
		"nothing under her" if hits.is_empty() else ", ".join(hits.slice(0, 4))], hits.is_empty())


## THE STEP'S LINE under the goal (`GoalLine`, Jon, Oct 20), gathered here: as
## drawn while a step is pending, and where it stands when one is (the longest
## step's words under the goal), so a step coming up never lands on her. In a
## fight no step shows (its tabs are locked), so it has no place there: held to
## that here too.
func _step_boxes(goal: Control, fight: bool = false) -> Array:
	var out: Array = []
	if goal == null or not goal.visible or goal.modulate.a <= 0.0:
		return out
	var g := Rect2(goal.global_position, goal.size)
	for pc in goal.find_children("*", "PanelContainer", false, false):
		var p := pc as Control
		if p.visible and p.get_global_rect() != g:
			out.append(["the step's line", p.get_global_rect()])
	var w := UITheme.pixel_font().get_string_size("Open STARCHART. Pick a star in range, then JUMP.",
		HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x + 10.0
	if not fight:
		out.append(["the step's place", Rect2(g.position.x, g.end.y + 1.0, w, g.size.y)])
	elif not out.is_empty():
		_ok("in a fight, no step's line under the goal (%s)" % out[0][1], false)
	return out


## Everything on `cur` she must not cover, [what, global rect], gathered here.
func _gather(cur: Control, v: Rect2) -> Array:
	var out: Array = []
	var hud := Router.hud.get_global_rect()
	out.append(["HUD", hud])
	for c in Router.hud.find_children("*", "Control", true, false):
		var k := c as Control
		if k.is_visible_in_tree() and k.size.x > 0.0 and (k is BaseButton or k is Label):
			out.append(["HUD's %s" % k.name, k.get_global_rect()])
	var goal := Router.hud.get_parent().get_node_or_null("GoalLine") as Control
	if goal != null and goal.visible and goal.modulate.a > 0.0:
		out.append(["the goal line", Rect2(goal.global_position, goal.size)])
	out.append_array(_step_boxes(goal, cur is SectorScreen and (cur as SectorScreen).fighting()))
	if cur is SectorScreen:
		out.append(["the goal line's band", Rect2(hud.position.x, hud.end.y, hud.size.x, 26.0)])
	if Ash.lesson_subject.size != Vector2.ZERO:
		out.append(["what she points at", Ash.lesson_subject])
	# every button and word on the screen, and every control that takes the
	# mouse (but a backdrop that holds the whole of her view)
	for c in cur.find_children("*", "Control", true, false):
		var k := c as Control
		if k == null or not k.is_visible_in_tree() or k.size.x <= 0.0 or k.size.y <= 0.0:
			continue
		var g := k.get_global_rect()
		var drawn := (k is BaseButton) or (k is Label and (k as Label).text.strip_edges() != "") \
			or (k is RichTextLabel and (k as RichTextLabel).text.strip_edges() != "")
		var takes := k.mouse_filter == Control.MOUSE_FILTER_STOP and _handles_input(k) and not _backdrop(g, v)
		if drawn or takes:
			out.append(["%s %s" % [k.get_class(), k.name], g])
	var sc := cur as SectorScreen
	if sc != null:
		var ship := sc._view.ship_view()
		if ship != null and ship.is_visible_in_tree():
			out.append(["your hull", ship.get_global_transform() * ship.ship_rect()])
		var i := 0
		while sc._view.slot(i) != null:
			var sl := sc._view.slot(i)
			if sl.is_visible_in_tree():
				out.append(["ship %d" % i, sl.get_global_transform() * sl.ink_rect()])
				out.append(["ship %d's words" % i, sl.intent_rect_global()])
				out.append(["ship %d's plate" % i, sl.readout_rect_global()])
			i += 1
		var subj := LocalSubject.of(sc._view)
		if subj != null:
			for x: Rect2 in subj.drawn_rects():
				out.append(["the event's subject", x])
		if sc._events != null and sc._events.visible:
			out.append(["the event band", sc._events.get_global_rect()])
		var cut := sc._cutaway
		if cut != null and cut.is_open():
			out.append(["the cutaway's panel", cut._hold_panel.get_global_rect()])
			for d in cut._mounts.drawn_rects():
				out.append(["the cutaway's %s %s" % [d.kind, d.text], cut._mounts.get_global_transform() * (d.rect as Rect2)])
	var map := cur as SystemMapScreen
	if map != null:
		var ov = map.overlay
		var stt: Array = ov.ship_status()
		if String(stt[0]) != "":
			out.append(["the map's ship status \"%s\"" % stt[0], map._box.get_global_transform() * (ov.status_rect(String(stt[0])) as Rect2)])
		for lr: Rect2 in ov.label_rects:
			out.append(["a word on the map", map._box.get_global_transform() * lr])
	var st := cur as StationScreen
	if st != null and st._cutaway != null and st._cutaway.is_open():
		out.append(["the cutaway's panel", st._cutaway._hold_panel.get_global_rect()])
		for d in st._cutaway._mounts.drawn_rects():
			out.append(["the cutaway's %s %s" % [d.kind, d.text], st._cutaway._mounts.get_global_transform() * (d.rect as Rect2)])
	if st != null and st._scene != null and st._scene.is_visible_in_tree() and (st._cutaway == null or not st._cutaway.is_open()):
		var ys := st._scene
		for i in 2:
			var P: Dictionary = ys.placed[i]
			if not P.is_empty():
				out.append(["yard ship %d and its name" % i, ys.get_global_transform()
					* Rect2(Vector2(float(P["x0"]), float(P["top"]) - 27.0), Vector2(float(P["w"]), float(P["h"]) + 27.0))])
	return out


## A control that does something with a click: a button, one wired to
## `gui_input`, or one whose own script reads the mouse.
func _handles_input(k: Control) -> bool:
	if k is BaseButton or not k.gui_input.get_connections().is_empty():
		return true
	var sc := k.get_script() as Script
	while sc != null:
		for m in sc.get_script_method_list():
			if String(m.name) == "_gui_input":
				return true
		sc = sc.get_base_script()
	return false


## A backdrop: it holds most of the view she stands in (the sky a click on
## LOCAL lands on, the cutaway's and a window's catch-all, the chart's and the
## map's whole picture). What is IN those pictures is `_picture_hits`.
func _backdrop(g: Rect2, v: Rect2) -> bool:
	var i := g.intersection(v)
	return v.size.x > 0.0 and i.get_area() >= 0.4 * v.get_area()


## What a click picks under `r` in a picture, by the picture's own hit test at
## every 2 px: the chart's systems, the map's worlds, beacons, star and belts
## (and its orbits' lines), the yard's drones and TAKE IT.
func _picture_hits(cur: Control, r: Rect2) -> Array[String]:
	var out: Array[String] = []
	var pts: Array[Vector2] = []
	var y := r.position.y
	while y <= r.end.y:
		var x := r.position.x
		while x <= r.end.x:
			pts.append(Vector2(x, y))
			x += 2.0
		y += 2.0
	if cur is StarchartScreen:
		var mc := (cur as StarchartScreen)._chart
		var inv := mc.get_global_transform().affine_inverse()
		for p in pts:
			var h: int = mc._node_at(inv * p)
			if h >= 0:
				out.append("the system %s" % MapGen.star_name(Run.map[h]))
				break
	elif cur is SystemMapScreen:
		var map := cur as SystemMapScreen
		var inv := map._box.get_global_transform().affine_inverse()
		for p in pts:
			var h: Dictionary = map.overlay.hit(inv * p)
			if not h.is_empty():
				out.append("the map's %s" % h.kind)
				break
		var L: SystemLayout = map.view.layout
		var o: Vector2 = map.view.origin()
		var g := map._box.get_global_transform()
		for b in L.bodies:
			for k in 720:
				var a := TAU * float(k) / 720.0
				var q: Vector2 = g * (o + Vector2(cos(a), sin(a) * 0.38) * b.orbit * map.view.zoom)
				if b.orbit > 0.0 and r.has_point(q):
					out.append("an orbit's line")
					break
			if out.size() > 0 and out.back() == "an orbit's line":
				break
	elif cur is StationScreen:
		var ys := (cur as StationScreen)._scene
		if ys != null and ys.is_visible_in_tree() and ys.drones != null:
			var inv := ys.get_global_transform().affine_inverse()
			for p in pts:
				var q := inv * p
				if ys.drones.hit(q) >= 0:
					out.append("a drone")
					break
				if ys.deal_tv.on_take(q):
					out.append("TAKE IT")
					break
	return out


# ------------------------------------------------------------------ the lines

func _lines() -> void:
	print("the lines")
	var bad: Array[String] = []
	for k in JON:
		if String(AshTutorLines.LINES.get(k, "")) != String(JON[k]):
			bad.append(String(k))
	_ok("her lines are Jon's picks, character for character (%d; %s)" % [JON.size(),
		"all" if bad.is_empty() else "NOT " + ", ".join(bad)], bad.is_empty())
	_ok("the cutaway line is Jon's A (Oct 18), behind one constant (\"%s\")" % AshTutorLines.CUTAWAY_LINE,
		AshTutorLines.LINES[&"cutaway"] == AshTutorLines.CUTAWAY_LINE
		and AshTutorLines.CUTAWAY_LINE.begins_with("Drag a part onto a ring to fit it."))
	var vals := {hand = 5, cap = 14, jumps = 2, name = "GAMMA KESTREL REACH", turn = "R", flip = "F"}
	var left: Array[String] = []
	var tallest := 0.0
	for k in AshTutorLines.LINES:
		var s := AshTutorLines.fill(k, vals)
		if s.contains("{"):
			left.append(String(k))
		tallest = maxf(tallest, AshPortrait.size_for(s).y)
	_ok("every field fills (%s)" % ("all" if left.is_empty() else ", ".join(left)), left.is_empty())
	_ok("the longest line's frame is %.0f px tall, at most five lines" % tallest, tallest <= 76.0)
	_ok("one jump reads \"1 jump\", two \"2 jumps\"",
		AshTutorLines.fill(&"fuel_dock", {jumps = 1, name = "X"}).contains("is 1 jump: X")
		and AshTutorLines.fill(&"fuel_dock", {jumps = 2, name = "X"}).contains("is 2 jumps: X"))
	# SHE NEVER SAYS A NUMBER OR A NAME (Jon, numbers:A): every spoken script has
	# no digit and no field, and a line with a field has a script of its own
	var digits := RegEx.create_from_string("[0-9]")
	var said_bad: Array[String] = []
	for k in AshTutorLines.LINES:
		var sp := AshTutorLines.spoken(k)
		var has_field := String(AshTutorLines.LINES[k]).contains("{")
		if sp.contains("{") or sp.contains("}") or (has_field and not AshTutorLines.SPOKEN.has(k)) \
				or (not has_field and sp != String(AshTutorLines.LINES[k])):
			said_bad.append(String(k))
		# (her own "1 hull", "1 heat" are words of the line, not a live value)
		if digits.search(sp.replace("1 hull", "").replace("1 heat", "")) != null:
			said_bad.append("%s has a digit" % k)
	_ok("what she says has no field and no live number; every line with a field has a script (%s)" % [
		"all %d" % AshTutorLines.LINES.size() if said_bad.is_empty() else "NOT " + ", ".join(said_bad)], said_bad.is_empty())
	_ok("the four scripts are Jon's", AshTutorLines.spoken(&"endturn") == "Out of energy. Press END TURN. They act, then you draw new cards."
		and AshTutorLines.spoken(&"heat") == "Heat. Past the limit, we lose 1 hull per point over, at end of turn."
		and AshTutorLines.spoken(&"fuel_dock") == "Fuel is low. Run dry and the run ends. Here's the nearest dock."
		and AshTutorLines.spoken(&"cutaway") == "Drag a part onto a ring to fit it. You can turn it and flip it.")
	_ok("the fuel hint picks its line by the dock: in reach, none, here",
		AshTutorLines.line_id(&"fuel", {jumps = 2}) == &"fuel_dock" and AshTutorLines.line_id(&"fuel", {}) == &"fuel_none"
		and AshTutorLines.line_id(&"fuel", {jumps = 0}) == &"fuel_here")
	var silent := 0
	for k in AshTutorLines.LINES:
		if AshTutorLines.voice_path(k) == "":
			silent += 1
	print("    (%d of %d lines have no take installed: text alone)" % [silent, AshTutorLines.LINES.size()])


# ------------------------------------------------------------------ the used state

func _used_state() -> void:
	print("the used state")
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	_ok("the flags go to the harness settings file (%s)" % Hints.store_path(), Hints.store_path() != DisplaySettings.PATH)
	# a line of hers already said, hints off: her launch
	Hints.forced = false
	var n := _system()
	await _local()
	Ash.waiting.clear()
	Ash._last_end = -INF
	Ash.arm(&"launch")
	await _frames(6)
	_ok("a bark of hers already said this run (%s)" % (Ash.said_log.back().kind if not Ash.said_log.is_empty() else "none"),
		not Ash.said_log.is_empty() and Ash.said_log.back().kind == &"launch")
	if Ash.portrait != null:
		Ash.portrait.cut()
	await _frames(2)
	# the settings file: hints and a step seen, reset, one seen since
	Hints.mark_seen(&"ship")
	Hints.mark_seen(&"wreck")
	Hints.mark_seen(&"step_jump")
	Hints.mark_seen(&"said_step_jump")
	Hints.reset()
	Hints.mark_seen(&"events")
	Hints.reload()
	_ok("after a reset the hints, the steps and her steps' lines are unsaid; one seen since stays seen",
		not Hints.seen(&"ship") and not Hints.said(&"step_jump") and not Hints.seen(&"step_jump") and Hints.seen(&"events"))
	Hints.forced = true
	_ok("on: she teaches, the hints are on", Ash.teaches() and Hints.enabled() and Hints.by_ash())
	_ok("a system to stand in", n != null)


# ------------------------------------------------------------------ the flow

func _flow() -> void:
	print("each moment, in her corner")
	var n := Run.node_at()
	Run.jumps = 0
	Ash._last_end = Ash.now
	# THE FIRST LOCAL: the goal's first step, and not the ship's hint yet
	var sc := await _local()
	await _expect_step(&"step_jump")
	await _never(&"ship", "before the first jump, the ship's hint does not come")
	# THE CHART: its list first, then the step as it reads there
	Router.show_starchart()
	await _frames(40)
	await _expect(&"chart")
	await _expect_step(&"step_jump_chart")
	Router.show_starchart()
	await _frames(40)
	await _never(&"chart", "the chart again: its line does not come back")
	Run.jumps = 1
	# THE MAP: the events were seen since the reset, so the step first
	if n.options.is_empty():
		_plant_event(n)
	Router.show_system()
	await _frames(40)
	await _expect_step(&"step_event_map")
	await _never(&"events", "the map's events were seen before: not said")
	Hints.mark_seen(&"events", false)
	await _expect(&"events")

	# LOCAL WITH A DERELICT, A WRECK THAT HOLDS SOMETHING, A PILE
	var oi := n.options.size()
	n.options.append(&"first_on_the_wreck")
	LocalEventDrawer.last = [n.index, oi]
	sc = await _local()
	SystemMapScreen._parked[n.index] = {at = LocalEventDrawer.body_of(n, oi)}
	var wreck := Run.new_wreck(n, DB.enemies[&"cutter"])
	wreck.items.append(CreditChit.of(40))
	Run.sector_jetsam(n).items.append(CreditChit.of(25))
	sc = await _local()
	await _expect(&"wreck")
	await _expect(&"loot")
	await _expect(&"ship")
	await _expect_step(&"step_event")
	LocalEventDrawer.last = []
	# OVER THE CUTAWAY (her bark rules keep her off it; a lesson may)
	var cut := sc.open_cutaway()
	if _ok("the cutaway opens", cut != null):
		await _frames(30)
		print("    (cutaway: open %s, its rect %s, panel %s %s, pic %s, view %s)" % [cut.is_open(), cut.get_global_rect(),
			cut._panel.get_global_rect(), cut._panel.is_visible_in_tree(), cut.get_global_transform() * cut._pic, Ash.tut_view_rect(sc)])
		await _expect(&"cutaway")
		cut.close_now()
		await _frames(10)
	# OVER THE EVENT BAND
	var pe := _plant_event(n)
	sc._events.open(pe)
	await _frames(30)
	await _expect(&"drawer")
	sc._events.not_now()
	await _frames(20)
	# OVER A WRECK'S WINDOW
	var loaded := Run.new_wreck(n, DB.enemies[&"cutter"])
	loaded.items.append(CreditChit.of(30))
	sc = await _local()
	sc._open_jetsam(loaded)
	await _frames(20)
	await _expect(&"salvage")
	sc._close_transfer()
	await _frames(10)

	# A FIGHT: five lines in one fight, her one-line limit is for barks
	Run.heat = 0
	var f0 := Ash.said_log.size()
	Router.start_combat(DB.enemies[&"cutter"], [], false, false)
	await _frames(40)
	var fs := Router.current as SectorScreen
	var cb: Combat = Router.combat
	if _ok("a fight is up", fs != null and fs.fighting() and cb != null):
		for e in cb.enemies:
			(e as Combat.EnemyState).max_hp = 999
			(e as Combat.EnemyState).hp = 999
		await _expect(&"hand")
		await _play_one(cb)
		await _expect(&"intent")
		while await _play_one(cb):
			pass
		await _expect(&"endturn", &"endturn", JON[&"endturn"].replace("{hand}", str(Run.hand_size())))
		cb.brace = 60
		fs._refresh_player()
		fs._on_end_turn()
		_ok("the next turn comes up", await _settle_turn(fs))
		await _expect(&"brace")
		await _expect(&"heat", &"heat", JON[&"heat"].replace("{cap}", str(Run.heat_cap())))
		var in_fight := 0
		for d: Dictionary in Ash.said_log.slice(f0):
			if d.get("tutorial", false) and String(d.kind) in ["tut_hand", "tut_intent", "tut_endturn", "tut_brace", "tut_heat"]:
				in_fight += 1
		_ok("five teaching lines in one fight (%d)" % in_fight, in_fight == 5)
	Run.heat = 0

	# THE STATION: its decks, its yard's ship, its cutaway
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Run.jumps = 1
	for raw in Run.map:
		var m: MapGen.MapNode = raw
		if m.type == MapGen.NodeType.STATION:
			Run.at = m.index
			m.visited = true
			break
	# (DOCK only at the station itself, Jon's dock:A: park there first)
	Router.park_at_station()
	Router.show_station()
	await _frames(90)
	await _expect(&"dock")
	Hints.mark_seen(&"ship", false)
	await _expect(&"ship")
	var st := Router.current as StationScreen
	Hints.mark_seen(&"cutaway", false)
	if st != null and st.open_cutaway() != null:
		await _frames(30)
		var sct := st._cutaway
		print("    (station cutaway: its rect %s xform %s, panel %s, pic %s, view %s)" % [sct.get_global_rect(), sct.get_global_transform(),
			sct._panel.get_global_rect(), sct.get_global_transform() * sct._pic, Ash.tut_view_rect(st)])
		await _expect(&"cutaway")
		st._cutaway.close_now()
		await _frames(10)

	# FUEL LOW: on the chart, by where the nearest dock is
	n = _system()
	Run.jumps = 1
	Router.show_starchart()
	await _frames(40)
	var was := Run.fuel
	# a third of the tank, and as much of it as still leaves a dock in reach
	Run.fuel = 15
	var d := Run.nearest_dock()
	# (a system a jump or two from a dock: the start may have none in reach)
	for raw in Run.map:
		var m: MapGen.MapNode = raw
		if not d.is_empty() and int(d.jumps) >= 1:
			break
		if m.type == MapGen.NodeType.SYSTEM:
			Run.at = m.index
			d = Run.nearest_dock()
	Router.show_starchart()
	await _frames(40)
	# (what is charted moves with the chart up: asked again as the hint will)
	d = Run.nearest_dock()
	var lid := AshTutorLines.line_id(&"fuel", d)
	_ok("a dock in reach at a third of the tank (%s)" % lid, lid == &"fuel_dock")
	await _expect(&"fuel", lid)
	_ok("fuel_dock: it names the dock and the jumps (\"%s\")" % Ash.said_log.back().line,
		lid != &"fuel_dock" or String(Ash.said_log.back().line).ends_with(": %s." % MapGen.star_name(d.node)))
	await _fuel_unflyable()
	# the other two, through the same hint
	for want: StringName in [&"fuel_none", &"fuel_here"]:
		Hints.mark_seen(&"fuel", false)
		Hints._dock_key = Vector2i(-2, -2)
		if want == &"fuel_none":
			Run.fuel = 1
			Hints._dock = {}
		else:
			for raw in Run.map:
				var m: MapGen.MapNode = raw
				if m.type == MapGen.NodeType.STATION:
					Run.at = m.index
					break
			Run.fuel = 6
		Hints._dock_key = Vector2i(Run.at, Run.fuel)
		Hints._dock = Run.nearest_dock() if want == &"fuel_here" else {}
		Router.show_starchart()
		await _frames(40)
		await _expect(&"fuel", want)
	Run.fuel = was
	_ok("she found room on every screen: no hint came as a card (%s)" % str(Hints.fallback_log), Hints.fallback_log.is_empty())
	print("    where she stood:")
	for k in _screens:
		print("      %-16s %s" % [k, _screens[k]])


## THE CHART'S DOCK SHE MUST NOT NAME (Jon, Oct 18: "hint:fix"). A heavy frame
## reaches past its dish, so a dock you have visited can sit in reach, on the
## chart, and out of sight, which `can_jump_to` refuses. Routed over the chart
## the hint named it at one jump; she must name the dock the ship can fly to,
## or say none is in reach.
func _fuel_unflyable() -> void:
	var mfr := Run.hull.manufacturer
	var weight := Run.hull.weight
	var at0 := Run.at
	Run.fit_chassis(&"korvan", HullData.Weight.HEAVY)
	for raw in Run.map:
		if (raw as MapGen.MapNode).type == MapGen.NodeType.STATION:
			(raw as MapGen.MapNode).visited = true
	var bad: MapGen.MapNode = null
	for raw in Run.map:
		var m: MapGen.MapNode = raw
		if m.type != MapGen.NodeType.SYSTEM:
			continue
		Run.at = m.index
		Run.chart_from(m)
		Run.fuel = 15
		# the chart's one-jump dock, least fuel first, as the old route chose it
		var pick: MapGen.MapNode = null
		for raw2 in Run.map:
			var s: MapGen.MapNode = raw2
			if s.type != MapGen.NodeType.STATION or not Run.charted(s) or not Run.reachable_from(m, s) 					or Run.fuel_cost_to(s) > Run.fuel:
				continue
			if pick == null or Run.fuel_cost_to(s) < Run.fuel_cost_to(pick):
				pick = s
		if pick != null and not pick.sensed:
			bad = pick
			break
	if _ok("fuel, the chart's dock: %s, one jump on the chart, which the ship cannot fly to"
			% (MapGen.star_name(bad) if bad != null else "none found"), bad != null and not Run.can_jump_to(bad)):
		Hints.mark_seen(&"fuel", false)
		Hints._dock_key = Vector2i(-2, -2)
		Router.show_starchart()
		await _frames(40)
		var d := Run.nearest_dock()
		var lid := AshTutorLines.line_id(&"fuel", d)
		await _expect(&"fuel", lid)
		var said := String(Ash.said_log.back().line)
		_ok("she names the dock it can reach, not the chart's one jump (\"%s\", %d jumps)" % [said, int(d.get("jumps", 0))],
			(d.is_empty() and lid == &"fuel_none")
			or (not d.is_empty() and not (d.node == bad and int(d.jumps) == 1) and said.ends_with(": %s." % MapGen.star_name(d.node))))
	Run.fit_chassis(mfr, weight)
	Run.at = at0
	Run.chart_from(Run.node_at())


func _play_one(cb: Combat) -> bool:
	for i in cb.hand.size():
		var c: CardData = cb.hand[i]
		if cb.can_play(c):
			cb.play(i, 0)
			await _frames(6)
			return true
	return false


func _settle_turn(sc: SectorScreen) -> bool:
	for i in 600:
		await _tree.process_frame
		if not sc._hold and not sc._opening and sc._end_button != null \
				and sc._end_button.is_visible_in_tree() and not sc._end_button.disabled:
			await _frames(4)
			return true
	return false


# ------------------------------------------------------------------ barks

func _bark_and_lesson() -> void:
	print("a bark never interrupts a teaching line")
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	_system()
	Run.jumps = 1
	Hints.reset()
	for id in Hints.ORDER:
		if id != &"ship":
			Hints.mark_seen(id)
	for id in Hints.STEP_LINES:
		Hints.mark_seen(StringName("said_" + String(id)))
	await _local()
	_ok("the ship's line comes", await _until_said(&"ship"))
	var n0 := Ash.said_log.size()
	Ash._last_end = -INF
	Ash.arm(&"haul")
	Run.hp = maxi(1, int(Run.max_hp() * 0.2))
	for i in 60:
		Hints.poll(1.0 / 60.0)
		await _tree.process_frame
	var barks := Ash.said_log.slice(n0).filter(func(d: Dictionary) -> bool: return not d.get("tutorial", false))
	_ok("a big bark and an ordinary one waiting: neither starts over her line (held by %s, %d said)" % [Ash.held_by, barks.size()],
		barks.is_empty() and Ash.lesson == &"ship" and Ash.lesson_up())
	Hints.poll(0.3)
	Hints.click(_press())
	Hints.poll(Hints.GAP_S + 0.1)
	await _frames(2)
	Ash._last_end = -INF
	var said_bark := false
	for i in 120:
		Hints.poll(1.0 / 60.0)
		await _tree.process_frame
		if Ash.said_log.size() > n0 and not Ash.said_log.back().get("tutorial", false):
			said_bark = true
			break
	_ok("once it is spent, the bark is said (%s)" % (Ash.said_log.back().kind if said_bark else "none"), said_bark)
	Run.hp = Run.max_hp()
	# A TEACHING LINE CUTS A BARK
	_ok("a bark is up", Ash.portrait.speaking() and not Ash.portrait.kind.begins_with("tut_"))
	Hints.mark_seen(&"ship", false)
	Hints._quiet = 0.0
	var cut_it := false
	for i in 40:
		Hints.poll(0.1)
		await _tree.process_frame
		if Ash.lesson == &"ship" and Ash.lesson_up():
			cut_it = true
			break
	_ok("a teaching line due cuts the bark and is said", cut_it and Ash.portrait.kind == &"tut_ship")
	Hints.poll(0.3)
	Hints.click(_press())
	Hints.poll(Hints.GAP_S + 0.1)
	Ash.waiting.clear()


# ------------------------------------------------------------------ the voice

func _voice() -> void:
	print("her voice")
	Audio.taping = true
	Audio.tape.clear()
	await _local()
	Hints.mark_seen(&"ship", false)
	Hints._quiet = 0.0
	# NO TAKE: every line has one now (Jon's picks, Oct 18), so the silent path is
	# held by a stand-in naming no file
	AshTutorLines.stand_in = {"tut_ship": ""}
	var up: bool = await _until_said(&"ship")
	var p := Ash.portrait
	_ok("no take: nothing taped, the words typed at once at her text pace", up and p.voice == ""
		and Audio.tape.filter(func(r: Array) -> bool: return String(r[0]).begins_with("ash/tut")).is_empty()
		and p.typed_at >= 0.0)
	Hints.poll(0.3)
	Hints.click(_press())
	Hints.poll(Hints.GAP_S + 0.1)
	# A TAKE (a stand-in: one of her recorded lines)
	AshTutorLines.stand_in = {"tut_ship": "res://assets/audio/voice/ash/haul_04.ogg"}
	Hints.mark_seen(&"ship", false)
	Hints._quiet = 0.0
	Router.animate_in_harness = true
	await _until_said(&"ship")
	p = Ash.portrait
	var t0 := GameClock.now()
	while p.phase != AshPortrait.Phase.HOLDING and GameClock.now() - t0 < 10.0:
		await _tree.process_frame
	var said := p.voice_secs - AshPortrait.VOICE_TAIL_S
	var off := absf(p.typed_for - said) / maxf(said, 0.001)
	_ok("a take: played once (%s), the words typed as long as she speaks (%.2f s against %.2f, %.0f%%)" % [
		str(Audio.tape.filter(func(r: Array) -> bool: return String(r[0]).begins_with("ash/haul")).size()), p.typed_for, said, off * 100.0],
		p.voice.ends_with("haul_04.ogg") and off <= 0.10)
	Audio.tape.clear()
	Hints.poll(0.3)
	Hints.click(_press())
	_ok("a click stops her voice", Audio.voice_now == "")
	# THE SHOWN WORDS, NUMBERS AND NAMES IN THEM, END WHEN SHE STOPS, whether her
	# take (from the SPOKEN script) is shorter or longer than they are: a short
	# take under the long dock line, a long one under the END TURN line
	var spans: Array[String] = []
	var span_ok := true
	for c: Array in [[&"fuel_dock", {jumps = 2, name = "GAMMA KESTREL REACH"}, "res://assets/audio/voice/ash/haul_03.ogg"],
			[&"endturn", {hand = 5}, "res://assets/audio/voice/ash/doubt_03.ogg"]]:
		var shown := AshTutorLines.fill(c[0], c[1])
		p.say(shown, StringName("tut_" + String(c[0])), {voice = c[2], spoken = AshTutorLines.spoken(c[0]), held = true})
		var s0 := GameClock.now()
		while p.phase != AshPortrait.Phase.HOLDING and GameClock.now() - s0 < 10.0:
			await _tree.process_frame
		var talk := p.voice_secs - AshPortrait.VOICE_TAIL_S
		var o := absf(p.typed_for - talk) / maxf(talk, 0.001)
		span_ok = span_ok and o <= 0.10 and p._text.done and p._text.text == shown
		spans.append("%s: %d letters typed in %.2f s, her take %.2f s" % [c[0], shown.length(), p.typed_for, talk])
		p.cut()
	_ok("the shown words end with her take, shorter or longer (%s)" % "; ".join(spans), span_ok)
	Router.animate_in_harness = false
	AshTutorLines.stand_in = {}
	Audio.taping = false
	Audio.tape.clear()
	Hints.poll(Hints.GAP_S + 0.1)


# ------------------------------------------------------------------ the switch

func _switch() -> void:
	print("her switch off brings the cards back")
	await _local()
	Hints.mark_seen(&"ship", false)
	Hints._quiet = 0.0
	_ok("her line is up", await _until_said(&"ship"))
	Ash.set_on(false)
	var card := false
	for i in 40:
		Hints.poll(0.1)
		await _tree.process_frame
		if Hints.card != null and Hints.card.id == &"ship":
			card = true
			break
	_ok("switched off mid-line: she goes, unspent, and the hint comes as today's card", card and not Hints.seen(&"ship")
		and (Ash.portrait == null or not Ash.portrait.speaking()) and Ash.lesson == &"")
	if card:
		var labels: Array[String] = []
		for l in Hints.card.find_children("*", "Label", true, false):
			labels.append((l as Label).text)
		_ok("the card's words are today's (%s)" % " / ".join(labels), str(labels) == str(Hints.lines(&"ship")))
		_ok("no outline of hers on it", Ash.outline_rect() == Rect2())
		Hints.poll(0.3)
		Hints.click(_press())
		_ok("and its click spends it, as before", Hints.seen(&"ship") and Hints.card == null)
	Hints.poll(Hints.GAP_S + 0.1)
	# off from the start: every hint a card, nothing of hers
	Hints.mark_seen(&"wreck", false)
	Hints.mark_seen(&"loot", false)
	var n := Run.node_at()
	var w := Run.new_wreck(n, DB.enemies[&"cutter"])
	w.items.append(CreditChit.of(40))
	Run.sector_jetsam(n).items.append(CreditChit.of(25))
	await _local()
	var said := Ash.said_log.size()
	var cards: Array[String] = []
	for i in 80:
		Hints.poll(0.1)
		await _tree.process_frame
		if Hints.card != null and Hints._up_t > 0.3:
			cards.append(String(Hints.card.id))
			Hints.click(_press())
			Hints.poll(Hints.GAP_S + 0.1)
	_ok("off: the hints are cards (%s) and she says nothing" % ", ".join(cards),
		cards.size() >= 2 and Ash.said_log.size() == said)
	Ash.set_on(true)


# ------------------------------------------------------------------ her introduction

## HER FIRST LINE INTRODUCES HER (Jon, Oct 18, "intro:A"), through real new runs
## with her and the hints both on the game's clock, as in play. Read through the
## settings file and her log, not her own calls, so it fails on a game without it.
func _intro() -> void:
	print("her first line introduces her")
	var intro := String(AshLines.of(&"launch")[3])
	_ok("the intro is launch_04, voiced (\"%s\")" % intro, AshLines.id_of(intro) == &"launch_04"
		and intro == "Autonomous Systems Handler, reporting. Please don't make me handle much."
		and AshLines.voice_path(intro).ends_with("/launch_04.ogg"))
	# A FRESH PROFILE, in the used state: lines of hers said this process, the
	# flag unset, every hint and step unseen
	_intro_flag_set(false)
	Hints.reset()
	Ash.reload()
	Hints._quiet = 0.0
	Audio.taping = true
	Audio.tape.clear()
	Hints.set_process(true)
	var n0 := Ash.said_log.size()
	Rng.forced = 5150
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Router.show_local()
	var w := await _watch_launch(n0, &"step_jump")
	var first: Dictionary = w.first
	_ok("a fresh profile's first launch: her first line is the intro (%s: \"%s\")" % [first.get("kind", &"none"),
		first.get("line", "")], first.get("kind", &"") == &"launch" and String(first.get("line", "")) == intro)
	_ok("in the launch's slot: on LOCAL, before the first jump, at one of her bark spots (%s)" % first.get("spot", &""),
		Run.jumps == 0 and Router.current is SectorScreen and Ash.SPOTS.has(StringName(first.get("spot", &""))))
	var taped: Array = Audio.tape.filter(func(r: Array) -> bool: return String(r[0]).begins_with("ash/"))
	_ok("its clip plays: launch_04 taped once, not cut (%s)" % ", ".join(taped.map(func(r: Array) -> String: return String(r[0]))),
		taped.size() >= 1 and taped[0][0] == &"ash/launch_04"
		and taped.filter(func(r: Array) -> bool: return r[0] == &"ash/launch_04").size() == 1
		and (taped.size() < 2 or taped[1][0] != &"ash/stop"))
	_ok("the flag is saved ([hints] ash_intro in %s)" % DisplaySettings.hints_path(), _intro_flag())
	_ok("the step never cut it: it ended of itself (%s) before the step began" % ("of itself" if w.natural else "cut"),
		w.natural and w.intro_end > 0.0 and w.step_at >= w.intro_end)
	_ok("the goal's first step follows it (%.2f s after; between them: %s)" % [w.step_at - w.intro_end,
		", ".join(w.between) if not w.between.is_empty() else "nothing"],
		w.step_at > 0.0 and w.step_at - w.intro_end <= 2.0 + 15.0 * float(w.between.size()))
	Hints.set_process(false)
	if Ash.portrait != null:
		Ash.portrait.cut()
	Audio.taping = false
	Audio.tape.clear()
	# (the hints' clock stops with the step's line up: let it go)
	Hints.reset()

	# LATER RUNS: the bag's, as before (nothing taught, so the launch comes at once)
	var picks: Dictionary = {}
	var all_pool := true
	for i in 8:
		for id in Hints.ORDER + Hints.STEPS:
			Hints.mark_seen(id)
		for id in Hints.STEP_LINES:
			Hints.mark_seen(StringName("said_" + String(id)))
		var n1 := Ash.said_log.size()
		Rng.forced = 6000 + i
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
		await _local()
		# (the last run's line was cut by hand: no quiet carried over from it)
		Ash._last_end = -INF
		for f in 120:
			if Ash.said_log.size() > n1:
				break
			await _tree.process_frame
		var got: Dictionary = Ash.said_log[n1] if Ash.said_log.size() > n1 else {}
		if got.is_empty():
			print("    (run %d: nothing said; held by %s, waiting %s)" % [i, Ash.held_by, Ash.waiting.keys()])
		var l := String(got.get("line", ""))
		all_pool = all_pool and got.get("kind", &"") == &"launch" and AshLines.of(&"launch").has(l)
		picks[l] = int(picks.get(l, 0)) + 1
		if Ash.portrait != null:
			Ash.portrait.cut()
	_ok("eight later runs: each first launch is from the pool, not forced (%s)" % str(picks.values()),
		all_pool and picks.size() >= 2 and int(picks.get(intro, 0)) < 8)
	_ok("the flag stays", _intro_flag())

	# A PROFILE THAT HAS THE FLAG, hints shown again: today's order (the step,
	# then a launch from the bag); SHOW HINTS AGAIN does not bring the intro back
	Hints.reset()
	Ash.reload()
	_ok("SHOW HINTS AGAIN leaves the flag", _intro_flag())
	Hints._quiet = 0.0
	Hints.set_process(true)
	var n2 := Ash.said_log.size()
	Rng.forced = 5150
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Router.show_local()
	var w2 := await _watch_launch(n2, &"step_jump")
	var f2: Dictionary = w2.first
	_ok("the flag set: no forced intro, the step comes first as today (first: %s)" % f2.get("kind", &"none"),
		f2.get("kind", &"") == &"tut_step_jump")
	Hints.set_process(false)
	if Ash.portrait != null:
		Ash.portrait.cut()
	Hints.reset()
	Ash.waiting.clear()


## Watch a launch frame by frame until her line `step` (or 40 s): the first
## line she says, when the first launch line stops being said and whether of
## itself, when the step starts, and what came between. A hint before the step
## is clicked through, as a player would.
func _watch_launch(n0: int, step: StringName) -> Dictionary:
	var out := {first = {}, intro_end = -1.0, natural = false, step_at = -1.0, between = []}
	var watching := false
	var t0 := GameClock.now()
	while GameClock.now() - t0 < 40.0:
		await _tree.process_frame
		if (out.first as Dictionary).is_empty() and Ash.said_log.size() > n0:
			out.first = Ash.said_log[n0]
			watching = out.first.kind == &"launch"
		var p := Ash.portrait
		if watching and float(out.intro_end) < 0.0 and (p == null or not p.speaking() or p.kind != &"launch"):
			out.intro_end = GameClock.now()
			out.natural = p != null and p._natural and p.kind == &"launch"
		if Hints.lesson != &"" and Hints._up_t > 0.5:
			(out.between as Array).append(String(Hints.lesson))
			Hints.click(_press())
		if Ash.lesson == step and Ash.lesson_up():
			out.step_at = GameClock.now()
			break
	return out


func _intro_flag() -> bool:
	var cfg := ConfigFile.new()
	return cfg.load(DisplaySettings.hints_path()) == OK and bool(cfg.get_value("hints", "ash_intro", false))


func _intro_flag_set(v: bool) -> void:
	var cfg := ConfigFile.new()
	cfg.load(DisplaySettings.hints_path())
	cfg.set_value("hints", "ash_intro", v)
	cfg.save(DisplaySettings.hints_path())


# ------------------------------------------------------------------ a first launch, as seen

## A RUN'S FIRST LAUNCH AS PLAYED (Jon, Oct 20: "A.S.H. introduces herself and
## also reads the tutorial at the same time. The GOAL and the tutorial tip are
## right under her box."), the screens animating as in play (the goal line
## fades in, so it is not drawn on the frame the ship stops), her and the hints
## on the game's clock. Both profiles: one that has not heard her introduction
## (the intro, then the step), and one that has (the step, then a launch line
## from the bag). Every frame: one line of hers at a time, none cut by the next,
## and her box clear of the goal, the step's line as drawn and the step's place.
func _first_launch() -> void:
	print("a first launch, as seen")
	# THE FRAME THE SHIP STOPS: the goal line is up from it but not drawn yet (it
	# fades in, and its own frame may come after hers). The step is due all the
	# same, so a launch line waits for it -- in play the line asked the drawn
	# line, the launch started there and the step cut it 0.6 s later
	_intro_flag_set(true)
	Hints.reset()
	Ash.reload()
	Rng.forced = 5150
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	await _local()
	var gl := Router.hud.get_parent().get_node_or_null("GoalLine") as Control
	if gl != null:
		gl.visible = false
		gl.modulate.a = 0.0
		var due := Hints.step_due()
		var why := Ash._cannot_start(&"launch")
		_ok("the goal line up but not yet drawn: the step is due and a launch line waits for it (due %s, held by %s)" % [due, why],
			due and why == "hint")
		gl.visible = true
		gl.modulate.a = 1.0
	Ash.waiting.clear()
	for heard: bool in [false, true]:
		_intro_flag_set(heard)
		Hints.reset()
		Ash.reload()
		Hints._quiet = 0.0
		Hints.set_process(true)
		Router.animate_in_harness = true
		var n0 := Ash.said_log.size()
		Rng.forced = 5150
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
		Router.show_local()
		var cuts: Array[String] = []
		var over: Array[String] = []
		var prev := &""
		var t0 := GameClock.now()
		var goal := Router.hud.get_parent().get_node_or_null("GoalLine") as Control
		while GameClock.now() - t0 < 60.0:
			await _tree.process_frame
			var p := Ash.portrait
			var now_kind: StringName = p.kind if p != null and p.speaking() else &""
			# ONE LINE AT A TIME: a line still saying, replaced by another
			if prev != &"" and now_kind != &"" and now_kind != prev:
				cuts.append("%s cut by %s" % [prev, now_kind])
			prev = now_kind
			if now_kind != &"":
				var r := p.rect()
				var under: Array = []
				if goal != null and goal.visible and goal.modulate.a > 0.0:
					under.append(["the goal line", Rect2(goal.global_position, goal.size)])
				under.append_array(_step_boxes(goal))
				for b: Array in under:
					if r.intersects(b[1]) and over.size() < 4:
						over.append("%s over %s %s at %.2f s" % [now_kind, b[0], b[1], GameClock.now() - t0])
			if Hints.lesson != &"" and Hints._up_t > 0.5:
				Hints.click(_press())
			if Ash.said_log.size() >= n0 + 2 and now_kind == &"":
				break
		var order: Array[String] = []
		for d: Dictionary in Ash.said_log.slice(n0):
			order.append(String(d.kind))
		var want: Array[String] = []
		want.assign(["launch", "tut_step_jump"] if not heard else ["tut_step_jump", "launch"])
		var who := "heard her introduction" if heard else "a fresh profile"
		_ok("%s: her lines in order %s (said %s)" % [who, want, order], order.slice(0, 2) == want)
		if not heard:
			_ok("%s: the first is the intro" % who, order.size() > 0
				and String(Ash.said_log[n0].line) == String(AshLines.of(&"launch")[3]))
		_ok("%s: one line at a time, none cut by the next (%s)" % [who, ", ".join(cuts) if not cuts.is_empty() else "none"], cuts.is_empty())
		_ok("%s: her box never over the goal or the step's line (%s)" % [who, "; ".join(over) if not over.is_empty() else "clear every frame"], over.is_empty())
		Hints.set_process(false)
		Router.animate_in_harness = false
		if Ash.portrait != null:
			Ash.portrait.cut()
		await _frames(2)
		Hints.reset()
		Ash.waiting.clear()


# ------------------------------------------------------------------ co-op

func _coop() -> void:
	print("off in a party")
	await _local()
	Hints.reset()
	var was_state = Net.state
	Net.state = Net.State.HOSTING
	var said := _taught()
	for i in 40:
		Hints.poll(0.1)
		await _tree.process_frame
	_ok("in a party: no hint, no step, no teaching line (taught %d, card %s)" % [_taught() - said,
		Hints.card != null], not Hints.enabled() and _taught() == said and Hints.card == null
		and Hints.lesson == &"" and Hints.step_up == &"")
	Net.state = was_state


func _taught() -> int:
	var n := 0
	for d: Dictionary in Ash.said_log:
		if d.get("tutorial", false):
			n += 1
	return n


func _finish() -> void:
	Ash.forced = false
	Hints.forced = false
	Hints.set_process(true)
	Hints.set_process_input(true)
	Hints.reset()
	print("  %d checks" % _checks)
	print("ashtutortest: %s" % ("PASS" if _fails == 0 else "%d FAILURES" % _fails))
	_tree.quit(1 if _fails > 0 else 0)
