class_name GoalLine
extends Control

## THE GOAL, ALWAYS, AND THE NEXT STEP WHILE ONE IS PENDING (tutorial direction
## B, "learn by doing", Jon Oct 17). Two quiet lines under the HUD:
##
##   GOAL: REACH THE CORE
##   Open STARCHART. Pick a star in range, then JUMP.
##
## The second line only while a step is pending, with the HUD tab it names
## outlined (`cue`). The tour that used to say the goal once, for three seconds,
## is gone; this says it for as long as a run lasts.
##
## THE STEPS, each done once per profile (`Hints.STEPS`, `[hints] step_*`,
## cleared by SHOW HINTS AGAIN), and only where the hints are on (`Hints.enabled`,
## so never under a harness that did not ask):
##   step_jump   no jump made yet: open STARCHART, pick a star, JUMP. Done at the
##               first jump.
##   step_event  after it, in a system with an event open: click one, then GO.
##               Done when an event's band is up on LOCAL.
##
## HOSTED BY THE HUD (`HudBar`) and drawn beside it, in the HUD's own column
## after the screens, so it is over the picture and under the escape menu. It
## is `top_level`, so the column does not lay it out; it places itself.
##
## ONE PLACE, ALWAYS (Jon, Oct 18: "Can we have the goal: xxx always be in this
## location?"), the same on all three and through every move between them
## (`fixed_at`). WHERE (Jon, Oct 20): not in the map's and the chart's top plate
## left of their DANGER / LAYER, but just below it, at the top left of their
## picture; and at that same place on LOCAL. The step's line, while one is
## pending, directly under it, the same on all three (`step_at`). Both have the
## step's dim backing: they stand over the picture. The two lines' room is kept
## whether a step is pending or not (`stack_rect`), so A.S.H., who keeps off it,
## is never sent away by a step arriving. `-- sheet=GoalTest` holds both clear
## of everything on every screen they show on (`avoid_rects` lists what that is).
##
## IT IS NOT A CONTROL, and does not look like one: no plate, no edge, no hover,
## no hand; it ignores the mouse, so a click goes through it. It stays up
## through a move between LOCAL, the map and the chart (a piece of the HUD);
## hidden over any other move, a jump's departure and an arrival (it comes up
## when the ship stops), the cutaway, a wreck's window and the escape menu, and
## off the three flight screens.

const GOAL := "GOAL: REACH THE CORE"
## Every step's line as shown (`step`), for the room the step keeps (`stack_rect`).
const STEP_TEXTS: Array[String] = ["Open STARCHART. Pick a star in range, then JUMP.",
	"Pick a star in range, then JUMP.", "Open SECTOR. Click an event, then GO.", "Click an event, then GO."]
## THE GOAL'S PLACE from the screens' area's corner (Jon, Oct 20: just below the
## map's and the chart's top plate, at the top left): the plate is 27 px tall
## and 4 px above the picture's frame, whose content margin is 12; then 4 px
## into the picture, where the step used to stand. LOCAL takes the same place
## (`GoalTest` and `CalmLadderTest` hold it to the map's and the chart's picture).
const AT := Vector2(16.0, 47.0)
## Between the goal's line and the step's, px.
const GAP := 1.0
## One line's height with its backing, px (where it cannot be measured).
const LINE_H := 13.0
## The fade in and out, s (none under reduced motion or headless).
const FADE_S := 0.2

var _panel: PanelContainer
var _step_panel: PanelContainer
var _goal: Label
var _step: Label
## The HUD tab the step names (&"chart" / &"sector"), or &"".
var cue: StringName = &""
var _want := false
var _tw: Tween = null
var _backed: StyleBoxFlat


