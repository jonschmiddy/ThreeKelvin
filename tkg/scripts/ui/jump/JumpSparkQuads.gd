class_name JumpSparkQuads
extends MultiMeshInstance2D

## Streaks and sparks of light (R14's stars and sparks, R10's sparks): one MultiMesh of quads
## moved by closed forms in `shaders/jump/jump_spark_quads.gdshader`, each instance's numbers
## in its colour and custom data, this instant's in uniforms. Added, whole pixels, into the
## stage between the film's passes.
## Why: docs/why/JumpSparkQuads.md#quads

const SHADER := preload("res://shaders/jump/jump_spark_quads.gdshader")

## R14 stars in the pour and the burst (heads and tails along their rays from the sink).
const MODE_STARS := 0
## R14's burst sparks: streaks thrown from the point, dragged.
const MODE_BURST := 1
## R10's sparks: a pixel of white, a plus of magenta when bright.
const MODE_SPARKS := 2

var mat: ShaderMaterial
var mm: MultiMesh
var _n := 0


## `count` instances in `mode`; the mesh is a unit quad the shader stretches head to tail.
func _init(mode: int, count: int, origin: Vector2) -> void:
	position = -origin
	mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = _quad()
	mm.instance_count = count
	for i in count:
		mm.set_instance_transform_2d(i, Transform2D.IDENTITY)
	multimesh = mm
	mat = ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter(&"mode", mode)
	material = mat
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


static func _quad() -> ArrayMesh:
	var m := ArrayMesh.new()
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arr[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arr[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


## One instance's numbers: its colour (any four floats) and its custom four.
func put(i: int, col: Color, custom: Color) -> void:
	mm.set_instance_color(i, col)
	mm.set_instance_custom_data(i, custom)
	_n = maxi(_n, i + 1)


func set_p(pname: StringName, v: Variant) -> void:
	mat.set_shader_parameter(pname, v)
