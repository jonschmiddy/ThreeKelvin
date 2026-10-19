class_name PanelSlide
extends Node

## A SCREEN'S OWN PANEL SLIDING, drawn as it is (Jon, Oct 18: "the panels should
## be drawn in as they are coming into the frame, they come in blank now and
## that's not good looking"). The calm move (`ZoomLadder`) carries the map's or
## the chart's real side bar off to the right, or its toolbar row up, into
## LOCAL, and on again out of it, with everything on them -- the title, the
## text, the list, the buttons -- drawn the whole way: the control itself is
## moved, never a picture of it nor an empty plate. Over the field (`NavField`)
## it is glass sliding over the stars.
##
## The control stays in its container: its place at rest is the one the
## container gives it, and the slide's offset is put back on top of that every
## time the container lays its children out again, so a panel whose contents
## change as it moves still slides from where it will rest. The screen it is on
## clips it at its own edge while it moves.

## every slide under way (the harness reads them)
static var live: Array = []

var target: Control = null
## &"side" (off to the right) or &"band" (up)
var kind: StringName = &"side"
## where the container has it at rest (its parent's px) and how far away it is
## at k 0
var rest := Vector2.ZERO
var off := Vector2.ZERO
## 1 at rest, 0 all the way off
var k := 1.0
var done := false
## HEARD AS IT FIRST MOVES (`Audio.FX` chrome_on / chrome_off, Jon's picks:
## menu_open coming on, menu_close going off, -6 dB): the side panel only --
## the toolbar row's plate moves with it, under the same one sound -- once a
## hop, on the first frame it stands a whole pixel from where it started, as
## the column it took over from (`ChromeSlide`) was heard
var _k0 := 1.0
var _heard := false
var _host: Control = null
var _host_clip := false
var _parent: Control = null


func setup(t: Control, kind_: StringName, off_: Vector2, k0: float, host: Control) -> void:
	target = t
	kind = kind_
	rest = t.position
	off = off_
	_host = host
	if host != null and is_instance_valid(host):
		_host_clip = host.clip_contents
		host.clip_contents = true
	_parent = t.get_parent() as Control
	if _parent is Container and not (_parent as Container).sort_children.is_connected(_resorted):
		(_parent as Container).sort_children.connect(_resorted)
	live.append(self)
	_k0 = k0
	set_k(k0)


## (the container laid its children out again: that is the place at rest now)
func _resorted() -> void:
	if done or not is_instance_valid(target):
		return
	rest = target.position
	_apply()


func set_k(v: float) -> void:
	k = clampf(v, 0.0, 1.0)
	_apply()
	if not _heard and kind == &"side" and is_instance_valid(target) and target.position != rest + (off * (1.0 - _k0)).round():
		_heard = true
		Audio.fx(&"chrome_on" if _k0 < 0.5 else &"chrome_off")


func _apply() -> void:
	if is_instance_valid(target):
		target.position = rest + (off * (1.0 - k)).round()


## Where it is now (viewport px).
func at() -> Rect2:
	return target.get_global_rect() if is_instance_valid(target) else Rect2()


## Done: left where it is (at rest, or away on a screen about to go).
func finish() -> void:
	if done:
		return
	done = true
	live.erase(self)
	if _parent is Container and is_instance_valid(_parent) and (_parent as Container).sort_children.is_connected(_resorted):
		(_parent as Container).sort_children.disconnect(_resorted)
	if _host != null and is_instance_valid(_host):
		_host.clip_contents = _host_clip
	queue_free()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		live.erase(self)
