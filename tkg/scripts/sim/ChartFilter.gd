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
	_outside_sight()
	verdict("chartfilter")


## Is anything DRAWN that is further off than the dish can see?
##
## THE SHEET ABOVE COULD NOT ANSWER THIS. It counts `visited or station_heard or
## at` -- three of the six reasons `StarchartScreen._visible_set` draws a dot --
## so the one the player actually complains about, `sensed`, was outside what it
## measured. It passed while the screen looked wrong, which is the same blind
## spot shape as a fingerprint that omits a field.
##
## Reported "I can see systems out of my view range", three times. Both rings are
## drawn and the outer one is sight, so the question is not whether dots appear
## beyond the ORANGE ring -- they should, that gap is what a dish buys -- but
## whether any appear beyond the TEAL one.
##
## MEASURED AFTER FLYING, which the first cut of this check did not do. A fresh
## chart is the one state where `visited` is a single node and `station_heard`
## reaches almost nothing, so measuring only there measures the case that cannot
## fail. Every report has been a screenshot of a chart somebody had been flying.
func _outside_sight() -> void:
	print("\n  %-6s %6s %6s %7s %7s   %s"
		% ["seed", "flown", "shown", "sensed", "beyond", "why"])
	var worst := 0
	for seed_i in [11, 4242, 90210, 31337]:
		for flown in [1, 8, 25]:
			worst = maxi(worst, _one_chart(seed_i, flown))
	# WHAT THIS IS AND IS NOT. `beyond` climbs to fifteen after twenty-five jumps
	# and that is CORRECT: it is where you have been, plus stations you have
	# heard, plus the core. None of those claim to be a current sighting, and
	# StarchartScreen draws them dimmed for exactly that reason.
	#
	# The invariant is narrower and is about the DISH alone: `sensed` is set by
	# `chart_from` measuring a radius, so a `sensed` node outside that radius is
	# the radius not being honoured. Written as a reason test rather than a count,
	# because a count is not an identity -- "at most one" would also pass on the
	# day an ordinary system started leaking through and the core stopped being
	# drawn.
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
		elif Run.station_heard(t.index):
			reason = "station"
		elif t.sensed:
			reason = "sensed"
		elif Run.contract_at(t.index) != null:
			reason = "contract"
		elif Run.can_jump_to(t):
			reason = "reach"
		if reason == "":
			continue
		shown += 1
		if MapGen.hop_distance(here, t) > r:
			beyond += 1
			why[reason] = int(why.get(reason, 0)) + 1
			# WHAT IS ACTUALLY FORBIDDEN is the DISH reaching past its own
			# radius. `visited`, `station` and `contract` beyond sight are all
			# correct -- they are things you were told or places you have been,
			# and none of them claim to be a current sighting. The core is
			# `chart_from`'s deliberate exception.
			if reason == "sensed" and t.type != MapGen.NodeType.CORE:
				beyond_not_core += 1
	print("  %-6d %6d %6d %7d %7d   %s"
		% [seed_i, flown, shown, sensed, beyond, JSON.stringify(why)])
	return beyond_not_core


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
