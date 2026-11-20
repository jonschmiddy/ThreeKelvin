class_name GameDock
extends MiniGame

## Tumble Dock (`wreck2.js` on its approved page, `layout.page_js("dock")`: fit3 + the kit), rule for
## rule: a wreck tumbles (and from sector 4 drifts) under the clamp; thruster taps build up through
## a lag; it docks once the lit port is in the bracket slowly enough. 152 wide, the kit drawn 1 in.
## Why: docs/why/MiniGame.md#tumble-dock

const PW := 152
const VH := 98
const PH := 130
## Spin per thruster pulse (deg/s), drift per slide pulse (px/s), how far off the clamp the port may sit.
const STEP := 12.0
const DSTEP := 2.0
const TOLX := 4.0
## Sector 5: the clamp sways this far (px), once per SWT seconds.
const SWAY := 5.0
const SWT := 10.0
const CFG := {
	1: {k = [2, 3], tol = 12, wMax = 16.0, vMax = 3.0, lag = 0.15, drift = 0, sway = 0, gasX = 2.0, secs = 70},
	2: {k = [3, 4], tol = 10, wMax = 13.0, vMax = 3.0, lag = 0.22, drift = 0, sway = 0, gasX = 1.85, secs = 75},
	3: {k = [3, 5], tol = 9, wMax = 11.0, vMax = 3.0, lag = 0.30, drift = 0, sway = 0, gasX = 1.7, secs = 80},
	4: {k = [3, 5], tol = 8, wMax = 9.0, vMax = 2.5, lag = 0.38, drift = 1, sway = 0, gasX = 1.6, secs = 90},
	5: {k = [4, 5], tol = 8, wMax = 8.0, vMax = 2.2, lag = 0.45, drift = 1, sway = 1, gasX = 1.5, secs = 100},
}
const M: Array[Color] = [Color("#080b11"), Color("#111823"), Color("#182230"), Color("#22303f"), Color("#2d3c4e"),
	Color("#3d4d61"), Color("#6b7d94"), Color("#8fa3ba"), Color("#c3d2e2")]
const BURN: Array[Color] = [Color("#080b11"), Color("#1c120c"), Color("#3a2416"), Color("#5a3a22")]
const PLANET: Array[Color] = [Color("#2a3a3a"), Color("#1a2628"), Color("#0f1719")]
const SPIN_DK := Color("#1c3a2a")
const FLARE_DK := Color("#5a2e10")
const DRIFT_DK := Color("#0b3531")
const CX := PW / 2
const CY := 52
const N4: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var P: Dictionary[String, Variant] = {}
var S: Dictionary[String, Variant] = {}
var WR: Dictionary[String, Variant] = {}
## The buttons: {id, x (canvas), w}; rows BY to BY + BH.
var B: Array[Dictionary] = []
## The stars: x, y, brightness, three to a star (doubles, as the page's).
var stars := PackedFloat64Array()
var fx: Array[Dictionary] = []
var done_fired := false
var end_t := 0.0
var status := ""
var status_kind := "neutral"
var status_t := 0.0
var press := ""
var press_t := 0.0
var arc_flash := 0.0
var pr := 0
var _acc := 0.0
var _timer := false
var _planet: Image
var _vig := PackedInt32Array()
var _kit: MiniPix
const BY := MiniKit.BTN_YL
const BH := MiniKit.BTN_HL


func id() -> StringName:
	return &"dock"


func hint() -> String:
	return "Stop it under the clamp."


func controls() -> Array[String]:
	return ["click"]


# ---------------------------------------------------------------- the rules

## JS `((a%360)+540)%360-180`: an angle into -180..180.
static func wrap180(a: float) -> float:
	return fmod(fmod(a, 360.0) + 540.0, 360.0) - 180.0


