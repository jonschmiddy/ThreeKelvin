extends Harness

## Does a part actually move the gauge its grade promised:
##   godot --headless --path . -- attrtest
##
## The attribute ladder says a rare part is worth one pip, an epic two, a
## legendary three. `Database._lay_pips` converts that into whatever raw unit
## the gauge is kept in — 7 hull, 2 heat capacity, 2 venting — and then
## `RunState.attr_*` converts it back. THIS CHECKS THE ROUND TRIP, by bolting
## each part onto a bare frame and reading the gauge before and after.
##
## Two ways it goes wrong and neither one throws:
##
## ROUNDING. A pip of venting is 1.5 and the field is an int, so it is stored
## as 2 and reads back as 1.3 — which rounds to 1 and is fine, until a formula
## is retuned and it rounds to 2. Nothing announces that; the part quietly
## becomes worth double its grade.
##
## A CHANGED FORMULA. `PER_PIP` is inverted out of the attr_* functions by hand.
## Retuning attr_thermal's divisor and not touching PER_PIP leaves every heat
## part off the ladder, silently, on every hull in the game.
##
## Measured against a BARE MEDIUM C, one part at a time. One reference frame is
## a definition rather than a discovery: pips are integers and the arithmetic
## rounds, so a bump measured from 2 and a bump measured from 7 can legitimately
## differ by one. The frame everything is measured against has to be named, and
## this is it.

## An axis IS a gauge now, so the table that used to translate between them is
## a pair of names that are the same name. Kept as a lookup rather than deleted
## because the attribute keys are what `attributes()` returns and the passive
## keys are what the catalogue authors — two vocabularies that happen to agree
## are still two vocabularies, and this is where they are joined.
const ON := {
	&"hull": &"hull", &"thermal": &"thermal", &"maneuver": &"maneuver",
	&"sensors": &"sensors", &"stealth": &"stealth",
}


func run() -> void:
	print("\n  %-22s %-10s %-8s %6s %6s" % ["part", "grade", "axis", "want", "got"])
	var bad: Array[String] = []
	for id in DB.PASSIVE_AXIS:
		for raw in DB.PASSIVE_AXIS[id]:
			var axis: StringName = raw
			var m: ModuleData = DB.modules[id]
			var want: int = DB.ATTR_BUMP[int(m.rarity)]
			var got := _measure(id, ON[axis])
			var mark := ""
			if got != want:
				mark = "   OFF"
				bad.append("%s (%s, %s): promised %+d, moved %+d"
					% [m.name, ModuleData.rarity_name(m.rarity), axis, want, got])
			print("  %-22s %-10s %-8s %6d %6d%s"
				% [m.name, ModuleData.rarity_name(m.rarity), axis, want, got, mark])

	# The prices, which are on the ladder's other side and are authored per part.
	print("")
	for id in DB.PASSIVE_COST:
		var row: Array = DB.PASSIVE_COST[id]
		var m: ModuleData = DB.modules[id]
		var want: int = -int(row[1])
		var got := _measure(id, ON[row[0]], _supplier(row[0]))
		var mark := ""
		if got != want:
			mark = "   OFF"
			bad.append("%s costs %s: promised %+d, moved %+d"
				% [m.name, row[0], want, got])
		print("  %-22s %-10s %-8s %6d %6d%s"
			% [m.name, "cost", row[0], want, got, mark])

	# A GRADE UP, from loot or from a save. The catalogue entry carries its own
	# grade's pips; a copy rolled or saved a grade higher must carry the higher
	# grade's, through the save too (Geno, Oct 22: a Rare Ranging Optics read
	# SENSORS +1 and moved nothing).
	print("")
	for id in DB.PASSIVE_AXIS:
		var base: ModuleData = DB.modules[id]
		for r in range(int(base.rarity) + 1, int(ModuleData.Rarity.LEGENDARY) + 1):
			for raw in DB.PASSIVE_AXIS[id]:
				var axis: StringName = raw
				var want: int = DB.ATTR_BUMP[r]
				var got := _measure(id, ON[axis], &"", r)
				var saved := _measure(id, ON[axis], &"", r, true)
				if got != want or saved != want:
					bad.append("%s graded %s (%s): promised %+d, moved %+d, after a save %+d"
						% [base.name, ModuleData.rarity_name(r), axis, want, got, saved])

	_floor()
	_ok("every part moves its gauge by exactly what its grade promised, graded up and saved too",
		bad.is_empty())
	for b in bad:
		_fail(b)
	_affixes()
	_hull_follows_fit()
	verdict("attrtest")


