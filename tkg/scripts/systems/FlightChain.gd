class_name FlightChain
extends RefCounted

## The flight in two legs, where one leaves nothing: the first aimed at a waypoint in open
## space, the second off its coast. `FlightSolve.solve` asks for it by `chain` / `chain_again`.
## Why: docs/why/FlightSolve.md#flights-in-two-legs

## Last resort in a twin: the ship flies via an open-space point so it never stops there.
## Needed for far-side targets that no departure burn and one coast reaches.
## Why: docs/why/FlightSolve.md#flights-in-two-legs
const CHAIN_PRE := [0.5, 3.0, 6.0]
const CHAIN_AFTER := 0.5
const CHAIN_T := 15.0
const CHAIN_R := [1.0, 0.7]
const CHAIN_CLEAR := 1.5
const CHAIN_EDGE := 0.95

## Round one sun, a target behind the ship's motion: one burn turned past a right angle
## runs the speed down to a cusp, so `_turn_waypoints` goes two legs. The bearing past which (rad):
## Why: docs/why/FlightChain.md#turn-around-waypoints
const BEHIND := PI * 0.5
## the first leg's turn off the motion, each tried in turn (rad)
const LEG1_TURN := [PI * 110.0 / 180.0, PI * 95.0 / 180.0, PI * 80.0 / 180.0]
## the waypoint's half-angle at the ship at most (rad): past it the apex runs far off
const PHI_MAX := PI * 70.0 / 180.0
## the ship this slow (px/s, the flight's clock) has no way to turn round from
const V_MIN := 2.0 * FlightSolve.V_CUSP


# ---------------------------------------------------------------- a flight in two legs
# The second leg leaves free off the first's coast, so the ship never stops at the waypoint.
# With a hint, the flight through it is kept only if a fresh one arrives no sooner.
# Why: docs/why/FlightSolve.md#flights-in-two-legs
static func chain(G: MapGravity, dep: Dictionary, tgt: Dictionary, t: float, hint: Vector2) -> FlightSolve.Result:
	var rh: FlightSolve.Result = null
	if hint.is_finite():
		rh = _chain_try(G, dep, tgt, t, hint, CHAIN_PRE)
	for W in _waypoints(G, dep, tgt, t):
		var rj := _chain_try(G, dep, tgt, t, W, CHAIN_PRE)
		if rj != null:
			if rh == null:
				return rj
			var keep := rh if float(rh.end.t) <= float(rj.end.t) + 1e-6 else rj
			keep.integrations = rh.integrations + rj.integrations
			keep.steps = rh.steps + rj.steps
			return keep
	return rh


## The flight in two legs through W, its second leaving `pres` s (each in
## turn) before the first's arrival burn: null when none is found and clean.
static func _chain_try(G: MapGravity, dep: Dictionary, tgt: Dictionary, t: float, W: Vector2, pres: Array) -> FlightSolve.Result:
	var l1 := FlightSolve.new()
	l1._leg = 1
	l1._wide_ok = false
	var r1 := l1._solve(G, dep, _wp_target(W), t, {})
	if not r1.found or not r1.clean:
		return null
	var tried := -1
	for pre: float in pres:
		# (each cut once: one past the first's departure burn stands for all
		# before it)
		var k := _cut_k(r1, pre)
		if k == tried:
			continue
		tried = k
		var rj := _leg_two(G, l1, r1, tgt, t, W, pre, k, {})
		if rj != null:
			return rj
	return null


## The sample of the first leg its second leaves from, `pre` s before the
## first's arrival burn and at least CHAIN_AFTER after its departure burn.
static func _cut_k(r1: FlightSolve.Result, pre: float) -> int:
	var tb := r1.t0 + r1.dur - r1.d2
	return floori((maxf(tb - pre, r1.t0 + r1.esc_t + CHAIN_AFTER) - r1.t0) / FlightSolve.SAMPLE)


