class_name SeqRift
extends JumpSequence

## R3 THE RIFT. Space tears open ahead of the ship and bends the stars into a ring round a
## black throat; the ship falls in, wraps round the ring, reddens and freezes; the throat zips
## shut and a shudder rolls out. The clock and curves are the approved film's (round3/_r3/rift.py,
## no zoom); the ship lives inside the lens (`JumpWarpField`).
## Why: docs/why/SeqRift.md#rift

const SHIP := preload("res://shaders/jump/jump_r3_ship.gdshader")
const WARP := preload("res://shaders/jump/jump_r3_warp.gdshader")
const POINTS := preload("res://shaders/jump/jump_r3_points.gdshader")

const T_WAKE := 0.6
const T_INHALE := 3.25
const T_HIT := 3.6
const T_HEAL := 7.0
## The mix's quietest moment in the inhale: the build cue ends there and the hit cue starts.
const CUT := 3.322
## The rift stood 275 px ahead of the nose, 16.5 above the hull's middle line.
const AHEAD := 275.0
const RISE := 16.5
## The fall's table: D0 for a depth D, sqrt-spaced over 0..TAB_MAX film px.
const TAB_N := 512
const TAB_MAX := 800.0
const FALL_N := 801

var field: JumpWarpField
var _seamed := false
var tg := Vector2.ZERO
var sk := 1.0
var motes: ShaderMaterial
var shut: ShaderMaterial
var _tab_img: Image
var _tab: ImageTexture
var _tab_f := PackedFloat32Array()
var _dt := PackedFloat32Array()
## Per D0 on the fall's grid, (1 / tau)^1.6, so a frame's table is one exp a texel.
var _itau := PackedFloat32Array()


func _init() -> void:
	id = &"r3"
	length = 10.6
	hit_t = T_HIT
	cut_t = CUT
	commit_t = 9.6
	swap_t = 0.85
	flame_s = T_WAKE
	_tab_f.resize(TAB_N)
	_dt.resize(FALL_N)
	_itau.resize(FALL_N)
	for i in FALL_N:
		var d0 := float(i)
		var tau := 0.36 * pow(maxf(d0 / 274.0, 0.05), 1.5)
		_itau[i] = pow(1.0 / tau, 1.6)


func setup(_stage: JumpStage, _place: JumpPlace, _hull: JumpHull) -> void:
	super(_stage, _place, _hull)
	sk = place.ahead(1.0)
	tg = Vector2(place.ink.end.x - 1.0 + roundf(AHEAD * sk), roundf(place.ink.get_center().y - RISE))
	field = JumpWarpField.new()
	field.build(stage, SHIP, WARP, place.window)
	stage.set1(&"Tg", tg)
	stage.set1(&"S", sk)
	stage.set1(&"ship", Vector4(place.canvas.position.x, place.canvas.position.y, place.canvas.size.x, place.canvas.size.y))
	stage.set1(&"tab_n", TAB_N)
	stage.set1(&"tab_max", TAB_MAX)
	field.setw(&"Tg", tg)
	field.setw(&"S", sk)
	# the flash is the warp pass's own; the finish keeps its floor unused (the harnesses read it)
	stage.set2(&"flash_floor", 0.0 if reduce else 0.10)
	_tab_img = Image.create(TAB_N, 1, false, Image.FORMAT_RF)
	_tab = ImageTexture.create_from_image(_tab_img)
	stage.set1(&"dtab", _tab)
	motes = field.points(POINTS, 120 * 6)
	shut = field.points(POINTS, 34 * 2)
	for m: ShaderMaterial in [motes, shut]:
		m.set_shader_parameter(&"Tg", tg)
		m.set_shader_parameter(&"S", sk)
	shut.set_shader_parameter(&"kind", 1)


