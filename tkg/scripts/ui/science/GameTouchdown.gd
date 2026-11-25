class_name GameTouchdown
extends MiniGame

## TOUCHDOWN (Jon's comet pick, Nov 25: comet G): land a probe on the ice of a comet's turning
## nucleus. The left button pushes toward the pointer (weak: it steers, it cannot stop you); the
## right button fires the brake out of the probe's front, which stops the fall and leaves sideways
## motion free. Too fast and it bounces or breaks. A port of `comet_g.js`, step for step.
## Why: docs/why/MiniGame.md#touchdown

const W := MiniKit.W
const H := MiniKit.H
const PY := MiniKit.PLAY_Y
const DT := 1.0 / 60.0
## The page's clock at mount, where `diff.py`'s page starts it (the blinks follow it).
const NOW0 := 1.0
## Per depth: time to get down, spin (rad/s), the patch's half width (rad), the safe speed, the
## pull at the surface, the main thruster, the brake's most push, the arrival speed, fuel seconds.
const RUN: Array[float] = [24.0, 22.0, 20.0, 18.0, 16.0]
const SPINS: Array[float] = [0.18, 0.22, 0.26, 0.3, 0.34]
const HWS: Array[float] = [0.42, 0.36, 0.31, 0.27, 0.23]
const SAFES: Array[float] = [10.0, 9.5, 9.0, 8.5, 8.0]
const G0S: Array[float] = [8.0, 8.8, 9.6, 10.4, 11.2]
const THRS: Array[float] = [11.0, 10.5, 10.5, 10.5, 10.5]
const BRKS: Array[float] = [32.0, 30.0, 28.0, 26.0, 24.0]
const V0S: Array[float] = [12.0, 15.0, 18.0, 21.0, 24.0]
const FUELS: Array[float] = [14.0, 12.0, 10.5, 9.0, 8.0]
## The main thruster drinks fuel twice as fast as the brake.
const MAINBURN := 2.0
## The nucleus's middle and mean radius; the feet are FOOT from the probe's middle.
const CX := 80.0
const CY := 94.0
const R0 := 28.0
const FOOT := 4.0
## The probe, legs down (+y): # body, o window, l legs, f feet.
const SPR: Array[String] = ["...###...", "..#ooo#..", ".#######.", ".#######.", "..#####..", "..l...l..", ".l.....l.", "f.......f"]
const ROCK: Array[Color] = [Color("#111823"), Color("#1a2430"), Color("#22303f"), Color("#2e3d4f"), Color("#3d4d61"), Color("#4a5a70")]
const LIMB := Color("#5a4320")
const LIMB_LO := Color("#2a2216")
const SOOT := Color("#5a3414")
const MOTE := Color("#26364a")
const WHITE := Color("#ffffff")
## The start card's lines: it has two controls, so it is the page's own three-line card.
const L1 := "LAND ON THE ICE."
const L2 := "RIGHT-CLICK TO BRAKE."
const L3 := "TO GIVE UP"

## The deal (`gen`).
var P: Dictionary = {}
var T := 24.0
var SPIN := 0.18
var HW := 0.42
var SAFE := 10.0
var BREAK := 20.0
var G0 := 8.0
var THR := 11.0
var BRK := 32.0
var FUEL := 14.0
var TP := 0.0
var RP := 0.0
var _p1 := 0.0
var _p2 := 0.0
var _p3 := 0.0
var vents: Array[Dictionary] = []
var rot := 0.0
## The probe: place and velocity.
var prx := 0.0
var pry := 0.0
var prvx := 0.0
var prvy := 0.0
var aim_x := 0.0
var aim_y := 0.0
var aim_in := false
var started := false
var over := false
var hold := false
var brake := false
var brake_on := false
var thrust_on := false
var thrusting := false
var bax := 0.0
var bay := 0.0
## The run's own clock (the page's `t`), from the first press.
var gt := 0.0
var end_t := -1.0
var fuel := 1.0
var bounces := 0
## How it ended: {} running, else {ok, on_ice, off, sp} or {broke, sp}, {lost}, {time}.
var landed: Dictionary = {}
var said: Dictionary = {}
var hurt := 0.0
var last_speed := 0.0
var _acc := 0.0
var _nz := 0
## Dust motes [x, y, v, k], gas puffs [x, y, vx, vy, age]; the brake's plume [t, m, x, y].
var motes: Array[PackedFloat64Array] = []
var puffs: Array[PackedFloat64Array] = []
var plume := PackedFloat64Array([-9.0, 0.0, 0.0, 1.0])
var _bg: Image
## The nucleus's box, per pixel offset: its distance and angle from the middle (fixed), and the
## two texture hashes by body cell.
var _nd := PackedFloat64Array()
var _na := PackedFloat64Array()
var _hh := PackedFloat64Array()
const NM := 34
const HSPAN := 80


