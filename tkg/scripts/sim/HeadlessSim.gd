class_name HeadlessSim
extends RefCounted
## Driven by Main.gd's sim branch, not --script, which skips the autoloads the sim reads.
## Why: docs/why/HeadlessSim.md#headless-sim

var runs := 200
## `seed=N` gives run i the seed N+i, so a sweep is reproducible; zero rolls fresh seeds.
var seed_base := 0
## Pins the chassis so a sweep asks about a new player's game, which has only Korvan.
var pin_manufacturer: StringName = &""
## Sets what every run's world may hold; empty keeps what `start_new_run` read.
var pin_unlocked: Array[StringName] = []
## `-- sim routines=damage_control,fuel_trim` (or `routines=all`) gives every run
## those science routines from launch, off the board (`Run.routines_granted`), so
## each can be ranked alone against a run without (plan S15). Granted after
## `start_new_run`, whose `clear_science` would take them away, and the hull
## filled to the new max. Empty grants nothing, the run the game flies.
var grant_routines: Array[StringName] = []
## `-- sim science=on|off|ignore` (Phase 12, plan §6), `on` by default.
## Why: docs/why/HeadlessSim.md#sim-scienceonoffignore
var science_mode: StringName = &"on"
var pilot: RandomNumberGenerator = RandomNumberGenerator.new()
## Every decision this file used to make itself. Extracted so the party bot can
## fly the same model the gate measures — see scripts/sim/Policy.gd.
var policy: Policy = Policy.new()
## `hot` spends heat for tempo: the default model leaves fights cold, so the heat layer never bites.
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

## `policy_gave_up` is no usable charted link, weaker than stranded; the gap is the blind spot.
## Why: docs/why/HeadlessSim.md#strand-counters
var policy_gave_up := 0

## Decides whether fuel is a problem: a run ending on most of a full tank did not die of fuel.
var end_fuel_total := 0

## Nowhere to go at any price is a map failure; non-zero means the fuel ruling aims wrong.
var stranded_nowhere := 0

## `forgone` is an option lost to a group exclusion; near zero means the exclusivity dial is idle.
## Why: docs/why/HeadlessSim.md#option-accounting
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
## Signature at a fight's end is the only heat a run can carry onto the map.
## Why: docs/why/HeadlessSim.md#run-tallies
var looted: int = 0
var postfight_samples := 0
var postfight_total := 0.0
var postfight_hot := 0
## Hellbender `met` counts landings on its system; fight length came from the Oct 13 block fix.
## Why: docs/why/HeadlessSim.md#run-tallies
var fights_n := 0
var fights_turns := 0
var fights_hull := 0
var fights_lost := 0
var hellbender_met := 0
var hellbender_fights := 0
var hellbender_kills := 0
var hellbender_escapes := 0
var derelicts_eaten := 0
## Derelicts eaten is two numbers (how often it moves, how much is edible), so both are counted.
var hellbender_moves_total := 0
var arrived_stripped := 0
var food_systems := 0
var all_systems := 0

## Fight pay is read out of the wrecks (Jon, Oct 13) and split by hull count; set pieces pay apart.
## Why: docs/why/HeadlessSim.md#fight-payout
var won_by_pack: Dictionary = {}
var credits_by_pack: Dictionary = {}
var modules_by_pack: Dictionary = {}
var fight_credits := 0
var fight_modules := 0
var credits_taken := 0
var modules_taken := 0

## Loot is tallied by system tier so the rarity ladder reads against depth (Jon, Oct 22).
## Why: docs/why/HeadlessSim.md#depth-payout
var loot_mix: Dictionary = {}
var looted_scrap := 0
var looted_mat_value := 0
var credits_in := 0
var _credits_seen := 0
var core_fights := 0
var core_wins := 0

## Not cleared by `_reset()`: the table spans the whole sweep, or each cell is too thin to read.
## Why: docs/why/HeadlessSim.md#per-kind-table
var by_kind: Dictionary = {}
## Split by launch manufacturer, as a new one moves its own runs and everyone else's at once.
var by_manufacturer: Dictionary = {}
## Read off the fight's own log line, so it counts what `CardResolver` did.
var flash_played := 0
var flash_fired := 0
## Branded parts the pilot picked up, by manufacturer.
var aboard_by_manufacturer: Dictionary = {}

## Fuel and credits are sampled by delta around stations and jumps, not by hooking `RunState`.
## Why: docs/why/HeadlessSim.md#economy-sampling
var stations_visited := 0
var fuel_spent_jumping := 0
var fuel_from_stations := 0
var fuel_from_elsewhere := 0
var credits_at_stations := 0
## Fights an event's outcome opened, and how many of them brought a creature,
## by kind -- the number Jon's Oct 17 ruling moves.
var option_fights := 0
var option_creatures: Dictionary = {}

## The fuel audit (Oct 17) writes one JSON line a run and changes nothing about how a run plays.
## Why: docs/why/HeadlessSim.md#fuel-audit
var sturdy := false
## Run-length study (Oct 22): Custodian multiples applied to the template before any run.
var _cust_hp := 1.0
var _cust_dmg := 1.0
var _cust_block := 1.0
var _cust_loop := ""
## The combat study (Oct 27) scales every enemy but the boss; off unless given, never a ruling.
## Why: docs/why/HeadlessSim.md#combat-study
var _enemy_hp := 1.0
var _enemy_dmg := 1.0
## How each run ended, for the study's closing line: the credits a won run
## ended with, and how many runs ended with nothing in the tank.
var st_won_credits: Array = []
var st_empty_tank := 0
var st_reached := 0
var st_core_wins := 0
var st_rows: Array = []
var _fights_at_start := 0
var _modules0 := 0
var _trace_path := ""
var _trace_file: FileAccess = null
var _tr: Dictionary = {}

## SCIENCE, one entry a run (`_report_science`).
## Why: docs/why/HeadlessSim.md#science
var sc_data: Array = []
var sc_careful: Array = []
var sc_risky: Array = []
var sc_film: Array = []
var sc_relic: Array = []
var sc_unspent: Array = []
var sc_met: Array = []
var sc_data_line: Array = []
var sc_credits_line: Array = []
var sc_fuel: Array = []
var sc_refused: Array = []
var sc_steps: Array = []
var sc_names: Dictionary = {}
var sc_aug: Array = []
var sc_aug_data: Array = []
var sc_aug_credits: Array = []
var sc_affixes: Dictionary = {}
var sc_credits_in: Array = []
var sc_event_credits: Array = []
var sc_trim: Array = [0, 0]
var sc_no_trim: Array = [0, 0]
var _data_in := 0
var _data_seen := 0
var _event_credits := 0

## Entry point. Reads `runs=N` from the user args after `--`, plays that many
## complete runs, and prints the report. The caller quits the tree, with
## `exit_code` (2 for a flag it will not fly, such as a bad `science=`).
var exit_code := 0