## A keep target at the fixed point W.
static func _wp_target(W: Vector2) -> Dictionary:
	return {"kind": &"keep", "place": -9, "c": W, "off": Vector2.ZERO}


## The second leg off the first, joined into one flight, with `c2` to rebuild it from.
static func _leg_two(G: MapGravity, l1: FlightSolve, r1: FlightSolve.Result, tgt: Dictionary, t: float, W: Vector2, pre: float, k_fix: int, c2: Dictionary) -> FlightSolve.Result:
	var tb := r1.t0 + r1.dur - r1.d2
	var k := k_fix if k_fix >= 0 else _cut_k(r1, pre)
	if k < 1 or k >= r1.samp.size() - 1 or r1.t0 + float(k) * FlightSolve.SAMPLE > tb - FlightSolve.SAMPLE:
		return null
	var tc := r1.t0 + float(k) * FlightSolve.SAMPLE
	var st := l1._coast_at(tc)
	var l2 := FlightSolve.new()
	l2._leg = 2
	l2._wide_ok = false
	var d2 := {"kind": &"free", "p": Vector2(st[0], st[1]), "v": Vector2(st[2], st[3]), "_pace": l1._kp}
	var r2 := l2._solve(G, d2, tgt, tc, c2)
	if not r2.found or not r2.clean:
		return null
	return _join(r1, k, r2, t, W, tb - tc)


## The two legs as one flight: the first's samples up to k, then the second's.
static func _join(r1: FlightSolve.Result, k: int, r2: FlightSolve.Result, t: float, W: Vector2, pre: float) -> FlightSolve.Result:
	var res := FlightSolve.Result.new()
	res.found = true
	res.clean = r1.clean and r2.clean
	res.kind = &"replay" if r1.kind == &"replay" and r2.kind == &"replay" else &"solved"
	res.legs = 2
	res.wp = W
	res.k_cut = k
	res.t_cut = r1.t0 + float(k) * FlightSolve.SAMPLE
	res.t0 = r1.t0
	res.lead = r1.lead
	res.lead_k = r1.lead_k
	res.a_dep = r1.a_dep
	res.sdt = FlightSolve.SAMPLE
	res.samp = r1.samp.slice(0, k)
	res.samp.append_array(r2.samp)
	res.burns = r1.burns.slice(0, k)
	res.burns.append_array(r2.burns)
	var n := res.samp.size() - 1
	res.dur = float(n) * FlightSolve.SAMPLE
	var amax := 1.0
	for j in range(1, n, 2):
		amax = maxf(amax, (res.samp[j + 1] - 2.0 * res.samp[j] + res.samp[j - 1]).length() / (FlightSolve.SAMPLE * FlightSolve.SAMPLE))
	res.amax = amax
	res.esc_t = r1.esc_t
	res.end = r2.end.duplicate()
	res.dvp = r1.dvp
	res.dv1 = r1.dv1
	res.dv2 = r2.dv2
	res.work = r1.dvp + r1.dv1 + r2.dv1 + r2.dv2
	res.arr_const = r2.arr_const
	res.d2 = r2.d2
	res.T = float(r2.end.t) - t
	res.cost = res.work + FlightSolve.TIME_W * res.T
	res.priced = res.cost
	res.clear = minf(r1.clear, r2.clear)
	res.integrations = r1.integrations + r2.integrations
	res.steps = r1.steps + r2.steps
	res.choice = r1.choice.duplicate()
	res.choice.J = res.cost
	res.choice.chain = {"W": W, "k": k, "pre": pre, "c1": r1.choice, "c2": r2.choice}
	return res


