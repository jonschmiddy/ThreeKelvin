class_name GameTuning
extends MiniGame

## SIGNAL TUNING: turn the dials until your curve matches the beacon's, then LOCK. A port of the
## approved `tuning2.js` (round 3: nothing of the target is drawn in YOURS; the stretches of your
## curve already on the target's shape turn green), in its approved layout and the UI kit (Nov 20).
## Why: docs/why/MiniGame.md#signal-tuning

const CFG := {
	1: {fmax = 4, phase = false, amp = false, noise = 0.0},
	2: {fmax = 5, phase = false, amp = false, noise = 0.0},
	3: {fmax = 5, phase = true, amp = false, noise = 0.0},
	4: {fmax = 6, phase = true, amp = false, noise = 0.022},
	5: {fmax = 6, phase = true, amp = true, noise = 0.032},
}
const AMPS: Array[float] = [0.4, 0.55, 0.7, 0.85, 1.0]
const BASE_PH := 1
const BASE_AMP := 4
const M := 1200
const MATCH := 0.012
## The game area, as every game draws it (the UI kit, Nov 20).
const W := MiniKit.W
const H := MiniKit.H
## The scope frames, SS square at SY (two fill the width, so A drops them to the middle of rows 10-115);
## HS is the glass centre's offset in a frame.
const SCX: Array[int] = [0, 76]
const SCL: Array[String] = ["TARGET", "YOURS"]
const SY := 29
const SS := 74
const R := 32
const HS := SS >> 1
## The knobs' centre row (the control row's) and radius: ticks fill rows 117-139, even the lit 180 deg
## tick. LOCK's right edge is on the gutter.
const KY := MiniKit.CTRL_CY
const KR := 7
const LOCK := Rect2i(MiniKit.W - MiniKit.GUT - 25, MiniKit.BTN_YS, 25, MiniKit.BTN_H)
const NEAR := 1.1 / R
## The page's clock at the mount, in ms (the prototype diff holds it there): the slow wander of
## your curve reads the clock itself, so any start draws the same game.
const T0 := 1000.0
## The nearest-point grid: GN x GN cells over [-1, 1], each wider than NEAR.
const GN := 40
const GH := 2.0 / GN
const RAMP_T: Array[Color] = [Color("#1b2d47"), Color("#2f4f78"), Color("#6a9ad4"), Color("#c3d2e2")]
const RAMP_Y: Array[Color] = [Color("#3a2310"), Color("#7a4518"), Color("#d97b29"), Color("#ffd28a")]
const RAMP_G: Array[Color] = [Color("#1f3328"), Color("#3f6a52"), Color("#7fb89a"), Color("#b8f5d8")]
const GLASS := Color("#05080d")
const RIM := Color("#151d28")
const GRAT := Color("#0f1824")
const GRAT0 := Color("#16212f")
const GLARE := Color("#101a26")
const STEEL := Color("#4a5a70")
const NOTCH_HI := Color("#56677d")
const NOTCH_LO := Color("#2b3849")
const COLLAR := Color("#3f6a52")


## A point set sorted into the grid's cells, so a nearest-point search asks a few cells, not all
## 1200 points. The min it finds is the same number the prototype's full scan finds.
class Grid:
	var start := PackedInt32Array()
	var xs := PackedFloat64Array()
	var ys := PackedFloat64Array()
	var idx := PackedInt32Array()


var g0: Dictionary[String, Variant] = {}
var c: Dictionary = {}
var cur: Dictionary = {}
var knobs: Array[Dictionary] = []
var par_now := 0
var taps := 0
var over := false
var d := 0.0
var free := 0
var meter_v := 0.0
var acted := false
var lock_down := false
var T := PackedFloat64Array()
var cur_p := PackedFloat64Array()
var near := PackedByteArray()
var jit := PackedFloat64Array()
var _gt: Grid
var _drag_on := false
var _drag_k := -1
var _drag_lock := false
var _last := 0.0
var _plate: Image


func id() -> StringName:
	return &"tuning"


