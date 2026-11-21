class_name GameCoolant
extends MiniGame

## COOLANT ROUTING (Jon: loved, Nov 17): turn pipe tiles to carry coolant from the hot core to the
## sample chamber before HEAT fills. A port of the approved prototype's `coolant2.js`, rule for rule
## and pixel for pixel, in its approved layout and the UI kit (Nov 20); the puzzle is dealt from the
## seeded stream, never solved.
## Why: docs/why/MiniGame.md#coolant

## Directions 0 N, 1 E, 2 S, 3 W; a tile's pipes are a 4-bit mask, bit = 1 << dir.
const DX: Array[int] = [0, 1, 0, -1]
const DY: Array[int] = [-1, 0, 1, 0]
## empty: the share of off-route squares left bare; ok: the share of route pipes dealt already right.
const CFG := {
	1: {w = 5, h = 4, valve = 0, two = 0, crack = 0, secs = 55, empty = 0.0, ok = 0.0},
	2: {w = 5, h = 5, valve = 1, two = 0, crack = 0, secs = 65, empty = 0.1, ok = 0.1},
	3: {w = 6, h = 5, valve = 1, two = 0, crack = 2, secs = 75, empty = 0.18, ok = 0.15},
	4: {w = 6, h = 6, valve = 1, two = 1, crack = 2, secs = 90, empty = 0.25, ok = 0.2},
	5: {w = 7, h = 6, valve = 1, two = 1, crack = 3, secs = 105, empty = 0.3, ok = 0.2},
}
## The game area, as every game draws it (the UI kit, Nov 20).
const W := MiniKit.W
const H := MiniKit.H
## The core's and the chambers' column width.
const E := 14
const WATER := Color("#2a9e90")
const METAL_DK := Color("#4a586a")
const PLATE := Color("#151d29")
const PLATE_LK := Color("#1a2433")
const CORE_DK := Color("#7a3d12")
const CHAMBER := Color("#0d1520")
const DRY := Color("#364353")
const LEAK_AT: Array[Vector2] = [Vector2(0.2, 0.25), Vector2(0.75, 0.2), Vector2(0.7, 0.75), Vector2(0.25, 0.8),
	Vector2(0.5, 0.12), Vector2(0.85, 0.5), Vector2(0.15, 0.5)]
const CRACK_AT: Array[Vector2] = [Vector2(0.2, 0.08), Vector2(0.38, 0.34), Vector2(0.28, 0.5), Vector2(0.56, 0.62),
	Vector2(0.44, 0.8), Vector2(0.72, 0.94)]

var P: Dictionary = {}
var taps := 0
var over := false
var won := false
var lost := false
var heat := 0.0
var last := -1
var phase := 0
var F: Dictionary = {}
var limit := 0.0
var S := 18
var GX := 0
var GY := 11


func id() -> StringName:
	return &"coolant"


func hint() -> String:
	return "Cool the sample."


func controls() -> Array[String]:
	return ["click"]


# ---------------------------------------------------------------- the rules

static func opp(d: int) -> int:
	return (d + 2) % 4


static func rotm(m: int, k: int) -> int:
	k = posmod(k, 4)
	for i in k:
		m = ((m << 1) | (m >> 3)) & 15
	return m


static func dir_to(a: Vector2i, b: Vector2i) -> int:
	for d in 4:
		if a.x + DX[d] == b.x and a.y + DY[d] == b.y:
			return d
	return -1


## A random self-avoiding walk from (sx, sy) that ends in the last column, or [].
static func walk(w: int, h: int, sx: int, sy: int, used: Array[int], rng_: RandomNumberGenerator,
		min_len: int, max_len: int, ok_end: Callable) -> Array[Vector2i]:
	for t_ in 400:
		var seen := {}
		for u in used:
			seen[u] = true
		var path: Array[Vector2i] = [Vector2i(sx, sy)]
		seen[sy * w + sx] = true
		var x := sx
		var y := sy
		while path.size() <= max_len:
			if x == w - 1 and path.size() >= min_len and ok_end.call(y) and rng_.randf() < 0.65:
				return path
			var opts: Array[Vector2] = []
			var tot := 0.0
			for d in 4:
				var nx := x + DX[d]
				var ny := y + DY[d]
				if nx < 0 or ny < 0 or nx >= w or ny >= h or seen.has(ny * w + nx):
					continue
				var wt := 0.3 if d == 3 else 1.0
				opts.append(Vector2(d, wt))
				tot += wt
			if opts.is_empty():
				break
			var r := rng_.randf() * tot
			var dd := int(opts[0].x)
			for o in opts:
				r -= o.y
				if r <= 0.0:
					dd = int(o.x)
					break
			x += DX[dd]
			y += DY[dd]
			seen[y * w + x] = true
			path.append(Vector2i(x, y))
		if x == w - 1 and path.size() >= min_len and path.size() <= max_len and ok_end.call(y):
			return path
	return []