static func gen(d: int, sens: int, r: RandomNumberGenerator) -> Dictionary[String, Variant]:
	var c: Dictionary = CFG[d]
	var ks: Array = c.k
	var mag := int(ks[0]) + floori(r.randf() * (int(ks[1]) - int(ks[0]) + 1))
	var k := mag * (-1 if r.randf() < 0.5 else 1)
	var th0 := floorf(r.randf() * 360.0)
	if absf(wrap180(th0)) < 40.0:
		th0 += 90.0
	var shift_dir := -1 if r.randf() < 0.5 else 1
	var vk := 0
	var x0 := 0
	var drift := int(c.drift)
	if drift != 0:
		var vm := 1 + floori(r.randf() * 1.5)
		vk = vm * (-1 if r.randf() < 0.5 else 1)
		x0 = MiniPix.jr((r.randf() - 0.5) * 20.0)
	var par := absi(k) + 2 + (absi(vk) + 1 if drift != 0 else 0)
	var out: Dictionary[String, Variant] = {}
	out.assign({k = k, th0 = th0, vk = vk, x0 = x0, drift = drift, shift = 0, wMax = c.wMax, vMax = c.vMax, shiftDir = shift_dir,
		sway = c.sway, lag = c.lag, tol = int(c.tol) + (2 if sens >= 3 else 0), par = par,
		gas = ceili(par * float(c.gasX)) + 2 * sens, T = int(c.secs) + 8 * sens, tPar = 15 + 3 * d, depth = d})
	return out


static func new_sim(p: Dictionary) -> Dictionary[String, Variant]:
	var out: Dictionary[String, Variant] = {}
	out.assign({t = 0.0, th = float(p.th0), w = int(p.k) * STEP, wk = int(p.k), x = float(p.x0), vx = int(p.vk) * DSTEP, vk = int(p.vk),
		used = 0, docked = false, over = false, latch = {}, events = []})
	return out


## 0 = the port straight up, under the clamp.
static func err(s: Dictionary) -> float:
	return wrap180(s.th)


static func clamp_x(s: Dictionary, p: Dictionary) -> float:
	if not (s.latch as Dictionary).is_empty():
		return s.latch.kx
	return SWAY * sin(float(s.t) * 2.0 * PI / SWT) if int(p.sway) != 0 else 0.0


static func placed(s: Dictionary, p: Dictionary) -> bool:
	return absf(err(s)) <= float(p.tol) and absf(float(s.x) - clamp_x(s, p)) <= TOLX


static func slow_spin(s: Dictionary, p: Dictionary) -> bool:
	return absf(s.w) <= float(p.wMax)


static func slow_drift(s: Dictionary, p: Dictionary) -> bool:
	return absf(s.vx) <= float(p.vMax)


static func lined(s: Dictionary, p: Dictionary) -> bool:
	return placed(s, p) and slow_spin(s, p) and slow_drift(s, p)


static func close(s: Dictionary, p: Dictionary) -> bool:
	return absf(err(s)) <= float(p.tol) * 1.8 and absf(float(s.x) - clamp_x(s, p)) <= TOLX * 2.0


static func tap(s: Dictionary, p: Dictionary, what: String) -> bool:
	if s.over or int(s.used) >= int(p.gas):
		return false
	s.used = int(s.used) + 1
	match what:
		"cw":
			s.wk = int(s.wk) + 1
		"ccw":
			s.wk = int(s.wk) - 1
		"right":
			s.vk = int(s.vk) + 1
		"left":
			s.vk = int(s.vk) - 1
	(s.events as Array).append({type = "puff", what = what})
	return true


static func step(s: Dictionary, p: Dictionary, dt: float) -> void:
	if s.over:
		return
	s.t = float(s.t) + dt
	var f := 1.0 - exp(-dt / float(p.lag))
	s.w = float(s.w) + (int(s.wk) * STEP - float(s.w)) * f
	s.vx = float(s.vx) + (int(s.vk) * DSTEP - float(s.vx)) * f
	s.th = float(s.th) + float(s.w) * dt
	s.x = float(s.x) + float(s.vx) * dt
	if absf(s.x) > 50.0:
		s.x = signf(s.x) * 50.0
	if lined(s, p):
		s.docked = true
		s.over = true
		var slow := 1.0 - 0.5 * (absf(s.w) / float(p.wMax) + (absf(s.vx) / float(p.vMax) if int(p.drift) != 0 else 0.0))
		s.latch = {t = s.t, th0 = s.th, x0 = s.x, kx = clamp_x(s, p), slow = slow}
		(s.events as Array).append({type = "docked"})
	if not s.over and float(s.t) >= float(p.T):
		s.over = true
		(s.events as Array).append({type = "fail", why = "time"})
	var settled := absf(float(s.w) - int(s.wk) * STEP) < 1.0 and absf(float(s.vx) - int(s.vk) * DSTEP) < 0.3
	if not s.over and int(s.used) >= int(p.gas) and settled and _stuck(s, p):
		s.over = true
		(s.events as Array).append({type = "fail", why = "gas"})


