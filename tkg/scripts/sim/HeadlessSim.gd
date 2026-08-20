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

## Entry point. Reads `runs=N` from the user args after `--`, plays that many
## complete runs, and prints the report. The caller quits the tree.
func run_sim() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("runs="):
			runs = int(arg.split("=")[1])
		elif arg.begins_with("seed="):
			seed_base = int(arg.split("=")[1])

	hot = "hot" in OS.get_cmdline_user_args()
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

		# Resolve whatever is here.
		if node.type == MapGen.NodeType.FIGHT and not node.cleared:
			var pool := DB.fight_pool(node.danger, node.region == MapGen.Region.FAUNA)
			if not _fight(DB.enemies[Rng.pick(Rng.foe, pool)]):
				break
		elif node.type == MapGen.NodeType.GOAL:
			_fight(DB.enemies[&"custodian"])
			break
		elif node.type == MapGen.NodeType.STATION:
			_shop()
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
		_manage_cargo()

		# Farm laterally while healthy enough, then descend.
		var options: Array[int] = []
		for idx in node.links:
			if Run.can_jump_to(Run.map[idx]):
				options.append(idx)
		if options.is_empty():
			Run.check_stranded()
			stranded += 1
			for idx in node.links:
				if Run.fuel < Run.fuel_cost_to(Run.map[idx]):
					stranded_no_fuel += 1
					break
			break
		var lateral: Array[int] = []
		var forward: Array[int] = []
		for idx in options:
			var t: MapGen.MapNode = Run.map[idx]
			if t.layer == node.layer and not t.cleared:
				lateral.append(idx)
			elif t.layer > node.layer:
				forward.append(idx)
		var healthy := Run.hp > Run.max_hp() * 0.6
		# A COMPETENT PLAYER WATCHES THE TANK.
		#
		# This used to farm laterally on a 65% coin whatever the fuel gauge said,
		# and always when hurt — so the model wandered until it ran dry, and the
		# average run came out at 117 jumps. That is not a fact about the game;
		# it is a fact about this loop. Tuning the fuel economy to bring the
		# number down would have been tuning the game against a model artifact,
		# and it would have made the real game punitive to fix a bug in here.
		#
		# Farming is what you do when you can afford it. With the tank low, the
		# only move that ends well is onward — and a player who has decided to
		# descend descends whether or not they are healthy, because sitting still
		# does not heal you.
		var can_wander := Run.fuel > 45
		var pick := -1
		if not lateral.is_empty() and can_wander and (not healthy or pilot.randf() < 0.65):
			pick = Rng.pick(pilot, lateral)
		elif not forward.is_empty():
			pick = Rng.pick(pilot, forward)
		else:
			pick = Rng.pick(pilot, options)
		Run.jump_to(pick)

	if jumped_hot:
		runs_ambushed += 1
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
			var best := -1
			var best_score := 0.0
			for i in cb.hand.size():
				var c := cb.hand[i]
				if not cb.can_play(c):
					continue
				var projected := Run.heat + c.heat - Run.dissipation()
				# The hot model tolerates sitting over capacity; the cold one
				# only crosses it to close out a kill. Same ceiling either way,
				# so neither is suicidal — the difference is how long it is
				# willing to stay up there.
				var ceiling := Run.heat_cap() + (12 if hot else 3)
				if projected > ceiling and c.heat > 0 and cb.enemy.hp > 30:
					continue
				var s := _score(c, cb)
				if s > best_score:
					best_score = s
					best = i
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

func _score(c: CardData, cb: Combat) -> float:
	if c.unplayable:
		return -1.0
	var incoming := 0
	if cb.enemy.intent != null:
		incoming = cb.enemy.intent.damage * maxi(1, cb.enemy.intent.hits)
	if c.energy_gain > 0:
		return 95.0
	if c.lock_on > 0:
		return 90.0
	# Venting is the first thing the cold model reaches for and nearly the last
	# thing the hot one does. This single threshold is most of the difference
	# between the two policies.
	if c.vent > 0 and Run.heat > Run.heat_cap() * (1.15 if hot else 0.7):
		return 85.0
	if (c.armor > 0 or c.block > 0) and incoming > cb.armor + cb.block:
		return 80.0
	if c.heal > 0 and Run.hp < Run.max_hp() * 0.5:
		return 75.0
	if c.draw > 0 and c.damage == 0:
		return 70.0
	if c.charge_turns > 0:
		return 65.0
	if c.damage > 0:
		return 40.0 + float(c.damage * maxi(1, c.hits)) / 4.0
	return 5.0

