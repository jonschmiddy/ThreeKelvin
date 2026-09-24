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
## ONE CELL ON THE SHELF: THE SPRITE'S OWN 1x, 20 A CELL -- half the hold's 40.
##
## The paragraph above is why it was 40, and it was overruled by looking: seen on
## the rack at both sizes, Jon kept 1x. A part at its own pixel size is the
## finest-detailed thing on the wall, so it reads as the goods rather than as
## furniture, and the rack it needs is half the height. The cost is the one the
## paragraph names -- a part is bigger in your hold than it was on the shelf.
const SHELF_CELL := 20
## Air above a board's items, so nothing touches the shelf above it.
const HEAD := 7
## How thick a board is, and the frame around the whole unit.
const PLANK := 5
## THE UPRIGHT, AND IT IS FURNITURE, NOT SHELF. At 13 with 7 of air inside it,
## the frame spent 40 of the rack's 132 pixels on itself and the goods read as
## lost in it. Eight and four is the same pillar with its two flat middle
## columns dropped: the shelf space is 92 either way, so the rack is 116.
const POST_W := 8
const CAP_H := 9
const PLINTH_H := 11
## Where the price ticket sits on the board's front lip.
const TICKET_H := 5
## How tall a price tag is. Enough for an 8px face with a punched hole beside it.
const TAG_H := 9
## Air between two things standing side by side on the same board.
const GAP := 10.0
## How far apart the boards are, floor to floor.
##
## Tall enough for the tallest thing in the catalogue to stand on one -- a 2x2 is
## two cells -- plus its ticket and a little headroom. Fixed rather than measured
## off the stock, because a shelf's boards are where the shelf's boards are: they
## do not move up when a shop happens to be selling small things.
const PITCH := SHELF_CELL * 2 + PLANK + TICKET_H + HEAD + 6

## HOW BIG THE UNIT IS, rather than how big the deck is.
##
## A PIECE OF FURNITURE, NOT A WALL. The rack was handed the whole deck and drew
## boards all the way down it, which made the Promenade a warehouse aisle with
## four things in it. A shop's shelf is an OBJECT standing in a room -- it is the
## size it is, the air around it is the room, and an outpost with two parts on it
## still looks like a shop with two parts in it because the empty boards are
## still there. Three of them, which is a shelf; nine was a wall.
const BOARDS := 3
## EACH BOARD IS A 4 x 2 STRIP OF CELLS -- Jon's spec. Four cells across, and
## two high so a 2x2 part stands on it; parts snap to the columns the way they
## snap to the hold's grid, side by side and never stacked. The longest part in
## the catalogue, a four-cell rail, fills a board on its own.
const SHELF_COLS := 4
## AIR BETWEEN PARTS, and a fixed amount of it. Flush read as one lump; spread
## evenly across the board left three parts marooned. Four pixels, packed from
## the left post.
const PART_GAP := 4
## Air inside each post. See POST_W: it came down with the upright.
const SHELF_PAD := 4
## The break between one cell's light and the next, so the strip can be counted.
##
## Two pixels, which is one at game scale -- the gap has to survive the shrink
## without eating the light either side of it. The art's own bays under the
## board run at a pitch of its own and are NOT what this lines up with: those
## are how the rack was built, this is how big the part on it is.
const PIP_GAP := 2
## The board's usable width: six cells and the five gaps a full board needs.
const SHELF_INNER := SHELF_COLS * SHELF_CELL + (SHELF_COLS - 1) * PART_GAP
const RACK_W := SHELF_INNER + POST_W * 2 + SHELF_PAD * 2

## The height that many boards need. Derived rather than typed, so the unit and
## the boards inside it can never disagree about how tall it is.
static func rack_height(boards: int = BOARDS) -> float:
	return float(CAP_H + 6 + PITCH * boards + PLINTH_H)


## Two boards, or three when two will not hold this stock.
##
## TWO OR THREE SHELVES TALL. Twelve cells hold an ordinary station's three
## parts nearly always; a hub's five can need eighteen, so a hub gets the tall
## rack. Asked of `_pack`, the same packing `stock` lays out with, so the rack
## and what stands on it cannot disagree.
static func boards_for(rows: Array) -> int:
	return 2 if _pack(rows, 2)[1] == 0 else BOARDS


