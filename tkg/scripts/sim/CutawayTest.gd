extends Harness

## THE CUTAWAY'S MOVES, through the cutaway's own handlers, headless:
##   godot --headless --path . -- cutawaytest
##
## `CutawayView` moves parts with Run's rule (`lift_part`, `fit_at_mount`,
## `stow_at`) and claims loot with the calls SECTOR LOOT makes (`take_item`,
## `take_from_jetsam`), so the refit screen, the map's loot popup and the
## cutaway cannot disagree. This drives the view's own drop handlers -- what a
## real drag ends in -- and checks both the model AND what the view draws (its
## hold's icons, its loot grids), because a model that moved and a screen that
## did not is the bug the transfer screen had three times.

var _tree: SceneTree
var _cut: CutawayView
var _node: MapGen.MapNode


func run(tree: SceneTree) -> void:
	_tree = tree
	await tree.process_frame
	Rng.reseed(4242, 0)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	_node = Run.node_at()
	_node.jetsam.clear()
	_node.taken.clear()
	Run.cargo.clear()

	var host := Control.new()
	host.size = Vector2(960, 518)
	tree.root.add_child(host)
	_cut = CutawayView.open_over(host, null)
	for i in 4:
		await tree.process_frame
	_ok("the cutaway opens without LOCAL's hull (headless, reduced)", _cut != null and is_instance_valid(_cut))
	_ok("and picks a push-in scale (%dx)" % _cut.k, _cut.k == 1 or _cut.k == 2)

	# a weapon mount with something on it, and a spare weapon in the hold
	var w := ModuleData.Slot.WEAPON
	var on: ModuleData = null
	var at_mount := -1
	for i in Run.slots_for(w):
		if Run.module_at(w, i) != null:
			on = Run.module_at(w, i)
			at_mount = i
			break
	if not _ok("the ship has a gun fitted", on != null):
		return _finish()
	var spare := _module_of(w)
	_ok("a spare gun goes in the hold", Run.place_in_hold(spare))
	await _settle()
	_ok("the shelf draws it (%d icon)" % _icons(_cut._hold), _icons(_cut._hold) == Run.cargo.size())

	# 1. hold -> occupied mount: the spare is fitted, the resident goes to the hold
	await _cut._on_mount_drop({module = spare, origin = &"cargo"}, w, at_mount)
	await _settle()
	_ok("a part from the hold onto an occupied mount is fitted there",
		Run.module_at(w, at_mount) == spare)
	_ok("and the part it displaced is in the hold", Run.cargo.has(on) and not Run.installed.has(on))
	_ok("and the shelf draws the hold as it is (%d icons, %d in cargo)" % [_icons(_cut._hold), Run.cargo.size()],
		_icons(_cut._hold) == Run.cargo.size())

	# 2. a lift that never lands goes back where it was
	var mount_was := spare.mount
	_cut._on_lift(spare)
	_ok("lifting takes it off the ship", not Run.installed.has(spare))
	_cut._on_release()
	_ok("a lift that never landed puts it back on its mount",
		Run.installed.has(spare) and spare.mount == mount_was)

	# 3. lifted onto another occupied mount of its kind: the two trade
	var other := -1
	for i in Run.slots_for(w):
		if i != spare.mount and Run.module_at(w, i) != null:
			other = i
			break
	if other >= 0:
		var there := Run.module_at(w, other)
		var from := spare.mount
		_cut._on_lift(spare)
		await _cut._on_mount_drop({module = spare, origin = &"hull"}, w, other)
		_ok("a fitted part moved onto another fitted one trades places",
			Run.module_at(w, other) == spare and Run.module_at(w, from) == there)
	else:
		print("  --   (one weapon mount fitted: the trade is not exercised)")

	# 4. off the ship into the hold
	var cell := _free_cell(spare)
	_cut._on_lift(spare)
	await _cut._on_hold_drop({module = spare, origin = &"hull"}, cell)
	await _settle()
	_ok("a fitted part dropped on the hold is stored there",
		Run.cargo.has(spare) and not Run.installed.has(spare) and spare.mount == -1)
	_ok("and the shelf draws it (%d icons)" % _icons(_cut._hold), _icons(_cut._hold) == Run.cargo.size())

	# 5. this system's loot: into the hold, the same claim SECTOR LOOT makes
	var pile := Run.sector_jetsam(_node, true)
	var loose := MaterialData.of(MaterialTable.all()[0])
	pile.items.append(loose)
	_cut._refresh()
	await _settle()
	_ok("the shelf draws this system's loot (%d)" % _icons(_cut._loot_grid), _icons(_cut._loot_grid) == 1)
	await _cut._on_hold_drop({module = loose, origin = &"bag"}, _free_cell(loose))
	await _settle()
	_ok("loot dragged to the hold is taken", Run.cargo.has(loose))
	_ok("and claimed, so SECTOR LOOT shows it gone (%d left)" % Run.jetsam_left(_node, pile),
		Run.jetsam_left(_node, pile) == 0)
	_ok("and the shelf stops drawing it (%d)" % _icons(_cut._loot_grid), _icons(_cut._loot_grid) == 0)
	_ok("and says so when the pile is empty", _cut._loot_empty.visible)

	# 6. a wreck's gun straight onto an empty mount
	var wreck := Run.new_wreck(_node, DB.enemies[&"cutter"])
	var prize := _module_of(w)
	wreck.items.append(prize)
	wreck.items.append(MaterialData.of(MaterialTable.all()[1]))
	_cut._refresh()
	var empty := -1
	for i in Run.slots_for(w):
		if Run.module_at(w, i) == null:
			empty = i
			break
	await _settle()
	_ok("the shelf draws the wreck's bay (%d)" % _icons(_cut._wreck_grid), _icons(_cut._wreck_grid) == 2)
	if empty >= 0:
		await _cut._on_mount_drop({module = prize, origin = &"bag"}, w, empty)
		await _settle()
		_ok("a wreck's part dropped on an empty mount is fitted", Run.module_at(w, empty) == prize)
		_ok("and claimed out of the wreck", Run.jetsam_left(_node, wreck) == 1)

	# 7. TAKE ALL
	await _cut._take_all(wreck)
	await _settle()
	_ok("TAKE ALL empties the wreck into the hold", Run.jetsam_left(_node, wreck) == 0)
	_ok("and the bay is drawn empty (%d)" % _icons(_cut._wreck_grid), _icons(_cut._wreck_grid) == 0)

	# 8. a full hold refuses a swap BEFORE anything moves
	var fill := 0
	while fill < 40:
		fill += 1
		var junk := MaterialData.of(MaterialTable.all()[0])
		if not Run.place_in_hold(junk):
			break
	var big := _module_of(w, Vector2i(3, 1))
	var resident: ModuleData = null
	var rm := -1
	for i in Run.slots_for(w):
		if Run.module_at(w, i) != null:
			resident = Run.module_at(w, i)
			rm = i
			break
	if big != null and resident != null:
		var before_fit := Run.installed.duplicate()
		var before_hold := Run.cargo.duplicate()
		big.hold_at = -Vector2i.ONE
		# from nowhere (a part not in the hold) onto an occupied mount, hold full
		await _cut._on_mount_drop({module = big, origin = &"cargo"}, w, rm)
		_ok("a full hold refuses the swap and nothing moves",
			Run.installed == before_fit and Run.cargo == before_hold and Run.module_at(w, rm) == resident)

	# 9. closing puts nothing in limbo
	var n_before := Run.installed.size() + Run.cargo.size()
	_cut._on_lift(Run.installed[0])
	_cut.close()
	for i in 3:
		await tree.process_frame
	_ok("closing with a part in hand puts it back (%d -> %d)" % [n_before, Run.installed.size() + Run.cargo.size()],
		Run.installed.size() + Run.cargo.size() == n_before)
	_finish()


func _finish() -> void:
	verdict("cutawaytest")
	_tree.quit(code())


func _settle() -> void:
	for i in 2:
		await _tree.process_frame


func _icons(g: Control) -> int:
	var n := 0
	for c in g.get_children():
		if c is ItemIcon and (c as Control).visible:
			n += 1
	return n


func _free_cell(m: HoldItem) -> Vector2i:
	var g := Run.hold_grid()
	for y in g.y:
		for x in g.x:
			if Run.can_place(m, Vector2i(x, y)):
				return Vector2i(x, y)
	return -Vector2i.ONE


## A module of this slot from the catalogue (of this size, if asked), a copy.
func _module_of(s: ModuleData.Slot, want: Vector2i = Vector2i.ZERO) -> ModuleData:
	for id in DB.modules:
		var m: ModuleData = DB.modules[id]
		if m.slot != s or m.starter_only:
			continue
		if want != Vector2i.ZERO and m.size != want:
			continue
		return m.duplicate(true) as ModuleData
	return null
