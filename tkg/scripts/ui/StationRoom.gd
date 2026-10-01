class_name StationRoom
extends Control

## The room a station deck happens in: a back wall, a floor, and the lamps over
## it. Every deck but the Shipyard's hangar is one of these with its own furniture.
##
## ONE ROOM, FOUR DECKS. The Promenade got a room first and everything in it --
## the palette, the tint, the lamp count, the floor laid in widening courses, the
## light pools drawn after the floor -- was worked out the hard way, one wrong
## screenshot at a time. The Exchange, the Hiring Hall and the Laboratory need
## exactly that room with different things standing in it, and three copies of
## two hundred lines is three places for the next lesson to be learned only once.
## So the room is here and each deck says only what is DIFFERENT about it, in
## `_dress_wall` and `_dress_floor`.
##
## A PLACEHOLDER THAT IS ALSO THE FALLBACK, like `YardScene`. The layout is the
## part worth settling with rectangles, and every answer is a constraint the art
## will have to meet. If a generated plate never lands, this is what the station
## looks like.

## How built-up this station is, from `MapGen.Development`. The axis that already
## sets prices and stock, so the picture says something true rather than
## decorating: fewer lamps at an outpost, more at a capital.
var dev: int = MapGen.Development.CITY
## Whoever holds the station. Tints the TRIM and nothing else -- see `_tint`.
var manufacturer: StringName = &""

## THE STATION'S OWN PALETTE, and deliberately the berth's numbers.
##
## `YardScene`'s header records why they are darker than they look like they
## should be: a mid-grey room puts mid-grey objects against mid-grey and every
## silhouette goes soft. The decks reading as one station is worth more than any
## one of them reading well alone.
const WALL := Color("#0d141d")
const PLATE := Color("#151e2a")
const EDGE := Color("#202d3d")
const DEEP := Color("#080c12")
const LAMP := Color("#d97b29")
const FLOOR := Color("#121a24")
const FLOOR_LINE := Color("#1c2836")
const STAR := Color("#c3d2e2")
## A crate, and the lit edge that makes it a box rather than a swatch.
const CRATE := Color("#1e2836")
const CRATE_LIP := Color("#33445c")

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## How deep the floor band is, measured up from the bottom.
##
## The furniture stands on the bottom edge of this control, so this is the strip
## of deck VISIBLE around it. A function rather than a constant so a deck whose
## furniture is taller than the shop's can give itself less floor.
func floor_h() -> float:
	return 78.0


## How many lamps hang over the room.
func _lamps() -> int:
	match dev:
		MapGen.Development.OUTPOST: return 2
		MapGen.Development.SETTLEMENT: return 3
		MapGen.Development.CAPITAL: return 6
		_: return 4


## A colour pigment-shifted toward whoever holds the station.
##
## ON THE TRIM, NOT ON THE WALLS -- which is the whole finding.
##
## A lerp moves each channel by a fraction of ITS OWN GAP, and out of a colour
## this dark the gaps are wildly uneven: Solari's #ed9b22 against #0d141d is 224
## of red and 5 of blue. Any weight at all therefore does not tint a wall, it
## DESATURATES it -- at 0.12 the shop's wall came out #2f2d29 and at 0.06
## #1a1c1d, both neutral warm greys where the station is meant to be cold blue.
##
## So big surfaces keep the station's colour and the livery goes on the EDGES:
## joints, studs, conduit, window frames, floor courses. That is how a livery
## works anyway -- nobody repaints a hull, they paint the trim -- and a 2px line
## can afford to be orange.
func _tint(c: Color) -> Color:
	var m: ManufacturerData = DB.manufacturers.get(manufacturer)
	return c if m == null else c.lerp(m.colour, 0.18)


## A repeatable scatter. Stars and bubbles have to land in the same place every
## redraw or they twinkle each time the pointer moves, and GDScript's RNG is a
## stream rather than a function of position.
func _scatter(i: int, span: float) -> float:
	return fmod(float(i) * 2654435761.0 / 65536.0, span)


