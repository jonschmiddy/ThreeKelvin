extends Node

## Autopilot flights are planned and measured in sweeps. The flags and checks are in the doc.
## PASS needs 99% found and clean per sweep, 97% for hand twins the layout never builds.
## Why: docs/why/SolveTest.md#solve-sweeps

const SEEDS := [4242, 7, 1999, 31337]
const LAND_PX := 0.5
const LAND_V := 0.5
const START_PX := 0.05
const START_V := 0.5
## How far inside a keep-out samples may pass, read at each sample's own time (review 2).
const IN_PX := 1.0
## the samples the pull is read over (finite differences): 4 apart
const SPAN := 4
const RAIL_V := 35.0
const STAR_RAIL_V := 45.0
const ORBIT_K := ShipFlightS.ORBIT_K
## A settled star orbit's pace, times Kepler's.
const STAR_PACE := ShipFlightS.STAR_PACE
const KEEP_OFF := Vector2(8.0, 5.0 / 0.38)
## In `short`, only two pairs and fewer angles: the full sweep took the gate from 170 s to 370 s.
## Why: docs/why/SolveTest.md#phase-sweep
const PHASES := 8
const PHASES_SHORT := 4
## found and clean in at least this share of each sweep (above)
const FOUND_MIN := 0.99
const FOUND_MIN_HAND := 0.97
## how many times each flight in two legs is planned again (`_replans`)
const TWO_STEPS := 5
## Real-twin flights planned again in two legs: 9875260b went to one leg, later than a fresh two.
## The misses were 16.0 s and 6.6 s.
## Why: docs/why/SolveTest.md#two-leg-replans
const TWO_PINS := [
	["seed 31337 node 3 ", "ring 1", "keep 3", 6],
	["seed 31337 node 28 ", "ring 1", "keep 5", 10],
]

const ShipFlightS := preload("res://scripts/ui/sysmap/ShipFlight.gd")
## CURVED's median bend against DIRECT's, at the least (both run)
const BEND_MARGIN := 2.0
## a flight that strays more than this share of its own chord is a loop (counted)
const LOOP_BEND := 0.5
## the paths asked for, and the pace each flies at (`_ready`)
var _paths: Array[StringName] = [&"direct", &"curved"]
var _pace := {}

var h := Harness.new()
var _per_seed := 4
var _lineups := 12
var _twins := 2
var _twin_lineups := 6
var _worker_n := 400
var _only := ""
## the gate's run (`short`)
var _short := false
## where each found, clean flight's shape is written, one JSON line a flight
## (`shapes=path`: its sweep, path, bend, turn, flight seconds in tau and the
## pace), so a run's shards can be pooled
var _shapes_out := ""
## every case: {sweep, L, G, dep, tgt, t, label, kind, hand}
var _cases: Array = []
## How many sweeps judged at least one plan.
var _swept := 0
var _res: Array = []
## cases past the line-ups asked for, planned only for the replan check of
## flights in two legs (`TWO_PINS`, `_replans`)
var _pin_cases: Array = []


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
		elif s.begins_with("path="):
			var pv := s.substr(5)
			if pv == "direct" or pv == "curved":
				_paths = [StringName(pv)]
		elif s.begins_with("pace="):
			_pace["all"] = float(s.substr(5))
		elif s.begins_with("shapes="):
			_shapes_out = s.substr(7)
		elif s == "short":
			_short = true
			_per_seed = 1
			_lineups = 4
			_twins = 1
			_twin_lineups = 3
			_worker_n = 100
	_run.call_deferred()


func _wants(sweep: String) -> bool:
	return _only == "" or _only == sweep


## The pace path p's flights are planned at in this run.
func _pace_of(p: StringName) -> float:
	return float(_pace.get("all", ShipFlightS.FLIGHT_PACE[p]))


## A sweep's name for path p: as it was for DIRECT, " curved" after it for CURVED.
static func sw_name(sweep: String, p: StringName) -> String:
	return sweep if p == &"direct" else sweep + " curved"


## (`FlightSolve.shape_of`)
static func shape_of(samp: PackedVector3Array) -> PackedFloat64Array:
	return FlightSolve.shape_of(samp)

func _run() -> void:
	await get_tree().process_frame
	var t_all := Time.get_ticks_msec()
	if h.mine(0):
		_bench()
	if _wants("proto") and h.mine(0):
		_prototype()
	if _wants("one") or _wants("giant") or _wants("rtwin") or _wants("rclose"):
		_real_cases()
	if _wants("twin"):
		_twin_cases()
	if _wants("phase"):
		_phase_cases()
	# (the paths' cases one after the other, each path's in its own order: made
	# path by path for each line-up, a shard of 2 or 4 took every DIRECT case or
	# every CURVED one, and the shards' sums and the bend's comparison lost a
	# path each)
	if _paths.size() > 1:
		var by_path: Array = []
		for p0 in _paths:
			by_path.append_array(_cases.filter(func(c: Dictionary) -> bool: return StringName(c.path) == p0))
		_cases = by_path
	print("solvetest: %d cases" % _cases.size())
	# every case, on the main thread (this shard's: the others' are null)
	var n_mine := 0
	for i in _cases.size():
		if not h.mine(i):
			_res.append(null)
			continue
		n_mine += 1
		var c: Dictionary = _cases[i]
		var r := FlightSolve.solve(c.G, c.dep, c.tgt, float(c.t), {}, c.opts)
		_res.append(r)
	for p in _paths:
		for sw: String in ["one", "giant", "rtwin", "rclose", "twin"]:
			_report(sw_name(sw, p))
		_report(sw_name("phase", p))
	# (a shard may hold no case of one sweep; it holds none at all only when it is numbered past the case count)
	var sh := Harness.shard()
	h._ok("the sweeps judged plans where the shard arithmetic says there are some (%d sweeps, %d of %d cases here, shard %d of %d)" % [
		_swept, n_mine, _cases.size(), sh.x, maxi(sh.y, 1)], (_swept > 0) == (_cases.size() >= maxi(sh.x, 1)))
	_shapes()
	if (_wants("phase") or _wants("twin")) and h.mine(0):
		_aim_check()
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
	h.shard_end("solvetest", n_mine, _cases.size())
	h.verdict("solvetest")
	get_tree().quit(h.code())


