extends Node

## THE SECTOR MAP'S CPU AND GPU TRIMS DRAW WHAT THEY DREW (the Mac's map, Oct 27):
##   godot --headless --path . -- sheet=MapPerfTest [seeds=4242,77,1301]
##   godot --path . -- sheet=MapPerfTest palcache        (needs a window)
##
## Each trim is held to the code it replaced, through the real map:
##   * THE DUST: a wisp sheet whose colour is black (a clear sky, outside LEGACY)
##     is not built (`SystemView._wisps_blank`); every fluff sheet keeps the seed
##     it had when the wisps were built before it (HIGH and LOW), and a cloud,
##     a pulsar and the core keep all nine sheets;
##   * THE ORBITS: `_Lines.orbit_runs` -- the camera read once, the points
##     worked out in place, stretches off the frame skipped -- gives exactly the
##     lines the old loop did (kept below, `_old_runs`, as it was), point for
##     point and colour for colour, and the same with the skipping off, over
##     cameras from the whole system to the closest zoom and panned past the
##     frame's edges;
##   * THE BELTS: each rock's draws from the belt's table are the generator's own;
##   * THE LINE: `ShipFlight._run_line` with the centres worked out once a frame
##     (`_centres`) is the line it was with each centre worked out where it was
##     needed, from many states in every system, and it prints how long each
##     took.
## `palcache` (windowed): a system shown, another, the first again -- the second
## visit to it cuts no palette and wears the first visit's; and a third visit with
## the cache off cuts one afresh, printed against the first (how many of its
## colours moved), with how long each visit took to its palette.

const SystemViewS := preload("res://scripts/ui/sysmap/SystemView.gd")
const ScreenS := preload("res://scripts/ui/sysmap/SystemMapScreen.gd")
const ShipFlightS := preload("res://scripts/ui/sysmap/ShipFlight.gd")

var _fails := 0
var _checks := 0


func _ok(what: String, cond: bool) -> bool:
	_checks += 1
	if not cond:
		_fails += 1
		print("  FAIL %s" % what)
	return cond


func _ready() -> void:
	await get_tree().process_frame
	if "palcache" in OS.get_cmdline_user_args():
		await _palcache()
	else:
		var seeds := [4242, 77, 1301]
		for a in OS.get_cmdline_user_args():
			if (a as String).begins_with("seeds="):
				seeds = []
				for s in (a as String).substr(6).split(","):
					seeds.append(int(s))
		for sd: int in seeds:
			await _seed(sd)
	print("  mapperftest: %d checks" % _checks)
	print("mapperftest: %s" % ("PASS" if _fails == 0 else "%d FAILURES" % _fails))
	get_tree().quit()


## The systems of one run worth looking at: clear skies, a cloud, a pulsar, the
## core, a station, a belt.
func _pick() -> Array:
	var out: Array = []
	var want := {"clear": 2, "nebula": 1, "pulsar": 1, "core": 1, "station": 1, "belt": 1}
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		var key := ""
		if n.type == MapGen.NodeType.PULSAR:
			key = "pulsar"
		elif n.type == MapGen.NodeType.CORE:
			key = "core"
		elif n.type == MapGen.NodeType.STATION:
			key = "station"
		elif n.type == MapGen.NodeType.SYSTEM:
			key = "nebula" if n.in_nebula else "clear"
			if not n.in_nebula and SystemLayout.of(n).bodies.any(func(b: SystemLayout.Body) -> bool: return b.kind == &"belt"):
				key = "belt" if int(want.belt) > 0 else "clear"
		if key != "" and int(want.get(key, 0)) > 0:
			want[key] = int(want[key]) - 1
			out.append([key, n])
	return out


func _seed(sd: int) -> void:
	Rng.forced = sd
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	print("  mapperftest: seed %d" % sd)
	var view: Control = SystemViewS.new()
	add_child(view)
	for e: Array in _pick():
		var key: String = e[0]
		var n: MapGen.MapNode = e[1]
		for low: bool in [false, true]:
			DisplaySettings.graphics_low = low
			await view.show_system(n)
			_dust(view, key, low)
		DisplaySettings.graphics_low = false
		await view.show_system(n)
		view.window = Rect2(0, 0, 960, 540)
		await _lines(view, key)
		_belts(view, key)
		_line(view, key)
	view.queue_free()
	await get_tree().process_frame


