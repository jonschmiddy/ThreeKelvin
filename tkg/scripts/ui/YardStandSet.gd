class_name YardStandSet
extends Control

## One berth on the ship-select screen: a hull on two of its room's posts, or a locked
## maker's tarp. The hull (or tarp) is what you click; the posts stand behind it, placed by
## PORT.md's rule (clear of the belly guns, both level, tucked behind the belly).
## Why: docs/why/ShipRoom.md#posts-clear-the-guns

signal pressed
signal hovered(on: bool)

const WEIGHTS := [HullData.Weight.LIGHT, HullData.Weight.MEDIUM, HullData.Weight.HEAVY]
## Each locked maker's own tarp (Jon, Nov 12); one with none of its own wears Solari's.
const TARP_DIR := "res://art/sprites/station/yard/tarps/%s_%s.png"
const TARP_WEIGHT := {HullData.Weight.LIGHT: "light", HullData.Weight.MEDIUM: "medium", HullData.Weight.HEAVY: "heavy"}
## The tarps drop one after another, the heavy first, and each hem ripples on its own clock.
const TARP_DELAY := {HullData.Weight.HEAVY: 0.0, HullData.Weight.MEDIUM: 0.18, HullData.Weight.LIGHT: 0.36}
const TARP_SEED := {HullData.Weight.HEAVY: 0.0, HullData.Weight.MEDIUM: 1.4, HullData.Weight.LIGHT: 2.9}
const TARP_LIFT := 12
## A post is 39 wide, centred on its column; a gun's span keeps 3 px either side clear of it.
const POST_HALF := 19
const GUN_MARGIN := 3
## A post seats on the median underside over its column +-8, all 17 present, 12 in from the hull's ends.
const SEAT_REACH := 8
const END_IN := 12
## The pair keeps at least this share of the berth's old spread.
const MIN_SPREAD := 0.8
## A post's saddle and cradle: its top rows, kept whole when it is cut or grown.
const POST_HEAD := 41
const SHAFT_ROW := 47

var weight: HullData.Weight = HullData.Weight.MEDIUM
var room: ShipRoom
var tarped: bool = false
## The hull (or tarp) box in frame pixels: the click area and what the band ties to.
var thing: Rect2i
## The posts' feet row.
var feet: int = 0
var hover: bool = false

var _view: ShipView = null
## The weapons drawn on the hull (`YardMounts.mount`), or null under a tarp.
var mounts: MountPoints = null
var _tarp: Tarp = null
## Each post's left column, their width and their (level) top row.
var post_x: Array[int] = []
var post_w: int = 39
var post_top: int = 0
## The belly guns' spans (with their margin) the posts keep clear of, in frame columns.
var guns: Array[Vector2i] = []
var _posts: Array[TextureRect] = []
## Rows the posts have sunk into the floor (`ShipLift`, as the hull lifts off).
var retract: int = 0:
	set(v):
		retract = v
		_sink_posts()
## Off its posts (`ShipLift`).
var lifted := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


## Stand `hull` with its launch `kit` here, or the weight's tarp when `hull` is null.
func setup(r: ShipRoom, w: HullData.Weight, hull: HullData, kit: Array[ModuleData], manufacturer: StringName) -> void:
	room = r
	weight = w
	tarped = hull == null
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_view = null
	_tarp = null
	mounts = null
	_posts.clear()
	post_x.clear()
	retract = 0
	lifted = false
	position = Vector2.ZERO
	size = Vector2.ZERO
	feet = int(ShipRoom.FEET[w])
	if hull != null:
		_stand_hull(hull, kit)
	else:
		_stand_tarp(manufacturer)


func _stand_hull(hull: HullData, kit: Array[ModuleData]) -> void:
	var v := ShipView.new()
	# a hull on stands: no idle flame, no running lights
	v._engines_off = true
	v.setup_preview(hull, 0, 1)
	var body := v.canvas()
	var b := belly_of(body)
	# the belly's median row two under the seat, the body's middle on the berth's (PORT.md, "Hulls")
	var at := Vector2i(int(ShipRoom.CENTRE[weight]) - b.y, int(ShipRoom.SEAT[weight]) + 2 - b.x)
	var ink := body.get_used_rect()
	thing = Rect2i(at + ink.position, ink.size)
	_frame_to(at, Vector2i(body.get_width(), body.get_height()))
	v.position = Vector2(at) - position
	v.size = Vector2(body.get_width(), body.get_height())
	v.material = room.hull_material()
	v.set_instance_shader_parameter(&"rows", Vector2(thing.position.y, thing.end.y - 1))
	_view = v
	add_child(v)
	mounts = YardMounts.mount(v, hull, kit)
	var under := undersides(body, at.x, at.y)
	var pics: Array = mounts.gun_pictures_canvas() if mounts != null else []
	guns = belly_guns(body, at, under, pics)
	_place_posts(under, room.tuck(), _hull_with_guns(body, at, pics))
	v.move_to_front()


