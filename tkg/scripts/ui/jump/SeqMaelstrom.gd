class_name SeqMaelstrom
extends JumpSequence

## R8 MAELSTROM. The nebula ahead turns into a whirlpool; the current spins the ship down the
## drain, faster each lap, the eye swallows it in a flash and the storm slowly unwinds. The clock
## and curves are the approved film's (round3/_r8/maelstrom.py, its sound v3); the ship lives
## inside the twist (`JumpWarpField`).
## Why: docs/why/SeqMaelstrom.md#maelstrom

const WARP := preload("res://shaders/jump/jump_r8_warp.gdshader")
const POINTS := preload("res://shaders/jump/jump_r8_points.gdshader")
## Loaded, not preloaded: a fresh clone parses this before the PNG is imported.
const GAS_PATH := "res://art/jump/r8_gas.png"

const T_WAKE := 0.6
const T_CATCH := 3.6
const T_HUSH := 5.95
const T_HIT := 6.2
const T_UNW0 := 7.0
const T_UNW1 := 9.45
## The mix's quietest moment in the hush: the build cue ends there and the hit cue starts.
const CUT := 6.065
const KY := 0.62
const RC := 120.0
## The eye stood 330 px ahead of the nose, 28.5 above the hull's middle line.
const AHEAD := 330.0
const RISE := 28.5
## The twist's and the streaks' clocks are integrals, summed at a millisecond as the film did.
const DT := 0.001
const N_T := 10700

var field: JumpWarpField
var _seamed := false
var tg := Vector2.ZERO
var sk := 1.0
## The hull's centre less the eye (film px), its distance, and its sprite centre (canvas px).
var c0 := Vector2.ZERO
var d0 := 1.0
var sc := Vector2.ZERO
var streaks: ShaderMaterial
var embers: ShaderMaterial
var wake: ShaderMaterial
var _phi := PackedFloat32Array()
var _flow := PackedFloat32Array()
var _peak := 0.0
var _hull_in := false


func _init() -> void:
	id = &"r8"
	length = 10.6
	hit_t = T_HIT
	cut_t = CUT
	commit_t = 9.5
	swap_t = 0.85
	flame_s = T_WAKE
	_phi.resize(N_T)
	_flow.resize(N_T)
	var a := 0.0
	var b := 0.0
	for i in N_T:
		var t := float(i) * DT
		a += omega(t) * DT
		b += flow_rate(t) * DT
		_phi[i] = a
		_flow[i] = b
	_peak = _at(_phi, T_UNW0)


func setup(_stage: JumpStage, _place: JumpPlace, _hull: JumpHull) -> void:
	super(_stage, _place, _hull)
	sk = place.ahead(1.0)
	tg = Vector2(place.ink.end.x - 1.0 + roundf(AHEAD * sk), roundf(place.ink.get_center().y - RISE))
	var ink_c := place.ink.position - place.canvas.position
	sc = Vector2(ink_c.x + (place.ink.size.x - 1.0) * 0.5, ink_c.y + (place.ink.size.y - 1.0) * 0.5 + 4.0)
	c0 = (place.canvas.position + sc - tg) / sk
	d0 = c0.length()
	field = JumpWarpField.new()
	field.build(stage, null, WARP, place.window)
	var ship_r := Vector4(place.canvas.position.x, place.canvas.position.y, place.canvas.size.x, place.canvas.size.y)
	streaks = field.points(POINTS, 260 * 7)
	embers = field.points(POINTS, 60 * 2)
	wake = field.points(POINTS, 39 * 2)
	embers.set_shader_parameter(&"kind", 1)
	wake.set_shader_parameter(&"kind", 2)
	for m: ShaderMaterial in _mats():
		m.set_shader_parameter(&"Tg", tg)
		m.set_shader_parameter(&"S", sk)
		m.set_shader_parameter(&"sc", sc)
		m.set_shader_parameter(&"ship", ship_r)
	field.setw(&"gas", load(GAS_PATH) as Texture2D)
	# the flash is the warp pass's own; the finish keeps its floor unused (the harnesses read it)
	stage.set2(&"flash_floor", 0.0 if reduce else 0.10)