# ---------------------------------------------------------------- the systems
# Real systems per seed, giants first: the one-star sweeps and the two-star `rtwin` layouts.
func _real_cases() -> void:
	for sd: int in SEEDS:
		Rng.forced = sd
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
		var withg: Array = []
		var without: Array = []
		var twins: Array = []
		var closes: Array = []
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
				# (each kind laid out on purpose: the kind is rolled, `is_close`)
				var was := n.twin
				n.twin = true
				SystemLayout.close_force = -1
				var L2 := SystemLayout.of(n)
				SystemLayout.close_force = 1
				var L4 := SystemLayout.of(n)
				SystemLayout.close_force = 0
				n.twin = was
				if L2.twin:
					twins.append([n.index, L2])
				if L4.close:
					closes.append([n.index, L4])
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
		for kind: Array in [["rtwin", twins, ""], ["rclose", closes, "close, "]]:
			var rows: Array = kind[1]
			if not _wants(String(kind[0])):
				continue
			rows.sort_custom(func(a: Array, b: Array) -> bool:
				var la: SystemLayout = a[1]
				var lb: SystemLayout = b[1]
				return la.bodies.size() > lb.bodies.size() or (la.bodies.size() == lb.bodies.size() and int(a[0]) < int(b[0])))
			for row in rows.slice(0, _twins):
				var Lt: SystemLayout = row[1]
				var gi := ""
				for b in Lt.bodies:
					if b.gm > 0.0:
						gi = ", giant %.2f" % b.gm_frac
				var lab := "seed %d node %d (%s%d bodies, share %.3f, sep %.0f%s)" % [sd, int(row[0]), kind[2], Lt.bodies.size(), Lt.star_share, Lt.sep, gi]
				_add_system(String(kind[0]), Lt, MapGravity.from_layout(Lt), lab, false)


## The prototype's geometry scaled to `sep`, with each star's ladder as `_twin_ladder` sets it.
## Why: docs/why/SolveTest.md#hand-twins
static func twin_layout(sep: float, pha: float = 4.584536085992015, phb: float = 3.7905025599699775, phc: float = 0.0) -> SystemLayout:
	var L := SystemLayout.new()
	var share := 0.55
	L.twin = true
	L.star = SystemLayout.StarKind.ORDINARY
	L.star_r = 16.0
	L.star2 = SystemLayout.StarKind.ORDINARY
	L.star2_r = 16.0 * pow((1.0 - share) / share, 0.8)
	L.star2_at0 = Vector2(sep, 0.0)
	L.star_share = share
	L.sep = sep
	L.bary = Vector2((1.0 - share) * sep, 0.0)
	var k := sep / 280.0
	var a_orb := 80.0 * k
	var b_orb := 70.0 * k
	var c_orb := 680.0 * k
	L.edge = maxf(SystemLayout.HI, L.bary.x + c_orb + 9.0) + 30.0
	var specs := [["a", Vector2.ZERO, -1, a_orb, share, 3.0, 0.0, pha],
		["b", L.star2_at0, SystemLayout.STAR_B, b_orb, 1.0 - share, 3.0, 0.0, phb],
		["c", L.bary, -9, c_orb, 1.0, 9.0, (70.4 / 1.6 - 24.0) / 2.4, phc]]
	for i in specs.size():
		var sp: Array = specs[i]
		var b := SystemLayout.Body.new()
		b.kind = &"planet"
		b.world = &"rock"
		b.index = i
		b.name = "twin %s" % sp[0]
		b.host0 = sp[1]
		b.host_id = sp[2]
		b.orbit = sp[3]
		# (the prototype's own geometry at the old pace of 1: built by hand, as it was flown)
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
	# The pair turns as a laid-out one does (ruling 23). `-- pair=0` gives the old figures.
	SystemLayout.spin_pair(L)
	return L


func _twin_cases() -> void:
	for sep: float in [280.0, 300.0, 380.0]:
		var L := twin_layout(sep)
		_add_system("twin", L, MapGravity.from_layout(L), "twin %.0f" % sep, true)


