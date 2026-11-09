class_name GoalLine
extends Control

## The goal always shows, with the next tutorial step while one is pending, under the HUD.
## It is not a Control: it ignores the mouse and hides over moves and popups.
## Why: docs/why/GoalLine.md#goal-line

const GOAL := "GOAL: REACH THE CORE"
## Every step's line as shown (`step`), for the room the step keeps (`stack_rect`).
const STEP_TEXTS: Array[String] = ["Open STARCHART. Pick a star in range, then JUMP.",
	"Pick a star in range, then JUMP.", "Open SECTOR. Click an event, then GO.", "Click an event, then GO."]
## Placed from the screens' corner (Jon, Oct 20): below the top plate, 4 px into the picture.
const AT := Vector2(16.0, 47.0)
## ITS PLACE ON LOCAL (Jon, Oct 20, "snug:B"): snug under the HUD, 4 px into the
## screens' area as it is 4 px into the map's picture, at the same left.
const AT_LOCAL := Vector2(16.0, 4.0)
## Between the goal's line and the step's, px.
const GAP := 1.0
## One line's height with its backing, px (where it cannot be measured).
const LINE_H := 13.0
## The backing's padding round the goal's words, px (`_backed`).
const PAD_H := 5.0
const PAD_V := 1.0
## Silkscreen at 8 px: its capitals' height, and the blank column every glyph
## carries on its right (its advance runs 1 px past its ink), px.
const CAP_H := 5.0
const INK_TAIL := 1.0
## Blank columns between the goal's last letter and the badge (Jon, Nov 4).
const BADGE_GAP := 6.0
## THE STEP'S LINE COMING BACK after she has said it: how long, s, and the
## settle up into its place, px.
const APPEAR_S := 0.45
const APPEAR_DY := 3.0
## The fade in and out, s (none under reduced motion or headless).
const FADE_S := 0.2

var _panel: PanelContainer
var _step_panel: PanelContainer
var _goal: Label
var _step: Label
## the Custodian's badge, on the goal's line
var _badge: CustodianBadge
## The HUD tab the step names (&"chart" / &"sector"), or &"".
var cue: StringName = &""
var _want := false
var _tw: Tween = null
var _backed: StyleBoxFlat
## WHERE IT STANDS between LOCAL's place (0) and the place below the map's and
## the chart's top plate (1); -1 before it has been placed.
var drop := -1.0
## the step's line held back while she says it (`_step_held`), and when it
## started coming back (GameClock s; -1 not coming back)
var step_held := false
var _appear_t0 := -1.0


func _init() -> void:
	name = "GoalLine"
	top_level = true
	# (after the ladder has moved the top plate this frame, so the two move on
	# the same frame, never a frame apart)
	process_priority = 100
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	visible = false
	modulate.a = 0.0
	_panel = PanelContainer.new()
	# The goal sits on the step's dim backing (Jon, Oct 20), as it stands over the picture.
	_backed = UITheme.flat(Color(UITheme.VOID, 0.72), Color(0, 0, 0, 0), 0, int(PAD_V), int(PAD_H))
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
	# THE CUSTODIAN'S BADGE, after the goal's words (placed in `refresh`; after
	# the step's panel, so the goal's and the step's labels stay the first two)
	_badge = CustodianBadge.new()
	add_child(_badge)


