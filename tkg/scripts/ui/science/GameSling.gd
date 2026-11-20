class_name GameSling
extends MiniGame

## GRAVITY SLING (Jon, Nov 17: "should be a dial, not a click"): turn the AIM dial, pull the sling
## back and let go; stars and planets bend the probe's path into the target ring. A port of the
## approved `sling2.js`: more masses by sector, a moving target from 4, a no-fly zone at 5.
## Why: docs/why/MiniGame.md#gravity-sling

const CFG := {
	1: {masses = 1, move = 0, zone = 0, tr = 36, shots = 5},
	2: {masses = 2, move = 0, zone = 0, tr = 34, shots = 5},
	3: {masses = 3, move = 0, zone = 0, tr = 32, shots = 5},
	4: {masses = 2, move = 1, zone = 0, tr = 32, shots = 5},
	5: {masses = 3, move = 1, zone = 1, tr = 30, shots = 5},
}
const FW := 1000.0
const FH := 640.0
const DT := 0.5
const MAXS := 1600
const K := 1.15
const AMIN := -80
const AMAX := 80
const PMIN := 10
const PMAX := 100
## How a flight ended (the prototype's `end` strings).
const LOST := 0
const CRASH := 1
const HIT := 2
const ZONE := 3
const W := 144
const H := 124
const FY := 92
const SC := 144.0 / 1000.0
const DX := 15
const DY := 108
const DRAD := 13
const FKX := 136
const RY := 109
const PULLMAX := 72
const SUN := Color("#fff4dc")
## Deals made before their mount, by "depth:seed:state" (the scan takes about half a second): the
## desk's card starts one on a worker; with `memo_on` (tests) every deal is kept for later mounts.
## Why: docs/why/MiniGame.md#gravity-sling
static var memo := {}
static var memo_on := false
static var _pre_task := -1
static var _pre_key := ""
static var _pre_got := {}

## {ox, oy, tx, ty, tr, masses [{x, y, r, gm}], move, zone ({x, y, w, h} or null), amp, per, sol, frac, a0}
var P: Dictionary = {}
var max_shots := 5
var ang := 0
var pow_ := 0
var last_pow := -1
var used := 0
var over := false
var started := false
var clock := 0.0
var off := 0.0
var note := ""
var note_t := 0.0
var miss_txt := ""
var best_miss := INF
## {r (the flight's sim), pts (canvas points, flat), k}
var flying: Dictionary = {}
## {t, from, wob}
var twang: Dictionary = {}
## {x, y, c, t0}
var fx: Dictionary = {}
## The last four flights: {pts, hit}.
var old: Array[Dictionary] = []
var dial: Dictionary = {}
var pull: Dictionary = {}
var _stub_steps := 0
var _stub := PackedFloat64Array()
var _bg: Image
var _deck: Image
## The deck's dimmer while a probe flies (`globalAlpha` .35 of VOID).
var _shade: Image
## The old paths, drawn once a flight lands (clear between them).
var _old_layer: Image
var _acc := 0.0


func id() -> StringName:
	return &"sling"


func hint() -> String:
	return "Hit the target."


func controls() -> Array[String]:
	return ["dial", "drag-h"]


# ---------------------------------------------------------------- the rules

## JS `Math.hypot` of two, as V8 computes it (scaled by the larger), so ties round alike.
static func hyp(a: float, b: float) -> float:
	a = absf(a)
	b = absf(b)
	var m := maxf(a, b)
	if m == 0.0:
		return 0.0
	var p := a / m
	var q := b / m
	return sqrt(p * p + q * q) * m


static func speed(p: float) -> float:
	return 2.0 + p * 0.08


## The masses packed for the flight loop, always three: x, y, r squared, gm. A missing one sits
## far off with no pull, so it adds exactly nothing.
static func _pack(p: Dictionary) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for m: Dictionary in p.masses:
		var r := float(m.r)
		out.append_array([float(m.x), float(m.y), r * r, float(m.gm)])
	while out.size() < 12:
		out.append_array([1e9, 1e9, -1.0, 0.0])
	return out