## Where a hull meets its posts: (the median lowest row over its middle half, its columns' middle).
static func belly_of(img: Image) -> Vector2i:
	var r := img.get_used_rect()
	var x0 := r.position.x
	var x1 := r.end.x - 1
	var low: Array[int] = []
	for c in range(x0 + (x1 - x0) / 4, x1 - (x1 - x0) / 4):
		for y in range(r.end.y - 1, r.position.y - 1, -1):
			if img.get_pixel(c, y).a8 > 0:
				low.append(y)
				break
	if low.is_empty():
		return Vector2i(r.end.y - 1, (x0 + x1) / 2)
	low.sort()
	var n := low.size()
	var med := low[n / 2] if n % 2 == 1 else int(floorf((low[n / 2 - 1] + low[n / 2]) / 2.0))
	return Vector2i(med, (x0 + x1) / 2)


## Per frame column, the lowest opaque row of `img` with its top left at (`x`, `top`); -1 where none.
static func undersides(img: Image, x: int, top: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(ShipRoom.W)
	out.fill(-1)
	for c in img.get_width():
		var X := x + c
		if X < 0 or X >= ShipRoom.W:
			continue
		for y in range(img.get_height() - 1, -1, -1):
			if img.get_pixel(c, y).a8 > 0:
				out[X] = top + y
				break
	return out


## The guns' pixels that hang below the body's median underside less 6 rows, each run of
## four columns or more with a 3 px margin, in frame columns.
## Why: docs/why/ShipRoom.md#posts-clear-the-guns
static func belly_guns(body: Image, at: Vector2i, under: PackedInt32Array, pics: Array) -> Array[Vector2i]:
	var vals: Array[int] = []
	for v in under:
		if v >= 0:
			vals.append(v - at.y)
	vals.sort()
	var mid := vals[vals.size() / 2] if not vals.is_empty() else body.get_height()
	var low := PackedByteArray()
	low.resize(body.get_width())
	for p: Array in pics:
		_mark_low(body, p[0], p[1], mid - 6, low)
	var spans: Array[Vector2i] = []
	var start := -1
	for x in body.get_width() + 1:
		var on := x < body.get_width() and low[x] == 1
		if on and start < 0:
			start = x
		elif not on and start >= 0:
			if x - 1 - start >= 3:
				spans.append(Vector2i(at.x + start - GUN_MARGIN, at.x + x - 1 + GUN_MARGIN))
			start = -1
	return spans


## The columns where gun `img` (drawn in canvas rect `r`) has a pixel off the body from row `from` down.
static func _mark_low(body: Image, r: Rect2, img: Image, from: int, low: PackedByteArray) -> void:
	if img == null or r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	var sx := float(img.get_width()) / r.size.x
	var sy := float(img.get_height()) / r.size.y
	for y in range(maxi(int(r.position.y), from), int(r.end.y)):
		for x in range(int(r.position.x), int(r.end.x)):
			if x < 0 or x >= body.get_width() or low[x] == 1:
				continue
			var gx := int((x - r.position.x) * sx)
			var gy := int((y - r.position.y) * sy)
			if gx < 0 or gy < 0 or gx >= img.get_width() or gy >= img.get_height() or img.get_pixel(gx, gy).a8 == 0:
				continue
			if y >= 0 and y < body.get_height() and body.get_pixel(x, y).a8 > 0:
				continue
			low[x] = 1


## The hull with its guns' pixels on it, for the posts' contact line.
static func _hull_with_guns(body: Image, at: Vector2i, pics: Array) -> Image:
	var m := body.duplicate() as Image
	if m.get_format() != Image.FORMAT_RGBA8:
		m.convert(Image.FORMAT_RGBA8)
	for p: Array in pics:
		var r: Rect2 = p[0]
		var img: Image = p[1]
		if img == null:
			continue
		var g := img.duplicate() as Image
		g.convert(Image.FORMAT_RGBA8)
		if Vector2i(r.size) != g.get_size() and r.size.x >= 1.0 and r.size.y >= 1.0:
			g.resize(int(r.size.x), int(r.size.y), Image.INTERPOLATE_NEAREST)
		m.blend_rect(g, Rect2i(Vector2i.ZERO, g.get_size()), Vector2i(r.position))
	m.set_meta(&"at", at)
	return m


## The two posts by the rule: the clear pair nearest the berth's old posts, both level.
## Why: docs/why/ShipRoom.md#posts-clear-the-guns
func _place_posts(under: PackedInt32Array, tuck: int, over: Image) -> void:
	var c0 := int(ShipRoom.CENTRE[weight])
	var half := int(ShipRoom.APART[weight]) / 2
	var old := [c0 - half, c0 + half]
	var x0 := -1
	var x1 := -1
	for x in ShipRoom.W:
		if under[x] >= 0:
			x1 = x
			if x0 < 0:
				x0 = x
	var cands: Array[int] = []
	for c in range(x0 + END_IN, x1 - END_IN + 1):
		if _clear(c) and seat_at(under, c) >= 0:
			cands.append(c)
	var spread0 := float(old[1] - old[0])
	var best := [-1, -1, -1]
	for a in cands:
		for b in cands:
			if float(b - a) < maxf(2.0 * POST_HALF + 4.0, MIN_SPREAD * spread0):
				continue
			var cost := absi(a - old[0]) + absi(b - old[1])
			if best[0] < 0 or cost < best[0]:
				best = [cost, a, b]
	if best[0] < 0:
		# never a post through a gun: say which hull and span, and stand it at the old spots
		push_error("ship room: no pair of posts clears the %s's belly guns %s" % [HullData.weight_name(weight), guns])
		best = [0, old[0], old[1]]
	post_top = mini(seat_at(under, best[1]), seat_at(under, best[2])) - tuck
	post_x.assign([int(best[1]) - POST_HALF, int(best[2]) - POST_HALF])
	_build_posts(over)


func _clear(c: int) -> bool:
	for g in guns:
		if not (c + POST_HALF < g.x or c - POST_HALF > g.y):
			return false
	return true


## The median underside over a post's column +-8, or -1 unless all 17 columns have one.
static func seat_at(under: PackedInt32Array, c: int) -> int:
	var v: Array[int] = []
	for x in range(c - SEAT_REACH, c + SEAT_REACH + 1):
		if x >= 0 and x < under.size() and under[x] >= 0:
			v.append(under[x])
	if v.size() < 2 * SEAT_REACH + 1:
		return -1
	v.sort()
	return v[v.size() / 2]


## A post `h` rows tall from the room's tallest: its head kept, the shaft cut or repeated.
static func post_rows(src: Image, h: int) -> Image:
	var w := src.get_width()
	var out := Image.create(w, maxi(1, h), false, Image.FORMAT_RGBA8)
	var rest := src.get_height() - POST_HEAD
	var need := h - POST_HEAD
	out.blit_rect(src, Rect2i(0, 0, w, mini(POST_HEAD, h)), Vector2i.ZERO)
	if need <= 0:
		return out
	if need <= rest:
		out.blit_rect(src, Rect2i(0, src.get_height() - need, w, need), Vector2i(0, POST_HEAD))
		return out
	var grow := need - rest
	for k in grow:
		out.blit_rect(src, Rect2i(0, SHAFT_ROW, w, 1), Vector2i(0, POST_HEAD + k))
	out.blit_rect(src, Rect2i(0, POST_HEAD, w, rest), Vector2i(0, POST_HEAD + grow))
	return out


## The posts behind the hull: never a pixel over it, and a 1 px dark line where they meet
## its underside (with its guns), x0.45 (Jon, Nov 22: "Why are the clamps over the ship?").
func _build_posts(over: Image) -> void:
	var src := room.post_image()
	if src == null:
		return
	post_w = src.get_width()
	var at: Vector2i = over.get_meta(&"at", Vector2i.ZERO) if over != null else Vector2i.ZERO
	for px in post_x:
		var img := post_rows(src, feet - post_top)
		if over != null:
			_contact_line(img, over, at, px)
		var tr := TextureRect.new()
		tr.texture = ImageTexture.create_from_image(img)
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.stretch_mode = TextureRect.STRETCH_KEEP
		tr.clip_contents = true
		tr.material = room.thing_material()
		add_child(tr)
		_posts.append(tr)
	_frame_to(Vector2i(post_x.min(), post_top), Vector2i(post_x.max() + post_w - post_x.min(), feet - post_top))
	for i in _posts.size():
		_posts[i].position = Vector2(post_x[i], post_top) - position
		_posts[i].size = Vector2(post_w, feet - post_top)


## The post's pixels in the first row under the hull (with its kit), column by column, x0.45.
func _contact_line(img: Image, over: Image, at: Vector2i, px: int) -> void:
	for c in img.get_width():
		var ox := px + c - at.x
		if ox < 0 or ox >= over.get_width():
			continue
		var last := -1
		for y in range(over.get_height() - 1, -1, -1):
			if over.get_pixel(ox, y).a8 > 0:
				last = y
				break
		var r := at.y + last + 1 - post_top
		if last >= 0 and r >= 0 and r < img.get_height():
			var p := img.get_pixel(c, r)
			if p.a8 > 0:
				img.set_pixel(c, r, Color(p.r * 0.45, p.g * 0.45, p.b * 0.45, p.a))


## Rows sunk into the floor: each post drawn lower and cut at its feet.
func _sink_posts() -> void:
	pin_posts()


## The posts where they stand in the frame, however the berth has moved (a launch flies it).
func pin_posts() -> void:
	for i in _posts.size():
		var tr := _posts[i]
		if is_instance_valid(tr) and i < post_x.size():
			var h := maxi(0, feet - post_top - retract)
			tr.position = Vector2(post_x[i], post_top + retract) - position
			tr.size.y = h
			tr.visible = h > 0


## Grow the control to cover a frame rect, keeping every child where it stands in the frame.
func _frame_to(at: Vector2i, sz: Vector2i) -> void:
	var r := Rect2(position, size) if size != Vector2.ZERO else Rect2(Vector2(at), Vector2.ZERO)
	var n := r.merge(Rect2(Vector2(at), Vector2(sz)))
	var d := n.position - position
	for c in get_children():
		(c as Control).position -= d
	position = n.position
	size = n.size


func _stand_tarp(manufacturer: StringName) -> void:
	var tx := load(tarp_file(manufacturer, weight)) as Texture2D
	_tarp = Tarp.new()
	_tarp.setup(tx, float(TARP_DELAY[weight]), float(TARP_SEED[weight]))
	var bb := _tarp.image.get_used_rect() if _tarp.image != null else Rect2i()
	# the tarps sit hem over the stand tops (PORT.md: hem 34/34/30)
	var at := Vector2i(int(ShipRoom.CENTRE[weight]) - (bb.position.x + bb.end.x) / 2,
		int(ShipRoom.SEAT[weight]) + int(ShipRoom.HEM[weight]) - bb.end.y)
	thing = Rect2i(at, Vector2i(_tarp.tex_w, _tarp.tex_h))
	_frame_to(Vector2i(at.x - 4, at.y - TARP_LIFT), Vector2i(_tarp.tex_w + 8, _tarp.tex_h + TARP_LIFT + 12))
	_tarp.material = room.hull_material()
	_tarp.set_instance_shader_parameter(&"rows", Vector2(at.y + bb.position.y, at.y + bb.end.y - 1))
	add_child(_tarp)
	guns.clear()
	if _tarp.image != null:
		_place_posts(undersides(_tarp.image, at.x, at.y), room.tuck(), null)
	_tarp.position = Vector2(at.x - 4, at.y - TARP_LIFT) - position
	_tarp.move_to_front()


## The maker's tarp for this weight (one with none of its own wears Solari's).
static func tarp_file(manufacturer: StringName, w: HullData.Weight) -> String:
	var f := TARP_DIR % [String(manufacturer), String(TARP_WEIGHT[w])]
	return f if ResourceLoader.exists(f) else TARP_DIR % ["solari", String(TARP_WEIGHT[w])]


## Where the band's words tie to this berth: the hull's middle at its posts' feet.
func tie_point() -> Vector2:
	return Vector2(thing.position.x + thing.size.x / 2, feet - 2)


## Only the hull's or the tarp's own pixels are the thing: the posts, the air and
## the box's empty corners are "away", where a click clears the pick (Jon, Nov 11).
func _has_point(p: Vector2) -> bool:
	return on_ink(p + position)


## Is the frame point `at` on the hull's (or the settled tarp's) opaque pixels?
func on_ink(at: Vector2) -> bool:
	if not thing.has_point(Vector2i(at)):
		return false
	var img: Image = null
	var corner := Vector2.ZERO
	if _view != null:
		img = _view.canvas()
		corner = position + _view.position
	elif _tarp != null:
		img = _tarp.image
		corner = Vector2(thing.position)
	if img == null:
		return true
	var q := Vector2i((at - corner).floor())
	if q.x < 0 or q.y < 0 or q.x >= img.get_width() or q.y >= img.get_height():
		return false
	return img.get_pixel(q.x, q.y).a8 >= 128


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
	return room.hull_material() if room != null else null


## The hull or the tarp alone, drawn into `ci` at its own place on the frame:
## the sharp copy the hover lays over the blurred room.
func draw_sharp(ci: CanvasItem, origin: Vector2) -> void:
	if _view != null:
		ci.draw_texture_rect(_view.texture, Rect2(_view.global_position - origin, _view.size), false)
	elif _tarp != null:
		_tarp.paint(ci, _tarp.global_position - origin)


## Start the tarps falling now (a locked set just came in).
func drop_tarp() -> void:
	if _tarp != null:
		_tarp.drop()


## THE TARP: the art posed row by row in whole pixels. It falls from twelve
## rows up, lands, sags, springs back and settles; at rest, every few seconds,
## the hall's air ripples the loose hem sideways while the body never moves.
## A room may give it wind instead (`set_wind`): its material moves the cloth.
class Tarp extends Control:
	## A wind texture's margin round the art, each side and below.
	const WIND_PAD := 6
	## The wind eases in over this long once the tarp has settled.
	const WIND_IN := 0.6
	var texture: Texture2D
	var image: Image
	var tex_w: int = 0
	var tex_h: int = 0
	var delay: float = 0.0
	var seed_s: float = 0.0
	## The room's wind texture (the art padded by WIND_PAD, its hold field under it), or null.
	var wind: Texture2D = null
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

	## Draw the cloth from a room's wind texture: its material ripples it in place (Old hangar).
	func set_wind(t: Texture2D) -> void:
		wind = t
		queue_redraw()

	## How much of the wind the cloth takes: none while it drops, easing in once it has settled.
	func wind_k() -> float:
		return clampf((maxf(_u, 0.0) - 0.56) / WIND_IN, 0.0, 1.0)

	func _process(dt: float) -> void:
		_u += dt
		var key := str(pose()) + (str(snappedf(wind_k(), 0.02)) if wind != null else "")
		if key != _last_key:
			_last_key = key
			queue_redraw()

	## (lift, stretch at the top, sag at the hem, flutter phase or -1) at this moment.
	func pose() -> Array[float]:
		var u := maxf(_u, 0.0)  # (waiting its turn, it hangs at the top of its fall: a stand is never bare)
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
		# with wind, the rows come from the wind texture (art WIND_PAD in), its draw colour saying how much wind
		var tx := wind if wind != null else texture
		var sx := float(WIND_PAD) if wind != null else 0.0
		if lift != 0.0 or stretch != 0.0 or sag != 0.0:
			var still := Color(0.0, 1.0, 1.0, 1.0) if wind != null else Color.WHITE
			var last_y := -1000
			for r in tex_h:
				var f := float(r) / float(maxi(1, tex_h - 1))
				var y := r + int(round(lift - stretch * (1.0 - f) + sag * f * f))
				var row := Rect2(sx, r, tex_w, 1)
				# a row that leaves a gap under the one above fills it with itself
				while last_y > -1000 and last_y + 1 < y:
					last_y += 1
					ci.draw_texture_rect_region(tx, Rect2(ox, oy + last_y, tex_w, 1), row, still)
				if y > last_y:
					ci.draw_texture_rect_region(tx, Rect2(ox, oy + y, tex_w, 1), row, still)
					last_y = y
			return
		if wind != null:
			var pad := float(WIND_PAD)
			var box := Vector2(tex_w + 2.0 * pad, tex_h + pad)
			ci.draw_texture_rect_region(wind, Rect2(Vector2(ox - pad, oy), box), Rect2(Vector2.ZERO, box), Color(wind_k(), 1.0, 1.0, 1.0))
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