## Marks a step done the first time it sees it; `id` is the line A.S.H. says.
static func step() -> Dictionary:
	if Run.hull == null or not Hints.enabled():
		return {}
	var cur := Router.current
	# Not in a fight: the named tabs are locked there, so a step could not be done.
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
	# SAID ONCE, NOT TWICE: held back while she has it to say or says it, and
	# coming back slowly once she is done
	var held := _step.visible and _step_held()
	if step_held and not held and _step.visible:
		_appear_t0 = GameClock.now() if Router.animating() else -1.0
	step_held = held
	_step_panel.visible = _step.visible and not held
	cue = StringName(st.get("tab", &""))
	drop = drop_now(cur, drop)
	if want:
		var sz := _panel.get_combined_minimum_size()
		_panel.size = sz
		# the line's room takes the badge in, at its widest (S0's), so nothing
		# that keeps off the goal moves as the jumps go by
		if CustodianBadge.enabled():
			var at := badge_at()
			_badge.position = at
			# (the backing runs on behind the badge, its eye and its count, to the line's
			# room: over a galaxy's gold close in, a giant elliptical at zoom 2, its blue
			# count could not be read, Nov 5)
			_panel.size.x = maxf(_panel.size.x, minf(at.x + float(_badge.drawn_w()) + PAD_H, at.x + CustodianBadge.MAX_W))
			sz =Vector2(maxf(sz.x, at.x + CustodianBadge.MAX_W), maxf(sz.y, at.y + CustodianBadge.BOX_H))
		size = sz
		position = fixed_at()
		if _step.visible:
			var ssz := _step_panel.get_combined_minimum_size()
			_step_panel.size = ssz
			_step_panel.position = step_at(cur) - position + Vector2(0.0, _appear())
	_fade(want)
	# The badge plays its arrival once the line is fully up, from the last count shown.
	# A departure skipped on its first frame would commit the jump mid fade.
	# Why: docs/why/GoalLine.md#custodian-badge
	var seen := Run.custodian_seen
	var g := CustodianBadge.count()
	var pending := CustodianBadge.enabled() and seen < g
	if pending and want and visible and modulate.a >= 0.99:
		_badge.arrive(g, seen)
		Run.custodian_seen = g
		pending = false
	_badge.refresh(visible and (want or modulate.a > 0.0), pending, seen)
	queue_redraw()