## `sim`: a probe launched at `a` degrees and power `pw`. With `steps`, only the first steps are
## flown (the sensors' stub), the target ignored. {pts (flat x, y), end, best, hitD}.
static func sim(p: Dictionary, a: float, pw: float, steps := 0, keep := true) -> Dictionary[String, Variant]:
	var ms := _pack(p)
	var m0x := ms[0]
	var m0y := ms[1]
	var m0r := ms[2]
	var m0g := ms[3]
	var m1x := ms[4]
	var m1y := ms[5]
	var m1r := ms[6]
	var m1g := ms[7]
	var m2x := ms[8]
	var m2y := ms[9]
	var m2r := ms[10]
	var m2g := ms[11]
	var rad := a * PI / 180.0
	var v := speed(pw)
	var x := float(p.ox)
	var y := float(p.oy)
	var vx := v * cos(rad)
	var vy := -v * sin(rad)
	var pts := PackedFloat64Array([x, y]) if keep else PackedFloat64Array()
	var best := INF
	var inside := false
	var end := LOST
	var hit_d := INF
	var tr := float(p.tr)
	var tx := float(p.tx)
	var ty0 := float(p.ty)
	var mv := int(p.move) != 0
	var amp := float(p.get("amp", 0.0))
	var per := float(p.get("per", 1.0))
	var zn: Variant = p.zone
	var zx := 0.0
	var zy := 0.0
	var zw := 0.0
	var zh := 0.0
	if zn != null:
		zx = float(zn.x)
		zy = float(zn.y)
		zw = float(zn.w)
		zh = float(zn.h)
	var n := steps if steps > 0 else MAXS
	for s in range(1, n + 1):
		var dx0 := m0x - x
		var dy0 := m0y - y
		var r0 := dx0 * dx0 + dy0 * dy0
		var dx1 := m1x - x
		var dy1 := m1y - y
		var r1 := dx1 * dx1 + dy1 * dy1
		var dx2 := m2x - x
		var dy2 := m2y - y
		var r2 := dx2 * dx2 + dy2 * dy2
		if r0 < m0r or r1 < m1r or r2 < m2r:
			end = CRASH
			break
		var f0 := m0g / (r0 * sqrt(r0))
		var f1 := m1g / (r1 * sqrt(r1))
		var f2 := m2g / (r2 * sqrt(r2))
		var ax := 0.0 + f0 * dx0 + f1 * dx1 + f2 * dx2
		var ay := 0.0 + f0 * dy0 + f1 * dy1 + f2 * dy2
		vx += ax * DT
		vy += ay * DT
		x += vx * DT
		y += vy * DT
		if keep and s % 2 == 0:
			pts.append(x)
			pts.append(y)
		if steps > 0:
			continue
		var ty := ty0 + amp * sin(2.0 * PI * (s * DT) / per) if mv else ty0
		var ex := x - tx
		var ey := y - ty
		var lim := maxf(best, tr) * 1.000001
		if not inside and ex * ex + ey * ey > lim * lim:
			if zn == null and x >= -60.0 and x <= FW + 60.0 and y >= -60.0 and y <= FH + 60.0:
				continue
		var d := hyp(ex, ey)
		if d < best:
			best = d
		if d < tr:
			inside = true
			if d < hit_d:
				hit_d = d
			else:
				end = HIT
				break
		elif inside:
			end = HIT
			break
		if zn != null and x > zx and x < zx + zw and y > zy and y < zy + zh:
			end = ZONE
			break
		if x < -60.0 or x > FW + 60.0 or y < -60.0 or y > FH + 60.0:
			break
	if keep and (pts[pts.size() - 2] != x or pts[pts.size() - 1] != y):
		pts.append(x)
		pts.append(y)
	var out: Dictionary[String, Variant] = {}
	out.assign({pts = pts, end = end, best = best, hitD = hit_d})
	return out


## Where the target is `tt` seconds of flight in (`tpos`); it moves only up and down.
static func target_y(p: Dictionary, tt: float) -> float:
	if int(p.move) != 0:
		return float(p.ty) + float(p.amp) * sin(2.0 * PI * tt / float(p.per))
	return float(p.ty)


static func aim_at(p: Dictionary) -> int:
	return MiniPix.jr(atan2(float(p.oy) - float(p.ty), float(p.tx) - float(p.ox)) * 180.0 / PI)


## The masses for one attempt; false when one could not be placed (`gen`'s inner loop).
static func _place(p: Dictionary, c: Dictionary, r: RandomNumberGenerator) -> bool:
	for k in int(c.masses):
		var placed := false
		var t := 0
		while t < 60 and not placed:
			t += 1
			var rr := 22.0 + r.randf() * 22.0
			var mx := 260.0 + r.randf() * 470.0
			var my := 70.0 + r.randf() * 500.0
			var m := {x = mx, y = my, r = rr, gm = K * rr * rr}
			if hyp(mx - float(p.ox), my - float(p.oy)) < rr + 120.0 \
					or hyp(mx - float(p.tx), my - float(p.ty)) < rr + (float(p.amp) if int(p.move) else 0.0) + 110.0:
				continue
			if (p.masses as Array).any(func(o: Dictionary) -> bool: return hyp(float(o.x) - mx, float(o.y) - my) < float(o.r) + rr + 70.0):
				continue
			(p.masses as Array).append(m)
			placed = true
		if not placed:
			return false
	return true


## At least one mass sits near the straight line, so the sling matters.
static func _on_line(p: Dictionary) -> bool:
	var ox := float(p.ox)
	var oy := float(p.oy)
	var lx := float(p.tx) - ox
	var ly := float(p.ty) - oy
	var ll := hyp(lx, ly)
	for m: Dictionary in p.masses:
		var u := ((float(m.x) - ox) * lx + (float(m.y) - oy) * ly) / (ll * ll)
		var qx := ox + u * lx
		var qy := oy + u * ly
		if u > 0.15 and u < 0.85 and hyp(float(m.x) - qx, float(m.y) - qy) < float(m.r) + 90.0:
			return true
	return false


