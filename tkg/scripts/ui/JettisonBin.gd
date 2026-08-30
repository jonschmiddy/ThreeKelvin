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
## recoverable from SECTOR LOOT for the rest of the run. A system is a place
## you can leave things; the price of coming back for one is the trip.

signal dumped(item: HoldItem)

## SQUARE, because the mark on it is, and small because it sits on a heading
## rather than under a grid. 20 is the row's own height: any taller and the
## label beside it stops being the tallest thing in the line, which is what
## makes a heading read as one.
const W := 20
const H := 20

## Lit while something is being carried over it.
var _hot: bool = false
## Awake while something of YOURS is in the air anywhere on screen.
##
## Three states rather than two, and the third is the one that was missing: a
## control that is always red is always shouting, and a red cross beside a hold
## you are not touching reads as a warning about the hold. Grey until there is
## something it could act on.
var _armed: bool = false


func _init() -> void:
	custom_minimum_size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = Widgets.tip("JETTISON\n\nDrag something here to put it down in this system. It stays there for the rest of the run -- fly back and take it from SECTOR LOOT whenever you want it.")


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
	# NOTIFICATION_DRAG_BEGIN reaches every control, which is exactly what this
	# needs: the drag starts on an icon somewhere else and this has to hear
	# about it without being under the cursor.
	if what == NOTIFICATION_DRAG_BEGIN:
		var carried: Variant = get_viewport().gui_get_drag_data()
		var m: HoldItem = null
		if typeof(carried) == TYPE_DICTIONARY 				and (carried as Dictionary).has("module"):
			m = (carried as Dictionary).module
		# Only what is in the HOLD. A part on the hull is not yours to drop from
		# here -- taking it off the ship is the mount's decision -- so carrying
		# one must leave this asleep rather than promising something it refuses.
		_armed = m != null and Run.cargo.has(m)
		queue_redraw()
	elif what == NOTIFICATION_DRAG_END:
		_armed = false
		_hot = false
		queue_redraw()


func _draw() -> void:
	var edge := UITheme.TRACTOR if _hot else UITheme.LINE
	var box := Rect2(Vector2.ZERO, size)
	draw_rect(box, Color(0.043, 0.055, 0.078, 1.0), true)

	# A SQUARE WITH A RED CROSS, and the plainness is the point.
	#
	# This has been a hatch with jaws (read as a face at 56px) and then a hatch
	# with an arrow through it (legible, and still a small diagram you had to
	# work out). A cross is the one mark nobody has to read -- it means the
	# thing under it stops -- and red is the only colour in this palette that
	# has never meant anything else.
	var pad := 5.0
	# ASLEEP, AWAKE, AIMED AT. Grey while nothing is in the air, the real red
	# once you are carrying something it can take, and brighter still when you
	# are over it -- so the mark answers before you have let go.
	var c := UITheme.LINE
	if _hot:
		c = Color("#e0503c")
	elif _armed:
		c = UITheme.LEAVE
	var span := size - Vector2(pad, pad) * 2.0
	var step := 2.0
	# Drawn as squares along both diagonals rather than as lines: a rotated
	# line anti-aliases, and nothing else on this screen has a soft edge.
	var n := int(minf(span.x, span.y) / step)
	for i in n + 1:
		var t := float(i) / float(maxi(1, n))
		var x := pad + span.x * t
		var y := pad + span.y * t
		draw_rect(Rect2(roundf(x) - 1.0, roundf(y) - 1.0, 2.0, 2.0), c, true)
		draw_rect(Rect2(roundf(x) - 1.0, roundf(size.y - y) - 1.0, 2.0, 2.0),
			c, true)

	draw_rect(box, edge, false, 2.0 if _hot else 1.0)
