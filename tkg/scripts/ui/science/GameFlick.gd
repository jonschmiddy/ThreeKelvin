class_name GameFlick
extends MiniGame

## FLICK (Jon's comet pick, Nov 22: comet H): the comet breaks up near the sun and its chunks drift
## down at the ship. Ice into the open bay is the haul; rock on the hull or in the bay spills ice.
## Grab a chunk, swing it on its spring, let go to throw. A port of `comet_h.js`, step for step.
## Why: docs/why/MiniGame.md#flick

const W := MiniKit.W
const H := MiniKit.H
const PY := MiniKit.PLAY_Y
const DT := 1.0 / 60.0
## The page reads `performance.now()`, whose zero is its own: the port's clock starts where
## `diff.py`'s page starts it, so the blinks and the held ring turn in step.
const NOW0 := 1.0
const RUN: Array[float] = [12.5, 11.5, 10.5, 10.0, 9.5]
const NS: Array[int] = [10, 12, 14, 16, 18]
const ROCKY: Array[float] = [0.3, 0.35, 0.4, 0.45, 0.5]
const SPDS: Array[float] = [19.0, 21.0, 23.0, 25.0, 27.0]
const BWS: Array[int] = [46, 42, 38, 34, 30]
const FULL: Array[float] = [0.85, 0.8, 0.78, 0.75, 0.72]
## The hull's top row, the ice a rock hit spills, the nucleus.
const HULL := 121
const LOSS := 2
const NCX := 75.0
const NCY := 22.0
const SLATE := Color("#4a5a70")
const DEEP := Color("#18212d")
const DIM_RED := Color("#5a2a22")
const TETHER := Color("#8a4a16")
const WELL := Color("#26364a")
const LIMB := Color("#5a4320")
const LIMB_LO := Color("#2a2216")
const WHITE := Color("#ffffff")

## The deal (`gen`): the chunks the comet will shed, the bay, the hold's size.
var P: Dictionary = {}
var T := 12.5
var BW := 46
var BX0 := 52
var BX1 := 98
var TARGET := 3
var plan: Array = []
## The run's own clock (the page's `t`), from the first press.
var rt := 0.0
var started := false
var over := false
var end_t := -1.0
var pi := 0
var ice := 0
var hits := 0
var uid := 0
var flash_bay := 0.0
var flash_hull := 0.0
var said_half := false
var said_miss := false
## The chunks in flight ({id, rock, big, r, x, y, vx, vy, ang, spin, ph, ph2, age}) and the one held.
var chunks: Array[Dictionary] = []
var held: Dictionary = {}
var ptr_x := -1.0
var ptr_y := -1.0
## Debris and sparkles, moved and aged a drawn frame at a time, as the page does in its draw.
var bits: Array[Array] = []
var sparks: Array[Array] = []
var _nz := 0
var _acc := 0.0
var _bg: Image
## The nucleus's cracks [x, y, dx] (their glow is timed), and the bay's fill pixels in fill order.
var _cracks: Array[Vector3i] = []
var _fill: Array[Array] = []


func id() -> StringName:
	return &"flick"


func hint() -> String:
	return "Ice in. Rocks out."


func controls() -> Array[String]:
	return ["drag"]


# ---------------------------------------------------------------- the deal

