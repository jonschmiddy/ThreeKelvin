class_name ShipRoomSolariCrew
extends RefCounted

## The casting bed's people, as show18 and handlers.py move them: the plate handlers at the wall
## foot (feet on row 212), and in front of the hulls the lamp tech, the fettler, the welder, two carriers.
## Why: docs/why/ShipRoomSolari.md#crew

const C := preload("res://scripts/ui/ShipRoomSolariCycle.gd")
const B := preload("res://scripts/ui/ShipRoomSolariBed.gd")
const YARD := "res://art/sprites/station/yard/"
# handlers.py
const PACE := 7.8
const ADV := 1.5
const LAND := Vector2(23.7, 24.7)
const GAP := 30
const PLATE_TOP := C.FLOOR - 23
const PLATE_LOAD := C.FLOOR - 15
const SHOULDER := C.FLOOR - 14
const DOORS: Array[int] = [287, 377, 560, 748, 920]
const PLATE_COLS: Array[Color] = [Color(0.690, 0.416, 0.196), Color(0.478, 0.282, 0.149), Color(0.361, 0.216, 0.122),
	Color(0.361, 0.216, 0.122), Color(0.361, 0.216, 0.122), Color(0.361, 0.216, 0.122), Color(0.275, 0.173, 0.110),
	Color(0.024, 0.008, 0.004)]
const ARM_C := Color8(70, 62, 62)
const HAND := Color8(236, 170, 130)
const INK := Color8(24, 15, 10)
const BRASS := Color8(150, 96, 50)
const IRON := Color8(60, 44, 32)
# the front lane (show18)
const LAMP_TECH := [["at", 430, -0.01, -1], ["stand", 3.0], ["walk", 486], ["stand", 4.5], ["walk", 530],
	["stand", 6.0], ["walk", 430], ["stand", 30.0]]
const CARRY1 := [["at", 96, -0.01, 1], ["walk", 272], ["stand", 3.0], ["walk", 96], ["stand", 30.0]]
const CARRY2 := [["at", 905, -0.01, -1], ["stand", 4.0], ["walk", 812], ["stand", 6.0], ["walk", 905], ["stand", 30.0]]
const LIFT_X := 764
const LANE := 388
const LIFT_RISE := 26
const GRIND_X := 290
const GRIND_FEET := 302
const BEAM_COL := Color(1.0, 226.0 / 255.0, 172.0 / 255.0)

var meta: Dictionary = {}
var _tex: Dictionary[StringName, Texture2D] = {}
var _belly: Dictionary = {}
## Each front-lane look's frames as silhouettes: per frame, per row, its opaque columns.
var _sil: Dictionary[StringName, Array] = {}
var _gspark: ShipRoomSolariFx.Sparks
var _wspark: ShipRoomSolariFx.Sparks


func _init(r: ShipRoomSolari) -> void:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(YARD + "yard.json"))
	meta = (d as Dictionary).get("art", {}) if d is Dictionary else {}
	for look: String in ["t_loader", "look_rigger", "look_loader"]:
		_tex[StringName(look)] = load(YARD + str(meta.crew[look].picture)) as Texture2D
	_tex[&"welder"] = _cool_strip(load(YARD + str(meta.life.welder_strip.picture)) as Texture2D, true)
	_tex[&"welder_hot"] = load(YARD + str(meta.life.welder_strip.picture)) as Texture2D
	_tex[&"tech_raised"] = _cool_strip(_tex[&"look_rigger"], false)
	_tex[&"lift"] = _lift_tex(load(YARD + str(meta.lifts.unclaimed.picture)) as Texture2D)
	_belly = r.layout.get("solari", {}).get("belly_rows", {})
	for look: StringName in [&"look_rigger", &"look_loader", &"tech_raised"]:
		_sil[look] = _silhouettes(_tex.get(look), 8)
	_gspark = ShipRoomSolariFx.Sparks.new(7, 70.0, Vector2(0.3, 0.8), 300.0, 0.35)
	_wspark = ShipRoomSolariFx.Sparks.new(31, 36.0, Vector2(0.35, 0.9), 240.0, 0.3)


