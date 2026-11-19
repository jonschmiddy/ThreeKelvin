class_name ChartGlyphs
extends RefCounted

## THE STAR CHART'S ICONS (Jon, Nov 18): the sector beacons' style at the chart's sizes, for the
## chart, its KEY and the in-range list; a plain system wears a sun, as big as the rest.
## Why: docs/why/ChartGlyphs.md#the-icons

## THE INK FOR THE TUBE (Jon, Nov 18: "kinda... dull?"): the chart's dimming, softened to a floor, then
## `MapGlyphs.boost` as the sector's beacons. Far and unseen still read quieter, never brown or grey.
## Why: docs/why/ChartGlyphs.md#ink
const NEAR_LIFT := 0.12
const FAR_DIM := 0.12
const UNSEEN_DIM := 0.25
## No icon's ink goes below this value (HSV) before the boost: a red star's station stays red, not brown.
const FLOOR_V := 0.7
## The boost's lift for a node icon: the old glyph body's lift (0.34) kept a red core bright, which the
## sector's 0.15 alone does not.
const NODE_LIFT := 0.3
## A spent (cleared) place's icon: the chart's CLEARED grey lifted as the old glyph body was, drawn flat
## and never boosted, as the sector's spent beacon, so it reads as done rather than as a lit place.
const SPENT := Color("#7b848d")
## Node icons: 9 zoomed in, 7 at the opening zoom (where neighbours sit 6 px apart).
## Why: docs/why/ChartGlyphs.md#sizes
const BIG := 9
const SMALL := 7
## Codes as `MapGlyphs`: M the ink, m it at `MapGlyphs.FILL_A`, I ice, H hot, C chill.
const NODE := {
	# a sun with short rays: a plain system ("system:A", Jon, Nov 18)
	&"system": {
		9: [
			"....M....",
			".M.....M.",
			"...MMM...",
			"..MmmmM..",
			"M.MmHmM.M",
			"..MmmmM..",
			"...MMM...",
			".M.....M.",
			"....M....",
		],
		7: [
			"...M...",
			".M...M.",
			"..MMM..",
			"M.MHM.M",
			"..MMM..",
			".M...M.",
			"...M...",
		],
	},
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
	# TWO SUNS (ruling 20): the sun with a small warm sun at its lower right ("twin:A", Jon, Nov 18)
	&"twin": {
		9: [
			"...M.....",
			".M...M...",
			"..MMM....",
			"M.MHM.M..",
			"..MMM....",
			".M...M.H.",
			"...M..HHH",
			".......H.",
			".........",
		],
		7: [
			"..M....",
			".MMM...",
			"MMHMM..",
			".MMM.H.",
			"..M.HHH",
			".....H.",
			".......",
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


## A node icon's ink from its star's colour: near you lifted, far and unseen dimmed to the floor, then boosted.
static func node_ink(tint: Color, near: bool, seen: bool) -> Color:
	var c := tint.lightened(NEAR_LIFT) if near else tint.darkened(FAR_DIM)
	if not seen:
		c = c.darkened(UNSEEN_DIM)
	if c.v < FLOOR_V:
		c = Color.from_hsv(c.h, c.s, FLOOR_V, c.a)
	return MapGlyphs.boost(c, NODE_LIFT)


## Which icon a node type wears.
static func kind_of(t: MapGen.NodeType) -> StringName:
	match t:
		MapGen.NodeType.START: return &"start"
		MapGen.NodeType.STATION: return &"station"
		MapGen.NodeType.PULSAR: return &"pulsar"
		MapGen.NodeType.CORE: return &"core"
	return &"system"


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


## A node's icon centred on `cp`: `size` 9 or 7 (the core is always the sector's 11); a system of two
## suns (`twin`) wears the twin.
static func draw_node(ci: CanvasItem, t: MapGen.NodeType, cp: Vector2, size: int, main: Color,
		under: Color, flat := false, twin := false) -> void:
	var kind := kind_of(t)
	if twin and kind == &"system":
		kind = &"twin"
	var key := "core" if kind == &"core" else "%s%d" % [kind, size]
	var half := (MapGlyphs.SIZE if kind == &"core" else size) / 2
	_draw(ci, key, cp, Vector2i(half, half), main, under, flat)


## A marker on the star at `cp`: &"quest" (the sector's pin, standing on it), &"hellbender", &"party".
## Its colour boosted as the sector's beacons are.
static func draw_mark(ci: CanvasItem, name: StringName, cp: Vector2, main: Color, under: Color) -> void:
	var ink := MapGlyphs.boost(main)
	if name == &"quest":
		_draw(ci, "quest", cp, PIN_AT, ink, under, false)
		return
	var rows: Array = MARK[name]
	var half: int = rows.size() / 2
	_draw(ci, String(name), cp, Vector2i(half, half), ink, under, false)


## YOU's brackets round the star at `cp`.
static func draw_you(ci: CanvasItem, cp: Vector2, half: int, main: Color, under: Color) -> void:
	_draw(ci, "you%d" % half, cp, Vector2i(half, half), MapGlyphs.boost(main), under, false)


## The centre pixel the chart draws a mark on, for a star at `at`: the old 13 px glyph's middle.
static func centre(at: Vector2) -> Vector2:
	return (at - Vector2(6, 6)).round() + Vector2(6, 6)