## The chunks the comet will shed, from the stream in the page's order: which are rock (shuffled, the
## first one ice), when each leaves, where it is aimed, how fast, how big.
static func gen(r: RandomNumberGenerator, d: int, s: int) -> Dictionary[String, Variant]:
	var tp := RUN[d - 1]
	var spawn_end := tp - 4.2
	var n := NS[d - 1]
	var spd := SPDS[d - 1] * (1.0 - 0.04 * s)
	var bw := BWS[d - 1] + 2 * s
	var bx0 := MiniPix.jr(75.0 - bw / 2.0)
	var bx1 := bx0 + bw
	var n_rock := MiniPix.jr(n * ROCKY[d - 1])
	var kinds: Array[bool] = []
	for i in n:
		kinds.append(i < n_rock)
	for i in range(n - 1, 0, -1):
		var j := int(floorf(r.randf() * (i + 1)))
		var k := kinds[i]
		kinds[i] = kinds[j]
		kinds[j] = k
	if kinds[0]:
		kinds[kinds.find(false)] = true
		kinds[0] = false
	var out_plan: Array = []
	for i in n:
		var at := 0.25 + (spawn_end - 0.25) * (float(i) / (n - 1)) + (r.randf() - 0.5) * 0.5 * (spawn_end / n)
		var rock := kinds[i]
		var big := not rock and r.randf() < 0.22
		var in_bay := r.randf() < (0.55 if rock else 0.45)
		var xi := 0.0
		if in_bay:
			xi = bx0 + 4 + r.randf() * (bw - 8)
		elif r.randf() < 0.5:
			xi = 6 + r.randf() * (bx0 - 12)
		else:
			xi = bx1 + 6 + r.randf() * (W - bx1 - 12)
		var sp := spd * (0.85 + 0.3 * r.randf())
		var rad := 0
		if rock:
			rad = 3 + int(floorf(r.randf() * 3))
		elif big:
			rad = 5
		else:
			rad = 3 + int(floorf(r.randf() * 2))
		var ph := r.randf() * 6.28
		var ph2 := r.randf() * 6.28
		var spin := (r.randf() - 0.5) * 4.0
		out_plan.append({at = maxf(0.2, at), rock = rock, big = big, xi = xi, sp = sp, rad = rad, ph = ph, ph2 = ph2, spin = spin})
	# the page's sort is stable: an insertion sort keeps equal times in their order
	for i in range(1, out_plan.size()):
		var j := i
		while j > 0 and float(out_plan[j - 1].at) > float(out_plan[j].at):
			var tmp: Dictionary = out_plan[j]
			out_plan[j] = out_plan[j - 1]
			out_plan[j - 1] = tmp
			j -= 1
	var total := 0
	for p: Dictionary in out_plan:
		total += 0 if p.rock else (2 if p.big else 1)
	var out: Dictionary[String, Variant] = {}
	out.assign({plan = out_plan, bw = bw, bx0 = bx0, bx1 = bx1, target = maxi(3, MiniPix.jr(total * FULL[d - 1]))})
	return out


# ---------------------------------------------------------------- the game

func _mount() -> void:
	px = MiniPix.new(W, H)
	P = gen(rng, depth, sensors)
	T = RUN[depth - 1]
	plan = P.plan
	BW = P.bw
	BX0 = P.bx0
	BX1 = P.bx1
	TARGET = P.target
	_nz = (seed ^ 0x3c5) & PageRand.M
	_draw_bg()
	_bake()
	if drawing:
		_render()


func _noise() -> float:
	_nz = PageRand.mb_next(_nz)
	return PageRand.mb_value(_nz)


static func mass(c: Dictionary) -> float:
	return (2.2 if c.rock else 1.0) * float(c.r) * float(c.r) / 9.0


func is_held(c: Dictionary) -> bool:
	return not held.is_empty() and c.id == held.id


func _spawn(p: Dictionary) -> void:
	var dx := float(p.xi) - NCX
	var dy := HULL - NCY
	var d := GameSling.hyp(dx, dy)
	var ux := dx / d
	var uy := dy / d
	uid += 1
	chunks.append({id = uid, rock = p.rock, big = p.big, r = int(p.rad), x = NCX + ux * 11.0, y = NCY + uy * 11.0, vx = ux * float(p.sp), vy = uy * float(p.sp),
		ang = 0.0, spin = float(p.spin), ph = float(p.ph), ph2 = float(p.ph2), age = 0.0})
	for i in 4:
		var vx := ux * 8.0 + (_noise() - 0.5) * 10.0
		var vy := uy * 8.0 + (_noise() - 0.5) * 10.0
		bits.append([NCX + ux * 11.0, NCY + uy * 11.0, vx, vy, 0.0, MiniPix.COLD])


