extends Node

## TWO SUNS AND HEAVY GIANTS ON THE MAP (ruling 20, Oct 30), measured headless:
##   godot --headless --path . -- sheet=TwinDrawTest [seeds=24] [views=N]
## Every check here looks at twins it has counted and prints how many, so none
## passes on an empty set.
##
##   * THE TWIN SUN FLOOR (`SystemView.twin_floor_on`): in every twin of
##     `seeds` seeds (24, the layout reviewers', under twin=all), with a fetch, a
##     hunt, the Hellbender and all three put out past its edge as
##     `SystemTest._comers` puts them, the map opens below the layout's
##     `fit_zoom` -- and there each sun's drawn plane radius never passes the
##     one it has at the fit (its true size and its held disc, at the opening
##     zoom and at 12 zooms from there to the fit), no star's close ring runs
##     inside its drawn sun, and the worlds round each star are counted against
##     their suns, before (the old floor, `SystemLayout.sun_drawn`) and after;
##   * THE PAIR TURNS (ruling 23): every check of the drawn map below at
##     `PHASES` (8) angles round the pair's lap, not only the one it was laid
##     out at;
##   * THE DEPTH ORDER (`SystemView.step`): over the twins of the four
##     systemtest seeds as rolled, each world round a star drawn after its sun
##     when it is nearer the viewer than the sun and before it when farther, at
##     24 moments round its year, for both stars; the nearer of the two suns
##     drawn over the farther ("stacked:A"), and each sun drawn where the pair
##     has it (`star_screen`);
##   * THE ORBITS ROUND THEIR OWN CENTRES (`_Lines.orbit_runs`): every point of
##     every drawn ring on some body's ring about its own host, and each world
##     round a star with points on its own;
##   * THE LIGHT: each world round one star of a pair lit from that star (the
##     share of its light, the angle of its one light against the way to it);
##   * THE SHIP ON A WORLD'S 20 px RING (`ShipFlight.orbit_r`), measured, not
##     judged: how much of its ride round a world circling one star its centre
##     spends inside the world's drawn disc, at the opening zoom and at 1 (since
##     Jon's "ring:A", Nov 1, it is drawn over that world in a light outline
##     there: TwinSiteTest checks that on the real map);
##   * THE SUN FLOOR AS DRAWN (Oct 31): the same promise read off the map
##     itself, each SunView's own disc and corona (`_kd`, `_k`) as `step` sets
##     them, on every frame of a zoom out from the fit to 0.6 of it and of the
##     jumps and settles after, for both stars -- the floor above is the
##     layout's sums, which hold by construction and could not catch the map
##     dropping its cap;
##   * THE NEAR POINT'S RING AND MOONS (Oct 31): every drawn orbit point inside
##     a star's hole on screen is in front of that star (none behind it), some
##     are (a world round one star of a pair passes in front of its sun, and its
##     ring's near half with it), and a world in front of its sun inside its
##     hole keeps its moons (`_Moons.positions`), one behind it does not;
##   * LOCAL'S TWO SUNS, as far as headless reaches (`LocalSky._build` stops
##     before any picture is made, so the suns, their slots, the disc cut, the
##     palette and the steps run first in a window): with the ship parked at a
##     world round each star and at each star's close orbit (a close pair, with
##     no world round one star, at each star's close orbit), the place kept
##     (-4 too), the lit sun the near one, the distance from it (a world round B
##     65 to 100 px out, not 350), the near sun drawn the bigger, the two discs
##     apart on the band, and the cloud's bubble round the lit sun clear of
##     every band of distance from it that a body sweeps.
## Prints `twindrawtest: PASS` or `twindrawtest: N FAILURES`.

const SystemViewS := preload("res://scripts/ui/sysmap/SystemView.gd")
const ShipFlightS := preload("res://scripts/ui/sysmap/ShipFlight.gd")
const SectorPaintedS := preload("res://scripts/ui/sysmap/SectorPainted.gd")
const SkyBakeS := preload("res://scripts/ui/sysmap/SkyBake.gd")
const SEEDS := [4242, 7, 1999, 31337, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233, 377, 610, 987, 1597, 2584, 4181, 6765, 10946]
const VIEW_SEEDS := [4242, 7, 1999, 31337]

var h := Harness.new()
var _st := {}
var _n := {}


func _ready() -> void:
	_run.call_deferred()


func _tally(k: String, by: int = 1) -> void:
	_n[k] = int(_n.get(k, 0)) + by


func _least(k: String, v: float, at: String) -> void:
	if not _st.has(k) or v < float(_st[k][0]):
		_st[k] = [v, at]


func _most(k: String, v: float, at: String) -> void:
	if not _st.has(k) or v > float(_st[k][0]):
		_st[k] = [v, at]


func _run() -> void:
	var n_seeds := SEEDS.size()
	var n_views := 1000
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with("seeds="):
			n_seeds = clampi(int((a as String).substr(6)), 1, SEEDS.size())
		elif (a as String).begins_with("views="):
			n_views = int((a as String).substr(6))
	var t0 := Time.get_ticks_msec()
	MapGen.twin_force = 1
	for si in n_seeds:
		_floor_seed(int(SEEDS[si]))
	MapGen.twin_force = 0
	print("  twindrawtest: the sun floor over %d seeds in %.1f s" % [n_seeds, float(Time.get_ticks_msec() - t0) / 1000.0])
	_floor_verdict()
	t0 = Time.get_ticks_msec()
	var view: Control = SystemViewS.new()
	add_child(view)
	var seen := 0
	for sd: int in VIEW_SEEDS:
		Rng.forced = sd
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
		for raw in Run.map:
			var nd: MapGen.MapNode = raw
			if not nd.twin or seen >= n_views:
				continue
			seen += 1
			await view.show_system(nd)
			view.window = Rect2(0, 0, 960, 540)
			_view_checks(view, "seed %d system %d" % [sd, nd.index])
			_view_floor(view, "seed %d system %d" % [sd, nd.index])
	view.queue_free()
	print("  twindrawtest: %d twins drawn and checked in %.1f s" % [seen, float(Time.get_ticks_msec() - t0) / 1000.0])
	_view_verdict(seen)
	t0 = Time.get_ticks_msec()
	await _painted()
	print("  twindrawtest: PAINTED's silhouettes looked at in %.1f s" % [float(Time.get_ticks_msec() - t0) / 1000.0])
	t0 = Time.get_ticks_msec()
	var lseen := 0
	for sd: int in VIEW_SEEDS:
		Rng.forced = sd
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
		for raw in Run.map:
			var nd: MapGen.MapNode = raw
			if not nd.twin or lseen >= n_views:
				continue
			lseen += 1
			_local_checks(nd, "seed %d system %d" % [sd, nd.index])
	print("  twindrawtest: LOCAL looked at in %d twins in %.1f s" % [lseen, float(Time.get_ticks_msec() - t0) / 1000.0])
	_local_verdict(lseen)
	_report()
	h.verdict("twindrawtest")
	get_tree().quit(h.code())


