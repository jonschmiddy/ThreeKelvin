extends Node

## The star chart photographed at chosen views, whole and with its systems
## hidden, at the chart's own size (1x) and doubled (2x, game scale, for
## judging):
##   godot --path . -- sheet=ChartLook out=<dir> [kind=N] [views=name:Z:X:Y,...] [clock=T]
##     [nebkind=F:T] [allsys] [calm] [style=legacy] [graphics=low] [runseed=N] [corekeep=0]
##     [boltclock] (the clock on the first emission cloud's next held lightning bolt)
## A view is a zoom and a pan in VIEW PX at zoom 1 (the showcase's units, 622.25
## a galaxy unit, the chart's own projection), the frame's centre: `core:1.5:0:0`.
## X may be `ship` (centred on YOU) or `neb` / `nebK` (centred on a cloud that
## shines, or one of NebulaField.Kind K; `nebK.N` the Nth of that kind). The
## default views are the showcase's heroes: opening 0.42, core 1.5, a nebula at
## 4 and the hole at 6. `clock=T` holds the sky's clock at T seconds
## (`MapChart.clock_override`, default 600, the showcase's stills); `calm` turns
## reduced motion on in memory; `nebkind=F:T` makes the first cloud of kind F
## kind T for the shot; `style=` and `graphics=low` are read by DisplaySettings.
##
## CLIPS, for measuring motion (sky only, chart rect at 1x, `f_NNNN.png`, for the
## showcase's `tools/frames.py`):
##   zoomclip=<dir> clipview=Z:X:Y [clipzoom=1.1] [clipframes=61]
##     a slow zoom: the zoom times `clipzoom` over the frames, the clock frozen
##   panclip=<dir> clipview=Z:X:Y [clipframes=61]
##     a slow pan, 12 view px over the frames, the clock frozen
##   liveclip=<dir> clipview=Z:X:Y cliptime=T0:T1:N
##     the sky's own motion at one view, the clock stepped from T0 to T1
##
## Writes <view>_full.png and <view>_sky.png (1x) and <view>_2x.png (sky, 2x).
## Prints the bake's time. Needs a window; leave it alone while it runs.

var out := "user://chartlook"
var _chart: Control = null


func _arg(name: String, fallback: String = "") -> String:
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with(name + "="):
			return (a as String).substr(name.length() + 1)
	return fallback


func _ready() -> void:
	out = _arg("out", out)
	DirAccess.make_dir_recursive_absolute(out)
	get_viewport().gui_disable_input = true
	_run.call_deferred()


