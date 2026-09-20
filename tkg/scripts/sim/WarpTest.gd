extends Harness

## A click through the curved glass lands where the picture says it does:
##   godot --path . -- warptest
##
## NEEDS A WINDOW, because it is about the window. The shader bends the picture
## per screen pixel and the container that feeds input to the game knows nothing
## about that, so `GameShell` bends the pointer the same way before anything
## sees it. Jon found the fault by hand -- "the buttons in the far corners are
## hard to hit" on CRT+ and the arcade cabinet -- and then found the fix was not
## finished: "the button localization is better.... but it's not pixel perfect."
##
## So this measures the WHOLE chain rather than my arithmetic: it takes a point
## in the game, works out which window pixel that point is drawn at, pushes a
## real mouse motion there, and asks the game where it thinks the mouse is. The
## error is the answer, in game pixels, and the picture is only honest if it is
## under one.
##
## WHY THE INVERSE IS ITERATED. The bend has a closed form one way only: given a
## screen point, which game pixel is drawn there. Going back the other way is a
## cubic, so this walks Newton's method over it -- five passes is plenty at
## these curvatures, and the harness asserts the walk converged rather than
## trusting it.

const LOOKS: Array[int] = [DisplaySettings.Look.CRT_GENTLE,
	DisplaySettings.Look.CRT, DisplaySettings.Look.CRT_ARCADE]
## Where to test: the middle, the edges, and the corners the curve moves most.
const AT: Array[Vector2] = [Vector2(0.5, 0.5), Vector2(0.08, 0.08),
	Vector2(0.92, 0.08), Vector2(0.08, 0.92), Vector2(0.92, 0.92),
	Vector2(0.5, 0.06), Vector2(0.06, 0.5), Vector2(0.94, 0.5), Vector2(0.5, 0.94)]
## HOW CLOSE IS CLOSE ENOUGH, and the number follows the mechanism rather than
## the other way round. The rect is nudged by WHOLE GAME PIXELS -- a fractional
## nudge changes which texel each screen pixel samples and makes the picture
## crawl as the mouse moves -- so the pointer can sit up to half a pixel from
## where the bend wants it in each axis. That is 0.71 on the diagonal, plus a
## little for the bend's own curvature inside one pixel. One pixel is the
## honest bound; asking for less would be asking the quantisation not to exist.
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
	# WHAT THIS CANNOT SEE, and two attempts are the evidence rather than an
	# excuse. Which control is HOVERED does not follow input events: pushed ones
	# leave `gui_get_hovered_control()` null even after the engine's own
	# `notify_mouse_entered`, and while the SubViewportContainer is delivering,
	# hover comes from the real pointer, which a harness cannot move -- warping
	# it is ignored without window focus and moving it for real would be moving
	# Jon's mouse. So the corner feel is judged by hand, with `-- mt=0` to
	# compare against how it was.

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


## Push a real motion at that window pixel and ask THE GAME where it landed.
##
## Not `Viewport.get_mouse_position()`: that reports the operating system's
## pointer mapped into the viewport and is not moved by a pushed event at all --
## it answered with the same number for every probe, which is how this test
## first "measured" an error of eleven hundred pixels. A control inside the game
## receiving the event is the only witness that proves the whole chain.
func _land(shell: GameShell, win: Vector2) -> Vector2:
	# THE POINTER IS PRETENDED, because a harness has no real one and the whole
	# mechanism is keyed to where the real one is. Everything after this is the
	# engine's own path: the container's transform, its own GUI picking, its own
	# hover -- which is the point. One transform now drives all of it, so
	# measuring the click measures the highlight too.
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
