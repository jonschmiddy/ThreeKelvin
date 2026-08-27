class_name HeadlessSim
extends RefCounted
## Headless balance simulator.
##
##   godot --headless --path . -- sim runs=200
##
## This tool is worth as much as the game code. In the web prototype it found
## three real bugs (including an infinite draw loop) and a structural map flaw
## in minutes. Run it after any balance change.
##
## Driven by Main.gd's sim branch, NOT by --script. The sim reads the Run and DB
## autoloads, and Godot only creates autoloads when the project boots normally;
## --script replaces the main loop and skips them entirely, so every reference
## here would fail to compile.

var runs := 200
## `-- sim seed=N` gives run i the seed N+i, so a whole sweep is reproducible
## and any single run in it can be flown again by hand. Zero means roll fresh
## seeds, which is what a balance measurement wants.
var seed_base := 0
var pilot: RandomNumberGenerator = RandomNumberGenerator.new()
## Every decision this file used to make itself. Extracted so the party bot can
## fly the same model the gate measures — see scripts/sim/Policy.gd.
var policy: Policy = Policy.new()
## `-- sim hot` flips the fight policy from "never overheat" to "spend heat for
## tempo". The default model vents on sight and leaves every fight cold, which
## is a competent player and is also the one player the map heat layer can
## never touch. Measuring that layer needs somebody who actually runs hot.
var hot := false
var wins := 0
var deaths := 0
var errors := 0
var total_jumps := 0
var total_kills := 0
var total_danger := 0
var death_causes := {}
var stranded := 0
var stranded_no_fuel := 0

## The policy ran out of options. NOT the same as the run ending.
##
## `choose_jump` builds its candidates from `node.links`; the game lets you jump
## to anything inside a radius (`reachable_from`), and never consults `links` at
## all. So the policy giving up means "no CHARTED link was usable", which is a
## much weaker condition than "stranded" -- and it was being counted as one.
##
## Kept alongside `stranded` rather than replacing it, because THE GAP BETWEEN
## THEM IS THE SIZE OF THE BLIND SPOT, and that gap is the number that says
## whether any of this mattered.
var policy_gave_up := 0

## Fuel left in the tank when the run ended, summed.
##
## S3A_FUEL_SWEEP 6 asks for this by name, and it is the number that decides
## whether there is a fuel problem at all: a run that ends with most of a full
## tank did not end for want of fuel, whatever the strand counter says.
var end_fuel_total := 0

## Genuinely nowhere to go, at any price -- a MAP failure, not an economy one.
##
## Distinct from a dry tank: `stranded_no_fuel` means there were places to go and
## none affordable, this means the reachable set was empty. If this is ever
## non-zero the fuel ruling is aimed at the wrong thing entirely.
var stranded_nowhere := 0

## What the pilot did with what each system offered.
##
## `ENCOUNTER_REBUILD.md` 8 names `forgone` as the number the model must be able
## to report: an option lost because something else in its GROUP was taken
## first. It is the depth curve made visible -- counts stay flat and only the
## grouping moves, so if this stays near zero the exclusivity dial is not
## actually doing anything.
var opts_taken := 0
var opts_declined := 0
var opts_forgone := 0
var opts_fight := 0
var sites_with_options := 0
## The heat layer. Without these the sim can report that a heat change did
## nothing when what actually happened is that it never fired.
var ambushes := 0
var runs_ambushed := 0
var heat_samples := 0
var heat_total := 0.0
var hot_arrivals := 0
## Signature at the moment a fight ENDS, which is the only heat a run ever has
## a chance to carry onto the map. If this is near zero the map heat layer
## cannot matter no matter what is attached to it.
var postfight_samples := 0
var postfight_total := 0.0
var postfight_hot := 0
## The hellbender. `met` is landings on its system, because the first question
## about a roamer is whether a run even crosses its path; the rest is what the
## model did about it and what avoiding it cost in salvage.
var hellbender_met := 0
var hellbender_fights := 0
var hellbender_kills := 0
var hellbender_escapes := 0
var derelicts_eaten := 0

