extends Node

## The star chart photographed at chosen views, whole and with its systems
## hidden, at the chart's own size (1x) and doubled (2x, game scale, for
## judging):
##   godot --path . -- sheet=ChartLook out=<dir> [kind=N] [views=name:Z:X:Y,...] [clock=T]
##     [nebkind=F:T] [allsys] [calm] [style=legacy] [graphics=low] [runseed=N] [corekeep=0]
##     [at=N|darkF] (YOU at system N, or beside the first dark cloud, F of its radius out)
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
##   liveclip=<dir> clipview=Z:X:Y cliptime=T0:T1:N [turn=title] [clipwait=1]
##     the sky's own motion at one view, the clock stepped from T0 to T1
##     (`turn=title` at the title's turning speed; `clipwait=1` a frame drawn a
##     step, so a 20 s clip at 60 steps a second is the game's own frames)
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
	# `at=N` puts YOU at system N; `at=dark` / `at=darkF` at the system nearest
	# the first dark cloud, F of its radius out from its middle toward the rim
	# (a system with a nebula beside it, its jump lines drawn, for `ship` views)
	var at_s := _arg("at")
	if at_s != "":
		var want_i := -1
		if at_s.begins_with("dark"):
			var frac := float(at_s.substr(4)) if at_s.length() > 4 else 0.0
			for raw in NebulaField.clouds():
				var dc: NebulaField.Cloud = raw
				if dc.kind != NebulaField.Kind.DARK:
					continue
				var aim := dc.pos + dc.pos.normalized() * dc.radius * frac
				var best_d := INF
				for ni in Run.map.size():
					var dd := ((Run.map[ni] as MapGen.MapNode).gal - aim).length()
					if dd < best_d:
						best_d = dd
						want_i = ni
				print("  chartlook: YOU at system %d, beside %s" % [want_i, dc.name])
				break
		else:
			want_i = int(at_s)
		if want_i >= 0 and want_i < Run.map.size():
			Run.at = want_i
			Run.trail = PackedInt32Array([want_i])
			Run._range_cache.clear()
			Run.chart_from(Run.node_at())
	# `visit=N`: a run's worth of history -- N hops from where YOU are, each to the
	# nearest system not yet visited, all marked visited, YOU at the last
	var nv := int(_arg("visit", "0"))
	if nv > 0 and not Run.map.is_empty():
		var cur: MapGen.MapNode = Run.node_at()
		cur.visited = true
		var trail := PackedInt32Array([cur.index])
		for _h in nv:
			var best: MapGen.MapNode = null
			var bd := INF
			for raw in Run.map:
				var mn: MapGen.MapNode = raw
				if mn.visited or mn.type == MapGen.NodeType.CORE:
					continue
				var dd := (mn.gal - cur.gal).length() + (mn.gal.length() - cur.gal.length()) * 0.6
				if dd < bd and (mn.gal - cur.gal).length() > 0.03:
					bd = dd
					best = mn
			if best == null:
				break
			best.visited = true
			trail.append(best.index)
			cur = best
		Run.trail = trail
		Run.at = cur.index
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
	if _arg("diag") != "":
		ChartSky.diag = int(_arg("diag"))
		ChartLegacy.diag = int(_arg("diag"))
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

	if _arg("tourclip") != "":
		await _tour(_arg("tourclip"))
		get_tree().quit()
		return
	if _arg("costbench") != "":
		await _cost_bench(_arg("costbench"))
		get_tree().quit()
		return
	if _arg("zoomclip") != "" or _arg("liveclip") != "" or _arg("panclip") != "" or _arg("wheelclip") != "" or _arg("glideclip") != "" or _arg("playclip") != "":
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
	var dir := _arg("zoomclip", _arg("liveclip", _arg("panclip", _arg("wheelclip", _arg("glideclip", _arg("playclip"))))))
	DirAccess.make_dir_recursive_absolute(dir)
	var cv := _arg("clipview", "1.5:0:0").split(":")
	var z0 := float(cv[0])
	var at := _pan_of(cv[1], cv[2] if cv.size() > 2 else "0", z0)
	_chart.show_icons = false
	# `turn=title`: the galaxy turning at the title screen's speed (once every
	# five minutes), not the chart's (once every twelve hours)
	if _arg("turn") == "title":
		_chart.turn_speed = LauncherScreen.TITLE_TURN
	if _arg("panclip") != "":
		# a slow pan: 12 view px over the frames (`panpx=`), as a drag would move it,
		# at the clip view's zoom (it used to pan at whatever zoom the chart opened on)
		_view(z0, at)
		for _i in 6:
			await RenderingServer.frame_post_draw
		var pp := float(_arg("panpx", "12"))
		var n3 := int(_arg("clipframes", "61"))
		for i in n3:
			var before: Vector2 = _chart.pan
			_chart.pan = -(at + Vector2(pp * float(i) / float(n3 - 1), 0.0)) * z0
			_chart.sky_pan += _chart.pan - before
			_chart._repaint_galaxy()
			await _frame_shot(dir, i)
	elif _arg("playclip") != "":
		# `playclip=<dir>`: a hand playing: wheel notches at wandering cursors and
		# drags, for `clipframes` frames, the clock running (`playseed=N`)
		_view(z0, at)
		for _i in 6:
			await RenderingServer.frame_post_draw
		if _arg("bhold") != "" and (_chart._sky as ChartSky)._m_state != null:
			(_chart._sky as ChartSky)._m_state.set_shader_parameter("hold", float(_arg("bhold")))
			(_chart._sky as ChartSky)._g_for()["_hold_fixed"] = true
		var rng := RandomNumberGenerator.new()
		rng.seed = int(_arg("playseed", "7"))
		var t := StarchartScreen.MapChart.clock_override
		var drag := Vector2.ZERO
		var drag_n := 0
		for fi in int(_arg("clipframes", "300")):
			t += 1.0 / 60.0
			StarchartScreen.MapChart.clock_override = t
			var r := rng.randf()
			if drag_n > 0:
				var before: Vector2 = _chart.pan
				_chart.pan += drag
				_chart.sky_pan += _chart.pan - before
				_chart._clamp_pan()
				_chart._repaint_galaxy()
				drag_n -= 1
			elif r < 0.12:
				var cur := _chart.size * Vector2(rng.randf_range(0.15, 0.85), rng.randf_range(0.15, 0.85))
				var f := StarchartScreen.MapChart.ZOOM_STEP if (rng.randf() < 0.55 or _chart.zoom < 2.0) and _chart.zoom < 5.5 else 1.0 / StarchartScreen.MapChart.ZOOM_STEP
				_chart._zoom_at(cur, f)
			elif r < 0.16:
				drag = Vector2(rng.randf_range(-6.0, 6.0), rng.randf_range(-4.0, 4.0))
				drag_n = rng.randi_range(5, 30)
			_chart._repaint_sky()
			await _frame_shot(dir, fi)
			if "playlog" in OS.get_cmdline_user_args():
				var sk := _chart._sky as ChartSky
				print("  play %d zoom %.6f pan %.4f %.4f sky %.4f %.4f t %.4f origin %s size %s since %d" % [fi, _chart.zoom, _chart.pan.x, _chart.pan.y, _chart.sky_pan.x, _chart.sky_pan.y, t, sk._vp_origin, sk._vp.size, sk._since_zoom])
	elif _arg("glideclip") != "":
		# `glideclip=<dir>`: glides as a press makes them (`glide_to`), from the clip
		# view in to `glideto=Z:X:Y` and back, every frame drawn as the game draws it
		_view(z0, at)
		for _i in 6:
			await RenderingServer.frame_post_draw
		var gt := _arg("glideto", "5:0:0").split(":")
		var z1 := float(gt[0])
		var at1 := _pan_of(gt[1], gt[2] if gt.size() > 2 else "0", z1)
		var k: float = _chart._radius() * StarchartScreen.MapChart.DISC
		var fi := 0
		for leg in 2:
			var zz := z1 if leg == 0 else z0
			var aa := at1 if leg == 0 else at
			var zoom: float = zz * ChartSky.K0 / k
			_chart.glide_to(zoom, -aa * zz, 0.55)
			for _j in 50:
				await _frame_shot(dir, fi)
				fi += 1
	elif _arg("wheelclip") != "":
		# `wheelclip=<dir>`: as a hand plays it -- turns of the wheel at a cursor
		# (`wheelat=fx:fy`, shares of the chart), in to the closest zoom and back out,
		# a notch every `wheelgap=N` frames, with drags between; the clock runs at the
		# game's rate and the galaxy turns (`turn=title` for the title's speed)
		_view(z0, at)
		for _i in 6:
			await RenderingServer.frame_post_draw
		var wa := _arg("wheelat", "0.45:0.4").split(":")
		var cur := _chart.size * Vector2(float(wa[0]), float(wa[1]))
		var gap := int(_arg("wheelgap", "4"))
		var steps := int(_arg("wheelsteps", "24"))
		var t := StarchartScreen.MapChart.clock_override
		var fi := 0
		for dirn in [1, -1]:
			for st in steps:
				_chart._zoom_at(cur, StarchartScreen.MapChart.ZOOM_STEP if dirn > 0 else 1.0 / StarchartScreen.MapChart.ZOOM_STEP)
				for _j in gap:
					t += 1.0 / 60.0
					StarchartScreen.MapChart.clock_override = t
					if st % 6 == 5 and _j < 2:
						var before: Vector2 = _chart.pan
						_chart.pan += Vector2(3.0, 1.0)
						_chart.sky_pan += _chart.pan - before
						_chart._repaint_galaxy()
					_chart._repaint_sky()
					await _frame_shot(dir, fi)
					fi += 1
	elif _arg("zoomclip") != "":
		var n := int(_arg("clipframes", "61"))
		var f := float(_arg("clipzoom", "1.1"))
		# `bhold=N`: PAINTED's band memory held N frames at most (0: none), to see
		# what the memory itself does to a zoom
		if _arg("bhold") != "" and (_chart._sky as ChartSky)._m_state != null:
			(_chart._sky as ChartSky)._m_state.set_shader_parameter("hold", float(_arg("bhold")))
			(_chart._sky as ChartSky)._g_for()["_hold_fixed"] = true
		# `clipback`: in over the frames, held still half as long (`clipstill=N`
		# frames), back out, held again -- what a zoom leaves behind once it stops
		var path: Array[float] = []
		for i in n:
			path.append(float(i) / float(n - 1))
		if "clipback" in OS.get_cmdline_user_args():
			var hold_n := int(_arg("clipstill", str(n / 2)))
			for i in hold_n:
				path.append(1.0)
			for i in n:
				path.append(1.0 - float(i) / float(n - 1))
			for i in hold_n:
				path.append(0.0)
		for i in path.size():
			_view(z0 * pow(f, path[i]), at)
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


