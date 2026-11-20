extends Harness

## Checks each authored row against a real hold; a "5x1" row would parse yet never
## place. Then the table against the list Jon approved (draft 2).
## Why: docs/why/MaterialTest.md#catalogue-check

## The approved list, which `MaterialTable.ROWS` was generated from.
## Why: docs/why/MaterialTest.md#the-approved-list
const LIST := "res://tools/fixtures/materials_draft2.json"


func run() -> void:
	print("=== materials ===")
	var rows := MaterialTable.all()
	_ok("catalogue is not empty", not rows.is_empty())
	_list()

	# --- every row builds -----------------------------------------------------
	var bad_build: Array[String] = []
	for row in rows:
		var m := MaterialData.of(row)
		if m == null or m.id == &"" or m.name == "":
			bad_build.append(String(row.get("id", "?")))
	_ok("all %d rows build an instance" % rows.size(), bad_build.is_empty())
	if not bad_build.is_empty():
		print("       %s" % ", ".join(bad_build))

	# --- ids are unique, because a save stores one ---------------------------
	var seen: Dictionary = {}
	var dupes: Array[String] = []
	for row in rows:
		var id := StringName(row.get("id", &""))
		if seen.has(id):
			dupes.append(String(id))
		seen[id] = true
	_ok("ids are unique", dupes.is_empty())
	if not dupes.is_empty():
		print("       %s" % ", ".join(dupes))

	# --- and a save can find them again --------------------------------------
	var lost: Array[String] = []
	for row in rows:
		var id := StringName(row.get("id", &""))
		var back := MaterialData.by_id(id)
		if back == null or back.id != id or back.size != MaterialData.parse_cells(
				String(row.get("cells", "1x1"))):
			lost.append(String(id))
	_ok("every id round-trips through by_id", lost.is_empty())
	if not lost.is_empty():
		print("       %s" % ", ".join(lost))

	# --- THE SHAPE FITS A REAL HOLD ------------------------------------------
	# Against the smallest hold: an item fitting only a heavy vanishes quietly for half the
	# roster.
	var smallest := Vector2i(99, 99)
	var which := ""
	for h in DB.hull_frames:
		var g: Vector2i = (h as HullData).hold_grid
		if g.x * g.y > 0 and g.x * g.y < smallest.x * smallest.y:
			smallest = g
			which = (h as HullData).name
	print("  smallest hold: %s, %dx%d" % [which, smallest.x, smallest.y])

	var oversize: Array[String] = []
	for row in rows:
		var m := MaterialData.of(row)
		var f := m.footprint()
		# Turned counts: a 4x1 in a 3x5 hold does not fit lying down but does
		# standing up, and the hold lets you turn things.
		var flat := f.x <= smallest.x and f.y <= smallest.y
		var stood := f.y <= smallest.x and f.x <= smallest.y
		if not (flat or stood):
			oversize.append("%s %dx%d" % [m.id, f.x, f.y])
	_ok("every shape fits the smallest hold, flat or turned", oversize.is_empty())
	if not oversize.is_empty():
		print("       %s" % ", ".join(oversize))

	# --- a station can pay for it --------------------------------------------
	var worthless: Array[String] = []
	for row in rows:
		if int(row.get("value", 0)) <= 0:
			worthless.append(String(row.get("id", "?")))
	_ok("every row is worth something", worthless.is_empty())
	if not worthless.is_empty():
		print("       %s" % ", ".join(worthless))

	# --- and it can be carried -----------------------------------------------
	# Placed for real in the lightest hull's hold; `parse_cells` sanity is not `place_in_hold`
	# accepting it.
	# Why: docs/why/MaterialTest.md#carry-check
	Run.start_new_run(&"korvan", int(HullData.Weight.LIGHT))
	print("  placing into %s, %dx%d" % [Run.hull.name,
		Run.hull.hold_grid.x, Run.hull.hold_grid.y])
	var placed := 0
	for row in rows:
		var m := MaterialData.of(row)
		Run.cargo.clear()
		if Run.place_in_hold(m):
			placed += 1
	_ok("every row places into an empty hold", placed == rows.size())
	if placed != rows.size():
		print("       %d of %d placed" % [placed, rows.size()])
		for row in rows:
			var m2 := MaterialData.of(row)
			Run.cargo.clear()
			if not Run.place_in_hold(m2):
				print("       refused %s %dx%d (hold %dx%d)" % [m2.id,
					m2.footprint().x, m2.footprint().y,
					Run.hull.hold_grid.x, Run.hull.hold_grid.y])

	# --- and it survives a save ----------------------------------------------
	# Only id and cell are stored and the rest rebuilt from the catalogue, the half that can
	# silently fail.
	# Why: docs/why/MaterialTest.md#save-check
	Run.cargo.clear()
	var want: Array[StringName] = []
	for row in rows:
		var m3 := MaterialData.of(row)
		if not Run.place_in_hold(m3):
			break
		want.append(m3.id)
	var placed_at: Array[Vector2i] = []
	for c in Run.cargo:
		placed_at.append(c.hold_at)
	_ok("a hold can be filled with materials", want.size() > 0)

	SaveGame.save()
	Run.cargo.clear()
	_ok("save then load returns a run", SaveGame.load_into_run())

	var back: Array[StringName] = []
	var cells_back: Array[Vector2i] = []
	for c in Run.cargo:
		if c is MaterialData:
			back.append((c as MaterialData).id)
			cells_back.append(c.hold_at)
	_ok("every material came back (%d of %d)" % [back.size(), want.size()],
		back == want)
	_ok("and came back in the same cells", cells_back == placed_at)

	# --- overboard -----------------------------------------------------------
	# Jettison destroys nothing: it moves the item to the system bag, and both halves are
	# checked.
	# Why: docs/why/MaterialTest.md#jettison
	Run.cargo.clear()
	var here: MapGen.MapNode = Run.node_at()
	var floor_h := Run.sector_jetsam(here)
	var before := floor_h.items.size()
	var thrown := MaterialData.of(rows[0])
	_ok("something is in the hold to throw", Run.place_in_hold(thrown))
	_ok("it goes overboard", Run.jettison(thrown))
	_ok("and it is out of the hold", not Run.cargo.has(thrown))
	_ok("and it is on this system's floor",
		floor_h.items.size() == before + 1 and floor_h.items.has(thrown))
	_ok("so it can be picked back up", Run.jetsam_left(here, floor_h) > 0)

	# --- and back again ------------------------------------------------------
	# `take_from_bag` marked the option taken first, then stowed: a crate spent its claim and
	# stayed on the floor.
	# Why: docs/why/MaterialTest.md#take-back
	Run.cargo.clear()
	var retrieved := MaterialData.of(rows[1])
	_ok("a material stows", Run.stow(retrieved))
	_ok("and is in the hold", Run.cargo.has(retrieved))
	_ok("with a cell of its own", retrieved.hold_at.x >= 0)

	# A module has to still stow, since the signature moved under it.
	var part := LootGen.roll_module(1, &"", false, Rng.derive(&"materialtest", 2))
	_ok("a module still stows", Run.stow(part))

	# --- what the cursor is aiming at ----------------------------------------
	# The ghost centres the plate, so a 3x1 lands a cell and a half left; `target_for` read
	# top-left.
	# Why: docs/why/MaterialTest.md#drag-target
	Run.cargo.clear()
	Run.cargo.append(MaterialData.new())
	_ok("a hold with a material counts no contraband, and does not crash", Run.contraband_count() == 0)
	Run.cargo.clear()
	var grid := HoldGrid.new()
	grid.refresh()
	var long_one := MaterialData.new()
	long_one.size = Vector2i(3, 1)
	var aim := grid.target_for(long_one, Vector2(100, 60))
	_ok("a 3x1 lands where the plate is, not where the pointer is (%s)" % aim,
		aim == Vector2i(1, 1))
	var one := MaterialData.new()
	one.size = Vector2i.ONE
	var aim1 := grid.target_for(one, Vector2(100, 60))
	_ok("and a 1x1 still lands under the pointer (%s)" % aim1,
		aim1 == Vector2i(2, 1))
	# A 4x1 in a 4-wide hold has exactly one column it can start in, and the
	# clamp has to find it from anywhere along the row.
	var wide := MaterialData.new()
	wide.size = Vector2i(4, 1)
	_ok("a full-width item clamps into the only column that fits",
		grid.target_for(wide, Vector2(300, 20)) == Vector2i(0, 0))
	grid.queue_free()

	# --- swapping out of a full hold -----------------------------------------
	# A swap lands the resident in cells the new part is giving up; a full hold refused them
	# all.
	# Why: docs/why/MaterialTest.md#full-hold-swap
	Run.cargo.clear()
	var packed := 0
	for prow in rows:
		if Run.hold_full():
			break
		var pm := MaterialData.of(prow)
		if Run.place_in_hold(pm):
			packed += 1
	_ok("the hold is packed (%d items, full: %s)" % [packed, Run.hold_full()],
		Run.hold_full())

	var leaving: HoldItem = Run.cargo[0]
	var same := MaterialData.new()
	same.size = leaving.size
	_ok("with the hold full, nothing new fits", not Run.has_room_for(same))
	_ok("but a same-size swap does, once the departing part is counted out",
		Run.has_room_for(same, leaving))

	# And bigger still does not, because the arithmetic is real rather than a
	# blanket exemption for anything called a swap.
	var bigger := MaterialData.new()
	bigger.size = Vector2i(leaving.size.x + 1, leaving.size.y + 1)
	_ok("a bigger one still does not fit",
		not Run.has_room_for(bigger, leaving) or bigger.cells() <= leaving.cells())

	# --- out, back, out, back ------------------------------------------------
	# Jettison appended a second reference to one object, so `find()` hit the spent one and
	# refused pickup.
	# Why: docs/why/MaterialTest.md#repeated-throw
	Run.cargo.clear()
	var here2: MapGen.MapNode = Run.node_at()
	here2.jetsam.clear()
	here2.taken.clear()
	var yoyo := MaterialData.of(rows[2])
	_ok("it is in the hold to begin with", Run.place_in_hold(yoyo))
	_ok("first throw", Run.jettison(yoyo))
	var floor2 := Run.sector_jetsam(here2)
	_ok("the floor holds it once", floor2.items.count(yoyo) == 1)
	_ok("first pick-up", Run.stow(yoyo) if floor2.items.has(yoyo) else false)
	# `stow` is what `take_from_bag` calls once the claim is won; mark the claim
	# the way taking it would have.
	here2.taken.append(floor2.option(floor2.items.find(yoyo)))

	_ok("second throw", Run.jettison(yoyo))
	_ok("the floor STILL holds it once", floor2.items.count(yoyo) == 1)
	_ok("and the claim was released, so it can be taken again",
		not here2.taken.has(floor2.option(floor2.items.find(yoyo))))
	_ok("so it is loose out there", Run.jetsam_left(here2, floor2) == 1)

	# --- a turn that did not land --------------------------------------------
	# R mid-drag flips `turned` in place; a cancelled drag left a 4x1 as a 1x4 off the grid.
	# `Run.settle` fixes it.
	# Why: docs/why/MaterialTest.md#cancelled-turn
	Run.cargo.clear()
	var g2 := Run.hold_grid()
	var bar := MaterialData.new()
	bar.size = Vector2i(4, 1)
	bar.name = "TEST BAR"
	_ok("a 4x1 goes in the last row",
		Run.place_in_hold(bar, Vector2i(0, g2.y - 1)))

	# The mid-drag turn, exactly as the key handler does it: on the item, in
	# place, with no re-validation.
	bar.turned = not bar.turned
	var f2 := bar.footprint()
	var hangs := bar.hold_at.y + f2.y > g2.y
	_ok("turning it in place puts it outside the grid (%s + %s in %s)"
		% [bar.hold_at, f2, g2], hangs)

	_ok("settle puts it somewhere legal", Run.settle(bar))
	var f3 := bar.footprint()
	_ok("and it is inside the grid now (%s + %s in %s)"
		% [bar.hold_at, f3, g2],
		bar.hold_at.x >= 0 and bar.hold_at.x + f3.x <= g2.x
			and bar.hold_at.y + f3.y <= g2.y)
	_ok("and it is still in the hold", Run.cargo.has(bar))

	# --- money takes no room -------------------------------------------------
	# A chit has a footprint to draw but occupies no cell; a full hold must still take it.
	# Why: docs/why/MaterialTest.md#money-takes-no-room
	Run.cargo.clear()
	while not Run.hold_full():
		var filler := MaterialData.of(rows[0])
		if not Run.place_in_hold(filler):
			break
	_ok("the hold is full", Run.hold_full())
	var purse := Run.credits
	var chit := CreditChit.of(137)
	_ok("a full hold still has room for money", Run.has_room_for(chit))
	var held := Run.cargo.size()
	_ok("and takes it", Run.stow(chit))
	_ok("crediting %d -> %d" % [purse, Run.credits],
		Run.credits == purse + 137)
	_ok("without occupying a cell (%d items either side)" % Run.cargo.size(),
		Run.cargo.size() == held and not Run.cargo.has(chit))

	# --- a wide part must not burn its claim on one free cell ----------------
	# take_from_bag asked for one cell, claimed the part, then failed to stow it.
	Run.cargo.clear()
	var site: MapGen.MapNode = Run.node_at()
	site.bag.clear()
	site.taken.clear()
	_fill_hold()
	Run.take_from_hold(Run.cargo[0])
	var slab := MaterialData.new()
	slab.size = Vector2i(2, 2)
	site.bag.append(slab)
	var took: bool = await Run.take_from_bag(site, 0)
	_ok("a 2x2 part is refused with one cell free", not took)
	_ok("and its claim is not spent", site.taken.is_empty() and Run.bag_left(site) == 1)

	# --- RELIC ANALYSIS into a packed hold keeps the part ---------------------
	# The roll came after the money and the relic were spent; a shape that did not fit vanished.
	var recipe: Dictionary = DB.RECIPES[0]
	var vanished := 0
	var spilled := 0
	for k in 12:
		Run.cargo.clear()
		site.jetsam.clear()
		Run.credits = 9999
		Run.place_in_hold(MaterialData.of(MaterialTable.by_id(&"relic")))
		_fill_hold()
		var said := Fabricator.make(site, recipe)
		var mods := Run.cargo.filter(func(m: HoldItem) -> bool: return m is ModuleData).size()
		var pile := Run.sector_jetsam(site, false)
		var down := 0
		if pile != null:
			down = pile.items.filter(func(m: HoldItem) -> bool: return m is ModuleData).size()
		spilled += down
		if said.is_empty() or mods + down != 1:
			vanished += 1
	_ok("every analysis ends with its part somewhere (%d vanished, %d on the floor)"
		% [vanished, spilled], vanished == 0)

	verdict("materialtest")


