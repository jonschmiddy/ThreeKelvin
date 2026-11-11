class_name JumpStage
extends Control

## The film's canvas: a full-rect Control put last in EncounterView, over the world (sky, hull,
## dust, effects) and under the HUD, which is drawn after the view. In order: the specks (into
## the world, so the world pass sees them), a back buffer copy, the film's world pass, a second
## copy, and the shared finish pass (bloom, flash, fringe, shake). Freed at the commit.
## Why: docs/why/JumpStage.md#stage

const FINISH := preload("res://shaders/jump/jump_finish.gdshader")

var world := Rect2()
var specks: JumpSpecks
var pass1: ColorRect
var mat1: ShaderMaterial
var pass2: ColorRect
var mat2: ShaderMaterial


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Build the passes with the film's world shader. `world_rect` is the window on screen.
func build(world_shader: Shader, world_rect: Rect2) -> void:
	world = world_rect
	specks = JumpSpecks.new()
	add_child(specks)
	add_child(_copy())
	mat1 = ShaderMaterial.new()
	mat1.shader = world_shader
	pass1 = _pass(mat1)
	add_child(_copy())
	mat2 = ShaderMaterial.new()
	mat2.shader = FINISH
	pass2 = _pass(mat2)
	var wr := Vector4(world.position.x, world.position.y, world.size.x, world.size.y)
	mat1.set_shader_parameter(&"world", wr)
	mat2.set_shader_parameter(&"world", wr)


func _copy() -> BackBufferCopy:
	var bb := BackBufferCopy.new()
	bb.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	return bb


func _pass(mat: ShaderMaterial) -> ColorRect:
	var r := ColorRect.new()
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.material = mat
	add_child(r)
	return r


func set1(pname: StringName, v: Variant) -> void:
	mat1.set_shader_parameter(pname, v)


func set2(pname: StringName, v: Variant) -> void:
	mat2.set_shader_parameter(pname, v)


## An additive light buffer the size of the window, drawn in screen coordinates and read by
## the world pass as `pname` (8-bit, so what is drawn into it is pre-scaled by LIGHT_K).
## Why: docs/why/JumpStage.md#light-buffers
const LIGHT_K := 0.25

func light(pname: StringName, k: float = 1.0) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i((world.size * k).ceil())
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	# set once it is in the tree: before, its canvas is not yet the viewport's
	vp.canvas_transform = Transform2D(0.0, Vector2(k, k), 0.0, -world.position * k)
	mat1.set_shader_parameter(pname, vp.get_texture())
	return vp


## The hull's textures, once baked, to the world pass.
func hull_textures(h: JumpHull) -> void:
	mat1.set_shader_parameter(&"hull", h.tex)
	mat1.set_shader_parameter(&"aux", h.aux)
	mat1.set_shader_parameter(&"aux2", h.aux2)
	mat1.set_shader_parameter(&"sdf", h.sdf)
	mat1.set_shader_parameter(&"sdf_pad", float(JumpHull.PAD))
	mat1.set_shader_parameter(&"d_in_max", h.d_in_max)
	mat1.set_shader_parameter(&"ink_rect", Vector4(h.ink.position.x, h.ink.position.y, h.ink.size.x, h.ink.size.y))
