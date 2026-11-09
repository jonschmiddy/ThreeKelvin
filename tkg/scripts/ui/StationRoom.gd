class_name StationRoom
extends Control

## One room serves four decks, so each deck says only what differs, not three copies.
## A placeholder that is also the fallback if a generated plate never lands.
## Why: docs/why/StationRoom.md#room-design

## Development already sets prices and stock,
## so the picture says something true: fewer lamps at an outpost.
var dev: int = MapGen.Development.CITY
## Whoever holds the station. Tints the TRIM and nothing else -- see `_tint`.
var manufacturer: StringName = &""

## Deliberately the berth's numbers, darker than they look: a mid-grey room makes every
## silhouette soft. The decks reading as one station beats any one reading well alone.
## Why: docs/why/StationRoom.md#palette
const WALL := Color("#0d141d")
const PLATE := Color("#151e2a")
const EDGE := Color("#202d3d")
const DEEP := Color("#080c12")
const LAMP := UITheme.EMBER
const FLOOR := Color("#121a24")
const FLOOR_LINE := Color("#1c2836")
const STAR := UITheme.ICE
## A crate, and the lit edge that makes it a box rather than a swatch.
const CRATE := Color("#1e2836")
const CRATE_LIP := Color("#33445c")

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## The visible deck strip round furniture standing on the
## bottom edge; a function so a taller deck can have less.
func floor_h() -> float:
	return 78.0


## How many lamps hang over the room.
func _lamps() -> int:
	match dev:
		MapGen.Development.OUTPOST: return 2
		MapGen.Development.SETTLEMENT: return 3
		MapGen.Development.CAPITAL: return 6
		_: return 4


## Tint the trim, not the walls: a lerp on a dark colour desaturates it (at 0.12 the wall came
## out grey). Big surfaces keep the station's colour; the livery goes on joints, studs and frames.
## Why: docs/why/StationRoom.md#livery-tint
func _tint(c: Color) -> Color:
	var m: ManufacturerData = DB.manufacturers.get(manufacturer)
	return c if m == null else c.lerp(m.colour, 0.18)


## A repeatable scatter, or stars and bubbles twinkle each redraw, as GDScript's RNG is a stream.
func _scatter(i: int, span: float) -> float:
	return UIHash.scatter(i, span)


## Keyed on the deck, not development, since the plate is a backdrop with no lamps.
## So one plate serves outpost and capital alike, and the twelve needed become three.
## Why: docs/why/StationRoom.md#plates
func plate_id() -> StringName:
	return &"room"


## A texture first touched inside `_draw` renders white, so plates are resolved outside it and kept.
## Keyed on id as `dev` is set after `_ready`; two layers as the livery tints trim only.
## Why: docs/why/StationRoom.md#plates
var _plate_key: StringName = &""
var _plate_wall: Texture2D = null
var _plate_trim: Texture2D = null
## One lamp art for every deck and level; count and light colour are the room's to decide.
var _lamp_hood: Texture2D = null
var _lamp_cone: Texture2D = null
var _lamp_pool: Texture2D = null


func _load_plate(key: StringName) -> void:
	_plate_key = key
	var id := plate_id()
	_plate_wall = DB.station_sprite(id, &"wall")
	_plate_trim = DB.station_sprite(id, &"trim")
	_lamp_hood = DB.station_sprite(&"lamp", &"hood")
	_lamp_cone = DB.station_sprite(&"lamp", &"cone")
	_lamp_pool = DB.station_sprite(&"lamp", &"pool")
	# ONE WINDOW STYLE PER STATION, off its seed: somebody built this place and
	# they had a way of making windows. The chamfer is the plain one.
	var style: StringName = WINDOW_STYLES[absi(hash([place_seed, &"style"])) % WINDOW_STYLES.size()]
	_box_window = _bezel(&"window" if style == &"chamfer" else StringName("window_%s" % style),
		true, 18.0 if style == &"chamfer" else 24.0)
	if _box_window == null:
		_box_window = _bezel(&"window", true)
	_ports = DB.station_sprite(&"frame", &"ports")
	# Opening frames are resolved here, not in the draw call:
	# fifteen small textures, built about twice a life.
	_opening_art.clear()
	for skin in _hole_runs_keys():
		var a := DB.station_sprite(&"opening", skin)
		if a != null:
			_opening_art[skin] = a
	_backdrop = null
	_bd_id = &""
	var bd: StringName = forced_views.get(&"backdrop", &"")
	var pool: Array = BACKDROPS.get(dev, BACKDROPS[MapGen.Development.CITY])
	if bd == &"" and not pool.is_empty():
		bd = pool[absi(hash([place_seed, &"backdrop"])) % pool.size()]
	if bd != &"":
		_backdrop = DB.station_sprite(&"backdrop", bd)
		_bd_id = bd
	_reflect = REFLECTIVE.has(bd)
	_bd_drop = float(_drops().get(String(bd), 0))
	_build_cast(bd)
	_box_door = _bezel(&"door", false)
	_load_views()
	queue_redraw()
	if _fore != null:
		_fore.queue_redraw()


## What the plate cache is keyed on. The seed is in it because the views are:
## a room that moves to a new station has to pick again, not keep the last one.
func _plate_cache_key() -> StringName:
	var id := plate_id()
	if id == &"":
		return &""
	# DEV IS IN IT because the backdrop pool is chosen by development level: a
	# room re-dressed for another level with the same seed must re-pick.
	return StringName("%s:%d:%d:%d" % [id, place_seed, dev,
		openings(size.x, size.y, size.y - floor_h()).size()])


## Art supplies the fixture; `_lamps()` keeps count and positions, so an outpost reads as two lamps.
## The light must land on the floor: a lamp that lights nothing is a sticker.
## Why: docs/why/StationRoom.md#lamps
func _lamp_rects(w: float, _floor_y: float) -> void:
	var n := _lamps()
	var glow := _light()
	for i in n:
		var lx := w * (float(i) + 0.5) / float(n)
		draw_rect(Rect2(lx - 1.0, 0.0, 2.0, 9.0), _tint(EDGE))
		draw_rect(Rect2(lx - 7.0, 9.0, 14.0, 4.0), _tint(EDGE))
		draw_rect(Rect2(lx - 5.0, 12.0, 10.0, 2.0), Color(glow, 0.85))


