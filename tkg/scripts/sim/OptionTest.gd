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
	for o in OptionTable.all():
		var id := StringName(o.id)
		if ids.has(id):
			_fail("duplicate option id '%s'" % id)
		ids[id] = true
		if not o.has("choices") or (o.choices as Array).is_empty():
			_fail("option '%s' has no choices" % id)
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

	_science_table()
	_science_rolls()
	_science_pay()
	_science_gate()
	verdict("optiontest")


const SCIENCE_SEEDS := [4242, 11, 90210, 31337, 7, 1000, 5150, 8675309, 42, 99, 2024, 777]


## THE EIGHT SCIENCE EVENTS (Phase 12, plan section 3): four barren and four
## belt, one of each in the bands 1-4, 3-6, 5-8 and 7-10, each with a careful
## reading, a risky one behind a check and one line that pays credits.
func _science_table() -> void:
	print("\n=== SCIENCE ===")
	var bands := {&"barren": [], &"belt": []}
	var shape_bad: Array[String] = []
	for o in OptionTable.all():
		if not OptionTable.is_science(o):
			continue
		var site := StringName(o.get("site", &""))
		if not bands.has(site):
			shape_bad.append("%s sits on '%s'" % [o.id, site])
			continue
		(bands[site] as Array).append("%d-%d" % [int(o.get("min_danger", 0)), int(o.get("max_danger", 0))])
		var burns := 0
		var credits := 0
		for c: Dictionary in o.choices:
			if bool(c.get("burns", false)):
				burns += 1
			else:
				credits += 1
		if burns != 2 or credits != 1:
			shape_bad.append("%s has %d reading lines and %d others" % [o.id, burns, credits])
	for site in bands:
		var got: Array = bands[site]
		got.sort()
		if str(got) != str(["1-4", "3-6", "5-8", "7-10"]):
			shape_bad.append("%s bands are %s" % [site, str(got)])
	_ok("eight science events, a barren and a belt one in each band, two readings and a credits line each%s"
		% ("" if shape_bad.is_empty() else ": " + "; ".join(shape_bad)), shape_bad.is_empty())


## HOW OFTEN, ONE AT MOST, AND NOTHING ELSE MOVES.
## Why: docs/why/OptionTest.md#how-often
func _science_rolls() -> void:
	var main_all: Array[Dictionary] = []
	for o in OptionTable.all():
		if not OptionTable.is_science(o):
			main_all.append(o)
	var opts := 0
	var sci := 0
	var systems := 0
	var hit := 0
	var two: Array[String] = []
	var moved: Array[String] = []
	var off_moved: Array[String] = []
	var rs_moved := 0
	for seed in SCIENCE_SEEDS:
		Rng.forced = seed
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
		for raw in Run.map:
			var n: MapGen.MapNode = raw
			if n.type == MapGen.NodeType.STATION or n.type == MapGen.NodeType.CORE \
					or n.type == MapGen.NodeType.START:
				continue
			var rs_before := JSON.stringify(Rng.state())
			var got := OptionTable.roll_for(n)
			if JSON.stringify(Rng.state()) != rs_before:
				rs_moved += 1
			Run.science_off = true
			var off := OptionTable.roll_for(n)
			Run.science_off = false
			# main's table: every option but science, rolled the same way
			var full := OptionTable._all
			OptionTable._all = main_all
			var main := OptionTable.roll_for(n)
			OptionTable._all = full
			systems += 1
			opts += got.size()
			var here := 0
			for id in got:
				if OptionTable.is_science(OptionTable.by_id(id)):
					here += 1
			sci += here
			hit += int(here > 0)
			if here > 1:
				two.append("seed %d system %d: %s" % [seed, n.index, str(got)])
			if str(off) != str(main):
				off_moved.append("seed %d system %d: off %s, main %s" % [seed, n.index, str(off), str(main)])
			var diff := 0
			for k in mini(got.size(), main.size()):
				if got[k] != main[k]:
					diff += 1
			if got.size() != main.size() or diff != here:
				moved.append("seed %d system %d: %s, main %s" % [seed, n.index, str(got), str(main)])
	var share := float(sci) / float(maxi(opts, 1))
	print("  %d science events in %d options rolled (%.3f), at %d of %d systems (%.0f%%)"
		% [sci, opts, share, hit, systems, 100.0 * float(hit) / float(maxi(systems, 1))])
	_ok("the science share of rolled options is %.3f, about 1 in 6 (0.155 to 0.18)" % share,
		share >= 0.155 and share <= 0.18)
	_ok("no system holds two science events%s" % ("" if two.is_empty() else ": " + two[0]), two.is_empty())
	_ok("every system rolls main's list, but for the one slot a science event took (%d differ)%s"
		% [moved.size(), "" if moved.is_empty() else ": " + moved[0]], moved.is_empty())
	_ok("science=off rolls main's list in every system (%d differ)%s"
		% [off_moved.size(), "" if off_moved.is_empty() else ": " + off_moved[0]], off_moved.is_empty())
	_ok("rolling with science moves no shared stream (%d systems did)" % rs_moved, rs_moved == 0)