func hint() -> String:
	return "Match the wave."


func controls() -> Array[String]:
	return ["dial", "click"]


# ---------------------------------------------------------------- the rules

static func rint(r: RandomNumberGenerator, lo: int, hi: int) -> int:
	return lo + int(floorf(r.randf() * (hi - lo + 1)))


static func gcd(a: int, b: int) -> int:
	return gcd(b, a % b) if b else a


## The curve of setting `s` ({a, b, ph 0..7 in steps of pi/4, amp an index}) as x, y pairs.
static func points(s: Dictionary, from := 0.0, to := TAU, m := M) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	out.resize(m * 2)
	var amp: float = AMPS[int(s.amp)]
	var a := float(s.a)
	var b := float(s.b)
	var ph := float(s.ph) * PI / 4.0
	for i in m:
		var t_ := from + (to - from) * i / m
		out[i * 2] = amp * sin(a * t_ + ph)
		out[i * 2 + 1] = sin(b * t_)
	return out


## Every fourth point of the full curve, the ones `one_way` measures from.
static func samples(s: Dictionary) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	out.resize(M / 2)
	var amp: float = AMPS[int(s.amp)]
	var a := float(s.a)
	var b := float(s.b)
	var ph := float(s.ph) * PI / 4.0
	for k in M / 4:
		var t_ := 0.0 + TAU * (k * 4) / M
		out[k * 2] = amp * sin(a * t_ + ph)
		out[k * 2 + 1] = sin(b * t_)
	return out


static func cell(v: float) -> int:
	return clampi(int(floorf((v + 1.0) / GH)), 0, GN - 1)


static func grid(P: PackedFloat64Array) -> Grid:
	var gr := Grid.new()
	var n := P.size() / 2
	var cnt := PackedInt32Array()
	cnt.resize(GN * GN + 1)
	var at := PackedInt32Array()
	at.resize(n)
	for i in n:
		var cc := cell(P[i * 2 + 1]) * GN + cell(P[i * 2])
		at[i] = cc
		cnt[cc + 1] += 1
	for cc in GN * GN:
		cnt[cc + 1] += cnt[cc]
	gr.start = cnt.duplicate()
	gr.xs.resize(n)
	gr.ys.resize(n)
	gr.idx.resize(n)
	for i in n:
		var k := cnt[at[i]]
		cnt[at[i]] += 1
		gr.xs[k] = P[i * 2]
		gr.ys[k] = P[i * 2 + 1]
		gr.idx[k] = i
	return gr


static func _scan(gr: Grid, cc: int, x: float, y: float, best: float) -> float:
	for k in range(gr.start[cc], gr.start[cc + 1]):
		var dx := x - gr.xs[k]
		var dy := y - gr.ys[k]
		var dd := dx * dx + dy * dy
		if dd < best:
			best = dd
	return best


## The squared distance from (x, y) to the nearest point in `gr`: rings of cells outward until no
## cell left can hold a nearer one.
static func near2(gr: Grid, x: float, y: float) -> float:
	var cx := cell(x)
	var cy := cell(y)
	var best := 1e9
	var r := 0
	while true:
		for yy in range(maxi(0, cy - r), mini(GN - 1, cy + r) + 1):
			if yy == cy - r or yy == cy + r:
				for xx in range(maxi(0, cx - r), mini(GN - 1, cx + r) + 1):
					best = _scan(gr, yy * GN + xx, x, y, best)
			else:
				if cx - r >= 0:
					best = _scan(gr, yy * GN + cx - r, x, y, best)
				if cx + r < GN:
					best = _scan(gr, yy * GN + cx + r, x, y, best)
		var bound := maxf(0.0, r * GH - 1e-9)
		if best <= bound * bound or r >= GN:
			return best
		r += 1
	return best


