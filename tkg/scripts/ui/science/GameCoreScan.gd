class_name GameCoreScan
extends MiniGame

## CORE SCAN (Jon: loved, Nov 17): the ship's scanner reads a buried find in slices. Each bar says
## how many solid cells its slice holds, in runs; fill the solid cells to bring the find up on screen.
## A port of the approved `tomo2.js`, rule for rule and pixel for pixel, in its approved layout (fit3)
## and the UI kit (Nov 20).
## Why: docs/why/MiniGame.md#core-scan

## Each sector's pictures: [name, palette hue, rows], in the page's order.
const PICS := {
	5: [
		["CRYSTAL", "t2", ["..#..", ".###.", "#####", ".###.", "..#.."]],
		["HEART", "bad", [".#.#.", "#####", "#####", ".###.", "..#.."]],
		["ROCKET", "flare", ["..#..", ".###.", ".###.", ".###.", "#.#.#"]],
		["TREE", "t1", ["..#..", ".###.", "#####", "..#..", "..#.."]],
		["SKULL", "ice", [".###.", "#####", "#.#.#", "#####", ".#.#."]],
		["ANCHOR", "chill", ["..#..", "#####", "..#..", "#.#.#", ".###."]],
		["SHIP", "cold", ["..#..", ".###.", "##.##", "#####", "#.#.#"]],
		["MUG", "ember", ["####.", "#..##", "#..##", "####.", ".##.."]],
	],
	6: [
		["CRYSTAL", "t2", ["..##..", ".####.", "######", ".####.", "..##..", "..##.."]],
		["SHELL", "hot", [".####.", "######", "#.##.#", "######", ".####.", "..##.."]],
		["SCREW", "chill", [".####.", ".####.", "..##..", ".###..", "..##..", "...#.."]],
		["WRENCH", "cold", ["#...#.", "#####.", ".###..", "..##..", "...##.", "....##"]],
		["GEAR", "warn", ["#.##.#", ".####.", "##..##", "##..##", ".####.", "#.##.#"]],
		["BONE", "ice", ["##....", "####..", ".###..", "..###.", "...###", "....##"]],
		["LEAF", "t1", ["...###", "..####", ".#.##.", "####..", ".##...", "#....."]],
	],
	8: [
		["CRYSTAL", "t2", ["...#....", "..###.#.", "..###.##", ".####.##", ".####.##", "#####.##", "########", ".######."]],
		["SHELL", "hot", ["..####..", ".##...#.", "#..##..#", "#.#..#.#", "#.#.##.#", "#..#...#", ".#....#.", "..#####."]],
		["WRENCH", "cold", [".#.#....", ".#.#....", ".###....", "..###...", "...####.", "....###.", ".....###", "......##"]],
		["SCREW", "chill", [".######.", ".######.", "...##...", "..####..", "...##...", "..####..", "...##...", "....#..."]],
		["GEAR", "warn", ["...##...", ".######.", ".##..##.", "###..###", "###..###", ".##..##.", ".######.", "...##..."]],
		["BONE", "ice", ["........", ".#....#.", "###..###", ".######.", ".######.", "###..###", ".#....#.", "........"]],
		["LEAF", "t1", ["......##", "....####", "...#####", "..#####.", ".##.##..", ".####...", ".#......", "#......."]],
	],
	10: [
		["CRYSTAL", "t2", ["....#.....", "...###....", "...###..#.", "..#####.##", "..#####.##", "..#####.##", ".######.##",
			".#########", "##########", ".########."]],
		["SHELL", "hot", ["...####...", ".########.", "##.#..#.##", "#.##..##.#", "##.####.##", ".##.##.##.", "..######..",
			"...####...", "..######..", "..######.."]],
		["WRENCH", "cold", [".#..#.....", ".#..#.....", ".####.....", "..####....", "...####...", "....#####.", ".....####.",
			"......####", ".......###", "........#."]],
		["GEAR", "warn", ["....##....", ".#.####.#.", ".########.", "..##..##..", "####..####", "####..####", "..##..##..",
			".########.", ".#.####.#.", "....##...."]],
		["SKULL", "ice", ["..######..", ".########.", "##########", "##..##..##", "##..##..##", "##########", ".###..###.",
			"..######..", "..#.##.#..", "..######.."]],
		["LEAF", "t1", ["........##", "......####", ".....#####", "....######", "...#.####.", "..######..", ".######...",
			".####.....", ".#........", "#........."]],
	],
}
const HUE := {"t2": Color("#6a9ad4"), "bad": MiniPix.BAD, "flare": MiniPix.FLARE, "t1": Color("#4fbf82"), "ice": MiniPix.ICE,
	"chill": MiniPix.CHILL, "cold": MiniPix.COLD, "ember": MiniPix.EMBER, "hot": MiniPix.HOT, "warn": MiniPix.WARN}
