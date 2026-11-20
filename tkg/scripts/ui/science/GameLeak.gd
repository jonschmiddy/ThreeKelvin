class_name GameLeak
extends MiniGame

## LEAK HUNT (Jon loved, Nov 17): puff smoke in a dead station room, watch where it gets sucked,
## and patch the hidden hull leak before the air runs out. A port of the approved `wreck3.js`.
## Its canvas is 152 wide: the glass shows all but a column each side, the view's frame inside it.
## Why: docs/why/MiniGame.md#the-round-2-games

const PW := 152
const VH := 92
const HUD := 26
const PH := VH + HUD
## Where a leak can be: the back wall above the consoles.
const RX0 := 6.0
const RX1 := 146.0
const RY0 := 10.0
const RY1 := 70.0
const CFG := {
	1: {leaks = 1, wind = 0, S = 450.0, life = 2.6, tol = 5.0, secs = 60.0, spare = 2},
	2: {leaks = 1, wind = 0, S = 320.0, life = 2.2, tol = 4.5, secs = 60.0, spare = 2},
	3: {leaks = 2, wind = 0, S = 400.0, life = 2.4, tol = 4.5, secs = 85.0, spare = 1},
	4: {leaks = 1, wind = 1, S = 400.0, life = 2.4, tol = 4.5, secs = 70.0, spare = 1},
	5: {leaks = 2, wind = 1, S = 330.0, life = 2.2, tol = 4.0, secs = 95.0, spare = 1},
}
const WIND := 6.0
const M: Array[Color] = [Color("#080b11"), Color("#111823"), Color("#182230"), Color("#22303f"), Color("#2d3c4e"),
	Color("#3d4d61"), Color("#6b7d94"), Color("#8fa3ba"), Color("#c3d2e2")]
const RED: Array[Color] = [Color("#1a0d0b"), Color("#2e1410"), Color("#4a1c16"), Color("#7a2f24"), MiniPix.BAD]
const PLANET := Color("#1a2628")
const PLANET_DK := Color("#0f1719")
const CABLE_DK := Color("#3e3016")
const SMOKE_HI := Color("#e6eef6")
const AIR_LOW := Color("#e07a62")
const AIR_LOW_DK := Color("#7a2f24")
const BTN_ON := Color("#3a2416")
const BTN_ON_DK := Color("#1c120c")
const BY := VH + 8
const BHT := 16
const BUTTONS: Array[Dictionary] = [{id = "smoke", x = 2, w = 44, lab = "SMOKE"}, {id = "patch", x = 48, w = 44, lab = "PATCH"}]

var P: Dictionary = {}
var S: Dictionary = {}
var mode := "smoke"
var done_fired := false
var end_t := 0.0
var status := ""
var status_col := MiniPix.CHILL
var status_t := 0.0
var fx: Array = []
var junk: Array = []
var motes: Array = []
var _room: Image
var _finish_at := -1.0
var _acc := 0.0


func id() -> StringName:
	return &"leak"


func hint() -> String:
	return "Patch the leak."


func controls() -> Array[String]:
	return ["click"]


# ---------------------------------------------------------------- the rules

static func gen(d: int, sn: int, r: RandomNumberGenerator) -> Dictionary[String, Variant]:
	var c: Dictionary = CFG[d]
	var leaks: Array = []
	while leaks.size() < int(c.leaks):
		var x := RX0 + 6.0 + r.randf() * (RX1 - RX0 - 12.0)
		var y := RY0 + 4.0 + r.randf() * (RY1 - RY0 - 8.0)
		if leaks.any(func(l: Dictionary) -> bool: return Vector2(float(l.x) - x, float(l.y) - y).length() < 34.0):
			continue
		leaks.append({x = x, y = y, open = true})
	var wind := {}
	if int(c.wind):
		var side := -1 if r.randf() < 0.5 else 1
		wind = {dir = -side, x = 2 if side < 0 else PW - 3, y = 22.0 + r.randf() * 40.0}
	var out: Dictionary[String, Variant] = {}
	out.assign({leaks = leaks, wind = wind, S = c.S, life = float(c.life) + 0.4 * sn, tol = c.tol,
		patches = int(c.leaks) + int(c.spare) + (1 if sn >= 3 else 0), T = float(c.secs) + 8 * sn,
		par_puffs = 3 * int(c.leaks) + (1 if int(c.wind) else 0)})
	return out


