class_name YardStandSet
extends Control

## One display berth on the front door: a hull on two of the yard's stands, or,
## for a locked manufacturer, the tarp that covers it. The hull (or the tarp) is
## the thing you point at and click; the stands are scenery.
## Why: docs/why/ChassisSelect.md#banner-yard

signal pressed
signal hovered(on: bool)

const WEIGHTS := [HullData.Weight.LIGHT, HullData.Weight.MEDIUM, HullData.Weight.HEAVY]
## Where each weight stands (the mockup's SHIPS): the hull's left edge and its
## belly row in hall pixels; the heavy centred behind, higher on the floor.
const PLACE := {HullData.Weight.HEAVY: Vector2i(333, 252), HullData.Weight.MEDIUM: Vector2i(88, 290),
	HullData.Weight.LIGHT: Vector2i(634, 290)}
## The hull is let six rows into the stands' saddles; a stand picture is 46 x 88.
const SINK := 6
const STAND_W := 46
const STAND_H := 88
const STAND_AT := [0.27, 0.73]
## The tarp art, drawn over the Korvan hulls: its left edge from the hull's, and
## the row inside it that lies on the hull's belly row.
const TARP_FILE := {HullData.Weight.LIGHT: "tarp_light.png", HullData.Weight.MEDIUM: "tarp_medium.png",
	HullData.Weight.HEAVY: "tarp_heavy.png"}
const TARP_ANCHOR := {HullData.Weight.LIGHT: Vector2i(2, 75), HullData.Weight.MEDIUM: Vector2i(3, 88),
	HullData.Weight.HEAVY: Vector2i(5, 107)}
## The tarps drop one after another, the heavy first, and each hem ripples on its own clock.
const TARP_DELAY := {HullData.Weight.HEAVY: 0.0, HullData.Weight.MEDIUM: 0.18, HullData.Weight.LIGHT: 0.36}
const TARP_SEED := {HullData.Weight.HEAVY: 0.0, HullData.Weight.MEDIUM: 1.4, HullData.Weight.LIGHT: 2.9}
const TARP_LIFT := 12

var weight: HullData.Weight = HullData.Weight.MEDIUM
var scene: YardScene
var tarped: bool = false
## The hull (or tarp) box in hall pixels: the click area and what the band ties to.
var thing: Rect2i
## The stands' feet row.
var feet: int = 0
var hover: bool = false

var _view: ShipView = null
var _tarp: Tarp = null
var _x0: int = 0
var _belly: int = 0
var _hull_w: int = 0
var _stand_x: Array[int] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


## Stand `hull` here, or the weight's tarp when `hull` is null (the frame's
## width still comes from Korvan's hull, which the tarps were cut for).
func setup(sc: YardScene, w: HullData.Weight, hull: HullData, frame: HullData) -> void:
	scene = sc
	weight = w
	tarped = hull == null
	for c in get_children():
		c.queue_free()
	_view = null
	_tarp = null
	var place: Vector2i = PLACE[w]
	_x0 = place.x
	_belly = place.y
	feet = _belly - SINK + STAND_H
	# the hull's ink, for the stands' places and the box
	var probe := ShipView.new()
	# a hull on stands: no idle flame, no running lights
	probe._engines_off = true
	probe.setup_preview(frame if hull == null else hull, 0, 1)
	var img := probe.canvas()
	var ink := _ink(img)
	_hull_w = maxi(1, ink.size.x)
	var top := _belly - ink.size.y
	position = Vector2(_x0 - 24, top)
	size = Vector2(_hull_w + 48, feet - top)
	var sh: Dictionary = (YardScene.doc().get("art", {}) as Dictionary).get("stand_shadow", {})
	var shadow := scene.tex(String(sh.get("picture", "stand_shadow.png")))
	var st: Dictionary = ((YardScene.doc().get("art", {}) as Dictionary).get("stands", {}) as Dictionary).get("city", {})
	var stand := scene.tex(String(st.get("picture", "stand_city.png")))
	_stand_x.clear()
	for q: float in STAND_AT:
		_stand_x.append(int(_x0 + float(_hull_w) * q) - STAND_W / 2)
	for sx in _stand_x:
		if shadow != null:
			var tr := TextureRect.new()
			tr.texture = shadow
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			tr.position = Vector2(sx - 20, feet - 4) - position
			add_child(tr)
	for sx in _stand_x:
		if stand != null:
			var tr2 := TextureRect.new()
			tr2.texture = stand
			tr2.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tr2.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			tr2.position = Vector2(sx, _belly - SINK) - position
			tr2.material = scene._mats[YardPaint.FLOOR]
			var cx := sx + STAND_W / 2
			tr2.set_instance_shader_parameter(&"cell", Vector2(cx - 766 if cx > 765 else cx, feet))
			add_child(tr2)
	if hull != null:
		_view = probe
		_view.position = Vector2(_x0 - ink.position.x, top - ink.position.y) - position
		_view.size = Vector2(img.get_width(), img.get_height())
		_view.material = scene._mats[YardPaint.SHIP]
		_view.self_modulate = YardScene.HULL_TINT
		scene._parent_material(_view)
		add_child(_view)
		thing = Rect2i(_x0, top, _hull_w, ink.size.y)
	else:
		probe.free()
		_tarp = Tarp.new()
		_tarp.setup(scene.tex(String(TARP_FILE[w])), float(TARP_DELAY[w]), float(TARP_SEED[w]))
		var a: Vector2i = TARP_ANCHOR[w]
		var at := Vector2i(_x0 - a.x, _belly - a.y)
		_tarp.position = Vector2(at.x - 4, at.y - TARP_LIFT) - position
		_tarp.material = scene._mats[YardPaint.SHIP]
		add_child(_tarp)
		thing = Rect2i(at.x, at.y, _tarp.tex_w, _tarp.tex_h)
		# the control reaches up to where the tarp falls from
		var grow := float(top - (at.y - TARP_LIFT))
		if grow > 0.0:
			position.y -= grow
			size.y += grow
			for c in get_children():
				(c as Control).position.y += grow


