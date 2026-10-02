extends Node2D

## A SYSTEM'S SUN ON THE MAP: the ordinary, red and blue suns, as the approved
## mockup paints them ("Twenty-Four Stars", Jon: "These are great. Bang.
## Done."; sealed as `ST` in the scratchpad's `sysmap/page/index.html`). Put it
## at the star's centre in whole game pixels, `setup` it once per system and
## `step` it every frame with the map's clock.
##
## The picture is `sun.gdshader`, one pass over the mockup's 420x300 box round
## the star. This script does the parts of the mockup that are a handful of
## numbers a frame rather than a picture: the roll of the system's looks, where
## each plume and sunspot group is in its life, the corona's puffs, the sparks
## off an ember star, and the flares -- their kind, their loop or bubble, and the
## pixels they splat. Those go to the shader as uniforms and as one small float
## texture (`_data`, rows described in the shader's header).
##
## Like the mockup, the star is redrawn only when the clock has moved 0.03 s
## since the last drawing (`starLook`'s `STAR_C.last`): at 60 frames a second
## it moves at 30, which is how its motion was approved.
##
## ZOOMED (`set_zoom`), the same star is drawn k times bigger by the shader,
## in single game pixels: everything rolled and listed here stays in the
## mockup's 420x300 box, and only the box drawn on the map grows.

const SHADER := preload("res://shaders/sun.gdshader")

const W := 420
const H := 300
const CX := 210.0
const CY := 150.0
const DATA_W := 1024
const DATA_H := 6
const MAX_POINTS := 1024
const MAX_BLOBS := 1024

const L_SUN := Vector3(1.0, 0.62, 0.22)
const L_RED := Vector3(0.85, 0.22, 0.1)
const L_BLU := Vector3(0.35, 0.6, 1.0)
const L_ICE := Vector3(0.75, 0.9, 1.0)
const L_PINK := Vector3(0.9, 0.3, 0.45)
const L_WHITE := Vector3(1.0, 1.0, 1.0)
const HOT := Vector3(1.0, 0.92, 0.75)
const WARM := Vector3(1.0, 0.55, 0.25)
const FLARE_KINDS := ["loop", "cme", "spray", "arcade", "ribbons"]
const LAYER_BITS := {"dust": 1, "plumes": 2, "wind": 4, "lobes": 8, "bedisc": 16, "carve": 32, "corona": 64}
## The eight spikes: their angle and their length as a share of the longest.
const ARMS := [[0.0, 1.0], [PI, 1.0], [PI / 2.0, 0.8], [-PI / 2.0, 0.8], [PI / 4.0, 0.35], [3.0 * PI / 4.0, 0.35], [-PI / 4.0, 0.35], [-3.0 * PI / 4.0, 0.35]]

## The rolled star: the mockup's `P`, its keys in snake case.
var P: Dictionary = {}
var _rect: ColorRect
var _mat: ShaderMaterial
var _data := PackedFloat32Array()
var _img: Image
var _tex: ImageTexture
var _last := -1e9
var _np := 0
var _nb := 0
var _box := Vector4(1e9, 1e9, -1e9, -1e9)
var _bbox := Vector4(1e9, 1e9, -1e9, -1e9)
## how many times bigger than the mockup the star is drawn (`set_zoom`)
var _k := 1.0
## A spray flare's droplets, carried on from frame to frame (see `_spray`).
var _spray_g := -1
var _spray_u := 0.0
var _drops: Array = []


func _init() -> void:
	_rect = ColorRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.position = Vector2(-CX, -CY)
	_rect.size = Vector2(W, H)
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_rect.material = _mat
	add_child(_rect)
	_data.resize(DATA_W * DATA_H * 4)
	_img = Image.create_from_data(DATA_W, DATA_H, false, Image.FORMAT_RGBAF, _data.to_byte_array())
	_tex = ImageTexture.create_from_image(_img)
	_mat.set_shader_parameter("data", _tex)
	_zoom_box()


