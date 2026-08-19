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
var wins := 0
var deaths := 0
var errors := 0
var total_jumps := 0
var total_kills := 0
var total_danger := 0
var death_causes := {}
var stranded := 0
var stranded_no_fuel := 0

## Entry point. Reads `runs=N` from the user args after `--`, plays that many
## complete runs, and prints the report. The caller quits the tree.
func run_sim() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("runs="):
			runs = int(arg.split("=")[1])

	print("Three Kelvin — simulating %d runs" % runs)
	for i in runs:
		_play_one()
	_report()

func _play_one() -> void:
	Run.start_new_run()
	var guard := 0
	while not Run.won and not Run.dead and guard < 600:
		guard += 1
		var node: MapGen.MapNode = Run.node_at()
		# Resolve whatever is here.
		if node.type == MapGen.NodeType.FIGHT and not node.cleared:
			var pool := DB.fight_pool(node.danger, node.region == MapGen.Region.FAUNA)
			if not _fight(DB.enemies[pool.pick_random()]):
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
			node.cleared = true
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
		var pick := -1
		if not lateral.is_empty() and (not healthy or randf() < 0.65):
			pick = lateral.pick_random()
		elif not forward.is_empty() and healthy:
			pick = forward.pick_random()
		else:
			pick = options.pick_random()
		Run.jump_to(pick)

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
				if projected > Run.heat_cap() + 3 and c.heat > 0 and cb.enemy.hp > 30:
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
	if c.vent > 0 and Run.heat > Run.heat_cap() * 0.7:
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

func _shop() -> void:
	var rate := Run.repair_cost_per_hull()
	var missing := Run.max_hp() - Run.hp
	if missing > 0 and Run.scrap > rate * missing + 25:
		Run.add_scrap(-rate * missing)
		Run.heal(missing)
	if Run.fuel < 8 and Run.scrap >= 12:
		Run.add_scrap(-12)
		Run.fuel += 5

func _manage_cargo() -> void:
	var guard := 0
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
			Run.scrap_module(m)
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
	print("---")
	print("Healthy target: 40-55% win rate for this competent-player model.")
	print("Too easy? Raise station repair prices before touching enemy damage —")
	print("this design's difficulty lives in the economy, not in single fights.")
