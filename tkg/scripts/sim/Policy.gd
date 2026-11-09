class_name Policy
extends RefCounted

## One pilot model for the gate and the bot, so the bot's skill cannot drift from the measured rate.
## Frame-free: the sim loop must not yield and the bot's must, but decisions can be shared.
## Why: docs/why/Policy.md#pilot-model

## Spend heat for tempo, or vent on sight. `-- sim hot` flips this, and it is
## most of the difference between the two policies the simulator reports.
var hot: bool = false

## Unchanged after the 2026-08-25 sweep: paired at 500 galaxies, the dial moves nothing.
## The hot policy models Solari on a Korvan ship; it matters once Solari is on (B4).
## Why: docs/why/Policy.md#vent-thresholds
var vent_cold: float = 0.7
var vent_hot: float = 1.15

## Assigned by the caller, not seeded here, since a party bot must not share the sim's stream.
## Why: docs/why/Policy.md#pilot-rng
var pilot: RandomNumberGenerator = RandomNumberGenerator.new()

## Lateral hops already spent in each ring this run. See FARM_LIMIT.
var _farmed: Dictionary = {}


## Take the most valuable thing that fits until nothing does; never scrap to make room.
## Needed since `MATERIALS_NOTE` 3.6: payouts are now places the sim can fail to reach.
## Why: docs/why/Policy.md#cargo-policy
static func loot(n: MapGen.MapNode) -> int:
	if n == null:
		return 0
	var took := 0
	while true:
		var best := -1
		var best_worth := -1
		var from: MapGen.Jetsam = null
		# Weigh every container in the system together; a pilot takes the best they can carry.
		for raw in n.jetsam:
			var h: MapGen.Jetsam = raw
			for i in h.items.size():
				if n.taken.has(h.option(i)):
					continue
				var m: HoldItem = h.items[i]
				if not Run.has_room_for(m):
					continue
				var worth := _worth(m)
				if worth > best_worth:
					best_worth = worth
					best = i
					from = h
		if best < 0 or from == null:
			return took
		# Not awaited: solo has no round trip to make, and the sim is solo. A
		# party's claim is a network question and this is not that.
		if not Run.stow(from.items[best]):
			return took
		n.taken.append(from.option(best))
		took += 1
	return took


## What a thing is worth to a pilot deciding what to carry.
static func _worth(m: HoldItem) -> int:
	# Money first, always. It costs no room, so there is never a reason to
	# leave it and never a trade to weigh it against.
	if m is CreditChit:
		return 1 << 30
	if m is MaterialData:
		return (m as MaterialData).value
	return Market.base_value(m as ModuleData)


## Called at the top of every run. The farm counters are per-run state and a
## Policy outlives a run in the by-chassis sweep.
func begin_run() -> void:
	_farmed.clear()
	spend = {fuel = 0, repair = 0, options = 0, augment = 0}
	sci = new_sci()
	fuel_bought = 0
	refuel_stops = 0
	rescues = 0
	limited = false


## Counts the places this pilot spends, for the fuel audit (balance/fuel, Oct 17):
## the desks, an option's price and (science) the Lab's AUGMENT.
var spend: Dictionary = {fuel = 0, repair = 0, options = 0, augment = 0}

## SCIENCE (Phase 12, Jon's picks 1A 2B 3A 4B, and "science costs fuel"). False
## is a pilot that takes every reading's credits line and never spends DATA:
## `-- sim science=off` (with `Run.science_off`, the world main rolls) and
## `-- sim science=ignore` (the world keeps its readings; this pilot sells them).
##
## EVERY SCIENCE RULE BELOW DRAWS FROM NO STREAM, `pilot` included. A reading is
## taken or sold on what the ship holds, and the Lab is a list in a fixed order,
## so a run with science off flies exactly the run main flew.
var science: bool = true

