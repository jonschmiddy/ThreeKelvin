class_name ShipRoomSolariBed
extends RefCounted

## The casting bed's life, as show18 draws it into the room: the moulds filling and cooling, the
## white-core streams and their crowns, the spouts' lips, the stacks, the jibs, the drone, the beacon.
## Painted into a layer lit as the room's albedo (`ShipRoomSolari.Mode.BACK`): a pixel whose colour
## has alpha GLOW burns unlit (the film's emissive), one with alpha SHADE multiplies what is under it.
## Why: docs/why/ShipRoomSolari.md#cycle

const C := preload("res://scripts/ui/ShipRoomSolariCycle.gd")
const GLOW := 0.5
const SHADE := 0.25
const INK := Color8(18, 11, 8)
const RAMP: Array = [[0.93, Color8(255, 247, 220)], [0.83, Color8(255, 226, 150)], [0.72, Color8(255, 190, 88)],
	[0.60, Color8(244, 146, 50)], [0.48, Color8(218, 104, 34)], [0.36, Color8(178, 68, 24)],
	[0.26, Color8(140, 48, 20)], [0.16, Color8(106, 38, 19)]]
const PLATE_ROWS: Array[Color] = [Color8(176, 106, 50), Color8(96, 57, 32), Color8(66, 42, 27)]
const STREAM: Array[Color] = [Color8(255, 253, 240), Color8(255, 238, 186), Color8(255, 194, 92), Color8(236, 124, 42)]
const CHALK := Color8(232, 228, 214)

var _tex: Dictionary[StringName, Texture2D] = {}
var _jib: Dictionary = {}
var _lips: Dictionary = {}


func _init(r: ShipRoomSolari) -> void:
	for n: StringName in [&"beam_mid", &"nose", &"hook", &"jaw"]:
		_tex[n] = ShipRoom.tex(&"solari", "jib_%s.png" % n)
	_jib = r.layout.get("solari", {}).get("jib", {})
	_lips = r.layout.get("solari", {}).get("stream_rows", {})
	_tex[&"drone"] = load("res://art/sprites/station/yard/life_drone_3.png") as Texture2D


static func glow(c: Color) -> Color:
	return Color(c.r, c.g, c.b, GLOW)


static func px(ci: CanvasItem, x: int, y: int, c: Color, w: int = 1, h: int = 1) -> void:
	ci.draw_rect(Rect2(x, y, w, h), c)


## A pixel of metal at heat h: its colour off the stepped ramp, and whether it burns.
static func metal(h: float) -> Color:
	for e: Array in RAMP:
		if h >= float(e[0]):
			return glow(e[1])
	if h > 0.08:
		return glow(Color8(86, 44, 30))
	return Color8(96, 57, 32)


## show18.plate_pixels: the plate's n rows by 20, hotter at its core, the edges and top crusting
## first, cracks in the crust glowing (4 changes a second), a rippling white skin while it fills.
static func plate_pixels(j: int, u: float, tl: float, n: int) -> Array[PackedColorArray]:
	var h0 := C.heat_of(u)
	var tick := int(tl * 4.0)
	var out: Array[PackedColorArray] = []
	for r in n:
		var row := PackedColorArray()
		var ry := float(r) / float(C.PLATE_H - 1)
		for c in 20:
			var cx := absf(c - 9.5) / 9.5
			var h := h0 + 0.10 * (1.0 - cx * cx) + 0.04 * ry - 0.12
			if u >= 5.0 and (c == 0 or c == 19 or r == 0):
				h -= minf(0.2, 0.05 * (u - 5.0))
			if r == 0 and u >= 5.0 and h0 > 0.2:
				if C.hash1([j, c / 3, 5]) < 0.45 - 0.03 * (u - 5.0) and C.hash1([j, c, tick]) < 0.8:
					h = h0 + 0.12
			var col := metal(h)
			if h0 < 0.3:
				col.a = 1.0
				if h0 > 0.1 and r > 1 and r < n - 2 and c > 2 and c < 17:
					col = metal(h0 + 0.1)
			if col.a == 1.0:
				col = PLATE_ROWS[0] if r == 0 else (PLATE_ROWS[2] if r == n - 1 else PLATE_ROWS[1])
				if c == 0 or c == 19:
					col = Color(col.r * 0.7, col.g * 0.7, col.b * 0.7)
			row.append(col)
		out.append(row)
	if u < C.P_DUR + C.TAIL and n > 0:
		var tk := int(tl * 12.0)
		for c in 20:
			out[0][c] = glow(Color8(255, 250, 232) if C.hash1([j, c, tk]) < 0.75 else Color8(255, 228, 160))
	return out


static func draw_plate(ci: CanvasItem, pix: Array[PackedColorArray], x0: int, y0: int) -> void:
	for r in pix.size():
		for c in 20:
			var x := x0 + c
			if x >= 0 and x < ShipRoom.W:
				px(ci, x, y0 + r, pix[r][c])


