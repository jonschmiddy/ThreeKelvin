class_name FlightSolve
extends RefCounted

## THE AUTOPILOT'S FLIGHT, SOLVED under the real pull of the stars and the
## giant on map time (ruling 20, Oct 30: "Prototype: twin:A giant:A"; Phase 13
## step 2, ruled Oct 29 "flight:N clock:map"). Data in, data out: no Nodes, no
## Callables, nothing shared but the read-only `MapGravity`, so it is safe on a
## `WorkerThreadPool` task, and the same inputs always give the same flight.
##
## A FLIGHT, from where the ship is to a place:
## 1. the ride: round its ring (a world's, a star's close orbit, or any circle
##    round a fixed point) for a lead of 0 to LEAD_MAX 2.2 s, sped up by a
##    phasing burn of at most PHASE_K_MAX times the ring's pace when the point it
##    leaves from is further round (`ShipFlight._step_phase` flies it);
## 2. the departure burn, at THRUST 40 px/s^2 in one direction, from the ring's
##    own motion (velocity continuous);
## 3. the coast, integrated through the stars and the moving giant (RK4 in
##    64-bit scalars, each step ETA of the nearest pull's own time);
## 4. the arrival burn, onto the target's ring at its speed either way round
##    (or alongside a station, belt, hulk or contact, at its own motion): the
##    coast's path plus a cubic that ends exactly on the ring, its own pull at
##    most THRUST and linear in time, so the burn turns smoothly or not at all
##    (with gravity's change across it, at most THRUST_SLACK over).
## Keep-out (`MapGravity`) holds along the whole path: each step's closest
## approach on the cubic through its ends, and the arrival burn's own path.
##
## THE COST: engine work (the burns' sizes, px/s) + TIME_W x seconds from now
## to arrival. Flying inside a system costs no fuel; the cost only picks the
## path. TIME_W is the dial: more, faster flights that burn more.
##
## HOW IT IS FOUND (prototyped in tk-scratch/twin-build/solve-proto, measured):
## - conic guesses (Lambert about the star, or in a twin about the pair's
##   balance point), priced from the very point and moment the ship can leave,
##   aimed at the target ring's tangent point (where the ring's motion runs
##   along the coast's own);
## - the cheapest refined by Newton (finite differences, then Broyden) on the
##   departure velocity until the coast meets that tangent point at its time;
## - in a twin always, otherwise when no conic flies clean: a scan of real
##   departures (SCAN_ANG points round the ring x SCAN_KICKS along its motion),
##   the best refined by a minimum-norm Newton on the signed miss at the
##   coast's pass of the target (its time free: along-track timing is the
##   sensitive direction of an arc); then a second scan between the first's,
##   and a third with slower departures;
## - last, the rest of the conics as they are; at most BUDGET integrations.
##
## MEASURED (SolveTest, Oct 30, this Mac's i5-8257U; 7,884 plans: every start
## to every place at 12 line-ups in 16 real systems, the same with their giant
## at 1/10 and 1/4, and three twins by hand): found and clean in 99.9% of
## one-star plans, 99.3% with a heavy giant, 99.1% in twins; each lands on its
## ring within 0.0001 px and 0.06 px/s; the drawn coast within 0.08 px of a
## plain RK4 at SAMPLE. Planning median 14 ms one-star, 15 with a giant, 36 in
## a twin; the worst 64, 61 and 103 ms. A twin's plans are over DESIGN's
## median of 25 ms, so the game plans on a worker while the ship rides its
## ring (a plan made on a worker is the same plan, bit for bit). The
## prototype's free twin flight (world a to world b at its best line-up, 9.2
## s): 1.6 px/s in 9.4 s.
##
## USE
##   var G := MapGravity.from_layout(L)          # once per system; shareable
##   var r := FlightSolve.solve(G, dep, tgt, t)   # or (..., prefer = r.choice)
##   dep: {kind: &"ring", place: int, rt: float, ang: float, w: float}
##          place: a body index, -1 star A, SystemLayout.STAR_B, or -9 with
##          c: Vector2, a fixed centre (a settled star orbit); w signed rad/s
##        {kind: &"keep", place: int, off: Vector2}   alongside, `off` from it
##        {kind: &"free", p: Vector2, v: Vector2}
##   tgt: {kind: &"ring", place: int, R: float, V: float, sense: 0 | 1 | -1}
##          R the radius it arrives on (ShipFlight.orbit_r), V the ring speed
##          (RAIL_V 35, a star's STAR_RAIL_V 45), sense 0 either way round
##        {kind: &"keep", place: int, off: Vector2}
##   t: map time now.
## The result (`Result`) fills a ShipFlight.FlightPlan: samp from t0 (after
## the ride) SAMPLE apart, burns per sample, end {body, p, v, a, arel, rv, t,
## keep, sense} (a: the ring's own pull, relative, so the insertion that
## follows flies none), lead and lead_k for rail.phase, dur, amax, esc_t (the
## departure burn), and `choice`. Passing that choice back as `prefer` rebuilds
## the same flight exactly (one integration) while its departure is still
## ahead and the ride can reach it; otherwise it starts the search from it and
## keeps that flight if it flies, so a preview does not flip between near
## equals. `found` false: nothing clean within the budget, and no samples (the
## caller falls back); `clean` false on a found plan only if its own samples
## cut a keep-out (none in the sweeps).

const THRUST := 40.0
## an arrival burn may pull this much over THRUST where gravity's own pull
## changes across it (its cubic alone holds to THRUST)
const THRUST_SLACK := 1.1
## the arrival burn's path is checked every 0.05 s of it and kept this far
## (px) inside its keep-outs' edge: checked every 0.1 s, two arrivals onto a
## twin's close orbit cut 0.15 and 1.5 px in between the points
const BURN_PAD := 0.5
const LEAD_MAX := 2.2
## the phasing burn's top pace, in times the ring's own (today's `_lead` has no
## cap): at 4 the prototype sweeps found 98.2% of twin and heavy-giant flights
## (the ring's best point out of reach), at 8 99.1% and 99.5%
const PHASE_K_MAX := 8.0
## a flight arrives within this of now
const T_CAP := 30.0
## px/s of engine work one second of flight is worth. At 0.5 the median flight
## takes 24 s one-star, 21 s with a heavy giant and 15 s in a twin (SolveTest);
## Jon's v2 pick took 18 to 23 s
const TIME_W := 0.5
const SAMPLE := 1.0 / 240.0
## the coast's step: ETA of the nearest pull's dynamical time sqrt(r^3/GM),
## clamped; a burn's steps at most H_BURN. Measured (SolveTest): at 0.1 and
## 0.25 s the drawn coast was within 0.013 px of a plain RK4 at SAMPLE; at 0.15
## and 0.5 s within 0.08 px, in half the steps, the same flights found
const ETA := 0.15
const H_MIN := 1.0 / 120.0
const H_MAX := 0.5
const H_BURN := 0.1
## the longest arrival burn: the coast is flown on this far past a keep-out
## it breaks, for an arrival whose burn starts before it
const D2_MAX := 3.0
## how far round a pass a coast is priced from the target (px past its ring)
const NEAR := 260.0
## a coast passing within this of the ring's virtual circle is priced at its
## closest even when it does not cross it
const GRAZE := 60.0
const SCAN_ANG := 6
const SCAN_KICKS := [0.0, 15.0, 35.0, 60.0]
const SCAN_KICKS2 := [7.0, 25.0, 47.0, 80.0]
## the third look, when two find nothing: slower than the ring, and faster
const SCAN_KICKS3 := [-12.0, -22.0, 20.0, 100.0]
## integrations a plan may take: a twin's flights are short and its search
## wide (measured: the median twin plan 39, one-star 8)
const BUDGET := 140
const CONIC_TS := [6.0, 9.0, 13.0, 18.0, 24.0, 29.0]
## the conics the second stage re-solves from the real departure
const CONIC_KEEP := 6
## the version of `choice` this file writes and reads
const CHOICE_V := 1


class Result:
	extends RefCounted
	var found := false
	var clean := false
	## &"solved", &"replay" (rebuilt from `prefer`), &"warm" (searched from it)
	var kind: StringName = &"solved"
	## map time samp[0] is at (the departure, after the ride)
	var t0 := 0.0
	var lead := 0.0
	var lead_k := 1.0
	var a_dep := 0.0
	var sdt := SAMPLE
	var samp := PackedVector3Array()
	var burns := PackedByteArray()
	var dur := 0.0
	## the hardest |second difference| / SAMPLE^2 (`FlightPlan.amax`, the flame)
	var amax := 1.0
	## the departure burn's length (s)
	var esc_t := 0.0
	var end: Dictionary = {}
	var choice: Dictionary = {}
	var cost := INF
	## engine work, px/s: the departure burn and the arrival burn
	var work := 0.0
	var dv1 := 0.0
	var dv2 := 0.0
	## seconds from now to arrival, and the arrival burn's length
	var T := 0.0
	var d2 := 0.0
	## the least margin to any keep-out along the samples, px
	var clear := 0.0
	var integrations := 0
	var steps := 0
	var usec := 0
	## of usec: the conic guesses, integrating, pricing arrivals, the samples
	var us_seed := 0
	var us_int := 0
	var us_price := 0
	var us_build := 0


# ---------------------------------------------------------------- the problem
var G: MapGravity
var t_now := 0.0
## the departure: 0 ring, 1 keep, 2 free; its place's circle
var _dk := 0
var _dhx := 0.0
var _dhz := 0.0
var _dorb := 0.0
var _dn := 0.0
var _dph := 0.0
var _drt := 0.0
var _dang := 0.0
var _dw := 0.0
var _doffx := 0.0
var _doffz := 0.0
var _dpx := 0.0
var _dpz := 0.0
var _dvx := 0.0
var _dvz := 0.0
var _dplace := -9
## the target: 0 ring, 1 keep
var _tk := 0
var _thx := 0.0
var _thz := 0.0
var _torb := 0.0
var _tn := 0.0
var _tph := 0.0
var _tR := 0.0
var _tV := 0.0
var _toffx := 0.0
var _toffz := 0.0
var _tplace := -9
var _senses := PackedFloat64Array([1.0, -1.0])
var _twin := false

## a place's centre and motion (`_dep_at`, `_tgt_at` write these)
var _cx := 0.0
var _cz := 0.0
var _cvx := 0.0
var _cvz := 0.0

# ---------------------------------------------------------------- one coast
var _cT := PackedFloat64Array()
var _cX := PackedFloat64Array()
var _cZ := PackedFloat64Array()
var _cVX := PackedFloat64Array()
var _cVZ := PackedFloat64Array()
## the least keep-out margin up to each node
var _cCL := PackedFloat64Array()
var _cn := 0
var _tc0 := 0.0
var _t_bad := INF
var _n_integ := 0
var _n_steps := 0
## where the time goes (us): conic guesses, integrating, pricing arrivals, the samples
var _us_seed := 0
var _us_int := 0
var _us_price := 0
var _us_build := 0

