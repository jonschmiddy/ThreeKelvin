extends Node

## Every galaxy kind as data, for mocking up a new rendering of the star chart:
##   godot --path . -- sheet=GalaxyDump out=<dir> [kinds=0,3,8]
##   godot --path . -- sheet=GalaxyDump out=<dir> pulls   (systems at three arm pulls)
##
## For seed 4242 and each kind GalaxyGen can roll (forced the way ChartShot's
## `kind=N` does it: roll the kind, regenerate the map), writes
##   <dir>/kind_NN.json  the rolled parameters, the chart's own star field
##                       (`_star_pos`/`_star_col`/`_star_big`, in galaxy units
##                       where 1.0 is the disc radius, the space MapNode.gal
##                       speaks), the turning core's particles, the clouds, the
##                       systems with their colours and whether the chart shows
##                       them, the ship and its two rings;
##   <dir>/kind_NN_full.png  the chart's rect at the default view (zoom 0.42,
##                       pan zero), systems drawn;
##   <dir>/kind_NN_sky.png   the same with the systems hidden;
##   <dir>/kind_NN_core_max.png  the core at the chart's closest zoom (6.0),
##                       systems hidden.
## Needs a window; input is switched off while it runs.

var out := "user://galaxydump"
var only: Array = []
var lean := false
var _chart: Control = null


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var s := a as String
		if s.begins_with("out="):
			out = s.substr(4)
		elif s.begins_with("kinds="):
			for k in s.substr(6).split(","):
				only.append(int(k))
		# SPREAD's dials, for either mode: `floor=` `gap=` `width=`
		elif s.begins_with("floor="):
			MapGen.arm_floor = float(s.substr(6))
		elif s.begins_with("gap="):
			MapGen.spread_gap = float(s.substr(4))
		elif s.begins_with("width="):
			MapGen.arm_width = float(s.substr(6))
	DirAccess.make_dir_recursive_absolute(out)
	get_viewport().gui_disable_input = true
	if "pulls" in OS.get_cmdline_user_args():
		_pulls.call_deferred()
		return
	if "spread" in OS.get_cmdline_user_args():
		_spread.call_deferred()
		return
	if "nebulae" in OS.get_cmdline_user_args():
		_nebulae.call_deferred()
		return
	# `placement=pull|spread` lays the systems out that way (`MapGen.placement`),
	# `clouds=ridge|fit` places the clouds that way (`NebulaField.placement`),
	# `allsys` draws every system rather than the charted ones, and `lean` takes
	# only kind_NN_full.png -- the before | after pictures for a placement.
	for a in OS.get_cmdline_user_args():
		var s2 := a as String
		if s2 == "placement=pull":
			MapGen.placement = MapGen.Placement.PULL
		elif s2 == "placement=spread":
			MapGen.placement = MapGen.Placement.SPREAD
		elif s2 == "clouds=ridge":
			NebulaField.placement = NebulaField.Placement.RIDGE
		elif s2 == "clouds=fit":
			NebulaField.placement = NebulaField.Placement.FIT
		elif s2 == "allsys":
			StarchartScreen._show_all = true
		elif s2 == "lean":
			lean = true
	_run.call_deferred()


## `pulls`: every system of every kind (seed 4242) at three strengths of the
## arm pull (`MapGen.arm_pull` / `arm_pull_cap`), and for each strength the
## flyability `-- maptest` measures (its rule, 120 pinned seeds), plus the
## widest angular gap in ring 8 of every spiral (the measure in `galaxy_pos`). Writes <dir>/pulls.json. Puts the hook back after.
const PULLS := [["before", 0.75, 2.0], ["today", 0.9, 3.0], ["strongest", 1.0, 4.5]]