func run_sim() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("runs="):
			runs = int(arg.split("=")[1])
		elif arg.begins_with("seed="):
			seed_base = int(arg.split("=")[1])
		elif arg.begins_with("manufacturer="):
			pin_manufacturer = StringName(arg.split("=")[1])
		elif arg.begins_with("unlocked="):
			for m in arg.split("=")[1].split(","):
				if Unlocks.CHAIN.has(StringName(m)):
					pin_unlocked.append(StringName(m))
		# The vent thresholds, as fractions of heat capacity. See Policy.
		elif arg.begins_with("ventcold="):
			policy.vent_cold = float(arg.split("=")[1])
		elif arg.begins_with("venthot="):
			policy.vent_hot = float(arg.split("=")[1])
		elif arg.begins_with("fueltrace="):
			_trace_path = arg.split("=")[1]
		# Run-length study flags (Oct 22), off unless given; `depthcap` is for comparison only.
		elif arg.begins_with("depthcap="):
			Run.depth_step = int(arg.split("=")[1])
		elif arg.begins_with("ambushdeep="):
			Run.study_ambush_deep = float(arg.split("=")[1])
		elif arg.begins_with("radrim="):
			Run.study_radius_rim = float(arg.split("=")[1])
		elif arg.begins_with("raddeep="):
			Run.study_radius_deep = float(arg.split("=")[1])
		elif arg.begins_with("custhp="):
			_cust_hp = float(arg.split("=")[1])
		elif arg.begins_with("custdmg="):
			_cust_dmg = float(arg.split("=")[1])
		elif arg.begins_with("custblock="):
			_cust_block = float(arg.split("=")[1])
		elif arg.begins_with("custloop="):
			_cust_loop = arg.split("=")[1]
		elif arg.begins_with("enemyhp="):
			_enemy_hp = float(arg.split("=")[1])
		elif arg.begins_with("enemydmg="):
			_enemy_dmg = float(arg.split("=")[1])
		elif arg.begins_with("routines="):
			grant_routines = parse_routines(arg.split("=")[1])
		elif arg.begins_with("science="):
			var mode := parse_science(arg.split("=")[1])
			if mode == &"":
				# NOT FLOWN ON A TYPO: `science=of` flying on would have a study
				# cell compare on against on and say nothing. No runs, and Main
				# quits with `exit_code`.
				push_error("science: no mode called %s (on, off or ignore); no runs flown" % arg.split("=")[1])
				exit_code = 2
				return
			science_mode = mode
	apply_science()
	policy.dash = "dash" in OS.get_cmdline_user_args()
	policy.beeline = policy.dash or "beeline" in OS.get_cmdline_user_args()
	if policy.beeline:
		print("BEELINE policy: the deepest star it can afford, every jump%s." % [
			" (and no options taken)" if policy.dash else ""])
	if Run.depth_step != Run.DEPTH_STEP or Run.study_radius_rim != 1.0 or Run.study_radius_deep != 1.0:
		print("STUDY: depth cap %d · radius x%.2f at the rim, x%.2f at the last ring" % [
			Run.depth_step, Run.study_radius_rim, Run.study_radius_deep])
	_study_custodian()
	if _enemy_hp != 1.0 or _enemy_dmg != 1.0:
		print("STUDY enemies, all but the boss: hull x%.2f · damage x%.2f · %s" % [
			_enemy_hp, _enemy_dmg, " / ".join(scale_enemies(_enemy_hp, _enemy_dmg))])
	# Above `bossonly`, which returns before the rest: a routines= boss run has
	# to say so in its log the way a full run does.
	if not grant_routines.is_empty():
		var said: Array[String] = []
		for id in grant_routines:
			said.append(String(DB.routines[id].name))
		print("ROUTINES from launch, off the board: %s." % ", ".join(said))
	if "bossonly" in OS.get_cmdline_user_args():
		_boss_only()
		return
	policy.human = "human" in OS.get_cmdline_user_args()
	# `sturdy` restores hull and heat each arrival so fuel is measured; never a balance number.
	# Why: docs/why/HeadlessSim.md#sturdy-lens
	sturdy = "sturdy" in OS.get_cmdline_user_args()
	if sturdy:
		print("STURDY lens: hull and heat restored on every arrival.")
	if policy.human:
		print("HUMAN policy: heads for the core, scores the chart, buys fuel for the way in.")
	if science_mode == &"off":
		print("SCIENCE off: no science events, no DATA, no board (the control cell).")
	elif science_mode == &"ignore":
		print("SCIENCE ignore: the world rolls its readings; the pilot sells every one and spends no DATA.")
	print("fuel: start %d · tank %d" % [Run.start_fuel(), Run.fuel_cap()])
	if _trace_path != "":
		_trace_file = FileAccess.open(_trace_path, FileAccess.WRITE)

	# `riskaverse` declines below `Policy.RISK_FLOOR`: a greedy model makes shortfalls look free.
	policy.risk_averse = "riskaverse" in OS.get_cmdline_user_args()
	# Without `fight_cb` the sim measures a game with no combat: it reported 0.2 kills a run.
	# Why: docs/why/HeadlessSim.md#fight-wiring
	policy.fight_cb = _option_fight
	Sig.log_line.connect(func(text: String, _kind: StringName) -> void:
		if text.begins_with("  flashpoint +"):
			flash_fired += 1)
	Sig.resources_changed.connect(func() -> void:
		var d := Run.credits - _credits_seen
		if d > 0:
			credits_in += d
		_credits_seen = Run.credits)
	listen_data()
	hot = "hot" in OS.get_cmdline_user_args()
	# The control cell. Comparing `nohellbender` against the default on one build
	# is what says what the roamer costs, without keeping a second checkout.
	# Since Nov 8 the Hellbender flies only at ascension 7 and up, so the default
	# (ascension 0) IS that control cell; `asc=7` is the game as it was before.
	Run.hellbender_off = "nohellbender" in OS.get_cmdline_user_args()
	print("ascension %d (the Hellbender flies from %d)" % [Run.ascension_for_new_run(),
		Run.HELLBENDER_ASCENSION])
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
	if pin_manufacturer != &"":
		print("Every run flies %s." % pin_manufacturer)
	if not pin_unlocked.is_empty():
		print("Every run's world holds %s and unbranded." % ", ".join(pin_unlocked))
	for i in runs:
		_play_one(pin_manufacturer, -1, i)
	_report()

