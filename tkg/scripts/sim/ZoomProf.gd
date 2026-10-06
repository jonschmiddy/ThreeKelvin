extends Node

## Where the sector map's frame time goes while the camera moves:
##   godot --path . -- sheet=ZoomProf [node=I] [seed=N]
## Shows a system on the real screen and, for each test, runs 240 frames:
## held still, zooming in and out without stopping, and panning without
## stopping. Prints the frame time (mean and slowest tenth), the CPU in the
## map's own GDScript by part, and the GPU time of the map's two pictures.
## `wev=<name>` (or `a+b`, a pair) holds that weather event at its height (`SkyWeather.PEAK`)
## through every test, after a still run with no weather at all, and prints
## what it added to the scene's GPU time.

const ScreenS := preload("res://scripts/ui/sysmap/SystemMapScreen.gd")

var _scr


func _ready() -> void:
	Rng.forced = 4242
	var idx := -1
	var wev := ""
	for a in OS.get_cmdline_user_args():
		var s := a as String
		if s.begins_with("node="):
			idx = int(s.substr(5))
		elif s.begins_with("seed="):
			Rng.forced = int(s.substr(5))
		elif s.begins_with("wev="):
			wev = s.substr(4)
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
	# `nebkind=K`: the system's cloud made kind K (no emission cloud rolls on seed 4242)
	for a2 in OS.get_cmdline_user_args():
		if (a2 as String).begins_with("nebkind="):
			var cl2 = NebulaField.at(n.gal) if n.in_nebula else null
			if cl2 != null:
				cl2.kind = int((a2 as String).substr(8)) as NebulaField.Kind
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
	# (PAINTED draws its far picture and its band memory in viewports of their
	# own, inside the place's: counted with it)
	for k in ["svp", "tvp"]:
		if _scr.view._pt.has(k):
			RenderingServer.viewport_set_measure_render_time((_scr.view._pt[k] as SubViewport).get_viewport_rid(), true)
	var none_gpu := -1.0
	if wev != "":
		# THE WEATHER HELD AT ITS HEIGHT, against the same sky with none
		var W = _scr.view._weather
		W.auto = false
		_scr.view._nova.auto = false
		DisplaySettings.reduced_motion = false
		while not _scr.view._palette_built:
			await get_tree().process_frame
		for _i in 70:
			await get_tree().process_frame
		none_gpu = await _run("still, no weather", func(_k: int) -> void: pass)
		# (`a+b` holds two: a slot-A event and a slot-B one, the worst pair)
		for one in wev.split("+"):
			var err: String = W.force(StringName(one))
			if err != "":
				print("  zoomprof: " + err)
		W.hold = true
	var still_gpu: float = await _run("still" + (" with %s held" % wev if wev != "" else ""), func(_k: int) -> void: pass)
	if none_gpu >= 0.0:
		print("  zoomprof: weather %s at its height adds %.3f ms to the scene's GPU time (%.3f against %.3f)" % [wev, still_gpu - none_gpu, still_gpu, none_gpu])
	await _run("zooming", func(k: int) -> void:
		_scr._zoom_to = 4.0 if (k / 40) % 2 == 0 else _scr.zoom_min)
	_scr._zoom_to = 2.5
	for _i in 60:
		await get_tree().process_frame
	await _run("panning at 2.5x", func(k: int) -> void:
		_scr.view.pan += Vector2(3.0 if (k / 60) % 2 == 0 else -3.0, 0.0))
	# THE SHIP FLOWN, zoomed out: W held and a turn, so the flight steps and its
	# dotted line is run forward every frame
	_scr._zoom_to = _scr.zoom_min
	_scr.view.pan = Vector2.ZERO
	for _i in 60:
		await get_tree().process_frame
	_scr.harness_keys = true
	await _run("flying (W held, the line run)", func(k: int) -> void:
		_scr._wasd = {"w": true, "a": false, "s": false, "d": (k / 50) % 2 == 0})
	_scr._wasd = {"w": false, "a": false, "s": false, "d": false}
	await _run("coasting (the line run)", func(_k: int) -> void: pass)
	get_tree().quit()


func _run(label: String, each: Callable) -> float:
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
		for kk in ["svp", "tvp"]:
			if _scr.view._pt.has(kk):
				gpu_scene += RenderingServer.viewport_get_measured_render_time_gpu((_scr.view._pt[kk] as SubViewport).get_viewport_rid())
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
		print("  zoomprof:     %-14s %.3f ms a frame" % [key, float(parts[key]) / 240.0 / 1000.0])
	return gpu_scene / 240.0