## The stock on `count` boards, as `[boards, spilled]`: each board an Array of
## entries in stock order, and how many parts found no room.
##
## WIDEST FIRST, ONTO THE BOARD WITH THE MOST ROOM LEFT. Widest-first is what
## stops a long rail being stranded by small parts ahead of it; most-room-first
## spreads the stock across the boards instead of filling the top one, which is
## what a shopkeeper does and what a delivery nobody unpacked does not.
static func _pack(rows: Array, count: int) -> Array:
	var items: Array = []
	for i in rows.size():
		var m := rows[i].thing as ModuleData
		if m != null:
			items.append([i, clampi(m.size.x, 1, SHELF_COLS), rows[i]])
	items.sort_custom(func(a1, b1): return a1[1] > b1[1])
	var boards: Array = []
	var free: Array[int] = []
	for b in count:
		boards.append([])
		free.append(SHELF_COLS)
	var spilled := 0
	for it in items:
		var best := -1
		for b in count:
			if free[b] >= it[1] and (best < 0 or free[b] > free[best]):
				best = b
		if best < 0:
			spilled += 1
			continue
		boards[best].append(it)
		free[best] -= it[1]
	var out: Array = []
	for b in boards:
		b.sort_custom(func(a2, b2): return a2[0] < b2[0])
		var line: Array = []
		for it in b:
			line.append(it[2])
		out.append(line)
	return [out, spilled]

const POST := Color("#2c3d52")
const EDGE := Color("#465c78")
const LIP := Color("#5f7794")
const BACK := Color("#161f2b")
const SHADE := Color("#070a10")

## Every board's top edge, in local coordinates. Filled by `stock`, read by
## `_draw`, so the boards are always under the things standing on them.
var _boards: Array[float] = []
## One light per part on the board under it, in the part's rarity colour:
## `[Rect2, Color]`. What the boxed plate's border and ground used to say, said
## by the shelf instead -- a shop lights its better stock.
var _pips: Array = []

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## The rack as art, or null for the drawn one.
##
## RESOLVED OUTSIDE `_draw`, deferred: a texture first touched inside a draw
## call renders white for good -- `StationRoom._plate_key` has the long version.
## The art is authored to `RACK_W` x `rack_height()` with its boards on the
## heights `stock` stands parts on, so the parts land on them without asking.
var _art2: Texture2D = null
var _art3: Texture2D = null


func _ready() -> void:
	_load_art.call_deferred()


func _load_art() -> void:
	_art2 = DB.station_sprite(&"shop", &"shelf2")
	_art3 = DB.station_sprite(&"shop", &"shelf3")
	queue_redraw()


