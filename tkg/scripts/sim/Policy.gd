class_name Policy
extends RefCounted

## The competent-player model, as a thing rather than as a loop.
##
## This is `HeadlessSim`'s pilot, lifted out of it unchanged. It was extracted
## for one reason: the party bot needed a brain, and a bot with its OWN brain
## would be a second pilot model that nothing measures. The gate plays this one
## two hundred times before every merge and reports its win rate; a second copy
## in `BotPilot` would drift away from that number quietly, and the first sign
## would be a bot that plays visibly worse than the simulator says the game
## plays. One model, two callers.
##
## Frame-free on purpose. Nothing here awaits, and nothing here touches a
## screen, so it runs identically inside `HeadlessSim`'s tight synchronous loop
## and inside `BotPilot`'s frame-driven one. That is the whole reason the split
## lands on this line and not somewhere more natural-looking: the SIM's loop and
## the BOT's loop cannot be shared — one must not yield and the other must — but
## every decision inside them can.
##
## It reads `Run` and a `Combat` and mutates them. That is not a layering
## mistake, it is what a player does.

## Spend heat for tempo, or vent on sight. `-- sim hot` flips this, and it is
## most of the difference between the two policies the simulator reports.
var hot: bool = false

## When each model reaches for a vent card, as a fraction of heat capacity.
##
## THESE TWO NUMBERS ARE THE TWO POLICIES. The comment at the threshold says it
## outright, and after the end-of-turn shed was deleted they stopped doing the
## job: hot and cold ended a fight at 0.32 and 0.31 signature and arrived hot
## 9.4% of the time each. Identical heat behaviour from the two models that
## exist to bracket it.
##
## Sweepable from the command line -- `-- sim ventcold=0.5 venthot=1.0` -- so
## that retuning them is a measurement rather than an argument.
## When each model reaches for a vent card, as a fraction of heat capacity.
##
## THESE TWO NUMBERS ARE THE TWO POLICIES -- and they are UNCHANGED after being
## swept on 2026-08-25, because the sweep says they do not matter.
##
## The suspicion was reasonable. They were chosen when a free point of heat came
## off every turn, and deleting that shed should have made both models hold vent
## cards too long. An unpaired sweep at 300 runs a cell appeared to confirm it,
## with both old values landing worst in their own column.
##
## THAT SWEEP WAS MEASURING THE GALAXY, NOT THE THRESHOLD. Every run rolls a
## different galaxy and the kind alone swings win rate 33 to 38 points, which
## is an order of magnitude more than this dial. Re-run PAIRED -- `seed=1000`,
## so both configs face the same 500 galaxies -- it collapses:
##
##     cold 0.50   win 27% (135)   cooked 52   fightsig 0.31   arrived hot 8.4%
##     cold 0.70   win 26% (129)   cooked 53   fightsig 0.32   arrived hot 8.6%
##     hot  1.00   win 26% (128)   cooked 65   fightsig 0.34   arrived hot 9.3%
##     hot  1.15   win 26% (128)   cooked 62   fightsig 0.34   arrived hot 9.2%
##
## Six wins in five hundred between the cold pair, none at all between the hot
## pair, and every heat number the same. So the values stay where they are: a
## change with no measured effect is a diff somebody has to read later for
## nothing.
##
## WHY THE DIAL IS INERT, and it is not a heat problem at all.
##
## THE HOT POLICY IS MODELLING SOLARI, ON A KORVAN SHIP. `design-doc.md` has
## them as mirrored heat philosophies -- Korvan MANAGES heat, Solari SURFS it --
## and Korvan is the starter kit and the only entry in ACTIVE_MANUFACTURERS. So
## the model is asking the cold manufacturer to run hot, using the cold
## manufacturer's loot. It loses because it should.
##
## The three cards that want heat high are all Solari: Plasma Lance
## (`heat_scale`), Thermal Purge (`damage_equals_heat`), Heat Shroud
## (`brace_from_heat`). Solari is SEVEN modules of a targeted forty and does not
## drop, so those cards are unreachable in a normal run.
##
## This dial becomes meaningful when Solari is written and switched on -- that
## is blocker B4, already tracked -- and not before. Tuning it against Korvan is
## tuning the wrong ship.
##
## Sweepable from the command line -- `-- sim ventcold=0.5 venthot=1.0` --
## and ALWAYS PAIRED with `seed=`, or the galaxy roll drowns the answer.
var vent_cold: float = 0.7
var vent_hot: float = 1.15

