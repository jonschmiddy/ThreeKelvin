class_name LiftPlume
extends Control

## THE STEAM a hull throws up as it lifts off or sets down (Jon's "AB-23", Nov 12):
## sculpted lobes in three layers of depth, rising round the hull, every lift its own.
## The host (`ShipLift`) moves it with the hull, lays `back_layer` under the hull, and
## sets `thrust`; once the jets cut, it clears.
## Why: docs/why/ShipLift.md#plume

## The shape changes ten times a second (the steam's own clock), the lobes move every frame.
const HZ := 10.0
const MAX_LOBES := 48
const RATE := 26.0
const BURST := 12
## Once the jets cut, every lobe is gone within this many seconds (Jon, Nov 12:
## "The smoke should also dissipate when landing").
const CLEAR_S := Vector2(1.4, 2.0)
## The light it gives eases after the thrust over a few tenths of a second: steady,
## never stepping frame to frame (Jon's F1, Nov 12).
const LIGHT_TC := 0.15
## Its five tones, crease to lit rim: halfway between grey steam and warm exhaust.
const TONES := [Color(0.23, 0.225, 0.235), Color(0.365, 0.36, 0.36), Color(0.51, 0.5, 0.49),
	Color(0.65, 0.64, 0.62), Color(0.8, 0.785, 0.755)]
## The three layers of depth, far to near: alpha, tone shift (paler), contrast.
const LAYERS := [[0.42, 0.7, 0.45], [0.8, 0.2, 0.8], [0.94, 0.0, 1.15]]

## Knobs: how big, how hard, and the floor row it rises from.
var size_k: float = 1.0
var strength: float = 1.0
var floor_y: float = 372.0
## The hull's belly middle and half its length (host px), this frame.
var src := Vector2(480, 300)
var src_w: float = 60.0
## The hull's inked box (host px), this frame: the steam climbs past its nose and tail.
var hull := Rect2()
## 0..1, set by the host each frame: how hard the lift jets burn.
var thrust: float = 0.0
## Where under the hull the steam comes from this frame: (x, belly row, weight),
## and how far either side of each it starts.
var sources: Array[Vector3] = []
var spread: float = 10.0
## The stands' tops (host px), where steam also rises.
var vents: Array[Vector2] = []
## The hall's lamps over the berth (x, reach), for the light on its tops.
var lamps: Array[Vector2] = []
## The far and middle layers and the steam's shadow, which the host lays under the hull.
var back_layer: Control

var _front: ColorRect
var _back: ColorRect
var _shadow: ColorRect
var _fmat: ShaderMaterial
var _bmat: ShaderMaterial
var _smat: ShaderMaterial
var _lobes: Array = []
var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _fired := -1.0
var _acc := 0.0
var _burned := false
var _clearing := false
var _lk := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# every launch and landing its own steam (Jon, Nov 12)
	_rng.randomize()


## `w` x `h` is the host's picture; the steam may run `pad` px past each edge of it.
func setup(w: float, h: float, pad: float = 0.0) -> void:
	size = Vector2(w, h)
	back_layer = Control.new()
	back_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back_layer.size = size
	_smat = _material(pad)
	_smat.set_shader_parameter(&"shadow_pass", true)
	_shadow = _rect(_smat, pad)
	back_layer.add_child(_shadow)
	_bmat = _material(pad)
	_back = _rect(_bmat, pad)
	back_layer.add_child(_back)
	_fmat = _material(pad)
	_front = _rect(_fmat, pad)
	add_child(_front)
	_push()


