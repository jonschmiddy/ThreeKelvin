class_name GameGeyser
extends MiniGame

## GEYSER (Jon's comet pick, Nov 22: comet I): low over a comet's nucleus, where sunlit vents fire gas
## straight up. The sampler floats only in a jet and fills while it does; off it, it sinks, and the
## ground ends the run. The nucleus turns, so jets drift into the night and die: hop to the next. A
## port of `comet_i.js`, step for step. Why: docs/why/MiniGame.md#geyser

const W := MiniKit.W
const H := MiniKit.H
const PY := MiniKit.PLAY_Y
const DT := 1.0 / 60.0
## The page's clock at mount, where `diff.py`'s page starts it (the blinks follow it).
const NOW0 := 1.0
const RUN: Array[float] = [12.5, 11.5, 10.5, 10.0, 9.5]
## How fast the ground turns past (px/s at the top of the arc), the gaps between vents.
const VS: Array[float] = [8.0, 9.5, 11.0, 12.5, 14.0]
const GAPS: Array[Vector2] = [Vector2(34, 46), Vector2(40, 54), Vector2(46, 60), Vector2(50, 66), Vector2(54, 72)]
const SWAYS: Array[float] = [0.06, 0.1, 0.14, 0.18, 0.22]
const GUSTS: Array[float] = [0.1, 0.14, 0.18, 0.22, 0.26]
const PUSHES: Array[float] = [4.0, 7.0, 10.0, 13.0, 16.0]
const SPREAD := 0.16
## Pull, lift at the mouth, how high a jet reaches.
const G := 14.0
const L0 := 38.0
const HMAX := 104.0
## The nucleus, a big arc across the bottom; night left of TERM; a vent wakes at IGN.
const CY := 330.0
const RR := 220.0
const TERM := 58.0
const IGN := 134.0
const RAMP: Array[Color] = [MiniPix.BEVEL_LO, Color("#111823"), Color("#18212d"), MiniPix.LINE, MiniPix.BEVEL_HI, Color("#4a5a70"), MiniPix.COLD]
const GLOW := Color("#34495e")
const GLOW_LO := Color("#26364a")
const LIMB := Color("#5a4320")
const LIMB_LO := Color("#2a2216")
const SOOT := Color("#5a3414")
const MARK := Color("#8a4a16")

## The deal (`gen`): the vents, at their arc positions at t = 0.
var vents: Array[Dictionary] = []
var T := 12.5
var V := 8.0
var W0 := 4.2
var SWAY := 0.06
var GUST := 0.1
var PUSH := 4.0
var RATE := 0.2
var gt := 0.0
var started := false
var over := false
var end_t := -1.0
var fill := 0.0
var crashed := false
var thr := 0.0
var fill_on := false
var said_half := false
var said_low := false
var prx := 0.0
var pry := 0.0
var prvx := 0.0
var prvy := 0.0
var ptr_x := 0.0
## Gas motes: [x, y, vx, vy, age, life] each.
var motes: Array[PackedFloat64Array] = []
var _nz := 0
var _acc := 0.0
var _bg: Image
## The ground's top per column, and its two texture hashes by cell (`_ground_hashes`).
var _top := PackedFloat64Array()
var _h1 := PackedFloat64Array()
var _h2 := PackedFloat64Array()


func id() -> StringName:
	return &"geyser"


func hint() -> String:
	return "Ride the gas jets."


func controls() -> Array[String]:
	return ["drag-h"]


# ---------------------------------------------------------------- the deal

## The vents from the stream, in the page's order: the first one's place, then a gap to each next
## until the run is covered, then each one's sway phase and rate, gust phase and tilt.
static func gen(r: RandomNumberGenerator, d: int) -> Dictionary[String, Variant]:
	var v := VS[d - 1]
	var gap := GAPS[d - 1]
	var s := 26.0 + r.randf() * 10.0
	var out_v: Array = [{s0 = s, first = true}]
	while s - v * RUN[d - 1] < IGN - 75.0 + 40.0:
		s += gap.x + r.randf() * (gap.y - gap.x)
		out_v.append({s0 = s, first = false})
	for q: Dictionary in out_v:
		q.ph = r.randf() * 6.28
		q.w = 1.2 + r.randf() * 0.9
		q.gp = r.randf() * 6.28
		q.tilt = (r.randf() - 0.5) * 0.1
	var out: Dictionary[String, Variant] = {}
	out.assign({vents = out_v})
	return out


static func surf_y(x: float) -> float:
	return CY - sqrt(RR * RR - (x - 75.0) * (x - 75.0))