## What science did this run, for `HeadlessSim._report_science`. Reset by
## `begin_run`. `met` readings come to, and which line was taken (`careful`,
## `risky`, `credits`); `refused` a reading's DATA lines the fuel gate shut;
## DATA by where it came from (`data_careful`, `data_risky` out of the events,
## `data_film`, `data_relic` out of the Lab's bench); `fuel` burned on readings;
## `augments` and what they cost (`aug_data`, `aug_credits`) and put on
## (`affixes`, name to count).
var sci: Dictionary = new_sci()

static func new_sci() -> Dictionary:
	return {met = 0, careful = 0, risky = 0, credits = 0, refused = 0,
		data_careful = 0, data_risky = 0, data_film = 0, data_relic = 0, fuel = 0,
		augments = 0, aug_data = 0, aug_credits = 0, affixes = {}}
var fuel_bought := 0
var refuel_stops := 0
## REFUELs that were the way out of a dock (`Run.dock_rescue`), a run.
var rescues := 0

## A person heading for the core, unlike the gate's farmer, who picks stars at random.
## Why: docs/why/Policy.md#human-pilot
var human: bool = false
## Set by `choose_jump` in human mode: the star it scored best was in reach and
## seen but not affordable, so it flew its second choice.
var limited: bool = false

## A behaviour, not a capacity: keep it at or under the smallest hull's 8 slots.
const HOLD_LIMIT := 4

## Top up to full but keep a credit reserve: hull loss kills more runs than fuel does.
## Why: docs/why/Policy.md#fuel-policy
const FUEL_TOPUP := 1.0

## Cap lateral hops per ring: the old rule circled a damaged ship until something killed it.
## Why: docs/why/Policy.md#jump-policy
const FARM_LIMIT := 3
const FUEL_RESERVE := 40


## The heat ceiling is checked here, not in `score()`: it is legality, not preference.
func best_card(cb: Combat) -> int:
	var best := -1
	var best_score := 0.0
	for i in cb.hand.size():
		var c := cb.hand[i]
		if not cb.can_play(c):
			continue
		var projected := Run.heat + c.heat - Run.dissipation()
		# Same ceiling for both models; the hot one is willing to stay over it longer.
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
	# The vent threshold is most of the difference between the cold and hot policies.
	if c.vent > 0 and Run.heat > Run.heat_cap() * (vent_hot if hot else vent_cold):
		return 85.0
	if (c.brace > 0 or c.block > 0) and incoming > cb.brace + cb.block:
		return 80.0
	# Repair rises as the hull falls: a flat 75 braced against hits the model could not survive.
	# Why: docs/why/Policy.md#card-scoring
	if (c.heal > 0 or c.heal_scale > 0) and Run.hp < Run.max_hp() * 0.5:
		return 92.0 if Run.hp < Run.max_hp() * 0.2 else 75.0
	if c.draw > 0 and c.damage == 0:
		return 70.0
	if c.charge_turns > 0:
		return 65.0
	if c.damage > 0:
		# Flashpoint pays only over the cap, so the pilot reaches for it there.
		var per := c.damage + (c.flashpoint if Run.heat > Run.heat_cap() else 0)
		return 40.0 + float(per * maxi(1, c.hits)) / 4.0
	return 5.0


## Carry a few to the next market: always melting meant the sim never used the economy.
## Why: docs/why/Policy.md#cargo-policy
func manage_cargo() -> void:
	var guard := 0
	var passed: Array[HoldItem] = []
	while not Run.cargo.is_empty() and guard < 24:
		guard += 1
		var item: HoldItem = Run.cargo[0]
		# A material is cargo, not a fitting: it leaves the queue, then returns to the hold below.
		var m := item as ModuleData
		if m == null:
			Run.take_from_hold(item)
			passed.append(item)
			continue
		var free := Run.slots_used(m.slot) < Run.slots_for(m.slot)
		var worst := _worst_fitted(m.slot)
		if free or (worst != null and m.scrap_value > worst.scrap_value * 1.15):
			Run.install_module(m)
		else:
			# Out of the queue and into the hold, so the loop terminates.
			Run.take_from_hold(m)
			passed.append(m)
	for it in passed:
		# Re-place through `place_in_hold` so it gets a cell; a bare append overlaps the hold.
		if not Run.place_in_hold(it):
			_shed(it)
	while Run.cargo.size() > HOLD_LIMIT:
		var cheapest: HoldItem = Run.cargo[0]
		for it2 in Run.cargo:
			if _worth(it2) < _worth(cheapest):
				cheapest = it2
		_shed(cheapest)


