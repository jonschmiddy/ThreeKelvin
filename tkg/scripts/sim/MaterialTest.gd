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

	verdict("materialtest")
