extends RefCounted

## Needs a window: under `--headless` the dummy display server never emits `frame_post_draw`.
## Measured in frame time, not fps: fps is a rate and the thing being fixed is a cost.
## Why: docs/why/ChartBench.md#chart-bench

const FRAMES := 240

var _gpu_rid := RID()
## The window's own pass beside the game's frame (Oct 27): on Retina it is 3x the game's pixels.
var _root_rid := RID()
var _measuring := false


func run(tree: SceneTree) -> void:
	# `style=` and `graphics=low` are read by DisplaySettings; `calm` turns
	# reduced motion on in memory (the events off)
	DisplaySettings.reduced_motion = "calm" in OS.get_cmdline_user_args()
	await tree.process_frame
	# VSYNC off, or every reading is 16.67 ms and the bench measures the monitor.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	# Input off while measuring: a Tab or HUD click freed the chart (the 'previously freed' crash).
	# Why: docs/why/ChartBench.md#bench-input
	tree.root.gui_disable_input = true
	StarchartScreen.MapChart.prof = true
	if GameShell.instance != null:
		_gpu_rid = GameShell.instance.view.get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(_gpu_rid, true)
	_root_rid = tree.root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_root_rid, true)
	# `Rng.forced`, not `Rng.reseed`: `start_new_run` rolls its own seed, so galaxies differed.
	# Why: docs/why/ChartBench.md#bench-seed
	Rng.forced = 4242
	Run.start_new_run(&"korvan", 1)
	# `kind=N`: the run's galaxy made that kind (as ChartLook's), to time one kind
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with("kind="):
			Run.galaxy_kind = clampi(int((a as String).substr(5)), 0, GalaxyGen.count() - 1)
			Run.galaxy = GalaxyGen.roll(Run.galaxy_kind)
			Run.map = MapGen.generate(Run.MAP_CANVAS)
			Run.at = 0
			Run.trail = PackedInt32Array([0])
			Run._range_cache.clear()
			Run.chart_from(Run.node_at())
	Router.show_starchart()
	for i in 90:
		await RenderingServer.frame_post_draw

	# Title first and seeded: it draws the same galaxy and had the worst reported frame rate.
	# The run's galaxy is put back after: the launcher overwrote `Run.galaxy` and skewed samples.
	# Why: docs/why/ChartBench.md#bench-title-screen
	var run_galaxy: Dictionary = Run.galaxy.duplicate(true)
	var run_kind: int = Run.galaxy_kind
	var run_seed: int = Run.galaxy_seed
	LauncherScreen._sky_kind = -1
	seed(4242)
	Router.show_launcher()
	# Warmed by the clock, not a frame count: `_build_stars()` costs 350 to 420 ms.
	var warm := Time.get_ticks_msec()
	while Time.get_ticks_msec() - warm < 2000:
		await RenderingServer.frame_post_draw
	var ls := Router.current as LauncherScreen
	# and until the title's own galaxy is baked
	while ls != null and ls._sky != null and not (ls._sky._sky as ChartSky).ready_to_draw() 			and Time.get_ticks_msec() - warm < 20000:
		await RenderingServer.frame_post_draw
	for i in 30:
		await RenderingServer.frame_post_draw
	if ls != null and ls._sky != null:
		var tsky: ChartSky = ls._sky._sky
		print("  title sky: key %s, baked %s, drawing %s, visible %s" % [tsky._key, tsky.ready_baked(), tsky.ready_to_draw(), ls._sky.visible])
	var title := await _sample(tree, null, "", "title", _sky_rid(ls._sky if ls != null else null))

	Run.galaxy = run_galaxy
	Run.galaxy_kind = run_kind
	Run.galaxy_seed = run_seed
	Router.show_starchart()
	for i in 60:
		await RenderingServer.frame_post_draw
	var chart := (Router.current as StarchartScreen)._chart
	if chart == null:
		print("no chart")
		tree.quit()
		return
	_watch(chart)

	_measuring = true
	var sky := _sky_rid(chart)
	var still := await _sample(tree, chart, "", "still", sky)
	var dragged := await _sample(tree, chart, "drag", "drag", sky)
	var zoomed := await _sample(tree, chart, "zoom", "zoom", sky)
	# Still at every depth: the sky works every block afresh each frame, and does more deep in it.
	var depths := []
	for z: float in [1.0, 2.9, 6.0]:
		chart._go_to(z, Vector2.ZERO, false)
		depths.append([z, await _sample(tree, chart, "", "still at %.1f" % z, sky)])
	_measuring = false

	print("\n=== CHART ===")
	print("  %d systems on the map" % Run.map.size())
	for row in [["title", title], ["still", still], ["dragging", dragged],
			["zooming", zoomed]]:
		var ms: float = row[1]
		print("  %-9s %.2f ms/frame  (%.0f fps)" % [row[0], ms, 1000.0 / maxf(0.01, ms)])
	print("  the drag costs %.2f ms a frame, the zoom %.2f" % [dragged - still, zoomed - still])
	for d in depths:
		print("  still at zoom %.1f: %.2f ms/frame" % [d[0], d[1]])

	# A look as well: a stopwatch cannot see a misplaced sky or a trailing edge out of stars.
	Router.show_launcher()
	for i in 30:
		await RenderingServer.frame_post_draw
	_save(tree, "user://bench_title.png")
	Run.galaxy = run_galaxy
	Run.galaxy_kind = run_kind
	Run.galaxy_seed = run_seed
	Router.show_starchart()
	for i in 30:
		await RenderingServer.frame_post_draw
	_save(tree, "user://bench_chart.png")
	# A NEW chart: showing the launcher freed the one measured above, and
	# reusing that reference is a use-after-free the engine catches for you.
	chart = (Router.current as StarchartScreen)._chart
	# Mid-drag, and far enough to have crossed the margin at least once.
	for i in 90:
		_nudge(chart, 0)
		await RenderingServer.frame_post_draw
	_save(tree, "user://bench_drag.png")
	print("  shots: " + ProjectSettings.globalize_path("user://"))
	tree.quit()


