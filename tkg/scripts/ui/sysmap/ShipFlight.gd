extends RefCounted

## YOUR SHIP ON THE SECTOR MAP, flown (Jon: "can we have WASD move the little
## ship? Just for fun, like can the player fly around the sector"). Jon's pick
## of the six mocked (scratchpad `shipflight`, option F, "Arcade orbits"):
##
## OPEN SPACE flies like a little ship and not like a planet. A and D turn the
## nose, W thrusts along it and fades out at a top speed, S brakes, and letting
## go coasts to a stop. There is no pull from the star: real gravity made every
## pass at the star or a giant a fight with the stick (Jon: "the sun's gravity
## is too much and makes flying feel clumsy and awkward"). The star is a soft
## bumper instead -- fly at it and your motion is turned sideways round it.
##
## A WORLD'S RING IS A RAIL. Let go inside it slower than CAPTURE and the ship
## eases onto a circular orbit round the world and stays there with no input;
## the panel opens that world. On the rail A and D take the orbit closer or
## wider, and W leaves along it (and the ring will not take you back for a
## moment, so leaving is easy). Belts, stations, derelicts and contacts hold you
## ALONGSIDE the same way; the star has a close-orbit ring of its own. Holding
## W never captures, so you can cruise across the system past a world.
##
## THE DOTTED LINE is where you will END UP if you let go now: the same step the
## ship flies, run forward, to the capture -- where it bends onto the orbit you
## will be on -- or to where the coast dies out. A capture the line is showing
## holds until you are STICKY over the capture speed, and the ship keeps to the
## same rule, so the line cannot say one thing and the ship do another. Measured
## in the mock over 303 approaches: the answer changed in the last two seconds
## before arrival 7 times, and matched what happened 300 times.
##
## EVERY AUTO-FLIGHT IS A MANOEUVRE (Jon: "when you double click on a planet,
## the trajectory should be actually orbitally sound", and "instead of flying
## straight to the planet ... more convincing orbital mechanics on the auto fly
## to a planet"). Out of an orbit, an ESCAPE: a prograde burn spiralling out of
## the ring to where it leaves along the transfer; then the TRANSFER, a Lambert
## conic round the star, prograde, engine off, faster near the star, a short
## burn at each end blending the motions; when no direct arc is clean, round a
## WAYPOINT outside with a burn there; then the ARRIVAL, met with the world's
## own motion, and the insertion any capture flies, onto the orbit. There is
## no straight or swooping fallback any more.
##
## All in the plane's own units (x across, z toward you); the view projects
## it. Nothing here is saved: where the ship is in a system
## lives for the session (`SystemMapScreen._flights`).

## THE FEEL, measured in the mock (a run of test players: steer at a world, then
## let go, brake, or wait for the line; 303 of 303 ended in orbit, none crashed,
## and crossing the system on W took 14 s).
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
## THE STAR HOLDS YOU WHEN NOTHING ELSE DOES (Jon: "If I'm not orbiting a
## planet, can't I orbit the star?"). Let go of thrust out of every ring and the
## ship turns (SETTLE_TURN) and burns, at most SETTLE_A, into a circle round the
## star at the distance it is, going the way the worlds go, at STAR_PACE times
## the worlds' own pace there (they keep Kepler's: 800 s a lap at 100 px, so
## 7.85 / sqrt(r) px/s; fifty times that is 39 px/s at 100 px, 20 at 400 and 13
## at the edge -- a lap in a minute or two). Settled within SETTLED_DV.
const SETTLE_A := 90.0
## Turning round onto the star's orbit (rad/s): a ship going the other way swings
## round at speed rather than stopping dead and reversing, which drew a cusp
## (Jon: "why are there sharp angles on some of the trajectories?").
const SETTLE_W := 1.0
const SETTLE_TAU := 0.5
const SETTLE_TURN := 0.28
const SETTLE_RAMP := 0.35
const STAR_PACE := 50.0
const SETTLED_DV := 2.0
## THE NOSE TURNS ON A SPRING, critically damped at this rate (rad/s): a half
## turn in about 0.3 s, eased in and out, never a jump.
const NOSE_W := 14.0
## AN ORBIT INSERTION (Jon: "can the animation where you enter the orbit of a
## planet be more smooth? like have a burn animation"): the approach blended onto
## the circle by a quintic Hermite in the world's own frame -- position, velocity
## and acceleration all continuous at both ends -- over INSERT_T (by distance and
## speed, clamped), the nose on the burn and the flame lit by it.
const INSERT_T := Vector2(0.7, 1.6)
const RAIL_V := 35.0
const STAR_RAIL_V := 45.0
## Alongside a belt's beacon, a station or a hulk: this close, as seen.
const KEEP_R := 22.0
const TILT := 0.38

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
		return c


## A planned flight, sampled SAMPLE apart: where the ship is and whether its
## engine is lit, along the whole of it; `tail` is the insertion after it, for
## drawing it before it is flown.
class FlightPlan:
	var dur := 1.4
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
	## OUT OF AN ORBIT: how long the ship rides round its ring before the escape
	## (samples start then: `t0` is that moment), and how hard it phases to get
	## there sooner (1 = no burn); and which of the tries it was, so a replan can
	## keep to it
	var lead := 0.0
	var lead_k := 1.0
	var choice: Dictionary = {}
	## the insertion's sharpest curvature as drawn (1 / its tightest radius, px)
	var tail_k := 0.0

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
	f = FreeState.new()
	# IN ORBIT OF THE STAR AS IT ARRIVES (Jon: "Can we start the ship in orbit
	# around the star? Like it can be as far away as it normally is when a sector
	# is entered"): out where it warps in, on a circle clear of every place's
	# ring and inside the edge, going round the way the worlds go
	var r := arrival_r(edge_point.length())
	f.p = edge_point.normalized() * r if edge_point.length() > 1.0 else Vector2(r, 0.0)
	f.orbit_r = r
	f.sense = 1.0
	f.v = star_orbit_v(f.p, r, 1.0)
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
func star_rail() -> float:
	# the black hole's lens reaches far past its disc: its close orbit sits outside it
	if L.star == SystemLayout.StarKind.CORE:
		return 150.0
	return L.star_r + 44.0


