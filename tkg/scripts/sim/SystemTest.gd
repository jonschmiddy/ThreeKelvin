extends Harness

## A gate: `SystemLayout` is derived and never saved, so every layout fault is silent.
## Why: docs/why/SystemTest.md#system-test-promises

const SEEDS := [4242, 7, 1999, 31337]
const STAR_B := SystemLayout.STAR_B


func _print_of(L: SystemLayout) -> String:
	var parts: Array[String] = ["%d" % L.star]
	# (two suns: the pair, its rings and where each body circles)
	if L.twin:
		parts.append("twin:%d:%.5f:%.3f:%.3f,%.3f:%.3f:%.3f,%.3f" % [int(L.close), L.star_share, L.sep, L.star2_at0.x,
			L.star2_at0.y, L.star2_r, L.bary.x, L.bary.y])
		# (and its turn: rate, angle at t 0, star A's distance from the balance point)
		parts.append("pair:%.9f:%.6f:%.3f" % [L.pair_n, L.pair_ph, L.pair_ra])
		for p in L.stars():
			parts.append("ring%d:%.3f:%.3f:%.3f" % [p, L.keep_clear_of(p), L.star_rail_of(p), L.star_ring_of(p)])
	for b in L.bodies:
		var opts: Array[String] = []
		for bc in b.beacons:
			opts.append("%d%s%s" % [bc.opt, "d" if bc.dock else "", "c" if bc.core else ""])
		parts.append("%s:%s:%.3f:%.3f:%.3f:%s:%.3f[%s]:%d:%.3f,%.3f:%.5f:%d:%.3f" % [b.kind, b.world, b.orbit,
			b.period, b.phase, b.name, b.r, ",".join(opts), b.host_id, b.host0.x, b.host0.y, b.gm_frac, b.zone, b.soi])
	var on_star: Array[String] = []
	for bc in L.star_beacons:
		on_star.append("%d" % bc.opt)
	parts.append("star[%s]" % ",".join(on_star))
	parts.append("edge:%.3f:%.5f" % [L.edge, L.fit_zoom])
	return "|".join(parts)


## What the two-sun checks measured, across every twin they saw, and how many
## pairs had to be moved apart past their rolled separation for their worlds.
var _st := {}
var _seen := 0
var _spread_out := 0


func _least(k: String, v: float, at: String) -> void:
	if not _st.has(k) or v < float(_st[k][0]):
		_st[k] = [v, at]


func _most(k: String, v: float, at: String) -> void:
	if not _st.has(k) or v > float(_st[k][0]):
		_st[k] = [v, at]


func run() -> void:
	var prints := {}
	var n_sys := 0
	var worlds := {}
	var min_gap := INF
	var min_gap_at := ""
	var counts := {}
	var eligible := 0
	var twins := 0
	var closes := 0
	var zooms_one: Array[float] = []
	var zooms_two: Array[float] = []
	var st_systems := 0
	for s in SEEDS:
		Rng.forced = s
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
		for raw in Run.map:
			var n: MapGen.MapNode = raw
			var before := JSON.stringify(Rng.state())
			var L := SystemLayout.of(n)
			var L2 := SystemLayout.of(n)
			if JSON.stringify(Rng.state()) != before:
				_fail("laying out system %d moved a shared stream" % n.index)
			var fp := _print_of(L)
			if fp != _print_of(L2):
				_fail("system %d laid out two ways in one run" % n.index)
			prints["%d:%d" % [s, n.index]] = fp
			n_sys += 1
			# every option on exactly one body
			var seen := {}
			for b in L.bodies:
				for bc in b.beacons:
					if bc.opt >= 0:
						seen[bc.opt] = int(seen.get(bc.opt, 0)) + 1
			# (or on the star itself: an event sited there, `OptionTable` `site`)
			for bc in L.star_beacons:
				seen[bc.opt] = int(seen.get(bc.opt, 0)) + 1
				if L.star != SystemLayout.StarKind.RED and L.star != SystemLayout.StarKind.BLUE:
					_fail("system %d: option %d on a star that is not red or blue" % [n.index, bc.opt])
			for i in n.options.size():
				if int(seen.get(i, 0)) != 1:
					_fail("system %d: option %d is on %d bodies" % [n.index, i, int(seen.get(i, 0))])
			# one event to a world
			for b in L.bodies:
				if b.kind == &"planet" or b.kind == &"giant":
					var on := b.beacons.filter(func(bc): return bc.opt >= 0).size()
					if on > 1:
						_fail("system %d: %s %s holds %d events" % [n.index, b.kind, b.name, on])
			if L.star_beacons.size() > 1:
				_fail("system %d: the star holds %d events" % [n.index, L.star_beacons.size()])
			for k in seen.keys():
				if int(k) >= n.options.size():
					_fail("system %d: a beacon for option %d, which it does not have" % [n.index, int(k)])
			if n.type == MapGen.NodeType.STATION and not L.bodies.any(func(b): return b.beacons.any(func(bc): return bc.dock)):
				_fail("station %d has no DOCK" % n.index)
			# One station to a station system (Jon, Nov 3), after `_place_stations` thins them.
			# Why: docs/why/SystemTest.md#stations
			var st_bodies := L.bodies.filter(func(b): return b.kind == &"station").size()
			if st_bodies != (1 if n.type == MapGen.NodeType.STATION else 0):
				_fail("system %d (%s) holds %d stations" % [n.index, MapGen.type_label(n.type), st_bodies])
			elif n.type == MapGen.NodeType.STATION:
				st_systems += 1
			if n.type == MapGen.NodeType.CORE and not L.bodies.any(func(b): return b.beacons.any(func(bc): return bc.core)):
				_fail("the core has no custodian")
			# a gas giant if and only if the node has one
			var giants := L.bodies.filter(func(b): return b.kind == &"giant").size()
			var want_giant := n.gas_giant and n.type != MapGen.NodeType.PULSAR
			if giants != (1 if want_giant else 0):
				_fail("system %d: %d giants, gas_giant=%s" % [n.index, giants, str(n.gas_giant)])
			_weights(n, L)
			if L.bodies.is_empty():
				_fail("system %d has no bodies" % n.index)
			counts[L.bodies.size()] = int(counts.get(L.bodies.size(), 0)) + 1
			# the edge past everything, from the plane's origin (star A at t 0),
			# whatever each body circles, at every angle of a turning pair
			for b in L.bodies:
				for q in TURN_STEPS:
					var tq := _turn_t(L, q)
					if L.edge < b.host_at(tq).length() + b.orbit + SystemLayout.reach_of(b):
						_fail("system %d: %s %s reaches past the edge at %d/%d of the pair's lap" % [n.index, b.kind, b.name, q, TURN_STEPS])
						break
			# two suns only where they may be, and always where the node has them
			if MapGen.twin_ok(n):
				eligible += 1
				if n.twin:
					twins += 1
					closes += int(L.close)
			elif n.twin:
				_fail("system %d has two suns and may not (type %d, star %d)" % [n.index, n.type, n.star])
			if L.twin != n.twin:
				_fail("system %d: twin %s, laid out twin %s" % [n.index, str(n.twin), str(L.twin)])
			_turn(n, L, "seed %d system %d" % [s, n.index])
			if L.twin:
				_twin_checks(n, L, "seed %d system %d" % [s, n.index])
				_comers(n, "seed %d system %d" % [s, n.index])
				zooms_two.append(SystemLayout.open_zoom(L.edge))
			else:
				zooms_one.append(SystemLayout.open_zoom(L.edge))
				# ONE SUN: everything round star A, as it always was
				if L.sep != 0.0 or L.star_share != 1.0 or not L.bodies.all(func(b): return b.host_id == -1 and b.host0 == Vector2.ZERO):
					_fail("system %d has one sun and something circles elsewhere" % n.index)
				# orbits clear of each other's bodies (a giant's rings reach twice its
				# radius), in index order, which round one sun is the order out
				for i in range(1, L.bodies.size()):
					var a := L.bodies[i - 1]
					var b := L.bodies[i]
					var reach := SystemLayout.reach_of(a) + SystemLayout.reach_of(b)
					var gap := b.orbit - a.orbit - reach
					if gap < min_gap:
						min_gap = gap
						min_gap_at = "system %d, bodies %d and %d" % [n.index, i - 1, i]
					if gap <= 0.0:
						_fail("system %d: orbits %d and %d cross their bodies (gap %.1f)" % [n.index, i - 1, i, gap])
			for b in L.bodies:
				if b.world != &"":
					worlds[b.world] = int(worlds.get(b.world, 0)) + 1
	_ok("%d systems laid out, every option on one body, one event to a world" % n_sys, true)
	_ok("one station body in each of the %d station systems, none anywhere else" % st_systems, st_systems > 0)
	var share := float(twins) / float(maxi(eligible, 1))
	_ok("two suns at %d of %d systems that may have them (%.0f%%; about one in four)" % [twins, eligible, share * 100.0],
		twins > 0 and share > 0.12 and share < 0.40)
	var cshare := float(closes) / float(maxi(twins, 1))
	_ok("close pairs at %d of those %d binaries (%.0f%%; about one in three), the rest wide" % [closes, twins, cshare * 100.0],
		closes > 0 and cshare > 0.22 and cshare < 0.45)
	_hellbender("")
	var cl: Array[String] = []
	for k in range(1, 12):
		if counts.has(k):
			cl.append("%d bodies: %d" % [k, counts[k]])
	print("  systems by body count: " + ", ".join(cl))
	print("  narrowest gap between neighbouring bodies round one sun: %.1f px (%s)" % [min_gap, min_gap_at])
	print("  opening zoom, one sun: %s; two suns: %s" % [_spread(zooms_one), _spread(zooms_two)])
	# the same seed, a fresh run, the same layouts
	var drift := 0
	for s in SEEDS:
		Rng.forced = s
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
		for raw in Run.map:
			var n: MapGen.MapNode = raw
			if _print_of(SystemLayout.of(n)) != prints.get("%d:%d" % [s, n.index], ""):
				drift += 1
	_ok("every layout the same in a fresh run of the same seed (%d differ)" % drift, drift == 0)
	_all_twins()
	_report()
	_turn_report()
	_comet_pace()
	var keys := worlds.keys()
	keys.sort_custom(func(a, b): return int(worlds[a]) > int(worlds[b]))
	var line: Array[String] = []
	for k in keys:
		line.append("%s %d" % [k, worlds[k]])
	print("  worlds drawn: " + ", ".join(line))
	verdict("systemtest")