## Pins each chassis and repeats it; slow on purpose (10,500 runs), so not for the merge gate.
## Why: docs/why/HeadlessSim.md#by-chassis-sweep
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
	fights_n = 0
	fights_turns = 0
	fights_hull = 0
	fights_lost = 0
	hellbender_met = 0
	hellbender_fights = 0
	hellbender_kills = 0
	hellbender_escapes = 0
	derelicts_eaten = 0
	hellbender_moves_total = 0
	arrived_stripped = 0
	food_systems = 0
	all_systems = 0
	won_by_pack = {}
	credits_by_pack = {}
	modules_by_pack = {}
	fight_credits = 0
	fight_modules = 0
	credits_taken = 0
	modules_taken = 0
	loot_mix = {}
	looted_scrap = 0
	looted_mat_value = 0
	credits_in = 0
	core_fights = 0
	core_wins = 0
	for a in [sc_data, sc_careful, sc_risky, sc_film, sc_relic, sc_unspent, sc_met,
			sc_data_line, sc_credits_line, sc_fuel, sc_refused, sc_steps, sc_aug,
			sc_aug_data, sc_aug_credits, sc_credits_in, sc_event_credits]:
		(a as Array).clear()
	sc_names = {}
	sc_affixes = {}
	sc_trim = [0, 0]
	sc_no_trim = [0, 0]

## DATA IN, the way `credits_in` is counted: every change to `Run.data` goes
## through `add_data`, which emits `resources_changed`. Its own connection, so
## a harness playing `_play_one` without `run_sim` can count it too.
func listen_data() -> void:
	Sig.resources_changed.connect(func() -> void:
		var dd := Run.data - _data_seen
		if dd > 0:
			_data_in += dd
		_data_seen = Run.data)

## `science=`'s mode: &"on", &"off" or &"ignore", or &"" for anything else.
static func parse_science(arg: String) -> StringName:
	var s := arg.strip_edges().to_lower()
	return StringName(s) if s in ["on", "off", "ignore"] else &""

## The mode, set where it acts: the world (`Run.science_off`, read by the
## science pass, the barren override, the board's services and the bench) and
## the pilot (`policy.science`). Set before the first run and left there, as
## `hellbender_off` is: `start_new_run` does not touch it.
func apply_science() -> void:
	Run.science_off = science_mode == &"off"
	policy.science = science_mode == &"on"

## `routines=`'s ids: `all` is the twelve, branch by branch, weakest first; an
## id the catalogue does not have is named and left out.
static func parse_routines(arg: String) -> Array[StringName]:
	var out: Array[StringName] = []
	if arg == "all":
		for b in DB.BRANCHES:
			out.append_array(DB.routines_in(b))
		return out
	for raw in arg.split(",", false):
		var id := StringName(raw.strip_edges())
		if not DB.routines.has(id):
			print("routines: no routine called %s, left out" % id)
		elif not out.has(id):
			out.append(id)
	return out

## The `routines=` grant, on a run `start_new_run` has just cleared: owned from
## launch, and the hull at the max they make (DAMAGE CONTROL fills its 7).
func grant_at_launch() -> void:
	if grant_routines.is_empty():
		return
	Run.routines_granted = grant_routines.duplicate()
	Run.hp = Run.max_hp()
	Sig.ship_changed.emit()

