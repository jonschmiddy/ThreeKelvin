extends RefCounted

## What the star chart costs, still, dragged and zoomed:
##   godot --path . -- chartbench [style=legacy] [graphics=low] [calm]
##
## NEEDS A WINDOW, like every other measurement of drawing in this project:
## under `--headless` the dummy display server never emits `frame_post_draw` and
## the numbers are of a renderer that is not running.
##
## IT EXISTS BECAUSE "IT FEELS LAGGY" IS NOT A NUMBER. The chart holds 60fps
## standing still and drops while the galaxy is dragged, which points at
## `_repaint_galaxy` — the one thing a drag does that resting does not. This
## times the states against each other so a fix can be shown to have worked
## rather than argued to have.
##
## Measured in FRAME TIME rather than fps, because fps is a rate and the thing
## being fixed is a cost: 60fps to 40fps sounds like a third gone and is
## actually 8ms of work added to a 16ms budget.
##
## FRAME TIME ALONE CAN HIDE THE COST. When the driver holds the swap to the
## display, a frame that costs 3ms and one that costs 15ms both read 16.67, so
## each sample also prints what the chart's layers spent in GDScript drawing
## (`MapChart.prof`) and what the GPU spent on the game's frame.

const FRAMES := 240

var _gpu_rid := RID()
var _measuring := false


func run(tree: SceneTree) -> void:
	# `style=` and `graphics=low` are read by DisplaySettings; `calm` turns
	# reduced motion on in memory (the events off)
	DisplaySettings.reduced_motion = "calm" in OS.get_cmdline_user_args()
	await tree.process_frame
	# VSYNC OFF, or every reading is 16.67ms and the bench measures the monitor.
	# The first version did exactly that: still and dragging both came back at
	# precisely 60fps and the difference was -0.00ms.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	# NOTHING FROM THE KEYBOARD OR THE MOUSE, while it measures. The window takes
	# focus when it opens, and this bench holds one chart for some five hundred
	# frames: a Tab from whoever is at the machine cycles to the ship screen, a
	# click on a HUD tab swaps the screen, and either frees the chart under the
	# next nudge -- the "previously freed" crash at the drag sample. Nothing in
	# the chart or the router frees it on its own; one Tab sent to a bench-like
	# run did it every time, and with input off here it did not.
	tree.root.gui_disable_input = true
	StarchartScreen.MapChart.prof = true
	if GameShell.instance != null:
		_gpu_rid = GameShell.instance.view.get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(_gpu_rid, true)
	# Rng.forced, NOT Rng.reseed -- see ChartFilter, which already learned this.
	# start_new_run rolls its own master seed, so a reseed before it changes
	# nothing and every run of this bench drew a DIFFERENT galaxy: 157, 244, 332
	# and 356 systems across four runs, with the title screen swinging from 5.6
	# to 36.1 ms. Comparing an optimisation against numbers like that is
	# measuring the galaxy, not the change.
	Rng.forced = 4242
	Run.start_new_run(&"korvan", 1)
	Router.show_starchart()
	for i in 90:
		await RenderingServer.frame_post_draw

	# THE TITLE SCREEN FIRST, because it draws the same galaxy and is where the
	# worst frame rate was reported. It is also the screen a player sees before
	# anything else, so a slow one is the game's first impression.
	#
	# Its galaxy is rolled off the global generator, once a process, so it is
	# seeded here or the title would be a different galaxy -- and a different
	# number -- every run of the bench.
	#
	# AND THE RUN'S GALAXY IS PUT BACK AFTER. The launcher writes its own into
	# `Run.galaxy` (it expects no run to be live), so every chart sample after
	# it used to measure the TITLE's galaxy at the chart's size: 70k primitives
	# one run, 100k the next, from the same seed.
	var run_galaxy: Dictionary = Run.galaxy.duplicate(true)
	var run_kind: int = Run.galaxy_kind
	var run_seed: int = Run.galaxy_seed
	LauncherScreen._sky_kind = -1
	seed(4242)
	Router.show_launcher()
	# WARMED BY THE CLOCK, NOT BY A FRAME COUNT. `_build_stars()` costs 350-420ms
	# for a galaxy it has not seen, and the launcher builds its own; sixty frames
	# is a quarter-second at the rate this screen runs, so the build landed
	# inside the sample on some runs and not others. That is what made the title
	# read 4.3ms on one run and 38.8ms on the next FROM THE SAME SEED.
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
	# AND STILL AT EVERY DEPTH. The sky works every block out afresh each
	# frame (`ChartSky`), and deep in it does more: finer gas, the climb
	# toward the hole drawn twice, the swirl, the extra stars.
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

	# AND A LOOK AT IT, because a frame time is not a picture. The two things
	# that can go wrong while the view moves are invisible to a stopwatch: the
	# sky landing at the wrong offset, and the trailing edge running out of stars
	# mid-drag. `-- sheet=ChartSheet` is the pixel-exact version of this.
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


## Says out loud if the measured chart leaves the tree while it is being
## measured, and what took its place. A chart freed under the bench is a
## use-after-free at the next nudge, and the screen that replaced it is the
## whole of the diagnosis.
func _watch(chart: Node) -> void:
	chart.tree_exiting.connect(func() -> void:
		if _measuring:
			print("  !! the measured chart left the tree mid-sample; Router.current is %s"
				% Router.current))


func _save(tree: SceneTree, path: String) -> void:
	tree.root.get_texture().get_image().save_png(path)


## Mean frame time over FRAMES, optionally moving the view every frame.
##
## The first frames of either state are discarded: the first drag frame pays for
## whatever the still state had cached, and counting it measures the transition
## rather than the state.
## The chart's sky draws into a viewport of its own (`ChartSky`), whose GPU
## time the game's viewport does not include: measured beside it.
## (The simplified sky is three viewports -- stars, place, composite -- and
## all three are counted; the painted sky a fourth, its band memory; the legacy
## sky one, every pass inside it.)
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
	var gpu_sky := 0.0
	var t0 := Time.get_ticks_usec()
	for i in FRAMES:
		if not await _step(chart, move, i):
			return -1.0
		if _gpu_rid.is_valid():
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(_gpu_rid)
		for r in sky_rid:
			gpu_sky += RenderingServer.viewport_get_measured_render_time_gpu(r)
	var t1 := Time.get_ticks_usec()
	# WHAT THE FRAME SUBMITTED, not just how long it took. The star field was
	# ~48,000 individual `draw_rect` calls, and a canvas item's command list is
	# re-submitted EVERY frame whether or not `_draw` rebuilt it -- so skipping
	# the repaint removes the GDScript loop and leaves the submission. Drawing
	# the field as one mesh is what took that away.
	print("      [%s] %d draw calls, %.0fk primitives a frame, GPU %.2f ms (the sky's own viewport %.2f ms)" % [
		label,
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0,
		gpu / float(FRAMES), gpu_sky / float(FRAMES)])
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
