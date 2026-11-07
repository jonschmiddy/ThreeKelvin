extends Harness

## Guards the filtered chart against an exception swallowing the rule, as stations once
## drew out to the rim.
## Why: docs/why/ChartFilter.md#known-only-filter

## Six per cent is about a starting system, neighbours and a nearby station: a fresh chart.
const OPENING_CEILING := 0.06


func run() -> void:
	print("\n  %-6s %6s %8s %9s %9s %9s"
		% ["seed", "nodes", "stations", "visited", "shown", "was"])
	var worst := 0.0
	var worst_at := ""
	for seed_i in [11, 4242, 90210, 31337]:
		for visits in [1, 8, 25]:
			# Uses `Rng.forced`, not `Rng.reseed`: reseeding before `start_new_run` drew a
			# different galaxy each run.
			Rng.forced = seed_i
			Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
			var stations := 0
			for n in Run.map:
				if (n as MapGen.MapNode).type == MapGen.NodeType.STATION:
					stations += 1
			_walk(visits)
			var shown := 0
			for n in Run.map:
				var t: MapGen.MapNode = n
				if t.visited or Run.station_heard(t.index) or t.index == Run.at:
					shown += 1
			var frac := float(shown) / float(maxi(1, Run.map.size()))
			# The old rule's count stays here, as the ceiling means nothing without the number it
			# holds against.
			var was := 0
			for other in Run.map:
				var u: MapGen.MapNode = other
				if u.visited or u.type == MapGen.NodeType.STATION or u.index == Run.at:
					was += 1
			print("  %-6d %6d %8d %9d %9d (%2d%%) %6d (%2d%%)"
				% [seed_i, Run.map.size(), stations, visits, shown,
					roundi(frac * 100.0), was,
					roundi(100.0 * float(was) / float(maxi(1, Run.map.size())))])
			if visits == 1 and frac > worst:
				worst = frac
				worst_at = "seed %d" % seed_i
	_ok("a fresh chart shows at most %d%% of the galaxy (worst %s: %.0f%%)"
		% [roundi(OPENING_CEILING * 100.0), worst_at, worst * 100.0],
		worst <= OPENING_CEILING)
	_outside_sight()
	verdict("chartfilter")


## Checks the `sensed` reason, which the first sheet missed, and measures after flying, not
## on a fresh chart.
## Why: docs/why/ChartFilter.md#outside-sight
func _outside_sight() -> void:
	print("\n  %-6s %6s %6s %7s %7s   %s"
		% ["seed", "flown", "shown", "sensed", "beyond", "why"])
	var worst := 0
	for seed_i in [11, 4242, 90210, 31337]:
		for flown in [1, 8, 25]:
			worst = maxi(worst, _one_chart(seed_i, flown))
	# Only the dish is bounded by its radius. Written as a reason test, as a count of one
	# would miss a leak.
	# Why: docs/why/ChartFilter.md#outside-sight
	_ok("the dish never marks anything beyond its own radius (worst %d)" % worst,
		worst == 0)


## One galaxy, flown `flown` systems deep. Returns how many non-core nodes are
## drawn beyond sight.
func _one_chart(seed_i: int, flown: int) -> int:
	Rng.forced = seed_i
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	_walk(flown)
	var here: MapGen.MapNode = Run.node_at()
	Run.chart_from(here)
	var r := Run.sense_radius()
	var shown := 0
	var sensed := 0
	var beyond := 0
	var beyond_not_core := 0
	var why: Dictionary = {}
	for n in Run.map:
		var t: MapGen.MapNode = n
		if t.sensed:
			sensed += 1
		# `_visible_set`'s reasons, in its order. `selected` and `hovered` are
		# left out on purpose: they are a mouse, not a rule.
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
			# Only the dish may not pass its radius; visited, station and contract are told, and
			# the core is exempt.
			if reason == "sensed" and t.type != MapGen.NodeType.CORE:
				beyond_not_core += 1
	print("  %-6d %6d %6d %7d %7d   %s"
		% [seed_i, flown, shown, sensed, beyond, JSON.stringify(why)])
	return beyond_not_core


## Walks outward: runs explore a connected region, and scattered dots would flatter the
## filter.
func _walk(n: int) -> void:
	var queue: Array[int] = [Run.at]
	var seen := {Run.at: true}
	var done := 0
	while not queue.is_empty() and done < n:
		var i: int = queue.pop_front()
		(Run.map[i] as MapGen.MapNode).visited = true
		done += 1
		for j in (Run.map[i] as MapGen.MapNode).links:
			if not seen.has(j):
				seen[j] = true
				queue.append(j)
