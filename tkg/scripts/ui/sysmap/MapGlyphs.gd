class_name MapGlyphs
extends RefCounted

## THE MAP'S BEACON GLYPHS (Jon, Nov 18): 11 x 11 pictures in game pixels, drawn 1:1, read by the
## overlay's beacons and edge arrows, the KEY and the quest log, so one icon means one thing.
## Why: docs/why/MapGlyphs.md#the-glyphs

const SIZE := 11
## How much of the beacon's colour a fill pixel (m) keeps.
const FILL_A := 0.47
## M the beacon's colour, m that at FILL_A, I ice, H hot, C chill, . nothing.
const GLYPH := {
	# a gunsight
	&"fight": [
		".....M.....",
		"...MMMMM...",
		"..M..M..M..",
		".M.......M.",
		".M.......M.",
		"MMM..H..MMM",
		".M.......M.",
		".M.......M.",
		"..M..M..M..",
		"...MMMMM...",
		".....M.....",
	],
	# the radiation trefoil
	&"hazard": [
		"...........",
		"..M.....M..",
		".MmM...MmM.",
		"MmmM...MmmM",
		"MmmM...MmmM",
		"MMMM.H.MMMM",
		"...........",
		"....MMM....",
		"....MmM....",
		"...MmmmM...",
		"...MMMMM...",
	],
	# a gear
	&"salvage": [
		"....MMM....",
		".MM.MmM.MM.",
		".MmMMmMMmM.",
		"..MmmmmmM..",
		"MMMmMMMmMMM",
		"MmmmM.MmmmM",
		"MMMmMMMmMMM",
		"..MmmmmmM..",
		".MmMMmMMmM.",
		".MM.MmM.MM.",
		"....MMM....",
	],
	# a sample flask
	&"science": [
		"...MMMMM...",
		"....M.M....",
		"....M.M....",
		"...M...M...",
		"..M.....M..",
		".M.......M.",
		"M.........M",
		"MmmmmmmmmmM",
		"MmmImmmmmIM",
		"MmmmmmImmmM",
		".MMMMMMMMM.",
	],
	# three bars rising
	&"signal": [
		"........MMI",
		"........MmM",
		"........MmM",
		"....MMM.MmM",
		"....MmM.MmM",
		"....MmM.MmM",
		"MMM.MmM.MmM",
		"MmM.MmM.MmM",
		"MmM.MmM.MmM",
		"MmM.MmM.MmM",
		"MMM.MMM.MMM",
	],
	# a page with its corner folded
	&"contract": [
		".MMMMMM....",
		".MmmmmMM...",
		".MmmmmMmM..",
		".MmmmmMMMM.",
		".MmIIIIImM.",
		".MmmmmmmmM.",
		".MmIIIIImM.",
		".MmmmmmmmM.",
		".MmIIImmmM.",
		".MmmmmmmmM.",
		".MMMMMMMMM.",
	],
	# a map pin
	&"quest": [
		"...MMMMM...",
		"..MmmmmmM..",
		".MmmmmmmmM.",
		".MmmMMMmmM.",
		".MmmMHMmmM.",
		".MmmMMMmmM.",
		"..MmmmmmM..",
		"...MmmmM...",
		"....MmM....",
		".....M.....",
		"...........",
	],
	# an arrow down into a bay
	&"dock": [
		"....MMM....",
		"....MMM....",
		"..MMMMMMM..",
		"...MMMMM...",
		"....MMM....",
		".....M.....",
		"M.........M",
		"M.........M",
		"M..CCHCC..M",
		"M.........M",
		"MMMMMMMMMMM",
	],
	# four arrows pulling in
	&"harvest": [
		"M.........M",
		".M.M...M.M.",
		"..MM...MM..",
		".MMM...MMM.",
		".....m.....",
		"....mHm....",
		".....m.....",
		".MMM...MMM.",
		"..MM...MM..",
		".M.M...M.M.",
		"M.........M",
	],
	# a black hole in its ring
	&"core": [
		"...........",
		"...........",
		"....MMM....",
		"...M...M...",
		"..M.....M..",
		"mmMmmmmmMmm",
		"HMMMMMMMMMH",
		"mmMmmmmmMmm",
		"...M...M...",
		"....MMM....",
		"...........",
	],
}
const CODES := "MmIHC"

## Each glyph's lit pixels as (x, y, code), parsed once.
static var _px: Dictionary[StringName, Array] = {}


static func pixels(name: StringName) -> Array[Vector3i]:
	if not GLYPH.has(name):
		name = &"signal"
	if not _px.has(name):
		var out: Array[Vector3i] = []
		var rows: Array = GLYPH[name]
		for y in rows.size():
			var r: String = rows[y]
			for x in r.length():
				var k := CODES.find(r[x])
				if k >= 0:
					out.append(Vector3i(x, y, k))
		_px[name] = out
	var got: Array[Vector3i] = []
	got.assign(_px[name])
	return got


## A pixel's colour: the accents keep the beacon's alpha (a dimmed beacon dims them too), and `flat`
## paints them in `main` (a spent beacon's grey).
static func ink(code: int, main: Color, flat := false) -> Color:
	if code == 1:
		return Color(main, main.a * FILL_A)
	if flat or code == 0:
		return main
	return Color([UITheme.ICE, UITheme.HOT, UITheme.CHILL][code - 2], main.a)


## `name` with its top left at `at`, in `main`.
static func draw(ci: CanvasItem, at: Vector2, name: StringName, main: Color, flat := false) -> void:
	for p: Vector3i in pixels(name):
		ci.draw_rect(Rect2(at + Vector2(p.x, p.y), Vector2.ONE), ink(p.z, main, flat))
