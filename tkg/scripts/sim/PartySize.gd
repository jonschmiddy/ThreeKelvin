extends Node

## THE PARTY-SIZE TABLE (Jon, Nov 5): what `PartyScale` makes of a fight for 1
## to 4 players, measured, not guessed.
##
##   tools/dev/godot.sh --headless --path tkg -- sheet=PartySize [runs=150] [seed=N]
##       [h=1.0] [sweep=0.6,0.8,1.0,1.2] [enemy=cutter] [n=1,2,3,4]
##
## N ships in one process. `Run` is one ship, so each ship keeps its own hull,
## heat and death in a snapshot swapped into `Run` before it acts (all fly the
## same Korvan medium starter kit, so nothing else on `Run` differs). Each ship
## has its own real `Combat` (deck, hand, energy, block, brace, drones,
## charges), planned through `Combat.plan` with the party's count, so the hull
## is the game's own (`PartyScale.hull` in `_spawn`); all point at ONE enemy
## list, as a shared fight has one enemy. Cards are played by the sim's
## `Policy`. The enemy's turn is the host's (`NetSession._swing`): each live
## hull picks a target weighted 0.5 + heat ratio, and the hit resolves on that
## ship's Combat (`_act_one`: dodge, block, brace), as `_on_swing` does.
##
## Two rows per party size:
##   party  every player in the fight from turn 1
##   alone  one ship fighting a fight built for the whole party (the global
##          rule: the others are elsewhere)
## `h=` overrides `PartyScale.HULL_PER`; `sweep=` prints the 2-player rows at
## each value given, for picking it.
##
## The Custodian lens: a starter kit dies to it in three rounds, so for that
## fight every ship gets a bigger hull (`custhull=`, 120), standing in for a
## ship built over a run, as `CoJoinMeasure` did (one ship alone wins about
## half).

class Duo extends Combat:
	var hold := false
	var held_block := 0

	func _enemy_act() -> void:
		# The driver swings, once for the whole crew.
		held_block = block

	func begin_turn() -> void:
		if hold:
			block = held_block
			return
		super.begin_turn()

	func _victory() -> void:
		finished = true
		result = &"won"

	func _pacify() -> void:
		finished = true
		result = &"pacified"


class Ship extends RefCounted:
	var cb: Duo
	var hp := 0
	var heat := 0
	var dead := false
	var reason := ""
	var hp_in := 0


var policy: Policy = Policy.new()
var cur: Ship = null
var h_over := -1.0


func _ready() -> void:
	_run.call_deferred()


func _arg(k: String, d: String) -> String:
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with(k + "="):
			return (a as String).substr(k.length() + 1)
	return d


func _run() -> void:
	await get_tree().process_frame
	var runs := int(_arg("runs", "150"))
	var seed_base := int(_arg("seed", "9100"))
	var only := _arg("enemy", "")
	var fights := [
		{key = "cutter", lead = &"cutter", extras = [], danger = 3, jumps = 0},
		{key = "lancer", lead = &"lancer", extras = [], danger = 5, jumps = 0},
		{key = "pack", lead = &"lancer", extras = [&"cutter"], danger = 4, jumps = 0},
		{key = "custodian", lead = &"custodian", extras = [], danger = 10, jumps = 20},
	]
	var sizes: Array = Array(_arg("n", "1,2,3,4").split(",")).map(func(x: String) -> int: return int(x))
	var hs: Array = [-1.0]
	if _arg("sweep", "") != "":
		hs = Array(_arg("sweep", "").split(",")).map(func(x: String) -> float: return float(x))
		sizes = [2]
	elif _arg("h", "") != "":
		hs = [float(_arg("h", ""))]
	print("PARTYSIZE HULL_PER %.2f LOOT_PER %.2f runs %d seed %d" % [
		PartyScale.HULL_PER, PartyScale.LOOT_PER, runs, seed_base])
	for fd in fights:
		if only != "" and fd.key != only:
			continue
		for hv in hs:
			h_over = float(hv)
			for n in sizes:
				for mode in ["party", "alone"]:
					if int(n) == 1 and mode == "alone":
						continue
					var agg := {won = 0, rounds = 0.0, rounds_won = 0.0, lost = 0.0, dead = 0, hull = 0.0}
					for i in runs:
						var r := _fight(fd, int(n), mode == "alone", seed_base + i)
						if r.won:
							agg.won += 1
							agg.rounds_won += r.rounds
						agg.rounds += r.rounds
						agg.lost += r.lost
						agg.dead += r.dead
						agg.hull += r.hull
					var k := float(runs)
					print("ROW %s" % JSON.stringify({
						fight = fd.key, players = n, mode = mode,
						h = snappedf(h_over if h_over >= 0.0 else PartyScale.HULL_PER, 0.01),
						hull_mult = snappedf(_hull(int(n)), 0.01),
						loot_mult = snappedf(PartyScale.loot(int(n)), 0.01),
						foe_hull = snappedf(agg.hull / k, 0.1),
						won_pct = snappedf(100.0 * agg.won / k, 0.1),
						rounds = snappedf(agg.rounds / k, 0.01),
						rounds_won = snappedf(agg.rounds_won / maxf(1.0, agg.won), 0.01),
						hull_lost_per_ship = snappedf(agg.lost / k, 0.1),
						ships_dead_pct = snappedf(100.0 * agg.dead / (k * (1 if mode == "alone" else int(n))), 0.1),
					}))
	print("PARTYSIZE DONE")
	get_tree().quit(0)