## The welder's strip with the torch's hot pixels cooled (the fettler grinds dark), or the rigger's
## with his hanging hand painted out (the lamp tech's raised arm is drawn on).
static func _cool_strip(src: Texture2D, welder: bool) -> Texture2D:
	if src == null:
		return null
	var img := src.get_image()
	if img == null:
		return src
	img = img.duplicate() as Image
	img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var fh := img.get_height()
	for y in fh:
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a8 == 0 or c.r8 <= (200 if welder else 180) or c.g8 <= 120:
				continue
			if welder:
				img.set_pixel(x, y, Color8(70, 66, 62))
			elif y >= 22:
				img.set_pixel(x, y, Color8(58, 50, 52))
	return ImageTexture.create_from_image(img)


## Per frame of a strip, per row, the opaque columns (the wall shadow's source).
static func _silhouettes(src: Texture2D, frames: int) -> Array[Array]:
	var out: Array[Array] = []
	if src == null:
		return out
	var img := src.get_image()
	if img == null:
		return out
	img = img.duplicate() as Image
	img.decompress()
	var fw := img.get_width() / frames
	for f in frames:
		var rows: Array[PackedInt32Array] = []
		for y in img.get_height():
			var cols := PackedInt32Array()
			for c in fw:
				if img.get_pixel(f * fw + c, y).a > 0.0:
					cols.append(c)
			rows.append(cols)
		out.append(rows)
	return out


## draw_lift's scissor lift, raised 26 rows: its base, the scissors repeated, its deck on top.
static func _lift_tex(src: Texture2D) -> Texture2D:
	if src == null:
		return null
	var a := src.get_image()
	if a == null:
		return src
	a = a.duplicate() as Image
	a.decompress()
	a.convert(Image.FORMAT_RGBA8)
	var out := Image.create(a.get_width(), a.get_height() + LIFT_RISE, false, Image.FORMAT_RGBA8)
	out.blit_rect(a, Rect2i(0, 11, a.get_width(), a.get_height() - 11), Vector2i(0, LIFT_RISE + 11))
	var y := LIFT_RISE + 11
	var rows := LIFT_RISE
	while rows > 0:
		var hh := mini(14, rows)
		y -= hh
		out.blit_rect(a, Rect2i(0, 25 - hh, a.get_width(), hh), Vector2i(0, y))
		rows -= hh
	out.blit_rect(a, Rect2i(0, 0, a.get_width(), 11), Vector2i(0, 0))
	return ImageTexture.create_from_image(out)


# ------------------------------------------------------------------ walking (ideas.walker_at)
## Where a walker is: x, the stride frame, facing left.
class Pose:
	var x := 0.0
	var fr := 0
	var flip := false

	func _init(x_: float, fr_: int, flip_: bool) -> void:
		x = x_
		fr = fr_
		flip = flip_


## A walker on a plan [at x t0 dir], [walk x1], [stand secs]: one pose per `advance` px.
func walker_at(look: String, plan: Array, t: float) -> Pose:
	var m: Dictionary = meta.crew[look]
	var adv := float(m.advance)
	var pace := float(m.pace)
	var x := float(plan[0][1])
	var tt := float(plan[0][2])
	var d := int(plan[0][3]) if plan[0].size() > 3 else 1
	for i in range(1, plan.size()):
		var p: Array = plan[i]
		if p[0] == "walk":
			var dist := absf(float(p[1]) - x)
			var dur := dist / pace
			if t >= tt and t < tt + dur:
				var steps := floorf(pace * (t - tt) / adv)
				var u := minf(1.0, steps * adv / maxf(1e-6, dist))
				d = 1 if float(p[1]) >= x else -1
				return Pose.new(x + (float(p[1]) - x) * u, int(steps) % 8, d < 0)
			d = 1 if float(p[1]) >= x else -1
			x = float(p[1])
			tt += dur
		else:
			if t >= tt and t < tt + float(p[1]):
				return Pose.new(x, 0, d < 0)
			tt += float(p[1])
	return Pose.new(x, 0, d < 0)


func _frame(ci: CanvasItem, look: StringName, fr: int, flip: bool, x: int, y: int, mod: Color = Color.WHITE) -> void:
	var tx: Texture2D = _tex.get(look)
	if tx == null:
		return
	var fw := tx.get_width() / int(meta.crew[String(look)].frames) if meta.crew.has(String(look)) else 21
	var fh := tx.get_height()
	if flip:
		ci.draw_set_transform(Vector2(x + fw, y), 0.0, Vector2(-1, 1))
		ci.draw_texture_rect_region(tx, Rect2(0, 0, fw, fh), Rect2(fr * fw, 0, fw, fh), mod)
		ci.draw_set_transform(Vector2.ZERO)
	else:
		ci.draw_texture_rect_region(tx, Rect2(x, y, fw, fh), Rect2(fr * fw, 0, fw, fh), mod)


