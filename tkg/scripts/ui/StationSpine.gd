class_name StationSpine
extends Control

## The station in section, five floors of it, drawn behind the deck rail.
##
## THE RAIL WAS FIVE BUTTONS AND IT IS A BUILDING NOW. A tab strip tells you
## which page you are on; a cutaway tells you where you are STANDING. They cost
## the same vertical, and only one of them makes the station a place -- so the
## decks are floors of one structure, stacked in the order you walk them, and
## the one you are on is the one with its lights on.
##
## EVERY FLOOR IS AN INTERIOR. That is the whole conceit: you are inside this
## thing. Nothing here is drawn from outside, there is no starfield, and the
## hull walls run down both edges of every floor to say so.
##
## Drawn rather than loaded, for the same reason `YardScene` is: it is the
## placeholder AND the fallback, and settling the composition in rectangles is
## what lets a prompt describe a picture we have already checked. If art lands it
## replaces the body of `_draw`; if it never does, this is the rail.

## Which floors are showing, top to bottom -- outposts do not have every deck, so
## this is not always five. Ids from `StationScreen.DECKS`.
var floors: Array[StringName] = []
## Which of them you are standing on. -1 lights none.
var active: int = -1
## WHERE THE CAR IS, as a floor number that need not be a whole one.
##
## THE LIGHT TRAVELS, AND THAT IS THE WHOLE ELEVATOR. `active` says which floor
## you have chosen; this says where the car has actually got to on its way
## there. At 2.4 it is between the third and fourth rooms, and both of them are
## partly lit -- so a floor brightens as the car arrives and dims as it leaves,
## which is what makes it read as something moving through a building rather
## than as a highlight teleporting between rows.
var car: float = -1.0
## Whoever holds the station, for the pigment shift. Same weight as the berth.
var manufacturer: StringName = &""
## How far the far wall of each room is offset, in pixels.
##
## THE BACK OF A ROOM IS FURTHER AWAY, so it is drawn inset. This used to be
## driven by the building sliding in its shaft; the building does not slide any
## more -- the CAR does -- so it is a fixed inset now and the depth comes from
## the light moving across rooms that have a behind.
var parallax: float = 0.0

