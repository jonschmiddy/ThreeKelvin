class_name SeqHyperspace
extends JumpSequence

## R1 HYPERSPACE, the cinema jump: the drive spools, a pinhole opens ahead, the stars
## stretch into it and streaks pour past the hull, the ship holds, lurches in over two
## frames under a white-violet flash, and the stars spring home. The clock and curves are
## the approved film's (tk-scratch/jump-drive/round3/_r1/r1.py, round 3b, no zoom).
## Why: docs/why/SeqHyperspace.md#hyperspace

const SHADER := preload("res://shaders/jump/jump_r1.gdshader")

const T_WAKE := 0.7
const T_HOLD := 4.55
const T_HIT := 5.0
const CUT := 4.86
## The film's pinhole stood 446 px ahead of the nose, a pixel above the hull's middle line.
const VP_AHEAD := 446.0
const MID_K := 50.0 / 93.0
const VIO := Vector3(0.62, 0.36, 1.00)
const LIL := Vector3(0.86, 0.74, 1.00)
## The four arms of a bright spark: direction and colour, in the order they are drawn.
const ARMS: Array = [[Vector2(-1, 0), LIL], [Vector2(1, 0), LIL], [Vector2(0, -1), VIO], [Vector2(0, 1), VIO]]
const WHT := Vector3(1.00, 0.96, 1.00)
## The faint extra stars that only show once space is stretched, and the flow's streaks.
const NX := 1500
const NF := 900
## The seventy sparks of the aftermath, as the film rolled them (rng 77): x from the tail
## (of 682 to the pinhole), y off the middle line, drift, life, brightness.
const SP_X0 := [540.29, 384.88, 181.45, 241.41, 230.97, 278.28, 550.46, 80.11, 267.34, 543.86, 522.24, 419.83, 106.56, 258.22, 596.47, 667.52, 488.15, 126.50, 601.58, 127.17, 244.67, 253.83, 276.96, 96.77, 142.81, 519.75, 70.21, 279.99, 21.88, 325.59, 77.49, 42.66, 557.59, 156.56, 557.01, 197.66, 549.94, 312.57, 464.07, 664.97, 157.35, 437.80, 75.02, 327.87, 126.80, 527.41, 90.89, 314.25, 67.02, 332.40, 682.00, 682.00, 682.00, 682.00, 682.00, 682.00, 682.00, 682.00, 682.00, 682.00, 682.00, 682.00, 682.00, 682.00, 682.00, 682.00, 682.00, 682.00, 682.00, 682.00]
const SP_Y0 := [0.19, 1.14, 2.52, 2.87, 6.94, -0.29, -1.04, -3.83, 1.00, 1.06, -3.04, -0.13, -0.07, 14.66, -2.04, 4.98, 1.63, -0.37, 1.63, 1.43, -0.13, -1.00, -1.50, -1.54, 1.12, -0.47, 3.86, 5.52, -0.22, -1.19, 5.28, -0.28, 0.84, -1.54, 0.53, 5.18, 3.58, -4.37, -3.40, -1.63, -1.21, 2.81, -8.52, 5.16, -4.60, 4.15, -5.04, -0.82, 3.46, 0.14, -1.00, -1.00, -1.00, -1.00, -1.00, -1.00, -1.00, -1.00, -1.00, -1.00, -1.00, -1.00, -1.00, -1.00, -1.00, -1.00, -1.00, -1.00, -1.00, -1.00]
const SP_VX := [11.78, 37.32, -1.93, 29.56, 12.66, 3.68, 12.13, 27.36, 35.15, 34.78, 15.87, 13.30, 28.19, 13.92, 36.71, 27.56, 32.09, 12.96, 26.67, 27.59, 5.04, 32.77, 32.17, 14.63, 7.78, 22.55, 23.00, 24.15, 20.19, 23.91, 8.63, 16.14, 20.30, 29.12, 27.04, 17.66, 22.26, 14.10, 8.79, 11.25, 24.54, 36.55, 15.60, 4.35, 21.79, 32.87, 27.51, 21.78, 24.01, 30.77, -30.00, 16.51, 0.96, -16.53, -59.20, -38.28, -33.61, -40.66, 67.59, 60.12, 25.40, 21.66, -2.39, 51.59, -38.11, -14.38, -26.02, -24.79, 8.50, 44.23]
const SP_VY := [0.98, -0.50, 5.15, 3.04, 3.76, 1.74, 8.24, 3.91, -0.78, 5.35, -10.40, -0.83, -10.69, -5.12, 4.83, 1.01, 5.13, -6.08, 7.61, 8.90, 7.65, 1.17, -2.08, -7.28, -7.36, -10.84, -0.01, 3.78, -4.14, -5.59, -0.56, 6.67, -5.77, 10.42, -0.47, 10.02, -6.17, -4.09, -5.55, -10.20, 1.14, 5.93, -2.36, -6.21, 10.44, -8.72, -7.08, -8.32, 3.61, -9.19, 15.03, -26.09, -19.05, -9.70, -16.47, -2.02, -3.16, -11.69, -4.55, 7.41, -20.66, -6.85, -13.65, -24.21, 9.25, -26.47, -5.47, 25.39, 36.50, -23.28]
const SP_LIFE := [2.719, 1.551, 1.538, 2.214, 1.336, 1.463, 1.710, 2.700, 2.707, 1.523, 2.373, 1.311, 2.159, 1.472, 2.742, 1.577, 1.130, 1.618, 2.329, 1.060, 2.200, 0.921, 0.937, 1.545, 2.096, 1.089, 1.414, 2.526, 2.689, 1.338, 2.473, 1.790, 1.006, 1.074, 2.010, 2.215, 1.261, 2.225, 2.407, 1.869, 1.871, 1.620, 1.308, 2.278, 1.085, 2.117, 2.148, 1.200, 1.729, 1.557, 1.651, 2.431, 1.284, 2.757, 1.478, 2.543, 1.367, 1.191, 1.377, 2.752, 1.444, 2.422, 1.260, 1.070, 2.780, 2.576, 1.458, 1.545, 2.624, 1.579]
const SP_B := [0.885, 1.207, 1.214, 0.690, 1.115, 0.789, 1.171, 1.172, 1.193, 0.824, 1.208, 1.248, 0.922, 0.578, 1.159, 0.991, 0.753, 0.591, 0.592, 0.798, 0.536, 1.184, 0.582, 0.904, 1.111, 1.187, 1.271, 0.974, 0.867, 0.654, 0.891, 0.869, 0.550, 0.594, 0.939, 1.104, 0.542, 1.020, 0.643, 0.758, 1.092, 1.015, 0.840, 0.679, 0.559, 0.991, 0.829, 1.136, 0.852, 1.203, 1.234, 0.552, 0.751, 0.525, 0.660, 0.762, 0.512, 0.973, 0.860, 1.079, 0.742, 0.763, 0.542, 1.203, 0.867, 0.627, 0.873, 1.257, 0.653, 1.190]

