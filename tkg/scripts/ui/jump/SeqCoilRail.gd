class_name SeqCoilRail
extends JumpSequence

## R10 COIL RAIL. The drive throws seven rings ahead, charges them and fires the ship
## through: each ring flares white as the bow passes, a shock cone opens behind, the hull
## becomes a spear of light and is gone; the rings ring down and go out one by one. The
## film's clock (round3/_r10/r10.py); the rail scales to the room ahead, the rings to the hull.
## Why: docs/why/SeqCoilRail.md#coil-rail

const SHADER := preload("res://shaders/jump/jump_r10.gdshader")

const T_WAKE := 0.6
const RN := 7
const R0 := 58.0
const YAW := 0.17
const TD := [1.25, 1.62, 1.94, 2.22, 2.47, 2.69, 2.89]
const T_CHG := 3.62
const T_HOLD := 4.62
const T_SIL := 4.86
const T_FIRE := 5.0
const DRAW_BACK := 6.0
const V0 := 520.0
const ACC := 4200.0
## The film's nose stood at x 325; the first ring 80 px ahead of it, the rest 78 apart, the
## jump point 44 past the last; the bow passes the last ring at 5.405 and is gone at 5.424.
const FILM_NOSE := 325.0
const RING0 := 80.0
const RING_GAP := 78.0
const JUMP_PAST := 44.0
const T_J := 5.424
const T_OUT0 := 6.05
const OUT_GAP := 0.31
const POP := 0.20
const MID_K := 50.0 / 93.0
const WHT := Vector3(1.00, 0.96, 1.00)
const MAG := Vector3(1.00, 0.36, 0.84)
const VIO := Vector3(0.62, 0.36, 1.00)
const SPARK_N := 16 * 7 + 9 * 7 + 36

var s := 1.0
var hk := 1.0
var nose := 0.0
var nose0 := 0.0
var ax := 0.0
var xj := 0.0
var rxf: PackedFloat32Array = PackedFloat32Array()
var fl: PackedFloat32Array = PackedFloat32Array()
var tl: PackedFloat32Array = PackedFloat32Array()
var tp: PackedFloat32Array = PackedFloat32Array()
var to: PackedFloat32Array = PackedFloat32Array()
var pe: PackedFloat32Array = PackedFloat32Array()
var pv: PackedFloat32Array = PackedFloat32Array()
var _rot := PackedFloat32Array()
var sparks: JumpSparkQuads
var _arc_fr := -1
var _arc_pts := PackedVector2Array()
var _arc_n := 0


func _init() -> void:
	id = &"r10"
	length = 10.0
	hit_t = T_J
	cut_t = T_SIL
	commit_t = 8.8
	flash_floor = 0.14
	for i in RN:
		rxf.append(FILM_NOSE + RING0 + RING_GAP * float(i))
		fl.append(0.24 + (rxf[i] - FILM_NOSE) / 1500.0)
		tl.append(float(TD[i]) + fl[i])
		tp.append(T_FIRE + run_k(rxf[i] - (FILM_NOSE - DRAW_BACK)))
		to.append(T_OUT0 + OUT_GAP * float(i))
	# the chase pulses, emitted faster and faster through the charge
	var tt := T_CHG - 0.35
	while tt < T_HOLD - 0.02:
		pe.append(tt)
		var sc := ease3((tt - T_CHG + 0.35) / (T_HOLD - T_CHG + 0.35))
		pv.append(520.0 + 1300.0 * sc)
		tt += 1.0 / (2.5 + 11.0 * sc)
	# the rings' spin: a speed curve's integral, 600 samples a second, so the glints never jump
	_rot.resize(int(11.0 * 600.0) + 1)
	var acc := 0.0
	for i in _rot.size():
		var tq := float(i) / 600.0
		var spd := 1.2 + 16.0 * pow(charge(tq), 1.6) + (3.0 if (tq > T_HOLD and tq < T_FIRE) else 0.0)
		if tq >= T_FIRE:
			spd += 22.0 * exp(-(tq - T_FIRE) / 0.6)
		acc += spd / 600.0
		_rot[i] = acc