## MISSING HULL STAYS MISSING (Jon, Oct 22). A plate fitted to a full ship
## leaves it full and moves the HULL gauge at once; damage carries across a
## fit; unfitting and refitting lands where it started; a nearly dead ship that
## sheds plating is left at 1, not killed.
func _hull_follows_fit() -> void:
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Run.installed.clear()
	Sig.ship_changed.emit()
	Run.hp = Run.max_hp()
	Sig.ship_changed.emit()
	var base := Run.max_hp()
	var plate := (DB.modules[&"plating"] as ModuleData).duplicate(true) as ModuleData
	DB.regrade(plate, int(ModuleData.Rarity.RARE))
	var add := plate.max_hull
	var gauge := Run.attr_hull()
	plate.mount = 0
	Run.installed.append(plate)
	Sig.ship_changed.emit()
	_ok("a full ship fits a +%d plate and stays full (%d/%d)" % [add, Run.hp, Run.max_hp()],
		add > 0 and Run.max_hp() == base + add and Run.hp == Run.max_hp())
	_ok("and its HULL gauge moves at once (%d -> %d)" % [gauge, Run.attr_hull()],
		Run.attr_hull() == int(round(Run.ATTR_MAX * float(base + add) / Run.HULL_REF)))
	Run.hp -= 2
	var before := Run.hp
	Run.installed.erase(plate)
	Sig.ship_changed.emit()
	_ok("taking it off a damaged ship keeps the damage (%d/%d)" % [Run.hp, Run.max_hp()],
		Run.hp == Run.max_hp() - 2)
	Run.installed.append(plate)
	Sig.ship_changed.emit()
	_ok("and fitting it again lands where it started (%d, was %d)" % [Run.hp, before],
		Run.hp == before)
	Run.hp = 3
	Run.installed.erase(plate)
	Sig.ship_changed.emit()
	_ok("shedding plating near death leaves 1 hull, not 0 (%d)" % Run.hp, Run.hp == 1)


## The pip delta one part makes to one gauge, on a frame carrying nothing else.
func _measure(id: StringName, key: StringName, with: StringName = &"",
		grade: int = -1, through_save: bool = false) -> int:
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Run.installed.clear()
	# A COST NEEDS SOMETHING TO TAKE. Stealth floors at 0, so a flare rack
	# measured on a bare Korvan frame reads no change at all — not because the
	# penalty is missing but because the frame had nothing to lose. Bolting a
	# supplier on first is what makes the subtraction visible, and it is also
	# the only build where the penalty means anything.
	if with != &"":
		var helper := (DB.modules[with] as ModuleData).duplicate(true) as ModuleData
		helper.mount = 1
		Run.installed.append(helper)
	# HULL READS CURRENT HP, not the maximum, so a plate bolted to a frame that
	# is not topped up moves nothing at all and every hull part reads as broken.
	# Filling first is what makes the before and after comparable — and it is
	# also what a refit at a station actually does.
	Run.hp = Run.max_hp()
	var before := _read(key)
	var m := (DB.modules[id] as ModuleData).duplicate(true) as ModuleData
	if grade >= 0:
		DB.regrade(m, grade)
	if through_save:
		m = SaveGame._module_from(SaveGame._module_to(m))
	Run.installed.append(m)
	m.mount = 0
	Run.hp = Run.max_hp()
	return _read(key) - before


func _read(key: StringName) -> int:
	for row in Run.attributes():
		if (row as Dictionary).key == key:
			return int((row as Dictionary).value)
	return 0


## A part that SUPPLIES an axis, so a price on it has something to subtract
## from. The artifact ones, deliberately: they carry the most, so the reference
## sits well clear of the floor and the measurement is of the price rather than
## of the clamp.
func _supplier(axis: StringName) -> StringName:
	match axis:
		&"stealth": return &"lattice"
		&"sensors": return &"director"
		&"hull": return &"reactive"
		&"thermal": return &"shroud"
		&"maneuver": return &"singing"
	return &""


