class_name YardScene
extends Control

## The berth the ship for sale is standing in, drawn rather than loaded.
##
## A PLACEHOLDER THAT IS ALSO THE FALLBACK. The plan is a generated plate behind
## this panel, and the plan is not the thing to find the layout with: how tall
## the gantry sits, where the cradle puts the hull, whether a details slab can
## live over the top right, and how dark the middle has to be for a mid-grey
## ship to read on it -- all of that is answerable with rectangles, and every
## one of those answers is a constraint the art has to meet. Settling them here
## means the prompt describes a composition we have already checked instead of
## one we are hoping for.
##
## It follows the same rule `ShipView` does: sprite when there is one, drawn when
## there is not. If the art never lands this is what the Yard looks like, and
## that is a deliberately survivable outcome rather than a hole.
##
## EVERY BERTH IS AN INTERIOR, and not only because it looks better. An open
## drydock puts a STARFIELD BEHIND THE SHIP -- and the hull is a mid-grey
## silhouette full of internal detail, against high-contrast points scattered
## over exactly the area it occupies. A back wall is a ground you can read a ship
## against; a floor is what makes it look parked rather than adrift. Space still
## gets in, through one window, which is a cue and not a texture.

## How built-up this berth is, from `MapGen.Development`. The ladder is the same
## composition made better or worse: rock and one lamp at an outpost, a machined
## hall with six at a capital. It is the axis that already sets prices and stock,
## so the picture is saying something true rather than decorating.
var dev: int = MapGen.Development.CITY
## Whoever holds the berth. Tints the plating the way `ShipView` tints a hull --
## a pigment shift, never a light, and never on the lamps themselves.
var manufacturer: StringName = &""

## THE WALL IS DARKER THAN IT LOOKS IT SHOULD BE, on purpose.
##
## The first pass used #141c26 and the hangar came out as a mid-grey room with a
## mid-grey ship in it -- the hull stopped being the brightest thing in frame and
## the silhouette went soft. These are the values that put a lit ship against a
## dark room rather than two greys against each other, and every one of them is
## a number the generated plate will have to hit as well.
const WALL := Color("#0d141d")
const PLATE := Color("#151e2a")
const EDGE := Color("#202d3d")
const DEEP := Color("#080c12")
const LAMP := Color("#d97b29")

## How deep the service bay across the front of the hangar is.
##
## THE RIGS STAND IN IT AND THE SHIP DOES NOT. The berth's cradle is pushed back
## by exactly this much -- see `cradle_y` -- so a fuel bowser is never parked in
## front of the hull somebody is deciding whether to buy. It is also why the
## services stopped being a table above the picture: a yard's machines belong on
## a yard's floor, and there was no floor for them to stand on until there was a
## bay.
const BAY_H := 104.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## How many work lights this berth runs to. One at an outpost, six at a capital.
func _lamps() -> int:
	match dev:
		MapGen.Development.OUTPOST: return 1
		MapGen.Development.SETTLEMENT: return 2
		MapGen.Development.CAPITAL: return 6
		_: return 4


## The plating, pigment-shifted toward whoever holds the station.
##
## 0.12, the same weight `ShipView` uses on a hull, and kept OFF the lamps for
## the same reason: paint is a property of the object and light is not. A Solari
## yard and a Cygnet yard are the same hangar in two liveries.
func _tint(c: Color) -> Color:
	var m: ManufacturerData = DB.manufacturers.get(manufacturer)
	return c if m == null else c.lerp(m.colour, 0.12)


## How thick the deck band along the bottom is. One answer, because `_draw`,
## `cradle_y` and `deck_y` all need it, and three copies of it is how a ship ends
## up standing four pixels under its own cradle.
func _floor_h() -> float:
	if dev <= MapGen.Development.OUTPOST:
		return 10.0
	return 20.0 if dev >= MapGen.Development.CAPITAL else 15.0


