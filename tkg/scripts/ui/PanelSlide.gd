class_name PanelSlide
extends Node

## The real control slides, drawn whole (Jon, Oct 18), never a picture or an empty plate.
## It stays in its container; the slide offset is re-applied on every layout.
## Why: docs/why/PanelSlide.md#panel-slide

## every slide under way (the harness reads them)
static var live: Array = []

var target: Control = null
## &"side" (off to the right), &"band" (up) or &"foot" (down: a bottom band, `for_foot`)
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


## A screen's bottom band (`ladder_foot`: the KEY band, LOCAL's strip), or null.
static func foot_of(s: Control) -> Control:
	return s.call(&"ladder_foot") as Control if s != null and is_instance_valid(s) and s.has_method(&"ladder_foot") else null


## `s`'s bottom band sliding down off the content rect `c` (Jon, Nov 11), started on or off, or null.
static func for_foot(parent: Node, s: Control, c: Rect2, on: bool) -> PanelSlide:
	var ft := foot_of(s)
	if ft == null or not is_instance_valid(ft) or ft.size.y <= 2.0:
		return null
	var pf := PanelSlide.new()
	parent.add_child(pf)
	pf.setup(ft, &"foot", Vector2(0.0, c.end.y - ft.get_global_rect().position.y + 2.0), 0.0 if on else 1.0, s)
	return pf


## What hides `s`'s bottom band until it slides on: the band, or for a drawer in a clipping
## holder (LOCAL's strip) the holder, so nothing of it reads as there while the camera moves.
static func veil_of(s: Control) -> Control:
	var ft := foot_of(s)
	var hp := ft.get_parent() as Control if ft != null and is_instance_valid(ft) else null
	return hp if hp != null and hp.clip_contents and not (hp is Container) else ft