# ---------------------------------------------------------------- the sun floor

## Star p's sun at zoom z, game px: [its true size, the most it is held at], the
## way the map draws it now (`after`) or with the old floor.
static func _sun(L: SystemLayout, p: int, z: float, after: bool) -> Vector2:
	var r := L.star_radius(p)
	if not after:
		var raw0 := SystemLayout.sun_drawn(r, z)
		return Vector2(raw0, SystemLayout.held_most(raw0, SystemLayout.SUN_LEAST))
	var raw := r * SystemViewS.sun_raw_k(r, z)
	var cap := INF
	if L.twin and z < L.fit_zoom:
		raw = minf(raw, r * SystemViewS.sun_raw_k(r, L.fit_zoom) * z / L.fit_zoom)
		cap = SystemViewS.twin_held_cap(r, z, L.fit_zoom)
	return Vector2(raw, minf(SystemLayout.held_most(raw, SystemLayout.SUN_LEAST), cap))


static func _disc_held(w: SystemLayout.Body, z: float) -> float:
	var raw := SystemLayout.world_drawn(w, z)
	return SystemLayout.held_most(raw, minf(SystemLayout.WORLD_FLOOR, raw))


## Whether a layout has a place out past its edge that comes and goes.
static func _comers_in(n: MapGen.MapNode, L: SystemLayout) -> bool:
	if L.hellbender_place() >= 0:
		return true
	for b in L.bodies:
		for bc in b.beacons:
			if bc.opt >= 0 and bc.opt < n.options.size() and OptionTable.is_job(n.options[bc.opt]):
				return true
	return false


func _floor_seed(sd: int) -> void:
	Rng.forced = sd
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		if not MapGen.twin_ok(n):
			continue
		var hb_at := Run.hellbender_at
		var hb_hp := Run.hellbender_hp
		if hb_at == n.index:
			Run.hellbender_at = -1
		var bare := SystemLayout.of(n)
		# (counted once the options are rolled: `SystemLayout.of` rolls them on a
		# node's first layout, and counted before, the first case's cut back to
		# that count wiped them and every later case was laid out bare of them)
		var n_opt := n.options.size()
		if not bare.twin or _comers_in(n, bare):
			Run.hellbender_at = hb_at
			continue
		_tally("twins laid out bare")
		# (as `SystemTest._comers` puts them out: a fetch's world, a hunt's contact,
		# the Hellbender, and all three)
		var cases: Array = [["a fetch", [&"job_pickup"], false], ["a hunt", [&"job_target"], false],
			["the Hellbender", [], true], ["all three", [&"job_pickup", &"job_target"], true]]
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
			_floor_case(L, String(c[0]), "seed %d system %d" % [sd, n.index])
		Run.hellbender_at = hb_at
		Run.hellbender_hp = hb_hp


func _floor_case(L: SystemLayout, what: String, at: String) -> void:
	var z := SystemLayout.open_zoom(L.edge)
	var fz := L.fit_zoom
	_tally("%s: twins" % what)
	if z < fz - 1e-9:
		_tally("%s: twins opened below the fit" % what)
	for p in L.stars():
		for after: bool in [false, true]:
			var tag := "after" if after else "before"
			var s := _sun(L, p, z, after)
			_tally("%s: star rings (%s)" % [what, tag])
			# the layout's own measure: the ring against the sun's true size
			if L.star_ring_of(p) < s.x / z:
				_tally("%s: star rings inside the drawn sun (%s)" % [what, tag])
			_least("%s: star's ring outside its drawn sun, plane px (%s)" % [what, tag], L.star_ring_of(p) - s.x / z, at)
			# and against the most it is held at, in blocks
			if L.star_ring_of(p) < s.y / z:
				_tally("%s: star rings inside the held sun (%s)" % [what, tag])
			_least("%s: star's ring outside its held sun, plane px (%s)" % [what, tag], L.star_ring_of(p) - s.y / z, at)
		# BELOW THE FIT, NEVER WIDER ON THE PLANE THAN AT THE FIT: the true size and
		# the held disc, at the opening zoom and 12 zooms on to the fit
		var at_fit := _sun(L, p, fz, true)
		var held_fit := maxf(roundf(at_fit.x / 2.0) * 2.0, 2.0)
		for k in 13:
			var zk := lerpf(z, fz, float(k) / 13.0)
			if zk >= fz:
				continue
			var sk := _sun(L, p, zk, true)
			_tally("sun floor: zooms below the fit checked")
			_most("sun floor: true plane radius over the fit's", (sk.x / zk) / (at_fit.x / fz), at)
			_most("sun floor: held plane radius over the fit's", (sk.y / zk) / (held_fit / fz), at)
			# (as ratios: the capped true size is the fit's times zk / fz, equal to it
			# on the plane but for float rounding, a few millionths of a pixel)
			if (sk.x / zk) / (at_fit.x / fz) > 1.0 + 1e-6 or (sk.y / zk) / (held_fit / fz) > 1.0 + 1e-6:
				_tally("sun floor: a sun wider on the plane than at the fit")
	for w in L.bodies:
		if not SystemLayout.is_star(w.host_id):
			continue
		for after: bool in [false, true]:
			var tag := "after" if after else "before"
			var side := w.orbit * z - _sun(L, w.host_id, z, after).y - _disc_held(w, z)
			_tally("%s: worlds round a star (%s)" % [what, tag])
			_least("%s: world beside its sun as drawn, game px (%s)" % [what, tag], side, at)
			if side < 0.0:
				_tally("%s: worlds touching their sun (%s)" % [what, tag])
			if side < SystemLayout.SIDE_GAP:
				_tally("%s: worlds under 3 game px off their sun (%s)" % [what, tag])


