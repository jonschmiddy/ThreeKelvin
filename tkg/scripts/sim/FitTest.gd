extends Harness

## Parts can actually be picked up and put down:
##   godot --path . -- fittest
##
## NEEDS A WINDOW. This drives Godot's own drag-and-drop state machine with real
## input events, and that machine lives in Viewport — headless there is no gui
## input to hand it, so the whole thing would pass by never running.
##
## Written because every other test of the hold checks the DATA. `-- holdtest`
## proves two parts never share a cell and `-- mounts` proves a hardpoint sits on
## the hull, and both of them pass in full on a screen where nothing can be
## picked up at all. The refit screen is the one place in the game whose entire
## job is an interaction, and it was the one place with no test of one.
##
## Four crossings, because the hold and the hull are two containers and a part
## has to survive every trip between them: hold to hull, hull to hold, hull to
## hull, and a refusal — a part dropped on a mount of the wrong kind must not
## move, and must not vanish on the way.

var _tree: SceneTree
var _at: Vector2 = Vector2.ZERO


func run(tree: SceneTree) -> void:
	_tree = tree
	await tree.process_frame

	Rng.reseed(7711, 0)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Router.show_ship()
	for i in 4:
		await tree.process_frame

	var screen := Router.current
	if not _ok("the refit screen is up", screen is ShipScreen):
		verdict("fittest")
		return
	var grid := first(screen, func(n: Node) -> bool: return n is HoldGrid) as HoldGrid
	var mounts := first(screen, func(n: Node) -> bool: return n is MountPoints) as MountPoints
	if not _ok("the hold and the hardpoints are both on it",
			grid != null and mounts != null):
		verdict("fittest")
		return

	await _to_hull(grid, mounts)
	await _to_hold(grid, mounts)
	await _wrong_slot(grid, mounts)
	await _turning(grid)
	verdict("fittest")


# ---------------------------------------------------------------- the crossings

## Hold to hull: pick a part out of the grid and bolt it to a free mount.
func _to_hull(grid: HoldGrid, mounts: MountPoints) -> void:
	var m := _stow(ModuleData.Slot.WEAPON)
	if m == null:
		_fail("nothing in the catalogue fits a weapon mount")
		return
	await _settle(grid)
	var icon := _icon_for(grid, m)
	if not _ok("the part has a plate in the hold", icon != null):
		return
	var spot := _free_mount(mounts, ModuleData.Slot.WEAPON)
	if not _ok("the hull has a free weapon mount", spot != Vector2.INF):
		return

	var live := await _carry(_centre(icon), mounts, spot - mounts.get_global_rect().position)
	_ok("a plate in the hold can be picked up", live)
	_ok("dragged from the hold onto the hull: it is installed",
		Run.installed.has(m))
	_ok("dragged from the hold onto the hull: it left the hold",
		not Run.cargo.has(m))
	_ok("dragged from the hold onto the hull: it knows its mount", m.mount >= 0)


## Hull to hold. THE HALF THAT DID NOT EXIST: `_on_hold_drop` has always handled
## a part arriving off the ship, and nothing could ever start that drag, so the
## branch was unreachable and looked written.
func _to_hold(grid: HoldGrid, mounts: MountPoints) -> void:
	var m: ModuleData = null
	for x in Run.installed:
		if (x as ModuleData).slot == ModuleData.Slot.WEAPON:
			m = x
			break
	if not _ok("something is bolted on to take off", m != null):
		return
	var from := _mount_of(mounts, m)
	if not _ok("the fitted part has a place on the hull", from != Vector2.INF):
		return
	await _settle(grid)

	var cell := _empty_cell(grid)
	var live := await _carry(from, grid, cell - grid.get_global_rect().position)
	_ok("a part bolted to the hull can be picked up", live)
	_ok("dragged off the hull into the hold: it is stowed", Run.cargo.has(m))
	_ok("dragged off the hull into the hold: it is off the ship",
		not Run.installed.has(m))
	_ok("dragged off the hull into the hold: its mount is released", m.mount < 0)
	_ok("dragged off the hull into the hold: it has a cell", m.hold_at.x >= 0)


