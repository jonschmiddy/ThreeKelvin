class_name HitText
extends RefCounted

## One look for preview and landing numbers (Jon, Oct 13): pixel font, 1 px dark outline, no plate.
## Centred on the hull's ink, not the canvas, whose exhaust clearance skewed BLOCKED 5.
## Why: docs/why/HitText.md#hit-text

const SHADOW := Color(0, 0, 0, 0.85)
## Line to line when several stack on one hull.
const LINE := 17.0
## Silkscreen's capitals and figures at FS_HEAD, in px: the ink of a line is the
## CAP rows above its baseline (measured off the frames: BLOCKED 5 is 10 rows).
const CAP := 10.0
## The empty column pair after the last glyph in its advance: ink is narrower
## than `width` by this.
const TRAIL := 2.0
## A landed number's baseline above the ink's top: the outline's row and three
## pixels of air.
const GAP := 4.0
## How far a landed number rises (`CombatFx`'s pop).
const RISE := 10.0

## Damage and gain keep the preview's FLARE and GOOD; the other kinds name what reached the hull.
## Why: docs/why/HitText.md#hit-text
static func colour(kind: StringName) -> Color:
	match kind:
		&"damage", &"kill":
			return UITheme.FLARE
		&"gain":
			return UITheme.GOOD
		&"hurt":
			return UITheme.LEAVE
		&"block":
			return UITheme.BRACE
		&"miss":
			return UITheme.COLD
		&"act":
			return UITheme.EMBER
	return UITheme.FLARE


static func font() -> Font:
	return UITheme.pixel_font()


static func size() -> int:
	return UITheme.FS_HEAD


static func width(text: String) -> float:
	return font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size()).x


## How wide the letters themselves are.
static func ink_width(text: String) -> float:
	return maxf(0.0, width(text) - TRAIL)


## The letters' own box, for a line whose baseline starts at `at` (outline not
## included; it is one pixel more all round).
static func ink_rect(at: Vector2, text: String) -> Rect2:
	return Rect2(at.x, at.y - CAP, ink_width(text), CAP)


## Where to put a line's baseline start so its letters are centred on `centre`.
static func centred_at(centre: Vector2, text: String) -> Vector2:
	return Vector2(centre.x - ink_width(text) * 0.5, centre.y + CAP * 0.5).round()


## A landed number's spot over a hull whose ink is `ink`: the middle across, the
## baseline GAP above the top. (`CombatFx.pop` centres the line on this x.)
static func above(ink: Rect2) -> Vector2:
	return Vector2(ink.get_center().x, ink.position.y - GAP).round()


const _RING: Array[Vector2] = [Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1),
	Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(0, 1), Vector2(1, 1)]

## Draw `text` with its baseline's left end at `at`, in `col`. `fade` (1 to 0)
## dims the letters and their outline together, for a pop on its way out.
static func draw(ci: CanvasItem, at: Vector2, text: String, col: Color, fade: float = 1.0) -> void:
	var f := font()
	var fs := size()
	var sh := SHADOW
	sh.a *= fade
	var c := col
	if fade < 1.0:
		c = col.darkened(1.0 - fade)
	var p := at.round()
	text = LowHull.scr(ci, text, fs, f)
	# The outline: the line itself, dark, a pixel out in all eight directions.
	for o in _RING:
		ci.draw_string(f, p + o, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, sh)
	ci.draw_string(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)


## The letters' middle on `centre`, both ways: the preview on a target's ink.
static func draw_centred(ci: CanvasItem, centre: Vector2, text: String, col: Color) -> void:
	draw(ci, centred_at(centre, text), text, col)