func star_ring() -> float:
	return star_rail() + 35.0


## THE ORBIT A SHIP RIDES, OUT AT THE EDGE OF THE RING (Jon: "When you orbit an
## object... you orbit at the furthest distance"): just inside the place's
## capture ring, clear of its line. -1 the star's close orbit.
const ORBIT_K := 0.88
func orbit_r(i: int) -> float:
	if i < 0:
		return star_ring() - 8.0
	# (a world close in to the star: as far out as keeps the orbit off the
	# star's keep-clear, never lower than the old half ring)
	var b := L.bodies[i]
	return clampf(b.orbit - keep_clear() - 10.0, b.soi * 0.5, b.soi * ORBIT_K)


## Where a flight's coast meets the place, for the burn onto its orbit: just
## outside the ring, so the insertion comes in along it.
const APPROACH_K := 1.12
func approach_r(i: int) -> float:
	if i < 0:
		return star_ring() + 12.0
	return L.bodies[i].soi * APPROACH_K


func bumper() -> float:
	return star_rail() + 25.0


func keep_clear() -> float:
	return L.star_r + 32.0


func is_keep(i: int) -> bool:
	if i < 0:
		return false
	var k := L.bodies[i].kind
	return k == &"belt" or k == &"station" or k == &"derelict" or k == &"contact"


## Where a place is at time t: the star, a world, or for a belt the point its
## beacon rides.
func center(i: int, t: float) -> Vector3:
	if i < 0:
		return Vector3.ZERO
	var b := L.bodies[i]
	if b.kind == &"belt":
		var a: float = b.phase + t / b.period * TAU
		return Vector3(cos(a) * b.orbit, 0.0, sin(a) * b.orbit)
	return b.point3(t)


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


## What the ship is in orbit of or alongside: a body, -1 the star, -9 nothing.
func reached() -> int:
	if mode == &"rail":
		return -9 if (inserting() or rail.has("phase")) else int(rail.body)
	if mode == &"keep":
		return -9 if inserting() else int(keep.body)
	return -9


## Burning onto an orbit (or alongside), not yet on it.
func inserting() -> bool:
	if mode == &"rail":
		return float(rail.get("s", 1.0)) < 1.0
	if mode == &"keep":
		return (keep.get("ev", Vector2.ZERO) as Vector2).length() > 3.0
	return false


## What the ship is on, or burning onto: a body, -1 the star's close orbit, -9.
func orbit_body() -> int:
	if mode == &"rail":
		return int(rail.body)
	if mode == &"keep":
		return int(keep.body)
	return -9


## Settled on a wide orbit round the star (not its close one).
func star_orbiting() -> bool:
	return mode == &"free" and f.orbit_r > 0.0


## THE STAR ORBIT'S VELOCITY at plane point p, on radius r: round the way the
## worlds go, at the calm pace, with a pull back onto r once it is held.
func star_orbit_v(p: Vector2, r_hold: float, sense := 1.0) -> Vector2:
	var r := maxf(p.length(), 1.0)
	var rh := p / r
	var rr := r_hold if r_hold > 0.0 else r
	var spd := STAR_PACE * TAU * 1000.0 / (800.0 * sqrt(maxf(rr, 20.0)))
	var v := Vector2(-rh.y, rh.x) * spd * sense
	if r_hold > 0.0:
		v -= rh * (r - r_hold) * 1.2
	return v


## THE NOSE, turned toward `want` (a screen angle) on its spring.
func _nose(want: float, dt: float) -> void:
	var err := wrapf(want - ang, -PI, PI)
	_ang_v += (NOSE_W * NOSE_W * err - 2.0 * NOSE_W * _ang_v) * dt
	ang = wrapf(ang + _ang_v * dt, -PI, PI)
	f.head = ang


## A plane direction as the screen angle the ship is drawn at.
static func _scr_ang(v: Vector2) -> float:
	return atan2(v.y * TILT, v.x)


## The flame's level: the burn's share of its peak, flaring as it lights.
func _flame(k: float, dt: float) -> void:
	_burn_age += dt
	burn_k = clampf(k, 0.0, 1.0) * (1.0 + 0.6 * clampf(1.0 - _burn_age / 0.25, 0.0, 1.0))


# ---------------------------------------------------------------- a frame
var _fly_pos := Vector3.ZERO
var _last_screen := Vector2.ZERO


