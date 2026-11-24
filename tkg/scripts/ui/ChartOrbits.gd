class_name ChartOrbits
extends Control

## THE DESTINATION'S ORBITS (Jon, Nov 22, "2: B"): a small map of a picked system on the star
## chart's panel, the star at the left edge and one arc per orbit. Read off `SystemLayout.of`, the
## seed the sector map draws on arrival, and only what that fixes: no events, no comet, no contacts.
## Why: docs/why/ChartOrbits.md#what-it-shows

const SystemViewS := preload("res://scripts/ui/sysmap/SystemView.gd")
const W := 228
const H := 72
## Arcs and the warm hot line, in the panel's own colours.
const ARC := Color("#3a4a5e")
const BELT := UITheme.CHILL
const WORLD := Color("#a9b6c4")
const GIANT := Color("#c7b79a")
const GIANT_BAND := Color("#8d7f68")
const WRECK := Color("#9a7550")
const WRECK_LIT := Color("#d0a070")
const SUN_B := Color("#f0a860")
## The words the counts line uses, singular and plural, in the order it says them.
const NOUNS := [[&"planet", "PLANET", "PLANETS"], [&"giant", "GIANT", "GIANTS"],
	[&"belt", "BELT", "BELTS"], [&"station", "STATION", "STATIONS"],
	[&"wreck", "WRECK", "WRECKS"], [&"job", "JOB", "JOBS"]]

## WHICH PICTURE (dev switch, Jon, Nov 23: "a couple versions"): `arcs` today's; `orrery` top
## down, full rings, each world where it is; `lineup` one line out from the star, sized by kind;
## `arrival` the map you jump into, small. Why: docs/why/ChartOrbits.md#looks
const LOOKS: Array[StringName] = [&"arcs", &"orrery", &"lineup", &"arrival"]
static var look: StringName = &"arcs"

## What is drawn: each a kind, an orbit in layout px, the star it circles and its phase.
var marks: Array[Dictionary] = []
var star: SystemLayout.StarKind = SystemLayout.StarKind.ORDINARY
var star_col: Color = Color.WHITE
var twin := false
## The layout drawn, for the star's picture above the map (`StarchartScreen._paint_star`).
var layout: SystemLayout = null
var _index := -1
## Built once in `show_system`, never in `_draw`: each arc's pixels, the belt's and the hot line's.
var _arcs: Array[PackedVector2Array] = []
var _belts: Array[PackedVector2Array] = []
var _spots: Array[Vector2] = []
var _scale := 1.0
var _pulsar_px := PackedVector2Array()
var _pulsar_col := PackedColorArray()
## The other looks' parts: dots in one colour each, each mark's size and colour, the suns.
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


func _build() -> void:
	_arcs.clear()
	_belts.clear()
	_spots.clear()
	_dots.clear()
	_sizes.clear()
	_cols.clear()
	_suns.clear()
	_pulsar_px = PackedVector2Array()
	_pulsar_col = PackedColorArray()
	match look:
		&"orrery":
			_build_orrery()
			return
		&"lineup":
			_build_lineup()
			return
		&"arrival":
			_build_arrival()
			return
	# Linear in AU, so the hot line sits where it does against the orbits.
	var far := SystemLayout.ZONE_NEAR * 1.2
	for d in marks:
		far = maxf(far, float(d.orbit))
	_scale = (W - 8.0) / far
	var cy := H * 0.5
	for d in marks:
		# a world round one sun of a pair is drawn beside that sun, not on an arc
		if twin and int(d.host) != -9:
			_spots.append(_sun_at(int(d.host)) + Vector2(12, 0))
			continue
		var r := float(d.orbit) * _scale
		var a_max := asin(clampf((cy - 8.0) / r, 0.0, 1.0))
		var th := a_max * sin(float(d.phase))
		_spots.append(Vector2(roundf(r * cos(th)), roundf(cy + r * sin(th))))
		if d.kind == &"belt":
			_belts.append(_arc(r, 3))
		else:
			_arcs.append(_arc(r, 1))
	_pulsar_px = PackedVector2Array()
	_pulsar_col = PackedColorArray()
	if star == SystemLayout.StarKind.PULSAR:
		pulsar_pixels(Vector2(6, roundf(H * 0.5)), MapGlyphs.boost(star_col, ChartGlyphs.NODE_LIFT),
			1, 6, _pulsar_px, _pulsar_col)


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


## Where sun `host` sits on the left edge: one sun in the middle, a pair one above the other.
func _sun_at(host: int) -> Vector2:
	if not twin:
		return Vector2(0, H * 0.5)
	return Vector2(0, H * 0.5 + (10.0 if host == SystemLayout.STAR_B else -10.0))


