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

## How many galaxies to roll, on pinned seeds (`-- maptest seeds=N from=S` rolls
## others, `seedlist=a,b` exactly those, `noknown` leaves out KNOWN_BAD). Every
## kind should appear several times, and the rare failure is what this is for —
## one map proves nothing.
const ROLLS := 120
## SEEDS THAT ONCE BROKE A GALAXY, rolled every time on top of the 120, so the
## gate cannot pass by not happening to roll them. The 120 are pinned too (from
## 90210): until Oct 11 this gate rolled 120 FRESH galaxies a run, because
## `start_new_run` draws its own seed and the reseed before it was thrown away,
## and a failure came and went between runs.
##   65867625  a Magellanic Irregular whose start sat alone in the dark at the
##             rim, 0.243 from its nearest system (`MapGen._ensure_flyable`)
const KNOWN_BAD: Array[int] = [65867625]


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

	# (`seeds=N from=S`: N galaxies from seed S instead, for hunting a rare
	# failure; every failure names its seed, and `-- seed S` replays it)
	var rolls := ROLLS
	var first := 90210
	var list: Array[int] = []
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with("seeds="):
			rolls = int((a as String).substr(6))
		elif (a as String).begins_with("from="):
			first = int((a as String).substr(5))
		elif (a as String).begins_with("seedlist="):
			for s in (a as String).substr(9).split(",", false):
				list.append(int(s))
	if list.is_empty() and not "noknown" in OS.get_cmdline_user_args():
		for i in rolls:
			list.append(first + i)
		list.append_array(KNOWN_BAD)
	if not list.is_empty():
		rolls = list.size()
	# (`pull=K`: the old PULL placement at arm pull cap K, which used to fail
	# about one galaxy in 120 at 4.0 -- a stress test for `_ensure_flyable`'s
	# bridging, which the shipped placement rarely needs)
	MapGen.flyable_repair = not "norepair" in OS.get_cmdline_user_args()
	MapGen.test_stretch = float(_arg_of("stretch", "1"))
	var pull := float(_arg_of("pull", "0"))
	if pull > 0.0:
		MapGen.placement = MapGen.Placement.PULL
		MapGen.arm_pull_cap = pull
	for i in rolls:
		# THE SEED IS FORCED, not reseeded: `start_new_run` rolls its own master
		# seed (`Rng.roll_master`) from the global generator, so a reseed before
		# it was thrown away and every run of this gate rolled 120 new galaxies
		Rng.forced = list[i] if not list.is_empty() else first + i
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
		var map := Run.map
		if map.is_empty():
			unreachable.append("seed %d produced no map" % Rng.forced)
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
				doorless.append("seed %d ring %d has no way inward" % [Rng.forced, layer])

		# AND THE CORE HAS TO BE REACHABLE, which is the only check that
		# actually matters to a player. Breadth-first over `links`, so it
		# measures the map rather than the ship — fuel and jump range are a
		# RunState question and a different kind of stranding.
		var goal := _goal(map)
		var start := _start(map)
		if goal < 0 or start < 0:
			unreachable.append("seed %d has no start or no core" % Rng.forced)
			continue
		var hops := _shortest(map, start, goal)
		if hops < 0:
			unreachable.append("seed %d cannot reach the core at all" % Rng.forced)
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
			unflyable.append("seed %d: the core cannot be FLOWN to (kind %s)%s"
				% [Rng.forced, String(Run.galaxy.get("name", "?")), _why(map, start)])
			continue
		flown += 1
		fly_total += flyable
		fly_worst = maxi(fly_worst, flyable)
		fly_best = mini(fly_best, flyable)

	print("\n=== MAP ===")
	print("  %d galaxies rolled, %d rings" % [rolls, total_rings])
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
	for u in unflyable:
		_fail(u)
	# ONE JUMP A RING AT BEST (RunState.DEPTH_STEP): there are LAYERS - 1 steps
	# from the rim ring to the core, so nothing may be shorter. Before the rule
	# came back the shortest way in was six.
	if flown > 0:
		_ok("no galaxy is flown in fewer than one jump a ring (%d, at least %d)"
			% [fly_best, MapGen.LAYERS - 1], fly_best >= MapGen.LAYERS - 1)
	if list.size() > 0:
		Rng.forced = list[0]
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
		_one_ring_rule(Run.map)
	if not "nokinds" in OS.get_cmdline_user_args():
		_every_kind(int(_arg_of("kindseeds", str(KIND_SEEDS))))
	Rng.forced = 0
	_labels()
	verdict("maptest")


