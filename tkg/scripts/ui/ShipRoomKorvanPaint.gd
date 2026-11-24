class_name ShipRoomKorvanPaint
extends Node2D

## One layer of Korvan's life as the film drew it, in frame pixels: rects and sprites set each frame
## (`clear`, then the calls, then the draw), lit one way (`light`) or blended (multiply, add).
## Why: docs/why/ShipRoomKorvan.md#life

enum Blend { LIT, MUL, ADD, UNLIT }

var blend := Blend.LIT
## Drawn once and kept: what never changes from frame to frame (the floor lamp, the desk).
var keep := false
## Draws outside this frame rect are cut (the door's opening, the office glass).
var clip := Rect2(0, 0, 960, 540):
	set(v):
		clip = v
		_full = v == FRAME
var _full := true
const FRAME := Rect2(0, 0, 960, 540)
## Contact shadows worked out once per place and size: [x, y, f] each.
static var _contacts: Dictionary[Vector4i, PackedVector3Array] = {}
var _ops: Array[Array] = []


func setup(b: Blend, lit: Material) -> void:
	blend = b
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	match b:
		Blend.LIT:
			material = lit
		Blend.MUL:
			var m := CanvasItemMaterial.new()
			m.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
			material = m
		Blend.ADD:
			var m := CanvasItemMaterial.new()
			m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			material = m


## How the film lit this layer: mode 0 the light at its own pixels (+ k), 1 at point p (+ k), 2 colours
## times clamp(max light at p + k, lo, hi), 3 the room's light, 4 as drawn, 5 a flat light k; then x mul + add.
func light(mode: int, p: Vector2 = Vector2.ZERO, k: float = 0.0, lo: float = 0.0, hi: float = 9.0,
		mul: float = 1.0, add: Color = Color(0, 0, 0)) -> void:
	set_instance_shader_parameter(&"lmode", mode)
	set_instance_shader_parameter(&"lp", Vector2(clampf(p.x, 0, 959), clampf(p.y, 0, 539)))
	set_instance_shader_parameter(&"lk4", Vector4(k, lo, hi, mul))
	set_instance_shader_parameter(&"ladd", Vector3(add.r, add.g, add.b))


func clear() -> void:
	_ops.clear()
	queue_redraw()


## A colour in the film's 0-255 floats.
static func c8(r: float, g: float, b: float, a: float = 1.0) -> Color:
	return Color(r / 255.0, g / 255.0, b / 255.0, a)


func rect(x: int, y: int, w: int, h: int, c: Color) -> void:
	var r := Rect2(x, y, w, h)
	if not _full:
		r = r.intersection(clip)
	elif x < 0 or y < 0 or x + w > 960 or y + h > 540:
		r = r.intersection(FRAME)
	if r.size.x > 0 and r.size.y > 0:
		_ops.append([0, r, c])


func px(x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < 960 and y < 540:
		rect(x, y, 1, 1, c)


## A region of a texture with its top left at (x, y), mirrored when flip; cut to the clip.
func sprite(tex: Texture2D, src: Rect2, x: int, y: int, flip: bool = false, mod: Color = Color.WHITE) -> void:
	if tex == null:
		return
	var dst := Rect2(x, y, src.size.x, src.size.y)
	var cut := dst.intersection(clip)
	if cut.size.x <= 0 or cut.size.y <= 0:
		return
	var s := src
	var dx0 := cut.position.x - dst.position.x
	var dx1 := dst.end.x - cut.end.x
	s.position.y += cut.position.y - dst.position.y
	s.size.y = cut.size.y
	s.position.x += dx1 if flip else dx0
	s.size.x = cut.size.x
	_ops.append([1, tex, s, cut, flip, mod])


## The film's contact shadow (core.contact) as multiplies: an ellipse round the feet, its rim
## dithered on the frame's grid. Only on a MUL layer.
func contact(x0: float, x1: float, feet: int, length: int = 6, dark: float = 0.5) -> void:
	var key := Vector4i(roundi(x0 * 2.0), roundi(x1 * 2.0), feet, length * 100 + roundi(dark * 100.0))
	var cells: PackedVector3Array = _contacts.get(key, PackedVector3Array())
	if cells.is_empty():
		cells = _contact_cells(x0, x1, feet, length, dark)
		_contacts[key] = cells
	for c in cells:
		_ops.append([0, Rect2(c.x, c.y, 1, 1), Color(c.z, c.z, c.z)])


static func _contact_cells(x0: float, x1: float, feet: int, length: int, dark: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	var cx := (x0 + x1) / 2.0
	var rx := maxf(2.0, (x1 - x0) / 2.0 + 3.0)
	for dy in range(-1, length + 1):
		var y := feet + dy
		if y < 0 or y >= 540:
			continue
		for x in range(maxi(0, int(cx - rx) - 1), mini(960, int(cx + rx) + 2)):
			var r := sqrt(pow((x - cx) / rx, 2.0) + pow((dy + 1) / (length + 1.0), 2.0))
			var k := clampf(1.0 - r, 0.0, 1.0)
			if k > 0.35 or (k > 0.0 and ShipRoom.bayer4(x, y) < k / 0.35):
				out.append(Vector3(x, y, 1.0 - dark * clampf(0.45 + k, 0.0, 1.0)))
	return out


func _draw() -> void:
	for op in _ops:
		if op[0] == 0:
			draw_rect(op[1], op[2])
		else:
			var d: Rect2 = op[3]
			if op[4]:
				draw_set_transform(Vector2(d.end.x, d.position.y), 0.0, Vector2(-1, 1))
				draw_texture_rect_region(op[1], Rect2(Vector2.ZERO, d.size), op[2], op[5])
				draw_set_transform(Vector2.ZERO)
			else:
				draw_texture_rect_region(op[1], d, op[2], op[5])
