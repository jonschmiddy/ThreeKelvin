class_name AimTarget
extends Control

## What a held card aims at: the corner brackets that light up and the number the card would
## give or take (kept as on main, Jon, Nov 9). EnemySlot and ShipSlot differ only in the box,
## the arm length and the colours.

var _hot: bool = false
var _drag_text: String = ""
## The one outline on this slot's art (C1): the wreck's hover, never the aim.
var mark: MarkOutline = null


## `set_drag_preview` hid the target under a 112x160 card; the aimed line keeps the board
## visible.
## Why: docs/why/AimTarget.md#aim-preview
func aim(on: bool, text: String = "") -> void:
	set_hot(on)
	var t := text if on else ""
	if t != _drag_text:
		_drag_text = t
		queue_redraw()


func set_hot(v: bool) -> void:
	if _hot == v:
		return
	_hot = v
	sync_mark()
	queue_redraw()


## Whether the outline should show now: never for the aim (that is the brackets); a slot says.
func mark_wanted() -> bool:
	return false


## The outline on or off as `mark_wanted` says.
func sync_mark() -> void:
	if mark == null or not is_instance_valid(mark):
		return
	var want := mark_wanted()
	if mark.visible != want:
		mark.visible = want
		mark.queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _hot:
		_hot = false
		sync_mark()
		queue_redraw()


## The hull's ink in this slot's coordinates; each slot says where its own is.
func ink_rect() -> Rect2:
	return Rect2(Vector2.ZERO, size)


## Where the held card's number is drawn, its letters' own box, in this slot's
## coordinates (`HitText.ink_rect`). For the test that holds it to the ink.
func preview_rect(text: String) -> Rect2:
	return HitText.ink_rect(HitText.centred_at(ink_rect().get_center(), text), text)


## Corner brackets round `box`, `arm` long, drawn on `ci` from inside its `_draw`.
static func draw_brackets(ci: CanvasItem, box: Rect2, arm: float, col: Color) -> void:
	for corner in [
			[box.position, Vector2(1, 1)],
			[Vector2(box.end.x, box.position.y), Vector2(-1, 1)],
			[Vector2(box.position.x, box.end.y), Vector2(1, -1)],
			[box.end, Vector2(-1, -1)]]:
		var o: Vector2 = corner[0]
		var d: Vector2 = corner[1]
		ci.draw_rect(Rect2(o + Vector2(0, -1 if d.y < 0 else 0), Vector2(arm * d.x, 1)), col, true)
		ci.draw_rect(Rect2(o + Vector2(-1 if d.x < 0 else 0, 0), Vector2(1, arm * d.y)), col, true)
