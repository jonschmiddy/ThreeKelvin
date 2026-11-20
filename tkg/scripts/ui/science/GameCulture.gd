class_name GameCulture
extends MiniGame

## Culture Dish (`culture2.js` on its approved page, `layout.page_js("culture")`: fit3 + the kit), rule
## for rule: drop seed droplets on a hex dish, then GROW it a ring at a time; reach every food speck,
## and a stain kills what touches it. The page's clock is milliseconds from 1000 at the mount.
## Why: docs/why/MiniGame.md#culture-dish

const CFG := {
	1: {R = 4, s = 6, steps = 3, seeds = 1, food = 3, stain = 3},
	2: {R = 4, s = 6, steps = 3, seeds = 2, food = 4, stain = 4},
	3: {R = 5, s = 5, steps = 3, seeds = 2, food = 5, stain = 6},
	4: {R = 5, s = 5, steps = 3, seeds = 3, food = 6, stain = 7},
	5: {R = 5, s = 5, steps = 4, seeds = 2, food = 6, stain = 6},
}
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)]
const W := MiniKit.W
const H := MiniKit.H
const CX := 75
const CY := 65
const AR := 51
const RO := 55
const STEPMS := 520.0
const T0 := 1000.0
## The colour ramps as 0xRRGGBB (the page's `rgb` arrays it writes straight into its pixels).
const GREEN: Array[int] = [0x14301f, 0x2c5a40, 0x4f8a6c, 0x7fb89a, 0xb8f5d8]
const GREY: Array[int] = [0x15181d, 0x2f353d, 0x4a525c, 0x6b7d94, 0x8fa3ba]
const AGAR: Array[int] = [0x2c200d, 0x3d2d13, 0x523d1a, 0x6a5022, 0x83642b, 0x9c7834]
const STA: Array[int] = [0x120709, 0x21090d, 0x3a1013]
const DROP: Array[Color] = [Color("#0b3531"), Color("#1c7c72"), Color("#4fe0cc"), Color("#b8f5f0")]
const RIM_DK := Color("#3b4a5c")
const GHOST_DK := Color("#14301f")
const DEAD_DK := Color("#5a1a14")
const SHADOW := Color("#1e160a")
const PIP_HI := Color("#e07a66")

var p: Dictionary[String, Variant] = {}
var c: Dictionary = {}
var nn := 0
var pos: Array[Vector2i] = []
var rad := 0.0
var food_set: Dictionary[int, bool] = {}
var stain_mask := PackedByteArray()
var tries := 2
var t1 := 0.0
var mode := "place"
var attempt := 0
var best: Dictionary = {frac = -1.0, idx = 0, covered = 0, hits = 0, secs = -1.0}
var ended := false
var seeds: Array[int] = []
var touched := false
var hover := -1
var pressed := ""
var press_t := 0.0
var banner := ""
var bparts: Array = []
var drops: Array[Dictionary] = []
var parts: Array[Dictionary] = []
var ripples: Array[Dictionary] = []
var pulses: Array[Dictionary] = []
## The growth under way: {seeds, ev, step_t, seen, covered, hits, done_t}; empty before a GROW.
var run: Dictionary = {}
## The buttons the last frame drew: {x, y, w, h, label}.
var buttons: Array[Dictionary] = []
var _last := 0.0
var _touch := false
var _hs := 0
var bg := PackedByteArray()
var sm := PackedFloat32Array()
var phase := PackedFloat32Array()
var dish := PackedInt32Array()
var fl := PackedFloat32Array()
var fd := PackedFloat32Array()
var inside_ := PackedByteArray()


func id() -> StringName:
	return &"culture"


func hint() -> String:
	return "Eat every speck."


func controls() -> Array[String]:
	return ["click"]


# ---------------------------------------------------------------- the rules (a hex dish)

static func board(r: int) -> Dictionary[String, Variant]:
	var cells: Array[Vector2i] = []
	var idx: Dictionary[Vector2i, int] = {}
	for q in range(-r, r + 1):
		for rr in range(-r, r + 1):
			if absi(q + rr) > r:
				continue
			idx[Vector2i(q, rr)] = cells.size()
			cells.append(Vector2i(q, rr))
	var nb: Array[PackedInt32Array] = []
	for cl in cells:
		var row := PackedInt32Array()
		for d in DIRS:
			if idx.has(cl + d):
				row.append(idx[cl + d])
		nb.append(row)
	var out: Dictionary[String, Variant] = {}
	out.assign({R = r, cells = cells, nb = nb})
	return out