## The prototype's `oneWay`: the mean distance from every `step`th point of P to Q. With a `cap`,
## it stops once the mean can only end at or over it (a test against the cap reads the same).
static func one_way(P: PackedFloat64Array, gq: Grid, cap := 0.0, step := 4) -> float:
	var n := P.size() / 2
	var cnt := ceili(n / float(step))
	var sum := 0.0
	for i in range(0, n, step):
		sum += sqrt(near2(gq, P[i * 2], P[i * 2 + 1]))
		if cap > 0.0 and sum / cnt >= cap:
			return sum / cnt
	return sum / cnt


## Whether the prototype's `dist(P, Q)` is under `cap`.
static func closer(P: PackedFloat64Array, Q: PackedFloat64Array, gq: Grid, cap: float) -> bool:
	if one_way(P, gq, cap) >= cap:
		return false
	return one_way(Q, grid(P), cap) < cap


static func degenerate(s: Dictionary) -> bool:
	var full := points(s, 0.0, TAU, 600)
	var half := points(s, 0.0, PI, 600)
	return one_way(full, grid(half), 0.02) < 0.02


static func _matches(s: Dictionary, T_: PackedFloat64Array, gt: Grid) -> bool:
	if one_way(samples(s), gt, MATCH, 1) >= MATCH:
		return false
	return one_way(T_, grid(points(s)), MATCH) < MATCH


static func par(c_: Dictionary, f: Dictionary, t_: Dictionary) -> int:
	var v := absi(int(f.a) - int(t_.a)) + absi(int(f.b) - int(t_.b))
	if c_.phase:
		var dd := absi(int(f.ph) - int(t_.ph))
		v += mini(dd, 8 - dd)
	if c_.amp:
		v += absi(int(f.amp) - int(t_.amp))
	return v


static func best_par(c_: Dictionary, f: Dictionary, eq: Array) -> int:
	var best := 1 << 30
	for e: Dictionary in eq:
		best = mini(best, par(c_, f, e))
	return best


static func _setting(r: RandomNumberGenerator, c_: Dictionary, a: int, b: int, amp_lo: int, amp_hi: int) -> Dictionary[String, Variant]:
	var ph := rint(r, 0, 7) if c_.phase else BASE_PH
	var amp := rint(r, amp_lo, amp_hi) if c_.amp else BASE_AMP
	var out: Dictionary[String, Variant] = {}
	out.assign({a = a, b = b, ph = ph, amp = amp})
	return out


## {cfg, target, start, par, T (the target's points), eq (every setting that draws the target)}.
## A start under par 3 of the target itself is under par 3 of the best match: skipped before eq.
static func gen(r: RandomNumberGenerator, depth_: int) -> Dictionary[String, Variant]:
	var c_: Dictionary = CFG.get(depth_, CFG[1])
	var fmax: int = c_.fmax
	var out: Dictionary[String, Variant] = {}
	for tries in 500:
		var a := rint(r, 1, fmax)
		var b := rint(r, 1, fmax)
		if gcd(a, b) != 1 or (a == 1 and b == 1):
			continue
		var target := _setting(r, c_, a, b, 0, 3)
		if degenerate(target):
			continue
		var sa := rint(r, 1, fmax)
		var sb := rint(r, 1, fmax)
		var st := _setting(r, c_, sa, sb, 1, 4)
		if par(c_, st, target) < 3:
			continue
		var T_ := points(target)
		var gt := grid(T_)
		var eq: Array[Dictionary] = []
		for ph in 8:
			for am in 5:
				if (not c_.phase and ph != int(target.ph)) or (not c_.amp and am != int(target.amp)):
					continue
				var s2 := {a = a, b = b, ph = ph, amp = am}
				if (ph == int(target.ph) and am == int(target.amp)) or _matches(s2, T_, gt):
					eq.append(s2)
		var pr := best_par(c_, st, eq)
		if pr < 3:
			continue
		if closer(points(st), T_, gt, 0.15):
			continue
		out.assign({cfg = c_, target = target, start = st, par = pr, T = T_, eq = eq})
		return out
	return out


