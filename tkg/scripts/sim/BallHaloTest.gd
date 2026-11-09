extends Node

## Jon, Oct 18: ball galaxies stretched down forever; fails if reach below far exceeds above.
## Why: docs/why/BallHaloTest.md#ball-halo

const REACH_T := 6.0
const REACH_MAX := 1.3
const ASYM_MAX := 0.2
## Balls fade into space (Jon, Oct 18): `fade` fails RADIANT's hard-rimmed orb.
## Why: docs/why/BallHaloTest.md#ball-fade
const FADE_MIN := 0.42
## Clickables (Jon, Oct 19): the story may not lift a mark's sky past `MARK_LUMA`.
const MARK_RISE := 30.0
const MARK_LUMA := 110.0
## and the story's light: the chart's mean luma up at most this, its cream (over 200, % of
## the chart) at most this
const STORY_MEAN_RISE := 8.0
const STORY_CREAM_RISE := 0.3
## LOCAL REGION zooms in at least this far (the chart opens at about 0.42; a ball
## framed whole was 0.53 to 0.60)
const REGION_ZOOM := 1.0
const BALL_KINDS := [8, 9, 10, 13, 14, 15]
const DISC_KINDS := [0, 6]
## Jon's run: PGC 6236, The Drowned Coil, a giant elliptical
const SEED := 884043030

var _fails := 0
var _shots := ""
var _first := &""


func _arg(name: String, fallback: String = "") -> String:
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with(name + "="):
			return (a as String).substr(name.length() + 1)
	return fallback


func _ready() -> void:
	get_viewport().gui_disable_input = true
	# Judged without the shared field: its cloud and edge fade were read as the ball.
	# Why: docs/why/BallHaloTest.md#chart-sky
	NavField.harness_off = true
	_shots = _arg("shots")
	if _shots != "":
		DirAccess.make_dir_recursive_absolute(_shots)
	_run.call_deferred()