func _draw_lamp_art(w: float, floor_y: float) -> bool:
	if _lamp_hood == null:
		return false
	var n := _lamps()
	var glow := _light()
	var hood := Vector2(_lamp_hood.get_size())
	for i in n:
		var lx := w * (float(i) + 0.5) / float(n)
		var drop := hood.y
		if _lamp_cone != null:
			# Widening to the floor, and drawn BEFORE the fixture so the hood
			# sits in front of its own light rather than under it.
			var cw := maxf(46.0, w / float(n) * 0.72)
			draw_texture_rect(_lamp_cone,
				Rect2(lx - cw * 0.5, drop, cw, maxf(1.0, floor_y - drop)),
				false, Color(glow, 0.62))
		draw_texture(_lamp_hood, Vector2(lx - hood.x * 0.5, 0.0).round())
		if _lamp_pool != null:
			var pw := maxf(60.0, w / float(n) * 0.92)
			draw_texture_rect(_lamp_pool,
				Rect2(lx - pw * 0.5, floor_y, pw, floor_h()),
				false, Color(glow, 0.75))
	return true


func _blit_plate() -> bool:
	var key := _plate_cache_key()
	if key == &"":
		return false
	if _plate_key != key:
		# Deferred, so the load lands between frames rather than inside this one.
		_load_plate.call_deferred(key)
		return false
	var wall: Texture2D = _plate_wall
	if wall == null:
		return false
	# Stretched to the room because the wall must reach
	# both edges: the one texture not drawn at 1:1.
	draw_texture_rect(wall, Rect2(Vector2.ZERO, size), false)
	var trim: Texture2D = _plate_trim
	if trim != null:
		draw_texture_rect(trim, Rect2(Vector2.ZERO, size), false, _tint(EDGE))
	return true


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 60.0 or h <= 120.0:
		return
	var floor_y := h - floor_h()
	if view_only and _backdrop != null:
		var bs0 := Vector2(_backdrop.get_size())
		_bd_pos = Vector2(roundf((w - bs0.x) * 0.5), floor_y - bs0.y + _bd_drop)
		var all0 := Rect2(Vector2.ZERO, Vector2(w, h))
		draw_rect(all0, DEEP)
		_blit_backdrop(all0)
		_draw_cast(all0)
		return
	if _blit_plate():
		# A plate is the room as a backdrop only; lamps and furniture go over it because they vary
		# by development, deck and live state, and none of those can be baked.
		# Why: docs/why/StationRoom.md#plates
		_draw_openings(w, h, floor_y)
		_dress_wall(w, h, floor_y)
		# No lamps on the art path: the generated hood, cone and pool read as stickers and
		# were cut. `_draw_lamp_art` stays for when lighting returns as art that belongs.
		# Why: docs/why/StationRoom.md#lamps
		_dress_floor(w, h, floor_y)
		_draw_haze(w, h, floor_y)
		return

	# The back wall is the darkest thing in the room: as `PLATE` the furniture read as dark holes.
	# Why: docs/why/StationRoom.md#palette
	draw_rect(Rect2(0.0, 0.0, w, floor_y), WALL)
	# Panel joints, wide and faint. A flat wall reads as a hole.
	var jy := 30.0
	while jy < floor_y - 8.0:
		draw_rect(Rect2(0.0, jy, w, 1.0), _tint(EDGE))
		draw_rect(Rect2(0.0, jy + 1.0, w, 1.0), Color(DEEP, 0.45))
		jy += 46.0
	var jx := 62.0
	while jx < w - 20.0:
		draw_rect(Rect2(jx, 0.0, 2.0, floor_y), _tint(EDGE))
		jx += 124.0

	_dress_wall(w, h, floor_y)

	_lamp_rects(w, floor_y)

	# The floor goes down before the light that falls on it, or it painted over the lamps' pools.
	draw_rect(Rect2(0.0, floor_y, w, floor_h()), FLOOR)
	# The junction, lit along the top edge: the one line that stops the wall and
	# the deck being the same surface.
	draw_rect(Rect2(0.0, floor_y, w, 2.0), _tint(FLOOR_LINE))
	draw_rect(Rect2(0.0, floor_y + 2.0, w, 3.0), Color(DEEP, 0.55))
	# Plating, in courses that get taller as they come toward you. Even courses
	# read as a grid seen flat on; uneven ones read as a floor going away.
	var fy := floor_y + 16.0
	var gap := 16.0
	while fy < h - 2.0:
		draw_rect(Rect2(0.0, fy, w, 1.0), FLOOR_LINE)
		gap += 5.0
		fy += gap
	# And the seams across them, staggered course to course the way plate is laid.
	var course := 0
	fy = floor_y + 4.0
	while fy < h - 4.0:
		var sxx := 40.0 + float((course % 2) * 60)
		while sxx < w - 10.0:
			draw_rect(Rect2(sxx, fy, 1.0, 10.0),
				Color(DEEP, 0.35))
			sxx += 120.0
		course += 1
		fy += 26.0

	_dress_floor(w, h, floor_y)

	# --- AND THE LIGHT THE LAMPS PUT ON IT, last of all so the plating shows
	# THROUGH it. A pool is light on a floor, not a shape lying on one.
	var pool_n := _lamps()
	var pool_glow := _light()
	for i in pool_n:
		var px := w * (float(i) + 0.5) / float(pool_n)
		var step := 0
		while step < 6:
			var spread := 16.0 + float(step) * 14.0
			draw_rect(Rect2(px - spread, floor_y + float(step) * 13.0,
				spread * 2.0, 13.0),
				Color(pool_glow.r, pool_glow.g, pool_glow.b,
					0.075 - 0.011 * float(step)))
			step += 1


## The colour of this room's lamps and of the light they put on the floor. The
## station's amber, unless a room is lit for a different job.
func _light() -> Color:
	return LAMP


## Anchors for the station's manufacturer banners; the screen hangs the whole set centred on it.
func banner_spots() -> Array:
	return []


## What hangs on this deck's wall. Drawn after the wall and before the lamps.
func _dress_wall(_w: float, _h: float, _floor_y: float) -> void:
	pass


## What stands on this deck's floor. Drawn after the plating and before the
## light pools, so the lamps light the furniture as well as the deck.
func _dress_floor(_w: float, _h: float, _floor_y: float) -> void:
	pass


# ------------------------------------------------------------------ the layers
# A room in depth: openings show views and cables hang in front, with depth from overlap and haze.
# All of it is the plate path's; a deck with no art keeps its rectangles.
# Why: docs/why/StationRoom.md#room-layers

## Which station this is, as a number: picks the views, the walkers and the
## cables, so a station looks the same every visit and different from the next.
var place_seed: int = 0

