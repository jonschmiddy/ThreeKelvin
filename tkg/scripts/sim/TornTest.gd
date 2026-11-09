extends Node

## TORN AWAY's big dwarf in every style: THE RULE headless, THE DRAWING windowed.
## `-- sheet=TornTest [styles=..] [kinds=14,15] [shots=<dir>] [rulesonly]`; needs a window.
## Why: docs/why/TornTest.md#torn-test

const SEEDS := [884043030, 4242, 11]
## Jon's galaxy (BallHaloTest's): its far sky clear round the core
const DRAW_SEED := 884043030
const KINDS := [14, 15]
## The body's reach past the farthest system at least (gu): a rim system's mark is
## on lit body, not on its fading last edge
const COVER_MARGIN := 0.04
## The shader's floor margin (`chart_torn_core`'s TORN_MARGIN)
const TORN_MARGIN := 0.018
## A mark's box changed by the body over this share of its pixels: it stands on it
const ON_SHARE := 0.15
## or the box's median luma (0..255) over the void's (the darkest corner's) by this:
## lit, on a body the big one left as it was (the core's own)
const LIT_T := 8.0
## BallHaloTest's: a mark's sky may not rise more than this to past that
const MARK_RISE := 30.0
const MARK_LUMA := 110.0
const CREAM_RISE := 0.3
## The giant's bulge on the screen, half its size (a share of its half length, along
## its tilt and across): its light past this is its disc's, under which a word still reads
const GIANT_CORE := Vector2(0.12, 0.08)
## The rings lost at which the hook is drawn and judged (Jon's mockup's frames)
const HOOK_AT := [0, 3, 5, 10]

var _fails := 0
var _shots := ""


func _arg(name: String, fallback: String = "") -> String:
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with(name + "="):
			return (a as String).substr(name.length() + 1)
	return fallback


func _ok(what: String, c: bool) -> bool:
	print("  %s %s" % ["ok  " if c else "FAIL", what])
	if not c:
		_fails += 1
	return c


func _ready() -> void:
	get_viewport().gui_disable_input = true
	NavField.harness_off = true
	_shots = _arg("shots")
	if _shots != "":
		DirAccess.make_dir_recursive_absolute(_shots)
	_run.call_deferred()