## The fitted part in `slot` a better find would replace: the cheapest.
##
## AN AUGMENTED PART IS NEVER THE ONE, unless it is the only part in its slot.
## The Lab's work on it (DATA and credits, once per part ever) is not in its
## scrap value, which AUGMENT leaves alone, so measured by price alone the pilot
## would melt what it just paid for. With science off no part is augmented and
## this is the old cheapest-in-the-slot.
static func _worst_fitted(slot: ModuleData.Slot) -> ModuleData:
	var worst: ModuleData = null
	var plain_worst: ModuleData = null
	for x in Run.installed:
		if x.slot != slot:
			continue
		if worst == null or x.scrap_value < worst.scrap_value:
			worst = x
		if not x.augmented and (plain_worst == null or x.scrap_value < plain_worst.scrap_value):
			plain_worst = x
	return plain_worst if plain_worst != null else worst


## A part melts; a material cannot, so it goes over the side and stays in the system.
func _shed(it: HoldItem) -> void:
	var m := it as ModuleData
	if m != null:
		Run.scrap_module(m)
	else:
		Run.jettison(it)
	if Run.found_hull != null:
		if Run.found_hull.max_hull > Run.max_hp() or Run.found_hull.tier > Run.hull.tier:
			Run.transfer_to_hull(Run.found_hull)
		elif not Run.scrap_found_hull():
			# Cut up when it carries a SCRAP (the derelict hauler's frame), as a
			# player would; left when it does not.
			Run.found_hull = null


## Sell first, then spend, so salvage can pay for repairs. Never buys stock to resell.
## The Lab first (science); AUGMENT costs credits too, so it waits (`augment`, last).
## Why: docs/why/Policy.md#shopping
func shop(n: MapGen.MapNode) -> void:
	lab(n)
	sell_hold(n)

	var missing := Run.max_hp() - Run.hp
	var repair := Market.repair_price(n, missing)
	if missing > 0 and Run.credits > repair + 25:
		Run.add_credits(-repair)
		Run.heal(missing)
		spend.repair += repair
	# Always top up: `fuel < 8` fired once a run, and 20% of runs ended fuel blocked.
	# Why: docs/why/Policy.md#fuel-policy
	var want := int(float(Run.fuel_cap()) * FUEL_TOPUP)
	if human:
		want = human_fuel_want(n)
	var bought := false
	var guard := 0
	while Run.fuel < want and guard < 40:
		guard += 1
		var offer := Run.refuel_offer(n)
		var refuel := int(offer.cost)
		# No reserve when the tank cannot make the next jump: three strands refused a can (Oct 18).
		# Why: docs/why/Policy.md#fuel-policy
		var reserve := FUEL_RESERVE
		if offer.get("rescue", false) or not _can_make_a_jump(n):
			reserve = 0
		if Run.credits < refuel + reserve:
			break
		var f0 := Run.fuel
		if not Run.buy_refuel(n):
			break
		if offer.get("rescue", false):
			rescues += 1
		spend.fuel += refuel
		fuel_bought += Run.fuel - f0
		bought = true
	if bought:
		refuel_stops += 1
	augment(n)


