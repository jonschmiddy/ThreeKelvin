class_name ShelfDisplay
extends Control

## The Promenade's stock, as objects standing on a shelf.
##
## IT WAS A LIST OF ROWS AND NOW IT IS A SHOP. The rack under the old list was
## furniture behind a table of names -- better than a picture behind one, and
## still a table. What is actually on a shelf is THINGS, at the size they are,
## in the shape they are: a four-cell rail takes four cells of board and a
## fitting takes one, so the shelf tells you what you are buying before you have
## read a word of it.
##
## THE HOVER IS FREE. `ModuleIcon` already answers `_make_custom_tooltip` with
## the part's readout and every card it grants -- the same panel the refit screen
## and the module gallery use -- so putting the real icon on a board is what
## gives the shelf its inspection, rather than something built for this screen.
##
## Drawn rather than loaded, like `YardScene` and `StationSpine`. Art replaces
## the body of `_draw`; the layout below is what the art has to fit.

## NO SIGNAL, BECAUSE NOTHING ON A SHELF IS A BUTTON.
##
## The ticket used to be one: clicking a price bought the part where it stood.
## That was three hundred credits leaving your account on a single click with
## nothing carried anywhere, which is the gesture the game threw out of the hold
## when right-click-to-jettison was cut. The stock is objects and the objects
## drag -- `ModuleIcon` is an `ItemIcon`, so every part on these boards can
## already be picked up -- and the till on the deck below is what a shop has
## instead of a buy button.

## One cell of a module's footprint, in pixels.
##
## THE SAME 40 THE HOLD USES, so a part is the same size on the shelf as it is
## in the bay you will put it in. 26 was the first try -- four spines to a board
## and technically legible, but a shop where the goods are smaller than they are
## anywhere else in the game reads as a list of thumbnails rather than as
## objects. A 1x1 fitting is 40 across and a 2x2 is 80, which is a thing you
## point at rather than a thing you squint at.
const CELL := HoldGrid.CELL
## Air above a board's items, so nothing touches the shelf above it.
const HEAD := 7
## How thick a board is, and the frame around the whole unit.
const PLANK := 5
const POST_W := 13
const CAP_H := 9
const PLINTH_H := 11
## Where the price ticket sits on the board's front lip.
const TICKET_H := 5
## How tall a price tag is. Enough for an 8px face with a punched hole beside it.
const TAG_H := 15
## Air between two things standing side by side on the same board.
const GAP := 10.0
## How far apart the boards are, floor to floor.
##
## Tall enough for the tallest thing in the catalogue to stand on one -- a 2x2 is
## two cells -- plus its ticket and a little headroom. Fixed rather than measured
## off the stock, because a shelf's boards are where the shelf's boards are: they
## do not move up when a shop happens to be selling small things.
const PITCH := CELL * 2 + PLANK + TICKET_H + HEAD + 6

## HOW BIG THE UNIT IS, rather than how big the deck is.
##
## A PIECE OF FURNITURE, NOT A WALL. The rack was handed the whole deck and drew
## boards all the way down it, which made the Promenade a warehouse aisle with
## four things in it. A shop's shelf is an OBJECT standing in a room -- it is the
## size it is, the air around it is the room, and an outpost with two parts on it
## still looks like a shop with two parts in it because the empty boards are
## still there. Three of them, which is a shelf; nine was a wall.
const BOARDS := 3
## Wide enough for the longest part in the catalogue -- a four-cell spine is 160
## -- plus the two posts and a little air either side of it.
const RACK_W := 280

## The height that many boards need. Derived rather than typed, so the unit and
## the boards inside it can never disagree about how tall it is.
static func rack_height() -> float:
	return float(CAP_H + 6 + PITCH * BOARDS + PLINTH_H)

const POST := Color("#2c3d52")
const EDGE := Color("#465c78")
const LIP := Color("#5f7794")
const BACK := Color("#161f2b")
const SHADE := Color("#070a10")

