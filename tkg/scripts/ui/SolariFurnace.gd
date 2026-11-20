class_name SolariFurnace
extends RefCounted

## Solari's furnace light, live (Jon, Nov 20, idea C): embers and sparks behind the grate,
## flare-ups filling the line both ways, the cab's glass flickering on a worn hull; a C
## sputters, an S burns on the beat. Why: docs/why/SolariFurnace.md#furnace-light

const PART_DISC := 1
const PART_FWD := 2
const PART_AFT := 3
const PART_LENS := 4
const PART_GLASS := 5
const RAMP_W := 32
const SHADER := preload("res://shaders/solari_furnace.gdshader")

var size := Vector2i.ZERO
var data: ImageTexture
var ramps: ImageTexture
var ramp_n := Vector3i.ONE
var fwd_len := 1.0
var aft_len := 1.0
var lens_s := 1.0
var centre := Vector2.ZERO
var radii := Vector2.ONE
var seed := 0
## Halo pixels round the furnace's rim and the lens, two rings, dithered once.
var halo_rim: PackedVector2Array = []
var halo_rim2: PackedVector2Array = []
var halo_lens: PackedVector2Array = []

static var _cache := {}


## The furnace for a graded hull key ("solari/hull_medium_zero"), or null for a hull without one.
static func of(key: String, src: Texture2D) -> SolariFurnace:
	if _cache.has(key):
		return _cache[key]
	var f: SolariFurnace = null
	var at := HullGrade.places(key)
	if at.has("lit") and src != null and (at.lit as Dictionary).has("glass"):
		f = SolariFurnace.new()
		f._build(src, at.lit, key)
	_cache[key] = f
	return f


static func material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	return m


# ------------------------------------------------------------------ the light map

func _build(src: Texture2D, lit: Dictionary, key: String) -> void:
	var img := src.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	size = img.get_size()
	seed = absi(key.hash()) % 9973
	var map := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var disc: Array = (lit.discs as Array)[0]
	centre = Vector2(float(disc[0]), float(disc[1]))
	radii = Vector2(float(disc[2]), float(disc[3]))
	var groups := {0: {}, 1: {}, 2: {}}
	for y in size.y:
		for x in size.x:
			var c := img.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			var q := (Vector2(x, y) - centre) / radii
			var rad := q.length()
			if rad <= 1.0 and HullGrade.luma(c) > 0.08:
				_mark(map, x, y, PART_DISC, rad * 200.0, c)
				groups[0][HullGrade.key(c)] = c
	var lines: Array = lit.lines
	fwd_len = _line(map, img, _path(lines[1], false), PART_FWD, groups[1])
	aft_len = _line(map, img, _path(lines[0], true), PART_AFT, groups[1])
	lens_s = fwd_len + 4.0
	var lb: Array = (lit.boxes as Array)[1]
	for y in range(int(lb[1]), int(lb[1]) + int(lb[3])):
		for x in range(int(lb[0]), int(lb[0]) + int(lb[2])):
			var c := img.get_pixel(x, y)
			if c.a > 0.0 and HullGrade.luma(c) > 0.33:
				_mark(map, x, y, PART_LENS, 0.0, c)
				groups[1][HullGrade.key(c)] = c
	for g: Array in lit.glass:
		for x in range(int(g[0]), int(g[0]) + int(g[2])):
			var c := img.get_pixel(x, int(g[1]))
			_mark(map, x, int(g[1]), PART_GLASS, 0.0, c)
			groups[2][HullGrade.key(c)] = c
	data = ImageTexture.create_from_image(map)
	_ramps(groups)
	_halos(map)


func _mark(map: Image, x: int, y: int, part: int, g: float, c: Color) -> void:
	map.set_pixel(x, y, Color8(part * 40, clampi(int(round(g)), 0, 255), int(round(HullGrade.luma(c) * 255.0)), 255))


