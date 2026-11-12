class_name YardFront
extends Control

## THE BANNER SHIPYARD: the front door's picture (Jon's W2 v10, Nov 10). The old
## shipyard hall with its crew and light, seven banners on the gantry, the chosen
## manufacturer's hulls (or tarps) on the stands, a hover that blurs the rest.
## What a click means is `ChassisSelect`'s; this is the hall.
## Why: docs/why/ChassisSelect.md#banner-yard

signal banner_pressed(i: int)
signal ship_pressed(w: HullData.Weight)
signal ship_hover(w: int)

const W := 960
const H := 540
const HALL_W := YardScene.W
const HALL_H := YardScene.H
## The banners' left edges on the gantry.
const BANNER_X := [126, 238, 350, 462, 574, 686, 798]
## An open set is lit as the Shipyard deck is (its ambient, yard.json's dial);
## a locked set's hall goes down to this, its lamps to half.
## Why: docs/why/ChassisSelect.md#lit-as-the-shipyard
const AMB_LOCKED := 0.07
## A locked set's two stuttering lamps and their steps.
const FLICK_LAMPS := [2, 4]
const FLICK := [1.0, 0.55, 0.85, 0.3]
## The bay paint: corner brackets and a dashed line, in the hall's cyan.
const PAINT := Color8(42, 132, 138)
## The floor darkens toward the frame's foot (band B1): from this row, in six steps.
const FALL_FROM := 372
const FALL_TO := 0.08
## The hover's blur comes up and goes in a fifth of a second.
const BLUR_RATE := 5.0

var scene: YardScene = null
var banners: Array[YardBanner] = []
## By weight: light, medium, heavy.
var sets: Dictionary = {}
var manufacturer: StringName = &""
var locked: bool = false
var picked: int = -1
var hover_w: int = -1
var ready_hall: bool = false
## The pools have been baked (`YardFrontPools`), with this set's hulls' shadows in them.
var _bay_baked := false

var _paint: Control
var _fall: Sprite2D
var _blur: ColorRect
var _blur_mat: ShaderMaterial
var _ghost: Ghost
var _k: float = 0.0
var _t: float = 0.0
var _ship_tex: ImageTexture = null
var _sharp_set: YardStandSet = null
## Where the next piece of floor goes among the hall's children: after the hall picture.
var _under_at: int = 1
## LAUNCH's heavy lift (`ShipLift`, Jon's L1) under way, its clock and what it
## calls when the hull is gone; and the ship map with the launching hull lifted
## out, to stamp back where it flies.
var launching := false
var lift: ShipLift = null
var _lift_t := 0.0
var _lift_done: Callable = Callable()
var _ship_map_img: Image = null
var _lm_base: Image = null
var _lm_piece: Image = null
var _lm_rect := Rect2i()
var _lm_off := Vector2i(1 << 20, 0)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)


func setup() -> void:
	scene = YardScene.new()
	scene.dev = MapGen.Development.CITY
	scene.position = Vector2.ZERO
	scene.size = Vector2(HALL_W, HALL_H)
	add_child(scene)
	scene.setup()
	# A click on the hall is "away" from the ships, so it goes on up to `ChassisSelect`.
	scene.mouse_filter = Control.MOUSE_FILTER_PASS
	if scene.light == null or scene.lv.is_empty():
		push_warning("yard front: no city hall installed")
		return
	ready_hall = true
	# the floor runs on past the hall to the frame's edge, its crew and stands with it
	scene.clip_contents = false
	scene.draw_w = W
	scene.life = YardFrontLife.new(scene)
	# the deal TV stands on the apron where the band goes: off the picture
	scene.deal_tv.X = -2000.0
	# never powered: no service drones, the TV dark
	scene._tp = 1.0e9
	_build_hall_extras()
	_paint = Control.new()
	_paint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paint.size = Vector2(W, H)
	_paint.draw.connect(_draw_paint)
	_under(_paint)
	for i in DB.STARTABLE.size():
		var b := YardBanner.new()
		b.setup(i, DB.STARTABLE[i], Unlocks.unlocked(DB.STARTABLE[i]), int(BANNER_X[i % BANNER_X.size()]))
		b.pressed.connect(func() -> void: banner_pressed.emit(i))
		banners.append(b)
		add_child(b)
	for w: HullData.Weight in [HullData.Weight.HEAVY, HullData.Weight.MEDIUM, HullData.Weight.LIGHT]:
		var s := YardStandSet.new()
		sets[w] = s
		s.pressed.connect(func() -> void: ship_pressed.emit(w))
		s.hovered.connect(func(on: bool) -> void: _on_hover(w, on))
		add_child(s)
	var berths: Array[YardStandSet] = []
	for w: HullData.Weight in sets:
		berths.append(sets[w])
	(scene.life as YardFrontLife).berths = berths
	_fall = Sprite2D.new()
	_fall.centered = false
	_fall.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_fall.texture = _falloff()
	_fall.position = Vector2(0, FALL_FROM)
	add_child(_fall)
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
	_apply_light()


