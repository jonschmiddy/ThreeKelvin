class_name LiftPlume
extends Control

## TRIAL (not for landing): the smoke a hull throws on the floor as it lifts off
## or sets down. One effect for the front door's LAUNCH and the Shipyard deck's
## undock and landing (Jon, Nov 12: "something sick and powerful"). Six ideas
## (`style` 1-6, `-- plume=P1..P6`); the host moves `src` with the hull and
## sets `thrust` every frame, and lights its floor from `lights()`.
##   P1 rolling ground cloud   P2 column punched down, then mushrooming
##   P3 jet wash: streaks, sparks, debris   P4 steam bursting from the stands
##   P5 dense dark exhaust, orange inside   P6 a dust ring, then a slow billow

## The shape changes ten times a second (fire's rate), the puffs move every frame.
const HZ := 10.0
const MAX_PUFFS := 64
const NAMES := ["", "Rolling ground cloud", "Column, then mushroom", "Jet wash, sparks and debris",
	"Steam from the stands", "Dense dark exhaust", "Dust ring, then a slow billow"]

var style: int = 1
## Knobs: how big, how hard, and the floor row it rolls on.
var size_k: float = 1.0
var strength: float = 1.0
var floor_y: float = 372.0
## The hull's belly middle and half its length (hall px), this frame.
var src := Vector2(480, 300)
var src_w: float = 60.0
## 0..1, set by the host each frame: how hard the lift jets burn.
var thrust: float = 0.0
## P4's vents: points on the stands the steam bursts from.
var vents: Array[Vector2] = []

var _smoke: ColorRect
var _mat: ShaderMaterial
var _bits: Control
var _puffs: Array = []
var _sparks: Array = []
var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _fired := -1.0
var _acc := 0.0
var _ring := Vector4.ZERO


static func style_arg(fallback: int = 1) -> int:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("plume=P") or a.begins_with("plume=p"):
			return clampi(int(a.substr(7)), 1, 6)
	return fallback


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	_bits = Control.new()
	_bits.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bits.size = size
	_bits.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bits.draw.connect(_draw_bits)
	add_child(_bits)
	_push()


## Start it: the first blast goes out at once.
func fire() -> void:
	_fired = _t
	match style:
		2:
			for i in 10:
				_spawn()
		4:
			for v in vents:
				for k in 6:
					var dir := -1.0 if k % 2 == 0 else 1.0
					_add(v + Vector2(dir * 2.0, 0), Vector2(dir * _rng.randf_range(160, 300), _rng.randf_range(-30, 6)) * size_k,
						4.0, 30.0, 0.9, 1.4, 0.15, 2.4, 0.7, 1.0, 2.2, 4.0)
		6:
			_ring = Vector4(src.x, floor_y, 6.0, 1.0)
			for i in 6:
				_spawn()
		_:
			for i in 24:
				_spawn()


func fired() -> bool:
	return _fired >= 0.0


## The floor and stands it lights this tick, as the yard's small lights
## (`YardLight.dyn`: x, y, radius x, y, strength, colour, beat).
func lights() -> Array:
	var out: Array = []
	if _fired < 0.0:
		return out
	var k := thrust * strength
	var warm := Color(1.0, 0.55, 0.22) if style != 4 else Color(1.0, 0.7, 0.45)
	if k > 0.02:
		var flick := 0.85 + 0.15 * YardLight.hash1(floorf(_t * HZ) * 1.37)
		out.append([src.x, floor_y - 2.0, 150.0 * size_k, 46.0 * size_k, 1.6 * k, warm, flick])
		out.append([src.x, src.y + 4.0, 90.0 * size_k, 50.0 * size_k, 1.1 * k, Color(1.0, 0.75, 0.45), flick])
	var hot := 0.0
	for p: Dictionary in _puffs:
		hot += float(p.heat) * maxf(0.0, 1.0 - float(p.age) / 1.2)
	hot = minf(hot / 8.0, 1.0) * strength
	if hot > 0.05 and style == 5:
		out.append([src.x, floor_y - 10.0, 200.0 * size_k, 60.0 * size_k, 0.9 * hot, Color(1.0, 0.45, 0.15), 1.0])
	if style == 6 and _ring.w > 0.05:
		out.append([_ring.x, _ring.y, _ring.z + 30.0, (_ring.z + 30.0) * 0.25, 0.7 * _ring.w, Color(0.95, 0.85, 0.7), 1.0])
	return out


func _process(dt: float) -> void:
	_t += dt
	if _fired < 0.0:
		return
	var rate := _rate() * thrust * strength
	_acc += rate * dt
	while _acc >= 1.0:
		_acc -= 1.0
		_spawn()
	_step(dt)
	_push()
	_bits.queue_redraw()


func _rate() -> float:
	match style:
		1: return 46.0
		2: return 38.0
		3: return 40.0
		4: return 26.0
		5: return 34.0
		6: return 16.0
	return 30.0


