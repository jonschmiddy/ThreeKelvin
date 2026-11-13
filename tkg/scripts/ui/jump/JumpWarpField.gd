class_name JumpWarpField
extends RefCounted

## The warp field R3 and R8 share, the ship inside the bend: the film's ship pass (the world with
## the stand-in drawn where the film's source plane has it), a copy, the warp pass that bends
## both and adds the light, then the finish. Points of light go into an additive light buffer.
## Why: docs/why/JumpWarpField.md#warp-field

## The light buffer is 8-bit, so what is drawn into it is pre-scaled by this (read back x4).
const LIGHT_K := 0.25

var stage: JumpStage
var warp: ShaderMaterial
var light: SubViewport


## Build the passes: `ship_shader` on the stage's first pass, `warp_shader` after a second copy.
## With no ship pass (R8, whose warp reads the hull itself) the warp is the stage's first pass.
func build(st: JumpStage, ship_shader: Shader, warp_shader: Shader, window: Rect2) -> void:
	stage = st
	if ship_shader == null:
		stage.build(warp_shader, window)
		warp = stage.mat1
		_light(window)
		return
	stage.build(ship_shader, window)
	warp = ShaderMaterial.new()
	warp.shader = warp_shader
	var r := ColorRect.new()
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.material = warp
	var bb := BackBufferCopy.new()
	bb.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	# world -> ship pass -> copy -> warp -> copy -> finish
	stage.add_child(r)
	stage.move_child(r, stage.pass2.get_index())
	stage.add_child(bb)
	stage.move_child(bb, stage.pass2.get_index())
	warp.set_shader_parameter(&"world", Vector4(window.position.x, window.position.y, window.size.x, window.size.y))
	_light(window)


func _light(window: Rect2) -> void:
	light = SubViewport.new()
	light.size = Vector2i(window.size.ceil())
	light.transparent_bg = true
	light.disable_3d = true
	light.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# (set once it is in the tree: before, the viewport has no canvas to move)
	stage.add_child(light)
	light.canvas_transform = Transform2D(0.0, -window.position)
	warp.set_shader_parameter(&"lightbuf", light.get_texture())


## A layer of `n` points drawn by `shader`'s vertex function into the light buffer: each point is a
## quad whose UV carries (point index, corner); the shader places it from its uniforms alone.
func points(shader: Shader, n: int) -> ShaderMaterial:
	var verts := PackedVector2Array()
	var uvs := PackedVector2Array()
	verts.resize(n * 6)
	uvs.resize(n * 6)
	# (the vertices span the window only so the layer is never culled; the shader moves them)
	var w := Rect2(stage.world.position, Vector2(light.size))
	var corners := [w.position, Vector2(w.end.x, w.position.y), w.end, w.position, w.end, Vector2(w.position.x, w.end.y)]
	for i in n:
		for c in 6:
			verts[i * 6 + c] = corners[c]
			uvs[i * 6 + c] = Vector2(float(i), float(c))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance2D.new()
	mi.mesh = mesh
	var m := ShaderMaterial.new()
	m.shader = shader
	mi.material = m
	light.add_child(mi)
	return m


func setw(pname: StringName, v: Variant) -> void:
	warp.set_shader_parameter(pname, v)


## The hull's baked textures to the warp pass too (R8 reads its coverage there).
func hull_textures(h: JumpHull) -> void:
	warp.set_shader_parameter(&"hull", h.tex)
	warp.set_shader_parameter(&"aux", h.aux)
	warp.set_shader_parameter(&"sdf", h.sdf)
	warp.set_shader_parameter(&"sdf_pad", float(JumpHull.PAD))
	warp.set_shader_parameter(&"ink_rect", Vector4(h.ink.position.x, h.ink.position.y, h.ink.size.x, h.ink.size.y))


static var _seams: Dictionary = {}

## The films' own plate seams for a baked hull (rift.py SEAM: dark lines darker than their 3x3
## mean, kept where they run as lines) in red, and their halo (three five-point blurs over the
## film hull's maximum, x2.2, clipped) in green. Once per hull look, in a film's opening.
## Why: docs/why/JumpWarpField.md#seams
static func film_seams(h: JumpHull) -> ImageTexture:
	if _seams.has(h.key):
		return _seams[h.key]
	var img := h.image
	var w := h.size.x
	var hh := h.size.y
	var n := w * hh
	var lum := PackedFloat32Array()
	lum.resize(n)
	var a := PackedByteArray()
	a.resize(n)
	for y in hh:
		for x in w:
			var c := img.get_pixel(x, y)
			lum[y * w + x] = (c.r + c.g + c.b) / 3.0 * 255.0
			a[y * w + x] = 1 if c.a > 0.0 else 0
	var s := PackedByteArray()
	s.resize(n)
	for y in range(1, hh - 1):
		for x in range(1, w - 1):
			var i := y * w + x
			if a[i] == 0 or a[i - 1] == 0 or a[i + 1] == 0 or a[i - w] == 0 or a[i + w] == 0 or lum[i] >= 110.0:
				continue
			var nb := 0.0
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					nb += lum[i + dy * w + dx]
			if lum[i] < nb / 9.0 - 14.0:
				s[i] = 1
	var lh := PackedByteArray()
	lh.resize(n)
	var lv := PackedByteArray()
	lv.resize(n)
	for y in range(1, hh - 1):
		for x in range(1, w - 1):
			var i := y * w + x
			if s[i] == 1:
				lh[i] = 1 if (s[i - 1] == 1 and s[i + 1] == 1) else 0
				lv[i] = 1 if (s[i - w] == 1 and s[i + w] == 1) else 0
	var seam := PackedFloat32Array()
	seam.resize(n)
	for y in range(2, hh - 2):
		for x in range(2, w - 2):
			var i := y * w + x
			if lh[i] == 1 or lv[i] == 1 or (s[i] == 1 and (lh[i - 1] == 1 or lh[i + 1] == 1 or lv[i - w] == 1 or lv[i + w] == 1)):
				seam[i] = 1.0
	var hb := seam
	for _k in 3:
		var nx := PackedFloat32Array()
		nx.resize(n)
		for y in hh:
			for x in w:
				var i := y * w + x
				var v := hb[i]
				if x > 0: v += hb[i - 1]
				if x < w - 1: v += hb[i + 1]
				if y > 0: v += hb[i - w]
				if y < hh - 1: v += hb[i + w]
				nx[i] = v / 5.0
		hb = nx
	var bytes := PackedByteArray()
	bytes.resize(n * 4)
	for i in n:
		bytes[i * 4] = 255 if seam[i] > 0.5 else 0
		bytes[i * 4 + 1] = clampi(int(roundf(clampf(hb[i] / 0.832 * 2.2, 0.0, 1.0) * 255.0)), 0, 255) if a[i] == 1 else 0
		bytes[i * 4 + 3] = 255
	var tex := ImageTexture.create_from_image(Image.create_from_data(w, hh, false, Image.FORMAT_RGBA8, bytes))
	if _seams.size() >= JumpHull.CACHE_MAX:
		_seams.erase(_seams.keys()[0])
	_seams[h.key] = tex
	return tex