## Busiest pair of that kind per seed, at PHASES map times a lap apart. Held still, there is no lap.
func _phase_cases() -> void:
	var phases := PHASES_SHORT if _short else PHASES
	for pick: Array in ([[7, 1], [4242, -1]] if _short else [[7, 1], [7, -1], [4242, -1]]):
		var sd: int = pick[0]
		Rng.forced = sd
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
		var best: SystemLayout = null
		var best_n := -1
		var best_i := -1
		for raw in Run.map:
			var n: MapGen.MapNode = raw
			if n.type != MapGen.NodeType.SYSTEM:
				continue
			OptionTable.ensure(n)
			var was := n.twin
			n.twin = true
			SystemLayout.close_force = int(pick[1])
			var L := SystemLayout.of(n)
			SystemLayout.close_force = 0
			n.twin = was
			if not L.twin or L.close != (int(pick[1]) == 1):
				continue
			if L.bodies.size() > best_n:
				best = L
				best_i = n.index
				best_n = L.bodies.size()
		if best == null:
			print("phase: seed %d laid out no %s pair: not swept" % [sd, "close" if int(pick[1]) == 1 else "wide"])
			continue
		var times: Array = []
		var lap := TAU / absf(best.pair_n) if best.pair_n != 0.0 else 0.0
		for j in phases:
			times.append(40.0 + (lap * float(j) / float(phases) if lap > 0.0 else 37.0 * float(j)))
		var lab := "seed %d node %d (%s pair, %d bodies, sep %.0f, lap %.0f s)" % [sd, best_i, "close" if best.close else "wide", best.bodies.size(), best.sep, lap]
		print("phase: %s, at %d angles round its lap%s" % [lab, phases, "" if lap > 0.0 else " (held still: line-ups 37 s apart)"])
		_add_system("phase", best, MapGravity.from_layout(best), lab, false, times, true)


## As `ShipFlight._dep_of` hands it over: a -9 circle hosted by the sun, riding with a turning one.
## Why: docs/why/SolveTest.md#settled-orbit
func _settled_round(L: SystemLayout, G: MapGravity, st: Array, t: float, lu: int, si: int, ti: int) -> Dictionary:
	if st[0] != "orbitS" or not L.twin:
		return {}
	var hp := int(st[1])
	var share := L.star_share if hp == -1 else 1.0 - L.star_share
	var lo := FlightSolve.star_orbit_r(L, hp) + 12.0
	var hi := 0.9 * SystemLayout.s_limit(1.0 - share) * L.sep
	if hi <= lo + 4.0:
		return {}
	var r := lerpf(lo, hi, fposmod(float(lu) * 0.618034 + 0.3 * float(si), 1.0))
	var cs := L.star_pos(hp, t)
	var a := fposmod(2.39996 * float(lu) + 1.1 * float(si) + 0.7 * float(ti), TAU)
	var ok := false
	for _k in 42:
		var q := cs + Vector2(cos(a), sin(a)) * r
		if G.margin(q.x, q.y, t) > 10.0:
			ok = true
			break
		a += 0.15
	if not ok:
		return {}
	var pace := STAR_PACE * TAU * 1000.0 / (800.0 * sqrt(r)) * sqrt(share)
	return {"kind": &"ring", "place": -9, "c": cs, "host": hp, "rt": r, "ang": a, "w": pace / r}


## The conic aims at where star B is on its orbit then, not B's centre, which B has moved past.
func _aim_check() -> void:
	var L := twin_layout(300.0)
	var G := MapGravity.from_layout(L)
	if L.pair_n == 0.0:
		print("aim: the pair is held still (pair=0): not judged")
		return
	var t := 300.0
	var te := t + 12.0
	var R := FlightSolve.star_orbit_r(L, SystemLayout.STAR_B)
	var dep := {"kind": &"ring", "place": 0, "rt": ride_r(L, 0, true), "ang": 0.3, "w": RAIL_V / ride_r(L, 0, true)}
	var tgt := {"kind": &"ring", "place": SystemLayout.STAR_B, "R": R, "V": STAR_RAIL_V, "sense": 0}
	var fs := FlightSolve.new()
	fs.G = G
	fs.t_now = t
	var set_ok := fs._setup(dep, tgt)
	var kb := G.star_index(SystemLayout.STAR_B)
	var c0 := Vector2(G.sx(kb, t), G.sz(kb, t))
	var c1 := Vector2(G.sx(kb, te), G.sz(kb, te))
	var p1 := c0 + Vector2(-120.0, 30.0)
	var by_id := fs._aims(te, p1.x, p1.y, c0.x, c0.y, 1.0, kb)
	var by_place := fs._aims(te, p1.x, p1.y, c0.x, c0.y, 1.0, -1)
	# (in 64 bits: Vector2 is 32)
	var on := absf(sqrt(pow(by_id[0] - G.sx(kb, te), 2.0) + pow(by_id[1] - G.sz(kb, te), 2.0)) - R)
	var at_centre := sqrt(pow(by_place[0] - G.sx(kb, te), 2.0) + pow(by_place[1] - G.sz(kb, te), 2.0))
	print("aim: star B moves %.2f px in 12 s; aimed by index %.6f px off its close orbit then; asked by place, %.2f px from its centre" % [(c1 - c0).length(), on, at_centre])
	h._ok("a conic about a turning sun aims at its close orbit round where it will be, by the sun's index (%.6f px off; it moved %.2f px)" % [on, (c1 - c0).length()], set_ok and (c1 - c0).length() > 1.0 and on < 1e-6 and at_centre < 1e-6)


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