func _pulls() -> void:
	# process_frame, not frame_post_draw: this mode runs headless, where nothing draws
	await get_tree().process_frame
	var mt = load("res://scripts/sim/MapTest.gd").new()
	var rolls := 120
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with("rolls="):
			rolls = int((a as String).substr(6))
	var result := {}
	var was_pull := MapGen.arm_pull
	var was_cap := MapGen.arm_pull_cap
	for setting in PULLS:
		MapGen.arm_pull = setting[1]
		MapGen.arm_pull_cap = setting[2]
		var kinds: Array = []
		for kind in GalaxyGen.count():
			Rng.forced = 4242
			Run.start_new_run(&"korvan", 1)
			if Run.galaxy_kind != kind:
				Run.galaxy_kind = kind
				Run.galaxy = GalaxyGen.roll(kind)
				Run.map = MapGen.generate(Run.MAP_CANVAS)
				Run.at = 0
			var sys: Array = []
			for n in Run.map:
				var node: MapGen.MapNode = n
				sys.append([_r4(node.gal.x), _r4(node.gal.y), MapGen.NodeType.keys()[node.type],
					_hex(MapGen.star_colour(node)), node.layer])
			kinds.append({"kind": kind, "name": GalaxyGen.type_name(kind), "systems": sys})
		# flyability, as maptest asks it: its rolls, its rule
		# The same 120 galaxies for every setting. maptest's own `Rng.reseed`
		# does not pin them: `start_new_run` rolls a fresh master seed unless
		# `Rng.forced` is set, so its rolls differ run to run.
		var fails := 0
		var fly_total := 0
		var flown := 0
		var fly_worst := 0
		var voids: Array = []
		var gd8: Array = []
		var t0 := Time.get_ticks_msec()
		for i in rolls:
			Rng.forced = 90210 + i
			Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
			var map := Run.map
			var goal: int = mt._goal(map)
			var start: int = mt._start(map)
			var f: int = mt._shortest_by_range(map, start, goal) if goal >= 0 and start >= 0 else -1
			if f < 0:
				fails += 1
			else:
				flown += 1
				fly_total += f
				fly_worst = maxi(fly_worst, f)
			if int(Run.galaxy.arms) > 0:
				var sq := float(Run.galaxy.squash)
				for layer in MapGen.LAYERS - 1:
					var angs: Array = []
					for n in map:
						var nd: MapGen.MapNode = n
						if nd.layer == layer:
							angs.append(atan2(nd.gal.y / sq, nd.gal.x))
					if angs.size() < 4:
						continue
					angs.sort()
					var gap: float = float(angs[0]) + TAU - float(angs[angs.size() - 1])
					for k in range(1, angs.size()):
						gap = maxf(gap, float(angs[k]) - float(angs[k - 1]))
					if layer == 8:
						voids.append(rad_to_deg(gap))
						if Run.galaxy_kind == 0:
							gd8.append(rad_to_deg(gap))
		var vmean := 0.0
		for v in voids:
			vmean += v
		var g8 := 0.0
		for v in gd8:
			g8 += v
		result[setting[0]] = {"pull": setting[1], "cap": setting[2], "kinds": kinds,
			"rolls": rolls, "fails": fails, "flyable_mean": float(fly_total) / maxf(1.0, float(flown)),
			"flyable_worst": fly_worst,
			"widest_void_mean_deg": vmean / maxf(1.0, float(voids.size())),
			"widest_void_max_deg": voids.max() if not voids.is_empty() else 0.0,
			"gd_ring8_void_mean_deg": g8 / maxf(1.0, float(gd8.size())), "gd_rolls": gd8.size()}
		print("GALAXYDUMP pulls %s (%d ms): %d of %d unflyable, flyable %.2f mean, ring-8 void %.0f deg mean / %.0f max (spirals), GD ring 8 %.0f deg (%d rolls)" % [
			setting[0], Time.get_ticks_msec() - t0, fails, rolls, result[setting[0]].flyable_mean, result[setting[0]].widest_void_mean_deg,
			result[setting[0]].widest_void_max_deg, result[setting[0]].gd_ring8_void_mean_deg, gd8.size()])
	MapGen.arm_pull = was_pull
	MapGen.arm_pull_cap = was_cap
	Rng.forced = 0
	var f2 := FileAccess.open(out.path_join("pulls.json"), FileAccess.WRITE)
	f2.store_string(JSON.stringify(result))
	f2.close()
	print("GALAXYDUMP wrote %s" % ProjectSettings.globalize_path(out.path_join("pulls.json")))
	get_tree().quit()


