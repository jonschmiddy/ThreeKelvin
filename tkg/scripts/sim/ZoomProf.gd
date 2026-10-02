extends Node

## Where the sector map's frame time goes while the camera moves:
##   godot --path . -- sheet=ZoomProf [node=I] [seed=N]
## Shows a system on the real screen and, for each test, runs 240 frames:
## held still, zooming in and out without stopping, and panning without
## stopping. Prints the frame time (mean and slowest tenth), the CPU in the
## map's own GDScript by part, and the GPU time of the map's two pictures.

const ScreenS := preload("res://scripts/ui/sysmap/SystemMapScreen.gd")

var _scr


func _ready() -> void:
	Rng.forced = 4242
	var idx := -1
	for a in OS.get_cmdline_user_args():
		var s := a as String
		if s.begins_with("node="):
			idx = int(s.substr(5))
		elif s.begins_with("seed="):
			Rng.forced = int(s.substr(5))
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var n: MapGen.MapNode = null
	if idx >= 0:
		n = Run.map[idx]
	else:
		for raw in Run.map:
			var m: MapGen.MapNode = raw
			OptionTable.ensure(m)
			if m.type == MapGen.NodeType.SYSTEM and m.options.size() >= 3:
				n = m
				break
	var content := Control.new()
	content.position = Vector2(8, 32)
	content.size = Vector2(944, 501)
	add_child(content)
	_scr = ScreenS.new()
	content.add_child(_scr)
	await _scr.show_system(n, 30.0)
	for _i in 30:
		await get_tree().process_frame
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	RenderingServer.viewport_set_measure_render_time(_scr._vp.get_viewport_rid(), true)
	RenderingServer.viewport_set_measure_render_time(_scr.view._scene.get_viewport_rid(), true)
	await _run("still", func(_k: int) -> void: pass)
	await _run("zooming", func(k: int) -> void:
		_scr._zoom_to = 4.0 if (k / 40) % 2 == 0 else 1.0)
	_scr._zoom_to = 2.5
	for _i in 60:
		await get_tree().process_frame
	await _run("panning at 2.5x", func(k: int) -> void:
		_scr.view.pan += Vector2(3.0 if (k / 60) % 2 == 0 else -3.0, 0.0))
	get_tree().quit()


func _run(label: String, each: Callable) -> void:
	var SV = _scr.view.get_script()
	SV.prof = {}
	SV.prof_on = true
	var times: Array[float] = []
	var gpu_scene := 0.0
	var gpu_map := 0.0
	var gpu_root := 0.0
	var last := Time.get_ticks_usec()
	for k in 240:
		each.call(k)
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		times.append(float(now - last) / 1000.0)
		last = now
		gpu_scene += RenderingServer.viewport_get_measured_render_time_gpu(_scr.view._scene.get_viewport_rid())
		gpu_map += RenderingServer.viewport_get_measured_render_time_gpu(_scr._vp.get_viewport_rid())
		gpu_root += RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())
	SV.prof_on = false
	var sorted := times.duplicate()
	sorted.sort()
	var mean := 0.0
	for t in times:
		mean += t
	mean /= times.size()
	var slow: float = sorted[int(sorted.size() * 0.9)]
	print("  zoomprof: %s: frame %.1f ms mean, %.1f ms slowest tenth; GPU scene %.2f, map %.2f, window %.2f ms" % [label, mean, slow, gpu_scene / 240.0, gpu_map / 240.0, gpu_root / 240.0])
	var parts: Dictionary = SV.prof
	var keys := parts.keys()
	keys.sort()
	for key in keys:
		print("  zoomprof:     %-14s %.2f ms a frame" % [key, float(parts[key]) / 240.0 / 1000.0])