## The control space scanned into `good` (the [a, p] that land inside half the ring); the hits, or
## -1 once over 6% of shots hit (the deal is dropped). The page scans it all; this stops early.
static func _scan(p: Dictionary, good: Array) -> int:
	var hits := 0
	var half := float(p.tr) * 0.5
	for a in range(-76, 77, 2):
		for pw in range(10, 101, 3):
			var res := sim(p, a, pw, 0, false)
			if int(res.end) == HIT:
				hits += 1
				if float(res.hitD) < half:
					good.append([a, pw])
				if hits >= 144:
					return -1
	return hits


static func gen(d: int, r: RandomNumberGenerator) -> Dictionary[String, Variant]:
	var c: Dictionary = CFG[clampi(d, 1, 5)]
	for att in 400:
		var p: Dictionary[String, Variant] = {}
		var oy := 120.0 + r.randf() * 400.0
		var tx := 900.0 + r.randf() * 40.0
		var ty := 110.0 + r.randf() * 420.0
		p.assign({ox = 60.0, oy = oy, tx = tx, ty = ty, tr = float(c.tr), masses = [], move = int(c.move), zone = null})
		if int(c.move):
			p.amp = 60.0 + r.randf() * 40.0
			p.per = 260.0 + r.randf() * 160.0
			p.ty = maxf(float(p.amp) + float(p.tr) + 20.0, minf(FH - float(p.amp) - float(p.tr) - 20.0, ty))
		if not _place(p, c, r) or not _on_line(p):
			continue
		if int(c.zone):
			var zw := 110.0
			var zh := 150.0
			var z := {x = 380.0 + r.randf() * 220.0, y = 60.0 + r.randf() * (FH - zh - 120.0), w = zw, h = zh}
			p.zone = z
			if (p.masses as Array).any(func(m: Dictionary) -> bool:
					return float(m.x) > float(z.x) - float(m.r) and float(m.x) < float(z.x) + zw + float(m.r) \
						and float(m.y) > float(z.y) - float(m.r) and float(m.y) < float(z.y) + zh + float(m.r)):
				continue
		var a0 := aim_at(p)
		if int(sim(p, a0, 50, 0, false).end) == HIT:
			continue
		var good: Array = []
		var hits := _scan(p, good)
		if hits < 0 or good.size() < 2:
			continue
		p.sol = good[int(floorf(r.randf() * good.size()))]
		p.frac = hits / 2387.0
		p.a0 = a0
		return p
	return {}


static func score_hit(k: int, d: float, tr: float) -> float:
	return clampf(1.0 - 0.12 * (k - 1), 0.0, 1.0) * (0.78 + 0.22 * (1.0 - clampf(d / tr, 0.0, 1.0)))


static func score_miss(best: float, tr: float) -> float:
	return 0.2 * clampf(1.0 - best / (5.0 * tr), 0.0, 1.0)


# ---------------------------------------------------------------- drawing helpers

static func S(v: float) -> float:
	return v * SC


## The prototype's `line`: Bresenham between rounded ends, `dash` [every, on] counted along it.
static func line(c: MiniPix, x0: float, y0: float, x1: float, y1: float, col: Color, dash := Vector2i.ZERO) -> void:
	var ax := MiniPix.jr(x0)
	var ay := MiniPix.jr(y0)
	var bx := MiniPix.jr(x1)
	var by := MiniPix.jr(y1)
	var dx := absi(bx - ax)
	var dy := -absi(by - ay)
	var sx := 1 if ax < bx else -1
	var sy := 1 if ay < by else -1
	var e := dx + dy
	var n := 0
	while true:
		if dash.x == 0 or n % dash.x < dash.y:
			c.dot(ax, ay, col)
		n += 1
		if ax == bx and ay == by:
			break
		var e2 := 2 * e
		if e2 >= dy:
			e += dy
			ax += sx
		if e2 <= dx:
			e += dx
			ay += sy


## `ringPx`: a ring of dots, every `every`th of them when set.
static func ring(c: MiniPix, cx: float, cy: float, r: float, col: Color, every := 0) -> void:
	var n := maxi(8, MiniPix.jr(r * 7.0))
	var seen := {}
	for k in n:
		if every and k % every:
			continue
		var a := float(k) / n * 2.0 * PI
		var x := MiniPix.jr(cx + r * cos(a))
		var y := MiniPix.jr(cy + r * sin(a))
		var key := x * 999 + y
		if seen.has(key):
			continue
		seen[key] = true
		c.dot(x, y, col)


## `poly` over flat points from index `i0` to `i1` (inclusive; -1 is the last).
static func poly(c: MiniPix, pts: PackedFloat64Array, col: Color, dash := Vector2i.ZERO, i0 := 0, i1 := -1) -> void:
	if i1 < 0:
		i1 = pts.size() / 2 - 1
	for i in range(i0 + 1, i1 + 1):
		line(c, pts[2 * i - 2], pts[2 * i - 1], pts[2 * i], pts[2 * i + 1], col, dash)


