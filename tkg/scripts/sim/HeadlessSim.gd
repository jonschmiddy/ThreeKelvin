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
## The stoker. `met` is landings on its system, because the first question
## about a roamer is whether a run even crosses its path; the rest is what the
## model did about it and what avoiding it cost in salvage.
var stoker_met := 0
var stoker_fights := 0
var stoker_kills := 0
var stoker_escapes := 0
var derelicts_eaten := 0

## Entry point. Reads `runs=N` from the user args after `--`, plays that many
## complete runs, and prints the report. The caller quits the tree.
func run_sim() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("runs="):
			runs = int(arg.split("=")[1])
		elif arg.begins_with("seed="):
			seed_base = int(arg.split("=")[1])

	hot = "hot" in OS.get_cmdline_user_args()
	# The control cell. Comparing `nostoker` against the default on one build
	# is what says what the roamer costs, without keeping a second checkout.
	Run.stoker_off = "nostoker" in OS.get_cmdline_user_args()
	policy.hot = hot
	if hot:
		print("HOT policy: the model spends heat for tempo and vents late.")

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
		"chassis", "maker", "wins", "win%", "jumps", "kills"])
	var rows: Array = []
	for man in DB.STARTABLE:
		for w in weights:
			_reset()
			for i in runs:
				_play_one(man, int(w))
			var hull := DB.hull_for(man, w)
			var rate := 100.0 * wins / maxi(1, runs)
			rows.append({name = hull.name, rate = rate})
			print("%-18s %-8s %6d %5.1f%% %6.1f %6.1f   %s" % [
				hull.name, DB.short_name(DB.manufacturer_name(man)), wins, rate,
				float(total_jumps) / runs, float(total_kills) / runs,
				str(death_causes)])
	# Sorted afterwards, because the table above is grouped by maker for reading
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
	ambushes = 0
	runs_ambushed = 0
	heat_samples = 0
	heat_total = 0.0
	hot_arrivals = 0
	postfight_samples = 0
	postfight_total = 0.0
	postfight_hot = 0
	stoker_met = 0
	stoker_fights = 0
	stoker_kills = 0
	stoker_escapes = 0
	derelicts_eaten = 0

## `index` exists so that `-- sim seed=N` gives every run its own reproducible
## seed rather than playing one run a thousand times. A sim that reports "40% of
## runs strand" is only actionable if one of those runs can be handed back:
## `-- seed <the number printed with the death>` flies it again exactly.
func _play_one(man: StringName = &"", w: int = -1, index: int = 0) -> void:
	Rng.forced = (seed_base + index) if seed_base != 0 else 0
	Run.start_new_run(man, w)
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

		# Something followed the heat in. Rolled exactly as Router does it on
		# arrival — a model that never gets jumped cannot measure whether
		# getting jumped matters.
		if not node.ambush_rolled and node.type != MapGen.NodeType.FIGHT \
				and node.type != MapGen.NodeType.GOAL:
			node.ambush_rolled = true
			if Rng.foe.randf() < Run.ambush_chance(node):
				ambushes += 1
				jumped_hot = true
				var apool := DB.fight_pool(node.danger, false)
				if not _fight(DB.enemies[Rng.pick(Rng.foe, apool)]):
					break

		# The stoker holds this system. Same blockade the game enforces in
		# Router.resolve_current_node(): nothing here is reachable past it, so
		# the model fights it or flies on with the node unresolved. A break-off
		# lifts the blockade in place — it jumps two hops out — which is why
		# the flag is re-read after the fight.
		var blockaded := Run.stoker_alive() and Run.stoker_at == Run.at
		if blockaded:
			stoker_met += 1
			if policy.engage_stoker():
				stoker_fights += 1
				if not _fight_stoker():
					break
				blockaded = Run.stoker_alive() and Run.stoker_at == Run.at

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
			policy.shop(Run.node_at())
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
			Run.cargo.append(LootGen.roll_module(node.danger))
		policy.manage_cargo()

		# Farm laterally while healthy enough, then descend. The choice itself
		# lives in Policy; what stays here is the ACCOUNTING for the case where
		# there is no choice, which is a measurement rather than a decision.
		var pick := policy.choose_jump(node)
		if pick < 0:
			Run.check_stranded()
			stranded += 1
			for idx in node.links:
				if Run.fuel < Run.fuel_cost_to(Run.map[idx]):
					stranded_no_fuel += 1
					break
			break
		Run.jump_to(pick)

	if jumped_hot:
		runs_ambushed += 1
	for n in Run.map:
		if (n as MapGen.MapNode).eaten:
			derelicts_eaten += 1
	total_jumps += Run.jumps
	total_kills += Run.kills
	total_danger += Run.node_at().danger
	if Run.won:
		wins += 1
	if Run.dead:
		deaths += 1
		var key := Run.death_reason.substr(0, 24)
		death_causes[key] = int(death_causes.get(key, 0)) + 1

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
func _fight_stoker() -> bool:
	var cb := Combat.new()
	cb.clears_node = false
	cb.plan(DB.enemies[&"stoker"], Run.node_at().danger)
	cb.enemies[0].hp = clampi(Run.stoker_hp, 1, cb.enemies[0].max_hp)
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
		stoker_kills += 1
	elif cb.result == &"broke_off":
		stoker_escapes += 1
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
	print("stranded, ended by check_stranded() %d (%.1f%%) · of those, blocked by fuel %d" % [
		stranded, 100.0 * stranded / maxi(1, runs), stranded_no_fuel])
	# The heat layer, reported separately because it is the newest thing in the
	# economy and the first question about any tuning pass on it is whether it
	# fired at all.
	print("heat: avg signature on arrival %.2f · arrived hot %d of %d (%.1f%%)" % [
		heat_total / maxf(1.0, float(heat_samples)), hot_arrivals, heat_samples,
		100.0 * hot_arrivals / maxi(1, heat_samples)])
	print("post-fight signature %.2f · left a fight hot %d of %d (%.1f%%)" % [
		postfight_total / maxf(1.0, float(postfight_samples)), postfight_hot,
		postfight_samples, 100.0 * postfight_hot / maxi(1, postfight_samples)])
	print("stoker: met %d · engaged %d · killed %d · watched it escape %d · derelicts eaten %.2f/run" % [
		stoker_met, stoker_fights, stoker_kills, stoker_escapes,
		float(derelicts_eaten) / maxi(1, runs)])
	print("ambushes %d (%.2f per run) · runs jumped at least once %d (%.1f%%)" % [
		ambushes, float(ambushes) / maxi(1, runs), runs_ambushed,
		100.0 * runs_ambushed / maxi(1, runs)])
	print("---")
	print("Healthy target: 40-55% win rate for this competent-player model.")
	print("Too easy? Raise station repair prices before touching enemy damage —")
	print("this design's difficulty lives in the economy, not in single fights.")
