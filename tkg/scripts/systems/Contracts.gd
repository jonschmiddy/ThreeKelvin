class_name Contracts
extends RefCounted

## What a station's house wants doing, and what it pays.
##
## POSITIONAL, like the shelf and the wreck. What is on a station's board is
## drawn from `Rng.derive(&"work", node.index)`, so it is a property of the place
## rather than of who walked in — four ships docking in four different orders see
## one board, and it is the same board on the second visit as on the first.
##
## NOT CONTESTED, unlike the shelf. Two ships can both take the same contract and
## both deliver it. A shelf holds one Legendary and a job holds as many hands as
## want it; the thing being paid for is the flying, and both of them flew. This
## is the same reasoning that makes the archive uncontested — see
## `netcode.md` "One kill, one bag" for the shape it is deliberately NOT.
##
## Nothing here expires. See ContractData's header for why that is a rule rather
## than an omission.

## How many offers a board carries. Two is enough to be a choice and few enough
## that declining both is a normal evening.
const OFFERS := 2

## Pay, per unit of the thing being priced. All three kinds are priced against
## the TRIP rather than against the difficulty, because the trip is the cost the
## player is actually being asked to bear — `docs/design-doc.md`'s greed clock is
## a fuel budget with a danger gradient stapled to it.
const PAY_BASE := 26
const PAY_PER_LAYER := 9
const PAY_PER_DANGER := 4
## A hunt is a fight you were going to have to win anyway, plus the flying.
const HUNT_BONUS := 1.25
## Heat pays best of the three and is never explained. See `docs/lore.md` §1.
const HEAT_PER_UNIT := 11

## How much heat a berth will ask for. Small, because `RunState.cool_in_transit()`
## sheds half a jump's worth every time you move: arriving anywhere with heat on
## the hull means having chosen not to cool down, and that choice is the whole
## mechanic. Anything larger than this is not a contract, it is a demand that you
## fly hot for six jumps, which is the ambush layer being weaponised against the
## player rather than offered to them.
const HEAT_MIN := 4
const HEAT_MAX := 9


## What this station is offering, or empty for a station with no house behind it.
##
## Idempotent and derived — nothing is stored on the node. A board that was
## generated once and saved would be a board that could drift from the seed, and
## there is nothing here a seed cannot say.
static func board(n: MapGen.MapNode) -> Array:
	var out: Array = []
	if n == null or n.type != MapGen.NodeType.STATION:
		return out
	var houses := _houses(n)
	if houses.is_empty():
		return out
	var r := Rng.derive(&"work", n.index)
	# Both offers are rolled against the same map, so the two candidate pools are
	# built once here and handed down rather than rebuilt inside each `_target`.
	# `board()` is called on every station refresh and the scan is the whole map.
	var pools: Dictionary = {}
	for i in OFFERS:
		var c := _roll(n, houses[i % houses.size()], r, pools)
		if c != null:
			out.append(c)
	return out


## Every house with a berth here. `manufacturer` is the dominant one and `makers`
## is everyone present, so a contested station posts two different houses' work
## side by side — which is the trade map the chart already draws, saying
## something about itself.
static func _houses(n: MapGen.MapNode) -> Array:
	var out: Array = []
	if n.manufacturer != &"" and DB.manufacturers.has(n.manufacturer):
		out.append(n.manufacturer)
	for m in n.makers:
		if m != &"" and m != n.manufacturer and DB.manufacturers.has(m):
			out.append(m)
	return out


