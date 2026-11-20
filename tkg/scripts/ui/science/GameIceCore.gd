class_name GameIceCore
extends MiniGame

## ICE CORE (Jon, Nov 17: "brilliant"): short ice cores overlap; stack their layers in the tube in
## the order they fell, oldest at the bottom, and CHECK. A port of the approved `icecore2.js`.
## Why: docs/why/MiniGame.md#the-round-2-games

const CFG := {
	1: {n = 6, flip = 0, gap = 0},
	2: {n = 7, flip = 0, gap = 0},
	3: {n = 8, flip = 1, gap = 0},
	4: {n = 9, flip = 1, gap = 1},
	5: {n = 10, flip = 1, gap = 1},
}
## Each layer kind's texture: 0 plain, 1 dots, 2 stripes, 3 cross.
const TEX: Array[int] = [0, 1, 2, 0, 3, 1, 2, 0, 3, 2]
const KC: Array[Color] = [MiniPix.ICE, MiniPix.BEVEL_HI, MiniPix.WARN, Color("#6a9ad4"), MiniPix.GOOD, MiniPix.BAD,
	MiniPix.HOT, Color("#8b4fd4"), Color("#d99b29"), MiniPix.TRACTOR]
const CHECK_SCORE: Array[float] = [1.0, 0.75, 0.58, 0.48, 0.42]
const W := 144
const H := 120
## Cores, the stack tube, the tray of loose layers, the buttons.
const CX0 := 16
const CDX := 16
const CW := 12
const LH := 7
const GH := 5
const CB := 62
const SX := 104
const SW := 24
const SH := 8
const SB := 96
const PX0 := 4
const PDX := 18
const PW := 16
const PHH := 10
const PY0 := 80
const PDY := 13
const BY := 106
const BH := 12
const BCL := Vector2i(91, 26)
const BCK := Vector2i(118, 26)
const ZZ: Array[int] = [2, 1, 3, 1, 2, 3, 1, 2, 3, 2, 1, 3, 2, 1]
const TICK: Array[String] = ["....#", "...#.", "#.#..", ".#...", "....."]
const CROSS: Array[String] = ["#...#", ".#.#.", "..#..", ".#.#.", "#...#"]

var p: Dictionary = {}
var n := 6
var checks := 3
var given := {}
var slots: Array[int] = []
var marks: Array[String] = []
var placed_at: Array[float] = []
var pal_kinds: Array[int] = []
var used := 0
var ended := false
var acted := false
var last_frac := 0.0
var msg := ""
var win_at := 0.0
var pressed := ""
## A held piece: {from "pal"|"slot", kind, idx, sx, sy, x, y, moved, over}, or a held button {btn}.
var drag: Dictionary = {}
var _frame := -1


func id() -> StringName:
	return &"icecore"


func hint() -> String:
	return "Stack the layers in order."


func controls() -> Array[String]:
	return ["click", "drag"]


# ---------------------------------------------------------------- the rules

static func shuffled(src: Array[int], r: RandomNumberGenerator) -> Array[int]:
	var a: Array[int] = src.duplicate()
	for i in range(a.size() - 1, 0, -1):
		var j := int(r.randf() * (i + 1))
		var tmp := a[i]
		a[i] = a[j]
		a[j] = tmp
	return a


static func rint(r: RandomNumberGenerator, lo: int, hi: int) -> int:
	return lo + int(r.randf() * (hi - lo + 1))


## A core as seen: flipped, its layers run newest first and its crack moves with them.
static func orient(core: Dictionary, flip: bool) -> Dictionary[String, Variant]:
	var out: Dictionary[String, Variant] = {}
	out.assign(core)
	if not flip:
		return out
	var l: Array[int] = []
	l.assign(core.layers)
	l.reverse()
	out.assign({layers = l, gap = -1 if int(core.gap) < 0 else l.size() - int(core.gap)})
	return out


