extends Harness

## What every frame actually launches with:
##   godot --headless --path . -- reactor
##
## A SHEET AND A GATE. It prints the twelve weight-by-grade combinations so the
## reactor ladder can be tuned by looking at real launches rather than at the
## table it came from, and it fails on the two ways the ladder can be set wrong.
##
## THE FAILURE IT EXISTS FOR is a cell budget so tight that a frame launches
## without a deck. `_top_up_deck` fills spare mounts until the deck reaches
## hand_size + 4, and it now has to respect the reactor — so a low cap does not
## produce a small ship, it produces a ship whose every turn is identical
## because it draws its entire deck. That is not a hypothesis: the medium's
## second utility mount exists because an Atelier Yacht once opened with four
## cards against a hand of five, and nothing about the fix stops a reactor
## number from putting it straight back.
##
## Deliberately measured through `start_new_run`, the real path, rather than by
## arithmetic on the tables. The kit is filtered by mounts AND by capacity, and
## the interaction between those two filters is the thing worth checking.

## A deck has to be bigger than the hand or there is no deck. Equal is the
## degenerate case — every card, every turn, nothing held back and nothing to
## sequence. One spare card is the least that is still a game.
const DECK_MARGIN := 1


func run() -> void:
	print("\n%-8s %-3s %5s %5s %6s %6s %5s %5s  %s"
		% ["frame", "cls", "power", "cap", "energy", "gauge", "mods", "deck", "hand"])
	var thin: Array[String] = []
	var over: Array[String] = []
	for w in [HullData.Weight.LIGHT, HullData.Weight.MEDIUM, HullData.Weight.HEAVY]:
		for t in HullData.TIER_NAMES.size():
			Rng.reseed(4242, 0)
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


## THE PARTS THAT GRANT CAPACITY, measured on the gauge rather than counted in
## the table that authored them.
##
## Every coupling raises REACTOR by the same +2, and the cells it grants are
## derived from that. So the thing worth checking is the PIP, not the cell
## count: a change to CELLS_PER_PIP moves every grant at once and this is what
## notices if the two halves stop agreeing.
##
## It replaces a check on the NET, which measured a proxy. That rule — nothing
## nets more than +2 — was a guess at what "not too much" meant, made before the
## gauge was the unit, and it is superseded: the nets now run from +2 to +5 by
## design, because a part that grants capacity also occupies it and a 1-cell
## cable keeps more of its own grant than a 2x2 armature does.
func _hardware() -> void:
	var rows: Array[String] = []
	var bad: Array[String] = []
	for id in DB.modules:
		var m: ModuleData = DB.modules[id]
		if m.power_cap == 0:
			continue
		Rng.forced = 4242
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
		Run.installed.clear()
		var before := Run.attr_reactor()
		var fit := m.duplicate(true) as ModuleData
		fit.mount = 0
		Run.installed.append(fit)
		var moved := Run.attr_reactor() - before
		rows.append("  %-24s %s  REACTOR %+d  ·  +%d cells, %d to run, net %+d"
			% [m.name, ModuleData.rarity_name(m.rarity).left(4).to_upper(), moved,
				m.power_cap, m.cells(), m.power_cap - m.cells()])
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
