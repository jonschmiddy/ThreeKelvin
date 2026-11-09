class_name TradeCounter
extends Control

## Dragging is the confirmation, so the counter needs no button; places replace per-row buttons.
## Why: docs/why/TradeCounter.md#counter-design

## What was carried here. The screen decides what that means -- this only knows
## that something was put down on it.
signal took(item: HoldItem)

## Two sides of one market, not the old scrap chute: `Market.bid` always stays under `Market.ask`.
## Why: docs/why/TradeCounter.md#counter-sides
enum Side { PAYS, CHARGES }
var side: int = Side.PAYS

## Named so a rename in `ShelfDisplay` or `_accepts` cannot silently charge for owned parts.
## Why: docs/why/TradeCounter.md#shelf-origin
const FROM_SHELF := &"shelf"

const TOP := Color("#2f4054")
const FACE := Color("#1d2836")
const EDGE := Color("#4a6180")
const LIP := Color("#647e9d")
const GLASS := Color("#0d1a20")
const SHADE := Color("#070a10")
const LIVE := UITheme.GOOD
## Darker than the counter's face, so the counter reads as standing in front of something.
const WALL := Color("#111925")
const WALL_LINE := Color("#202c3c")
## What the counter has already taken today, stacked behind it. Lighter than the
## wall, because furniture in front of a surface has to out-read the surface.
const CRATE := Color("#26344a")
const CRATE_LIP := Color("#3d5271")

## How deep the counter's top surface looks from the front.
const TOP_H := 11.0
## Fixed height, not a fraction: a scaled desk grew waist-high at three hundred pixels.
## Why: docs/why/TradeCounter.md#desk-size
const DESK_H := 96.0

## Art is authored with its desk top `DESK_H` above its foot and its props standing above that.
## Why: docs/why/TradeCounter.md#counter-art
var art: Texture2D = null
## A level counter takes the drop as a whole and carries its own register.
var fitted := false
## The quote and the lit edge are drawn over the room's light instead of here.
## See `draw_lit_marks`.
var lit_elsewhere := false
var _over: HoldItem = null
var _why: String = ""

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


## Static and public so screens quote the same number; a price belongs to the place.
## Why: docs/why/TradeCounter.md#pricing
static func offer(m: HoldItem, at: int = Side.PAYS) -> int:
	if m == null:
		return 0
	var n: MapGen.MapNode = Run.node_at()
	# Crates and parts are priced by different tables, both in credits.
	var mat := m as MaterialData
	if mat != null:
		return Market.material_price(n, mat.id)
	var mod := m as ModuleData
	if mod == null:
		return 0
	return Market.ask(n, mod) if at == Side.CHARGES else Market.bid(n, mod)


## Refusals are spoken: a silent till looks broken, and each case is something the player can fix.
## Why: docs/why/TradeCounter.md#refusal
static func refusal(at: int, m: HoldItem) -> String:
	var price := offer(m, at)
	if at == Side.CHARGES:
		if price <= 0:
			return "NOT FOR SALE"
		if Run.credits < price:
			return "NEED %d MORE" % (price - Run.credits)
		# Room is for the whole part: `hold_full` checks one cell, so a 2x2 was paid for then lost.
		# Why: docs/why/TradeCounter.md#refusal
		if not Run.has_room_for(m):
			return "NO ROOM"
		return ""
	# Zero on the paying side is contraband in policed space, which the Exchange
	# already explains in its own note.
	return "WILL NOT BUY" if price <= 0 else ""


## A wrong origin is a money bug: a till buys from the shelf, never charges for owned parts.
## Why: docs/why/TradeCounter.md#drop-origin
func _accepts(from: StringName) -> bool:
	return from == FROM_SHELF if side == Side.CHARGES else from != FROM_SHELF


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY or not (data as Dictionary).has("module"):
		return false
	var m: HoldItem = (data as Dictionary).module
	if m == null:
		return false
	# On the counter, not anywhere in the room, or a far-wall drop would sell something.
	if _at.y < _desk_top():
		_clear()
		return false
	if not _accepts(StringName((data as Dictionary).get("origin", &""))):
		_clear()
		return false
	# The price is quoted while the thing is still in your hand, so you can decline.
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
	if fitted:
		return 0.0
	return maxf(0.0, size.y - DESK_H)