# ---------------------------------------------------------------- the last flight flown
var _e_J := INF
var _e_td := 0.0
var _e_ad := 0.0
var _e_lead := 0.0
var _e_k := 1.0
var _e_x0 := 0.0
var _e_z0 := 0.0
var _e_vx0 := 0.0
var _e_vz0 := 0.0
var _e_dvx := 0.0
var _e_dvz := 0.0
var _e_te := 0.0
var _e_s := 1.0
var _e_phi := 0.0
var _e_d2 := 0.0
var _e_w2 := 0.0
## the arrival cubic's own top pull (THRUST, or less where gravity adds to it)
var _e_pk := THRUST
var _e_ux := 0.0
var _e_uz := 0.0
var _e_fix := false
var _e_afix := 0.0

# ---------------------------------------------------------------- the best so far
var _b_J := INF
var _b := {}


## THE FLIGHT from `dep` to `tgt` at map time t (see the head of this file).
static func solve(grav: MapGravity, dep: Dictionary, tgt: Dictionary, t: float, prefer: Dictionary = {}) -> Result:
	var fs := FlightSolve.new()
	return fs._solve(grav, dep, tgt, t, prefer)


func _solve(grav: MapGravity, dep: Dictionary, tgt: Dictionary, t: float, prefer: Dictionary) -> Result:
	var t_us := Time.get_ticks_usec()
	G = grav
	t_now = t
	_twin = G.star_x.size() > 1
	if not _setup(dep, tgt):
		var bad := Result.new()
		bad.usec = Time.get_ticks_usec() - t_us
		return bad
	var res: Result = null
	if not prefer.is_empty() and int(prefer.get("v", 0)) == CHOICE_V:
		res = _replay(prefer)
		if res == null:
			_warm(prefer)
			if _b_J < INF:
				res = _build(&"warm")
	if res == null:
		_search()
		res = _build(&"solved")
	res.integrations = _n_integ
	res.steps = _n_steps
	res.us_seed = _us_seed
	res.us_int = _us_int
	res.us_price = _us_price
	res.us_build = _us_build
	res.usec = Time.get_ticks_usec() - t_us
	return res


func _setup(dep: Dictionary, tgt: Dictionary) -> bool:
	match StringName(dep.get("kind", &"")):
		&"ring":
			_dk = 0
			if not _place_circle(int(dep.get("place", -9)), dep.get("c", Vector2.ZERO), true):
				return false
			_drt = float(dep.rt)
			_dang = float(dep.ang)
			_dw = float(dep.w)
			if absf(_dw) < 1e-6 or _drt <= 0.0:
				return false
		&"keep":
			_dk = 1
			if not _place_circle(int(dep.get("place", -9)), dep.get("c", Vector2.ZERO), true):
				return false
			var o: Vector2 = dep.get("off", Vector2.ZERO)
			_doffx = o.x
			_doffz = o.y
		&"free":
			_dk = 2
			var p: Vector2 = dep.p
			var v: Vector2 = dep.v
			_dpx = p.x
			_dpz = p.y
			_dvx = v.x
			_dvz = v.y
		_:
			return false
	match StringName(tgt.get("kind", &"")):
		&"ring":
			_tk = 0
			_tR = float(tgt.R)
			_tV = float(tgt.V)
			var sn := int(tgt.get("sense", 0))
			_senses = PackedFloat64Array([1.0, -1.0]) if sn == 0 else PackedFloat64Array([float(signi(sn))])
		&"keep":
			_tk = 1
			var o2: Vector2 = tgt.get("off", Vector2.ZERO)
			_toffx = o2.x
			_toffz = o2.y
			_senses = PackedFloat64Array([1.0])
		_:
			return false
	return _place_circle(int(tgt.get("place", -9)), tgt.get("c", Vector2.ZERO), false)


## A place's circle into the departure's (dep) or the target's fields.
func _place_circle(p: int, c: Vector2, dep: bool) -> bool:
	var hx := c.x
	var hz := c.y
	var orb := 0.0
	var n := 0.0
	var ph := 0.0
	if p >= 0:
		if p >= G.pl_hx.size():
			return false
		hx = G.pl_hx[p]
		hz = G.pl_hz[p]
		orb = G.pl_orb[p]
		n = G.pl_n[p]
		ph = G.pl_ph[p]
	elif p != -9:
		var k := G.star_index(p)
		if k < 0:
			return false
		hx = G.star_x[k]
		hz = G.star_z[k]
	if dep:
		_dplace = p
		_dhx = hx
		_dhz = hz
		_dorb = orb
		_dn = n
		_dph = ph
	else:
		_tplace = p
		_thx = hx
		_thz = hz
		_torb = orb
		_tn = n
		_tph = ph
	return true


func _dep_at(t: float) -> void:
	var a := _dph + _dn * t
	var c := cos(a)
	var s := sin(a)
	_cx = _dhx + _dorb * c
	_cz = _dhz + _dorb * s
	_cvx = -_dorb * _dn * s
	_cvz = _dorb * _dn * c


func _tgt_at(t: float) -> void:
	var a := _tph + _tn * t
	var c := cos(a)
	var s := sin(a)
	_cx = _thx + _torb * c
	_cz = _thz + _torb * s
	_cvx = -_torb * _tn * s
	_cvz = _torb * _tn * c


# ---------------------------------------------------------------- the ride and the departure
## How far round its ring the ride reaches within LEAD_MAX (rad).
func _reach() -> float:
	return absf(_dw) * LEAD_MAX * (PHASE_K_MAX + 1.0) * 0.5 - 1e-6


## The ride dang radians round at rate w (> 0): [lead, phasing k]
## (`ShipFlight._lead`'s law: up to LEAD_MAX it simply rides).
static func _lead_of(dang: float, w: float) -> PackedFloat64Array:
	var nat := dang / w
	if nat <= LEAD_MAX:
		return PackedFloat64Array([nat, 1.0])
	return PackedFloat64Array([LEAD_MAX, 1.0 + 2.0 * (dang / (w * LEAD_MAX) - 1.0)])


## The departure angle on the ring for a flight leaving along (ux, uz) relative
## to its place: the point whose ring motion runs along it, or the nearer end
## of the arc the ride reaches.
func _aligned(ux: float, uz: float) -> float:
	var dr := 1.0 if _dw >= 0.0 else -1.0
	var a := atan2(uz, ux) - dr * PI * 0.5
	var dang := fposmod(dr * (a - _dang), TAU)
	var reach := _reach()
	if dang > reach:
		a = _dang + dr * (reach if dang - reach < TAU - dang else 0.0)
	return a


## The ship on its ring at angle a after the ride there: _e_td, _e_lead, _e_k,
## _e_ad and the state _e_x0.. _e_vz0. False when the ride cannot reach it.
func _ride_to(a: float) -> bool:
	var dr := 1.0 if _dw >= 0.0 else -1.0
	var dang := fposmod(dr * (a - _dang), TAU)
	var lk := _lead_of(dang, absf(_dw))
	if lk[1] > PHASE_K_MAX + 1e-6:
		return false
	_e_lead = lk[0]
	_e_k = lk[1]
	_e_td = t_now + _e_lead
	_e_ad = a
	_dep_at(_e_td)
	var ca := cos(a)
	var sa := sin(a)
	_e_x0 = _cx + _drt * ca
	_e_z0 = _cz + _drt * sa
	_e_vx0 = _cvx - _dw * _drt * sa
	_e_vz0 = _cvz + _dw * _drt * ca
	return true


## THE DEPARTURE for leaving with velocity (ux, uz) relative to its place (free:
## absolute), from ring angle a_fix if has_fix: its state and burn into _e_*.
## On a ring the burn is centred on the point the flight leaves from: the ship
## comes off the ring half a burn sooner (as far as the ride allows), so the
## finite burn does what an instant one would there.
func _depart(ux: float, uz: float, has_fix: bool, a_fix: float) -> bool:
	_e_ux = ux
	_e_uz = uz
	_e_fix = has_fix
	_e_afix = a_fix
	if _dk == 2:
		_e_td = t_now
		_e_lead = 0.0
		_e_k = 1.0
		_e_ad = 0.0
		_e_x0 = _dpx
		_e_z0 = _dpz
		_e_vx0 = _dvx
		_e_vz0 = _dvz
		_e_dvx = ux - _dvx
		_e_dvz = uz - _dvz
		return true
	if _dk == 1:
		_e_td = t_now
		_e_lead = 0.0
		_e_k = 1.0
		_e_ad = 0.0
		_dep_at(t_now)
		_e_x0 = _cx + _doffx
		_e_z0 = _cz + _doffz
		_e_vx0 = _cvx
		_e_vz0 = _cvz
		_e_dvx = ux
		_e_dvz = uz
		return true
	var a := a_fix if has_fix else _aligned(ux, uz)
	if not _ride_to(a):
		return false
	_e_dvx = _cvx + ux - _e_vx0
	_e_dvz = _cvz + uz - _e_vz0
	var d1 := sqrt(_e_dvx * _e_dvx + _e_dvz * _e_dvz) / THRUST
	var back := minf(0.5 * d1, _e_lead)
	if back > 1e-6:
		var a_b := a - _dw * back
		var keep := [_e_td, _e_lead, _e_k, _e_ad, _e_x0, _e_z0, _e_vx0, _e_vz0, _e_dvx, _e_dvz]
		if _ride_to(a_b) and _e_td <= float(keep[0]):
			_e_dvx = _cvx + ux - _e_vx0
			_e_dvz = _cvz + uz - _e_vz0
		else:
			_e_td = float(keep[0])
			_e_lead = float(keep[1])
			_e_k = float(keep[2])
			_e_ad = float(keep[3])
			_e_x0 = float(keep[4])
			_e_z0 = float(keep[5])
			_e_vx0 = float(keep[6])
			_e_vz0 = float(keep[7])
			_e_dvx = float(keep[8])
			_e_dvz = float(keep[9])
	return true


## Fly the departure for (ux, uz) and price its arrival: the flight's cost, INF
## when it has no clean arrival. The coast stays in _c*, the flight in _e_*.
func _fly(ux: float, uz: float, has_fix: bool, a_fix: float) -> float:
	_e_J = INF
	if not _depart(ux, uz, has_fix, a_fix):
		return INF
	var t0 := Time.get_ticks_usec()
	_integrate(_e_td, _e_x0, _e_z0, _e_vx0, _e_vz0, _e_dvx, _e_dvz, t_now + T_CAP)
	var t1 := Time.get_ticks_usec()
	_price()
	_us_int += t1 - t0
	_us_price += Time.get_ticks_usec() - t1
	if _e_J < _b_J:
		_keep_best()
	return _e_J


func _keep_best() -> void:
	_b_J = _e_J
	_b = {"ux": _e_ux, "uz": _e_uz, "fix": _e_fix, "afix": _e_afix, "td": _e_td, "ad": _e_ad,
		"x0": _e_x0, "z0": _e_z0, "vx0": _e_vx0, "vz0": _e_vz0, "dvx": _e_dvx, "dvz": _e_dvz,
		"te": _e_te, "s": _e_s, "phi": _e_phi, "d2": _e_d2, "w2": _e_w2, "lead": _e_lead, "k": _e_k, "pk": _e_pk}