## Per galaxy kind: name -> {runs, wins, jumps, kills, systems}.
##
## NOT cleared by `_reset()`. That is called once per batch in the by-chassis
## sweep, and a per-kind table wants to span the whole sweep -- fifteen kinds
## across twenty-one chassis is already thin, and resetting it per chassis would
## leave every cell too small to read.
var by_kind: Dictionary = {}

## THE ECONOMY, which decided more runs than danger did and was invisible.
##
## Fuel and credits both flow through exactly two places -- a station, and the
## act of jumping -- so they are sampled by delta around those rather than by
## hooking RunState. A harness that edits the game to measure it is a harness
## that measures a different game.
var stations_visited := 0
var fuel_spent_jumping := 0
var fuel_from_stations := 0
var fuel_from_elsewhere := 0
var credits_at_stations := 0
var credits_from_elsewhere := 0

## Entry point. Reads `runs=N` from the user args after `--`, plays that many
## complete runs, and prints the report. The caller quits the tree.
func run_sim() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("runs="):
			runs = int(arg.split("=")[1])
		elif arg.begins_with("seed="):
			seed_base = int(arg.split("=")[1])
		# The vent thresholds, as fractions of heat capacity. See Policy.
		elif arg.begins_with("ventcold="):
			policy.vent_cold = float(arg.split("=")[1])
		elif arg.begins_with("venthot="):
			policy.vent_hot = float(arg.split("=")[1])

	# THE SECOND POLICY `ENCOUNTER_REBUILD.md` 8 ASKS FOR. A greedy model takes
	# every check it is offered, which overstates income and makes the shortfall
	# ladder look free. `-- sim riskaverse` declines below Policy.RISK_FLOOR and
	# pays for the caution in what it never collects; running both on one seed is
	# how the exclusivity dial gets argued with rather than assumed.
	policy.risk_averse = "riskaverse" in OS.get_cmdline_user_args()
	hot = "hot" in OS.get_cmdline_user_args()
	# The control cell. Comparing `nohellbender` against the default on one build
	# is what says what the roamer costs, without keeping a second checkout.
	Run.hellbender_off = "nohellbender" in OS.get_cmdline_user_args()
	policy.hot = hot
	if hot:
		print("HOT policy: the model spends heat for tempo and vents late.")
	print("vent thresholds: cold %.2f x cap · hot %.2f x cap"
		% [policy.vent_cold, policy.vent_hot])

	if "bychassis" in OS.get_cmdline_user_args():
		_run_by_chassis()
		return

	if seed_base != 0:
		print("Seeded sweep from %d. Run i uses seed %d + i." % [seed_base, seed_base])
	print("Three Kelvin — simulating %d runs" % runs)
	for i in runs:
		_play_one(&"", -1, i)
	_report()