## The air's flow at (x, y): each open leak a sink (speed falling off as 1/r), plus the fan's draft.
static func field(pz: Dictionary, x: float, y: float) -> Vector2:
	var v := Vector2.ZERO
	for l: Dictionary in pz.leaks:
		if not l.open:
			continue
		var dx := float(l.x) - x
		var dy := float(l.y) - y
		var r2 := dx * dx + dy * dy + 4.0
		v += Vector2(float(pz.S) * dx / r2, float(pz.S) * dy / r2)
	var w: Dictionary = pz.wind
	if not w.is_empty():
		var f := 0.45 + 0.55 * exp(-pow((y - float(w.y)) / 26.0, 2.0))
		v.x += int(w.dir) * WIND * f
	return v


static func new_sim() -> Dictionary[String, Variant]:
	var out: Dictionary[String, Variant] = {}
	out.assign({t = 0.0, air = 1.0, puffs = 0, used = 0, wrong = 0, sealed = 0, parts = [], over = false, won = false, events = [], patches_at = []})
	return out


static func puff(sm: Dictionary, pz: Dictionary, x: float, y: float) -> void:
	if sm.over:
		return
	sm.puffs += 1
	for i in 24:
		# where each wisp starts and how long it lasts is the smoke's look, not the game's state
		var a := randf() * 6.283
		var r := sqrt(randf()) * 3.0
		(sm.parts as Array).append({x = x + cos(a) * r, y = y + sin(a) * r, age = 0.0, life = float(pz.life) * (0.7 + 0.3 * randf()), trail = [], gone = false, j = randf() * 6.283})
	(sm.events as Array).append({type = "puff", x = x, y = y})


static func patch(sm: Dictionary, pz: Dictionary, x: float, y: float) -> void:
	if sm.over or int(sm.used) >= int(pz.patches):
		return
	sm.used += 1
	var hit: Dictionary = {}
	for l: Dictionary in pz.leaks:
		if l.open and Vector2(float(l.x) - x, float(l.y) - y).length() <= float(pz.tol):
			hit = l
			break
	if not hit.is_empty():
		hit.open = false
		sm.sealed += 1
		(sm.patches_at as Array).append({x = hit.x, y = hit.y, ok = true})
		(sm.events as Array).append({type = "sealed", x = hit.x, y = hit.y})
	else:
		sm.wrong += 1
		(sm.patches_at as Array).append({x = x, y = y, ok = false})
		(sm.events as Array).append({type = "wrong", x = x, y = y})
	if (pz.leaks as Array).all(func(l: Dictionary) -> bool: return not l.open):
		sm.won = true
		sm.over = true
		(sm.events as Array).append({type = "won"})
	elif int(sm.used) >= int(pz.patches):
		sm.over = true
		(sm.events as Array).append({type = "fail", why = "patches"})


static func step(sm: Dictionary, pz: Dictionary, dt: float) -> void:
	sm.t += dt
	for p: Dictionary in sm.parts:
		if p.gone:
			continue
		p.age += dt
		if float(p.age) > float(p.life):
			p.gone = true
			continue
		var v := field(pz, p.x, p.y)
		var jx := cos(float(p.j) + float(p.age) * 3.0) * 1.2
		var jy := sin(float(p.j) * 1.3 + float(p.age) * 2.5) * 1.2
		var sx := (v.x + jx) * dt
		var sy := (v.y + jy) * dt
		var m := Vector2(sx, sy).length()
		if m > 3.0:
			sx *= 3.0 / m
			sy *= 3.0 / m
		p.x += sx
		p.y += sy
		for l: Dictionary in pz.leaks:
			if l.open and Vector2(float(l.x) - float(p.x), float(l.y) - float(p.y)).length() < 2.2:
				p.gone = true
				p.sucked = true
				break
		if float(p.x) < 1 or float(p.x) > PW - 2 or float(p.y) < 1 or float(p.y) > VH - 2:
			p.gone = true
	sm.parts = (sm.parts as Array).filter(func(p: Dictionary) -> bool: return not p.gone)
	if sm.over:
		return
	var open := (pz.leaks as Array).filter(func(l: Dictionary) -> bool: return l.open).size()
	sm.air -= dt / float(pz.T) * (float(open) / (pz.leaks as Array).size())
	if float(sm.air) <= 0.0:
		sm.air = 0.0
		sm.over = true
		(sm.events as Array).append({type = "fail", why = "air"})