func _run() -> void:
	Rng.forced = int(_arg("runseed", "4242"))
	# `corekeep=0`: the clouds as placed before they were kept off the core (a before/after)
	if _arg("corekeep") == "0":
		NebulaField.keep_core = false
	Run.start_new_run(&"korvan", 1)
	if _arg("kind") != "":
		Run.galaxy_kind = clampi(int(_arg("kind")), 0, GalaxyGen.count() - 1)
		Run.galaxy = GalaxyGen.roll(Run.galaxy_kind)
		Run.map = MapGen.generate(Run.MAP_CANVAS)
		Run.at = 0
		Run.trail = PackedInt32Array([0])
		Run._range_cache.clear()
		Run.chart_from(Run.node_at())
	if "allsys" in OS.get_cmdline_user_args():
		StarchartScreen._show_all = true
	if "calm" in OS.get_cmdline_user_args():
		DisplaySettings.reduced_motion = true
	else:
		DisplaySettings.reduced_motion = false
	var nk := _arg("nebkind")
	if nk != "":
		var kk := nk.split(":")
		for raw in NebulaField.clouds():
			var cl: NebulaField.Cloud = raw
			if int(cl.kind) == int(kk[0]):
				cl.kind = int(kk[1]) as NebulaField.Kind
				break
	StarchartScreen.MapChart.clock_override = float(_arg("clock", "600"))
	# `boltclock`: the clock held on the first emission cloud's next lightning
	# bolt after the given clock (PAINTED's held bolt), for a still of it
	if "boltclock" in OS.get_cmdline_user_args():
		var bi := 0
		for raw in NebulaField.clouds():
			var bc: NebulaField.Cloud = raw
			if bc.kind == NebulaField.Kind.EMISSION:
				var bt := StarchartScreen.MapChart.clock_override
				while bt < StarchartScreen.MapChart.clock_override + 600.0:
					if ChartPainted._bolt(bc, bi, bt).x == 1.0 and ChartPainted._bolt(bc, bi, bt - 0.15).x == 1.0:
						break
					bt += 0.05
				StarchartScreen.MapChart.clock_override = bt
				print("  chartlook: bolt in %s at clock %.2f" % [bc.name, bt])
				break
			bi += 1
	if _arg("hyst") != "":
		ChartSky.hyst = float(_arg("hyst"))
	if _arg("palmerge") != "":
		ChartSky.pal_merge = float(_arg("palmerge"))
	if _arg("dithgs") != "":
		ChartSky.dith_gs = float(_arg("dithgs"))
	if _arg("dithcoh") != "":
		ChartSky.dith_coh = float(_arg("dithcoh"))
	if _arg("quant") == "0":
		ChartSky.quant = false
	if _arg("dith") != "":
		ChartSky.dith = float(_arg("dith"))
	if _arg("palfree") != "":
		ChartSky.pal_free = int(_arg("palfree"))
	var t0 := Time.get_ticks_msec()
	Router.show_starchart()
	var scp := Router.current as StarchartScreen
	_chart = scp._chart
	# until the sky is baked, palette and all
	while not (_chart._sky as ChartSky).ready_to_draw() and Time.get_ticks_msec() - t0 < 30000:
		await get_tree().process_frame
	var g: Dictionary = ChartSky._baked.get((_chart._sky as ChartSky)._key, {})
	print("  chartlook: kind %d %s, %s; baked in %d ms, %d colours, %d stars, %d clouds, %d knots" % [
		Run.galaxy_kind, GalaxyGen.type_name(Run.galaxy_kind), DisplaySettings.style_name(DisplaySettings.render_style),
		int(g.get("bake_ms", -1)), (g.get("pal_cols", PackedColorArray()) as PackedColorArray).size(),
		int(g.get("n_star", 0)), (g.get("clouds", []) as Array).size(), (g.get("knots", []) as Array).size()])
	print("  chartlook: bake stages (ms) %s" % [g.get("times", {})])
	if "printpal" in OS.get_cmdline_user_args():
		var hx: Array = []
		for c: Color in (g.get("pal_cols", PackedColorArray()) as PackedColorArray):
			hx.append(c.to_html(false))
		print("  chartlook: palette %s" % [hx])
	scp.dismiss_primer()
	for _i in 20:
		await get_tree().process_frame
	_chart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var kinds := []
	for raw in NebulaField.clouds():
		kinds.append(NebulaField.Kind.keys()[(raw as NebulaField.Cloud).kind])
	print("  chartlook: clouds %s" % [kinds])

	if _arg("zoomclip") != "" or _arg("liveclip") != "" or _arg("panclip") != "":
		await _clip()
		get_tree().quit()
		return

	var views: Array = []
	var spec := _arg("views", "opening:0.42:0:0,core:1.5:0:0,neb:4:neb:0,hole:6:0:0")
	for s in spec.split(","):
		var f := (s as String).split(":")
		views.append([f[0], float(f[1]), _pan_of(f[2], f[3] if f.size() > 3 else "0", float(f[1]))])
	for v in views:
		_view(v[1], v[2])
		_chart.show_icons = true
		_chart.queue_redraw()
		await _shot("%s_full" % v[0], false)
		_chart.show_icons = false
		_chart.queue_redraw()
		await _shot("%s_sky" % v[0], true)
	_chart.show_icons = true
	get_tree().quit()