## The film's `state`: Einstein radius, throat, frame dragging and the shake's amplitude.
static func lens_at(t: float) -> Vector3:
	var rE := 0.0
	if t < T_WAKE:
		rE = 0.0
	elif t < T_INHALE:
		rE = 4.0 + 76.0 * pow((t - T_WAKE) / (T_INHALE - T_WAKE), 1.3)
	elif t < T_HIT:
		rE = 80.0 - 40.0 * ease3((t - T_INHALE) / (T_HIT - T_INHALE))
	elif t < T_HEAL:
		var k := t - T_HIT
		var snap := 74.0 * (1.0 - pow(1.0 - clampf(k / 0.16, 0.0, 1.0), 3.0)) + 10.0 * exp(-k * 7.0) * sin(k * 30.0)
		rE = 20.0 + snap + 30.0 * ease3((k - 0.2) / 2.6)
	else:
		rE = 117.0 * (1.0 - pow(clampf((t - T_HEAL) / 0.32, 0.0, 1.0), 2.4))
	var rh := 0.17 * rE * clampf((t - T_WAKE) / 1.2, 0.0, 1.0) if t < T_HIT else 0.56 * rE
	var spin := 0.0
	if t >= T_WAKE:
		spin = 0.25 * ease3((t - T_WAKE) / 2.6) if t < T_HIT else 0.25 + 0.9 * ease3((t - T_HIT) / 2.5)
	if t >= T_HEAL:
		spin *= maxf(0.0, 1.0 - (t - T_HEAL) / 0.32)
	return Vector3(rE, rh, spin)


static func shake_amp(t: float) -> float:
	if t > T_WAKE and t < T_INHALE:
		return 2.2 * pow((t - T_WAKE) / (T_INHALE - T_WAKE), 2.0)
	if t >= T_HIT and t < T_HEAL:
		return 7.0 * exp(-(t - T_HIT) * 4.5) + 0.8
	if t >= T_HEAL:
		var k := t - T_HEAL
		return (9.0 * exp(-(k - 0.33) * 3.2) if k > 0.3 else 0.6) * (1.0 if k < 2.4 else 0.0)
	return 0.0


## rift.py `hash01`, in the same 32-bit steps.
static func hash01(a: int, b: int, c: int = -1) -> float:
	var h := 0
	for v: int in ([a, b] if c < 0 else [a, b, c]):
		h = (h * 1000003 + v * 7919 + 12345) & 0xFFFFFFFF
	return float((h * 2654435761) & 0xFFFFFFFF) / 4294967296.0


## The film shook 24 times a second, from its hash, in whole pixels.
static func shake_at(t: float) -> Vector2:
	var amp := shake_amp(t)
	if amp < 0.5:
		return Vector2.ZERO
	var n := int(t * 24.0)
	return Vector2(roundf((hash01(n, 1) * 2.0 - 1.0) * amp), roundf((hash01(n, 2) * 2.0 - 1.0) * amp * 0.6))


## The fall: each part at D0 closes on a horizon Dh on its own clock (nose first), never the
## centre. The table is its inverse, D0 for a depth D, for the ship pass to look up.
func _fill_table(k: float) -> void:
	var u := pow(maxf(k - 0.05, 0.0), 1.6)
	var dh := 5.0 + 22.0 * exp(-k / 0.9)
	var top := -1e9
	for i in FALL_N:
		var d0 := float(i)
		var v := dh + (d0 - dh) * exp(-u * _itau[i]) + d0 * 1e-6
		top = maxf(top, v)
		_dt[i] = top
	var j := 0
	for n in TAB_N:
		var x := float(n) / float(TAB_N - 1)
		var D := TAB_MAX * x * x
		if D < _dt[0]:
			_tab_f[n] = -1.0
			continue
		while j < FALL_N - 2 and _dt[j + 1] < D:
			j += 1
		if D > _dt[FALL_N - 1]:
			_tab_f[n] = 900.0
			continue
		var a := _dt[j]
		var b := _dt[j + 1]
		_tab_f[n] = float(j) + clampf((D - a) / maxf(b - a, 1e-6), 0.0, 1.0)
	_tab_img.set_data(TAB_N, 1, false, Image.FORMAT_RF, _tab_f.to_byte_array())
	_tab.update(_tab_img)


