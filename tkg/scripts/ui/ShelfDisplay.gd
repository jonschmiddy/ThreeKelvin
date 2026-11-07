class_name ShelfDisplay
extends Control

## The stock is objects at their own size, not a table; hover reuses the real `ModuleIcon`.
## Why: docs/why/ShelfDisplay.md#shelf-design

## Nothing on a shelf is a button: a one-click 300 credit buy is gone, and the till buys.
## Why: docs/why/ShelfDisplay.md#no-buy-signal

## Cell was the hold's 40 so a part matches its bay; 26 read as a list of thumbnails.
## Why: docs/why/ShelfDisplay.md#cell-size
const CELL := HoldGrid.CELL
## Reversed: Jon kept the sprite's own 1x at 20 a cell, seen at both sizes on the rack.
## Why: docs/why/ShelfDisplay.md#cell-size
const SHELF_CELL := 20
## Air above a board's items, so nothing touches the shelf above it.
const HEAD := 7
## How thick a board is, and the frame around the whole unit.
const PLANK := 5
## The upright is furniture, not shelf: 13 plus 7 of air spent 40 of 132 px; 8 and 4 gives 116.
## Why: docs/why/ShelfDisplay.md#rack-frame
const POST_W := 8
const CAP_H := 9
const PLINTH_H := 11
## Where the price ticket sits on the board's front lip.
const TICKET_H := 5
## How tall a price tag is. Enough for an 8px face with a punched hole beside it.
const TAG_H := 9
## Air between two things standing side by side on the same board.
const GAP := 10.0
## Board pitch is fixed from the tallest part, so boards do not move for small stock.
## Why: docs/why/ShelfDisplay.md#rack-frame
const PITCH := SHELF_CELL * 2 + PLANK + TICKET_H + HEAD + 6

## A piece of furniture, not a wall: three boards, as nine made a warehouse aisle.
## Why: docs/why/ShelfDisplay.md#rack-size
const BOARDS := 3
## Each board is a 4 x 2 strip of cells (Jon's spec); parts snap to columns, never stacked.
const SHELF_COLS := 4
## A fixed 4 px of air packed from the left post: flush was one lump, even spread marooned parts.
const PART_GAP := 4
## Air inside each post. See POST_W: it came down with the upright.
const SHELF_PAD := 4
## The pip gap is 2, which is one at game scale; not the art's own bay pitch.
## Why: docs/why/ShelfDisplay.md#rack-frame
const PIP_GAP := 2
## The board's usable width: six cells and the five gaps a full board needs.
const SHELF_INNER := SHELF_COLS * SHELF_CELL + (SHELF_COLS - 1) * PART_GAP
const RACK_W := SHELF_INNER + POST_W * 2 + SHELF_PAD * 2

## The height that many boards need. Derived rather than typed, so the unit and
## the boards inside it can never disagree about how tall it is.
static func rack_height(boards: int = BOARDS) -> float:
	return float(CAP_H + 6 + PITCH * boards + PLINTH_H)


## Two or three boards tall; a hub gets the tall rack, asked of `_pack` so they cannot disagree.
## Why: docs/why/ShelfDisplay.md#rack-size
static func boards_for(rows: Array) -> int:
	return 2 if _pack(rows, 2)[1] == 0 else BOARDS


## Whether these parts all stand on `count` boards, packed the way `stock`
## packs them. What the shop's stock roll asks before it takes a part.
static func stands_on(mods: Array, count: int) -> bool:
	var rows: Array = []
	for m in mods:
		rows.append({thing = m})
	return _pack(rows, count)[1] == 0


## Widest first onto the board with most room, so rails are not stranded and stock spreads.
## Why: docs/why/ShelfDisplay.md#packing
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

## A shop room can bring its own rack art and board rows; pixel-doubled together.
## Why: docs/why/ShelfDisplay.md#room-rack
var art_override: Texture2D = null
var board_rows: Array = []
## THE MARKS ARE DRAWN OVER THE ROOM'S LIGHT instead of here: the rarity lights
## and the price tags. See `ShopLight.Glow` and `draw_lit_marks`.
var lit_elsewhere := false
## Each price tag's top-left, number and whether it is affordable, for
## `draw_lit_marks`.
var _tags: Array = []
## One light per part in its rarity colour: a shop lights its better stock.
var _pips: Array = []

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Resolved outside `_draw`, deferred: a texture first touched in a draw renders white for good.
## Why: docs/why/ShelfDisplay.md#rack-art
var _art2: Texture2D = null
var _art3: Texture2D = null


func _ready() -> void:
	_load_art.call_deferred()


func _load_art() -> void:
	_art2 = DB.station_sprite(&"shop", &"shelf2")
	_art3 = DB.station_sprite(&"shop", &"shelf3")
	queue_redraw()


