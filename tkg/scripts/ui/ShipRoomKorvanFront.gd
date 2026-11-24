class_name ShipRoomKorvanFront
extends RefCounted

## Korvan's film in front of the hulls (mix18.render's after_hulls() and front()): the bead on the
## heavy's belly, the bench grinder, the lift and its welder, the lamp tech, the arc and its sparks,
## the ladder jobs, the parts delivery and the forklift. Why: docs/why/ShipRoomKorvan.md#life

const F := preload("res://scripts/ui/ShipRoomKorvanFilm.gd")
const P := preload("res://scripts/ui/ShipRoomKorvanPaint.gd")
const INK := Color(14 / 255.0, 16 / 255.0, 20 / 255.0)
const SKIN := Color(236 / 255.0, 160 / 255.0, 112 / 255.0)
const LANE := 388
const WFLOOR := 374
const FORE_X := 218
const DESK_X := 199
const LEG_P := 104
const CRATE_ROW := 378
const DECK_BOT := 381

var life: ShipRoomKorvanLife
var p: Dictionary[StringName, ShipRoomKorvanPaint] = {}
var _courier: ShipRoomKorvanLife.Walker


func _init(l: ShipRoomKorvanLife) -> void:
	life = l
	_courier = ShipRoomKorvanLife.Walker.new("look_suit", [["in", -60, LANE, 0.5], ["walk", 150, LANE], ["stand", 5.0],
		["walk", 132, LANE], ["stand", 3.3], ["walk", -60, LANE], ["out"]], 22.0)


func _mk(n: StringName, b: ShipRoomKorvanPaint.Blend = ShipRoomKorvanPaint.Blend.LIT) -> ShipRoomKorvanPaint:
	var q := life.paint(b)
	p[n] = q
	return q


func build() -> void:
	_mk(&"bead")
	_mk(&"bench_sh", P.Blend.MUL)
	_mk(&"bench").light(0)
	_mk(&"bench_sparks")
	_mk(&"lift").light(0)
	_mk(&"welder").light(0)
	_mk(&"worklamp")
	_mk(&"tech_sh", P.Blend.MUL)
	_mk(&"tech").light(0, Vector2.ZERO, 0.3)
	_mk(&"tech_arm").light(0, Vector2.ZERO, 0.45)
	_mk(&"tech_beam", P.Blend.ADD)
	_mk(&"tech_lens")
	_mk(&"arc_glow", P.Blend.ADD)
	_mk(&"arc")
	_mk(&"sparks")
	_mk(&"flamp_sh", P.Blend.MUL)
	_mk(&"flamp")
	_mk(&"flamp_beam", P.Blend.ADD)
	for i in 2:
		_mk(StringName("w%d_sh" % i), P.Blend.MUL)
		_mk(StringName("w%d_bink" % i))
		_mk(StringName("w%d_bk" % i))
		_mk(StringName("w%d_bkt" % i))
		_mk(StringName("w%d_man" % i)).light(0, Vector2.ZERO, 0.1 if i == 1 else 0.0)
		_mk(StringName("w%d_fink" % i))
		_mk(StringName("w%d_fkt" % i))
		_mk(StringName("w%d_tool_ink" % i))
		_mk(StringName("w%d_tool_k" % i))
		_mk(StringName("w%d_tool_hot" % i))
		_mk(StringName("w%d_glow" % i), P.Blend.ADD)
		_mk(StringName("w%d_arc" % i))
		_mk(StringName("w%d_sparks" % i))
	_build_delivery()
	_mk(&"fork_sh", P.Blend.MUL)
	_mk(&"fork")
	_mk(&"fork_crate")
	_mk(&"fork_lamp")


func _build_delivery() -> void:
	_mk(&"desk_sh", P.Blend.MUL)
	_mk(&"desk_k")
	_mk(&"desk_ink")
	for i in 2:
		_mk(StringName("leg_sh%d" % i), P.Blend.MUL)
		_mk(StringName("leg%d" % i))
	_mk(&"cart_sh", P.Blend.MUL)
	_mk(&"cart")
	for i in 2:
		_mk(StringName("deck%d" % i))
	_mk(&"courier_sh", P.Blend.MUL)
	_mk(&"courier")
	for i in 2:
		_mk(StringName("held%d" % i))
	_mk(&"courier_k")
	_mk(&"fore_sh", P.Blend.MUL)
	_mk(&"fore")
	_mk(&"fore_k")
	_mk(&"fore_ink")