## `nebulae`: where the clouds sit, RIDGE against FIT (`NebulaField.placement`),
## every kind forced onto the pinned seeds (90210 + i, `rolls=`, 120), plus
## maptest's natural 120 (skip with `nonatural`). Per kind and placement: each
## cloud's share inside the arm band (`NebulaField.arm_share`; mean, lowest, and
## how many clouds have under half) -- the cloud put over the core is left out,
## it sits in the bulge on purpose -- pulsars per galaxy, and unflyable / mean
## jumps (maptest's rule). Writes <dir>/nebulae.json. Runs headless.
func _nebulae() -> void:
	await get_tree().process_frame
	var mt = load("res://scripts/sim/MapTest.gd").new()
	var rolls := 120
	var natural := true
	for a in OS.get_cmdline_user_args():
		var s := a as String
		if s.begins_with("rolls="):
			rolls = int(s.substr(6))
		elif s == "nonatural":
			natural = false
	var was: int = NebulaField.placement
	var result := {}
	for setting in [["before", NebulaField.Placement.RIDGE], ["after", NebulaField.Placement.FIT]]:
		NebulaField.placement = setting[1]
		var nat_fail := 0
		var nat_total := 0
		var nat_flown := 0
		for i in (rolls if natural else 0):
			Rng.forced = 90210 + i
			Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
			var f: int = _fly(mt)
			if f < 0:
				nat_fail += 1
			else:
				nat_flown += 1
				nat_total += f
		var kinds: Array = []
		for kind in GalaxyGen.count():
			if not only.is_empty() and not only.has(kind):
				continue
			var shares: Array = []
			var pulsars := 0
			var fails := 0
			var fly_total := 0
			var flown := 0
			for i in rolls:
				Rng.forced = 90210 + i
				Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
				if Run.galaxy_kind != kind:
					Run.galaxy_kind = kind
					Run.galaxy = GalaxyGen.roll(kind)
					Run.map = MapGen.generate(Run.MAP_CANVAS)
					Run.at = 0
					Run.trail = PackedInt32Array([0])
					Run._range_cache.clear()
				var f: int = _fly(mt)
				if f < 0:
					fails += 1
				else:
					flown += 1
					fly_total += f
				for n in Run.map:
					if (n as MapGen.MapNode).type == MapGen.NodeType.PULSAR:
						pulsars += 1
				var cl := NebulaField.clouds()
				for c in cl.size():
					if c != 1:
						shares.append(NebulaField.arm_share(cl[c]))
			shares.sort()
			var mean := 0.0
			var under := 0
			for v in shares:
				mean += float(v)
				if float(v) < 0.5:
					under += 1
			var row := {"kind": kind, "name": GalaxyGen.type_name(kind),
				"arms": int(GalaxyGen.params(kind).arms), "clouds": shares.size(),
				"share_mean": mean / maxf(1.0, float(shares.size())),
				"share_min": shares[0] if not shares.is_empty() else 0.0,
				"under_half": under, "pulsars": float(pulsars) / float(rolls),
				"fails": fails, "fly_mean": float(fly_total) / maxf(1.0, float(flown))}
			kinds.append(row)
			print("NEBULAE %s k%02d %-22s clouds %d | in arm %.0f%% mean, %.0f%% lowest, %d under half | pulsars %.2f a galaxy | fail %d fly %.2f" % [
				setting[0], kind, row.name, row.clouds, row.share_mean * 100.0, row.share_min * 100.0,
				under, row.pulsars, fails, row.fly_mean])
		result[setting[0]] = {"natural_fails": nat_fail,
			"natural_fly_mean": float(nat_total) / maxf(1.0, float(nat_flown)), "kinds": kinds}
		if natural:
			print("NEBULAE %s natural: %d of %d unflyable, %.2f jumps mean" % [
				setting[0], nat_fail, rolls, result[setting[0]].natural_fly_mean])
	NebulaField.placement = was
	Rng.forced = 0
	var f2 := FileAccess.open(out.path_join("nebulae.json"), FileAccess.WRITE)
	f2.store_string(JSON.stringify(result))
	f2.close()
	print("GALAXYDUMP wrote %s" % ProjectSettings.globalize_path(out.path_join("nebulae.json")))
	get_tree().quit()