## Whether the tank holds the cheapest jump on the chart from here.
static func _can_make_a_jump(n: MapGen.MapNode) -> bool:
	for raw in Run.in_range_of(n):
		var t: MapGen.MapNode = raw
		if t.sensed and Run.fuel >= Run.fuel_cost_to(t):
			return true
	return false


## Enough for the way in with half again; with 279 aboard a person never bought fuel.
func human_fuel_want(n: MapGen.MapNode) -> int:
	var rings_left := maxi(1, MapGen.LAYERS - 1 - n.layer)
	var typ := 0.0
	var k := 0
	for t in Run.in_range_of(n):
		var tn: MapGen.MapNode = t
		if tn.sensed and tn.layer >= n.layer:
			typ += float(Run.fuel_cost_to(tn))
			k += 1
	typ = typ / k if k > 0 else 3.0
	var need := int(ceil(typ * float(rings_left) * HUMAN_HOPS_PER_RING * 1.5))
	return mini(need, Run.fuel_cap())

## Hops a person spends per ring on the way in: one down and a look around.
const HUMAN_HOPS_PER_RING := 1.6
## 12 makes a fresh system a near coin against one a ring in, the exploring person.
var HUMAN_LOOK_ROUND := 12.0


## Anything left at a station was already headed to scrap, so take the higher price.
func sell_hold(n: MapGen.MapNode) -> void:
	var guard := 0
	while not Run.cargo.is_empty() and guard < 24:
		guard += 1
		var item: HoldItem = Run.cargo[0]
		# A material is only ever sold: it has no scrap value and nothing to install into.
		var mat := item as MaterialData
		if mat != null:
			Run.take_from_hold(mat)
			Run.add_credits(Market.material_price(n, mat.id))
			n.trades += 1
			continue
		var m := item as ModuleData
		var paid := Market.bid(n, m)
		if paid > Run.scrap_value_of(m):
			Run.take_from_hold(m)
			Run.add_credits(paid)
			n.trades += 1
		else:
			Run.scrap_module(m)


# ------------------------------------------------------------------ science

## THE LAB, at a dock (science, plan S12). The one entry the bot and the sim both
## call, so they stay one pilot: DEVELOP FILM and READ FOR DATA while the board
## still wants DATA, then the board's steps (`research`). Both cost only DATA and
## materials, never credits, so nothing here competes with a repair or the tank.
##
## The bench's old matches (a hull patch, fuel cracking) went with their
## recipes; RELIC ANALYSIS (40 credits for a part) is a build decision this
## pilot has no opinion on, so a relic the board has no use for is sold.
func lab(n: MapGen.MapNode) -> void:
	if not science or not Science.lab_here(n):
		return
	for r in Fabricator.available(n):
		if StringName(r.kind) != &"data":
			continue
		var guard := 0
		while wants_data() and Fabricator.can_make(n, r) and guard < 12:
			guard += 1
			var d0 := Run.data
			if Fabricator.make(n, r).is_empty():
				break
			var key := "data_relic" if StringName(r.id) == &"read" else "data_film"
			sci[key] = int(sci[key]) + Run.data - d0
	research(n)


## Buy the board's steps: the cheapest next step DATA covers, again and again.
## Ties go to the routine's rank (`DB.routines[id].rank`, weakest first), then
## to branch order (FRAME, CORE, DRIVE). Returns the steps bought.
func research(n: MapGen.MapNode) -> int:
	if not science or not Science.lab_here(n):
		return 0
	var bought := 0
	while bought < 9:
		var b := cheapest_step()
		if b < 0 or not Science.can_buy(b):
			break
		if Science.buy(b).is_empty():
			break
		bought += 1
	return bought


## The branch whose next step is cheapest, by the tie rules above, or -1 when
## every branch is finished. Affordability is the caller's question.
static func cheapest_step() -> int:
	var best := -1
	var best_cost := 0
	var best_rank := 0
	for b in DB.BRANCHES.size():
		var id := Run.next_step(b)
		if id == &"":
			continue
		var cost := Run.step_cost(b)
		var rank := int(DB.routines[id].get("rank", 0))
		# (branches are walked in order, so an equal cost and rank keeps the first)
		if best < 0 or cost < best_cost or (cost == best_cost and rank < best_rank):
			best = b
			best_cost = cost
			best_rank = rank
	return best


