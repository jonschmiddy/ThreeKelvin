extends Node

## THE AUTOPILOT'S SOLVED FLIGHTS (ruling 20, Oct 30), planned and measured:
##   godot --headless --path . -- sheet=SolveTest [systems=N] [lineups=N] [twins=N]
##     [twinlineups=N] [worker=N] [only=one|giant|twin|rtwin|proto]
## `FlightSolve` from every start to every place, at line-ups (map times), in
## four sweeps:
##   one    real one-star systems from systemtest's four seeds (SYSTEM, PULSAR
##          and STATION nodes, N of each seed, those with a giant first), the
##          giant pulling nothing;
##   giant  the same systems' giants set by hand to 1/10 and 1/4 of the star;
##   rtwin  the layout's own two-star systems: per seed the `twins` with the
##          most bodies (each SYSTEM node asked for two suns, as `-- twin=all`
##          does), their giants as rolled. None until the layout makes twins:
##          the sweep says so and is not judged;
##   twin   two-star systems built by hand to the prototype's geometry (stars
##          280 px apart, A 0.55 of the pull, world a 80 px round A and b 70 px
##          round B with 38.4 px rings, c round both at 680 px with a 70.4 px
##          ring) and the same at 300 and 380 px apart, each star's keep-out,
##          close orbit and ring as the layout's ladder sets them. Its worlds
##          round one star sit at 0.98 of the steady limit, past the layout's
##          0.90, with rings twice the layout's: the prototype's case, not the
##          game's (rtwin is that).
## Starts: each world's ring, each star's close orbit, a settled star orbit
## (round the star, or round both stars' balance point: a ring round a fixed
## point, where every visit's ship arrives, `ShipFlight.setup`), alongside a
## station, belt, hulk or contact, and flying free. Targets: each world's ring (either
## way round), each star's close orbit, each station, belt, hulk and contact.
## For each plan: found; clean (every keep-out held along the samples);
## starts where the ship is (on its ring at the departure, at the ring's own
## motion); lands (the last sample on the ring at ring speed, or alongside at
## the place's motion, within LAND_PX and LAND_V, the place where the layout's
## own Body has it, not MapGravity's copy); its pull at most THRUST in a burn
## and none on the coast (from the samples, every SPAN); the ride's phasing
## push at most THRUST; engine work, time, integrations and milliseconds.
## A sample of plans flown again at SAMPLE by plain RK4 through
## `MapGravity.acc` (the physics); rebuilt from their own choice (the same
## samples bit for bit, now, half a second on round a ring, and half a second
## on alongside); planned again 3 s on with the old choice (the overlay's
## preview in orbit), every one found and none kept that a fresh search beats
## by more than the warm slack; and every plan of the first `worker` cases
## solved again on WorkerThreadPool (the same results). Also the prototype's
## a-to-b flight at its best line-up.
## PASS: found and clean in at least 99% of each sweep (DESIGN), but 97% of
## the hand twins, whose geometry the layout never builds: their worlds round
## one star sit at 0.98 of the steady limit (the layout's at most 0.90), their
## rings twice the layout's reach the star's close orbit, and two of the three
## pairs are closer than the layout's 300 px; flights between their stars'
## close orbits, 2 px outside the keep-out as the layout puts them, are the
## misses (65 of 72 found). Every found plan starting and landing, no burn in
## it swinging the ship round a point (`FlightSolve.V_CUSP`, read off its
## samples), every replay and worker result the same. Planning time is measured and judged in
## the log (median 25 ms, worst 150 ms: DESIGN), not failed on: this Mac's load
## varies.

const SEEDS := [4242, 7, 1999, 31337]
const LAND_PX := 0.5
const LAND_V := 0.5
const START_PX := 0.05
const START_V := 0.5
## the samples the pull is read over (finite differences): 4 apart
const SPAN := 4
const RAIL_V := 35.0
const STAR_RAIL_V := 45.0
## `ShipFlight.ORBIT_K`
const ORBIT_K := 0.88
## `ShipFlight.STAR_PACE`: a settled star orbit's pace, times Kepler's
const STAR_PACE := 50.0
const KEEP_OFF := Vector2(8.0, 5.0 / 0.38)
## found and clean in at least this share of each sweep (above)
const FOUND_MIN := 0.99
const FOUND_MIN_HAND := 0.97

var h := Harness.new()
var _per_seed := 4
var _lineups := 12
var _twins := 2
var _twin_lineups := 6
var _worker_n := 400
var _only := ""
## every case: {sweep, L, G, dep, tgt, t, label, kind, hand}
var _cases: Array = []
var _res: Array = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var s := a as String
		if s.begins_with("systems="):
			_per_seed = int(s.substr(8))
		elif s.begins_with("lineups="):
			_lineups = int(s.substr(8))
		elif s.begins_with("twins="):
			_twins = int(s.substr(6))
		elif s.begins_with("twinlineups="):
			_twin_lineups = int(s.substr(12))
		elif s.begins_with("worker="):
			_worker_n = int(s.substr(7))
		elif s.begins_with("only="):
			_only = s.substr(5)
	_run.call_deferred()


func _wants(sweep: String) -> bool:
	return _only == "" or _only == sweep


func _run() -> void:
	await get_tree().process_frame
	var t_all := Time.get_ticks_msec()
	_bench()
	if _wants("proto"):
		_prototype()
	if _wants("one") or _wants("giant") or _wants("rtwin"):
		_real_cases()
	if _wants("twin"):
		_twin_cases()
	print("solvetest: %d cases" % _cases.size())
	# every case, on the main thread
	for i in _cases.size():
		var c: Dictionary = _cases[i]
		var r := FlightSolve.solve(c.G, c.dep, c.tgt, float(c.t))
		_res.append(r)
	for sw: String in ["one", "giant", "rtwin", "twin"]:
		_report(sw)
	if _wants("rtwin"):
		var nrt := 0
		for c in _cases:
			if c.sweep == "rtwin":
				nrt += 1
		if nrt == 0:
			print("rtwin: no two-star layouts in this tree (the layout's twins are not here yet): not judged")
	if not _cases.is_empty():
		_replays()
		_replans()
		_physics()
		_worker()
	print("solvetest: all of it took %.0f s" % ((Time.get_ticks_msec() - t_all) / 1000.0))
	h.verdict("solvetest")
	get_tree().quit(h.code())