func _notification(what: int) -> void:
	# Cleared on exit and on any drag end, or a stale quote stays for a thing no longer moving.
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

	if fitted:
		if art != null:
			draw_texture(art, Vector2.ZERO)
		if not lit_elsewhere:
			_paint_quote(self, Vector2.ZERO)
		return
	if art != null:
		_draw_art(w, dy, carrying, ok)
		return

	# The counter is not the whole control: given no height it is just the desk.
	# Why: docs/why/TradeCounter.md#drawn-counter
	if dy > 40.0:
		draw_rect(Rect2(0.0, 0.0, w, dy), WALL)
		# Panel joints across it and studs down it. A blank wall reads as a hole
		# in the deck rather than as the back of a room.
		var jy := 26.0
		while jy < dy - 6.0:
			draw_rect(Rect2(0.0, jy, w, 1.0), WALL_LINE)
			draw_rect(Rect2(0.0, jy + 1.0, w, 1.0),
				Color(SHADE, 0.4))
			jy += 34.0
		var jx := 46.0
		while jx < w - 20.0:
			draw_rect(Rect2(jx, 0.0, 2.0, dy), WALL_LINE)
			jx += 92.0
		draw_rect(Rect2(0.0, 0.0, w, 1.0), Color(SHADE, 0.6))

		# Taken stock stacks behind the desk, so it reads as in front and the station keeps things.
		# Why: docs/why/TradeCounter.md#drawn-counter
		for r in [Rect2(w - 74.0, dy - 44.0, 30.0, 44.0),
				Rect2(w - 42.0, dy - 30.0, 26.0, 30.0),
				Rect2(w - 70.0, dy - 66.0, 22.0, 22.0)]:
			var box: Rect2 = r
			if box.position.x < 8.0 or box.position.y < 4.0:
				continue
			draw_rect(box, CRATE)
			draw_rect(Rect2(box.position.x, box.position.y, box.size.x, 1.0), CRATE_LIP)
			draw_rect(Rect2(box.position.x, box.position.y, 1.0, box.size.y),
				Color(CRATE_LIP, 0.5))
			# A band round the middle, so a crate is a crate and not a swatch.
			draw_rect(Rect2(box.position.x, box.position.y + box.size.y * 0.45,
				box.size.x, 2.0), Color(SHADE, 0.5))

	# A lit top lip makes a slab a surface, the same trick as the shelf's boards.
	draw_rect(Rect2(0.0, dy + TOP_H, w, h - dy - TOP_H), FACE)
	draw_rect(Rect2(0.0, dy, w, TOP_H), TOP)
	draw_rect(Rect2(0.0, dy, w, 1.0), LIP)
	draw_rect(Rect2(0.0, dy + TOP_H - 1.0, w, 1.0),
		Color(SHADE, 0.75))
	# Panel seams down the front, so the counter has a width you can read.
	var sx := 22.0
	while sx < w - 12.0:
		draw_rect(Rect2(sx, dy + TOP_H + 4.0, 1.0, h - dy - TOP_H - 8.0),
			Color(SHADE, 0.5))
		sx += 34.0

	# The display sits on the desk and shows a number: a glow gives you nothing to decline.
	# Why: docs/why/TradeCounter.md#drawn-counter
	var bw := minf(w - 40.0, 132.0)
	var win := Rect2((w - bw) * 0.5, dy + TOP_H + 8.0, bw, 22.0)
	if win.end.y < h - 5.0 and bw > 40.0:
		draw_rect(win, GLASS)
		draw_rect(win, EDGE, false, 1.0)
		draw_rect(Rect2(win.position.x, win.position.y, win.size.x, 1.0),
			Color(SHADE, 0.7))
		var f := UITheme.pixel_font()
		var text := "- - -"
		var ink := Color(EDGE, 0.55)
		if carrying:
			text = "%d CR" % offer(_over, side) if ok else _why
			ink = LIVE if ok else UITheme.LEAVE
		var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			UITheme.FS_SMALL).x
		draw_string(f, Vector2(win.position.x + (win.size.x - tw) * 0.5,
			win.position.y + 15.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			UITheme.FS_SMALL, ink)

	# Keypad or scale pan is all that says which way the money goes; on the face, not the top.
	# Why: docs/why/TradeCounter.md#drawn-counter
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
						Color(EDGE, 0.55))
		# And the slot the chit comes out of, with a lip under it.
		var rx := win.end.x + 10.0
		if rx + 34.0 < w - 6.0:
			draw_rect(Rect2(rx, win.position.y + 4.0, 34.0, 3.0), SHADE)
			draw_rect(Rect2(rx, win.position.y + 7.0, 34.0, 1.0), LIP)

	# The scale says trading, not storing; it stands on the desk with the pan above the surface.
	# Why: docs/why/TradeCounter.md#drawn-counter
	var cx := w * 0.5
	var pan := dy - 30.0
	if side == Side.PAYS and pan > 2.0:
		draw_rect(Rect2(cx - 2.0, pan, 4.0, dy - pan + 2.0), TOP)
		draw_rect(Rect2(cx - 26.0, pan, 52.0, 4.0), TOP)
		draw_rect(Rect2(cx - 26.0, pan, 52.0, 1.0), LIP)
		draw_rect(Rect2(cx - 16.0, dy - 3.0, 32.0, 3.0), TOP)

	# The lit edge is the hit box; an edge, not a wash, so the held object stays visible.
	# Why: docs/why/TradeCounter.md#drawn-counter
	if carrying:
		var ink2 := LIVE if ok else UITheme.LEAVE
		draw_rect(Rect2(0.0, dy, w, 2.0), ink2)
		draw_rect(Rect2(0.0, h - 2.0, w, 2.0), ink2)
		draw_rect(Rect2(0.0, dy, 2.0, h - dy), ink2)
		draw_rect(Rect2(w - 2.0, dy, 2.0, h - dy), ink2)


