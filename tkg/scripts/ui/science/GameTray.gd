class_name GameTray
extends MiniGame

## SAMPLE TRAY (Jon loved, Nov 17: "click and draggable"): slide canisters along their length until
## the glowing sample leaves by the gap on the right. A port of the approved `tray2.js`; the
## searches keep their order but hold each state as one integer. In its approved layout and the UI kit
## (Nov 20).
## Why: docs/why/MiniGame.md#the-round-2-games

## A 6x6 tray, the exit on the right of row 2.
const S := 6
const ROW := 2
const GOAL := 4
const CFG := {
	1: {lo = 6, hi = 10, nb = [8, 9], lock = 0},
	2: {lo = 8, hi = 13, nb = [9, 10], lock = 0},
	3: {lo = 10, hi = 16, nb = [10, 11], lock = 0},
	4: {lo = 9, hi = 15, nb = [10, 11], lock = 3},
	5: {lo = 12, hi = 20, nb = [11, 12], lock = 4},
}
## The game area, as every game draws it (the UI kit, Nov 20).
const W := MiniKit.W
const H := MiniKit.H
## Deals searched before their mount, by "depth:seed:state"; with `memo_on` (tests) every deal is kept,
## so a test's later mounts skip the search.
static var memo := {}
static var memo_on := false
static var _pre_task := -1
static var _pre_key := ""
static var _pre_got := {}

## 6x6 cells of 18 art px (the tray in rows 10-125: A, Nov 20); a canister's thickness; the exit row's
## top; UNDO, at the foot of the right column a row under the tray's rim.
const C := 18
const T := C - 2
const GX := 6
const GY := 14
const EXY := GY + ROW * C
const UB := Rect2i(MiniKit.W - MiniKit.GUT - 33, 127, 33, MiniKit.BTN_H)
const STEEL: Array[Color] = [MiniPix.ICE, MiniPix.CHILL, MiniPix.CHILL, MiniPix.COLD, MiniPix.COLD, MiniPix.COLD,
	MiniPix.LINE, MiniPix.LINE, MiniPix.BEVEL_LO]

## {B (blocks: {h, len, fix}), pos, par, lock, N, first, path}
var P: Dictionary = {}
var B: Array = []
var pos: Array[int] = []
var vis: Array[float] = []
var hist: Array = []
var moves_ := 0
var last := -1
var sel := -1
var over := false
var undos := 2
var started := false
var clock := 0.0
var out_t := -1.0
var show_hint := false
## A held canister: {i, a0, v0, moved, rng (lo, hi)}.
var drag: Dictionary = {}
var wob: Dictionary = {}
var undo_down := false
var _plate: Image
var _acc := 0.0


func id() -> StringName:
	return &"tray"


func hint() -> String:
	return "Get the sample out."


func controls() -> Array[String]:
	return ["drag"]


# ---------------------------------------------------------------- the rules

static func cell_of(b: Dictionary, p: int, k: int) -> int:
	return int(b.fix) * S + p + k if b.h else (p + k) * S + int(b.fix)


static func fill_occ(bl: Array, p: Array[int], g: PackedInt32Array) -> void:
	g.fill(-1)
	for i in bl.size():
		var b: Dictionary = bl[i]
		for k in int(b.len):
			g[cell_of(b, p[i], k)] = i


static func occ(bl: Array, p: Array[int]) -> PackedInt32Array:
	var g := PackedInt32Array()
	g.resize(S * S)
	fill_occ(bl, p, g)
	return g


static func weights(nb: int) -> Array[int]:
	var w: Array[int] = []
	var v := 1
	for i in nb:
		w.append(v)
		v *= S
	return w


static func enc(p: Array[int], w: Array[int]) -> int:
	var k := 0
	for i in p.size():
		k += p[i] * w[i]
	return k


static func dec(k: int, nb: int) -> Array[int]:
	var p: Array[int] = []
	for i in nb:
		p.append(k % S)
		k /= S
	return p