## kit.contact: an oval under a thing's feet, darkest at the foot, its rim ordered-dithered; it only darkens.
static func contact(ci: CanvasItem, x0: int, x1: int, feet: int, length: int, dark: float) -> void:
	var cx := (x0 + x1) / 2.0
	var rx := maxf(2.0, (x1 - x0) / 2.0 + 3.0)
	var ry := maxf(2.0, float(length))
	for dy in range(-1, length + 1):
		var y := feet + dy
		for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
			var r := sqrt(pow((x - cx) / rx, 2.0) + pow((dy + 1) / (ry + 1.0), 2.0))
			var k := clampf(1.0 - r, 0.0, 1.0)
			if k > 0.35 or (k > 0.0 and ShipRoom.bayer4(x, y) < k / 0.35):
				B.px(ci, x, y, Color(1.0 - dark * clampf(0.45 + k, 0.0, 1.0), 0, 0, B.SHADE))


## handlers.shadow: the floor row under feet or a wheel darkened, softer at its ends.
static func floor_shadow(ci: CanvasItem, cx: float, half: int) -> void:
	var c := int(roundf(cx))
	for x in range(c - half - 1, c + half + 2):
		B.px(ci, x, C.FLOOR + 1, Color(0.55 if absi(x - c) <= half else 0.8, 0, 0, B.SHADE))
		if absi(x - c) <= half - 1:
			B.px(ci, x, C.FLOOR + 2, Color(0.8, 0, 0, B.SHADE))


# ------------------------------------------------------------------ the plate handlers (handlers.py)
## A bay's handling this frame: who stands where, the trolleys (x, loaded), the plate sliding, the arms.
class Handling:
	var handlers: Array[Pose] = []
	var trolleys: Array[Vector2] = []
	var slide_x := NAN
	## [kind, xa, xb, row]: "push", "steady", "chalk", "handle"
	var arms: Array[Array] = []


static func _walk(x0: float, x1: float, t0: float, t: float) -> Pose:
	var dist := absf(x1 - x0)
	if t <= t0:
		return Pose.new(x0, -1, false)
	if t >= t0 + dist / PACE:
		return Pose.new(x1, -1, false)
	var steps := int(PACE * (t - t0) / ADV)
	return Pose.new(x0 + signf(x1 - x0) * minf(dist, steps * ADV), steps % 8, x1 < x0)


## The last leg begun by t, [t0, x0, x1, face when still]: a pose, or null before the first.
static func _seq(legs: Array, t: float) -> Pose:
	var cur: Array = []
	for leg: Array in legs:
		if t >= float(leg[0]):
			cur = leg
	if cur.is_empty():
		return null
	var p := _walk(float(cur[1]), float(cur[2]), float(cur[0]), t)
	if p.fr < 0:
		return Pose.new(p.x, 0, float(cur[3]) < 0.0)
	return p


## This cycle's handling plus the last cycle's pair still going out (they pass in the doorway).
static func handling(j: int, u: float) -> Handling:
	var o := Handling.new()
	_handle(j, u, u, false, o)
	_handle(j, u, u + 30.0, true, o)
	return o