# ---------------------------------------------------------------- the jets

## Where a vent is at time `tt`: [x, y, its angle on the arc].
func pos_of(v: Dictionary, tt: float) -> Vector3:
	var a := (float(v.s0) - V * tt) / RR
	return Vector3(75.0 + RR * sin(a), CY - RR * cos(a), a)


## When a vent wakes (reaches IGN) and dies (reaches TERM), reckoned once a vent at the mount.
func t_ign(v: Dictionary) -> float:
	return v.ti


func t_die(v: Dictionary) -> float:
	return v.td


func strength(v: Dictionary, tt: float) -> float:
	var ti := t_ign(v)
	var td := t_die(v)
	if tt < ti or tt > td + 0.05:
		return 0.0
	var k := minf(1.0, (tt - ti) / 0.5)
	var left := td - tt
	if left < 1.1:
		k *= maxf(0.0, left / 1.1) * (0.55 + 0.45 * sin(tt * 37.0 + float(v.ph)))
	return maxf(0.0, k)


func warm(v: Dictionary, tt: float) -> bool:
	var ti := t_ign(v)
	return tt > ti - 0.8 and tt < ti + 0.2


## The jet's axis: its mouth (x, y) and its unit direction (ux, uy), leaning as it sways.
func axis(v: Dictionary, tt: float) -> PackedFloat64Array:
	var p := pos_of(v, tt)
	var a := float(p.z) + float(v.tilt) + SWAY * sin(tt * float(v.w) + float(v.ph))
	return PackedFloat64Array([p.x, p.y, sin(a), -cos(a)])


## The gas at a point: [ax, ay, rich]: lift along the jet, a shove off its core, how rich it is.
func gas(x: float, y: float, tt: float) -> PackedFloat64Array:
	var ax := 0.0
	var ay := 0.0
	var rich := 0.0
	for v in vents:
		var k := strength(v, tt)
		if k <= 0.0:
			continue
		var a := axis(v, tt)
		var dx := x - a[0]
		var dy := y - a[1]
		var al := dx * a[2] + dy * a[3]
		if al <= 0.0:
			continue
		var off := -dx * a[3] + dy * a[2]
		var w := W0 + al * SPREAD
		var core := exp(-2.0 * (off / w) * (off / w))
		var f := maxf(0.0, 1.0 - al / HMAX)
		if core < 0.01 or f <= 0.0:
			continue
		var gust := 1.0 + GUST * sin(tt * 4.3 + float(v.gp)) + GUST * 0.6 * sin(tt * 9.1 + float(v.gp) * 2.0)
		var lift := L0 * k * f * core * gust
		var side := minf(1.0, absf(off) / w)
		ax += a[2] * lift + -a[3] * signf(off) * PUSH * k * f * core * side * 2.0
		ay += a[3] * lift + a[2] * signf(off) * PUSH * k * f * core * side * 2.0
		rich = maxf(rich, k * core * (0.35 + 0.65 * f))
	return PackedFloat64Array([ax, ay, rich])


# ---------------------------------------------------------------- the game

func _mount() -> void:
	px = MiniPix.new(W, H)
	vents.assign((gen(rng, depth).vents as Array))
	T = RUN[depth - 1]
	V = VS[depth - 1]
	W0 = (4.2 - 0.3 * (depth - 1)) * (1.0 + 0.06 * sensors)
	SWAY = SWAYS[depth - 1]
	GUST = GUSTS[depth - 1]
	PUSH = PUSHES[depth - 1]
	RATE = 1.0 / (0.42 * T)
	for v in vents:
		v.ti = -9.0 if v.first else (float(v.s0) - RR * asin((IGN - 75.0) / RR)) / V
		v.td = (float(v.s0) - RR * asin((TERM - 75.0) / RR)) / V
	var a0 := axis(vents[0], 0.0)
	var h0 := HMAX * (1.0 - G / L0)
	prx = a0[0] + a0[2] * h0
	pry = a0[1] + a0[3] * h0
	ptr_x = prx
	_nz = (seed ^ 0x6b1) & PageRand.M
	_draw_bg()
	_ground_hashes()
	if drawing:
		_render()


func _noise() -> float:
	_nz = PageRand.mb_next(_nz)
	return PageRand.mb_value(_nz)


