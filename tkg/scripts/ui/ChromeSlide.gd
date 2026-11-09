class_name ChromeSlide
extends Control

## Chrome is one solid piece sliding as LOCAL's camera lands, so LOCAL is never scaled.
## It takes clicks until gone: what is under it is about to be somewhere else.
## Why: docs/why/ChromeSlide.md#chrome-slide

static var live: Array = []

var kind: StringName = &"side"
var rest := Rect2()
var off := Vector2.ZERO
var clip := Rect2()
var tex: Texture2D = null
## (no picture) the panel's own plate, and where it stands at rest
var plate: StyleBox = null
var plate_rect := Rect2()
## 1 in place, 0 gone
var k := 1.0
var done := false
## Heard on the first whole pixel of motion, whoever drives it. The side bar's column only.
var _k0 := 1.0
var _heard := false


static func finish_all() -> void:
	for p: Variant in live.duplicate():
		if is_instance_valid(p):
			(p as ChromeSlide).finish()
	live.clear()


static func of_kind(kd: StringName) -> ChromeSlide:
	for p: Variant in live:
		if is_instance_valid(p) and not (p as ChromeSlide).done and (p as ChromeSlide).kind == kd:
			return p as ChromeSlide
	return null


func setup(kind_: StringName, rest_: Rect2, off_: Vector2, clip_: Rect2, k0: float) -> void:
	kind = kind_
	rest = rest_
	off = off_
	clip = clip_
	k = k0
	_k0 = k0
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	# (over the held picture and over the dip to black of a dive)
	z_index = 1
	_body = _Body.new()
	_body.piece = self
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_body)
	live.append(self)
	_place.call_deferred()


func _place() -> void:
	if done or not is_inside_tree():
		return
	var p := get_parent() as Control
	position = clip.position - (p.global_position if p != null else Vector2.ZERO)
	size = clip.size
	_redraw()


func set_k(v: float) -> void:
	v = clampf(v, 0.0, 1.0)
	if not is_equal_approx(v, k):
		k = v
		_redraw()
		if not _heard and kind == &"side" and at().position != rest.position + (off * (1.0 - _k0)).round():
			_heard = true
			Audio.fx(&"chrome_on" if _k0 < 0.5 else &"chrome_off")


## Where it is now (viewport px), on whole pixels.
func at() -> Rect2:
	return Rect2(rest.position + (off * (1.0 - k)).round(), rest.size)


## (drawn by a child, so the parent's clip cuts it at the screens' edge)
class _Body extends Control:
	var piece: ChromeSlide

	func _draw() -> void:
		var r := piece.at()
		var o := piece.clip.position
		var here := Rect2(r.position - o, r.size)
		if piece.tex != null:
			draw_texture_rect_region(piece.tex, here, piece.rest)
			return
		draw_rect(here, UITheme.VOID)
		if piece.plate != null:
			draw_style_box(piece.plate, Rect2(piece.plate_rect.position + (r.position - piece.rest.position) - o, piece.plate_rect.size))


var _body: _Body = null


func _redraw() -> void:
	if _body != null:
		_body.position = Vector2.ZERO
		_body.size = size
		_body.queue_redraw()


func _has_point(point: Vector2) -> bool:
	return not done and at().intersection(clip).has_point(get_global_transform() * point)


func finish() -> void:
	done = true
	visible = false
	live.erase(self)
	queue_free()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		live.erase(self)
