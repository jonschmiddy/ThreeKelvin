class_name GameSkim
extends MiniGame

## SKIM (Jon's comet pick, Nov 21: the harder round 2): a comet swings past the sun and its ice tail
## streams away from it. A probe on a spring tether to the pointer scoops the ice it passes through,
## the young ice near the head counting double; grit bursts out of the head and a hit spills ice. A
## port of `comet_a.js`, step for step: every float the page computes, in the page's order.
## Why: docs/why/MiniGame.md#skim

const W := MiniKit.W
const H := MiniKit.H
const PY := MiniKit.PLAY_Y
const DT := 1.0 / 60.0
## The pass, shorter with depth; the tail thins out over its last FADE seconds.
const PASS: Array[float] = [10.5, 9.5, 8.6, 7.4, 6.4]
const FADE := 2.2
const EMIT := 150.0
## The tail is already streaming when the glass opens: the pass is run on this far before the mount.
const PRE := 2.4
const DAMP := 5.2
const WARN_S := 0.5
## The share of the pass's ice a full hold asks for (tuned on the page's bot).
const FULL: Array[float] = [0.62, 0.56, 0.5, 0.4, 0.3]
## The glow's density field, on 2 px cells.
const CW := 75
const CH := 65
const DEEP := Color("#34495e")
const MID := Color("#26364a")
const OLD := Color("#3a4a5e")
const ROCKC := Color("#4a5a70")
const DIM_RED := Color("#5a2a22")
const ROCK_IN := Color("#5a2a20")
const LIMB := Color("#5a4320")
const LIMB_LO := Color("#2a2216")
const TETHER := Color("#8a4a16")
const RING := Color("#5a3414")
const WHITE := Color("#ffffff")

## The deal (`gen`): the sun, the head's curve, the ripple, the grit's schedule, the grain noise's seed.
var P: Dictionary = {}
var T := 10.5
var VS := 14.0
var CURL := 3.6
var LIFE := 3.4
var CATCH := 3.0
var KEEP := 7.25
var DBL := 0.26
var THIN := 0.0
var SPLIT := 0.0
var SPRING := 28.0
var SPILL := 0.14
var TARGET := 1
var sun_x := 0.0
var sun_y := 0.0
## The pass's own clock (the page's `t`): from -PRE, held until the first press.
var ct := 0.0
var started := false
var over := false
var end_t := -1.0
var hits := 0
var ice := 0
var hurt := 0.0
var flash := 0.0
var last_tick := -1.0
var said_half := false
var said_fade := false
var gi := 0
## The probe, and where the pointer holds its tether.
var prx := 0.0
var pry := 0.0
var prvx := 0.0
var prvy := 0.0
var ax := 0.0
var ay := 0.0
## The ice grains, one array a field, in the page's order (it matters: the scoop draws noise in it).
var qx := PackedFloat64Array()
var qy := PackedFloat64Array()
var qvx := PackedFloat64Array()
var qvy := PackedFloat64Array()
var qage := PackedFloat64Array()
var qlife := PackedFloat64Array()
## Grit in flight: [x, y, vx, vy] each.
var rocks: Array[PackedFloat64Array] = []
## Sparkles where ice was scooped: [x, y, age, k] each (aged a drawn frame at a time, as the page's).
var sparks: Array[Array] = []
var _nz := 0
## The head's curve: P0, P1, P2 as x, y pairs.
var _cv := PackedFloat64Array()
var _acc := 0.0
var _bg: Image
var _blur := PackedFloat64Array()
var _mark := PackedByteArray()
var _cells := PackedInt32Array()


func id() -> StringName:
	return &"skim"


func hint() -> String:
	return "Skim the ice."


func controls() -> Array[String]:
	return ["drag"]


# ---------------------------------------------------------------- the deal

