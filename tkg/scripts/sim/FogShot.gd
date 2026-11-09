extends RefCounted

## The simulator cannot see this: it never plans a route, so live sight moved win rate 1 in 500.
## Needs a window, as `--headless` never emits `frame_post_draw`.
## Why: docs/why/FogShot.md#fog-shot

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
		# Zoomed and centred on the ship, after the screen settles, or its deferred fit overwrites.
		# Why: docs/why/FogShot.md#fog-shot-framing
		for i in 20:
			await RenderingServer.frame_post_draw
		var chart = (Router.current as StarchartScreen)._chart
		if chart != null:
			chart.center_on_ship(2.2)
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
		# Why each system is visible: `_visible_set` has four reasons and only one is the dish.
		var here2: MapGen.MapNode = Run.node_at()
		var r_sight := Run.sense_radius()
		var out_only_sensed := 0
		var by_visited := 0
		var by_station := 0
		var by_contract := 0
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

	# The reach overlay is hover-driven: hover a system a couple of hops out, not the ship's own.
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
