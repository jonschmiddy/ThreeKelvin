class_name JumpSpecks
extends Node2D

## Whole-pixel specks drawn into the world before the film's passes copy it: R12's seventy
## dust motes, which the negative then inverts for free. Positions are closed forms in t.
## Why: docs/why/JumpSpecks.md#motes

## [x, y, brightness, drift, size] per mote, as r12.py rolled them (rng 1212).
var motes: Array = []
var _pts: PackedVector2Array = PackedVector2Array()
var _cols: PackedColorArray = PackedColorArray()
var _sizes: PackedInt32Array = PackedInt32Array()
var _origin := Vector2.ZERO


func _init() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m


## Where the film's (0, 0) is on screen: the motes were placed in the film's frame.
func set_origin(o: Vector2) -> void:
	_origin = o


## The motes at time t: drifting left, pulled toward `pc` by `pull`, at `vis` strength.
func place(t: float, vis: float, pull: float, pc: Vector2, col: Color) -> void:
	_pts.clear()
	_cols.clear()
	_sizes.clear()
	if vis > 0.01:
		for m: Array in motes:
			var x: float = float(m[0]) + float(m[3]) * t
			var y: float = float(m[1])
			x += (pc.x - x) * pull
			y += (pc.y - y) * pull
			_pts.append(Vector2(floorf(x + 0.5), floorf(y + 0.5)))
			_cols.append(Color(col.r * float(m[2]) * vis, col.g * float(m[2]) * vis, col.b * float(m[2]) * vis, 1.0))
			_sizes.append(int(m[4]))
	queue_redraw()


func _draw() -> void:
	for i in _pts.size():
		draw_rect(Rect2(_pts[i] - _origin, Vector2(float(_sizes[i]), 1.0)), _cols[i], true)
