class_name TradeCounter
extends Control

## A counter you carry things to, and the money changes hands.
##
## DRAGGING IS THE CONFIRMATION, which is the whole reason this needs no button.
## The game already settled that argument once -- right-clicking to jettison was
## cut for being "the only destructive gesture in the game with no confirmation,
## no travel and no target", and the hatch beside the hold was fine because you
## have to CARRY something to it. A counter is the same rule applied to money:
## nobody sells a rare, or spends four hundred credits, by twitching.
##
## It also unties the knot a list of rows could not. Buying was a price you could
## click and selling was three buttons on every line -- install, sell, scrap --
## which is a spreadsheet. As PLACES they need no labels at all: the hardpoints
## are on the SHIP page, and this is the counter.
##
## TWO SIDES, ONE PIECE OF FURNITURE. See `Side`. The Promenade's till charges
## you and the Exchange's counter pays you, and they are the same desk seen from
## the two sides of it.
##
## Drawn rather than loaded, like the rest of the station's furniture.

## What was carried here. The screen decides what that means -- this only knows
## that something was put down on it.
signal took(item: HoldItem)

## Which way the money goes at this counter.
##
## THIS IS NOT THE SCRAP CHUTE COMING BACK. That was two prices for ONE object in
## ONE room: the counter's bid beside a flat melt rate, where the lower number
## existed only to be a second currency wearing a verb's clothes. These are the
## two SIDES of a single market -- `Market.ask` is what a shop charges and
## `Market.bid` is what it pays -- and `MarketTest` proves by exhaustion over
## every development, security, danger, rarity and manufacturer relationship that
## a bid is always under an ask. A spread you cannot farm is a market; a second
## rate for the same object in the same room is a currency.
enum Side { PAYS, CHARGES }
var side: int = Side.PAYS

## The `origin` a drag carries when the thing was lifted off a shop shelf.
##
## NAMED HERE BECAUSE THIS IS WHAT DEPENDS ON IT. `ShelfDisplay` stamps it and
## `_accepts` reads it, and while it was a bare "shelf" in both files a rename in
## either one would have gone through the parser without a word and come out as a
## till that charges you for parts already in your hold. It is a money bug with
## no error message, so it gets a name.
const FROM_SHELF := &"shelf"

const TOP := Color("#2f4054")
const FACE := Color("#1d2836")
const EDGE := Color("#4a6180")
const LIP := Color("#647e9d")
const GLASS := Color("#0d1a20")
const SHADE := Color("#070a10")
const LIVE := Color("#7fb89a")
## The room behind the desk. Darker than the counter's face, because the counter
## has to read as standing IN FRONT of something -- the furniture-brightness rule
## the spine's rooms and the shelf both had to learn the hard way.
const WALL := Color("#111925")
const WALL_LINE := Color("#202c3c")
## What the counter has already taken today, stacked behind it. Lighter than the
## wall, because furniture in front of a surface has to out-read the surface.
const CRATE := Color("#26344a")
const CRATE_LIP := Color("#3d5271")

## How deep the counter's top surface looks from the front.
const TOP_H := 11.0
## How tall the desk itself is, measured up from the deck.
##
## FIXED, NOT A FRACTION. This control fills whatever it is given so the room has
## depth, and an early version scaled the counter with it -- which drew a
## waist-high desk three hundred pixels tall and made the scale on it look like a
## lamppost. A counter is a counter however big the room is; the SPACE above it
## is what varies, and that space is the room. Below about forty pixels of slack
## there is no room to draw and this is simply a desk, which is what the
## Promenade wants: the shelf is already that deck's room.
const DESK_H := 96.0

## What is being carried over the desk right now, and why it is being refused.
## `_why` empty while something is over it means the counter will take it.
var _over: HoldItem = null
var _why: String = ""

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