## THE DUST SHEETS against the old build: the far sheets in DEPTH_FAR order (LOW:
## the fluff alone), then four near ones in HIGH, each far sheet seeded by its
## place among them.
func _dust(view, key: String, low: bool) -> void:
	var blank: bool = view._wisps_blank()
	var dl: Array = view._depth_look()
	_ok("%s: a blank wisp is a black one outside LEGACY" % key, blank == (not view.legacy and dl[3] == Vector3.ZERO))
	if key == "nebula" or key == "pulsar" or key == "core":
		_ok("%s keeps its wisps" % key, not blank)
	var far_old: Array = []
	for fi in SystemViewS.DEPTH_FAR.size():
		if low and int(SystemViewS.DEPTH_FAR[fi][2]) == 0:
			continue
		far_old.append(fi)
	var far_new: Array = []
	var near := 0
	var seeds: Array = []
	for d: Array in view._depth:
		if int(d[2]) < 0:
			far_new.append(d)
			seeds.append(float((d[0] as ShaderMaterial).get_shader_parameter("seed")))
		else:
			near += 1
	if SystemViewS.depth_k <= 0.0:
		_ok("%s: no sheets with no dust" % key, view._depth.is_empty())
		return
	var k := 0
	var j := 0
	for oi in far_old.size():
		var fi: int = far_old[oi]
		var wisp := int(SystemViewS.DEPTH_FAR[fi][2]) == 0
		if blank and wisp:
			continue
		if not _ok("%s%s: far sheet %d built" % [key, " LOW" if low else "", fi], j < far_new.size()):
			return
		var want_seed := float(view.node.index) * 1.37 + float(oi) * 11.3
		_ok("%s%s: far sheet %d (look %d) keeps its seed %.3f (has %.3f)" % [key, " LOW" if low else "", fi, int(SystemViewS.DEPTH_FAR[fi][2]), want_seed, seeds[j]],
			is_equal_approx(seeds[j], want_seed) and int((far_new[j][0] as ShaderMaterial).get_shader_parameter("look")) == int(SystemViewS.DEPTH_FAR[fi][2]))
		j += 1
		k += 1
	_ok("%s%s: %d far sheets, as many as the old build less its blank wisps" % [key, " LOW" if low else "", far_new.size()], far_new.size() == k)
	var near_want := 0 if low or blank else SystemViewS.DEPTH_NEAR
	_ok("%s%s: %d near sheets (want %d)" % [key, " LOW" if low else "", near, near_want], near == near_want)
	if not low:
		print("  mapperftest:   %s: %d dust sheets (%s)" % [key, view._depth.size(), "wisps black, not built" if blank else "all built"])


## THE ORBITS at cameras from the whole system in, panned about and off the
## frame's edges: the new lines, with and without the skipping, and the old.
func _lines(view, key: String) -> void:
	var zs := [0.35, 0.6, 1.0, 1.6, 2.5, 3.3, 4.0]
	var rng := RandomNumberGenerator.new()
	rng.seed = 99 + view.node.index
	var n_runs := 0
	var n_pts := 0
	var skipped := 0
	var t_new := 0
	var t_old := 0
	for zi in zs.size():
		for pi in 6:
			view.zoom = zs[zi]
			view.pan = Vector2.ZERO if pi == 0 else Vector2(rng.randf_range(-900, 900), rng.randf_range(-500, 500)) * zs[zi]
			view.t = rng.randf_range(0.0, 400.0)
			# (a step settles the worlds where they are drawn: their places, sizes)
			for _i in 2:
				view.step()
			var t0 := Time.get_ticks_usec()
			var a: Array = view._lines.orbit_runs(true)
			var t1 := Time.get_ticks_usec()
			var b: Array = view._lines.orbit_runs(false)
			var t2 := Time.get_ticks_usec()
			var c: Array = _old_runs(view)
			var t3 := Time.get_ticks_usec()
			t_new += t1 - t0
			t_old += t3 - t2
			var where := "%s zoom %.2f pan (%d, %d)" % [key, view.zoom, view.pan.x, view.pan.y]
			if not _ok("%s: the lines with the skip are the lines without (%d runs, %d)" % [where, a.size(), b.size()], _same(a, b)):
				return
			if not _ok("%s: the lines are the old loop's (%d runs, %d)" % [where, a.size(), c.size()], _same(a, c)):
				return
			n_runs += a.size()
			for r: Array in a:
				n_pts += (r[0] as PackedVector2Array).size()
	print("  mapperftest:   %s: orbits identical at %d cameras (%d stretches, %d points); %.2f ms new, %.2f ms old a camera" % [key, zs.size() * 6, n_runs, n_pts,
		float(t_new) / 1000.0 / float(zs.size() * 6), float(t_old) / 1000.0 / float(zs.size() * 6)])
	view.zoom = 1.0
	view.pan = Vector2.ZERO