## Every full order the cores allow (up to `limit`), given exactly `flips` cores upside down.
static func solve(nn: int, cores: Array[Dictionary], flips: int, limit: int = 2) -> Array[String]:
	var found: Array[String] = []
	# the prototype's union-find is sized by layer count, so a core holding a kind numbered n or more
	# never solves there: it only ever deals the first n kinds, and this keeps that
	for c in cores:
		for v: int in c.layers:
			if v >= nn:
				return found
	var choices: Array = [[]] if flips == 0 else range(cores.size()).map(func(i: int) -> Array: return [i])
	for ch: Array in choices:
		var oc: Array[Dictionary] = []
		for i in cores.size():
			oc.append(orient(cores[i], ch.has(i)))
		var comps := _components(nn, oc)
		if comps.is_empty():
			continue
		var pos: Array[int] = []
		pos.resize(nn)
		pos.fill(-1)
		_place(comps, 0, pos, nn, found, limit)
		if found.size() >= limit:
			break
	return found


## The cores' layers as rigid groups of (layer, offset), largest first; [] if the cores disagree.
static func _components(nn: int, oc: Array[Dictionary]) -> Array[Array]:
	var par: Array[int] = []
	var off: Array[int] = []
	for i in nn:
		par.append(i)
		off.append(0)
	for c in oc:
		var l: Array = c.layers
		for k in range(1, l.size()):
			var a: int = l[k - 1]
			var b: int = l[k]
			var d := 2 if int(c.gap) == k else 1
			var ra := _find(a, par, off)
			var rb := _find(b, par, off)
			if ra == rb:
				if off[b] - off[a] != d:
					return [] as Array[Array]
			else:
				par[rb] = ra
				off[rb] = off[a] + d - off[b]
	var groups := {}
	var order: Array[int] = []
	for i in nn:
		var r := _find(i, par, off)
		if not groups.has(r):
			groups[r] = []
			order.append(r)
		(groups[r] as Array).append(Vector2i(i, off[i]))
	# JS walks an object keyed by the root: integer keys come out in numeric order
	order.sort()
	var list: Array = []
	for r in order:
		var cp: Array = groups[r]
		var m := 1 << 30
		for e: Vector2i in cp:
			m = mini(m, e.y)
		var seen := {}
		var norm: Array = []
		for e: Vector2i in cp:
			norm.append(Vector2i(e.x, e.y - m))
			seen[e.y - m] = true
		if seen.size() != cp.size():
			return [] as Array[Array]
		list.append(norm)
	# JS sorts by size, largest first (a stable sort: ties keep their order)
	var idx := range(list.size())
	idx.sort_custom(func(a: int, b: int) -> bool: return (list[a] as Array).size() > (list[b] as Array).size() or ((list[a] as Array).size() == (list[b] as Array).size() and a < b))
	var out: Array[Array] = []
	for i: int in idx:
		out.append(list[i])
	return out


static func _find(x: int, par: Array[int], off: Array[int]) -> int:
	if par[x] == x:
		return x
	var r := _find(par[x], par, off)
	off[x] += off[par[x]]
	par[x] = r
	return r


static func _place(list: Array, ci: int, pos: Array[int], nn: int, found: Array[String], limit: int) -> void:
	if found.size() >= limit:
		return
	if ci == list.size():
		var key := ",".join(pos.map(func(v: int) -> String: return str(v)))
		if not found.has(key):
			found.append(key)
		return
	var cp: Array = list[ci]
	var span := 0
	for e: Vector2i in cp:
		span = maxi(span, e.y)
	for s in nn - span:
		var free := true
		for e: Vector2i in cp:
			if pos[s + e.y] >= 0:
				free = false
				break
		if not free:
			continue
		for e: Vector2i in cp:
			pos[s + e.y] = e.x
		_place(list, ci + 1, pos, nn, found, limit)
		for e: Vector2i in cp:
			pos[s + e.y] = -1


