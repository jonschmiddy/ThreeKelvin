extends Node

## WHAT EACH SHADER COSTS TO COMPILE THE FIRST TIME IT IS DRAWN, on this machine:
##   tools/dev/render.sh --path tkg -- sheet=WarmCost [only=sky,planet,...] [mesh=map_fabric]
## Each shader under res://shaders/ is drawn once into a 4x4 viewport of its own
## (as a rect; `mesh=` names the ones also drawn as a mesh, the variant
## `draw_mesh` binds): the frame that draws it, timed from its process step to
## the end of its draw (`frame_post_draw`), against the median of frames that
## compile nothing. (Not a `force_draw` straight after adding it: a new item's
## draw list is made at the frame's end, so that draw held nothing to compile,
## and every shader timed at under a millisecond.) Every run has a fresh profile, so this is
## a cold compile -- what a launch costs where the driver keeps no program
## binaries (Apple's OpenGL), or a first launch anywhere. Needs a window: the
## dummy renderer compiles nothing.

var _tree: SceneTree
var _args: PackedStringArray


func _arg(k: String, d: String = "") -> String:
	for a in _args:
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d


func _ready() -> void:
	_args = OS.get_cmdline_user_args()
	# (the title under this sheet compiles the map's shaders ahead where it
	# can, `ShaderWarm`: off, or they would be compiled before they are timed.
	# By path, so this sheet runs on a tree without it too)
	if ResourceLoader.exists("res://scripts/ui/ShaderWarm.gd"):
		(load("res://scripts/ui/ShaderWarm.gd") as GDScript).set("off", true)
	_run.call_deferred()


## One frame, from here (in its process step) to the end of its draw.
func _frame_ms() -> float:
	var t0 := Time.get_ticks_usec()
	await RenderingServer.frame_post_draw
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	# (on into the next frame's process step, where the next item is added)
	await _tree.process_frame
	return ms


func _baseline() -> float:
	var v: Array[float] = []
	for i in 7:
		v.append(await _frame_ms())
	v.sort()
	return v[3]


func _vp(holder: Node, item: CanvasItem) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(4, 4)
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	holder.add_child(vp)
	vp.add_child(item)
	return vp


class _MeshItem extends Node2D:
	var mesh: ArrayMesh

	func _draw() -> void:
		draw_mesh(mesh, null)


func _run() -> void:
	_tree = get_tree()
	for i in 30:
		await _tree.process_frame
	if ResourceLoader.exists("res://scripts/ui/ShaderWarm.gd") \
			and not ((load("res://scripts/ui/ShaderWarm.gd") as GDScript).get("costs") as Array).is_empty():
		print("[warmcost] ShaderWarm compiled ahead before this ran: its shaders read as free")
	var only := _arg("only", "").split(",", false)
	var meshes := _arg("mesh", "map_fabric").split(",", false)
	var names: Array[String] = []
	var da := DirAccess.open("res://shaders")
	for f in da.get_files():
		if f.ends_with(".gdshader"):
			var nm := f.trim_suffix(".gdshader")
			if only.is_empty() or nm in only:
				names.append(nm)
	names.sort()
	var holder := Node.new()
	add_child(holder)
	var rows: Array = []
	var quad := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2(0, 0), Vector2(4, 0), Vector2(4, 4)])
	quad.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var total := 0.0
	for nm in names:
		var sh := load("res://shaders/%s.gdshader" % nm) as Shader
		if sh == null or sh.get_mode() != Shader.MODE_CANVAS_ITEM:
			continue
		for variant in (["rect", "mesh"] if nm in meshes else ["rect"]):
			var base := await _baseline()
			var m := ShaderMaterial.new()
			m.shader = sh
			var item: CanvasItem
			if variant == "rect":
				var r := ColorRect.new()
				r.size = Vector2(4, 4)
				item = r
			else:
				var mi := _MeshItem.new()
				mi.mesh = quad
				item = mi
			item.material = m
			_vp(holder, item)
			var ms: float = (await _frame_ms()) - base
			total += maxf(0.0, ms)
			rows.append([ms, "%s (%s)" % [nm, variant]])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	print("[warmcost] %d shaders, %.0f ms in all, adapter %s, driver %s" % [rows.size(), total,
		RenderingServer.get_video_adapter_name(), RenderingServer.get_current_rendering_driver_name()])
	for r: Array in rows:
		print("[warmcost] %7.1f ms  %s" % [float(r[0]), r[1]])
	_tree.quit()