## Which plate this room wants, or `&""` for none.
##
## KEYED ON THE DECK, NOT ON DEVELOPMENT, because the plate is a BACKDROP and
## carries no lamps. The lamp count is what development changes, and lamps are
## drawn over the plate from `_lamps()` -- so one plate serves an outpost and a
## capital alike, and the twelve this used to need are three. Decks override
## this; the base is the plain room.
func plate_id() -> StringName:
	return &"room"


## The room as two generated layers, or `false` if either is missing.
##
## TWO LAYERS BECAUSE THE LIVERY TINTS TRIM ONLY, which is `_tint`'s finding
## above: a wall lerped toward a manufacturer colour desaturates instead of
## tinting. So the plate ships as `<id>_wall.png` flat and `<id>_trim.png`
## through `_tint`, and the orange lands on the joints and the courses where it
## belongs.
##
## RESOLVED OUTSIDE A DRAW CALL AND REMEMBERED.
##
## A TEXTURE FIRST TOUCHED INSIDE `_draw` RENDERS WHITE. Resolving one there
## hands the renderer a resource whose GPU side is not ready for the commands
## being recorded, and the sampler falls back to white -- every texture, every
## size, `draw_texture` and `draw_texture_rect` alike, while `draw_rect` on the
## same item draws correctly. A room draws about twice in its life, so it keeps
## that white for good. Rect-drawn rooms never hit it, which is why it waited
## for the first plate to appear.
##
## Keyed on the id so a deck that changes development level reloads rather than
## keeping the plate it was born with; `dev` is set after `_ready`, so loading
## there would cache the wrong one.
var _plate_key: StringName = &""
var _plate_wall: Texture2D = null
var _plate_trim: Texture2D = null
## The lamp, as art rather than rectangles. Shared by every deck and every
## development level: what changes is how many are hung and what colour the
## light is, and both of those are the room's to decide.
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
	# Every opening frame this station might cut, resolved here rather than in
	# the draw call that needs it. Fifteen small textures; the room is built
	# about twice in its life.
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


