extends Harness

## Does the system map's layout keep its promises?
##   godot --headless --path . -- systemtest
##
## A GATE. `SystemLayout` is derived and never saved, so everything it gets
## wrong is wrong silently: an option with no body is an encounter nobody can
## click, an unstable layout is a planet that moves between a save and a load
## (or sits in two places for two players), and an orbit run through a body is a
## planet drawn on top of another. The five promises:
##
## **Every option is on exactly one body** (or on the star itself, an event
## sited there at a red or blue star), a station has its DOCK and the core its
## custodian.
## **Stable**: the same node lays out the same way twice in one run, and the same
## seed lays out the same way in a fresh run.
## **A gas giant if and only if the node has one** (never round a pulsar), and
## every giant weighs 1/10 to 1/4 of its star (ruling 20) with its ring and dent
## where they were.
## **Orbits never cross a body**: neighbouring orbits are further apart than the
## two bodies on them are wide.
## **No shared stream is touched**: laying out a system draws only from
## `Rng.derive`, so looking at the map cannot move what the run rolls next.
## **One event to a world** (Jon, Oct 15: "A planet should only hold one event.
## That should be a rule."): no planet, giant or star holds two options.
## **The Hellbender has a place of its own** where it is anchored, last, past
## every orbit, and every other body is where it would be without it.
##
## AND TWO SUNS (ruling 20, Oct 30), about one ordinary system in four, and every
## one of them under `twin=all`: a world round each star, inside the farthest
## steady orbit round it (Holman and Wiegert); everything else round both, past
## the nearest steady orbit round the pair; neighbours apart round each centre,
## not by index; every world's ring clear of its star's close ring, of both
## stars' keep-clear and of every ring it can meet; each world round a star
## standing clear of its sun's drawn disc at the map's opening zoom, beside it;
## zones by distance from the light; Kepler round what each body circles.

const SEEDS := [4242, 7, 1999, 31337]
const STAR_B := SystemLayout.STAR_B


func _print_of(L: SystemLayout) -> String:
	var parts: Array[String] = ["%d" % L.star]
	# (two suns: the pair, its rings and where each body circles)
	if L.twin:
		parts.append("twin:%.5f:%.3f:%.3f,%.3f:%.3f:%.3f,%.3f" % [L.star_share, L.sep, L.star2_at.x,
			L.star2_at.y, L.star2_r, L.bary.x, L.bary.y])
		for p in L.stars():
			parts.append("ring%d:%.3f:%.3f:%.3f" % [p, L.keep_clear_of(p), L.star_rail_of(p), L.star_ring_of(p)])
	for b in L.bodies:
		var opts: Array[String] = []
		for bc in b.beacons:
			opts.append("%d%s%s" % [bc.opt, "d" if bc.dock else "", "c" if bc.core else ""])
		parts.append("%s:%s:%.3f:%.3f:%.3f:%s:%.3f[%s]:%d:%.3f,%.3f:%.5f:%d:%.3f" % [b.kind, b.world, b.orbit,
			b.period, b.phase, b.name, b.r, ",".join(opts), b.host_id, b.host.x, b.host.y, b.gm_frac, b.zone, b.soi])
	var on_star: Array[String] = []
	for bc in L.star_beacons:
		on_star.append("%d" % bc.opt)
	parts.append("star[%s]" % ",".join(on_star))
	parts.append("edge:%.3f" % L.edge)
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
	var zooms_one: Array[float] = []
	var zooms_two: Array[float] = []
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
			# the edge past everything, from star A, whatever each body circles
			for b in L.bodies:
				if L.edge < b.host.length() + b.orbit + SystemLayout.reach_of(b):
					_fail("system %d: %s %s reaches past the edge" % [n.index, b.kind, b.name])
			# two suns only where they may be, and always where the node has them
			if MapGen.twin_ok(n):
				eligible += 1
				if n.twin:
					twins += 1
			elif n.twin:
				_fail("system %d has two suns and may not (type %d, star %d)" % [n.index, n.type, n.star])
			if L.twin != n.twin:
				_fail("system %d: twin %s, laid out twin %s" % [n.index, str(n.twin), str(L.twin)])
			if L.twin:
				_twin_checks(n, L, "seed %d system %d" % [s, n.index])
				zooms_two.append(SystemLayout.open_zoom(L.edge))
			else:
				zooms_one.append(SystemLayout.open_zoom(L.edge))
				# ONE SUN: everything round star A, as it always was
				if L.sep != 0.0 or L.star_share != 1.0 or not L.bodies.all(func(b): return b.host_id == -1 and b.host == Vector2.ZERO):
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
	var share := float(twins) / float(maxi(eligible, 1))
	_ok("two suns at %d of %d systems that may have them (%.0f%%; about one in four)" % [twins, eligible, share * 100.0],
		twins > 0 and share > 0.12 and share < 0.40)
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
	var keys := worlds.keys()
	keys.sort_custom(func(a, b): return int(worlds[a]) > int(worlds[b]))
	var line: Array[String] = []
	for k in keys:
		line.append("%s %d" % [k, worlds[k]])
	print("  worlds drawn: " + ", ".join(line))
	verdict("systemtest")


