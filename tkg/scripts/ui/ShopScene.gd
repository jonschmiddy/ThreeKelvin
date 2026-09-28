class_name ShopScene
extends StationRoom

## The room the Promenade's shop stands in: one of Jon's fifteen.
##
## THE ROOM IS HIS AND IT IS DATA. Jon laid out three rooms per development
## level on the room bench, and `tools/room_install.py` put them in
## `art/sprites/station/rooms/` -- every plate, prop, lamp and door at the size
## it is drawn, and each room's light worked out ahead of time. A station picks
## one of its level's three off its seed, the way it picks its backdrop, and
## this draws it the way the bench draws it: the same passes in the same order,
## the same pixels. Nothing about where a thing stands is decided here.
##
## THE BENCH IS THE REFERENCE. Where this file and `tools/room_bench.tmpl.html`
## disagree, this file is wrong. Each function below names the bench function
## it ports.
##
## FIVE LAYERS, BECAUSE THE RACK AND THE COUNTER ARE LIVE. The stock on the
## rack can be picked up and the counter takes it, so both are nodes of their
## own and the room is drawn around them:
##
##   this node   the plate, the openings and the concourse through them, and
##               whatever the bench draws before the furniture or clear of it
##   (furniture) the rack and its stock, the counter -- `StationScreen`'s
##   front       what the bench draws after the furniture and over it: the
##               haze, a prop Jon stood in front, the lamps
##   light       the room's light, over all of the above (`ShopLight.Overlay`)
##   glow        dust, lamp glass, lit panels, and the shop's own marks
##
## `StationScreen` stacks them in that order; the three above the furniture
## come from `front_layer`, `light_layer` and `glow_layer`. Which side of the
## furniture a thing goes is `room_install.py`'s call, made from the bench's
## draw order: Jon keeps his racks and counters in the WALL band, where they
## neither cast a shadow nor sit in one, so the haze comes in front of them.
##
## NO LIVERY. The old room tinted its trim in the manufacturer's colour and hung
## cables in front; the bench has neither, so neither does this (the port
## plan's option 2A). Other decks keep theirs.

const ROOMS_DIR := "res://art/sprites/station/rooms/"
const ROOMS_JSON := ROOMS_DIR + "rooms.json"

## The fixed wall the rooms were laid out on. The panel is this size on the
## Promenade; a different size draws the room at its top-left regardless.
const PANEL := Vector2(740.0, 431.0)

## A room to use instead of the seed's, by slug (`unclaimed_scrap`), for
## `stationshot room=`.
static var forced_room := ""
## Draw rooms unlit, as the bench's fullbright does. For `stationshot lights=off`.
static var fullbright := false
## THE SHOP'S OWN MARKS OVER THE LIGHT: prices, rarity lights, the counter's
## quote. See `ShopLight.Glow`. False lights them with the room, as the bench does.
static var lit_marks := true
## Nobody behind the glass, no dust and no failing lamps, for `stationshot
## people=0 motes=0 steady`: a room that holds still to be compared with the
## bench pixel for pixel.
static var no_people := false
static var no_motes := false
static var steady := false
## The room's clock held at this many milliseconds, for `stationshot clock=`:
## a failing lamp caught at a known moment, to set beside the bench's render
## of the same moment. Below zero the clock runs.
static var pin_clock_ms := -1.0

static var _doc: Dictionary = {}
static var _doc_read := false


## rooms.json, read once.
static func doc() -> Dictionary:
	if not _doc_read:
		_doc_read = true
		if FileAccess.file_exists(ROOMS_JSON):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOMS_JSON))
			if parsed is Dictionary:
				_doc = parsed
	return _doc


## The name rooms.json files a development level under.
static func level_name(dev: int) -> String:
	match dev:
		MapGen.Development.UNCLAIMED: return "unclaimed"
		MapGen.Development.OUTPOST: return "outpost"
		MapGen.Development.SETTLEMENT: return "settlement"
		MapGen.Development.CAPITAL: return "capital"
		_: return "city"


## The room a station of this level has, off its seed. Empty with no rooms
## installed, which draws nothing -- the furniture still stands.
static func room_for(dev: int, seed: int) -> Dictionary:
	var rooms: Array = doc().get("rooms", [])
	if forced_room != "":
		for r in rooms:
			if String((r as Dictionary).get("slug", "")) == forced_room:
				return r
		print("  no shop room '%s' -- the seed's" % forced_room)
	var names: Array = (doc().get("levels", {}) as Dictionary).get(level_name(dev), [])
	if names.is_empty():
		return {}
	var want: String = names[absi(hash([seed, &"room"])) % names.size()]
	for r in rooms:
		if String((r as Dictionary).get("slug", "")) == want:
			return r
	return {}