# ---------------------------------------------------------------- the coast
## THE FLIGHT FROM (x, z, vx, vz) AT td: a burn of (dvx, dvz) at THRUST, then the
## coast, to t_now + T_CAP (or on past a broken keep-out for D2_MAX, or out of
## the system). Fixed-step RK4 in scalars, the pull summed inline (two stars
## and a giant at most take the fast path), each step's closest approach to
## every keep-out on the cubic through its ends.
func _integrate(td: float, x: float, z: float, vx: float, vz: float, dvx: float, dvz: float, t_end: float) -> void:
	_n_integ += 1
	var cap := 4096
	if _cT.size() < cap:
		_cT.resize(cap)
		_cX.resize(cap)
		_cZ.resize(cap)
		_cVX.resize(cap)
		_cVZ.resize(cap)
		_cCL.resize(cap)
	var ns := G.star_x.size()
	var ng := G.gi_hx.size()
	var nw := G.wo_hx.size()
	var fast := ns <= 2 and ng <= 1
	var s0x := G.star_x[0] if ns > 0 else 0.0
	var s0z := G.star_z[0] if ns > 0 else 0.0
	var s0g := G.star_gm[0] if ns > 0 else 0.0
	var s0k := G.star_keep[0] if ns > 0 else 0.0
	var s1x := G.star_x[1] if ns > 1 else 0.0
	var s1z := G.star_z[1] if ns > 1 else 0.0
	var s1g := G.star_gm[1] if ns > 1 else 0.0
	var s1k := G.star_keep[1] if ns > 1 else 0.0
	var ghx := G.gi_hx[0] if ng > 0 else 0.0
	var ghz := G.gi_hz[0] if ng > 0 else 0.0
	var gor := G.gi_orb[0] if ng > 0 else 0.0
	var gnn := G.gi_n[0] if ng > 0 else 0.0
	var gph := G.gi_ph[0] if ng > 0 else 0.0
	var ggm := G.gi_gm[0] if ng > 0 else 0.0
	var gkp := G.gi_keep[0] if ng > 0 else 0.0
	var dv := sqrt(dvx * dvx + dvz * dvz)
	var d1 := dv / THRUST
	var thx := dvx / dv * THRUST if dv > 1e-9 else 0.0
	var thz := dvz / dv * THRUST if dv > 1e-9 else 0.0
	var nb := 0
	if d1 > 1e-9:
		nb = maxi(1, ceili(d1 / H_BURN))
	var hb := d1 / float(nb) if nb > 0 else 0.0
	var t := td
	var lost2 := pow(G.edge * 1.6, 2.0)
	_tc0 = td + d1
	_t_bad = INF
	var clear := INF
	_cT[0] = t
	_cX[0] = x
	_cZ[0] = z
	_cVX[0] = vx
	_cVZ[0] = vz
	_cCL[0] = INF
	var n := 1
	var k := 0
	# the giant's place at the step's start (carried from the last step's end)
	var gx0 := 0.0
	var gz0 := 0.0
	if ng > 0:
		gx0 = ghx + gor * cos(gph + gnn * t)
		gz0 = ghz + gor * sin(gph + gnn * t)
	while t < t_end - 1e-9 and n < cap:
		var h := 0.0
		var ax_t := 0.0
		var az_t := 0.0
		if k < nb:
			h = hb
			ax_t = thx
			az_t = thz
		else:
			# a tenth of the nearest pull's own time
			var tau2 := INF
			if ns > 0:
				var ex := s0x - x
				var ez := s0z - z
				var q2 := ex * ex + ez * ez
				tau2 = q2 * sqrt(q2) / s0g
			if ns > 1:
				var ex1 := s1x - x
				var ez1 := s1z - z
				var q21 := ex1 * ex1 + ez1 * ez1
				tau2 = minf(tau2, q21 * sqrt(q21) / s1g)
			if ng > 0:
				var exg := gx0 - x
				var ezg := gz0 - z
				var q2g := exg * exg + ezg * ezg
				tau2 = minf(tau2, q2g * sqrt(q2g) / ggm)
			h = clampf(ETA * sqrt(tau2), H_MIN, H_MAX)
			if t + h > t_end:
				h = t_end - t
		var hh := 0.5 * h
		# the giant at the step's middle and end
		var gxm := gx0
		var gzm := gz0
		var gx1 := gx0
		var gz1 := gz0
		if ng > 0:
			var am := gph + gnn * (t + hh)
			gxm = ghx + gor * cos(am)
			gzm = ghz + gor * sin(am)
			var a1 := gph + gnn * (t + h)
			gx1 = ghx + gor * cos(a1)
			gz1 = ghz + gor * sin(a1)
		var a1x := ax_t
		var a1z := az_t
		var a2x := ax_t
		var a2z := az_t
		var a3x := ax_t
		var a3z := az_t
		var a4x := ax_t
		var a4z := az_t
		var x2 := x + hh * vx
		var z2 := z + hh * vz
		var x3 := 0.0
		var z3 := 0.0
		var x4 := 0.0
		var z4 := 0.0
		var v2x := 0.0
		var v2z := 0.0
		var v3x := 0.0
		var v3z := 0.0
		var v4x := 0.0
		var v4z := 0.0
		if fast:
			# k1
			var dx := s0x - x
			var dz := s0z - z
			var r2 := dx * dx + dz * dz
			var f := s0g / (r2 * sqrt(r2))
			a1x += f * dx
			a1z += f * dz
			if ns > 1:
				dx = s1x - x
				dz = s1z - z
				r2 = dx * dx + dz * dz
				f = s1g / (r2 * sqrt(r2))
				a1x += f * dx
				a1z += f * dz
			if ng > 0:
				dx = gx0 - x
				dz = gz0 - z
				r2 = dx * dx + dz * dz
				f = ggm / (r2 * sqrt(r2))
				a1x += f * dx
				a1z += f * dz
			v2x = vx + hh * a1x
			v2z = vz + hh * a1z
			# k2
			dx = s0x - x2
			dz = s0z - z2
			r2 = dx * dx + dz * dz
			f = s0g / (r2 * sqrt(r2))
			a2x += f * dx
			a2z += f * dz
			if ns > 1:
				dx = s1x - x2
				dz = s1z - z2
				r2 = dx * dx + dz * dz
				f = s1g / (r2 * sqrt(r2))
				a2x += f * dx
				a2z += f * dz
			if ng > 0:
				dx = gxm - x2
				dz = gzm - z2
				r2 = dx * dx + dz * dz
				f = ggm / (r2 * sqrt(r2))
				a2x += f * dx
				a2z += f * dz
			x3 = x + hh * v2x
			z3 = z + hh * v2z
			v3x = vx + hh * a2x
			v3z = vz + hh * a2z
			# k3
			dx = s0x - x3
			dz = s0z - z3
			r2 = dx * dx + dz * dz
			f = s0g / (r2 * sqrt(r2))
			a3x += f * dx
			a3z += f * dz
			if ns > 1:
				dx = s1x - x3
				dz = s1z - z3
				r2 = dx * dx + dz * dz
				f = s1g / (r2 * sqrt(r2))
				a3x += f * dx
				a3z += f * dz
			if ng > 0:
				dx = gxm - x3
				dz = gzm - z3
				r2 = dx * dx + dz * dz
				f = ggm / (r2 * sqrt(r2))
				a3x += f * dx
				a3z += f * dz
			x4 = x + h * v3x
			z4 = z + h * v3z
			v4x = vx + h * a3x
			v4z = vz + h * a3z
			# k4
			dx = s0x - x4
			dz = s0z - z4
			r2 = dx * dx + dz * dz
			f = s0g / (r2 * sqrt(r2))
			a4x += f * dx
			a4z += f * dz
			if ns > 1:
				dx = s1x - x4
				dz = s1z - z4
				r2 = dx * dx + dz * dz
				f = s1g / (r2 * sqrt(r2))
				a4x += f * dx
				a4z += f * dz
			if ng > 0:
				dx = gx1 - x4
				dz = gz1 - z4
				r2 = dx * dx + dz * dz
				f = ggm / (r2 * sqrt(r2))
				a4x += f * dx
				a4z += f * dz
		else:
			var g1 := G.acc(x, z, t)
			a1x += g1[0]
			a1z += g1[1]
			v2x = vx + hh * a1x
			v2z = vz + hh * a1z
			var g2 := G.acc(x2, z2, t + hh)
			a2x += g2[0]
			a2z += g2[1]
			x3 = x + hh * v2x
			z3 = z + hh * v2z
			v3x = vx + hh * a2x
			v3z = vz + hh * a2z
			var g3 := G.acc(x3, z3, t + hh)
			a3x += g3[0]
			a3z += g3[1]
			x4 = x + h * v3x
			z4 = z + h * v3z
			v4x = vx + h * a3x
			v4z = vz + h * a3z
			var g4 := G.acc(x4, z4, t + h)
			a4x += g4[0]
			a4z += g4[1]
		var h6 := h / 6.0
		var nx := x + h6 * (vx + 2.0 * v2x + 2.0 * v3x + v4x)
		var nz := z + h6 * (vz + 2.0 * v2z + 2.0 * v3z + v4z)
		var nvx := vx + h6 * (a1x + 2.0 * a2x + 2.0 * a3x + a4x)
		var nvz := vz + h6 * (a1z + 2.0 * a2z + 2.0 * a3z + a4z)
		_n_steps += 1
		# KEEP-OUT between the steps: only where the step comes near enough
		var reach := h * (sqrt(vx * vx + vz * vz) + sqrt(nvx * nvx + nvz * nvz)) * 0.5 + 1.0
		var deep := false
		for j in ns:
			var ox := s0x if j == 0 else (s1x if fast else G.star_x[j])
			var oz := s0z if j == 0 else (s1z if fast else G.star_z[j])
			var kp := s0k if j == 0 else (s1k if fast else G.star_keep[j])
			var dd := sqrt((nx - ox) * (nx - ox) + (nz - oz) * (nz - oz))
			if dd < 0.5 * kp:
				deep = true
			if dd - kp < reach + 40.0:
				var m := _step_min(x, z, vx, vz, nx, nz, nvx, nvz, h, ox, oz) - kp
				clear = minf(clear, m)
				if m < 0.0 and _t_bad == INF:
					_t_bad = t
		for j in ng:
			var ox2 := gxm if j == 0 else G.giant_at(j, t + hh)[0]
			var oz2 := gzm if j == 0 else G.giant_at(j, t + hh)[1]
			var kp2 := gkp if j == 0 else G.gi_keep[j]
			var dd2 := sqrt((nx - ox2) * (nx - ox2) + (nz - oz2) * (nz - oz2))
			if dd2 < 0.5 * kp2:
				deep = true
			if dd2 - kp2 < reach + 40.0:
				var m2 := _step_min(x, z, vx, vz, nx, nz, nvx, nvz, h, ox2, oz2) - kp2
				clear = minf(clear, m2)
				if m2 < 0.0 and _t_bad == INF:
					_t_bad = t
		for j in nw:
			# (cheap first: how far the step is from the world's whole orbit)
			var rh := sqrt((nx - G.wo_hx[j]) * (nx - G.wo_hx[j]) + (nz - G.wo_hz[j]) * (nz - G.wo_hz[j]))
			var kp3: float = G.wo_keep[j]
			if absf(rh - G.wo_orb[j]) - kp3 > reach + 40.0:
				continue
			var aw := G.wo_ph[j] + G.wo_n[j] * (t + hh)
			var ox3 := G.wo_hx[j] + G.wo_orb[j] * cos(aw)
			var oz3 := G.wo_hz[j] + G.wo_orb[j] * sin(aw)
			var dd3 := sqrt((nx - ox3) * (nx - ox3) + (nz - oz3) * (nz - oz3))
			if dd3 - kp3 < reach + 40.0:
				var m3 := _step_min(x, z, vx, vz, nx, nz, nvx, nvz, h, ox3, oz3) - kp3
				clear = minf(clear, m3)
				if m3 < 0.0 and _t_bad == INF:
					_t_bad = t
		x = nx
		z = nz
		vx = nvx
		vz = nvz
		t += h
		k += 1
		gx0 = gx1
		gz0 = gz1
		_cT[n] = t
		_cX[n] = x
		_cZ[n] = z
		_cVX[n] = vx
		_cVZ[n] = vz
		_cCL[n] = clear
		n += 1
		# ON PAST A BROKEN KEEP-OUT for as long as an arrival burn lasts: an
		# arrival that starts its burn before it never flies the rest
		if _t_bad < INF and (t > _t_bad + D2_MAX or deep):
			break
		if x * x + z * z > lost2:
			break
	_cn = n


