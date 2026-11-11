extends RefCounted

## Arcade flight: no star pull in open space, rings capture slow ships as rails.
## Auto-flights are solved manoeuvres. Not saved: ship position lives for the session.
## Why: docs/why/ShipFlight.md#ship-flight-design

## The feel was measured on test players in the mock: 303 of 303 approaches ended in orbit.
## Why: docs/why/ShipFlight.md#ship-flight-design
const THRUST := 40.0
const VMAX := 150.0
const TURN := 200.0 * PI / 180.0
const DRAG := 0.35
const BRAKE := 3.0
## Let go in a ring slower than this and you are on its orbit. Above VMAX on
## purpose: anything a player flies is slow enough, so W alone decides.
const CAPTURE := 170.0
const STICKY := 12.0
const EASE := 0.5
const NO_CAPTURE_S := 1.5
## Letting go out of every ring settles the ship onto a calm circle round the star.
## Pace is STAR_PACE times Kepler's, so a lap takes a minute or two.
## Why: docs/why/ShipFlight.md#star-settle
const SETTLE_A := 90.0
## Swings round at speed instead of stopping and reversing, which drew a cusp.
const SETTLE_W := 1.0
const SETTLE_TAU := 0.5
const SETTLE_TURN := 0.28
const SETTLE_RAMP := 0.35
const STAR_PACE := 50.0
const SETTLED_DV := 2.0
## settled onto a radius it was brought to (a twin's, `_settle_centre`) within this (px)
const SETTLED_PX := 0.5
## THE NOSE TURNS ON A SPRING, critically damped at this rate (rad/s): a half
## turn in about 0.3 s, eased in and out, never a jump.
const NOSE_W := 14.0
## Quintic Hermite blend keeps position, velocity and acceleration continuous at both ends.
const INSERT_T := Vector2(0.7, 1.6)
const RAIL_V := 35.0
const STAR_RAIL_V := 45.0
## Alongside a belt's beacon, a station or a hulk: this close, as seen (the
## layout keeps it, for the room an arrival needs: `SystemLayout.arrive_reach`).
const KEEP_R := SystemLayout.ALONGSIDE
const TILT := 0.38
## THE FAST TRANSFERS (Jon, Nov 4-7): each solved flight is planned on its own clock this many times
## faster than the map's, per AUTOPILOT path: DIRECT x4, CURVED x12 ("3B"). The parked ring stays at RAIL_V.
## `-- flight_pace=K` and `-- autopilot=direct|curved` for a harness.
## Why: docs/why/ShipFlight.md#flight-pace
const FLIGHT_PACE := {&"direct": 4.0, &"curved": 12.0}
static var pace_k := -1.0
static var path_k: StringName = &""
## The look aids while a fast flight plays: the flame fades over FLAME_MIN s after a burn, and the
## nose turns no faster than NOSE_RATE round a fast flight. `-- lookaids=0` turns them off.
## Why: docs/why/ShipFlight.md#look-aids
const FLAME_MIN := 0.25
const NOSE_RATE := deg_to_rad(300.0)
const NOSE_SLOW_S := 1.2
static var look_aids := -1
## Spin-up and spin-down round a ring: a fast flight leaves at `ke` times the ring's speed, reached
## as it rides round, and arrives that much faster, eased down over SPIN_S.
## Why: docs/why/ShipFlight.md#spin-up-and-down
const SPIN_S := 0.3
## THE SPIN-UP'S PUSH is the clock's hand-off, not the engine's: (ke - 1) x
## the ring's speed x 1.5 / its length at its peak; with the phasing beside it
## a ride may push up to SPIN_PUSH_K times THRUST x pace^2, and the spin is no
## shorter than SPIN_MIN. The flame shows it.
const SPIN_PUSH_K := 3.0
const SPIN_MIN := 0.08


## THE RATE A RIDE ROUND A RING ENDS AT, in times the ring's own, for plan pl:
## pace x its speed on the flight's clock / its speed (1 for today's planner, a
## pace of 1, or a ring already left at speed / pace).
func _ride_ke(pl: FlightPlan) -> float:
	if pl == null or pl.res == null or pl.pace == 1.0 or StringName(pl.dep.get("kind", &"")) != &"ring":
		return 1.0
	var v := absf(float(pl.dep.w)) * float(pl.dep.rt)
	if v <= 1e-9:
		return 1.0
	return pl.pace * absf(FlightSolve.tau_speed(v, pl.pace)) / v


## Whether a ride round a ring can be flown at pace pk: its push within THRUST (and VMAX) on the map,
## the spin-up's beside the phasing's, and its phasing k no less than `FlightSolve.RIDE_K_MIN`.
## Why: docs/why/ShipFlight.md#ride-flyable
static func _ride_flyable(rd: Dictionary, pk: float, vr: float) -> bool:
	var k := float(rd.get("k", 1.0))
	var ke := float(rd.get("ke", 1.0))
	var most := FlightSolve.THRUST * pk * pk * (SPIN_PUSH_K if ke > 1.0 + 1e-6 else 1.0)
	return not (vr * _ride_peak(rd) > most + 1e-6 or (maxf(k, 1.0) + ke - 1.0) * vr > FlightSolve.VMAX * pk + 1e-6 or k < FlightSolve.RIDE_K_MIN)


## The ride's shape round to a fast flight's departure: ride at w, spin up over `sp` s, ride on at
## ke w, the spin starting `ls` s before it leaves. Returns {k, ke, ls, sp}.
## Why: docs/why/ShipFlight.md#ride-shape
static func _ride_shape(dang: float, w: float, T: float, ke: float) -> Dictionary:
	if ke <= 1.0 + 1e-9 or T <= 1e-9:
		var k0 := 2.0 * dang / (w * T) - 1.0 if T > 1e-9 else 1.0
		return {"k": k0, "ke": 1.0, "ls": 0.0, "sp": 0.0}
	var need := dang / w - T
	var sp := minf(FlightSolve.spin_up(), T)
	var ls := need / (ke - 1.0) + 0.5 * sp
	if ls < sp:
		sp = clampf(2.0 * need / (ke - 1.0), minf(SPIN_MIN, T), sp)
		ls = sp
	ls = minf(ls, T)
	var res := dang / w - T - (ke - 1.0) * (ls - 0.5 * sp)
	return {"k": 1.0 + 2.0 * res / T, "ke": ke, "ls": ls, "sp": sp}


## The ride rd at tau s in: [the angle it has gone round past a0, its rate in
## times w, its push along the ring in w / s] (rd: T, k, ke, ls, sp).
static func _ride_at(rd: Dictionary, tau: float) -> PackedFloat64Array:
	var T := float(rd.T)
	var k := float(rd.get("k", 1.0))
	var ang := tau
	var rate := 1.0
	var acc := 0.0
	if T < INF and T > 1e-9 and k != 1.0:
		ang += (k - 1.0) * (tau / 2.0 - T / (4.0 * PI) * sin(TAU * tau / T))
		rate += (k - 1.0) * pow(sin(PI * tau / T), 2.0)
		acc += (k - 1.0) * PI / T * sin(TAU * tau / T)
	var ke := float(rd.get("ke", 1.0))
	if ke != 1.0 and T < INF:
		var ls := float(rd.ls)
		var sp := maxf(float(rd.sp), 1e-6)
		var s0 := T - ls
		if tau > s0:
			var x := clampf((tau - s0) / sp, 0.0, 1.0)
			var g := sp * (x * x * x - 0.5 * x * x * x * x)
			if tau > s0 + sp:
				g = 0.5 * sp + (tau - s0 - sp)
			ang += (ke - 1.0) * g
			rate += (ke - 1.0) * x * x * (3.0 - 2.0 * x)
			acc += (ke - 1.0) * 6.0 * x * (1.0 - x) / sp
	return PackedFloat64Array([ang, rate, acc])


## Its push along the ring at the most, in w / s.
static func _ride_peak(rd: Dictionary) -> float:
	var T := float(rd.T)
	var p := absf(float(rd.get("k", 1.0)) - 1.0) * PI / T if T > 1e-9 and T < INF else 0.0
	var ke := float(rd.get("ke", 1.0))
	if ke != 1.0:
		p += 1.5 * absf(ke - 1.0) / maxf(float(rd.sp), 1e-6)
	return p

## The modes: at the edge as arrived, flying free, on a rail, held alongside,
## or on a planned flight.
var mode: StringName = &"warp"
var L: SystemLayout
## The canonical state, kept current in every mode so leaving one is continuous.
var f := FreeState.new()
var ang := PI
var rail: Dictionary = {}
var keep: Dictionary = {}
var plan: FlightPlan = null
var fly_t0 := 0.0
var fly_to := -9
var _fly_done: Callable = Callable()
## WHEN A FLIGHT KEY WAS LAST HELD (the system's clock): while you fly by hand,
## and a moment after, the map draws only where you are going, not a plan
var thrust_t := -99.0
var burn := false
## how hard the engine burns, 0..1, for the flame (brighter as it lights)
var burn_k := 0.0
var _burn_age := 0.0
var _ang_v := 0.0
var _bound_t := -99.0
var rcs := false
var fast_t := -99.0
var bump_t := -99.0
var lead_t := -99.0
## What the line shows ending in (the capture held stickily), and its lines.
var sticky := -9
var _meet_raw := -9
var _meet_t := 0.0
var line: Dictionary = {}
var hold_line: Dictionary = {}
## Where the ship arrived at the edge (the game puts it at the frame's edge).
var edge_at := Vector2.ZERO
var warp_t := 0.0
## JUST ARRIVED, on the star orbit it warped in on, nothing done yet
var fresh := false


class FreeState:
	var p := Vector2.ZERO
	var v := Vector2.ZERO
	var head := PI
	var no_cap_left := 0.0
	var no_cap_body := -9
	var fast_seen := -9
	var bumped := false
	## how long the ship has coasted (no W, no S): the settle turns, then burns
	var coast := 0.0
	## the star orbit it has settled on, or -1
	var orbit_r := -1.0
	## the settle's burn this step, and the way it wants to burn (unramped)
	var acc := Vector2.ZERO
	var aim := Vector2.ZERO
	## heading into a capture anyway: the settle holds off (`ShipFlight.capture_ahead`)
	var bound := false
	## which way round the star it settles: the way it is already going round
	## (it used to swing round to the worlds' way, a hook by the ship)
	var sense := 1.0
	## What a settle rides round: the centre, its share of the stars' pull, and the radius.
	var cen := Vector2.ZERO
	var cen_id := -1
	var cen_share := 1.0
	var r_want := -1.0

	func copy() -> FreeState:
		var c := FreeState.new()
		c.p = p
		c.v = v
		c.head = head
		c.no_cap_left = no_cap_left
		c.no_cap_body = no_cap_body
		c.fast_seen = fast_seen
		c.coast = coast
		c.orbit_r = orbit_r
		c.bound = bound
		c.sense = sense
		c.cen = cen
		c.cen_id = cen_id
		c.cen_share = cen_share
		c.r_want = r_want
		return c


## `tail` is the insertion after the plan, kept so the whole flight can be drawn first.
class FlightPlan:
	var dur := 1.4
	## the flight's own clock against the map's (`FlightSolve.Result.pace`): its
	## pulls are pace^2 of what the solver flew; 1 for today's planner
	var pace := 1.0
	var conic := true
	## &"direct", &"waypoint", or &"unclean" (the least bad, none being clean)
	var kind: StringName = &"direct"
	var t0 := 0.0
	var esc_t := 0.0
	var sdt := 1.0 / 240.0
	var samp := PackedVector3Array()
	var burns := PackedByteArray()
	var amax := 1.0
	var tail := PackedVector3Array()
	var end: Dictionary = {}
	## Ride time and phasing before an escape; the try is kept so a replan stays on it.
	var lead := 0.0
	var lead_k := 1.0
	var choice: Dictionary = {}
	## the insertion's sharpest curvature as drawn (1 / its tightest radius, px)
	var tail_k := 0.0
	## Solved flight data; `res` is null when the old planner made the plan.
	var res: FlightSolve.Result = null
	var to := -9
	var dep: Dictionary = {}
	var t_plan := 0.0
	var u_dep := 0.0
	## Old planner's plan made on a worker for a moment ahead, flown from `t0` on map time.
	var ahead := false
	var a_dep := 0.0
	## whether the stretch drawn after it burns (an insertion) or rides on (a
	## solved flight's ring, which is no burn)
	var tail_lit := true
	## THE LINE AS THE MAP DRAWS IT, laid out on the worker that made the plan
	## (`lay_out`): [points, lit, u], or empty
	var line: Array = []

	func pos(u: float) -> Vector3:
		var n := samp.size() - 1
		if n < 1:
			return samp[0] if n == 0 else Vector3.ZERO
		var x := clampf(u, 0.0, 1.0) * n
		var j := mini(n - 1, int(floor(x)))
		return samp[j].lerp(samp[j + 1], x - j)

	## The engine is lit for the escape and for the burns at each end of a coast.
	func burning(u: float) -> bool:
		var n := burns.size() - 1
		if n < 0:
			return false
		return burns[clampi(int(roundf(clampf(u, 0.0, 1.0) * n)), 0, n)] == 1


func setup(layout: SystemLayout, edge_point: Vector2, t: float) -> void:
	L = layout
	edge_at = edge_point
	_grav_v = null
	_stars = L.stars()
	_cache_stars()
	f = FreeState.new()
	_drop_jobs()
	# The ship starts in orbit of the star, clear of every ring, going the way worlds go.
	var c := L.bary if L.twin else Vector2.ZERO
	var ep := edge_point - c
	var r := arrival_r(ep.length())
	f.p = c + ep.normalized() * r if ep.length() > 1.0 else c + Vector2(r, 0.0)
	f.cen = c
	f.cen_id = -9 if L.twin else -1
	f.cen_share = 1.0
	f.orbit_r = r
	f.sense = 1.0
	f.v = star_orbit_v(f.p, r, 1.0, c, 1.0)
	f.head = _scr_ang(f.v)
	ang = f.head
	mode = &"free"
	fresh = true
	plan = null
	warp_t = t
	line = {}
	hold_line = {}
	sticky = -9


# ---------------------------------------------------------------- the places
# The stars are cached from `setup` because free flight asks for them every step.
var _stars: Array[int] = [-1]
## Per-star numbers are cached in `setup`: looking them up each step made a twin's
## frame cost about double a single sun's (MapPerfTest, Oct 31).
## Why: docs/why/ShipFlight.md#star-caches
var _s_pos := PackedVector2Array()
var _s_bump := PackedFloat64Array()
var _s_keep := PackedFloat64Array()
var _s_ring := PackedFloat64Array()
var _s_hold := PackedFloat64Array()


func _cache_stars() -> void:
	_s_pos = PackedVector2Array()
	_s_bump = PackedFloat64Array()
	_s_keep = PackedFloat64Array()
	_s_ring = PackedFloat64Array()
	_s_hold = PackedFloat64Array()
	_s_r = PackedFloat64Array()
	for s in _stars:
		# (where each is at t 0, the pair as laid out: where a still pair and
		# one sun always are, and a turning pair's only at t 0, `_stars_at`)
		_s_pos.append(L.star_pos(s, 0.0))
		_s_bump.append(bumper(s))
		_s_keep.append(keep_clear(s))
		_s_ring.append(star_ring(s))
		_s_hold.append(keep_clear(s) if L.twin else L.star_radius(s) + 8.0)
		_s_r.append(L._pair_r(s) if L.twin else 0.0)


## each star's signed distance from the balance point along the pair's line
## (`SystemLayout._pair_r`), in `_stars`' order: a turning pair's circles
var _s_r := PackedFloat64Array()
## A turning pair's suns go into their own buffers each step, never the shared cache,
## as the two forecast lines need them every frame.
## Why: docs/why/ShipFlight.md#star-caches
var _sp_at := PackedVector2Array()
var _sv_at := PackedVector2Array()
var _sp_buf := PackedVector2Array()
var _sv_buf := PackedVector2Array()
func _stars_at(t: float) -> bool:
	if L.pair_n == 0.0 or t == 0.0:
		_sp_at = _s_pos
		return false
	var a := L.pair_ph + L.pair_n * t
	var u := Vector2(cos(a), sin(a))
	var ut := Vector2(-u.y, u.x)
	if _sp_buf.size() != _stars.size():
		_sp_buf = PackedVector2Array()
		_sv_buf = PackedVector2Array()
		_sp_buf.resize(_stars.size())
		_sv_buf.resize(_stars.size())
	for si in _stars.size():
		_sp_buf[si] = L.bary + u * _s_r[si]
		_sv_buf[si] = ut * (_s_r[si] * L.pair_n)
	_sp_at = _sp_buf
	_sv_at = _sv_buf
	return true


## Round a turning pair's sun the centre rides with that sun, as a fixed point
## was left behind at up to 1.1 px/s.
## Why: docs/why/ShipFlight.md#settle-centre
func _follow(st: FreeState, moving: bool) -> Vector2:
	if not moving or not SystemLayout.is_star(st.cen_id):
		return Vector2.ZERO
	var ci := 0 if st.cen_id == -1 else 1
	st.cen = _sp_at[ci]
	return _sv_at[ci]


## How fast a settle's centre `id` moves at t (`_follow`'s, for one moment):
## a sun of a turning pair's, else nought.
func _cen_vel(id: int, t: float) -> Vector2:
	if not L.twin or not SystemLayout.is_star(id):
		return Vector2.ZERO
	return L.star_vel(id, t)


## One source for rail, ring and keep-clear, so the layout and the flight agree.
func star_rail(p: int = -1) -> float:
	return L.star_rail_of(p)


func star_ring(p: int = -1) -> float:
	return L.star_ring_of(p)


## The ship rides at the ring's outer edge, just inside capture and clear of its line.
const ORBIT_K := 0.88
func orbit_r(i: int) -> float:
	if SystemLayout.is_star(i):
		return FlightSolve.star_orbit_r(L, i)
	if i < 0:
		return star_ring() - 8.0
	# A world close to its star orbits far enough out to stay off the star's keep-clear.
	var b := L.bodies[i]
	var hs := b.host_id if SystemLayout.is_star(b.host_id) else -1
	return clampf(b.orbit - keep_clear(hs) - 10.0, b.soi * 0.5, b.soi * ORBIT_K)


## Where a flight's coast meets the place, for the burn onto its orbit: just
## outside the ring, so the insertion comes in along it.
const APPROACH_K := 1.12
func approach_r(i: int) -> float:
	if i < 0:
		return star_ring(i if SystemLayout.is_star(i) else -1) + 12.0
	return L.bodies[i].soi * APPROACH_K


## A twin's ring is only 2 px past its rail, so its bumper sits 8 px past the ring.
func bumper(p: int = -1) -> float:
	if L.twin:
		return star_ring(p) + 8.0
	return star_rail(p) + 25.0


func keep_clear(p: int = -1) -> float:
	return L.keep_clear_of(p)


func is_keep(i: int) -> bool:
	if i < 0:
		return false
	var k := L.bodies[i].kind
	return k == &"belt" or k == &"station" or k == &"derelict" or k == &"contact"


## Every body circles its own centre: the old belt rule circled the origin and landed
## 236 twin arrivals more than 0.5 px off the beacon.
## Why: docs/why/ShipFlight.md#place-centres
func center(i: int, t: float) -> Vector3:
	if i < 0:
		if SystemLayout.is_star(i):
			var sp := L.star_pos(i, t)
			return Vector3(sp.x, 0.0, sp.y)
		return Vector3.ZERO
	return L.bodies[i].point3(t)


func center_vel(i: int, t: float) -> Vector3:
	return (center(i, t + 0.05) - center(i, t - 0.05)) / 0.1


static func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


## The plane point as the flight's (x, 0, z).
func where3() -> Vector3:
	if mode == &"fly" and plan != null:
		return _fly_pos
	return Vector3(f.p.x, 0.0, f.p.y)


func vel() -> Vector2:
	return f.v


## What the ship is in orbit of or alongside: a body, -1 star A (the star),
## SystemLayout.STAR_B star B, -9 nothing.
func reached() -> int:
	# (a flight asked for and being planned, or holding alongside to leave, is
	# on its way: as riding round to leave is)
	if not _pend.is_empty():
		return -9
	if mode == &"rail":
		return -9 if (inserting() or rail.has("phase")) else int(rail.body)
	if mode == &"keep":
		return -9 if (inserting() or keep.has("hold")) else int(keep.body)
	return -9


## Burning onto an orbit (or alongside), not yet on it.
func inserting() -> bool:
	if mode == &"rail":
		return float(rail.get("s", 1.0)) < 1.0
	if mode == &"keep":
		return keep.has("arrive") or (keep.get("ev", Vector2.ZERO) as Vector2).length() > 3.0
	return false


## What the ship is on, or burning onto: a body, a star's close orbit (-1,
## SystemLayout.STAR_B), -9.
func orbit_body() -> int:
	if mode == &"rail":
		return int(rail.body)
	if mode == &"keep":
		return int(keep.body)
	return -9


## Settled on a wide orbit round the star (not its close one).
func star_orbiting() -> bool:
	return mode == &"free" and f.orbit_r > 0.0


## Star orbit velocity: the way worlds go, at the calm pace, with a pull back onto r.
func star_orbit_v(p: Vector2, r_hold: float, sense := 1.0, c := Vector2.ZERO, share := 1.0) -> Vector2:
	var q := p - c
	var r := maxf(q.length(), 1.0)
	var rh := q / r
	var rr := r_hold if r_hold > 0.0 else r
	var spd := STAR_PACE * TAU * 1000.0 / (800.0 * sqrt(maxf(rr, 20.0)))
	if share != 1.0:
		spd *= sqrt(share)
	var v := Vector2(-rh.y, rh.x) * spd * sense
	if r_hold > 0.0:
		# (unclamped in the very order it always was, so a ship round one star
		# moves to the bit as it did)
		if absf((r - r_hold) * 1.2) <= PULL_V:
			v -= rh * (r - r_hold) * 1.2
		else:
			v -= rh * signf(r - r_hold) * PULL_V
	return v


## The pull cap never reaches a ship settled round one star (under 3 px/s of pull).
## A twin's far-out ship is brought in at 1.2 px/s a px instead of 400.
## Why: docs/why/ShipFlight.md#settle-centre
const PULL_V := 30.0


## The settled star orbit's pace (px/s) at radius r round a centre with `share`
## of the stars' pull (`star_orbit_v`'s speed).
static func star_pace(r: float, share := 1.0) -> float:
	var spd := STAR_PACE * TAU * 1000.0 / (800.0 * sqrt(maxf(r, 20.0)))
	if share != 1.0:
		spd *= sqrt(share)
	return spd


## In a twin the ship settles round the nearer star inside its steady zone, else both.
## Circles stay clear of capture rings, or a settling ship was taken onto a star or world.
## Why: docs/why/ShipFlight.md#settle-centre
func _settle_centre(st: FreeState, t: float) -> void:
	st.r_want = -1.0
	if not L.twin:
		st.cen = Vector2.ZERO
		st.cen_id = -1
		st.cen_share = 1.0
		return
	var da := (st.p - L.star_pos(-1, t)).length()
	var db := (st.p - L.star_pos(SystemLayout.STAR_B, t)).length()
	var za := _zone(-1)
	var zb := _zone(SystemLayout.STAR_B)
	var near := -1 if da - za <= db - zb else SystemLayout.STAR_B
	var dn := da if near == -1 else db
	var zn := za if near == -1 else zb
	if da < za or db < zb:
		near = -1 if da < za else SystemLayout.STAR_B
		_round_star(st, near, -1.0, t)
		return
	var r := (st.p - L.bary).length()
	var r_out := _bary_out()
	if r < r_out and dn - zn < r_out - r:
		# (inside the pair: the nearer zone's edge is the shorter way, out past
		# the ring of the world round that star where it crosses it)
		_round_star(st, near, _clear_round(near, maxf(zn, star_ring(near) + STAR_ORBIT_GAP)), t)
		return
	st.cen = L.bary
	st.cen_id = -9
	st.cen_share = 1.0
	var hi := maxf(_bary_in(), r_out)
	var rw := clampf(r, r_out, hi)
	if absf(rw - r) > 0.01:
		rw = _clear_both(rw, r_out, hi)
	st.r_want = rw if absf(rw - r) > 0.01 else -1.0


## Settled round star p of a twin, at radius r_want (-1: where it is): round
## where the star is at t, and from then on where it is each step (`_follow`).
func _round_star(st: FreeState, p: int, r_want: float, t: float) -> void:
	st.cen = L.star_pos(p, t)
	st.cen_id = p
	st.cen_share = L.star_share if p == -1 else 1.0 - L.star_share
	st.r_want = r_want


## A twin's star p's steady zone (px from it): `SystemLayout.s_limit` of the
## other star's share, times the separation.
func _zone(p: int) -> float:
	var share := L.star_share if p == -1 else 1.0 - L.star_share
	return SystemLayout.s_limit(1.0 - share) * L.sep