## A room of another deck installed beside the shop's (`decks.<deck>` in
## rooms.json), for this station's level, off its seed -- the Exchange's.
static func deck_room_for(deck: String, dev: int, seed: int) -> Dictionary:
	var d: Dictionary = (doc().get("decks", {}) as Dictionary).get(deck, {})
	var rooms: Array = d.get("rooms", [])
	if forced_room != "":
		for r in rooms:
			if String((r as Dictionary).get("slug", "")) == forced_room:
				return r
	var names: Array = (d.get("levels", {}) as Dictionary).get(level_name(dev), [])
	if names.is_empty():
		return {}
	var want: String = names[absi(hash([seed, StringName(deck)])) % names.size()]
	for r in rooms:
		if String((r as Dictionary).get("slug", "")) == want:
			return r
	return {}


## This station's room, set by the screen through `set_room`.
var room: Dictionary = {}

## Every picture the room draws, by file name. Loaded with the plate, never in
## a draw call -- see `_plate_key` on the white-texture trap.
var _tex: Dictionary = {}
## The light, as `room_install.py` stored it: one RGBA8 picture of four bands,
## kept as bytes for the dust to read and as a texture for the shader.
var _light_bytes := PackedByteArray()
var _light_tex: ImageTexture = null
var _light_w := 0
var _light_h := 0
var _scales: Array = [[8.0, 8.0, 8.0, 8.0], [8.0, 32.0, 1.0, 1.0]]
## The backdrop's colour, which is what the openings glow.
var _tone := Vector3(0.72, 0.80, 1.0)
## The failing lamp this frame: f times its fault-tinted colour, and f.
var _flick_col := Vector3.ZERO
var _flick_f := 0.0

var _lamps_node: Control = null
var _light_node: ShopLight.Overlay = null
var _glow_node: ShopLight.Glow = null

## The live furniture, so the glow layer can keep its marks readable.
var shelf_node: Control = null
var till_node: Control = null


func _init() -> void:
	# The concourse through the glass is drawn as it is, untinted: the bench
	# never cooled it, and the opening's own glass does the rest.
	_view_tint = Color.WHITE


## Put this station's room up. Loads on the next draw, as every plate does.
func set_room(r: Dictionary) -> void:
	if r == room:
		return
	room = r
	queue_redraw()


func plate_id() -> StringName:
	return &"shop" if not room.is_empty() else &""


func _plate_cache_key() -> StringName:
	if room.is_empty():
		return &""
	return StringName("shop:%s:%d:%d" % [room.get("slug", ""), place_seed, dev])


## The openings as `StationRoom` counts them, so its views and its 30 Hz clock
## run for this room too.
func openings(_w: float, _h: float, _floor_y: float) -> Array:
	var out := []
	for o in room.get("openings", []):
		var d: Dictionary = o
		out.append({rect = Rect2(float(d.x), float(d.y), float(d.w), float(d.h)),
			kind = StringName(d.type)})
	return out


func banner_spots() -> Array:
	return []


## The rack's box on the wall, at the size it is drawn (twice its art).
func rack_rect() -> Rect2:
	var r: Dictionary = room.get("rack", {})
	return Rect2(float(r.get("x", 0)), float(r.get("y", 0)), float(r.get("w", 0)),
		float(r.get("h", 0)))


func rack_art() -> Texture2D:
	return _tex.get(String((room.get("rack", {}) as Dictionary).get("art", "")), null)


## Where this rack's boards are, in its own art's rows.
func rack_boards() -> Array:
	return (room.get("rack", {}) as Dictionary).get("boards", [59, 122])


func till_rect() -> Rect2:
	var r: Dictionary = room.get("till", {})
	var t: Texture2D = till_art()
	var sz := Vector2(t.get_size()) if t != null else Vector2(float(r.get("w", 0)), float(r.get("h", 0)))
	return Rect2(Vector2(float(r.get("x", 0)), float(r.get("y", 0))), sz)


func till_art() -> Texture2D:
	return _tex.get(String((room.get("till", {}) as Dictionary).get("art", "")), null)


## The furniture's art is only there once the plate has loaded; the screen asks
## again when it is.
signal room_loaded


# ------------------------------------------------------------------- loading

func _load_plate(key: StringName) -> void:
	_load_room()
	super(key)
	_choose_view()
	_tone = _tone_of(_bd_id)
	_setup_light()
	for n in [_lamps_node, _glow_node]:
		if n != null:
			(n as CanvasItem).queue_redraw()
	room_loaded.emit()


