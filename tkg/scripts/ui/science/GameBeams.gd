class_name GameBeams
extends MiniGame

## BEAM BENCH (Jon loved, Nov 17): tap a mirror to turn it; light every sensor. A port of the
## approved `beams2.js` in its approved layout and the UI kit (Nov 20): LIT and TURNS in the header,
## the table as large as the whole glass allows with its emitter, ALL LIT on the shell's result card (status A).
## Why: docs/why/MiniGame.md#beams-and-spectrum-on-the-glass

const DX: Array[int] = [0, 1, 0, -1]
const DY: Array[int] = [-1, 0, 1, 0]
## '/' and '\' reflections.
const SL: Array[int] = [1, 0, 3, 2]
const BS: Array[int] = [3, 2, 1, 0]
const CFG := {
	1: {n = 5, pm = 3, dec = 1, rocks = 0, glass = 0, sens = 2, min_par = 2, t1 = 25.0},
	2: {n = 6, pm = 4, dec = 1, rocks = 2, glass = 0, sens = 2, min_par = 2, t1 = 35.0},
	3: {n = 6, pm = 4, dec = 2, rocks = 2, glass = 1, sens = 3, min_par = 3, t1 = 45.0},
	4: {n = 7, pm = 5, dec = 2, rocks = 3, glass = 1, sens = 3, min_par = 3, t1 = 55.0},
	5: {n = 7, pm = 5, dec = 3, rocks = 3, glass = 2, sens = 3, min_par = 3, t1 = 65.0},
}
const W := MiniKit.W
const H := MiniKit.H
const TABLE := Color("#0d121b")
const TABLE_LIT := Color("#111823")
const PEG := Color("#18212d")
const EMIT_SH := Color("#3b4a5c")
const OFF_LAMP := Color("#1f2935")
const HOUSING := Color("#2b3644")
const ROCK: Array[Color] = [Color("#0b0d10"), Color("#262b33"), Color("#3a4048"), Color("#565e69"), Color("#7a838f")]
const MOUNT: Array[Color] = [Color("#05070a"), Color("#1a222d"), Color("#2b3644"), Color("#3d4d61"), Color("#56677d")]
const DARK_LENS: Array[Color] = [Color("#000000"), Color("#0b0f15"), Color("#151c26"), Color("#1f2935")]

var P: Dictionary = {}
var n := 5
var board: Array = []
var cs := 21
var bw := 105
var bx := 0
var by := 0
var t1 := 25.0
var over := false
var taps := 0
var won := 0.0
var ang := {}
var lit_since := {}
var beam := {}
var scol := {}
var _bg: Image
var _em := Vector2i.ZERO
var _frame := -1


func id() -> StringName:
	return &"beams"


func hint() -> String:
	return "Light every sensor."


func controls() -> Array[String]:
	return ["click"]


# ---------------------------------------------------------------- the rules

## One beam: sensors and glass let it through, glass tints it, mirrors turn it, rocks stop it.
static func trace(nn: int, b: Array, src: Dictionary) -> Dictionary[String, Variant]:
	var segs: Array = []
	var hits := {}
	var seen := {}
	var path: Array[int] = []
	var pcol: Array[String] = []
	var x: int = src.x
	var y: int = src.y
	var d: int = src.d
	var c := "w"
	var sx := x + 0.5 - DX[d] * 0.5
	var sy := y + 0.5 - DY[d] * 0.5
	var end := "edge"
	for guard in 500:
		if x < 0 or y < 0 or x >= nn or y >= nn:
			segs.append([sx, sy, x + 0.5 - DX[d] * 0.5, y + 0.5 - DY[d] * 0.5, c])
			break
		var i := y * nn + x
		var key := i * 4 + d
		if seen.has(key):
			segs.append([sx, sy, x + 0.5, y + 0.5, c])
			end = "loop"
			break
		seen[key] = true
		var cell: Variant = b[i]
		var t: String = (cell as Dictionary).t if cell != null else ""
		if t == "rock":
			segs.append([sx, sy, x + 0.5 - DX[d] * 0.5, y + 0.5 - DY[d] * 0.5, c])
			end = "rock"
			break
		path.append(i)
		if t == "glass":
			segs.append([sx, sy, x + 0.5, y + 0.5, c])
			c = cell.c
			sx = x + 0.5
			sy = y + 0.5
		pcol.append(c)
		if t == "sensor":
			if not hits.has(i):
				hits[i] = {}
			hits[i][c] = true
		if t == "m":
			segs.append([sx, sy, x + 0.5, y + 0.5, c])
			d = (BS if int(cell.o) else SL)[d]
			sx = x + 0.5
			sy = y + 0.5
		x += DX[d]
		y += DY[d]
	var out: Dictionary[String, Variant] = {}
	out.assign({segs = segs, hits = hits, path = path, pcol = pcol, end = end})
	return out