static func layout(c: Dictionary, r: RandomNumberGenerator) -> Dictionary[String, Variant]:
	var bl: Array = [{h = true, len = 2, fix = ROW}]
	var p: Array[int] = [int(r.randf() * 3)]
	var nb: Array = c.nb
	var want: int = int(nb[0]) + int(r.randf() * (int(nb[1]) - int(nb[0]) + 1))
	var t_ := 0
	while t_ < 300 and bl.size() < want:
		t_ += 1
		var h := r.randf() < 0.5
		var ln := 2 if r.randf() < 0.72 else 3
		var fix := int(r.randf() * S)
		var q := int(r.randf() * (S - ln + 1))
		if h and fix == ROW:
			continue
		var b := {h = h, len = ln, fix = fix}
		var g := occ(bl, p)
		var ok := true
		for k in ln:
			if g[cell_of(b, q, k)] >= 0:
				ok = false
		if ok:
			bl.append(b)
			p.append(q)
	var out: Dictionary[String, Variant] = {}
	out.assign({B = bl, pos = p})
	return out


## Each block's cells at each place along its line as bits of the 6x6 tray (`occ`), and the cell
## each place takes first (`bit`), for `component`'s inner loop.
static func _bits(bl: Array) -> Array[PackedInt64Array]:
	var occ := PackedInt64Array()
	var bit := PackedInt64Array()
	for b: Dictionary in bl:
		for p in S:
			var cell: int = int(b.fix) * S + p if b.h else p * S + int(b.fix)
			bit.append(1 << cell)
			var m := 0
			if p + int(b.len) <= S:
				for c in int(b.len):
					m |= 1 << (int(b.fix) * S + p + c if b.h else (p + c) * S + int(b.fix))
			occ.append(m)
	return [occ, bit]


## Every state the start can reach (moves are reversible) and each one's distance to the goal; {} past `cap`.
static func component(bl: Array, pos0: Array[int], cap: int) -> Dictionary[String, Variant]:
	var out: Dictionary[String, Variant] = {}
	var nb := bl.size()
	var w := weights(nb)
	var ln := PackedInt32Array()
	for b: Dictionary in bl:
		ln.append(int(b.len))
	var bits := _bits(bl)
	var occ := bits[0]
	var bit := bits[1]
	var keys := {}
	var states := PackedInt64Array([enc(pos0, w)])
	keys[states[0]] = 0
	var edges := PackedInt32Array()
	var eblk := PackedInt32Array()
	var st := PackedInt32Array()
	var en := PackedInt32Array()
	var pos := PackedInt32Array()
	pos.resize(nb)
	var i := 0
	while i < states.size():
		var k0 := states[i]
		var kk := k0
		var m := 0
		for c in nb:
			var p := kk % S
			kk /= S
			pos[c] = p
			m |= occ[c * S + p]
		st.append(edges.size())
		for b in nb:
			var pb := pos[b]
			var at := b * S
			var wb := w[b]
			# the page's order (down the line, then up), so states number alike
			var q := pb - 1
			while q >= 0 and not (m & bit[at + q]):
				var k := k0 + (q - pb) * wb
				var j: int = keys.get(k, -1)
				if j < 0:
					if states.size() >= cap:
						return out
					j = states.size()
					keys[k] = j
					states.append(k)
				edges.append(j)
				eblk.append(b)
				q -= 1
			var l := ln[b]
			q = pb + 1
			while q + l <= S and not (m & bit[at + q + l - 1]):
				var k := k0 + (q - pb) * wb
				var j: int = keys.get(k, -1)
				if j < 0:
					if states.size() >= cap:
						return out
					j = states.size()
					keys[k] = j
					states.append(k)
				edges.append(j)
				eblk.append(b)
				q += 1
		en.append(edges.size())
		i += 1
	var dist := PackedInt32Array()
	dist.resize(states.size())
	dist.fill(-1)
	var qq := PackedInt32Array()
	for si in states.size():
		if states[si] % S == GOAL:
			dist[si] = 0
			qq.append(si)
	var hd := 0
	while hd < qq.size():
		var a := qq[hd]
		hd += 1
		for e in range(st[a], en[a]):
			var j := edges[e]
			if dist[j] < 0:
				dist[j] = dist[a] + 1
				qq.append(j)
	out.assign({states = states, dist = dist, nb = nb, edges = edges, eblk = eblk, st = st, en = en, w = w})
	return out