static func score(dd: float, tp: int, pr: int, fr: int) -> float:
	if dd < MATCH:
		var extra := maxi(0, tp - pr - 2 - fr)
		return maxf(0.55, 1.0 - 0.05 * extra)
	return 0.35 * maxf(0.0, 1.0 - dd / 0.25)


## How close you are in dial steps: 0 (as far as it gets) to 1 (there).
static func closeness(c_: Dictionary, f: Dictionary, eq: Array) -> float:
	var mx := 2 * (int(c_.fmax) - 1) + (4 if c_.phase else 0) + (4 if c_.amp else 0)
	return maxf(0.0, 1.0 - float(best_par(c_, f, eq)) / mx)


## Whether a dial on `v` sits on a right value: some matching setting has it.
func right_on(key: String, v: int) -> bool:
	for e: Dictionary in g0.eq:
		if int(e[key]) == v:
			return true
	return false


func is_right(k: int) -> bool:
	var kb := knobs[k]
	return right_on(kb.key, int(cur[kb.key]))


## The matching setting fewest steps from the dials (the first, as `bestPar` counts).
func best_eq() -> Dictionary[String, Variant]:
	var best: Dictionary[String, Variant] = {}
	var bp := 1 << 30
	for e: Dictionary in g0.eq:
		var p := par(c, cur, e)
		if p < bp:
			bp = p
			best.assign(e)
	return best


# ---------------------------------------------------------------- the game

func _mount() -> void:
	px = MiniPix.new(W, H)
	g0 = gen(rng, depth)
	if g0.is_empty():
		push_error("GameTuning: no deal at depth %d" % depth)
		over = true
		done(0.0, "No deal")
		return
	c = g0.cfg
	T = g0.T
	_gt = grid(T)
	cur = (g0.start as Dictionary).duplicate()
	if sensors >= 3:
		cur.a = g0.target.a
	if sensors >= 5:
		if c.phase:
			cur.ph = g0.target.ph
		else:
			cur.b = g0.target.b
	par_now = best_par(c, cur, g0.eq)
	free = sensors / 2
	_jitter()
	_knobs()
	_refit()
	_plate = _draw_plate()
	_last = T0
	_draw(T0)


## The noisy target's fixed jitter per point (drawn from the stream at every depth, as the page does).
func _jitter() -> void:
	var wp: Array[float] = []
	var wf: Array[float] = []
	for k in 4:
		wf.append(2.0 * PI * (30 + int(floorf(rng.randf() * 50))) / M)
		wp.append(rng.randf() * 7)
	var nz: float = c.noise
	jit.resize(M * 2)
	for i in M:
		jit[i * 2] = nz * (sin(i * wf[0] + wp[0]) + sin(i * wf[1] + wp[1])) * 0.7
		jit[i * 2 + 1] = nz * (sin(i * wf[2] + wp[2]) + sin(i * wf[3] + wp[3])) * 0.7


func _knobs() -> void:
	knobs.clear()
	var fmax: int = c.fmax
	knobs.append({lab = "X", key = "a", lo = 1, hi = fmax, wrap = false})
	knobs.append({lab = "Y", key = "b", lo = 1, hi = fmax, wrap = false})
	if c.phase:
		knobs.append({lab = "PH", key = "ph", lo = 0, hi = 7, wrap = true})
	if c.amp:
		knobs.append({lab = "SIZE", key = "amp", lo = 0, hi = 4, wrap = false})
	# across the control row left of LOCK: each knob (ticks out to 11), its label at its lower right
	var n := knobs.size()
	var need := 11 + maxi(11, 9 + MiniKit.tw(knobs[n - 1].lab))
	for i in n - 1:
		need += _pitch(knobs[i])
	var room := LOCK.position.x - MiniKit.GAP - MiniKit.GUT
	var gap := mini(14, floori(float(room - need) / (n - 1))) if n > 1 else 0
	need += gap * (n - 1)
	var x := MiniKit.GUT + 11 + ((room - need) >> 1)
	for k in knobs:
		k.cx = x
		k.cy = KY
		k.n = 8 if k.wrap else int(k.hi) - int(k.lo) + 1
		k.click = -1.0
		x += _pitch(k) + gap


