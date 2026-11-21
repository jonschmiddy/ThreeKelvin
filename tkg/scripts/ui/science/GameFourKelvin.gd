class_name GameFourKelvin
extends MiniGame

## FOUR KELVIN (Jon loved, Nov 17): turn and thrust a probe east through an asteroid belt; fly
## through sparkles for ore, richer further in. A port of the approved `fourkelvin.js`. W thrusts,
## A and D turn; touch has the three buttons under the view.
## Why: docs/why/MiniGame.md#the-round-2-games

const W := MiniKit.W
const H := MiniKit.H
## The deal's view width: the belt is laid out as the 140 px prototype's (fit4 widened only the view).
const GENW := 140
## View: kit header rows 0 to 9, the belt 10 to 109, the progress bar 112 and 113, the kit deck 116 to
## 139 (status A, Nov 20: the belt took the freed rows, 82 -> 100, world 1:1).
const VY := 10
const BH := 100
const SHIPX := 46
const DT := 1.0 / 30.0
const TURN := 3.6
const ACC := 72.0
const DRAG := 0.9
const VMAX := 52.0
const HULLN := 2
const SHIPR := 3.2
const FACINGS := 32
const LEAD := 70.0
const NODE := 48.0
const CFG := {
	1: {hw = 18.0, step = 10.0, dens = 95.0, amp = 2.0, spin_lo = 0.2, spin_hi = 0.6, len = 1150.0},
	2: {hw = 16.0, step = 12.0, dens = 120.0, amp = 3.0, spin_lo = 0.3, spin_hi = 0.9, len = 1250.0},
	3: {hw = 14.5, step = 14.0, dens = 145.0, amp = 4.0, spin_lo = 0.4, spin_hi = 1.2, len = 1350.0},
	4: {hw = 13.0, step = 16.0, dens = 165.0, amp = 5.0, spin_lo = 0.5, spin_hi = 1.5, len = 1450.0},
	5: {hw = 12.0, step = 18.0, dens = 185.0, amp = 6.0, spin_lo = 0.6, spin_hi = 1.8, len = 1550.0},
}
const STONE: Array[Color] = [Color("#080b11"), Color("#141b25"), Color("#22303f"), Color("#3d4d61"), Color("#6b7d94"), Color("#8fa3ba")]
const RUST: Array[Color] = [Color("#080b11"), Color("#24171a"), Color("#4a2e2a"), Color("#7a4c40"), Color("#a5705f"), Color("#c98d7a")]
const HULL: Array[Color] = [MiniPix.BEVEL_HI, MiniPix.COLD, MiniPix.CHILL, MiniPix.ICE]
const TIER_HI: Array[Color] = [Color("#d8dde2"), Color("#b6f0cf"), Color("#c8dcf5"), Color("#d6b8f5"), Color("#ffe0a0")]
const M4: Array[int] = [0, 2, 3, 1]
const CRACK: Array[Vector2] = [Vector2(-0.8, -1.5), Vector2(-0.2, -0.5), Vector2(-1, 0.5)]
const BTN := {"a": Rect2i(MiniKit.GUT, MiniKit.BTN_YL, 25, MiniKit.BTN_HL), "d": Rect2i(MiniKit.GUT + 25 + MiniKit.GAP, MiniKit.BTN_YL, 25, MiniKit.BTN_HL),
	"w": Rect2i(W - MiniKit.GUT - 45, MiniKit.BTN_YL, 45, MiniKit.BTN_HL)}
const BTN_ICON := {"a": "ccw", "d": "cw", "w": "thrust"}
const SEGW := 7
const SHIELD_DK := Color("#3f5f8a")
const HULL_DK := Color("#4f7a63")
const SHIELD_GONE := Color("#2a3a52")
const FLASH := Color("#fff4dc")
const SF: Array[float] = [0.1, 0.25, 0.5]
const SC: Array[Color] = [MiniPix.LINE, MiniPix.COLD, MiniPix.CHILL]

var F: Dictionary = {}
var stars: Array = []
var s := {x = 20.0, y = 0.0, vx = 0.0, vy = 0.0, ang = 0.0}
var keys := {"w": false, "a": false, "d": false}
var ptr := ""
var mode := "ready"
var thrust := false
var shield := 0
var hull := HULLN
var inv := 0.0
var ore_n := 0
var ore_val := 0
var clock := 0.0
var tick_n := 0
var end_t := 0.0
var crashed := false
var fired := false
var max_x := 20.0
var cam_x := 0.0
var parts: Array = []
var nseg := 2
var lost_at: Array[float] = []
var culprit: Dictionary = {}
var hit_t := -9.0
var hit_shield := false
var _acc := 0.0