static func is_lit(cell: Dictionary, h: Variant) -> bool:
	if h == null:
		return false
	return (h as Dictionary).size() > 0 if cell.c == "w" else (h as Dictionary).has(cell.c)


static func lit_count(p: Dictionary, b: Array, tr: Dictionary) -> int:
	var k := 0
	for s: int in p.sensors:
		if is_lit(b[s], (tr.hits as Dictionary).get(s)):
			k += 1
	return k


static func with_o(b: Array, mir: Array, mask: int) -> Array[Variant]:
	var out: Array[Variant] = []
	out.assign(b)
	for k in mir.size():
		out[mir[k]] = {t = "m", o = (mask >> k) & 1}
	return out


static func solutions(p: Dictionary, b: Array) -> Array[int]:
	var out: Array[int] = []
	var mir: Array = p.mir
	for m in 1 << mir.size():
		var bb := with_o(b, mir, m)
		if lit_count(p, bb, trace(p.n, bb, p.src)) == (p.sensors as Array).size():
			out.append(m)
	return out


static func pop(v: int) -> int:
	var k := 0
	while v:
		k += v & 1
		v >>= 1
	return k


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


static func shuffled(src: Array, r: RandomNumberGenerator) -> Array[int]:
	var out: Array[int] = []
	for i in order(src.size(), r):
		out.append(int(src[i]))
	return out


## The mirrors on the beam's path, one past the last; false when the beam ran out of room.
static func _lay_mirrors(c: Dictionary, nn: int, b: Array, src: Dictionary, src_i: int, path_m: Array[int], r: RandomNumberGenerator) -> bool:
	var last_idx := -1
	for m in int(c.pm):
		var tr := trace(nn, b, src)
		var cand: Array[int] = []
		for i: int in (tr.path as Array).slice(last_idx + 2):
			if b[i] == null and i != src_i:
				cand.append(i)
		if cand.is_empty():
			return false
		var i := cand[int(r.randf() * cand.size())]
		b[i] = {t = "m", o = 0 if r.randf() < 0.5 else 1}
		path_m.append(i)
		last_idx = (trace(nn, b, src).path as Array).find(i)
	return true


## {n, src, sensors, mir, board, par, sols, start, lockMask}; {} if none came.
static func gen(r: RandomNumberGenerator, d: int, sens_pts: int) -> Dictionary[String, Variant]:
	var c: Dictionary = CFG[d]
	var nn: int = c.n
	var out: Dictionary[String, Variant] = {}
	for att in 4000:
		var b: Array = []
		b.resize(nn * nn)
		var side := int(r.randf() * 4)
		var k := 1 + int(r.randf() * (nn - 2))
		var src: Dictionary = [{x = k, y = nn - 1, d = 0}, {x = 0, y = k, d = 1}, {x = k, y = 0, d = 2}, {x = nn - 1, y = k, d = 3}][side]
		var src_i: int = int(src.y) * nn + int(src.x)
		for rk in int(c.rocks):
			var i := int(r.randf() * nn * nn)
			if i != src_i and b[i] == null:
				b[i] = {t = "rock"}
		var path_m: Array[int] = []
		if not _lay_mirrors(c, nn, b, src, src_i, path_m, r):
			continue
		var tr := trace(nn, b, src)
		var tp: Array = tr.path
		if tr.end == "loop" or path_m.any(func(i: int) -> bool: return not tp.has(i)):
			continue
		var first_m := tp.find(path_m[0])
		if not _lay_glass(c, nn, b, src, first_m, r):
			continue
		tr = trace(nn, b, src)
		if tr.end == "loop":
			continue
		var p := _finish_deal(c, nn, b, src, src_i, path_m, tr, sens_pts, r)
		if not p.is_empty():
			out.assign(p)
			return out
	return out