func _burst(x: float, y: float, n: int, cols: Array[Color], sp: float) -> void:
	for i in n:
		var a := _noise() * 6.28
		var s := sp * (0.4 + _noise() * 0.8)
		bits.append([x, y, cos(a) * s, sin(a) * s - 6.0, 0.0, cols[i % cols.size()]])


func _hit(c: Dictionary, in_bay: bool) -> void:
	hits += 1
	var lost := mini(ice, LOSS)
	ice -= lost
	flash_hull = 0.5
	if in_bay:
		flash_bay = 0.5
	sfx(&"hit")
	say("ROCK IN THE HOLD" if in_bay else "HULL HIT", "bad")
	_burst(c.x, HULL - 1, 10, [MiniPix.BAD, MiniPix.COLD, DIM_RED], 20.0)
	for i in lost * 3:
		var a := -PI / 2.0 + (_noise() - 0.5) * 1.6
		var s := 20.0 + _noise() * 25.0
		bits.append([75.0 + (_noise() - 0.5) * BW * 0.6, float(HULL + 4), cos(a) * s, sin(a) * s, 0.0, MiniPix.ICE])


## The held chunk hangs off the pointer on a spring (heavier rock lags more); every chunk drifts.
func _move() -> void:
	for c in chunks:
		c.age += DT
		c.ang += float(c.spin) * DT
		if is_held(c):
			var k := 520.0 / mass(c)
			var dmp := 2.0 * 0.75 * sqrt(k)
			c.vx += ((ptr_x - float(c.x)) * k - float(c.vx) * dmp) * DT
			c.vy += ((ptr_y - float(c.y)) * k - float(c.vy) * dmp) * DT
			var sp := GameSling.hyp(c.vx, c.vy)
			if sp > 170.0:
				c.vx *= 170.0 / sp
				c.vy *= 170.0 / sp
			c.spin = float(c.vx) * 0.08
		c.x += float(c.vx) * DT
		c.y += float(c.vy) * DT


## Chunks knock each other; the held one counts five times heavier, so you can bat with it.
func _knocks() -> void:
	for i in chunks.size():
		for j in range(i + 1, chunks.size()):
			var a := chunks[i]
			var b := chunks[j]
			var dx := float(b.x) - float(a.x)
			var dy := float(b.y) - float(a.y)
			var d := GameSling.hyp(dx, dy)
			var m := float(a.r) + float(b.r) - 0.5
			if d >= m or d == 0.0:
				continue
			var nx := dx / d
			var ny := dy / d
			var ma := mass(a) * (5.0 if is_held(a) else 1.0)
			var mb := mass(b) * (5.0 if is_held(b) else 1.0)
			var ov := m - d
			a.x -= nx * ov * mb / (ma + mb)
			a.y -= ny * ov * mb / (ma + mb)
			b.x += nx * ov * ma / (ma + mb)
			b.y += ny * ov * ma / (ma + mb)
			var rv := (float(b.vx) - float(a.vx)) * nx + (float(b.vy) - float(a.vy)) * ny
			if rv >= 0.0:
				continue
			var jj := -1.8 * rv / (1.0 / ma + 1.0 / mb)
			a.vx -= jj / ma * nx
			a.vy -= jj / ma * ny
			b.vx += jj / mb * nx
			b.vy += jj / mb * ny
			if absf(rv) > 12.0:
				sfx(&"knock")


