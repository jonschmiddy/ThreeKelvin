extends Node

## The star chart photographed twice at each view, whole and with its systems
## hidden, for mocking up a new look for its sky with the systems laid back on
## top unchanged:
##   godot --path . -- sheet=ChartLook out=<dir> [kind=N] [squash=S] [views=Z:X:Y,...] [clock=T] [neblook=N]
## A view's X of `neb` centres it on a cloud (`1.5:neb:0`); `neblook=N` draws
## the named clouds in treatment N (`ChartSky.nebula_look`), and `starlevel=N`
## draws N's density of stars (`ChartSky.star_level`), `holelook=N` the black
## hole in look N (`ChartSky.hole_look`), `holebands=N` its light shaded in
## bands N (`ChartSky.hole_bands`), `holeband=A` part way to the warm bands
## (`ChartSky.hole_band_amt`, 0 to 1). `allsys` shows every system, not only
## the charted ones; a view's X of `ship` centres it on YOU (`3:ship:0`).
## `depthlook=N` draws the sky's depth in look N (`ChartSky.depth_look`),
## `depthamt=A` at strength A (`ChartSky.depth_amt`); `volume=N` the disc as a
## volume of height N (`ChartSky.volume_look`).
## `squash=S` tilts the galaxy to S (how foreshortened the disc is; the sector
## map's plane is at 0.38) before the chart is drawn. `views=` replaces the
## three views with zooms and pans of your own (`1.66:0:0,6:40:-20`), and
## `clock=T` holds the sky's clock at T seconds (`MapChart.clock_override`),
## so a shot can be set beside the mockup at the same turn. `clocks=T0:T1:N`
## photographs each view N times with the clock stepped from T0 to T1, sky
## only (`<view>_tNNN.png`): a snap in the turning shows as one step unlike
## the rest.
## Writes <view>_full.png and <view>_sky.png. Needs a window; leave it alone
## while it runs (a Tab or a click changes screens under it).