## The DATA the rest of the board costs.
static func board_left() -> int:
	var left := 0
	for b in DB.BRANCHES.size():
		var owned := clampi(Run.board_owned[b], 0, 3) if b < Run.board_owned.size() else 3
		for k in range(owned, 3):
			if b * 3 + k < Run.board.size():
				left += DB.BOARD_PRICES[k]
	return left


## WHETHER MORE DATA WOULD BUY ANYTHING: the board's steps cost more than the
## DATA held. A reading taken past that point would only be an augment's leftover,
## and its credits line pays now; so a finished board (or one the DATA held
## already covers) sells its readings.
func wants_data() -> bool:
	return science and not Run.science_off and Run.data < board_left()


## Whether the DATA held buys a step of the board now, at any Lab.
func data_covers_step() -> bool:
	if not science or Run.science_off:
		return false
	var b := cheapest_step()
	return b >= 0 and Run.data >= Run.step_cost(b)


## AUGMENT, when no step of the board is affordable: one part a visit. The most
## valuable fitted part not yet augmented (`Market.base_value`), and of the three
## the Lab offers it the first in `AUGMENT_ORDER`. Never Lightened (-1 HUL) under
## 60% hull. Never below FUEL_RESERVE credits, the reserve the tank keeps. Returns
## the line, or "" when nothing was done.
##
## THE PART'S PRICE DOES NOT MOVE (pick 3A): `Science.augment` leaves
## `scrap_value` alone, so this buys strength and never resale.
func augment(n: MapGen.MapNode) -> String:
	if not science or not Science.lab_here(n):
		return ""
	var b := cheapest_step()
	if b >= 0 and Science.can_buy(b):
		return ""
	var cost := Science.augment_cost(n)
	if Run.data < int(cost.data) or Run.credits - int(cost.credits) < FUEL_RESERVE:
		return ""
	var parts: Array[ModuleData] = []
	for raw in Run.installed:
		var m := raw as ModuleData
		if m != null and not m.augmented:
			parts.append(m)
	# Most valuable first; equal values keep the fitted order (a stable sort by
	# hand, since `sort_custom` promises none).
	var order: Array[int] = []
	for i in parts.size():
		var at := order.size()
		for j in order.size():
			if Market.base_value(parts[i]) > Market.base_value(parts[order[j]]):
				at = j
				break
		order.insert(at, i)
	var low := Run.hp < Run.max_hp() * 0.6
	for i in order:
		var m: ModuleData = parts[i]
		if not Science.can_augment(m, n):
			continue
		var pick: AffixData = null
		var rank := AUGMENT_ORDER.size()
		for a in Science.augment_offer(m, n):
			var r := AUGMENT_ORDER.find(StringName(a.name))
			if r < 0 or (low and StringName(a.name) == &"Lightened"):
				continue
			if r < rank:
				rank = r
				pick = a
		if pick == null:
			continue
		var d0 := Run.data
		var c0 := Run.credits
		var line := Science.augment(m, pick, n)
		if line.is_empty():
			continue
		spend.augment += c0 - Run.credits
		sci.augments += 1
		sci.aug_data += d0 - Run.data
		sci.aug_credits += c0 - Run.credits
		sci.affixes[pick.name] = int(sci.affixes.get(pick.name, 0)) + 1
		return line
	return ""

## The order this pilot wants the Lab's affixes in, best first.
const AUGMENT_ORDER: Array[StringName] = [&"Double-Plated", &"Reinforced",
	&"Gyro-Trimmed", &"Signature-Damped", &"Tuned Injectors", &"Wide-Banded",
	&"Bus-Fed", &"Lightened"]


