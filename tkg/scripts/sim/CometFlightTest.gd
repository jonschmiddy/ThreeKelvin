extends Node

## The comet's spots as flights (Phase 13, `CometCatch`): from every world's orbit as the comet
## comes in, planned to each spot, and one in four flown. FlightTest is not touched.
## Why: docs/why/CometFlightTest.md#comet-flight-test

const ShipFlightS := preload("res://scripts/ui/sysmap/ShipFlight.gd")
const CatchS := preload("res://scripts/ui/sysmap/CometCatch.gd")
const SEEDS := [4242, 7, 1999, 31337]
## comet systems a seed, at most (`systems=N`)
const SYSTEMS := 25
## Found and clean in at least this share (FlightTest's own FOUND_MIN).
const FOUND_MIN := 0.99
## settled this close to the spot, and held this close for HOLD_S (plane px)
const END_PX := 0.5
const HOLD_S := 3.0
## flown this long at most (s)
const FLY_MAX := 45.0
const NONE := {"w": false, "a": false, "s": false, "d": false}

var h := Harness.new()


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	CometPath._force = 1
	var cap := int(Harness.arg("systems", str(SYSTEMS)))
	var you: Array = [[], [], []]
	var cases := 0
	var found := 0
	var made: Array[int] = [0, 0, 0]
	var tried: Array[int] = [0, 0, 0]
	var flown := 0
	var bad: Array[String] = []
	var worst_end := 0.0
	var worst_hold := 0.0
	var worst_meet := 0.0
	var least_clear := INF
	var ms: Array = []
	var n_sys := 0
	for sd: int in SEEDS:
		Rng.forced = sd
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
		var k_sys := 0
		for raw in Run.map:
			var n: MapGen.MapNode = raw
			if k_sys >= cap:
				break
			if n.type != MapGen.NodeType.SYSTEM:
				continue
			OptionTable.ensure(n)
			var L := SystemLayout.of(n)
			var c := L.comet
			if c == null:
				continue
			k_sys += 1
			n_sys += 1
			var t0 := c.t_in
			for b in L.bodies.size():
				if L.bodies[b].world == &"":
					continue
				for k in 3:
					if c.spot_in(k, t0) <= 0.0:
						continue
					var fl = ShipFlightS.new()
					fl.setup(L, Vector2(L.edge, -210.0), t0)
					fl.place_at(b, t0)
					var R := RandomNumberGenerator.new()
					R.seed = sd * 131 + n.index * 7 + b * 3 + k
					fl.rail.ang = R.randf() * TAU
					fl.step(1.0 / 60.0, t0, NONE)
					if not fl.can_fly():
						continue
					cases += 1
					tried[k] += 1
					var o: Dictionary = fl.flight_opts()
					var dep: Dictionary = fl._dep_of(t0, 0.0)
					var r := FlightSolve.solve(fl._grav_at(float(o.pace)), dep, CatchS.target(L, c, k), t0, {}, o)
					ms.append(float(r.usec) / 1000.0)
					if not (r.found and r.clean):
						bad.append("seed %d system %d world %d spot %d: found %s clean %s" % [sd, n.index, b, k, r.found, r.clean])
						continue
					found += 1
					var y := float(r.end.t) - t0
					(you[k] as Array).append(y)
					if y + CatchS.MARGIN < c.spot_in(k, t0):
						made[k] += 1
					if cases % 4 != 0:
						continue
					var got := _fly(fl, L, c, k, r, dep, t0)
					flown += 1
					worst_end = maxf(worst_end, float(got.end))
					worst_hold = maxf(worst_hold, float(got.hold))
					worst_meet = maxf(worst_meet, float(got.meet))
					least_clear = minf(least_clear, float(got.clear))
					if not bool(got.settled):
						bad.append("seed %d system %d world %d spot %d: flown, never settled" % [sd, n.index, b, k])
	CometPath._force = 0
	print("\n=== COMET FLIGHTS ===")
	print("  %d comet systems, %d flights planned, %d found and clean, %d flown" % [n_sys, cases, found, flown])
	ms.sort()
	if not ms.is_empty():
		print("  planning, ms: median %.0f, 90th %.0f, worst %.0f" % [ms[ms.size() / 2], ms[int(ms.size() * 0.9)], ms[-1]])
	for k in 3:
		var ys: Array = you[k]
		ys.sort()
		if ys.is_empty():
			continue
		print("  spot %d %s, click to settled, s: median %.2f, 90th %.2f, worst %.2f (%d); made from the moment it comes in: %d of %d" % [k + 1,
			CometPath.SPOT_NAMES[k], ys[ys.size() / 2], ys[int(ys.size() * 0.9)], ys[-1], ys.size(), made[k], tried[k]])
	print("  flown: worst settle %.3f px off the spot, worst hold %.3f px over %.0f s, worst miss of the comet %.3f px, nearest a sun's keep-out %.1f px outside" % [worst_end, worst_hold, HOLD_S, worst_meet, least_clear])
	for line in bad.slice(0, 6):
		print("    " + line)
	var share := float(found) / float(maxi(cases, 1))
	h._ok("every spot flight found and clean in at least %.0f%% (%.3f of %d)" % [FOUND_MIN * 100.0, share, cases], cases > 0 and share >= FOUND_MIN)
	h._ok("every flown spot flight settles on the spot (worst %.3f px) and holds there (worst %.3f px)" % [worst_end, worst_hold], flown > 0 and worst_end <= END_PX and worst_hold <= END_PX)
	h._ok("the comet passes the ship where it waits (worst %.3f px off)" % worst_meet, flown > 0 and worst_meet <= END_PX + 0.5)
	h._ok("no flown spot flight comes inside a sun's keep-out (nearest %.1f px outside)" % least_clear, least_clear >= -FlightSolve.BURN_PAD)
	h.verdict("cometflighttest")
	get_tree().quit(h.code())


## Fly plan r to spot k on the ship's own clock; then hold HOLD_S, and meet the comet there.
func _fly(fl, L: SystemLayout, c: CometPath, k: int, r: FlightSolve.Result, dep: Dictionary, t0: float) -> Dictionary:
	var out := {"settled": false, "end": INF, "hold": 0.0, "meet": INF, "clear": INF}
	var spot := c.spot_at(L, k)
	var done := [false]
	var pv = fl._plan_of(r, -9, dep, t0)
	fl.fly(-9, t0, func() -> void: done[0] = true, {}, pv)
	var dt := 1.0 / 60.0
	var t := t0
	while t - t0 < FLY_MAX and not done[0]:
		t += dt
		fl.step(dt, t, NONE)
		var p: Vector3 = fl.where3()
		for s: int in L.stars():
			out.clear = minf(float(out.clear), Vector2(p.x, p.z).distance_to(L.star_pos(s, t)) - L.keep_clear_of(s))
	if not done[0]:
		return out
	out.settled = true
	out.end = (fl.f.p as Vector2).distance_to(spot)
	var t_hold := t
	while t - t_hold < HOLD_S:
		t += dt
		fl.step(dt, t, NONE)
		out.hold = maxf(float(out.hold), (fl.f.p as Vector2).distance_to(spot))
	out.meet = c.pos(L, c.spot_t(k)).distance_to(spot)
	return out