func id() -> StringName:
	return &"touchdown"


func hint() -> String:
	return "Land on the ice."


func controls() -> Array[String]:
	return ["hold"]


# ---------------------------------------------------------------- the deal

## The nucleus, its vents and the probe's arrival from the stream, in the page's order.
static func gen(r: RandomNumberGenerator, d: int, sens: int) -> Dictionary[String, Variant]:
	var hw := HWS[d - 1] * (1.0 + 0.05 * sens)
	var spin := (-1.0 if r.randf() < 0.5 else 1.0) * SPINS[d - 1]
	var p1 := r.randf() * 6.28
	var p2 := r.randf() * 6.28
	var p3 := r.randf() * 6.28
	var tp := r.randf() * 6.28
	var nv := 2 if d >= 5 else (1 if d >= 3 else 0)
	var vs: Array = []
	for i in nv:
		var side := 0.0
		if i == 0:
			side = -1.0 if r.randf() < 0.5 else 1.0
		else:
			side = -float(vs[0].side)
		var a := tp + side * (hw + 0.5 + r.randf() * 0.2)
		var per := 2.6 + r.randf() * 0.8
		var ph := r.randf() * 2.0
		vs.append({side = side, a = a, per = per, ph = ph})
	var x := 78.0 + (r.randf() - 0.5) * 40.0
	var sgn := -1.0 if r.randf() < 0.5 else 1.0
	var side2 := sgn * (4.0 + r.randf() * 4.0)
	var out: Dictionary[String, Variant] = {}
	out.assign({spin = spin, p1 = p1, p2 = p2, p3 = p3, tp = tp, vents = vs, x = x, side = side2})
	return out


static func wrap_a(a: float) -> float:
	a = fmod(a + PI, TAU)
	if a < 0.0:
		a += TAU
	return a - PI


func raw(a: float) -> float:
	return R0 + 3.0 * sin(2.0 * a + _p1) + 2.1 * sin(3.0 * a + _p2) + 1.1 * sin(5.0 * a + _p3)


## The surface's radius at body angle `a`: flat over the patch, blending into the rock beside it.
func rad(a: float) -> float:
	var d := absf(wrap_a(a - TP))
	var w := 1.0 if d < HW + 0.08 else (0.0 if d > HW + 0.55 else 1.0 - (d - HW - 0.08) / 0.47)
	return raw(a) * (1.0 - w) + RP * w


# ---------------------------------------------------------------- the game

func _mount() -> void:
	px = MiniPix.new(W, H)
	var D := depth
	var S := sensors
	P = gen(rng, D, S)
	T = RUN[D - 1]
	SPIN = float(P.spin)
	HW = HWS[D - 1] * (1.0 + 0.05 * S)
	SAFE = SAFES[D - 1] + 0.8 * S
	BREAK = SAFE * 2.0
	G0 = G0S[D - 1]
	THR = THRS[D - 1]
	BRK = BRKS[D - 1]
	FUEL = FUELS[D - 1] * (1.25 if S >= 4 else 1.0)
	_p1 = P.p1
	_p2 = P.p2
	_p3 = P.p3
	TP = P.tp
	RP = raw(TP)
	rot = -PI / 2.0 - TP - SPIN * 2.6
	vents.assign(P.vents as Array)
	prx = P.x
	pry = 22.0
	var dx := CX - prx
	var dy := CY - pry
	var d := GameSling.hyp(dx, dy)
	var v0 := V0S[D - 1]
	var side: float = P.side
	prvx = dx / d * v0 - dy / d * side
	prvy = dy / d * v0 + dx / d * side
	aim_x = prx
	aim_y = pry + 20.0
	_nz = (seed ^ 0x7a11) & PageRand.M
	for i in 40:
		var mx := _noise() * W
		var my := PY + _noise() * (H - PY)
		var mv := 6.0 + _noise() * 10.0
		motes.append(PackedFloat64Array([mx, my, mv, _noise()]))
	if drawing:
		_draw_bg()
		_nucleus_tables()
		_render()


func _noise() -> float:
	_nz = PageRand.mb_next(_nz)
	return PageRand.mb_value(_nz)


