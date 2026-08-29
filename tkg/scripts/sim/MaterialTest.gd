extends Harness

## Every catalogue row becomes an item the hold can actually hold.
##
## `MaterialTable` authored 64 rows before anything could carry one, so its
## shapes, values and ids have never been checked against the thing that has to
## accept them. This is that check, and it is the gate
## `docs/briefs/MATERIALS_NOTE.md` §4 asks for.
##
## The point is the SHAPE. A row whose `cells` reads "5x1" parses fine, builds a
## fine instance, and can never be placed in a four-wide hold -- it would roll,
## drop, and refuse to go anywhere, and nothing would say why. That is precisely
## the failure a table authored ahead of its consumer produces.


func run() -> void:
	print("=== materials ===")
	var rows := MaterialTable.all()
	_ok("catalogue is not empty", not rows.is_empty())

	# --- every row builds -----------------------------------------------------
	var built := 0
	var bad_build: Array[String] = []
	for row in rows:
		var m := MaterialData.of(row)
		if m == null or m.id == &"" or m.name == "":
			bad_build.append(String(row.get("id", "?")))
		else:
			built += 1
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
	#
	# Against the SMALLEST hold in the game, not against the biggest. An item
	# that fits a heavy and not a light is an item that vanishes for half the
	# roster, and it would do it quietly.
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
	#
	# Placed for real, into a real hold, one at a time. `parse_cells` returning
	# a sane Vector2i is not the same claim as `place_in_hold` accepting it.
	# The LIGHTEST hull, matching the shape check above: placing into a heavy's
	# hold would pass rows that a light can never carry.
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
	#
	# A material stores only its id and its cell; everything else is rebuilt from
	# the catalogue. That is the right way round, and it is also the half that
	# can silently fail -- a row rebuilt from a table is a row that can come back
	# as something else, or as nothing.
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
	#
	# The ruling is that jettison DESTROYS NOTHING: it moves the item into the
	# bag at the system you are standing in, so it is recoverable until you jump.
	# Both halves are checked, because a jettison that removed the item and
	# forgot to append it would look identical from the hold.
	Run.cargo.clear()
	var here: MapGen.MapNode = Run.node_at()
	var before := here.bag.size() if here != null else -1
	var thrown := MaterialData.of(rows[0])
	_ok("something is in the hold to throw", Run.place_in_hold(thrown))
	_ok("it goes overboard", Run.jettison(thrown))
	_ok("and it is out of the hold", not Run.cargo.has(thrown))
	_ok("and it is in this system's bag",
		here != null and here.bag.size() == before + 1 and here.bag.has(thrown))
	_ok("so it can be picked back up", Run.bag_left(here) > 0)

	# AND THE SECTOR CAN DRAW IT. This is the half that made jettison look
	# broken when it was not: the item went into the bag correctly and the
	# salvage list built its rows with `Widgets.module_row`, which reads a
	# manufacturer, a slot and an affix list off whatever it is handed. A crate
	# has none of those, so the row failed and the system appeared to have
	# swallowed the thing.
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
	#
	# `stow` is what TAKE calls once the claim is won, and it was the last
	# `ModuleData` on the path from a bag to a hold. The failure was the bad
	# kind: `take_from_bag` marked the option taken FIRST and then stowed, so a
	# crate spent its claim and stayed on the floor -- gone from the bag's point
	# of view and never in your hold.
	Run.cargo.clear()
	var retrieved := MaterialData.of(rows[1])
	_ok("a material stows", Run.stow(retrieved))
	_ok("and is in the hold", Run.cargo.has(retrieved))
	_ok("with a cell of its own", retrieved.hold_at.x >= 0)

	# A module has to still stow, since the signature moved under it.
	var part := LootGen.roll_module(1, &"", false, Rng.derive(&"materialtest", 2))
	_ok("a module still stows", Run.stow(part))

	verdict("materialtest")