static func hd(b: Dictionary, i: int, j: int) -> int:
	var a: Vector2i = b.cells[i]
	var z: Vector2i = b.cells[j]
	return (absi(a.x - z.x) + absi(a.y - z.y) + absi(a.x + a.y - z.x - z.y)) / 2


static func shuffled(a: Array[int], r: RandomNumberGenerator) -> Array[int]:
	var out: Array[int] = a.duplicate()
	for i in range(out.size() - 1, 0, -1):
		var j := floori(r.randf() * (i + 1))
		var tmp: int = out[i]
		out[i] = out[j]
		out[j] = tmp
	return out


## The one rule: each step, every free spot touching the culture grows; one on a stain dies and stays
## dead. frames[k] holds that step's births as (spot, parent, ok).
static func simulate(b: Dictionary, steps: int, sd: Array[int], stains: PackedByteArray) -> Dictionary[String, Variant]:
	var nb: Array[PackedInt32Array] = b.nb
	var n := nb.size()
	var alive := PackedByteArray()
	alive.resize(n)
	var born := PackedInt32Array()
	born.resize(n)
	born.fill(-1)
	var dead := PackedByteArray()
	dead.resize(n)
	var ndead := 0
	var frames: Array[Array] = []
	for i in sd:
		alive[i] = 1
		born[i] = 0
	var stained := not stains.is_empty()
	for t in range(1, steps + 1):
		var births: Array[Vector3i] = []
		for i in n:
			if alive[i] or dead[i]:
				continue
			for j in nb[i]:
				if alive[j] and born[j] < t:
					births.append(Vector3i(i, j, 0 if stained and stains[i] else 1))
					break
		for e in births:
			if e.z == 1:
				alive[e.x] = 1
				born[e.x] = t
			else:
				dead[e.x] = 1
				ndead += 1
		frames.append(births)
	var out: Dictionary[String, Variant] = {}
	out.assign({alive = alive, born = born, dead = ndead, frames = frames})
	return out


static func mask(pz: Dictionary) -> PackedByteArray:
	var m := PackedByteArray()
	m.resize((pz.B.cells as Array).size())
	for s: int in pz.stains:
		m[s] = 1
	return m


static func evaluate(pz: Dictionary, sd: Array[int]) -> Dictionary[String, Variant]:
	var r := simulate(pz.B, pz.steps, sd, mask(pz))
	var alive: PackedByteArray = r.alive
	var covered := 0
	for f: int in pz.food:
		covered += 1 if alive[f] else 0
	var hits: int = r.dead
	var out: Dictionary[String, Variant] = {}
	out.assign({r = r, covered = covered, hits = hits, frac = maxf(0.0, covered - hits) / (pz.food as Array).size()})
	return out


static func wins(pz: Dictionary, sd: Array[int]) -> bool:
	var v := evaluate(pz, sd)
	return float(v.frac) == 1.0 and int(v.hits) == 0


static func gen(r: RandomNumberGenerator, d: int) -> Dictionary[String, Variant]:
	var cf: Dictionary = CFG.get(d, CFG[1])
	var bd := board(cf.R)
	var n := (bd.cells as Array).size()
	for tries_ in 3000:
		var sd := _seeds(bd, cf, n, r)
		if sd.is_empty():
			continue
		var sim := simulate(bd, cf.steps, sd, PackedByteArray())
		var alive: PackedByteArray = sim.alive
		var born: PackedInt32Array = sim.born
		# stains sit just past the reach, so a seed one spot off touches one
		var edge: Array[int] = []
		for i in n:
			if not alive[i]:
				for j in bd.nb[i]:
					if alive[j]:
						edge.append(i)
						break
		if edge.size() < int(cf.stain):
			continue
		var stains := _spaced(bd, shuffled(edge, r), cf.stain)
		if stains.size() < int(cf.stain):
			continue
		# food sits near the far edge of the reach
		var cand: Array[int] = []
		for i in n:
			if born[i] >= maxi(2, int(cf.steps) - 1):
				cand.append(i)
		var food := _spaced(bd, _by_born(shuffled(cand, r), born), cf.food)
		if food.size() < int(cf.food):
			continue
		var pz: Dictionary[String, Variant] = {}
		pz.assign({B = bd, R = cf.R, steps = cf.steps, nSeeds = cf.seeds, food = food, stains = stains, solution = sd})
		if _keep(pz, sd, n, tries_):
			return pz
	push_error("GameCulture: no puzzle at depth %d" % d)
	return {}