## Moves the ship on by `dt` real seconds; `t` is the system's clock now. Keys:
## {w, a, s, d} as held. Returns the thrust loop's level for this frame.
func step(dt: float, t: float, k: Dictionary) -> float:
	var any: bool = k.w or k.a or k.s or k.d
	if any and (mode == &"free" or mode == &"warp"):
		thrust_t = t
	if any or mode != &"free":
		fresh = false
	if mode == &"fly":
		var u := clampf((t - fly_t0) / plan.dur, 0.0, 1.0)
		_fly_pos = plan.pos(u)
		burn = plan.burning(u)
		rcs = false
		# THE SAME MANOEUVRE AS AN INSERTION: the nose on the burn while it burns
		# (retrograde as it arrives), along the way it goes between
		var du := 1.0 / 120.0
		var q0 := plan.pos(maxf(u - du, 0.0))
		var q2 := plan.pos(minf(u + du, 1.0))
		var vv := Vector2(q2.x - q0.x, q2.z - q0.z)
		var aa := Vector2(q2.x - 2.0 * _fly_pos.x + q0.x, q2.z - 2.0 * _fly_pos.z + q0.z)
		# WHERE IT IS AND HOW IT MOVES, kept as it flies: a new place chosen on
		# the way plans from here, at this speed (it planned from the motion the
		# ship had before the flight, and drew nonsense)
		f.p = Vector2(_fly_pos.x, _fly_pos.z)
		if u < 1.0:
			f.v = vv / (2.0 * du * plan.dur)
		var lvl := 0.0
		if burn and aa.length() > 0.0001:
			_nose(_scr_ang(aa), dt)
			var ac := aa.length() / pow(du * plan.dur, 2.0)
			_flame(clampf(ac / maxf(plan.amax, 1.0), 0.3, 1.0), dt)
			lvl = 0.7 * burn_k
		else:
			if vv.length() > 0.0001:
				_nose(_scr_ang(vv), dt)
			_burn_age = 0.0
			burn_k = 0.0
		if u >= 1.0:
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
		if not k.w:
			if k.a:
				f.head -= TURN * dt
			if k.d:
				f.head += TURN * dt
			ang = f.head
			var ev: Vector2 = keep.ev
			keep.off = (keep.off as Vector2) + ev * dt
			keep.ev = ev * exp(-dt / 0.35)
			var c := center(int(keep.body), t)
			f.p = _flat(c) + (keep.off as Vector2)
			f.v = _flat(center_vel(int(keep.body), t)) + (keep.ev as Vector2)
			rcs = false
			# BURNED TO A STOP ALONGSIDE: nose against the motion, flame on it
			var e0 := float(keep.get("ev0", 1.0))
			if ev.length() > 3.0 and not (k.a or k.d):
				burn = true
				_nose(_scr_ang(-ev), dt)
				_flame(ev.length() / maxf(e0, 1.0), dt)
				return 0.7 * burn_k
			burn = false
			burn_k = 0.0
			_burn_age = 0.0
			_arrived()
			return 0.32 if (k.a or k.d) else 0.0
		f.no_cap_body = int(keep.body)
		f.no_cap_left = NO_CAPTURE_S
		mode = &"free"
	# OPEN SPACE: a step
	# WHETHER THE COAST IS GOING INTO A RING anyway, held half a second
	if capture_ahead(f, t):
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
		keep = {"body": res.body, "off": res.rel, "ev": res.rv, "ev0": (res.rv as Vector2).length()}
		f.orbit_r = -1.0
	return lvl


func _step_rail(dt: float, t: float, k: Dictionary) -> float:
	var body := int(rail.body)
	if inserting():
		return _step_insert(dt, t, k)
	if rail.has("phase"):
		if k.w:
			# W: the flight is off; leave the orbit as W always does
			rail.erase("phase")
			plan = null
			_fly_done = Callable()
		else:
			return _step_phase(dt, t)
	rail.u = minf(1.0, float(rail.u) + dt / EASE)
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
	if k.w:
		# W: OFF THE RAIL, a prograde burn from the orbit's own motion (no kick:
		# the thrust does it), and this ring lets you go until you are out of it
		mode = &"free"
		f.v = _flat(cv) + tg * absf(wv) * r
		f.no_cap_body = body
		f.no_cap_left = NO_CAPTURE_S
		f.orbit_r = -1.0
		f.coast = 0.0
		rail = {}
		return 0.7
	return 0.32 if (k.a or k.d) else 0.0


## THE RIDE ROUND TO THE DEPARTURE POINT: on the ring at its own rate, sped up
## by a phasing burn when it is far (prograde, then back to the ring's own
## rate, so the escape starts with the orbit's own motion), then the flight.
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
	var kk: float = ph.k
	var a := float(ph.a0) + w * (tau + (kk - 1.0) * (tau / 2.0 - T / (4.0 * PI) * sin(TAU * tau / T)))
	var rt: float = rail.rt
	var tg := Vector2(-sin(a), cos(a))
	f.p = _flat(c) + Vector2(cos(a), sin(a)) * rt
	f.v = _flat(cv) + tg * w * (1.0 + (kk - 1.0) * pow(sin(PI * tau / T), 2.0)) * rt
	rail.ang = a
	rcs = false
	var at: float = w * (kk - 1.0) * PI / T * sin(TAU * tau / T) * rt
	var peak: float = absf(w) * (kk - 1.0) * PI / T * rt
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
func start_rail(body: int, rel: Vector2, rv: Variant, t: float, acc0 := Vector2.ZERO) -> void:
	var b: SystemLayout.Body = null if body < 0 else L.bodies[body]
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
	rail = {"body": body, "ang": atan2(rel.y, rel.x), "r0": rt, "rt": rt,
		"rmin": (L.star_r + 30.0) if b == null else (b.r + 10.0), "rmax": (star_ring() - 4.0) if b == null else b.soi * 0.95,
		"speed": spd, "dir": dir, "w0": dir * spd / rt, "u": 1.0, "s": 1.0}
	if rv != null:
		_plan_insert(rel, rv as Vector2, rt, dir * spd / rt, b, acc0)


## THE INSERTION'S CURVE in the world's frame: from `p0` moving `v0` (no burn
## yet) to the circle of radius `rt` at angular rate `w`, arriving with the
## circle's own velocity and pull. Its length by distance and speed; its end
## angle a sweep on from where it starts, the approach's own turning and the
## orbit's averaged. Kept clear of the world's disc: shorter, then longer, until
## its closest is outside it.
func _plan_insert(p0: Vector2, v0: Vector2, rt: float, w: float, b: SystemLayout.Body, acc0 := Vector2.ZERO) -> void:
	var best := insert_plan(p0, v0, rt, w, b, acc0)
	rail.ins = best
	rail.s = 0.0
	rail.ang = best.a1