## The pilot's own generator. One per run, seeded from the run's master seed, so
## the model's choices replay with the run and drawing them does not move what
## the world rolls next.
##
## Assigned by the caller — `Rng.derive(&"pilot", 0)` — rather than seeded here,
## because a bot in a party must NOT share it with the sim's convention. See
## `BotPilot._brain_up()`.
var pilot: RandomNumberGenerator = RandomNumberGenerator.new()

## Lateral hops already spent in each ring this run. See FARM_LIMIT.
var _farmed: Dictionary = {}


## Called at the top of every run. The farm counters are per-run state and a
## Policy outlives a run in the by-chassis sweep.
func begin_run() -> void:
	_farmed.clear()

## What the model is willing to haul. A BEHAVIOUR, not a capacity — hulls hold
## 8 / 12 / 16. A competent player does not carry twenty parts hoping for a
## buyer; they keep the few worth a detour and scrap the rest where they stand.
## It must stay at or under the smallest hull's capacity or the model would be
## measuring a hold no ship in the game has.
const HOLD_LIMIT := 4

## Top up to half a tank at a station, and never below this many credits.
##
## The reserve exists because hull loss kills more runs than fuel does: a model
## that spends its last credit on fuel arrives at the next fight unable to
## repair, which is a worse death for the same money.
const FUEL_TOPUP := 0.5

## How many lateral hops the model will spend in one ring before descending.
##
## Unbounded farming is not a strategy, it is a loop: the old rule moved
## laterally on every unhealthy turn, so a damaged ship circled its ring picking
## up more damage until something killed it. Three is enough to visit a station
## and a couple of sites and still be going somewhere.
const FARM_LIMIT := 3
const FUEL_RESERVE := 40


## The best card in hand to play right now, or -1 to stop playing.
##
## The heat ceiling is checked HERE rather than inside score(), because it is a
## legality question and not a preference one: a card that cooks the ship is not
## a bad play, it is a play the model has decided it is not making this turn.
func best_card(cb: Combat) -> int:
	var best := -1
	var best_score := 0.0
	for i in cb.hand.size():
		var c := cb.hand[i]
		if not cb.can_play(c):
			continue
		var projected := Run.heat + c.heat - Run.dissipation()
		# The hot model tolerates sitting over capacity; the cold one only
		# crosses it to close out a kill. Same ceiling either way, so neither is
		# suicidal — the difference is how long it is willing to stay up there.
		var ceiling := Run.heat_cap() + (12 if hot else 3)
		if projected > ceiling and c.heat > 0 and cb.enemy != null and cb.enemy.hp > 30:
			continue
		var s := score(c, cb)
		if s > best_score:
			best_score = s
			best = i
	return best


## Lock on before attacking, brace against telegraphed damage, vent before
## overheating, and never overheat unless it secures a kill.
func score(c: CardData, cb: Combat) -> float:
	if c.unplayable:
		return -1.0
	var incoming := 0
	if cb.enemy != null and cb.enemy.intent != null:
		incoming = cb.enemy.intent.damage * maxi(1, cb.enemy.intent.hits)
	if c.energy_gain > 0:
		return 95.0
	if c.lock_on > 0:
		return 90.0
	# Venting is the first thing the cold model reaches for and nearly the last
	# thing the hot one does. This single threshold is most of the difference
	# between the two policies.
	if c.vent > 0 and Run.heat > Run.heat_cap() * (vent_hot if hot else vent_cold):
		return 85.0
	if (c.brace > 0 or c.block > 0) and incoming > cb.brace + cb.block:
		return 80.0
	# Repair, and it RISES AS THE HULL FALLS rather than sitting at one number.
	#
	# The flat 75 modelled a player who repairs when convenient. It ranked below
	# brace and venting at every level of damage, so at three hull the model
	# braced against a hit it could not survive instead of buying the turn that
	# would let it. That is not a competent player, and the repair cards are now
	# scaled on hull missing — see CardData.heal_scale — so the card the model was
	# declining is the biggest one in the deck exactly when it declined it.
	#
	# Below a fifth of your hull it outranks everything except a lock that is
	# already paid for. Between a fifth and a half it sits where it used to.
	if (c.heal > 0 or c.heal_scale > 0) and Run.hp < Run.max_hp() * 0.5:
		return 92.0 if Run.hp < Run.max_hp() * 0.2 else 75.0
	if c.draw > 0 and c.damage == 0:
		return 70.0
	if c.charge_turns > 0:
		return 65.0
	if c.damage > 0:
		return 40.0 + float(c.damage * maxi(1, c.hits)) / 4.0
	return 5.0


