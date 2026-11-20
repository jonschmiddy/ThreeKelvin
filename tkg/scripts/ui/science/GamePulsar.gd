class_name GamePulsar
extends MiniGame

## PULSAR FOLD (Jon, Nov 17: "so sick"; round 3: "Could be harder. Much harder."): turn the tuning
## dial until the pulses stack into a straight line, then LOCK, before the signal fades. A port of
## the approved `pulsar2.js`: noise, a drifting period, a fainter decoy from sector 3. In its approved
## layout and the UI kit (Nov 20), keeping its own dial (Jon: "can keep their individual dials").
## Why: docs/why/MiniGame.md#the-round-2-games

const CFG := {
	1: {N = 1400, dec = false, noise = 0.62, two = false, chirp = false, drift = 0.05, decoy = false},
	2: {N = 1400, dec = false, noise = 0.75, two = false, chirp = false, drift = 0.06, decoy = false},
	3: {N = 1600, dec = true, noise = 0.65, two = false, chirp = false, drift = 0.03, decoy = true},
	4: {N = 1600, dec = false, noise = 0.6, two = true, chirp = false, drift = 0.05, decoy = true},
	5: {N = 1800, dec = true, noise = 0.75, two = false, chirp = true, drift = 0.035, decoy = true},
}
const PMIN := 30.0
const PMAX := 58.0
const B := 40
const WID := 1.6
const DRIFT_MAX := 3.0
const ACCEPT := 0.5
const FADE := {1: 28.0, 2: 26.0, 3: 30.0, 4: 40.0, 5: 30.0}
const MISS := 0.3
const W := MiniKit.W
const H := MiniKit.H
const GX := 15
const GW := 120
const RAWY := 14
const RAWH := 13
const WFY := 29
const WFH := 55
const PRY := 85
const PRH := 16
## The deck's rule: its own, 11 rows above the kit's 116, to hold Pulsar's own 29 px dial (A, Nov 20:
## the deck moved down the 10 freed rows whole; the glass grew into them).
const DECK := 105
## The dial (r 14, kept, Jon, Nov 20): its ring on rows 107-137.
const DX := MiniKit.GUT + 15
const DY := 122
const DR := 14
const SX := DX + DR + 7
const SW := 104
const SY := 130
## LOCK.
const LB := Rect2i(MiniKit.W - MiniKit.GUT - 33, 114, 33, MiniKit.BTN_H)
const GLASS := Color("#06110b")
const GRAT := Color("#0d2116")
const WHITE_G := Color("#effff7")

var g0: Dictionary = {}
var c: Dictionary = {}
var started := false
var pf_ := 30.0
var ended := false
var lit := 0.0
var stamp_t := 0.0
var stamp_txt := ""
var msg := ""
var clock := 0.0
var fade_s := 28.0
var sig := 1.0
var burst := 0.0
var lost := false
var play := 0.0
var locks: Array = []
var misses := 0
var n_t := 1
var band := Vector2(-1, -1)
var dial: Dictionary = {}
var strip_drag := false
var lock_down := false
var gseed := 0
var gl := {t = -1.0, I = 0.0, tear = [], noise = [], drop = [], jit = PackedInt32Array()}
var _cur: Dictionary = {}
var _plate: Image
var _acc := 0.0
var RAMP: Array[Color] = []
var RAMPON: Array[Color] = []


func id() -> StringName:
	return &"pulsar"


func hint() -> String:
	return "Tune in the pulsar."


func controls() -> Array[String]:
	return ["dial"]


# ---------------------------------------------------------------- the rules

static func u10(v: float) -> int:
	return MiniPix.jr(v * 10.0)


static func rint(r: RandomNumberGenerator, lo: int, hi: int) -> int:
	return lo + int(r.randf() * (hi - lo + 1))


static func gauss(r: RandomNumberGenerator) -> float:
	var u := 0.0
	while u == 0.0:
		u = r.randf()
	return sqrt(-2.0 * log(u)) * cos(2.0 * PI * r.randf())