## The game's table against the approved list: every row as written, each source's matrix,
## the cut ids, what `pick` and `roll` hand back, and the tooltip's lines.
func _list() -> void:
	print("=== the approved list (draft 2) ===")
	var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(LIST))
	if not _ok("the list loads (%s)" % LIST, typeof(doc) == TYPE_DICTIONARY):
		return
	var fields: Array = doc.fields
	var want: Array = []
	for r in doc.materials:
		want.append([r, false])
	for r in doc.named:
		want.append([r, true])
	var wrong: Array[String] = []
	for pair in want:
		var r: Dictionary = {}
		for i in fields.size():
			r[fields[i]] = pair[0][i]
		var got := MaterialTable.by_id(StringName(r.id))
		if got.is_empty() or String(got.id) != r.id:
			wrong.append("%s missing" % r.id)
			continue
		for k in ["name", "tier", "cells", "source", "text"]:
			if String(got.get(k, "")) != String(r[k]):
				wrong.append("%s %s is %s, list says %s" % [r.id, k, got.get(k, ""), r[k]])
		if int(got.get("value", 0)) != int(r.value):
			wrong.append("%s value is %d, list says %d" % [r.id, int(got.get("value", 0)), int(r.value)])
		if bool(got.get("named", false)) != bool(pair[1]):
			wrong.append("%s named is %s" % [r.id, got.get("named", false)])
	_ok("every row of the list is in the game as written (%d rows)" % want.size(), wrong.is_empty())
	_ok("and the game has no row the list does not (%d in the game)" % MaterialTable.all().size(),
		MaterialTable.all().size() == want.size())
	for line in wrong.slice(0, 12):
		print("       %s" % line)
	_matrix(doc)
	_cut_and_pick(doc)
	_deep_wrecks()