## The flight's points on the canvas (`pl`).
static func to_canvas(pts: PackedFloat64Array) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	out.resize(pts.size())
	for i in pts.size():
		out[i] = pts[i] * SC
	return out


## The star field's generator: `(hs * 1103515245 + 12345) & 0x7fffffff`, its double product kept.
static func _lcg(hs: int) -> int:
	var m := fmod(float(hs) * 1103515245.0 + 12345.0, 4294967296.0)
	return int(m) & 0x7fffffff


# ---------------------------------------------------------------- the nav plot, drawn once

func _draw_bg() -> Image:
	var b := MiniPix.new(W, FY)
	b.rect(0, 0, W, FY, MiniPix.VOID)
	var hs := int(floorf(float(P.oy) * 977.0 + float(P.ty) * 131.0)) | 1
	for k in 70:
		hs = _lcg(hs)
		var q := float(hs) / 0x7fffffff
		hs = _lcg(hs)
		var x := float(hs) / 0x7fffffff * W
		hs = _lcg(hs)
		var y := float(hs) / 0x7fffffff * FY
		b.dotf(x, y, MiniPix.HOT if q > 0.92 else (MiniPix.CHILL if q > 0.6 else MiniPix.COLD))
	for x in range(0, W, 12):
		for y in range(0, FY, 12):
			b.dot(x, y, MiniPix.LINE)
	var ms: Array = P.masses
	var star_i := 0
	for i in ms.size():
		if float(ms[i].r) > float(ms[star_i].r):
			star_i = i
	var plan: Array = [[MiniPix.ICE, MiniPix.CHILL, MiniPix.COLD], [MiniPix.HOT, MiniPix.THEM, MiniPix.shade(MiniPix.THEM, -0.45)],
		[MiniPix.shade(MiniPix.GOOD, 0.4), MiniPix.GOOD, MiniPix.shade(MiniPix.GOOD, -0.45)]]
	var pk := 0
	for i in ms.size():
		var m: Dictionary = ms[i]
		var cx := S(float(m.x))
		var cy := S(float(m.y))
		var r := S(float(m.r))
		for f: float in [4.2, 2.9, 1.9]:
			ring(b, cx, cy, r * f, MiniPix.shade(MiniPix.EMBER, -0.55) if i == star_i else MiniPix.LINE, 3)
		if i == star_i:
			_star(b, cx, cy, r)
		else:
			_planet(b, cx, cy, r, plan[pk % 3])
			pk += 1
			if pk % 3 == 2:
				_rings(b, cx, cy, r)
	_zone(b)
	if int(P.move):
		line(b, S(float(P.tx)), S(float(P.ty) - float(P.amp)), S(float(P.tx)), S(float(P.ty) + float(P.amp)), MiniPix.shade(MiniPix.GOOD, -0.5), Vector2i(3, 1))
	ring(b, S(float(P.ox)), S(float(P.oy)), 3.2, MiniPix.BEVEL_HI)
	return b.img


## The no-fly zone: a dashed red edge round a sparse hatch.
func _zone(b: MiniPix) -> void:
	if P.zone == null:
		return
	var z: Dictionary = P.zone
	var x0 := MiniPix.jr(S(float(z.x)))
	var y0 := MiniPix.jr(S(float(z.y)))
	var zw := MiniPix.jr(S(float(z.w)))
	var zh := MiniPix.jr(S(float(z.h)))
	var dim := MiniPix.shade(MiniPix.BAD, -0.45)
	for y in zh:
		for x in zw:
			var e := x == 0 or y == 0 or x == zw - 1 or y == zh - 1
			if ((x + y) % 4 < 2) if e else ((x + y) % 5 == 0):
				b.dot(x0 + x, y0 + y, MiniPix.BAD if e else dim)


func _star(b: MiniPix, cx: float, cy: float, r: float) -> void:
	var rr := ceili(r * 3.4)
	var fx_ := fmod(cx, 1.0)
	var fy_ := fmod(cy, 1.0)
	var deep := MiniPix.shade(MiniPix.EMBER, -0.4)
	for y in range(-rr, rr + 1):
		for x in range(-rr, rr + 1):
			var d := hyp(x + 0.5 - fx_, y + 0.5 - fy_)
			var X := int(floorf(cx)) + x
			var Y := int(floorf(cy)) + y
			if d <= r:
				var l := hyp(x + r * 0.35, y + r * 0.35) / r
				b.dot(X, Y, SUN if l < 0.45 else (MiniPix.HOT if l < 0.85 else (MiniPix.FLARE if l < 1.15 else MiniPix.EMBER)))
			else:
				var t_ := (d - r) / (r * 2.4)
				if t_ < 1.0:
					var dens := pow(1.0 - t_, 2.2) * 0.85
					if MiniPix.bay(X, Y) < dens:
						b.dot(X, Y, MiniPix.FLARE if t_ < 0.35 else (MiniPix.EMBER if t_ < 0.7 else deep))
	var dim := MiniPix.shade(MiniPix.FLARE, -0.4)
	for k in range(1, MiniPix.jr(r * 2.6)):
		var a := dim if k > r * 1.6 else MiniPix.FLARE
		if k % 2:
			continue
		b.dotf(cx + k, cy, a)
		b.dotf(cx - k, cy, a)
		b.dotf(cx, cy + k, a)
		b.dotf(cx, cy - k, a)