## The insertion an approach would fly (the line draws it before it happens).
func insert_plan(p0: Vector2, v0: Vector2, rt: float, w: float, b: SystemLayout.Body, acc0 := Vector2.ZERO) -> Dictionary:
	var r0 := maxf(p0.length(), 1.0)
	var w0 := (p0.x * v0.y - p0.y * v0.x) / (r0 * r0)
	var a0 := atan2(p0.y, p0.x)
	var clear := (b.r + 6.0) if b != null else (L.star_r + 14.0)
	var base := clampf(2.4 * (absf(r0 - rt) + rt * 0.5) / (v0.length() + absf(w) * rt + 20.0), INSERT_T.x, INSERT_T.y)
	# OF THE CLEAR TRIES, THE ONE THAT TURNS LEAST SHARPLY as drawn (the plane
	# tilted as the map shows it): a try whose motion doubles back on itself drew
	# a loop or a corner
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


## AN INSERTION IN POLAR TERMS round the place (Jon: "why are there sharp
## angles on some of the trajectories?"): its angle and its radius each a
## quintic from the approach -- where it is, how it moves, its pull -- to the
## circle at angle a1. As a curve in x and y, an approach coming in nearly
## head-on had to turn so hard it drew a hairpin; round the place it spirals in,
## its angle never turning back.
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


## ONE STEP OF AN INSERTION: along the curve round the world as it moves, the
## nose on the burn, the flame by how hard it burns; at its end, on the circle.
## W breaks off it, from the motion it has.
func _step_insert(dt: float, t: float, k: Dictionary) -> float:
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
	if is_keep(body):
		mode = &"keep"
		var c := center(body, t)
		keep = {"body": body, "off": Vector2(8.0, 5.0 / TILT), "ev": Vector2.ZERO}
		f.p = _flat(c) + Vector2(8.0, 5.0 / TILT)
		return
	start_rail(body, Vector2(orbit_r(body), 0.0), null, t)


## THE COAST, AS IT IS, GOES INTO A RING: straight on for up to five seconds (a
## sample a tenth), the worlds moving, into a world's ring, alongside a station,
## belt or hulk, or into the star's close ring, slow enough to be taken. Then
## the settle onto the star holds off, so letting go aimed at a world gets you to
## it. Not the place you just left.
func capture_ahead(st: FreeState, t: float) -> bool:
	var no_cap := st.no_cap_body if st.no_cap_left > 0.0 else -9
	for j in range(1, 51):
		var tau := float(j) * 0.1
		var p := st.p + st.v * tau
		if no_cap != -1 and p.length() < star_ring() and st.v.length() < CAPTURE:
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


## THE STAR ORBIT A SHIP ARRIVES ON: radius r0 if every place's ring is well
## clear of it (a world's, a station's or belt's reach), else the nearest radius
## that is -- outward first, never past the edge, then inward.
func arrival_r(r0: float) -> float:
	var lo := star_ring() + 40.0
	var hi := L.edge - 12.0
	var clear := func(r: float) -> bool:
		for b in L.bodies:
			var reach: float = b.soi * 1.3 + 10.0 if b.world != &"" else (KEEP_R / TILT + 10.0 if is_keep(b.index) else 0.0)
			if reach > 0.0 and absf(r - b.orbit) < reach:
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
	if body == -1:
		return p.length() < star_ring()
	if body < 0 or body >= L.bodies.size() or L.bodies[body].world == &"":
		return false
	var c := center(body, t)
	return Vector2(p.x - c.x, p.y - c.z).length() < L.bodies[body].soi