## Clear of each star's capture ring by STAR_ORBIT_GAP and of the bands worlds sweep.
const STAR_ORBIT_GAP := 12.0
func _bary_out() -> float:
	var r := 0.0
	# (from the balance point, which the pair turns round rigidly: the same at
	# every t, so read at t 0)
	for p in _stars:
		r = maxf(r, (L.star_pos(p, 0.0) - L.bary).length() + star_ring(p) + STAR_ORBIT_GAP)
	for b in L.bodies:
		if SystemLayout.is_star(b.host_id) and b.world != &"":
			r = maxf(r, (b.host0 - L.bary).length() + b.orbit + _band(b))
	return r


## Moved past a world's band: a ship on the zone edge was otherwise taken onto that world.
func _clear_round(p: int, r: float) -> float:
	for b in L.bodies:
		if b.host_id == p and b.world != &"" and absf(r - b.orbit) < _band(b):
			r = b.orbit + _band(b)
	return r


## The radius is moved off every ring that can take a ship, or a settling ship
## was captured by the world, giant or contact ringing it.
## Why: docs/why/ShipFlight.md#settle-centre
func _clear_both(r: float, lo: float, hi: float) -> float:
	var cands: Array[float] = [r]
	for b in L.bodies:
		var reach: float = SystemLayout.arrive_reach(b)
		if b.host_id == -9 and reach > 0.0:
			cands.append(b.orbit - reach)
			cands.append(b.orbit + reach)
	var best := r
	var best_d := INF
	for c: float in cands:
		if c < lo - 0.001 or c > hi + 0.001 or absf(c - r) >= best_d:
			continue
		var ok := true
		for b in L.bodies:
			if b.host_id == -9 and absf(c - b.orbit) < SystemLayout.arrive_reach(b) - 0.001:
				ok = false
				break
		if ok:
			best = c
			best_d = absf(c - r)
	return best


## How far either side of its circle a world's ring reaches, well clear (as
## `arrival_r` keeps it).
func _band(b: SystemLayout.Body) -> float:
	return b.soi * 1.3 + 10.0


## Widest circle inside the map, measured from star A; `_clear_both` handles the worlds.
func _bary_in() -> float:
	return L.edge - L.bary.length() - 12.0


## THE NOSE, turned toward `want` (a screen angle) on its spring; around a
## fast flight no faster than NOSE_RATE (`_nose_slow`).
func _nose(want: float, dt: float) -> void:
	var err := wrapf(want - ang, -PI, PI)
	_ang_v += (NOSE_W * NOSE_W * err - 2.0 * NOSE_W * _ang_v) * dt
	# (from the ride round to a fast flight's departure to NOSE_SLOW_S after it
	# is on its ring)
	if plan != null and plan.res != null and plan.pace > 1.0:
		_nose_slow = NOSE_SLOW_S
	if _nose_slow > 0.0 and aids_on():
		_ang_v = clampf(_ang_v, -NOSE_RATE, NOSE_RATE)
	_nose_slow = maxf(_nose_slow - dt, 0.0)
	ang = wrapf(ang + _ang_v * dt, -PI, PI)
	f.head = ang
## (s left of the nose's slow turn after a fast flight: `NOSE_RATE`)
var _nose_slow := 0.0


## A plane direction as the screen angle the ship is drawn at.
static func _scr_ang(v: Vector2) -> float:
	return atan2(v.y * TILT, v.x)


## The flame's level: the burn's share of its peak, flaring as it lights.
func _flame(k: float, dt: float) -> void:
	_burn_age += dt
	burn_k = clampf(k, 0.0, 1.0) * (1.0 + 0.6 * clampf(1.0 - _burn_age / 0.25, 0.0, 1.0))


# ---------------------------------------------------------------- a frame
## A FLIGHT'S MOTION, read from its samples this far either side in time (s)
const FLY_DT := 1.0 / 60.0
var _fly_pos := Vector3.ZERO
var _last_screen := Vector2.ZERO


## Worker plans are taken in after the step so the ride is current, not a frame stale.
## A held clock (dt 0) still places a ship on its ring, or it had no place until its first step.
## Why: docs/why/ShipFlight.md#step-and-held-clock
func step(dt: float, t: float, k: Dictionary) -> float:
	if dt > 0.0:
		_lvl = _step_mode(dt, t, k)
		_lvl_k = {"w": k.w, "a": k.a, "s": k.s, "d": k.d}
	else:
		var lvl0 := 0.0
		if mode != &"free" and mode != &"warp":
			lvl0 = _step_mode(0.0, t, NO_KEYS)
		_let_go_held(k, lvl0)
	_poll_jobs(t)
	return _lvl
var _lvl := 0.0
## (the keys held on the last step by time: what the level held may be theirs)
var _lvl_k := {}
const NO_KEYS := {"w": false, "a": false, "s": false, "d": false}


## A key let go during a hold goes quiet at once, or W let go kept the burn and
## flame lit to the move's end, up to 2 s.
## Why: docs/why/ShipFlight.md#step-and-held-clock
func _let_go_held(k: Dictionary, lvl0: float) -> void:
	var kept := {}
	var gone := false
	var any := false
	for key: String in _lvl_k:
		kept[key] = bool(_lvl_k[key]) and bool(k.get(key, false))
		gone = gone or (bool(_lvl_k[key]) and not kept[key])
		any = any or bool(kept[key])
	if not gone:
		return
	_lvl_k = kept
	if mode == &"free" or mode == &"warp":
		burn = bool(kept.w)
		rcs = bool(kept.s)
		if not burn:
			burn_k = 0.0
			_burn_age = 0.0
		_lvl = 0.7 if kept.w else (0.45 if kept.s else (0.32 if (kept.a or kept.d) else 0.0))
	elif not any:
		_lvl = lvl0


func _step_mode(dt: float, t: float, k: Dictionary) -> float:
	var any: bool = k.w or k.a or k.s or k.d
	if any and (mode == &"free" or mode == &"warp"):
		thrust_t = t
	if any or mode != &"free":
		fresh = false
	# A FLIGHT ASKED FOR AND STILL BEING PLANNED (`fly_bg`): W or S lets go of
	# it, as W lets go of a ride round to leave
	if not _pend.is_empty() and (k.w or k.s):
		_cancel_flight()
	if mode == &"fly":
		var lvl := _fly_frame(dt, t)
		# A solved flight's last stretch is its burn onto the orbit, flown on its own samples.
		if plan.res != null and t >= _arrive_t(plan):
			_arrive(t)
		elif t - fly_t0 >= plan.dur:
			_land(t)
		return lvl
	if mode == &"warp":
		if not any:
			burn = false
			return 0.0
		mode = &"free"
		f.v = Vector2.ZERO
	if mode == &"rail":
		return _step_rail(dt, t, k)
	if mode == &"keep":
		if keep.has("arrive"):
			return _step_arrive(dt, t, k)
		# HOLDING ALONGSIDE BEFORE A FLIGHT LEAVES (`FlightSolve.KEEP_HOLD`): W
		# lets go of the flight; at its departure, the flight
		if keep.has("hold"):
			if k.w:
				_cancel_flight()
			elif t >= float(keep.hold):
				keep.erase("hold")
				_begin_fly(t)
				return _step_mode(0.0, t, k)
		if not k.w:
			if k.a:
				f.head -= TURN * dt
			if k.d:
				f.head += TURN * dt
			ang = f.head
			# The rest point alongside is fixed when the
			# ship came alongside, so a plan leaves from it.
			var ev: Vector2 = keep.ev
			if not keep.has("inf"):
				keep.inf = (keep.off as Vector2) + ev * KEEP_TAU
			keep.ev = ev * exp(-dt / KEEP_TAU)
			keep.off = (keep.inf as Vector2) - (keep.ev as Vector2) * KEEP_TAU
			var c := center(int(keep.body), t)
			f.p = _flat(c) + (keep.off as Vector2)
			f.v = _flat(center_vel(int(keep.body), t)) + (keep.ev as Vector2)
			rcs = false
			var e0 := float(keep.get("ev0", 1.0))
			if keep.has("hold"):
				# the nose onto the burn it will leave on
				var hd: Vector2 = keep.get("hold_dir", Vector2.ZERO)
				if hd.length() > 0.01:
					_nose(_scr_ang(hd), dt)
			elif ev.length() > 3.0 and not (k.a or k.d):
				burn = true
				_nose(_scr_ang(-ev), dt)
				_flame(ev.length() / maxf(e0, 1.0), dt)
				return 0.7 * burn_k
			burn = false
			burn_k = 0.0
			_burn_age = 0.0
			# (not while it waits to leave: the callback is the next flight's)
			if not keep.has("hold") and _pend.is_empty():
				_arrived()
			return 0.32 if (k.a or k.d) else 0.0
		f.no_cap_body = int(keep.body)
		f.no_cap_left = NO_CAPTURE_S
		mode = &"free"
	# A settle's own burn is not taken as an aim, or it stopped half
	# way and coasted into the world. Seen 3 of 30 times in a wide pair.
	# Why: docs/why/ShipFlight.md#capture-rules
	if not (f.r_want > 0.0 and f.coast > SETTLE_TURN) and capture_ahead(f, t):
		_bound_t = t
	f.bound = t - _bound_t < 0.5
	var res := free_step(f, k, t, dt, sticky, true)
	burn = k.w
	rcs = k.s
	var lvl := 0.7 if k.w else (0.45 if k.s else (0.32 if (k.a or k.d) else 0.0))
	if k.w or k.s or k.a or k.d:
		# the player's own nose
		ang = f.head
		_ang_v = 0.0
		if k.w:
			_flame(1.0, dt)
		else:
			burn_k = 0.0
			_burn_age = 0.0
	elif f.acc.length() > 4.0:
		# THE SETTLE'S BURN onto the star's orbit, the nose on it
		_nose(_scr_ang(f.acc), dt)
		burn = true
		_flame(f.acc.length() / SETTLE_A, dt)
		lvl = 0.7 * burn_k
	else:
		burn_k = 0.0
		_burn_age = 0.0
		if f.aim.length() > 4.0 and f.orbit_r < 0.0:
			# about to burn: the nose turns onto the burn first
			_nose(_scr_ang(f.aim), dt)
		elif f.v.length() > 1.0:
			# coasting round the star: along the way it goes
			_nose(_scr_ang(f.v), dt)
	if res.get("kind", &"") == &"fast":
		fast_t = t
	elif res.get("kind", &"") == &"rail":
		start_rail(int(res.body), res.rel, res.rv, t)
	elif res.get("kind", &"") == &"keep":
		mode = &"keep"
		keep = {"body": res.body, "off": res.rel, "ev": res.rv, "ev0": (res.rv as Vector2).length(),
			"inf": (res.rel as Vector2) + (res.rv as Vector2) * KEEP_TAU}
		f.orbit_r = -1.0
	return lvl


## Alongside, the motion relative to the place eases out over this (s).
const KEEP_TAU := 0.35


## ONE FRAME ON A PLANNED FLIGHT: where it is and how it moves, from its
## samples at the map's clock, the nose and the flame on its burn.
func _fly_frame(dt: float, t: float) -> float:
	var u := clampf((t - fly_t0) / plan.dur, 0.0, 1.0)
	_fly_pos = plan.pos(u)
	burn = plan.burning(u)
	rcs = false
	# Motion is read FLY_DT either side in time,
	# as a share of the plan smeared a 30 s flight's burns.
	var du := FLY_DT / maxf(plan.dur, 0.001)
	var ua := maxf(u - du, 0.0)
	var ub := minf(u + du, 1.0)
	var q0 := plan.pos(ua)
	var q2 := plan.pos(ub)
	var vv := Vector2(q2.x - q0.x, q2.z - q0.z)
	var aa := Vector2(q2.x - 2.0 * _fly_pos.x + q0.x, q2.z - 2.0 * _fly_pos.z + q0.z)
	# Position and motion are kept as it flies, so a new target plans from here at this speed.
	f.p = Vector2(_fly_pos.x, _fly_pos.z)
	if u < 1.0 and ub > ua:
		f.v = vv / ((ub - ua) * plan.dur)
	var lvl := 0.0
	var push := aa / (FLY_DT * FLY_DT)
	# (a flight on its own clock, played pace times faster: its pulls pace^2)
	var k2 := plan.pace * plan.pace
	if plan.res != null:
		# Flame shows the burn less the pull: near a keep-out a star's pull is twice THRUST.
		var g := _grav().acc(_fly_pos.x, _fly_pos.z, t)
		push -= Vector2(g[0], g[1]) * k2
	var aids := plan.res != null and plan.pace > 1.0 and aids_on()
	if burn and push.length() > 0.5 * k2:
		_nose(_scr_ang(push), dt)
		if plan.res != null:
			_flame(clampf(push.length() / (THRUST * k2), 0.3, 1.0), dt)
		else:
			_flame(clampf(push.length() / maxf(plan.amax, 1.0), 0.3, 1.0), dt)
		lvl = 0.7 * burn_k
		if aids:
			_flame_left = FLAME_MIN
			_flame_peak = burn_k
			_flame_dir = push
	else:
		# (the flame fading out, the nose still on the burn's way)
		if aids and _flame_left > 0.0 and _flame_dir != Vector2.ZERO:
			_nose(_scr_ang(_flame_dir), dt)
		elif vv.length() > 0.0001:
			_nose(_scr_ang(vv), dt)
		if aids and _flame_left > 0.0:
			# THE FLAME FADING OUT after a burn (`FLAME_MIN`)
			_flame_left = maxf(_flame_left - dt, 0.0)
			burn = true
			burn_k = _flame_peak * _flame_left / FLAME_MIN
			lvl = 0.7 * burn_k
		else:
			_flame_left = 0.0
			_flame_dir = Vector2.ZERO
			_burn_age = 0.0
			burn_k = 0.0
	return lvl
var _flame_left := 0.0
var _flame_peak := 0.0
var _flame_dir := Vector2.ZERO


## The arrival burn is bounded by ARRIVE_MIN and INSERT_T. The whole burn had a twin's
## ship up to 338 px off its ring and 9.7 s before the end.
## Why: docs/why/ShipFlight.md#arrival-burn
const ARRIVE_MIN := 0.5
func _arrive_t(pl: FlightPlan) -> float:
	var k := maxf(pl.pace, 1.0)
	return float(pl.end.t) - clampf(pl.res.d2 * k, ARRIVE_MIN, INSERT_T.y) / k


## Onto the place: burning on, or alongside, then exactly on the ring (`_land`).
func _arrive(t: float) -> void:
	var e := plan.end
	var i: int = e.body
	var arel: Vector2 = e.arel
	if e.get("keep", false):
		mode = &"keep"
		keep = {"body": i, "off": arel, "ev": Vector2.ZERO, "ev0": 0.0, "inf": arel, "arrive": true}
		rail = {}
	else:
		var pl := plan
		start_rail(i, arel, e.rv, float(e.t), e.get("a", Vector2.ZERO), pl.pace)
		plan = pl
		rail.s = 0.0
		rail.arrive = true
		rail.erase("ins")
	f.orbit_r = -1.0
	f.no_cap_left = 0.0


## A FRAME OF THE BURN ONTO THE PLACE (`_arrive`): on the flight's samples; W
## breaks off it from the motion it has, as it does off an insertion.
func _step_arrive(dt: float, t: float, k: Dictionary) -> float:
	if k.w:
		var body := orbit_body()
		mode = &"free"
		_fly_done = Callable()
		f.no_cap_body = body
		f.no_cap_left = NO_CAPTURE_S
		f.coast = 0.0
		rail = {}
		keep = {}
		plan = null
		return 0.7
	var lvl := _fly_frame(dt, t)
	if t - fly_t0 >= plan.dur:
		_land(t)
	return lvl


func _step_rail(dt: float, t: float, k: Dictionary) -> float:
	var body := int(rail.body)
	if inserting():
		return _step_insert(dt, t, k)
	if rail.has("phase"):
		if k.w:
			# W: the flight is off. A fast flight's ride is spun down to the ring's own rate over SPIN_S first,
			# then W takes it off (let go at once, a whirl dropped to 35 px/s in a frame).
			# Why: docs/why/ShipFlight.md#w-during-a-spin-up
			var ph: Dictionary = rail.phase
			var w_now := float(ph.w) * _ride_at(ph, t - float(ph.t0))[1]
			var w_own := float(rail.dir) * float(rail.speed) / float(rail.rt)
			_cancel_flight()
			if float(ph.get("ke", 1.0)) > 1.0 and absf(w_now - w_own) > 0.02 * absf(w_own):
				rail.r0 = float(rail.rt)
				rail.u = 0.0
				rail.spin = {"t0": t, "a0": float(rail.ang), "w1": w_now}
		else:
			return _step_phase(dt, t)
	rail.u = minf(1.0, float(rail.u) + dt / float(rail.get("ease", EASE)))
	# A AND D: the orbit a little closer or wider, inside the ring
	if k.a:
		rail.rt = maxf(float(rail.rmin), float(rail.rt) - 30.0 * dt)
	if k.d:
		rail.rt = minf(float(rail.rmax), float(rail.rt) + 30.0 * dt)
	var e := smoothstep(0.0, 1.0, float(rail.u))
	var rt: float = rail.rt
	var r: float = rt + (float(rail.r0) - rt) * (1.0 - e)
	var wt: float = float(rail.dir) * float(rail.speed) / rt
	var wv: float = float(rail.w0) + (wt - float(rail.w0)) * e
	rail.ang = float(rail.ang) + wv * dt
	if rail.has("spin"):
		wv = _spin_down(t, wt)
	var c := center(body, t)
	var cv := center_vel(body, t)
	var sg := 1.0 if wv >= 0.0 else -1.0
	var a: float = rail.ang
	var tg := Vector2(-sin(a) * sg, cos(a) * sg)
	f.p = Vector2(c.x + cos(a) * r, c.z + sin(a) * r)
	f.v = _flat(cv) + tg * absf(wv) * r
	# prograde along the orbit, the flame out
	_nose(_scr_ang(tg), dt)
	burn = false
	burn_k = 0.0
	_burn_age = 0.0
	rcs = false
	if k.w and not rail.has("spin"):
		# W: OFF THE RAIL, a prograde burn from the orbit's own motion (no kick:
		# the thrust does it), and this ring lets you go until you are out of it
		# (not while it spins down onto its own rate: then)
		mode = &"free"
		f.v = _flat(cv) + tg * absf(wv) * r
		f.no_cap_body = body
		f.no_cap_left = NO_CAPTURE_S
		f.orbit_r = -1.0
		f.coast = 0.0
		rail = {}
		return 0.7
	return 0.32 if (k.a or k.d) else 0.0


## Ride to the departure point at the ring's rate, so the escape starts with the orbit's motion.
func _step_phase(dt: float, t: float) -> float:
	var ph: Dictionary = rail.phase
	var T: float = ph.T
	var tau: float = t - float(ph.t0)
	if tau >= T:
		rail.erase("phase")
		fly_t0 = float(ph.t0) + T
		_fly_pos = plan.pos(clampf((t - fly_t0) / plan.dur, 0.0, 1.0))
		mode = &"fly"
		rail = {}
		keep = {}
		return 0.0
	var body := int(rail.body)
	var c := center(body, t)
	var cv := center_vel(body, t)
	var w: float = ph.w
	# (waiting for its plan, `fly_bg`: no end, the ring's own pace; a fast
	# flight's spin-up, `_ride_shape`)
	var ra := _ride_at(ph, tau)
	var a := float(ph.a0) + w * ra[0]
	var rt: float = rail.rt
	var tg := Vector2(-sin(a), cos(a))
	f.p = _flat(c) + Vector2(cos(a), sin(a)) * rt
	f.v = _flat(cv) + tg * w * ra[1] * rt
	rail.ang = a
	rcs = false
	var at: float = w * ra[2] * rt
	# (a ride sped up or, replaying a drawn flight, slowed: k under 1)
	var peak: float = absf(w) * _ride_peak(ph) * rt
	if absf(at) > 4.0:
		burn = true
		_nose(_scr_ang(tg * signf(at)), dt)
		_flame(absf(at) / maxf(peak, 1.0), dt)
		return 0.7 * burn_k
	burn = false
	burn_k = 0.0
	_burn_age = 0.0
	_nose(_scr_ang(tg * signf(w)), dt)
	return 0.0


## ONTO A RAIL round `body` (-1 the star), from `rel` off its centre moving at
## `rv` relative to it; with no rv, already on it (a flight's arrival, a restore).
func start_rail(body: int, rel: Vector2, rv: Variant, t: float, acc0 := Vector2.ZERO, on_k := 1.0) -> void:
	var b: SystemLayout.Body = null if body < 0 else L.bodies[body]
	var sb := body if SystemLayout.is_star(body) else -1
	var r0 := maxf(1.0, rel.length())
	var rt := orbit_r(body)
	var spd := STAR_RAIL_V if b == null else RAIL_V
	var hh := 1.0
	var w0 := spd / rt
	if rv != null:
		var rvv := rv as Vector2
		hh = rel.x * rvv.y - rel.y * rvv.x
		w0 = hh / (r0 * r0)
	var dir := 1.0 if hh >= 0.0 else -1.0
	if rv == null:
		w0 = dir * spd / rt
	mode = &"rail"
	keep = {}
	f.no_cap_left = 0.0
	f.orbit_r = -1.0
	# A twin's star rail is 2 px outside the keep-out, so A and D go no lower there.
	var rmin := (L.star_radius(sb) + 30.0) if b == null else (b.r + 10.0)
	var rmax := (star_ring(sb) - 4.0) if b == null else b.soi * 0.95
	if b == null and L.twin:
		rmin = star_rail(sb)
		rmax = star_ring(sb) - 1.0
	rail = {"body": body, "ang": atan2(rel.y, rel.x), "r0": rt, "rt": rt,
		"rmin": rmin, "rmax": rmax,
		"speed": spd, "dir": dir, "w0": dir * spd / rt, "u": 1.0, "s": 1.0}
	if rv != null:
		# ALREADY ON IT, at its speed (a solved flight lands on the ring exactly,
		# `FlightSolve`): no insertion, the ship rides on from where it is
		var rvv2 := rv as Vector2
		# (a flight on its own clock lands within ON_RING_V there: on the map,
		# pace times that, `on_k`)
		if absf(rel.length() - rt) < ON_RING_PX and absf(rvv2.length() - spd) < ON_RING_V * on_k and absf(rvv2.dot(rel / r0)) < ON_RING_V * on_k:
			return
		# ON IT, FASTER (a fast flight arrives at pace times its ring speed on
		# its own clock, `FlightSolve.RING_TAU`): no insertion, its rate eased
		# down to the ring's own over SPIN_S (`_step_rail`)
		if on_k > 1.0 and absf(rel.length() - rt) < ON_RING_PX and absf(rvv2.dot(rel / r0)) < ON_RING_V * on_k and rvv2.length() > spd:
			rail.w0 = hh / (r0 * r0)
			rail.u = 0.0
			rail.spin = {"t0": t, "a0": atan2(rel.y, rel.x), "w1": hh / (r0 * r0)}
			return
		_plan_insert(rel, rv as Vector2, rt, dir * spd / rt, b, acc0, sb)


## THE SPIN-DOWN after a fast flight's arrival (`start_rail`), at t: the ring's
## angle from the arrival, as the arrival tail draws it (`_tail`), the
## rate eased from the arrival's to the ring's own wt by smoothstep over SPIN_S;
## then it is the ring's. Sets rail.ang and rail.u; returns the rate.
func _spin_down(t: float, wt: float) -> float:
	var sd: Dictionary = rail.spin
	var tau := maxf(t - float(sd.t0), 0.0)
	var x := clampf(tau / SPIN_S, 0.0, 1.0)
	var w1 := float(sd.w1)
	rail.ang = float(sd.a0) + wt * tau + (w1 - wt) * SPIN_S * (x - x * x * x + 0.5 * x * x * x * x)
	var wv := wt + (w1 - wt) * (1.0 - x * x * (3.0 - 2.0 * x))
	rail.u = 1.0 if x >= 1.0 else minf(x, 0.999)
	rail.w0 = wv
	if x >= 1.0:
		rail.erase("spin")
	return wv


## A ship this close to a ring (px) and its speed (px/s) is on it: no insertion.
const ON_RING_PX := 0.05
const ON_RING_V := 0.05
## the ring drawn after a solved flight's arrival, as the ship rides it (s)
const TAIL_S := 1.0


## The insertion arrives with the circle's own velocity and pull, kept clear of the world's disc.
## Why: docs/why/ShipFlight.md#insertion-curve
func _plan_insert(p0: Vector2, v0: Vector2, rt: float, w: float, b: SystemLayout.Body, acc0 := Vector2.ZERO, star := -1) -> void:
	var best := insert_plan(p0, v0, rt, w, b, acc0, star)
	rail.ins = best
	rail.s = 0.0
	rail.ang = best.a1