## The least distance to (ox, oz) over one step, on the cubic through its ends
## (a golden-section search where the step passes its closest).
static func _step_min(x0: float, z0: float, vx0: float, vz0: float, x1: float, z1: float, vx1: float, vz1: float, h: float, ox: float, oz: float) -> float:
	var d0 := sqrt((x0 - ox) * (x0 - ox) + (z0 - oz) * (z0 - oz))
	var dd1 := sqrt((x1 - ox) * (x1 - ox) + (z1 - oz) * (z1 - oz))
	var best := minf(d0, dd1)
	var r0 := (x0 - ox) * vx0 + (z0 - oz) * vz0
	var r1 := (x1 - ox) * vx1 + (z1 - oz) * vz1
	if r0 < 0.0 and r1 > 0.0:
		var a := 0.0
		var b := 1.0
		var g := 0.6180339887498949
		for _i in 14:
			var c := b - g * (b - a)
			var d := a + g * (b - a)
			var xc := _herm(x0, vx0, x1, vx1, h, c) - ox
			var zc := _herm(z0, vz0, z1, vz1, h, c) - oz
			var xd := _herm(x0, vx0, x1, vx1, h, d) - ox
			var zd := _herm(z0, vz0, z1, vz1, h, d) - oz
			if xc * xc + zc * zc < xd * xd + zd * zd:
				b = d
			else:
				a = c
		var u := 0.5 * (a + b)
		var xm := _herm(x0, vx0, x1, vx1, h, u) - ox
		var zm := _herm(z0, vz0, z1, vz1, h, u) - oz
		best = minf(best, sqrt(xm * xm + zm * zm))
	return best


static func _herm(p0: float, v0: float, p1: float, v1: float, h: float, u: float) -> float:
	var u2 := u * u
	var u3 := u2 * u
	return (2.0 * u3 - 3.0 * u2 + 1.0) * p0 + (u3 - 2.0 * u2 + u) * h * v0 + (-2.0 * u3 + 3.0 * u2) * p1 + (u3 - u2) * h * v1


static func _hermd(p0: float, v0: float, p1: float, v1: float, h: float, u: float) -> float:
	var u2 := u * u
	return ((6.0 * u2 - 6.0 * u) * p0 + (3.0 * u2 - 4.0 * u + 1.0) * h * v0 + (-6.0 * u2 + 6.0 * u) * p1 + (3.0 * u2 - 2.0 * u) * h * v1) / h


## The coast at time tq (inside it): [x, z, vx, vz], and the node it is after in _qk.
var _qk := 0
func _coast_at(tq: float) -> PackedFloat64Array:
	# binary search on the nodes
	var lo := 0
	var hi := _cn - 1
	while hi - lo > 1:
		var mid := (lo + hi) >> 1
		if _cT[mid] <= tq:
			lo = mid
		else:
			hi = mid
	_qk = lo
	return _coast_k(lo, tq)


func _coast_k(k: int, tq: float) -> PackedFloat64Array:
	var k1 := mini(k + 1, _cn - 1)
	var h := _cT[k1] - _cT[k]
	if h <= 0.0:
		return PackedFloat64Array([_cX[k], _cZ[k], _cVX[k], _cVZ[k]])
	var u := (tq - _cT[k]) / h
	return PackedFloat64Array([_herm(_cX[k], _cVX[k], _cX[k1], _cVX[k1], h, u), _herm(_cZ[k], _cVZ[k], _cZ[k1], _cVZ[k1], h, u),
		_hermd(_cX[k], _cVX[k], _cX[k1], _cVX[k1], h, u), _hermd(_cZ[k], _cVZ[k], _cZ[k1], _cVZ[k1], h, u)])


# ---------------------------------------------------------------- the arrival
## THE RING POINT A CONSTANT-THRUST BURN WOULD END ON from the coast's state (r,
## u) relative to the target at te, sense s: [radial mismatch g, angle phi,
## burn length d]. A constant burn of length d ends at r_T, u_T exactly when
## r_T - u_T d/2 = r - u d/2 (the virtual point q), and |r_T - u_T d/2| is the
## same all round the ring, so phi follows from q's angle and g is the miss.
## Into _vg, _vphi, _vd (it runs at every node near the target).
var _vg := 0.0
var _vphi := 0.0
var _vd := 0.0
func _virt(rx: float, rz: float, ux: float, uz: float, s: float, rounds: int = 3) -> void:
	var d := 0.0
	var phi := atan2(rz, rx)
	var R := _tR
	var V := _tV
	for _i in rounds:
		var qx := rx - ux * d * 0.5
		var qz := rz - uz * d * 0.5
		phi = atan2(qz, qx) + s * atan2(V * d * 0.5, R)
		var tx := -sin(phi) * s * V
		var tz := cos(phi) * s * V
		d = sqrt((tx - ux) * (tx - ux) + (tz - uz) * (tz - uz)) / THRUST
	var qx2 := rx - ux * d * 0.5
	var qz2 := rz - uz * d * 0.5
	_vg = sqrt(qx2 * qx2 + qz2 * qz2) - sqrt(R * R + V * d * 0.5 * V * d * 0.5)
	_vphi = phi
	_vd = d


## THE ARRIVAL BURN for a change of position (dxx, dxz) and velocity (dux, duz)
## off the coast: P(tau) = A tau^2 + B tau^3 on top of the coast, A = 3 dx -
## du d, B = du d - 2 dx; its pull (2A + 6B tau) / d^2 is linear, so at most
## THRUST (pk) means at both ends. [d, engine work], d the least that holds (a
## constant burn when dx = du d/2), or empty past 64 s.
static func _cubic_burn(dxx: float, dxz: float, dux: float, duz: float, pk: float = THRUST) -> PackedFloat64Array:
	var lo := 1e-3
	var hi := 0.05
	while _peak(dxx, dxz, dux, duz, hi) > pk:
		hi *= 2.0
		if hi > 64.0:
			return PackedFloat64Array()
	for _i in 22:
		var m := 0.5 * (lo + hi)
		if _peak(dxx, dxz, dux, duz, m) > pk:
			lo = m
		else:
			hi = m
	var d := hi
	var a0x := 6.0 * dxx - 2.0 * dux * d
	var a0z := 6.0 * dxz - 2.0 * duz * d
	var a1x := 4.0 * dux * d - 6.0 * dxx
	var a1z := 4.0 * duz * d - 6.0 * dxz
	# the work, Simpson on four intervals of the linear pull's size
	var w := 0.0
	for j in 5:
		var u := float(j) / 4.0
		var wt := 1.0 if j == 0 or j == 4 else (4.0 if j % 2 == 1 else 2.0)
		var px := a0x + (a1x - a0x) * u
		var pz := a0z + (a1z - a0z) * u
		w += wt * sqrt(px * px + pz * pz)
	return PackedFloat64Array([d, w / 12.0 / d])


static func _peak(dxx: float, dxz: float, dux: float, duz: float, d: float) -> float:
	var ax := 6.0 * dxx - 2.0 * dux * d
	var az := 6.0 * dxz - 2.0 * duz * d
	var bx := 4.0 * dux * d - 6.0 * dxx
	var bz := 4.0 * duz * d - 6.0 * dxz
	return maxf(sqrt(ax * ax + az * az), sqrt(bx * bx + bz * bz)) / (d * d)


## The arrival ending at te from the coast's state (x, z, vx, vz) there, sense
## s: [work, phi, d, dxx, dxz, dux, duz], or empty.
func _arrival(te: float, x: float, z: float, vx: float, vz: float, s: float, pk: float = THRUST) -> PackedFloat64Array:
	_tgt_at(te)
	var rx := x - _cx
	var rz := z - _cz
	var ux := vx - _cvx
	var uz := vz - _cvz
	var phi := 0.0
	var dxx := 0.0
	var dxz := 0.0
	var dux := 0.0
	var duz := 0.0
	if _tk == 1:
		dxx = _toffx - rx
		dxz = _toffz - rz
		dux = -ux
		duz = -uz
	else:
		_virt(rx, rz, ux, uz, s)
		phi = _vphi
		dxx = _tR * cos(phi) - rx
		dxz = _tR * sin(phi) - rz
		dux = -sin(phi) * s * _tV - ux
		duz = cos(phi) * s * _tV - uz
	var cb := _cubic_burn(dxx, dxz, dux, duz, pk)
	if cb.is_empty():
		return PackedFloat64Array()
	return PackedFloat64Array([cb[1], phi, cb[0], dxx, dxz, dux, duz])


## The least keep-out margin along an arrival burn's path (the coast plus the
## cubic, at n points); and into _bthr the most the engine pulls there: the
## cubic's own (2A + 6B tau) / d^2 and the change of gravity's pull between the
## coast and the burn's path (close to a star or a heavy giant it is not small).
var _bthr := 0.0
func _burn_clear(te: float, d: float, dxx: float, dxz: float, dux: float, duz: float, n: int = 16) -> float:
	var Ax := 3.0 * dxx - dux * d
	var Az := 3.0 * dxz - duz * d
	var Bx := dux * d - 2.0 * dxx
	var Bz := duz * d - 2.0 * dxz
	var least := INF
	var tb := te - d
	_bthr = 0.0
	_coast_at(tb)
	var k := _qk
	for j in range(0, n + 1):
		var tau := float(j) / float(n)
		var tq := tb + tau * d
		# (the coast walked forward, not searched for, point by point)
		while k + 2 < _cn and _cT[k + 1] <= tq:
			k += 1
		var h := _cT[k + 1] - _cT[k]
		var u := (tq - _cT[k]) / h if h > 0.0 else 0.0
		var cx := _herm(_cX[k], _cVX[k], _cX[k + 1], _cVX[k + 1], h, u)
		var cz := _herm(_cZ[k], _cVZ[k], _cZ[k + 1], _cVZ[k + 1], h, u)
		var yx := cx + Ax * tau * tau + Bx * tau * tau * tau
		var yz := cz + Az * tau * tau + Bz * tau * tau * tau
		if j > 0:
			least = minf(least, _margin(yx, yz, tq))
		var px := (2.0 * Ax + 6.0 * Bx * tau) / (d * d)
		var pz := (2.0 * Az + 6.0 * Bz * tau) / (d * d)
		# gravity's change between the coast and the burn's path, only where it
		# could matter: its gradient times how far the burn has moved it
		var off2 := (yx - cx) * (yx - cx) + (yz - cz) * (yz - cz)
		if off2 * _grad2(yx, yz, tq) > 1.0:
			_acc_at(cx, cz, tq)
			var gcx := _ax
			var gcz := _az
			_acc_at(yx, yz, tq)
			px += gcx - _ax
			pz += gcz - _az
		_bthr = maxf(_bthr, sqrt(px * px + pz * pz))
	return least


