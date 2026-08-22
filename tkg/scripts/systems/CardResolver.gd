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

	# THROWING THINGS AWAY, before anything else this card does. A card that
	# purges and then draws must not be able to draw the junk back and purge it
	# in the same breath, and doing this first is what makes the order obvious
	# rather than something to remember.
	if c.purge > 0:
		var gone := 0
		for i in range(cb.hand.size() - 1, -1, -1):
			if gone >= c.purge:
				break
			if (cb.hand[i] as CardData).unplayable:
				cb.discard.append(cb.hand[i])
				cb.hand.remove_at(i)
				gone += 1
		cb._log("Purged %d." % gone if gone > 0 else "Nothing to purge.", &"sys")
		Sig.hand_changed.emit()

	if c.dump_hand:
		var n := cb.hand.size()
		cb.discard.append_array(cb.hand)
		cb.hand.clear()
		cb._log("Dumped %d card%s." % [n, "" if n == 1 else "s"], &"sys")
		Sig.hand_changed.emit()

	if c.vent_all:
		var purged := Run.heat
		Run.heat = 0
		if purged > 0:
			cb._log("Purged %d heat." % purged, &"heat")

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
		if c.adapt > 0:
			dmg += cb.adapt_bonus
		var salvo_ok := cb.attacks_this_turn > 0
		if c.manufacturer == &"korvan" and Run.has_set(&"korvan", 5):
			salvo_ok = true
		if c.salvo > 0 and salvo_ok:
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

	if c.drone_armor > 0:
		cb.drone_armor += c.drone_armor
		cb._log("Wasp screen online (+%d armor/turn)." % c.drone_armor, &"good")

	if c.evoke > 0:
		var n := cb.drones.size()
		if n > 0:
			cb.damage_enemy(c.evoke, n, "Evoke (%d drones)" % n)
			cb.drones.clear()
		else:
			cb._log("No drones to evoke.", &"sys")

	if c.armor > 0:
		var a := c.armor
		if Run.has_set(&"probate", 5):
			a += 2
		cb.armor += a
		cb._log("Brace +%d armor." % a, &"you")

	if c.armor_from_heat:
		var a2 := maxi(2, int(Run.heat / 2) + 2)
		cb.armor += a2
		cb._log("Shroud +%d armor from heat." % a2, &"you")

	if c.block > 0:
		cb.block += c.block
		cb._log("Block +%d (decays)." % c.block, &"you")

	if c.riposte > 0:
		cb.riposte += c.riposte

	if c.negate_next:
		cb.negate_next = true
		cb._log("Next attack will be slipped.", &"good")

	if c.vent > 0:
		var v := mini(Run.heat, c.vent)
		Run.heat -= v
		if v > 0:
			cb._log("Vented %d heat." % v, &"heat")

	if c.heal > 0 or c.heal_scale > 0:
		var amount := c.heal
		if c.heal_scale > 0:
			# What is MISSING, read at the moment of play. See CardData.heal_scale
			# — the whole point is that this number is small when you are fine and
			# large when you are not.
			var missing := maxi(0, Run.max_hp() - Run.hp)
			amount += int(missing / c.heal_scale)
		var healed := Run.heal(amount)
		if healed > 0:
			cb._log("Hull +%d." % healed, &"good")

	if c.lock_on > 0:
		cb.lock_on = c.lock_on
		cb._log("Lock-on engaged.", &"you")

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