static func pulses(nn: int, p0: float, t0: float, chirp: float, amp: float) -> PackedFloat64Array:
	var s := PackedFloat64Array()
	s.resize(nn)
	var t_ := t0
	while t_ < nn + 5:
		var p := p0 + chirp * (t_ / nn - 0.5)
		for i in range(maxi(0, int(floorf(t_ - 5.0))), mini(nn - 1, int(ceilf(t_ + 5.0))) + 1):
			var d := i - t_
			s[i] += amp * exp(-d * d / (2.0 * WID * WID))
		t_ += p
	return s


## The signal folded at period `pf`: each row's bins and the whole profile.
static func fold(s: PackedFloat64Array, pf: float) -> Dictionary[String, Variant]:
	var nn := s.size()
	var rr := int(floorf(nn / pf))
	var rows: Array[PackedFloat64Array] = []
	var cnt: Array[PackedFloat64Array] = []
	for r in rr:
		var a := PackedFloat64Array()
		a.resize(B)
		rows.append(a)
		var b := PackedFloat64Array()
		b.resize(B)
		cnt.append(b)
	var i := 0
	while i < rr * pf and i < nn:
		var r := int(floorf(i / pf))
		if r >= rr:
			break
		var b := mini(B - 1, int(floorf((i - r * pf) / pf * B)))
		rows[r][b] += s[i]
		cnt[r][b] += 1.0
		i += 1
	var prof := PackedFloat64Array()
	prof.resize(B)
	var pc := PackedFloat64Array()
	pc.resize(B)
	for r in rr:
		for b in B:
			if cnt[r][b]:
				prof[b] += rows[r][b]
				pc[b] += cnt[r][b]
				rows[r][b] /= cnt[r][b]
	for b in B:
		prof[b] = prof[b] / pc[b] if pc[b] else 0.0
	var out: Dictionary[String, Variant] = {}
	out.assign({rows = rows, prof = prof})
	return out


static func profile(s: PackedFloat64Array, pf: float) -> PackedFloat64Array:
	var nn := s.size()
	var rr := int(floorf(nn / pf))
	var end := minf(nn, rr * pf)
	var prof := PackedFloat64Array()
	prof.resize(B)
	var pc := PackedFloat64Array()
	pc.resize(B)
	var i := 0
	while i < end:
		var r := int(floorf(i / pf))
		if r >= rr:
			break
		var b := mini(B - 1, int(floorf((i - r * pf) / pf * B)))
		prof[b] += s[i]
		pc[b] += 1.0
		i += 1
	for b in B:
		prof[b] = prof[b] / pc[b] if pc[b] else 0.0
	return prof


## How sharp a folded profile is: its smoothed peak over its mean.
static func sharp(prof: PackedFloat64Array) -> float:
	var m := 0.0
	var pk := -1e9
	for b in B:
		m += prof[b]
	m /= B
	for b in B:
		var v := 0.25 * prof[(b + B - 1) % B] + 0.5 * prof[b] + 0.25 * prof[(b + 1) % B]
		if v > pk:
			pk = v
	return pk - m


## How far the true periods have drifted after `tt` seconds: a slow walk turning back at DRIFT_MAX.
static func drift_of(g: Dictionary, tt: float) -> float:
	var x := absf(float(g.rate)) * tt
	var a := DRIFT_MAX
	var y := fmod(x, 4.0 * a)
	var v := y if y < a else (2.0 * a - y if y < 3.0 * a else y - 4.0 * a)
	return signf(float(g.rate)) * v


static func _per(c_: Dictionary, r: RandomNumberGenerator) -> float:
	if c_.dec:
		return rint(r, u10(PMIN + DRIFT_MAX), u10(PMAX - DRIFT_MAX)) / 10.0
	return float(rint(r, int(PMIN + DRIFT_MAX), int(PMAX - DRIFT_MAX)))