func _floor_verdict() -> void:
	var cases := ["a fetch", "a hunt", "the Hellbender", "all three"]
	var tw := int(_n.get("twins laid out bare", 0))
	h._ok("the sun floor measured on %d twins, each with %d cases put out" % [tw, cases.size()], tw > 100)
	for c: String in cases:
		var below := int(_n.get("%s: twins opened below the fit" % c, 0))
		print("  twindrawtest: with %s out: %d of %d twins open below their fit; star rings inside the drawn sun %d before, %d after (held: %d, %d); worlds touching their sun %d before, %d after, of %d" % [c,
			below, int(_n.get("%s: twins" % c, 0)),
			int(_n.get("%s: star rings inside the drawn sun (before)" % c, 0)), int(_n.get("%s: star rings inside the drawn sun (after)" % c, 0)),
			int(_n.get("%s: star rings inside the held sun (before)" % c, 0)), int(_n.get("%s: star rings inside the held sun (after)" % c, 0)),
			int(_n.get("%s: worlds touching their sun (before)" % c, 0)), int(_n.get("%s: worlds touching their sun (after)" % c, 0)),
			int(_n.get("%s: worlds round a star (after)" % c, 0))])
		h._ok("with %s out, no star's close ring inside its drawn sun (%d before)" % [c, int(_n.get("%s: star rings inside the drawn sun (before)" % c, 0))],
			int(_n.get("%s: star rings inside the drawn sun (after)" % c, 0)) == 0 and int(_n.get("%s: star rings inside the held sun (after)" % c, 0)) == 0)
	var zc := int(_n.get("sun floor: zooms below the fit checked", 0))
	h._ok("below the fit no sun is wider on the plane than at the fit (%d suns at zooms checked)" % zc,
		zc > 1000 and int(_n.get("sun floor: a sun wider on the plane than at the fit", 0)) == 0)


# ---------------------------------------------------------------- the drawn map

func _view_checks(view, at: String) -> void:
	var L: SystemLayout = view.layout
	if not L.twin or view.star2 == null:
		h._fail("%s: a twin drawn without star B" % at)
		return
	_tally("views")
	var fl = ShipFlightS.new()
	fl.setup(L, Vector2(L.edge * 0.9, -210.0), 0.0)
	view.zoom = SystemLayout.open_zoom(L.edge)
	view.home_zoom = view.zoom
	view.pan = Vector2.ZERO
	# THE PAIR TURNS (ruling 23): every check below at PHASES angles round a lap
	# of the pair, so none holds only at the angle it was laid out at (a still
	# pair, `pair=0`, has the one)
	var lap: float = TAU / L.pair_n if L.pair_n > 0.0 else 0.0
	var phases := PHASES if lap > 0.0 else 1
	_tally("pair phases wanted", phases)
	# (the orbit lines, every point of every ring against every body, at the
	# first angle and one more, a different one for each twin in turn: all eight
	# of them over the twins)
	var also := 1 + int(_n.get("views", 0)) % (PHASES - 1)
	for ph in phases:
		_tally("pair phases drawn")
		_phase_checks(view, fl, lap * float(ph) / float(PHASES), ph, ph == 0 or ph == also, "%s, the pair %d/%d round" % [at, ph, PHASES])


## How many angles round its lap each pair is drawn at, and how many moments of
## each world's year at each angle but the first (which has all 24): the map is
## stepped once a moment, and 24 at every angle, with the orbit lines read at
## every one, took the sheet from 110 s to 390.
const PHASES := 8
const MOMENTS_TURNED := 6