## The insertion an approach would fly (the line draws it before it happens).
## `b` null: onto star `star`'s close orbit.
func insert_plan(p0: Vector2, v0: Vector2, rt: float, w: float, b: SystemLayout.Body, acc0 := Vector2.ZERO, star := -1) -> Dictionary:
	var r0 := maxf(p0.length(), 1.0)
	var w0 := (p0.x * v0.y - p0.y * v0.x) / (r0 * r0)
	var a0 := atan2(p0.y, p0.x)
	var clear := (b.r + 6.0) if b != null else (L.star_radius(star if SystemLayout.is_star(star) else -1) + 14.0)
	# (onto a twin's star: never inside its keep-out, 4 px inside its ring; star_r +
	# 14 there was about 20 px inside it)
	if b == null and L.twin:
		clear = keep_clear(star if SystemLayout.is_star(star) else -1)
	var base := clampf(2.4 * (absf(r0 - rt) + rt * 0.5) / (v0.length() + absf(w) * rt + 20.0), INSERT_T.x, INSERT_T.y)
	# Of the clear tries take the gentlest turn, as one that doubles back drew a loop or corner.
	var best := {}
	var best_k := INF
	var best_bent := true
	for tk: float in [1.0, 0.8, 1.25, 0.65, 1.5, 1.9]:
		for sk: float in [1.0, 0.6, 1.5, 2.0]:
			var T := clampf(base * tk, 0.45, 2.4)
			var a1 := a0 + (w0 + w) * 0.5 * T * sk
			var p1 := Vector2(cos(a1), sin(a1)) * rt
			var v1 := Vector2(-sin(a1), cos(a1)) * w * rt
			var ins := _polar_ins(p0, v0, acc0, rt, w, T, a1)
			var rmin := INF
			var amax := 0.0
			var kmax := 0.0
			var pv := Vector2.INF
			# AN INSERTION THAT BENDS ONE WAY AND THEN THE OTHER draws a hook:
			# the spiral in should turn one way all along
			var bend_sg := 0.0
			var bent := false
			for j in 33:
				var s := float(j) / 32.0
				rmin = minf(rmin, _ins_at(ins, s, 0).length())
				var aa := _ins_at(ins, s, 2)
				amax = maxf(amax, aa.length())
				var vv := _ins_at(ins, s, 1)
				var vs := Vector2(vv.x, vv.y * TILT)
				var as_ := Vector2(aa.x, aa.y * TILT)
				if vs.length() < 2.0 or (pv != Vector2.INF and vs.dot(pv) < 0.0):
					kmax = INF
				else:
					var kk := vs.cross(as_) / pow(vs.length(), 3.0)
					kmax = maxf(kmax, absf(kk))
					if absf(kk) > 1.0 / 60.0:
						if bend_sg != 0.0 and signf(kk) != bend_sg:
							bent = true
						bend_sg = signf(kk)
				pv = vs
			ins.amax = amax
			if best.is_empty():
				best = ins
			if rmin >= clear and ((best_bent and not bent) or (bent == best_bent and kmax < best_k)):
				best = ins
				best_k = kmax
				best_bent = bent
				# gentle enough (no turn tighter than 15 px), one way: no need to look further
				if kmax < 1.0 / 15.0 and not bent:
					best.kmax = best_k
					return best
	best.kmax = best_k if best_k < INF else 99.0
	return best


## Built in polar terms so a head-on approach spirals in instead of drawing a hairpin.
## Why: docs/why/ShipFlight.md#insertion-curve
static func _polar_ins(p0: Vector2, v0: Vector2, acc0: Vector2, rt: float, w: float, T: float, a1: float) -> Dictionary:
	var r0 := maxf(p0.length(), 0.5)
	var er := p0 / r0
	var ep := Vector2(-er.y, er.x)
	var rd := v0.dot(er)
	var pd := v0.dot(ep) / r0
	# the pull's parts, as radius'' - r angle'^2 and r angle'' + 2 radius' angle'
	var rdd := acc0.dot(er) + r0 * pd * pd
	var pdd := (acc0.dot(ep) - 2.0 * rd * pd) / r0
	var ph0 := atan2(p0.y, p0.x)
	# the end angle, on the same turn of the circle as the way it goes
	var ph1 := ph0 + wrapf(a1 - ph0, -PI, PI)
	var dirw := signf(w) if w != 0.0 else 1.0
	if (ph1 - ph0) * dirw < 0.0:
		ph1 += TAU * dirw
	var ins := {"polar": true, "T": T, "a1": ph1,
		"ph": [ph0, pd * T, pdd * T * T, ph1, w * T, 0.0],
		"rr": [r0, rd * T, rdd * T * T, rt, 0.0, 0.0]}
	return ins


## The insertion at s (0..1): its position (d 0), velocity (1) or acceleration
## (2), per second, in the world's frame.
static func _ins_at(ins: Dictionary, s: float, d: int) -> Vector2:
	var T: float = ins.T
	if ins.get("polar", false):
		var ph := _q5(ins.ph, s, 0)
		var r := _q5(ins.rr, s, 0)
		var er := Vector2(cos(ph), sin(ph))
		var ep := Vector2(-er.y, er.x)
		if d == 0:
			return er * r
		var p1 := _q5(ins.ph, s, 1) / T
		var r1 := _q5(ins.rr, s, 1) / T
		if d == 1:
			return er * r1 + ep * r * p1
		var p2 := _q5(ins.ph, s, 2) / (T * T)
		var r2 := _q5(ins.rr, s, 2) / (T * T)
		return er * (r2 - r * p1 * p1) + ep * (r * p2 + 2.0 * r1 * p1)
	var s2 := s * s
	var s3 := s2 * s
	var s4 := s3 * s
	var s5 := s4 * s
	var hh: Array
	if d == 0:
		hh = [1.0 - 10.0 * s3 + 15.0 * s4 - 6.0 * s5, s - 6.0 * s3 + 8.0 * s4 - 3.0 * s5,
			0.5 * s2 - 1.5 * s3 + 1.5 * s4 - 0.5 * s5, 0.5 * s3 - s4 + 0.5 * s5,
			-4.0 * s3 + 7.0 * s4 - 3.0 * s5, 10.0 * s3 - 15.0 * s4 + 6.0 * s5]
	elif d == 1:
		hh = [-30.0 * s2 + 60.0 * s3 - 30.0 * s4, 1.0 - 18.0 * s2 + 32.0 * s3 - 15.0 * s4,
			s - 4.5 * s2 + 6.0 * s3 - 2.5 * s4, 1.5 * s2 - 4.0 * s3 + 2.5 * s4,
			-12.0 * s2 + 28.0 * s3 - 15.0 * s4, 30.0 * s2 - 60.0 * s3 + 30.0 * s4]
	else:
		hh = [-60.0 * s + 180.0 * s2 - 120.0 * s3, -36.0 * s + 96.0 * s2 - 60.0 * s3,
			1.0 - 9.0 * s + 18.0 * s2 - 10.0 * s3, 3.0 * s - 12.0 * s2 + 10.0 * s3,
			-24.0 * s + 84.0 * s2 - 60.0 * s3, 60.0 * s - 180.0 * s2 + 120.0 * s3]
	var q: Vector2 = (ins.p0 as Vector2) * float(hh[0]) + (ins.v0 as Vector2) * T * float(hh[1]) \
		+ (ins.a0v as Vector2) * T * T * float(hh[2]) + (ins.a1v as Vector2) * T * T * float(hh[3]) \
		+ (ins.v1 as Vector2) * T * float(hh[4]) + (ins.p1 as Vector2) * float(hh[5])
	return q / pow(T, float(d))


## One insertion step along the curve round the moving world; W breaks off it.
func _step_insert(dt: float, t: float, k: Dictionary) -> float:
	if rail.has("arrive"):
		return _step_arrive(dt, t, k)
	var body := int(rail.body)
	var ins: Dictionary = rail.ins
	var c := center(body, t)
	var cv := center_vel(body, t)
	if k.w:
		mode = &"free"
		_fly_done = Callable()
		f.v = _flat(cv) + _ins_at(ins, float(rail.s), 1)
		f.no_cap_body = body
		f.no_cap_left = NO_CAPTURE_S
		f.coast = 0.0
		rail = {}
		return 0.7
	var s_raw: float = float(rail.s) + dt / float(ins.T)
	if s_raw >= 1.0:
		# ON THE CIRCLE, carried on round it for what is left of the frame (a
		# last sliver of curve would show as a frame that does not move)
		var w: float = float(rail.dir) * float(rail.speed) / float(rail.rt)
		var a: float = float(ins.a1) + w * (s_raw - 1.0) * float(ins.T)
		var rt: float = rail.rt
		rail.s = 1.0
		rail.ang = a
		rail.u = 1.0
		f.p = _flat(c) + Vector2(cos(a), sin(a)) * rt
		f.v = _flat(cv) + Vector2(-sin(a), cos(a)) * w * rt
		burn = false
		burn_k = 0.0
		_burn_age = 0.0
		_arrived()
		return 0.0
	rail.s = s_raw
	var s: float = rail.s
	var rel := _ins_at(ins, s, 0)
	f.p = _flat(c) + rel
	f.v = _flat(cv) + _ins_at(ins, s, 1)
	var acc := _ins_at(ins, s, 2)
	rcs = false
	if s >= 1.0:
		rail.ang = float(ins.a1)
		rail.u = 1.0
		burn = false
		burn_k = 0.0
		_burn_age = 0.0
		return 0.0
	burn = acc.length() > 3.0
	if burn:
		_nose(_scr_ang(acc), dt)
		_flame(acc.length() / maxf(float(ins.amax), 1.0), dt)
	return 0.7 * burn_k if burn else 0.0


## Straight onto a place, no flight: a harness, or a ship put back where it was.
func place_at(body: int, t: float) -> void:
	if body == -3:
		setup(L, edge_at, t)
		warp_t = -100.0
		return
	fresh = false
	_drop_flight()
	if is_keep(body):
		mode = &"keep"
		var c := center(body, t)
		keep = {"body": body, "off": KEEP_OFF, "ev": Vector2.ZERO, "inf": KEEP_OFF}
		f.p = _flat(c) + KEEP_OFF
		return
	start_rail(body, Vector2(orbit_r(body), 0.0), null, t)


## Put back on its ring where it rode, as a ship placed at +x jumped across its world on a Tab back.
## Why: docs/why/ShipFlight.md#rail-restore
func rail_back(body: int, rel: Vector2, dir: float, t: float) -> void:
	place_at(body, t)
	if mode != &"rail" or rel.length() < 0.5:
		return
	var u := rel.normalized()
	var spd := STAR_RAIL_V if body < 0 else RAIL_V
	start_rail(body, u * orbit_r(body), Vector2(-u.y, u.x) * spd * (-1.0 if dir < 0.0 else 1.0), t)


## Where a ship sits alongside a station, belt, hulk or contact, from its place.
const KEEP_OFF := Vector2(8.0, 5.0 / TILT)


## Looks up to five seconds ahead; if the coast goes into a ring the star settle holds off.
func capture_ahead(st: FreeState, t: float) -> bool:
	var no_cap := st.no_cap_body if st.no_cap_left > 0.0 else -9
	for j in range(1, 51):
		var tau := float(j) * 0.1
		var p := st.p + st.v * tau
		for s in _stars:
			# (where the star is then, and the ship's motion against its own: a
			# turning pair's suns move, as `free_step`'s close rings take it)
			var qa := p - L.star_pos(s, t + tau)
			var va := st.v - L.star_vel(s, t + tau)
			if no_cap != s and qa.length() < star_ring(s) and va.length() < CAPTURE and _star_takes(s, va, qa / maxf(qa.length(), 0.001)):
				return true
		for b in L.bodies:
			if b.index == no_cap:
				continue
			if b.world == &"" and not is_keep(b.index):
				continue
			var c := center(b.index, t + tau)
			var rel := Vector2(p.x - c.x, p.y - c.z)
			var reach: float = b.soi if b.world != &"" else KEEP_R
			var d := rel.length() if b.world != &"" else Vector2(rel.x, rel.y * TILT).length()
			if d < reach and (st.v - _flat(center_vel(b.index, t + tau))).length() < CAPTURE:
				return true
	return false


## Arrival radius keeps every place's ring well clear; in a twin bodies sweep a band of
## distances from the balance point, which each star's ring is also kept clear of.
## Why: docs/why/ShipFlight.md#arrival-orbit
func arrival_r(r0: float) -> float:
	var c := L.bary if L.twin else Vector2.ZERO
	var lo := star_ring() + 40.0
	var hi := L.edge - SystemLayout.ARRIVE_IN
	if L.twin:
		lo = 0.0
		# (from the balance point: the same at every angle of the pair)
		for s in _stars:
			lo = maxf(lo, (L.star_pos(s, 0.0) - c).length() + star_ring(s) + 40.0)
		hi = L.edge - c.length() - SystemLayout.ARRIVE_IN
	# The host distance is read at t 0, as the pair's turn does not change it.
	var twin := L.twin
	var clear := func(r: float) -> bool:
		for b in L.bodies:
			var reach: float = SystemLayout.arrive_reach(b)
			if reach <= 0.0:
				continue
			if not twin or b.host_id == -9:
				if absf(r - b.orbit) < reach:
					return false
			else:
				var dh := (b.host0 - c).length()
				if r > absf(dh - b.orbit) - reach and r < dh + b.orbit + reach:
					return false
		return true
	var r := clampf(r0, lo, hi)
	if clear.call(r):
		return r
	for k in range(1, 200):
		var up := r + 4.0 * k
		if up <= hi and clear.call(up):
			return up
		var dn := r - 4.0 * k
		if dn >= lo and clear.call(dn):
			return dn
	return r


## Inside a place's capture ring (the star's close ring, a world's).
func _inside(body: int, p: Vector2, t: float) -> bool:
	if SystemLayout.is_star(body):
		return (p - L.star_pos(body, t)).length() < star_ring(body)
	if body < 0 or body >= L.bodies.size() or L.bodies[body].world == &"":
		return false
	var c := center(body, t)
	return Vector2(p.x - c.x, p.y - c.z).length() < L.bodies[body].soi


# ---------------------------------------------------------------- one step of open space
# One step shared by the ship and its line, so the line can only show what the ship will do.
# Why: docs/why/ShipFlight.md#free-step
func free_step(st: FreeState, k: Dictionary, t: float, dt: float, stick: int, real: bool, cs := PackedVector3Array()) -> Dictionary:
	var have_c := not cs.is_empty()
	if k.a:
		st.head -= TURN * dt
	if k.d:
		st.head += TURN * dt
	var nose := Vector2(cos(st.head), sin(st.head) / TILT).normalized()
	if k.w:
		# thrust fades into the top speed; turning under thrust cannot build past it
		var along := st.v.dot(nose)
		st.v += nose * THRUST * clampf(1.0 - along / VMAX, 0.0, 1.0) * dt
		var n := st.v.length()
		if n > VMAX:
			st.v *= maxf(VMAX, n - THRUST * 2.0 * dt) / n
	if k.s:
		st.v *= exp(-BRAKE * dt)
	# THE STARS WHERE THEY ARE AT t (`_stars_at`; a turning pair's move), and the
	# settle's centre with them
	if _s_pos.size() != _stars.size():
		_cache_stars()
	var moving := _stars_at(t)
	var cv := _follow(st, moving)
	# Round a sun of a turning pair the settle runs in that sun's own frame, as a fixed
	# centre left the ship at up to 1.1 px/s.
	# Why: docs/why/ShipFlight.md#star-settle
	st.acc = Vector2.ZERO
	if k.w or k.s:
		st.coast = 0.0
		st.orbit_r = -1.0
		st.aim = Vector2.ZERO
	elif st.bound and st.orbit_r < 0.0:
		# COASTING INTO A RING: the settle does not take you off your way to it
		st.coast = 0.0
		st.aim = Vector2.ZERO
	else:
		if st.coast == 0.0:
			_settle_centre(st, t)
			cv = _follow(st, moving)
			# the way round it is already going, unless it is hardly going round
			var q0 := st.p - st.cen
			var v0 := st.v - cv
			var tang := (q0.x * v0.y - q0.y * v0.x) / maxf(q0.length(), 1.0)
			st.sense = signf(tang) if absf(tang) > 20.0 else 1.0
		st.coast += dt
		# (the orbit's motion against the centre, then as the map sees it)
		var tvr := star_orbit_v(st.p, st.orbit_r if st.orbit_r > 0.0 else st.r_want, st.sense, st.cen, st.cen_share)
		var tv := tvr + cv
		var vr0 := st.v - cv
		var dv := tv - st.v
		var ramp := smoothstep(SETTLE_TURN, SETTLE_TURN + SETTLE_RAMP, st.coast)
		var turn_by := vr0.angle_to(tvr)
		if vr0.length() > 10.0 and absf(turn_by) > 0.5:
			# GOING THE OTHER WAY: the motion swings round toward the orbit's at
			# speed (a turn you can see), not braked through nought and reversed
			var spd := vr0.length()
			var rot := clampf(turn_by, -SETTLE_W * dt, SETTLE_W * dt) * ramp
			var nspd := move_toward(spd, maxf(tvr.length(), 20.0), SETTLE_A * 0.5 * dt * ramp)
			var nv := vr0.rotated(rot).normalized() * nspd + cv
			st.aim = vr0.rotated(signf(turn_by) * PI / 2.0).normalized() * SETTLE_A
			st.acc = (nv - st.v) / dt
			st.v = nv
		else:
			var want := dv / SETTLE_TAU
			if want.length() > SETTLE_A:
				want *= SETTLE_A / want.length()
			st.aim = want
			st.acc = want * ramp
			# The circle's own pull is the star's, not a burn;
			# without it the ship creeps out and never settles.
			var q := st.p - st.cen
			var r0 := maxf(q.length(), 1.0)
			var pull := -q / r0 * tvr.length_squared() / r0 * ramp
			st.v += (st.acc + pull) * dt
		# Settled only once on its own radius, not while it rides the pull in at its pace.
		if st.orbit_r < 0.0 and dv.length() < SETTLED_DV and st.coast > SETTLE_TURN + SETTLE_RAMP \
				and (st.r_want <= 0.0 or absf((st.p - st.cen).length() - st.r_want) < SETTLED_PX):
			st.orbit_r = st.r_want if st.r_want > 0.0 else (st.p - st.cen).length()
	# THE RING YOU LEFT lets you go until you are out of it, and a moment more
	if st.no_cap_left > 0.0 and not _inside(st.no_cap_body, st.p, t):
		st.no_cap_left -= dt
	var no_cap := st.no_cap_body if st.no_cap_left > 0.0 else -9
	var sp := st.v.length()
	var vs0 := st.v
	# The bumper works against the star's own motion, as its close ring takes the ship.
	for si in _stars.size():
		var s := _stars[si]
		var qs := st.p - _sp_at[si]
		var r := qs.length()
		var rh := qs / r if r > 0.001 else Vector2.RIGHT
		var bm := _s_bump[si]
		var sv := _sv_at[si] if moving else Vector2.ZERO
		var spr := (vs0 - sv).length() if moving else sp
		if r < bm and not (no_cap != s and spr < CAPTURE + (STICKY if stick == s else 0.0) and not k.w and _star_takes(s, st.v - sv, rh)):
			var kk := (bm - r) / bm
			var turn := 10.0
			if L.twin:
				# A twin's bumper is only 12 px deep, so it ramps over all of it; W held at a sun
				# drove the ship 18 to 22 px into the drawn sun.
				# Why: docs/why/ShipFlight.md#twin-bumper
				kk = clampf((bm - r) / maxf(bm - _s_keep[si], 1.0), 0.0, 1.0)
				turn = TWIN_TURN
			var rv := st.v - sv
			var vr := rv.dot(rh)
			if vr < 0.0:
				rv -= rh * minf(1.0, kk * turn * dt) * vr
				var nn := rv.length()
				if nn > 0.01:
					rv *= spr / nn
				st.v = rv + sv
			st.v += rh * 40.0 * kk * dt
			st.bumped = true
	for b in L.bodies:
		if b.world == &"":
			continue
		var c: Vector3 = cs[b.index] if have_c else center(b.index, t)
		var d := Vector2(st.p.x - c.x, st.p.y - c.z)
		var dd := d.length()
		var m := maxf(b.r, 10.0) + 10.0
		if dd < m and dd > 0.01:
			var nrm := d / dd
			var vr2 := st.v.dot(nrm)
			if vr2 < 0.0:
				st.v -= nrm * vr2 * 1.2
			st.bumped = true
	st.p += st.v * dt
	# The edge is measured round the origin, not the balance point, which stopped the ship
	# short on one side or let it fly past on the other.
	# Why: docs/why/ShipFlight.md#map-edge
	var rr := st.p.length()
	if rr > L.edge:
		st.p *= L.edge / rr
		var vr3 := st.v.dot(st.p / L.edge)
		if vr3 > 0.0:
			st.v -= st.p / L.edge * vr3
	if real or L.twin:
		# Out of the star's disc as drawn; star_r + 8 was half way into a twin's drawn sun.
		for s2 in _stars.size():
			var sc2 := _sp_at[s2]
			var q2 := st.p - sc2
			var r2 := q2.length()
			var rd := _s_hold[s2]
			if r2 < rd and r2 > 0.001:
				st.p = sc2 + q2 / r2 * rd
				if L.twin:
					var sv2 := _sv_at[s2] if moving else Vector2.ZERO
					var vr4 := (st.v - sv2).dot(q2 / r2)
					if vr4 < 0.0:
						st.v -= q2 / r2 * vr4
	if k.w:
		return {}
	# Take the ring the line shows, else the nearest; first-by-index put a ship on the giant
	# when letting go by a hulk.
	# Why: docs/why/ShipFlight.md#capture-rules
	var take := {}
	var take_d := INF
	var fast := {}
	# The settle's pull-through is not a capture unless it
	# is the line's, or the ship hit the world it passed.
	var pulled := st.r_want > 0.0 and st.orbit_r < 0.0 and st.coast > SETTLE_TURN
	for b in L.bodies:
		if b.world == &"" or b.index == no_cap or (pulled and b.index != stick):
			continue
		var c2: Vector3 = cs[b.index] if have_c else center(b.index, t)
		var rel := Vector2(st.p.x - c2.x, st.p.y - c2.z)
		if rel.length() < b.soi:
			var rv := st.v - _flat(center_vel(b.index, t))
			if rv.length() < CAPTURE + (STICKY if stick == b.index else 0.0):
				var tk := {"kind": &"rail", "body": b.index, "rel": rel, "rv": rv, "at": st.p}
				if capture_by_index:
					return tk
				if take_d > -1.0 and (b.index == stick or rel.length() < take_d):
					take = tk
					take_d = -1.0 if b.index == stick else rel.length()
			elif st.fast_seen != b.index and fast.is_empty():
				fast = {"kind": &"fast", "body": b.index, "at": st.p}
				if capture_by_index:
					st.fast_seen = b.index
					return fast
	for si3 in _stars.size():
		var s3 := _stars[si3]
		var rs := st.p - _sp_at[si3]
		if no_cap != s3 and rs.length() < _s_ring[si3]:
			# (the motion against the star's, as a world's ring takes it: the rail
			# then rides round with a turning sun, `center`)
			var rvs := st.v - (_sv_at[si3] if moving else Vector2.ZERO)
			if not _star_takes(s3, rvs, rs / maxf(rs.length(), 0.001)):
				continue
			if rvs.length() < CAPTURE + (STICKY if stick == s3 else 0.0):
				var tk2 := {"kind": &"rail", "body": s3, "rel": rs, "rv": rvs, "at": st.p}
				if capture_by_index:
					return tk2
				if take_d > -1.0 and (s3 == stick or rs.length() < take_d):
					take = tk2
					take_d = -1.0 if s3 == stick else rs.length()
			elif st.fast_seen != s3 and fast.is_empty():
				fast = {"kind": &"fast", "body": s3, "at": st.p}
				if capture_by_index:
					st.fast_seen = s3
					return fast
	for b in L.bodies:
		if not is_keep(b.index) or b.index == no_cap or (pulled and b.index != stick):
			continue
		var c3: Vector3 = cs[b.index] if have_c else center(b.index, t)
		var rel3 := Vector2(st.p.x - c3.x, st.p.y - c3.z)
		# (its motion, two more centres, only for a place this close)
		if Vector2(rel3.x, rel3.y * TILT).length() < KEEP_R:
			var rv3 := st.v - _flat(center_vel(b.index, t))
			if rv3.length() < CAPTURE + (STICKY if stick == b.index else 0.0):
				var tk3 := {"kind": &"keep", "body": b.index, "rel": rel3, "rv": rv3, "at": st.p}
				if capture_by_index:
					return tk3
				if take_d > -1.0 and (b.index == stick or rel3.length() < take_d):
					take = tk3
					take_d = -1.0 if b.index == stick else rel3.length()
	if not take.is_empty():
		return take
	if not fast.is_empty():
		st.fast_seen = int(fast.body)
		return fast
	return {}


