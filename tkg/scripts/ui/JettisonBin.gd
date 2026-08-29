class_name JettisonBin
extends Control

## The hatch. Drag something onto it and it goes overboard.
##
## Right-clicking an item already does this and will keep working -- see
## `ItemIcon._gui_input` -- but a right-click is a thing you have to be told
## about, and nothing on the ship screen was telling you. A hatch beside the
## hold is the same instruction drawn instead of written.
##
## It puts things on the SYSTEM'S FLOOR, not into a wreck: this is the ship
## page, there is no container open, and `RunState.jettison` is exactly the
## "no screen open to say where you meant" case. What you drop here is
## recoverable from SECTOR LOOT until you jump, and gone after.

signal dumped(item: HoldItem)

## SQUARE, because the mark on it is. 56 is the hold's own cell and a half, so
## it sits under the grid as something the same kind of size as what goes in it.
const W := 56
const H := 56

## Lit while something is being carried over it.
var _hot: bool = false


func _init() -> void:
	custom_minimum_size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = Widgets.tip("JETTISON\n\nDrag something here to put it down in this system. It stays until you jump, and you can take it back from SECTOR LOOT.\n\nRight-clicking anything in your hold does the same.")


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY or not (data as Dictionary).has("module"):
		return false
	var m: HoldItem = (data as Dictionary).module
	# ONLY WHAT YOU ARE CARRYING. A part on the hull is not in the hold, and
	# dropping one here would have to take it off the ship first -- which is a
	# different decision and belongs to the mount it is bolted to.
	var ok := m != null and Run.cargo.has(m)
	if ok != _hot:
		_hot = ok
		queue_redraw()
	return ok


func _drop_data(_at: Vector2, data: Variant) -> void:
	var m: HoldItem = (data as Dictionary).module
	_hot = false
	queue_redraw()
	if m != null and Run.jettison(m):
		dumped.emit(m)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _hot:
		_hot = false
		queue_redraw()


func _draw() -> void:
	var edge := UITheme.TRACTOR if _hot else UITheme.LINE
	var ink := UITheme.EMBER if _hot else UITheme.COLD
	var box := Rect2(Vector2.ZERO, size)
	draw_rect(box, Color(0.043, 0.055, 0.078, 1.0), true)

	# A SQUARE WITH A RED CROSS, and the plainness is the point.
	#
	# This has been a hatch with jaws (read as a face at 56px) and then a hatch
	# with an arrow through it (legible, and still a small diagram you had to
	# work out). A cross is the one mark nobody has to read -- it means the
	# thing under it stops -- and red is the only colour in this palette that
	# has never meant anything else.
	var pad := 14.0
	var c := UITheme.LEAVE if not _hot else Color("#e0503c")
	var span := size - Vector2(pad, pad) * 2.0
	var step := 3.0
	# Drawn as squares along both diagonals rather than as lines: a rotated
	# line anti-aliases, and nothing else on this screen has a soft edge.
	var n := int(minf(span.x, span.y) / step)
	for i in n + 1:
		var t := float(i) / float(maxi(1, n))
		var x := pad + span.x * t
		var y := pad + span.y * t
		draw_rect(Rect2(roundf(x) - 1.5, roundf(y) - 1.5, 3.0, 3.0), c, true)
		draw_rect(Rect2(roundf(x) - 1.5, roundf(size.y - y) - 1.5, 3.0, 3.0),
			c, true)

	draw_rect(box, edge, false, 2.0 if _hot else 1.0)