## The lamps as sprites, or `false` if there is no art and rectangles it is.
##
## THE COUNT AND THE POSITIONS STAY THE ROOM'S. Art supplies the fixture and the
## shape of the light; `_lamps()` says how many and `w * (i + 0.5) / n` says
## where, so an outpost still reads as two lamps and a capital as six off one
## plate. The glow is drawn through `_light()`, which is how the Laboratory gets
## cold light out of the same cone everything else lights warm.
## The lamps as rectangles: the fallback, and what the room has always drawn.
##
## THE LIGHT LANDS ON THE FLOOR. A lamp that glows and lights nothing is a
## sticker; the pool underneath is the half that makes the room have a source,
## and it is drawn later, after the plating it falls on.
func _lamp_rects(w: float, _floor_y: float) -> void:
	var n := _lamps()
	var glow := _light()
	for i in n:
		var lx := w * (float(i) + 0.5) / float(n)
		draw_rect(Rect2(lx - 1.0, 0.0, 2.0, 9.0), _tint(EDGE))
		draw_rect(Rect2(lx - 7.0, 9.0, 14.0, 4.0), _tint(EDGE))
		draw_rect(Rect2(lx - 5.0, 12.0, 10.0, 2.0), Color(glow.r, glow.g, glow.b, 0.85))


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
				false, Color(glow.r, glow.g, glow.b, 0.62))
		draw_texture(_lamp_hood, Vector2(lx - hood.x * 0.5, 0.0).round())
		if _lamp_pool != null:
			var pw := maxf(60.0, w / float(n) * 0.92)
			draw_texture_rect(_lamp_pool,
				Rect2(lx - pw * 0.5, floor_y, pw, floor_h()),
				false, Color(glow.r, glow.g, glow.b, 0.75))
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
	# Stretched to the room, NOT centred, because a room is a fitted surface
	# rather than an object standing in one -- the wall has to reach both edges
	# whatever width the rail leaves. This is the one place in the art direction
	# where a texture is not drawn at 1:1, and it is why a plate is authored at
	# the size the panel actually is rather than cropped to its ink.
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
		# A plate is the ROOM AS A BACKDROP -- walls, deck, and nothing that
		# varies. The lamps go on over it because their COUNT is development and
		# their COLOUR is the deck, and the furniture goes on over that because
		# it is per-deck and often live: the Exchange's cage is measured off the
		# hold grid every redraw, and the service rigs reach for whatever hull
		# is parked. None of those can be baked and none of them are meant to be.
		_draw_openings(w, h, floor_y)
		_dress_wall(w, h, floor_y)
		# NO LAMPS ON THE ART PATH. The generated hood and its drawn cone and
		# pool read as stickers over a room that is otherwise made, and were
		# cut. `_draw_lamp_art` stays for when lighting comes back as art that
		# belongs; the drawn fallback room below still hangs its own.
		_dress_floor(w, h, floor_y)
		_draw_haze(w, h, floor_y)
		return

	# --- THE BACK WALL, AND IT IS THE DARKEST THING IN THE ROOM.
	#
	# It was `PLATE` for one pass, which is the colour of the FURNITURE -- so the
	# shop's rack and till read as dark holes cut in a lighter wall. Everything
	# standing in a room has to out-read the room. Untinted, for the reason
	# `_tint` gives at length.
	draw_rect(Rect2(0.0, 0.0, w, floor_y), WALL)
	# Panel joints, wide and faint. A flat wall reads as a hole.
	var jy := 30.0
	while jy < floor_y - 8.0:
		draw_rect(Rect2(0.0, jy, w, 1.0), _tint(EDGE))
		draw_rect(Rect2(0.0, jy + 1.0, w, 1.0), Color(DEEP.r, DEEP.g, DEEP.b, 0.45))
		jy += 46.0
	var jx := 62.0
	while jx < w - 20.0:
		draw_rect(Rect2(jx, 0.0, 2.0, floor_y), _tint(EDGE))
		jx += 124.0

	_dress_wall(w, h, floor_y)

	_lamp_rects(w, floor_y)

	# --- THE FLOOR.
	#
	# BEFORE THE LIGHT THAT FALLS ON IT. The pools were once drawn with the lamps
	# and the floor went down on top of them, so the lamps lit a room that stayed
	# uniformly dark -- painted over by the surface they were lighting.
	draw_rect(Rect2(0.0, floor_y, w, floor_h()), FLOOR)
	# The junction, lit along the top edge: the one line that stops the wall and
	# the deck being the same surface.
	draw_rect(Rect2(0.0, floor_y, w, 2.0), _tint(FLOOR_LINE))
	draw_rect(Rect2(0.0, floor_y + 2.0, w, 3.0), Color(DEEP.r, DEEP.g, DEEP.b, 0.55))
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
				Color(DEEP.r, DEEP.g, DEEP.b, 0.35))
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


## Where this room hangs the station's manufacturer banners. Each entry is a
## horizontal anchor fraction and a top; the screen hangs the whole set side by
## side, centred on it. Empty means the room hangs none.
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
#
# A ROOM IN DEPTH, NOT A ROOM ON A PANEL. The back wall opens -- a window onto
# the concourse outside, a door onto a corridor -- and what is seen through each
# opening is a generated view of somewhere else on the station, with people
# walking past in it. In front of the whole deck, furniture included, hang dark
# cables. Nothing here moves the camera, so the depth comes from what a still
# picture can do: overlap, far things hazier than near ones, a dark frame in
# front, and near things moving faster than far ones.
#
# ALL OF IT IS THE PLATE PATH'S. A deck with no art keeps the rectangles it had.

## Which station this is, as a number: picks the views, the walkers and the
## cables, so a station looks the same every visit and different from the next.
var place_seed: int = 0

## What can be seen through each kind of opening. Checked against the files when
## the plate loads, so an id with no art drops out of the pool rather than
## drawing a hole.
const VIEWS := {
	&"window": [&"prom_a", &"prom_d", &"shops_b", &"arcade_a",
		&"arcade_b", &"gallery_c", &"lounge_a", &"lounge_b", &"mess_a",
		&"mess_b", &"mess_c", &"garden_b", &"garden_c", &"obs_a", &"obs_b"],
	&"door": [&"hall_a", &"hall_b", &"hall_c"],
}