## Out of gas and still turning or drifting too fast, or stopped off the bracket.
static func _stuck(s: Dictionary, p: Dictionary) -> bool:
	return absf(int(s.wk) * STEP) > float(p.wMax) or absf(int(s.vk) * DSTEP) > float(p.vMax) \
		or int(s.wk) == 0 and absf(err(s)) > float(p.tol) \
		or int(s.vk) == 0 and absf(s.x) > (SWAY if int(p.sway) != 0 else 0.0) + TOLX


## Docked: gas left, speed, and arriving slow all count; a clean dock is 1.0, a sloppy one about 0.5.
static func score_of(s: Dictionary, p: Dictionary) -> float:
	if not s.docked:
		return 0.0 if int(s.used) == 0 else 0.1
	var fuel := clampf(1.0 - maxf(0.0, int(s.used) - int(p.par)) / 6.0, 0.0, 1.0)
	var tm := clampf(1.0 - maxf(0.0, float(s.t) - float(p.tPar)) / (2.0 * float(p.tPar)), 0.0, 1.0)
	return clampf(0.4 + 0.3 * fuel + 0.2 * tm + 0.1 * clampf(float(s.latch.slow), 0.0, 1.0), 0.4, 1.0)


# ---------------------------------------------------------------- the deal

func _mount() -> void:
	px = MiniPix.new(PW, PH)
	_kit = MiniPix.new(MiniKit.W, MiniKit.H)
	P = gen(depth, sensors, rng)
	S = new_sim(P)
	WR = build_wreck(rng)
	pr = int(WR.hh) + 2
	for i in 60:
		var sx := floorf(rng.randf() * PW)
		var sy := floorf(rng.randf() * VH)
		stars.append(sx)
		stars.append(sy)
		stars.append(rng.randf())
	if int(P.drift) != 0:
		B.assign([{id = "ccw", x = 3, w = 33}, {id = "left", x = 40, w = 33}, {id = "right", x = 77, w = 33}, {id = "cw", x = 114, w = 33}])
	else:
		B.assign([{id = "ccw", x = 3, w = 45}, {id = "cw", x = 102, w = 45}])
	for b in B:
		b.x = int(b.x) + 1
	if drawing:
		_static_layers()
		_draw(1.0 + t)


## The wreck as a 64x64 mask of materials with outward normals, so the light stays top-left as it turns.
static func build_wreck(r: RandomNumberGenerator) -> Dictionary[String, Variant]:
	var n := 64
	var c := 32
	var mat := PackedInt32Array()
	mat.resize(n * n)
	mat.fill(-1)
	var hl := 19 + floori(r.randf() * 4)
	var hh := 7 + floori(r.randf() * 2)
	var tear: Array[int] = []
	for y in range(-hh, hh + 1):
		tear.append(floori(r.randf() * 5))
	for y in range(-hh, hh + 1):
		for x in range(-hl, hl - tear[y + hh] + 1):
			if x < -hl + 3 and absi(y) > hh - (x + hl):
				continue
			_mark(mat, c + x, c + y, 1)
	for y in range(-4, 5):
		for x in range(-hl - 5, -hl):
			_mark(mat, c + x, c + y, 2)
	var mx := -6 + floori(r.randf() * 8)
	for y in range(hh, hh + 7):
		_mark(mat, c + mx, c + y, 1)
		_mark(mat, c + mx + 1, c + y, 1)
	for x in range(mx - 3, mx + 5):
		_mark(mat, c + x, c + hh + 7, 1)
	for i in 7:
		_mark(mat, c + hl - 2 + i, c - 2 + MiniPix.jr(i * 0.4), 1)
	for y in range(-hh, hh + 1):
		for x in range(hl - 10, hl + 1):
			var i := (c + y) * n + c + x
			if mat[i] == 1 and r.randf() < 0.55 + (x - hl + 10) * 0.04:
				mat[i] = 3
	for x in range(-hl + 6, hl - 12, 3):
		if absi(x) > 4:
			_mark(mat, c + x, c - 1, 4)
	# the port on top, right over the spin centre
	for y in range(-hh - 3, -hh + 1):
		for x in range(-3, 4):
			_mark(mat, c + x, c + y, 6 if absi(x) <= 1 and y <= -hh - 1 else 5)
	var cables: Array[Dictionary] = []
	for i in 3:
		var y0 := -hh + 2 + floori(r.randf() * (2 * hh - 3))
		var ln := 4 + floori(r.randf() * 5)
		cables.append({x = hl - tear[y0 + hh] + 1, y = y0, len = ln, ph = r.randf() * 6.0})
	var out: Dictionary[String, Variant] = {}
	out.assign({N = n, C = c, mat = mat, nrm = _normals(mat, n), cables = cables, hl = hl, hh = hh})
	return out