## Reports if the chart leaves the tree mid-measure: a freed chart is a use-after-free.
func _watch(chart: Node) -> void:
	chart.tree_exiting.connect(func() -> void:
		if _measuring:
			print("  !! the measured chart left the tree mid-sample; Router.current is %s"
				% Router.current))


func _save(tree: SceneTree, path: String) -> void:
	tree.root.get_texture().get_image().save_png(path)


## The sky draws into its own viewports, whose GPU time the game's view excludes.
## Why: docs/why/ChartBench.md#bench-sampling
func _sky_rid(chart: Node) -> Array[RID]:
	var out: Array[RID] = []
	if chart == null or not is_instance_valid(chart):
		return out
	var sky: ChartSky = chart.get("_sky")
	if sky == null:
		return out
	var vps: Array = []
	if sky._legacy != null:
		if sky._legacy._vp == null:
			return out
		vps = [sky._legacy._vp]
	elif sky._vp == null:
		return out
	else:
		vps = [sky._svp, sky._pvp, sky._vp] + ([sky._tvp] if sky._tvp != null else [])
	for vp: SubViewport in vps:
		var rid := vp.get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(rid, true)
		out.append(rid)
	return out


func _sample(tree: SceneTree, chart: Node, move: String, label := "", sky_rid: Array[RID] = []) -> float:
	for i in 20:
		if not await _step(chart, move, i):
			return -1.0
	StarchartScreen.MapChart.prof_us.clear()
	var gpu := 0.0
	var gpu_root := 0.0
	var gpu_sky := 0.0
	var t0 := Time.get_ticks_usec()
	for i in FRAMES:
		if not await _step(chart, move, i):
			return -1.0
		if _gpu_rid.is_valid():
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(_gpu_rid)
		gpu_root += RenderingServer.viewport_get_measured_render_time_gpu(_root_rid)
		for r in sky_rid:
			gpu_sky += RenderingServer.viewport_get_measured_render_time_gpu(r)
	var t1 := Time.get_ticks_usec()
	# Counts what the frame submitted: commands resubmit every frame, even if repaint is skipped.
	print("      [%s] %d draw calls, %.0fk primitives a frame, GPU game view %.2f ms (the sky's own viewport %.2f ms, the window's %.2f ms)" % [
		label,
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0,
		gpu / float(FRAMES), gpu_sky / float(FRAMES), gpu_root / float(FRAMES)])
	var parts := []
	for k in ["sky", "chart", "push"]:
		var us := int(StarchartScreen.MapChart.prof_us.get(k, 0))
		parts.append("%s %.2f" % [k, float(us) / float(FRAMES) / 1000.0])
	print("      [%s] GDScript drawing, ms a frame: %s" % [label, ", ".join(parts)])
	return float(t1 - t0) / float(FRAMES) / 1000.0


## One frame of the state: a drag nudge, a zoom step, or nothing. False when the
## chart is gone, which ends the sample rather than touching a freed object.
func _step(chart: Node, move: String, i: int) -> bool:
	if move != "":
		if not is_instance_valid(chart):
			print("      the chart was freed mid-sample; stopping this sample")
			return false
		if move == "drag":
			_nudge(chart, i)
		else:
			_zoom(chart, i)
	await RenderingServer.frame_post_draw
	return true


## One frame of a drag, as `_gui_input` would produce it.
func _nudge(chart: Node, i: int) -> void:
	var d := 3.0 if (i / 30) % 2 == 0 else -3.0
	var before: Vector2 = chart.pan
	chart.pan += Vector2(d, d * 0.4)
	chart._clamp_pan()
	chart.sky_pan += chart.pan - before
	chart._repaint_galaxy()


## One frame of a wheel held down, about the middle of the chart: in for half a
## second, out for half a second, so the zoom stays inside its range.
func _zoom(chart: Node, i: int) -> void:
	var f := 1.03 if (i / 30) % 2 == 0 else 1.0 / 1.03
	chart._zoom_at(chart.size * 0.5, f)