func _load_room() -> void:
	_tex.clear()
	var files: Array[String] = [_plate_name()]
	for key in ["rack", "till"]:
		files.append(String((room.get(key, {}) as Dictionary).get("art", "")))
	for band in ["back", "front"]:
		for p in room.get(band, []):
			if (p as Dictionary).has("art"):
				files.append(String(p.art))
	for o in room.get("openings", []):
		var d: Dictionary = o
		if d.has("art"):
			files.append(String(d.art))
		if d.has("frame"):
			files.append("../" + String(d.frame))
	for l in room.get("lamps", []):
		files.append(String(l.art))
		files.append(String(l.glass))
	for g in room.get("glass", []):
		files.append(String(g.art))
	for f in files:
		if f == "" or _tex.has(f):
			continue
		var path := ROOMS_DIR + f
		if ResourceLoader.exists(path):
			_tex[f] = load(path) as Texture2D
	_load_light()


## The room's light, off disk: a PNG decoded straight to bytes, NOT imported --
## an import is free to touch the colour of a transparent pixel, and here the
## colour is data.
func _load_light() -> void:
	_light_bytes = PackedByteArray()
	_light_tex = null
	var lf: String = (room.get("light", {}) as Dictionary).get("file", "")
	var path := ROOMS_DIR + lf
	if lf == "" or not FileAccess.file_exists(path):
		return
	var img := Image.new()
	if img.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
		push_warning("shop: could not read %s" % path)
		return
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var ls: Array = doc().get("light_size", [370, 216])
	_light_w = int(ls[0])
	_light_h = int(ls[1])
	if img.get_width() != _light_w or img.get_height() != _light_h * 4:
		push_warning("shop: %s is %dx%d" % [path, img.get_width(), img.get_height()])
		return
	_scales = doc().get("light_scales", _scales)
	_light_bytes = img.get_data()
	_light_tex = ImageTexture.create_from_image(img)


static func _tone_of(bd: StringName) -> Vector3:
	var t: Variant = (doc().get("tones", {}) as Dictionary).get(String(bd), null)
	if t is Array and (t as Array).size() == 3:
		return Vector3(float(t[0]), float(t[1]), float(t[2]))
	return Vector3(0.72, 0.80, 1.0)


# ------------------------------------------------------------------- drawing

## The bench's `draw()`, up to the furniture: the room, what is seen through
## it, the wall band, the haze, the floor band.
func _draw() -> void:
	var key := _plate_cache_key()
	if key == &"":
		return
	if _plate_key != key:
		_load_plate.call_deferred(key)
		return
	if pin_clock_ms >= 0.0:
		_clock = pin_clock_ms / 1000.0
	var plate: Texture2D = _tex.get(_plate_name(), null)
	if plate == null:
		return
	# `drawRoom`: the plate is the whole room at its size.
	draw_texture(plate, Vector2.ZERO)
	if _backdrop != null:
		# `backdrop()`: centred across the wall, its foot on the floor line,
		# dropped by its own height off the heights page.
		var bs := Vector2(_backdrop.get_size())
		_bd_pos = Vector2(floorf((PANEL.x - bs.x) * 0.5 + 0.5),
			float(doc().get("floor_y", 353)) - bs.y + floorf(_bd_drop + 0.5))
	_pose_cast()
	for o in room.get("openings", []):
		var d: Dictionary = o
		match String(d.type):
			"open": _open_hole(d)
			"door": _door_hole(d)
			"window": _window_hole(d)
	_draw_list(self, room.get("back", []))
	_draw_furniture()
	_frame_light()


## The picture the room stands on. The Exchange's is the station's shop's.
func _plate_name() -> String:
	return String(room.get("plate", ""))


## Furniture the room draws itself, between what stands behind the live
## furniture and what stands in front of it. The shop's is all live.
func _draw_furniture() -> void:
	pass


## What is seen through the openings, once the base room has picked a
## concourse. The shop keeps the concourse.
func _choose_view() -> void:
	pass


## A run of the bench's draw order onto one canvas: sprites where they stand,
## and the haze where it falls in the order.
func _draw_list(c: CanvasItem, list: Array) -> void:
	for p in list:
		var d: Dictionary = p
		if d.has("haze"):
			_draw_bench_haze(c)
			continue
		var t: Texture2D = _tex.get(String(d.art), null)
		if t != null:
			c.draw_texture(t, Vector2(float(d.x), float(d.y)))