## THE PAIR'S LAP in this many steps (`_turn`): eight angles round it, whatever
## its speed (the review's pair-phase sweep).
const TURN_STEPS := 8
## (what `_turn` measured, across every layout it saw)
var _turn_st := {}


## The map time at which a turning pair has gone q / TURN_STEPS of its lap
## (q / TURN_STEPS of a long minute for one sun or a still pair).
static func _turn_t(L: SystemLayout, q: int) -> float:
	var lap := TAU / L.pair_n if L.pair_n > 0.0 else 600.0
	return lap * float(q) / float(TURN_STEPS)


func _tn(k: String, v: float) -> void:
	var e: Array = _turn_st.get(k, [INF, -INF, 0])
	_turn_st[k] = [minf(float(e[0]), v), maxf(float(e[1]), v), int(e[2]) + 1]


## The pair turns (ruling 23): one sun is still at every t, two turn rigidly at eight angles.
func _turn(n: MapGen.MapNode, L: SystemLayout, at: String) -> void:
	var ts: Array[float] = [0.0, 0.5, 37.25, 400.0, 1234.5]
	if not L.twin:
		var still := L.pair_n == 0.0
		for t in ts:
			still = still and L.star_pos(-1, t) == Vector2.ZERO and L.star_vel(-1, t) == Vector2.ZERO
			for b in L.bodies:
				# (the formula `point3` always was, to the bit)
				var a := b.phase + t / b.period * TAU
				var old := Vector3(b.host0.x + cos(a) * b.orbit, 0.0, b.host0.y + sin(a) * b.orbit)
				still = still and b.point3(t) == old and b.host_at(t) == b.host0 and b.hr == 0.0
		if not still:
			_fail("%s: one sun, and something moved off where it always was" % at)
		_tn("one sun: still at every t", 1.0)
		return
	var k := SystemLayout.pair_speed()
	var kind := "close" if L.close else "wide"
	# THE RATE: Kepler round the pair's whole mass, times the ruling's speed
	var lap := SystemLayout.kepler_s() * pow(L.sep / 100.0, 1.5)
	if k <= 0.0:
		if L.pair_n != 0.0:
			_fail("%s: the pair held still (pair=0) and turns" % at)
	elif absf(L.pair_n - TAU / lap * k) > 1e-9 * L.pair_n:
		_fail("%s: the pair turns at %.6f rad/s, not Kepler x %.0f (%.6f)" % [at, L.pair_n, k, TAU / lap * k])
	if L.pair_n > 0.0:
		_tn("%s pair: a lap, minutes" % kind, TAU / L.pair_n / 60.0)
	# THE REST POSE: at t 0 exactly the layout as laid out
	if L.star_pos(-1, 0.0) != Vector2.ZERO or L.star_pos(STAR_B, 0.0) != L.star2_at0:
		_fail("%s: at t 0 the suns are not where the layout put them" % at)
	for b in L.bodies:
		if b.host_at(0.0) != b.host0:
			_fail("%s: at t 0 %s's centre is not where the layout put it" % [at, b.name])
	var G := MapGravity.from_layout(L)
	var ka := G.star_index(-1)
	var kb := G.star_index(STAR_B)
	var worst_g := 0.0
	var worst_rigid := 0.0
	var worst_v := 0.0
	for q in TURN_STEPS:
		var t := _turn_t(L, q) + 3.0
		var sa := L.star_pos(-1, t)
		var sb := L.star_pos(STAR_B, t)
		# the suns sep apart, either side of the still balance point by their shares
		worst_rigid = maxf(worst_rigid, absf(sa.distance_to(sb) - L.sep))
		worst_rigid = maxf(worst_rigid, absf(sa.distance_to(L.bary) - L.pair_ra))
		worst_rigid = maxf(worst_rigid, absf((sa * L.star_share + sb * (1.0 - L.star_share)).distance_to(L.bary)))
		# each body's centre where its sun is, or still; the world its orbit from it
		for b in L.bodies:
			var want := L.star_pos(b.host_id, t) if SystemLayout.is_star(b.host_id) else b.host0
			worst_rigid = maxf(worst_rigid, b.host_at(t).distance_to(want))
			var p3 := b.point3(t)
			worst_rigid = maxf(worst_rigid, absf(Vector2(p3.x, p3.z).distance_to(b.host_at(t)) - b.orbit))
			# its motion: round its circle and with its centre (`vel`), against a
			# step either side
			var fd := (b.pos(t + 0.01) - b.pos(t - 0.01)) / 0.02
			worst_v = maxf(worst_v, fd.distance_to(b.vel(t)))
		for p in L.stars():
			var fd2 := (L.star_pos(p, t + 0.01) - L.star_pos(p, t - 0.01)) / 0.02
			worst_v = maxf(worst_v, fd2.distance_to(L.star_vel(p, t)))
		# THE PULL'S SUNS where the layout has them, and its carried worlds too
		worst_g = maxf(worst_g, Vector2(G.sx(ka, t), G.sz(ka, t)).distance_to(sa))
		worst_g = maxf(worst_g, Vector2(G.sx(kb, t), G.sz(kb, t)).distance_to(sb))
		worst_g = maxf(worst_g, Vector2(G.svx(kb, t), G.svz(kb, t)).distance_to(L.star_vel(STAR_B, t)))
		for j in G.wo_body.size():
			var b := L.bodies[G.wo_body[j]]
			var aw := G.wo_ph[j] + G.wo_n[j] * t
			var wq := Vector2(G.hx_at(G.wo_hs[j], G.wo_hx[j], t) + G.wo_orb[j] * cos(aw), G.hz_at(G.wo_hs[j], G.wo_hz[j], t) + G.wo_orb[j] * sin(aw))
			worst_g = maxf(worst_g, wq.distance_to(b.pos(t)))
	_tn("%s pair: the turn's worst off rigid (px)" % kind, worst_rigid)
	_tn("%s pair: motion against a step either side (px/s)" % kind, worst_v)
	_tn("%s pair: MapGravity against the layout (px)" % kind, worst_g)
	if worst_rigid > 0.01:
		_fail("%s: the turn is not rigid, %.4f px off" % [at, worst_rigid])
	if worst_v > 0.05:
		_fail("%s: a speed %.4f px/s off its own motion" % [at, worst_v])
	if worst_g > 0.01:
		_fail("%s: MapGravity's suns or worlds %.4f px off the layout's" % [at, worst_g])
	# A WORLD ROUND ONE SUN LAPS IT 5.4 TO 7.6 TIMES A LAP OF THE PAIR (DESIGN,
	# seed 7's wide pairs at Kepler; the same at any speed past it): printed
	if L.pair_n > 0.0:
		for b in L.bodies:
			if SystemLayout.is_star(b.host_id):
				_tn("wide pair: a world's laps of its sun a lap of the pair", (TAU / L.pair_n) / b.period)
	# Reduced motion must not move the pair's angle: it feeds flights, saves and co-op.
	var rm := DisplaySettings.reduced_motion
	var rows: Array = []
	for pass_i in 2:
		DisplaySettings.reduced_motion = pass_i == 1
		var L2 := L if pass_i == 0 else SystemLayout.of(n)
		var row: Array = []
		for t in ts:
			for p in L2.stars():
				row.append(L2.star_pos(p, t))
			for b in L2.bodies:
				row.append(b.point3(t))
		rows.append(row)
	DisplaySettings.reduced_motion = rm
	if rows[0] != rows[1]:
		_fail("%s: a place is not one function of the map's time (or reduced motion moved it)" % at)


