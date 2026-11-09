extends Harness

## A gate, not a measurement: it checks what makes a run unwinnable, which players never see.
## Exists because thinning links removed the guarantee that every ring has an exit.
## Why: docs/why/MapTest.md#map-gate

## Pinned seeds, several of every kind: one map proves nothing and the rare failure is the point.
const ROLLS := 120
## Seeds that once broke a galaxy are always rolled; the 120 are pinned since Oct 11.
## Why: docs/why/MapTest.md#known-bad-seeds
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
	# (the station pass, `MapGen._place_stations`)
	var st_min := 9999
	var st_max := 0
	var st_total := 0
	var st_maps := 0
	var st_close: Array[String] = []
	var st_wrong: Array[String] = []
	var st_closest := INF
	var st_closest_at := ""

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
	# `pull=K` is the old placement, a stress test of `_ensure_flyable`'s bridging.
	MapGen.flyable_repair = not "norepair" in OS.get_cmdline_user_args()
	MapGen.test_stretch = float(_arg_of("stretch", "1"))
	var pull := float(_arg_of("pull", "0"))
	if pull > 0.0:
		MapGen.placement = MapGen.Placement.PULL
		MapGen.arm_pull_cap = pull
	for i in rolls:
		# Forced, not reseeded: `start_new_run` rolls its own master seed and discards a reseed.
		Rng.forced = list[i] if not list.is_empty() else first + i
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
		var map := Run.map
		if map.is_empty():
			unreachable.append("seed %d produced no map" % Rng.forced)
			continue

		# Stations are rarer and spaced (Jon, Nov 3): none within a bare drive's jump of another.
		var here_st := _stations(map)
		st_maps += 1
		st_total += here_st.size()
		st_min = mini(st_min, here_st.size())
		st_max = maxi(st_max, here_st.size())
		for si in here_st.size():
			var a: MapGen.MapNode = here_st[si]
			# (the start is node 0 and the core the last ring's one system)
			if a.index == 0 or a.layer == MapGen.LAYERS - 1:
				st_wrong.append("seed %d node %d" % [Rng.forced, a.index])
			for sj in range(si + 1, here_st.size()):
				var d := MapGen.hop_distance(a, here_st[sj])
				if d < st_closest:
					st_closest = d
					st_closest_at = "seed %d nodes %d and %d" % [Rng.forced, a.index,
						(here_st[sj] as MapGen.MapNode).index]
				if d <= Run.JUMP_RADIUS:
					st_close.append("seed %d: stations %d and %d are %.3f apart" % [Rng.forced,
						a.index, (here_st[sj] as MapGen.MapNode).index, d])

		# Every ring needs an exit, counted on `links`: an unconnected ring is a `_link` fault.
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

		# The core must be reachable, breadth-first over `links`: map structure, not fuel.
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

		# Also walks `reachable_from`, what the ship flies: a wide gap is a wall `links` misses.
		# Why: docs/why/MapTest.md#flyable-route
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
	var st_mean := float(st_total) / maxf(1.0, float(st_maps))
	print("  stations a galaxy: %d fewest · %.1f mean · %d most; the closest two %.4f apart (%s)"
		% [st_min, st_mean, st_max, st_closest, st_closest_at])

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
	# At best one jump per two rings (`DEPTH_STEP`), so no route may take fewer than seven.
	if flown > 0:
		var floor_jumps := ceili(float(MapGen.LAYERS - 1) / float(RULE))
		_ok("no galaxy is flown in fewer than one jump per %d rings (%d, at least %d)"
			% [RULE, fly_best, floor_jumps], fly_best >= floor_jumps)
	_ok("no station is within a bare drive's jump (%.2f) of another (closest %.4f, %s)"
		% [Run.JUMP_RADIUS, st_closest, st_closest_at], st_close.is_empty())
	for c in st_close.slice(0, 6):
		_fail(c)
	_ok("the start and the core are never stations", st_wrong.is_empty())
	for w in st_wrong.slice(0, 6):
		_fail(w)
	# (the study saw 35.5 a galaxy on the mean over 200 galaxies from seed
	# 777, 73.0 before the pass)
	_ok("stations a galaxy stay between %d and %d (%d to %d)"
		% [ST_FEWEST, ST_MOST, st_min, st_max],
		st_maps > 0 and st_min >= ST_FEWEST and st_max <= ST_MOST)
	_ok("about half today's count, %.0f to %.0f a galaxy on the mean (%.1f)"
		% [ST_MEAN_LO, ST_MEAN_HI, st_mean], st_mean >= ST_MEAN_LO and st_mean <= ST_MEAN_HI)
	if list.size() > 0:
		_stations_same(list[0])
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


