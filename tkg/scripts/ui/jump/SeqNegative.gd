class_name SeqNegative
extends JumpSequence

## R12 NEGATIVE (Jon: "R12 is great", Nov 10). The drive pulses, space turns to a photographic
## negative in a wave from the ship, the negative throbs and closes tight round the hull, the
## ship falls in on itself to a black point, and space snaps back, leaving the hull's ghost.
## The clock and every curve are the approved film's (tk-scratch/jump-drive/round3/_r12/r12.py).
## Why: docs/why/SeqNegative.md#negative

const SHADER := preload("res://shaders/jump/jump_r12.gdshader")

const T_WAKE := 0.7
const T_WAVE := 1.9
const T_FULL := 4.2
const BEATS := [4.50, 4.86, 5.16, 5.40]
const REACH := [330.0, 150.0, 56.0, 7.0]
const T_BREATH := 5.62
const T_HIT := 5.92
const T_POINT := T_HIT + 8.0 / 60.0
const T_SNAP := T_POINT + 3.0 / 60.0
const HANG := [4.22, 4.37]
## The drive's accelerating pulses, 3 to 14 a second (r4.py's clock).
const PULSES := [0.7, 1.01297, 1.18476, 1.31852, 1.43196, 1.53223, 1.62308, 1.70674, 1.78469]
## The negative's fixed colours: the ramp's stops, two slates, the hole-of-light ramp.
const FIXED := [
	[12, 9, 22], [40, 32, 62], [92, 80, 122], [146, 134, 170], [182, 174, 200], [208, 203, 222],
	[120, 104, 160], [70, 58, 104],
	[255, 253, 255], [242, 236, 253], [224, 214, 247], [202, 190, 236], [178, 164, 222]]
## The film's own cut of its scene's negative, used where this LOCAL has no palette of its own.
const FILM_PAL := [
	[208, 204, 217], [208, 203, 220], [208, 202, 219], [205, 199, 215], [201, 195, 212], [195, 189, 208],
	[193, 185, 205], [189, 182, 202], [186, 177, 198], [184, 175, 196], [177, 167, 191], [172, 162, 188],
	[169, 159, 184], [166, 156, 183], [163, 152, 179], [150, 139, 171], [142, 129, 161], [92, 86, 120]]
## Seventy motes in front of the hull, as the film rolled them (rng 1212): x, y, brightness, drift, size.
const DUST_X := [282.61, 714.85, 243.14, 289.22, 799.38, 251.52, 571.49, 361.09, 31.89, 443.03, 219.22, 654.47, 860.79, 690.68, 67.44, 400.20, 823.43, 353.05, 800.97, 490.92, 708.89, 400.17, 378.10, 493.30, 406.98, 134.85, 496.11, 647.45, 711.94, 452.63, 441.56, 173.99, 411.87, 226.97, 613.61, 462.62, 718.21, 888.81, 470.13, 628.46, 145.83, 447.24, 602.04, 852.90, 654.59, 299.48, 534.70, 514.88, 63.61, 880.00, 842.76, 152.38, 642.95, 269.65, 109.57, 476.13, 361.40, 497.93, 752.69, 651.29, 361.50, 220.71, 132.79, 875.29, 383.17, 605.57, 46.48, 361.12, 659.18, 817.78]
const DUST_Y := [259.48, 125.91, 429.25, 246.79, 252.95, 366.62, 130.62, 475.82, 232.99, 113.33, 245.58, 98.66, 86.33, 236.79, 346.21, 126.54, 279.04, 359.73, 293.82, 428.09, 480.55, 433.56, 140.99, 322.20, 176.82, 294.73, 420.21, 169.29, 287.00, 308.08, 95.30, 93.28, 268.93, 284.04, 187.07, 351.80, 268.29, 322.55, 80.55, 418.51, 83.24, 420.14, 149.76, 474.73, 245.37, 165.42, 112.47, 182.55, 482.74, 484.97, 358.15, 93.94, 220.35, 241.46, 398.96, 114.60, 279.14, 296.69, 196.48, 294.82, 324.43, 131.71, 172.26, 119.55, 360.47, 235.28, 214.60, 282.66, 380.18, 276.10]
const DUST_B := [0.656, 0.735, 0.761, 0.750, 0.376, 0.403, 0.324, 0.562, 0.681, 0.233, 0.816, 0.798, 0.580, 0.778, 0.247, 0.866, 0.660, 0.397, 0.406, 0.667, 0.668, 0.323, 0.810, 0.935, 0.900, 0.383, 0.798, 0.238, 0.409, 0.975, 0.642, 0.768, 0.351, 0.315, 0.827, 0.345, 0.904, 0.582, 0.420, 0.526, 0.419, 0.600, 0.295, 0.260, 0.270, 0.880, 0.642, 0.758, 0.443, 0.316, 0.923, 0.529, 0.995, 0.745, 0.552, 0.738, 0.562, 0.492, 0.238, 0.372, 0.262, 0.210, 0.228, 0.922, 0.962, 0.278, 0.854, 0.515, 0.594, 0.511]
const DUST_V := [-5.634, -4.900, -2.481, -4.245, -3.005, -4.790, -2.867, -3.473, -2.315, -4.097, -2.695, -3.907, -2.084, -3.198, -4.300, -3.834, -3.767, -5.005, -5.628, -5.905, -4.411, -4.333, -5.701, -4.363, -3.140, -3.021, -4.288, -2.335, -3.140, -3.269, -2.083, -5.042, -2.495, -3.626, -5.882, -4.442, -3.062, -3.309, -5.729, -5.104, -4.260, -5.742, -3.846, -3.316, -3.417, -4.040, -4.570, -3.357, -2.559, -4.472, -3.599, -2.676, -5.338, -5.797, -4.375, -3.659, -4.135, -4.416, -2.053, -3.558, -4.813, -2.290, -2.898, -5.058, -3.756, -2.673, -2.745, -3.795, -3.948, -4.927]
const DUST_SZ := [1, 1, 1, 1, 1, 1, 1, 2, 1, 1, 1, 2, 1, 1, 1, 1, 2, 2, 1, 1, 2, 1, 1, 1, 1, 1, 1, 2, 1, 2, 1, 1, 2, 1, 1, 2, 2, 2, 2, 1, 1, 1, 1, 2, 1, 1, 1, 1, 1, 1, 1, 1, 2, 1, 2, 1, 1, 1, 2, 2, 2, 1, 2, 1, 1, 1, 2, 1, 1, 1]
const DUST_COL := Color(70.0 / 255.0, 66.0 / 255.0, 84.0 / 255.0)