# ---------------------------------------------------------------- the systems
## Real systems, per seed: the first `_per_seed` SYSTEM, PULSAR or STATION
## nodes with one star, those with a giant first, each with the giant
## weightless (one) and at 1/10 and 1/4 (giant); and the `_twins` two-star
## layouts with the most bodies (rtwin), every SYSTEM node asked for two suns.
func _real_cases() -> void:
	for sd: int in SEEDS:
		Rng.forced = sd
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
		var withg: Array = []
		var without: Array = []
		var twins: Array = []
		for raw in Run.map:
			var n: MapGen.MapNode = raw
			if n.type != MapGen.NodeType.SYSTEM and n.type != MapGen.NodeType.PULSAR and n.type != MapGen.NodeType.STATION:
				continue
			OptionTable.ensure(n)
			var L := SystemLayout.of(n)
			if not L.twin:
				var has := false
				for b in L.bodies:
					if b.kind == &"giant":
						has = true
				if has:
					withg.append(L)
				else:
					without.append(L)
			if n.type == MapGen.NodeType.SYSTEM:
				# (two suns where the layout may give them: `-- twin=all`'s way)
				var was := n.twin
				n.twin = true
				var L2 := SystemLayout.of(n)
				n.twin = was
				if L2.twin:
					twins.append([n.index, L2])
		if _wants("one") or _wants("giant"):
			var pick: Array = withg.slice(0, mini(withg.size(), ceili(_per_seed / 2.0)))
			pick.append_array(without.slice(0, _per_seed - pick.size()))
			for L: SystemLayout in pick:
				var label := "seed %d, %d bodies%s" % [sd, L.bodies.size(), "" if L.star == SystemLayout.StarKind.ORDINARY else " (star %d)" % L.star]
				var gb: SystemLayout.Body = null
				for b in L.bodies:
					if b.kind == &"giant":
						gb = b
				var gm0 := gb.gm if gb != null else 0.0
				var gf0 := gb.gm_frac if gb != null else 0.0
				if _wants("one"):
					if gb != null:
						gb.gm = 0.0
						gb.gm_frac = 0.0
					_add_system("one", L, MapGravity.from_layout(L), label, false)
				if _wants("giant") and gb != null:
					for frac: float in [0.10, 0.25]:
						gb.gm_frac = frac
						gb.gm = frac * SystemLayout.GM_SHIP
						_add_system("giant", L, MapGravity.from_layout(L), label + ", giant %.2f" % frac, false)
				if gb != null:
					gb.gm = gm0
					gb.gm_frac = gf0
		if _wants("rtwin"):
			twins.sort_custom(func(a: Array, b: Array) -> bool:
				var la: SystemLayout = a[1]
				var lb: SystemLayout = b[1]
				return la.bodies.size() > lb.bodies.size() or (la.bodies.size() == lb.bodies.size() and int(a[0]) < int(b[0])))
			for row in twins.slice(0, _twins):
				var Lt: SystemLayout = row[1]
				var gi := ""
				for b in Lt.bodies:
					if b.gm > 0.0:
						gi = ", giant %.2f" % b.gm_frac
				var lab := "seed %d node %d (%d bodies, share %.3f, sep %.0f%s)" % [sd, int(row[0]), Lt.bodies.size(), Lt.star_share, Lt.sep, gi]
				_add_system("rtwin", Lt, MapGravity.from_layout(Lt), lab, false)


## A TWO-STAR SYSTEM BY HAND, the prototype's geometry scaled to `sep`: star
## A (0.55) at the origin, B at (sep, 0), world a round A and b round B on the
## prototype's small-rock rings, c round both. Each star's keep-out, close
## orbit and ring as the layout's ladder sets them (`SystemLayout._twin_ladder`
## on the LAYOUT branch): the keep-out the larger of r + 10 and the drawn sun
## at the opening zoom + 6, the rail (the close orbit ridden and arrived on) 2
## px outside it, the ring 2 px further.
static func twin_layout(sep: float, pha: float = 4.584536085992015, phb: float = 3.7905025599699775, phc: float = 0.0) -> SystemLayout:
	var L := SystemLayout.new()
	var share := 0.55
	L.twin = true
	L.star = SystemLayout.StarKind.ORDINARY
	L.star_r = 16.0
	L.star2 = SystemLayout.StarKind.ORDINARY
	L.star2_r = 16.0 * pow((1.0 - share) / share, 0.8)
	L.star2_at = Vector2(sep, 0.0)
	L.star_share = share
	L.sep = sep
	L.bary = Vector2((1.0 - share) * sep, 0.0)
	var k := sep / 280.0
	var a_orb := 80.0 * k
	var b_orb := 70.0 * k
	var c_orb := 680.0 * k
	L.edge = maxf(SystemLayout.HI, L.bary.x + c_orb + 9.0) + 30.0
	var specs := [["a", Vector2.ZERO, -1, a_orb, share, 3.0, 0.0, pha],
		["b", L.star2_at, SystemLayout.STAR_B, b_orb, 1.0 - share, 3.0, 0.0, phb],
		["c", L.bary, -9, c_orb, 1.0, 9.0, (70.4 / 1.6 - 24.0) / 2.4, phc]]
	for i in specs.size():
		var sp: Array = specs[i]
		var b := SystemLayout.Body.new()
		b.kind = &"planet"
		b.world = &"rock"
		b.index = i
		b.name = "twin %s" % sp[0]
		b.host = sp[1]
		b.host_id = sp[2]
		b.orbit = sp[3]
		b.period = 800.0 * pow(b.orbit / 100.0, 1.5) / sqrt(float(sp[4]))
		b.r = sp[5]
		b.mass = sp[6]
		b.phase = sp[7]
		b.soi = SystemLayout.soi_of(b)
		L.bodies.append(b)
	var z := MapGravity.open_zoom(L)
	var ring := {}
	for p: int in [-1, SystemLayout.STAR_B]:
		var r := L.star_radius(p)
		var keep := maxf(r + 10.0, sqrt(pow(r * z, 2.0) + 100.0) / z + 6.0)
		L._keep[p] = keep
		L._rail[p] = keep + 2.0
		ring[p] = keep + 4.0
	# (the layout's ring, where this tree's SystemLayout has one)
	if &"_ring" in L:
		L.set(&"_ring", ring)
	return L


func _twin_cases() -> void:
	for sep: float in [280.0, 300.0, 380.0]:
		var L := twin_layout(sep)
		_add_system("twin", L, MapGravity.from_layout(L), "twin %.0f" % sep, true)