## Least / median / most of a list, for a line.
func _spread(v: Array[float]) -> String:
	if v.is_empty():
		return "none"
	var s := v.duplicate()
	s.sort()
	return "%.3f / %.3f / %.3f (least / median / most of %d)" % [s[0], s[int(s.size() / 2.0)], s[s.size() - 1], s.size()]


## A GIANT'S WEIGHT (ruling 20): 1/10 to 1/4 of its star, in every system that
## has one, felt by the autopilot through `gm`; its ring and its dent in the
## fabric are where they were, so no orbit moved. Nothing else pulls.
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
	var d := a.host.distance_to(b.host)
	if d >= a.orbit + b.orbit:
		return d - a.orbit - b.orbit
	if d <= absf(a.orbit - b.orbit):
		return absf(a.orbit - b.orbit) - d
	return 0.0


## How far round a body its ring reaches (or the body itself, with no ring).
static func _ring(b: SystemLayout.Body) -> float:
	return b.soi if b.soi > 0.0 else SystemLayout.reach_of(b)


## THE TWO-SUN PROMISES, on one twin layout.
func _twin_checks(n: MapGen.MapNode, L: SystemLayout, at: String) -> void:
	var share := L.star_share
	if L.star != SystemLayout.StarKind.ORDINARY or L.star2 != SystemLayout.StarKind.ORDINARY:
		_fail("%s: two suns that are not both ordinary" % at)
	if not (L.star2_r < L.star_r and L.star2_r > 0.0):
		_fail("%s: star B (r %.1f) is not the smaller" % [at, L.star2_r])
	if share < SystemLayout.TWIN_SHARE_LO - 1e-9 or share > SystemLayout.TWIN_SHARE_HI + 1e-9:
		_fail("%s: star A's share %.3f" % [at, share])
	if L.sep < SystemLayout.TWIN_SEP_LO - 1e-6 or absf(L.star2_at.length() - L.sep) > 0.01:
		_fail("%s: the stars %.1f apart, star B %.1f out" % [at, L.sep, L.star2_at.length()])
	if L.bary.distance_to(L.star2_at * (1.0 - share)) > 0.01:
		_fail("%s: the balance point is not where the shares put it" % at)
	if not L.star_beacons.is_empty():
		_fail("%s: an event on a star of a pair" % at)
	_seen += 1
	if L.sep > SystemLayout.TWIN_SEP_HI + 0.5:
		_spread_out += 1
		_most("separation spread past its roll", L.sep, at)
	# WHAT EACH BODY CIRCLES: star A at the origin, star B at its place, or the
	# balance point; one world round each star, and only one
	var round_a: Array[SystemLayout.Body] = []
	var round_b: Array[SystemLayout.Body] = []
	var both: Array[SystemLayout.Body] = []
	for b in L.bodies:
		if b.host_id == -1 and b.host == Vector2.ZERO:
			round_a.append(b)
		elif b.host_id == STAR_B and b.host.distance_to(L.star2_at) < 0.01:
			round_b.append(b)
		elif b.host_id == -9 and b.host.distance_to(L.bary) < 0.01:
			both.append(b)
		else:
			_fail("%s: %s %s circles %d at (%.1f, %.1f), which is no centre" % [at, b.kind, b.name, b.host_id, b.host.x, b.host.y])
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
	# PAST THE NEAREST STEADY ORBIT ROUND BOTH
	for b in both:
		var k := b.orbit / L.sep
		if k < SystemLayout.P_LIMIT:
			_fail("%s: %s %s round both at %.3f of the separation, inside %.3f" % [at, b.kind, b.name, k, SystemLayout.P_LIMIT])
		_least("round both, orbit over separation", k, at)
	# NEIGHBOURS APART ROUND EACH CENTRE, nearest out, not by index
	for group in [round_a, round_b, both]:
		var g: Array = group.duplicate()
		g.sort_custom(func(x, y): return x.orbit < y.orbit)
		for i in range(1, g.size()):
			var gap: float = g[i].orbit - g[i - 1].orbit - SystemLayout.reach_of(g[i]) - SystemLayout.reach_of(g[i - 1])
			_least("gap between neighbours round both", gap, at)
			if gap <= 0.0:
				_fail("%s: %s and %s cross their bodies round the same centre (gap %.1f)" % [at, g[i - 1].name, g[i].name, gap])
	# KEPLER ROUND WHAT IT CIRCLES: a world round one star by that star's share
	for b in L.bodies:
		var m := 1.0 if b.host_id == -9 else (share if b.host_id == -1 else 1.0 - share)
		var k := b.period / (800.0 * pow(b.orbit / 100.0, 1.5) / sqrt(m))
		if k < 0.95 - 1e-6 or k > 1.05 + 1e-6:
			_fail("%s: %s's period is %.3f of Kepler's round what it circles" % [at, b.name, k])
	# THE RINGS. Each star: keep-clear, then rail, then ring, out from its surface.
	for p in L.stars():
		var r := L.star_radius(p)
		if not (r < L.keep_clear_of(p) and L.keep_clear_of(p) < L.star_rail_of(p) and L.star_rail_of(p) < L.star_ring_of(p)):
			_fail("%s: star %d's keep-clear %.1f, rail %.1f and ring %.1f are out of order" % [at, p, L.keep_clear_of(p), L.star_rail_of(p), L.star_ring_of(p)])
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
		var cq := w.host.distance_to(L.star_pos(q)) - w.orbit - w.soi
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
			var near := b.orbit - b.host.distance_to(L.star_pos(p)) - _ring(b) - L.star_ring_of(p)
			if near < SystemLayout.RING_CLEAR:
				_fail("%s: %s %s's ring comes %.1f px from star %d's close ring" % [at, b.kind, b.name, near, p])
	# AT THE OPENING ZOOM each world round a star stands clear of its sun's drawn
	# disc beside it (3 game px). At its near point, in front of the sun, it
	# cannot -- the edge is too far out for the zone it is in (`SystemLayout._twin`)
	# -- so that is measured, not promised.
	var z := SystemLayout.open_zoom(L.edge)
	for w in sw:
		var p := w.host_id
		var sun := SystemLayout.sun_drawn(L.star_radius(p), z)
		var disc := SystemLayout.world_drawn(w, z)
		var side := w.orbit * z - sun - disc
		var front := w.orbit * z * SystemLayout.SLANT - sun - disc
		_least("world beside its sun at the opening zoom (game px)", side, at)
		_least("world in front of its sun at the opening zoom (game px)", front, at)
		_most("world in front of its sun at the opening zoom, most (game px)", front, at)
		_least("star's close ring outside its drawn sun (game px)", L.star_ring_of(p) * z - sun, at)
		if side < 3.0:
			_fail("%s: %s stands %.1f game px off its sun's drawn disc at the opening zoom %.3f" % [at, w.name, side, z])
	# ZONES BY DISTANCE FROM THE LIGHT: never a farther body in a nearer zone;
	# the worlds round a star near
	var dist := {}
	for b in L.bodies:
		var flux := 0.0
		for p in L.stars():
			var cc := L.star_pos(p).distance_to(b.host)
			flux += pow(L.star_radius(p) / 16.0, 2.0) / maxf(absf(cc * cc - b.orbit * b.orbit), 1.0)
		dist[b] = 1.0 / sqrt(flux)
	for a in L.bodies:
		for b in L.bodies:
			if float(dist[a]) < float(dist[b]) and a.zone > b.zone:
				_fail("%s: %s (%.0f px from the light) is in zone %d, farther %s (%.0f) in %d" % [at, a.name, dist[a], a.zone, b.name, dist[b], b.zone])
	for w in sw:
		if w.zone != 0:
			_fail("%s: %s, %.0f px from its sun, is not near" % [at, w.name, w.orbit])
	var names := {}
	for b in L.bodies:
		if names.has(b.name):
			_fail("%s: two bodies called %s" % [at, b.name])
		names[b.name] = true