## A chunk at the hull: ice in the bay banks, ice beside it is lost, rock hits. Off the glass, gone.
func _landings() -> void:
	var i := chunks.size() - 1
	while i >= 0:
		var c := chunks[i]
		var bottom := float(c.y) + float(c.r)
		if (bottom >= HULL and float(c.vy) >= 0.0) or bottom >= HULL + 2:
			var in_bay := float(c.x) > BX0 + 1 and float(c.x) < BX1 - 1
			if c.rock:
				_hit(c, in_bay)
			elif in_bay:
				ice += 2 if c.big else 1
				flash_bay = 0.25
				sfx(&"bank")
				for k in 5:
					var sx := MiniPix.jr(float(c.x) + (_noise() - 0.5) * 6.0)
					sparks.append([sx, HULL - 1 - int(floorf(_noise() * 4.0)), 0.0])
			else:
				_burst(c.x, HULL - 1, 8, [MiniPix.ICE, MiniPix.CHILL, MiniPix.COLD], 12.0)
				sfx(&"miss")
				if not said_miss:
					said_miss = true
					say("ICE LOST", "neutral")
			if is_held(c):
				held = {}
			chunks.remove_at(i)
		elif float(c.x) < -10.0 or float(c.x) > W + 10 or float(c.y) < PY - 12 or float(c.y) > H + 10:
			if is_held(c):
				held = {}
			chunks.remove_at(i)
		i -= 1


func _sim() -> void:
	if not started or over:
		return
	rt += DT
	flash_bay = maxf(0.0, flash_bay - DT)
	flash_hull = maxf(0.0, flash_hull - DT)
	while pi < plan.size() and rt >= float(plan[pi].at):
		_spawn(plan[pi])
		pi += 1
	_move()
	_knocks()
	_landings()
	if ice >= TARGET / 2.0 and not said_half:
		said_half = true
		say("HALF FULL", "goal")
	if rt >= T or ice >= TARGET or (pi >= plan.size() and chunks.is_empty()):
		_end()


func score_now() -> float:
	return clampf(float(ice) / TARGET, 0.0, 1.0)


func _end() -> void:
	if over:
		return
	over = true
	end_t = rt
	held = {}
	var s := score_now()
	if s >= 0.5:
		sfx(&"win")
	say_end("HOLD FULL" if s >= 0.93 else ("GOOD HAUL" if s >= 0.5 else "THIN HAUL"), "good" if s >= 0.93 else "neutral")
	done(s, "%d of %d ice, %d rock hits" % [ice, TARGET, hits])


func _tick(dt: float) -> void:
	_acc += minf(0.1, dt)
	while _acc >= DT:
		_acc -= DT
		_sim()
	if drawing:
		_render()


# ---------------------------------------------------------------- drawing

## Stars, and the sun's glow in the top-left corner, drawn once.
func _draw_bg() -> void:
	_bg = Image.create(W, H, false, Image.FORMAT_RGBA8)
	_bg.fill(MiniPix.VOID)
	for y in range(PY, 70):
		for x in 60:
			var d := GameSling.hyp(x + 40.0, y + 10.0)
			if d < 50.0:
				_bg.set_pixel(x, y, MiniPix.WARN if MiniPix.lit(x, y, (50.0 - d) / 4.0) else LIMB)
			elif d < 58.0:
				_bg.set_pixel(x, y, LIMB if MiniPix.lit(x, y, (58.0 - d) / 8.0) else LIMB_LO)
			elif d < 68.0 and MiniPix.lit(x, y, (68.0 - d) / 10.0 * 0.6):
				_bg.set_pixel(x, y, LIMB_LO)
	var sr := (seed ^ 0x9e37) & PageRand.M
	for i in 55:
		sr = PageRand.mb_next(sr)
		var x := int(floorf(PageRand.mb_value(sr) * W))
		sr = PageRand.mb_next(sr)
		var y := PY + int(floorf(PageRand.mb_value(sr) * (HULL - PY)))
		if GameSling.hyp(x + 40.0, y + 10.0) < 62.0:
			continue
		sr = PageRand.mb_next(sr)
		_bg.set_pixel(x, y, MiniPix.COLD if PageRand.mb_value(sr) < 0.2 else MiniPix.LINE)