var out := "user://chartlook"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with("out="):
			out = (a as String).substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	get_viewport().gui_disable_input = true
	Rng.forced = 4242
	Run.start_new_run(&"korvan", 1)
	# `kind=N`: a chosen galaxy kind, its map laid out again, as ChartShot does it
	for a1 in OS.get_cmdline_user_args():
		if (a1 as String).begins_with("kind="):
			Run.galaxy_kind = clampi(int((a1 as String).substr(5)), 0, GalaxyGen.count() - 1)
			Run.galaxy = GalaxyGen.roll(Run.galaxy_kind)
			Run.map = MapGen.generate(Run.MAP_CANVAS)
			Run.at = 0
			Run.trail = PackedInt32Array([0])
			Run._range_cache.clear()
			Run.chart_from(Run.node_at())
	for a2 in OS.get_cmdline_user_args():
		if (a2 as String).begins_with("squash="):
			Run.galaxy["squash"] = float((a2 as String).substr(7))
	print("  chartlook: galaxy %s at squash %.2f" % [Run.galaxy.get("name", "?"), float(Run.galaxy.get("squash", 1.0))])
	for a4 in OS.get_cmdline_user_args():
		if (a4 as String).begins_with("holelook="):
			ChartSky.hole_look = int((a4 as String).substr(9))
		elif (a4 as String).begins_with("holebands="):
			ChartSky.hole_bands = int((a4 as String).substr(10))
		elif (a4 as String).begins_with("holeband="):
			ChartSky.hole_band_amt = float((a4 as String).substr(9))
		elif (a4 as String).begins_with("depthlook="):
			ChartSky.depth_look = int((a4 as String).substr(10))
		elif (a4 as String).begins_with("neblook="):
			# (before the chart opens: the bake reads it -- which clouds are
			# in the list, and the colours its palette keeps)
			ChartSky.nebula_look = int((a4 as String).substr(8))
		elif (a4 as String).begins_with("clusters="):
			ChartSky.cluster_look = int((a4 as String).substr(9))
		elif (a4 as String) == "billow":
			# (and reduced motion off for the shot, in memory only: it is saved
			# on in this machine's settings)
			ChartSky.gas_billow = true
			DisplaySettings.reduced_motion = false
		elif (a4 as String).begins_with("gas="):
			ChartSky.gas_look = int((a4 as String).substr(4))
		elif (a4 as String).begins_with("volume="):
			ChartSky.volume_look = int((a4 as String).substr(7))
		elif (a4 as String).begins_with("depthamt="):
			ChartSky.depth_amt = float((a4 as String).substr(9))
		elif (a4 as String) == "allsys":
			StarchartScreen._show_all = true
	# `nebkind=F:T`: the first cloud of kind F made kind T for the shot (no
	# emission cloud rolls on this seed)
	for a5 in OS.get_cmdline_user_args():
		if (a5 as String).begins_with("nebkind="):
			var kk := (a5 as String).substr(8).split(":")
			for raw in NebulaField.clouds():
				var cl: NebulaField.Cloud = raw
				if int(cl.kind) == int(kk[0]):
					cl.kind = int(kk[1]) as NebulaField.Kind
					break
	Router.show_starchart()
	var warm := Time.get_ticks_msec()
	while Time.get_ticks_msec() - warm < 2500:
		await get_tree().process_frame
	(Router.current as StarchartScreen).dismiss_primer()
	for _i in 30:
		await get_tree().process_frame
	var chart = (Router.current as StarchartScreen)._chart
	var gp := ChartSky.params()
	var kinds := []
	for raw in NebulaField.clouds():
		kinds.append(NebulaField.Kind.keys()[(raw as NebulaField.Cloud).kind])
	print("  chartlook: clouds %s" % [kinds])
	print("  chartlook: kind %d bulge %.2f bsq %.3f eff %.3f, %.2f screen px a bake px at zoom 1; climb to %.1f, hole edge %.1f, disc rim %.1f bake px" % [
		Run.galaxy_kind, float(gp.bul), float(gp.bsq), float(gp.eff),
		chart._radius() * StarchartScreen.MapChart.DISC / float(gp.big_r),
		float(gp.rb), float(gp.rin_p), float(gp.big_r)])
	var clocks := Vector3.ZERO
	var views: Array = [["default", 0.42, Vector2.ZERO], ["mid", 1.0, Vector2.ZERO], ["close", 2.9, Vector2(60, -30)]]
	for a3 in OS.get_cmdline_user_args():
		var arg := a3 as String
		if arg.begins_with("starlevel="):
			ChartSky.star_level = int(arg.substr(10))
		elif arg.begins_with("neblook="):
			ChartSky.nebula_look = int(arg.substr(8))
		elif arg.begins_with("clocks="):
			var c := arg.substr(7).split(":")
			clocks = Vector3(float(c[0]), float(c[1]), float(c[2]))
		elif arg.begins_with("clock="):
			StarchartScreen.MapChart.clock_override = float(arg.substr(6))
		elif arg.begins_with("views="):
			views = []
			for spec in arg.substr(6).split(","):
				var f := (spec as String).split(":")
				var at := Vector2(float(f[1]), float(f[2]))
				if f[1] == "ship":
					# centred on YOU
					at = -chart._proj_unit(Run.node_at().gal) * float(f[0])
				elif f[1].begins_with("neb"):
					# centred on a cloud that shines: `neb` the nearest the
					# middle (a remnant or planetary first), `nebK` one of kind K
					var want := int(f[1].substr(3)) if f[1].length() > 3 else -1
					at = _cloud_pan(chart, float(f[0]), want)
					_view_cloud["z%s_%s_%s" % [f[0], f[1], f[2]]] = _last_cloud
				views.append(["z%s_%s_%s" % [f[0], f[1], f[2]], float(f[0]), at])
	for v in views:
		if clocks.z > 0.0:
			chart._go_to(v[1], v[2], false)
			chart.show_icons = false
			for i in int(clocks.z):
				StarchartScreen.MapChart.clock_override = lerpf(clocks.x, clocks.y, float(i) / maxf(1.0, clocks.z - 1.0))
				chart._repaint_sky()
				await _shot("%s_t%03d" % [v[0], i])
			continue
		chart._go_to(v[1], v[2], false)
		chart.show_icons = true
		_place_cursor(chart)
		if "outline" in OS.get_cmdline_user_args() and _view_cloud.has(v[0]):
			chart._neb_hot = _view_cloud[v[0]]
			chart.queue_redraw()
		chart._repaint_sky()
		await _shot("%s_full" % v[0])
		chart.show_icons = false
		chart._repaint_sky()
		await _shot("%s_sky" % v[0])
	chart.show_icons = true
	get_tree().quit()


## `cursor=X:Y`: the pointer held at (X, Y) in the chart's own pixels, so the
## scanning cursor is in the picture.
func _place_cursor(chart: Node) -> void:
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with("cursor="):
			var f := (a as String).substr(7).split(":")
			chart._cursor = Vector2(float(f[0]), float(f[1]))
			if chart._cross != null:
				chart._cross.queue_redraw()


## The pan that puts a cloud that shines in the middle at zoom z: a remnant
## or planetary if there is one, else the cloud nearest the galaxy's centre.
func _cloud_pan(chart: Node, z: float, want: int = -1) -> Vector2:
	var best: NebulaField.Cloud = null
	var score := INF
	for raw in NebulaField.clouds():
		var cl: NebulaField.Cloud = raw
		if (cl.kind == NebulaField.Kind.DARK and want != int(NebulaField.Kind.DARK)) or (want >= 0 and int(cl.kind) != want):
			continue
		var sc := cl.pos.length()
		if cl.kind == NebulaField.Kind.REMNANT or cl.kind == NebulaField.Kind.PLANETARY:
			sc -= 10.0
		if sc < score:
			score = sc
			best = cl
	if best == null:
		return Vector2.ZERO
	_last_cloud = best.name
	chart.zoom = z
	return -chart._proj_unit(best.pos) * z


## The cloud the last `neb` view centred on, and the views' clouds in order:
## `outline` draws each one's outline as if pointed at.
var _last_cloud := ""
var _view_cloud: Dictionary = {}


func _shot(name: String) -> void:
	for _i in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