func surf_at(x: float, y: float) -> Vector3:
	var a := atan2(y - CY, x - CX)
	return Vector3(a, rad(a - rot), GameSling.hyp(x - CX, y - CY))


func grav_at(x: float, y: float) -> Vector2:
	var dx := CX - x
	var dy := CY - y
	var d := GameSling.hyp(dx, dy)
	if d == 0.0:
		d = 1.0
	var gg := G0 * pow(R0 / maxf(d, R0), 0.35)
	return Vector2(dx / d * gg, dy / d * gg)


func surf_vel(x: float, y: float) -> Vector2:
	return Vector2(-SPIN * (y - CY), SPIN * (x - CX))


## The ground's own speed under a point (the spot on the surface straight below it).
func ground_vel(x: float, y: float) -> Vector2:
	var s := surf_at(x, y)
	var k := minf(1.0, (s.y + FOOT) / (s.z if s.z != 0.0 else 1.0))
	return surf_vel(CX + (x - CX) * k, CY + (y - CY) * k)


func speed_rel() -> float:
	var sv := ground_vel(prx, pry)
	return GameSling.hyp(prvx - sv.x, prvy - sv.y)


## 0 quiet, 1 glowing, 2 puffing.
func vent_state(v: Dictionary, tt: float) -> int:
	var u := fmod(tt + float(v.ph), float(v.per))
	return 0 if u < float(v.per) - 1.5 else (1 if u < float(v.per) - 0.8 else 2)


func _sim() -> void:
	if not started or over:
		return
	gt += DT
	rot += SPIN * DT
	hurt = maxf(0.0, hurt - DT)
	var gr := grav_at(prx, pry)
	var ax := gr.x
	var ay := gr.y
	thrusting = false
	if hold and fuel > 0.0:
		var dx := aim_x - prx
		var dy := aim_y - pry
		var d := GameSling.hyp(dx, dy)
		if d > 1.5:
			ax += dx / d * THR
			ay += dy / d * THR
			thrusting = true
			fuel = maxf(0.0, fuel - DT / FUEL * MAINBURN)
	if thrusting != thrust_on:
		thrust_on = thrusting
		sfx_loop(&"hum", thrusting)
	# the brake cancels the approach (the motion toward the nucleus, and the pull), up to BRK
	bax = 0.0
	bay = 0.0
	if brake and fuel > 0.0:
		var dd := GameSling.hyp(prx - CX, pry - CY)
		if dd == 0.0:
			dd = 1.0
		var ux := (prx - CX) / dd
		var uy := (pry - CY) / dd
		var vr := prvx * ux + prvy * uy
		var gr0 := gr.x * ux + gr.y * uy
		var m := maxf(0.0, minf(BRK, -vr / 0.12 - gr0))
		if m > 0.5:
			bax = ux * m
			bay = uy * m
			ax += bax
			ay += bay
			fuel = maxf(0.0, fuel - DT / FUEL * maxf(0.25, m / BRK))
	var b_on := GameSling.hyp(bax, bay) > 1.0
	if b_on != brake_on:
		brake_on = b_on
		sfx_loop(&"brake", b_on)
	if (hold or brake) and fuel <= 0.0 and not said.has("fuel"):
		said.fuel = 1
		say("NO FUEL", "bad")
	# gas vents puff beside the patch: a puff pushes the probe away from the nucleus
	for v in vents:
		if vent_state(v, gt) != 2:
			continue
		var a := float(v.a) + rot
		var rr := rad(float(v.a))
		var vx := CX + cos(a) * rr
		var vy := CY + sin(a) * rr
		var dx := prx - vx
		var dy := pry - vy
		var al := dx * cos(a) + dy * sin(a)
		var off := absf(-dx * sin(a) + dy * cos(a))
		if al > -1.0 and al < 44.0 and off < 3.0 + al * 0.35:
			ax += cos(a) * 60.0 * (1.0 - al / 50.0)
			ay += sin(a) * 60.0 * (1.0 - al / 50.0)
			var key := "v%d" % MiniPix.jr(gt)
			if not said.has(key) and hurt <= 0.0:
				said[key] = 1
				say("GAS PUFF", "bad")
				hurt = 0.6
				sfx(&"puff")
		if _noise() < 0.7:
			var s := 12.0 + _noise() * 20.0
			var sp := (_noise() - 0.5) * 0.6
			if drawing:
				puffs.append(PackedFloat64Array([vx, vy, cos(a + sp) * s, sin(a + sp) * s, 0.0]))
	prvx += ax * DT
	prvy += ay * DT
	prx += prvx * DT
	pry += prvy * DT
	last_speed = speed_rel()
	var su := surf_at(prx, pry)
	if su.z - su.y < 26.0 and last_speed > SAFE and not said.has("fast") and bounces == 0:
		said.fast = 1
		say("TOO FAST", "bad")
	if su.z <= su.y + FOOT:
		_touch(su)
		if over:
			return
	if prx < -12.0 or prx > W + 12 or pry < PY - 14 or pry > H + 12:
		landed = {lost = true}
		_end()
		return
	if gt >= T:
		landed = {time = true}
		_end()