## {cfg, P (periods), sig, start, chirp, S (sharpness by tenth), base, peaks, step, decoy, dpk, rate}.
static func gen(r: RandomNumberGenerator, d: int, sn: int) -> Dictionary[String, Variant]:
	var c_: Dictionary = CFG.get(d, CFG[1])
	var out: Dictionary[String, Variant] = {}
	var nn: int = c_.N
	var noise := float(c_.noise) * (1.0 - 0.1 * sn)
	for tries in 200:
		var per: Array[float] = [_per(c_, r)]
		if c_.two:
			var p2 := _per(c_, r)
			while absf(p2 - per[0]) < 8.0:
				p2 = _per(c_, r)
			per.append(p2)
		var decoy := -1.0
		if c_.decoy:
			for k in 50:
				var dd := per[0] + (-1.0 if r.randf() < 0.5 else 1.0) * (2.5 + r.randf() * 1.5)
				dd = u10(dd) / 10.0 if c_.dec else float(MiniPix.jr(dd))
				if dd < PMIN + 1 or dd > PMAX - 1 or per.any(func(p: float) -> bool: return absf(p - dd) < 2.5):
					continue
				decoy = dd
				break
			if decoy < 0.0:
				continue
		var chirp := (-1.0 if r.randf() < 0.5 else 1.0) * (0.45 + r.randf() * 0.3) if c_.chirp else 0.0
		var clean: Array[PackedFloat64Array] = []
		for k in per.size():
			clean.append(pulses(nn, per[k], r.randf() * per[k], chirp if k == 0 else 0.0, 1.0 if k == 0 else 0.85))
		if decoy >= 0.0:
			clean.append(pulses(nn, decoy, r.randf() * decoy, 0.0, 0.7))
		var s := PackedFloat64Array()
		s.resize(nn)
		for i in nn:
			var v := noise * gauss(r)
			for cl in clean:
				v += cl[i]
			s[i] = v
		var start := 0.0
		while true:
			start = rint(r, u10(PMIN), u10(PMAX)) / 10.0 if c_.dec else float(rint(r, int(PMIN), int(PMAX)))
			if not per.any(func(p: float) -> bool: return absf(p - start) < 6.0) and not (decoy >= 0.0 and absf(decoy - start) < 3.0):
				break
		var sm := {}
		var vals: Array[float] = []
		for u in range(u10(PMIN - DRIFT_MAX), u10(PMAX + DRIFT_MAX) + 1):
			var v := sharp(profile(s, u / 10.0))
			sm[u] = v
			vals.append(v)
		vals.sort()
		var base := vals[vals.size() / 2]
		var peaks: Array[Vector2] = []
		for p in per:
			var bu := u10(p)
			var bv := -1e9
			for u: int in sm:
				if absi(u - u10(p)) <= u10(1.5) and float(sm[u]) > bv:
					bv = sm[u]
					bu = u
			peaks.append(Vector2(bu, bv))
		var dpk := 0.0
		if decoy >= 0.0:
			for u: int in sm:
				if absi(u - u10(decoy)) <= u10(0.6):
					dpk = maxf(dpk, sm[u])
			var weakest := 1e9
			for q in peaks:
				weakest = minf(weakest, q.y)
			if dpk - base > 0.8 * (weakest - base):
				continue
		var rate := (-1.0 if r.randf() < 0.5 else 1.0) * float(c_.drift) * (0.7 + 0.6 * r.randf())
		out.assign({cfg = c_, P = per, sig = s, start = start, chirp = chirp, noise = noise, S = sm, base = base,
			peaks = peaks, step = 0.1 if c_.dec else 1.0, decoy = decoy, dpk = dpk, rate = rate})
		return out
	return out


## How close a lock is: within 0.6 of a dial step keeps it all, within 1.6 steps half, else a miss.
static func period_acc(c_: Dictionary, err: float, chirp: bool) -> float:
	var k := err / (0.1 if c_.dec else 1.0)
	if chirp:
		k = maxf(0.0, k - 1.0)
	return 1.0 if k <= 0.6 else (0.55 if k <= 1.6 else (0.2 if k <= 3.0 else 0.05))


## The lock lamp's glow at the effective setting `pe` for the pulsars not locked yet: fully on only
## where a LOCK would hold, white only on an exact one; anything else, the decoy too, 0.8 at most.
static func glow(g: Dictionary, pe: float, skip: Array) -> float:
	var sm: Dictionary = g.S
	if not sm.has(u10(pe)):
		return 0.0
	var v: float = sm[u10(pe)]
	var best := 0.0
	var per: Array = g.P
	var peaks: Array = g.peaks
	for k in per.size():
		if skip.has(k):
			continue
		var err := absf(pe - float(per[k]))
		if err > 3.0:
			continue
		var s := clampf((v - float(g.base)) / maxf(1e-6, (peaks[k] as Vector2).y - float(g.base)), 0.0, 1.0)
		var pa := period_acc(g.cfg, err, float(g.chirp) != 0.0 and k == 0)
		s = 1.0 if pa >= 1.0 else (maxf(0.9, minf(0.95, s)) if pa >= ACCEPT else minf(0.8, s))
		best = maxf(best, s)
	if float(g.decoy) >= 0.0 and absf(pe - float(g.decoy)) <= 3.0:
		var top := -1e9
		for q: Vector2 in peaks:
			top = maxf(top, q.y)
		best = maxf(best, minf(0.8, clampf((v - float(g.base)) / maxf(1e-6, top - float(g.base)), 0.0, 1.0)))
	return best