## {n, truth (kind at each depth, oldest first), cores, flipped, flips, gaps}; {} if none came.
static func gen(r: RandomNumberGenerator, d: int) -> Dictionary[String, Variant]:
	var c: Dictionary = CFG.get(d, CFG[1])
	var nn: int = c.n
	var out: Dictionary[String, Variant] = {}
	var all: Array[int] = []
	for i in 10:
		all.append(i)
	for tries in 2000:
		var truth := shuffled(all, r).slice(0, nn)
		var wins: Array[Vector2i] = []
		var pos := 0
		while true:
			var ln := 3 if nn <= 7 else rint(r, 3, 4)
			var e := mini(nn - 1, pos + ln - 1)
			wins.append(Vector2i(maxi(0, e - ln + 1), e))
			if e >= nn - 1:
				break
			pos = e - rint(r, 1 if int(c.flip) else 0, 1)
		if wins.size() < 3 or wins.size() > 5:
			continue
		var cores: Array[Dictionary] = []
		for w in wins:
			cores.append({layers = truth.slice(w.x, w.y + 1), gap = -1})
		if int(c.gap):
			var cand: Array[int] = []
			for i in cores.size():
				if (cores[i].layers as Array).size() >= 4:
					cand.append(i)
			if cand.is_empty():
				continue
			var gi := cand[int(r.randf() * cand.size())]
			var l: Array[int] = cores[gi].layers
			var k := rint(r, 1, l.size() - 2)
			var cut: Array[int] = l.slice(0, k)
			cut.append_array(l.slice(k + 1))
			cores[gi] = {layers = cut, gap = k}
		var flipped := -1
		if int(c.flip):
			flipped = int(r.randf() * cores.size())
			cores[flipped] = orient(cores[flipped], true)
		var seen := {}
		for co in cores:
			for v: int in co.layers:
				seen[v] = true
		if seen.size() != nn:
			continue
		var sols := solve(nn, cores, int(c.flip), 2)
		if sols.size() != 1 or sols[0] != ",".join(truth.map(func(v: int) -> String: return str(v))):
			continue
		var idx: Array[int] = []
		for i in cores.size():
			idx.append(i)
		var order := shuffled(idx, r)
		var dealt: Array[Dictionary] = []
		for i in order:
			dealt.append(cores[i])
		out.assign({n = nn, truth = truth, cores = dealt, flipped = order.find(flipped), flips = int(c.flip), gaps = int(c.gap)})
		return out
	return out


static func score(solved_at: int, frac: float) -> float:
	return CHECK_SCORE[mini(solved_at, 5) - 1] if solved_at > 0 else 0.3 * frac


## The prototype's hash for each layer's trapped bubbles, its 32-bit wraps and its double products kept.
static func hash3(a: int, b: int, c: int) -> float:
	var h := (a * 73856093) ^ (b * 19349663) ^ (c * 83492791)
	h = h ^ (h >> 13)
	var m := fmod(float(h) * 1274126177.0, 4294967296.0)
	var u := int(m + 4294967296.0 if m < 0.0 else m)
	return float(u ^ (u >> 16)) / 4294967296.0


# ---------------------------------------------------------------- the game

func _mount() -> void:
	px = MiniPix.new(W, H)
	p = gen(rng, depth)
	if p.is_empty():
		push_error("GameIceCore: no puzzle at depth %d" % depth)
		ended = true
		done(0.0, "No puzzle")
		return
	n = p.n
	checks = 3 + (1 if sensors >= 2 else 0) + (1 if sensors >= 4 else 0)
	if sensors >= 1:
		given[0] = true
	if sensors >= 3:
		given[n - 1] = true
	if sensors >= 5:
		given[n / 2] = true
	slots.resize(n)
	slots.fill(-1)
	for i: int in given:
		slots[i] = int(p.truth[i])
	marks.resize(n)
	marks.fill("")
	placed_at.resize(n)
	placed_at.fill(0.0)
	pal_kinds = shuffled(p.truth, rng)
	_draw(_now())


func _tick(_dt: float) -> void:
	var f := int(floorf(t * 30.0))
	if f != _frame:
		_frame = f
		if drawing:
			_draw(_now())


func _now() -> float:
	return t * 1000.0 + 1.0