## The radius a ship rides a world's ring at (`ShipFlight.orbit_r`): round the
## hand twins' worlds, the prototype's ring itself.
static func ride_r(L: SystemLayout, i: int, hand: bool = false) -> float:
	var b := L.bodies[i]
	if hand:
		return b.soi
	if L.twin:
		return b.soi * ORBIT_K
	return clampf(b.orbit - (L.star_r + 32.0) - 10.0, b.soi * 0.5, b.soi * ORBIT_K)


static func is_keep(b: SystemLayout.Body) -> bool:
	return b.kind == &"belt" or b.kind == &"station" or b.kind == &"derelict" or b.kind == &"contact"


func _add_system(sweep: String, L: SystemLayout, G: MapGravity, label: String, hand: bool) -> void:
	var lineups := _twin_lineups if sweep == "rtwin" else _lineups
	# starts: [kind, place]
	var starts: Array = []
	var targets: Array = []
	for b in L.bodies:
		if b.world != &"":
			starts.append(["ring", b.index])
			targets.append(["ring", b.index])
	for p in L.stars():
		starts.append(["star", p])
		targets.append(["star", p])
	var nk := 0
	for b in L.bodies:
		if is_keep(b):
			targets.append(["keep", b.index])
			if nk == 0:
				starts.append(["keep", b.index])
			nk += 1
	starts.append(["orbit9", -9])
	starts.append(["free", -9])
	for si in starts.size():
		var st: Array = starts[si]
		for ti in targets.size():
			var tg: Array = targets[ti]
			if st[1] == tg[1] and st[0] != "free":
				continue
			for lu in lineups:
				var t := 40.0 + 37.0 * float(lu)
				# the line-up's own start: an angle round the ring, the way round,
				# a free state (golden-angle steps, no random stream)
				var ang := fposmod(2.39996 * float(lu) + 1.1 * float(si) + 0.7 * float(ti), TAU)
				var sense := -1.0 if lu % 5 == 4 else 1.0
				var dep := {}
				var tag := String(st[0])
				match String(st[0]):
					"ring":
						var rr := ride_r(L, int(st[1]), hand)
						dep = {"kind": &"ring", "place": int(st[1]), "rt": rr, "ang": ang, "w": sense * RAIL_V / rr}
						if L.twin:
							tag = "S" if SystemLayout.is_star(L.bodies[int(st[1])].host_id) else "P"
					"star":
						var rs := FlightSolve.star_orbit_r(L, int(st[1]))
						dep = {"kind": &"ring", "place": int(st[1]), "rt": rs, "ang": ang, "w": STAR_RAIL_V / rs}
					"keep":
						dep = {"kind": &"keep", "place": int(st[1]), "off": KEEP_OFF}
					"orbit9":
						# (out where a visit arrives, 0.55 to 0.85 of the edge round the
						# centre, its pace STAR_PACE times Kepler's there, clear of
						# everything where it starts)
						var c9 := L.bary if L.twin else Vector2.ZERO
						var r9 := (L.edge - c9.length()) * (0.55 + 0.3 * fposmod(float(lu) * 0.618034, 1.0))
						var a9 := ang
						for _k9 in 40:
							var p9 := c9 + Vector2(cos(a9), sin(a9)) * r9
							if G.margin(p9.x, p9.y, t) > 30.0:
								break
							a9 += 0.15
						var pace := STAR_PACE * TAU * 1000.0 / (800.0 * sqrt(r9))
						dep = {"kind": &"ring", "place": -9, "c": c9, "rt": r9, "ang": a9, "w": sense * pace / r9}
					_:
						var fr := fposmod(float(lu) * 0.618034 + float(ti) * 0.3, 1.0)
						var rad := 200.0 + 500.0 * fr
						var p := L.bary + Vector2(cos(ang), sin(ang)) * rad
						# (not inside anything)
						for _k in 40:
							if G.margin(p.x, p.y, t) > 10.0:
								break
							p = L.bary + (p - L.bary) * 1.07
						var hd := fposmod(1.7 * float(lu) + 0.5, TAU)
						var sp := 10.0 + 30.0 * fposmod(float(lu) * 0.377, 1.0)
						dep = {"kind": &"free", "p": p, "v": Vector2(cos(hd), sin(hd)) * sp}
				var tgt := {}
				var ttag := String(tg[0])
				match String(tg[0]):
					"ring":
						tgt = {"kind": &"ring", "place": int(tg[1]), "R": ride_r(L, int(tg[1]), hand), "V": RAIL_V, "sense": 0}
						if L.twin:
							ttag = "S" if SystemLayout.is_star(L.bodies[int(tg[1])].host_id) else "P"
					"star":
						tgt = {"kind": &"ring", "place": int(tg[1]), "R": FlightSolve.star_orbit_r(L, int(tg[1])), "V": STAR_RAIL_V, "sense": 0}
					_:
						tgt = {"kind": &"keep", "place": int(tg[1]), "off": KEEP_OFF}
				_cases.append({"sweep": sweep, "L": L, "G": G, "dep": dep, "tgt": tgt, "t": t, "hand": hand,
					"label": "%s: %s %d to %s %d, line-up %d" % [label, st[0], st[1], tg[0], tg[1], lu],
					"kind": "%s>%s" % [tag, ttag]})


# ---------------------------------------------------------------- the checks
## A place's centre and motion at t, from the layout's own Body (not
## MapGravity's copy of it): [x, z, vx, vz]. A belt's place is the point its
## beacon rides, round its host as the Body's is.
static func centre(L: SystemLayout, p: int, t: float) -> PackedFloat64Array:
	if p >= 0:
		var b := L.bodies[p]
		var at := b.point3(t)
		var a := b.phase + t / b.period * TAU
		var n := TAU / b.period
		return PackedFloat64Array([at.x, at.z, -b.orbit * n * sin(a), b.orbit * n * cos(a)])
	var sp := L.star_pos(p)
	return PackedFloat64Array([sp.x, sp.y, 0.0, 0.0])


## The centre and motion of the ring a case leaves from: its place's, or a
## settled star orbit's fixed point. [x, z, vx, vz]
static func dep_centre(c: Dictionary, t: float) -> PackedFloat64Array:
	var dep: Dictionary = c.dep
	if int(dep.get("place", -9)) == -9:
		var c9: Vector2 = dep.get("c", Vector2.ZERO)
		return PackedFloat64Array([c9.x, c9.y, 0.0, 0.0])
	return centre(c.L, int(dep.place), t)


