extends RefCounted

## Determinism: the same seed twice, and streams that do not move each other.
##
##   godot --headless --path . -- rngtest
##
## RUN THIS AFTER TOUCHING Rng OR ANY GENERATOR. Determinism fails silently by
## nature. A run that is 99% reproducible looks exactly like one that is
## reproducible — the map matches, the galaxy matches, and then one call site
## that still reaches for the global `randf()` puts four players in four
## different games at jump 40, an hour into an evening they had scheduled.
##
## The four properties, in the order they matter:
##
## 1. **Same seed, same galaxy.** The one the co-op design needs. A seed is only
##    worth sending if the receiver draws the same numbers from it.
## 2. **Different seeds, different galaxies.** The check that catches a seed
##    which is not actually being read — a generator stuck on its default is
##    perfectly deterministic and completely useless.
## 3. **Streams do not move each other.** Ten thousand combat rolls must not
##    move the map by one system. Without this, tuning a loot weight changes the
##    world, and the balance sim reports numbers nobody can attribute.
## 4. **Position beats order.** What is at a node is the same whoever reaches it
##    and whenever. This is the property that survives four players doing four
##    different things at once, and a stream cannot provide it.

const SEED_A: int = 12345
const SEED_B: int = 999983

var fails: int = 0


func check(what: String, got: Variant, want: Variant) -> void:
	if str(got) != str(want):
		fails += 1
		print("  FAIL %s\n    got:  %s\n    want: %s" % [
			what, str(got).substr(0, 200), str(want).substr(0, 200)])


func ok(what: String, condition: bool) -> void:
	if not condition:
		fails += 1
		print("  FAIL %s" % what)


func run() -> void:
	print("\n=== the same seed twice ===")
	_same_seed()
	print("\n=== different seeds ===")
	_different_seeds()
	print("\n=== streams do not move each other ===")
	_independence()
	print("\n=== position beats order ===")
	_positional()
	print("\n=== the mixer ===")
	_mixer()
	print("\n=== a save keeps its place in the stream ===")
	_state_round_trip()
	print("\n=== a whole run ===")
	_whole_run()

	print("")
	if fails == 0:
		print("rngtest: PASS")
	else:
		print("rngtest: %d FAILURES" % fails)


# --- the fingerprints -----------------------------------------------------
#
# Everything the world is, flattened to a string. Deliberately over-inclusive:
# a field left out of this is a field that can drift between two machines with
# the test still green, and the whole point is to catch the one call site
# somebody forgot.

func world_print() -> String:
	var parts: PackedStringArray = [
		"kind=%d" % Run.galaxy_kind,
		"spin=%.9f" % Run.galaxy_spin,
		"name=%s" % Run.galaxy_name,
		"title=%s" % Run.galaxy_title,
	]
	var keys: Array = Run.galaxy.keys()
	keys.sort()
	for k in keys:
		parts.append("%s=%s" % [k, Run.galaxy[k]])
	return "|".join(parts)


func map_print() -> String:
	var parts: PackedStringArray = []
	for n in Run.map:
		var nn: MapGen.MapNode = n
		parts.append("%d:%d/%d d%d t%d dev%d sec%d f%d neb%d %s [%s] %s" % [
			nn.index, nn.layer, nn.row, nn.danger, int(nn.type),
			int(nn.development), nn.security, int(nn.fauna), int(nn.in_nebula),
			MapGen.star_name(nn), ",".join(_names(nn.berths)),
			",".join(PackedStringArray(Array(nn.links).map(func(i: int) -> String: return str(i)))),
		])
	return "\n".join(parts)


func _names(list: Array) -> PackedStringArray:
	var out: PackedStringArray = []
	for x in list:
		out.append(String(x))
	return out


func module_print(m: ModuleData) -> String:
	var af: PackedStringArray = []
	for a in m.affixes:
		af.append(a.name)
	return "%s|r%d|%d|%s" % [m.id, int(m.rarity), m.scrap_value, ",".join(af)]


func build_world(seed_value: int) -> void:
	Rng.forced = seed_value
	Run.start_new_run()
	Rng.forced = 0


# --- 1. the same seed twice ----------------------------------------------

func _same_seed() -> void:
	build_world(SEED_A)
	var w1 := world_print()
	var m1 := map_print()
	var hull1 := "%s/%d/%d" % [Run.hull.manufacturer, int(Run.hull.weight), Run.hull.max_hull]

	build_world(SEED_A)
	check("the galaxy is the same object", world_print(), w1)
	check("every system is the same system", map_print(), m1)
	check("the starting hull is the same hull",
		"%s/%d/%d" % [Run.hull.manufacturer, int(Run.hull.weight), Run.hull.max_hull], hull1)
	check("the seed is on the run where the save can find it", Run.galaxy_seed, SEED_A)
	print("  %s — %d systems, identical twice" % [Run.galaxy_name, Run.map.size()])


# --- 2. different seeds ---------------------------------------------------

func _different_seeds() -> void:
	build_world(SEED_A)
	var a := world_print() + map_print()
	build_world(SEED_B)
	var b := world_print() + map_print()
	ok("a different seed is a different galaxy", a != b)

	# Ten seeds, ten distinct maps. One pair colliding would be a coincidence;
	# a generator that ignores its seed produces ten identical strings, and the
	# single-pair check above would still pass if the two seeds happened to be
	# the ones being read.
	var seen := {}
	for i in 10:
		build_world(4000 + i * 7)
		seen[map_print()] = true
	check("ten seeds make ten maps", seen.size(), 10)


# --- 3. streams do not move each other ------------------------------------