static func score_of(sm: Dictionary, pz: Dictionary) -> float:
	var nl := (pz.leaks as Array).size()
	if not sm.won:
		return clampf(0.1 + 0.25 * float(sm.sealed) / nl, 0.0, 0.35)
	var extra := maxi(0, int(sm.puffs) - int(pz.par_puffs))
	return clampf(1.0 - 0.05 * extra - 0.2 * int(sm.wrong) - 0.25 * clampf((0.55 - float(sm.air)) / 0.55, 0.0, 1.0), 0.3, 1.0)


static func bt(x: int, y: int) -> float:
	return MiniPix.bay(x, y)


# ---------------------------------------------------------------- the game

func _mount() -> void:
	px = MiniPix.new(PW, PH)
	P = gen(depth, sensors, rng)
	S = new_sim()
	_room = _draw_room()
	for i in 5:
		junk.append({k = ["mug", "pad", "tool", "sheet", "sheet"][i], x = RX0 + 10.0 + rng.randf() * (RX1 - RX0 - 20.0), y = RY0 + 20.0 + rng.randf() * 40.0,
			vx = (rng.randf() - 0.5) * 2.0, vy = (rng.randf() - 0.5) * 2.0, ang = rng.randf() * 4.0})
	for i in 14:
		motes.append({x = rng.randf() * PW, y = 10.0 + rng.randf() * 60.0, ph = rng.randf() * 6.0})
	_draw()


## The room, drawn once: panels lit by the emergency lamp, the pipe, the dead screen, the porthole,
## a hanging cable, consoles, a tipped chair.
func _draw_room() -> Image:
	var s := MiniPix.new(PW, VH)
	var lamp := Vector2(14, 6)
	for y in VH:
		for x in PW:
			var c := 2
			if y < 5:
				c = 0 if y == 4 else (3 if y == 1 else 2)
			elif y >= 78:
				c = 1 if ((x + (y >> 1)) % 4 == 0 or y == 78) else 2
				if y == 79:
					c = 4
			else:
				var pxl := (x - 1) % 30
				var py := (y - 5) % 24
				if bt(x, y) < 0.25:
					c = 3
				if pxl == 0 or py == 0:
					c = 4
				if pxl == 29 or py == 23:
					c = 1
			var d := Vector2(x - lamp.x, (y - lamp.y) * 1.3).length()
			var light := clampf(1.0 - d / 90.0, 0.0, 1.0)
			if bt(x, y) < light * 0.7 and c < 6:
				c += 1
			s.dot(x, y, M[mini(7, c)])
			if d < 34 and y > 4 and bt(x, y) < (1.0 - d / 34.0) * 0.9:
				s.dot(x, y, RED[3] if d < 12 else (RED[2] if d < 22 else RED[1]))
	for x in PW:
		s.dot(x, 6, M[5])
		s.dot(x, 7, M[4])
		s.dot(x, 8, M[2])
		s.dot(x, 9, M[0])
		if x % 24 == 5:
			s.dot(x, 5, M[6])
			s.dot(x, 6, M[7])
			s.dot(x, 7, M[5])
			s.dot(x, 8, M[3])
	var scr := Vector2i(52 + int(floorf(rng.randf() * 30.0)), 20)
	for y in 14:
		for x in 22:
			var e := x == 0 or y == 0 or x == 21 or y == 13
			s.dot(scr.x + x, scr.y + y, (M[5] if x == 0 or y == 0 else M[0]) if e else (M[3] if bt(x, y) < 0.12 else M[1]))
	s.text("NO SIG", scr.x + 11, scr.y + 5, M[3], "center")
	for y in 10:
		for x in 16:
			s.dot(110 + x, 16 + y, M[0] if y % 2 else M[4])
	_porthole(s, Vector2i(122 if scr.x < 80 else 28, 44), 9)
	var cx := 96 if scr.x < 80 else 44
	for i in 18:
		var x := cx + MiniPix.jr(sin(i * 0.35) * 2.0)
		s.dot(x, 10 + i, MiniPix.WARN)
		s.dot(x + 1, 10 + i, CABLE_DK)
	s.dot(cx, 28, MiniPix.HOT)
	for cw: Vector2i in [Vector2i(4, 30), Vector2i(104, 44)]:
		for y in range(66, 78):
			for x in range(cw.x, cw.x + cw.y):
				var e := x == cw.x or y == 66 or x == cw.x + cw.y - 1
				s.dot(x, y, (M[6] if y == 66 or x == cw.x else M[0]) if e else (M[5] if y < 69 else M[3]))
		for x in range(cw.x + 3, cw.x + cw.y - 3, 4):
			s.dot(x, 68, MiniPix.BAD if (x * 13) % 5 == 0 else M[2])
	for i in 7:
		s.dot(60 + i, 74 - i / 2, M[5])
		s.dot(60 + i, 75 - i / 2, M[0])
	for y in 5:
		s.dot(60, 70 + y, M[5])
		s.dot(66, 71 + y, M[4])
	s.text("DECK 4", PW - 28, VH - 10, M[3])
	for y in 3:
		for x in range(-3, 4):
			s.dot(int(lamp.x) + x, int(lamp.y) - 1 + y, M[6] if y == 0 else RED[4])
	return s.img


