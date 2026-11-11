class_name SeqSlitScan
extends JumpSequence

## R4 SLIT-SCAN CORRIDOR. A slit of light opens ahead, planes of coloured light rush out of it
## into an endless corridor, the ship dives down it to the point, and the corridor folds shut.
## The clock and every curve are the approved film's (tk-scratch/jump-drive/round3/_r4/r4.py).
## Why: docs/why/SeqSlitScan.md#slit-scan

const SHADER := preload("res://shaders/jump/jump_r4.gdshader")

const T_WAKE := 0.7
const T_SLIT := 0.9
const T_OPEN := 1.5
const T_FULL := 3.7
const T_BREATH := 4.7
const T_HIT := 5.0
const T_FOLD := 5.5
const T_PINCH := 6.0
const T_SHUT := 6.26
const CUT := T_BREATH + 0.03
const RIB := 3.4
const BPX := 270.0
const K := 10.0
const MAG := Vector3(1.00, 0.22, 0.72)
const VIO := Vector3(0.62, 0.34, 1.00)
const EMR := Vector3(0.16, 1.00, 0.50)
const LIME := Vector3(0.74, 1.00, 0.26)
const ROSE := Vector3(1.00, 0.46, 0.60)
const WHT := Vector3(1.00, 0.97, 1.00)
const LIL := Vector3(0.88, 0.76, 1.00)
const PAL := [MAG, VIO, ROSE, EMR, LIME, LIL]
const RIB_PAL := [5, 0, 3, 1, 4]
## The film's vanishing point stood 446 px ahead of the nose, a pixel above the hull's middle line.
const VP_AHEAD := 446.0
const MID_K := 50.0 / 93.0

var vp := Vector2.ZERO
var mid_y := 0.0
var _phi := PackedFloat32Array()


func _init() -> void:
	id = &"r4"
	length = 10.0
	hit_t = T_HIT
	cut_t = CUT
	commit_t = 8.8
	# the corridor's phase is the speed's integral, sampled 600 times a second as the film did
	_phi.resize(int(11.0 * 600.0) + 1)
	var acc := 0.0
	for i in _phi.size():
		acc += speed(float(i) / 600.0) / 600.0
		_phi[i] = acc


static func speed(t: float) -> float:
	if t < T_OPEN:
		return 0.6
	if t < T_BREATH:
		return 0.6 + 7.4 * pow((t - T_OPEN) / (T_BREATH - T_OPEN), 1.8)
	if t < T_HIT:
		return 8.0 * (1.0 - ease3((t - T_BREATH) / (T_HIT - T_BREATH) / 0.6)) + 0.25
	var k := t - T_HIT
	if k < 1.2:
		return 0.25 + 30.0 * (1.0 - exp(-k / 0.04)) * exp(-k / 0.55)
	return 2.0


func off(t: float) -> float:
	var x := clampf(t * 600.0, 0.0, float(_phi.size() - 1))
	var i := int(floor(x))
	if i >= _phi.size() - 1:
		return _phi[_phi.size() - 1]
	return lerpf(_phi[i], _phi[i + 1], x - float(i))


static func dnear(t: float) -> float:
	if t < T_OPEN:
		return 900.0
	var u := pow(ease3((t - T_OPEN) / (T_FULL - 0.3 - T_OPEN)), 0.85)
	return exp(log(900.0) * (1.0 - u) + log(0.95) * u)


static func fold_sq(t: float) -> float:
	if t <= T_FOLD:
		return 1.0
	return maxf(1.0 - pow(ease3(clampf((t - T_FOLD) / (T_PINCH - T_FOLD), 0.0, 1.0)), 1.3), 0.0)


static func fold_sl(t: float) -> float:
	if t <= T_PINCH:
		return 1.0
	return maxf(1.0 - pow(clampf((t - T_PINCH) / (T_SHUT - T_PINCH), 0.0, 1.0), 2.0), 0.0)


static func gain(t: float) -> float:
	if t < T_OPEN:
		return 0.0
	if t < T_BREATH:
		return 0.55 + 0.6 * ease3((t - T_OPEN) / (T_BREATH - T_OPEN))
	if t < T_HIT:
		return 1.15 - 0.35 * ease3((t - T_BREATH) / 0.2)
	return 0.8 + 0.9 * exp(-(t - T_HIT) / 0.25)


