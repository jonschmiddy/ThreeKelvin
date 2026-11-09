class_name AimTarget
extends Control

## What a held card aims at: the one outline (`MarkOutline`) on the hull it would hit, and
## the number the card would give or take. EnemySlot and ShipSlot differ only in the art
## the outline follows and the number's colour.

var _hot: bool = false
var _drag_text: String = ""
## The outline on this slot's art, built by the slot once it has the art.
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


## Whether the outline should show now: aimed at, or whatever else the slot says.
func mark_wanted() -> bool:
	return _hot


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