func _porthole(s: MiniPix, po: Vector2i, r: int) -> void:
	for y in range(-r - 2, r + 3):
		for x in range(-r - 2, r + 3):
			var d := Vector2(x, y).length()
			var xx := po.x + x
			var yy := po.y + y
			if d <= r:
				var c := MiniPix.VOID
				var pd := Vector2(x - 10, y - 12).length()
				if pd < 13:
					c = M[6] if pd > 12 else (PLANET if bt(xx, yy) < 0.4 else PLANET_DK)
				elif (xx * 31 + yy * 17) % 29 == 0:
					c = M[7]
				if x + y < -9 and d > r - 2 and bt(xx, yy) < 0.5:
					c = M[4]
				s.dot(xx, yy, c)
			elif d <= r + 1.2:
				s.dot(xx, yy, M[6] if x + y < 0 else M[3])
			elif d <= r + 2.2:
				s.dot(xx, yy, M[0])


func _banner(y: int, big: String, ctrls: Array[String], tt: float) -> void:
	var iw := -3
	for k in ctrls:
		iw += (13 if k == "click" else (21 if k == "hold" else 22)) + 3
	var w := maxi(big.length() * 4 - 1, iw) + 10
	var x := int(floorf(PW / 2.0 - w / 2.0))
	px.rect(x, y, w, 27, MiniPix.BEVEL_LO)
	px.rect(x + 1, y + 1, w - 2, 25, MiniPix.PANEL)
	px.rect(x + 1, y + 1, w - 2, 1, MiniPix.BEVEL_HI)
	px.text(big, PW / 2, y + 4, MiniPix.HOT, "center")
	var ix := int(floorf(PW / 2.0 - iw / 2.0))
	for k in ctrls:
		ix += px.icon(k, ix, y + 12, tt) + 3


