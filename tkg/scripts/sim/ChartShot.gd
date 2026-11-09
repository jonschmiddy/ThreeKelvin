extends RefCounted

## Photographs the chart as ShipShot does: the scale bar and region button are not visible headless.
func run(tree: SceneTree) -> void:
	await tree.process_frame
	# `seed=N` first: rare states are found by trying seeds, so the harness must accept one.
	for a0 in OS.get_cmdline_user_args():
		if (a0 as String).begins_with("seed="):
			# (forced, not reseeded: `start_new_run` draws its own seed and a reseed
			# before it was thrown away)
			Rng.forced = int((a0 as String).substr(5))
			print("  [seed] %d" % Rng.forced)
	Run.start_new_run(&"korvan", 1)
	# `kind=N` regenerates the map after the swap, as node layout reads `Run.galaxy`.
	# Why: docs/why/ChartShot.md#chart-shot-options
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
	# `flown=N`: a fresh chart cannot show the remembered-system bug, so mark systems visited.
	# Why: docs/why/ChartShot.md#chart-shot-options
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
	# `toodeep` parks where some reachable stars are too deep, to photograph them dimmed.
	var deep: Array = []
	if "toodeep" in OS.get_cmdline_user_args():
		var deep_test: GDScript = load("res://scripts/sim/ChartDeepTest.gd")
		var spot: int = deep_test.park_spot()
		if spot < 0:
			print("  no system with a star in reach that is too deep")
		else:
			deep_test.park(spot)
			var here0: MapGen.MapNode = Run.node_at()
			for raw in Run.map:
				var nd: MapGen.MapNode = raw
				# (on the chart only: reach can outrun sight)
				if nd.type != MapGen.NodeType.CORE and Run.charted(nd) \
						and Run.too_deep_only(here0, nd):
					deep.append(nd)
			deep.sort_custom(func(x, y): return MapGen.hop_distance(here0, x) < MapGen.hop_distance(here0, y))
			print("  parked at %d (ring %d): %d stars on the chart in reach and too deep"
				% [spot, here0.layer + 1, deep.size()])
	# `quest` makes the call an outcome would, as a placement cannot be posed any other way.
	# Why: docs/why/ChartShot.md#chart-shot-options
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
	# The primer shows on a harness's first open, so it is removed unless `primer` is given.
	# Why: docs/why/ChartShot.md#chart-shot-options
	var scp := Router.current as StarchartScreen
	if "primerkey" in OS.get_cmdline_user_args():
		# Drives dismissal with a real key event: teardown alone does not prove a key reaches it.
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
	# `pick` chooses a destination with a STAR worth reading, to photograph the row varying.
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
			# `pick=long` takes the wordiest blurb, so rows sit at the same y for any length.
			if "long" in OS.get_cmdline_user_args():
				if MapGen.place_blurb(nn).length() > 104:
					want = nn.index
					break
				continue
			# `pick=neb` needs `flown=N` first: only 4 of 161 systems were charted at start.
			if "neb" in OS.get_cmdline_user_args():
				if nn.in_nebula and NebulaField.at(nn.gal) != null:
					want = nn.index
					break
				continue
			if nn.star != MapGen.Star.ORDINARY:
				want = nn.index
				break
		# Say so when the preference missed: a silent fallback made a NEBULA row look broken.
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
			# JUMP's bottom edge is checked against the viewport, not the panel below the HUD.
			# Why: docs/why/ChartShot.md#chart-shot-options
			var screen_h: float = sc0.get_viewport_rect().size.y
			var jb: float = sc0._jump.global_position.y + sc0._jump.size.y
			print("    blurb %d · rows y %.0f · %d in range · JUMP ends at %.0f of %.0f%s"
				% [MapGen.place_blurb(t2).length(), sc0._rows.global_position.y,
					sc0._neigh.get_child_count(), jb, screen_h,
					"  <-- OFF SCREEN" if jb > screen_h else ""])
	var tag := ""
	# `zoom=N` frames it as the player does: the galaxy-wide shot draws neither range ring.
	# Why: docs/why/ChartShot.md#chart-shot-options
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
	# Where the chart sits in the picture, for anything drawn over it later.
	var sc := Router.current as StarchartScreen
	if sc != null and sc._chart != null:
		print("chart rect ", sc._chart.get_global_rect())
		# and where the core is on it, with how many px a galaxy unit is there (for
		# measuring a light's reach about the core off the picture)
		var ch := sc._chart
		print("chart core %s gu_px %.3f" % [ch.get_global_rect().position + ch.centre_px(),
			ch._radius() * MapChart.DISC * ch.zoom])
		if ChartSky.form_of(Run.galaxy_kind) == 1:
			print("chart ball depth %s" % [ChartSky.ball_depth(Run.galaxy_kind)])
	var deep_at := -1
	if not deep.is_empty() and sc != null and sc._chart != null:
		# (the readout opens to the star's right, or its left at the edge, about
		# 170 x 51: the first one that leaves YOU and its own star in sight)
		var you: Vector2 = sc._chart._screen_pos(Run.node_at())
		for nd in deep:
			var at: Vector2 = sc._chart._screen_pos(nd)
			var o := at + Vector2(14, -26)
			if o.x + 170.0 > sc._chart.size.x - 2.0:
				o.x = at.x - 184.0
			if not Rect2(o, Vector2(170, 51)).grow(12).has_point(you) \
					and Rect2(Vector2.ZERO, sc._chart.size).grow(-20).has_point(at):
				deep_at = (nd as MapGen.MapNode).index
				break
	if deep_at >= 0:
		sc._chart.hovered = deep_at
		sc._chart._hover_t = 1.0
		sc._chart.queue_redraw()
		tag += "_toodeep"
		print("  pointing at %s: %s" % [MapGen.star_name(Run.map[deep_at]),
			" / ".join(sc._chart.tip_lines(Run.map[deep_at], Run.node_at()))])
		for i in 6:
			await RenderingServer.frame_post_draw
	# `cursor`: a pointer parked mid-chart, so the reticle is in the picture.
	# A shot has no mouse, and the reticle only draws where one is.
	if "cursor" in OS.get_cmdline_user_args() and sc != null and sc._chart != null 			and sc._chart._cross != null:
		sc._chart._cursor = (sc._chart.size * Vector2(0.55, 0.45)).floor()
		sc._chart._cross.queue_redraw()
		tag += "_cursor"
		for i in 3:
			await RenderingServer.frame_post_draw
	var path := "user://chart%s.png" % tag
	# `shot=<png>`: written there instead (two harnesses on one machine share user://)
	for a2 in OS.get_cmdline_user_args():
		if (a2 as String).begins_with("shot="):
			path = (a2 as String).substr(5)
	tree.root.get_texture().get_image().save_png(path)
	print("wrote ", ProjectSettings.globalize_path(path))
	tree.quit()