var vp := Vector2.ZERO
var mid_y := 0.0
var tail_x := 0.0
var _phi := PackedFloat32Array()
var _back: SubViewport
var _front: SubViewport
var _stars: JumpStars = null
var _star_lines: JumpLines = null
var _flow_back: JumpLines
var _flow_front: JumpLines
var _dots: JumpDots
## The launch frames shown so far: the two hand-set frames and the flash's four each get a
## frame of their own however the frames fall.
var _launch := 0
## The hull's place this instant (`_ship_place`): offset, stretch, squash, heat, drawn.
var _pl_d := Vector2.ZERO
var _pl_sx := 1.0
var _pl_sy := 1.0
var _pl_hot := 0.0
var _pl_on := true


func _init() -> void:
	id = &"r1"
	length = 10.0
	hit_t = T_HIT
	cut_t = CUT
	commit_t = 8.8
	flash_floor = 0.30
	_phi.resize(int(11.0 * 600.0) + 1)
	var acc := 0.0
	for i in _phi.size():
		var tt := float(i) / 600.0
		var fa := flow_amt(tt)
		acc += (0.0 if tt < 2.4 else (0.15 + 1.1 * pow(fa, 2.2) if tt < T_HIT else 1.6 * fa)) / 600.0
		_phi[i] = acc


