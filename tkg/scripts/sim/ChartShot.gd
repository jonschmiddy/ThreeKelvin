extends RefCounted

## The star chart, photographed. `godot --path . -- chartshot [region]`
##
## Same reason ShipShot exists: the scale bar changes with zoom and the region
## button is a click, and neither is visible in a headless render.
func run(tree: SceneTree) -> void:
	await tree.process_frame
	# `seed=N` before anything else. A state that is rare per galaxy -- a system
	# inside a cloud, a long blurb -- is found by trying seeds, and a harness
	# that cannot be told which seed can only be run until it gets lucky.
	for a0 in OS.get_cmdline_user_args():
		if (a0 as String).begins_with("seed="):
			Rng.reseed(int((a0 as String).substr(5)))
	Run.start_new_run(&"korvan", 1)
	# `kind=N` photographs a CHOSEN galaxy instead of a rolled one, which is the
	# only way to look at a new shape without rerolling seeds until it turns up.
	#
	# The map is regenerated after the swap rather than left alone. Node
	# positions read `reach`, `squash` and `ring` off `Run.galaxy`, so a chart
	# painted as one kind with systems laid out for another is a picture of a
	# galaxy that does not exist -- and the layout is half of what a new kind
	# has to be judged on.
	for a1 in OS.get_cmdline_user_args():
		if not (a1 as String).begins_with("kind="):
			continue
		Run.galaxy_kind = clampi(int((a1 as String).substr(5)), 0,
			GalaxyGen.count() - 1)
		Run.galaxy = GalaxyGen.roll(Run.galaxy_kind)
		Run.map = MapGen.generate(Run.MAP_CANVAS)
		Run.at = 0
		Run.trail = PackedInt32Array([0])
		Run._range_cache.clear()
		Run.chart_from(Run.node_at())
		print("  %s" % GalaxyGen.type_name(Run.galaxy_kind).to_upper())
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
	# THE PRIMER IS UP IN EVERY SHOT UNLESS IT IS TAKEN DOWN. It shows on the
	# first chart open of a run, and `flown=N` marks systems VISITED without
	# appending to `trail` -- so a harness run is always a first open, however
	# far it has notionally flown, and the card would sit over every photograph
	# ever taken of this screen.
	#
	# `primer` keeps it up, to photograph the card itself.
	var scp := Router.current as StarchartScreen
	if "primerkey" in OS.get_cmdline_user_args():
		# THE DISMISS PATH ITSELF, driven with a real event rather than by
		# calling the teardown. `dismiss_primer()` returning true proves the card
		# can be removed; it proves nothing about whether any key REACHES it, and
		# a primer that cannot be got past is the one failure mode that matters.
		var ev := InputEventKey.new()
		ev.keycode = KEY_SPACE
		ev.pressed = true
		scp._input(ev)
		for iK in 4:
			await RenderingServer.frame_post_draw
		print("  after a keypress the primer is %s"
			% ["GONE" if scp._primer == null else "STILL UP"])
	elif "primer" in OS.get_cmdline_user_args():
		print("  primer left up")
	elif scp != null and scp.dismiss_primer():
		print("  primer dismissed")
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
			# `pick=long` takes the wordiest description instead, which is what
			# the header reservation exists for: if the rows below sit at the
			# same y for the shortest blurb and the longest, nothing moves.
			if "long" in OS.get_cmdline_user_args():
				if MapGen.place_blurb(nn).length() > 104:
					want = nn.index
					break
				continue
			# `pick=neb` takes one inside a cloud, to photograph the NEBULA
			# warning. MEASURED at 7.0% of systems, and only 4 of 161 were
			# charted at run start across seven seeds -- so this wants `flown=N`
			# in front of it or it will miss every time.
			if "neb" in OS.get_cmdline_user_args():
				if nn.in_nebula and NebulaField.at(nn.gal) != null:
					want = nn.index
					break
				continue
			if nn.star != MapGen.Star.ORDINARY:
				want = nn.index
				break
		# SAY SO WHEN THE PREFERENCE MISSED. This fell back to the first charted
		# system in silence, so `pick neb` on a galaxy with no charted cloud
		# photographed an ordinary system and the missing NEBULA row read as a
		# broken row rather than as a chart with nothing to show.
		if want < 0:
			print("  NO MATCH for the preference -- falling back")
		var at2 := want if want >= 0 else fallback
		if sc0 != null and at2 >= 0:
			sc0._on_node_picked(at2)
			var t2: MapGen.MapNode = Run.map[at2]
			print("  picked %s -- %s%s" % [MapGen.star_name(t2),
				MapGen.star_kind(t2),
				" + gas giant" if t2.gas_giant else ""])
			for iP in 8:
				await RenderingServer.frame_post_draw
			# JUMP IS THE CONTROL THIS SCREEN EXISTS TO REACH, so where its
			# bottom edge sits against the window is the assertion, not the
			# decoration. Anything at or past the height is off the screen.
			# AGAINST THE VIEWPORT, not against the panel. `global_position` is
			# in the viewport's frame and `sc0.size.y` is the panel's own height,
			# which starts below the HUD bar -- comparing them said the button
			# was thirteen pixels off the bottom of a screen it was plainly on.
			var screen_h: float = sc0.get_viewport_rect().size.y
			var jb: float = sc0._jump.global_position.y + sc0._jump.size.y
			print("    blurb %d · rows y %.0f · %d in range · JUMP ends at %.0f of %.0f%s"
				% [MapGen.place_blurb(t2).length(), sc0._rows.global_position.y,
					sc0._neigh.get_child_count(), jb, screen_h,
					"  <-- OFF SCREEN" if jb > screen_h else ""])
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
		chart.center_on_ship(float((a as String).substr(5)))
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