## `MapGravity.margin`, a world's place worked out only when it is near
## enough for its orbit to matter.
func _margin(x: float, z: float, t: float) -> float:
	var least := INF
	for k in G.star_x.size():
		least = minf(least, sqrt((x - G.star_x[k]) * (x - G.star_x[k]) + (z - G.star_z[k]) * (z - G.star_z[k])) - G.star_keep[k])
	for k in G.gi_hx.size():
		var a := G.gi_ph[k] + G.gi_n[k] * t
		var gx := G.gi_hx[k] + G.gi_orb[k] * cos(a) - x
		var gz := G.gi_hz[k] + G.gi_orb[k] * sin(a) - z
		least = minf(least, sqrt(gx * gx + gz * gz) - G.gi_keep[k])
	for k in G.wo_hx.size():
		var rh := sqrt((x - G.wo_hx[k]) * (x - G.wo_hx[k]) + (z - G.wo_hz[k]) * (z - G.wo_hz[k]))
		if absf(rh - G.wo_orb[k]) - G.wo_keep[k] >= least:
			continue
		var aw := G.wo_ph[k] + G.wo_n[k] * t
		var wx := G.wo_hx[k] + G.wo_orb[k] * cos(aw) - x
		var wz := G.wo_hz[k] + G.wo_orb[k] * sin(aw) - z
		least = minf(least, sqrt(wx * wx + wz * wz) - G.wo_keep[k])
	return least


## The pull at (x, z) at t into _ax, _az (`MapGravity.acc` without its array).
var _ax := 0.0
var _az := 0.0
func _acc_at(x: float, z: float, t: float) -> void:
	_ax = 0.0
	_az = 0.0
	for k in G.star_x.size():
		var dx := G.star_x[k] - x
		var dz := G.star_z[k] - z
		var r2 := dx * dx + dz * dz
		var f := G.star_gm[k] / (r2 * sqrt(r2))
		_ax += f * dx
		_az += f * dz
	for k in G.gi_hx.size():
		var a := G.gi_ph[k] + G.gi_n[k] * t
		var dx := G.gi_hx[k] + G.gi_orb[k] * cos(a) - x
		var dz := G.gi_hz[k] + G.gi_orb[k] * sin(a) - z
		var r2 := dx * dx + dz * dz
		var f := G.gi_gm[k] / (r2 * sqrt(r2))
		_ax += f * dx
		_az += f * dz


## The square of how fast the pull changes with place there (2 GM / r^3 of
## the nearest-felt body, summed loosely): an upper bound for a few px.
func _grad2(x: float, z: float, t: float) -> float:
	var g := 0.0
	for k in G.star_x.size():
		var r2 := (G.star_x[k] - x) * (G.star_x[k] - x) + (G.star_z[k] - z) * (G.star_z[k] - z)
		g += 2.0 * G.star_gm[k] / (r2 * sqrt(r2))
	for k in G.gi_hx.size():
		var a := G.gi_ph[k] + G.gi_n[k] * t
		var dx := G.gi_hx[k] + G.gi_orb[k] * cos(a) - x
		var dz := G.gi_hz[k] + G.gi_orb[k] * sin(a) - z
		var r2 := dx * dx + dz * dz
		g += 2.0 * G.gi_gm[k] / (r2 * sqrt(r2))
	return g * g


## THE CHEAPEST CLEAN ARRIVAL ON THE COAST into _e_*: where the coast's virtual
## point crosses the ring's virtual circle, or passes closest to it within
## GRAZE (for a station, belt, hulk or contact: comes closest to its spot);
## each priced by its burn, the coast clean up to the burn and the burn's own
## path clean. _e_J stays INF when there is none.
func _price() -> void:
	var t_lim := minf(_cT[_cn - 1], t_now + T_CAP)
	var ns := _senses.size()
	var keepd := _tk == 1
	# per sense: the last two g and the last node
	var g1 := PackedFloat64Array()
	var g2 := PackedFloat64Array()
	var k1 := PackedInt32Array()
	# (and whether the last g is only its lower bound)
	var ap := PackedByteArray()
	g1.resize(ns)
	g2.resize(ns)
	k1.resize(ns)
	ap.resize(ns)
	for j in ns:
		k1[j] = -1
	var cands := PackedFloat64Array()
	for k in _cn:
		var tk := _cT[k]
		if tk > t_lim:
			break
		if tk < _tc0:
			continue
		_tgt_at(tk)
		var rx := _cX[k] - _cx
		var rz := _cZ[k] - _cz
		var r := sqrt(rx * rx + rz * rz)
		if r > _tR + NEAR + sqrt(_toffx * _toffx + _toffz * _toffz):
			for j in ns:
				k1[j] = -1
			continue
		var ux := _cVX[k] - _cvx
		var uz := _cVZ[k] - _cvz
		# A LOWER BOUND ON THE MISS, cheap: the burn is at most (|u| + V) / THRUST
		# long, so the virtual point is at most |u| d/2 off the coast and the
		# virtual circle at most rho_max across. Far above GRAZE, no sense can
		# cross or graze here, and the solve is skipped (most nodes of a twin's
		# compact flights are within NEAR of everything)
		var mu := sqrt(ux * ux + uz * uz)
		var lb := 0.0
		if keepd:
			lb = sqrt((rx - _toffx) * (rx - _toffx) + (rz - _toffz) * (rz - _toffz)) - mu * mu / (2.0 * THRUST)
		else:
			var dmax := (mu + _tV) / THRUST
			lb = r - mu * dmax * 0.5 - sqrt(_tR * _tR + 0.25 * _tV * _tV * dmax * dmax)
		if lb > GRAZE + 1.0:
			for j in ns:
				if k1[j] >= 0:
					g2[j] = g1[j]
				else:
					g2[j] = INF
				g1[j] = lb
				k1[j] = k
				ap[j] = 1
			continue
		for j in ns:
			var s := _senses[j]
			var g := 0.0
			if keepd:
				var dk := sqrt(ux * ux + uz * uz) / THRUST
				var qx := rx - ux * dk * 0.5 - _toffx
				var qz := rz - uz * dk * 0.5 - _toffz
				g = sqrt(qx * qx + qz * qz)
			else:
				# (two rounds find where it crosses; the arrival takes three)
				_virt(rx, rz, ux, uz, s, 2)
				g = _vg
			if k1[j] >= 0:
				var gk1 := g1[j]
				if ap[j] == 1 and not keepd and g <= 0.0:
					# crossing from a bounded node: its own miss, for the place
					var kp := k1[j]
					_tgt_at(_cT[kp])
					_virt(_cX[kp] - _cx, _cZ[kp] - _cz, _cVX[kp] - _cvx, _cVZ[kp] - _cvz, s, 2)
					gk1 = _vg
				if not keepd and (gk1 > 0.0) != (g > 0.0):
					cands.append(float(k1[j]))
					cands.append(gk1 / (gk1 - g))
					cands.append(s)
				elif g2[j] < INF and gk1 < g2[j] and gk1 <= g and (keepd or gk1 > 0.0) and gk1 < GRAZE:
					cands.append(float(k1[j]))
					cands.append(0.0)
					cands.append(s)
				g2[j] = gk1
			else:
				g2[j] = INF
			g1[j] = g
			k1[j] = k
			ap[j] = 0
	# each candidate priced (cheap), then its path checked cheapest first, so
	# the first that is clean is the one
	var priced: Array = []
	for c in range(0, cands.size(), 3):
		var kk := int(cands[c])
		if kk + 1 >= _cn:
			continue
		var h := _cT[kk + 1] - _cT[kk]
		var te := _cT[kk] + cands[c + 1] * h
		if te > t_now + T_CAP:
			continue
		var st := _coast_k(kk, te)
		var ar := _arrival(te, st[0], st[1], st[2], st[3], cands[c + 2])
		if ar.is_empty() or te - ar[2] < _tc0 - 1e-9:
			continue
		priced.append([ar[0] + TIME_W * (te - t_now), c, te])
	priced.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]) or (float(a[0]) == float(b[0]) and int(a[1]) < int(b[1])))
	var best := INF
	for pc in priced:
		if float(pc[0]) >= best:
			break
		var c: int = pc[1]
		var kk := int(cands[c])
		var s2 := cands[c + 2]
		var te: float = pc[2]
		var st := _coast_k(kk, te)
		# WHERE GRAVITY'S PULL CHANGES ACROSS THE BURN (close to a star or a heavy
		# giant) the engine pulls more than the cubic's own: a longer, gentler
		# cubic then, its own pull cut by what it overshot, up to three times
		var pk := THRUST
		var ok := false
		var ar := PackedFloat64Array()
		var cost := INF
		for _try in 4:
			ar = _arrival(te, st[0], st[1], st[2], st[3], s2, pk)
			if ar.is_empty():
				break
			var tb := te - ar[2]
			if tb < _tc0 - 1e-9:
				break
			cost = ar[0] + TIME_W * (te - t_now)
			if cost >= best:
				break
			# the coast clean up to the burn, and the burn's own path
			_coast_at(tb)
			if _cCL[mini(_qk + 1, _cn - 1)] < 0.0:
				break
			if _burn_clear(te, ar[2], ar[3], ar[4], ar[5], ar[6], clampi(ceili(ar[2] / 0.05), 16, 64)) < BURN_PAD:
				break
			if _bthr <= THRUST * THRUST_SLACK:
				ok = true
				break
			pk *= THRUST / _bthr
		if not ok:
			continue
		best = cost
		_e_te = te
		_e_s = s2
		_e_phi = ar[1]
		_e_d2 = ar[2]
		_e_w2 = ar[0]
		_e_pk = pk
	if best < INF:
		_e_J = sqrt(_e_dvx * _e_dvx + _e_dvz * _e_dvz) + best


# ---------------------------------------------------------------- refining
## THE TANGENT POINT the coast should meet at te: the ring point (relative to
## the target) whose ring motion for sense s runs along the coast's own (u),
## and the constant burn onto it. Its miss, q - aim: [fx, fz], or empty.
func _qres(te: float, s: float) -> PackedFloat64Array:
	if te > _cT[_cn - 1] or te < _tc0:
		return PackedFloat64Array()
	var c := _coast_at(te)
	_tgt_at(te)
	var rx := c[0] - _cx
	var rz := c[1] - _cz
	var ux := c[2] - _cvx
	var uz := c[3] - _cvz
	var m := sqrt(ux * ux + uz * uz)
	if _tk == 1:
		var dk := m / THRUST
		return PackedFloat64Array([rx - ux * dk * 0.5 - _toffx, rz - uz * dk * 0.5 - _toffz])
	if m < 1e-6:
		return PackedFloat64Array()
	var hx := ux / m
	var hz := uz / m
	var phi := atan2(-s * hx, s * hz)
	var d := absf(m - _tV) / THRUST
	return PackedFloat64Array([rx - _tR * cos(phi) - (m - _tV) * hx * d * 0.5, rz - _tR * sin(phi) - (m - _tV) * hz * d * 0.5])