func _planet(b: MiniPix, cx: float, cy: float, r: float, pal: Array) -> void:
	var rr := ceili(r * 3.4)
	var atmo := MiniPix.shade(pal[1], -0.35)
	for y in range(-rr, rr + 1):
		for x in range(-rr, rr + 1):
			var fx_ := x + 0.5 - fmod(cx, 1.0)
			var fy_ := y + 0.5 - fmod(cy, 1.0)
			var d := hyp(fx_, fy_)
			var X := int(floorf(cx)) + x
			var Y := int(floorf(cy)) + y
			if d <= r - 0.6:
				var lt := (-fx_ * 0.7 - fy_ * 0.7) / r
				var band := int(floorf((fy_ + r) / maxf(1.5, r * 0.4))) & 1
				var col: Color = pal[0] if lt > 0.35 else (pal[1] if lt > -0.25 else pal[2])
				if lt > -0.25 and lt <= 0.35 and band and MiniPix.bay(X, Y) < 0.5:
					col = pal[0] if lt > 0.0 else pal[2]
				if lt < -0.55:
					col = MiniPix.BEVEL_LO if MiniPix.bay(X, Y) < 0.6 else pal[2]
				b.dot(X, Y, col)
			elif d <= r + 0.4:
				b.dot(X, Y, MiniPix.BEVEL_LO)
			elif d <= r + 1.4 and MiniPix.bay(X, Y) < 0.35:
				b.dot(X, Y, atmo)


func _rings(b: MiniPix, cx: float, cy: float, r: float) -> void:
	for k in 40:
		var a := float(k) / 40 * 2.0 * PI
		var x := cx + cos(a) * r * 1.9
		var y := cy + sin(a) * r * 0.45 - cos(a) * r * 0.35
		if sin(a) < 0.0 and hyp(x - cx, y - cy) < r:
			continue
		b.dotf(x, y, MiniPix.WARN)


## The control deck's plate: the dial face and its ticks, AIM, the fork, the rest line and scale.
func _draw_deck() -> Image:
	var d := MiniPix.new(W, H - FY)
	d.rect(0, 0, W, H - FY, MiniPix.PANEL)
	d.rect(0, 0, W, 1, MiniPix.BEVEL_HI)
	d.rect(0, 1, W, 1, MiniPix.BEVEL_LO)
	for y in range(-DRAD - 1, DRAD + 2):
		for x in range(-DRAD - 1, DRAD + 2):
			var r := hyp(x, y)
			var X := DX + x
			var Y := DY - FY + y
			if r <= DRAD - 0.5:
				var lt := float(-x - y) / DRAD
				d.dot(X, Y, (MiniPix.BEVEL_HI if lt > 0.2 else (MiniPix.BEVEL_LO if lt < -0.3 else MiniPix.LINE)) if r > DRAD - 2.5 else MiniPix.VOID)
			elif r <= DRAD + 0.5:
				d.dot(X, Y, MiniPix.BEVEL_LO)
	for a in range(AMIN, AMAX + 1, 20):
		var rad := a * PI / 180.0
		d.dotf(DX + (DRAD - 3) * cos(rad), DY - FY - (DRAD - 3) * sin(rad), MiniPix.ICE if a == 0 else MiniPix.COLD)
	d.text("AIM", 33, 4, MiniPix.COLD)
	line(d, FKX + 3, 30, FKX + 3, 19, MiniPix.BEVEL_LO)
	line(d, FKX + 4, 30, FKX + 4, 19, MiniPix.COLD)
	line(d, FKX + 3, 19, FKX, 9, MiniPix.COLD)
	line(d, FKX + 4, 19, FKX + 1, 9, MiniPix.CHILL)
	line(d, FKX + 3, 19, FKX, 26, MiniPix.COLD)
	line(d, FKX + 4, 19, FKX + 1, 26, MiniPix.BEVEL_LO)
	for x in range(128 - PULLMAX, 124, 3):
		d.dot(x, RY - FY, MiniPix.LINE)
	for k in 10:
		var x := MiniPix.jr(128 - 14 - k * (PULLMAX - 14) / 9.0)
		d.dot(x, 29, MiniPix.CHILL if k % 5 == 0 else MiniPix.LINE)
		if k % 5 == 0:
			d.dot(x, 28, MiniPix.CHILL)
	return d.img


# ---------------------------------------------------------------- the game