# ---------------------------------------------------------------- one step of open space
## ONE STEP OF OPEN-SPACE FLIGHT, for the ship and for its line alike, so the
## line can only show what the ship will do. Returns a capture (&"rail",
## &"keep"), a ring crossed too fast (&"fast"), or {}.
func free_step(st: FreeState, k: Dictionary, t: float, dt: float, stick: int, real: bool) -> Dictionary:
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
	# COASTING SETTLES ONTO THE STAR (it used to drag to a stop): the nose turns
	# for SETTLE_TURN, then a burn eases in, at most SETTLE_A
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
			# the way round it is already going, unless it is hardly going round
			var tang := (st.p.x * st.v.y - st.p.y * st.v.x) / maxf(st.p.length(), 1.0)
			st.sense = signf(tang) if absf(tang) > 20.0 else 1.0
		st.coast += dt
		var tv := star_orbit_v(st.p, st.orbit_r, st.sense)
		var dv := tv - st.v
		var ramp := smoothstep(SETTLE_TURN, SETTLE_TURN + SETTLE_RAMP, st.coast)
		var turn_by := st.v.angle_to(tv)
		if st.v.length() > 10.0 and absf(turn_by) > 0.5:
			# GOING THE OTHER WAY: the motion swings round toward the orbit's at
			# speed (a turn you can see), not braked through nought and reversed
			var spd := st.v.length()
			var rot := clampf(turn_by, -SETTLE_W * dt, SETTLE_W * dt) * ramp
			var nspd := move_toward(spd, maxf(tv.length(), 20.0), SETTLE_A * 0.5 * dt * ramp)
			var nv := st.v.rotated(rot).normalized() * nspd
			st.aim = st.v.rotated(signf(turn_by) * PI / 2.0).normalized() * SETTLE_A
			st.acc = (nv - st.v) / dt
			st.v = nv
		else:
			var want := dv / SETTLE_TAU
			if want.length() > SETTLE_A:
				want *= SETTLE_A / want.length()
			st.aim = want
			st.acc = want * ramp
			# the circle's own pull, which is the star's and not a burn: without it
			# the burn holds a steady error and the ship creeps outward, never settling
			var r0 := maxf(st.p.length(), 1.0)
			var pull := -st.p / r0 * tv.length_squared() / r0 * ramp
			st.v += (st.acc + pull) * dt
		if st.orbit_r < 0.0 and dv.length() < SETTLED_DV and st.coast > SETTLE_TURN + SETTLE_RAMP:
			st.orbit_r = st.p.length()
	# THE RING YOU LEFT lets you go until you are out of it, and a moment more
	if st.no_cap_left > 0.0 and not _inside(st.no_cap_body, st.p, t):
		st.no_cap_left -= dt
	var no_cap := st.no_cap_body if st.no_cap_left > 0.0 else -9
	var r := st.p.length()
	var rh := st.p / r if r > 0.001 else Vector2.RIGHT
	var sp := st.v.length()
	# THE STAR IS A SOFT BUMPER: inside it, the inward part of your motion is turned
	# sideways (speed kept) and a little push goes out -- unless you are slow
	# enough for its close ring, which takes you instead
	var bm := bumper()
	if r < bm and not (no_cap != -1 and sp < CAPTURE + (STICKY if stick == -1 else 0.0) and not k.w):
		var kk := (bm - r) / bm
		var vr := st.v.dot(rh)
		if vr < 0.0:
			st.v -= rh * minf(1.0, kk * 10.0 * dt) * vr
			var nn := st.v.length()
			if nn > 0.01:
				st.v *= sp / nn
		st.v += rh * 40.0 * kk * dt
		st.bumped = true
	for b in L.bodies:
		if b.world == &"":
			continue
		var c := center(b.index, t)
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
	var rr := st.p.length()
	if rr > L.edge:
		st.p *= L.edge / rr
		var vr3 := st.v.dot(st.p / L.edge)
		if vr3 > 0.0:
			st.v -= st.p / L.edge * vr3
	if real and rr < L.star_r + 8.0 and rr > 0.001:
		st.p = st.p / rr * (L.star_r + 8.0)
	if k.w:
		return {}
	for b in L.bodies:
		if b.world == &"" or b.index == no_cap:
			continue
		var c2 := center(b.index, t)
		var rel := Vector2(st.p.x - c2.x, st.p.y - c2.z)
		if rel.length() < b.soi:
			var rv := st.v - _flat(center_vel(b.index, t))
			if rv.length() < CAPTURE + (STICKY if stick == b.index else 0.0):
				return {"kind": &"rail", "body": b.index, "rel": rel, "rv": rv, "at": st.p}
			if st.fast_seen != b.index:
				st.fast_seen = b.index
				return {"kind": &"fast", "body": b.index, "at": st.p}
	var r2 := st.p.length()
	if no_cap != -1 and r2 < star_ring():
		if st.v.length() < CAPTURE + (STICKY if stick == -1 else 0.0):
			return {"kind": &"rail", "body": -1, "rel": st.p, "rv": st.v, "at": st.p}
		if st.fast_seen != -1:
			st.fast_seen = -1
			return {"kind": &"fast", "body": -1, "at": st.p}
	for b in L.bodies:
		if not is_keep(b.index) or b.index == no_cap:
			continue
		var c3 := center(b.index, t)
		var rel3 := Vector2(st.p.x - c3.x, st.p.y - c3.z)
		var rv3 := st.v - _flat(center_vel(b.index, t))
		if Vector2(rel3.x, rel3.y * TILT).length() < KEEP_R and rv3.length() < CAPTURE + (STICKY if stick == b.index else 0.0):
			return {"kind": &"keep", "body": b.index, "rel": rel3, "rv": rv3, "at": st.p}
	return {}


# ---------------------------------------------------------------- the line
## THE LINE: where you end up if you let go now, run forward on the same step
## (up to 6 s, or the capture), and with a key held a fainter one for keeping it
## held 1.5 s more. The capture it shows changes only once it has held 0.25 s.
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
	line = _run_line(t, {"w": false, "a": false, "s": false, "d": false}, 0.0)
	hold_line = _run_line(t, k, 1.5) if any else {}
	var meet: int = -9
	if not (line.out as Dictionary).is_empty() and line.out.kind != &"star":
		meet = int(line.out.body)
	if meet != _meet_raw:
		_meet_raw = meet
		_meet_t = t
	if t - _meet_t > 0.25:
		sticky = meet


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
		var res := free_step(st, kk, t, hstep, sticky, false)
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
			# SETTLED ROUND THE STAR, here
			out = {"kind": &"star", "body": -1, "r": st.orbit_r, "at": st.p, "t": t, "v": st.v}
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
## THE RIDE ROUND TO THE DEPARTURE POINT: as long as it takes, up to LEAD_MAX;
## further round than that, a phasing burn (prograde, then back) gets it there
## in LEAD_MAX.
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


## A FLIGHT TO PLACE i: the first manoeuvre that is clean -- direct, then round
## a waypoint -- trying coasts of different lengths and both sides of the ring;
## strictly first (under 1,200 px/s and 5,000 px/s²), then only clear. If none
## is, the least bad, marked `unclean` (the measure counts them: none so far).
## WHETHER A FLIGHT CAN START NOW (Jon: "You have to be IN AN ORBIT ... AND
## THEN CLICK to go to another planet"): settled in an orbit -- round a world,
## alongside a station, belt or contact, round the star close in, or on the
## star orbit a ship coasts onto. Not mid-flight, not burning onto an orbit, not
## under thrust or still settling.
## The place a flight under way is taking the ship to (riding round to leave,
## flying, or burning onto its orbit), or -9.
func heading_to() -> int:
	match mode:
		&"fly":
			return fly_to
		&"rail":
			if rail.has("phase"):
				return fly_to
			if inserting():
				return int(rail.body)
		&"keep":
			if inserting():
				return int(keep.body)
	return -9


func can_fly() -> bool:
	match mode:
		&"rail":
			return not rail.is_empty() and not inserting() and not rail.has("phase")
		&"keep":
			return not keep.is_empty() and not inserting()
		&"free":
			return star_orbiting()
	return false