## One ice layer as part of a lit cylinder: highlight left, shadow right, light from the top.
func _layer(kind: int, x: int, y: int, w: int, h: int, lift: float) -> void:
	var iced := MiniPix.mix(KC[kind], MiniPix.ICE, 0.16)
	var tx := TEX[kind]
	var b := MiniPix.shade(iced, lift) if lift != 0.0 else iced
	for i in w:
		var f := 0.0
		if i == 0:
			f = 0.18
		elif i == 1:
			f = 0.42
		elif i == 2:
			f = 0.2
		elif i == w - 1:
			f = -0.42
		elif i == w - 2:
			f = -0.26
		elif i == w - 3:
			f = -0.1
		px.rect(x + i, y, 1, h, MiniPix.shade(b, f) if f != 0.0 else b)
	px.rect(x + 2, y, w - 4, 1, MiniPix.shade(b, 0.12))
	var dk := MiniPix.shade(b, -0.38)
	if tx == 1:
		for j in range(2, h - 1, 3):
			for i in range(3 + ((j / 3) % 2) * 2, w - 2, 4):
				px.rect(x + i, y + j, 1, 1, dk)
	elif tx == 2:
		for j in range(2, h, 3):
			px.rect(x + 2, y + j, w - 4, 1, MiniPix.shade(b, -0.24))
	elif tx == 3:
		for j in range(1, h):
			for i in range(2, w - 2):
				if (i + j) % 4 == 0:
					px.rect(x + i, y + j, 1, 1, dk)
	for i in 2:
		var hx := hash3(kind, i, 7)
		var hy := hash3(kind, i, 11)
		if hash3(kind, i, 3) < 0.6:
			px.rect(x + 3 + int(floorf(hx * (w - 6))), y + 1 + int(floorf(hy * (h - 2))), 1, 1, MiniPix.shade(b, 0.62))


func _crack(x: int, y: int, w: int) -> void:
	px.rect(x, y, w, GH, MiniPix.BEVEL_LO)
	for i in w:
		px.rect(x + i, y + ZZ[i % ZZ.size()], 1, 1, MiniPix.CHILL)


func _cap(x: int, y: int, w: int) -> void:
	px.rect(x, y, w, 2, MiniPix.COLD)
	px.dither(x + 1, y, w - 2, 2, MiniPix.CHILL, MiniPix.ICE, 0.35)


func _core(c: Dictionary, i: int) -> void:
	var x := CX0 + i * CDX
	var l: Array = c.layers
	var hgt := l.size() * LH + (GH if int(c.gap) >= 0 else 0)
	var top := CB - hgt
	px.rect(x - 1, top - 3, CW + 2, hgt + 6, MiniPix.BEVEL_LO)
	px.dither(x - 1, top - 1, 1, hgt + 2, MiniPix.BEVEL_LO, MiniPix.COLD, 0.3)
	px.dither(x + CW, top - 1, 1, hgt + 2, MiniPix.BEVEL_LO, MiniPix.LINE, 0.5)
	_cap(x, top - 2, CW)
	_cap(x, CB, CW)
	var y := CB
	for k in l.size():
		if int(c.gap) == k:
			y -= GH
			_crack(x, y, CW)
		y -= LH
		_layer(int(l[k]), x, y, CW, LH, 0.0)
		px.rect(x + 1, y + LH - 1, CW - 2, 1, MiniPix.shade(KC[int(l[k])], -0.3))
	px.text("C%d" % (i + 1), x + CW / 2, 12, MiniPix.CHILL, "center")


func _glyph(ok: bool, x: int, y: int, col: Color) -> void:
	var g: Array[String] = TICK if ok else CROSS
	for j in 5:
		for i in 5:
			if g[j][i] == "#":
				px.rect(x + i, y + j, 1, 1, col)