## The haze between the wall and the deck: fourteen bands from ninety above the
## floor to the foot of the room, each a row taller than its slot as the bench
## has them.
func _draw_bench_haze(c: CanvasItem) -> void:
	var fl := float(doc().get("floor_y", 353))
	var top := fl - 90.0
	var bh := (PANEL.y - top) / 14.0
	for b in 14:
		var a := 0.12 * minf(1.0, float(b + 1) / 14.0 * 1.4)
		c.draw_rect(Rect2(0.0, top + bh * float(b), PANEL.x, bh + 1.0),
			Color(69.0 / 255.0, 89.0 / 255.0, 120.0 / 255.0, a))


# ------------------------------------------------------------------ openings

## The concourse behind a span of wall, and the people in it. Every opening is
## drawn out of these, one rect at a time.
func _view_span(span: Rect2) -> void:
	draw_rect(span, DEEP)
	if _backdrop != null:
		var bs := Vector2(_backdrop.get_size())
		var src := Rect2(span.position - _bd_pos, span.size).intersection(Rect2(Vector2.ZERO, bs))
		if src.has_area():
			draw_texture_rect_region(_backdrop, Rect2(src.position + _bd_pos, src.size), src)
		_shop_cast(span)
	draw_rect(span, Color(0.0, 14.0 / 255.0, 40.0 / 255.0, 0.07))


## A shaped opening (`drawOpening`, type "open"): the view clipped to the hole
## the cutter measured, then the frame over it.
func _open_hole(d: Dictionary) -> void:
	var skin := StringName(d.skin)
	var r := Rect2(float(d.x), float(d.y), float(d.w), float(d.h))
	# A room may carry an opening of its own -- the Exchange's hangar doors --
	# with its picture beside the room's others and its hole in the entry.
	var runs: Array = d.runs if d.has("runs") else _hole_runs(skin)
	var fx := bool(d.get("fx", false))
	var fy := bool(d.get("fy", false))
	for run in runs:
		var rx := float(run[1])
		var ry := float(run[0])
		var rw := float(run[2])
		if fx:
			rx = r.size.x - rx - rw
		if fy:
			ry = r.size.y - ry - 1.0
		_view_span(Rect2(r.position + Vector2(rx, ry), Vector2(rw, 1.0)))
	var art: Texture2D = _tex.get(String(d.art), null) if d.has("art") \
		else _opening_art.get(skin, null)
	if art == null:
		return
	if fx or fy:
		draw_texture_rect(art, Rect2(r.position + Vector2(r.size.x if fx else 0.0,
			r.size.y if fy else 0.0), Vector2(-r.size.x if fx else r.size.x,
			-r.size.y if fy else r.size.y)), false)
	else:
		draw_texture(art, r.position)


## A door (`drawOpening`, type "door"): the view, eight bands of shadow down
## its upper half, then its styled frame.
func _door_hole(d: Dictionary) -> void:
	var r := Rect2(float(d.x), float(d.y), float(d.w), float(d.h))
	_view_span(r)
	# THE BANDS ARE FILLED THE WAY A CANVAS FILLS THEM: an edge that falls part
	# way through a row covers that row by the share it covers. Each band is
	# 1/16 of the door and a door is 190 tall, so most rows are shared.
	var bh := r.size.y * 0.5 / 8.0
	var y := r.position.y
	var y_end := r.position.y + r.size.y * 0.5
	while y < y_end:
		for b in 8:
			var b0 := r.position.y + bh * float(b)
			var cov := minf(y + 1.0, b0 + bh) - maxf(y, b0)
			if cov <= 0.0:
				continue
			var a := 0.45 * (1.0 - float(b) / 8.0) * minf(1.0, cov)
			draw_rect(Rect2(r.position.x, y, r.size.x, 1.0), Color(8.0 / 255.0,
				12.0 / 255.0, 18.0 / 255.0, a))
		y += 1.0
	var art: Texture2D = _tex.get(String(d.get("art", "")), null)
	if art != null:
		draw_texture(art, Vector2(float(d.ax), float(d.ay)))


## A window (`drawOpening`, the rest): the view, a cold glaze, two streaks of
## reflection, and the nine-sliced frame.
func _window_hole(d: Dictionary) -> void:
	var r := Rect2(float(d.x), float(d.y), float(d.w), float(d.h))
	_view_span(r)
	draw_rect(r, Color(89.0 / 255.0, 128.0 / 255.0, 184.0 / 255.0, 0.08))
	var y := 0.0
	while y < r.size.y:
		var dd := floorf(r.position.x + r.size.x * 0.18 + y * 0.6)
		_clip(Rect2(dd, r.position.y + y, 12.0, 1.0), r, Color(0.8, 230.0 / 255.0, 1.0, 0.06))
		_clip(Rect2(dd + 30.0, r.position.y + y, 4.0, 1.0), r, Color(0.8, 230.0 / 255.0, 1.0, 0.05))
		y += 1.0
	var frame: Texture2D = _tex.get("../" + String(d.frame), null)
	var bz := float(doc().get("bezel", 12))
	if frame != null:
		_nine(frame, int(d.margin), r.position.x - bz, r.position.y - bz,
			r.size.x + 2.0 * bz, r.size.y + 2.0 * bz, true)


