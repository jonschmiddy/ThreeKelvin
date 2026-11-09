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
	_augmented_round_trip()
	_augmented_shown()
	_augment_mark()
	# A script error ends a function and the run goes on to PASS, so the two
	# S10 checks say they reached their last line.
	_ok("the AUGMENTED line and mark checks ran to the end", _ends == 2)
	verdict("attrtest")


## How many of the S10 checks reached their last line.
var _ends := 0


## THE AUGMENTED LINE IN EVERY BOX THAT DESCRIBES A PART (science, S10), and those boxes
## still fit at the Lab's worst case: three rolled affixes plus the augment.
## Why: docs/why/AttrTest.md#the-augmented-line-in-every-box
func _augmented_shown() -> void:
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var by_len := DB.affixes.duplicate()
	by_len.sort_custom(func(a: AffixData, b: AffixData) -> bool:
		return (a.name + a.text).length() > (b.name + b.text).length())
	var lab: AffixData = null
	for a in by_len:
		if DB.LAB_AFFIXES.has(StringName((a as AffixData).name)):
			lab = a
			break
	var rolled: Array[AffixData] = []
	for a in by_len:
		if a != lab and rolled.size() < 3:
			rolled.append(a)
	var host: ModuleData = DB.modules[&"kh20"]
	for id in DB.modules:
		if (DB.modules[id] as ModuleData).flavour.length() > host.flavour.length():
			host = DB.modules[id]
	var m := host.duplicate(true) as ModuleData
	var four := rolled.duplicate()
	four.append(lab)
	m.affixes = four
	m.augmented = true
	var plain := host.duplicate(true) as ModuleData
	plain.affixes = rolled.duplicate()
	var stripped := host.duplicate(true) as ModuleData
	stripped.affixes = []
	stripped.augmented = true
	print("  worst case: %s with %s" % [m.name, ", ".join(four.map(
		func(a: AffixData) -> String: return a.name))])

	var noop := func(_what: String, _m: ModuleData) -> void: pass
	var boxes := {
		"the hover popup": func(x: ModuleData) -> Control: return ModuleIcon.tip_for(x),
		"the hull's tip": func(x: ModuleData) -> Control: return Widgets.module_tip_panel(x),
		"the list row": func(x: ModuleData) -> Control: return Widgets.module_row(
			x, Widgets.ModuleContext.HOLD, 10, noop, "", 20),
	}
	for what in boxes:
		var make: Callable = boxes[what]
		var c: Control = make.call(m)
		_ok("%s says AUGMENTED for an augmented part" % what,
			_texts(c).has(Widgets.AUGMENTED_TEXT))
		c.free()
		var p: Control = make.call(plain)
		_ok("%s says nothing of it for a plain one" % what,
			not " ".join(_texts(p)).contains("AUGMENTED"))
		p.free()
		var s: Control = make.call(stripped)
		_ok("%s still says it once STRIP took every affix off" % what,
			_texts(s).has(Widgets.AUGMENTED_TEXT))
		s.free()

	var tip := Widgets.module_tip_panel(m)
	_lay_out(tip)
	_ok("the hull's tip stays %d px wide with four affixes and the line (%d)"
		% [Widgets.TIP_W, tip.size.x], is_equal_approx(tip.size.x, Widgets.TIP_W))
	_ok("and is shorter than the screen (%d of 540)" % tip.size.y, tip.size.y <= 540.0)
	_boxes_fit("the hull's tip", tip, tip)
	tip.queue_free()

	# The popup's part panel is a card wide AT LEAST (`module_readout` with no
	# width floors it, and a long unwrapped name can push it). So the line is
	# measured against the same part unmarked: it may add height, never width.
	var unmarked := m.duplicate(true) as ModuleData
	unmarked.augmented = false
	var pop0 := ModuleIcon.tip_for(unmarked)
	_lay_out(pop0)
	var w0 := (pop0.get_child(0) as Control).size.x
	pop0.queue_free()
	var pop := ModuleIcon.tip_for(m)
	_lay_out(pop)
	var panel := pop.get_child(0) as Control
	_ok("the popup's part panel is no wider for the line (%d, unmarked %d, a card %d)"
		% [panel.size.x, w0, CardView.CARD_W],
		is_equal_approx(panel.size.x, w0) and panel.size.x >= CardView.CARD_W)
	_ok("and the popup is shorter than the screen (%d of 540)" % pop.size.y,
		pop.size.y <= 540.0)
	_boxes_fit("the popup's part panel", panel, panel)
	pop.queue_free()
	_ends += 1


