class_name ShopScene
extends Control

## The room the Promenade's shop stands in, drawn rather than loaded.
##
## THE FURNITURE WAS FLOATING. A rack against one wall and a till against the
## other, on a flat panel with a hole between them -- two objects and no place.
## Everything here exists to put a floor under them and something behind them,
## which is the same job `YardScene` does for the berth and the same reason: a
## deck the player believes is somewhere is a deck they will come back to.
##
## A PLACEHOLDER THAT IS ALSO THE FALLBACK, exactly as the berth is. The layout
## is the part worth settling with rectangles -- where the floor line sits, how
## much wall is left above a 335-pixel rack, whether a window can be read behind
## two pieces of furniture -- and every answer is a constraint the art has to
## meet. If a generated plate never lands, this is what the shop looks like.
##
## THE WINDOW IS THE POINT. A station interior with no way out is a corridor; one
## long viewport over the shop says the promenade is a deck on something that is
## in space, and it costs one rectangle and forty stars. It sits ABOVE both
## pieces of furniture rather than behind them, because a window you cannot see
## is a dark rectangle.

## How built-up this station is, from `MapGen.Development`. Same ladder the berth
## uses: fewer lamps and rougher plating at an outpost, a machined hall at a
## capital. It is the axis that already sets prices and stock, so the picture is
## saying something true rather than decorating.
var dev: int = MapGen.Development.CITY
## Whoever holds the station. Tints the plating and nothing else.
var manufacturer: StringName = &""

## THE STATION'S OWN PALETTE, and deliberately the berth's numbers.
##
## `YardScene`'s header records why they are darker than they look like they
## should be: a mid-grey room puts mid-grey objects against mid-grey and every
## silhouette goes soft. The shop has the same problem with a rack full of parts,
## so it gets the same answer -- and the two decks reading as one station is
## worth more than either of them reading well alone.
const WALL := Color("#0d141d")
const PLATE := Color("#151e2a")
const EDGE := Color("#202d3d")
const DEEP := Color("#080c12")
const LAMP := Color("#d97b29")
const FLOOR := Color("#121a24")
const FLOOR_LINE := Color("#1c2836")
const STAR := Color("#c3d2e2")
## A crate on the floor, and the lit edge that makes it a box rather than a
## swatch. The same pair the counter stacks behind itself.
const CRATE := Color("#1e2836")
const CRATE_LIP := Color("#33445c")

## How deep the floor band is, measured up from the bottom.
##
## The rack's plinth and the till's kickboard both sit on the bottom edge of this
## control, so this is the strip of deck VISIBLE either side of them and in the
## gap between. Deep enough to read as floor rather than as a line.
const FLOOR_H := 78.0
## The long window over the shop: how far down it starts and how tall it is.
## Above the rack's 335, which is what makes it visible at all.
const SKY_Y := 16.0
const SKY_H := 52.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## How many lamps hang over this shop. One at an outpost, six at a capital.
func _lamps() -> int:
	match dev:
		MapGen.Development.OUTPOST: return 2
		MapGen.Development.SETTLEMENT: return 3
		MapGen.Development.CAPITAL: return 6
		_: return 4


## The plating, pigment-shifted toward whoever holds the station.
##
## ON THE TRIM, NOT ON THE WALLS -- which is the whole finding here.
##
## A lerp moves each channel by a fraction of ITS OWN GAP, and out of a colour
## this dark the gaps are wildly uneven: Solari's #ed9b22 against #0d141d is 224
## of red and 5 of blue. Any weight at all therefore does not tint the room, it
## DESATURATES it -- at 0.12 the wall came out #2f2d29 and at 0.06 #1a1c1d, both
## of them neutral warm greys where the station is meant to be cold blue. The
## room stopped looking like this game.
##
## So the big surfaces keep the station's own colour and the livery goes on the
## EDGES: joints, studs, conduit, window frame, floor courses. That is also how a
## livery actually works -- nobody repaints a hull, they paint the trim -- and it
## survives at full strength, because a 2px line can afford to be orange.
func _tint(c: Color) -> Color:
	var m: ManufacturerData = DB.manufacturers.get(manufacturer)
	return c if m == null else c.lerp(m.colour, 0.18)


