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


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 60.0 or h <= 120.0:
		return
	var floor_y := h - floor_h()

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

	# --- THE LAMPS, hung on stems from the ceiling.
	#
	# THE LIGHT LANDS ON THE FLOOR. A lamp that glows and lights nothing is a
	# sticker; the pool underneath is the half that makes the room have a source.
	var n := _lamps()
	var glow := _light()
	for i in n:
		var lx := w * (float(i) + 0.5) / float(n)
		draw_rect(Rect2(lx - 1.0, 0.0, 2.0, 9.0), _tint(EDGE))
		draw_rect(Rect2(lx - 7.0, 9.0, 14.0, 4.0), _tint(EDGE))
		draw_rect(Rect2(lx - 5.0, 12.0, 10.0, 2.0), Color(glow.r, glow.g, glow.b, 0.85))

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
	for i in n:
		var px := w * (float(i) + 0.5) / float(n)
		var step := 0
		while step < 6:
			var spread := 16.0 + float(step) * 14.0
			draw_rect(Rect2(px - spread, floor_y + float(step) * 13.0,
				spread * 2.0, 13.0),
				Color(glow.r, glow.g, glow.b, 0.075 - 0.011 * float(step)))
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
## looking at a poster.
func _window(sky: Rect2) -> void:
	draw_rect(sky, DEEP)
	# Stars. Fixed positions, three brightnesses, and none of them on the frame --
	# a star touching a mullion looks like a dead pixel.
	for i in 46:
		var sx := sky.position.x + 3.0 + _scatter(i * 7 + 1, sky.size.x - 6.0)
		var sy := sky.position.y + 3.0 + _scatter(i * 13 + 5, sky.size.y - 6.0)
		var mag := 0.25 + 0.75 * (float(i % 5) / 4.0)
		draw_rect(Rect2(floorf(sx), floorf(sy), 1.0, 1.0),
			Color(STAR.r, STAR.g, STAR.b, mag))
	var arc := 0.0
	while arc < sky.size.x:
		var bow := sky.size.y * 0.30 * sin(PI * arc / sky.size.x)
		draw_rect(Rect2(sky.position.x + arc, sky.end.y - bow, 2.0, bow),
			Color(EDGE.r, EDGE.g, EDGE.b, 0.75))
		arc += 2.0
	draw_rect(sky, _tint(EDGE), false, 2.0)
	draw_rect(Rect2(sky.position.x, sky.end.y - 1.0, sky.size.x, 3.0),
		Color(LAMP.r, LAMP.g, LAMP.b, 0.22))
	var mx := sky.position.x + 116.0
	while mx < sky.end.x - 20.0:
		draw_rect(Rect2(mx, sky.position.y, 3.0, sky.size.y), _tint(PLATE))
		draw_rect(Rect2(mx, sky.position.y, 1.0, sky.size.y),
			Color(EDGE.r, EDGE.g, EDGE.b, 0.6))
		mx += 116.0


## A run of conduit across the whole wall on brackets, because a station is
## plumbing with rooms in it and one pipe says so faster than any panelling.
func _conduit(y: float, w: float) -> void:
	draw_rect(Rect2(0.0, y, w, 3.0), _tint(EDGE))
	draw_rect(Rect2(0.0, y, w, 1.0), Color(STAR.r, STAR.g, STAR.b, 0.10))
	var bx := 34.0
	while bx < w - 10.0:
		draw_rect(Rect2(bx, y - 2.0, 4.0, 7.0), _tint(PLATE))
		bx += 78.0
