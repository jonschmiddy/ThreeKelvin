class_name DrawerPlate
extends Button
## The drawers' buttons: the escape menu's and Settings'. A chamfered plate,
## drawn rather than composed from styleboxes, because a chamfer, a pixel icon
## and text that all change colour together on hover are one drawing, not four
## nodes to keep in step.
##
## Two shapes. A PLATE is a menu line -- a doubled-pixel icon, a label, and a
## second line saying what the choice does (Jon's pick: chamfered + two lines).
## A CHIP is one choice among several, one line, centred; the one in force is
## edged in ember like RESUME, so "what is set" reads the same as "where Esc
## goes".

const PLATE_H := 40.0
## A plate with nothing to explain is shorter: one line, centred.
const LINE_H := 28.0
## Between a plate's two lines.
const LINE_GAP := 5.0
const CHIP_H := 18.0
const CUT := 6.0
const CHIP_CUT := 3.0

## 7x7, every pixel drawn 2x2. Jon kept the sliders and the floppy and picked
## the others from six each; the arrow is the narrow one made one pixel wider
## on every row, which keeps its edge an even staircase. BACK is that arrow
## turned round.
const ICONS := {
	&"resume": ["##.....", "###....", "####...", "#####..", "####...", "###....", "##....."],
	&"back": [".....##", "....###", "...####", "..#####", "...####", "....###", ".....##"],
	&"settings": [".#.....", "#######", ".#.....", ".......", "....#..", "#######", "....#.."],
	&"save": ["######.", "#.##.##", "#.##..#", "#.....#", "#.###.#", "#.###.#", "#######"],
	&"abandon": ["...#...", ".#.#.#.", "#..#..#", "#.....#", "#.....#", ".#...#.", "..###.."],
	# Section marks in Settings, drawn the same way.
	&"display": ["#######", "#.....#", "#.....#", "#.....#", "#######", "...#...", ".#####."],
	&"audio": ["..#..#.", ".##...#", "###.#.#", "###.#.#", "###.#.#", ".##...#", "..#..#."],
	# Look: the contrast circle, half struck. The eye it replaced read as a
	# target at 7 pixels, and the monitor belongs to DISPLAY.
	&"look": ["..###..", ".####.#", "#####..", "#####.#", "#####..", ".####.#", "..###.."],
	# Motion: a thing and the ghosts of where it was.
	&"motion": ["#.#.###", "#.#.###", "#.#.###", ".......", "#.#.###", "#.#.###", "#.#.###"],
}

## One icon at `at`, every pixel 2x2, for anything that wants the set's marks.
static func draw_icon(ci: CanvasItem, id: StringName, at: Vector2, ink: Color) -> void:
	var rows: Array = ICONS.get(id, [])
	for y in rows.size():
		var r: String = rows[y]
		for x in r.length():
			if r[x] == "#":
				ci.draw_rect(Rect2(at + Vector2(x * 2, y * 2), Vector2(2, 2)), ink)

var icon_id: StringName
var title := ""
var sub := ""
var chip := false
## Edged in ember: the setting in force, on a chip.
var lead := false
## What the button is FOR, said in colour -- and only under the cursor. Jon:
## every plate is grey at rest, and lights when you point at it, so the drawer
## reads as one grey column until you choose something. GOOD is going on
## (RESUME, SAVE), BAD is ending the run, NONE is everything else.
enum Tone {NONE, GOOD, BAD}
var tone: Tone = Tone.NONE

static func plate(id: StringName, t: String, s: String, action: Callable) -> DrawerPlate:
	var p := _base(action)
	p.icon_id = id
	p.title = t
	p.sub = s
	p.custom_minimum_size = Vector2(0, PLATE_H if s != "" else LINE_H)
	return p

## `picked` chips are the setting in force: lit, and not clickable, because
## choosing what is already chosen does nothing and should not sound as if it did.
static func chip_for(t: String, picked: bool, action: Callable) -> DrawerPlate:
	var p := _base(action)
	p.chip = true
	p.title = t
	p.lead = picked
	p.disabled = picked
	p.custom_minimum_size = Vector2(0, CHIP_H)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return p

static func _base(action: Callable) -> DrawerPlate:
	var p := DrawerPlate.new()
	p.focus_mode = Control.FOCUS_NONE
	p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		p.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	# The same sounds every button in the game makes (Widgets._btn).
	p.pressed.connect(Audio.click)
	p.mouse_entered.connect(func() -> void:
		if not p.disabled:
			Audio.hover())
	p.pressed.connect(action)
	p.mouse_entered.connect(p.queue_redraw)
	p.mouse_exited.connect(p.queue_redraw)
	return p

func _draw() -> void:
	var hot := is_hovered() and not disabled
	var edge := UITheme.LINE
	var fill := UITheme.PANEL
	var ink := UITheme.COLD
	var text := UITheme.CHILL
	if lead:
		edge = UITheme.EMBER
		fill = Color("#1f1a14")
		ink = UITheme.FLARE
		text = UITheme.ICE
	if hot:
		match tone:
			Tone.GOOD:
				edge = UITheme.GOOD
				fill = Color("#141f1a")
				ink = UITheme.GOOD
				text = Color("#a9d8c2")
			Tone.BAD:
				edge = UITheme.BAD
				fill = Color("#201513")
				ink = UITheme.BAD
				text = Color("#e08a76")
			_:
				edge = UITheme.CHILL
				fill = Color("#16202c")
				ink = UITheme.CHILL
				text = UITheme.ICE
	var w := size.x
	var h := size.y
	var cut := CHIP_CUT if chip else CUT
	draw_colored_polygon(PackedVector2Array([Vector2(cut, 0), Vector2(w, 0),
		Vector2(w, h - cut), Vector2(w - cut, h), Vector2(0, h), Vector2(0, cut)]), edge)
	var c := cut - 1.0
	draw_colored_polygon(PackedVector2Array([Vector2(1 + c, 1), Vector2(w - 1, 1),
		Vector2(w - 1, h - 1 - c), Vector2(w - 1 - c, h - 1), Vector2(1, h - 1), Vector2(1, 1 + c)]), fill)
	var font := get_theme_font("font", "Label")
	var fs := UITheme.FS_SMALL
	if chip:
		# CENTRED ON THE FONT'S OWN METRICS, both ways. Centring on the point
		# size instead puts the text a pixel or two high, which is what a chip
		# full of two-character labels shows up immediately.
		var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var base := (h + font.get_ascent(fs) - font.get_descent(fs)) * 0.5
		draw_string(font, Vector2(floorf((w - tw) * 0.5), floorf(base)),
			title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text)
		return
	draw_icon(self, icon_id, Vector2(12, floorf((h - 14.0) * 0.5)), ink)
	if sub == "":
		var base := (h + font.get_ascent(fs) - font.get_descent(fs)) * 0.5
		draw_string(font, Vector2(36, floorf(base)), title,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text)
		return
	# CENTRED AS A BLOCK, off the font's own metrics rather than two guessed
	# baselines: the pair sat a pixel or two high in the plate.
	var lh := font.get_ascent(fs) + font.get_descent(fs)
	var top := floorf((h - (lh * 2.0 + LINE_GAP)) * 0.5)
	draw_string(font, Vector2(36, top + font.get_ascent(fs)), title,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text)
	draw_string(font, Vector2(36, top + lh + LINE_GAP + font.get_ascent(fs)), sub,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITheme.COLD)
