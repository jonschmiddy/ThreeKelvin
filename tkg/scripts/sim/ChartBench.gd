extends RefCounted

## What the star chart costs, still and while dragging:
##   godot --path . -- chartbench
##
## NEEDS A WINDOW, like every other measurement of drawing in this project:
## under `--headless` the dummy display server never emits `frame_post_draw` and
## the numbers are of a renderer that is not running.
##
## IT EXISTS BECAUSE "IT FEELS LAGGY" IS NOT A NUMBER. The chart holds 60fps
## standing still and drops while the galaxy is dragged, which points at
## `_repaint_galaxy` — the one thing a drag does that resting does not. This
## times the two states against each other so a fix can be shown to have worked
## rather than argued to have.
##
## Measured in FRAME TIME rather than fps, because fps is a rate and the thing
## being fixed is a cost: 60fps to 40fps sounds like a third gone and is
## actually 8ms of work added to a 16ms budget.

const FRAMES := 240


func run(tree: SceneTree) -> void:
	await tree.process_frame
	# VSYNC OFF, or every reading is 16.67ms and the bench measures the monitor.
	# The first version did exactly that: still and dragging both came back at
	# precisely 60fps and the difference was -0.00ms.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
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
	Router.show_launcher()
	# WARMED BY THE CLOCK, NOT BY A FRAME COUNT. `_build_stars()` costs 350-420ms
	# for a galaxy it has not seen, and the launcher builds its own; sixty frames
	# is a quarter-second at the rate this screen runs, so the build landed
	# inside the sample on some runs and not others. That is what made the title
	# read 4.3ms on one run and 38.8ms on the next FROM THE SAME SEED.
	var warm := Time.get_ticks_msec()
	while Time.get_ticks_msec() - warm < 2000:
		await RenderingServer.frame_post_draw
	var title := await _sample(tree, null, false, "title")

	Router.show_starchart()
	for i in 60:
		await RenderingServer.frame_post_draw
	var chart := (Router.current as StarchartScreen)._chart
	if chart == null:
		print("no chart")
		tree.quit()
		return

	var still := await _sample(tree, chart, false, "still")
	var dragged := await _sample(tree, chart, true, "drag")

	print("\n=== CHART ===")
	print("  %d systems on the map" % Run.map.size())
	print("  title    %.2f ms/frame  (%.0f fps)" % [title, 1000.0 / maxf(0.01, title)])
	print("  still    %.2f ms/frame  (%.0f fps)" % [still, 1000.0 / maxf(0.01, still)])
	print("  dragging %.2f ms/frame  (%.0f fps)" % [dragged, 1000.0 / maxf(0.01, dragged)])
	print("  the drag costs %.2f ms a frame" % [dragged - still])

	# AND A LOOK AT IT, because a frame time is not a picture. The backdrop is
	# slid rather than repainted now, so the two things that could go wrong are
	# invisible to a stopwatch: the sky landing at the wrong offset, and the
	# trailing edge running out of stars mid-drag.
	Router.show_launcher()
	for i in 30:
		await RenderingServer.frame_post_draw
	tree.root.get_texture().get_image().save_png("user://bench_title.png")
	Router.show_starchart()
	for i in 30:
		await RenderingServer.frame_post_draw
	tree.root.get_texture().get_image().save_png("user://bench_chart.png")
	# A NEW chart: showing the launcher freed the one measured above, and
	# reusing that reference is a use-after-free the engine catches for you.
	chart = (Router.current as StarchartScreen)._chart
	# Mid-drag, and far enough to have crossed the margin at least once.
	for i in 90:
		_nudge(chart, 0)
		await RenderingServer.frame_post_draw
	tree.root.get_texture().get_image().save_png("user://bench_drag.png")
	print("  shots: " + ProjectSettings.globalize_path("user://"))
	tree.quit()


## Mean frame time over FRAMES, optionally moving the view every frame.
##
## The first frames of either state are discarded: the first drag frame pays for
## whatever the still state had cached, and counting it measures the transition
## rather than the state.
func _sample(tree: SceneTree, chart: Node, drag: bool, label := "") -> float:
	for i in 20:
		if drag and chart != null:
			_nudge(chart, i)
		await RenderingServer.frame_post_draw
	var t0 := Time.get_ticks_usec()
	for i in FRAMES:
		if drag and chart != null:
			_nudge(chart, i)
		await RenderingServer.frame_post_draw
	var t1 := Time.get_ticks_usec()
	# WHAT THE FRAME SUBMITTED, not just how long it took. The star field is
	# ~48,000 individual `draw_rect` calls, and a canvas item's command list is
	# re-submitted EVERY frame whether or not `_draw` rebuilt it -- so skipping
	# the repaint (which is what the slide does) removes the GDScript loop and
	# leaves the submission. That is the floor this screen cannot get under
	# without drawing the field as one thing instead of 48,000 things.
	print("      [%s] %d draw calls, %.0fk primitives a frame" % [
		label,
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0])
	return float(t1 - t0) / float(FRAMES) / 1000.0


## One frame of a drag, as `_gui_input` would produce it.
func _nudge(chart: Node, i: int) -> void:
	var d := 3.0 if (i / 30) % 2 == 0 else -3.0
	chart.pan += Vector2(d, d * 0.4)
	chart._clamp_pan()
	chart._repaint_galaxy()
