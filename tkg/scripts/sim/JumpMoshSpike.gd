extends Node

## R15's history buffer, the spike: (a) a mirror SubViewport sharing the game view's World2D
## with everything outside EncounterView culled by canvas_cull_mask / visibility_layer, and
## (b) a self-reading state SubViewport (clear NEVER, read back through a BackBufferCopy).
## Windowed:  render.sh --path tkg --fixed-fps 60 -- sheet=JumpMoshSpike [out=<dir>]

var h := Harness.new()
var _tree: SceneTree

const SHIFT := """
shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform sampler2D live : filter_nearest, repeat_disable;
uniform float frame = 0.0;
uniform float first = 1.0;
void fragment() {
	vec2 p = floor(SCREEN_UV / SCREEN_PIXEL_SIZE);
	vec2 px = SCREEN_PIXEL_SIZE;
	vec3 c;
	if (first > 0.5) {
		c = texture(live, (p + 0.5) * px).rgb;
	} else if (p.y < 4.0) {
		// a counter stripe: column 0 takes this frame's number, the rest is last frame moved right a pixel
		c = p.x < 1.0 ? vec3(mod(frame, 256.0) / 255.0, 0.0, 0.0) : texture(screen, (p - vec2(1.0, 0.0) + 0.5) * px).rgb;
	} else {
		c = texture(screen, (p + 0.5) * px).rgb;
	}
	COLOR = vec4(c, 1.0);
}
"""


func _ready() -> void:
	_run.call_deferred()


func _anc(n: Node) -> String:
	var s := PackedStringArray()
	var c := n
	while c != null:
		var tag := c.get_class()
		if c.get_script() != null and c.get_script().get_global_name() != &"":
			tag = c.get_script().get_global_name()
		s.append("%s(%s)" % [c.name, tag])
		if c is Viewport:
			break
		c = c.get_parent()
	return " < ".join(s)


## The drawn rects under a culled Control: its leaves that are inside the window, visible.
func _covers(c: Control, out: Array[Rect2]) -> void:
	var kids := 0
	for k in c.get_children():
		if k is Control and (k as Control).visible:
			kids += 1
			_covers(k as Control, out)
	if kids == 0 and c.size.x * c.size.y < 200000.0:
		out.append(c.get_global_rect().grow(2.0))