## Every chassis in the game, `runs` each, reported as a table.
##
##   godot --headless --path . -- sim bychassis runs=500
##
## The ordinary sim rolls a random manufacturer and weight per run, which is
## right for "is the GAME winnable" and useless for "is this SHIP winnable" —
## twenty-one starts averaged into one number can hide a chassis that never wins
## behind six that do. This pins one and repeats it.
##
## Slow on purpose: at 500 each that is 10,500 complete runs. It is a thing you
## leave running, not a thing you put in the merge gate.
func _run_by_chassis() -> void:
	var weights := [HullData.Weight.LIGHT, HullData.Weight.MEDIUM, HullData.Weight.HEAVY]
	print("Three Kelvin — %d runs per chassis, %d chassis, %d runs total" % [
		runs, DB.STARTABLE.size() * weights.size(),
		runs * DB.STARTABLE.size() * weights.size()])
	print("%-18s %-8s %6s %6s %6s %6s   deaths" % [
		"chassis", "manufacturer", "wins", "win%", "jumps", "kills"])
	var rows: Array = []
	for manufacturer in DB.STARTABLE:
		for w in weights:
			_reset()
			for i in runs:
				_play_one(manufacturer, int(w))
			var hull := DB.hull_for(manufacturer, w)
			var rate := 100.0 * wins / maxi(1, runs)
			rows.append({name = hull.name, rate = rate})
			print("%-18s %-8s %6d %5.1f%% %6.1f %6.1f   %s" % [
				hull.name, DB.short_name(DB.manufacturer_name(manufacturer)), wins, rate,
				float(total_jumps) / runs, float(total_kills) / runs,
				str(death_causes)])
	# Sorted afterwards, because the table above is grouped by manufacturer for reading
	# and this is the ranking you actually act on.
	rows.sort_custom(func(a, b): return a.rate > b.rate)
	print("\n--- ranked ---")
	for r in rows:
		print("%-18s %5.1f%%" % [r.name, r.rate])

## Zero the counters between chassis. Without this every row would report the
## running total of every chassis before it, which looks like a table and is not.
func _reset() -> void:
	wins = 0
	deaths = 0
	errors = 0
	total_jumps = 0
	total_kills = 0
	total_danger = 0
	death_causes = {}
	stranded = 0
	stranded_no_fuel = 0
	policy_gave_up = 0
	end_fuel_total = 0
	stranded_nowhere = 0
	opts_taken = 0
	opts_declined = 0
	opts_forgone = 0
	opts_fight = 0
	sites_with_options = 0
	ambushes = 0
	runs_ambushed = 0
	heat_samples = 0
	heat_total = 0.0
	hot_arrivals = 0
	postfight_samples = 0
	postfight_total = 0.0
	postfight_hot = 0
	hellbender_met = 0
	hellbender_fights = 0
	hellbender_kills = 0
	hellbender_escapes = 0
	derelicts_eaten = 0