## Touchdown: soft lands (on the ice or on rock), too fast breaks, between bounces.
func _touch(su: Vector3) -> void:
	var sv := ground_vel(prx, pry)
	var rvx := prvx - sv.x
	var rvy := prvy - sv.y
	var sp := GameSling.hyp(rvx, rvy)
	var nx := (prx - CX) / su.z
	var ny := (pry - CY) / su.z
	var off := wrap_a(su.x - rot - TP)
	var on_ice := absf(off) <= HW
	prx = CX + nx * (su.y + FOOT)
	pry = CY + ny * (su.y + FOOT)
	if sp > BREAK:
		landed = {ok = false, broke = true, sp = sp}
		prvx = sv.x
		prvy = sv.y
		sfx(&"hit")
		_end()
		return
	if sp <= SAFE:
		landed = {ok = true, on_ice = on_ice, off = off, sp = sp}
		prvx = sv.x
		prvy = sv.y
		sfx(&"land" if on_ice else &"hit")
		_end()
		return
	# a bounce: the normal part reflects, softened; the probe skids along with the ground a little
	var vn := rvx * nx + rvy * ny
	var tx := rvx - vn * nx
	var ty := rvy - vn * ny
	prvx = sv.x + tx * 0.7 - vn * 0.5 * nx
	prvy = sv.y + ty * 0.7 - vn * 0.5 * ny
	bounces += 1
	hurt = 0.7
	sfx(&"hit")
	say("BOUNCED", "bad")
	for i in 8:
		var an := _noise() * 6.28
		var v := 6.0 + _noise() * 10.0
		if drawing:
			puffs.append(PackedFloat64Array([prx - nx * FOOT, pry - ny * FOOT, cos(an) * v + nx * 8.0, sin(an) * v + ny * 8.0, 0.2]))


func score_now() -> float:
	if landed.is_empty():
		return 0.0
	if landed.get("ok", false):
		var soft := maxf(0.0, 1.0 - float(landed.sp) / SAFE)
		if landed.on_ice:
			var q := 1.0 - absf(float(landed.off)) / HW
			return maxf(0.0, minf(1.0, (0.7 + 0.18 * q + 0.12 * soft) * pow(0.75, bounces)))
		return (0.25 + 0.08 * soft) * pow(0.75, bounces)
	return 0.05 if landed.get("broke", false) else (0.1 if landed.get("time", false) else 0.0)


func _end() -> void:
	if over:
		return
	over = true
	end_t = gt
	hold = false
	brake = false
	sfx_loop(&"hum", false)
	sfx_loop(&"brake", false)
	var s := score_now()
	if s >= 0.5:
		sfx(&"win")
	var ok: bool = landed.get("ok", false)
	var ice: bool = ok and landed.on_ice
	var top := mini(4, 2 + (depth - 1) / 2)
	var best := floori(s * top + 0.15) >= top
	var word := ("PERFECT LANDING" if best else "LANDED") if ice else ("LANDED ON ROCK" if ok else
		("PROBE BROKE" if landed.get("broke", false) else ("LOST IN SPACE" if landed.get("lost", false) else "NO LANDING")))
	say_end(word, "good" if ice else ("neutral" if ok else "bad"))
	var det := ""
	if ok:
		det = "%s at %.1f px/s, %d bounces" % ["On the ice" if ice else "On rock", float(landed.sp), bounces]
	elif landed.get("broke", false):
		det = "Hit at %d px/s" % MiniPix.jr(float(landed.sp))
	else:
		det = "Drifted off" if landed.get("lost", false) else "Out of time"
	done(s, det)


func _tick(dt: float) -> void:
	_acc += minf(0.1, dt)
	while _acc >= DT:
		_acc -= DT
		_sim()
	if drawing:
		_render()


# ---------------------------------------------------------------- drawing