## Install what improves the ship; carry a few of the rest to the next market.
##
## The model used to melt everything it did not install, the instant it picked
## it up. That was correct when melting was the only thing you could do with a
## part and it is not any more — a hold that is always empty means the simulator
## can never once exercise the thing this economy is built around, and would
## report a win rate for a game with no market in it.
func manage_cargo() -> void:
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
			Run.take_from_hold(m)
			passed.append(m)
	for m in passed:
		# Back through the door so it is given a cell again. A bare append
		# leaves it at (-1,-1) claiming none, and the model would then be
		# measuring a hold that overlaps itself.
		if not Run.place_in_hold(m):
			Run.scrap_module(m)
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


## Dock. Sell first, then spend — which is what a player does, and which is the
## only order that lets a hold full of salvage pay for the repair.
##
## The model deliberately does NOT buy stock to resell. Trade routes are a
## strategy the player can find; assuming a competent player already runs one
## would report a win rate for a game nobody has played yet.
func shop(n: MapGen.MapNode) -> void:
	sell_hold(n)
	bench(n)

	var missing := Run.max_hp() - Run.hp
	var repair := Market.repair_price(n, missing)
	if missing > 0 and Run.credits > repair + 25:
		Run.add_credits(-repair)
		Run.heal(missing)
	# A COMPETENT PILOT TOPS UP; they do not coast to empty and hope for a
	# station. `Run.fuel < 8` was the old test, and it is a fault in the
	# INSTRUMENT rather than a fact about the game -- see the note on
	# RunState.FUEL_PER_DISC_RADIUS, which records the same lesson about the
	# jump policy. With a tank that starts at 279 that test fires about once a
	# run: the model sailed past twenty-one stations declining fuel and then
	# stranded when it finally ran low somewhere without one.
	#
	# Measured before the change: 21.5 stations a run, 11 fuel bought across all
	# of them, and 20% of runs ending blocked by fuel while sitting on 125
	# credits of profit.
	#
	# Tops up toward half a tank, keeping a credit reserve so refuelling never
	# eats the repair budget -- hull loss is the largest death cause and buying
	# fuel instead of a hull is not competence.
	var tank := Run.FUEL_PER_RING_STEP * float(MapGen.LAYERS - 2)
	var want := int(tank * FUEL_TOPUP)
	var refuel := Market.refuel_price(n)
	while Run.fuel < want and Run.credits >= refuel + FUEL_RESERVE:
		Run.add_credits(-refuel)
		Run.fuel += Market.REFUEL_UNITS


## Anything left in the hold at a station was already destined for scrapping —
## manage_cargo() ran on arrival and kept what was worth installing. So take
## whichever of the two prices is higher, which is the one decision selling
## actually adds.
func sell_hold(n: MapGen.MapNode) -> void:
	var guard := 0
	while not Run.cargo.is_empty() and guard < 24:
		guard += 1
		var m: ModuleData = Run.cargo[0]
		var paid := Market.bid(n, m)
		if paid > Run.scrap_value_of(m):
			Run.take_from_hold(m)
			Run.add_credits(paid)
			n.trades += 1
		else:
			Run.scrap_module(m)


## Fabricate whatever is both affordable and better value than buying the same
## thing off the service desk. Hull patches and fuel synthesis are the two that
## compete directly with a price on the same screen, so they are the two the
## model can judge; the other recipes are build decisions it has no opinion on.
func bench(n: MapGen.MapNode) -> void:
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


## Where to go from here, or -1 when there is nowhere legal to go.
##
## Farm laterally while the tank allows it, then descend.
##
## A COMPETENT PLAYER WATCHES THE TANK. This used to farm laterally on a 65%
## coin whatever the fuel gauge said, and always when hurt — so the model
## wandered until it ran dry, and the average run came out at 117 jumps. That is
## not a fact about the game; it is a fact about this function. Tuning the fuel
## economy to bring the number down would have been tuning the game against a
## model artifact, and it would have made the real game punitive to fix a bug in
## here.
##
## Farming is what you do when you can afford it. With the tank low, the only
## move that ends well is onward — and a player who has decided to descend
## descends whether or not they are healthy, because sitting still does not heal
## you.
## Whether the model commits to the hellbender when it lands on one. Health-gated
## rather than build-gated: the model cannot read its own deck quality, but a
## player at full hull who has found a set piece engages it and a player at
## half does not. Damage banked from a previous engagement makes the fight
## strictly better, so the bar drops with the hellbender's own hull.
func engage_hellbender() -> bool:
	var mine := float(Run.hp) / float(maxi(1, Run.max_hp()))
	var its := float(Run.hellbender_hp) / float(maxi(1, Run.hellbender_max))
	return mine >= 0.45 + its * 0.3

