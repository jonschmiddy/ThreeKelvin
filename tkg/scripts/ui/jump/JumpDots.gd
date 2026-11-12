class_name JumpDots
extends Node2D

## Single pixels of light (R1's sparks, R5's foam) drawn into a light buffer: whole pixels,
## each a colour already scaled by the buffer's factor, summed by the additive blend and
## tone-mapped with the rest of the near light by the world pass.
## Why: docs/why/JumpLines.md#dots

var _pts := PackedVector2Array()
var _cols := PackedColorArray()


func _init() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m


func set_dots(pts: PackedVector2Array, cols: PackedColorArray) -> void:
	_pts = pts
	_cols = cols
	queue_redraw()


func _draw() -> void:
	for i in _pts.size():
		draw_rect(Rect2(_pts[i], Vector2.ONE), _cols[i], true)