func step(t: float) -> void:
	if not _seamed and hull.ready:
		# the films' seams, baked in the opening (the hull is baked by its third frame)
		_seamed = true
		stage.set1(&"seams", JumpWarpField.film_seams(hull))
	var L := lens_at(t)
	var rE := L.x
	var rh := L.y
	var spin := L.z
	for m: ShaderMaterial in [field.warp, motes]:
		m.set_shader_parameter(&"rh", rh)
	motes.set_shader_parameter(&"t", t)
	shut.set_shader_parameter(&"t", t)
	field.setw(&"rE", rE)
	field.setw(&"spin", spin)
	motes.set_shader_parameter(&"spin", spin)
	var k_hit := t - T_HIT
	field.setw(&"k_hit", k_hit)
	field.setw(&"k_gw", t - T_HEAL - 0.30)
	_step_ship(t)
	_step_light(t, rE, rh)
	# the finish: the shake, and the film's flat fringe for 0.3 s from the tear
	var sh := shake_at(t)
	set_shake(-sh)
	var fr := 0.0
	if k_hit >= 0.0 and k_hit < 0.3:
		fr = roundf(4.0 * (1.0 - k_hit / 0.3))
	stage.set2(&"fringe_px", fr)
	stage.set2(&"centre", tg)


func _step_ship(t: float) -> void:
	var k := t - T_HIT
	var fade := 1.0
	var lurch := 0.0
	if k < 0.0:
		if t > T_INHALE:
			lurch = -3.0 * ease3((t - T_INHALE) / (T_HIT - T_INHALE))
	else:
		fade = exp(-maxf(k - 1.8, 0.0) / 0.45)
		if fade > 0.01:
			_fill_table(k)
	stage.set1(&"alive", 1.0 if fade > 0.01 else 0.0)
	stage.set1(&"fall_k", k if k >= 0.0 else -1.0)
	stage.set1(&"lurch", lurch)
	stage.set1(&"fade", fade)
	stage.set1(&"red_k", clampf(k / 0.4, 0.0, 1.0))
	# the rift's light on the hull: none before the drive wakes, building, a blaze at the tear
	var hk := 0.0
	if t >= T_WAKE:
		hk = 0.9 * pow(clampf((t - T_WAKE) / (T_HIT - T_WAKE), 0.0, 1.0), 1.5)
		if t >= T_HIT:
			hk = 1.2 + 2.2 * exp(-(t - T_HIT) * 3.5)
	stage.set1(&"hull_k", hk)
	var seam_on := t >= T_WAKE and t < T_HIT + 0.6
	stage.set1(&"seam_on", 1.0 if seam_on else 0.0)
	if seam_on:
		var u := clampf((t - T_WAKE) / (T_INHALE - T_WAKE), 0.0, 1.0)
		stage.set1(&"seam_u", u)
		stage.set1(&"seam_ph", (t - T_WAKE) * 0.6 + 1.4 * (t - T_WAKE) * u * u)
		var mul := 1.0
		if t >= T_INHALE:
			mul = 1.5 if t < T_HIT else 2.5 * exp(-(t - T_HIT) * 6.0)
		stage.set1(&"seam_mul", mul)