## Stars, the sun's limb on the left, and the coma's haze with the gas streaming right: drawn once.
func _draw_bg() -> void:
	_bg = Image.create(W, H, false, Image.FORMAT_RGBA8)
	_bg.fill(MiniPix.VOID)
	var sx := -56.0
	var sy := 84.0
	for y in range(PY, H):
		for x in 40:
			var d := GameSling.hyp(x - sx, y - sy)
			if d < 60.0:
				_bg.set_pixel(x, y, MiniPix.WARN if MiniPix.lit(x, y, (60.0 - d) / 4.0) else LIMB)
			elif d < 69.0:
				_bg.set_pixel(x, y, LIMB if MiniPix.lit(x, y, (69.0 - d) / 9.0) else LIMB_LO)
			elif d < 80.0 and MiniPix.lit(x, y, (80.0 - d) / 11.0 * 0.6):
				_bg.set_pixel(x, y, LIMB_LO)
	var sr := (seed ^ 0x9e37) & PageRand.M
	for i in 50:
		sr = PageRand.mb_next(sr)
		var x := int(floorf(PageRand.mb_value(sr) * W))
		sr = PageRand.mb_next(sr)
		var y := PY + int(floorf(PageRand.mb_value(sr) * (H - PY)))
		if x < 34:
			continue
		sr = PageRand.mb_next(sr)
		_bg.set_pixel(x, y, MiniPix.COLD if PageRand.mb_value(sr) < 0.2 else MiniPix.LINE)
	# the page draws the haze every frame, over the background and under everything else
	for y in range(int(CY) - 42, int(CY) + 43):
		for x in range(int(CX) - 42, W):
			if y < PY or y >= H:
				continue
			var dx := x - CX
			var dy := y - CY
			var d := GameSling.hyp(dx, dy)
			var k := (44.0 - d) / 44.0 * 0.32 if d < 44.0 else 0.0
			var tl := maxf(0.0, 1.0 - absf(dy) / (10.0 + dx * 0.25)) * 0.22 * (1.0 - dx / 90.0) if dx > 0.0 else 0.0
			var v := maxf(k, tl)
			if v > 0.0 and MiniPix.lit(x, y, v):
				_bg.set_pixel(x, y, MiniPix.LINE)


## The nucleus box's fixed distance and angle per pixel, and the texture hash per body cell.
func _nucleus_tables() -> void:
	var n := 2 * NM + 1
	_nd.resize(n * n)
	_na.resize(n * n)
	for y in range(-NM, NM + 1):
		for x in range(-NM, NM + 1):
			var i := (y + NM) * n + x + NM
			_nd[i] = GameSling.hyp(x, y)
			_na[i] = atan2(float(y), float(x))
	_hh.resize(HSPAN * HSPAN)
	for b in HSPAN:
		for c in HSPAN:
			_hh[b * HSPAN + c] = PageRand.hash(b - HSPAN / 2, c - HSPAN / 2)


func _hash_at(a: int, b: int) -> float:
	var i := a + HSPAN / 2
	var j := b + HSPAN / 2
	return _hh[i * HSPAN + j] if i >= 0 and i < HSPAN and j >= 0 and j < HSPAN else PageRand.hash(a, b)


