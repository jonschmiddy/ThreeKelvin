class_name ChartOrbits
extends Control

## THE DESTINATION'S ORBITS (Jon, Nov 22, "2: B"): a small map of a picked system on the star
## chart's panel: the sector map you arrive in, small (Nov 23). Read off `SystemLayout.of`, the
## seed the sector map draws on arrival, and only what that fixes: no events, no comet, no contacts.
## Why: docs/why/ChartOrbits.md#what-it-shows

const SystemViewS := preload("res://scripts/ui/sysmap/SystemView.gd")
const W := 228
const H := 72
## Orbits and belts, in the panel's own colours.
const ARC := Color("#3a4a5e")
const BELT := UITheme.CHILL
const WORLD := Color("#a9b6c4")
const GIANT := Color("#c7b79a")
const WRECK := Color("#9a7550")
const WRECK_LIT := Color("#d0a070")
const SUN_B := Color("#f0a860")
## The words the counts line uses, singular and plural, in the order it says them.
const NOUNS := [[&"planet", "PLANET", "PLANETS"], [&"giant", "GIANT", "GIANTS"],
	[&"belt", "BELT", "BELTS"], [&"station", "STATION", "STATIONS"],
	[&"wreck", "WRECK", "WRECKS"], [&"job", "JOB", "JOBS"]]

## What is drawn: each a kind, an orbit in layout px, the star it circles and its phase.
var marks: Array[Dictionary] = []
var star: SystemLayout.StarKind = SystemLayout.StarKind.ORDINARY
var star_col: Color = Color.WHITE
var twin := false
## The layout drawn, for the star's picture above the map (`StarchartScreen._paint_star`).
var layout: SystemLayout = null
var _index := -1
## Built once in `show_system`, never in `_draw`: each mark's place, size and colour, the
## orbits' and belts' dots in one colour each, the suns and a pulsar's pixels.
var _spots: Array[Vector2] = []
var _pulsar_px := PackedVector2Array()
var _pulsar_col := PackedColorArray()
var _dots: Array[Dictionary] = []
var _sizes: Array[int] = []
var _cols: Array[Color] = []
var _suns: Array[Dictionary] = []
## The map time drawn (`Run.map_t`): where the worlds are as the map opens on arrival.
var t_drawn := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## The orbits of `L` as the map will draw them on arrival: planets, giants, belts, stations,
## wrecks, and a signed job's place. Contacts are fights (events) and the comet is per visit.
static func read(L: SystemLayout, n: MapGen.MapNode) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for bi in L.bodies.size():
		var b: SystemLayout.Body = L.bodies[bi]
		var kind := b.kind
		var job := false
		for bc in b.beacons:
			if bc.opt >= 0 and bc.opt < n.options.size() and OptionTable.is_job(n.options[bc.opt]):
				job = true
		if job:
			kind = &"job"
		elif kind == &"contact":
			continue
		elif kind == &"derelict":
			kind = &"wreck"
		out.append({kind = kind, orbit = b.orbit, host = b.host_id if L.twin else -1,
			phase = b.phase, body = bi})
	return out


## "3 PLANETS · 1 GIANT · 1 BELT", in `NOUNS`' order.
static func counts(m: Array[Dictionary]) -> String:
	var parts: Array[String] = []
	for noun in NOUNS:
		var k := 0
		for d in m:
			if d.kind == noun[0]:
				k += 1
		if k > 0:
			parts.append("%d %s" % [k, noun[1] if k == 1 else noun[2]])
	return " · ".join(parts)


## One line a test compares before the jump and after it: star, pair, and every orbit.
static func signature(L: SystemLayout, n: MapGen.MapNode) -> String:
	var parts: Array[String] = ["%d%s" % [L.star, " twin" if L.twin else ""]]
	for d in read(L, n):
		parts.append("%s@%.1f/%d" % [d.kind, float(d.orbit), int(d.host)])
	return " ".join(parts)


## Lay the picture out for node `n`.
func show_system(n: MapGen.MapNode) -> void:
	var L := SystemLayout.of(n)
	layout = L
	_index = n.index
	marks = read(L, n)
	star = L.star
	twin = L.twin
	star_col = MapGen.star_colour(n)
	t_drawn = Run.map_t(n.index)
	_build()
	queue_redraw()


## The system shown (its node index), -1 before any.
func shown() -> int:
	return _index


