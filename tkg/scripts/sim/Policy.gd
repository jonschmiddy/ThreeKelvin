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

## The pilot's own generator. One per run, seeded from the run's master seed, so
## the model's choices replay with the run and drawing them does not move what
## the world rolls next.
##
## Assigned by the caller — `Rng.derive(&"pilot", 0)` — rather than seeded here,
## because a bot in a party must NOT share it with the sim's convention. See
## `BotPilot._brain_up()`.
var pilot: RandomNumberGenerator = RandomNumberGenerator.new()

## What the model is willing to haul. A BEHAVIOUR, not a capacity — hulls hold
## 8 / 12 / 16. A competent player does not carry twenty parts hoping for a
## buyer; they keep the few worth a detour and scrap the rest where they stand.
## It must stay at or under the smallest hull's capacity or the model would be
## measuring a hold no ship in the game has.
const HOLD_LIMIT := 4


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
	if c.vent > 0 and Run.heat > Run.heat_cap() * (1.15 if hot else 0.7):
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
	var refuel := Market.refuel_price(n)
	if Run.fuel < 8 and Run.credits >= refuel:
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
func choose_jump(node: MapGen.MapNode) -> int:
	var options: Array[int] = []
	for idx in node.links:
		if Run.can_jump_to(Run.map[idx]):
			options.append(idx)
	if options.is_empty():
		return -1
	var lateral: Array[int] = []
	var forward: Array[int] = []
	for idx in options:
		var t: MapGen.MapNode = Run.map[idx]
		if t.layer == node.layer and not t.cleared:
			lateral.append(idx)
		elif t.layer > node.layer:
			forward.append(idx)
	var healthy := Run.hp > Run.max_hp() * 0.6
	var can_wander := Run.fuel > 45
	if not lateral.is_empty() and can_wander and (not healthy or pilot.randf() < 0.65):
		return Rng.pick(pilot, lateral)
	if not forward.is_empty():
		return Rng.pick(pilot, forward)
	return Rng.pick(pilot, options)
