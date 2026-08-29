extends Harness

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


func run(tree: SceneTree) -> void:
	_tree = tree
	await tree.process_frame

	Rng.reseed(8899, 0)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	# TWO PARTS LOOSE IN THE SYSTEM, which is how loot arrives now. They used
	# to be stowed straight into the hold and the rail opened because the hold
	# was not empty -- but the rail no longer reports what you are carrying,
	# only what is out there and unclaimed. The dismissal rule this test guards
	# is unchanged; what opens the rail is not.
	# A HULL ON OFFER, which is what this rail is now for. It has been three
	# things across this file's life -- your cargo, then loose salvage, now an
	# offer -- and each time the DISMISSAL RULE it guards was unchanged and what
	# opened the panel was not. That rule has been got wrong three times; the
	# trigger is incidental.
	Run.found_hull = DB.hull_frames[0]

	Router.show_sector()
	await tree.process_frame
	var rail := _rail()
	if not _ok("the rail opens with a hull on offer", rail != null and rail.visible):
		return _finish()

	# Press the real button rather than setting the flag by hand. The handler is
	# what a player touches and the handler is what was wrong the first time.
	# "DECIDE LATER", not "STOW". The verb was dropped because the button does
	# not move anything -- it hushes the rail -- and "STOW" was only ever true
	# while everything the rail listed was already in the hold. A bag is not:
	# loose salvage sits in the system, so pressing STOW on one put the panel
	# away and left the parts on the floor. The rule this test guards is
	# unchanged; only the word is.
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
	Router.show_sector()
	await tree.process_frame
	_ok("and it is STILL shut on the next screen", not _rail_visible())
	_ok("without anything having been added to the hold",
		Run.hauls == hauls_before)
	# THE SALVAGE IS STILL WHERE IT WAS. It was never in the hold -- it is loose
	# in the system you left, and dismissing a rail must not have quietly taken
	# it, dropped it, or claimed it on your behalf.
	_ok("and the offer is still standing", Run.found_hull != null)

	# New loot must bring it back, or the fix has traded one silence for another.
	# A BAG AT A SYSTEM YOU HAVE NOT STOOD OVER, which is the case the rule is
	# actually written around -- `salvage_hushed` keys the dismissal to a node,
	# so arriving somewhere new with something loose in it has to speak up.
	# A fresh haul is what un-hushes it, so the count has to move.
	Run.stow(LootGen.roll_module(4))
	Router.show_sector()
	await tree.process_frame
	_ok("a fresh haul opens it again", _rail_visible())

	# AND NOTHING ON THIS RAIL MAY EMPTY THE HOLD.
	#
	# This assertion used to read the other way round: it required a JETTISON
	# button and required it to leave `Run.cargo` empty. That button called
	# `Run.cargo.clear()` -- one press, everything you were carrying, gone --
	# and its own tooltip admitted "there is no reason to do this".
	#
	# `MATERIALS_NOTE` 3.4 rules it out: nothing of yours is destroyed for you.
	# Jettison now means one thing, overboard into this system's bag and
	# recoverable until you jump, done one item at a time by right-clicking it.
	#
	# So the test is inverted rather than deleted. A deleted assertion protects
	# nothing; this one keeps the trap from being rebuilt, and would have failed
	# on the day it was first written.
	# SOMETHING IN THE HOLD TO BE UNTOUCHED. Nothing is stowed by this test any
	# more -- the salvage stays loose in the system -- so without this the claim
	# "the hold is untouched" would be made about an empty hold, which is the
	# case that cannot fail.
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
	verdict("stowtest")
	_tree.quit(code())


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
	return first(n, func(x: Node) -> bool:
		return x is Button and (x as Button).text.begins_with(starts_with)) as Button


## Any system that is not the one we are standing in.
func _somewhere_else() -> int:
	for i in Run.map.size():
		if i != Run.at:
			return i
	return -1
