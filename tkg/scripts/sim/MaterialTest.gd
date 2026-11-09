extends Harness

## Checks each of 64 authored rows against a real hold; a "5x1" row would parse yet never
## place.
## Why: docs/why/MaterialTest.md#catalogue-check


func run() -> void:
	print("=== materials ===")
	var rows := MaterialTable.all()
	_ok("catalogue is not empty", not rows.is_empty())

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

	# The bag row used `module_row`, which a crate fails, so the system seemed to swallow the
	# item.
	# Why: docs/why/MaterialTest.md#jettison
	var row := Widgets.material_row(thrown, Widgets.ModuleContext.BAG, 0,
		func(_a: String, _t: Variant) -> void: pass, "")
	_ok("and the sector can draw a row for it", row != null)
	if row != null:
		row.queue_free()

	# A module has to survive the same path, because `_bag_row` now chooses
	# between two builders and a wrong branch would only show on one kind.
	var gun := LootGen.roll_module(1, &"", false, Rng.derive(&"materialtest", 1))
	var grow := Widgets.module_row(gun, Widgets.ModuleContext.BAG, 0,
		func(_a: String, _t: Variant) -> void: pass, "", 10)
	_ok("and still one for a module", grow != null)
	if grow != null:
		grow.queue_free()

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

	verdict("materialtest")