## A knob's share of the control row: the knob, then its label at its lower right.
static func _pitch(k: Dictionary) -> int:
	return maxi(23, 19 + MiniKit.tw(k.lab))


## The detent's angle in degrees, 0 straight up, clockwise.
static func det_a(k: Dictionary, v: int) -> float:
	if k.wrap:
		return float((v - int(k.lo)) * 45)
	return 0.0 if int(k.n) == 1 else -135.0 + 270.0 * (v - int(k.lo)) / (int(k.n) - 1)


## Where knob `k`'s tick for `v` sits (the solver taps it).
func tick_at(k: int, v: int) -> Vector2:
	var kb := knobs[k]
	var a := det_a(kb, v) * PI / 180.0
	return Vector2(MiniPix.jr(int(kb.cx) + sin(a) * (KR + 3)), MiniPix.jr(int(kb.cy) - cos(a) * (KR + 3))) + Vector2(0.5, 0.5)


func _now() -> float:
	return T0 + t * 1000.0


## The curve of the dials, how far it is from the target, and its stretches already on it.
func _refit() -> void:
	cur_p = points(cur)
	d = maxf(one_way(cur_p, _gt), one_way(T, grid(cur_p)))
	near = near_map(cur_p)


## The points of P within about a pixel of the target's (every other target point), kept only in
## runs of 12 or more: a lone near point where two curves only cross reads as noise.
func near_map(P: PackedFloat64Array) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(M)
	var n2 := NEAR * NEAR
	for i in M:
		var x := P[i * 2]
		var y := P[i * 2 + 1]
		var cx := cell(x)
		var cy := cell(y)
		var hit := false
		for yy in range(maxi(0, cy - 1), mini(GN - 1, cy + 1) + 1):
			for xx in range(maxi(0, cx - 1), mini(GN - 1, cx + 1) + 1):
				var cc := yy * GN + xx
				for k in range(_gt.start[cc], _gt.start[cc + 1]):
					if _gt.idx[k] & 1:
						continue
					var dx := x - _gt.xs[k]
					var dy := y - _gt.ys[k]
					if dx * dx + dy * dy < n2:
						hit = true
						break
				if hit:
					break
			if hit:
				break
		out[i] = 1 if hit else 0
	var i := 0
	while i < M:
		if not out[i]:
			i += 1
			continue
		var j := i
		while j < M and out[j]:
			j += 1
		if j - i < 12:
			for k in range(i, j):
				out[k] = 0
		i = j
	return out


func _tick(_dt: float) -> void:
	var now := _now()
	if drawing and now - _last >= 32.0:
		_last = now
		_draw(now)


# ---------------------------------------------------------------- drawing

func _draw_plate() -> Image:
	var b := MiniPix.new(W, H)
	b.clear(MiniKit.BORDER)
	for i in 2:
		var x := SCX[i]
		b.rect(x, SY, SS, SS, MiniPix.BEVEL_LO)
		b.rect(x + 1, SY + 1, SS - 2, SS - 2, MiniPix.LINE)
		b.rect(x + 1, SY + 1, SS - 2, 1, MiniPix.BEVEL_HI)
		b.rect(x + 1, SY + 1, 1, SS - 2, MiniPix.BEVEL_HI)
		b.rect(x + 2, SY + SS - 2, SS - 3, 1, RIM)
		b.rect(x + SS - 2, SY + 2, 1, SS - 3, RIM)
		var gx := x + 3
		var gy := SY + 3
		var gs := SS - 6
		b.rect(gx, gy, gs, gs, GLASS)
		for at: Vector2i in [Vector2i(gx, gy), Vector2i(gx + gs - 1, gy), Vector2i(gx, gy + gs - 1), Vector2i(gx + gs - 1, gy + gs - 1)]:
			b.dot(at.x, at.y, MiniPix.LINE)
		var cx := x + HS
		var cy := SY + HS
		for k in range(-2, 3):
			for t_ in range(-R, R + 1, 2):
				b.dot(cx + k * R / 2, cy + t_, GRAT if k else GRAT0)
				b.dot(cx + t_, cy + k * R / 2, GRAT if k else GRAT0)
		b.dither(gx + 2, gy + 2, 10, 2, GLASS, GLARE, 0.5)
		b.dither(gx + 2, gy + 4, 2, 8, GLASS, GLARE, 0.5)
		b.text(SCL[i], x + HS, SY - 6, MiniPix.FLARE if i else MiniPix.TIERS[2], "center")
	return b.img