func _draw() -> void:
	var tt: float = S.t
	px.img.blit_rect(_room, Rect2i(0, 0, PW, VH), Vector2i.ZERO)
	if sin(tt * 7.0) + sin(tt * 13.3) > 1.6:
		for y in range(5, 40):
			for x in 50:
				if bt(x, y) < 0.3:
					px.dot(x, y, M[1])
	_draw_fan(tt)
	for m: Dictionary in motes:
		var x := MiniPix.jr(float(m.x) + sin(tt * 0.3 + float(m.ph)) * 4.0)
		var y := MiniPix.jr(float(m.y) + cos(tt * 0.25 + float(m.ph)) * 3.0)
		if bt(x, y) < 0.6:
			px.dot(x, y, M[4])
	for p: Dictionary in S.patches_at:
		var x := MiniPix.jr(p.x) - 3
		var y := MiniPix.jr(p.y) - 3
		for j in 7:
			for i in 7:
				var e := i == 0 or j == 0 or i == 6 or j == 6
				px.dot(x + i, y + j, (M[7] if i == 0 or j == 0 else M[0]) if e else M[5])
		for q: Vector2i in [Vector2i(1, 1), Vector2i(5, 1), Vector2i(1, 5), Vector2i(5, 5)]:
			px.dot(x + q.x, y + q.y, M[7])
		px.dot(x + 3, y + 3, MiniPix.GOOD if p.ok else MiniPix.BAD)
	_draw_junk(tt)
	_draw_smoke()
	for f: Dictionary in fx:
		var k := float(f.age) / float(f.life)
		var r := 3.0 + k * 6.0
		for a in 16:
			var aa := a / 16.0 * 6.283
			var x := MiniPix.jr(float(f.x) + cos(aa) * r)
			var y := MiniPix.jr(float(f.y) + sin(aa) * r)
			if bt(x, y) < 1.0 - k:
				px.dot(x, y, MiniPix.GOOD if f.ok else MiniPix.BAD)
	for c: Vector4i in [Vector4i(1, 1, 1, 1), Vector4i(PW - 2, 1, -1, 1), Vector4i(1, VH - 2, 1, -1), Vector4i(PW - 2, VH - 2, -1, -1)]:
		for i in 5:
			px.dot(c.x + c.z * i, c.y, M[6])
			px.dot(c.x, c.y + c.w * i, M[6])
	px.text("DRONE 2", 4, VH - 8, M[6])
	if not int(S.puffs) and not S.over:
		_banner(26, "PATCH THE LEAK", ["click"], tt)
	if mode == "patch" and not S.over:
		for x in range(2, PW - 2):
			if bt(x, 0) < 0.5:
				px.dot(x, 1, MiniPix.EMBER)
				px.dot(x, VH - 2, MiniPix.EMBER)
	_draw_strip()
	dirty = true


func _draw_fan(tt: float) -> void:
	var w: Dictionary = P.wind
	if w.is_empty():
		return
	var fx0 := 0 if int(w.dir) > 0 else PW - 7
	var wy := MiniPix.jr(w.y)
	for y in range(-8, 9):
		for x in 7:
			var e := y == -8 or y == 8 or x == 0 or x == 6
			px.dot(fx0 + x, wy + y, M[5] if e else M[1])
	var a := tt * 14.0
	for k in 3:
		var aa := a + k * 2.094
		for r in range(1, 7):
			px.dot(MiniPix.jr(fx0 + 3 + cos(aa) * r * 0.45), MiniPix.jr(float(w.y) + sin(aa) * r), M[6])
	px.dot(fx0 + 3, wy, MiniPix.HOT)
	for dy: int in [-6, 0, 6]:
		for i in range(1, 7):
			var x := 7 + i if int(w.dir) > 0 else PW - 8 - i
			px.dot(x, MiniPix.jr(float(w.y) + dy + sin(tt * 12.0 + i + dy) * i * 0.25), MiniPix.EMBER if i % 2 else MiniPix.FLARE)


func _draw_junk(tt: float) -> void:
	for j: Dictionary in junk:
		var x := MiniPix.jr(j.x)
		var y := MiniPix.jr(j.y)
		match String(j.k):
			"mug":
				for yy in 4:
					for xx in 3:
						px.dot(x + xx, y + yy, M[8] if xx == 0 else M[6])
				px.dot(x + 3, y + 1, M[6])
				px.dot(x + 3, y + 2, M[6])
				for xx in 3:
					px.dot(x + xx, y + 4, M[0])
			"pad":
				for yy in 5:
					for xx in 4:
						px.dot(x + xx, y + yy, M[7] if yy == 0 else (MiniPix.TRACTOR if yy == 2 and xx > 0 else M[4]))
				for xx in 4:
					px.dot(x + xx, y + 5, M[0])
			"tool":
				var c := cos(float(j.ang))
				var s2 := sin(float(j.ang))
				for i in range(-3, 4):
					px.dot(MiniPix.jr(x + c * i), MiniPix.jr(y + s2 * i), MiniPix.WARN if i > 1 else M[7])
				px.dot(MiniPix.jr(x + c * 4 - s2), MiniPix.jr(y + s2 * 4 + c), MiniPix.WARN)
			_:
				var f := sin(tt * 3.0 + float(j.ang)) > 0.0
				for i in 4:
					px.dot(x + i, y + (1 if f and i > 1 else 0), M[8])
				px.dot(x, y + 1, M[6])