## The comet from the stream, in the page's order of draws.
static func gen(r: RandomNumberGenerator, d: int) -> Dictionary[String, Variant]:
	var tp := PASS[d - 1]
	var sun_left := r.randf() < 0.5
	var down_ := r.randf() < 0.5
	var sy := 70.0 + r.randf() * 12.0
	var ya := 36.0 + r.randf() * 10.0
	var yb := 116.0 - r.randf() * 10.0
	var p0x := _mir(sun_left, 30.0 + r.randf() * 12.0)
	var p2x := _mir(sun_left, 34.0 + r.randf() * 12.0)
	var p1x := _mir(sun_left, 14.0 + r.randf() * 10.0 + d * 3)
	var p1y := (ya + yb) / 2.0 + (r.randf() - 0.5) * 16.0
	var phase := r.randf() * 6.28
	var curl_k := 0.15 + r.randf() * 0.06
	var at := PackedFloat64Array()
	var off := PackedFloat64Array()
	var sp := PackedFloat64Array()
	var bursts := PackedFloat64Array()
	var rate := 0.25 + 0.17 * (d - 1)
	var nb := 2 + d
	var tt := 1.0 + r.randf() * 1.2
	while tt < tp - 0.5:
		var o := (r.randf() - 0.5) * 0.6
		var s := 1.55 + r.randf() * 0.2
		bursts.append(tt)
		for i in nb:
			at.append(tt + i * 0.09)
			off.append(o + (r.randf() - 0.5) * 0.05)
			sp.append(s + (r.randf() - 0.5) * 0.05)
		tt += (0.7 + r.randf() * 0.6) / rate
	var phase2 := r.randf() * 6.28
	var nz := int(floorf(r.randf() * 4294967296.0))
	var out: Dictionary[String, Variant] = {}
	out.assign({sun_left = sun_left, down = down_, sun = [_mir(sun_left, -52.0), sy],
		p0 = [p0x, ya if down_ else yb], p1 = [p1x, p1y], p2 = [p2x, yb if down_ else ya],
		phase = phase, curl_k = curl_k, at = at, off = off, sp = sp, bursts = bursts, phase2 = phase2, nz = nz})
	return out


static func _mir(left: bool, x: float) -> float:
	return x if left else W - 1 - x


## The page's `mulberry`, a 32-bit generator: `mb_next` steps its state (kept in [0, 2^32)),
## `mb_value` is the draw that state gives.
static func mb_next(a: int) -> int:
	return (a + 0x6D2B79F5) & 0xFFFFFFFF


static func mb_value(a: int) -> float:
	var t_ := _imul(a ^ (a >> 15), 1 | a)
	t_ = ((t_ + _imul(t_ ^ (t_ >> 7), 61 | t_)) & 0xFFFFFFFF) ^ t_
	return float((t_ ^ (t_ >> 14)) & 0xFFFFFFFF) / 4294967296.0


## `Math.imul` on two values in [0, 2^32): the low 32 bits of the product, without 64-bit overflow.
static func _imul(x: int, y: int) -> int:
	return (x * (y & 0xFFFF) + (((x * (y >> 16)) & 0xFFFF) << 16)) & 0xFFFFFFFF


func _noise() -> float:
	_nz = mb_next(_nz)
	return mb_value(_nz)


# ---------------------------------------------------------------- the game

func _mount() -> void:
	px = MiniPix.new(W, H)
	P = gen(rng, depth)
	var d := float(depth)
	T = PASS[depth - 1]
	VS = 11.0 + 3.0 * d
	CURL = 2.0 + 1.6 * d
	LIFE = 3.4 * (1.0 + 0.07 * sensors)
	CATCH = 3.0 + 0.35 * sensors
	KEEP = 6.5 + 0.75 * d
	DBL = 0.26 - 0.03 * (d - 1.0)
	THIN = 0.15 * (d - 1.0)
	SPLIT = 0.07 * (d - 2.0) if depth >= 3 else 0.0
	SPRING = 30.0 - 2.0 * d
	SPILL = 0.12 + 0.02 * d
	TARGET = MiniPix.jr(EMIT * (T - FADE / 2.0) * FULL[depth - 1])
	sun_x = float(P.sun[0])
	sun_y = float(P.sun[1])
	_nz = int(P.nz)
	_cv = PackedFloat64Array([P.p0[0], P.p0[1], P.p1[0], P.p1[1], P.p2[0], P.p2[1]])
	prx = _mir(bool(P.sun_left), 118.0)
	pry = 122.0 if P.down else 28.0
	ax = prx
	ay = pry
	_blur.resize(CW * CH)
	_mark.resize(CW * CH)
	_draw_bg()
	ct = -PRE
	while ct < 0.0:
		_sim(true)
	ct = 0.0
	if drawing:
		_render()


