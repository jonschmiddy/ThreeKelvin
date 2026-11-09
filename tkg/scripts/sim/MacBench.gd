extends Node

## Manual and windowed, not in the gate: it reads the GPU, which a headless run lacks.
## Why: docs/why/MacBench.md#mac-bench

const ALL_SCREENS := ["title", "chart", "map", "map2", "local", "fight", "yard"]
## Samples run 2.5 s because `TIME_PROCESS` is the engine's once-a-second worst.
const MIN_SECS := 2.5

var _args: PackedStringArray
var _rows: Array = []
## Where every screen but the title is: a system with a giant to orbit
## (LOCAL, the map, the fight), and a station whose yard is measured.
var _giant := -1
var _giant_body := -1
var _station := -1
var _game_rid := RID()
var _root_rid := RID()
## The run's galaxy while the title has written its own over it (as
## `chartbench` does: the launcher expects no live run).
var _held_galaxy: Dictionary = {}


func _arg(k: String, d: String = "") -> String:
	for a in _args:
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d


func _ready() -> void:
	_args = OS.get_cmdline_user_args()
	_run.call_deferred()


## Swallows keyboard and mouse: a Tab or HUD click swaps the measured screen (`chartbench` crash).
## Why: docs/why/MacBench.md#input-guard
func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		get_viewport().set_input_as_handled()


func _run() -> void:
	var tree := get_tree()
	await tree.process_frame
	if DisplayServer.get_name() == "headless":
		print("macbench: needs a window (headless has no GPU to read)")
		tree.quit(1)
		return
	tree.root.gui_disable_input = true
	if GameShell.instance != null:
		GameShell.instance.view.gui_disable_input = true
		_game_rid = GameShell.instance.view.get_viewport_rid()
	else:
		_game_rid = get_viewport().get_viewport_rid()
	_root_rid = tree.root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_game_rid, true)
	RenderingServer.viewport_set_measure_render_time(_root_rid, true)
	var scales: Array[int] = []
	for s in _arg("scales", "1,2,3").split(",", false):
		scales.append(int(s))
	var looks := _arg("looks", "flat,crt").split(",", false)
	var gfx := _arg("gfx", "high,low").split(",", false)
	var screens := _arg("screens", ",".join(ALL_SCREENS)).split(",", false)
	var frames := maxi(10, int(_arg("frames", "120")))
	_machine("before")
	Rng.forced = int(_arg("seed", "4242"))
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	_pick_places()
	var done_k: Array[int] = []
	for want in scales:
		var k := await _set_scale(want)
		if k in done_k:
			print("  macbench: %dx asked, %dx is the largest this screen allows and is already measured" % [want, k])
			continue
		done_k.append(k)
		for g in gfx:
			_leave()
			DisplaySettings.set_graphics_low(g == "low")
			for sc in screens:
				if not sc in ALL_SCREENS:
					print("  macbench: no screen '%s' (%s)" % [sc, ", ".join(ALL_SCREENS)])
					continue
				if not await _go(sc):
					print("  macbench: %s could not be shown; skipped" % sc)
					continue
				for l in looks:
					DisplaySettings.set_look(DisplaySettings.Look.FLAT if l == "flat" else DisplaySettings.Look.CRT_GENTLE)
					var row := await _sample(frames)
					row.merge({"scale": k, "gfx": g.to_upper(), "look": l.to_upper(), "screen": sc,
						"window": [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y]})
					_rows.append(row)
					print("  macbench: %s" % _line(row))
	_leave()
	_restore_galaxy()
	_machine("after")
	_table()
	var outp := _arg("out")
	if outp != "":
		var f := FileAccess.open(outp, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(_rows, " "))
			f.close()
			print("wrote ", outp)
	tree.quit()