func draw(f: int, t: float) -> void:
	var fr: Dictionary = (F.D["frames"] as Array)[f]
	var tA := fposmod(t, 10.0)
	_bead(tA)
	_bench(t)
	var wp := F.weld_pose(tA)
	_lift(wp.x)
	_lamp_tech(t)
	var lvl := float(fr["arcA"]) if wp.y == 1 else 0.0
	if lvl > 0.0:
		var tip := F.arc_tip(wp.x)
		_star(p[&"arc_glow"], p[&"arc"], tip, lvl, ((F.D["tenths"] as Array)[int(floorf(tA * 10.0))] as Dictionary)["arc"], false)
	_arc_sparks(tA)
	_floor_lamp()
	for i in 2:
		_ladder(i, t, fr)
	_delivery(t)
	_forklift(t)


# ------------------------------------------------------------------ the bead cooling on the heavy's belly
func _bead(tA: float) -> void:
	var bead := 0.0
	for r: Vector2 in F.A_RUNS:
		var age := fposmod(tA - r.y, 10.0)
		if age < 2.0:
			bead = maxf(bead, 1.0 - age / 2.0)
		if tA >= r.x and tA < r.y:
			bead = 1.0
	if bead <= 0.0:
		return
	var tip := int(F.K["tip_x"])
	var und: Array = F.K["under_h"]
	for i in 8:
		var dx := i - 7
		var k := bead * (0.55 + 0.45 * (i / 7.0))
		var c := P.c8(255, 230, 150) * k + P.c8(190, 60, 20) * (1.0 - k)
		p[&"bead"].px(tip + dx, int(und[tip + dx]), Color(c.r, c.g, c.b, k))


# ------------------------------------------------------------------ the bench grinder on the mid floor (ideaC)
func _bench(t: float) -> void:
	var bx := int(F.K["bx"])
	var bf := int(F.K["bfeet"])
	var grinding := F.in_any(t, F.GRIND)
	p[&"bench_sh"].contact(bx - 18, bx + 16, bf, 3, 0.5)
	life.strip(p[&"bench"], "grind_strip", int(t * 10.0) % 9 if grinding else 0, bx - 24, bf - 28)
	var g := Vector2(float(F.K["g_ox"]), float(F.K["g_oy"]))
	for s: Array in F.D["spawn"]["bench"]:
		var age := fposmod(t - float(s[0]), 30.0)
		if age > float(s[3]):
			continue
		var x := g.x + float(s[1]) * age
		var y := minf(bf, g.y + float(s[2]) * age + 110.0 * age * age)
		var a := age / float(s[3])
		var c := P.c8(255, 246, 216) if a < 0.3 else (P.c8(255, 179, 71) if a < 0.7 else P.c8(192, 80, 26))
		p[&"bench_sparks"].px(F.pyround(x), F.pyround(y), c)


# ------------------------------------------------------------------ the lift under the heavy and its welder (ideaA)
func _lift(wf: int) -> void:
	var K := F.K
	life.piece(p[&"lift"], "lift", int(K["lift_x0"]), int(K["lift_y0"]))
	var wx0 := int(floorf(float(K["wx"]) - float(K["wcx"]) + 0.5))
	life.strip(p[&"welder"], "welder_strip", wf, wx0, int(K["wb"]) - int(K["wfoot"]))
	var wl := Vector2i(int(K["wlx"]), int(K["wly"]))
	p[&"worklamp"].rect(wl.x - 1, wl.y - 2, 3, 2, P.c8(40, 40, 44))
	p[&"worklamp"].rect(wl.x - 1, wl.y - 3, 3, 1, P.c8(255, 226, 170))