## 0..1 drive charge.
static func spool(t: float) -> float:
	return pow(ease3((t - T_WAKE) / (T_HOLD - T_WAKE)), 1.2) if t < T_HIT else 0.0


## How far the stars lean toward the pinhole (0 home, 1 into it); a damped spring home after.
static func stretch(t: float) -> float:
	if t < 1.7:
		return 0.0
	if t < T_HOLD:
		return 0.62 * pow((t - 1.7) / (T_HOLD - 1.7), 2.3)
	if t < T_HIT:
		return 0.62 + 0.10 * ease5((t - T_HOLD) / (T_HIT - T_HOLD))
	var k := t - T_HIT
	if k < 2.0 / 60.0:
		return 0.72 + 0.24 * (k / (2.0 / 60.0))
	k -= 2.0 / 60.0
	return 0.96 * exp(-k / 0.28) * cos(TAU * k / 1.5)


static func flow_amt(t: float) -> float:
	if t < 2.4:
		return 0.0
	if t < T_HIT:
		return ease3((t - 2.4) / (T_HOLD - 2.4))
	return exp(-(t - T_HIT) / 0.22)


func phi(t: float) -> float:
	var x := clampf(t * 600.0, 0.0, float(_phi.size() - 1))
	var i := int(floor(x))
	if i >= _phi.size() - 1:
		return _phi[_phi.size() - 1]
	return lerpf(_phi[i], _phi[i + 1], x - float(i))


func setup(_stage: JumpStage, _place: JumpPlace, _hull: JumpHull) -> void:
	super(_stage, _place, _hull)
	stage.build(SHADER, place.window)
	mid_y = place.ink.position.y + roundf(MID_K * place.ink.size.y)
	tail_x = place.ink.position.x
	vp = Vector2(place.ink.end.x + roundf(place.ahead(VP_AHEAD)), mid_y - 1.0)
	stage.set1(&"vp", vp)
	stage.set1(&"core", place.core)
	stage.set1(&"mid_y", mid_y)
	stage.set1(&"tail_x", tail_x)
	stage.set1(&"ink_w", place.ink.size.x)
	stage.set1(&"ship", Vector4(place.canvas.position.x, place.canvas.position.y, place.canvas.size.x, place.canvas.size.y))
	_back = stage.light(&"light_back")
	_front = stage.light(&"light_front")
	_roll_flow()
	_dots = JumpDots.new()
	_front.add_child(_dots)
	# the finish: R1's bloom, its flash (a floor of 0.3, a 200 px falloff, violet, a beam
	# along the ship's line left of the pinhole, seven steps)
	stage.set2(&"centre", vp)
	stage.set2(&"bloom", 0.0 if DisplaySettings.graphics_low else 1.15)
	stage.set2(&"flash_r", 200.0)
	stage.set2(&"flash_col", WHT * 0.6 + VIO * 0.4)
	stage.set2(&"flash_lv", 7.0)
	stage.set2(&"flash_beam", Vector4(mid_y, 30.0, 1.2, vp.x))


## The 900 streaks of the flow (rng 31 in the film; hashed here): angle, phase, depth, speed,
## brightness, thickness. The near ones are drawn over the hull.
func _roll_flow() -> void:
	var rows: Array = []
	var n_front := 0
	for i in NF:
		var ang := held_rand(i, 21) * TAU
		var u0 := held_rand(i, 22)
		var dr := held_rand(i, 23)
		var dep := 0 if dr < 0.55 else (1 if dr < 0.88 else 2)
		var v: float = [0.55, 1.0, 1.9][dep] * (0.8 + 0.4 * held_rand(i, 24))
		var b: float = [0.35, 0.7, 1.25][dep] * (0.6 + 0.4 * held_rand(i, 25))
		rows.append([ang, u0, dep, v, b])
		if dep == 2:
			n_front += 1
	_flow_back = JumpLines.new(NF - n_front, 2)
	_flow_front = JumpLines.new(n_front, 2)
	var ib := 0
	var ifr := 0
	for r: Array in rows:
		var dep: int = r[2]
		var ln: JumpLines = _flow_front if dep == 2 else _flow_back
		var i := ifr if dep == 2 else ib
		ln.put(i, Vector2(r[0], r[1]), Vector2(r[3], r[4]), Vector2(float(dep), 2.0 if dep == 2 else 1.0))
		if dep == 2:
			ifr += 1
		else:
			ib += 1
	for ln: JumpLines in [_flow_back, _flow_front]:
		ln.set_p(&"vp", vp)
		ln.set_p(&"world", Vector4(place.window.position.x, place.window.position.y, place.window.size.x, place.window.size.y))
	_back.add_child(_flow_back)
	_front.add_child(_flow_front)


