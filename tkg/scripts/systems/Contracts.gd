class_name Contracts
extends RefCounted

## Boards are positional and derived, not contested: two ships can take and deliver one job.
## Why: docs/why/Contracts.md#board

## How many offers a board carries. Two is enough to be a choice and few enough
## that declining both is a normal evening.
const OFFERS := 2

## Pay is priced against the trip, not the difficulty, as the trip is the cost the player bears.
const PAY_BASE := 26
const PAY_PER_LAYER := 9
const PAY_PER_DANGER := 4
## A hunt is a fight you were going to have to win anyway, plus the flying.
const HUNT_BONUS := 1.25
## Heat pays best of the three and is never explained. See `docs/lore.md` §1.
const HEAT_PER_UNIT := 11

## Heat asks stay small: arriving hot already means choosing not to cool, so more is a demand.
## Why: docs/why/Contracts.md#heat-asks
const HEAT_MIN := 4
const HEAT_MAX := 9


## Every station posts work (Jon, Nov 3); derived from the seed, never stored, so it cannot drift.
## Why: docs/why/Contracts.md#board
static func board(n: MapGen.MapNode) -> Array:
	var out: Array = []
	if n == null or n.type != MapGen.NodeType.STATION:
		return out
	var manufacturers := _manufacturers(n)
	if manufacturers.is_empty():
		return out
	var r := Rng.derive(&"work", n.index)
	# The candidate pool is built once and handed down, as `board()` runs on every station refresh.
	var pools: Dictionary = {}
	for i in OFFERS:
		var c := _roll(n, manufacturers[i % manufacturers.size()], r, pools)
		if c != null:
			out.append(c)
	return out


## A contested station posts two manufacturers' work side by side, as the trade map does.
static func _manufacturers(n: MapGen.MapNode) -> Array:
	var out: Array = []
	if n.manufacturer != &"" and DB.manufacturers.has(n.manufacturer):
		out.append(n.manufacturer)
	for m in n.berths:
		if m != &"" and m != n.manufacturer and DB.manufacturers.has(m):
			out.append(m)
	if out.is_empty() and dock_desk(n) != &"":
		out.append(dock_desk(n))
	return out


## A station with no berth posts work through a derived dock desk (Jon, Nov 3), never stored.
## Why: docs/why/Contracts.md#dock-desk
static func dock_desk(n: MapGen.MapNode) -> StringName:
	if n == null or n.type != MapGen.NodeType.STATION:
		return &""
	if n.manufacturer != &"" or not n.berths.is_empty():
		return &""
	return dock_desk_from(n.index, DB.manufacturers)


## Sort desks by text via `NetSession.sorted_ids`: StringName `keys().sort()` sorts by address.
## Why: docs/why/Contracts.md#dock-desk
static func dock_desk_from(index: int, table: Dictionary) -> StringName:
	var keys := NetSession.sorted_ids(table)
	if keys.is_empty():
		return &""
	return StringName(keys[Rng.derive(&"dock_desk", index).randi() % keys.size()])


static func _roll(n: MapGen.MapNode, manufacturer: StringName,
		r: RandomNumberGenerator, pools: Dictionary) -> ContractData:
	var c := ContractData.new()
	c.manufacturer = manufacturer
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
			c.text = _voice(manufacturer, c.kind, "", c.amount, r)
		ContractData.Kind.HUNT:
			var target := _target(n, r, pools)
			if target < 0:
				return null
			c.at = target
			c.pay = int(round(_trip_pay(n, Run.map[target]) * HUNT_BONUS))
			c.standing = 1
			c.text = _voice(manufacturer, c.kind, MapGen.star_name(Run.map[target]), 0, r)
		_:
			var target2 := _target(n, r, pools)
			if target2 < 0:
				return null
			c.at = target2
			c.item = _item(manufacturer, r)
			c.pay = _trip_pay(n, Run.map[target2])
			# Standing scales on depth, not grinding: regard comes from unpleasant places.
			c.standing = 2 if Run.map[target2].layer >= 5 else 1
			c.text = _voice(manufacturer, c.kind, MapGen.star_name(Run.map[target2]), 0, r)
	return c


## Targets are ordinary systems only, as the work becomes an event there; partly biased outward.
## Why: docs/why/Contracts.md#job-targets
static func _target(n: MapGen.MapNode, r: RandomNumberGenerator,
		pools: Dictionary) -> int:
	if Run.map.is_empty():
		return -1
	if pools.has(&"to"):
		var cached: Array = pools[&"to"]
		if cached.is_empty():
			return -1
		return int(cached[r.randi() % cached.size()])
	var pool: Array = []
	for other in Run.map:
		var o: MapGen.MapNode = other
		if o.index == n.index or not holds_goal(o):
			continue
		var reach := absi(o.layer - n.layer)
		if reach > 3:
			continue
		pool.append(o.index)
	pools[&"to"] = pool
	if pool.is_empty():
		return -1
	return int(pool[r.randi() % pool.size()])