## THE PAY TABLE (plan section 3), run through every event's own callables at
## the bottom of its band: the careful line pays a reading and burns the fuel,
## the risky line pays two, two, one and none by band and burns the fuel on
## every band (you flew down there), and the credits line pays credits and
## moves neither fuel nor DATA.
func _science_pay() -> void:
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var by_danger := {}
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		if not by_danger.has(n.danger):
			by_danger[n.danger] = n
	var pay_bad: Array[String] = []
	# careful DATA and fuel by danger, as Jon's 4B and "science costs fuel" set them
	var want_pay := [0, 5, 5, 6, 6, 8, 8, 10, 10, 14, 14]
	var want_fuel := [0, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2]
	var dangers := 0
	for d in range(1, 11):
		if not by_danger.has(d):
			continue
		dangers += 1
		Run.at = (by_danger[d] as MapGen.MapNode).index
		if OptionTable.reading(1) != want_pay[d] or OptionTable.reading(2) != 2 * want_pay[d] \
				or OptionTable.science_fuel() != want_fuel[d]:
			pay_bad.append("danger %d pays %d/%d for %d fuel" % [d, OptionTable.reading(1),
				OptionTable.reading(2), OptionTable.science_fuel()])
	_ok("a reading pays 5/6/8/10/14 by tier, double for the risky line, for 1/1/2/2/2 fuel (%d dangers)%s"
		% [dangers, "" if pay_bad.is_empty() else ": " + ", ".join(pay_bad)], pay_bad.is_empty() and dangers >= 9)
	var bad: Array[String] = []
	var ran := 0
	for o in OptionTable.all():
		if not OptionTable.is_science(o):
			continue
		var d := int(o.min_danger)
		if not by_danger.has(d):
			bad.append("%s: no system at danger %d" % [o.id, d])
			continue
		Run.at = (by_danger[d] as MapGen.MapNode).index
		var fuel := OptionTable.science_fuel()
		var one := OptionTable.reading(1)
		for c: Dictionary in o.choices:
			var calls: Array = []
			var reads: Array = []
			if c.has("check"):
				for b in [SkillCheck.Band.MET, SkillCheck.Band.CLEAN, SkillCheck.Band.PARTIAL, SkillCheck.Band.BOTCHED]:
					calls.append(SkillCheck.pick_outcome(c, b))
				reads = [2, 2, 1, 0]
			else:
				calls.append(c.effect)
				reads = [int(c.get("reads", 0))]
			for k in calls.size():
				Run.fuel = Run.FUEL_TANK
				Run.hp = Run.max_hp()
				Run.heat = 0
				Run.data = 0
				var cr := Run.credits
				var res: Variant = (calls[k] as Callable).call()
				ran += 1
				var tag := "%s \"%s\"%s" % [o.id, c.label, "" if calls.size() == 1 else " band %d" % k]
				if typeof(res) != TYPE_DICTIONARY or String((res as Dictionary).get("text", "")) == "":
					bad.append("%s returns no text" % tag)
				if bool(c.get("burns", false)):
					if Run.data != one * int(reads[k]) or Run.fuel != Run.FUEL_TANK - fuel:
						bad.append("%s paid %d DATA for %d fuel, wants %d for %d" % [tag, Run.data,
							Run.FUEL_TANK - Run.fuel, one * int(reads[k]), fuel])
				elif Run.data != 0 or Run.fuel != Run.FUEL_TANK or Run.credits <= cr:
					bad.append("%s (credits) moved DATA %d, fuel %d, credits %d" % [tag, Run.data,
						Run.fuel - Run.FUEL_TANK, Run.credits - cr])
	_ok("every science outcome (%d run) pays the table's DATA, burns its fuel on every band, and the credits line pays credits alone%s"
		% [ran, "" if bad.is_empty() else ": " + "; ".join(bad.slice(0, 4))], bad.is_empty() and ran == 8 * 6)


## THE FUEL GATE (open call 1, a hard gate): a reading is refused when paying it
## would take the tank under `Run.fuel_floor()`, the way out `drain_fuel` keeps,
## and the credits line never is. At the floor plus the reading's fuel it is
## allowed, and the drain then takes the whole amount.
func _science_gate() -> void:
	var o := OptionTable.by_id(&"the_spare_probe")
	var careful: Dictionary = o.choices[0]
	var risky: Dictionary = o.choices[1]
	var credits: Dictionary = o.choices[2]
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		if n.danger >= 1 and n.danger <= 4 and n.type == MapGen.NodeType.SYSTEM:
			Run.at = n.index
			break
	var keep := Run.fuel_floor()
	var cost := OptionTable.science_fuel()
	Run.fuel = keep + cost
	var open_at := OptionResolve.affordable(careful) and OptionResolve.affordable(risky)
	Run.data = 0
	careful.effect.call()
	var drained := Run.fuel == keep and Run.data == OptionTable.reading(1)
	Run.fuel = keep + cost - 1
	var shut := not OptionResolve.affordable(careful) and not OptionResolve.affordable(risky)
	var still := OptionResolve.affordable(credits)
	_ok("at the floor (%d) plus the reading's fuel (%d) a reading is open, and the drain takes it all" % [keep, cost],
		open_at and drained and keep > 0)
	_ok("one fuel short of that both readings are refused and the credits line is not", shut and still)
	Run.fuel = Run.FUEL_TANK


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
		# (`site`: a science reading's dry world or belt; its DATA lines' `burns`
		# and `reads` are choice keys, which `encounter_lint` check 10 reads)
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