func _init() -> void:
	id = &"r12"
	length = 10.0
	hit_t = T_SNAP
	cut_t = T_BREATH
	commit_t = 8.8


func setup(_stage: JumpStage, _place: JumpPlace, _hull: JumpHull) -> void:
	super(_stage, _place, _hull)
	stage.build(SHADER, place.window)
	stage.set1(&"core", place.core)
	stage.set1(&"pc", place.pc)
	stage.set1(&"ship", Vector4(place.canvas.position.x, place.canvas.position.y, place.canvas.size.x, place.canvas.size.y))
	var pt := PackedFloat32Array()
	var ps := PackedFloat32Array()
	for tp: float in PULSES:
		pt.append(tp)
		ps.append((tp - T_WAKE) / (T_WAVE - T_WAKE))
	stage.set1(&"pulse_t", pt)
	stage.set1(&"pulse_s", ps)
	stage.set1(&"pulse_n", PULSES.size())
	_set_palette()
	stage.specks.set_origin(stage.global_position)
	for i in DUST_X.size():
		stage.specks.motes.append([DUST_X[i], DUST_Y[i], DUST_B[i], DUST_V[i], DUST_SZ[i]])


## The negative's palette: the fixed ramp, plus this LOCAL's own colours through the negative
## (`LocalSky.palette_for`), or the film's cut where the sky kept no palette.
func _set_palette() -> void:
	var cols: Array = []
	for c: Array in FIXED:
		cols.append(Vector3(c[0], c[1], c[2]))
	var own: Array = LocalSky.palette_for(Run.node_at()) if Run.node_at() != null else []
	var n := 0
	if own.size() == 2:
		var arr: PackedVector3Array = own[0]
		n = int(own[1])
		for i in mini(n, 24):
			cols.append(_neg_of(arr[i]))
	if n == 0:
		for c: Array in FILM_PAL:
			cols.append(Vector3(c[0], c[1], c[2]))
	var out := PackedVector3Array()
	for c: Vector3 in cols:
		if out.size() >= 40:
			break
		var dup := false
		for o in out:
			if o.distance_to(c) < 4.0:
				dup = true
				break
		if not dup:
			out.append(c)
	var cnt := out.size()
	out.resize(40)
	stage.set1(&"pal", out)
	stage.set1(&"pal_n", cnt)