const CFG := {
	1: {n = 5, lives = 4, par = 40},
	2: {n = 6, lives = 4, par = 60},
	3: {n = 8, lives = 4, par = 95},
	4: {n = 8, lives = 3, par = 95},
	5: {n = 10, lives = 3, par = 140},
}
## The crack's five arms (dx, dy), in doubles as the page has them (a Vector2 would round them to floats).
const ARMS: Array = [[1.0, -1.0], [-1.0, -0.6], [0.4, 1.0], [-0.8, 0.9], [1.0, 0.3]]
const BLACK := Color("#000000")
const WHITE := Color("#ffffff")
const GLASS := Color("#101824")
const GLASS_HI := Color("#1a2533")
const KNOWN := Color("#080b11")
const KNOWN_HI := Color("#0b0f15")
const EDGE := Color("#05070a")
const SCAN := Color("#1f3a44")
const CRACKED := Color("#140a0b")
## The game area, as every game draws it (the UI kit, Nov 20).
const W := MiniKit.W
const H := MiniKit.H

## The pictures each size can deal (those the line solver finishes), built once.
static var _opt := {}

## The deal, as the page names it: {name, hue, grid (rows of 0/1), n}.
var P: Dictionary[String, Variant] = {}
var n := 5
var lives := 4
var par := 40
## The picture's rows (P.grid, typed).
var grid: Array[PackedInt32Array] = []
var rows: Array[PackedInt32Array] = []
var cols: Array[PackedInt32Array] = []
## 0 unknown, 1 filled, 2 known empty, 3 cracked.
var st: Array[PackedInt32Array] = []
var crack_t := {}
var fill_t := {}
var forgive := 0
var mistakes := 0
var over := false
var won := 0.0
var lost := 0.0
var touched := false
var total := 0
var last_row := -1
var last_col := -1
var last_t := 0.0
var sweep_row := {}
var sweep_col := {}
var CLW := 0
var CLH := 0
var CS := 0
var GW := 0
var GX := 0
var GY := 0
var ramp: Array[Color] = []
var phase := 0


func id() -> StringName:
	return &"corescan"


func hint() -> String:
	return "Fill in the scan."


func controls() -> Array[String]:
	return ["click"]


# ---------------------------------------------------------------- the rules

## A line's runs of solid cells.
static func runs(line: PackedInt32Array) -> PackedInt32Array:
	var r := PackedInt32Array()
	var c := 0
	for v in line:
		if v:
			c += 1
		elif c:
			r.append(c)
			c = 0
	if c:
		r.append(c)
	return r


