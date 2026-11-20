class_name GameSeismic
extends MiniGame

## SEISMIC SCAN (Jon: loved, Nov 17): the ship's sensor map of a barren field. Tap a spot to scan it:
## a ring sweeps out and each buried find it passes pops up on the graph (lower is rarer, longer is
## nearer); every scan leaves a beacon; then dig. A port of the approved `seismic2.js`, rule for rule
## and pixel for pixel, in its approved layout (fit3, rings "B") and the UI kit (Nov 20).
## Why: docs/why/MiniGame.md#seismic-scan

const VAL: Array[int] = [1, 2, 4, 7, 11]
const TN: Array[String] = ["COMMON", "UNCOMMON", "RARE", "EPIC", "LEGENDARY"]
const TC: Array[Color] = [Color("#a3abb3"), Color("#4fbf82"), Color("#6a9ad4"), Color("#9a62e6"), Color("#d99b29")]
const CFG := {
	1: {"G": 8, "tiers": [0, 1, 2], "scans": 4, "range": 4.5},
	2: {"G": 9, "tiers": [0, 1, 2, 3], "scans": 5, "range": 4.5},
	3: {"G": 9, "tiers": [0, 1, 1, 2, 3], "scans": 5, "range": 4.5},
	4: {"G": 10, "tiers": [0, 1, 2, 3, 4], "scans": 6, "range": 4.5},
	5: {"G": 10, "tiers": [0, 1, 1, 2, 3, 4], "scans": 6, "range": 4.2},
}
const SOIL: Array[Color] = [Color("#140e08"), Color("#21180e"), Color("#2e2214"), Color("#3d2e1b"), Color("#4f3d25"),
	Color("#625031")]
const BLACK := Color("#000000")
const WHITE := Color("#ffffff")
const HOLE := Color("#050304")
const GEM: Array[String] = [".ooo.", "ohccl", "occcl", ".ocl.", "..o.."]
## The game area, as every game draws it (the UI kit, Nov 20).
const W := MiniKit.W
const H := MiniKit.H
const PY0 := MiniKit.PLAY_Y
const PH := MiniKit.DECK_N - MiniKit.PLAY_Y
## The right column: the two tools, then the graph down to row 137 (A, Nov 20: 16 rows taller, its
## five tier rows 14.2 px apart, not 11).
const CXL := MiniKit.W - MiniKit.GUT - 33
const CW := 33
const GY := 44
const GH := 94
const BL := CXL + 5
const BR := CXL + CW - 3
const T0 := GY + 8
const T1 := T0 + 71
const TOOLS: Array[String] = ["scan", "dig"]
const TB_Y: Array[int] = [12, 12 + MiniKit.BTN_H + MiniKit.GAP]
const NO_CELL := Vector2i(-1, -1)

## The deal, as the page names it: {deps [{x, y, t, got}], G, tiers, scans, digs, range, tol}.
var P: Dictionary[String, Variant] = {}
var G := 9
var CP := 12
var FW := 108
var FX := 2
var FY := 11
var rg := 4.5
var scans_left := 0
var digs_left := 0
var tool := "scan"
var over := false
var busy := false
var touched := false
## Each scan: {x, y, out: [{i, t, d}] nearest first}.
var scans: Array[Dictionary] = []
var holes: Array[Dictionary] = []
var gems: Array[Dictionary] = []
var parts: Array[Dictionary] = []
var close_t := 0.0
var sel := -1
var peek := -1
var hover_cell := NO_CELL
var hover_spike: Dictionary = {}
## The scan sweeping out: {p (its index), t0, dur, heard {out index: true}, flash [[out index, ms]], end}.
var sweep: Dictionary = {}
var drill: Dictionary = {}
var msg := ""
var end_ghost := false
var phase := 0
var _f: Field
var _hs := 1
var _base: Image
var _clip := Rect2i()
var _clipping := false
## The tier colours mixed as the page mixes them: [dim .35, dim .7, lit .25, gem hi, gem lo, gem ol, spike ol, spike hi].
var _tc: Array[PackedColorArray] = []


func id() -> StringName:
	return &"seismic"


func hint() -> String:
	return "Scan, then dig."


func controls() -> Array[String]:
	return ["click"]


# ---------------------------------------------------------------- the rules

static func cpof(g: int) -> int:
	return 110 / g


## V8's `Math.hypot` for two numbers (scaled by the larger), so a tie breaks as the page breaks it.
static func hyp(a: float, b: float) -> float:
	a = absf(a)
	b = absf(b)
	var m := maxf(a, b)
	if m == 0.0:
		return 0.0
	var p := a / m
	var q := b / m
	return sqrt(p * p + q * q) * m


static func params(d: int, s: int) -> Dictionary[String, Variant]:
	var c: Dictionary = CFG[d]
	var tiers: Array = (c.tiers as Array).duplicate()
	var out: Dictionary[String, Variant] = {}
	out.assign({"G": int(c.G), "tiers": tiers, "scans": int(c.scans) + int(s >= 1) + int(s >= 3) + int(s >= 5),
		"digs": tiers.size() + 1 + int(s >= 4), "range": float(c.range) + (1.0 if s >= 2 else 0.0),
		"tol": 0.6 / float(cpof(int(c.G)))})
	return out


