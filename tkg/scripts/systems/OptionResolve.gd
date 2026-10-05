class_name OptionResolve
extends RefCounted

## TAKING ONE CHOICE OF ONE OPTION, the same way from every screen that offers
## it -- the sector's drawer and the system map's panel -- so the rules cannot
## drift apart. Moved whole out of `SectorScreen._take`; its reasoning comes with
## it. `Policy` resolves options its own way for the simulator and is not
## touched, so the simulator still measures the same game.
##
## `take(n, i, j)` runs choice j of option i at node n and returns what
## happened, for the screen to show:
##   ok         false if nothing was done (see `why`)
##   why        "bounds", "credits", "material" or "too_late"
##   who        on "too_late", the partner who got there first ("" if unknown)
##   stay       walking away: nothing rolled, paid or spent
##   checked    whether a skill check was rolled
##   band       SkillCheck.Band
##   odds       the odds line the choice showed
##   res        the outcome's own dictionary (its `text`, its payload)
##   bill       `EncounterDrawer.bill_rows` from before the choice to after `pay`
##   dead       the ship died of it: show the game over
##   fight_now  a fight the player chose with nothing to read: start it, no panel

## Whether an outcome handed over any of the things the result panel exists to
## show. The ledger covers credits, fuel, heat and hull; this covers the rest.
static func pays_anything(res: Dictionary) -> bool:
	for k in ["module", "material", "material_id", "archive_recover", "place"]:
		if res.has(k):
			return true
	return false


## Whether choice `c` can be attempted right now: its price and its material.
static func affordable(c: Dictionary) -> bool:
	if c.has("cost_credits") and Run.credits < int(c.cost_credits):
		return false
	if c.has("needs_material") and Run.material(StringName(c.needs_material)) < 1:
		return false
	return true


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
	var out := {"ok": true, "checked": c.has("check"), "stay": bool(c.get("stay", false))}
	# ASK THE PARTY FIRST -- the same door the wreck path uses. An option two
	# ships can race for is arbitrated through `Run.take_option` before
	# anything is rolled or paid: assume you won and both players pocket the
	# payout, and the flag agreeing afterwards does not take it back. Walking
	# away (`stay`) consumes nothing, so it does not ask.
	if not out.stay:
		var won_it: bool = await Run.take_option(n, MapGen.OPTION_SITE + i)
		if not won_it:
			return {"ok": false, "why": "too_late", "who": Net.taker_name(n.index, MapGen.OPTION_SITE + i)}
	out.band = SkillCheck.Band.MET
	out.odds = SkillCheck.odds_line(c.get("check", {}))
	var call: Callable = c.get("effect", Callable())
	if out.checked:
		out.band = SkillCheck.roll(c.check)
		call = SkillCheck.pick_outcome(c, out.band)
	# THE LEDGER OPENS BEFORE THE CHOICE RUNS. A gate you pay to attempt is part
	# of what the option cost you, and a bill that started counting after the
	# toll was taken would show a botched sixty-credit gamble as costing nothing.
	#
	# AND THE SCREEN DOES NOT TAKE THE MONEY. `cost_credits` is the price the
	# choice DISPLAYS and the affordability gate above refuses on; every priced
	# choice in the table already spends it inside its own effect. Deducting it
	# here as well charged the player twice -- the deep dock's thirty-credit
	# tank cost sixty, and at exactly thirty credits the gate let the click
	# through and `add_credits` floored the second charge at zero, so the price
	# was everything you had. `Policy` never applied this deduction, so the
	# simulator has always priced these options at one charge and the win rate
	# in the gate was measured against that.
	var was := Run.ledger()
	var res: Variant = call.call() if call.is_valid() else {}
	if typeof(res) != TYPE_DICTIONARY:
		res = {}
	out.res = res
	# AND AFTER `pay`, WHICH CAN STILL MOVE THE LEDGER. It is the one call that
	# turns a payload into what the payload promised, so the books close on the
	# far side of it or they close early.
	OptionTable.pay(res, n)
	out.bill = EncounterDrawer.bill_rows(was, Run.ledger())
	# SPENT NOW, NOT ON CONTINUE. The result is already applied -- credits moved,
	# hull taken, a module in the hold -- so a player who closed the game on the
	# result screen must not come back to an option they have already been paid
	# for.
	#
	# UNLESS NOTHING HAPPENED. A `stay` choice is walking away -- no roll, no
	# cost, no payout -- and marking it RESOLVED would spend an encounter on the
	# act of declining it. Declining leaves the thing exactly as found.
	if not out.stay:
		Router.option_resolved(i, SkillCheck.band_result(out.band) if out.checked else MapGen.R_DONE)
	_remember(n, i, out)
	out.dead = Run.dead
	# A FIGHT YOU CHOSE DOES NOT NEED A PANEL IN FRONT OF IT. The result panel
	# earns its click when there is something to read: which way a roll went,
	# and what the branch cost. A choice with no check that starts a fight and
	# moves nothing has neither. ONLY THE UNCHECKED ONES: a botched check is
	# exactly the case where the panel is the point. The line is logged either
	# way, so nothing written for the moment is lost.
	out.fight_now = not out.dead and not out.checked and bool((res as Dictionary).get("fight", false)) \
		and Run.ledger() == was and not pays_anything(res)
	if out.fight_now:
		var line := String((res as Dictionary).get("text", ""))
		if line != "":
			Run.log_line(line, &"them")
	return out


## The walk-away or the outcome, onto the node for the system map's cards
## (`MapNode.left` and `MapNode.said`), where the save keeps them. Yours alone:
## nothing here is claimed or sent to the party.
static func _remember(n: MapGen.MapNode, i: int, out: Dictionary) -> void:
	var line := EncounterDrawer.first_sentence(String((out.res as Dictionary).get("text", "")))
	if out.stay:
		n.left[i] = line
		return
	# TAKEN NOW, SO NO LONGER LEFT ALONE
	n.left.erase(i)
	n.said[i] = [EncounterDrawer.moved_line(out.bill), line]