static func run_x(k: float) -> float:
	return V0 * k + 0.5 * ACC * k * k


static func run_k(d: float) -> float:
	return (-V0 + sqrt(V0 * V0 + 2.0 * ACC * maxf(d, 0.0))) / ACC


static func charge(t: float) -> float:
	return ease3((t - T_CHG) / (T_HOLD - T_CHG)) if t < T_FIRE else 0.0


func rot(t: float) -> float:
	var x := clampf(t * 600.0, 0.0, float(_rot.size() - 1))
	var i := int(floor(x))
	if i >= _rot.size() - 1:
		return _rot[_rot.size() - 1]
	return lerpf(_rot[i], _rot[i + 1], x - float(i))


## A film x (along the rail) on this screen.
func xs(film_x: float) -> float:
	return nose + (film_x - FILM_NOSE) * s


func setup(_stage: JumpStage, _place: JumpPlace, _hull: JumpHull) -> void:
	super(_stage, _place, _hull)
	stage.build(SHADER, place.window)
	s = place.ahead(1.0)
	hk = place.hull_k
	nose = place.ink.end.x - 1.0
	nose0 = nose - roundf(DRAW_BACK * s)
	ax = place.ink.position.y + roundf(MID_K * place.ink.size.y)
	xj = xs(rxf[RN - 1] + JUMP_PAST)
	stage.set1(&"nose", nose)
	stage.set1(&"nose0", nose0)
	stage.set1(&"s", s)
	stage.set1(&"hk", hk)
	stage.set1(&"ax", ax)
	stage.set1(&"xj", xj)
	stage.set1(&"core", place.core)
	stage.set1(&"ship", Vector4(place.canvas.position.x, place.canvas.position.y, place.canvas.size.x, place.canvas.size.y))
	var rx := PackedFloat32Array()
	for i in RN:
		rx.append(xs(rxf[i]))
	stage.set1(&"ring_x", rx)
	stage.set2(&"bloom", 0.0 if DisplaySettings.graphics_low else 1.17)
	stage.set2(&"flash_amp", 2.4)
	stage.set2(&"flash_r", 200.0)
	stage.set2(&"flash_col", WHT * 0.55 + MAG * 0.25 + VIO * 0.2)
	stage.set2(&"flash_bar", Vector4(1.0, ax, 22.0, nose0 - 260.0 * s))
	_roll_sparks()


## The sparks each flare, each pop and the jump throw (the film's rng 1010, rolled here).
func _roll_sparks() -> void:
	sparks = JumpSparkQuads.new(JumpSparkQuads.MODE_SPARKS, SPARK_N, stage.global_position)
	stage.mid_node(sparks)
	var r := RandomNumberGenerator.new()
	r.seed = 1010
	var n := 0
	for i in RN:
		for m in 16:
			var th := r.randf_range(0.0, TAU)
			var sp := r.randf_range(30.0, 120.0)
			sparks.put(n, Color(-r.randf_range(20.0, 140.0), cos(th) * sp, r.randf_range(0.6, 1.4), float(n)),
				Color(tp[i], xs(rxf[i]) + R0 * hk * YAW * sin(th), ax + R0 * hk * cos(th), r.randf_range(0.5, 1.6)))
			n += 1
	for i in RN:
		for m in 9:
			var a := r.randf_range(0.0, TAU)
			var sp := r.randf_range(15.0, 55.0)
			sparks.put(n, Color(cos(a) * sp, sin(a) * sp, r.randf_range(0.6, 1.2), float(n)),
				Color(to[i] + POP, xs(rxf[i]), ax, r.randf_range(0.4, 1.0)))
			n += 1
	for m in 36:
		var a := r.randf_range(0.0, TAU)
		var sp := r.randf_range(20.0, 160.0)
		sparks.put(n, Color(cos(a) * sp - 30.0, sin(a) * sp * 0.7, r.randf_range(0.6, 1.5), float(n)),
			Color(T_J, xj, ax, r.randf_range(0.7, 2.2)))
		n += 1