func _button(b: Vector2i, label: String, hot: bool, down_: bool) -> void:
	var x := b.x
	var w := b.y
	px.rect(x, BY, w, BH, MiniPix.BEVEL_LO)
	var face := MiniPix.EMBER if hot else MiniPix.PANEL
	px.rect(x + 1, BY + 1, w - 2, BH - 2, face)
	var lit := MiniPix.shade(face, -0.35) if down_ else (MiniPix.FLARE if hot else MiniPix.BEVEL_HI)
	px.rect(x + 1, BY + 1, w - 2, 1, lit)
	px.rect(x + 1, BY + 1, 1, BH - 2, lit)
	var lo := MiniPix.shade(face, 0.2) if down_ else MiniPix.shade(face, -0.4)
	px.rect(x + 1, BY + BH - 2, w - 2, 1, lo)
	px.rect(x + w - 2, BY + 1, 1, BH - 2, lo)
	px.text(label, x + w / 2 + (1 if down_ else 0), BY + 4 + (1 if down_ else 0), MiniPix.VOID if hot else MiniPix.COLD, "center")


static func slot_y(i: int) -> int:
	return SB - (i + 1) * SH


static func pal_xy(j: int) -> Vector2i:
	return Vector2i(PX0 + (j % 5) * PDX, PY0 + (j / 5) * PDY)


func _draw(now: float) -> void:
	var cores: Array = p.cores
	px.rect(0, 0, W, H, MiniPix.VOID)
	px.dither(0, H - 6, W, 6, MiniPix.VOID, MiniPix.PANEL, 0.5)
	var bx := CX0 - 3
	var bw := CDX * cores.size() + 2
	px.rect(bx, 18, bw, 49, MiniPix.PANEL)
	px.dither(bx, 18, bw, 6, MiniPix.PANEL, MiniPix.LINE, 0.5)
	px.rect(bx, 18, bw, 1, MiniPix.LINE)
	px.rect(bx, 18, 1, 49, MiniPix.LINE)
	if not acted:
		px.rect(0, 0, W, 8, MiniPix.PANEL)
		px.rect(0, 8, W, 1, MiniPix.LINE)
		px.text("STACK THE LAYERS IN ORDER", W / 2, 2, MiniPix.HOT, "center")
	else:
		px.text("CHECKS %d" % (checks - used), 2, 2, MiniPix.HOT)
		px.text("LAYERS %d" % n, 92, 2, MiniPix.COLD, "right")
	px.rect(CX0 - 4, CB + 3, CDX * cores.size() + 4, 2, MiniPix.BEVEL_HI)
	px.rect(CX0 - 4, CB + 5, CDX * cores.size() + 4, 1, MiniPix.BEVEL_LO)
	px.text("NEW", 1, 24, MiniPix.COLD)
	px.text("OLD", 1, 56, MiniPix.COLD)
	for y in range(31, 54):
		px.rect(6, y, 1, 1, MiniPix.LINE)
	px.rect(5, 31, 3, 1, MiniPix.LINE)
	for i in cores.size():
		_core(cores[i], i)
	var ny := 68
	if int(p.flips):
		px.text("ONE UPSIDE DOWN", CX0 - 4, ny, MiniPix.WARN)
		ny += 6
	if int(p.gaps):
		px.text("CRACK = 1 LOST", CX0 - 4, ny, MiniPix.CHILL)
	_tray()
	_tube(now)
	_button(BCL, "CLEAR", false, pressed == "clear")
	_button(BCK, "CHECK", not slots.has(-1) and not ended, pressed == "check")
	if not acted and msg == "":
		var w1 := px.icon("click", 2, 106, now / 1000.0)
		px.icon("drag", 2 + w1 + 4, 106, now / 1000.0)
	if msg != "":
		px.text(msg, 2, 114, MiniPix.GOOD if ended and win_at else MiniPix.HOT)
	if not drag.is_empty() and drag.has("kind") and drag.moved:
		var w := PW if drag.from == "pal" else SW
		var h := PHH if drag.from == "pal" else SH - 1
		var x := int(drag.x) - (w >> 1)
		var y := int(drag.y) - (h >> 1)
		px.rect(x - 1, y - 1, w + 2, h + 2, MiniPix.BEVEL_LO)
		_layer(int(drag.kind), x, y, w, h, 0.08)
	dirty = true