## A twin's star takes only slow inward ships: at 150 px/s the insertion dipped to 31 px
## from a sun whose keep-out is 47.
## Why: docs/why/ShipFlight.md#capture-rules
func _star_takes(_s: int, v: Vector2, rh: Vector2) -> bool:
	if not L.twin:
		return true
	return -v.dot(rh) <= STAR_IN_V


const STAR_IN_V := 30.0
## a twin's bumper turns the inward motion away at up to this rate (1/s)
const TWIN_TURN := 40.0


## Old capture rule kept so FlightTest can measure what the new one changed.
static var capture_by_index := false


# ---------------------------------------------------------------- the line
# The same step run forward; the shown capture changes only after it has held 0.25 s.
func predict(t: float, k: Dictionary) -> void:
	if mode != &"free":
		line = {}
		hold_line = {}
		sticky = -9
		return
	var any: bool = k.w or k.a or k.s or k.d
	if f.orbit_r > 0.0 and not any:
		# on the star's orbit already: the ring is drawn, there is nothing to foresee
		line = {}
		hold_line = {}
		return
	_ctab.clear()
	line = _run_line(t, {"w": false, "a": false, "s": false, "d": false}, 0.0)
	hold_line = _run_line(t, k, 1.5) if any else {}
	_ctab.clear()
	var meet: int = -9
	if not (line.out as Dictionary).is_empty() and line.out.kind != &"star":
		meet = int(line.out.body)
	if meet != _meet_raw:
		_meet_raw = meet
		_meet_t = t
	if t - _meet_t > 0.25:
		sticky = meet


## Centres are worked out once a frame: both lines each looked up every place's centre,
## about 6,800 calls a frame for one answer per place.
## Why: docs/why/ShipFlight.md#centre-table
var _ctab: Array = []
static var centre_table := true


func _centres(i: int, t: float) -> PackedVector3Array:
	if i < _ctab.size() and float(_ctab[i][0]) == t:
		return _ctab[i][1]
	var cs := PackedVector3Array()
	cs.resize(L.bodies.size())
	for b in L.bodies:
		cs[b.index] = center(b.index, t)
	if i == _ctab.size():
		_ctab.append([t, cs])
	elif i < _ctab.size():
		_ctab[i] = [t, cs]
	return cs


func _run_line(t0: float, k: Dictionary, hold: float) -> Dictionary:
	var st := f.copy()
	var pts := PackedVector2Array([st.p])
	var fast: Array = []
	var bump := Vector2.INF
	var out: Dictionary = {}
	var none := {"w": false, "a": false, "s": false, "d": false}
	var hstep := 1.0 / 30.0
	var t := t0
	for i in 180:
		var kk: Dictionary = k if i * hstep < hold else none
		st.bumped = false
		var res := free_step(st, kk, t, hstep, sticky, false, _centres(i, t) if centre_table else PackedVector3Array())
		t += hstep
		pts.append(st.p)
		if st.bumped and bump == Vector2.INF:
			bump = st.p
		var kind: StringName = res.get("kind", &"")
		if kind == &"fast":
			fast.append(res)
		elif kind == &"rail" or kind == &"keep":
			out = res
			out.t = t
			break
		var held: bool = kk.w or kk.a or kk.s or kk.d
		if not held and st.orbit_r > 0.0:
			# SETTLED ROUND THE STAR, here: `c` the centre (a twin's star, or its
			# balance point, `id` -9), `r` the radius round it
			out = {"kind": &"star", "body": -1, "r": st.orbit_r, "at": st.p, "t": t, "v": st.v, "c": st.cen, "id": st.cen_id}
			break
	return {"pts": pts, "out": out, "fast": fast, "bump": bump}


# ---------------------------------------------------------------- flights
const SAMPLE := 1.0 / 240.0
## Out of an orbit at this speed along it (and a third of it outward), the
## coast met at the target's ring at APP_V relative to it.
const ESC_V := 110.0
const APP_V := 70.0
## The burns that blend a coast's ends onto the motions either side.
const T_BURN := 0.35
## The ride takes as long as needed up to LEAD_MAX; further round, a phasing burn.
const LEAD_MAX := 2.2
## How much pull a blend takes on (px/s²), and how much the insertion starts with.
const A_BLEND := 1500.0
const A_INS := 600.0
## A harness (FlightTest `why=`): say why each try at a plan fails.
static var why := false
## How long a coast may stretch: 5 s, or 7 s on the last pass, for the few
## (fast inward arcs to a place near the star) nothing shorter flies cleanly.
var _tcap := 5.0
## The last pass: the waypoint far out, a loop wide of everything.
var _high := false
## a waypoint between the two ends' radii, so a flight in or out round most of
## a lap is one spiral, not a climb out past both and a fall back
var _mid := false


## The first clean manoeuvre wins, strict limits before merely clear; the least bad is `unclean`.
## A flight starts only from a settled orbit, not mid-flight, burning or settling.
## Why: docs/why/ShipFlight.md#flight-choice
func heading_to() -> int:
	if not _pend.is_empty():
		return int(_pend.i)
	match mode:
		&"fly":
			return fly_to
		&"rail":
			if rail.has("phase"):
				return fly_to
			if inserting():
				return int(rail.body)
		&"keep":
			if keep.has("hold"):
				return fly_to
			if inserting():
				return int(keep.body)
	return -9


## The flight under way as it will be flown from t0, a point every dt s (told to a partner, PROTOCOL 17):
## [pts, lit, dep_s, arr_s], or [] when nothing is under way.
## Why: docs/why/ShipFlight.md#said-path
func said_path(t0: float, dt: float) -> Array:
	var pl := plan
	if pl == null or pl.samp.size() < 2 or dt <= 0.0:
		return []
	var tf := 0.0
	var ph: Dictionary = {}
	match mode:
		&"fly":
			tf = fly_t0
		&"rail":
			if not rail.has("phase") or rail.phase.get("wait", false):
				return []
			ph = rail.phase
			tf = float(ph.t0) + float(ph.T)
		&"keep":
			if not keep.has("hold") or keep.get("wait", false):
				return []
			tf = float(keep.hold)
		_:
			return []
	var t_end := tf + float(pl.dur)
	var tail_s := TAIL_S if pl.res != null and not pl.tail_lit and pl.tail.size() > 1 else 0.0
	var n := maxi(2, ceili((t_end + tail_s - t0) / dt) + 1)
	var pts := PackedVector2Array()
	var lit := PackedByteArray()
	for j in n:
		# (the last sample can fall past the end: held there, so a plan with no tail never reads one)
		var tj := minf(t0 + float(j) * dt, t_end + tail_s)
		var q := Vector3.ZERO
		var on := false
		if tj < tf:
			if not ph.is_empty():
				# (the ride round the ring, as `_step_phase` flies it)
				var ra := _ride_at(ph, tj - float(ph.t0))
				var a := float(ph.a0) + float(ph.w) * ra[0]
				var c := center(int(rail.body), tj)
				q = c + Vector3(cos(a), 0.0, sin(a)) * float(rail.rt)
				on = absf(float(ph.w) * ra[2] * float(rail.rt)) > 4.0
			else:
				# (holding alongside, where it rests)
				var ck := center(int(keep.body), tj)
				var off: Vector2 = keep.get("inf", keep.off)
				q = ck + Vector3(off.x, 0.0, off.y)
		elif tj <= t_end:
			var u := clampf((tj - tf) / maxf(float(pl.dur), 1e-6), 0.0, 1.0)
			q = pl.pos(u)
			on = pl.burning(u)
		else:
			var x := clampf((tj - t_end) / TAIL_S, 0.0, 1.0) * float(pl.tail.size() - 1)
			var k := mini(int(x), pl.tail.size() - 2)
			q = pl.tail[k].lerp(pl.tail[k + 1], x - float(k))
		pts.append(Vector2(q.x, q.z))
		lit.append(1 if on else 0)
	return [pts, lit, maxf(tf - t0, 0.0), maxf(t_end - t0, 0.0)]


## SPINNING DOWN onto its ring after a fast flight (`start_rail`'s spin), with
## nothing else under way: `can_fly` is false for that moment only.
func spinning() -> bool:
	return mode == &"rail" and rail.has("spin") and not rail.has("phase") and not inserting() and _pend.is_empty()


func can_fly() -> bool:
	# (a flight asked for, still being planned: it is under way)
	if not _pend.is_empty():
		return false
	match mode:
		&"rail":
			# (and not while it spins down onto its ring after a fast flight)
			return not rail.is_empty() and not inserting() and not rail.has("phase") and float(rail.get("u", 1.0)) >= 1.0
		&"keep":
			return not keep.is_empty() and not inserting() and not keep.has("hold")
		&"free":
			return star_orbiting()
	return false


# ---------------------------------------------------------------- the solved flight
# Pull and keep-outs are made once a visit as pure data, so a worker can read them.
var _grav_v: MapGravity = null
var _grav_n := -1
func _grav() -> MapGravity:
	if _grav_v == null or _grav_n != L.bodies.size():
		_grav_v = MapGravity.from_layout(L)
		_grav_n = L.bodies.size()
		_grav_p = null
	return _grav_v


## THE SAME ON A FLIGHT'S CLOCK (`MapGravity.paced`), made here on the map's
## thread and kept while the pace holds, so a worker only reads it.
var _grav_p: MapGravity = null
func _grav_at(k: float) -> MapGravity:
	var g := _grav()
	if k == 1.0:
		return g
	if _grav_p == null or _grav_p.pace != k:
		_grav_p = g.paced(k)
	return _grav_p


## WHAT A FLIGHT IS PLANNED WITH NOW: {path, pace} (`FlightSolve.solve`'s
## opts): the AUTOPILOT setting's path, and its pace (`FLIGHT_PACE`), each as
## a harness's command line may set it.
static func flight_opts() -> Dictionary:
	if pace_k < 0.0:
		pace_k = 0.0
		for a in OS.get_cmdline_user_args():
			var s := a as String
			if s.begins_with("flight_pace="):
				# (at least 1: under it the ride spins the other way from the
				# solver's, the code review, Nov 5)
				pace_k = maxf(float(s.substr(12)), 1.0)
			elif s.begins_with("autopilot="):
				path_k = StringName(s.substr(10))
	var path: StringName = path_k if path_k == &"direct" or path_k == &"curved" else DisplaySettings.autopilot
	if path != &"direct":
		path = &"curved"
	var k: float = pace_k if pace_k > 0.0 else float(FLIGHT_PACE[path])
	# (CURVED's arc dials read here, on the main thread, before any worker plans)
	FlightSolve.curved_arc()
	return {"path": path, "pace": k}


static func aids_on() -> bool:
	if look_aids < 0:
		look_aids = 1
		for a in OS.get_cmdline_user_args():
			if a == "lookaids=0":
				look_aids = 0
	return look_aids == 1


## Counters for a harness: solved flights, old-planner fallbacks, none, and stale drops.
static var n_solved := 0
static var n_fallback := 0
static var n_none := 0
static var n_stale := 0
## the last plan's own time on the thread that made it (ms), and whether it was
## made on a worker
var last_ms := 0.0
var last_bg := false


## A worker plan is made for a moment ahead, so its departure is still to come when taken in.
## Why: docs/why/ShipFlight.md#departure-state
func _dep_of(t: float, ahead := 0.0) -> Dictionary:
	match mode:
		&"rail":
			if rail.is_empty() or inserting() or (rail.has("phase") and not rail.phase.get("wait", false)):
				return {}
			var rt := float(rail.rt)
			var w := float(rail.dir) * float(rail.speed) / rt
			return {"kind": &"ring", "place": int(rail.body), "rt": rt, "ang": float(rail.ang) + w * ahead, "w": w}
		&"keep":
			if keep.is_empty() or inserting() or (keep.has("hold") and not keep.get("wait", false)):
				return {}
			return {"kind": &"keep", "place": int(keep.body), "off": keep.get("inf", keep.off)}
		&"free":
			if star_orbiting():
				var q := f.p - f.cen
				var rt2 := f.orbit_r
				var w2 := f.sense * star_pace(rt2, f.cen_share) / rt2
				var d := {"kind": &"ring", "place": -9, "c": f.cen, "rt": rt2, "ang": atan2(q.y, q.x) + w2 * ahead, "w": w2}
				# Round a sun of a pair the planner rides that sun's circle,
				# as a fixed centre is off by the sun's own motion of about 1 px/s.
				# Why: docs/why/ShipFlight.md#departure-state
				if L.twin and SystemLayout.is_star(f.cen_id):
					d["host"] = f.cen_id
					d["c"] = L.star_pos(f.cen_id, t + ahead)
				return d
			return {"kind": &"free", "p": f.p, "v": f.v}
		&"warp":
			return {"kind": &"free", "p": f.p, "v": Vector2.ZERO}
	return {}


## Worker plans are made 0.25 s ahead: made for now, a flight leaving at once was gone
## by the time it came in.
## Why: docs/why/ShipFlight.md#plan-lead-time
const PLAN_AHEAD := 0.25
## Previews look 1 s ahead, as one planned 0.25 s ahead went stale in a quarter second
## and the overlay planned it about four times a second.
## Why: docs/why/ShipFlight.md#plan-lead-time
const PREVIEW_AHEAD := 1.0
## A click on a fast flight's preview that leaves more than CLICK_LATE s on plans a fresh flight
## from the click, and flies it when it arrives CLICK_GAIN s sooner; else the drawn one.
## Why: docs/why/ShipFlight.md#click-on-a-late-preview
const CLICK_LATE := 0.45
const CLICK_GAIN := 0.15
## whether the last click flew a flight planned at it, not the one drawn (a
## harness reads it)
var click_replanned := false
## THE ARRIVAL ASKED FOR at a world (`ArriveSide`), set by the map for the selected world and every flight it starts
var wish: Dictionary = {}


## Whether a flight planned at the click (pn) goes before the drawn one (pv).
static func _sooner(pn: FlightPlan, pv: FlightPlan) -> bool:
	if pn == null or pn.res == null or pv == null or pv.res == null:
		return false
	return float(pn.end.t) < float(pv.end.t) - CLICK_GAIN


## The line is laid out on the worker too, as doing it on the main thread cost 3 to 8 ms.
## Why: docs/why/ShipFlight.md#planning-on-workers
const LINE_N := 1600


## Arrival: a ring at RAIL_V either way round, a star's close orbit, or alongside a place; a wish
## (`ArriveSide`) only on the world it was made for, never another (GO-lit, Jon, Nov 11).
func _tgt_of(i: int) -> Dictionary:
	if is_keep(i):
		return {"kind": &"keep", "place": i, "off": KEEP_OFF}
	if SystemLayout.is_star(i):
		return {"kind": &"ring", "place": i, "R": orbit_r(i), "V": STAR_RAIL_V, "sense": 0}
	return ArriveSide.ring_target(i, orbit_r(i), RAIL_V, wish if int(wish.get("to", -9)) == i else {})


## A solved flight as a FlightPlan, with the insertion after it drawn.
func _plan_of(r: FlightSolve.Result, i: int, dep: Dictionary, t: float) -> FlightPlan:
	var pl := FlightPlan.new()
	pl.conic = false
	pl.kind = &"solved"
	pl.res = r
	pl.to = i
	pl.dep = dep
	pl.t_plan = t
	pl.t0 = r.t0
	pl.sdt = r.sdt
	pl.samp = r.samp
	pl.burns = r.burns
	pl.dur = r.dur
	pl.amax = r.amax
	pl.esc_t = r.esc_t
	pl.end = r.end.duplicate()
	pl.lead = r.lead
	pl.lead_k = r.lead_k
	pl.choice = r.choice
	pl.pace = r.pace
	return _tail(pl)


## Solved first; the old planner only when nothing is clean (under 1%), else null.
## Why: docs/why/ShipFlight.md#flight-choice
func make_plan(i: int, t: float, prefer: Dictionary = {}, ahead := 0.0) -> FlightPlan:
	var dep := _dep_of(t, ahead)
	if dep.is_empty() or not SystemLayout.is_place(i):
		return _fallback(i, t, prefer)
	if StringName(dep.kind) == &"free":
		ahead = 0.0
	var pf := prefer if int(prefer.get("v", -1)) == FlightSolve.CHOICE_V else {}
	var o := flight_opts()
	var tg := _tgt_of(i)
	var r := FlightSolve.solve(_grav_at(float(o.pace)), dep, tg, t + ahead, pf, o)
	if not r.found and tg.has("side"):
		r = ArriveSide.unsided_solve(_grav_at(float(o.pace)), dep, tg, t + ahead, pf, o)
	last_ms = float(r.usec) / 1000.0
	last_bg = false
	if r.found:
		n_solved += 1
		return _plan_of(r, i, dep, t + ahead)
	# (today's planner, from the ship as it will be then, as the worker plans it;
	# in a twin only its near hop, `_twin_near`)
	var op := _snapshot(t, t + ahead)._old_ahead(i, t + ahead, prefer if not prefer.has("v") else {}, dep, ahead > 0.0, L.twin) as FlightPlan
	if op == null:
		n_none += 1
		return null
	n_fallback += 1
	return op


## Never used in a twin: its star-A-only conics ran up to 1.15 s on this thread for
## flights later thrown out for crossing star B.
## Why: docs/why/ShipFlight.md#old-planner
func _fallback(i: int, t: float, prefer: Dictionary) -> FlightPlan:
	if not SystemLayout.is_place(i):
		return null
	if L.twin:
		n_none += 1
		return null
	var pl := _old_plan(i, t, prefer if not prefer.has("v") else {})
	if pl == null:
		n_none += 1
		return null
	n_fallback += 1
	pl.to = i
	pl.t_plan = t
	return pl


## A plan is flown only if the ship is still where it was planned from, else it is planned again.
## Why: docs/why/ShipFlight.md#plan-reuse
func _takeable(pl: FlightPlan, t: float) -> Dictionary:
	if pl == null:
		return {}
	if pl.res == null and not pl.ahead:
		return {"T": maxf(pl.t0 - t, 0.0), "k": pl.lead_k} if absf(t - pl.t_plan) < 1e-9 else {}
	var a_dep := pl.res.a_dep if pl.res != null else pl.a_dep
	var d := pl.dep
	var lead := pl.t0 - t
	if lead < -1e-9:
		return {}
	lead = maxf(lead, 0.0)
	match StringName(d.get("kind", &"")):
		&"ring":
			var p := int(d.place)
			var a := 0.0
			var w := float(d.w)
			var rt := float(d.rt)
			if p == -9:
				# Round a turning sun the centre is compared by sun id, as it is elsewhere every
				# frame and the preview was otherwise thrown out and planned again each frame.
				# Why: docs/why/ShipFlight.md#plan-reuse
				var same_c: bool = (f.cen_id == int(d.host)) if d.has("host") else (f.cen == (d.c as Vector2))
				if mode != &"free" or not star_orbiting() or not same_c or f.orbit_r != rt or not _pend_free_ok(w):
					return {}
				var q := f.p - f.cen
				a = atan2(q.y, q.x)
			else:
				if mode != &"rail" or rail.is_empty() or inserting() or (rail.has("phase") and not rail.phase.get("wait", false)) or int(rail.body) != p or float(rail.rt) != rt:
					return {}
				if float(rail.dir) * float(rail.speed) / float(rail.rt) != w:
					return {}
				a = float(rail.ang)
			var dr := 1.0 if w >= 0.0 else -1.0
			var dang := fposmod(dr * (a_dep - a), TAU)
			# A ride from a moment before can exceed a lap;
			# read as the near end it was a lap short.
			var want := fposmod(dr * (a_dep - float(d.ang)), TAU) + absf(w) * (pl.t_plan - t)
			dang += TAU * roundf((want - dang) / TAU)
			if absf(dang - want) > 0.05:
				return {}
			# (a fast flight's ride spins up to `ke` times the ring's rate,
			# `_ride_shape`)
			var ke := _ride_ke(pl)
			var rd := {"T": lead, "k": 1.0, "a0": a, "w": w, "ke": 1.0, "ls": 0.0, "sp": 0.0}
			if lead < 1e-6:
				if absf(dang) > 1e-4 or ke > 1.0 + 1e-6:
					return {}
			else:
				if dang < 0.0:
					return {}
				rd.merge(_ride_shape(dang, absf(w), lead, ke), true)
				if not _ride_flyable(rd, pl.pace, absf(w) * rt):
					return {}
			return rd
		&"keep":
			if mode != &"keep" or keep.is_empty() or inserting() or (keep.has("hold") and not keep.get("wait", false)) or int(keep.body) != int(d.place):
				return {}
			if keep.get("inf", keep.off) != d.off:
				return {}
			return {"T": lead, "k": 1.0}
		&"free":
			if absf(t - pl.t_plan) > 1e-9 or f.p != (d.p as Vector2) or f.v != (d.v as Vector2):
				return {}
			return {"T": 0.0, "k": 1.0}
	return {}


## (a settled star orbit is ridden at its pace the way the ship goes round)
func _pend_free_ok(w: float) -> bool:
	return absf(f.sense * star_pace(f.orbit_r, f.cen_share) / f.orbit_r - w) < 1e-9


## How a plan is flown by its ride: round a ring, alongside, round a star orbit, or at once.
func _fly_plan(pl: FlightPlan, rd: Dictionary, t: float, done: Callable) -> void:
	_pend = {}
	fly_to = pl.to
	_fly_done = done
	line = {}
	hold_line = {}
	var T := float(rd.get("T", 0.0))
	if pl.res == null and not pl.ahead:
		# TODAY'S PLANNER'S, as it flew: out of an orbit round it first
		plan = pl
		if pl.lead > 0.0 and mode == &"rail" and not rail.is_empty():
			rail.phase = {"t0": t, "T": pl.lead, "k": pl.lead_k, "a0": float(rail.ang),
				"w": float(rail.dir) * float(rail.speed) / float(rail.rt)}
			return
		_begin_fly(t)
		return
	match StringName(pl.dep.get("kind", &"")):
		&"ring":
			if int(pl.dep.place) == -9:
				plan = _with_ride(pl, rd, t)
				_begin_fly(t)
				return
			plan = pl
			if T > 1e-6:
				rail.phase = {"t0": t, "T": T, "k": float(rd.k), "a0": float(rd.a0), "w": float(rd.w), "ke": float(rd.get("ke", 1.0)),
					"ls": float(rd.get("ls", 0.0)), "sp": float(rd.get("sp", 0.0))}
				return
			_begin_fly(t)
		&"keep":
			plan = pl
			keep.erase("wait")
			if T > 1e-6:
				keep.hold = pl.t0
				if pl.res != null:
					var c := pl.res.choice
					keep.hold_dir = Vector2(float(c.get("dvx", 0.0)), float(c.get("dvz", 0.0)))
				elif pl.samp.size() > 24:
					keep.hold_dir = _flat(pl.samp[24] - pl.samp[0])
				return
			_begin_fly(t)
		_:
			plan = pl
			_begin_fly(t)


## Ride samples sit on the flight's own time grid, so the flight itself is not resampled.
## Why: docs/why/ShipFlight.md#star-orbit-ride
func _with_ride(pl: FlightPlan, rd: Dictionary, t: float) -> FlightPlan:
	var T := float(rd.T)
	# (the flight's own sample spacing on the map: SAMPLE / pace)
	var sd := pl.sdt
	var n := ceili(T / sd - 1e-9)
	if n <= 0:
		return pl
	var out := FlightPlan.new()
	out.conic = false
	out.kind = pl.kind
	out.res = pl.res
	out.to = pl.to
	out.dep = pl.dep
	out.t_plan = pl.t_plan
	out.sdt = pl.sdt
	out.end = pl.end
	out.choice = pl.choice
	out.tail = pl.tail
	out.tail_k = pl.tail_k
	out.tail_lit = pl.tail_lit
	out.ahead = pl.ahead
	out.a_dep = pl.a_dep
	out.lead = 0.0
	out.lead_k = 1.0
	out.pace = pl.pace
	out.t0 = pl.t0 - float(n) * sd
	var c: Vector2 = pl.dep.c
	# Round a turning pair's sun, ride round where that sun is at each sample's moment.
	var hs := int(pl.dep.get("host", -9))
	var carried := SystemLayout.is_star(hs) and L.pair_n != 0.0
	if carried:
		c = f.cen
	var rt := float(pl.dep.rt)
	var w := float(rd.w)
	var a0 := float(rd.a0)
	var r0 := (f.p - c).length()
	var rdt := rd.duplicate()
	rdt.T = T
	var samp := PackedVector3Array()
	var lit := PackedByteArray()
	for j in n:
		# (the first may be up to a sample before now: the ride runs back that far at its pace)
		var tau := out.t0 + float(j) * sd - t
		var a := a0 + w * tau
		var ra := _ride_at(rdt, tau) if tau > 0.0 else PackedFloat64Array([tau, 1.0, 0.0])
		a = a0 + w * ra[0]
		var e := smoothstep(0.0, 1.0, clampf(tau / maxf(T, 0.001), 0.0, 1.0))
		var r := r0 + (rt - r0) * e
		if carried:
			c = L.star_pos(hs, out.t0 + float(j) * sd)
		samp.append(Vector3(c.x + cos(a) * r, 0.0, c.y + sin(a) * r))
		var at := w * ra[2] * rt
		lit.append(1 if absf(at) > 4.0 else 0)
	samp.append_array(pl.samp)
	lit.append_array(pl.burns)
	out.samp = samp
	out.burns = lit
	out.dur = float(samp.size() - 1) * sd
	out.amax = pl.amax
	out.esc_t = pl.esc_t + float(n) * sd
	out.u_dep = float(n) / float(maxi(samp.size() - 1, 1))
	return out