## `spread`: the arm pull (PULL, 0.9 / 3.0) against SPREAD (`MapGen.placement`),
## every kind forced onto the same pinned seeds (90210 + i, `rolls=`, 120), plus
## maptest's own natural 120. Per kind and placement: unflyable count and mean
## jumps to the core (maptest's rule), each system's nearest neighbour on the
## chart in ring gaps (min, 5th percentile, median, share under 0.3 -- the
## piles), the share of systems on an arm against the share of the ring that is
## arm, and the largest hole in the arms (the farthest a point within an arm's
## half-width of its ridge sits from any system, in ring gaps). `floor=` / `gap=` / `width=` set SPREAD's `arm_floor` /
## `spread_gap` / `arm_width` (here and for the pictures), and
## `only=after` skips the PULL pass, `nonatural` maptest's natural 120. Writes <dir>/spread.json. Runs headless.
func _spread() -> void:
	await get_tree().process_frame
	var mt = load("res://scripts/sim/MapTest.gd").new()
	var rolls := 120
	var settings: Array = [["before", MapGen.Placement.PULL], ["after", MapGen.Placement.SPREAD]]
	var natural := true
	for a in OS.get_cmdline_user_args():
		var s := a as String
		if s.begins_with("rolls="):
			rolls = int(s.substr(6))
		elif s == "only=after":
			settings = [["after", MapGen.Placement.SPREAD]]
		elif s == "nonatural":
			natural = false
	var was: int = MapGen.placement
	var result := {}
	for setting in settings:
		MapGen.placement = setting[1]
		var t0 := Time.get_ticks_msec()
		# maptest's own question: the natural galaxies of the pinned seeds
		var nat_fail := 0
		var nat_total := 0
		var nat_flown := 0
		for i in (rolls if natural else 0):
			Rng.forced = 90210 + i
			Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
			var f: int = _fly(mt)
			if f < 0:
				nat_fail += 1
			else:
				nat_flown += 1
				nat_total += f
		var kinds: Array = []
		for kind in GalaxyGen.count():
			if not only.is_empty() and not only.has(kind):
				continue
			var fails := 0
			var fly_total := 0
			var flown := 0
			var nn: Array = []
			var on_arm := 0
			var placed := 0
			var area := 0.0
			var voids: Array = []
			var per_ring_ms := 0
			var crowd: Array = []
			crowd.resize(MapGen.LAYERS)
			crowd.fill(0)
			for i in rolls:
				Rng.forced = 90210 + i
				Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
				if Run.galaxy_kind != kind:
					Run.galaxy_kind = kind
					Run.galaxy = GalaxyGen.roll(kind)
					var tg := Time.get_ticks_msec()
					Run.map = MapGen.generate(Run.MAP_CANVAS)
					per_ring_ms += Time.get_ticks_msec() - tg
					Run.at = 0
					Run.trail = PackedInt32Array([0])
					Run._range_cache.clear()
				var f: int = _fly(mt)
				if f < 0:
					fails += 1
				else:
					flown += 1
					fly_total += f
				var m := _measure(Run.map)
				nn.append_array(m.nn)
				on_arm += int(m.on_arm)
				placed += int(m.placed)
				area += float(m.area)
				if float(m.void) >= 0.0:
					voids.append(float(m.void))
				for l in MapGen.LAYERS:
					crowd[l] += int(m.crowd[l])
			nn.sort()
			var under := 0
			for v in nn:
				if float(v) < 0.3:
					under += 1
			var vmean := 0.0
			for v in voids:
				vmean += float(v)
			var row := {"kind": kind, "name": GalaxyGen.type_name(kind),
				"arms": int(GalaxyGen.params(kind).arms),
				"fails": fails, "fly_mean": float(fly_total) / maxf(1.0, float(flown)),
				"nn_min": nn[0], "nn_p5": nn[int(nn.size() * 0.05)], "nn_p50": nn[int(nn.size() * 0.5)],
				"nn_under_03": float(under) / float(nn.size()),
				"on_arm": float(on_arm) / maxf(1.0, float(placed)),
				"arm_area": area / maxf(1.0, float(placed)),
				"void_mean": vmean / maxf(1.0, float(voids.size())),
				"void_max": voids.max() if not voids.is_empty() else 0.0,
				"gen_ms": float(per_ring_ms) / float(rolls), "crowd_by_ring": crowd}
			kinds.append(row)
			print("SPREAD %s k%02d %-22s fail %d fly %.2f | nn min %.2f p5 %.2f p50 %.2f <0.3 %.1f%% | arm %.0f%% of systems on %.0f%% of ring | arm hole %.2f mean %.2f max | gen %.0f ms | under 0.45 by ring %s" % [
				setting[0], kind, row.name, fails, row.fly_mean, row.nn_min, row.nn_p5, row.nn_p50,
				row.nn_under_03 * 100.0, row.on_arm * 100.0, row.arm_area * 100.0,
				row.void_mean, row.void_max, row.gen_ms, str(crowd)])
		result[setting[0]] = {"natural_fails": nat_fail,
			"natural_fly_mean": float(nat_total) / maxf(1.0, float(nat_flown)),
			"kinds": kinds, "rolls": rolls,
			"arm_floor": MapGen.arm_floor, "spread_gap": MapGen.spread_gap,
			"arm_width": MapGen.arm_width}
		print("SPREAD %s natural: %d of %d unflyable, %.2f jumps mean (%d ms)" % [
			setting[0], nat_fail, rolls, result[setting[0]].natural_fly_mean, Time.get_ticks_msec() - t0])
	MapGen.placement = was
	Rng.forced = 0
	var f2 := FileAccess.open(out.path_join("spread.json"), FileAccess.WRITE)
	f2.store_string(JSON.stringify(result))
	f2.close()
	print("GALAXYDUMP wrote %s" % ProjectSettings.globalize_path(out.path_join("spread.json")))
	get_tree().quit()