## Views per opening kind are checked against the files at load, so an id with no art drops out.
const VIEWS := {
	&"window": [&"prom_a", &"prom_d", &"shops_b", &"arcade_a",
		&"arcade_b", &"gallery_c", &"lounge_a", &"lounge_b", &"mess_a",
		&"mess_b", &"mess_c", &"garden_b", &"garden_c", &"obs_a", &"obs_b"],
	&"door": [&"hall_a", &"hall_b", &"hall_c"],
}

## A view is seen through glass, a touch colder;
## `room_plate.py view` seats it behind the room's light.
const VIEW_GLASS := Color(0.90, 0.94, 1.0)
## Layers redraw at 30 Hz: at 12 every walker pose was held 83 or 167 ms at random,
## and the fastest walker skipped poses outright.
## Why: docs/why/StationRoom.md#layer-rate
const LAYER_HZ := 30.0

## A view to show instead of the seed's pick, by kind. For `stationshot view=`,
## which photographs a named view in its real window; nothing in play sets it.
static var forced_views := {}

## The place outside with no room round it, for `stationshot roomview`; nothing in play sets it.
static var view_only := false

var _views: Array = []
var _box_window: StyleBoxTexture = null
## Every backdrop is 800x400: `_bd_pos` centres it, and shorter ones left bare wall above.
## One pool per development level (Jon, 2026-09-25), so a squat never views a capital atrium.
## Why: docs/why/StationRoom.md#backdrops
const BACKDROPS := {
	MapGen.Development.UNCLAIMED: [&"unclaimed_foodcounter14u",
		&"unclaimed_gutted14u", &"unclaimed_habs15u", &"unclaimed_habtrash14u",
		&"unclaimed_market15u", &"unclaimed_pawn15u",
		&"unclaimed_trashdoors15u"],
	MapGen.Development.OUTPOST: [&"outpost_canteen11a", &"outpost_galley8a",
		&"outpost_hydro", &"outpost_junk8a", &"outpost_shack11a",
		&"outpost_vending"],
	MapGen.Development.SETTLEMENT: [&"settlement_bathhouse16u",
		&"settlement_cobbler16u", &"settlement_homes9a",
		&"settlement_noodle10a", &"settlement_pharmacy10a",
		&"settlement_supply11a"],
	MapGen.Development.CITY: [&"city_bar11a", &"city_electronics11a",
		&"city_gates8a", &"city_hotel11a", &"city_nightmarket11a"],
	MapGen.Development.CAPITAL: [&"capital_bank6a", &"capital_boutique9b",
		&"capital_embassy8a", &"capital_plaza2b", &"capital_skygarden2a"],
}
## Only polished-floor backdrops reflect their walkers (Jon, 2026-09-25); on grating it would lie.
## Why: docs/why/StationRoom.md#backdrops
const REFLECTIVE: Array[StringName] = [&"outpost_hydro", &"outpost_vending"]

var _backdrop: Texture2D = null
## Which backdrop that is, by id: what `_load_plate` drew from the pool.
var _bd_id: StringName = &""
var _bd_pos := Vector2.ZERO
## Views are seen through `VIEW_GLASS`; the shop turns it off as its openings carry their own glaze.
var _view_tint := VIEW_GLASS
## How far this station's backdrop sits below the default, from DROPS_PATH.
var _bd_drop := 0.0
const DROPS_PATH := "res://art/sprites/station/backdrop_drops.json"
static var _drop_table: Dictionary = {}
static var _drops_read := false


## backdrop id -> px moved down, read once. A missing file or entry is 0.
static func _drops() -> Dictionary:
	if not _drops_read:
		_drops_read = true
		if FileAccess.file_exists(DROPS_PATH):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DROPS_PATH))
			if parsed is Dictionary:
				_drop_table = parsed
	return _drop_table


## This station's backdrop is in REFLECTIVE: its walkers get a reflection.
var _reflect := false
## How strongly the floor gives a walker back. A third reads as polish; more
## reads as a second person standing on their head.
const REFLECT_ALPHA := 0.3

## Walkers belong to the backdrop, not a window, so two windows on one stretch show the same person.
## Positions are a function of the clock, so a hidden room picks up where it should be.
## Why: docs/why/StationRoom.md#walkers
const WALKERS := true

const WALK_LINES_PATH := "res://art/sprites/station/backdrop_walk.json"
const STRIPS_PATH := "res://art/sprites/station/walker_strips.json"

## WALK_PACE 40 is on Jon's call and breaks the cycle rule: 9.5 frames a second against 4.7 at 20.
## His eye overruled the arithmetic six times running, so a number nobody has watched is worth less.
## Why: docs/why/StationRoom.md#walk-pace
const WALK_PACE := 40.0

## A flyer has no feet to place it, so nothing in the art says how high above its line it rides.
const FLY_ALT := 96.0

static var _walk_lines: Dictionary = {}
static var _strips: Dictionary = {}
static var _walk_read := false

## Who is on the concourse behind this room. Built once when the backdrop is
## chosen, not every frame.
var _cast: Array = []

## The opening frames, keyed by skin. See `_shaped_opening` for why these are
## resolved here and not where they are drawn.
var _opening_art: Dictionary = {}

## The porthole plate: one sprite, three holes, a single view behind it.
var _ports: Texture2D = null

## The shapes a station's windows come in. See `room_plate.py window_styles`.
const WINDOW_STYLES: Array[StringName] = [&"chamfer", &"round", &"octa"]
var _box_door: StyleBoxTexture = null
var _fore: Control = null
var _clock := 0.0
var _since := 0.0


## A deck places its openings round its own furniture;
## the room knows nothing of what stands in front.
func openings(_w: float, _h: float, _floor_y: float) -> Array:
	return []


func _load_views() -> void:
	_views.clear()
	var taken := {}
	var list := openings(size.x, size.y, size.y - floor_h())
	for i in list.size():
		var kind: StringName = list[i].kind
		# A porthole plate looks onto the same kinds of place a window does.
		var pool_kind: StringName = &"window" if kind == &"ports" else kind
		var want: StringName = forced_views.get(kind, &"")
		if want != &"" and DB.station_sprite(&"view", want) != null:
			_views.append(DB.station_sprite(&"view", want))
			continue
		var pool: Array = []
		for v in VIEWS.get(pool_kind, []):
			if not taken.has(v) and DB.station_sprite(&"view", v) != null:
				pool.append(v)
		if pool.is_empty():
			_views.append(null)
			continue
		var pick: StringName = pool[absi(hash([place_seed, i])) % pool.size()]
		taken[pick] = true
		_views.append(DB.station_sprite(&"view", pick))


