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
## `-- sim manufacturer=korvan` flies every run in that manufacturer's chassis
## (the weight still rolls). Empty rolls one of the seven per run, as before.
## What a fresh profile can fly is Korvan alone, so this is how a sweep asks
## about the game a new player gets rather than an average over seven starts.
var pin_manufacturer: StringName = &""
## `-- sim unlocked=korvan` (or `korvan,solari`) sets what every run's world may
## hold (`Run.unlocked_manufacturers`), whatever this profile's flight record
## and developer mode say. Empty keeps what `start_new_run` read -- and from the
## editor binary developer mode is on, so that is every manufacturer, within
## `DB.ACTIVE_MANUFACTURERS`. `unlocked=korvan` is a fresh profile's world.
var pin_unlocked: Array[StringName] = []
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
## How many things were taken out of containers across the run. The first
## number the sim has ever had for "did the pilot collect", which used to be
## true by construction.
var looted: int = 0
var postfight_samples := 0
var postfight_total := 0.0
var postfight_hot := 0
## The hellbender. `met` is landings on its system, because the first question
## about a roamer is whether a run even crosses its path; the rest is what the
## model did about it and what avoiding it cost in salvage.
## How long an ordinary fight lasts and what it costs: turns and hull lost per
## fight, and how many the model lost outright. Added for the enemy-block fix
## (combat polish, Oct 13): a block intent that finally works should make
## fights longer, and this is the number that says by how much.
var fights_n := 0
var fights_turns := 0
var fights_hull := 0
var fights_lost := 0
var hellbender_met := 0
var hellbender_fights := 0
var hellbender_kills := 0
var hellbender_escapes := 0
var derelicts_eaten := 0
## THE FOOD SUPPLY, which is the thing §9a asks about and nothing measured.
## `derelicts eaten` is a product of two numbers -- how often it moves, and how
## much of the chart is edible -- and tuning the wrong one of those is exactly
## the trap §9a names. So both are counted.
var hellbender_moves_total := 0
var arrived_stripped := 0
var food_systems := 0
var all_systems := 0

## WHAT A WON FIGHT PAYS, read out of the wrecks it left (Jon, Oct 13: "each ship
## you kill has a chance to get credits and modules and other parts"). Split by
## how many hulls the fight had: an ambush fields its whole pack, as the game
## does, and an option's fight one ship (reinforcements are gone). The set
## pieces are counted in the totals and left out of
## the split, since they pay by their own rules. `fight_credits` is what fights
## put into wrecks (and, for the custodian, the ledger); `credits_taken` is what
## the pilot banked from them after looting.
var won_by_pack: Dictionary = {}
var credits_by_pack: Dictionary = {}
var modules_by_pack: Dictionary = {}
var fight_credits := 0
var fight_modules := 0
var credits_taken := 0
var modules_taken := 0

## WHAT GOING DEEP PAYS (Jon, Oct 22: a hard game where going deep is worth it).
## `loot_mix` is every part and material lying in the run's systems when it
## ends -- wrecks, floor piles, bags, taken or not -- by the tier of the system
## it lay in (`MapGen.tier`), so the rarity ladder can be read against depth.
## The core is left out: the custodian's body is authored, not rolled by tier.
## `looted_scrap` is what the parts the pilot took would melt for and
## `looted_mat_value` what its materials list at; `credits_in` is every credit
## the run gained, from any source, read off `Sig.resources_changed` (every
## change to `Run.credits` goes through `add_credits`, which emits it).
## `core_fights` / `core_wins`: the ship the run built, against the custodian.
## Read-only, like `_tally`: nothing here draws from any stream.
var loot_mix: Dictionary = {}
var looted_scrap := 0
var looted_mat_value := 0
var credits_in := 0
var _credits_seen := 0
var core_fights := 0
var core_wins := 0

## Per galaxy kind: name -> {runs, wins, jumps, kills, systems}.
##
## NOT cleared by `_reset()`. That is called once per batch in the by-chassis
## sweep, and a per-kind table wants to span the whole sweep -- fifteen kinds
## across twenty-one chassis is already thin, and resetting it per chassis would
## leave every cell too small to read.
var by_kind: Dictionary = {}
## THE SAME SPLIT BY THE MANUFACTURER YOU LAUNCHED AS, with each death bucketed
## by what ended it. A new manufacturer switched on moves two things at once --
## its own runs, which can now find their sets, and everybody else's, whose
## branded drops are now shared -- and one win rate cannot say which moved.
var by_manufacturer: Dictionary = {}
## FLASHPOINT IN REAL FIGHTS: cards with the keyword played, and how many of
## those resolved over capacity (the bonus fired, read off the fight's own log
## line, so it counts what CardResolver did rather than what the sim expected).
var flash_played := 0
var flash_fired := 0
## Branded parts the pilot picked up, by manufacturer.
var aboard_by_manufacturer: Dictionary = {}

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
## Fights an event's outcome opened, and how many of them brought a creature,
## by kind -- the number Jon's Oct 17 ruling moves.
var option_fights := 0
var option_creatures: Dictionary = {}