static func _lay_glass(c: Dictionary, nn: int, b: Array, src: Dictionary, first_m: int, r: RandomNumberGenerator) -> bool:
	var tr := trace(nn, b, src)
	for gi in int(c.glass):
		var cand: Array[int] = []
		for i: int in (tr.path as Array).slice(first_m + 1):
			if b[i] == null:
				cand.append(i)
		if cand.is_empty():
			return false
		var at := cand[int(r.randf() * cand.size())]
		var col: String
		if gi == 0:
			col = "r" if r.randf() < 0.5 else "b"
		else:
			col = "b" if b.any(func(e: Variant) -> bool: return e != null and e.t == "glass" and e.c == "r") else "r"
		b[at] = {t = "glass", c = col}
		tr = trace(nn, b, src)
	return true


## Sensors (one past the last turn, the rest after the first), decoy mirrors, the bolted mirrors
## sensors give, and a starting turn of every mirror that is not already solved.
static func _finish_deal(c: Dictionary, nn: int, b: Array, src: Dictionary, src_i: int, path_m: Array[int], tr: Dictionary, sens_pts: int, r: RandomNumberGenerator) -> Dictionary[String, Variant]:
	var none: Dictionary[String, Variant] = {}
	var tp: Array = tr.path
	var first_m := tp.find(path_m[0])
	var last_m := tp.rfind(path_m[path_m.size() - 1])
	var tail: Array[int] = []
	var mid: Array[int] = []
	for j in tp.size():
		if b[tp[j]] != null:
			continue
		if j > last_m:
			tail.append(j)
		if j > first_m and j < last_m:
			mid.append(j)
	if tail.is_empty() or mid.size() < int(c.sens) - 1:
		return none
	var pick_j: Array[int] = [tail[int(r.randf() * tail.size())]]
	for j in shuffled(mid, r):
		if pick_j.size() >= int(c.sens):
			break
		if pick_j.all(func(q: int) -> bool: return absi(q - j) > 1):
			pick_j.append(j)
	if pick_j.size() < int(c.sens):
		return none
	var sens: Array[int] = []
	var seen := {}
	for j in pick_j:
		sens.append(int(tp[j]))
		seen[int(tp[j])] = true
	if seen.size() != sens.size():
		return none
	for j in pick_j:
		b[tp[j]] = {t = "sensor", c = (tr.pcol as Array)[j] if int(c.glass) else "w"}
	if int(c.glass) and not sens.any(func(i: int) -> bool: return b[i].c != "w"):
		return none
	var off: Array[int] = []
	for i in nn * nn:
		if b[i] == null and not tp.has(i) and i != src_i:
			off.append(i)
	if off.size() < int(c.dec):
		return none
	for i in shuffled(off, r).slice(0, int(c.dec)):
		b[i] = {t = "m", o = 0 if r.randf() < 0.5 else 1}
	var mir: Array[int] = []
	for i in nn * nn:
		if b[i] != null and b[i].t == "m":
			mir.append(i)
	var p := {n = nn, src = src, sensors = sens, mir = mir}
	var sol_mask := 0
	for k in mir.size():
		sol_mask |= int(b[mir[k]].o) << k
	var sols := solutions(p, b)
	if not sols.has(sol_mask) or sols.size() > maxi(2, (1 << mir.size()) / 8):
		return none
	var n_lock := mini(int(sens_pts >= 1) + int(sens_pts >= 3) + int(sens_pts >= 5), int(c.pm) - 2)
	var lock_i: Array[int] = []
	for i in shuffled(path_m, r).slice(0, n_lock):
		lock_i.append(mir.find(i))
	var lock_mask := 0
	for k in lock_i:
		lock_mask |= 1 << k
	var ok_sols: Array[int] = sols.filter(func(m: int) -> bool: return (m & lock_mask) == (sol_mask & lock_mask))
	var start := -1
	var par := 0
	for t_ in 60:
		var m := int(r.randf() * (1 << mir.size()))
		m = (m & ~lock_mask) | (sol_mask & lock_mask)
		var pr := 1 << 30
		for s in ok_sols:
			pr = mini(pr, pop(s ^ m))
		if pr < mini(int(c.min_par), int(c.pm) - n_lock):
			continue
		var bb := with_o(b, mir, m)
		if lit_count(p, bb, trace(nn, bb, src)) == sens.size():
			continue
		start = m
		par = pr
		break
	if start < 0:
		return none
	var deal := with_o(b, mir, start)
	for k in lock_i:
		deal[mir[k]].lock = true
	p.board = deal
	p.par = par
	p.sols = ok_sols
	p.start = start
	p.lockMask = lock_mask
	none.assign(p)
	return none