static func _handle(j: int, u: float, ue: float, tail: bool, o: Handling) -> void:
	var X := C.stack_x(j)
	if X < 0:
		return
	var D := 377 if j == 2 else DOORS[0]
	if j != 2:
		for dx in DOORS:
			if absi(dx - X) < absi(D - X):
				D = dx
	var dd := 1 if D > X else -1
	var d := -dd if absi(D - X) < 44 else dd
	var cX := X + d * GAP
	var A0 := X - d * 14
	var A1 := X + d * 16
	var AS := X + d * 14
	var t_park := 14.0
	var s0 := 16.0
	var t_push := maxf(28.8, 25.8 + absi(AS - (cX - dd * 13)) / PACE + 0.1)
	var slide_end := s0 + GAP / PACE
	var tB0 := t_park - absi(cX - D) / PACE
	var tA0 := s0 - absi(A0 - D) / PACE - 0.1
	var out_end := t_push + (absi(D - cX) + 14) / PACE
	if ue < minf(tA0, tB0) or ue > out_end or (tail and ue < 30.0):
		return
	var tx := float(D)
	if ue >= tB0 and ue < t_park:
		tx = _walk(D, cX, tB0, ue).x
	elif ue >= t_park and ue < t_push:
		tx = cX
	elif ue >= t_push:
		tx = _walk(cX, D, t_push, ue).x
	var n0 := o.handlers.size()
	var rb := _seq([[tB0, D + dd * 13, cX + dd * 13, -dd], [slide_end + 0.2, cX + dd * 13, AS, -d],
		[25.8, AS, cX - dd * 13, dd], [t_push, cX - dd * 13, D - dd * 13, dd]], ue)
	if rb != null and (rb.x - D) * dd < 0:
		o.handlers.append(rb)
	var ra := _seq([[tA0, D, A0, d], [s0, A0, A1, d], [slide_end + 0.1, A1, A0, d], [25.8, A0, D, dd]], ue)
	if ra != null and ((ra.x - D) * dd < 0 or (ue < 25.8 and absf(ra.x - D) > 0.5)):
		o.handlers.append(ra)
	if (tx - D) * dd < 0:
		o.trolleys.append(Vector2(tx, 1.0 if ue >= slide_end else 0.0))
	if not tail:
		if ue >= s0 and ue < slide_end and ra != null:
			o.slide_x = ra.x + d * 14
			o.arms.append(["push", ra.x + d * 3, ra.x + d * 4, PLATE_LOAD - 2])
		if ue >= LAND.x and ue < LAND.y:
			o.arms.append(["steady", X + d * 11, 0, 0])
			o.arms.append(["steady", X - d * 11, 0, 0])
		if ue >= 25.0 and ue < 25.8:
			o.arms.append(["chalk", X + d * 11, X + d * 9, PLATE_TOP + 4])
	if ue >= t_push and (tx - D) * dd < 0 and rb != null and (rb.x - D) * dd < 0:
		o.arms.append(["handle", rb.x + dd * 3, tx - dd * 11, PLATE_LOAD - 1])
	if not tail and ue >= slide_end + 0.5 and ue < LAND.x:
		for k in range(n0, o.handlers.size()):
			var h := o.handlers[k]
			if h.fr == 0 and int((ue + 0.8 * (k - n0) + 0.3 * j) / 1.7) % 2 != 0:
				h.flip = not h.flip


static func chalk_top(_j: int, u: float) -> bool:
	return u >= 25.4 or u < 16.0


## Every bay's handlers, trolleys and plates, in show18's order (after the moulds, before the jibs).
func paint_wall(ci: CanvasItem, t: float) -> void:
	var tl := fposmod(t, C.LOOP)
	for j in 6:
		var u := C.u_of(j, tl)
		var o := handling(j, u)
		for tr in o.trolleys:
			_trolley(ci, int(roundf(tr.x)))
			if tr.y > 0.5:
				_plate(ci, int(roundf(tr.x)), true)
		if not is_nan(o.slide_x):
			_plate(ci, int(roundf(o.slide_x)), true)
		for h in o.handlers:
			var fw := 9
			_frame(ci, &"t_loader", h.fr, h.flip, int(roundf(h.x)) - fw / 2, C.FLOOR + 1 - 19, Color(0.9, 0.9, 0.9))
			floor_shadow(ci, h.x, 2)
		var hy := C.jib_state(u).hy
		for a in o.arms:
			var xa := int(roundf(float(a[1])))
			if a[0] == "steady":
				var bot := hy + C.PLATE_H
				if bot + 1 >= SHOULDER - 8:
					B.px(ci, xa, bot + 1, ARM_C, 1, SHOULDER - bot - 1)
					B.px(ci, xa, bot + 1, HAND)
			else:
				var xb := int(roundf(float(a[2])))
				B.px(ci, mini(xa, xb), int(a[3]), ARM_C, absi(xb - xa) + 1)
				B.px(ci, xb, int(a[3]), HAND)


func _plate(ci: CanvasItem, x: int, chalk: bool) -> void:
	for r in PLATE_COLS.size():
		B.px(ci, x - 10, PLATE_TOP + r, PLATE_COLS[r], 20)
		B.px(ci, x - 10, PLATE_TOP + r, Color8(6, 2, 1))
		B.px(ci, x + 9, PLATE_TOP + r, Color8(6, 2, 1))
	if chalk:
		B.px(ci, x - 3, PLATE_TOP + 3, B.CHALK, 3)
		B.px(ci, x - 1, PLATE_TOP + 4, B.CHALK)