## STATIONS A GALAXY under S3 (Jon, Nov 3): the bounds every pinned galaxy
## has to keep, and the mean over them (about 36; 73 before the pass).
const ST_FEWEST := 10
const ST_MOST := 60
const ST_MEAN_LO := 30.0
const ST_MEAN_HI := 42.0


func _stations(map: Array) -> Array:
	var out: Array = []
	for raw in map:
		if (raw as MapGen.MapNode).type == MapGen.NodeType.STATION:
			out.append(raw)
	return out


func _station_list(map: Array) -> Array[int]:
	var out: Array[int] = []
	for raw in _stations(map):
		out.append((raw as MapGen.MapNode).index)
	return out


## Stations are the seed's: later loot, foe and event rolls cannot change them (`Rng.derive`).
func _stations_same(sd: int) -> void:
	Rng.forced = sd
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var first := _station_list(Run.map)
	Rng.forced = sd
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var second := _station_list(Run.map)
	_ok("seed %d gives the same %d stations twice" % [sd, first.size()],
		not first.is_empty() and first == second)
	Rng.reseed(sd, 0)
	Run.galaxy = GalaxyGen.roll(Run.galaxy_kind)
	Run.galaxy_spin = Rng.world.randf() * TAU
	var at: int = Rng.world.state
	var built := _station_list(MapGen.generate(Run.MAP_CANVAS))
	for _i in 1000:
		Rng.loot.randf()
		Rng.foe.randf()
		Rng.event.randf()
	Rng.world.state = at
	var again := _station_list(MapGen.generate(Run.MAP_CANVAS))
	_ok("and the same after 1,000 loot, foe and event rolls (%d stations)" % again.size(),
		not built.is_empty() and built == again)


## THE RULE JON RULED, Oct 27: "Two rings now". A jump goes at most this many
## rings deeper (`RunState.DEPTH_STEP`; it was one from Oct 22, "A1D").
const RULE := 2


## The two-ring rule asked of every pair; a refusal inside reach is what the chart must name.
## Why: docs/why/MapTest.md#depth-rule
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
	# SECOND_NEAR > 0, or the line passes on nothing: a galaxy with no system of
	# that ring in reach of the core asks none of it.
	_ok("from the ring before it when in reach (%d of %d in reach), and never from further out or out of reach (%d)"
		% [from_second, second_near, from_before],
		second_near > 0 and from_before == 0 and from_second == second_near)


## The chart's words must name the rule's current count, or it gives the wrong reason silently.
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
	# Fits the 228 px column and wraps to no more lines than before, so the card does not grow.
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


## Every kind is completable for the slowest ship; the study found some it could not finish.
## Why: docs/why/MapTest.md#kind-sweep
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


## Fewest jumps for a ship with no thrust bonus, by the game's own rule; -1 if no way in.
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


## Guards a silent bug: a renumbered enum left a label array wrong. Check length, not blanks.
## Why: docs/why/MapTest.md#label-drift
func _labels() -> void:
	var bad: Array[String] = []
	# Check length, not blankness: the old bug was a too-long array of real but wrong names.
	if MapGen.REGION_NAMES.size() != MapGen.Region.size():
		bad.append("Region: %d names for %d values"
			% [MapGen.REGION_NAMES.size(), MapGen.Region.size()])
	if MapGen.DEVELOPMENT_NAMES.size() != MapGen.Development.size():
		bad.append("Development: %d names for %d values"
			% [MapGen.DEVELOPMENT_NAMES.size(), MapGen.Development.size()])
	if HullData.WEIGHT_NAMES.size() != HullData.Weight.size():
		bad.append("Weight: %d names for %d values"
			% [HullData.WEIGHT_NAMES.size(), HullData.Weight.size()])
	# Checks `type_label` still reads `NodeType.keys()`, so a revert to a literal array is caught.
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


## Blind to fuel on purpose: it asks if the geometry permits a route. About n^2, harness only.
## Why: docs/why/MapTest.md#flyable-route
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


## Why a galaxy cannot be flown: the wall's width against the jump radius, and its rings.
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