static func _mark(mat: PackedInt32Array, x: int, y: int, m: int) -> void:
	if x >= 0 and y >= 0 and x < 64 and y < 64:
		mat[y * 64 + x] = m


## Each solid pixel's outward normal from the empty pixels round it (stored as float32, as the page's).
static func _normals(mat: PackedInt32Array, n: int) -> PackedFloat32Array:
	var nrm := PackedFloat32Array()
	nrm.resize(n * n * 2)
	for y in n:
		for x in n:
			if mat[y * n + x] < 0:
				continue
			var nx := 0
			var ny := 0
			for j in range(-2, 3):
				for i in range(-2, 3):
					var xx := x + i
					var yy := y + j
					if xx < 0 or yy < 0 or xx >= n or yy >= n or mat[yy * n + xx] < 0:
						nx += i
						ny += j
			var l := GameSling.hyp(nx, ny)
			nrm[(y * n + x) * 2] = nx / l * minf(1.0, l / 3.0) if l != 0.0 else 0.0
			nrm[(y * n + x) * 2 + 1] = ny / l * minf(1.0, l / 3.0) if l != 0.0 else 0.0
	return nrm


## The still planet limb (bottom-left) and the vignette's dithered pixels, worked out once.
func _static_layers() -> void:
	_planet = Image.create(PW, VH, false, Image.FORMAT_RGBA8)
	var pcx := -60.0
	var pcy := float(VH + 70)
	for y in range(40, VH):
		for x in 70:
			var d := GameSling.hyp(x - pcx, y - pcy)
			if d < 120.0:
				var lx := (x - pcx) / 120.0
				var ly := (y - pcy) / 120.0
				var l := -(lx + ly) * 0.7
				var b := MiniPix.bay(x, y) * 0.5
				_planet.set_pixel(x, y, M[5] if 120.0 - d < 1.5 else (PLANET[0] if l + b > 0.55 else (PLANET[1] if l + b > 0.2 else PLANET[2])))
	for y in VH:
		for x in PW:
			var dx := maxf(0.0, absf(x - PW / 2.0) - PW * 0.4) / (PW * 0.1)
			var dy := maxf(0.0, absf(y - VH / 2.0) - VH * 0.38) / (VH * 0.12)
			var v := GameSling.hyp(dx, dy)
			if v > 0.0 and MiniPix.bay(x, y) < v * 0.5:
				_vig.append(y * PW + x)


# ---------------------------------------------------------------- the clock

func _say(txt: String, kind: String, secs := 2.0) -> void:
	status = txt
	status_kind = kind
	status_t = secs


func _events() -> void:
	var evs: Array = S.events
	while not evs.is_empty():
		var ev: Dictionary = evs.pop_front()
		match String(ev.type):
			"puff":
				sfx(&"puff")
				var side: bool = ev.what == "cw" or ev.what == "left"
				fx.append({x = PW - 6 if side else 5, y = VH - 8, age = 0.0, life = 0.6, dir = -1 if side else 1})
			"docked":
				end_t = S.t
				_say("DOCKED", "good", 99.0)
				sfx(&"dock")
				sfx(&"win")
			"fail":
				end_t = S.t
				_say("WINDOW LOST" if ev.why == "time" else "OUT OF GAS", "bad", 99.0)


func _finish() -> void:
	if done_fired:
		return
	done_fired = true
	var detail := "Docked in %d s with %d pulses (par %d)" % [MiniPix.jr(S.t), int(S.used), int(P.par)] if S.docked \
		else ("Ran out of gas" if int(S.used) >= int(P.gas) else "Ran out of time")
	done(score_of(S, P), detail)


