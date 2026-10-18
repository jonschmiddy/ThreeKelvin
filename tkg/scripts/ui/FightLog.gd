class_name FightLog
extends Control

## THE FIGHT LOG, HIDDEN UNTIL YOU ASK FOR IT (Jon, Oct 18, "fightlog:hidden":
## "Hidden. Open it with a button if you want it."). The running list of what
## happened each turn of a fight -- your shots, their moves, heat, hull -- under a
## TURN line per turn. It went from the screen with the side rail ("every line
## was a transcript of an animation you had just watched"), and the lines never
## stopped being written (`Combat._log`, `Sig.log_line`); this brings them back
## for whoever wants the transcript, and nobody else.
##
## LOG, a small button at the right end of the band under the HUD, shows and
## hides it. The choice is kept (`[fight] log_open` in the settings file, the
## harness's own under a harness), so a player who wants it open has it open in
## every fight after. Off on a fresh profile.
##
## IT RECORDS WHILE HIDDEN. The recorder (`lines`) listens from the first fight
## of the session whether or not anything shows it, so opening the log mid-fight
## shows the whole fight so far.
##
## NOTHING MOVES FOR IT. Both are drawn over the screen, placed in game px, and
## nothing in the hand or the picture is laid out round them: the button stands
## where nothing else does (the band under the HUD is the goal line's, at its
## left end, and A.S.H. never stands in it), and the open log stands in the top
## left corner of the picture, under that band and above your ship, cut short of
## your hull, its shield and every enemy. A.S.H., the goal line and the hint
## cards keep off both (`rects`). The open log is a readout, not a control: no
## edge, a dim backing like the goal line's, and the mouse goes through it.
## `-- sheet=FightLogTest` holds all of it.

const SECTION := "fight"
const KEY := "log_open"
## Off the picture's right edge, px, and the band's height (`Ash.GOAL_BAND`).
const EDGE := 6.0
## The open log's widest, and its tallest and shortest, px.
const LOG_W := 300.0
const LOG_MAX_H := 96.0
const LOG_MIN_H := 30.0
## Its clearance from your ship, its shield and the enemies, px.
const CLEAR := 4.0
## Room over your hull for two of the numbers a hit on you pops, risen, px:
## the gap `HitText.above` leaves and `SectorScreen._pop_reach(2)`.
const OWN_POPS := HitText.GAP + HitText.LINE + HitText.CAP + 1.0 + HitText.RISE
## How long the button takes to come and go, s (none headless or reduced).
const FADE_S := 0.2
## The lines kept: a long fight is a few hundred, and the list only scrolls on.
const KEEP := 400

## Every line of the fight under way (or the last one): {text, kind}. A TURN
## line opens each turn (`kind` &"turn").
static var lines: Array = []
static var _rec: _Recorder = null
static var _open := false
static var _open_read := false


## Starts the recorder, once a session (idempotent).
static func hook() -> void:
	if _rec != null:
		return
	_rec = _Recorder.new()
	Sig.combat_started.connect(_rec.on_started)
	Sig.combat_ended.connect(_rec.on_ended)
	Sig.log_line.connect(_rec.on_line)


class _Recorder extends RefCounted:
	var live := false
	var turn := 0

	func on_started(_who: String) -> void:
		FightLog.lines.clear()
		live = true
		turn = 0

	func on_ended(_res: StringName, _text: String) -> void:
		live = false

	func on_line(text: String, kind: StringName) -> void:
		if not live:
			return
		# A TURN LINE when the turn moves on: read off the fight, because the
		# first lines of a turn (a charge going off) come before `turn_started`
		var c: Combat = Router.combat
		var t := c.turn if c != null else turn
		if t != turn:
			turn = t
			FightLog.lines.append({text = "TURN %d" % t, kind = &"turn"})
		FightLog.lines.append({text = text, kind = kind})
		if FightLog.lines.size() > FightLog.KEEP:
			FightLog.lines = FightLog.lines.slice(FightLog.lines.size() - FightLog.KEEP)


## Whether the player has the log open (read once from the settings file).
static func is_open() -> bool:
	if not _open_read:
		_open_read = true
		var cfg := ConfigFile.new()
		if cfg.load(DisplaySettings.path) == OK:
			_open = bool(cfg.get_value(SECTION, KEY, false))
	return _open


static func set_open(v: bool) -> void:
	_open = v
	_open_read = true
	var cfg := ConfigFile.new()
	cfg.load(DisplaySettings.path)
	cfg.set_value(SECTION, KEY, v)
	cfg.save(DisplaySettings.path)