# ------------------------------------------------------------------ the lamp tech under the medium (mix18.tech_pose)
func _lamp_tech(t: float) -> void:
	var K := F.K
	var spot := F.lamp_spot(t)
	var aim := F.tech_aim(spot)
	var flip := spot > int(K["tech_x"]) + 1
	var tx := int(K["tech_x"])
	p[&"tech_sh"].contact(tx - 9, tx + 9, int(K["tech_feet"]), 3, 0.45)
	life.piece(p[&"tech"], "tech_cut", int(K["tbx0"]), int(K["tby0"]), flip)
	var arm := p[&"tech_arm"]
	var ux := aim.x
	var uy := aim.y
	var s0 := Vector2(aim.z, aim.w)
	var pts: Array[Vector2i] = []
	var s := 1.0
	while s < 10.5:
		pts.append(Vector2i(F.pyround(s0.x + ux * s), F.pyround(s0.y + uy * s)))
		s += 0.5
	for q in pts:
		arm.rect(q.x - 1, q.y - 1, 3, 3, P.c8(12, 14, 20))
	for q in pts:
		arm.px(q.x, q.y, P.c8(61, 128, 182))
		arm.px(q.x, q.y + 1, P.c8(28, 66, 108))
	var h := Vector2i(F.pyround(s0.x + ux * 10.5), F.pyround(s0.y + uy * 10.5))
	arm.rect(h.x, h.y, 1, 2, SKIN)
	s = 11.5
	while s < 14.5:
		arm.px(F.pyround(s0.x + ux * s), F.pyround(s0.y + uy * s), P.c8(44, 46, 52))
		s += 0.5
	var lens := F.lens_at(spot)
	var by := int((K["under_m"] as Array)[spot]) - 1
	var n := maxi(1, lens.y - by)
	var beam := p[&"tech_beam"]
	for i in n:
		var u := float(i) / n
		var y := lens.y - i
		var cxb := lens.x + (spot - lens.x) * u
		var hw := 0.5 + 5.0 * u
		for x in range(int(cxb - hw - 1), int(cxb + hw + 2)):
			var dd := absf(x - cxb) / hw
			var k := 0.0
			if dd < 0.45:
				k = 0.34
			elif dd < 1.0 and ShipRoom.bayer4(x, y) < 0.5:
				k = 0.17
			if k > 0.0:
				beam.px(x, y, P.c8(255 * k * (1.0 - 0.35 * u), 214 * k * (1.0 - 0.35 * u), 150 * k * (1.0 - 0.35 * u)))
	p[&"tech_lens"].px(lens.x, lens.y, P.c8(255, 246, 214))
	_glow(beam, lens, 3, 1.4, 0.9, Color(120 / 255.0, 100 / 255.0, 70 / 255.0))


## core.glow_local(r, fall) x s, stepped on the frame's grid and added in colour c.
static func _glow(q: ShipRoomKorvanPaint, c0: Vector2i, r: int, fall: float, s: float, c: Color) -> void:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var g := pow(maxf(1.0 - Vector2(dx, dy).length() / r, 0.0), fall) * s
			var v := clampf(g, 0.0, 2.5) * 6.0
			var lo := floorf(v)
			var fr := v - lo
			if fr > 0.75 and ShipRoom.bayer4(c0.x + dx, c0.y + dy) < (fr - 0.75) * 4.0:
				lo += 1.0
			if lo > 0.0:
				q.px(c0.x + dx, c0.y + dy, Color(c.r * lo / 6.0, c.g * lo / 6.0, c.b * lo / 6.0))


## An arc drawn as light: a stepped blue-white glow and its ragged pixels. yx: the pairs are (dy, dx).
func _star(glow: ShipRoomKorvanPaint, q: ShipRoomKorvanPaint, a: Vector2i, lvl: float, pix: Array, yx: bool) -> void:
	_glow(glow, a, 5, 1.2, lvl * 1.4, Color(150 / 255.0, 190 / 255.0, 1.0))
	for d: Array in pix:
		var o := Vector2i(int(d[1]), int(d[0])) if yx else Vector2i(int(d[0]), int(d[1]))
		q.px(a.x + o.x, a.y + o.y, P.c8(225, 240, 255))
	q.px(a.x, a.y, Color.WHITE)


static func spark_col(a: float) -> Color:
	if a < 0.15:
		return Color.WHITE
	if a < 0.4:
		return P.c8(255, 233, 168)
	if a < 0.7:
		return P.c8(255, 179, 71)
	return P.c8(192, 80, 26)


## A spark thrown from `from` at (vx, vy), stepped at 120 Hz with its bounces: [x, y, px, py].
static func _fly(from: Vector2, vx: float, vy: float, age: float, deck: Callable) -> PackedFloat32Array:
	var x := from.x
	var y := from.y
	var prev := Vector2(x, y)
	var dt := 1.0 / 120.0
	for i in int(age / dt):
		prev = Vector2(x, y)
		vy += 260.0 * dt
		x += vx * dt
		y += vy * dt
		var stop: float = deck.call(x, y)
		if y >= stop and vy > 0.0:
			y = stop
			vy *= -0.32
			vx *= 0.55
	return PackedFloat32Array([x, y, prev.x, prev.y])


func _arc_sparks(tA: float) -> void:
	var K := F.K
	var lx0 := float(K["lift_x0"])
	var lw := float(K["lift_w"])
	var wb := float(K["wb"])
	var ly := float(K["ly"])
	var deck := func(x: float, y: float) -> float:
		return wb if x >= lx0 and x <= lx0 + lw - 1.0 and y < wb + 2.0 else ly + 1.0
	var from := Vector2(float(K["tip_x"]), float(K["belly"]) + 2.0)
	for s: Array in F.D["spawn"]["arc"]:
		var age := fposmod(tA - float(s[0]), 10.0)
		if age > float(s[3]):
			continue
		var v := _fly(from, float(s[1]), float(s[2]), age, deck)
		var a := age / float(s[3])
		_spark(p[&"sparks"], v, spark_col(a), a < 0.7, 0.6)