## The hull's (or tarp's) pixels into the light's ship map (R a hull, G a stand),
## at their hall places; `img` may be wider than the hall.
func mask_into(img: Image) -> void:
	var st: Dictionary = ((YardScene.doc().get("art", {}) as Dictionary).get("stands", {}) as Dictionary).get("city", {})
	var si := scene.img(String(st.get("picture", "stand_city.png")))
	if si != null:
		for sx in _stand_x:
			_stamp(img, si, Rect2i(Vector2i.ZERO, si.get_size()), Vector2i(sx, _belly - SINK), Color8(0, 255, 0, 255), false)
	if _view != null:
		var c := _view.canvas()
		_stamp(img, c, _ink(c), Vector2i(_x0, thing.position.y), Color8(255, 0, 0, 255), true)
	elif _tarp != null and _tarp.image != null:
		_stamp(img, _tarp.image, Rect2i(Vector2i.ZERO, _tarp.image.get_size()), thing.position, Color8(255, 0, 0, 255), true)


static func _stamp(img: Image, src: Image, ink: Rect2i, at: Vector2i, col: Color, over: bool) -> void:
	for y in ink.size.y:
		for x in ink.size.x:
			if src.get_pixel(ink.position.x + x, ink.position.y + y).a8 < 128:
				continue
			var X := at.x + x
			var Y := at.y + y
			if X < 0 or Y < 0 or X >= img.get_width() or Y >= img.get_height():
				continue
			if over or img.get_pixel(X, Y).r8 == 0:
				img.set_pixel(X, Y, col)


## The box of a picture's opaque pixels.
static func _ink(img: Image) -> Rect2i:
	if img == null:
		return Rect2i()
	var r := img.get_used_rect()
	return r


## Where the band's tie line meets this berth: the heavy's on its left stand,
## clear of the crew between its stands; the others at the hull's middle.
func tie_point() -> Vector2:
	var x := thing.position.x + 79 if weight == HullData.Weight.HEAVY else thing.position.x + thing.size.x / 2
	return Vector2(x, feet - 2)


## Only the hull or the tarp is the thing; the stands and the air are not.
func _has_point(p: Vector2) -> bool:
	return thing.has_point(Vector2i(p + position))


func _gui_input(e: InputEvent) -> void:
	var mb := e as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		Audio.click()
		pressed.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		hover = true
		Audio.hover()
		hovered.emit(true)
	elif what == NOTIFICATION_MOUSE_EXIT:
		hover = false
		hovered.emit(false)


## The lit material the sharp copy over the blur draws with.
func sharp_material() -> Material:
	return scene._mats[YardPaint.SHIP]


## The hull or the tarp alone, drawn into `ci` at its own place on the hall:
## the sharp copy the hover lays over the blurred yard.
func draw_sharp(ci: CanvasItem, origin: Vector2) -> void:
	if _view != null:
		ci.draw_texture_rect(_view.texture, Rect2(_view.global_position - origin, _view.size), false, YardScene.HULL_TINT)
	elif _tarp != null:
		_tarp.paint(ci, _tarp.global_position - origin)