func _hull(n: int) -> float:
	if h_over < 0.0:
		return PartyScale.hull(n)
	return 1.0 + h_over * float(n - 1)


func _swap_to(s: Ship) -> void:
	if cur == s:
		return
	if cur != null:
		cur.hp = Run.hp
		cur.heat = Run.heat
		cur.dead = Run.dead
		cur.reason = Run.death_reason
	Run.hp = s.hp
	Run.heat = s.heat
	Run.dead = s.dead
	Run.death_reason = s.reason
	cur = s


func _foes_alive(enemies: Array) -> bool:
	for e in enemies:
		if (e as Combat.EnemyState).hp > 0:
			return true
	return false


func _play_hand(s: Ship, enemies: Array) -> bool:
	_swap_to(s)
	var cb := s.cb
	var acted := true
	var guard := 0
	while acted and not cb.finished and _foes_alive(enemies) and guard < 200:
		guard += 1
		acted = false
		while cb.choosing > 0:
			cb.choose(cb.best_choice())
			acted = true
		var best := policy.best_card(cb)
		if best >= 0:
			cb.play(best)
			acted = true
	return not _foes_alive(enemies)


func _fight(fd: Dictionary, n: int, alone: bool, sd: int) -> Dictionary:
	cur = null
	Rng.forced = sd
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Run.jumps = int(fd.jumps)
	Run.party_jumps = 0
	if fd.key == "custodian":
		var hh := Run.hull.duplicate() as HullData
		hh.max_hull = int(_arg("custhull", "120"))
		Run.hull = hh
		Run.hp = Run.max_hp()
	var lead: EnemyTemplate = DB.enemies[fd.lead]
	var extras: Array = []
	for x in fd.extras:
		extras.append(DB.enemies[x])
	var ships: Array[Ship] = []
	for i in (1 if alone else n):
		var s := Ship.new()
		s.hp = Run.hp
		s.heat = Run.heat
		s.hp_in = Run.hp
		s.cb = Duo.new()
		s.cb.clears_node = false
		ships.append(s)
	cur = ships[0]
	# The game's own build at the party's count. `h=` and `sweep=` rescale the
	# solo hull by the factor asked for instead.
	ships[0].cb.plan(lead, int(fd.danger), extras, n if h_over < 0.0 else 1)
	var enemies: Array = ships[0].cb.enemies
	if h_over >= 0.0:
		for e in enemies:
			var es := e as Combat.EnemyState
			es.max_hp = maxi(1, int(round(es.max_hp * _hull(n))))
			es.hp = es.max_hp
	var hull0 := 0.0
	for e in enemies:
		hull0 += (e as Combat.EnemyState).max_hp
	for i in range(1, ships.size()):
		_swap_to(ships[i])
		ships[i].cb.plan(lead, int(fd.danger), extras, n)
		ships[i].cb.enemies = ships[0].cb.enemies
	for s in ships:
		_swap_to(s)
		s.cb.begin_turn()
	var won := false
	var turn := 1
	var rounds := 0
	while turn <= 60:
		rounds = turn
		for s in ships:
			if s.dead or s.cb.finished:
				continue
			if _play_hand(s, enemies):
				won = true
				break
		if won:
			break
		for s in ships:
			if s.dead or s.cb.finished:
				continue
			_swap_to(s)
			s.cb.hold = true
			s.cb.end_turn()
			s.cb.hold = false
			if Run.dead:
				s.dead = true
		if not _foes_alive(enemies):
			won = true
			break
		for e in enemies:
			var es := e as Combat.EnemyState
			if es.hp <= 0:
				continue
			var pool: Array = []
			var w: Array = []
			var tot := 0.0
			for s in ships:
				if s.dead or (s.cb.finished and s.cb.result == &"dead"):
					continue
				_swap_to(s)
				var wt := 0.5 + minf(1.7, float(Run.heat) / float(maxi(1, Run.heat_cap())))
				pool.append(s)
				w.append(wt)
				tot += wt
			if pool.is_empty():
				break
			var roll := Rng.fight.randf() * tot
			var acc := 0.0
			var tgt: Ship = pool[pool.size() - 1]
			for k in pool.size():
				acc += float(w[k])
				if roll < acc:
					tgt = pool[k]
					break
			_swap_to(tgt)
			tgt.cb._act_one(es)
			if Run.dead:
				tgt.dead = true
			if not _foes_alive(enemies):
				break
		if not _foes_alive(enemies):
			won = true
			break
		var any := false
		for s in ships:
			if not s.dead:
				any = true
		if not any:
			break
		for s in ships:
			if s.dead or s.cb.finished:
				continue
			_swap_to(s)
			s.cb.block = 0
			s.cb.begin_turn()
		turn += 1
	var lost := 0.0
	var dead := 0
	for s in ships:
		_swap_to(s)
	_swap_to(ships[0])
	for s in ships:
		lost += s.hp_in - (Run.hp if s == cur else s.hp)
		dead += 1 if s.dead else 0
	cur = null
	return {won = won, rounds = rounds, lost = lost / ships.size(), dead = dead, hull = hull0}