## A field for `depth` and `sensors` from stream `r` that the screen-only solver digs out whole
## (the first that fails is kept as the fallback, as the page keeps it).
static func gen(r: RandomNumberGenerator, d: int, s: int) -> Dictionary[String, Variant]:
	var p := params(d, s)
	var g: int = p.G
	var mid := (g - 1) / 2.0
	var fallback: Dictionary[String, Variant] = {}
	for a in 400:
		var deps: Array[Dictionary] = []
		var ok := true
		for t: int in p.tiers:
			var placed := false
			for k in 80:
				var x := int(r.randf() * g)
				var y := int(r.randf() * g)
				if t >= 2 and hyp(x - mid, y - mid) < g * 0.22:
					continue # rare ones hide out from the middle
				var near := false
				for q in deps:
					if hyp(int(q.x) - x, int(q.y) - y) < 2.2:
						near = true
						break
				if near:
					continue
				deps.append({"x": x, "y": y, "t": t, "got": false})
				placed = true
				break
			if not placed:
				ok = false
				break
		if not ok:
			continue
		var out: Dictionary[String, Variant] = {"deps": deps}
		out.merge(p)
		if solve(out):
			return out
		if fallback.is_empty():
			fallback = out
	if not fallback.is_empty():
		fallback["unproven"] = true
	return fallback


## The page's `solver`: a player who only uses what the screen shows scans to cover the field, then
## to split the spots still in doubt, then digs the surest spot first. True when it digs out every find.
static func solve(S: Dictionary) -> bool:
	var f := Field.new(S)
	var g := f.g
	var all_t: Array = S.tiers
	var tiers: Array[int] = []
	for t: int in all_t:
		if not tiers.has(t):
			tiers.append(t)
	var scans_: Array[Dictionary] = []
	var cover := PackedByteArray()
	cover.resize(f.n)
	var at := PackedByteArray()
	at.resize(f.n)
	for k in int(S.scans):
		var best := _best_scan(f, scans_, cover, at, tiers, all_t)
		var bx := best % g
		var by := best / g
		scans_.append(f.scan_at(bx, by))
		at[best] = 1
		for i in f.n:
			if f.dist(i % g, i / g, bx, by) <= f.rg:
				cover[i] = 1
	return _dig_out(f, scans_, tiers, int(S.digs))


## The cell the solver scans next: the most uncovered cells in reach, plus the most distinct echoes it
## would split the doubtful spots into, a hair toward the middle.
static func _best_scan(f: Field, scans_: Array[Dictionary], cover: PackedByteArray, at: PackedByteArray,
		tiers: Array[int], all_t: Array) -> int:
	var g := f.g
	var mid := (g - 1) / 2.0
	var unc := PackedInt32Array()
	for i in f.n:
		if not cover[i]:
			unc.append(i)
	var amb: Array[PackedInt32Array] = []
	if not scans_.is_empty():
		for t in tiers:
			var c := f.candidates(scans_, t, PackedByteArray())
			if c.size() > all_t.count(t):
				amb.append(c)
	var seen := PackedInt32Array()
	seen.resize(512)
	var stamp := 0
	var best := -1
	var bv := -1e9
	for y in g:
		for x in g:
			if at[y * g + x]:
				continue
			var v := 0.0
			for i in unc:
				if f.dist(i % g, i / g, x, y) <= f.rg:
					v += 10.0
			for c in amb:
				stamp += 1
				var m := 0
				for i in c:
					var b := f.bkt[absi(i % g - x) * g + absi(i / g - y)] + 1
					if seen[b] != stamp:
						seen[b] = stamp
						m += 1
				v += m
			v -= hyp(x - mid, y - mid) * 0.01
			if v > bv:
				bv = v
				best = y * g + x
	return best


static func _dig_out(f: Field, scans_: Array[Dictionary], tiers: Array[int], digs: int) -> bool:
	var nd := f.ft.size()
	var ruled := PackedByteArray()
	ruled.resize(f.n)
	var got := PackedByteArray()
	got.resize(nd)
	var got_n := 0
	var desc := tiers.duplicate()
	desc.sort()
	desc.reverse()
	while digs > 0 and got_n < nd:
		var pc := PackedInt32Array()
		var pneed := 0
		for t: int in desc:
			var need := 0
			for i in nd:
				if f.ft[i] == t and not got[i]:
					need += 1
			if need == 0:
				continue
			var c := f.candidates(scans_, t, ruled)
			if c.is_empty():
				continue
			if pneed == 0 or float(c.size()) / need < float(pc.size()) / pneed:
				pc = c
				pneed = need
		if pneed == 0:
			break
		var cell := pc[0]
		digs -= 1
		ruled[cell] = 1
		var q := f.near_find(cell % f.g, cell / f.g, 1, got)
		if q >= 0:
			got[q] = 1
			got_n += 1
	return got_n == nd


static func value_of(deps: Array, only_got: bool) -> int:
	var v := 0
	for q: Dictionary in deps:
		if q.got or not only_got:
			v += VAL[int(q.t)]
	return v


static func score_of(deps: Array, spare: int) -> float:
	var f := float(value_of(deps, true)) / value_of(deps, false)
	return minf(1.0, f * (0.85 + 0.15 * minf(1.0, spare / 2.0)))


