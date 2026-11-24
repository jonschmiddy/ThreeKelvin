class_name YardFront
extends Control

## THE SHIP-SELECT SCREEN's picture (Jon's W2 v10 banners, Nov 10; the rooms, Nov 22-24):
## the maker's room (`ShipRoom`), seven banners on the gantry, its hulls (or a locked
## maker's tarps) on their posts, a hover that blurs the rest. What a click means is
## `ChassisSelect`'s; this is the room.
## Why: docs/why/ChassisSelect.md#banner-yard

signal banner_pressed(i: int)
signal ship_pressed(w: HullData.Weight)
signal ship_hover(w: int)

const W := 960
const H := 540
## The banners' left edges on the gantry.
const BANNER_X := [126, 238, 350, 462, 574, 686, 798]
## The floor fades into the band's colour from this row to the frame's foot in 12 flat
## steps, each boundary two rows of pair dither (Jon, Nov 24: "fades into the bottom panel gradually").
## Why: docs/why/ShipRoom.md#fade-into-the-band
const FALL_FROM := 372
const FALL_STEPS := 12
## The hover's blur comes up and goes in a fifth of a second.
const BLUR_RATE := 5.0

var room: ShipRoom = null
var banners: Array[YardBanner] = []
## By weight: light, medium, heavy.
var sets: Dictionary = {}
var manufacturer: StringName = &""
var locked: bool = false
var picked: int = -1
var hover_w: int = -1
var ready_hall: bool = false

var _fall: TextureRect
var _vignette: ColorRect
var _blur: ColorRect
var _blur_mat: ShaderMaterial
var _ghost: Ghost
var _k: float = 0.0
var _sharp_set: YardStandSet = null
## LAUNCH's heavy lift (`ShipLift`, Jon's L1) under way, its clock and what it calls when the hull is gone.
var launching := false
var lift: ShipLift = null
var _lift_t := 0.0
var _lift_done: Callable = Callable()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)


func setup() -> void:
	for w: HullData.Weight in [HullData.Weight.HEAVY, HullData.Weight.MEDIUM, HullData.Weight.LIGHT]:
		var s := YardStandSet.new()
		sets[w] = s
		s.pressed.connect(func() -> void: ship_pressed.emit(w))
		s.hovered.connect(func(on: bool) -> void: _on_hover(w, on))
		add_child(s)
	_fall = TextureRect.new()
	_fall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fall.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_fall.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_fall.stretch_mode = TextureRect.STRETCH_TILE
	_fall.position = Vector2(0, FALL_FROM)
	_fall.size = Vector2(W, H - FALL_FROM)
	add_child(_fall)
	for i in DB.STARTABLE.size():
		var b := YardBanner.new()
		b.setup(i, DB.STARTABLE[i], Unlocks.unlocked(DB.STARTABLE[i]), int(BANNER_X[i % BANNER_X.size()]))
		b.pressed.connect(func() -> void: banner_pressed.emit(i))
		banners.append(b)
		add_child(b)
	_vignette = ColorRect.new()
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.size = Vector2(W, H)
	var vm := ShaderMaterial.new()
	vm.shader = preload("res://shaders/ship_room_vignette.gdshader")
	_vignette.material = vm
	add_child(_vignette)
	# a room's own passes read the screen too: copy it fresh, so the blur has everything under it
	var bb := BackBufferCopy.new()
	bb.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(bb)
	_blur = ColorRect.new()
	_blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blur.size = Vector2(W, H)
	_blur_mat = ShaderMaterial.new()
	_blur_mat.shader = preload("res://shaders/yard_blur.gdshader")
	_blur.material = _blur_mat
	_blur.visible = false
	add_child(_blur)
	_ghost = Ghost.new()
	_ghost.size = Vector2(W, H)
	_ghost.visible = false
	add_child(_ghost)
	ready_hall = true


## The fade into the band: two columns (the pair dither's checkerboard), tiled across.
static func fall_texture(band: Color) -> ImageTexture:
	var h := H - FALL_FROM
	var img := Image.create(2, h, false, Image.FORMAT_RGBA8)
	var step := float(h) / float(FALL_STEPS)
	for y in h:
		var i := mini(FALL_STEPS, int(floorf(float(y) / step)) + 1)
		var b := int(roundf(float(i - 1) * step))
		for x in 2:
			var w := float(i) / float(FALL_STEPS)
			if (y == b or y == b + 1) and (x + y + FALL_FROM) % 2 != 0:
				w = float(i - 1) / float(FALL_STEPS)
			img.set_pixel(x, y, Color(band.r, band.g, band.b, w))
	return ImageTexture.create_from_image(img)