static func fade_secs(d: int, sn: int) -> float:
	return float(FADE.get(d, 28.0)) * (1.0 + 0.1 * sn)


static func keep(s: float) -> float:
	return clampf(s / 0.8, 0.0, 1.0)


static func final_score(lk: Array, nt: int, s: float) -> float:
	var sum := 0.0
	for l: Dictionary in lk:
		sum += float(l.pa)
	return (sum / nt) * keep(s)


static func lost_score(lk: Array, nt: int) -> float:
	var sum := 0.0
	for l: Dictionary in lk:
		sum += float(l.pa)
	return 0.05 + 0.15 * sum / nt


# ---------------------------------------------------------------- the game

func _mount() -> void:
	px = MiniPix.new(W, H)
	g0 = gen(rng, depth, sensors)
	if g0.is_empty():
		push_error("GamePulsar: no deal at depth %d" % depth)
		ended = true
		done(0.0, "No deal")
		return
	c = g0.cfg
	pf_ = g0.start
	fade_s = fade_secs(depth, sensors)
	n_t = (g0.P as Array).size()
	gseed = _i32(seed ^ 0x5bd1e995)
	gl.jit.resize(WFH)
	RAMP.assign([GLASS, MiniPix.shade(MiniPix.GOOD, -0.72), MiniPix.shade(MiniPix.GOOD, -0.45), MiniPix.GOOD, MiniPix.MARK, WHITE_G])
	RAMPON.assign([GLASS, MiniPix.shade(MiniPix.GOOD, -0.55), MiniPix.GOOD, MiniPix.MARK, WHITE_G, Color.WHITE])
	if sensors >= 3:
		var half := 2.5 if sensors >= 5 else 4.0
		var tgt: float = g0.P[0]
		var lo := maxf(PMIN, tgt - half + (rng.randf() - 0.5) * half)
		band = Vector2(lo, minf(PMAX, lo + 2.0 * half))
	_plate = _draw_plate()
	_draw()


static func _i32(v: int) -> int:
	v &= 0xFFFFFFFF
	return v - 0x100000000 if v >= 0x80000000 else v


## The glitch's own generator: `Math.imul(gseed, 1103515245) + 12345 | 0`.
func _grnd() -> float:
	gseed = _i32(_i32(gseed * 1103515245) + 12345)
	return float(((gseed & 0xFFFFFFFF) >> 8) & 0xffff) / 65536.0


func _drift() -> float:
	return drift_of(g0, play)


func _pe() -> float:
	return pf_ - _drift()


func _fmt(v: float) -> String:
	return "%.1f" % v if c.dec else str(MiniPix.jr(v))


func _sx_of(v: float) -> int:
	return SX + MiniPix.jr((v - PMIN) / (PMAX - PMIN) * (SW - 1))


func _ramp(v: float, x: int, y: int, r: Array[Color]) -> Color:
	var f := maxf(0.0, minf(r.size() - 1.001, v * (r.size() - 1)))
	var i := int(floorf(f))
	return r[i + 1] if MiniPix.bay(x, y) < f - i else r[i]