## (times: the map times to plan at, one line-up each, in place of the sweep's
## own line-ups; settled: also from a settled orbit round each sun of a twin)
func _add_system(sweep: String, L: SystemLayout, G: MapGravity, label: String, hand: bool, times: Array = [], settled: bool = false) -> void:
	var lineups := _twin_lineups if sweep == "rtwin" or sweep == "rclose" else _lineups
	if not times.is_empty():
		lineups = times.size()
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
	if settled and L.twin:
		for p in L.stars():
			starts.append(["orbitS", p])
	starts.append(["free", -9])
	for si in starts.size():
		var st: Array = starts[si]
		for ti in targets.size():
			var tg: Array = targets[ti]
			if st[1] == tg[1] and st[0] != "free" and st[0] != "orbitS":
				continue
			var lus: Array = range(lineups)
			if sweep == "rtwin":
				for pin: Array in TWO_PINS:
					if label.begins_with(pin[0]) and "%s %d" % [st[0], st[1]] == pin[1] and "%s %d" % [tg[0], tg[1]] == pin[2] and int(pin[3]) >= lineups:
						lus.append(int(pin[3]))
			for lu: int in lus:
				var t := 40.0 + 37.0 * float(lu)
				if not times.is_empty():
					t = float(times[lu])
				var orb_s := _settled_round(L, G, st, t, lu, si, ti)
				if st[0] == "orbitS" and orb_s.is_empty():
					continue
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
						# A settled orbit out where a visit arrives, paced STAR_PACE times Kepler.
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
					"orbitS":
						dep = orb_s
						dep.w = sense * float(dep.w)
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
				for pth in _paths:
					var k := _pace_of(pth)
					(_cases if lu < lineups else _pin_cases).append(_on_tau({"sweep": sw_name(sweep, pth), "base": sweep, "L": L, "G": G, "dep": dep, "tgt": tgt, "t": t, "hand": hand,
						"label": "%s%s: %s %d to %s %d, line-up %d" % [label, "" if pth == &"direct" else " (curved)", st[0], st[1], tg[0], tg[1], lu],
						"kind": "%s>%s" % [tag, ttag], "path": pth}, k))


## A CASE ON THE FLIGHT'S OWN CLOCK at pace k (`FlightSolve.solve` does this
## to a map case; done here so every check reads the flight in tau): its
## ring's or free start's speed / k, the target's ring speed / k, t x k, the
## system paced, the hold alongside as the game's (`FlightSolve.HOLD_MAP`);
## planned with opts {path} at pace 1 (it is in tau already).
func _on_tau(c: Dictionary, k: float) -> Dictionary:
	c.k = k
	c.opts = {"path": c.path}
	if k == 1.0:
		return c
	var d: Dictionary = FlightSolve.dep_tau(c.dep, k)
	d["_hold"] = maxf(FlightSolve.KEEP_HOLD, FlightSolve.HOLD_MAP * k)
	d["_pace"] = k
	var g: Dictionary = FlightSolve.tgt_tau(c.tgt, k)
	c.dep = d
	c.tgt = g
	c.t = float(c.t) * k
	c.G = (c.G as MapGravity).paced(k)
	return c


# ---------------------------------------------------------------- the checks
# From the layout's own Body, not MapGravity's copy. A belt's place is the point its beacon rides.
## On a flight's own clock (k, `_on_tau`): read at map time t / k, its motion / k.
static func centre(L: SystemLayout, p: int, t: float, k := 1.0) -> PackedFloat64Array:
	if k != 1.0:
		var m := centre(L, p, t / k)
		return PackedFloat64Array([m[0], m[1], m[2] / k, m[3] / k])
	if p >= 0:
		var b := L.bodies[p]
		var at := b.point3(t)
		var a := b.phase + t / b.period * TAU
		var n := TAU / b.period
		# (a world round one sun of a turning pair is carried with it)
		var hv := b.host_vel(t)
		return PackedFloat64Array([at.x, at.z, -b.orbit * n * sin(a) + hv.x, b.orbit * n * cos(a) + hv.y])
	var sp := L.star_pos(p, t)
	var sv := L.star_vel(p, t)
	return PackedFloat64Array([sp.x, sp.y, sv.x, sv.y])


## Centre and motion of the ring a case leaves from: place, settled star orbit, or host sun.
static func dep_centre(c: Dictionary, t: float) -> PackedFloat64Array:
	var dep: Dictionary = c.dep
	if int(dep.get("place", -9)) == -9 and dep.has("host"):
		return centre(c.L, int(dep.host), t, float(c.get("k", 1.0)))
	if int(dep.get("place", -9)) == -9:
		var c9: Vector2 = dep.get("c", Vector2.ZERO)
		return PackedFloat64Array([c9.x, c9.y, 0.0, 0.0])
	return centre(c.L, int(dep.place), t, float(c.get("k", 1.0)))


## Start offset against the ship's ring, end offset against the target's ring at its speed.
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
			var ck := centre(L, int(dep.place), r.t0, float(c.get("k", 1.0)))
			var o: Vector2 = dep.off
			e0 = Vector2(s[0].x - ck[0] - o.x, s[0].z - ck[1] - o.y).length()
			ev0 = Vector2(v0.x - ck[2], v0.z - ck[3]).length()
		_:
			var p: Vector2 = dep.p
			var v: Vector2 = dep.v
			e0 = Vector2(s[0].x - p.x, s[0].z - p.y).length()
			ev0 = Vector2(v0.x - v.x, v0.z - v.y).length()
	var te: float = r.end.t
	var ct := centre(L, int(tgt.place), te, float(c.get("k", 1.0)))
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


## A cusp is a speed dip under V_CUSP inside a lit run: motion swinging round a point.
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
		# (on a flight's own clock as on the map: a cusp is its turn radius,
		# v^2 / a, which the clock leaves as it is, `FlightSolve._vc`)
		if vmin < FlightSolve.V_CUSP and vmin < minf(va, vb) - 2.0:
			worst = minf(worst, vmin)
	return PackedFloat64Array([1.0 if worst < INF else 0.0, worst])