## The machine, as the frames below were measured on it.
func _machine(when: String) -> void:
	print("\n=== MACBENCH: the machine, %s ===" % when)
	print("  %s" % BuildInfo.line())
	print("  %s %s; CPU %s, %d threads" % [OS.get_name(), OS.get_version(), OS.get_processor_name(), OS.get_processor_count()])
	print("  adapter: %s (%s), API %s" % [RenderingServer.get_video_adapter_name(),
		RenderingServer.get_video_adapter_vendor(), RenderingServer.get_video_adapter_api_version()])
	print("  driver: %s, %s" % [RenderingServer.get_current_rendering_driver_name(), RenderingServer.get_current_rendering_method()])
	var on := DisplayServer.window_get_current_screen()
	print("  screen %d of %d: %s px at %s, scale %.2f, refresh %.0f Hz; largest scale %.2f" % [on + 1,
		DisplayServer.get_screen_count(), DisplayServer.screen_get_size(on), DisplayServer.screen_get_position(on),
		DisplayServer.screen_get_scale(on), DisplayServer.screen_get_refresh_rate(on), DisplayServer.screen_get_max_scale()])
	print("  " + PlaytestLogs.window_line())
	print("  frames: vsync %s, max_fps %d; style %s" % [PlaytestLogs.vsync_name(DisplayServer.window_get_vsync_mode()),
		Engine.max_fps, DisplaySettings.render_style])
	print("  power: " + PlaytestLogs.power_state())
	if OS.get_name() == "macOS":
		var out: Array = []
		if OS.execute("/usr/bin/pmset", ["-g", "therm"], out) == 0 and not out.is_empty():
			for line in String(out[0]).split("\n", false):
				print("  therm: " + line.strip_edges())


## Sets the window as Settings does, and turns vsync and the cap off again after it.
func _set_scale(want: int) -> int:
	DisplaySettings.set_scale(want)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	for _i in 30:
		await RenderingServer.frame_post_draw
	print("\n=== MACBENCH: WINDOW SIZE %dx asked ===" % want)
	print("  " + PlaytestLogs.window_line())
	print("  root viewport %s, vsync %s, max_fps %d" % [get_tree().root.size,
		PlaytestLogs.vsync_name(DisplayServer.window_get_vsync_mode()), Engine.max_fps])
	return DisplaySettings.window_scale


## A system with a ringed giant to orbit, and a station made a city for the costliest yard tick.
func _pick_places() -> void:
	for strict in [true, false]:
		for n: MapGen.MapNode in Run.map:
			if n.type == MapGen.NodeType.STATION or n.type == MapGen.NodeType.START or Router.no_fights_at(n):
				continue
			var Lo := SystemLayout.of(n)
			for i in Lo.bodies.size():
				var b = Lo.bodies[i]
				if b.kind == &"giant" and b.world != &"" and (not strict or bool(Worlds.spec(b.world, b.seed, 100.0).get("ring", false))):
					_giant = n.index
					_giant_body = i
					break
			if _giant >= 0:
				break
		if _giant >= 0:
			break
	for n: MapGen.MapNode in Run.map:
		if n.type == MapGen.NodeType.STATION:
			_station = n.index
			n.development = MapGen.Development.CITY
			break
	if _giant < 0:
		_giant = Run.at
	var g: MapGen.MapNode = Run.map[_giant]
	print("  macbench: map, LOCAL and the fight at node %d %s (giant body %d); the yard at node %d" % [
		_giant, MapGen.star_name(g), _giant_body, _station])


## Set before the map too, as going from map to LOCAL writes the map's ship over it.
func _park() -> void:
	if _giant_body < 0:
		return
	var Lo := SystemLayout.of(Run.map[_giant])
	SystemMapScreen._parked[_giant] = {"at": _giant_body, "p": Vector2(Lo.edge * 1.02, -210.0),
		"v": Vector2.ZERO, "head": 0.0, "mode": &"rail"}


## Out of the fight and off the berth, back at the giant's system: where every
## pass starts.
func _leave() -> void:
	if Router.combat != null:
		Router.combat = null
		Router.current_fight = {}
	Router.docked = false
	Run.at = _giant


func _restore_galaxy() -> void:
	if _held_galaxy.is_empty():
		return
	Run.galaxy = _held_galaxy.galaxy
	Run.galaxy_kind = _held_galaxy.kind
	Run.galaxy_seed = _held_galaxy.seed
	_held_galaxy = {}


## A screen's first second pays its build: a stall worth knowing, but not the screen's cost.
func _settle(s: float) -> void:
	var until := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < until:
		await _frame()


func _headless() -> bool:
	return DisplayServer.get_name() == "headless"


## Drawn with a window, processed headless, where the dummy renderer never emits `frame_post_draw`.
func _frame() -> void:
	if _headless():
		await get_tree().process_frame
	else:
		await RenderingServer.frame_post_draw