## Smoke: a head pixel and a short fading trail per wisp.
func _draw_smoke() -> void:
	for p: Dictionary in S.parts:
		var k := float(p.age) / float(p.life)
		var tr: Array = p.trail
		for i in tr.size():
			var q: Vector2 = tr[i]
			var tk := k + (tr.size() - i) * 0.06
			if bt(MiniPix.jr(q.x), MiniPix.jr(q.y)) > (1.0 - tk) * 0.8:
				continue
			px.dot(MiniPix.jr(q.x), MiniPix.jr(q.y), MiniPix.CHILL if tk < 0.5 else MiniPix.COLD)
		var x := MiniPix.jr(p.x)
		var y := MiniPix.jr(p.y)
		if k < 0.4:
			for j in range(-1, 2):
				for i in range(-1, 2):
					if absi(i) + absi(j) > 1 and bt(x + i, y + j) > 0.5 - k:
						continue
					px.dot(x + i, y + j, SMOKE_HI if i + j < 0 else MiniPix.ICE)
		elif k < 0.7:
			px.dot(x, y, MiniPix.ICE)
			if bt(x + 1, y) < 0.7 - k:
				px.dot(x + 1, y, MiniPix.CHILL)
		elif bt(x, y) < 1.3 - k:
			px.dot(x, y, MiniPix.CHILL)


## The control strip: SMOKE and PATCH (the patches left), AIR, the status.
func _draw_strip() -> void:
	px.rect(0, VH, PW, HUD, MiniPix.PANEL)
	px.rect(0, VH, PW, 1, MiniPix.BEVEL_HI)
	px.rect(0, VH + 1, PW, 1, MiniPix.BEVEL_LO)
	for b in BUTTONS:
		var on: bool = mode == b.id
		var bx: int = b.x
		var bw: int = b.w
		px.rect(bx, BY, bw, BHT, M[0])
		px.rect(bx + 1, BY + 1, bw - 2, BHT - 2, BTN_ON if on else M[4])
		px.rect(bx + 1, BY + 1, bw - 2, 1, MiniPix.EMBER if on else M[6])
		px.rect(bx + 1, BY + 1, 1, BHT - 2, MiniPix.EMBER if on else M[6])
		px.rect(bx + 1, BY + BHT - 2, bw - 2, 1, BTN_ON_DK if on else M[2])
		px.rect(bx + bw - 2, BY + 1, 1, BHT - 2, BTN_ON_DK if on else M[2])
		var ox := bx + bw / 2
		var oy := BY + 8
		if b.id == "smoke":
			for c: Vector3i in [Vector3i(-5, 1, 3), Vector3i(0, -1, 4), Vector3i(5, 1, 3), Vector3i(2, 2, 3)]:
				for yy in range(-c.z, c.z + 1):
					for xx in range(-c.z, c.z + 1):
						if xx * xx + yy * yy > c.z * c.z:
							continue
						px.dot(ox + c.x + xx, oy + c.y + yy, MiniPix.ICE if xx + yy < -1 else MiniPix.CHILL)
			for k in 4:
				px.dot(ox - 10 + k, oy + 4 - k % 2, M[6])
		else:
			var nn := int(P.patches) - int(S.used)
			var x0 := ox - 12
			var y0 := oy - 5
			for j in 10:
				for i in 10:
					var e := i == 0 or j == 0 or i == 9 or j == 9
					px.dot(x0 + i, y0 + j, (M[7] if i == 0 or j == 0 else M[0]) if e else M[5])
			for q: Vector2i in [Vector2i(2, 2), Vector2i(7, 2), Vector2i(2, 7), Vector2i(7, 7)]:
				px.dot(x0 + q.x, y0 + q.y, M[8])
			for i in nn:
				px.rect(ox + 2 + i * 4, oy - 2, 3, 5, MiniPix.HOT if on else MiniPix.FLARE)
	px.text("AIR", 97, VH + 5, MiniPix.CHILL)
	var aw := 36
	px.rect(111, VH + 4, aw + 2, 7, MiniPix.BEVEL_LO)
	px.rect(112, VH + 5, aw, 5, MiniPix.LINE)
	var air: float = S.air
	var fw := MiniPix.jr(aw * air)
	for i in fw:
		px.dot(112 + i, VH + 5, AIR_LOW if air < 0.25 else MiniPix.ICE)
		for j in range(1, 5):
			px.dot(112 + i, VH + 5 + j, (AIR_LOW_DK if air < 0.25 else MiniPix.COLD) if j == 4 else (MiniPix.BAD if air < 0.25 else MiniPix.CHILL))
	if status_t > 0.0 or S.over:
		px.text(status, PW - 3, VH + 15, status_col, "right")
	else:
		px.text("PUFFS %d" % int(S.puffs), PW - 3, VH + 15, M[6], "right")