static func score_of(n_taps: int, par_: int, secs: float, tt: float) -> float:
	var extra := n_taps - par_
	var p := 1.0 if extra <= 0 else maxf(0.0, 1.0 - 0.12 * extra)
	var t := 1.0 if secs <= tt else maxf(0.0, 1.0 - (secs - tt) / (2.0 * tt))
	return clampf(0.3 + 0.45 * p + 0.25 * t, 0.0, 1.0)


# ---------------------------------------------------------------- the picture

func _now() -> float:
	return 1000.0 + t * 1000.0


func _mount() -> void:
	px = MiniPix.new(W, H)
	P = gen(rng, depth, sensors)
	if P.is_empty():
		push_error("GameBeams: no puzzle at depth %d" % depth)
		over = true
		done(0.0, "No puzzle")
		return
	n = P.n
	t1 = float(CFG[depth].t1) + (int(sensors >= 2) + int(sensors >= 4)) * 15.0
	for cell: Variant in P.board:
		board.append((cell as Dictionary).duplicate() if cell != null else null)
	# the table, its frame and the emitter's housing in rows 11-138 with 1 px side margins (A, Nov 20: the
	# whole glass), cells as large as they allow
	var py0 := MiniKit.PLAY_Y + 1
	var ph := MiniKit.deck_y(false) - 1 - py0
	var sd: int = P.src.d
	cs = mini((W - 2 - (15 if sd == 1 or sd == 3 else 6)) / n, (ph - (15 if sd == 0 or sd == 2 else 6)) / n)
	bw = n * cs
	var el := 12 if sd == 1 else 3
	var er := 12 if sd == 3 else 3
	var et := 12 if sd == 2 else 3
	var eb := 12 if sd == 0 else 3
	bx = el + ((W - el - er - bw) >> 1)
	by = py0 + et + ((ph - et - eb - bw) >> 1)
	for i: int in P.mir:
		var a := 45.0 if int(board[i].o) else -45.0
		ang[i] = Vector2(a, a)
	var black := Color.BLACK
	var white := Color.WHITE
	beam = {"w": [MiniPix.EMBER, MiniPix.FLARE, Color("#fff3dc")],
		"r": [MiniPix.mix(MiniPix.BAD, black, 0.35), MiniPix.BAD, MiniPix.mix(MiniPix.BAD, white, 0.55)],
		"b": [MiniPix.mix(MiniPix.TIERS[2], black, 0.35), MiniPix.TIERS[2], MiniPix.mix(MiniPix.TIERS[2], white, 0.6)]}
	scol = {"w": MiniPix.HOT, "r": MiniPix.BAD, "b": MiniPix.TIERS[2]}
	_bg = _draw_bg()
	_render(_now())