## `index` gives every run its own reproducible seed, so one run can be flown again.
func _play_one(manufacturer: StringName = &"", w: int = -1, index: int = 0) -> void:
	Rng.forced = (seed_base + index) if seed_base != 0 else 0
	Run.start_new_run(manufacturer, w)
	# Before anything has been rolled from it: `start_new_run` rolls the map,
	# and no shelf, wreck or derelict is filled until it is reached.
	if not pin_unlocked.is_empty():
		Run.unlocked_manufacturers = pin_unlocked.duplicate()
	grant_at_launch()
	_credits_seen = Run.credits
	_data_seen = Run.data
	_data_in = 0
	_event_credits = 0
	var credits_in0 := credits_in
	var dry0 := stranded_no_fuel
	var started_as := Run.hull.manufacturer
	# The pilot generator is per run, not per jump: `Run.jumps` is not a place and repeated picks.
	# Why: docs/why/HeadlessSim.md#pilot-generator
	pilot = Rng.derive(&"pilot", 0)
	policy.pilot = pilot
	policy.begin_run()
	_fights_at_start = fights_n
	_modules0 = modules_taken
	_tr = {seed = Rng.forced, manufacturer = String(Run.hull.manufacturer), weight = int(Run.hull.weight),
		ff = Run.fuel_factor(), start = Run.fuel, dep = [], arr = [], cost = [], layer = [],
		dist = [], any_dear = 0, limited = 0, hint_at = -1, pulsar_fuel = 0, event_fuel = 0,
		station_fuel = 0, stations = 0, hint_station_reach = -1}
	if _trace_file != null:
		_tr.core_hops = _hops_to_core()
	var guard := 0
	var jumped_hot := false
	# The game rolls an ambush only on arrival by jump, so the start system is not rolled.
	var arrived := false
	while not Run.won and not Run.dead and guard < 600:
		guard += 1
		var node: MapGen.MapNode = Run.node_at()
		if sturdy:
			Run.hp = Run.max_hp()
			Run.heat = 0

		# Arrival heat is sampled first, as every other heat rule keys off it.
		heat_samples += 1
		heat_total += Run.signature()
		if Run.signature() > Run.SIGNATURE_FLOOR:
			hot_arrivals += 1

		# The sim uses the game's own ambush gates and pack (Oct 17), not a second implementation.
		# Why: docs/why/HeadlessSim.md#ambush-parity
		if arrived and not node.cleared and not node.ambush_rolled \
				and node.type != MapGen.NodeType.CORE and not Router.no_fights_at(node):
			node.ambush_rolled = true
			if Rng.foe.randf() < Run.ambush_chance(node):
				ambushes += 1
				jumped_hot = true
				var pack := Router.ambush_pack(node)
				if not pack.is_empty() and not _fight(pack[0], false, pack.slice(1)):
					break

		# Same blockade as the game's; a break-off lifts it in place, so the flag is re-read.
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
		elif node.type == MapGen.NodeType.CORE:
			var row := _study_arrival()
			var cf0 := fights_turns
			core_fights += 1
			_fight(DB.enemies[&"custodian"])
			if Run.won:
				core_wins += 1
			row.won = Run.won
			row.turns = fights_turns - cf0
			st_reached += 1
			st_core_wins += 1 if row.won else 0
			st_rows.append(row)
			break
		elif node.type == MapGen.NodeType.STATION:
			stations_visited += 1
			var sf := Run.fuel
			var sc := Run.credits
			policy.shop(Run.node_at())
			fuel_from_stations += maxi(0, Run.fuel - sf)
			_tr.station_fuel += maxi(0, Run.fuel - sf)
			_tr.stations += 1
			credits_at_stations += Run.credits - sc
		elif node.type == MapGen.NodeType.PULSAR and not node.cleared:
			# Always taken: a competent player passes up no fuel; the win rate judges hull cost.
			var pf := Run.fuel
			Run.harvest_pulsar()
			_tr.pulsar_fuel += Run.fuel - pf
			if Run.dead:
				break
		# Policy-taken options are the only way a system resolves since the collapse, fights too.
		# Why: docs/why/HeadlessSim.md#option-resolution
		if not node.cleared:
			var of := Run.fuel
			var oc := Run.credits
			var ot := credits_taken
			var got := policy.take_options(node)
			_tr.event_fuel += Run.fuel - of
			# What the lines themselves paid, the loot of any fight they
			# opened left out (`_loot` counts that into `credits_taken`).
			_event_credits += (Run.credits - oc) - (credits_taken - ot)
			if int(got.taken) + int(got.declined) + int(got.forgone) + int(got.fights) > 0:
				sites_with_options += 1
			opts_taken += int(got.taken)
			opts_declined += int(got.declined)
			opts_forgone += int(got.forgone)
			opts_fight += int(got.fights)
			if Run.dead:
				break
		policy.manage_cargo()

		# The choice lives in `Policy`; here is only the accounting for the case of no choice.
		var pick := policy.choose_jump(node)
		_audit_jump(node, pick)
		if pick < 0:
			# A strand is what the game says it is: the old counter tracked the policy giving up.
			# Why: docs/why/HeadlessSim.md#strand-accounting
			policy_gave_up += 1
			Run.check_stranded()
			if Run.has_legal_jump():
				# The policy is out of charted links but the ship can still
				# fly. Not a strand, and the old counter called it one.
				break
			stranded += 1
			# Walks the set the game uses, all of it, not the first unaffordable link.
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
		# Everything that is not a jump or a station is caught as the remainder.
		var jf := Run.fuel
		var jc := Run.credits
		var jumps_before := Run.jumps
		var jd := MapGen.hop_distance(node, Run.map[pick])
		Run.jump_to(pick)
		arrived = Run.jumps != jumps_before
		if arrived:
			_tr.dep.append(jf)
			_tr.arr.append(Run.fuel)
			_tr.cost.append(jf - Run.fuel)
			_tr.layer.append(Run.node_at().layer)
			_tr.dist.append(snappedf(jd, 0.001))
		# Arriving at an already stripped system is the one way the hellbender's appetite costs.
		if Run.node_at() != null and (Run.node_at() as MapGen.MapNode).eaten:
			arrived_stripped += 1
		fuel_spent_jumping += maxi(0, jf - Run.fuel)

	if jumped_hot:
		runs_ambushed += 1
	_mix_run()
	for n in Run.map:
		var mn := n as MapGen.MapNode
		if mn.eaten:
			derelicts_eaten += 1
		# Asked at run end, since `system_has_tag` rolls an unvisited system's options.
		all_systems += 1
		if OptionTable.system_has_tag(mn, &"salvage"):
			food_systems += 1
	hellbender_moves_total += Run.hellbender_moves
	total_jumps += Run.jumps
	total_kills += Run.kills
	total_danger += Run.node_at().danger
	end_fuel_total += Run.fuel
	_science_run(credits_in - credits_in0, stranded_no_fuel > dry0)
	if _trace_file != null:
		_tr.end = Run.fuel
		_tr.jumps = Run.jumps
		_tr.won = Run.won
		_tr.dead = Run.dead
		_tr.reason = Run.death_reason
		_tr.depth = Run.node_at().layer
		_tr.credits_end = Run.credits
		_tr.spent = policy.spend.duplicate()
		_tr.fuel_bought = policy.fuel_bought
		_tr.refuel_stops = policy.refuel_stops
		_tr.rescues = policy.rescues
		_tr.kills = Run.kills
		_tr.data_in = _data_in
		_tr.data_end = Run.data
		_tr.steps = Array(Run.board_owned)
		_tr.sci = policy.sci.duplicate(true)
		_trace_file.store_line(JSON.stringify(_tr))
		_trace_file.flush()
	if Run.won:
		wins += 1
		st_won_credits.append(Run.credits)
	if Run.fuel <= 0:
		st_empty_tank += 1
	if Run.dead:
		deaths += 1
		var key := Run.death_reason.substr(0, 24)
		death_causes[key] = int(death_causes.get(key, 0)) + 1

	var mrow: Dictionary = by_manufacturer.get(started_as, {
		"runs": 0, "wins": 0, "fire": 0, "heat": 0, "event": 0, "stranded": 0,
		"set3": 0,
	})
	mrow.runs += 1
	mrow.wins += 1 if Run.won else 0
	if Run.dead:
		var why := Run.death_reason
		if why.begins_with("Enemy fire"):
			mrow.fire += 1
		elif why.begins_with("The ship overheated"):
			mrow.heat += 1
		elif why.begins_with("Adrift"):
			mrow.stranded += 1
		else:
			mrow.event += 1
	# Did this run ever hold three of its own manufacturer at the end?
	if started_as != &"" and Run.manufacturer_count(started_as) >= 3:
		mrow.set3 += 1
	by_manufacturer[started_as] = mrow
	for raw in Run.installed:
		var im: ModuleData = raw
		if im != null and im.manufacturer != &"":
			aboard_by_manufacturer[im.manufacturer] = int(aboard_by_manufacturer.get(im.manufacturer, 0)) + 1
	for raw2 in Run.cargo:
		var cm := raw2 as ModuleData
		if cm != null and cm.manufacturer != &"":
			aboard_by_manufacturer[cm.manufacturer] = int(aboard_by_manufacturer.get(cm.manufacturer, 0)) + 1

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

## Option fights use `Router.option_foe`; the sim's own pick fought whales, not ships.
## Why: docs/why/HeadlessSim.md#option-fights
func _option_fight(n: MapGen.MapNode, foe: StringName = &"") -> bool:
	if foe == &"" and DB.fight_pool(n.danger, false).is_empty():
		return not Run.dead
	# Not consuming, as in `Router.start_ambush`: clearing the node would take fewer options.
	var t := Router.option_foe(n, foe)
	option_fights += 1
	if t.fauna:
		option_creatures[t.id] = int(option_creatures.get(t.id, 0)) + 1
	return _fight(t, false)


func _fight(template: EnemyTemplate, clears_node: bool = true, extras: Array = []) -> bool:
	var cb := Combat.new()
	cb.clears_node = clears_node
	var wrecks0 := _wrecks_at(Run.node_at())
	var cr0 := Run.credits
	cb.start(template, Run.node_at().danger, extras)
	var hp_in := Run.hp
	var turns := _play_out(cb)
	fights_n += 1
	fights_turns += turns
	fights_hull += maxi(0, hp_in - Run.hp)
	if Run.dead:
		fights_lost += 1
	# A kill fills a container, so the pilot must loot it; see `Policy.loot`.
	_tally(cb, wrecks0, cr0)
	if not Run.dead:
		_loot()
	postfight_samples += 1
	postfight_total += Run.signature()
	if Run.signature() > Run.SIGNATURE_FLOOR:
		postfight_hot += 1
	return not Run.dead


