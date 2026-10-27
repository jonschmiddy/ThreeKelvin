extends Node

## THE SECTOR MAP'S KEPT POLISH, filmed before and after at the same moment:
##   godot --path . -- sheet=WowClip out=<dir> [kind=ordinary|red|blue|nebula|station|node:<i>]
##     [seed=N] [zoom=Z|open] [aim=star|world|belt|<i>] [t0=S] [secs=8]
##     [wow=glints,orbitdepth,sunfix] [ab] [cost=N] [zoomto=Z2|open] [style=...]
## Opens the system on the real map screen (as `SystemSheet`'s sweep does: Main's
## frame and theme, the weather and the far novae held off), aims the camera,
## and films `secs` seconds at 30 frames a second with the map's clock stepped a
## thirtieth a frame: `<out>/f_NNNN.png`, the map window in game pixels. With
## `ab` it films them before and after, interleaved frame by frame at the same
## clock (`<out>/before/`, `<out>/after/`): the things named in `wow=` taken out
## for the before -- the belts' glints (`SystemView.belt_glints`), the orbits'
## near half (`SystemView.orbit_depth`), the sun's zoom cap past 4
## (`SunView.k_max` 4 before, 9 after) -- so the two differ only by them.
## `zoomto=Z2` eases the zoom from Z to Z2 over the clip (zooming must only
## magnify). `cost=N` then times N frames before and N after, four times over,
## alternating, the clock running: the place picture's GPU time, the window's,
## and the map's own CPU time (its profiler). `list` prints every system's
## bodies, headless. Needs a window (but for `list`).

const ScreenS := preload("res://scripts/ui/sysmap/SystemMapScreen.gd")
const SystemViewS := preload("res://scripts/ui/sysmap/SystemView.gd")
const SunViewS := preload("res://scripts/ui/sysmap/SunView.gd")

var _scr: Control
var _aim_kind := "star"
var _aim_i := -9
var _want: PackedStringArray = []


## The things asked for (`wow=`) out (the before) or in (the after).
func _switch(on: bool) -> void:
	if "glints" in _want:
		SystemViewS.belt_glints = on
	if "orbitdepth" in _want:
		SystemViewS.orbit_depth = on
	if "sunfix" in _want:
		SunViewS.k_max = 9.0 if on else 4.0