## The bench's `nine()`: corners at their own size, edges tiled from the start,
## middle open.
func _nine(im: Texture2D, m: int, x: float, y: float, w: float, h: float, bottom: bool) -> void:
	var s := float(im.get_width())
	var mf := float(m)
	var e := s - 2.0 * mf
	if e <= 0.0:
		return
	var tile_h := func(sy: float, dy: float, sh: float) -> void:
		var t := 0.0
		while t < w - 2.0 * mf:
			var c := minf(e, w - 2.0 * mf - t)
			draw_texture_rect_region(im, Rect2(x + mf + t, dy, c, sh), Rect2(mf, sy, c, sh))
			t += e
	var tile_v := func(sx: float, dx: float, y0: float, y1: float) -> void:
		var t := y0
		while t < y1:
			var c := minf(e, y1 - t)
			draw_texture_rect_region(im, Rect2(dx, t, mf, c), Rect2(sx, mf, mf, c))
			t += e
	draw_texture_rect_region(im, Rect2(x, y, mf, mf), Rect2(0.0, 0.0, mf, mf))
	draw_texture_rect_region(im, Rect2(x + w - mf, y, mf, mf), Rect2(s - mf, 0.0, mf, mf))
	tile_h.call(0.0, y, mf)
	var yb := y + h - mf if bottom else y + h
	tile_v.call(0.0, x, y + mf, yb)
	tile_v.call(s - mf, x + w - mf, y + mf, yb)
	if bottom:
		draw_texture_rect_region(im, Rect2(x, y + h - mf, mf, mf), Rect2(0.0, s - mf, mf, mf))
		draw_texture_rect_region(im, Rect2(x + w - mf, y + h - mf, mf, mf),
			Rect2(s - mf, s - mf, mf, mf))
		tile_h.call(s - mf, y + h - mf, mf)


# -------------------------------------------------------------- the concourse

## THE BENCH'S CROWD (`stepWalkers`), the port plan's option 1A: two to five
## people to a walk line, each with a pause between passes, and no drones. The
## game's other rooms keep their own rule.
func _build_cast(bd: StringName) -> void:
	_cast.clear()
	_read_walk()
	if no_people or _backdrop == null:
		return
	var dens := float((room.get("air", {}) as Dictionary).get("people", 1))
	var lines: Variant = _walk_lines.get(String(bd), null)
	if dens <= 0.0 or not (lines is Array) or (lines as Array).is_empty():
		return
	var id := String(bd)
	var sd := ShopLight.hash1(float(id.length()) * 3.7 + float(id.unicode_at(0)) * 1.9) * 53.0
	var near := 0.0
	for ln in lines:
		near = maxf(near, float(int((ln as Dictionary).get("tall", 0))))
	var bw := float(_backdrop.get_width())
	for lane in (lines as Array).size():
		var ln: Dictionary = lines[lane]
		var ht := maxf(4.0, float(int(ln.get("tall", 0))))
		var n := int(floorf((2.0 + floorf(ShopLight.hash1(sd + float(lane) * 3.3) * 4.0)) * dens + 0.5))
		var depth := ht / near if near > 0.0 else 1.0
		var haze := clampf((1.0 - depth) * 0.7, 0.0, 0.45)
		for k in n:
			var h0 := ShopLight.hash1(sd + float(lane) * 5.9 + float(k) * 2.3)
			var tallpx := maxf(4.0, floorf(ht + 0.5))
			var pick := _pick_strip(tallpx, int(floorf(h0 * 9973.0)), false)
			var w := {"ln_y": float(ln.get("y", 0)), "tall": tallpx, "h0": h0, "haze": haze,
				"right": ShopLight.hash1(h0 * 47.7) > 0.5,
				"span": bw + 40.0, "cycle": bw + 40.0 + 80.0 + ShopLight.hash1(h0 * 31.1) * 260.0,
				"init": ShopLight.hash1(h0 * 17.3) * 997.0}
			var ks := 1.0
			var gait := 1.0
			if pick != "":
				var m: Dictionary = _strips[pick]
				var path := "res://art/sprites/station/" + String(m.get("file", "walker_%s.png" % pick))
				var tex: Texture2D = null
				if ResourceLoader.exists(path):
					tex = load(path) as Texture2D
				var adv_v: Variant = m.get("advance", null)
				if tex == null or adv_v == null or float(adv_v) <= 0.0:
					pick = ""
				else:
					ks = float(_strip_k(m, tallpx))
					gait = float(m.get("gait", 1.0))
					w["tex"] = tex
					w["k"] = ks
					w["fw"] = float(m.get("frame_w", 0)) * ks
					w["fh"] = float(m.get("frame_h", 0)) * ks
					w["frames"] = maxi(1, int(m.get("frames", 1)))
					w["adv"] = float(adv_v) * ks
			w["figure"] = pick == ""
			w["speed"] = WALK_PACE * gait * (0.85 + 0.3 * h0) * depth * ks
			_cast.append(w)