## Hops to the core under maptest's rule, -1 if there is no route.
func _fly(mt) -> int:
	var goal: int = mt._goal(Run.map)
	var start: int = mt._start(Run.map)
	if goal < 0 or start < 0:
		return -1
	return mt._shortest_by_range(Run.map, start, goal)


## One map's spread: nearest neighbours on the chart in ring gaps, systems on an
## arm, the ring share that is arm, and the longest empty stretch of arm ridge.
func _measure(map: Array) -> Dictionary:
	var g := Run.galaxy
	var reach := float(g.get("reach", 1.0))
	var sq := float(g.squash)
	var unit := MapGen.RING_GAP * reach
	var pts: Array[Vector2] = []
	var nodes: Array = []
	for n in map:
		var nd: MapGen.MapNode = n
		if nd.type == MapGen.NodeType.CORE:
			continue
		pts.append(nd.gal)
		nodes.append(nd)
	var nn: Array = []
	for i in pts.size():
		var best := INF
		for j in pts.size():
			if j != i:
				best = minf(best, pts[i].distance_squared_to(pts[j]))
		nn.append(sqrt(best) / unit)
	var arms := int(g.arms)
	var on_arm := 0
	var area := 0.0
	var void_len := -1.0
	if arms > 0:
		for nd in nodes:
			var node: MapGen.MapNode = nd
			var rn := MapGen.ring_radius(node.layer)
			var hw := _arm_hw(rn)
			var a := atan2(node.gal.y / sq, node.gal.x)
			var dmin := TAU
			for arm in arms:
				dmin = minf(dmin, absf(wrapf(MapGen.shape_angle(rn, arm, 0.0) - a, -PI, PI)))
			if dmin <= hw:
				on_arm += 1
			# the share of this ring within hw of a ridge, sampled
			var hit := 0
			for s in 180:
				var th := float(s) * TAU / 180.0
				var dd := TAU
				for arm in arms:
					dd = minf(dd, absf(wrapf(MapGen.shape_angle(rn, arm, 0.0) - th, -PI, PI)))
				if dd <= hw:
					hit += 1
			area += float(hit) / 180.0
		# THE LARGEST HOLE IN THE ARMS: points across every arm's band (within
		# its half-width of the ridge), on every ring and halfway between rings,
		# and the farthest any of them is from a system, in ring gaps. A pile
		# leaves a hole beside it; an even spread along the arm does not.
		void_len = 0.0
		var cell := 0.06 * reach
		var grid: Dictionary = {}
		for q in pts:
			var key := Vector2i(floori(q.x / cell), floori(q.y / cell))
			if not grid.has(key):
				grid[key] = []
			(grid[key] as Array).append(q)
		for half in (MapGen.LAYERS - 2) * 2 + 1:
			var l0 := half / 2
			var rn := MapGen.ring_radius(l0)
			if half % 2 == 1:
				rn = (rn + MapGen.ring_radius(l0 + 1)) * 0.5
			if rn < maxf(0.2, float(g.bar)):
				continue
			var hw := _arm_hw(rn)
			var steps := int(TAU * rn / 0.01)
			for s in steps:
				var th := float(s) * TAU / float(steps)
				var dd := TAU
				for arm in arms:
					dd = minf(dd, absf(wrapf(MapGen.shape_angle(rn, arm, 0.0) - th, -PI, PI)))
				if dd > hw:
					continue
				var p := Vector2(cos(th), sin(th) * sq) * rn * reach
				void_len = maxf(void_len, _nearest(grid, cell, p) / unit)
	var crowd: Array = []
	crowd.resize(MapGen.LAYERS)
	crowd.fill(0)
	for i in nodes.size():
		if float(nn[i]) < 0.45:
			crowd[(nodes[i] as MapGen.MapNode).layer] += 1
	return {"nn": nn, "on_arm": on_arm, "placed": nodes.size(), "area": area, "void": void_len, "crowd": crowd}


