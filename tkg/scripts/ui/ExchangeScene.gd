class_name ExchangeScene
extends ShopScene

## The Exchange: one of Jon's five rooms, with your hold standing in it.
##
## THE SHOP'S ROOM, FACING THE OTHER WAY. Jon laid out one room per development
## level on the Exchange's own bench (`room_bench.py --deck exchange`), and
## `tools/room_install.py` installed them beside the shop's, under
## `decks.exchange` in rooms.json. Everything `ShopScene` does -- the plate, the
## openings, the lamps, the light, the dust, the counter's lit marks -- this does
## the same way, from the same code. What differs is three things.
##
## THE HOLD STANDS WHERE THE RACK DID. It is three frames, one per hull size,
## fitted round a 4x3, 5x4 and 6x5 grid of 40px cells (`tools/cage_fit.py`). The
## room was laid out round the heavy frame; a lighter hull's stands on the same
## spot, centred, its feet on the same floor, as the bench previews it. The frame
## is drawn here, between what stands behind the furniture and what stands in
## front of it, and the hold itself -- `HoldGrid`, live, packable, draggable --
## stands in its opening (`hold_opening`).
##
## THE WALL IS THE STATION'S. An Exchange stands in its own station's shop
## plate: the shop picks one of its level's three plates off the seed and so does
## this, so two decks of one station are built of the same stuff. Jon laid each
## Exchange out on one wall and chose this over keeping it (2026-09-27, "A"):
## a station's shop and Exchange match, and each of his rooms stands on all
## three of its level's walls. The wall in his layout is only the fallback.
##
## SPACE OUTSIDE, AND IT IS THIS STATION'S. The view is `SpaceBackdrop` -- the
## sky the sector shows when you are here -- drawn once into a picture the size of
## the room, with its world framed in the room's biggest clear window
## (`sky_frame`, worked out by the installer). A station arm was generated to
## stand across it and Jon cut all five: "a disembodied space station arm
## doesn't make sense" (2026-09-27). Nobody walks past; now and then a ship does.

## THE VIEW IS NOT THE ROOM'S TO LIGHT. The shop hands a window over to the
## room across a few pixels; on black space that band came out as a grey ring
## round the door's edges and round everything standing in front of it (Jon,
## 2026-09-27: "why is there a weird outline ?"). So the room carries its view
## pixel for pixel, one channel per hold size (`room_install.view_masks`), and
## the light leaves exactly those pixels alone.
const VIEW_SIZES := ["s", "m", "l"]

## The ships that pass, at two distances. See `tools/flyby_ships.py`.
const FLYBY_JSON := "res://art/sprites/station/flyby/flyby.json"
## A ship sets off about this often, in seconds. One crosses the whole wall in
## ten to forty, and is seen only while it is behind a window.
const FLY_EVERY := 19.0

## Which hull's frame stands: "s", "m" or "l". Set through `fit_hold`.
var hold_size := "l"
## The station whose sky is outside.
var sky_node: MapGen.MapNode = null

var _view_tex: ImageTexture = null
var _sky_vp: SubViewport = null
var _sky: SpaceBackdrop = null
var _sky_for: MapGen.MapNode = null

static var _fleet: Array = []
static var _fleet_read := false


## The Exchange room a station of this level has.
static func exchange_room_for(dev: int, seed: int) -> Dictionary:
	return deck_room_for("exchange", dev, seed)


func _plate_cache_key() -> StringName:
	if room.is_empty():
		return &""
	var sky := sky_node.index if sky_node != null else -1
	return StringName("exchange:%s:%s:%d:%d:%d" % [room.get("slug", ""), _plate_name(),
		place_seed, dev, sky])


## The station's shop plate, or the room's own if the shop has none. Asked on
## every draw (the plate key has it in), so it is worked out once per station.
func _plate_name() -> String:
	var at := [dev, place_seed, String(room.get("slug", ""))]
	if at != _plate_at:
		_plate_at = at
		var p := String(ShopScene.room_for(dev, place_seed).get("plate", ""))
		_plate_file = p if p != "" else String(room.get("plate", ""))
	return _plate_file


var _plate_at: Array = []
var _plate_file := ""


func _load_room() -> void:
	super()
	var names: Array[String] = []
	for f in _frames().values():
		names.append(String((f as Dictionary).get("art", "")))
	names.append(String(((room.get("hold", {}) as Dictionary).get("hook", {}) as Dictionary).get("art", "")))
	for n in names:
		if n != "" and not _tex.has(n) and ResourceLoader.exists(ROOMS_DIR + n):
			_tex[n] = load(ROOMS_DIR + n) as Texture2D
	# Off disk like the light, NOT imported: its colour is data.
	_view_tex = null
	var vf := String((room.get("light", {}) as Dictionary).get("view", ""))
	if vf != "" and FileAccess.file_exists(ROOMS_DIR + vf):
		var img := Image.new()
		if img.load_png_from_buffer(FileAccess.get_file_as_bytes(ROOMS_DIR + vf)) == OK:
			_view_tex = ImageTexture.create_from_image(img)
		else:
			push_warning("exchange: could not read %s" % vf)