## Rebuilt from its choice while kept, else null so the caller looks again.
## Why: docs/why/FlightSolve.md#flights-in-two-legs
static func chain_again(G: MapGravity, dep: Dictionary, tgt: Dictionary, t: float, c: Dictionary) -> FlightSolve.Result:
	var ch: Dictionary = c.chain
	var W: Vector2 = ch.get("W", Vector2.INF)
	if not W.is_finite():
		return null
	var l1 := FlightSolve.new()
	l1._leg = 1
	l1._wide_ok = false
	var r1 := l1._solve(G, dep, _wp_target(W), t, ch.get("c1", {}))
	if not r1.found or not r1.clean:
		return null
	var same := r1.kind == &"replay"
	var rj := _leg_two(G, l1, r1, tgt, t, W, float(ch.get("pre", 0.0)), int(ch.get("k", -1)) if same else -1, ch.get("c2", {}))
	if rj == null:
		return null
	if rj.kind == &"replay":
		return rj
	rj.kind = &"warm"
	var j_old := float(c.get("J", INF))
	if rj.cost > j_old + FlightSolve._warm_slack(j_old):
		return null
	return rj


## Waypoints round the balance point, best first, kept clear of the suns and the map's edge.
static func _waypoints(G: MapGravity, dep: Dictionary, tgt: Dictionary, t: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var fs := FlightSolve.new()
	fs.G = G
	fs.t_now = t
	if G.star_x0.size() < 2 or not fs._setup_in(dep, tgt):
		return _turn_waypoints(G, dep, tgt, t) if G.star_x0.size() == 1 else out
	var pd := fs._dep_pos(t)
	var pt := fs.target_point(t + CHAIN_T)
	var c := G.bary
	var qd := pd - c
	var qt := pt - c
	var gap := wrapf(qt.angle() - qd.angle(), -PI, PI)
	# (the suns' distance apart at t 0: a turning pair is rigid, so it is the
	# same at every t, as the balance point is where it is)
	var sep := Vector2(G.star_x0[1] - G.star_x0[0], G.star_z0[1] - G.star_z0[0]).length()
	var e := CHAIN_EDGE * G.edge
	for way in 2:
		var a := qd.angle() + (gap if way == 0 else gap - signf(gap) * TAU) * 0.5
		var u := Vector2(cos(a), sin(a))
		# (as far out as the map allows along u: |c + u r| = e)
		var cu := c.dot(u)
		var r_hi := -cu + sqrt(maxf(cu * cu - c.length_squared() + e * e, 0.0))
		for rk: float in CHAIN_R:
			var r := clampf(maxf(qd.length(), qt.length()) * rk, CHAIN_CLEAR * sep, r_hi)
			out.append(c + u * r)
	return out


## Waypoints for a target behind the ship's motion, best first; none otherwise. Each is the
## apex of the isosceles triangle on the ship-to-target line, on the motion's side, so the
## first leg turns by LEG1_TURN and the second by twice the apex's half-angle.
static func _turn_waypoints(G: MapGravity, dep: Dictionary, tgt: Dictionary, t: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	if G.star_x0.size() != 1:
		return out
	var fs := FlightSolve.new()
	fs.G = G
	fs.t_now = t
	if not fs._setup_in(dep, tgt):
		return out
	var pd := fs._dep_pos(t)
	var v := fs.departure_velocity(t)
	var pt := fs.target_point(t + CHAIN_T)
	var line := pt - pd
	if v.length() < V_MIN or line.length() < 1.0:
		return out
	var th := v.angle_to(line)
	if absf(th) <= BEHIND:
		return out
	# (rotating the line toward the motion by phi: the first leg's turn is |th| - phi)
	var side := signf(th)
	var star := Vector2(G.star_x0[0], G.star_z0[0])
	var keep := G.star_keep[0] * CHAIN_CLEAR
	var e := CHAIN_EDGE * G.edge
	for t1: float in LEG1_TURN:
		var phi := absf(th) - t1
		if phi <= 0.0 or phi > PHI_MAX:
			continue
		var W := pd + line.rotated(-side * phi) * (0.5 / cos(phi))
		if W.length() > e or W.distance_to(star) < keep:
			continue
		out.append(W)
	return out