## The ride's phasing as `ShipFlight._step_phase` flies it: top push and top speed.
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
	var inside := 0
	var worst_in := INF
	for i in _cases.size():
		var c: Dictionary = _cases[i]
		if c.sweep != sweep or _res[i] == null:
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
			# Clean as MapGravity has it: start-read keep-outs passed 16 plans 9 px in.
			# Why: docs/why/SolveTest.md#clean-check
			var own := [int(c.dep.get("place", -9)), int(c.tgt.get("place", -9))]
			var mq := INF
			for kq in r.samp.size():
				mq = minf(mq, (c.G as MapGravity).margin_but(r.samp[kq].x, r.samp[kq].z, r.t0 + kq * r.sdt, own))
			worst_in = minf(worst_in, mq)
			if mq < -IN_PX:
				inside += 1
				if inside <= 4:
					print("  (clean, but %.2f px inside a keep-out at its samples' times: %s)" % [-mq, c.label])
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
		# Free starts are a harness's: the map flies only from a ring, star orbit or alongside.
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
	_swept += 1
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
		if _cases[i].sweep == sweep and _res[i] != null and _res[i].found and StringName(_cases[i].dep.kind) == &"ring":
			leads.append(_res[i].lead)
	print("  ride s %s" % _dist(leads))
	print("  ride: phasing k %s; push along the ring px/s2 %s; top speed px/s %s" % [_dist(ks), _dist(push), _dist(top_v)])
	print("  worst start %.3f of its tolerance; worst landing %.4f px, %.4f px/s" % [worst_start, worst_land, worst_land_v])
	var bar := FOUND_MIN_HAND if sweep.begins_with("twin") else FOUND_MIN
	h.total("%s: found and clean" % sweep, "%s: found and clean in at least %.0f%% (%.2f%%)" % [sweep, 100.0 * bar, 100.0 * clean / n], "clean >= BAR * n", {"clean": clean, "n": n, "BAR": bar})
	h._ok("%s: every found plan starts on the ship's ring (%d of %d)" % [sweep, started, found], started == found)
	h._ok("%s: every clean plan clear of MapGravity's keep-outs at each sample's own time, within %.0f px (%d inside; least margin %.2f px)" % [sweep, IN_PX, inside, worst_in], inside == 0)
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


## Every 5th found plan, rebuilt from its own choice, must give the same samples.
## Or, for a fallback flight, a sooner clean fresh plan of one leg.
## Why: docs/why/SolveTest.md#replays
func _replays() -> void:
	var n := 0
	var same := 0
	var later := 0
	var later_same := 0
	var kept := 0
	var kept_same := 0
	var later_fell := 0
	var spun := 0
	for i in range(0, _cases.size(), 5):
		var r: FlightSolve.Result = _res[i]
		if r == null or not r.found:
			continue
		var c: Dictionary = _cases[i]
		n += 1
		var r2 := FlightSolve.solve(c.G, c.dep, c.tgt, float(c.t), r.choice, c.opts)
		if r2.kind == &"replay" and r2.samp == r.samp and r2.end.t == r.end.t and r2.burns == r.burns:
			same += 1
		elif n - same <= 3:
			print("  (replay %s: %s)" % [r2.kind, c.label])
		var dep: Dictionary = c.dep
		# Not on a flight's own clock (`dep.spin`): a plan made for now spins up from now. The game never
		# asks it, as its plans are made a moment ahead.
		# Why: docs/why/SolveTest.md#spin-not-replayed
		if StringName(dep.kind) == &"ring" and float(dep.get("spin", 0.0)) > 0.0:
			spun += 1
		elif StringName(dep.kind) == &"ring" and r.lead >= 0.6 and r.lead_k <= 1.0:
			later += 1
			var d2 := dep.duplicate()
			d2.ang = float(dep.ang) + float(dep.get("w0", dep.w)) * 0.5
			var r3 := FlightSolve.solve(c.G, d2, c.tgt, float(c.t) + 0.5, r.choice, c.opts)
			if r3.kind == &"replay" and r3.samp == r.samp:
				later_same += 1
			elif _fell_sooner(r, r3):
				later_same += 1
				later_fell += 1
			elif later - later_same <= 3:
				print("  (replay half a second on %s: %s)" % [r3.kind, c.label])
		if StringName(dep.kind) == &"keep":
			kept += 1
			var r4 := FlightSolve.solve(c.G, dep, c.tgt, float(c.t) + 0.5, r.choice, c.opts)
			if r4.kind == &"replay" and r4.samp == r.samp and r4.t0 == r.t0:
				kept_same += 1
			elif _fell_sooner(r, r4):
				kept_same += 1
				later_fell += 1
			elif kept - kept_same <= 3:
				print("  (alongside, half a second on %s: %s)" % [r4.kind, c.label])
	h._ok("a plan rebuilt from its choice is the same flight (%d of %d)" % [same, n], same == n)
	print("replays: half a second on, %d flights the fallback found or in two legs gave way to a fresh plan arriving sooner" % later_fell)
	h._ok("and half a second on, the ship ridden round (%d of %d; %d on a flight's own clock not asked)" % [later_same, later, spun], later_same == later)
	h._ok("and half a second on alongside, the ship holding there (%d of %d)" % [kept_same, kept], kept_same == kept)


## A fallback or two-leg flight that gave way to a sooner clean plan breaks the keep rule.
## Not met until stations were halved on Nov 3 (seed 7 node 199: 544.32 against 540.71).
## Why: docs/why/SolveTest.md#replays
static func _fell_sooner(r: FlightSolve.Result, r2: FlightSolve.Result) -> bool:
	if not (r2.found and r2.clean and r2.kind == &"solved" and float(r2.end.t) < float(r.end.t) - 1e-6):
		return false
	if r.legs == 2:
		return true
	return r.legs == 1 and float(r.choice.get("cap", 0.0)) > _cap0(r) + 1e-6 and r2.legs == 1