func _spark(q: ShipRoomKorvanPaint, v: PackedFloat32Array, c: Color, tail: bool, k: float) -> void:
	var xi := F.pyround(v[0])
	var yi := F.pyround(v[1])
	if xi < 0 or yi < 0 or xi >= 960 or yi >= 540:
		return
	q.px(xi, yi, c)
	var pxi := F.pyround(v[2])
	var pyi := F.pyround(v[3])
	if tail and (pxi != xi or pyi != yi):
		q.px(pxi, pyi, Color(c.r, c.g, c.b, k))


# ------------------------------------------------------------------ the floor lamp under the light hull, aimed up at its belly
func _floor_lamp() -> void:
	var fx := F.FL_X
	var ff := 372
	p[&"flamp_sh"].contact(fx - 8, fx + 8, ff, 3, 0.45)
	var q := p[&"flamp"]
	for dx: int in [-5, 0, 5]:
		for i in 6:
			q.px(fx + int(dx * (1.0 - i / 6.0)), ff - i, P.c8(30, 32, 38))
	q.rect(fx, ff - 22, 1, 17, P.c8(54, 58, 66))
	q.rect(fx - 3, ff - 26, 7, 4, P.c8(40, 42, 48))
	q.rect(fx - 2, ff - 27, 5, 1, P.c8(255, 236, 190))
	var top := int(F.K["fl_top"])
	var b := p[&"flamp_beam"]
	for y in range(top, ff - 27):
		var u := float(ff - 27 - y) / maxf(1.0, ff - 27 - top)
		var hw := 1.0 + 5.0 * u
		for x in range(int(fx - hw), int(fx + hw) + 1):
			var k := 0.22 if absf(x - fx) < hw * 0.5 else (0.11 if ShipRoom.bayer4(x, y) < 0.5 else 0.0)
			if k > 0.0:
				b.px(x, y, P.c8(255 * k * (1.0 - 0.3 * u), 220 * k * (1.0 - 0.3 * u), 160 * k * (1.0 - 0.3 * u)))


# ------------------------------------------------------------------ the ladder jobs: a welder at the light, a grinder at the medium (people8 W)
func _ladder(i: int, t: float, fr: Dictionary) -> void:
	var sp: Dictionary = (F.K["weld8"] as Array)[i]
	var st := F.weld_state(sp, t)
	var on := st.y > 0.5
	var tip := Vector2i(int(sp["tip"][0]), int(sp["tip"][1]))
	var x0 := int(sp["x0"])
	var y0 := int(sp["y0"])
	var grind: bool = sp["kind"] == "grind"
	if grind:
		p[StringName("w%d_sh" % i)].contact(int(sp["LX"]) - 15, int(sp["LX"]) + 15, WFLOOR, 3, 0.5)
	else:
		p[StringName("w%d_sh" % i)].contact(int(sp["tw"][0]) - 3, int(sp["tw"][1]) + 3, WFLOOR, 3, 0.5)
	_platform(i, sp, true)
	if grind:
		life.piece(p[StringName("w%d_man" % i)], "tech_tg", x0, y0)
	else:
		life.strip(p[StringName("w%d_man" % i)], "welder_strip", int(st.x), x0, y0)
	_platform(i, sp, false)
	if grind:
		_grinder(i, sp, on, int(fr["jit"]) if on else 0, t)
		return
	var lvl := float((fr["arc8"] as Array)[i]) if on else 0.0
	var arc := p[StringName("w%d_arc" % i)]
	for j in 6:
		var k := 0.0
		if on:
			var done := float(j) / 6.0 <= st.z
			k = (1.0 if absf(float(j) / 6.0 - st.z) < 0.2 else 0.6) if done else 0.0
		else:
			k = maxf(0.0, 1.0 - st.w / 2.2) * 0.85
		if k > 0.0:
			var c := P.c8(255, 230, 150) * k + P.c8(190, 60, 20) * (1.0 - k)
			arc.px(tip.x + 1, tip.y - 4 + j, Color(c.r, c.g, c.b, k))
	if lvl > 0.0:
		var tn: Dictionary = (F.D["tenths"] as Array)[int(floorf(t * 10.0)) % 300]
		_star(p[StringName("w%d_glow" % i)], arc, tip, lvl, (tn["w8"] as Array)[i], true)
	_ladder_sparks(i, sp, t, false)