## Whether this pilot declines long odds.
##
## The second policy `ENCOUNTER_REBUILD.md` §8 asks for. A greedy model takes
## every check it is offered, which overstates income and makes the shortfall
## ladder look free; a risk-averse one refuses below `RISK_FLOOR` and pays for
## the caution in what it never collects. Running both is how the exclusivity
## dial gets argued with rather than assumed.
var risk_averse: bool = false

## How often caution took the safe line instead of the check.
##
## `declined` counts walking away from an option ENTIRELY, and it measured
## nothing: a cautious pilot almost never does that, it takes the unchecked
## fallback instead. So the two policies differed by eight points of win rate
## with an identical `declined` of 0.00, and the number that was supposed to
## explain the gap could not see it.
##
## This is what caution actually costs, and what it buys.
var checks_avoided := 0

## The odds a cautious pilot will not go below.
##
## `SkillCheck.ODDS` is [1.0, 0.65, 0.40, 0.20, 0.05] by shortfall, so 0.45 sits
## between one pip short and two: this pilot takes a check it is one under and
## declines one it is two under. Not a ruling -- a starting point for the sweep
## §8 asks for.
const RISK_FLOOR := 0.45

## Runs a fight the way this harness runs fights, and reports whether we lived.
##
## Injected because a policy has no Combat of its own and should not: the sim
## owns the loop, the postfight sampling and the turn cap. Left invalid, fights
## are counted and not run -- which is a measurement of a different game, so any
## harness that reports a win rate must set this.
var fight_cb: Callable = Callable()


## Take what this system offers, and report what was left behind.
##
## GROUPS ARE THE POINT. Taking an option marks its group spent and every other
## option in that group becomes unavailable -- so a grouped system is a system
## where arriving rich means choosing what to leave. `forgone` counts exactly
## that, and it is the number §8 says the model must be able to report.
func take_options(n: MapGen.MapNode) -> Dictionary:
	var out := {"taken": 0, "declined": 0, "forgone": 0, "fights": 0}
	if n == null or not OptionTable.ensure(n):
		return out
	var spent: Dictionary = {}
	for i in n.options.size():
		var opt := OptionTable.by_id(n.options[i])
		if opt.is_empty():
			continue
		var oid := MapGen.OPTION_SITE + i
		if n.taken.has(oid):
			continue
		var g := StringName(opt.get("group", &""))
		if g != &"" and spent.has(g):
			# Not declined -- FORGONE. The pilot never got to weigh it, because
			# something else in its group was taken first.
			out.forgone += 1
			continue
		var pick := _choose_line(opt)
		if pick < 0:
			out.declined += 1
			continue
		var line: Dictionary = (opt.choices as Array)[pick]
		var res := _resolve_line(n, line)
		n.taken.append(oid)
		out.taken += 1
		if g != &"":
			spent[g] = true
		if Run.dead:
			break
		# AND NOW THE FIGHT, if the outcome opened one. This used to be counted
		# and skipped, which was defensible while FIGHT was still a node type and
		# the sim fought there instead. It is not defensible now: fights exist
		# ONLY as option outcomes, so skipping them meant simulating a game with
		# no combat in it -- 0.2 kills a run, and a win rate measuring the wrong
		# game. `fight_cb` is the sim's own `_fight`, handed in because Policy
		# does not own a Combat.
		if bool(res.get("fight", false)):
			out.fights += 1
			if fight_cb.is_valid() and not fight_cb.call(n):
				break
	return out


## Which line of an option to take, or -1 to walk away.
##
## Prefers a check this pilot will pass over a flat effect, because the checked
## bands are where the payouts are -- but only when the odds clear the floor. A
## cautious pilot falling back to the unchecked line is the whole difference
## between the two policies.
func _choose_line(opt: Dictionary) -> int:
	var choices: Array = opt.get("choices", [])
	var fallback := -1
	for i in choices.size():
		var c: Dictionary = choices[i]
		if c.has("cost_credits") and Run.credits < int(c.cost_credits):
			continue
		if not c.has("check"):
			if fallback < 0:
				fallback = i
			continue
		if risk_averse and SkillCheck.odds(c.check) < RISK_FLOOR:
			checks_avoided += 1
			continue
		return i
	return fallback