## What `_turn` measured.
func _turn_report() -> void:
	var keys := _turn_st.keys()
	keys.sort()
	for k in keys:
		var e: Array = _turn_st[k]
		print("  turn: %s: %.4f to %.4f (%d)" % [k, float(e[0]), float(e[1]), int(e[2])])
	_ok("the pair turns: Kepler x %.0f, rigid at %d angles a lap, MapGravity with it, one sun still" % [SystemLayout.pair_speed(), TURN_STEPS],
		_turn_st.has("one sun: still at every t") and (SystemLayout.pair_speed() <= 0.0 or _turn_st.has("wide pair: a lap, minutes")))
	# Pins the ruled speed itself: a changed or zeroed `PAIR_K` otherwise passed every rate check.
	# Why: docs/why/SystemTest.md#pair-speed
	var asked := false
	var wasked := false
	for a in OS.get_cmdline_user_args():
		asked = asked or (a as String).begins_with("pair=")
		wasked = wasked or (a as String).begins_with("worldpace=")
	var W := SystemLayout.world_pace()
	if not wasked:
		_ok("the worlds' pace is the ruled WORLD_PACE (%.2f)" % W, W == SystemLayout.WORLD_PACE)
	if not asked:
		var wide: Array = _turn_st.get("wide pair: a lap, minutes", [])
		var close: Array = _turn_st.get("close pair: a lap, minutes", [])
		_ok("the ruled speed: PAIR_K 4 (%.2f) at the worlds' pace %.2f, wide pairs lap in %.1f to %.1f min (%s), close pairs in %.1f to %.2f (%s)" % [
			SystemLayout.PAIR_K, W, 19.0 / W, 25.0 / W,
			"none seen" if wide.is_empty() else "%.2f to %.2f" % [float(wide[0]), float(wide[1])],
			6.0 / W, 7.5 / W,
			"none seen" if close.is_empty() else "%.2f to %.2f" % [float(close[0]), float(close[1])]],
			SystemLayout.PAIR_K == 4.0 and SystemLayout.pair_speed() == 4.0
				and not wide.is_empty() and float(wide[0]) >= 19.0 / W - 1e-9 and float(wide[1]) <= 25.0 / W + 1e-9
				and not close.is_empty() and float(close[0]) >= 6.0 / W - 1e-9 and float(close[1]) <= 7.5 / W + 1e-9)


