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
	# ONE JUMP PER TWO RINGS AT BEST (RunState.DEPTH_STEP): there are LAYERS - 1
	# steps from the rim ring to the core, so nothing may take fewer than half
	# of them, rounded up: seven. Under Oct 22's one ring it was fourteen, and
	# before any cap the shortest way in was six.
	if flown > 0:
		var floor_jumps := ceili(float(MapGen.LAYERS - 1) / float(RULE))
		_ok("no galaxy is flown in fewer than one jump per %d rings (%d, at least %d)"
			% [RULE, fly_best, floor_jumps], fly_best >= floor_jumps)
	if list.size() > 0:
		Rng.forced = list[0]
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
		_depth_rule(Run.map)
	_chart_words()
	if not "nokinds" in OS.get_cmdline_user_args():
		_every_kind(int(_arg_of("kindseeds", str(KIND_SEEDS))))
	Rng.forced = 0
	_labels()
	verdict("maptest")


## THE RULE JON RULED, Oct 27: "Two rings now". A jump goes at most this many
## rings deeper (`RunState.DEPTH_STEP`; it was one from Oct 22, "A1D").
const RULE := 2


## THE TWO-RING RULE, asked of every pair in one galaxy (`RunState.too_deep`).
## A jump goes at most two rings deeper; outward and along a ring it goes as far
## as the drive reaches; the core from the last ring always, from the ring
## before it when in reach, and never from further out. And a star the rule
## refuses from inside the reach ring is the case the chart has to name
## (`too_deep_only`, TOO DEEP), so it has to say so.
func _depth_rule(map: Array) -> void:
	_ok("the game's rule is Jon's: %d rings deeper a jump at most (RunState.DEPTH_STEP %d)"
		% [RULE, Run.DEPTH_STEP], Run.DEPTH_STEP == RULE and Run.depth_step == RULE)
	var one_in := 0
	var two_in := 0
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
			if ok and step > RULE:
				broke.append("%d (ring %d) -> %d (ring %d)" % [a.index, a.layer, b.index, b.layer])
			if ok and step == 1:
				one_in += 1
			if ok and step == RULE:
				two_in += 1
			if ok and step < -RULE:
				outward += 1
			if step > RULE and b.type != MapGen.NodeType.CORE \
					and MapGen.hop_distance(a, b) <= Run.range_from(a):
				if Run.too_deep_only(a, b):
					named += 1
				else:
					unnamed += 1
	_ok("no jump goes three rings deeper or more (%d broke it)%s" % [broke.size(),
		"" if broke.is_empty() else ": " + ", ".join(broke.slice(0, 4))], broke.is_empty())
	_ok("a jump one ring deeper is allowed (%d pairs)" % one_in, one_in > 0)
	_ok("a jump two rings deeper is allowed (%d pairs)" % two_in, two_in > 0)
	_ok("a jump more than two rings OUTWARD is still allowed (%d pairs)" % outward, outward > 0)
	_ok("a star in reach but three rings in reads TOO DEEP (%d named, %d not)" % [named, unnamed],
		named > 0 and unnamed == 0)
	var from_last := 0
	var last_ring := 0
	var from_second := 0
	var second_near := 0
	var from_before := 0
	for ra in map:
		var a: MapGen.MapNode = ra
		if a.type == MapGen.NodeType.CORE:
			continue
		var ok := Run.reachable_from(a, map[core])
		if a.layer == MapGen.LAYERS - 2:
			last_ring += 1
			if ok:
				from_last += 1
		elif a.layer == MapGen.LAYERS - 3:
			# (two rings out: a jump like any other, so in reach or not)
			var near := MapGen.hop_distance(a, map[core]) <= Run.range_from(a) \
				or MapGen.hop_distance(a, map[core]) <= Run.range_from(map[core])
			if near:
				second_near += 1
			if ok != near:
				from_before += 1
			elif ok:
				from_second += 1
		elif ok:
			from_before += 1
	_ok("the core is flown to from every system of the last ring (%d of %d)"
		% [from_last, last_ring], last_ring > 0 and from_last == last_ring)
	_ok("from the ring before it when in reach (%d of %d in reach), and never from further out or out of reach (%d)"
		% [from_second, second_near, from_before], from_before == 0 and from_second == second_near)


