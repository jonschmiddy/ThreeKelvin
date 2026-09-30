class_name YardLight
extends RefCounted

## One level's light in the Yard: the lamps `tools/yard_install.py` baked, the
## clocks they burn on, and the few questions about the light that are asked
## off the GPU.
##
## THE PAGE IS THE REFERENCE. The Yard Drones page (v46, the artifact Jon passed
## the Yard on) lights its hall in `lightWeights`, `syncStatic` and
## `shadeRange`; every function here names the one it ports. The pools were
## worked out ahead of time and live in the level's `.lmap` files -- what moves
## is how hard each light burns this tick, and that is all this hands the
## shader (`yard_light.gdshader`, four materials of it).
##
## THE CLOCKS ARE THE PAGE'S, LINE FOR LINE: a bulb with a bad contact buzzing,
## a loose one blinking, unclaimed's bad bulb popping in a shower of sparks,
## neon stuttering, gold breathing, the tired lamp over the crane striking back
## on. A beat changes a light's own pixels; only a light that really goes out
## takes its pool with it ("pulses dim bands, never move them").
##
## Asked off the GPU: the light at a point, for what is drawn after the light
## (the drones take the light over the ships' row, the flyers the hall's light
## as a whole, the deal TV the light at its feet) and for the dust, which shows
## only where a cone is bright.

const LW := 766
const LH := 482
const DIR := "res://art/sprites/station/yard/"
## The page's stepped light: sixths, smooth under the first one and a half.
const LSTEP := 1.0 / 6.0
const LSOFT := 1.5 / 6.0
## E4: a ceiling lamp flickers out and pops back on; E7's short knock is the
## other shape (unused since Jon cut the flyer that clipped a lamp).
const FLICK_LONG := [[0.0, 1.0], [0.1, 0.15], [0.2, 1.0], [0.32, 0.1], [0.45, 0.85], [0.52, 0.05],
	[2.0, 0.05], [2.05, 1.2], [2.2, 1.0]]

var level := ""
## The installed level (yard.json's `levels.<level>`).
var doc: Dictionary = {}
var hall: Texture2D
## The hall's pixels as installed, for what reads them (the stars, the lifts' shaft).
var hall_img: Image
var lights: Array = []
var nlights := 0
## Each light's weight this tick: `nw` its pool, `ew` its own pixels.
var nw := PackedFloat32Array()
var ew := PackedFloat32Array()
## The lamps a flicker can take out, by ceiling index.
var ceil_idx: Array = []
var tired := -1
var no_flicker := false
var main := Color(0.82, 0.9, 1.0)
var ambc := Color(0.7, 0.8, 1.0)
var amb := 0.1
var lship := PackedFloat32Array()
var dust_col := Color(1, 1, 1)
var dust_n := 56

## E4: which lamp is flickering and since when (-1 none).
var flk_lamp := -1
var flk_t0 := 0.0
## Unclaimed's bad bulb: when it last popped, how long it stays dark, when next.
var pop_k := -1
var pop_t0 := -99.0
var pop_off := 1.4
var pop_next := 1e9

## This tick's small lights: [cx, cy, rx, ry, k, colour, breathing].
var dyn: Array = []

var _light := PackedByteArray()
var _vary := PackedByteArray()
var _vary_w := LW
var _own := PackedByteArray()
var _bay := PackedByteArray()
var _bay_on := false
var _scale := 4.0
var _vscale := 2.0
const BSCALE := 2.0
const LSCALE := 2.0
## The variable lights' light indices, in band order.
var _vary_idx: Array[int] = []

var mats: Array[ShaderMaterial] = []
var _textures: Dictionary = {}


static func _read(name: String) -> Image:
	var path := DIR + name
	if name == "" or not FileAccess.file_exists(path):
		push_warning("yard: %s is missing -- run tools/yard_install.py" % path)
		return null
	var img := Image.new()
	if img.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
		push_warning("yard: could not read %s" % path)
		return null
	img.convert(Image.FORMAT_RGBA8)
	return img


