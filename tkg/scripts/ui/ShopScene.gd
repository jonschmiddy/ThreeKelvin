class_name ShopScene
extends StationRoom

## The room the Promenade's shop stands in.
##
## THE FURNITURE WAS FLOATING. A rack against one wall and a till against the
## other, on a flat panel with a hole between them -- two objects and no place.
## The floor and the wall are `StationRoom`'s now, shared with every other deck
## that needs one; what is the SHOP's is the long window over it and the stock on
## a pallet in the aisle.
##
## THE WINDOW IS THE POINT. A station interior with no way out is a corridor; one
## long viewport over the shop says the promenade is a deck on something that is
## in space. It sits ABOVE both pieces of furniture rather than behind them,
## because a window you cannot see is a dark rectangle.

## The long window over the shop: how far down it starts and how tall it is.
## Above the rack's 335, which is what makes it visible at all.
const SKY_Y := 16.0
const SKY_H := 52.0


func _dress_wall(w: float, _h: float, floor_y: float) -> void:
	# ONE LONG LETTERBOX rather than a row of portholes: the shop is on the
	# OUTSIDE of something, and a continuous view is what says the deck curves
	# away rather than that somebody drilled three holes.
	var sky := Rect2(26.0, SKY_Y, w - 52.0, SKY_H)
	if sky.size.x > 80.0 and sky.end.y < floor_y - 40.0:
		_window(sky)
	var pipe := sky.end.y + 13.0
	if pipe < floor_y - 30.0:
		_conduit(pipe, w)


func _dress_floor(w: float, h: float, floor_y: float) -> void:
	# --- STOCK WAITING TO GO OUT, on a pallet in the aisle.
	#
	# IN THE MIDDLE, WHICH IS WHERE THE AISLE IS. This does not know where the
	# rack and the till are and does not need to: the rack stands against the left
	# wall and the counter against the right, so the centre of the room is the
	# floor between them by construction. It is the one thing here that says the
	# shop is WORKING rather than staged -- a delivery nobody has put away.
	var cx0 := w * 0.5
	var base := h - 12.0
	if base <= floor_y + 24.0:
		return
	# The pallet: two bearers and a deck, seen almost edge-on.
	draw_rect(Rect2(cx0 - 34.0, base, 68.0, 5.0), _tint(EDGE))
	draw_rect(Rect2(cx0 - 34.0, base, 68.0, 1.0), CRATE_LIP)
	draw_rect(Rect2(cx0 - 30.0, base + 5.0, 5.0, 4.0), DEEP)
	draw_rect(Rect2(cx0 + 25.0, base + 5.0, 5.0, 4.0), DEEP)
	for c in [Rect2(cx0 - 30.0, base - 26.0, 28.0, 26.0),
			Rect2(cx0 - 1.0, base - 19.0, 24.0, 19.0),
			Rect2(cx0 - 24.0, base - 44.0, 20.0, 18.0)]:
		var r: Rect2 = c
		if r.position.y < floor_y - 30.0:
			continue
		_crate(r)


## Where the station's banners hang in the shop: on the back wall over the aisle,
## under the conduit, between the rack and the till.
func banner_spots() -> Array:
	return [Vector2(0.5, SKY_Y + SKY_H + 26.0)]