func make_plan(i: int, t: float, prefer: Dictionary = {}) -> FlightPlan:
	var st := _depart_state(t)
	# A PLACE ALREADY CLOSE (Jon: the plan took a lap round the star with the
	# world right beside him): a short hop in the world's own frame
	if i >= 0 and int(st.body) == -9 and not is_keep(i) and (prefer.is_empty() or prefer.get("near", false)):
		var hp := _near_hop(i, t, st, prefer if prefer.get("near", false) else {})
		if hp == null and prefer.get("near", false):
			hp = _near_hop(i, t, st)
		if hp != null:
			return _tail(hp)
	# FROM THE STAR ORBIT TO A WORLD, THE TEXTBOOK WAY (Jon: "the projected orbit
	# path is updating constantly and can create some WEIRD shapes"): ride round
	# to the point half a lap short of where the world will be, then one
	# half-ellipse in (or out), tangent where it leaves
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
	# strictly clean first, at up to 5 s of coast and then 7 (direct, round a
	# waypoint, round a high one); only then merely clear
	# TO THE STAR'S CLOSE ORBIT: the half-ellipse, if it flies clean, before any
	# other shape
	if i < 0:
		var sth := st.duplicate()
		sth["hohmann"] = true
		# from a star orbit or open space, no turn toward the star first: the
		# half-ellipse starts along the way the ship goes (one burn along it), and
		# only a ship going well off that way turns -- toward the ellipse's own way
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
	# FROM A STAR ORBIT OR OPEN SPACE, FIRST THE TEXTBOOK SHAPE: the coast that
	# leaves exactly along the way the ship already goes (one burn along it,
	# faster or slower, no turn first) -- out of a star orbit, a transfer ellipse
	# tangent where it starts (Jon: "one retro burn on the current orbit, a
	# half-ellipse coasting inward")
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
		# THE COAST THAT LEAVES ALONG THE WAY THE SHIP IS GOING, exactly: its
		# length found where the coast's way out crosses the ship's (a transfer
		# tangent where it starts, as out of a circular orbit), tried first
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
					# SWUNG FAR OUT PAST BOTH ENDS (Jon: "the predictive line still goes
					# crazy" -- a retarget round the outside of the whole system): not
					# clean while anything plainer is, bar the waypoint passes that
					# are out there by design
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
	# FROM THE BEST POINT ON THE RING for this place, not from wherever the ship
	# is (Jon: "the predictive path updates every time the ship rotates around
	# the planet"): leaving along the way the transfer goes (out of the star's
	# close orbit, three tenths of a lap short of the place), the escape a sweep
	# round the ring before that, spiralling out; the ship rides round to it
	# first. Angle and radius each a quintic, so it starts with the orbit's own
	# motion and pull.
	if int(st.body) >= -1:
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
		# OUT TO JUST PAST THE RING (the orbit now rides at its edge: the spiral
		# out was sized from the old low orbit, and twice the new one reached
		# far enough to graze the star from an inner world)
		var rxs: Array = [star_ring() + 30.0, star_ring() + 8.0, star_ring() + 70.0] if b < 0 else [L.bodies[b].soi * 1.2, L.bodies[b].soi * 1.05, L.bodies[b].soi * 1.5]
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


## OUT OF OPEN SPACE THE WRONG WAY: when the coast must leave well away from
## the way the ship is going, it first turns round at speed -- its heading
## swinging on a quintic (still at both ends), its speed easing to at least 50
## px/s -- so the plan curves round instead of braking through nought and
## reversing (a cusp). {} when it need not, or the turn would cut a world.
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


## The ride round to the departure point dang radians on at rate w: [how long,
## how hard it phases]. Up to LEAD_MAX it simply rides; further, a burn speeds
## it round (its rate times 1 + (k - 1) sin², which averages to the distance).
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
	# THE COAST'S LENGTH: by how far round and how far across, then stretched
	# (to 5 s at most) until the arc is under about 950 px/s and 4,000 px/s² --
	# taking longer rather than cheating the shape
	var cg := center(i, t1 + 2.0)
	var dth := _pro_angle(p1, cg)
	var dist := Vector2(cg.x - p1.x, cg.z - p1.z).length()
	var T := clampf(1.3 + 0.9 * dth / PI + 0.9 * clampf((dist - 200.0) / 1200.0, 0.0, 1.0), 1.3, 3.2)
	# A REPLAN ARRIVES WHEN THE LAST ONE DID (its choice carries the time): the
	# plan from a moving ship then keeps its shape, where a fresh length each
	# time slid the arrival along the world's orbit
	# (a flight that leaves now, from open space, keeps its coast as long
	# instead: it slides along with the ship)
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
		# WHICH SIDE OF THE WORLD, AND SO WHICH WAY ROUND IT (Jon: "why is this
		# happening sometimes ... it's weirdly shaped"): the side that keeps the
		# coast's own turn going -- the world on the inside of the bend it is
		# already making, so the insertion carries the curve on round instead of
		# overshooting and hooking back the other way. Side 1 is that side, -1
		# the other; a coast that hardly bends keeps the plain order.
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
		# AT THE RING, ALONG IT (side 1 or -1: which way round): the coast comes in
		# tangent to the orbit it will join, so the insertion is an inward spiral;
		# side 0.5 or -0.5 comes in at a slant, for when that will not clear
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
			if din2.length() > 1.0 and absf(cr2) / pow(din2.length(), 3.0) * float(L.bodies[i].soi) * 0.95 > 0.005 and not st.has("abs_side"):
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
	# OUT OF AN ORBIT, THE ESCAPE ENDS WITH THE COAST'S OWN MOTION AND PULL: the
	# spiral rebuilt to finish exactly as the coast starts, so there is no burn
	# blending one into the other (Jon: "a tight wiggle/hook at a burn diamond
	# near the ring before the coast")
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
	# A START THAT WOULD BRAKE THROUGH NOUGHT AND REVERSE (the coast leaving
	# well away from the way the ship goes, out of open space): turn round toward
	# the coast's own way out first, and plan again from there
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
		# THE BURNS AS LONG AS THEIR CHANGE NEEDS (a burn's pull is 4 times its
		# change over its length at the start)
		# (longer and gentler than they were: fewer, softer bends)
		var tb1 := minf(clampf(d1.length() / 350.0, 0.45, 1.3), 0.45 * T2)
		var tb2 := minf(clampf(d2.length() / 350.0, 0.45, 1.3), 0.45 * T2)
		# a burn only where there is one to speak of
		var real1 := d1.length() > 15.0 or e1.length() > 400.0
		var real2 := d2.length() > 15.0 or e2.length() > 400.0
		var pts: PackedVector3Array = lg.pts
		# THE ARRIVAL BURN SLOWS THE SHIP ALONG THE COAST'S OWN CURVE (as seen
		# from the place): the last stretch replayed slower and slower, down to
		# the approach pace, so the path keeps the conic's gentle bend instead of
		# a blend that, at that slow pace, drew a hook (Jon: "a sharp hook into
		# the world"); it takes a little longer
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