func _process(delta: float) -> void:
	if not WALKERS or _views.is_empty() or not is_visible_in_tree():
		return
	_clock += delta
	_since += delta
	# Half a frame of slack: two 60 Hz frames sum to a hair under 1/30 and the gate waited a third.
	if _since >= 1.0 / LAYER_HZ - 0.5 * delta:
		_since = 0.0
		queue_redraw()


func _draw_openings(w: float, h: float, floor_y: float) -> void:
	var list := openings(w, h, floor_y)
	if _backdrop != null:
		# Fixed to the wall, as centring it on the openings made it slide whenever a window moved.
		var bs := Vector2(_backdrop.get_size())
		# Dropped by its own height so its floor meets the room's;
		# set by eye per backdrop (Jon, 2026-09-25).
		_bd_pos = Vector2(roundf((w - bs.x) * 0.5), floor_y - bs.y + _bd_drop)
	for i in list.size():
		var r: Rect2 = list[i].rect
		var tex: Texture2D = _views[i] if i < _views.size() else null
		if list[i].kind == &"door":
			_door(r, tex, i)
		elif list[i].kind == &"ports" and _ports != null:
			_porthole_plate(r, tex)
		elif list[i].kind == &"open":
			_shaped_opening(r, tex, list[i].get("skin", &""))
		else:
			_pane(r, tex, i)


## The sprite cannot say where its hole is, so the inside is filled from `opening_holes.json` spans,
## then the sprite goes over the top.
## Why: docs/why/StationRoom.md#shaped-openings
func _shaped_opening(r: Rect2, tex: Texture2D, skin: StringName) -> void:
	# Read from the cache, never `load()` in a draw call: it sampled white and every opening frame
	# rendered as a white rectangle.
	# Why: docs/why/StationRoom.md#plates
	var art: Texture2D = _opening_art.get(skin, null)
	var runs: Array = _hole_runs(skin)
	if art == null or runs.is_empty():
		# No sprite, or a plate with no hole in it: fall back to a plain pane
		# rather than drawing a rectangle of raw promenade on the wall.
		_pane(r, tex, 0)
		return
	for run in runs:
		var span := Rect2(r.position + Vector2(run[1], run[0]), Vector2(run[2], 1.0))
		draw_rect(span, DEEP)
		if _backdrop == null:
			continue
		_blit_backdrop(span)
		_draw_cast(span)
	draw_texture(art, r.position.round())


## The measured insides, read once and kept. Missing file or bad skin gives an
## empty list, which `_shaped_opening` treats as "draw a plain pane instead".
static var _holes: Dictionary = {}
static var _holes_read := false
const HOLES_PATH := "res://art/sprites/station/opening_holes.json"


static func _hole_runs(skin: StringName) -> Array:
	if not _holes_read:
		_holes_read = true
		if FileAccess.file_exists(HOLES_PATH):
			var parsed: Variant = JSON.parse_string(
				FileAccess.get_file_as_string(HOLES_PATH))
			if parsed is Dictionary:
				_holes = parsed
	var entry: Variant = _holes.get(String(skin), null)
	if entry is Dictionary and entry.has("runs"):
		return entry["runs"]
	return []


## Every skin `opening_holes.json` knows about, which is every frame the art
## ships. Reading it through `_hole_runs` first makes sure the file is parsed.
static func _hole_runs_keys() -> Array:
	_hole_runs(&"")
	var out: Array = []
	for k in _holes.keys():
		out.append(StringName(k))
	return out


## Three portholes in one plate over one view. The view is drawn across the
## whole opening and the plate covers everything but the holes, glass and all.
func _porthole_plate(r: Rect2, tex: Texture2D) -> void:
	_blit_view(r, tex, false)
	var ps := Vector2(_ports.get_size())
	draw_texture(_ports, (r.get_center() - ps * 0.5).round())


## The backdrop's top row is stretched up to the ceiling, as the heights page and bench draw it.
func _blit_backdrop(dst: Rect2) -> void:
	var bs := Vector2(_backdrop.get_size())
	var src := Rect2(dst.position - _bd_pos, dst.size).intersection(Rect2(Vector2.ZERO, bs))
	if src.has_area():
		draw_texture_rect_region(_backdrop, Rect2(src.position + _bd_pos, src.size),
			src, _view_tint)
	if dst.position.y < _bd_pos.y:
		var x0 := maxf(dst.position.x, _bd_pos.x)
		var x1 := minf(dst.end.x, _bd_pos.x + bs.x)
		var y1 := minf(dst.end.y, _bd_pos.y)
		if x1 > x0 and y1 > dst.position.y:
			draw_texture_rect_region(_backdrop,
				Rect2(Vector2(x0, dst.position.y), Vector2(x1 - x0, y1 - dst.position.y)),
				Rect2(Vector2(x0 - _bd_pos.x, 0.0), Vector2(x1 - x0, 1.0)), _view_tint)


## A view is cropped at 1:1, never scaled; `bottom`
## pins its foot to the opening's, which corridors need.
func _blit_view(r: Rect2, tex: Texture2D, bottom: bool) -> void:
	draw_rect(r, DEEP)
	if _backdrop != null:
		_blit_backdrop(r)
		_draw_cast(r)
		return
	if tex == null:
		return
	var ts := Vector2(tex.get_size())
	var src := Rect2(floorf((ts.x - r.size.x) * 0.5),
		(ts.y - r.size.y) if bottom else floorf((ts.y - r.size.y) * 0.5),
		r.size.x, r.size.y)
	var dst := r
	if src.position.x < 0.0:
		dst.position.x -= src.position.x
		dst.size.x = ts.x
		src.position.x = 0.0
		src.size.x = ts.x
	if src.position.y < 0.0:
		dst.position.y -= src.position.y
		dst.size.y = ts.y
		src.position.y = 0.0
		src.size.y = ts.y
	draw_texture_rect_region(tex, dst, src, VIEW_GLASS)


## A window onto the concourse: the view, people walking past in it, the glass,
## and a frame in the station's livery.
func _pane(r: Rect2, tex: Texture2D, i: int) -> void:
	_blit_view(r, tex, false)
	if tex != null and WALKERS and _cast.is_empty():
		_walkers(r, i)
	# The glass: a cold cast and two streaks of reflection. The streaks are what
	# make it glass rather than a hole -- without them the concourse is a poster.
	draw_rect(r, Color(0.35, 0.50, 0.72, 0.08))
	var y := 0.0
	while y < r.size.y:
		var d := r.position.x + r.size.x * 0.18 + y * 0.6
		_clip(Rect2(d, r.position.y + y, 12.0, 1.0), r, Color(0.8, 0.9, 1.0, 0.06))
		_clip(Rect2(d + 30.0, r.position.y + y, 4.0, 1.0), r, Color(0.8, 0.9, 1.0, 0.05))
		y += 1.0
	_frame(r, true)