## [start px off, start px/s off, end px off, end px/s off]: where the samples
## begin against the ship's ring (or state), and where they end against the
## target's ring at its speed (or its spot at its motion).
static func ends(c: Dictionary, r: FlightSolve.Result) -> PackedFloat64Array:
	var L: SystemLayout = c.L
	var dep: Dictionary = c.dep
	var tgt: Dictionary = c.tgt
	var s := r.samp
	var n := s.size() - 1
	var dt := r.sdt
	var v0 := (-3.0 * s[0] + 4.0 * s[1] - s[2]) / (2.0 * dt)
	var e0 := 0.0
	var ev0 := 0.0
	match StringName(dep.kind):
		&"ring":
			var cc := dep_centre(c, r.t0)
			var rt: float = dep.rt
			var w: float = dep.w
			var a := r.a_dep
			e0 = Vector2(s[0].x - (cc[0] + rt * cos(a)), s[0].z - (cc[1] + rt * sin(a))).length()
			ev0 = Vector2(v0.x - (cc[2] - w * rt * sin(a)), v0.z - (cc[3] + w * rt * cos(a))).length()
		&"keep":
			var ck := centre(L, int(dep.place), r.t0)
			var o: Vector2 = dep.off
			e0 = Vector2(s[0].x - ck[0] - o.x, s[0].z - ck[1] - o.y).length()
			ev0 = Vector2(v0.x - ck[2], v0.z - ck[3]).length()
		_:
			var p: Vector2 = dep.p
			var v: Vector2 = dep.v
			e0 = Vector2(s[0].x - p.x, s[0].z - p.y).length()
			ev0 = Vector2(v0.x - v.x, v0.z - v.y).length()
	var te: float = r.end.t
	var ct := centre(L, int(tgt.place), te)
	var vn := (3.0 * s[n] - 4.0 * s[n - 1] + s[n - 2]) / (2.0 * dt)
	var rel := Vector2(s[n].x - ct[0], s[n].z - ct[1])
	var e1 := 0.0
	var ev1 := 0.0
	if StringName(tgt.kind) == &"keep":
		var o2: Vector2 = tgt.off
		e1 = (rel - o2).length()
		ev1 = Vector2(vn.x - ct[2], vn.z - ct[3]).length()
	else:
		var R: float = tgt.R
		var V: float = tgt.V
		e1 = absf(rel.length() - R)
		var sn: float = r.end.sense
		var tg := Vector2(-rel.y, rel.x).normalized() * sn * V
		ev1 = Vector2(vn.x - ct[2] - tg.x, vn.z - ct[3] - tg.y).length()
	return PackedFloat64Array([e0, ev0, e1, ev1])


## The pull the samples show beyond gravity's, every SPAN samples: [the most
## in a burn, the most on the coast] (px/s^2).
static func thrust(c: Dictionary, r: FlightSolve.Result) -> PackedFloat64Array:
	var G: MapGravity = c.G
	var s := r.samp
	var dt := r.sdt * SPAN
	var burn := 0.0
	var coast := 0.0
	for k in range(SPAN, s.size() - SPAN, SPAN):
		var acc := (s[k + SPAN] - 2.0 * s[k] + s[k - SPAN]) / (dt * dt)
		var g := G.acc(s[k].x, s[k].z, r.t0 + k * r.sdt)
		var th := Vector2(acc.x - g[0], acc.z - g[1]).length()
		# (a burn's own edges smear over the span: read only well inside one)
		var lit := true
		for q in [k - SPAN, k, k + SPAN]:
			if r.burns[q] == 0:
				lit = false
		var dark := true
		for q2 in [k - SPAN, k, k + SPAN]:
			if r.burns[q2] == 1:
				dark = false
		if lit:
			burn = maxf(burn, th)
		elif dark:
			coast = maxf(coast, th)
	return PackedFloat64Array([burn, coast])


## WHETHER A BURN DRAWS A CUSP, from the samples (`FlightSolve.V_CUSP`): in
## any run of lit samples, the speed dipping under V_CUSP and 2 px/s under
## where the run starts and ends -- the motion swinging round a point, a sharp
## angle as drawn. [1 or 0, the least such speed].
static func cusp(r: FlightSolve.Result) -> PackedFloat64Array:
	var s := r.samp
	var dt := r.sdt
	var k := 1
	var n := s.size()
	var worst := INF
	while k < n - 1:
		if r.burns[k] == 0:
			k += 1
			continue
		var k0 := k
		var vmin := INF
		while k < n - 1 and r.burns[k] == 1:
			vmin = minf(vmin, ((s[k + 1] - s[k - 1]) / (2.0 * dt)).length())
			k += 1
		var va := ((s[mini(k0 + 1, n - 1)] - s[maxi(k0 - 1, 0)]) / (2.0 * dt)).length()
		var vb := ((s[mini(k, n - 1)] - s[maxi(k - 2, 0)]) / (2.0 * dt)).length()
		if vmin < FlightSolve.V_CUSP and vmin < minf(va, vb) - 2.0:
			worst = minf(worst, vmin)
	return PackedFloat64Array([1.0 if worst < INF else 0.0, worst])


## THE RIDE'S PHASING as `ShipFlight._step_phase` flies it: [its top push
## along the ring px/s^2, its top speed px/s] (0 and the ring's own when it
## simply rides).
static func ride(c: Dictionary, r: FlightSolve.Result) -> PackedFloat64Array:
	var dep: Dictionary = c.dep
	if StringName(dep.kind) != &"ring":
		return PackedFloat64Array([0.0, 0.0])
	var vr := absf(float(dep.w)) * float(dep.rt)
	if r.lead <= 1e-9:
		return PackedFloat64Array([0.0, vr])
	return PackedFloat64Array([vr * absf(r.lead_k - 1.0) * PI / r.lead, vr * maxf(r.lead_k, 1.0)])


