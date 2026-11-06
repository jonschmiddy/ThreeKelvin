extends Node

## A MAC'S SCROLL ZOOMS THE CHART AND THE MAP (issue #36, James, Nov 6: "did you
## remove scrolling to zoom or is my mouse not working?"), headless:
##   godot --headless --fixed-fps 60 --path . -- sheet=ZoomGestureTest
##
## On macOS a trackpad's two-finger scroll and a Magic Mouse's come to Godot as
## InputEventPanGesture, never as WHEEL_UP / WHEEL_DOWN, and a pinch as an
## InputEventMagnifyGesture. The star chart and the system map read only the
## wheel's buttons, so on a Mac without a notched wheel neither zoomed at all.
## Every event here is pushed into the game's own viewport
## (`GameShell.input_target`) at the middle of the picture, so it goes the way a
## hand's does, through whatever lies over it:
##   - the wheel up zooms in and down zooms out, on the chart and on the map
##     (it always did: the check that this test reaches the screen at all);
##   - a scroll gesture up zooms in and down zooms out, the same way round as
##     the wheel, on both;
##   - a pinch out zooms in and a pinch in zooms out, on both;
##   - a sideways scroll alone leaves the zoom where it was.
## Fails on main 42707b66 (the gestures moved nothing) and passes with the fix.

var h := Harness.new()


func _ready() -> void:
	_run.call_deferred()


func _frames(k: int) -> void:
	for i in k:
		await get_tree().process_frame


func _idle() -> void:
	for i in 900:
		if not ZoomLadder.busy() and ZoomLadder.chain == &"":
			return
		await get_tree().process_frame


func _vp() -> Viewport:
	return GameShell.input_target(get_tree())


func _wheel(at: Vector2, idx: MouseButton) -> void:
	for down in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = idx
		ev.pressed = down
		ev.factor = 1.0
		ev.position = at
		ev.global_position = at
		_vp().push_input(ev, true)


func _pan(at: Vector2, d: Vector2) -> void:
	var ev := InputEventPanGesture.new()
	ev.delta = d
	ev.position = at
	_vp().push_input(ev, true)


func _pinch(at: Vector2, f: float) -> void:
	var ev := InputEventMagnifyGesture.new()
	ev.factor = f
	ev.position = at
	_vp().push_input(ev, true)


## The four ways, asked of one screen: `reset` puts its zoom in the middle of
## its range, `read` gives the zoom it is heading for.
func _ways(screen: String, at: Vector2, reset: Callable, read: Callable) -> void:
	var cases := [
		["the wheel up", func() -> void: _wheel(at, MOUSE_BUTTON_WHEEL_UP), 1],
		["the wheel down", func() -> void: _wheel(at, MOUSE_BUTTON_WHEEL_DOWN), -1],
		["a scroll gesture up", func() -> void: _pan(at, Vector2(0, -2.0)), 1],
		["a scroll gesture down", func() -> void: _pan(at, Vector2(0, 2.0)), -1],
		["a pinch out", func() -> void: _pinch(at, 1.25), 1],
		["a pinch in", func() -> void: _pinch(at, 0.8), -1],
		["a sideways scroll", func() -> void: _pan(at, Vector2(3.0, 0)), 0],
	]
	for c: Array in cases:
		reset.call()
		await _frames(2)
		var z0: float = read.call()
		(c[1] as Callable).call()
		await _frames(2)
		var z1: float = read.call()
		var want: int = c[2]
		var moved := 0 if absf(z1 - z0) < 0.0001 else (1 if z1 > z0 else -1)
		h._ok("%s: %s %s (zoom %.3f -> %.3f)" % [screen, c[0],
			["zooms out", "leaves the zoom", "zooms in"][want + 1], z0, z1], moved == want)


func _run() -> void:
	await get_tree().process_frame
	h.seed_run(4242)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	await _frames(10)
	_vp().notification(Node.NOTIFICATION_VP_MOUSE_ENTER)

	Router.show_starchart()
	await _idle()
	await _frames(30)
	var ch := Router.current as StarchartScreen
	h._ok("the chart is up", ch != null)
	if ch != null:
		var chart := ch._chart
		var mid := sqrt(StarchartScreen.MapChart.ZOOM_MIN * StarchartScreen.MapChart.ZOOM_MAX)
		await _ways("the chart", chart.get_global_rect().get_center(),
			func() -> void:
				chart.zoom = mid
				chart.pan = Vector2.ZERO,
			func() -> float: return chart.zoom)

	Router.show_system()
	await _idle()
	var m: SystemMapScreen = null
	for i in 240:
		m = Router.current as SystemMapScreen
		if m != null and m.flight != null and m.view.layout != null:
			break
		await get_tree().process_frame
	await _frames(4)
	h._ok("the map is up", m != null)
	if m != null:
		var mmid := sqrt(m.zoom_min * m.view.ZOOM_MAX)
		await _ways("the map", m._frame.get_global_rect().get_center(),
			func() -> void:
				m._glide = {}
				m._zoom_to = mmid,
			func() -> float: return m._zoom_to)

	_vp().notification(Node.NOTIFICATION_VP_MOUSE_EXIT)
	h.verdict("zoomgesturetest")
	get_tree().quit(h.code())