## A line's points from the furnace outward: the forward line as listed, the aft one reversed.
func _path(pts: Array, aft: bool) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i in range(pts.size() - 1):
		var a: Array = pts[i]
		var b: Array = pts[i + 1]
		var last := i == pts.size() - 2
		for x in range(int(a[0]), int(b[0]) + (1 if last else 0)):
			var tt := 0.0 if int(b[0]) == int(a[0]) else float(x - int(a[0])) / float(int(b[0]) - int(a[0]))
			out.append(Vector2i(x, int(round(lerpf(float(a[1]), float(b[1]), tt)))))
	if aft:
		out.reverse()
	return out


## Marks a line's shining pixels with their distance from the furnace; returns its length.
func _line(map: Image, img: Image, path: Array[Vector2i], part: int, group: Dictionary) -> float:
	for k in path.size():
		for y in range(path[k].y - 1, path[k].y + 3):
			var x := path[k].x
			if y < 0 or y >= size.y:
				continue
			var c := img.get_pixel(x, y)
			var warm := c.r > c.b + 20.0 / 255.0 or HullGrade.luma(c) > 0.8
			if c.a > 0.0 and HullGrade.luma(c) > 0.33 and warm:
				_mark(map, x, y, part, float(k), c)
				group[HullGrade.key(c)] = c
	return float(path.size())


## Each part's colours dark to light, the most saturated at each lightness step, and white-hot.
func _ramps(groups: Dictionary) -> void:
	var img := Image.create(RAMP_W, 6, false, Image.FORMAT_RGBA8)
	var counts: Array[int] = []
	for gi in 3:
		var buckets := {}
		for c: Color in (groups[gi] as Dictionary).values():
			var b := int(HullGrade.luma(c) / 0.045)
			if not buckets.has(b) or c.s > (buckets[b] as Color).s:
				buckets[b] = c
		var keys := buckets.keys()
		keys.sort()
		var cols: Array[Color] = []
		for b: int in keys:
			cols.append(buckets[b])
		if cols.size() >= RAMP_W:
			cols.resize(RAMP_W - 1)
		cols.append(Color8(255, 250, 238))
		for i in cols.size():
			img.set_pixel(i, gi * 2, cols[i])
			var l := HullGrade.luma(cols[i])
			img.set_pixel(i, gi * 2 + 1, Color(l, l, l))
		counts.append(cols.size())
	ramp_n = Vector3i(counts[0], counts[1], counts[2])
	ramps = ImageTexture.create_from_image(img)


func _halos(map: Image) -> void:
	var rim := {}
	var lensp := {}
	for y in size.y:
		for x in size.x:
			var c := map.get_pixel(x, y)
			var part := int(round(c.r8 / 40.0))
			if part == PART_DISC and c.g8 > 164:
				rim[Vector2i(x, y)] = true
			elif part == PART_LENS:
				lensp[Vector2i(x, y)] = true
	var lit := func(p: Vector2i) -> bool: return p.x >= 0 and p.y >= 0 and p.x < size.x and p.y < size.y and map.get_pixel(p.x, p.y).a > 0.0
	var r1 := _grow(rim, lit)
	var both := rim.duplicate()
	for p: Vector2i in r1:
		both[p] = true
	var r2 := _grow(both, lit)
	for p: Vector2i in r1:
		if _on(p):
			halo_rim.append(Vector2(p))
	for p: Vector2i in r2:
		if not r1.has(p) and _on(p):
			halo_rim2.append(Vector2(p))
	for p: Vector2i in _grow(lensp, lit):
		if _on(p):
			halo_lens.append(Vector2(p))


func _grow(s: Dictionary, lit: Callable) -> Dictionary[Vector2i, bool]:
	var out: Dictionary[Vector2i, bool] = {}
	for p: Vector2i in s:
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q := p + d
			if not s.has(q) and not lit.call(q):
				out[q] = true
	return out


## The halo's dither: three of every four pixels, fixed.
static func _on(p: Vector2i) -> bool:
	return float(HullWear.BAYER[p.y % 4][p.x % 4]) / 16.0 < 0.75


# --------------------------------------------------------------- the behaviour

## 0 at S, 1 at C: how far from controlled the furnace is.
static func chaos(grade: int) -> float:
	return [1.0, 0.6, 0.25, 0.0][clampi(grade, 0, 3)]