static func whiten(t: float) -> float:
	if t > T_BREATH and t < T_HIT:
		return 0.55 * ease3((t - T_BREATH) / 0.25)
	if t >= T_HIT:
		return 0.55 * exp(-(t - T_HIT) / 0.12)
	return 0.0


func setup(_stage: JumpStage, _place: JumpPlace, _hull: JumpHull) -> void:
	super(_stage, _place, _hull)
	stage.build(SHADER, place.window)
	mid_y = place.ink.position.y + roundf(MID_K * place.ink.size.y)
	vp = Vector2(place.ink.end.x + roundf(place.ahead(VP_AHEAD)), mid_y - 1.0)
	stage.set1(&"vp", vp)
	stage.set1(&"mid_y", mid_y)
	stage.set1(&"core", place.core)
	stage.set1(&"ship_x0", place.ink.position.x)
	stage.set1(&"ship", Vector4(place.canvas.position.x, place.canvas.position.y, place.canvas.size.x, place.canvas.size.y))
	stage.set2(&"centre", vp)
	stage.set2(&"bloom", 0.0 if DisplaySettings.graphics_low else 1.0)


## Screen x, colour and falloff of each rib now crossing the hull (the light it throws on it).
func _ribs(t: float, o: float, dn: float) -> Array[Array]:
	var out: Array[Array] = []
	if t < T_OPEN or t >= T_FOLD:
		return out
	var n0 := int(floor((o + 0.3) / RIB))
	for n in range(n0, n0 + 40):
		var d := float(n) * RIB - 0.02 - o
		if d <= maxf(dn, 0.3):
			continue
		var x := vp.x - BPX * K / d
		if x < place.ink.position.x - 40.0:
			continue
		if x > place.ink.end.x + 40.0:
			break
		var c: Vector3 = PAL[RIB_PAL[posmod(n, 5)]] * 0.5 + WHT * 0.5
		out.append([x, c, exp(-d / 26.0)])
		if out.size() >= 4:
			break
	return out


func step(t: float) -> void:
	var k_hit := t - T_HIT
	var k_shut := t - T_SHUT
	var o := off(t)
	var dn := dnear(t)
	var sp := speed(t)
	var g := gain(t)
	var wh := whiten(t)
	var sq := fold_sq(t)
	var sl := fold_sl(t)
	stage.set1(&"t", t)
	stage.set1(&"cor_on", 1.0 if (t >= T_OPEN and t < T_SHUT) else 0.0)
	stage.set1(&"o", o)
	stage.set1(&"dn", dn)
	stage.set1(&"sq", sq)
	stage.set1(&"sl", sl)
	stage.set1(&"blur", sp / 60.0 * 0.9)
	stage.set1(&"gain", g)
	stage.set1(&"wh", wh)
	stage.set1(&"dimk", 0.72 * ease3((t - T_OPEN) / 1.2) if t < T_SHUT else 0.72 * exp(-(t - T_SHUT) / 0.6))
	stage.set1(&"before_shut", 1.0 if t < T_SHUT else 0.0)
	# the slit, the point, the slot, the fold
	var slit := Vector2.ZERO
	if t > T_SLIT and t < T_OPEN + 0.5:
		var u := ease3((t - T_SLIT) / (T_OPEN - T_SLIT))
		var fade := 1.0 - ease3((t - T_OPEN) / 0.5)
		var flick := 1.0 + 0.15 * float(int(floor(t * 15.0)) % 2)
		slit = Vector2((0.6 + 1.6 * u) * fade * flick, 2.0 + 60.0 * u)
	stage.set1(&"slit", slit)
	var br := 0.0
	if t > T_SLIT and t < T_SHUT:
		br = ease3((t - T_SLIT) / 1.2) * (1.0 + (1.2 * exp(-maxf(0.0, t - T_HIT - 0.4) / 0.2) if t > T_HIT else 0.0))
	stage.set1(&"br", br)
	stage.set1(&"slot_k", 0.55 * g * ease3((t - T_OPEN) / 1.0) if (t >= T_OPEN and t < T_SHUT) else 0.0)
	var fold := Vector3.ZERO
	if t > T_FOLD and t < T_SHUT:
		fold = Vector3(ease3((t - T_FOLD) / (T_PINCH - T_FOLD)), 800.0 * sl + 3.0, sl)
	stage.set1(&"fold", fold)
	_step_ship(t, k_hit, k_shut, o, dn, g, wh)
	# the near dashes in the rush, the shards after the shut
	var fga := 0.0
	if t > 3.6 and t < T_FOLD:
		fga = ease3((t - 3.6) / 0.8) * (0.35 if (t > T_BREATH and t < T_HIT) else 1.0)
	stage.set1(&"fga", fga)
	stage.set1(&"ph", o * 0.11)
	stage.set1(&"ln_k", clampf(sp / 30.0, 0.03, 0.5))
	stage.set1(&"speck_on", 1.0 if k_shut >= 0.0 else 0.0)
	# the finish: the flash and fringe of both hits, the shakes
	var fl := 0.0
	if k_hit >= 0.0:
		fl = [0.34, 0.2, 0.1][int(k_hit * 60.0)] if k_hit < 3.0 / 60.0 else 0.1 * exp(-(k_hit - 3.0 / 60.0) / 0.1)
	if k_shut >= 0.0:
		fl = maxf(fl, [0.3, 0.15, 0.07][int(k_shut * 60.0)] if k_shut < 3.0 / 60.0 else 0.07 * exp(-(k_shut - 3.0 / 60.0) / 0.1))
	set_flash(fl, vp, 1.3)
	var cf := 0.0
	for k: float in [k_hit, k_shut]:
		if k >= 0.0 and k < 0.5:
			cf = maxf(cf, 4.0 * exp(-k / 0.12))
	stage.set2(&"fringe", cf)
	var sh := Vector2.ZERO
	for ev: Array in [[T_HIT, 5.0, 0.13], [T_SHUT, 4.0, 0.12]]:
		var k := t - float(ev[0])
		if k >= 0.0 and k < 0.5:
			sh += Vector2(smooth_noise(t, 0), smooth_noise(t, 1) * 0.8) * float(ev[1]) * exp(-k / float(ev[2]))
	set_shake(sh)