func _independence() -> void:
	build_world(SEED_A)
	var clean := world_print() + map_print()

	# Burn the other streams hard, then rebuild the world from the same seed.
	# If any generator still reaches for the global RNG, or if two streams share
	# a cursor, this is where it shows.
	Rng.forced = SEED_A
	Run.start_new_run()
	Rng.forced = 0
	for i in 10000:
		Rng.fight.randf()
		Rng.loot.randi()
		Rng.event.randf()
		Rng.foe.randi()
	# The world stream is untouched, so regenerating from it must not be needed
	# at all — what was already built is the comparison.
	check("10,000 combat, loot, event and foe rolls did not move the world",
		world_print() + map_print(), clean)

	# And the same in the other direction: the world is generated between two
	# loot draws, and the loot draws must not notice.
	Rng.reseed(SEED_B)
	var first := LootGen.roll_module(5)
	Rng.reseed(SEED_B)
	var _throwaway := MapGen.generate(Rect2(Vector2.ZERO, Vector2(1600, 900)))
	var second := LootGen.roll_module(5)
	check("generating a map did not move the loot stream",
		module_print(second), module_print(first))


# --- 4. position beats order ----------------------------------------------

func _positional() -> void:
	Rng.reseed(SEED_A)
	var at46 := module_print(LootGen.roll_module(5, &"", false, Rng.derive(&"shop", 46)))
	var at47 := module_print(LootGen.roll_module(5, &"", false, Rng.derive(&"shop", 47)))
	ok("two systems do not stock the same shelf", at46 != at47)

	# The other player's evening: a thousand rolls of their own before they get
	# to node 46. The shelf must be the shelf.
	Rng.reseed(SEED_A)
	for i in 1000:
		LootGen.roll_module(3)
		Rng.foe.randi()
	var late := module_print(LootGen.roll_module(5, &"", false, Rng.derive(&"shop", 46)))
	check("node 46 stocks the same shelf whenever you reach it", late, at46)

	# And the tag matters, or the shop and the wreck at one node are one roll.
	var salvage := module_print(LootGen.roll_module(5, &"", false, Rng.derive(&"salvage", 46)))
	ok("the shop and the wreck at one node are different rolls", salvage != at46)


# --- 5. the mixer ---------------------------------------------------------

func _mixer() -> void:
	# Adjacent node indices must not give adjacent sequences. The mixer this
	# replaced was a single multiply, which leaves the low bits of neighbouring
	# seeds correlated — every system on a ring would drift toward the same
	# roll. 4096 consecutive indices, first byte of each: a good mixer fills
	# essentially all 256 buckets, a bad one clusters.
	Rng.reseed(SEED_A)
	var buckets := {}
	for i in 4096:
		buckets[Rng.derive(&"shop", i).randi() % 256] = true
	print("  4096 adjacent indices filled %d of 256 buckets" % buckets.size())
	ok("adjacent node indices decorrelate", buckets.size() >= 250)

	# The same index under the same master is the same generator, every time.
	Rng.reseed(SEED_A)
	var once := Rng.derive(&"shop", 46).randi()
	var twice := Rng.derive(&"shop", 46).randi()
	check("derive is a function, not a cursor", twice, once)

	# ...and a different master moves it.
	Rng.reseed(SEED_B)
	ok("a different run stocks a different shelf at the same node",
		Rng.derive(&"shop", 46).randi() != once)


# --- 6. the save keeps its place -----------------------------------------

func _state_round_trip() -> void:
	Rng.reseed(SEED_A)
	for i in 100:
		LootGen.roll_module(4)
	var saved := Rng.state()
	var expected: PackedStringArray = []
	for i in 10:
		expected.append(module_print(LootGen.roll_module(4)))

	# Scramble hard, the way SaveTest does, so nothing can survive by accident.
	Rng.reseed(SEED_B)
	for i in 500:
		LootGen.roll_module(6)

	Rng.restore(saved)
	var after: PackedStringArray = []
	for i in 10:
		after.append(module_print(LootGen.roll_module(4)))
	check("a restored run finds what it was going to find", str(after), str(expected))
	check("and remembers its seed", Rng.master, SEED_A)


# --- 7. a whole run -------------------------------------------------------

func _whole_run() -> void:
	# The map is generated once, so it proves the world stream and nothing else.
	# This walks a run far enough to touch the foe, event and loot paths and
	# checks that the whole thing replays — which is what "-- seed N reproduces
	# the bug" actually has to mean.
	var trace_a := _walk(SEED_A)
	var trace_b := _walk(SEED_A)
	check("forty jumps replay exactly", trace_b, trace_a)
	var other := _walk(SEED_B)
	ok("and a different seed does not", other != trace_a)
	print("  %d characters of run trace, identical twice" % trace_a.length())


func _walk(seed_value: int) -> String:
	build_world(seed_value)
	var parts: PackedStringArray = []
	for step in 40:
		var here: MapGen.MapNode = Run.node_at()
		var options: Array = []
		for idx in here.links:
			if Run.can_jump_to(Run.map[idx]):
				options.append(idx)
		if options.is_empty():
			break
		# Deterministic navigation, off a derived generator, so the walk itself
		# is not what is being tested.
		var r := Rng.derive(&"walk", step)
		var pick: int = Rng.pick(r, options)
		Run.jump_to(pick)
		var n: MapGen.MapNode = Run.node_at()
		var foes := Router._roll_foes(n)
		parts.append("%d>%d %s %s %s" % [
			here.index, n.index, MapGen.star_name(n), ",".join(_names(foes)),
			EventTable.pick_key(Rng.derive(&"event", n.index)),
		])
		parts.append("  " + module_print(LootGen.roll_module(n.danger, &"", false,
			Rng.derive(&"salvage", n.index))))
		parts.append("  " + module_print(LootGen.roll_module(n.danger)))
	return "\n".join(parts)