## The fewest moves out from state `si` with block `lk` bolted until `nn` moves are made (a move slides
## one block; sliding the same block again is the same move): {dist, path}, or {} past the cap. Walks
## the component's moves in the page's order, so ties break alike.
static func solve_in(comp: Dictionary, si: int, lk: int, nn: int, cap: int = 300000) -> Dictionary[String, Variant]:
	var out: Dictionary[String, Variant] = {}
	var states: PackedInt64Array = comp.states
	if states[si] % S == GOAL:
		out.assign({dist = 0, path = []})
		return out
	var edges: PackedInt32Array = comp.edges
	var eblk: PackedInt32Array = comp.eblk
	var st: PackedInt32Array = comp.st
	var en: PackedInt32Array = comp.en
	var w: Array[int] = comp.w
	var nstate := PackedInt32Array([si])
	var nmade := PackedInt32Array([0])
	var nlast := PackedInt32Array([-1])
	var npar := PackedInt32Array([-1])
	var nmove := PackedInt32Array([-1])
	var seen := {}
	seen[si * 256 + _tag(0, -1, nn)] = true
	var fr := PackedInt32Array([0])
	var d := 0
	while not fr.is_empty():
		var nx := PackedInt32Array()
		d += 1
		for ni in fr:
			var s0 := nstate[ni]
			var made := nmade[ni]
			var locked := lk if made < nn else -1
			var nk := mini(nn, made + 1)
			var last := nlast[ni]
			for e in range(st[s0], en[s0]):
				var b := eblk[e]
				if b == locked or b == last:
					continue
				var j := edges[e]
				var q := (states[j] / w[b]) % S
				if b == 0 and q == GOAL:
					var path: Array = [Vector2i(b, q)]
					var at := ni
					while at >= 0 and nmove[at] >= 0:
						path.push_front(Vector2i(nmove[at] >> 4, nmove[at] & 15))
						at = npar[at]
					out.assign({dist = d, path = path})
					return out
				var key := j * 256 + _tag(nk, b, nn)
				if not seen.has(key):
					seen[key] = true
					nstate.append(j)
					nmade.append(nk)
					nlast.append(b)
					npar.append(ni)
					nmove.append((b << 4) | q)
					nx.append(nstate.size() - 1)
					if seen.size() > cap:
						return out
		fr = nx
	return out


static func _tag(k: int, lst: int, nn: int) -> int:
	return k * 16 + lst + 1 if k < nn else 255


static func shuffled(src: Array[int], r: RandomNumberGenerator) -> Array[int]:
	var a: Array[int] = src.duplicate()
	for i in range(a.size() - 1, 0, -1):
		var j := int(r.randf() * (i + 1))
		var tmp := a[i]
		a[i] = a[j]
		a[j] = tmp
	return a


## {B, pos, par, lock, N, first, path}; {} if none came.
static func gen(d: int, r: RandomNumberGenerator) -> Dictionary[String, Variant]:
	var c: Dictionary = CFG[d]
	var out: Dictionary[String, Variant] = {}
	for att in 400:
		var lay := layout(c, r)
		var bl: Array = lay.B
		var comp := component(bl, lay.pos, 15000)
		if comp.is_empty():
			continue
		var dist: PackedInt32Array = comp.dist
		var best := -1
		for dd in dist:
			if dd <= int(c.hi) and dd > best:
				best = dd
		if best < int(c.lo):
			continue
		var cand: Array[int] = []
		for i in dist.size():
			if dist[i] == best:
				cand.append(i)
		var si := cand[int(r.randf() * cand.size())]
		var start := dec(int(comp.states[si]), bl.size())
		var par := best
		var lock := -1
		if int(c.lock):
			var bi := -1
			var bd := -1
			var others: Array[int] = []
			for i in range(1, bl.size()):
				others.append(i)
			for b in shuffled(others, r):
				var rs := solve_in(comp, si, b, int(c.lock))
				if not rs.is_empty() and int(rs.dist) > par and int(rs.dist) <= int(c.hi) + 3 and (bi < 0 or int(rs.dist) > bd):
					bi = b
					bd = rs.dist
			if bi < 0:
				continue
			lock = bi
			par = bd
		var nn := 0 if lock < 0 else int(c.lock)
		var sol := solve_in(comp, si, lock, nn)
		if sol.is_empty() or int(sol.dist) != par:
			continue
		var path: Array = sol.path
		out.assign({B = bl, pos = start, par = par, lock = lock, N = nn, first = path[0], path = path})
		return out
	return out


static func score_of(mv: int, par: int) -> float:
	return clampf(0.15 + 0.85 * pow(minf(1.0, float(par) / maxf(1.0, mv)), 1.3), 0.0, 1.0)


# ---------------------------------------------------------------- the game