## A repeatable scatter. Stars have to land in the same place every redraw or the
## window twinkles every time the pointer moves, and GDScript's RNG is a stream
## rather than a function of position.
func _scatter(i: int, span: float) -> float:
	return fmod(float(i) * 2654435761.0 / 65536.0, span)


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 60.0 or h <= 120.0:
		return
	var floor_y := h - FLOOR_H
	# THE WALL IS THE DARKEST THING IN THE ROOM, and it has to be.
	#
	# It was `PLATE` for one pass, which is the colour of the FURNITURE -- so the
	# rack and the till, both built from plate tones, read as dark holes cut in a
	# lighter wall. Everything standing in a room has to out-read the room; this
	# is `YardScene`'s "darker than it looks like it should be" arriving at the
	# same answer from the opposite direction. Untinted, for the reason `_tint`
	# gives at length.
	var wall := WALL

	# --- THE BACK WALL, and the deck it stands on.
	draw_rect(Rect2(0.0, 0.0, w, floor_y), wall)
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

	# --- THE WINDOW, and space through it.
	#
	# ONE LONG LETTERBOX rather than a row of portholes: the shop is on the
	# OUTSIDE of something, and a continuous view is what says the deck curves
	# away rather than that somebody drilled three holes.
	var sky := Rect2(26.0, SKY_Y, w - 52.0, SKY_H)
	if sky.size.x > 80.0 and sky.end.y < floor_y - 40.0:
		draw_rect(sky, DEEP)
		# Stars. Fixed positions, three brightnesses, and none of them on the
		# frame -- a star touching the mullion looks like a dead pixel.
		for i in 46:
			var sx := sky.position.x + 3.0 + _scatter(i * 7 + 1, sky.size.x - 6.0)
			var sy := sky.position.y + 3.0 + _scatter(i * 13 + 5, sky.size.y - 6.0)
			var mag := 0.25 + 0.75 * (float(i % 5) / 4.0)
			draw_rect(Rect2(floorf(sx), floorf(sy), 1.0, 1.0),
				Color(STAR.r, STAR.g, STAR.b, mag))
		# The station's own hull, curving away below the window. It is the one
		# mark that says you are ON something rather than looking at a poster.
		var arc := 0.0
		while arc < sky.size.x:
			var bow := sky.size.y * 0.30 * sin(PI * arc / sky.size.x)
			draw_rect(Rect2(sky.position.x + arc, sky.end.y - bow, 2.0, bow),
				Color(EDGE.r, EDGE.g, EDGE.b, 0.75))
			arc += 2.0
		# The frame: a lit sill along the bottom, dark head above, mullions down.
		draw_rect(sky, _tint(EDGE), false, 2.0)
		draw_rect(Rect2(sky.position.x, sky.end.y - 1.0, sky.size.x, 3.0),
			Color(LAMP.r, LAMP.g, LAMP.b, 0.22))
		var mx := sky.position.x + 116.0
		while mx < sky.end.x - 20.0:
			draw_rect(Rect2(mx, sky.position.y, 3.0, sky.size.y), _tint(PLATE))
			draw_rect(Rect2(mx, sky.position.y, 1.0, sky.size.y),
				Color(EDGE.r, EDGE.g, EDGE.b, 0.6))
			mx += 116.0

	# --- CONDUIT along the wall under the window, because a station is plumbing
	# with rooms in it and one pipe says so faster than any amount of panelling.
	var pipe := sky.end.y + 13.0
	if pipe < floor_y - 30.0:
		draw_rect(Rect2(0.0, pipe, w, 3.0), _tint(EDGE))
		draw_rect(Rect2(0.0, pipe, w, 1.0), Color(STAR.r, STAR.g, STAR.b, 0.10))
		var bx := 34.0
		while bx < w - 10.0:
			# The brackets holding it off the wall.
			draw_rect(Rect2(bx, pipe - 2.0, 4.0, 7.0), _tint(PLATE))
			bx += 78.0

	# --- THE LAMPS, hung on stems from the ceiling.
	#
	# THE LIGHT LANDS ON THE FLOOR. A lamp that glows and lights nothing is a
	# sticker; the pool underneath is the half that makes the room have a source.
	var n := _lamps()
	for i in n:
		var lx := w * (float(i) + 0.5) / float(n)
		draw_rect(Rect2(lx - 1.0, 0.0, 2.0, 9.0), _tint(EDGE))
		draw_rect(Rect2(lx - 7.0, 9.0, 14.0, 4.0), _tint(EDGE))
		draw_rect(Rect2(lx - 5.0, 12.0, 10.0, 2.0), Color(LAMP.r, LAMP.g, LAMP.b, 0.85))

	# --- THE FLOOR.
	#
	# BEFORE THE LIGHT THAT FALLS ON IT. The pools were drawn with the lamps and
	# the floor went down on top of them, so four lamps lit a room that stayed
	# uniformly dark -- painted over by the surface they were lighting.
	draw_rect(Rect2(0.0, floor_y, w, FLOOR_H), FLOOR)
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

	# --- STOCK WAITING TO GO OUT, on a pallet in the aisle.
	#
	# IN THE MIDDLE, WHICH IS WHERE THE AISLE IS. This does not know where the
	# rack and the till are and does not need to: the rack stands against the left
	# wall and the counter against the right, so the centre of the room is the
	# floor between them by construction. It is the one thing here that says the
	# shop is WORKING rather than staged -- a delivery nobody has put away.
	var cx0 := w * 0.5
	var base := h - 12.0
	if base > floor_y + 24.0:
		# The pallet: two bearers and a deck, seen almost edge-on.
		draw_rect(Rect2(cx0 - 34.0, base, 68.0, 5.0), _tint(EDGE))
		draw_rect(Rect2(cx0 - 34.0, base, 68.0, 1.0), CRATE_LIP)
		draw_rect(Rect2(cx0 - 30.0, base + 5.0, 5.0, 4.0), DEEP)
		draw_rect(Rect2(cx0 + 25.0, base + 5.0, 5.0, 4.0), DEEP)
		# And what is on it. Lighter than the floor, because a thing standing on a
		# surface has to out-read the surface -- the rule this room has now been
		# taught three times.
		for c in [Rect2(cx0 - 30.0, base - 26.0, 28.0, 26.0),
				Rect2(cx0 - 1.0, base - 19.0, 24.0, 19.0),
				Rect2(cx0 - 24.0, base - 44.0, 20.0, 18.0)]:
			var r: Rect2 = c
			if r.position.y < floor_y - 30.0:
				continue
			draw_rect(r, CRATE)
			draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1.0), CRATE_LIP)
			draw_rect(Rect2(r.position.x, r.position.y, 1.0, r.size.y),
				Color(CRATE_LIP.r, CRATE_LIP.g, CRATE_LIP.b, 0.45))
			draw_rect(Rect2(r.position.x, r.position.y + r.size.y * 0.42,
				r.size.x, 2.0), Color(DEEP.r, DEEP.g, DEEP.b, 0.55))

	# --- AND THE LIGHT THE LAMPS PUT ON IT, last of all so the plating shows
	# THROUGH it. A pool is light on a floor, not a shape lying on one, which is
	# the difference between a lit room and a room with ovals painted in it.
	for i in n:
		var px := w * (float(i) + 0.5) / float(n)
		var step := 0
		while step < 6:
			var spread := 16.0 + float(step) * 14.0
			draw_rect(Rect2(px - spread, floor_y + float(step) * 13.0,
				spread * 2.0, 13.0),
				Color(LAMP.r, LAMP.g, LAMP.b, 0.075 - 0.011 * float(step)))
			step += 1