## The line the service rigs stand on -- the back edge of the front bay, which is
## also where the cradle's posts come down.
func deck_y() -> float:
	return size.y - _floor_h() - BAY_H


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 4.0 or h <= 4.0:
		return
	var rough: bool = dev <= MapGen.Development.OUTPOST
	var wall := _tint(WALL)
	var plate := _tint(PLATE)
	var edge := _tint(EDGE)

	# --- THE BACK WALL, and it is the darkest thing in frame across the middle.
	# The ship sits centre-left and is the brightest object; everything behind it
	# is graded down toward the centre so the silhouette has somewhere to read.
	draw_rect(Rect2(0.0, 0.0, w, h), DEEP)
	draw_rect(Rect2(0.0, 0.0, w, h), wall)
	# DARKEST WHERE THE SHIP GOES. Not a vignette for its own sake: the hull is
	# placed centre-left and low, so that is the rectangle that has to be black.
	var mid := Rect2(w * 0.02, h * 0.20, w * 0.96, h * 0.66)
	draw_rect(mid, DEEP.lerp(wall, 0.18))

	# Wall seams, further apart and rougher the poorer the berth.
	var seam := 26.0 if rough else 18.0
	var y := h * 0.20
	while y < h * 0.78:
		draw_rect(Rect2(w * 0.02, y, w * 0.96, 1.0), wall.lerp(edge, 0.22))
		y += seam

	# --- THE CEILING, and the gantry rail under it.
	var roof_h: float = 12.0 if rough else (22.0 if dev >= MapGen.Development.CAPITAL else 17.0)
	draw_rect(Rect2(0.0, 0.0, w, roof_h), plate)
	draw_rect(Rect2(0.0, roof_h, w, 2.0), edge)
	if not rough:
		# A HEAVY RAIL, because a hangar with a roof has something running along
		# it. The outpost has no rail: what it has is scaffolding, below.
		draw_rect(Rect2(0.0, roof_h + 5.0, w, 4.0), plate)
		draw_rect(Rect2(0.0, roof_h + 5.0, w, 1.0), edge)
		# The hoist trolley, parked off to one side rather than over the berth.
		draw_rect(Rect2(w * 0.78, roof_h + 3.0, 26.0, 9.0), plate)
		draw_rect(Rect2(w * 0.78, roof_h + 3.0, 26.0, 1.0), edge)

	# --- THE COLUMNS. Two at an outpost, four at a capital, and they are what
	# the lamps are bolted to.
	var cols: Array[float] = [0.07, 0.90]
	if dev >= MapGen.Development.CITY:
		cols = [0.05, 0.30, 0.72, 0.93]
	var col_w: float = 5.0 if rough else 7.0
	for cx in cols:
		var x := w * cx
		draw_rect(Rect2(x, roof_h, col_w, h - roof_h), plate)
		draw_rect(Rect2(x, roof_h, 1.0, h - roof_h), edge)

	# --- THE LAMPS, and they are the only warm thing in the picture.
	#
	# The game allows exactly one source of warmth in frame and it is normally
	# the reactor. Here it is the yard's own lights, which is what keeps the ship
	# cold metal standing in somebody else's light rather than glowing on its own.
	var lamps := _lamps()
	for i in lamps:
		var cx: float = cols[i % cols.size()]
		var lx := w * cx + col_w * 0.5
		var ly := h * (0.34 + 0.16 * float(i / cols.size()))
		draw_rect(Rect2(lx - 4.0, ly, 8.0, 3.0), LAMP)
		# The spill, as three widening bands rather than a gradient: a blur is
		# not a thing this renderer does and a hard falloff is what pixel art
		# reads as light anyway.
		for step in 3:
			var a := 0.16 - 0.05 * float(step)
			var sw := 10.0 + 12.0 * float(step + 1)
			draw_rect(Rect2(lx - sw * 0.5, ly + 3.0 + 4.0 * float(step),
				sw, 4.0), Color(LAMP.r, LAMP.g, LAMP.b, a))

	# --- THE FLOOR AND THE CRADLE. The cradle is the thing the ship stands in,
	# so its top edge is where the hull's belly goes -- see `cradle_y`.
	var floor_h := _floor_h()
	var cy := deck_y()

	# --- THE FRONT BAY, between the cradle line and the deck edge.
	#
	# The floor the service rigs stand on. Lighter than the wall behind it, the
	# way every surface in this station has had to learn to be, and marked off
	# with a painted line because that is what a working bay has: a boundary you
	# do not park a ship over.
	draw_rect(Rect2(0.0, cy, w, h - cy), wall.lerp(plate, 0.55))
	draw_rect(Rect2(0.0, cy, w, 1.0), edge)
	if not rough:
		# Hazard paint along the back edge of the bay. Short dashes rather than a
		# solid rule: a painted line on a deck is worn, and the yard's own lamp
		# colour is already the one warm thing in the room.
		var hx := 8.0
		while hx < w - 8.0:
			draw_rect(Rect2(hx, cy + 3.0, 9.0, 2.0), Color(LAMP.r, LAMP.g, LAMP.b, 0.42))
			hx += 18.0
		# Bay plating, running the other way from the deck's so the two surfaces
		# read as two surfaces.
		var by := cy + 16.0
		while by < h - floor_h - 4.0:
			draw_rect(Rect2(0.0, by, w, 1.0), wall.lerp(edge, 0.45))
			by += 22.0

	# --- AND THE DECK EDGE ITSELF, seen almost end-on at the very bottom.
	draw_rect(Rect2(0.0, h - floor_h, w, floor_h), plate)
	draw_rect(Rect2(0.0, h - floor_h, w, 1.0), edge)
	if not rough:
		# Deck plating, drawn as seams so the floor has a scale to it.
		var fx := 0.0
		while fx < w:
			draw_rect(Rect2(fx, h - floor_h, 1.0, floor_h), wall.lerp(edge, 0.5))
			fx += 34.0
	# TALLER THAN THE HULL COVERS. The first version was a seven-pixel plinth
	# with the ship standing straight on it, so the hull hid all of it and the
	# ship read as parked on the floor rather than held in a cradle. The arms now
	# rise past the belly, and `cradle_y` lifts the ship clear of the deck.
	# ONE PER BERTH. Two cradles rather than one long plinth, because two ships
	# standing on a single slab read as cargo on a shelf; two cradles read as two
	# berths, which is what the deck is.
	for b: float in [BERTH_MINE, BERTH_SALE]:
		var left := w * (b - BERTH_HALF)
		var span := w * BERTH_HALF * 2.0
		draw_rect(Rect2(left, cy - 9.0, span, 9.0), plate)
		draw_rect(Rect2(left, cy - 9.0, span, 1.0), edge)
		for off: float in [0.04, 0.15]:
			for arm: float in [b - BERTH_HALF + off, b + BERTH_HALF - off]:
				draw_rect(Rect2(w * arm, cy - 34.0, 6.0, 34.0), plate)
				draw_rect(Rect2(w * arm, cy - 34.0, 1.0, 34.0), edge)
				# The pad the hull actually rests on, one shade up so it reads as
				# a separate part rather than as the top of the post.
				draw_rect(Rect2(w * arm - 3.0, cy - 36.0, 12.0, 3.0), edge)

	# --- ONE WINDOW, high on the right, and it is the whole of the space cue.
	#
	# A wall of stars would be a texture across the only area the ship occupies.
	# A single port says the same thing about where you are and stays out of the
	# way. Far LEFT and high, because the details slab lands top right and the
	# one bright thing in the room must not spend its life underneath it.
	# BETWEEN THE TWO BERTHS. It was far left and high, which was out of the way
	# of one ship; with a hull standing in both, the gap down the middle is the
	# only piece of wall nothing is parked against.
	var win := Rect2(w * 0.5 - 20.0, roof_h + 14.0, 40.0, 28.0)
	draw_rect(win, DEEP)
	draw_rect(win, edge, false, 1.0)
	for s in [Vector2(0.22, 0.30), Vector2(0.61, 0.18), Vector2(0.44, 0.66),
			Vector2(0.78, 0.52)]:
		draw_rect(Rect2(win.position.x + win.size.x * s.x,
			win.position.y + win.size.y * s.y, 1.0, 1.0),
			Color(0.62, 0.70, 0.80, 0.75))

	# --- AND THE SCAFFOLDING, at the poor end only. An outpost has no gantry; it
	# has poles somebody welded across the mouth of a hole.
	if rough:
		draw_rect(Rect2(w * 0.07, h * 0.36, w * 0.78, 3.0), plate)
		draw_rect(Rect2(w * 0.24, h * 0.36, 4.0, h * 0.22), plate)
		draw_rect(Rect2(w * 0.55, h * 0.36, 4.0, h * 0.16), plate)