## Ring i at t: [cx (screen), R (px), E, squash, yaw], or [] once gone or not yet thrown.
func ring_state(i: int, t: float) -> Array[float]:
	if t < float(TD[i]) or t >= to[i] + POP:
		return [] as Array[float]
	var u := (t - float(TD[i])) / fl[i]
	var cxf := rxf[i]
	var R := R0
	var E := 0.0
	var sq := 0.0
	if u < 1.0:
		var e := 1.0 - pow(1.0 - u, 3.0)
		cxf = FILM_NOSE + 6.0 + (rxf[i] - FILM_NOSE - 6.0) * e
		R = 9.0 + (R0 - 9.0) * pow(ease3(u * 1.15), 0.8)
		E = 0.95 - 0.35 * u
		return [xs(cxf), R * hk, E, 0.0, YAW + (0.62 - YAW) * pow(1.0 - e, 1.5)]
	var k := t - tl[i]
	R = R0 * (1.0 + 0.10 * exp(-k / 0.09) * cos(TAU * k * 8.0))
	E = 0.38 + 2.2 * exp(-k / 0.06) + 0.06 * sin(t * 9.0 + float(i))
	sq = 0.10 * exp(-k / 0.12) * sin(TAU * k * 9.0)
	var c := charge(t)
	if t < T_FIRE:
		E += pow(c, 1.3)
		for j in pe.size():
			var dt := t - (pe[j] + (rxf[i] - FILM_NOSE) / pv[j])
			if dt >= 0.0 and dt < 0.4:
				E += (0.6 + 0.8 * c) * exp(-dt / 0.05)
		if t > T_HOLD:
			var h := ease5((t - T_HOLD) / (T_SIL - T_HOLD))
			E *= 1.0 - 0.82 * h
			R *= 1.0 - 0.05 * h
		return [xs(cxf), R * hk, E, sq, YAW]
	if t < tp[i]:
		var a := (t - T_FIRE) / maxf(tp[i] - T_FIRE, 1e-3)
		return [xs(cxf), R0 * 0.95 * hk, 0.25 + 1.4 * a * a * a, 0.0, YAW]
	k = t - tp[i]
	E = 0.55 + 7.0 * exp(-k / 0.045) + 1.4 * exp(-k / 0.45)
	R = R0 * (1.0 + 0.20 * exp(-k / 0.07))
	var bell := TAU * k * (5.0 + 0.4 * float(i))
	sq = 0.07 * exp(-k / 1.1) * sin(bell)
	E += 0.25 * exp(-k / 1.1) * (0.5 + 0.5 * sin(bell * 2.0))
	if t >= to[i]:
		var k2 := t - to[i]
		E = E * 0.6 + 2.6 * exp(-k2 / 0.05) + 0.5
		R *= 1.0 - pow(ease3(k2 / POP), 1.6)
		sq = 0.0
	return [xs(cxf), R * hk, E, sq, YAW]


## The hull's offset (screen px, x y) and mode (z): 0 still, 1 running, 2 spear, -1 gone.
func ship_place(t: float) -> Vector3:
	var c := charge(t)
	if t < T_HOLD:
		var d := Vector2.ZERO
		if c > 0.05:
			var fr := int(floor(t * (14.0 + 10.0 * c)))
			if held_rand(fr, 1) < 0.55 * c:
				d.y = float(int(held_rand(fr, 2) * 3.0) - 1)
			if held_rand(fr, 3) < 0.25 * c:
				d.x = float(int(held_rand(fr, 4) * 3.0) - 1)
		return Vector3(d.x, d.y, 0.0)
	if t < T_FIRE:
		return Vector3(-roundf(DRAW_BACK * s * ease5((t - T_HOLD) / 0.26)), 0.0, 0.0)
	if t < T_J:
		return Vector3(roundf(s * run_x(t - T_FIRE)) - roundf(DRAW_BACK * s), 0.0, 1.0)
	if t < T_J + 1.5 / 60.0:
		return Vector3(roundf(s * (rxf[RN - 1] + JUMP_PAST - FILM_NOSE)), 0.0, 2.0)
	return Vector3(0.0, 0.0, -1.0)