## The distance from `p` to the nearest point in `grid` (cells of `cell`).
func _nearest(grid: Dictionary, cell: float, p: Vector2) -> float:
	var c := Vector2i(floori(p.x / cell), floori(p.y / cell))
	var best := INF
	for ring in 8:
		for dx in range(-ring, ring + 1):
			for dy in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dy)) != ring:
					continue
				var bucket: Variant = grid.get(c + Vector2i(dx, dy))
				if bucket == null:
					continue
				for q in bucket:
					best = minf(best, p.distance_to(q))
		if best <= float(ring) * cell:
			return best
	return best


## The half-width of an arm's core at `rn`, as `MapGen._arm_cdf` reads it.
func _arm_hw(rn: float) -> float:
	var g := Run.galaxy
	var hw := 0.5 * (0.55 + 0.9 * rn) * float(g.spread)
	if float(g.bar) > 0.0 and rn < float(g.bar):
		hw *= 0.22
	return hw


func _run() -> void:
	await _frames(5)
	StarchartScreen.MapChart.clock_override = 123.456
	for kind in GalaxyGen.count():
		if not only.is_empty() and not only.has(kind):
			continue
		Rng.forced = 4242
		Run.start_new_run(&"korvan", 1)
		var natural: int = Run.galaxy_kind
		if Run.galaxy_kind != kind:
			Run.galaxy_kind = kind
			Run.galaxy = GalaxyGen.roll(kind)
			Run.map = MapGen.generate(Run.MAP_CANVAS)
			Run.at = 0
			Run.trail = PackedInt32Array([0])
			Run._range_cache.clear()
			Run.chart_from(Run.node_at())
		Router.show_starchart()
		await _frames(60)
		var scp := Router.current as StarchartScreen
		scp.dismiss_primer()
		_chart = scp._chart
		_chart.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_chart._go_to(StarchartScreen.MapChart.ZOOM_MIN, Vector2.ZERO, false)
		_chart.show_icons = true
		_chart.queue_redraw()
		var tag := "kind_%02d" % kind
		await _shot(tag + "_full")
		if lean:
			print("GALAXYDUMP %s %s" % [tag, GalaxyGen.type_name(kind)])
			continue
		_chart.show_icons = false
		_chart.queue_redraw()
		await _shot(tag + "_sky")
		# The core at the chart's closest zoom, systems hidden: the black hole
		# as the game draws it now, to set beside a remade one.
		_chart._go_to(StarchartScreen.MapChart.ZOOM_MAX, Vector2.ZERO, false)
		await _shot(tag + "_core_max")
		_chart._go_to(StarchartScreen.MapChart.ZOOM_MIN, Vector2.ZERO, false)
		_chart.show_icons = true
		_chart.queue_redraw()
		var d := _dump(kind, natural)
		var f := FileAccess.open(out.path_join(tag + ".json"), FileAccess.WRITE)
		f.store_string(JSON.stringify(d))
		f.close()
		print("GALAXYDUMP %s %s: %d stars, %d core, %d systems" % [tag,
			GalaxyGen.type_name(kind), (d.stars.x as Array).size(),
			(d.core.r as Array).size(), (d.systems as Array).size()])
	print("GALAXYDUMP wrote %s" % ProjectSettings.globalize_path(out))
	get_tree().quit()