## Least / median / most of a list, for a line.
func _spread(v: Array[float]) -> String:
	if v.is_empty():
		return "none"
	var s := v.duplicate()
	s.sort()
	return "%.3f / %.3f / %.3f (least / median / most of %d)" % [s[0], s[int(s.size() / 2.0)], s[s.size() - 1], s.size()]


## A giant weighs 1/10 to 1/4 of its star (ruling 20); its ring and dent are where they were.
func _weights(n: MapGen.MapNode, L: SystemLayout) -> void:
	for b in L.bodies:
		if b.kind == &"giant":
			if b.gm_frac < SystemLayout.GIANT_MIN or b.gm_frac > SystemLayout.GIANT_MAX:
				_fail("system %d: the giant weighs %.3f of its star" % [n.index, b.gm_frac])
			if not is_equal_approx(b.gm, b.gm_frac * SystemLayout.GM_SHIP):
				_fail("system %d: the giant's pull %.1f is not its weight's" % [n.index, b.gm])
			if b.mass != 24.0 or not is_equal_approx(b.soi, SystemLayout.soi_of(b)):
				_fail("system %d: the giant's weight moved its dent or its ring" % n.index)
			_least("giant weight", b.gm_frac, "system %d" % n.index)
			_most("giant weight, most", b.gm_frac, "system %d" % n.index)
		elif b.gm != 0.0 or b.gm_frac != 0.0:
			_fail("system %d: %s %s pulls" % [n.index, b.kind, b.name])


## How near two bodies on their circles can come, centre to centre, whatever
## their phases: apart, one inside the other, or 0 where the circles cross.
static func _closest(a: SystemLayout.Body, b: SystemLayout.Body) -> float:
	var d := a.host0.distance_to(b.host0)
	if d >= a.orbit + b.orbit:
		return d - a.orbit - b.orbit
	if d <= absf(a.orbit - b.orbit):
		return absf(a.orbit - b.orbit) - d
	return 0.0


## How far round a body its ring reaches (or the body itself, with no ring).
static func _ring(b: SystemLayout.Body) -> float:
	return b.soi if b.soi > 0.0 else SystemLayout.reach_of(b)


## Star p's sun and world w's disc at zoom z at the most SystemView draws them,
## in 2 px blocks (`SystemLayout.held_most`, `SystemView._held`).
static func _sun_held(L: SystemLayout, p: int, z: float) -> float:
	return SystemLayout.held_most(SystemLayout.sun_drawn(L.star_radius(p), z), SystemLayout.SUN_LEAST)


static func _disc_held(w: SystemLayout.Body, z: float) -> float:
	var raw := SystemLayout.world_drawn(w, z)
	return SystemLayout.held_most(raw, minf(SystemLayout.WORLD_FLOOR, raw))


## How far world w round a star stands from its sun's drawn disc beside it at
## zoom z, as drawn (game px).
static func _side(L: SystemLayout, w: SystemLayout.Body, z: float) -> float:
	return w.orbit * z - _sun_held(L, w.host_id, z) - _disc_held(w, z)


## Whether a layout has a place that comes and goes out past its edge: the
## Hellbender's, or a signed job's.
static func _comers_in(n: MapGen.MapNode, L: SystemLayout) -> bool:
	if L.hellbender_place() >= 0:
		return true
	for b in L.bodies:
		for bc in b.beacons:
			if bc.opt >= 0 and bc.opt < n.options.size() and OptionTable.is_job(n.options[bc.opt]):
				return true
	return false


## How many of each thing the two-sun checks counted, across every twin.
var _twin_n := {}


func _tally(k: String) -> void:
	_twin_n[k] = int(_twin_n.get(k, 0)) + 1


## Jobs and the Hellbender push the edge out, so the suns' reach is measured, not promised.
## Why: docs/why/SystemTest.md#comers
func _comers(n: MapGen.MapNode, at: String) -> void:
	var hb_at := Run.hellbender_at
	var hb_hp := Run.hellbender_hp
	var n_opt := n.options.size()
	if hb_at == n.index:
		Run.hellbender_at = -1
	var bare := SystemLayout.of(n)
	if _comers_in(n, bare):
		# (a Hellbender's wreck lies here, or a job is posted: not bare)
		Run.hellbender_at = hb_at
		return
	var cases: Array = [["a fetch", [&"job_pickup"], false], ["a hunt", [&"job_target"], false],
		["the Hellbender", [], true], ["a fetch, a hunt and the Hellbender", [&"job_pickup", &"job_target"], true]]
	for c in cases:
		for id in c[1]:
			n.options.append(id)
		if c[2]:
			Run.hellbender_at = n.index
			Run.hellbender_hp = maxi(hb_hp, 1)
		var L := SystemLayout.of(n)
		Run.hellbender_at = -1 if hb_at == n.index else hb_at
		Run.hellbender_hp = hb_hp
		n.options.resize(n_opt)
		var what: String = c[0]
		_tally("twins with %s out" % what)
		if L.bodies.size() != bare.bodies.size() + c[1].size() + (1 if c[2] else 0):
			_fail("%s: with %s out, %d bodies against %d" % [at, what, L.bodies.size(), bare.bodies.size()])
			continue
		var moved := L.fit_zoom != bare.fit_zoom or L.sep != bare.sep
		for p in bare.stars():
			moved = moved or L.keep_clear_of(p) != bare.keep_clear_of(p) or L.star_rail_of(p) != bare.star_rail_of(p) \
				or L.star_ring_of(p) != bare.star_ring_of(p)
		for i in bare.bodies.size():
			var a := bare.bodies[i]
			var b := L.bodies[i]
			moved = moved or a.orbit != b.orbit or a.phase != b.phase or a.period != b.period or a.host0 != b.host0 \
				or a.world != b.world or a.soi != b.soi or a.name != b.name
		if moved:
			_fail("%s: putting %s out moved a body, a star's rings or the fitted zoom" % [at, what])
		# what the map then draws: its opening zoom, the suns' drawn discs against
		# the layout's rings and the planner's live keep-out, the worlds beside them
		var z := SystemLayout.open_zoom(L.edge)
		_least("with %s out: opening zoom over the fitted one" % what, z / L.fit_zoom, at)
		for p in L.stars():
			var sd := SystemLayout.sun_drawn(L.star_radius(p), z) / z
			_least("with %s out: star's ring outside its drawn sun (plane px)" % what, L.star_ring_of(p) - sd, at)
			_most("with %s out: the drawn sun + 6 past the layout's keep-out, most (plane px)" % what, sd + SystemLayout.RING_OUT - L.keep_clear_of(p), at)
			if L.star_ring_of(p) < sd:
				_tally("with %s out: star rings inside the drawn sun" % what)
		for w in L.bodies:
			if SystemLayout.is_star(w.host_id):
				var side := _side(L, w, z)
				_least("with %s out: world beside its sun, as drawn (game px)" % what, side, at)
				_tally("with %s out: worlds round a star" % what)
				if side < SystemLayout.SIDE_GAP:
					_tally("with %s out: worlds under 3 game px off their sun" % what)
				if side < 0.0:
					_tally("with %s out: worlds whose disc runs into their sun's beside it" % what)
	Run.hellbender_at = hb_at
	Run.hellbender_hp = hb_hp