func _report(sweep: String) -> void:
	var n := 0
	var found := 0
	var clean := 0
	var started := 0
	var landed := 0
	var ms: Array = []
	var work: Array = []
	var phw: Array = []
	var T: Array = []
	var integ: Array = []
	var phase := {"seed": [], "int": [], "price": [], "build": []}
	var burn_max: Array = []
	var coast_max: Array = []
	var push: Array = []
	var top_v: Array = []
	var ks: Array = []
	var d2k: Array = []
	var d2keep: Array = []
	var gap: Array = []
	var ngap := 0
	var nconst := 0
	var miss := {}
	var by := {}
	var worst_start := 0.0
	var worst_land := 0.0
	var worst_land_v := 0.0
	var pushed := 0
	var cusped := 0
	var cusped_free := 0
	var found_free := 0
	var shown := 0
	for i in _cases.size():
		var c: Dictionary = _cases[i]
		if c.sweep != sweep:
			continue
		n += 1
		var r: FlightSolve.Result = _res[i]
		if not by.has(c.kind):
			by[c.kind] = [0, 0]
		by[c.kind][0] += 1
		ms.append(r.usec / 1000.0)
		integ.append(float(r.integrations))
		phase.seed.append(r.us_seed / 1000.0)
		phase.int.append(r.us_int / 1000.0)
		phase.price.append(r.us_price / 1000.0)
		phase.build.append(r.us_build / 1000.0)
		if not r.found or not r.clean:
			miss[c.kind] = int(miss.get(c.kind, 0)) + 1
			if shown < 8 or (r.found and not r.clean):
				print("  (not found%s: %s, %d integrations)" % ["" if not r.found else " clean (%.2f px inside)" % -r.clear, c.label, r.integrations])
				shown += 1
			if not r.found:
				continue
		found += 1
		if r.clean:
			clean += 1
			by[c.kind][1] += 1
		var e := ends(c, r)
		worst_start = maxf(worst_start, maxf(e[0] / START_PX, e[1] / START_V))
		worst_land = maxf(worst_land, e[2])
		worst_land_v = maxf(worst_land_v, e[3])
		if e[0] <= START_PX and e[1] <= START_V:
			started += 1
		elif started + 3 > found:
			print("  (starts %.3f px, %.2f px/s off: %s)" % [e[0], e[1], c.label])
		if e[2] <= LAND_PX and e[3] <= LAND_V:
			landed += 1
		else:
			print("  (lands %.3f px, %.2f px/s off: %s)" % [e[2], e[3], c.label])
		# (a free start, coasting at 10 to 40 px/s, is a harness's: the map flies
		# only out of a ring, a settled star orbit or alongside, `can_fly`, and
		# the solver turns down a cusp only from those; counted apart)
		var cu := cusp(r)
		var free_dep := StringName(c.dep.kind) == &"free"
		if free_dep:
			found_free += 1
		if cu[0] > 0.5 and free_dep:
			cusped_free += 1
		elif cu[0] > 0.5:
			cusped += 1
			if cusped <= 4:
				print("  (a burn's speed dips to %.1f px/s: %s)" % [cu[1], c.label])
		var rd := ride(c, r)
		if StringName(c.dep.kind) == &"ring":
			push.append(rd[0])
			top_v.append(rd[1])
			ks.append(r.lead_k)
			if rd[0] <= FlightSolve.THRUST + 1e-6 and rd[1] <= FlightSolve.VMAX + 1e-6:
				pushed += 1
		else:
			pushed += 1
		if r.dv2 > 1.0:
			# (a constant burn at THRUST: 1; longer where gravity's change cut its
			# pull; the cubic's three times when it pulls against itself first)
			if StringName(c.tgt.kind) == &"ring":
				d2k.append(r.d2 * FlightSolve.THRUST / r.dv2)
				if r.arr_const:
					nconst += 1
			else:
				d2keep.append(r.d2 * FlightSolve.THRUST / r.dv2)
		if r.found and r.clean:
			work.append(r.work)
			phw.append(r.dvp)
			T.append(r.T)
			gap.append(r.cost - r.priced)
			if absf(r.cost - r.priced) > 2.0 and ngap < 4:
				ngap += 1
				print("  (built at %.2f, priced at %.2f, arrival %s, d2 %.2f dv2 %.1f: %s)" % [r.cost, r.priced, "constant" if r.arr_const else "cubic", r.d2, r.dv2, c.label])
		if i % 3 == 0:
			var th := thrust(c, r)
			burn_max.append(th[0])
			coast_max.append(th[1])
	if n == 0:
		return
	var keys := by.keys()
	keys.sort()
	var line := ""
	for k in keys:
		line += " %s %d/%d" % [k, by[k][1], by[k][0]]
	print("%s: %d plans; found and clean %d (%.2f%%), found %d" % [sweep, n, clean, 100.0 * clean / n, found])
	print("  by start>target:%s" % line)
	print("  planning ms     %s" % _dist(ms))
	print("  integrations    %s" % _dist(integ))
	print("  of which ms: conics %s | integrating %s | pricing %s | samples %s" % [_med(phase.seed), _med(phase.int), _med(phase.price), _med(phase.build)])
	print("  engine work px/s %s" % _dist(work))
	print("    of it phasing  %s" % _dist(phw))
	print("  flight time s   %s" % _dist(T))
	print("  built cost minus priced %s" % _dist(gap))
	print("  burn pull px/s2 %s (THRUST %.0f, from the samples; with gravity's own change across the burn)" % [_dist(burn_max), FlightSolve.THRUST])
	print("  coast pull px/s2 %s (beyond gravity: the drawn path's own error)" % _dist(coast_max))
	print("  arrival burn onto a ring: %d of %d constant; its length x THRUST / its work %s (1: at THRUST)" % [nconst, d2k.size(), _dist(d2k)])
	print("  arrival burn alongside: its length x THRUST / its work %s (about 3: it pulls against itself first)" % _dist(d2keep))
	var leads: Array = []
	for i in _cases.size():
		if _cases[i].sweep == sweep and _res[i].found and StringName(_cases[i].dep.kind) == &"ring":
			leads.append(_res[i].lead)
	print("  ride s %s" % _dist(leads))
	print("  ride: phasing k %s; push along the ring px/s2 %s; top speed px/s %s" % [_dist(ks), _dist(push), _dist(top_v)])
	print("  worst start %.3f of its tolerance; worst landing %.4f px, %.4f px/s" % [worst_start, worst_land, worst_land_v])
	var bar := FOUND_MIN_HAND if sweep == "twin" else FOUND_MIN
	h._ok("%s: found and clean in at least %.0f%% (%.2f%%)" % [sweep, 100.0 * bar, 100.0 * clean / n], clean >= bar * n)
	h._ok("%s: every found plan starts on the ship's ring (%d of %d)" % [sweep, started, found], started == found)
	h._ok("%s: every found plan lands on the ring at its speed within %.1f px, %.1f px/s, where the layout's Body is (%d of %d)" % [sweep, LAND_PX, LAND_V, landed, found], landed == found)
	h._ok("%s: every ride's phasing pushes at most THRUST and stays under VMAX (%d of %d)" % [sweep, pushed, found], pushed == found)
	h._ok("%s: no burn swings the ship round a point, its speed under %.0f px/s mid-burn (a cusp as drawn), out of a ring, a settled star orbit or alongside: %d of %d" % [sweep, FlightSolve.V_CUSP, cusped, found - found_free], cusped == 0)
	print("  %s: free starts (a harness's) with such a burn: %d of %d" % [sweep, cusped_free, found_free])
	ms.sort()
	var med: float = ms[ms.size() / 2]
	var worst: float = ms[-1]
	print("  TIMING %s: median %.1f ms (DESIGN 25), worst %.1f ms (DESIGN 150): %s" % [sweep, med, worst,
		"meets both" if med <= 25.0 and worst <= 150.0 else ("median meets, worst over: plan on a worker" if med <= 25.0 else "over: plan on a worker")])


