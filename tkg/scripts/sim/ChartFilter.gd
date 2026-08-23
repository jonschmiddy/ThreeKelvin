extends Harness

## What KNOWN ONLY actually shows you:
##   godot --headless --path . -- chartfilter
##
## The chart has two views and the useful one is the filtered view — the map you
## have earned, as opposed to the map the generator built. That only means
## anything if the filter is mostly filtering.
##
## THE FAILURE IT EXISTS FOR is an exception that grows until it swallows the
## rule. Stations are on the chart before you visit them, deliberately and for a
## good reason, and the range that exception reached was the entire galaxy — so
## KNOWN ONLY drew your four visited systems and every station out to the rim.
## Nothing errored. The view simply stopped answering the question it is for, and
## the only symptom was a screen that looked wrong to somebody who opened it.
##
## Measured across seeded galaxies at three depths of exploration, because "the
## filter is too loose" is a claim about a ratio and a ratio needs numbers.

## How much of the galaxy a filtered chart may show at the START of a run. Six
## per cent is roughly a starting system, its neighbours, and any station close
## enough to hear — which is what a chart should have on it before you have
## flown anywhere.
const OPENING_CEILING := 0.06


func run() -> void:
	print("\n  %-6s %6s %8s %9s %9s %9s"
		% ["seed", "nodes", "stations", "visited", "shown", "was"])
	var worst := 0.0
	var worst_at := ""
	for seed_i in [11, 4242, 90210, 31337]:
		for visits in [1, 8, 25]:
			# Rng.forced, NOT Rng.reseed. start_new_run rolls its own master seed,
			# so reseeding before it changed nothing and this sheet drew a
			# different galaxy on every run — a gate on a number that moves is not
			# a gate. Same lever `-- sim seed=N` uses.
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
			# WHAT THE OLD RULE WOULD HAVE SHOWN: everywhere you had been, plus
			# every station in the galaxy. Kept in the sheet and not only in a
			# commit message, because the ceiling below is meaningless without
			# the number it is holding the line against.
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
	verdict("chartfilter")


## Mark `n` systems visited, walking outward from the start rather than picking
## at random — a run explores a CONNECTED region, and a scattering of visited
## dots across the whole disc would flatter the filter by putting a listener
## next to far more stations than a real route ever does.
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