func _ladder_sparks(i: int, sp: Dictionary, t: float, grind: bool) -> void:
	var from := Vector2(float(sp["tip"][0]), float(sp["tip"][1]))
	var deck := func(_x: float, _y: float) -> float:
		return WFLOOR + 1.0
	for s: Array in (F.D["spawn"]["w8"] as Array)[i]:
		var age := fposmod(t - float(s[0]), 30.0)
		if age > float(s[3]):
			continue
		var v := _fly(from, float(s[1]), float(s[2]), age, deck)
		var a := age / float(s[3])
		if grind:
			var c := P.c8(255, 214, 120) if a < 0.3 else (P.c8(255, 150, 50) if a < 0.7 else P.c8(190, 74, 24))
			_spark(p[StringName("w%d_sparks" % i)], v, c, true, 0.65)
		else:
			_spark(p[StringName("w%d_sparks" % i)], v, spark_col(a), a < 0.7, 0.6)


## people8.platform: the A-frame platform ladder, its rail and legs behind him, its toe board in front.
func _platform(i: int, sp: Dictionary, back: bool) -> void:
	var X := int(sp["LX"])
	var deck := int(sp["F"]) + 1
	var ink := P.c8(14, 16, 20)
	var yel := P.c8(168, 140, 62)
	var yd := P.c8(104, 84, 36)
	var dw := 9
	var fw := 14
	if not back:
		var fi := p[StringName("w%d_fink" % i)]
		var fk := p[StringName("w%d_fkt" % i)]
		fk.light(2, Vector2(X, deck), 0.3, 0.35, 1.3)
		fi.rect(X - dw - 1, deck - 2, 2 * dw + 3, 2, ink)
		fk.rect(X - dw, deck - 2, 2 * dw + 1, 1, yel)
		fk.rect(X - dw, deck - 1, 2 * dw + 1, 1, yd)
		return
	var bi := p[StringName("w%d_bink" % i)]
	var bk := p[StringName("w%d_bk" % i)]
	var bt := p[StringName("w%d_bkt" % i)]
	bk.light(2, Vector2(X, (deck + WFLOOR) / 2), 0.3, 0.35, 1.25)
	bt.light(2, Vector2(X, deck), 0.3, 0.35, 1.3)
	bi.rect(X - dw - 1, deck - 13, 1, 13, ink)
	bt.rect(X - dw, deck - 12, 1, 12, yel)
	bi.rect(X - dw - 1, deck - 13, dw + 2, 1, ink)
	bt.rect(X - dw, deck - 12, dw + 1, 1, yel)
	bt.rect(X - dw, deck - 7, dw - 2, 1, yd)
	var h := WFLOOR - deck
	for j in range(3, h + 1):
		var y := deck + j
		var s := dw - 1 + (fw - dw + 1) * float(j) / h
		for xx: int in [F.pyround(X - s), F.pyround(X + s)]:
			bi.px(xx - 1, y, ink)
			bk.px(xx, y, yel)
			bk.px(xx + 1, y, yd)
		if j % 9 == 5 and j < h - 3:
			var a := F.pyround(X - s) + 2
			var b := F.pyround(X + s) - 1
			bk.rect(a, y, b - a, 1, P.c8(168 * 0.85, 140 * 0.85, 62 * 0.85))
			bi.rect(a, y + 1, b - a, 1, ink)
	bk.rect(X - dw, deck + h / 2, 2 * dw + 1, 1, P.c8(60, 62, 68))
	for x: int in [X - fw - 1, X + fw - 1]:
		bi.rect(x, WFLOOR - 1, 3, 2, ink)
	bi.rect(X - dw - 1, deck, 2 * dw + 3, 3, ink)
	bt.rect(X - dw, deck, 2 * dw + 1, 1, P.c8(150, 154, 160))
	bt.rect(X - dw, deck + 1, 2 * dw + 1, 1, P.c8(92, 96, 104))