static func _roll(n: MapGen.MapNode, house: StringName,
		r: RandomNumberGenerator, pools: Dictionary) -> ContractData:
	var c := ContractData.new()
	c.house = house
	c.posted_at = n.index
	var roll := r.randf()
	if roll < 0.45:
		c.kind = ContractData.Kind.FETCH
	elif roll < 0.78:
		c.kind = ContractData.Kind.HUNT
	else:
		c.kind = ContractData.Kind.HEAT

	match c.kind:
		ContractData.Kind.HEAT:
			c.amount = r.randi_range(HEAT_MIN, HEAT_MAX)
			c.pay = c.amount * HEAT_PER_UNIT
			c.standing = 1
			c.text = _voice(house, c.kind, "", c.amount, r)
		ContractData.Kind.HUNT:
			var target := _target(n, r, true, pools)
			if target < 0:
				return null
			c.at = target
			c.pay = int(round(_trip_pay(n, Run.map[target]) * HUNT_BONUS))
			c.standing = 1
			c.text = _voice(house, c.kind, MapGen.star_name(Run.map[target]), 0, r)
		_:
			var target2 := _target(n, r, false, pools)
			if target2 < 0:
				return null
			c.at = target2
			c.item = _item(house, r)
			c.pay = _trip_pay(n, Run.map[target2])
			# The deep ones are worth more standing as well as more money. This is
			# the only place standing scales, and it scales on DEPTH rather than on
			# how many you have done, so a house's regard is bought by flying
			# somewhere unpleasant rather than by grinding the rim.
			c.standing = 2 if Run.map[target2].layer >= 5 else 1
			c.text = _voice(house, c.kind, MapGen.star_name(Run.map[target2]), 0, r)
	return c


## Somewhere to send them. Never this system, never the core, and never a place
## the map cannot name.
##
## Biased OUTWARD-ish rather than always deeper: a board that only ever points
## coreward is a board that is spending the player's fuel on the house's behalf,
## which is the "somebody else's schedule" §6 was worried about. About a third of
## the work sits shallower than the station posting it.
static func _target(n: MapGen.MapNode, r: RandomNumberGenerator,
		want_fight: bool, pools: Dictionary) -> int:
	if Run.map.is_empty():
		return -1
	if pools.has(want_fight):
		var cached: Array = pools[want_fight]
		if cached.is_empty():
			return -1
		return int(cached[r.randi() % cached.size()])
	var pool: Array = []
	for other in Run.map:
		var o: MapGen.MapNode = other
		if o.index == n.index or o.type == MapGen.NodeType.GOAL:
			continue
		if o.type == MapGen.NodeType.START:
			continue
		if want_fight and o.type != MapGen.NodeType.FIGHT:
			continue
		var reach := absi(o.layer - n.layer)
		if reach > 3:
			continue
		pool.append(o.index)
	pools[want_fight] = pool
	if pool.is_empty():
		return -1
	return int(pool[r.randi() % pool.size()])


static func _trip_pay(from: MapGen.MapNode, to: MapGen.MapNode) -> int:
	var hops := absi(to.layer - from.layer) + 1
	return PAY_BASE + hops * PAY_PER_LAYER + MapGen.tier(to.danger) * PAY_PER_DANGER


## What got left out there. A NAME AND NOTHING ELSE — see recover().
static func _item(house: StringName, r: RandomNumberGenerator) -> String:
	var pool: Array = []
	for id in DB.modules:
		var m: ModuleData = DB.modules[id]
		if m.manufacturer == house and not m.starter_only:
			pool.append(m.name)
	if pool.is_empty():
		return "a crate with no markings on it"
	return String(pool[r.randi() % pool.size()])


# --- the seven, asking for things ------------------------------------------

## The ask, in the house's own register.
##
## Every one of these is a person at a desk with a job, in the same voice the
## archive is written in — see `docs/lore.md` §5. Nobody explains anything,
## nobody is grateful, and nobody says what the heat is for.
static func _voice(house: StringName, kind: ContractData.Kind, place: String,
		amount: int, r: RandomNumberGenerator) -> String:
	var lines: Array = _LINES.get(house, {}).get(kind, [])
	if lines.is_empty():
		lines = _LINES[&"korvan"][kind]
	var s := String(lines[r.randi() % lines.size()])
	return s.replace("{PLACE}", place).replace("{N}", str(amount))

