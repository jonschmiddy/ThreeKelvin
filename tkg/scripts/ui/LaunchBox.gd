class_name LaunchBox
extends Control

## LAUNCH A RUN's lower half (Jon's v3, Nov 10, "T1: GOOD!"): the tier stops,
## the tier's galaxy and its lines, then LAUNCH, NOT YET and the seed on one
## row, on three columns. The title owns the buttons and the seed field.
## Why: docs/why/Ladder.md#the-box

signal tier_changed(tier: int)

const W := 363
const COL_C := TierGalaxy.G + 14
const STEP := 22
const STOP_W := 17
const STOP_H := 14
const GY := 22
## The bottom row's box height: a LineEdit's smallest at the pixel font, and the buttons made to match.
const ROW_H := 19
const PANEL := Color8(17, 24, 35)
const PANEL2 := Color8(22, 31, 44)
const LINE := Color8(34, 48, 63)
const DIM_LINE := Color8(26, 36, 48)
const COLD := Color8(107, 125, 148)
const CHILL := Color8(143, 163, 186)
const ICE := Color8(195, 210, 226)
## The rule wraps at this many characters, three lines at most.
const WRAP := 38

## Remembered across opens of the box, as the seed field is not.
static var last_tier: int = 0

var tier: int = 0
var galaxy: TierGalaxy
var stops: Array[Stop] = []
var _lines: Control
var _font: Font


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = UITheme.pixel_font()


## `launch` and `not_yet` are the title's buttons, `seed_row` its SEED label and field.
func setup(launch: Button, not_yet: Button, seed_row: HBoxContainer) -> void:
	tier = last_tier
	while tier > 0 and not Ladder.can_pick(tier):
		tier -= 1
	var lab := UITheme.body("TIER", COLD, UITheme.FS_SMALL)
	lab.position = Vector2(0, 2)
	lab.mouse_filter = Control.MOUSE_FILTER_STOP
	lab.tooltip_text = Widgets.tip("Tiers\nEach tier adds one rule to the galaxy. Winning a run opens the next tier.")
	add_child(lab)
	for k in Ladder.count():
		var s := Stop.new()
		s.box = self
		s.tier = k
		s.position = Vector2(COL_C + k * STEP, 0)
		s.size = Vector2(STOP_W + 1, STOP_H + 1)
		stops.append(s)
		add_child(s)
	galaxy = TierGalaxy.new()
	galaxy.position = Vector2(0, GY)
	add_child(galaxy)
	_lines = Control.new()
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lines.position = Vector2(COL_C, GY)
	add_child(_lines)
	# the bottom row: the buttons on L, SEED on C, the field to R, one height, one ink row
	var by := GY + TierGalaxy.G + 12
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.position = Vector2(0, by)
	for b: Button in [launch, not_yet]:
		b.custom_minimum_size.y = ROW_H
		row.add_child(b)
	add_child(row)
	# the title's SEED label and field, taken out of their row: the label's ink
	# on the buttons' ink row at C, the field from C + 34 to R, the buttons' height
	var kids := seed_row.get_children()
	for c in kids:
		seed_row.remove_child(c)
		if c is LineEdit:
			var le := c as LineEdit
			le.custom_minimum_size = Vector2(0, ROW_H)
			le.position = Vector2(COL_C + 34, by)
			le.size = Vector2(W - COL_C - 34, ROW_H)
			# and again whenever its minimum moves: entering the tree, before the
			# theme's font reaches it, the field grows to the default font's height and stays
			var fit := func() -> void: le.size = Vector2(W - COL_C - 34, ROW_H)
			le.minimum_size_changed.connect(fit)
			le.ready.connect(func() -> void: fit.call_deferred())
		else:
			(c as Control).position = Vector2(COL_C, by + 4)
		add_child(c)
	seed_row.free()
	custom_minimum_size = Vector2(W, by + ROW_H)
	size = custom_minimum_size
	_show_tier()


func pick(t: int) -> void:
	if not Ladder.can_pick(t) or t == tier:
		return
	tier = t
	last_tier = t
	Audio.click()
	_show_tier()
	tier_changed.emit(t)


func _show_tier() -> void:
	galaxy.set_tier(tier)
	for s in stops:
		s.queue_redraw()
	Widgets.clear(_lines)
	var col := Ladder.colour(tier)
	var head := UITheme.body("TIER %d" % tier, col, UITheme.FS_HEAD)
	head.position = Vector2(0, 0)
	_lines.add_child(head)
	var sub := UITheme.body("%s · %s" % [Ladder.rung_name(tier), Ladder.form_name(tier)], col, UITheme.FS_SMALL)
	sub.position = Vector2(0, 26)
	_lines.add_child(sub)
	var lines := _wrap(Ladder.rule(tier).to_upper(), WRAP)
	for i in mini(3, lines.size()):
		var l := UITheme.body(lines[i], ICE, UITheme.FS_SMALL)
		l.position = Vector2(0, 44 + i * 12)
		_lines.add_child(l)


static func _wrap(s: String, width: int) -> Array[String]:
	var out: Array[String] = []
	var line := ""
	for word in s.split(" "):
		var next := word if line == "" else line + " " + word
		if next.length() > width and line != "":
			out.append(line)
			line = word
		else:
			line = next
	if line != "":
		out.append(line)
	return out


## One stop on the ladder: the current tier outlined in its kind colour, an
## open one plain, one past best + 1 dim and dead.
class Stop extends Control:
	var box: LaunchBox
	var tier: int = 0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func can() -> bool:
		return Ladder.can_pick(tier)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_ENTER:
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if can() else Control.CURSOR_ARROW
			tooltip_text = Widgets.tip("Tier %d: %s\n%s" % [tier, Ladder.rung_name(tier).capitalize(), Ladder.rule(tier)]) \
				if can() else Widgets.tip("Tier %d\nWin a run at tier %d to open it." % [tier, tier - 1])
			if can():
				Audio.hover()

	func _gui_input(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			if can():
				box.pick(tier)
			else:
				Audio.denied()

	func _draw() -> void:
		var r := Rect2(0, 0, STOP_W + 1, STOP_H + 1)
		var kind := Ladder.colour(tier)
		var ink: Color
		if tier == box.tier:
			draw_rect(r, PANEL2, true)
			draw_rect(r.grow(-0.5), kind, false, 1.0)
			ink = kind
		elif can():
			draw_rect(r, PANEL, true)
			draw_rect(r.grow(-0.5), LINE, false, 1.0)
			ink = kind if tier <= box.tier else CHILL
		else:
			draw_rect(r, PANEL, true)
			draw_rect(r.grow(-0.5), DIM_LINE, false, 1.0)
			ink = LINE
		var s := str(tier)
		var w := box._font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x
		draw_string(box._font, Vector2(floorf((STOP_W + 1 - w) / 2.0), 3.0 + box._font.get_ascent(UITheme.FS_SMALL)), s,
			HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL, ink)