func _draw_nucleus(n: float) -> void:
	var M := int(R0) + 6
	var nn := 2 * NM + 1
	var img := px.img
	for y in range(-M, M + 1):
		for x in range(-M, M + 1):
			var X := int(CX) + x
			var Y := int(CY) + y
			if Y < PY:
				continue
			var i := (y + NM) * nn + x + NM
			var d := _nd[i]
			if d > M:
				continue
			var a := _na[i]
			var ba := a - rot
			var rr := rad(ba)
			if d > rr:
				if d <= rr + 1.0:
					img.set_pixel(X, Y, MiniPix.BEVEL_LO)
				continue
			# body coordinates (they turn with the nucleus): craters and grit stay put on the body
			var bx := MiniPix.jr(cos(ba) * d)
			var by := MiniPix.jr(sin(ba) * d)
			var light_n := -cos(a)
			var depth_in := (rr - d) / rr
			var lv := 1.6 + light_n * 1.7 + (0.6 * light_n if depth_in < 0.12 else 0.0) - depth_in * 1.2
			var h := _hash_at(bx >> 1, by >> 1)
			if h < 0.12:
				lv -= 1.0
			elif h > 0.9:
				lv += 0.6
			if _hash_at((bx + 40) >> 2, (by + 40) >> 2) < 0.06:
				lv -= 1.2
			var c := ROCK[clampi(MiniPix.jr(lv), 0, 5)]
			var off := absf(wrap_a(ba - TP))
			if off <= HW and d > rr - 4.5:
				if d > rr - 1.5:
					c = MiniPix.ICE if light_n > -0.5 else MiniPix.CHILL
				elif d > rr - 3.0:
					c = MiniPix.CHILL
				else:
					c = MiniPix.CHILL if MiniPix.lit(X, Y, 0.5) else MiniPix.COLD
			img.set_pixel(X, Y, c)
	# the landing zone: a row of blue lights over the ice, blinking in turn, and a chevron over its middle
	var nl := maxi(5, MiniPix.jr(HW * RP / 2.2))
	var ph := int(floorf(n * 6.0))
	for i in nl + 1:
		var ba := TP - HW + 2.0 * HW * i / nl
		var a := ba + rot
		var rr := rad(ba) + 4.0
		var x := MiniPix.jr(CX + cos(a) * rr)
		var y := MiniPix.jr(CY + sin(a) * rr)
		if y < PY:
			continue
		px.dot(x, y, MiniPix.ICE if (i + ph) % 3 == 0 else MiniKit.T2)
	var a2 := TP + rot
	var b := 1 if int(floorf(n * 3.0)) % 2 else 0
	var ux := cos(a2)
	var uy := sin(a2)
	var r2 := RP + 8.0 + b
	for k in range(-2, 3):
		var x := MiniPix.jr(CX + ux * (r2 + absi(k)) - uy * k)
		var y := MiniPix.jr(CY + uy * (r2 + absi(k)) + ux * k)
		if y >= PY:
			px.dot(x, y, MiniKit.T2)
	# vents: dark holes that glow before they puff
	for v in vents:
		var st := vent_state(v, gt) if started and not over else 0
		var a := float(v.a) + rot
		var rr := rad(float(v.a)) - 0.5
		var x := MiniPix.jr(CX + cos(a) * rr)
		var y := MiniPix.jr(CY + sin(a) * rr)
		var blink := int(floorf(n * 8.0)) % 2 == 0
		px.rect(x - 1, y - 1, 2, 2, MiniPix.HOT if st == 2 else ((MiniPix.FLARE if blink else MiniPix.EMBER) if st == 1 else SOOT))


## The probe, legs toward the nucleus, turned in whole 22.5 degree steps; its legs red when too fast.
func _draw_probe(n: float) -> void:
	var ang := atan2(pry - CY, prx - CX) + PI / 2.0
	var q := MiniPix.jr(ang / (PI / 8.0)) * (PI / 8.0)
	var ca := cos(q)
	var sa := sin(q)
	var ok: bool = landed.get("ok", false)
	var fast := last_speed > SAFE and not ok
	var blink := hurt > 0.0 and int(floorf(n * 12.0)) % 2 == 0
	var leg := MiniPix.GOOD if ok else ((MiniPix.BAD if fast else MiniPix.GOOD) if started else MiniPix.COLD)
	var cx := MiniPix.jr(prx)
	var cy := MiniPix.jr(pry)
	if blink:
		return
	for y in range(-7, 8):
		for x in range(-7, 8):
			var sx := MiniPix.jr(x * ca + y * sa) + 4
			var sy := MiniPix.jr(-x * sa + y * ca + 3.5)
			if sx < 0 or sx > 8 or sy < 0 or sy > 7:
				continue
			var ch := SPR[sy][sx]
			if ch == ".":
				continue
			px.dot(cx + x, cy + y, (MiniPix.FLARE if sy == 0 else MiniPix.EMBER) if ch == "#" else (MiniPix.HOT if ch == "o" else leg))


func _render() -> void:
	var n := t + NOW0
	var live := started and not over
	px.img.blit_rect(_bg, Rect2i(0, 0, W, H), Vector2i.ZERO)
	_draw_dust(live)
	_draw_nucleus(n)
	_draw_puffs(live)
	if sensors >= 2 and live:
		_draw_path()
	if live and aim_in:
		_draw_thrust(n)
	_draw_probe(n)
	_draw_plume(n, live)
	# the header: fuel (yours), the speed (red when too fast to land), time
	var left := maxf(0.0, T - (end_t if over and end_t >= 0.0 else gt))
	var sp_i := MiniPix.jr(last_speed) if started else 0
	var ok: bool = landed.get("ok", false)
	MiniKit.header(px, {label = "FUEL", meter = {w = 37, frac = fuel, kind = "bad" if fuel < 0.2 else "yours"}},
		[["SPEED", sp_i, "bad" if started and last_speed > SAFE and not ok else "good"], ["TIME", ceili(left)]])
	if not told:
		card(px, t)
	draw_toast()
	dirty = true