## Every board's top edge, in local coordinates. Filled by `stock`, read by
## `_draw`, so the boards are always under the things standing on them.
var _boards: Array[float] = []

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Stand a shelf's worth of parts up.
##
## `rows` is what `_refresh_stock` already builds: `thing`, `price` and `pick`
## per entry. Laid out left to right and wrapped onto the next board when the
## next part will not fit, which is how a shelf gets filled by a person.
func stock(rows: Array) -> void:
	Widgets.clear(self)
	_boards.clear()
	var w := size.x
	var h := size.y
	if w <= 40.0 or h <= 40.0:
		# No layout yet. `_refresh_stock` calls again on `resized`, and doing the
		# arithmetic against a width of zero would put everything on one board.
		return

	# --- THE BOARDS ARE WHERE THE BOARDS ARE.
	#
	# Fixed pitch down the whole unit, filled from the top. The empty ones at the
	# bottom are not a gap to be closed -- an outpost with two parts on it SHOULD
	# look like a shop with two parts in it, and a rack that shrank to fit its
	# stock could never say that.
	var usable := h - float(CAP_H + 6 + PLINTH_H)
	# CAPPED AT `BOARDS`, so a taller deck makes a taller ROOM and not a taller
	# rack. Still measured against the height it was actually given, because a
	# unit squeezed below its own size should lose boards rather than draw them
	# through its own plinth.
	var count := clampi(int(usable / float(PITCH)), 1, BOARDS)
	for i in count:
		_boards.append(float(CAP_H + 6) + float(PITCH) * float(i + 1)
			- float(PLANK + TICKET_H + HEAD) - 2.0)

	# --- AND THE STOCK STANDS ON THEM, wrapped left to right.
	#
	# Wrapped FIRST and placed SECOND, because things on a shelf stand on it: a
	# 2x2 and a 1x1 sharing a board line up at the BOTTOM, and a part cannot be
	# positioned until the tallest thing beside it is known.
	# SPREAD ACROSS THE BOARDS, not packed onto the first one.
	#
	# Wrapping purely on width put all five parts on the top shelf with three
	# empty boards underneath -- which is what a delivery looks like before
	# anybody has put it away, not what a shop looks like. A shopkeeper spreads
	# the stock out, so the wrap takes whichever comes first: the board is full
	# ACROSS, or it has its share of the goods.
	var inner := w - float(POST_W * 2 + 10)
	# HOW MANY GO ON ONE BOARD.
	#
	# SPREAD, BUT NOT ONE PER BOARD. Dividing the stock over every board is right
	# when there is stock to divide; with three parts and four boards it put one
	# thing on each and the rack read as a column of single objects rather than
	# as a shop. So the spread is over as many boards as will hold PAIRS, capped
	# by how many boards there are -- three parts fill two boards and five fill
	# three, which looks like somebody stood them up rather than dealt them out.
	var boards_used := clampi(int(ceilf(float(rows.size()) * 0.5)), 1, count)
	var share := maxi(1, int(ceilf(float(rows.size()) / float(boards_used))))
	var shelves: Array = []
	var line: Array = []
	var used := 0.0
	for entry in rows:
		var m := entry.thing as ModuleData
		if m == null:
			continue
		# THE WIDER OF THE TWO, because the price hangs under the part and a
		# cheap fitting can carry a number broader than itself. Wrapping on the
		# part alone put two of those side by side and let their cards touch.
		var iw := _reserve(m, entry)
		if not line.is_empty() and (used + iw > inner or line.size() >= share):
			shelves.append(line)
			line = []
			used = 0.0
		line.append(entry)
		used += iw + GAP
	if not line.is_empty():
		shelves.append(line)

	for i in shelves.size():
		if i >= _boards.size():
			# More stock than boards. Nothing is dropped silently: the unit is as
			# tall as the deck and the deck is as tall as it is, so this is a real
			# limit and the shelf says so rather than stacking parts on nothing.
			break
		var base: float = _boards[i]
		var x := float(POST_W + 5)
		for entry in shelves[i]:
			var m2 := entry.thing as ModuleData
			var iw2 := float(maxi(1, m2.size.x) * CELL)
			var ih2 := float(maxi(1, m2.size.y) * CELL)
			# The part sits in the MIDDLE of what was reserved for it, so that
			# when the tag is the wider of the two the overhang is even and the
			# card still reads as belonging to the thing above it.
			var keep := _reserve(m2, entry)
			var slot := _slot(m2, entry, iw2, ih2)
			add_child(slot)
			slot.position = Vector2(x + (keep - iw2) * 0.5, base - ih2)
			slot.size = Vector2(iw2, ih2)
			x += keep + GAP
	queue_redraw()


## How much board one item eats, part and price together.
##
## ONE ANSWER, ASKED TWICE. The wrap needs it to decide where a board ends and
## the placement needs it to know where the next thing starts, and the two
## disagreeing is how a shelf loses its last item off the right-hand post.
func _reserve(m: ModuleData, entry: Dictionary) -> float:
	return maxf(float(maxi(1, m.size.x) * CELL),
		PriceTag.width_for("%d CR" % int(entry.price)))


