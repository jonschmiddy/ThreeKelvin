extends Node

## The system map's pulsar as the GPU paints it, one picture per seed and
## moment, to set against the mockup's (the scratchpad's `sysmap/page`):
##   godot --path . -- sheet=PulsarSheet out=<dir> [seeds=11,3,0] [times=0.2,0.45]
##       [layer=pulsar|web|gas|both] [gas=<png>] [zoom=<k>] [at=<x>,<y>] [perf]
##   godot --path . -- sheet=PulsarSheet out=<dir> zoomsheet [zooms=1,2,3,4] [seeds=..] [times=..] [layer=..]
##
## Each picture is the map's 960 x 540 on black, the pulsar where the map puts
## it, saved as <dir>/g_<layer>_<seed>_<t>.png. `gas=` is the mockup's pulsar
## gas brightness dumped as a 16-bit PNG (red high byte, green low, over 4),
## to light it with the beam. `perf` instead times 240 frames with the
## pulsar and 240 without, vsync off, and prints the difference. Needs a
## window: a shader draws nothing headless.
##
## `zoom=` draws at the map's zoom k (`set_zoom`); `at=` moves the pulsar there
## after setting it up (a pan: its web should go with it). `perf` takes both,
## and `copies=` (20).
## `zoomsheet` draws each seed and moment at every zoom in `zooms`, the
## pulsar set up where the game sets it (the map's centre, the map's own
## rect) and then carried to the middle of a picture four times the map's
## size, so zoom 4 shows the whole of what zoom 1 shows; saved as
## <dir>/z_<layer>_<seed>_<t>_k<k>.png, 3840 x 2160.

const PulsarView := preload("res://scripts/ui/sysmap/PulsarView.gd")
const CENTRE := Vector2(622, 262)

var _out := ""
var _seeds: Array[int] = [11, 3, 0]
var _times: Array[float] = [0.2, 0.45, 0.55, 0.8]
var _layer := "both"
var _gas := ""
var _perf := false
var _zoom := 1.0
var _at := Vector2(NAN, NAN)
var _zooms: Array[float] = [1.0, 2.0, 3.0, 4.0]
var _zoom_sheet := false
var _copies := 20


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			_out = a.substr(4)
		elif a.begins_with("seeds="):
			_seeds.clear()
			for s in a.substr(6).split(","):
				_seeds.append(int(s))
		elif a.begins_with("times="):
			_times.clear()
			for s in a.substr(6).split(","):
				_times.append(float(s))
		elif a.begins_with("layer="):
			_layer = a.substr(6)
		elif a.begins_with("gas="):
			_gas = a.substr(4)
		elif a == "perf":
			_perf = true
		elif a.begins_with("zoom="):
			_zoom = float(a.substr(5))
		elif a.begins_with("at="):
			var xy := a.substr(3).split(",")
			_at = Vector2(float(xy[0]), float(xy[1]))
		elif a.begins_with("zooms="):
			_zooms.clear()
			for s in a.substr(6).split(","):
				_zooms.append(float(s))
		elif a.begins_with("copies="):
			_copies = int(a.substr(7))
		elif a == "zoomsheet":
			_zoom_sheet = true
	if _zoom_sheet:
		await _zoom_pictures()
		get_tree().quit()
		return
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.size = Vector2(960, 540)
	add_child(bg)
	var map := Node2D.new()
	add_child(map)
	var pv: Node2D = PulsarView.new()
	pv.position = CENTRE
	map.add_child(pv)
	if _gas != "":
		pv.call("set_gas", _gas_texture(_gas))
	if _perf:
		await _time_it(map, pv)
		get_tree().quit()
		return
	DirAccess.make_dir_recursive_absolute(_out)
	for seed in _seeds:
		pv.position = CENTRE
		pv.call("setup", seed)
		_zoom_pan(pv)
		(pv.get("web") as CanvasItem).visible = _layer != "pulsar"
		(pv.get("_box") as CanvasItem).visible = _layer == "pulsar" or _layer == "both"
		# `gas`: the beam-lit gas alone, no web over it
		(pv.get("_web_mat") as ShaderMaterial).set_shader_parameter("web_on", _layer != "gas")
		for t in _times:
			pv.call("step", t)
			for _i in 3:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img = img.get_region(Rect2i(0, 0, 960, 540))
			var path := "%s/g_%s_%d_%s.png" % [_out, _layer, seed, str(t)]
			img.save_png(path)
			print("  pulsarsheet: seed %d t %s beam %s sky %.3f -> %s" % [seed, str(t), str(pv.get("beam_angle")), float(pv.get("sky_flash")), path])
	get_tree().quit()