## THE TWO-SUN PROMISES, on one twin layout.
func _twin_checks(n: MapGen.MapNode, L: SystemLayout, at: String) -> void:
	var share := L.star_share
	if L.star != SystemLayout.StarKind.ORDINARY or L.star2 != SystemLayout.StarKind.ORDINARY:
		_fail("%s: two suns that are not both ordinary" % at)
	if not (L.star2_r < L.star_r and L.star2_r > 0.0):
		_fail("%s: star B (r %.1f) is not the smaller" % [at, L.star2_r])
	if share < SystemLayout.TWIN_SHARE_LO - 1e-9 or share > SystemLayout.TWIN_SHARE_HI + 1e-9:
		_fail("%s: star A's share %.3f" % [at, share])
	if absf(L.star2_at0.length() - L.sep) > 0.01:
		_fail("%s: the stars %.1f apart, star B %.1f out" % [at, L.sep, L.star2_at0.length()])
	if L.bary.distance_to(L.star2_at0 * (1.0 - share)) > 0.01:
		_fail("%s: the balance point is not where the shares put it" % at)
	if not L.star_beacons.is_empty():
		_fail("%s: an event on a star of a pair" % at)
	_seen += 1
	if L.close:
		_close_checks(n, L, at)
		return
	_tally("wide pairs")
	if L.sep < SystemLayout.TWIN_SEP_LO - 1e-6:
		_fail("%s: a wide pair's stars %.1f apart" % [at, L.sep])
	if L.sep > SystemLayout.TWIN_SEP_HI + 0.5:
		_spread_out += 1
		_most("separation spread past its roll", L.sep, at)
	# WHAT EACH BODY CIRCLES: star A at the origin, star B at its place, or the
	# balance point; one world round each star, and only one
	var round_a: Array[SystemLayout.Body] = []
	var round_b: Array[SystemLayout.Body] = []
	var both: Array[SystemLayout.Body] = []
	for b in L.bodies:
		if b.host_id == -1 and b.host0 == Vector2.ZERO:
			round_a.append(b)
		elif b.host_id == STAR_B and b.host0.distance_to(L.star2_at0) < 0.01:
			round_b.append(b)
		elif b.host_id == -9 and b.host0.distance_to(L.bary) < 0.01:
			both.append(b)
		else:
			_fail("%s: %s %s circles %d at (%.1f, %.1f), which is no centre" % [at, b.kind, b.name, b.host_id, b.host0.x, b.host0.y])
	if round_a.size() != 1 or round_b.size() != 1 or round_a[0].kind != &"planet" or round_b[0].kind != &"planet":
		_fail("%s: %d bodies round star A and %d round star B, not one world each" % [at, round_a.size(), round_b.size()])
		return
	var planets := L.bodies.filter(func(b): return b.kind == &"planet")
	if planets[0] != round_a[0] or planets[1] != round_b[0]:
		_fail("%s: the worlds round the stars are not its first two planets" % at)
	var sw: Array[SystemLayout.Body] = [round_a[0], round_b[0]]
	# INSIDE THE FARTHEST STEADY ORBIT round its star, at 0.70 to 0.90 of it
	for w in sw:
		var mu := (1.0 - share) if w.host_id == -1 else share
		var lim := SystemLayout.s_limit(mu) * L.sep
		var f := w.orbit / lim
		if f > SystemLayout.S_HI + 1e-6 or f < SystemLayout.S_LO - 1e-6:
			_fail("%s: %s at %.3f of its steady limit (%.1f of %.1f px)" % [at, w.name, f, w.orbit, lim])
		_least("world round a star, share of its limit", f, at)
		_most("world round a star, share of its limit, most", f, at)
	# PAST THE NEAREST STEADY ORBIT ROUND BOTH, for this pair's shares, and never
	# inside the build's 2.423
	var p_lim := SystemLayout.p_limit(1.0 - share)
	var hw := 1.60 + 4.12 * (1.0 - share) - 5.09 * pow(1.0 - share, 2.0)
	if p_lim < 2.423 or p_lim < hw - 1e-9:
		_fail("%s: the nearest steady orbit round both taken as %.3f, under %.3f" % [at, p_lim, maxf(2.423, hw)])
	for b in both:
		var k := b.orbit / L.sep
		if k < p_lim:
			_fail("%s: %s %s round both at %.3f of the separation, inside %.3f" % [at, b.kind, b.name, k, p_lim])
		_least("round both, orbit over separation", k, at)
		_least("round both, orbit past its steady limit (share)", k / p_lim, at)
	# NEIGHBOURS APART ROUND EACH CENTRE, nearest out, not by index
	for group in [round_a, round_b, both]:
		var g: Array = group.duplicate()
		g.sort_custom(func(x, y): return x.orbit < y.orbit)
		for i in range(1, g.size()):
			var gap: float = g[i].orbit - g[i - 1].orbit - SystemLayout.reach_of(g[i]) - SystemLayout.reach_of(g[i - 1])
			_least("gap between neighbours round both", gap, at)
			if gap <= 0.0:
				_fail("%s: %s and %s cross their bodies round the same centre (gap %.1f)" % [at, g[i - 1].name, g[i].name, gap])
	# Kepler round what it circles, times the pair's speed (ruling 23), so laps match.
	var kk := maxf(SystemLayout.pair_speed(), 1.0)
	for b in L.bodies:
		var m := 1.0 if b.host_id == -9 else (share if b.host_id == -1 else 1.0 - share)
		var kep := SystemLayout.kepler_s() * pow(b.orbit / 100.0, 1.5) / sqrt(m)
		if b.host_id != -9:
			kep /= kk
		var k := b.period / kep
		if k < 0.95 - 1e-6 or k > 1.05 + 1e-6:
			_fail("%s: %s's period is %.3f of Kepler's%s round what it circles" % [at, b.name, k, "" if b.host_id == -9 else " x %.0f" % kk])
	# The keep-clear is no nearer than the autopilot's keep-out at the fitted zoom.
	var fz := L.fit_zoom
	if not (fz > 0.0):
		_fail("%s: no zoom the layout is fitted to (%.3f)" % [at, fz])
		return
	for p in L.stars():
		var r := L.star_radius(p)
		if not (r < L.keep_clear_of(p) and L.keep_clear_of(p) < L.star_rail_of(p) and L.star_rail_of(p) < L.star_ring_of(p)):
			_fail("%s: star %d's keep-clear %.1f, rail %.1f and ring %.1f are out of order" % [at, p, L.keep_clear_of(p), L.star_rail_of(p), L.star_ring_of(p)])
		var keep_out := SystemLayout.sun_drawn(r, fz) / fz + SystemLayout.RING_OUT
		_least("star's keep-clear past the keep-out at the fitted zoom (plane px)", L.keep_clear_of(p) - keep_out, at)
		if L.keep_clear_of(p) < keep_out - 1e-6:
			_fail("%s: star %d's keep-clear %.2f is inside the keep-out %.2f (its drawn sun + 6 at the fitted zoom %.3f)" % [at, p, L.keep_clear_of(p), keep_out, fz])
	for w in sw:
		var p := w.host_id
		var q := STAR_B if p == -1 else -1
		var inner := w.orbit - w.soi
		# its own star's close ring inside its orbit, and its ring 8 px clear of it
		var c := inner - L.star_ring_of(p)
		_least("world's ring past its star's close ring", c, at)
		if c < SystemLayout.RING_CLEAR - 1e-6 or inner < L.keep_clear_of(p):
			_fail("%s: %s's ring (%.1f to %.1f) is %.1f px off its star's close ring %.1f (keep-clear %.1f)" % [at, w.name, inner, w.orbit + w.soi, c, L.star_ring_of(p), L.keep_clear_of(p)])
		# and the other star's, wherever on their circles they are
		var cq := w.host0.distance_to(L.star_pos(q, 0.0)) - w.orbit - w.soi
		_least("world's ring off the other star's close ring", cq - L.star_ring_of(q), at)
		if cq - L.star_ring_of(q) < SystemLayout.RING_CLEAR or cq < L.keep_clear_of(q):
			_fail("%s: %s's ring comes %.1f px from the other star" % [at, w.name, cq])
		# and every other body's ring (or body) it can meet
		for o in L.bodies:
			if o == w:
				continue
			var meet := _closest(w, o) - w.soi - _ring(o)
			_least("world round a star, ring off any other ring", meet, at)
			if meet <= 0.0:
				_fail("%s: %s's ring meets %s %s's" % [at, w.name, o.kind, o.name])
	# the rings round both clear of both stars' close rings
	for b in both:
		for p in L.stars():
			var near := b.orbit - b.host0.distance_to(L.star_pos(p, 0.0)) - _ring(b) - L.star_ring_of(p)
			if near < SystemLayout.RING_CLEAR:
				_fail("%s: %s %s's ring comes %.1f px from star %d's close ring" % [at, b.kind, b.name, near, p])
	# Round both, bodies are kept apart but not rings, as round one sun; the overlap is printed.
	for b in both:
		_tally("bodies round both")
		var held := false
		for o in both:
			if o == b or o.soi <= 0.0:
				continue
			if _closest(o, b) < o.soi:
				held = true
				if o.kind == &"giant":
					_tally("of them inside the giant's ring")
		if held:
			_tally("of them inside another world's ring")
	# At the near point the edge is too far out for the zone, so that is measured, not promised.
	# Why: docs/why/SystemTest.md#opening-zoom
	var z := SystemLayout.open_zoom(L.edge)
	var bare := not _comers_in(n, L)
	# (the edge adds 32-bit `Vector2` host lengths: a millionth either way)
	if bare and z < fz * (1.0 - 1e-6):
		_fail("%s: the map opens at %.4f, further out than the zoom the layout is fitted to (%.4f)" % [at, z, fz])
	for w in sw:
		var p := w.host_id
		var side := _side(L, w, z)
		var front := w.orbit * z * SystemLayout.SLANT - _sun_held(L, p, z) - _disc_held(w, z)
		var tag := "" if bare else ", the Hellbender here"
		_least("world beside its sun at the opening zoom, as drawn (game px)%s" % tag, side, at)
		_least("world in front of its sun at the opening zoom, as drawn (game px)%s" % tag, front, at)
		_most("world in front of its sun at the opening zoom, as drawn, most (game px)%s" % tag, front, at)
		var sd := SystemLayout.sun_drawn(L.star_radius(p), z) / z
		_least("star's close orbit past its keep-out at the opening zoom (plane px)%s" % tag, L.star_rail_of(p) - sd - SystemLayout.RING_OUT, at)
		if bare and side < SystemLayout.SIDE_GAP - 1e-4:
			_fail("%s: %s stands %.2f game px off its sun's drawn disc at the opening zoom %.3f" % [at, w.name, side, z])
		if bare and L.star_rail_of(p) < sd + SystemLayout.RING_OUT - 1e-4:
			_fail("%s: star %d's close orbit %.2f is inside the keep-out %.2f at the opening zoom %.3f" % [at, p, L.star_rail_of(p), sd + SystemLayout.RING_OUT, z])
	# ZONES BY DISTANCE FROM THE LIGHT: never a farther body in a nearer zone;
	# the worlds round a star near
	_zones_and_names(L, at)
	for w in sw:
		if w.zone != 0:
			_fail("%s: %s, %.0f px from its sun, is not near" % [at, w.name, w.orbit])


