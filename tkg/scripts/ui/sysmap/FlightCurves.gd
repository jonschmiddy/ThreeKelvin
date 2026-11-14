class_name FlightCurves
extends RefCounted

## The ship's flight curves, state-free statics moved out of `ShipFlight` whole (Nov 13: that file
## was over its cap): the ride's shape, the insertion's polar and quintic curves, a coast's
## integration and samples. `ShipFlight` keeps its own names for the dials below.

const SPIN_PUSH_K := 3.0
const SPIN_MIN := 0.08
const SAMPLE := 1.0 / 240.0
const LEAD_MAX := 2.2


## Whether a ride round a ring can be flown at pace pk: its push within THRUST (and VMAX) on the map,
## the spin-up's beside the phasing's, and its phasing k no less than `FlightSolve.RIDE_K_MIN`.
## Why: docs/why/ShipFlight.md#ride-flyable
static func ride_flyable(rd: Dictionary, pk: float, vr: float) -> bool:
	var k := float(rd.get("k", 1.0))
	var ke := float(rd.get("ke", 1.0))
	var most := FlightSolve.THRUST * pk * pk * (SPIN_PUSH_K if ke > 1.0 + 1e-6 else 1.0)
	return not (vr * ride_peak(rd) > most + 1e-6 or (maxf(k, 1.0) + ke - 1.0) * vr > FlightSolve.VMAX * pk + 1e-6 or k < FlightSolve.RIDE_K_MIN)


## The ride's shape round to a fast flight's departure: ride at w, spin up over `sp` s, ride on at
## ke w, the spin starting `ls` s before it leaves. Returns {k, ke, ls, sp}.
## Why: docs/why/ShipFlight.md#ride-shape
static func ride_shape(dang: float, w: float, T: float, ke: float) -> Dictionary:
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
static func ride_at(rd: Dictionary, tau: float) -> PackedFloat64Array:
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
static func ride_peak(rd: Dictionary) -> float:
	var T := float(rd.T)
	var p := absf(float(rd.get("k", 1.0)) - 1.0) * PI / T if T > 1e-9 and T < INF else 0.0
	var ke := float(rd.get("ke", 1.0))
	if ke != 1.0:
		p += 1.5 * absf(ke - 1.0) / maxf(float(rd.sp), 1e-6)
	return p


## Built in polar terms so a head-on approach spirals in instead of drawing a hairpin.
## Why: docs/why/ShipFlight.md#insertion-curve
static func polar_ins(p0: Vector2, v0: Vector2, acc0: Vector2, rt: float, w: float, T: float, a1: float) -> Dictionary:
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
static func ins_at(ins: Dictionary, s: float, d: int) -> Vector2:
	var T: float = ins.T
	if ins.get("polar", false):
		var ph := q5(ins.ph, s, 0)
		var r := q5(ins.rr, s, 0)
		var er := Vector2(cos(ph), sin(ph))
		var ep := Vector2(-er.y, er.x)
		if d == 0:
			return er * r
		var p1 := q5(ins.ph, s, 1) / T
		var r1 := q5(ins.rr, s, 1) / T
		if d == 1:
			return er * r1 + ep * r * p1
		var p2 := q5(ins.ph, s, 2) / (T * T)
		var r2 := q5(ins.rr, s, 2) / (T * T)
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


## Ride to the departure point: up to LEAD_MAX it simply rides, further a burn speeds it round.
static func lead(dang: float, w: float) -> Array:
	if w <= 0.0001:
		return [0.0, 1.0]
	var natural := dang / w
	if natural <= LEAD_MAX:
		return [natural, 1.0]
	return [LEAD_MAX, 1.0 + 2.0 * (dang / (w * LEAD_MAX) - 1.0)]


## The waypoint a two-leg coast turns at.
static func waypoint_of(legs: Array) -> Vector3:
	return legs[0][0].get("to", Vector3.ZERO)


## A coast's points, SAMPLE apart, by cubic Hermite between its integrated
## steps on their own velocities; the miss at the end taken out evenly.
static func sample(lg: Dictionary) -> void:
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
static func coast_pv(r: Vector3, v: Vector3, T: float, m: int) -> Array:
	var hh := T / m
	var ps := PackedVector3Array([r])
	var vs := PackedVector3Array([v])
	var x := r
	var u := v
	for _i in m:
		var a1 := acc(x)
		var x2 := x + u * hh / 2.0
		var u2 := u + a1 * hh / 2.0
		var a2 := acc(x2)
		var x3 := x + u2 * hh / 2.0
		var u3 := u + a2 * hh / 2.0
		var a3 := acc(x3)
		var x4 := x + u3 * hh
		var u4 := u + a3 * hh
		var a4 := acc(x4)
		x += (u + 2.0 * u2 + 2.0 * u3 + u4) * hh / 6.0
		u += (a1 + 2.0 * a2 + 2.0 * a3 + a4) * hh / 6.0
		ps.append(x)
		vs.append(u)
	return [ps, vs]


## The angle from r1 round to r2 the way the worlds go (0..TAU).
static func pro_angle(r1: Vector3, r2: Vector3) -> float:
	var base := acos(clampf(Vector2(r1.x, r1.z).normalized().dot(Vector2(r2.x, r2.z).normalized()), -1.0, 1.0))
	return base if r1.x * r2.z - r1.z * r2.x >= 0.0 else TAU - base


## H1 and H2 blend shapes keep position, velocity and pull continuous (C2).
static func h1(x: float) -> float:
	return x - 6.0 * x * x * x + 8.0 * x * x * x * x - 3.0 * pow(x, 5.0)


static func h2(x: float) -> float:
	return 0.5 * x * x - 1.5 * x * x * x + 1.5 * pow(x, 4.0) - 0.5 * pow(x, 5.0)


## A scalar quintic Hermite on s (0..1): c = [x0, x0', x0'', x1, x1', x1''] in s.
static func q5(c: Array, s: float, d: int) -> float:
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


static func acc(p: Vector3) -> Vector3:
	var d := p.length()
	return -p / (d * d * d)