## THE CHART SAYS THE SAME RULE (`StarchartScreen.DEPTH_ROW`, the FUEL row of a
## star refused for depth, and the legend's line on the chart's first survey):
## both name the rule's count, neither the old one, and both still fit where
## they sit. A rule changed without its words is a chart that gives the wrong
## reason, which nothing else here would notice.
const COUNT_WORDS: Array[String] = ["NO", "ONE", "TWO", "THREE", "FOUR"]

func _chart_words() -> void:
	var word := COUNT_WORDS[clampi(Run.DEPTH_STEP, 0, COUNT_WORDS.size() - 1)]
	var row := StarchartScreen.DEPTH_ROW
	var legend := ""
	for l: String in StarchartScreen.PRIMER_LEGEND:
		if l.contains("THRUSTER REACH"):
			legend = l
	_ok("the FUEL row of a star too deep names the rule (\"%s\")" % row,
		row.begins_with(word + " RING") and not row.contains("ONE RING AT A TIME"))
	_ok("the chart's legend names the rule (\"%s\")" % legend,
		legend.contains("%s ring" % word.to_lower()) and not legend.contains("one ring deeper"))
	# FITS: the row beside its key inside the panel's 228 px column, and the
	# legend's line wrapping to no more lines at the card's width than Oct 22's
	# words did, so the card does not grow
	var font := UITheme.pixel_font()
	var fs := UITheme.FS_SMALL
	var row_w := font.get_string_size("FUEL", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x \
		+ font.get_string_size(row, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 8.0
	_ok("the row fits its panel (%.0f of 228 px)" % row_w, row_w <= 228.0)
	var para := float(StarchartScreen.PRIMER_W - 28)
	var was := "You fly as far as THRUSTER REACH, and one ring deeper a jump at most. You see as far as SENSOR RANGE. Past your sight a jump is refused: NOT SCANNED."
	var h_now := font.get_multiline_string_size(legend, HORIZONTAL_ALIGNMENT_LEFT, para, fs).y
	var h_was := font.get_multiline_string_size(was, HORIZONTAL_ALIGNMENT_LEFT, para, fs).y
	_ok("the legend's line is no taller than before (%.0f px, was %.0f)" % [h_now, h_was],
		h_now > 0.0 and h_now <= h_was)


## EVERY GALAXY KIND IS COMPLETABLE UNDER THE DEPTH RULE, for the slowest
## ship (thrust adds nothing, so the base `JUMP_RADIUS`): `seeds` galaxies of
## each `GalaxyGen` kind (15 each of 17 kinds, 255 galaxies), laid out the way
## the run-length study laid them out (seeds 900001 + kind * 1000 + i). The
## study found a few that one ring a jump could not finish;
## `MapGen._ensure_flyable` walks by the rule (two rings since Oct 27) and
## bridges the gap, and this is the sweep that says it did.
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
	print("  EVERY KIND, the slowest ship, %d rings a jump at most: %d galaxies, %d flown · %d shortest · %.1f mean · %d longest"
		% [Run.depth_step, GalaxyGen.count() * seeds, flown, best, float(total) / maxf(1.0, float(flown)), worst])
	_ok("every galaxy of every kind (%d) can be flown to the core by the slowest ship"
		% (GalaxyGen.count() * seeds), stuck.is_empty())
	var floor_jumps := ceili(float(MapGen.LAYERS - 1) / float(RULE))
	if flown > 0:
		_ok("and none in fewer than one jump per %d rings (%d, at least %d)"
			% [RULE, best, floor_jumps], best >= floor_jumps)
	for u in stuck:
		_fail("cannot reach the core: " + u)


## Fewest jumps start to core for a ship with no thrust bonus: the game's own
## rule (`reachable_from`, so the depth cap and the core's approach) and no
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
			# (nothing deeper than the cap is ever a jump; `reachable_from`
			# below is the judge, this only skips the rings it would refuse)
			var cap := Run.depth_step if Run.depth_step > 0 else MapGen.LAYERS
			for l in mini(MapGen.LAYERS, a.layer + cap + 1):
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