## THE FUEL AUDIT (balance/fuel, Oct 17). `fueltrace=<path>` writes one JSON
## line a run: the tank at every departure and arrival, what each jump cost,
## what was bought and where the money went, and the two "did fuel bite"
## counts -- jumps where a seen, reachable star was too dear, and (human
## pilot) jumps where the star it wanted most was. Read by the scratchpad's
## fuel_report.py; nothing here changes how a run plays.
var sturdy := false
## The run-length study (balance/run-length, Oct 22). The Custodian's numbers
## as multiples of its own (`custhp=`, `custdmg=`, `custblock=`), or a loop
## swapped out (`custloop=`), applied to the template before any run; and what
## a run carried when it reached the core.
var _cust_hp := 1.0
var _cust_dmg := 1.0
var _cust_block := 1.0
var _cust_loop := ""
var st_reached := 0
var st_core_wins := 0
var st_rows: Array = []
var _fights_at_start := 0
var _credits_seen := 0
var _modules0 := 0
var _trace_path := ""
var _trace_file: FileAccess = null
var _tr: Dictionary = {}

## Entry point. Reads `runs=N` from the user args after `--`, plays that many
## complete runs, and prints the report. The caller quits the tree.
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
		# THE RUN-LENGTH STUDY'S FLAGS (balance/run-length, Oct 22). Off unless
		# given; see RunState.study_radius_scale and `_study_custodian`.
		# `depthcap=N` flies another depth rule than the game's one ring a jump
		# (RunState.DEPTH_STEP; 0 is August's, no cap), for comparison only.
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
	policy.dash = "dash" in OS.get_cmdline_user_args()
	policy.beeline = policy.dash or "beeline" in OS.get_cmdline_user_args()
	if policy.beeline:
		print("BEELINE policy: the deepest star it can afford, every jump%s." % [
			" (and no options taken)" if policy.dash else ""])
	if Run.depth_step != Run.DEPTH_STEP or Run.study_radius_rim != 1.0 or Run.study_radius_deep != 1.0:
		print("STUDY: depth cap %d · radius x%.2f at the rim, x%.2f at the last ring" % [
			Run.depth_step, Run.study_radius_rim, Run.study_radius_deep])
	_study_custodian()
	if "bossonly" in OS.get_cmdline_user_args():
		_boss_only()
		return
	policy.human = "human" in OS.get_cmdline_user_args()
	# A LENS, NOT A PLAYER: hull and heat restored at every arrival, so runs
	# live long enough for the fuel economy to be what is measured. Today's
	# pilot dies at ~11 jumps of fights and heat with 92% of the tank unspent,
	# which says nothing about fuel either way. Never a balance number.
	sturdy = "sturdy" in OS.get_cmdline_user_args()
	if sturdy:
		print("STURDY lens: hull and heat restored on every arrival.")
	if policy.human:
		print("HUMAN policy: heads for the core, scores the chart, buys fuel for the way in.")
	print("fuel: start %d · tank %d" % [Run.start_fuel(), Run.fuel_cap()])
	if _trace_path != "":
		_trace_file = FileAccess.open(_trace_path, FileAccess.WRITE)

	# THE SECOND POLICY `ENCOUNTER_REBUILD.md` 8 ASKS FOR. A greedy model takes
	# every check it is offered, which overstates income and makes the shortfall
	# ladder look free. `-- sim riskaverse` declines below Policy.RISK_FLOOR and
	# pays for the caution in what it never collects; running both on one seed is
	# how the exclusivity dial gets argued with rather than assumed.
	policy.risk_averse = "riskaverse" in OS.get_cmdline_user_args()
	# WITHOUT THIS THE SIM MEASURES A GAME WITH NO COMBAT. Fights live only in
	# option outcomes now, and Policy has no Combat of its own, so an unwired
	# `fight_cb` means every hostile line resolves to its prose and nothing shoots
	# back. It reported 0.2 kills a run before this was connected.
	policy.fight_cb = _option_fight
	Sig.log_line.connect(func(text: String, _kind: StringName) -> void:
		if text.begins_with("  flashpoint +"):
			flash_fired += 1)
	Sig.resources_changed.connect(func() -> void:
		var d := Run.credits - _credits_seen
		if d > 0:
			credits_in += d
		_credits_seen = Run.credits)
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
	if pin_manufacturer != &"":
		print("Every run flies %s." % pin_manufacturer)
	if not pin_unlocked.is_empty():
		print("Every run's world holds %s and unbranded." % ", ".join(pin_unlocked))
	for i in runs:
		_play_one(pin_manufacturer, -1, i)
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