## One of the star's facts (`kind`, `radius`, `mass`, `temp`, `lum`), the sector panel's own
## (`SystemView.star_facts_of`, this system's numbers).
func fact(key: String) -> String:
	return String(SystemViewS.star_facts_of(null, kind_name(), -1, _index).get(key, ""))


## The star's kind as the sector map names it (`SystemView.KIND_NAMES`).
func kind_name() -> String:
	return String(SystemViewS.KIND_NAMES[star])


## A pair's second sun, as the sector panel names it.
static func second_sun() -> String:
	return String(SystemViewS.STAR_B_FACTS.kind)


## THE MAP YOU ARRIVE IN, SMALL (Jon, Nov 23: "C!!!"): the sector map's own projection
## (`SystemView.screen`: x across, the plane tilted to `TILT`), the whole system fitted, its
## orbits as the map draws them, each world where it is as the map opens and in its own colour.
## Why: docs/why/ChartOrbits.md#looks
func _build() -> void:
	_spots.clear()
	_dots.clear()
	_sizes.clear()
	_cols.clear()
	_suns.clear()
	_pulsar_px = PackedVector2Array()
	_pulsar_col = PackedColorArray()
	_fill_marks()
	var t := t_drawn
	var tilt: float = SystemViewS.TILT
	var c0: Vector2 = layout.bary if twin else Vector2.ZERO
	var ext := 10.0
	for b in layout.bodies:
		ext = maxf(ext, (b.host_at(t) - c0).length() + b.orbit)
	for p in layout.stars():
		ext = maxf(ext, (layout.star_pos(p, t) - c0).length())
	var k := minf((W - 12.0) / (2.0 * ext), (H - 10.0) / (2.0 * ext * tilt))
	var mid := Vector2(roundf(W * 0.5), roundf(H * 0.5))
	var scr := func(p: Vector2) -> Vector2: return (mid + Vector2(p.x - c0.x, (p.y - c0.y) * tilt) * k).round()
	for i in marks.size():
		var b := _body_of(marks[i])
		var hc: Vector2 = scr.call(b.host_at(t))
		var belt: bool = marks[i].kind == &"belt"
		_dots.append({px = _ring(hc, b.orbit * k, b.orbit * k * tilt, 3 if belt else 2), col = BELT if belt else ARC})
		_spots[i] = scr.call(b.pos(t))
		match marks[i].kind:
			&"giant":
				_sizes[i] = 4
			&"planet":
				_sizes[i] = clampi(roundi(b.r * 0.25), 2, 3)
		_cols[i] = _world_col(b, GIANT if marks[i].kind == &"giant" else WORLD)
	if star == SystemLayout.StarKind.PULSAR:
		pulsar_pixels(scr.call(Vector2.ZERO), MapGlyphs.boost(star_col, ChartGlyphs.NODE_LIFT), 1, 5, _pulsar_px, _pulsar_col)
	else:
		for p in layout.stars():
			var two := p == SystemLayout.STAR_B
			_suns.append({c = scr.call(layout.star_pos(p, t)), r = 3 if twin else _sun_r(),
				col = SUN_B if two else star_col})


## A pulsar in the chart's style: a bright point, two beams `reach` blocks long fading out on one
## diagonal, in `px`-pixel blocks; appended to `out` and `cols`.
static func pulsar_pixels(c: Vector2, ink: Color, px: int, reach: int, out: PackedVector2Array,
		cols: PackedColorArray) -> void:
	for k in range(2, reach + 1):
		var a := clampf(1.15 - float(k) / float(reach + 1), 0.25, 1.0)
		for sgn in [-1.0, 1.0]:
			out.append(c + Vector2(k, k) * sgn * px)
			cols.append(Color(ink, a))
	for d in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1), Vector2.ZERO]:
		out.append(c + d * px)
		cols.append(UITheme.ICE if d == Vector2.ZERO else ink)


func _draw() -> void:
	for dd in _dots:
		for p in dd.px:
			draw_rect(Rect2(p, Vector2.ONE), dd.col, true)
	for i in _pulsar_px.size():
		draw_rect(Rect2(_pulsar_px[i], Vector2.ONE), _pulsar_col[i], true)
	for sn in _suns:
		_full_disc(sn.c, sn.r, sn.col)
	for i in marks.size():
		var kind := StringName(marks[i].kind)
		if kind == &"planet" or kind == &"giant":
			_disc(_spots[i], _sizes[i], _cols[i])
			if kind == &"giant":
				var p: Vector2 = _spots[i]
				var s := _sizes[i]
				draw_rect(Rect2(p.x - s, p.y - 1, 2 * s + 1, 1), _cols[i].darkened(0.3), true)
		elif kind != &"belt":
			_draw_mark(kind, _spots[i])