func _mount() -> void:
	px = MiniPix.new(W, H)
	P = _deal()
	if P.is_empty():
		push_error("GameSling: no puzzle at depth %d" % depth)
		over = true
		done(0.0, "No puzzle")
		return
	var c: Dictionary = CFG[depth]
	max_shots = int(c.shots) + (1 if sensors >= 2 else 0) + (1 if sensors >= 4 else 0)
	_stub_steps = sensors * 32
	ang = int(P.a0)
	_bg = _draw_bg()
	_deck = _draw_deck()
	restub()
	_draw()


## A deal made on a worker while the desk's card is up; the mount that asks for it waits out the rest.
static func prefetch(d: int, r: RandomNumberGenerator) -> void:
	settle()
	if not memo_on:
		memo.clear()
	_pre_key = "%d:%d:%d" % [d, r.seed, r.state]
	_pre_task = WorkerThreadPool.add_task(func() -> void:
		var got := gen(d, r)
		GameSling._pre_got = {P = got, end = r.state})


## Waits for the worker's deal, if one is out, and files it under its key.
static func settle() -> void:
	if _pre_task < 0:
		return
	WorkerThreadPool.wait_for_task_completion(_pre_task)
	_pre_task = -1
	memo[_pre_key] = _pre_got
	_pre_got = {}


## `gen`, or the deal already made for this stream, the stream left where the deal left it.
func _deal() -> Dictionary[String, Variant]:
	var key := "%d:%d:%d" % [depth, rng.seed, rng.state]
	if key == _pre_key:
		settle()
	var got: Dictionary[String, Variant] = {}
	if memo.has(key):
		var m: Dictionary = memo[key]
		if not memo_on:
			memo.erase(key)
		rng.state = int(m.end)
		got.assign(Dictionary(m.P).duplicate(true))
		return got
	got = gen(depth, rng)
	if memo_on:
		memo[key] = {P = got.duplicate(true), end = rng.state}
	return got


func pow_now() -> int:
	return pow_ if pow_ > 0 else (last_pow if last_pow > 0 else 50)


static func off_of(pw: int) -> float:
	return 0.0 if pw <= 0 else 14.0 + float(pw - PMIN) / (PMAX - PMIN) * (PULLMAX - 14)


func restub() -> void:
	_stub = to_canvas(sim(P, ang, pow_now(), _stub_steps).pts) if _stub_steps and not over else PackedFloat64Array()


func _draw() -> void:
	px.img.blit_rect(_bg, Rect2i(0, 0, W, FY), Vector2i.ZERO)
	_draw_field()
	_draw_hud()
	px.img.blit_rect(_deck, Rect2i(0, 0, W, H - FY), Vector2i(0, FY))
	_draw_controls()
	dirty = true


## The target, old paths, the stub, the aim line or the probe in flight, and the hit's rings.
func _draw_field() -> void:
	var tt := int(flying.k) * 2 * DT if not flying.is_empty() else 0.0
	var TX := S(float(P.tx))
	var TY := S(target_y(P, tt))
	var TR := S(float(P.tr))
	ring(px, TX, TY, TR, MiniPix.GOOD)
	ring(px, TX, TY, TR * 0.5, MiniPix.MARK if int(floorf(clock * 2.0)) % 2 else MiniPix.shade(MiniPix.GOOD, -0.4))
	px.rect(MiniPix.jr(TX) - 1, MiniPix.jr(TY), 3, 1, MiniPix.MARK)
	px.rect(MiniPix.jr(TX), MiniPix.jr(TY) - 1, 1, 3, MiniPix.MARK)
	if _old_layer != null:
		px.img.blend_rect(_old_layer, Rect2i(0, 0, W, H), Vector2i.ZERO)
	if not _stub.is_empty() and flying.is_empty():
		poly(px, _stub, MiniPix.EMBER, Vector2i(3, 2))
	var a := ang * PI / 180.0
	var OX := S(float(P.ox))
	var OY := S(float(P.oy))
	if flying.is_empty() and not over:
		var L := 5.0 + pow_now() * 0.12
		line(px, OX, OY, OX + L * cos(a), OY - L * sin(a), MiniPix.EMBER, Vector2i(2, 1))
		px.rect(MiniPix.jr(OX) - 1, MiniPix.jr(OY) - 1, 2, 2, MiniPix.ICE)
	if not flying.is_empty():
		var pts: PackedFloat64Array = flying.pts
		var k := int(flying.k)
		poly(px, pts, MiniPix.HOT, Vector2i.ZERO, maxi(0, k - 400), k)
		var k0 := maxi(0, k - 3)
		var qx := pts[2 * k]
		var qy := pts[2 * k + 1]
		var hx := qx - pts[2 * k0]
		var hy := qy - pts[2 * k0 + 1]
		var hl := hyp(hx, hy)
		if hl == 0.0:
			hl = 1.0
		if fmod(clock * 30.0, 2.0) < 1.2:
			px.dotf(qx - hx / hl * 2.0, qy - hy / hl * 2.0, MiniPix.FLARE)
		px.rect(MiniPix.jr(qx) - 1, MiniPix.jr(qy) - 1, 2, 2, MiniPix.ICE)
		px.dotf(qx + hx / hl * 1.5, qy + hy / hl * 1.5, MiniPix.EMBER)
	if not fx.is_empty():
		var t_ := (clock - float(fx.t0)) / 0.7
		if t_ >= 1.0:
			fx = {}
		else:
			ring(px, float(fx.x), float(fx.y), 2.0 + t_ * 10.0, fx.c, 2 if t_ > 0.5 else 0)
			if t_ < 0.5:
				ring(px, float(fx.x), float(fx.y), 1.0 + t_ * 5.0, MiniPix.HOT, 2)


