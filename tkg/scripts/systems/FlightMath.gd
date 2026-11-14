class_name FlightMath
extends RefCounted

## The flight solver's pure static math: the cubic burn, the Hermite step, a ring's speed on a
## flight's clock. No instance state, so `FlightSolve` calls it from a worker thread as before.
## Why: docs/why/FlightSolve.md#autopilot-flight-solver


## The least distance to (ox, oz) over one step, on the cubic through its ends
## (a golden-section search where the step passes its closest).
static func step_min(x0: float, z0: float, vx0: float, vz0: float, x1: float, z1: float, vx1: float, vz1: float, h: float, ox: float, oz: float) -> float:
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
			var xc := herm(x0, vx0, x1, vx1, h, c) - ox
			var zc := herm(z0, vz0, z1, vz1, h, c) - oz
			var xd := herm(x0, vx0, x1, vx1, h, d) - ox
			var zd := herm(z0, vz0, z1, vz1, h, d) - oz
			if xc * xc + zc * zc < xd * xd + zd * zd:
				b = d
			else:
				a = c
		var u := 0.5 * (a + b)
		var xm := herm(x0, vx0, x1, vx1, h, u) - ox
		var zm := herm(z0, vz0, z1, vz1, h, u) - oz
		best = minf(best, sqrt(xm * xm + zm * zm))
	return best


static func herm(p0: float, v0: float, p1: float, v1: float, h: float, u: float) -> float:
	var u2 := u * u
	var u3 := u2 * u
	return (2.0 * u3 - 3.0 * u2 + 1.0) * p0 + (u3 - 2.0 * u2 + u) * h * v0 + (-2.0 * u3 + 3.0 * u2) * p1 + (u3 - u2) * h * v1


static func hermd(p0: float, v0: float, p1: float, v1: float, h: float, u: float) -> float:
	var u2 := u * u
	return ((6.0 * u2 - 6.0 * u) * p0 + (3.0 * u2 - 4.0 * u + 1.0) * h * v0 + (-6.0 * u2 + 6.0 * u) * p1 + (3.0 * u2 - 2.0 * u) * h * v1) / h


## Looks for the least pull first, since the feasible window is a few percent wide.
## Doubling out from 0.05 s stepped over it and made every burn three times the least.
## Why: docs/why/FlightSolve.md#cubic-burn
static func cubic_burn(dxx: float, dxz: float, dux: float, duz: float, pk: float = FlightSolve.THRUST) -> PackedFloat64Array:
	var du := sqrt(dux * dux + duz * duz)
	var lb := maxf(du / pk, 1e-3)
	var d := -1.0
	var pl := peak(dxx, dxz, dux, duz, lb)
	if pl <= pk:
		d = lb
	else:
		# near the least: the lowest peak, golden section on [lb, 1.5 lb], where
		# it falls to a point and then rises
		var a := lb
		var b := 1.5 * lb
		var gr := 0.6180339887498949
		var c := b - gr * (b - a)
		var e := a + gr * (b - a)
		var fc := peak(dxx, dxz, dux, duz, c)
		var fe := peak(dxx, dxz, dux, duz, e)
		for _i in 18:
			if fc < fe:
				b = e
				e = c
				fe = fc
				c = b - gr * (b - a)
				fc = peak(dxx, dxz, dux, duz, c)
			else:
				a = c
				c = e
				fc = fe
				e = a + gr * (b - a)
				fe = peak(dxx, dxz, dux, duz, e)
		var dm := c if fc < fe else e
		var pm := minf(fc, fe)
		if pm <= pk:
			# the least that holds, between lb (over) and dm
			var lo := lb
			var hi := dm
			for _i in 20:
				var m := 0.5 * (lo + hi)
				if peak(dxx, dxz, dux, duz, m) > pk:
					lo = m
				else:
					hi = m
			d = hi
		elif pm <= pk * (1.0 + FlightSolve.BURN_TOL):
			d = dm
		else:
			var lo2 := 1.5 * lb
			var hi2 := 1.5 * lo2
			while peak(dxx, dxz, dux, duz, hi2) > pk:
				lo2 = hi2
				hi2 *= 1.5
				if hi2 > 64.0:
					return PackedFloat64Array()
			for _i in 22:
				var m2 := 0.5 * (lo2 + hi2)
				if peak(dxx, dxz, dux, duz, m2) > pk:
					lo2 = m2
				else:
					hi2 = m2
			d = hi2
	return PackedFloat64Array([d, cubic_work(dxx, dxz, dux, duz, d)])