## people8.job_G: the grinder held to the seam, a jitter while it runs, a hot spot, a fan of sparks.
func _grinder(i: int, sp: Dictionary, on: bool, j: int, t: float) -> void:
	var hg: Array = F.K["handg"]
	var hx := int(sp["x0"]) + int(hg[0])
	var hy := int(sp["y0"]) + int(hg[1])
	var tx := int(sp["tip"][0])
	var ty := int(sp["tip"][1])
	var gi := p[StringName("w%d_tool_ink" % i)]
	var gk := p[StringName("w%d_tool_k" % i)]
	var gh := p[StringName("w%d_tool_hot" % i)]
	gk.light(2, Vector2(hx, hy), 0.35, 0.4, 1.3)
	var gx0 := hx + 1
	gi.rect(gx0, hy - 1 + j, 4, 3, P.c8(16, 18, 22))
	gk.rect(gx0, hy + j, 3, 1, P.c8(70, 76, 86))
	gk.rect(gx0 + 1, hy - 1 + j, 2, 1, P.c8(214, 160, 50))
	gh.rect(gx0 + 1, hy - 4 + j, 1, 3, P.c8(24, 26, 30))
	for d in range(-3, 4):
		if absi(d) < 3:
			gk.px(tx - 1, ty + d + j, P.c8(150, 156, 166))
		else:
			gh.px(tx - 1, ty + d + j, P.c8(20, 22, 26))
	gh.rect(tx - 2, ty - 3 + j, 1, 4, P.c8(30, 32, 38))
	if on:
		gh.px(tx, ty + j, P.c8(255, 236, 190))
		gh.px(tx, ty + 1 + j, P.c8(255, 170, 70))
	_ladder_sparks(i, sp, t, true)


# ------------------------------------------------------------------ the parts delivery, with hands (people8 round 16)
func _desk() -> void:
	var k := p[&"desk_k"]
	var ink := p[&"desk_ink"]
	k.light(2, Vector2(DESK_X + 6, LANE - 20), 0.35, 0.4, 1.3)
	var y0 := LANE - 3
	p[&"desk_sh"].contact(DESK_X, DESK_X + 12, y0, 2, 0.45)
	k.rect(DESK_X + 1, y0 - 1, 11, 2, P.c8(40, 44, 52))
	k.rect(DESK_X + 5, y0 - 22, 2, 21, P.c8(50, 54, 62))
	k.px(DESK_X + 5, y0 - 22, P.c8(96, 102, 112))
	for j in 13:
		var yy := y0 - 26 + j / 5
		k.px(DESK_X + j, yy, P.c8(70, 76, 86))
		ink.px(DESK_X + j, yy + 1, P.c8(16, 18, 22))
	k.rect(DESK_X + 2, y0 - 27, 9, 1, P.c8(222, 216, 196))
	k.rect(DESK_X + 2, y0 - 26, 4, 1, P.c8(200, 194, 174))
	ink.rect(DESK_X + 1, y0 - 33, 1, 7, P.c8(30, 32, 38))
	ink.rect(DESK_X + 1, y0 - 34, 4, 1, P.c8(30, 32, 38))
	ink.rect(DESK_X + 3, y0 - 33, 3, 1, P.c8(40, 42, 48))
	ink.px(DESK_X + 4, y0 - 32, P.c8(255, 230, 170))


static func _ease_lerp(a: Vector2, b: Vector2, k: float) -> Vector2:
	return a + (b - a) * F.smooth(k)


## people8.courier_state: (x, facing left, reaching) and the two crates [x, bottom, carried] A then B.
func _courier_state(u: float, at: PackedFloat32Array) -> Array[Vector3]:
	var s := _courier.segs
	var sa0 := float(s[1][1])
	var sa1 := float(s[1][2])
	var sb0 := float(s[3][1])
	var sb1 := float(s[3][2])
	var x := at[0]
	var left := at[3] > 0.5
	if u >= sa0 and u < sa1:
		left = u >= sa1 - 0.45
	var cx0 := x + 6
	var slot1 := Vector2(cx0 + 3, DECK_BOT)
	var slot2 := Vector2(cx0 + 18, DECK_BOT)
	var hl := Vector2(x - 22, LANE - 18)
	var hr := Vector2(x + 8, LANE - 18)
	var leg := Vector2(LEG_P, CRATE_ROW)
	var A := slot1
	var B := leg
	var carried := 0
	var reach := false
	if u < sb0:
		pass
	elif u >= sb0 + 2.6 or u >= sb1:
		A = leg
		B = slot2
	else:
		var v := u - sb0
		if v < 0.4:
			left = true
			reach = true
		elif v < 0.7:
			left = true
			reach = true
			B = _ease_lerp(leg, hl, (v - 0.4) / 0.3)
			carried = 2
		elif v < 1.0:
			left = v < 0.85
			B = hl if left else hr
			carried = 2
		elif v < 1.3:
			left = false
			reach = true
			B = _ease_lerp(hr, slot2, (v - 1.0) / 0.3)
			carried = 2
		elif v < 1.6:
			left = false
			reach = true
			B = slot2
		elif v < 1.9:
			left = false
			reach = true
			B = slot2
			A = _ease_lerp(slot1, hr, (v - 1.6) / 0.3)
			carried = 1
		elif v < 2.2:
			left = v >= 2.05
			B = slot2
			A = hl if left else hr
			carried = 1
		else:
			left = true
			reach = true
			B = slot2
			A = _ease_lerp(hl, leg, (v - 2.2) / 0.4)
			carried = 1
	return [Vector3(x, 1.0 if left else 0.0, 1.0 if reach else 0.0), Vector3(A.x, A.y, 1.0 if carried == 1 else 0.0),
		Vector3(B.x, B.y, 1.0 if carried == 2 else 0.0)]


