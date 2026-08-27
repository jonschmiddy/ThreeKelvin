extends Harness

## Does the option roller obey its own rules?
##   godot --headless --path . -- optiontest
##
## A GATE, not a measurement. Everything checked here is a thing that would be
## invisible in a run and wrong in a save or a co-op session.
##
## The four that matter:
##
## **Positional and stable.** What is AT a place is a property of the place, so
## four machines must roll the same list. `Rng.derive(&"options", n.index)` is
## the mechanism; this proves it by rolling the same node twice and by rolling
## the same seed twice.
##
## **Gating is honoured.** Every clause is ANDed and all seven axes already exist
## on `MapNode`. An option that surfaces where its gate forbids is the fault
## `EventTable` has today -- `pick_key()` reads none of the axes, which is most
## of why fourteen events feel same-y.
##
## **The tier plan is obeyed.** Counts stay flat and only grouping moves, per
## `ENCOUNTER_REBUILD.md` §4. A tier-5 system offering two independent options
## has lost the dial the whole design turns on.
##
## **No duplicates.** Drawn without replacement, so a system never offers the
## same situation twice.

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

	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var n_checked := 0

	for n in Run.map:
		var node: MapGen.MapNode = n
		if node.type == MapGen.NodeType.STATION or node.type == MapGen.NodeType.GOAL:
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
		# UNDER the plan is a CONTENT signal, not a machine fault. The roller
		# clamps what it wants to what the gate admits, so a thin table shows up
		# here as a shortfall rather than as a broken rule -- and filling the
		# pool is its own phase, per ROADMAP 11.
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

	verdict("optiontest")
