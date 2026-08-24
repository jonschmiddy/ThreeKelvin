extends RefCounted

## What every repair card is actually worth, and when:
##   godot --headless --path . -- repairs
##
## `heal_scale` is a dial you cannot read off the data. A card printed as "heal 2"
## that scales at 4 is worth 2 on a turn you are fine and 10 on the turn you are
## about to die, and the whole design question — IS THIS A LIFELINE — is a
## question about the second number, which appears nowhere in Database.gd.
##
## So this prints the second number. Three columns: full hull, half hull, and
## three hull left, against the three real weight classes rather than a made-up
## one, because a card that saves a heavy does not necessarily save a light.
##
## The bar it is checked against: at three hull, ONE CARD FOR AT MOST ONE ENERGY
## should buy a turn. Anything under that is a repair card, not a lifeline, and
## the difference is the entire reason the field exists.

## What "buys a turn" means, as a fraction of the hull you are trying to save.
## A fifth of a hull back is roughly one enemy swing at mid danger, which is the
## thing a lifeline has to be worth.
const LIFELINE := 0.20
## The state the whole design is aimed at. Three hull and one energy.
const DESPERATE := 3


func run() -> void:
	print("\nRepair — what a card is worth, by how much trouble you are in\n")
	var weights := [
		[HullData.Weight.LIGHT, "light"],
		[HullData.Weight.MEDIUM, "medium"],
		[HullData.Weight.HEAVY, "heavy"],
	]
	var hulls: Array = []
	for w in weights:
		var h := DB.hull_for(&"", w[0] as HullData.Weight)
		hulls.append([String(w[1]), h.max_hull if h != null else 30])

	var head := "%-26s %-9s %4s" % ["", "manufacturer", "nrg"]
	for h in hulls:
		head += "  %s %s" % [String(h[0]).substr(0, 3), "full/half/low"]
	print(head)

	var fails: Array = []
	for id in DB.modules:
		var m: ModuleData = DB.modules[id]
		for c in m.cards:
			var card: CardData = c
			if card.heal <= 0 and card.heal_scale <= 0:
				continue
			var manufacturer := String(card.manufacturer if card.manufacturer != &"" \
				else m.manufacturer)
			var row := "%-26s %-9s %4d" % [card.name,
				manufacturer if manufacturer != "" else "yard", card.energy]
			for h in hulls:
				var cap := int(h[1])
				row += "   %2d/%2d/%2d" % [_at(card, cap, cap),
					_at(card, cap, cap / 2), _at(card, cap, DESPERATE)]
			# Copies matter to the answer: two cards that heal seven are a
			# different lifeline from one that heals fourteen, because you have to
			# draw both and pay twice.
			if card.copies > 1:
				row += "  x%d" % card.copies
			if card.credit_cost > 0:
				row += "  %dcr" % card.credit_cost
			if card.heat > 0:
				row += "  +%dheat" % card.heat
			print(row)

			# The bar, checked on the MEDIUM, which is the middle of every axis.
			var cap_m := int(hulls[1][1])
			var got := _at(card, cap_m, DESPERATE)
			if card.energy <= 1 and float(got) / float(cap_m) < LIFELINE:
				# The scaled-ness is recorded HERE, where it is known, rather
				# than formatted into a sentence and parsed back out of it
				# later. The first version appended a string, then split the
				# card's name off the front of it and rescanned the whole module
				# catalogue to recover this one boolean.
				fails.append({
					"line": "%s buys %d of %d at three hull" % [card.name, got, cap_m],
					"scaled": card.heal_scale > 0,
				})

	print("")
	# Flat healers are supposed to fail this and are not reported as failures —
	# Calyx heals you all fight rather than saving you at the end of one, and the
	# bar above is a bar for lifelines. See Database._seed_modules.
	var real: Array = []
	for f in fails:
		if bool((f as Dictionary)["scaled"]):
			real.append(String((f as Dictionary)["line"]))
	if real.is_empty():
		print("every scaled repair at one energy or less buys at least %d%% of a medium hull back." % int(LIFELINE * 100.0))
		print("repairs: PASS")
	else:
		for f in real:
			print("  THIN  %s" % f)
		print("repairs: THIN")


func _at(c: CardData, cap: int, hp: int) -> int:
	var out := c.heal
	if c.heal_scale > 0:
		out += int(maxi(0, cap - hp) / c.heal_scale)
	# Never more than the hole it is filling.
	return mini(out, cap - hp) if cap > hp else out