## The midpoint circle, its pixels thinned by the Bayer threshold `th` (none: every pixel).
func _circ(cx: int, cy: int, r: int, c: Color, th := -1.0) -> void:
	if r < 1:
		px.dot(cx, cy, c)
		return
	var x := r
	var y := 0
	var e := 1 - r
	var seen := {}
	while x >= y:
		for q: Vector2i in [Vector2i(x, y), Vector2i(y, x), Vector2i(-y, x), Vector2i(-x, y), Vector2i(-x, -y), Vector2i(-y, -x), Vector2i(y, -x), Vector2i(x, -y)]:
			var xx := cx + q.x
			var yy := cy + q.y
			var k := xx * 1000 + yy
			if seen.has(k):
				continue
			seen[k] = true
			if th >= 0.0 and MiniPix.bay(xx, yy) >= th:
				continue
			px.dot(xx, yy, c)
		y += 1
		if e < 0:
			e += 2 * y + 1
		else:
			x -= 1
			e += 2 * (y - x) + 1


## A shaded ball: an outlined disc lit from the top-left in the ramp's steps.
static func _ball(c: MiniPix, cx: int, cy: int, r: int, ramp: Array) -> void:
	var rr := r * r + r * 0.8
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			if x * x + y * y > rr:
				continue
			var edge := (x - 1) * (x - 1) + y * y > rr or (x + 1) * (x + 1) + y * y > rr or x * x + (y - 1) * (y - 1) > rr or x * x + (y + 1) * (y + 1) > rr
			var col: Color
			if edge:
				col = ramp[0]
			else:
				var nx := x / (r + 0.5)
				var ny := y / (r + 0.5)
				var nz := sqrt(maxf(0.0, 1.0 - nx * nx - ny * ny))
				var l := maxf(0.0, -nx * 0.55 - ny * 0.62 + nz * 0.56)
				col = ramp[maxi(1, mini(ramp.size() - 1, MiniPix.jr(l * (ramp.size() - 1) + MiniPix.bay(cx + x, cy + y) - 0.5)))]
			c.dot(cx + x, cy + y, col)


## The console plate and the optical table, the emitter, and the rocks and glass, drawn once.
func _draw_bg() -> Image:
	var b := MiniPix.new(W, H)
	b.rect(0, 0, W, H, MiniPix.PANEL)
	MiniKit.deck(b, false)
	b.rect(bx - 3, by - 3, bw + 6, bw + 6, MiniPix.BEVEL_LO)
	b.rect(bx - 2, by - 2, bw + 4, bw + 4, Color.BLACK)
	b.rect(bx - 3, by + bw + 2, bw + 6, 1, MiniPix.BEVEL_HI)
	b.rect(bx + bw + 2, by - 3, 1, bw + 6, MiniPix.BEVEL_HI)
	b.rect(bx, by, bw, bw, TABLE)
	for y in bw:
		for x in bw:
			if MiniPix.bay(bx + x, by + y) < (1.0 - (x + y) / (bw * 2.0)) * 0.35:
				b.dot(bx + x, by + y, TABLE_LIT)
	for j in n:
		for i in n:
			var x := bx + i * cs
			var y := by + j * cs
			b.dot(x + (cs >> 1), y + (cs >> 1), MiniPix.LINE)
			for q: Vector2i in [Vector2i(2, 2), Vector2i(cs - 3, 2), Vector2i(2, cs - 3), Vector2i(cs - 3, cs - 3)]:
				b.dot(x + q.x, y + q.y, PEG)
	var s: Dictionary = P.src
	var ex := bx + int(s.x) * cs + (cs >> 1)
	var ey := by + int(s.y) * cs + (cs >> 1)
	_em = Vector2i(ex, ey)
	var em: Rect2i
	match int(s.d):
		1:
			em = Rect2i(bx - 12, ey - 5, 10, 11)
		3:
			em = Rect2i(bx + bw + 2, ey - 5, 10, 11)
		2:
			em = Rect2i(ex - 5, by - 12, 11, 10)
		_:
			em = Rect2i(ex - 5, by + bw + 2, 11, 10)
	b.rect(em.position.x, em.position.y, em.size.x, em.size.y, Color.BLACK)
	b.rect(em.position.x + 1, em.position.y + 1, em.size.x - 2, em.size.y - 2, MiniPix.COLD)
	b.rect(em.position.x + 1, em.position.y + 1, em.size.x - 2, 1, MiniPix.ICE)
	b.rect(em.position.x + 1, em.position.y + 1, 1, em.size.y - 2, MiniPix.CHILL)
	b.rect(em.position.x + 2, em.end.y - 3, em.size.x - 3, 1, EMIT_SH)
	b.rect(em.position.x + 3, em.position.y + 3, em.size.x - 6, em.size.y - 6, MiniPix.EMBER)
	b.rect(em.position.x + 3, em.position.y + 3, 1, 1, MiniPix.HOT)
	for i in n * n:
		var cell: Variant = board[i]
		if cell == null:
			continue
		var x := bx + (i % n) * cs
		var y := by + (i / n) * cs
		var cx := x + (cs >> 1)
		var cy := y + (cs >> 1)
		if cell.t == "rock":
			_ball(b, cx, cy, int(floorf(cs * 0.36)), ROCK)
			b.rect(cx + 1, cy, 2, 1, ROCK[1])
			b.rect(cx + 1, cy - 1, 1, 1, ROCK[3])
		elif cell.t == "glass":
			_glass(b, x, y, scol[cell.c])
	return b.img