## A view is somewhere else, seen through glass: a touch colder than it was
## drawn. The heavy lifting -- getting it to sit BEHIND the room's own light --
## is done once at install, by `room_plate.py view`, which fits each view's
## midtones and leaves its lit signs alone.
const VIEW_GLASS := Color(0.90, 0.94, 1.0)
## How often the moving layers redraw: 30, as the room bench does.
##
## It was 12, the sector view's rate, on the grounds that pixel art moving at
## 60 Hz reads as sliding. That does not apply here: a walker's body only moves
## when its pose changes (planted feet, Jon's pick), and poses change 4 to 13
## times a second -- so at 12 Hz every pose was held for 83 or 167 ms at
## random, and the fastest walker skipped poses outright. At 30 the holds are
## even and nothing is skipped. Walkers, drones and the drawn figures are the
## only things on this clock.
const LAYER_HZ := 30.0

## A view to show instead of the seed's pick, by kind. For `stationshot view=`,
## which photographs a named view in its real window; nothing in play sets it.
static var forced_views := {}

## The place outside and its walkers with no room round them, for
## `stationshot roomview`: the elevator's Promenade picture is filmed from it.
## Nothing in play sets it.
static var view_only := false

var _views: Array = []
var _box_window: StyleBoxTexture = null
## ONE PLACE BEHIND THE WHOLE WALL, when there is one: every opening shows the
## part of it behind that hole, instead of each opening picking its own view.
## Placed by `_draw_openings` so its walkway meets this room's floor.
##
## EVERY ONE IS 800x400, AND THAT IS NOT A STYLE CHOICE. `_bd_pos` centres the
## picture on the wall and stands it on the floor line, so on the 740x431 panel
## it sits at (-30, -47) -- past both sides and over the top. The set this
## replaced was 808 wide but only 286 to 352 tall, which left between 1 and 67
## pixels of bare wall above it, and an opening dragged high showed the gap.
## Drawing those smaller to widen the view only uncovered more wall. Any
## backdrop added here has to reach as far.
## ONE POOL PER DEVELOPMENT LEVEL (Jon, 2026-09-25). The promenade behind the
## wall is part of how a station says how built-up it is, so a squat never
## looks out on a capital atrium. Each is `backdrop_<level>_<name>.png`; the
## first set of 25 (arches, archive ... vitrine) is retired, files kept, and
## `room_bench.py` fails its build if this and its VIEWS ever disagree.
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
## FLOORS THAT SHOW A REFLECTION: the walkers on these are drawn a second
## time, upside down under their feet and faint (Jon, 2026-09-25). Only the
## backdrops whose floor was generated polished; a reflection on grating
## would be a lie about the floor.
const REFLECTIVE: Array[StringName] = [&"outpost_hydro", &"outpost_vending"]

var _backdrop: Texture2D = null
## Which backdrop that is, by id: what `_load_plate` drew from the pool.
var _bd_id: StringName = &""
var _bd_pos := Vector2.ZERO
## WHAT THE CONCOURSE IS SEEN THROUGH: `VIEW_GLASS`, a touch colder than drawn.
## The shop turns it off -- its rooms are the bench's, which never cooled the
## view, and its openings carry their own glaze.
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

## PEOPLE ON THE CONCOURSE, as pixel-art sprites on the backdrop.
##
## THEY BELONG TO THE BACKDROP, NOT TO A WINDOW. Each one stands on a walk line
## measured for that particular backdrop and moves in the picture's own
## coordinates, so two openings onto the same stretch of concourse show the
## same person in the same place. The procedural figures this replaces were
## drawn per pane in lanes, which meant two windows side by side showed two
## unrelated crowds of the same three silhouettes.
##
## A FUNCTION OF THE CLOCK, not a list that steps: each walker's position comes
## from the time and its own seed, so nothing has to be kept in step and a room
## that was hidden picks up wherever the clock says it should be.
const WALKERS := true