## The seeds: inside the dish's reach of cell 0, off each other; [] when one finds no place.
static func _seeds(bd: Dictionary, cf: Dictionary, n: int, r: RandomNumberGenerator) -> Array[int]:
	var sd: Array[int] = []
	for k in int(cf.seeds):
		var placed := false
		var a := 0
		while a < 60 and not placed:
			a += 1
			var i := floori(r.randf() * n)
			if hd(bd, i, 0) > int(cf.R) - 1:
				continue
			var near := false
			for j in sd:
				near = near or hd(bd, i, j) < mini(4, int(cf.steps) + 1)
			if near:
				continue
			sd.append(i)
			placed = true
		if not placed:
			return []
	return sd


## Up to `count` spots from `order`, each at least 2 from those already taken.
static func _spaced(bd: Dictionary, order: Array[int], count: int) -> Array[int]:
	var out: Array[int] = []
	for i in order:
		var ok := true
		for s in out:
			ok = ok and hd(bd, s, i) >= 2
		if ok:
			out.append(i)
		if out.size() == count:
			break
	return out


## JS's stable sort, latest born first: ties keep their shuffled order.
static func _by_born(order: Array[int], born: PackedInt32Array) -> Array[int]:
	var keyed: Array[Vector2i] = []
	for k in order.size():
		keyed.append(Vector2i(born[order[k]], k))
	keyed.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x > b.x if a.x != b.x else a.y < b.y)
	var out: Array[int] = []
	for e in keyed:
		out.append(order[e.y])
	return out


## The deal is kept when it wins, every seed matters, and few other spots win.
static func _keep(pz: Dictionary, sd: Array[int], n: int, tries_: int) -> bool:
	if not wins(pz, sd):
		return false
	var banned: Dictionary[int, bool] = {}
	for f: int in pz.food:
		banned[f] = true
	for s: int in pz.stains:
		banned[s] = true
	if sd.size() > 1:
		for k in sd.size():
			var less: Array[int] = sd.duplicate()
			less.remove_at(k)
			if int(evaluate(pz, less).covered) == (pz.food as Array).size():
				return false
	var alt := 0
	var k2 := 0
	while k2 < sd.size() and alt <= 2:
		for i in n:
			if banned.has(i) or sd.has(i):
				continue
			var mv: Array[int] = sd.duplicate()
			mv[k2] = i
			if wins(pz, mv):
				alt += 1
		k2 += 1
	return alt <= (1 if tries_ < 1500 else 2)


static func score_of(frac: float, idx: int, secs: float, t1_: float) -> float:
	var tf := 1.0 if secs <= t1_ else maxf(0.0, 1.0 - (secs - t1_) / (2.0 * t1_))
	return clampf(frac * (1.0 - 0.15 * idx) * (0.8 + 0.2 * tf), 0.0, 1.0)


# ---------------------------------------------------------------- the deal

func _mount() -> void:
	p = gen(rng, depth)
	if p.is_empty():
		px = MiniPix.new(W, H)
		ended = true
		done(0.0, "No puzzle")
		return
	c = CFG[depth]
	nn = (p.B.cells as Array).size()
	var s := sensors
	tries = 2 + int(s >= 1) + int(s >= 3) + int(s >= 5)
	t1 = 25.0 + 10.0 * depth + (int(s >= 2) + int(s >= 4)) * 10.0
	px = MiniPix.new(W, H)
	var cs: float = c.s
	for cl: Vector2i in p.B.cells:
		pos.append(Vector2i(MiniPix.jr(CX + cs * sqrt(3.0) * (cl.x + cl.y / 2.0)), MiniPix.jr(CY + cs * 1.5 * cl.y)))
	rad = cs * 0.86
	for f: int in p.food:
		food_set[f] = true
	stain_mask = mask(p)
	_hs = (int(p.food[0]) * 7919 + int(p.solution[0]) * 104729 + nn) | 1
	fl.resize(W * H)
	fd.resize(W * H)
	inside_.resize(W * H)
	if drawing:
		GameCultureLook.background(self)
	_frame(T0)


## The page's own hash for the look (never the stream): its product passes 2^53 in doubles, as JS's does.
func hr() -> float:
	var v := float(_hs) * 1103515245.0 + 12345.0
	_hs = int(v) & 0x7fffffff
	return _hs / float(0x7fffffff)