func _mount() -> void:
	px = MiniPix.new(W, H)
	P = _deal()
	if P.is_empty():
		push_error("GameTray: no puzzle at depth %d" % depth)
		over = true
		done(0.0, "No puzzle")
		return
	B = P.B
	pos.assign(P.pos)
	for v in pos:
		vis.append(float(v))
	undos = 2 + sensors
	show_hint = sensors >= 2
	_plate = _draw_plate()
	_draw()


## A deal searched on a worker while the desk's card is up (the search can take seconds at sector 5);
## the mount that asks for it waits out what is left.
static func prefetch(d: int, r: RandomNumberGenerator) -> void:
	settle()
	if not memo_on:
		memo.clear()
	var key := "%d:%d:%d" % [d, r.seed, r.state]
	_pre_key = key
	_pre_task = WorkerThreadPool.add_task(func() -> void:
		var got := gen(d, r)
		GameTray._pre_got = {P = got, end = r.state})


## Waits for the worker's deal, if one is out, and files it under its key.
static func settle() -> void:
	if _pre_task < 0:
		return
	WorkerThreadPool.wait_for_task_completion(_pre_task)
	_pre_task = -1
	memo[_pre_key] = _pre_got
	_pre_got = {}


## `gen`, or the deal already searched for this stream (a prefetch, or with `memo_on` an earlier
## mount in a test), the stream left where the search left it.
func _deal() -> Dictionary[String, Variant]:
	var key := "%d:%d:%d" % [depth, rng.seed, rng.state]
	if key == _pre_key:
		settle()
	if memo.has(key):
		var m: Dictionary = memo[key]
		if not memo_on:
			memo.erase(key)
		rng.state = int(m.end)
		var got: Dictionary[String, Variant] = {}
		got.assign(Dictionary(m.P).duplicate(true))
		return got
	var p := gen(depth, rng)
	if memo_on:
		memo[key] = {P = p.duplicate(true), end = rng.state}
	return p


func _lock_on() -> bool:
	return int(P.lock) >= 0 and moves_ < int(P.N)


func _draw_plate() -> Image:
	var b := MiniPix.new(W, H)
	b.rect(0, 0, W, H, MiniPix.PANEL)
	b.rect(GX - 4, GY - 4, S * C + 8, 2, MiniPix.BEVEL_HI)
	b.rect(GX - 4, GY - 4, 2, S * C + 8, MiniPix.BEVEL_HI)
	b.rect(GX - 4, GY + S * C + 2, S * C + 8, 2, MiniPix.BEVEL_LO)
	b.rect(GX + S * C + 2, GY - 4, 2, S * C + 8, MiniPix.BEVEL_LO)
	b.rect(GX - 2, GY - 2, S * C + 4, S * C + 4, MiniPix.LINE)
	var plate_lit := MiniPix.shade(MiniPix.PANEL, 0.1)
	for y in S * C:
		for x in S * C:
			var xx := GX + x
			var yy := GY + y
			var cx := x % C
			var cy := y % C
			var col := MiniPix.PANEL if MiniPix.bay(xx, yy) < 0.18 else MiniPix.VOID
			if cx == 0 or cy == 0:
				col = MiniPix.BEVEL_LO
			elif cx == 1 or cy == 1:
				col = MiniPix.LINE
			if absi(cx - (C >> 1)) <= 1 and absi(cy - (C >> 1)) <= 1:
				col = MiniPix.BEVEL_LO if cx == C >> 1 and cy == C >> 1 else plate_lit
			b.dot(xx, yy, col)
	b.rect(GX + S * C - 1, EXY + 1, 6, C - 2, MiniPix.VOID)
	for x in range(GX + S * C + 5, W - 1):
		b.dot(x, EXY - 1, MiniPix.BEVEL_LO)
		b.dot(x, EXY + C - 1, MiniPix.BEVEL_LO)
		b.dot(x, EXY, MiniPix.BEVEL_HI)
		for y in range(EXY + 1, EXY + C - 1):
			b.dot(x, y, MiniPix.LINE if (y - EXY) % 4 == 2 else MiniPix.VOID)
	return b.img