## Show screen `sc` and wait for it to settle. False when it could not be shown.
func _go(sc: String) -> bool:
	if sc != "title":
		_restore_galaxy()
	match sc:
		"title":
			_leave()
			# THE TITLE'S OWN GALAXY, the same one every run: it is rolled off the
			# global generator, once a process (`chartbench`)
			_held_galaxy = {"galaxy": Run.galaxy.duplicate(true), "kind": Run.galaxy_kind, "seed": Run.galaxy_seed}
			LauncherScreen._sky_kind = -1
			seed(4242)
			Router.show_launcher()
			await _settle(2.0)
			var ls := Router.current as LauncherScreen
			if ls == null:
				return false
			var t0 := Time.get_ticks_msec()
			while not _headless() and ls._sky != null and not (ls._sky._sky as ChartSky).ready_to_draw() and Time.get_ticks_msec() - t0 < 20000:
				await RenderingServer.frame_post_draw
			await _settle(0.5)
			return Router.current is LauncherScreen
		"chart":
			Router.show_starchart()
			await _settle(2.0)
			var cs := Router.current as StarchartScreen
			if cs == null or cs._chart == null:
				return false
			var t1 := Time.get_ticks_msec()
			var sky = cs._chart.get("_sky")
			while not _headless() and sky != null and is_instance_valid(sky) and not (sky as ChartSky).ready_to_draw() and Time.get_ticks_msec() - t1 < 20000:
				await RenderingServer.frame_post_draw
			await _settle(0.5)
			return Router.current is StarchartScreen
		"map":
			Run.at = _giant
			_park()
			Router.show_system()
			var scr := Router.current as SystemMapScreen
			if scr == null:
				return false
			var t2 := Time.get_ticks_msec()
			while not _headless() and not bool(scr.view._palette_built) and Time.get_ticks_msec() - t2 < 15000:
				await RenderingServer.frame_post_draw
			await _settle(1.5)
			return Router.current is SystemMapScreen
		"map2":
			if not (Router.current is SystemMapScreen):
				if not await _go("map"):
					return false
			var m := Router.current as SystemMapScreen
			# (as `SystemSheet._aim`: the camera put there, about the star)
			m._glide = {}
			m._zoom_to = 2.0
			m.view.zoom = 2.0
			m.view.pan = Vector2.ZERO
			await _settle(1.5)
			return Router.current is SystemMapScreen
		"local":
			Run.at = _giant
			_park()
			SectorScreen._approached_at = _giant
			Router.show_local()
			await _settle(3.0)
			if Run.site_here() != _giant_body:
				print("  macbench: LOCAL is at body %d, not the giant (%d)" % [Run.site_here(), _giant_body])
			return Router.current is SectorScreen
		"fight":
			if not (Router.current is SectorScreen) or Router.in_combat():
				if not await _go("local"):
					return false
			Router.start_combat(DB.enemies[&"cutter"], [], false)
			await _settle(3.0)
			return Router.in_combat() and Router.current is SectorScreen
		"yard":
			if _station < 0:
				return false
			_leave()
			Run.at = _station
			Router.park_at_station(Run.map[_station])
			Router.show_station()
			await _settle(4.0)
			return Router.current is StationScreen
	return false


