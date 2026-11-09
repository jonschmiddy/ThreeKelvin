extends Harness

## A gate, not a measurement: positional, gated, tier-planned and duplicate-free rolling.
## Why: docs/why/OptionTest.md#option-test

const ROLLS := 200


func run() -> void:
	var bad_gate: Array[String] = []
	var bad_dup: Array[String] = []
	var bad_count: Array[String] = []
	var unstable: Array[String] = []
	var empty := 0
	var by_tier: Dictionary = {}
	var seen_ids: Dictionary = {}

	# The table itself has to be sound before anything rolled off it means
	# anything: a duplicate id would make `by_id` silently prefer one of two.
	var ids: Dictionary = {}
	var fails_before := _fails
	for o in OptionTable.all():
		var id := StringName(o.id)
		if ids.has(id):
			_fail("duplicate option id '%s'" % id)
		ids[id] = true
		if not o.has("choices") or (o.choices as Array).is_empty():
			_fail("option '%s' has no choices" % id)
	if _fails == fails_before:
		_ok("every option has a unique id and at least one choice", true)

	_gates_are_real()
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var n_checked := 0

	for n in Run.map:
		var node: MapGen.MapNode = n
		# The same three `ensure` refuses: a station is its own list, the core is
		# a boss, and the start is deliberately quiet.
		if node.type == MapGen.NodeType.STATION or node.type == MapGen.NodeType.CORE 				or node.type == MapGen.NodeType.START:
			continue
		if n_checked >= ROLLS:
			break
		n_checked += 1

		var got := OptionTable.roll_for(node)
		if got.is_empty():
			empty += 1
			continue

		# POSITIONAL: the same node rolled again is the same list.
		var again := OptionTable.roll_for(node)
		if str(got) != str(again):
			unstable.append("node %d rolled two different lists" % node.index)

		var seen: Dictionary = {}
		var groups: Dictionary = {}
		for id in got:
			seen_ids[id] = true
			if seen.has(id):
				bad_dup.append("node %d offers '%s' twice" % [node.index, id])
			seen[id] = true
			var o := OptionTable.by_id(id)
			if o.is_empty():
				bad_gate.append("node %d rolled unknown id '%s'" % [node.index, id])
				continue
			if not OptionTable.admits(o, node):
				bad_gate.append("node %d (danger %d, region %d) rolled '%s', which its gate forbids"
					% [node.index, node.danger, node.region, id])
			var g := StringName(o.get("group", &""))
			if g != &"":
				groups[g] = true

		var tier := MapGen.tier(node.danger)
		var plan: Dictionary = OptionTable.TIER_PLAN[tier]
		if got.size() > int(plan.hi):
			bad_count.append("node %d tier %d holds %d options, plan allows %d"
				% [node.index, tier, got.size(), int(plan.hi)])
		if groups.size() > int(plan.groups):
			bad_count.append("node %d tier %d opened %d groups, plan allows %d"
				% [node.index, tier, groups.size(), int(plan.groups)])
		var t: Dictionary = by_tier.get(tier, {"n": 0, "opts": 0, "grouped": 0, "short": 0})
		t.n += 1
		t.opts += got.size()
		t.grouped += groups.size()
		# Under the plan is a content signal, not a machine fault; the roller clamps to the gate.
		if got.size() < int(plan.lo):
			t.short += 1
		by_tier[tier] = t

	print("\n=== OPTIONS ===")
	print("  %d options in the table, %d distinct ids rolled over %d systems"
		% [OptionTable.all().size(), seen_ids.size(), n_checked])
	print("  tier   systems   avg options   wanted   avg groups   under plan")
	var short_total := 0
	for tier in [1, 2, 3, 4, 5]:
		if not by_tier.has(tier):
			continue
		var t: Dictionary = by_tier[tier]
		var plan2: Dictionary = OptionTable.TIER_PLAN[tier]
		short_total += int(t.short)
		print("  %4d %9d %13.2f %8s %12.2f %11d" % [tier, t.n,
			float(t.opts) / float(t.n),
			"%d-%d" % [int(plan2.lo), int(plan2.hi)],
			float(t.grouped) / float(t.n), int(t.short)])
	if short_total > 0:
		print("  %d of %d systems fell short of the tier plan -- THE TABLE IS THIN,"
			% [short_total, n_checked])
		print("  which is a content bill and not a fault. See ENCOUNTER_GENERATION.md.")
	if empty > 0:
		print("  %d systems rolled NOTHING -- every option gated out" % empty)

	_ok("the same system always rolls the same options", unstable.is_empty())
	for u in unstable:
		_fail(u)
	_ok("no system offers the same option twice", bad_dup.is_empty())
	for b in bad_dup:
		_fail(b)
	_ok("every rolled option is admitted by its own gate", bad_gate.is_empty())
	for b in bad_gate:
		_fail(b)
	_ok("counts and groups stay inside the tier plan", bad_count.is_empty())
	for b in bad_count:
		_fail(b)

	# A system with nothing to do in it is dead air, which is the failure §2
	# names: "sparse-and-easy is not tension, it is dead air".
	_ok("no system is left with nothing to do", empty == 0)

	# An option no galaxy admits is dead content; checked across seeds, not in each galaxy.
	# Why: docs/why/OptionTest.md#dead-content
	var reach: Dictionary = {}
	var skies: Array[String] = []
	for seed in [4242, 11, 90210, 31337, 7, 1000, 5150, 8675309, 42, 99, 2024, 777]:
		Rng.forced = seed
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
		var pulsars := 0
		var reds := 0
		var blues := 0
		var giants := 0
		for raw0 in Run.map:
			var s: MapGen.MapNode = raw0
			if s.type == MapGen.NodeType.PULSAR:
				pulsars += 1
			if s.type != MapGen.NodeType.SYSTEM:
				continue
			if s.star == MapGen.Star.RED:
				reds += 1
			if s.star == MapGen.Star.BLUE:
				blues += 1
			if s.gas_giant:
				giants += 1
		var remnants := 0
		for cc in NebulaField.clouds():
			if (cc as NebulaField.Cloud).kind == NebulaField.Kind.REMNANT:
				remnants += 1
		skies.append("    seed %-8d %-22s gas %.2f · %d clouds · %d remnants"
			% [seed, String(Run.galaxy.get("name", "?")),
				float(Run.galaxy.get("gas", 0.0)),
				NebulaField.clouds().size(), remnants])
		skies.append("    seed %-8d %3d pulsars · %3d red · %3d blue · %3d giants"
			% [seed, pulsars, reds, blues, giants])
		for o in OptionTable.all():
			if bool(o.get("placed", false)):
				continue   # placed options are never rolled; that is the point
			var id0 := StringName(o.id)
			var homes := 0
			for raw in Run.map:
				if OptionTable.admits(o, raw as MapGen.MapNode):
					homes += 1
			reach[id0] = int(reach.get(id0, 0)) + homes
	var homeless: Array[String] = []
	for id1 in reach:
		if int(reach[id1]) == 0:
			homeless.append(String(id1))
	_ok("every option has somewhere it could appear", homeless.is_empty())
	for bb in homeless:
		_fail("no system in any of four galaxies admits '%s'" % bb)
	print("  what the four galaxies actually hold:")
	for line in skies:
		print(line)
	print("  systems admitting each sky-gated option, over four galaxies:")
	for id2 in [&"the_sweep", &"corona", &"flare_shelter", &"slipping_orbit"]:
		if reach.has(id2):
			print("    %-16s %d" % [String(id2), int(reach[id2])])

	verdict("optiontest")