## What never changes, drawn onto the background once: the coma and the nucleus (its cracks kept
## apart, they glow on a clock), and the order the bay's banked ice fills its pixels in.
func _bake() -> void:
	for y in range(PY, 52):
		for x in range(40, 110):
			var d := GameSling.hyp(x - NCX, y - NCY)
			if d < 30.0 and MiniPix.lit(x, y, (30.0 - d) / 30.0 * 0.35):
				_bg.set_pixel(x, y, MiniPix.LINE)
	for y in range(-15, 16):
		for x in range(-15, 16):
			var xx := int(NCX) + x
			var yy := int(NCY) + y
			if yy < PY:
				continue
			var a := atan2(y, x)
			var d := GameSling.hyp(x, y)
			var e := 12.0 + 1.6 * sin(3.0 * a + 1.1) + 1.1 * sin(5.0 * a + 0.4) + (-0.8 if a > 0.3 and a < 2.8 else 0.0)
			if d > e + 1.0:
				continue
			if d > e:
				_bg.set_pixel(xx, yy, MiniPix.BEVEL_LO)
				continue
			var l := (-x - y) / 16.0
			var col := SLATE if l > 0.45 else (MiniPix.BEVEL_HI if l > 0.0 else (MiniPix.LINE if l > -0.45 else DEEP))
			if PageRand.hash(x + 50, y + 50) < 0.1:
				col = MiniPix.LINE
			if absf(sin(x * 0.7 + y * 1.3) * 7.0 + sin(x * 0.3 - y * 0.9) * 5.0) < 1.1 and d < e - 1.0:
				_cracks.append(Vector3i(xx, yy, x))
			_bg.set_pixel(xx, yy, col)
	var k := 0
	var rows := (H - HULL - 3) * (BW - 1)
	var y := H - 2
	while y > HULL + 1 and k < rows:
		var x := BX0 + 1
		while x < BX1 and k < rows:
			var c := MiniPix.ICE if PageRand.hash(x, y) < 0.2 else (MiniPix.CHILL if PageRand.hash(x + 3, y) < 0.5 else MiniPix.COLD)
			_fill.append([x, y, c])
			x += 1
			k += 1
		y -= 1


func _chunk(c: Dictionary, n: float) -> void:
	var rad := int(c.r)
	var big_r := rad + 1
	var cx := MiniPix.jr(c.x)
	var cy := MiniPix.jr(c.y)
	var rock: bool = c.rock
	var ang := float(c.ang)
	var ca := cos(ang)
	var sa := sin(ang)
	for y in range(-big_r - 1, big_r + 2):
		for x in range(-big_r - 1, big_r + 2):
			var d := GameSling.hyp(x, y)
			var a := atan2(y, x)
			var e := rad * (1.0 + 0.16 * sin(3.0 * (a - ang) + float(c.ph)) + 0.09 * sin(5.0 * (a - ang) + float(c.ph2)))
			if d > e + 1.0:
				continue
			var xx := cx + x
			var yy := cy + y
			if yy < PY or yy >= H:
				continue
			if d > e:
				px.dot(xx, yy, MiniPix.BAD if rock else MiniPix.BEVEL_LO)
				continue
			var l := (-x - y) / (rad * 1.4)
			var tex := PageRand.hash(MiniPix.jr(x * ca + y * sa) + int(c.id) * 7, MiniPix.jr(-x * sa + y * ca))
			var col: Color
			if rock:
				col = SLATE if l > 0.45 else ((MiniPix.LINE if tex < 0.2 else MiniPix.BEVEL_HI) if l > -0.1 else (MiniPix.LINE if l > -0.6 else DEEP))
				if d > e - 1.0 and l < -0.2:
					col = DIM_RED
			else:
				col = (MiniPix.CHILL if tex < 0.15 else WHITE) if l > 0.5 else ((MiniPix.CHILL if tex < 0.2 else MiniPix.ICE) if l > 0.05 else (MiniPix.CHILL if l > -0.5 else MiniPix.COLD))
			px.dot(xx, yy, col)
	if is_held(c):
		var rr2 := rad + 3.0
		var n2 := MiniPix.jr(rr2 * 4.0)
		for k in range(0, n2, 2):
			var a := float(k) / n2 * 6.283 + n * 3.0
			px.dot(MiniPix.jr(float(c.x) + cos(a) * rr2), MiniPix.jr(float(c.y) + sin(a) * rr2), MiniPix.EMBER)