## The jets' motes always stream (the glass is alive before the first press); the world waits for it.
func _motes(tt: float) -> void:
	for v in vents:
		var k := strength(v, tt)
		if k <= 0.0:
			continue
		var a := axis(v, tt)
		var n := k * 3.2
		var c := int(floorf(n)) + (1 if _noise() < fmod(n, 1.0) else 0)
		while c > 0:
			c -= 1
			var sp := 50.0 + _noise() * 30.0
			var o := (_noise() - 0.5) * W0 * 1.2
			var vx := a[2] * sp + (_noise() - 0.5) * 6.0
			motes.append(PackedFloat64Array([a[0] - a[3] * o, a[1] + a[2] * o, vx, a[3] * sp, 0.0, 0.9 + _noise() * 0.8]))
	var keep: Array[PackedFloat64Array] = []
	for m in motes:
		m[4] += DT
		m[2] *= 0.985
		m[3] *= 0.985
		m[0] += m[2] * DT
		m[1] += m[3] * DT
		if not (m[4] > m[5] or m[1] < PY):
			keep.append(m)
	motes = keep


func _sim() -> void:
	# the motes are only seen, and only they draw the noise: a run nobody watches skips them
	if drawing:
		_motes(gt if started else 0.0)
	if not started or over:
		return
	gt += DT
	var gs := gas(prx, pry, gt)
	# side thrusters chase the pointer's x; gravity pulls toward the nucleus
	var want := clampf((ptr_x - prx) * 10.0 - prvx * 4.5, -55.0, 55.0)
	thr = want
	var gx := (75.0 - prx) / (CY - pry) * G
	prvx += (want + gs[0] + gx) * DT
	prvy += (G + gs[1]) * DT
	prvx *= 0.995
	prvy *= 0.985
	prx += prvx * DT
	pry += prvy * DT
	if prx < 3.0:
		prx = 3.0
		prvx = 0.0
	if prx > W - 4:
		prx = W - 4
		prvx = 0.0
	if pry < PY + 4:
		pry = PY + 4
		prvy = maxf(0.0, prvy)
	var gy := surf_y(prx)
	if gs[2] > 0.05:
		fill = minf(1.0, fill + RATE * gs[2] * DT)
	var rich := gs[2] > 0.3
	if rich != fill_on:
		fill_on = rich
		sfx_loop(&"hum", rich)
	if fill >= 0.5 and not said_half:
		said_half = true
		say("HALF FULL", "goal")
	if gy - pry < 24.0 and prvy > 0.0 and not said_low:
		said_low = true
		say("TOO LOW", "bad")
	if gy - pry > 34.0:
		said_low = false
	if pry + 3.0 >= gy:
		crashed = true
		pry = gy - 3.0
		sfx(&"hit")
		_end()
		return
	if gt >= T or fill >= 1.0:
		_end()


func score_now() -> float:
	return clampf(fill * (0.85 if crashed else 1.0), 0.0, 1.0)


func _end() -> void:
	if over:
		return
	over = true
	end_t = gt
	sfx_loop(&"hum", false)
	var s := score_now()
	if s >= 0.5 and not crashed:
		sfx(&"win")
	if crashed:
		say_end("CRASHED", "bad")
	else:
		say_end("SAMPLER FULL" if s >= 0.93 else ("GOOD SAMPLE" if s >= 0.5 else "THIN SAMPLE"), "good" if s >= 0.93 else "neutral")
	done(s, "%d%% full%s" % [MiniPix.jr(fill * 100.0), ", crashed" if crashed else ""])


func _tick(dt: float) -> void:
	_acc += minf(0.1, dt)
	while _acc >= DT:
		_acc -= DT
		_sim()
	if drawing:
		_render()


# ---------------------------------------------------------------- drawing

## Stars, and the sun's glow in the top-right corner, drawn once.
func _draw_bg() -> void:
	_bg = Image.create(W, H, false, Image.FORMAT_RGBA8)
	_bg.fill(MiniPix.VOID)
	var sx := W + 36.0
	var sy := -6.0
	for y in range(PY, 80):
		for x in range(80, W):
			var d := GameSling.hyp(x - sx, y - sy)
			if d < 46.0:
				_bg.set_pixel(x, y, MiniPix.WARN if MiniPix.lit(x, y, (46.0 - d) / 4.0) else LIMB)
			elif d < 54.0:
				_bg.set_pixel(x, y, LIMB if MiniPix.lit(x, y, (54.0 - d) / 8.0) else LIMB_LO)
			elif d < 66.0 and MiniPix.lit(x, y, (66.0 - d) / 12.0 * 0.6):
				_bg.set_pixel(x, y, LIMB_LO)
	var sr := (seed ^ 0x9e37) & PageRand.M
	for i in 60:
		sr = PageRand.mb_next(sr)
		var x := int(floorf(PageRand.mb_value(sr) * W))
		sr = PageRand.mb_next(sr)
		var y := PY + int(floorf(PageRand.mb_value(sr) * (H - PY)))
		if GameSling.hyp(x - sx, y - sy) < 60.0:
			continue
		sr = PageRand.mb_next(sr)
		_bg.set_pixel(x, y, MiniPix.COLD if PageRand.mb_value(sr) < 0.2 else MiniPix.LINE)