func _step(dt: float) -> void:
	if not S.over:
		step(S, P, dt)
	else:
		S.t = float(S.t) + dt
	# the latch: the clamp grabs and pulls the last bit in
	var lt: Dictionary = S.latch
	if not lt.is_empty():
		var u := minf(1.0, (float(S.t) - float(lt.t)) / 0.5)
		var e := 1.0 - pow(1.0 - u, 3.0)
		S.th = float(lt.th0) - wrap180(lt.th0) * e
		S.x = float(lt.x0) + (float(lt.kx) - float(lt.x0)) * e
	_events()
	status_t -= dt
	press_t -= dt
	arc_flash -= dt
	var keep: Array[Dictionary] = []
	for f in fx:
		f.age = float(f.age) + dt
		if float(f.age) <= float(f.life):
			keep.append(f)
	fx = keep
	if S.over and not _timer and float(S.t) - end_t > (1.0 if S.docked else 1.2):
		_timer = true
		after(0.1, _finish)


func _tick(dt: float) -> void:
	if done_fired:
		return
	var d := minf(0.05, dt)
	_step(d)
	_acc += d
	if _acc >= 1.0 / 30.0:
		_acc = 0.0
		if drawing:
			_draw(1.0 + t)


# ---------------------------------------------------------------- input

func down(p: Vector2i) -> void:
	if S.over:
		return
	for b in B:
		if p.x >= int(b.x) and p.x < int(b.x) + int(b.w) and p.y >= BY - 3 and p.y < BY + BH + 2:
			if tap(S, P, b.id):
				press = b.id
				press_t = 0.15
				arc_flash = 0.25
			else:
				_say("NO GAS", "bad", 1.5)


## A button's centre on the canvas (the pilot presses it there).
func btn_at(what: String) -> Vector2:
	for b in B:
		if b.id == what:
			return Vector2(int(b.x) + (int(b.w) >> 1), BY + (BH >> 1)) + Vector2(0.5, 0.5)
	return Vector2.ZERO


func give_up() -> void:
	if done_fired:
		return
	S.over = true
	done_fired = true
	done(0.0, "Gave up")


# ---------------------------------------------------------------- the picture

func _put(x: int, y: int, c: Color) -> void:
	px.dot(x, y, c)


func _draw(now: float) -> void:
	var tt: float = S.t
	px.rect(0, 0, PW, VH, MiniPix.VOID)
	for i in range(0, stars.size(), 3):
		var sx := stars[i]
		var sb := stars[i + 2]
		var tw := sb > 0.9 and int(floorf(now * 1.5 + sx)) % 5 == 0
		_put(int(sx), int(stars[i + 1]), MiniPix.HOT if tw else (MiniPix.ICE if sb > 0.8 else (M[6] if sb > 0.5 else M[4])))
	px.img.blend_rect(_planet, Rect2i(0, 0, PW, VH), Vector2i.ZERO)
	var ok: bool = S.docked
	var near: bool = not ok and not S.over and close(S, P)
	var ty := CY - pr
	var tc := MiniPix.GOOD if ok else ((MiniPix.FLARE if placed(S, P) else MiniPix.WARN) if near else MiniPix.HOT)
	var bl := int(floorf(now * 3.0)) % 2
	var kx := CX + MiniPix.jr(clamp_x(S, P))
	var wx := CX + MiniPix.jr(S.x)
	if not S.docked:
		for y in range(20, ty - 6, 2):
			_put(kx, y, tc if (y + int(floorf(now * 8.0))) % 4 < 2 else M[3])
		_put(kx - 1, ty - 8, tc)
		_put(kx + 1, ty - 8, tc)
		_put(kx, ty - 7, tc)
	_draw_wreck(wx, CY, S.th)
	for sgn: int in [-1, 1]:
		var x := kx + sgn * 7
		for y in range(ty - 5, ty + 5):
			_put(x, y, tc)
			_put(x + sgn, y, M[0])
		_put(x - sgn, ty - 5, tc)
		_put(x - sgn, ty + 4, tc)
		_put(x - 2 * sgn, ty - 5, tc)
		_put(x - 2 * sgn, ty + 4, tc)
		if not ok and bl == 1:
			_put(x + sgn, ty, tc)
	var rd: Array = []
	_draw_spin(wx, tt, rd)
	_draw_drift(wx, rd)
	_draw_clamp(kx, ty, tt, ok)
	if near:
		rd.append(["TOO FAST", "bad"])
	if ok and not (S.latch as Dictionary).is_empty() and float(S.t) - float(S.latch.t) < 0.25:
		for sgn: int in [-1, 1]:
			for k in 3:
				_put(kx + sgn * (12 + k), ty - 3 + k * 3, MiniPix.HOT)
	_draw_puffs()
	var img := px.img
	for i in _vig:
		img.set_pixel(i % PW, i / PW, MiniPix.BEVEL_LO)
	_hud(now, rd)
	dirty = true


