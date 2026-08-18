class_name UITheme
extends RefCounted

## Cold universe, warm ship. The void, panels and chrome are desaturated blues;
## the only warm colours in the game are combustion — reactor glow, weapon fire,
## and heat on your own hull.

const VOID := Color("#0a0e15")
const PANEL := Color("#111823")
const PANEL2 := Color("#161f2c")
const LINE := Color("#22303f")
const COLD := Color("#6b7d94")
const CHILL := Color("#8fa3ba")
const ICE := Color("#c3d2e2")
const EMBER := Color("#d97b29")
const FLARE := Color("#ff9d3d")
const HOT := Color("#ffd28a")
const HULL_GREEN := Color("#4d7a63")
const THEM := Color("#c98d7a")
const GOOD := Color("#7fb89a")

const FS_SMALL := 14
const FS_BODY := 16
const FS_HEAD := 20

static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = FS_BODY

	# Panels
	t.set_stylebox("panel", "PanelContainer", flat(PANEL, LINE))
	t.set_stylebox("panel", "Panel", flat(PANEL, LINE))

	# Buttons
	var normal := flat(PANEL2, LINE, 4, 6, 10)
	var hover := flat(PANEL2, EMBER, 4, 6, 10)
	var pressed := flat(LINE, FLARE, 4, 6, 10)
	var disabled := flat(PANEL, LINE, 4, 6, 10)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_stylebox("focus", "Button", flat(PANEL2, CHILL, 4, 6, 10))
	t.set_color("font_color", "Button", ICE)
	t.set_color("font_hover_color", "Button", FLARE)
	t.set_color("font_pressed_color", "Button", HOT)
	t.set_color("font_disabled_color", "Button", Color(COLD.r, COLD.g, COLD.b, 0.35))
	t.set_font_size("font_size", "Button", FS_SMALL)

	# Labels
	t.set_color("font_color", "Label", CHILL)
	t.set_font_size("font_size", "Label", FS_BODY)
	t.set_color("default_color", "RichTextLabel", CHILL)
	t.set_font_size("normal_font_size", "RichTextLabel", FS_SMALL)
	t.set_stylebox("normal", "RichTextLabel", empty())

	# Scrolling
	t.set_stylebox("scroll", "VScrollBar", flat(Color("#0c1219"), Color(0, 0, 0, 0), 2, 0, 0))
	t.set_stylebox("grabber", "VScrollBar", flat(LINE, Color(0, 0, 0, 0), 2, 0, 0))
	t.set_stylebox("grabber_highlight", "VScrollBar", flat(COLD, Color(0, 0, 0, 0), 2, 0, 0))

	# Progress bars (hull, heat, enemy)
	t.set_stylebox("background", "ProgressBar", flat(Color("#0c1219"), LINE, 0, 0, 0))
	t.set_stylebox("fill", "ProgressBar", flat(HULL_GREEN, Color(0, 0, 0, 0), 0, 0, 0))
	t.set_font_size("font_size", "ProgressBar", FS_SMALL)

	t.set_stylebox("panel", "TooltipPanel", flat(PANEL2, EMBER))
	t.set_color("font_color", "TooltipLabel", ICE)
	return t

static func flat(bg: Color, border: Color, radius: int = 0,
		pad_v: int = 8, pad_h: int = 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1 if border.a > 0.0 else 0)
	sb.set_corner_radius_all(radius)
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	return sb

static func empty() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()

static func log_colour(kind: StringName) -> Color:
	match kind:
		&"you": return CHILL
		&"them": return THEM
		&"heat": return FLARE
		&"good": return GOOD
		&"big": return ICE
		_: return COLD

## Small caps-ish section header used throughout the UI.
static func header(text: String) -> Label:
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_color_override("font_color", COLD)
	l.add_theme_font_size_override("font_size", FS_SMALL)
	return l

static func body(text: String, colour: Color = CHILL, size: int = FS_BODY) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", colour)
	l.add_theme_font_size_override("font_size", size)
	return l

static func hsep() -> HSeparator:
	var s := HSeparator.new()
	var sb := StyleBoxLine.new()
	sb.color = LINE
	sb.thickness = 1
	s.add_theme_stylebox_override("separator", sb)
	return s