## The field's distances as a table (every one is between whole cells), its finds, and the page's
## `scanAt`, `candidates` and `nearFind` on them.
class Field:
	var g := 0
	var n := 0
	var rg := 0.0
	var tol := 0.0
	var fx := PackedInt32Array()
	var fy := PackedInt32Array()
	var ft := PackedInt32Array()
	## hyp(|dx|, |dy|) at |dx| * g + |dy|, and its echo bucket round(d / tol), -1 out of reach.
	var tab := PackedFloat64Array()
	var bkt := PackedInt32Array()

	func _init(S: Dictionary) -> void:
		g = int(S.G)
		n = g * g
		rg = float(S.range)
		tol = float(S.tol)
		for q: Dictionary in S.deps:
			fx.append(int(q.x))
			fy.append(int(q.y))
			ft.append(int(q.t))
		tab.resize(n)
		bkt.resize(n)
		for a in g:
			for b in g:
				var d := GameSeismic.hyp(a, b)
				tab[a * g + b] = d
				bkt[a * g + b] = MiniPix.jr(d / tol) if d <= rg else -1

	func dist(x0: int, y0: int, x1: int, y1: int) -> float:
		return tab[absi(x0 - x1) * g + absi(y0 - y1)]

	## What one scan hears: every find within range, its tier and distance, nearest first (V8's
	## sort is stable: a tie keeps the finds' order).
	func scan_at(x: int, y: int) -> Dictionary[String, Variant]:
		var idx: Array[int] = []
		for i in ft.size():
			if dist(fx[i], fy[i], x, y) <= rg + 1e-9:
				idx.append(i)
		idx.sort_custom(func(a: int, b: int) -> bool:
			var da := dist(fx[a], fy[a], x, y)
			var db := dist(fx[b], fy[b], x, y)
			return da < db or (da == db and a < b))
		var oi := PackedInt32Array()
		var ot := PackedInt32Array()
		var od := PackedFloat64Array()
		for i in idx:
			oi.append(i)
			ot.append(ft[i])
			od.append(dist(fx[i], fy[i], x, y))
		var out: Dictionary[String, Variant] = {"x": x, "y": y, "i": oi, "t": ot, "d": od}
		return out

	## Cells a find of tier t could sit in, given what every scan heard.
	func candidates(scans_: Array[Dictionary], t: int, ruled: PackedByteArray) -> PackedInt32Array:
		var out := PackedInt32Array()
		for y in g:
			for x in g:
				if not ruled.is_empty() and ruled[y * g + x]:
					continue
				var ok := true
				for p in scans_:
					var d := dist(x, y, int(p.x), int(p.y))
					if d > rg + 1e-9:
						continue
					var pt: PackedInt32Array = p.t
					var pd: PackedFloat64Array = p.d
					var hit := false
					for k in pt.size():
						if pt[k] == t and absf(pd[k] - d) <= tol:
							hit = true
							break
					if not hit:
						ok = false
						break
				if ok:
					out.append(y * g + x)
		return out

	## The find a dig at (x, y) reaches: the nearest one not yet dug within `reach` cells (square).
	func near_find(x: int, y: int, reach: int, got: PackedByteArray) -> int:
		var best := -1
		var bd := 1e9
		for i in ft.size():
			if got[i]:
				continue
			if maxi(absi(fx[i] - x), absi(fy[i] - y)) <= reach:
				var d := dist(fx[i], fy[i], x, y)
				if d < bd:
					bd = d
					best = i
		return best


# ---------------------------------------------------------------- the game

func _mount() -> void:
	P = gen(rng, depth, sensors)
	px = MiniPix.new(W, H)
	if P.is_empty():
		push_error("GameSeismic: no field at depth %d" % depth)
		over = true
		done(0.0, "No field")
		return
	G = int(P.G)
	CP = cpof(G)
	FW = G * CP
	FX = 1 + ((110 - FW) >> 1)
	FY = PY0 + ((PH - FW) >> 1)
	rg = float(P.range)
	scans_left = int(P.scans)
	digs_left = int(P.digs)
	_f = Field.new(P)
	_tc.clear()
	for c in TC:
		_tc.append(PackedColorArray([MiniPix.mix(c, BLACK, 0.35), MiniPix.mix(c, BLACK, 0.7), MiniPix.mix(c, WHITE, 0.25),
			MiniPix.mix(c, WHITE, 0.55), MiniPix.mix(c, BLACK, 0.45), MiniPix.mix(c, BLACK, 0.75),
			MiniPix.mix(c, BLACK, 0.6), MiniPix.mix(c, WHITE, 0.45)]))
	var d0: Dictionary = (P.deps as Array)[0]
	_hs = (int(d0.x) * 131 + int(d0.y) * 977 + G) | 1
	_base = _ground()
	_render(_now())


## The page's clock: `performance.now()` read 1000 at the mount.
func _now() -> float:
	return 1000.0 + t * 1000.0


## The ground's own hash stream (`hr`), the page's float arithmetic and 32-bit wrap.
func _hr() -> float:
	var v := float(_hs) * 1103515245.0 + 12345.0
	_hs = int(fposmod(v, 4294967296.0)) & 0x7fffffff
	return _hs / float(0x7fffffff)


func ccx(x: int) -> int:
	return FX + x * CP + (CP >> 1)


func ccy(y: int) -> int:
	return FY + y * CP + (CP >> 1)


func ring_r(d: float) -> int:
	return 3 if d < 0.5 else MiniPix.jr(d * CP)


func _deps() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign(P.deps)
	return out


