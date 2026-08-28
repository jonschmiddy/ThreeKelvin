extends Harness

## Is the galaxy actually traversable, and how short is the short way?
##   godot --headless --path . -- maptest
##
## A GATE, not a measurement, unlike `-- content` and `-- rarity`. Everything it
## checks is a thing that makes a run UNWINNABLE rather than merely unbalanced,
## and none of it is visible from inside a run — a player meeting a ring with no
## way inward does not see a generation fault, they see a game that stopped.
##
## IT EXISTS BECAUSE OF THE SPARSE-LINK WORK. `_link()` currently gives EVERY
## system a coreward link, so "can you get in" was true by construction and
## needed no checking. Thinning those links removes that guarantee, and
## `GALAXY_SCALE.md` §3 flags the exact hazard: the reachability pass guarantees
## every forward system is reachable FROM somewhere, not that every ring has an
## exit. A ring with no doors is a run that cannot be finished.
##
## It also answers the question the design briefs kept guessing at. §0 opens "a
## run is eight jumps long" — that is the FORCED path, and this measures it
## rather than deriving it from the layer count, because reachability is not
## only about `links`: `RunState.reachable_from` also lets a hop through when
## either end thinks the other is close, so thinning links may not thin the
## shortest path by as much as the link count suggests.

## How many galaxies to roll. Every kind should appear several times, and the
## rare failure is what this is for — one map proves nothing.
const ROLLS := 120


func run() -> void:
	var worst_path := 0
	var best_path := 999
	var total_path := 0
	var paths := 0
	var doorless: Array[String] = []
	var unreachable: Array[String] = []
	var unflyable: Array[String] = []
	var fly_total := 0
	var fly_worst := 0
	var fly_best := 999
	var flown := 0
	var total_doors := 0
	var total_rings := 0

	for i in ROLLS:
		Rng.reseed(90210 + i, 0)
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
		var map := Run.map
		if map.is_empty():
			unreachable.append("roll %d produced no map" % i)
			continue

		# EVERY RING NEEDS AN EXIT. Counted on `links` rather than on
		# reachability, because this is asking about the structure the linker
		# built: a ring whose systems all fail to connect inward is a fault in
		# `_link`, whatever `reachable_from` may allow on top of it.
		for layer in MapGen.LAYERS - 1:
			var here := _in_layer(map, layer)
			if here.is_empty():
				continue
			total_rings += 1
			var doors := 0
			for n in here:
				for idx in (n as MapGen.MapNode).links:
					if idx >= 0 and idx < map.size() \
							and (map[idx] as MapGen.MapNode).layer > layer:
						doors += 1
						break
			total_doors += doors
			if doors == 0:
				doorless.append("roll %d ring %d has no way inward" % [i, layer])

		# AND THE CORE HAS TO BE REACHABLE, which is the only check that
		# actually matters to a player. Breadth-first over `links`, so it
		# measures the map rather than the ship — fuel and jump range are a
		# RunState question and a different kind of stranding.
		var goal := _goal(map)
		var start := _start(map)
		if goal < 0 or start < 0:
			unreachable.append("roll %d has no start or no core" % i)
			continue
		var hops := _shortest(map, start, goal)
		if hops < 0:
			unreachable.append("roll %d cannot reach the core at all" % i)
			continue
		paths += 1
		total_path += hops
		worst_path = maxi(worst_path, hops)
		best_path = mini(best_path, hops)

		# AND THE SAME QUESTION ASKED OF THE RULE THE SHIP FLIES. The search
		# above walks `links`, which is the graph the CHART draws and which
		# nothing in the jump path consults. This one walks `reachable_from` --
		# a radius, fixed since JUMP_RADIUS landed, so a gap wider than it is a
		# wall that the link graph knows nothing about.
		#
		# Fuel is deliberately not considered: running dry is a RunState problem
		# and a different kind of stranding. This asks whether the geometry
		# permits the route at all.
		var flyable := _shortest_by_range(map, start, goal)
		if flyable < 0:
			unflyable.append("roll %d: the core cannot be FLOWN to (kind %s)"
				% [i, String(Run.galaxy.get("name", "?"))])
			continue
		flown += 1
		fly_total += flyable
		fly_worst = maxi(fly_worst, flyable)
		fly_best = mini(fly_best, flyable)

	print("\n=== MAP ===")
	print("  %d galaxies rolled, %d rings" % [ROLLS, total_rings])
	if paths > 0:
		print("  forced path to the core: %d shortest · %.1f mean · %d longest"
			% [best_path, float(total_path) / float(paths), worst_path])
	print("  coreward doors per ring: %.1f average"
		% [float(total_doors) / maxf(1.0, float(total_rings))])
	if flown > 0:
		print("  FLYABLE path (radius, not links): %d shortest · %.1f mean · %d longest"
			% [fly_best, float(fly_total) / float(flown), fly_worst])

	_ok("every ring has at least one way inward", doorless.is_empty())
	for d in doorless:
		_fail(d)
	_ok("the core is reachable from the start in every galaxy",
		unreachable.is_empty())
	for u in unreachable:
		_fail(u)
	# THE ONE THAT MATTERS TO A PLAYER, now that links do not gate movement.
	_ok("the core can be FLOWN to in every galaxy", unflyable.is_empty())
	_labels()