## Samples fly on the map's clock; a plan made now flies from now.
func _begin_fly(t: float) -> void:
	fly_t0 = plan.t0 if (plan.res != null or plan.ahead) else t
	_fly_pos = plan.pos(clampf((t - fly_t0) / plan.dur, 0.0, 1.0))
	mode = &"fly"
	rail = {}
	keep = {}
	line = {}
	hold_line = {}


## A FLIGHT LET GO OF (W off the ring, or out of the hold, or before its plan
## came in): nothing flies, the callback is dropped.
func _cancel_flight() -> void:
	if rail.has("phase"):
		rail.erase("phase")
	if keep.has("hold"):
		keep.erase("hold")
	keep.erase("wait")
	plan = null
	_fly_done = Callable()
	_pend = {}
	if _jobs.has(&"fly"):
		_reap.append(int(_jobs[&"fly"].task))
		_jobs.erase(&"fly")


## The errand goes to the ship that replaces this one when the map is redrawn.
## This ship never calls `done` after.
## Why: docs/why/ShipFlight.md#hand-over
func hand_over() -> Dictionary:
	var to := heading_to()
	if not _fly_done.is_valid() or not SystemLayout.is_place(to):
		return {}
	var d := _fly_done
	_fly_done = Callable()
	var prefer: Dictionary = {}
	if not _pend.is_empty():
		prefer = _pend.get("prefer", {})
	elif plan != null and plan.res != null:
		prefer = plan.choice
	return {"to": to, "done": d, "prefer": prefer}


## (put somewhere by hand: no flight is waiting to leave)
func _drop_flight() -> void:
	plan = null
	_pend = {}
	if _jobs.has(&"fly"):
		_reap.append(int(_jobs[&"fly"].task))
		_jobs.erase(&"fly")


# ---------------------------------------------------------------- planned on a worker
# The ship goes on as before while a flight is planned, then flies it when it comes in.
var _pend: Dictionary = {}
## A started task is always waited for, never by blocking; dropped ones are reaped as they finish.
var _jobs: Dictionary = {}
static var _reap: Array[int] = []
## EVERY TASK STARTED AND NOT YET WAITED FOR, by id, whoever holds it (a ship's
## `_jobs`, `_reap`): what `drain` waits for as the game quits.
static var _out: Dictionary = {}
## (a harness, ThreadStress: this ship's worker plans go straight to today's
## planner, as one the solver found nothing for does)
var old_only := false
## the slowest plan made on a worker (ms, its own time) and how many
var worst_bg_ms := 0.0
var n_bg := 0


## Tasks are reaped as they finish, not waited for:
## waiting held the frame up to about 140 ms in a twin.
## Why: docs/why/ShipFlight.md#freed-mid-plan
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and not _jobs.is_empty():
		for k in _jobs:
			_reap.append(int(_jobs[k].task))
		_jobs.clear()


func _drop_jobs() -> void:
	for k in _jobs:
		_reap.append(int(_jobs[k].task))
	_jobs.clear()
	_pend = {}


## THE TASKS LET GO OF, waited for once they are done (never before): every
## ship's step, and the map's frame with none (`SystemMapScreen._step_ship`).
static func reap() -> void:
	for ri in range(_reap.size() - 1, -1, -1):
		if _done(_reap[ri]):
			_wait(_reap[ri])
			_reap.remove_at(ri)


## Every task is waited for as the game quits: one never waited for kept its lambda past
## GDScript shutdown and crashed the quit (signal 11, exit 134).
## Why: docs/why/ShipFlight.md#quit-crash
static func drain() -> void:
	for task in _out.keys():
		WorkerThreadPool.wait_for_task_completion(int(task))
	_out.clear()
	_reap.clear()


## Whether task `task` is done (or already waited for, `drain`).
static func _done(task: int) -> bool:
	return not _out.has(task) or WorkerThreadPool.is_task_completed(task)


## Task `task` waited for, once: never again after `drain` has.
static func _wait(task: int) -> void:
	if _out.has(task):
		_out.erase(task)
		WorkerThreadPool.wait_for_task_completion(task)


## Whether a plan for `use` is being made.
func planning(use: StringName) -> bool:
	return _jobs.has(use)


## A plan for `use` no longer wanted: let go of (its task reaped when done).
func drop_bg(use: StringName) -> void:
	if _jobs.has(use):
		_reap.append(int(_jobs[use].task))
		_jobs.erase(use)


## Plans are made on a worker; the old planner ran in the taking-in frame for 60 to 275 ms.
## Why: docs/why/ShipFlight.md#planning-on-workers
func plan_bg(i: int, t: float, prefer: Dictionary, use: StringName, lay := 0) -> bool:
	if _jobs.has(use) or not SystemLayout.is_place(i):
		return false
	var ahead := PREVIEW_AHEAD if use == &"preview" else PLAN_AHEAD
	var dep := _dep_of(t, ahead)
	if dep.is_empty():
		return false
	var free := StringName(dep.kind) == &"free"
	var ts := t if free else t + ahead
	var o := flight_opts()
	var G: MapGravity = _grav_at(float(o.pace))
	var held := {}
	var d2 := dep.duplicate(true)
	var t2 := _tgt_of(i).duplicate(true)
	var p2 := prefer.duplicate(true) if int(prefer.get("v", -1)) == FlightSolve.CHOICE_V else {}
	var po := prefer.duplicate(true) if not prefer.has("v") else {}
	var snap = _snapshot(t, ts)
	var near_only := L.twin
	var only_old := old_only
	var task := WorkerThreadPool.add_task(func() -> void:
		var r := FlightSolve.Result.new() if only_old else FlightSolve.solve(G, d2, t2, ts, p2, o)
		if not r.found and not only_old and t2.has("side"):
			r = ArriveSide.unsided_solve(G, d2, t2, ts, p2, o)
		held.r = r
		var pl = null
		if r.found:
			pl = snap._plan_of(r, i, d2, ts)
		else:
			# (in a twin, only today's near hop: `_twin_near`)
			pl = snap._old_ahead(i, ts, po, d2, not free, near_only)
			held.old = true
		# (through the snapshot: a lambda naming this ship's own functions holds
		# the ship, which could then be freed on the worker)
		if pl != null and lay > 0:
			pl.line = snap.lay_out(pl, lay)
		held.plan = pl, false, "sector map flight plan")
	_out[task] = true
	_jobs[use] = {"task": task, "held": held, "i": i, "t": ts, "dep": dep, "prefer": prefer}
	return true


## A copy of the ship at ts for a worker; where a ring rider will be is known.
func _snapshot(t: float, ts: float) -> RefCounted:
	var s = get_script().new()
	s.L = L
	s._stars = _stars
	s._s_pos = _s_pos
	s._s_bump = _s_bump
	s._s_keep = _s_keep
	s._s_ring = _s_ring
	s._s_hold = _s_hold
	s._s_r = _s_r
	s.edge_at = edge_at
	s._grav_v = _grav_v
	s._grav_n = _grav_n
	s.mode = mode
	s.f = f.copy()
	s.rail = rail.duplicate(true)
	s.keep = keep.duplicate(true)
	s.rail.erase("phase")
	for kk in ["hold", "wait", "hold_dir"]:
		s.keep.erase(kk)
	var dt := ts - t
	if mode == &"rail" and not rail.is_empty():
		var b := int(rail.body)
		var rt := float(rail.rt)
		var w := float(rail.dir) * float(rail.speed) / rt
		var a := float(rail.ang) + w * dt
		s.rail.ang = a
		var c := center(b, ts)
		s.f.p = Vector2(c.x + cos(a) * rt, c.z + sin(a) * rt)
		s.f.v = _flat(center_vel(b, ts)) + Vector2(-sin(a), cos(a)) * w * rt
	elif mode == &"keep" and not keep.is_empty():
		var off: Vector2 = keep.get("inf", keep.off)
		s.keep.off = off
		s.keep.inf = off
		s.keep.ev = Vector2.ZERO
		var c2 := center(int(keep.body), ts)
		s.f.p = _flat(c2) + off
		s.f.v = _flat(center_vel(int(keep.body), ts))
	elif star_orbiting():
		# (round its centre as it will be then: a sun of a turning pair carried
		# on dt with the ship round it, its motion on top of the circle's)
		var q := f.p - f.cen
		var w2 := f.sense * star_pace(f.orbit_r, f.cen_share) / f.orbit_r
		var a2 := atan2(q.y, q.x) + w2 * dt
		var c2 := f.cen
		var cv2 := Vector2.ZERO
		if L.twin and SystemLayout.is_star(f.cen_id) and L.pair_n != 0.0:
			c2 = L.star_pos(f.cen_id, ts)
			cv2 = L.star_vel(f.cen_id, ts)
			s.f.cen = c2
		s.f.p = c2 + Vector2(cos(a2), sin(a2)) * f.orbit_r
		s.f.v = star_orbit_v(s.f.p, f.orbit_r, f.sense, c2, f.cen_share) + cv2
	return s


## The old planner's flight made ahead, flown from its own t0 while the ship rides on.
func _old_ahead(i: int, ts: float, prefer: Dictionary, dep: Dictionary, ahead: bool, near_only := false) -> FlightPlan:
	var pl := _twin_near(i, ts, prefer) if near_only else _old_plan(i, ts, prefer)
	if pl == null:
		return null
	pl.to = i
	pl.t_plan = ts
	pl.dep = dep
	pl.ahead = ahead
	if StringName(dep.get("kind", &"")) == &"ring":
		pl.a_dep = float(dep.ang) + float(dep.w) * pl.lead * (1.0 + pl.lead_k) * 0.5
	return pl


## In a twin a ship near a world and not in orbit cannot leave by a solved flight, so use the
## near hop (26 of 32 such FlightTest starts missed in one leg and two).
## Why: docs/why/ShipFlight.md#old-planner
func _twin_near(i: int, t: float, prefer: Dictionary) -> FlightPlan:
	if i < 0 or is_keep(i) or not (prefer.is_empty() or prefer.get("near", false)):
		return null
	var st := _depart_state(t)
	if int(st.body) != -9:
		return null
	var hp := _near_hop(i, t, st, prefer if prefer.get("near", false) else {})
	if hp == null and prefer.get("near", false):
		hp = _near_hop(i, t, st)
	return _tail(hp) if hp != null else null


## Layout is pure arrays so the worker does it; on the map's thread it took 3 to 8 ms a plan.
## Why: docs/why/ShipFlight.md#planning-on-workers
static func lay_out(pl: FlightPlan, n: int) -> Array:
	var dense := PackedVector3Array()
	var lit := PackedByteArray()
	var us := PackedFloat32Array()
	var ns: int = pl.samp.size()
	for j in ns:
		dense.append(pl.samp[j])
		lit.append(1 if pl.burns[j] == 1 else 0)
		us.append(float(j) / float(maxi(ns - 1, 1)))
	var tl := 1 if pl.tail_lit else 0
	for q in pl.tail:
		dense.append(q)
		lit.append(tl)
		us.append(1.0)
	var cum := PackedFloat32Array()
	cum.resize(dense.size())
	var tot := 0.0
	for j in dense.size():
		if j > 0:
			tot += dense[j].distance_to(dense[j - 1])
		cum[j] = tot
	var pts := PackedVector3Array()
	var lits := PackedByteArray()
	var uu := PackedFloat32Array()
	var j2 := 0
	for k in n:
		var dk := tot * float(k) / float(n - 1)
		while j2 < dense.size() - 2 and cum[j2 + 1] < dk:
			j2 += 1
		var seg := maxf(cum[j2 + 1] - cum[j2], 0.0001) if dense.size() > 1 else 1.0
		var fr := clampf((dk - cum[j2]) / seg, 0.0, 1.0)
		pts.append(dense[j2].lerp(dense[mini(j2 + 1, dense.size() - 1)], fr))
		lits.append(lit[j2])
		uu.append(lerpf(us[j2], us[mini(j2 + 1, us.size() - 1)], fr))
	return [pts, lits, uu]


## Takes a finished worker plan for `use`, never waiting for it.
func take_bg(use: StringName, t: float) -> Dictionary:
	if not _jobs.has(use):
		return {}
	var j: Dictionary = _jobs[use]
	if not _done(int(j.task)):
		return {}
	_wait(int(j.task))
	_jobs.erase(use)
	var r: FlightSolve.Result = j.held.get("r")
	var pl: FlightPlan = j.held.get("plan")
	if r != null:
		last_ms = float(r.usec) / 1000.0
		last_bg = true
		n_bg += 1
		worst_bg_ms = maxf(worst_bg_ms, last_ms)
		if r.found:
			n_solved += 1
		elif pl != null:
			n_fallback += 1
		else:
			n_none += 1
	return {"plan": pl, "i": int(j.i), "t": float(j.t)}


## The click flies the drawn preview while its departure is ahead, else a plan from a worker.
## Why: docs/why/ShipFlight.md#click-to-fly
func fly_bg(i: int, t: float, done: Callable, prefer: Dictionary = {}, pv: FlightPlan = null) -> bool:
	if not can_fly() or not SystemLayout.is_place(i):
		return false
	click_replanned = false
	var late: FlightPlan = null
	if pv != null and pv.to == i:
		var rd := _takeable(pv, t)
		if not rd.is_empty():
			# (leaving late: a fresh flight asked for, the drawn one kept to fly if
			# that is no sooner, `CLICK_LATE`)
			if pv.res == null or pv.pace <= 1.0 or float(pv.t0) - t <= CLICK_LATE:
				_fly_plan(pv, rd, t, done)
				return true
			late = pv
	fly_to = i
	_fly_done = done
	line = {}
	hold_line = {}
	if late != null:
		if not plan_bg(i, t, {}, &"fly", LINE_N):
			_fly_plan(late, _takeable(late, t), t, done)
			return true
	elif _jobs.has(&"preview") and int(_jobs[&"preview"].i) == i:
		_jobs[&"fly"] = _jobs[&"preview"]
		_jobs.erase(&"preview")
	elif not plan_bg(i, t, prefer, &"fly", LINE_N):
		# (nothing to plan from: put there, as a plan that finds nothing is)
		_put_there(i, t)
		return true
	_pend = {"i": i, "t": t, "prefer": prefer}
	if late != null:
		_pend["pv"] = late
	# The ship rides on while planned, so the map draws
	# the orbit it leaves and does not reopen the place.
	if mode == &"rail":
		rail.phase = {"t0": t, "T": INF, "k": 1.0, "a0": float(rail.ang),
			"w": float(rail.dir) * float(rail.speed) / float(rail.rt), "wait": true}
	elif mode == &"keep":
		keep.hold = INF
		keep.wait = true
	return true


## Nothing could be planned: the ship is put in orbit there (or alongside), and
## told it has arrived.
func _put_there(i: int, t: float) -> void:
	var d := _fly_done
	place_at(i, t)
	_fly_done = d
	_pend = {}
	_arrived()


## Stale plans (departure passed, ship moved) are asked for again, keeping their choice.
func _poll_jobs(t: float) -> void:
	reap()
	if _pend.is_empty() or not _jobs.has(&"fly"):
		return
	var got := take_bg(&"fly", t)
	if got.is_empty():
		return
	var i := int(_pend.i)
	var pl: FlightPlan = got.plan
	var d := _fly_done
	# THE DRAWN FLIGHT KEPT BESIDE A CLICK'S OWN (`CLICK_LATE`): flown unless the
	# one planned at the click is takeable and arrives sooner
	var pv: FlightPlan = _pend.get("pv")
	if pv != null:
		var rdv := _takeable(pv, t)
		if not rdv.is_empty():
			var rdn := _takeable(pl, t) if pl != null else {}
			if not rdn.is_empty() and _sooner(pl, pv):
				click_replanned = true
				_fly_plan(pl, rdn, t, d)
			else:
				_fly_plan(pv, rdv, t, d)
			return
		_pend.erase("pv")
	if pl == null:
		_put_there(i, t)
		return
	var rd := _takeable(pl, t)
	if rd.is_empty():
		n_stale += 1
		var p0: Dictionary = _pend.prefer
		var tries := int(_pend.get("tries", 0)) + 1
		_pend = {}
		var keep_c := pl.choice if pl.res != null else p0
		# (a fourth stale plan in a row: planned here, on this thread)
		if tries > 3:
			var pl2 := make_plan(i, t, keep_c)
			var rd2 := _takeable(pl2, t)
			if pl2 == null or rd2.is_empty():
				_put_there(i, t)
			else:
				_fly_plan(pl2, rd2, t, d)
			return
		if not plan_bg(i, t, keep_c, &"fly", LINE_N):
			_put_there(i, t)
			return
		_pend = {"i": i, "t": t, "prefer": keep_c, "tries": tries}
		return
	_fly_plan(pl, rd, t, d)


## `t` has no default, so a call from before the pair turned fails rather than settling
## round where a sun was at t 0.
## Why: docs/why/ShipFlight.md#harness-placement
func settle_at(t: float, p: Vector2, sense := 1.0) -> void:
	mode = &"free"
	rail = {}
	keep = {}
	f.p = p
	f.v = Vector2.ZERO
	_settle_centre(f, t)
	if f.r_want > 0.0:
		f.p = f.cen + (p - f.cen).normalized() * f.r_want
	f.orbit_r = (f.p - f.cen).length()
	f.sense = sense
	f.v = star_orbit_v(f.p, f.orbit_r, sense, f.cen, f.cen_share) + _cen_vel(f.cen_id, t)
	# (settled: the next step keeps this centre and does not choose again)
	f.coast = SETTLE_TURN + SETTLE_RAMP + 0.01
	f.head = _scr_ang(f.v)
	ang = f.head


## Put back with only a point, the ship kept the arrival orbit and was pulled onto a circle
## through star A's keep-out, so the saved orbit is restored when the system still has it.
## Why: docs/why/ShipFlight.md#restore-free
func restore_free(t: float, p: Vector2, v: Vector2, head: float, cen_id := -99, r := -1.0, sense := 0.0) -> void:
	_drop_flight()
	mode = &"free"
	rail = {}
	keep = {}
	plan = null
	f = FreeState.new()
	f.p = p
	f.head = head
	ang = head
	fresh = false
	warp_t = -100.0
	var known := cen_id == -1 or (L.twin and (cen_id == SystemLayout.STAR_B or cen_id == -9))
	if r > 0.0 and known:
		f.cen_id = cen_id
		f.cen = L.bary if cen_id == -9 else L.star_pos(cen_id, t)
		f.cen_share = 1.0 if (not L.twin or cen_id == -9) else (L.star_share if cen_id == -1 else 1.0 - L.star_share)
		f.orbit_r = r
		f.sense = sense if sense != 0.0 else 1.0
		var cv := _cen_vel(cen_id, t)
		if cv != Vector2.ZERO and (p - f.cen).length() > 0.001:
			f.p = f.cen + (p - f.cen).normalized() * r
		f.v = star_orbit_v(f.p, f.orbit_r, f.sense, f.cen, f.cen_share) + cv
		# (settled: the next step keeps this centre and does not choose again)
		f.coast = SETTLE_TURN + SETTLE_RAMP + 0.01
	else:
		f.v = v


## TODAY'S PLANNER (before ruling 20): Lambert conics round star A, time-scaled,
## now only the fallback for the flights `FlightSolve` finds nothing clean for.
func _old_plan(i: int, t: float, prefer: Dictionary = {}) -> FlightPlan:
	var st := _depart_state(t)
	# A PLACE ALREADY CLOSE (Jon: the plan took a lap round the star with the
	# world right beside him): a short hop in the world's own frame
	if i >= 0 and int(st.body) == -9 and not is_keep(i) and (prefer.is_empty() or prefer.get("near", false)):
		var hp := _near_hop(i, t, st, prefer if prefer.get("near", false) else {})
		if hp == null and prefer.get("near", false):
			hp = _near_hop(i, t, st)
		if hp != null:
			return _tail(hp)
	# Star orbit to a world by a half-ellipse, so the projected path stops taking weird shapes.
	if i >= 0 and star_orbiting() and not is_keep(i) and (prefer.is_empty() or prefer.get("star_ride", false)):
		var sp := _star_transfer(i, t, st, prefer)
		if sp == null and not prefer.is_empty():
			sp = _star_transfer(i, t, st, {})
		if sp != null:
			return _tail(sp)
	st["esc"] = _escape(i, t, st)
	if (st.esc as Dictionary).is_empty():
		st["esc"] = _turnaround(i, t, st)
	if why and not (st.esc as Dictionary).is_empty():
		var ed: Dictionary = st.esc
		print("  depart: body %d at %s (ang %.2f rt %.1f w %.3f); escape from %s, lead %.2f, td %.2f vs t %.2f" % [int(st.body), (st.p as Vector3).round(), float(st.get("ang", 0.0)), float(st.get("rt", 0.0)), float(st.get("w", 0.0)), (ed.samp[0] if (ed.samp as PackedVector3Array).size() > 0 else Vector3.ZERO).round(), float(ed.get("lead", 0.0)), float(ed.get("td", 0.0)), t])
	# A REPLAN KEEPS TO THE LAST CHOICE while it is still clean, so the drawn
	# plan does not flip between two near-equals
	if not prefer.is_empty():
		_tcap = float(prefer.tcap)
		_high = bool(prefer.high)
		_mid = bool(prefer.get("mid", false))
		var stp := st.duplicate()
		if prefer.get("hohmann", false):
			stp["hohmann"] = true
		if prefer.get("bare", false):
			stp["esc"] = {}
			stp["bare"] = true
		if int(st.body) == -9 and prefer.has("T_coast"):
			stp["T_fix"] = float(prefer.T_coast)
		elif prefer.has("t_end"):
			stp["t_end"] = float(prefer.t_end)
		var side_p := float(prefer.side)
		if prefer.has("abs_side"):
			stp["abs_side"] = true
			side_p = float(prefer.abs_side)
		var pp := _manoeuvre(i, t, stp, float(prefer.kf), side_p, bool(prefer.way))
		_mid = false
		if pp != null and _clean(pp, bool(prefer.strict), stp, i):
			pp.kind = StringName(prefer.kind)
			pp.choice = prefer
			_tcap = 5.0
			_high = false
			_mid = false
			return _tail(pp)
	var fallback: FlightPlan = null
	var fb_score := -INF
	_tcap = 5.0
	# Strictly clean tries first, then merely clear;
	# the star's close orbit tries the half-ellipse first.
	if i < 0:
		var sth := st.duplicate()
		sth["hohmann"] = true
		# No turn toward the star first: the half-ellipse starts along the way the ship goes.
		var bare_h := int(st.body) == -9 and not (st.esc as Dictionary).is_empty() and not (st.esc as Dictionary).has("b")
		if bare_h:
			sth["esc"] = {}
			sth["bare"] = true
		for strict_h: bool in [true, false]:
			for cap_h: float in [5.0, 7.0]:
				_tcap = cap_h
				var hp := _manoeuvre(i, t, sth, 1.0, 1.0, false)
				if hp != null and _clean(hp, strict_h, sth, i):
					hp.kind = &"hohmann"
					hp.choice = {"kf": 1.0, "side": 1.0, "way": false, "strict": strict_h, "tcap": cap_h, "high": false, "kind": "hohmann", "hohmann": true, "bare": bare_h}
					_tcap = 5.0
					return _tail(hp)
		_tcap = 5.0
	# Textbook shape first: a coast leaving along the ship's own way with one burn.
	if int(st.body) == -9 and i >= 0 and not (st.esc as Dictionary).is_empty() and not (st.esc as Dictionary).has("b"):
		var vb := Vector2(float(st.v.x), float(st.v.z))
		var kb := _tangent_kf(st.p, vb, center(i, t + 2.0))
		if why:
			print("  bare tangent coast: %.3f" % kb)
		if kb > 0.0:
			var stb := st.duplicate()
			stb["esc"] = {}
			stb["bare"] = true
			var best_b: FlightPlan = null
			var best_g := -1.0
			for cap_b: float in [5.0, 7.0]:
				_tcap = cap_b
				for way_b: bool in [false, true]:
					_mid = way_b
					for side_b: float in [1.0, -1.0, 0.5, -0.5]:
						var pb := _manoeuvre(i, t, stb, kb, side_b, way_b)
						if pb != null and _clean(pb, true, stb, i) and not _too_wide(pb, i, stb):
							var gb := _grace(pb)
							if gb > best_g:
								best_b = pb
								best_g = gb
								pb.kind = (&"waypoint" if way_b else &"direct") if cap_b <= 5.0 else &"slow"
								pb.choice = {"kf": kb, "side": side_b, "way": way_b, "strict": true, "tcap": cap_b, "high": false, "kind": String(pb.kind), "bare": true, "mid": way_b}
					_mid = false
					if best_b != null:
						break
				if best_b != null:
					break
			_tcap = 5.0
			if best_b != null:
				return _tail(best_b)
	# THE COASTS THAT START THE WAY THE SHIP IS ALREADY GOING, tried first
	var kfs: Array = [0.8, 1.1, 0.6, 1.5, 2.0, 0.45]
	var vs := Vector2(float(st.v.x), float(st.v.z))
	var from_p: Vector3 = st.p
	if not (st.esc as Dictionary).is_empty():
		vs = Vector2((st.esc.v1 as Vector3).x, (st.esc.v1 as Vector3).z)
		from_p = st.esc.p1
	if vs.length() > 12.0:
		var ci := center(i, t + 2.0)
		var cost := {}
		for kf0: float in kfs:
			var g0 := _lam(from_p, ci, 2.0, kf0, false)
			cost[kf0] = absf(vs.angle_to(Vector2((g0.v0 as Vector3).x, (g0.v0 as Vector3).z))) if not g0.is_empty() else PI
		kfs.sort_custom(func(x: float, y: float) -> bool: return float(cost[x]) < float(cost[y]))
		# Coast length is found where its way out crosses the ship's, like a tangent transfer.
		var kt := _tangent_kf(from_p, vs, ci)
		if why:
			print("  tangent coast: %.3f; order %s" % [kt, kfs])
		if kt > 0.0:
			kfs.insert(0, kt)
	# of the clean ones in a pass, the most graceful of the first three
	var keep_best: FlightPlan = null
	var keep_grace := -1.0
	var kept := 0
	for pass_k: Array in [[false, true, 5.0, false, false], [true, true, 5.0, false, true], [true, true, 5.0, false, false], [false, true, 7.0, false, false], [true, true, 7.0, false, true], [true, true, 7.0, false, false], [true, true, 7.0, true, false],
			[false, false, 5.0, false, false], [true, false, 5.0, false, false], [false, false, 7.0, false, false], [true, false, 7.0, false, false], [true, false, 7.0, true, false]]:
		var way: bool = pass_k[0]
		var strict: bool = pass_k[1]
		_tcap = pass_k[2]
		_high = pass_k[3]
		_mid = pass_k[4]
		# A LOOSE PASS takes the gentlest clear plan of all its tries, not the
		# first (the first was once a 3,000 px/s loop)
		var gentle: FlightPlan = null
		var g_score := INF
		if true:
			for side: float in [1.0, -1.0, 0.5, -0.5]:
				for kf: float in kfs:
					var pl := _manoeuvre(i, t, st, kf, side, way)
					if why:
						print("  try way %s strict %s side %d kf %.2f: %s" % [way, strict, side, kf, "null" if pl == null else "built"])
					if pl == null:
						continue
					# Plans swung far out past both ends are not clean while anything plainer is.
					if strict and (not way or _mid) and _too_wide(pl, i, st):
						if why:
							print("  too wide: way %s kf %.2f side %d" % [way, kf, side])
						continue
					if _clean(pl, strict, st, i):
						pl.kind = &"waypoint" if way else &"direct"
						if _tcap > 5.0:
							pl.kind = &"slow"
						pl.choice = {"kf": kf, "side": side, "way": way, "strict": strict, "tcap": _tcap, "high": _high, "kind": String(pl.kind), "mid": _mid}
						if strict:
							var gr := _grace(pl)
							if gr > keep_grace:
								keep_best = pl
								keep_grace = gr
							kept += 1
							if kept >= 3 or gr > 60.0:
								_tcap = 5.0
								_high = false
								_mid = false
								return _tail(keep_best)
							continue
						var hs := _harsh(pl)
						if hs < g_score:
							gentle = pl
							g_score = hs
						continue
					var sc := _clearance(pl, st, i)
					if fallback == null or sc > fb_score:
						fallback = pl
						fb_score = sc
		if keep_best != null:
			_tcap = 5.0
			_high = false
			_mid = false
			return _tail(keep_best)
		if gentle != null:
			_tcap = 5.0
			_high = false
			_mid = false
			return _tail(gentle)
	_tcap = 5.0
	_high = false
	_mid = false
	if fallback != null:
		fallback.kind = &"unclean"
	return _tail(fallback)


