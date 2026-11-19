class_name ChartGlyphs
extends RefCounted

## THE STAR CHART'S ICONS (Jon, Nov 18): the sector beacons' style at the chart's sizes, for the
## chart, its KEY and the in-range list. Plain systems are dots and have none.
## Why: docs/why/ChartGlyphs.md#the-icons

## How far a node icon's ink is lifted toward white, as the old glyph's body was: a far icon is a smudge without it.
const LIFT := 0.34
## Node icons: 9 zoomed in, 7 at the opening zoom (where neighbours sit 6 px apart).
## Why: docs/why/ChartGlyphs.md#sizes
const BIG := 9
const SMALL := 7
## Codes as `MapGlyphs`: M the ink, m it at `MapGlyphs.FILL_A`, I ice, H hot, C chill.
const NODE := {
	# a flag planted: where the run began
	&"start": {
		9: [
			"..MMMMMM.",
			"..MmmmmmM",
			"..MmmHmmM",
			"..MmmmmmM",
			"..MMMMMM.",
			"..M......",
			"..M......",
			"..M......",
			"MMMMM....",
		],
		7: [
			".MMMMM.",
			".MmHmmM",
			".MmmmM.",
			".MMMM..",
			".M.....",
			".M.....",
			"MMM....",
		],
	},
	# the sector's DOCK (`MapGlyphs` &"dock"), an arrow into a bay, at the chart's sizes
	&"station": {
		9: [
			"...MMM...",
			"...MMM...",
			".MMMMMMM.",
			"..MMMMM..",
			"...MMM...",
			"M...M...M",
			"M.......M",
			"M..CHC..M",
			"MMMMMMMMM",
		],
		7: [
			"..MMM..",
			".MMMMM.",
			"..MMM..",
			"M..M..M",
			"M.....M",
			"M.CHC.M",
			"MMMMMMM",
		],
	},
	# a spinning star throwing two beams, its middle open for the sky's own flash
	&"pulsar": {
		9: [
			"MM.......",
			"MmM......",
			".MMMMM...",
			"..M...M..",
			"..M...M..",
			"..M...M..",
			"...MMMMM.",
			"......MmM",
			".......MM",
		],
		7: [
			"MM.....",
			"MmM....",
			".MMMM..",
			"..M.M..",
			"..MMMM.",
			"....MmM",
			".....MM",
		],
	},
}
## The markers that are not the sector's: the hellbender's skull (11) and a partner's diamond (9).
const MARK := {
	&"hellbender": [
		"..MMMMMMM..",
		".MmmmmmmmM.",
		"MmmmmmmmmmM",
		"MmHHmmmHHmM",
		"MmHHmmmHHmM",
		"MmmmmMmmmmM",
		".MmmmmmmmM.",
		"..MMmmmMM..",
		"..MmMmMmM..",
		"..MMMMMMM..",
		"...........",
	],
	&"party": [
		"....M....",
		"...MmM...",
		"..Mm.mM..",
		".Mm...mM.",
		"Mm.....mM",
		".Mm...mM.",
		"..Mm.mM..",
		"...MmM...",
		"....M....",
	],
}
## The pin (`MapGlyphs` &"quest") stands on its star: this pixel of it on the star's centre, the tip 3 above.
const PIN_AT := Vector2i(5, 12)
## One corner of YOU's brackets, top left; the other three are it mirrored.
const YOU_CORNER := [
	"HMMMM",
	"MMMMM",
	"MM...",
	"MM...",
	"MM...",
]
## YOU's half-width: zoomed out (round the opening zoom's 7 px icons and their neighbours) and in.
const YOU_HALF_OUT := 11
const YOU_HALF_IN := 9

## Parsed once per grid: its lit pixels (x, y, code) and the void rim on their four sides.
static var _px: Dictionary[String, Array] = {}
static var _rim: Dictionary[String, Array] = {}