## Every fight goes through here: the Hellbender's own copy never answered a pending pick.
func _play_out(cb: Combat) -> int:
	var turns := 0
	while not cb.finished and turns < 60:
		turns += 1
		var acted := true
		while acted and not cb.finished:
			acted = false
			# Answer a pending pick first: nothing is playable while one is open.
			while cb.choosing > 0:
				cb.choose(cb.best_choice())
				acted = true
			var best := policy.best_card(cb)
			if best >= 0:
				if cb.hand[best].flashpoint > 0:
					flash_played += 1
				cb.play(best)
				acted = true
		if not cb.finished:
			cb.end_turn()
	return turns


## The pilot reaches into the system's containers, and what it took is counted.
func _loot() -> void:
	var n: MapGen.MapNode = Run.node_at()
	var mods0 := _modules_left(n)
	var cr1 := Run.credits
	# What was on offer, by option key, so what the pilot took can be priced.
	var offered: Dictionary = {}
	if n != null:
		for raw in n.jetsam:
			var h: MapGen.Jetsam = raw
			for i in h.items.size():
				if not n.taken.has(h.option(i)):
					offered[h.option(i)] = h.items[i]
	looted += Policy.loot(n)
	modules_taken += mods0 - _modules_left(n)
	credits_taken += Run.credits - cr1
	for key in offered:
		if not n.taken.has(key):
			continue
		var it: HoldItem = offered[key]
		if it is ModuleData:
			looted_scrap += Run.scrap_value_of(it as ModuleData)
		elif it is MaterialData:
			looted_mat_value += (it as MaterialData).value


## Every part and material lying in this run's systems, by the system's tier.
func _mix_run() -> void:
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		if n.type == MapGen.NodeType.CORE:
			continue
		var t := MapGen.tier(n.danger)
		var items: Array = n.bag.duplicate()
		for jraw in n.jetsam:
			items.append_array((jraw as MapGen.Jetsam).items)
		for it in items:
			var key := ""
			if it is ModuleData:
				key = ModuleData.rarity_name((it as ModuleData).rarity)
			elif it is MaterialData:
				key = "mat " + String((it as MaterialData).tier)
			else:
				continue
			if not loot_mix.has(t):
				loot_mix[t] = {}
			loot_mix[t][key] = int(loot_mix[t].get(key, 0)) + 1


## How many wrecks a system holds, so a fight's own can be told from older ones.
static func _wrecks_at(n: MapGen.MapNode) -> int:
	var k := 0
	if n != null:
		for raw in n.jetsam:
			if (raw as MapGen.Jetsam).is_wreck():
				k += 1
	return k


## Modules still unclaimed anywhere in the system.
static func _modules_left(n: MapGen.MapNode) -> int:
	var k := 0
	if n == null:
		return 0
	for raw in n.jetsam:
		var h: MapGen.Jetsam = raw
		for i in h.items.size():
			if h.items[i] is ModuleData and not n.taken.has(h.option(i)):
				k += 1
	return k


## Read-only: draws nothing from any stream, so watched runs are the runs always played.
func _tally(cb: Combat, wrecks0: int, cr0: int) -> void:
	if cb.result != &"victory" and cb.result != &"won":
		return
	var n: MapGen.MapNode = Run.node_at()
	var cr := Run.credits - cr0
	var mods := 0
	var seen := 0
	for raw in n.jetsam:
		var h: MapGen.Jetsam = raw
		if not h.is_wreck():
			continue
		seen += 1
		if seen <= wrecks0:
			continue
		for m in h.items:
			if m is CreditChit:
				cr += (m as CreditChit).amount
			elif m is ModuleData:
				mods += 1
	fight_credits += cr
	fight_modules += mods
	var lead := cb.enemies[0].template
	if lead.boss or lead.miniboss:
		return
	var size := cb.enemies.size()
	won_by_pack[size] = int(won_by_pack.get(size, 0)) + 1
	credits_by_pack[size] = int(credits_by_pack.get(size, 0)) + cr
	modules_by_pack[size] = int(modules_by_pack.get(size, 0)) + mods


## Differs from `_fight()` as the game does: enemy hull from the map, no consume, three endings.
func _fight_hellbender() -> bool:
	var cb := Combat.new()
	cb.clears_node = false
	var wrecks0 := _wrecks_at(Run.node_at())
	var cr0 := Run.credits
	cb.plan(DB.enemies[&"hellbender"], Run.node_at().danger)
	cb.enemies[0].hp = clampi(Run.hellbender_hp, 1, cb.enemies[0].max_hp)
	cb.enemies[0].pick_intent()
	cb.begin(null)
	_play_out(cb)
	_tally(cb, wrecks0, cr0)
	if not Run.dead:
		_loot()
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
	# Zero means every wreck was walked past; it was zero by construction until containers landed.
	print("looted %d items across %d runs (%.1f per run)"
		% [looted, maxi(1, runs), float(looted) / float(maxi(1, runs))])
	print("runs %d · wins %d (%.0f%%) · deaths %d · errors %d" % [
		runs, wins, 100.0 * wins / maxi(1, runs), deaths, errors])
	print("avg jumps %.1f · avg kills %.1f · avg danger reached %.2f" % [
		float(total_jumps) / runs, float(total_kills) / runs, float(total_danger) / runs])
	print("death causes: %s" % str(death_causes))
	# Strands count in deaths but are reported apart, as a fuel death is an economy failure.
	print("stranded, ended by check_stranded() %d (%.1f%%) · dry tank %d · nowhere in range %d" % [
		stranded, 100.0 * stranded / maxi(1, runs), stranded_no_fuel,
		stranded_nowhere])
	# The blind spot: runs in the gap are ones the old counter called stranded and the game not.
	print("fuel left at run end: %.0f of a %d tank (%.0f%%)" % [
		float(end_fuel_total) / maxi(1, runs),
		Run.start_fuel(),
		100.0 * (float(end_fuel_total) / maxi(1, runs))
			/ maxf(1.0, float(Run.start_fuel()))])
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
			print("  %d of those opened a fight (%.2f a system)"
				% [opts_fight, float(opts_fight) / float(sites_with_options)])
	print("policy gave up %d (%.1f%%) · of those, the ship could still fly %d" % [
		policy_gave_up, 100.0 * policy_gave_up / maxi(1, runs),
		policy_gave_up - stranded])
	# The heat layer is reported apart, as the first question on any tuning is whether it fired.
	print("heat: avg signature on arrival %.2f · arrived hot %d of %d (%.1f%%)" % [
		heat_total / maxf(1.0, float(heat_samples)), hot_arrivals, heat_samples,
		100.0 * hot_arrivals / maxi(1, heat_samples)])
	print("post-fight signature %.2f · left a fight hot %d of %d (%.1f%%)" % [
		postfight_total / maxf(1.0, float(postfight_samples)), postfight_hot,
		postfight_samples, 100.0 * postfight_hot / maxi(1, postfight_samples)])
	print("fights: %d · %.2f turns a fight · %.2f hull lost a fight · %d lost" % [
		fights_n, float(fights_turns) / maxi(1, fights_n),
		float(fights_hull) / maxi(1, fights_n), fights_lost])
	print("hellbender: met %d · engaged %d · killed %d · watched it escape %d · derelicts eaten %.2f/run" % [
		hellbender_met, hellbender_fights, hellbender_kills, hellbender_escapes,
		float(derelicts_eaten) / maxi(1, runs)])
	print("  arrived somewhere already stripped %d times (%.2f a run, %.1f%% of arrivals)" % [
		arrived_stripped, float(arrived_stripped) / maxi(1, runs),
		100.0 * arrived_stripped / maxi(1, total_jumps)])
	print("  it moved %.1f times a run · %.1f%% of systems were edible · it ate on %.0f%% of moves" % [
		float(hellbender_moves_total) / maxi(1, runs),
		100.0 * food_systems / maxi(1, all_systems),
		100.0 * derelicts_eaten / maxi(1, hellbender_moves_total)])
	print("ambushes %d (%.2f per run) · runs jumped at least once %d (%.1f%%)" % [
		ambushes, float(ambushes) / maxi(1, runs), runs_ambushed,
		100.0 * runs_ambushed / maxi(1, runs)])
	var creatures := 0
	for k in option_creatures:
		creatures += int(option_creatures[k])
	print("event fights %d (%.2f per run) · brought a creature %d (%.1f%%) %s" % [
		option_fights, float(option_fights) / maxi(1, runs), creatures,
		100.0 * creatures / maxi(1, option_fights), str(option_creatures)])
	_report_economy()
	_report_science()
	_report_deep()
	_report_kinds()
	_report_manufacturers()
	_report_study()
	print("---")
	print("Healthy target: 40-55% win rate for this competent-player model.")
	print("Too easy? Raise station repair prices before touching enemy damage —")
	print("this design's difficulty lives in the economy, not in single fights.")