## The cap of the first look of r's path: T_CAP for DIRECT, CURVED's arc's
## (`FlightSolve.first_cap`, its first look the as-built search to that cap);
## past it, the fallback's.
static func _cap0(r: FlightSolve.Result) -> float:
	return FlightSolve.first_cap(r.path)


## A dep as `FlightSolve.solve` hands it on for case c's path (`FlightChain.chain_again`
## called straight, past `solve`).
static func _dep_opts(d: Dictionary, c: Dictionary) -> Dictionary:
	if StringName(c.get("path", &"direct")) != &"curved":
		return d
	var d2 := d.duplicate()
	d2["_curved"] = true
	return d2


## The overlay replans the preview every 3 s from the old choice: found, and no costlier than fresh.
## No fallback or two-leg flight is kept where a fresh plan arrives sooner (reviews of Nov 1).
## Why: docs/why/SolveTest.md#replans
func _replans() -> void:
	var n := 0
	var ok := 0
	var fresh_found := 0
	var kinds := {}
	var over: Array = []
	var bad := 0
	var fell := 0
	var held := 0
	for i in range(0, _cases.size(), 7):
		var r: FlightSolve.Result = _res[i]
		var c: Dictionary = _cases[i]
		if r == null or not r.found or StringName(c.dep.kind) != &"ring":
			continue
		var d2: Dictionary = c.dep.duplicate()
		d2.ang = float(c.dep.ang) + float(c.dep.get("w0", c.dep.w)) * 3.0
		var t2 := float(c.t) + 3.0
		var rw := FlightSolve.solve(c.G, d2, c.tgt, t2, r.choice, c.opts)
		var rf := FlightSolve.solve(c.G, d2, c.tgt, t2, {}, c.opts)
		n += 1
		kinds[rw.kind] = int(kinds.get(rw.kind, 0)) + 1
		if rf.found:
			fresh_found += 1
			if rw.found:
				ok += 1
		# (a flight the fallback found, kept warm, or rebuilt as drawn where a
		# fresh plan beside it is clean)
		var fb := rw.found and rf.found and float(rw.choice.get("cap", 0.0)) > _cap0(rw) + 1e-6
		if fb and (rw.kind == &"warm" or (rw.kind == &"replay" and rw.legs == 1)):
			fell += 1
			if rf.T < rw.T - 1e-3 and (rf.clean or rw.kind == &"warm"):
				held += 1
				if held <= 3:
					print("  (the fallback's %.2f s kept %s against a fresh %.2f s: %s)" % [rw.T, rw.kind, rf.T, c.label])
		if rw.found and rf.found and rw.kind == &"warm":
			var fc := _at_time_w(rf)
			over.append(_at_time_w(rw) - fc)
			var j_old := float(r.choice.get("J", INF))
			if not fb and rw.cost > fc + FlightMath.warm_slack(fc) + 1e-6 and rw.cost > j_old + FlightMath.warm_slack(j_old) + 1e-6:
				bad += 1
				if bad <= 3:
					print("  (kept %.1f against fresh %.1f, old %.1f: %s)" % [rw.cost, fc, j_old, c.label])
	print("replans: %d previews planned again 3 s on with their old choice: %s; kept warm, cost minus a fresh search's at TIME_W %s; the fallback's flights kept warm or rebuilt %d" % [n, kinds, _dist(over), fell])
	h.total("replans: found again", "planned again 3 s on, found wherever a fresh search finds one (%d of %d)" % [ok, fresh_found], "ok >= fresh_found - maxi(1, fresh_found / 100)", {"ok": ok, "fresh_found": fresh_found})
	h._ok("and no flight of C's own kept past the warm slack of both a fresh search and its own old cost, at TIME_W (%d)" % bad, bad == 0)
	h._ok("and no flight the fallback found kept where a fresh plan arrives sooner (%d of the %d kept)" % [held, fell], held == 0)
	# Two-leg flights planned again as the overlay plans them, each from the last choice.
	var twos := 0
	var two_kept := 0
	var two_held := 0
	var two_old := 0
	var two_later := 0
	var two_fresh := 0
	var two_cases: Array = []
	for i in _cases.size():
		if _res[i] != null:
			two_cases.append([_cases[i], _res[i]])
	for j in _pin_cases.size():
		var c: Dictionary = _pin_cases[j]
		if h.mine(_cases.size() + j):
			two_cases.append([c, FlightSolve.solve(c.G, c.dep, c.tgt, float(c.t), {}, c.opts)])
	for cr: Array in two_cases:
		var c: Dictionary = cr[0]
		var r: FlightSolve.Result = cr[1]
		var dk := StringName(c.dep.kind)
		if not r.found or r.legs != 2 or (dk != &"ring" and dk != &"keep"):
			continue
		twos += 1
		var dt := 3.0 if dk == &"ring" and int(c.dep.place) != -9 else 1.0
		var pv := r
		var legs: Dictionary = r.choice
		for k in range(1, TWO_STEPS + 1):
			var d2: Dictionary = c.dep.duplicate()
			if dk == &"ring":
				d2.ang = float(c.dep.ang) + float(c.dep.get("w0", c.dep.w)) * dt * float(k)
			var t2 := float(c.t) + dt * float(k)
			var rw := FlightSolve.solve(c.G, d2, c.tgt, t2, pv.choice, c.opts)
			# (the last legs kept, flown again here as `FlightChain.chain_again`
			# flies them: none kept arrives later)
			var ra: FlightSolve.Result = null
			if not legs.is_empty():
				ra = FlightChain.chain_again(c.G, _dep_opts(d2, c), c.tgt, t2, legs)
			if ra != null:
				two_old += 1
				if not rw.found or float(rw.end.t) > float(ra.end.t) + 1e-3:
					two_later += 1
					if two_later <= 3:
						print("  (kept %s in %d legs where its old legs fly %.2f s, %.0f s on: %s)" % ["%.2f s" % rw.T if rw.found else "nothing", rw.legs, ra.T, dt * float(k), c.label])
			if not rw.found:
				continue
			pv = rw
			if rw.legs != 2:
				# (the old legs it carries, `alt`)
				legs = rw.choice.get("alt", {})
				continue
			legs = rw.choice
			two_kept += 1
			# (a fresh plan as a first plan's: one leg, else two)
			var rf2 := FlightSolve.solve(c.G, d2, c.tgt, t2, {}, c.opts)
			if rf2.found and rf2.clean and rf2.T < rw.T - 1e-3:
				if rf2.legs == 1:
					two_held += 1
					if two_held <= 3:
						print("  (%.2f s in two legs kept against a fresh %.2f s in one, %.0f s on: %s)" % [rw.T, rf2.T, dt * float(k), c.label])
				else:
					two_fresh += 1
					if two_fresh <= 3:
						print("  (%.2f s in two legs kept %s against a fresh %.2f s in two, %.0f s on: %s)" % [rw.T, rw.kind, rf2.T, dt * float(k), c.label])
	print("replans: %d flights in two legs planned again %d times each as the overlay plans them (%d pinned cases, `TWO_PINS`); kept in two legs %d times" % [twos, TWO_STEPS, _pin_cases.size(), two_kept])
	h._ok("and no flight in two legs kept where a fresh plan of one leg arrives sooner (%d of %d)" % [two_held, two_kept], two_held == 0)
	h._ok("nor where a fresh plan in two legs arrives sooner (%d of %d)" % [two_fresh, two_kept], two_fresh == 0)
	h._ok("and none kept that arrives later than its old legs flown again (%d of %d)" % [two_later, two_old], two_later == 0)