## Every enum value still has a name, and the name still belongs to it.
##
## THE BUG THIS EXISTS FOR IS SILENT AND ALREADY HAPPENED. `type_label` was a
## hand-written array indexed by the enum value; the 8a-2 collapse renumbered
## `NodeType` and left the array alone, so STATION read "FIGHT", CORE read
## "STATION", PULSAR read "EVENT" and SYSTEM read "DERELICT" -- four of five node
## types naming themselves wrong on the sector screen for a day.
##
## Nothing errored. The array was still seven long and every lookup was in
## bounds, which is the whole hazard: a parallel array does not break when it
## stops corresponding, it answers a different question. A warning comment sat
## directly above the enum and survived the edit it was warning about, because
## comments do not run.
##
## `type_label` reads `NodeType.keys()` now and cannot drift. The other three
## CANNOT do that and should not: `region_name` deliberately maps FAUNA to
## "Migration Route" and CORE to "Precursor Ruins", which are prose, not keys.
## So this checks the property that actually matters -- every value in the enum
## resolves to a non-empty label, and one past the end does not resolve at all.
func _labels() -> void:
	var bad: Array[String] = []
	# LENGTH, NOT BLANKNESS, because the bug that happened was an array that was
	# too LONG and full of the wrong names -- every lookup in bounds, every label
	# non-empty, and four of five of them wrong. Checking for blanks would have
	# passed it. A count is the only thing that actually drifted.
	if MapGen.REGION_NAMES.size() != MapGen.Region.size():
		bad.append("Region: %d names for %d values"
			% [MapGen.REGION_NAMES.size(), MapGen.Region.size()])
	if MapGen.DEVELOPMENT_NAMES.size() != MapGen.Development.size():
		bad.append("Development: %d names for %d values"
			% [MapGen.DEVELOPMENT_NAMES.size(), MapGen.Development.size()])
	if HullData.WEIGHT_NAMES.size() != HullData.Weight.size():
		bad.append("Weight: %d names for %d values"
			% [HullData.WEIGHT_NAMES.size(), HullData.Weight.size()])
	# `type_label` reads `NodeType.keys()` and cannot drift by construction, so
	# what is checked there is that it still does -- a future edit swapping it
	# back to a literal array would slip past everything above.
	for i in MapGen.NodeType.size():
		if MapGen.type_label(i) != MapGen.NodeType.keys()[i]:
			bad.append("NodeType[%d] is %s, not %s"
				% [i, MapGen.type_label(i), MapGen.NodeType.keys()[i]])
	_ok("every enum has exactly as many labels as values%s"
		% ("" if bad.is_empty() else " -- " + ", ".join(bad)), bad.is_empty())


func _in_layer(map: Array, layer: int) -> Array:
	var out: Array = []
	for n in map:
		if (n as MapGen.MapNode).layer == layer:
			out.append(n)
	return out


func _goal(map: Array) -> int:
	for n in map:
		if (n as MapGen.MapNode).type == MapGen.NodeType.CORE:
			return (n as MapGen.MapNode).index
	return -1


func _start(map: Array) -> int:
	for n in map:
		if (n as MapGen.MapNode).type == MapGen.NodeType.START:
			return (n as MapGen.MapNode).index
	return -1


## Hops from `a` to `b` over `links`, or -1 if there is no route at all.
func _shortest(map: Array, a: int, b: int) -> int:
	var seen := {a: true}
	var frontier: Array[int] = [a]
	var depth := 0
	while not frontier.is_empty():
		if frontier.has(b):
			return depth
		var next: Array[int] = []
		for i in frontier:
			for idx in (map[i] as MapGen.MapNode).links:
				if idx >= 0 and idx < map.size() and not seen.has(idx):
					seen[idx] = true
					next.append(idx)
		frontier = next
		depth += 1
	return -1


## Fewest hops to the core under the rule the ship actually flies.
##
## `reachable_from`, not `links`. Breadth-first, and deliberately blind to fuel:
## this asks whether the GEOMETRY permits a route, which is the thing a galaxy
## can be generated wrong. Running dry is a different failure with a different
## fix.
##
## O(n) per node because `reachable_from` has no index behind it, so this is
## about n^2 a galaxy. At ~350 systems and 120 rolls that is affordable, and it
## only runs in the harness.
func _shortest_by_range(map: Array, start: int, goal: int) -> int:
	var seen: Dictionary = {start: true}
	var frontier: Array[int] = [start]
	var depth := 0
	while not frontier.is_empty():
		if frontier.has(goal):
			return depth
		var next: Array[int] = []
		for idx in frontier:
			var a: MapGen.MapNode = map[idx]
			for n in map:
				var b: MapGen.MapNode = n
				if seen.has(b.index):
					continue
				if Run.reachable_from(a, b):
					seen[b.index] = true
					next.append(b.index)
		frontier = next
		depth += 1
		if depth > map.size():
			return -1
	return -1
