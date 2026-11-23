class_name ChartOrbits
extends Control

## THE DESTINATION'S ORBITS (Jon, Nov 22, "2: B"): a small map of a picked system on the star
## chart's panel, the star at the left edge and one arc per orbit. Read off `SystemLayout.of`, the
## seed the sector map draws on arrival, and only what that fixes: no events, no comet, no contacts.
## Why: docs/why/ChartOrbits.md#what-it-shows

const SystemViewS := preload("res://scripts/ui/sysmap/SystemView.gd")
const W := 228
const H := 88
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

## What is drawn: each a kind, an orbit in layout px, the star it circles and its phase.
var marks: Array[Dictionary] = []
var star: SystemLayout.StarKind = SystemLayout.StarKind.ORDINARY
var star_col: Color = Color.WHITE
var twin := false
## The layout drawn, for the star's picture above the map (`StarchartScreen._paint_star`).
var layout: SystemLayout = null
## Built once in `show_system`, never in `_draw`: each arc's pixels, the belt's and the hot line's.
var _arcs: Array[PackedVector2Array] = []
var _belts: Array[PackedVector2Array] = []
var _spots: Array[Vector2] = []
var _scale := 1.0
var _pulsar_px := PackedVector2Array()
var _pulsar_col := PackedColorArray()


func _init() -> void:
	custom_minimum_size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## The orbits of `L` as the map will draw them on arrival: planets, giants, belts, stations,
## wrecks, and a signed job's place. Contacts are fights (events) and the comet is per visit.
static func read(L: SystemLayout, n: MapGen.MapNode) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for b in L.bodies:
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
			phase = b.phase})
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
	marks = read(L, n)
	star = L.star
	twin = L.twin
	star_col = MapGen.star_colour(n)
	_build()
	queue_redraw()


## One of the star's facts (`kind`, `radius`), the sector panel's own (`SystemView.STAR_FACTS`).
func fact(key: String) -> String:
	return String((SystemViewS.STAR_FACTS[SystemViewS.KIND_NAMES[star]] as Dictionary)[key])


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


## The pulsar's picture over the panel's list: `pulsar_pixels` in 2 px blocks, built once.
class PulsarPic extends Control:
	var _px := PackedVector2Array()
	var _cols := PackedColorArray()

	func setup(ink: Color, c: Vector2) -> void:
		ChartOrbits.pulsar_pixels(c, ink, 2, 14, _px, _cols)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		queue_redraw()

	func _draw() -> void:
		for i in _px.size():
			draw_rect(Rect2(_px[i] - Vector2.ONE, Vector2(2, 2)), _cols[i], true)