func _tick(_dt: float) -> void:
	# the page's loop draws (and moves the sweep) about 30 times a second
	var ph := floori(t * 30.0)
	if ph == phase:
		return
	phase = ph
	var now := _now()
	_step(now)
	if drawing:
		_render(now)


## The sweep's ears: each find the ring has passed rings once; the sweep ends 150 ms after it is out.
func _step(now: float) -> void:
	if sweep.is_empty():
		return
	var el := now - float(sweep.t0)
	if el < 250.0:
		return
	var u := minf(1.0, (el - 250.0) / float(sweep.dur))
	var d := u * rg
	var od: PackedFloat64Array = scans[int(sweep.p)].d
	for k in od.size():
		if (sweep.heard as Dictionary).has(k) or od[k] > d:
			continue
		sweep.heard[k] = true
		(sweep.flash as Array).append([k, now])
	if u >= 1.0 and not sweep.end:
		sweep.end = true
		after(0.15, _end_sweep)


func _end_sweep() -> void:
	if sweep.is_empty():
		return
	var p: int = sweep.p
	sweep = {}
	busy = false
	sel = p
	if (scans[p].d as PackedFloat64Array).is_empty():
		say("QUIET", "neutral")
	if scans_left <= 0 and tool == "scan":
		tool = "dig"


func _scan(x: int, y: int, now: float) -> void:
	if over or busy or scans_left <= 0:
		return
	busy = true
	scans_left -= 1
	msg = ""
	peek = -1
	hover_spike = {}
	scans.append(_f.scan_at(x, y))
	sel = scans.size() - 1
	sweep = {"p": sel, "t0": now, "dur": 900.0 * rg / 4.5, "heard": {}, "flash": [], "end": false}
	sfx(&"scan")


func _hole_at(x: int, y: int) -> bool:
	for h in holes:
		if int(h.x) == x and int(h.y) == y:
			return true
	return false


func _dig(x: int, y: int, now: float) -> void:
	if over or busy or digs_left <= 0 or _hole_at(x, y):
		return
	busy = true
	digs_left -= 1
	msg = ""
	drill = {"x": x, "y": y, "t": now, "dust": false}
	sfx(&"dig")
	after(0.52, _dug.bind(x, y))


## The nearest find not yet dug within `reach` cells of (x, y), or -1.
func _near_find(x: int, y: int, reach: int) -> int:
	var got := PackedByteArray()
	for q: Dictionary in _deps():
		got.append(1 if q.got else 0)
	return _f.near_find(x, y, reach, got)


func _dug(x: int, y: int) -> void:
	if over:
		return
	drill = {}
	busy = false
	var q := _near_find(x, y, 1)
	var near := -1 if q >= 0 else _near_find(x, y, 2)
	holes.append({"x": x, "y": y, "hit": q >= 0, "close": near >= 0})
	var deps := _deps()
	if q >= 0:
		deps[q].got = true
		sfx(&"ore")
		gems.append({"d": q, "t": _now()})
		msg = TN[int(deps[q].t)]
		say(msg, "t%d" % int(deps[q].t))
	elif near >= 0:
		msg = "CLOSE"
		close_t = _now()
		say(msg, "neutral")
	else:
		msg = "EMPTY"
		say(msg, "bad")
	if deps.all(func(e: Dictionary) -> bool: return e.got):
		after(0.5, func() -> void:
			sfx(&"win")
			_finish("ALL DUG"))
	elif digs_left <= 0:
		after(0.5, _finish.bind("NO DIGS LEFT"))


func _finish(why: String) -> void:
	if over:
		return
	over = true
	end_ghost = true
	msg = why
	busy = false
	var deps := _deps()
	var got := deps.filter(func(e: Dictionary) -> bool: return e.got).size()
	if why != "STOPPED":
		say_end(why, "good" if why == "ALL DUG" else "bad")
	done(score_of(deps, scans_left + digs_left), "%d of %d finds dug · %d scans" % [got, deps.size(), scans.size()])


func cell_at(q: Vector2i) -> Vector2i:
	if q.x >= FX and q.x < FX + FW and q.y >= FY and q.y < FY + FW:
		return Vector2i((q.x - FX) / CP, (q.y - FY) / CP)
	return NO_CELL


func _scan_index(c: Vector2i) -> int:
	for k in scans.size():
		if int(scans[k].x) == c.x and int(scans[k].y) == c.y:
			return k
	return -1


func cur_scan() -> int:
	return peek if peek >= 0 else sel


## A scan's spikes on the graph: [{k (out index), t, x (the row), h}], up to `up_to` cells out.
func spikes_of(p: Dictionary, up_to := INF) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var per := {}
	var pt: PackedInt32Array = p.t
	var pd: PackedFloat64Array = p.d
	for k in pt.size():
		if pd[k] > up_to:
			continue
		var n: int = per.get(pt[k], 0)
		per[pt[k]] = n + 1
		var slot := ceili(n / 2.0) if n % 2 else -ceili(n / 2.0)
		out.append({"k": k, "t": pt[k], "i": (p.i as PackedInt32Array)[k], "x": _gx(pt[k], slot),
			"h": maxi(2, MiniPix.jr(24.0 * (1.0 - pd[k] / (rg + 0.6))))})
	return out


func _gx(tier: int, slot: int) -> int:
	return MiniPix.jr(T0 + (tier + 0.5) * (T1 - T0) / 5.0) + slot * 5


