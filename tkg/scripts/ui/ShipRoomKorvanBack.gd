class_name ShipRoomKorvanBack
extends RefCounted

## Korvan's film behind the hulls (mix18.render's back() and post_light()): the albedo edits, the
## girder, the door's corridor, the office, the holo-table room, the engine test, the wall crew, the
## drones, the cargo swap and the crane. Why: docs/why/ShipRoomKorvan.md#life

const F := preload("res://scripts/ui/ShipRoomKorvanFilm.gd")
const L := preload("res://scripts/ui/ShipRoomKorvanLife.gd")
const P := preload("res://scripts/ui/ShipRoomKorvanPaint.gd")
const INK := Color(14 / 255.0, 16 / 255.0, 20 / 255.0)
const DX0 := 530
const DX1 := 589
const DY0 := 150
const DY1 := 197
const DH := 48
const HX0 := 418
const HY0 := 158

var life: ShipRoomKorvanLife
var p: Dictionary[StringName, ShipRoomKorvanPaint] = {}
var _office: Image
var _albedo: Texture2D
var _wall: Array = []
var _corridor: Array = []
var _top_truck: ShipRoomKorvanLife.Walker


func _init(l: ShipRoomKorvanLife) -> void:
	life = l
	_albedo = ShipRoom.tex(&"korvan", "albedo.png")
	var r := life.src("office_mask")
	_office = life.atlas.get_image().get_region(Rect2i(r))
	var W := ShipRoomKorvanLife.Walker
	_wall = [W.new("t_loader", [["in", 726, 127, 20.0], ["walk", 792, 127], ["stand", 1.5], ["walk", 726, 127], ["out"]]),
		W.new("t_loader", [["in", 606, 210, 4.0], ["walk", 700, 210], ["stand", 1.5], ["walk", 606, 210], ["out"]]),
		W.new("t_loader", [["in", 160, 127, 12.0], ["walk", 226, 127], ["stand", 1.5], ["walk", 160, 127], ["out"]])]
	_corridor = [W.new("t_loader", [["in", 596, DY1 - 1, 1.8], ["walk", 524, DY1 - 1], ["out"]]),
		W.new("t_suit", [["in", 524, DY1 - 1, 3.4], ["walk", 596, DY1 - 1], ["out"]])]
	_top_truck = W.new("t_suit", [["in", 292, 48, -14.0], ["stand", 17.0], ["walk", 346, 48], ["stand", 8.4],
		["walk", 292, 48], ["stand", 40.0]])


func _mk(n: StringName, b: ShipRoomKorvanPaint.Blend = ShipRoomKorvanPaint.Blend.LIT) -> ShipRoomKorvanPaint:
	var q := life.paint(b)
	p[n] = q
	return q


## The layers, in the film's order: albedo edits first (lit by the room), then post_light's.
func build_edits() -> void:
	_mk(&"edit").light(3)


func build() -> void:
	_mk(&"girder")
	_mk(&"corridor")
	_mk(&"cor_crew").light(5, Vector2.ZERO, 0.55, 0, 9, 0.55, P.c8(40, 30, 20))
	_mk(&"office", P.Blend.MUL)
	_mk(&"paper")
	_mk(&"holo")
	_mk(&"beacons")
	_mk(&"burner", P.Blend.UNLIT)
	_mk(&"blades")
	_mk(&"embers")
	p[&"steam"] = life.puffs()
	for i in _wall.size():
		_mk(StringName("wall_sh%d" % i), P.Blend.MUL)
		_mk(StringName("wall%d" % i))
	_build_jobs()
	_mk(&"truck_k")
	_mk(&"truck_crate")
	_mk(&"truck_hand")
	_mk(&"stack")
	_mk(&"tele")
	_mk(&"tele_lamp")
	_mk(&"survey")
	_mk(&"survey_nav")
	_mk(&"stack_crate")
	for i in 2:
		_mk(StringName("cargo_crate%d" % i))
		_mk(StringName("cargo_line%d" % i))
		_mk(StringName("cargo%d" % i))
		_mk(StringName("cargo_nav%d" % i))
	_build_crane()
	p[&"smoke"] = life.puffs()
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/ship_room_korvan_burner.gdshader")
	p[&"burner"].material = mat


func _build_jobs() -> void:
	_mk(&"con_sh", P.Blend.MUL)
	_mk(&"con")
	_mk(&"con_k")
	_mk(&"con_ui")
	_mk(&"ga_sh", P.Blend.MUL)
	_mk(&"ga_valve")
	_mk(&"ga_wheel")
	_mk(&"ga")
	_mk(&"ga_k")
	_mk(&"ga_ui")
	_mk(&"rig_crate")
	_mk(&"rig_ink")
	_mk(&"rig_chain")
	_mk(&"rig_sh", P.Blend.MUL)
	_mk(&"rig")
	_mk(&"rig_k")


func _build_crane() -> void:
	_mk(&"load")
	_mk(&"load_bits")
	_mk(&"trolley")
	_mk(&"rig_wheels")
	_mk(&"rig_lit")
	_mk(&"rig_dark")
	_mk(&"dload_top")
	_mk(&"dload_bot")
	_mk(&"dcable")
	_mk(&"dcable_ink")
	for j in 2:
		_mk(StringName("drone%d" % j))
		_mk(StringName("drone_bits%d" % j))


func draw(f: int, t: float, lk: float) -> void:
	var fr: Dictionary = (F.D["frames"] as Array)[f]
	var tB := F.win(t, F.ENGINE_AT)
	var tC := F.win(t, F.DOOR_AT)
	_edits(t, tB, tC, fr)
	life.piece(p[&"girder"], "girder", 0, 0)
	_door(tC)
	_office_draw(t)
	_holo(t, float(fr["holo_fl"]))
	_engine(t, tB, f)
	_walkers(t)
	_jobs(t)
	_trucks(t)
	_drones(t)
	_cargo(tC, t)
	_crane(t, f, lk)