## The Custodian template is scaled before any run; with no flags it is a no-op.
func _study_custodian() -> void:
	if _cust_hp == 1.0 and _cust_dmg == 1.0 and _cust_block == 1.0 and _cust_loop == "":
		return
	var t: EnemyTemplate = DB.enemies[&"custodian"]
	t.max_hull = int(round(t.max_hull * _cust_hp))
	t.brace = int(round(t.brace * _cust_block))
	var loop: Array[IntentData] = []
	if _cust_loop != "":
		for s in _cust_loop.split(","):
			loop.append((t.loop[int(s)] as IntentData).duplicate(true))
	else:
		for i in t.loop:
			loop.append((i as IntentData).duplicate(true))
	for c in loop:
		c.damage = int(round(c.damage * _cust_dmg))
		c.block = int(round(c.block * _cust_block))
	t.loop = loop
	var said: PackedStringArray = []
	for c in loop:
		said.append("%s %d%s%s" % [c.name, c.damage, ("x%d" % c.hits) if c.hits > 1 else "",
			(" +%d block" % c.block) if c.block > 0 else ""])
	print("STUDY custodian: hull %d · brace %d · loop %s" % [t.max_hull, t.brace, " / ".join(said)])


## What a run carries the moment it reaches the core, before the fight.
func _study_arrival() -> Dictionary:
	var rar := 0
	var mods := 0
	for raw in Run.installed:
		var m: ModuleData = raw
		if m == null:
			continue
		mods += 1
		rar += int(m.rarity)
	# (AUGMENT is spending too, science's; without it `earned` read short by
	# what the Lab took)
	var spent := int(policy.spend.fuel) + int(policy.spend.repair) + int(policy.spend.options) \
		+ int(policy.spend.get("augment", 0))
	return {
		steps = _steps(),
		jumps = Run.jumps,
		fights = fights_n - _fights_at_start,
		kills = Run.kills,
		credits = Run.credits,
		earned = Run.credits + spent - 40,
		looted = modules_taken - _modules0,
		mods = mods,
		rarity = rar,
		grade = Run.hull.tier,
		hp = Run.hp,
		fuel = Run.fuel,
		max_hp = Run.max_hp(),
		reactor = Run.reactor(),
		deck = DeckBuilder.build().size(),
		weight = int(Run.hull.weight),
		kind = GalaxyGen.type_name(Run.galaxy_kind),
	}


## Board steps owned (the board's, never `routines=`'s grant).
static func _steps() -> int:
	var k := 0
	for v in Run.board_owned:
		k += clampi(v, 0, 3)
	return k


## One run's science, into the per-run arrays. `credits_gained` is the run's
## share of `credits_in`; `dry` whether it ended a dry-tank strand.
func _science_run(credits_gained: int, dry: bool) -> void:
	var s: Dictionary = policy.sci
	sc_data.append(_data_in)
	sc_careful.append(int(s.data_careful))
	sc_risky.append(int(s.data_risky))
	sc_film.append(int(s.data_film))
	sc_relic.append(int(s.data_relic))
	sc_unspent.append(Run.data)
	sc_met.append(int(s.met))
	sc_data_line.append(int(s.careful) + int(s.risky))
	sc_credits_line.append(int(s.credits))
	sc_fuel.append(int(s.fuel))
	sc_refused.append(int(s.refused))
	sc_steps.append(_steps())
	for b in DB.BRANCHES.size():
		for k in clampi(Run.board_owned[b], 0, 3):
			if b * 3 + k >= Run.board.size():
				break
			var id: StringName = Run.board[b * 3 + k]
			sc_names[id] = int(sc_names.get(id, 0)) + 1
	sc_aug.append(int(s.augments))
	sc_aug_data.append(int(s.aug_data))
	sc_aug_credits.append(int(s.aug_credits))
	for a in s.affixes:
		sc_affixes[a] = int(sc_affixes.get(a, 0)) + int(s.affixes[a])
	sc_credits_in.append(credits_gained)
	sc_event_credits.append(_event_credits)
	var cell: Array = sc_trim if Run.has_routine(&"fuel_trim") else sc_no_trim
	cell[1] += 1
	if dry:
		cell[0] += 1


static func _mean(a: Array) -> float:
	var t := 0.0
	for v in a:
		t += float(v)
	return t / float(maxi(1, a.size()))


## The value `q` of the way up `a` (0.1 is p10), nearest rank.
static func _pct(a: Array, q: float) -> float:
	if a.is_empty():
		return 0.0
	var s := a.duplicate()
	s.sort()
	return float(s[clampi(int(ceil(q * s.size())) - 1, 0, s.size() - 1)])


