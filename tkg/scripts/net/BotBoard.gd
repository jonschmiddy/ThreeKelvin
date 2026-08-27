class_name BotBoard
extends RefCounted

## What the bot can see, in words rather than in pointers.
##
## This is the whole API surface of the ninth seat. Everything on the far end of
## the mailbox — a model, a script, a person with a text editor — knows the game
## only through what this file chooses to say, so the shape here is the shape of
## what a remote brain is able to think about.
##
## Two rules held it to this size:
##
## LEGAL MOVES ARE LISTED, NOT INFERRED. Every board carries a `moves` array of
## strings that are actually playable right now — the cards with the energy for
## them, the systems in fuel range, the shelf slots nobody has bought. A brain
## that has to work out legality from raw state gets it wrong, and gets it wrong
## in the direction of trying illegal moves, which is a stall. Handing it the
## list makes the wrong answer impossible to spell.
##
## IT DESCRIBES, IT DOES NOT ADVISE. There is no "recommended" field and no
## score. `Policy` already holds an opinion and it is one keystroke away when
## the brain wants it (`pass` takes it); mixing the two would produce a bot that
## is really the autopilot with a model rubber-stamping it, which is not the
## thing that sounded fun.
##
## Everything here is JSON-safe: dictionaries, arrays, ints, floats, strings,
## bools. No StringName, no objects. `JSON.stringify` silently renders an object
## as a pointer, so a leaked EnemyState reaches the far end as `<Object#-92233>`
## and reads as data right up until somebody tries to use it.

const SCHEMA := 1


## Everything a brain sees, whatever it is being asked about.
static func of(kind: String, seq: int) -> Dictionary:
	return {
		"schema": SCHEMA,
		"seq": seq,
		"kind": kind,
		"me": _me(),
		"party": _party(),
	}


## Who this ship is and how it is doing. The numbers a player reads off the HUD
## without thinking about it, which is exactly the set a brain has no other way
## to get.
static func _me() -> Dictionary:
	if Run.hull == null:
		return {}
	return {
		"name": Net.name_of(Net.local_id()) if Net.is_networked() else "Autopilot",
		"peer": Net.local_id(),
		"hull": Run.hull.display_name(),
		"hp": Run.hp,
		"max_hp": Run.max_hp(),
		"heat": Run.heat,
		"heat_cap": Run.heat_cap(),
		"fuel": Run.fuel,
		"credits": Run.credits,
		"kills": Run.kills,
		"jumps": Run.jumps,
		# The heat you are radiating, which is what decides whether something
		# follows you in. A brain that cannot see this cannot understand why it
		# keeps getting ambushed.
		"signature": snappedf(Run.signature(), 0.01),
		"hold": _modules(Run.cargo),
		"installed": _modules(Run.installed),
	}


## The other ships, and — the part that matters — WHERE they are. A party member
## in the same system is somebody you can fight alongside; one four systems away
## is a name on a list.
static func _party() -> Array:
	var out: Array = []
	if not Net.is_networked():
		return out
	for s in Net.partners():
		var at := int(s.get("at", -1))
		out.append({
			"name": String(s.get("name", "?")),
			"peer": int(s.get("id", 0)),
			"at": at,
			"here": at == Run.at,
			"system": MapGen.star_name(Run.map[at]) if at >= 0 and at < Run.map.size() else "",
		})
	return out


## A fight. The board a brain spends most of its time looking at.
static func fight(cb: Combat, seq: int) -> Dictionary:
	var d := of("fight", seq)
	d["turn"] = cb.turn
	d["energy"] = cb.energy
	d["block"] = cb.block
	d["brace"] = cb.brace
	d["lock_on"] = cb.lock_on
	d["shared"] = cb.is_shared()
	d["enemies"] = []
	for i in cb.enemies.size():
		var e: Combat.EnemyState = cb.enemies[i]
		d["enemies"].append({
			"index": i,
			"name": e.template.name,
			"hp": e.hp,
			"max_hp": e.max_hp,
			"block": e.block,
			"brace": e.brace,
			"alive": e.hp > 0,
			# What it has telegraphed for the end of the turn. This is the
			# single most decision-relevant fact on the board — the whole
			# grammar of the combat is "you can see it coming" — so it is spelt
			# out rather than left as an id to look up.
			"intent": _intent(e),
		})
	d["hand"] = []
	for i in cb.hand.size():
		var c: CardData = cb.hand[i]
		d["hand"].append({
			"index": i,
			"name": c.name,
			"energy": c.energy,
			"heat": c.heat,
			"text": c.describe(),
			"playable": cb.can_play(c),
			# What it would actually do to the current target, after lock-on,
			# salvo, heat scaling and the target's brace. The card text is the
			# rule; this is the number.
			"damage_now": cb.preview_damage(c) if c.damage > 0 else 0,
		})
	d["deck"] = cb.deck.size()
	d["discard"] = cb.discard.size()

	# The party's copy of the enemy, and the barrier. `waiting` means this ship
	# has ended its turn and the fight has not moved yet, which is the one state
	# where the honest answer to "what should I do" is "nothing".
	d["waiting"] = cb.waiting
	if cb.is_shared():
		var f := Net.fight_at(cb.shared_at)
		if f != null:
			var crew: Array = []
			for p in f.crew:
				crew.append(Net.name_of(p))
			var pending: Array = []
			for p in f.waiting_on():
				pending.append(Net.name_of(p))
			d["crew"] = crew
			d["waiting_on"] = pending

	d["moves"] = _fight_moves(cb)
	return d