## A scene colour through `neg_raw` (the shader's ramp), in 0..255.
static func _neg_of(x: Vector3) -> Vector3:
	var stops := [0.0, 0.30, 0.52, 0.68, 0.80, 0.90]
	var L := x.dot(Vector3(0.30, 0.55, 0.15))
	var v := clampf(1.0 - pow(clampf(L, 0.0, 1.0), 0.45), 0.0, 1.0)
	var o := Vector3(FIXED[5][0], FIXED[5][1], FIXED[5][2])
	for i in 5:
		if v < float(stops[i + 1]):
			var a := Vector3(FIXED[i][0], FIXED[i][1], FIXED[i][2])
			var b := Vector3(FIXED[i + 1][0], FIXED[i + 1][1], FIXED[i + 1][2])
			o = a.lerp(b, (v - float(stops[i])) / (float(stops[i + 1]) - float(stops[i])))
			break
	var chroma := x - Vector3(L, L, L)
	return (o - chroma * 255.0 * 0.5).clamp(Vector3.ZERO, Vector3(255, 255, 255))


static func spread_r(t: float) -> float:
	return 990.0 * pow(clampf((t - T_WAVE) / (T_FULL - T_WAVE), 0.0, 1.0), 1.12)


## The skin's distance off the hull in the tighten: each beat throbs out, then snaps in.
static func reach_at(t: float) -> float:
	var r := 1100.0
	for i in BEATS.size():
		var k := t - float(BEATS[i])
		if k < 0.0:
			return r
		if k < 0.07:
			return r + (0.10 * r + 10.0) * sin(PI * k / 0.07)
		if k < 0.20:
			return r + (float(REACH[i]) - r) * ease5((k - 0.07) / 0.13)
		r = float(REACH[i])
	return r


static func throb_at(t: float) -> float:
	var v := 0.0
	for b: float in [T_WAVE] + HANG + BEATS:
		var k := t - b
		if k >= 0.0 and k < 0.5:
			v = maxf(v, exp(-k / 0.09))
	return v


static func collapse_f(t: float) -> float:
	if t < T_HIT:
		return 1.0
	var u := clampf((t - T_HIT) / (T_POINT - T_HIT), 0.0, 1.0)
	return maxf(1.0 - pow(u, 1.7), 0.0)


func step(t: float) -> void:
	var k_snap := t - T_SNAP
	var fsc := collapse_f(t)
	var gone := t >= T_SNAP
	var b0 := float(BEATS[0])
	var b3 := float(BEATS[3])
	var mode := 0
	var wob_amp := 0.0
	var wob_t := t
	var rr := 1100.0
	var R := 0.0
	if t < T_WAVE:
		mode = 0
	elif t < b0:
		mode = 1
		R = spread_r(t)
		wob_amp = 4.0 + 0.035 * R
	elif t < T_HIT:
		mode = 2
		rr = reach_at(t)
		var boil := 1.0 + 1.6 * ease3((t - b3) / 0.4) if t > b3 else 1.0
		wob_amp = (2.0 + 0.04 * rr) * boil
		wob_t = t * (1.0 + (1.5 if t > b3 else 0.0))
	elif not gone:
		mode = 3 if fsc > 0.02 else 4
		wob_t = t * 2.5
	elif k_snap < 2.0 / 60.0:
		mode = 5
	elif k_snap < 1.0:
		mode = 6
	else:
		mode = 7
	var th := throb_at(t)
	stage.set1(&"mode", mode)
	stage.set1(&"t", t)
	stage.set1(&"R", R)
	stage.set1(&"reach", rr)
	stage.set1(&"wob_amp", wob_amp)
	stage.set1(&"wob_t", wob_t)
	stage.set1(&"fsc", fsc)
	stage.set1(&"throb", th)
	stage.set1(&"lift", 0.0)
	stage.set1(&"ech", clampf(R / 200.0, 0.0, 1.0) * (1.0 - ease3((t - 3.4) / 0.8)) if mode == 1 else 0.0)
	stage.set1(&"band", 3.5 if t < b0 else 2.5)
	var g := 0.0
	if mode == 1:
		g = ease3((t - T_WAVE) / 0.15) * (1.0 - 0.6 * ease3((t - (T_FULL - 0.5)) / 0.5))
	elif mode == 2:
		g = 0.9 + 0.6 * ease3((t - b3) / 0.4)
	elif mode == 3 or mode == 4:
		g = 1.6 * fsc + 0.3
	stage.set1(&"rim_g", g)
	stage.set1(&"ink_on", 1.0 if t < b3 else 0.0)
	stage.set1(&"inkk", clampf(((1.0 - fsc) - 0.32) / 0.55, 0.0, 1.0))
	stage.set1(&"tight", ease3((t - float(BEATS[2])) / 0.3) if t > float(BEATS[2]) else 0.0)
	stage.set1(&"front_amp", 2.6 if mode == 1 else (2.0 if mode == 2 else 0.0))
	var pull := 0.0
	if t >= T_HIT - 0.3 and t < T_SNAP:
		pull = pow(ease3((t - (T_HIT - 0.3)) / (T_SNAP - T_HIT + 0.3)), 2.0)
	stage.set1(&"pull_k", pull)
	stage.set1(&"k_snap", k_snap)
	var glow_on := t >= T_WAKE and t < T_WAVE + 0.4
	stage.set1(&"glow_on", 1.0 if glow_on else 0.0)
	stage.set1(&"wake_s", ease3((t - T_WAKE) / (T_WAVE - T_WAKE)))
	_step_hull(t, mode, gone, k_snap, b0, b3)
	# the finish: a chromatic fringe and a 6 px shake on the snap, no flash of its own
	var cf := 3.5 * exp(-k_snap / 0.12) if (k_snap >= 0.0 and k_snap < 0.5) else 0.0
	stage.set2(&"fringe", cf)
	stage.set2(&"centre", place.pc)
	var sh := Vector2.ZERO
	if k_snap >= 0.0 and k_snap < 0.6:
		var a := 6.0 * exp(-k_snap / 0.13)
		sh = Vector2(smooth_noise(t, 0), smooth_noise(t, 1) * 0.8) * a
	set_shake(sh)