## SCIENCE (plan §6). Every line starts `science:`, `routines:`, `augments:`,
## `strand:` or `credits:`, so the gate can grep them; with science off one
## `science: off` line stands for the rest, and `credits:` still prints, since
## credits a run against `off` is one of the study's bands.
func _report_science() -> void:
	print("---")
	for line in science_lines():
		print(line)


## `_report_science`'s lines, for the report and for `-- sheet=ScienceSimTest`.
func science_lines() -> PackedStringArray:
	var out := PackedStringArray()
	var r := float(maxi(1, sc_data.size()))
	if science_mode == &"off":
		out.append("science: off (the control cell: no science events, no DATA, no board)")
	else:
		if science_mode == &"ignore":
			out.append("science: ignore (the pilot sells every reading and spends no DATA)")
		out.append("science: DATA %.1f a run (median %.0f, p10 %.0f, p90 %.0f) · careful %.1f risky %.1f · film %.1f · relic %.1f · unspent at end %.1f"
			% [_mean(sc_data), _median(sc_data), _pct(sc_data, 0.1), _pct(sc_data, 0.9),
				_mean(sc_careful), _mean(sc_risky), _mean(sc_film), _mean(sc_relic),
				_mean(sc_unspent)])
		var met := _mean(sc_met) * r
		out.append("science: %.2f science events met a run · DATA line %.0f%% · credits line %.0f%% · fuel on science %.1f a run · fuel gate shut %.2f a run"
			% [_mean(sc_met), 100.0 * _mean(sc_data_line) * r / maxf(1.0, met),
				100.0 * _mean(sc_credits_line) * r / maxf(1.0, met), _mean(sc_fuel),
				_mean(sc_refused)])
		var won: Array = []
		var lost: Array = []
		for row in st_rows:
			(won if bool(row.get("won", false)) else lost).append(int(row.get("steps", 0)))
		var names := {}
		for id in sc_names:
			names[String(DB.routines[id].name)] = sc_names[id]
		out.append("routines: %.1f a run at end, median at the core %.1f won / %.1f lost (%d / %d) · by name %s"
			% [_mean(sc_steps), _median(won), _median(lost), won.size(), lost.size(), str(names)])
		out.append("augments: %.2f a run · DATA %.1f · credits %.1f · affixes %s"
			% [_mean(sc_aug), _mean(sc_aug_data), _mean(sc_aug_credits), str(sc_affixes)])
		out.append("strand: with FUEL TRIM %d/%d (%.1f%%) · without %d/%d (%.1f%%)"
			% [sc_trim[0], sc_trim[1], 100.0 * sc_trim[0] / maxi(1, sc_trim[1]),
				sc_no_trim[0], sc_no_trim[1], 100.0 * sc_no_trim[0] / maxi(1, sc_no_trim[1])])
	out.append("credits: gained %.0f a run (median %.0f) · from events %.0f a run (net, fights' loot left out)"
		% [_mean(sc_credits_in), _median(sc_credits_in), _mean(sc_event_credits)])
	return out


## Scales every template but the boss in place; danger scaling still applies in `Combat._spawn`.
static func scale_enemies(hp: float, dmg: float) -> PackedStringArray:
	var said: PackedStringArray = []
	for id in DB.enemies:
		var t: EnemyTemplate = DB.enemies[id]
		if t.boss:
			continue
		t.max_hull = maxi(1, int(round(t.max_hull * hp)))
		var loop: Array[IntentData] = []
		for raw in t.loop:
			var c := (raw as IntentData).duplicate(true) as IntentData
			c.damage = int(round(c.damage * dmg))
			loop.append(c)
		t.loop = loop
		var pool: Array[IntentData] = []
		for raw in t.pool:
			var c := (raw as IntentData).duplicate(true) as IntentData
			c.damage = int(round(c.damage * dmg))
			pool.append(c)
		t.pool = pool
		said.append("%s %d" % [id, t.max_hull])
	return said


## Closing line: won-run credits and empty-tank runs, of which `dry` had places in reach.
static func end_line(won_credits: Array, empty: int, dry: int) -> String:
	var top := 0
	for c in won_credits:
		top = maxi(top, int(c))
	return "STUDY at the end: won runs %d · credits median %.0f max %d · ended on an empty tank %d (dry-tank strands %d)" % [
		won_credits.size(), _median(won_credits), top, empty, dry]