func _tray() -> void:
	var placed := {}
	for v in slots:
		if v >= 0:
			placed[v] = true
	for j in pal_kinds.size():
		var k := pal_kinds[j]
		var at := pal_xy(j)
		var lifted: bool = not drag.is_empty() and drag.get("from", "") == "pal" and drag.moved and int(drag.kind) == k
		if placed.has(k) or lifted:
			px.rect(at.x, at.y, PW, PHH, MiniPix.BEVEL_LO)
			px.dither(at.x + 1, at.y + 1, PW - 2, PHH - 2, MiniPix.VOID, MiniPix.LINE, 0.25)
			continue
		px.rect(at.x - 1, at.y - 1, PW + 2, PHH + 2, MiniPix.BEVEL_LO)
		_layer(k, at.x, at.y, PW, PHH, 0.0)


func _tube(now: float) -> void:
	var top := slot_y(n - 1)
	px.text("NEW", SX + SW / 2, top - 8, MiniPix.COLD, "center")
	px.rect(SX - 2, top - 2, SW + 4, n * SH + 4, MiniPix.BEVEL_LO)
	px.rect(SX - 1, top - 1, SW + 2, n * SH + 2, MiniPix.LINE)
	for i in n:
		var y := slot_y(i)
		var lifted: bool = not drag.is_empty() and drag.get("from", "") == "slot" and drag.moved and int(drag.idx) == i
		var show_k := -1 if lifted else slots[i]
		if show_k >= 0:
			var lift := 0.0
			if win_at:
				if absf((now - win_at) / 1000.0 - i * 0.09) < 0.18:
					lift = 0.45
			_layer(show_k, SX, y, SW, SH - 1, lift)
		else:
			px.rect(SX, y, SW, SH - 1, MiniPix.VOID)
			px.dither(SX + 1, y + 1, SW - 2, SH - 3, MiniPix.VOID, MiniPix.PANEL, 0.5)
			px.rect(SX, y, 1, SH - 1, MiniPix.shade(MiniPix.CHILL, -0.5))
		px.rect(SX, y + SH - 1, SW, 1, MiniPix.BEVEL_LO)
		px.rect(SX + 1, y, 1, SH - 1, MiniPix.shade(KC[show_k], 0.55) if show_k >= 0 else MiniPix.LINE)
		if placed_at[i] and now - placed_at[i] < 350.0:
			px.rect(SX - 1, y - 1, SW + 2, 1, MiniPix.FLARE)
			px.rect(SX - 1, y + SH - 1, SW + 2, 1, MiniPix.FLARE)
		if not drag.is_empty() and drag.has("kind") and drag.moved and int(drag.over) == i:
			px.rect(SX - 1, y - 1, SW + 2, 1, MiniPix.EMBER)
			px.rect(SX - 1, y + SH - 1, SW + 2, 1, MiniPix.EMBER)
			px.rect(SX - 1, y, 1, SH - 1, MiniPix.EMBER)
			px.rect(SX + SW, y, 1, SH - 1, MiniPix.EMBER)
		if given.has(i):
			px.rect(SX + SW + 3, y + 3, 2, 2, MiniPix.HOT)
		elif marks[i] != "":
			_glyph(marks[i] == "ok", SX + SW + 3, y + 1, MiniPix.GOOD if marks[i] == "ok" else MiniPix.BAD)
	px.text("OLD", SX + SW / 2, SB + 3, MiniPix.COLD, "center")


# ---------------------------------------------------------------- input

func hit_pal(x: int, y: int) -> int:
	var placed := {}
	for v in slots:
		if v >= 0:
			placed[v] = true
	for j in pal_kinds.size():
		var at := pal_xy(j)
		if x >= at.x - 1 and x <= at.x + PW and y >= at.y - 2 and y <= at.y + PHH + 1 and not placed.has(pal_kinds[j]):
			return j
	return -1


func hit_slot(x: int, y: int, loose := false) -> int:
	if x < SX - (6 if loose else 1) or x > SX + SW + (6 if loose else 1):
		return -1
	for i in n:
		var y0 := slot_y(i)
		if y >= y0 - 1 and y < y0 + SH:
			return i
	return -1


