extends RefCounted

## The salvage rail, driven through the real screen:
##   godot --headless --path . -- stowtest
##
## THIS IS THE TEST THAT SHOULD HAVE EXISTED FIRST. The dismissal rule has been
## got wrong three times and every one of them was invisible to the assertions
## that existed:
##
##   1. the flag lived on `SectorScreen`, which `Router` REBUILDS ON EVERY JUMP,
##      so stowing was forgotten the moment you left the system;
##   2. moved to `Run`, it asked whether the state MATCHED the dismissal, so
##      walking away from a loot bag re-opened the rail;
##   3. it compared haul counts with `>`, which fails shut when `hauls` resets.
##
## Unit assertions on `Run.salvage_hushed()` catch (2) and (3) and CANNOT catch
## (1), because (1) is not about the rule — it is about which object holds it and
## how long that object lives. Only building the screen, pressing its button,
## jumping, and letting Router build a NEW screen can see that.
##
## So this drives the real thing: the real rail, the real STOW button, the real
## jump, the real rebuild.

var _tree: SceneTree
var _fails: int = 0


func run(tree: SceneTree) -> void:
	_tree = tree
	await tree.process_frame

	Rng.reseed(8899, 0)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	# Two parts in the hold, arriving the way loot actually arrives.
	Run.stow(LootGen.roll_module(3))
	Run.stow(LootGen.roll_module(3))

	Router.show_sector()
	await tree.process_frame
	var rail := _rail()
	if not _ok("the rail opens with salvage aboard", rail != null and rail.visible):
		return _finish()

	# Press the real button rather than setting the flag by hand. The handler is
	# what a player touches and the handler is what was wrong the first time.
	var stow := _button("STOW")
	if not _ok("and it has a STOW button", stow != null):
		return _finish()
	stow.pressed.emit()
	await tree.process_frame
	_ok("pressing STOW shuts it", not _rail_visible())

	# THE JUMP. Router builds a whole new SectorScreen here, which is the step
	# that defeated the first fix.
	var to := _somewhere_else()
	if not _ok("there is somewhere to jump to", to >= 0):
		return _finish()
	var hauls_before := Run.hauls
	Run.at = to
	Router.show_sector()
	await tree.process_frame
	_ok("and it is STILL shut on the next screen", not _rail_visible())
	_ok("without anything having been added to the hold",
		Run.hauls == hauls_before)
	_ok("and the hold still holds it", Run.cargo.size() == 2)

	# New loot must bring it back, or the fix has traded one silence for another.
	Run.stow(LootGen.roll_module(4))
	Router.show_sector()
	await tree.process_frame
	_ok("a fresh haul opens it again", _rail_visible())

	# And JETTISON has to actually empty the hold and close the rail.
	var dump := _button("JETTISON")
	if _ok("there is a JETTISON button", dump != null):
		dump.pressed.emit()
		await tree.process_frame
		_ok("jettison empties the hold", Run.cargo.is_empty())
		_ok("and closes the rail behind it", not _rail_visible())

	_finish()


## Print the verdict and end the process. EVERY EXIT GOES THROUGH HERE.
##
## The guarded assertions above used to `return` on failure, and nothing else
## ends the tree — `Main._ready()` has already returned by then. So renaming the
## STOW button would not have failed this test, it would have HUNG it: no
## verdict line, no failing assertion, just the gate's 120-second watchdog
## reporting "still running, killed". A test whose failure mode is a timeout
## tells you less than no test at all.
func _finish() -> void:
	# TORN DOWN BEFORE QUITTING, and the merge gate is why. This is the only
	# headless test that builds real screens, so it is the only one that can quit
	# holding a live Control tree — and Godot reports the leftovers as
	# "resources still in use at exit", which the gate reads as script errors and
	# fails the build on. `free()` rather than `queue_free()`: a deferred free
	# does not run before the tree quits.
	if Router.current != null:
		var last := Router.current
		Router.current = null
		last.get_parent().remove_child(last)
		last.free()
	await _tree.process_frame
	print("")
	print("stowtest: %s" % ("PASS" if _fails == 0 else "%d FAILURES" % _fails))
	_tree.quit(1 if _fails > 0 else 0)


## The salvage panel on whatever sector screen is currently up. Found by walking
## the tree rather than held, because the whole point is that the screen is a
## different object after a jump.
func _rail() -> Control:
	var s := Router.current as SectorScreen
	if s == null:
		return null
	return s._salvage_wrap


## Whether the rail is up. FALSE when there is no rail at all, rather than a
## crash: a screen that is not a SectorScreen turns `_rail()` null, and
## dereferencing that would report a script error where the test has a perfectly
## good verdict to give.
func _rail_visible() -> bool:
	var r := _rail()
	return r != null and r.visible


func _button(starts_with: String) -> Button:
	var s := Router.current as SectorScreen
	if s == null:
		return null
	return _find_button(s, starts_with)


func _find_button(n: Node, starts_with: String) -> Button:
	var b := n as Button
	if b != null and b.text.begins_with(starts_with):
		return b
	for child in n.get_children():
		var found := _find_button(child, starts_with)
		if found != null:
			return found
	return null


## Any system that is not the one we are standing in.
func _somewhere_else() -> int:
	for i in Run.map.size():
		if i != Run.at:
			return i
	return -1


func _ok(what: String, condition: bool) -> bool:
	if condition:
		print("  ok   %s" % what)
	else:
		print("  FAIL %s" % what)
		_fails += 1
	return condition