## One angle of the pair, from map time `t0`: the depth order (each world round a
## star against its sun, and the two suns against each other, near over far),
## the two suns drawn where the pair has them, the moons, the light; the ship's
## ring (at the first angle alone, since it is measured round its world); the
## orbit lines, where `orbits`.
func _phase_checks(view, fl, t0: float, ph: int, orbits: bool, at: String) -> void:
	var L: SystemLayout = view.layout
	var ring := ph == 0
	# (every moment of the 24 at the first angle; at the others MOMENTS_TURNED of
	# them, each angle starting a moment further on, so between them the angles
	# see every part of the year)
	var moments: Array[int] = []
	for k in 24:
		if ring or k % (24 / MOMENTS_TURNED) == ph % (24 / MOMENTS_TURNED):
			moments.append(k)
	for w in L.bodies:
		if w.world == &"" or not SystemLayout.is_star(w.host_id) or not view._views.has(w.index):
			continue
		var sn: Node2D = view.star2 if w.host_id == SystemLayout.STAR_B else view.star
		# THE DEPTH ORDER, round its year
		var mooned := int((view._views[w.index].get("spec") as Dictionary).get("moons", 0)) > 0
		for k: int in moments:
			view.t = t0 + w.period * float(k) / 24.0
			view.step()
			# (its sun's depth now: the pair turns, so it is not star A's 0)
			var sd: float = view.star_depth(w.host_id)
			var wv: Node2D = view._views[w.index]
			var in_front: bool = (view.pos[w.index] as Vector2).y >= sd
			var ok := (wv.get_index() > sn.get_index()) == in_front
			_tally("depth order: world round a star, moments checked")
			# THE TWO SUNS, NEAR OVER FAR ("stacked:A"), and each drawn where the pair
			# has it (`star_screen`, as the lines, the overlay and the weather read it)
			var b_front: bool = float(view.star_depth(SystemLayout.STAR_B)) > float(view.star_depth(-1))
			_tally("depth order: the two suns, moments checked")
			if (view.star2.get_index() > view.star.get_index()) != b_front:
				_tally("depth order: the far sun drawn over the near one")
				h._fail("%s: the far sun drawn over the near one at t %.0f" % [at, view.t])
			for sp: int in L.stars():
				var sv: Node2D = view.star2 if sp == SystemLayout.STAR_B else view.star
				_tally("suns: drawn places checked")
				if sv.position != view.star_screen(sp):
					_tally("suns: drawn off their place")
					h._fail("%s: star %d drawn at %s, the pair has it at %s (t %.0f)" % [at, sp, sv.position, view.star_screen(sp), view.t])
			# ITS MOONS AT THE NEAR POINT: over its sun with it in front, hidden
			# with it behind (only where its centre is inside the sun's hole)
			if mooned and _in_hole(view, w.host_id, view.world_c(w.index)):
				var has := false
				for mm: Dictionary in view._moons.positions(0.0):
					if int(mm.i) == w.index:
						has = true
						break
				if in_front:
					_tally("moons: in front of its sun, inside its hole")
					if not has:
						_tally("moons: hidden in front of its sun")
						h._fail("%s: world %d's moons hidden in front of its sun at t %.0f" % [at, w.index, view.t])
				else:
					_tally("moons: behind its sun, inside its hole")
					if has:
						_tally("moons: shown behind its sun")
						h._fail("%s: world %d's moons shown behind its sun at t %.0f" % [at, w.index, view.t])
			if not ok:
				_tally("depth order: drawn on the wrong side of its sun")
				h._fail("%s: world %d drawn %s its sun at t %.0f (%s it)" % [at, w.index, "over" if wv.get_index() > sn.get_index() else "under", view.t, "in front of" if in_front else "behind"])
				break
		# THE LIGHT, from its own star, where the pair has both now
		var p: Vector2 = view.pos[w.index]
		var share: float = view.share_b(p)
		var own := share if w.host_id == SystemLayout.STAR_B else 1.0 - share
		_least("light: a world round one star, its own star's share of its light", own, at)
		_most("light: a world round one star, its own star's share of its light, most", own, at)
		var toward: Vector2 = (L.star_pos(w.host_id, float(view.t)) - p).normalized()
		var lit: Vector2 = SystemViewS.toward_light_of(L, p, float(view.t))
		_least("light: a world round one star, cos of its light's angle off the way to its sun", lit.dot(toward), at)
		if lit.dot(toward) < 0.9:
			h._fail("%s: world %d lit from %.0f degrees off its own sun" % [at, w.index, rad_to_deg(acos(clampf(lit.dot(toward), -1.0, 1.0)))])
		_tally("light: worlds round a star checked")
		if not ring:
			continue
		# THE SHIP ON ITS RING, at the opening zoom and at 1: how much of the ride its
		# centre spends inside the world's drawn disc
		for zz: float in [view.zoom, 1.0]:
			var orb: float = fl.orbit_r(w.index)
			var rd: float = SystemLayout.held_most(SystemLayout.world_drawn(w, zz), minf(SystemLayout.WORLD_FLOOR, SystemLayout.world_drawn(w, zz)))
			var inside := 0
			for j in 72:
				var aj := float(j) / 72.0 * TAU
				var off := Vector2(cos(aj) * orb, sin(aj) * orb * SystemViewS.TILT) * zz
				if off.length() < rd:
					inside += 1
			var key := "opening zoom" if zz != 1.0 else "zoom 1"
			_least("ship on a world's ring round one star, share of the ride inside the drawn disc (%s)" % key, float(inside) / 72.0, at)
			_most("ship on a world's ring round one star, share of the ride inside the drawn disc, most (%s)" % key, float(inside) / 72.0, at)
			_least("ship on a world's ring round one star, ring across over the drawn disc (%s)" % key, orb * zz / rd, at)
			_tally("ship: rings measured (%s)" % key)
			_tally("ship: ride samples inside the disc (%s)" % key, inside)
			_tally("ship: ride samples (%s)" % key, 72)
	# THE ORBITS ROUND THEIR OWN CENTRES, at the opening zoom
	if not orbits:
		return
	_tally("orbits: pair phases read")
	view.t = t0 + 37.0
	view.step()
	view.step()
	var runs: Array = view._lines.orbit_runs(false)
	var own_pts := {}
	var stray := 0
	var n_pts := 0
	for run: Array in runs:
		for q: Vector2 in run[0]:
			n_pts += 1
			var best := INF
			var bi := -1
			for b in L.bodies:
				if b.kind == &"belt":
					continue
				var c: Vector2 = view.screen(b.host_at(float(view.t)).x, b.host_at(float(view.t)).y)
				var zv: float = view.zoom
				var e: Vector2 = (q - c) / Vector2(b.orbit * zv, b.orbit * zv * SystemViewS.TILT)
				var d: float = absf(e.length() - 1.0) * b.orbit * float(view.zoom) * SystemViewS.TILT
				if d < best:
					best = d
					bi = b.index
			if best > 1.0:
				stray += 1
			else:
				own_pts[bi] = int(own_pts.get(bi, 0)) + 1
			# A STAR'S HOLE ONLY BEHIND IT: a point drawn inside a star's hole is in
			# front of that star. (The point's z on the plane from its screen row:
			# whole pixels, so half a pixel either way, and points within a pixel
			# of the star's own depth are not judged. And the hole a pixel smaller:
			# `orbit_runs` cuts by the point before it is rounded to its pixel,
			# which moves it up to 0.71 px -- judged by the rounded point, 28 of
			# 3,750 drawn just outside the hole's edge read as inside it.)
			var zq: float = (q.y - (float(SystemViewS.CY) + float(view.pan.y))) / (SystemViewS.TILT * float(view.zoom))
			var tol: float = 1.0 / (SystemViewS.TILT * float(view.zoom))
			for sp: int in L.stars():
				if not _in_hole(view, sp, q, -1.0):
					continue
				var dz: float = zq - float(view.star_depth(sp))
				if dz > tol:
					_tally("orbits: points drawn in front of a star, inside its hole")
				elif dz < -tol:
					_tally("orbits: points drawn behind a star, inside its hole")
					h._fail("%s: an orbit point drawn behind star %d inside its disc (%.0f, %.0f)" % [at, sp, q.x, q.y])
	_tally("orbits: points checked", n_pts)
	_tally("orbits: points on no body's ring about its own centre", stray)
	for w in L.bodies:
		if w.world != &"" and SystemLayout.is_star(w.host_id):
			_tally("orbits: worlds round a star")
			if int(own_pts.get(w.index, 0)) < 8:
				h._fail("%s: world %d round a star has %d points on its own ring" % [at, w.index, int(own_pts.get(w.index, 0))])


## Whether screen point q is inside star p's hole in the lines and the moons
## (`_Lines._star_hole` / `_star2_hole`, round the star as drawn), the hole
## grown by `grow` px.
static func _in_hole(view, p: int, q: Vector2, grow := 0.0) -> bool:
	var hole: Vector2 = view._lines._star_hole() if p != SystemLayout.STAR_B else view._lines._star2_hole()
	if hole.x <= 0.0:
		return false
	hole += Vector2(grow, grow)
	var o: Vector2 = view.star_screen(p)
	return pow((q.x - o.x) / hole.x, 2.0) + pow((q.y - o.y) / hole.y, 2.0) < 1.0