## THE ONE-RING RULE, asked of every pair in one galaxy (`RunState.too_deep`,
## Jon, Oct 22: "A1D"). A jump goes at most one ring deeper; outward and along
## a ring it goes as far as the drive reaches; the core only from the last
## ring. And a star the rule refuses from inside the reach ring is the case the
## chart has to name (`too_deep_only`, TOO DEEP), so it has to say so.
func _one_ring_rule(map: Array) -> void:
	var deeper := 0
	var outward := 0
	var broke: Array[String] = []
	var named := 0
	var unnamed := 0
	var core := _goal(map)
	for ra in map:
		var a: MapGen.MapNode = ra
		for rb in map:
			var b: MapGen.MapNode = rb
			if a.index == b.index:
				continue
			var ok := Run.reachable_from(a, b)
			var step := b.layer - a.layer
			if ok and step > 1:
				broke.append("%d (ring %d) -> %d (ring %d)" % [a.index, a.layer, b.index, b.layer])
			if ok and step == 1:
				deeper += 1
			if ok and step < -1:
				outward += 1
			if step > 1 and b.type != MapGen.NodeType.CORE \
					and MapGen.hop_distance(a, b) <= Run.range_from(a):
				if Run.too_deep_only(a, b):
					named += 1
				else:
					unnamed += 1
	_ok("no jump goes two rings deeper or more (%d broke it)%s" % [broke.size(),
		"" if broke.is_empty() else ": " + ", ".join(broke.slice(0, 4))], broke.is_empty())
	_ok("a jump one ring deeper is allowed (%d pairs)" % deeper, deeper > 0)
	_ok("a jump more than one ring OUTWARD is still allowed (%d pairs)" % outward, outward > 0)
	_ok("a star in reach but two rings in reads TOO DEEP (%d named, %d not)" % [named, unnamed],
		named > 0 and unnamed == 0)
	var from_last := 0
	var from_before := 0
	for ra in map:
		var a: MapGen.MapNode = ra
		if a.type == MapGen.NodeType.CORE:
			continue
		if Run.reachable_from(a, map[core]):
			if a.layer == MapGen.LAYERS - 2:
				from_last += 1
			else:
				from_before += 1
	_ok("the core is flown to from the last ring and only from there (%d from it, %d from before it)"
		% [from_last, from_before], from_last > 0 and from_before == 0)


## EVERY GALAXY KIND IS COMPLETABLE UNDER THE ONE-RING RULE, for the slowest
## ship (thrust adds nothing, so the base `JUMP_RADIUS`): `seeds` galaxies of
## each `GalaxyGen` kind (15 each of 17 kinds, 255 galaxies), laid out the way
## the run-length study laid them out (seeds 900001 + kind * 1000 + i). The
## study found a few that one ring a jump could not finish;
## `MapGen._ensure_flyable` walks by the rule now and bridges the gap, and this
## is the sweep that says it did.
const KIND_SEEDS := 15