## The ground's top per column, and the page's two texture hashes for every cell the run can scroll
## to, made once (they are the frame's cost otherwise).
func _ground_hashes() -> void:
	_top.resize(W)
	for x in W:
		_top[x] = surf_y(x)
	_h1.resize(HB1 * HD1)
	_h2.resize(HB2 * HD2)
	for b in HB1:
		for d in HD1:
			_h1[b * HD1 + d] = PageRand.hash(b + 999, d)
	for b in HB2:
		for d in HD2:
			_h2[b * HD2 + d] = PageRand.hash(b, d)


const HB1 := 160
const HD1 := 24
const HB2 := 80
const HD2 := 12


func _hash1(bx: int, dd: int) -> float:
	var b := bx >> 1
	var d := dd >> 1
	return _h1[b * HD1 + d] if b >= 0 and b < HB1 and d < HD1 else PageRand.hash(b + 999, d)


func _hash2(bx: int, dd: int) -> float:
	var b := (bx + 5) >> 2
	var d := (dd + 3) >> 2
	return _h2[b * HD2 + d] if b >= 0 and b < HB2 and d < HD2 else PageRand.hash(b, d)


func _ground(tt: float, n: float) -> void:
	var sc := V * tt
	var blink := int(floorf(n * 8.0)) % 2 == 0
	var low := started and not over and surf_y(prx) - pry < 26.0
	var img := px.img
	for x in W:
		var top := _top[x]
		var ty := ceili(top)
		var night := x < TERM
		var bx := MiniPix.jr(x + sc + (x - 75) * 0)
		for y in range(ty, H):
			var dd := y - top
			var rd := MiniPix.jr(dd)
			var hh := _hash1(bx, rd)
			var lv := 4 if dd < 1.5 else (3 if dd < 4.0 else (2 if dd < 9.0 else 1))
			if hh < 0.15:
				lv -= 1
			elif hh > 0.92:
				lv += 1
			if _hash2(bx, rd) < 0.07 and dd > 3.0:
				lv -= 1
			if night:
				lv -= 2 if x < TERM - 6 else (1 if MiniPix.lit(x, y, 0.5) else 2)
			var c := RAMP[clampi(lv + 1, 0, 6)]
			if low and dd < 1.5 and absf(x - prx) < 12.0 and blink:
				c = MiniPix.BAD
			img.set_pixel(x, y, c)
		if ty - 1 >= PY:
			img.set_pixel(x, ty - 1, MiniPix.BEVEL_LO)


## A jet: a dithered column, brightest in the core and low down; its mouth dark, glowing before it
## wakes, bright while it blows. A row's pixels too thin to show (under 0.08) are never visited.
func _jet(v: Dictionary, tt: float, n: float) -> void:
	var k := strength(v, tt)
	var p := pos_of(v, tt)
	if p.x < -4.0 or p.x > W + 4:
		return
	var a := axis(v, tt)
	if k > 0.0:
		for al in range(1, int(HMAX)):
			var f := 1.0 - al / HMAX
			var w := W0 + al * SPREAD
			var cx := a[0] + a[2] * al
			var cy := a[1] + a[3] * al
			if cy < PY:
				break
			var span := ceili(w * 1.4)
			var q := k * (0.25 + 0.75 * f)
			if q < 0.08:
				continue
			var lim := mini(span, ceili(w * sqrt(log(q / 0.08) / 2.0)) + 1)
			for o in range(-lim, lim + 1):
				var x := MiniPix.jr(cx - a[3] * o)
				var y := MiniPix.jr(cy + a[2] * o)
				if y < PY or y >= H:
					continue
				var core := exp(-2.0 * (o / w) * (o / w))
				var d := k * core * (0.25 + 0.75 * f)
				if d < 0.08:
					continue
				if d > 0.55 and MiniPix.lit(x, y, (d - 0.55) * 2.2):
					px.dot(x, y, MiniPix.ICE if d > 0.8 else MiniPix.CHILL)
				elif MiniPix.lit(x, y, minf(0.75, d * 1.3)):
					px.dot(x, y, GLOW if d > 0.3 else GLOW_LO)
	var mx := MiniPix.jr(p.x)
	var my := MiniPix.jr(p.y)
	px.rect(mx - 2, my, 5, 2, MiniPix.BEVEL_LO)
	if warm(v, tt) and k < 0.5:
		px.rect(mx - 1, my, 3, 1, MiniPix.FLARE if int(floorf(n * 8.0)) % 2 == 0 else MiniPix.EMBER)
	elif k > 0.0:
		px.rect(mx - 1, my, 3, 1, MiniPix.ICE if k > 0.6 else MiniPix.CHILL)


