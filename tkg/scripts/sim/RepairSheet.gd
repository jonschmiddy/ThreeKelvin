extends RefCounted

## `heal_scale` cannot be read off the data: at three hull, one card for one energy buys a turn.
## Why: docs/why/RepairSheet.md#repair-worth

## Buying a turn is a fifth of a hull, about one enemy swing at mid danger.
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
			# Copies matter: two cards healing seven differ from one healing fourteen.
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
				# Scaled-ness is recorded where known, not parsed back out of a string.
				fails.append({
					"line": "%s buys %d of %d at three hull" % [card.name, got, cap_m],
					"scaled": card.heal_scale > 0,
				})

	print("")
	# Flat healers are not failures: Calyx heals all fight, and the bar is for lifelines.
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