## The pixels of an arc of radius `r` round the left edge's middle, every `every`th one.
func _arc(r: float, every: int) -> PackedVector2Array:
	var seen := {}
	var out := PackedVector2Array()
	var cy := H * 0.5
	var steps := maxi(8, int(r * PI))
	var k := 0
	for i in steps + 1:
		var a := -PI * 0.5 + PI * float(i) / float(steps)
		var p := Vector2i(roundi(r * cos(a)), roundi(cy + r * sin(a)))
		if p.x < 0 or p.y < 1 or p.y > H - 2 or seen.has(p):
			continue
		seen[p] = true
		if k % every == 0:
			out.append(Vector2(p))
		k += 1
	return out


func _draw() -> void:
	if look != &"arcs":
		_draw_look()
		return
	for arc in _arcs:
		for p in arc:
			draw_rect(Rect2(p, Vector2.ONE), ARC, true)
	for arc in _belts:
		for p in arc:
			draw_rect(Rect2(p, Vector2.ONE), BELT, true)
	_draw_star()
	for i in marks.size():
		_draw_mark(StringName(marks[i].kind), _spots[i])


func _draw_star() -> void:
	if star == SystemLayout.StarKind.PULSAR:
		for i in _pulsar_px.size():
			draw_rect(Rect2(_pulsar_px[i], Vector2.ONE), _pulsar_col[i], true)
		return
	var r := {SystemLayout.StarKind.RED: 7, SystemLayout.StarKind.BLUE: 5}.get(star, 4) as int
	if twin:
		_half_disc(_sun_at(-1), 4, star_col)
		_half_disc(_sun_at(SystemLayout.STAR_B), 3, SUN_B)
		return
	_half_disc(_sun_at(-1), r, star_col)


## A sun cut by the panel's left edge, as the mock has it.
func _half_disc(c: Vector2, r: int, col: Color) -> void:
	for y in range(-r, r + 1):
		var w := int(floor(sqrt(float(r * r - y * y)) + 0.5))
		if w > 0:
			draw_rect(Rect2(c.x, c.y + y, w, 1), col, true)


func _draw_mark(kind: StringName, p: Vector2) -> void:
	match kind:
		&"planet":
			_disc(p, 3, WORLD)
		&"giant":
			_disc(p, 5, GIANT)
			draw_rect(Rect2(p.x - 5, p.y - 1, 11, 1), GIANT_BAND, true)
			draw_rect(Rect2(p.x - 4, p.y + 2, 9, 1), GIANT_BAND, true)
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


## A small round world on a dark rim, so it reads across an arc.
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


## Marks round the stars themselves (one sun, or both of a pair), nearest first.
func _main_order() -> Array[int]:
	var out: Array[int] = []
	for i in marks.size():
		if not twin or int(marks[i].host) == -9:
			out.append(i)
	out.sort_custom(func(a: int, b: int) -> bool: return float(marks[a].orbit) < float(marks[b].orbit))
	return out


## Each mark's place filled in by the look; every mark gets one, a size and a colour.
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


## A: TOP DOWN. The star in the middle, a full ring per orbit spaced by order, each world at
## the angle it has on its orbit as the map opens (`t_drawn`); a world round one sun of a pair
## beside that sun, at its angle.
func _build_orrery() -> void:
	_fill_marks()
	var c := Vector2(roundf(W * 0.5), roundf(H * 0.5))
	var t := t_drawn
	var bc: Vector2 = layout.bary if twin else Vector2.ZERO
	var sun_px := {}
	if star == SystemLayout.StarKind.PULSAR:
		pulsar_pixels(c, MapGlyphs.boost(star_col, ChartGlyphs.NODE_LIFT), 1, 5, _pulsar_px, _pulsar_col)
	elif twin:
		for p in layout.stars():
			var dir := layout.star_pos(p, t) - bc
			dir = Vector2(-1 if p == -1 else 1, 0) if dir.length() < 0.01 else dir.normalized()
			var sp := (c + dir * 8.0).round()
			sun_px[p] = sp
			_suns.append({c = sp, r = 3 if p == -1 else 2, col = star_col if p == -1 else SUN_B, half = false})
	else:
		_suns.append({c = c, r = _sun_r(), col = star_col, half = false})
	var order := _main_order()
	var r0 := 17.0 if twin else float(_sun_r()) + 6.0
	var rmax := H * 0.5 - 4.0
	var step := minf(7.0, (rmax - r0) / float(maxi(order.size() - 1, 1)))
	for k in order.size():
		var i := order[k]
		var b := _body_of(marks[i])
		var r := r0 + step * float(k)
		var a := (b.pos(t) - b.host_at(t)).angle()
		_spots[i] = (c + Vector2(cos(a), sin(a)) * r).round()
		var belt: bool = marks[i].kind == &"belt"
		_dots.append({px = _ring(c, r, r, 3 if belt else 1), col = BELT if belt else ARC})
	for i in marks.size():
		var b := _body_of(marks[i])
		if twin and int(marks[i].host) != -9:
			var a2 := (b.pos(t) - b.host_at(t)).angle()
			var s0: Vector2 = sun_px.get(int(marks[i].host), c)
			_spots[i] = (s0 + Vector2(cos(a2), sin(a2)) * 5.0).round()
		_sizes[i] = 3 if marks[i].kind == &"giant" else 2
		_cols[i] = _world_col(b, GIANT if marks[i].kind == &"giant" else WORLD)