## A door onto a corridor. No glass -- it is open -- so the corridor's own light
## reaches the threshold, and a hazard stripe says where the room stops.
func _door(r: Rect2, tex: Texture2D, _i: int) -> void:
	_blit_view(r, tex, true)
	# Darker toward the top: a doorway is lit from the floor strips, not the sky.
	var bands := 8
	for b in bands:
		var bh := r.size.y * 0.5 / float(bands)
		draw_rect(Rect2(r.position.x, r.position.y + bh * float(b), r.size.x, bh),
			Color(DEEP, 0.45 * (1.0 - float(b) / float(bands))))
	# THE BLAST DOORS, OPEN: a leaf slid back into each jamb. A hole in a wall is
	# a hole; a hole with its doors pulled aside is a door someone can close.
	for side in [r.position.x, r.end.x - 6.0]:
		var sxf: float = side
		draw_rect(Rect2(sxf, r.position.y, 6.0, r.size.y), PLATE)
		draw_rect(Rect2(sxf + (5.0 if sxf > r.position.x else 0.0), r.position.y,
			1.0, r.size.y), DEEP)
		draw_rect(Rect2(sxf + 2.0, r.position.y, 1.0, r.size.y),
			Color(STAR, 0.10))
		draw_rect(Rect2(sxf + 2.0, r.position.y + roundf(r.size.y * 0.45), 2.0, 2.0),
			Color(0.44, 0.83, 0.88, 0.85))
	_frame(r, false)
	var sx := r.position.x
	while sx < r.end.x:
		draw_rect(Rect2(sx, r.end.y - 3.0, 4.0, 3.0), Color(LAMP, 0.55))
		sx += 8.0


## The bezel is a nine-sliced sprite with the livery
## on its head bar; without art the drawn frame stays.
## Why: docs/why/StationRoom.md#openings
func _frame(r: Rect2, sill: bool) -> void:
	var box: StyleBoxTexture = _box_window if sill else _box_door
	if box != null:
		var outer := r.grow(12.0)
		if not sill:
			outer.size.y -= 12.0
		draw_style_box(box, outer)
		var m: ManufacturerData = DB.manufacturers.get(manufacturer)
		var badge: Color = m.colour if m != null else LAMP
		var bw := roundf(minf(48.0, r.size.x * 0.34) * 0.5) * 2.0
		draw_rect(Rect2(roundf(r.get_center().x - bw * 0.5), r.position.y - 8.0, bw, 2.0),
			Color(badge, 0.85))
		return
	var t := 5.0
	var outer2 := r.grow(t)
	if not sill:
		outer2.size.y -= t
	draw_rect(Rect2(outer2.position, Vector2(outer2.size.x, t)), PLATE)
	draw_rect(Rect2(outer2.position.x, r.position.y, t, r.size.y), PLATE)
	draw_rect(Rect2(r.end.x, r.position.y, t, r.size.y), PLATE)
	draw_rect(Rect2(outer2.position.x, outer2.position.y, outer2.size.x, 1.0),
		Color(STAR, 0.16))
	draw_rect(r.grow(1.0), _tint(EDGE), false, 1.0)
	if sill:
		draw_rect(Rect2(outer2.position.x, r.end.y, outer2.size.x, t), PLATE)
		draw_rect(Rect2(outer2.position.x, r.end.y, outer2.size.x, 1.0),
			Color(LAMP, 0.30))
		draw_rect(Rect2(outer2.position.x, r.end.y + t, outer2.size.x, 2.0),
			Color(DEEP, 0.6))


## A bezel sprite as a nine-slice, or null with no art. Built at load rather than
## in `_draw`, for the white-texture reason on `_plate_key`.
func _bezel(id: StringName, sill: bool, margin: float = 18.0) -> StyleBoxTexture:
	var tex := DB.station_sprite(&"frame", id)
	if tex == null:
		return null
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.draw_center = false
	sb.texture_margin_left = margin
	sb.texture_margin_right = margin
	sb.texture_margin_top = margin
	sb.texture_margin_bottom = margin if sill else 0.0
	# TILED, not stretched: a stretched edge smears its rivets.
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	return sb


static func _read_walk() -> void:
	if _walk_read:
		return
	_walk_read = true
	if FileAccess.file_exists(WALK_LINES_PATH):
		var a: Variant = JSON.parse_string(FileAccess.get_file_as_string(WALK_LINES_PATH))
		if a is Dictionary:
			_walk_lines = a
	if FileAccess.file_exists(STRIPS_PATH):
		var b: Variant = JSON.parse_string(FileAccess.get_file_as_string(STRIPS_PATH))
		if b is Dictionary:
			_strips = b


## Pick among strips within a sixth of the rung by seed, so every 80px line is not the same walker.
func _pick_strip(tall: float, s: int, flying: bool) -> String:
	var near: Array[String] = []
	var best := ""
	var bestd := 1.0e9
	for nm in _strips.keys():
		var m: Dictionary = _strips[nm]
		if bool(m.get("by_time", false)) != flying:
			continue
		var d: float = absf(float(m.get("frame_h", 0)) * float(_strip_k(m, tall)) - tall)
		if d < bestd:
			bestd = d
			best = String(nm)
		if d <= tall / 6.0:
			near.append(String(nm))
	# Far lines with no sprite near their size draw figures:
	# every far line used to get the same 74px sprite.
	# Why: docs/why/StationRoom.md#walker-picking
	if near.is_empty():
		return best if (flying or bestd <= tall * 0.2) else ""
	near.sort()
	return near[s % near.size()]


## Everyone walking behind this room, and the drones over them.
func _build_cast(bd: StringName) -> void:
	_cast.clear()
	_read_walk()
	if _strips.is_empty():
		return
	var lines: Variant = _walk_lines.get(String(bd), null)
	if not (lines is Array):
		return
	var rows: Array = lines
	if rows.is_empty():
		return
	# Distance from people's height, the bench's rule:
	# half the height is twice as far, half the speed.
	var near_tall := 0.0
	for row in rows:
		near_tall = maxf(near_tall, float(row.get("tall", 80)))
	for li in rows.size():
		var row: Dictionary = rows[li]
		var tall := float(row.get("tall", 80))
		var feet := float(row.get("y", 0))
		var depth := tall / near_tall if near_tall > 0.0 else 1.0
		# One or two to a line. More and a concourse reads as a queue.
		var n := 1 + absi(hash([place_seed, bd, li])) % 2
		for k in n:
			var s := absi(hash([place_seed, bd, li, k]))
			var nm := _pick_strip(tall, s, false)
			if nm == "":
				_spawn_figure(tall, feet, s, depth)
			else:
				_spawn(nm, feet, s, false, depth, tall)
	# A drone or two over the nearest line, riding above head height.
	var low := 0.0
	for row in rows:
		low = maxf(low, float(row.get("y", 0)))
	# A DOUBLED CONCOURSE HAS DOUBLED DRONES, riding twice as high: the scene's
	# scale is its nearest line against the ~80px the cast is drawn at.
	var sk := 2.0 if near_tall >= 120.0 else 1.0
	for k in 1 + absi(hash([place_seed, bd, &"fly"])) % 2:
		var s := absi(hash([place_seed, bd, &"fly", k]))
		var dn := _pick_strip(36.0 * sk, s, true)
		_spawn(dn, low - FLY_ALT * sk, s, true, 1.0, 36.0 * sk)