## One science event taken: which line, the DATA it paid and the fuel it burned.
func _count_reading(line: Dictionary, data: int, fuel: int) -> void:
	sci.met += 1
	if not bool(line.get("burns", false)):
		sci.credits += 1
		return
	sci.fuel += maxi(0, fuel)
	if line.has("check"):
		sci.risky += 1
		sci.data_risky += maxi(0, data)
	else:
		sci.careful += 1
		sci.data_careful += maxi(0, data)


## A SCIENCE EVENT'S LINE (plan S12). Three lines: careful (`burns`, no check),
## risky (`burns` and a check), and the buyer's credits (no `burns`).
##
## Credits when this pilot has science off, when the board wants no more DATA
## (`wants_data`), or when the fuel gate is shut (`OptionResolve.fuel_ok`, the
## same gate the card greys: a reading never takes the tank under the way out).
## Otherwise risky while the hull is above half (and, for the cautious pilot,
## only at odds of RISK_FLOOR or better), else careful. Draws from no stream.
func _choose_science(opt: Dictionary) -> int:
	var choices: Array = opt.get("choices", [])
	var careful := -1
	var risky := -1
	var credits := -1
	for i in choices.size():
		var c: Dictionary = choices[i]
		if bool(c.get("burns", false)):
			if c.has("check"):
				if risky < 0:
					risky = i
			elif careful < 0:
				careful = i
		elif credits < 0 and OptionResolve.affordable(c):
			credits = i
	if not wants_data():
		return credits
	var any := careful if careful >= 0 else risky
	if any < 0:
		return credits
	if not OptionResolve.affordable(choices[any]):
		sci.refused += 1
		return credits
	if risky >= 0 and Run.hp > Run.max_hp() * 0.5 and OptionResolve.affordable(choices[risky]):
		if not risk_averse or SkillCheck.odds(choices[risky].check) >= RISK_FLOOR:
			return risky
		checks_avoided += 1
	if careful >= 0:
		return careful
	return credits


## Farm only while the tank allows, then descend: the old coin wandered 117 jumps, a model artifact.
## Why: docs/why/Policy.md#jump-policy
func engage_hellbender() -> bool:
	var mine := float(Run.hp) / float(maxi(1, Run.max_hp()))
	var its := float(Run.hellbender_hp) / float(maxi(1, Run.hellbender_max))
	return mine >= 0.45 + its * 0.3

## A second policy (`ENCOUNTER_REBUILD.md` §8): the risk-averse one refuses below `RISK_FLOOR`.
## Why: docs/why/Policy.md#risk-policy
var risk_averse: bool = false

## `declined` measured nothing, as cautious pilots take the unchecked fallback instead.
## Why: docs/why/Policy.md#risk-policy
var checks_avoided := 0

## 0.45 sits between one pip short and two; a starting point, not a ruling.
## Why: docs/why/Policy.md#risk-policy
const RISK_FLOOR := 0.45

## Injected because a policy owns no Combat; unset, fights are counted, not run.
## Why: docs/why/Policy.md#option-taking
var fight_cb: Callable = Callable()