## Deep wrecks pay more, rising with depth, and turn up the precursor pieces (Jon, Nov 19):
## 3000 positional rolls a tier, their mean value and grades printed, the rule held.
func _deep_wrecks() -> void:
	print("=== deep wrecks ===")
	var mean: Dictionary = {}
	var found: Dictionary = {}
	var stray := 0
	for d in range(1, MapGen.DANGER_MAX + 1):
		var t := MapGen.tier(d)
		if mean.has(t):
			continue
		var r := Rng.derive(&"materialtest_deep", t)
		var sum := 0
		var by: Dictionary = {}
		for i in 3000:
			var row := MaterialTable.roll(&"wreck", d, r)
			sum += int(row.value)
			by[row.tier] = int(by.get(row.tier, 0)) + 1
			if row.source != &"wreck":
				found[row.id] = t
				if t < MaterialTable.WRECK_PRECURSOR_TIER or not row.get("precursor", false):
					stray += 1
		mean[t] = sum / 3000.0
		var line := "  tier %d: %5.1f a roll ·" % [t, mean[t]]
		for g in MaterialTable.TIERS:
			if by.has(g):
				line += " %s %d%%" % [g, roundi(100.0 * by[g] / 3000.0)]
		print(line)
	_ok("a wreck roll is worth more the deeper it is (%s)" % str(mean),
		mean[3] > mean[2] and mean[4] > mean[3] and mean[5] > mean[4] and mean[4] >= 95.0)
	_ok("deep wrecks turn up the other lists' precursor pieces (%s)" % ", ".join(found.keys()),
		found.has(&"singing_tine") and found.has(&"caged_sphere") and found.has(&"closed_bay_key"))
	_ok("and nothing else from another list, at any depth (%d)" % stray, stray == 0)