func _pos(cx: int, cy: int, P: PackedFloat64Array, jt: PackedFloat64Array, wob: float, now: float, i: int) -> Vector2i:
	var jx := jt[i * 2] if jt.size() else 0.0
	var jy := jt[i * 2 + 1] if jt.size() else 0.0
	var wx := MiniPix.jr(sin(i * 0.031 + now * 0.0021) * wob) if wob else 0
	var wy := MiniPix.jr(cos(i * 0.027 + now * 0.0017) * wob) if wob else 0
	return Vector2i(MiniPix.jr(cx + (P[i * 2] + jx) * R) + wx, MiniPix.jr(cy - (P[i * 2 + 1] + jy) * R) + wy)


## One scope's curve: the whole figure dim, a fading tail to the head, the head with a glow ring.
## `nr` greens the stretches already on the target (YOURS only); `wob` is its slow wander.
func _trace(x: int, P: PackedFloat64Array, ramp: Array[Color], head: int, jt: PackedFloat64Array, wob: float, now: float, nr: PackedByteArray) -> void:
	var cx := x + HS
	var cy := SY + HS
	var has_nr := nr.size() > 0
	for i in range(0, M, 2):
		var q := _pos(cx, cy, P, jt, wob, now, i)
		px.dot(q.x, q.y, RAMP_G[1] if has_nr and nr[i] else ramp[0])
	var tail := 300
	for j in tail:
		var i := (head - tail + j + M) % M
		var q := _pos(cx, cy, P, jt, wob, now, i)
		var rr: Array[Color] = RAMP_G if has_nr and nr[i] else ramp
		px.dot(q.x, q.y, rr[1 if j < tail * 0.45 else (2 if j < tail * 0.85 else 3)])
	var h := _pos(cx, cy, P, jt, wob, now, head)
	for o: Vector2i in [Vector2i(-2, 0), Vector2i(2, 0), Vector2i(0, -2), Vector2i(0, 2), Vector2i(-1, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1)]:
		px.dot(h.x + o.x, h.y + o.y, ramp[1])
	px.rect(h.x - 1, h.y, 3, 1, ramp[3])
	px.rect(h.x, h.y - 1, 1, 3, ramp[3])


func _draw(now: float) -> void:
	px.img.blit_rect(_plate, Rect2i(0, 0, W, H), Vector2i.ZERO)
	var head := int(floorf(fmod((now - T0) / 4200.0, 1.0) * M))
	_trace(SCX[0], T, RAMP_T, head, jit if float(c.noise) else PackedFloat64Array(), 0.0, now, PackedByteArray())
	var wrong := 0
	for k in knobs.size():
		if not is_right(k):
			wrong += 1
	var green := (over or wrong == 0) and d < MATCH
	_trace(SCX[1], cur_p, RAMP_G if green else RAMP_Y, head, PackedFloat64Array(), 0.0 if over else float(wrong) / knobs.size() * 1.6, now, near)
	_hud()
	MiniKit.deck(px, true)
	for k in knobs.size():
		_knob(k, _drag_on and _drag_k == k, now)
	_lock_btn()
	# A (Nov 20): no status line; a right dial wears its green collar, MATCH! / NO MATCH the shell's card
	if not acted and not told and not over:
		MiniKit.tell(px, "MATCH THE WAVE.", controls(), (now - T0) / 1000.0)
	draw_toast()
	dirty = true