static func shuffled(src: Array[int], r: RandomNumberGenerator) -> Array[int]:
	var a: Array[int] = src.duplicate()
	for i in range(a.size() - 1, 0, -1):
		var j := int(r.randf() * (i + 1))
		var tmp: int = a[i]
		a[i] = a[j]
		a[j] = tmp
	return a


## Lays a walk's pipes into `goal` and `on_path`: `ind` is where the first tile's coolant comes from.
static func _lay(path: Array[Vector2i], first_in: int, w: int, goal: PackedInt32Array, on_path: PackedByteArray) -> void:
	for i in path.size():
		var p := path[i]
		var ind := first_in if i == 0 else opp(dir_to(path[i - 1], p))
		var out := 1 if i == path.size() - 1 else dir_to(p, path[i + 1])
		goal[p.y * w + p.x] = (1 << ind) | (1 << out)
		on_path[p.y * w + p.x] = 1


## The second chamber's branch off the main route (sector 4+); false when none fits.
static func _branch(c: Dictionary, main: Array[Vector2i], rows: Array[int], goal: PackedInt32Array,
		on_path: PackedByteArray, r: RandomNumberGenerator) -> bool:
	var w: int = c.w
	var h: int = c.h
	for a in 60:
		var j := 1 + int(r.randf() * (main.size() - 2))
		var p := main[j]
		var pi := p.y * w + p.x
		var ds: Array[int] = []
		for d in 4:
			var nx := p.x + DX[d]
			var ny := p.y + DY[d]
			if not (goal[pi] & (1 << d)) and nx >= 0 and ny >= 0 and nx < w and ny < h and not on_path[ny * w + nx]:
				ds.append(d)
		if ds.is_empty():
			continue
		var d2 := ds[int(r.randf() * ds.size())]
		var used: Array[int] = []
		for i in on_path.size():
			if on_path[i]:
				used.append(i)
		var row0 := rows[0]
		var br := walk(w, h, p.x + DX[d2], p.y + DY[d2], used, r, 2, 10,
			func(y: int) -> bool: return absi(y - row0) >= 1)
		if br.is_empty():
			continue
		goal[pi] |= (1 << d2)
		_lay(br, opp(d2), w, goal, on_path)
		rows.append(br[br.size() - 1].y)
		return true
	return false


## The tiles: route pipes turned off their goal, decoys elsewhere.
static func _tiles(c: Dictionary, goal: PackedInt32Array, on_path: PackedByteArray, r: RandomNumberGenerator) -> Array[Dictionary]:
	var tiles: Array[Dictionary] = []
	for i in goal.size():
		if on_path[i]:
			var g := goal[i]
			var straight := g == 5 or g == 10
			var u := r.randf()
			var k := 0
			if straight:
				k = 1 if r.randf() < 0.5 else 3
			else:
				k = 3 if u < 0.42 else (2 if u < 0.82 else 1)
			if r.randf() < float(c.ok):
				k = 0
			tiles.append({m = rotm(g, k), goal = g, path = true, crack = false, lock = false})
		elif r.randf() < float(c.empty):
			tiles.append({m = 0, goal = -1, path = false, crack = false, lock = false})
		else:
			var rr := r.randf()
			var base := 5 if rr < 0.3 else (3 if rr < 0.72 else 7)
			tiles.append({m = rotm(base, int(r.randf() * 4)), goal = -1, path = false, crack = false, lock = false})
	return tiles


