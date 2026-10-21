class_name NoteCard
extends Control

## JON'S NOTES AS A LETTER: the welcome note over the title (`WelcomePopup`) and
## the thank-you note on the win screen (`GameOverScreen`), one look for both.
##
## THE CLEAN LOOK, Jon's pick of three (Oct 13; a riveted pixel bezel and the
## same bezel with a glow round it were the others): the salvage popup's
## chamfered case and its readout heading -- a hazard mark, the title, a
## scanline -- so the notes read as part of the same interface as the wreck you
## just stripped.
##
## Full-rect: a dim behind, then the panel centred on it. The panel is the
## heading, the note (its sign-off split off and set apart: a pixel heart for
## "<3", then the name, right-aligned like a letter's), whatever the caller adds
## under it (`add_section`), a row of buttons (`add_buttons`) and a footer
## (`add_footer`). The note scrolls only if the window is too short for the
## whole panel (`_fit`). It fades in when it opens.

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

	# OVER THE WHOLE PICTURE, not this card's rect: a screen stops short of the
	# glass by Main's margin, and the title's galaxy showed through it undimmed
	# as a frame round the note (`Widgets.cover_picture`)
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
	# Room between the lines. Silkscreen is the only face and is crisp only at 8
	# and 16, so the type cannot go a size up without doubling the panel; the
	# spacing is what makes paragraphs of eight-pixel capitals readable.
	body.add_theme_constant_override("line_spacing", 4)
	letter.add_child(body)
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


## A wrapping label measured before it has a width is one letter wide and
## hundreds of pixels tall, which threw `_fit` into scrolling a note that fits;
## so it is given the column's width from the start.
func _full_width(c: Control) -> Control:
	if c is Label and (c as Label).autowrap_mode != TextServer.AUTOWRAP_OFF:
		c.custom_minimum_size.x = WIDTH
	return c


## THE BUTTON THAT MOVES YOU ON, and the most button-like thing on screen: an
## authored amber plate (`art/tools/note_frame.py`) at the heading's size, lit
## on hover, pressed in. Every other button beside it is the game's own.
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
	var b := StyleBoxFlat.new()
	b.bg_color = UITheme.PANEL2
	b.border_color = UITheme.LINE
	b.set_border_width_all(1)
	b.corner_radius_top_left = 10
	b.corner_radius_bottom_right = 10
	b.corner_detail = 1
	b.content_margin_top = 18
	b.content_margin_bottom = 18
	b.content_margin_left = 24
	b.content_margin_right = 24
	return b


## THE NOTE SCROLLS ONLY IF THE PANEL WOULD NOT FIT. At the game's 960x540 the
## whole letter shows; a shorter window (or a longer letter) caps the note's
## height so the heading, whatever is under it and the buttons stay on screen.
## Not before the note has its width: an autowrapped label measured narrower
## than it will be is many times taller than it will be.
func _fit() -> void:
	if _scroll == null or panel == null or not is_inside_tree() or size.y <= 0.0:
		return
	# (a scrolling note is narrower by its bar, and is measured anyway)
	if body.size.x < WIDTH - 1.0 and not note_scrolls():
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


func note_scrolls() -> bool:
	return _scroll != null and _scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED


func panel_rect() -> Rect2:
	return panel.get_global_rect() if panel != null else Rect2()
