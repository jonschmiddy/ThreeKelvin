class_name PanelSlide
extends Node

## The real control slides, drawn whole (Jon, Oct 18), never a picture or an empty plate.
## It stays in its container; the slide offset is re-applied on every layout.
## Why: docs/why/PanelSlide.md#panel-slide

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
## Heard once as it first moves, for the side panel only;
## the toolbar row moves under the same one sound.
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