## THE SUN FLOOR AS THE MAP DRAWS IT: from the fit, still, a zoom out over 24
## frames to 0.6 of the fit, then jumps to 0.683 (the worst comer's), 0.8 and
## 0.95 of it, each held until it has settled and 20 frames on -- on every
## frame, each sun's disc and corona as its own SunView has them (`_kd`, `_k`),
## in plane px, never wider than the layout's sun at the fit: the disc than the
## most it is held at there (`SystemLayout.held_most`), the corona than that or
## its true size there, whichever is more (the corona is the true size while the
## zoom moves and eases onto the disc once it is still). Counted in frames, never
## the clock: `step` measures its settle in its own frame steps.
func _view_floor(view, at: String) -> void:
	var L: SystemLayout = view.layout
	var fz: float = L.fit_zoom
	if fz <= 0.0:
		h._fail("%s: a twin with no fit_zoom" % at)
		return
	# (headless never cuts a palette, and the corona is drawn at its true size
	# while the zoom moves only once one is cut: without this the frames below
	# would only ever see the disc)
	view._palette_built = true
	var bound := {}
	for p in L.stars():
		var tf := SystemLayout.sun_drawn(L.star_radius(p), fz)
		var hf := SystemLayout.held_most(tf, SystemLayout.SUN_LEAST)
		bound[p] = Vector2(hf / fz, maxf(tf, hf) / fz)
	view.zoom = fz
	_settle(view)
	for k in 24:
		view.zoom = lerpf(fz, 0.6 * fz, float(k + 1) / 24.0)
		view.step()
		_floor_frame(view, bound, at)
	for f: float in [0.6, 0.683, 0.8, 0.95]:
		view.zoom = f * fz
		# (the jump seen by its first frame, then held until it settles)
		view.step()
		_floor_frame(view, bound, at)
		var n := 0
		while n < 200 and bool(view.zooming()):
			view.step()
			_floor_frame(view, bound, at)
			n += 1
		for k in 20:
			view.step()
			_floor_frame(view, bound, at)
	view.zoom = SystemLayout.open_zoom(L.edge)
	_settle(view)


## Step the map until its zoom has settled (at most 200 frames) and 20 on.
static func _settle(view) -> void:
	var n := 0
	view.step()
	while n < 200 and bool(view.zooming()):
		view.step()
		n += 1
	for k in 20:
		view.step()


## One frame of `_view_floor`: both suns as drawn against the fit's.
func _floor_frame(view, bound: Dictionary, at: String) -> void:
	var L: SystemLayout = view.layout
	var zf: float = view.zoom
	var moving: bool = view.zooming()
	for p in L.stars():
		var sv: Node2D = view.star2 if p == SystemLayout.STAR_B else view.star
		if sv == null:
			h._fail("%s: star %d has no painter" % [at, p])
			continue
		var r := L.star_radius(p)
		var disc := r * float(sv.get("_kd")) / zf
		var cor := r * float(sv.get("_k")) / zf
		var bd: Vector2 = bound[p]
		_tally("sun floor as drawn: suns checked")
		_tally("sun floor as drawn: suns checked while the zoom moved" if moving else "sun floor as drawn: suns checked at rest")
		_most("sun floor as drawn: disc on the plane over the most it is held at the fit", disc / bd.x, at)
		_most("sun floor as drawn: corona on the plane over the most it is drawn at the fit", cor / bd.y, at)
		if disc > bd.x + 1e-4 or cor > bd.y + 1e-4:
			_tally("sun floor as drawn: a sun wider on the plane than at the fit")
			if int(_n.get("sun floor as drawn: a sun wider on the plane than at the fit", 0)) <= 5:
				h._fail("%s: star %d at zoom %.3f (fit %.3f) drawn %.2f plane px (disc), %.2f (corona), against %.2f / %.2f at the fit" % [at, p, zf, L.fit_zoom, disc, cor, bd.x, bd.y])


func _view_verdict(seen: int) -> void:
	h._ok("drawn and checked %d twins" % seen, seen > 20 and int(_n.get("views", 0)) == seen)
	var fc := int(_n.get("sun floor as drawn: suns checked", 0))
	var fm := int(_n.get("sun floor as drawn: suns checked while the zoom moved", 0))
	var fs := int(_n.get("sun floor as drawn: suns checked at rest", 0))
	var fw := int(_n.get("sun floor as drawn: a sun wider on the plane than at the fit", 0))
	h._ok("below the fit no sun is drawn wider on the plane than at the fit, as the map draws it (%d suns: %d while the zoom moved, %d at rest; %d wider)" % [fc, fm, fs, fw],
		fm > 1000 and fs > 1000 and fw == 0)
	var fr := int(_n.get("orbits: points drawn in front of a star, inside its hole", 0))
	var bh := int(_n.get("orbits: points drawn behind a star, inside its hole", 0))
	h._ok("every orbit point drawn inside a star's disc is in front of it (%d in front, %d behind)" % [fr, bh], fr > 1000 and bh == 0)
	var mf := int(_n.get("moons: in front of its sun, inside its hole", 0))
	var mh := int(_n.get("moons: hidden in front of its sun", 0))
	var mb := int(_n.get("moons: behind its sun, inside its hole", 0))
	var ms := int(_n.get("moons: shown behind its sun", 0))
	h._ok("a world's moons drawn over its sun with it in front, hidden with it behind (%d moments in front, %d hidden; %d behind, %d shown)" % [mf, mh, mb, ms],
		mf > 100 and mb > 100 and mh == 0 and ms == 0)
	var np := int(_n.get("pair phases drawn", 0))
	# (every pair turns but where a harness holds them still, `pair=0`)
	var turning := SystemLayout.pair_speed() > 0.0
	h._ok("each pair drawn at %d angles round its lap%s (%d in all)" % [PHASES, "" if turning else ", held still at its one", np],
		np == int(_n.get("pair phases wanted", 0)) and np == seen * (PHASES if turning else 1))
	var ds := int(_n.get("depth order: the two suns, moments checked", 0))
	h._ok("the near sun drawn over the far one at every angle of the pair (%d moments, %d wrong)" % [ds, int(_n.get("depth order: the far sun drawn over the near one", 0))],
		ds > 500 and int(_n.get("depth order: the far sun drawn over the near one", 0)) == 0)
	var dp := int(_n.get("suns: drawn places checked", 0))
	h._ok("each sun drawn where the pair has it (%d, %d off)" % [dp, int(_n.get("suns: drawn off their place", 0))],
		dp > 1000 and int(_n.get("suns: drawn off their place", 0)) == 0)
	var dm := int(_n.get("depth order: world round a star, moments checked", 0))
	h._ok("each world round a star drawn on the right side of its sun (%d moments, %d wrong)" % [dm, int(_n.get("depth order: drawn on the wrong side of its sun", 0))],
		dm > 500 and int(_n.get("depth order: drawn on the wrong side of its sun", 0)) == 0)
	var op := int(_n.get("orbits: points checked", 0))
	h._ok("every drawn orbit point on a ring about its own centre (%d points, %d stray, %d worlds round a star)" % [op,
		int(_n.get("orbits: points on no body's ring about its own centre", 0)), int(_n.get("orbits: worlds round a star", 0))],
		op > 10000 and int(_n.get("orbits: points on no body's ring about its own centre", 0)) == 0)
	h._ok("worlds round one star lit from it (%d worlds)" % int(_n.get("light: worlds round a star checked", 0)), int(_n.get("light: worlds round a star checked", 0)) > 40)
	for key: String in ["opening zoom", "zoom 1"]:
		print("  twindrawtest: the ship on a world's 20 px ring, %s: its centre inside the world's drawn disc for %d of %d moments of the ride (%.0f%%), over %d rings" % [key,
			int(_n.get("ship: ride samples inside the disc (%s)" % key, 0)), int(_n.get("ship: ride samples (%s)" % key, 0)),
			100.0 * float(_n.get("ship: ride samples inside the disc (%s)" % key, 0)) / maxf(1.0, float(_n.get("ship: ride samples (%s)" % key, 0))),
			int(_n.get("ship: rings measured (%s)" % key, 0))])


