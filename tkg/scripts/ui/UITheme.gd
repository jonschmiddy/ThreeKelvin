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

## A material's tier, as the grade ladder the game already has.
##
## CORRECTED. This first shipped as a second palette of eight colours defined
## here, on the grounds that nothing coloured a rarity yet. That was wrong:
## `ModuleData.rarity_colour` has done it all along and I missed it because it is
## a static on a data class rather than anything in `ui/`. Two ladders for one
## idea is the exact thing the first version claimed to be avoiding.
##
## The names line up exactly -- `MaterialTable`'s tiers and `ModuleData.Rarity`
## are the same eight in the same order -- so this is a lookup, not a mapping
## with opinions in it.
##
## `rarity_ink` rather than `rarity_colour`, because contraband's colour is very
## nearly black: fine as a plate's ground, unreadable as ink on one.
const TIER_ORDER: Array[StringName] = [&"common", &"uncommon", &"rare", &"epic",
	&"legendary", &"exotic", &"artifact", &"contraband"]

static func tier_rarity(tier: StringName) -> ModuleData.Rarity:
	var i := TIER_ORDER.find(tier)
	return ModuleData.Rarity.COMMON if i < 0 else i as ModuleData.Rarity


static func tier_colour(tier: StringName) -> Color:
	return ModuleData.rarity_ink(tier_rarity(tier))
const GOOD := Color("#7fb89a")

## A mount reaching for the thing you are holding. See ModuleCell.Tractor.
##
## The one colour in the game that is neither the cold of the void nor the warm
## of something burning, which is exactly what makes it read as MACHINERY doing
## something rather than as heat or as chrome. The art direction's warm/cold
## rule governs objects and lighting; this is neither, it is a field.
##
## Deliberately off Cygnet's #58c8d8. Manufacturer accents sit on module plates,
## and a drop target that borrowed one would say "Cygnet" on every hardpoint of
## every ship in the game.
const TRACTOR := Color("#4fe0cc")

## The way OUT. Quit, flee, break contact, not yet — every control whose job is
## to leave the thing you are looking at.
##
## Not a danger colour, which is why it is not called one. The red button on the
## sector screen breaks off a fight you were losing and the red item on the
## title screen closes the game; neither is the dangerous choice, both are the
## exit. Marking exits keeps them from reading as one more equal option in a row
## of buttons.
##
## This hex was already in the game twelve times across seven files before it had
## a name here — the sector screen alone spends it four times. Those sites are
## left alone rather than swept: several are semantically DAMAGE (a hull below a
## third, a negative stat) rather than an exit, and folding two meanings into one
## constant because they share a hex is how a palette stops meaning anything.
const LEAVE := Color("#d4614f")

## The two-step warning ramp: amber for "worth noticing", red for "bad". The
## chart's danger meter and the frame counter were each spelling this pair out
## as literals and agreeing only by coincidence.
const WARN := Color("#b8923f")
const BAD := Color("#c8503c")

# Bevel ramp. Raised chrome catches light top-left and falls away bottom-right —
# the same two-plane rule the sprite contract uses, applied to interface chrome.
const BEVEL_HI := Color("#3d4d61")
const BEVEL_LO := Color("#080b11")

# Silkscreen is an 8px face. Use multiples of 8 only: any other size resamples
# and the point of a pixel font is lost. The viewport is 960x540 drawn at 2x,
# so 8 here is 16 real pixels on a 1080p screen.
const FS_SMALL := 8

## Tooltips are held to one rectangle rather than sized to their text. See the
## TooltipPanel block in build(). TOOLTIP_WRAP is in CHARACTERS, applied by
## Widgets.tip() when the text is set, because a Label inside a themed
## TooltipPanel cannot be given an autowrap mode from the theme itself.
##
## 32 is narrow on purpose. A tooltip is read in one glance beside the thing it
## describes, not scanned like a paragraph, and a narrow column keeps it out of
## the way of whatever you are pointing at. Prose measures usually want 45-75
## characters; this is deliberately under that, because the text here is one or
## two sentences and never a body of copy.
const TOOLTIP_PAD_V := 6
const TOOLTIP_PAD_H := 9
const TOOLTIP_WRAP := 32
const FS_BODY := 8
const FS_HEAD := 16

## For a heading that is the ONLY thing in its corner.
##
## `FS_HEAD` is sized to sit above a subtitle and a paragraph; with those gone
## it reads as a label rather than as the name of the place you are standing in.
## 26 is the same face at the next whole multiple that stays crisp -- the font
## is a pixel face and anything between magnifications fuzzes.
const FS_PLACE := 26

## Loaded once and shared. Antialiasing and hinting are forced off in code as
## well as in project settings — a bitmap face at integer scale must not be
## smoothed, and a stray .import setting would otherwise undo it silently.
##
## NOW ACTUALLY ONCE. The comment above said "loaded once and shared" and the
## function did neither: every call re-ran load() and rewrote all four
## properties on the shared resource. That is cheap but not free, and eighteen
## call sites read this — several from inside _draw(), which this codebase
## queues on mouse motion, so the writes were landing on every hover frame of
## every card, gauge and enemy slot. The resource cache always returned the same
## FontFile, so the only thing the repetition bought was the property writes.
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