## MATCH: the header's meter (11 segments) climbs as you tune in, eased a quarter of the way each
## frame; STEP and PAR on the right.
func _hud() -> void:
	var f := closeness(c, cur, g0.eq)
	meter_v += (f - meter_v) * 0.25
	var top := f >= 0.999
	MiniKit.header(px, {label = "MATCH", kind = "good" if top else "", meter = {w = 45, frac = meter_v, kind = "good" if top else "neutral"}},
		[["STEP", taps, "bad" if taps > par_now + 2 + free else ""], ["PAR", par_now]])


## A selector switch: the detent click's fading ring, a right dial's green collar, the ticks, the
## stepped metal body, the cap, the pointer, its name and its value.
func _knob(k: int, active: bool, now: float) -> void:
	var kb := knobs[k]
	var cx: int = kb.cx
	var cy: int = kb.cy
	var ok := is_right(k) and not over
	var clk: float = kb.click
	if clk >= 0.0 and now - clk < 500.0:
		var a := 1.0 - (now - clk) / 500.0
		for y in range(-KR - 2, KR + 3):
			for x in range(-KR - 2, KR + 3):
				var r2 := x * x + y * y
				if r2 > (KR + 1) * (KR + 1) and r2 <= (KR + 2) * (KR + 2) and ((x * 7 + y * 13) & 3) < a * 4:
					px.dot(cx + x, cy + y, MiniPix.MARK)
	if ok:
		for y in range(-KR - 2, KR + 3):
			for x in range(-KR - 2, KR + 3):
				var r2 := x * x + y * y
				if r2 > (KR + 1) * (KR + 1) and r2 <= (KR + 2) * (KR + 2) and ((x + y) & 1) == 0:
					px.dot(cx + x, cy + y, COLLAR)
	var v_now := int(cur[kb.key])
	for v in range(int(kb.lo), int(kb.hi) + 1):
		var a := det_a(kb, v) * PI / 180.0
		var on := v == v_now
		px.dot(MiniPix.jr(cx + sin(a) * (KR + 3)), MiniPix.jr(cy - cos(a) * (KR + 3)), (MiniPix.MARK if ok else MiniPix.FLARE) if on else MiniPix.COLD)
		if on:
			px.dot(MiniPix.jr(cx + sin(a) * (KR + 4)), MiniPix.jr(cy - cos(a) * (KR + 4)), MiniPix.MARK if ok else MiniPix.HOT)
	_knob_body(cx, cy)
	var pa := det_a(kb, v_now) * PI / 180.0
	for t_ in range(2, KR):
		px.dot(MiniPix.jr(cx + sin(pa) * t_), MiniPix.jr(cy - cos(pa) * t_), MiniPix.HOT if active else MiniPix.EMBER)
	px.text(kb.lab, cx + 10, cy + 1, MiniPix.COLD)


## Stepped metal lit from the top left, a 1 px dark outline, grip notches on the rim, and the cap.
func _knob_body(cx: int, cy: int) -> void:
	for y in range(-KR, KR + 1):
		for x in range(-KR, KR + 1):
			var r2 := x * x + y * y
			if r2 > KR * KR + KR:
				continue
			var col: Color
			if r2 > (KR - 1) * (KR - 1) + KR - 1:
				col = MiniPix.BEVEL_LO
			else:
				var l := (-x - y) / (KR * 1.4)
				col = MiniPix.CHILL if l > 0.45 else (MiniPix.COLD if l > 0.05 else (STEEL if l > -0.4 else MiniPix.BEVEL_HI))
				if r2 > (KR - 2) * (KR - 2) and ((x + y) & 1) == 0 and r2 <= (KR - 1) * (KR - 1) + KR - 1:
					col = NOTCH_HI if l > 0.05 else NOTCH_LO
			px.dot(cx + x, cy + y, col)
	for y in range(-4, 5):
		for x in range(-4, 5):
			var r2 := x * x + y * y
			if r2 > 18:
				continue
			px.dot(cx + x, cy + y, NOTCH_LO if r2 > 12 else (MiniPix.CHILL if x + y < -2 else STEEL))