## Zones by distance from the light, never a farther body in a nearer zone, and
## no two bodies of one name: a pair of either kind.
func _zones_and_names(L: SystemLayout, at: String) -> void:
	var dist := {}
	for b in L.bodies:
		var flux := 0.0
		for p in L.stars():
			var cc := L.star_pos(p, 0.0).distance_to(b.host0)
			flux += pow(L.star_radius(p) / 16.0, 2.0) / maxf(absf(cc * cc - b.orbit * b.orbit), 1.0)
		dist[b] = 1.0 / sqrt(flux)
	for a in L.bodies:
		for b in L.bodies:
			if float(dist[a]) < float(dist[b]) and a.zone > b.zone:
				_fail("%s: %s (%.0f px from the light) is in zone %d, farther %s (%.0f) in %d" % [at, a.name, dist[a], a.zone, b.name, dist[b], b.zone])
	var names := {}
	for b in L.bodies:
		if names.has(b.name):
			_fail("%s: two bodies called %s" % [at, b.name])
		names[b.name] = true


## The close pair's promises (Jon, Nov 1); some are counted and printed rather than promised.
## Why: docs/why/SystemTest.md#close-pair
func _close_checks(n: MapGen.MapNode, L: SystemLayout, at: String) -> void:
	_tally("close pairs")
	if L.sep < SystemLayout.CLOSE_SEP_LO - 1e-6 or L.sep > SystemLayout.CLOSE_SEP_HI + 1e-6:
		_fail("%s: a close pair's stars %.1f apart" % [at, L.sep])
	_least("close pair: separation", L.sep, at)
	_most("close pair: separation, most", L.sep, at)
	var lo := SystemLayout.p_limit(1.0 - L.star_share) * SystemLayout.P_MARGIN * L.sep
	for b in L.bodies:
		if b.host_id != -9 or b.host0.distance_to(L.bary) > 0.01:
			_fail("%s: %s %s circles %d, not both suns" % [at, b.kind, b.name, b.host_id])
		if b.orbit < lo - 1e-6:
			_fail("%s: %s %s round both at %.1f px, inside the first steady orbit %.1f" % [at, b.kind, b.name, b.orbit, lo])
		_least("close pair: orbit past its steady limit (share)", b.orbit / (lo / SystemLayout.P_MARGIN), at)
		var k := b.period / (SystemLayout.kepler_s() * pow(b.orbit / 100.0, 1.5))
		if k < 0.95 - 1e-6 or k > 1.05 + 1e-6:
			_fail("%s: %s's period is %.3f of Kepler's round both" % [at, b.name, k])
	var g: Array = L.bodies.duplicate()
	g.sort_custom(func(x, y): return x.orbit < y.orbit)
	for i in range(1, g.size()):
		var gap: float = g[i].orbit - g[i - 1].orbit - SystemLayout.reach_of(g[i]) - SystemLayout.reach_of(g[i - 1])
		_least("close pair: gap between neighbours", gap, at)
		if gap <= 0.0:
			_fail("%s: %s and %s cross their bodies (gap %.1f)" % [at, g[i - 1].name, g[i].name, gap])
	var fz := L.fit_zoom
	if not (fz > 0.0):
		_fail("%s: no zoom the layout is fitted to (%.3f)" % [at, fz])
		return
	for p in L.stars():
		var r := L.star_radius(p)
		if not (r < L.keep_clear_of(p) and L.keep_clear_of(p) < L.star_rail_of(p) and L.star_rail_of(p) < L.star_ring_of(p)):
			_fail("%s: star %d's keep-clear %.1f, rail %.1f and ring %.1f are out of order" % [at, p, L.keep_clear_of(p), L.star_rail_of(p), L.star_ring_of(p)])
		var keep_out := SystemLayout.sun_drawn(r, fz) / fz + SystemLayout.RING_OUT
		if L.keep_clear_of(p) < keep_out - 1e-6:
			_fail("%s: star %d's keep-clear %.2f is inside the keep-out %.2f" % [at, p, L.keep_clear_of(p), keep_out])
	# THE TWO SUNS' OWN RINGS, apart: keep-outs, a close orbit against the other's
	# keep-out, capture rings
	var ka := L.keep_clear_of(-1)
	var kb := L.keep_clear_of(STAR_B)
	var keeps := L.sep - ka - kb
	var rails := minf(L.sep - L.star_rail_of(-1) - kb, L.sep - L.star_rail_of(STAR_B) - ka)
	var rings := L.sep - L.star_ring_of(-1) - L.star_ring_of(STAR_B)
	_least("close pair: the suns' keep-outs apart (px)", keeps, at)
	_least("close pair: a sun's close orbit off the other's keep-out (px)", rails, at)
	_least("close pair: the suns' capture rings apart (px)", rings, at)
	if keeps <= 0.0 or rails <= 0.0 or rings <= 0.0:
		_fail("%s: the suns' keep-outs %.1f, close orbits %.1f, capture rings %.1f px apart" % [at, keeps, rails, rings])
	# EVERY RING ROUND BOTH CLEAR OF BOTH SUNS' CLOSE RINGS, a world's by RING_GAP
	# (one sun's rule), anything else's by RING_CLEAR
	for b in L.bodies:
		for p in L.stars():
			var near := b.orbit - b.host0.distance_to(L.star_pos(p, 0.0)) - _ring(b) - L.star_ring_of(p)
			var want := SystemLayout.RING_GAP if b.soi > 0.0 else SystemLayout.RING_CLEAR
			_least("close pair: a ring off a sun's close ring (px)", near, at)
			if near < want - 1e-6:
				_fail("%s: %s %s's ring comes %.1f px from star %d's close ring" % [at, b.kind, b.name, near, p])
	var z := SystemLayout.open_zoom(L.edge)
	if not _comers_in(n, L) and z < fz * (1.0 - 1e-6):
		_fail("%s: the map opens at %.4f, further out than the zoom the layout is fitted to (%.4f)" % [at, z, fz])
	_zones_and_names(L, at)
	# what it holds (counted)
	var mid := false
	var first: SystemLayout.Body = g[0]
	for b in L.bodies:
		if b.kind == &"planet" and b.zone == 1:
			mid = true
		var held := false
		for o in L.bodies:
			if o != b and o.soi > 0.0 and absf(o.orbit - b.orbit) < o.soi:
				held = true
		_tally("close pairs: bodies")
		if held:
			_tally("close pairs: of them inside another world's ring")
	if mid:
		_tally("close pairs with a planet in the middle band")
	_tally("close pairs whose first body is %s" % ["hot", "temperate", "cold"][first.zone])