func _init() -> void:
	name = "GoalLine"
	top_level = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	visible = false
	modulate.a = 0.0
	_panel = PanelContainer.new()
	# THE GOAL, on the step's dim backing: it stands over the picture now (Jon,
	# Oct 20), on a bright sky too; the same look on all three, a fixed piece of
	# the HUD
	_backed = UITheme.flat(Color(UITheme.VOID, 0.72), Color(0, 0, 0, 0), 0, 1, 5)
	_panel.add_theme_stylebox_override("panel", _backed)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	_goal = UITheme.body(GOAL, UITheme.EMBER, UITheme.FS_SMALL)
	_goal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_goal)
	# THE STEP, its own line on the same backing, directly under the goal
	_step_panel = PanelContainer.new()
	_step_panel.add_theme_stylebox_override("panel", _backed)
	_step_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_step_panel)
	_step = UITheme.body("", UITheme.CHILL, UITheme.FS_SMALL)
	_step.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_step_panel.add_child(_step)


## The step pending now, as {text, tab, id}; {} for none. Marks a step done the
## first time it sees it done. `id` is the line A.S.H. says for it as it starts
## (`AshTutorLines`, `Hints` decides when).
static func step() -> Dictionary:
	if Run.hull == null or not Hints.enabled():
		return {}
	var cur := Router.current
	# NOT IN A FIGHT: the tabs every step names are locked there ("Locked during
	# combat."), so a step would be a thing to do that cannot be done; and the
	# fight's top left is the one place A.S.H. has clear in every fight
	if _fighting(cur):
		return {}
	if not Hints.seen(&"step_jump"):
		if Run.jumps >= 1:
			Hints.mark_seen(&"step_jump")
		elif cur is StarchartScreen:
			return {text = "Pick a star in range, then JUMP.", tab = &"", id = &"step_jump_chart"}
		else:
			return {text = "Open STARCHART. Pick a star in range, then JUMP.", tab = &"chart", id = &"step_jump"}
	if Run.jumps >= 1 and not Hints.seen(&"step_event"):
		var sc := cur as SectorScreen
		if sc != null and sc._events != null and is_instance_valid(sc._events) and sc._events.page != &"":
			Hints.mark_seen(&"step_event")
			return {}
		if _open_events() > 0:
			if cur is SystemMapScreen:
				return {text = "Click an event, then GO.", tab = &"", id = &"step_event_map"}
			return {text = "Open SECTOR. Click an event, then GO.", tab = &"sector", id = &"step_event"}
	return {}


## How many events here are still open to take.
static func _open_events() -> int:
	var n := Run.node_at()
	if n == null:
		return 0
	OptionTable.ensure(n)
	var k := 0
	for i in n.options.size():
		var kind: StringName = EncounterDrawer.option_state(n, i).kind
		if kind == &"open" or kind == &"left":
			k += 1
	return k


func _process(_d: float) -> void:
	refresh()


## Words, place and whether it shows, from the screens as they are now.
func refresh() -> void:
	var cur := Router.current
	var want := shows_on(cur)
	var st := step() if want else {}
	_step.text = String(st.get("text", ""))
	_step.visible = _step.text != ""
	_step_panel.visible = _step.visible
	cue = StringName(st.get("tab", &""))
	if want:
		var sz := _panel.get_combined_minimum_size()
		_panel.size = sz
		size = sz
		position = fixed_at()
		if _step.visible:
			var ssz := _step_panel.get_combined_minimum_size()
			_step_panel.size = ssz
			_step_panel.position = step_at(cur) - position
	_fade(want)
	queue_redraw()


## THE GOAL'S ONE PLACE (Jon, Oct 18: "Can we have the goal: xxx always be in
## this location?"; Oct 20: just below the map's and the chart's top plate, top
## left, and the same on LOCAL): the same on all three and through every move
## between them, a fixed piece of the HUD.
static func fixed_at() -> Vector2:
	var c := Router.content.get_global_rect() if Router.content != null else Rect2(8, 42, 944, 491)
	return c.position + AT


## Where the step's line goes (global): directly under the goal, on all three.
func step_at(_cur: Control = null) -> Vector2:
	return fixed_at() + Vector2(0, _line_h() + GAP)


