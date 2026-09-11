class_name ExchangeScene
extends StationRoom

## The Exchange: a loading dock. Your hold stands on it in its own cargo cage,
## under the crane that set it down, and the market's counter is across the floor.
##
## THE HOLD WAS A GRID IN A PANEL NEXT TO A ROOM. The counter had a place to
## stand in and the thing you were selling FROM did not -- a 5x4 of cells with a
## caption over it, floating at the top of its column like a form field. It is
## the most physical object on the whole deck: the actual contents of your ship,
## at the size they take up in it. So it gets a physical form. A cage has a
## frame, a plate with its name stencilled on it, a skid it stands on and a
## crane hook it hangs from, and the grid is simply what is inside the cage.
##
## THE CAGE NEVER COVERS A CELL. It is drawn AROUND the grid, off the grid's own
## rect, and the screen pads the grid by exactly `CAGE_SIDE`, `CAGE_TOP` and
## `CAGE_FOOT` so there is always room for it. The grid still takes every drop
## and every hover; nothing here is in the pointer's way.

## What is printed on the cage's plate -- the hold's name and how full it is.
var hold_label: String = ""

## The hold's grid, whose rect the cage is drawn round. Read every redraw rather
## than cached, because the grid moves whenever the hull it belongs to changes.
var _grid: Control = null

## How much frame the cage puts round the grid. The screen pads the grid by
## these, so the frame can never be drawn over a cell.
const CAGE_SIDE := 10.0
const CAGE_TOP := 24.0
const CAGE_FOOT := 13.0

## The cage's steel. LIGHTER than the wall and the floor behind it -- the rule
## every surface in this station has had to learn -- and a shade warmer than the
## counter's, so the two pieces of furniture read as two objects.
const CAGE := Color("#27364b")
const CAGE_LIT := Color("#3e5472")
const PLATE_INK := Color("#c3d2e2")


func watch_hold(grid: Control) -> void:
	_grid = grid
	# THE GRID AND ITS WRAPPER BOTH. Moving the wrapper does not change the
	# grid's own position inside it, so watching the grid alone would miss the
	# frame the page first lays itself out in and draw the cage somewhere else.
	for c: Control in [grid, grid.get_parent() as Control]:
		if c == null:
			continue
		if not c.item_rect_changed.is_connected(queue_redraw):
			c.item_rect_changed.connect(queue_redraw)


## Where the grid is, in this room's own coordinates. Empty when there is none.
func _hold_rect() -> Rect2:
	if _grid == null or not is_instance_valid(_grid) or not _grid.is_visible_in_tree():
		return Rect2()
	return Rect2(_grid.global_position - global_position, _grid.size)