## A plate trolley: its deck at the third plate's height, four legs, two wheels on the floor line.
func _trolley(ci: CanvasItem, c: int) -> void:
	B.px(ci, c - 11, PLATE_LOAD, BRASS, 22)
	B.px(ci, c - 11, PLATE_LOAD + 1, INK, 22)
	for lx: int in [c - 10, c + 9]:
		B.px(ci, lx, PLATE_LOAD + 2, INK, 1, C.FLOOR - 2 - PLATE_LOAD - 2)
		B.px(ci, lx + (1 if lx < c else -1), PLATE_LOAD + 2, IRON, 1, C.FLOOR - 2 - PLATE_LOAD - 2)
	for wx: int in [c - 11, c + 8]:
		B.px(ci, wx, C.FLOOR - 2, INK, 3, 3)
		B.px(ci, wx + 1, C.FLOOR - 1, BRASS)
		floor_shadow(ci, wx + 1, 2)
	for hx: int in [c - 12, c + 11]:
		B.px(ci, hx, PLATE_TOP + 1, INK, 1, PLATE_LOAD - PLATE_TOP)
		B.px(ci, hx, PLATE_TOP, BRASS)


# ------------------------------------------------------------------ in front of the hulls (show18.front)
## The welder's state on its 10 s clock: [strip frame, welding].
static func weld_state(t: float) -> Array[int]:
	t = fposmod(t, 10.0)
	var seq := [[0.0, 0.4, "raise"], [0.4, 3.9, "weld"], [3.9, 4.3, "lower"], [4.3, 5.4, "rest"],
		[5.4, 5.8, "raise"], [5.8, 9.6, "weld"], [9.6, 10.0, "lower"]]
	for s: Array in seq:
		if t >= float(s[0]) and t < float(s[1]):
			var u := (t - float(s[0])) / (float(s[1]) - float(s[0]))
			match s[2]:
				"weld":
					return [[0, 1, 2, 1][int(t * 8.0) % 4], 1]
				"raise":
					return [5 - mini(2, int(u * 3.0)), 0]
				"lower":
					return [3 + mini(2, int(u * 3.0)), 0]
	return [5, 0]


static func grind_on(t: float) -> bool:
	t = fposmod(t, 10.0)
	for ab: Vector2 in [Vector2(0.2, 2.0), Vector2(2.6, 4.6), Vector2(5.4, 7.6), Vector2(8.2, 9.8)]:
		if t >= ab.x and t < ab.y:
			return true
	return false


func weld_feet() -> int:
	var ls: Dictionary = meta.lifts.unclaimed
	return LANE - int(ls.foot) + int(ls.deck) - LIFT_RISE


func weld_tip(fr: int) -> Vector2i:
	var f: Dictionary = meta.life.welder_strip.frames[fr]
	var x := LIFT_X - 4 - float(f.cx) + float(f.tip[0])
	var y := weld_feet() - float(f.foot) + float(f.tip[1])
	return Vector2i(int(roundf(x)), int(roundf(y)))


func belly_row(x: int) -> int:
	return int(_belly.get(str(x), 270))


## The crew's light this frame: the arc, the grinder, the lamp tech's lamp, and the walkers as
## shadow sheets (x0, x1, z, height) in the pours' and the roar's light.
func light_state(t: float, r: ShipRoomSolari) -> Dictionary[StringName, Variant]:
	var tl := fposmod(t, C.LOOP)
	var out: Dictionary[StringName, Variant] = {&"arc_i": -1, &"arc_w": 0.0, &"grind_w": 0.0, &"tech_i": -1}
	var ws := weld_state(tl)
	if ws[1] == 1:
		var fl: float = [0.8, 0.9, 1.0][int(C.hash1([9, int(tl * 8.0)]) * 3.0)]
		var tip := weld_tip(ws[0])
		r.hull_light(tip.x, tip.y, 130, ShipRoomSolari.ARC, 1.3 * fl)
		out[&"arc_i"] = mini(2, ws[0])
		out[&"arc_tip"] = Vector2(tip)
		out[&"arc_w"] = fl
	if grind_on(tl):
		var b: float = [0.85, 0.95, 1.05][int(C.hash1([77, int(tl * 8.0)]) * 3.0)]
		r.hull_light(GRIND_X + 4, GRIND_FEET - 27, 70, ShipRoomSolari.FIRE, b)
		out[&"grind_w"] = b
	var tp := walker_at("look_rigger", LAMP_TECH, tl)
	var spots := [430, 486, 530]
	for i in 3:
		if absf(tp.x - spots[i]) < 0.5:
			out[&"tech_i"] = i
			var bx := int(roundf(tp.x)) + (-1 if tp.flip else 1) * 26
			r.hull_light(bx, belly_row(bx), 50, Color(1.0, 0.95, 0.82), 0.8)
	var ppl := PackedVector4Array()
	for plan: Array in [CARRY1, CARRY2]:
		var cx := int(roundf(walker_at("look_loader", plan, tl).x))
		ppl.append(Vector4(cx - 3, cx + 3, 391, 42))
	var tx := int(roundf(tp.x))
	ppl.append(Vector4(tx - 3, tx + 3, 335, 41))
	out[&"people"] = ppl
	return out