## WHERE THE COAST MEETS THE PLACE, relative to it: a world's (or the star's
## close) ring met along it -- side 1 or -1 which way round, 0.5 or -0.5 at a
## slant -- or a station's, belt's or hulk's spot, come up to.
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


## The coast length (as a share of the reference) whose way out from p is the
## way `v` points: scanned from 0.25 to 3, the first crossing bisected; -1 if
## none comes within a radian.
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


## A HOHMANN HALF-ELLIPSE round the star from p (Jon: "going to the star's
## close orbit from the star orbit should be the most textbook manoeuvre in the
## game"): an apsis where it starts, along the ship's own way round (`sense`),
## the other half a lap on at radius `ra` -- tangent at both ends, so one burn
## onto it, the coast speeding up (or slowing) as it falls in (or climbs), one
## burn off it. In the shape `_lam` gives, shown over T.
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


## OUT OF THE STAR ORBIT TO WORLD i: the ship rides round its orbit to the
## departure point (a phasing burn speeds it there when that is far, as out of
## a world's orbit: `_lead`), then a coast that leaves along the orbit, tangent,
## across half a lap to the world -- a Hohmann half-ellipse. The departure is
## chosen once and kept (`prefer` carries its place and time), so the drawn plan
## holds its shape while the ship rides round to it; the ride is the plan's own
## first stretch. Null when no clean one is found.
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
	# the ride's length and its phasing burn for `dang` radians: at the orbit's
	# own pace if that is quick, else sped up -- never past 600 px/s, never
	# longer than 5 s (short of the point, it leaves a little early)
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
		# where it must leave: half a lap short of where the world will be when
		# the coast ends (found three times, the ride's length and the coast's
		# depending on each other)
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
			# MORE THAN HALF A LAP TO RIDE: the world is less than half a lap
			# ahead already -- leave now along the orbit on a shorter arc to it
			# (the coast that leaves tangent), not ride most of the way round
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


## THE SHORT HOP TO A WORLD ALREADY CLOSE (within a little over two of its
## rings): in the world's own frame, from where the ship is and how it moves to
## a point on the ring a little round from it, along the ring -- angle and
## radius each a quintic, so it curves in one way -- and the insertion from
## there. The gentlest of its tries that keeps off the world and the star; null
## if none (or the place is not that close).
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
					if Vector2(q.x, q.z).length() < keep_clear():
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
	# AN ARRIVAL THAT TURNS ONE WAY AND ORBITS THE OTHER (Jon: "why is this
	# happening sometimes"): the coast's last bend against the way round the
	# insertion will go is an overshoot and a hook back -- last of all the clean
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


## THE INSERTION AFTER A PLAN, as it will fly, for drawing the whole flight
## first: made once, for the plan chosen (making it for every try was most of
## the planning's time).
func _tail(pl: FlightPlan) -> FlightPlan:
	if pl == null or not pl.tail.is_empty():
		return pl
	if not pl.choice.is_empty() and pl.end.has("t"):
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
		for k in 13:
			var tk := float(k) * 0.1
			var off := arel + rv * 0.35 * (1.0 - exp(-tk / 0.35))
			var ck := center(i, t2 + tk)
			pl.tail.append(ck + Vector3(off.x, 0.0, off.y))
		return pl
	var rti: float = orbit_r(i)
	var spd: float = STAR_RAIL_V if i < 0 else RAIL_V
	var dr := 1.0 if arel.x * rv.y - arel.y * rv.x >= 0.0 else -1.0
	var ins := insert_plan(arel, rv, rti, dr * spd / rti, null if i < 0 else L.bodies[i], aend)
	pl.tail_k = float(ins.get("kmax", 0.0))
	for k in 121:
		var sk2 := float(k) / 120.0
		var ck2 := center(i, t2 + sk2 * float(ins.T))
		var q2 := _ins_at(ins, sk2, 0)
		pl.tail.append(ck2 + Vector3(q2.x, 0.0, q2.y))
	return pl


## A Lambert coast from r1 to r2 the prograde way, taking T on screen (its true
## time `kf` of the reference): on the plane, integrated in 160 steps and sampled SAMPLE
## apart by cubic Hermite on its own velocities, and its motion at each end in
## screen units. `full` false: only the motions (a probe). Empty if it will not
## solve or close.
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
	var sol := lambert(f1, f2, dth, tof)
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


## The blend shapes: H1 starts with slope 1 and H2 with curvature 1, both with
## everything else nought at both ends -- a burn that blends one motion onto
## another with position, velocity and pull all continuous (C2).
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


