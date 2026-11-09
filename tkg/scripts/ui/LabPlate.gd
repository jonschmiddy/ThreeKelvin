class_name LabPlate
extends Button

## A KEY ON THE LAB'S SCREEN (science S9, Jon's 1C): the four the zoomed-in Lab presses ...
## Why: docs/why/LabPlate.md#a-key-on-the-labs-screen

const BG := Color("#0a0e15")
const EMBER := Color("#d97b29")
const HOT := Color("#ffd28a")
const NEXT_D := Color("#4a2a0c")

var kind: StringName = &"plate"
## The word on the key.
var label := ""
## A tab: whether it is the page on show.
var on := false
## A tab's rule when it is not on: the glass's own ink (the lab's tint).
var rule := Color("#22303f")
## F8 or F16 Silkscreen, in game px.
var font_size := 8


func _init(word: String = "", k: StringName = &"plate") -> void:
	label = word
	kind = k
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for st in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(st, StyleBoxEmpty.new())
	# the game's button sounds (`Widgets._btn`): a click, a hover, and the
	# dead thud of a key that cannot be pressed
	pressed.connect(Audio.click)
	mouse_entered.connect(Audio.hover)
	gui_input.connect(func(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and disabled:
			Audio.denied())


## How wide the mockup makes it for its word: a tab's word and 12, LEAVE's 18.
static func width_for(word: String, k: StringName, pad: int = 18) -> int:
	return LabBoard.tw(word, 8) + (12 if k == &"tab" else pad)


func _draw() -> void:
	var w := int(size.x)
	var h := int(size.y)
	var hover := is_hovered() and not disabled
	var font := UITheme.pixel_font()
	var cap := 5 if font_size == 8 else 10
	var col: Color
	if kind == &"tab":
		if on:
			draw_rect(Rect2(0, 0, w, 15), Color("#2a1c0c"))
			draw_rect(Rect2(0, 15, w, 1), EMBER)
			col = HOT
		else:
			draw_rect(Rect2(0, 15, w, 1), rule.lerp(EMBER, 0.5) if hover else rule)
			col = UITheme.ICE if hover else UITheme.CHILL
		draw_string(font, Vector2(6, 5 + cap), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)
		return
	var bg := Color("#161f2c")
	var hi := Color("#3d4d61")
	var lo := Color("#080b11")
	if kind == &"commit":
		bg = NEXT_D
		hi = EMBER
		col = HOT
		if hover:
			bg = NEXT_D.lerp(EMBER, 0.25)
	else:
		col = UITheme.LEAVE if kind == &"leave" else UITheme.ICE
		if hover:
			bg = bg.lerp(hi, 0.35)
	if disabled:
		# A KEY THAT CANNOT BE PRESSED LOOKS IT: no bevel, no ember, grey words.
		bg = Color("#0d131c")
		hi = Color("#1a2330")
		lo = hi
		col = UITheme.QUOTE
	draw_rect(Rect2(0, 0, w, h), bg)
	draw_rect(Rect2(0, 0, w - 1, 1), hi)
	draw_rect(Rect2(0, 0, 1, h - 1), hi)
	draw_rect(Rect2(1, h - 1, w - 1, 1), lo)
	draw_rect(Rect2(w - 1, 1, 1, h - 1), lo)
	var tx := floori((w - LabBoard.tw(label, font_size)) / 2.0)
	var ty := floori((h - cap) / 2.0)
	draw_string(font, Vector2(tx, ty + cap), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)
