class_name FlightPick
extends RefCounted

## Which flight is flown where more than one is planned: a solve's one leg or two
## (`FlightChain`), a held two-leg flight against a fresh plan, the sooner of two.
## Moved out of FlightSolve (Nov 22) to hold its size.
## Why: docs/why/FlightSolve.md#sooner-of-two-plans


## (the search on the flight's own clock: dep, tgt and t already in tau)
static func solve_tau(grav: MapGravity, dep: Dictionary, tgt: Dictionary, t: float, prefer: Dictionary = {}) -> FlightSolve.Result:
	if grav.star_x0.size() > 1 or prefer.has("chain") or prefer.has("alt"):
		var held := StringName(dep.get("kind", &"")) != &"free"
		if prefer.has("chain"):
			# A held two-leg flight is kept only while a fresh plan finds none arriving sooner.
			# Why: docs/why/FlightSolve.md#two-leg-replans
			var t_us := Time.get_ticks_usec()
			var rc := FlightChain.chain_again(grav, dep, tgt, t, prefer)
			if rc == null:
				var ch: Dictionary = prefer.chain
				rc = solve_or_chain(grav, dep, tgt, t, {}, ch.get("W", Vector2.INF))
			elif held:
				rc = sooner_of(rc, solve_or_chain(grav, dep, tgt, t, {}, Vector2.INF))
			rc.usec = Time.get_ticks_usec() - t_us
			return rc
		if prefer.has("alt") and held:
			# Old legs are tried beside the warm plan, and where they beat it, beside a fresh one.
			# Why: docs/why/FlightSolve.md#two-leg-replans
			var t_ua := Time.get_ticks_usec()
			var c1 := prefer.duplicate()
			c1.erase("alt")
			var ra := FlightChain.chain_again(grav, dep, tgt, t, prefer.alt)
			var r := solve_or_chain(grav, dep, tgt, t, c1, Vector2.INF)
			if ra != null:
				var rk := sooner_of(ra, r)
				r = rk if rk != ra else sooner_of(ra, solve_or_chain(grav, dep, tgt, t, {}, Vector2.INF))
			r.usec = Time.get_ticks_usec() - t_ua
			return r
	return solve_or_chain(grav, dep, tgt, t, prefer, Vector2.INF)


## Held legs lose to a fresh plan that arrives sooner, or a preview stayed slow in two legs.
## Why: docs/why/FlightSolve.md#sooner-of-two-plans
static func sooner_of(rc: FlightSolve.Result, r1: FlightSolve.Result) -> FlightSolve.Result:
	var n := rc.integrations + r1.integrations
	var st := rc.steps + r1.steps
	var out := rc
	if r1.found and r1.clean and float(r1.end.t) < float(rc.end.t) - 1e-6:
		out = r1
		if r1.legs == 1:
			out.choice = r1.choice.duplicate()
			out.choice.alt = rc.choice
	out.integrations = n
	out.steps = st
	return out


## The flight of one leg; where none is found, of two (`FlightChain.chain`, a twin's or round one sun;
## `hint` its first point tried first).
static func solve_or_chain(grav: MapGravity, dep: Dictionary, tgt: Dictionary, t: float, prefer: Dictionary, hint: Vector2) -> FlightSolve.Result:
	var fs := FlightSolve.new()
	var r := fs.solve_here(grav, dep, tgt, t, prefer)
	if r.found and fs.kept_alone():
		# A kept fallback flight is weighed against two legs too, as a fresh plan finds them.
		# Why: docs/why/FlightSolve.md#fallback-kept-by-arrival
		var t_k := Time.get_ticks_usec()
		var rk := FlightChain.chain(grav, dep, tgt, t, hint)
		if rk != null:
			var u := r.usec + Time.get_ticks_usec() - t_k
			r = sooner_of(r, rk)
			r.usec = u
		return r
	if r.found or not fs.was_set():
		return r
	var t_us := Time.get_ticks_usec()
	var rc := FlightChain.chain(grav, dep, tgt, t, hint)
	if rc == null:
		r.usec += Time.get_ticks_usec() - t_us
		return r
	rc.integrations += r.integrations
	rc.steps += r.steps
	rc.usec = r.usec + Time.get_ticks_usec() - t_us
	return rc