## Groups are the point: taking one forecloses its siblings, and `forgone` counts that.
## Why: docs/why/Policy.md#option-taking
func take_options(n: MapGen.MapNode) -> Dictionary:
	var out := {"taken": 0, "declined": 0, "forgone": 0, "fights": 0}
	# `-- sim dash`: the beeline pilot that opens nothing on the way in.
	if dash:
		return out
	if n == null or not OptionTable.ensure(n):
		return out
	var spent: Dictionary = {}
	for i in n.options.size():
		var opt := OptionTable.by_id(n.options[i])
		if opt.is_empty():
			continue
		var oid := MapGen.OPTION_SITE + i
		# Test this visit's group before the node's claims, or `forgone` reads zero forever.
		var g := StringName(opt.get("group", &""))
		if g != &"" and spent.has(g):
			# Not declined -- FORGONE. The pilot never got to weigh it, because
			# something else in its group was taken first.
			out.forgone += 1
			continue
		if n.taken.has(oid):
			continue
		var pick := _choose_line(opt)
		if pick < 0:
			out.declined += 1
			continue
		var line: Dictionary = (opt.choices as Array)[pick]
		if line.has("cost_credits"):
			spend.options += int(line.cost_credits)
		var d0 := Run.data
		var f0 := Run.fuel
		var res := _resolve_line(n, line, n.options[i])
		if OptionTable.is_science(opt):
			_count_reading(line, Run.data - d0, f0 - Run.fuel)
		n.taken.append(oid)
		# Write the decision down as the game does, so a finished node stops offering forgone ones.
		OptionTable.foreclose(n, i)
		out.taken += 1
		if g != &"":
			spent[g] = true
		if Run.dead:
			break
		# Run the fight an outcome opens: fights exist only as outcomes, so skipping hid combat.
		# Why: docs/why/Policy.md#option-taking
		if bool(res.get("fight", false)):
			out.fights += 1
			# What it brings is the event's tag, as on the screen: the
			# creature its text set up, or a ship (`OptionTable.fight_foe`).
			if fight_cb.is_valid() and not fight_cb.call(n, OptionTable.fight_foe(opt, line)):
				break
	return out


## Prefer a check the pilot will pass; falling back to the flat line is the policy split.
## A science event goes to `_choose_science` first.
## Why: docs/why/Policy.md#option-taking
func _choose_line(opt: Dictionary) -> int:
	if OptionTable.is_science(opt):
		return _choose_science(opt)
	var choices: Array = opt.get("choices", [])
	var fallback := -1
	for i in choices.size():
		var c: Dictionary = choices[i]
		if c.has("cost_credits") and Run.credits < int(c.cost_credits):
			continue
		# The same gate the screen greys. A policy that took a line the player
		# cannot reach would price a trade nobody can make.
		if c.has("needs_material") \
				and Run.material(StringName(c.needs_material)) < 1:
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


## Reward class from §5: a `module` option pays one rolled at the system's own danger.
func _resolve_line(n: MapGen.MapNode, line: Dictionary, src: StringName = &"") -> Dictionary:
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
	OptionTable.pay(res, n, src)
	# Handed back rather than consumed here, because `fight` is the caller's
	# business: this function grants rewards, it does not start battles.
	return res


func choose_jump(node: MapGen.MapNode) -> int:
	# Route by `in_range()`, not `links`: links is the drawn graph; 46% of stuck ships could fly.
	# Why: docs/why/Policy.md#jump-policy
	limited = false
	if beeline:
		return _beeline_jump(node)
	if human:
		return _human_jump(node)
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
			# `lateral` is a place worth stopping; `sideways` is anywhere in this ring.
			sideways.append(idx)
			if not t.cleared:
				lateral.append(idx)
		elif t.layer > node.layer:
			forward.append(idx)
	var healthy := Run.hp > Run.max_hp() * 0.6
	# Scaled to the tank, not a flat 45, which meant spare fuel at 150 but is always true at 279.
	var tank := float(Run.start_fuel())
	var can_wander := float(Run.fuel) > tank * 0.3
	# The ring needs something left; forbidding descent when hurt made damaged ships circle.
	var spent: int = int(_farmed.get(node.layer, 0))
	var want_lateral := pilot.randf() < (0.65 if healthy else 0.85)
	if not lateral.is_empty() and can_wander and want_lateral \
			and spent < FARM_LIMIT:
		_farmed[node.layer] = spent + 1
		return Rng.pick(pilot, lateral)
	if not forward.is_empty():
		return Rng.pick(pilot, forward)

	# Walk the ring to find a way down: the old random link walk made 70 jumps at danger 1.8.
	# Why: docs/why/Policy.md#jump-policy
	if not sideways.is_empty():
		# In range, not linked, for the same reason; the costly pass now almost never runs.
		# Why: docs/why/Policy.md#jump-policy
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