## Every Label's text under `n`.
func _texts(n: Node) -> PackedStringArray:
	var out := PackedStringArray()
	if n is Label:
		out.append((n as Label).text)
	for k in n.get_children():
		out.append_array(_texts(k))
	return out


## LAID OUT FOR REAL, without waiting for a frame (attrtest runs inside Main._ready and quits
## after it).
## Why: docs/why/AttrTest.md#laid-out-for-real
func _lay_out(c: Control) -> void:
	Run.add_child(c)
	for i in 5:
		c.size = c.get_combined_minimum_size()
		_sort(c)


func _sort(n: Node) -> void:
	if n is Container:
		n.notification(Container.NOTIFICATION_SORT_CHILDREN)
	for k in n.get_children():
		_sort(k)


## Every line and rule under `root` inside `panel`, and no two overlapping.
func _boxes_fit(what: String, root: Control, panel: Control) -> void:
	var drawn: Array[Control] = []
	_drawn(root, drawn)
	var outer := panel.get_global_rect()
	var out: Array[String] = []
	var hit: Array[String] = []
	for i in drawn.size():
		var a := drawn[i].get_global_rect()
		if not outer.encloses(a):
			out.append(_name_of(drawn[i]))
		for j in range(i + 1, drawn.size()):
			if a.intersects(drawn[j].get_global_rect()):
				hit.append("%s / %s" % [_name_of(drawn[i]), _name_of(drawn[j])])
	# Laid out at all: a box never sized is 0 x 0, inside everything and on
	# top of nothing, and would pass the two checks below by being empty.
	var flat := drawn.filter(func(c: Control) -> bool: return c.size.x < 1.0 or c.size.y < 1.0)
	_ok("%s: every line and rule has a size (%d of %d flat)" % [what, flat.size(),
		drawn.size()], flat.is_empty())
	_ok("%s: all %d lines and rules inside it%s" % [what, drawn.size(),
		"" if out.is_empty() else " (out: %s)" % ", ".join(out)],
		out.is_empty() and drawn.size() > 4)
	_ok("%s: none on top of another%s" % [what,
		"" if hit.is_empty() else " (%s)" % ", ".join(hit)], hit.is_empty())


func _drawn(n: Node, into: Array[Control]) -> void:
	if (n is Label or n is HSeparator) and (n as Control).visible:
		into.append(n)
	for k in n.get_children():
		_drawn(k, into)


func _name_of(c: Control) -> String:
	return "\"%s\"" % (c as Label).text.left(24) if c is Label else "a rule"