## What one thing changes hands for at a counter of this side.
##
## STATIC AND PUBLIC so a screen can quote the same number in its own readouts
## without forming a second opinion about what a counter is worth. It reads
## `Run.node_at()` rather than taking a node, because a price is a property of
## the PLACE and there is only ever one place you are standing in.
static func offer(m: HoldItem, at: int = Side.PAYS) -> int:
	if m == null:
		return 0
	var n: MapGen.MapNode = Run.node_at()
	# A CRATE AND A PART ARE PRICED BY DIFFERENT TABLES. Materials have a flat
	# worth that development moves; a module is a bid or an ask against the local
	# market. Both come out in credits, which is the only currency there is.
	var mat := m as MaterialData
	if mat != null:
		return Market.material_price(n, mat.id)
	var mod := m as ModuleData
	if mod == null:
		return 0
	return Market.ask(n, mod) if at == Side.CHARGES else Market.bid(n, mod)


## Why this counter will not take the thing being carried over it. Empty when it
## will take it.
##
## SAID OUT LOUD RATHER THAN GONE QUIET. A till that simply refused a drop is a
## till that looks broken, and every case here is one the player can act on --
## "NEED 40 MORE" is a different instruction from "NO ROOM".
static func refusal(at: int, m: HoldItem) -> String:
	var price := offer(m, at)
	if at == Side.CHARGES:
		if price <= 0:
			return "NOT FOR SALE"
		if Run.credits < price:
			return "NEED %d MORE" % (price - Run.credits)
		if Run.hold_full():
			return "NO ROOM"
		return ""
	# Zero on the paying side is contraband in policed space, which the Exchange
	# already explains in its own note.
	return "WILL NOT BUY" if price <= 0 else ""


## Where a thing carried here is allowed to have come from.
##
## THE ORIGIN MATTERS, and getting it wrong would be a money bug rather than a
## layout one. A till buys FROM THE SHELF; dropping a part you already own onto
## it would otherwise charge you for something already in your hold. The
## Exchange's counter is the mirror -- it takes what you are carrying and not
## what is still standing on a shelf for sale.
func _accepts(from: StringName) -> bool:
	return from == FROM_SHELF if side == Side.CHARGES else from != FROM_SHELF


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY or not (data as Dictionary).has("module"):
		return false
	var m: HoldItem = (data as Dictionary).module
	if m == null:
		return false
	# ON THE COUNTER, not anywhere in the room. This control fills its column so
	# the deck has depth behind the desk, and a drop that landed on the far wall
	# and sold something would be the counter reaching across the room for it.
	if _at.y < _desk_top():
		_clear()
		return false
	if not _accepts(StringName((data as Dictionary).get("origin", &""))):
		_clear()
		return false
	# THE PRICE IS QUOTED WHILE THE THING IS STILL IN YOUR HAND. A counter that
	# only told you what it charged after it had charged it would be a counter
	# you could not decline.
	var was := _over
	var why := _why
	_over = m
	_why = refusal(side, m)
	if was != _over or why != _why:
		queue_redraw()
	return _why == ""


func _drop_data(_at: Vector2, data: Variant) -> void:
	var m: HoldItem = (data as Dictionary).module
	var ok := m != null and _at.y >= _desk_top() \
		and _accepts(StringName((data as Dictionary).get("origin", &""))) \
		and refusal(side, m) == ""
	_clear()
	if ok:
		took.emit(m)


## Where the desk's top surface is. Everything above it is the room.
func _desk_top() -> float:
	return maxf(0.0, size.y - DESK_H)


func _notification(what: int) -> void:
	# Godot has no "the drag left me", so the quote is cleared on the way out and
	# again when any drag anywhere ends -- without the second, a counter that was
	# dragged across and dropped elsewhere keeps quoting a price for a thing that
	# is no longer moving.
	if what == NOTIFICATION_MOUSE_EXIT or what == NOTIFICATION_DRAG_END:
		_clear()


