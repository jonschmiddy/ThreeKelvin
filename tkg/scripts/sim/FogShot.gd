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
		# ZOOMED, AND CENTRED ON THE SHIP. The default view centres the GALAXY,
		# and the ship spawns on the rim -- so the one thing these shots are of
		# sits off the edge of the frame.
		# AFTER the screen has settled. `show_starchart` builds a fresh screen and
		# its deferred fit sets zoom and pan itself, so anything set before that
		# lands is simply overwritten.
		for i in 20:
			await RenderingServer.frame_post_draw
		var chart = (Router.current as StarchartScreen)._chart
		if chart != null:
			chart.zoom = 2.2
			chart.pan = -chart._polar(Run.node_at()) * chart.zoom
			chart._clamp_pan()
			chart._repaint_sky()
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
		# WHY each visible system is visible. `_visible_set` has four reasons and
		# only one of them is the dish, so a system can be lit well outside the
		# sensor ring and still be correct -- or not, which is the question.
		var here2: MapGen.MapNode = Run.node_at()
		var r_sight := Run.sense_radius()
		var out_only_sensed := 0
		var by_visited := 0
		var by_station := 0
		var by_contract := 0
		var by_sensed := 0
		for n in Run.map:
			var t: MapGen.MapNode = n
			var d2 := MapGen.hop_distance(here2, t)
			var outside := d2 > r_sight
			if t.visited:
				if outside:
					by_visited += 1
			elif Run.station_heard(t.index):
				if outside:
					by_station += 1
			elif t.sensed:
				by_sensed += 1
				if outside:
					out_only_sensed += 1
			elif Run.contract_at(t.index) != null:
				if outside:
					by_contract += 1
		print("  after %2d jumps: %d of %d in sensor range, %d on the chart"
			% [jumped, lit, Run.map.size(), seen])
		print("       OUTSIDE the sensor ring: %d visited - %d station_heard - %d contract - %d STILL FLAGGED sensed"
			% [by_visited, by_station, by_contract, out_only_sensed])
		tree.root.get_texture().get_image().save_png(
			"user://fog_%02d.png" % jumped)

	# AND THE REACH OVERLAY, which is hover-driven and so cannot be seen from a
	# screenshot without saying what is hovered. Points at a system a couple of
	# hops out rather than the ship's own, since the ship already draws its
	# dotted lines and would prove nothing.
	var chart2 = (Router.current as StarchartScreen)._chart
	if chart2 != null:
		chart2.show_links = true
		var pick := Run.node_at().index
		for n in Run.map:
			var t: MapGen.MapNode = n
			if t.sensed and t.index != Run.node_at().index:
				pick = t.index
				break
		chart2.hovered = pick
		chart2.queue_redraw()
		for i in 20:
			await RenderingServer.frame_post_draw
		tree.root.get_texture().get_image().save_png("user://fog_reach.png")
		print("  reach overlay on system %d" % pick)

	print("  shots in " + ProjectSettings.globalize_path("user://"))
	tree.quit()