## `index` exists so that `-- sim seed=N` gives every run its own reproducible
## seed rather than playing one run a thousand times. A sim that reports "40% of
## runs strand" is only actionable if one of those runs can be handed back:
## `-- seed <the number printed with the death>` flies it again exactly.
func _play_one(manufacturer: StringName = &"", w: int = -1, index: int = 0) -> void:
	Rng.forced = (seed_base + index) if seed_base != 0 else 0
	Run.start_new_run(manufacturer, w)
	# The simulated pilot's own generator: one per run, seeded from the run's
	# master seed. The model is a player, not a place — so its choices replay
	# with the run, and drawing them does not move what the world rolls next.
	#
	# NOT derived per jump, which is what this was first. Rng.derive() keys on
	# a position, and `Run.jumps` is not one: jump_to() returns without
	# incrementing when a jump turns out to be unaffordable, so two loop passes
	# could share an index, hand back the same generator and make the same
	# choice twice. The model wandered laterally in circles and reported 94
	# jumps a run against a real figure of 66 — a policy bug produced entirely
	# by seeding a decision on something that was not a place.
	pilot = Rng.derive(&"pilot", 0)
	policy.pilot = pilot
	policy.begin_run()
	var guard := 0
	var jumped_hot := false
	while not Run.won and not Run.dead and guard < 600:
		guard += 1
		var node: MapGen.MapNode = Run.node_at()

		# How hot the model actually arrives, sampled before anything here is
		# resolved. This is the number every other heat rule keys off, so a
		# report that omits it cannot explain its own win rate.
		heat_samples += 1
		heat_total += Run.signature()
		if Run.signature() > Run.SIGNATURE_FLOOR:
			hot_arrivals += 1

		# Something followed the heat in, through the SAME function the game
		# uses. This comment used to claim it was "rolled exactly as Router does
		# it on arrival" and it was not: Router rolls the pack positionally via
		# `_roll_foes`, and this picked ONE enemy off `Rng.foe` from a pool that
		# always passed `false` for fauna. Two implementations, one of them
		# measuring the other.
		if not node.ambush_rolled and node.type != MapGen.NodeType.FIGHT \
				and node.type != MapGen.NodeType.GOAL:
			node.ambush_rolled = true
			if Rng.foe.randf() < Run.ambush_chance(node):
				ambushes += 1
				jumped_hot = true
				var pack := Router._roll_foes(node)
				if not pack.is_empty() and not _fight(DB.enemies[pack[0]]):
					break

		# The hellbender holds this system. Same blockade the game enforces in
		# Router.resolve_current_node(): nothing here is reachable past it, so
		# the model fights it or flies on with the node unresolved. A break-off
		# lifts the blockade in place — it jumps two hops out — which is why
		# the flag is re-read after the fight.
		var blockaded := Run.hellbender_alive() and Run.hellbender_at == Run.at
		if blockaded:
			hellbender_met += 1
			if policy.engage_hellbender():
				hellbender_fights += 1
				if not _fight_hellbender():
					break
				blockaded = Run.hellbender_alive() and Run.hellbender_at == Run.at

		# Resolve whatever is here.
		if blockaded:
			pass
		elif node.type == MapGen.NodeType.FIGHT and not node.cleared:
			var pool := DB.fight_pool(node.danger, node.region == MapGen.Region.FAUNA)
			if not _fight(DB.enemies[Rng.pick(Rng.foe, pool)]):
				break
		elif node.type == MapGen.NodeType.GOAL:
			_fight(DB.enemies[&"custodian"])
			break
		elif node.type == MapGen.NodeType.STATION:
			stations_visited += 1
			var sf := Run.fuel
			var sc := Run.credits
			policy.shop(Run.node_at())
			fuel_from_stations += maxi(0, Run.fuel - sf)
			credits_at_stations += Run.credits - sc
		elif node.type == MapGen.NodeType.PULSAR and not node.cleared:
			# Always taken. A competent player does not walk past the best fuel
			# in the galaxy — the question the model cannot answer is whether
			# the hull cost is worth it, which is exactly what the win rate is
			# for.
			Run.harvest_pulsar()
			if Run.dead:
				break
		elif node.type == MapGen.NodeType.DERELICT and not node.cleared:
			Run.consume_node(node)
			Run.place_in_hold(LootGen.roll_module(node.danger))
		# WHAT THE SYSTEM OFFERS, taken by the policy rather than by the type.
		#
		# Additive for now: the node types above still resolve as they always
		# have, and this runs beside them. Phase 8 is where `NodeType` collapses
		# and the two stop being separate questions.
		if not node.cleared:
			var got := policy.take_options(node)
			if int(got.taken) + int(got.declined) + int(got.forgone) + int(got.fights) > 0:
				sites_with_options += 1
			opts_taken += int(got.taken)
			opts_declined += int(got.declined)
			opts_forgone += int(got.forgone)
			opts_fight += int(got.fights)
			if Run.dead:
				break
		policy.manage_cargo()

		# Farm laterally while healthy enough, then descend. The choice itself
		# lives in Policy; what stays here is the ACCOUNTING for the case where
		# there is no choice, which is a measurement rather than a decision.
		var pick := policy.choose_jump(node)
		if pick < 0:
			# F1 -- A STRAND IS WHAT THE GAME SAYS IT IS. This used to call
			# `check_stranded()` and then increment regardless of what it did:
			# the counter tracked the POLICY giving up, not the run ending.
			# `check_stranded` returns void and dies internally, so ask the same
			# question it asks.
			policy_gave_up += 1
			Run.check_stranded()
			if Run.has_legal_jump():
				# The policy is out of charted links but the ship can still
				# fly. Not a strand, and the old counter called it one.
				break
			stranded += 1
			# F2 -- OVER THE SET THE GAME USES, AND ALL OF IT. This used to walk
			# `node.links` and break on the FIRST unaffordable one, so it meant
			# "at least one link was too dear" rather than "nothing was
			# affordable" -- over the wrong set, in the wrong direction.
			var any_reachable := false
			var any_affordable := false
			for n in Run.in_range_of(node):
				any_reachable = true
				if Run.fuel >= Run.fuel_cost_to(n):
					any_affordable = true
					break
			if not any_reachable:
				stranded_nowhere += 1
			elif not any_affordable:
				stranded_no_fuel += 1
			break
		# EVERYTHING THAT IS NOT A JUMP AND NOT A STATION, caught as the
		# remainder: fights, derelicts, pulsars and events all move these and
		# instrumenting each one separately would be five more places to keep
		# in step with the loop above.
		var jf := Run.fuel
		var jc := Run.credits
		Run.jump_to(pick)
		fuel_spent_jumping += maxi(0, jf - Run.fuel)

	if jumped_hot:
		runs_ambushed += 1
	for n in Run.map:
		if (n as MapGen.MapNode).eaten:
			derelicts_eaten += 1
	total_jumps += Run.jumps
	total_kills += Run.kills
	total_danger += Run.node_at().danger
	end_fuel_total += Run.fuel
	if Run.won:
		wins += 1
	if Run.dead:
		deaths += 1
		var key := Run.death_reason.substr(0, 24)
		death_causes[key] = int(death_causes.get(key, 0)) + 1

	# WHICH GALAXY THIS RUN HAPPENED IN. Read after the run rather than before,
	# because `start_new_run` is what rolls the kind and the map it implies.
	var kind := GalaxyGen.type_name(Run.galaxy_kind)
	var row: Dictionary = by_kind.get(kind, {
		"runs": 0, "wins": 0, "jumps": 0, "kills": 0, "systems": 0,
	})
	row.runs += 1
	row.wins += 1 if Run.won else 0
	row.jumps += Run.jumps
	row.kills += Run.kills
	row.systems += Run.map.size()
	by_kind[kind] = row