## The spike nearest the pointer's row on the current scan's graph: {i, t} of its find, or {}.
func spike_at(q: Vector2i) -> Dictionary[String, Variant]:
	var best: Dictionary[String, Variant] = {}
	var ci := cur_scan()
	if ci < 0 or q.x < CXL or q.y < GY or q.y > GY + GH:
		return best
	var bd := 4
	for s in spikes_of(scans[ci]):
		var d := absi(int(s.x) - q.y)
		if d < bd:
			bd = d
			best = {"i": s.i, "t": s.t}
	return best


func _act(c: Vector2i, now: float) -> void:
	var k := _scan_index(c)
	if k >= 0 and (tool == "scan" or sel != k):
		sel = k
		peek = -1
		hover_spike = {}
		return
	if tool == "scan":
		if scans_left > 0:
			_scan(c.x, c.y, now)
		else:
			tool = "dig"
	else:
		_dig(c.x, c.y, now)


func down(p: Vector2i) -> void:
	if over:
		return
	touched = true
	if p.x >= CXL and p.y < GY - 1:
		for k in 2:
			if p.y >= TB_Y[k] and p.y < TB_Y[k] + MiniKit.BTN_H and tool != TOOLS[k]:
				tool = TOOLS[k]
		return
	var c := cell_at(p)
	if c != NO_CELL:
		_act(c, _now())
		return
	var sp := spike_at(p)
	if not sp.is_empty():
		hover_spike = {} if not hover_spike.is_empty() and int(hover_spike.i) == int(sp.i) else sp


func move(p: Vector2i) -> void:
	var c := cell_at(p)
	hover_cell = c
	var k := _scan_index(c) if c != NO_CELL else -1
	peek = -1 if k == sel else k
	if c == NO_CELL:
		hover_spike = spike_at(p)


func give_up() -> void:
	if over:
		return
	_later.clear()
	sweep = {}
	drill = {}
	_finish("STOPPED")


# ---------------------------------------------------------------- the picture

## A pixel inside the field's clip while it is on (`g.clip()` round the field).
func _dot(x: int, y: int, c: Color) -> void:
	if _clipping and not _clip.has_point(Vector2i(x, y)):
		return
	px.dot(x, y, c)


func _r(x: int, y: int, w: int, h: int, c: Color) -> void:
	if not _clipping:
		px.rect(x, y, w, h, c)
		return
	var rr := Rect2i(x, y, w, h).intersection(_clip)
	if rr.size.x > 0 and rr.size.y > 0:
		px.rect(rr.position.x, rr.position.y, rr.size.x, rr.size.y, c)


## The page's midpoint ring: `th` the dither threshold (INF: none), `dash` the dashed reach ring.
func _circ(cx: int, cy: int, r: int, c: Color, th := INF, dash := false) -> void:
	if r < 1:
		_r(cx, cy, 1, 1, c)
		return
	var x := r
	var y := 0
	var e := 1 - r
	while x >= y:
		# a point repeats only within one step (on the axes and the diagonals); the first one counts
		var seen: Array[Vector2i] = []
		for ab: Vector2i in [Vector2i(x, y), Vector2i(y, x), Vector2i(-y, x), Vector2i(-x, y), Vector2i(-x, -y),
				Vector2i(-y, -x), Vector2i(y, -x), Vector2i(x, -y)]:
			if seen.has(ab):
				continue
			seen.append(ab)
			var xx := cx + ab.x
			var yy := cy + ab.y
			if MiniPix.bay(xx, yy) >= th:
				continue
			if dash and int((atan2(float(ab.y), float(ab.x)) + 4.0) * r / 2.5) % 2:
				continue
			_dot(xx, yy, c)
		y += 1
		if e < 0:
			e += 2 * y + 1
		else:
			x -= 1
			e += 2 * (y - x) + 1


## The static ground, drawn once: soil, rocks, cracks, the grid, the bezel, the graph's screen, the deck.
func _ground() -> Image:
	var b := MiniPix.new(W, H)
	b.rect(0, 0, W, H, MiniPix.PANEL)
	var nz := PackedFloat64Array()
	var i := 0
	while i < (W / 8.0 + 2.0) * (H / 8.0 + 2.0):
		nz.append(_hr())
		i += 1
	for y in FW:
		for x in FW:
			var v := _vn(nz, x, y, 10) * 0.6 + _vn(nz, x + 40, y + 17, 4) * 0.4
			var lit := (-(x - FW / 2.0) - (y - FW / 2.0)) / FW * 0.25
			var k := MiniPix.jr((v + lit) * 5.0 - 0.3 + MiniPix.bay(x, y) - 0.5)
			b.rect(FX + x, FY + y, 1, 1, SOIL[clampi(k, 1, 4)])
	_rocks(b)
	for j in range(1, G):
		for ii in range(1, G):
			b.rect(FX + ii * CP, FY + j * CP, 1, 1, SOIL[3])
	b.rect(FX - 2, FY - 2, FW + 4, 1, MiniPix.BEVEL_LO)
	b.rect(FX - 2, FY - 2, 1, FW + 4, MiniPix.BEVEL_LO)
	b.rect(FX - 2, FY + FW + 1, FW + 4, 1, MiniPix.BEVEL_HI)
	b.rect(FX + FW + 1, FY - 2, 1, FW + 4, MiniPix.BEVEL_HI)
	b.rect(FX - 1, FY - 1, FW + 2, 1, BLACK)
	b.rect(FX - 1, FY - 1, 1, FW + 2, BLACK)
	b.rect(FX - 1, FY + FW, FW + 2, 1, BLACK)
	b.rect(FX + FW, FY - 1, 1, FW + 2, BLACK)
	# the graph screen, on its side: tiers run down (common at the top), spikes run right (longer = nearer)
	b.rect(CXL - 1, GY - 1, CW + 2, GH + 1, BLACK)
	b.rect(CXL, GY, CW, GH - 1, MiniPix.VOID)
	for tr in 5:
		var ly := MiniPix.jr(T0 + (tr + 0.5) * (T1 - T0) / 5.0)
		for x in range(BL + 2, BR + 1, 2):
			b.rect(x, ly, 1, 1, MiniPix.PANEL)
		b.rect(BL - 2, ly - 3, 1, 7, TC[tr])
	b.rect(BL, T0, 1, T1 - T0 + 1, MiniPix.LINE)
	b.rect(BL, T1 + 7, BR - BL + 1, 1, MiniPix.LINE)
	b.rect(BR - 1, T1 + 6, 1, 3, MiniPix.LINE)
	b.text("COMMON", CXL + 2, GY + 2, MiniPix.COLD)
	b.text("RARE", CXL + 2, T1 + 1, MiniPix.COLD)
	b.text("FAR", CXL + 2, T1 + 9, MiniPix.LINE)
	b.text("NEAR", BR + 1, T1 + 9, MiniPix.COLD, "right")
	MiniKit.deck(b, false)
	return b.img