func hit_btn(x: int, y: int) -> String:
	if y < BY - 1 or y > BY + BH:
		return ""
	if x >= BCL.x and x < BCL.x + BCL.y:
		return "clear"
	if x >= BCK.x and x < BCK.x + BCK.y:
		return "check"
	return ""


func _put(at: int, k: int) -> void:
	sfx(&"place")
	slots[at] = k
	marks[at] = ""
	placed_at[at] = _now()
	msg = ""


func down(q: Vector2i) -> void:
	if ended:
		return
	var b := hit_btn(q.x, q.y)
	if b != "":
		acted = true
		pressed = b
		drag = {btn = b}
		return
	var j := hit_pal(q.x, q.y)
	if j >= 0:
		drag = {from = "pal", kind = pal_kinds[j], idx = -1, sx = q.x, sy = q.y, x = q.x, y = q.y, moved = false, over = -1}
	else:
		var i := hit_slot(q.x, q.y)
		if i >= 0 and not given.has(i) and slots[i] >= 0:
			drag = {from = "slot", idx = i, kind = slots[i], sx = q.x, sy = q.y, x = q.x, y = q.y, moved = false, over = -1}
	if not drag.is_empty():
		acted = true


func move(q: Vector2i) -> void:
	if drag.is_empty():
		return
	if drag.has("btn"):
		pressed = drag.btn if hit_btn(q.x, q.y) == drag.btn else ""
		return
	drag.x = q.x
	drag.y = q.y
	if not drag.moved and absi(q.x - int(drag.sx)) + absi(q.y - int(drag.sy)) > 3:
		drag.moved = true
	if drag.moved:
		var i := hit_slot(q.x, q.y, true)
		drag.over = i if i >= 0 and not given.has(i) else -1


func up(q: Vector2i, cancel := false) -> void:
	if drag.is_empty():
		return
	var d := drag
	drag = {}
	pressed = ""
	if ended or cancel:
		return
	if d.has("btn"):
		if hit_btn(q.x, q.y) == d.btn:
			if d.btn == "check":
				check()
			else:
				clear()
		return
	if not d.moved:
		if d.from == "pal":
			var at := slots.find(-1)
			if at >= 0:
				_put(at, int(d.kind))
		else:
			slots[int(d.idx)] = -1
			marks[int(d.idx)] = ""
		return
	var tg := int(d.over)
	if d.from == "pal":
		if tg >= 0:
			_put(tg, int(d.kind))
		return
	if tg < 0:
		slots[int(d.idx)] = -1
		marks[int(d.idx)] = ""
		return
	if tg == int(d.idx):
		return
	var old := slots[tg]
	_put(tg, int(d.kind))
	slots[int(d.idx)] = old
	marks[int(d.idx)] = ""
	if old >= 0:
		placed_at[int(d.idx)] = _now()


func clear() -> void:
	if ended:
		return
	for i in n:
		if not given.has(i):
			slots[i] = -1
			marks[i] = ""
	msg = ""


func check() -> void:
	if ended or slots.has(-1):
		return
	used += 1
	var right := 0
	for i in n:
		var ok := slots[i] == int(p.truth[i])
		if ok:
			right += 1
		marks[i] = "" if given.has(i) else ("ok" if ok else "no")
	last_frac = float(right) / n
	if right == n:
		ended = true
		win_at = _now()
		msg = "ORDER CONFIRMED"
		sfx(&"confirm")
		sfx(&"win")
		var u := used
		after((90.0 * n + 500.0) / 1000.0, func() -> void: done(score(u, 1.0), "Ordered %d layers on check %d of %d" % [n, u, checks]))
		return
	msg = "%d/%d IN PLACE" % [right, n]
	if used >= checks:
		ended = true
		var fr := last_frac
		after(0.9, func() -> void: done(score(0, fr), "%d/%d layers in place after %d checks" % [right, n, checks]))


func give_up() -> void:
	if ended:
		return
	ended = true
	_later.clear()
	var right := 0
	for i in n:
		if slots[i] == int(p.truth[i]) and not given.has(i):
			right += 1
	done(0.2 * right / n, "Gave up")
