class_name ShipRoomKorvanPaint
extends Node2D

## One layer of Korvan's life as the film drew it, in frame pixels: rects and sprites set each frame
## (`clear`, then the calls, then the draw), lit one way (`light`) or blended (multiply, add).
## Why: docs/why/ShipRoomKorvan.md#life

enum Blend { LIT, MUL, ADD, UNLIT }

const FRAME := Rect2(0, 0, 960, 540)
const CONTACT := preload("res://shaders/ship_room_korvan_contact.gdshader")

var blend := Blend.LIT
## Drawn once and kept: what never changes from frame to frame (the floor lamp, the desk, the platforms).
var keep := false
## Draws outside this frame rect are cut (the door's opening, the office glass).
var clip := FRAME:
	set(v):
		clip = v
		_full = v == FRAME
var _full := true
## Drawn in its own coordinates, moved by `position`: no frame bounds (the crane's rigging).
var free := false
# the ops in packed arrays (cheap to fill each frame): a kind per op, rects and their colours, sprites
var _kind := PackedByteArray()
var _rect := PackedVector4Array()
var _col := PackedColorArray()
var _spr: Array[Array] = []
## The contact shadow's shader (shared by the room's layers, given by `ShipRoomKorvanLife`).
var contact_mat: ShaderMaterial = null
## Op lists already worked out for a state of this layer (`recall`, `remember`): a layer whose picture is a
## function of a few numbers (the office's clerks, the hoist's chain) is drawn from them after the first time.
var _memo: Dictionary = {}
var _li := Vector4(-1, -1, -1, -1)
var _cs := Vector4(-1, -1, -1, -1)


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
## times clamp(max light at p + k, lo, hi), 3 the room's light, 4 as drawn, 5 a flat light k; then x mul + add
## (add is the door's warm backlight or nothing). All of it in one instance slot (`li`, see the shader).
## Why: docs/why/ShipRoomKorvan.md#instance-slots
func light(mode: int, p: Vector2 = Vector2.ZERO, k: float = 0.0, lo: float = 0.0, hi: float = 9.0,
		mul: float = 1.0, add: Color = Color(0, 0, 0)) -> void:
	var px := int(clampf(p.x, 0, 959))
	var py := int(clampf(p.y, 0, 539))
	var code := mode + (8 if add.r > 0.0 else 0) + 16 * (px + 1024 * py)
	_set_li(Vector4(code, k, roundi(lo * 100.0) + 1000 * roundi(hi * 100.0), mul))


## A weld wisp (lmode 7) centred on (cx, cy): the slot holds the centre's whole pixel, the rect's colour its
## fraction (the shader draws no colour of its own here); src 0 the lift's arc, 1 the ladder welder's.
func wisp(cx: float, cy: float, rad: float, dens: float, src: int, lvl: float) -> void:
	var ix := floori(cx)
	var iy := floori(cy)
	_set_li(Vector4(7 + 16 * (ix + 1024 * iy), rad, dens, 2.0 * src + clampf(lvl, 0.0, 1.0)))
	var x0 := floori(cx - rad - 1.0)
	var y0 := floori(cy - rad - 1.0)
	rect(x0, y0, ceili(cx + rad + 1.0) - x0, ceili(cy + rad + 1.0) - y0, Color(cx - ix, cy - iy, 0, 1))


func _set_li(v: Vector4) -> void:
	if v != _li:
		_li = v
		set_instance_shader_parameter(&"li", v)


func clear() -> void:
	if _kind.is_empty():
		return
	# new arrays, never .clear(): after `recall` these are the memo's own (packed arrays are shared)
	# Why: docs/why/ShipRoomKorvan.md#remembered-poses
	_kind = PackedByteArray()
	_rect = PackedVector4Array()
	_col = PackedColorArray()
	_spr = []
	queue_redraw()


## Draws what was remembered for `key`, true when there was one (the layer must be clear).
func recall(key: Variant) -> bool:
	var m: Array = _memo.get(key, [])
	if m.is_empty():
		return false
	_kind = m[0]
	_rect = m[1]
	_col = m[2]
	_spr.assign(m[3])
	if not _kind.is_empty():
		queue_redraw()
	return true