## Where the ship starts from: its place and motion, and on an orbit (not one
## it is still burning onto) the orbit.
func _depart_state(t: float) -> Dictionary:
	var st := {"p": where3(), "v": Vector3(f.v.x, 0.0, f.v.y), "body": -9}
	if mode == &"free":
		# just out of a world's ring (on the way from it): its disc is no
		# obstacle for the first moments
		for b in L.bodies:
			if b.world == &"":
				continue
			var cb := center(b.index, t)
			if Vector2(cb.x - st.p.x, cb.z - st.p.z).length() < approach_r(b.index) * 1.2:
				st["left"] = b.index
	if mode == &"rail" and not rail.is_empty() and not inserting():
		st["body"] = int(rail.body)
		st["rt"] = float(rail.rt)
		st["ang"] = float(rail.ang)
		st["w"] = float(rail.dir) * float(rail.speed) / float(rail.rt)
	elif mode == &"keep" and not keep.is_empty():
		st["v"] = center_vel(int(keep.body), t)
	elif mode == &"warp":
		st["v"] = Vector3.ZERO
	return st


## THE ESCAPE out of the orbit the ship is on (once per plan: every try shares
## it), or {} when it is not on one.
func _escape(i: int, t: float, st: Dictionary) -> Dictionary:
	# Escape starts from the best point on the ring, not the ship's spot, so the path does
	# not update every time the ship rotates round the planet.
	# Why: docs/why/ShipFlight.md#escape-point
	if SystemLayout.is_place(int(st.body)):
		var b := int(st.body)
		var rt: float = st.rt
		var w: float = st.w
		var dir := 1.0 if w >= 0.0 else -1.0
		var a_now: float = st.ang
		var ax := 0.0
		if b >= 0:
			var u := _guess_dir(center(b, t), center(i, t + 2.5))
			if i < 0:
				# to the star's close orbit, out along the world's own way round the
				# star: where the half-ellipse in starts
				var cb := center(b, t)
				u = Vector2(-cb.z, cb.x).normalized()
			ax = atan2(u.y, u.x) - dir * PI / 2.0
		else:
			var ci := center(i, t + 2.5)
			ax = atan2(ci.z, ci.x) - dir * 0.6 * PI
		var sweeps: Array = [0.75 * PI, 0.5 * PI, 1.0 * PI, 1.25 * PI, 0.4 * PI, 1.4 * PI]
		# Spiral out to just past the ring; the old size grazed the star from an inner world.
		var rxs: Array = [star_ring(b) + 30.0, star_ring(b) + 8.0, star_ring(b) + 70.0] if b < 0 else [L.bodies[b].soi * 1.2, L.bodies[b].soi * 1.05, L.bodies[b].soi * 1.5]
		var vr := ESC_V * 0.3
		var best := {}
		for rx: float in rxs:
			for sweep: float in sweeps:
				var a0 := ax - dir * sweep
				var dang := fposmod(dir * (a0 - a_now), TAU)
				var lead := _lead(dang, absf(w))
				var td: float = t + float(lead[0])
				var e := _spiral(b, td, a0, rt, w, dir, sweep, rx, vr)
				e["lead"] = lead[0]
				e["lead_k"] = lead[1]
				e["a_dep"] = a0
				if best.is_empty():
					best = e
				if e.clear:
					return e
		return best
	return {}


## Turns round at speed when the coast must leave the wrong way, avoiding a cusp.
func _turnaround(i: int, t: float, st: Dictionary, toward := Vector2.ZERO, pace := 0.0) -> Dictionary:
	var v0: Vector3 = st.v
	var sp := Vector2(v0.x, v0.z).length()
	if sp < 12.0:
		return {}
	var u := toward if toward != Vector2.ZERO else _guess_dir(st.p, center(i, t + 2.0))
	var h0 := atan2(v0.z, v0.x)
	var dh := wrapf(atan2(u.y, u.x) - h0, -PI, PI)
	if absf(dh) < deg_to_rad(35.0):
		return {}
	# it comes out of the turn at the coast's own pace (slower than it went in,
	# when the coast is): the coast then starts with nothing to blend
	var spd := clampf(pace, 50.0, 300.0) if pace > 0.0 else maxf(sp, 50.0)
	var ne := maxi(8, roundi((0.35 + absf(dh) / 2.6) / SAMPLE))
	var te := ne * SAMPLE
	var hq := [h0, 0.0, 0.0, h0 + dh, 0.0, 0.0]
	var sq := [sp, 0.0, 0.0, spd, 0.0, 0.0]
	var samp := PackedVector3Array()
	var p: Vector3 = st.p
	var vprev := Vector3(cos(h0), 0.0, sin(h0)) * sp
	for k in ne + 1:
		var sk := float(k) / float(ne)
		var hh := _q5(hq, sk, 0)
		var vv := Vector3(cos(hh), 0.0, sin(hh)) * _q5(sq, sk, 0)
		if k > 0:
			p += (vv + vprev) * 0.5 * SAMPLE
		vprev = vv
		if k < ne:
			samp.append(p)
		if k % 6 == 0:
			if Vector2(p.x, p.z).length() < keep_clear():
				return {}
			for ob in L.bodies:
				if ob.world == &"":
					continue
				var oc := center(ob.index, t + sk * te)
				if Vector2(p.x - oc.x, p.z - oc.z).length() < ob.r + 8.0:
					return {}
	return {"samp": samp, "p1": p, "v1": vprev, "t1": t + te, "te": te, "td": t, "a1": Vector3.ZERO,
		"lead": 0.0, "lead_k": 1.0, "clear": true}


## Ride to the departure point: up to LEAD_MAX it simply rides, further a burn speeds it round.
static func _lead(dang: float, w: float) -> Array:
	if w <= 0.0001:
		return [0.0, 1.0]
	var natural := dang / w
	if natural <= LEAD_MAX:
		return [natural, 1.0]
	return [LEAD_MAX, 1.0 + 2.0 * (dang / (w * LEAD_MAX) - 1.0)]


## One escape spiral out of the ring round place b from angle a0 at time td.
func _spiral(b: int, td: float, a0: float, rt: float, w: float, dir: float, sweep: float, rx: float, vr: float, v_end := Vector2.INF, a_end := Vector2.ZERO) -> Dictionary:
	var ne := maxi(8, roundi((0.7 + 0.3 * sweep) / SAMPLE))
	var te := ne * SAMPLE
	var ph := [a0, w * te, 0.0, a0 + dir * sweep, dir * ESC_V / rx * te, 0.0]
	var rr := [rt, 0.0, 0.0, rx, vr * te, 0.0]
	if v_end != Vector2.INF:
		# LEAVING WITH THE COAST'S OWN MOTION AND PULL (relative to the place),
		# so the coast starts where the spiral ends with nothing to blend
		var ph1: float = ph[3]
		var er := Vector2(cos(ph1), sin(ph1))
		var ep := Vector2(-er.y, er.x)
		var rd := v_end.dot(er)
		var pd := v_end.dot(ep) / rx
		if pd * dir <= 0.0:
			return {}
		var rdd := a_end.dot(er) + rx * pd * pd
		var pdd := (a_end.dot(ep) - 2.0 * rd * pd) / rx
		ph = [a0, w * te, 0.0, ph1, pd * te, pdd * te * te]
		rr = [rt, 0.0, 0.0, rx, rd * te, rdd * te * te]
		# no turning back round the ring, no dipping in toward the place
		for j in 25:
			var sj := float(j) / 24.0
			if _q5(ph, sj, 1) * dir <= 0.0 or _q5(rr, sj, 0) < rt * 0.9:
				return {}
	var esc := PackedVector3Array()
	var clear := true
	var at := func(sk: float) -> Vector3:
		var c := center(b, td + sk * te)
		var phi := _q5(ph, sk, 0)
		var r := _q5(rr, sk, 0)
		return c + Vector3(cos(phi) * r, 0.0, sin(phi) * r)
	for k in ne + 1:
		var sk := float(k) / float(ne)
		var q: Vector3 = at.call(sk)
		if k < ne:
			esc.append(q)
		if (k % 3 == 0 or k == ne) and clear:
			for ob in L.bodies:
				if ob.world == &"" or ob.index == b:
					continue
				var oc := center(ob.index, td + sk * te)
				if Vector2(q.x - oc.x, q.z - oc.z).length() < ob.r + 8.0:
					clear = false
					break
	var phi1: float = ph[3]
	var c1 := center(b, td + te)
	var p1 := c1 + Vector3(cos(phi1) * rx, 0.0, sin(phi1) * rx)
	var v1 := center_vel(b, td + te) + Vector3(cos(phi1), 0.0, sin(phi1)) * vr + Vector3(-sin(phi1), 0.0, cos(phi1)) * dir * ESC_V
	# its pull at the end (the spiral's own curve there), for the blend onto the coast
	var ds := 1.0 / float(ne)
	var a1: Vector3 = ((at.call(1.0 + ds) as Vector3) - 2.0 * p1 + (at.call(1.0 - ds) as Vector3)) / pow(ds * te, 2.0)
	a1.y = 0.0
	if v_end != Vector2.INF:
		v1 = center_vel(b, td + te) + Vector3(v_end.x, 0.0, v_end.y)
	return {"samp": esc, "p1": p1, "v1": v1, "t1": td + te, "te": te, "td": td, "a1": a1, "clear": clear,
		"b": b, "ang0": a0, "rt": rt, "w": w, "dir": dir, "sweep": sweep, "rx": rx, "vr": vr}


## One way to fly it, or null.
func _manoeuvre(i: int, t: float, st: Dictionary, kf: float, side: float, way: bool) -> FlightPlan:
	var pl := FlightPlan.new()
	pl.t0 = t
	pl.sdt = SAMPLE
	var p1: Vector3 = st.p
	var v1: Vector3 = st.v
	var t1 := t
	if st.has("esc") and not (st.esc as Dictionary).is_empty():
		var e: Dictionary = st.esc
		pl.t0 = e.td
		pl.lead = e.lead
		pl.lead_k = e.lead_k
		pl.samp.append_array(e.samp)
		for _k in (e.samp as PackedVector3Array).size():
			pl.burns.append(1)
		p1 = e.p1
		v1 = e.v1
		t1 = e.t1
		pl.esc_t = e.te
	# Coast stretched to 5 s at most until under about
	# 950 px/s and 4,000 px/s², not cheating the shape.
	var cg := center(i, t1 + 2.0)
	var dth := _pro_angle(p1, cg)
	var dist := Vector2(cg.x - p1.x, cg.z - p1.z).length()
	var T := clampf(1.3 + 0.9 * dth / PI + 0.9 * clampf((dist - 200.0) / 1200.0, 0.0, 1.0), 1.3, 3.2)
	# A replan arrives when the last did, so its shape holds; a fresh length slid the arrival.
	var fixed_t: float = float(st.get("t_end", -1.0))
	if st.has("T_fix"):
		fixed_t = t1 + float(st.T_fix)
	if fixed_t > 0.0:
		T = maxf(fixed_t - t1, 0.8)
	var side_used := side
	var keepd := is_keep(i)
	var legs: Array = []
	var n2 := 0
	var t2 := t1
	var ct := Vector3.ZERO
	var cvt := Vector3.ZERO
	var arel := Vector2.ZERO
	var pa := Vector3.ZERO
	for _it in 4:
		n2 = roundi(T / SAMPLE)
		var tt := n2 * SAMPLE
		t2 = t1 + tt
		ct = center(i, t2)
		cvt = center_vel(i, t2)
		# THE APPROACH: on the side it comes in from, a little round, so it meets
		# the ring along it
		var din := _guess_dir(p1, ct)
		var g := _lam(p1, ct, tt, kf, false)
		# Take the side that keeps the coast's own turn going, so the insertion does not
		# overshoot and hook back the other way.
		# Why: docs/why/ShipFlight.md#approach-side
		var side_eff := side
		if not g.is_empty():
			var gv: Vector3 = (g.v2 as Vector3) - cvt
			if Vector2(gv.x, gv.z).length() > 0.01:
				din = Vector2(gv.x, gv.z).normalized()
			if i >= 0 and not keepd:
				var ga: Vector3 = (g.a2 as Vector3) - center_acc(i, t2)
				var gv2 := Vector2(gv.x, gv.z)
				var cr := gv2.cross(Vector2(ga.x, ga.z))
				var ra_i: float = approach_r(i)
				if gv2.length() > 1.0 and absf(cr) / pow(gv2.length(), 3.0) * ra_i > 0.005 and not st.has("abs_side"):
					side_eff = side * -signf(cr)
		# Come in tangent to the orbit to be joined, so the insertion is an inward spiral.
		var aa0 := atan2(p1.z, p1.x) + clampf(dth, 0.5, 5.5) * 0.85
		arel = _approach(i, din, side_eff, keepd, aa0, ct)
		pa = ct + Vector3(arel.x, 0.0, arel.y)
		# TO THE STAR'S CLOSE ORBIT, THE TEXTBOOK WAY: a half-ellipse from here,
		# tangent at both ends, round the way the ship already goes
		if st.get("hohmann", false) and (i < 0 or st.has("hohmann_r")):
			var vh := Vector2(v1.x, v1.z)
			var sn := 1.0
			if vh.length() > 12.0:
				sn = signf(p1.x * vh.y - p1.z * vh.x)
			# to the star's close orbit, or (out of the star orbit) to the near
			# side of a world's ring, where the world will be half a lap on
			var ho := _hohmann(p1, sn, float(st.get("hohmann_r", star_ring() + 12.0)), tt)
			if ho.is_empty():
				return null
			legs = [[ho, n2]]
			pa = ho.end
			arel = Vector2(pa.x - ct.x, pa.z - ct.z)
			var vmh := float(ho.vmax)
			var gmh := float(ho.gmax)
			var dinh := (v1 - (ho.v0 as Vector3)).length()
			var douth := (ho.v2 as Vector3).length()
			var lneed := maxf(maxf(vmh / 950.0, sqrt(gmh / 4000.0)), 4.0 * maxf(dinh, douth) / (minf(0.8, 0.4 * T) * 4500.0))
			if lneed <= 1.0 or T >= _tcap or fixed_t > 0.0:
				break
			T = minf(_tcap, T * lneed * 1.05)
			continue
		# THE COAST: direct (not when it is most of a lap, where the arc is
		# degenerate), or round a waypoint outside both ends with a burn there
		legs = []
		# a place nearly in line with the ship has no arc to it that short: it is
		# a swing round the star, two half-orbits through a waypoint opposite
		var pro := _pro_angle(p1, pa)
		if why:
			print("    p1 r %.0f, target r %.0f, prograde angle %.2f, way %s" % [Vector2(p1.x, p1.z).length(), Vector2(pa.x, pa.z).length(), pro, way])
		if pro < 0.6:
			if not way:
				return null
			pro += TAU
		if way:
			# split so neither leg is the half lap no arc can fly, nor most of one
			var fs := 0.5
			for fk: float in [0.42, 0.5, 0.35, 0.58, 0.65, 0.28]:
				var l1 := pro * fk
				var l2 := pro - l1
				if absf(sin(l1)) >= 0.15 and absf(sin(l2)) >= 0.15 and l1 <= 1.45 * PI and l2 <= 1.45 * PI:
					fs = fk
					break
			var am := atan2(p1.z, p1.x) + pro * fs
			var rw := maxf(maxf(Vector2(p1.x, p1.z).length(), Vector2(pa.x, pa.z).length()), keep_clear() * 2.2) * 1.15 + 30.0
			if _mid:
				# between the two radii, as far in (or out) as it is round: one spiral
				var ra1 := Vector2(p1.x, p1.z).length()
				var ra2 := Vector2(pa.x, pa.z).length()
				if absf(ra1 - ra2) < 0.2 * maxf(ra1, ra2):
					return null
				rw = maxf(lerpf(ra1, ra2, fs), keep_clear() * 2.2)
			if _high:
				rw = maxf(rw, L.edge * 0.85)
			var pw := Vector3(cos(am) * rw, 0.0, sin(am) * rw)
			var nh := roundi(n2 * fs)
			var kf1 := kf
			if _mid and st.get("bare", false):
				# leaving along the way the ship goes: the first half-orbit tangent
				# where it starts
				kf1 = _tangent_kf(p1, Vector2(v1.x, v1.z), pw)
				if kf1 <= 0.0:
					return null
			var la := _lam(p1, pw, nh * SAMPLE, kf1)
			var lb := _lam(pw, pa, (n2 - nh) * SAMPLE, kf)
			if la.is_empty() or lb.is_empty():
				return null
			la["to"] = pw
			legs = [[la, nh], [lb, n2 - nh]]
		else:
			if pro > 1.45 * PI:
				return null
			var ld := _lam(p1, pa, tt, kf)
			if ld.is_empty():
				return null
			legs = [[ld, n2]]
		# THE APPROACH REFINED from the coast's real arrival: once, so it really
		# comes in along the ring
		if absf(side) == 1.0 and not keepd:
			var rv2: Vector3 = (legs[-1][0].v2 as Vector3) - cvt
			var din2 := Vector2(rv2.x, rv2.z)
			# and the side again from the coast as built (round a waypoint its last
			# leg bends its own way, not the probe's)
			var side2 := side_eff
			var ra2: Vector3 = (legs[-1][0].a2 as Vector3) - center_acc(i, t2)
			var cr2 := din2.cross(Vector2(ra2.x, ra2.z))
			if i >= 0 and din2.length() > 1.0 and absf(cr2) / pow(din2.length(), 3.0) * float(L.bodies[i].soi) * 0.95 > 0.005 and not st.has("abs_side"):
				side2 = side * -signf(cr2)
			if din2.length() > 1.0 and (absf(din2.angle_to(din)) > deg_to_rad(4.0) or side2 != side_eff):
				side_eff = side2
				var arel2 := _approach(i, din2.normalized(), side_eff, keepd, aa0, ct)
				var pa2 := ct + Vector3(arel2.x, 0.0, arel2.y)
				var legs2: Array = []
				if way:
					var lb2 := _lam(_waypoint_of(legs), pa2, int(legs[-1][1]) * SAMPLE, kf)
					if not lb2.is_empty():
						legs2 = [legs[0], [lb2, legs[-1][1]]]
				else:
					var ld2 := _lam(p1, pa2, tt, kf)
					if not ld2.is_empty():
						legs2 = [[ld2, n2]]
				if not legs2.is_empty():
					legs = legs2
					arel = arel2
					pa = pa2
		side_used = side_eff
		# how fast and how hard the coast is, as it would be shown
		var vmax := 0.0
		var gmax := 0.0
		for lg2: Array in legs:
			vmax = maxf(vmax, float(lg2[0].vmax))
			gmax = maxf(gmax, float(lg2[0].gmax))
		# and the burns at its ends: a burn's pull is 4 times its change over its
		# length, which is at most 0.8 s and 40% of the shortest leg
		var lmin := T
		for lg3: Array in legs:
			lmin = minf(lmin, int(lg3[1]) * SAMPLE)
		var d_in := (v1 - (legs[0][0].v0 as Vector3)).length()
		var d_out := ((legs[-1][0].v2 as Vector3) - cvt).length()
		var bneed := 4.0 * maxf(d_in, d_out) / (minf(0.8, 0.4 * lmin) * 4500.0)
		var need := maxf(maxf(vmax / 950.0, sqrt(gmax / 4000.0)), bneed)
		if need <= 1.0 or T >= _tcap or fixed_t > 0.0:
			break
		T = minf(_tcap, T * need * 1.05)
	# The spiral is rebuilt to end as the coast starts, so no burn blends them and no hook shows.
	if st.has("esc") and not (st.esc as Dictionary).is_empty() and (st.esc as Dictionary).has("b") and not st.has("matched"):
		var e5: Dictionary = st.esc
		var b5: int = e5.b
		var vrel: Vector3 = (legs[0][0].v0 as Vector3) - center_vel(b5, t1)
		var arel5: Vector3 = (legs[0][0].a0 as Vector3) - center_acc(b5, t1)
		var m5 := _spiral(b5, float(e5.td), float(e5.ang0), float(e5.rt), float(e5.w), float(e5.dir), float(e5.sweep), float(e5.rx), float(e5.vr),
			Vector2(vrel.x, vrel.z), Vector2(arel5.x, arel5.z))
		if not m5.is_empty() and m5.clear:
			m5["lead"] = e5.lead
			m5["lead_k"] = e5.lead_k
			m5["a1"] = legs[0][0].a0
			var st5 := st.duplicate()
			st5["esc"] = m5
			st5["matched"] = true
			return _manoeuvre(i, t, st5, kf, side, way)
	# Turn toward the coast's way out first; braking through nought and reversing is a cusp.
	var lv0: Vector3 = legs[0][0].v0
	# (after an escape too: its way out and the coast's can differ)
	if not st.has("turned") and Vector2(v1.x, v1.z).length() > 12.0 and Vector2(lv0.x, lv0.z).length() > 1.0:
		var gap := absf(Vector2(v1.x, v1.z).angle_to(Vector2(lv0.x, lv0.z)))
		if gap > deg_to_rad(35.0):
			var st2 := st.duplicate()
			st2["turned"] = true
			var from := st.duplicate()
			if st.has("esc") and not (st.esc as Dictionary).is_empty():
				from["v"] = v1
				from["p"] = p1
			var tr := _turnaround(i, t1, from, Vector2(lv0.x, lv0.z).normalized(), Vector2(lv0.x, lv0.z).length())
			if not tr.is_empty():
				if st.has("esc") and not (st.esc as Dictionary).is_empty():
					var e0: Dictionary = st.esc
					var both := PackedVector3Array(e0.samp)
					both.append_array(tr.samp)
					tr["samp"] = both
					tr["td"] = e0.td
					tr["te"] = float(e0.te) + float(tr.te)
					# and the ride round to where the escape starts (lost here, the
					# flight began at the departure point with no ride: a jump)
					tr["lead"] = e0.get("lead", 0.0)
					tr["lead_k"] = e0.get("lead_k", 1.0)
				st2["esc"] = tr
				return _manoeuvre(i, t, st2, kf, side, way)
	for lg4: Array in legs:
		_sample(lg4[0])
	var rin := (legs[-1][0].v2 as Vector3) - cvt
	var vend := cvt + (rin.normalized() * APP_V if rin.length() > 0.01 else Vector3.ZERO)
	var v_in := v1
	var a_in := Vector3.ZERO
	if st.has("esc") and not (st.esc as Dictionary).is_empty():
		a_in = st.esc.a1
	var t_leg := t1
	var t_more := 0.0
	var k_arr := 1.0
	for li in legs.size():
		var lg: Dictionary = legs[li][0]
		var n: int = legs[li][1]
		var T2 := n * SAMPLE
		var v_out: Vector3 = vend
		# the pull it ends with: the conic's own into the insertion (which starts
		# with it), the two legs' average at a waypoint
		var a_out: Vector3 = (lg.a2 as Vector3).limit_length(A_INS)
		if li < legs.size() - 1:
			v_out = ((lg.v2 as Vector3) + (legs[li + 1][0].v0 as Vector3)) * 0.5
			a_out = ((lg.a2 as Vector3) + (legs[li + 1][0].a0 as Vector3)) * 0.5
		var d1 := v_in - (lg.v0 as Vector3)
		var d2 := v_out - (lg.v2 as Vector3)
		# the pulls matched only so far: close to the star a coast's pull is huge,
		# and blending all of it away would bulge the path more than a small kink
		var e1 := (a_in - (lg.a0 as Vector3)).limit_length(A_BLEND)
		var e2 := (a_out - (lg.a2 as Vector3)).limit_length(A_BLEND)
		a_out = (lg.a2 as Vector3) + e2
		# Burns are longer and gentler, so there are fewer, softer bends.
		var tb1 := minf(clampf(d1.length() / 350.0, 0.45, 1.3), 0.45 * T2)
		var tb2 := minf(clampf(d2.length() / 350.0, 0.45, 1.3), 0.45 * T2)
		# a burn only where there is one to speak of
		var real1 := d1.length() > 15.0 or e1.length() > 400.0
		var real2 := d2.length() > 15.0 or e2.length() > 400.0
		var pts: PackedVector3Array = lg.pts
		# The arrival burn replays the coast's last stretch
		# slower, keeping its bend, as a blend drew a hook.
		var rv2: Vector3 = (lg.v2 as Vector3) - center_vel(i, t_leg + T2)
		var warp := li == legs.size() - 1 and not keepd and Vector2(rv2.x, rv2.z).length() > APP_V * 1.2
		var nb := 0
		if warp:
			nb = mini(roundi(tb2 / SAMPLE), n - roundi(tb1 / SAMPLE) - 2)
			warp = nb >= 8
		for k in range(0, n - nb + (1 if li == legs.size() - 1 and not warp else 0)):
			var tau := k * SAMPLE
			var sg := T2 - tau
			var q := pts[k]
			var lit := false
			if tau < tb1:
				var x := tau / tb1
				q += d1 * tb1 * _h1(x) + e1 * tb1 * tb1 * _h2(x)
				lit = real1
			if sg < tb2 and not warp:
				var y := sg / tb2
				q += -d2 * tb2 * _h1(y) + e2 * tb2 * tb2 * _h2(y)
				lit = lit or real2
			pl.samp.append(q)
			pl.burns.append(1 if lit else 0)
		if warp:
			var tbw := nb * SAMPLE
			var kq := clampf(APP_V / rv2.length(), 0.05, 1.0)
			var nd := maxi(nb + 1, floori(2.0 * tbw / (1.0 + kq) / SAMPLE))
			var dw := nd * SAMPLE
			kq = clampf(2.0 * tbw / dw - 1.0, 0.0, 1.0)
			var m0 := dw / tbw
			var m1 := kq * dw / tbw
			var s0 := T2 - tbw
			var tw0 := t_leg + s0
			for j in nd + 1:
				var u := float(j) / float(nd)
				var sw := s0 + tbw * (m0 * u + (m1 - m0) * (u * u * u - u * u * u * u * 0.5))
				var xk := clampf(sw / SAMPLE, 0.0, float(n))
				var k0 := mini(int(floor(xk)), n - 1)
				var fr := xk - k0
				var qa := pts[maxi(k0 - 1, 0)]
				var qb := pts[k0]
				var qc := pts[k0 + 1]
				# (past the end, carried on at its own curve, not stopped dead)
				var qd := pts[k0 + 2] if k0 + 2 <= n else 3.0 * pts[n] - 3.0 * pts[n - 1] + pts[n - 2]
				var qs := 0.5 * ((2.0 * qb) + (-qa + qc) * fr + (2.0 * qa - 5.0 * qb + 4.0 * qc - qd) * fr * fr + (-qa + 3.0 * qb - 3.0 * qc + qd) * fr * fr * fr)
				var q := center(i, tw0 + j * SAMPLE) + (qs - center(i, t_leg + sw))
				if j == nd:
					q = center(i, tw0 + dw) + (pts[n] - center(i, t_leg + T2))
				pl.samp.append(q)
				pl.burns.append(1 if kq < 0.9 else 0)
			t_more = dw - tbw
			k_arr = kq
		v_in = v_out
		a_in = a_out
		t_leg += T2
	pl.dur = (pl.samp.size() - 1) * SAMPLE
	if t_more > 0.0:
		t2 += t_more
		ct = center(i, t2)
		cvt = center_vel(i, t2)
		pa = ct + Vector3(arel.x, 0.0, arel.y)
		vend = cvt + rin * k_arr
		rin = rin * k_arr
	# its hardest burn, for the flame
	var amax := 1.0
	for k in range(1, pl.samp.size() - 1, 2):
		amax = maxf(amax, (pl.samp[k + 1] - 2.0 * pl.samp[k] + pl.samp[k - 1]).length() / (SAMPLE * SAMPLE))
	pl.amax = amax
	var aend := ((legs[-1][0].a2 as Vector3) + ((legs[-1][0].a2 as Vector3).limit_length(A_INS) - (legs[-1][0].a2 as Vector3)).limit_length(A_BLEND) - center_acc(i, t2)).limit_length(A_INS)

	if t_more > 0.0:
		var a2r: Vector3 = (legs[-1][0].a2 as Vector3) - center_acc(i, t2 - t_more)
		aend = (a2r * k_arr * k_arr).limit_length(A_INS)
	pl.end = {"body": i, "p": pa, "v": vend, "keep": keepd, "t": t2, "a": Vector2(aend.x, aend.z)}
	pl.end["arel"] = arel
	pl.end["side_abs"] = side_used
	# when the coast itself ends (the arrival burn's slowing comes after): what a
	# replan keeps to
	pl.end["t_coast"] = t2 - t_more
	pl.end["t1"] = t1
	pl.end["rv"] = Vector2(vend.x - cvt.x, vend.z - cvt.z)
	return pl