## The authored counter, with only the live parts drawn over it: the price on
## its screen, and the lit edge when something is held over the desk.
func _draw_art(w: float, dy: float, carrying: bool, ok: bool) -> void:
	var aw := float(art.get_width())
	var ax := floorf((w - aw) * 0.5)
	draw_texture(art, Vector2(ax, dy - (float(art.get_height()) - DESK_H)))
	# The art's screen is where this window always was: 132 wide, centred, 19
	# below the desk top. The art is drawn to it, not the other way round.
	var bw := minf(aw - 40.0, 132.0)
	var win := Rect2(ax + (aw - bw) * 0.5, dy + TOP_H + 8.0, bw, 22.0)
	var f := UITheme.pixel_font()
	var text := "- - -"
	var ink := Color(0.44, 0.83, 0.88, 0.45)
	if carrying:
		text = "%d CR" % offer(_over, side) if ok else _why
		ink = LIVE if ok else UITheme.LEAVE
	var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		UITheme.FS_SMALL).x
	draw_string(f, Vector2(win.position.x + (win.size.x - tw) * 0.5,
		win.position.y + 15.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		UITheme.FS_SMALL, ink)
	if carrying:
		var desk := Rect2(ax, dy, aw, DESK_H)
		var ink2 := LIVE if ok else UITheme.LEAVE
		draw_rect(Rect2(desk.position.x, desk.position.y, desk.size.x, 2.0), ink2)
		draw_rect(Rect2(desk.position.x, desk.end.y - 2.0, desk.size.x, 2.0), ink2)
		draw_rect(Rect2(desk.position.x, desk.position.y, 2.0, desk.size.y), ink2)
		draw_rect(Rect2(desk.end.x - 2.0, desk.position.y, 2.0, desk.size.y), ink2)


## While something is held over it: the price on a small screen, edge green for yes, red for no.
func _paint_quote(c: CanvasItem, at: Vector2) -> void:
	if _over == null:
		return
	var ok := _why == ""
	var ink := LIVE if ok else UITheme.LEAVE
	var f := UITheme.pixel_font()
	var text := "%d CR" % offer(_over, side) if ok else _why
	var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x
	var box := Rect2(at + Vector2(floorf((size.x - tw) * 0.5) - 6.0, floorf(size.y * 0.55) - 11.0),
		Vector2(tw + 12.0, 22.0))
	c.draw_rect(box, GLASS)
	c.draw_rect(box, EDGE, false, 1.0)
	c.draw_string(f, box.position + Vector2(6.0, 15.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		UITheme.FS_SMALL, ink)
	var r := Rect2(at, size)
	c.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 2.0), ink)
	c.draw_rect(Rect2(r.position.x, r.end.y - 2.0, r.size.x, 2.0), ink)
	c.draw_rect(Rect2(r.position.x, r.position.y, 2.0, r.size.y), ink)
	c.draw_rect(Rect2(r.end.x - 2.0, r.position.y, 2.0, r.size.y), ink)


## The quote, onto the layer over the room's light, where this counter stands.
func draw_lit_marks(c: CanvasItem) -> void:
	if fitted and is_visible_in_tree():
		_paint_quote(c, position)


## What the counter is currently quoting, for the screen's own readout. -1 when
## nothing is being carried over it.
func quote() -> int:
	return offer(_over, side) if _over != null else -1
