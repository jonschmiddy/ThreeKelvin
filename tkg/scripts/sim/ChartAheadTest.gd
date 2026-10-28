extends Node

## THE RUN'S STAR CHART BUILT AHEAD, headless:
##   godot --headless --path . -- sheet=ChartAheadTest
##
## A new run builds its chart's star field on a worker while the hull is picked
## (`MapChart.build_ahead`, from `Router.new_run`), so the first STARCHART or Tab
## does not stand still for the build. On three galaxies, through the real doors:
##
## - the chart the player opens is laid out at `MapChart.CHART_AT`, the size the
##   field is built for: a layout that moves the chart fails here, instead of
##   quietly building the field on the click again;
## - opening it builds nothing on the main thread: the field built ahead is the
##   one drawn, and it is the field the chart would have built itself, list for
##   list (`SKY_FIELDS`), read off Run as before;
## - THE WORKER READS ONLY ITS COPY: built while the main thread writes another
##   galaxy over Run (as the title does with its own) and asks the clouds of that
##   one, it still comes out the run's galaxy exactly; and it is not handed to a
##   chart of the other galaxy;
## - no engine error, worker or main thread.
##
## And the shaders the title compiles ahead (`ShaderWarm`) are the very ones the
## map and LOCAL draw with (the same resources, so the same programs), and none
## of it starts headless; and no compile starts within its QUIET_MS of the
## player's last input, the title's own included (seen before the warm began),
## nor in the first QUIET_MS after it arrives.

const SEEDS := [4242, 11, 777]

var _fails := 0
var _tree: SceneTree
var _log := ThreadStressCounter.new()


class ThreadStressCounter extends Logger:
	var n := 0
	var first: Array[String] = []
	var lock := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		lock.lock()
		n += 1
		if first.size() < 8:
			first.append("%s  (%s:%d %s)" % [rationale if rationale != "" else code, file, line, function])
		lock.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass


func _ok(what: String, c: bool) -> bool:
	print("  %s %s" % ["ok  " if c else "FAIL", what])
	if not c:
		_fails += 1
	return c


func _ready() -> void:
	_tree = get_tree()
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await _tree.process_frame


## Every list a chart's field is, the same in both.
func _same_field(a: StarchartScreen.MapChart, b: Variant) -> bool:
	for f: String in StarchartScreen.MapChart.SKY_FIELDS:
		var va: Variant = a.get(f)
		var vb: Variant = (b as Dictionary)[f] if b is Dictionary else (b as Object).get(f)
		if va != vb:
			print("    %s differs" % f)
			return false
	return int(a.get("_star_pos").size()) > 1000


## The field built here and now, on the main thread, off Run: what a chart of
## this size has always built for itself.
func _reference(size: Vector2) -> StarchartScreen.MapChart:
	var ref := StarchartScreen.MapChart.new()
	ref.size = size
	ref._build_field()
	return ref


func _wait_ahead() -> void:
	var a := StarchartScreen.MapChart._ahead
	for i in 600:
		if a == null or not is_instance_valid(a) or a.task < 0 or WorkerThreadPool.is_task_completed(a.task):
			return
		await _tree.process_frame