## A plan's cost at TIME_W: an as-built flight's (its choice's tw
## TIME_W_BACK) with its seconds at C's weight.
static func _at_time_w(r: FlightSolve.Result) -> float:
	var tw0 := FlightSolve.first_tw(r.path)
	return r.cost + (tw0 - float(r.choice.get("tw", tw0))) * r.T


## EACH PATH'S SHAPES (printed per sweep and path): every found, clean flight's
## bend and whole turn (`shape_of`), how many are loops (bend over LOOP_BEND),
## and CURVED's median bend against DIRECT's where both ran in this shard.
func _shapes() -> void:
	var med := {}
	var fo: FileAccess = FileAccess.open(_shapes_out, FileAccess.WRITE) if _shapes_out != "" else null
	for p in _paths:
		var bends: Array = []
		var turns: Array = []
		var loops := 0
		for i in _cases.size():
			var c: Dictionary = _cases[i]
			var r: FlightSolve.Result = _res[i]
			if r == null or not r.found or not r.clean or StringName(c.path) != p:
				continue
			var sh := shape_of(r.samp)
			if fo != null:
				fo.store_line(JSON.stringify({"sweep": c.sweep, "path": String(p), "bend": sh[0], "turn": sh[1], "T_tau": r.T, "pace": _pace_of(p), "legs": r.legs, "kind": String(r.kind)}))
			bends.append(sh[0])
			turns.append(sh[1])
			if sh[0] > LOOP_BEND:
				loops += 1
		print("shape %s (pace %.1f): bend %s; turn deg %s; loops (bend over %.1f) %d of %d" % [p, _pace_of(p), _dist(bends), _dist(turns), LOOP_BEND, loops, bends.size()])
		if not bends.is_empty():
			bends.sort()
			med[p] = float(bends[bends.size() / 2])
	if med.has(&"direct") and med.has(&"curved"):
		h._ok("CURVED's flights bend more than DIRECT's: median %.3f against %.3f (at least %.1f times)" % [med[&"curved"], med[&"direct"], BEND_MARGIN], float(med[&"curved"]) >= BEND_MARGIN * float(med[&"direct"]))