## Cracks on decoys beside the route (sector 3+); false when too few fit.
static func _crack(c: Dictionary, tiles: Array[Dictionary], on_path: PackedByteArray, r: RandomNumberGenerator) -> bool:
	var w: int = c.w
	var h: int = c.h
	var near: Array[int] = []
	for i in w * h:
		if on_path[i] or not int(tiles[i].m):
			continue
		var x := i % w
		var y := i / w
		for d in 4:
			var nx := x + DX[d]
			var ny := y + DY[d]
			if nx >= 0 and ny >= 0 and nx < w and ny < h and on_path[ny * w + nx]:
				near.append(i)
				break
	var pick := shuffled(near, r).slice(0, int(c.crack))
	if pick.size() < int(c.crack):
		return false
	for i: int in pick:
		tiles[i].crack = true
	return true


## A puzzle for `depth` and `sensors` from stream `r`, never dealt solved; {} if none came.
static func gen(d: int, s: int, r: RandomNumberGenerator) -> Dictionary[String, Variant]:
	var out: Dictionary[String, Variant] = {}
	var c: Dictionary = CFG[d]
	var w: int = c.w
	var h: int = c.h
	for tries in 200:
		var r0 := int(r.randf() * h)
		var main := walk(w, h, 0, r0, [] as Array[int], r, w + 2, int(floorf(w * h * 0.45)),
			func(_y: int) -> bool: return true)
		if main.is_empty():
			continue
		var goal := PackedInt32Array()
		goal.resize(w * h)
		var on_path := PackedByteArray()
		on_path.resize(w * h)
		_lay(main, 3, w, goal, on_path)
		var rows: Array[int] = [main[main.size() - 1].y]
		if int(c.two) and not _branch(c, main, rows, goal, on_path, r):
			continue
		var tiles := _tiles(c, goal, on_path, r)
		var valve := -1
		if int(c.valve):
			var cand: Array[int] = []
			for p in main.slice(1, main.size() - 1):
				cand.append(p.y * w + p.x)
			valve = cand[int(r.randf() * cand.size())]
		if int(c.crack) and not _crack(c, tiles, on_path, r):
			continue
		# sensors: some route tiles bolted in place, already right; only ones that needed turning
		var n_lock := mini(maxi(0, s - 1), main.size() / 3)
		var turnable: Array[int] = []
		for i in tiles.size():
			if tiles[i].path and need(tiles[i]) > 0:
				turnable.append(i)
		for i: int in shuffled(turnable, r).slice(0, n_lock):
			tiles[i].m = tiles[i].goal
			tiles[i].lock = true
		var puz := {w = w, h = h, r0 = r0, rows = rows, tiles = tiles, valve = valve, path_len = main.size()}
		puz.par = par(puz)
		if win(puz, flood(puz)):
			continue
		out.assign(puz)
		return out
	return out


static func need(tile: Dictionary) -> int:
	if int(tile.goal) < 0:
		return 0
	for k in 4:
		if rotm(int(tile.m), k) == int(tile.goal):
			return k
	return 0


static func par(puz: Dictionary) -> int:
	var n := 0
	for tile: Dictionary in puz.tiles:
		n += need(tile)
	return n


static func fixes(puz: Dictionary) -> int:
	var n := 0
	for tile: Dictionary in puz.tiles:
		if need(tile) > 0:
			n += 1
	return n


## Seconds a competent player needs once they see the route (the prototype's, calibrated on Jon's runs).
static func pace_secs(puz: Dictionary, d: int) -> float:
	var c: Dictionary = CFG[d]
	var f := fixes(puz)
	return 10.0 + 3.5 * f + 0.6 * (int(puz.par) - f) + (5.0 if int(c.valve) else 0.0) \
		+ (8.0 if int(c.two) else 0.0) + 2.0 * int(c.crack)


## The heat limit: the sector's base time, stretched so a competent run has 30% to spare.
static func time_limit(puz: Dictionary, d: int, s: int) -> float:
	return maxf(float(CFG[d].secs), float(MiniPix.jr(1.3 * pace_secs(puz, d)))) * (1.0 + 0.12 * s)