## A canister across `len` cells from (x, y) (top-left of its span): steel, a bolted one with hazard
## bands, or the sample, a glass tube with a glowing core between ember caps.
func _canister(x: float, y: float, ln: int, h: bool, kind: String, is_sel: bool) -> Rect2i:
	var l := ln * C - 2
	var tt := T
	var w := l if h else tt
	var ht := tt if h else l
	var xx := MiniPix.jr(x) + 1
	var yy := MiniPix.jr(y) + 1
	for j in ht:
		for i in w:
			var edge := i == 0 or j == 0 or i == w - 1 or j == ht - 1
			if (i == 0 or i == w - 1) and (j == 0 or j == ht - 1):
				continue
			var a := j if h else i
			var along := i if h else j
			var alen := w if h else ht
			var col: Color
			if edge:
				col = MiniPix.BEVEL_LO
			elif kind == "sample":
				col = _sample_px(a, along, alen)
			else:
				col = STEEL[mini(8, a * 9 / tt)]
				if along < 3 or along > alen - 4:
					col = MiniPix.shade(col, -0.35)
				if along == 3 or along == alen - 4:
					col = MiniPix.BEVEL_LO
				var mid := (T - 1) >> 1
				if (along == 1 or along == alen - 2) and a == mid:
					col = MiniPix.CHILL
				if kind == "bolt" and a > mid - 2 and a < mid + 2 and along % 6 == 0 and along > 3 and along < alen - 4:
					col = MiniPix.WARN
			px.dot(xx + i, yy + j, col)
	if is_sel:
		px.rect(xx - 1, yy - 2, w + 2, 1, MiniPix.EMBER)
		px.rect(xx - 1, yy + ht + 1, w + 2, 1, MiniPix.EMBER)
		px.rect(xx - 2, yy - 1, 1, ht + 2, MiniPix.EMBER)
		px.rect(xx + w + 1, yy - 1, 1, ht + 2, MiniPix.EMBER)
	return Rect2i(xx, yy, w, ht)


func _sample_px(a: int, along: int, alen: int) -> Color:
	if along < 4 or along > alen - 5:
		return MiniPix.HOT if a < 3 else (MiniPix.FLARE if a < T - 5 else (MiniPix.EMBER if a < T - 2 else MiniPix.shade(MiniPix.EMBER, -0.4)))
	if a == 1 or a == T - 2:
		return MiniPix.shade(MiniPix.TRACTOR, -0.5)
	if a == 2:
		return MiniPix.ICE
	var f := absf(a - T / 2.0) / ((T - 4) / 2.0)
	var col := MiniPix.MARK if f < 0.35 else (MiniPix.TRACTOR if f < 0.75 else MiniPix.shade(MiniPix.TRACTOR, -0.35))
	if (along * 7 + a * 3) % 23 == 0:
		col = MiniPix.MARK
	return col


func _cell_xy(i: int, v: float) -> Vector2:
	var bk: Dictionary = B[i]
	return Vector2(GX + (v if bk.h else float(bk.fix)) * C, GY + (float(bk.fix) if bk.h else v) * C)


func range_of(i: int) -> Vector2i:
	if i == int(P.lock) and _lock_on():
		return Vector2i(pos[i], pos[i])
	var bk: Dictionary = B[i]
	var gr := occ(B, pos)
	var lo := pos[i]
	var hi := pos[i]
	while lo - 1 >= 0 and gr[cell_of(bk, lo - 1, 0)] < 0:
		lo -= 1
	while hi + 1 + int(bk.len) <= S and gr[cell_of(bk, hi + 1, int(bk.len) - 1)] < 0:
		hi += 1
	return Vector2i(lo, hi)