## For a harness: forget what was read, so the next ask reads the file again.
static func reread() -> void:
	_open_read = false


## Everything of the log's on `cur` that others keep off, global: the button
## while it shows, and the log while it is open.
static func rects(cur: Control) -> Array:
	var out: Array = []
	var sc := cur as SectorScreen
	if sc == null or sc._fight_log == null or not is_instance_valid(sc._fight_log):
		return out
	var f := sc._fight_log
	if f.button.is_visible_in_tree():
		out.append(f.button.get_global_rect())
	if f.panel.is_visible_in_tree():
		out.append(f.panel.get_global_rect())
	return out


var screen: SectorScreen
var button: Button
var panel: PanelContainer
var _text: RichTextLabel
var _shown := -1
var _shown_first: Dictionary = {}
var _alpha := 0.0
## The log's box, worked out when it opens (and when the picture changes size):
## the ship's bob would otherwise move its bottom a pixel every few frames.
var _box := Rect2()
var _box_for := Rect2()


func _init(s: SectorScreen) -> void:
	screen = s
	name = "FightLog"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	FightLog.hook()

	button = Widgets.button("LOG", _toggle)
	button.name = "FightLogButton"
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", UITheme.FS_SMALL)
	button.custom_minimum_size = Vector2(32, 16)
	button.tooltip_text = Widgets.tip("LOG\n\nWhat happened each turn of this fight. Click to show or hide it.")
	# FLAT, LIKE FLEE AND HAIL ON THE HAND'S RAIL: an edge, no fill until it is
	# pointed at, and filled while the log is open
	var edge := Color("#4a5f78")
	button.add_theme_color_override("font_color", UITheme.CHILL)
	button.add_theme_color_override("font_hover_color", UITheme.ICE)
	button.add_theme_color_override("font_pressed_color", UITheme.ICE)
	button.add_theme_color_override("font_hover_pressed_color", UITheme.ICE)
	button.add_theme_stylebox_override("normal", UITheme.flat(Color(UITheme.VOID, 0.72), edge, 0, 0, 6))
	button.add_theme_stylebox_override("hover", UITheme.flat(Color("#1d2836"), UITheme.ICE, 0, 0, 6))
	button.add_theme_stylebox_override("pressed", UITheme.flat(Color("#243044"), UITheme.ICE, 0, 0, 6))
	button.add_theme_stylebox_override("hover_pressed", UITheme.flat(Color("#2b3a52"), UITheme.ICE, 0, 0, 6))
	button.add_theme_stylebox_override("disabled", UITheme.flat(Color(0, 0, 0, 0), Color("#3a3a3a"), 0, 0, 6))
	button.visible = false
	add_child(button)

	panel = PanelContainer.new()
	panel.name = "FightLogPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# NOT A CONTROL, AND DOES NOT LOOK LIKE ONE: the goal line's dim backing
	# and no edge (an edged box is what this game's controls look like)
	panel.add_theme_stylebox_override("panel", UITheme.flat(Color(UITheme.VOID, 0.78), Color(0, 0, 0, 0), 0, 3, 5))
	panel.visible = false
	add_child(panel)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.scroll_following = true
	_text.scroll_active = false
	_text.fit_content = false
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_font_override("normal_font", UITheme.pixel_font())
	_text.add_theme_font_size_override("normal_font_size", UITheme.FS_SMALL)
	_text.add_theme_constant_override("line_separation", 1)
	panel.add_child(_text)


func _toggle() -> void:
	FightLog.set_open(button.button_pressed)
	_box_for = Rect2()
	_place()


## Whether the button belongs on screen: a fight up, its hand settled, not ended.
func wanted() -> bool:
	var sc := screen
	if sc == null or not is_instance_valid(sc) or not sc.is_visible_in_tree():
		return false
	if not sc.fighting() or sc.combat.finished:
		return false
	if sc._raising or sc._lowered or sc._hand_holder == null or not sc._hand_holder.is_visible_in_tree():
		return false
	return true


func _process(delta: float) -> void:
	var want := wanted()
	var instant := not Router.animating() or DisplaySettings.reduced_motion
	if instant:
		_alpha = 1.0 if want else 0.0
	else:
		_alpha = move_toward(_alpha, 1.0 if want else 0.0, delta / FADE_S)
	button.visible = _alpha > 0.0
	button.modulate.a = _alpha
	# (a click only once it is all the way in, as the hand's own buttons)
	button.mouse_filter = Control.MOUSE_FILTER_STOP if _alpha >= 1.0 else Control.MOUSE_FILTER_IGNORE
	if button.button_pressed != FightLog.is_open():
		button.set_pressed_no_signal(FightLog.is_open())
	panel.visible = button.visible and FightLog.is_open()
	panel.modulate.a = _alpha
	if button.visible:
		_place()
	if panel.visible:
		_fill()