## Which kind of sun ("ORDINARY", "RED" or "BLUE"), for which system, at what
## radius in game pixels -- the map's `starLook`: seed index * 7 + 3, radius 16,
## 48 or 24.
func setup(kind: String, system_index: int, star_r: float) -> void:
	P = roll(kind, system_index * 7 + 3, star_r)
	_last = -1e9
	_spray_g = -1
	var m := _mat
	m.set_shader_parameter("kind", int(P.pal))
	m.set_shader_parameter("R", float(P.R))
	m.set_shader_parameter("limb", float(P.limb))
	m.set_shader_parameter("spin", float(P.spin))
	m.set_shader_parameter("glow_c", P.glow_c)
	m.set_shader_parameter("glow_r", float(P.glow_r))
	m.set_shader_parameter("glow_w", float(P.glow_w))
	m.set_shader_parameter("glow_i", float(P.glow_i))
	m.set_shader_parameter("gran", float(P.gran))
	m.set_shader_parameter("gran_k", float(P.gran_k))
	m.set_shader_parameter("cells", float(P.cells))
	m.set_shader_parameter("lumpy", float(P.lumpy))
	m.set_shader_parameter("breath", float(P.breath))
	m.set_shader_parameter("embers", bool(P.embers))
	m.set_shader_parameter("oblate", float(P.oblate))
	m.set_shader_parameter("eq_tilt", float(P.eq_tilt))
	m.set_shader_parameter("gdark", float(P.gdark))
	m.set_shader_parameter("shimmer", float(P.shimmer))
	m.set_shader_parameter("spikes", float(P.spikes))
	m.set_shader_parameter("spike_c", P.spike_c)
	m.set_shader_parameter("rays", float(P.rays))
	m.set_shader_parameter("rays_c", P.rays_c)
	var bits := 0
	for l: String in P.layers:
		bits |= int(LAYER_BITS.get(l, 0))
	m.set_shader_parameter("layers", bits)
	m.set_shader_parameter("carve_sd", float(P.seed) * 3.1)
	m.set_shader_parameter("n_proms", 0)
	m.set_shader_parameter("n_groups", 0)
	m.set_shader_parameter("n_points", 0)
	m.set_shader_parameter("n_blobs", 0)
	m.set_shader_parameter("cme_a", Vector4.ZERO)
	m.set_shader_parameter("wave", Vector4.ZERO)
	m.set_shader_parameter("flick", 1.0)


## THE MAP'S ZOOM, 1 to 4: the star drawn k times bigger -- its radius, its
## cells, its plumes and flares, its glow and the box round it -- by its own
## shader, in single game pixels; the same rolled star, nothing re-rolled.
## Cheap enough to call every frame while the zoom eases.
func set_zoom(k: float) -> void:
	k = clampf(k, 1.0, 4.0)
	if k == _k:
		return
	_k = k
	_zoom_box()


## The box the star is drawn in, the mockup's 420x300 grown by k to whole game
## pixels round the star's centre (which stays at this node's position).
func _zoom_box() -> void:
	var h := Vector2(ceilf(CX * _k - 0.001), ceilf(CY * _k - 0.001))
	_rect.position = -h
	_rect.size = h * 2.0
	_mat.set_shader_parameter("zoom", _k)
	_mat.set_shader_parameter("box_h", h)


## The map's clock, in seconds.
func step(t: float) -> void:
	if P.is_empty() or (_last > t - 0.03 and _last <= t):
		return
	_last = t
	var m := _mat
	m.set_shader_parameter("time", t)
	var flick := 1.0
	if P.flicker > 0.0:
		flick = 1.0 + P.flicker * (noise(t * 3.0, 7.0) - 0.5) * 2.0
	m.set_shader_parameter("flick", flick)
	var R: float = P.R
	var layers: Array = P.layers
	if layers.has("plumes"):
		_plumes(t, R)
	if P.proms > 0:
		_proms(t, R)
	if P.spikes > 0.0:
		var turn: float = t * P.spin_spikes
		var arms := PackedVector4Array()
		for j in 8:
			var a: float = ARMS[j][0]
			var k: float = ARMS[j][1]
			if P.spin_spikes > 0.0:
				k *= 0.7 + 0.5 * noise(t * 1.1 + j * 3.7, float(j))
			arms.append(Vector4(cos(a + turn), sin(a + turn), k, 0.0))
		m.set_shader_parameter("arms", arms)
	# the lists the shader reads from `_data`: points, discs, sunspot members
	_np = 0
	_nb = 0
	_box = Vector4(1e9, 1e9, -1e9, -1e9)
	_bbox = Vector4(1e9, 1e9, -1e9, -1e9)
	var dirty := false
	if P.groups > 0:
		_groups(t)
		dirty = true
	if layers.has("sparks"):
		_sparks(t, R)
	if layers.has("corona"):
		_corona_puffs(t, R)
	m.set_shader_parameter("cme_a", Vector4.ZERO)
	m.set_shader_parameter("wave", Vector4.ZERO)
	if layers.has("flare"):
		_flare(t, R)
	# (with nothing listed the counts are 0 and the texture's old rows go unread)
	if dirty or _np > 0 or _nb > 0:
		_img.set_data(DATA_W, DATA_H, false, Image.FORMAT_RGBAF, _data.to_byte_array())
		_tex.update(_img)
	m.set_shader_parameter("n_points", _np)
	m.set_shader_parameter("pts_box", _box)
	m.set_shader_parameter("n_blobs", _nb)
	m.set_shader_parameter("blob_box", _bbox)