func _mats() -> Array[ShaderMaterial]:
	var out: Array[ShaderMaterial] = [field.warp, streaks, embers, wake]
	return out


func hull_ready() -> void:
	super()
	field.hull_textures(hull)
	streaks.set_shader_parameter(&"hull", hull.tex)
	field.setw(&"hull_on", 1.0)
	_hull_in = true


static func omega(t: float) -> float:
	if t < T_WAKE:
		return 0.0
	if t < T_CATCH:
		return 1.5 * pow((t - T_WAKE) / (T_CATCH - T_WAKE), 1.8)
	if t < T_HIT:
		return 1.5 + 6.5 * pow((t - T_CATCH) / (T_HIT - T_CATCH), 1.6)
	return 8.0 * exp(-(t - T_HIT) / 0.28)


## How fast the streaks run on their own clock: it climbs with the storm.
static func flow_rate(t: float) -> float:
	if t < T_WAKE:
		return 0.0
	if t < T_HIT:
		return 0.15 + omega(t) * 0.42
	return omega(t) * 0.42


func _at(arr: PackedFloat32Array, t: float) -> float:
	var x := clampf(t / DT, 0.0, float(N_T - 1))
	var i := int(floor(x))
	if i >= N_T - 1:
		return arr[N_T - 1]
	return lerpf(arr[i], arr[i + 1], x - float(i))


## The total twist at the core: it winds up, then unwinds home with one small overshoot.
func phi(t: float) -> float:
	if t < T_UNW0:
		return _at(_phi, t)
	if t > T_UNW1:
		return 0.0
	var u := clampf((t - T_UNW0) / (T_UNW1 - T_UNW0), 0.0, 1.0)
	var over := 0.035 * sin(PI * clampf((u - 0.55) / 0.45, 0.0, 1.0)) if u > 0.55 else 0.0
	return _peak * (1.0 - ease3(u)) - _peak * over


static func level(t: float) -> float:
	if t < T_WAKE:
		return 0.0
	if t < T_CATCH:
		return 0.55 * pow(clampf((t - T_WAKE) / (T_CATCH - T_WAKE), 0.0, 1.0), 1.3)
	if t < T_HIT:
		return 0.55 + 0.45 * ease3((t - T_CATCH) / (T_HIT - T_CATCH))
	if t < T_UNW0:
		return 1.0 - 0.25 * ease3((t - T_HIT) / (T_UNW0 - T_HIT))
	return 0.75 * (1.0 - ease3((t - T_UNW0) / (T_UNW1 - 0.25 - T_UNW0)))


static func gas_reach(t: float) -> float:
	if t < T_WAKE:
		return 1.0
	if t < T_HIT:
		return 40.0 + 330.0 * (1.0 - pow(1.0 - clampf((t - T_WAKE) / (T_HIT - T_WAKE), 0.0, 1.0), 1.6))
	return 370.0 + 60.0 * ease3((t - T_HIT) / 1.5)


static func inflow(t: float) -> float:
	if t < T_WAKE:
		return 0.0
	if t < T_UNW0:
		return 0.55 * ease3((t - T_WAKE) / (T_HIT - T_WAKE)) if t < T_HIT else 0.55
	return 0.55 * (1.0 - ease3((t - T_UNW0) / (T_UNW1 - T_UNW0)))


static func fprof(r: float) -> float:
	return 1.0 / (1.0 + (r / RC) * (r / RC))


## The ship's pose in the disc (maelstrom.py `ship_pose`).
class Pose:
	## centre less the eye (film px), scale, extra turn, the twist's weight on it
	var c := Vector2.ZERO
	var s := 1.0
	var beta := 0.0
	var wk := 0.0
	## its distance from the eye, the fall's clock (below zero before it), alive, how white it burns
	var d := 0.0
	var k := -1.0
	var alive := true
	var glow := 0.0