static func _line_h() -> float:
	var g: GoalLine = Router.hud.goal if Router.hud != null and is_instance_valid(Router.hud) else null
	if g != null and is_instance_valid(g) and g._panel.size.y > 0.0:
		return g._panel.size.y
	return LINE_H


## THE ROOM THE GOAL AND ITS STEP KEEP (global), whether a step is pending or
## not: the goal's line and the widest step's under it. Empty off the screens
## it shows on. A.S.H. keeps off it (`Ash.avoid_rects`), so a step arriving
## never lands on her.
static func stack_rect(cur: Control) -> Rect2:
	if cur == null or not is_instance_valid(cur) or not (cur is SectorScreen or cur is SystemMapScreen or cur is StarchartScreen):
		return Rect2()
	var font := UITheme.pixel_font()
	var w := font.get_string_size(GOAL, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x
	# (in a fight there is no step: the goal's line alone, `step`)
	if _fighting(cur):
		return Rect2(fixed_at(), Vector2(ceilf(w) + 10.0, _line_h()))
	for t: String in STEP_TEXTS:
		w = maxf(w, font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x)
	# (the backing's 5 px each side)
	return Rect2(fixed_at(), Vector2(ceilf(w) + 10.0, _line_h() * 2.0 + GAP))


static func _fighting(cur: Control) -> bool:
	var sc := cur as SectorScreen
	return sc != null and is_instance_valid(sc) and sc.fighting()


## The step's line as drawn (global), or empty.
func step_rect() -> Rect2:
	return Rect2(position + _step_panel.position, _step_panel.size) if visible and _step_panel.visible else Rect2()


## On LOCAL (a fight too), the sector map and the chart, with a run, nothing
## over them and the camera still. Static: whether it is up this frame, though
## its own `_process` has yet to run (`Hints.step_due`, which A.S.H.'s barks
## wait on, asks before the line has come up).
static func shows_on(cur: Control) -> bool:
	if Run.hull == null or Run.dead or cur == null or not is_instance_valid(cur):
		return false
	if Router.hud == null or not Router.hud.is_visible_in_tree():
		return false
	if Hints.menu_up():
		return false
	# (through a move between LOCAL, the map and the chart it stays: a fixed
	# piece of the HUD; any other move, the dive or the dock, takes it)
	if ZoomLadder.busy() and not (bool(ZoomLadder.active.get("_calm")) and Router.nav_screen(cur)):
		return false
	if cur is SectorScreen:
		var sc := cur as SectorScreen
		# not over a jump's departure or an arrival: it comes up when the ship
		# stops and the controls are yours
		if sc._phase != SectorScreen.Phase.NONE:
			return false
		if sc._cutaway != null or sc._transfer != null or sc._card != null:
			return false
		var d := sc._events
		if d != null and is_instance_valid(d) and d._transfer != null and is_instance_valid(d._transfer):
			return false
		return true
	return cur is SystemMapScreen or cur is StarchartScreen


## The map's and the chart's picture inside its frame, global; empty elsewhere.
static func picture_rect(cur: Control) -> Rect2:
	var inner: Control = null
	if cur is StarchartScreen:
		inner = (cur as StarchartScreen)._chart
	elif cur is SystemMapScreen:
		inner = (cur as SystemMapScreen)._frame
	if inner == null or not is_instance_valid(inner) or not inner.is_visible_in_tree():
		return Rect2()
	return inner.get_global_rect()


## The frame round that picture (its panel), global.
static func frame_rect(cur: Control) -> Rect2:
	var inner: Rect2 = picture_rect(cur)
	if inner.size == Vector2.ZERO:
		return Rect2()
	var c: Control = (cur as StarchartScreen)._chart if cur is StarchartScreen else (cur as SystemMapScreen)._frame
	var p := c.get_parent_control()
	return p.get_global_rect() if p != null else inner


## EVERYTHING IT MUST NOT COVER on `cur`, global. Public: `GoalTest` measures
## against the same list, and a little more (`-- sheet=GoalTest`).
static func avoid_rects(cur: Control) -> Array:
	var out: Array = []
	if Router.hud != null and is_instance_valid(Router.hud):
		out.append(Router.hud.get_global_rect())
	if cur == null or not is_instance_valid(cur):
		return out
	# the side bar, and the toolbar row's own pieces (its spacers are air)
	if cur.has_method("ladder_side"):
		var side: Control = cur.call("ladder_side")
		if side != null and is_instance_valid(side) and side.is_visible_in_tree():
			out.append(side.get_global_rect())
	if cur.has_method("ladder_bar"):
		var bar: Control = cur.call("ladder_bar")
		if bar != null and is_instance_valid(bar) and bar.is_visible_in_tree():
			_inked(bar, out)
	# the map's and the chart's frame (its picture, inside, is the second row's)
	var fr := frame_rect(cur)
	if fr.size != Vector2.ZERO:
		out.append(fr)
	if cur is SectorScreen:
		var sc := cur as SectorScreen
		# the fight log's LOG button at the band's right end (`FightLog`)
		out.append_array(FightLog.rects(sc))
		var d := sc._events
		if d != null and is_instance_valid(d) and d.visible:
			out.append(d.get_global_rect())
		if sc._quiet_holder != null and sc._quiet_holder.is_visible_in_tree():
			out.append(sc._quiet_holder.get_global_rect())
		if sc._hand != null and sc._hand.is_visible_in_tree():
			out.append(sc._hand.get_global_rect())
		var v := sc._view
		if v != null:
			var ship := v.ship_view()
			if ship != null and ship.is_visible_in_tree():
				out.append(ship.get_global_transform() * ship.ship_rect())
			if sc._self_plate != null and sc._self_plate.is_visible_in_tree():
				out.append(sc._self_plate.get_global_rect())
			for i in 12:
				var sl := v.slot(i)
				if sl == null or not sl.is_visible_in_tree():
					continue
				out.append(sl.get_global_transform() * sl.ink_rect())
				for r: Rect2 in [sl.intent_rect_global(), sl.readout_rect_global()]:
					if r.size != Vector2.ZERO:
						out.append(r)
			var subj := LocalSubject.of(v)
			if subj != null:
				out.append_array(subj.drawn_rects())
	return out


## The boxes of what is drawn in `c`: its labels, buttons and panels, not the
## containers and spacers that only hold them apart.
static func _inked(c: Control, out: Array) -> void:
	for ch in c.get_children():
		var k := ch as Control
		if k == null or not k.is_visible_in_tree() or k.size.x <= 0.0:
			continue
		if k is Label or k is BaseButton or k is Panel or k is TextureRect or k is PanelContainer:
			out.append(k.get_global_rect())
		elif k is Container:
			_inked(k, out)
		elif k.get_child_count() > 0:
			_inked(k, out)
		elif k.get_class() != "Control" or k.get_script() != null:
			# something that draws itself
			out.append(k.get_global_rect())


func _fade(on: bool) -> void:
	if on == _want:
		return
	_want = on
	if _tw != null and _tw.is_valid():
		_tw.kill()
	if not Router.animating() or not is_inside_tree():
		modulate.a = 1.0 if on else 0.0
		visible = on
		return
	visible = true
	_tw = create_tween()
	_tw.tween_property(self, "modulate:a", 1.0 if on else 0.0, FADE_S)
	if not on:
		_tw.tween_callback(func() -> void: visible = false)


## The rect it covers, global; empty while it is not up.
func rect() -> Rect2:
	return Rect2(position, size) if visible and modulate.a > 0.0 else Rect2()


## THE TAB THE STEP NAMES, OUTLINED: a 1 px line round it in the step's own
## colour. The tab is a real button and this only says which one; it adds no
## hover and takes no click.
func _draw() -> void:
	if cue == &"" or Router.hud == null:
		return
	var t: Rect2 = Router.hud.tab_rect(cue)
	if t.size == Vector2.ZERO:
		return
	var r := Rect2(t.position - position, t.size).grow(1.0)
	draw_rect(r, UITheme.ICE, false, 1.0)