func _clear() -> void:
	if _over == null and _why == "":
		return
	_over = null
	_why = ""
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 20.0 or h <= 30.0:
		return
	var dy := _desk_top()
	var carrying := _over != null
	var ok := carrying and _why == ""

	# --- THE ROOM BEHIND THE DESK, when there is room for one.
	#
	# THE COUNTER IS NOT THE WHOLE CONTROL. Given height it fills it, so that
	# side of the deck is a PLACE rather than a widget floating in a panel; given
	# none -- the Promenade, where the shelf is already the room -- it is just the
	# desk, and nothing below has to be told which case it is in.
	if dy > 40.0:
		draw_rect(Rect2(0.0, 0.0, w, dy), WALL)
		# Panel joints across it and studs down it. A blank wall reads as a hole
		# in the deck rather than as the back of a room.
		var jy := 26.0
		while jy < dy - 6.0:
			draw_rect(Rect2(0.0, jy, w, 1.0), WALL_LINE)
			draw_rect(Rect2(0.0, jy + 1.0, w, 1.0),
				Color(SHADE.r, SHADE.g, SHADE.b, 0.4))
			jy += 34.0
		var jx := 46.0
		while jx < w - 20.0:
			draw_rect(Rect2(jx, 0.0, 2.0, dy), WALL_LINE)
			jx += 92.0
		draw_rect(Rect2(0.0, 0.0, w, 1.0), Color(SHADE.r, SHADE.g, SHADE.b, 0.6))

		# --- AND WHAT IT HAS ALREADY TAKEN, stacked against the back wall.
		#
		# BEHIND the desk, so only the tops clear the counter -- which is what
		# makes the desk read as being in front of something rather than pasted
		# onto a backdrop. It is also the only thing on the deck that says the
		# station keeps what it handles: your hold empties and the stock goes
		# somewhere.
		for r in [Rect2(w - 74.0, dy - 44.0, 30.0, 44.0),
				Rect2(w - 42.0, dy - 30.0, 26.0, 30.0),
				Rect2(w - 70.0, dy - 66.0, 22.0, 22.0)]:
			var box: Rect2 = r
			if box.position.x < 8.0 or box.position.y < 4.0:
				continue
			draw_rect(box, CRATE)
			draw_rect(Rect2(box.position.x, box.position.y, box.size.x, 1.0), CRATE_LIP)
			draw_rect(Rect2(box.position.x, box.position.y, 1.0, box.size.y),
				Color(CRATE_LIP.r, CRATE_LIP.g, CRATE_LIP.b, 0.5))
			# A band round the middle, so a crate is a crate and not a swatch.
			draw_rect(Rect2(box.position.x, box.position.y + box.size.y * 0.45,
				box.size.x, 2.0), Color(SHADE.r, SHADE.g, SHADE.b, 0.5))

	# --- THE BODY, and a top surface seen almost edge-on.
	#
	# A LIT TOP LIP IS WHAT MAKES A SLAB A SURFACE. The same trick the shelf's
	# boards use: bright along the top, dark down the face, and the thing above
	# it stops floating.
	draw_rect(Rect2(0.0, dy + TOP_H, w, h - dy - TOP_H), FACE)
	draw_rect(Rect2(0.0, dy, w, TOP_H), TOP)
	draw_rect(Rect2(0.0, dy, w, 1.0), LIP)
	draw_rect(Rect2(0.0, dy + TOP_H - 1.0, w, 1.0),
		Color(SHADE.r, SHADE.g, SHADE.b, 0.75))
	# Panel seams down the front, so the counter has a width you can read.
	var sx := 22.0
	while sx < w - 12.0:
		draw_rect(Rect2(sx, dy + TOP_H + 4.0, 1.0, h - dy - TOP_H - 8.0),
			Color(SHADE.r, SHADE.g, SHADE.b, 0.5))
		sx += 34.0

	# --- THE TILL DISPLAY, set into the front of the desk and facing you.
	#
	# ON THE DESK RATHER THAN ON THE WALL, which is the one placement that works
	# at both sizes: the Promenade's counter has no wall to hang anything on. It
	# is also where a till's display actually is.
	#
	# THE QUOTE IS A NUMBER, NOT A GLOW. An earlier version lit a small green
	# window and left you to guess what the thing was worth, but the whole point
	# of quoting while it is still in your hand is that you can decline, and you
	# cannot decline an amount nobody has told you.
	var bw := minf(w - 40.0, 132.0)
	var win := Rect2((w - bw) * 0.5, dy + TOP_H + 8.0, bw, 22.0)
	if win.end.y < h - 5.0 and bw > 40.0:
		draw_rect(win, GLASS)
		draw_rect(win, EDGE, false, 1.0)
		draw_rect(Rect2(win.position.x, win.position.y, win.size.x, 1.0),
			Color(SHADE.r, SHADE.g, SHADE.b, 0.7))
		var f := UITheme.pixel_font()
		var text := "- - -"
		var ink := Color(EDGE.r, EDGE.g, EDGE.b, 0.55)
		if carrying:
			text = "%d CR" % offer(_over, side) if ok else _why
			ink = LIVE if ok else UITheme.LEAVE
		var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			UITheme.FS_SMALL).x
		draw_string(f, Vector2(win.position.x + (win.size.x - tw) * 0.5,
			win.position.y + 15.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			UITheme.FS_SMALL, ink)

	# --- THE HARDWARE EITHER SIDE OF THE DISPLAY, which is what tells the two
	# counters apart at a glance.
	#
	# A TILL HAS A KEYPAD AND A SCALE HAS A PAN. Both counters are the same desk
	# -- deliberately, because a station should do business one way -- so the
	# equipment bolted to them is the only thing that has to say which way the
	# money goes here. It sits on the FACE rather than standing on the top,
	# because the Promenade's counter is only as tall as a counter and has no
	# top surface inside its own box to stand anything on.
	if side == Side.CHARGES and win.end.y < h - 5.0:
		# The keypad: three rows of keys, sunk into the desk.
		var kx := win.position.x - 44.0
		if kx > 6.0:
			draw_rect(Rect2(kx, win.position.y, 36.0, 26.0), GLASS)
			draw_rect(Rect2(kx, win.position.y, 36.0, 26.0), EDGE, false, 1.0)
			for row in 3:
				for col in 3:
					draw_rect(Rect2(kx + 5.0 + float(col) * 9.0,
						win.position.y + 4.0 + float(row) * 7.0, 5.0, 4.0),
						Color(EDGE.r, EDGE.g, EDGE.b, 0.55))
		# And the slot the chit comes out of, with a lip under it.
		var rx := win.end.x + 10.0
		if rx + 34.0 < w - 6.0:
			draw_rect(Rect2(rx, win.position.y + 4.0, 34.0, 3.0), SHADE)
			draw_rect(Rect2(rx, win.position.y + 7.0, 34.0, 1.0), LIP)

	# --- THE SCALE, STANDING ON THE COUNTER.
	#
	# It is the one object that says TRADING rather than storing, which is the
	# whole difference between this and the shelf or the hold beside it. It sits
	# ON the desk and reaches UP, so the pan is above the surface -- which is
	# where you would actually put something down.
	var cx := w * 0.5
	var pan := dy - 30.0
	if side == Side.PAYS and pan > 2.0:
		draw_rect(Rect2(cx - 2.0, pan, 4.0, dy - pan + 2.0), TOP)
		draw_rect(Rect2(cx - 26.0, pan, 52.0, 4.0), TOP)
		draw_rect(Rect2(cx - 26.0, pan, 52.0, 1.0), LIP)
		draw_rect(Rect2(cx - 16.0, dy - 3.0, 32.0, 3.0), TOP)

	# --- AND THE DESK ANSWERS WHAT IS BEING HELD OVER IT.
	#
	# THE DESK AND NOT THE ROOM, which is also where the drop is accepted: the
	# lit edge is the hit box drawn. On the EDGE rather than as a wash, because a
	# fill would swallow the object you are holding over it and the object is the
	# thing you are deciding about. Red for a refusal rather than nothing at all,
	# so a counter that will not take something still looks like it noticed.
	if carrying:
		var ink2 := LIVE if ok else UITheme.LEAVE
		draw_rect(Rect2(0.0, dy, w, 2.0), ink2)
		draw_rect(Rect2(0.0, h - 2.0, w, 2.0), ink2)
		draw_rect(Rect2(0.0, dy, 2.0, h - dy), ink2)
		draw_rect(Rect2(w - 2.0, dy, 2.0, h - dy), ink2)


## What the counter is currently quoting, for the screen's own readout. -1 when
## nothing is being carried over it.
func quote() -> int:
	return offer(_over, side) if _over != null else -1