## Show a maker's three hulls in its room, or its three tarps in the Old hangar when it is locked.
func show_set(m: StringName, open: bool, tier: int = 0) -> void:
	if not ready_hall:
		return
	manufacturer = m
	locked = not open
	var rid := ShipRoom.id_for(m, open)
	if room == null or room.id != rid:
		_set_room(rid)
	for w: HullData.Weight in sets:
		var hull: HullData = DB.at_tier(DB.hull_for(m, w), tier) if open else null
		var kit: Array[ModuleData] = []
		if open:
			kit = YardMounts.kit_for(m, w, tier)
		(sets[w] as YardStandSet).setup(room, w, hull, kit, m)
	if locked:
		for w: HullData.Weight in sets:
			(sets[w] as YardStandSet).drop_tarp()
	room.placed(sets.values())
	if _sharp_set != null:
		_ghost.set_source(_sharp_set)


## The room behind the stands: its `under` first, its `above` straight after the stand sets.
func _set_room(rid: StringName) -> void:
	if room != null:
		room.under.queue_free()
		room.above.queue_free()
	room = ShipRoom.make(rid)
	room.build()
	add_child(room.under)
	move_child(room.under, 0)
	var after := 0
	for s: Node in sets.values():
		after = maxi(after, s.get_index())
	add_child(room.above)
	move_child(room.above, after + 1)
	_fall.texture = fall_texture(room.band_colour())


## What is picked holds the blur round it with the pointer gone (Jon, Nov 11:
## "the blur should stay"). It is lit no differently.
## Why: docs/why/ChassisSelect.md#held-blur
func set_picked(w: int) -> void:
	picked = w
	if hover_w < 0:
		_focus(w)


## The ship drawn sharp over the blur: the one pointed at, else the picked one.
func _focus(w: int) -> void:
	if _ghost == null:
		return
	_sharp_set = sets.get(w) as YardStandSet if w >= 0 else _sharp_set
	if _sharp_set != null:
		_ghost.set_source(_sharp_set)


func _process(delta: float) -> void:
	if not ready_hall:
		return
	if room != null:
		room.extra = lift.plume.lights() if lift != null and lift.plume != null else []
		room.tick(delta)
	if lift != null:
		_lift_t += delta
		lift.lift_at(_lift_t)
		if _lift_t >= ShipLift.front_s() and _lift_done.is_valid():
			var d := _lift_done
			_lift_done = Callable()
			d.call()
	var target := 1.0 if not launching and (hover_w >= 0 or (picked >= 0 and not locked)) else 0.0
	var k := move_toward(_k, target, delta * BLUR_RATE)
	if k != _k:
		_k = k
		_blur_mat.set_shader_parameter(&"k", _k)
		_blur.visible = _k > 0.0
		_ghost.visible = _k > 0.0 and _sharp_set != null
		_ghost.queue_redraw()
	elif _ghost.visible:
		_ghost.queue_redraw()


func _on_hover(w: HullData.Weight, on: bool) -> void:
	if on:
		hover_w = int(w)
		_focus(int(w))
	elif hover_w == int(w):
		hover_w = -1
		_focus(picked)
	ship_hover.emit(hover_w)


## LAUNCH: the picked hull lifts off its posts and burns off the right edge
## (Jon's L1, Nov 12), then `done`. `shake` is what shivers with it (the whole screen).
## Why: docs/why/ShipLift.md#front-door
func lift_off(w: int, shake: Control, done: Callable) -> ShipLift:
	var s: YardStandSet = sets.get(w)
	if s == null or s._view == null or lift != null:
		return null
	launching = true
	_lift_done = done
	_lift_t = 0.0
	var L := ShipLift.new()
	L.k = 1.0
	L.floor_y = float(s.feet)
	L.rise = float(ShipLift.RISE_PX[s.weight])
	L.exit_px = float(W) + ShipLift.EXIT_CLEAR - float(s.thing.position.x)
	L.sink = func(rows: int) -> void: s.retract = rows
	L.shake_node = shake
	L.shake_rest = shake.position
	# (out under the ceiling, in front of the banners' rods)
	L.ceiling_y = 44.0
	L.lamps = room.ceiling_lamps() if room != null else []
	# the jets under the hulls, the smoke and its light over the room, under the floor's fade
	L.setup(s._view, self, get_children().find(sets.values()[0]), _fall)
	# the hull flies with its berth (its click box goes with it, and nothing is clickable now);
	# its posts stay where they stand and sink
	var p0 := s.position
	L.move_view = false
	L.moved = func(o: Vector2) -> void:
		s.position = p0 + o
		s.pin_posts()
		if o.y <= -12.0 and not s.lifted:
			s.lifted = true
	lift = L
	return L


## The berth the band's words tie to.
func tie_point(w: HullData.Weight) -> Vector2:
	var s: YardStandSet = sets.get(w)
	return s.tie_point() if s != null else Vector2.ZERO


func set_of(w: HullData.Weight) -> YardStandSet:
	return sets.get(w)


## The sharp copy of the ship pointed at, over the blurred room.
class Ghost extends Control:
	var source: YardStandSet = null

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func set_source(s: YardStandSet) -> void:
		source = s
		material = s.sharp_material() if s != null else null
		YardMounts.ghost_mounts(self, s)
		queue_redraw()

	func _draw() -> void:
		if source != null and is_instance_valid(source):
			source.draw_sharp(self, global_position)
			YardMounts.follow(self, source)
