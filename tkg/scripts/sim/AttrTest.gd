extends Harness

## Checks the pip round trip, as rounding and a retuned formula both fail silently.
## Why: docs/why/AttrTest.md#attribute-round-trip

## Kept as a lookup: attribute keys and passive keys are two vocabularies that happen to agree.
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

	# A grade up from loot or a save must carry the higher grade's pips (Geno, Oct 22).
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


## Missing hull stays missing (Jon, Oct 22): fitting plating moves the HULL gauge at once.
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
	# A cost needs something to take: stealth floors at 0, so supply some first.
	if with != &"":
		var helper := (DB.modules[with] as ModuleData).duplicate(true) as ModuleData
		helper.mount = 1
		Run.installed.append(helper)
	# Hull reads current hp, so fill first or a plate on a damaged frame moves nothing.
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


## A part that supplies an axis, artifact ones, so the price is measured and not the clamp.
func _supplier(axis: StringName) -> StringName:
	match axis:
		&"stealth": return &"lattice"
		&"sensors": return &"director"
		&"hull": return &"reactive"
		&"thermal": return &"shroud"
		&"maneuver": return &"singing"
	return &""


## An attribute stops at zero; only sensors and stealth, summed straight off parts, could fail it.
## Why: docs/why/AttrTest.md#attribute-floor
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


## Measured on a bare medium C like parts; stealth is excluded as it subtracts heat signature.
## Why: docs/why/AttrTest.md#affix-checks
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


## A card reads the same however its module rolled; affixes used to overflow the card text.
## Why: docs/why/AttrTest.md#card-faces
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