func step(t: float) -> void:
	var c := charge(t)
	var kf := t - T_FIRE
	var kj := t - T_J
	var hold_e := ease5((t - T_HOLD) / (T_SIL - T_HOLD)) if t > T_HOLD else 0.0
	stage.set1(&"t", t)
	stage.set1(&"c", c)
	stage.set1(&"hold_e", hold_e)
	stage.set1(&"kf", kf)
	stage.set1(&"kj", kj)
	stage.set1(&"rr", rot(t))
	_step_rings(t, kf)
	_step_rail(t, c, kf, hold_e)
	_step_ship(t, c, kf, kj, hold_e)
	sparks.set_p(&"t", t)
	# the finish: a flash per ring passed and the jump's, the fringe, the shake
	var fls := 0.0
	for i in RN:
		var kk := t - tp[i]
		if kk >= 0.0 and kk < 2.0 / 60.0:
			fls += 0.03 + 0.01 * float(i)
	if kj >= 0.0:
		fls += [0.35, 0.9, 0.3, 0.12][int(kj * 60.0)] if kj < 4.0 / 60.0 else 0.12 * exp(-(kj - 4.0 / 60.0) / 0.12)
	var cxf := xj if kj >= 0.0 else nose0 + s * run_x(maxf(kf, 0.0))
	set_flash(fls, Vector2(cxf, ax), 1.3)
	var cf := 0.0
	if kf >= 0.0 and kj < 0.55:
		cf = 1.0 if kj < 0.0 else 2.5 * exp(-kj / 0.13)
	stage.set2(&"fringe", cf if cf >= 0.5 else 0.0)
	var a := 0.0
	if kf >= 0.0 and kf < T_J - T_FIRE:
		a = 1.0 + 2.0 * kf / (T_J - T_FIRE)
		for i in RN:
			var kk := t - tp[i]
			if kk >= 0.0 and kk < 0.08:
				a += 1.5 * exp(-kk / 0.03)
	if kj >= 0.0 and kj < 0.7:
		a = maxf(a, 7.0 * exp(-kj / 0.17))
	set_shake(Vector2(smooth_noise(t, 0, 17.0), smooth_noise(t, 1, 17.0) * 0.8) * a if a > 0.0 else Vector2.ZERO)


