class_name JettisonBin
extends Control

## Right-click needs telling about; a hatch beside the hold draws the instruction instead.
## Items land on the system's floor, recoverable from SECTOR LOOT for the rest of the run.
## Why: docs/why/JettisonBin.md#jettison-hatch

signal dumped(item: HoldItem)

## Square like its mark, 20 tall so the heading's label stays the tallest thing in the line.
const W := 20
const H := 20
## The bin when something it can take is over it.
const BIN_OVER := Color("#e0503c")

## Lit while something is being carried over it.
var _hot: bool = false
## Three states: always red shouts, and red beside an untouched hold reads as a warning.
## Why: docs/why/JettisonBin.md#hatch-states
var _armed: bool = false


func _init() -> void:
	custom_minimum_size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = Widgets.tip("JETTISON\n\nDrag something here to leave it in this system, under SECTOR LOOT, for the rest of the run.")


## The HoldItem inside a drag payload, or null for anything else. All three
## handlers unpack the same dictionary; the shape is decided once, here.
static func _held(data: Variant) -> HoldItem:
	if typeof(data) != TYPE_DICTIONARY or not (data as Dictionary).has("module"):
		return null
	return (data as Dictionary).module as HoldItem


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	var m := _held(data)
	# Only what you carry: taking a hull part off is the mount's decision, not the hatch's.
	var ok := m != null and Run.cargo.has(m)
	if ok != _hot:
		_hot = ok
		queue_redraw()
	return ok


func _drop_data(_at: Vector2, data: Variant) -> void:
	var m := _held(data)
	_hot = false
	queue_redraw()
	if m != null and Run.jettison(m):
		Audio.play(&"jettison", 0.06)
		dumped.emit(m)


func _notification(what: int) -> void:
	# `NOTIFICATION_DRAG_BEGIN` reaches every control, so this hears drags started elsewhere.
	if what == NOTIFICATION_DRAG_BEGIN:
		var m := _held(get_viewport().gui_get_drag_data())
		# Only hold items arm it, so carrying a hull part leaves it asleep rather than promising.
		_armed = m != null and Run.cargo.has(m)
		queue_redraw()
	elif what == NOTIFICATION_DRAG_END:
		_armed = false
		_hot = false
		queue_redraw()


func _draw() -> void:
	var edge := UITheme.TRACTOR if _hot else UITheme.LINE
	var box := Rect2(Vector2.ZERO, size)
	draw_rect(box, UITheme.VOID, true)

	# A red cross: the jaws read as a face and the arrow was a diagram. Nobody must read a cross.
	# Why: docs/why/JettisonBin.md#hatch-mark
	var pad := 5.0
	# Grey asleep, red when carrying something it can take, brighter when over it.
	var c := UITheme.LINE
	if _hot:
		c = BIN_OVER
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