## Start the tarps falling now (a locked set just came in).
func drop_tarp() -> void:
	if _tarp != null:
		_tarp.drop()


## THE TARP: the art posed row by row in whole pixels. It falls from twelve
## rows up, lands, sags, springs back and settles; at rest, every few seconds,
## the hall's air ripples the loose hem sideways while the body never moves.
class Tarp extends Control:
	var texture: Texture2D
	var image: Image
	var tex_w: int = 0
	var tex_h: int = 0
	var delay: float = 0.0
	var seed_s: float = 0.0
	var _u: float = -1.0
	var _dropping: bool = false
	var _last_key := ""

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func setup(t: Texture2D, d: float, s: float) -> void:
		texture = t
		delay = d
		seed_s = s
		image = t.get_image() if t != null else null
		if image != null and image.get_format() != Image.FORMAT_RGBA8:
			image.convert(Image.FORMAT_RGBA8)
		tex_w = t.get_width() if t != null else 0
		tex_h = t.get_height() if t != null else 0
		size = Vector2(tex_w + 8, tex_h + TARP_LIFT + 12)
		_u = 10.0

	func drop() -> void:
		_u = -delay
		_dropping = true

	func _process(dt: float) -> void:
		_u += dt
		var key := str(pose())
		if key != _last_key:
			_last_key = key
			queue_redraw()

	## (lift, stretch at the top, sag at the hem, flutter phase or -1) at this moment.
	func pose() -> Array[float]:
		var u := _u
		if u < 0.0:
			return []
		if u < 0.26:
			var f := pow(u / 0.26, 2.0)
			return [-12.0 + 12.0 * f, 3.0 * (1.0 - f), 0.0, -1.0]
		if u < 0.40:
			return [0.0, 0.0, 3.0 * sin((u - 0.26) / 0.14 * PI), -1.0]
		if u < 0.56:
			return [0.0, 0.0, -1.2 * sin((u - 0.40) / 0.16 * PI), -1.0]
		var cyc := fmod(u + seed_s, 4.2)
		if cyc < 0.6:
			return [0.0, 0.0, 0.0, cyc / 0.6]
		return [0.0, 0.0, 0.0, -1.0]

	func _draw() -> void:
		paint(self, Vector2.ZERO)

	## The posed rows at `at` (the control's top left) into any canvas item.
	func paint(ci: CanvasItem, at: Vector2) -> void:
		if texture == null:
			return
		var p := pose()
		if p.is_empty():
			return
		var lift := float(p[0])
		var stretch := float(p[1])
		var sag := float(p[2])
		var flutter := float(p[3])
		var ox := at.x + 4.0
		var oy := at.y + TARP_LIFT
		if lift != 0.0 or stretch != 0.0 or sag != 0.0:
			var last_y := -1000
			for r in tex_h:
				var f := float(r) / float(maxi(1, tex_h - 1))
				var y := r + int(round(lift - stretch * (1.0 - f) + sag * f * f))
				var row := Rect2(0, r, tex_w, 1)
				# a row that leaves a gap under the one above fills it with itself
				while last_y > -1000 and last_y + 1 < y:
					last_y += 1
					ci.draw_texture_rect_region(texture, Rect2(ox, oy + last_y, tex_w, 1), row)
				if y > last_y:
					ci.draw_texture_rect_region(texture, Rect2(ox, oy + y, tex_w, 1), row)
					last_y = y
			return
		var hem := maxi(0, tex_h - 12)
		ci.draw_texture_rect_region(texture, Rect2(ox, oy, tex_w, hem), Rect2(0, 0, tex_w, hem))
		var env := sin(flutter * PI) if flutter >= 0.0 else 0.0
		for r in range(hem, tex_h):
			if env <= 0.0:
				ci.draw_texture_rect_region(texture, Rect2(ox, oy + r, tex_w, 1), Rect2(0, r, tex_w, 1))
				continue
			# a small wave along the hem: runs of the row shifted by whole pixels
			var depth := float(r - hem) / 11.0
			var amp := 2.0 * depth * env
			var run0 := 0
			var dx0 := _wave(0, amp, flutter)
			for x in range(1, tex_w + 1):
				var dx := _wave(x, amp, flutter) if x < tex_w else 1000
				if dx != dx0:
					ci.draw_texture_rect_region(texture, Rect2(ox + run0 + dx0, oy + r, x - run0, 1), Rect2(run0, r, x - run0, 1))
					run0 = x
					dx0 = dx

	static func _wave(x: int, amp: float, phase: float) -> int:
		return int(round(amp * sin(TAU * (float(x) / 40.0 - phase * 1.5))))