## Where the cradle's top edge is, in this control's own coordinates.
##
## The screen stands the ship on it rather than centring it in the panel: a hull
## floating at the vertical middle of a room with a floor in it looks like it is
## hovering, and the whole reason to draw a berth is that the ship is IN one.
func cradle_y() -> float:
	# The PADS, not the plinth: 36 up from the cradle line is where the posts
	# end and the hull begins, so a ship standing here has daylight under it.
	# Off `deck_y` rather than off the bottom of the control, because the front
	# bay takes the near hundred pixels now and the berth sits behind it.
	return deck_y() - 36.0


## TWO BERTHS, AND WHICH IS WHICH IS THE WHOLE POINT.
##
## The yard used to draw one cradle with the ship for sale standing in it, and
## your own ship -- the thing you are trading in, the reason there is a part
## exchange at all -- appeared nowhere on the deck. It was a number in a
## sentence: "less 25 for your Emberwright". Both ships stand in the hangar now,
## yours on the LEFT wearing everything you have bolted to it and the offer on
## the RIGHT wearing nothing, which is the deal drawn rather than described.
##
## Fractions of the width, so the berths hold whatever the deck is.
const BERTH_MINE := 0.26
const BERTH_SALE := 0.74
## How far a cradle reaches either side of its berth's centre.
const BERTH_HALF := 0.21

## Where berth `i` is across, as a fraction. 0 is yours, 1 is the one for sale.
static func berth_x(i: int) -> float:
	return BERTH_SALE if i == 1 else BERTH_MINE


## Where the station's banners hang in the hangar: under the gantry rail, a set
## either side of the window, over both berths.
func banner_spots() -> Array:
	return [Vector2(0.40, 30.0), Vector2(0.60, 30.0)]
