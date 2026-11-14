extends RefCounted

## Needs a window, as headless never emits `frame_post_draw`. The bug is a shape no assert sees.
## Seeded with `Rng.forced`, as `start_new_run` rolls its own seed and discards a reseed.
## Why: docs/why/ZoomShot.md#zoom-shot

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
		# `_repaint_sky`: a zoom invalidates the backdrop's slide basis, and this skips input.
		chart._repaint_sky()
		for i in 12:
			await RenderingServer.frame_post_draw
		# Screen-pixel radii beside the panel: a visible boundary is one landing inside it.
		print("  zoom %.2f  panel %.0fx%.0f  disc %.0f  core_clear %.0f  shadow %.0f" % [
			z, chart.size.x, chart.size.y,
			chart.chart_radius() * MapChart.DISC * z * 1.1,
			chart._core_clear() * z,
			chart._shadow_r() * z * 1.05])
		var path := "user://zoom_%03d.png" % int(z * 100.0)
		var img := tree.root.get_texture().get_image()
		img.save_png(path)
		# The chart sits at game-viewport coordinates, so the profile reads the game's own texture.
		_profile(GameShell.input_target(tree).get_texture().get_image(), chart, z)

	# At full pan the galaxy must just touch the edge. An empty shot means the clamp loses it.
	for z in [0.42, 1.5, 4.0]:
		chart.zoom = z
		chart.pan = Vector2(99999.0, 0.0)
		chart._clamp_pan()
		chart._repaint_sky()
		for i in 12:
			await RenderingServer.frame_post_draw
		var img2 := tree.root.get_texture().get_image()
		img2.save_png("user://panned_%03d.png" % int(z * 100.0))
		_profile(GameShell.input_target(tree).get_texture().get_image(), chart, z)

	print("  shots in " + ProjectSettings.globalize_path("user://"))
	tree.quit()


## `_star_layer` drops 88% of stars inside `disc`, so a step in the profile is a visible edge.
## Why: docs/why/ZoomShot.md#density-step
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