## Stand a shelf's worth of parts up.
##
## `rows` is what `_refresh_stock` already builds: `thing`, `price` and `pick`
## per entry. Laid out left to right and wrapped onto the next board when the
## next part will not fit, which is how a shelf gets filled by a person.
func stock(rows: Array) -> void:
	Widgets.clear(self)
	_boards.clear()
	_pips.clear()
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
	var shelves: Array = _pack(rows, count)[0]
	for i in shelves.size():
		var base: float = _boards[i]
		# From the left post, a `PART_GAP` between each pair.
		var line: Array = shelves[i]
		var step := float(PART_GAP)
		var x := float(POST_W + SHELF_PAD)
		for entry in line:
			var m2 := entry.thing as ModuleData
			var cw := clampi(m2.size.x, 1, SHELF_COLS)
			var iw2 := float(cw * SHELF_CELL)
			var ih2 := float(maxi(1, m2.size.y) * SHELF_CELL)
			var slot := _slot(m2, entry, iw2, ih2)
			add_child(slot)
			slot.position = Vector2(x, base - ih2)
			slot.size = Vector2(iw2, ih2)
			# ON THE BOARD'S LIGHT STRIP, ONE SEGMENT PER CELL: the edge under a
			# rare part glows its colour, broken where its cells are. Three rows
			# so it covers the strip on the middle board too, which the art puts
			# a pixel higher than `base`.
			#
			# IT COUNTS, it does not just measure. As one unbroken rect it was
			# only a LENGTH, and a length is read against the part standing on
			# it rather than against the grid -- so a 3x1 and a 2x1 looked like
			# the same thing at two sizes. Segmented, the strip says three and
			# says two, and you can count it without knowing the cell pitch.
			# ONE BLOCK IS ONE CELL, at the cell pitch -- not the part's width
			# divided by its cells. Dividing gave a block of 18.67px for a 3x1
			# against 19px for a 2x1, which lands on half pixels at 2x and
			# makes the segments ragged and unequal. A block of SHELF_CELL less
			# the break is a whole number for every size there is.
			var lit := float(SHELF_CELL - PIP_GAP)
			for c in cw:
				_pips.append([Rect2(slot.position.x + float(c * SHELF_CELL),
					base + 3.0, lit, 3.0),
					ModuleData.rarity_colour(m2.rarity)])
			x += iw2 + step
	queue_redraw()


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
	icon.plate_scale = float(SHELF_CELL) / float(HoldGrid.CELL) * ModuleIcon.HOLD_K
	# On the authored rack a part STANDS on the board rather than sitting in a
	# box on it; its rarity goes on the light under it instead. See `_pips`.
	icon.bare = DB.station_sprite(&"shop", &"shelf2") != null
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
	# A BARE NUMBER. A paper tag on a shop shelf is a price without saying so,
	# and " CR" made every tag wider than the 1x part above it. The till still
	# says "236 CR", which is where the money actually moves.
	tag.text = "%d" % price
	# A PRICE YOU CANNOT PAY IS STILL THE PRICE. The card greys rather than
	# vanishing: what a thing costs is the reason you are not buying it, and a
	# shelf that went blank on the parts you cannot afford would be hiding its
	# own answer.
	tag.afford = Run.credits >= price
	var tw := tag.wants()
	tag.position = Vector2(floorf((iw - tw) * 0.5), ih + float(PLANK) + 1.0)
	tag.size = Vector2(tw, float(TAG_H))
	box.add_child(tag)
	return box


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 20.0 or h <= 20.0:
		return
	var art: Texture2D = _art2 if _boards.size() <= 2 else _art3
	if art != null:
		# Stood on the floor: anchored at the foot, so a unit given a few pixels
		# more than it needs keeps its plinth on the deck.
		draw_texture(art, Vector2(0.0, h - float(art.get_height())))
		for pip in _pips:
			var pr: Rect2 = pip[0]
			var pc: Color = pip[1]
			# A glow up the back panel behind the part, then the lit strip itself.
			for k in 4:
				draw_rect(Rect2(pr.position.x, pr.position.y - 4.0 - float(k) * 2.0,
					pr.size.x, 2.0), Color(pc.r, pc.g, pc.b, 0.10 - 0.022 * float(k)))
			draw_rect(pr, pc)
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
	## A PRICE STAMPED ON A CARD, in digits three pixels wide.
	##
	## A tag has to fit under its part, and a part on a 1x shelf can be one cell,
	## twenty pixels. The game's pixel font sets "236" wider than that, so the
	## digits are drawn here, 3x5 each with a pixel between: three digits in
	## fifteen, four in nineteen. It reads as a price gun's stamp, which is what a
	## shop tag is.
	const CARD := Color("#c2ae86")
	const CARD_DIM := Color("#6e6858")
	const INK := Color("#241d14")
	const INK_DIM := Color("#3f3a30")
	const STRING := Color("#8d7c5c")
	const GLYPHS := {
		"0": "111101101101111", "1": "010110010010111", "2": "111001111100111",
		"3": "111001111001111", "4": "101101111001001", "5": "111100111001111",
		"6": "111100111101111", "7": "111001001001001", "8": "111101111101111",
		"9": "111101111001111"}

	var text: String = ""
	var afford: bool = true

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## How wide a tag needs to be for a given number: four pixels a digit and a
	## one-pixel margin each side. STATIC, so the shelf can ask before it places.
	static func width_for(t: String) -> float:
		return float(t.length() * 4 + 1)

	func wants() -> float:
		return width_for(text)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		if w < 5.0 or h < 7.0:
			return
		var card := CARD if afford else CARD_DIM
		var ink := INK if afford else INK_DIM
		# The string up to the board's lip, and the shadow the card casts.
		draw_rect(Rect2(floorf(w * 0.5), -2.0, 1.0, 2.0), Color(STRING.r, STRING.g, STRING.b, 0.85))
		draw_rect(Rect2(1.0, 1.0, w, h), Color(0.03, 0.04, 0.06, 0.5))
		draw_rect(Rect2(0.0, 0.0, w, h), card)
		draw_rect(Rect2(0.0, 0.0, w, 1.0), card.lightened(0.3))
		var x := 1.0
		for ch in text:
			var g: String = GLYPHS.get(ch, "")
			for k in g.length():
				if g[k] == "1":
					draw_rect(Rect2(x + float(k % 3), 2.0 + float(k / 3), 1.0, 1.0), ink)
			x += 4.0