static func _same(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if a[i][0] != b[i][0] or a[i][1] != b[i][1]:
			return false
	return true


## The orbits' loop as it was before the trim (SystemView `_Lines._draw`, Oct 27
## main), its draws collected instead of drawn.
static func _old_runs(view) -> Array:
	var out: Array = []
	var self_lines = view._lines
	var L: SystemLayout = view.layout
	var win: Rect2 = view.window.grow(4.0)
	var o: Vector2 = view.origin()
	var hole: Vector2 = self_lines._star_hole()
	var odepth: bool = view.orbit_depth
	var TILT: float = SystemViewS.TILT
	for bi in L.bodies.size():
		var b := L.bodies[bi]
		if b.kind == &"belt":
			continue
		var ea: float = b.orbit * view.zoom
		var eb: float = ea * TILT
		var per: float = PI * (3.0 * (ea + eb) - sqrt((3.0 * ea + eb) * (ea + 3.0 * eb)))
		var n := clampi(int(per / 1.2), 64, 3000)
		var own: bool = view._views.has(bi)
		var own_r: float = view.draw_r(view.layout.bodies[bi]) + 1.5
		var ring_ab := Vector2.ZERO
		if own:
			var vw: Node2D = view._views[bi]
			var vm: ShaderMaterial = vw.get("_mat")
			var rmode: Variant = vm.get_shader_parameter("ring_mode") if vm != null else null
			var rout: Variant = vm.get_shader_parameter("ring_out") if vm != null else null
			if rmode != null and rout != null and int(rmode) == 1 and bool((vw.get("spec") as Dictionary).get("ring", false)):
				var ra: float = float(rout) * (own_r - 1.5) + 2.0
				ring_ab = Vector2(ra, ra * 0.28 + 1.5)
		var a0: float = b.phase + (view.t / b.period) * TAU
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		for i in n + 1:
			var a := float(i) / float(n) * TAU
			var op: Vector3 = b.orbit_point(a)
			var sp: Vector2 = view.screen(op.x, op.z)
			var off_world := own and sp.distance_squared_to(view.at[bi]) < own_r * own_r
			if ring_ab.x > 0.0 and not off_world:
				var rq: Vector2 = (sp - view.world_c(bi)) / ring_ab
				off_world = rq.length_squared() < 1.0
			if not win.has_point(sp) or pow((sp.x - o.x) / hole.x, 2.0) + pow((sp.y - o.y) / hole.y, 2.0) < 1.0 or off_world:
				if pts.size() > 1:
					out.append([pts, cols])
				pts = PackedVector2Array()
				cols = PackedColorArray()
				continue
			var behind := fposmod(a0 - a, TAU)
			var tr := pow(1.0 - behind / 2.1, 1.6) if behind < 2.1 else 0.0
			var c := Vector3(0.55, 0.58, 0.62).lerp(Vector3(0.82, 0.85, 0.9), tr)
			var q: Vector2 = sp.round()
			if pts.size() > 0 and pts[pts.size() - 1] == q:
				continue
			pts.append(q)
			var dk := 1.0
			if odepth:
				var dz := smoothstep(-1.0, 1.0, op.z / maxf(b.orbit, 1.0))
				if view.painted:
					dz = 0.0 if dz < 0.33 else (0.5 if dz < 0.67 else 1.0)
				dk = lerpf(0.6, 1.45, dz)
			cols.append(Color(c.x, c.y, c.z, (0.14 + tr * 0.38) * dk))
		if pts.size() > 1:
			out.append([pts, cols])
	return out


## THE BELTS' TABLE is the generator's draws, rock for rock, as it grows.
func _belts(view, key: String) -> void:
	for b: SystemLayout.Body in view.layout.bodies:
		if b.kind != &"belt":
			continue
		var bl = view._belts
		# (from an empty table, as a belt's first frame finds it -- the map's frames
		# have grown it already; and the 300 rocks' table COPIED, since growing it
		# to 1,200 grows that same array)
		(bl._rtab as Dictionary).erase(b.index)
		var small: PackedFloat64Array = (bl._rock_draws(b, 300) as PackedFloat64Array).duplicate()
		var big: PackedFloat64Array = bl._rock_draws(b, 1200)
		var R := Worlds.XRng.new(floor(b.orbit * 13.0))
		var same := small.size() == 2100 and big.size() == 8400
		for i in 8400:
			var v := R.next()
			if big[i] != v or (i < 2100 and small[i] != v):
				same = false
				break
		_ok("%s: belt %d's table is its generator's 8,400 draws in order" % [key, b.index], same)


## THE LINE from many states of the ship, with the centres shared and without.
func _line(view, key: String) -> void:
	var L: SystemLayout = view.layout
	var fl = ShipFlightS.new()
	fl.setup(L, Vector2(L.edge * 0.9, -210.0), 0.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7 + view.node.index
	var keysets := [{"w": false, "a": false, "s": false, "d": false}, {"w": true, "a": false, "s": false, "d": false},
		{"w": true, "a": true, "s": false, "d": false}, {"w": false, "a": false, "s": true, "d": true}]
	var t_new := 0
	var t_old := 0
	var outs := {}
	var n := 0
	for k in 40:
		var t := rng.randf_range(0.0, 600.0)
		# a place's ring to aim at now and then, so the line ends in captures too
		var p := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(L.star_r + 40.0, L.edge)
		if k % 3 == 0 and not L.bodies.is_empty():
			var bi := rng.randi() % L.bodies.size()
			var c3: Vector3 = fl.center(bi, t)
			p = Vector2(c3.x, c3.z) + Vector2.from_angle(rng.randf() * TAU) * 60.0
		fl.f = ShipFlightS.FreeState.new()
		fl.f.p = p
		fl.f.v = Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, 150.0)
		fl.f.head = rng.randf() * TAU
		fl.f.sense = 1.0 if rng.randf() < 0.5 else -1.0
		fl.mode = &"free"
		var kk: Dictionary = keysets[k % keysets.size()]
		var none := {"w": false, "a": false, "s": false, "d": false}
		# (as `predict` runs them: the line, then the held line on the same table)
		fl._ctab.clear()
		var t0 := Time.get_ticks_usec()
		var a0: Dictionary = fl._run_line(t, none, 0.0)
		var a1: Dictionary = fl._run_line(t, kk, 1.5)
		var t1 := Time.get_ticks_usec()
		ShipFlightS.centre_table = false
		var b0: Dictionary = fl._run_line(t, none, 0.0)
		var b1: Dictionary = fl._run_line(t, kk, 1.5)
		ShipFlightS.centre_table = true
		var t2 := Time.get_ticks_usec()
		t_new += t1 - t0
		t_old += t2 - t1
		n += 1
		for pr: Array in [[a0, b0, "line"], [a1, b1, "held line"]]:
			var a: Dictionary = pr[0]
			var b: Dictionary = pr[1]
			var ka: StringName = (a.out as Dictionary).get("kind", &"none")
			outs[ka] = int(outs.get(ka, 0)) + 1
			if not _ok("%s: the %s from state %d is the same with the centres shared" % [key, pr[2], k],
					a.pts == b.pts and a.out == b.out and a.fast == b.fast and a.bump == b.bump):
				return
	print("  mapperftest:   %s: %d pairs of lines identical %s; %.3f ms a pair shared, %.3f ms not" % [key, n, str(outs),
		float(t_new) / 1000.0 / float(n), float(t_old) / 1000.0 / float(n)])


# ---------------------------------------------------------------- the palette cache
func _palcache() -> void:
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var picks := _pick()
	var a: MapGen.MapNode = null
	var b: MapGen.MapNode = null
	for e: Array in picks:
		if e[0] == "belt" or e[0] == "clear":
			if a == null:
				a = e[1]
			elif b == null:
				b = e[1]
	var neb: MapGen.MapNode = null
	for e: Array in picks:
		if e[0] == "nebula":
			neb = e[1]
	var content := Control.new()
	content.position = Vector2(8, 32)
	content.size = Vector2(944, 501)
	add_child(content)
	var scr: Control = ScreenS.new()
	content.add_child(scr)
	for pair: Array in [[a, b], [neb, a]]:
		var n: MapGen.MapNode = pair[0]
		if n == null or pair[1] == null:
			continue
		var cuts0: int = SystemViewS.pal_cuts
		var first := await _visit(scr, n)
		_ok("system %d: the first visit cut its palette (%d colours, %.0f ms to it)" % [n.index, first.pal.size(), first.ms], SystemViewS.pal_cuts == cuts0 + 1 and first.pal.size() > 0)
		await _visit(scr, pair[1])
		var cuts1: int = SystemViewS.pal_cuts
		var again := await _visit(scr, n)
		_ok("system %d: back again, no palette cut (%.0f ms to it)" % [n.index, again.ms], SystemViewS.pal_cuts == cuts1)
		_ok("system %d: back again, its first visit's palette" % n.index, again.pal == first.pal)
		SystemViewS.pal_cache_on = false
		var fresh := await _visit(scr, n)
		SystemViewS.pal_cache_on = true
		var moved := 0
		for i in maxi(fresh.pal.size(), first.pal.size()):
			if i >= fresh.pal.size() or i >= first.pal.size() or not (fresh.pal[i] as Vector3).is_equal_approx(first.pal[i]):
				moved += 1
		# (how far: each recut colour to the nearest of the first visit's, its
		# largest channel step in 0-255, the worst and the middle one)
		var far: Array[float] = []
		for c: Vector3 in fresh.pal:
			var best := INF
			for c0: Vector3 in first.pal:
				var dv := (c - c0).abs()
				best = minf(best, maxf(dv.x, maxf(dv.y, dv.z)) * 255.0)
			far.append(best)
		far.sort()
		var worst: float = far[far.size() - 1] if not far.is_empty() else 0.0
		var mid: float = far[floori(far.size() * 0.5)] if not far.is_empty() else 0.0
		print("  mapperftest:   system %d%s: first visit %.0f ms to its palette, back again %.0f ms (cached), recut %.0f ms; the recut against the first: %d of %d colours moved (%d against %d), the nearest first-visit colour at most %.1f of 255 away (middle %.1f)" % [
			n.index, " (in a cloud)" if n.in_nebula else "", first.ms, again.ms, fresh.ms, moved, first.pal.size(), fresh.pal.size(), first.pal.size(), worst, mid])


## One visit, as the game makes it: the system shown at its clock's zero, run
## until its palette is set. Its palette and how long that took.
func _visit(scr: Control, n: MapGen.MapNode) -> Dictionary:
	Run.at = n.index
	OptionTable.ensure(n)
	var t0 := Time.get_ticks_usec()
	await scr.show_system(n, 0.0, false)
	var mat: ShaderMaterial = scr.view._palette_mat
	var waited := 0
	while int(mat.get_shader_parameter("pal_n")) == 0 and waited < 600:
		await get_tree().process_frame
		waited += 1
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0
	var pal := PackedVector3Array(mat.get_shader_parameter("pal"))
	pal.resize(int(mat.get_shader_parameter("pal_n")))
	for _i in 10:
		await get_tree().process_frame
	return {"pal": pal, "ms": ms}