## The head at pass time `tt`, on its curve past the sun.
func hx(tt: float) -> float:
	var u := clampf((tt + PRE) / (T + PRE + 0.6), 0.0, 1.0)
	return (1.0 - u) * (1.0 - u) * _cv[0] + 2.0 * u * (1.0 - u) * _cv[2] + u * u * _cv[4]


func hy(tt: float) -> float:
	var u := clampf((tt + PRE) / (T + PRE + 0.6), 0.0, 1.0)
	return (1.0 - u) * (1.0 - u) * _cv[1] + 2.0 * u * (1.0 - u) * _cv[3] + u * u * _cv[5]


## The way from the sun through (x, y), as a unit vector.
func dir_at(x: float, y: float) -> PackedFloat64Array:
	var dx := x - sun_x
	var dy := y - sun_y
	var d := GameSling.hyp(dx, dy)
	if d == 0.0:
		d = 1.0
	return PackedFloat64Array([dx / d, dy / d])


func _emit(h_x: float, h_y: float, hvx: float, hvy: float, k: float) -> void:
	var d0 := dir_at(h_x, h_y)
	var n := EMIT * DT * k * (1.0 - THIN * (0.5 + 0.5 * sin(ct * 2.6 + float(P.phase2))))
	var c := int(floorf(n)) + (1 if _noise() < fmod(n, 1.0) else 0)
	while c > 0:
		c -= 1
		var sp := VS * (0.7 + 0.6 * _noise())
		var sd := (_noise() - 0.5) * 4.0
		var sa := (-1.0 if _noise() < 0.5 else 1.0) * SPLIT
		var ca := cos(sa)
		var sn := sin(sa)
		var dx := d0[0] * ca - d0[1] * sn
		var dy := d0[0] * sn + d0[1] * ca
		qx.append(h_x + (_noise() - 0.5) * 2.0)
		qy.append(h_y + (_noise() - 0.5) * 2.0)
		qvx.append(dx * sp - dy * sd + hvx * 0.4)
		qvy.append(dy * sp + dx * sd + hvy * 0.4)
		qage.append(0.0)
		qlife.append(LIFE * (0.7 + 0.5 * _noise()))


func _spill(n: int) -> void:
	for i in n:
		var a := _noise() * 6.28
		var s := 10.0 + _noise() * 18.0
		qx.append(prx)
		qy.append(pry)
		qvx.append(cos(a) * s + prvx * 0.3)
		qvy.append(sin(a) * s + prvy * 0.3)
		qage.append(LIFE * 0.3)
		qlife.append(LIFE)


## The ice drifts away from the sun, rippling across the tail's line; a grain past its life or off
## the glass goes (the page's backwards splice, kept in order).
func _drift(h_x: float, h_y: float) -> void:
	var w := 0
	var phase := float(P.phase)
	var ck := float(P.curl_k)
	for i in qx.size():
		var age := qage[i] + DT
		var x := qx[i]
		var y := qy[i]
		if age >= qlife[i] or x < -4.0 or x > W + 4 or y < PY - 4 or y > H + 4:
			continue
		var dx := x - sun_x
		var dy := y - sun_y
		var dd := GameSling.hyp(dx, dy)
		if dd == 0.0:
			dd = 1.0
		dx /= dd
		dy /= dd
		var wv := CURL * sin(GameSling.hyp(x - h_x, y - h_y) * ck - ct * 2.1 + phase)
		var vx := qvx[i] + (-dy * wv + dx * 4.0) * DT
		var vy := qvy[i] + (dx * wv + dy * 4.0) * DT
		qx[w] = x + vx * DT
		qy[w] = y + vy * DT
		qvx[w] = vx
		qvy[w] = vy
		qage[w] = age
		qlife[w] = qlife[i]
		w += 1
	qx.resize(w)
	qy.resize(w)
	qvx.resize(w)
	qvy.resize(w)
	qage.resize(w)
	qlife.resize(w)


