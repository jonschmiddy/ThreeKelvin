extends RefCounted

## Real galaxy data for the sensor-ladder study:
##   godot --headless --path . -- sensordump
##
## Writes `user://sensor_study.json`. Everything an outside tool needs to draw
## what a given SENSORS rating shows you, taken from the running game rather
## than reconstructed -- system positions, the galaxy's squash, the base radius
## at a real node, and the constants sight and reach are built from.
##
## The point is that the ladder is judged against the galaxy that ships. A
## hand-made field of dots would answer a question about the dots.

func run(tree: SceneTree) -> void:
	await tree.process_frame
	# `seed=N` so a SPIRAL can be asked for. The default 4242 is a Giant
	# Elliptical, `arms = 0`, and the arm-pull block never runs on one -- so it
	# is the one kind that cannot show what the arm clamp does.
	Rng.forced = 4242
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with("seed="):
			Rng.forced = int((a as String).substr(5))
	Run.start_new_run(&"korvan", 1)
	# `kind=N` re-rolls the galaxy as a chosen kind and regenerates the map.
	# Needed because the kind is rolled from the seed, and the arm-pull study
	# wants a SPIRAL specifically -- kind 0 is Grand-Design, arms 2.
	for a2 in OS.get_cmdline_user_args():
		if (a2 as String).begins_with("kind="):
			Run.galaxy_kind = int((a2 as String).substr(5))
			Run.galaxy = GalaxyGen.roll(Run.galaxy_kind)
			Run.map = MapGen.generate(Run.MAP_CANVAS)
			Run.at = 0
			Run.chart_from(Run.node_at())

	var here: MapGen.MapNode = Run.node_at()
	var g: Dictionary = Run.galaxy
	var out: Dictionary = {}

	out["galaxy"] = String(g.get("name", "?"))
	out["squash"] = float(g.get("squash", 0.62))
	out["systems_total"] = Run.map.size()
	out["sense_floor"] = Run.SENSE_FLOOR
	out["sense_reach"] = Run.SENSE_REACH
	out["thrust_reach"] = Run.thrust_reach()
	out["attr_thrust"] = Run.attr_thrust()
	# The base every radius is a multiple of: the map's own spacing at this node,
	# with no ship in it. Sight is base * (SENSE_FLOOR + sensors * SENSE_REACH)
	# and reach is base * thrust_reach().
	out["base_radius"] = Run._map_range_from(here)
	out["here"] = {"x": here.gal.x, "y": here.gal.y, "layer": here.layer}

	# Every system, in galaxy coordinates -- ALREADY SQUASHED, because `gal` is
	# what `galaxy_pos` produced and that is what the chart draws.
	var sys: Array = []
	for n in Run.map:
		var t: MapGen.MapNode = n
		sys.append({
			"x": t.gal.x, "y": t.gal.y, "layer": t.layer,
			"type": int(t.type),
			# Un-squashed distance from the ship: the number the game measures
			# and the reason a nearer-LOOKING system can be out of range.
			"d": MapGen.hop_distance(here, t)})
	out["systems"] = sys

	# And what each rung of the ladder actually buys, counted rather than
	# guessed. `sensed` is live now, so this is simply "inside the sight radius".
	var rungs: Array = []
	for s in range(0, 11):
		var r: float = out["base_radius"] * (Run.SENSE_FLOOR + float(s) * Run.SENSE_REACH)
		var lit := 0
		for n in Run.map:
			if MapGen.hop_distance(here, n) <= r:
				lit += 1
		rungs.append({"sensors": s, "radius": r, "visible": lit})
	out["ladder"] = rungs

	var f := FileAccess.open("user://sensor_study.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	print("  %s - %d systems, squash %.2f, base %.4f"
		% [out["galaxy"], out["systems_total"], out["squash"], out["base_radius"]])
	for r in rungs:
		print("    sensors %2d - radius %.3f - %d of %d visible"
			% [r["sensors"], r["radius"], r["visible"], out["systems_total"]])
	print("  " + ProjectSettings.globalize_path("user://sensor_study.json"))
	tree.quit()