## Where the coolant reaches from the core: {lit: {tile: the side it came in}, reached, leaks}.
static func flood(puz: Dictionary) -> Dictionary[String, Variant]:
	var w: int = puz.w
	var h: int = puz.h
	var tiles: Array[Dictionary] = puz.tiles
	var rows: Array[int] = puz.rows
	var lit := {}
	var reached: Array[bool] = []
	for r_ in rows:
		reached.append(false)
	var leaks: Array[int] = []
	var s0 := int(puz.r0) * w
	var q: Array[int] = []
	if int(tiles[s0].m) & 8:
		lit[s0] = 3
		q.append(s0)
	var head := 0
	while head < q.size():
		var i := q[head]
		head += 1
		var tile := tiles[i]
		if tile.crack:
			leaks.append(i)
			continue
		var x := i % w
		var y := i / w
		for d in 4:
			if not (int(tile.m) & (1 << d)) or d == int(lit[i]):
				continue
			var nx := x + DX[d]
			var ny := y + DY[d]
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				if d == 1:
					for k in rows.size():
						if rows[k] == y:
							reached[k] = true
				continue
			var j := ny * w + nx
			if lit.has(j):
				continue
			if int(tiles[j].m) & (1 << opp(d)):
				lit[j] = opp(d)
				q.append(j)
	var out: Dictionary[String, Variant] = {}
	out.assign({lit = lit, reached = reached, leaks = leaks})
	return out


static func win(puz: Dictionary, f: Dictionary) -> bool:
	for b: bool in f.reached:
		if not b:
			return false
	return (int(puz.valve) < 0 or (f.lit as Dictionary).has(int(puz.valve))) and (f.leaks as Array).is_empty()


static func score_of(ht: float, n_taps: int, par_: int) -> float:
	var tt := clampf((1.0 - ht) / 0.6, 0.0, 1.0)
	var rr := clampf(1.0 - maxf(0.0, n_taps - par_) / float(par_ + 4), 0.0, 1.0)
	return clampf(0.3 + 0.35 * tt + 0.35 * rr, 0.0, 1.0)


# ---------------------------------------------------------------- the game

func _mount() -> void:
	P = gen(depth, sensors, rng)
	if P.is_empty():
		push_error("GameCoolant: no puzzle at depth %d" % depth)
		px = MiniPix.new(W, H)
		over = true
		done(0.0, "No puzzle")
		return
	var w: int = P.w
	var h: int = P.h
	limit = time_limit(P, depth, sensors)
	# the tile size, even: as big as the kit's play rows allow, inside the grid's 1 px frame, with
	# 1 px margins at the sides (A, Nov 20: the whole glass is the game, rows 10-139)
	var py0 := MiniKit.PLAY_Y + 1
	var ph := MiniKit.deck_y(false) - 1 - py0
	S = mini((W - 2 - 2 * E) / w, ph / h) & ~1
	GX = (W - w * S) / 2
	GY = py0 + ((ph - h * S) >> 1)
	px = MiniPix.new(W, H)
	F = flood(P)
	_render()


func _tick(_dt: float) -> void:
	if not over:
		# the prototype's heat timer ticks every 100 ms
		heat = clampf(floorf(t / 0.1) * 0.1 / limit, 0.0, 1.0)
		if heat >= 1.0:
			over = true
			lost = true
			last = -1
			say_end("OVERHEAT", "bad")
			done(0.1, "Overheated before the route closed")
	# the coolant flows at about 30 frames a second, before and after the end
	var ph := int(floorf(t * 30.0))
	if ph != phase:
		phase = ph
		if drawing:
			_render()


func tap(i: int) -> void:
	if over:
		return
	var tiles: Array[Dictionary] = P.tiles
	tiles[i].m = rotm(int(tiles[i].m), 1)
	taps += 1
	last = i
	sfx(&"turn")
	var leaks := (F.leaks as Array).size()
	F = flood(P)
	if (F.leaks as Array).size() > leaks:
		say("LEAK", "bad")
	if win(P, F):
		over = true
		won = true
		last = -1
		sfx(&"flow")
		sfx(&"win")
		say_end("ROUTED", "good")
		done(score_of(heat, taps, int(P.par)), "Routed at %d%% heat in %d turns (par %d)" % [MiniPix.jr(heat * 100.0), taps, int(P.par)])
	_render()


func down(p: Vector2i) -> void:
	if over:
		return
	var x := floori((p.x - GX) / float(S))
	var y := floori((p.y - GY) / float(S))
	if x < 0 or y < 0 or x >= int(P.w) or y >= int(P.h):
		return
	var i := y * int(P.w) + x
	var tile: Dictionary = P.tiles[i]
	if tile.lock or not int(tile.m):
		return
	tap(i)


