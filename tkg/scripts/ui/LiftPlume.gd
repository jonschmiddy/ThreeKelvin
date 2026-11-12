class_name LiftPlume
extends Control

## THE SMOKE a hull throws on the floor as it lifts off or sets down (Jon's P1, the
## rolling ground cloud). The host (`ShipLift`) moves its sources with the hull,
## sets `thrust` every frame and lights the floor from `lights()`.
## Why: docs/why/ShipLift.md#plume

## The shape changes ten times a second (fire's rate), the puffs move every frame.
const HZ := 10.0
const MAX_PUFFS := 64
const RATE := 46.0
const BURST := 24

## Knobs: how big, how hard, and the floor row it rolls on.
var size_k: float = 1.0
var strength: float = 1.0
var floor_y: float = 372.0
## The hull's belly middle and half its length (host px), this frame.
var src := Vector2(480, 300)
var src_w: float = 60.0
## 0..1, set by the host each frame: how hard the lift jets burn.
var thrust: float = 0.0
## Where under the hull the smoke comes from this frame: (x, belly row, weight),
## and how far either side of each it starts. Empty: across `src_w` of `src`.
var sources: Array[Vector3] = []
var spread: float = 10.0

var _smoke: ColorRect
var _mat: ShaderMaterial
var _puffs: Array = []
var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _fired := -1.0
var _acc := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# (cosmetic, but the same smoke every time: films compare like for like)
	_rng.seed = 7


## `w` x `h` is the host's picture; the smoke may run `pad` px past each edge of it.
func setup(w: float, h: float, pad: float = 0.0) -> void:
	size = Vector2(w, h)
	_smoke = ColorRect.new()
	_smoke.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_smoke.position = Vector2(-pad, -pad)
	_smoke.size = size + Vector2(2.0 * pad, 2.0 * pad)
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/lift_plume.gdshader")
	_mat.set_shader_parameter(&"rect_size", _smoke.size)
	_mat.set_shader_parameter(&"org", _smoke.position)
	_smoke.material = _mat
	add_child(_smoke)
	_push()


## Start it: the first blast goes out at once.
func fire() -> void:
	_fired = _t
	for i in BURST:
		_spawn()


func fired() -> bool:
	return _fired >= 0.0


## How many puffs are in the air.
func puffs() -> int:
	return _puffs.size()


## The floor and stands it lights this tick, as the yard's small lights
## (`YardLight.dyn`: x, y, radius x, y, strength, colour, beat).
func lights() -> Array:
	var out: Array = []
	var k := thrust * strength
	if _fired < 0.0 or k <= 0.02:
		return out
	var flick := 0.85 + 0.15 * YardLight.hash1(floorf(_t * HZ) * 1.37)
	out.append([src.x, floor_y - 2.0, 150.0 * size_k, 46.0 * size_k, 1.6 * k, Color(1.0, 0.55, 0.22), flick])
	out.append([src.x, src.y + 4.0, 90.0 * size_k, 50.0 * size_k, 1.1 * k, Color(1.0, 0.75, 0.45), flick])
	return out


func _process(dt: float) -> void:
	_t += dt
	if _fired < 0.0:
		return
	_acc += RATE * thrust * strength * dt
	while _acc >= 1.0:
		_acc -= 1.0
		_spawn()
	_step(dt)
	_push()


## One puff: where, how fast, radius, growth px/s, density, life s, heat, stretch,
## drag, buoyancy (px/s^2 up).
func _add(at: Vector2, v: Vector2, r: float, gr: float, d: float, life: float, heat: float,
		sx: float, sy: float, drag: float, buoy: float) -> void:
	if _puffs.size() >= MAX_PUFFS:
		_puffs.pop_front()
	_puffs.append({"p": at, "v": v, "r": r * size_k, "gr": gr * size_k, "d": d, "life": life, "age": 0.0,
		"heat": heat, "sx": sx, "sy": sy, "drag": drag, "buoy": buoy * size_k})


## The rolling ground cloud: some roll out along the floor, some tumble up out of the bank.
func _spawn() -> void:
	var s := size_k
	var side := -1.0 if _rng.randf() < 0.5 else 1.0
	var bx := src.x + _rng.randf_range(-0.6, 0.6) * src_w
	if not sources.is_empty():
		var tot := 0.0
		for q in sources:
			tot += q.z
		var pick := _rng.randf() * tot
		for q in sources:
			pick -= q.z
			if pick <= 0.0:
				bx = q.x + _rng.randf_range(-spread, spread)
				break
	var up := _rng.randf() < 0.35
	var vx := side * _rng.randf_range(110, 250) * s * (0.6 if up else 1.0)
	var vy := -_rng.randf_range(40, 90) * s if up else _rng.randf_range(-30, 0) * s
	_add(Vector2(bx, floor_y - 8.0 * s), Vector2(vx, vy), _rng.randf_range(12, 22), 40.0, _rng.randf_range(0.75, 1.0),
		_rng.randf_range(3.0, 4.6), 0.9, _rng.randf_range(1.1, 1.5), _rng.randf_range(0.85, 1.2), 1.5, 26.0 if up else 14.0)


func _step(dt: float) -> void:
	var keep: Array = []
	var fl := floor_y - 2.0
	for p: Dictionary in _puffs:
		p.age = float(p.age) + dt
		if float(p.age) >= float(p.life):
			continue
		var v: Vector2 = p.v
		var pos: Vector2 = p.p
		v *= exp(-float(p.drag) * dt)
		v.y -= float(p.buoy) * dt
		pos += v * dt
		if pos.y > fl + 8.0:
			pos.y = fl + 8.0
			v.y = minf(v.y, 0.0)
		p.v = v
		p.p = pos
		p.r = float(p.r) + float(p.gr) * dt * exp(-float(p.age) * 0.6)
		keep.append(p)
	_puffs = keep


func _push() -> void:
	if _mat == null:
		return
	var a := PackedVector4Array()
	var b := PackedVector4Array()
	a.resize(MAX_PUFFS)
	b.resize(MAX_PUFFS)
	var x0 := 1e9
	var y0 := 1e9
	var x1 := -1e9
	var y1 := -1e9
	var n := 0
	for p: Dictionary in _puffs:
		var u := float(p.age) / float(p.life)
		var d := float(p.d) * (1.0 - u * u) * minf(1.0, float(p.age) * 12.0 + 0.3)
		var pos: Vector2 = (p.p as Vector2).floor()
		var r := floorf(float(p.r))
		a[n] = Vector4(pos.x, pos.y, maxf(2.0, r), d)
		b[n] = Vector4(float(p.heat) * exp(-float(p.age) * 4.5), float(p.sx), float(p.sy), 0.0)
		var ext := r * maxf(float(p.sx), float(p.sy)) + 24.0
		x0 = minf(x0, pos.x - ext)
		y0 = minf(y0, pos.y - ext)
		x1 = maxf(x1, pos.x + ext)
		y1 = maxf(y1, pos.y + ext)
		n += 1
	_mat.set_shader_parameter(&"n", n)
	_mat.set_shader_parameter(&"puff", a)
	_mat.set_shader_parameter(&"puff2", b)
	_mat.set_shader_parameter(&"tstep", floorf(_t * HZ))
	_mat.set_shader_parameter(&"box", Vector4(x0, y0, x1, y1) if n > 0 else Vector4(0, 0, -1, -1))
	_mat.set_shader_parameter(&"floor_y", floor_y)
	var k := thrust * strength
	_mat.set_shader_parameter(&"src", Vector4(src.x, floor_y - 8.0, maxf(30.0, src_w * 1.1) * size_k, 0.8 * k))
