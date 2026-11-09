class_name NoteCard
extends Control

## The clean look was Jon's pick of three (Oct 13), matching the salvage popup's chamfered case.
## Why: docs/why/NoteCard.md#note-card

const WIDTH := 420
## What the panel leaves clear of the window's edges when it is tall.
const EDGE := 12
const FADE_S := 0.3
## The dim behind, as the title's own popups dim it (`LauncherScreen._open_popup`).
const DIM := Color(0.02, 0.03, 0.05, 0.80)

const HEART := preload("res://art/sprites/ui/note_heart.png")
const BTN := preload("res://art/sprites/ui/note_button.png")
const BTN_HOVER := preload("res://art/sprites/ui/note_button_hover.png")
const BTN_DOWN := preload("res://art/sprites/ui/note_button_down.png")

var panel: PanelContainer
## The note without its sign-off, and the whole note as written.
var body: Label
var full_text := ""
var signed := ""
var heart := false

var _col: VBoxContainer
var _scroll: ScrollContainer
## What the note's width is read from before `_fit` measures it: the body, or
## the list `set_note` put in its place.
var _measure: Control
var _foot: VBoxContainer
var _buttons: HBoxContainer


## `dim` scales the dim behind: 1 over the title (the note is all there is to
## read), less on the win screen, which keeps its sky.
func build(title: String, text: String, dim: float = 1.0) -> void:
	name = "NoteCard"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	full_text = text
	_split(text)

	# Dim the whole picture, not this card's rect: the title's galaxy showed through as a frame.
	var shade := ColorRect.new()
	Widgets.cover_picture(shade)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.color = Color(DIM, DIM.a * dim)
	add_child(shade)

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _case())
	centre.add_child(panel)
	_col = VBoxContainer.new()
	_col.add_theme_constant_override("separation", 12)
	_col.custom_minimum_size = Vector2(WIDTH, 0)
	panel.add_child(_col)

	_heading(title)

	# THE LETTER: the note, then its sign-off, in one scroll.
	var letter := VBoxContainer.new()
	letter.add_theme_constant_override("separation", 10)
	body = UITheme.body(text if signed == "" else text.substr(0, text.length() - _tail_len()),
		UITheme.CHILL, UITheme.FS_BODY)
	body.name = "NoteBody"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(WIDTH, 0)
	# Silkscreen is crisp only at 8 and 16, so spacing, not size, makes capitals readable.
	body.add_theme_constant_override("line_spacing", 4)
	letter.add_child(body)
	_measure = body
	if signed != "":
		letter.add_child(_sign_off())
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.add_child(letter)
	_col.add_child(_scroll)

	_foot = VBoxContainer.new()
	_foot.add_theme_constant_override("separation", 10)
	_col.add_child(_foot)
	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 8)
	_col.add_child(_buttons)

	# re-measured whenever the screen or the note's wrap changes
	resized.connect(_fit)
	body.resized.connect(_fit)


func _ready() -> void:
	_fit.call_deferred()
	# ARRIVES, gently: a fade, nothing that moves or bounces
	if Router.animating() and not DisplaySettings.reduced_motion:
		modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 1.0, FADE_S) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## A note that is not a letter: `c` takes the body's place in the same scroll and measure.
func set_note(c: Control) -> void:
	body.visible = false
	c.custom_minimum_size.x = WIDTH
	body.get_parent().add_child(c)
	_measure = c
	c.resized.connect(_fit)


## Something under the note -- the win screen's numbers -- behind a scanline.
func add_section(c: Control) -> void:
	var sc := TransferView.Scan.new()
	sc.custom_minimum_size = Vector2(0, 5)
	_foot.add_child(sc)
	_foot.add_child(_full_width(c))


func add_buttons(list: Array) -> void:
	for b in list:
		_buttons.add_child(b as Control)


## Something under the buttons: the win screen's "saved to" line.
func add_footer(c: Control) -> void:
	_col.add_child(_full_width(c))


## A wrapping label measured before it has a width is one letter wide, so `_fit` scrolled.
func _full_width(c: Control) -> Control:
	if c is Label and (c as Label).autowrap_mode != TextServer.AUTOWRAP_OFF:
		c.custom_minimum_size.x = WIDTH
	return c


