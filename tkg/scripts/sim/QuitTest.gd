extends Harness

## The left screen is only queued for freeing, so redrawing it drew a run with no ship.
## Runs the two lines, not the handler, which writes an ABANDONED run to the history.
## Why: docs/why/QuitTest.md#quit-test

var _tree: SceneTree
## Every draw of the starchart's chart, and the ones made with no ship.
var _draws := 0
var _blind := 0


func run(tree: SceneTree) -> void:
	_tree = tree
	await tree.process_frame

	seed_run(4471)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Router.show_starchart()
	# Wait for the chart, do not count frames: `for i
	# in 3` passed seven runs and failed the eighth.
	# Why: docs/why/QuitTest.md#quit-test-waits
	var chart: StarchartScreen.MapChart = null
	var until := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < until:
		chart = null
		if Router.current is StarchartScreen:
			chart = first(Router.current, _is_chart) as StarchartScreen.MapChart
		if chart != null:
			break
		await tree.process_frame
	if not _ok("the starchart is up with its systems showing",
			chart != null and chart.show_icons):
		await _finish()
		return

	# Prove a draw can be seen first: a headless run
	# that never drew would pass by counting nothing.
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


## Tear down first, as `StowTest._finish` records: a
## headless quit with a live Control tree reads as leaking.
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