func _cut(i: int) -> void:
	qx.remove_at(i)
	qy.remove_at(i)
	qvx.remove_at(i)
	qvy.remove_at(i)
	qage.remove_at(i)
	qlife.remove_at(i)


## The grit: it leaves the head on the deal's schedule and flies straight.
func _grit(adv: bool, h_x: float, h_y: float, hvx: float, hvy: float) -> void:
	var at: PackedFloat64Array = P.at
	while adv and gi < at.size() and ct >= at[gi]:
		var d := dir_at(h_x, h_y)
		var a := atan2(d[1], d[0]) + float(P.off[gi])
		var s := VS * float(P.sp[gi])
		gi += 1
		rocks.append(PackedFloat64Array([h_x, h_y, cos(a) * s + hvx * 0.4, sin(a) * s + hvy * 0.4]))
	var keep: Array[PackedFloat64Array] = []
	for o in rocks:
		o[0] += o[2] * DT
		o[1] += o[3] * DT
		if not (o[0] < -4.0 or o[0] > W + 4 or o[1] < PY - 4 or o[1] > H + 4):
			keep.append(o)
	rocks = keep


## The probe: a spring tether to the pointer, with drag (it lags, swings and overshoots).
func _tether() -> void:
	prvx += ((ax - prx) * SPRING - prvx * DAMP) * DT
	prvy += ((ay - pry) * SPRING - prvy * DAMP) * DT
	prx += prvx * DT
	pry += prvy * DT
	if prx < 2.0:
		prx = 2.0
		prvx = absf(prvx) * 0.4
	if prx > W - 3:
		prx = W - 3
		prvx = -absf(prvx) * 0.4
	if pry < PY + 2:
		pry = PY + 2
		prvy = absf(prvy) * 0.4
	if pry > H - 3:
		pry = H - 3
		prvy = -absf(prvy) * 0.4


## One fixed step; `adv` false holds the head still (before the first press the tail streams but
## the pass waits).
func _sim(adv: bool) -> void:
	var h_x := hx(ct)
	var h_y := hy(ct)
	var hvx := (hx(ct + DT) - h_x) / DT if adv else 0.0
	var hvy := (hy(ct + DT) - h_y) / DT if adv else 0.0
	var left := T - ct
	var k := 1.0 if ct < 0.0 else (1.0 if left > FADE else maxf(0.0, left / FADE))
	if ct < T:
		_emit(h_x, h_y, hvx, hvy, k)
	_drift(h_x, h_y)
	_grit(adv, h_x, h_y, hvx, hvy)
	_tether()
	if adv:
		ct += DT
	if not started or over:
		return
	hurt = maxf(0.0, hurt - DT)
	flash = maxf(0.0, flash - DT)
	_scoop()
	var f := float(ice) / TARGET
	if f >= 0.5 and not said_half:
		said_half = true
		say("HALF FULL", "goal")
	if T - ct < FADE and not said_fade and f < 1.0:
		said_fade = true
		say("TAIL FADING", "neutral")
	if hurt <= 0.0:
		_hit(h_x, h_y)
	if ct >= T or f >= 1.0:
		_end()


## Every grain inside the scoop is yours; young ice (near the head) counts double.
func _scoop() -> void:
	var got := 0
	var i := qx.size() - 1
	while i >= 0:
		var x := qx[i]
		var y := qy[i]
		if absf(x - prx) <= CATCH and absf(y - pry) <= CATCH and (x - prx) * (x - prx) + (y - pry) * (y - pry) <= CATCH * CATCH:
			var v := 2 if qage[i] < qlife[i] * DBL else 1
			got += v
			_cut(i)
			if _noise() < 0.5:
				sparks.append([MiniPix.jr(x), MiniPix.jr(y), 0.0, v])
		i -= 1
	if got:
		ice += got
		flash = 0.08
		if t - last_tick > 0.085:
			last_tick = t
			sfx(&"tick")