func _say(txt: String, c: Color, sec: float = 2.0) -> void:
	status = txt
	status_col = c
	status_t = sec


func _events() -> void:
	var evs: Array = S.events
	while not evs.is_empty():
		var ev: Dictionary = evs.pop_front()
		match String(ev.type):
			"sealed":
				sfx(&"seal")
				fx.append({x = ev.x, y = ev.y, age = 0.0, life = 0.6, ok = true})
				_say("SEALED" if S.won else "ONE SEALED", MiniPix.GOOD, 99.0 if S.won else 2.5)
			"wrong":
				fx.append({x = ev.x, y = ev.y, age = 0.0, life = 0.6, ok = false})
				_say("STILL LEAKING", MiniPix.BAD, 2.5)
			"won":
				end_t = S.t
				sfx(&"win")
			"fail":
				end_t = S.t
				_say("AIR GONE" if ev.why == "air" else "NO PATCHES", MiniPix.BAD, 99.0)


func _finish() -> void:
	if done_fired:
		return
	done_fired = true
	var nl := (P.leaks as Array).size()
	done(score_of(S, P), "Sealed with %d puffs, %d wrong, %d%% air left" % [int(S.puffs), int(S.wrong), MiniPix.jr(float(S.air) * 100.0)] if S.won \
		else "%d of %d sealed" % [int(S.sealed), nl])


func _step(dt: float) -> void:
	for p: Dictionary in S.parts:
		(p.trail as Array).append(Vector2(p.x, p.y))
		if (p.trail as Array).size() > 5:
			(p.trail as Array).pop_front()
	step(S, P, dt)
	_events()
	status_t -= dt
	var keep: Array = []
	for f: Dictionary in fx:
		f.age += dt
		if float(f.age) <= float(f.life):
			keep.append(f)
	fx = keep
	for j: Dictionary in junk:
		var v := field(P, j.x, j.y)
		j.vx += v.x * 0.05 * dt
		j.vy += v.y * 0.05 * dt
		var sp := Vector2(j.vx, j.vy).length()
		if sp > 2.5:
			j.vx *= 2.5 / sp
			j.vy *= 2.5 / sp
		j.x += float(j.vx) * dt
		j.y += float(j.vy) * dt
		j.ang += dt * 0.6
		if float(j.x) < 4 or float(j.x) > PW - 8:
			j.vx *= -1
			j.x = clampf(j.x, 4, PW - 8)
		if float(j.y) < 11 or float(j.y) > 72:
			j.vy *= -1
			j.y = clampf(j.y, 11, 72)
	if S.over and _finish_at < 0.0 and float(S.t) - end_t > 1.0:
		_finish_at = t + 0.1
	if _finish_at >= 0.0 and t >= _finish_at:
		_finish()


func _tick(dt: float) -> void:
	_step(minf(0.05, dt))
	_acc += dt
	if _acc >= 1.0 / 30.0:
		_acc = 0.0
		if drawing:
			_draw()


# ---------------------------------------------------------------- input

func down(_p: Vector2i) -> void:
	if S.over:
		return
	var x := pf.x
	var y := pf.y
	if y >= VH:
		for b in BUTTONS:
			if x >= int(b.x) and x < int(b.x) + int(b.w) and y >= BY - 1 and y <= BY + BHT:
				mode = b.id
		return
	if y < 5 or y >= 78:
		return
	if mode == "smoke":
		sfx(&"puff")
		puff(S, P, x, y)
	else:
		if int(S.used) >= int(P.patches):
			return
		patch(S, P, x, y)
		mode = "smoke"


func give_up() -> void:
	if done_fired:
		return
	S.over = true
	done_fired = true
	done(clampf(0.25 * float(S.sealed) / (P.leaks as Array).size(), 0.0, 1.0), "Gave up")