func _setup_light() -> void:
	super()
	_show_view()


## Which of the view's channels the light reads: the frame that hangs.
func _show_view() -> void:
	if _light_node == null or not _light_node.visible:
		return
	_light_node.set_param(&"view_mask", _view_tex)
	_light_node.set_param(&"view_k", VIEW_SIZES.find(hold_size) if _view_tex != null else -1)


# ---------------------------------------------------------------------- hold

func _frames() -> Dictionary:
	return (room.get("hold", {}) as Dictionary).get("frames", {})


## The frame for a hold `grid` cells big: the smallest whose opening takes it.
## Every hull's hold is one of the three exactly; anything else gets room.
func fit_hold(grid: Vector2i) -> void:
	var want := Vector2(grid) * float(HoldGrid.CELL)
	var best := "l"
	var best_area := INF
	for z in _frames():
		var op: Array = (_frames()[z] as Dictionary).opening
		var o := Vector2(float(op[2]), float(op[3]))
		if o.x >= want.x and o.y >= want.y and o.x * o.y < best_area:
			best = z
			best_area = o.x * o.y
	if best != hold_size:
		hold_size = best
		_show_view()
		queue_redraw()


## Where the standing frame is: `drawHold` in the bench -- on the heavy frame's
## spot, centred, its foot on the same floor.
func frame_rect() -> Rect2:
	return frame_at(room.get("hold", {}), hold_size)


## Where a room's frame of size `z` stands, from its installed `hold` entry.
## `ArtCheck` asks it of all three.
static func frame_at(h: Dictionary, z: String) -> Rect2:
	var f: Dictionary = (h.get("frames", {}) as Dictionary).get(z, {})
	if h.is_empty() or f.is_empty():
		return Rect2()
	var w := float(f.w)
	var fh := float(f.h)
	return Rect2(float(h.x) + roundf((float(h.w) - w) / 2.0), float(h.y) + float(h.h) - fh, w, fh)


## The frame's opening, in the room: where the hold's grid stands.
func hold_opening() -> Rect2:
	var fr := frame_rect()
	var f: Dictionary = _frames().get(hold_size, {})
	if not fr.has_area():
		return Rect2()
	var op: Array = f.opening
	return Rect2(fr.position + Vector2(float(op[0]), float(op[1])),
		Vector2(float(op[2]), float(op[3])))


func _draw_furniture() -> void:
	var f: Dictionary = _frames().get(hold_size, {})
	var t: Texture2D = _tex.get(String(f.get("art", "")), null)
	var fr := frame_rect()
	if t != null and fr.has_area():
		draw_texture(t, fr.position)
		_hang(fr, float(f.get("hook_y", 0)))


## THE HOLD HANGS FROM A WIRE (Jon, 2026-09-27: "a box that is suspended by a
## wire (like the original generated design)"): a crane hook over the frame's
## top middle, caught on it by `into` pixels, and the hook picture's own top
## rows of rope repeated up to the ceiling -- `hangHold` in the bench.
func _hang(fr: Rect2, catch_y: float) -> void:
	var hk: Dictionary = (room.get("hold", {}) as Dictionary).get("hook", {})
	var im: Texture2D = _tex.get(String(hk.get("art", "")), null)
	if im == null:
		return
	var rope := float(hk.get("rope", 8))
	var w := float(im.get_width())
	# caught on the frame's top beam, not the air above it in its picture
	var at := Vector2(fr.position.x + roundf((fr.size.x - w) / 2.0),
		fr.position.y + catch_y + float(hk.get("into", 6)) - float(im.get_height()))
	var ry := at.y
	while ry > 0.0:
		var hgt := minf(rope, ry)
		draw_texture_rect_region(im, Rect2(at.x, ry - hgt, w, hgt), Rect2(0.0, rope - hgt, w, hgt))
		ry -= rope
	draw_texture(im, at)


# ----------------------------------------------------------------------- sky

## The station's sky in place of the concourse the base room picked.
func _choose_view() -> void:
	_ensure_sky()
	_backdrop = _sky_vp.get_texture()
	_bd_id = StringName("space_" + level_name(dev))
	# Top of the picture on the ceiling: space has no floor to stand on the
	# floor line, and the picture is exactly the room.
	_bd_drop = PANEL.y - float(doc().get("floor_y", 353))
	_reflect = false