## The spin arrow under the wreck (its length and running chevrons are the spin), or when stopped
## a thin arc from the port to the bracket, the short way round.
func _draw_spin(wx: int, tt: float, rd: Array) -> void:
	var n := absf(S.w) / STEP
	if (n > 0.15 or int(S.wk) != 0) and not S.docked:
		var span := minf(200.0, 20.0 + n * 28.0)
		var dir := signf(S.w) if signf(S.w) != 0.0 else float(signi(int(S.wk)))
		var fl := arc_flash > 0.0
		var sl := slow_spin(S, P)
		_arrow_arc(35, 90.0 - dir * span / 2.0, 90.0 + dir * span / 2.0, MiniPix.HOT if fl else (MiniPix.GOOD if sl else MiniPix.FLARE),
			MiniPix.EMBER if fl else (SPIN_DK if sl else FLARE_DK), n, tt)
		if float(S.t) >= 6.0 or int(S.used) > 0:
			rd.append(["SPIN %d" % absi(S.wk), "good" if sl else "neutral"])
	elif not S.docked and not S.over:
		var e := err(S)
		if absf(e) > float(P.tol):
			var a0 := -90.0 + e
			var a1 := -90.0 + (3.0 if e > 0.0 else -3.0)
			var d := minf(a0, a1)
			while d <= maxf(a0, a1):
				var a := d * PI / 180.0
				if int(d / 2.0) % 2 == 0:
					_put(MiniPix.jr(wx + cos(a) * (pr + 7)), MiniPix.jr(CY + sin(a) * (pr + 7)), MiniPix.HOT)
				d += 2.0
			var ah := a1 * PI / 180.0
			var hx := MiniPix.jr(wx + cos(ah) * (pr + 7))
			var hy := MiniPix.jr(CY + sin(ah) * (pr + 7))
			var s := -1 if e > 0.0 else 1
			for q: Vector2i in [Vector2i(s, 0), Vector2i(0, -1), Vector2i(0, 1), Vector2i(-s, -1), Vector2i(-s, 1)]:
				_put(hx + q.x, hy + q.y, MiniPix.HOT)
		if float(S.t) >= 6.0 or int(S.used) > 0:
			rd.append(["STILL", "good"])


## The drift: a cyan arrow above the wreck, as long as the drift is fast.
func _draw_drift(wx: int, rd: Array) -> void:
	var dn := absf(S.vx) / DSTEP
	if int(P.drift) == 0 or S.docked or not (dn > 0.12 or int(S.vk) != 0):
		return
	var dir := int(signf(S.vx)) if signf(S.vx) != 0.0 else signi(int(S.vk))
	var l := MiniPix.jr(4.0 + dn * 7.0)
	var y := 19
	var dc := MiniPix.GOOD if slow_drift(S, P) else MiniPix.TRACTOR
	for i in range(-l, l + 1):
		_put(wx + i, y, dc)
		_put(wx + i, y + 1, DRIFT_DK)
	var hx := wx + dir * l
	for j in range(1, 4):
		_put(hx - dir * j, y - j, dc)
		_put(hx - dir * j, y + j, dc)
	_put(hx + dir, y, dc)
	if float(S.t) >= 6.0 or int(S.used) > 0:
		rd.append(["DRIFT %d" % absi(S.vk), "good" if dc == MiniPix.GOOD else "neutral"])


## Your docking clamp, hanging from the header rule; it reaches down once docked.
func _draw_clamp(kx: int, ty: int, tt: float, ok: bool) -> void:
	var ct := MiniKit.PLAY_Y
	var ext := mini(ty - 13 - ct, MiniPix.jr((tt - end_t) * 40.0)) if S.docked else 0
	for y in 6 + ext:
		for x in range(-9, 10):
			var ax := absi(x)
			if ax < 4 and y < 6 + ext - 2:
				continue
			if ax > 9 - (2 if y > 4 + ext else 0):
				continue
			_put(kx + x, ct + y, M[6] if ax == 9 or y == 0 else (M[4] if ax >= 7 else M[5]))
	for x: int in [-9, 9]:
		for y in 6 + ext:
			_put(kx + x + (1 if x > 0 else -1), ct + y, M[0])
	for x: int in [-6, 6]:
		_put(kx + x, ct + 2, MiniPix.GOOD if ok else (MiniPix.EMBER if int(floorf(tt * 2.0)) % 2 == 1 else M[3]))