func id() -> StringName:
	return &"fourkelvin"


func hint() -> String:
	return "Fly the ship. Get the ore."


func controls() -> Array[String]:
	return ["keys:WAD"]


# ---------------------------------------------------------------- the field

static func _rr(r: RandomNumberGenerator) -> float:
	return r.randf()


static func mk_rock(r: RandomNumberGenerator, x: float, y: float, rad: float, c: Dictionary) -> Dictionary[String, Variant]:
	var prof := PackedFloat32Array()
	prof.resize(32)
	var a2 := r.randf()
	var a3 := r.randf()
	var p2 := r.randf() * 6.28
	var p3 := r.randf() * 6.28
	var p5 := r.randf() * 6.28
	var k := 0.5 if rad < 3.5 else 1.0
	for i in 32:
		var t_ := i / 32.0 * 6.2832
		prof[i] = rad * (1.0 + k * (0.13 * a2 * cos(2.0 * t_ + p2) + 0.1 * a3 * cos(3.0 * t_ + p3) + 0.05 * cos(5.0 * t_ + p5)))
	var craters: Array = []
	if rad >= 4.0:
		var nn := 1 + int(r.randf() * (3 if rad > 7.0 else 2))
		for i in nn:
			var a := r.randf() * 6.28
			var d := r.randf() * 0.55 * rad
			craters.append(Vector3(cos(a) * d, sin(a) * d, 0.9 + r.randf() * rad * 0.2))
	var da := r.randf() * 6.28
	var am := float(c.amp) * (0.4 + 0.6 * r.randf())
	var o := {x = x, y = y, r = rad, prof = prof, craters = craters, rot0 = r.randf() * 6.28}
	o.rs = (-1.0 if r.randf() < 0.5 else 1.0) * (float(c.spin_lo) + r.randf() * (float(c.spin_hi) - float(c.spin_lo)))
	o.rust = r.randf() < 0.3
	o.ax = cos(da) * am
	o.ay = sin(da) * am
	o.w1 = 0.25 + r.randf() * 0.35
	o.w2 = 0.25 + r.randf() * 0.35
	o.p1 = r.randf() * 6.28
	o.p2 = r.randf() * 6.28
	o.amp = am
	var out: Dictionary[String, Variant] = {}
	out.assign(o)
	return out


## The lane's centre at x: a smooth walk between nodes.
static func cen(nodes: PackedFloat64Array, x: float) -> float:
	x = maxf(0.0, x)
	var i := int(floorf(x / NODE))
	var f := x / NODE - i
	var a := nodes[mini(i, nodes.size() - 1)]
	var b := nodes[mini(i + 1, nodes.size() - 1)]
	return a + (b - a) * f * f * (3.0 - 2.0 * f)


## Rocks keep clear of a hidden lane by their full drift, so every seed has a way through.
static func gen(r: RandomNumberGenerator, d: int) -> Dictionary[String, Variant]:
	var c: Dictionary = CFG[d]
	var target: float = c.len
	var ln := target + GENW + 40
	var hw: float = c.hw
	var nodes := PackedFloat64Array()
	var y := BH / 2.0
	var lo := hw + 3.0
	var hi := BH - hw - 3.0
	var i := 0
	while i * NODE <= ln + NODE * 2:
		if i > 1:
			y += (r.randf() * 2.0 - 1.0) * float(c.step)
			y = maxf(lo, minf(hi, y))
		nodes.append(y)
		i += 1
	var rocks: Array = []
	# rocks per area as the 82-row belt had them, so the taller belt is no emptier
	var want := MiniPix.jr(float(c.dens) * ln / 1000.0 * BH / 82.0)
	var t_ := 0
	while t_ < want * 6 and rocks.size() < want:
		t_ += 1
		var u := r.randf()
		var rad := 2.8 + r.randf() * 2.0 if u < 0.5 else (4.8 + r.randf() * 3.0 if u < 0.82 else 7.8 + r.randf() * 4.0)
		var x := LEAD + rad * 1.3 + float(c.amp) + r.randf() * (ln - LEAD)
		var yy := -3.0 + r.randf() * (BH + 6)
		var o := mk_rock(r, x, yy, rad, c)
		if not _clear(nodes, hw, x, yy, rad * 1.15 + 0.5 + float(o.amp)):
			continue
		var crowded := false
		for q: Dictionary in rocks:
			if absf(float(q.x) - x) < float(q.r) + rad + float(q.amp) + float(o.amp) + 2.0 \
				and Vector2(float(q.x) - x, float(q.y) - yy).length() < (float(q.r) + rad) * 0.8 + float(q.amp) + float(o.amp) + 1.0:
				crowded = true
				break
		if crowded:
			continue
		rocks.append(o)
	rocks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.x) < float(b.x))
	var glints: Array = []
	var gx := LEAD + 10.0
	while gx < target - 10.0:
		var tier := mini(4, int(floorf(gx / target * 5.0)))
		glints.append({x = gx, y = cen(nodes, gx) + (r.randf() * 2.0 - 1.0) * (hw - 6.0), tier = tier, val = tier + 1, got = false, ph = r.randf() * 6.0})
		gx += 50.0 + r.randf() * 35.0
	var out: Dictionary[String, Variant] = {}
	out.assign({rocks = rocks, glints = glints, nodes = nodes, hw = hw, target = target, depth = d})
	return out