## A view's pan from its spec: view px, or YOU, or a cloud.
func _pan_of(x: String, y: String, z: float) -> Vector2:
	var phi: float = _chart.turn()
	if x == "ship":
		var n: MapGen.MapNode = Run.node_at()
		return ChartSky._to_view(Vector2(n.gal.x, n.gal.y / float(Run.galaxy.squash)), phi)
	if x.begins_with("neb"):
		var want := -1
		var nth := 0
		var rest := x.substr(3)
		if rest != "":
			var parts := rest.split(".")
			want = int(parts[0])
			if parts.size() > 1:
				nth = int(parts[1])
		var cl := _cloud(want, nth)
		if cl == null:
			return Vector2.ZERO
		print("  chartlook: view at zoom %.2f on %s (%s)" % [z, cl.name, NebulaField.Kind.keys()[cl.kind]])
		return ChartSky._to_view(Vector2(cl.pos.x, cl.pos.y / float(Run.galaxy.squash)), phi)
	return Vector2(float(x), float(y))


## A cloud that shines: an emission cloud first, then whatever is nearest the
## middle; or the nth of kind `want`.
func _cloud(want: int, nth: int) -> NebulaField.Cloud:
	var best: NebulaField.Cloud = null
	var score := INF
	var seen := 0
	for raw in NebulaField.clouds():
		var cl: NebulaField.Cloud = raw
		if want >= 0:
			if int(cl.kind) == want:
				if seen == nth:
					return cl
				seen += 1
			continue
		if cl.kind == NebulaField.Kind.DARK:
			continue
		var sc := cl.pos.length() - (10.0 if cl.kind == NebulaField.Kind.EMISSION else 0.0)
		if sc < score:
			score = sc
			best = cl
	return best


## The chart at zoom z with the frame's centre at view px `at`.
func _view(z: float, at: Vector2) -> void:
	var k: float = _chart._radius() * StarchartScreen.MapChart.DISC
	var zoom := z * ChartSky.K0 / k
	var ze := zoom * k / ChartSky.K0
	_chart._go_to(zoom, -at * ze, false)
	_chart._repaint_sky()


func _clip() -> void:
	var dir := _arg("zoomclip", _arg("liveclip", _arg("panclip")))
	DirAccess.make_dir_recursive_absolute(dir)
	var cv := _arg("clipview", "1.5:0:0").split(":")
	var z0 := float(cv[0])
	var at := _pan_of(cv[1], cv[2] if cv.size() > 2 else "0", z0)
	_chart.show_icons = false
	if _arg("panclip") != "":
		# a slow pan: 12 view px over the frames, as a drag would move it
		var n3 := int(_arg("clipframes", "61"))
		for i in n3:
			var before: Vector2 = _chart.pan
			_chart.pan = -(at + Vector2(12.0 * float(i) / float(n3 - 1), 0.0)) * z0
			_chart.sky_pan += _chart.pan - before
			_chart._repaint_galaxy()
			await _frame_shot(dir, i)
	elif _arg("zoomclip") != "":
		var n := int(_arg("clipframes", "61"))
		var f := float(_arg("clipzoom", "1.1"))
		for i in n:
			_view(z0 * pow(f, float(i) / float(n - 1)), at)
			await _frame_shot(dir, i)
	else:
		var ct := _arg("cliptime", "600:610:96").split(":")
		var n2 := int(ct[2])
		_view(z0, at)
		for i in n2:
			StarchartScreen.MapChart.clock_override = lerpf(float(ct[0]), float(ct[1]), float(i) / maxf(1.0, float(n2 - 1)))
			_chart._repaint_sky()
			await _frame_shot(dir, i)
	print("  chartlook: clip in %s" % ProjectSettings.globalize_path(dir))


func _frame_shot(dir: String, i: int) -> void:
	for _k in 3:
		await RenderingServer.frame_post_draw
	_crop().save_png(dir.path_join("f_%04d.png" % i))


## The chart's rect at 1x, cut from whichever viewport it is drawn in.
func _crop() -> Image:
	var img := _chart.get_viewport().get_texture().get_image()
	var at := _chart.get_global_transform_with_canvas().origin
	return img.get_region(Rect2i(Vector2i(at.round()), Vector2i(_chart.size.round())))


func _shot(name: String, twice: bool) -> void:
	for _i in 6:
		await RenderingServer.frame_post_draw
	var img := _crop()
	img.save_png("%s/%s.png" % [out, name])
	if twice:
		var big := img.duplicate() as Image
		big.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
		big.save_png("%s/%s_2x.png" % [out, name.trim_suffix("_sky")])
