class_name LiftPlume
extends Control

## THE SMOKE a hull throws on the floor as it lifts off or sets down (Jon's P1, the
## rolling ground cloud). The host (`ShipLift`) moves its sources with the hull,
## sets `thrust` every frame and lights the floor from `lights()`; once the jets
## cut, it thins, spreads, lifts and clears (`_clearing`).
## Why: docs/why/ShipLift.md#plume

## The shape changes ten times a second (fire's rate), the puffs move every frame.
const HZ := 10.0
const MAX_PUFFS := 64
const RATE := 46.0
const BURST := 24
## Once the jets cut, every puff is gone within this many seconds (Jon, Nov 12:
## "The smoke should also dissipate when landing").
const CLEAR_S := Vector2(1.4, 2.0)
## TRIAL (`-- smoke=S1|S2|S3`, Jon's look at other smoke, Nov 12): S1 launch-pad
## billows, S2 jet wash and dust, S3 vapour vents. P1a without the flag.
const KINDS := ["P1a", "S1", "S2", "S3"]

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
## The stands' tops (host px, this frame), where S3's vapour also vents.
var vents: Array[Vector2] = []
var kind := "P1a"

var _smoke: ColorRect
var _mat: ShaderMaterial
var _haze: ColorRect = null
var _hmat: ShaderMaterial = null
var _bits: Control = null
var _grit: Array = []
var _puffs: Array = []
var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _fired := -1.0
var _acc := 0.0
var _acc_g := 0.0
var _next_burst := 0.0
var _burned := false
var _clearing := false
## The light it gives, easing after the thrust over a few tenths of a second: steady,
## never stepping frame to frame (Jon's F1, Nov 12).
var _lk := 0.0
const LIGHT_TC := 0.15


static func kind_arg() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("smoke=") and a.substr(6).to_upper() in KINDS:
			return a.substr(6).to_upper() if a.substr(6).to_upper() != "P1A" else "P1a"
	return "P1a"


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# (cosmetic, but the same smoke every time: films compare like for like)
	_rng.seed = 7
	kind = kind_arg()


## `w` x `h` is the host's picture; the smoke may run `pad` px past each edge of it.
func setup(w: float, h: float, pad: float = 0.0) -> void:
	size = Vector2(w, h)
	if kind == "S2":
		# the heat haze reads the picture under it, so it goes in first, under the dust
		_haze = ColorRect.new()
		_haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_haze.size = size
		_hmat = ShaderMaterial.new()
		_hmat.shader = preload("res://shaders/lift_haze.gdshader")
		_hmat.set_shader_parameter(&"rect_size", size)
		_haze.material = _hmat
		add_child(_haze)
	_smoke = ColorRect.new()
	_smoke.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_smoke.position = Vector2(-pad, -pad)
	_smoke.size = size + Vector2(2.0 * pad, 2.0 * pad)
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/lift_plume.gdshader")
	_mat.set_shader_parameter(&"rect_size", _smoke.size)
	_mat.set_shader_parameter(&"org", _smoke.position)
	_palette()
	_smoke.material = _mat
	add_child(_smoke)
	if kind == "S2":
		_bits = Control.new()
		_bits.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bits.size = size
		_bits.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_bits.draw.connect(_draw_grit)
		add_child(_bits)
	_push()


## Each kind's smoke in the yard's colours: how it is lit and how dense it reads.
func _palette() -> void:
	match kind:
		"S1":
			# heavy billows: grey-black above and at the edges, the engines' orange under them
			_set_pal(Vector3(0.07, 0.07, 0.08), Vector3(0.15, 0.15, 0.17), Vector3(0.26, 0.26, 0.28), Vector3(0.36, 0.36, 0.38))
			_mat.set_shader_parameter(&"top_light", 0.0)
			_mat.set_shader_parameter(&"floor_glow", 1.3)
			_mat.set_shader_parameter(&"turb", 0.75)
		"S2":
			# a low skirt of floor dust
			_set_pal(Vector3(0.2, 0.18, 0.15), Vector3(0.3, 0.27, 0.22), Vector3(0.41, 0.37, 0.31), Vector3(0.5, 0.46, 0.38))
			_mat.set_shader_parameter(&"glow_k", 0.15)
			_mat.set_shader_parameter(&"alpha_k", 0.75)
		"S3":
			# white-grey vapour, a mist that hangs low
			_set_pal(Vector3(0.46, 0.5, 0.54), Vector3(0.6, 0.64, 0.68), Vector3(0.74, 0.78, 0.81), Vector3(0.86, 0.89, 0.91))
			_mat.set_shader_parameter(&"glow_k", 0.25)
			_mat.set_shader_parameter(&"alpha_k", 0.8)


func _set_pal(d: Vector3, m: Vector3, l: Vector3, t: Vector3) -> void:
	_mat.set_shader_parameter(&"c_dark", d)
	_mat.set_shader_parameter(&"c_mid", m)
	_mat.set_shader_parameter(&"c_lite", l)
	_mat.set_shader_parameter(&"c_top", t)


