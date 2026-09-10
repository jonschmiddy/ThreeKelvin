class_name PostingBoard
extends Control

## The Hiring Hall's board, with the work pinned to it.
##
## THE FURNITURE IS UNDER THE CONTENT, NOT BEHIND IT -- the same move the
## Promenade's shelf makes. A contract is not a row in a table; it is a notice
## somebody walked up and pinned there, and the difference between those two
## things is a frame, a pin and a shadow.
##
## It does not touch the rows. `_offer_row` and `_deliver_row` build exactly what
## they built before; this measures itself off them and draws the board they are
## pinned to, which is why a contract being taken or a row growing a line does
## not need this to know anything.
##
## Drawn rather than loaded, like `YardScene`, `StationSpine` and `ShelfDisplay`:
## placeholder and fallback in one. Art replaces the body of `_draw`.

## The list whose children are pinned to this. Read every redraw, never cached --
## the rows are rebuilt from scratch on every refresh of the deck.
var list: Container = null

const CORK := Color("#241c14")
const GRAIN := Color("#2d2317")
const FRAME := Color("#3a2c1c")
const LIP := Color("#54402a")
const SHADE := Color("#070a10")
const PIN := Color("#d4614f")
## How thick the board's own frame is.
const FRAME_W := 7.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func watch(l: Container) -> void:
	list = l
	if not l.sort_children.is_connected(queue_redraw):
		l.sort_children.connect(queue_redraw)
	if not l.resized.is_connected(queue_redraw):
		l.resized.connect(queue_redraw)


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 16.0 or h <= 16.0:
		return

	# --- THE CORK. Warm, and the only warm surface in the station that is not a
	# light -- which is the point: every other deck is painted metal, and the one
	# room with something soft in it is the one where people stand about reading.
	draw_rect(Rect2(0.0, 0.0, w, h), CORK)
	# Grain, as short marks at an irregular pitch. Regular would read as a
	# pattern; a board is a pressed mat and its texture has no beat.
	var gy := 5.0
	var step := 0
	while gy < h - 3.0:
		var gx := 8.0 + float((step * 37) % 23)
		while gx < w - 8.0:
			draw_rect(Rect2(gx, gy, 3.0, 1.0), GRAIN)
			gx += 17.0 + float((step * 11) % 9)
		gy += 6.0
		step += 1

	# --- THE FRAME AROUND IT, and a lit top edge so it reads as a thing hung on
	# a wall rather than as a coloured rectangle.
	draw_rect(Rect2(0.0, 0.0, w, FRAME_W), FRAME)
	draw_rect(Rect2(0.0, h - FRAME_W, w, FRAME_W), FRAME)
	draw_rect(Rect2(0.0, 0.0, FRAME_W, h), FRAME)
	draw_rect(Rect2(w - FRAME_W, 0.0, FRAME_W, h), FRAME)
	draw_rect(Rect2(0.0, 0.0, w, 1.0), LIP)
	draw_rect(Rect2(0.0, FRAME_W, w, 1.0), Color(SHADE.r, SHADE.g, SHADE.b, 0.55))
	draw_rect(Rect2(0.0, h - FRAME_W, w, 1.0), LIP)

	# --- AND A PIN THROUGH EVERY NOTICE.
	#
	# `sort_children` has fired by now, so these are the real rects. The pin goes
	# at the top LEFT rather than the middle: a notice pinned once hangs slightly,
	# and the corner is where somebody standing at a board actually puts it.
	if list == null:
		return
	for child in list.get_children():
		var c := child as Control
		if c == null or not c.visible:
			continue
		var at := Vector2(c.position.x + list.position.x - position.x,
			c.position.y + list.position.y - position.y)
		# The shadow the paper casts on the cork, down and right, so the notice
		# is ON the board rather than printed into it.
		draw_rect(Rect2(at.x + 2.0, at.y + c.size.y, c.size.x, 2.0),
			Color(SHADE.r, SHADE.g, SHADE.b, 0.45))
		draw_rect(Rect2(at.x + c.size.x, at.y + 2.0, 2.0, c.size.y),
			Color(SHADE.r, SHADE.g, SHADE.b, 0.45))
		# The pin: a head with a highlight, and a shadow under it.
		var px := at.x + 9.0
		var py := at.y - 2.0
		draw_rect(Rect2(px + 1.0, py + 1.0, 5.0, 5.0),
			Color(SHADE.r, SHADE.g, SHADE.b, 0.6))
		draw_rect(Rect2(px, py, 5.0, 5.0), PIN)
		draw_rect(Rect2(px, py, 2.0, 2.0), PIN.lightened(0.45))