## Competent-player model: lock on before attacking, brace against telegraphed
## damage, vent before overheating, and never overheat unless it secures a kill.
func _fight(template: EnemyTemplate) -> bool:
	var cb := Combat.new()
	cb.start(template, Run.node_at().danger)
	var turns := 0
	while not cb.finished and turns < 60:
		turns += 1
		var acted := true
		while acted and not cb.finished:
			acted = false
			# Answer any pending pick first. Nothing is playable while one is
			# open, so a loop that only ever asked for a card would decide the
			# turn was over and end it with the choice unmade.
			while cb.choosing > 0:
				cb.choose(cb.best_choice())
				acted = true
			var best := policy.best_card(cb)
			if best >= 0:
				cb.play(best)
				acted = true
		if not cb.finished:
			cb.end_turn()
	postfight_samples += 1
	postfight_total += Run.signature()
	if Run.signature() > Run.SIGNATURE_FLOOR:
		postfight_hot += 1
	return not Run.dead


## The set piece, carried damage and all. Differs from _fight() in exactly the
## ways the game does: the enemy opens at the hull the map says it has, winning
## does not consume the system, and there are three endings — it dies, it
## leaves, or you do.
func _fight_hellbender() -> bool:
	var cb := Combat.new()
	cb.clears_node = false
	cb.plan(DB.enemies[&"hellbender"], Run.node_at().danger)
	cb.enemies[0].hp = clampi(Run.hellbender_hp, 1, cb.enemies[0].max_hp)
	cb.enemies[0].pick_intent()
	cb.begin(null)
	var turns := 0
	while not cb.finished and turns < 60:
		turns += 1
		var acted := true
		while acted and not cb.finished:
			acted = false
			var best := policy.best_card(cb)
			if best >= 0:
				cb.play(best)
				acted = true
		if not cb.finished:
			cb.end_turn()
	if cb.result == &"victory":
		hellbender_kills += 1
	elif cb.result == &"broke_off":
		hellbender_escapes += 1
	postfight_samples += 1
	postfight_total += Run.signature()
	if Run.signature() > Run.SIGNATURE_FLOOR:
		postfight_hot += 1
	return not Run.dead