func _delivery(t: float) -> void:
	var u := fposmod(t, 30.0)
	var s := _courier.segs
	var sa0 := float(s[1][1])
	var sa1 := float(s[1][2])
	var fx := _foreman_x(u, sa0, sa1)
	_desk()
	var at := _courier.at(u)
	var on := u >= _courier.t_in and u < _courier.t_out and not at.is_empty()
	var st: Array[Vector3] = []
	var crates: Array[Vector3] = [Vector3(LEG_P, CRATE_ROW, 0)]
	if on:
		st = _courier_state(u, at)
		crates = [st[1], st[2]]
	for i in crates.size():
		var c := crates[i]
		if c.z < 0.5 and absf(c.y - CRATE_ROW) < 0.5:
			var bx := F.pyround(c.x)
			p[StringName("leg_sh%d" % i)].contact(bx - 1, bx + 14, CRATE_ROW, 2, 0.45)
			p[StringName("leg%d" % i)].light(1, Vector2(bx + 7, CRATE_ROW - 6), 0.15)
			life.piece(p[StringName("leg%d" % i)], "crate", bx, CRATE_ROW - 12)
	if on:
		_courier_draw(u, at, st)
	_foreman(u, fx, sa0)


func _courier_draw(u: float, at: PackedFloat32Array, st: Array[Vector3]) -> void:
	var s := _courier.segs
	var x := int(st[0].x)
	var left := st[0].y > 0.5
	var reach := st[0].z > 0.5
	var stand_now := (u >= float(s[1][1]) and u < float(s[1][2])) or (u >= float(s[3][1]) and u < float(s[3][2]))
	var fi := int(F.Y["crew"]["look_suit"]["stand"]) if stand_now else int(at[2])
	var flip := left if stand_now else at[3] > 0.5
	var sz := life.crew_src("look_suit", fi).size
	var cx0 := x + 6
	p[&"cart_sh"].contact(cx0, cx0 + 34, LANE, 3)
	p[&"cart"].light(1, Vector2(cx0 + 12, LANE - 10), 0.15)
	life.piece(p[&"cart"], "cart2", cx0, LANE - 13)
	for i in 2:
		var c := st[i + 1]
		if c.z < 0.5 and absf(c.y - DECK_BOT) < 0.5:
			p[StringName("deck%d" % i)].light(1, Vector2(int(c.x) + 7, LANE - 16), 0.15)
			life.piece(p[StringName("deck%d" % i)], "crate", F.pyround(c.x), F.pyround(c.y) - 12)
	p[&"courier_sh"].contact(x - 7, x + 7, LANE, 3)
	p[&"courier"].light(1, Vector2(x, LANE - 20), 0.15)
	life.crew(p[&"courier"], "look_suit", fi, x - int(sz.x) / 2, LANE - int(sz.y), flip)
	var k := p[&"courier_k"]
	k.light(2, Vector2(x, LANE - 24), 0.3, 0.4, 1.3)
	for i in 2:
		var c := st[i + 1]
		if c.z > 0.5 or (reach and absf(c.y - DECK_BOT) > 0.5 and absf(c.y - CRATE_ROW) > 0.5):
			var bx := F.pyround(c.x)
			var bt := F.pyround(c.y)
			p[StringName("held%d" % i)].light(1, Vector2(bx + 7, bt - 6), 0.2)
			life.piece(p[StringName("held%d" % i)], "crate", bx, bt - 12)
			for hx: int in [bx - 1, bx + 14]:
				k.rect(hx, bt - 7, 1, 2, SKIN)
	if reach:
		var tgt: Vector3 = Vector3(NAN, 0, 0)
		for c in [st[1], st[2]]:
			if (c as Vector3).z > 0.5:
				tgt = c
				break
		if is_nan(tgt.x):
			for c in [st[1], st[2]]:
				var cc := c as Vector3
				if (absf(cc.x - (x - 22)) < 20) if left else (absf(cc.x - (x + 8)) < 20):
					tgt = cc
					break
		if not is_nan(tgt.x):
			var gx := F.pyround(tgt.x) + (14 if left else -1)
			var gy := F.pyround(tgt.y) - 6
			for v in ShipRoomKorvanLife.seg(Vector2(x - 3 if left else x + 3, LANE - 30), Vector2(gx, gy)):
				k.px(int(v.x), int(v.y), P.c8(206, 210, 220))
			k.px(gx, gy, SKIN)