func _draw_plate() -> Image:
	var b := MiniPix.new(W, H)
	b.rect(0, 0, W, H, MiniPix.PANEL)
	b.rect(1, 11, W - 2, 1, MiniPix.BEVEL_HI)
	b.rect(1, 11, 1, 92, MiniPix.BEVEL_HI)
	b.rect(1, 103, W - 2, 1, MiniPix.BEVEL_LO)
	b.rect(W - 2, 11, 1, 93, MiniPix.BEVEL_LO)
	b.rect(3, 13, W - 6, 89, GLASS)
	b.rect(0, DECK, W, H - DECK, MiniKit.BORDER)
	b.rect(0, DECK, W, 1, MiniPix.LINE)
	for x in range(GX, GX + GW + 1, 15):
		for y in range(WFY, WFY + WFH, 2):
			b.dot(x, y, GRAT)
	for y in range(WFY, WFY + WFH + 1, 10):
		for x in range(GX, GX + GW, 2):
			b.dot(x, y, GRAT)
	for x in range(4, W - 4, 2):
		b.dot(x, RAWY + RAWH - 4, GRAT)
		b.dot(x, PRY + PRH - 1, GRAT)
	for y in range(-DR - 2, DR + 3):
		for x in range(-DR - 2, DR + 3):
			var r := Vector2(x, y).length()
			if r > DR + 1.5:
				continue
			b.dot(DX + x, DY + y, MiniPix.BEVEL_LO if r > DR + 0.5 else MiniPix.VOID)
	b.rect(SX - 1, SY - 1, SW + 2, 8, MiniPix.BEVEL_LO)
	b.rect(SX, SY, SW, 6, MiniPix.VOID)
	for v in range(int(PMIN), int(PMAX) + 1, 2):
		var x := _sx_of(v)
		b.rect(x, SY + (0 if v % 10 == 0 else 3), 1, 6 if v % 10 == 0 else 3, MiniPix.COLD if v % 10 == 0 else MiniPix.LINE)
	b.text("%d-%d" % [int(PMIN), int(PMAX)], LB.position.x - 5, LB.position.y + 4, MiniPix.LINE, "right")
	return b.img


func _glitch_i() -> float:
	return minf(1.0, maxf(0.0, (0.5 - sig) / 0.5) * 0.85 + burst)


func _roll_glitch() -> void:
	var gi := _glitch_i()
	gl.I = gi
	gl.tear = []
	gl.noise = []
	gl.drop = []
	(gl.jit as PackedInt32Array).fill(0)
	if gi <= 0.0:
		return
	var y := RAWY
	while y < PRY + PRH:
		var h := 2 + int(floorf(_grnd() * (3 + 5 * gi)))
		if _grnd() < 0.45 * gi:
			(gl.tear as Array).append([y, h, (-1 if _grnd() < 0.5 else 1) * (1 + int(floorf(_grnd() * (1 + 4 * gi))))])
		y += 2 + int(floorf(_grnd() * 6))
	if _grnd() < 0.6 * gi:
		(gl.noise as Array).append([RAWY + int(floorf(_grnd() * (PRY + PRH - RAWY - 3))), 2 + int(floorf(_grnd() * 2))])
	if _grnd() < 0.35 * gi:
		(gl.drop as Array).append([WFY + int(floorf(_grnd() * WFH)), 1 + int(floorf(_grnd() * 2))])
	for yy in WFH:
		if _grnd() < 0.5 * gi:
			gl.jit[yy] = MiniPix.jr((_grnd() - 0.5) * 2.0 * (1.0 + 2.0 * gi))


## Tear rows sideways, lay static bands, drop lines: inside the glass only, never over the dial.
func _apply_glitch() -> void:
	if float(gl.I) <= 0.0:
		return
	var snap := px.img.duplicate() as Image
	var clip := Rect2i(3, RAWY, W - 6, PRY + PRH - RAWY)
	for e: Array in gl.tear:
		var y: int = e[0]
		var h: int = e[1]
		var dx: int = e[2]
		var band_r := Rect2i(3, y, W - 6, h).intersection(clip)
		px.img.fill_rect(band_r, GLASS)
		var dst := Rect2i(3 + dx, y, W - 6, h).intersection(clip)
		if dst.size.x > 0 and dst.size.y > 0:
			px.img.blit_rect(snap, Rect2i(dst.position.x - dx, dst.position.y, dst.size.x, dst.size.y), dst.position)
	for e: Array in gl.noise:
		for yy in range(int(e[0]), int(e[0]) + int(e[1])):
			for x in range(3, W - 3):
				var r := _grnd()
				if r < 0.35 and clip.has_point(Vector2i(x, yy)):
					px.dot(x, yy, MiniPix.shade(MiniPix.GOOD, -0.2) if r < 0.08 else (MiniPix.shade(MiniPix.GOOD, -0.5) if r < 0.2 else GRAT))
	for e: Array in gl.drop:
		px.img.fill_rect(Rect2i(3, int(e[0]), W - 6, int(e[1])).intersection(clip), GLASS)


