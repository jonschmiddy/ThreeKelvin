class_name CardResolver
extends RefCounted

## Declarative card resolution. Every effect on CardData is handled here once,
## so adding a card is a data change, not a code change.

static func resolve(c: CardData, cb: Combat, from_charge: bool) -> void:
	if c.energy_gain > 0:
		cb.energy += c.energy_gain
		cb._log("+%d energy." % c.energy_gain, &"good")

	if c.credit_cost > 0:
		if Run.credits < c.credit_cost:
			cb._log("Not enough credits.", &"sys")
			return
		Run.add_credits(-c.credit_cost)
		cb._log("Spent %d credits." % c.credit_cost, &"sys")

	# Discard comes first, so a card that discards then draws cannot pull the junk back.
	if c.discard_hand:
		var n := cb.hand.size()
		cb.discard.append_array(cb.hand)
		cb.hand.clear()
		cb._log("Discarded %d card%s." % [n, "" if n == 1 else "s"], &"sys")
		Sig.hand_changed.emit()

	# A pick is a pause: what you discard is chosen from the hand you had, not the draw.
	if c.discard > 0 or c.decommission > 0:
		cb.choose_kind = &"decommission" if c.decommission > 0 else &"discard"
		cb.choosing = mini(maxi(c.discard, c.decommission), cb.hand.size())

	if c.damage_equals_heat:
		var d := maxi(1, Run.heat + 2)
		cb.damage_enemy(d, 1, c.name)
		cb.attacks_this_turn += 1

	if c.damage > 0:
		var dmg := c.damage
		if c.heat_scale > 0:
			dmg += int(Run.heat / c.heat_scale)
		if c.manufacturer == &"solari" and c.heat_scale > 0 and Run.has_set(&"solari", 3):
			dmg += 2
		if c.flashpoint > 0 and Run.heat > Run.heat_cap():
			dmg += c.flashpoint
			cb._log("  flashpoint +%d/hit" % c.flashpoint, &"good")
		if c.adapt > 0:
			dmg += cb.adapt_bonus
		if c.salvo > 0 and cb.salvo_live(c):
			dmg += c.salvo
			cb._log("  salvo +%d/hit" % c.salvo, &"good")
		if cb.lock_on > 0:
			dmg += cb.lock_on
			cb._log("  lock-on +%d/hit" % cb.lock_on, &"good")
		cb.damage_enemy(dmg, c.hits, c.name)
		if c.adapt > 0:
			cb.adapt_bonus += c.adapt
		cb.lock_on = 0
		cb.attacks_this_turn += 1

	if c.drone_damage > 0:
		var d2 := Combat.Drone.new()
		d2.damage = c.drone_damage
		cb.drones.append(d2)
		cb._log("Drone launched (%d/turn)." % c.drone_damage, &"good")

	if c.drone_brace > 0:
		cb.drone_brace += c.drone_brace
		cb._log("Screen drone launched (+%d brace/turn)." % c.drone_brace, &"good")

	if c.evoke > 0:
		var n := cb.drones.size()
		if n > 0:
			cb.damage_enemy(c.evoke, n, "Evoke (%d drones)" % n)
			cb.drones.clear()
		else:
			cb._log("No drones to evoke.", &"sys")

	if c.brace > 0:
		var a := c.brace
		if Run.has_set(&"probate", 5):
			a += 2
		cb.brace += a
		cb._log("Brace +%d." % a, &"you")

	if c.brace_from_heat:
		var a2 := maxi(2, int(Run.heat / 2) + 2)
		cb.brace += a2
		cb._log("%s +%d brace from heat." % [c.name, a2], &"you")

	if c.block > 0:
		cb.block += c.block
		cb._log("Block +%d (decays)." % c.block, &"you")

	if c.feedback > 0:
		cb.feedback += c.feedback

	if c.negate_next:
		cb.negate_next = true
		cb._log("Next attack on you will be negated.", &"good")

	# After everything that reads heat: Thermal Purge once zeroed the gauge, then hit for 2.
	if c.vent_all:
		var purged := Run.heat
		Run.heat = 0
		if purged > 0:
			cb._log("Purged %d heat." % purged, &"heat")

	if c.vent > 0:
		# Vent adds the ship's dissipation, which no longer sheds on its own, making it a decision.
		# Why: docs/why/CardResolver.md#vent-dissipation
		var v := mini(Run.heat, c.vent + Run.dissipation())
		Run.heat -= v
		if v > 0:
			cb._log("Vented %d heat." % v, &"heat")

	if c.heal > 0 or c.heal_scale > 0:
		var amount := c.heal
		if c.heal_scale > 0:
			# Missing hull is read at the moment of play; see `CardData.heal_scale`.
			var missing := maxi(0, Run.max_hp() - Run.hp)
			amount += int(missing / c.heal_scale)
		var healed := Run.heal(amount)
		if healed > 0:
			cb._log("Hull +%d." % healed, &"good")

	# LOCK-ON STACKS (Jon, Oct 23: "Lock on should stack"). A second sight card
	# adds to the first rather than replacing it; the next attack spends it all.
	if c.lock_on > 0:
		cb.lock_on += c.lock_on
		cb._log("Lock-on +%d. Next attack +%d a hit." % [c.lock_on, cb.lock_on], &"you")

	if c.credit_gain > 0:
		Run.add_credits(c.credit_gain)
		cb._log("+%d credits." % c.credit_gain, &"good")

	if c.draw > 0:
		# Never reshuffle mid-turn: that is what makes 0-cost draw loop forever.
		cb.draw_cards(c.draw, false)

	if c.heat > 0:
		Run.heat += c.heat
		if from_charge:
			cb._log("  +%d heat from discharge." % c.heat, &"heat")

	Sig.resources_changed.emit()