func _material(pad: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/lift_plume.gdshader")
	m.set_shader_parameter(&"rect_size", size + Vector2(2.0 * pad, 2.0 * pad))
	m.set_shader_parameter(&"org", Vector2(-pad, -pad))
	var tones := PackedVector4Array()
	for c: Color in TONES:
		tones.append(Vector4(c.r, c.g, c.b, 1.0))
	m.set_shader_parameter(&"tones", tones)
	return m


func _rect(m: ShaderMaterial, pad: float) -> ColorRect:
	var r := ColorRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.position = Vector2(-pad, -pad)
	r.size = size + Vector2(2.0 * pad, 2.0 * pad)
	r.material = m
	return r


## Start it: the first billows go up at once.
func fire() -> void:
	_fired = _t
	for i in BURST:
		_spawn()


func fired() -> bool:
	return _fired >= 0.0


## How many lobes are in the air.
func puffs() -> int:
	return _lobes.size()


## The stands take the weight: a last puff off their tops.
func touchdown() -> void:
	for v in vents:
		_add(v + Vector2(_rng.randf_range(-3, 3), 0), Vector2(_rng.randf_range(-12, 12), -_rng.randf_range(20, 40)),
			_rng.randf_range(8, 11), 2, 0.0, 1.4)


## The floor and stands it lights this tick, as the yard's small lights
## (`YardLight.dyn`: x, y, radius x, y, strength, colour, beat).
func lights() -> Array:
	var out: Array = []
	var k := _lk
	if _fired < 0.0 or k <= 0.02:
		return out
	out.append([src.x, floor_y - 2.0, 150.0 * size_k, 46.0 * size_k, 1.6 * k, Color(1.0, 0.55, 0.22), 1.0])
	out.append([src.x, src.y + 4.0, 90.0 * size_k, 50.0 * size_k, 1.1 * k, Color(1.0, 0.75, 0.45), 1.0])
	return out


## The light's level now (the thrust, eased).
func light_level() -> float:
	return _lk


## Done: nothing of it left to draw.
func cleared() -> bool:
	return _clearing and _lobes.is_empty()


func _process(dt: float) -> void:
	_t += dt
	_lk += (thrust * strength - _lk) * (1.0 - exp(-dt / LIGHT_TC))
	if _fired < 0.0:
		return
	if thrust > 0.05:
		_burned = true
	elif _burned and not _clearing:
		_clear()
	if not _clearing:
		_acc += RATE * thrust * strength * dt
		while _acc >= 1.0:
			_acc -= 1.0
			_spawn()
	_step(dt)
	_push()


## THE JETS CUT: no more steam, and what is there thins, lifts and is gone within
## `CLEAR_S` (its alpha steps down through the dither, so nothing pops out).
func _clear() -> void:
	_clearing = true
	for l: Dictionary in _lobes:
		l.life = minf(float(l.life), float(l.age) + _rng.randf_range(CLEAR_S.x, CLEAR_S.y))
		l.buoy = float(l.buoy) + 10.0 * size_k


## One lobe: where, how fast, radius, its layer (0 far .. 2 near), warmth, life s.
func _add(at: Vector2, v: Vector2, r: float, layer: int, warm: float, life: float) -> void:
	if _lobes.size() >= MAX_LOBES * 2:
		_lobes.pop_front()
	_lobes.append({"p": at, "v": v, "r": r * size_k, "gr": _rng.randf_range(7, 12) * size_k, "layer": layer,
		"warm": warm, "life": life, "age": 0.0, "buoy": _rng.randf_range(6, 14) * size_k, "seed": _rng.randf()})


## A jet, by weight, and a spot either side of it.
func _jet() -> Vector2:
	if sources.is_empty():
		return Vector2(src.x + _rng.randf_range(-0.6, 0.6) * src_w, src.y)
	var q := sources[_rng.randi() % sources.size()]
	return Vector2(q.x + _rng.randf_range(-spread, spread), q.y)


## What goes up: a bank of billows off the floor under the jets, rolling out wide
## (some in front, some behind), pillars up past the nose and tail to the hull's top
## (behind, and some in front), steam off the stands' tops (in front), and now and
## then a thin wisp.
func _spawn() -> void:
	var s := size_k
	var side := -1.0 if _rng.randf() < 0.5 else 1.0
	var mid := hull.get_center().x if hull.size.x > 0.0 else src.x
	var half := 0.5 * hull.size.x if hull.size.x > 0.0 else src_w * 1.4
	var roll := _rng.randf()
	if roll < 0.5:
		var j := _jet()
		var near := _rng.randf() < 0.4
		# (a third of it stays under the jets and fills the middle)
		var out := _rng.randf_range(8, 45) if _rng.randf() < 0.35 else _rng.randf_range(60, 160)
		_add(Vector2(j.x, floor_y - 10.0 * s), Vector2(side * out * s, -_rng.randf_range(10, 30) * s),
			_rng.randf_range(13, 18), 2 if near else 1, 0.9, _rng.randf_range(2.4, 3.4))
	elif roll < 0.82:
		# up the sides, to about the hull's top
		# (behind the hull under it; in front only past its nose and tail)
		var layer := 0 if _rng.randf() < 0.35 else (2 if _rng.randf() < 0.25 else 1)
		var x := mid + side * half * (_rng.randf_range(0.95, 1.15) if layer == 2 else _rng.randf_range(0.55, 1.0))
		var up := clampf(floor_y - hull.position.y, 60.0 * s, 200.0 * s) if hull.size.y > 0.0 else 100.0 * s
		_add(Vector2(x, floor_y - 16.0 * s), Vector2(side * _rng.randf_range(6, 24) * s, -_rng.randf_range(0.5, 0.75) * up),
			_rng.randf_range(14, 20), layer, 0.25, _rng.randf_range(2.8, 3.8))
	elif roll < 0.93 and not vents.is_empty():
		var v: Vector2 = vents[_rng.randi() % vents.size()]
		_add(v + Vector2(_rng.randf_range(-3, 3), 0), Vector2(_rng.randf_range(-8, 8), -_rng.randf_range(18, 34) * s),
			_rng.randf_range(8, 11), 2, 0.0, _rng.randf_range(2.0, 2.8))
	else:
		_add(Vector2(mid + side * half * _rng.randf_range(0.6, 1.0), floor_y - 30.0 * s),
			Vector2(side * _rng.randf_range(40, 80) * s, -_rng.randf_range(40, 70) * s),
			_rng.randf_range(4, 6), 0, 0.0, _rng.randf_range(1.2, 1.8))


func _step(dt: float) -> void:
	var keep: Array = []
	var fl := floor_y - 4.0
	for l: Dictionary in _lobes:
		l.age = float(l.age) + dt
		if float(l.age) >= float(l.life):
			continue
		var v: Vector2 = l.v
		var pos: Vector2 = l.p
		v *= exp(-1.1 * dt)
		v.y -= float(l.buoy) * dt
		pos += v * dt
		if pos.y > fl:
			pos.y = fl
			v.y = minf(v.y, 0.0)
		l.v = v
		l.p = pos
		l.r = float(l.r) + float(l.gr) * dt * exp(-float(l.age) * 0.5)
		keep.append(l)
	_lobes = keep


func _push() -> void:
	if _fmat == null:
		return
	var back: Array = []
	var front: Array = []
	for l: Dictionary in _lobes:
		(front if int(l.layer) == 2 else back).append(l)
	# painted far to near, and within a layer top first, so the lower ones roll over
	back.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.layer) < int(b.layer) or (int(a.layer) == int(b.layer) and (a.p as Vector2).y < (b.p as Vector2).y))
	front.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a.p as Vector2).y < (b.p as Vector2).y)
	var lamp_arr := PackedVector2Array()
	lamp_arr.resize(8)
	for i in mini(8, lamps.size()):
		lamp_arr[i] = lamps[i]
	for pair: Array in [[_bmat, back], [_fmat, front], [_smat, _lobes]]:
		_fill(pair[0], pair[1], lamp_arr)