# ------------------------------------------------------------------ before the light: the albedo edits
func _edits(t: float, tB: float, tC: float, fr: Dictionary) -> void:
	var e := p[&"edit"]
	# the deck hoist's block moves; the wall behind it painted back, its chains down to it (people8.back8)
	var dy := F.pyround(_hoist_dy(t))
	life.piece(e, "wallbehind8", 873, 72)
	var top := 100 + dy
	var ch := life.src("chains8")
	e.sprite(life.atlas, Rect2(ch.position, Vector2(12, top - 72)), 873, 72)
	life.piece(e, "block8", 873, top)
	# the dial's face and its needle
	for yy in range(-2, 3):
		for xx in range(-2, 3):
			if xx * xx + yy * yy <= 5:
				e.px(910 + xx, 171 + yy, P.c8(200, 200, 190))
	var a := deg_to_rad(225.0 - 270.0 * _gauge_level(t))
	for r in [1, 2]:
		e.px(910 + F.pyround(r * cos(a)), 171 - F.pyround(r * sin(a)), P.c8(30, 20, 20))
	e.px(910, 171, P.c8(30, 20, 20))
	# the back room's taller opening (booth11.back_opening)
	var fd := P.c8(21, 25, 37)
	var fl := P.c8(70, 90, 107)
	e.rect(416, 156, 42, 1, fd)
	e.rect(417, 157, 40, 1, fl)
	e.rect(416, 156, 1, 29, fd)
	e.rect(417, 157, 1, 28, fl)
	e.rect(457, 156, 1, 29, fd)
	e.rect(456, 157, 1, 28, fl)
	# heat shakes the air over the port: each row pair slid a pixel as the film drew it
	var sh: Array = fr["shim"]
	for i in sh.size():
		var s := int(sh[i])
		if s == 0:
			continue
		var y := 118 + 2 * i
		var u := (166.0 - y) / 48.0
		var x0 := F.PX - 14 - int(8 * u)
		var x1 := F.PX + 15 + int(8 * u)
		if s > 0:
			e.sprite(_albedo, Rect2(x0, y, x1 - x0 - 1, 2), x0 + 1, y)
			e.sprite(_albedo, Rect2(x1 - 1, y, 1, 2), x0, y)
		else:
			e.sprite(_albedo, Rect2(x0 + 1, y, x1 - x0 - 1, 2), x0, y)
			e.sprite(_albedo, Rect2(x0, y, 1, 2), x1 - 1, y)
	# the loading door rolled up by its opening
	var d := F.pyround(F.opening(tC) * DH)
	if d > 0:
		e.rect(DX0, DY0, DX1 - DX0 + 1, DH, Color.BLACK)
		if d < DH:
			var pr := life.src("panel")
			e.sprite(life.atlas, Rect2(pr.position + Vector2(0, d), Vector2(pr.size.x, DH - d)), DX0, DY0)


static func _hoist_dy(t: float) -> float:
	var u := fposmod(t, 12.0)
	if u < 1.0:
		return 0.0
	if u < 4.5:
		return -12.0 * F.smooth((u - 1.0) / 3.5)
	if u < 6.5:
		return -12.0
	if u < 10.0:
		return -12.0 * (1.0 - F.smooth((u - 6.5) / 3.5))
	return 0.0


static func _gauge_level(t: float) -> float:
	var u := fposmod(t, 10.0)
	var v := 0.15
	if u < 2.5:
		v = 0.15 + 0.6 * F.smooth(u / 2.5)
	elif u < 6.0:
		v = 0.75
	elif u < 8.5:
		v = 0.75 - 0.6 * F.smooth((u - 6.0) / 2.5)
	var run := F.burn(F.win(t, F.ENGINE_AT))
	return minf(1.0, v + 0.25 * run + (0.03 * sin(t * 40.0) if run > 0.5 else 0.0))


# ------------------------------------------------------------------ the door's corridor and its loaders
func _door(tC: float) -> void:
	var d := F.pyround(F.opening(tC) * DH)
	if d <= 0:
		return
	var y0 := DY1 + 1 - d
	var cr := life.src("corridor")
	p[&"corridor"].sprite(life.atlas, Rect2(cr.position + Vector2(0, y0 - DY0), Vector2(cr.size.x, d)), DX0, y0)
	var q := p[&"cor_crew"]
	q.clip = Rect2(DX0, y0, DX1 - DX0 + 1, DY1 + 1 - y0)
	for wk: ShipRoomKorvanLife.Walker in _corridor:
		var a := wk.at(tC)
		if a.is_empty():
			continue
		var s := life.crew_src(wk.look, int(a[2]))
		life.crew(q, wk.look, int(a[2]), int(a[0]) - int(s.size.x) / 2, int(a[1]) - int(s.size.y), a[3] > 0.5)


# ------------------------------------------------------------------ the office: two clerks' shapes on the glass
func _office_draw(t: float) -> void:
	var u := fposmod(t, 30.0)
	_shade(_rect_cells(236, 186, 13, 4), 0.38)
	var cab := _rect_cells(258, 181, 5, 9)
	if (u >= 4.3 and u < 6.2) or (u >= 23.7 and u < 24.8):
		cab.append_array(_rect_cells(256, 184, 2, 2))
	_shade(cab, 0.45)
	var b := _clerk_b(u)
	_shade(_figure(241, int(b.x), int(b.y), int(b.z)), 0.30)
	var a := _clerk_a(u)
	_shade(_figure(int(a.x), int(a.y), int(a.z) / 10, int(a.z) % 10 - 5), 0.26)
	var pp := Vector2i(-1, -1)
	if b.w > 0.5:
		pp = Vector2i(241 + 6, int(b.x) + 6)
	elif a.w > 0.5:
		pp = Vector2i(int(a.x) - 5, int(a.y) + 6)
	if pp.x >= 0 and _om(pp.x, pp.y):
		p[&"paper"].rect(pp.x, pp.y, 2, 2, P.c8(236, 226, 196))


func _om(x: int, y: int) -> bool:
	var lx := x - 234
	var ly := y - 176
	return lx >= 0 and ly >= 0 and lx < _office.get_width() and ly < _office.get_height() and _office.get_pixel(lx, ly).a > 0.5