func _glass(b: MiniPix, x: int, y: int, col: Color) -> void:
	var m := 3
	var dk := MiniPix.mix(col, Color.BLACK, 0.35)
	for yy in range(m, cs - m):
		for xx in range(m, cs - m):
			if MiniPix.bay(x + xx, y + yy) < 0.4:
				b.dot(x + xx, y + yy, dk)
	b.rect(x + m - 1, y + m - 1, cs - 2 * m + 2, 1, Color.BLACK)
	b.rect(x + m - 1, y + cs - m, cs - 2 * m + 2, 1, Color.BLACK)
	b.rect(x + m - 1, y + m - 1, 1, cs - 2 * m + 2, Color.BLACK)
	b.rect(x + cs - m, y + m - 1, 1, cs - 2 * m + 2, Color.BLACK)
	b.rect(x + m, y + m, cs - 2 * m, 1, MiniPix.mix(col, Color.WHITE, 0.4))
	b.rect(x + m, y + m, 1, cs - 2 * m, MiniPix.mix(col, Color.WHITE, 0.25))
	b.rect(x + m, y + cs - m - 1, cs - 2 * m, 1, MiniPix.mix(col, Color.BLACK, 0.2))
	b.rect(x + cs - m - 1, y + m, 1, cs - 2 * m, MiniPix.mix(col, Color.BLACK, 0.2))
	for k in 4:
		b.rect(x + m + 3 + k, y + cs - m - 4 - k, 1, 1, Color.WHITE)


## Each beam segment rasterised, a pixel at a time with its colour and whether it runs across.
func _beam_pixels(tr: Dictionary) -> Array[Array]:
	var out: Array[Array] = []
	for s: Array in tr.segs:
		var x0 := MiniPix.jr(bx + float(s[0]) * cs)
		var y0 := MiniPix.jr(by + float(s[1]) * cs)
		var x1 := MiniPix.jr(bx + float(s[2]) * cs)
		var y1 := MiniPix.jr(by + float(s[3]) * cs)
		var dx := signi(x1 - x0)
		var dy := signi(y1 - y0)
		var ln := maxi(absi(x1 - x0), absi(y1 - y0))
		for k in ln + 1:
			out.append([x0 + dx * k, y0 + dy * k, s[4], dx != 0])
	return out