## `zoom=` and `at=`, after a setup.
func _zoom_pan(pv: Node2D) -> void:
	if not is_nan(_at.x):
		pv.position = _at
	pv.call("set_zoom", _zoom)


## Every seed and moment at every zoom, whole, in a picture 4x the map's size.
func _zoom_pictures() -> void:
	const SC := 4
	var vp := SubViewport.new()
	vp.size = Vector2i(960 * SC, 540 * SC)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.size = Vector2(vp.size)
	vp.add_child(bg)
	var map := Node2D.new()
	vp.add_child(map)
	var pv: Node2D = PulsarView.new()
	map.add_child(pv)
	if _gas != "":
		pv.call("set_gas", _gas_texture(_gas))
	DirAccess.make_dir_recursive_absolute(_out)
	for seed in _seeds:
		# set up as the game does, at the map's centre over the map's own rect...
		pv.position = Vector2(480, 270)
		pv.call("setup", seed, Rect2(0, 0, 960, 540))
		# ...then the web made to cover the whole picture, and the pulsar carried to its middle
		var web := pv.get("web") as ColorRect
		web.size = Vector2(vp.size)
		var wm := pv.get("_web_mat") as ShaderMaterial
		wm.set_shader_parameter("rect_size", Vector2(vp.size))
		wm.set_shader_parameter("web_on", _layer != "gas")
		web.visible = _layer != "pulsar"
		(pv.get("_box") as CanvasItem).visible = _layer == "pulsar" or _layer == "both"
		pv.position = Vector2(vp.size / 2)
		for t in _times:
			for k in _zooms:
				pv.call("set_zoom", k)
				pv.call("step", t)
				for _i in 3:
					await get_tree().process_frame
				await RenderingServer.frame_post_draw
				var img := vp.get_texture().get_image()
				var path := "%s/z_%s_%d_%s_k%s.png" % [_out, _layer, seed, str(t), str(k)]
				img.save_png(path)
				print("  pulsarsheet: seed %d t %s zoom %s -> %s" % [seed, str(t), str(k), path])


## The mockup's gas brightness, out of its 16-bit PNG into a float texture.
func _gas_texture(path: String) -> Texture2D:
	var src := Image.load_from_file(path)
	var img := Image.create(src.get_width(), src.get_height(), false, Image.FORMAT_RF)
	for y in src.get_height():
		for x in src.get_width():
			var c := src.get_pixel(x, y)
			var v := (c.r8 * 256 + c.g8) / 65535.0 * 4.0
			img.set_pixel(x, y, Color(v, 0, 0))
	return ImageTexture.create_from_image(img)


## GPU time per frame for the pulsar's box and for the web, each drawn
## `copies=` times over (one copy is lost in the noise of a shared GPU), vsync off.
func _time_it(map: Node2D, pv: Node2D) -> void:
	var copies := _copies
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var vp := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	pv.visible = false
	for seed in _seeds:
		var views: Array[Node2D] = []
		for i in copies:
			var v: Node2D = PulsarView.new()
			v.position = CENTRE
			map.add_child(v)
			v.call("setup", seed)
			_zoom_pan(v)
			if _gas != "":
				v.call("set_gas", pv.get("_web_mat").get_shader_parameter("gas_tex"))
			views.append(v)
		var res := {}
		for mode: String in ["none", "box", "web"]:
			for v in views:
				(v.get("_box") as CanvasItem).visible = mode == "box"
				(v.get("web") as CanvasItem).visible = mode == "web"
			for _i in 20:
				await get_tree().process_frame
			var gpu := 0.0
			var n := 120
			for i in n:
				for v in views:
					v.call("step", 3.0 + i / 60.0)
				await get_tree().process_frame
				gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
			res[mode] = gpu / n
		print("  pulsarsheet perf: seed %d %s zoom %s  gpu per copy: box %.3f ms, web %.3f ms (baseline %.3f ms a frame)" % [seed, str(views[0].get("spec").picks), str(_zoom), (res.box - res.none) / copies, (res.web - res.none) / copies, res.none])
		for v in views:
			v.free()