## Flavour grey: dark enough to sink toward the panel, light enough to read.
##
## Two jobs at once. Desaturated out of the palette's cold blues, because
## everything the player can act on is blue-grey and a neutral says "not this
## one" before a word is read. And held down near the panel itself, so the
## block recedes rather than competing — flavour should be findable, not
## announced.
##
## Roughly 3:1 against PANEL. That is deliberately under the threshold you
## would demand of anything a player has to act on, and it is the right side of
## the line for something they never have to read at all.
const QUOTE := Color("#5a6470")

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

	# THE ONE HOT BUTTON ON A PANEL. `Widgets.cta()` opts a button into this
	# variation; everything it does not set falls through to Button above, and
	# two of those fall-throughs are the point rather than laziness. PRESSED is
	# already ember in the base theme, so a pressed CTA and a pressed button
	# answer with the same heat -- the plate only ever promised what the press
	# was going to say anyway. And DISABLED drops the warmth entirely: a greyed
	# JUMP or a held CONTINUE has to read as "no", and a plate that stayed warm
	# while refusing would be the button equivalent of a lit door that does not
	# open. The bevel highlight goes warm with the plate, because a cool grey
	# edge on an ember face reads as a repaint rather than a different metal.
	t.set_type_variation(&"CtaButton", &"Button")
	t.set_stylebox("normal", "CtaButton",
		_bevel_box(Color("#4a2c10"), Color("#a15c1e"), BEVEL_LO, 3, 5))
	t.set_stylebox("hover", "CtaButton",
		_bevel_box(Color("#5f3915"), Color("#c47828"), BEVEL_LO, 3, 5))
	t.set_color("font_color", "CtaButton", HOT)

	# Labels
	t.set_color("font_color", "Label", CHILL)
	t.set_font_size("font_size", "Label", FS_BODY)
	t.set_color("default_color", "RichTextLabel", CHILL)
	t.set_font_size("normal_font_size", "RichTextLabel", FS_SMALL)
	t.set_stylebox("normal", "RichTextLabel", empty())

	# Scrolling.
	#
	# THE PADDING IS THE WIDTH, and these three were authored at zero.
	#
	# A `VScrollBar` derives its minimum width from its styleboxes, so a track
	# with no horizontal content margin is a bar that is nought pixels across.
	# Every ScrollContainer in the game was therefore scrollable and said so to
	# nobody: the shelf, the hold, the run history and — once it had one — the
	# salvage rail all scrolled on the wheel and drew no bar at any point. The
	# bug that got this looked at was reported as "it doesn't have a scroll",
	# which was the correct reading of what was on screen.
	#
	# Six pixels. Wide enough to see and to grab, narrow enough that it reads as
	# an edge treatment rather than as a control — the panels it lives in are
	# 268 across and a chunky bar would be a tenth of one.
	const BAR_PAD := 3
	t.set_stylebox("scroll", "VScrollBar",
		flat(Color("#0c1219"), Color(0, 0, 0, 0), 0, 0, BAR_PAD))
	t.set_stylebox("grabber", "VScrollBar",
		flat(LINE, Color(0, 0, 0, 0), 0, 0, BAR_PAD))
	t.set_stylebox("grabber_highlight", "VScrollBar",
		flat(COLD, Color(0, 0, 0, 0), 0, 0, BAR_PAD))

	# Progress bars (hull, heat, enemy)
	t.set_stylebox("background", "ProgressBar", bevel_in(Color("#0c1219"), 0, 0))
	t.set_stylebox("fill", "ProgressBar", flat(HULL_GREEN, Color(0, 0, 0, 0), 0, 0, 0))
	t.set_font_size("font_size", "ProgressBar", FS_SMALL)

	# Tooltips, held to one shape.
	#
	# Godot sizes a tooltip to its text, so a screen full of them is a screen
	# full of different rectangles — a four-word one is a sliver and a
	# three-sentence one runs most of the way across the viewport. Padding it
	# generously and giving the panel a minimum width puts a floor under the
	# small ones; TOOLTIP_WRAP puts a ceiling over the large ones by breaking
	# their lines before the viewport does.
	#
	# Both halves are needed. Only a minimum and the long ones still sprawl;
	# only a wrap and the short ones are still slivers.
	var tip := bevel(PANEL2, TOOLTIP_PAD_V, TOOLTIP_PAD_H)
	tip.set_content_margin(SIDE_LEFT, TOOLTIP_PAD_H)
	tip.set_content_margin(SIDE_RIGHT, TOOLTIP_PAD_H)
	tip.set_content_margin(SIDE_TOP, TOOLTIP_PAD_V)
	tip.set_content_margin(SIDE_BOTTOM, TOOLTIP_PAD_V)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", ICE)
	t.set_font_size("font_size", "TooltipLabel", FS_SMALL)
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