## Start it: the first blast goes out at once.
func fire() -> void:
	_fired = _t
	match kind:
		"S2":
			for i in 8:
				_spawn()
			for i in 40:
				_spawn_grit()
		"S3":
			_burst(1.0)
		_:
			for i in (32 if kind == "S1" else BURST):
				_spawn()


func fired() -> bool:
	return _fired >= 0.0


## How many puffs are in the air.
func puffs() -> int:
	return _puffs.size()


## The stands take the weight: S3's vents puff, the others' smoke is already clearing.
func touchdown() -> void:
	if kind == "S3":
		_burst(0.8, true)


## The floor and stands it lights this tick, as the yard's small lights
## (`YardLight.dyn`: x, y, radius x, y, strength, colour, beat).
func lights() -> Array:
	var out: Array = []
	var k := _lk
	if _fired < 0.0 or k <= 0.02:
		return out
	var floor_k := 2.0 if kind == "S1" else (1.6 if kind == "P1a" else 1.0)
	out.append([src.x, floor_y - 2.0, 150.0 * size_k, 46.0 * size_k, floor_k * k, Color(1.0, 0.55, 0.22), 1.0])
	out.append([src.x, src.y + 4.0, 90.0 * size_k, 50.0 * size_k, 1.1 * k, Color(1.0, 0.75, 0.45), 1.0])
	return out


## The light's level now (the thrust, eased).
func light_level() -> float:
	return _lk


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
		match kind:
			"S2":
				_acc += 14.0 * thrust * strength * dt
				_acc_g += 110.0 * thrust * strength * dt
				while _acc_g >= 1.0:
					_acc_g -= 1.0
					_spawn_grit()
			"S3":
				if thrust > 0.1 and _t >= _next_burst:
					_burst(thrust)
					_next_burst = _t + _rng.randf_range(0.2, 0.32)
			"S1":
				_acc += 30.0 * thrust * strength * dt
			_:
				_acc += RATE * thrust * strength * dt
		while _acc >= 1.0:
			_acc -= 1.0
			_spawn()
	_step(dt)
	_push()


## THE JETS CUT: no more smoke, and what is there thins, spreads, lifts and is gone
## within `CLEAR_S` (its density steps down through the dither, so nothing pops out).
func _clear() -> void:
	_clearing = true
	for p: Dictionary in _puffs:
		var left := _rng.randf_range(CLEAR_S.x, CLEAR_S.y)
		p.life = minf(float(p.life), float(p.age) + left)
		p.buoy = float(p.buoy) + 12.0 * size_k
		p.gr = float(p.gr) + 10.0 * size_k
		p.heat = 0.0
	for g: Dictionary in _grit:
		g.life = minf(float(g.life), float(g.age) + 0.3)


## Done: nothing of it left to draw.
func cleared() -> bool:
	return _clearing and _puffs.is_empty() and _grit.is_empty()


## One puff: where, how fast, radius, growth px/s, density, life s, heat, stretch,
## drag, buoyancy (px/s^2 up).
func _add(at: Vector2, v: Vector2, r: float, gr: float, d: float, life: float, heat: float,
		sx: float, sy: float, drag: float, buoy: float) -> void:
	if _puffs.size() >= MAX_PUFFS:
		_puffs.pop_front()
	_puffs.append({"p": at, "v": v, "r": r * size_k, "gr": gr * size_k, "d": d, "life": life, "age": 0.0,
		"heat": heat, "sx": sx, "sy": sy, "drag": drag, "buoy": buoy * size_k})


## Where under the hull this puff starts: a jet, by weight.
func _source_x() -> float:
	var bx := src.x + _rng.randf_range(-0.6, 0.6) * src_w
	if not sources.is_empty():
		var tot := 0.0
		for q in sources:
			tot += q.z
		var pick := _rng.randf() * tot
		for q in sources:
			pick -= q.z
			if pick <= 0.0:
				return q.x + _rng.randf_range(-spread, spread)
	return bx


func _spawn() -> void:
	var s := size_k
	var side := -1.0 if _rng.randf() < 0.5 else 1.0
	var bx := _source_x()
	match kind:
		"S1":
			# big round puffs piling up and rolling out in a wall, rising slowly
			var up := _rng.randf() < 0.45
			_add(Vector2(bx, floor_y - 10.0 * s), Vector2(side * _rng.randf_range(50, 150) * s, -_rng.randf_range(10, 40) * s if up else 0.0),
				_rng.randf_range(18, 28), 30.0, _rng.randf_range(0.9, 1.15), _rng.randf_range(5.5, 7.5), 1.2,
				_rng.randf_range(1.0, 1.2), _rng.randf_range(0.95, 1.15), 0.9, 8.0 if up else 3.0)
		"S2":
			# a low skirt of dust thrown out fast along the floor, settling
			_add(Vector2(bx, floor_y - 4.0 * s), Vector2(side * _rng.randf_range(200, 320) * s, _rng.randf_range(-6, 0)),
				_rng.randf_range(7, 11), 18.0, _rng.randf_range(0.35, 0.5), _rng.randf_range(1.4, 2.4), 0.0, 2.4, 0.45, 2.6, -3.0)
		"S3":
			# (a burst is `_burst`; a lone puff is a wisp of the mist)
			_add(Vector2(bx, floor_y - 6.0 * s), Vector2(side * _rng.randf_range(20, 50) * s, 0.0),
				_rng.randf_range(10, 14), 10.0, 0.4, _rng.randf_range(3.5, 5.0), 0.0, 2.2, 0.45, 1.0, -2.0)
		_:
			# the rolling ground cloud: some roll out along the floor, some tumble up out of the bank
			var up2 := _rng.randf() < 0.35
			var vx := side * _rng.randf_range(110, 250) * s * (0.6 if up2 else 1.0)
			var vy := -_rng.randf_range(40, 90) * s if up2 else _rng.randf_range(-30, 0) * s
			_add(Vector2(bx, floor_y - 8.0 * s), Vector2(vx, vy), _rng.randf_range(12, 22), 40.0, _rng.randf_range(0.75, 1.0),
				_rng.randf_range(3.0, 4.6), 0.9, _rng.randf_range(1.1, 1.5), _rng.randf_range(0.85, 1.2), 1.5, 26.0 if up2 else 14.0)