## The hall continued to the right (its first columns again, lit as they are),
## its floor run on under the band, and plain floor over the painted bay marks.
func _build_hall_extras() -> void:
	var L := scene.light
	var edge_m := L.material(0)
	edge_m.set_shader_parameter(&"shift_x", -float(HALL_W))
	var clip := Control.new()
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.position = Vector2(HALL_W, 0)
	clip.size = Vector2(W - HALL_W, HALL_H)
	var tr := TextureRect.new()
	tr.texture = L.hall
	tr.stretch_mode = TextureRect.STRETCH_KEEP
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.size = Vector2(HALL_W, HALL_H)
	tr.material = edge_m
	clip.add_child(tr)
	_under(clip)
	# the floor under the band: the hall's last rows again, each piece lit at its own cell
	var rows := H - HALL_H
	for cx in range(0, W, 80):
		var sx := cx if cx < HALL_W else cx - HALL_W
		var piece := _sprite(L.hall, Rect2(sx, HALL_H - rows, mini(80, HALL_W - sx), rows), Vector2(cx, HALL_H))
		piece.material = scene._mats[YardPaint.FLOOR]
		piece.set_instance_shader_parameter(&"cell", Vector2(sx + 40, HALL_H - 12))
		_under(piece)
	# plain floor over the two painted bay marks (and the copy's) and over the
	# striped hatch where the band's words go, as the mockup patched them
	var patches: Array = []
	for bx: int in [58, 448, 824]:
		for k in 3:
			patches.append([Rect2(330, 226, 110, 98), Vector2(bx + k * 110, 226)])
	patches.append([Rect2(560, 408, 80, 24), Vector2(400, 408)])
	for pr: Array in patches:
		var src: Rect2 = pr[0]
		var at: Vector2 = pr[1]
		# a patch across the hall's join is cut at it: past it the hall's light did not reach it, so it drew unlit
		if at.x < HALL_W and at.x + src.size.x > HALL_W:
			src.size.x = HALL_W - at.x
		var p := _sprite(L.hall, src, at)
		p.material = edge_m if p.position.x >= HALL_W else scene._mats[YardPaint.HALL]
		_under(p)


## Into the hall under its crew and stands: the floor they walk and stand on.
## (Laid over the scene, it hid every walker who crossed a patch or the hall's join.)
func _under(n: CanvasItem) -> void:
	scene.add_child(n)
	scene.move_child(n, _under_at)
	_under_at += 1