## Where the coast meets the place: along a ring, at a slant, or a station's spot.
func _approach(i: int, din: Vector2, side: float, keepd: bool, aa0: float, ct: Vector3) -> Vector2:
	if keepd:
		return Vector2(8.0, 5.0 / TILT) - din * APP_V * 0.35
	var ra: float = approach_r(i)
	var perp := Vector2(-din.y, din.x)
	var arel: Vector2
	if absf(side) == 1.0:
		# tangent: the ring's own point where its way round is the way it comes in
		arel = perp * signf(side) * ra
	else:
		arel = (-din * cos(1.0) + perp * signf(side) * sin(1.0)) * ra
	if i < 0 and absf(side) != 1.0:
		arel = Vector2(cos(aa0 + side * 0.36), sin(aa0 + side * 0.36)) * ra
	# an inner world's star side is the star's: come in on its outside instead
	if i >= 0:
		var rh := Vector2(ct.x, ct.z).normalized()
		var pa := Vector2(ct.x, ct.z) + arel
		if pa.length() < keep_clear() + 24.0:
			arel -= rh * 2.0 * minf(0.0, arel.dot(rh))
	return arel


## Coast length whose way out from p points along `v`: scanned 0.25 to 3, first crossing bisected.
func _tangent_kf(p: Vector3, v: Vector2, c: Vector3) -> float:
	var ks: Array = []
	for j in 15:
		ks.append(0.25 * pow(12.0, float(j) / 14.0))
	if why:
		var dbg := []
		for k0: float in ks:
			var g0 := _lam(p, c, 2.0, k0, false)
			dbg.append("%.2f:%s" % [k0, "x" if g0.is_empty() else "%.0f" % rad_to_deg(v.angle_to(Vector2((g0.v0 as Vector3).x, (g0.v0 as Vector3).z)))])
		print("    tangent scan from r %.0f to r %.0f, angle %.2f: %s" % [Vector2(p.x, p.z).length(), Vector2(c.x, c.z).length(), _pro_angle(p, c), " ".join(dbg)])
	var prev_k := -1.0
	var prev_a := 0.0
	var best_k := -1.0
	var best_a := INF
	for k: float in ks:
		var g := _lam(p, c, 2.0, k, false)
		if g.is_empty():
			prev_k = -1.0
			continue
		var a := v.angle_to(Vector2((g.v0 as Vector3).x, (g.v0 as Vector3).z))
		if prev_k > 0.0 and signf(a) != signf(prev_a) and absf(a) < 1.0 and absf(prev_a) < 1.0:
			var lo := prev_k
			var hi := k
			var alo := prev_a
			for _b in 10:
				var mid := (lo + hi) * 0.5
				var gm := _lam(p, c, 2.0, mid, false)
				if gm.is_empty():
					break
				var am := v.angle_to(Vector2((gm.v0 as Vector3).x, (gm.v0 as Vector3).z))
				if signf(am) == signf(alo):
					lo = mid
					alo = am
				else:
					hi = mid
			return (lo + hi) * 0.5
		prev_k = k
		prev_a = a
		if absf(a) < best_a:
			best_a = absf(a)
			best_k = k
	# no crossing: the nearest, if it is near (a coast that leaves within a few
	# degrees of the way the ship goes)
	return best_k if best_a < 0.1 else -1.0


## Star orbit to the star's close orbit is a Hohmann half-ellipse, tangent at both ends
## with one burn each.
## Why: docs/why/ShipFlight.md#hohmann-transfer
func _hohmann(p: Vector3, sense: float, ra: float, T: float) -> Dictionary:
	var f1 := Vector3(p.x, 0.0, p.z)
	var r1 := f1.length()
	if r1 < 1.0 or absf(r1 - ra) < 1.0:
		return {}
	var a := (r1 + ra) * 0.5
	var tof := PI * sqrt(a * a * a)
	var vt := sqrt(maxf(2.0 / r1 - 1.0 / a, 0.0))
	var v0 := Vector3(-f1.z, 0.0, f1.x) / r1 * vt * sense
	var m := 160
	var pv := _coast_pv(f1, v0, tof, m)
	var nodes: PackedVector3Array = pv[0]
	var vels: PackedVector3Array = pv[1]
	var f2 := -f1 / r1 * ra
	var err := nodes[m] - f2
	var kk := tof / T
	var vmax := 0.0
	var gmax := 0.0
	for j in m + 1:
		vmax = maxf(vmax, vels[j].length() * kk)
		gmax = maxf(gmax, _acc(nodes[j]).length() * kk * kk)
	return {"nodes": nodes, "vels": vels, "err": err, "tof": tof, "T": T,
		"v0": v0 * kk, "v2": vels[m] * kk, "vmax": vmax, "gmax": gmax,
		"a0": _acc(nodes[0]) * kk * kk, "a2": _acc(nodes[m]) * kk * kk, "end": f2}


## The departure is chosen once and kept, so the drawn
## plan holds its shape while the ship rides round.
## Why: docs/why/ShipFlight.md#hohmann-transfer
func _star_transfer(i: int, t: float, st: Dictionary, prefer: Dictionary) -> FlightPlan:
	var p0: Vector3 = st.p
	var r1 := Vector2(p0.x, p0.z).length()
	if r1 < 1.0:
		return null
	var sense: float = f.sense if absf(f.sense) > 0.5 else 1.0
	var spd := STAR_PACE * TAU * 1000.0 / (800.0 * sqrt(maxf(r1, 20.0)))
	var w := sense * spd / r1
	var a_now := atan2(p0.z, p0.x)
	var r2 := Vector2(center(i, t).x, center(i, t).z).length()
	var a_dep := 0.0
	var lt := 0.0
	var kq := 1.0
	# Ride and phasing burn for `dang`: never past 600 px/s or 5 s, so it may leave a little early.
	var aw := absf(w)
	var ride_for := func(dang: float) -> Array:
		if dang <= aw * LEAD_MAX:
			return [dang / aw, 1.0]
		var k0 := maxf(minf(2.0 * dang / (aw * LEAD_MAX) - 1.0, 600.0 / (aw * r1)), 1.0)
		return [minf(2.0 * dang / (aw * (1.0 + k0)), 5.0), k0]
	if prefer.has("a_dep"):
		# KEPT: the same place to leave from (the ship rides on toward it); once
		# it is passed, from here
		a_dep = float(prefer.a_dep)
		var dk := fposmod(sense * (a_dep - a_now), TAU)
		if dk > TAU - 0.35:
			dk = 0.0
			a_dep = a_now
		var rk: Array = ride_for.call(dk)
		lt = float(rk[0])
		kq = float(rk[1])
	else:
		# Leave half a lap short of where the world will be,
		# found three times as ride and coast depend on each other.
		var T_est := clampf(1.3 + 0.9 + 0.9 * clampf((absf(r1 - r2) - 200.0) / 1200.0, 0.0, 1.0), 1.3, 3.2)
		for _k in 3:
			var cw := center(i, t + lt + T_est)
			a_dep = atan2(cw.z, cw.x) - sense * PI
			var dang := fposmod(sense * (a_dep - a_now), TAU)
			# nearly there already, or just past: leave now (a little short or
			# long of half a lap rather than a whole lap round)
			if dang > TAU - 0.35:
				dang = 0.0
				a_dep = a_now
			# Under half a lap ahead, leave now on a shorter tangent arc instead of riding round.
			elif dang > PI:
				return null
			var rf: Array = ride_for.call(dang)
			lt = float(rf[0])
			kq = float(rf[1])
	# the ride, as `_step_phase` flies it
	var n_r := roundi(lt / SAMPLE)
	lt = n_r * SAMPLE
	var ride := PackedVector3Array()
	var ride_b := PackedByteArray()
	for k in n_r:
		var tau := k * SAMPLE
		var a := a_now + w * (tau + (kq - 1.0) * (tau / 2.0 - lt / (4.0 * PI) * sin(TAU * tau / lt)))
		ride.append(Vector3(cos(a) * r1, 0.0, sin(a) * r1))
		var at := w * (kq - 1.0) * PI / lt * sin(TAU * tau / lt) * r1
		ride_b.append(1 if absf(at) > 4.0 else 0)
	# the ride round the orbit keeps off every world's disc too
	for k4 in range(0, n_r, 6):
		for ob in L.bodies:
			if ob.world == &"":
				continue
			var oc := center(ob.index, t + k4 * SAMPLE)
			if Vector2(ride[k4].x - oc.x, ride[k4].z - oc.z).length() < ob.r + 8.0:
				return null
	var a_d := a_now + w * lt * (1.0 + (kq - 1.0) * 0.5) if n_r > 0 else a_now
	var t_d := t + lt
	var p_d := Vector3(cos(a_d) * r1, 0.0, sin(a_d) * r1)
	var v_d := Vector3(-sin(a_d), 0.0, cos(a_d)) * w * r1
	# the coast, leaving along the orbit: a half-ellipse to the near side of the
	# world's ring (outside it coming in, inside it going out)
	var ra_w: float = approach_r(i)
	var r_arr := r2 + ra_w if r2 < r1 else r2 - ra_w
	var std := {"p": p_d, "v": v_d, "body": -9, "esc": {}, "bare": true, "hohmann": true, "hohmann_r": r_arr}
	var kb := 1.0
	if why:
		print("  star transfer: r %.0f -> %.0f (arrives at %.0f), ride %.2f s (x%.1f) from %.2f to %.2f rad" % [r1, r2, r_arr, lt, kq, a_now, a_d])
	# kept: the same coast (as long), so the drawn line holds its shape
	if prefer.has("T_coast"):
		std["t_end"] = t_d + float(prefer.T_coast)
	if prefer.has("abs_side"):
		std["abs_side"] = true
	var best: FlightPlan = null
	var best_g := -1.0
	var sides: Array = [1.0]
	for cap: float in [5.0, 7.0]:
		_tcap = cap
		for sd: float in sides:
			var pc := _manoeuvre(i, t_d, std, kb, sd, false)
			if why:
				print("  star transfer side %d cap %.0f: %s" % [sd, cap, "null" if pc == null else ("clean" if _clean(pc, true, std, i) else "unclean")])
			# (a kept one is kept while it is merely clear: it was clean when chosen)
			if pc == null or not _clean(pc, prefer.is_empty(), std, i):
				continue
			var g := _grace(pc)
			if g > best_g:
				best_g = g
				best = pc
		if best != null:
			break
	_tcap = 5.0
	if best == null:
		return null
	# the ride first, then the coast
	var all := PackedVector3Array(ride)
	all.append_array(best.samp)
	var lit := PackedByteArray(ride_b)
	lit.append_array(best.burns)
	best.samp = all
	best.burns = lit
	best.t0 = t
	best.dur = (all.size() - 1) * SAMPLE
	best.esc_t = lt
	best.lead = 0.0
	best.kind = &"hohmann"
	best.choice = {"kf": kb, "side": float(best.end.get("side_abs", 1.0)), "way": false, "strict": true, "tcap": 5.0, "high": false, "kind": "hohmann",
		"star_ride": true, "a_dep": a_d, "T_coast": float(best.end.get("t_coast", best.end.t)) - t_d}
	return best


## A short hop in the world's own frame for a world already close; null if none keeps clear.
## Why: docs/why/ShipFlight.md#near-hop
func _near_hop(i: int, t: float, st: Dictionary, pick: Dictionary = {}) -> FlightPlan:
	var b := L.bodies[i]
	var rti: float = orbit_r(i)
	var ra: float = approach_r(i)
	var c0 := center(i, t)
	var cv0 := center_vel(i, t)
	var p: Vector3 = st.p
	var v: Vector3 = st.v
	var r0 := Vector2(p.x - c0.x, p.z - c0.z)
	var v0 := Vector2(v.x - cv0.x, v.z - cv0.z)
	var d0 := r0.length()
	if d0 > ra * 2.3 or d0 < 0.5:
		return null
	var best: FlightPlan = null
	var best_g := -1.0
	var a_start := atan2(r0.y, r0.x)
	var w_start := r0.cross(v0) / (d0 * d0)
	var rd_start := v0.dot(r0 / d0)
	var sds: Array = [1.0, -1.0]
	var sweeps: Array = [0.9, 1.4, 0.5, 2.0]
	var tks: Array = [1.0, 1.4, 1.9]
	if pick.has("hop"):
		var hk: Array = pick.hop
		sds = [hk[0]]
		sweeps = [hk[1]]
		tks = [hk[2]]
	for sd: float in sds:
		for sweep: float in sweeps:
			for tk: float in tks:
				var re := clampf(d0, minf(rti * 1.08, ra), ra)
				# replayed: round to the same place on the ring, arriving when it did
				var a_end := a_start + sd * sweep
				if pick.has("a_end_rel"):
					a_end = float(pick.a_end_rel)
				var path_len := absf(d0 - re) + sweep * (d0 + re) * 0.5
				var T := clampf(path_len / maxf(60.0, 0.5 * (v0.length() + APP_V)), 0.8, 3.5) * tk
				if pick.has("t_end"):
					T = maxf(float(pick.t_end) - t, 0.5)
				var n := maxi(8, roundi(T / SAMPLE))
				T = n * SAMPLE
				var w_end := sd * APP_V / re
				# angle and radius each a quintic, from the ship's own rates to the
				# ring's
				var aq := [a_start, w_start * T, 0.0, a_end, w_end * T, 0.0]
				var rq := [d0, rd_start * T, 0.0, re, 0.0, 0.0]
				var pl := FlightPlan.new()
				pl.t0 = t
				pl.sdt = SAMPLE
				var ok := true
				var amax := 1.0
				var prev := Vector3.INF
				var prev_v := Vector3.INF
				for k in n + 1:
					var u := float(k) / float(n)
					var aa := _q5(aq, u, 0)
					var rr := _q5(rq, u, 0)
					if rr < b.r * 1.3 + 6.0:
						ok = false
						break
					var ck := center(i, t + k * SAMPLE)
					var q := ck + Vector3(cos(aa) * rr, 0.0, sin(aa) * rr)
					# (clear of every star: a twin's second too; one sun, star A at
					# the origin as before)
					var in_star := false
					for s in _stars:
						if (Vector2(q.x, q.z) - L.star_pos(s, t + k * SAMPLE)).length() < keep_clear(s):
							in_star = true
					if in_star:
						ok = false
						break
					if k % 12 == 0:
						for ob in L.bodies:
							if ob.world == &"" or ob.index == i:
								continue
							var oc := center(ob.index, t + k * SAMPLE)
							if Vector2(q.x - oc.x, q.z - oc.z).length() < ob.r + 8.0:
								ok = false
						if not ok:
							break
					if prev != Vector3.INF:
						var vq := (q - prev) / SAMPLE
						if vq.length() > 950.0:
							ok = false
							break
						if prev_v != Vector3.INF:
							amax = maxf(amax, (vq - prev_v).length() / SAMPLE)
						prev_v = vq
					prev = q
					pl.samp.append(q)
					pl.burns.append(1)
				if not ok or amax > 4000.0:
					continue
				# NO STALL AND NO CORNER as drawn: a hop that all but stops (to turn
				# back) draws a cusp, the world moving under it
				var vmin := INF
				var vlast := Vector2.INF
				var sharp := false
				for k3 in range(3, pl.samp.size(), 3):
					var qa := pl.samp[k3 - 3]
					var qb := pl.samp[k3]
					var dv2 := Vector2(qb.x - qa.x, (qb.z - qa.z) * TILT)
					vmin = minf(vmin, Vector2(qb.x - qa.x, qb.z - qa.z).length() / (3.0 * SAMPLE))
					if vlast != Vector2.INF and dv2.length() > 0.05 and vlast.length() > 0.05:
						if absf(vlast.angle_to(dv2)) / maxf(dv2.length(), 0.3) > 0.3:
							sharp = true
					if dv2.length() > 0.05:
						vlast = dv2
				var v_abs0 := Vector2(v.x, v.z).length()
				if sharp or vmin < maxf(20.0, 0.3 * minf(v_abs0, APP_V)):
					continue
				pl.amax = amax
				pl.dur = n * SAMPLE
				pl.esc_t = 0.0
				var er := Vector2(cos(a_end), sin(a_end))
				var ep := Vector2(-er.y, er.x)
				var arel := er * re
				var rv := ep * w_end * re
				var ce := center(i, t + T)
				var cve := center_vel(i, t + T)
				pl.end = {"body": i, "p": ce + Vector3(arel.x, 0.0, arel.y), "v": cve + Vector3(rv.x, 0.0, rv.y), "keep": false, "t": t + T,
					"a": -er * re * w_end * w_end, "arel": arel, "rv": rv}
				# THE GENTLEST, and one that turns the way it will go round: a hop
				# that bends against the orbit first is a hook
				var g := _grace(pl)
				var against := 0.0
				var pv2 := Vector2.INF
				for k2 in range(0, pl.samp.size() - 6, 6):
					var a2 := pl.samp[k2]
					var b2 := pl.samp[k2 + 6]
					var d2 := Vector2(b2.x - a2.x, (b2.z - a2.z) * TILT)
					if pv2 != Vector2.INF and d2.length() > 0.5 and pv2.length() > 0.5:
						var tn := pv2.angle_to(d2)
						if signf(tn) != sd:
							against += absf(tn)
					pv2 = d2
				g -= against * 60.0
				if g > best_g:
					best_g = g
					best = pl
					pl.kind = &"near"
					pl.choice = {"kf": 1.0, "side": sd, "way": false, "strict": true, "tcap": 5.0, "high": false, "kind": "near", "near": true, "hop": [sd, sweep, tk], "a_end_rel": a_end}
				# gentle enough: no need to look further
				if best_g > 80.0:
					return best
	# none gentle enough (tighter than 20 px, or a hook): the ordinary flight
	if best_g < 20.0 and pick.is_empty():
		return null
	return best