## The ship: hull plates across the bottom, running lights, the open bay (blue) with the ice banked in it.
func _ship(n: float) -> void:
	var hull_c := MiniPix.BAD if flash_hull > 0.0 and int(floorf(n * 12.0)) % 2 == 0 else MiniPix.BEVEL_HI
	px.rect(0, HULL, W, H - HULL, MiniPix.BEVEL_LO)
	px.rect(0, HULL + 1, BX0 - 1, H - HULL - 1, MiniPix.LINE)
	px.rect(BX1 + 2, HULL + 1, W - BX1 - 2, H - HULL - 1, MiniPix.LINE)
	px.rect(0, HULL, BX0 - 1, 1, hull_c)
	px.rect(BX1 + 2, HULL, W - BX1 - 2, 1, hull_c)
	for x in range(8, W, 16):
		if x > BX0 - 3 and x < BX1 + 3:
			continue
		px.rect(x, HULL + 2, 1, H - HULL - 2, DEEP)
	px.rect(0, HULL + 9, BX0 - 1, 1, DEEP)
	px.rect(BX1 + 2, HULL + 9, W - BX1 - 2, 1, DEEP)
	var lamp := MiniPix.FLARE if int(floorf(n * 2.0)) % 2 == 0 else MiniPix.EMBER
	px.rect(4, HULL + 4, 2, 2, lamp)
	px.rect(W - 6, HULL + 4, 2, 2, lamp)
	px.rect(BX0, HULL, BW + 1, H - HULL, MiniPix.VOID)
	var rim := MiniKit.T2
	if flash_bay > 0.0 and int(floorf(n * 12.0)) % 2 == 0:
		rim = MiniPix.BAD if hits > 0 and flash_hull > 0.0 else MiniPix.ICE
	px.rect(BX0 - 1, HULL - 2, 1, H - HULL + 2, rim)
	px.rect(BX1 + 1, HULL - 2, 1, H - HULL + 2, rim)
	px.rect(BX0 - 3, HULL - 2, 3, 1, rim)
	px.rect(BX1 + 1, HULL - 2, 3, 1, rim)
	for x in range(BX0, BX1 + 1):
		if MiniPix.lit(x, HULL, 0.5):
			px.dot(x, HULL, WELL)
	var rows := MiniPix.jr(minf(1.0, float(ice) / TARGET) * (H - HULL - 3) * (BW - 1))
	for k in mini(rows, _fill.size()):
		px.dot(_fill[k][0], _fill[k][1], _fill[k][2])


## Red marks where rocks will hit, and with sensors 2+ their paths.
func _warnings(n: float) -> void:
	if not started or over:
		return
	for c in chunks:
		if not c.rock or is_held(c) or float(c.vy) <= 1.0:
			continue
		var tt := (HULL - float(c.r) - float(c.y)) / float(c.vy)
		if tt > 2.2:
			continue
		var xh := float(c.x) + float(c.vx) * tt
		if xh < 0.0 or xh >= W:
			continue
		if sensors >= 2:
			var k := 4
			while k < tt * 60.0:
				var s := k / 60.0
				var y := MiniPix.jr(float(c.y) + float(c.vy) * s)
				if y >= PY and y < HULL:
					px.dot(MiniPix.jr(float(c.x) + float(c.vx) * s), y, DIM_RED)
				k += 6
		if int(floorf(n * 8.0)) % 2 == 0:
			var x := MiniPix.jr(xh)
			px.rect(x - 2, HULL - 1, 5, 1, MiniPix.BAD)
			px.rect(x, HULL - 3, 1, 2, MiniPix.BAD)