## The grinder's and the arc's sparks: births since the last frame, and their flight.
func step(t: float, dt: float) -> void:
	var tl := fposmod(t, C.LOOP)
	var tip := Vector2(GRIND_X + 4, GRIND_FEET - 27)
	_gspark.step(t, dt, grind_on(tl), tip + Vector2(1.5, 0.5), _grind_v, _lane_floor)
	var ws := weld_state(tl)
	_wspark.step(t, dt, ws[1] == 1, Vector2(weld_tip(ws[0])) + Vector2(0.5, 0.5), _weld_v, _weld_floor)


func _grind_v(h1: float, h2: float) -> Vector2:
	var a := deg_to_rad(-40.0 + 120.0 * h1)
	var v := 50.0 + 90.0 * h2
	return Vector2(-cos(a) * v * 0.6 - 10.0, sin(a) * v)


func _lane_floor(_x: float) -> float:
	return float(LANE)


func _weld_v(h1: float, h2: float) -> Vector2:
	return Vector2(-34.0 + 68.0 * h1, -30.0 + 34.0 * h2)


func _weld_floor(x: float) -> float:
	return float(weld_feet()) if absf(x - LIFT_X) < 20.0 else float(LANE)


## Everyone in front of the hulls, in foot-row order, lit at their own pixels (FRONT: rgb x m).
func paint_front(ci: CanvasItem, t: float, m_at: Callable) -> void:
	var tl := fposmod(t, C.LOOP)
	var ls: Dictionary = meta.lifts.unclaimed
	var lx0 := int(LIFT_X - float(ls.cx) + float(ls.x0))
	contact(ci, lx0 + 4, lx0 + int(ls.x1) - int(ls.x0) - 4, LANE - 1, 3, 0.35)
	contact(ci, 291, 301, 387, 3, 0.4)
	var tp := walker_at("look_rigger", LAMP_TECH, tl)
	var carriers: Array[Pose] = [walker_at("look_loader", CARRY1, tl), walker_at("look_loader", CARRY2, tl)]
	for p in carriers:
		contact(ci, int(roundf(p.x)) - 3, int(roundf(p.x)) + 3, 391, 3, 0.45)
	contact(ci, int(roundf(tp.x)) - 3, int(roundf(tp.x)) + 3, 335, 3, 0.45)
	var shining := false
	for sx: int in [430, 486, 530]:
		shining = shining or absf(tp.x - sx) < 0.5
	var tlook: StringName = &"tech_raised" if shining else &"look_rigger"
	_frame(ci, tlook, tp.fr, tp.flip, int(roundf(tp.x)) - 10, 336 - 41)
	wall_shadow(ci, tlook, tp, 21, 336, m_at)
	if shining:
		_beam(ci, tp)
	else:
		B.px(ci, int(roundf(tp.x)) + (-6 if tp.flip else 6), 336 - 26, B.glow(Color8(200, 180, 140)))
	_fettler(ci, tl)
	_welder(ci, tl)
	for p in carriers:
		_frame(ci, &"look_loader", p.fr, p.flip, int(roundf(p.x)) - 10, 392 - 44)
		wall_shadow(ci, &"look_loader", p, 21, 392, m_at)


func _frame_strip(ci: CanvasItem, key: StringName, fr: int, x: int, y: int) -> void:
	var tx: Texture2D = _tex.get(key)
	if tx != null:
		ci.draw_texture_rect_region(tx, Rect2(x, y, 32, 40), Rect2(fr * 32, 0, 32, 40))


