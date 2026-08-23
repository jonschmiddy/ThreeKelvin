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

## Which gauge each axis lands on. Two axes share THERMAL and two share
## MANEUVER, which is the whole reason `attr_thermal` exists in that shape.
const ON := {
	&"hull": &"hull", &"heat": &"thermal", &"vent": &"thermal",
	&"dodge": &"maneuver", &"init": &"maneuver",
	&"sensors": &"sensors", &"stealth": &"stealth",
}


func run() -> void:
	print("\n  %-22s %-10s %-8s %6s %6s" % ["part", "grade", "axis", "want", "got"])
	var bad: Array[String] = []
	for id in DB.PASSIVE_AXIS:
		var axis: StringName = DB.PASSIVE_AXIS[id]
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

	_floor()
	_ok("every part moves its gauge by exactly what its grade promised",
		bad.is_empty())
	for b in bad:
		_fail(b)
	verdict("attrtest")


## The pip delta one part makes to one gauge, on a frame carrying nothing else.
func _measure(id: StringName, key: StringName, with: StringName = &"") -> int:
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
		&"heat", &"vent": return &"shroud"
		&"dodge", &"init": return &"singing"
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
