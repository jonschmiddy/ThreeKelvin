class_name LambertPlane
extends RefCounted

## Lambert's problem in 64-bit scalars on the map plane, for `FlightSolve`'s conic guesses
## (moved out of it whole, Nov 10: that file is at its length cap). `solve` was `FlightSolve.lambert`.


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


## Lambert's problem in 64-bit scalars, as `LambertSpace.solve`'s Vector3 inputs are 32-bit.
static func solve(r1x: float, r1z: float, r2x: float, r2z: float, dth: float, tof: float) -> PackedFloat64Array:
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