static func _intent(e: Combat.EnemyState) -> Dictionary:
	if e.intent == null:
		return {}
	return {
		"name": e.intent.name,
		"text": e.intent.text,
		"damage": e.intent.damage,
		"hits": maxi(1, e.intent.hits),
		"block": e.intent.block,
		"telegraph": e.intent.telegraph,
		# Pre-multiplied, because "8 damage, 3 hits" is 24 and every brain that
		# has to do that multiplication itself will eventually not.
		"total": e.intent.damage * maxi(1, e.intent.hits),
	}


static func _fight_moves(cb: Combat) -> Array:
	var out: Array = []
	if cb.finished or cb.waiting:
		return out
	for i in cb.hand.size():
		if cb.can_play(cb.hand[i]):
			out.append("play %d" % i)
	out.append("end_turn")
	# Costs FLEE_FUEL and pays nothing. Listed anyway: a brain that cannot
	# retreat is not playing the same game as the people it is flying with.
	out.append("flee")
	# Hand the rest of the turn to Policy. The escape hatch that makes a slow
	# brain safe — see BotPilot's shot clock.
	out.append("pass")
	return out


## The map. Where this ship is, and everywhere it could legally go next.
static func map(seq: int) -> Dictionary:
	var d := of("map", seq)
	var here: MapGen.MapNode = Run.node_at()
	d["at"] = Run.at
	d["system"] = MapGen.star_name(here)
	d["layer"] = here.layer
	d["danger"] = here.danger
	d["jump_range"] = snappedf(Run.jump_range(), 0.1)
	d["links"] = []
	var moves: Array = []
	for idx in here.links:
		var n: MapGen.MapNode = Run.map[idx]
		var cost := Run.fuel_cost_to(n)
		var can := Run.can_jump_to(n)
		d["links"].append({
			"index": idx,
			"system": MapGen.star_name(n),
			"type": _node_type(n.type),
			"danger": n.danger,
			"layer": n.layer,
			# Deeper is toward the goal. Without this a brain cannot tell
			# progress from wandering, and wandering is how runs end dry.
			"deeper": n.layer > here.layer,
			"fuel": cost,
			"visited": n.visited,
			# CLEARED IS THE PARTY'S WORD, not this ship's. Somebody else may
			# have stripped it — see Sig.party_map_changed.
			"cleared": n.cleared,
			"reachable": can,
		})
		if can:
			moves.append("jump %d" % idx)
	# Staying put is a move, and on a map board it is often the right one. A
	# party member is somewhere on this list of systems or on their way to one,
	# and a ship that must jump every time it is asked cannot ever be waited for.
	if Net.is_networked():
		moves.append("hold")
	d["moves"] = moves
	return d


## A station. The one place a party competes for something that is not an enemy.
static func station(seq: int) -> Dictionary:
	var d := of("station", seq)
	var n: MapGen.MapNode = Run.node_at()
	d["at"] = Run.at
	d["system"] = MapGen.star_name(n)
	d["shelf"] = []
	var moves: Array = []
	for i in n.shop.size():
		var m: ModuleData = n.shop[i]
		# The gap in the shelf where somebody else got there first. Shown rather
		# than skipped, because "sold" is information — it tells a brain another
		# ship is docked here and shopping.
		var gone := n.taken.has(MapGen.OPTION_SHOP + i)
		var price := Market.ask(n, m)
		d["shelf"].append({
			"slot": i,
			"name": m.name,
			"price": price,
			"slot_kind": _slot_name(m.slot),
			"sold": gone,
			"affordable": Run.credits >= price,
		})
		if not gone and Run.credits >= price and not Run.hold_full():
			moves.append("buy %d" % i)
	d["hold"] = _modules(Run.cargo)
	for i in Run.cargo.size():
		moves.append("sell %d" % i)
	var missing := Run.max_hp() - Run.hp
	d["repair_price"] = Market.repair_price(n, missing) if missing > 0 else 0
	d["refuel_price"] = Market.refuel_price(n)
	if missing > 0 and Run.credits >= d["repair_price"]:
		moves.append("repair")
	if Run.credits >= d["refuel_price"]:
		moves.append("refuel")
	moves.append("pass")
	moves.append("leave")
	d["moves"] = moves
	return d


static func _modules(list: Array) -> Array:
	var out: Array = []
	for m in list:
		out.append({
			"name": (m as ModuleData).name,
			"slot": _slot_name((m as ModuleData).slot),
			"value": Market.base_value(m as ModuleData),
		})
	return out


static func _node_type(t: int) -> String:
	match t:
		MapGen.NodeType.START: return "start"
		MapGen.NodeType.STATION: return "station"
		MapGen.NodeType.SYSTEM: return "system"
		MapGen.NodeType.CORE: return "goal"
		MapGen.NodeType.PULSAR: return "pulsar"
	return "?"


static func _slot_name(s: int) -> String:
	match s:
		ModuleData.Slot.WEAPON: return "weapon"
		ModuleData.Slot.SYSTEM: return "system"
		ModuleData.Slot.UTILITY: return "utility"
	return "?"