## The waypoint a two-leg coast turns at.
static func _waypoint_of(legs: Array) -> Vector3:
	return legs[0][0].get("to", Vector3.ZERO)


## Whether a plan swings far out past both its ends: out beyond 1.3 times the
## farther of where it starts and where it arrives.
func _too_wide(pl: FlightPlan, i: int, st: Dictionary) -> bool:
	var p0: Vector3 = st.p
	var r_s := Vector2(p0.x, p0.z).length()
	var r_t := star_ring()
	if i >= 0:
		var ce := center(i, float(pl.end.get("t", pl.t0 + pl.dur)))
		r_t = Vector2(ce.x, ce.z).length()
	var lim := maxf(r_s, r_t) * 1.3 + 40.0
	for k in range(0, pl.samp.size(), 8):
		if Vector2(pl.samp[k].x, pl.samp[k].z).length() > lim:
			return true
	return false


## HOW GRACEFUL a plan is, as drawn at zoom 1: the radius of its tightest bend
## in screen px (bigger is better) -- what a plan is chosen by among the clean.
func _grace(pl: FlightPlan) -> float:
	var sp := PackedVector2Array()
	for k in range(0, pl.samp.size(), 3):
		var q := pl.samp[k]
		sp.append(Vector2(q.x, q.z * TILT))
	var worst := 0.0
	for k in range(2, sp.size() - 2):
		var u := sp[k] - sp[k - 2]
		var v := sp[k + 2] - sp[k]
		var ln := u.length() + v.length()
		if ln < 1.5:
			continue
		worst = maxf(worst, absf(u.angle_to(v)) / ln)
	var gr := 1.0 / maxf(worst, 1e-4)
	# An arrival that turns one way and orbits the other overshoots and hooks back.
	if pl.end.has("arel") and not bool(pl.end.get("keep", false)) and sp.size() > 12:
		var arel: Vector2 = pl.end.arel
		var rv: Vector2 = pl.end.rv
		var dr := 1.0 if arel.x * rv.y - arel.y * rv.x >= 0.0 else -1.0
		var turn := 0.0
		var span := 0.0
		for k in range(sp.size() - 10, sp.size() - 1):
			var u2 := sp[k] - sp[k - 1]
			var v2 := sp[k + 1] - sp[k]
			turn += u2.angle_to(v2)
			span += v2.length()
		# bending against it, tighter than about 150 px
		if span > 1.0 and signf(turn) != dr and absf(turn) / span > 1.0 / 150.0:
			gr = minf(gr, 2.0)
	return gr


## The insertion tail is made once for the chosen plan;
## making it for every try was most of the planning time.
func _tail(pl: FlightPlan) -> FlightPlan:
	if pl == null or not pl.tail.is_empty():
		return pl
	# (a solved flight's choice is `FlightSolve`'s own, given back as it was)
	if pl.res == null and not pl.choice.is_empty() and pl.end.has("t"):
		pl.choice["t_end"] = float(pl.end.get("t_coast", pl.end.t))
		if pl.end.has("t1"):
			pl.choice["T_coast"] = float(pl.end.get("t_coast", pl.end.t)) - float(pl.end.t1)
		if pl.end.has("side_abs"):
			pl.choice["abs_side"] = float(pl.end.side_abs)
	var i: int = pl.end.body
	var t2: float = pl.end.t
	var arel: Vector2 = pl.end.arel
	var rv: Vector2 = pl.end.rv
	var aend: Vector2 = pl.end.a
	if pl.end.keep:
		# A solved flight comes to rest in its own samples: the second held alongside, drawn on,
		# made a corner of 53 to 86 deg a px at zoom 2.
		# Why: docs/why/ShipFlight.md#plan-tail
		if pl.res != null:
			return pl
		for k in 13:
			var tk := float(k) * 0.1
			var off := arel + rv * 0.35 * (1.0 - exp(-tk / 0.35))
			var ck := center(i, t2 + tk)
			pl.tail.append(ck + Vector3(off.x, 0.0, off.y))
		return pl
	var rti: float = orbit_r(i)
	var spd: float = STAR_RAIL_V if i < 0 else RAIL_V
	var dr := 1.0 if arel.x * rv.y - arel.y * rv.x >= 0.0 else -1.0
	if pl.res != null and absf(arel.length() - rti) < ON_RING_PX and (absf(rv.length() - spd) < ON_RING_V * pl.pace or (pl.pace > 1.0 and rv.length() > spd and absf(rv.dot(arel / maxf(arel.length(), 0.001))) < ON_RING_V * pl.pace)):
		# Already on the ring, so the tail is the ring itself with the engine off.
		pl.tail_lit = false
		var w := dr * spd / rti
		var a0 := atan2(arel.y, arel.x)
		# (a fast flight arrives faster than the ring goes and spins down onto
		# it over SPIN_S, `start_rail`: that much further round, w_arr - w times
		# the integral of 1 - smoothstep)
		var w_arr := dr * rv.length() / rti
		var spun := pl.pace > 1.0 and absf(w_arr) > absf(w) + 1e-9
		for k3 in 121:
			var tk3 := TAIL_S * float(k3) / 120.0
			var ck3 := center(i, t2 + tk3)
			var ak := a0 + w * tk3
			if spun:
				var x := clampf(tk3 / SPIN_S, 0.0, 1.0)
				ak += (w_arr - w) * SPIN_S * (x - x * x * x + 0.5 * x * x * x * x)
			pl.tail.append(ck3 + Vector3(cos(ak) * rti, 0.0, sin(ak) * rti))
		return pl
	var ins := insert_plan(arel, rv, rti, dr * spd / rti, null if i < 0 else L.bodies[i], aend, i)
	pl.tail_k = float(ins.get("kmax", 0.0))
	for k in 121:
		var sk2 := float(k) / 120.0
		var ck2 := center(i, t2 + sk2 * float(ins.T))
		var q2 := _ins_at(ins, sk2, 0)
		pl.tail.append(ck2 + Vector3(q2.x, 0.0, q2.y))
	return pl


## Lambert coast on the plane, sampled SAMPLE apart; `full` false returns only the end motions.
func _lam(r1: Vector3, r2: Vector3, T: float, kf: float, full := true) -> Dictionary:
	var f1 := Vector3(r1.x, 0.0, r1.z)
	var f2 := Vector3(r2.x, 0.0, r2.z)
	if f1.length() < 1.0 or f2.length() < 1.0:
		return {}
	var dth := _pro_angle(f1, f2)
	# AT HALF A LAP THE ARC'S PLANE IS UNDEFINED and the solution meaningless (it
	# missed its end by 900 px): none within 7 degrees of it; a waypoint flies it
	if absf(sin(dth)) < 0.12:
		if why:
			print("    half a lap: dth %.2f" % dth)
		return {}
	var a := (f1.length() + f2.length()) / 2.0
	var tof := kf * dth * sqrt(a * a * a)
	var sol := LambertSpace.solve(f1, f2, dth, tof)
	if sol.is_empty():
		if why:
			print("    lambert: no solution, dth %.2f r1 %.0f r2 %.0f" % [dth, f1.length(), f2.length()])
		return {}
	var kk := tof / T
	if not full:
		return {"v0": (sol[0] as Vector3) * kk, "v2": (sol[1] as Vector3) * kk, "a2": _acc(f2) * kk * kk}
	var m := 160
	var pv := _coast_pv(f1, sol[0], tof, m)
	var nodes: PackedVector3Array = pv[0]
	var vels: PackedVector3Array = pv[1]
	var err := nodes[m] - f2
	if err.length() > 30.0:
		if why:
			print("    coast misses by %.0f, dth %.2f" % [err.length(), dth])
		return {}
	# as shown: speed scales by kk, the star's pull by kk squared
	var vmax := 0.0
	var gmax := 0.0
	for j in m + 1:
		vmax = maxf(vmax, vels[j].length() * kk)
		gmax = maxf(gmax, _acc(nodes[j]).length() * kk * kk)
	return {"nodes": nodes, "vels": vels, "err": err, "tof": tof, "T": T,
		"v0": (sol[0] as Vector3) * kk, "v2": (sol[1] as Vector3) * kk, "vmax": vmax, "gmax": gmax,
		"a0": _acc(nodes[0]) * kk * kk, "a2": _acc(nodes[m]) * kk * kk}


## A coast's points, SAMPLE apart, by cubic Hermite between its integrated
## steps on their own velocities; the miss at the end taken out evenly.
static func _sample(lg: Dictionary) -> void:
	if lg.has("pts"):
		return
	var nodes: PackedVector3Array = lg.nodes
	var vels: PackedVector3Array = lg.vels
	var m := nodes.size() - 1
	var tof: float = lg.tof
	var err: Vector3 = lg.err
	var hstep := tof / m
	var n := maxi(2, roundi(float(lg.T) / SAMPLE))
	var pts := PackedVector3Array()
	pts.resize(n + 1)
	for k in n + 1:
		var lam := float(k) / float(n) * tof
		var j := mini(m - 1, int(floor(lam / hstep)))
		var sj := lam / hstep - j
		var s2 := sj * sj
		var s3 := s2 * sj
		var q := (2.0 * s3 - 3.0 * s2 + 1.0) * nodes[j] + (s3 - 2.0 * s2 + sj) * hstep * vels[j]
		q += (-2.0 * s3 + 3.0 * s2) * nodes[j + 1] + (s3 - s2) * hstep * vels[j + 1]
		q -= err * (float(k) / float(n))
		q.y = 0.0
		pts[k] = q
	lg.pts = pts


## The coast under the star, in m RK4 steps: its points and velocities.
static func _coast_pv(r: Vector3, v: Vector3, T: float, m: int) -> Array:
	var hh := T / m
	var ps := PackedVector3Array([r])
	var vs := PackedVector3Array([v])
	var x := r
	var u := v
	for _i in m:
		var a1 := _acc(x)
		var x2 := x + u * hh / 2.0
		var u2 := u + a1 * hh / 2.0
		var a2 := _acc(x2)
		var x3 := x + u2 * hh / 2.0
		var u3 := u + a2 * hh / 2.0
		var a3 := _acc(x3)
		var x4 := x + u3 * hh
		var u4 := u + a3 * hh
		var a4 := _acc(x4)
		x += (u + 2.0 * u2 + 2.0 * u3 + u4) * hh / 6.0
		u += (a1 + 2.0 * a2 + 2.0 * a3 + a4) * hh / 6.0
		ps.append(x)
		vs.append(u)
	return [ps, vs]


## The angle from r1 round to r2 the way the worlds go (0..TAU).
static func _pro_angle(r1: Vector3, r2: Vector3) -> float:
	var base := acos(clampf(Vector2(r1.x, r1.z).normalized().dot(Vector2(r2.x, r2.z).normalized()), -1.0, 1.0))
	return base if r1.x * r2.z - r1.z * r2.x >= 0.0 else TAU - base


## Which way a coast from a to b sets off, on the plane: a reference transfer's
## own, or straight at it.
func _guess_dir(a: Vector3, b: Vector3) -> Vector2:
	var g := _lam(a, b, 2.0, 1.0, false)
	if not g.is_empty():
		var v: Vector3 = g.v0
		if Vector2(v.x, v.z).length() > 0.01:
			return Vector2(v.x, v.z).normalized()
	var d := Vector2(b.x - a.x, b.z - a.z)
	return d.normalized() if d.length() > 0.01 else Vector2.RIGHT


## H1 and H2 blend shapes keep position, velocity and pull continuous (C2).
static func _h1(x: float) -> float:
	return x - 6.0 * x * x * x + 8.0 * x * x * x * x - 3.0 * pow(x, 5.0)


static func _h2(x: float) -> float:
	return 0.5 * x * x - 1.5 * x * x * x + 1.5 * pow(x, 4.0) - 0.5 * pow(x, 5.0)


## A place's own acceleration (its orbit's pull), on the plane.
func center_acc(i: int, t: float) -> Vector3:
	return (center_vel(i, t + 0.05) - center_vel(i, t - 0.05)) / 0.1


## A scalar quintic Hermite on s (0..1): c = [x0, x0', x0'', x1, x1', x1''] in s.
static func _q5(c: Array, s: float, d: int) -> float:
	var s2 := s * s
	var s3 := s2 * s
	var s4 := s3 * s
	var s5 := s4 * s
	var hh: Array
	if d == 0:
		hh = [1.0 - 10.0 * s3 + 15.0 * s4 - 6.0 * s5, s - 6.0 * s3 + 8.0 * s4 - 3.0 * s5,
			0.5 * s2 - 1.5 * s3 + 1.5 * s4 - 0.5 * s5, 10.0 * s3 - 15.0 * s4 + 6.0 * s5,
			-4.0 * s3 + 7.0 * s4 - 3.0 * s5, 0.5 * s3 - s4 + 0.5 * s5]
	elif d == 1:
		hh = [-30.0 * s2 + 60.0 * s3 - 30.0 * s4, 1.0 - 18.0 * s2 + 32.0 * s3 - 15.0 * s4,
			s - 4.5 * s2 + 6.0 * s3 - 2.5 * s4, 30.0 * s2 - 60.0 * s3 + 30.0 * s4,
			-12.0 * s2 + 28.0 * s3 - 15.0 * s4, 1.5 * s2 - 4.0 * s3 + 2.5 * s4]
	else:
		hh = [-60.0 * s + 180.0 * s2 - 120.0 * s3, -36.0 * s + 96.0 * s2 - 60.0 * s3,
			1.0 - 9.0 * s + 18.0 * s2 - 10.0 * s3, 60.0 * s - 180.0 * s2 + 120.0 * s3,
			-24.0 * s + 84.0 * s2 - 60.0 * s3, 3.0 * s - 12.0 * s2 + 10.0 * s3]
	var q := 0.0
	for k in 6:
		q += float(c[k]) * float(hh[k])
	return q


## How hard a plan is to fly: its speed over 1,200 px/s and its pull over
## 5,000 px/s², as one penalty (0 for a strictly clean one).
func _harsh(pl: FlightPlan) -> float:
	var n := pl.samp.size()
	var vmax := 0.0
	var amax := 0.0
	var pv := Vector3.INF
	for k in range(0, n - 4, 4):
		var v := (pl.samp[k + 4] - pl.samp[k]) / (4.0 * pl.sdt)
		vmax = maxf(vmax, v.length())
		if pv != Vector3.INF:
			amax = maxf(amax, (v - pv).length() / (4.0 * pl.sdt))
		pv = v
	return maxf(0.0, vmax - 1200.0) / 100.0 + maxf(0.0, amax - 5000.0) / 2000.0


## Clearance less a penalty for speed and pull, so the flown plan neither cuts a disc nor jumps.
## Why: docs/why/ShipFlight.md#unclean-score
func _clearance(pl: FlightPlan, st: Dictionary, i: int) -> float:
	var n := pl.samp.size()
	var least := INF
	var vmax := 0.0
	var amax := 0.0
	var pv := Vector3.INF
	for k in range(0, n, 6):
		var q := pl.samp[k]
		if k + 6 < n:
			var v := (pl.samp[k + 6] - q) / (6.0 * pl.sdt)
			vmax = maxf(vmax, v.length())
			if pv != Vector3.INF:
				amax = maxf(amax, (v - pv).length() / (6.0 * pl.sdt))
			pv = v
		var tk := pl.t0 + k * pl.sdt
		least = minf(least, Vector2(q.x, q.z).length() - L.star_r)
		for b in L.bodies:
			if b.world == &"":
				continue
			if b.index == int(st.body) and k * pl.sdt < pl.esc_t + 0.3:
				continue
			if b.index == int(st.get("left", -9)) and k * pl.sdt < pl.esc_t + 0.8:
				continue
			if b.index == i and (n - k) * pl.sdt < 0.5:
				continue
			var c := center(b.index, tk)
			least = minf(least, Vector2(q.x - c.x, q.z - c.z).length() - b.r)
	return minf(least, 20.0) - maxf(0.0, vmax - 1200.0) / 100.0 - maxf(0.0, amax - 5000.0) / 2000.0


## Clean: clear of keep-clear and every disc; the old planner flies one fixed star only.
func _clean(pl: FlightPlan, strict: bool, st: Dictionary, i: int) -> bool:
	var n := pl.samp.size()
	var pv := Vector3.INF
	for k in range(0, n, 4):
		var q := pl.samp[k]
		var tk := pl.t0 + k * pl.sdt
		# on the last of the approach to a place that itself sits near the star, the
		# margin gives way to the place's own distance (never into the disc)
		var kc := keep_clear()
		if (n - k) * pl.sdt < 0.6:
			var ep: Vector3 = pl.end.get("p", q)
			kc = maxf(minf(kc, Vector2(ep.x, ep.z).length() - 16.0), L.star_r + 8.0)
		if Vector2(q.x, q.z).length() < kc and not (i < 0 and (n - k) * pl.sdt < 0.4):
			if why:
				print("    unclean: the star at %.2f s, r %.0f" % [k * pl.sdt, Vector2(q.x, q.z).length()])
			return false
		for b in L.bodies:
			if b.world == &"":
				continue
			if b.index == int(st.body) and k * pl.sdt < pl.esc_t + 0.3:
				continue
			if b.index == i and (n - k) * pl.sdt < 0.5:
				continue
			var c := center(b.index, tk)
			# just out of a world's ring, its margin gives way -- never its disc
			var margin := 2.0 if b.index == int(st.get("left", -9)) and k * pl.sdt < pl.esc_t + 0.8 else 8.0
			if Vector2(q.x - c.x, q.z - c.z).length() < b.r + margin:
				if why:
					print("    unclean: world %d at %.2f s (of %.2f, escape %.2f)" % [b.index, k * pl.sdt, n * pl.sdt, pl.esc_t])
				return false
		if strict and k + 4 < n:
			var v := (pl.samp[k + 4] - q) / (4.0 * pl.sdt)
			if v.length() > 1200.0:
				if why:
					print("    unclean: %.0f px/s at %.2f s (of %.2f, escape %.2f)" % [v.length(), k * pl.sdt, n * pl.sdt, pl.esc_t])
				return false
			if pv != Vector3.INF and (v - pv).length() / (4.0 * pl.sdt) > 5000.0:
				if why:
					print("    unclean: %.0f px/s2 at %.2f s (of %.2f, escape %.2f)" % [(v - pv).length() / (4.0 * pl.sdt), k * pl.sdt, n * pl.sdt, pl.esc_t])
				return false
			pv = v
	return true


## The ship's own motion as it leaves: free, it is its velocity; on a rail or
## alongside, the motion it has there.
func _v0() -> Vector3:
	return Vector3(f.v.x, 0.0, f.v.y)


## Plans on this thread for a harness; the map plans on a worker.
func fly(i: int, t: float, done: Callable, prefer: Dictionary = {}, pv: FlightPlan = null) -> FlightPlan:
	click_replanned = false
	if pv != null and pv.to == i:
		var rd := _takeable(pv, t)
		if not rd.is_empty():
			# THE DRAWN FLIGHT LEAVING LATE (`CLICK_LATE`): a fresh one planned at
			# the click, as the map's worker plans it (PLAN_AHEAD on), flown when
			# it arrives sooner
			if pv.res != null and pv.pace > 1.0 and float(pv.t0) - t > CLICK_LATE:
				var pn := make_plan(i, t, {}, PLAN_AHEAD)
				var rn := _takeable(pn, t) if pn != null else {}
				if not rn.is_empty() and _sooner(pn, pv):
					click_replanned = true
					_fly_plan(pn, rn, t, done)
					return plan
			_fly_plan(pv, rd, t, done)
			return plan
	var pl := make_plan(i, t, prefer)
	# A KEPT CHOICE OF TODAY'S PLANNER THAT NO LONGER STARTS WHERE THE SHIP IS
	# (made for another moment): planned afresh, so the flight never jumps
	if pl != null and pl.res == null and not prefer.is_empty() and pl.lead <= 0.0 and not pl.samp.is_empty():
		var w0 := where3()
		if Vector2(pl.samp[0].x - w0.x, pl.samp[0].z - w0.z).length() > 3.0:
			if why:
				print("  kept plan starts %.0f px from the ship: planned afresh" % Vector2(pl.samp[0].x - w0.x, pl.samp[0].z - w0.z).length())
			pl = make_plan(i, t)
	if pl == null:
		return null
	var rd2 := _takeable(pl, t)
	if rd2.is_empty():
		# Planned here this moment, so its ride starts
		# from where the ship is, not across the circle.
		var a0 := float(rail.get("ang", 0.0))
		if mode == &"free" and star_orbiting():
			a0 = atan2(f.p.y - f.cen.y, f.p.x - f.cen.x)
		var ke2 := _ride_ke(pl)
		var T2 := maxf(pl.t0 - t, 0.0)
		var w2 := float(pl.dep.get("w", 0.0))
		rd2 = {"T": T2, "k": pl.lead_k, "a0": a0, "w": w2, "ke": 1.0, "ls": 0.0, "sp": 0.0}
		if ke2 != 1.0 and T2 > 1e-6 and absf(w2) > 1e-9:
			var dr2 := 1.0 if w2 >= 0.0 else -1.0
			var dang2 := fposmod(dr2 * (pl.res.a_dep - a0), TAU) if pl.res != null else 0.0
			rd2.merge(_ride_shape(dang2, absf(w2), T2, ke2), true)
			# (held to the bounds `_takeable` holds a ride to: unchecked, a
			# phasing under nought ran the ship backwards round its ring, the code
			# review, Nov 5. Planned once more from here with no kept choice; else
			# no slower than RIDE_K_MIN, the flight leaving a little off its point)
			if not _ride_flyable(rd2, pl.pace, absf(w2) * float(pl.dep.get("rt", 0.0))):
				if not prefer.is_empty():
					return fly(i, t, done)
				if why:
					print("  a ride out of bounds (k %.2f): held to %.1f" % [float(rd2.k), FlightSolve.RIDE_K_MIN])
				rd2.k = maxf(float(rd2.k), FlightSolve.RIDE_K_MIN)
	_fly_plan(pl, rd2, t, done)
	return plan


## Coast done: the insertion every capture flies; a solved flight lands exactly on the ring.
func _land(t: float) -> void:
	var e := plan.end
	var i: int = e.body
	if plan.res != null:
		var te := float(e.t)
		var arel: Vector2 = e.arel
		var rv0: Vector2 = e.rv
		var c0 := center(i, t)
		if e.get("keep", false):
			mode = &"keep"
			keep = {"body": i, "off": arel, "ev": Vector2.ZERO, "ev0": 0.0, "inf": arel}
			f.p = _flat(c0) + arel
			f.v = _flat(center_vel(i, t))
			plan = null
			return
		start_rail(i, arel, rv0, te, e.get("a", Vector2.ZERO), plan.pace)
		plan = null
		if not inserting():
			var w: float = float(rail.dir) * float(rail.speed) / float(rail.rt)
			# (spinning down onto it, from the arrival: `_spin_down`)
			if rail.has("spin"):
				w = _spin_down(t, w)
			else:
				rail.ang = float(rail.ang) + w * (t - te)
			var a: float = rail.ang
			var rt: float = rail.rt
			f.p = _flat(c0) + Vector2(cos(a), sin(a)) * rt
			f.v = _flat(center_vel(i, t)) + Vector2(-sin(a), cos(a)) * w * rt
			_arrived()
		return
	var p: Vector3 = e.p
	f.p = Vector2(p.x, p.z)
	f.v = Vector2((e.v as Vector3).x, (e.v as Vector3).z)
	var c := center(i, t)
	var rel := Vector2(p.x - c.x, p.z - c.z)
	var rv := f.v - _flat(center_vel(i, t))
	if e.get("keep", false):
		mode = &"keep"
		keep = {"body": i, "off": rel, "ev": rv, "ev0": rv.length(), "inf": rel + rv * KEEP_TAU}
	else:
		start_rail(i, rel, rv, t, e.get("a", Vector2.ZERO))
	plan = null


## On the orbit (or alongside) at the end of a flight: what it was flown for.
func _arrived() -> void:
	if _fly_done.is_valid():
		var d := _fly_done
		_fly_done = Callable()
		d.call()


static func _acc(p: Vector3) -> Vector3:
	var d := p.length()
	return -p / (d * d * d)