## Which icon a node type wears; &"" for a plain system, which is a dot.
static func kind_of(t: MapGen.NodeType) -> StringName:
	match t:
		MapGen.NodeType.START: return &"start"
		MapGen.NodeType.STATION: return &"station"
		MapGen.NodeType.PULSAR: return &"pulsar"
		MapGen.NodeType.CORE: return &"core"
	return &""


static func _rows(key: String) -> Array[String]:
	var out: Array[String] = []
	if key == "core" or key == "quest":
		out.assign(MapGlyphs.GLYPH[StringName(key)])
	elif key.begins_with("you"):
		out = _you_rows(int(key.substr(3)))
	elif MARK.has(StringName(key)):
		out.assign(MARK[StringName(key)])
	else:
		var cut := key.length() - 1
		out.assign(NODE[StringName(key.left(cut))][int(key.substr(cut))])
	return out


static func _you_rows(half: int) -> Array[String]:
	var n := half * 2 + 1
	var g: Array[String] = []
	for y in n:
		var row := ""
		for x in n:
			var cx := mini(x, n - 1 - x)
			var cy := mini(y, n - 1 - y)
			row += (YOU_CORNER[cy] as String)[cx] if cx < 5 and cy < 5 else "."
		g.append(row)
	return g


static func _parse(key: String) -> void:
	if _px.has(key):
		return
	var rows := _rows(key)
	var on: Dictionary[Vector2i, int] = {}
	for y in rows.size():
		var r: String = rows[y]
		for x in r.length():
			var k := MapGlyphs.CODES.find(r[x])
			if k >= 0:
				on[Vector2i(x, y)] = k
	var px: Array[Vector3i] = []
	var rim: Dictionary[Vector2i, bool] = {}
	for c: Vector2i in on:
		px.append(Vector3i(c.x, c.y, on[c]))
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if not on.has(c + d):
				rim[c + d] = true
	_px[key] = px
	_rim[key] = rim.keys()


## Grid `key` with its pixel `at` on the centre pixel `cp`; the rim in `under` (skipped when clear),
## and `flat` paints the accents in `main` too (a too-deep grey).
static func _draw(ci: CanvasItem, key: String, cp: Vector2, at: Vector2i, main: Color,
		under: Color, flat: bool) -> void:
	_parse(key)
	var o := cp - Vector2(at)
	if under.a > 0.0:
		for q: Vector2i in _rim[key]:
			ci.draw_rect(Rect2(o + Vector2(q), Vector2.ONE), under, true)
	for p: Vector3i in _px[key]:
		ci.draw_rect(Rect2(o + Vector2(p.x, p.y), Vector2.ONE), MapGlyphs.ink(p.z, main, flat), true)


## A node's icon centred on `cp`: `size` 9 or 7 (the core is always the sector's 11).
static func draw_node(ci: CanvasItem, t: MapGen.NodeType, cp: Vector2, size: int, main: Color,
		under: Color, flat := false) -> void:
	var kind := kind_of(t)
	if kind == &"":
		return
	var key := "core" if kind == &"core" else "%s%d" % [kind, size]
	var half := (MapGlyphs.SIZE if kind == &"core" else size) / 2
	_draw(ci, key, cp, Vector2i(half, half), main, under, flat)


## A marker on the star at `cp`: &"quest" (the sector's pin, standing on it), &"hellbender", &"party".
static func draw_mark(ci: CanvasItem, name: StringName, cp: Vector2, main: Color, under: Color) -> void:
	if name == &"quest":
		_draw(ci, "quest", cp, PIN_AT, main, under, false)
		return
	var rows: Array = MARK[name]
	var half: int = rows.size() / 2
	_draw(ci, String(name), cp, Vector2i(half, half), main, under, false)


## YOU's brackets round the star at `cp`.
static func draw_you(ci: CanvasItem, cp: Vector2, half: int, main: Color, under: Color) -> void:
	_draw(ci, "you%d" % half, cp, Vector2i(half, half), main, under, false)


## The centre pixel the chart draws a mark on, for a star at `at`: the old 13 px glyph's middle.
static func centre(at: Vector2) -> Vector2:
	return (at - Vector2(6, 6)).round() + Vector2(6, 6)
