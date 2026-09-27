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


## HOW THIS SHOP IS ARRANGED, one of `LAYOUTS`, set by the screen off the
## station's seed -- the same move as the window style: somebody fitted this
## shop out, and they put the rack and the till where they put them.
##
##   0  rack left, till right; the door beside the rack, the window over the till
##   1  the same, mirrored
##   2  rack left, till standing mid-floor under the window, door at the far end
##   3  the same, mirrored
var layout := 0
## Written out rather than `ARRANGEMENTS.size()`: a const that calls a method on
## another const cannot be resolved from a different script, and the screen
## reads this one to pick a shop. `artcheck` fails if the two disagree.
const LAYOUTS := 10

## TEN FITTED-OUT SHOPS, one picked off the station's seed.
##
## `order` is how the furniture stands, and it is the OLD four arrangements
## unchanged -- the rack and the till have real connections and reordering the
## row is all that ever moved them. What is new is the wall: each layout names
## the openings cut in it, so a shop is a fit-out rather than one window slid
## left or right.
##
## `skin` places a shaped sprite by its own top-left; the sprite's size comes
## from `StationRoom.opening_size`, never from a number written here, because a
## number here would go stale the moment the art was recut. A `w`/`h` entry with
## no skin is a plain glazed pane in one of the three bezel styles.
##
## NO BACKDROP IS NAMED. Which place is behind the wall is the station's to
## decide, not the fit-out's -- `StationRoom` picks it off `place_seed`, so two
## shops with the same layout on different stations look out on different
## halls. Openings are checked against the wall and each other by
## `artcheck`, which is what stops a layout going in that hangs a window half
## off the deck.
const ARRANGEMENTS: Array[Dictionary] = [
	# 0. A long band high up and a rail below it; rack left, till right.
	{order = 0, cuts = [{skin = &"clerestory", x = 170, y = 28},
		{skin = &"rail", x = 44, y = 150}, {door = 600}]},
	# 1. The arch, centred, with the till standing under it.
	{order = 2, cuts = [{skin = &"arch", x = 250, y = 53}, {door = 60}]},
	# 2. A hex and a big round port either side of a mid-wall door.
	{order = 0, cuts = [{skin = &"hex", x = 60, y = 80},
		{skin = &"roundbig", x = 404, y = 70}, {door = 330}]},
	# 3. The double window over a bare deck, door at the far end.
	{order = 1, cuts = [{skin = &"clerestory", x = 170, y = 16},
		{skin = &"double", x = 100, y = 113}, {door = 620}]},
	# 4. A slot each end, a vitrine between them.
	{order = 2, cuts = [{skin = &"slot", x = 30, y = 41},
		{skin = &"slot", x = 596, y = 41}, {skin = &"vitrine", x = 250, y = 120},
		{door = 180}]},
	# 5. A torn hull, patched, with a shutter beside it.
	{order = 3, cuts = [{skin = &"breach", x = 90, y = 110},
		{skin = &"shutter", x = 400, y = 113}, {door = 20}]},
	# 6. Shopfront: a canopy over the till, a vitrine beside it.
	{order = 1, cuts = [{skin = &"canopy", x = 40, y = 120},
		{skin = &"vitrine", x = 400, y = 140}, {door = 670}]},
	# 7. A bay window and a cracked pane, rack between them.
	{order = 0, cuts = [{skin = &"bay", x = 30, y = 130},
		{skin = &"cracked", x = 350, y = 120}, {door = 650}]},
	# 8. One canted window and a big port; everything else plain wall.
	{order = 3, cuts = [{skin = &"angled", x = 30, y = 115},
		{skin = &"roundbig", x = 360, y = 85}, {door = 650}]},
	# 9. A band over a cracked pane, one slot at the end.
	{order = 2, cuts = [{skin = &"clerestory", x = 170, y = 16},
		{skin = &"cracked", x = 60, y = 125}, {skin = &"slot", x = 600, y = 41},
		{door = 400}]},
]