static func _med(xs: Array) -> String:
	if xs.is_empty():
		return "-"
	var s := xs.duplicate()
	s.sort()
	return "median %.2f p90 %.2f" % [float(s[s.size() / 2]), float(s[mini(s.size() - 1, int(0.9 * s.size()))])]


static func _dist(xs: Array) -> String:
	if xs.is_empty():
		return "(none)"
	var s := xs.duplicate()
	s.sort()
	var q := func(p: float) -> float: return float(s[mini(s.size() - 1, int(p * s.size()))])
	return "median %.2f  p90 %.2f  p99 %.2f  max %.2f  (n %d)" % [q.call(0.5), q.call(0.9), q.call(0.99), float(s[-1]), s.size()]


## REBUILT FROM ITS OWN CHOICE: every 5th found plan, at once; round a ring
## (its departure still 0.6 s or more ahead, not phasing) half a second on with
## the ship ridden on round; alongside, half a second on (the ship holding
## there): the very same samples.
func _replays() -> void:
	var n := 0
	var same := 0
	var later := 0
	var later_same := 0
	var kept := 0
	var kept_same := 0
	for i in range(0, _cases.size(), 5):
		var r: FlightSolve.Result = _res[i]
		if not r.found:
			continue
		var c: Dictionary = _cases[i]
		n += 1
		var r2 := FlightSolve.solve(c.G, c.dep, c.tgt, float(c.t), r.choice)
		if r2.kind == &"replay" and r2.samp == r.samp and r2.end.t == r.end.t and r2.burns == r.burns:
			same += 1
		elif n - same <= 3:
			print("  (replay %s: %s)" % [r2.kind, c.label])
		var dep: Dictionary = c.dep
		if StringName(dep.kind) == &"ring" and r.lead >= 0.6 and r.lead_k <= 1.0:
			later += 1
			var d2 := dep.duplicate()
			d2.ang = float(dep.ang) + float(dep.w) * 0.5
			var r3 := FlightSolve.solve(c.G, d2, c.tgt, float(c.t) + 0.5, r.choice)
			if r3.kind == &"replay" and r3.samp == r.samp:
				later_same += 1
			elif later - later_same <= 3:
				print("  (replay half a second on %s: %s)" % [r3.kind, c.label])
		if StringName(dep.kind) == &"keep":
			kept += 1
			var r4 := FlightSolve.solve(c.G, dep, c.tgt, float(c.t) + 0.5, r.choice)
			if r4.kind == &"replay" and r4.samp == r.samp and r4.t0 == r.t0:
				kept_same += 1
			elif kept - kept_same <= 3:
				print("  (alongside, half a second on %s: %s)" % [r4.kind, c.label])
	h._ok("a plan rebuilt from its choice is the same flight (%d of %d)" % [same, n], same == n)
	h._ok("and half a second on, the ship ridden round (%d of %d)" % [later_same, later], later_same == later)
	h._ok("and half a second on alongside, the ship holding there (%d of %d)" % [kept_same, kept], kept_same == kept)


## THE PREVIEW IN ORBIT, PLANNED AGAIN 3 s ON WITH ITS OLD CHOICE (the overlay
## does this every 3 s): every 7th found ring plan, the ship ridden on round.
## Its departure has often gone by, and on a ring of over about 50 px the ride
## no longer reaches it, so the old choice is warm-started (the first build's
## SCRIPT ERROR was here). Every one must be found where a fresh search finds
## one, and a flight kept warm may cost no more than a fresh search's plus the
## warm slack, or than its own old cost plus the slack. (One still ahead is
## rebuilt as drawn, its ride phasing harder over the lead left, within THRUST:
## the drawn flight is the flown one, at up to about 22 px/s more.)
func _replans() -> void:
	var n := 0
	var ok := 0
	var fresh_found := 0
	var kinds := {}
	var over: Array = []
	var bad := 0
	for i in range(0, _cases.size(), 7):
		var r: FlightSolve.Result = _res[i]
		var c: Dictionary = _cases[i]
		if not r.found or StringName(c.dep.kind) != &"ring":
			continue
		var d2: Dictionary = c.dep.duplicate()
		d2.ang = float(c.dep.ang) + float(c.dep.w) * 3.0
		var t2 := float(c.t) + 3.0
		var rw := FlightSolve.solve(c.G, d2, c.tgt, t2, r.choice)
		var rf := FlightSolve.solve(c.G, d2, c.tgt, t2)
		n += 1
		kinds[rw.kind] = int(kinds.get(rw.kind, 0)) + 1
		if rf.found:
			fresh_found += 1
			if rw.found:
				ok += 1
		if rw.found and rf.found and rw.kind == &"warm":
			over.append(rw.cost - rf.cost)
			var j_old := float(r.choice.get("J", INF))
			if rw.cost > rf.cost + FlightSolve._warm_slack(rf.cost) + 1e-6 and rw.cost > j_old + FlightSolve._warm_slack(j_old) + 1e-6:
				bad += 1
				if bad <= 3:
					print("  (kept %.1f against fresh %.1f, old %.1f: %s)" % [rw.cost, rf.cost, j_old, c.label])
	print("replans: %d previews planned again 3 s on with their old choice: %s; kept warm, cost minus a fresh search's %s" % [n, kinds, _dist(over)])
	h._ok("planned again 3 s on, found wherever a fresh search finds one (%d of %d)" % [ok, fresh_found], ok >= fresh_found - maxi(1, fresh_found / 100))
	h._ok("and no kept flight past the warm slack of both a fresh search and its own old cost (%d)" % bad, bad == 0)