func pose(t: float) -> Pose:
	var p := Pose.new()
	if t < T_CATCH:
		var tremble := 0.0
		if t > T_WAKE + 1.2:
			var u := (t - T_WAKE - 1.2) / (T_CATCH - T_WAKE - 1.2)
			var sgn := 1.0 if SeqRift.hash01(int(t * 20.0), 4) > 0.5 else -1.0
			if u > 0.4 and SeqRift.hash01(int(t * 20.0), 6) < 0.35 + 0.5 * u:
				tremble = sgn
		# it strains back a hair before it is taken
		var back := -3.0 * ease3((t - T_CATCH + 0.35) / 0.35) if t > T_CATCH - 0.35 else 0.0
		p.c = c0 + Vector2(back, tremble)
		p.d = d0
		return p
	p.k = t - T_CATCH
	var u := clampf(p.k / (T_HIT - T_CATCH), 0.0, 1.0)
	# a slow first slide, then down the drain faster and faster
	p.d = d0 * pow(1.0 - pow(u, 1.35), 1.25) + 1.0
	p.c = c0 / d0 * p.d
	p.s = 0.10 + 0.90 * pow(p.d / d0, 0.75)
	p.beta = -0.75 * ease3(p.k / 1.4)
	p.wk = ease3(p.k / 0.6)
	p.alive = t < T_HIT
	p.glow = pow(clampf((u - 0.80) / 0.20, 0.0, 1.0), 1.5)
	return p


## Where the ship's centre is drawn (the forward map), film px about the eye.
func ship_screen(t: float) -> Vector2:
	var p := pose(t)
	var a := phi(t) * p.wk * fprof(p.d)
	var v := p.c
	var vy := v.y / KY
	return Vector2(v.x * cos(a) - vy * sin(a), (v.x * sin(a) + vy * cos(a)) * KY)


static func shake_at(t: float) -> Vector2:
	if t < T_HIT or t >= T_HIT + 0.75:
		return Vector2.ZERO
	var amp := 7.0 * exp(-(t - T_HIT) * 5.0)
	if amp < 0.5:
		return Vector2.ZERO
	var n := int(t * 24.0)
	return Vector2(roundf((SeqRift.hash01(n, 1) * 2.0 - 1.0) * amp), roundf((SeqRift.hash01(n, 2) * 2.0 - 1.0) * amp * 0.6))


func step(t: float) -> void:
	if not _seamed and hull.ready:
		# the films' seams, baked in the opening (the hull is baked by its third frame)
		_seamed = true
		stage.set1(&"seams", JumpWarpField.film_seams(hull))
	var ph := phi(t)
	var lv := level(t)
	var k_hit := t - T_HIT
	for m in _mats():
		m.set_shader_parameter(&"PH", ph)
		m.set_shader_parameter(&"P", inflow(t))
	_step_ship(t)
	field.setw(&"lv", lv)
	field.setw(&"reach", gas_reach(t))
	field.setw(&"k_hit", k_hit)
	var hush := 1.0
	var lip_r := 20.0 + 14.0 * lv
	if t >= T_HUSH and t < T_HIT:
		hush = 1.0 - 0.65 * ease3((t - T_HUSH) / (T_HIT - T_HUSH))
		lip_r *= 1.0 - 0.5 * ease3((t - T_HUSH) / (T_HIT - T_HUSH))
	field.setw(&"hush", hush)
	field.setw(&"lip_r", lip_r)
	# the swallow: one near-white frame from the eye, then a smaller one (30 fps frames)
	var fa := 0.0
	var fr := 150.0
	var lift := 0.0
	if t >= T_HIT and t < T_HIT + 1.0 / 30.0:
		fa = 2.6
		lift = 0.03
	elif t >= T_HIT + 1.0 / 30.0 and t < T_HIT + 2.0 / 30.0:
		fa = 1.4
		fr = 90.0
	flash = fa / 2.6
	if reduce:
		flash = minf(flash, 0.35)
		fa = minf(fa, 2.6 * 0.35)
		lift = 0.0
	field.setw(&"flash_a", fa)
	field.setw(&"flash_r", fr)
	field.setw(&"lift", lift)
	_step_points(t, k_hit)
	set_shake(-shake_at(t))
	var fr_px := 0.0
	if k_hit >= 0.0 and k_hit < 0.3:
		fr_px = roundf(4.0 * (1.0 - k_hit / 0.3))
	stage.set2(&"fringe_px", fr_px)
	stage.set2(&"centre", tg)