# ---------------------------------------------------------------- the roll
## EACH SYSTEM ROLLS ITS STAR (Jon: "randomize these ... between systems. They
## should stay the same across the run"): one or two looks from its kind's set,
## from the system's own seed. The mockup's `rollStar`, hash for hash.
static func roll(kind: String, seed: int, r: float) -> Dictionary:
	var p := {
		"R": r, "pal": 0, "glow_c": L_SUN, "limb": 0.6, "glow_r": 3.5, "glow_w": 0.45, "glow_i": 0.8, "spin": 0.05,
		"layers": [], "gran": 0.0, "gran_k": 0.3, "cells": 0.0, "lumpy": 0.0, "breath": 0.0, "embers": false,
		"oblate": 0.0, "eq_tilt": 0.0, "gdark": 0.0, "flicker": 0.0, "shimmer": 0.0, "spikes": 0.0, "spin_spikes": 0.0,
		"spike_c": L_ICE, "rays": 0.0, "rays_c": L_ICE, "groups": 0, "group_span": 0.5, "group_size": 1.0, "proms": 0, "flare": 0.0,
	}
	var pool: Array
	if kind == "RED":
		p.merge({"pal": 1, "glow_c": L_RED, "limb": 0.8, "glow_r": 2.2, "glow_w": 0.3, "glow_i": 0.6, "spin": 0.02, "cells": 2.4}, true)
		pool = ["lumpy", "dust", "breath", "plumes", "ember"]
	elif kind == "BLUE":
		p.merge({"pal": 2, "glow_c": L_BLU, "limb": 0.35, "glow_r": 5.5, "glow_w": 0.9, "glow_i": 1.1, "spin": 0.08, "gran": 8.0, "gran_k": 0.15}, true)
		pool = ["blinding", "wind", "lobes", "flicker", "spun", "carve"]
	else:
		p.merge({"gran": 9.0, "gran_k": 0.22}, true)
		pool = ["spots", "proms", "corona", "flares", "glare"]
	var n := 1 if hsh(seed, 901) < 0.45 else 2
	var a := int(floorf(hsh(seed, 902) * pool.size()))
	var b := int(floorf(hsh(seed, 903) * (pool.size() - 1)))
	if b >= a:
		b += 1
	var looks: Array = [pool[a]] if n == 1 else [pool[a], pool[b]]
	var layers: Array = p.layers
	for k: String in looks:
		match k:
			"lumpy": p.lumpy = 0.075
			"dust": layers.append("dust")
			"breath": p.breath = 0.05
			"plumes": layers.append("plumes")
			"ember":
				p.embers = true
				p.limb = 0.6
				p.cells = 0.0
				layers.append("sparks")
			"blinding": p.merge({"spikes": 46.0, "spin_spikes": 0.05, "shimmer": 0.35, "rays": 0.16}, true)
			"wind": layers.append("wind")
			"lobes": layers.append("lobes")
			"flicker":
				p.flicker = 0.35
				if p.spikes <= 0.0:
					p.spikes = 36.0
			"spun":
				layers.append("bedisc")
				p.merge({"oblate": 0.22, "eq_tilt": -0.25, "gdark": 0.5}, true)
			"carve": layers.append("carve")
			"spots": p.merge({"groups": 2, "group_span": 0.55, "group_size": 1.3, "spin": 0.08}, true)
			"proms":
				layers.append("proms")
				p.proms = 4
			"corona": layers.append("corona")
			"flares":
				p.flare = 6.0
				layers.append("flare")
			"glare": p.merge({"spikes": 34.0, "spike_c": Vector3(1.0, 0.85, 0.6), "spin_spikes": 0.04, "shimmer": 0.3, "rays": 0.14, "rays_c": Vector3(1.0, 0.78, 0.45)}, true)
	p.seed = seed
	p.looks = looks
	return p