## Laid out left to right and wrapped to the next board when a part will not fit.
func stock(rows: Array) -> void:
	Widgets.clear(self)
	_boards.clear()
	_pips.clear()
	_tags.clear()
	var w := size.x
	var h := size.y
	if w <= 40.0 or h <= 40.0:
		# No layout yet. `_refresh_stock` calls again on `resized`, and doing the
		# arithmetic against a width of zero would put everything on one board.
		return

	# Fixed pitch filled from the top: empty boards say an outpost is a shop with two parts.
	# Why: docs/why/ShelfDisplay.md#rack-size
	var usable := h - float(CAP_H + 6 + PLINTH_H)
	# Capped at `BOARDS` so a taller deck makes a taller room; a squeezed unit loses boards.
	var count := clampi(int(usable / float(PITCH)), 1, BOARDS)
	if not board_rows.is_empty():
		# A ROOM'S RACK HAS THE BOARDS IT WAS DRAWN WITH, and exactly that many.
		count = board_rows.size()
		for by in board_rows:
			_boards.append(float(by))
	else:
		for i in count:
			_boards.append(float(CAP_H + 6) + float(PITCH) * float(i + 1)
				- float(PLANK + TICKET_H + HEAD) - 2.0)

	# Wrapped first, placed second so bottoms align; spread so the top shelf is not full.
	# Why: docs/why/ShelfDisplay.md#packing
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
			for kid in slot.get_children():
				if kid is PriceTag:
					var tg: PriceTag = kid
					_tags.append([slot.position + tg.position, tg.text, tg.afford])
					tg.visible = not lit_elsewhere
			# One lit segment per cell so the strip counts, in whole pixels, not width over cells.
			# Why: docs/why/ShelfDisplay.md#light-strip
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

	# The real `ModuleIcon` brings plate, stripe, rarity ground, silhouette and tooltip for free.
	var icon := ModuleIcon.new()
	# Stamped with its origin; only the till accepts it. See `TradeCounter.FROM_SHELF`.
	icon.setup(m, TradeCounter.FROM_SHELF)
	icon.custom_minimum_size = Vector2.ZERO
	icon.position = Vector2.ZERO
	icon.size = Vector2(iw, ih)
	icon.plate_scale = float(SHELF_CELL) / float(HoldGrid.CELL) * ModuleIcon.HOLD_K
	# On the authored rack a part STANDS on the board rather than sitting in a
	# box on it; its rarity goes on the light under it instead. See `_pips`.
	icon.bare = DB.station_sprite(&"shop", &"shelf2") != null
	box.add_child(icon)

	# The price sits under its item as a tag, not a button; `stock` reserves room for the overhang.
	# Why: docs/why/ShelfDisplay.md#price-tags
	var price := int(entry.price)
	var tag := PriceTag.new()
	# A bare number: ' CR' made every tag wider than the 1x part above it.
	tag.text = "%d" % price
	# An unaffordable price greys but stays: a blank shelf would hide the reason.
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
	if art_override != null:
		# A room's rack as the bench draws it: the art plus one lit block per cell, no back glow.
		draw_texture(art_override, Vector2(0.0, h - float(art_override.get_height())))
		if not lit_elsewhere:
			for pip in _pips:
				draw_rect(pip[0], pip[1])
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

	# Uprights drilled the whole way down: empty holes say the rack could hold more.
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
		# Stepped brackets of three rects: a diagonal cannot be trusted to hit the pixel grid.
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


## The rarity lights and price tags, drawn onto another layer -- the one over
## the room's light -- exactly where this rack would draw them.
func draw_lit_marks(c: CanvasItem) -> void:
	if not is_visible_in_tree():
		return
	c.draw_set_transform(position, rotation, scale)
	for pip in _pips:
		c.draw_rect(pip[0], pip[1])
	for t in _tags:
		PriceTag.paint(c, t[0], t[1], t[2], float(TAG_H))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The tag is a card on a string, not a label, and the deck's only warm surface.
## Why: docs/why/ShelfDisplay.md#price-tags
class PriceTag extends Control:
	## Digits are drawn 3x5 here, as the pixel font sets '236' wider than a one-cell part.
	## Why: docs/why/ShelfDisplay.md#price-tags
	const CARD := Color("#c2ae86")
	const CARD_DIM := Color("#6e6858")
	const INK := Color("#241d14")
	const INK_DIM := Color("#3f3a30")
	const STRING := Color("#8d7c5c")
	## The card's lit top edge and its shadow, as the bench's `stamp` has them.
	const LIP := Color("#dccaa3")
	const SHADOW := Color(8.0 / 255.0, 10.0 / 255.0, 14.0 / 255.0, 0.5)
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
		paint(self, Vector2.ZERO, text, afford, size.y)

	## A tag at `at`, onto any canvas: this one's own, or the layer the shop
	## draws its marks on over the light. Drawn as the bench's `stamp` draws it.
	static func paint(ci: CanvasItem, at: Vector2, t: String, can: bool, h: float) -> void:
		var w := width_for(t)
		if w < 5.0 or h < 7.0:
			return
		var card := CARD if can else CARD_DIM
		var ink := INK if can else INK_DIM
		# The string up to the board's lip, and the shadow the card casts.
		ci.draw_rect(Rect2(at + Vector2(floorf(w * 0.5), -2.0), Vector2(1.0, 2.0)),
			Color(STRING.r, STRING.g, STRING.b, 0.85))
		ci.draw_rect(Rect2(at + Vector2(1.0, 1.0), Vector2(w, h)), SHADOW)
		ci.draw_rect(Rect2(at, Vector2(w, h)), card)
		ci.draw_rect(Rect2(at, Vector2(w, 1.0)), LIP if can else card.lightened(0.3))
		var x := 1.0
		for ch in t:
			var g: String = GLYPHS.get(ch, "")
			for k in g.length():
				if g[k] == "1":
					ci.draw_rect(Rect2(at + Vector2(x + float(k % 3), 2.0 + float(k / 3)),
						Vector2.ONE), ink)
			x += 4.0
