extends Harness

## Leaving a run from the pause menu, driven through the real screens:
##   godot --headless --path . -- quittest
##
## QUIT and SAVE & QUIT both end the same way -- `Run.hull = null`, then
## `Router.show_launcher()` -- and the screen they leave is only QUEUED for
## freeing, so it is still in the tree for the rest of that frame. Anything that
## redraws it there draws a run with no ship in it. On the starchart that is
## every reachable system asking how far this ship can jump: hundreds of
## "Invalid access to property 'thrust' on Nil" in one frame, and nothing wrong
## to look at, because the frame is never shown.
##
## The two lines are run here rather than the pause menu's signals emitted. The
## real QUIT handler also writes an ABANDONED run into the flight record, and a
## test has no business putting runs in a player's history.

var _tree: SceneTree
## Every draw of the starchart's chart, and the ones made with no ship.
var _draws := 0
var _blind := 0


func run(tree: SceneTree) -> void:
	_tree = tree
	await tree.process_frame

	Rng.reseed(4471, 0)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Router.show_starchart()
	# WAIT FOR THE CHART, DO NOT COUNT FRAMES AT IT. This was `for i in 3`, and
	# three frames is usually enough for the screen to build and usually is not a
	# test: it passed seven runs in a row and failed the eighth on the same
	# build. A bounded wait on the thing actually being looked for is the same
	# check without the race.
	var chart: StarchartScreen.MapChart = null
	for i in 60:
		chart = first(Router.current, _is_chart) as StarchartScreen.MapChart
		if chart != null:
			break
		await tree.process_frame
	if not _ok("the starchart is up with its systems showing",
			chart != null and chart.show_icons):
		await _finish()
		return

	# PROVE A DRAW CAN BE SEEN FIRST. A headless run that never drew would pass
	# the real assertion below by counting nothing, which is the failure this
	# project keeps finding in checks that measured an empty state.
	chart.draw.connect(_on_draw)
	chart.queue_redraw()
	await tree.process_frame
	await tree.process_frame
	if not _ok("and it draws in this harness, so a draw after leaving would show",
			_draws > 0):
		await _finish()
		return

	# What QUIT and SAVE & QUIT both do, in their order.
	Run.hull = null
	Router.show_launcher()
	for i in 6:
		await tree.process_frame
	_ok("the title screen is up", Router.current is LauncherScreen)
	_ok("and the chart left behind never drew without a ship", _blind == 0)
	await _finish()


func _on_draw() -> void:
	_draws += 1
	if Run.hull == null:
		_blind += 1


func _is_chart(n: Node) -> bool:
	return n is StarchartScreen.MapChart


## Print the verdict and end the process, torn down first for the reason
## `StowTest._finish` records: a headless run that quits holding a live Control
## tree is reported as leaking, and the gate reads that as script errors.
func _finish() -> void:
	if Router.current != null:
		var last := Router.current
		Router.current = null
		last.get_parent().remove_child(last)
		last.free()
	await _tree.process_frame
	print("")
	verdict("quittest")
	_tree.quit(code())
