class_name TorchSim
extends RefCounted

## Cutting Torch's rules (the approved `wreck1.js`, shared by the game and its scripted player):
## the deal (a crate in a hull plate, live lines passing it at a gap, a clean loop round it) and
## the torch's simulation (contacts, scorches, closing a loop). Sim units are two to an art pixel.
## Why: docs/why/MiniGame.md#the-round-2-games

const W := 304.0
const H := 200.0
const SPEED := 34.0
const TR := 2.0
const SR := 1.5
const HITS_MAX := 3
const CFG := {
	1: {lines = 3, fuel = 0, gap = [22.0, 30.0], gas = 1.8, faint = 0, feed = 0},
	2: {lines = 4, fuel = 1, gap = [17.0, 25.0], gas = 1.65, faint = 0, feed = 0},
	3: {lines = 5, fuel = 2, gap = [14.0, 21.0], gas = 1.5, faint = 0, feed = 0},
	4: {lines = 5, fuel = 2, gap = [13.0, 19.0], gas = 1.45, faint = 2, feed = 0},
	5: {lines = 5, fuel = 2, gap = [12.0, 18.0], gas = 1.45, faint = 1, feed = 1},
}
const PULSE_PER := 2.6
const PULSE_LIVE := 1.5


static func rr(r: RandomNumberGenerator, a: float, b: float) -> float:
	return a + r.randf() * (b - a)