func remember(key: Variant) -> void:
	_memo[key] = [_kind.duplicate(), _rect.duplicate(), _col.duplicate(), _spr.duplicate()]


## A colour in the film's 0-255 floats.
static func c8(r: float, g: float, b: float, a: float = 1.0) -> Color:
	return Color(r / 255.0, g / 255.0, b / 255.0, a)


func rect(x: int, y: int, w: int, h: int, c: Color) -> void:
	if free:
		_rect.append(Vector4(x, y, w, h))
		_col.append(c)
		_kind.append(0)
		if _kind.size() == 1:
			queue_redraw()
		return
	if not _full or x < 0 or y < 0 or x + w > 960 or y + h > 540:
		var r := Rect2(x, y, w, h).intersection(clip)
		if r.size.x <= 0 or r.size.y <= 0:
			return
		_rect.append(Vector4(r.position.x, r.position.y, r.size.x, r.size.y))
	elif w <= 0 or h <= 0:
		return
	else:
		_rect.append(Vector4(x, y, w, h))
	_col.append(c)
	_kind.append(0)
	if _kind.size() == 1:
		queue_redraw()


func px(x: int, y: int, c: Color) -> void:
	if free:
		rect(x, y, 1, 1, c)
		return
	if x < 0 or y < 0 or x >= 960 or y >= 540:
		return
	if not _full:
		rect(x, y, 1, 1, c)
		return
	_rect.append(Vector4(x, y, 1, 1))
	_col.append(c)
	_kind.append(0)
	if _kind.size() == 1:
		queue_redraw()


## A region of a texture with its top left at (x, y), mirrored when flip; cut to the clip.
func sprite(tex: Texture2D, src: Rect2, x: int, y: int, flip: bool = false, mod: Color = Color.WHITE) -> void:
	if tex == null:
		return
	var dst := Rect2(x, y, src.size.x, src.size.y)
	var cut := dst if free else dst.intersection(clip)
	if cut.size.x <= 0 or cut.size.y <= 0:
		return
	var s := src
	var dx0 := cut.position.x - dst.position.x
	var dx1 := dst.end.x - cut.end.x
	s.position.y += cut.position.y - dst.position.y
	s.size.y = cut.size.y
	s.position.x += dx1 if flip else dx0
	s.size.x = cut.size.x
	_spr.append([tex, s, cut, flip, mod])
	_kind.append(1)
	if _kind.size() == 1:
		queue_redraw()


## The film's contact shadow (core.contact), one per layer: its ellipse worked out by a multiply shader.
## Why: docs/why/ShipRoomKorvan.md#cost
func contact(x0: float, x1: float, feet: int, length: int = 6, dark: float = 0.5) -> void:
	if contact_mat == null:
		contact_mat = ShaderMaterial.new()
		contact_mat.shader = CONTACT
	if material != contact_mat:
		material = contact_mat
	var cx := (x0 + x1) / 2.0
	var rx := maxf(2.0, (x1 - x0) / 2.0 + 3.0)
	var cs := Vector4(cx, rx, feet, length + clampf(dark, 0.0, 0.99))
	if cs != _cs:
		_cs = cs
		set_instance_shader_parameter(&"cs", cs)
	var a := int(cx - rx) - 1
	rect(a, feet - 1, int(cx + rx) + 2 - a, length + 2, Color.WHITE)


func _draw() -> void:
	var ri := 0
	var si := 0
	for k in _kind:
		if k == 0:
			var r := _rect[ri]
			draw_rect(Rect2(r.x, r.y, r.z, r.w), _col[ri])
			ri += 1
		else:
			var op: Array = _spr[si]
			si += 1
			var d: Rect2 = op[2]
			if op[3]:
				draw_set_transform(Vector2(d.end.x, d.position.y), 0.0, Vector2(-1, 1))
				draw_texture_rect_region(op[0], Rect2(Vector2.ZERO, d.size), op[1], op[4])
				draw_set_transform(Vector2.ZERO)
			else:
				draw_texture_rect_region(op[0], d, op[1], op[4])