## AN ATTRIBUTE STOPS AT ZERO. It does not go under, and it is not shown as a
## negative anywhere.
##
## The arithmetic above zero is plain — four stealth and a flare rack is three,
## and that is a real pip the rack costs a stealth build. What this checks is
## the bottom: a price on a gauge that is already empty reads 0, not -1, and
## not a smaller number than nothing.
##
## Only sensors and stealth could ever have failed it. They are the two summed
## straight off the hull and its modules rather than derived from a quantity
## that was floored on the way — heat capacity floors at 1, dissipation and
## dodge at 0, and nothing had ever been negative on any of them.
func _floor() -> void:
	var bad: Array[String] = []
	for id in DB.PASSIVE_COST:
		var row: Array = DB.PASSIVE_COST[id]
		var key: StringName = ON[row[0]]
		var m: ModuleData = DB.modules[id]
		Rng.forced = 4242
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
		Run.installed.clear()
		Run.hp = Run.max_hp()
		var priced := m.duplicate(true) as ModuleData
		priced.mount = 0
		Run.installed.append(priced)
		var sunk := _read(key)
		print("  %-22s %-10s %-8s %6d %6d%s"
			% [m.name, "floor", row[0], 0, sunk, "" if sunk == 0 else "   UNDER"])
		if sunk != 0:
			bad.append("%s reads %d on a gauge that was already empty"
				% [m.name, sunk])
	_ok("a gauge with nothing on it stays at zero", bad.is_empty())
	for b in bad:
		_fail(b)


## Every affix in the table moves the gauge it advertises, by its pips.
##
## MEASURED THE SAME WAY A PART IS, on a bare medium C with one thing attached,
## because the arithmetic rounds and a bump measured from a different starting
## value can legitimately differ by one. Reusing the reference frame is what
## makes the two comparable.
##
## A negative pip is checked as carefully as a positive one: `Stripped` trades
## two of maneuverability for one of hull, and a table where the plus half works
## and the minus half silently does not is worse than one that never worked.
##
## STEALTH IS EXCLUDED, and that is a real exception rather than a fudge:
## `attr_stealth` subtracts the ship's heat signature, which the reference frame
## has, so a stealth pip does not survive to the gauge cleanly. The affix is
## still applied -- `_read` would show it on a cold ship -- and the sum it goes
## through is the same one every other gauge uses.
func _affixes() -> void:
	var bad: Array[String] = []
	for a in DB.affixes:
		var af := a as AffixData
		for g in AffixData.GAUGES:
			var pips: int = int(af.get(g))
			if pips == 0 or g == &"stealth":
				continue
			Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
			Run.installed.clear()
			Run.hp = Run.max_hp()
			var before := _read(g)
			# A part with NO passive of its own, so what moves is the affix and
			# nothing else. The chatterbox is a plain gun.
			var m := (DB.modules[&"kh20"] as ModuleData).duplicate(true) as ModuleData
			m.affixes = [af]
			Run.installed.append(m)
			m.mount = 0
			Run.hp = Run.max_hp()
			var moved := _read(g) - before
			if moved != pips:
				bad.append("%s: %s moved %+d, promised %+d"
					% [af.name, String(g).to_upper(), moved, pips])
	_ok("every affix moves the gauge it names, by the pips it names",
		bad.is_empty())
	for b in bad:
		_fail(b)
	_faces()


## A card reads the same however the module that granted it rolled.
##
## THE POINT OF THE WHOLE MOVE. Affixes used to write into card fields and
## `describe()` prints a clause per non-zero field, so a Slug off a plain module
## read "Deal 4 x 2." and the same Slug off a well-rolled one read "Deal 4 x 2.
## Draw 1. Vent 2. Heal 2." -- in a box 93 pixels wide, with fit_content on and
## no clipping, so the words simply left the card.
##
## Compared against the SAME module with no affixes rather than against a
## remembered string, because the expected answer is "whatever this card says
## when nothing has touched it" and hard-coding that would need updating every
## time a card is retuned.
func _faces() -> void:
	var bad: Array[String] = []
	for id in DB.modules:
		var plain := (DB.modules[id] as ModuleData).duplicate(true) as ModuleData
		plain.affixes = []
		var rolled := (DB.modules[id] as ModuleData).duplicate(true) as ModuleData
		rolled.affixes = DB.affixes.duplicate()
		var a := plain.resolved_cards()
		var b := rolled.resolved_cards()
		if a.size() != b.size():
			bad.append("%s grants %d cards plain, %d rolled"
				% [id, a.size(), b.size()])
			continue
		for i in a.size():
			var want := (a[i] as CardData).describe()
			var got := (b[i] as CardData).describe()
			if want != got:
				bad.append("%s card %d: plain \"%s\" vs rolled \"%s\""
					% [id, i, want, got])
	_ok("a card reads the same however its module rolled", bad.is_empty())
	for b2 in bad:
		_fail(b2)