## The page's value noise: bilinear over the hash stream's values.
func _vn(nz: PackedFloat64Array, x: int, y: int, s: int) -> float:
	var gw := ceili(W / float(s)) + 2
	var xf := x / float(s)
	var yf := y / float(s)
	var x0 := floori(xf)
	var y0 := floori(yf)
	var fx := xf - x0
	var fy := yf - y0
	var n := nz.size()
	var v00 := nz[((y0 * gw + x0) * 7) % n]
	var v10 := nz[((y0 * gw + x0 + 1) * 7) % n]
	var v01 := nz[(((y0 + 1) * gw + x0) * 7) % n]
	var v11 := nz[(((y0 + 1) * gw + x0 + 1) * 7) % n]
	var a := v00 + (v10 - v00) * fx
	var c := v01 + (v11 - v01) * fx
	return a + (c - a) * fy


func _rocks(b: MiniPix) -> void:
	var k := 0
	while k < G * G * 0.35:
		var x := FX + 2 + floori(_hr() * (FW - 4))
		var y := FY + 2 + floori(_hr() * (FW - 4))
		if _hr() < 0.35:
			b.rect(x - 1, y, 3, 2, SOIL[1])
			b.rect(x - 1, y - 1, 2, 1, SOIL[4])
			b.rect(x, y, 2, 1, SOIL[4])
			b.rect(x + 1, y + 1, 1, 1, SOIL[0])
		else:
			b.rect(x, y, 1, 1, SOIL[1])
		k += 1
	for c in 4:
		var x := FX + floori(_hr() * FW)
		var y := FY + floori(_hr() * FW)
		for s in 18:
			b.rect(x, y, 1, 1, SOIL[0])
			x += 1 if _hr() < 0.6 else 0
			y += 1 if _hr() < 0.5 else -1
			if x >= FX + FW or y < FY or y >= FY + FW:
				break


func _render(now: float) -> void:
	px.img.blit_rect(_base, Rect2i(0, 0, W, H), Vector2i.ZERO)
	_tools()
	_clip = Rect2i(FX, FY, FW, FW)
	_clipping = true
	var ci := cur_scan()
	_rings(ci)
	if hover_cell != NO_CELL and tool == "scan" and not busy and not over and scans_left > 0 and _scan_index(hover_cell) < 0:
		_circ(ccx(hover_cell.x), ccy(hover_cell.y), MiniPix.jr(rg * CP), MiniPix.TRACTOR, 0.35, true)
	_holes(now)
	_sweep(now)
	_beacons(now, ci)
	_drill(now)
	_finds(now)
	if hover_cell != NO_CELL and not over and not busy:
		_cursor()
	_clipping = false
	_graph(now, ci)
	if not touched and scans.is_empty() and now - 1000.0 < 6000.0:
		MiniKit.tell(px, "SCAN, THEN DIG.", ["click"] as Array[String], (now - 1000.0) / 1000.0)
	# A (Nov 20): no status line; dig results and QUIET are toasts, ALL DUG / NO DIGS LEFT the shell's card
	draw_toast()
	dirty = true


## The header and the two tools, scanner and drill, each with its charges.
func _tools() -> void:
	var deps := _deps()
	var got := deps.filter(func(e: Dictionary) -> bool: return e.got).size()
	MiniKit.header(px, {label = "FINDS", value = "%d/%d" % [got, deps.size()], vkind = "good" if got == deps.size() else ""},
		[["SCANS", scans_left], ["DIGS", digs_left, null if digs_left else "bad"]])
	for k in 2:
		var on := tool == TOOLS[k]
		var live := scans_left > 0 if k == 0 else digs_left > 0
		MiniKit.button(px, CXL, TB_Y[k], CW, MiniKit.BTN_H, "SCAN" if k == 0 else "DIG",
			"disabled" if not live else ("active" if on else "normal"), TOOLS[k])