## The rings' part of the instant: each ring, its two thrown ghosts, its flare and its pop.
func _step_rings(t: float, kf: float) -> void:
	var rp := PackedVector4Array()
	var ryaw := PackedFloat32Array()
	var ron := PackedFloat32Array()
	var ruf := PackedFloat32Array()
	var rfl := PackedFloat32Array()
	var rpop := PackedFloat32Array()
	var gp := PackedVector4Array()
	var gyaw := PackedFloat32Array()
	var gon := PackedFloat32Array()
	for i in RN:
		var st := ring_state(i, t)
		var on := not st.is_empty()
		rp.append(Vector4(st[0], st[1], st[2], st[3]) if on else Vector4.ZERO)
		ryaw.append(st[4] if on else YAW)
		ron.append(1.0 if on else 0.0)
		var uf := (t - float(TD[i])) / fl[i]
		ruf.append(uf)
		for lag_i in 2:
			var lag: float = [2.0 / 60.0, 4.0 / 60.0][lag_i]
			var gw: float = [0.60, 0.30][lag_i]
			var g: Array[float] = ring_state(i, t - lag) if (on and uf < 1.15 and t - lag >= float(TD[i])) else ([] as Array[float])
			if g.is_empty():
				gp.append(Vector4.ZERO)
				gyaw.append(YAW)
				gon.append(0.0)
			else:
				gp.append(Vector4(g[0], g[1], g[2] * gw * clampf(1.1 - uf, 0.0, 1.0), g[3]))
				gyaw.append(g[4])
				gon.append(1.0)
		var f := 0.0
		if kf >= 0.0 and t >= tp[i]:
			f = exp(-(t - tp[i]) / 0.05)
		rfl.append(f if f > 0.02 else 0.0)
		var kp := t - to[i] - POP + 0.04
		rpop.append(kp if (kp >= 0.0 and kp < 0.29) else -1.0)
	stage.set1(&"ring_p", rp)
	stage.set1(&"ring_yaw", ryaw)
	stage.set1(&"ring_on", ron)
	stage.set1(&"ring_uf", ruf)
	stage.set1(&"ring_fl", rfl)
	stage.set1(&"ring_pop", rpop)
	stage.set1(&"ghost_p", gp)
	stage.set1(&"ghost_yaw", gyaw)
	stage.set1(&"ghost_on", gon)


## The rail, the chase pulses, the field lines and the arcs between the rings.
func _step_rail(t: float, c: float, kf: float, hold_e: float) -> void:
	var last := -1
	for i in RN:
		if t >= tl[i]:
			last = i
	var rail := Vector4.ZERO
	if last >= 0 and kf < 0.0:
		var a_line := 0.10 + 0.55 * c + 0.9 * hold_e
		var flick := 1.0 + 0.15 * float(int(floor(t * 15.0)) % 2) * c
		rail = Vector4(1.0, xs(rxf[last]), a_line * flick, a_line * 0.25 if c > 0.2 else 0.0)
	stage.set1(&"rail", rail)
	var px := PackedFloat32Array()
	var pln := PackedFloat32Array()
	if t > T_CHG - 0.4 and t < T_HOLD + 0.5:
		for j in pe.size():
			if t < pe[j] or px.size() >= 16:
				continue
			var xhf := FILM_NOSE + pv[j] * (t - pe[j])
			if xhf > rxf[RN - 1] + 20.0:
				continue
			px.append(xs(xhf))
			pln.append((6.0 + 0.035 * pv[j]) * s)
	stage.set1(&"pulse_n", px.size())
	px.resize(16)
	pln.resize(16)
	stage.set1(&"pulse_x", px)
	stage.set1(&"pulse_ln", pln)
	var hold_dim2 := 1.0 - 0.85 * hold_e
	var on := c > 0.02 and t < T_FIRE
	stage.set1(&"field_k", c * hold_dim2 if on else 0.0)
	stage.set1(&"arc_w", 1.5 * hold_dim2)
	# the arcs: jagged lightning ring to ring, re-rolled fifteen times a second
	var fr := int(floor(t * 15.0))
	if on and t < T_SIL:
		if fr != _arc_fr:
			_arc_fr = fr
			_roll_arcs(fr, c)
		stage.set1(&"arc_n", _arc_n)
		stage.set1(&"arc_pts", _arc_pts)
	else:
		stage.set1(&"arc_n", 0)


func _roll_arcs(fr: int, c: float) -> void:
	_arc_pts.clear()
	# a Poisson count by Knuth's product of uniforms, from the held frame's draws
	var lam := 0.4 + 3.2 * pow(c, 1.5)
	var L := exp(-lam)
	var prod := held_rand(fr, 100)
	var n := 0
	var salt := 101
	while prod > L and n < 12:
		n += 1
		prod *= held_rand(fr, salt)
		salt += 1
	_arc_n = n
	for a in n:
		var i := mini(int(held_rand(fr, salt) * 6.0), 5)
		var side := 1.0 if held_rand(fr, salt + 1) < 0.5 else -1.0
		salt += 2
		for k in 7:
			var u := float(k) / 6.0
			var x := xs(rxf[i] + 1.0 + (rxf[i + 1] - rxf[i] - 2.0) * u)
			var jit := (held_rand(fr, salt) * 6.0 - 3.0) if (k > 0 and k < 6) else 0.0
			salt += 1
			_arc_pts.append(Vector2(x, ax + side * (R0 * hk + jit + 4.0 * sin(PI * u))))
	_arc_pts.resize(84)