## The fettler on his ladder at the light hull's nose, grinding in bursts, sparks off the wheel.
func _fettler(ci: CanvasItem, tl: float) -> void:
	var rail := Color(120.0 / 255.0, 86.0 / 255.0, 52.0 / 255.0, 0.75)
	var rung := Color(96.0 / 255.0, 68.0 / 255.0, 42.0 / 255.0, 0.75)
	var n := 388 - 262
	for i in n + 1:
		var y := 388 - i
		var xc := 296 + (288 - 296) * float(i) / n
		for side: int in [-5, 5]:
			var x := int(roundf(xc + side))
			B.px(ci, x, y, rail)
			B.px(ci, x + (1 if side > 0 else -1), y, Color8(22, 15, 10))
		if i % 6 == 3:
			B.px(ci, int(roundf(xc - 4)), y, rung, int(roundf(xc + 4)) - int(roundf(xc - 4)) + 1)
	var on := grind_on(tl)
	var fr: int = [6, 7, 8, 7][int(tl * 8.0) % 4] if on else 6
	_frame_strip(ci, &"welder", fr, GRIND_X - 16, GRIND_FEET - 38)
	var tip := Vector2(GRIND_X + 4, GRIND_FEET - 27)
	if on:
		B.px(ci, int(tip.x), int(tip.y), B.glow(Color8(255, 214, 140)), 2)
	_gspark.draw(ci)


## The welder on his raised lift under the medium, the arc's white point and its sparks.
func _welder(ci: CanvasItem, tl: float) -> void:
	var ls: Dictionary = meta.lifts.unclaimed
	var lt: Texture2D = _tex.get(&"lift")
	if lt != null:
		var left := int(roundf(LIFT_X - float(ls.cx)))
		ci.draw_texture(lt, Vector2(left, LANE - int(ls.foot) - LIFT_RISE))
	var ws := weld_state(tl)
	var f: Dictionary = meta.life.welder_strip.frames[ws[0]]
	var x := int(roundf(LIFT_X - 4 - float(f.cx)))
	var y := weld_feet() - int(f.foot)
	_frame_strip(ci, &"welder_hot" if ws[1] == 1 else &"welder", ws[0], x, y)
	var tip := weld_tip(ws[0])
	if ws[1] == 1:
		B.px(ci, tip.x, tip.y, B.glow(Color.WHITE))
		var tk := int(tl * 10.0)
		var nn := 3 + int(C.hash1([1000, tk]) * 4.0)
		for k in nn:
			var ddx := int(C.hash1([1001, tk, k]) * 7.0) - 3
			var ddy := int(C.hash1([1002, tk, k]) * 5.0) - 3
			B.px(ci, tip.x + ddx, tip.y + ddy, B.glow(Color8(205, 225, 255)))
	_wspark.draw(ci)


## Where the lamp tech's lamp is and where its beam lands: (lens x, y, spot x, y).
func beam_geom(tp: Pose) -> Vector4:
	var d := -1 if tp.flip else 1
	var sx0 := int(roundf(tp.x)) - 10 + (11 if tp.flip else 9)
	var sy0 := 336 - 41 + 14
	var spx := int(roundf(tp.x)) + d * 26
	var spy := belly_row(spx)
	var a := rad_to_deg(atan2(sy0 - spy, absi(spx - sx0)))
	var aim := deg_to_rad(72.0 if a > 64.0 else (57.0 if a > 48.0 else 42.0))
	return Vector4(sx0, sy0, d * cos(aim), -sin(aim))


## Korvan's flashlight on the heavy: the raised arm along the aim, the lamp's barrel and lens.
func _beam(ci: CanvasItem, tp: Pose) -> void:
	var g := beam_geom(tp)
	var k := 1.0
	while k < 10.5:
		B.px(ci, int(roundf(g.x + g.z * k)) - 1, int(roundf(g.y + g.w * k)) - 1, B.glow(Color8(18, 14, 16)), 3, 3)
		k += 0.5
	k = 1.0
	while k < 10.5:
		var xi := int(roundf(g.x + g.z * k))
		var yi := int(roundf(g.y + g.w * k))
		B.px(ci, xi, yi, B.glow(Color8(106, 96, 94)))
		B.px(ci, xi, yi + 1, B.glow(Color8(70, 62, 62)))
		k += 0.5
	B.px(ci, int(roundf(g.x + g.z * 10.5)), int(roundf(g.y + g.w * 10.5)), B.glow(Color8(236, 170, 130)), 1, 2)
	k = 11.5
	while k < 14.5:
		B.px(ci, int(roundf(g.x + g.z * k)), int(roundf(g.y + g.w * k)), B.glow(Color8(40, 40, 46)))
		k += 0.5
	B.px(ci, int(roundf(g.x + g.z * 15.0)), int(roundf(g.y + g.w * 15.0)), B.glow(Color8(255, 248, 222)))