## Everything on the bed this frame, in show18's order: stacks, moulds and streams, then the jibs.
func paint(ci: CanvasItem, t: float, crew: ShipRoomSolariCrew) -> void:
	var tl := fposmod(t, C.LOOP)
	for j in 6:
		var u := C.u_of(j, tl)
		_stack(ci, j, u, crew)
		var land := _mould(ci, j, u, tl)
		if C.pouring(u):
			_stream(ci, j, u, tl, land)
		else:
			var y0 := int(_lips.get(str(C.TAPS[j]), [137])[0])
			px(ci, C.TAPS[j] - 1, y0, glow(Color8(150, 52, 18)), 3)
	if crew != null:
		crew.paint_wall(ci, t)
	for j in 6:
		_jib_draw(ci, j, C.u_of(j, tl), tl)
	_drone(ci, tl)
	_beacon(ci, tl)


func _stack(ci: CanvasItem, j: int, u: float, crew: ShipRoomSolariCrew) -> void:
	var X := C.stack_x(j)
	if X < -10 or X > ShipRoom.W + 10:
		return
	var n := 3 if (u >= 24.7 or u < 16.0) else 2
	if n < 3:
		return
	var top := C.FLOOR + 1 - C.PLATE_H * 3
	var placed := u >= C.JIB.release.x
	for r in C.PLATE_H:
		var c := Color8(176, 106, 50)
		if r == C.PLATE_H - 1:
			c = Color8(6, 2, 1)
		elif r == 1:
			c = Color8(122, 72, 38)
		elif r > 1:
			c = Color8(92, 55, 31) if r < C.PLATE_H - 2 else Color8(70, 44, 28)
		px(ci, X - 10, top + r, c, 20)
		px(ci, X - 10, top + r, Color8(6, 2, 1))
		px(ci, X + 9, top + r, Color8(6, 2, 1))
		if placed and r > 0 and r < C.PLATE_H - 1 and C.heat_of(u) > 0.08:
			px(ci, X - 8, top + r, metal(C.heat_of(u) + 0.02), 16)
	var chalk := crew.chalk_top(j, u) if crew != null else (u >= 25.4 or u < 16.0)
	if chalk:
		px(ci, X - 3, top + 3, CHALK, 3)
		px(ci, X - 1, top + 4, CHALK)


## The mould's metal; returns its surface row, or -1 while it is empty.
func _mould(ci: CanvasItem, j: int, u: float, tl: float) -> int:
	var n := C.fill_of(u)
	if n <= 0:
		return -1
	draw_plate(ci, plate_pixels(j, u, tl, n), C.TAPS[j] - C.MW / 2 + 1, C.IN1 - n + 1)
	return C.IN1 - n + 1


## The pour: a thick stream, white at its core and orange at its edges, swaying, surges running
## down it, ragged at its edges 10 times a second; the spout's lip burning; the crown where it lands.
func _stream(ci: CanvasItem, j: int, u: float, tl: float, land: int) -> void:
	var T := C.TAPS[j]
	if land < 0:
		land = C.IN1
	var ytop := float(C.SPOUT_Y)
	var ybot := float(land)
	if u < C.FALL:
		ybot = C.SPOUT_Y + (land - C.SPOUT_Y) * u / C.FALL
	elif u >= C.P_DUR:
		ytop = C.SPOUT_Y + (land - C.SPOUT_Y) * (u - C.P_DUR) / C.TAIL
	var full := u >= 0.1 and u < C.P_DUR - 0.25
	var tick := int(tl * 10.0)
	var span := maxf(1.0, land - C.SPOUT_Y)
	var sway := 0.9 * sin(TAU * tl * 1.4 + 2.1 * j)
	for y in range(int(ytop), int(ybot) + 1):
		var r := y - C.SPOUT_Y
		var cx := T + int(roundf(sway * r / span))
		var half := 2 if full else 1
		if full and fposmod(r - tl * 60.0 + 7 * j, 11.0) < 3.0:
			half += 1
		for dx in range(-half - 1, half + 2):
			var d := absi(dx)
			var c: Color
			if d == half + 1:
				if C.hash1([j, r / 2, tick, 1 if dx > 0 else 0]) < 0.55:
					continue
				c = STREAM[3]
			else:
				c = STREAM[mini(3, d + (1 if (not full and d > 0) else 0))]
			px(ci, cx + dx, y, glow(c))
	px(ci, T - 2, C.SPOUT_Y - 2, glow(Color8(255, 214, 130)), 5, 2)
	if u >= C.FALL and u < C.P_DUR:
		var tk := int(tl * 12.0)
		for k in 9:
			var dx := int(roundf((C.hash1([j, tk, k]) - 0.5) * 12.0))
			var dy := 1 + int(C.hash1([j, tk, k, 2]) * 3.0)
			var yy := land - dy
			if yy >= C.MY0 - 3 and yy < land and absi(dx) > 1:
				px(ci, T + dx, yy, glow(Color8(255, 240, 180) if dy < 3 else Color8(250, 170, 70)))