## `twin=all` makes every eligible system a twin and each keeps every promise; `none` makes none.
func _all_twins() -> void:
	MapGen.twin_force = 1
	var laid := 0
	var missed := 0
	var rows: Array[String] = []
	var zooms: Array[float] = []
	for s in SEEDS:
		Rng.forced = s
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
		var shown := 0
		for raw in Run.map:
			var n: MapGen.MapNode = raw
			if not MapGen.twin_ok(n):
				if n.twin:
					_fail("twin=all: system %d may not have two suns and has" % n.index)
				continue
			var before := JSON.stringify(Rng.state())
			var L := SystemLayout.of(n)
			if JSON.stringify(Rng.state()) != before:
				_fail("twin=all: laying out system %d moved a shared stream" % n.index)
			if not (n.twin and L.twin):
				missed += 1
				continue
			if _print_of(L) != _print_of(SystemLayout.of(n)):
				_fail("twin=all: system %d laid out two ways in one run" % n.index)
			laid += 1
			zooms.append(SystemLayout.open_zoom(L.edge))
			_twin_checks(n, L, "twin=all seed %d system %d" % [s, n.index])
			_comers(n, "twin=all seed %d system %d" % [s, n.index])
			_weights(n, L)
			if shown < 2:
				rows.append(_row(s, n, L))
				shown += 1
	_ok("twin=all: every one of the %d systems that may have two suns has them (%d not)" % [laid, missed], laid > 0 and missed == 0)
	print("  opening zoom, two suns at every system that may have them: %s" % _spread(zooms))
	_hellbender("twin=all: ")
	MapGen.twin_force = -1
	var any := 0
	for s in SEEDS:
		Rng.forced = s
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
		for raw in Run.map:
			if (raw as MapGen.MapNode).twin or SystemLayout.of(raw as MapGen.MapNode).twin:
				any += 1
	_ok("twin=none: no system has two suns (%d do)" % any, any == 0)
	MapGen.twin_force = 0
	print("  two-sun systems (twin=all), two a seed:")
	print("    seed node  sep  share  rA   rB  | round A: a / limit (ring; star A's keep-clear, close orbit, ring) | round B: the same | round both: kind a (ring) ... | edge  zoom | A beside, in front | B beside, in front (game px, as drawn)")
	for r in rows:
		print("    " + r)