func _now() -> float:
	return T0 + t * 1000.0


# ---------------------------------------------------------------- the clock

func _tick(_dt: float) -> void:
	var now := _now()
	if now - _last < 32.0:
		return
	_last = now
	_frame(now)


## One of the page's frames: the growth worked out, then the picture (or only its buttons).
func _frame(now: float) -> void:
	if not run.is_empty():
		_tick_run(now)
	if drawing:
		GameCultureLook.render(self, now)
	else:
		panel(now)


func animating(now: float) -> bool:
	if run.is_empty() or (run.step_t as Array).is_empty():
		return false
	return now - float((run.step_t as Array).back()) < STEPMS * 0.9


func _tick_run(now: float) -> void:
	var st: Array = run.step_t
	var frames: Array = run.ev.r.frames
	var seen: Dictionary = run.seen
	for k in st.size():
		var el := now - float(st[k])
		for b: Vector3i in frames[k]:
			if seen.has(b.x):
				continue
			if b.z == 1 and el >= STEPMS * 0.6:
				seen[b.x] = true
				if food_set.has(b.x):
					run.covered = int(run.covered) + 1
					pulses.append({x = pos[b.x].x, y = pos[b.x].y, t = now})
			if b.z == 0 and el >= STEPMS * 0.7:
				seen[b.x] = true
				run.hits = int(run.hits) + 1
	var steps: int = p.steps
	if mode == "grow" and st.size() == steps and now - float(st[steps - 1]) > STEPMS * 1.1 and float(run.done_t) == 0.0:
		run.done_t = now
		_ended(now)


## The last ring is in: the try's result, kept if it is the best.
func _ended(now: float) -> void:
	var ev: Dictionary = run.ev
	if float(ev.frac) > float(best.frac):
		best = {frac = ev.frac, idx = attempt, covered = ev.covered, hits = ev.hits, secs = (now - T0) / 1000.0}
	var nf := (p.food as Array).size()
	if float(ev.frac) == 1.0 and int(ev.hits) == 0:
		sfx(&"win")
		banner = "ALL FED"
		bparts = [["ALL FED", "good"]]
		mode = "done"
		after(0.9, finish)
		return
	banner = "%d/%d FED" % [int(ev.covered), nf]
	bparts = [[banner, "neutral"]]
	if int(ev.hits) != 0:
		bparts.append(["%d DEAD" % int(ev.hits), "bad"])
	if attempt + 1 >= tries:
		mode = "done"
		bparts.append(["NO TRIES", "bad"])
		after(1.3, finish)
		return
	mode = "result"


# ---------------------------------------------------------------- input

func cell_at(x: int, y: int) -> int:
	var bi := -1
	var bd := 1e9
	for i in nn:
		var d := GameSling.hyp(pos[i].x - x, pos[i].y - y)
		if d < bd:
			bd = d
			bi = i
	return bi if bd <= float(c.s) * 1.05 else -1


## A press works as the page's touch path: on a seed it lifts it, elsewhere it previews the rings
## until the lift drops the seed there.
func down(q: Vector2i) -> void:
	if ended:
		return
	touched = true
	var now := _now()
	for b in buttons:
		if q.x >= int(b.x) and q.x < int(b.x) + int(b.w) and q.y >= int(b.y) and q.y < int(b.y) + int(b.h):
			pressed = b.label
			press_t = now
			_press(b.label)
			return
	if mode != "place":
		return
	var i := cell_at(q.x, q.y)
	if i < 0:
		return
	var at := seeds.find(i)
	if at >= 0:
		seeds.remove_at(at)
		ripples.append({x = pos[i].x, y = pos[i].y, t = now, c = MiniPix.COLD})
		return
	_touch = true
	hover = i


func move(q: Vector2i) -> void:
	hover = cell_at(q.x, q.y) if mode == "place" else -1


func up(q: Vector2i, cancel := false) -> void:
	if not _touch:
		return
	_touch = false
	var i := -1 if cancel else cell_at(q.x, q.y)
	hover = -1
	if i >= 0 and mode == "place" and not ended:
		_drop(i, _now())


func _press(label: String) -> void:
	match label:
		"GROW":
			grow()
		"KEEP":
			finish()
		"AGAIN":
			again()


