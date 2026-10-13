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
## heading size, a one-pixel shadow down and right, no plate, and one colour
## per kind of number. The pop keeps its own motion (rise, hold, fade); the
## letters are this.

const SHADOW := Color(0, 0, 0, 0.75)
## Line to line when several stack on one hull.
const LINE := 17.0

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


## Draw `text` with its baseline's left end at `at`, in `col`. `fade` (1 to 0)
## dims the letters and their shadow together, for a pop on its way out.
static func draw(ci: CanvasItem, at: Vector2, text: String, col: Color, fade: float = 1.0) -> void:
	var f := font()
	var fs := size()
	var sh := SHADOW
	sh.a *= fade
	var c := col
	if fade < 1.0:
		c = col.darkened(1.0 - fade)
	ci.draw_string(f, (at + Vector2(1, 1)).round(), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, sh)
	ci.draw_string(f, at.round(), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)


## Centred on `centre` the way the preview sits on a target: its middle there,
## the baseline a little below.
static func draw_centred(ci: CanvasItem, centre: Vector2, text: String, col: Color) -> void:
	var at := Vector2(centre.x - width(text) * 0.5, centre.y + size() * 0.4)
	draw(ci, at, text, col)