func _report() -> void:
	var keys := _st.keys()
	keys.sort()
	for k: String in keys:
		print("  %s: %.3f (%s)" % [k, float(_st[k][0]), _st[k][1]])
	var nk := _n.keys()
	nk.sort()
	for k: String in nk:
		print("  count %s: %d" % [k, int(_n[k])])


# ---------------------------------------------------------------- PAINTED
## PAINTED'S SILHOUETTES FACE THE LIGHT THE CLOUD IS LIT BY (Nov 1; they faced
## star A alone, "SectorPainted's rims face star A only"): its paint pass
## (`sector_b_paint`) outlines the cloud where it meets the sky, a rim on the
## side toward the light and an outline on the side away. The other styles light
## that cloud by both suns (`sky_nebula`'s `light_at`), and each world by its own
## one light (checked above for every style: `toward_light_of`, which the world's
## shader takes in PAINTED too). Headless compiles no shader, so this reads the
## numbers each pass is given: in a twin the paint pass gets star B's place on
## screen, its brightness and the light's reach, the same as the cloud's; with
## one sun it gets none of them, and its shader keeps its defaults (star B's
## brightness 0: star A's way alone, worked out as before). And a moon's
## brightest step is warmed by its own world's light (`tint_at`), as the world's
## is; with one sun by the star's, as before.
func _painted() -> void:
	var was: StringName = DisplaySettings.render_style
	DisplaySettings.render_style = SystemViewS.STYLE_PAINTED
	var sh := load("res://shaders/sector_b_paint.gdshader") as Shader
	var names := PackedStringArray()
	for u: Dictionary in sh.get_shader_uniform_list():
		names.append(String(u.get("name", "")))
	print("  twindrawtest: sector_b_paint's uniforms as this build reads them (%d): star2_at %s, star2_k %s, light_lz %s" % [names.size(),
		"star2_at" in names, "star2_k" in names, "light_lz" in names])
	var twins := 0
	var clouded := 0
	var ones := 0
	var bad: Array[String] = []
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	for raw in Run.map:
		var nd: MapGen.MapNode = raw
		if nd.type != MapGen.NodeType.SYSTEM or (nd.twin and twins >= 6) or (not nd.twin and ones >= 4):
			continue
		# (at most four twins of a clear sky: the rest have a cloud to hold the
		# silhouettes' light against)
		if nd.twin and twins - clouded >= 4 and not SkyBakeS.look_for(nd, "ORDINARY").has("neb"):
			continue
		var view: SystemViewS = SystemViewS.new()
		add_child(view)
		await view.show_system(nd)
		view.window = Rect2(0, 0, 960, 540)
		var L: SystemLayout = view.layout
		view.zoom = SystemLayout.open_zoom(L.edge)
		view.home_zoom = view.zoom
		view.pan = Vector2(18.0, -12.0)
		# (a pair three eighths of the way round its lap from where it was laid out:
		# the pair turns, so star A is off the plane's origin)
		view.t = 30.0 + (TAU / L.pair_n * 0.375 if L.pair_n > 0.0 else 0.0)
		view.step()
		var at := "%s (%s)" % [MapGen.star_name(nd), "two suns" if L.twin else "one sun"]
		var pt: Dictionary = view._pt
		if not view.painted or pt.is_empty():
			bad.append("%s: no painted pass" % at)
			view.queue_free()
			continue
		var mp: ShaderMaterial = pt.paint
		var a_at: Variant = mp.get_shader_parameter("star_at")
		# (one sun: at its disc, `origin`, as before; two: where star A truly is,
		# `star_exact`, as the cloud's light has it -- the pair turns)
		var a_want: Vector2 = view.star_exact(-1) if L.twin else view.origin()
		if a_at != a_want:
			bad.append("%s: star A at %s, it is at %s" % [at, a_at, a_want])
		var moon_was: Color = SectorPaintedS.mix_ok(Color(String(Worlds.RAMP[&"moon"][5])), _srgb(view.star_light()), 0.3)
		if (pt.moon as Array)[7] != moon_was:
			bad.append("%s: the moons' brightest step %s, was %s" % [at, (pt.moon as Array)[7], moon_was])
		if not L.twin:
			ones += 1
			for k: String in ["star2_at", "star2_k", "light_lz"]:
				if mp.get_shader_parameter(k) != null:
					bad.append("%s: one sun given %s %s" % [at, k, mp.get_shader_parameter(k)])
			view.queue_free()
			continue
		twins += 1
		var sb: Vector2 = view.star_exact(SystemLayout.STAR_B)
		var k2: Variant = mp.get_shader_parameter("star2_k")
		var lz: Variant = mp.get_shader_parameter("light_lz")
		if mp.get_shader_parameter("star2_at") != sb or k2 == null or absf(float(k2 if k2 != null else 0.0) - view.star2_light_k()) > 1e-6 or float(k2 if k2 != null else 0.0) <= 0.0:
			bad.append("%s: star B given %s, %s (its disc %s, its light %.3f)" % [at, mp.get_shader_parameter("star2_at"), k2, sb, view.star2_light_k()])
		# THE CLOUD'S OWN LIGHT, as `sky_nebula` is given it this frame: star B's
		# place (the cloud's unrounded, the silhouettes' its disc's, within the
		# 2 px block), the light's reach from its own lzoom, home_zoom and lscale,
		# and star B's brightness where it has it (headless the sky's bake, which
		# gives it `star2_light_k`, is skipped: the same call then). A clear sky
		# has no cloud: the view's own numbers.
		var nm: ShaderMaterial = view._neb_mat
		var lz_c: float = view.paint_light_lz()
		if nm != null and nm.get_shader_parameter("lzoom") != null and nm.get_shader_parameter("star2_at") != null:
			clouded += 1
			lz_c = pow(maxf(float(nm.get_shader_parameter("lzoom")), 1e-3) / maxf(float(nm.get_shader_parameter("home_zoom")), 1e-3), 0.42) * float(nm.get_shader_parameter("lscale"))
			var nk: Variant = nm.get_shader_parameter("star2_k")
			if (nk != null and absf(float(nk) - float(k2 if k2 != null else 0.0)) > 1e-6) or (nm.get_shader_parameter("star2_at") as Vector2).distance_to(sb) > 1.5:
				bad.append("%s: star B on the cloud %s, %s; on the silhouettes %s, %s" % [at, nm.get_shader_parameter("star2_at"), nk, sb, k2])
			_most("painted: star B's place on the cloud against on the silhouettes, px", (nm.get_shader_parameter("star2_at") as Vector2).distance_to(sb), at)
		if lz == null or absf(float(lz) - lz_c) > 1e-5:
			bad.append("%s: the light's reach %s, the cloud's %.4f" % [at, lz, lz_c])
		# BESIDE STAR B, off its side across from star A: the silhouettes' way to
		# the light, as `sector_b_paint` works it, against the way to star B --
		# how far round toward B it has come
		var sa: Vector2 = view.star_exact(-1)
		var perp := (sb - sa).orthogonal().normalized()
		var k2f: float = float(k2) if k2 != null else 0.0
		var lzf: float = float(lz) if lz != null else 1.0
		for side: float in [1.0, -1.0]:
			var px: Vector2 = sb + perp * side * (view.star_disc(SystemLayout.STAR_B) + 6.0)
			var to_b := (sb - px).normalized()
			var now := _rim_way(sa, sb, k2f, lzf, px)
			var old := _rim_way(sa, sb, 0.0, lzf, px)
			_least("painted: beside star B, cos of the silhouettes' way to the light off the way to B", now.normalized().dot(to_b), at)
			_most("painted: beside star B, cos of the silhouettes' way off the way to B, star A's alone (as it was)", old.dot(to_b), at)
			if now.normalized().dot(to_b) <= old.dot(to_b) + 0.05:
				bad.append("%s: beside star B the silhouettes face %.2f of the way to B (star A's alone %.2f)" % [at, now.normalized().dot(to_b), old.dot(to_b)])
		# A MOON OF A WORLD ROUND STAR B: its brightest step its world's light's
		for w in L.bodies:
			if w.host_id == SystemLayout.STAR_B and w.world != &"":
				var lit_b: Color = SectorPaintedS.lit_step(&"moon", view.tint_at(view.pos[w.index]))
				_most("painted: a moon of a world round star B, its brightest step from star A's (RGB distance)",
					Vector3(lit_b.r - moon_was.r, lit_b.g - moon_was.g, lit_b.b - moon_was.b).length(), at)
		view.queue_free()
	DisplaySettings.render_style = was
	h._ok("PAINTED: in %d twins (%d with a cloud, held against the cloud's own numbers) the silhouettes are given star B's place, its brightness and the light's reach, and lean toward B beside it; in %d one-sun systems none of them, star A's at its disc as before, and the moons' steps as before%s" % [
		twins, clouded, ones, "" if bad.is_empty() else ": " + "; ".join(bad.slice(0, 4))], bad.is_empty() and twins >= 4 and clouded >= 2 and ones >= 4)