## The screen as it stands, over n frames (and at least MIN_SECS).
func _sample(n: int) -> Dictionary:
	var subs: Array[RID] = []
	for vp: Node in get_tree().root.find_children("*", "SubViewport", true, false):
		var rid := (vp as SubViewport).get_viewport_rid()
		if rid == _game_rid:
			continue
		RenderingServer.viewport_set_measure_render_time(rid, true)
		subs.append(rid)
	# The frame cut in two: process and draw start on the real clock; draw ends after the swap.
	var mark := {"proc": 0, "pre": 0}
	var on_proc := func() -> void: mark.proc = Time.get_ticks_usec()
	var on_pre := func() -> void: mark.pre = Time.get_ticks_usec()
	get_tree().process_frame.connect(on_proc)
	RenderingServer.frame_pre_draw.connect(on_pre)
	for _i in 15:
		await RenderingServer.frame_post_draw
	var last := PackedFloat64Array()
	for rid in subs:
		last.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
	var times: Array[float] = []
	var proc := 0.0
	var draw := 0.0
	var root := 0.0
	var game := 0.0
	var sub := 0.0
	var drawn := 0
	var rcpu := 0.0
	var calls := 0.0
	var last_cpu := PackedFloat64Array()
	for rid in subs:
		last_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
	var prev := Time.get_ticks_usec()
	var until := prev + int(MIN_SECS * 1000000.0)
	while times.size() < n or Time.get_ticks_usec() < until:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		times.append(float(now - prev) / 1000.0)
		prev = now
		proc += float(int(mark.pre) - int(mark.proc)) / 1000.0
		draw += float(now - int(mark.pre)) / 1000.0
		root += RenderingServer.viewport_get_measured_render_time_gpu(_root_rid)
		game += RenderingServer.viewport_get_measured_render_time_gpu(_game_rid)
		rcpu += RenderingServer.viewport_get_measured_render_time_cpu(_root_rid)
		rcpu += RenderingServer.viewport_get_measured_render_time_cpu(_game_rid)
		for j in subs.size():
			var v := RenderingServer.viewport_get_measured_render_time_gpu(subs[j])
			var c := RenderingServer.viewport_get_measured_render_time_cpu(subs[j])
			# (drawn this frame: either stamp moved)
			if v != last[j] or c != last_cpu[j]:
				sub += v
				rcpu += c
				drawn += 1
			last[j] = v
			last_cpu[j] = c
		calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	get_tree().process_frame.disconnect(on_proc)
	RenderingServer.frame_pre_draw.disconnect(on_pre)
	# (the engine's: the worst process + draw of the last whole second)
	var tproc := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	n = times.size()
	var sorted := times.duplicate()
	sorted.sort()
	var mean := 0.0
	for t in times:
		mean += t
	mean /= float(n)
	var f := float(n)
	return {
		"frames": n,
		"frame_mean": snappedf(mean, 0.01),
		"frame_p50": snappedf(sorted[n / 2], 0.01),
		"frame_p95": snappedf(sorted[mini(n - 1, int(f * 0.95))], 0.01),
		"frame_max": snappedf(sorted[n - 1], 0.01),
		"proc": snappedf(proc / f, 0.01),
		"draw": snappedf(draw / f, 0.01),
		"time_process": snappedf(tproc, 0.01),
		"render_cpu": snappedf(rcpu / f, 0.01),
		"gpu_root": snappedf(root / f, 0.01),
		"gpu_game": snappedf(game / f, 0.01),
		"gpu_other": snappedf(sub / f, 0.01),
		"other_viewports": snappedf(float(drawn) / f, 0.1),
		"draw_calls": int(round(calls / f)),
	}


func _line(r: Dictionary) -> String:
	return "%dx %-4s %-4s %-6s frame p50 %6.2f p95 %6.2f max %6.2f ms (%.0f fps, %d frames) | proc %5.2f, draw %5.2f (render cpu %5.2f), TIME_PROCESS %6.2f | GPU window %5.2f, game %5.2f, other %6.2f (%.1f vp) | %d draws" % [
		r.scale, r.gfx, r.look, r.screen, r.frame_p50, r.frame_p95, r.frame_max, 1000.0 / maxf(0.01, r.frame_mean), r.frames,
		r.proc, r.draw, r.render_cpu, r.time_process, r.gpu_root, r.gpu_game, r.gpu_other, r.other_viewports, r.draw_calls]


func _table() -> void:
	print("\n=== MACBENCH: every sample (ms; proc and draw are means a frame, tproc the engine's TIME_PROCESS, the worst process + draw of a second; GPU per pass: the window's, the game view's, every other viewport drawn) ===")
	print("  scale gfx  look screen   p50    p95    max   proc   draw  rcpu   tproc gpu-win gpu-game gpu-other draws")
	var gpu_seen := false
	for r: Dictionary in _rows:
		print("  %dx    %-4s %-4s %-6s %6.2f %6.2f %6.2f %6.2f %6.2f %5.2f %7.2f %7.2f %8.2f %9.2f %5d" % [r.scale, r.gfx, r.look, r.screen,
			r.frame_p50, r.frame_p95, r.frame_max, r.proc, r.draw, r.render_cpu, r.time_process,
			r.gpu_root, r.gpu_game, r.gpu_other, r.draw_calls])
		if float(r.gpu_root) + float(r.gpu_game) + float(r.gpu_other) > 0.0:
			gpu_seen = true
	if not _rows.is_empty() and not gpu_seen:
		print("  NOTE: every GPU reading was 0: this driver (%s, API %s) gave the engine no GL timestamps." % [
			RenderingServer.get_current_rendering_driver_name(), RenderingServer.get_video_adapter_api_version()])
		print("  Read the frame times (vsync is off, so a frame lasts as long as its slowest side): a draw well over rcpu is the driver waiting on the GPU.")