## Load a level's light. False when it is not installed.
func load_level(lv: String, entry: Dictionary, dark: float) -> bool:
	level = lv
	doc = entry
	if doc.is_empty():
		return false
	var li := _read(String(doc.get("light", "")))
	var vi := _read(String(doc.get("vary", "")))
	var oi := _read(String(doc.get("own", "")))
	var fi := _read(String(doc.get("off", "")))
	if li == null or vi == null or oi == null or fi == null:
		return false
	hall = load(DIR + String(doc.get("picture", ""))) as Texture2D
	hall_img = hall.get_image() if hall != null else null
	if hall_img != null and hall_img.get_format() != Image.FORMAT_RGBA8:
		hall_img.convert(Image.FORMAT_RGBA8)
	_light = li.get_data()
	_vary = vi.get_data()
	_vary_w = vi.get_width()
	_own = oi.get_data()
	_scale = float(doc.get("scale", 4.0))
	_vscale = float(doc.get("vscale", 2.0))
	lights = doc.get("lights", [])
	nlights = lights.size()
	nw.resize(nlights)
	ew.resize(nlights)
	nw.fill(1.0)
	ew.fill(1.0)
	_vary_idx.clear()
	_vary_idx.resize(int(doc.get("nvary", 0)))
	for n in nlights:
		var b := int((lights[n] as Dictionary).get("band", -1))
		if b >= 0:
			_vary_idx[b] = n
	ceil_idx = doc.get("ceil", [])
	tired = int(doc.get("tired", -1))
	no_flicker = bool(doc.get("noFlicker", false))
	main = _col(doc.get("main", [1, 1, 1]))
	ambc = _col(doc.get("amb", [1, 1, 1]))
	amb = dark / 100.0 * float(doc.get("ambK", 1.0))
	var ls: Array = doc.get("lship", [])
	lship.resize(LW)
	for x in mini(LW, ls.size()):
		lship[x] = float(ls[x])
	var dc: Array = doc.get("dust", [255, 255, 255])
	dust_col = Color8(int(dc[0]), int(dc[1]), int(dc[2]))
	dust_n = int(doc.get("dustN", 56))
	pop_k = int(doc.get("pop", -1))
	pop_t0 = -99.0
	flk_lamp = -1
	_textures = {
		"light_map": ImageTexture.create_from_image(li),
		"vary_map": ImageTexture.create_from_image(vi),
		"own_map": ImageTexture.create_from_image(oi),
		"off_map": ImageTexture.create_from_image(fi),
		"lship_map": ImageTexture.create_from_image(_lship_image()),
	}
	for m in mats:
		_dress(m)
	return true


static func _col(a: Variant) -> Color:
	var v: Array = a
	return Color(float(v[0]), float(v[1]), float(v[2]))


## The ships' row as a 766 x 1 picture, 16-bit in R and G.
func _lship_image() -> Image:
	var img := Image.create(LW, 1, false, Image.FORMAT_RGBA8)
	for x in LW:
		var q := clampi(roundi(clampf(lship[x], 0.0, LSCALE) / LSCALE * 65535.0), 0, 65535)
		img.set_pixel(x, 0, Color8(q >> 8, q & 255, 0, 255))
	return img


## A material of the Yard's light in one of its four modes (see the shader).
func material(mode: int) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/yard_light.gdshader")
	m.set_shader_parameter(&"mode", mode)
	mats.append(m)
	if not doc.is_empty():
		_dress(m)
	return m


func _dress(m: ShaderMaterial) -> void:
	for k in _textures:
		m.set_shader_parameter(StringName(k), _textures[k])
	m.set_shader_parameter(&"scale", _scale)
	m.set_shader_parameter(&"vscale", _vscale)
	m.set_shader_parameter(&"bscale", BSCALE)
	m.set_shader_parameter(&"lscale", LSCALE)
	m.set_shader_parameter(&"nvary", _vary_idx.size())
	var boxes := PackedVector4Array()
	boxes.resize(12)
	for b in _vary_idx.size():
		var bx: Array = (lights[_vary_idx[b]] as Dictionary).get("box", [0, 0, 0, 0])
		boxes[b] = Vector4(float(bx[0]), float(bx[1]), float(bx[2]), float(bx[3]))
	m.set_shader_parameter(&"vbox", boxes)
	m.set_shader_parameter(&"amb", amb)
	m.set_shader_parameter(&"ambc", Vector3(ambc.r, ambc.g, ambc.b))
	m.set_shader_parameter(&"mainc", Vector3(main.r, main.g, main.b))
	m.set_shader_parameter(&"refl", bool(doc.get("glowRefl", true)))
	m.set_shader_parameter(&"reflk", float(doc.get("reflK", 0.4)))
	m.set_shader_parameter(&"bay_on", _bay_on)