func _step_ship(t: float) -> void:
	var p := pose(t)
	var d := p.d
	var beta := p.beta
	var c := p.c
	for m in _mats():
		m.set_shader_parameter(&"wk", p.wk)
		m.set_shader_parameter(&"fc", fprof(d))
		m.set_shader_parameter(&"crel", c)
		m.set_shader_parameter(&"cbsb", Vector2(cos(-beta), sin(-beta)))
		m.set_shader_parameter(&"s_ship", p.s)
	var alive := 1.0 if p.alive else 0.0
	stage.set1(&"alive", alive)
	streaks.set_shader_parameter(&"cov_on", alive if _hull_in else 0.0)
	stage.set1(&"k_ship", p.k)
	# hull light from the eye, building through the storm, blazing as it nears
	var hk := 0.0
	if t >= T_WAKE:
		hk = 0.7 * pow(clampf((t - T_WAKE) / (T_CATCH - T_WAKE), 0.0, 1.0), 1.5) + 0.6 / (1.0 + pow(d / 140.0, 2.0)) * level(t)
	stage.set1(&"hull_k", hk)
	var tl := (-c).normalized()
	stage.set1(&"lxy", Vector2(tl.x * cos(-beta) - tl.y * sin(-beta), tl.x * sin(-beta) + tl.y * cos(-beta)))
	var seam_on := t >= T_WAKE and t < T_CATCH + 0.8
	stage.set1(&"seam_on", 1.0 if seam_on else 0.0)
	if seam_on:
		var u := clampf((t - T_WAKE) / (T_CATCH - T_WAKE), 0.0, 1.0)
		stage.set1(&"seam_u", u)
		stage.set1(&"seam_ph", (t - T_WAKE) * 0.6 + 1.4 * (t - T_WAKE) * u * u)
		stage.set1(&"seam_mul", 2.2 * exp(-(t - T_CATCH) * 3.0) if t >= T_CATCH else 1.0)
	stage.set1(&"deep", clampf(p.k / 2.0, 0.0, 1.0) * 0.45)
	var gl := p.glow
	stage.set1(&"glow", gl)
	if p.alive and gl > 0.0:
		field.setw(&"spot", tg + ship_screen(t) * sk)


func _step_points(t: float, k_hit: float) -> void:
	var on := t >= T_WAKE + 0.3 and t < T_HIT + 0.5
	var vis := 0.0
	if on:
		vis = clampf((t - T_WAKE - 0.3) / 1.5, 0.0, 1.0) * (1.0 if t < T_HIT else maxf(0.0, 1.0 - (t - T_HIT) / 0.5))
	streaks.set_shader_parameter(&"vis", vis)
	streaks.set_shader_parameter(&"tau", _at(_flow, t))
	embers.set_shader_parameter(&"t", t)
	embers.set_shader_parameter(&"k_hit", k_hit)
	# the wake: a ribbon of light along the path the ship has just spiralled
	var pts := PackedVector3Array()
	pts.resize(39)
	if t >= T_CATCH + 0.2 and t < T_HIT + 0.6:
		for j in range(1, 40):
			var tj := t - float(j) * 0.012
			if tj < T_CATCH or tj >= T_HIT:
				continue
			var gl := pose(tj).glow
			var a := pow(1.0 - float(j) / 40.0, 1.5) * (0.3 + 1.2 * gl + 0.4 * clampf((tj - T_CATCH) / 1.5, 0.0, 1.0))
			if t >= T_HIT:
				a *= maxf(0.0, 1.0 - (t - T_HIT) / 0.6)
			var at := tg + ship_screen(tj) * sk
			pts[j - 1] = Vector3(at.x, at.y, a)
	wake.set_shader_parameter(&"wake", pts)
