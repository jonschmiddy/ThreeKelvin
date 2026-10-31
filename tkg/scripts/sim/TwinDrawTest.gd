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
##   * THE DEPTH ORDER (`SystemView.step`): over the twins of the four
##     systemtest seeds as rolled, each world round a star drawn after its sun
##     when it is nearer the viewer than the sun and before it when farther, at
##     24 moments round its year, for both stars;
##   * THE ORBITS ROUND THEIR OWN CENTRES (`_Lines.orbit_runs`): every point of
##     every drawn ring on some body's ring about its own host, and each world
##     round a star with points on its own;
##   * THE LIGHT: each world round one star of a pair lit from that star (the
##     share of its light, the angle of its one light against the way to it);
##   * THE SHIP ON A WORLD'S 20 px RING (`ShipFlight.orbit_r`), measured, not
##     judged: how much of its ride round a world circling one star its centre
##     spends inside the world's drawn disc, at the opening zoom and at 1.
## Prints `twindrawtest: PASS` or `twindrawtest: N FAILURES`.

const SystemViewS := preload("res://scripts/ui/sysmap/SystemView.gd")
const ShipFlightS := preload("res://scripts/ui/sysmap/ShipFlight.gd")
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
	view.queue_free()
	print("  twindrawtest: %d twins drawn and checked in %.1f s" % [seen, float(Time.get_ticks_msec() - t0) / 1000.0])
	_view_verdict(seen)
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
	var raw := r * SystemViewS.sun_raw_k(r, z, false)
	var cap := INF
	if L.twin and z < L.fit_zoom:
		raw = minf(raw, r * SystemViewS.sun_raw_k(r, L.fit_zoom, false) * z / L.fit_zoom)
		cap = SystemViewS.twin_held_cap(r, z, L.fit_zoom, false)
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
	for w in L.bodies:
		if w.world == &"" or not SystemLayout.is_star(w.host_id) or not view._views.has(w.index):
			continue
		var sn: Node2D = view.star2 if w.host_id == SystemLayout.STAR_B else view.star
		var sd: float = view.star_depth(w.host_id)
		# THE DEPTH ORDER, round its year
		for k in 24:
			view.t = w.period * float(k) / 24.0
			view.step()
			var wv: Node2D = view._views[w.index]
			var in_front: bool = (view.pos[w.index] as Vector2).y >= sd
			var ok := (wv.get_index() > sn.get_index()) == in_front
			_tally("depth order: world round a star, moments checked")
			if not ok:
				_tally("depth order: drawn on the wrong side of its sun")
				h._fail("%s: world %d drawn %s its sun at t %.0f (%s it)" % [at, w.index, "over" if wv.get_index() > sn.get_index() else "under", view.t, "in front of" if in_front else "behind"])
				break
		# THE LIGHT, from its own star
		var p: Vector2 = view.pos[w.index]
		var share: float = view.share_b(p)
		var own := share if w.host_id == SystemLayout.STAR_B else 1.0 - share
		_least("light: a world round one star, its own star's share of its light", own, at)
		_most("light: a world round one star, its own star's share of its light, most", own, at)
		var toward: Vector2 = (L.star_pos(w.host_id) - p).normalized()
		var lit: Vector2 = SystemViewS.toward_light_of(L, p)
		_least("light: a world round one star, cos of its light's angle off the way to its sun", lit.dot(toward), at)
		if lit.dot(toward) < 0.9:
			h._fail("%s: world %d lit from %.0f degrees off its own sun" % [at, w.index, rad_to_deg(acos(clampf(lit.dot(toward), -1.0, 1.0)))])
		_tally("light: worlds round a star checked")
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
	view.t = 37.0
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
				var c: Vector2 = view.screen(b.host.x, b.host.y)
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
	_tally("orbits: points checked", n_pts)
	_tally("orbits: points on no body's ring about its own centre", stray)
	for w in L.bodies:
		if w.world != &"" and SystemLayout.is_star(w.host_id):
			_tally("orbits: worlds round a star")
			if int(own_pts.get(w.index, 0)) < 8:
				h._fail("%s: world %d round a star has %d points on its own ring" % [at, w.index, int(own_pts.get(w.index, 0))])


func _view_verdict(seen: int) -> void:
	h._ok("drawn and checked %d twins" % seen, seen > 20 and int(_n.get("views", 0)) == seen)
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