## Each source has exactly the list's count at every tier, so every grade it should have is there.
func _matrix(doc: Dictionary) -> void:
	var off: Array[String] = []
	_ok("the sources are the list's (%s)" % ", ".join(MaterialTable.SOURCES),
		Array(MaterialTable.SOURCES).map(func(s: StringName) -> String: return String(s)) == doc.sources)
	for src in doc.matrix:
		for tier in doc.matrix[src]:
			var n := MaterialTable.rows_of(StringName(src), StringName(tier)).size()
			if n != int(doc.matrix[src][tier]):
				off.append("%s %s: %d, list says %d" % [src, tier, n, int(doc.matrix[src][tier])])
	_ok("every source has the list's count at every tier%s" % ("" if off.is_empty() else ": " + "; ".join(off)),
		off.is_empty())
	var open := true
	for d in range(1, MapGen.DANGER_MAX + 1):
		open = open and MaterialTable.admits(&"uncommon", d)
	_ok("uncommon rolls at every danger, everywhere", open)


## Cut ids load as their successor; `pick` stays in its source at or under the grade asked;
## `roll` pays every source at the rim and in the deep; the tooltip says NAME / TIER / SOURCE.
func _cut_and_pick(doc: Dictionary) -> void:
	var lost: Array[String] = []
	for cut in doc.cut:
		var m := MaterialData.by_id(StringName(cut))
		if m == null or String(m.id) != String(doc.cut[cut]):
			lost.append(String(cut))
	_ok("a cut id in a save loads as the row that took its slot%s" % ("" if lost.is_empty() else ": " + ", ".join(lost)),
		lost.is_empty())
	var bad: Array[String] = []
	var r := Rng.derive(&"materialtest", 9)
	for src in MaterialTable.SOURCES:
		for i in MaterialTable.TIERS.size():
			var tier := MaterialTable.TIERS[i]
			var row := MaterialTable.pick(src, tier, r)
			var at := MaterialTable.TIERS.find(StringName(row.get("tier", &"")))
			var ok: bool = not row.is_empty() and row.source == src and at <= i \
				and (tier == &"contraband") == (row.tier == &"contraband")
			if not ok:
				bad.append("%s %s -> %s" % [src, tier, row.get("id", "nothing")])
		for d in [1, MapGen.DANGER_MAX]:
			var rolled := MaterialTable.roll(src, d, r)
			var own: bool = not rolled.is_empty() and (rolled.source == src or rolled.get("precursor", false))
			if not own or rolled.get("named", false):
				bad.append("%s rolled at danger %d -> %s" % [src, d, rolled.get("id", "nothing")])
	_ok("pick and roll stay in their source, at or under the grade%s" % ("" if bad.is_empty() else ": " + "; ".join(bad)),
		bad.is_empty())
	var cable := MaterialData.by_id(&"cable_loom")
	var tip := MaterialIcon.tip_text(cable).split("\n")
	_ok("the tooltip reads NAME / TIER / SOURCE, then its line (%s)" % " / ".join(tip),
		tip.size() >= 5 and tip[0] == "CABLE LOOM" and tip[1] == "UNCOMMON" and tip[2] == "WRECK"
			and tip[3] == "" and " ".join(tip.slice(4)) == cable.text)
	# The tag shows those lines as they are (`TagLayer.plain` dropped the caps head in the first render).
	var icon := MaterialIcon.new()
	icon.setup(cable, &"hold")
	var ls := icon.tag_lines()
	_ok("and the tag shows each of them (%d lines)" % ls.size(), ls.size() == tip.size()
		and String(ls[0][0]) == "CABLE LOOM" and String(ls[2][0]) == "WRECK")
	icon.free()


## Packs the hold with one-cell blanks until a cell is not free.
func _fill_hold() -> void:
	while not Run.hold_full():
		var blank := MaterialData.new()
		blank.size = Vector2i.ONE
		if not Run.place_in_hold(blank):
			break