## THE TOUR: a player's first look, the same every run, for a before and an
## after at the same state (`tourclip=<dir> tour=dive|core|pan|open [icons]
## [tourat=fx:fy|ship]`). 30 frames a second of the game's clock, one frame
## drawn a step, the moves made through the chart's own wheel and drag code (so
## the far sky's parallax is the game's):
##   dive  1 s at the opening, 5 s of wheel in toward `tourat` (5.7x), 2 s of
##         drag, 1 s still
##   core  the core at 1.2, 5 s in to 3.6 about the middle, 2 s still
##   pan   the arms at zoom 1, 8 s of drag across them, eased
##   open  3 s still at the opening, then the dive
##   sn        the next supernova at zoom 1.4 on its star, from 1.5 s before, 12 s
##             (FORCED into the clip: the clock is set to it)
##   remlapse  the opening as the clock runs 20 minutes at 120 times (a time-lapse:
##             the supernovae's remnants coming and fading)
##   remhold   the inner disc at 1.4, 10 s at the game's speed (the last ten
##             minutes' remnants standing in the gas)
##   zoomin    the arms at 0.6, 6 s of wheel in about the middle (5x), 1 s still
##   depthdrag the opening, 4 s of drag one way and 4 s back (the galaxy's depth)
##   depthzoom the opening, 6 s of wheel in about the middle (3x), 1 s still
func _tour(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var tour := _arg("tour", "dive")
	_chart.show_icons = "icons" in OS.get_cmdline_user_args()
	var segs: Array = []
	var cur := _chart.size * Vector2(0.62, 0.42)
	var ta := _arg("tourat", "")
	if ta == "ship":
		cur = _chart._screen_pos(Run.node_at())
	elif ta != "":
		var tf := ta.split(":")
		cur = _chart.size * Vector2(float(tf[0]), float(tf[1]))
	match tour:
		"core":
			_view(1.2, Vector2.ZERO)
			segs = [["hold", 30], ["zoom", 150, 3.0, _chart.size * 0.5], ["hold", 60]]
		"pan":
			_view(1.0, Vector2(-150, 10))
			segs = [["drag", 240, Vector2(300, -40)]]
		"sn":
			var sky0 := _chart._sky as ChartSky
			var sn: Dictionary = sky0.next_supernova(StarchartScreen.MapChart.clock_override)
			StarchartScreen.MapChart.clock_override = float(sn.t0) - 1.5
			_view(1.4, ChartSky._to_view(sn.xy, _chart.turn()))
			segs = [["hold", 360]]
		"remlapse":
			_view(0.42, Vector2.ZERO)
			segs = [["lapse", 300, 4.0]]
		"remhold":
			_view(1.4, Vector2(60, -10))
			segs = [["hold", 300]]
		"zoomin":
			_view(0.6, Vector2(60, 10))
			segs = [["zoom", 180, 5.0, _chart.size * 0.5], ["hold", 30]]
		"depthdrag":
			_view(0.42, Vector2.ZERO)
			segs = [["drag", 120, Vector2(160, 30)], ["drag", 120, Vector2(-160, -30)]]
		"depthzoom":
			_view(0.42, Vector2.ZERO)
			segs = [["zoom", 180, 3.0, _chart.size * 0.5], ["hold", 30]]
		"open":
			_view(0.42, Vector2.ZERO)
			segs = [["hold", 90], ["zoom", 150, 2.4 / 0.42, cur], ["drag", 60, Vector2(-120, -40)], ["hold", 30]]
		_:
			_view(0.42, Vector2.ZERO)
			segs = [["hold", 30], ["zoom", 150, 2.4 / 0.42, cur], ["drag", 60, Vector2(-120, -40)], ["hold", 30]]
	for _i in 6:
		await RenderingServer.frame_post_draw
	var t := StarchartScreen.MapChart.clock_override
	StarchartScreen.MapChart.clock_override = t
	var fi := 0
	for s: Array in segs:
		var n: int = s[1]
		var done := 0.0
		for i in n:
			var u := _ease(float(i + 1) / float(n))
			match String(s[0]):
				"zoom":
					var want := pow(float(s[2]), u)
					_chart._zoom_at(s[3], want / pow(float(s[2]), done))
				"drag":
					var d: Vector2 = s[2] * (u - done)
					var before: Vector2 = _chart.pan
					_chart.pan += d
					_chart._clamp_pan()
					_chart.sky_pan += _chart.pan - before
					_chart._repaint_galaxy()
			done = u
			# (a time-lapse steps the clock s[2] seconds a frame)
			t += float(s[2]) if String(s[0]) == "lapse" else 1.0 / 30.0
			StarchartScreen.MapChart.clock_override = t
			_chart._repaint_sky()
			await _frame_shot(dir, fi)
			fi += 1
	print("  chartlook: tour %s, %d frames in %s" % [tour, fi, ProjectSettings.globalize_path(dir)])


## WHAT A PART OF THE SKY COSTS (`costbench=remnants,depth|none`): one process,
## one galaxy, the part switched off and on in turns at each view (the opening, the
## arms at 1.2, the arms at 2.5, the hole at 6), eighty turns of eight frames,
## vsync off; every frame's own GPU time of the sky's viewports, and the whole
## frame's, compared at the 20th percentile (the frame with the least of the rest
## of the machine's load on it) and the median. Interleaved because this machine is
## shared: two separate runs of `chartbench` differed by half a millisecond with
## nothing changed. `none` switches nothing, to show the noise. Remnants are
## switched by `ChartSky.diag` 2048; the depth by `ChartSky.depth`.
func _cost_bench(names: String) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var sky := _chart._sky as ChartSky
	var rids: Array[RID] = []
	for vp: SubViewport in [sky._svp, sky._pvp, sky._vp]:
		RenderingServer.viewport_set_measure_render_time(vp.get_viewport_rid(), true)
		rids.append(vp.get_viewport_rid())
	var views := [["opening", 0.42, Vector2.ZERO], ["arms1.2", 1.2, Vector2(150, 20)],
		["arms2.5", 2.5, Vector2(200, 30)], ["hole6", 6.0, Vector2.ZERO]]
	var t := StarchartScreen.MapChart.clock_override
	var dep0 := ChartSky.depth()
	for nm in names.split(","):
		for v: Array in views:
			_view(v[1], v[2])
			var gpu := [[], []]
			var ft := [[], []]
			for turn in 80:
				var on := turn % 2
				ChartSky.diag = 2048 if nm == "remnants" and on == 0 else 0
				ChartSky._depth.x = 1.0 if nm == "depth" and on == 1 else (dep0.x if nm != "depth" else 0.0)
				for _w in 3:
					t += 1.0 / 60.0
					StarchartScreen.MapChart.clock_override = t
					_chart._repaint_sky()
					await RenderingServer.frame_post_draw
				for _f in 8:
					t += 1.0 / 60.0
					StarchartScreen.MapChart.clock_override = t
					_chart._repaint_sky()
					var t0 := Time.get_ticks_usec()
					await RenderingServer.frame_post_draw
					var g := 0.0
					for r in rids:
						g += RenderingServer.viewport_get_measured_render_time_gpu(r)
					(gpu[on] as Array).append(g)
					(ft[on] as Array).append(float(Time.get_ticks_usec() - t0) / 1000.0)
			var q := func(a: Array, f: float) -> float:
				var b := a.duplicate()
				b.sort()
				return float(b[int(f * (b.size() - 1))])
			print("  costbench %-8s %-8s sky GPU p20 %.3f -> %.3f (%+.3f), median %.3f -> %.3f (%+.3f); frame p20 %.2f -> %.2f (%+.2f)" % [nm, v[0],
				q.call(gpu[0], 0.2), q.call(gpu[1], 0.2), q.call(gpu[1], 0.2) - q.call(gpu[0], 0.2),
				q.call(gpu[0], 0.5), q.call(gpu[1], 0.5), q.call(gpu[1], 0.5) - q.call(gpu[0], 0.5),
				q.call(ft[0], 0.2), q.call(ft[1], 0.2), q.call(ft[1], 0.2) - q.call(ft[0], 0.2)])
	ChartSky.diag = 0
	ChartSky._depth = dep0


static func _ease(u: float) -> float:
	return u * u * (3.0 - 2.0 * u)


func _frame_shot(dir: String, i: int) -> void:
	for _k in int(_arg("clipwait", "3")):
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