## B: A LINEUP. The star at the left edge, one line out from it, the worlds on it in orbit
## order, each drawn at its own size and colour: a giant big, a rock small, a belt a column of dots.
func _build_lineup() -> void:
	_fill_marks()
	var cy := roundf(H * 0.5)
	if star == SystemLayout.StarKind.PULSAR:
		pulsar_pixels(Vector2(6, cy), MapGlyphs.boost(star_col, ChartGlyphs.NODE_LIFT), 1, 6, _pulsar_px, _pulsar_col)
	elif twin:
		_suns.append({c = _sun_at(-1), r = 4, col = star_col, half = true})
		_suns.append({c = _sun_at(SystemLayout.STAR_B), r = 3, col = SUN_B, half = true})
	else:
		_suns.append({c = Vector2(0, cy), r = _sun_r() + 1, col = star_col, half = true})
	var order := _main_order()
	var x0 := float(_sun_r()) + 16.0
	var x1 := W - 10.0
	var line := PackedVector2Array()
	for x in range(int(x0) - 6, int(x1) + 1):
		line.append(Vector2(x, cy))
	_dots.append({px = line, col = ARC})
	for k in order.size():
		var i := order[k]
		var f := 0.5 if order.size() == 1 else float(k) / float(order.size() - 1)
		_spots[i] = Vector2(roundf(lerpf(x0, x1, f)), cy)
	var beside := {}
	for i in marks.size():
		var b := _body_of(marks[i])
		if twin and int(marks[i].host) != -9:
			var h := int(marks[i].host)
			var n := int(beside.get(h, 0))
			beside[h] = n + 1
			_spots[i] = _sun_at(h) + Vector2(11 + 9 * n, 0)
		match marks[i].kind:
			&"giant":
				_sizes[i] = clampi(roundi(b.r * 0.45), 5, 7)
			&"planet":
				_sizes[i] = clampi(roundi(b.r * 0.3), 2, 4)
		_cols[i] = _world_col(b, GIANT if marks[i].kind == &"giant" else WORLD)
		if marks[i].kind == &"belt":
			var col := PackedVector2Array()
			var p: Vector2 = _spots[i]
			for j in range(-4, 5):
				col.append(p + Vector2((j * 5 % 3) - 1, j * 2))
			_dots.append({px = col, col = BELT})


## C: THE MAP YOU ARRIVE IN, SMALL. The sector map's own projection (`SystemView.screen`: x across,
## the plane tilted to `TILT`), the whole system fitted, its orbits as the map draws them, each
## world where it is as the map opens and in its own colour.
func _build_arrival() -> void:
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
				col = SUN_B if two else star_col, half = false})


func _draw_look() -> void:
	for dd in _dots:
		for p in dd.px:
			draw_rect(Rect2(p, Vector2.ONE), dd.col, true)
	for i in _pulsar_px.size():
		draw_rect(Rect2(_pulsar_px[i], Vector2.ONE), _pulsar_col[i], true)
	for sn in _suns:
		if sn.half:
			_half_disc(sn.c, sn.r, sn.col)
		else:
			_full_disc(sn.c, sn.r, sn.col)
	for i in marks.size():
		var kind := StringName(marks[i].kind)
		if kind == &"planet" or kind == &"giant":
			_disc(_spots[i], _sizes[i], _cols[i])
			if kind == &"giant" and _sizes[i] >= 4:
				var p: Vector2 = _spots[i]
				var s := _sizes[i]
				draw_rect(Rect2(p.x - s, p.y - 1, 2 * s + 1, 1), _cols[i].darkened(0.3), true)
		elif kind != &"belt":
			_draw_mark(kind, _spots[i])


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
