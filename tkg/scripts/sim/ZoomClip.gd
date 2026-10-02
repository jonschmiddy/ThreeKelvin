extends Node

## The sector map's camera, played as a player would and filmed with its sound:
##   godot --path . --write-movie <out.avi> --fixed-fps 30 -- sheet=ZoomClip [seed=N]
## Starts a run on the real shell and router, then on a fixed timeline: the
## cursor sweeps the map (the scan blips), the wheel zooms in over a world (the
## ticks), a drag pans, LOCATION zooms onto the ship, a beacon is opened (the
## ship flies, the panel opens), and the wheel zooms back out. Quits at the end.
## `--fixed-fps` makes every frame one thirtieth of a second, so the film runs
## at true speed however slowly the frames are saved.

const END := 23.0

var _t := 0.0
var _scr
var _steps: Array = []


func _ready() -> void:
	Rng.forced = 4242
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with("seed="):
			Rng.forced = int((a as String).substr(5))
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	# to the first ordinary system with a few beacons, through the arrival path
	for raw in Run.map:
		var m: MapGen.MapNode = raw
		if m.index != Run.at and Run.can_jump_to(m) and m.type == MapGen.NodeType.SYSTEM:
			Router.commit_jump(m.index)
			break


func _process(delta: float) -> void:
	_t += delta
	if _scr == null:
		if Router.current is SystemMapScreen and Router.current.view.layout != null:
			_scr = Router.current
			_plan()
		return
	while not _steps.is_empty() and _t >= float(_steps[0][0]):
		var s: Array = _steps.pop_front()
		(s[1] as Callable).call()
	if _t >= END:
		get_tree().quit()


## Frame coordinates of a map point.
func _f(map_p: Vector2) -> Vector2:
	return map_p + _scr._box.position


func _move(p: Vector2, rel: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = p
	e.relative = rel
	_scr._on_map_input(e)


func _button(b: MouseButton, p: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = b
	e.pressed = down
	e.position = p
	_scr._on_map_input(e)


func _plan() -> void:
	var v = _scr.view
	var world := -1
	for i in v.layout.bodies.size():
		if v.layout.bodies[i].world != &"":
			world = i
			break
	var frame: Vector2 = _scr._frame.size
	# 1.5 to 4.5 s: the cursor sweeps from the left edge to the world
	var from := Vector2(40, frame.y * 0.7)
	for k in 90:
		var u := float(k) / 89.0
		var at := 1.5 + u * 3.0
		_steps.append([at, func() -> void:
			var to: Vector2 = _f(v.at[world]) if world >= 0 else frame / 2.0
			var p := from.lerp(to, u * u * (3.0 - 2.0 * u))
			_move(p, Vector2(6, -2))])
	# 5 to 6.6 s: eight notches in over the world
	for k in 8:
		_steps.append([5.0 + k * 0.2, func() -> void:
			var p: Vector2 = _f(v.at[world]) if world >= 0 else frame / 2.0
			_button(MOUSE_BUTTON_WHEEL_UP, p, true)])
	# 7.5 to 12 s: a slow drag right across the frame and back, to show the
	# sky's three depths sliding at their own speeds
	var a0 := Vector2(frame.x * 0.2, frame.y * 0.55)
	var a1 := Vector2(frame.x * 0.85, frame.y * 0.45)
	_steps.append([7.5, func() -> void: _button(MOUSE_BUTTON_LEFT, a0, true)])
	for k in 135:
		var u := float(k + 1) / 135.0
		var w := sin(u * PI)
		_steps.append([7.5 + u * 4.5, func() -> void:
			_move(a0.lerp(a1, w), Vector2(4, -1))])
	_steps.append([12.05, func() -> void: _button(MOUSE_BUTTON_LEFT, a0, false)])
	# 13 s: LOCATION, onto the ship
	_steps.append([13.0, func() -> void: _scr._on_location()])
	# 15.5 s: open the first beacon; the ship flies and the panel opens
	_steps.append([15.5, func() -> void:
		for bi in v.layout.bodies.size():
			for bc in v.layout.bodies[bi].beacons:
				if bc.opt >= 0:
					_scr.open_beacon(bi, bc)
					return])
	# 19 s: let go of LOCATION, which glides back out to the whole sector
	_steps.append([19.0, func() -> void:
		if _scr._location_on:
			_scr._on_location()])