## A part dropped on a mount that will not take it stays exactly where it was.
## The interesting failure is not the refusal, it is a part that is refused
## AFTER being lifted and belongs to neither container afterwards.
func _wrong_slot(grid: HoldGrid, mounts: MountPoints) -> void:
	var m := _stow(ModuleData.Slot.WEAPON)
	if m == null:
		return
	await _settle(grid)
	var icon := _icon_for(grid, m)
	var spot := _free_mount(mounts, ModuleData.Slot.SYSTEM)
	if icon == null or spot == Vector2.INF:
		# No system mount free is not a failure of the rule under test.
		return
	var was := m.hold_at

	await _carry(_centre(icon), mounts, spot - mounts.get_global_rect().position)
	_ok("a weapon refused by a system mount stays in the hold", Run.cargo.has(m))
	_ok("a weapon refused by a system mount does not move", m.hold_at == was)
	_ok("a weapon refused by a system mount is not installed",
		not Run.installed.has(m))


## R turns a part in the hold, and a turn that will not fit costs nothing.
func _turning(grid: HoldGrid) -> void:
	var m := _long()
	if m == null:
		_fail("nothing long enough in the catalogue to turn")
		return
	await _settle(grid)
	var icon := _icon_for(grid, m)
	if not _ok("the long part has a plate", icon != null):
		return
	var before := m.footprint()
	var cells := m.cells()

	_turn(_centre(icon))
	_ok("R turns a %dx%d into a %dx%d" % [before.x, before.y, before.y, before.x],
		m.footprint() == Vector2i(before.y, before.x))
	_ok("turning does not change how much room it takes", m.cells() == cells)
	_ok("a turned part is still somewhere legal",
		m.hold_at.x >= 0 and Run.can_place(m, m.hold_at))
	_no_overlap()

	await _settle(grid)
	var again := _icon_for(grid, m)
	if again != null:
		_turn(_centre(again))
		_ok("R again turns it back", m.footprint() == before)

	# And a turn with nowhere to go leaves the part exactly as it was.
	var packed := _pack_solid()
	await _settle(grid)
	if _ok("a hold packed solid around a long part", packed != null):
		var shape := packed.footprint()
		var where := packed.hold_at
		_turn(_plate_centre(grid, packed))
		_ok("a turn with no room for it changes nothing",
			packed.footprint() == shape and packed.hold_at == where)


## Nothing shares a cell after a turn. The failure this is looking for does not
## throw and does not show up in a total: two parts overlapping still add up.
func _no_overlap() -> void:
	var seen := {}
	var clash := ""
	for x in Run.cargo:
		var f: Vector2i = x.footprint()
		for dy in f.y:
			for dx in f.x:
				var c: Vector2i = x.hold_at + Vector2i(dx, dy)
				if seen.has(c):
					clash = "%s over %s at %s" % [x.name, seen[c], c]
				seen[c] = x.name
	_ok("no two parts share a cell after turning" if clash == "" else clash,
		clash == "")


## A part that is not square, so turning it is visible.
func _long() -> ModuleData:
	for i in 60:
		var m := LootGen.roll_module(3 + (i % 5), &"", true)
		if m.size.x != m.size.y and Run.place_in_hold(m):
			Sig.ship_changed.emit()
			return m
	return null


## What R does, at a point of our choosing. See ShipScreen._turn_in_hold for
## why the point is passed rather than read off the cursor.
func _turn(at: Vector2) -> void:
	(Router.current as ShipScreen)._turn_in_hold(at)


## A hold with EXACTLY no room to turn in, built rather than hoped for.
##
## A 1x3 down the first column and every other cell filled with fittings. Turned
## it wants three cells in a ROW and the only three free are the ones it just
## vacated, in a column — so the move has to be refused, and refused is the
## branch worth testing: the part is out of the hold at that moment and has to
## get back exactly where it was.
##
## Built by hand because the first version of this filled the hold with whatever
## the loot table rolled and then asserted a refusal. There was room, the turn
## succeeded, and the test failed while the code was right.
func _pack_solid() -> ModuleData:
	for m in Run.cargo.duplicate():
		Run.take_from_hold(m)
	var long := LootGen.roll_module(3, &"", true)
	long.size = Vector2i(1, 3)
	long.turned = false
	if not Run.place_in_hold(long, Vector2i.ZERO):
		return null
	var g := Run.hold_grid()
	var guard := 0
	while Run.cargo_used() < g.x * g.y and guard < 200:
		guard += 1
		var fill := LootGen.roll_module(3, &"", true)
		fill.size = Vector2i.ONE
		fill.turned = false
		if not Run.place_in_hold(fill):
			break
	Sig.ship_changed.emit()
	return long


