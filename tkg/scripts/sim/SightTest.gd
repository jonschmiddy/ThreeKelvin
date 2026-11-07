extends Harness

## Prices three screenshot claims about sensor range across seeded galaxies: `-- sighttest`.
## Why: docs/why/SightTest.md#sensor-checks


func run() -> void:
	_ladder()
	_beyond()
	verdict("sighttest")


## Walks the radius multiplier directly: the count depends only on radius and galaxy.
func _ladder() -> void:
	print("\n  === WHAT A RADIUS COVERS ===")
	print("  %-8s %-7s %8s %9s %9s"
		% ["sensors", "mult", "radius", "systems", "vs reach"])
	var reach := Run.JUMP_RADIUS
	for s in [0, 1, 2, 4, 6]:
		var mult: float = Run.SENSE_FLOOR + float(s) * Run.SENSE_REACH
		var r: float = reach * float(mult)
		var total := 0.0
		var n := 0
		for seed_i in [11, 4242, 90210, 31337]:
			Rng.forced = seed_i
			Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
			var here: MapGen.MapNode = Run.node_at()
			var c := 0
			for node in Run.map:
				var t: MapGen.MapNode = node
				if t.index == here.index:
					continue
				if MapGen.hop_distance(here, t) <= r:
					c += 1
			total += float(c)
			n += 1
		print("  %-8d %-7.2f %8.3f %9.1f %9s"
			% [s, mult, r, total / float(n), "%.2fx" % mult])
	# The reach ring barely moves: thrust 6 buys 8%, two or three pixels of ellipse.
	print("\n  === WHAT A THRUSTER BUYS ===")
	print("  %-8s %-7s %8s" % ["thrust", "mult", "radius"])
	for t2 in [2, 4, 6, 8, 14]:
		var m := clampf(1.0 + float(t2 - Run.THRUST_REF) * Run.THRUST_REACH,
			1.0, Run.THRUST_REACH_MAX)
		print("  %-8d %-7.2f %8.3f" % [t2, m, reach * m])


## And what is drawn beyond the dish, after flying.
func _beyond() -> void:
	print("\n  === DRAWN BEYOND SIGHT, AFTER 25 JUMPS ===")
	print("  %-6s %7s %7s %8s   %s" % ["seed", "shown", "sensed", "beyond", "why"])
	for seed_i in [11, 4242]:
		Rng.forced = seed_i
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
		var q: Array[int] = [Run.at]
		var seen := {Run.at: true}
		var done := 0
		while not q.is_empty() and done < 25:
			var i: int = q.pop_front()
			(Run.map[i] as MapGen.MapNode).visited = true
			done += 1
			for j in (Run.map[i] as MapGen.MapNode).links:
				if not seen.has(j):
					seen[j] = true
					q.append(j)
		var here: MapGen.MapNode = Run.node_at()
		Run.chart_from(here)
		var r := Run.sense_radius()
		var shown := 0
		var sensed := 0
		var beyond := 0
		var why: Dictionary = {}
		for node in Run.map:
			var t: MapGen.MapNode = node
			if t.sensed:
				sensed += 1
			var reason := ""
			if t.index == here.index:
				reason = "here"
			elif t.visited:
				reason = "visited"
			elif t.sensed:
				reason = "sensed"
			elif Run.station_heard(t.index):
				reason = "station"
			elif Run.contract_at(t.index) != null:
				reason = "contract"
			# `Run.charted` is the rule; this only names WHICH clause admitted it, for
			# the table. If the two ever disagree the rule wins and this is stale.
			if reason != "" and not Run.charted(t):
				reason = ""
			if reason == "":
				continue
			shown += 1
			if MapGen.hop_distance(here, t) > r:
				beyond += 1
				why[reason] = int(why.get(reason, 0)) + 1
		print("  %-6d %7d %7d %8d   %s"
			% [seed_i, shown, sensed, beyond, JSON.stringify(why)])
	_gap()
	_ok("measured", true)


## Reachable but not sensed shows as NOT ENOUGH FUEL, which cannot be true at 279 fuel.
## Why: docs/why/SightTest.md#reachable-not-sensed
func _gap() -> void:
	print("\n  === REACHABLE BUT NOT SENSED ===")
	print("  %-6s %8s %8s %8s   %s" % ["seed", "inrange", "sensed", "gap", "types"])
	for seed_i in [11, 4242, 90210, 31337]:
		Rng.forced = seed_i
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
		var here: MapGen.MapNode = Run.node_at()
		Run.chart_from(here)
		var inr := Run.in_range()
		var gap := 0
		var kinds: Dictionary = {}
		for n in inr:
			var t: MapGen.MapNode = n
			if t.sensed:
				continue
			gap += 1
			var k := MapGen.type_label(t.type)
			kinds[k] = int(kinds.get(k, 0)) + 1
		var sensed := 0
		for n2 in inr:
			if (n2 as MapGen.MapNode).sensed:
				sensed += 1
		print("  %-6d %8d %8d %8d   %s"
			% [seed_i, inr.size(), sensed, gap, JSON.stringify(kinds)])
