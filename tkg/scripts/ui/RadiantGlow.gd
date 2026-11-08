class_name RadiantGlow
extends RefCounted

## RADIANT'S GLOW AND COLOUR (direction C, Nov 7; Jon: "redo radiant to be super
## dramatic with the lighting effects"). One pass over a finished, palette-cut
## picture, at its own 2x2 blocks: what is bright glows in layered halos of its
## own colour, cut into flat steps with a dithered band at each edge; the key
## light's rays stream out through gaps in the dust; the darks go deep and
## coloured, never grey. The same pass on the chart, the sector map and LOCAL.
##
## A glow viewport WRAPS the picture's own viewport (`wrap`): the picture is
## drawn as a child, so it is drawn first each frame, then
##   1. `radiant_bright`: what of it glows, alone;
##   2. a back buffer copy, whose blurred levels are the halos;
##   3. `radiant_glow`: the picture, its shade, and the glow in steps.
## Nothing of it is built in any other style.

const BRIGHT_SH := preload("res://shaders/radiant_bright.gdshader")
const GLOW_SH := preload("res://shaders/radiant_glow.gdshader")


## `inner` moved into a new glow viewport of its size, which takes its place
## among its parent's children. `canvas`: the size the picture is drawn at in
## its own canvas (the scene's 960x540 over 480x270 blocks; the chart's blocks
## as they are). `look`: `radiant_glow` uniforms for this view.
static func wrap(inner: SubViewport, canvas: Vector2, look: Dictionary = {}) -> SubViewport:
	var vp := SubViewport.new()
	vp.name = "RadiantGlow"
	vp.size = inner.size
	if inner.size_2d_override != Vector2i.ZERO:
		vp.size_2d_override = inner.size_2d_override
		vp.size_2d_override_stretch = true
	vp.transparent_bg = false
	vp.disable_3d = true
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var parent := inner.get_parent()
	if parent != null:
		var at := inner.get_index()
		parent.remove_child(inner)
		parent.add_child(vp)
		parent.move_child(vp, at)
	vp.add_child(inner)
	var mb := ShaderMaterial.new()
	mb.shader = BRIGHT_SH
	mb.set_shader_parameter("src", inner.get_texture())
	var b := ColorRect.new()
	b.name = "Bright"
	b.size = canvas
	b.material = mb
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vp.add_child(b)
	var copy := BackBufferCopy.new()
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	vp.add_child(copy)
	var mg := ShaderMaterial.new()
	mg.shader = GLOW_SH
	mg.set_shader_parameter("src", inner.get_texture())
	mg.set_shader_parameter("size", Vector2(inner.size))
	for k in look:
		if k == "thr" or k == "knee" or k == "hue_k":
			mb.set_shader_parameter(k, look[k])
		else:
			mg.set_shader_parameter(k, look[k])
	var g := ColorRect.new()
	g.name = "Glow"
	g.size = canvas
	g.material = mg
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vp.add_child(g)
	return vp


## The glow pass's material, to set its light, anchor or look each frame.
static func glow_mat(vp: SubViewport) -> ShaderMaterial:
	if vp == null or not vp.has_node("Glow"):
		return null
	return (vp.get_node("Glow") as ColorRect).material as ShaderMaterial


## A new size (blocks; `canvas` as in `wrap`): the chart's viewport follows the screen.
static func resize(vp: SubViewport, blocks: Vector2i, canvas: Vector2) -> void:
	vp.size = blocks
	(vp.get_node("Bright") as ColorRect).size = canvas
	(vp.get_node("Glow") as ColorRect).size = canvas
	glow_mat(vp).set_shader_parameter("size", Vector2(blocks))


## A SUN'S BREATH NOW, for the glow's `pulse`: its corona's strength against its
## steady one -- the flicker (`SunView.step`'s `flick`, over its steady warmth) and
## the breath (`c_breath`, which the corona's glow takes 1.33 times). 1 for anything
## not a sun. (A+B+C, Nov 7: the steps hold still while the light breathes.)
static func sun_pulse(sun: Node) -> float:
	if sun == null or not is_instance_valid(sun):
		return 1.0
	var m: Variant = sun.get("_mat")
	if not (m is ShaderMaterial):
		return 1.0
	var sm := m as ShaderMaterial
	var p: Variant = sun.get("P")
	var warm := float((p as Dictionary).get("warm", 1.0)) if p is Dictionary else 1.0
	var fl: Variant = sm.get_shader_parameter("flick")
	var br: Variant = sm.get_shader_parameter("c_breath")
	var f := (float(fl) / maxf(warm, 1e-3)) if fl != null else 1.0
	var b := float(br) if br != null else 1.0
	return clampf(f * (1.0 + (b - 1.0) * 1.33), 0.5, 2.0)