## The dust streaming off in the tail (it moves only while the run does).
func _draw_dust(live: bool) -> void:
	for m in motes:
		if live:
			m[0] += m[2] * DT
		if m[0] > W + 2:
			m[0] = CX + (_noise() - 0.5) * 20.0
			m[1] = CY + (_noise() - 0.5) * 40.0
		var dy := absf(m[1] - CY)
		if m[0] < CX - 30.0 or dy > 14.0 + (m[0] - CX) * 0.3:
			continue
		px.dot(MiniPix.jr(m[0]), MiniPix.jr(m[1]), MiniPix.COLD if m[3] < 0.3 else MOTE)


func _draw_puffs(live: bool) -> void:
	for i in range(puffs.size() - 1, -1, -1):
		var p := puffs[i]
		if live:
			p[4] += DT
			p[0] += p[2] * DT
			p[1] += p[3] * DT
		if p[4] > 1.1:
			puffs.remove_at(i)
			continue
		var y := MiniPix.jr(p[1])
		if y < PY:
			continue
		px.dot(MiniPix.jr(p[0]), y, MiniPix.HOT if p[4] < 0.3 else (MiniPix.CHILL if p[4] < 0.6 else MiniPix.COLD))


## Sensors 2+: the path you are on (no thrust), 1.6 s ahead.
func _draw_path() -> void:
	var x := prx
	var y := pry
	var vx := prvx
	var vy := prvy
	var rt := rot
	for i in range(1, 97):
		var gr := grav_at(x, y)
		vx += gr.x * DT
		vy += gr.y * DT
		x += vx * DT
		y += vy * DT
		rt += SPIN * DT
		var a := atan2(y - CY, x - CX)
		if GameSling.hyp(x - CX, y - CY) <= rad(a - rt) + FOOT:
			break
		if i % 6 == 0 and y >= PY:
			px.dot(MiniPix.jr(x), MiniPix.jr(y), SOOT)


## The thrust line (where the push goes), the pointer's cross, and the flame on the far side.
func _draw_thrust(n: float) -> void:
	var dx := aim_x - prx
	var dy := aim_y - pry
	var L := GameSling.hyp(dx, dy)
	if L == 0.0:
		L = 1.0
	var ux := dx / L
	var uy := dy / L
	var lc := MiniPix.EMBER if hold and fuel > 0.0 else SOOT
	var k := 6
	while k < minf(L, 26.0):
		px.dot(MiniPix.jr(prx + ux * k), MiniPix.jr(pry + uy * k), lc)
		k += 2
	var ax := MiniPix.jr(aim_x)
	var ay := MiniPix.jr(aim_y)
	for o: Vector2i in [Vector2i(-2, 0), Vector2i(2, 0), Vector2i(0, -2), Vector2i(0, 2)]:
		px.dot(ax + o.x, ay + o.y, MiniPix.EMBER)
	if not thrusting:
		return
	var fl := int(floorf(n * 20.0)) % 3
	for kk in range(4, 7 + fl):
		var c := MiniPix.HOT if kk < 6 else (MiniPix.FLARE if kk < 7 else MiniPix.EMBER)
		px.dot(MiniPix.jr(prx - ux * kk), MiniPix.jr(pry - uy * kk), c)
		if kk == 5:
			px.dot(MiniPix.jr(prx - ux * kk - uy), MiniPix.jr(pry - uy * kk + ux), c)
			px.dot(MiniPix.jr(prx - ux * kk + uy), MiniPix.jr(pry - uy * kk - ux), c)


## The brake's plume out of the probe's front: a fan of flame that grows with the push and flickers,
## gas puffing ahead of it, held 0.14 s after the push.
func _draw_plume(n: float, live: bool) -> void:
	var bm := GameSling.hyp(bax, bay)
	if bm > 1.0:
		plume[1] = bm
		plume[2] = -bax / bm
		plume[3] = -bay / bm
		plume[0] = n
	if not live or n - plume[0] >= 0.14:
		return
	var ux := plume[2]
	var uy := plume[3]
	var fl := int(floorf(n * 24.0)) % 3
	var ln := 6 + MiniPix.jr(minf(1.0, plume[1] / BRK) * 5.0) + fl
	for o: float in [-3.0, -1.5, 0.0, 1.5, 3.0]:
		var ll := ln - absf(o) * 1.2
		var k := 5
		while k <= ll:
			var sp := o * (1.0 + (k - 4) * 0.12)
			var c := WHITE if k < 6 else (MiniPix.HOT if k < 8 else (MiniPix.FLARE if k < 10 else MiniPix.EMBER))
			px.dot(MiniPix.jr(prx + ux * k - uy * sp), MiniPix.jr(pry + uy * k + ux * sp), c)
			k += 1
	if n - plume[0] < 0.02 and _noise() < 0.8:
		var vx := ux * (14.0 + _noise() * 10.0) + (_noise() - 0.5) * 14.0
		var vy := uy * (14.0 + _noise() * 10.0) + (_noise() - 0.5) * 14.0
		puffs.append(PackedFloat64Array([prx + ux * (ln + 1), pry + uy * (ln + 1), vx, vy, 0.25]))