## The lifted stars and the hashed extras as instances, once the lift is in.
func _build_stars() -> void:
	var n := _stars.home.size()
	_stars.add_faint(NX)
	_star_lines = JumpLines.new(n + NX, 1)
	for i in n:
		_star_lines.put(i, _stars.home[i], Vector2(_stars.bright[i], _stars.lag_u[i]), Vector2.ZERO)
	for j in NX:
		_star_lines.put(n + j, _stars.faint_home[j], Vector2(_stars.faint_bright[j], _stars.faint_lag[j]), Vector2(1.0, 0.0))
	_star_lines.set_p(&"vp", vp)
	_back.add_child(_star_lines)
	if _stars.mask != null:
		stage.set1(&"mask", _stars.mask)
		stage.set1(&"mask_on", 1.0)


## The hull's offset, stretch, squash and heat this instant; the launch frames are latched.
func _ship_place(t: float, s: float, k_hit: float) -> void:
	_pl_sx = 1.0
	_pl_sy = 1.0
	_pl_hot = 0.0
	_pl_on = true
	if t < T_HOLD:
		var d := Vector2.ZERO
		if t > 3.3:
			var fr := int(floor(t * (14.0 + 10.0 * s)))
			if held_rand(fr, 5) < 0.6 * s:
				d.y = float(int(held_rand(fr, 6) * 3.0) - 1)
			if held_rand(fr, 7) < 0.3 * s:
				d.x = float(int(held_rand(fr, 8) * 3.0) - 1)
		_pl_d = d
	elif t < T_HIT:
		_pl_d = Vector2(-roundf(5.0 * ease5((t - T_HOLD) / 0.30)), 0.0)
	else:
		var idx := mini(_launch, int(k_hit * 60.0))
		_pl_d = Vector2(24.0, 0.0) if idx == 0 else (Vector2(200.0, 0.0) if idx == 1 else Vector2.ZERO)
		_pl_sx = 1.6 if idx == 0 else (3.6 if idx == 1 else 1.0)
		_pl_sy = 0.8 if idx == 0 else (0.22 if idx == 1 else 1.0)
		_pl_hot = 0.3 if idx == 0 else (1.0 if idx == 1 else 0.0)
		_pl_on = idx < 2