## THE CORNER MARK, drawn only on an augmented part.
## Why: docs/why/AttrTest.md#the-corner-mark
func _augment_mark() -> void:
	var m := (DB.modules[&"kh20"] as ModuleData).duplicate(true) as ModuleData
	var r := Rect2(Vector2(100, 60), ModuleIcon.footprint_box(m))
	var plain := ModuleIcon.plate_ink(m, r)
	_ok("a plain plate inks its four edges and nothing else (%d)" % plain.size(),
		plain.size() == 4 and not plain.any(
			func(q: Array) -> bool: return q[1] == UITheme.ICE))
	m.augmented = true
	var ink := ModuleIcon.plate_ink(m, r)
	var mark := ink.slice(4)
	var ice := mark.filter(func(q: Array) -> bool: return q[1] == UITheme.ICE)
	_ok("an augmented plate inks the edges and then the mark (%d ICE rows of %d)"
		% [ice.size(), mark.size()], ink.size() > 4 and not ice.is_empty())
	var corner := Rect2(r.get_center().x, r.position.y, r.size.x * 0.5,
		r.size.y * 0.5)
	_ok("the mark sits inside the plate, in its top-right corner",
		not mark.is_empty() and mark.all(
			func(q: Array) -> bool: return corner.encloses(q[0] as Rect2)))
	_ok("and the edge is the same four edges a plain plate inks",
		str(ink.slice(0, 4)) == str(plain))

	var bad: Array[String] = []
	for k: float in [1.0, ModuleIcon.HOLD_K]:
		for slot: ModuleData.Slot in [ModuleData.Slot.WEAPON, ModuleData.Slot.SYSTEM,
				ModuleData.Slot.UTILITY]:
			for fx in range(1, 4):
				for fy in range(1, 4):
					var f := Vector2i(fx, fy)
					var q := k / ModuleIcon.HOLD_K
					var step := float(HoldGrid.CELL + HoldGrid.GAP) * q
					var box := Rect2(Vector2.ZERO,
						Vector2(f) * step - Vector2(HoldGrid.GAP, HoldGrid.GAP) * q)
					var up := ModuleIcon.part_turn(slot, f)
					var art := ModuleIcon.part_rect(slot, box,
						ModuleIcon.part_scale(slot, f, box.size), up)
					for w in ModuleIcon.augment_mark(box, k):
						if (w[0] as Rect2).intersects(art):
							bad.append("%s %dx%d at %dx" % [ModuleData.slot_name(slot),
								fx, fy, int(k)])
							break
	_ok("the mark is clear of the silhouette at every footprint, 1x and 2x%s"
		% ("" if bad.is_empty() else " (on it: %s)" % ", ".join(bad)), bad.is_empty())
	_mark_on_sprites()
	_ends += 1


## THE MARK ON A SPRITE stays a corner: it may hide at most this share of the art drawn.
## Why: docs/why/AttrTest.md#the-mark-on-a-sprite
const MARK_HIDES := 0.05

func _mark_on_sprites() -> void:
	var worst := 0.0
	var worst_at := ""
	var on: Dictionary = {}
	var cases := 0
	for id in DB.modules:
		var m := DB.modules[id] as ModuleData
		if m.sprite == null:
			continue
		var img := m.sprite.get_image()
		if img == null:
			continue
		if img.is_compressed():
			img.decompress()
		var ink := 0
		for y in img.get_height():
			for x in img.get_width():
				if img.get_pixel(x, y).a > 0.1:
					ink += 1
		if ink == 0:
			continue
		var fp := m.footprint()
		var packs: Array[Vector2i] = [fp]
		if fp.x != fp.y:
			packs.append(Vector2i(fp.y, fp.x))
		for f in packs:
			for k: float in [1.0, 2.0, 3.0]:
				var q := k / ModuleIcon.HOLD_K
				var step := float(HoldGrid.CELL + HoldGrid.GAP) * q
				var box := Rect2(Vector2(17, 9),
					Vector2(f) * step - Vector2(HoldGrid.GAP, HoldGrid.GAP) * q)
				for mirror in [false, true]:
					cases += 1
					var hid := _mark_hides(img, box, k, mirror,
						ModuleIcon.sprite_turn(m.sprite, f))
					if hid > 0:
						on[id] = true
					var kk := maxi(1, int(roundf(k)))
					var share := float(hid) / float(ink * kk * kk)
					if share > worst:
						worst = share
						worst_at = "%s %dx%d at %dx%s" % [id, f.x, f.y, int(k),
							" flipped" if mirror else ""]
	print("  the mark lies on sprite art for: %s" % ", ".join(on.keys()))
	_ok("the mark was tried on sprite parts (%d cases)" % cases, cases > 100)
	_ok("on a sprite it hides at most %d%% of the art (worst %.1f%%, %s)"
		% [int(MARK_HIDES * 100), worst * 100.0, worst_at], worst <= MARK_HIDES)