## One puff: where, how fast, radius, growth px/s, density, life s, heat, stretch,
## cool (steam), drag, buoyancy (px/s^2 up).
func _add(at: Vector2, v: Vector2, r: float, gr: float, d: float, life: float, heat: float,
		sx: float, sy: float, cool: float, drag: float, buoy: float, kind: int = 0) -> void:
	if _puffs.size() >= MAX_PUFFS:
		_puffs.pop_front()
	_puffs.append({"p": at, "v": v, "r": r * size_k, "gr": gr * size_k, "d": d, "life": life, "age": 0.0,
		"heat": heat, "sx": sx, "sy": sy, "cool": cool, "drag": drag, "buoy": buoy * size_k, "kind": kind})


func _spawn() -> void:
	var s := size_k
	var side := -1.0 if _rng.randf() < 0.5 else 1.0
	var bx := src.x + _rng.randf_range(-0.6, 0.6) * src_w
	match style:
		1:
			# some roll out along the floor, some tumble up out of the bank
			var up := _rng.randf() < 0.35
			_add(Vector2(bx, floor_y - 8.0), Vector2(side * _rng.randf_range(110, 250) * s * (0.6 if up else 1.0), -_rng.randf_range(40, 90) if up else _rng.randf_range(-30, 0)),
				_rng.randf_range(12, 22), 40.0, _rng.randf_range(0.75, 1.0), _rng.randf_range(3.0, 4.6), 0.9, _rng.randf_range(1.1, 1.5), _rng.randf_range(0.85, 1.2), 0.0, 1.5, 26.0 if up else 14.0)
		2:
			_add(Vector2(src.x + _rng.randf_range(-0.35, 0.35) * src_w, src.y + 3.0), Vector2(_rng.randf_range(-14, 14), _rng.randf_range(250, 340) * s),
				_rng.randf_range(7, 10), 10.0, _rng.randf_range(0.8, 1.0), _rng.randf_range(2.8, 4.0), 1.4, 0.8, 1.25, 0.0, 0.2, 0.0, 1)
		3:
			_add(Vector2(bx, floor_y - 5.0), Vector2(side * _rng.randf_range(300, 480) * s, _rng.randf_range(-14, 0)),
				_rng.randf_range(9, 13), 20.0, _rng.randf_range(0.8, 1.0), _rng.randf_range(1.0, 1.7), 0.9, 3.0, 0.65, 0.0, 2.2, 3.0)
			for k in 2:
				_sparks.append({"p": Vector2(bx, src.y + 2.0), "v": Vector2(_rng.randf_range(-260, 260), _rng.randf_range(-60, 140)) * s,
					"age": 0.0, "life": _rng.randf_range(0.35, 0.9), "kind": 0})
			if _rng.randf() < 0.45:
				_sparks.append({"p": Vector2(bx, floor_y - 1.0), "v": Vector2(side * _rng.randf_range(90, 260), -_rng.randf_range(60, 170)) * s,
					"age": 0.0, "life": _rng.randf_range(1.0, 1.8), "kind": 1})
		4:
			if vents.is_empty():
				return
			var v: Vector2 = vents[_rng.randi() % vents.size()]
			_add(v + Vector2(_rng.randf_range(-3, 3), 0), Vector2(_rng.randf_range(-40, 40), -_rng.randf_range(30, 90)) * s,
				_rng.randf_range(7, 11), 20.0, _rng.randf_range(0.6, 0.9), _rng.randf_range(2.6, 3.8), 0.2, 1.1, 1.0, 1.0, 0.9, 16.0)
			_add(Vector2(bx, floor_y - 4.0), Vector2(side * _rng.randf_range(90, 170) * s, _rng.randf_range(-16, 0)),
				_rng.randf_range(7, 10), 20.0, 0.55, _rng.randf_range(2.0, 3.0), 0.5, 1.6, 0.8, 0.7, 1.4, 5.0)
		5:
			_add(Vector2(src.x + _rng.randf_range(-0.4, 0.4) * src_w, src.y + 4.0), Vector2(_rng.randf_range(-50, 50), _rng.randf_range(110, 190) * s),
				_rng.randf_range(13, 19), 17.0, _rng.randf_range(1.0, 1.3), _rng.randf_range(3.6, 5.0), 0.75, 1.2, 1.0, 0.0, 0.8, 0.0, 1)
			if _rng.randf() < 0.5:
				_sparks.append({"p": Vector2(bx, floor_y - 6.0), "v": Vector2(_rng.randf_range(-60, 60), -_rng.randf_range(30, 90)) * s,
					"age": 0.0, "life": _rng.randf_range(0.8, 1.6), "kind": 2})
		6:
			_add(Vector2(bx, floor_y - 6.0), Vector2(side * _rng.randf_range(20, 70) * s, -_rng.randf_range(10, 34)),
				_rng.randf_range(14, 20), 15.0, _rng.randf_range(0.7, 0.95), _rng.randf_range(4.0, 5.5), 0.7, 1.4, 0.9, 0.0, 0.6, 9.0)


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
		# a puff punched down hits the floor and rolls out along it
		if int(p.kind) == 1 and pos.y >= fl:
			pos.y = fl
			var side := -1.0 if v.x < 0.0 else 1.0
			if absf(v.x) < 30.0:
				side = -1.0 if _rng.randf() < 0.5 else 1.0
			var sp := v.y
			v = Vector2(side * sp * _rng.randf_range(0.5, 0.75), -sp * (0.12 if style == 5 else 0.18))
			p.kind = 0
			p.sx = 1.4
			p.sy = 0.9
			p.gr = float(p.gr) * 2.4
			p.drag = 1.3
			p.buoy = (24.0 if style == 2 else 8.0) * size_k
		elif pos.y > fl + 8.0:
			pos.y = fl + 8.0
			v.y = minf(v.y, 0.0)
		p.v = v
		p.p = pos
		p.r = float(p.r) + float(p.gr) * dt * exp(-float(p.age) * 0.6)
		keep.append(p)
	_puffs = keep
	var ks: Array = []
	for s: Dictionary in _sparks:
		s.age = float(s.age) + dt
		if float(s.age) >= float(s.life):
			continue
		var v2: Vector2 = s.v
		var g := 420.0 if int(s.kind) == 0 else (520.0 if int(s.kind) == 1 else -20.0)
		v2.y += g * dt
		var p2: Vector2 = s.p
		s.last = p2
		p2 += v2 * dt
		if p2.y > floor_y and int(s.kind) != 2:
			p2.y = floor_y
			v2.y = -v2.y * 0.35
			v2.x *= 0.7
		s.v = v2
		s.p = p2
		ks.append(s)
	_sparks = ks
	if _ring.w > 0.0:
		var u := _t - _fired
		_ring.z = 6.0 + 430.0 * size_k * (1.0 - pow(1.0 - clampf(u / 0.8, 0.0, 1.0), 3.0))
		_ring.w = clampf(1.0 - u / 0.9, 0.0, 1.0) * strength


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
		b[n] = Vector4(float(p.heat) * exp(-float(p.age) * (1.6 if style == 5 else 4.5)), float(p.sx), float(p.sy), float(p.cool))
		var ext := r * maxf(float(p.sx), float(p.sy)) + 24.0
		x0 = minf(x0, pos.x - ext)
		y0 = minf(y0, pos.y - ext)
		x1 = maxf(x1, pos.x + ext)
		y1 = maxf(y1, pos.y + ext)
		n += 1
	if _ring.w > 0.0:
		x0 = minf(x0, _ring.x - _ring.z - 10.0)
		x1 = maxf(x1, _ring.x + _ring.z + 10.0)
		y0 = minf(y0, _ring.y - _ring.z * 0.25 - 10.0)
		y1 = maxf(y1, _ring.y + _ring.z * 0.25 + 10.0)
	_mat.set_shader_parameter(&"n", n)
	_mat.set_shader_parameter(&"puff", a)
	_mat.set_shader_parameter(&"puff2", b)
	_mat.set_shader_parameter(&"ring", _ring)
	_mat.set_shader_parameter(&"tstep", floorf(_t * HZ))
	_mat.set_shader_parameter(&"box", Vector4(x0, y0, x1, y1) if n > 0 or _ring.w > 0.0 else Vector4(0, 0, -1, -1))
	_mat.set_shader_parameter(&"floor_y", floor_y)
	_mat.set_shader_parameter(&"dark", 1.0 if style == 5 else 0.0)
	_mat.set_shader_parameter(&"turb", 1.25 if style == 5 or style == 2 else 1.0)
	var k := thrust * strength
	_mat.set_shader_parameter(&"src", Vector4(src.x, floor_y - 8.0, maxf(30.0, src_w * 1.1) * size_k, 0.8 * k))