## NEWTON ON THE DEPARTURE so the coast meets the target ring's tangent point at
## te (the conic's arrival time): a finite-difference Jacobian, then Broyden,
## a step that does worse taken a quarter as far.
func _refine_at(ux: float, uz: float, has_fix: bool, a_fix: float, te: float, s: float, iters: int = 4) -> void:
	var fd := 1.0
	_fly(ux, uz, has_fix, a_fix)
	var F := _qres(te, s)
	if F.is_empty():
		return
	_fly(ux + fd, uz, has_fix, a_fix)
	var Fa := _qres(te, s)
	_fly(ux, uz + fd, has_fix, a_fix)
	var Fb := _qres(te, s)
	if Fa.is_empty() or Fb.is_empty():
		return
	var j11 := (Fa[0] - F[0]) / fd
	var j21 := (Fa[1] - F[1]) / fd
	var j12 := (Fb[0] - F[0]) / fd
	var j22 := (Fb[1] - F[1]) / fd
	for _it in iters:
		var det := j11 * j22 - j12 * j21
		if absf(det) < 1e-9:
			return
		var dx := -(j22 * F[0] - j12 * F[1]) / det
		var dz := -(-j21 * F[0] + j11 * F[1]) / det
		var st := sqrt(dx * dx + dz * dz)
		var lim := 0.5 * maxf(10.0, sqrt(ux * ux + uz * uz))
		if st > lim:
			dx *= lim / st
			dz *= lim / st
		_fly(ux + dx, uz + dz, has_fix, a_fix)
		var Fn := _qres(te, s)
		if Fn.is_empty() or Fn[0] * Fn[0] + Fn[1] * Fn[1] > F[0] * F[0] + F[1] * F[1]:
			dx *= 0.25
			dz *= 0.25
			_fly(ux + dx, uz + dz, has_fix, a_fix)
			Fn = _qres(te, s)
		if Fn.is_empty():
			return
		var yx := Fn[0] - F[0]
		var yz := Fn[1] - F[1]
		var jx := j11 * dx + j12 * dz
		var jz := j21 * dx + j22 * dz
		var den := dx * dx + dz * dz
		if den < 1e-18:
			return
		j11 += (yx - jx) * dx / den
		j12 += (yx - jx) * dz / den
		j21 += (yz - jz) * dx / den
		j22 += (yz - jz) * dz / den
		ux += dx
		uz += dz
		F = Fn
		if F[0] * F[0] + F[1] * F[1] < 0.09:
			return


## THE COAST'S PASS OF THE TARGET, its time free: where an arrival burn along
## its own motion would start (r.u_hat = (|u| - V) d/2), and the signed miss
## there, r.left(u_hat) + s R (0: it meets the ring's tangent point). NAN when
## it does not pass.
func _pass_miss(s: float) -> float:
	var keepd := _tk == 1
	var R := 0.0 if keepd else _tR
	var V := 0.0 if keepd else _tV
	var ox := _toffx if keepd else 0.0
	var oz := _toffz if keepd else 0.0
	var t_lim := minf(_cT[_cn - 1], t_now + T_CAP)
	var hp := NAN
	for k in _cn:
		var tk := _cT[k]
		if tk > t_lim:
			break
		if tk < _tc0:
			continue
		_tgt_at(tk)
		var rx := _cX[k] - _cx - ox
		var rz := _cZ[k] - _cz - oz
		var ux := _cVX[k] - _cvx
		var uz := _cVZ[k] - _cvz
		var mu := sqrt(ux * ux + uz * uz)
		if mu < 1e-6:
			hp = NAN
			continue
		var d := absf(mu - V) / THRUST
		var hcur := (rx * ux + rz * uz) / mu - (mu - V) * d * 0.5
		if not is_nan(hp) and hp < 0.0 and hcur >= 0.0:
			var u := hp / (hp - hcur)
			var tq := _cT[k - 1] + u * (tk - _cT[k - 1])
			var c := _coast_k(k - 1, tq)
			_tgt_at(tq)
			var qx := c[0] - _cx - ox
			var qz := c[1] - _cz - oz
			var wx := c[2] - _cvx
			var wz := c[3] - _cvz
			var mw := sqrt(wx * wx + wz * wz)
			if mw < 1e-6:
				return NAN
			return (-qx * wz + qz * wx) / mw + s * R
		hp = hcur
	return NAN


## MINIMUM-NORM NEWTON on the signed miss at the pass (one number, its time
## free), from a scanned departure: the step along the miss's gradient that
## clears it, the gradient by finite differences and then Broyden.
func _refine_pass(ux: float, uz: float, has_fix: bool, a_fix: float, s: float, iters: int = 5) -> void:
	var fd := 1.0
	_fly(ux, uz, has_fix, a_fix)
	var m := _pass_miss(s)
	if is_nan(m):
		return
	_fly(ux + fd, uz, has_fix, a_fix)
	var ma := _pass_miss(s)
	_fly(ux, uz + fd, has_fix, a_fix)
	var mb := _pass_miss(s)
	if is_nan(ma) or is_nan(mb):
		return
	var gx := (ma - m) / fd
	var gz := (mb - m) / fd
	for _it in iters:
		var g2 := gx * gx + gz * gz
		if g2 < 1e-12:
			return
		var dx := -m * gx / g2
		var dz := -m * gz / g2
		var st := sqrt(dx * dx + dz * dz)
		var lim := 0.5 * maxf(10.0, sqrt(ux * ux + uz * uz))
		if st > lim:
			dx *= lim / st
			dz *= lim / st
		_fly(ux + dx, uz + dz, has_fix, a_fix)
		var mn := _pass_miss(s)
		if is_nan(mn) or absf(mn) > absf(m):
			dx *= 0.25
			dz *= 0.25
			_fly(ux + dx, uz + dz, has_fix, a_fix)
			mn = _pass_miss(s)
		if is_nan(mn):
			return
		var den := dx * dx + dz * dz
		if den < 1e-18:
			return
		var e := (mn - m) - (gx * dx + gz * dz)
		gx += e * dx / den
		gz += e * dz / den
		ux += dx
		uz += dz
		m = mn
		if absf(m) < 0.3:
			return


## At the coast's closest pass of the target: [distance, the sense it passes in].
func _pass_side() -> PackedFloat64Array:
	var best := INF
	var sb := 1.0
	var ox := _toffx if _tk == 1 else 0.0
	var oz := _toffz if _tk == 1 else 0.0
	for k in _cn:
		if _cT[k] < _tc0:
			continue
		_tgt_at(_cT[k])
		var rx := _cX[k] - _cx - ox
		var rz := _cZ[k] - _cz - oz
		var d := sqrt(rx * rx + rz * rz)
		if d < best:
			best = d
			var lf := -rx * (_cVZ[k] - _cvz) + rz * (_cVX[k] - _cvx)
			sb = -1.0 if lf > 0.0 else 1.0
	return PackedFloat64Array([best, sb])


# ---------------------------------------------------------------- the search
## Every way it tries, cheapest kept in _b, within BUDGET integrations.
func _search() -> void:
	var t0 := Time.get_ticks_usec()
	var seeds := _seeds()
	_us_seed += Time.get_ticks_usec() - t0
	var nsd := floori(seeds.size() / 9.0)
	# the cheapest conic, refined; the next two as they are
	if nsd > 0:
		_refine_at(seeds[1], seeds[2], seeds[6] > 0.5, seeds[7], seeds[8], seeds[5])
	if not _twin:
		for i in range(1, mini(3, nsd)):
			_fly(seeds[i * 9 + 1], seeds[i * 9 + 2], seeds[i * 9 + 6] > 0.5, seeds[i * 9 + 7])
		if _b_J < INF:
			return
	# A SCAN OF REAL DEPARTURES (in a twin always: its cheap flights come from the
	# two stars' pull, which no conic sees), the best refined at their pass
	for pass_i in 3:
		var kicks: Array = [SCAN_KICKS, SCAN_KICKS2, SCAN_KICKS3][pass_i]
		var scan := _scan([0.0, 0.5, 0.25][pass_i], kicks)
		var rows: Array = []
		for i in range(0, scan.size(), 4):
			if _n_integ >= BUDGET:
				break
			var jj := _fly(scan[i], scan[i + 1], scan[i + 2] > 0.5, scan[i + 3])
			var side := _pass_side()
			var sc := jj if jj < INF else 1e8 + side[0]
			rows.append([sc, i, _e_s if jj < INF else side[1]])
		rows.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]) or (float(a[0]) == float(b[0]) and int(a[1]) < int(b[1])))
		var nfix := 2 if pass_i == 0 else 3
		for r in rows.slice(0, nfix):
			if _n_integ >= BUDGET:
				break
			var i2: int = r[1]
			_refine_pass(scan[i2], scan[i2 + 1], scan[i2 + 2] > 0.5, scan[i2 + 3], float(r[2]) if _tk == 0 else 1.0)
		if _b_J < INF:
			return
	# last, the rest of the conics as they are
	for i in range(1, nsd):
		if _n_integ >= BUDGET:
			return
		_fly(seeds[i * 9 + 1], seeds[i * 9 + 2], seeds[i * 9 + 6] > 0.5, seeds[i * 9 + 7])


## Departures to fly as they are: round a ring, SCAN_ANG points across what the
## ride reaches (shifted `off` of a step), each leaving along its ring motion
## plus each kick; free or alongside, its own motion and each kick in eight
## directions. Flat: [ux, uz, has_fix, a_fix] each.
func _scan(off: float, kicks: Array) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	if _dk == 0:
		var dr := 1.0 if _dw >= 0.0 else -1.0
		var reach := _reach()
		for j in SCAN_ANG:
			var f := (float(j) + off) / float(SCAN_ANG - 1)
			if f > 1.0:
				continue
			var a := _dang + dr * reach * f
			if not _ride_to(a):
				continue
			var ux := _e_vx0 - _cvx
			var uz := _e_vz0 - _cvz
			var m := sqrt(ux * ux + uz * uz)
			for kk in kicks:
				var fk := (m + float(kk)) / m
				if fk <= 0.05:
					continue
				out.append_array(PackedFloat64Array([ux * fk, uz * fk, 1.0, a]))
	else:
		var vx := _dvx if _dk == 2 else 0.0
		var vz := _dvz if _dk == 2 else 0.0
		if off == 0.0:
			out.append_array(PackedFloat64Array([vx, vz, 0.0, 0.0]))
		for kk in kicks:
			if absf(float(kk)) <= 0.0:
				continue
			for j in 8:
				var hd := TAU * (float(j) + off) / 8.0
				out.append_array(PackedFloat64Array([vx + float(kk) * cos(hd), vz + float(kk) * sin(hd), 0.0, 0.0]))
	return out