## Run one line and grant what it pays.
##
## The reward class is §5's: an option that says `module` pays one rolled at the
## system's own danger, which is where `LootGen`'s rarity floors do the
## high-risk half by themselves.
func _resolve_line(n: MapGen.MapNode, line: Dictionary) -> Dictionary:
	var res: Dictionary = {}
	if line.has("check"):
		var band := SkillCheck.roll(line.check)
		var cb: Callable = SkillCheck.pick_outcome(line, band)
		if cb.is_valid():
			res = cb.call()
	elif line.has("effect"):
		var cb2: Callable = line.effect
		if cb2.is_valid():
			res = cb2.call()
	if typeof(res) != TYPE_DICTIONARY:
		return {}
	if bool(res.get("module", false)):
		Run.place_in_hold(LootGen.roll_module(n.danger))
	# Handed back rather than consumed here, because `fight` is the caller's
	# business: this function grants rewards, it does not start battles.
	return res


func choose_jump(node: MapGen.MapNode) -> int:
	# IN RANGE, NOT LINKED. `links` is the graph the chart DRAWS; it is not the
	# graph the ship flies. `can_jump_to` is `reachable_from` plus fuel, and
	# `reachable_from` is a radius that never consults `links` -- the chart's own
	# neighbour list is `in_range()`, which is what the player picks from.
	#
	# Routing on links made the simulator play a narrower game than the one that
	# ships, and it showed: the policy running out of charted options was being
	# counted as the run ending, and 46% of those ships could still fly.
	var options: Array[int] = []
	for n in Run.in_range_of(node):
		if Run.can_jump_to(n):
			options.append((n as MapGen.MapNode).index)
	if options.is_empty():
		return -1
	var lateral: Array[int] = []
	var sideways: Array[int] = []
	var forward: Array[int] = []
	for idx in options:
		var t: MapGen.MapNode = Run.map[idx]
		if t.layer == node.layer:
			# `lateral` is somewhere worth STOPPING; `sideways` is anywhere in
			# this ring at all, cleared or not. They used to be the same list,
			# which was fine while every system had a way down and travelling
			# was never necessary.
			sideways.append(idx)
			if not t.cleared:
				lateral.append(idx)
		elif t.layer > node.layer:
			forward.append(idx)
	var healthy := Run.hp > Run.max_hp() * 0.6
	# SCALED TO THE TANK, not a flat 45. That number meant "fuel to spare" when
	# a run started with 150; at 279 it is true almost always and the gate never
	# closes. Three tenths reproduces the old proportion.
	var tank := Run.FUEL_PER_RING_STEP * float(MapGen.LAYERS - 2)
	var can_wander := float(Run.fuel) > tank * 0.3
	# AND THE RING HAS TO HAVE SOMETHING LEFT. `not healthy` used to force a
	# lateral hop, which meant a damaged ship could not descend at all -- it
	# circled taking damage until it died. Being hurt still biases toward
	# farming, it just no longer forbids leaving.
	var spent: int = int(_farmed.get(node.layer, 0))
	var want_lateral := pilot.randf() < (0.65 if healthy else 0.85)
	if not lateral.is_empty() and can_wander and want_lateral \
			and spent < FARM_LIMIT:
		_farmed[node.layer] = spent + 1
		return Rng.pick(pilot, lateral)
	if not forward.is_empty():
		return Rng.pick(pilot, forward)

	# NO WAY DOWN FROM HERE, so walk the ring until there is one. Since sparse
	# coreward links landed, most systems have no door and this is the ordinary
	# case rather than an edge one -- the old fallback picked at random from
	# every link including BACKWARD ones, which on a sparse map is a random walk
	# that ends when the fuel does. Measured before this: 70 jumps at an average
	# danger of 1.8, which is seventy hops without leaving the rim.
	#
	# Prefers a neighbour that can itself descend, so the walk is toward
	# something rather than merely away. These hops are travel, not farming, and
	# deliberately do not count against FARM_LIMIT: a limit on how much you farm
	# should not also be a limit on how far you may walk to leave.
	if not sideways.is_empty():
		# ALSO IN RANGE RATHER THAN LINKED, for the same reason: "can this
		# neighbour get further in" is a question about what it can REACH.
		#
		# This is the expensive branch -- a map-wide pass per candidate -- but it
		# now almost never runs. `forward` is only empty when nothing deeper is
		# in radius at all, which a radius reaching several rings rarely manages.
		var doors: Array[int] = []
		for idx in sideways:
			for t in Run.in_range_of(Run.map[idx]):
				if (t as MapGen.MapNode).layer > node.layer:
					doors.append(idx)
					break
		if not doors.is_empty():
			return Rng.pick(pilot, doors)
		return Rng.pick(pilot, sideways)
	return Rng.pick(pilot, options)