func give_up() -> void:
	if over:
		return
	over = true
	done(0.0, "Gave up")


# ---------------------------------------------------------------- the picture

func _render() -> void:
	px.clear(MiniPix.VOID)
	var w: int = P.w
	var h: int = P.h
	px.rect(GX - 1, GY - 1, w * S + 2, h * S + 2, MiniPix.BEVEL_LO)
	for i in w * h:
		_tile(i)
	_ends()
	_hud()
	draw_toast()
	dirty = true


func _ring(cx: int, cy: int, r: int, c: Color) -> void:
	for y in range(-r - 1, r + 2):
		for x in range(-r - 1, r + 2):
			var d := Vector2(x + 0.5, y + 0.5).length()
			if d > r - 0.5 and d <= r + 0.5:
				px.dot(cx + x, cy + y, c)


## Pixels between r0 and r1 lit with falling density.
func _glow(cx: int, cy: int, r0: int, r1: int, c: Color, k: float) -> void:
	for y in range(-r1, r1 + 1):
		for x in range(-r1, r1 + 1):
			var d := Vector2(x + 0.5, y + 0.5).length()
			if d < r0 or d > r1:
				continue
			if MiniPix.lit(cx + x, cy + y, (1.0 - (d - r0) / float(r1 - r0)) * k):
				px.dot(cx + x, cy + y, c)