func _h(a: int, b: int, c: int = 0) -> float:
	return HullGrade.noise(a * 131 + c, b, seed + 17)


## The flare-ups that can still be seen at `t`: [start, strength, forward reach, aft reach].
func flares(grade: int, t: float) -> Array[Vector4]:
	var ch := chaos(grade)
	var per := lerpf(1.4, 0.9, ch)
	var out: Array[Vector4] = []
	var k0 := floori((t - 3.0) / per)
	for k in range(k0, floori(t / per) + 1):
		var t0 := float(k) * per + 0.2 + (_h(k, 1) - 0.5) * per * 0.9 * ch
		if _h(k, 2) < 0.15 * ch:
			continue
		var r := _h(k, 3)
		var amp := 1.0
		var fwd := 1e6
		var aft := 1e6
		if r < 0.3 * ch:
			# a misfire: weak, and dying partway, each way on its own
			amp = 0.35
			fwd = fwd_len * (0.25 + 0.5 * _h(k, 4))
			aft = aft_len * (0.25 + 0.5 * _h(k, 5))
		elif r > 1.0 - 0.2 * ch:
			amp = 1.25
		if amp >= 1.0:
			if _h(k, 6) < 0.25 * ch:
				fwd = fwd_len * (0.3 + 0.6 * _h(k, 7))
			if _h(k, 8) < 0.25 * ch:
				aft = aft_len * (0.3 + 0.6 * _h(k, 9))
		if t0 <= t:
			out.append(Vector4(t0, amp, fwd, aft))
		if _h(k, 10) < 0.35 * ch and t0 + 0.16 <= t:
			# a double cough
			out.append(Vector4(t0 + 0.16, amp * 0.7, fwd, aft))
	while out.size() > 12:
		out.remove_at(0)
	return out


## The furnace's flare at `t`: an eased rise, a hold at S, a fall.
func flare_level(grade: int, t: float, fs: Array[Vector4]) -> float:
	var ch := chaos(grade)
	var rise := lerpf(0.12, 0.05, ch)
	var hold := lerpf(0.2, 0.0, ch)
	var fall := lerpf(0.45, 0.22, ch)
	var v := 0.0
	for f in fs:
		var u := t - f.x
		var e := 0.0
		if u < rise:
			var q := u / rise
			e = q * q * (3.0 - 2.0 * q)
		elif u < rise + hold:
			e = 1.0
		else:
			e = exp(-(u - rise - hold) / fall)
		v = maxf(v, f.y * e)
	return v


func speed(grade: int) -> float:
	return lerpf(240.0, 160.0, chaos(grade))


## The cab's glass: steady on a good hull; on a worn one, dips and now and then a stutter.
func glass_level(grade: int, t: float) -> float:
	if grade >= 2:
		return 1.0
	var k := floori(t / 1.3)
	var at := _h(k, 41) * 1.0
	var u := t - float(k) * 1.3
	if u > at and u < at + 0.12:
		return 0.5
	if grade == 1:
		return 1.0
	var k2 := floori(t / 3.1)
	var at2 := _h(k2, 43) * 2.4
	var u2 := t - float(k2) * 3.1
	if u2 > at2 and u2 < at2 + 0.45:
		return 0.25 if int((u2 - at2) * 12.0) % 2 == 0 else 1.0
	return 0.9 + 0.1 * _h(floori(t * 10.0), 47)


## Sparks rising in the furnace, in the art's pixels.
func sparks(grade: int, t: float) -> PackedVector2Array:
	var ch := chaos(grade)
	var out := PackedVector2Array()
	var n := int(round(lerpf(14.0, 22.0, ch)))
	for i in n:
		var life := lerpf(0.6, 0.3 + 0.5 * _h(i, 111), ch)
		var per := life + lerpf(0.2, 0.6 * _h(i, 112), ch)
		var cyc := floori((t + i * 0.37) / per)
		var u := (t + i * 0.37) - float(cyc) * per
		if u > life or _h(i, 113, cyc) < 0.3 * ch:
			continue
		var ang := _h(i, 114, cyc) * TAU
		var r0 := 0.6 * _h(i, 115, cyc)
		var vy := lerpf(0.9, 0.6 + 1.0 * _h(i, 116, cyc), ch) * radii.y * 1.4
		var drift := lerpf(sin(u * 9.0 + i) * 1.5, (_h(i, 117, floori(u * 12.0)) - 0.5) * 5.0, ch)
		var p := Vector2(round(centre.x + cos(ang) * r0 * radii.x + drift), round(centre.y + 0.6 * radii.y - vy * u))
		if ((p - centre) / radii).length() < 0.95:
			out.append(p)
	return out


