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

	print("\n=== MAP ===")
	print("  %d galaxies rolled, %d rings" % [ROLLS, total_rings])
	if paths > 0:
		print("  forced path to the core: %d shortest · %.1f mean · %d longest"
			% [best_path, float(total_path) / float(paths), worst_path])
	print("  coreward doors per ring: %.1f average"
		% [float(total_doors) / maxf(1.0, float(total_rings))])

	_ok("every ring has at least one way inward", doorless.is_empty())
	for d in doorless:
		_fail(d)
	_ok("the core is reachable from the start in every galaxy",
		unreachable.is_empty())
	for u in unreachable:
		_fail(u)
	verdict("maptest")


func _in_layer(map: Array, layer: int) -> Array:
	var out: Array = []
	for n in map:
		if (n as MapGen.MapNode).layer == layer:
			out.append(n)
	return out


func _goal(map: Array) -> int:
	for n in map:
		if (n as MapGen.MapNode).type == MapGen.NodeType.GOAL:
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