func _plate_centre(grid: HoldGrid, m: ModuleData) -> Vector2:
	var o := grid.get_global_rect().position
	var f := m.footprint()
	var step := float(HoldGrid.CELL + HoldGrid.GAP)
	return o + Vector2(m.hold_at) * step + Vector2(f) * step * 0.5


# ------------------------------------------------------------------- the mouse

## One crossing: pick up at `from` on the screen, put down at `local` on
## `onto`. Returns whether a drag actually started.
##
## THE PICK-UP IS REAL AND THE DROP IS NOT, and the split is deliberate rather
## than lazy. Real events start a genuine drag — `gui_is_dragging()` goes true
## and the payload comes back through `_get_drag_data` — but Godot then follows
## the OS CURSOR for the rest of it, so pushed motion does not steer the hover.
## Driving the rest would mean warping the physical mouse on whatever machine is
## running the gate, which is a real side effect to inflict for a test.
##
## So the engine's routing is out of scope here and everything of ours is in it:
## that a plate hands over a payload, that a target accepts or refuses it, and
## that the run's state afterwards is right.
func _carry(from: Vector2, onto: Control, local: Vector2) -> bool:
	var vp := _tree.root
	await _move(from, 0)
	await _press(from, true)
	await _move(from + Vector2(0, -24), MOUSE_BUTTON_MASK_LEFT)
	var data: Variant = vp.gui_get_drag_data()
	var live := vp.gui_is_dragging() and typeof(data) == TYPE_DICTIONARY
	if live:
		if onto._can_drop_data(local, data):
			onto._drop_data(local, data)
	await _press(_at, false)
	await _tree.process_frame
	return live


func _win(p: Vector2) -> Vector2:
	return _tree.root.get_final_transform() * p


func _move(to: Vector2, mask: int) -> void:
	var e := InputEventMouseMotion.new()
	e.position = _win(to)
	e.global_position = e.position
	e.relative = _win(to) - _win(_at)
	e.velocity = Vector2.ZERO
	e.button_mask = mask
	_at = to
	_tree.root.push_input(e)
	await _tree.process_frame


func _press(at: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = _win(at)
	e.global_position = e.position
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	_at = at
	_tree.root.push_input(e)
	await _tree.process_frame


# -------------------------------------------------------------------- fixtures

## Put a part of `slot` in the hold and hand it back.
func _stow(slot: ModuleData.Slot) -> ModuleData:
	for i in 40:
		var m := LootGen.roll_module(3 + (i % 5), &"", true)
		if m.slot == slot and Run.place_in_hold(m):
			Sig.ship_changed.emit()
			return m
	return null


func _settle(grid: HoldGrid) -> void:
	grid.refresh()
	for i in 3:
		await _tree.process_frame


func _icon_for(grid: HoldGrid, m: ModuleData) -> Control:
	for c in grid.get_children():
		if c is ModuleIcon and (c as ModuleIcon).module == m:
			return c
	return null


func _centre(c: Control) -> Vector2:
	var r := c.get_global_rect()
	return r.position + r.size * 0.5


## Where a free mount of this kind sits, in screen coordinates, or INF.
func _free_mount(mounts: MountPoints, slot: ModuleData.Slot) -> Vector2:
	return _mount_where(mounts, func(s: Dictionary) -> bool:
		return s.slot == slot and s.held == null)


func _mount_of(mounts: MountPoints, m: ModuleData) -> Vector2:
	return _mount_where(mounts, func(s: Dictionary) -> bool: return s.held == m)


func _mount_where(mounts: MountPoints, want: Callable) -> Vector2:
	for s in mounts.spots():
		if want.call(s):
			return mounts.get_global_rect().position + (s.at as Vector2)
	return Vector2.INF


## The middle of a cell nothing is sitting in.
func _empty_cell(grid: HoldGrid) -> Vector2:
	var g := Run.hold_grid()
	var taken := {}
	for m in Run.cargo:
		if m.hold_at.x < 0:
			continue
		for dy in maxi(1, m.size.y):
			for dx in maxi(1, m.size.x):
				taken[m.hold_at + Vector2i(dx, dy)] = true
	for y in g.y:
		for x in g.x:
			if not taken.has(Vector2i(x, y)):
				return grid.get_global_rect().position \
					+ Vector2((x + 0.5) * (HoldGrid.CELL + HoldGrid.GAP),
						(y + 0.5) * (HoldGrid.CELL + HoldGrid.GAP))
	return grid.get_global_rect().get_center()
