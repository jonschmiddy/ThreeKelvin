class_name JumpGhosts
extends MultiMeshInstance2D

## R5's probable ships: the hull's outline, seams and a faint fill baked once from the hull
## bake as a ghost texture, drawn N times as additive density into a light buffer (behind
## the hull in R, in front in G, the frozen cloud in B), placed by GDScript each frame.
## Why: docs/why/JumpGhosts.md#ghosts

const SHADER := preload("res://shaders/jump/jump_ghost.gdshader")

var mat: ShaderMaterial
var canvas := Vector2.ZERO


## The ghost of this hull: EDGE1 0.95 + EDGE2 0.20 + SEAM 0.45 + 0.16 of its own shading to
## the 1.6, as r5.py made it, over 2 so it fits a byte; with mipmaps for the haze.
static func bake(h: JumpHull) -> ImageTexture:
	var w := h.size.x
	var hh := h.size.y
	var a := PackedByteArray()
	a.resize(w * hh)
	var hl := PackedFloat32Array()
	hl.resize(w * hh)
	for y in hh:
		for x in w:
			var c := h.image.get_pixel(x, y)
			if c.a > 0.0:
				a[y * w + x] = 1
				hl[y * w + x] = (c.r + c.g + c.b) / 3.0
	var er1 := JumpHull.erode_mask(a, w, hh)
	var er2 := JumpHull.erode_mask(er1, w, hh)
	var seam := h.aux.get_image()
	var out := Image.create(w, hh, true, Image.FORMAT_RGBA8)
	for y in hh:
		for x in w:
			var i := y * w + x
			if a[i] == 0:
				continue
			var v := (1.0 - float(er1[i])) * 0.95 + (1.0 - float(er2[i])) * 0.20
			v += seam.get_pixel(x, y).r * 0.45 + pow(hl[i], 1.6) * 0.16
			var g := clampf(v * 0.5, 0.0, 1.0)
			out.set_pixel(x, y, Color(g, g, g, 1.0))
	out.generate_mipmaps()
	return ImageTexture.create_from_image(out)


## `n` instances of `tex` (the hull's canvas, `canvas_size` px); `mip` for the quarter buffer.
func _init(n: int, tex: ImageTexture, canvas_size: Vector2, mip: bool) -> void:
	canvas = canvas_size
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_custom_data = true
	multimesh.mesh = JumpLines.quad()
	multimesh.instance_count = n
	multimesh.custom_aabb = AABB(Vector3(-4096.0, -4096.0, -1.0), Vector3(8192.0, 8192.0, 2.0))
	mat = ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter(&"ghost", tex)
	mat.set_shader_parameter(&"ghost_mip", tex)
	mat.set_shader_parameter(&"mip", 1.0 if mip else 0.0)
	material = mat
	for i in n:
		put(i, Vector2.ZERO, 1.0, 0.0, 0)


## Instance i: the canvas's top-left on screen (whole px), its scale, weight and channel.
func put(i: int, origin: Vector2, sc: float, w: float, chan: int) -> void:
	multimesh.set_instance_transform_2d(i, Transform2D(Vector2(canvas.x * sc, 0.0), Vector2(0.0, canvas.y * sc), origin.round()))
	multimesh.set_instance_custom_data(i, Color(w, float(chan), sc, 0.0))
