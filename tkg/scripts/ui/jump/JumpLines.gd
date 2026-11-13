class_name JumpLines
extends MultiMeshInstance2D

## Streaks of light as instances in a light buffer: one thin quad each, placed by the vertex
## shader from the instance's own numbers (its transform's origin and axes) and this
## instant's uniforms, so a thousand streaks cost the CPU nothing a frame.
## Why: docs/why/JumpLines.md#streaks

const SHADER := preload("res://shaders/jump/jump_lines.gdshader")
static var _quad: ArrayMesh = null

var mat: ShaderMaterial


## The unit quad every instance is built from (its UV is the along and across of the streak).
static func quad() -> ArrayMesh:
	if _quad == null:
		var arr: Array = []
		arr.resize(Mesh.ARRAY_MAX)
		var v := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)])
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_TEX_UV] = v
		_quad = ArrayMesh.new()
		_quad.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return _quad


## `n` instances in `mode` (0 given lines, 1 R1's stars, 2 R1's flow). Every instance must
## be `put` before the first frame: an identity transform is a star at the window's corner.
func _init(n: int, mode: int) -> void:
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_custom_data = true
	multimesh.use_colors = true
	multimesh.mesh = quad()
	multimesh.instance_count = n
	# the transforms carry numbers, not places: the item's rect is set by hand
	multimesh.custom_aabb = AABB(Vector3(-4096.0, -4096.0, -1.0), Vector3(8192.0, 8192.0, 2.0))
	mat = ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter(&"mode", mode)
	material = mat


## Instance i's numbers, as the mode reads them: the origin and the two axes.
func put(i: int, origin: Vector2, ax: Vector2, ay: Vector2) -> void:
	multimesh.set_instance_transform_2d(i, Transform2D(ax, ay, origin))


## Mode 0: a line from head to tail with its head and tail brightness; `ih` 0 hides it.
func line(i: int, head: Vector2, tail: Vector2, ih: float, it: float) -> void:
	multimesh.set_instance_transform_2d(i, Transform2D(tail, Vector2(ih, it), head))


func set_p(pname: StringName, v: Variant) -> void:
	mat.set_shader_parameter(pname, v)