func _run() -> void:
	print("\n=== TORN AWAY: the big dwarf, stripped ring by ring ===")
	var kinds: Array = []
	for s in _arg("kinds", "14,15").split(","):
		kinds.append(int(s))
	for seed_v in SEEDS:
		for k in kinds:
			_start(seed_v, k)
			for e in [&"F", &"N"]:
				_rule(seed_v, k, e)
			_hook(seed_v, k)
	if not "rulesonly" in OS.get_cmdline_user_args():
		StarchartScreen.MapChart.clock_override = 600.0
		DisplaySettings.reduced_motion = false
		for st in _arg("styles", "painted,simplified,radiant").split(","):
			DisplaySettings._harness_style = true
			DisplaySettings.render_style = DisplaySettings.valid_style(st)
			for k in kinds:
				await _drawn(StringName(st), k)
	ChartTorn.reset()
	ChartTorn.big = true
	ChartTorn.ending = &"F"
	print("torntest: %s (%d failed)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(1 if _fails > 0 else 0)


func _start(seed_v: int, kind: int) -> void:
	Rng.forced = seed_v
	Run.start_new_run(&"korvan", 1)
	Run.galaxy_kind = kind
	Run.galaxy = GalaxyGen.roll(kind)
	Run.map = MapGen.generate(Run.MAP_CANVAS)
	Run.at = 0
	Run.trail = PackedInt32Array([0])
	Run._range_cache.clear()
	Run.chart_from(Run.node_at())


## A system's radius in the galaxy's own plane (gu), as `ChartTorn.ring_r` reads it.
func _plane_r(n: MapGen.MapNode) -> float:
	return Vector2(n.gal.x, n.gal.y / maxf(float(Run.galaxy.squash), 0.05)).length()


func _rule(seed_v: int, kind: int, ending: StringName) -> void:
	ChartTorn.reset()
	ChartTorn.big = true
	ChartTorn.ending = ending
	ChartTorn.active = true
	var tag := "%s seed %d, ending %s:" % [GalaxyGen.type_name(kind), seed_v, ending]
	var far := 0.0
	for raw in Run.map:
		far = maxf(far, _plane_r(raw))
	_ok("%s the body reaches %.3f gu, past every system (the farthest %.3f)" % [tag, ChartTorn.cover(), far],
		ChartTorn.cover() >= far + COVER_MARGIN)
	var ml := ChartTorn.max_lost()
	_ok("%s %d rings can fall" % [tag, ml], ml == (14 if ending == &"N" else 10))
	var falls := true
	var prev := INF
	var edges: Array[String] = []
	for l in ml + 1:
		var e := ChartTorn.edge_at(l)
		edges.append("%.3f" % e)
		if e >= prev - 1e-6 and l > 0 or (e <= 0.0) != (l >= ml):
			falls = false
		prev = e
	_ok("%s the edge falls ring by ring to nothing at the last (%s)" % [tag, " ".join(edges)], falls)
	var outside := 0
	var off_floor := 0
	var wrong_gone := 0
	var core_gone := false
	var last_in := ml - 1 if ending == &"N" else ChartTorn.F_FOLLOW
	for l in ml + 1:
		ChartTorn.lost = float(l)
		var e := ChartTorn.edge()
		for raw in Run.map:
			var n: MapGen.MapNode = raw
			var g := ChartTorn.gone(n)
			if n.type == MapGen.NodeType.CORE:
				core_gone = core_gone or g
				continue
			if g != (n.layer < l):
				wrong_gone += 1
			if g:
				continue
			var r := _plane_r(n)
			if l <= last_in and r >= e:
				outside += 1
			if l <= last_in and r > ChartTorn.live_r() + 1e-4:
				off_floor += 1
	_ok("%s every system standing inside the edge with up to %d rings lost (%d outside)" % [tag, last_in, outside], outside == 0)
	_ok("%s every system standing inside the torn edge's floor (%d past it)" % [tag, off_floor], off_floor == 0)
	_ok("%s the lost rings' systems gone, and only theirs, the core never (%d wrong)" % [tag, wrong_gone], wrong_gone == 0 and not core_gone)
	ChartTorn.lost = float(ml)
	_ok("%s nothing of the picture at the end (edge %.3f)" % [tag, ChartTorn.edge()], ChartTorn.edge() <= 0.0)
	var st := ChartSky.ball_story(1.0)
	var alone := true
	for c: Vector4 in (st.u_storyC as PackedVector4Array):
		alone = alone and c == Vector4.ZERO
	_ok("%s no small companion round the big dwarf" % tag, alone)
	ChartTorn.reset()


## THE HOOK, headless: how far round the stream has come, the giant closing in and
## growing, and its parallax (a share of a pan, in whole blocks).
func _hook(seed_v: int, kind: int) -> void:
	ChartTorn.reset()
	ChartTorn.big = true
	ChartTorn.ending = &"F"
	ChartTorn.active = true
	var tag := "%s seed %d, the hook:" % [GalaxyGen.type_name(kind), seed_v]
	var ok := true
	var notes: Array[String] = []
	var prev_g := Vector2.INF
	for l in HOOK_AT:
		ChartTorn.lost = float(l)
		var r := ChartTorn.reach()
		var want_r := minf(1.0, 0.62 + float(l) / 10.0 * 1.3)
		var p := ChartTorn.par()
		var want_p := 0.4 + 0.04 * float(l)
		var g := ChartTorn.giant_at()
		ChartTorn.view_off = Vector2.ZERO
		ChartTorn.view_blk = 0.0
		var still := ChartTorn.hook()
		# (a pan of 120 px at the opening's zoom, in blocks of 2 px)
		ChartTorn.view_off = Vector2(-120.0, 48.0) / (ChartSky.K0 * ChartTorn.Z_OPEN)
		ChartTorn.view_blk = 2.0 / (ChartSky.K0 * ChartTorn.Z_OPEN)
		var sl := ChartTorn.slide(p)
		var exact := (1.0 - p) * ChartTorn.view_off
		var blocks := sl / ChartTorn.view_blk
		var whole := blocks.is_equal_approx(blocks.round())
		# (the root, the sweep and the turn held with the dwarf; only the end in the giant
		# slides, with the giant: a pan bends just the climb)
		var panned := ChartTorn.hook()
		var held := panned[0] == still[0] and panned[1] == still[1] and panned[2] == still[2]
		ok = ok and held and (panned[3] - still[3]).is_equal_approx(sl)
		var rib := ChartTorn.ribbon()
		var ends := rib[rib.size() - 1]
		ok = ok and absf(r - want_r) < 1e-4 and absf(p - want_p) < 1e-4 and whole
		ok = ok and (sl - exact).length() <= 0.75 * ChartTorn.view_blk and (l == 0 or g.x > prev_g.x and g.y > prev_g.y)
		ok = ok and absf(ends.w - r) < 1e-4
		notes.append("%d lost: round %.2f, parallax %.2f, giant at %s x%.2f, stream held but its end%s" % [l, r, p, (g * ChartSky.K0 * ChartTorn.Z_OPEN).round(), ChartTorn.giant_s(), "" if held else " (NOT)"])
		prev_g = g
	ChartTorn.view_off = Vector2.ZERO
	ChartTorn.view_blk = 0.0
	_ok("%s %s" % [tag, "; ".join(notes)], ok)
	ChartTorn.reset()


# ------------------------------------------------------------------ the drawing

func _drawn(st: StringName, kind: int) -> void:
	_start(DRAW_SEED, kind)
	ChartTorn.reset()
	ChartTorn.ending = &"N"
	var tag := "%-10s %-18s" % [String(st).to_upper(), GalaxyGen.type_name(kind)]
	# the dwarf as before, then big, TORN AWAY off
	ChartTorn.big = false
	var small: Image = (await _open(true)).img
	ChartTorn.big = true
	var op: Dictionary = await _open(true)
	var chart: StarchartScreen.MapChart = op.chart
	var big: Image = op.img
	_save(big, "%s_%d_big" % [st, kind])
	var void_l := _void(small)
	var on := 0
	var off: Array[String] = []
	var clouded := 0
	var view := Rect2(Vector2(6, 6), chart.size - Vector2(12, 12))
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		if n.type == MapGen.NodeType.CORE:
			continue
		var sp: Vector2 = chart._screen_pos(n)
		if not view.has_point(sp):
			continue
		if NebulaField.at(n.gal) != null:
			clouded += 1
			continue
		var s := _changed(big, small, sp)
		# (or lit already: the inner rings stand on the core's own body, which the big
		# one leaves as it was)
		if s >= ON_SHARE or _box_med(big, sp) - void_l >= LIT_T:
			on += 1
		else:
			off.append("%d L%d %.2f" % [n.index, n.layer, s])
	_ok("%s TORN AWAY off: %d systems on the body, %d off it %s (%d in a cloud, apart)" % [tag, on, off.size(), off, clouded], off.is_empty())
	# legible: the sky under the marks and YOU's name, against the dwarf as before
	var boxes := _mark_boxes(chart)
	var now := _box_lumas(big, boxes)
	var was := _box_lumas(small, boxes)
	var worst := 0.0
	var worst_i := -1
	for i in boxes.size():
		if now[i] - was[i] > worst:
			worst = now[i] - was[i]
			worst_i = i
	var hid := worst_i >= 0 and worst > MARK_RISE and now[worst_i] > MARK_LUMA
	_ok("%s marks: %d, the sky under them up %.1f at most (to %.1f)" % [tag, boxes.size(), worst, now[worst_i] if worst_i >= 0 else 0.0], not hid)
	var lu := _lumas(big)
	var lu0 := _lumas(small)
	_ok("%s light: mean %.1f (was %.1f), its cream (over 200, stars aside) %.2f%% (was %.2f%%)" % [tag, lu.x, lu0.x, lu.y, lu0.y], lu.y - lu0.y <= CREAM_RISE)
	# TORN AWAY's opening: the dwarf down and to the right (`ChartTorn.open_pan`)
	ChartTorn.active = true
	var tpan := ChartTorn.open_pan(0.42)
	# legible on: the sky under the marks with the hook drawn, against TORN AWAY off on
	# the same view (the giant, the stream and its drift over the dwarf's rim)
	ChartTorn.active = false
	var plain: Image = (await _open(false, tpan)).img
	ChartTorn.active = true
	for l in HOOK_AT:
		ChartTorn.lost = float(l)
		op = await _open(false, tpan)
		chart = op.chart
		_save(op.img, "%s_%d_hook%d" % [st, kind, l])
		# clear: the giant's middle against everything the chart prints and the controls,
		# and the giant whole in the opening
		_clear("%s %d lost:" % [tag, l], chart)
		if l <= 3:
			var hb := _mark_boxes(chart, true)
			var hn := _box_lumas(op.img, hb)
			var hw := _box_lumas(plain, hb)
			var hworst := 0.0
			var hi := -1
			for i in hb.size():
				if hn[i] - hw[i] > hworst:
					hworst = hn[i] - hw[i]
					hi = i
			_ok("%s %d lost: marks %d, the sky under them up %.1f at most with the hook (to %.1f, at %s)" % [tag, l, hb.size(), hworst, hn[hi] if hi >= 0 else 0.0, hb[hi].get_center() if hi >= 0 else Vector2.ZERO],
				not (hi >= 0 and hworst > MARK_RISE and hn[hi] > MARK_LUMA))
	# stripped: each system standing on what is left, against every ring gone
	ChartTorn.lost = float(ChartTorn.max_lost())
	var gone_img: Image = (await _open(false, tpan)).img
	_save(gone_img, "%s_%d_t%d" % [st, kind, ChartTorn.max_lost()])
	for l in [4, 8]:
		ChartTorn.lost = float(l)
		var img: Image = (await _open(false, tpan)).img
		_save(img, "%s_%d_t%d" % [st, kind, l])
		var bare: Array[String] = []
		var n_on := 0
		for raw in Run.map:
			var n: MapGen.MapNode = raw
			if n.type == MapGen.NodeType.CORE or ChartTorn.gone(n):
				continue
			var sp: Vector2 = chart._screen_pos(n)
			if not view.has_point(sp) or NebulaField.at(n.gal) != null:
				continue
			var s := _changed(img, gone_img, sp)
			# (or lit over the sky left with every ring gone: a faint body's outskirts
			# change its pixels by less than a palette step in places)
			if s >= ON_SHARE or _box_med(img, sp) - _box_med(gone_img, sp) >= LIT_T:
				n_on += 1
			else:
				bare.append("%d L%d %.2f" % [n.index, n.layer, s])
		_ok("%s %d rings lost: %d systems standing on what is left, %d off it %s" % [tag, l, n_on, bare.size(), bare], bare.is_empty())
	ChartTorn.reset()


## The giant's bulge on the screen against the chart's marks, words and controls.
func _clear(tag: String, chart: StarchartScreen.MapChart) -> void:
	var core_pt: Vector2 = chart._screen_pos(Run.map[_core_index()])
	var ze: float = chart.zoom * chart._radius() * StarchartScreen.MapChart.DISC / ChartSky.K0
	var kc := 1.0
	if ChartSky.solid():
		var w := ChartSky.SOLID_CAM
		kc = w.x / (w.x + ChartSky.SOLID_T.y * w.z)
	var gp := core_pt + ChartTorn.giant_at() * ChartSky.K0 * ze * kc
	var L := ChartTorn.giant_len() * ChartSky.K0 * ze * kc
	var half := GIANT_CORE * L
	var gbox := Rect2(gp - half, half * 2.0)
	# (its disc, to its half length along its tilt and its breadth across)
	var ca := cos(ChartTorn.GIANT_ANG)
	var sa := sin(ChartTorn.GIANT_ANG)
	var Lq := L * ChartTorn.GIANT_RY / ChartTorn.GIANT_RX
	var dh := Vector2(sqrt(L * L * ca * ca + Lq * Lq * sa * sa), sqrt(L * L * sa * sa + Lq * Lq * ca * ca))
	var disc := Rect2(gp - dh, dh * 2.0)
	var hits: Array[String] = []
	var boxes := _mark_boxes(chart)
	for b in boxes:
		if gbox.intersects(b):
			hits.append("mark %s" % b)
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		if n.type == MapGen.NodeType.CORE or ChartTorn.gone(n):
			continue
		var sp: Vector2 = chart._screen_pos(n)
		if gbox.intersects(Rect2(sp - Vector2(6, 6), Vector2(12, 12))):
			hits.append("system %d" % n.index)
	if Run.hellbender_alive() and Run.hellbender_at < Run.map.size():
		var hc: Vector2 = chart._screen_pos(Run.map[Run.hellbender_at])
		if gbox.intersects(Rect2(hc + Vector2(-46, -24), Vector2(92, 30))):
			hits.append("THE HELLBENDER")
	for q: Rect2 in chart.quest_rects:
		if gbox.intersects(q):
			hits.append("quest tag %s" % q)
	var origin := chart.get_global_rect().position
	var scp := chart.get_parent()
	while scp != null and not scp is StarchartScreen:
		scp = scp.get_parent()
	var ctl := 0
	if scp != null:
		for c in _controls(scp):
			var cr: Rect2 = (c as Control).get_global_rect()
			cr.position -= origin
			if c == chart or cr.encloses(Rect2(Vector2.ZERO, chart.size)):
				continue
			if not Rect2(Vector2.ZERO, chart.size).intersects(cr):
				continue
			ctl += 1
			if gbox.intersects(cr):
				hits.append("%s %s" % [c.name, cr])
	var inside := Rect2(Vector2.ZERO, chart.size).encloses(gbox)
	_ok("%s the giant's middle at %s clear of %d marks and %d controls over the chart%s %s" % [tag, gp.round(), boxes.size(), ctl,
		"" if inside else " (NOT inside the chart)", hits], hits.is_empty() and inside)
	_ok("%s the giant whole in the opening (its disc %s in the chart %s)" % [tag, disc, chart.size],
		Rect2(Vector2.ZERO, chart.size).encloses(disc))


func _core_index() -> int:
	for raw in Run.map:
		if (raw as MapGen.MapNode).type == MapGen.NodeType.CORE:
			return (raw as MapGen.MapNode).index
	return 0


## Every visible Control under `root` that draws something (words, a button, a panel).
func _controls(root: Node) -> Array:
	var out: Array = []
	for c in root.get_children():
		if c is Control and not (c as Control).is_visible_in_tree():
			continue
		if c is Label or c is Button or c is GoalLine or c is RichTextLabel:
			if (c as Control).size.x > 1.0:
				out.append(c)
		out.append_array(_controls(c))
	return out


## The share of a 9 x 9 box about p (px) where two pictures differ.
func _changed(a: Image, b: Image, p: Vector2) -> float:
	var n := 0
	var d := 0
	for y in range(int(p.y) - 4, int(p.y) + 5):
		for x in range(int(p.x) - 4, int(p.x) + 5):
			if x < 0 or y < 0 or x >= a.get_width() or y >= a.get_height():
				continue
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			n += 1
			if (absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)) * 255.0 > 24.0:
				d += 1
	return float(d) / maxf(float(n), 1.0)