func _r4(v: float) -> float:
	return snappedf(v, 0.0001)


func _hex(c: Color) -> String:
	return c.to_html(false)


func _dump(kind: int, natural: int) -> Dictionary:
	var ch = _chart
	var r_max: float = ch._radius() * StarchartScreen.MapChart.DISC
	var g: Dictionary = {}
	for k in Run.galaxy:
		g[k] = Run.galaxy[k]
	# The star field, as the backdrop layer draws it, with colours as indices
	# into a table so 80k stars stay a few megabytes.
	var table: Array = []
	var index: Dictionary = {}
	var xs: Array = []
	var ys: Array = []
	var cs: Array = []
	var bs: Array = []
	var pos: PackedVector2Array = ch._star_pos
	var col: PackedColorArray = ch._star_col
	var big: PackedByteArray = ch._star_big
	for i in pos.size():
		var h := _hex(col[i])
		if not index.has(h):
			index[h] = table.size()
			table.append(h)
		xs.append(_r4(pos[i].x / r_max))
		ys.append(_r4(pos[i].y / r_max))
		cs.append(index[h])
		bs.append(int(big[i]))
	# The turning core: radius and angle in drawn space, at the moment of
	# building (the live layer turns them by `_orbital_omega`).
	var cr: Array = []
	var ca: Array = []
	var cc: Array = []
	var cz: Array = []
	var crad: PackedFloat32Array = ch._core_rad
	var cang: PackedFloat32Array = ch._core_ang
	var ccol: PackedColorArray = ch._core_col
	var csz: PackedByteArray = ch._core_size
	for i in crad.size():
		var h2 := _hex(ccol[i])
		if not index.has(h2):
			index[h2] = table.size()
			table.append(h2)
		cr.append(_r4(crad[i] / r_max))
		ca.append(_r4(cang[i]))
		cc.append(index[h2])
		cz.append(int(csz[i]))
	var clouds: Array = []
	for raw in NebulaField.clouds():
		var cl: NebulaField.Cloud = raw
		var lobes: Array = []
		for l in cl.lobes.size():
			lobes.append([_r4(cl.lobes[l].x), _r4(cl.lobes[l].y), _r4(cl.lobe_r[l])])
		clouds.append({
			"name": cl.name, "kind": NebulaField.Kind.keys()[cl.kind],
			"x": _r4(cl.pos.x), "y": _r4(cl.pos.y), "radius": _r4(cl.radius),
			"hollow": cl.hollow, "emission": cl.emission,
			"shape": NebulaField.Shape.keys()[cl.shape],
			"base": _hex(cl.base_colour()), "edge": _hex(cl.edge_colour()),
			"tint": _hex(ch._region_tint(cl.pos * r_max)),
			"lobes": lobes,
		})
	var here: MapGen.MapNode = Run.node_at()
	var reach: Dictionary = {}
	for cand in Run.in_range():
		if Run.charted(cand):
			reach[(cand as MapGen.MapNode).index] = true
	var shown: Dictionary = ch._visible_set(here, reach.keys())
	var systems: Array = []
	for n in Run.map:
		var node: MapGen.MapNode = n
		systems.append({
			"i": node.index, "x": _r4(node.gal.x), "y": _r4(node.gal.y),
			"layer": node.layer, "type": MapGen.NodeType.keys()[node.type],
			"col": _hex(MapGen.star_colour(node)),
			"shown": shown.has(node.index), "sensed": node.sensed,
			"cleared": node.cleared, "reach": reach.has(node.index),
			"afford": Run.can_jump_to(node) if reach.has(node.index) else false,
		})
	var pulsars: Array = []
	for p in ch._pulsar:
		pulsars.append([_r4((p as Vector2).x / r_max), _r4((p as Vector2).y / r_max)])
	return {
		"kind": kind, "name": GalaxyGen.type_name(kind),
		"natural_kind": natural, "seed": Run.galaxy_seed,
		"spin": Run.galaxy_spin, "galaxy_name": Run.galaxy_name,
		"galaxy_title": Run.galaxy_title, "params": g,
		"chart": {"w": ch.size.x, "h": ch.size.y, "radius": ch._radius(),
			"r_max": r_max, "zoom": ch.zoom, "pan": [ch.pan.x, ch.pan.y],
			"shadow": _r4(ch._shadow_r() / r_max),
			"core_clear": _r4(ch._core_clear() / r_max),
			"bulge": _r4(ch._radius() * float(g.bulge) / r_max)},
		"colours": table,
		"stars": {"x": xs, "y": ys, "c": cs, "big": bs},
		"core": {"r": cr, "a": ca, "c": cc, "size": cz},
		"clouds": clouds, "pulsars": pulsars,
		"systems": systems, "here": here.index,
		"trail": Array(Run.trail),
		"sense_radius": Run.sense_radius(), "jump_range": Run.jump_range(),
	}


func _frames(n: int) -> void:
	for i in n:
		await RenderingServer.frame_post_draw


func _shot(name: String) -> void:
	await _frames(6)
	var img := _chart.get_viewport().get_texture().get_image()
	var at := _chart.get_global_transform_with_canvas().origin
	img = img.get_region(Rect2i(Vector2i(at.round()), Vector2i(_chart.size.round())))
	img.save_png(out.path_join(name + ".png"))