func _run() -> void:
	_tree = get_tree()
	var dir := Harness.arg("out", "user://moshspike")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Router.show_local()
	for i in 30:
		await _tree.process_frame
	(Router.current as SectorScreen)._skip()
	for i in 30:
		await _tree.process_frame
	var sc := Router.current as SectorScreen
	var ev: EncounterView = sc._view
	var vp := ev.get_viewport()
	print("  renderer %s, view %s, %s" % [ProjectSettings.get_setting("rendering/renderer/rendering_method"), vp.size if vp is SubViewport else vp.get_visible_rect().size, _anc(ev)])
	var size := Vector2i(vp.get_visible_rect().size)

	# --- (a) the mirror: everything not on EncounterView's path is put on layer 20 only
	var held: Array = []
	var path := ev as Node
	while path != null and not (path is Viewport):
		var par := path.get_parent()
		if par == null:
			break
		for c in par.get_children():
			if c != path and c is CanvasItem:
				held.append([c, (c as CanvasItem).visibility_layer])
				(c as CanvasItem).visibility_layer = 1 << 19
		path = par
	print("  culled %d siblings on the path" % held.size())
	var mirror := SubViewport.new()
	mirror.size = size
	mirror.world_2d = vp.world_2d
	mirror.canvas_cull_mask = 1
	mirror.transparent_bg = false
	mirror.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	mirror.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	# --- (b) the state: clear never, last frame read through a BackBufferCopy
	var state := SubViewport.new()
	state.size = size
	state.transparent_bg = false
	state.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
	state.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	state.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var bb := BackBufferCopy.new()
	bb.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	state.add_child(bb)
	var sh := Shader.new()
	sh.code = SHIFT
	var mat := ShaderMaterial.new()
	mat.shader = sh
	var cr := ColorRect.new()
	cr.size = Vector2(size)
	cr.material = mat
	state.add_child(cr)
	# the mirror is the state's child, so it draws first (a viewport draws after its children)
	state.add_child(mirror)
	mat.set_shader_parameter(&"live", mirror.get_texture())
	var host := Node.new()
	host.name = "MoshSpikeHost"
	ev.add_child(host)
	host.add_child(state)

	# a test overlay inside the world window, on the main view, that the mirror must not see:
	# a stage-like ColorRect last in EncounterView on layer 20
	var over := ColorRect.new()
	over.color = Color(1, 0, 1)
	over.position = Vector2(400, 200)
	over.size = Vector2(40, 40)
	over.visibility_layer = 1 << 19
	ev.add_child(over)

	var frames := 40
	for f in frames:
		mat.set_shader_parameter(&"frame", float(f))
		mat.set_shader_parameter(&"first", 1.0 if f < 2 else 0.0)
		await RenderingServer.frame_post_draw
	var mimg := mirror.get_texture().get_image()
	var simg := state.get_texture().get_image()
	var vimg := vp.get_texture().get_image()
	mimg.save_png("%s/mirror.png" % dir)
	simg.save_png("%s/state.png" % dir)
	vimg.save_png("%s/view.png" % dir)

	# the HUD: where HudBar draws, the main view has it and the mirror does not
	var hud: Control = null
	for n in _tree.root.find_children("*", "Control", true, false):
		if n is HudBar:
			hud = n
			break
	var win := ev.get_global_rect()
	# what the culled items cover: the HUD's overlays that sit inside the world window
	var covers: Array[Rect2] = []
	for e in held:
		if e[0] is Control and (e[0] as Control).is_visible_in_tree():
			_covers(e[0] as Control, covers)
	var same_in := 0
	var all_in := 0
	var same_hud := 0
	var all_hud := 0
	for y in range(0, size.y, 2):
		for x in range(0, size.x, 2):
			var a := mimg.get_pixel(x, y)
			var b := vimg.get_pixel(x, y)
			var eq := absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) < 0.02
			var under := Rect2(400, 200, 40, 40).has_point(Vector2(x, y))
			# the goal line at the top and the status bar at the foot sit over the window
			under = under or y < int(win.position.y) + 22 or y >= 498
			if win.has_point(Vector2(x, y)) and not under:
				all_in += 1
				same_in += 1 if eq else 0
			elif hud != null and hud.get_global_rect().has_point(Vector2(x, y)):
				all_hud += 1
				same_hud += 1 if eq else 0
	print("  world window %s, hud %s" % [win, hud.get_global_rect() if hud != null else Rect2()])
	h._ok("(a) the mirror matches the view inside the world window, off the HUD's overlays (%d of %d samples)" % [same_in, all_in],
		all_in > 0 and float(same_in) / float(all_in) > 0.995)
	h._ok("(a) and never holds the HUD (%d of %d HUD samples equal the view's)" % [same_hud, all_hud],
		all_hud > 0 and float(same_hud) / float(all_hud) < 0.2)
	var pm := mimg.get_pixel(420, 220)
	h._ok("(a) the overlay culled by visibility_layer is not in the mirror (%s)" % pm, not (pm.r > 0.9 and pm.b > 0.9 and pm.g < 0.1))
	# the state's counter stripe: column k holds the frame number from k frames ago
	var c0 := int(round(simg.get_pixel(0, 1).r * 255.0))
	var run := 0
	for k in 30:
		var v := int(round(simg.get_pixel(k, 1).r * 255.0))
		if v == c0 - k:
			run += 1
	h._ok("(b) the state read last frame back through the BackBufferCopy: %d of 30 columns step back one frame each (col0 %d)" % [run, c0],
		run >= 29 and c0 >= frames - 3)
	var sb := simg.get_pixel(300, 300)
	var mb := mimg.get_pixel(300, 300)
	h._ok("(b) and below the stripe it kept the world it was seeded with (%s vs %s)" % [sb, mb], sb.a > 0.99)
	for e in held:
		(e[0] as CanvasItem).visibility_layer = e[1]
	host.queue_free()
	over.queue_free()
	h.verdict("jumpmoshspike")
	_tree.quit(h.code())