func _arg(name: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with(name + "="):
			return (a as String).substr(name.length() + 1)
	return fallback


func _ready() -> void:
	Rng.forced = int(_arg("seed", "4242"))
	var out := _arg("out", "user://wow")
	var kind := _arg("kind", "ordinary")
	var z0 := float(_arg("zoom", "1.0"))
	var z1 := float(_arg("zoomto", str(z0)))
	var t0 := float(_arg("t0", "30"))
	var secs := float(_arg("secs", "8"))
	var ab := "ab" in OS.get_cmdline_user_args()
	var ncost := int(_arg("cost", "0"))
	_want = _arg("wow", "").split(",", false)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	if "list" in OS.get_cmdline_user_args():
		# every system: its star, sky, and what its bodies are (belts, worlds)
		for raw in Run.map:
			var m: MapGen.MapNode = raw
			var L := SystemLayout.of(m)
			var kinds: Array = []
			for b: SystemLayout.Body in L.bodies:
				kinds.append("%s%s" % [b.kind, (":" + String(b.world)) if b.world != &"" else ""])
			print("  node %d type %d star %d neb %s: %s" % [m.index, m.type, m.star, m.in_nebula, ", ".join(kinds)])
		get_tree().quit()
		return
	var n: MapGen.MapNode = _pick(kind)
	if n == null:
		print("  wowclip: no %s system in this run" % kind)
		get_tree().quit()
		return
	get_viewport().gui_disable_input = true
	var content := Control.new()
	var main := get_parent() as Control
	content.theme = main.theme if main != null and main.theme != null else UITheme.build()
	content.position = Vector2(8, 32)
	content.size = Vector2(944, 501)
	add_child(content)
	_scr = ScreenS.new()
	content.add_child(_scr)
	_scr.frozen = true
	Audio.room(&"", 0.01)
	Run.at = n.index
	OptionTable.ensure(n)
	_scr.view.hclock = t0
	await _scr.show_system(n, t0)
	_scr.frozen = true
	_scr._location_on = false
	_scr.overlay.ship_park = 0
	_scr._was_at = _scr.flight.reached()
	_scr.panel.show_system()
	if _scr.view._weather != null:
		_scr.view._weather.auto = false
	if _scr.view._nova != null:
		_scr.view._nova.auto = false
	while not _scr.view._palette_built:
		await get_tree().process_frame
	for _i in 4:
		await get_tree().process_frame
	# (`zoom=open`, `zoomto=open`: the zoom the map opens at)
	if _arg("zoom", "") == "open":
		z0 = _scr.zoom_min
	if _arg("zoomto", "") == "open":
		z1 = _scr.zoom_min
	elif _arg("zoomto", "") == "":
		z1 = z0
	_pick_aim(_arg("aim", "star"))
	print("  wowclip: %s system %d, %d bodies, zoom %.2f..%.2f, aim %s (%d)" % [kind, n.index, _scr.view.layout.bodies.size(), z0, z1, _aim_kind, _aim_i])
	var frames := int(secs * 30.0)
	if ab:
		await _film_ab(out, t0, z0, z1, frames)
	else:
		await _film(out, t0, z0, z1, frames)
	if ncost > 0:
		await _costs(t0, z0, ncost)
	get_tree().quit()


## The system of that kind in this run, as `SystemSheet` finds them.
func _pick(kind: String) -> MapGen.MapNode:
	if kind.begins_with("node:"):
		return Run.map[int(kind.substr(5))]
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		match kind:
			"pulsar":
				if n.type == MapGen.NodeType.PULSAR:
					return n
			"station":
				if n.type == MapGen.NodeType.STATION:
					return n
			"nebula":
				if n.type == MapGen.NodeType.SYSTEM and n.in_nebula:
					return n
			"red":
				if n.type == MapGen.NodeType.SYSTEM and not n.in_nebula and n.star == MapGen.Star.RED and n.gas_giant:
					return n
			"blue":
				if n.type == MapGen.NodeType.SYSTEM and not n.in_nebula and n.star == MapGen.Star.BLUE:
					return n
			"ordinary":
				if n.type == MapGen.NodeType.SYSTEM and not n.in_nebula and n.star == MapGen.Star.ORDINARY:
					OptionTable.ensure(n)
					if n.options.size() >= 2:
						return n
	return null


func _pick_aim(a: String) -> void:
	var v = _scr.view
	_aim_kind = a
	if a == "star":
		_aim_i = -9
	elif a == "world" or a == "town":
		var best := -1.0
		for i: int in v._views:
			var b: SystemLayout.Body = v.layout.bodies[i]
			var sc := b.r + (100.0 if b.kind == &"giant" else 0.0)
			if a == "town":
				var spec: Dictionary = v._views[i].get("spec") if v._views[i].get("spec") != null else {}
				sc = float((spec.get("towns", []) as Array).size()) + float(spec.get("moons", 0)) * 0.1
			if sc > best:
				best = sc
				_aim_i = i
		_aim_kind = "world"
	elif a == "belt":
		for b: SystemLayout.Body in v.layout.bodies:
			if b.kind == &"belt":
				_aim_i = b.index
				break
	else:
		_aim_i = int(a)
		_aim_kind = "world"


## The camera at zoom z on the aim, now.
func _aim(z: float) -> void:
	var v = _scr.view
	_scr._zoom_to = z
	v.zoom = z
	if _aim_kind == "belt" and _aim_i >= 0:
		# the belt's near side, a little toward the sun's left, where its rocks
		# are lit and seen against the dark
		var b: SystemLayout.Body = v.layout.bodies[_aim_i]
		var a := PI * 0.62
		v.pan = -Vector2(cos(a) * b.orbit, sin(a) * b.orbit * v.TILT) * z
	elif _aim_kind == "world" and _aim_i >= 0:
		v.pan = -_scr.overlay.place_rel(_aim_i)
	else:
		v.pan = Vector2.ZERO


func _grab() -> Image:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var w: Rect2 = _scr.view.window
	var o: Vector2 = _scr._box.get_global_transform_with_canvas().origin
	return img.get_region(Rect2i(Vector2i(o + w.position), Vector2i(w.size)))


func _clock(t: float) -> void:
	_scr.view.t = t
	_scr.view.hclock = t


func _film(dir: String, t0: float, z0: float, z1: float, frames: int) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	_clock(t0)
	_aim(z0)
	for _i in 20:
		_clock(t0)
		_aim(z0)
		await get_tree().process_frame
	for k in frames:
		var u := float(k) / float(maxi(frames - 1, 1))
		_clock(t0 + float(k) / 30.0)
		_aim(z0 * pow(z1 / z0, smoothstep(0.0, 1.0, u)))
		(await _grab()).save_png(dir.path_join("f_%04d.png" % k))
	print("  wowclip: %d frames to %s" % [frames, dir])


## BEFORE AND AFTER INTERLEAVED, frame by frame at the same clock: the switches
## off for one frame and on for the next. (Filmed one after the other, the
## ship's own flight -- on the frame's clock, not the map's -- was somewhere else
## in each.) Run with `--fixed-fps 60`: the two frames of each step are one
## thirtieth of a second of the ship's flight between them, as a 30 fps film.
func _film_ab(dir: String, t0: float, z0: float, z1: float, frames: int) -> void:
	var db := dir.path_join("before")
	var da := dir.path_join("after")
	DirAccess.make_dir_recursive_absolute(db)
	DirAccess.make_dir_recursive_absolute(da)
	for _i in 20:
		_clock(t0)
		_aim(z0)
		await get_tree().process_frame
	for k in frames:
		var u := float(k) / float(maxi(frames - 1, 1))
		for pass_i in 2:
			_switch(pass_i == 1)
			_clock(t0 + float(k) / 30.0)
			_aim(z0 * pow(z1 / z0, smoothstep(0.0, 1.0, u)))
			(await _grab()).save_png((db if pass_i == 0 else da).path_join("f_%04d.png" % k))
			if k == 0 and pass_i == 0:
				print("  wowclip: drawn at zoom %.3f pan %s" % [_scr.view.zoom, _scr.view.pan])
	_switch(true)
	print("  wowclip: %d frames before and after to %s" % [frames, dir])


func _costs(t0: float, z0: float, n: int) -> void:
	var rid: RID = _scr.view._scene.get_viewport_rid()
	# THE GAME VIEW, NOT THE WINDOW: this runs inside the game's SubViewport, so
	# `get_viewport()` is the 960x540 frame. It printed as `window_gpu` until
	# Oct 27; the window (`get_tree().root`, the shell's glass) is its own column.
	var game := get_viewport().get_viewport_rid()
	var root := get_tree().root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	RenderingServer.viewport_set_measure_render_time(game, true)
	RenderingServer.viewport_set_measure_render_time(root, true)
	# (the CPU side by the map's own profiler, `SystemView.tick`: the process
	# monitor swings by tens of ms here while other renders share the machine)
	var SV = _scr.view.get_script()
	SV.prof_on = true
	var sums := {"off": [0.0, 0.0, 0.0, 0, 0.0], "on": [0.0, 0.0, 0.0, 0, 0.0]}
	var tk := t0
	for rep in 4:
		for which: String in ["off", "on"]:
			_switch(which == "on")
			for _w in 10:
				tk += 1.0 / 30.0
				_clock(tk)
				_aim(z0)
				await get_tree().process_frame
			for _i in n:
				tk += 1.0 / 30.0
				_clock(tk)
				_aim(z0)
				SV.prof.clear()
				await RenderingServer.frame_post_draw
				var s: Array = sums[which]
				s[0] += RenderingServer.viewport_get_measured_render_time_gpu(rid)
				s[1] += RenderingServer.viewport_get_measured_render_time_gpu(game)
				s[4] += RenderingServer.viewport_get_measured_render_time_gpu(root)
				var us := 0
				for key: String in SV.prof:
					# (the parts inside "step (all)" are counted by it)
					if key in ["step (all)", "belts", "lines draw"]:
						us += int(SV.prof[key])
				s[2] += float(us) / 1000.0
				s[3] += 1
	SV.prof_on = false
	for which: String in ["off", "on"]:
		var s: Array = sums[which]
		var c := float(s[3])
		print("  wowclip cost %s: scene_gpu %.3f ms  game_view_gpu %.3f ms  root_gpu %.3f ms  map_cpu %.3f ms  (%d frames)" % [which, s[0] / c, s[1] / c, s[4] / c, s[2] / c, s[3]])
	var a: Array = sums.off
	var b: Array = sums.on
	print("  wowclip cost delta: gpu (scene + game view) %+.3f ms  root %+.3f ms  cpu %+.3f ms" % [(b[0] + b[1] - a[0] - a[1]) / float(a[3]), (b[4] - a[4]) / float(a[3]), (b[2] - a[2]) / float(a[3])])