static func _rect_cells(x: int, y: int, w: int, h: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for yy in h:
		for xx in w:
			out.append(Vector2i(x + xx, y + yy))
	return out


func _shade(cells: Array[Vector2i], k: float) -> void:
	var seen := {}
	for c in cells:
		if not seen.has(c) and _om(c.x, c.y):
			seen[c] = true
			p[&"office"].rect(c.x, c.y, 1, 1, Color(k, k, k))


## office11.figure: head and shoulders 7 wide; arm 0 none, 1 out, 2 up; side -1 or 1.
static func _figure(cx: int, top: int, arm: int, side: int) -> Array[Vector2i]:
	var m: Array[Vector2i] = []
	m.append_array(_rect_cells(cx - 1, top, 3, 3))
	m.append(Vector2i(cx, top + 3))
	for c in _rect_cells(cx - 3, top + 4, 7, 12):
		if not (c.y == top + 4 and absi(c.x - cx) == 3):
			m.append(c)
	var sx := cx + 3 * side
	if arm == 1:
		for k in 4:
			m.append(Vector2i(sx + k * side, top + 6))
	elif arm == 2:
		for yy in range(top + 1, top + 6):
			m.append(Vector2i(sx + side, yy))
	return m


## (x, top, arm*10 + side+5 packed as arm code, paper) for the clerk who walks (office11.clerk_a).
static func _clerk_a(u: float) -> Vector4:
	var keys := [[0.0, 250], [2.5, 250], [4.0, 259], [6.5, 259], [8.0, 250], [11.6, 250], [13.2, 270], [15.8, 270],
		[17.4, 252], [22.0, 252], [23.5, 258], [25.0, 258], [26.6, 250], [30.0, 250]]
	var x := 250.0
	var walking := false
	for i in keys.size() - 1:
		var t0 := float(keys[i][0])
		var t1 := float(keys[i + 1][0])
		if u >= t0 and u < t1:
			var x0 := float(keys[i][1])
			var x1 := float(keys[i + 1][1])
			x = x0 + (x1 - x0) * F.smooth((u - t0) / (t1 - t0)) if x1 != x0 else x0
			walking = x1 != x0
			break
	var bob := 1 if walking and int(u * 6.0) % 2 == 1 else 0
	var arm := 0
	var side := 0
	if (u >= 4.3 and u < 6.2) or (u >= 23.7 and u < 24.8):
		arm = 1
		side = 1
	elif (u >= 8.4 and u < 9.1) or (u >= 19.0 and u < 19.6):
		arm = 2
		side = -1
	elif u >= 10.0 and u < 11.0:
		arm = 1
		side = -1
	var paper := (u >= 10.6 and u < 13.2) or (u >= 15.8 and u < 17.4)
	return Vector4(F.pyround(x), 178 + bob, arm * 10 + side + 5, 1.0 if paper else 0.0)


## (top, arm, side, paper) for the clerk at the desk (office11.clerk_b).
static func _clerk_b(u: float) -> Vector4:
	var top := 182
	if u >= 9.0 and u < 11.4:
		top = 182 - F.pyround(4.0 * minf(1.0, minf((u - 9.0) / 0.4, (11.4 - u) / 0.4)))
	elif u >= 19.0 and u < 21.0:
		top = 182 - F.pyround(4.0 * minf(1.0, minf((u - 19.0) / 0.4, (21.0 - u) / 0.4)))
	else:
		top = 182 + (1 if int(u * 4.0) % 7 == 0 else 0)
	var arm := 0
	var side := 1
	var paper := false
	if u >= 10.0 and u < 10.6:
		arm = 1
		paper = true
	elif u >= 19.6 and u < 20.4:
		arm = 2
	elif top >= 182 and int(u * 5.0) % 3 == 0 and not (u >= 9.0 and u < 21.0):
		arm = 1
	return Vector4(top, arm, side, 1.0 if paper else 0.0)


# ------------------------------------------------------------------ the back room: the holo-table (booth11 idea 9)
static var _hull_segs: Array[Array] = []


static func _box(x0: float, x1: float, z0: float, z1: float, y0: float, y1: float) -> Array[Array]:
	var pts: Array[Vector3] = []
	for x in [x0, x1]:
		for y in [y0, y1]:
			for z in [z0, z1]:
				pts.append(Vector3(x, y, z))
	var out: Array[Array] = []
	for e: Vector2i in [Vector2i(0, 1), Vector2i(2, 3), Vector2i(4, 5), Vector2i(6, 7), Vector2i(0, 2), Vector2i(1, 3),
			Vector2i(4, 6), Vector2i(5, 7), Vector2i(0, 4), Vector2i(1, 5), Vector2i(2, 6), Vector2i(3, 7)]:
		out.append([pts[e.x], pts[e.y]])
	return out


static func _hull_model() -> Array[Array]:
	if not _hull_segs.is_empty():
		return _hull_segs
	var segs := _box(-8, 7, -2.5, 2.5, 0, 3)
	for c: Vector3 in [Vector3(7, 0, -2.5), Vector3(7, 0, 2.5), Vector3(7, 3, -2.5), Vector3(7, 3, 2.5)]:
		segs.append([c, Vector3(11, 1.2, 0)])
	segs.append_array(_box(-3, 1, -1.2, 1.2, 3, 5.5))
	for s in segs:
		_hull_segs.append([s[0], s[1], false])
	for s in _box(-11, -8, -2.2, -0.6, 0.6, 2.4) + _box(-11, -8, 0.6, 2.2, 0.6, 2.4):
		_hull_segs.append([s[0], s[1], true])
	return _hull_segs


## booth11.put/line on the room's 38 x 26 canvas, alpha a.
func _hput(x: float, y: float, c: Color, a: float = 1.0) -> void:
	var xi := F.pyround(x)
	var yi := F.pyround(y)
	if xi >= 0 and yi >= 0 and xi < 38 and yi < 26:
		p[&"holo"].rect(HX0 + xi, HY0 + yi, 1, 1, Color(c.r, c.g, c.b, a))


func _hline(x0: float, y0: float, x1: float, y1: float, c: Color, a: float = 1.0) -> void:
	var a0 := Vector2(F.pyround(x0), F.pyround(y0))
	var b0 := Vector2(F.pyround(x1), F.pyround(y1))
	var n := maxi(1, int(maxf(absf(b0.x - a0.x), absf(b0.y - a0.y))))
	for i in n + 1:
		var v := a0 + (b0 - a0) * float(i) / float(n)
		_hput(v.x, v.y, c, a)


func _hrect(x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	p[&"holo"].rect(HX0 + x0, HY0 + y0, x1 - x0 + 1, y1 - y0 + 1, c)


func _holo(t: float, fl: float) -> void:
	var q := p[&"holo"]
	q.clip = Rect2(HX0, HY0, 38, 26)
	var u := fposmod(t, 15.0)
	var bands := [[P.c8(40, 52, 72), 3], [P.c8(34, 46, 64), 5], [P.c8(30, 40, 56), 6], [P.c8(26, 34, 48), 12]]
	var y := 0
	for b: Array in bands:
		q.rect(HX0, HY0 + y, 38, int(b[1]), b[0])
		y += int(b[1])
	for yy in range(4, 15):
		var f := (15.0 - yy) / 11.0
		var hw := 5.0 + 6.0 * f
		for x in range(int(19 - hw), int(19 + hw) + 1):
			if ShipRoom.bayer4(HX0 + x, HY0 + yy) < 0.12:
				_hput(x, yy, P.c8(90, 200, 240), 0.3)
	var th := TAU * (t / 15.0)
	var hot := u >= 5.0 and u < 8.0 and int(u * 5.0) % 2 == 0
	for s in _hull_model():
		var pts: Array[Vector2] = []
		for v: Vector3 in [s[0], s[1]]:
			var w := v * 1.3
			var X := w.x * cos(th) - w.z * sin(th)
			var Z := w.x * sin(th) + w.z * cos(th)
			pts.append(Vector2(19.0 + X, 12.0 - w.y * cos(0.42) + Z * sin(0.42) * 0.8))
		var eng: bool = s[2]
		var c := P.c8(255, 150, 60) if eng and hot else P.c8(150, 242, 255)
		_hline(pts[0].x, pts[0].y, pts[1].x, pts[1].y, c, 1.0 if eng and hot else 0.85)
	for yy in 26:
		if (yy + int(t * 6.0)) % 3 == 0:
			q.rect(HX0 + 8, HY0 + yy, 23, 1, Color(0, 0, 0, 1.0 - (0.86 + 0.08 * fl)))
	_hrect(6, 15, 32, 17, P.c8(44, 52, 68))
	_hrect(6, 15, 32, 15, P.c8(70, 84, 104))
	_hrect(12, 15, 26, 15, P.c8(150, 240, 255))
	_hrect(8, 18, 8, 21, P.c8(30, 34, 44))
	_hrect(30, 18, 30, 21, P.c8(30, 34, 44))
	var s1 := life.src("holo_s1")
	life.piece(q, "holo_s1", HX0, HY0 + 22 - int(s1.size.y))
	var w1 := int(s1.size.x)
	var jab := u >= 5.0 and u < 8.0
	var reach := 11 + (F.pyround(1.5 * sin(u * 9.0)) if jab else 0)
	_hline(w1 - 2, 9, reach - 2, 7 if jab else 9, P.c8(200, 200, 196))
	var s2 := life.src("holo_s2")
	var nod := 1 if jab and int(u * 4.0) % 2 == 0 else 0
	q.sprite(life.atlas, Rect2(s2.position + Vector2(0, 5), Vector2(s2.size.x, s2.size.y - 5)), HX0 + 31, HY0 + 9)
	q.sprite(life.atlas, Rect2(s2.position, Vector2(s2.size.x, 5)), HX0 + 31, HY0 + 4 + nod)
	_hrect(31, 10, 31 + int(s2.size.x) - 2, 10, P.c8(60, 70, 44))
	for i in 3:
		_hput(2 + i, 3 - i, Color.WHITE, 0.22)
		_hput(3 + i, 3 - i, Color.WHITE, 0.12)


# ------------------------------------------------------------------ the engine test: beacons, the port, embers, steam
func _engine(t: float, tB: float, f: int) -> void:
	var b := F.burn(tB)
	var hh := F.heat(tB)
	var on := F.beacon_on(tB) and tB > 0.0
	var q := p[&"beacons"]
	for i in 2:
		var bc: Vector2i = F.BEACONS[i]
		var dome := 0.0
		if on:
			var c := cos(TAU * (1.25 * tB + i * 0.37))
			dome = 0.35 + 0.65 * c if c > 0.05 else 0.35
		q.rect(bc.x - 2, bc.y + 2, 5, 2, P.c8(26, 30, 36))
		var col := P.c8(255 * (0.3 + 0.7 * dome), 170 * (0.3 + 0.7 * dome), 60 * (0.3 + 0.7 * dome)) if on else P.c8(70, 46, 20)
		q.rect(bc.x - 1, bc.y, 3, 2, col)
		if on and dome > 0.7:
			q.px(bc.x, bc.y - 1, P.c8(255, 220, 140))
	var bm := p[&"burner"].material as ShaderMaterial
	var tn: Dictionary = (F.D["tenths"] as Array)[int(floorf(tB * 10.0)) % 300]
	var lobes: Array = tn["lobes"]
	var lo := PackedFloat32Array()
	for v: Variant in lobes:
		lo.append(float(v))
	lo.append(float(lobes[0]))
	bm.set_shader_parameter(&"burn", b)
	bm.set_shader_parameter(&"heat", hh)
	bm.set_shader_parameter(&"lobes", lo)
	bm.set_shader_parameter(&"lobe_k", float(tn["lobe_k"]))
	p[&"burner"].sprite(life.white, Rect2(0, 0, 21, 21), F.PX - 10, F.PY - 10)
	if tB < 2.6 and b > 0.02:
		var spin := TAU * (0.6 * tB + 1.8 * pow(maxf(0.0, tB - 1.4), 2.0)) if tB < 3.0 else 0.0
		for i in 3:
			var a := spin + i * TAU / 3.0
			var rr := 1.0
			while rr < 6.0:
				p[&"blades"].px(F.PX - 10 + 10 + F.pyround(rr * cos(a)), F.PY - 10 + 10 + F.pyround(rr * sin(a)), P.c8(24, 20, 22))
				rr += 0.5
	if tB <= 0.0:
		return
	var em: Array = F.D["embers"]
	for i in em.size():
		var e: Array = em[i]
		var age := tB - float(e[0])
		if age < 0.0 or age > float(e[1]):
			continue
		var x := 882.0 + float(e[4]) + float(e[2]) * age + 3.0 * sin(age * 5.0 + i)
		var y := 168.0 + float(e[3]) * age + 10.0 * age * age
		var a := age / float(e[1])
		var c := P.c8(255, 230, 150) if a < 0.25 else (P.c8(255, 160, 60) if a < 0.6 else P.c8(170, 60, 24))
		p[&"embers"].px(F.pyround(x), F.pyround(y), c)
	var st: Array = F.D["steam"]
	for i in st.size():
		var s: Array = st[i]
		var age := tB - float(s[0])
		if age < 0.0 or age > float(s[1]):
			continue
		var a := age / float(s[1])
		ShipRoomKorvanLife.puff(p[&"steam"], 918.0 + float(s[2]) + 10.0 * age + 3.0 * sin(age * 2.0 + i),
			186.0 - 26.0 * age - 4.0 * age * age, 3.0 + 7.0 * a, (1.0 - a) * 0.55)


# ------------------------------------------------------------------ the wall's walkers
func _walkers(t: float) -> void:
	for i in _wall.size():
		var wk: ShipRoomKorvanLife.Walker = _wall[i]
		var a := wk.at(t)
		if a.is_empty() or a[4] <= 0.5:
			continue
		var s := life.crew_src(wk.look, int(a[2]))
		var x := int(a[0]) - int(s.size.x) / 2
		var y := int(a[1]) - int(s.size.y)
		var fy := mini(539, y + int(s.size.y) - 1)
		p[StringName("wall_sh%d" % i)].contact(x + 2, x + s.size.x - 3, fy + 1, 2, 0.4)
		var q := p[StringName("wall%d" % i)]
		q.light(1, Vector2(x + int(s.size.x) / 2, fy - 5), 0.12)
		life.crew(q, wk.look, int(a[2]), x, y, a[3] > 0.5)


# ------------------------------------------------------------------ the wall crew's jobs (people8.wall_jobs8)
const SKIN := Color(236 / 255.0, 160 / 255.0, 112 / 255.0)
const SLEEVE := Color(206 / 255.0, 210 / 255.0, 220 / 255.0)


func _jobs(t: float) -> void:
	var run := F.burn(F.win(t, F.ENGINE_AT))
	# the console hand types; the screen's trace runs, and jumps while the stand runs
	var s := life.crew_src("t_suit", 0)
	p[&"con_sh"].contact(827, 835, 210, 2, 0.4)
	p[&"con"].light(1, Vector2(831, 200), 0.12)
	life.crew(p[&"con"], "t_suit", 0, 831 - int(s.size.x) / 2, 210 - int(s.size.y))
	var u := fposmod(t, 6.0)
	var typing := fposmod(u, 2.0) < 1.3 and not (u >= 4.0 and u < 5.0)
	var bob := 1 if typing and int(t * 7.0) % 2 == 1 else 0
	var k := p[&"con_k"]
	k.light(2, Vector2(834, 193), 0.25, 0.3, 1.3)
	for v in ShipRoomKorvanLife.seg(Vector2(833, 197), Vector2(836, 191 - bob)):
		k.px(int(v.x), int(v.y), SLEEVE)
	k.px(837, 190 - bob, SKIN)
	var ui := p[&"con_ui"]
	ui.rect(840, 180, 8, 6, P.c8(8, 30, 20))
	var amp := 1.0 + 1.6 * run
	for c in 8:
		var ph := c * 0.9 - t * 5.0
		var y := 182.5 + amp * sin(ph) * (1.0 if run < 0.3 else 1.0 + 0.6 * sin(ph * 3.1))
		ui.px(840 + c, F.pyround(clampf(y, 180, 185)), P.c8(150, 255, 170) if run < 0.5 else P.c8(255, 220, 120))
	if int(t * 2.0) % 2 == 0:
		ui.px(838, 188, P.c8(255, 80, 60))
	_gauge_hand(t)
	_rigger(t)


func _gauge_hand(t: float) -> void:
	var s := life.crew_src("t_suit", 0)
	p[&"ga_sh"].contact(914, 922, 210, 2, 0.4)
	var u := fposmod(t, 10.0)
	var turning := u < 2.5 or (u >= 6.0 and u < 8.5)
	var ang := 0.0
	if u < 2.5:
		ang = 6.0 * F.smooth(u / 2.5)
	elif u < 6.0:
		ang = 6.0
	elif u < 8.5:
		ang = 6.0 * (1.0 - F.smooth((u - 6.0) / 2.5))
	p[&"ga_valve"].rect(908, 193, 3, 2, P.c8(40, 42, 48))
	var w := p[&"ga_wheel"]
	w.light(2, Vector2(909, 191), 0.3, 0.35, 1.3)
	for a in 8:
		var aa := a * PI / 4.0
		w.px(909 + F.pyround(2 * cos(aa)), 191 + F.pyround(2 * sin(aa)), P.c8(200, 46, 34))
	for sa: float in [0.0, PI / 2.0]:
		w.px(909 + F.pyround(1.4 * cos(ang + sa)), 191 + F.pyround(1.4 * sin(ang + sa)), P.c8(70, 20, 16))
	w.px(909, 191, P.c8(230, 220, 200))
	p[&"ga"].light(1, Vector2(918, 196), 0.22)
	life.crew(p[&"ga"], "t_suit", 0, 918 - int(s.size.x) / 2, 210 - int(s.size.y), true)
	var k := p[&"ga_k"]
	k.light(2, Vector2(915, 193), 0.25, 0.3, 1.3)
	if turning:
		var hx := 909 + F.pyround(2 * cos(ang))
		var hy := 191 + F.pyround(2 * sin(ang))
		for v in ShipRoomKorvanLife.seg(Vector2(916, 197), Vector2(hx + 1, hy)):
			k.px(int(v.x), int(v.y), SLEEVE)
		k.px(hx + 1, hy, SKIN)
	elif u >= 3.0 and u < 6.0:
		k.rect(913, 194, 3, 4, P.c8(226, 222, 206))
		k.px(916, 196, SKIN)
		p[&"ga_ui"].px(914, 195 + int(t * 6.0) % 2, P.c8(40, 40, 60))
	p[&"ga_ui"].rect(902, 155, 7, 1, P.c8(30, 32, 36))
	p[&"ga_ui"].rect(903, 156, 5, 1, P.c8(255, 226, 160))


func _rigger(t: float) -> void:
	var dy := F.pyround(_hoist_dy(t))
	var u := fposmod(t, 12.0)
	var hauling := (u >= 1.0 and u < 4.5) or (u >= 6.5 and u < 10.0)
	var sway := (1 if int(t * 1.5) % 2 == 1 else 0) if (u >= 4.5 and u < 6.5) else 0
	p[&"rig_crate"].light(1, Vector2(878, 120 + dy), 0.2)
	life.piece(p[&"rig_crate"], "smallbox8", 874 + sway, 118 + dy)
	p[&"rig_ink"].px(878 + sway, 118 + dy, P.c8(20, 22, 26))
	var run_s := 0.0
	if u >= 1.0 and u < 4.5:
		run_s = 30.0 * F.smooth((u - 1.0) / 3.5)
	elif u >= 4.5 and u < 6.5:
		run_s = 30.0
	elif u >= 6.5 and u < 10.0:
		run_s = 30.0 - 30.0 * F.smooth((u - 6.5) / 3.5)
	var c := p[&"rig_chain"]
	c.light(2, Vector2(871, 100), 0.3, 0.35, 1.3)
	for y in range(74, 117):
		for xd: Vector2i in [Vector2i(870, 1), Vector2i(871, -1)]:
			var lit := posmod(y + xd.y * int(run_s), 3) != 0
			c.px(xd.x, y, P.c8(150, 150, 158) if lit else P.c8(50, 52, 58))
	var s := life.crew_src("t_rigger", 0)
	p[&"rig_sh"].contact(862, 870, 127, 2, 0.4)
	p[&"rig"].light(1, Vector2(866, 112), 0.3)
	life.crew(p[&"rig"], "t_rigger", 0, 866 - int(s.size.x) / 2, 127 - int(s.size.y))
	var k := p[&"rig_k"]
	k.light(2, Vector2(868, 110), 0.25, 0.3, 1.3)
	var sl := P.c8(60, 58, 64)
	if hauling:
		var f := fposmod(u * 2.2, 1.0)
		for hy: int in [104 + F.pyround(6 * f), 110 - F.pyround(6 * f)]:
			for v in ShipRoomKorvanLife.seg(Vector2(867, 113), Vector2(869, hy)):
				k.px(int(v.x), int(v.y), sl)
			k.px(869, hy, SKIN)
	else:
		for v in ShipRoomKorvanLife.seg(Vector2(867, 113), Vector2(869, 108)):
			k.px(int(v.x), int(v.y), sl)
		k.px(869, 108, SKIN)


# ------------------------------------------------------------------ the top deck's hand truck, the stack by the cage
func _trucks(t: float) -> void:
	var tt := fposmod(t, 30.0)
	var a := _top_truck.at(tt)
	if a.is_empty():
		a = _top_truck.at(tt + 30.0)
	if not a.is_empty():
		var s := life.crew_src("t_suit", int(a[2]))
		var x := int(a[0]) - int(s.size.x) / 2
		var y := int(a[1]) - int(s.size.y)
		var left := a[3] > 0.5
		var feet := y + int(s.size.y)
		var cx := x + int(s.size.x) / 2
		var tx := cx - 8 if left else cx + 6
		var k := p[&"truck_k"]
		k.light(2, Vector2(tx, feet - 6), 0.25, 0.3, 1.2)
		for i in 12:
			k.px(tx + (i / 5) * (1 if left else -1), feet - 1 - i, P.c8(70, 78, 90))
		k.rect(tx - 3, feet - 1, 7, 1, P.c8(70, 78, 90))
		if not (tt >= 8.6 and tt < 22.6):
			var bx := tx - 10 if left else tx + 1
			p[&"truck_crate"].light(1, Vector2(bx + 4, feet - 6), 0.2)
			life.piece(p[&"truck_crate"], "small_crate", bx, feet - 11)
		p[&"truck_hand"].light(1, Vector2(cx, feet - 5), 0.12)
		life.crew(p[&"truck_hand"], "t_suit", int(a[2]), x, y, left)
	p[&"stack"].light(1, Vector2(226, 204), 0.2)
	life.piece(p[&"stack"], "small_crate", 222, 199)


# ------------------------------------------------------------------ the telemetry drone and the survey drone
func _drones(t: float) -> void:
	var dy := F.pyround(2.0 * sin(TAU * t / 2.5))
	p[&"tele"].light(1, Vector2(846, 140), 0.25)
	life.piece(p[&"tele"], "drone_b", 846 - 9, 132 + dy)
	if int(t * 1.6) % 2 == 0:
		p[&"tele_lamp"].px(846, 132 + dy + 13, P.c8(255, 60, 50))
	var d := F.drone_at(t)
	var dxi := F.pyround(d.x)
	p[&"survey"].light(1, Vector2(dxi, 100), 0.4)
	life.piece(p[&"survey"], "drone_a", dxi - 8, 96)
	if dxi - 7 >= 0 and dxi + 7 < 960:
		if int(t * 2.5) % 2 == 0:
			p[&"survey_nav"].px(dxi - 7, 100, P.c8(255, 70, 60))
		if int(t * 2.5 + 0.5) % 2 == 0:
			p[&"survey_nav"].px(dxi + 7, 100, P.c8(90, 255, 140))


# ------------------------------------------------------------------ the cargo drones swap the top deck's crate through the door
const D1 := [[0.0, -24, 2], [1.6, 527, 2], [2.0, 527, 8], [2.4, 527, 8], [2.8, 527, 4], [3.2, 531, 4], [4.8, 548, 150],
	[5.2, 548, 160], [5.8, 512, 160]]
const D2 := [[5.6, 606, 160], [6.2, 548, 160], [6.6, 548, 150], [8.0, 527, 7], [8.3, 527, 11], [8.6, 527, 11],
	[8.9, 527, 7], [10.0, 990, 2]]


static func _path(pts: Array, t: float) -> Vector2:
	if t < float(pts[0][0]) or t > float(pts[-1][0]):
		return Vector2(NAN, NAN)
	for i in pts.size() - 1:
		var a: Array = pts[i]
		var b: Array = pts[i + 1]
		if t >= float(a[0]) and t <= float(b[0]):
			var u := F.smooth((t - float(a[0])) / maxf(1e-6, float(b[0]) - float(a[0])))
			return Vector2(float(a[1]) + (float(b[1]) - float(a[1])) * u, float(a[2]) + (float(b[2]) - float(a[2])) * u)
	return Vector2(NAN, NAN)


func _cargo(tc: float, t: float) -> void:
	if tc < 2.4 or tc >= 8.6:
		p[&"stack_crate"].light(1, Vector2(527, 26))
		life.piece(p[&"stack_crate"], "crate", 520, 20)
	if tc <= 0.0:
		return
	var warm := P.c8(40, 30, 20)
	for j in 2:
		var pos := _path(D1 if j == 0 else D2, tc)
		if is_nan(pos.x):
			continue
		var x := F.pyround(pos.x)
		var y := F.pyround(pos.y)
		var n := "drone_d1" if j == 0 else "drone_d2"
		var sz := life.src(n).size
		var carrying := tc >= 2.4 if j == 0 else tc < 8.6
		var inside := tc >= 5.0 if j == 0 else tc < 6.2
		var qs: Array[ShipRoomKorvanPaint] = [p[StringName("cargo_crate%d" % j)], p[StringName("cargo_line%d" % j)],
			p[StringName("cargo%d" % j)], p[StringName("cargo_nav%d" % j)]]
		var mul := 0.55 if inside else 1.0
		var add := warm if inside else Color(0, 0, 0)
		for q in qs:
			q.clip = Rect2(DX0, DY0, DX1 - DX0 + 1, DH) if inside else Rect2(0, 0, 960, 540)
		qs[1].light(4, Vector2.ZERO, 0, 0, 9, mul, add)
		qs[3].light(4, Vector2.ZERO, 0, 0, 9, mul, add)
		if carrying:
			var cy := y + int(sz.y) + 2
			qs[0].light(1, Vector2(x, cy + 6), 0.15, 0, 9, mul, add)
			life.piece(qs[0], "crate", x - 7, cy)
			for cx: int in [x - 5, x + 5]:
				for yy in range(y + int(sz.y) - 1, cy):
					qs[1].px(cx, yy, P.c8(30, 32, 36))
		qs[2].light(1, Vector2(x, y + 4), 0.35, 0, 9, mul, add)
		life.piece(qs[2], n, x - int(sz.x) / 2, y)
		if int(t * 3.0) % 2 == 0 and x >= 2 and x < 950 and y + 2 >= 0:
			qs[3].px(x - int(sz.x) / 2 + 1, y + 2, P.c8(255, 70, 60))
			qs[3].px(x + int(sz.x) / 2 - 1, y + 2, P.c8(90, 255, 140))


# ------------------------------------------------------------------ the crane on its bridge, and its cargo drones (upper11)
func _crane(t: float, f: int, lk: float) -> void:
	var cr := F.crane(t)
	var K := F.K
	var pd: Dictionary = K["parts"][str(cr.part)]
	# the wrecked part, lit from above by the lamps' mean (upper11._draw_load)
	var sw := F.pyround(clampf(cr.sway / 4.0, -1.0, 1.0) * 4.0) / 4.0 * 0.06
	var ld := p[&"load"]
	ld.light(4, Vector2.ZERO, 0, 0, 9, 2.0 * lk * (1.0 + sw))
	life.piece(ld, "part%d_half" % cr.part, cr.lx, cr.ly)
	var bits := p[&"load_bits"]
	var lag := -cr.sway * 0.15 - cr.vel * 0.004
	for cb: Array in pd["cables"]:
		var x0 := cr.lx + int(cb[0])
		var y0 := cr.ly + int(cb[1])
		var ln := int(cb[2])
		var col: Array = cb[3]
		for i in ln + 1:
			var uu := float(i) / ln
			var k := (0.55 + 0.45 * (1.0 - uu)) * lk
			bits.px(F.pyround(x0 + lag * ln * 0.25 * uu * uu), y0 + i, P.c8(float(col[0]) * k, float(col[1]) * k, float(col[2]) * k))
	var emb: Array = ((F.D["tenths"] as Array)[int(t * 10.0) % 300] as Dictionary)["emb"]
	var pe: Array = pd["embers"]
	for i in pe.size():
		var e := int(emb[i]) if i < emb.size() else 0
		if e > 0:
			bits.px(cr.lx + int(pe[i][0]), cr.ly + int(pe[i][1]), P.c8(255, 170, 60) if e == 1 else P.c8(220, 90, 30))
	var c := maxf(0.0, cos(TAU * (1.3 * t + 1.0)))
	bits.rect(cr.lx + cr.lw / 2 - 1, cr.ly - 14, 3, 2, P.c8(255 * (0.35 + 0.65 * c), 170 * (0.35 + 0.65 * c), 60 * (0.35 + 0.65 * c)))
	_rig(cr, lk)
	_drone_rig(t, f, lk)
	# smoke off the burnt part, trailing as it travels (crane8.smoke)
	var sm: Array = pd["smoke"]
	for j in sm.size():
		for i in 7:
			var age := fposmod(t * 0.8 + i / 7.0 + j * 0.37, 1.0)
			var life_s := 2.2 * age
			ShipRoomKorvanLife.puff(p[&"smoke"], cr.lx + float(sm[j][0]) - cr.vel * 0.35 * life_s + 3.0 * sin(i * 1.7 + j),
				cr.ly + float(sm[j][1]) - 14.0 * life_s, 2.0 + 5.0 * age, (1.0 - age) * 0.5)


func _rig(cr: ShipRoomKorvanFilm.Crane, lk: float) -> void:
	var K := F.K
	var tw := int(K["trolley_w"])
	var ty := int(K["trolley_y"])
	var th := int(K["trolley_h"])
	var tx := cr.x - tw / 2
	var tr := p[&"trolley"]
	tr.light(2, Vector2(tx + tw / 2, ty + th / 2), 0.35, 0.4, 1.25, 2.0)
	life.piece(tr, "trolley_half", tx, ty)
	var wh := p[&"rig_wheels"]
	for cx: int in [tx + 9, tx + tw - 10]:
		for dy in range(-3, 3):
			for dx in range(-3, 4):
				var d := Vector2(dx, dy + 0.5).length()
				if d <= 3.2:
					wh.px(cx + dx, 9 + dy, INK if d > 2.4 else (P.c8(150, 156, 166) if dy < 0 else P.c8(70, 74, 84)))
		wh.px(cx, 9, P.c8(200, 204, 210))
	var lit := p[&"rig_lit"]
	var dk := p[&"rig_dark"]
	lit.light(2, Vector2(cr.x, 50), 0.45, 0.5, 1.25, lk)
	var hc := F.pyround(cr.x + cr.sway * 0.25)
	var bt := ty + th + 1
	for cx0: int in [cr.x - 4, cr.x + 4]:
		var a := Vector2(cx0, ty + th - 4)
		var b := Vector2(cx0 + (hc - cr.x), bt)
		var n := int(maxf(maxf(absf(b.x - a.x), absf(b.y - a.y)), 1.0))
		for i in n + 1:
			var v := a + (b - a) * float(i) / n
			var xi := F.pyround(v.x)
			var yi := F.pyround(v.y)
			lit.px(xi, yi, P.c8(150, 156, 166))
			lit.px(xi - 1, yi, P.c8(210, 214, 222))
			dk.px(xi + 1, yi, INK)
	life.piece(lit, "hook_block", hc - 8, bt)
	var hk := bt + 14
	for e: Array in [[0, [0]], [1, [0]], [2, [0]], [3, [-1, 0, 1, 2]], [4, [2]]]:
		for dx: int in e[1]:
			lit.px(hc + dx, hk + int(e[0]), P.c8(200, 204, 212))
	var by := cr.ly - 11
	var bx0 := cr.lx + 6
	var bx1 := cr.lx + cr.lw - 7
	lit.rect(bx0, by, bx1 - bx0 + 1, 1, P.c8(238, 188, 66))
	lit.rect(bx0, by + 1, bx1 - bx0 + 1, 1, P.c8(206, 156, 48))
	lit.rect(bx0, by + 2, bx1 - bx0 + 1, 1, P.c8(150, 110, 34))
	dk.rect(bx0 - 1, by - 1, bx1 - bx0 + 3, 1, INK)
	dk.rect(bx0 - 1, by + 3, bx1 - bx0 + 3, 1, INK)
	for xx in range(bx0, bx1 + 1, 6):
		dk.px(xx, by + 1, P.c8(40, 32, 14))
	for fr: float in [0.06, 0.36, 0.64, 0.94]:
		var gx := F.pyround(bx0 + (bx1 - bx0) * fr)
		for yy in range(by + 4, cr.ly):
			lit.px(gx, yy, P.c8(170, 176, 186) if yy % 2 == 1 else P.c8(70, 74, 82))
			dk.px(gx + 1, yy, INK)
		dk.px(gx, cr.ly, P.c8(110, 116, 124))
	for gx: int in [bx0 + 4, bx1 - 4]:
		var n := int(maxf(absf(gx - hc), absf(by - hk - 3)))
		var side := 1 if gx > hc else -1
		for i in n + 1:
			var u := float(i) / n
			var px := F.pyround(hc + (gx - hc) * u)
			var py := F.pyround(hk + 3 + (by - 1 - hk - 3) * u)
			var cc := P.c8(236, 184, 60) if (i / 4) % 2 == 0 else P.c8(196, 146, 44)
			lit.px(px, py, cc)
			lit.px(px - side, py, Color(cc.r * 0.72, cc.g * 0.72, cc.b * 0.72))
			dk.px(px + side, py, P.c8(36, 28, 12))


func _drone_rig(t: float, f: int, lk: float) -> void:
	var d := F.drones(t)
	if d == null:
		return
	var lx := d.xc - d.lw / 2
	var src := life.src(d.load)
	var half := int(src.size.y) / 2 + (int(src.size.y) % 2)
	var top := p[&"dload_top"]
	var bot := p[&"dload_bot"]
	top.light(2, Vector2(d.xc, d.ly + 4), 0.5, 0.6, 1.2, 1.15 * lk)
	bot.light(2, Vector2(d.xc, d.ly + 4), 0.5, 0.6, 1.2, 0.7 * lk)
	var h := int(src.size.y)
	var cut := 0
	for r in h:
		if float(r) / maxf(1.0, h - 1.0) < 0.5:
			cut = r + 1
	top.sprite(life.atlas, Rect2(src.position, Vector2(src.size.x, cut)), lx, d.ly)
	bot.sprite(life.atlas, Rect2(src.position + Vector2(0, cut), Vector2(src.size.x, h - cut)), lx, d.ly + cut)
	var cl := p[&"dcable"]
	var ci := p[&"dcable_ink"]
	cl.light(2, Vector2(d.xc, d.ly - 10), 0.45, 0.5, 1.25, lk)
	var ends := _cable_ends(d, lx)
	for e: Array in ends:
		var hk: Vector2i = e[0]
		var lg: Vector2i = e[1]
		var a := Vector2(hk)
		var b := Vector2(lg.x, lg.y - 2)
		var n := int(maxf(maxf(absf(b.x - a.x), absf(b.y - a.y)), 1.0))
		for i in n + 1:
			var v := a + (b - a) * float(i) / n
			cl.px(F.pyround(v.x), F.pyround(v.y), P.c8(196, 202, 212))
			cl.px(F.pyround(v.x - 1), F.pyround(v.y), P.c8(84, 90, 100))
		ci.px(lg.x - 1, lg.y - 1, INK)
		cl.px(lg.x, lg.y - 1, P.c8(170, 176, 186))
		ci.px(lg.x + 1, lg.y - 1, INK)
		cl.px(lg.x, lg.y - 2, P.c8(210, 214, 222))
	var prop: Array = ((F.D["frames"] as Array)[f] as Dictionary)["prop"]
	for j in d.d.size():
		var dp: Vector2i = d.d[j]
		var q := p[StringName("drone%d" % j)]
		q.light(2, Vector2(dp), 0.45, 0.5, 1.25, lk)
		life.piece(q, "up_drone", dp.x - 15, dp.y)
		var bq := p[StringName("drone_bits%d" % j)]
		var bitsv := int(prop[j])
		var k := 0
		for x0: int in [dp.x - 14, dp.x + 6]:
			for xx in range(x0, x0 + 8):
				if bitsv & (1 << k):
					bq.px(xx, dp.y + 1, P.c8(150, 160, 170))
				k += 1
		if int(t * 2.5) % 2 == 0:
			bq.px(dp.x - 14, dp.y + 3, P.c8(255, 70, 60))
			bq.px(dp.x + 14, dp.y + 3, P.c8(90, 255, 140))
		bq.rect(maxi(0, dp.x - 1), dp.y + 8, 3, 1, P.c8(255, 244, 220))
		for e: Array in ends:
			var hk: Vector2i = e[0]
			if absi(hk.x - dp.x) <= 4:
				bq.px(hk.x, hk.y, P.c8(200, 204, 212))
				bq.px(hk.x, hk.y - 1, P.c8(60, 64, 72))


## upper11.cable_ends: [hook, lug] per cable, the lugs on the load's own top edge.
func _cable_ends(d: ShipRoomKorvanFilm.Drones, lx: int) -> Array[Array]:
	var lugs: Array = F.K["up_load"]["lugs_small0" if d.pair else "lugs_crate"]
	var lp: Array[Vector2i] = []
	for l: Array in lugs:
		lp.append(Vector2i(lx + int(l[0]), d.ly + int(l[1])))
	var out: Array[Array] = []
	for j in d.d.size():
		var dp: Vector2i = d.d[j]
		if d.pair:
			out.append([Vector2i(dp.x + (3 if j == 0 else -3), dp.y + 9), lp[j]])
		else:
			for k in lp.size():
				out.append([Vector2i(dp.x + (-2 if k == 0 else 2), dp.y + 9), lp[k]])
	return out