static func _clear(nodes: PackedFloat64Array, hw: float, x: float, yy: float, rad: float) -> bool:
	var xs := x - rad - hw
	while xs <= x + rad + hw:
		if Vector2(xs - x, cen(nodes, xs) - yy).length() < rad + hw:
			return false
		xs += 1.0
	return true


static func rock_pos(o: Dictionary, tt: float) -> Vector2:
	return Vector2(float(o.x) + float(o.ax) * sin(float(o.w1) * tt + float(o.p1)), float(o.y) + float(o.ay) * sin(float(o.w2) * tt + float(o.p2)))


static func lower(arr: Array, x: float) -> int:
	var lo := 0
	var hi := arr.size()
	while lo < hi:
		var m := (lo + hi) >> 1
		if float(arr[m].x) < x:
			lo = m + 1
		else:
			hi = m
	return lo


static func shields(sn: int) -> int:
	return ceili(sn / 2.0)


static func score_of(f: Dictionary, dist: float, ov: int) -> float:
	var tot := 0
	for g: Dictionary in f.glints:
		tot += int(g.val)
	tot = maxi(tot, 1)
	return clampf(0.65 * clampf(dist / float(f.target), 0.0, 1.0) + 0.35 * minf(1.0, float(ov) / tot), 0.0, 1.0)


static func _dith(x: int, y: int, tt: float) -> bool:
	return (M4[(y & 1) * 2 + (x & 1)] + 0.5) / 4.0 < tt