func step(t: float) -> void:
	var s := spool(t)
	var S := stretch(t)
	var fa := flow_amt(t)
	var k_hit := t - T_HIT
	# the stars are lifted off the sky a few frames in, once this LOCAL has drawn itself
	if _stars == null and t >= 0.1:
		var img: Image = null
		if not LocalSky.headless() and stage.get_viewport().get_texture() != null:
			img = stage.get_viewport().get_texture().get_image()
		_stars = JumpStars.lift(stage, img, place.window, place.ink.grow(4.0))
	elif _stars != null and _star_lines == null and _stars.poll():
		_build_stars()
	stage.set1(&"t", t)
	stage.set1(&"k_hit", k_hit)
	stage.set1(&"S", S)
	stage.set1(&"after", 1.0 if t >= T_HIT else 0.0)
	stage.set1(&"bend_on", 1.0 if (t > 1.5 and t < T_HIT) else 0.0)
	stage.set1(&"s", s)
	stage.set1(&"tw", t - T_WAKE if (t >= T_WAKE and t < T_HIT) else -1.0)
	stage.set1(&"hold", 1.0 if t > T_HOLD else 0.0)
	var pin_g := ease3((t - 1.2) / (T_HOLD - 1.2)) if (t > 1.2 and t < T_HIT) else 0.0
	stage.set1(&"pin_g", pin_g)
	stage.set1(&"tight", ease5((t - T_HOLD) / (T_HIT - T_HOLD)) if t > T_HOLD else 0.0)
	stage.set1(&"flick", 1.0 + 0.12 * sin(t * 37.0) * float(int(floor(t * 12.0)) % 2))
	_ship_place(t, s, k_hit)
	stage.set1(&"ship_d", _pl_d)
	stage.set1(&"sxs", _pl_sx)
	stage.set1(&"sqy", _pl_sy)
	stage.set1(&"hot", _pl_hot)
	stage.set1(&"place_on", 1.0 if _pl_on else 0.0)
	# the streaks: the stars' stretch, the flow's phase and speed
	if _star_lines != null:
		_star_lines.set_p(&"S", S)
		_star_lines.set_p(&"after", 1.0 if t >= T_HIT else 0.0)
		_star_lines.set_p(&"ea", minf(1.0, absf(S) / 0.35))
	var ph := phi(t)
	for ln: JumpLines in [_flow_back, _flow_front]:
		ln.set_p(&"fa", fa)
		ln.set_p(&"phi", ph)
		ln.set_p(&"sp", 0.08 + 0.55 * pow(fa, 1.5))
	_step_after(t, k_hit)
	# the shake: builds with the charge, dead still in the hold, a jolt on the hit
	var a := 0.0
	var hz := 15.0
	if t < T_HOLD:
		a = 1.7 * pow(maxf(0.0, (t - 2.2) / (T_HOLD - 2.2)), 2.0)
		hz = 9.0 + 10.0 * s
	elif t < T_HIT:
		a = 1.7 * maxf(0.0, 1.0 - (t - T_HOLD) / 0.12)
		hz = 19.0
	else:
		a = 7.0 * exp(-k_hit / 0.30)
		hz = 16.0
	set_shake(Vector2(smooth_noise(t, 0, hz), smooth_noise(t, 1, hz) * 0.8) * a if a > 0.01 else Vector2.ZERO)


## The hit and after: the flash, the fringe, the sparks.
func _step_after(t: float, k_hit: float) -> void:
	var fl := 0.0
	if k_hit >= 0.0:
		var idx := mini(_launch, int(k_hit * 60.0))
		_launch += 1
		fl = [0.3, 0.85, 0.22, 0.10][idx] if idx < 4 else 0.10 * exp(-(k_hit - 4.0 / 60.0) / 0.10)
	set_flash(fl, vp, 1.3)
	stage.set2(&"fringe", 5.0 * exp(-k_hit / 0.12) if (k_hit >= 0.0 and k_hit < 0.6) else 0.0)
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	if k_hit >= 0.0 and k_hit < 3.0:
		var kx := (vp.x - tail_x) / 682.0
		var dragf := (1.0 - exp(-k_hit / 0.6)) * 0.6
		var held := int(floor(k_hit * 10.0))
		var k := JumpStage.LIGHT_K
		for i in SP_X0.size():
			var life := 1.0 - k_hit / float(SP_LIFE[i])
			if life <= 0.0 or (k_hit < 0.5 and (held + i) % 4 == 0):
				continue
			var x := floorf(tail_x + float(SP_X0[i]) * kx + float(SP_VX[i]) * dragf)
			var y := floorf(mid_y + float(SP_Y0[i]) + float(SP_VY[i]) * dragf + 4.0 * k_hit * k_hit)
			var v := float(SP_B[i]) * pow(life, 0.7) * 2.2
			pts.append(Vector2(x, y))
			cols.append(Color(WHT.x * v * k, WHT.y * v * k, WHT.z * v * k))
			var arm := v * 0.3 * clampf((v - 0.6) / 0.8, 0.0, 1.0)
			if arm > 0.0:
				for d: Array in ARMS:
					var c: Vector3 = d[1]
					pts.append(Vector2(x, y) + d[0])
					cols.append(Color(c.x * arm * k, c.y * arm * k, c.z * arm * k))
	_dots.set_dots(pts, cols)


func teardown() -> void:
	if _stars != null and _stars._vp != null and is_instance_valid(_stars._vp):
		_stars._vp.queue_free()