static func column(g: Array, j: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for row: PackedInt32Array in g:
		out.append(row[j])
	return out


## What a line's clue and its known cells (-1 unknown) settle: the cells every fit agrees on, or
## an empty array when nothing fits.
static func line_solve(clue: PackedInt32Array, known: PackedInt32Array) -> PackedInt32Array:
	var ls := LineFit.new(clue, known)
	ls.rec(0, 0)
	var out := PackedInt32Array()
	if not ls.any:
		return out
	for i in known.size():
		if known[i] != -1:
			out.append(known[i])
		elif ls.can_f[i] and not ls.can_e[i]:
			out.append(1)
		elif not ls.can_f[i] and ls.can_e[i]:
			out.append(0)
		else:
			out.append(-1)
	return out


## The page's recursive fitter: every placement of the clue's runs that agrees with the known cells.
class LineFit:
	var clue: PackedInt32Array
	var known: PackedInt32Array
	var n := 0
	var can_f: Array[bool] = []
	var can_e: Array[bool] = []
	var cur: Array[int] = []
	var any := false

	func _init(c: PackedInt32Array, k: PackedInt32Array) -> void:
		clue = c
		known = k
		n = k.size()
		for i in n:
			can_f.append(false)
			can_e.append(false)
			cur.append(0)

	func rec(ci: int, pos: int) -> void:
		if ci == clue.size():
			for i in range(pos, n):
				if known[i] == 1:
					return
			for i in n:
				if i >= pos:
					cur[i] = 0
				if cur[i]:
					can_f[i] = true
				else:
					can_e[i] = true
			any = true
			return
		var ln := clue[ci]
		var rest := 0
		for k in range(ci + 1, clue.size()):
			rest += clue[k] + 1
		for s in range(pos, n - ln - rest + 1):
			var ok := true
			for i in range(pos, s):
				if known[i] == 1:
					ok = false
					break
			if not ok:
				break
			for i in range(s, s + ln):
				if known[i] == 0:
					ok = false
					break
			if not ok:
				continue
			if s + ln < n and known[s + ln] == 1:
				continue
			for i in range(pos, s):
				cur[i] = 0
			for i in range(s, s + ln):
				cur[i] = 1
			if s + ln < n:
				cur[s + ln] = 0
			rec(ci + 1, mini(n, s + ln + 1))


## Whether row and column passes alone finish the picture.
static func line_solvable(g: Array[PackedInt32Array]) -> bool:
	var m := g.size()
	var k: Array[PackedInt32Array] = []
	for i in m:
		var row := PackedInt32Array()
		row.resize(m)
		row.fill(-1)
		k.append(row)
	var changed := true
	while changed:
		changed = false
		for i in m:
			var r := line_solve(runs(g[i]), k[i])
			if r.is_empty():
				return false
			if r != k[i]:
				k[i] = r
				changed = true
		for j in m:
			var r := line_solve(runs(column(g, j)), column(k, j))
			if r.is_empty():
				return false
			for i in m:
				if r[i] != k[i][j]:
					k[i][j] = r[i]
					changed = true
	for i in m:
		if k[i] != g[i]:
			return false
	return true


static func to_grid(src: Array, flip: bool) -> Array[PackedInt32Array]:
	var out: Array[PackedInt32Array] = []
	for r: String in src:
		var a := PackedInt32Array()
		for ch in r:
			a.append(1 if ch == "#" else 0)
		if flip:
			a.reverse()
		out.append(a)
	return out


static func options(m: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for pic: Array in PICS[m]:
		for flip: bool in [false, true]:
			var g := to_grid(pic[2], flip)
			if line_solvable(g):
				out.append({"name": pic[0], "hue": pic[1], "flip": flip, "grid": g})
	return out


static func gen(r: RandomNumberGenerator, d: int) -> Dictionary[String, Variant]:
	var m: int = CFG[d].n
	if not _opt.has(m):
		_opt[m] = options(m)
	var opts: Array[Dictionary] = _opt[m]
	var o: Dictionary = opts[int(r.randf() * opts.size())]
	var out: Dictionary[String, Variant] = {}
	out.assign({"name": o.name, "hue": o.hue, "grid": (o.grid as Array).duplicate(true), "n": m})
	return out


static func score_of(cracks: int, secs: int, par_: int) -> float:
	var tp := minf(0.25, maxf(0.0, 0.25 * (secs - par_) / par_))
	return maxf(0.3, 1.0 - 0.14 * cracks - tp)


# ---------------------------------------------------------------- the game

func _mount() -> void:
	var c: Dictionary = CFG[depth]
	lives = c.lives
	par = c.par
	P = gen(rng, depth)
	n = P.n
	grid.assign(P.grid)
	var g := grid
	rows.clear()
	cols.clear()
	st.clear()
	for i in n:
		rows.append(runs(g[i]))
		cols.append(runs(column(g, i)))
		var z := PackedInt32Array()
		z.resize(n)
		st.append(z)
	forgive = sensors / 2
	# the rows sensors fill in, drawn from the stream after the deal (`TK.shuffle`)
	var order: Array[int] = []
	for i in n:
		order.append(i)
	for i in range(order.size() - 1, 0, -1):
		var j := int(rng.randf() * (i + 1))
		var tmp := order[i]
		order[i] = order[j]
		order[j] = tmp
	for i in order.slice(0, mini(ceili(sensors / 2.0), n / 3)):
		for j in n:
			st[i][j] = 1 if g[i][j] else 2
	total = 0
	for row in g:
		for v in row:
			total += v
	_layout()
	for i in n:
		if row_done(i):
			sweep_row[i] = 1.0
		if col_done(i):
			sweep_col[i] = 1.0
	px = MiniPix.new(W, H)
	_render(_now())


func _grid() -> Array[PackedInt32Array]:
	return grid


func _layout() -> void:
	var rw := 0
	for r in rows:
		var w := -3
		for v in (r if not r.is_empty() else PackedInt32Array([0])):
			w += str(v).length() * 4 - 1 + 3
		rw = maxi(rw, w)
	CLW = rw + 11
	var max_c := 1
	for c in cols:
		max_c = maxi(max_c, c.size())
	CLH = max_c * 6 + 5
	var av := MiniKit.deck_y(false) - MiniKit.PLAY_Y - 2
	CS = mini((W - 6 - CLW) / n, (av - CLH) / n)
	GW = n * CS
	GX = (W - CLW - GW) / 2 + CLW
	GY = MiniKit.PLAY_Y + CLH + ((av - CLH - GW) >> 1)
	var hue: Color = HUE.get(String(P.hue), MiniPix.ICE)
	ramp.assign([MiniPix.mix(hue, BLACK, 0.75), MiniPix.mix(hue, BLACK, 0.4), hue, MiniPix.mix(hue, WHITE, 0.45)])


## The page's clock: `performance.now()` read 1000 at the mount.
func _now() -> float:
	return 1000.0 + t * 1000.0


func row_done(i: int) -> bool:
	var g := _grid()
	for j in n:
		if g[i][j] and st[i][j] != 1:
			return false
	return true


func col_done(j: int) -> bool:
	var g := _grid()
	for i in n:
		if g[i][j] and st[i][j] != 1:
			return false
	return true


func found() -> int:
	var f := 0
	for row in st:
		for v in row:
			if v == 1:
				f += 1
	return f


## A finished row or column clears its leftover cells and sweeps green.
func settle(now: float) -> void:
	for i in n:
		if row_done(i) and not sweep_row.has(i):
			sweep_row[i] = now
			for j in n:
				if st[i][j] == 0:
					st[i][j] = 2
	for j in n:
		if col_done(j) and not sweep_col.has(j):
			sweep_col[j] = now
			for i in n:
				if st[i][j] == 0:
					st[i][j] = 2


func tap(i: int, j: int, now: float) -> void:
	if over or st[i][j] != 0:
		return
	touched = true
	last_row = i
	last_col = j
	last_t = now
	if _grid()[i][j]:
		st[i][j] = 1
		sfx(&"fill")
		fill_t[Vector2i(i, j)] = now
		settle(now)
		if found() == total:
			_win(now)
		return
	st[i][j] = 3
	crack_t[Vector2i(i, j)] = now
	sfx(&"crack")
	if forgive > 0:
		forgive -= 1
	else:
		mistakes += 1
	settle(now)
	if mistakes >= lives:
		over = true
		lost = now
		var f := found()
		done(0.15 * f / total, "Glass broke, %d/%d found" % [f, total])


func _win(now: float) -> void:
	sfx(&"win")
	over = true
	won = now
	var secs := MiniPix.jr((now - 1000.0) / 1000.0)
	done(score_of(mistakes, secs, par), "%s, %d crack%s" % [String(P.name).to_lower(), mistakes, "" if mistakes == 1 else "s"])


## The canvas point at the middle of cell (i, j).
func cell_xy(i: int, j: int) -> Vector2i:
	return Vector2i(GX + j * CS + (CS >> 1), GY + i * CS + (CS >> 1))


func down(p: Vector2i) -> void:
	var j := floori((p.x - GX) / float(CS))
	var i := floori((p.y - GY) / float(CS))
	if i >= 0 and j >= 0 and i < n and j < n:
		tap(i, j, _now())


func give_up() -> void:
	if over:
		return
	over = true
	var f := found()
	done(0.15 * f / total, "%d of %d found" % [f, total])


func _tick(_dt: float) -> void:
	# the page's loop draws about 30 times a second
	var ph := floori(t * 30.0)
	if ph == phase:
		return
	phase = ph
	if drawing:
		_render(_now())


# ---------------------------------------------------------------- the picture

func _render(now: float) -> void:
	px.rect(0, 0, W, H, MiniPix.PANEL)
	var x0 := MiniKit.header(px, "GLASS", [["SLICE", "%dX%d" % [n, n]]]).x
	for k in lives:
		var x := x0 + k * 7
		var broke := k < mistakes
		px.rect(x, 1, 6, 7, BLACK)
		px.rect(x + 1, 2, 4, 5, CRACKED if broke else SCAN)
		px.rect(x + 1, 2, 4, 1, CRACKED if broke else MiniPix.CHILL)
		if broke:
			px.rect(x + 2, 3, 1, 1, MiniPix.CHILL)
			px.rect(x + 3, 4, 1, 2, MiniPix.CHILL)
	if forgive:
		px.text("+%d" % forgive, x0 + lives * 7 + 2, 2, MiniPix.GOOD)
	MiniKit.deck(px, false)
	# the screen's bezel
	px.rect(GX - 2, GY - 2, GW + 4, GW + 4, MiniPix.BEVEL_LO)
	px.rect(GX - 1, GY - 1, GW + 2, GW + 2, BLACK)
	px.rect(GX - 2, GY + GW + 1, GW + 4, 1, MiniPix.BEVEL_HI)
	px.rect(GX + GW + 1, GY - 2, 1, GW + 4, MiniPix.BEVEL_HI)
	_clues(now)
	for i in n:
		for j in n:
			_cell(i, j, now)
	# the scan line idles down the glass
	if not over:
		var sy := GY + floori(fmod((now - 1000.0) / 30.0, GW + 30.0))
		if sy < GY + GW:
			for x in range(GX, GX + GW):
				if MiniPix.bay(x, sy) < 0.35:
					px.rect(x, sy, 1, 1, Color("#2b4a55"))
	if won > 0.0:
		var u := minf(1.0, (now - won) / 600.0)
		if u < 1.0:
			px.rect(GX, GY + MiniPix.jr(u * GW), GW, 1, WHITE)
		MiniKit.status(px, "FOUND: " + String(P.name), "good", false)
	elif lost > 0.0:
		MiniKit.status(px, "SCAN LOST", "bad", false)
	if not touched and now - 1000.0 < 4500.0:
		MiniKit.tell(px, "FILL IN THE SCAN.", ["click"] as Array[String], (now - 1000.0) / 1000.0)
	dirty = true


## The row bars left of the glass and the column bars over it, their runs, and their green sweeps.
func _clues(now: float) -> void:
	for i in n:
		var d := row_done(i)
		var y := GY + i * CS
		_bar(GX - CLW + 1, y, CLW - 3, CS, true, d, i == last_row and now - last_t < 500.0)
		var x := GX - 6
		var nums := rows[i] if not rows[i].is_empty() else PackedInt32Array([0])
		for k in range(nums.size() - 1, -1, -1):
			x -= str(nums[k]).length() * 4 - 1
			px.text(str(nums[k]), x, y + ((CS - 5) >> 1), MiniPix.MARK if d else MiniPix.ICE)
			x -= 3
		var sw: float = sweep_row.get(i, 0.0)
		if sw and now - sw < 450.0:
			var sx := GX + MiniPix.jr((now - sw) / 450.0 * GW)
			px.rect(sx, y, 1, CS, MiniPix.MARK)
			if sx - 1 >= GX:
				px.rect(sx - 1, y, 1, CS, MiniPix.GOOD)
	for j in n:
		var d := col_done(j)
		var x := GX + j * CS
		_bar(x, GY - CLH + 1, CS, CLH - 3, false, d, j == last_col and now - last_t < 500.0)
		var y := GY - 6
		var nums := cols[j] if not cols[j].is_empty() else PackedInt32Array([0])
		for k in range(nums.size() - 1, -1, -1):
			y -= 5
			px.text(str(nums[k]), x + (CS >> 1), y, MiniPix.MARK if d else MiniPix.ICE, "center")
			y -= 1
		var sw: float = sweep_col.get(j, 0.0)
		if sw and now - sw < 450.0:
			var sy := GY + MiniPix.jr((now - sw) / 450.0 * GW)
			px.rect(x, sy, CS, 1, MiniPix.MARK)
			if sy - 1 >= GY:
				px.rect(x, sy - 1, CS, 1, MiniPix.GOOD)


func _bar(x: int, y: int, w: int, h: int, horiz: bool, d: bool, hot: bool) -> void:
	px.rect(x, y, w, h, BLACK)
	px.rect(x + 1, y + 1, w - 2, h - 2, Color("#10261c") if d else Color("#0a1520"))
	var ec := MiniPix.GOOD if d else (WHITE if hot else MiniPix.TRACTOR)
	var dim := MiniPix.mix(ec, BLACK, 0.4)
	if horiz:
		px.rect(x + w - 2, y + 1, 1, h - 2, ec)
		for yy in range(y + 1, y + h - 1):
			if MiniPix.bay(x + w - 3, yy) < 0.5:
				px.rect(x + w - 3, yy, 1, 1, dim)
	else:
		px.rect(x + 1, y + h - 2, w - 2, 1, ec)
		for xx in range(x + 1, x + w - 1):
			if MiniPix.bay(xx, y + h - 3) < 0.5:
				px.rect(xx, y + h - 3, 1, 1, dim)
	px.rect(x + 1, y + 1, w - 3 if horiz else 1, 1, SCAN)


func _pic(i: int, j: int) -> bool:
	return i >= 0 and j >= 0 and i < n and j < n and _grid()[i][j] == 1


func _cell(i: int, j: int, now: float) -> void:
	var x := GX + j * CS
	var y := GY + i * CS
	var s := st[i][j]
	if s == 1 or won > 0.0:
		_solid(i, j, x, y, now)
		return
	# the scanner's glass
	px.rect(x, y, CS, CS, KNOWN if s == 2 else GLASS)
	px.rect(x, y, CS, 1, KNOWN_HI if s == 2 else GLASS_HI)
	px.rect(x, y, 1, CS, KNOWN_HI if s == 2 else GLASS_HI)
	px.rect(x + CS - 1, y, 1, CS, EDGE)
	px.rect(x, y + CS - 1, CS, 1, EDGE)
	if s == 0 and (i == last_row or j == last_col) and now - last_t < 600.0:
		var th := 0.3 * (1.0 - (now - last_t) / 600.0)
		for yy in range(1, CS - 1):
			for xx in range(1, CS - 1):
				if MiniPix.bay(x + xx, y + yy) < th:
					px.rect(x + xx, y + yy, 1, 1, SCAN)
	if s == 2:
		px.rect(x + (CS >> 1), y + (CS >> 1), 1, 1, Color("#1f2935"))
	if s == 3:
		_crack(i, j, x, y, now)


## A filled cell (or every cell once the find is up): the picture in its hue, edged where it ends.
func _solid(i: int, j: int, x: int, y: int, now: float) -> void:
	if not _grid()[i][j]:
		px.rect(x, y, CS, CS, EDGE if won > 0.0 else KNOWN_HI)
		return
	var age := now - float(fill_t[Vector2i(i, j)]) if fill_t.has(Vector2i(i, j)) else 999.0
	px.rect(x, y, CS, CS, ramp[2])
	for yy in CS:
		for xx in CS:
			if MiniPix.bay(x + xx, y + yy) < 0.12:
				px.rect(x + xx, y + yy, 1, 1, ramp[3])
	var up := _pic(i - 1, j)
	var lf := _pic(i, j - 1)
	var dn := _pic(i + 1, j)
	var rt := _pic(i, j + 1)
	if not up:
		px.rect(x, y, CS, 2, ramp[3])
	if not lf:
		px.rect(x, y, 2, CS, ramp[3])
	if not dn:
		px.rect(x, y + CS - 2, CS, 2, ramp[1])
	if not rt:
		px.rect(x + CS - 2, y, 2, CS, ramp[1])
	if not up:
		px.rect(x, y, CS, 1, ramp[0])
	if not lf:
		px.rect(x, y, 1, CS, ramp[0])
	if not dn:
		px.rect(x, y + CS - 1, CS, 1, ramp[0])
	if not rt:
		px.rect(x + CS - 1, y, 1, CS, ramp[0])
	if age < 220.0:
		var th := 1.0 - age / 220.0
		for yy in range(1, CS - 1):
			for xx in range(1, CS - 1):
				if MiniPix.bay(x + xx, y + yy) < th * 0.8:
					px.rect(x + xx, y + yy, 1, 1, WHITE)


func _crack(i: int, j: int, x: int, y: int, now: float) -> void:
	var age := now - float(crack_t[Vector2i(i, j)])
	var grow := minf(1.0, age / 250.0)
	var cx := x + (CS >> 1)
	var cy := y + (CS >> 1)
	px.rect(x + 1, y + 1, CS - 2, CS - 2, CRACKED)
	for k in ARMS.size():
		var a: Array = ARMS[k]
		var ln := (CS / 2.0 - 1.0) * grow * (0.8 if k % 2 else 1.0)
		var fx := float(cx)
		var fy := float(cy)
		var s := 0
		while s < ln:
			fx += float(a[0]) * 0.9 + sin(s * 1.7 + k) * 0.4
			fy += float(a[1]) * 0.9 + cos(s * 1.3 + k) * 0.4
			px.rect(MiniPix.jr(fx), MiniPix.jr(fy), 1, 1, WHITE if s < 2 else MiniPix.CHILL)
			s += 1
	px.rect(cx, cy, 1, 1, WHITE)
	if age < 150.0 and int(age / 40.0) % 2:
		px.rect(x, y, CS, 1, MiniPix.BAD)