func _draw_screen() -> void:
	var pe := _pe()
	_cur = fold(g0.sig, pe)
	var skip: Array = locks.map(func(l: Dictionary) -> int: return int(l.k))
	lit = 1.0 if ended and not locks.is_empty() else glow(g0, pe, skip)
	var on := lit >= 0.9
	var rp: Array[Color] = RAMPON if on else RAMP
	var s: PackedFloat64Array = g0.sig
	var nn := mini(s.size(), 284)
	var py := -999
	for i in range(0, nn, 2):
		var x := 4 + (i >> 1)
		var v := maxf(s[i], s[i + 1] if i + 1 < s.size() else 0.0)
		var yy := maxi(RAWY, mini(RAWY + RAWH - 1, MiniPix.jr(RAWY + RAWH - 4 - v * 6.0)))
		if py != -999:
			px.line(x - 1, py, x, yy, MiniPix.shade(MiniPix.GOOD, -0.2))
		py = yy
	var rows: Array = _cur.rows
	var rn := rows.size()
	for y in WFH:
		var r0 := y * rn / WFH
		var r1 := maxi(r0 + 1, (y + 1) * rn / WFH)
		for bn in B:
			var sm := 0.0
			for r in range(r0, r1):
				var row: PackedFloat64Array = rows[r]
				sm += 0.25 * row[(bn + B - 1) % B] + 0.5 * row[bn] + 0.25 * row[(bn + 1) % B]
			sm /= (r1 - r0)
			var v := clampf((sm - 0.12) / 0.75, 0.0, 1.0)
			if v < 0.04:
				continue
			for k in 3:
				var xx: int = GX + bn * 3 + k + gl.jit[y]
				px.dot(xx, WFY + y, _ramp(v * 0.95, xx, WFY + y, rp))
	var prof: PackedFloat64Array = _cur.prof
	var pk := 0
	for bn in range(1, B):
		if prof[bn] > prof[pk]:
			pk = bn
	for bn in B:
		var v := clampf((prof[bn] + 0.05) / 0.75, 0.0, 1.0)
		var h := MiniPix.jr(v * (PRH - 2))
		for k in 3:
			var xx := GX + bn * 3 + k
			for j in h:
				var yy := PRY + PRH - 2 - j
				var col: Color
				if j == h - 1:
					col = WHITE_G if on else MiniPix.MARK
				elif on:
					col = MiniPix.GOOD if MiniPix.bay(xx, yy) < 0.6 else MiniPix.shade(MiniPix.GOOD, -0.45)
				else:
					col = MiniPix.shade(MiniPix.GOOD, -0.35) if MiniPix.bay(xx, yy) < 0.35 else MiniPix.shade(MiniPix.GOOD, -0.68)
				px.dot(xx, yy, col)
	if on:
		for y in range(WFY - 2, PRY + PRH, 2):
			px.dot(GX + pk * 3 + 1, y, MiniPix.EMBER)


func _draw() -> void:
	px.img.blit_rect(_plate, Rect2i(0, 0, W, H), Vector2i.ZERO)
	_draw_screen()
	var on := lit >= 0.9
	_draw_signal(on)
	var lx := W - 8
	var ly := 4
	var a := lit * lit
	for y in range(-4, 5):
		for x in range(-4, 5):
			var r := Vector2(x, y).length()
			if r <= 2.2:
				var col: Color
				if on:
					col = Color.WHITE if r < 1.2 and lit >= 0.99 else MiniPix.MARK
				else:
					col = MiniPix.GOOD if a > 0.5 else (MiniPix.shade(MiniPix.GOOD, -0.4) if a > 0.2 else MiniPix.shade(MiniPix.GOOD, -0.7))
				px.dot(lx + x, ly + y, col)
			elif r <= 4.2 and on and MiniPix.bay(lx + x, ly + y) < (4.2 - r) / 2.6:
				px.dot(lx + x, ly + y, MiniPix.GOOD)
	_apply_glitch()
	if msg != "":
		px.text(msg, W / 2, RAWY + RAWH - 2, MiniPix.HOT, "center")
	elif not started:
		MiniKit.tell(px, "TUNE IN THE PULSAR.", ["dial"] as Array[String], clock)
	_draw_dial(on)
	draw_toast()