# ---------------------------------------------------------------- conic guesses
## CONIC GUESSES, cheapest first, priced from where the ship can really leave.
## Stage 1 from the place's centre now (a world's ring is small beside the
## flight; round a star, from two points on its ring), every length in CONIC_TS
## and both ways round; stage 2 the CONIC_KEEP cheapest again from the very
## point and moment it would leave, aimed at the target ring's tangent point.
## Flat: [price, ux, uz, T, way, s, has_fix, a_fix, te] each.
func _seeds() -> PackedFloat64Array:
	var centres := PackedFloat64Array()
	if _twin:
		centres.append_array(PackedFloat64Array([G.bary.x, G.bary.y, SystemLayout.GM_SHIP]))
	else:
		for k in G.star_x.size():
			centres.append_array(PackedFloat64Array([G.star_x[k], G.star_z[k], G.star_gm[k]]))
	var p1s := PackedFloat64Array()
	if _dk == 2:
		p1s.append_array(PackedFloat64Array([_dpx, _dpz, 0.0, 0.0]))
	elif _dk == 0 and _dorb == 0.0:
		# a star's close orbit (or a circle round a fixed point): from the ring
		var dr := 1.0 if _dw >= 0.0 else -1.0
		for j in 2:
			var a := _dang + dr * _reach() * (float(j) + 0.5) / 2.0
			p1s.append_array(PackedFloat64Array([_dhx + _drt * cos(a), _dhz + _drt * sin(a), 0.0, 0.0]))
	else:
		_dep_at(t_now)
		var ox := _doffx if _dk == 1 else 0.0
		var oz := _doffz if _dk == 1 else 0.0
		p1s.append_array(PackedFloat64Array([_cx + ox, _cz + oz, _cvx, _cvz]))
	var rough: Array = []
	for T: float in CONIC_TS:
		for pi in range(0, p1s.size(), 4):
			for ci in range(0, centres.size(), 3):
				for way: float in [1.0, -1.0]:
					var aims := _aims(t_now + T, p1s[pi], p1s[pi + 1], centres[ci], centres[ci + 1], way)
					for ai in range(0, aims.size(), 2):
						var sol := _lambert_gm(centres[ci], centres[ci + 1], centres[ci + 2], p1s[pi], p1s[pi + 1], aims[ai], aims[ai + 1], T, way)
						if sol.is_empty():
							continue
						var pr := _price_conic(t_now + T, sol[0] - p1s[pi + 2], sol[1] - p1s[pi + 3], sol[0], sol[1], sol[2], sol[3], false, 0.0, 0.0)
						rough.append([pr + TIME_W * T, T, ci, way, pi, ai, sol[2], sol[3]])
	rough.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var out: Array = []
	for r in rough.slice(0, CONIC_KEEP):
		var T: float = r[1]
		var ci: int = r[2]
		var way: float = r[3]
		var pi: int = r[4]
		var cx := centres[ci]
		var cz := centres[ci + 1]
		var gm := centres[ci + 2]
		var aims0 := _aims(t_now + T, p1s[pi], p1s[pi + 1], cx, cz, way)
		var ai: int = r[5]
		var sol0 := _lambert_gm(cx, cz, gm, p1s[pi], p1s[pi + 1], aims0[ai], aims0[ai + 1], T, way)
		if sol0.is_empty():
			continue
		var ux := sol0[0] - p1s[pi + 2]
		var uz := sol0[1] - p1s[pi + 3]
		# where and when it really leaves
		var px := 0.0
		var pz := 0.0
		var vx := 0.0
		var vz := 0.0
		var td := t_now
		if _dk == 0:
			var a := _aligned(ux, uz)
			if not _ride_to(a):
				continue
			if _dorb == 0.0:
				# round a star too, off the ring along its motion: the point whose
				# motion runs along the conic's, found by solving again from it
				for _it in 2:
					var aa := _aims(t_now + T, _e_x0, _e_z0, cx, cz, way)
					var s2 := _lambert_gm(cx, cz, gm, _e_x0, _e_z0, aa[0], aa[1], T - _e_lead, way)
					if s2.is_empty() or T - _e_lead < 3.0:
						break
					# (a fixed centre: the conic's velocity is the one relative to it)
					ux = s2[0]
					uz = s2[1]
					if not _ride_to(_aligned(ux, uz)):
						break
			td = _e_td
			px = _e_x0
			pz = _e_z0
			vx = _e_vx0
			vz = _e_vz0
		elif _dk == 1:
			_dep_at(t_now)
			px = _cx + _doffx
			pz = _cz + _doffz
			vx = _cvx
			vz = _cvz
		else:
			px = _dpx
			pz = _dpz
			vx = _dvx
			vz = _dvz
		var Te := T - (td - t_now)
		if Te < 3.0:
			continue
		var te := td + Te
		var cvdx := 0.0
		var cvdz := 0.0
		if _dk != 2:
			_dep_at(td)
			cvdx = _cvx
			cvdz = _cvz
		_tgt_at(te)
		var u2x: float = float(r[6]) - _cvx
		var u2z: float = float(r[7]) - _cvz
		var own := _tk == 0 and _torb == 0.0 and absf(_thx - cx) < 1.0 and absf(_thz - cz) < 1.0
		for s: float in _senses:
			var aims := _aims(te, px, pz, cx, cz, way)
			var p2x := aims[0]
			var p2z := aims[1]
			if _tk == 0 and not own:
				# a ring (a world's, or a star's the conic is not about): its
				# tangent point for the conic's own arrival
				_tgt_at(te)
				var m := sqrt(u2x * u2x + u2z * u2z)
				if m < 1e-6:
					continue
				var phi := atan2(-s * u2x / m, s * u2z / m)
				p2x = _cx + _tR * cos(phi)
				p2z = _cz + _tR * sin(phi)
			var sol := _lambert_gm(cx, cz, gm, px, pz, p2x, p2z, Te, way)
			if sol.is_empty():
				continue
			var pr := _price_conic(te, sol[0] - cvdx, sol[1] - cvdz, sol[0], sol[1], sol[2], sol[3], true, vx, vz)
			out.append([pr + TIME_W * T, sol[0] - (cvdx if _dk != 2 else 0.0), sol[1] - (cvdz if _dk != 2 else 0.0), T, way, s, 0.0, 0.0, te])
	out.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var flat := PackedFloat64Array()
	for o in out:
		flat.append_array(PackedFloat64Array(o))
	return flat


## Where a conic aims at te: the target's centre (or its spot alongside); to
## a star's close orbit round this centre, the ring point most of a half lap on.
func _aims(te: float, p1x: float, p1z: float, cx: float, cz: float, way: float) -> PackedFloat64Array:
	_tgt_at(te)
	if _tk == 1:
		return PackedFloat64Array([_cx + _toffx, _cz + _toffz])
	if _torb == 0.0 and absf(_cx - cx) < 1.0 and absf(_cz - cz) < 1.0:
		var a1 := atan2(p1z - cz, p1x - cx) + way * (PI - 0.4)
		return PackedFloat64Array([cx + _tR * cos(a1), cz + _tR * sin(a1)])
	return PackedFloat64Array([_cx, _cz])


## The engine work a conic would need: leaving (aligned on a world's ring, or
## from the state given) and arriving onto the ring at its speed.
func _price_conic(te: float, ux: float, uz: float, v1x: float, v1z: float, v2x: float, v2z: float, at: bool, vx: float, vz: float) -> float:
	var c1 := 0.0
	if at:
		c1 = sqrt((v1x - vx) * (v1x - vx) + (v1z - vz) * (v1z - vz))
	elif _dk == 0:
		c1 = absf(sqrt(ux * ux + uz * uz) - absf(_dw) * _drt)
	elif _dk == 1:
		c1 = sqrt(ux * ux + uz * uz)
	else:
		c1 = sqrt((v1x - _dvx) * (v1x - _dvx) + (v1z - _dvz) * (v1z - _dvz))
	_tgt_at(te)
	var u2x := v2x - _cvx
	var u2z := v2z - _cvz
	var c2 := sqrt(u2x * u2x + u2z * u2z)
	if _tk == 0:
		c2 = absf(c2 - _tV)
	return c1 + c2


## THE CONIC about (cx, cz) of pull gm from p1 to p2 in T, way 1 counter-
## clockwise (the worlds' way), -1 clockwise: [v1x, v1z, v2x, v2z], or empty.
## Within 7 degrees of a half lap (or none) a conic has no plane: aimed as far
## round as the ring's own size, or just out of that zone.
func _lambert_gm(cx: float, cz: float, gm: float, p1x: float, p1z: float, p2x: float, p2z: float, T: float, way: float) -> PackedFloat64Array:
	var r1x := p1x - cx
	var r1z := (p1z - cz) * way
	var r2x := p2x - cx
	var r2z := (p2z - cz) * way
	var dth := fposmod(atan2(r2z, r2x) - atan2(r1z, r1x), TAU)
	if absf(sin(dth)) < 0.12:
		var rr := sqrt(r2x * r2x + r2z * r2z)
		if rr < 1.0:
			return PackedFloat64Array()
		var da0 := maxf(0.13, minf((_tR if _tk == 0 else 20.0) / rr, 0.3))
		var da := 0.0
		if absf(sin(dth + da0)) >= 0.12 and dth + da0 > 0.0 and dth + da0 < TAU:
			da = da0
		elif absf(sin(dth - da0)) >= 0.12 and dth - da0 > 0.0 and dth - da0 < TAU:
			da = -da0
		else:
			return PackedFloat64Array()
		var ca := cos(da)
		var sa := sin(da)
		var nx := r2x * ca - r2z * sa
		r2z = r2x * sa + r2z * ca
		r2x = nx
		dth += da
	var sq := sqrt(gm)
	var sol := lambert(r1x, r1z, r2x, r2z, dth, T * sq)
	if sol.is_empty():
		return sol
	return PackedFloat64Array([sol[0] * sq, sol[1] * sq * way, sol[2] * sq, sol[3] * sq * way])


## The universal variables' time of flight at z (mu 1), NAN where the conic
## does not exist (Stumpff's C and S worked out once).
static func _tof(z: float, r1: float, r2: float, A: float) -> float:
	var c := 0.5
	var sv := 1.0 / 6.0
	if z > 1e-6:
		var q := sqrt(z)
		c = (1.0 - cos(q)) / z
		sv = (q - sin(q)) / (q * q * q)
	elif z < -1e-6:
		var q2 := sqrt(-z)
		c = (cosh(q2) - 1.0) / -z
		sv = (sinh(q2) - q2) / (q2 * q2 * q2)
	var y := r1 + r2 + A * (z * sv - 1.0) / sqrt(c)
	if not (y > 0.0):
		return NAN
	var yc := y / c
	return yc * sqrt(yc) * sv + A * sqrt(y)


static func _y_of(z: float, r1: float, r2: float, A: float) -> float:
	var c := 0.5
	var sv := 1.0 / 6.0
	if z > 1e-6:
		var q := sqrt(z)
		c = (1.0 - cos(q)) / z
		sv = (q - sin(q)) / (q * q * q)
	elif z < -1e-6:
		var q2 := sqrt(-z)
		c = (cosh(q2) - 1.0) / -z
		sv = (sinh(q2) - q2) / (q2 * q2 * q2)
	return r1 + r2 + A * (z * sv - 1.0) / sqrt(c)