## Everything the shader needs at `t`, set on `mat`.
func apply(mat: ShaderMaterial, grade: int, t: float) -> void:
	var ch := chaos(grade)
	var fs := flares(grade, t)
	var fl := flare_level(grade, t, fs)
	var sp := speed(grade)
	var lens := 0.0
	for f in fs:
		var u := t - f.x - lens_s / sp
		if u >= 0.0 and f.z >= lens_s:
			lens = maxf(lens, f.y * exp(-u / 0.25))
	var arr: Array[Vector4] = fs.duplicate()
	while arr.size() < 12:
		arr.append(Vector4(1e6, 0, 0, 0))
	var spk := sparks(grade, t)
	var spk_n := mini(spk.size(), 24)
	while spk.size() < 24:
		spk.append(Vector2(-9, -9))
	spk.resize(24)
	mat.set_shader_parameter("ramps", ramps)
	mat.set_shader_parameter("ramp_n", ramp_n)
	mat.set_shader_parameter("size", Vector2(size))
	mat.set_shader_parameter("t", t)
	mat.set_shader_parameter("flares", arr)
	mat.set_shader_parameter("flare_n", fs.size())
	mat.set_shader_parameter("sparks", spk)
	mat.set_shader_parameter("spark_n", spk_n)
	mat.set_shader_parameter("fl", fl)
	mat.set_shader_parameter("lens", lens)
	mat.set_shader_parameter("glass", glass_level(grade, t))
	mat.set_shader_parameter("fwd_len", fwd_len)
	mat.set_shader_parameter("aft_len", aft_len)
	mat.set_shader_parameter("speed", sp)
	mat.set_shader_parameter("line_hold", lerpf(0.15, 0.0, ch))
	mat.set_shader_parameter("line_decay", lerpf(0.4, 0.2, ch))
	mat.set_shader_parameter("base_lvl", lerpf(0.5, 0.42, ch))
	mat.set_shader_parameter("bed_k", lerpf(0.6, 1.0, ch))


## The furnace drawn into `ci` (its material this shader's), the picture's pixels at `scale`.
func draw(ci: CanvasItem, grade: int, t: float, scale: float) -> void:
	var mat := ci.material as ShaderMaterial
	if mat == null:
		return
	apply(mat, grade, t)
	ci.draw_texture_rect(data, Rect2(Vector2.ZERO, Vector2(size) * scale), false)


## The light thrown round the rim and the lens, added with the hull's lights.
func draw_halo(ci: CanvasItem, grade: int, t: float, scale: float) -> void:
	var fs := flares(grade, t)
	var fl := flare_level(grade, t, fs)
	var warm := Color(1.0, 0.59, 0.24)
	if fl > 0.02:
		var a1 := warm * (0.30 * minf(1.5, fl * 1.1))
		var a2 := warm * (0.14 * minf(1.5, fl * 1.1))
		for p in halo_rim:
			ci.draw_rect(Rect2(p * scale, Vector2(scale, scale)), a1)
		for p in halo_rim2:
			ci.draw_rect(Rect2(p * scale, Vector2(scale, scale)), a2)
	var sp := speed(grade)
	var lens := 0.0
	for f in fs:
		var u := t - f.x - lens_s / sp
		if u >= 0.0 and f.z >= lens_s:
			lens = maxf(lens, f.y * exp(-u / 0.25))
	if lens > 0.02:
		var al := warm * (0.30 * minf(1.5, lens))
		for p in halo_lens:
			ci.draw_rect(Rect2(p * scale, Vector2(scale, scale)), al)