## A thick pixel arc from angle a0 to a1 (degrees; 0 right, 90 down) with a head at a1.
func _arrow_arc(r: int, a0: float, a1: float, col: Color, dark: Color, chev: float, tt: float) -> void:
	var ox := CX + MiniPix.jr(S.x)
	var dir := signf(a1 - a0) if signf(a1 - a0) != 0.0 else 1.0
	var ln := absf(a1 - a0)
	var d := 0.0
	while d <= ln:
		var a := (a0 + dir * d) * PI / 180.0
		for rr: int in [r - 1, r, r + 1]:
			var y := MiniPix.jr(CY + sin(a) * rr)
			if y < VH:
				_put(MiniPix.jr(ox + cos(a) * rr), y, col if rr == r else dark)
		d += 1.2
	# chevrons running along it, faster with more spin
	if chev != 0.0:
		d = fmod(tt * chev * 40.0, 14.0)
		while d < ln - 6.0:
			var a := (a0 + dir * d) * PI / 180.0
			_put(MiniPix.jr(ox + cos(a) * r), MiniPix.jr(CY + sin(a) * r), MiniPix.HOT)
			d += 14.0
	var ah := a1 * PI / 180.0
	var hx := ox + cos(ah) * r
	var hy := CY + sin(ah) * r
	var tx := -sin(ah) * dir
	var ty := cos(ah) * dir
	var nx := cos(ah)
	var ny := sin(ah)
	for s in 6:
		for w in range(-(5 - s), 5 - s + 1):
			var y := MiniPix.jr(hy + ty * s + ny * w)
			if y < VH:
				_put(MiniPix.jr(hx + tx * s + nx * w), y, dark if s == 0 or absi(w) == 5 - s else col)


## Thruster puffs at the frame's edges.
func _draw_puffs() -> void:
	for f in fx:
		var k := float(f.age) / float(f.life)
		var r := 1.0 + k * 6.0
		var j := -ceili(r)
		while j <= r:
			var i := 0
			while i <= r * 1.6:
				var d := GameSling.hyp(i / 1.6, j) / r
				if d <= 1.0:
					var x := MiniPix.jr(float(f.x) + int(f.dir) * i)
					var y := MiniPix.jr(float(f.y) + j - k * 3.0)
					if MiniPix.bay(x, y) <= (1.0 - d) * (1.0 - k) * 1.8:
						_put(x, y, MiniPix.ICE if d < 0.4 and k < 0.3 else MiniPix.CHILL)
				i += 1
			j += 1