## The button at the right end of the band under the HUD; the log in the
## picture's top left corner, under the band, cut short of what it must not cover.
func _place() -> void:
	var sc := screen
	if sc._view == null or Router.hud == null or not is_instance_valid(Router.hud):
		return
	var v := sc._view.get_global_rect()
	var hud := Router.hud.get_global_rect()
	var bs := button.get_combined_minimum_size()
	var right := minf(v.end.x, hud.end.x)
	button.size = bs
	button.global_position = Vector2(roundf(right - EDGE - bs.x), roundf(hud.end.y + (Ash.GOAL_BAND - bs.y) * 0.5))
	if not FightLog.is_open():
		return
	if _box_for != v or _box.size == Vector2.ZERO:
		_box_for = v
		_box = _log_box(v, hud)
	panel.global_position = _box.position
	panel.size = _box.size
	_text.custom_minimum_size = Vector2(_box.size.x - 10.0, 0.0)


func _log_box(v: Rect2, hud: Rect2) -> Rect2:
	var x0 := roundf(maxf(v.position.x, hud.position.x) + EDGE)
	var y0 := roundf(hud.end.y + Ash.GOAL_BAND + 2.0)
	var bottom := y0 + LOG_MAX_H
	# ABOVE YOUR SHIP, its shield and two of the numbers a hit on you pops (a
	# third and on are kept under the log: `SectorScreen._pop_limit`)
	var ship := sc_ship_rect()
	if ship.size != Vector2.ZERO:
		bottom = minf(bottom, ship.position.y - OWN_POPS - CLEAR)
	var L: HitLayers = screen._ship_fx
	if L != null and is_instance_valid(L) and L.shield != null:
		var sh := L.shield
		var rad := Vector2(sh._rx, sh._ry)
		var oval := sh.get_global_transform() * Rect2(sh._origin + sh._cc - rad, rad * 2.0)
		if oval.size.y > 1.0:
			bottom = minf(bottom, oval.position.y - CLEAR)
	var r := Rect2(x0, y0, LOG_W, maxf(LOG_MIN_H, floorf(bottom - y0)))
	# NARROWER against every enemy that reaches into its rows: its ship, its
	# words and bars, and the room the numbers your cards land on it pop into
	var view := screen._view
	for i in 16:
		var sl := view.slot(i)
		if sl == null or not is_instance_valid(sl) or not sl.is_visible_in_tree():
			continue
		var ink := sl.get_global_transform() * sl.ink_rect()
		var parts: Array[Rect2] = [ink, sl.intent_rect_global(), sl.readout_rect_global()]
		var words := sl.intent_rect_global()
		var top := minf(ink.position.y, words.position.y) if words.size.y > 0.0 else ink.position.y
		var reach := 2.0 * HitText.LINE + HitText.CAP + 1.0 + HitText.RISE + 4.0
		var wide := HitText.ink_width("BLOCKED 99") + 8.0
		parts.append(Rect2(ink.get_center().x - wide * 0.5, top - reach, wide, reach))
		for k: Rect2 in parts:
			var g := k.grow(CLEAR)
			if k.size != Vector2.ZERO and r.intersects(g) and g.position.x > r.position.x:
				r.size.x = g.position.x - r.position.x
	r.size = r.size.floor()
	return r


func sc_ship_rect() -> Rect2:
	var art := screen._view.ship_view() if screen._view != null else null
	if art == null or not art.is_visible_in_tree():
		return Rect2()
	return art.get_global_transform() * art.ship_rect()


## The lines into the log, when there are new ones.
func _fill() -> void:
	var first: Dictionary = FightLog.lines[0] if not FightLog.lines.is_empty() else {}
	if FightLog.lines.size() == _shown and first == _shown_first:
		return
	_shown = FightLog.lines.size()
	_shown_first = first
	var out := PackedStringArray()
	for l: Dictionary in FightLog.lines:
		var k: StringName = l.kind
		var c := UITheme.COLD if k == &"turn" else UITheme.log_colour(k)
		out.append("[color=#%s]%s[/color]" % [c.to_html(false), String(l.text).replace("[", "[lb]")])
	_text.text = "\n".join(out)


## The log's text as shown, for a harness.
func shown_text() -> String:
	return _text.get_parsed_text()
