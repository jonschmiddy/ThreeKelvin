class_name WorldView
extends Node2D

## What `PlanetView` and `ShatteredView` share: one world's disc and its surface memory.

var spec: Dictionary = {}
var _disc: ColorRect
var _mat: ShaderMaterial
var _cell := 1
## The surface remembers last frame so grain and edges do not go A, B, A across the pixel grid.
## Why: docs/why/ShatteredView.md#surface-memory
var _mem_vp: SubViewport
var _mem_copy: SubViewport
var _mem_mat: ShaderMaterial
var _mem_fresh := 0
var _mem_r := -1.0
var _mem_off := Vector2.INF


## The shader parameters the memory's pass must see each frame as the world on screen sees them.
func _mem_live() -> Array:
	return []


## A world of this kind, at radius `r`; `over` is merged into its spec where the kind takes one.
func set_world(_world: StringName, _seed: int, _r: float, _over: Dictionary = {}) -> void:
	pass


## 2 on the map: the world's dither and its trimmings on the place's 2x2 grid.
func set_cell(_c: int) -> void:
	pass


## The smooth zoom: radius `r`, round a centre `off` px from this node's.
func set_live(_r: float, _off: Vector2) -> void:
	pass


## Light direction, time, light strength and star disc position, in the parent's pixels.
func step(_t: float, _light: Vector3, _k_light: float = 1.0, _star_at: Vector2 = Vector2(-9999, -9999), _star_r: float = 0.0) -> void:
	pass


## The material the world on screen is drawn with.
func world_mat() -> ShaderMaterial:
	return _mat


## The material of the memory's pass (null until the memory is built).
func memory_mat() -> ShaderMaterial:
	return _mem_mat


## The memory's picture (null until the memory is built).
func memory_view() -> SubViewport:
	return _mem_vp


## The copy of last frame's memory (null until the memory is built).
func memory_copy() -> SubViewport:
	return _mem_copy


## Called in `_mem_setup` once the memory is sized to `n` blocks, before the uniforms are copied.
func _mem_resized(_n: int) -> void:
	pass


## Called each `_mem_sync` after the live uniforms are handed over.
func _mem_synced() -> void:
	pass


## How many frames a view put back in the tree holds its memory as fresh.
func _mem_fresh_on_enter() -> int:
	return 2


## The memory built or rebuilt for the world's current size: a pixel a block, with a last-frame copy.
func _mem_setup() -> void:
	if PixelTurn.world_mode != PixelTurn.Mode.BLENDED or spec.is_empty():
		return
	var cl := maxi(_cell, 1)
	var hs := int(_mat.get_shader_parameter("half_size"))
	var half := ceili(float(hs) / float(cl))
	var n := 2 * half + 1
	if _mem_vp == null:
		_mem_vp = SubViewport.new()
		_mem_vp.transparent_bg = true
		_mem_vp.disable_3d = true
		_mem_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
		var rect := ColorRect.new()
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_mem_mat = ShaderMaterial.new()
		_mem_mat.shader = _mat.shader
		rect.material = _mem_mat
		_mem_vp.add_child(rect)
		# last frame's memory, copied exactly (its alpha is a count, not a coverage)
		_mem_copy = SubViewport.new()
		_mem_copy.transparent_bg = true
		_mem_copy.disable_3d = true
		_mem_copy.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		var last := TextureRect.new()
		last.texture = _mem_vp.get_texture()
		last.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# Sized by hand, or it keeps its first size and a resized world was copied stretched.
		last.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		last.stretch_mode = TextureRect.STRETCH_SCALE
		var cm := CanvasItemMaterial.new()
		cm.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
		last.material = cm
		_mem_copy.add_child(last)
		_mem_vp.add_child(_mem_copy)
		add_child(_mem_vp)
		RenderingServer.frame_pre_draw.connect(_mem_sync)
		PixelTurn.timed(_mem_vp)
		PixelTurn.timed(_mem_copy)
	_mem_vp.size = Vector2i(n, n)
	_mem_copy.size = Vector2i(n, n)
	(_mem_vp.get_child(0) as ColorRect).size = Vector2(n, n)
	(_mem_copy.get_child(0) as TextureRect).size = Vector2(n, n)
	_mem_resized(n)
	# everything the world on screen was given, then the memory's own
	for u: Dictionary in _mat.shader.get_shader_uniform_list():
		var nm := String(u.name)
		if not nm.begins_with("mem_"):
			_mem_mat.set_shader_parameter(nm, _mat.get_shader_parameter(nm))
	for m: ShaderMaterial in [_mat, _mem_mat]:
		m.set_shader_parameter("mem_n", n)
		m.set_shader_parameter("mem_half", half)
		m.set_shader_parameter("mem_ease", PixelTurn.EASE)
		m.set_shader_parameter("mem_hyst", PixelTurn.HYST)
		m.set_shader_parameter("mem_release", PixelTurn.RELEASE)
	_mem_mat.set_shader_parameter("mem_mode", 1)
	_mem_mat.set_shader_parameter("mem_prev", _mem_copy.get_texture())
	_mat.set_shader_parameter("mem_mode", 2)
	_mat.set_shader_parameter("mem_now", _mem_vp.get_texture())
	_mem_fresh = 2


## Each frame before anything is drawn: the memory's pass handed what changed
## this frame; nothing held on a new size or centre (the map's smooth zoom).
func _mem_sync() -> void:
	if _mem_mat == null or not is_inside_tree():
		return
	var t0 := Time.get_ticks_usec() if PixelTurn.cost_on else 0
	var r := float(_mat.get_shader_parameter("r"))
	var ov: Variant = _mat.get_shader_parameter("ctr_off")
	var off: Vector2 = ov if ov is Vector2 else Vector2.ZERO
	# Keep the memory until size moves a block: the smooth zoom restarted it each frame.
	# Why: docs/why/PlanetView.md#memory-hysteresis
	var cl := float(maxi(_cell, 1))
	if _mem_r < 0.0 or absf(r - _mem_r) >= cl or off.distance_to(_mem_off) > cl:
		_mem_fresh = maxi(_mem_fresh, 1)
		_mem_r = r
	_mem_off = off
	for nm: String in _mem_live():
		_mem_mat.set_shader_parameter(nm, _mat.get_shader_parameter(nm))
	_mem_mat.set_shader_parameter("mem_fresh", _mem_fresh > 0)
	if _mem_fresh > 0:
		_mem_fresh -= 1
	_mem_synced()
	if PixelTurn.cost_on:
		PixelTurn.cpu_us += Time.get_ticks_usec() - t0


func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_mem_sync):
		RenderingServer.frame_pre_draw.disconnect(_mem_sync)


func _enter_tree() -> void:
	if _mem_mat != null and not RenderingServer.frame_pre_draw.is_connected(_mem_sync):
		RenderingServer.frame_pre_draw.connect(_mem_sync)
		_mem_fresh = _mem_fresh_on_enter()
