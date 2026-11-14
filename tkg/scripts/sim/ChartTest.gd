extends RefCounted

## Run after touching `_build_stars`: a missed `SKY_FIELDS` entry silently leaks the last
## galaxy's sky.
## Why: docs/why/ChartTest.md#sky-cache-test

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
	var restored: Dictionary = chart.snapshot_sky()

	# A genuine rebuild: no cache entry and no matching key.
	MapChart._sky_cache.clear()
	chart._star_key = ""
	chart._build_stars()
	var built: Dictionary = chart.snapshot_sky()

	# That rebuild repopulated the cache, so this takes the restore path.
	chart._star_key = ""
	chart._build_stars()
	var again: Dictionary = chart.snapshot_sky()

	var values := 0
	for f in fields:
		# The build reads no global RNG, so two builds are identical; if this fires, the cache is
		# not the cause.
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
		% MapChart._sky_cache.size())
	await _style_switch(tree, chart)
	print("=== %s (%d mismatches) ===\n" % ["PASS" if fails == 0 else "FAIL", fails])
	tree.quit(1 if fails > 0 else 0)


## Style switch remakes the sky in each renderer and back, in memory only; the settings
## file is not written.
func _style_switch(_tree: SceneTree, chart: Object) -> void:
	var sky: ChartSky = chart.get("_sky")
	if sky == null:
		print("  STYLE: the chart has no sky")
		fails += 1
		return
	var was := DisplaySettings.render_style
	for st: StringName in [&"painted", &"radiant", was]:
		DisplaySettings.render_style = st
		Sig.render_style_changed.emit()
		var t0 := Time.get_ticks_msec()
		var drawn := false
		while Time.get_ticks_msec() - t0 < 15000:
			await RenderingServer.frame_post_draw
			# the key is renewed at the next draw: wait for the new style to be drawing
			var mine := (sky._key.ends_with("|painted") == (st == &"painted")
				and sky._key.ends_with("|radiant") == (st == &"radiant"))
			if mine and sky.ready_to_draw():
				drawn = true
				break
		var own := (sky._tvp != null) == (st == &"painted") and sky._g_for().has("radiant") == (st == &"radiant")
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