static func spline(p: Array[Vector2], n: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i in p.size() - 1:
		var p0 := p[maxi(0, i - 1)]
		var p1 := p[i]
		var p2 := p[i + 1]
		var p3 := p[mini(p.size() - 1, i + 2)]
		for k in n:
			var t := float(k) / n
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * (2.0 * p1 + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(p[p.size() - 1])
	return out


static func rect_dist(r: Rect2, x: float, y: float) -> float:
	var dx := maxf(maxf(r.position.x - x, 0.0), x - r.end.x)
	var dy := maxf(maxf(r.position.y - y, 0.0), y - r.end.y)
	return Vector2(dx, dy).length()


static func seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var v := b - a
	var l := v.length_squared()
	var t := clampf((p - a).dot(v) / l, 0.0, 1.0) if l else 0.0
	return (p - a - v * t).length()


static func poly_dist(pts: Array[Vector2], x: float, y: float) -> float:
	var d := INF
	var p := Vector2(x, y)
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		if absf(a.x - x) > d + 12.0 and absf(b.x - x) > d + 12.0:
			continue
		var e := seg_dist(p, a, b)
		if e < d:
			d = e
	return d


static func live(l: Dictionary, t: float) -> bool:
	return not l.pulse or fmod(t + float(l.phase), PULSE_PER) < PULSE_LIVE


## A line passing one side of the crate at gap `g`, edge to edge.
static func make_line(r: Rect2, side: int, g: float, half: float, rng: RandomNumberGenerator) -> Array[Vector2]:
	var pass_: Vector2
	match side:
		0:
			pass_ = Vector2(rr(rng, r.position.x + 6, r.end.x - 6), r.position.y - g - half)
		1:
			pass_ = Vector2(rr(rng, r.position.x + 6, r.end.x - 6), r.end.y + g + half)
		2:
			pass_ = Vector2(r.position.x - g - half, rr(rng, r.position.y + 6, r.end.y - 6))
		_:
			pass_ = Vector2(r.end.x + g + half, rr(rng, r.position.y + 6, r.end.y - 6))
	var a: Vector2
	var b: Vector2
	if side < 2:
		a = Vector2(-12, clampf(pass_.y + rr(rng, -60, 60), 6, H - 6)) if rng.randf() < 0.75 else Vector2(rr(rng, 10, pass_.x - 30), -12.0 if side == 0 else H + 12)
		b = Vector2(W + 12, clampf(pass_.y + rr(rng, -60, 60), 6, H - 6)) if rng.randf() < 0.75 else Vector2(rr(rng, pass_.x + 30, W - 10), -12.0 if side == 0 else H + 12)
	else:
		a = Vector2(clampf(pass_.x + rr(rng, -55, 55), 6, W - 6), -12) if rng.randf() < 0.75 else Vector2(-12.0 if side == 2 else W + 12, rr(rng, 10, pass_.y - 30))
		b = Vector2(clampf(pass_.x + rr(rng, -55, 55), 6, W - 6), H + 12) if rng.randf() < 0.75 else Vector2(-12.0 if side == 2 else W + 12, rr(rng, pass_.y + 30, H - 10))
	var m1 := Vector2((a.x + pass_.x) / 2.0 + rr(rng, -14, 14), (a.y + pass_.y) / 2.0 + rr(rng, -14, 14))
	var m2 := Vector2((b.x + pass_.x) / 2.0 + rr(rng, -14, 14), (b.y + pass_.y) / 2.0 + rr(rng, -14, 14))
	return spline([a, m1, pass_, m2, b], 14)


static func gap_of(r: Rect2, l: Dictionary) -> float:
	var g := INF
	for p: Vector2 in l.pts:
		g = minf(g, rect_dist(r, p.x, p.y) - float(l.half))
	return g


## Near the crate, two lines must not touch or run on top of each other.
static func clashes(r: Rect2, a: Dictionary, b: Dictionary) -> bool:
	for p: Vector2 in a.pts:
		if rect_dist(r, p.x, p.y) > 55.0:
			continue
		for q: Vector2 in b.pts:
			if rect_dist(r, q.x, q.y) > 55.0:
				continue
			if (p - q).length() < float(a.half) + float(b.half) + 6.0:
				return true
	return false


static func order(nn: int, r: RandomNumberGenerator) -> Array[int]:
	var a: Array[int] = []
	for i in nn:
		a.append(i)
	for i in range(nn - 1, 0, -1):
		var j := int(r.randf() * (i + 1))
		var tmp := a[i]
		a[i] = a[j]
		a[j] = tmp
	return a


## The crate's own power cable (sector 5), plugged into one side, crossed only while it is dark.
static func _feed(r: Rect2, rng: RandomNumberGenerator) -> Dictionary[String, Variant]:
	var side := int(rng.randf() * 4)
	var plug: Vector2
	var a: Vector2
	match side:
		0:
			plug = Vector2(rr(rng, r.position.x + 14, r.end.x - 14), r.position.y)
			a = Vector2(clampf(plug.x + rr(rng, -50, 50), 10, W - 10), -12)
		1:
			plug = Vector2(rr(rng, r.position.x + 14, r.end.x - 14), r.end.y)
			a = Vector2(clampf(plug.x + rr(rng, -50, 50), 10, W - 10), H + 12)
		2:
			plug = Vector2(r.position.x, rr(rng, r.position.y + 12, r.end.y - 12))
			a = Vector2(-12, clampf(plug.y + rr(rng, -40, 40), 10, H - 10))
		_:
			plug = Vector2(r.end.x, rr(rng, r.position.y + 12, r.end.y - 12))
			a = Vector2(W + 12, clampf(plug.y + rr(rng, -40, 40), 10, H - 10))
	var out_ := plug + Vector2([0, 0, -26, 26][side], [-26, 26, 0, 0][side])
	var mid := Vector2((a.x + out_.x) / 2.0 + rr(rng, -12, 12), (a.y + out_.y) / 2.0 + rr(rng, -12, 12))
	var out: Dictionary[String, Variant] = {}
	out.assign({kind = "power", half = 3.5, pts = spline([a, mid, out_, plug], 14), pulse = true, phase = rng.randf() * PULSE_PER, feed = true, side = side, faint = false})
	return out


## {R, lines (the feed last), o, gmin, ref, gas, loop}; {} if none came.
static func gen(d: int, sn: int, rng: RandomNumberGenerator) -> Dictionary[String, Variant]:
	var c: Dictionary = CFG[d]
	var gp: Array = c.gap
	var out: Dictionary[String, Variant] = {}
	for tries in 600:
		var cw := MiniPix.jr(rr(rng, 70, 90))
		var ch := MiniPix.jr(rr(rng, 46, 58))
		var x0 := MiniPix.jr(rr(rng, 52, W - 52 - cw))
		var y0 := MiniPix.jr(rr(rng, 48, H - 48 - ch))
		var r := Rect2(x0, y0, cw, ch)
		var lines: Array = []
		var feed: Dictionary = _feed(r, rng) if int(c.feed) else {}
		var kinds: Array[String] = []
		for i in int(c.lines):
			kinds.append("fuel" if i < int(c.fuel) else "power")
		var sides := order(4, rng)
		var att := 0
		while lines.size() < int(c.lines) and att < 160:
			att += 1
			var kind := kinds[lines.size()]
			var half := 4.5 if kind == "fuel" else 3.5
			var side := sides[lines.size() % 4]
			var g := rr(rng, gp[0], gp[1]) + (rr(rng, 8, 20) if lines.size() >= 4 else 0.0)
			var l := {kind = kind, half = half, pts = make_line(r, side, g, half, rng), pulse = false, phase = 0.0, faint = false}
			if gap_of(r, l) < float(gp[0]) - 0.01:
				continue
			if lines.any(func(m: Dictionary) -> bool: return clashes(r, l, m)):
				continue
			if not feed.is_empty() and clashes(r, l, feed):
				continue
			lines.append(l)
		if lines.size() < int(c.lines):
			continue
		var gmin := INF
		for l: Dictionary in lines:
			gmin = minf(gmin, gap_of(r, l))
		var o := maxf(4.0, minf(9.0, gmin / 2.0))
		var lp := loop_path(r, o, feed)
		var bad := false
		for p: Vector2 in lp.pts:
			for l: Dictionary in lines:
				if poly_dist(l.pts, p.x, p.y) < float(l.half) + TR + 1.5:
					bad = true
					break
			if bad:
				break
		if bad:
			continue
		for i in order(lines.size(), rng).slice(0, mini(int(c.faint), lines.size())):
			lines[i].faint = true
		if not feed.is_empty():
			lines.append(feed)
		out.assign({R = r, lines = lines, o = o, gmin = gmin, ref = lp.len, gas = float(lp.len) * (float(c.gas) + 0.1 * sn), loop = lp.pts})
		return out
	return out


## A rounded loop at offset o round the crate, every ~2 sim units, starting away from the feed.
static func loop_path(r: Rect2, o: float, feed: Dictionary) -> Dictionary[String, Variant]:
	var pts: Array[Vector2] = []
	var cx: Array[float] = [r.position.x, r.end.x, r.end.x, r.position.x]
	var cy: Array[float] = [r.position.y, r.position.y, r.end.y, r.end.y]
	var a0: Array[float] = [PI, 1.5 * PI, 0.0, 0.5 * PI]
	for k in 4:
		for j in 9:
			var a := a0[k] + j / 8.0 * PI / 2.0
			pts.append(Vector2(cx[k] + o * cos(a), cy[k] + o * sin(a)))
	pts.append(pts[0])
	var out: Array[Vector2] = [pts[0]]
	var ln := 0.0
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var b := pts[i]
		var d := (b - a).length()
		var nn := maxi(1, ceili(d / 2.0))
		for k in range(1, nn + 1):
			out.append(a + (b - a) * k / nn)
		ln += d
	out.pop_back()
	var start := int(floorf(out.size() * 0.1))
	if not feed.is_empty():
		var fp: Array = feed.pts
		var plug: Vector2 = fp[fp.size() - 1]
		var fd := -1.0
		for i in out.size():
			var d := (out[i] - plug).length()
			if d > fd:
				fd = d
				start = i
	var rot: Array[Vector2] = out.slice(start)
	rot.append_array(out.slice(0, start))
	var res: Dictionary[String, Variant] = {}
	res.assign({pts = rot, len = ln})
	return res


# ---------------------------------------------------------------- the torch

static func new_sim() -> Dictionary[String, Variant]:
	var out: Dictionary[String, Variant] = {}
	out.assign({t = 0.0, torch = null, pts = [], used = 0.0, hits = 0, scorch = 0, touch = {}, in_crate = false, over = false,
		freed = false, poly = [], pieces = [], events = [], near = INF})
	return out


## Where segment ab crosses cd (NAN when it does not).
static func seg_x(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> Vector2:
	var r1 := b.x - a.x
	var r2 := b.y - a.y
	var s1 := d.x - c.x
	var s2 := d.y - c.y
	var den := r1 * s2 - r2 * s1
	if absf(den) < 1e-9:
		return Vector2(NAN, NAN)
	var t := ((c.x - a.x) * s2 - (c.y - a.y) * s1) / den
	var u := ((c.x - a.x) * r2 - (c.y - a.y) * r1) / den
	if t > 0.0 and t <= 1.0 and u >= 0.0 and u <= 1.0:
		return Vector2(a.x + r1 * t, a.y + r2 * t)
	return Vector2(NAN, NAN)


static func in_poly(poly: Array, x: float, y: float) -> bool:
	var c := false
	var j := poly.size() - 1
	for i in poly.size():
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[j]
		if (a.y > y) != (b.y > y) and x < (b.x - a.x) * (y - a.y) / (b.y - a.y) + a.x:
			c = not c
		j = i
	return c


static func contact(s: Dictionary, p: Dictionary) -> void:
	var tp: Vector2 = s.torch
	var near := INF
	var lines: Array = p.lines
	for i in lines.size():
		var l: Dictionary = lines[i]
		var d := poly_dist(l.pts, tp.x, tp.y) - float(l.half)
		if d < near and live(l, s.t):
			near = d
		if d < TR:
			if not (s.touch as Dictionary).has(i) and live(l, s.t):
				s.touch[i] = true
				s.hits += 1
				(s.events as Array).append({type = "hit", kind = l.kind, x = tp.x, y = tp.y, i = i})
		else:
			(s.touch as Dictionary).erase(i)
	s.near = near
	var r: Rect2 = p.R
	var in_c := tp.x > r.position.x - SR and tp.x < r.end.x + SR and tp.y > r.position.y - SR and tp.y < r.end.y + SR
	if in_c and not s.in_crate:
		s.scorch += 1
		(s.events as Array).append({type = "scorch", x = tp.x, y = tp.y})
	s.in_crate = in_c
	if int(s.hits) >= HITS_MAX and not s.over:
		s.over = true
		(s.events as Array).append({type = "fail", why = "hits"})


static func pierce(s: Dictionary, p: Dictionary, x: float, y: float) -> void:
	if s.torch != null or s.over:
		return
	s.torch = Vector2(clampf(x, 2, W - 2), clampf(y, 2, H - 2))
	(s.pts as Array).append(Vector3(s.torch.x, s.torch.y, s.t))
	contact(s, p)


## Closing: the new segment crosses an old one, or comes back onto an old point.
static func add_point(s: Dictionary, p: Dictionary) -> void:
	var pts: Array = s.pts
	var n := pts.size()
	if n < 2:
		return
	var b3: Vector3 = pts[n - 1]
	var a3: Vector3 = pts[n - 2]
	var a := Vector2(a3.x, a3.y)
	var b := Vector2(b3.x, b3.y)
	for i in n - 10:
		var c3: Vector3 = pts[i]
		var d3: Vector3 = pts[i + 1]
		var c := Vector2(c3.x, c3.y)
		var hit := seg_x(a, b, c, Vector2(d3.x, d3.y))
		if is_nan(hit.x) and (b - c).length() < 2.2:
			hit = c
		if is_nan(hit.x):
			continue
		var poly: Array = [hit]
		for q: Vector3 in pts.slice(i + 1, n - 1):
			poly.append(Vector2(q.x, q.y))
		poly.append(hit)
		if poly.size() < 6:
			continue
		var r: Rect2 = p.R
		var corners: Array[Vector2] = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.get_center()]
		if corners.all(func(q: Vector2) -> bool: return in_poly(poly, q.x, q.y)):
			s.freed = true
			s.over = true
			s.poly = poly
			(s.events as Array).append({type = "freed"})
			return
		if not (s.pieces as Array).any(func(pc: Dictionary) -> bool: return int(pc.i) == i):
			(s.pieces as Array).append({i = i, poly = poly, t = s.t})
			(s.events as Array).append({type = "piece", poly = poly})
		return


static func step(s: Dictionary, p: Dictionary, tx: float, ty: float, dt: float) -> void:
	s.t += dt
	if s.torch == null or s.over:
		return
	var tp: Vector2 = s.torch
	tx = clampf(tx, 2, W - 2)
	ty = clampf(ty, 2, H - 2)
	var dx := tx - tp.x
	var dy := ty - tp.y
	var d := Vector2(dx, dy).length()
	var left := float(p.gas) - float(s.used)
	var m := minf(minf(d, SPEED * dt), left)
	if m > 1e-6:
		# sub-steps of at most 1 so thin lines can't be skipped
		var nn := ceili(m)
		var k := 0
		while k < nn and not s.over:
			var st := m / nn
			s.torch = Vector2(float(s.torch.x) + dx / d * st, float(s.torch.y) + dy / d * st)
			s.used += st
			var l: Vector3 = (s.pts as Array).back()
			if Vector2(s.torch.x - l.x, s.torch.y - l.y).length() >= 1.6:
				(s.pts as Array).append(Vector3(s.torch.x, s.torch.y, s.t))
				add_point(s, p)
			contact(s, p)
			k += 1
	else:
		contact(s, p)
	if not s.over and float(s.used) >= float(p.gas) - 1e-6:
		s.over = true
		(s.events as Array).append({type = "fail", why = "gas"})


static func score_of(s: Dictionary, p: Dictionary) -> float:
	if not s.freed:
		return 0.08 if int(s.hits) >= HITS_MAX else 0.12
	var waste := clampf((float(s.used) / float(p.ref) - 1.2) / maxf(0.1, float(p.gas) / float(p.ref) - 1.2), 0.0, 1.0)
	if int(s.scorch) >= 3:
		return 0.15
	return clampf(1.0 - 0.22 * int(s.hits) - 0.32 * int(s.scorch) - 0.3 * waste, 0.15, 1.0)