func _every_kind(seeds: int) -> void:
	var stuck: Array[String] = []
	var best := 999
	var worst := 0
	var total := 0
	var flown := 0
	for k in GalaxyGen.count():
		for s in seeds:
			var sd := 900001 + k * 1000 + s
			Rng.forced = sd
			Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
			Rng.reseed(sd, 0)
			Run.galaxy_kind = k
			Run.galaxy = GalaxyGen.roll(k)
			Run.galaxy_spin = Rng.world.randf() * TAU
			Run.map = MapGen.generate(Run.MAP_CANVAS)
			var hops := _slowest_path(Run.map)
			if hops < 0:
				stuck.append("%s seed %d" % [GalaxyGen.type_name(k), sd])
				continue
			flown += 1
			total += hops
			best = mini(best, hops)
			worst = maxi(worst, hops)
	print("  EVERY KIND, the slowest ship, one ring a jump: %d galaxies, %d flown · %d shortest · %.1f mean · %d longest"
		% [GalaxyGen.count() * seeds, flown, best, float(total) / maxf(1.0, float(flown)), worst])
	_ok("every galaxy of every kind (%d) can be flown to the core one ring at a time by the slowest ship"
		% (GalaxyGen.count() * seeds), stuck.is_empty())
	for u in stuck:
		_fail("cannot reach the core: " + u)


## Fewest jumps start to core for a ship with no thrust bonus: the game's own
## rule (`reachable_from`, so the one-ring cap and the core's approach) and no
## hop longer than the base radius; -1 if there is no way in.
func _slowest_path(map: Array) -> int:
	var start := _start(map)
	var goal := _goal(map)
	if start < 0 or goal < 0:
		return -1
	var by_layer: Array = []
	for l in MapGen.LAYERS:
		by_layer.append([])
	for raw in map:
		(by_layer[(raw as MapGen.MapNode).layer] as Array).append(raw)
	var seen := {start: true}
	var frontier: Array[int] = [start]
	var depth := 0
	while not frontier.is_empty():
		if seen.has(goal):
			return depth
		var next: Array[int] = []
		for i in frontier:
			var a: MapGen.MapNode = map[i]
			# (nothing two rings in or more is ever a jump)
			for l in mini(MapGen.LAYERS, a.layer + 2):
				for raw in by_layer[l]:
					var b: MapGen.MapNode = raw
					if seen.has(b.index):
						continue
					if b.type != MapGen.NodeType.CORE \
							and MapGen.hop_distance(a, b) > Run.JUMP_RADIUS:
						continue
					if Run.reachable_from(a, b):
						seen[b.index] = true
						next.append(b.index)
		frontier = next
		depth += 1
	return depth if seen.has(goal) else -1


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
##
## So what is checked is LENGTH. The first cut of this looked for BLANK labels
## and would have passed the very bug it was written for: the array was too LONG,
## so every lookup was in bounds and every label was a real word -- just the
## wrong one. A count is the only thing that actually drifted.
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


func _arg_of(k: String, d: String) -> String:
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with(k + "="):
			return (a as String).substr(k.length() + 1)
	return d


## Why a galaxy cannot be flown: everything the ship can get to from the start,
## and the shortest hop from there to anywhere it cannot -- the wall's width
## against the jump radius, and which rings it lies between.
func _why(map: Array, start: int) -> String:
	var seen: Dictionary = {start: true}
	var frontier: Array[int] = [start]
	while not frontier.is_empty():
		var next: Array[int] = []
		for idx in frontier:
			var a: MapGen.MapNode = map[idx]
			for n in map:
				var b: MapGen.MapNode = n
				if not seen.has(b.index) and Run.reachable_from(a, b):
					seen[b.index] = true
					next.append(b.index)
		frontier = next
	var best := INF
	var pair := [-1, -1]
	for i: int in seen:
		for n in map:
			var b: MapGen.MapNode = n
			if seen.has(b.index):
				continue
			var d := MapGen.hop_distance(map[i], b)
			if d < best:
				best = d
				pair = [i, b.index]
	var deepest := 0
	for i: int in seen:
		deepest = maxi(deepest, (map[i] as MapGen.MapNode).layer)
	var a2: MapGen.MapNode = map[pair[0]]
	var b2: MapGen.MapNode = map[pair[1]]
	return " -- %d of %d systems reachable, deepest ring %d; the narrowest gap out is %.3f (radius %.3f) from ring %d at %s to ring %d at %s" 		% [seen.size(), map.size(), deepest, best, Run.range_from(a2), a2.layer, a2.gal, b2.layer, b2.gal]