## Badge sits BADGE_GAP columns after the goal's last ink column, on the capitals' middle.
static func badge_at() -> Vector2:
	var font := UITheme.pixel_font()
	var adv := font.get_string_size(GOAL, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x
	var cap_top := PAD_V + ceilf(font.get_ascent(UITheme.FS_SMALL)) - CAP_H
	return Vector2(roundf(PAD_H + adv - INK_TAIL + BADGE_GAP), roundf(cap_top + floorf(CAP_H / 2.0) - 7.0))


## The badge (tests and the tooltip read it).
func badge() -> CustodianBadge:
	return _badge


## A.S.H. has the step on the goal line to say, or is saying it (`Hints`): its
## line waits for her.
static func _step_held() -> bool:
	if not Hints.enabled() or not Hints.by_ash():
		return false
	if Hints.step_up != &"" and Ash.lesson_up() and Ash.lesson == Hints.step_up:
		return true
	return Hints._step_now() != &""


## The step's line coming back: its alpha set here, and how far under its place
## it stands this frame (whole px).
func _appear() -> float:
	if _appear_t0 < 0.0:
		_step_panel.modulate.a = 1.0
		return 0.0
	var u := clampf((GameClock.now() - _appear_t0) / APPEAR_S, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - u, 3.0)
	_step_panel.modulate.a = e
	if u >= 1.0:
		_appear_t0 = -1.0
	return roundf(APPEAR_DY * (1.0 - e))


## Where the goal stands: LOCAL's place, the map's place, or between them with the plate.
static func fixed_at() -> Vector2:
	var g: GoalLine = Router.hud.goal if Router.hud != null and is_instance_valid(Router.hud) else null
	return place_at(drop_now(Router.current, g.drop if g != null and is_instance_valid(g) else -1.0))


## The place at `k` (0 LOCAL's, 1 below the plate), global, whole pixels.
static func place_at(k: float) -> Vector2:
	var c := Router.content.get_global_rect() if Router.content != null else Rect2(8, 42, 944, 491)
	return (c.position + AT_LOCAL.lerp(AT, clampf(k, 0.0, 1.0))).round()


## Its place at rest on `cur`: below the plate on the map and the chart, LOCAL's
## anywhere else it shows (LOCAL, a fight).
static func rest_drop(cur: Control) -> float:
	return 1.0 if cur is SystemMapScreen or cur is StarchartScreen else 0.0


## A calm move between LOCAL and the map or the chart under way: the one kind
## of move the goal travels on.
static func _plate_moving() -> bool:
	if not ZoomLadder.busy() or not bool(ZoomLadder.active.get("_calm")):
		return false
	var zl := ZoomLadder.active
	return zl.r_old == ZoomLadder.LOCAL or zl.r_new == ZoomLadder.LOCAL


## The top plate's own slide, if it is moving: its `PanelSlide` (1 in place).
static func plate_slide() -> PanelSlide:
	for p: Variant in PanelSlide.live:
		if is_instance_valid(p) and not (p as PanelSlide).done and (p as PanelSlide).kind == &"band":
			return p as PanelSlide
	return null


## Per frame: with the plate while it slides, held while the camera moves, so it never jumps.
static func drop_now(cur: Control, was: float) -> float:
	if _plate_moving():
		var ps := plate_slide()
		if ps != null:
			return ps.k
		if was >= 0.0:
			return was
	return rest_drop(cur)


## Where the step's line goes (global): directly under the goal, on all three.
func step_at(_cur: Control = null) -> Vector2:
	return fixed_at() + Vector2(0, _line_h() + GAP)


## The goal's line as the step's line under it keeps off it: the goal's words,
## and the badge on them, which is 2 px taller (`CustodianBadge.BOX_H`).
static func _line_h() -> float:
	var h := _goal_h()
	if CustodianBadge.enabled():
		h = maxf(h, badge_at().y + CustodianBadge.BOX_H)
	return h


## One line of words on its backing (the goal's, and the step's).
static func _goal_h() -> float:
	var g: GoalLine = Router.hud.goal if Router.hud != null and is_instance_valid(Router.hud) else null
	if g != null and is_instance_valid(g) and g._panel.size.y > 0.0:
		return g._panel.size.y
	return LINE_H


## Room is kept whether or not a step is pending, so a step arriving never lands on A.S.H.
static func stack_rect(cur: Control) -> Rect2:
	if cur == null or not is_instance_valid(cur) or not (cur is SectorScreen or cur is SystemMapScreen or cur is StarchartScreen):
		return Rect2()
	var font := UITheme.pixel_font()
	var w := font.get_string_size(GOAL, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x
	# the badge on the goal's line, at its widest (S0's box)
	var bw := badge_at().x + CustodianBadge.MAX_W if CustodianBadge.enabled() else 0.0
	# (in a fight there is no step: the goal's line alone, `step`; A.S.H.
	# stands after it, so after the badge)
	if _fighting(cur):
		return Rect2(fixed_at(), Vector2(maxf(ceilf(w) + 10.0, bw), _line_h()))
	for t: String in STEP_TEXTS:
		w = maxf(w, font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x)
	# (the backing's 5 px each side)
	return Rect2(fixed_at(), Vector2(maxf(ceilf(w) + 10.0, bw), _line_h() + GAP + _goal_h()))


static func _fighting(cur: Control) -> bool:
	var sc := cur as SectorScreen
	return sc != null and is_instance_valid(sc) and sc.fighting()


## The step's line as drawn (global), or empty.
func step_rect() -> Rect2:
	return Rect2(position + _step_panel.position, _step_panel.size) if visible and _step_panel.visible else Rect2()


## The step's line is coming back (fading in) this frame.
func step_appearing() -> bool:
	return _appear_t0 >= 0.0


## Static, so `Hints.step_due` can ask before the line's own `_process` has come up.
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


## A 1 px outline in the step's colour; the tab is a real button, so no hover or click here.
func _draw() -> void:
	if cue == &"" or Router.hud == null:
		return
	var t: Rect2 = Router.hud.tab_rect(cue)
	if t.size == Vector2.ZERO:
		return
	var r := Rect2(t.position - position, t.size).grow(1.0)
	draw_rect(r, UITheme.ICE, false, 1.0)