## The start card, the page's own three lines (two controls, then Esc): hold for the main thruster,
## right-click to brake, ESC to give up. Recorded as the kit's tell is, for MiniGameTest.
static func card(p: MiniPix, tt: float) -> Rect2i:
	var w := maxi(maxi(24 + MiniKit.tw(L1), 24 + MiniKit.tw(L2)), 20 + MiniKit.tw(L3)) + 12
	var x := 75 - (w >> 1)
	var y := 44
	var h := 42
	p.rect(x, y, w, h, MiniPix.BEVEL_LO)
	p.rect(x + 1, y + 1, w - 2, h - 2, MiniKit.BORDER)
	p.rect(x + 1, y + 1, w - 2, 1, MiniPix.BEVEL_HI)
	var x1 := x + ((w - 24 - MiniKit.tw(L1)) >> 1)
	_mouse(p, x1, y + 2, tt, false)
	p.text(L1, x1 + 24, y + 6, MiniPix.HOT)
	var x2 := x + ((w - 24 - MiniKit.tw(L2)) >> 1)
	_mouse(p, x2, y + 15, tt + 0.5, true)
	p.text(L2, x2 + 24, y + 19, MiniPix.HOT)
	var x3 := x + ((w - 20 - MiniKit.tw(L3)) >> 1)
	p.icon("key", x3, y + 28, 0.5, "ESC")
	p.text(L3, x3 + 20, y + 33, MiniKit.LABEL)
	var b := Rect2i(x, y, w, h)
	MiniKit.told_px = p
	MiniKit.told_text = L1
	MiniKit.told_icons.assign(["hold", "hold"])
	MiniKit.told_t = tt
	MiniKit.told_at = b
	return b


## The card's mouse, its left or right button lit, and the hold bars ticking beside it.
static func _mouse(p: MiniPix, x: int, y: int, tt: float, right: bool) -> void:
	var M := MiniPix.MOUSE
	for r in M.size():
		for c in 11:
			if M[r][c] == "#":
				p.dot(x + c, y + r + 1, MiniPix.ICE)
	for r in range(1, 4):
		for c in range(2, 9):
			if c != 5:
				p.dot(x + c, y + r + 1, MiniPix.EMBER if (c < 5) != right else MiniPix.LINE)
	for r in range(5, 10):
		for c in range(2, 9):
			if M[r][c] == ".":
				p.dot(x + c, y + r + 1, MiniPix.PANEL)
	for i in 4:
		p.rect(x + 13 + i * 2, y + 10, 1, 2, MiniPix.EMBER if i < 1 + int(floorf(fmod(tt * 3.0, 4.0))) else MiniPix.LINE)


# ---------------------------------------------------------------- input

## The pointer: where the main thruster pushes toward.
func move(q: Vector2i) -> void:
	aim_x = clampf(q.x, 0.0, W - 1.0)
	aim_y = clampf(q.y, PY, H - 1.0)
	aim_in = (q.x >= 0 and q.x < W and q.y >= 0 and q.y < H) or hold


## The left button: the main thruster, toward the pointer. The first press starts the run.
func down(q: Vector2i) -> void:
	if over:
		return
	move(q)
	hold = true
	started = true


func up(_q: Vector2i, _cancel := false) -> void:
	hold = false


## The right button: the brake. It starts the run as the left one does.
func alt(q: Vector2i, pressed: bool) -> void:
	if not pressed:
		brake = false
		return
	if over:
		return
	move(q)
	brake = true
	started = true


func give_up() -> void:
	if over or is_done():
		return
	over = true
	hold = false
	brake = false
	sfx_loop(&"hum", false)
	sfx_loop(&"brake", false)
	done(0.0, "Gave up")