const WALL := Color("#0d141d")
const PLATE := Color("#151e2a")
const EDGE := Color("#202d3d")
const DEEP := Color("#080c12")
const LAMP := Color("#d97b29")
## How thick the station's outer hull is, down both edges of every floor.
const HULL_W := 6.0
## The deck plate between one floor and the next.
const DECK_T := 3.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _tint(c: Color) -> Color:
	var m: ManufacturerData = DB.manufacturers.get(manufacturer)
	return c if m == null else c.lerp(m.colour, 0.12)


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 8.0 or h <= 8.0 or floors.is_empty():
		return
	var wall := _tint(WALL)
	var plate := _tint(PLATE)
	var edge := _tint(EDGE)
	var fh := h / float(floors.size())

	draw_rect(Rect2(0.0, 0.0, w, h), DEEP)
	for i in floors.size():
		var top := fh * float(i)
		# HOW LIT, NOT WHETHER. One when the car is on this floor, nothing when it
		# is a floor away, and the ramp between is the car passing.
		var glow: float = 0.0
		if car >= 0.0:
			glow = clampf(1.0 - absf(car - float(i)), 0.0, 1.0)
		var lit: bool = glow > 0.45
		var room := Rect2(HULL_W, top, w - HULL_W * 2.0, fh - DECK_T)

		# THE ROOM YOU ARE IN IS THE LIT ONE, and it is lit rather than merely
		# brighter: a warm floor among cold ones reads as somewhere with people
		# in it, where a grey one lifted ten percent reads as a selected button.
		draw_rect(room, wall.lerp(LAMP, 0.10 * glow))
		# THE BACK OF THE ROOM, inset and lagging. Inset because a wall further
		# away subtends less; lagging because that is what further away DOES when
		# you move past it.
		var back := Rect2(room.position.x + 7.0,
			room.position.y + 4.0 - parallax * 0.33,
			room.size.x - 14.0, room.size.y - 8.0)
		draw_rect(back, DEEP.lerp(wall, 0.45))
		var sy := back.position.y + 5.0
		while sy < back.end.y - 2.0:
			draw_rect(Rect2(back.position.x, sy, back.size.x, 1.0),
				wall.lerp(edge, 0.30))
			sy += 9.0
		if glow > 0.02:
			# The spill from that floor's own lamps, banded down from the ceiling
			# because that is where they hang. Scaled by `glow`, so the light
			# comes UP as the car arrives instead of snapping on.
			for step in 3:
				draw_rect(Rect2(room.position.x, room.position.y + 3.0 * float(step),
					room.size.x, 3.0),
					Color(LAMP.r, LAMP.g, LAMP.b,
						(0.09 - 0.025 * float(step)) * glow))
		# THE FURNITURE IS DRAWN BRIGHTER THAN THE ROOM IT IS IN, and the first
		# pass was not. Everything in here was `plate` on `wall` -- #151e2a on
		# #0d141d -- which is eight levels of difference at 156 pixels wide, and
		# eight levels of difference is nothing. The walls stay dark because the
		# ship on the Yard has to read against them; what is IN a room has no
		# such duty and has to be legible at a glance from a rail.
		var furn := plate.lerp(EDGE, 1.4).lerp(LAMP, 0.16 * glow)
		var line := EDGE.lerp(Color("#5c718c"), 0.55).lerp(LAMP, 0.20 * glow)
		_furnish(floors[i], room, furn, line, lit)

		# The deck plate under it. Drawn last so nothing in the room sits on top
		# of the floor it is standing on.
		draw_rect(Rect2(0.0, top + fh - DECK_T, w, DECK_T), plate)
		draw_rect(Rect2(0.0, top + fh - DECK_T, w, 1.0), edge)

	# --- THE CAR. A lit frame the height of one floor, at wherever it has got to.
	#
	# Drawn as a FRAME rather than a fill: a filled box would hide the room it is
	# standing in, and the room is the thing you came to look at. Four edges and a
	# brighter left post, because the post is the side the labels are on and it is
	# what makes the selection read from across the screen.
	if car >= 0.0:
		var cy := fh * car
		var cr := Rect2(0.0, cy, w, fh - DECK_T)
		draw_rect(Rect2(cr.position.x, cr.position.y, cr.size.x, 2.0), LAMP)
		draw_rect(Rect2(cr.position.x, cr.end.y - 2.0, cr.size.x, 2.0), LAMP)
		draw_rect(Rect2(cr.position.x, cr.position.y, 3.0, cr.size.y), LAMP)
		draw_rect(Rect2(cr.end.x - 2.0, cr.position.y, 2.0, cr.size.y),
			Color(LAMP.r, LAMP.g, LAMP.b, 0.55))

	# --- A SHADOW DOWN THE LEFT, UNDER THE LABELS.
	#
	# The deck names sit over this drawing and nine-pixel type on a lit stall is
	# not type you can read. So the near side of every room is in shade -- which
	# is also what a room lit from the far wall would actually look like, so the
	# thing that makes the words legible is the same thing that gives the section
	# its light direction. Banded rather than smooth: a gradient is not a move
	# this renderer makes, and hard steps are what pixel art uses for falloff.
	for band in 5:
		var bw := 78.0 - 13.0 * float(band)
		draw_rect(Rect2(HULL_W, 0.0, bw, h),
			Color(DEEP.r, DEEP.g, DEEP.b, 0.30))

	# --- THE OUTER HULL, down both sides and over everything. It is what makes
	# five rooms one station rather than five pictures in a column.
	draw_rect(Rect2(0.0, 0.0, HULL_W, h), plate)
	draw_rect(Rect2(w - HULL_W, 0.0, HULL_W, h), plate)
	draw_rect(Rect2(HULL_W - 1.0, 0.0, 1.0, h), edge)
	draw_rect(Rect2(w - HULL_W, 0.0, 1.0, h), edge)
	# Ribs, so the hull has a scale and is not two grey bars.
	var y := 8.0
	while y < h:
		draw_rect(Rect2(0.0, y, HULL_W, 1.0), edge)
		draw_rect(Rect2(w - HULL_W, y, HULL_W, 1.0), edge)
		y += 19.0