func _line(x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	var dx := absi(x1 - x0)
	var dy := -absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var e := dx + dy
	while true:
		px.dot(x0, y0, c)
		if x0 == x1 and y0 == y1:
			break
		var e2 := 2 * e
		if e2 >= dy:
			e += dy
			x0 += sx
		if e2 <= dx:
			e += dx
			y0 += sy


## The band of half-width hw along arm d of the tile at (x0, y0).
func _arm(x0: int, y0: int, d: int, hw: int) -> Rect2i:
	var cx := x0 + S / 2
	var cy := y0 + S / 2
	match d:
		0:
			return Rect2i(cx - hw, y0, 2 * hw, cy + hw - y0)
		2:
			return Rect2i(cx - hw, cy - hw, 2 * hw, y0 + S - (cy - hw))
		1:
			return Rect2i(cx - hw, cy - hw, x0 + S - (cx - hw), 2 * hw)
	return Rect2i(x0, cy - hw, cx + hw - x0, 2 * hw)


func _pipe_arm(x0: int, y0: int, d: int) -> void:
	var a := _arm(x0, y0, d, 3)
	px.rect(a.position.x, a.position.y, a.size.x, a.size.y, MiniPix.COLD)
	if d == 0 or d == 2:
		px.rect(a.position.x, a.position.y, 1, a.size.y, MiniPix.CHILL)
		px.rect(a.position.x + 5, a.position.y, 1, a.size.y, METAL_DK)
	else:
		px.rect(a.position.x, a.position.y, a.size.x, 1, MiniPix.CHILL)
		px.rect(a.position.x, a.position.y + 5, a.size.x, 1, METAL_DK)


func _tile(i: int) -> void:
	var w: int = P.w
	var tile: Dictionary = P.tiles[i]
	var x0 := GX + (i % w) * S
	var y0 := GY + (i / w) * S
	var cx := x0 + S / 2
	var cy := y0 + S / 2
	var lit := (F.lit as Dictionary).has(i)
	var leak := (F.leaks as Array).has(i)
	# the deck plate
	px.rect(x0, y0, S, S, PLATE_LK if tile.lock else PLATE)
	px.rect(x0, y0, S, 1, MiniPix.LINE)
	px.rect(x0, y0, 1, S, MiniPix.LINE)
	px.rect(x0, y0 + S - 1, S, 1, MiniPix.BEVEL_LO)
	px.rect(x0 + S - 1, y0, 1, S, MiniPix.BEVEL_LO)
	var dirs: Array[int] = []
	for d in 4:
		if int(tile.m) & (1 << d):
			dirs.append(d)
	if not dirs.is_empty():
		_pipes(x0, y0, cx, cy, dirs, lit, leak, int(F.lit.get(i, -1)))
	if tile.crack:
		var pts: Array[Vector2i] = []
		for a in CRACK_AT:
			pts.append(Vector2i(x0 + MiniPix.jr(a.x * (S - 1)), y0 + MiniPix.jr(a.y * (S - 1))))
		for k in range(1, pts.size()):
			_line(pts[k - 1].x + 1, pts[k - 1].y, pts[k].x + 1, pts[k].y, MiniPix.BEVEL_LO)
			_line(pts[k - 1].x, pts[k - 1].y, pts[k].x, pts[k].y, MiniPix.BAD)
	if leak:
		# coolant spraying out of the crack
		for k in LEAK_AT.size():
			var f := float((phase + k * 3) % 9) / 9.0
			var a: Vector2 = LEAK_AT[k]
			px.dot(MiniPix.jr(cx + (a.x - 0.5) * S * (0.4 + 0.6 * f)), MiniPix.jr(cy + (a.y - 0.5) * S * (0.4 + 0.6 * f)),
				MiniPix.MARK if f < 0.5 else MiniPix.TRACTOR)
	if i == int(P.valve):
		# the hand wheel
		var on := lit and not leak
		var col := MiniPix.GOOD if on else MiniPix.WARN
		_ring(cx, cy, 4, MiniPix.BEVEL_LO)
		_ring(cx, cy, 3, col)
		px.rect(cx - 1, cy - 3, 2, 6, col)
		px.rect(cx - 3, cy - 1, 6, 2, col)
		px.rect(cx - 1, cy - 1, 2, 2, MiniPix.BEVEL_LO)
		px.dot(cx - 3, cy - 2, MiniPix.MARK if on else MiniPix.HOT)
	if tile.lock:
		for b: Vector2i in [Vector2i(x0 + 1, y0 + 1), Vector2i(x0 + S - 3, y0 + 1), Vector2i(x0 + 1, y0 + S - 3), Vector2i(x0 + S - 3, y0 + S - 3)]:
			px.rect(b.x, b.y, 2, 2, MiniPix.BRACE)
			px.dot(b.x + 1, b.y + 1, MiniPix.BEVEL_LO)
	if i == last and not over:
		px.rect(x0, y0, S, 1, MiniPix.EMBER)
		px.rect(x0, y0 + S - 1, S, 1, MiniPix.EMBER)
		px.rect(x0, y0, 1, S, MiniPix.EMBER)
		px.rect(x0 + S - 1, y0, 1, S, MiniPix.EMBER)


## A tile's pipes: arms, the hub flange lit from the top-left, the joints, and the channel, dry or
## carrying coolant that flows from the side it came in (`ent`).
func _pipes(x0: int, y0: int, cx: int, cy: int, dirs: Array[int], lit: bool, leak: bool, ent: int) -> void:
	for d in dirs:
		var a := _arm(x0, y0, d, 4)
		px.rect(a.position.x, a.position.y, a.size.x, a.size.y, MiniPix.BEVEL_LO)
	for d in dirs:
		_pipe_arm(x0, y0, d)
	px.rect(cx - 4, cy - 4, 8, 8, MiniPix.BEVEL_LO)
	px.rect(cx - 3, cy - 3, 6, 6, MiniPix.COLD)
	px.rect(cx - 3, cy - 3, 6, 1, MiniPix.ICE)
	px.rect(cx - 3, cy - 3, 1, 6, MiniPix.CHILL)
	px.rect(cx - 3, cy + 2, 6, 1, METAL_DK)
	px.rect(cx + 2, cy - 3, 1, 6, METAL_DK)
	for d in dirs:
		match d:
			0: px.rect(cx - 4, y0, 8, 1, MiniPix.BEVEL_LO)
			2: px.rect(cx - 4, y0 + S - 1, 8, 1, MiniPix.BEVEL_LO)
			3: px.rect(x0, cy - 4, 1, 8, MiniPix.BEVEL_LO)
			1: px.rect(x0 + S - 1, cy - 4, 1, 8, MiniPix.BEVEL_LO)
	var flow := lit and not leak
	var half := S / 2
	for d in dirs:
		for s in half:
			# s: the distance from the tile's edge
			var pxx := cx - 1 if d == 0 or d == 2 else (x0 + s if d == 3 else x0 + S - 1 - s)
			var pyy := cy - 1 if d == 1 or d == 3 else (y0 + s if d == 0 else y0 + S - 1 - s)
			var c := MiniPix.TRACTOR if lit else DRY
			if flow:
				var u := s if d == ent else S - s
				var m := posmod(u - phase, 6)
				c = MiniPix.MARK if m == 0 else (MiniPix.TRACTOR if m == 1 else WATER)
			if d == 0 or d == 2:
				px.rect(pxx, pyy, 2, 1, c)
			else:
				px.rect(pxx, pyy, 1, 2, c)
	if lit:
		px.rect(cx - 1, cy - 1, 2, 2, WATER if flow else MiniPix.TRACTOR)
	else:
		px.rect(cx - 1, cy - 1, 2, 2, MiniPix.COLD)
		px.dot(cx - 1, cy - 1, MiniPix.CHILL)


## The core, whose glow grows with HEAT, and the chambers, which frost over when coolant arrives.
func _ends() -> void:
	var w: int = P.w
	var cy := GY + int(P.r0) * S + S / 2
	var bx := GX - E
	var by := cy - 6
	var pulse := 0.5 + 0.5 * sin(phase * 0.25)
	_glow(bx + 5, cy, 4, 8 + MiniPix.jr(heat * 5.0), MiniPix.BAD if heat > 0.75 else MiniPix.FLARE, 0.35 + 0.25 * heat + 0.1 * pulse)
	px.rect(bx + 9, cy - 4, E - 9, 8, MiniPix.BEVEL_LO)
	px.rect(bx + 9, cy - 3, E - 9, 6, MiniPix.COLD)
	px.rect(bx + 9, cy - 3, E - 9, 1, MiniPix.CHILL)
	px.rect(bx, by, 11, 12, MiniPix.BEVEL_LO)
	px.rect(bx + 1, by + 1, 9, 10, CORE_DK)
	var core: Array[Color] = [MiniPix.EMBER, MiniPix.FLARE, MiniPix.HOT]
	if heat > 0.75:
		core[0] = MiniPix.BAD
	px.rect(bx + 2, by + 2, 7, 8, core[0])
	px.rect(bx + 3, by + 3, 5, 6, core[1])
	px.rect(bx + 4, by + 4, 3, 3 + (1 if pulse > 0.5 else 0), core[2])
	px.rect(bx + 1, by + 1, 9, 1, MiniPix.BEVEL_HI)
	if int(P.tiles[int(P.r0) * w].m) & 8:
		px.rect(bx + 11, cy - 1, GX - (bx + 11), 2, WATER)
	var rows: Array[int] = P.rows
	for k in rows.size():
		var on: bool = F.reached[k]
		var y := GY + rows[k] * S + S / 2
		var x := GX + w * S
		px.rect(x, y - 4, 3, 8, MiniPix.BEVEL_LO)
		px.rect(x, y - 3, 3, 6, MiniPix.COLD)
		px.rect(x, y - 3, 3, 1, MiniPix.CHILL)
		px.rect(x, y - 1, 3, 2, WATER if on else MiniPix.BEVEL_LO)
		var cx := x + 3
		var ww := E - 4
		px.rect(cx, y - 7, ww, 14, MiniPix.BEVEL_LO)
		px.rect(cx + 1, y - 6, ww - 2, 12, MiniPix.CHILL if on else CHAMBER)
		if on:
			px.dither(cx + 1, y - 6, ww - 2, 12, MiniPix.CHILL, MiniPix.ICE, 0.5)
			px.rect(cx + 2, y - 5, ww - 4, 1, MiniPix.MARK)
			for s in 3:
				px.dot(cx + 2 + ((s * 4 + (phase >> 2)) % (ww - 4)), y - 4 + ((s * 5) % 9), MiniPix.MARK)
		else:
			for q in range(0, 12, 2):
				px.dot(cx + 1 + (q % (ww - 2)), y - 6 + q, MiniPix.LINE)
		px.rect(cx, y - 7, ww, 1, MiniPix.ICE if on else MiniPix.COLD)


func _hud() -> void:
	var hot := heat > 0.75
	MiniKit.header(px, {label = "HEAT", kind = "bad" if hot else "", meter = {w = 53, frac = heat, kind = "bad" if hot else "neutral"}},
		[["TURNS", taps], ["PAR", int(P.par)]])
	# A (Nov 20): no status line; ROUTED / OVERHEAT are the shell's card, LEAK a toast, COLD and the
	# valve the grid's own
	if not over and taps == 0 and not told:
		MiniKit.tell(px, "COOL THE SAMPLE.", ["click"] as Array[String], t)