## One line of the table: a twin's pair, its worlds and how they are drawn at its opening zoom.
func _row(s: int, n: MapGen.MapNode, L: SystemLayout) -> String:
	var z := SystemLayout.open_zoom(L.edge)
	var ws := {}
	var both: Array[String] = []
	for b in L.bodies:
		if b.host_id == -9:
			both.append("%s %.0f (%.0f)" % [b.kind, b.orbit, _ring(b)])
		else:
			var mu := (1.0 - L.star_share) if b.host_id == -1 else L.star_share
			var sun := _sun_held(L, b.host_id, z)
			var disc := _disc_held(b, z)
			ws[b.host_id] = "%.1f / %.1f (%.0f; its star's %.1f, %.1f, %.1f) | " % [b.orbit, SystemLayout.s_limit(mu) * L.sep, b.soi,
				L.keep_clear_of(b.host_id), L.star_rail_of(b.host_id), L.star_ring_of(b.host_id)]
			ws[str(b.host_id)] = "%.1f, %.1f" % [b.orbit * z - sun - disc, b.orbit * z * SystemLayout.SLANT - sun - disc]
	return "%5d %4d %5.0f %.3f %4.1f %4.1f | %s%s%s | %5.0f %.3f | %s | %s" % [s, n.index, L.sep, L.star_share,
		L.star_r, L.star2_r, ws.get(-1, "(a close pair: none round one sun) | " if L.close else "?"), ws.get(STAR_B, "" if L.close else "?"), ", ".join(both), L.edge, z,
		ws.get("-1", "?"), ws.get(str(STAR_B), "?")]


## What the two-sun checks measured.
func _report() -> void:
	print("  two-sun layouts checked: %d, %d of them moved apart past their rolled separation" % [_seen, _spread_out])
	var nk := _twin_n.keys()
	nk.sort()
	for k in nk:
		print("  %s: %d" % [k, int(_twin_n[k])])
	var keys := _st.keys()
	keys.sort()
	for k in keys:
		print("  %s: %.3f (%s)" % [k, float(_st[k][0]), _st[k][1]])


## Its place: last, past every orbit, and nothing else moved by it.
func _hellbender(label: String) -> void:
	Rng.forced = SEEDS[0]
	# (ascension 7: the Hellbender flies only there, Jon, Nov 8)
	Run.forced_ascension = Run.HELLBENDER_ASCENSION
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Run.forced_ascension = -1
	if not Run.hellbender_alive():
		_fail("no Hellbender in this run to place")
		return
	var n: MapGen.MapNode = Run.map[Run.hellbender_at]
	var with := SystemLayout.of(n)
	var at := Run.hellbender_at
	Run.hellbender_at = -1
	var without := SystemLayout.of(n)
	Run.hellbender_at = at
	var hp := with.hellbender_place()
	_ok("%sthe Hellbender's system (%s) gives it a place, last (%d of %d)" % [label, "two suns" if with.twin else "one sun", hp, with.bodies.size()],
		hp == with.bodies.size() - 1 and without.hellbender_place() == -2)
	var same := with.bodies.size() == without.bodies.size() + 1
	for i in without.bodies.size():
		var a := with.bodies[i]
		var b := without.bodies[i]
		same = same and is_equal_approx(a.orbit, b.orbit) and is_equal_approx(a.phase, b.phase) and a.world == b.world
	_ok("%sand every other body is where it is without it" % label, same)
	# past every orbit: its own inner reach beyond every other body's outer, from
	# the centre it circles (round two suns, not every body circles that one)
	var past := hp >= 0
	if past:
		var hb := with.bodies[hp]
		for b in without.bodies:
			past = past and hb.orbit - SystemLayout.reach_of(hb) > b.host0.distance_to(hb.host0) + b.orbit + SystemLayout.reach_of(b)
	_ok("%spast every orbit" % label, past)


## Comets keep today's speed (Jon, Nov 5): WORLD_PACE turns the worlds and the pair faster, nothing else.
## At WORLD_PACE 1 and 4 a comet planned off the radii is at the same place at every age.
## Why: docs/why/SystemTest.md#comet-pace
func _comet_pace() -> void:
	var SW := preload("res://scripts/ui/sysmap/SkyWeather.gd")
	var was := SystemLayout.world_k
	var worst := 0.0
	var n_sys := 0
	var faster := true
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		if n.type != MapGen.NodeType.SYSTEM:
			continue
		n_sys += 1
		var paths: Array = []
		var periods: Array = []
		for k: float in [1.0, 4.0]:
			SystemLayout.world_k = k
			var L := SystemLayout.of(n)
			var inner := INF
			for b in L.bodies:
				if b.kind != &"belt" and (b.host_id == -1 or L.close):
					inner = minf(inner, b.orbit)
			if inner == INF:
				inner = L.star_r * 6.0
			var q := inner * 0.9
			var De := sqrt(maxf(L.edge / q - 1.0, 0.1))
			var ev := {"q": q, "w": 0.7, "K": 70.0 / (De + De * De * De / 3.0), "tp": 35.0}
			var pts: Array = []
			for age in 81:
				pts.append(SW.Comet.comet_pos(ev, float(age)))
			paths.append(pts)
			periods.append(L.bodies[0].period if not L.bodies.is_empty() else 0.0)
		for j in (paths[0] as Array).size():
			worst = maxf(worst, ((paths[0][j] as Vector2) - (paths[1][j] as Vector2)).length())
		if float(periods[0]) > 0.0 and absf(float(periods[0]) / float(periods[1]) - 4.0) > 1e-6:
			faster = false
	SystemLayout.world_k = was
	_ok("comets keep today's speed at every WORLD_PACE: %d systems' comets at the same place round their sun at every age, at 1 and 4 (worst %.6f px), while the worlds go 4 times as fast" % [n_sys, worst], n_sys > 0 and worst == 0.0 and faster)