## A sample of plans flown again by plain RK4 through `MapGravity.acc`, measuring the stray.
func _physics() -> void:
	var worst := 0.0
	var worst_at := ""
	var devs: Array = []
	var n := 0
	for i in range(0, _cases.size(), 41):
		var r: FlightSolve.Result = _res[i]
		if r == null or not r.found:
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
		# The departure burn by its own law, eased while slow (`R_BURN`): out of a settled orbit, or a ring where the choice says so (`ez`).
		var ease := StringName(c.dep.kind) == &"ring" and (int(c.dep.place) == -9 or bool(r.choice.get("ez", false)))
		var rem := dv if dv > 1e-9 else 0.0
		var pull := 0.0
		var t := r.t0
		var t_step := t
		var tb := r.t0 + r.dur - r.d2
		var dev := 0.0
		var k := 0
		while t + dt <= tb and k + 1 < s.size():
			# A two-leg flight's second leg leaves the first's coast at k_cut, eased while slow.
			if r.legs == 2 and k == r.k_cut:
				var c2: Dictionary = r.choice.chain.c2
				dvx = float(c2.dvx)
				dvz = float(c2.dvz)
				dv = sqrt(dvx * dvx + dvz * dvz)
				bux = dvx / dv if dv > 1e-9 else 0.0
				buz = dvz / dv if dv > 1e-9 else 0.0
				rem = dv if dv > 1e-9 else 0.0
				ease = true
				t_step = t
			var left := dt
			while left > 1e-12:
				var hp := left
				var ax := 0.0
				var az := 0.0
				if rem > 0.0 or t < t_step - 1e-12:
					if t >= t_step - 1e-12:
						pull = FlightSolve.THRUST
						if ease:
							pull = clampf((vx * vx + vz * vz) / FlightSolve.R_BURN, FlightSolve.P_MIN / float(c.get("k", 1.0)), FlightSolve.THRUST)
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
			var ck := centre(L, int(dep.place), r.t0, float(c.get("k", 1.0)))
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
			if _res[i] != null:
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
		elif j + 1 - same <= 3:
			print("  (on a worker, not the same: %s)" % _cases[_widx[j]].label)
	print("worker: %d plans on WorkerThreadPool in %d ms of wall clock (%.0f ms planned one after another on the main thread)" % [_widx.size(), wall, serial])
	h._ok("a plan made on a worker is the same plan (%d of %d)" % [same, _widx.size()], same == _widx.size())


func _solve_on_worker(j: int) -> void:
	var c: Dictionary = _cases[_widx[j]]
	var r := FlightSolve.solve(c.G, c.dep, c.tgt, float(c.t), {}, c.opts)
	_wlock.lock()
	_wres[j] = r
	_wlock.unlock()


# ---------------------------------------------------------------- the prototype's flight
# Judged with the pair held still, as the prototype flew it.
# At x4 it needs 62.7 px/s in 8.2 s, so the turning figures are only shown.
# Why: docs/why/SolveTest.md#prototype-flight
func _prototype() -> void:
	var k0 := SystemLayout.pair_speed()
	for k: float in ([0.0, k0] if k0 > 0.0 else [0.0]):
		SystemLayout.pair_k = k
		var how := "held still" if k == 0.0 else "turning at x%.0f" % k
		var L := twin_layout(280.0)
		var G := MapGravity.from_layout(L)
		var tgt := {"kind": &"ring", "place": 1, "R": L.bodies[1].soi, "V": RAIL_V, "sense": 0}
		var w := -RAIL_V / L.bodies[0].soi
		for before: float in [0.05, 0.4, 1.0]:
			var dep := {"kind": &"ring", "place": 0, "rt": L.bodies[0].soi, "ang": 3.6115208250617648 - w / absf(w) * before, "w": w}
			var r := FlightSolve.solve(G, dep, tgt, 0.0)
			print("prototype a to b (%s), best line-up, the ship %.2f rad before its point: %s" % [how, before,
				"engine work %.2f px/s (phasing %.2f, leaving %.2f, arriving %.2f) in %.2f s (ride %.2f s), %d integrations, %.1f ms" % [r.work, r.dvp, r.dv1, r.dv2, r.T, r.lead, r.integrations, r.usec / 1000.0] if r.found else "none found"])
			if before == 0.05 and k == 0.0:
				h._ok("prototype a to b at its best line-up, the pair held still: found, clean, within 3 px/s of free (%.2f) and 9.2 s +- 3 (%.1f)" % [r.work, r.T],
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
		print("prototype a to b (%s) over 12 line-ups: found %d; engine work %s; time %s (prototype typical 3.6 px/s)" % [how, works.size(), _dist(works), _dist(Ts)])
	SystemLayout.pair_k = k0


# ---------------------------------------------------------------- the cost of a step
# Planner cost on this machine: 40 timed 30 s coasts give the cost of one RK4 step.
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
		fs._integrate(0.0, 300.0, 0.0, 0.0, 26.0 + 0.1 * i, 3.0, 0.0, FlightSolve.T_CAP_BACK)
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
		fs2._integrate(0.0, 0.0, 300.0, 30.0 + 0.1 * i, 0.0, 0.0, 3.0, FlightSolve.T_CAP_BACK)
	us = Time.get_ticks_usec() - t0
	steps = fs2._n_steps - steps0
	print("bench: 40 coasts through two stars and a giant, %d RK4 steps, %.2f ms each, %.2f us a step" % [steps, us / 40000.0, float(us) / maxf(1.0, steps)])
	# (the hand twin 280, turning and held still: what the pair's turn costs a step)
	var k0 := SystemLayout.pair_speed()
	for k: float in [0.0, maxf(k0, 1.0)]:
		SystemLayout.pair_k = k
		var fs3 := FlightSolve.new()
		fs3.G = MapGravity.from_layout(twin_layout(280.0))
		t0 = Time.get_ticks_usec()
		steps0 = fs3._n_steps
		for i in 40:
			fs3._integrate(0.0, 126.0, 300.0, 30.0 + 0.1 * i, 0.0, 0.0, 3.0, FlightSolve.T_CAP_BACK)
		us = Time.get_ticks_usec() - t0
		steps = fs3._n_steps - steps0
		print("bench: 40 coasts through the hand twin 280 %s, %d RK4 steps, %.2f ms each, %.2f us a step" % ["held still" if k == 0.0 else "turning at x%.0f" % k, steps, us / 40000.0, float(us) / maxf(1.0, steps)])
	SystemLayout.pair_k = k0
