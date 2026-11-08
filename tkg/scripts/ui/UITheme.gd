class_name UITheme
extends RefCounted

## Cold universe, warm ship: warm colours are only combustion (reactor, fire, heat).

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

## A lookup on `ModuleData.rarity_colour`, not a second palette. `rarity_ink` as contraband
## is near black.
## Why: docs/why/UITheme.md#material-tier-colour
const TIER_ORDER: Array[StringName] = [&"common", &"uncommon", &"rare", &"epic",
	&"legendary", &"exotic", &"artifact", &"contraband"]

static func tier_rarity(tier: StringName) -> ModuleData.Rarity:
	var i := TIER_ORDER.find(tier)
	return ModuleData.Rarity.COMMON if i < 0 else i as ModuleData.Rarity


static func tier_colour(tier: StringName) -> Color:
	return ModuleData.rarity_ink(tier_rarity(tier))
const GOOD := Color("#7fb89a")

## Neither void-cold nor burning-warm, so it reads as machinery. Off Cygnet's accent to
## avoid saying Cygnet.
## Why: docs/why/UITheme.md#tractor-colour
const TRACTOR := Color("#4fe0cc")

## The exit colour, not a danger colour. Existing hex sites are left alone, as several mean
## DAMAGE.
## Why: docs/why/UITheme.md#leave-colour
const LEAVE := Color("#d4614f")

## Two-step warning ramp: the chart meter and frame counter had spelled it out as literals.
const WARN := Color("#b8923f")
const BAD := Color("#c8503c")

# Bevel ramp. Raised chrome catches light top-left and falls away bottom-right —
# the same two-plane rule the sprite contract uses, applied to interface chrome.
const BEVEL_HI := Color("#3d4d61")
const BEVEL_LO := Color("#080b11")

# Silkscreen is an 8px face: use multiples of 8 or it resamples. 960x540 viewport drawn at
# 2x.
const FS_SMALL := 8

## Tooltips are one rectangle, not sized to text. 32 chars is narrow on purpose: read in a
## glance.
## Why: docs/why/UITheme.md#tooltip-wrap
const TOOLTIP_PAD_V := 6
const TOOLTIP_PAD_H := 9
const TOOLTIP_WRAP := 32
const FS_BODY := 8
const FS_HEAD := 16

## For a heading alone in its corner. 26 is the next crisp whole multiple of the pixel
## face.
## Why: docs/why/UITheme.md#place-heading-size
const FS_PLACE := 26

## Loaded once and shared, smoothing forced off in code. It reloaded per call, hitting
## every hover `_draw`.
## Why: docs/why/UITheme.md#font-loaded-once
static var _face: FontFile = null

static func pixel_font() -> FontFile:
	if _face != null:
		return _face
	var f: FontFile = load("res://assets/fonts/Silkscreen-Regular.ttf")
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.force_autohinter = false
	_face = f
	return _face

## Flavour grey, about 3:1 against PANEL: it recedes, being something the player never has
## to read.
## Why: docs/why/UITheme.md#quote-colour
const QUOTE := Color("#5a6470")

## Panels are not quite opaque so the sky shows. `Widgets.panel_with` overrides the
## stylebox, so edit both.
## Why: docs/why/UITheme.md#panel-alpha
const PANEL_A := 0.88

