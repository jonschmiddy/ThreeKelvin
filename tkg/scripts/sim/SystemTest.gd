extends Harness

## Does the system map's layout keep its promises?
##   godot --headless --path . -- systemtest
##
## A GATE. `SystemLayout` is derived and never saved, so everything it gets
## wrong is wrong silently: an option with no body is an encounter nobody can
## click, an unstable layout is a planet that moves between a save and a load
## (or sits in two places for two players), and an orbit run through a body is a
## planet drawn on top of another. The five promises:
##
## **Every option is on exactly one body**, a station has its DOCK and the core
## its custodian.
## **Stable**: the same node lays out the same way twice in one run, and the same
## seed lays out the same way in a fresh run.
## **A gas giant if and only if the node has one** (never round a pulsar).
## **Orbits never cross a body**: neighbouring orbits are further apart than the
## two bodies on them are wide.
## **No shared stream is touched**: laying out a system draws only from
## `Rng.derive`, so looking at the map cannot move what the run rolls next.

const SEEDS := [4242, 7, 1999, 31337]


func _print_of(L: SystemLayout) -> String:
	var parts: Array[String] = ["%d" % L.star]
	for b in L.bodies:
		var opts: Array[String] = []
		for bc in b.beacons:
			opts.append("%d%s%s" % [bc.opt, "d" if bc.dock else "", "c" if bc.core else ""])
		parts.append("%s:%s:%.3f:%.3f:%.3f:%s:%.3f[%s]" % [b.kind, b.world, b.orbit, b.period, b.phase, b.name, b.r, ",".join(opts)])
	return "|".join(parts)


func run() -> void:
	var prints := {}
	var n_sys := 0
	var worlds := {}
	var min_gap := INF
	var min_gap_at := ""
	var counts := {}
	for s in SEEDS:
		Rng.forced = s
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
		for raw in Run.map:
			var n: MapGen.MapNode = raw
			var before := JSON.stringify(Rng.state())
			var L := SystemLayout.of(n)
			var L2 := SystemLayout.of(n)
			if JSON.stringify(Rng.state()) != before:
				_fail("laying out system %d moved a shared stream" % n.index)
			var fp := _print_of(L)
			if fp != _print_of(L2):
				_fail("system %d laid out two ways in one run" % n.index)
			prints["%d:%d" % [s, n.index]] = fp
			n_sys += 1
			# every option on exactly one body
			var seen := {}
			for b in L.bodies:
				for bc in b.beacons:
					if bc.opt >= 0:
						seen[bc.opt] = int(seen.get(bc.opt, 0)) + 1
			for i in n.options.size():
				if int(seen.get(i, 0)) != 1:
					_fail("system %d: option %d is on %d bodies" % [n.index, i, int(seen.get(i, 0))])
			for k in seen.keys():
				if int(k) >= n.options.size():
					_fail("system %d: a beacon for option %d, which it does not have" % [n.index, int(k)])
			if n.type == MapGen.NodeType.STATION and not L.bodies.any(func(b): return b.beacons.any(func(bc): return bc.dock)):
				_fail("station %d has no DOCK" % n.index)
			if n.type == MapGen.NodeType.CORE and not L.bodies.any(func(b): return b.beacons.any(func(bc): return bc.core)):
				_fail("the core has no custodian")
			# a gas giant if and only if the node has one
			var giants := L.bodies.filter(func(b): return b.kind == &"giant").size()
			var want_giant := n.gas_giant and n.type != MapGen.NodeType.PULSAR
			if giants != (1 if want_giant else 0):
				_fail("system %d: %d giants, gas_giant=%s" % [n.index, giants, str(n.gas_giant)])
			if L.bodies.is_empty():
				_fail("system %d has no bodies" % n.index)
			counts[L.bodies.size()] = int(counts.get(L.bodies.size(), 0)) + 1
			# orbits clear of each other's bodies (a giant's rings reach twice its radius)
			for i in range(1, L.bodies.size()):
				var a := L.bodies[i - 1]
				var b := L.bodies[i]
				var reach := SystemLayout.reach_of(a) + SystemLayout.reach_of(b)
				var gap := b.orbit - a.orbit - reach
				if gap < min_gap:
					min_gap = gap
					min_gap_at = "system %d, bodies %d and %d" % [n.index, i - 1, i]
				if gap <= 0.0:
					_fail("system %d: orbits %d and %d cross their bodies (gap %.1f)" % [n.index, i - 1, i, gap])
			for b in L.bodies:
				if b.world != &"":
					worlds[b.world] = int(worlds.get(b.world, 0)) + 1
	_ok("%d systems laid out, every option on one body" % n_sys, true)
	var cl: Array[String] = []
	for k in range(1, 12):
		if counts.has(k):
			cl.append("%d bodies: %d" % [k, counts[k]])
	print("  systems by body count: " + ", ".join(cl))
	print("  narrowest gap between neighbouring bodies: %.1f px (%s)" % [min_gap, min_gap_at])
	# the same seed, a fresh run, the same layouts
	var drift := 0
	for s in SEEDS:
		Rng.forced = s
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
		for raw in Run.map:
			var n: MapGen.MapNode = raw
			if _print_of(SystemLayout.of(n)) != prints.get("%d:%d" % [s, n.index], ""):
				drift += 1
	_ok("every layout the same in a fresh run of the same seed (%d differ)" % drift, drift == 0)
	var keys := worlds.keys()
	keys.sort_custom(func(a, b): return int(worlds[a]) > int(worlds[b]))
	var line: Array[String] = []
	for k in keys:
		line.append("%s %d" % [k, worlds[k]])
	print("  worlds drawn: " + ", ".join(line))
	verdict("systemtest")