## Echo rings from every scan, each in its find's tier colour, the radius the true distance: rings of
## one colour from two beacons cross on the find. A picked spike lights that find's rings only.
func _rings(ci: int) -> void:
	var sp := int(sweep.p) if not sweep.is_empty() else -1
	if ci >= 0 and ci != sp:
		_circ(ccx(int(scans[ci].x)), ccy(int(scans[ci].y)), MiniPix.jr(rg * CP), MiniPix.LINE, 0.3, true)
	var focus := int(hover_spike.i) if not hover_spike.is_empty() else -1
	var late: Array = []
	for k in scans.size():
		if k == sp:
			continue
		var p := scans[k]
		var cx := ccx(int(p.x))
		var cy := ccy(int(p.y))
		var pt: PackedInt32Array = p.t
		var pd: PackedFloat64Array = p.d
		var pi: PackedInt32Array = p.i
		for e in pt.size():
			var r := ring_r(pd[e])
			if focus >= 0:
				if pi[e] == focus:
					late.append([cx, cy, r, _tc[pt[e]][2]])
				else:
					_circ(cx, cy, r, _tc[pt[e]][1])
				continue
			_circ(cx, cy, r, TC[pt[e]] if k == ci else _tc[pt[e]][0])
	for l: Array in late:
		_circ(l[0], l[1], l[2], l[3])