func _debris() -> void:
	var i := bits.size() - 1
	while i >= 0:
		var b: Array = bits[i]
		b[4] = float(b[4]) + 1.0 / 60.0
		b[0] = float(b[0]) + float(b[2]) / 60.0
		b[1] = float(b[1]) + float(b[3]) / 60.0
		if float(b[4]) > 0.7:
			bits.remove_at(i)
		else:
			var y := MiniPix.jr(b[1])
			if y >= PY and y < H:
				px.dot(MiniPix.jr(b[0]), y, MiniPix.COLD if float(b[4]) > 0.45 else b[5])
		i -= 1
	i = sparks.size() - 1
	while i >= 0:
		var s: Array = sparks[i]
		s[2] = float(s[2]) + 1.0 / 60.0
		var age := float(s[2])
		if age > 0.3:
			sparks.remove_at(i)
		else:
			var a := 1 if age < 0.1 else (2 if age < 0.2 else 3)
			var c := WHITE if a == 1 else (MiniPix.ICE if a == 2 else MiniPix.CHILL)
			var x: int = s[0]
			var y: int = s[1]
			px.dot(x, y, c)
			if a < 3:
				px.dot(x - a, y, c)
				px.dot(x + a, y, c)
				px.dot(x, y - a, c)
		i -= 1


func _render() -> void:
	var n := t + NOW0
	px.img.blit_rect(_bg, Rect2i(0, 0, W, H), Vector2i.ZERO)
	for q in _cracks:
		px.dot(q.x, q.y, MiniPix.FLARE if int(floorf(n * 3.0 + q.z)) % 5 == 0 else MiniPix.EMBER)
	_ship(n)
	_warnings(n)
	for c in chunks:
		_chunk(c, n)
	if not held.is_empty():
		var dx := ptr_x - float(held.x)
		var dy := ptr_y - float(held.y)
		var st := int(floorf(GameSling.hyp(dx, dy) / 2.0))
		for i in range(1, st):
			px.dot(MiniPix.jr(float(held.x) + dx * i / st), MiniPix.jr(float(held.y) + dy * i / st), TETHER)
	_debris()
	var left := maxf(0.0, T - (end_t if over and end_t >= 0.0 else rt))
	var f := float(ice) / TARGET
	MiniKit.header(px, {label = "ICE", meter = {w = 57, frac = f, kind = "goal"}, value = "%d%%" % MiniPix.jr(minf(1.0, f) * 100.0)},
		[["TIME", ceili(left if started else T)]])
	if not told:
		MiniKit.tell(px, "ICE IN. ROCKS OUT.", ["drag"] as Array[String], t)
	draw_toast()
	dirty = true


# ---------------------------------------------------------------- input

func move(q: Vector2i) -> void:
	ptr_x = q.x
	ptr_y = q.y


## A press starts the run and grabs the nearest chunk within reach.
func down(q: Vector2i) -> void:
	if over:
		return
	move(q)
	started = true
	var best := {}
	var bd := 1e9
	for c in chunks:
		var d := GameSling.hyp(float(c.x) - ptr_x, float(c.y) - ptr_y)
		if d < float(c.r) + 5.0 and d < bd:
			bd = d
			best = c
	if not best.is_empty():
		held = best
		sfx(&"grab")


## Letting go throws: the chunk keeps its speed.
func up(_q: Vector2i, _cancel := false) -> void:
	if not held.is_empty() and GameSling.hyp(held.vx, held.vy) > 40.0:
		sfx(&"throw")
	held = {}


func give_up() -> void:
	if over or is_done():
		return
	over = true
	held = {}
	done(0.3 * score_now(), "Gave up at %d of %d ice" % [ice, TARGET])
