class_name MapGlyphs
extends RefCounted

## THE MAP'S BEACON GLYPHS (Jon, Nov 18): 11 x 11 pictures in game pixels, drawn 1:1, read by the
## overlay's beacons and edge arrows, the KEY and the quest log, so one icon means one thing.
## Why: docs/why/MapGlyphs.md#the-glyphs

const SIZE := 11
## THE INK, LIFTED FOR THE TUBE (Jon, Nov 18: "Can we fix the CRT issue?"): 1 px strokes lost a
## third of their contrast through the default CRT look, so the main colour is brighter (value
## x INK_V, then INK_LIFT toward white), the fill heavier, and a map beacon wears a dark rim.
## Why: docs/why/MapGlyphs.md#ink-for-the-tube
const INK_V := 1.25
const INK_LIFT := 0.15
## The KEY strip sits low, where the tube's vignette takes most: its glyphs lift further.
const KEY_LIFT := 0.3
## How much of the beacon's colour a fill pixel (m) keeps.
const FILL_A := 0.7
## The rim behind a map beacon's outer pixels: the edge arrows' dark, at this much.
const RIM := Color("#05070b")
const RIM_A := 0.6
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

## Each glyph's lit pixels as (x, y, code), and the pixels round them, parsed once.
static var _px: Dictionary[StringName, Array] = {}
static var _rim: Dictionary[StringName, Array] = {}


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


## The glyph's empty pixels (and one row past it) that touch a lit one, eight ways.
static func rim_pixels(name: StringName) -> Array[Vector2i]:
	if not GLYPH.has(name):
		name = &"signal"
	if not _rim.has(name):
		var lit := {}
		for p: Vector3i in pixels(name):
			lit[Vector2i(p.x, p.y)] = true
		var out: Array[Vector2i] = []
		for q: Vector2i in lit:
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					var n := q + Vector2i(dx, dy)
					if not lit.has(n) and not out.has(n):
						out.append(n)
		_rim[name] = out
	var got: Array[Vector2i] = []
	got.assign(_rim[name])
	return got


## The beacon's colour as a glyph draws it: brighter, the hue kept, the alpha kept.
static func boost(c: Color, lift := INK_LIFT) -> Color:
	var b := Color.from_hsv(c.h, c.s, minf(1.0, c.v * INK_V), c.a)
	return b.lerp(Color(1.0, 1.0, 1.0, c.a), lift)


## A pixel's colour, `main` already boosted: the accents keep the beacon's alpha (a dimmed beacon
## dims them too), and `flat` paints them in `main` (a spent beacon's grey).
static func ink(code: int, main: Color, flat := false) -> Color:
	if code == 1:
		return Color(main, main.a * FILL_A)
	if flat or code == 0:
		return main
	return Color([UITheme.ICE, UITheme.HOT, UITheme.CHILL][code - 2], main.a)


## `name` with its top left at `at`, in `main` (boosted here; a `flat` spent one is not), on a dark
## rim when `rim` (a map beacon, which can stand on a bright sky).
static func draw(ci: CanvasItem, at: Vector2, name: StringName, main: Color, flat := false, rim := false,
		lift := INK_LIFT) -> void:
	if rim:
		var dark := Color(RIM, RIM_A * main.a)
		for q: Vector2i in rim_pixels(name):
			ci.draw_rect(Rect2(at + Vector2(q), Vector2.ONE), dark)
	var m := main if flat else boost(main, lift)
	for p: Vector3i in pixels(name):
		ci.draw_rect(Rect2(at + Vector2(p.x, p.y), Vector2.ONE), ink(p.z, m, flat))