## LAMBERT'S PROBLEM by universal variables, mu 1, counterclockwise, in 64-bit
## scalars (`ShipFlight.lambert`'s solver, whose Vector3 inputs are 32-bit):
## the conic from r1 to r2 sweeping dth in tof: [v1x, v1z, v2x, v2z], or empty.
static func lambert(r1x: float, r1z: float, r2x: float, r2z: float, dth: float, tof: float) -> PackedFloat64Array:
	var r1 := sqrt(r1x * r1x + r1z * r1z)
	var r2 := sqrt(r2x * r2x + r2z * r2z)
	if r1 < 1.0 or r2 < 1.0:
		return PackedFloat64Array()
	var A := sin(dth) * sqrt(r1 * r2 / (1.0 - cos(dth)))
	var zhi := 4.0 * PI * PI - 1e-3
	var lo := -100.0
	var tlo := _tof(lo, r1, r2, A)
	if is_nan(tlo):
		# where the conic starts to exist: a coarse step up, then a bisection
		var prev := lo
		var found := false
		for j in range(1, 41):
			var z := -100.0 + (zhi + 100.0) * float(j) / 40.0
			if not is_nan(_tof(z, r1, r2, A)):
				var bad := prev
				var good := z
				for _e in 24:
					var mz := 0.5 * (bad + good)
					if is_nan(_tof(mz, r1, r2, A)):
						bad = mz
					else:
						good = mz
				lo = good
				tlo = _tof(lo, r1, r2, A)
				found = true
				break
			prev = z
		if not found:
			return PackedFloat64Array()
	var hi := zhi
	var thi := _tof(hi, r1, r2, A)
	if is_nan(thi) or tlo > tof or thi < tof:
		return PackedFloat64Array()
	for _it in 46:
		var m := 0.5 * (lo + hi)
		var tm := _tof(m, r1, r2, A)
		if is_nan(tm) or tm < tof:
			lo = m
		else:
			hi = m
	var zb := 0.5 * (lo + hi)
	var y := _y_of(zb, r1, r2, A)
	var fl := 1.0 - y / r1
	var g := A * sqrt(y)
	var gd := 1.0 - y / r2
	if absf(g) < 1e-9:
		return PackedFloat64Array()
	return PackedFloat64Array([(r2x - r1x * fl) / g, (r2z - r1z * fl) / g, (r2x * gd - r1x) / g, (r2z * gd - r1z) / g])


# ---------------------------------------------------------------- replay
## THE SAME FLIGHT AGAIN from its choice, one integration, every number as it
## was: round a ring, while its departure is still ahead and the ride from
## where the ship is now reaches it (the same ring); alongside, while it is
## still ahead (the ship waits there); free, at the same moment from the same
## state. Null when it cannot be.
func _replay(c: Dictionary) -> Result:
	if int(c.get("dk", -1)) != _dk or int(c.get("dp", -99)) != _dplace or int(c.get("tp", -99)) != _tplace:
		return null
	var td := float(c.td)
	var lead := td - t_now
	if lead < -1e-9:
		return null
	lead = maxf(lead, 0.0)
	var ad := float(c.get("ad", 0.0))
	var k := 1.0
	if _dk == 0:
		if absf(float(c.get("w", 0.0)) - _dw) > 1e-9 or absf(float(c.get("rt", 0.0)) - _drt) > 1e-9:
			return null
		var dr := 1.0 if _dw >= 0.0 else -1.0
		var dang := fposmod(dr * (ad - _dang), TAU)
		if lead < 1e-6:
			if dang > 1e-4 and dang < TAU - 1e-4:
				return null
		else:
			k = 2.0 * dang / (absf(_dw) * lead) - 1.0
			if k < 0.2 or k > PHASE_K_MAX:
				return null
		_dep_at(td)
		_e_x0 = _cx + _drt * cos(ad)
		_e_z0 = _cz + _drt * sin(ad)
		_e_vx0 = _cvx - _dw * _drt * sin(ad)
		_e_vz0 = _cvz + _dw * _drt * cos(ad)
	elif _dk == 1:
		_dep_at(td)
		_e_x0 = _cx + _doffx
		_e_z0 = _cz + _doffz
		_e_vx0 = _cvx
		_e_vz0 = _cvz
	else:
		if lead > 1e-9 or _dpx != float(c.get("x0", NAN)) or _dpz != float(c.get("z0", NAN)) or _dvx != float(c.get("vx0", NAN)) or _dvz != float(c.get("vz0", NAN)):
			return null
		_e_x0 = _dpx
		_e_z0 = _dpz
		_e_vx0 = _dvx
		_e_vz0 = _dvz
	_e_td = td
	_e_ad = ad
	_e_lead = lead
	_e_k = k
	_e_dvx = float(c.dvx)
	_e_dvz = float(c.dvz)
	_e_ux = float(c.get("ux", 0.0))
	_e_uz = float(c.get("uz", 0.0))
	_e_fix = bool(c.get("fix", false))
	_e_afix = float(c.get("afix", 0.0))
	_e_te = float(c.te)
	_e_s = float(c.s)
	_e_phi = float(c.get("phi", 0.0))
	_e_d2 = float(c.get("d2", 0.0))
	_e_w2 = float(c.get("w2", 0.0))
	_e_pk = float(c.get("pk", THRUST))
	_e_J = float(c.get("J", 0.0))
	_keep_best()
	return _build(&"replay")


## FROM A CHOICE THAT CANNOT BE REBUILT (its departure gone by, or open
## space): the search starts from its departure and keeps that flight if it
## flies, so the preview does not jump between near equals; else the search.
func _warm(c: Dictionary) -> void:
	if int(c.get("dk", -1)) != _dk or int(c.get("tp", -99)) != _tplace:
		return
	var ux := float(c.get("ux", 0.0))
	var uz := float(c.get("uz", 0.0))
	var te := float(c.get("te", 0.0))
	var s := float(c.get("s", 1.0))
	var fix := bool(c.get("fix", false))
	var afix := float(c.get("afix", 0.0))
	if te > t_now + 1.0:
		_refine_at(ux, uz, fix, afix, te, s, 3)
	else:
		_fly(ux, uz, fix, afix)


# ---------------------------------------------------------------- the result
## THE BEST FLIGHT AS SAMPLES: flown once more (the same integration), then the
## coast and the arrival burn sampled SAMPLE apart from the departure, the
## arrival's end on the sample grid (its burn worked out again there).
func _build(kind: StringName) -> Result:
	var t_b := Time.get_ticks_usec()
	var res := _build_in(kind)
	_us_build += Time.get_ticks_usec() - t_b
	return res


func _build_in(kind: StringName) -> Result:
	var res := Result.new()
	res.kind = kind
	if _b_J == INF or _b.is_empty():
		return res
	var b := _b
	# (to just past its arrival, so a replay made later flies the very same
	# steps: the last step before the time cap is cut short to meet it)
	_integrate(float(b.td), float(b.x0), float(b.z0), float(b.vx0), float(b.vz0), float(b.dvx), float(b.dvz), float(b.te) + 0.5)
	var td := float(b.td)
	var n := maxi(2, roundi((float(b.te) - td) / SAMPLE))
	var te := td + float(n) * SAMPLE
	if te > _cT[_cn - 1]:
		n -= 1
		te = td + float(n) * SAMPLE
	var s := float(b.s)
	var st := _coast_at(te)
	var ar := _arrival(te, st[0], st[1], st[2], st[3], s, float(b.pk))
	if ar.is_empty():
		return res
	var phi := ar[1]
	var d2 := ar[2]
	var dxx := ar[3]
	var dxz := ar[4]
	var dux := ar[5]
	var duz := ar[6]
	var tb := te - d2
	var Ax := 3.0 * dxx - dux * d2
	var Az := 3.0 * dxz - duz * d2
	var Bx := dux * d2 - 2.0 * dxx
	var Bz := duz * d2 - 2.0 * dxz
	res.samp.resize(n + 1)
	res.burns.resize(n + 1)
	var least := INF
	var j := 0
	var h := 1.0
	for k in n + 1:
		var tq := td + float(k) * SAMPLE
		while j + 2 < _cn and _cT[j + 1] <= tq:
			j += 1
		h = _cT[j + 1] - _cT[j]
		var u := (tq - _cT[j]) / h if h > 0.0 else 0.0
		var u2 := u * u
		var u3 := u2 * u
		var h00 := 2.0 * u3 - 3.0 * u2 + 1.0
		var h10 := (u3 - 2.0 * u2 + u) * h
		var h01 := -2.0 * u3 + 3.0 * u2
		var h11 := (u3 - u2) * h
		var x := h00 * _cX[j] + h10 * _cVX[j] + h01 * _cX[j + 1] + h11 * _cVX[j + 1]
		var z := h00 * _cZ[j] + h10 * _cVZ[j] + h01 * _cZ[j + 1] + h11 * _cVZ[j + 1]
		var lit := tq < _tc0
		if tq >= tb:
			var tau := (tq - tb) / d2
			x += Ax * tau * tau + Bx * tau * tau * tau
			z += Az * tau * tau + Bz * tau * tau * tau
			lit = true
		res.samp[k] = Vector3(x, 0.0, z)
		res.burns[k] = 1 if lit else 0
		# (the coast was held clear step by step as it was flown; the burn's
		# samples are checked here)
		if tq >= tb and (k % 4 == 0 or k == n):
			least = minf(least, _margin(x, z, tq))
	# the coast clean up to the burn (between samples too) and the burn's samples
	_coast_at(tb)
	least = minf(least, _cCL[mini(_qk + 1, _cn - 1)])
	var amax := 1.0
	for k in range(1, n, 2):
		amax = maxf(amax, (res.samp[k + 1] - 2.0 * res.samp[k] + res.samp[k - 1]).length() / (SAMPLE * SAMPLE))
	res.amax = amax
	res.clear = least
	res.clean = least >= -0.05
	res.found = true
	res.t0 = td
	res.lead = float(b.lead)
	res.lead_k = float(b.k)
	res.a_dep = float(b.ad)
	res.dur = float(n) * SAMPLE
	res.esc_t = _tc0 - td
	res.dv1 = sqrt(float(b.dvx) * float(b.dvx) + float(b.dvz) * float(b.dvz))
	res.dv2 = ar[0]
	res.work = res.dv1 + res.dv2
	res.d2 = d2
	res.T = te - t_now
	res.cost = res.work + TIME_W * res.T
	_tgt_at(te)
	var keepd := _tk == 1
	var arx := _toffx if keepd else _tR * cos(phi)
	var arz := _toffz if keepd else _tR * sin(phi)
	var rvx := 0.0 if keepd else -sin(phi) * s * _tV
	var rvz := 0.0 if keepd else cos(phi) * s * _tV
	var cen := -(_tV * _tV) / _tR if not keepd and _tR > 0.0 else 0.0
	res.end = {"body": _tplace, "p": Vector3(_cx + arx, 0.0, _cz + arz), "v": Vector3(_cvx + rvx, 0.0, _cvz + rvz),
		"a": Vector2(cen * cos(phi), cen * sin(phi)) if not keepd else Vector2.ZERO, "arel": Vector2(arx, arz),
		"rv": Vector2(rvx, rvz), "t": te, "keep": keepd, "sense": s if not keepd else 0.0}
	res.choice = {"v": CHOICE_V, "dk": _dk, "dp": _dplace, "tp": _tplace, "w": _dw, "rt": _drt,
		"td": td, "ad": float(b.ad), "dvx": float(b.dvx), "dvz": float(b.dvz), "ux": float(b.ux), "uz": float(b.uz),
		"x0": float(b.x0), "z0": float(b.z0), "vx0": float(b.vx0), "vz0": float(b.vz0),
		"fix": bool(b.fix), "afix": float(b.afix), "te": float(b.te), "s": s, "phi": float(b.phi), "d2": float(b.d2),
		"w2": float(b.w2), "pk": float(b.pk), "J": _b_J}
	return res