func _draw_hud() -> void:
	px.text("LAUNCH %d" % (max_shots - used), 2, 2, MiniPix.CHILL)
	if miss_txt != "":
		var col := MiniPix.GOOD if miss_txt == "HIT" else (MiniPix.BAD if miss_txt == "IMPACT" or miss_txt == "NO-FLY" else MiniPix.HOT)
		px.text(miss_txt, W - 2, 2, col, "right")
	if note != "" and clock < note_t:
		px.text(note, W / 2, FY - 7, MiniPix.HOT, "center")
	elif not started:
		px.start_card("HIT THE TARGET", controls(), W / 2.0, FY - 30, clock, MiniPix.VOID, MiniPix.BEVEL_HI)
	px.rect(0, FY - 1, W, 1, MiniPix.BEVEL_LO)


## The dial's knob and needle, the angle, the sling's pouch and bands, the power, the dimmer.
func _draw_controls() -> void:
	var dim := over or not flying.is_empty()
	var a := ang * PI / 180.0
	var nx := DX + (DRAD - 5) * cos(a)
	var ny := DY - (DRAD - 5) * sin(a)
	for y in range(-6, 7):
		for x in range(-6, 7):
			var r := hyp(x, y)
			if r > 6.4:
				continue
			var lt := float(-x - y) / 6.0
			px.dot(DX + x, DY + y, MiniPix.BEVEL_LO if r > 5.4 else (MiniPix.CHILL if lt > 0.45 else (MiniPix.COLD if lt > -0.2 else MiniPix.LINE)))
	line(px, DX, DY, nx, ny, MiniPix.COLD if dim else MiniPix.EMBER)
	line(px, DX + cos(a) * 6.0, DY - sin(a) * 6.0, DX + (DRAD - 1) * cos(a), DY - (DRAD - 1) * sin(a), MiniPix.COLD if dim else MiniPix.FLARE)
	px.dot(DX, DY, MiniPix.HOT)
	px.text(("+" if ang > 0 else ("-" if ang < 0 else "")) + str(absi(ang)), 33, FY + 12, MiniPix.HOT)
	var sh := float(twang.wob) if not twang.is_empty() else 0.0
	var PX := MiniPix.jr(128 - off)
	var PY := MiniPix.jr(RY + sh)
	var t_ := minf(1.0, off / PULLMAX)
	var band := MiniPix.THEM if t_ < 0.35 else (MiniPix.EMBER if t_ < 0.75 else MiniPix.BAD)
	line(px, FKX, FY + 9, PX - 1, PY - 2, band)
	line(px, FKX, FY + 26, PX - 1, PY + 2, band)
	px.rect(PX - 3, PY - 4, 5, 9, MiniPix.BEVEL_LO)
	px.rect(PX - 2, PY - 3, 3, 7, MiniPix.shade(MiniPix.THEM, -0.4))
	px.rect(PX, PY - 1, 2, 2, MiniPix.ICE)
	px.dot(PX + 2, PY, MiniPix.EMBER)
	if last_pow > 0:
		var lx := MiniPix.jr(128 - off_of(last_pow))
		px.rect(lx - 1, FY + 26, 3, 1, MiniPix.TIERS[2])
		px.dot(lx, FY + 25, MiniPix.TIERS[2])
	var shown := pow_ if pow_ > 0 else 0
	var label := "PWR %d" % shown if shown else ("LAST %d" % last_pow if last_pow > 0 else "PWR")
	px.text(label, W - 14, FY + 4, MiniPix.HOT if shown else MiniPix.COLD, "right")
	if pull.is_empty() and not dim and last_pow < 0 and used == 0 and int(floorf(clock * 1.5)) % 2:
		px.text("<", PX - 8, PY - 2, MiniPix.EMBER)
	if dim:
		if _shade == null:
			_shade = Image.create(W, H - FY - 2, false, Image.FORMAT_RGBA8)
			_shade.fill(Color(MiniPix.VOID, 0.35))
		px.img.blend_rect(_shade, Rect2i(0, 0, W, H - FY - 2), Vector2i(0, FY + 2))


func _draw_old() -> void:
	var o := MiniPix.new(W, H)
	o.clear(Color(0, 0, 0, 0))
	for i in old.size():
		poly(o, old[i].pts, MiniPix.GOOD if old[i].hit else (MiniPix.COLD if i == old.size() - 1 else MiniPix.LINE))
	_old_layer = o.img


