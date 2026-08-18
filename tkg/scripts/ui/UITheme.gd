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

# Bevel ramp. Raised chrome catches light top-left and falls away bottom-right —
# the same two-plane rule the sprite contract uses, applied to interface chrome.
const BEVEL_HI := Color("#3d4d61")
const BEVEL_LO := Color("#080b11")

# Silkscreen is an 8px face. Use multiples of 8 only: any other size resamples
# and the point of a pixel font is lost. The viewport is 960x540 drawn at 2x,
# so 8 here is 16 real pixels on a 1080p screen.
const FS_SMALL := 8
const FS_BODY := 8
const FS_HEAD := 16

## Loaded once and shared. Antialiasing and hinting are forced off in code as
## well as in project settings — a bitmap face at integer scale must not be
## smoothed, and a stray .import setting would otherwise undo it silently.
static func pixel_font() -> FontFile:
	var f: FontFile = load("res://assets/fonts/Silkscreen-Regular.ttf")
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.force_autohinter = false
	return f

static func build() -> Theme:
	var t := Theme.new()
	t.default_font = pixel_font()
	t.default_font_size = FS_BODY

	# Panels
	t.set_stylebox("panel", "PanelContainer", bevel(PANEL))
	t.set_stylebox("panel", "Panel", bevel(PANEL))

	# Buttons
	var normal := bevel(PANEL2, 3, 5)
	var hover := bevel(Color("#243244"), 3, 5)
	var pressed := bevel_in(Color("#4a2a0c"), 3, 5)
	var disabled := bevel_in(PANEL, 3, 5)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_stylebox("focus", "Button", bevel(PANEL2, 3, 5))
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
	t.set_stylebox("scroll", "VScrollBar", flat(Color("#0c1219"), Color(0, 0, 0, 0), 0, 0, 0))
	t.set_stylebox("grabber", "VScrollBar", flat(LINE, Color(0, 0, 0, 0), 0, 0, 0))
	t.set_stylebox("grabber_highlight", "VScrollBar", flat(COLD, Color(0, 0, 0, 0), 0, 0, 0))

	# Progress bars (hull, heat, enemy)
	t.set_stylebox("background", "ProgressBar", bevel_in(Color("#0c1219"), 0, 0))
	t.set_stylebox("fill", "ProgressBar", flat(HULL_GREEN, Color(0, 0, 0, 0), 0, 0, 0))
	t.set_font_size("font_size", "ProgressBar", FS_SMALL)

	t.set_stylebox("panel", "TooltipPanel", bevel(PANEL2, 4, 6))
	t.set_color("font_color", "TooltipLabel", ICE)
	return t

## Raised surface: 1px light top-left, 1px dark bottom-right, drawn as a 9-slice
## so it never stretches. 1px here is 2 real pixels at the 2x viewport scale.
static func bevel(bg: Color, pad_v: int = 4, pad_h: int = 6) -> StyleBoxTexture:
	return _bevel_box(bg, BEVEL_HI, BEVEL_LO, pad_v, pad_h)

## Recessed surface — the same bevel inverted. Use it for anything the eye should
## read as a hole rather than a plate: sockets, wells, gauge tracks.
static func bevel_in(bg: Color, pad_v: int = 4, pad_h: int = 6) -> StyleBoxTexture:
	return _bevel_box(bg, BEVEL_LO, Color("#2a3644"), pad_v, pad_h)

static func _bevel_box(bg: Color, hi: Color, lo: Color,
		pad_v: int, pad_h: int) -> StyleBoxTexture:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(bg)
	for i in 4:
		img.set_pixel(i, 0, hi)
		img.set_pixel(0, i, hi)
		img.set_pixel(i, 3, lo)
		img.set_pixel(3, i, lo)
	# Opposite corners belong to neither face; leave them flat so the join
	# does not read as a notch.
	img.set_pixel(3, 0, bg)
	img.set_pixel(0, 3, bg)

	var sb := StyleBoxTexture.new()
	sb.texture = ImageTexture.create_from_image(img)
	sb.set_texture_margin_all(1)
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	return sb

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