func _report() -> void:
	print("---")
	print("runs %d · wins %d (%.0f%%) · deaths %d · errors %d" % [
		runs, wins, 100.0 * wins / maxi(1, runs), deaths, errors])
	print("avg jumps %.1f · avg kills %.1f · avg danger reached %.2f" % [
		float(total_jumps) / runs, float(total_kills) / runs, float(total_danger) / runs])
	print("death causes: %s" % str(death_causes))
	# These ARE counted in deaths: check_stranded() ends the run rather than
	# leaving the ship alive and immobile. Reported separately because a fuel
	# death is an economy failure, not a combat one.
	print("stranded, ended by check_stranded() %d (%.1f%%) · dry tank %d · nowhere in range %d" % [
		stranded, 100.0 * stranded / maxi(1, runs), stranded_no_fuel,
		stranded_nowhere])
	# THE BLIND SPOT, printed on its own line because it is the point of S1.
	# `policy_gave_up` counts the policy running out of CHARTED links;
	# `stranded` counts the ship being unable to fly. Every run in the gap is one
	# the old counter called stranded and the game did not.
	print("fuel left at run end: %.0f of a %d tank (%.0f%%)" % [
		float(end_fuel_total) / maxi(1, runs),
		int(round(Run.FUEL_PER_RING_STEP * float(MapGen.LAYERS - 2))),
		100.0 * (float(end_fuel_total) / maxi(1, runs))
			/ maxf(1.0, Run.FUEL_PER_RING_STEP * float(MapGen.LAYERS - 2))])
	if sites_with_options > 0:
		print("options: %d systems offered them · %.2f taken, %.2f declined, %.2f FORGONE per system"
			% [sites_with_options,
				float(opts_taken) / float(sites_with_options),
				float(opts_declined) / float(sites_with_options),
				float(opts_forgone) / float(sites_with_options)])
		if policy.checks_avoided > 0:
			print("  %.2f checks a system refused for long odds -- what caution costs"
				% [float(policy.checks_avoided) / float(sites_with_options)])
		if opts_fight > 0:
			print("  %d fight lines skipped -- phase 8 is where the sim can run one"
				% opts_fight)
	print("policy gave up %d (%.1f%%) · of those, the ship could still fly %d" % [
		policy_gave_up, 100.0 * policy_gave_up / maxi(1, runs),
		policy_gave_up - stranded])
	# The heat layer, reported separately because it is the newest thing in the
	# economy and the first question about any tuning pass on it is whether it
	# fired at all.
	print("heat: avg signature on arrival %.2f · arrived hot %d of %d (%.1f%%)" % [
		heat_total / maxf(1.0, float(heat_samples)), hot_arrivals, heat_samples,
		100.0 * hot_arrivals / maxi(1, heat_samples)])
	print("post-fight signature %.2f · left a fight hot %d of %d (%.1f%%)" % [
		postfight_total / maxf(1.0, float(postfight_samples)), postfight_hot,
		postfight_samples, 100.0 * postfight_hot / maxi(1, postfight_samples)])
	print("hellbender: met %d · engaged %d · killed %d · watched it escape %d · derelicts eaten %.2f/run" % [
		hellbender_met, hellbender_fights, hellbender_kills, hellbender_escapes,
		float(derelicts_eaten) / maxi(1, runs)])
	print("ambushes %d (%.2f per run) · runs jumped at least once %d (%.1f%%)" % [
		ambushes, float(ambushes) / maxi(1, runs), runs_ambushed,
		100.0 * runs_ambushed / maxi(1, runs)])
	_report_economy()
	_report_kinds()
	print("---")
	print("Healthy target: 40-55% win rate for this competent-player model.")
	print("Too easy? Raise station repair prices before touching enemy damage —")
	print("this design's difficulty lives in the economy, not in single fights.")