## The hull's and the dust's part of the instant: the wake's discs, the tremble, the snap, the afterimage.
func _step_hull(t: float, mode: int, gone: bool, k_snap: float, b0: float, b3: float) -> void:
	# on each drive pulse a disc round the drive flickers negative for three frames
	var disc := Vector3.ZERO
	if mode == 0:
		for tp: float in PULSES:
			var k := t - tp
			if k >= 0.0 and k < 3.5 / 60.0:
				var s := (tp - T_WAKE) / (T_WAVE - T_WAKE)
				disc = Vector3(1.0, 4.0 + 44.0 * pow(s, 1.3), tp * 7.0)
	stage.set1(&"disc", disc)
	# the hull trembles a pixel as the skin boils
	var tremble := Vector2.ZERO
	if t > b3 and t < T_HIT:
		var s := ease3((t - b3) / 0.4)
		var fr := int(floor(t * 20.0))
		if held_rand(fr, 1) < 0.5 * s:
			tremble.x = float(int(held_rand(fr, 2) * 3.0) - 1)
		if held_rand(fr, 3) < 0.7 * s:
			tremble.y = float(int(held_rand(fr, 4) * 3.0) - 1)
	stage.set1(&"tremble", tremble)
	stage.set1(&"point_on", 1.0 if (t >= T_POINT and not gone) else 0.0)
	# the snap: two frames of full negative (a four-frame dithered crossfade with fewer flashes)
	var full := 0.0
	if gone and k_snap < 2.0 / 60.0:
		full = 1.0
	if reduce and gone and k_snap < 4.0 / 60.0:
		full = 1.0 - k_snap / (4.0 / 60.0)
	stage.set1(&"full_mix", full)
	# the afterimage
	var after := Vector4.ZERO
	var after_on := false
	if gone and k_snap >= 2.0 / 60.0:
		var ka := k_snap - 2.0 / 60.0
		after = Vector4(1.15 * exp(-ka / 0.9), ease3((ka - 1.1) / 1.5), ease3(ka / 1.6), 2.5 * exp(-ka / 0.10))
		after_on = true
	stage.set1(&"after", after)
	stage.set1(&"after_on", 1.0 if after_on else 0.0)
	# the dust: in from the wake, drawn toward the hull in the tighten and the collapse
	var dvis := ease3((t - T_WAKE) / 1.0) * (1.0 - ease3((t - 7.2) / 1.2)) * (0.0 if t >= T_SNAP else 1.0)
	var dpull := 0.0
	if t > b0:
		dpull = 0.10 * ease3((t - b0) / 1.4)
	if t > T_HIT:
		dpull = 0.10 + 0.9 * pow(ease3((t - T_HIT) / (T_SNAP - T_HIT)), 2.0)
	stage.specks.place(t, dvis, dpull, place.pc, DUST_COL)