func _draw_mirror(i: int, lock: bool) -> void:
	var x := bx + (i % n) * cs + (cs >> 1)
	var y := by + (i / n) * cs + (cs >> 1)
	var r := int(floorf(cs * 0.28))
	_ball(px, x, y, r, MOUNT)
	var a := deg_to_rad((ang[i] as Vector2).x)
	var l := cs * 0.42
	var ca := cos(a)
	var sa := sin(a)
	var pts := {}
	var keys: Array[int] = []
	var t_ := -l
	while t_ <= l:
		var w := -1.3
		while w <= 1.3:
			var ppx := MiniPix.jr(x + ca * t_ - sa * w)
			var ppy := MiniPix.jr(y + sa * t_ + ca * w)
			var k := ppx * 10000 + ppy
			var lay := 0 if absf(w) > 0.95 else (2 if w < 0.0 else 1)
			if not pts.has(k):
				keys.append(k)
			if not pts.has(k) or int(pts[k][2]) < lay:
				pts[k] = [ppx, ppy, lay, t_]
			w += 0.35
		t_ += 0.35
	for k in keys:
		var q: Array = pts[k]
		var shine := absf(float(q[3]) + l * 0.35) < 1.2
		px.dot(q[0], q[1], Color.BLACK if int(q[2]) == 0 else ((Color.WHITE if shine else MiniPix.ICE) if int(q[2]) == 2 else MiniPix.COLD))
	if lock:
		for q: Vector2i in [Vector2i(-r, -r), Vector2i(r, -r), Vector2i(-r, r), Vector2i(r, r)]:
			px.dot(x + q.x, y + q.y, MiniPix.WARN)


func _render(now: float) -> void:
	px.img.blit_rect(_bg, Rect2i(0, 0, W, H), Vector2i.ZERO)
	var settled := _turn()
	var tr := trace(n, board, P.src)
	var bp := _beam_pixels(tr)
	var ph := int(floorf(now / 60.0))
	var gl := 0.85 if won else 0.55
	for q: Array in bp:
		var c: Array = beam[q[2]]
		for o: int in [-2, 2]:
			var xx: int = q[0] if q[3] else int(q[0]) + o
			var yy: int = int(q[1]) + o if q[3] else q[1]
			if MiniPix.bay(xx, yy) < gl * 0.35:
				px.dot(xx, yy, c[0])
		for o: int in [-1, 1]:
			var xx: int = q[0] if q[3] else int(q[0]) + o
			var yy: int = int(q[1]) + o if q[3] else q[1]
			if MiniPix.bay(xx + ph, yy + ph) < gl + 0.2:
				px.dot(xx, yy, c[1])
	for q: Array in bp:
		px.dot(q[0], q[1], Color.WHITE if (int(q[0]) + int(q[1]) + ph * 2) % 9 == 0 else beam[q[2]][2])
	var s: Dictionary = P.src
	var sd: int = s.d
	_circ(_em.x + (-(cs >> 1) if sd == 1 else ((cs >> 1) if sd == 3 else 0)), _em.y + (-(cs >> 1) if sd == 2 else ((cs >> 1) if sd == 0 else 0)), 2, MiniPix.FLARE, 0.6)
	var lit := _pieces(tr, now)
	_hud(tr, now)
	if not over and lit == (P.sensors as Array).size() and settled:
		_win(now)
	draw_toast()
	dirty = true


## Each turning mirror 18 degrees on a frame; whether every one has settled.
func _turn() -> bool:
	var settled := true
	for i: int in P.mir:
		var a: Vector2 = ang[i]
		if a.x != a.y:
			var d := a.y - a.x
			a.x += signf(d) * minf(absf(d), 18.0)
			ang[i] = a
		settled = settled and (ang[i] as Vector2).x == (ang[i] as Vector2).y
	return settled