## The beam's light, added: a cone widening and fading from the lens, ending column by column at
## the plating; the spot there, stepped in three; the lens's small glow.
func paint_beam_light(ci: CanvasItem, t: float) -> void:
	var tp := walker_at("look_rigger", LAMP_TECH, fposmod(t, C.LOOP))
	var shining := false
	for sx: int in [430, 486, 530]:
		shining = shining or absf(tp.x - sx) < 0.5
	if not shining:
		return
	var g := beam_geom(tp)
	var lx := int(roundf(g.x + g.z * 15.0))
	var ly := int(roundf(g.y + g.w * 15.0))
	var spx := int(roundf(tp.x)) + (-1 if tp.flip else 1) * 26
	var spy := belly_row(spx)
	var n := maxi(1, ly - spy)
	for i in range(1, n + 1):
		var u := float(i) / n
		var y := ly - i
		var cx := lx + (spx - lx) * u
		var half := 0.5 + 6.5 * u
		for x in range(int(cx - half - 1), int(cx + half + 2)):
			if y <= _cover(x):
				continue
			var dd := absf(x - cx) / half
			var kk := 0.30 if dd < 0.45 else (0.13 if dd < 1.0 else 0.0)
			if kk > 0.0:
				B.px(ci, x, y, _lit(kk * (1.0 - 0.45 * u)))
	for y in range(spy - 9, spy + 2):
		for x in range(spx - 17, spx + 18):
			if y > _cover(x):
				continue
			var dd := Vector2((x - spx) / 16.0, (y - spy) / 6.5).length()
			var w := 0.9 if dd < 0.38 else (0.5 if dd < 0.72 else (0.22 if dd < 1.0 else 0.0))
			if w > 0.0:
				B.px(ci, x, y, _lit(w * 0.45))
	for yy in range(ly - 2, ly + 3):
		for xx in range(lx - 2, lx + 3):
			var r := Vector2(xx - lx, yy - ly).length()
			if r > 0.0 and r <= 2.3:
				B.px(ci, xx, yy, _lit(0.35 if r < 1.5 else 0.15))


static func _lit(k: float) -> Color:
	return Color(BEAM_COL.r * k, BEAM_COL.g * k, BEAM_COL.b * k, 1.0)


## The heavy's underside row at a column, or -1 where it has none.
func _cover(x: int) -> int:
	return int(_belly.get(str(x), -1))


## show20.wall_shadow (Jon: "This guy's shadow is weird"): one shadow from the furnace wall behind a
## walker, his pose's silhouette flipped and flattened onto the floor (0.4 of his height) from his feet,
## leaning away from the nearest furnace (at most 0.5 px a row), x0.5 near and x0.72 far, as strong as
## the floor's light at his feet.
func wall_shadow(ci: CanvasItem, look: StringName, p: Pose, w: int, feet: int, m_at: Callable) -> void:
	var frames: Array = _sil.get(look, [])
	if p.fr >= frames.size():
		return
	var sil: Array = frames[p.fr]
	var rows: Array[int] = []
	for r in sil.size():
		if not (sil[r] as PackedInt32Array).is_empty():
			rows.append(r)
	if rows.is_empty():
		return
	var x_left := int(roundf(p.x)) - w / 2
	var cx := x_left + w / 2.0
	var tn := C.TAPS[0]
	for tt in C.TAPS:
		if absf(tt - cx) < absf(tn - cx):
			tn = tt
	var lean := clampf((cx - tn) / 240.0, -0.5, 0.5)
	var m: Vector3 = m_at.call(clampi(int(cx), 0, ShipRoom.W - 1), mini(ShipRoom.H - 1, feet))
	var lv := clampf(((m.x + m.y + m.z) / 3.0 - 0.15) / 0.7, 0.0, 1.0)
	if lv <= 0.05:
		return
	var sh_h := maxi(2, int(roundf(0.4 * rows.size())))
	for k in sh_h:
		var src := rows[-1] - int(k / 0.4)
		if src < rows[0]:
			break
		var dx := int(roundf(lean * k))
		var kk := 1.0 - (0.28 if k >= sh_h / 2 else 0.5) * lv
		for c in sil[src] as PackedInt32Array:
			var cc := w - 1 - c if p.flip else c
			B.px(ci, x_left + cc + dx, feet + k, Color(kk, 0, 0, B.SHADE))