## HOW BAD an unclean plan is, as a score (higher is better): how clear it
## keeps of the star's disc and every world's (the least, in px, counted up to
## 20; the ring it leaves and the one it comes to excepted as `_clean` does),
## less a penalty for speed over 1,200 px/s and pull over 5,000 px/s² -- so the
## one flown neither cuts a disc nor jumps.
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


## CLEAN: clear of the star's keep-clear zone and of every world's disc (bar
## the ring it leaves and the one it comes to), and when strict under 1,200
## px/s and 5,000 px/s².
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


func fly(i: int, t: float, done: Callable, prefer: Dictionary = {}) -> FlightPlan:
	plan = make_plan(i, t, prefer)
	# A KEPT CHOICE THAT NO LONGER STARTS WHERE THE SHIP IS (made for another
	# moment): planned afresh, so the flight never jumps
	if plan != null and not prefer.is_empty() and plan.lead <= 0.0 and not plan.samp.is_empty():
		var w0 := where3()
		if Vector2(plan.samp[0].x - w0.x, plan.samp[0].z - w0.z).length() > 3.0:
			if why:
				print("  kept plan starts %.0f px from the ship: planned afresh" % Vector2(plan.samp[0].x - w0.x, plan.samp[0].z - w0.z).length())
			plan = make_plan(i, t)
	if plan == null:
		return null
	# OUT OF AN ORBIT the ship rides round it to the departure point first (a
	# phasing burn if that is far), then the flight
	if plan.lead > 0.0 and mode == &"rail" and not rail.is_empty():
		rail.phase = {"t0": t, "T": plan.lead, "k": plan.lead_k, "a0": float(rail.ang),
			"w": float(rail.dir) * float(rail.speed) / float(rail.rt)}
		fly_to = i
		_fly_done = done
		line = {}
		hold_line = {}
		return plan
	fly_t0 = t
	fly_to = i
	_fly_done = done
	_fly_pos = plan.pos(0.0)
	mode = &"fly"
	rail = {}
	keep = {}
	line = {}
	hold_line = {}
	return plan


## THE COAST DONE, at the ring with the place's own motion: the insertion (or
## the stop alongside) every capture flies, and the flight's callback once it is
## on the orbit.
func _land(t: float) -> void:
	var e := plan.end
	var i: int = e.body
	var p: Vector3 = e.p
	f.p = Vector2(p.x, p.z)
	f.v = Vector2((e.v as Vector3).x, (e.v as Vector3).z)
	var c := center(i, t)
	var rel := Vector2(p.x - c.x, p.z - c.z)
	var rv := f.v - _flat(center_vel(i, t))
	if e.get("keep", false):
		mode = &"keep"
		keep = {"body": i, "off": rel, "ev": rv, "ev0": rv.length()}
	else:
		start_rail(i, rel, rv, t, e.get("a", Vector2.ZERO))
	plan = null


## On the orbit (or alongside) at the end of a flight: what it was flown for.
func _arrived() -> void:
	if _fly_done.is_valid():
		var d := _fly_done
		_fly_done = Callable()
		d.call()


# ---------------------------------------------------------------- the transfer orbit
static func _stc(z: float) -> float:
	if z > 1e-6:
		var s := sqrt(z)
		return (1.0 - cos(s)) / z
	if z < -1e-6:
		var s := sqrt(-z)
		return (cosh(s) - 1.0) / -z
	return 0.5


static func _sts(z: float) -> float:
	if z > 1e-6:
		var s := sqrt(z)
		return (s - sin(s)) / (s * s * s)
	if z < -1e-6:
		var s := sqrt(-z)
		return (sinh(s) - s) / (s * s * s)
	return 1.0 / 6.0


## LAMBERT'S PROBLEM by universal variables (mu 1): the conic from r1 to r2
## sweeping dth in time tof; [v1, v2], or [] when it has none.
static func lambert(r1v: Vector3, r2v: Vector3, dth: float, tof: float) -> Array:
	var r1 := r1v.length()
	var r2 := r2v.length()
	var A := sin(dth) * sqrt(r1 * r2 / (1.0 - cos(dth)))
	var zhi := 4.0 * PI * PI - 1e-3
	# THE TIME RISES WITH z wherever the conic exists (y > 0), so: where it
	# starts to exist, by a coarse step up and a bisection of the edge, then a
	# bisection to the time (about 70 evaluations; it scanned 450)
	var lo := -100.0
	var tlo := _tof(lo, r1, r2, A)
	if is_nan(tlo):
		var prev := lo
		var found := false
		for j in range(1, 41):
			var z := -100.0 + (zhi + 100.0) * j / 40.0
			if not is_nan(_tof(z, r1, r2, A)):
				var bad := prev
				var good := z
				for _e in 24:
					var mz := (bad + good) / 2.0
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
			return []
	var hi := zhi
	var thi := _tof(hi, r1, r2, A)
	if is_nan(thi) or tlo > tof or thi < tof:
		return []
	for _it in 46:
		var m := (lo + hi) / 2.0
		var tm := _tof(m, r1, r2, A)
		if is_nan(tm) or tm < tof:
			lo = m
		else:
			hi = m
	var best := (lo + hi) / 2.0
	if is_nan(best):
		return []
	var y := r1 + r2 + A * (best * _sts(best) - 1.0) / sqrt(_stc(best))
	var fl := 1.0 - y / r1
	var g := A * sqrt(y)
	var gd := 1.0 - y / r2
	if absf(g) < 1e-9:
		return []
	return [(r2v - r1v * fl) / g, (r2v * gd - r1v) / g]


static func _tof(z: float, r1: float, r2: float, A: float) -> float:
	var y := r1 + r2 + A * (z * _sts(z) - 1.0) / sqrt(_stc(z))
	if not (y > 0.0):
		return NAN
	return pow(y / _stc(z), 1.5) * _sts(z) + A * sqrt(y)


static func _acc(p: Vector3) -> Vector3:
	var d := p.length()
	return -p / (d * d * d)