static func _in_tri(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var d1 := (p.x - b.x) * (a.y - b.y) - (a.x - b.x) * (p.y - b.y)
	var d2 := (p.x - c.x) * (b.y - c.y) - (b.x - c.x) * (p.y - c.y)
	var d3 := (p.x - a.x) * (c.y - a.y) - (c.x - a.x) * (p.y - a.y)
	return not ((d1 < 0 or d2 < 0 or d3 < 0) and (d1 > 0 or d2 > 0 or d3 > 0))


## The probe in its own frame (nose along +x): 1 the egg-shaped body, 2 a swept fin, 0 neither.
static func ship_part(lx: float, ly: float) -> int:
	var ex := (lx - 0.6) / (5.0 if lx > 0.6 else 4.2)
	var ey := ly / 2.7
	if ex * ex + ey * ey <= 1.0:
		return 1
	var p := Vector2(lx, ly)
	if _in_tri(p, Vector2(-5, -4.6), Vector2(-0.5, -2), Vector2(-4.2, -1.5)) or _in_tri(p, Vector2(-5, 4.6), Vector2(-0.5, 2), Vector2(-4.2, 1.5)):
		return 2
	return 0


# ---------------------------------------------------------------- the game

func _mount() -> void:
	px = MiniPix.new(W, H)
	F = gen(rng, depth)
	for i in 70:
		stars.append({x = rng.randf() * W, y = VY + rng.randf() * BH, l = 0 if i < 34 else (1 if i < 58 else 2), tw = rng.randf() < 0.3})
	s.y = cen(F.nodes, 20.0)
	shield = shields(sensors)
	nseg = HULLN + shield
	lost_at.resize(nseg)
	lost_at.fill(-1.0)
	max_x = s.x
	cam_x = s.x - SHIPX
	_render()


func _want(k: String) -> bool:
	return bool(keys[k]) or ptr == k


func _dist() -> float:
	return maxf(0.0, max_x - 20.0)


func facing() -> float:
	var st := 2.0 * PI / FACINGS
	return MiniPix.jr(float(s.ang) / st) * st


func _burst(x: float, y: float, nn: int, cols: Array, sp: float) -> void:
	for i in nn:
		var a := rng.randf() * 6.283
		var v := sp * (0.3 + rng.randf() * 0.7)
		parts.append({x = x, y = y, vx = cos(a) * v, vy = sin(a) * v, life = 0.5 + rng.randf() * 0.5, cols = cols})


func _finish() -> void:
	if fired:
		return
	fired = true
	var m := int(floorf(_dist() * 5.0))
	say_end("IMPACT" if crashed else "BELT CLEAR", "bad" if crashed else "good")
	done(score_of(F, _dist(), ore_val), ("Hull broke at " if crashed else "Cleared the belt, ") + "%d m, ore %d of %d" % [m, ore_n, (F.glints as Array).size()])


func _update() -> void:
	tick_n += 1
	clock += DT
	sfx_loop(&"thrust", mode == "run" and _want("w"))
	if mode == "run":
		_fly()
	elif mode == "end":
		end_t += DT
		if end_t > (2.6 if crashed else 1.6):
			_finish()
	if mode == "run" and hull < HULLN and tick_n % 5 == 0:
		var fa := facing()
		parts.append({x = float(s.x) - cos(fa) * 2.0, y = float(s.y) - sin(fa) * 2.0, vx = -float(s.vx) * 0.2 + (rng.randf() - 0.5) * 4.0,
			vy = -float(s.vy) * 0.2 - 3.0, life = 0.9, cols = [MiniPix.CHILL, MiniPix.COLD, MiniPix.LINE]})
	cam_x += ((float(s.x) - SHIPX) - cam_x) * 0.12
	var keep: Array = []
	for q: Dictionary in parts:
		q.x += float(q.vx) * DT
		q.y += float(q.vy) * DT
		q.vx *= 0.94
		q.vy *= 0.94
		q.life -= DT
		if float(q.life) > 0.0:
			keep.append(q)
	parts = keep


func _fly() -> void:
	var a := _want("a")
	var d := _want("d")
	thrust = _want("w")
	if a and not d:
		s.ang -= TURN * DT
	elif d and not a:
		s.ang += TURN * DT
	var fa := facing()
	if thrust:
		s.vx += cos(fa) * ACC * DT
		s.vy += sin(fa) * ACC * DT
	var k := 1.0 - DRAG * DT
	s.vx *= k
	s.vy *= k
	var sp := Vector2(s.vx, s.vy).length()
	if sp > VMAX:
		s.vx *= VMAX / sp
		s.vy *= VMAX / sp
	s.x += float(s.vx) * DT
	s.y += float(s.vy) * DT
	if float(s.y) < SHIPR + 1:
		s.y = SHIPR + 1
		if float(s.vy) < 0.0:
			s.vy *= -0.3
	if float(s.y) > BH - SHIPR - 1:
		s.y = BH - SHIPR - 1
		if float(s.vy) > 0.0:
			s.vy *= -0.3
	if float(s.x) < 6.0:
		s.x = 6.0
		if float(s.vx) < 0.0:
			s.vx = 0.0
	max_x = maxf(max_x, s.x)
	var gl: Array = F.glints
	var i := lower(gl, float(s.x) - 6.0)
	while i < gl.size() and float(gl[i].x) < float(s.x) + 6.0:
		var q: Dictionary = gl[i]
		if not q.got and Vector2(float(q.x) - float(s.x), float(q.y) - float(s.y)).length() < 5.5:
			q.got = true
			ore_n += 1
			ore_val += int(q.val)
			_burst(q.x, q.y, 5, [TIER_HI[q.tier], MiniPix.TIERS[q.tier]], 14.0)
		i += 1
	if inv > 0.0:
		inv -= DT
	_bumps()
	if mode == "run" and max_x >= float(F.target) + 20.0:
		mode = "end"
		thrust = false
		sfx(&"win")


## Every bump breaks one block, blue shields first; the last block going is the crash.
func _bumps() -> void:
	var rk: Array = F.rocks
	var i := lower(rk, float(s.x) - 20.0)
	while i < rk.size() and float(rk[i].x) < float(s.x) + 20.0 and mode == "run":
		var o: Dictionary = rk[i]
		i += 1
		var rp := rock_pos(o, clock)
		var dx := float(s.x) - rp.x
		var dy := float(s.y) - rp.y
		var dd := Vector2(dx, dy).length()
		var mn := float(o.r) * 0.85 + SHIPR
		if dd >= mn:
			continue
		var nx := dx / dd if dd else -1.0
		var ny := dy / dd if dd else 0.0
		var vn := float(s.vx) * nx + float(s.vy) * ny
		s.x = rp.x + nx * mn
		s.y = rp.y + ny * mn
		if inv > 0.0:
			if vn < 0.0:
				s.vx -= 1.5 * vn * nx
				s.vy -= 1.5 * vn * ny
			continue
		sfx(&"bump")
		var was := shield > 0
		if was:
			shield -= 1
		else:
			hull -= 1
		lost_at[hull + shield] = clock
		hit_t = clock
		hit_shield = was
		if hull <= 0:
			crashed = true
			culprit = o
			mode = "end"
			thrust = false
			_burst(s.x, s.y, 16, [MiniPix.HOT, MiniPix.FLARE, MiniPix.EMBER, MiniPix.BEVEL_HI], 22.0)
		else:
			inv = 1.0
			s.vx -= 1.6 * vn * nx
			s.vy -= 1.6 * vn * ny
			_burst(float(s.x) - nx * SHIPR, float(s.y) - ny * SHIPR, 6, [MiniPix.ICE, MiniPix.TIERS[2], MiniPix.COLD] if was else [MiniPix.HOT, MiniPix.FLARE, MiniPix.EMBER], 12.0)


func _tick(dt: float) -> void:
	_acc += minf(0.25, dt)
	while _acc >= DT:
		_update()
		_acc -= DT
	# The page draws every frame, so a key's press shows before the next step.
	if drawing and not fired:
		_render()


# ---------------------------------------------------------------- drawing

func _p(x: float, y: float, c: Color) -> void:
	var xi := int(x)
	var yi := int(y)
	if xi >= 0 and yi >= 0 and xi < W and yi < H:
		px.img.set_pixel(xi, yi, c)


func _sx(x: float) -> float:
	return x - cam_x


func _draw_rock(o: Dictionary, sx: float, sy: float) -> void:
	var cx := MiniPix.jr(sx)
	var cy := MiniPix.jr(sy)
	var rad: float = o.r
	var rr := ceili(rad * 1.25) + 1
	var st := PI / 12.0
	var ang := MiniPix.jr((float(o.rot0) + float(o.rs) * clock) / st) * st
	var ca := cos(ang)
	var sa := sin(ang)
	var ramp: Array[Color] = RUST if o.rust else STONE
	var prof: PackedFloat32Array = o.prof
	for j in range(-rr, rr + 1):
		var y := cy + j
		if y < VY or y >= VY + BH:
			continue
		for i in range(-rr, rr + 1):
			var x := cx + i
			if x < 0 or x >= W:
				continue
			var lx := i * ca + j * sa
			var ly := -i * sa + j * ca
			var rho := Vector2(lx, ly).length()
			var pr := prof[posmod(MiniPix.jr(atan2(ly, lx) / 6.2832 * 32.0) % 32, 32)]
			if rho > pr:
				continue
			if rho > pr - 1.0:
				px.img.set_pixel(x, y, ramp[0])
				continue
			var z := sqrt(maxf(0.0, 1.0 - (rho / pr) * (rho / pr)))
			var tt := ((-i * 0.6 - j * 0.75) / pr) * 0.55 + z * 0.6 + 0.05
			for q: Vector3 in o.craters:
				if Vector2(lx - q.x, ly - q.y).length() < q.z:
					tt -= 0.3
			var v := clampf(tt, 0.0, 1.0) * 4.0
			var b := int(floorf(v))
			if b < 4 and _dith(x, y, v - b):
				b += 1
			px.img.set_pixel(x, y, ramp[1 + mini(4, b)])


func _draw_glint(q: Dictionary, sx: float, sy: float) -> void:
	var x := MiniPix.jr(sx)
	var y := MiniPix.jr(sy)
	var ph := int(floorf(tick_n / 4.0 + float(q.ph) * 3.0)) % 6
	var arm := 1 if ph < 2 else (2 if ph < 4 else 1)
	var tier: int = q.tier
	for j in range(-4, 5):
		for i in range(-4, 5):
			var d := Vector2(i, j).length()
			if d > 2.5 and d < 4.2 and _dith(x + i, y + j, 0.25) and y + j >= VY:
				_p(x + i, y + j, MiniPix.TIERS[tier])
	for a in range(1, arm + 1):
		var c := TIER_HI[tier] if a == 1 else MiniPix.TIERS[tier]
		_p(x + a, y, c)
		_p(x - a, y, c)
		_p(x, y + a, c)
		_p(x, y - a, c)
	_p(x, y, MiniPix.HOT)


func _inside(i: int, j: int, ca: float, sa: float) -> int:
	return ship_part(i * ca + j * sa, -i * sa + j * ca)


func _draw_ship() -> void:
	var fa := facing()
	var ca := cos(fa)
	var sa := sin(fa)
	var cx := MiniPix.jr(_sx(s.x))
	var cy := MiniPix.jr(float(s.y) + VY)
	if thrust and mode == "run":
		var ln := 3 + (tick_n >> 1) % 3
		for j in range(-6, 7):
			for i in range(-6, 7):
				var lx := i * ca + j * sa
				var ly := -i * sa + j * ca
				if lx > -4.0:
					continue
				var d := Vector2((lx + 5.0 + ln / 2.0) / 1.4, ly).length()
				if d < 3.4 and _dith(cx + i, cy + j, 0.5 if d < 2.0 else 0.25):
					_p(cx + i, cy + j, MiniPix.EMBER)
		for k in ln:
			_p(cx + MiniPix.jr(-ca * (5 + k)), cy + MiniPix.jr(-sa * (5 + k)), MiniPix.HOT if k == 0 else (MiniPix.FLARE if k < ln - 1 else MiniPix.EMBER))
	for j in range(-7, 8):
		for i in range(-7, 8):
			var part := _inside(i, j, ca, sa)
			if not part:
				continue
			var x := cx + i
			var y := cy + j
			if not _inside(i + 1, j, ca, sa) or not _inside(i - 1, j, ca, sa) or not _inside(i, j + 1, ca, sa) or not _inside(i, j - 1, ca, sa):
				_p(x, y, STONE[0])
				continue
			var lx := i * ca + j * sa
			var ly := -i * sa + j * ca
			if Vector2(lx - 2.2, ly).length() < 1.3:
				_p(x, y, MiniPix.HOT if i + j < 0 else MiniPix.FLARE)
				continue
			var tt := 0.25 if part == 2 else 0.62 - (i * 0.5 + j * 0.65) / 5.0
			var v := clampf(tt, 0.0, 1.0) * 3.0
			var b := int(floorf(v))
			if b < 3 and _dith(x, y, v - b):
				b += 1
			_p(x, y, HULL[mini(3, b)])
	if hull < HULLN:
		var seen := {}
		for k in CRACK.size():
			var c := CRACK[k]
			var i := MiniPix.jr(c.x * ca - c.y * sa)
			var j := MiniPix.jr(c.x * sa + c.y * ca)
			var key := Vector2i(i, j)
			if seen.has(key) or not _inside(i, j, ca, sa) or not _inside(i + 1, j, ca, sa) or not _inside(i - 1, j, ca, sa) \
				or not _inside(i, j + 1, ca, sa) or not _inside(i, j - 1, ca, sa):
				continue
			seen[key] = true
			_p(cx + i, cy + j, MiniPix.EMBER if k == 1 and (tick_n >> 3) % 2 else STONE[0])
	if inv > 0.0:
		var tt := 0.5 * inv
		var col := MiniPix.TIERS[2] if hit_shield else MiniPix.FLARE
		for j in range(-8, 9):
			for i in range(-8, 9):
				var d := Vector2(i, j).length()
				if d > 6.6 and d < 7.6 and _dith(cx + i, cy + j, tt) and cy + j >= VY and cy + j < VY + BH:
					_p(cx + i, cy + j, col)


func _draw_warn() -> void:
	if sensors < 1 or mode != "run":
		return
	var rng_ := 8 + 4 * sensors
	var up_ := false
	var dn := false
	var rt := false
	var lf := false
	var rk: Array = F.rocks
	var i := lower(rk, float(s.x) - 30.0)
	while i < rk.size() and float(rk[i].x) < float(s.x) + 30.0:
		var o: Dictionary = rk[i]
		i += 1
		var rp := rock_pos(o, clock)
		var dx := rp.x - float(s.x)
		var dy := rp.y - float(s.y)
		if Vector2(dx, dy).length() - float(o.r) - SHIPR > rng_:
			continue
		if absf(dy) > absf(dx):
			if dy < 0:
				up_ = true
			else:
				dn = true
		elif dx > 0:
			rt = true
		else:
			lf = true
	var tt := 0.25 if int(floorf(clock * 3.0)) & 1 else 0.12
	var cx := MiniPix.jr(_sx(s.x))
	var cy := MiniPix.jr(float(s.y) + VY)
	for k in range(-14, 15):
		if up_ and _dith(cx + k, VY, tt):
			_p(cx + k, VY, MiniPix.EMBER)
		if dn and _dith(cx + k, VY + BH - 1, tt):
			_p(cx + k, VY + BH - 1, MiniPix.EMBER)
		if rt and _dith(W - 1, cy + k, tt) and cy + k >= VY and cy + k < VY + BH:
			_p(W - 1, cy + k, MiniPix.EMBER)
		if lf and _dith(0, cy + k, tt) and cy + k >= VY and cy + k < VY + BH:
			_p(0, cy + k, MiniPix.EMBER)


func _render() -> void:
	px.img.fill(MiniPix.VOID)
	for st: Dictionary in stars:
		var x := int(floorf(fposmod(float(st.x) - cam_x * SF[st.l], W)))
		var twk: bool = int(st.l) == 2 and st.tw and ((tick_n >> 3) + x) % 7 == 0
		_p(x, st.y, MiniPix.ICE if twk else SC[st.l])
	var ex := MiniPix.jr(_sx(float(F.target) + 20.0))
	if ex >= 0 and ex < W:
		for y in range(VY, VY + BH, 3):
			_p(ex, y, MiniPix.GOOD)
	var lo := cam_x - 16.0
	var hi := cam_x + W + 16.0
	var gl: Array = F.glints
	var i := lower(gl, lo)
	while i < gl.size() and float(gl[i].x) < hi:
		var q: Dictionary = gl[i]
		if not q.got:
			_draw_glint(q, _sx(q.x), float(q.y) + VY)
		i += 1
	var rk: Array = F.rocks
	i = lower(rk, lo - 10.0)
	while i < rk.size() and float(rk[i].x) < hi + 10.0:
		var rp := rock_pos(rk[i], clock)
		_draw_rock(rk[i], _sx(rp.x), rp.y + VY)
		i += 1
	if not crashed:
		_draw_ship()
	_draw_warn()
	for q: Dictionary in parts:
		var cols: Array = q.cols
		var life: float = q.life
		var c: Color = cols[0] if life > 0.7 else ((cols[1] if cols.size() > 1 else cols[0]) if life > 0.35 else (cols[2] if cols.size() > 2 else cols[cols.size() - 1]))
		var y := float(q.y) + VY
		if y >= VY and y < VY + BH:
			_p(_sx(q.x), y, c)
	if crashed and end_t < 0.15:
		for j in range(-1, 2):
			for k in range(-1, 2):
				_p(_sx(s.x) + k, float(s.y) + VY + j, MiniPix.FLARE if k or j else MiniPix.HOT)
	_hud()
	draw_toast()
	dirty = true


func _cell_x(i: int) -> int:
	return i * (SEGW + 1) + (2 if i >= HULLN else 0)


## HULL: a block a bump left, green hull blocks then blue shields; the right-most goes first.
func _hull_bar(x: int, y: int) -> void:
	for i in nseg:
		var cx := x + _cell_x(i)
		var sh := i >= HULLN
		var on := i < hull + shield
		var age := 9.0 if lost_at[i] < 0.0 else clock - lost_at[i]
		px.rect(cx, y, SEGW, 7, MiniPix.BEVEL_LO)
		if on:
			px.rect(cx + 1, y + 1, SEGW - 2, 5, MiniPix.TIERS[2] if sh else MiniPix.GOOD)
			px.rect(cx + 1, y + 1, SEGW - 2, 1, MiniPix.ICE if sh else MiniPix.MARK)
			px.rect(cx + 1, y + 5, SEGW - 2, 1, SHIELD_DK if sh else HULL_DK)
		elif age < 0.9 and int(floorf(age * 10.0)) % 2 == 0:
			px.rect(cx + 1, y + 1, SEGW - 2, 5, MiniPix.HOT)
			px.rect(cx + 2, y + 2, SEGW - 4, 3, FLASH)
		else:
			px.rect(cx + 1, y + 1, SEGW - 2, 5, MiniPix.LINE)
			for k in 5:
				px.rect(cx + 1 + k, y + 5 - k, 1, 1, SHIELD_GONE if sh else MiniPix.BAD)


func _hud() -> void:
	var fresh := clock - hit_t < 0.9 and int(floorf((clock - hit_t) * 10.0)) % 2 == 0
	var sp := MiniKit.header(px, {label = "HULL", kind = "bad" if fresh else ""}, [["DIST", "%04dM" % int(floorf(_dist() * 5.0))]])
	_hull_bar(sp.x, 1)
	var dk := MiniKit.deck_y(true)
	var by := VY + BH + 2
	px.rect(0, VY + BH, W, dk - VY - BH, MiniPix.PANEL)
	var f := minf(1.0, _dist() / float(F.target))
	var bw := W - 2 * MiniKit.GUT
	px.rect(MiniKit.GUT, by, bw, 2, MiniPix.LINE)
	px.rect(MiniKit.GUT, by, MiniPix.jr(bw * f), 2, MiniPix.CHILL)
	px.rect(MiniKit.GUT + MiniPix.jr(bw * f), by, 1, 2, MiniPix.HOT)
	MiniKit.deck(px, true)
	for k: String in ["a", "d", "w"]:
		var r: Rect2i = BTN[k]
		var st := "disabled" if mode == "end" else ("pressed" if _want(k) else "normal")
		var ic: String = BTN_ICON[k]
		MiniKit.button(px, r.position.x, r.position.y, r.size.x, r.size.y, "THRUST" if k == "w" else "", st, ic)
	# ENERGY: always full, never used
	var rd: Rect2i = BTN.d
	var rw: Rect2i = BTN.w
	var ex := rd.end.x + MiniKit.GAP
	var ew := rw.position.x - MiniKit.GAP - ex
	px.text("ENERGY", ex, MiniKit.CTRL_CY - 6, MiniKit.LABEL)
	MiniKit.meter(px, ex, MiniKit.CTRL_CY, ew, 1.0, "yours")
	if mode == "ready" and not told:
		# the top spot: the ship starts on row 60, under the middle
		MiniKit.tell(px, "FLY THE SHIP.", ["keys:WAD"] as Array[String], clock, MiniKit.TELL_TOP)
	elif mode == "end":
		_intent_tag()


## A WARNING tag over the rock that did it, raised once it is far too late (Jon, Nov 17).
func _intent_tag() -> Dictionary[String, Variant]:
	var out: Dictionary[String, Variant] = {}
	if culprit.is_empty() or end_t < 0.3:
		return out
	var rp := rock_pos(culprit, clock)
	var sx := MiniPix.jr(_sx(rp.x))
	var sy := MiniPix.jr(rp.y + VY)
	var r := ceili(float(culprit.r) * 1.25) + 1
	var label := "WARNING: ROCK"
	var w := label.length() * 4 - 1 + 6
	var h := 9
	var x := maxi(1, mini(W - w - 1, sx - w / 2))
	var y := sy - r - h - 3
	var up_ := true
	if y < VY + 1:
		y = sy + r + 3
		up_ = false
	px.rect(x - 1, y - 1, w + 2, h + 2, MiniPix.BEVEL_LO)
	px.rect(x, y, w, h, MiniPix.PANEL)
	px.rect(x, y, w, 1, MiniPix.THEM)
	px.text(label, x + 3, y + 2, MiniPix.THEM)
	var tx := maxi(x + 2, mini(x + w - 3, sx))
	px.rect(tx, y + h + 1 if up_ else y - 3, 1, 2, MiniPix.THEM)
	out.assign({box = Rect2i(x - 1, y - 1, w + 2, h + 2), rx = sx - r, ry = sy - r, rw = 2 * r + 1})
	return out


# ---------------------------------------------------------------- input

func _begin() -> void:
	if not fired and mode == "ready":
		mode = "run"


func _zone(q: Vector2i) -> String:
	for k: String in BTN:
		var r: Rect2i = BTN[k]
		if q.x >= r.position.x - 1 and q.x < r.end.x + 1 and q.y >= r.position.y - 2 and q.y < r.end.y + 1:
			return k
	return ""


func down(q: Vector2i) -> void:
	ptr = _zone(q)
	_begin()


func move(q: Vector2i) -> void:
	if ptr != "":
		ptr = _zone(q)


func up(_q: Vector2i, _cancel := false) -> void:
	ptr = ""


func key(k: StringName, pressed: bool) -> void:
	if fired:
		return
	keys[String(k)] = pressed
	if pressed:
		_begin()


func give_up() -> void:
	if fired:
		return
	fired = true
	sfx_loop(&"thrust", false)
	_render()
	done(0.0 if mode == "ready" else score_of(F, _dist(), ore_val), "Gave up at %d m, ore %d of %d" % [int(floorf(_dist() * 5.0)), ore_n, (F.glints as Array).size()])
