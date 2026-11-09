class_name OptionResolve
extends RefCounted

## One path for every screen that offers a choice, so the rules cannot drift. `Policy` is untouched.
## Why: docs/why/OptionResolve.md#taking-a-choice

## Whether an outcome handed over any of the things the result panel exists to
## show. The ledger covers credits, fuel, heat and hull; this covers the rest.
static func pays_anything(res: Dictionary) -> bool:
	for k in ["module", "material", "material_id", "place"]:
		if res.has(k):
			return true
	return false


## Reward is read off the pile, not outcome keys: three payload forms went unseen (Jon, Oct 22).
## Why: docs/why/OptionResolve.md#reward-detection
static func shows_reward(out: Dictionary) -> bool:
	return int(out.get("loot", 0)) > 0 and not bool(out.get("stay", false))


## What is on the system's pile now, to diff against after (`pile_gained`).
static func pile_now(n: MapGen.MapNode) -> Array:
	var pile := Run.sector_jetsam(n, false) if n != null else null
	return (pile.items as Array).duplicate() if pile != null else []


## How many things are on the system's pile that were not in `was`.
static func pile_gained(n: MapGen.MapNode, was: Array) -> int:
	var pile := Run.sector_jetsam(n, false) if n != null else null
	if pile == null:
		return 0
	var k := 0
	for it in pile.items:
		if not was.has(it):
			k += 1
	return k


## Whether choice `c` can be attempted right now: its price, its material and
## the fuel it burns.
static func affordable(c: Dictionary) -> bool:
	if c.has("cost_credits") and Run.credits < int(c.cost_credits):
		return false
	if c.has("needs_material") and Run.material(StringName(c.needs_material)) < 1:
		return false
	if not fuel_ok(c):
		return false
	return true


## A READING THAT BURNS FUEL (science, `burns = true`) IS REFUSED when paying it
## would take the tank under the way out `Run.drain_fuel` keeps
## (`Run.fuel_floor`). A hard gate, so the card's fuel is what it costs: the
## drain then always takes the whole amount, and science never strands a ship.
static func fuel_ok(c: Dictionary) -> bool:
	if not bool(c.get("burns", false)):
		return true
	return Run.fuel - OptionTable.science_fuel() >= Run.fuel_floor()


static func take(n: MapGen.MapNode, i: int, j: int) -> Dictionary:
	var opt := OptionTable.by_id(n.options[i])
	var choices: Array = opt.get("choices", [])
	if j < 0 or j >= choices.size():
		return {"ok": false, "why": "bounds"}
	var c: Dictionary = choices[j]
	if c.has("cost_credits") and Run.credits < int(c.cost_credits):
		return {"ok": false, "why": "credits"}
	if c.has("needs_material") and Run.material(StringName(c.needs_material)) < 1:
		return {"ok": false, "why": "material"}
	if not fuel_ok(c):
		return {"ok": false, "why": "fuel"}
	var out := {"ok": true, "checked": c.has("check"), "stay": bool(c.get("stay", false)),
		"foe": OptionTable.fight_foe(opt, c)}
	# Ask the party before rolling or paying, or both players pocket the payout.
	# Walking away skips it. Signed jobs and event quests are this ship's alone.
	# Why: docs/why/OptionResolve.md#party-claim
	if not out.stay and not OptionTable.is_mine(n.options[i]):
		var won_it: bool = await Run.take_option(n, MapGen.OPTION_SITE + i)
		if not won_it:
			return {"ok": false, "why": "too_late", "who": Net.taker_name(n.index, MapGen.OPTION_SITE + i)}
	out.band = SkillCheck.Band.MET
	out.odds = SkillCheck.odds_line(c.get("check", {}))
	var call: Callable = c.get("effect", Callable())
	if out.checked:
		out.band = SkillCheck.roll(c.check)
		call = SkillCheck.pick_outcome(c, out.band)
	# The ledger opens before the choice so tolls count in the bill.
	# The screen must not deduct `cost_credits`: effects do, and doing both charged twice.
	# Why: docs/why/OptionResolve.md#ledger
	var was := Run.ledger()
	var things := _things_before(n)
	var res: Variant = call.call() if call.is_valid() else {}
	if typeof(res) != TYPE_DICTIONARY:
		res = {}
	out.res = res
	# Close the books after `pay`, which can still move the ledger.
	var paid := OptionTable.pay(res, n, n.options[i])
	out.bill = EncounterDrawer.bill_rows(was, Run.ledger())
	out.got = _things_after(n, things, paid)
	out.loot = pile_gained(n, things.pile)
	# AN EVENT QUEST TAKEN: what it paid goes on its record, for the QUESTS
	# table's COMPLETED rows (`Run.finish_event_quest` asks whether it is one)
	if not out.stay:
		Run.finish_event_quest(n, i, int(Run.credits) - int(was.credits), gained_names(out.got))
	# Spent now, not on CONTINUE, so a quit on the result screen cannot replay it.
	# A stay choice spends nothing: declining leaves the thing as found.
	# Why: docs/why/OptionResolve.md#spent-option
	if not out.stay:
		Router.option_resolved(i, SkillCheck.band_result(out.band) if out.checked else MapGen.R_DONE)
	_remember(n, i, out)
	out.dead = Run.dead
	# An unchecked chosen fight skips the result panel; a botched check keeps it.
	# Why: docs/why/OptionResolve.md#chosen-fights
	out.fight_now = not out.dead and not out.checked and bool((res as Dictionary).get("fight", false)) \
		and Run.ledger() == was and not pays_anything(res) and int(out.loot) == 0
	if out.fight_now:
		var line := String((res as Dictionary).get("text", ""))
		if line != "":
			Run.log_line(line, &"them")
	return out