func _save(img: Image, name: String) -> void:
	if _shots != "":
		img.save_png(_shots.path_join(name + ".png"))


## The boxes the chart's clickables stand in (BallHaloTest's): every system it shows,
## and YOU's mark and name.
## `every`: every system still standing, charted or not (the hook runs past the rim's,
## which a run charts later).
func _mark_boxes(chart: StarchartScreen.MapChart, every := false) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var here := Run.node_at()
	var visible: Dictionary = chart._visible_set(here, chart._in_range())
	for raw in Run.map:
		var nd: MapGen.MapNode = raw
		if every and not ChartTorn.gone(nd):
			visible[nd.index] = true
		if not visible.has(nd.index) or nd.type == MapGen.NodeType.CORE:
			continue
		var sp: Vector2 = chart._screen_pos(nd)
		if Rect2(Vector2.ZERO, chart.size).has_point(sp):
			out.append(Rect2(sp - Vector2(6, 6), Vector2(12, 12)))
	var yp: Vector2 = chart._screen_pos(here)
	out.append(Rect2(yp - Vector2(17, 17), Vector2(34, 34)))
	out.append(Rect2(yp + Vector2(-14, 22), Vector2(28, 10)))
	return out


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


## The chart's mean luma (0..255) and the share of it (%) that is cream light (over
## 200), a star's point aside: a pixel over 200 counts only where the 3 x 3 about it is
## (its median), so the dwarf's own stars spread over its big body, single blocks and
## pluses, are not its light blown out.
func _lumas(img: Image) -> Vector2:
	var s := 0.0
	var hi := 0
	var n := 0
	for y in range(1, img.get_height() - 1, 2):
		for x in range(1, img.get_width() - 1, 2):
			var l := _luma(img, x, y)
			s += l
			if l > 200.0:
				var v: Array[float] = []
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						v.append(_luma(img, x + dx, y + dy))
				v.sort()
				hi += 1 if v[4] > 200.0 else 0
			n += 1
	return Vector2(s / float(n), 100.0 * float(hi) / float(n))


