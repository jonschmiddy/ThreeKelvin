extends Harness

## The dismissal rule was wrong three times; only driving the real screen catches a rebuild.
## Why: docs/why/StowTest.md#dismissal-rule

var _tree: SceneTree


func run(tree: SceneTree) -> void:
	_tree = tree
	await tree.process_frame

	seed_run(8899)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	# What opens the rail changed three times; the dismissal rule this test guards did not.
	# Why: docs/why/StowTest.md#rail-trigger
	Run.found_hull = DB.hull_frames[0]

	Router.show_local()
	await tree.process_frame
	var rail := _rail()
	if not _ok("the rail opens with a hull on offer", rail != null and rail.visible):
		return _finish()

	# The button reads DECIDE LATER since it only hushes the rail; STOW left parts on the floor.
	# Why: docs/why/StowTest.md#rail-button
	var stow := _button("DECIDE LATER")
	if not _ok("and it has a DECIDE LATER button", stow != null):
		return _finish()
	stow.pressed.emit()
	await tree.process_frame
	_ok("pressing DECIDE LATER shuts it", not _rail_visible())

	# THE JUMP. Router builds a whole new SectorScreen here, which is the step
	# that defeated the first fix.
	var to := _somewhere_else()
	if not _ok("there is somewhere to jump to", to >= 0):
		return _finish()
	var hauls_before := Run.hauls
	Run.at = to
	Router.show_local()
	await tree.process_frame
	_ok("and it is STILL shut on the next screen", not _rail_visible())
	_ok("without anything having been added to the hold",
		Run.hauls == hauls_before)
	# The salvage is loose in the system; dismissing the rail must not take or claim it.
	_ok("and the offer is still standing", Run.found_hull != null)

	# `salvage_hushed` keys to a node, so a new system with loose loot must speak up.
	Run.stow(LootGen.roll_module(4))
	Router.show_local()
	await tree.process_frame
	_ok("a fresh haul opens it again", _rail_visible())

	# No rail button may empty the hold: `MATERIALS_NOTE` 3.4 forbids destroying a player's things.
	# Why: docs/why/StowTest.md#no-emptying-hold
	Run.stow(LootGen.roll_module(3))
	var before := Run.cargo.size()
	_ok("nothing on the rail is spelled JETTISON", _button("JETTISON") == null)
	var wipes: Button = null
	for b in [_button("DUMP"), _button("DESTROY"), _button("EMPTY")]:
		if b != null:
			wipes = b
	_ok("and nothing else offers to empty the hold", wipes == null)
	_ok("so the hold is untouched by looking at it",
		Run.cargo.size() == before and before > 0)

	# The same rule on the system map, where arrival now lands and the panel rebuilds each visit.
	seed_run(8899)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Run.found_hull = DB.hull_frames[0]
	Router.show_sector()
	await _map_ready()
	_ok("arriving lands on the system map", Router.current is SystemMapScreen)
	var later := _find_button(Router.current, "DECIDE LATER")
	_ok("the map's panel offers the hull", later != null)
	if later != null:
		later.pressed.emit()
		await tree.process_frame
		_ok("pressing DECIDE LATER there shuts it",
			_find_button(Router.current, "DECIDE LATER") == null)
		var to2 := _somewhere_else()
		Run.at = to2
		Router.show_sector()
		await _map_ready()
		_ok("and it is STILL shut on the next system's map",
			_find_button(Router.current, "DECIDE LATER") == null)
		_ok("with the offer still standing", Run.found_hull != null)

	_finish()


## The map fills its panel once the system is shown, which is a frame or two.
func _map_ready() -> void:
	for _i in 4:
		await _tree.process_frame


## Every exit goes through `_finish`, or a failed guard would hang until the gate's watchdog.
## Why: docs/why/StowTest.md#test-exit
func _finish() -> void:
	# Tear down with `free()` before quitting, or leftover Controls fail the gate as script errors.
	# Why: docs/why/StowTest.md#test-teardown
	if Router.current != null:
		var last := Router.current
		Router.current = null
		last.get_parent().remove_child(last)
		last.free()
	await _tree.process_frame
	print("")
	verdict("stowtest")
	_tree.quit(code())


## Found by walking the tree, as the screen is a different object after a jump.
func _rail() -> Control:
	var s := Router.current as SectorScreen
	if s == null:
		return null
	return s._salvage_wrap


## False with no rail rather than a crash, as a non-SectorScreen makes `_rail()` null.
func _rail_visible() -> bool:
	var r := _rail()
	return r != null and r.visible


func _button(starts_with: String) -> Button:
	var s := Router.current as SectorScreen
	if s == null:
		return null
	return _find_button(s, starts_with)


func _find_button(n: Node, starts_with: String) -> Button:
	return first(n, func(x: Node) -> bool:
		return x is Button and (x as Button).text.begins_with(starts_with)) as Button


## Any system that is not the one we are standing in.
func _somewhere_else() -> int:
	for i in Run.map.size():
		if i != Run.at:
			return i
	return -1