## Grit, or the head itself: a hit spills a share of the hold and kicks the probe away.
func _hit(h_x: float, h_y: float) -> void:
	var by := PackedFloat64Array()
	for o in rocks:
		if GameSling.hyp(o[0] - prx, o[1] - pry) < 3.4:
			by = o
			break
	var hd := GameSling.hyp(h_x - prx, h_y - pry)
	if by.is_empty() and hd >= KEEP:
		return
	var lost := mini(ice, MiniPix.jr(TARGET * SPILL))
	ice -= lost
	_spill(mini(18, lost))
	hurt = 0.9
	hits += 1
	var hn := hd if hd != 0.0 else 1.0
	prvx += by[2] * 0.9 if not by.is_empty() else (prx - h_x) / hn * 60.0
	prvy += by[3] * 0.9 if not by.is_empty() else (pry - h_y) / hn * 60.0
	sfx(&"hit")
	say("TOO CLOSE" if by.is_empty() else "GRIT HIT", "bad")


func score_now() -> float:
	return clampf(float(ice) / TARGET, 0.0, 1.0)


func _end() -> void:
	if over:
		return
	over = true
	end_t = ct
	var s := score_now()
	if s >= 0.5:
		sfx(&"win")
	say_end("HOLD FULL" if s >= 0.93 else ("TAIL GONE" if s >= 0.5 else "TAIL LOST"), "good" if s >= 0.93 else "neutral")
	done(s, "%d of %d ice, %d hits" % [ice, TARGET, hits])


func _tick(dt: float) -> void:
	_acc += minf(0.1, dt)
	while _acc >= DT:
		_acc -= DT
		_sim(started)
	if drawing:
		_render()


# ---------------------------------------------------------------- drawing

## Stars and the sun's limb just off the edge, drawn once.
func _draw_bg() -> void:
	_bg = Image.create(W, H, false, Image.FORMAT_RGBA8)
	_bg.fill(MiniPix.VOID)
	for y in range(PY, H):
		for x in W:
			var d := GameSling.hyp(x - sun_x, y - sun_y)
			if d < 57.0:
				_bg.set_pixel(x, y, MiniPix.WARN if MiniPix.lit(x, y, (57.0 - d) / 4.0) else LIMB)
			elif d < 66.0:
				_bg.set_pixel(x, y, LIMB if MiniPix.lit(x, y, (66.0 - d) / 9.0) else LIMB_LO)
			elif d < 78.0 and MiniPix.lit(x, y, (78.0 - d) / 12.0 * 0.6):
				_bg.set_pixel(x, y, LIMB_LO)
	var sr := (seed ^ 0x9e37) & 0xFFFFFFFF
	for i in 55:
		sr = mb_next(sr)
		var x := int(floorf(mb_value(sr) * W))
		sr = mb_next(sr)
		var y := PY + int(floorf(mb_value(sr) * (H - PY)))
		sr = mb_next(sr)
		_bg.set_pixel(x, y, MiniPix.COLD if mb_value(sr) < 0.2 else MiniPix.LINE)


## The tail's glow: grains counted on 2 px cells, blurred (weights 2 / 1 / 0.5, scattered from each
## grain: every sum is a multiple of a quarter, so the order cannot change it), dithered under them.
func _glow() -> void:
	_cells.clear()
	for i in qx.size():
		var cx := int(floorf(qx[i] / 2.0))
		var cy := int(floorf((qy[i] - PY) / 2.0))
		if cx < 0 or cx >= CW or cy < 0 or cy >= CH:
			continue
		var v := 1.5 if qage[i] < qlife[i] * 0.5 else 1.0
		for j in range(-1, 2):
			var y := cy + j
			if y < 0 or y >= CH:
				continue
			for k in range(-1, 2):
				var x := cx + k
				if x < 0 or x >= CW:
					continue
				var c := y * CW + x
				if not _mark[c]:
					_mark[c] = 1
					_blur[c] = 0.0
					_cells.append(c)
				_blur[c] += v * (2.0 if j == 0 and k == 0 else (0.5 if j != 0 and k != 0 else 1.0))
	var img := px.img
	for c in _cells:
		_mark[c] = 0
		var v := _blur[c] / 8.0
		if v < 0.35:
			continue
		var x0 := (c % CW) * 2
		var y0 := PY + (c / CW) * 2
		for y in range(y0, y0 + 2):
			for x in range(x0, x0 + 2):
				if v > 1.6 and MiniPix.lit(x, y, minf(1.0, (v - 1.6) / 2.5)):
					img.set_pixel(x, y, DEEP)
				elif MiniPix.lit(x, y, minf(0.9, v / 1.4)):
					img.set_pixel(x, y, MID if v > 0.9 else MiniPix.LINE)