## One part on a board: the icon, and the pointer business around it.
func _slot(m: ModuleData, entry: Dictionary, iw: float, ih: float) -> Control:
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# THE REAL `ModuleIcon`, not a picture of one. It brings the plate, the
	# manufacturer stripe, the rarity ground, the silhouette AND the tooltip with
	# every card the part grants -- none of which this screen has to know about.
	var icon := ModuleIcon.new()
	# STAMPED WITH WHERE IT CAME FROM, and the till downstairs is the only thing
	# that accepts it. See `TradeCounter.FROM_SHELF` for why the string is a
	# constant instead of a literal in each of the two files that care.
	icon.setup(m, TradeCounter.FROM_SHELF)
	icon.custom_minimum_size = Vector2.ZERO
	icon.position = Vector2.ZERO
	icon.size = Vector2(iw, ih)
	icon.plate_scale = float(CELL) / float(HoldGrid.CELL) * ModuleIcon.HOLD_K
	box.add_child(icon)

	# THE PRICE ON THE BOARD, under the thing it is the price of. A shop puts the
	# ticket on the shelf edge and not on the box, which is also the only place
	# it can go here without covering the part.
	#
	# A TAG AND NOT A BUTTON. It is a piece of card on a string; what buys the
	# part is carrying the part to the till.
	#
	# CENTRED UNDER ITS OWN ITEM. A tag is as wide as its number and the things
	# above them are not -- a four-cell rail is a hundred and sixty pixels and a
	# fitting is forty -- so a wide price under a narrow part hangs past it on
	# both sides. That is what `stock` reserves room for: it advances by whichever
	# of the two is wider, so the overhang lands in air and never on a neighbour.
	var price := int(entry.price)
	var tag := PriceTag.new()
	tag.text = "%d CR" % price
	# A PRICE YOU CANNOT PAY IS STILL THE PRICE. The card greys rather than
	# vanishing: what a thing costs is the reason you are not buying it, and a
	# shelf that went blank on the parts you cannot afford would be hiding its
	# own answer.
	tag.afford = Run.credits >= price
	var tw := tag.wants()
	tag.position = Vector2((iw - tw) * 0.5, ih + float(PLANK) - 1.0)
	tag.size = Vector2(tw, float(TAG_H))
	box.add_child(tag)
	return box


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 20.0 or h <= 20.0:
		return

	# --- THE BACK PANEL. Two posts and some boards are a diagram of a shelf;
	# what makes it an object is having a BACK for the goods to stand against.
	draw_rect(Rect2(float(POST_W), 0.0, w - float(POST_W * 2), h), BACK)
	var sx := float(POST_W) + 9.0
	while sx < w - float(POST_W) - 6.0:
		var sy := 8.0
		while sy < h - 8.0:
			draw_rect(Rect2(sx, sy, 2.0, 5.0), Color(SHADE.r, SHADE.g, SHADE.b, 0.5))
			sy += 14.0
		sx += 19.0

	# --- THE UPRIGHTS, drilled the whole way down whether a board uses the holes
	# or not. A rack is drilled once and loaded later, and the empty holes are
	# what say it could hold more than it does.
	for px in [0.0, w - float(POST_W)]:
		draw_rect(Rect2(px, 0.0, float(POST_W), h), POST)
		draw_rect(Rect2(px, 0.0, 1.0, h), EDGE)
		draw_rect(Rect2(px + float(POST_W) - 1.0, 0.0, 1.0, h),
			Color(SHADE.r, SHADE.g, SHADE.b, 0.7))
	var y := 13.0
	while y < h - 8.0:
		for hx in [4.0, w - float(POST_W) + 4.0]:
			draw_rect(Rect2(hx, y, 4.0, 3.0), Color(SHADE.r, SHADE.g, SHADE.b, 0.75))
			draw_rect(Rect2(hx, y + 3.0, 4.0, 1.0), EDGE)
		y += 15.0

	# --- CAP AND PLINTH: a lid and a foot, so the unit is a whole thing rather
	# than a slice of something taller that happens to stop here.
	draw_rect(Rect2(0.0, 0.0, w, float(CAP_H)), POST)
	draw_rect(Rect2(0.0, 0.0, w, 1.0), LIP)
	draw_rect(Rect2(0.0, h - float(PLINTH_H), w, float(PLINTH_H)), POST)
	draw_rect(Rect2(0.0, h - float(PLINTH_H), w, 1.0), LIP)
	draw_rect(Rect2(5.0, h - float(PLINTH_H) + 3.0, w - 10.0, float(PLINTH_H) - 3.0),
		Color(SHADE.r, SHADE.g, SHADE.b, 0.6))

	# --- AND THE BOARDS THE PARTS ARE STANDING ON.
	for by in _boards:
		# The shadow the goods cast down onto their own board, so they are ON it.
		draw_rect(Rect2(float(POST_W), by - 3.0, w - float(POST_W * 2), 3.0),
			Color(SHADE.r, SHADE.g, SHADE.b, 0.5))
		# Stepped brackets where the board meets each post -- three rectangles
		# rather than a diagonal, because nothing here can trust a slope to land
		# on the pixel grid.
		for step in 3:
			var bw := 13.0 - 4.0 * float(step)
			if bw <= 0.0:
				break
			var byy := by + float(PLANK) + float(step) * 2.0
			draw_rect(Rect2(float(POST_W), byy, bw, 2.0), POST)
			draw_rect(Rect2(w - float(POST_W) - bw, byy, bw, 2.0), POST)
		# The board: a lit top lip and a dark underside, which is what a surface
		# seen almost edge-on looks like and what stops the goods floating.
		draw_rect(Rect2(0.0, by, w, float(PLANK)), POST)
		draw_rect(Rect2(0.0, by, w, 1.0), LIP)
		draw_rect(Rect2(0.0, by + float(PLANK) - 1.0, w, 1.0),
			Color(SHADE.r, SHADE.g, SHADE.b, 0.75))