# ---------------------------------------------------------------- the mockup's hash and noise
## The star painter's hash: JS `Math.imul` mixing, kept to 32 bits.
static func hsh(x: int, y: int) -> float:
	var h := ((x * 374761393) ^ (y * 668265263)) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	return float(h ^ (h >> 16)) / 4294967296.0


static func noise(x: float, y: float) -> float:
	var xf := floorf(x)
	var yf := floorf(y)
	var xi := int(xf)
	var yi := int(yf)
	var u := x - xf
	var v := y - yf
	u = u * u * (3.0 - 2.0 * u)
	v = v * v * (3.0 - 2.0 * v)
	var a := hsh(xi, yi)
	var b := hsh(xi + 1, yi)
	var c := hsh(xi, yi + 1)
	var d := hsh(xi + 1, yi + 1)
	return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v


static func smo(a: float, b: float, x: float) -> float:
	var u := clampf((x - a) / (b - a), 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


# ---------------------------------------------------------------- the lists
## A pixel of light, rounded as the mockup's `add` rounds it; off the box is lost.
## How far off its pixel the point really was goes too: zoomed, the shader
## puts its dot there.
func _add(x: float, y: float, c: Vector3, k: float) -> void:
	var X := floorf(x + 0.5)
	var Y := floorf(y + 0.5)
	if X < 0.0 or Y < 0.0 or X >= W or Y >= H or _np >= MAX_POINTS or k == 0.0:
		return
	var i := _np * 4
	_data[i] = X
	_data[i + 1] = Y
	# (kept under a half, so that at k = 1 the shader lands on X exactly)
	_data[i + 2] = clampf(x - X, -0.5, 0.4999)
	_data[i + 3] = clampf(y - Y, -0.5, 0.4999)
	i = (DATA_W + _np) * 4
	_data[i] = c.x * k
	_data[i + 1] = c.y * k
	_data[i + 2] = c.z * k
	_np += 1
	_box = Vector4(minf(_box.x, X), minf(_box.y, Y), maxf(_box.z, X), maxf(_box.w, Y))


## A soft lump of light, torn by noise keyed to (g, u): the mockup's `flareBlob`.
## `pre` lumps go down before the face (the corona's), the rest after it.
func _blob(x: float, y: float, w: float, c: Vector3, k: float, g: float, u: float, pre: bool = false) -> void:
	if _nb >= MAX_BLOBS or k == 0.0:
		return
	var i := (2 * DATA_W + _nb) * 4
	_data[i] = x
	_data[i + 1] = y
	_data[i + 2] = w
	_data[i + 3] = 1.0 if pre else 0.0
	_bbox = Vector4(minf(_bbox.x, x - w), minf(_bbox.y, y - w), maxf(_bbox.z, x + w), maxf(_bbox.w, y + w))
	i = (3 * DATA_W + _nb) * 4
	_data[i] = c.x * k
	_data[i + 1] = c.y * k
	_data[i + 2] = c.z * k
	i = (4 * DATA_W + _nb) * 4
	_data[i] = g * 9.0
	_data[i + 1] = u * 1.5
	_nb += 1


# ---------------------------------------------------------------- what moves
## PLUMES WITH LIFE: each lives some seconds, fades, and another rises elsewhere.
func _plumes(t: float, R: float) -> void:
	var pa := PackedVector4Array()
	var pb := PackedVector4Array()
	for k in 4:
		var life := 9.0 + hsh(k, 41) * 6.0
		var ph := hsh(k, 42) * life
		var g := int(floorf((t + ph) / life))
		var u := fmod(t + ph, life) / life
		var id := k * 13 + g
		var a := hsh(id, 43) * TAU
		var len := R * (0.5 + 0.6 * hsh(id, 44)) * smo(0.0, 0.45, u)
		var fade := 1.0 - smo(0.62, 1.0, u)
		var bend := (hsh(id, 45) - 0.5) * 1.4
		var on := not (len < 2.0 or fade <= 0.0)
		pa.append(Vector4(cos(a), sin(a), len, fade))
		pb.append(Vector4(bend, float(id), float(k), 1.0 if on else 0.0))
	_mat.set_shader_parameter("plume_a", pa)
	_mat.set_shader_parameter("plume_b", pb)


## Arches of glowing gas at the edge, slowly rising and falling.
func _proms(t: float, R: float) -> void:
	var pp := PackedVector4Array()
	var pq := PackedVector4Array()
	for k in int(P.proms):
		var base := hsh(k, 21) * TAU + t * 0.02
		var span := 0.4 + hsh(k, 22) * 0.35
		var h := R * (0.4 + 0.45 * hsh(k, 23)) * (0.8 + 0.25 * sin(t * 0.5 + k))
		var a0 := base - span / 2.0
		var a1 := base + span / 2.0
		pp.append(Vector4(CX + cos(a0) * R, CY + sin(a0) * R, CX + cos(a1) * R, CY + sin(a1) * R))
		pq.append(Vector4(CX + cos(base) * (R + h), CY + sin(base) * (R + h), base, 0.0))
	_mat.set_shader_parameter("prom_p", pp)
	_mat.set_shader_parameter("prom_q", pq)
	_mat.set_shader_parameter("n_proms", int(P.proms))


## SUNSPOT GROUPS (Jon's photo): big dark cores in ragged rims, strung along a
## line, pores between them; each grows, lives, fades, and another forms.
func _groups(t: float) -> void:
	var sd: int = int(P.seed) * 17
	var gc := PackedVector4Array()
	var ge := PackedVector4Array()
	var gn := PackedVector4Array()
	var counts := Vector2i.ZERO
	var ng := 0
	for k in int(P.groups):
		var life := 20.0 + hsh(k, sd + 1) * 12.0
		var ph := hsh(k, sd + 2) * life
		var g := int(floorf((t + ph) / life))
		var u := fmod(t + ph, life) / life
		var id := k * 31 + g
		var grow := pow(sin(PI * u), 0.5)
		if grow < 0.05:
			continue
		var la := (hsh(id, sd + 3) - 0.5) * 0.9
		var lo := hsh(id, sd + 4) * TAU
		var tilt := (hsh(id, sd + 5) - 0.5) * 1.6
		var c := Vector3(cos(la) * sin(lo), sin(la), cos(la) * cos(lo))
		var el := Vector2(c.z, -c.x).length()
		if el == 0.0:
			el = 1.0
		var e := Vector3(c.z / el, 0.0, -c.x / el)
		var n := Vector3(c.y * e.z - c.z * e.y, c.z * e.x - c.x * e.z, c.x * e.y - c.y * e.x)
		var gk := int(floorf(hsh(id, sd + 8) * 5.0))
		var scale: float = P.group_size * (0.6 + 0.9 * hsh(id, sd + 9)) * grow
		var span: float = P.group_span * (0.6 + 0.7 * hsh(id, sd + 6))
		var mem: Array[Vector4] = []
		# kinds: a lone round spot; a leading and trailing pair; a long chain;
		# a tangled cluster; a loose scatter of pores
		if gk == 0:
			mem.append(Vector4(0, 0, (0.1 + 0.05 * _gh(id, 0, 11)) * scale, 1))
			_pores(mem, id, 5, 0.3, 0.2, scale)
		elif gk == 1:
			mem.append(Vector4(-span * 0.4, 0, 0.1 * scale, 1))
			mem.append(Vector4(span * 0.4, (_gh(id, 1, 10) - 0.5) * 0.08, 0.065 * scale, 1))
			_pores(mem, id, 12, span, 0.14, scale)
		elif gk == 2:
			var nb := 4 + int(floorf(_gh(id, 0, 7) * 3.0))
			for j in nb:
				mem.append(Vector4((float(j) / (nb - 1) - 0.5) * span * 1.2 + (_gh(id, j, 9) - 0.5) * 0.05, (_gh(id, j, 10) - 0.5) * 0.05, (0.045 + 0.04 * _gh(id, j, 11)) * scale, 1))
			_pores(mem, id, 16, span * 1.4, 0.14, scale)
		elif gk == 3:
			var nb := 3 + int(floorf(_gh(id, 0, 7) * 3.0))
			for j in nb:
				mem.append(Vector4((_gh(id, j, 9) - 0.5) * span * 0.6, (_gh(id, j, 10) - 0.5) * span * 0.45, (0.05 + 0.05 * _gh(id, j, 11)) * scale, 1))
			_pores(mem, id, 22, span * 0.9, span * 0.6, scale)
		else:
			mem.append(Vector4(0, 0, 0.035 * scale, 1))
			_pores(mem, id, 26, span * 1.2, 0.3, scale)
		gc.append(Vector4(c.x, c.y, c.z, tilt))
		ge.append(Vector4(e.x, e.y, e.z, span * 0.9 + 0.3))
		gn.append(Vector4(n.x, n.y, n.z, float(id)))
		var cnt := mini(mem.size(), 32)
		for j in cnt:
			var i := (5 * DATA_W + ng * 32 + j) * 4
			_data[i] = mem[j].x
			_data[i + 1] = mem[j].y
			_data[i + 2] = mem[j].z
			_data[i + 3] = mem[j].w
		if ng == 0:
			counts.x = cnt
		else:
			counts.y = cnt
		ng += 1
	while gc.size() < 2:
		gc.append(Vector4.ZERO)
		ge.append(Vector4.ZERO)
		gn.append(Vector4.ZERO)
	_mat.set_shader_parameter("g_c", gc)
	_mat.set_shader_parameter("g_e", ge)
	_mat.set_shader_parameter("g_n", gn)
	_mat.set_shader_parameter("g_count", counts)
	_mat.set_shader_parameter("n_groups", ng)


func _gh(id: int, j: int, q: int) -> float:
	return hsh(id * 7 + j, q)


func _pores(mem: Array[Vector4], id: int, n: int, sx: float, sy: float, scale: float) -> void:
	for m in n:
		mem.append(Vector4((_gh(id, m, 12) - 0.5) * sx, (_gh(id, m, 13) - 0.5) * sy, (0.01 + 0.016 * _gh(id, m, 14)) * scale, 0))


## Sparks rising off an ember star's edge, flickering, drifting, gone.
func _sparks(t: float, R: float) -> void:
	for k in 50:
		var life := 2.5 + hsh(k, 61) * 2.0
		var ph := hsh(k, 62) * life
		var g := int(floorf((t + ph) / life))
		var u := fmod(t + ph, life) / life
		var a := hsh(k * 17 + g, 63) * TAU + (hsh(k, 64) - 0.5) * u * 0.6
		var r := R * (0.98 + 0.55 * u * (0.6 + 0.6 * hsh(k * 17 + g, 65)))
		var fl := 0.5 + 0.5 * noise(t * 6.0 + k * 3, float(k))
		_add(CX + cos(a) * r, CY + sin(a) * r, Vector3(1.0, 0.75, 0.35) if u < 0.4 else Vector3(1.0, 0.42, 0.15), (1.0 - u) * fl * 1.2)


## Puffs of plasma carried out along the corona's streamers.
func _corona_puffs(t: float, R: float) -> void:
	var Rc := R * 3.4
	var sway := 0.5 * sin(t * 0.15)
	for k in 6:
		var a := (k / 3.0) * PI - sway / 3.0 + (hsh(k, 3) - 0.5) * 0.3
		var run := fmod(t * 9.0 + k * 13, Rc - R)
		var d := R + run
		_blob(CX + cos(a) * d, CY + sin(a) * d, 2.0 + run * 0.08, Vector3(1.0, 0.8, 0.55), 0.45 * (1.0 - run / (Rc - R)), float(k), t, true)


## A SOLAR FLARE every six seconds, each rolling its kind.
func _flare(t: float, R: float) -> void:
	var T: float = P.flare
	var g := int(floorf(t / T))
	var u := t - g * T
	if u > 5.2:
		return
	var sd: int = int(P.seed)
	var kind: String = FLARE_KINDS[int(floorf(hsh(g, sd * 5 + 11) * FLARE_KINDS.size()))]
	var a := hsh(g, sd * 7 + 3) * TAU
	var ca := cos(a)
	var sa := sin(a)
	var gf := float(g)
	match kind:
		"loop":
			# THE ERUPTING LOOP: it swells up off the limb, breaks, and the top blows away
			var span := 0.38 + 0.16 * hsh(g, sd * 7 + 4)
			var twist := (hsh(g, sd * 7 + 5) - 0.5) * 1.6
			var rise := smo(0.15, 2.2, u)
			var broke := smo(2.4, 3.2, u)
			var legs := 1.0 - smo(2.8, 4.6, u)
			var top := R * (0.2 + 1.3 * rise)
			var x0 := CX + cos(a - span) * R * 0.97
			var y0 := CY + sin(a - span) * R * 0.97
			var x2 := CX + cos(a + span) * R * 0.97
			var y2 := CY + sin(a + span) * R * 0.97
			var cx1 := CX + cos(a + twist * span * 0.5) * (R + top * 1.9)
			var cy1 := CY + sin(a + twist * span * 0.5) * (R + top * 1.9)
			for i in 61:
				var s0 := i / 60.0
				var mm := 1.0 - s0
				var bx := mm * mm * x0 + 2.0 * mm * s0 * cx1 + s0 * s0 * x2
				var by := mm * mm * y0 + 2.0 * mm * s0 * cy1 + s0 * s0 * y2
				var mid := sin(PI * s0)
				var keep := legs * (1.0 - broke * smo(0.25, 0.4, mid))
				if keep < 0.03:
					continue
				var heat := 1.0 - mid
				var col := Vector3(1.0, 0.9, 0.7) if heat > 0.75 else (Vector3(1.0, 0.55, 0.25) if heat > 0.4 else L_PINK)
				_blob(bx + sin(s0 * 12.0 + u * 3.0) * 0.8, by + cos(s0 * 12.0 + u * 3.0) * 0.8, 1.6 + 2.6 * mid * rise, col, (0.32 - 0.12 * mid) * keep, gf, u)
			if broke > 0.0:
				var fly := (u - 2.4) * R * 0.9
				_blob(CX + ca * (R + top + fly), CY + sa * (R + top + fly), 4.0 + (u - 2.4) * 5.0, Vector3(1.0, 0.4, 0.55), 0.75 * broke * maxf(0.0, 1.0 - (u - 2.4) / 2.8), gf, u)
			var flash := maxf(0.0, 1.0 - u / 1.2)
			_blob(x0, y0, 4.0, L_WHITE, 1.8 * flash, gf, u)
			_blob(x2, y2, 4.0, L_WHITE, 1.8 * flash, gf, u)
		"cme":
			# A MASS EJECTION: a bubble balloons off the limb and sails away
			var go := pow(u, 1.25)
			var cd := R + R * 0.25 + go * R * 0.75
			var br := R * 0.25 + go * R * 0.4
			var fade := maxf(0.0, 1.0 - u / 5.2)
			var bx := CX + ca * cd
			var by := CY + sa * cd
			_mat.set_shader_parameter("cme_a", Vector4(bx, by, br, 1.0))
			_mat.set_shader_parameter("cme_b", Vector4(ca, sa, gf, u))
			_mat.set_shader_parameter("cme_fade", fade)
			_blob(CX + ca * (cd - br * 0.35), CY + sa * (cd - br * 0.35), 3.0 + go * 1.5, Vector3(1.0, 0.5, 0.55), 0.9 * fade, gf, u)
			for k: int in [-1, 1]:
				var fx := CX + cos(a + k * 0.35) * R
				var fy := CY + sin(a + k * 0.35) * R
				var ex := bx + (-sa * k) * br * 0.8 - ca * br * 0.4
				var ey := by + (ca * k) * br * 0.8 - sa * br * 0.4
				var s0 := 0.0
				while s0 <= 1.0:
					_add(fx + (ex - fx) * s0, fy + (ey - fy) * s0, WARM, 0.35 * fade * (1.0 - s0 * 0.5))
					s0 += 0.03
			if u < 1.2:
				_blob(CX + ca * R * 0.95, CY + sa * R * 0.95, 5.0, L_WHITE, 1.6 * (1.0 - u / 1.2), gf, u)
		"spray":
			_spray(g, u, R, ca, sa)
			if u < 1.0:
				_blob(CX + ca * R * 0.95, CY + sa * R * 0.95, 4.0, L_WHITE, 1.6 * (1.0 - u), gf, u)
		"arcade":
			# AN ARCADE: a row of small loops lights up along the limb, one after another
			for k in 7:
				var c := a + (k - 3) * 0.13
				var on := smo(k * 0.18, k * 0.18 + 0.6, u) * maxf(0.0, 1.0 - maxf(0.0, u - 2.6) / 2.4)
				if on < 0.02:
					continue
				var h := R * (0.32 + 0.16 * hsh(k, g)) * (0.8 + 0.2 * sin(u * 2.0 + k))
				var s0 := 0.0
				while s0 <= 1.0:
					var ang := c + (s0 - 0.5) * 0.11
					var lift := sin(PI * s0) * h
					var rr := R * 0.97 + lift
					_add(CX + cos(ang) * rr, CY + sin(ang) * rr, WARM if lift > h * 0.6 else Vector3(1.0, 0.8, 0.5), 0.4 * on)
					_add(CX + cos(ang) * (rr + 1.0), CY + sin(ang) * (rr + 1.0), L_PINK, 0.25 * on)
					s0 += 0.025
		_:
			# RIBBONS: two bright ribbons flash across the face, a wave of light runs out from them
			var ox := CX + ca * R * 0.4
			var oy := CY + sa * R * 0.4
			var flash := maxf(0.0, 1.0 - u / 2.5)
			for k: int in [-1, 1]:
				var s0 := -1.0
				while s0 <= 1.0:
					var bend := s0 * s0 * 2.5
					var x := ox + (-sa) * s0 * R * 0.32 + ca * (k * 2.4 + bend)
					var y := oy + ca * s0 * R * 0.32 + sa * (k * 2.4 + bend)
					_add(x, y, L_WHITE, 1.4 * flash * (0.6 + 0.6 * noise(s0 * 6.0 + k * 3, gf)))
					_add(x + ca * k, y + sa * k, HOT, 0.6 * flash)
					s0 += 0.04
			_mat.set_shader_parameter("wave", Vector4(ox, oy, u * R * 0.6, maxf(0.0, 1.0 - u / 3.5)))


## A SPRAY: plasma flung up off the limb in a fan of drops that slow, turn and
## rain back down. The mockup ran every drop from its launch on every frame;
## the same steps are carried on here from the last frame, so a frame pays
## only for the steps it adds, and the drops land where the mockup's land.
func _spray(g: int, u: float, R: float, ca: float, sa: float) -> void:
	var grav := R * 0.75
	var dt := 0.04
	if _spray_g != g or u < _spray_u:
		_spray_g = g
		_drops.clear()
		for k in 70:
			var ang := (hsh(k, g * 3 + 1) - 0.5) * 0.9
			var sp := R * (0.55 + 0.45 * hsh(k, g * 3 + 2))
			var t0 := hsh(k, g * 3 + 3) * 0.6
			var vx := (ca * cos(ang) - sa * sin(ang)) * sp
			var vy := (sa * cos(ang) + ca * sin(ang)) * sp
			_drops.append({"t0": t0, "x": CX + ca * R * 0.98, "y": CY + sa * R * 0.98, "vx": vx, "vy": vy, "st": 0.0, "n": 0, "home": false, "trail": PackedVector2Array()})
	_spray_u = u
	for dr: Dictionary in _drops:
		var s0: float = u - dr.t0
		if s0 < 0.0:
			continue
		# the mockup's loop, `for (st = 0; st < s0; st += dt)`, resumed where it stopped
		var st: float = dr.st
		var x: float = dr.x
		var y: float = dr.y
		var vx: float = dr.vx
		var vy: float = dr.vy
		var trail: PackedVector2Array = dr.trail
		var home: bool = dr.home
		while not home and st < s0:
			var dx := x - CX
			var dy := y - CY
			var d := sqrt(dx * dx + dy * dy)
			if st > 0.1 and d < R * 0.97:
				home = true
				break
			vx -= dx / d * grav * dt
			vy -= dy / d * grav * dt
			x += vx * dt
			y += vy * dt
			trail.append(Vector2(x, y))
			if trail.size() > 4:
				trail.remove_at(0)
			st += dt
		dr.st = st
		dr.x = x
		dr.y = y
		dr.vx = vx
		dr.vy = vy
		dr.trail = trail
		dr.home = home
		if home:
			continue
		var heat := maxf(0.0, 1.0 - s0 / 2.6)
		var col := HOT if heat > 0.6 else (WARM if heat > 0.25 else L_PINK)
		for j in trail.size():
			_add(trail[j].x, trail[j].y, col, 0.7 * (0.4 + 0.2 * j))