## A drawn person, for a line no sprite is the right height for.
func _spawn_figure(tall: float, feet: float, s: int, depth: float) -> void:
	var haze := clampf((1.0 - depth) * 0.7, 0.0, 0.45)
	_cast.append({
		"figure": true, "tall": tall, "feet": feet, "seed": s,
		"fw": ceilf(tall * 0.5), "fly": false,
		"ink": Color(0.03, 0.04, 0.07).lerp(Color(0.30, 0.38, 0.50), haze),
		"speed": WALK_PACE * (0.85 + 0.3 * float(s % 100) / 100.0) * depth,
		"flip": (s >> 11) % 2 == 0,
		"phase": float((s >> 3) % 1499),
	})


## Drawn at 1x or exactly 2x, the one resize pixel art survives (Jon, 2026-09-25).
static func _strip_k(m: Dictionary, tall: float) -> int:
	var fh := float(m.get("frame_h", 0))
	return 2 if fh > 0.0 and tall >= fh * 1.5 else 1


func _spawn(nm: String, feet: float, s: int, flying: bool, depth := 1.0, tall := 0.0) -> void:
	if nm == "" or not _strips.has(nm):
		return
	var m: Dictionary = _strips[nm]
	var path := "res://art/sprites/station/" + String(m.get("file", "walker_%s.png" % nm))
	if not ResourceLoader.exists(path):
		return
	var tex := load(path) as Texture2D
	if tex == null:
		return
	var fw := float(m.get("frame_w", 0))
	var fh := float(m.get("frame_h", 0))
	if fw <= 0.0 or fh <= 0.0:
		return
	var adv_v: Variant = m.get("advance", null)
	# Doubled: the frame, its stride AND the pace, so a big walker takes the
	# same number of steps a second as a small one rather than half.
	var k := float(_strip_k(m, tall))
	_cast.append({
		"tex": tex, "fw": fw * k, "fh": fh * k, "feet": feet, "k": k,
		"frames": maxi(1, int(m.get("frames", 1))),
		"adv": (float(adv_v) if adv_v != null else 0.0) * k,
		"fly": flying,
		"fps": float(m.get("fps", 10.0)),
		# Pace within a fifth of the room's, times its own gait, so the crowd is not in lockstep.
		"speed": WALK_PACE * float(m.get("gait", 1.0))
				* (0.85 + 0.3 * float(s % 100) / 100.0) * depth * k,
		"flip": (s >> 11) % 2 == 0,
		"phase": float((s >> 3) % 1499),
	})


## A walker outside the clip is not drawn, which is how somebody passes behind the wall.
func _draw_cast(clip: Rect2) -> void:
	if _backdrop == null or _cast.is_empty():
		return
	# Poses once per redraw, as a shaped hole calls this for every 1px run it is cut into.
	if _posed_at != _clock:
		_pose_cast()
	# REFLECTIONS FIRST, so a walker crossing another's reflection stands on it.
	if _reflect:
		for p in _posed:
			if not bool(p[0].get("figure", false)):
				_blit_reflection(p[0], p[1], p[2], p[3], clip)
	for p in _posed:
		var w: Dictionary = p[0]
		if bool(w.get("figure", false)):
			_figure(Vector2(p[1], p[2]), float(w["tall"]), int(w["seed"]), p[4],
				w["ink"], clip)
		else:
			_blit_walker(w, p[1], p[2], p[3], clip)


var _posed: Array = []
var _posed_at := -1.0


func _pose_cast() -> void:
	_posed_at = _clock
	_posed.clear()
	var bw := float(_backdrop.get_size().x)
	for w in _cast:
		var fw: float = w["fw"]
		var span := bw + fw * 2.0
		var run := fmod(_clock * float(w["speed"]) + float(w["phase"]), span)
		var f := 0
		var at := run
		if bool(w.get("figure", false)):
			# Feet at the centre, walking the same span as a sprite would.
			var fx := _bd_pos.x - fw * 0.5 + run
			if bool(w["flip"]):
				fx = _bd_pos.x + bw + fw * 0.5 - run
			_posed.append([w, roundf(fx), roundf(_bd_pos.y + float(w["feet"])), 0, run])
			continue
		if bool(w["fly"]):
			# A flyer's frames run on a clock: tied to
			# travel its rotors would speed up and slow down.
			f = int(_clock * float(w["fps"])) % int(w["frames"])
		else:
			var adv: float = w["adv"]
			if adv <= 0.0:
				continue
			# The body is drawn where it was at its frame start:
			# sliding between frames reads as skating.
			var steps := floorf(run / adv)
			f = int(steps) % int(w["frames"])
			at = steps * adv
		var x := _bd_pos.x - fw + at
		if bool(w["flip"]):
			x = _bd_pos.x + bw - at
		_posed.append([w, roundf(x),
			roundf(_bd_pos.y + float(w["feet"]) - float(w["fh"])), f, run])