## Where everyone is at the room's clock: `stepWalkers`' positions, then
## `sprite`'s and `figure`'s. Distance is a function of the clock here, which
## is the bench's accumulated distance for a speed that never changes.
func _pose_cast() -> void:
	_posed_at = _clock
	_posed.clear()
	if _backdrop == null:
		return
	var bw := float(_backdrop.get_width())
	for w in _cast:
		var run := fmod(float(w.init) + _clock * float(w.speed), float(w.cycle))
		if run > float(w.span):
			continue
		var right: bool = w.right
		var x := (_bd_pos.x - 20.0 + run) if right else (_bd_pos.x + bw + 20.0 - run)
		var feet := floorf(_bd_pos.y + float(w.ln_y) + 0.5)
		if bool(w.figure):
			_posed.append([w, floorf(x + 0.5), feet, 0, run])
			continue
		var adv: float = w.adv
		var steps := floorf(run / adv)
		var f := int(steps) % int(w.frames)
		var frac := run - steps * adv
		var dx := floorf(x - frac * (1.0 if right else -1.0) - float(w.fw) * 0.5 + 0.5)
		var dy := floorf(feet - float(w.fh) + 0.5)
		_posed.append([w, dx, dy, f, run])


## `walkers()`: the crowd inside one clip -- reflections first on a polished
## floor, then everybody.
func _shop_cast(clip: Rect2) -> void:
	if _reflect:
		for p in _posed:
			var w: Dictionary = p[0]
			if not bool(w.figure):
				w["flip"] = not bool(w.right)
				_blit_reflection(w, p[1], p[2], p[3], clip)
	for p in _posed:
		var w: Dictionary = p[0]
		if bool(w.figure):
			_bench_figure(p[1], p[2], float(w.tall), float(w.h0), float(p[4]),
				float(w.haze), clip)
		else:
			w["flip"] = not bool(w.right)
			_blit_walker(w, p[1], p[2], p[3], clip)


## `figure()`: a drawn person, for a line no sprite is the height of.
func _bench_figure(cx: float, feet: float, tall: float, h0: float, run: float,
		haze: float, clip: Rect2) -> void:
	var ink := Color8(int(floorf((0.03 + 0.27 * haze) * 255.0 + 0.5)),
		int(floorf((0.04 + 0.34 * haze) * 255.0 + 0.5)),
		int(floorf((0.07 + 0.43 * haze) * 255.0 + 0.5)))
	var head := maxf(3.0, floorf(tall * 0.16 + 0.5))
	var chest := maxf(5.0, floorf(tall * 0.30 + 0.5)) + (2.0 if ShopLight.hash1(h0 * 3.1) > 0.5 else 0.0)
	var torso := floorf(tall * 0.34 + 0.5)
	var legs := tall - head - 1.0 - torso
	var top := feet - tall
	var sx := cx - floorf(chest / 2.0)
	var apart := int(floorf(run / maxf(2.0, tall * 0.3))) % 2 == 0
	var hx := cx - floorf(head / 2.0)
	_clip(Rect2(hx + 1.0, top, head - 2.0, 1.0), clip, ink)
	_clip(Rect2(hx, top + 1.0, head, head - 1.0), clip, ink)
	var ny := top + head
	_clip(Rect2(cx - 1.0, ny, 2.0, 1.0), clip, ink)
	var ty := ny + 1.0
	_clip(Rect2(sx, ty, chest, ceilf(torso / 2.0)), clip, ink)
	_clip(Rect2(sx + 1.0, ty + ceilf(torso / 2.0), chest - 2.0, floorf(torso / 2.0)), clip, ink)
	var arm := floorf(torso * 0.95 + 0.5)
	var sw := 1.0 if apart else 0.0
	_clip(Rect2(sx - 1.0, ty + 1.0 + sw, 1.0, arm), clip, ink)
	_clip(Rect2(sx + chest, ty + 2.0 - sw, 1.0, arm), clip, ink)
	var ly := ty + torso
	var lw := maxf(1.0, floorf(chest * 0.25))
	if apart:
		_clip(Rect2(sx, ly, lw, legs), clip, ink)
		_clip(Rect2(sx + chest - lw, ly, lw, legs), clip, ink)
	else:
		_clip(Rect2(cx - lw, ly, lw * 2.0, legs), clip, ink)
	var rim := Color(1.0, 196.0 / 255.0, 124.0 / 255.0, snappedf(0.55 * (1.0 - haze), 0.01))
	var edge := (sx + chest - 1.0) if ShopLight.hash1(h0 * 23.9) > 0.5 else sx
	_clip(Rect2(hx + 1.0, top, head - 2.0, 1.0), clip, rim)
	_clip(Rect2(edge, ty, 1.0, ceilf(torso / 2.0)), clip, rim)
	var carry := int(floorf(ShopLight.hash1(h0 * 61.3) * 7.0))
	if carry == 0:
		_clip(Rect2(sx - 1.0, ty - 3.0, floorf(chest * 0.6 + 0.5), 3.0), clip, ink)
	elif carry == 1:
		_clip(Rect2(sx + chest + 1.0, ty + 3.0, 1.0, 1.0), clip,
			Color(115.0 / 255.0, 217.0 / 255.0, 242.0 / 255.0, 0.9))