## THE PHYSICS: a sample of found plans flown again by plain RK4 at SAMPLE
## through `MapGravity.acc` (the departure burn along the plan's own, then
## coasting) up to its arrival burn; the most the samples stray from it.
func _physics() -> void:
	var worst := 0.0
	var worst_at := ""
	var devs: Array = []
	var n := 0
	for i in range(0, _cases.size(), 41):
		var r: FlightSolve.Result = _res[i]
		if not r.found:
			continue
		var c: Dictionary = _cases[i]
		var G: MapGravity = c.G
		var s := r.samp
		var dt := r.sdt
		var st := start_state(c, r)
		var x := st[0]
		var z := st[1]
		var vx := st[2]
		var vz := st[3]
		var dvx := float(r.choice.dvx)
		var dvz := float(r.choice.dvz)
		var dv := sqrt(dvx * dvx + dvz * dvz)
		var bux := dvx / dv if dv > 1e-9 else 0.0
		var buz := dvz / dv if dv > 1e-9 else 0.0
		# THE DEPARTURE BURN by its own law, from this flight's own state: a pull
		# held for each step of at most H_BURN, eased out of a settled star orbit
		# while the ship is slow (`FlightSolve.R_BURN`), until dv is spent
		var ease := StringName(c.dep.kind) == &"ring" and int(c.dep.place) == -9
		var rem := dv if dv > 1e-9 else 0.0
		var pull := 0.0
		var t := r.t0
		var t_step := t
		var tb := r.t0 + r.dur - r.d2
		var dev := 0.0
		var k := 0
		while t + dt <= tb and k + 1 < s.size():
			var left := dt
			while left > 1e-12:
				var hp := left
				var ax := 0.0
				var az := 0.0
				if rem > 0.0 or t < t_step - 1e-12:
					if t >= t_step - 1e-12:
						pull = FlightSolve.THRUST
						if ease:
							pull = clampf((vx * vx + vz * vz) / FlightSolve.R_BURN, FlightSolve.P_MIN, FlightSolve.THRUST)
						var hb := minf(FlightSolve.H_BURN, rem / pull)
						rem -= pull * hb
						if rem <= 1e-9:
							rem = 0.0
						t_step = t + hb
					hp = minf(left, t_step - t)
					ax = bux * pull
					az = buz * pull
				var st2 := _rk4(G, x, z, vx, vz, t, hp, ax, az)
				x = st2[0]
				z = st2[1]
				vx = st2[2]
				vz = st2[3]
				t += hp
				left -= hp
			k += 1
			dev = maxf(dev, Vector2(x - s[k].x, z - s[k].z).length())
		devs.append(dev)
		n += 1
		if dev > worst:
			worst = dev
			worst_at = c.label
	print("physics: %d plans flown again at SAMPLE by plain RK4: samples off it %s px; worst at %s" % [n, _dist(devs), worst_at])
	h._ok("the drawn coast follows the physics within 1 px (worst %.3f px)" % worst, worst < 1.0)


static func _rk4(G: MapGravity, x: float, z: float, vx: float, vz: float, t: float, dt: float, ax: float, az: float) -> PackedFloat64Array:
	var g1 := G.acc(x, z, t)
	var a1x := g1[0] + ax
	var a1z := g1[1] + az
	var v2x := vx + 0.5 * dt * a1x
	var v2z := vz + 0.5 * dt * a1z
	var g2 := G.acc(x + 0.5 * dt * vx, z + 0.5 * dt * vz, t + 0.5 * dt)
	var a2x := g2[0] + ax
	var a2z := g2[1] + az
	var v3x := vx + 0.5 * dt * a2x
	var v3z := vz + 0.5 * dt * a2z
	var g3 := G.acc(x + 0.5 * dt * v2x, z + 0.5 * dt * v2z, t + 0.5 * dt)
	var a3x := g3[0] + ax
	var a3z := g3[1] + az
	var v4x := vx + dt * a3x
	var v4z := vz + dt * a3z
	var g4 := G.acc(x + dt * v3x, z + dt * v3z, t + dt)
	var a4x := g4[0] + ax
	var a4z := g4[1] + az
	return PackedFloat64Array([x + dt / 6.0 * (vx + 2.0 * v2x + 2.0 * v3x + v4x), z + dt / 6.0 * (vz + 2.0 * v2z + 2.0 * v3z + v4z),
		vx + dt / 6.0 * (a1x + 2.0 * a2x + 2.0 * a3x + a4x), vz + dt / 6.0 * (a1z + 2.0 * a2z + 2.0 * a3z + a4z)])


## Where and how the ship leaves, exactly (not from 32-bit samples): on its
## ring at the plan's departure angle, alongside, or free. [x, z, vx, vz]
static func start_state(c: Dictionary, r: FlightSolve.Result) -> PackedFloat64Array:
	var L: SystemLayout = c.L
	var dep: Dictionary = c.dep
	match StringName(dep.kind):
		&"ring":
			var cc := dep_centre(c, r.t0)
			var rt: float = dep.rt
			var w: float = dep.w
			var a := r.a_dep
			return PackedFloat64Array([cc[0] + rt * cos(a), cc[1] + rt * sin(a), cc[2] - w * rt * sin(a), cc[3] + w * rt * cos(a)])
		&"keep":
			var ck := centre(L, int(dep.place), r.t0)
			var o: Vector2 = dep.off
			return PackedFloat64Array([ck[0] + o.x, ck[1] + o.y, ck[2], ck[3]])
	var p: Vector2 = dep.p
	var v: Vector2 = dep.v
	return PackedFloat64Array([p.x, p.y, v.x, v.y])


## THE SAME ON A WORKER: the first `_worker_n` cases of each sweep solved again
## on WorkerThreadPool tasks, every result the same as on the main thread.
var _wres: Array = []
var _wlock := Mutex.new()
var _widx: Array = []