func _run() -> void:
	print("\n=== BALL HALO: a ball galaxy's light about its core ===")
	StarchartScreen.MapChart.clock_override = 600.0
	DisplaySettings.reduced_motion = false
	var styles := _arg("styles", "simplified,painted,radiant").split(",")
	# (Jon's galaxy as rolled; then every ball kind and two discs on its seed)
	var cases: Array = [[SEED, -1]]
	for k in BALL_KINDS + DISC_KINDS:
		cases.append([SEED, k])
	_first = StringName(styles[0])
	for st in styles:
		# in memory only, as a harness's `style=` is: nothing is saved
		DisplaySettings._harness_style = true
		DisplaySettings.render_style = DisplaySettings.valid_style(st)
		for c in cases:
			await _case(StringName(st), int(c[0]), int(c[1]))
	print("ballhalo: %s (%d failed)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(1 if _fails > 0 else 0)


func _case(st: StringName, seed_v: int, kind: int) -> void:
	Rng.forced = seed_v
	Run.start_new_run(&"korvan", 1)
	if kind >= 0:
		Run.galaxy_kind = kind
		Run.galaxy = GalaxyGen.roll(kind)
		Run.map = MapGen.generate(Run.MAP_CANVAS)
		Run.at = 0
		Run.trail = PackedInt32Array([0])
		Run._range_cache.clear()
		Run.chart_from(Run.node_at())
	var ball := ChartSky.form_of(Run.galaxy_kind) == 1
	var op: Dictionary = await _open()
	var chart: StarchartScreen.MapChart = op.chart
	var img: Image = op.img
	var k: float = op.k
	# With a story on, the ball's light is judged without it, as the story is lopsided on purpose.
	var story_on := ChartSky.form_of(Run.galaxy_kind) == 1 and ChartSky.ball_look2_now() > 0
	var img0: Image = img
	if story_on:
		var l2 := ChartSky.ball_look2
		ChartSky.ball_look2 = 0
		img0 = (await _open(true)).img
		ChartSky.ball_look2 = l2
		op = await _open(true)
		chart = op.chart
		img = op.img
	var core := chart.centre_px()
	var gu: float = chart._radius() * StarchartScreen.MapChart.DISC * chart.zoom
	var m := _measure(img0, core, gu)
	var name := "%s %s" % [GalaxyGen.type_name(Run.galaxy_kind), Run.galaxy_name if kind < 0 else "(forced)"]
	var ratio: float = maxf(m.down, 0.01) / maxf(m.up, 0.01)
	var hard: bool = ball and st == &"radiant" and m.fade < FADE_MIN
	var bad := ball and (ratio > REACH_MAX or ratio < 1.0 / REACH_MAX or absf(m.asym) > ASYM_MAX or hard)
	if bad:
		_fails += 1
	print("  %-10s %-34s reach above %.2f%s below %.2f%s gu (x%.2f)  asym %+.2f  fade %.2f%s  %s" % [
		String(st).to_upper(), name, m.up, " edge" if m.up_edge else "", m.down, " edge" if m.down_edge else "",
		ratio, m.asym, m.fade, " (a hard rim)" if hard else "", ("FAIL" if bad else "ok") if ball else "(a disc: not judged)"])
	if st == _first:
		# The region frame: systems near you, a ball's as a spiral's (Jon, Oct 21).
		var far := Run.node_at()
		for raw in Run.map:
			if (raw as MapGen.MapNode).gal.length() > far.gal.length():
				far = raw
		var view := Rect2(Vector2(-2.0, -2.0), chart.size + Vector2(4.0, 4.0))
		# (`shots=`: Jon's galaxy and the grand-design spiral as the window shows them,
		# at the opening and framed from YOU, `<seed>_<kind>_open.png` / `_region.png`)
		var film := _shots != "" and (kind == -1 or kind == 0)
		if film:
			await _window_shot("%d_%s_open" % [seed_v, str(kind) if kind >= 0 else "rolled"])
		for here: MapGen.MapNode in [Run.node_at(), far]:
			var z0 := chart.zoom
			chart.frame_region(here, 0.24, false)
			if film and here == Run.node_at():
				await _window_shot("%d_%s_region" % [seed_v, str(kind) if kind >= 0 else "rolled"])
			var near := 0
			var out := 0
			for raw in Run.map:
				var mn: MapGen.MapNode = raw
				if MapGen.hop_distance(here, mn) > 0.24:
					continue
				near += 1
				if not view.has_point(chart._screen_pos(mn)):
					out += 1
			var you_in := view.has_point(chart._screen_pos(here))
			var good := you_in and out == 0 and chart.zoom >= REGION_ZOOM
			if not good:
				_fails += 1
			print("  %-10s %-34s frame from %s: zoom %.3f -> %.3f, %d systems near, %d out of view, YOU %s  %s" % [
				String(st).to_upper(), name, "YOU" if here == Run.node_at() else "the rim", z0, chart.zoom,
				near, out, "in view" if you_in else "OUT OF VIEW", "ok" if good else "FAIL"])
		chart._go_to(0.42 * ChartSky.K0 / k, Vector2.ZERO, false)
	# Clickables must stay legible: the sky under each mark is compared with and without the story.
	if story_on:
		var boxes := _mark_boxes(chart)
		var now := _box_lumas(img, boxes)
		var was := _box_lumas(img0, boxes)
		var worst := 0.0
		var worst_i := -1
		for i in boxes.size():
			var rise: float = now[i] - was[i]
			if rise > worst:
				worst = rise
				worst_i = i
		var hid := worst_i >= 0 and worst > MARK_RISE and now[worst_i] > MARK_LUMA
		if hid:
			_fails += 1
		print("  %-10s %-34s marks: %d, the sky under them up %.1f at most (to %.1f)  %s" % [String(st).to_upper(), name,
			boxes.size(), worst, now[worst_i] if worst_i >= 0 else 0.0, "FAIL" if hid else "ok"])
		# and the light: no blow-out (the brightness the balls were brought to, Oct 18)
		var lu := _lumas(img)
		var lu0 := _lumas(img0)
		var hot: bool = lu.x - lu0.x > STORY_MEAN_RISE or lu.y - lu0.y > STORY_CREAM_RISE
		if hot:
			_fails += 1
		print("  %-10s %-34s light: mean %.1f (was %.1f), over 200 %.2f%% (was %.2f%%)  %s" % [String(st).to_upper(), name,
			lu.x, lu0.x, lu.y, lu0.y, "FAIL" if hot else "ok"])
	if _shots != "":
		# (Jon's galaxy as rolled is `_rolled`: by its kind it took the forced giant's name)
		img.save_png(_shots.path_join("%s_%d_%s.png" % [st, seed_v, str(kind) if kind >= 0 else "rolled"]))


## Down a vertical line through the core: how far the light reaches each way and
## how evenly it is shared, out to the nearer frame edge (gu).
func _measure(img: Image, core: Vector2, gu: float) -> Dictionary:
	var w := img.get_width()
	var h := img.get_height()
	var cx := int(core.x)
	var cy := int(core.y)
	# the void's own level: the darkest of the frame's corners
	var void_l := INF
	for p in [Vector2i(30, 30), Vector2i(w - 30, 30), Vector2i(30, h - 30), Vector2i(w - 30, h - 30)]:
		void_l = minf(void_l, _row(img, p.y, p.x - 15, p.x + 15))
	var room := mini(cy - 2, h - 3 - cy)
	var la: Array[float] = []
	var lb: Array[float] = []
	for d in room + 1:
		la.append(_row(img, cy - d, cx - 40, cx + 41) - void_l)
		lb.append(_row(img, cy + d, cx - 40, cx + 41) - void_l)
	# (from just outside the hole's shadow and lens)
	var d0 := int(0.06 * gu)
	var up := _reach(la, d0)
	var dn := _reach(lb, d0)
	var sa := 0.0
	var sb := 0.0
	for d in range(d0, maxi(up, dn) + 1):
		sa += maxf(la[d], 0.0)
		sb += maxf(lb[d], 0.0)
	# how the light ends: from 0.4 of its light at 0.1 gu to the reach, as a share of the
	# reach, each way and averaged
	var d10 := mini(int(0.1 * gu), room)
	var fades: Array[float] = []
	for pair in [[la, up], [lb, dn]]:
		var l: Array[float] = pair[0]
		var r: int = pair[1]
		var d40 := r
		for d in range(d10, r + 1):
			if l[d] < 0.4 * l[d10]:
				d40 = d
				break
		fades.append(float(r - d40) / maxf(float(r), 1.0))
	return {
		up = up / gu, down = dn / gu, up_edge = up >= room, down_edge = dn >= room,
		asym = (sb - sa) / maxf(sb + sa, 1e-6), fade = (fades[0] + fades[1]) * 0.5,
	}


## The last px out from d0 before the light first stays at or under REACH_T for
## three rows running (a star's row or a dither's step is not the light ending).
func _reach(l: Array[float], d0: int) -> int:
	var last := d0
	var dark := 0
	for d in range(d0, l.size()):
		if l[d] > REACH_T:
			last = d
			dark = 0
		else:
			dark += 1
			if dark >= 3:
				break
	return last


## The median luma of a row's run of pixels (0..255): stars are points.
func _row(img: Image, y: int, x0: int, x1: int) -> float:
	var v: Array[float] = []
	for x in range(maxi(x0, 0), mini(x1, img.get_width())):
		var c := img.get_pixel(x, y)
		v.append((0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) * 255.0)
	v.sort()
	return v[v.size() / 2] if not v.is_empty() else 0.0


## The chart's sky alone at the opening zoom; `fresh` rebakes, as a style keeps its first bake.
func _window_shot(name: String) -> void:
	for _i in 8:
		await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
	img.save_png(_shots.path_join(name + ".png"))


func _open(fresh: bool = false) -> Dictionary:
	if fresh:
		ChartSky._baked.clear()
		ChartSky._early.clear()
	var old := Router.current
	Router.show_starchart()
	var t0 := Time.get_ticks_msec()
	while (Router.current == old or not Router.current is StarchartScreen) and Time.get_ticks_msec() - t0 < 10000:
		await get_tree().process_frame
	var scp := Router.current as StarchartScreen
	var chart: StarchartScreen.MapChart = scp._chart
	var sky := chart._sky as ChartSky
	while not sky.ready_to_draw() and Time.get_ticks_msec() - t0 < 30000:
		await get_tree().process_frame
	scp.dismiss_primer()
	chart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# the chart's opening zoom (ChartLook's `opening`), the core in the middle
	var k: float = chart._radius() * StarchartScreen.MapChart.DISC
	chart._go_to(0.42 * ChartSky.K0 / k, Vector2.ZERO, false)
	chart._repaint_sky()
	chart.show_icons = false
	chart.queue_redraw()
	for _i in 8:
		await RenderingServer.frame_post_draw
	var img := chart.get_viewport().get_texture().get_image()
	var at := chart.get_global_transform_with_canvas().origin
	img = img.get_region(Rect2i(Vector2i(at.round()), Vector2i(chart.size.round())))
	chart.show_icons = true
	return {chart = chart, img = img, k = k}


## The boxes the chart's clickables stand in (the chart's rect, px): every system it
## shows, and YOU's mark and name.
func _mark_boxes(chart: StarchartScreen.MapChart) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var here := Run.node_at()
	var visible: Dictionary = chart._visible_set(here, chart._in_range())
	for raw in Run.map:
		var nd: MapGen.MapNode = raw
		if not visible.has(nd.index) or nd.type == MapGen.NodeType.CORE:
			continue
		var sp: Vector2 = chart._screen_pos(nd)
		if Rect2(Vector2.ZERO, chart.size).has_point(sp):
			out.append(Rect2(sp - Vector2(6, 6), Vector2(12, 12)))
	var yp: Vector2 = chart._screen_pos(here)
	out.append(Rect2(yp + Vector2(-14, 22), Vector2(28, 10)))
	return out


## The mean luma (0..255) of the sky under each box.
func _box_lumas(img: Image, boxes: Array[Rect2]) -> Array[float]:
	var out: Array[float] = []
	for b in boxes:
		var s := 0.0
		var n := 0
		for y in range(maxi(int(b.position.y), 0), mini(int(b.end.y), img.get_height())):
			for x in range(maxi(int(b.position.x), 0), mini(int(b.end.x), img.get_width())):
				var c := img.get_pixel(x, y)
				s += (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) * 255.0
				n += 1
		out.append(s / maxf(float(n), 1.0))
	return out


## The chart's mean luma (0..255) and its share over 200 (%).
func _lumas(img: Image) -> Vector2:
	var s := 0.0
	var hi := 0
	var n := 0
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			var c := img.get_pixel(x, y)
			var l := (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) * 255.0
			s += l
			hi += 1 if l > 200.0 else 0
			n += 1
	return Vector2(s / float(n), 100.0 * float(hi) / float(n))