# -------------------------------------------------------------------- layers

## What the bench draws after the furniture and over it, then the fixtures
## (`drawLampBodies`), hung in front of everything.
func front_layer() -> Control:
	if _lamps_node == null:
		_lamps_node = _Layer.new()
		_lamps_node.shop = self
	return _lamps_node


## The room's light (`applyLight`), over everything the room and its furniture
## drew.
func light_layer() -> Control:
	if _light_node == null:
		_light_node = ShopLight.Overlay.new()
		_setup_light()
	return _light_node


## Dust, glass, lit panels and the shop's marks, over the light.
func glow_layer() -> Control:
	if _glow_node == null:
		_glow_node = ShopLight.Glow.new()
		_glow_node.shop = self
	return _glow_node


class _Layer extends Control:
	var shop: ShopScene

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if shop != null and is_instance_valid(shop):
			shop._draw_front(self)


func _draw_front(c: CanvasItem) -> void:
	if room.is_empty() or _plate_key == &"":
		return
	_draw_list(c, room.get("front", []))
	for l in room.get("lamps", []):
		var t: Texture2D = _tex.get(String(l.art), null)
		if t != null:
			c.draw_texture(t, Vector2(float(l.x), float(l.y)))


func _setup_light() -> void:
	if _light_node == null:
		return
	var on := not fullbright and _light_tex != null and not room.is_empty()
	_light_node.visible = on
	if not on:
		return
	var lt: Dictionary = room.get("light", {})
	var k: Dictionary = doc().get("constants", {})
	var ac: Array = k.get("amb_col", [0.70, 0.78, 1.0])
	var s1: Array = _scales[0]
	var s2: Array = _scales[1]
	_light_node.setup(Rect2(Vector2.ZERO, PANEL), {
		"light_map": _light_tex,
		"room_size": PANEL,
		"band_h": _light_h,
		"gk": int(doc().get("gk", 2)),
		"scales1": Vector4(float(s1[0]), float(s1[1]), float(s1[2]), float(s1[3])),
		"scales2": Vector4(float(s2[0]), float(s2[1]), float(s2[2]), float(s2[3])),
		"tone": _tone,
		"amb": float(lt.get("amb", 0.30)),
		"shadowk": float(lt.get("shadowk", 0.55)),
		"dither": bool(lt.get("dither", false)),
		"amb_col": Vector3(float(ac[0]), float(ac[1]), float(ac[2])),
		"levels": float(k.get("levels", 6)),
		"soft": float(k.get("soft", 1.5)),
		"flick_col": Vector3.ZERO,
		"flick_f": 0.0,
	})