## `admits` ignores unknown keys, so an unimplemented gate admits everywhere, silently.
## Why: docs/why/OptionTest.md#gate-names
func _gates_are_real() -> void:
	# The keys `OptionTable.admits` tests, plus the ones that are not gates.
	var known := {
		&"id": true, &"title": true, &"body": true, &"tags": true,
		&"group": true, &"weight": true, &"choices": true,
		&"min_danger": true, &"max_danger": true,
		&"min_security": true, &"max_security": true,
		&"min_development": true, &"max_development": true,
		&"regions": true, &"needs_fauna": true, &"needs_berth": true,
		&"berth": true,
		# WHAT LOCAL SHOWS while the event is open (`LocalSubject`): not a gate,
		# and `-- subjecttest` checks its pieces and its fit
		&"subject": true,
		# PLACED: never rolled, only put by an outcome; listed so the gate does not do nothing.
		&"placed": true,
		# A signed contract's work (`Contracts.post_goal`), read by `OptionTable.is_job`.
		&"job": true,
		# A PLACED OPTION'S ROW IN THE QUESTS TABLE: its task, its chart tag's
		# word, its note and the event that places it. Read by `QuestLog`.
		&"quest": true,
		# STAR FEATURES: what is in the sky at a system, gated the way
		# `needs_fauna` is. See `OptionTable.admits`.
		&"needs_star": true, &"needs_giant": true, &"needs_pulsar": true,
		&"needs_nebula": true,
		# Where it sits on the system and how LOCAL draws the giant while it is open.
		&"site": true, &"near": true,
		# What its fight brings (Jon, Oct 17), read by `OptionTable.fight_foe`; not a gate.
		&"foe": true,
	}
	var bad: Array[String] = []
	for o in OptionTable.all():
		for k in (o as Dictionary).keys():
			if not known.has(StringName(k)):
				bad.append("%s.%s" % [String((o as Dictionary).id), String(k)])
	_ok("every option field is one the table reads%s"
		% ("" if bad.is_empty() else " -- " + ", ".join(bad)), bad.is_empty())