## Beeline flies the deepest star it can afford, as Kevin reached the core in seven jumps.
## Why: docs/why/Policy.md#beeline-pilot
var beeline: bool = false
var dash: bool = false

func _beeline_jump(node: MapGen.MapNode) -> int:
	var best := -1
	var best_k := -INF
	var dock := -1
	var dock_k := -INF
	for raw in Run.in_range_of(node):
		var t: MapGen.MapNode = raw
		if not Run.can_jump_to(t):
			continue
		var depth := 100.0 if t.type == MapGen.NodeType.CORE else float(t.layer)
		var k := depth * 10.0 - float(Run.fuel_cost_to(t)) + pilot.randf() * 0.5
		if k > best_k:
			best_k = k
			best = t.index
		if t.type == MapGen.NodeType.STATION and t.index != node.index and k > dock_k:
			dock_k = k
			dock = t.index
	if best >= 0 and (Run.map[best] as MapGen.MapNode).type == MapGen.NodeType.CORE:
		return best
	if Run.fuel_low() and node.type != MapGen.NodeType.STATION and dock >= 0:
		return dock
	return best


## Score every reachable star and fly the best affordable; otherwise it is fuel limited.
func _human_jump(node: MapGen.MapNode) -> int:
	var best := -1
	var best_s := -INF
	var best_ok := -1
	var best_ok_s := -INF
	for raw in Run.in_range_of(node):
		var t: MapGen.MapNode = raw
		if not t.sensed:
			continue
		var s := human_score(node, t)
		if s > best_s:
			best_s = s
			best = t.index
		if Run.fuel >= Run.fuel_cost_to(t) and s > best_ok_s:
			best_ok_s = s
			best_ok = t.index
	if best_ok < 0:
		return -1
	limited = best != best_ok
	var tn: MapGen.MapNode = Run.map[best_ok]
	if tn.layer == node.layer and not tn.cleared:
		_farmed[node.layer] = int(_farmed.get(node.layer, 0)) + 1
	return best_ok


## Depth first, then somewhere new, a dock when hurt; the noise comes from the pilot's own stream.
func human_score(here: MapGen.MapNode, t: MapGen.MapNode) -> float:
	if t.type == MapGen.NodeType.CORE:
		return 1000.0
	var s := 0.0
	var dl := t.layer - here.layer
	# The first ring in is the point; more than one at a hop is worth a little,
	# because each ring in is a step up in danger a person feels.
	if dl > 0:
		s += 10.0 - 1.0 * float(maxi(0, t.danger - here.danger))
	elif dl < 0:
		s -= 15.0 * float(-dl)
	if t.visited:
		s -= 8.0
	elif not t.cleared:
		s += 6.0
	var healthy := Run.hp > Run.max_hp() * 0.6
	# A look round the ring while it is worth it: three hops, as the farmer.
	if dl == 0 and not t.visited and healthy 			and int(_farmed.get(here.layer, 0)) < FARM_LIMIT:
		s += HUMAN_LOOK_ROUND
	if t.type == MapGen.NodeType.STATION:
		var low := Run.fuel < human_fuel_want(here) / 2
		s += 14.0 if (not healthy or low) else 3.0
		# A LAB WITH DATA TO SPEND (science, open call 19): a person holding the
		# DATA for the board's next step steers for a dock. The human pilot
		# only; the gate's farmer stays put.
		if data_covers_step():
			s += 6.0
	if t.type == MapGen.NodeType.PULSAR and not t.cleared and healthy:
		s += 4.0
	if not healthy:
		s -= 0.8 * float(t.danger)
	s -= 0.6 * float(Run.fuel_cost_to(t))
	return s + pilot.randf() * 6.0