static func build() -> Theme:
	var t := Theme.new()
	t.default_font = pixel_font()
	t.default_font_size = FS_BODY

	# Panels
	t.set_stylebox("panel", "PanelContainer", bevel(Color(PANEL, PANEL_A)))
	t.set_stylebox("panel", "Panel", bevel(Color(PANEL, PANEL_A)))

	# Buttons. See `button_style`: the shape of every button in the game.
	var normal: StyleBox = bevel(PANEL2, 3, 5)
	var hover: StyleBox = bevel(Color("#243244"), 3, 5)
	var pressed: StyleBox = bevel_in(Color("#4a2a0c"), 3, 5)
	var disabled: StyleBox = bevel_in(PANEL, 3, 5)
	match button_style:
		ButtonStyle.SOFT:
			normal = _bevel_box(PANEL2, Color("#2a3644"), Color("#0b0f16"), 3, 5)
			hover = _bevel_box(Color("#243244"), Color("#33465c"), Color("#0b0f16"), 3, 5)
		ButtonStyle.FLAT:
			normal = flat(PANEL2, LINE, 0, 3, 5)
			hover = flat(Color("#243244"), BEVEL_HI, 0, 3, 5)
			pressed = flat(Color("#4a2a0c"), EMBER, 0, 3, 5)
			disabled = flat(PANEL, LINE, 0, 3, 5)
		ButtonStyle.OUTLINE:
			var o := outline_boxes()
			normal = o.normal
			hover = o.hover
			pressed = o.pressed
			disabled = o.disabled
		ButtonStyle.CUT:
			normal = _cut(PANEL2, LINE)
			hover = _cut(Color("#243244"), CHILL)
			pressed = _cut(Color("#4a2a0c"), EMBER)
			disabled = _cut(PANEL, Color(LINE, 0.5))
		ButtonStyle.UNDERLINE:
			normal = _rule(Color(0, 0, 0, 0), LINE)
			hover = _rule(Color(0, 0, 0, 0), FLARE)
			pressed = _rule(Color("#2a1c0c"), EMBER)
			disabled = _rule(Color(0, 0, 0, 0), Color(LINE, 0.5))
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_stylebox("focus", "Button", normal)
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

	# Bar padding is its width: zero-padded bars were nought pixels across. `BAR_GAP` keeps
	# text off the bar (Jon, Oct 20).
	# Why: docs/why/UITheme.md#scroll-bar-sizing
	t.set_stylebox("scroll", "VScrollBar", bar_box(Color("#0c1219")))
	t.set_stylebox("grabber", "VScrollBar", bar_box(LINE))
	t.set_stylebox("grabber_highlight", "VScrollBar", bar_box(COLD))
	t.set_stylebox("grabber_pressed", "VScrollBar", bar_box(COLD))

	# Progress bars (hull, heat, enemy)
	t.set_stylebox("background", "ProgressBar", bevel_in(Color("#0c1219"), 0, 0))
	t.set_stylebox("fill", "ProgressBar", flat(HULL_GREEN, Color(0, 0, 0, 0), 0, 0, 0))
	t.set_font_size("font_size", "ProgressBar", FS_SMALL)

	# Tooltips get a minimum width and a `TOOLTIP_WRAP` ceiling; with only one half they
	# sprawl or sliver.
	# Why: docs/why/UITheme.md#tooltip-shape
	var tip := bevel(PANEL2, TOOLTIP_PAD_V, TOOLTIP_PAD_H)
	tip.set_content_margin(SIDE_LEFT, TOOLTIP_PAD_H)
	tip.set_content_margin(SIDE_RIGHT, TOOLTIP_PAD_H)
	tip.set_content_margin(SIDE_TOP, TOOLTIP_PAD_V)
	tip.set_content_margin(SIDE_BOTTOM, TOOLTIP_PAD_V)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", ICE)
	t.set_font_size("font_size", "TooltipLabel", FS_SMALL)
	return t

## Button shapes: PLATE is the original raised plate, the rest are Jon's alternatives (`--
## btn=N`).
## Why: docs/why/UITheme.md#button-styles
enum ButtonStyle { PLATE, SOFT, FLAT, OUTLINE, CUT, UNDERLINE }
static var button_style: ButtonStyle = ButtonStyle.PLATE

## A plate with its corners cut, like the drawer's chips.
static func _cut(bg: Color, edge: Color) -> StyleBoxFlat:
	var sb := flat(bg, edge, 3, 3, 5)
	sb.corner_detail = 1
	sb.corner_radius_top_left = 4
	sb.corner_radius_bottom_right = 4
	sb.corner_radius_top_right = 0
	sb.corner_radius_bottom_left = 0
	return sb

## No box at all: a rule under the word, the way a tab strip marks itself.
static func _rule(bg: Color, edge: Color) -> StyleBoxFlat:
	var sb := flat(bg, Color(0, 0, 0, 0), 0, 3, 5)
	sb.border_color = edge
	sb.border_width_bottom = 1
	return sb

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

## The OUTLINE button style's boxes, by state; also `Widgets.quiet`'s.
static func outline_boxes() -> Dictionary:
	return {
		"normal": flat(Color(0, 0, 0, 0), LINE, 0, 3, 5),
		"hover": flat(Color(PANEL2, 0.9), CHILL, 0, 3, 5),
		"pressed": flat(Color("#4a2a0c"), EMBER, 0, 3, 5),
		"disabled": flat(Color(0, 0, 0, 0), Color(LINE, 0.5), 0, 3, 5),
	}

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

## The vertical scroll bar's drawn width (a 3 px pad either side of nothing) and
## the clear gutter on its left; a ScrollContainer reserves both.
const BAR_PAD := 3
const BAR_GAP := 4
const BAR_W := BAR_PAD * 2 + BAR_GAP


## Left border is transparent because StyleBoxFlat leaves borders out of the fill.
static func bar_box(c: Color) -> StyleBoxFlat:
	var sb := flat(c, Color(0, 0, 0, 0), 0, 0, BAR_PAD)
	sb.border_width_left = BAR_GAP
	sb.content_margin_left = BAR_PAD + BAR_GAP
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

## Moved from LobbyScreen: the rename box made it a second use, so a pattern. Recessed,
## caret in EMBER.
## Why: docs/why/UITheme.md#text-field
static func field(chars: int = 20) -> LineEdit:
	var e := LineEdit.new()
	e.custom_minimum_size = Vector2(chars * 10, 0)
	e.add_theme_stylebox_override("normal", bevel_in(VOID, 4, 6))
	e.add_theme_stylebox_override("focus", bevel_in(VOID, 4, 6))
	e.add_theme_color_override("font_color", ICE)
	e.add_theme_color_override("font_placeholder_color", COLD)
	e.add_theme_color_override("caret_color", EMBER)
	e.add_theme_font_size_override("font_size", FS_BODY)
	return e


## `size` is a parameter: Silkscreen's only legal larger size is 16, with no rung in
## between.
static func header(text: String, size: int = FS_SMALL) -> Label:
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_color_override("font_color", COLD)
	l.add_theme_font_size_override("font_size", size)
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