## A piece of the hall drawn somewhere else: scenery, which no box test reads as ink.
static func _sprite(tex: Texture2D, region: Rect2, at: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.region_enabled = true
	s.region_rect = region
	s.position = at
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return s


## The floor falls to near-black toward the frame's foot in stepped, dithered bands.
func _falloff() -> ImageTexture:
	var h := H - FALL_FROM
	var img := Image.create(W, h, false, Image.FORMAT_RGBA8)
	var bayer := [[0.0, 0.5], [0.75, 0.25]]
	for y in h:
		var k := lerpf(1.0, FALL_TO, float(y) / float(h))
		var q := k * 6.0
		var base := floorf(q)
		var frac := q - base
		for x in W:
			var thr: float = bayer[y % 2][x % 2]
			var kq := (base + (1.0 if frac > thr else 0.0)) / 6.0
			img.set_pixel(x, y, Color(0, 0, 0, 1.0 - clampf(kq, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


## Show a manufacturer's three hulls, or its three tarps when it is locked.
func show_set(m: StringName, open: bool, tier: int = 0) -> void:
	if not ready_hall:
		return
	manufacturer = m
	locked = not open
	for w: HullData.Weight in sets:
		var frame := DB.hull_for(&"korvan", w)
		var hull: HullData = DB.at_tier(DB.hull_for(m, w), tier) if open else null
		(sets[w] as YardStandSet).setup(scene, w, hull, frame)
	if locked:
		for w: HullData.Weight in sets:
			(sets[w] as YardStandSet).drop_tarp()
	_rebake()
	_apply_light()


## What is picked holds the blur round it with the pointer gone (Jon, Nov 11:
## "the blur should stay"). It is lit no differently: the deck adds no light to a ship shown.
## Why: docs/why/ChassisSelect.md#held-blur
func set_picked(w: int) -> void:
	picked = w
	if hover_w < 0:
		_focus(w)
	_apply_light()


## The ship drawn sharp over the blur: the one pointed at, else the picked one.
func _focus(w: int) -> void:
	if _ghost == null:
		return
	_sharp_set = sets.get(w) as YardStandSet if w >= 0 else _sharp_set
	if _sharp_set != null:
		_ghost.set_source(_sharp_set)


## The light's ship map: every hull's (or tarp's) pixels, shaded toward the
## belly as the Shipyard deck shades them, and the floor lamps' pools baked
## again with the hulls' shadows in them (`YardFrontPools`), on a banner, never on
## a pick. In bytes, over the hulls' box: per pixel it took 60 ms a banner click.
## Why: docs/why/ChassisSelect.md#ship-map-in-bytes
func _rebake() -> void:
	var img := Image.create_from_data(W, HALL_H, false, Image.FORMAT_RGBA8, ship_map())
	if _ship_tex == null:
		_ship_tex = ImageTexture.create_from_image(img)
	else:
		_ship_tex.update(img)
	scene.light.set_ship_map(_ship_tex)
	_bay_baked = true
	YardFrontPools.bake(self)


## The ship map's RGBA8 bytes, W x HALL_H, as the sets stand now.
func ship_map() -> PackedByteArray:
	var map := PackedByteArray()
	map.resize(W * HALL_H * 4)
	var box := Rect2i()
	for w: HullData.Weight in sets:
		var b := (sets[w] as YardStandSet).mask_into(map, W)
		if b.size != Vector2i.ZERO:
			box = b if box.size == Vector2i.ZERO else box.merge(b)
	for x in range(box.position.x, box.end.x):
		var top := -1
		var bot := -1
		for y in range(box.position.y, box.end.y):
			if map[(y * W + x) * 4] == 255:
				if top < 0:
					top = y
				bot = y
		if top < 0 or bot - top < 6:
			continue
		for y in range(top, bot + 1):
			var o := (y * W + x) * 4
			if map[o] != 255:
				continue
			var u := float(y - top) / float(bot - top)
			var k := floorf(clampf((u - 0.5) / 0.5, 0.0, 1.0) * 3.0 + 0.5) / 3.0
			map[o + 2] = clampi(int(floorf((1.0 - 0.45 * k) * 255.0 + 0.5)), 1, 255)
	return map


func _apply_light() -> void:
	if not ready_hall:
		return
	var amb := AMB_LOCKED if locked else scene.light.amb
	for m in scene.light.mats:
		m.set_shader_parameter(&"amb", amb)
	for b in banners:
		b.gloom = 0.75 if locked else 1.0
		b.queue_redraw()
	if _paint != null:
		_paint.queue_redraw()


## The lamps this tick: all full, as on the deck; a locked set's hall at half,
## two lamps stuttering in uneven steps.
func _lamp_gains() -> PackedFloat32Array:
	var g := PackedFloat32Array()
	g.resize(5)
	for i in 5:
		g[i] = 0.5 * (float(FLICK[_flick_index()]) if i in FLICK_LAMPS else 1.0) if locked else 1.0
	return g


## Whole steps, uneven, from a hash of the moment (the mockup's flick_index).
func _flick_index() -> int:
	var step := int(_t * 11.0)
	var h := (step * 7919 + 13) % 17
	return 0 if h < 9 else (1 if h < 12 else (2 if h < 15 else 3))


func _process(delta: float) -> void:
	if not ready_hall:
		return
	_t += delta
	scene.light.lamp_gain = _lamp_gains()
	if lift != null:
		_lift_t += delta
		lift.lift_at(_lift_t)
		if _lift_t >= ShipLift.front_s() and _lift_done.is_valid():
			var d := _lift_done
			_lift_done = Callable()
			d.call()
	var target := 1.0 if not launching and (hover_w >= 0 or (picked >= 0 and not locked) ) else 0.0
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


## LAUNCH: the picked hull lifts off its stands and burns off the right edge
## (Jon's L1, Nov 12), then `done`. `shake` is what shivers with it (the whole screen).
## Why: docs/why/ShipLift.md#front-door
func lift_off(w: int, shake: Control, done: Callable) -> ShipLift:
	var s: YardStandSet = sets.get(w)
	if s == null or s._view == null or lift != null:
		return null
	launching = true
	_lift_done = done
	_lift_t = 0.0
	launch_mask_begin(s)
	var L := ShipLift.new()
	L.k = 1.0
	L.floor_y = float(s.feet)
	L.rise = float(ShipLift.RISE_PX[s.weight])
	L.exit_px = float(W) + ShipLift.EXIT_CLEAR - float(s.thing.position.x)
	L.life = scene.life
	L.light = scene.light
	L.sink = func(rows: int) -> void: s.retract = rows
	L.shake_node = shake
	L.shake_rest = shake.position
	# (out under the ceiling lamps, in front of the banners: the hulls draw after them)
	L.ceiling_y = 44.0
	# the jets under the hulls, the smoke and its light over the hall, under the floor's fall
	L.setup(s._view, self, get_children().find(sets.values()[0]), _fall.get_index())
	# the hull flies with its berth (its click box goes with it, and nothing is clickable now)
	var p0 := s.position
	L.move_view = false
	L.moved = func(o: Vector2) -> void:
		s.position = p0 + o
		launch_mask_at(Vector2i(o))
		# off its stands: the floor lamps baked again with no shadow of it under them
		if o.y <= -12.0 and not s.lifted:
			s.lifted = true
			YardFrontPools.bake(self)
	lift = L
	return L


## The launching hull's pixels out of the ship map, kept to stamp back as it flies.
func launch_mask_begin(s: YardStandSet) -> void:
	_ship_map_img = Image.create_from_data(W, HALL_H, false, Image.FORMAT_RGBA8, ship_map())
	_lm_rect = Rect2i(s.thing.position - Vector2i(2, 2), s.thing.size + Vector2i(4, 4)).intersection(
		Rect2i(Vector2i.ZERO, _ship_map_img.get_size()))
	_lm_base = _ship_map_img.duplicate() as Image
	_lm_piece = Image.create(_lm_rect.size.x, _lm_rect.size.y, false, Image.FORMAT_RGBA8)
	_lm_piece.fill(Color(0, 0, 0, 0))
	for y in _lm_rect.size.y:
		for x in _lm_rect.size.x:
			var c := _ship_map_img.get_pixel(_lm_rect.position.x + x, _lm_rect.position.y + y)
			if c.r8 == 255:
				_lm_piece.set_pixel(x, y, c)
				_lm_base.set_pixel(_lm_rect.position.x + x, _lm_rect.position.y + y, Color(0, 0, 0, 0))


## The ship map with the launching hull `off` from its berth.
func launch_mask_at(off: Vector2i) -> void:
	if _lm_base == null or off == _lm_off:
		return
	_lm_off = off
	var f := _lm_base.duplicate() as Image
	f.blend_rect(_lm_piece, Rect2i(Vector2i.ZERO, _lm_piece.get_size()), _lm_rect.position + off)
	_ship_tex.update(f)


## The berth the band ties its line to.
func tie_point(w: HullData.Weight) -> Vector2:
	var s: YardStandSet = sets.get(w)
	return s.tie_point() if s != null else Vector2.ZERO


func set_of(w: HullData.Weight) -> YardStandSet:
	return sets.get(w)


## The scenery on the hall, under its crew: the banners' shadows on the wall
## and the bay paint. The stands ground themselves (`YardStandSet.paint_stands`).
func _draw_paint() -> void:
	var ci := _paint
	for x: int in BANNER_X:
		var ry := float(YardBanner.ROD_Y)
		var cl := float(YardBanner.CLOTH)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x + 4, ry + 12), Vector2(x + 52, ry + 12),
			Vector2(x + 52, ry + cl + 10), Vector2(x + 28, ry + cl + 2), Vector2(x + 4, ry + cl + 10)]),
			Color(0, 0, 0, 80.0 / 255.0))
	for box: Array in [[310, 214, 650, 340], [70, 300, 890, 380]]:
		var x0 := float(box[0])
		var y0 := float(box[1])
		var x1 := float(box[2])
		var y1 := float(box[3])
		for c: Array in [[x0, y0, 1.0, 1.0], [x1, y0, -1.0, 1.0], [x0, y1, 1.0, -1.0], [x1, y1, -1.0, -1.0]]:
			var cx := float(c[0])
			var cy := float(c[1])
			ci.draw_rect(Rect2(minf(cx, cx + 18.0 * float(c[2])), cy, 19, 1), PAINT, true)
			ci.draw_rect(Rect2(cx, minf(cy, cy + 14.0 * float(c[3])), 1, 15), PAINT, true)
		var dx := x0 + 24.0
		while dx < x1 - 24.0:
			ci.draw_rect(Rect2(dx, y1, 6, 1), PAINT, true)
			dx += 12.0


## The sharp copy of the ship pointed at, over the blurred yard.
class Ghost extends Control:
	var source: YardStandSet = null

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func set_source(s: YardStandSet) -> void:
		source = s
		material = s.sharp_material() if s != null else null
		queue_redraw()

	func _draw() -> void:
		if source != null and is_instance_valid(source):
			source.draw_sharp(self, global_position)
