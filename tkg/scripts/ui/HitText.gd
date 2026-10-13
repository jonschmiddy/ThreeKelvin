class_name HitText
extends RefCounted

## THE NUMBER ON A TARGET, ONE LOOK FOR BOTH TIMES IT IS SHOWN (Jon, Oct 13:
## "let's have these numbers be the same as when a card is hovered over the
## enemy ship").
##
## A card held over a target paints what it would do there (`EnemySlot`,
## `EncounterView.ShipSlot`); the same card landing pops what it did
## (`CombatFx.pop`). They were two styles -- the landing smaller, its colours
## its own -- so the answer did not read as the answer to the question the
## preview had asked. Both draw through here now: the pixel font at the
## heading size, a one-pixel dark outline all round, no plate, and one colour
## per kind of number. The pop keeps its own motion (rise, hold, fade); the
## letters are this.
##
## THE OUTLINE (Jon, Oct 13, "Pops: B"): a 1 px dark ring round every glyph, so
## a small number still reads over a bright, studded hull. It was a shadow down
## and right only, and "-6" sank into the Rustjaw cutter's rivets.
##
## WHERE (Jon, same note): held over a ship, the number is ON it, centred on the
## hull's ink both ways (`centred_at`); landed, it is ABOVE the ship, centred on
## the ink across and a few pixels clear of its top (`above`), and rises from
## there. Measured off the INK, never the canvas or the slot: your hull's canvas
## carries the exhaust's clearance on one side, which put BLOCKED 5 right of
## centre.

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

## The colour for a kind of number:
##   damage, kill  what a card does to a contact (FLARE, as the preview always was)
##   gain          what a card puts on your own hull (GOOD, likewise)
##   hurt          what reached your hull
##   block         what block and brace took
##   miss          a shot that went by
##   act           something a contact did that is not a shot
static func colour(kind: StringName) -> Color:
	match kind:
		&"damage", &"kill":
			return UITheme.FLARE
		&"gain":
			return UITheme.GOOD
		&"hurt":
			return UITheme.LEAVE
		&"block":
			return EnemySlot.ARMOR_COL
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
	# The outline: the line itself, dark, a pixel out in all eight directions.
	for o in _RING:
		ci.draw_string(f, p + o, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, sh)
	ci.draw_string(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)


## The letters' middle on `centre`, both ways: the preview on a target's ink.
static func draw_centred(ci: CanvasItem, centre: Vector2, text: String, col: Color) -> void:
	draw(ci, centred_at(centre, text), text, col)
