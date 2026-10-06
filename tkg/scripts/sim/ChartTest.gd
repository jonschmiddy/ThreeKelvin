extends RefCounted

## Correctness and cost of the star chart's shared sky cache.
##
##   godot --path . -- charttest        (needs a window: it renders)
##
## RUN THIS AFTER ADDING ANYTHING TO _build_stars OR ITS SUB-BUILDERS.
##
## The cache saves and restores a named list of fields, MapChart.SKY_FIELDS, and
## there is exactly one way for it to go wrong: a builder gains a new output and
## nobody adds it to that list. Nothing errors. The field simply keeps whatever
## the previous galaxy left in it, and the chart draws last run's dust lanes
## over this run's stars — on the second visit only, which is the kind of bug
## that gets blamed on anything but the cache.
##
## So this compares a RESTORED sky against a freshly BUILT one, field for field.
## Screenshots cannot answer the question: SkyAnim redraws every frame, so two
## captures of an identical sky differ anyway.

var fails: int = 0

func run(tree: SceneTree) -> void:
	print("\n=== STAR CHART CACHE ===")
	await tree.create_timer(1.5).timeout      ## let the first layout settle

	await _open(tree, "cold  (first ever)")
	await _open(tree, "warm  (same galaxy)")
	await _open(tree, "warm  (same galaxy)")
	Run.start_new_run()
	await tree.create_timer(0.4).timeout
	await _open(tree, "cold  (new galaxy)")
	await _open(tree, "warm  (new galaxy)")

	Router.show_starchart()
	await RenderingServer.frame_post_draw
	var chart: Object = (Router.current as StarchartScreen)._chart
	var fields: Array = chart.SKY_FIELDS
	var restored: Dictionary = chart._snapshot_sky()

	# A genuine rebuild: no cache entry and no matching key.
	StarchartScreen.MapChart._sky_cache.clear()
	chart._star_key = ""
	chart._build_stars()
	var built: Dictionary = chart._snapshot_sky()

	# That rebuild repopulated the cache, so this takes the restore path.
	chart._star_key = ""
	chart._build_stars()
	var again: Dictionary = chart._snapshot_sky()

	var values := 0
	for f in fields:
		# The build reads no global RNG — every random number in it comes from
		# _seed_rng off galaxy_seed — so two builds of one galaxy are identical.
		# If this ever fires, the cache is not the thing that broke.
		if str(restored[f]) != str(built[f]):
			print("  NON-DETERMINISTIC build: %s" % f)
			fails += 1
		if str(again[f]) != str(built[f]):
			print("  CACHE MISMATCH: %s" % f)
			fails += 1
		var v: Variant = built[f]
		values += (v.size() if typeof(v) != TYPE_INT else 1)

	print("  %d fields, %d values compared" % [fields.size(), values])
	print("  cache entries held: %d (a run is one galaxy, so this should be 1)"
		% StarchartScreen.MapChart._sky_cache.size())
	await _style_switch(tree, chart)
	print("=== %s (%d mismatches) ===\n" % ["PASS" if fails == 0 else "FAIL", fails])
	tree.quit()


## Another style chosen with the chart open: the sky is made again in that
## style's own renderer (PAINTED keeps a fourth pass, its band memory; LEGACY a
## node of its own, `ChartLegacy`; RADIANT its own bakes and place pass) and back. In memory only: the settings file
## is never written.
func _style_switch(_tree: SceneTree, chart: Object) -> void:
	var sky: ChartSky = chart.get("_sky")
	if sky == null:
		print("  STYLE: the chart has no sky")
		fails += 1
		return
	var was := DisplaySettings.render_style
	for st: StringName in [&"painted", &"legacy", &"radiant", was]:
		DisplaySettings.render_style = st
		Sig.render_style_changed.emit()
		var t0 := Time.get_ticks_msec()
		var drawn := false
		var legacy := st == &"legacy"
		while Time.get_ticks_msec() - t0 < 15000:
			await RenderingServer.frame_post_draw
			# the key is renewed at the next draw: wait for the new style to be drawing
			var mine := (sky._legacy != null) == legacy and (legacy or (sky._key.ends_with("|painted") == (st == &"painted")
				and sky._key.ends_with("|radiant") == (st == &"radiant")))
			if mine and sky.ready_to_draw():
				drawn = true
				break
		var own := (sky._tvp != null) == (st == &"painted") and (sky._legacy != null) == legacy 			and (not legacy or sky._vp == null) and sky._g_for().has("radiant") == (st == &"radiant")
		print("  style %-10s drawn %s in %d ms, its own passes %s" % [st, drawn, Time.get_ticks_msec() - t0, own])
		if not drawn or not own:
			fails += 1

func _open(tree: SceneTree, label: String) -> void:
	var t0 := Time.get_ticks_usec()
	Router.show_starchart()
	await RenderingServer.frame_post_draw
	await tree.process_frame
	await RenderingServer.frame_post_draw
	print("  %-24s %7.1f ms" % [label, (Time.get_ticks_usec() - t0) / 1000.0])
	Router.show_sector()
	await tree.create_timer(0.4).timeout