static func _foreman_x(u: float, sa0: float, sa1: float) -> int:
	if u >= sa0 and u < sa0 + 0.75:
		return FORE_X - 2 * (1 + int((u - sa0) / 0.25))
	if u >= sa0 + 0.75 and u < sa1 - 0.1:
		return FORE_X - 6
	if u >= sa1 - 0.1 and u < sa1 + 0.65:
		return FORE_X - 6 + 2 * (1 + int((u - (sa1 - 0.1)) / 0.25))
	return FORE_X


func _foreman(u: float, fx: int, sa0: float) -> void:
	var pointing := u >= sa0 + 3.2 and u < sa0 + 4.4
	var at_desk := fx == FORE_X
	var w := fposmod(u, 8.0)
	var looking := at_desk and w >= 3.5 and w < 4.8
	var n := "tech_or_0" if pointing else ("tech_or_3" if looking else "tech_or_cut")
	p[&"fore_sh"].contact(fx - 9, fx + 9, LANE, 3)
	p[&"fore"].light(1, Vector2(fx, LANE - 20), 0.15)
	life.piece(p[&"fore"], n, fx - 18, LANE - 44)
	var k := p[&"fore_k"]
	var ink := p[&"fore_ink"]
	k.light(2, Vector2(fx, LANE - 24), 0.3, 0.4, 1.3)
	if at_desk and not looking:
		var hx := fx - 11
		var hy := LANE - 29
		if w < 2.0 or w >= 4.8:
			var bob := int(u * 5.0) % 2
			k.px(hx, hy + bob, SKIN)
			ink.px(hx - 1, hy - 1 + bob, P.c8(24, 24, 30))
		elif w < 2.5:
			var px := DESK_X + 10 - int((w - 2.0) / 0.5 * 8.0)
			k.rect(px, LANE - 31, 2, 1, P.c8(236, 230, 210))
			k.px(hx, hy, SKIN)
		else:
			var up := 3 if int((w - 2.5) * 4.0) % 2 == 0 else 0
			ink.rect(hx, hy - up, 2, 2, P.c8(60, 30, 24))
			ink.rect(DESK_X + 8, LANE - 30, 2, 1, P.c8(214, 160, 50) if w < 2.8 else P.c8(190, 50, 40))
	elif not pointing and not at_desk:
		var bx := fx - 9
		var by := LANE - 27
		ink.rect(bx - 1, by - 1, 7, 7, P.c8(30, 24, 18))
		k.rect(bx, by, 5, 5, P.c8(226, 222, 206))
		var chk := u >= sa0 + 0.75 and u < sa0 + 3.2
		var wob := int(u * (6.0 if chk else 2.0)) % 2
		k.rect(bx + 1, by + 1 + wob, 3, 1, P.c8(60, 60, 70))
		k.px(bx + 4, by + 3 + wob, SKIN)


# ------------------------------------------------------------------ the forklift hauling a crate across the front
func _forklift(t: float) -> void:
	var fx := F.fork_x(t)
	if is_nan(fx):
		return
	var x := F.pyround(fx)
	var wh: Array = F.K["fork_wh"]
	var fw := int(wh[0])
	var fh := int(wh[1])
	var lane := F.FORK_LANE
	p[&"fork_sh"].contact(x + 4, x + fw - 4, lane, 4, 0.6)
	p[&"fork"].light(1, Vector2(x + fw / 2, lane - 20), 0.15)
	life.piece(p[&"fork"], "fork", x, lane - fh + 1)
	p[&"fork_crate"].light(1, Vector2(x + fw - 8, lane - 16), 0.15)
	life.piece(p[&"fork_crate"], "fork_crate", x + fw - 17, lane - 24)
	var bc: Array = F.K["fork_beacon"]
	var bx := x + int(bc[0])
	var by := lane - fh + 1 + int(bc[1])
	if bx >= 0 and bx < 959:
		p[&"fork_lamp"].rect(bx, by, 2, 2, P.c8(255, 190, 70) if int(t / 0.2) % 2 == 0 else P.c8(110, 64, 22))