## The kit's header: SIG as a draining meter (+ which pulsar of two), LOCK lit when a lock would hold.
func _draw_signal(on: bool) -> void:
	var low := sig < 0.25
	var two := "%d/%d" % [mini(locks.size() + 1, n_t), n_t] if n_t > 1 else ""
	MiniKit.header(px, {label = "SIG", kind = "bad" if low else "", value = two,
		meter = {w = 77 if n_t > 1 else 89, frac = sig, kind = "bad" if low else "neutral"}},
		[["LOCK", null, null, "good" if on else ""]], 10)


## The knurled dial turning with the period, the readout, the strip's needle and locks, LOCK.
func _draw_dial(on: bool) -> void:
	var rot := (pf_ - PMIN) * 36.0 * PI / 180.0
	for y in range(-DR, DR + 1):
		for x in range(-DR, DR + 1):
			var r := Vector2(x, y).length()
			if r > DR - 0.5:
				continue
			var lt := float(-x - y) / DR
			var col := MiniPix.CHILL if lt > 0.5 else (MiniPix.COLD if lt > 0.0 else (MiniPix.LINE if lt > -0.5 else MiniPix.BEVEL_LO))
			if r > DR - 3:
				var ang := atan2(y, x) - rot
				if int(floorf((ang / (2.0 * PI)) * 24.0 + 48.0)) & 1:
					col = MiniPix.BEVEL_LO
			elif r > DR - 4:
				col = MiniPix.BEVEL_LO
			px.dot(DX + x, DY + y, col)
	for y in range(-6, 7):
		for x in range(-6, 7):
			var r := Vector2(x, y).length()
			if r <= 6:
				px.dot(DX + x, DY + y, MiniPix.BEVEL_LO if r > 5 else (MiniPix.COLD if (-x - y) > 3 else MiniPix.LINE))
	px.rect(MiniPix.jr(DX + sin(rot) * 9.0) - 1, MiniPix.jr(DY - cos(rot) * 9.0) - 1, 2, 2, MiniPix.EMBER)
	MiniKit.pair(px, SX, LB.position.y + 4, "PERIOD", _fmt(pf_), "", "good" if on else "")
	if band.x >= 0.0:
		var shf := MiniPix.shade(MiniPix.GOOD, -0.3)
		for x in range(_sx_of(band.x + _drift()), _sx_of(band.y + _drift()) + 1):
			for y in range(SY, SY + 6):
				if x >= SX and x < SX + SW and MiniPix.bay(x, y) < 0.4:
					px.dot(x, y, shf)
	for l: Dictionary in locks:
		px.rect(_sx_of(float(l.pf)), SY, 1, 6, MiniPix.GOOD)
	var nx := _sx_of(pf_)
	px.rect(nx, SY - 2, 1, 10, MiniPix.EMBER)
	px.dot(nx - 1, SY - 2, MiniPix.EMBER)
	px.dot(nx + 1, SY - 2, MiniPix.EMBER)
	var hot := on and not ended
	var st := "disabled" if ended else (("active-pressed" if lock_down else "active") if hot else ("pressed" if lock_down else "normal"))
	MiniKit.button(px, LB.position.x, LB.position.y, LB.size.x, LB.size.y, "LOCK", st)
	dirty = true


func _tick(dt: float) -> void:
	_acc += dt
	if _acc < 0.032:
		return
	var step := minf(0.1, _acc)
	_acc = 0.0
	clock += step
	if started and not ended:
		play += step
		sig = maxf(0.0, sig - step / fade_s)
		if sig <= 0.0:
			_lose()
	burst = maxf(0.0, burst - step * 1.4)
	if clock - float(gl.t) >= 0.12 or (float(gl.I) > 0.0 and _glitch_i() <= 0.0):
		gl.t = clock
		_roll_glitch()
	if drawing:
		_draw()


# ---------------------------------------------------------------- input

func set_p(v: float) -> bool:
	var st: float = g0.step
	var nv := MiniPix.jr(v / st) * st
	nv = maxf(PMIN, minf(PMAX, nv))
	nv = u10(nv) / 10.0
	if nv != pf_:
		pf_ = nv
		msg = ""
		sfx(&"tick")
		return true
	return false


