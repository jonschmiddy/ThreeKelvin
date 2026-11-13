class_name LiftPlume
extends Control

## THE STEAM a hull throws up as it lifts off or sets down (Jon's "AB-23", Nov 12):
## sculpted lobes in three layers of depth, every lift its own. All of it leaves the
## hull's jets: down to the floor in streams, pooled there, rolled out to both sides.
## The host (`ShipLift`) moves it with the hull, lays `back_layer` under the hull, and
## sets `thrust`; once the jets cut, it clears.
## Why: docs/why/ShipLift.md#plume

## The shape changes ten times a second (the steam's own clock), the lobes move every frame.
const HZ := 10.0
const MAX_LOBES := 64
## HOW HEAVY (Jon, Nov 13: "more smoke and it needs to be heavier"), as `weight`:
## 0 AB-23 as first built, 1 heavy, 2 heavier. Puffs a second, their size, the
## layers' alpha (far, mid, near), the ragged edge's share of it, the jets' push
## down and how fast it dies, the bank's roll out and how fast it slows, how much
## longer it lingers, how much it lifts, the curl's size, the floor shadow, the
## darker undersides; and once the jets cut, how long it takes to go (s), whether
## it lifts (+) or settles (-) as it goes, and how fast it spreads (px/s).
const WEIGHTS := [
	{"rate": 28.0, "size": 1.0, "alpha": [0.42, 0.8, 0.94], "edge": 0.5, "fall": 1.0, "fall_drag": 1.0,
		"out": 1.0, "roll_drag": 1.3, "linger": 0.0, "lift": 1.0, "curl": 1.0, "shadow": 0.34, "under": 0.0,
		"clear": Vector2(1.4, 2.0), "clear_lift": 10.0, "clear_spread": 0.0},
	{"rate": 32.0, "size": 1.35, "alpha": [0.62, 0.9, 1.0], "edge": 0.7, "fall": 1.15, "fall_drag": 0.8,
		"out": 0.75, "roll_drag": 1.5, "linger": 0.5, "lift": 0.5, "curl": 1.3, "shadow": 0.46, "under": 0.25,
		"clear": Vector2(4.0, 5.0), "clear_lift": -3.0, "clear_spread": 4.0},
	{"rate": 36.0, "size": 1.6, "alpha": [0.75, 0.95, 1.0], "edge": 0.82, "fall": 1.3, "fall_drag": 0.7,
		"out": 0.6, "roll_drag": 1.7, "linger": 0.8, "lift": 0.3, "curl": 1.5, "shadow": 0.56, "under": 0.4,
		"clear": Vector2(5.0, 6.0), "clear_lift": -4.0, "clear_spread": 5.0},
]
static var weight := 0
const BURST := 12
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
## The hull's jets' velocity (host px/s), eased; every puff born takes it along.
var _ship_v := Vector2.ZERO
var _w: Dictionary = WEIGHTS[0]
var _nback := 0
var _nfront := 0
var _last_src := Vector2(INF, INF)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# every launch and landing its own steam (Jon, Nov 12)
	_rng.randomize()
	_w = WEIGHTS[clampi(weight, 0, WEIGHTS.size() - 1)]


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
	m.set_shader_parameter(&"edge_a", float(_w.edge))
	m.set_shader_parameter(&"under_k", float(_w.under))
	m.set_shader_parameter(&"shadow_k", float(_w.shadow))
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


## The stands take the weight: a last breath out of the jets.
func touchdown() -> void:
	for i in 6:
		_spawn()


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
	if dt > 0.0:
		var sv := Vector2.ZERO if _last_src.x == INF else ((src - _last_src) / dt).limit_length(600.0)
		_ship_v = _ship_v.lerp(sv, 1.0 - exp(-dt / 0.08))
		_last_src = src
	if _fired < 0.0:
		return
	if thrust > 0.05:
		_burned = true
	elif _burned and not _clearing:
		_clear()
	if not _clearing:
		# (a weak burn thins the steam more than it spaces it out: the streams stay streams)
		_acc += float(_w.rate) * thrust * (0.5 + 0.5 * minf(strength, 1.0)) * dt
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
		var c: Vector2 = _w.clear
		# (all of it given the full clearing: the heavy weights linger past a puff's own life)
		l.life = float(l.age) + _rng.randf_range(c.x, c.y) * (1.0 if bool(l.roll) else 0.5)
		l.c0 = float(l.age)
		l.buoy = float(l.buoy) + float(_w.clear_lift) * size_k


## One lobe, born at the hull: where, how fast, radius, its layer (0 far .. 2 near),
## warmth, life s. It falls (`roll` false) until it reaches the floor.
func _add(at: Vector2, v: Vector2, r: float, layer: int, warm: float, life: float) -> void:
	# (full: no new puff, rather than an old one gone at once)
	if (_nback if layer < 2 else _nfront) >= MAX_LOBES:
		return
	if layer < 2:
		_nback += 1
	else:
		_nfront += 1
	_lobes.append({"p": at, "d": at, "v": v, "c0": -1.0, "r": r * size_k * float(_w.size), "gr": _rng.randf_range(7, 12) * size_k, "layer": layer,
		"warm": warm, "life": life, "age": 0.0, "buoy": _rng.randf_range(3, 7) * size_k * float(_w.lift), "seed": _rng.randf(),
		"k": clampf(0.4 + 0.6 * strength, 0.0, 1.0), "roll": false, "rolled": 0.0, "side": 1.0, "R": 0.0, "phi": 0.0, "w": 0.0})