func _dress_wall(w: float, _h: float, floor_y: float) -> void:
	# --- THE LOADING SHUTTER, in the middle of the back wall.
	#
	# The one feature that says DOCK rather than shop: a roll-up door raised a
	# third of the way, with the dark of the station beyond it. Between the cage
	# and the counter, which is the only stretch of wall neither stands against.
	var door := Rect2(w * 0.40, 40.0, w * 0.19, floor_y - 40.0)
	if door.size.x > 60.0 and door.size.y > 90.0:
		var post := 6.0
		# The posts, with hazard paint down their faces.
		for px in [door.position.x - post, door.end.x]:
			draw_rect(Rect2(px, door.position.y - 8.0, post, door.size.y + 8.0),
				_tint(EDGE))
			var hy := door.position.y + 2.0
			while hy < door.end.y - 6.0:
				draw_rect(Rect2(px + 1.0, hy, post - 2.0, 4.0),
					Color(LAMP.r, LAMP.g, LAMP.b, 0.40))
				hy += 10.0
		# The header box the shutter rolls into.
		draw_rect(Rect2(door.position.x - post, door.position.y - 8.0,
			door.size.x + post * 2.0, 10.0), _tint(PLATE))
		draw_rect(Rect2(door.position.x - post, door.position.y - 8.0,
			door.size.x + post * 2.0, 1.0), _tint(EDGE))
		# The slats, down to where the shutter stops.
		var raised := door.end.y - door.size.y * 0.34
		draw_rect(Rect2(door.position.x, door.position.y + 2.0, door.size.x,
			raised - door.position.y - 2.0), PLATE)
		var sy := door.position.y + 6.0
		while sy < raised - 2.0:
			draw_rect(Rect2(door.position.x, sy, door.size.x, 1.0), EDGE)
			draw_rect(Rect2(door.position.x, sy + 1.0, door.size.x, 1.0),
				Color(DEEP.r, DEEP.g, DEEP.b, 0.5))
			sy += 6.0
		draw_rect(Rect2(door.position.x, raised - 3.0, door.size.x, 3.0), _tint(EDGE))
		# And the gap under it: the corridor beyond, darker than anything here.
		draw_rect(Rect2(door.position.x, raised, door.size.x, door.end.y - raised), DEEP)
		draw_rect(Rect2(door.position.x + door.size.x * 0.35, door.end.y - 3.0,
			door.size.x * 0.3, 1.0), Color(LAMP.r, LAMP.g, LAMP.b, 0.18))

	# --- THE CRANE RAIL, across the top of the dock, and the hook over the cage.
	draw_rect(Rect2(0.0, 18.0, w, 5.0), _tint(PLATE))
	draw_rect(Rect2(0.0, 18.0, w, 1.0), _tint(EDGE))
	draw_rect(Rect2(0.0, 22.0, w, 1.0), Color(DEEP.r, DEEP.g, DEEP.b, 0.6))
	var r := _hold_rect()
	if r.size.x > 0.0:
		var top := r.position.y - CAGE_TOP
		var cx := r.position.x + r.size.x * 0.5
		if top > 40.0:
			# The trolley on the rail, and the cable to the cage's lifting eye.
			draw_rect(Rect2(cx - 11.0, 15.0, 22.0, 10.0), _tint(EDGE))
			draw_rect(Rect2(cx - 11.0, 15.0, 22.0, 1.0), CAGE_LIT)
			draw_rect(Rect2(cx - 1.0, 25.0, 2.0, top - 34.0), Color(EDGE.r, EDGE.g, EDGE.b, 0.9))
			draw_rect(Rect2(cx - 5.0, top - 10.0, 10.0, 4.0), CAGE_LIT)
			draw_rect(Rect2(cx - 2.0, top - 6.0, 4.0, 6.0), CAGE_LIT)