func _run() -> void:
	await _tree.process_frame
	OS.add_logger(_log)
	StarchartScreen.MapChart.ahead_always = true
	for sd in SEEDS:
		print("  [seed] %d" % sd)
		await _through_the_doors(sd)
	print("  [isolation]")
	await _isolation(31337)
	_warm_list()
	_warm_quiet()
	StarchartScreen.MapChart.ahead_always = false
	OS.remove_logger(_log)
	for l in _log.first:
		print("  error: " + l)
	_ok("no engine errors (%d)" % _log.n, _log.n == 0)
	print("chartaheadtest: %s (%d failed)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	_tree.quit(1 if _fails > 0 else 0)


func _through_the_doors(sd: int) -> void:
	Router.new_run(sd)
	var ahead := StarchartScreen.MapChart._ahead
	_ok("NEW RUN starts the chart's field on a worker", ahead != null and ahead.task >= 0)
	await _wait_ahead()
	await _frames(2)
	var before := StarchartScreen.MapChart.built_here
	Router.show_starchart()
	await _frames(6)
	var sc := Router.current as StarchartScreen
	if not _ok("the chart is up", sc != null and sc._chart != null):
		return
	var chart := sc._chart
	chart._build_stars()
	_ok("the chart stands at CHART_AT %s (it is %s)" % [StarchartScreen.MapChart.CHART_AT, chart.size],
		chart.size == StarchartScreen.MapChart.CHART_AT)
	_ok("opening it built no field on the main thread", StarchartScreen.MapChart.built_here == before)
	_ok("the field built ahead was taken", StarchartScreen.MapChart._ahead == null)
	var ref := _reference(chart.size)
	_ok("and it is the field the chart builds itself, list for list", _same_field(ref, chart))
	ref.free()
	Router.show_system()
	await _frames(4)


func _isolation(sd: int) -> void:
	Rng.forced = sd
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var sz := StarchartScreen.MapChart.CHART_AT
	var ref := _reference(sz)
	var mine := [Run.galaxy_kind, Run.galaxy.duplicate(true), Run.galaxy_seed, Run.galaxy_spin]
	StarchartScreen.MapChart.build_ahead(sz)
	var a := StarchartScreen.MapChart._ahead
	if not _ok("a field started for the run's galaxy", a != null and a.task >= 0):
		ref.free()
		return
	# the title's own galaxy written over Run while the worker builds, again
	# and again, its clouds asked for each time (`LauncherScreen._roll_sky_galaxy`)
	var r := RandomNumberGenerator.new()
	var n := 0
	while not WorkerThreadPool.is_task_completed(a.task) and n < 4000:
		r.seed = 9000 + n
		var k := r.randi() % GalaxyGen.count()
		Run.galaxy_kind = k
		Run.galaxy = GalaxyGen.roll(k, r)
		Run.galaxy_seed = r.randi()
		Run.galaxy_spin = r.randf() * TAU
		NebulaField.clouds()
		n += 1
	print("    %d other galaxies written over Run while it built" % n)
	# (a chart of another galaxy does not take it)
	StarchartScreen.MapChart._take_ahead()
	_ok("a chart of another galaxy leaves it be", StarchartScreen.MapChart._ahead == a and is_instance_valid(a))
	a.finish()
	Run.galaxy_kind = mine[0]
	Run.galaxy = mine[1]
	Run.galaxy_seed = mine[2]
	Run.galaxy_spin = mine[3]
	_ok("built from its copy, it is the run's galaxy exactly", _same_field(ref, a.snap))
	StarchartScreen.MapChart._drop_ahead()
	ref.free()


func _warm_list() -> void:
	print("  [shader warm]")
	var used := {}
	for path in ["res://scripts/ui/sysmap/SystemView.gd", "res://scripts/ui/LocalSky.gd",
			"res://scripts/ui/NavField.gd", "res://scripts/ui/sysmap/SunView.gd",
			"res://scripts/ui/planets/PlanetView.gd"]:
		var sc := load(path) as GDScript
		for k in sc.get_script_constant_map():
			var v: Variant = sc.get_script_constant_map()[k]
			if v is Shader:
				used[v] = true
	for e: Array in ShaderWarm.wanted():
		var sh := e[0] as Shader
		_ok("%s is a canvas shader the map or LOCAL draws with" % sh.resource_path,
			sh.get_mode() == Shader.MODE_CANVAS_ITEM and used.has(sh))
	ShaderWarm.start()
	_ok("nothing is compiled headless", _tree.root.get_node_or_null("ShaderWarm") == null)


## THE WARM KEEPS CLEAR OF THE PLAYER'S HAND: a compile is a held title frame,
## so none starts within QUIET_MS of any input -- the title's own `_input`
## counts from its first frame, before the warm's node exists -- nor in the
## first QUIET_MS after the node arrives.
func _warm_quiet() -> void:
	print("  [shader warm, quiet]")
	var held_by := func(ev: InputEvent, through_title: bool) -> bool:
		ShaderWarm._quiet_until = 0
		if through_title:
			var ls := LauncherScreen.new()
			ls._input(ev)
			ls.free()
		else:
			ShaderWarm.note_input(ev)
		return ShaderWarm.held()
	ShaderWarm._quiet_until = 0
	_ok("nothing touched: not held", not ShaderWarm.held())
	var mm := InputEventMouseMotion.new()
	mm.relative = Vector2(3, 1)
	_ok("the mouse moved on the title, before the warm began: held", held_by.call(mm, true))
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	_ok("a click on the title: held", held_by.call(click, true))
	var key := InputEventKey.new()
	key.keycode = KEY_ENTER
	key.pressed = true
	_ok("a key on the title: held", held_by.call(key, true))
	var pan := InputEventPanGesture.new()
	pan.delta = Vector2(0, 2)
	_ok("a trackpad pan: held", held_by.call(pan, false))
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	_ok("a touch: held", held_by.call(touch, false))
	var pad := InputEventJoypadButton.new()
	pad.pressed = true
	_ok("a pad button: held", held_by.call(pad, false))
	var stick := InputEventJoypadMotion.new()
	stick.axis_value = 0.8
	_ok("a stick pushed: held", held_by.call(stick, false))
	stick.axis_value = 0.05
	_ok("a resting stick's drift: not held", not held_by.call(stick, false))
	ShaderWarm._quiet_until = 0
	var t := Time.get_ticks_msec()
	ShaderWarm.note_input(mm)
	var left := ShaderWarm._quiet_until - t
	_ok("held QUIET_MS after the input, no longer (%d ms)" % left,
		left >= ShaderWarm.QUIET_MS and left <= ShaderWarm.QUIET_MS + 50)
	# the node arriving starts a quiet window of its own
	ShaderWarm._quiet_until = 0
	var w := ShaderWarm.new()
	add_child(w)
	_ok("the warm's first compile waits QUIET_MS after it arrives", ShaderWarm.held())
	w._input(mm)
	_ok("and the node's own input holds it too", ShaderWarm._quiet_until >= Time.get_ticks_msec() + ShaderWarm.QUIET_MS - 1)
	w.free()
	ShaderWarm._quiet_until = 0