const _LINES := {
	&"korvan": {
		ContractData.Kind.FETCH: [
			"A crew ran the tank dry at {PLACE} and left a mount on the rock rather than the fuel to move it. It is Korvan. Bring it back.",
			"Inventory says a part is at {PLACE}. Inventory has said so for some time. Go and make inventory correct.",
		],
		ContractData.Kind.HUNT: [
			"Something at {PLACE} is shooting at our haulers. It has been asked to stop.",
			"There is a contact at {PLACE}. Remove it. There is no second part to this.",
		],
		ContractData.Kind.HEAT: [
			"Standing order. Dock at any of our berths carrying {N} heat and we will take it off you at the posted rate.",
		],
	},
	&"solari": {
		ContractData.Kind.FETCH: [
			"There is a Foundry part sitting cold at {PLACE}. That offends me personally. Fetch it.",
			"Somebody abandoned good hardware at {PLACE} because they were afraid of it. Go and be less afraid.",
		],
		ContractData.Kind.HUNT: [
			"The thing at {PLACE} runs cold and thinks that makes it clever. Correct it.",
			"Contact at {PLACE}. Aim something at it. Heat is only waste if you fail to aim it.",
		],
		ContractData.Kind.HEAT: [
			"Come in hot. {N} on the hull, any Foundry berth, and do not vent on the approach like a coward.",
		],
	},
	&"dredge": {
		ContractData.Kind.FETCH: [
			"Filing says the contents of {PLACE} are ours. The contents disagree by being at {PLACE}. Retrieve.",
			"Item at {PLACE}. Combine holds the claim. Recovery is billable at the rate below.",
		],
		ContractData.Kind.HUNT: [
			"A hostile at {PLACE} is sitting on a claim we filed first. Clear the claim.",
			"Contact at {PLACE}. It becomes salvage when it stops moving. Make it salvage.",
		],
		ContractData.Kind.HEAT: [
			"Thermal, {N} units, delivered to any Combine berth. Weighed on arrival. Paid on the weight.",
		],
	},
	&"redline": {
		ContractData.Kind.FETCH: [
			"Package at {PLACE}. Don't open it, don't scan it, don't ask. Bring it here.",
			"Left something at {PLACE} in a hurry. Would rather it came back. Would rather not say why.",
		],
		ContractData.Kind.HUNT: [
			"Someone at {PLACE} knows a name they shouldn't. They'll stop knowing it if you're quick.",
			"Contact at {PLACE}. No serials on it. There won't be any afterwards either.",
		],
		ContractData.Kind.HEAT: [
			"{N} on the hull, any of our doors, cash, no receipt. We pay over the posted rate. Don't tell anyone we do.",
		],
	},
	&"halcyon": {
		ContractData.Kind.FETCH: [
			"A commission of ours is at {PLACE}, unattended. The Company maintains what it sold. Recover it and we will resume doing so.",
			"An owner failed to return from {PLACE}. The obligation did not lapse. The hardware is still there.",
		],
		ContractData.Kind.HUNT: [
			"There is something at {PLACE} interfering with a client. It is to be discouraged, thoroughly and once.",
		],
		ContractData.Kind.HEAT: [
			"We will accept {N} units of banked thermal at any atelier. The rate is not negotiable and has never needed to be.",
		],
	},
	&"cygnet": {
		ContractData.Kind.FETCH: [
			"A unit at {PLACE} has stopped reporting. Retrieve the housing. The literature does not require you to look inside it.",
			"There is hardware at {PLACE}. It is expected. Bring it in.",
		],
		ContractData.Kind.HUNT: [
			"The contact at {PLACE} is destroying units faster than they return. Resolve it.",
		],
		ContractData.Kind.HEAT: [
			"Deliver {N}. Any berth. No party will be present and none is required to be.",
		],
	},
	&"calyx": {
		ContractData.Kind.FETCH: [
			"A specimen was left at {PLACE} without supervision. It is still under warranty. Collect it carefully.",
			"There is cultured hardware at {PLACE}, unfed, for some time now. Retrieve it. Do not feed it.",
		],
		ContractData.Kind.HUNT: [
			"Something at {PLACE} is eating our specimens. Every contract has a clause about that.",
		],
		ContractData.Kind.HEAT: [
			"{N} units of thermal, any Calyx berth. The cultures take it better than the vaults do.",
		],
	},
}