func _dress_floor(w: float, h: float, floor_y: float) -> void:
	var r := _hold_rect()
	if r.size.x <= 0.0:
		return
	var outer := Rect2(r.position.x - CAGE_SIDE, r.position.y - CAGE_TOP,
		r.size.x + CAGE_SIDE * 2.0, r.size.y + CAGE_TOP + CAGE_FOOT)

	# --- THE BAY IT IS PARKED IN, painted on the deck.
	#
	# A dashed box round the cage's footprint. It is what makes the hold PARKED
	# on the dock rather than pasted over it: somebody marked where cargo goes.
	var bay := Rect2(outer.position.x - 8.0, floor_y + 6.0,
		outer.size.x + 16.0, h - floor_y - 9.0)
	var paint := Color(LAMP.r, LAMP.g, LAMP.b, 0.30)
	var dx := bay.position.x
	while dx < bay.end.x:
		draw_rect(Rect2(dx, bay.position.y, 6.0, 1.0), paint)
		draw_rect(Rect2(dx, bay.end.y, 6.0, 1.0), paint)
		dx += 10.0
	var dy := bay.position.y
	while dy < bay.end.y:
		draw_rect(Rect2(bay.position.x, dy, 1.0, 5.0), paint)
		draw_rect(Rect2(bay.end.x, dy, 1.0, 5.0), paint)
		dy += 9.0

	# --- ITS SHADOW, down and right, on whatever is behind it.
	draw_rect(Rect2(outer.position.x + 4.0, outer.position.y + 4.0,
		outer.size.x, outer.size.y), Color(DEEP.r, DEEP.g, DEEP.b, 0.55))

	# --- THE FRAME: two posts, a plate across the top and a skid underneath.
	for px in [outer.position.x, r.end.x]:
		draw_rect(Rect2(px, outer.position.y, CAGE_SIDE, outer.size.y), CAGE)
		draw_rect(Rect2(px, outer.position.y, 1.0, outer.size.y), CAGE_LIT)
		draw_rect(Rect2(px + CAGE_SIDE - 1.0, outer.position.y, 1.0, outer.size.y),
			Color(DEEP.r, DEEP.g, DEEP.b, 0.7))
		# Rivets down each post, so it is steel and not a stripe.
		var ry := outer.position.y + CAGE_TOP + 5.0
		while ry < r.end.y - 2.0:
			draw_rect(Rect2(px + CAGE_SIDE * 0.5 - 1.0, ry, 2.0, 2.0), CAGE_LIT)
			ry += 14.0
	# The plate, and the lifting eye the crane's cable comes down to.
	draw_rect(Rect2(outer.position.x, outer.position.y, outer.size.x, CAGE_TOP), CAGE)
	draw_rect(Rect2(outer.position.x, outer.position.y, outer.size.x, 1.0), CAGE_LIT)
	draw_rect(Rect2(outer.position.x, outer.position.y + CAGE_TOP - 1.0,
		outer.size.x, 1.0), Color(DEEP.r, DEEP.g, DEEP.b, 0.8))
	var cx := outer.position.x + outer.size.x * 0.5
	draw_rect(Rect2(cx - 4.0, outer.position.y - 4.0, 8.0, 4.0), CAGE_LIT)
	# THE NAME, STENCILLED ON THE PLATE. The caption that used to float above the
	# grid, now where a cargo cage actually carries its markings.
	var inset := Rect2(outer.position.x + 6.0, outer.position.y + 5.0,
		outer.size.x - 12.0, CAGE_TOP - 10.0)
	draw_rect(inset, DEEP)
	draw_rect(inset, Color(CAGE_LIT.r, CAGE_LIT.g, CAGE_LIT.b, 0.5), false, 1.0)
	if hold_label != "":
		var f := UITheme.pixel_font()
		var tw := f.get_string_size(hold_label, HORIZONTAL_ALIGNMENT_LEFT, -1,
			UITheme.FS_SMALL).x
		draw_string(f, Vector2(inset.position.x + maxf(4.0, (inset.size.x - tw) * 0.5),
			inset.position.y + 10.0), hold_label, HORIZONTAL_ALIGNMENT_LEFT,
			inset.size.x - 8.0, UITheme.FS_SMALL, PLATE_INK)
	# The skid, with hazard paint along its face.
	var skid := Rect2(outer.position.x, r.end.y, outer.size.x, CAGE_FOOT)
	draw_rect(skid, CAGE)
	draw_rect(Rect2(skid.position.x, skid.position.y, skid.size.x, 1.0), CAGE_LIT)
	var sx := skid.position.x + 4.0
	while sx < skid.end.x - 8.0:
		draw_rect(Rect2(sx, skid.position.y + 4.0, 6.0, 4.0),
			Color(LAMP.r, LAMP.g, LAMP.b, 0.55))
		sx += 12.0
	# Corner gussets where the posts meet the plate, which is what makes four
	# bars into a frame.
	for gx in [r.position.x, r.end.x - 5.0]:
		draw_rect(Rect2(gx, r.position.y, 5.0, 5.0), CAGE)
		draw_rect(Rect2(gx, r.end.y - 5.0, 5.0, 5.0), CAGE)


## Where the station's banners hang on the dock: over the counter, which is the
## side of the room that belongs to whoever runs the market.
func banner_spots() -> Array:
	return [Vector2(0.80, 38.0)]