func _holes(now: float) -> void:
	for k in holes.size():
		var h := holes[k]
		var x := ccx(int(h.x))
		var y := ccy(int(h.y))
		_r(x - 2, y - 1, 5, 3, HOLE)
		_r(x - 1, y - 2, 3, 5, HOLE)
		_r(x - 1, y + 2, 3, 1, SOIL[5])
		if not h.hit:
			var xc := MiniPix.HOT if h.close else MiniPix.BAD
			for o: Vector2i in [Vector2i(-1, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(0, 0)]:
				_r(x + o.x, y + o.y, 1, 1, xc)
		if h.close and k == holes.size() - 1:
			var u := (now - close_t) / 700.0
			if u < 1.0:
				_circ(x, y, MiniPix.jr(3 + u * CP * 1.5), MiniPix.HOT, 1.0 - u)
				_circ(x, y, MiniPix.jr(2 + u * CP), MiniPix.FLARE, 0.7 * (1.0 - u))


## The sweep: a beam drops from the ship, then a ring sweeps out with a turning arm.
func _sweep(now: float) -> void:
	if sweep.is_empty():
		return
	var p := scans[int(sweep.p)]
	var el := now - float(sweep.t0)
	var x := ccx(int(p.x))
	var y := ccy(int(p.y))
	if el < 250.0:
		var yy := FY + MiniPix.jr((y - FY) * el / 250.0)
		for j in range(FY, yy, 2):
			_r(x, j, 1, 1, MiniPix.TRACTOR)
		return
	var u := minf(1.0, (el - 250.0) / float(sweep.dur))
	var r := MiniPix.jr(u * rg * CP)
	for k in range(1, 4):
		var rr := r - k * 2
		if rr > 1:
			_circ(x, y, rr, MiniPix.TRACTOR, 0.35 - k * 0.1)
	if r >= 1:
		_circ(x, y, r, MiniPix.MARK if u < 0.85 else MiniPix.TRACTOR)
	var a := el / 160.0
	for k in r + 1:
		var ax := MiniPix.jr(x + cos(a) * k)
		var ay := MiniPix.jr(y + sin(a) * k)
		if MiniPix.bay(ax, ay) < 0.8:
			_r(ax, ay, 1, 1, MiniPix.TRACTOR)
	var pt: PackedInt32Array = p.t
	var pd: PackedFloat64Array = p.d
	for f: Array in sweep.flash:
		var fu := (now - float(f[1])) / 500.0
		_circ(x, y, ring_r(pd[f[0]]), WHITE if fu < 0.3 else TC[pt[f[0]]])


func _beacons(now: float, ci: int) -> void:
	for k in scans.size():
		var x := ccx(int(scans[k].x))
		var y := ccy(int(scans[k].y))
		var on := k == ci
		_r(x - 2, y - 2, 5, 5, BLACK)
		_r(x - 1, y - 1, 3, 3, MiniPix.EMBER if on else MiniPix.CHILL)
		_r(x, y, 1, 1, MiniPix.HOT if on else MiniPix.ICE)
		_r(x, y - 4, 1, 2, MiniPix.EMBER if on else MiniPix.COLD)
		if on and int(now / 300.0) % 2:
			_r(x, y - 5, 1, 1, MiniPix.HOT)


func _drill(now: float) -> void:
	if drill.is_empty():
		return
	var u := (now - float(drill.t)) / 520.0
	if u >= 1.0:
		return
	var x := ccx(int(drill.x))
	var y := ccy(int(drill.y))
	var sh := (1 if int(now / 40.0) % 2 else -1) if u > 0.5 else 0
	var yy := y + MiniPix.jr(-14.0 * (1.0 - minf(1.0, u / 0.5)))
	_r(x - 3 + sh, yy - 13, 7, 1, BLACK)
	_r(x - 3 + sh, yy - 12, 7, 2, MiniPix.EMBER)
	_r(x - 3 + sh, yy - 12, 7, 1, MiniPix.HOT)
	_r(x - 2 + sh, yy - 10, 5, 6, BLACK)
	_r(x - 1 + sh, yy - 10, 3, 6, MiniPix.COLD)
	_r(x - 1 + sh, yy - 10, 1, 6, MiniPix.ICE)
	var sp := int(now / 50.0) % 2
	_r(x - 1 + sh, yy - 4, 3, 2, MiniPix.CHILL)
	_r(x - 1 + sh + sp * 2, yy - 4, 1, 1, MiniPix.COLD)
	_r(x + sh, yy - 2, 1, 2, MiniPix.ICE)
	_r(x + sh, yy - 3 + sp, 1, 1, MiniPix.COLD)
	if u > 0.5 and not drill.dust:
		drill.dust = true
		for k in 7:
			var a := -PI * (0.05 + 0.9 * k / 6.0)
			var vx := cos(a) * (4.0 + _hr() * 4.0)
			var vy := sin(a) * (3.0 + _hr() * 3.0)
			parts.append({"x": x, "y": y, "vx": vx, "vy": vy, "t": now, "life": 420.0, "c": SOIL[5] if k % 2 else SOIL[4]})


## The finds dug (popping up), the ones missed (at the end), and the drill's dust.
func _finds(now: float) -> void:
	var deps := _deps()
	for g: Dictionary in gems:
		var q: Dictionary = deps[int(g.d)]
		var u := minf(1.0, (now - float(g.t)) / 650.0)
		var x := ccx(int(q.x))
		var y := ccy(int(q.y)) - MiniPix.jr(sin(PI * u) * 12.0 * (1.0 - u * 0.3))
		if u < 1.0 and u > 0.1:
			_circ(ccx(int(q.x)), ccy(int(q.y)), MiniPix.jr(2.0 + u * 6.0), TC[int(q.t)], 0.6 * (1.0 - u))
		_gem(x, y, int(q.t))
	if end_ghost:
		for q: Dictionary in deps:
			if not q.got:
				var x := ccx(int(q.x))
				var y := ccy(int(q.y))
				_circ(x, y, 3, TC[int(q.t)], 0.6)
				_r(x, y, 1, 1, TC[int(q.t)])
	for k in range(parts.size() - 1, -1, -1):
		var q := parts[k]
		var u := (now - float(q.t)) / float(q.life)
		if u >= 1.0:
			parts.remove_at(k)
			continue
		_r(MiniPix.jr(float(q.x) + float(q.vx) * u), MiniPix.jr(float(q.y) + float(q.vy) * u + 8.0 * u * u), 1, 1, q.c)


func _gem(x: int, y: int, tr: int) -> void:
	var c := TC[tr]
	var hi: Color = _tc[tr][3]
	var lo: Color = _tc[tr][4]
	var ol: Color = _tc[tr][5]
	_r(x - 2, y - 3, 5, 1, ol)
	for j in GEM.size():
		for i in 5:
			var ch := GEM[j][i]
			if ch == ".":
				continue
			_r(x - 2 + i, y - 2 + j, 1, 1, ol if ch == "o" else (hi if ch == "h" else (lo if ch == "l" else c)))
	_r(x - 1, y - 2, 3, 1, hi)


## The hover cursor's corners on the field.
func _cursor() -> void:
	var x := FX + hover_cell.x * CP
	var y := FY + hover_cell.y * CP
	var c := MiniPix.TRACTOR if tool == "scan" else MiniPix.EMBER
	_r(x, y, 2, 1, c)
	_r(x, y, 1, 2, c)
	_r(x + CP - 2, y, 2, 1, c)
	_r(x + CP - 1, y, 1, 2, c)
	_r(x, y + CP - 1, 2, 1, c)
	_r(x, y + CP - 2, 1, 2, c)
	_r(x + CP - 2, y + CP - 1, 2, 1, c)
	_r(x + CP - 1, y + CP - 2, 1, 2, c)


## The graph of the sweeping or the current scan.
func _graph(now: float, ci: int) -> void:
	var live := not sweep.is_empty()
	var gp := int(sweep.p) if live else ci
	if gp < 0:
		return
	var up_to := INF
	if live and not sweep.end:
		up_to = maxf(0.0, (now - float(sweep.t0) - 250.0) / float(sweep.dur) * rg)
	var sp := spikes_of(scans[gp], up_to)
	for s in sp:
		var age := 1.0
		if live:
			for f: Array in sweep.flash:
				if int(f[0]) == int(s.k):
					age = minf(1.0, (now - float(f[1])) / 180.0)
					break
		var h := maxi(1, MiniPix.jr(int(s.h) * (age * 1.15 if age < 1.0 else 1.0)))
		var tr: int = s.t
		var c := TC[tr]
		var ol: Color = _tc[tr][6]
		var hi: Color = _tc[tr][7]
		var lit := not hover_spike.is_empty() and int(hover_spike.i) == int(s.i)
		var sx: int = s.x
		for j in h:
			var w := MiniPix.jr(2.0 * (j / float(h)))
			var x := BL + h - j
			px.rect(x, sx - w, 1, w * 2 + 1, hi if lit else c)
			px.rect(x, sx - w - 1, 1, 1, ol)
			px.rect(x, sx + w + 1, 1, 1, ol)
			if j < h * 0.6:
				px.rect(x, sx - w, 1, 1, hi)
		px.rect(BL + h + 1, sx, 1, 1, WHITE if lit else ol)
	px.text("#%d" % (gp + 1), CXL + CW - 2, T1 + 2, MiniPix.HOT if peek >= 0 else MiniPix.CHILL, "right")