func _lock_btn() -> void:
	var state := "disabled"
	if not over:
		if d < MATCH:
			state = "active-pressed" if lock_down else "active"
		else:
			state = "pressed" if lock_down else "normal"
	MiniKit.button(px, LOCK.position.x, LOCK.position.y, LOCK.size.x, LOCK.size.y, "LOCK", state)


# ---------------------------------------------------------------- input

static func in_lock(q: Vector2i) -> bool:
	return q.x >= LOCK.position.x - 2 and q.x < LOCK.end.x + 2 and q.y >= LOCK.position.y - 2 and q.y < LOCK.end.y + 2


func _knob_at(q: Vector2i) -> int:
	var best := -1
	var bd := 1e9
	for k in knobs.size():
		var dd := sqrt(float((q.x - int(knobs[k].cx)) ** 2 + (q.y - int(knobs[k].cy)) ** 2))
		if dd <= KR + 7 and dd < bd:
			bd = dd
			best = k
	return best


## The detent nearest the finger; a right value pulls a little harder (it snaps in).
func _nearest(k: int, deg: float) -> int:
	var kb := knobs[k]
	var best: int = kb.lo
	var bd := 1e9
	if not kb.wrap:
		deg = deg - 360.0 if deg > 180.0 else deg
		deg = maxf(-135.0, minf(135.0, deg))
	for v in range(int(kb.lo), int(kb.hi) + 1):
		var dd := absf(fmod(fmod(deg - det_a(kb, v), 360.0) + 540.0, 360.0) - 180.0) if kb.wrap else absf(deg - det_a(kb, v))
		if right_on(kb.key, v):
			dd *= 0.6
		if dd < bd:
			bd = dd
			best = v
	return best


func _turn_to(k: int, q: Vector2i) -> void:
	var dx := q.x + 0.5 - int(knobs[k].cx)
	var dy := q.y + 0.5 - int(knobs[k].cy)
	if dx * dx + dy * dy < 4.0:
		return
	var deg := fmod(atan2(dx, -dy) * 180.0 / PI + 360.0, 360.0)
	_set_knob(k, _nearest(k, deg))


func _set_knob(k: int, v: int) -> void:
	acted = true
	var kb := knobs[k]
	if over or v == int(cur[kb.key]):
		return
	var dlt := absi(v - int(cur[kb.key]))
	if kb.wrap:
		dlt = mini(dlt, 8 - dlt)
	sfx(&"detent")
	cur[kb.key] = v
	taps += dlt
	_refit()
	if is_right(k):
		kb.click = _now()


func down(p: Vector2i) -> void:
	if over:
		return
	var k := _knob_at(p)
	if k >= 0:
		_drag_on = true
		_drag_k = k
		_drag_lock = false
		_turn_to(k, p)
		return
	if in_lock(p):
		lock_down = true
		_drag_on = true
		_drag_k = -1
		_drag_lock = true


func move(p: Vector2i) -> void:
	if not _drag_on:
		return
	if _drag_k >= 0:
		_turn_to(_drag_k, p)
	else:
		lock_down = in_lock(p)


func up(p: Vector2i, cancel := false) -> void:
	if not _drag_on:
		return
	var was := _drag_lock
	_drag_on = false
	_drag_k = -1
	_drag_lock = false
	lock_down = false
	if was and not cancel and in_lock(p):
		_do_lock()


func _do_lock() -> void:
	acted = true
	if over:
		return
	over = true
	say_end("MATCH!" if d < MATCH else "NO MATCH", "good" if d < MATCH else "bad")
	sfx(&"lock")
	var sc := score(d, taps, par_now, free)
	if d < MATCH:
		sfx(&"win")
	var detail := "Matched in %d taps (par %d)" % [taps, par_now] if d < MATCH else "Locked off target"
	after(0.7, func() -> void: done(sc, detail))


func give_up() -> void:
	if over:
		return
	over = true
	done(0.0, "Gave up")