const WALK_LINES_PATH := "res://art/sprites/station/backdrop_walk.json"
const STRIPS_PATH := "res://art/sprites/station/walker_strips.json"

## The pace the concourse walks at, and it is NOT a free number. A walker's
## frame is chosen by the distance it has covered, so this sets how fast the
## legs move as well as how fast the body crosses.
##
## 40, ON JON'S CALL, AND IT BREAKS THE RULE THE CYCLES WERE CUT TO. At 20 a
## thirteen-frame cycle plays about 4.7 frames a second, inside the band where
## the eye separates steps; at 40 the same cycle plays 9.5, which is half again
## past the 6.3 he once rejected outright as jitter. Every cycle in
## `walker_strips.json` was measured and judged at 20.
##
## It is here at 40 anyway because his eye has overruled that arithmetic six
## times running -- five quality gates and a drone bob depth, every one of them
## fitted to his earlier verdicts and broken by his next one. A number nobody
## has watched is worth less than a look.
const WALK_PACE := 40.0

## How far above its walk line a drone rides. A flyer touches nothing, so
## unlike a walker -- whose feet ARE the placement -- there is nothing in the
## art to say where it belongs.
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


## Where this deck's back wall opens, as `{rect, kind}` with kind `&"window"` or
## `&"door"`. Empty is a blind wall. A deck places these round its own furniture;
## the room knows nothing about what stands in front of it.
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
	# HALF A FRAME OF SLACK. `_since` counts whole frames, and two 60 Hz frames
	# sum to a hair under 1/30 often enough that the gate waited a third one --
	# measured, the room redrew anywhere from 10 to 12 times a second at a
	# nominal 12. With the slack it fires on the frame nearest the period.
	if _since >= 1.0 / LAYER_HZ - 0.5 * delta:
		_since = 0.0
		queue_redraw()


func _draw_openings(w: float, h: float, floor_y: float) -> void:
	var list := openings(w, h, floor_y)
	if _backdrop != null:
		# FIXED TO THE WALL: centred across it, standing on the floor. It is the
		# place outside, so where the openings are changes what you see of it,
		# never where it is. (Centring it on the openings made it slide whenever
		# a window moved.) The walkway is at the foot of the picture, so a door
		# opens onto it at deck level.
		var bs := Vector2(_backdrop.get_size())
		# DROPPED BY ITS OWN HEIGHT: how far down this picture sits so its floor
		# meets the room's, set by eye per backdrop on the heights page (Jon,
		# 2026-09-25) and kept in `backdrop_drops.json`. 0 is the old placement,
		# bottom edge on the floor line.
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


## A HOLE THAT IS NOT A RECTANGLE. An arch, a canopy, a torn breach: the sprite
## carries the frame, and the station shows through the shape cut in it.
##
## THE SPRITE CANNOT TELL US WHERE THE HOLE IS. Both the hole and the air around
## the frame are transparent in it, so filling "everywhere the sprite is clear"
## paints promenade in a square all round the opening -- which is exactly what
## the bench did until the hole was measured out separately. `opening_holes.json`
## holds the inside as spans of [y, x, width]; we fill those and nothing else,
## then lay the sprite over the top.
func _shaped_opening(r: Rect2, tex: Texture2D, skin: StringName) -> void:
	# FROM THE CACHE, NEVER `load()` HERE. Resolving a texture inside a draw
	# call hands the renderer a resource whose GPU side is not ready and it
	# samples opaque white for good -- the warning at the top of this file,
	# broken nine hundred lines below where it is written. Every opening frame
	# in the game rendered as a solid white rectangle because of this one line,
	# and it was invisible in the bench because the bench never ran this path.
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


## The size a shaped opening wants, so a layout can place it without hardcoding
## numbers that would silently disagree with the art.
static func opening_size(skin: StringName) -> Vector2:
	_hole_runs(skin)
	var entry: Variant = _holes.get(String(skin), null)
	if entry is Dictionary:
		return Vector2(float(entry.get("w", 0)), float(entry.get("h", 0)))
	return Vector2.ZERO


