extends Harness

## Fails if a tight cell budget launches a frame without a deck, measured via `start_new_run`.
## Why: docs/why/ReactorSheet.md#reactor-gate

## A deck must exceed the hand; one spare card is the least that is still a game.
const DECK_MARGIN := 1


func run() -> void:
	print("\n%-8s %-3s %5s %5s %6s %6s %5s %5s  %s"
		% ["frame", "cls", "power", "cap", "energy", "gauge", "mods", "deck", "hand"])
	var thin: Array[String] = []
	var over: Array[String] = []
	for w in [HullData.Weight.LIGHT, HullData.Weight.MEDIUM, HullData.Weight.HEAVY]:
		for t in HullData.TIER_NAMES.size():
			seed_run(4242)
			# start_new_run then fit_chassis, because the grade is a fitting
			# concern and not a world one — the same split the chassis screen uses.
			Run.start_new_run(&"korvan", int(w))
			Run.fit_chassis(&"korvan", w, t)
			var name := HullData.weight_name(w)
			var draw := Run.power_draw()
			var cap := Run.power_cap()
			var mounts := Run.slots_for(ModuleData.Slot.WEAPON) \
				+ Run.slots_for(ModuleData.Slot.SYSTEM) \
				+ Run.slots_for(ModuleData.Slot.UTILITY)
			var deck := Run.deck_size()
			var hand := Run.hand_size()
			print("  %-8s %-3s %5d %5d %6d %6d %5d %5d  %d%s"
				% [name, HullData.TIER_NAMES[t], draw, cap, Run.reactor(),
					Run.attr_reactor(), Run.installed.size(), deck, hand,
					"   THIN" if deck < hand + DECK_MARGIN else ""])
			if deck < hand + DECK_MARGIN:
				thin.append("%s %s: %d cards against a hand of %d"
					% [name, HullData.TIER_NAMES[t], deck, hand])
			if draw > cap:
				over.append("%s %s: draws %d of %d"
					% [name, HullData.TIER_NAMES[t], draw, cap])

	_ok("every frame launches with a deck bigger than its hand", thin.is_empty())
	for x in thin:
		_fail(x)
	_ok("no frame launches drawing more than its reactor carries", over.is_empty())
	for x in over:
		_fail(x)
	_hardware()
	verdict("reactor")


## Checks the PIP, not the cell count or the net, which was a guess made before the gauge.
## Why: docs/why/ReactorSheet.md#capacity-grants
func _hardware() -> void:
	var rows: Array[String] = []
	var bad: Array[String] = []
	for id in DB.modules:
		var m: ModuleData = DB.modules[id]
		if m.reactor == 0:
			continue
		Rng.forced = 4242
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
		Run.installed.clear()
		var before := Run.attr_reactor()
		var was_cells := Run.power_cap()
		var fit := m.duplicate(true) as ModuleData
		fit.mount = 0
		Run.installed.append(fit)
		var moved := Run.attr_reactor() - before
		var gained := Run.power_cap() - was_cells
		rows.append("  %-24s %s  REACTOR %+d  ·  %+d cells, %d to run, net %+d"
			% [m.name, ModuleData.rarity_name(m.rarity).left(4).to_upper(), moved,
				gained, m.cells(), gained - m.cells()])
		if moved != DB.REACTOR_BUMP:
			bad.append("%s moves REACTOR %+d, not %+d"
				% [m.name, moved, DB.REACTOR_BUMP])
	if rows.is_empty():
		print("  no part grants reactor capacity")
	else:
		print("\n  parts that grant capacity:")
		for r in rows:
			print(r)
	_ok("every coupling raises REACTOR by exactly %+d" % DB.REACTOR_BUMP,
		bad.is_empty())
	for b in bad:
		_fail(b)