## The sampler: an amber pod with a scoop, the gas it holds in its window, thruster puffs on the side
## it pushes from, soot as it falls; the pointer's mark on its track.
func _sampler(n: float) -> void:
	var x := MiniPix.jr(prx)
	var y := MiniPix.jr(pry)
	px.rect(x - 3, y - 3, 7, 6, MiniPix.BEVEL_LO)
	px.rect(x - 2, y - 2, 5, 4, MiniPix.EMBER)
	px.rect(x - 2, y - 2, 5, 1, MiniPix.FLARE)
	px.rect(x - 1, y - 1, 3, 1, MiniPix.HOT)
	px.rect(x - 3, y - 4, 1, 2, MiniPix.BEVEL_LO)
	px.rect(x + 3, y - 4, 1, 2, MiniPix.BEVEL_LO)
	var fc := MiniPix.jr(fill * 3.0)
	if fc > 0:
		px.rect(x - 1, y + 1 - mini(2, fc - 1), 3, mini(2, fc), MiniPix.ICE)
	if started and not over and absf(thr) > 12.0:
		var fl := int(floorf(n * 20.0)) % 2
		px.rect(x - 5 - fl if thr > 0.0 else x + 4, y, 1 + fl, 1, MiniPix.HOT)
	if started and not over and not fill_on and prvy > 2.0:
		px.rect(x - 1, y + 4, 1, 1, SOOT)
		px.rect(x + 1, y + 5, 1, 1, SOOT)
	if started and not over:
		var xp := MiniPix.jr(ptr_x)
		px.rect(xp, y - 6, 1, 2, MARK)
		px.rect(xp, y + 5, 1, 2, MARK)


func _render() -> void:
	var n := t + NOW0
	var tt := gt if started else 0.0
	px.img.blit_rect(_bg, Rect2i(0, 0, W, H), Vector2i.ZERO)
	for v in vents:
		_jet(v, tt, n)
	for m in motes:
		var f := m[4] / m[5]
		px.dot(MiniPix.jr(m[0]), MiniPix.jr(m[1]), MiniPix.ICE if f < 0.3 else (MiniPix.CHILL if f < 0.6 else MiniPix.COLD))
	_ground(tt, n)
	# sensors 2+: where the next vent will wake
	if sensors >= 2 and not over:
		for v in vents:
			var ti := t_ign(v)
			if ti > tt and ti - tt < 3.0:
				var p := pos_of(v, tt)
				if p.x < W - 1:
					var x := MiniPix.jr(p.x)
					var y := MiniPix.jr(p.y) - 3
					px.dot(x, y, MiniKit.T2)
					px.dot(x - 1, y - 1, MiniKit.T2)
					px.dot(x + 1, y - 1, MiniKit.T2)
				break
	_sampler(n)
	var left := maxf(0.0, T - (end_t if over and end_t >= 0.0 else gt))
	MiniKit.header(px, {label = "GAS", meter = {w = 57, frac = fill, kind = "goal"}, value = "%d%%" % MiniPix.jr(fill * 100.0)},
		[["TIME", ceili(left if started else T)]])
	if not told:
		MiniKit.tell(px, "RIDE THE GAS JETS.", ["drag-h"] as Array[String], t, MiniKit.TELL_TOP)
	draw_toast()
	dirty = true


# ---------------------------------------------------------------- input

## The side thrusters steer for the pointer's x (no button held; a drag on touch).
func move(q: Vector2i) -> void:
	if over:
		return
	ptr_x = clampf(q.x, 2.0, W - 3.0)


## The first press starts the run with the pointer's mark on the sampler.
func down(q: Vector2i) -> void:
	if over:
		return
	if not started:
		started = true
		ptr_x = prx
	else:
		move(q)


func give_up() -> void:
	if over or is_done():
		return
	over = true
	sfx_loop(&"hum", false)
	done(0.3 * score_now(), "Gave up at %d%%" % MiniPix.jr(fill * 100.0))