func _tick(dt: float) -> void:
	_acc += dt
	if _acc < 0.032:
		return
	var step := minf(0.1, _acc)
	_acc = 0.0
	clock += step
	if not twang.is_empty():
		_twang(step)
	if not flying.is_empty():
		var last := (flying.pts as PackedFloat64Array).size() / 2 - 1
		flying.k = mini(last, int(flying.k) + maxi(1, MiniPix.jr(260.0 * step)))
		if int(flying.k) >= last:
			land(flying)
	if drawing:
		_draw()


## The sling springing back after a release, then wobbling still.
func _twang(dt: float) -> void:
	twang.t = float(twang.t) + dt
	var k := float(twang.t)
	var from := float(twang.from)
	if k < 0.06:
		off = from * (1.0 - k / 0.06)
		twang.wob = 0.0
	else:
		var q := k - 0.06
		var amp := minf(5.0, from * 0.08) * exp(-q * 6.0)
		off = maxf(0.0, -amp * sin(q * 36.0))
		twang.wob = amp * sin(q * 44.0) * 0.6
		if q > 0.8:
			twang = {}
			off = 0.0


# ---------------------------------------------------------------- input

static func d_ang(q: Vector2) -> float:
	return atan2(DY - q.y, q.x - DX) * 180.0 / PI


func down(_p: Vector2i) -> void:
	if over or not flying.is_empty():
		return
	var q := pf
	if q.y < FY:
		return
	started = true
	if q.x < 31:
		dial = {last = d_ang(q), acc = float(ang)}
	elif q.x >= 52:
		pull = {x0 = float(q.x)}
		twang = {}


func move(_p: Vector2i) -> void:
	var q := pf
	if not dial.is_empty():
		var dd := d_ang(q) - float(dial.last)
		if dd > 180.0:
			dd -= 360.0
		if dd < -180.0:
			dd += 360.0
		dial.last = d_ang(q)
		dial.acc = clampf(float(dial.acc) + dd, AMIN, AMAX)
		var n := MiniPix.jr(float(dial.acc))
		if n != ang:
			ang = n
			restub()
	elif not pull.is_empty():
		off = clampf(float(pull.x0) - q.x, 0.0, PULLMAX)
		var np := 0 if off < 14.0 else MiniPix.jr(PMIN + (off - 14.0) / (PULLMAX - 14) * (PMAX - PMIN))
		if np != pow_:
			pow_ = np
			restub()


func up(_p: Vector2i, cancel := false) -> void:
	if not dial.is_empty():
		dial = {}
		return
	if pull.is_empty():
		return
	pull = {}
	var pw := pow_
	pow_ = 0
	twang = {t = 0.0, from = off, wob = 0.0}
	if cancel or pw < PMIN:
		if off > 3.0:
			note = "TOO WEAK"
			note_t = clock + 1.2
		restub()
		return
	sfx(&"launch")
	last_pow = pw
	launch(pw)


func wheel(dir: int) -> void:
	if over or not flying.is_empty():
		return
	var q := pf
	if q.y < FY or q.x >= 31:
		return
	ang = clampi(ang + (1 if dir > 0 else -1), AMIN, AMAX)
	restub()


func launch(pw: int) -> void:
	if over or not flying.is_empty():
		return
	used += 1
	var r := sim(P, ang, pw)
	flying = {r = r, pts = to_canvas(r.pts), k = 0}


func land(f: Dictionary) -> void:
	var r: Dictionary = f.r
	flying = {}
	var hit := int(r.end) == HIT
	old.append({pts = f.pts, hit = hit})
	while old.size() > 4:
		old.pop_front()
	_draw_old()
	var pts: PackedFloat64Array = f.pts
	var ex := pts[pts.size() - 2]
	var ey := pts[pts.size() - 1]
	var tr := float(P.tr)
	if hit:
		over = true
		miss_txt = "HIT"
		sfx(&"hit")
		sfx(&"win")
		fx = {x = ex, y = ey, c = MiniPix.GOOD, t0 = clock}
		done(score_hit(used, float(r.hitD), tr), "Hit on launch %d of %d, %d%% off centre" % [used, max_shots, MiniPix.jr(100.0 * float(r.hitD) / tr)])
		return
	if int(r.end) == CRASH:
		fx = {x = ex, y = ey, c = MiniPix.BAD, t0 = clock}
	var miss := MiniPix.jr(maxf(0.0, float(r.best) - tr))
	best_miss = minf(best_miss, float(r.best))
	miss_txt = "IMPACT" if int(r.end) == CRASH else ("NO-FLY" if int(r.end) == ZONE else "MISS %d" % miss)
	if used >= max_shots:
		over = true
		note = "OUT OF PROBES"
		note_t = clock + 99.0
		done(score_miss(best_miss, tr), "No hit in %d launches" % max_shots)
		return
	restub()


func give_up() -> void:
	if over:
		return
	over = true
	done(score_miss(best_miss, float(P.tr)) * 0.5 if used else 0.0, "Gave up")