static func _d_ang(q: Vector2) -> float:
	return rad_to_deg(atan2(q.x - DX, -(q.y - DY)))


static func _in_lock(q: Vector2) -> bool:
	return q.x >= LB.position.x - 2 and q.x <= LB.end.x + 2 and q.y >= LB.position.y - 2 and q.y <= LB.end.y + 2


func down(_p: Vector2i) -> void:
	if ended:
		return
	var q := pf
	if q.y < DECK:
		return
	started = true
	if q.x < SX - 2:
		dial = {last = _d_ang(q), acc = pf_}
	elif _in_lock(q):
		lock_down = true
	elif q.y >= SY - 4 and q.y <= SY + 10 and q.x >= SX - 3 and q.x <= SX + SW + 3:
		strip_drag = true
		set_p(PMIN + (q.x - SX) / (SW - 1) * (PMAX - PMIN))


func move(_p: Vector2i) -> void:
	var q := pf
	if not dial.is_empty():
		var d := _d_ang(q) - float(dial.last)
		if d > 180.0:
			d -= 360.0
		if d < -180.0:
			d += 360.0
		dial.last = _d_ang(q)
		dial.acc = maxf(PMIN, minf(PMAX, float(dial.acc) + d / 36.0))
		set_p(dial.acc)
	elif strip_drag:
		set_p(PMIN + (q.x - SX) / (SW - 1) * (PMAX - PMIN))


func up(_p: Vector2i, cancel := false) -> void:
	dial = {}
	strip_drag = false
	if lock_down:
		lock_down = false
		if not cancel and _in_lock(pf):
			lock()


func wheel(dir: int) -> void:
	if ended or pf.y < DECK:
		return
	set_p(pf_ + dir * float(g0.step))


func lock() -> void:
	if ended:
		return
	var per: Array = g0.P
	var free: Array[int] = []
	for k in per.size():
		if not locks.any(func(l: Dictionary) -> bool: return int(l.k) == k):
			free.append(k)
	var pe := _pe()
	var k := free[0]
	for q in free:
		if absf(float(per[q]) - pe) < absf(float(per[k]) - pe):
			k = q
	var pa := period_acc(c, absf(float(per[k]) - pe), float(g0.chirp) != 0.0 and k == 0)
	if pa < ACCEPT:
		started = true
		sig = maxf(0.0, sig - MISS)
		burst = 0.9
		gl.t = -1.0
		stamp_txt = "NO LOCK"
		stamp_t = clock + 1.0
		say("NO LOCK", "bad")
		misses += 1
		if sig <= 0.0:
			_lose()
		return
	locks.append({k = k, pf = pf_, pa = pa, tru = float(per[k]) + _drift()})
	sfx(&"lock")
	stamp_txt = "LOCKED" if pa >= 0.7 else "WEAK"
	stamp_t = clock + 1.2
	say(stamp_txt, "good" if pa >= 0.7 else "neutral")
	if locks.size() < n_t:
		msg = ""
		return
	ended = true
	msg = ""
	sfx(&"win")
	# the END word now (the card's; the toast goes), the take 0.9 s later
	say_end(stamp_txt, "good" if stamp_txt == "LOCKED" else "neutral")
	var sc := final_score(locks, n_t, sig)
	stamp_t = clock + 99.0
	var detail := ", ".join(locks.map(func(l: Dictionary) -> String: return "P %s (true %s)" % [_fmt(l.pf), _fmt(l.tru)])) \
		+ ", %d%% signal left" % MiniPix.jr(sig * 100.0)
	after(0.9, func() -> void: done(sc, detail))


func _lose() -> void:
	if ended:
		return
	ended = true
	lost = true
	sig = 0.0
	stamp_txt = "LOST"
	stamp_t = clock + 99.0
	say_end("LOST", "bad")
	var sc := lost_score(locks, n_t)
	var nl := locks.size()
	after(0.9, func() -> void: done(sc, "Signal lost, %d/%d locked" % [nl, n_t]))


func give_up() -> void:
	if ended:
		return
	ended = true
	_later.clear()
	done(lost_score(locks, n_t) if not locks.is_empty() else 0.0, "Gave up")
