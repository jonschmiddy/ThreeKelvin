extends RefCounted

## The star chart, photographed. `godot --path . -- chartshot [region]`
##
## Same reason ShipShot exists: the scale bar changes with zoom and the region
## button is a click, and neither is visible in a headless render.
func run(tree: SceneTree) -> void:
	await tree.process_frame
	Run.start_new_run(&"korvan", 1)
	# `flown=N` marks N systems visited before the chart opens.
	#
	# A FRESH CHART CANNOT SHOW THE BUG. Everything on it is currently sensed, so
	# the "remembered" treatment has nothing to apply to and a screenshot of it is
	# evidence about the wrong state. Every report of "systems beyond my range"
	# has been a chart somebody had been flying for a while.
	for a0 in OS.get_cmdline_user_args():
		if not (a0 as String).begins_with("flown="):
			continue
		var want := int((a0 as String).substr(6))
		var queue: Array[int] = [Run.at]
		var seen := {Run.at: true}
		var done := 0
		while not queue.is_empty() and done < want:
			var i: int = queue.pop_front()
			(Run.map[i] as MapGen.MapNode).visited = true
			done += 1
			for j in (Run.map[i] as MapGen.MapNode).links:
				if not seen.has(j):
					seen[j] = true
					queue.append(j)
		Run.chart_from(Run.node_at())
	# `quest` places one and photographs the marker.
	#
	# A PLACEMENT CANNOT BE SET UP ANY OTHER WAY. It is the consequence of an
	# option resolution four jumps back, so there is no state to pose -- the only
	# honest setup is to make the call the outcome would make and let it choose
	# its own target the way it will in a real run.
	if "quest" in OS.get_cmdline_user_args():
		var at := OptionTable.place(Run.node_at(), &"paid_in_full")
		if at < 0:
			print("  nowhere to place it")
		else:
			var t: MapGen.MapNode = Run.map[at]
			print("  placed on %s (layer %d, you are on %d): %s"
				% [MapGen.star_name(t), t.layer,
					(Run.node_at() as MapGen.MapNode).layer,
					OptionTable.quest_name(t)])
			print("  its options: %s" % [t.options])
	Router.show_starchart()
	for i in 120:
		await RenderingServer.frame_post_draw
	# `pick` selects a destination so the panel has something to describe, and
	# prefers a system with a STAR worth reading -- an ordinary one shows the row
	# but not that the row varies, which is the half worth photographing.
	if "pick" in OS.get_cmdline_user_args():
		var sc0 := Router.current as StarchartScreen
		var want := -1
		var fallback := -1
		for raw in Run.map:
			var nn: MapGen.MapNode = raw
			if nn.type != MapGen.NodeType.SYSTEM or not Run.charted(nn):
				continue
			if fallback < 0:
				fallback = nn.index
			if nn.star != MapGen.Star.ORDINARY:
				want = nn.index
				break
		var at2 := want if want >= 0 else fallback
		if sc0 != null and at2 >= 0:
			sc0._on_node_picked(at2)
			var t2: MapGen.MapNode = Run.map[at2]
			print("  picked %s -- %s%s" % [MapGen.star_name(t2),
				MapGen.star_kind(t2),
				" + gas giant" if t2.gas_giant else ""])
			for iP in 8:
				await RenderingServer.frame_post_draw
	var tag := ""
	# `zoom=N` frames it the way the PLAYER looks at it: centred on the ship,
	# close enough that both range rings are on screen.
	#
	# The galaxy-wide shot above cannot answer a question about the rings at all
	# -- `_ring` gives up under six pixels of radius, so at full zoom-out neither
	# one is drawn and a screenshot of that view is evidence of nothing. Both
	# reports of "I can see systems outside my range" came from this framing.
	for a in OS.get_cmdline_user_args():
		if not (a as String).begins_with("zoom="):
			continue
		var s2 := Router.current as StarchartScreen
		if s2 == null or s2._chart == null:
			break
		var chart := s2._chart
		chart.zoom = float((a as String).substr(5))
		chart.pan = -chart._polar(Run.node_at()) * chart.zoom
		chart._clamp_pan()
		# A zoom invalidates the backdrop's slide basis outright, so the sky is
		# repainted rather than slid. ZoomShot learned this first.
		chart._repaint_sky()
		tag = "_zoom"
		for i in 30:
			await RenderingServer.frame_post_draw
	if "region" in OS.get_cmdline_user_args():
		var s := Router.current as StarchartScreen
		if s != null:
			s._on_region()
			tag = "_region"
		for i in 40:
			await RenderingServer.frame_post_draw
	var path := "user://chart%s.png" % tag
	tree.root.get_texture().get_image().save_png(path)
	print("wrote ", ProjectSettings.globalize_path(path))
	tree.quit()