## Three portholes in one plate over one view. The view is drawn across the
## whole opening and the plate covers everything but the holes, glass and all.
func _porthole_plate(r: Rect2, tex: Texture2D) -> void:
	_blit_view(r, tex, false)
	var ps := Vector2(_ports.get_size())
	draw_texture(_ports, (r.get_center() - ps * 0.5).round())


## The backdrop, in whatever part of `dst` it covers -- and above its top edge,
## its top row stretched up to the ceiling. A dropped picture no longer reaches
## the top of the wall, and the top of these views is deckhead or girder, so the
## row carries; the heights page and the bench draw it the same way, so what
## was judged there is what the room shows.
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


## A view cropped into its opening at 1:1 -- never scaled, because a view is
## pixel art like everything else here. `bottom` pins its foot to the opening's
## foot, which a corridor needs and a concourse does not.
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
			Color(DEEP.r, DEEP.g, DEEP.b, 0.45 * (1.0 - float(b) / float(bands))))
	# THE BLAST DOORS, OPEN: a leaf slid back into each jamb. A hole in a wall is
	# a hole; a hole with its doors pulled aside is a door someone can close.
	for side in [r.position.x, r.end.x - 6.0]:
		var sxf: float = side
		draw_rect(Rect2(sxf, r.position.y, 6.0, r.size.y), PLATE)
		draw_rect(Rect2(sxf + (5.0 if sxf > r.position.x else 0.0), r.position.y,
			1.0, r.size.y), DEEP)
		draw_rect(Rect2(sxf + 2.0, r.position.y, 1.0, r.size.y),
			Color(STAR.r, STAR.g, STAR.b, 0.10))
		draw_rect(Rect2(sxf + 2.0, r.position.y + roundf(r.size.y * 0.45), 2.0, 2.0),
			Color(0.44, 0.83, 0.88, 0.85))
	_frame(r, false)
	var sx := r.position.x
	while sx < r.end.x:
		draw_rect(Rect2(sx, r.end.y - 3.0, 4.0, 3.0), Color(LAMP.r, LAMP.g, LAMP.b, 0.55))
		sx += 8.0


## An opening's frame: the authored bezel, nine-sliced round the opening.
##
## THE BEZEL IS A SPRITE, NOT RECTANGLES -- `room_plate.py frames` records why.
## The livery goes on a light bar in its head, which is the one place on a frame
## a manufacturer would put a colour; with no bezel art the old drawn frame stays
## as the fallback.
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
			Color(badge.r, badge.g, badge.b, 0.85))
		return
	var t := 5.0
	var outer2 := r.grow(t)
	if not sill:
		outer2.size.y -= t
	draw_rect(Rect2(outer2.position, Vector2(outer2.size.x, t)), PLATE)
	draw_rect(Rect2(outer2.position.x, r.position.y, t, r.size.y), PLATE)
	draw_rect(Rect2(r.end.x, r.position.y, t, r.size.y), PLATE)
	draw_rect(Rect2(outer2.position.x, outer2.position.y, outer2.size.x, 1.0),
		Color(STAR.r, STAR.g, STAR.b, 0.16))
	draw_rect(r.grow(1.0), _tint(EDGE), false, 1.0)
	if sill:
		draw_rect(Rect2(outer2.position.x, r.end.y, outer2.size.x, t), PLATE)
		draw_rect(Rect2(outer2.position.x, r.end.y, outer2.size.x, 1.0),
			Color(LAMP.r, LAMP.g, LAMP.b, 0.30))
		draw_rect(Rect2(outer2.position.x, r.end.y + t, outer2.size.x, 2.0),
			Color(DEEP.r, DEEP.g, DEEP.b, 0.6))


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