## EVERY SYSTEM THAT MAY HAVE TWO SUNS, WITH THEM (`MapGen.twin_force`, the
## harness's `-- twin=all`): each lays out as a twin and keeps every promise;
## and with `twin=none`, none does.
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
	print("    seed node  sep  share  rA   rB  | round A: a / limit (ring; star A's close ring) | round B: the same | round both: kind a (ring) ... | edge  zoom | A beside, in front | B beside, in front (game px)")
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
			var sun := SystemLayout.sun_drawn(L.star_radius(b.host_id), z)
			var disc := SystemLayout.world_drawn(b, z)
			ws[b.host_id] = "%.1f / %.1f (%.0f; its star's %.0f) | " % [b.orbit, SystemLayout.s_limit(mu) * L.sep, b.soi, L.star_ring_of(b.host_id)]
			ws[str(b.host_id)] = "%.1f, %.1f" % [b.orbit * z - sun - disc, b.orbit * z * SystemLayout.SLANT - sun - disc]
	return "%5d %4d %5.0f %.3f %4.1f %4.1f | %s%s%s | %5.0f %.3f | %s | %s" % [s, n.index, L.sep, L.star_share,
		L.star_r, L.star2_r, ws.get(-1, "?"), ws.get(STAR_B, "?"), ", ".join(both), L.edge, z,
		ws.get("-1", "?"), ws.get(str(STAR_B), "?")]


## What the two-sun checks measured.
func _report() -> void:
	print("  two-sun layouts checked: %d, %d of them moved apart past their rolled separation" % [_seen, _spread_out])
	var keys := _st.keys()
	keys.sort()
	for k in keys:
		print("  %s: %.3f (%s)" % [k, float(_st[k][0]), _st[k][1]])


## Its place: last, past every orbit, and nothing else moved by it.
func _hellbender(label: String) -> void:
	Rng.forced = SEEDS[0]
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
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
			past = past and hb.orbit - SystemLayout.reach_of(hb) > b.host.distance_to(hb.host) + b.orbit + SystemLayout.reach_of(b)
	_ok("%spast every orbit" % label, past)