## Sparks (light), embers, and the debris thrown off the floor (dark).
func _draw_bits() -> void:
	for s: Dictionary in _sparks:
		var p: Vector2 = (s.p as Vector2).floor()
		var a := float(s.age) / float(s.life)
		match int(s.kind):
			0:
				var col := Color("#ffffff") if a < 0.15 else (Color("#ffe9a8") if a < 0.4 else (Color("#ffb347") if a < 0.7 else Color("#c0501a")))
				var l: Vector2 = (s.get("last", s.p) as Vector2).floor()
				_bits.draw_line(l + Vector2(0.5, 0.5), p + Vector2(0.5, 0.5), Color(col, 0.6), 1.0)
				_bits.draw_rect(Rect2(p, Vector2(1, 1)), col)
			1:
				_bits.draw_rect(Rect2(p, Vector2(2, 1) if a < 0.5 else Vector2(1, 1)), Color("#2a2622"))
				_bits.draw_rect(Rect2(p + Vector2(0, -1), Vector2(1, 1)), Color("#5a524a"))
			2:
				var flick := YardLight.hash1(floorf(_t * HZ) + p.x) > 0.3
				if flick:
					_bits.draw_rect(Rect2(p, Vector2(1, 1)), Color("#ffb347") if a < 0.5 else Color("#c0501a"))