## Pick a sprite for a rung. NOT simply the nearest by height, which would hand
## every 80px line the same one walker for ever. Anything within a sixth of the
## rung is close enough -- the cast measures 74-87px against an 80px line by
## design, because people are not all one height -- so the seed chooses among
## those and the nearest is only the fallback.
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
	# NOTHING NEAR, NOBODY DRAWN. Every sprite is 74-87px, so a 60px or 40px
	# line used to get the nearest one anyway -- a 74px curlyB on all nineteen
	# far lines, and on eight backdrops everyone was curlyB. A far line keeps
	# the drawn figures until sprites that size exist, as the bench does. A
	# drone has no line height to match, so it still takes the nearest.
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
	# HOW FAR OFF A LINE IS, FROM HOW TALL ITS PEOPLE ARE -- the bench's rule.
	# Half the height of the nearest line is twice as far away: half the speed,
	# and washed toward the colour of the air.
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


## AT ITS OWN SIZE OR EXACTLY DOUBLED. The room and every backdrop are pixel
## art drawn 2x2; the walkers are 1:1, so on a line twice a strip's height the
## strip is drawn at 2x -- the one resize pixel art survives (Jon, 2026-09-25:
## "the scale of people are so tiny compared to the door and the room").
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
		# Each one within a fifth of the room's pace, so the concourse is never
		# a conveyor belt of people in lockstep -- times its own gait, since an
		# elder with a stick does not keep up with a porter.
		"speed": WALK_PACE * float(m.get("gait", 1.0))
				* (0.85 + 0.3 * float(s % 100) / 100.0) * depth * k,
		"flip": (s >> 11) % 2 == 0,
		"phase": float((s >> 3) % 1499),
	})


## Draw the concourse's people into whatever part of the backdrop is showing.
## `clip` is in canvas space; a walker outside it is simply not drawn, which is
## how somebody passes behind the wall between two windows.
func _draw_cast(clip: Rect2) -> void:
	if _backdrop == null or _cast.is_empty():
		return
	# ONCE PER REDRAW, NOT ONCE PER ROW. A shaped hole calls this for every
	# 1px run it is cut into, and every call used to work out every walker
	# again from the same clock. The poses are the same for the whole redraw.
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
			# A flyer's frames run on a CLOCK. It touches nothing, so tying its
			# rotors to its travel would have them speed up and slow down with
			# it -- the one thing a hovering thing must not do.
			f = int(_clock * float(w["fps"])) % int(w["frames"])
		else:
			var adv: float = w["adv"]
			if adv <= 0.0:
				continue
			# THE BODY IS DRAWN WHERE IT WAS AT THE START OF ITS FRAME. Sliding
			# it smoothly between frame changes drags the planted boot a pixel
			# at a time, hundreds of times a minute, and that is what reads as
			# skating however well the stride was measured.
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
	# Which columns of the frame the visible slice shows. Mirrored, the visible
	# LEFT edge comes from the frame's RIGHT, so the offset is taken from the
	# far side instead.
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


## The same frame upside down, head at the bottom, its feet on the walker's
## feet -- what a polished floor gives back. Drawn through a transform that
## flips both axes as needed, so the clip slice maps onto the right rows and
## columns of the frame whichever way the walker faces.
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
	var tint := Color(_view_tint.r, _view_tint.g, _view_tint.b, _view_tint.a * REFLECT_ALPHA)
	var ox := cut.end.x if flip else 0.0
	var lx := 0.0 if flip else cut.position.x
	draw_set_transform(Vector2(ox, feet + fh), 0.0, Vector2(-1.0 if flip else 1.0, -1.0))
	draw_texture_rect_region(w["tex"], Rect2(Vector2(lx, row0), cut.size), src, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## People walking past on the far side of the glass, in three lanes.
##
## DEPTH BY SPEED AND HAZE. The near lane is lowest, tallest, darkest and
## fastest; the far lane is higher, smaller, paler and slower. On a picture that
## never pans, that difference in speed is the whole of the parallax.
##
## A FUNCTION OF THE CLOCK, not a list of walkers that step: each one's place is
## computed from the time and its own seed, so there is no state to keep in step
## and a room that was hidden picks up exactly where the clock says.
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
	# A PERSON, NOT A POST. The first cut was a block with a head the same width
	# and read as a row of bollards. What says "person" at twenty pixels is the
	# head narrower than the shoulders, a gap for the neck, a waist narrower than
	# the chest, and arms and legs that swing.
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
	# A RIM OF LAMPLIGHT down one side and over the head. A silhouette only reads
	# against something lit, and half these views have dark reflective floors --
	# the rim is what keeps a walker there when the floor behind it goes black.
	var rim := Color(LAMP.r, LAMP.g, LAMP.b, 0.55 * (1.0 - ink.b))
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


## The layer IN FRONT of the deck, furniture and all, as its own node.
##
## ITS OWN NODE BECAUSE THE FURNITURE IS. A deck's rack, till and cage are
## children of the screen stacked over this room, and nothing this room draws can
## reach above them. So the screen adds this after the furniture, and it draws
## the cables that make the whole deck sit behind something.
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
	var rim := Color(LAMP.r, LAMP.g, LAMP.b, 0.22)
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
		Color(CRATE_LIP.r, CRATE_LIP.g, CRATE_LIP.b, 0.45))
	draw_rect(Rect2(r.position.x, r.position.y + r.size.y * 0.42,
		r.size.x, 2.0), Color(DEEP.r, DEEP.g, DEEP.b, 0.55))