func _step_light(t: float, rE: float, rh: float) -> void:
	var pre := t >= T_WAKE and t < T_HIT
	field.setw(&"pre_on", 1.0 if pre else 0.0)
	var arcs := PackedVector3Array()
	arcs.resize(7)
	var nb := 0
	if pre:
		var u := clampf((t - T_WAKE) / (T_INHALE - T_WAKE), 0.0, 1.0)
		field.setw(&"pre_u", u)
		field.setw(&"pre_inh", 1.0 if t < T_INHALE else 1.0 - 0.7 * ease3((t - T_INHALE) / (T_HIT - T_INHALE)))
		field.setw(&"pre_flick", 0.8 + 0.2 * hash01(int(t * 12.0), 9))
		nb = int(2.0 + 5.0 * u)
		var tt := int(t * 10.0)
		for i in nb:
			arcs[i] = Vector3(hash01(i, tt) * TAU, 0.15 + 0.3 * hash01(i, tt, 3), rE * (0.8 + 0.4 * hash01(i, tt, 5)))
	field.setw(&"arc_n", nb)
	field.setw(&"arcs", arcs)
	var ring := t >= T_HIT and t < T_HEAL + 0.34
	field.setw(&"ring_on", 1.0 if ring else 0.0)
	field.setw(&"ring_heal", 1.0 if t < T_HEAL else pow(maxf(0.0, 1.0 - (t - T_HEAL) / 0.34), 0.7))
	_step_crack(t)
	# the tear's flash: one white-hot frame from the rift, a smaller one after (30 fps frames)
	var fa := 0.0
	var fr := 150.0
	var lift := 0.0
	if t >= T_HIT and t < T_HIT + 1.0 / 30.0:
		fa = 3.0
		lift = 0.05
	elif t >= T_HIT + 1.0 / 30.0 and t < T_HIT + 2.0 / 30.0:
		fa = 1.2
		fr = 90.0
	flash = fa / 3.0
	if reduce:
		flash = minf(flash, 0.35)
		fa = minf(fa, 3.0 * 0.35)
		lift = 0.0
	field.setw(&"flash_a", fa)
	field.setw(&"flash_r", fr)
	field.setw(&"lift", lift)
	var pin := t >= T_HEAL + 0.30 and t < T_HEAL + 0.30 + 1.0 / 30.0
	field.setw(&"pin_a", (2.5 * (0.35 if reduce else 1.0)) if pin else 0.0)
	var k_shut := t - T_HEAL - 0.28
	field.setw(&"k_shut", k_shut)
	shut.set_shader_parameter(&"k_shut", k_shut)
	var strength := 0.0
	if t >= T_WAKE + 0.4 and t < T_HEAL:
		strength = clampf((t - T_WAKE - 0.4) / 2.0, 0.0, 1.0) if t < T_HIT else 1.0
	motes.set_shader_parameter(&"strength", strength)


## The crack: sixteen jagged segments across the rift, re-rolled each 60th of a second while it
## tears; the scar is the first frame's line again, zipping shut from both ends.
func _step_crack(t: float) -> void:
	var mode := 0
	var k := t - T_HIT
	var seed_i := 77
	var length_px := 170.0
	var a := 0.0
	var keep := 0.5
	if t >= T_HIT - 1.0 / 30.0 and t < T_HIT + 0.2:
		mode = 1
		seed_i = 77 + int(maxf(k, 0.0) * 60.0)
		length_px = 170.0 * (1.0 + 0.3 * clampf(k / 0.1, 0.0, 1.0))
		a = 1.0 - clampf(k / 0.2, 0.0, 1.0)
	var ks := t - T_HEAL - 0.28
	if ks >= 0.0 and ks < 0.9:
		mode = 2
		length_px = 170.0 * 1.3
		keep = 0.5 * (1.0 - ease3(ks / 0.75))
		a = 1.2 * (1.0 - ks / 0.9)
	field.setw(&"crack_mode", mode)
	if mode == 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_i
	var pts := PackedVector2Array()
	var us := PackedFloat32Array()
	var ang0 := 1.2
	for i in 17:
		var u := float(i) / 16.0 - 0.5
		var jit := rng.randfn(0.0, 8.0) * (1.0 - absf(u) * 1.6)
		pts.append(Vector2(cos(ang0) * u * length_px + cos(ang0 + 1.57) * jit, sin(ang0) * u * length_px + sin(ang0 + 1.57) * jit))
		us.append(u)
	field.setw(&"crack", pts)
	field.setw(&"crack_u", us)
	field.setw(&"crack_a", a)
	field.setw(&"crack_keep", keep)