## The grains: bright when young, dimming as they age.
func _grains() -> void:
	for i in qx.size():
		var y := MiniPix.jr(qy[i])
		if y < PY:
			continue
		var f := qage[i] / qlife[i]
		px.dot(MiniPix.jr(qx[i]), y, MiniPix.ICE if f < 0.2 else (MiniPix.CHILL if f < 0.45 else (MiniPix.COLD if f < 0.75 else OLD)))


## The coma and the nucleus, fading once the pass is over.
func _coma(h_x: float, h_y: float) -> void:
	if ct >= T + 3.0:
		return
	var cx := MiniPix.jr(h_x)
	var cy := MiniPix.jr(h_y)
	var fade := 1.0 if ct < T else maxf(0.0, 1.0 - (ct - T) / 3.0)
	for y in range(-7, 8):
		for x in range(-7, 8):
			var k := (1.0 - GameSling.hyp(x, y) / 7.5) * fade
			if k > 0.0 and MiniPix.lit(cx + x, cy + y, k):
				px.dot(cx + x, cy + y, MiniPix.CHILL if k > 0.55 else (MiniPix.COLD if k > 0.3 else MiniPix.LINE))
	px.rect(cx - 1, cy - 2, 3, 1, ROCKC)
	px.rect(cx - 2, cy - 1, 4, 3, ROCKC)
	px.rect(cx - 1, cy + 2, 3, 1, ROCKC)
	px.rect(cx - 1, cy - 1, 2, 1, MiniPix.COLD)
	px.rect(cx - 2, cy, 1, 1, MiniPix.COLD)
	px.rect(cx - 1, cy, 1, 1, MiniPix.ICE)


## Whether a burst is due (its warning, WARN_S before it) or just left.
func warning() -> bool:
	var b: PackedFloat64Array = P.bursts
	for at in b:
		if ct >= at - WARN_S and ct < at + 0.1:
			return true
	return false


## The keep-out ring round the head (red dashes, brighter when the probe is near), and the lane a
## burst will take, blinking before it.
func _keep_out(h_x: float, h_y: float) -> void:
	if not (ct < T + 0.5 and started):
		return
	var near := GameSling.hyp(prx - h_x, pry - h_y) < KEEP + 6.0
	var warn := warning()
	var blink := int(floorf(t * 10.0)) % 2 == 0
	var col := MiniPix.BAD if (warn and blink) or near else DIM_RED
	var n := MiniPix.jr(KEEP * 1.6) * 2
	for a in range(0, n, 2):
		var an := float(a) / n * 6.283 + ct * 0.6
		px.dot(MiniPix.jr(h_x + cos(an) * KEEP), MiniPix.jr(h_y + sin(an) * KEEP), col)
	if warn and blink and gi < (P.at as PackedFloat64Array).size():
		var d := dir_at(h_x, h_y)
		var a := atan2(d[1], d[0]) + float(P.off[gi])
		var k := KEEP + 2.0
		while k < KEEP + 40.0:
			px.dot(MiniPix.jr(h_x + cos(a) * k), MiniPix.jr(h_y + sin(a) * k), DIM_RED)
			k += 3.0


## Grit: dark rock with a red edge and a short red streak behind it, so a burst reads as a lane.
func _rocks() -> void:
	for o in rocks:
		var sp := GameSling.hyp(o[2], o[3])
		if sp == 0.0:
			sp = 1.0
		for k in [2, 4, 6]:
			px.dot(MiniPix.jr(o[0] - o[2] / sp * k), MiniPix.jr(o[1] - o[3] / sp * k), DIM_RED)
	for o in rocks:
		var x := MiniPix.jr(o[0])
		var y := MiniPix.jr(o[1])
		px.rect(x - 1, y - 1, 3, 3, MiniPix.BAD)
		px.rect(x, y, 2, 2, ROCK_IN)
		px.rect(x, y, 1, 1, MiniPix.BEVEL_LO)