func _ensure_sky() -> void:
	if _sky_vp == null:
		_sky_vp = SubViewport.new()
		_sky_vp.size = Vector2i(PANEL)
		_sky_vp.transparent_bg = false
		_sky_vp.disable_3d = true
		_sky_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(_sky_vp)
	# A NEW STATION IS A NEW SKY. `SpaceBackdrop.setup` keys on the node's
	# index, which a later map reuses, so a different node gets a fresh one.
	if _sky == null or _sky_for != sky_node:
		if _sky != null:
			_sky.queue_free()
		_sky = SpaceBackdrop.new()
		_sky.size = PANEL
		_sky_vp.add_child(_sky)
		_sky_for = sky_node
	var fr: Variant = room.get("sky_frame", null)
	_sky.frame_in = Rect2(float(fr[0]), float(fr[1]), float(fr[2]), float(fr[3])) \
		if fr is Array else Rect2()
	if sky_node != null:
		_sky.setup(sky_node)
	_sky.queue_redraw()
	# DRAWN ONCE. The sky holds still; the ships going by are drawn over it in
	# the room, so the picture never has to be made again until the room is.
	_sky_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


# --------------------------------------------------------------------- ships

static func _fleet_list() -> Array:
	if not _fleet_read:
		_fleet_read = true
		if FileAccess.file_exists(FLYBY_JSON):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FLYBY_JSON))
			if parsed is Dictionary:
				for s in (parsed as Dictionary).get("ships", []):
					var d: Dictionary = s
					var e := {"facing": int(d.get("facing", 1))}
					for depth in ["far", "near"]:
						var path := "res://art/sprites/station/flyby/" + String(d.get(depth, ""))
						if ResourceLoader.exists(path):
							e[depth] = load(path) as Texture2D
					if e.has("far") and e.has("near"):
						_fleet.append(e)
	return _fleet


## No walkers: nobody is out there.
func _build_cast(_bd: StringName) -> void:
	_cast.clear()


## Where the passing ships are at the room's clock. A pass is chosen off its
## number and the station's seed -- which ship, how far off, how fast, how high
## -- so a pass is where the clock says without anything being kept.
func _pose_cast() -> void:
	_posed_at = _clock
	_posed.clear()
	var fleet := _fleet_list()
	if no_people or fleet.is_empty():
		return
	# THROUGH THE WINDOW THE WORLD IS IN, mostly: the ships cross the sky's
	# frame, where the eye already is, and anywhere else as high.
	var fr: Variant = room.get("sky_frame", null)
	var band := Rect2(float(fr[0]), float(fr[1]), float(fr[2]), float(fr[3])) \
		if fr is Array else Rect2(0.0, 80.0, PANEL.x, 180.0)
	var salt := float(absi(place_seed) % 9973) * 0.013
	var n1 := int(floorf(_clock / FLY_EVERY))
	for n in range(n1 - 3, n1 + 1):
		var t0: float = float(n) * FLY_EVERY + _roll(n, 1.0, salt) * FLY_EVERY * 0.6
		if _clock < t0:
			continue
		var ship: Dictionary = fleet[int(_roll(n, 2.0, salt) * float(fleet.size())) % fleet.size()]
		var far: bool = _roll(n, 3.0, salt) < 0.6
		var tex: Texture2D = ship.far if far else ship.near
		var sz := Vector2(tex.get_size())
		var speed: float = (18.0 + 12.0 * _roll(n, 4.0, salt)) if far 			else (38.0 + 26.0 * _roll(n, 4.0, salt))
		var run: float = (_clock - t0) * speed
		if run > PANEL.x + sz.x:
			continue
		var dir := int(ship.facing)
		var x: float = (-sz.x + run) if dir > 0 else (PANEL.x - run)
		var y: float = band.position.y + band.size.y * (0.12 + 0.6 * _roll(n, 5.0, salt)) 			- sz.y * 0.5
		# Farther is dimmer and bluer: there is more nothing in the way.
		var tint := Color(0.62, 0.68, 0.80) if far else Color(0.86, 0.89, 0.96)
		_posed.append([tex, Vector2(floorf(x), floorf(y)), tint])


## One roll for pass `n`: which ship, how far, how fast, how high.
static func _roll(n: int, k: float, salt: float) -> float:
	return ShopLight.hash1(float(n) * 7.31 + k * 3.17 + salt)


## The ships inside one clip of view.
func _shop_cast(clip: Rect2) -> void:
	for p in _posed:
		var tex: Texture2D = p[0]
		var at: Vector2 = p[1]
		var r := Rect2(at, Vector2(tex.get_size()))
		var cr := r.intersection(clip)
		if cr.has_area():
			draw_texture_rect_region(tex, cr, Rect2(cr.position - at, cr.size), p[2])