## A door is 56 wide and runs to the deck, because a door that stops short of
## the floor is a hatch. Its head sits under the sky band.
##
## 190, NOT 150, since the concourse's people were doubled to 150-174px
## (2026-09-25): a door shorter than the people walking past it reads wrong.
## The bench's door art was raised the same 34px.
const DOOR_W := 56.0
const DOOR_H := 190.0

## THE WALL THE NUMBERS ABOVE WERE DRAWN AGAINST, measured off the live layout
## rather than assumed -- the shop panel is 740x431 with its floor line at 353.
## Nothing reads these at draw time; `openings()` is handed the real width and
## floor every redraw and drops anything that will not fit. They are here so
## `artcheck` can test the table against the wall it was designed for, and so
## the next person to move a cut knows what the coordinates mean.
const FIT_WALL := Vector2(740.0, 431.0)
const FIT_FLOOR_Y := 353.0
## A layout to use instead of the seed's, for `stationshot layout=`.
static var forced_layout := -1


func _dress_wall(w: float, _h: float, floor_y: float) -> void:
	# THE LONG LETTERBOX OVER THE SHOP IS GONE. It was the one window still
	# drawn from rectangles and stars, and beside the promenade behind the wall
	# it read as programmer art. The wall's openings are the windows now.
	# `SKY_Y` and `SKY_H` stay, as where the top of the usable wall starts.
	var pipe := SKY_Y + SKY_H + 13.0
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


## THE SHOP FRONT FACES THE CONCOURSE. A shop's big glass is the side it sells
## through, so the wide window over the till looks out onto the promenade -- and
## a door behind the rack goes back into the station, which is where the stock
## comes from.
##
## Both sit clear of what stands in front of them: the window starts right of
## the banner at the middle of the wall and stops above the till's desk; the door
## stands between the rack and the banner and runs to the floor, because a door
## that stops short of the deck is a hatch.
func openings(w: float, h: float, floor_y: float) -> Array:
	var i := clampi(layout, 0, ARRANGEMENTS.size() - 1)
	return cuts_of(i, w, floor_y)


## The openings a layout cuts, as rects on this wall. Static and side-effect
## free so `artcheck` can ask for every layout's without standing a shop up.
##
## A cut that will not fit -- a sprite whose art is missing, or one that would
## hang off the deck on a narrower wall -- is DROPPED, not clamped. A clamped
## opening is a window in the wrong place, which looks like a mistake nobody
## made; a missing one just leaves wall, which is what a wall is.
static func cuts_of(i: int, w: float, floor_y: float) -> Array:
	var out := []
	var row: Dictionary = ARRANGEMENTS[clampi(i, 0, ARRANGEMENTS.size() - 1)]
	for cut in row.cuts:
		if cut.has("door"):
			var dh := minf(DOOR_H, floor_y - (SKY_Y + SKY_H + 30.0))
			if dh < 90.0 or float(cut.door) + DOOR_W > w - 12.0:
				continue
			out.append({rect = Rect2(float(cut.door), floor_y - dh, DOOR_W, dh),
				kind = &"door"})
			continue
		var skin: StringName = cut.skin
		var sz := StationRoom.opening_size(skin)
		if sz == Vector2.ZERO:
			continue
		var r := Rect2(Vector2(float(cut.x), float(cut.y)), sz)
		if r.end.x > w - 12.0 or r.end.y > floor_y or r.position.y < 8.0:
			continue
		out.append({rect = r, kind = &"open", skin = skin})
	return out


## The arrangement the row stands in for this layout: still one of the original
## four, so nothing about the furniture had to be reinvented to get ten shops.
static func order_of(i: int) -> int:
	return int(ARRANGEMENTS[clampi(i, 0, ARRANGEMENTS.size() - 1)].order)
## No banner in the shop. It hung mid-wall between the rack and the window and
## was cut; the livery still shows on the window frames' head lights.
func banner_spots() -> Array:
	return []