## Whether a contract's work can be put on this system's map.
static func holds_goal(n: MapGen.MapNode) -> bool:
	return n != null and n.type == MapGen.NodeType.SYSTEM \
		and not Router.no_fights_at(n)


# --- the work, out there -----------------------------------------------------

## The event each kind of work is, on the target's map (`OptionTable`).
const GOAL := {
	ContractData.Kind.FETCH: &"job_pickup",
	ContractData.Kind.HUNT: &"job_target",
}


## The work is put on the named system's map, idempotently at signing and arrival, per ship.
## Why: docs/why/Contracts.md#posting-the-goal
static func post_goal(job: ContractData) -> void:
	if job == null or job.state != ContractData.State.TAKEN or not GOAL.has(job.kind):
		return
	if job.at < 0 or job.at >= Run.map.size():
		return
	var n: MapGen.MapNode = Run.map[job.at]
	if not holds_goal(n):
		return
	var id: StringName = GOAL[job.kind]
	OptionTable.ensure(n)
	for i in n.options.size():
		if n.options[i] == id and not n.taken.has(MapGen.OPTION_SITE + i):
			_reopen(n)
			return
	# No `map_changed`: the station rebuilds on it, and the chart mark rides `contracts_changed`.
	n.options.append(id)
	_reopen(n)


## Who is paying for the open job of this kind where the ship is, as the
## short name a yard goes by ("Korvan"), for the event's own words.
static func payer_here(kind: ContractData.Kind) -> String:
	for c in Run.contracts:
		var job: ContractData = c
		if job.kind == kind and job.state == ContractData.State.TAKEN and job.at == Run.at:
			return DB.short_name(DB.manufacturer_name(job.manufacturer))
	return "of their"


## Every open job pointing at this system, posted.
static func post_goals_at(n: MapGen.MapNode) -> void:
	if n == null:
		return
	for c in Run.contracts:
		var job: ContractData = c
		if job.at == n.index:
			post_goal(job)


## A cleared system is reopened for the job only, as a cleared node refuses every event.
static func _reopen(n: MapGen.MapNode) -> void:
	if not n.cleared:
		return
	for i in n.options.size():
		var site := MapGen.OPTION_SITE + i
		if OptionTable.is_job(n.options[i]) or n.taken.has(site):
			continue
		n.taken.append(site)
		n.results[i] = MapGen.R_GONE
	n.cleared = false


static func _trip_pay(from: MapGen.MapNode, to: MapGen.MapNode) -> int:
	var hops := absi(to.layer - from.layer) + 1
	return PAY_BASE + hops * PAY_PER_LAYER + MapGen.tier(to.danger) * PAY_PER_DANGER


## A fetch names only parts this run can find, or it would name a part the player cannot meet.
## Why: docs/why/Contracts.md#fetch-items
static func _item(manufacturer: StringName, r: RandomNumberGenerator) -> String:
	var pool: Array = []
	if not LootGen.can_appear(manufacturer):
		return "a crate with no markings on it"
	for id in DB.modules:
		var m: ModuleData = DB.modules[id]
		if m.manufacturer == manufacturer and not m.starter_only:
			pool.append(m.name)
	if pool.is_empty():
		return "a crate with no markings on it"
	return String(pool[r.randi() % pool.size()])


# --- the seven, asking for things ------------------------------------------

## Voiced as a person at a desk (`docs/lore.md` 5): nobody explains or is grateful.
static func _voice(manufacturer: StringName, kind: ContractData.Kind, place: String,
		amount: int, r: RandomNumberGenerator) -> String:
	var lines: Array = _LINES.get(manufacturer, {}).get(kind, [])
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
			"Standing order. Dock at any of our yards carrying {N} heat and we will take it off you at the posted rate.",
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
			"Come in hot. {N} on the hull, any Foundry yard, and do not vent on the approach like a coward.",
		],
	},
	&"probate": {
		ContractData.Kind.FETCH: [
			"Filing says the contents of {PLACE} are ours. The contents disagree by being at {PLACE}. Retrieve.",
			"Item at {PLACE}. Combine holds the claim. Recovery is billable at the rate below.",
		],
		ContractData.Kind.HUNT: [
			"A hostile at {PLACE} is sitting on a claim we filed first. Clear the claim.",
			"Contact at {PLACE}. It becomes salvage when it stops moving. Make it salvage.",
		],
		ContractData.Kind.HEAT: [
			"Thermal, {N} units, delivered to any Combine yard. Weighed on arrival. Paid on the weight.",
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
	&"verity": {
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
			"Deliver {N}. Any yard. No party will be present and none is required to be.",
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
			"{N} units of thermal, any Calyx yard. The cultures take it better than the vaults do.",
		],
	},
}