## Snapshot before the choice so `_things_after` finds what an effect added by looking.
static func _things_before(n: MapGen.MapNode) -> Dictionary:
	return {
		pile = pile_now(n),
		hold = Run.cargo.duplicate(),
		frame = Run.found_hull,
	}


## Rows for the outcome line: part, material, frame or place. A part names the cards it adds.
static func _things_after(n: MapGen.MapNode, was: Dictionary, paid: String) -> Array:
	var got: Array = []
	var pile := Run.sector_jetsam(n, false)
	if pile != null:
		for it in pile.items:
			if not (was.pile as Array).has(it):
				got.append(_thing(it, true))
	if Run.found_hull != null and Run.found_hull != was.frame:
		got.append({kind = &"frame", name = Run.found_hull.display_name().to_upper(),
			gain = true, tone = UITheme.GOOD, cards = []})
	for bit in paid.split(", ", false):
		if bit.ends_with(" MARKED"):
			got.append({kind = &"place", name = bit.trim_suffix(" MARKED").to_upper(),
				gain = true, tone = UITheme.ICE, cards = []})
	for it in was.hold:
		if not Run.cargo.has(it):
			got.append(_thing(it, false))
	return got


## Names of what a choice handed over; a marked place is a quest, not a payment.
static func gained_names(got: Array) -> Array:
	var out: Array = []
	for raw in got:
		var g: Dictionary = raw
		if bool(g.get("gain", false)) and StringName(g.get("kind", &"")) != &"place":
			out.append(String(g.get("name", "")))
	return out


static func _thing(it: Variant, gain: bool) -> Dictionary:
	if it is ModuleData:
		var m := it as ModuleData
		var cards: Array = []
		for c in m.resolved_cards():
			cards.append(c.name.to_upper())
		return {kind = &"part", name = m.name.to_upper(), gain = gain,
			tone = ModuleData.rarity_ink(m.rarity),
			cards = cards, item = m}
	if it is MaterialData:
		var md := it as MaterialData
		return {kind = &"material", name = md.name.to_upper(), gain = gain,
			tone = UITheme.tier_colour(md.tier), cards = [], item = md}
	var nm := String((it as Resource).get("name")) if it is Resource else "ITEM"
	return {kind = &"item", name = nm.to_upper(), gain = gain, tone = UITheme.ICE, cards = []}


## Walk-away or outcome goes onto the node for the map's cards; yours alone, not sent.
static func _remember(n: MapGen.MapNode, i: int, out: Dictionary) -> void:
	var line := EncounterDrawer.first_sentence(String((out.res as Dictionary).get("text", "")))
	if out.stay:
		n.left[i] = line
		return
	# TAKEN NOW, SO NO LONGER LEFT ALONE
	n.left.erase(i)
	n.said[i] = [EncounterDrawer.moved_line(out.bill), line]