## The floor lamps' pools with the ships' shadows in them, as baked by
## `yard_bay.gdshader`: the half grid, 16-bit in R and G.
func set_bay(img: Image) -> void:
	if img == null:
		_bay = PackedByteArray()
		_bay_on = false
	else:
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
		_bay = img.get_data()
		_bay_on = true
		_textures["bay_map"] = ImageTexture.create_from_image(img)
	for m in mats:
		if _bay_on:
			m.set_shader_parameter(&"bay_map", _textures["bay_map"])
		m.set_shader_parameter(&"bay_on", _bay_on)


## The ships' masks and their bellies' shade (`ship_map`), for every material.
func set_ship_map(tex: Texture2D) -> void:
	_textures["ship_map"] = tex
	for m in mats:
		m.set_shader_parameter(&"ship_map", tex)


## Where the hall is in the canvas, for every material.
func set_origin(o: Vector2) -> void:
	for m in mats:
		m.set_shader_parameter(&"origin", o)


func set_fullbright(on: bool) -> void:
	for m in mats:
		m.set_shader_parameter(&"fullbright", on)


# ------------------------------------------------------------------ the clocks

static func hash1(v: float) -> float:
	var x := sin(v * 127.1) * 43758.5453
	return x - floorf(x)


static func vnoise(v: float) -> float:
	var k := floorf(v)
	var u := v - k
	var s := u * u * (3.0 - 2.0 * u)
	return hash1(k * 1.37) * (1.0 - s) + hash1((k + 1.0) * 1.37) * s