func _pieces(tr: Dictionary, now: float) -> int:
	var lit := 0
	for i in n * n:
		var cell: Variant = board[i]
		if cell == null:
			continue
		if cell.t == "m":
			_draw_mirror(i, cell.get("lock", false))
		if cell.t != "sensor":
			continue
		var x := bx + (i % n) * cs + (cs >> 1)
		var y := by + (i / n) * cs + (cs >> 1)
		var r := int(floorf(cs * 0.3))
		var col: Color = scol[cell.c]
		var on := is_lit(cell, (tr.hits as Dictionary).get(i))
		var wrong: bool = not on and (tr.hits as Dictionary).has(i)
		if on:
			lit += 1
			if not lit_since.has(i):
				lit_since[i] = now
				sfx(&"lit")
		else:
			lit_since.erase(i)
		px.rect(x - r - 2, y - r - 2, 2 * r + 5, 2 * r + 5, Color.BLACK)
		px.rect(x - r - 1, y - r - 1, 2 * r + 3, 2 * r + 3, HOUSING)
		px.rect(x - r - 1, y - r - 1, 2 * r + 3, 1, MiniPix.BEVEL_HI)
		px.rect(x - r - 1, y - r - 1, 1, 2 * r + 3, MiniPix.BEVEL_HI)
		if on:
			var pulse := 0.5 + 0.3 * sin((now - float(lit_since[i])) / 180.0)
			_circ(x, y, r + 3, col, pulse * 0.6)
			_circ(x, y, r + 2, col, pulse)
			_ball(px, x, y, r, [MiniPix.mix(col, Color.BLACK, 0.6), MiniPix.mix(col, Color.BLACK, 0.2), col, MiniPix.mix(col, Color.WHITE, 0.45), Color.WHITE])
		else:
			var ramp: Array = DARK_LENS.duplicate()
			ramp.append(MiniPix.mix(col, Color.BLACK, 0.55))
			_ball(px, x, y, r, ramp)
			_circ(x, y, r, MiniPix.mix(col, Color.BLACK, 0.25), 0.75)
			if wrong and int(floorf(now / 250.0)) % 2:
				_circ(x, y, r, MiniPix.BAD, 0.9)
	return lit


## The kit's header (LIT and its lamps, TURNS) and the tell card; ALL LIT is the shell's card (A).
func _hud(tr: Dictionary, now: float) -> void:
	var hd := MiniKit.header(px, "LIT", [["TURNS", taps]])
	var sens: Array = P.sensors
	for k in sens.size():
		var i: int = sens[k]
		var on := is_lit(board[i], (tr.hits as Dictionary).get(i))
		px.rect(hd.x + k * 7, 2, 5, 5, Color.BLACK)
		px.rect(hd.x + 1 + k * 7, 3, 3, 3, scol[board[i].c] if on else OFF_LAMP)
	if not taps and not over and now - 1000.0 < 4500.0:
		MiniKit.tell(px, "LIGHT EVERY SENSOR.", ["click", MiniKit.ESC] as Array[String], (now - 1000.0) / 1000.0)


func _win(now: float) -> void:
	sfx(&"win")
	over = true
	won = now
	say_end("ALL LIT", "good")
	done(score_of(taps, int(P.par), (now - 1000.0) / 1000.0, t1), "All %d lit with %d turns (best %d)" % [(P.sensors as Array).size(), taps, int(P.par)])


func _tick(_dt: float) -> void:
	var f := int(floorf(t * 30.0))
	if f != _frame:
		_frame = f
		if drawing:
			_render(_now())
		else:
			# the frame's rules without its picture (tests): the mirrors turn, all lit and settled wins
			var settled := _turn()
			if not over and settled and lit_count(P, board, trace(n, board, P.src)) == (P.sensors as Array).size():
				_win(_now())


## The canvas point over board cell `i`, for a scripted tap.
func cell_at(i: int) -> Vector2i:
	return Vector2i(bx + (i % n) * cs + (cs >> 1), by + (i / n) * cs + (cs >> 1))


func down(q: Vector2i) -> void:
	if over:
		return
	var cx := floori(float(q.x - bx) / cs)
	var cy := floori(float(q.y - by) / cs)
	if cx < 0 or cy < 0 or cx >= n or cy >= n:
		return
	var i := cy * n + cx
	var cell: Variant = board[i]
	if cell == null or cell.t != "m" or cell.get("lock", false):
		return
	cell.o = int(cell.o) ^ 1
	var a: Vector2 = ang[i]
	ang[i] = Vector2(a.x, a.y + 90.0)
	taps += 1
	sfx(&"turn")


func give_up() -> void:
	if over:
		return
	over = true
	var lit := lit_count(P, board, trace(n, board, P.src))
	done(0.1 * lit / (P.sensors as Array).size(), "Gave up with %d of %d lit" % [lit, (P.sensors as Array).size()])