## The ship's part of the instant: where it is and how it is lit.
func _step_ship(t: float, k_hit: float, k_shut: float, o: float, dn: float, g: float, wh: float) -> void:
	# the ship: a tremble in the rush, 5 px back in the breath, a jolt, then the dive
	var d := Vector2.ZERO
	var f := 1.0
	if t < T_BREATH:
		if t > 3.0:
			var s := ease3((t - 3.0) / (T_BREATH - 3.0))
			var fr := int(floor(t * (14.0 + 12.0 * s)))
			if held_rand(fr, 5) < 0.65 * s:
				d.y = float(int(held_rand(fr, 6) * 3.0) - 1)
			if held_rand(fr, 7) < 0.3 * s:
				d.x = float(int(held_rand(fr, 8) * 3.0) - 1)
	elif t < T_HIT:
		d.x = -roundf(5.0 * ease5((t - T_BREATH) / 0.25))
	else:
		d.x = 8.0
		if k_hit >= 1.0 / 60.0:
			f = 1.0 / (1.0 + pow((k_hit - 1.0 / 60.0) / 0.055, 2.1))
	stage.set1(&"ship_d", d)
	stage.set1(&"f", f)
	stage.set1(&"jolt", 1.0 if (t >= T_HIT and f >= 0.999) else 0.0)
	stage.set1(&"k_hit", k_hit)
	stage.set1(&"k_shut", k_shut)
	# the hull's light: drive pulses, the planes from above and below, ribs passing
	var tw := t - T_WAKE if (t >= T_WAKE and t < T_HIT) else -1.0
	stage.set1(&"tw", tw)
	stage.set1(&"pulse_s", ease3(tw / (T_BREATH - T_WAKE)))
	var pg := 0.0
	if t >= T_OPEN:
		pg = g * ease3(1.0 - (dn - 3.5) / 3.5 if dn < 7.0 else 0.0) if t < T_HIT else g
	stage.set1(&"plane_g", pg)
	stage.set1(&"topc", (MAG * 0.6 + VIO * 0.4) * (1.0 - wh) + WHT * wh)
	stage.set1(&"botc", (EMR * 0.65 + LIME * 0.35) * (1.0 - wh) + WHT * wh)
	var ribs := _ribs(t, o, dn)
	var rx := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	var rf := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	var rc := PackedVector3Array([Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO])
	for i in ribs.size():
		rx[i] = ribs[i][0]
		rc[i] = ribs[i][1]
		rf[i] = ribs[i][2]
	stage.set1(&"rib_x", rx)
	stage.set1(&"rib_c", rc)
	stage.set1(&"rib_f", rf)
	stage.set1(&"rib_n", ribs.size())