func _luma(img: Image, x: int, y: int) -> float:
	var c := img.get_pixel(x, y)
	return (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) * 255.0


## The median luma of a 9 x 9 box about p.
func _box_med(img: Image, p: Vector2) -> float:
	var v: Array[float] = []
	for y in range(maxi(int(p.y) - 4, 0), mini(int(p.y) + 5, img.get_height())):
		for x in range(maxi(int(p.x) - 4, 0), mini(int(p.x) + 5, img.get_width())):
			v.append(_luma(img, x, y))
	v.sort()
	return v[v.size() / 2] if not v.is_empty() else 0.0


## The void's own level (BallHaloTest's): the darkest of the frame's corners.
func _void(img: Image) -> float:
	var w := img.get_width()
	var h := img.get_height()
	var lo := INF
	for p in [Vector2(30, 30), Vector2(w - 30, 30), Vector2(30, h - 30), Vector2(w - 30, h - 30)]:
		lo = minf(lo, _box_med(img, p))
	return lo


## The chart opened on the run's galaxy at the opening zoom, the core in the middle, its
## sky alone (the chart's rect). `fresh`: baked afresh, the star field built again.
func _open(fresh: bool, pan := Vector2.ZERO) -> Dictionary:
	if fresh:
		ChartSky._baked.clear()
		ChartSky._early.clear()
		StarchartScreen.MapChart._sky_cache.clear()
	var old := Router.current
	if fresh or not old is StarchartScreen:
		Router.show_starchart()
		var t0 := Time.get_ticks_msec()
		while (Router.current == old or not Router.current is StarchartScreen) and Time.get_ticks_msec() - t0 < 10000:
			await get_tree().process_frame
	var scp := Router.current as StarchartScreen
	var chart: StarchartScreen.MapChart = scp._chart
	var sky := chart._sky as ChartSky
	var t1 := Time.get_ticks_msec()
	while not sky.ready_to_draw() and Time.get_ticks_msec() - t1 < 30000:
		await get_tree().process_frame
	scp.dismiss_primer()
	chart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var k: float = chart._radius() * StarchartScreen.MapChart.DISC
	chart._go_to(0.42 * ChartSky.K0 / k, pan, false)
	chart._repaint_sky()
	chart.show_icons = false
	chart.queue_redraw()
	for _i in 8:
		await RenderingServer.frame_post_draw
	var img := chart.get_viewport().get_texture().get_image()
	var at := chart.get_global_transform_with_canvas().origin
	img = img.get_region(Rect2i(Vector2i(at.round()), Vector2i(chart.size.round())))
	chart.show_icons = true
	chart.queue_redraw()
	await RenderingServer.frame_post_draw
	return {chart = chart, img = img, k = k}