## What is IN each room. One clause per deck, and each is the smallest set of
## shapes that could only be that place.
func _furnish(id: StringName, r: Rect2, plate: Color, edge: Color,
		lit: bool) -> void:
	var x := r.position.x
	var y := r.position.y
	var w := r.size.x
	var h := r.size.y
	var floor_y := y + h
	var warm := LAMP if lit else LAMP.lerp(WALL, 0.55)

	match id:
		&"stock":
			# THE PROMENADE: stalls under awnings, and goods hung off them. The
			# awning is the shape that says market at eight pixels.
			for i in 3:
				var sx := x + w * (0.14 + 0.26 * float(i))
				draw_rect(Rect2(sx, y + h * 0.34, w * 0.19, 3.0), plate)
				draw_rect(Rect2(sx, y + h * 0.34, w * 0.19, 1.0), edge)
				draw_rect(Rect2(sx + 2.0, floor_y - h * 0.30, 3.0, h * 0.30), plate)
				draw_rect(Rect2(sx + w * 0.14, floor_y - h * 0.22, 3.0, h * 0.22), plate)
			draw_rect(Rect2(x + w * 0.20, y + h * 0.42, 2.0, 5.0), warm)
			draw_rect(Rect2(x + w * 0.72, y + h * 0.42, 2.0, 5.0), warm)
		&"services":
			# THE YARD: a gantry, and the only hull in the building.
			draw_rect(Rect2(x + w * 0.08, y + h * 0.26, w * 0.84, 3.0), plate)
			draw_rect(Rect2(x + w * 0.08, y + h * 0.26, w * 0.84, 1.0), edge)
			draw_rect(Rect2(x + w * 0.22, y + h * 0.29, 3.0, h * 0.16), plate)
			var hull := Rect2(x + w * 0.20, floor_y - h * 0.40, w * 0.58, h * 0.24)
			draw_rect(hull, plate.lerp(edge, 0.55))
			draw_rect(hull, edge, false, 1.0)
			draw_rect(Rect2(hull.position.x + hull.size.x * 0.46, hull.position.y,
				3.0, hull.size.y), warm)
			# The cradle under it, two posts and a rail.
			draw_rect(Rect2(x + w * 0.18, floor_y - 5.0, w * 0.62, 3.0), plate)
			for a in [0.24, 0.66]:
				draw_rect(Rect2(x + w * a, floor_y - h * 0.16, 3.0, h * 0.16), plate)
		&"hold":
			# THE EXCHANGE: stacked crates, uneven, because a hold that is packed
			# neatly is a hold nobody uses.
			var stack := [[0.16, 0.30, 0.20], [0.40, 0.20, 0.34],
				[0.58, 0.26, 0.16], [0.76, 0.16, 0.26]]
			for c in stack:
				var cw := w * float(c[1])
				var ch := h * float(c[2])
				var cx := x + w * float(c[0])
				draw_rect(Rect2(cx, floor_y - ch - 2.0, cw, ch), plate)
				draw_rect(Rect2(cx, floor_y - ch - 2.0, cw, ch), edge, false, 1.0)
				draw_rect(Rect2(cx + 2.0, floor_y - ch, cw - 4.0, 1.0), edge)
		&"work":
			# THE HIRING HALL: a lit board with postings on it, and a bench.
			var board := Rect2(x + w * 0.16, y + h * 0.24, w * 0.44, h * 0.40)
			draw_rect(board, plate)
			draw_rect(board, edge, false, 1.0)
			for i in 3:
				draw_rect(Rect2(board.position.x + 4.0,
					board.position.y + 5.0 + 6.0 * float(i),
					board.size.x * (0.72 - 0.16 * float(i)), 2.0), warm)
			draw_rect(Rect2(x + w * 0.66, floor_y - h * 0.20, w * 0.20, 3.0), plate)
			draw_rect(Rect2(x + w * 0.68, floor_y - h * 0.18, 2.0, h * 0.18), plate)
			draw_rect(Rect2(x + w * 0.82, floor_y - h * 0.18, 2.0, h * 0.18), plate)
		&"bench":
			# THE LABORATORY: culture tanks, and exactly one of them alive. The
			# single warm tank is the whole reason this floor is not the Exchange.
			for i in 3:
				var tw := w * 0.13
				var th := h * (0.44 - 0.06 * float(i))
				var tx := x + w * (0.18 + 0.24 * float(i))
				var tank := Rect2(tx, floor_y - th - 3.0, tw, th)
				draw_rect(tank, plate)
				draw_rect(tank, edge, false, 1.0)
				if i == 1:
					draw_rect(Rect2(tank.position.x + 2.0, tank.position.y + 3.0,
						tank.size.x - 4.0, tank.size.y - 6.0),
						Color(warm.r, warm.g, warm.b, 0.55 if lit else 0.28))
			draw_rect(Rect2(x + w * 0.16, y + h * 0.22, w * 0.62, 2.0), plate)