func _drop(i: int, now: float) -> void:
	if food_set.has(i) or stain_mask[i] == 1:
		ripples.append({x = pos[i].x, y = pos[i].y, t = now, c = MiniPix.BAD})
		return
	if seeds.has(i):
		return
	if seeds.size() >= int(p.nSeeds):
		seeds.pop_front()
	seeds.append(i)
	drops.append({i = i, t = now})
	sfx(&"drop")


func grow() -> void:
	var now := _now()
	if mode == "place":
		if seeds.size() != int(p.nSeeds):
			return
		mode = "grow"
		banner = ""
		hover = -1
		run = {seeds = seeds.duplicate(), ev = evaluate(p, seeds), step_t = [], seen = {}, covered = 0, hits = 0, done_t = 0.0}
	if mode != "grow" or animating(now) or (run.step_t as Array).size() >= int(p.steps):
		return
	(run.step_t as Array).append(now)
	sfx(&"grow")


func again() -> void:
	if mode != "result":
		return
	attempt += 1
	run = {}
	banner = ""
	mode = "place"


func finish() -> void:
	if ended:
		return
	ended = true
	mode = "done"
	var bf := maxf(0.0, best.frac)
	var nf := (p.food as Array).size()
	var detail := "Never grew"
	if float(best.frac) >= 0.0:
		detail = "Fed %d/%d%s on try %d" % [int(best.covered), nf, (", %d died" % int(best.hits)) if int(best.hits) != 0 else "", int(best.idx) + 1]
	done(score_of(bf, best.idx, float(best.secs) if float(best.secs) >= 0.0 else 999.0, t1), detail)


func give_up() -> void:
	_later.clear()
	if not ended:
		mode = "done"
		finish()


## GROW's centre on the canvas (the solver presses it there).
static func grow_at() -> Vector2:
	return Vector2(W - MiniKit.GUT - 17, MiniKit.deck_y(false) - 2 - MiniKit.BTN_H + 6) + Vector2(0.5, 0.5)


## The panel under the dish: the seeds or rings left, GROW (or KEEP and AGAIN); it says which
## buttons the frame drew, and draws them when the game is drawn.
func panel(now: float) -> void:
	buttons.clear()
	var y0 := 104
	var by := MiniKit.deck_y(false) - 2 - MiniKit.BTN_H
	if mode == "place" and drawing:
		px.rect(4, y0 + 7, 11, 3, MiniPix.BEVEL_LO)
		px.rect(5, y0 + 8, 9, 1, MiniPix.CHILL)
		px.rect(14, y0 + 6, 4, 5, MiniPix.BAD)
		px.rect(15, y0 + 6, 2, 1, PIP_HI)
		px.rect(2, y0 + 8, 2, 1, MiniPix.CHILL)
		for k in int(p.nSeeds):
			var x := 22 + k * 8
			if k < seeds.size():
				GameCultureLook.circ(px, x + 1, y0 + 9, 2, MiniPix.COLD, 0.5)
			else:
				GameCultureLook.ball(px, x + 1, y0 + 9, 2, DROP)
	if mode == "place" or mode == "grow":
		var dn := (run.step_t as Array).size() if not run.is_empty() else 0
		if mode == "grow" and drawing:
			for k in int(p.steps):
				var x := 6 + k * 9
				GameCultureLook.circ(px, x, y0 + 9, 3, MiniPix.COLD if k < dn else MiniPix.MARK, 0.4 if k < dn else INF)
				if k >= dn:
					px.rect(x, y0 + 9, 1, 1, MiniPix.MARK)
		var can := seeds.size() == int(p.nSeeds) if mode == "place" else (not animating(now) and dn < int(p.steps))
		_btn(now, W - MiniKit.GUT - 33, by, "GROW", can, true)
	elif mode == "result":
		_btn(now, MiniKit.GUT, by, "KEEP", true, false)
		_btn(now, W - MiniKit.GUT - 33, by, "AGAIN", true, false)


func _btn(now: float, x: int, y: int, label: String, on: bool, act: bool) -> void:
	if drawing:
		var pr := pressed == label and now - press_t < 140.0
		var st := "disabled" if not on else (("active-pressed" if pr else "active") if act else ("pressed" if pr else "normal"))
		MiniKit.button(px, x, y, 33, MiniKit.BTN_H, label, st, "grow" if label == "GROW" else "")
	if on:
		buttons.append({x = x, y = y, w = 33, h = MiniKit.BTN_H, label = label})