static func _median(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var s := a.duplicate()
	s.sort()
	var m := s.size() / 2
	return float(s[m]) if s.size() % 2 == 1 else (float(s[m - 1]) + float(s[m])) * 0.5


func _report_study() -> void:
	print(end_line(st_won_credits, st_empty_tank, stranded_no_fuel))
	var jumps: Array = []
	var fights: Array = []
	var earned: Array = []
	var looted: Array = []
	var mods: Array = []
	var hpf: Array = []
	var maxhp: Array = []
	var grades := {}
	var turns: Array = []
	var fuel: Array = []
	for r in st_rows:
		fuel.append(r.fuel)
		jumps.append(r.jumps)
		fights.append(r.fights)
		earned.append(r.earned)
		looted.append(r.looted)
		mods.append(r.mods)
		hpf.append(float(r.hp) / float(maxi(1, r.max_hp)))
		maxhp.append(r.max_hp)
		grades[r.grade] = int(grades.get(r.grade, 0)) + 1
		turns.append(r.turns)
	print("STUDY reached core %d of %d (%.0f%%) · beat the custodian %d (%.0f%% of arrivals, %.1f%% of runs)" % [
		st_reached, runs, 100.0 * st_reached / maxi(1, runs), st_core_wins,
		100.0 * st_core_wins / maxi(1, st_reached), 100.0 * st_core_wins / maxi(1, runs)])
	if st_rows.is_empty():
		return
	var jmin := 999
	for j in jumps:
		jmin = mini(jmin, int(j))
	print("STUDY at arrival: jumps median %.1f min %d · fights median %.1f · credits earned median %.0f · parts looted median %.1f" % [
		_median(jumps), jmin, _median(fights), _median(earned), _median(looted)])
	print("STUDY at arrival: modules fitted median %.1f · hull %.0f%% of max (max hull median %.0f) · grades %s · custodian fight turns median %.1f" % [
		_median(mods), 100.0 * _median(hpf), _median(maxhp), str(grades), _median(turns)])
	var fmin := 999
	for f in fuel:
		fmin = mini(fmin, int(f))
	print("STUDY at arrival: fuel in the tank median %.1f min %d" % [_median(fuel), fmin])


## Flies each Korvan weight at grade C with its starter kit straight into the Custodian fight.
func _boss_only() -> void:
	var weights := [HullData.Weight.LIGHT, HullData.Weight.MEDIUM, HullData.Weight.HEAVY]
	var manu: StringName = pin_manufacturer if pin_manufacturer != &"" else &"korvan"
	print("BOSSONLY: %s, grade C, starter kit, %d fights a weight" % [manu, runs])
	for w in weights:
		var won := 0
		var t_all := 0
		var hp_left := 0
		var boss_left := 0
		var boss_left_n := 0
		var hp0 := 0
		for i in runs:
			Rng.forced = (seed_base if seed_base != 0 else 4242) + i
			Run.start_new_run(manu, int(w))
			grant_at_launch()
			hp0 = Run.max_hp()
			for raw in Run.map:
				if (raw as MapGen.MapNode).type == MapGen.NodeType.CORE:
					Run.at = (raw as MapGen.MapNode).index
			var cb := Combat.new()
			cb.clears_node = true
			cb.start(DB.enemies[&"custodian"], Run.node_at().danger, [])
			t_all += _play_out(cb)
			if not (cb.result == &"won" or cb.result == &"victory"):
				var left := 0
				for e in cb.enemies:
					left += maxi(0, (e as Combat.EnemyState).hp)
				boss_left += left
				boss_left_n += 1
			else:
				won += 1
				hp_left += Run.hp
		print("  %-8s max hull %3d · reactor %d · won %3d of %d (%.0f%%) · %.1f turns · hull left when won %.0f · custodian hull left when lost %.0f" % [
			["light", "medium", "heavy"][int(w)], hp0, Run.reactor(), won, runs, 100.0 * won / maxi(1, runs),
			float(t_all) / maxi(1, runs), float(hp_left) / maxi(1, won),
			float(boss_left) / maxi(1, boss_left_n)])


## Win rate and how each run ended, by the manufacturer it launched as; then
## Flashpoint in the fights, and whose parts the ships ended their runs holding.
func _report_manufacturers() -> void:
	if by_manufacturer.is_empty():
		return
	print("---")
	print("by starting manufacturer (deaths: enemy fire / overheated / events / stranded):")
	print("  %-10s %5s %6s %6s %6s %6s %6s %8s" % ["started", "runs", "win%", "fire", "heat", "event", "strand", "set3 end"])
	var keys := by_manufacturer.keys()
	keys.sort()
	for k in keys:
		var v: Dictionary = by_manufacturer[k]
		print("  %-10s %5d %5.0f%% %6d %6d %6d %6d %8d" % [str(k), int(v.runs),
			100.0 * float(v.wins) / maxf(1.0, float(v.runs)), int(v.fire), int(v.heat),
			int(v.event), int(v.stranded), int(v.set3)])
	print("flashpoint: %d cards played, %d hits resolved over capacity" % [flash_played, flash_fired])
	print("branded parts on board at run end: %s" % str(aboard_by_manufacturer))


## Kinds play as different games, as `squash` changes ring count and hop cost, so report per kind.
## Why: docs/why/HeadlessSim.md#galaxy-kinds
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


## Most deaths are economic and hidden from a corpse count; watch fuel per jump when resizing.
## Why: docs/why/HeadlessSim.md#economy-report
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
	print("  fights paid %.0f credits a run (%.0f banked after looting) · %.2f modules a run in the wrecks, %.2f looted"
		% [float(fight_credits) / r, float(credits_taken) / r,
			float(fight_modules) / r, float(modules_taken) / r])
	var sizes := won_by_pack.keys()
	sizes.sort()
	for k in sizes:
		var w := float(maxi(1, int(won_by_pack[k])))
		print("  won %d-ship fights: %d · %.1f credits a fight · %.2f modules a fight"
			% [k, int(won_by_pack[k]), float(credits_by_pack[k]) / w, float(modules_by_pack[k]) / w])


## The rarity ladder against depth, what the pilot's haul was worth, and the
## custodian fight. See `loot_mix`.
func _report_deep() -> void:
	var r := float(maxi(1, runs))
	print("---")
	print("deep loot per run: %.0f credits gained (all sources) · looted parts melt for %.0f · looted materials list at %.0f"
		% [float(credits_in) / r, float(looted_scrap) / r, float(looted_mat_value) / r])
	print("  custodian: reached %d · beaten %d (%.0f%% of those reached)"
		% [core_fights, core_wins, 100.0 * core_wins / maxi(1, core_fights)])
	var mods := ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Exotic", "Artifact", "Contraband"]
	var mats := ["mat common", "mat rare", "mat epic", "mat legendary", "mat exotic", "mat artifact", "mat contraband"]
	print("  parts lying in the run's systems at its end, by tier (%):")
	_mix_table(mods, 0)
	print("  materials lying there, by tier (%):")
	_mix_table(mats, 4)


func _mix_table(keys: Array, cut: int) -> void:
	var head := "    tier %6s" % "n"
	for k in keys:
		head += "  %5s" % String(k).substr(cut, 5)
	print(head)
	for t in [1, 2, 3, 4, 5]:
		var row: Dictionary = loot_mix.get(t, {})
		var total := 0
		for k in keys:
			total += int(row.get(k, 0))
		var line := "    %4d %6d" % [t, total]
		for k in keys:
			line += "  %5.1f" % (100.0 * int(row.get(k, 0)) / maxi(1, total))
		print(line)


## Keeps the first jump where the fuel hint's rule is true, and whether it would name a dock.
func _audit_jump(node: MapGen.MapNode, pick: int) -> void:
	if _tr.is_empty():
		return
	var dear := 0
	var any_dear := false
	for raw in Run.in_range_of(node):
		var t: MapGen.MapNode = raw
		if not t.sensed:
			continue
		var c := Run.fuel_cost_to(t)
		dear = maxi(dear, c)
		if c > Run.fuel:
			any_dear = true
	if dear == 0:
		dear = Run.FUEL_MAX_HOP
	if any_dear:
		_tr.any_dear += 1
	if policy.limited:
		_tr.limited += 1
	# THE FUEL HINT AS THE GAME FIRES IT (`Run.fuel_low`, a third of the tank),
	# and whether the dock it would name was in reach on what was left.
	if Run.fuel_low() and int(_tr.hint_at) < 0:
		_tr.hint_at = Run.jumps
		_tr.hint_station_reach = 0 if Run.nearest_dock().is_empty() else 1


## The fewest jumps from the start to the core, reach alone (no fuel, no sight):
## the length of the shortest possible run.
func _hops_to_core() -> int:
	var seen := {Run.at: 0}
	var q: Array = [Run.at]
	while not q.is_empty():
		var i: int = q.pop_front()
		var here: MapGen.MapNode = Run.map[i]
		if here.type == MapGen.NodeType.CORE:
			return int(seen[i])
		for raw in Run.in_range_of(here):
			var t: MapGen.MapNode = raw
			if not seen.has(t.index):
				seen[t.index] = int(seen[i]) + 1
				q.append(t.index)
	return -1