func _blit_walker(w: Dictionary, x: float, y: float, f: int, clip: Rect2) -> void:
	var fw: float = w["fw"]
	var fh: float = w["fh"]
	var dst := Rect2(Vector2(x, y), Vector2(fw, fh))
	var cut := dst.intersection(clip)
	if not cut.has_area():
		return
	# Mirrored, the visible left edge comes from the
	# frame's right, so the offset is from the far side.
	var flip: bool = w["flip"]
	var off := (dst.end.x - cut.end.x) if flip else (cut.position.x - dst.position.x)
	# The slice is measured on screen; the frame is read in the strip's own
	# pixels, which a doubled walker has half as many of.
	var k: float = w.get("k", 1.0)
	var src := Rect2(Vector2(float(f) * fw / k + off / k, (cut.position.y - dst.position.y) / k),
		cut.size / k)
	var tex: Texture2D = w["tex"]
	if not flip:
		draw_texture_rect_region(tex, cut, src, _view_tint)
		return
	# Mirrored about the slice's right edge: local x 0 lands on cut.end.x and
	# runs back to cut.position.x, so the frame reads right to left.
	draw_set_transform(Vector2(cut.end.x, 0.0), 0.0, Vector2(-1.0, 1.0))
	draw_texture_rect_region(tex, Rect2(Vector2(0.0, cut.position.y), cut.size),
		src, _view_tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The frame upside down with its feet on the walker's feet,
## through a flip transform, for polished floors.
func _blit_reflection(w: Dictionary, x: float, y: float, f: int, clip: Rect2) -> void:
	var fw: float = w["fw"]
	var fh: float = w["fh"]
	var feet := y + fh
	var dst := Rect2(Vector2(x, feet), Vector2(fw, fh))
	var cut := dst.intersection(clip)
	if not cut.has_area():
		return
	var flip: bool = w["flip"]
	var off := (dst.end.x - cut.end.x) if flip else (cut.position.x - dst.position.x)
	# Upside down about the reflection's bottom edge: frame row r lands on
	# screen row (feet + fh - r), so the visible slice is rows from here.
	var row0 := feet + fh - cut.end.y
	var k: float = w.get("k", 1.0)
	var src := Rect2(Vector2(float(f) * fw / k + off / k, row0 / k), cut.size / k)
	var tint := Color(_view_tint, _view_tint.a * REFLECT_ALPHA)
	var ox := cut.end.x if flip else 0.0
	var lx := 0.0 if flip else cut.position.x
	draw_set_transform(Vector2(ox, feet + fh), 0.0, Vector2(-1.0 if flip else 1.0, -1.0))
	draw_texture_rect_region(w["tex"], Rect2(Vector2(lx, row0), cut.size), src, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Depth in three lanes comes from speed and haze,
## which is the whole parallax on a picture that never pans.
## Why: docs/why/StationRoom.md#walkers
func _walkers(r: Rect2, i: int) -> void:
	# far, mid, near: feet as a fraction down the pane, height, speed, haze
	var lanes := [[0.72, 16.0, 5.0, 0.30], [0.84, 22.0, 9.0, 0.15],
		[0.98, 30.0, 14.0, 0.0]]
	for lane in lanes.size():
		var spec: Array = lanes[lane]
		var n := 1 + absi(hash([place_seed, i, lane])) % 3
		for k in n:
			var s := absi(hash([place_seed, i, lane, k]))
			var speed: float = spec[2] * (0.8 + 0.4 * float(s % 100) / 100.0)
			var span := r.size.x + 40.0
			# A pause between passes, so the lanes are never a conveyor belt.
			var cycle := span + 80.0 + float((s >> 7) % 260)
			var run := fmod(_clock * speed + float((s >> 3) % 997), cycle)
			if run > span:
				continue
			var right := (s >> 11) % 2 == 0
			var x := (r.position.x - 20.0 + run) if right else (r.end.x + 20.0 - run)
			var feet := r.position.y + r.size.y * float(spec[0])
			var haze: float = spec[3]
			var ink := Color(0.03, 0.04, 0.07).lerp(Color(0.30, 0.38, 0.50), haze)
			_figure(Vector2(roundf(x), roundf(feet)), spec[1], s, run, ink, r)


## One walker, feet at `at`, `tall` pixels high, clipped to the pane.
func _figure(at: Vector2, tall: float, s: int, run: float, ink: Color, clip: Rect2) -> void:
	# The first block figure read as bollards: a person needs
	# a narrower head, a neck gap, a waist and swinging limbs.
	# Why: docs/why/StationRoom.md#figures
	var head := maxf(3.0, roundf(tall * 0.16))
	var chest := maxf(5.0, roundf(tall * 0.30)) + float(s % 2) * 2.0
	var torso := roundf(tall * 0.34)
	var legs := tall - head - 1.0 - torso
	var top := at.y - tall
	var cx := at.x
	var sx := cx - floorf(chest * 0.5)
	# Two frames of stride off the distance walked, so a slow walker steps slowly.
	var apart := int(run / maxf(2.0, tall * 0.3)) % 2 == 0
	# Head, corners knocked off so it is round rather than a tile.
	var hx := cx - floorf(head * 0.5)
	_clip(Rect2(hx + 1.0, top, head - 2.0, 1.0), clip, ink)
	_clip(Rect2(hx, top + 1.0, head, head - 1.0), clip, ink)
	# Neck, then shoulders full width, tapering to the waist.
	var ny := top + head
	_clip(Rect2(cx - 1.0, ny, 2.0, 1.0), clip, ink)
	var ty := ny + 1.0
	_clip(Rect2(sx, ty, chest, ceilf(torso * 0.5)), clip, ink)
	_clip(Rect2(sx + 1.0, ty + ceilf(torso * 0.5), chest - 2.0, floorf(torso * 0.5)), clip, ink)
	# Arms: hanging past the waist, one forward and one back in the stride frame.
	var arm := roundf(torso * 0.95)
	var swing := 1.0 if apart else 0.0
	_clip(Rect2(sx - 1.0, ty + 1.0 + swing, 1.0, arm), clip, ink)
	_clip(Rect2(sx + chest, ty + 1.0 + (1.0 - swing), 1.0, arm), clip, ink)
	# Legs: apart, then passing.
	var ly := ty + torso
	var lw := maxf(1.0, floorf(chest * 0.25))
	if apart:
		_clip(Rect2(sx + 1.0 - 1.0, ly, lw, legs), clip, ink)
		_clip(Rect2(sx + chest - 1.0 - lw + 1.0, ly, lw, legs), clip, ink)
	else:
		_clip(Rect2(cx - lw, ly, lw * 2.0, legs), clip, ink)
	# A lamplight rim keeps a walker readable against dark reflective floors.
	var rim := Color(LAMP, 0.55 * (1.0 - ink.b))
	var edge := sx + chest - 1.0 if (s >> 5) % 2 == 0 else sx
	_clip(Rect2(hx + 1.0, top, head - 2.0, 1.0), clip, rim)
	_clip(Rect2(edge, ty, 1.0, ceilf(torso * 0.5)), clip, rim)
	# Some carry something: a crate on the shoulder, or a lit datapad.
	match s % 7:
		0: _clip(Rect2(sx - 1.0, ty - 3.0, chest * 0.6, 3.0), clip, ink)
		1: _clip(Rect2(sx + chest + 1.0, ty + 3.0, 1.0, 1.0), clip,
			Color(0.45, 0.85, 0.95, 0.9))


## A rect cut to a clip rect -- what keeps a walker inside the glass.
func _clip(rr: Rect2, clip: Rect2, c: Color) -> void:
	var cut := rr.intersection(clip)
	if cut.has_area():
		draw_rect(cut, c)


## A low cold haze over the foot of the wall and the deck: the air in the room.
## Drawn last, so it lies over the light pools as well -- haze is lit too.
func _draw_haze(w: float, h: float, floor_y: float) -> void:
	var top := floor_y - 90.0
	var steps := 14
	var bh := (h - top) / float(steps)
	for b in steps:
		var a := 0.12 * minf(1.0, float(b + 1) / float(steps) * 1.4)
		draw_rect(Rect2(0.0, top + bh * float(b), w, bh + 1.0),
			Color(0.27, 0.35, 0.47, a))


## The foreground is its own node because the furniture is:
## nothing this room draws can reach above it.
## Why: docs/why/StationRoom.md#foreground
func foreground() -> Control:
	if _fore == null:
		var f := _Fore.new()
		f.room = self
		f.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		f.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fore = f
	return _fore


class _Fore extends Control:
	var room: StationRoom

	func _draw() -> void:
		if room != null and is_instance_valid(room):
			room._draw_fore(self)


## Cables slung across the top of the deck, near black, with a faint warm rim
## underneath from the lamps. Two or three, placed by the seed.
func _draw_fore(c: Control) -> void:
	if _plate_wall == null:
		return
	var w := c.size.x
	if w < 120.0:
		return
	var dark := Color(0.016, 0.02, 0.03)
	var rim := Color(LAMP, 0.22)
	var n := 2 + absi(hash([place_seed, &"cables"])) % 2
	for k in n:
		var s := absi(hash([place_seed, &"cable", k]))
		var x0 := float(s % int(w * 0.5)) - 40.0
		var x1 := x0 + w * (0.45 + float((s >> 5) % 40) / 100.0)
		var sag := 18.0 + float((s >> 9) % 40)
		var y0 := float((s >> 13) % 18)
		var x := x0
		while x < x1:
			var t := (x - x0) / (x1 - x0)
			var y := roundf(y0 + 4.0 * sag * t * (1.0 - t))
			c.draw_rect(Rect2(x, y, 2.0, 3.0), dark)
			c.draw_rect(Rect2(x, y + 3.0, 2.0, 1.0), rim)
			x += 2.0


# ------------------------------------------------------------ shared furniture


## One crate. Lighter than the floor it stands on, because a thing standing on a
## surface has to out-read the surface.
func _crate(r: Rect2) -> void:
	draw_rect(r, CRATE)
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1.0), CRATE_LIP)
	draw_rect(Rect2(r.position.x, r.position.y, 1.0, r.size.y),
		Color(CRATE_LIP, 0.45))
	draw_rect(Rect2(r.position.x, r.position.y + r.size.y * 0.42,
		r.size.x, 2.0), Color(DEEP, 0.55))


