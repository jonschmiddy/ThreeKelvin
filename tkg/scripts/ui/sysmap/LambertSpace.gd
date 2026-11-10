class_name LambertSpace
extends RefCounted

## Lambert's problem on Vector3s (mu 1), for today's planner in `ShipFlight` (moved out of it
## whole, Nov 10: that file is at its length cap). `solve` was `ShipFlight.lambert`.


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
static func solve(r1v: Vector3, r2v: Vector3, dth: float, tof: float) -> Array[Vector3]:
	var r1 := r1v.length()
	var r2 := r2v.length()
	var A := sin(dth) * sqrt(r1 * r2 / (1.0 - cos(dth)))
	var zhi := 4.0 * PI * PI - 1e-3
	# Time rises with z wherever the conic exists, so find its edge then bisect to the time.
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
	var out: Array[Vector3] = [(r2v - r1v * fl) / g, (r2v * gd - r1v) / g]
	return out


static func _tof(z: float, r1: float, r2: float, A: float) -> float:
	var y := r1 + r2 + A * (z * _sts(z) - 1.0) / sqrt(_stc(z))
	if not (y > 0.0):
		return NAN
	return pow(y / _stc(z), 1.5) * _sts(z) + A * sqrt(y)