## A light as the palette's colour (linear, brightest channel 1, to sRGB as
## `SectorPainted.ext_ramp` turns it).
static func _srgb(sl: Vector3) -> Color:
	return Color(pow(sl.x, 1.0 / 2.2), pow(sl.y, 1.0 / 2.2), pow(sl.z, 1.0 / 2.2))


## `sector_b_paint`'s way to the light at place-picture point px, line for line.
static func _rim_way(sa: Vector2, sb: Vector2, k2: float, lz: float, px: Vector2) -> Vector2:
	var to_s := sa - px
	to_s /= maxf(to_s.length(), 1.0)
	if k2 <= 0.0:
		return to_s
	var to1 := sa - px
	var to2 := sb - px
	var q1 := (to1 * Vector2(1.0, 1.15)).length() / (maxf(lz, 1e-3) * 155.0)
	var q2 := (to2 * Vector2(1.0, 1.15)).length() / (maxf(lz, 1e-3) * 155.0)
	var j1 := 1.0 / (1.0 + q1 * q1)
	var j2 := k2 / (1.0 + q2 * q2)
	return (to_s * j1 + to2 / maxf(to2.length(), 1.0) * j2) / maxf(j1 + j2, 1e-4)


# ---------------------------------------------------------------- LOCAL

## LOCAL in twin `n` with the ship parked at a world round each star and at each
## star's close orbit, as the map leaves it (`SystemMapScreen._parked`), as far
## as a headless build goes (`LocalSky._situate` and the reads off it).
func _local_checks(n: MapGen.MapNode, at: String) -> void:
	var L := SystemLayout.of(n)
	if not L.twin:
		h._fail("%s: a twin node laid out with one sun" % at)
		return
	var wa := -1
	var wb := -1
	for b in L.bodies:
		if b.world == &"":
			continue
		if b.host_id == -1 and wa < 0:
			wa = b.index
		elif b.host_id == SystemLayout.STAR_B and wb < 0:
			wb = b.index
	# (a CLOSE PAIR has no world round one sun, `SystemLayout._close`: there
	# LOCAL is looked at in each sun's close orbit, a world's tint any world's)
	var places: Array = [[SystemLayout.STAR_B, SystemLayout.STAR_B, "B's close orbit"], [-1, -1, "A's close orbit"]]
	if L.close:
		_tally("local: close pairs")
		for b in L.bodies:
			if b.world != &"" and wb < 0:
				wb = b.index
	else:
		_tally("local: twins")
		if wa < 0 or wb < 0:
			h._fail("%s: no world round star %s" % [at, "A" if wa < 0 else "B"])
			return
		places = [[wb, SystemLayout.STAR_B, "a world round B"], places[0], [wa, -1, "a world round A"], places[1]]
	var had: Dictionary = SystemMapScreen._parked.get(n.index, {})
	for c: Array in places:
		var place: int = c[0]
		var lit_want: int = c[1]
		var what: String = c[2]
		SystemMapScreen._parked[n.index] = {"at": place, "p": Vector2(L.edge * 1.02, -210.0), "v": Vector2.ZERO, "head": 0.0, "mode": &"rail"}
		var sky := LocalSky.new()
		add_child(sky)
		sky.setup(n)
		_tally("local: places looked at")
		if sky.orbit_target != place:
			h._fail("%s: LOCAL at %s (place %d) took place %d" % [at, what, place, sky.orbit_target])
		if sky._lit != lit_want:
			h._fail("%s: LOCAL at %s lit by star %d" % [at, what, sky._lit])
		# (the distance LOCAL sizes the lit sun by: from that sun)
		_most("local: distance from the lit sun at %s, plane px" % what, sky.orbit_d, at)
		_least("local: distance from the lit sun at %s, plane px (least)" % what, sky.orbit_d, at)
		if sky.orbit_d > 120.0:
			h._fail("%s: LOCAL at %s reads %.0f px from its sun" % [at, what, sky.orbit_d])
		# the near sun the bigger, and the two drawn apart on the band
		var far := -1 if lit_want == SystemLayout.STAR_B else SystemLayout.STAR_B
		if sky.star_k_of(lit_want) * L.star_radius(lit_want) <= sky.star_k_of(far) * L.star_radius(far):
			h._fail("%s: LOCAL at %s draws the far sun as big as the near one" % [at, what])
		var ra := L.star_radius(-1) * sky.star_k_of(-1)
		var rb := L.star_radius(SystemLayout.STAR_B) * sky.star_k_of(SystemLayout.STAR_B)
		var gap := sky._sun_at(SystemLayout.STAR_B).distance_to(sky._sun_at(-1)) - ra - rb
		var kind := "a close pair's" if L.close else "a wide pair's"
		_least("local: the two suns' discs apart on the band, px", gap, at + " at " + what)
		_least("local: %s two suns' discs apart on the band, px" % kind, gap, at + " at " + what)
		_most("local: %s far sun's drawn radius over the near one's" % kind,
			sky.star_k_of(far) * L.star_radius(far) / (sky.star_k_of(lit_want) * L.star_radius(lit_want)), at + " at " + what)
		if gap <= 0.0:
			h._fail("%s: LOCAL at %s draws the two suns' discs over each other (%.1f px)" % [at, what, gap])
		if sky.star_light().is_equal_approx(SystemViewS._lin_top(SystemViewS.STAR_B_COL)) != (lit_want == SystemLayout.STAR_B):
			h._fail("%s: LOCAL at %s lit in the other sun's colour" % [at, what])
		# THE BUBBLE ROUND THE LIT SUN, clear of every band of distance from it a
		# body sweeps (`SystemView.bubble_gap`'s bands, which keep 24 px off them)
		var R := sky._bubble_r() / sky._s
		var lc := L.star_pos(lit_want, 0.0)
		for b in L.bodies:
			var hb := (b.host0 - lc).length()
			var bw := 28.0 if b.kind == &"belt" else 0.0
			var lo := maxf(0.0, absf(hb - b.orbit) - bw)
			var hi := hb + b.orbit + bw
			_tally("local: bodies' bands against the bubble")
			if R > lo - 1.0 and R < hi + 1.0:
				_tally("local: the bubble's wall through a body's band")
				h._fail("%s: LOCAL at %s: the bubble (%.0f px round the lit sun) runs through body %d's band %.0f-%.0f" % [at, what, R, b.index, lo, hi])
		# (the reads that ask for star B's SunView, which headless never makes,
		# run with a stand-in so their sums run at all: the other sun's light on
		# the gas against the lit one's, a band world's tint, the lit sun's breath)
		var stand_in := Node2D.new()
		sky.star2 = stand_in
		var k2 := sky._star2_k()
		if k2 < 0.0 or k2 > 1.0:
			h._fail("%s: LOCAL at %s: the other sun's light %.2f of the lit one's" % [at, what, k2])
		_most("local: the other sun's light on the gas against the lit one's", k2, at + " at " + what)
		var tw := sky._tint_at(L.bodies[wb].pos(0.0))
		if absf(maxf(tw.x, maxf(tw.y, tw.z)) - 1.0) > 0.02:
			h._fail("%s: LOCAL at %s: a world's tint %s, not a light" % [at, what, str(tw)])
		var br := sky._breath_lit()
		if br < 0.9 or br > 1.1:
			h._fail("%s: LOCAL at %s: the lit sun breathes at %.3f" % [at, what, br])
		sky.star2 = null
		stand_in.free()
		_tally("local: %s looked at" % what)
		remove_child(sky)
		# (freed at the frame's end, not now: anything `setup` queued for it runs first)
		sky.queue_free()
	if had.is_empty():
		SystemMapScreen._parked.erase(n.index)
	else:
		SystemMapScreen._parked[n.index] = had


func _local_verdict(seen: int) -> void:
	var places := int(_n.get("local: places looked at", 0))
	var wide := int(_n.get("local: twins", 0))
	var close := int(_n.get("local: close pairs", 0))
	h._ok("LOCAL looked at in %d twins, %d places: each world round a star and each star's close orbit; in %d of them close pairs, each star's close orbit" % [seen, places, close],
		seen > 20 and close > 0 and wide > 0 and places == 4 * wide + 2 * close)
	var nb := int(_n.get("local: bodies' bands against the bubble", 0))
	var nx := int(_n.get("local: the bubble's wall through a body's band", 0))
	h._ok("LOCAL's bubble round its lit sun clear of the bands its bodies sweep (%d bands, %d crossed)" % [nb, nx], nb > 1000 and nx == 0)
