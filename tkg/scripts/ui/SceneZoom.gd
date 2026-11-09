class_name SceneZoom
extends RefCounted

## LOCAL's scene scaled about one of its points, so that point lands where it is
## told: the camera the cutaway pushes in with, for any subject (a wreck, your ship).
## Why: docs/why/SceneZoom.md#one-camera-for-every-push-in

var _scenes: Array[Control] = []
var _sky: LocalSky = null
## Each scene's scale, offsets and size as they were, and the anchor in its own space.
var _was: Array = []
var _q: Array[Vector2] = []
var _sky_fixed := Vector2.ZERO
var _on := false


## Hold `scenes` (and the layered `sky`) ready to zoom about `anchor_g`, a global point.
func begin(scenes: Array[Control], sky: LocalSky, anchor_g: Vector2) -> void:
	end()
	_scenes = []
	_was = []
	_q = []
	for sc in scenes:
		if sc == null or not is_instance_valid(sc):
			continue
		_scenes.append(sc)
		_was.append([sc.scale, sc.offset_left, sc.offset_top, sc.offset_right, sc.offset_bottom, sc.size])
		_q.append(sc.get_global_transform().affine_inverse() * anchor_g)
	_sky = sky
	if _sky != null and is_instance_valid(_sky):
		_sky_fixed = _sky.get_global_transform().affine_inverse() * anchor_g
	_on = true


## The scene `zs` times its size, its anchor at the global point `to_g`.
func apply(zs: float, to_g: Vector2) -> void:
	if not _on:
		return
	for i in _scenes.size():
		var sc := _scenes[i]
		if not is_instance_valid(sc):
			continue
		var base: Vector2 = _was[i][0]
		sc.scale = base * zs
		var to := (sc.get_parent() as CanvasItem).get_global_transform().affine_inverse() * to_g
		sc.position = (to - _q[i] * sc.scale).round()
		# (its own size, which a moved anchored control does not keep)
		sc.size = _was[i][5]
		# (a picture lit in its own pixels relit where it now is, this frame)
		if sc.has_method(&"sync_light"):
			sc.call(&"sync_light")
	if _sky != null and is_instance_valid(_sky):
		_sky.set_zoom(zs, _sky_fixed, _sky.get_global_transform().affine_inverse() * to_g)


## Everything back where it was, by its offsets, so a window resized meanwhile lands it right.
func end() -> void:
	if not _on:
		return
	_on = false
	for i in _scenes.size():
		var sc := _scenes[i]
		if not is_instance_valid(sc):
			continue
		var w: Array = _was[i]
		sc.scale = w[0]
		sc.offset_left = w[1]
		sc.offset_top = w[2]
		sc.offset_right = w[3]
		sc.offset_bottom = w[4]
	if _sky != null and is_instance_valid(_sky):
		_sky.set_zoom(1.0, Vector2.ZERO, Vector2.ZERO)
	_scenes = []
	_was = []
	_q = []
	_sky = null


func active() -> bool:
	return _on
