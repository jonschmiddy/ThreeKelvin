extends RefCounted

## What the chart actually looks like now that sight is live:
##   godot --path . -- fogshot
##
## NEEDS A WINDOW. `--headless` never emits `frame_post_draw`.
##
## THE SIMULATOR CANNOT SEE THIS CHANGE. Its policy chooses from what is
## reachable this instant and never plans a route, so an accumulated chart is
## worth nothing to it -- live sight moved win rate by one run in five hundred.
## What a chart is FOR is planning, and the only way to judge it is to look.
##
## Three shots: the first frame, a few jumps in, and deep. What to look for is
## whether the lit part is enough to choose from -- a spawn in a sparse region
## is the stated worry, and `_map_range_from` being relative to the nearest
## neighbour rather than absolute is the reason it may not be.

const SHOTS := [0, 4, 12]


func run(tree: SceneTree) -> void:
	await tree.process_frame
	Rng.forced = 4242
	Run.start_new_run(&"korvan", 1)
	Router.show_starchart()
	for i in 40:
		await RenderingServer.frame_post_draw

	var policy := Policy.new()
	policy.pilot.seed = 4242
	var jumped := 0
	for want in SHOTS:
		while jumped < want:
			var node: MapGen.MapNode = Run.node_at()
			var pick: int = policy.choose_jump(node)
			if pick < 0:
				break
			Run.jump_to(pick)
			jumped += 1
		Router.show_starchart()
		for i in 24:
			await RenderingServer.frame_post_draw
		var lit := 0
		for n in Run.map:
			if (n as MapGen.MapNode).sensed:
				lit += 1
		var seen := 0
		for n in Run.map:
			var t: MapGen.MapNode = n
			if t.sensed or t.visited or Run.station_heard(t.index):
				seen += 1
		print("  after %2d jumps: %d of %d systems in sensor range, %d on the chart"
			% [jumped, lit, Run.map.size(), seen])
		tree.root.get_texture().get_image().save_png(
			"user://fog_%02d.png" % jumped)

	print("  shots in " + ProjectSettings.globalize_path("user://"))
	tree.quit()