func _draw() -> void:
	px.img.blit_rect(_plate, Rect2i(0, 0, W, H), Vector2i.ZERO)
	if show_hint and moves_ == 0 and not over:
		var f: Vector2i = P.first
		var bk: Dictionary = B[f.x]
		var at := _cell_xy(f.x, f.y)
		var w := int(bk.len) * C if bk.h else C
		var h := C if bk.h else int(bk.len) * C
		for k in range(0, w, 2):
			px.dotf(at.x + k, at.y, MiniPix.HOT)
			px.dotf(at.x + k, at.y + h - 1, MiniPix.HOT)
		for k in range(0, h, 2):
			px.dotf(at.x, at.y + k, MiniPix.HOT)
			px.dotf(at.x + w - 1, at.y + k, MiniPix.HOT)
	for i in B.size():
		var bk: Dictionary = B[i]
		var at := _cell_xy(i, vis[i])
		var w := int(bk.len) * C - 2 if bk.h else C - 2
		var h := C - 2 if bk.h else int(bk.len) * C - 2
		for j in h:
			for k in w:
				# `bay(x + k, y + j)` on a gliding canister: JS's `&` truncates the fraction
				if MiniPix.bay(int(at.x + k), int(at.y + j)) < 0.5:
					px.dot(MiniPix.jr(at.x) + 2 + k, MiniPix.jr(at.y) + 2 + j, MiniPix.BEVEL_LO)
	for i in B.size():
		if i == 0 and out_t >= 0.0:
			continue
		var bk: Dictionary = B[i]
		var at := _cell_xy(i, vis[i])
		var kind := "sample" if i == 0 else ("bolt" if i == int(P.lock) else "steel")
		var r := _canister(at.x, at.y, int(bk.len), bk.h, kind, i == sel and not over)
		if i == int(P.lock) and _lock_on():
			var cx := r.position.x + (r.size.x >> 1)
			var cy := r.position.y + (r.size.y >> 1)
			px.rect(cx - 4, cy - 4, 9, 9, MiniPix.BEVEL_LO)
			px.rect(cx - 3, cy - 3, 7, 7, MiniPix.CHILL)
			px.rect(cx - 3, cy + 2, 7, 1, MiniPix.COLD)
			px.rect(cx + 2, cy - 3, 1, 7, MiniPix.COLD)
			px.text(str(int(P.N) - moves_), cx - 1, cy - 2, MiniPix.VOID)
	if sel >= 0 and not over and drag.is_empty():
		var rg := range_of(sel)
		var bk: Dictionary = B[sel]
		if rg.x < pos[sel]:
			_arrow(sel, pos[sel] - 1, -1)
		if rg.y > pos[sel]:
			_arrow(sel, pos[sel] + int(bk.len), 1)
	if out_t >= 0.0:
		_leaving()
	_hud()
	if not started:
		# the top spot: the middle hides the sample's row
		MiniKit.tell(px, "GET THE SAMPLE OUT.", controls(), clock, MiniKit.TELL_TOP)
	draw_toast()
	dirty = true


func _leaving() -> void:
	var tt := minf(1.0, (clock - out_t) / 1.1)
	var e := tt * tt
	var x := GX + GOAL * C + e * (W - (GX + GOAL * C) + 4)
	var y := float(GY + ROW * C)
	var keep := px.img.duplicate() as Image
	_canister(x, y, 2, true, "sample", false)
	# the prototype clips the canister to the screen less its last two columns
	px.img.blit_rect(keep, Rect2i(W - 2, 0, 2, H), Vector2i(W - 2, 0))
	px.rect(W - 3, EXY - 2, 1, C + 3, MiniPix.BEVEL_HI)
	px.rect(W - 2, EXY - 2, 2, C + 3, MiniPix.BEVEL_LO)


func _hud() -> void:
	MiniKit.header(px, null, [["MOVES", moves_], ["PAR", int(P.par)]])
	var can := undos > 0 and not hist.is_empty() and not over
	MiniKit.button(px, UB.position.x, UB.position.y, UB.size.x, UB.size.y, "UNDO %d" % undos,
		"disabled" if not can else ("pressed" if undo_down else "normal"))


func _arrow(i: int, cell: int, dir: int) -> void:
	var bk: Dictionary = B[i]
	var at := Vector2i(GX + cell * C, GY + int(bk.fix) * C) if bk.h else Vector2i(GX + int(bk.fix) * C, GY + cell * C)
	var cx := at.x + (C >> 1)
	var cy := at.y + (C >> 1)
	for k in 4:
		if bk.h:
			px.rect(cx + (k - 2 if dir > 0 else 2 - k), cy - 3 + k, 1, 7 - 2 * k, MiniPix.EMBER)
		else:
			px.rect(cx - 3 + k, cy + (k - 2 if dir > 0 else 2 - k), 7 - 2 * k, 1, MiniPix.EMBER)


func _tick(dt: float) -> void:
	_acc += dt
	if _acc < 1.0 / 30.0:
		return
	var step := minf(0.1, _acc)
	_acc = 0.0
	clock += step
	for i in B.size():
		if not drag.is_empty() and int(drag.i) == i and drag.moved:
			continue
		var d := pos[i] - vis[i]
		vis[i] = float(pos[i]) if absf(d) < 0.02 else vis[i] + d * minf(1.0, step * 18.0)
	if not wob.is_empty():
		wob.t += step
		if float(wob.t) > 0.3:
			vis[int(wob.i)] = pos[int(wob.i)]
			wob = {}
		else:
			vis[int(wob.i)] = pos[int(wob.i)] + sin(float(wob.t) * 60.0) * 0.06 * (1.0 - float(wob.t) / 0.3)
	if drawing:
		_draw()


