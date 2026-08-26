extends RefCounted

## The star chart at a ladder of zooms:
##   godot --path . -- zoomshot
##
## NEEDS A WINDOW. Under `--headless` the dummy display server never emits
## `frame_post_draw`, so nothing is ever captured and it looks like a hang.
##
## IT EXISTS BECAUSE THE BUG IS A SHAPE, NOT A NUMBER. The report is that the
## galaxy sits inside a boundary, and that zooming IN makes that boundary
## smaller -- which is backwards, and not something a frame time or an assert
## can see. Six shots at a fixed seed, so the only thing that changes between
## them is `zoom`.
##
## Seeded with `Rng.forced`, NOT `Rng.reseed`: `start_new_run` rolls its own
## master seed, so a reseed before it changes nothing and every run draws a
## different galaxy. ChartFilter learned this first.

const ZOOMS: Array[float] = [0.42, 0.8, 1.5, 2.5, 4.0, 6.0]


func run(tree: SceneTree) -> void:
	await tree.process_frame
	Rng.forced = 4242
	Run.start_new_run(&"korvan", 1)
	Router.show_starchart()
	for i in 60:
		await RenderingServer.frame_post_draw

	var chart := (Router.current as StarchartScreen)._chart
	if chart == null:
		print("no chart")
		tree.quit()
		return

	for z in ZOOMS:
		chart.zoom = z
		chart.pan = Vector2.ZERO
		chart._clamp_pan()
		# _repaint_sky, not _repaint_galaxy: a zoom invalidates the backdrop's
		# slide basis outright, and this is the one caller that changes zoom
		# without going through the input path that already knows that.
		chart._repaint_sky()
		for i in 12:
			await RenderingServer.frame_post_draw
		# The radii that decide what the sky looks like, in screen pixels, next
		# to the panel they have to fit inside. A boundary you can SEE is one of
		# these landing inside the panel.
		print("  zoom %.2f  panel %.0fx%.0f  disc %.0f  core_clear %.0f  shadow %.0f" % [
			z, chart.size.x, chart.size.y,
			chart._radius() * StarchartScreen.MapChart.DISC * z * 1.1,
			chart._core_clear() * z,
			chart._shadow_r() * z * 1.05])
		var path := "user://zoom_%03d.png" % int(z * 100.0)
		var img := tree.root.get_texture().get_image()
		img.save_png(path)
		_profile(img, chart, z)

	# AND AT THE LIMIT OF THE DRAG, which is the thing that was actually wrong.
	# The rule is "the rim reaches the near edge of the view", so at full pan the
	# galaxy must be JUST touching the edge -- still visible, and one pixel from
	# not being. A shot that comes back empty means the clamp lets you lose it.
	for z in [0.42, 1.5, 4.0]:
		chart.zoom = z
		chart.pan = Vector2(99999.0, 0.0)
		chart._clamp_pan()
		chart._repaint_sky()
		for i in 12:
			await RenderingServer.frame_post_draw
		var img2 := tree.root.get_texture().get_image()
		img2.save_png("user://panned_%03d.png" % int(z * 100.0))
		_profile(img2, chart, z)

	print("  shots in " + ProjectSettings.globalize_path("user://"))
	tree.quit()


## How many pixels are lit, as a function of distance from the galaxy's centre.
##
## A DENSITY STEP IS A VISIBLE EDGE. `_star_layer` drops 88% of the foreground
## stars inside `disc` and none outside it, so there is a hard circle at that
## radius where the sky abruptly gets busier. On a smooth image this profile
## falls away steadily; a step in it is the boundary, and where the step lands
## says which radius drew it.
func _profile(img: Image, chart: Control, z: float) -> void:
	var org := chart.global_position
	var c := org + chart.size * 0.5
	var lit := PackedInt32Array()
	var tot := PackedInt32Array()
	lit.resize(40)
	tot.resize(40)
	var y := int(org.y)
	while y < int(org.y + chart.size.y):
		var x := int(org.x)
		while x < int(org.x + chart.size.x):
			var b := int(Vector2(x - c.x, y - c.y).length()) / 12
			if b < 40:
				tot[b] += 1
				if img.get_pixel(x, y).v > 0.085:
					lit[b] += 1
			x += 1
		y += 1
	var out := "  zoom %.2f density:" % z
	for b in 40:
		if tot[b] < 500:
			continue
		out += " %d:%.1f%%" % [b * 12, 100.0 * float(lit[b]) / float(tot[b])]
	print(out)