## `index` exists so that `-- sim seed=N` gives every run its own reproducible
## seed rather than playing one run a thousand times. A sim that reports "40% of
## runs strand" is only actionable if one of those runs can be handed back:
## `-- seed <the number printed with the death>` flies it again exactly.
func _play_one(manufacturer: StringName = &"", w: int = -1, index: int = 0) -> void:
	Rng.forced = (seed_base + index) if seed_base != 0 else 0
	Run.start_new_run(manufacturer, w)
	# Before anything has been rolled from it: `start_new_run` rolls the map,
	# and no shelf, wreck or derelict is filled until it is reached.
	if not pin_unlocked.is_empty():
		Run.unlocked_manufacturers = pin_unlocked.duplicate()
	_credits_seen = Run.credits
	var started_as := Run.hull.manufacturer
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
	# Whether the ship just ARRIVED here by a jump. The game rolls an ambush on
	# arrival (`Router.resolve_current_node`, off `Sig.jumped`) and nowhere
	# else, so the start system is not rolled until a jump comes back to it, and
	# a jump `Run.jump_to` refused is no arrival at all.
	var arrived := false
	while not Run.won and not Run.dead and guard < 600:
		guard += 1
		var node: MapGen.MapNode = Run.node_at()
		if sturdy:
			Run.hp = Run.max_hp()
			Run.heat = 0

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
		#
		# AND NOW FIELDED AS THE GAME FIELDS IT, which it was not until Oct 17:
		# the sim fought the pack's lead alone, with `clears_node` true, so a
		# won ambush consumed the system and the options it held were never
		# taken; it rolled ambushes at stations, which never have fights
		# (`Router.no_fights_at`), and on cleared systems, which `_roll_here`
		# leaves alone; and it rolled one at the start system before any jump.
		# Now: the gates of `Router._roll_ambush`, on arrival only, and the
		# whole `Router.ambush_pack` with `clears_node` false, as
		# `Router.resolve_current_node` opens it.
		if arrived and not node.cleared and not node.ambush_rolled \
				and node.type != MapGen.NodeType.CORE and not Router.no_fights_at(node):
			node.ambush_rolled = true
			if Rng.foe.randf() < Run.ambush_chance(node):
				ambushes += 1
				jumped_hot = true
				var pack := Router.ambush_pack(node)
				if not pack.is_empty() and not _fight(pack[0], false, pack.slice(1)):
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
			# Always taken. A competent player does not walk past the best fuel
			# in the galaxy — the question the model cannot answer is whether
			# the hull cost is worth it, which is exactly what the win rate is
			# for.
			var pf := Run.fuel
			Run.harvest_pulsar()
			_tr.pulsar_fuel += Run.fuel - pf
			if Run.dead:
				break
		# WHAT THE SYSTEM OFFERS, taken by the policy rather than by the type.
		#
		# THE ONLY WAY AN ORDINARY SYSTEM RESOLVES, since the collapse. It used to
		# run beside FIGHT and DERELICT branches that did the same work off a
		# label; those are gone and this is what replaced them, fights included --
		# `policy.fight_cb` is wired to `_fight` below.
		if not node.cleared:
			var of := Run.fuel
			var got := policy.take_options(node)
			_tr.event_fuel += Run.fuel - of
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
		_audit_jump(node, pick)
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
		# ARRIVING SOMEWHERE ALREADY STRIPPED is the only way the hellbender's
		# appetite actually costs the player anything. A wreck it ate in a system
		# nobody was ever going to fly to is a number, not a loss, and §9a's
		# worry is "salvage the party does not get".
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
		# What SHARE of the chart the hellbender could have eaten, asked the
		# same way it asks. `system_has_tag` rolls an unvisited system's options
		# to answer, which is why this runs at the end of a run and not during.
		all_systems += 1
		if OptionTable.system_has_tag(mn, &"salvage"):
			food_systems += 1
	hellbender_moves_total += Run.hellbender_moves
	total_jumps += Run.jumps
	total_kills += Run.kills
	total_danger += Run.node_at().danger
	end_fuel_total += Run.fuel
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
		_trace_file.store_line(JSON.stringify(_tr))
		_trace_file.flush()
	if Run.won:
		wins += 1
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