static func smooth(a: float, b: float, t: float) -> float:
	var u := clampf((t - a) / (b - a), 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


static func blink_at(k: float, seed: float) -> float:
	return (k + 0.05 + 0.9 * hash1(k * 3.77 + seed)) * 3.2 - seed


## A lamp with a bad contact: now and then it blinks off for a frame or three.
static func loose(t: float, seed: float) -> float:
	var k := floorf((t + seed) / 3.2)
	var at := blink_at(k, seed)
	var fr := floorf((t - at) / 0.033 + 0.5)
	if t >= at and fr == 0.0:
		return 0.02
	if t >= at and fr <= 2.0 and hash1(seed * 5.1 + k) > 0.45:
		return 0.9 if fr == 1.0 else 0.03
	return 1.0


## A light striking: flickering to full over `dur` (the labs' `strikes`).
static func strikes(tb: float, from: float, dur: float, seed: float) -> float:
	if tb < from:
		return 0.0
	if tb >= from + dur:
		return 1.0
	var h := hash1(floorf((tb - from) / 0.033) * 1.37 + seed * 3.1)
	return 1.0 if h < 0.42 else (0.55 if h < 0.52 else 0.04)


## A tired lamp: every 13 s or so it drops out and strikes back on.
static func tired_w(t: float) -> float:
	var k := floorf(t / 13.0)
	var at := k * 13.0 + 2.0 + 8.0 * hash1(k * 2.71 + 0.4)
	if t >= at and t < at + 0.45:
		return strikes(t, at, 0.45, k * 1.3 + 0.7)
	return 1.0


static func stutter(t: float, seed: float, per: float) -> float:
	var k := floorf((t + seed * 1.7) / per)
	var at := k * per - seed * 1.7 + 1.0 + (per - 2.0) * hash1(k * 1.3 + seed)
	var u := t - at
	if u >= 0.0 and u < 0.45 and hash1(k * 7.1 + seed) < 0.6 and hash1(floorf(u / 0.05) * 3.1 + seed) < 0.5:
		return 0.2
	return 1.0


## One of the page's beats, by its spec (`yard.json`): [name, params...].
func beat(spec: Variant, t: float) -> float:
	if spec == null:
		return 1.0
	var s: Array = spec
	match String(s[0]):
		"one":
			return 1.0
		"dead":
			return 0.07
		"sine":
			return float(s[2]) + float(s[3]) * sin(t * TAU / float(s[1]))
		"blink":
			return 1.0 if int(floorf(t * float(s[1]))) % 2 != 0 else float(s[2])
		"loose", "looseB":
			return loose(t, float(s[1]))
		"drift":
			var lo := float(s[2])
			return lo + (1.0 - lo) * vnoise(t * float(s[3]) + float(s[1]) * 17.3)
		"buzz":
			var seed := float(s[1])
			var ep := floorf(t / 4.3)
			if hash1(ep * 2.9 + seed) >= 0.5 or t - ep * 4.3 > 2.2:
				return 1.0
			return 0.1 if hash1(floorf(t * 17.0) * 1.7 + seed) < 0.45 else 1.0
		"pop":
			return pop_w(t)
		"stutter":
			return stutter(t, float(s[1]), float(s[2]))
		"neon":
			return stutter(t, float(s[1]), float(s[2])) * (0.92 + 0.08 * sin(t * 5.3 + float(s[1]) * 2.1))
		"breathe":
			var lo2 := float(s[2])
			return lo2 + (1.0 - lo2) * (0.5 + 0.5 * sin((t / float(s[1]) + float(s[3])) * TAU))
		"screen":
			return 0.72 + 0.28 * vnoise(t * 4.0 + float(s[1]) * 9.1)
	return 1.0


## Unclaimed's bad bulb, popped at `pop_t0`: a flash, dark a while, stuttering back.
func pop_w(t: float) -> float:
	var u := t - pop_t0
	if u < 0.06:
		return 2.4
	if u < pop_off:
		return 0.05
	if u < pop_off + 0.5:
		return 0.15 if hash1(floorf(u * 28.0) * 1.3) < 0.5 else 1.0
	return 1.0


## E4's lamp, at its flicker's step now.
func lamp_level(t: float) -> float:
	if flk_lamp < 0:
		return 1.0
	var u := t - flk_t0
	var w := 1.0
	for st: Array in FLICK_LONG:
		if u >= float(st[0]):
			w = float(st[1])
	if u > float((FLICK_LONG[FLICK_LONG.size() - 1] as Array)[0]) + 0.1:
		flk_lamp = -1
		return 1.0
	return w


## Which ceiling lamps can flicker out: the painted ones, never the capital's.
func flickable() -> Array[int]:
	var out: Array[int] = []
	if no_flicker:
		return out
	var ls: Array = doc.get("lamps", [])
	for i in ls.size():
		var l: Dictionary = ls[i]
		if bool(l.get("painted", false)) and not bool(l.get("noflick", false)):
			out.append(i)
	return out


## E4: a painted ceiling lamp flickers out and pops back on.
func flicker(t: float) -> bool:
	var can := flickable()
	if flk_lamp >= 0 or can.is_empty():
		return false
	flk_lamp = can[randi() % can.size()]
	flk_t0 = t
	return true


## Every light's weight at `t` (the page's `lightWeights`).
func weigh(t: float) -> void:
	for i in ceil_idx.size():
		var n := int(ceil_idx[i])
		var w := (lamp_level(t) if flk_lamp == i else 1.0) * (tired_w(t) if i == tired else 1.0)
		nw[n] = w
		ew[n] = w
	for n in nlights:
		var L: Dictionary = lights[n]
		var kind := String(L.get("kind", ""))
		if kind == "glow":
			ew[n] = beat(L.get("beat"), t)
			nw[n] = beat(L.get("pool"), t) if L.has("pool") else 1.0
		elif kind != "ceil":
			nw[n] = 1.0
			ew[n] = 1.0


## This tick's weights and small lights, to every material.
func feed() -> void:
	var e := PackedVector4Array()
	e.resize(16)
	for q in 16:
		var v := Vector4(1, 1, 1, 1)
		for k in 4:
			var n := q * 4 + k
			if n < nlights:
				v[k] = ew[n]
		e[q] = v
	var lw := PackedVector4Array()
	lw.resize(4)
	for q in 4:
		var v2 := Vector4(1, 1, 1, 1)
		for k in 4:
			var i := q * 4 + k
			if i < ceil_idx.size():
				v2[k] = nw[int(ceil_idx[i])]
		lw[q] = v2
	var vc := PackedVector4Array()
	vc.resize(12)
	for b in _vary_idx.size():
		var n2 := _vary_idx[b]
		var L: Dictionary = lights[n2]
		var c: Array = L.get("col", [1, 1, 1])
		vc[b] = Vector4(float(c[0]), float(c[1]), float(c[2]), (nw[n2] - 1.0) * float(L.get("p", 1.0)))
	var dp := PackedVector4Array()
	var dc := PackedVector4Array()
	var dkk := PackedVector4Array()
	dp.resize(12)
	dc.resize(12)
	dkk.resize(3)
	var nd := mini(12, dyn.size())
	var ks := PackedFloat32Array()
	ks.resize(12)
	for i in nd:
		var g: Array = dyn[i]
		dp[i] = Vector4(float(g[0]), float(g[1]), float(g[2]), float(g[3]))
		var col: Color = g[5]
		dc[i] = Vector4(col.r, col.g, col.b, float(g[6]))
		ks[i] = float(g[4])
	for q in 3:
		dkk[q] = Vector4(ks[q * 4], ks[q * 4 + 1], ks[q * 4 + 2], ks[q * 4 + 3])
	for m in mats:
		m.set_shader_parameter(&"ew", e)
		m.set_shader_parameter(&"lampw", lw)
		m.set_shader_parameter(&"vcol", vc)
		m.set_shader_parameter(&"ndyn", nd)
		m.set_shader_parameter(&"dpos", dp)
		m.set_shader_parameter(&"dcol", dc)
		m.set_shader_parameter(&"dk", dkk)


# ------------------------------------------------------------------ the light at a point

static func cell_x(x: float) -> int:
	return clampi(int(floorf(x + 0.5)), 0, LW - 1)


static func cell_y(y: float) -> int:
	return clampi(int(floorf(y + 0.5)), 0, LH - 1)


func _u16(b: PackedByteArray, hi: int, lo: int, s: float) -> float:
	return float(b[hi] * 256 + b[lo]) / 65535.0 * s


## The floor lamps at a pixel, eased up from the half grid.
func bay_at(x: int, y: int) -> float:
	if not _bay_on or y < 207:
		return 0.0
	var fx := float(x) * 0.5
	var fy := float(y) * 0.5
	var cx := mini(382, int(floorf(fx)))
	var cy := mini(240, int(floorf(fy)))
	var tx := fx - float(cx)
	var ty := fy - float(cy)
	var i0 := (cy * 384 + cx) * 4
	var i1 := ((cy + 1) * 384 + cx) * 4
	var a := _u16(_bay, i0, i0 + 1, BSCALE)
	var b := _u16(_bay, i0 + 4, i0 + 5, BSCALE)
	var c := _u16(_bay, i1, i1 + 1, BSCALE)
	var d := _u16(_bay, i1 + 4, i1 + 5, BSCALE)
	return (a * (1.0 - tx) + b * tx) * (1.0 - ty) + (c * (1.0 - tx) + d * tx) * ty


## Every lamp's light at a pixel: [R, G, B, how much].
func sa_at(x: int, y: int) -> PackedFloat32Array:
	var out := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	if _light.is_empty():
		return out
	var hi := (y * LW + x) * 4
	var lo := ((y + LH) * LW + x) * 4
	for c in 4:
		out[c] = _u16(_light, hi + c, lo + c, _scale)
	for b in _vary_idx.size():
		var n := _vary_idx[b]
		var L: Dictionary = lights[n]
		var k := (nw[n] - 1.0) * float(L.get("p", 1.0))
		if k == 0.0:
			continue
		var bx: Array = L.get("box", [0, 0, 0, 0])
		if x < int(bx[0]) or y < int(bx[1]) or x >= int(bx[0]) + int(bx[2]) or y >= int(bx[1]) + int(bx[3]):
			continue
		var band := b / 2
		var j := ((y + (band / 2) * LH) * _vary_w + x + (band % 2) * LW) * 4 + (b % 2) * 2
		var f := _u16(_vary, j, j + 1, _vscale) * k
		var c2: Array = L.get("col", [1, 1, 1])
		out[0] += float(c2[0]) * f
		out[1] += float(c2[1]) * f
		out[2] += float(c2[2]) * f
		out[3] += f
	var by := bay_at(x, y)
	out[0] += main.r * by
	out[1] += main.g * by
	out[2] += main.b * by
	out[3] += by
	return out


## This tick's small lights at a pixel: [R, G, B, steady, breathing, any].
func da_at(x: int, y: int) -> PackedFloat32Array:
	var out := PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
	for g: Array in dyn:
		var dx := (float(x) - float(g[0])) / float(g[2])
		var dy := (float(y) - float(g[1])) / float(g[3])
		var dd := dx * dx + dy * dy
		if dd >= 1.0:
			continue
		var v := float(g[4]) * pow(1.0 - dd, 1.6)
		var col: Color = g[5]
		out[0] += v * col.r
		out[1] += v * col.g
		out[2] += v * col.b
		out[3] += v
		out[4] += v * float(g[6])
		out[5] = 1.0
	return out


## Does this pixel burn on its own?
func own_at(x: int, y: int) -> int:
	if _own.is_empty():
		return 0
	return _own[(y * LW + x) * 4]


## The light on something drawn over the frame, smooth rather than stepped (it
## moves): the page's `mAt`. `ship` reads the light over the ships' row.
func m_at(x: float, y: float, ship: bool = false) -> Color:
	var cx := cell_x(x)
	var cy := cell_y(y)
	var r: float
	var g: float
	var b: float
	var s: float
	if ship:
		var v := lship[cx]
		r = v * main.r
		g = v * main.g
		b = v * main.b
		s = v
	else:
		var l := sa_at(cx, cy)
		r = l[0]
		g = l[1]
		b = l[2]
		s = l[3]
	var d := da_at(cx, cy)
	r += d[0]
	g += d[1]
	b += d[2]
	return _smooth(r, g, b, s + d[3], s + d[4])


func _smooth(r: float, g: float, b: float, s0: float, s1: float) -> Color:
	var l := maxf(r, maxf(g, b))
	if l <= 0.001:
		return Color(amb * ambc.r, amb * ambc.g, amb * ambc.b)
	var tq := minf(1.0, l)
	if s0 > 0.0:
		tq = minf(1.0, tq * s1 / s0)
	var u := 1.0 - tq
	return Color(amb * ambc.r * u + (1.0 - 0.45 * (1.0 - r / l)) * tq,
		amb * ambc.g * u + (1.0 - 0.45 * (1.0 - g / l)) * tq,
		amb * ambc.b * u + (1.0 - 0.45 * (1.0 - b / l)) * tq)


## Something flying high takes the hall's light as a whole, steady (the page's
## `mAir`: flyers lit by each cone they passed went dark and light as they
## crossed, which Jon found "kinda weird").
func m_air() -> Color:
	var tq := 0.85
	var u := 1.0 - tq
	return Color(amb * ambc.r * u + (1.0 - 0.45 * (1.0 - main.r)) * tq,
		amb * ambc.g * u + (1.0 - 0.45 * (1.0 - main.g)) * tq,
		amb * ambc.b * u + (1.0 - 0.45 * (1.0 - main.b)) * tq)


## The deal TV's box takes the light as it stands with the TV fully on (the
## page's `boxLight`): its own lamps' light at its feet counted at full, so
## only its glass and lamps follow the power-on. `now` and `full` are what its
## lamps put there now and at full: [R, G, B, steady, breathing].
func box_light(x: float, y: float, now: PackedFloat32Array, full: PackedFloat32Array) -> Color:
	var cx := cell_x(x)
	var cy := cell_y(y)
	var l := sa_at(cx, cy)
	var d := da_at(cx, cy)
	var r := l[0] + d[0] - now[0] + full[0]
	var g := l[1] + d[1] - now[1] + full[1]
	var b := l[2] + d[2] - now[2] + full[2]
	var s0 := l[3] + d[3] - now[3] + full[3]
	var s1 := l[3] + d[4] - now[4] + full[4]
	var mx := maxf(r, maxf(g, b))
	if mx <= 0.001:
		return Color(amb * ambc.r, amb * ambc.g, amb * ambc.b)
	var tq := minf(1.0, mx)
	if s0 > 0.0:
		tq = minf(1.0, tq * s1 / s0)
	var u := 1.0 - tq
	return Color(amb * ambc.r * u + (1.0 - 0.45 * (1.0 - r / mx)) * tq,
		amb * ambc.g * u + (1.0 - 0.45 * (1.0 - g / mx)) * tq,
		amb * ambc.b * u + (1.0 - 0.45 * (1.0 - b / mx)) * tq)


## How much light a pixel of the wall has from its lamps, for the dust.
func s_at(x: int, y: int) -> float:
	return sa_at(x, y)[3]