## A jet, by weight, and a spot either side of it.
func _jet() -> Vector2:
	if sources.is_empty():
		return Vector2(src.x + _rng.randf_range(-0.6, 0.6) * src_w, src.y)
	var q := sources[_rng.randi() % sources.size()]
	return Vector2(q.x + _rng.randf_range(-spread, spread), q.y)


## THE SHIP IS THE SOURCE (Jon, Nov 12): every puff leaves a belly jet, driven straight
## down. Whatever reaches the floor pools there and rolls out sideways from under the
## hull; what does not (the hull too high) thins out in the air.
func _spawn() -> void:
	var j := _jet()
	var q := _rng.randf()
	var layer := 0 if q < 0.3 else (1 if q < 0.7 else 2)
	# (carried along with the hull: its velocity, which fades as the puff falls)
	_add(Vector2(j.x, j.y + 2.0), _ship_v + Vector2(_rng.randf_range(-8, 8) * size_k, _rng.randf_range(230, 300) * size_k * float(_w.fall)),
		_rng.randf_range(7, 10), layer, 0.9, _rng.randf_range(0.8, 1.1))


## Falling: the jet's push dies off as it goes. On the floor it turns into the bank:
## out from under the hull, slowing, each lobe riding a roll at the front (low and
## forward, up the front, back over the top: Jon's curl), and late on lifting a little.
func _step(dt: float) -> void:
	var keep: Array = []
	var mid := hull.get_center().x if hull.size.x > 0.0 else src.x
	var half := 0.5 * hull.size.x if hull.size.x > 0.0 else src_w * 1.4
	for l: Dictionary in _lobes:
		l.age = float(l.age) + dt
		if float(l.age) >= float(l.life):
			continue
		var v: Vector2 = l.v
		var pos: Vector2 = l.p
		var r := float(l.r)
		if not bool(l.roll):
			v *= exp(-float(_w.fall_drag) * dt)
			pos += v * dt
			l.r = r + float(l.gr) * 0.6 * dt
			if pos.y + 0.4 * r >= floor_y:
				_land(l, pos, mid, half)
				pos = l.p
				v = l.v
			l.d = pos
		else:
			l.rolled = float(l.rolled) + dt
			v.x *= exp(-float(_w.roll_drag) * dt)
			v.y = -float(l.buoy) * clampf(float(l.rolled) - 1.0, 0.0, 1.0)
			pos += v * dt
			l.phi = minf(float(l.phi) + float(l.w) * dt * exp(-float(l.rolled) * 0.4), 1.3 * PI)
			l.r = r + float(l.gr) * dt * exp(-float(l.rolled) * 0.5)
			# (going, a heavy bank settles and spreads as it thins)
			if float(l.c0) >= 0.0:
				l.r = float(l.r) + float(_w.clear_spread) * size_k * dt
				pos.y = minf(pos.y, floor_y - 0.3 * float(l.r))
			var rr := float(l.R)
			l.d = pos + Vector2(float(l.side) * rr * sin(float(l.phi)), rr * cos(float(l.phi)))
		l.v = v
		l.p = pos
		keep.append(l)
	_lobes = keep
	_nback = 0
	_nfront = 0
	for l: Dictionary in _lobes:
		if int(l.layer) < 2:
			_nback += 1
		else:
			_nfront += 1


## A falling lobe reaches the floor: a third pools under the hull, the rest roll out,
## each side away from the middle.
func _land(l: Dictionary, at: Vector2, mid: float, half: float) -> void:
	var s := size_k
	var off := at.x - mid
	var side := signf(off) if absf(off) > 0.12 * half else (-1.0 if _rng.randf() < 0.5 else 1.0)
	var rr := _rng.randf_range(8, 16) * s * float(_w.curl)
	var out := (_rng.randf_range(10, 35) if _rng.randf() < 0.3 else _rng.randf_range(70, 150)) * float(_w.out)
	# the floor takes the splash: it spreads at once
	l.r = maxf(float(l.r), _rng.randf_range(13, 17) * s * float(_w.size))
	l.gr = _rng.randf_range(10, 16) * s * float(_w.size)
	l.roll = true
	l.side = side
	l.R = rr
	l.phi = 0.0
	l.w = _rng.randf_range(1.6, 2.8)
	l.p = Vector2(at.x, floor_y - rr - 0.4 * float(l.r))
	# (and shifted the way the hull was going, by what of its push is left)
	l.v = Vector2(side * out * s + 0.6 * (l.v as Vector2).x, 0.0)
	l.life = float(l.age) + _rng.randf_range(2.0, 2.8) + float(_w.linger)


func _push() -> void:
	if _fmat == null:
		return
	var back: Array = []
	var front: Array = []
	for l: Dictionary in _lobes:
		(front if int(l.layer) == 2 else back).append(l)
	# painted far to near, and within a layer top first, so the lower ones roll over
	back.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.layer) < int(b.layer) or (int(a.layer) == int(b.layer) and (a.d as Vector2).y < (b.d as Vector2).y))
	front.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a.d as Vector2).y < (b.d as Vector2).y)
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
		# (going: a slow thinning over the whole of what is left of it)
		if float(l.c0) >= 0.0:
			fade = minf(fade, clampf((float(l.life) - float(l.age)) / maxf(0.01, float(l.life) - float(l.c0)), 0.0, 1.0))
		var pos: Vector2 = (l.d as Vector2).floor()
		var r := floorf(float(l.r))
		a[n] = Vector4(pos.x, pos.y, maxf(3.0, r), float((_w.alpha as Array)[int(l.layer)]) * fade * float(l.k))
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