## Sparkles where ice was scooped, each a drawn frame older (the page ages them in its draw).
func _sparkles() -> void:
	var i := sparks.size() - 1
	while i >= 0:
		var s: Array = sparks[i]
		s[2] = float(s[2]) + 1.0 / 60.0
		var age := float(s[2])
		if age > 0.26:
			sparks.remove_at(i)
			i -= 1
			continue
		var a := 1 if age < 0.09 else (2 if age < 0.18 else 3)
		var c := MiniPix.ICE if a == 1 else (MiniPix.CHILL if a == 2 else MiniPix.COLD)
		var x: int = s[0]
		var y: int = s[1]
		px.dot(x, y, WHITE if a == 1 and int(s[3]) > 1 else c)
		if a < 3:
			px.dot(x - a, y, c)
			px.dot(x + a, y, c)
			px.dot(x, y - a, c)
			px.dot(x, y + a, c)
		else:
			px.dot(x - 1, y - 1, c)
			px.dot(x + 1, y + 1, c)
		i -= 1


## The tether (a dotted amber line from the pointer, once you have hold of it) and the probe: an
## amber scoop, a dotted ring for its catch, a flash when it scoops, a blink when it is hit.
func _probe() -> void:
	if started:
		var dx := prx - ax
		var dy := pry - ay
		var steps := int(floorf(GameSling.hyp(dx, dy) / 2.0))
		for i in range(1, steps):
			var u := float(i) / steps
			px.dot(MiniPix.jr(ax + dx * u), MiniPix.jr(ay + dy * u), TETHER)
		var cx := MiniPix.jr(ax)
		var cy := MiniPix.jr(ay)
		for q: Vector2i in [Vector2i(-2, 0), Vector2i(2, 0), Vector2i(0, -2), Vector2i(0, 2)]:
			px.dot(cx + q.x, cy + q.y, MiniPix.EMBER)
	var x := MiniPix.jr(prx)
	var y := MiniPix.jr(pry)
	if started and not over:
		var rr := CATCH + 1.2
		for a in range(0, 16, 2):
			var an := a / 16.0 * 6.283
			px.dot(MiniPix.jr(x + cos(an) * rr), MiniPix.jr(y + sin(an) * rr), RING)
	if hurt > 0.0 and int(floorf(t * 12.0)) % 2 == 0:
		return
	px.rect(x - 2, y - 2, 5, 5, MiniPix.BEVEL_LO)
	px.rect(x - 2, y - 1, 5, 3, MiniPix.EMBER)
	px.rect(x - 1, y - 2, 3, 5, MiniPix.EMBER)
	px.rect(x - 1, y - 1, 2, 1, MiniPix.HOT if flash > 0.0 else MiniPix.FLARE)
	px.rect(x, y, 1, 1, MiniPix.BEVEL_LO)


func _render() -> void:
	var h_x := hx(ct)
	var h_y := hy(ct)
	px.img.blit_rect(_bg, Rect2i(0, 0, W, H), Vector2i.ZERO)
	_glow()
	_grains()
	_coma(h_x, h_y)
	_keep_out(h_x, h_y)
	_rocks()
	_sparkles()
	_probe()
	var f := float(ice) / TARGET
	var left := maxf(0.0, T - maxf(0.0, end_t if over and end_t >= 0.0 else ct))
	MiniKit.header(px, {label = "ICE", meter = {w = 57, frac = f, kind = "goal"}, value = "%d%%" % MiniPix.jr(minf(1.0, f) * 100.0)},
		[["TIME", ceili(left) if started else ceili(T)]])
	if not told:
		MiniKit.tell(px, "SKIM THE ICE.", ["drag"] as Array[String], t)
	draw_toast()
	dirty = true


# ---------------------------------------------------------------- input

## The pointer holds the tether: the probe follows it, no button held (a drag on touch).
func move(q: Vector2i) -> void:
	if over:
		return
	ax = clampf(q.x, 1.0, W - 2.0)
	ay = clampf(q.y, PY + 1.0, H - 2.0)


func down(q: Vector2i) -> void:
	if over:
		return
	started = true
	move(q)


func give_up() -> void:
	if over or is_done():
		return
	over = true
	done(0.3 * score_now(), "Gave up at %d of %d ice" % [ice, TARGET])