## Dock. Sell first, then spend — which is what a player does, and which is the
## only order that lets a hold full of salvage pay for the repair.
##
## The model deliberately does NOT buy stock to resell. Trade routes are a
## strategy the player can find; assuming a competent player already runs one
## would report a win rate for a game nobody has played yet. What this measures
## is the FLOOR of the new economy: sell what you were going to melt anyway,
## fabricate when it is cheaper than buying the same effect.
func _shop() -> void:
	var n: MapGen.MapNode = Run.node_at()
	_sell_hold(n)
	_bench(n)

	var missing := Run.max_hp() - Run.hp
	var repair := Market.repair_price(n, missing)
	if missing > 0 and Run.credits > repair + 25:
		Run.add_credits(-repair)
		Run.heal(missing)
	var refuel := Market.refuel_price(n)
	if Run.fuel < 8 and Run.credits >= refuel:
		Run.add_credits(-refuel)
		Run.fuel += Market.REFUEL_UNITS

## Anything left in the hold at a station was already destined for scrapping —
## _manage_cargo() ran on arrival and kept what was worth installing. So take
## whichever of the two prices is higher, which is the one decision selling
## actually adds.
func _sell_hold(n: MapGen.MapNode) -> void:
	var guard := 0
	while not Run.cargo.is_empty() and guard < 24:
		guard += 1
		var m: ModuleData = Run.cargo[0]
		var paid := Market.bid(n, m)
		if paid > Run.scrap_value_of(m):
			Run.cargo.erase(m)
			Run.add_credits(paid)
			n.trades += 1
		else:
			Run.scrap_module(m)

## Fabricate whatever is both affordable and better value than buying the same
## thing off the service desk. Hull patches and fuel synthesis are the two that
## compete directly with a price on the same screen, so they are the two the
## model can judge; the other recipes are build decisions it has no opinion on.
func _bench(n: MapGen.MapNode) -> void:
	for r in Fabricator.available(n):
		var guard := 0
		while Fabricator.can_make(n, r) and guard < 6:
			guard += 1
			match StringName(r.id):
				&"patch":
					if Run.max_hp() - Run.hp < int(r.amount):
						break
					if Fabricator.price(n, r) >= Market.repair_price(n, int(r.amount)):
						break
				&"cracker":
					if Run.fuel > 40:
						break
					if Fabricator.price(n, r) >= Market.refuel_price(n):
						break
				_:
					break
			if Fabricator.make(n, r).is_empty():
				break

## Install what improves the ship; carry a few of the rest to the next market.
##
## The model used to melt everything it did not install, the instant it picked it
## up. That was correct when melting was the only thing you could do with a part
## and it is not any more — a hold that is always empty means the simulator can
## never once exercise the thing this economy is built around, and would report a
## win rate for a game with no market in it.
##
## HOLD_LIMIT is the honest half, and it is a BEHAVIOUR rather than a capacity —
## hulls hold 8 / 12 / 16. A competent player does not haul twenty parts around
## hoping for a buyer; they keep the few worth a detour and scrap the rest where
## they stand. Scrapping the cheapest first is what makes it a hold rather than a
## queue. It must stay at or under the smallest hull's capacity, or the model
## would be measuring a hold no ship in the game has.
const HOLD_LIMIT := 4

func _manage_cargo() -> void:
	var guard := 0
	var passed: Array[ModuleData] = []
	while not Run.cargo.is_empty() and guard < 24:
		guard += 1
		var m: ModuleData = Run.cargo[0]
		var free := Run.slots_used(m.slot) < Run.slots_for(m.slot)
		var worst: ModuleData = null
		for x in Run.installed:
			if x.slot == m.slot and (worst == null or x.scrap_value < worst.scrap_value):
				worst = x
		if free or (worst != null and m.scrap_value > worst.scrap_value * 1.15):
			Run.install_module(m)
		else:
			# Out of the queue and into the hold, so the loop terminates.
			Run.cargo.erase(m)
			passed.append(m)
	for m in passed:
		Run.cargo.append(m)
	while Run.cargo.size() > HOLD_LIMIT:
		var cheapest: ModuleData = Run.cargo[0]
		for m in Run.cargo:
			if Market.base_value(m) < Market.base_value(cheapest):
				cheapest = m
		Run.scrap_module(cheapest)
	if Run.found_hull != null:
		if Run.found_hull.max_hull > Run.max_hp() or Run.found_hull.tier > Run.hull.tier:
			Run.transfer_to_hull(Run.found_hull)
		else:
			Run.found_hull = null

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
	print("ambushes %d (%.2f per run) · runs jumped at least once %d (%.1f%%)" % [
		ambushes, float(ambushes) / maxi(1, runs), runs_ambushed,
		100.0 * runs_ambushed / maxi(1, runs)])
	print("---")
	print("Healthy target: 40-55% win rate for this competent-player model.")
	print("Too easy? Raise station repair prices before touching enemy damage —")
	print("this design's difficulty lives in the economy, not in single fights.")
