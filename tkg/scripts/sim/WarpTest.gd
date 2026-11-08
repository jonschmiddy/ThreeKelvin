extends Harness

## Measures the whole chain from drawn pixel to the game's pointer (Jon). Inverse is a
## cubic, solved by Newton.
## Why: docs/why/WarpTest.md#curved-glass-input

const LOOKS: Array[int] = [DisplaySettings.Look.CRT_GENTLE,
	DisplaySettings.Look.CRT, DisplaySettings.Look.CRT_ARCADE]
## Where to test: the middle, the edges, and the corners the curve moves most.
const AT: Array[Vector2] = [Vector2(0.5, 0.5), Vector2(0.08, 0.08),
	Vector2(0.92, 0.08), Vector2(0.08, 0.92), Vector2(0.92, 0.92),
	Vector2(0.5, 0.06), Vector2(0.06, 0.5), Vector2(0.94, 0.5), Vector2(0.5, 0.94)]
## One pixel bound: the rect nudges by whole game pixels, so up to 0.71 on the diagonal
## plus curvature.
## Why: docs/why/WarpTest.md#error-bound
const WANT := 1.0

var _tree: SceneTree
var _probe: Probe = null


func run(tree: SceneTree) -> void:
	_tree = tree
	var shell := GameShell.instance
	if not _ok("the game is running inside the shell", shell != null):
		return _finish()
	_probe = Probe.new()
	shell.view.add_child(_probe)
	await tree.process_frame
	await tree.process_frame

	for look in LOOKS:
		DisplaySettings.screen_look = look as DisplaySettings.Look
		GameShell.refresh()
		await tree.process_frame
		var worst := 0.0
		var worst_at := Vector2.ZERO
		var lost := 0
		for a in AT:
			var want := a * Vector2(GameShell.BASE)
			var win := _window_for(shell, want)
			if win == Vector2(-1, -1):
				lost += 1
				continue
			var got := _land(shell, win)
			# The landed point is the middle of a game pixel, so the test is
			# whether it is the RIGHT pixel: same floor as the target.
			var err := (got - (want.floor() + Vector2(0.5, 0.5))).length()
			if err > worst:
				worst = err
				worst_at = a
		_ok("%s: a click lands within %.2f game px (worst at %.0f%%, %.0f%%)"
				% [DisplaySettings.look_name(look as DisplaySettings.Look), worst,
					worst_at.x * 100.0, worst_at.y * 100.0],
				lost == 0 and worst <= WANT)
		# The glass stays put: the input rect slides, the picture and tube edge must not (Jon).
		shell._pointer = shell._home + Vector2(4, 4)
		shell._nudge()
		_ok("%s: the glass holds still with the pointer in a corner (input moved %s)"
				% [DisplaySettings.look_name(look as DisplaySettings.Look),
					shell.frame_rect().position - shell._home],
				shell._glass.position == shell._home and shell._glass.size == shell.frame_rect().size)
	# Hover cannot be seen: pushed events leave it null and the real pointer cannot be moved.
	# Judged by hand.
	# Why: docs/why/WarpTest.md#hover-limits

	DisplaySettings.screen_look = DisplaySettings.Look.CRT_GENTLE
	GameShell.refresh()
	_probe.queue_free()
	_finish()


func _finish() -> void:
	verdict("warptest")
	_tree.quit(code())


## Which window pixel shows the game point `want`. Newton against the bend.
func _window_for(shell: GameShell, want: Vector2) -> Vector2:
	var rect := Rect2(shell._home, shell.frame_rect().size)
	var p := rect.position + want / Vector2(GameShell.BASE) * rect.size
	for _i in 6:
		var err := shell._bend_at(p, shell._home) - want
		if err.length() < 0.01:
			return p
		# The bend is close to linear over a pixel, so step by the error scaled
		# into window space and go round again.
		p -= err / Vector2(GameShell.BASE) * rect.size
	return p if (shell._bend_at(p, shell._home) - want).length() < 0.5 else Vector2(-1, -1)


## Asks a control in the game, not `get_mouse_position()`: that ignores pushed events and
## read 1100px off.
## Why: docs/why/WarpTest.md#landing-probe
func _land(shell: GameShell, win: Vector2) -> Vector2:
	# Pretends the pointer, as a harness has none, so the engine's own path runs and the
	# highlight is measured too.
	shell._pointer = win
	shell._nudge()
	var e := InputEventMouseMotion.new()
	e.position = win
	e.global_position = win
	_probe.seen = Vector2(-1, -1)
	_tree.root.push_input(e, true)
	return _probe.seen


## A sheet over the game that writes down where it was touched. Full rect at the
## origin, so its local coordinates ARE the game's.
class Probe extends Control:
	var seen: Vector2 = Vector2(-1, -1)

	func _init() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _gui_input(event: InputEvent) -> void:
		var m := event as InputEventMouseMotion
		if m != null:
			seen = m.position