## The wreck turned by th about (cx, cy): each screen pixel looked up in the mask, lit by its turned normal.
func _draw_wreck(cx: int, cy: int, th: float) -> void:
	var a := th * PI / 180.0
	var ca := cos(a)
	var sa := sin(a)
	var n: int = WR.N
	var c: int = WR.C
	var mat: PackedInt32Array = WR.mat
	var nrm: PackedFloat32Array = WR.nrm
	var r := 34
	var lit6: bool = lined(S, P) or S.docked
	var tt: float = S.t
	# the mask under every pixel of the box and one round it (the page's `inside`, worked out once each)
	var x0 := cx - r - 1
	var y0 := cy - r - 1
	var bw := 2 * r + 3
	var idx := PackedInt32Array()
	idx.resize(bw * bw)
	for j in bw:
		for i in bw:
			var dx := (x0 + i) + 0.5 - cx
			var dy := (y0 + j) + 0.5 - cy
			var lx := MiniPix.jr(dx * ca + dy * sa) + c
			var ly := MiniPix.jr(-dx * sa + dy * ca) + c
			idx[j * bw + i] = ly * n + lx if lx >= 0 and ly >= 0 and lx < n and ly < n else -1
	for sy in range(cy - r, cy + r + 1):
		if sy < 0 or sy >= VH:
			continue
		for sx in range(cx - r, cx + r + 1):
			if sx < 0 or sx >= PW:
				continue
			var k := (sy - y0) * bw + sx - x0
			var i := idx[k]
			var m := -1 if i < 0 else mat[i]
			if m < 0:
				for q: int in [k + 1, k - 1, k + bw, k - bw]:
					if idx[q] >= 0 and mat[idx[q]] >= 0:
						_put(sx, sy, M[0])
						break
				continue
			var nx := nrm[i * 2]
			var ny := nrm[i * 2 + 1]
			var snx := nx * ca - ny * sa
			var sny := nx * sa + ny * ca
			var lit := -(snx + sny) * 0.707
			var body := -((sx - cx) + (sy - cy)) / 40.0
			var v := MiniPix.jr(lit * 1.6 + body + MiniPix.bay(sx, sy) * 0.9 - 0.45)
			_put(sx, sy, _hull(m, v, sx, sy, tt, lit6))
	for cb: Dictionary in WR.cables:
		for i in int(cb.len):
			var lx := int(cb.x) + i
			var ly := int(cb.y) + MiniPix.jr(sin(tt * 2.0 + float(cb.ph) + i * 0.6) * i * 0.25)
			var sx := MiniPix.jr(cx + lx * ca - ly * sa)
			var sy := MiniPix.jr(cy + lx * sa + ly * ca)
			if sx >= 0 and sy >= 0 and sx < PW and sy < VH:
				_put(sx, sy, MiniPix.HOT if i == int(cb.len) - 1 and int(floorf(tt * 5.0 + float(cb.ph))) % 3 == 0 else MiniPix.WARN)


## One hull pixel's colour: plate, engine, burn (with its embers), seams, the port and its lamp.
func _hull(m: int, v: int, sx: int, sy: int, tt: float, lit6: bool) -> Color:
	match m:
		1:
			return M[clampi(4 + v, 1, 7)]
		2:
			return M[clampi(3 + v, 1, 6)]
		3:
			return MiniPix.EMBER if sin(tt * 3.0 + sx * 1.7 + sy) > 0.97 else BURN[clampi(2 + v, 0, 3)]
		4:
			return MiniPix.HOT if (sx * 7 + sy * 3) % 11 == 0 and sin(tt * 2.0 + sx) > 0.0 else M[1]
		5:
			return M[clampi(5 + v, 2, 8)]
	return MiniPix.MARK if lit6 else (MiniPix.FLARE if int(floorf(tt * 3.0)) % 2 == 1 else MiniPix.HOT)


## The kit, as the page draws it inside `translate(1,0)`: on a 150-wide layer laid 1 px in.
func _hud(now: float, rd: Array) -> void:
	var k := _kit
	k.img.fill(Color(0, 0, 0, 0))
	var left := int(P.gas) - int(S.used)
	var tl := maxi(0, ceili(float(P.T) - float(S.t)))
	var low := left <= 3
	var lhs := {label = "GAS", meter = {w = mini(int(P.gas) * 4 + 1, 89), frac = float(left) / float(P.gas), kind = "bad" if low else "neutral"}}
	if low:
		lhs.kind = "bad"
	var tm: Array = ["TIME", tl, null]
	if tl < 10:
		tm[2] = "bad"
	MiniKit.header(k, lhs, [tm])
	if float(S.t) < 6.0 and int(S.used) == 0:
		MiniKit.tell(k, "STOP IT UNDER THE CLAMP.", ["click"] as Array[String], now)
	MiniKit.deck(k, true)
	if status_t > 0.0 or S.over:
		MiniKit.status(k, status, status_kind, true)
	elif not rd.is_empty():
		MiniKit.status(k, rd, "", true)
	var want := ""
	if not S.over and int(P.depth) <= 3 and int(S.wk) != 0:
		want = "ccw" if int(S.wk) > 0 else "cw"
	for b in B:
		var on: bool = press == b.id and press_t > 0.0
		var st := "disabled" if S.over or int(S.used) >= int(P.gas) else (("active-pressed" if on else "active") if want == b.id else ("pressed" if on else "normal"))
		MiniKit.button(k, int(b.x) - 1, BY, int(b.w), BH, "", st, b.id)
	px.img.blend_rect(k.img, Rect2i(0, 0, MiniKit.W, MiniKit.H), Vector2i(1, 0))