## One price, as a card on a string.
##
## IT WAS A LABEL, and a label is a number floating on a shelf. What a shop puts
## under its goods is an OBJECT -- card, a punched hole, a bit of string -- and
## the difference between those two things is about thirty lines of rectangles.
## It is also the only warm surface on this deck, which is the point: paper among
## painted metal reads as somebody's handwriting rather than as a readout.
##
## Drawn rather than loaded, like everything else standing in this station.
class PriceTag extends Control:
	## The card, and the same card once you cannot afford what is on it.
	const CARD := Color("#c2ae86")
	const CARD_DIM := Color("#6e6858")
	const INK := Color("#241d14")
	const INK_DIM := Color("#3f3a30")
	const HOLE := Color("#100c08")
	const STRING := Color("#8d7c5c")

	## How far in from the left the card's point reaches back to.
	const NOSE := 9.0
	## Air either side of the number.
	const PAD := 5.0

	var text: String = ""
	var afford: bool = true

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## How wide a tag needs to be for a given number.
	##
	## MEASURED, NOT GUESSED. "9 CR" and "236 CR" are not the same width, and a
	## fixed card sized for the longest price in the game would leave every cheap
	## fitting under a mostly empty piece of card.
	##
	## STATIC, because the shelf has to know how wide a tag will be BEFORE it
	## decides where the thing above it stands -- see the reservation in `stock`.
	static func width_for(t: String) -> float:
		var f := UITheme.pixel_font()
		return NOSE + PAD * 2.0 + f.get_string_size(t,
			HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x

	func wants() -> float:
		return width_for(text)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		if w <= NOSE + 6.0 or h < 9.0:
			return
		var card := CARD if afford else CARD_DIM
		var ink := INK if afford else INK_DIM
		var mid := h * 0.5

		# --- THE STRING, up over the board's lip. Two pixels of it, which is all
		# there is room for and all it needs: the tag stops looking printed on.
		draw_rect(Rect2(NOSE - 1.0, -3.0, 1.0, 4.0),
			Color(STRING.r, STRING.g, STRING.b, 0.85))

		# --- THE SHADOW IT CASTS, down and right. The same trick the posting
		# board's notices use, and the reason the card sits ON the shelf rather
		# than in it.
		draw_rect(Rect2(2.0, 2.0, w - 1.0, h - 1.0), Color(0.03, 0.04, 0.06, 0.5))

		# --- THE CARD. A rectangle for the body, and a point stepped one row at a
		# time for the nose -- nothing here can trust a slope to land on the pixel
		# grid, which is the same reason the shelf's brackets are three rectangles
		# instead of a diagonal.
		draw_rect(Rect2(NOSE, 0.0, w - NOSE, h), card)
		var row := 0.0
		while row < h:
			# Distance from the point, as a fraction of half the card's height.
			var away: float = absf(row + 0.5 - mid) / mid
			var x0 := NOSE * away
			draw_rect(Rect2(floorf(x0), row, NOSE - floorf(x0) + 1.0, 1.0), card)
			row += 1.0
		# A lit top edge and a dark underside, so the card has a thickness.
		draw_rect(Rect2(NOSE, 0.0, w - NOSE, 1.0), card.lightened(0.3))
		draw_rect(Rect2(NOSE, h - 1.0, w - NOSE, 1.0), card.darkened(0.35))

		# --- THE PUNCHED HOLE, in the narrow part where a hole actually goes.
		draw_rect(Rect2(NOSE - 2.0, mid - 1.5, 3.0, 3.0), HOLE)

		# --- AND THE NUMBER, in ink on the card.
		var f := UITheme.pixel_font()
		var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			UITheme.FS_SMALL).x
		draw_string(f, Vector2(NOSE + PAD + (w - NOSE - PAD * 2.0 - tw) * 0.5,
			mid + 3.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL, ink)