func _draw_mark(kind: StringName, p: Vector2) -> void:
	match kind:
		&"station":
			ChartGlyphs.draw_node(self, MapGen.NodeType.STATION, p, ChartGlyphs.BIG,
				MapGlyphs.boost(UITheme.ICE, ChartGlyphs.NODE_LIFT), UITheme.VOID)
		&"wreck":
			# a broken hull lying on its orbit: a 2 px bar, lit along its top
			for k in 7:
				draw_rect(Rect2(p.x - 3 + k, p.y - 3 + k, 2, 2), WRECK, true)
				if k % 2 == 0:
					draw_rect(Rect2(p.x - 3 + k, p.y - 3 + k, 1, 1), WRECK_LIT, true)
		&"job":
			for y in range(-4, 5):
				var w := 4 - absi(y)
				draw_rect(Rect2(p.x - w, p.y + y, 1, 1), UITheme.FLARE, true)
				draw_rect(Rect2(p.x + w, p.y + y, 1, 1), UITheme.FLARE, true)
			draw_rect(Rect2(p.x - 1, p.y - 1, 3, 3), UITheme.HOT, true)


## A small round world on a dark rim, so it reads across an orbit.
func _disc(c: Vector2, r: int, col: Color) -> void:
	for y in range(-r - 1, r + 2):
		for x in range(-r - 1, r + 2):
			var d := x * x + y * y
			if d <= r * r + 1:
				draw_rect(Rect2(c.x + x, c.y + y, 1, 1), col, true)
			elif d <= (r + 1) * (r + 1) + 1:
				draw_rect(Rect2(c.x + x, c.y + y, 1, 1), UITheme.PANEL, true)


## The body behind mark `d`.
func _body_of(d: Dictionary) -> SystemLayout.Body:
	return layout.bodies[int(d.body)]


## Every mark gets a place, a size and a colour.
func _fill_marks() -> void:
	_spots.resize(marks.size())
	_sizes.resize(marks.size())
	_cols.resize(marks.size())
	for i in marks.size():
		_sizes[i] = 3
		_cols[i] = WORLD


## A world's own colour, the planet painter's ramp (`Worlds.RAMP`), light side.
func _world_col(b: SystemLayout.Body, fallback: Color) -> Color:
	if b.world == &"" or not Worlds.RAMP.has(b.world):
		return fallback
	return Color(Worlds.RAMP[b.world][4])


func _sun_r() -> int:
	return {SystemLayout.StarKind.RED: 6, SystemLayout.StarKind.BLUE: 5}.get(star, 4) as int


## The pixels of an ellipse round `c`, every `every`th one, inside the box.
func _ring(c: Vector2, rx: float, ry: float, every: int) -> PackedVector2Array:
	var seen := {}
	var out := PackedVector2Array()
	var steps := maxi(16, int((rx + ry) * PI))
	var k := 0
	for i in steps:
		var a := TAU * float(i) / float(steps)
		var p := Vector2i(roundi(c.x + rx * cos(a)), roundi(c.y + ry * sin(a)))
		if p.x < 0 or p.x >= W or p.y < 1 or p.y > H - 2 or seen.has(p):
			continue
		seen[p] = true
		if k % every == 0:
			out.append(Vector2(p))
		k += 1
	return out


func _full_disc(c: Vector2, r: int, col: Color) -> void:
	for y in range(-r, r + 1):
		var w := int(floor(sqrt(float(r * r - y * y)) + 0.5))
		draw_rect(Rect2(c.x - w, c.y + y, 2 * w + 1, 1), col, true)


## The pulsar's picture over the panel's list: `pulsar_pixels` in 2 px blocks, built once.
class PulsarPic extends Control:
	var _px := PackedVector2Array()
	var _cols := PackedColorArray()

	func setup(ink: Color, c: Vector2) -> void:
		ChartOrbits.pulsar_pixels(c, ink, 2, 11, _px, _cols)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		queue_redraw()

	func _draw() -> void:
		for i in _px.size():
			draw_rect(Rect2(_px[i] - Vector2.ONE, Vector2(2, 2)), _cols[i], true)