## This frame's failing lamp, handed to the light and redrawn in the glow. On
## the room's own 30 Hz clock, the rate the faults were shaped at.
func _frame_light() -> void:
	var t_ms := _clock * 1000.0
	var li := int((room.get("light", {}) as Dictionary).get("flick_lamp", -1))
	var lamps: Array = room.get("lamps", [])
	if li >= 0 and li < lamps.size():
		var l: Dictionary = lamps[li]
		var fc := ShopLight.flicker_at(0 if steady else int(l.flick), t_ms, float(l.px),
			float(l.py), float(l.get("rate", 0)))
		var f := fc.a * float(l.get("pow", 1.4))
		var c := ShopLight.rgb_of(String(l.col)) * Vector3(fc.r, fc.g, fc.b)
		var mx := maxf(c.x, maxf(c.y, c.z))
		if mx <= 0.0:
			mx = 1.0
		if f > 0.003:
			_flick_col = c / mx * f
			_flick_f = f
		else:
			_flick_col = Vector3.ZERO
			_flick_f = 0.0
		if _light_node != null and _light_node.visible:
			_light_node.set_param(&"flick_col", _flick_col)
			_light_node.set_param(&"flick_f", _flick_f)
	if _glow_node != null:
		_glow_node.queue_redraw()


## The light at one light-map cell, before it touches the art: what the dust
## is lit by (`LR`, `LG`, `LB` in the bench).
func _light_at(gx: int, gy: int) -> Vector3:
	if _light_bytes.is_empty():
		return Vector3.ZERO
	var w := _light_w
	var o := (gy * w + gx) * 4
	var band := _light_h * w * 4
	var s1: Array = _scales[0]
	var s2: Array = _scales[1]
	var v := [0.0, 0.0, 0.0, 0.0, 0.0]
	for c in 4:
		v[c] = (float(_light_bytes[o + c]) * 256.0 + float(_light_bytes[o + band + c])) \
			/ 65535.0 * float(s1[c])
	v[4] = (float(_light_bytes[o + band * 2]) * 256.0 + float(_light_bytes[o + band * 3])) \
		/ 65535.0 * float(s2[0])
	return Vector3(v[0], v[1], v[2]) + _tone * v[3] + _flick_col * v[4]


## The layer over the light: `drawMotes`, `drawLampGlass`, `drawPropGlass`, and
## the shop's own marks.
func _draw_glow(c: CanvasItem) -> void:
	if room.is_empty() or _plate_key == &"":
		return
	var t := _clock
	var gk := int(doc().get("gk", 2))
	if not fullbright and not no_motes and not _light_bytes.is_empty():
		var n := int((room.get("air", {}) as Dictionary).get("motes", 0))
		for k in n:
			var sx := ShopLight.hash1(float(k) * 1.37 + 0.11)
			var sy := ShopLight.hash1(float(k) * 2.71 + 5.3)
			var sp := 0.15 + 0.5 * ShopLight.hash1(float(k) * 3.91 + 1.7)
			var x := fmod(sx * PANEL.x + t * sp * 7.0 + 13.0 * sin(t * 0.21 + sx * 31.0), PANEL.x)
			var y := fmod(sy * PANEL.y - t * sp * 4.0 + 9.0 * sin(t * 0.17 + sy * 27.0), PANEL.y)
			if x < 0.0:
				x += PANEL.x
			if y < 0.0:
				y += PANEL.y
			var l3 := _light_at(int(x) / gk, int(y) / gk)
			var l := maxf(l3.x, maxf(l3.y, l3.z))
			if l < 0.06:
				continue
			var a := snappedf(minf(0.85, l * (0.35 + 0.5 * ShopLight.hash1(float(k) * 7.7))), 0.001)
			c.draw_rect(Rect2(floorf(x), floorf(y), 1.0, 1.0), Color8(
				int(floorf(255.0 * minf(1.0, l3.x / l) + 0.5)),
				int(floorf(255.0 * minf(1.0, l3.y / l) + 0.5)),
				int(floorf(255.0 * minf(1.0, l3.z / l) + 0.5)), int(roundf(a * 255.0))))
	var t_ms := t * 1000.0
	for l in room.get("lamps", []):
		var f := ShopLight.flicker_at(0 if steady else int(l.flick), t_ms, float(l.px),
			float(l.py), float(l.get("rate", 0))).a
		if f <= 0.004:
			continue
		var g: Texture2D = _tex.get(String(l.glass), null)
		if g != null:
			c.draw_texture(g, Vector2(float(l.x), float(l.y)), Color(1, 1, 1, minf(1.0, f)))
	if not fullbright:
		for gl in room.get("glass", []):
			var gt: Texture2D = _tex.get(String(gl.art), null)
			if gt != null:
				c.draw_texture(gt, Vector2(float(gl.x), float(gl.y)))
	if lit_marks:
		if shelf_node != null and is_instance_valid(shelf_node) and shelf_node.has_method("draw_lit_marks"):
			shelf_node.draw_lit_marks(c)
		if till_node != null and is_instance_valid(till_node) and till_node.has_method("draw_lit_marks"):
			till_node.draw_lit_marks(c)