static func peak(dxx: float, dxz: float, dux: float, duz: float, d: float) -> float:
	var ax := 6.0 * dxx - 2.0 * dux * d
	var az := 6.0 * dxz - 2.0 * duz * d
	var bx := 4.0 * dux * d - 6.0 * dxx
	var bz := 4.0 * duz * d - 6.0 * dxz
	return maxf(sqrt(ax * ax + az * az), sqrt(bx * bx + bz * bz)) / (d * d)


## Closed form for the work: Simpson on four steps read 1.167 |du| where it is 1.25.
## Why: docs/why/FlightSolve.md#cubic-burn
static func cubic_work(dxx: float, dxz: float, dux: float, duz: float, d: float) -> float:
	var px := (6.0 * dxx - 2.0 * dux * d) / (d * d)
	var pz := (6.0 * dxz - 2.0 * duz * d) / (d * d)
	var qx := (4.0 * dux * d - 6.0 * dxx) / (d * d) - px
	var qz := (4.0 * duz * d - 6.0 * dxz) / (d * d) - pz
	var A := qx * qx + qz * qz
	var C := px * px + pz * pz
	if A < 1e-18:
		return sqrt(C) * d
	var B := px * qx + pz * qz
	var w0 := B / A
	var w1 := 1.0 + w0
	var k2 := maxf(C / A - w0 * w0, 0.0)
	return d * sqrt(A) * (half_hyp(w1, k2) - half_hyp(w0, k2))


## The integral of sqrt(w^2 + k2) from 0 to w.
static func half_hyp(w: float, k2: float) -> float:
	var s := sqrt(w * w + k2)
	if k2 < 1e-24:
		return 0.5 * w * absf(w)
	var k := sqrt(k2)
	var x := absf(w) / k
	var ash := log(x + sqrt(x * x + 1.0))
	return 0.5 * (w * s + k2 * (ash if w >= 0.0 else -ash))


## A ring's speed v (px/s, signed) on a flight's clock at pace k (`RING_TAU`).
static func tau_speed(v: float, k: float) -> float:
	if k == 1.0:
		return v
	var a := absf(v)
	return signf(v) * minf(a, maxf(a / k, FlightSolve.ring_floor()))


## THE SHAPE OF A FLIGHT from its samples: [bend, turn] -- the farthest a
## sample strays from the straight line between its two ends over that line's
## length, and how far its motion turns in all (deg), read every 8th sample.
static func shape_of(samp: PackedVector3Array) -> PackedFloat64Array:
	var n := samp.size()
	if n < 3:
		return PackedFloat64Array([0.0, 0.0])
	var a := Vector2(samp[0].x, samp[0].z)
	var b := Vector2(samp[n - 1].x, samp[n - 1].z)
	var ch := (b - a).length()
	var far := 0.0
	var turn := 0.0
	var pv := Vector2.ZERO
	var step := maxi(1, n / 400)
	for j in range(0, n, step):
		var q := Vector2(samp[j].x, samp[j].z)
		if ch > 1e-6:
			far = maxf(far, absf((b - a).cross(q - a)) / ch)
		if j + step < n:
			var v := Vector2(samp[j + step].x - samp[j].x, samp[j + step].z - samp[j].z)
			if pv != Vector2.ZERO and v.length() > 1e-6:
				turn += absf(pv.angle_to(v))
			if v.length() > 1e-6:
				pv = v
	return PackedFloat64Array([far / maxf(ch, 1e-6), rad_to_deg(turn)])


## The ride dang radians round at rate w (> 0): [lead, phasing k]
## (`ShipFlight._lead`'s law: up to FlightSolve.LEAD_MAX it simply rides).
static func lead_of(dang: float, w: float) -> PackedFloat64Array:
	var nat := dang / w
	if nat <= FlightSolve.LEAD_MAX:
		return PackedFloat64Array([nat, 1.0])
	return PackedFloat64Array([FlightSolve.LEAD_MAX, 1.0 + 2.0 * (dang / (w * FlightSolve.LEAD_MAX) - 1.0)])


## (NAN, a missing number, is never near)
static func near(a: Variant, b: float) -> bool:
	return absf(float(a) - b) <= 1e-9


static func warm_slack(j: float) -> float:
	return maxf(FlightSolve.WARM_ADD, FlightSolve.WARM_K * j)