## What each galaxy kind actually played like.
##
## FIFTEEN KINDS THAT ARE NOT THE SAME GAME. `GalaxyGen`'s header claims the
## shape of a galaxy cannot move a jump or a fuel cost; it can and does, because
## `MapGen.ring_count()` reads `squash` and `hop_distance()` measures in squashed
## space. A Lenticular is a smaller galaxy whose hops are cheaper. So a single
## win rate is an average over fifteen different games, and the moment that
## variation becomes DELIBERATE -- authored `density` and `reach` per kind -- it
## has to be readable or there is no way to tell a tuning change from a roll.
##
## SYSTEMS IS THE COLUMN TO WATCH during the galaxy resize: it is the number
## `LAYERS` and `RING_SPACING` move, and the one that says whether a change did
## what it claimed.
##
## Sorted by win rate, so the spread is the first thing visible. A kind with a
## handful of runs is noise -- the count is printed so it can be discounted.
func _report_kinds() -> void:
	if by_kind.is_empty():
		return
	print("---")
	print("by galaxy kind:")
	print("  %-22s %5s %6s %7s %7s %8s"
		% ["kind", "runs", "win%", "jumps", "kills", "systems"])
	var rows: Array = []
	for k in by_kind:
		var v: Dictionary = by_kind[k]
		var n: int = maxi(1, int(v.runs))
		rows.append({
			name = k,
			runs = int(v.runs),
			rate = 100.0 * float(v.wins) / float(n),
			jumps = float(v.jumps) / float(n),
			kills = float(v.kills) / float(n),
			systems = float(v.systems) / float(n),
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.rate) > float(b.rate))
	for r in rows:
		var row: Dictionary = r
		print("  %-22s %5d %5.0f%% %7.1f %7.1f %8.1f"
			% [row.name, row.runs, row.rate, row.jumps, row.kills, row.systems])
	# THE SPREAD, said out loud. Two kinds thirty points apart is the whole
	# reason this table exists, and it should not need reading off the rows.
	if rows.size() > 1:
		var hi: Dictionary = rows[0]
		var lo: Dictionary = rows[rows.size() - 1]
		print("  spread: %s %.0f%% down to %s %.0f%% (%.0f points across %d kinds)"
			% [hi.name, hi.rate, lo.name, lo.rate,
				float(hi.rate) - float(lo.rate), rows.size()])


## Where fuel and credits came from and went, per run.
##
## THE LARGEST DEATH CAUSES ARE ECONOMIC. Runs end adrift with a dry tank or
## holed because repairs were unaffordable, and neither is visible in a report
## that only counts corpses. This is the sheet that says whether a galaxy is
## payable at all.
##
## FUEL EARNED PER JUMP is the number to watch when the galaxy is resized: a
## bigger map costs more fuel to cross, and if income per system does not keep
## pace the run simply runs out of road however large the tank starts.
func _report_economy() -> void:
	var r := float(maxi(1, runs))
	var j := float(maxi(1, total_jumps))
	print("---")
	print("economy per run: %.1f stations · fuel %.0f spent jumping, %.0f from stations, %.0f elsewhere"
		% [float(stations_visited) / r, float(fuel_spent_jumping) / r,
			float(fuel_from_stations) / r, float(fuel_from_elsewhere) / r])
	print("  fuel per jump: %.2f spent · %.2f earned  (net %+.2f)"
		% [float(fuel_spent_jumping) / j,
			float(fuel_from_stations + fuel_from_elsewhere) / j,
			float(fuel_from_stations + fuel_from_elsewhere - fuel_spent_jumping) / j])
	print("  credits: %+.0f net at stations per run" % [float(credits_at_stations) / r])