func _fill(m: ShaderMaterial, lobes: Array, lamp_arr: PackedVector2Array) -> void:
	var a := PackedVector4Array()
	var b := PackedVector4Array()
	a.resize(MAX_LOBES)
	b.resize(MAX_LOBES)
	var x0 := 1e9
	var y0 := 1e9
	var x1 := -1e9
	var y1 := -1e9
	var n := 0
	for l: Dictionary in lobes:
		if n >= MAX_LOBES:
			break
		var u := float(l.age) / float(l.life)
		var L: Array = LAYERS[int(l.layer)]
		# in over a sixth of a second, out over the last third of its life
		var fade := minf(1.0, float(l.age) * 6.0) * clampf((1.0 - u) / 0.35, 0.0, 1.0)
		var pos: Vector2 = (l.p as Vector2).floor()
		var r := floorf(float(l.r))
		a[n] = Vector4(pos.x, pos.y, maxf(3.0, r), float(L[0]) * fade)
		b[n] = Vector4(float(L[1]), float(L[2]), float(l.warm) * exp(-float(l.age) * 1.5) * _lk, float(l.seed))
		x0 = minf(x0, pos.x - r - 16.0)
		y0 = minf(y0, pos.y - r - 16.0)
		x1 = maxf(x1, pos.x + r + 16.0)
		y1 = maxf(y1, pos.y + r + 28.0)
		n += 1
	m.set_shader_parameter(&"n", n)
	m.set_shader_parameter(&"lobe", a)
	m.set_shader_parameter(&"lobe2", b)
	m.set_shader_parameter(&"tstep", floorf(_t * HZ))
	m.set_shader_parameter(&"box", Vector4(x0, y0, x1, y1) if n > 0 else Vector4(0, 0, -1, -1))
	m.set_shader_parameter(&"floor_y", floor_y)
	m.set_shader_parameter(&"nlamps", mini(8, lamps.size()))
	m.set_shader_parameter(&"lamps", lamp_arr)