func _blit(ci: CanvasItem, n: StringName, x: int, y: int, flip: bool, w: int = -1) -> void:
	var tx: Texture2D = _tex.get(n)
	if tx == null:
		return
	var sw := tx.get_width() if w < 0 else w
	var src := Rect2(0, 0, sw, tx.get_height())
	var dst := Rect2(x + sw, y, -sw, tx.get_height()) if flip else Rect2(x, y, sw, tx.get_height())
	ci.draw_texture_rect_region(tx, dst, src)


## show18.draw_jib: the arm level from the post to the tip, the nose and its lamp, the plumb chain,
## the hook block and spreader, the two jaws open or shut on the plate it carries.
func _jib_draw(ci: CanvasItem, j: int, u: float, tl: float) -> void:
	var s := C.SIDE[j]
	var P := C.TAPS[j] + s * C.ARM
	var js := C.jib_state(u)
	var tx := C.jib_tip_x(j, js.phi)
	var bh := _tex[&"beam_mid"].get_height() if _tex[&"beam_mid"] != null else 7
	var top := C.ARM_Y - bh / 2
	var L := absi(tx - P)
	if L >= 2:
		_blit(ci, &"beam_mid", mini(P, tx), top, false, L)
	var band: Array = _jib.get("nose_band", [11, 17])
	var ny := top - int(band[0])
	var nose := _tex[&"nose"]
	var nw := nose.get_width() if nose != null else 12
	var nh := nose.get_height() if nose != null else 20
	var hook := _tex[&"hook"]
	var hkw := hook.get_width() if hook != null else 7
	var hkh := hook.get_height() if hook != null else 29
	var hy := js.hy
	_blit(ci, &"hook", tx - hkw / 2, hy - hkh, false)
	if tx >= 0 and tx < ShipRoom.W:
		for y in range(ny + nh, hy - hkh):
			px(ci, tx, y, Color8(119, 65, 32) if (y + hy) % 2 != 0 else Color8(39, 28, 24))
	var flip := tx < P
	_blit(ci, &"nose", tx - nw / 2, ny, flip)
	var lamp_on := C.jib_moving(u) and fposmod(tl * 2.0, 1.0) < 0.6
	for g: Array in _jib.get("glass", []):
		var gx := int(g[0])
		if flip:
			gx = nw - 1 - gx
		px(ci, gx + tx - nw / 2, int(g[1]) + ny, glow(Color8(255, 176, 50)) if lamp_on else Color8(63, 40, 29))
	var reach := 11 if js.grip else 13
	if js.carry:
		draw_plate(ci, plate_pixels(j, minf(u, 30.0), tl, C.PLATE_H), tx - 10, hy + 1)
	var jaw := _tex[&"jaw"]
	var jw := jaw.get_width() if jaw != null else 3
	for sx: int in [-1, 1]:
		_blit(ci, &"jaw", tx + sx * reach - jw / 2, hy - 2, sx > 0)


## The drone crossing high once a loop, its nav lights blinking red and green.
func _drone(ci: CanvasItem, tl: float) -> void:
	var dr := _tex[&"drone"]
	if dr == null:
		return
	var x := int(roundf(tl / C.LOOP * (ShipRoom.W + 120) - 60))
	var w := 18
	var h := 16
	ci.draw_texture_rect_region(dr, Rect2(x - w / 2, 52 - h / 2, w, h), Rect2(1, 2, w, h), Color(0.9, 0.9, 0.9))
	var on := fposmod(tl, 0.6) < 0.3
	for e: Array in [[-w / 2, Color8(255, 60, 40)], [w / 2 - 1, Color8(80, 255, 120)]]:
		var c: Color = e[1]
		if on != (int(e[0]) < 0):
			c = Color(c.r * 0.35, c.g * 0.35, c.b * 0.35)
		px(ci, x + int(e[0]), 52, glow(c))


## Furnace 2's amber beacon turning through the roar (6.0-13.6 s), 1.2 turns a second.
func _beacon(ci: CanvasItem, tl: float) -> void:
	var x := C.TAPS[1] - 2
	var y := 58
	px(ci, x - 1, y + 3, glow(Color8(40, 30, 22)), 6)
	if tl < 6.0 or tl >= 13.6:
		px(ci, x, y, glow(Color8(96, 54, 22)), 4, 3)
		return
	var ph := fposmod(tl * 1.2, 1.0)
	var lvl: float = [0.4, 0.65, 1.0][mini(2, int(maxf(0.0, cos(TAU * ph)) * 3.0))]
	px(ci, x, y, glow(Color(1.0, 170.0 / 255.0, 40.0 / 255.0) * lvl), 4, 3)
	px(ci, x + 1, y, glow(Color(1.0, 230.0 / 255.0, 150.0 / 255.0) * lvl), 2)