## The hull's part of the instant: the bow emitter, its place and light, the run, the cone.
func _step_ship(t: float, c: float, kf: float, kj: float, hold_e: float) -> void:
	var pl := ship_place(t)
	var d := Vector2(pl.x, pl.y)
	var mode := int(pl.z)
	stage.set1(&"ship_d", d)
	stage.set1(&"ship_mode", mode)
	var hold_dim := 1.0 - 0.7 * hold_e
	stage.set1(&"hold_dim", hold_dim)
	var emit := Vector4.ZERO
	if mode == 0 and t > T_WAKE:
		var w := ease3((t - T_WAKE) / 0.6)
		var kick := 0.0
		for td: float in TD:
			if t >= td:
				kick += exp(-(t - td) / 0.07)
		emit = Vector4(nose + d.x + 1.0, ax + d.y, (0.35 * w + 2.2 * kick + 1.6 * c) * hold_dim, c)
	stage.set1(&"emit", emit)
	var lx := xs(rxf[0]) if t > float(TD[0]) else xs(FILM_NOSE + 40.0)
	var g := ease3((t - float(TD[0])) / 1.5) if t > float(TD[0]) else 0.0
	stage.set1(&"face", Vector2(lx, (0.2 + 0.7 * g + 0.9 * c) * hold_dim))
	var waves := PackedFloat32Array()
	var starts: Array = [T_WAKE + 0.05]
	for td: float in TD:
		starts.append(td - 0.25)
	for p in pe:
		starts.append(p)
	for ts: float in starts:
		var dtp := t - ts
		if dtp >= 0.0 and dtp <= 0.6 and waves.size() < 20:
			waves.append(dtp)
	stage.set1(&"wave_n", waves.size())
	waves.resize(20)
	stage.set1(&"wave_t", waves)
	var run_len := T_J - T_FIRE
	stage.set1(&"run_p", clampf(kf / run_len, 0.0, 1.0))
	var sm := Vector4.ZERO
	if mode == 1:
		var k_prev := maxf(kf - 2.5 / 60.0, 0.0)
		sm = Vector4(s * run_x(k_prev) - roundf(DRAW_BACK * s), d.x, 10.0, 1.0 + 2.0 * kf / run_len)
	stage.set1(&"smear", sm)
	var tail := nose0 + s * run_x(run_len - 3.0 / 60.0) - place.ink.size.x
	stage.set1(&"spear", Vector2(tail, xj))
	var xn := minf(nose0 + s * run_x(clampf(kf, 0.0, run_len)), xj)
	stage.set1(&"xn", xn)
	var kjp := maxf(kj, 0.0)
	stage.set1(&"fade_j", exp(-kjp / 0.6))
	var gone := nose0 + (xj - nose0) * (pow(ease3(kjp / 1.6), 0.8) if kj > 0.0 else 0.0)
	stage.set1(&"after", Vector4(exp(-kjp / 1.0), gone, xn if kj < 0.0 else xj, 0.5 + 2.2 * exp(-kjp / 0.08)))
	var pinch := Vector3.ZERO
	if c > 0.01 and t < T_FIRE:
		var hold_t := ease5((t - T_HOLD) / (T_FIRE - T_HOLD)) if t > T_HOLD else 0.0
		pinch = Vector3(0.10 * c + 0.06 * hold_t, xs(rxf[RN - 1] + 60.0), 0.0)
	stage.set1(&"pinch", pinch)