## Competent-player model: lock on before attacking, brace against telegraphed
## damage, vent before overheating, and never overheat unless it secures a kill.
## A fight an option opened, against whatever this system would field.
##
## The ship is `Router.option_foe`, the one `Router.start_ambush` fields when an
## option's outcome says "fight": one ship off `Rng.foe` from the danger's
## ordinary pool. It was this file's own pick, with fauna where the region is
## fauna -- and the game's never is, so in fauna space the sim fought whales
## (no money, no parts) where the game fights ships.
##
## `foe` is the event's creature tag (`OptionTable.fight_foe`), as the screen
## hands it to `Router.start_ambush`: a creature event's fight brings that
## creature, everything else a ship.
func _option_fight(n: MapGen.MapNode, foe: StringName = &"") -> bool:
	if foe == &"" and DB.fight_pool(n.danger, false).is_empty():
		return not Run.dead
	# Not consuming, for the reason `Router.start_ambush` spells out: the option
	# spends itself and the system is finished when nothing is left in it. A sim
	# that cleared the node here would take fewer options than the game does.
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
	# AND THEN YOU GO AND LOOK IN IT. A kill fills a container at the node now
	# rather than putting parts in your hold, so a sim that does not reach into
	# one is a sim whose pilot never picks anything up. See `Policy.loot`.
	_tally(cb, wrecks0, cr0)
	if not Run.dead:
		_loot()
	postfight_samples += 1
	postfight_total += Run.signature()
	if Run.signature() > Run.SIGNATURE_FLOOR:
		postfight_hot += 1
	return not Run.dead


## The model's turns until the fight ends (or 60 turns), and how many it took.
## Every fight the sim plays goes through here, the Hellbender's too: its own
## copy of this loop never answered a pending pick, so a card that asked one
## locked the rest of that turn, which no player is made to do.
func _play_out(cb: Combat) -> int:
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


## What one won fight put into the wrecks it made (and, for the custodian, the
## ledger). Read-only: it draws nothing from any stream, so the runs it watches
## are the runs the sim always played.
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


## The set piece, carried damage and all. Differs from _fight() in exactly the
## ways the game does: the enemy opens at the hull the map says it has, winning
## does not consume the system, and there are three endings — it dies, it
## leaves, or you do.
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
	# WHAT THE PILOT COLLECTED. Zero here means every wreck in the galaxy was
	# walked past, which is the failure this number exists to make impossible to
	# miss -- it was zero by construction until containers landed.
	print("looted %d items across %d runs (%.1f per run)"
		% [looted, maxi(1, runs), float(looted) / float(maxi(1, runs))])
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
	# The heat layer, reported separately because it is the newest thing in the
	# economy and the first question about any tuning pass on it is whether it
	# fired at all.
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
	_report_deep()
	_report_kinds()
	_report_manufacturers()
	_report_study()
	print("---")
	print("Healthy target: 40-55% win rate for this competent-player model.")
	print("Too easy? Raise station repair prices before touching enemy damage —")
	print("this design's difficulty lives in the economy, not in single fights.")


## THE RUN-LENGTH STUDY (balance/run-length, Oct 22). The Custodian's template
## scaled before any run, so every fight with it -- the core's and `bossonly`'s
## -- meets the same numbers. Nothing here is a ruling; with no flags it is a
## no-op.
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
	var spent := int(policy.spend.fuel) + int(policy.spend.repair) + int(policy.spend.options)
	return {
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


static func _median(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var s := a.duplicate()
	s.sort()
	var m := s.size() / 2
	return float(s[m]) if s.size() % 2 == 1 else (float(s[m - 1]) + float(s[m])) * 0.5


func _report_study() -> void:
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


## THE CUSTODIAN AGAINST A FRESH SHIP (`-- sim bossonly`): each Korvan weight
## at grade C with its starter kit, flown straight to the core and into the
## fight with nothing else done, `runs` times each.
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


## Before every jump: did fuel narrow the choice, and would the fuel hint be up?
## The first jump the hint's rule is true on is kept, with whether it would have
## named a dock (`Run.nearest_dock`) -- the warning a stranded run had.
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