## How many of the wedge's pixels land on `img`'s ink, drawn into `box` the way
## `ModuleIcon.draw_sprite` places it (centred, whole magnification, turned a
## quarter anticlockwise when upright, reflected about the box's middle row).
func _mark_hides(img: Image, box: Rect2, k: float, mirror: bool, upright: bool) -> int:
	var kk := maxi(1, int(roundf(k)))
	var dst := Vector2(img.get_size()) * float(kk)
	var cy := box.get_center().y
	var hid := 0
	for w in ModuleIcon.augment_mark(box, k):
		var rr := w[0] as Rect2
		for y in range(int(rr.position.y), int(rr.end.y)):
			for x in range(int(rr.position.x), int(rr.end.x)):
				var p := Vector2(x + 0.5, y + 0.5)
				if mirror:
					p.y = cy * 2.0 - p.y
				var sp: Vector2
				if upright:
					var rel := p - box.get_center().round()
					sp = (Vector2(-rel.y, rel.x) - (-dst * 0.5).round()) / float(kk)
				else:
					sp = (p - (box.position + (box.size - dst) * 0.5).round()) / float(kk)
				var ix := int(floorf(sp.x))
				var iy := int(floorf(sp.y))
				if ix >= 0 and iy >= 0 and ix < img.get_width() and iy < img.get_height() \
						and img.get_pixel(ix, iy).a > 0.1:
					hid += 1
	return hid


## THE LAB'S MARK SURVIVES A SAVE, AND SO DOES WHAT IT ADDED (science, VERSION
## 41). A plain gun with Reinforced added by a Lab goes through the save's own
## module writer and reader: it comes back augmented, still Reinforced, and
## still worth +7 max hull fitted. A plain one comes back unmarked.
func _augmented_round_trip() -> void:
	var reinforced: AffixData = null
	for a in DB.affixes:
		if (a as AffixData).name == "Reinforced":
			reinforced = a
	if reinforced == null:
		_fail("no Reinforced affix to augment with")
		return
	var m := (DB.modules[&"kh20"] as ModuleData).duplicate(true) as ModuleData
	var added := m.affixes.duplicate()
	added.append(reinforced)
	m.affixes = added
	m.augmented = true
	var back := SaveGame._module_from(SaveGame._module_to(m))
	_ok("an augmented part comes back from the save augmented, with its affix",
		back != null and back.augmented and back.affixes.any(
			func(a: AffixData) -> bool: return a.name == "Reinforced"))
	var plain := SaveGame._module_from(SaveGame._module_to(
		(DB.modules[&"kh20"] as ModuleData).duplicate(true) as ModuleData))
	_ok("and a plain one comes back plain", plain != null and not plain.augmented)
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Run.installed.clear()
	var bare := Run.max_hp()
	if back != null:
		back.mount = 0
		Run.installed.append(back)
	_ok("and fitted it still adds 7 max hull (%d to %d)" % [bare, Run.max_hp()],
		Run.max_hp() == bare + 7)


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
	# LIGHTENED, once "Stripped" (Jon, Nov 5): the table holds the new name
	# only, +2 MAN -1 HUL, and the old name a save may hold finds it
	var names: Array = DB.affixes.map(func(x: AffixData) -> String: return x.name)
	var lt := DB.affix_named("Lightened")
	_ok("Lightened is +2 MAN -1 HUL, \"Stripped\" is gone from the table and an old save's \"Stripped\" reads as Lightened",
		lt != null and lt.maneuver == 2 and lt.hull == -1 and not names.has("Stripped")
		and DB.affix_named("Stripped") == lt and DB.LAB_AFFIXES.has(&"Lightened") and not DB.LAB_AFFIXES.has(&"Stripped"))
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