# ---------------------------------------------------------------- input

func hit_block(q: Vector2) -> int:
	for i in B.size():
		var bk: Dictionary = B[i]
		var at := _cell_xy(i, pos[i])
		var w := int(bk.len) * C if bk.h else C
		var h := C if bk.h else int(bk.len) * C
		if q.x >= at.x and q.x < at.x + w and q.y >= at.y and q.y < at.y + h:
			return i
	return -1


func _in_undo(q: Vector2) -> bool:
	return q.x >= UB.position.x - 2 and q.x <= UB.end.x + 2 and q.y >= UB.position.y - 2 and q.y <= UB.end.y + 2


func down(_p: Vector2i) -> void:
	if over:
		return
	var q := pf
	started = true
	if _in_undo(q):
		undo_down = true
		return
	var i := hit_block(q)
	if i >= 0:
		var bk: Dictionary = B[i]
		drag = {i = i, a0 = q.x if bk.h else q.y, v0 = pos[i], moved = false, rng = range_of(i)}
		var rg: Vector2i = drag.rng
		if rg.x == rg.y and i == int(P.lock) and _lock_on():
			wob = {i = i, t = 0.0}
		return
	var cx := int(floorf((q.x - GX) / C))
	var cy := int(floorf((q.y - GY) / C))
	if sel >= 0 and cx >= 0 and cy >= 0 and cx < S and cy < S:
		var bk: Dictionary = B[sel]
		var rg := range_of(sel)
		var along := cx if bk.h else cy
		var across := cy if bk.h else cx
		if across == int(bk.fix):
			if along == pos[sel] - 1 and rg.x < pos[sel]:
				commit(sel, pos[sel] - 1)
				return
			if along == pos[sel] + int(bk.len) and rg.y > pos[sel]:
				commit(sel, pos[sel] + 1)
				return
	sel = -1


func move(_p: Vector2i) -> void:
	if drag.is_empty():
		return
	var q := pf
	var bk: Dictionary = B[int(drag.i)]
	var d := ((q.x if bk.h else q.y) - float(drag.a0)) / C
	if not drag.moved and absf(d) * C > 2.5:
		drag.moved = true
	if drag.moved:
		var v := float(drag.v0) + d
		var rg: Vector2i = drag.rng
		var top := float(rg.y)
		if int(drag.i) == 0 and rg.y == GOAL:
			top = GOAL + 0.35
		v = maxf(rg.x - 0.12, minf(top + 0.12, v))
		if v < rg.x:
			v = rg.x - (rg.x - v) * 0.4
		if v > top:
			v = top + (v - top) * 0.4
		vis[int(drag.i)] = v


func up(_p: Vector2i, cancel := false) -> void:
	if undo_down:
		undo_down = false
		if not cancel and _in_undo(pf):
			undo()
		return
	if drag.is_empty():
		return
	var d := drag
	drag = {}
	if not d.moved:
		sel = -1 if sel == int(d.i) else int(d.i)
		return
	var rg: Vector2i = d.rng
	var nv := clampi(MiniPix.jr(vis[int(d.i)]), rg.x, rg.y)
	if nv != pos[int(d.i)]:
		commit(int(d.i), nv)
	else:
		sel = int(d.i)


func commit(i: int, np: int) -> void:
	hist.append({pos = pos.duplicate(), moves = moves_, last = last})
	pos[i] = np
	if i != last:
		moves_ += 1
		last = i
	sfx(&"slide")
	if pos[0] == GOAL:
		over = true
		sel = -1
		vis[0] = GOAL
		out_t = clock + 0.05
		sfx(&"out")
		sfx(&"win")
		say_end("SAMPLE OUT", "good")
		done(score_of(moves_, int(P.par)), "Out in %d moves (par %d)" % [moves_, int(P.par)])
		return
	sel = i


func undo() -> void:
	if over or undos <= 0 or hist.is_empty():
		return
	var h: Dictionary = hist.pop_back()
	pos.assign(h.pos)
	moves_ = h.moves
	last = h.last
	undos -= 1
	sel = -1


func give_up() -> void:
	if over:
		return
	over = true
	done(0.0, "Gave up")