func _worker() -> void:
	if _worker_n <= 0:
		return
	_widx = []
	var per := {}
	for i in _cases.size():
		var sw: String = _cases[i].sweep
		if int(per.get(sw, 0)) < _worker_n:
			per[sw] = int(per.get(sw, 0)) + 1
			_widx.append(i)
	_wres = []
	_wres.resize(_widx.size())
	var t0 := Time.get_ticks_msec()
	var gid := WorkerThreadPool.add_group_task(_solve_on_worker, _widx.size(), -1, true, "FlightSolve")
	WorkerThreadPool.wait_for_group_task_completion(gid)
	var wall := Time.get_ticks_msec() - t0
	var same := 0
	var serial := 0.0
	for j in _widx.size():
		var r: FlightSolve.Result = _res[_widx[j]]
		var w: FlightSolve.Result = _wres[j]
		serial += r.usec / 1000.0
		if w != null and w.found == r.found and w.samp == r.samp and w.cost == r.cost and w.choice == r.choice:
			same += 1
		elif _widx.size() - same <= 3 + j - same:
			print("  (on a worker, not the same: %s)" % _cases[_widx[j]].label)
	print("worker: %d plans on WorkerThreadPool in %d ms of wall clock (%.0f ms planned one after another on the main thread)" % [_widx.size(), wall, serial])
	h._ok("a plan made on a worker is the same plan (%d of %d)" % [same, _widx.size()], same == _widx.size())


func _solve_on_worker(j: int) -> void:
	var c: Dictionary = _cases[_widx[j]]
	var r := FlightSolve.solve(c.G, c.dep, c.tgt, float(c.t))
	_wlock.lock()
	_wres[j] = r
	_wlock.unlock()


# ---------------------------------------------------------------- the prototype's flight
## WORLD a TO WORLD b at the prototype's best line-up (a at 4.5845 rad round A,
## b at 3.7905 round B at t 0, the ship leaving a's ring at 3.6115 clockwise):
## the prototype found it free in 9.2 s; and over 12 line-ups (the worlds'
## places and the ship's turned by golden-angle steps) against its typical
## 3.6 px/s (a 60 s cap's figure, an upper bound).
func _prototype() -> void:
	var L := twin_layout(280.0)
	var G := MapGravity.from_layout(L)
	var tgt := {"kind": &"ring", "place": 1, "R": L.bodies[1].soi, "V": RAIL_V, "sense": 0}
	var w := -RAIL_V / L.bodies[0].soi
	for before: float in [0.05, 0.4, 1.0]:
		var dep := {"kind": &"ring", "place": 0, "rt": L.bodies[0].soi, "ang": 3.6115208250617648 - w / absf(w) * before, "w": w}
		var r := FlightSolve.solve(G, dep, tgt, 0.0)
		print("prototype a to b, best line-up, the ship %.2f rad before its point: %s" % [before,
			"engine work %.2f px/s (phasing %.2f, leaving %.2f, arriving %.2f) in %.2f s (ride %.2f s), %d integrations, %.1f ms" % [r.work, r.dvp, r.dv1, r.dv2, r.T, r.lead, r.integrations, r.usec / 1000.0] if r.found else "none found"])
		if before == 0.05:
			h._ok("prototype a to b at its best line-up: found, clean, within 3 px/s of free (%.2f) and 9.2 s +- 3 (%.1f)" % [r.work, r.T],
				r.found and r.clean and r.work < 3.0 and absf(r.T - 9.2) < 3.0)
	var works: Array = []
	var Ts: Array = []
	for lu in 12:
		var Lx := twin_layout(280.0, fposmod(4.5845 + 2.39996 * lu, TAU), fposmod(3.7905 + 1.3 * lu, TAU))
		var Gx := MapGravity.from_layout(Lx)
		var dep2 := {"kind": &"ring", "place": 0, "rt": Lx.bodies[0].soi, "ang": fposmod(0.7 * lu, TAU), "w": (-1.0 if lu % 2 == 0 else 1.0) * RAIL_V / Lx.bodies[0].soi}
		var r2 := FlightSolve.solve(Gx, dep2, {"kind": &"ring", "place": 1, "R": Lx.bodies[1].soi, "V": RAIL_V, "sense": 0}, 0.0)
		if r2.found:
			works.append(r2.work)
			Ts.append(r2.T)
	print("prototype a to b over 12 line-ups: found %d; engine work %s; time %s (prototype typical 3.6 px/s)" % [works.size(), _dist(works), _dist(Ts)])


# ---------------------------------------------------------------- the cost of a step
## THE PLANNER'S OWN COST on this machine: 40 flights of a one-star system's
## 30 s coast, timed; what one RK4 step costs.
func _bench() -> void:
	var G := MapGravity.new()
	G.add_star(-1, 0.0, 0.0, SystemLayout.GM_SHIP, 48.0)
	G.add_place(0.0, 0.0, 300.0, 4200.0, 0.0)
	G.add_place(0.0, 0.0, 600.0, 11000.0, 2.0)
	var fs := FlightSolve.new()
	fs.G = G
	fs.t_now = 0.0
	var t0 := Time.get_ticks_usec()
	var steps0 := fs._n_steps
	for i in 40:
		fs._integrate(0.0, 300.0, 0.0, 0.0, 26.0 + 0.1 * i, 3.0, 0.0, FlightSolve.T_CAP)
	var us := Time.get_ticks_usec() - t0
	var steps := fs._n_steps - steps0
	print("bench: 40 coasts of 30 s round one star, %d RK4 steps, %.2f ms each, %.2f us a step" % [steps, us / 40000.0, float(us) / maxf(1.0, steps)])
	var G2 := MapGravity.new()
	G2.add_star(-1, 0.0, 0.0, SystemLayout.GM_SHIP * 0.55, 39.0)
	G2.add_star(-4, 280.0, 0.0, SystemLayout.GM_SHIP * 0.45, 38.0)
	G2.add_giant(0, 126.0, 0.0, 700.0, 18000.0, 1.0, 0.25 * SystemLayout.GM_SHIP, 20.0)
	var fs2 := FlightSolve.new()
	fs2.G = G2
	t0 = Time.get_ticks_usec()
	steps0 = fs2._n_steps
	for i in 40:
		fs2._integrate(0.0, 0.0, 300.0, 30.0 + 0.1 * i, 0.0, 0.0, 3.0, FlightSolve.T_CAP)
	us = Time.get_ticks_usec() - t0
	steps = fs2._n_steps - steps0
	print("bench: 40 coasts through two stars and a giant, %d RK4 steps, %.2f ms each, %.2f us a step" % [steps, us / 40000.0, float(us) / maxf(1.0, steps)])