## The hull arc says you are on something, so it is drawn
## solid and lit; as a translucent band it read as a gradient.
## Why: docs/why/StationRoom.md#window
func _window(sky: Rect2) -> void:
	draw_rect(sky, DEEP)
	# Stars keep off the frame and vary in brightness and hue, as identical dots read as a loop.
	for i in 46:
		var sx := floorf(sky.position.x + 4.0 + _scatter(i * 7 + 1, sky.size.x - 8.0))
		var sy := floorf(sky.position.y + 4.0 + _scatter(i * 13 + 5, sky.size.y - 8.0))
		var mag := 0.25 + 0.75 * (float(i % 5) / 4.0)
		var tone := STAR
		if i % 11 == 3:
			tone = Color(0.98, 0.80, 0.60)
		elif i % 13 == 5:
			tone = Color(0.62, 0.78, 1.0)
		draw_rect(Rect2(sx, sy, 1.0, 1.0), Color(tone, mag))
		if i % 9 == 4:
			var arm := Color(tone, 0.35)
			draw_rect(Rect2(sx - 1.0, sy, 1.0, 1.0), arm)
			draw_rect(Rect2(sx + 1.0, sy, 1.0, 1.0), arm)
			draw_rect(Rect2(sx, sy - 1.0, 1.0, 1.0), arm)
			draw_rect(Rect2(sx, sy + 1.0, 1.0, 1.0), arm)
	var hull := Color("#141c27")
	var arc := 0.0
	while arc < sky.size.x:
		var bow := roundf(sky.size.y * 0.30 * sin(PI * arc / sky.size.x))
		if bow > 0.0:
			var top := sky.end.y - bow
			draw_rect(Rect2(sky.position.x + arc, top, 2.0, bow), hull)
			draw_rect(Rect2(sky.position.x + arc, top, 2.0, 1.0),
				Color(STAR, 0.30))
			# Ports: lit windows in a row just under the rim, some dark.
			if int(arc) % 10 == 4 and bow > 6.0 and _scatter(int(arc), 5.0) > 1.2:
				draw_rect(Rect2(sky.position.x + arc, top + 3.0, 2.0, 1.0),
					Color(LAMP, 0.75))
		arc += 2.0
	if _box_window != null:
		# Mullions as posts of the same steel as the bezel, bevelled like it.
		var mx := sky.position.x + 116.0
		while mx < sky.end.x - 20.0:
			draw_rect(Rect2(mx - 3.0, sky.position.y, 8.0, sky.size.y), Color("#151e2a"))
			draw_rect(Rect2(mx - 3.0, sky.position.y, 2.0, sky.size.y), Color("#3a4c64"))
			draw_rect(Rect2(mx + 3.0, sky.position.y, 2.0, sky.size.y), Color("#0d131c"))
			draw_rect(Rect2(mx - 1.0, sky.position.y + roundf(sky.size.y * 0.5) - 1.0,
				2.0, 2.0), Color("#687c96"))
			mx += 116.0
		_frame(sky, true)
		return
	draw_rect(sky, _tint(EDGE), false, 2.0)
	draw_rect(Rect2(sky.position.x, sky.end.y - 1.0, sky.size.x, 3.0),
		Color(LAMP, 0.22))
	var mx2 := sky.position.x + 116.0
	while mx2 < sky.end.x - 20.0:
		draw_rect(Rect2(mx2, sky.position.y, 3.0, sky.size.y), _tint(PLATE))
		draw_rect(Rect2(mx2, sky.position.y, 1.0, sky.size.y),
			Color(EDGE, 0.6))
		mx2 += 116.0