## S3: pressurised vapour out of the belly's vents and the stands' tops, sideways,
## condensing fast, then sinking into a mist that hangs across the floor.
func _burst(k: float, stands_only: bool = false) -> void:
	var s := size_k
	var points: Array[Vector2] = []
	if not stands_only:
		for q in sources:
			points.append(Vector2(q.x, q.y + 2.0))
	for v in vents:
		points.append(v)
	for at in points:
		for side: float in [-1.0, 1.0]:
			_add(at + Vector2(side * 3.0, 0.0), Vector2(side * _rng.randf_range(220, 320) * s * k, _rng.randf_range(-12, 12)),
				_rng.randf_range(4, 6), 70.0, _rng.randf_range(0.7, 0.9), _rng.randf_range(3.2, 4.6), 0.15,
				1.8, 0.7, 4.5, -9.0)


## S2: grit and sparks off the floor in fast streaks, out from under the jets.
func _spawn_grit() -> void:
	var s := size_k
	var side := -1.0 if _rng.randf() < 0.5 else 1.0
	var spark := _rng.randf() < 0.12
	_grit.append({"p": Vector2(_source_x(), floor_y - _rng.randf_range(0, 4)),
		"v": Vector2(side * _rng.randf_range(260, 520) * s, _rng.randf_range(-40, 25) * s),
		"age": 0.0, "life": _rng.randf_range(0.2, 0.5), "spark": spark})


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
	if _bits != null:
		var kg: Array = []
		for g: Dictionary in _grit:
			g.age = float(g.age) + dt
			if float(g.age) >= float(g.life):
				continue
			var gv: Vector2 = g.v
			gv *= exp(-3.0 * dt)
			gv.y += 260.0 * dt
			var gp: Vector2 = g.p
			g.last = gp
			gp += gv * dt
			if gp.y > floor_y + 6.0:
				gp.y = floor_y + 6.0
				gv.y = -gv.y * 0.3
			g.v = gv
			g.p = gp
			kg.append(g)
		_grit = kg
		_bits.queue_redraw()


## The grit as short streaks along its way, the sparks as light.
func _draw_grit() -> void:
	for g: Dictionary in _grit:
		var p: Vector2 = (g.p as Vector2).floor()
		var l: Vector2 = (g.get("last", g.p) as Vector2).floor()
		var a := 1.0 - float(g.age) / float(g.life)
		if bool(g.spark):
			_bits.draw_line(l + Vector2(0.5, 0.5), p + Vector2(0.5, 0.5), Color(1.0, 0.82, 0.48, 0.6 * a), 1.0)
			_bits.draw_rect(Rect2(p, Vector2(1, 1)), Color("#fff4d0") if a > 0.5 else Color("#ffb347"))
		else:
			var c := Color(0.55, 0.5, 0.42, 0.75 * a) if int(p.x) % 3 != 0 else Color(0.36, 0.32, 0.27, 0.8 * a)
			_bits.draw_line(l + Vector2(0.5, 0.5), p + Vector2(0.5, 0.5), c, 1.0)


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
		b[n] = Vector4(float(p.heat) * exp(-float(p.age) * (1.2 if kind == "S1" else 4.5)), float(p.sx), float(p.sy), 0.0)
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
	var k := _lk
	_mat.set_shader_parameter(&"src", Vector4(src.x, floor_y - 8.0, maxf(30.0, src_w * 1.1) * size_k, 0.8 * k))
	if _hmat != null:
		# the haze under each jet, from the belly to the floor, while they burn
		var jets := PackedVector4Array()
		jets.resize(6)
		var nj := 0
		for q in sources:
			if nj >= 6:
				break
			jets[nj] = Vector4(q.x, q.y + 2.0, floor_y, 10.0 * size_k)
			nj += 1
		_hmat.set_shader_parameter(&"n", nj)
		_hmat.set_shader_parameter(&"jets", jets)
		_hmat.set_shader_parameter(&"k", k)
		_hmat.set_shader_parameter(&"tstep", floorf(_t * HZ))