## A viewport onto space: stars, the station's own hull curving away below them,
## and a frame with a lit sill and mullions.
##
## The hull arc is the one mark that says you are ON something rather than
## looking at a poster -- so it is drawn as hull: solid, lit along its rim, with
## a row of lit ports along it. As a translucent band it read as a gradient.
func _window(sky: Rect2) -> void:
	draw_rect(sky, DEEP)
	# Stars. Fixed positions, three brightnesses, and none of them on the frame --
	# a star touching a mullion looks like a dead pixel. Every ninth is a bright
	# one drawn as a cross, and a few run warm or blue, because a field of
	# identical dots is the look of a loop rather than a sky.
	for i in 46:
		var sx := floorf(sky.position.x + 4.0 + _scatter(i * 7 + 1, sky.size.x - 8.0))
		var sy := floorf(sky.position.y + 4.0 + _scatter(i * 13 + 5, sky.size.y - 8.0))
		var mag := 0.25 + 0.75 * (float(i % 5) / 4.0)
		var tone := STAR
		if i % 11 == 3:
			tone = Color(0.98, 0.80, 0.60)
		elif i % 13 == 5:
			tone = Color(0.62, 0.78, 1.0)
		draw_rect(Rect2(sx, sy, 1.0, 1.0), Color(tone.r, tone.g, tone.b, mag))
		if i % 9 == 4:
			var arm := Color(tone.r, tone.g, tone.b, 0.35)
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
				Color(STAR.r, STAR.g, STAR.b, 0.30))
			# Ports: lit windows in a row just under the rim, some dark.
			if int(arc) % 10 == 4 and bow > 6.0 and _scatter(int(arc), 5.0) > 1.2:
				draw_rect(Rect2(sky.position.x + arc, top + 3.0, 2.0, 1.0),
					Color(LAMP.r, LAMP.g, LAMP.b, 0.75))
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
		Color(LAMP.r, LAMP.g, LAMP.b, 0.22))
	var mx2 := sky.position.x + 116.0
	while mx2 < sky.end.x - 20.0:
		draw_rect(Rect2(mx2, sky.position.y, 3.0, sky.size.y), _tint(PLATE))
		draw_rect(Rect2(mx2, sky.position.y, 1.0, sky.size.y),
			Color(EDGE.r, EDGE.g, EDGE.b, 0.6))
		mx2 += 116.0


## A run of conduit across the whole wall on brackets, because a station is
## plumbing with rooms in it and one pipe says so faster than any panelling.
func _conduit(y: float, w: float) -> void:
	draw_rect(Rect2(0.0, y, w, 3.0), _tint(EDGE))
	draw_rect(Rect2(0.0, y, w, 1.0), Color(STAR.r, STAR.g, STAR.b, 0.10))
	var bx := 34.0
	while bx < w - 10.0:
		draw_rect(Rect2(bx, y - 2.0, 4.0, 7.0), _tint(PLATE))
		bx += 78.0
