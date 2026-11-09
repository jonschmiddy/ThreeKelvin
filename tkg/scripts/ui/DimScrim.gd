class_name DimScrim
extends Control

## The dark glass over everything but one control: four rects round its box, so the hole
## is the control itself and a click there is a click on it. Ignores the mouse.
## Why: docs/why/SectorScreen.md#dim-the-rest

## VOID at this alpha leaves what is under it at about `UITheme.DIM` of its brightness.
const ALPHA := 0.6
const FADE_S := 0.25
var alpha := 0.0
var hole := Rect2()
var _keep: Control = null
var _tw: Tween = null

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

func show_dim(on: bool, keep: Control) -> void:
	_keep = keep
	if _tw != null and _tw.is_valid():
		_tw.kill()
	var to := ALPHA if on else 0.0
	if DisplaySettings.reduced_motion:
		alpha = to
		visible = on
		queue_redraw()
		return
	visible = true
	_tw = create_tween()
	_tw.tween_property(self, "alpha", to, FADE_S)
	if not on:
		_tw.tween_callback(func() -> void: visible = false)

## The hole follows the control every frame: the band breathes and the button with it.
func _process(_d: float) -> void:
	if not visible:
		return
	var h := _keep.get_global_rect() if _keep != null and is_instance_valid(_keep) else Rect2()
	if h != hole:
		hole = h
	queue_redraw()

func _draw() -> void:
	var c := Color(UITheme.VOID, alpha)
	var r := Rect2(Vector2.ZERO, size)
	if hole.size == Vector2.ZERO:
		draw_rect(r, c, true)
		return
	var h := Rect2(hole.position.round(), hole.size.round())
	draw_rect(Rect2(r.position, Vector2(r.size.x, h.position.y - r.position.y)), c, true)
	draw_rect(Rect2(Vector2(r.position.x, h.end.y), Vector2(r.size.x, r.end.y - h.end.y)), c, true)
	draw_rect(Rect2(Vector2(r.position.x, h.position.y), Vector2(h.position.x - r.position.x, h.size.y)), c, true)
	draw_rect(Rect2(Vector2(h.end.x, h.position.y), Vector2(r.end.x - h.end.x, h.size.y)), c, true)