## The primary button is an authored amber plate; every other button is the game's own.
static func primary(text: String, action: Callable) -> Button:
	var b := Widgets.button(text, action)
	b.add_theme_font_size_override("font_size", UITheme.FS_HEAD)
	for pair in [["normal", BTN], ["focus", BTN], ["hover", BTN_HOVER], ["pressed", BTN_DOWN]]:
		var sb := StyleBoxTexture.new()
		sb.texture = pair[1]
		sb.set_texture_margin_all(5)
		sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
		sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
		sb.content_margin_left = 16
		sb.content_margin_right = 16
		sb.content_margin_top = 7
		sb.content_margin_bottom = 6
		b.add_theme_stylebox_override(pair[0], sb)
	b.add_theme_color_override("font_color", UITheme.HOT)
	b.add_theme_color_override("font_focus_color", UITheme.HOT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", UITheme.HOT)
	return b


# --------------------------------------------------------------------- pieces

## "<3" then the name, the letter's last two paragraphs, set apart.
func _split(text: String) -> void:
	var paras := text.strip_edges().split("\n\n")
	if paras.size() >= 2 and paras[-1].strip_edges().length() <= 12:
		signed = paras[-1].strip_edges()
		heart = paras.size() >= 3 and paras[-2].strip_edges() == "<3"


## How many characters of the text the sign-off takes, with the gap before it.
func _tail_len() -> int:
	var tail := "\n\n" + signed
	if heart:
		tail = "\n\n<3" + tail
	return tail.length()


func _sign_off() -> Control:
	var row := HBoxContainer.new()
	row.name = "SignOff"
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 6)
	if heart:
		var h := TextureRect.new()
		h.name = "Heart"
		h.texture = HEART
		# doubled, on whole pixels: a 9x8 heart beside 16px type
		h.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		h.stretch_mode = TextureRect.STRETCH_SCALE
		h.custom_minimum_size = Vector2(HEART.get_width(), HEART.get_height()) * 2.0
		h.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(h)
	var n := UITheme.body(signed.to_upper(), UITheme.ICE, UITheme.FS_HEAD)
	n.name = "Signature"
	row.add_child(n)
	return row


## The salvage popup's readout heading: a hazard mark, the title, a scanline.
func _heading(title: String) -> void:
	var t := UITheme.body(title, UITheme.ICE, UITheme.FS_HEAD)
	t.name = "NoteTitle"
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var dot := TransferView.Stripe.new()
	dot.custom_minimum_size = Vector2(8, 8)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(dot)
	h.add_child(t)
	_col.add_child(h)
	var sc := TransferView.Scan.new()
	sc.custom_minimum_size = Vector2(0, 5)
	_col.add_child(sc)


## The salvage popup's chamfered case (`TransferView._cut_box`), with more room.
func _case() -> StyleBoxFlat:
	return UITheme.chamfer(UITheme.PANEL2, UITheme.LINE, 18, 24)


## Scroll only if the panel would not fit, and not before the note has its width.
func _fit() -> void:
	if _scroll == null or panel == null or not is_inside_tree() or size.y <= 0.0:
		return
	# (a scrolling note is narrower by its bar, and is measured anyway)
	if _measure.size.x < WIDTH - 1.0 and not note_scrolls():
		return
	var note := _scroll.get_child(0) as Control
	var want := note.get_combined_minimum_size().y
	var rest := panel.get_combined_minimum_size().y - _scroll.get_combined_minimum_size().y
	var room := size.y - 2.0 * EDGE - rest
	if want <= room:
		_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_scroll.custom_minimum_size.y = 0.0
	else:
		_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		_scroll.custom_minimum_size.y = maxf(48.0, room)


## The note's scroll, for a page that moves it by key (`NewThingsPopup`).
func note_scroll() -> ScrollContainer:
	return _scroll


func note_scrolls() -> bool:
	return _scroll != null and _scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED


func panel_rect() -> Rect2:
	return panel.get_global_rect() if panel != null else Rect2()
