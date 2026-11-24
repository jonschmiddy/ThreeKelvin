extends Node

## The ship-select rooms as a player meets them, to lay beside the approved films:
## `room=korvan|solari|old at=0,5,10 out=<dir> [pick=medium] [film=S]`, with `--fixed-fps 30`
## so the room's clock steps as the films' did; needs a window (render.sh). docs/tests.md.
## Banners: `bt=` `strip=1` `state=1` `banners=off` `events=<json>` `perf=1` (docs/tests.md).

var _out := ""
var _events: Array = []
var _ev := 0
var _yard: YardFront = null


func _ready() -> void:
	_out = Harness.arg("out", "user://shiproom")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_run.call_deferred()


func _run() -> void:
	await Harness.frames(get_tree(), 2)
	if DevMode.available:
		DevMode.enabled = false
	# `look=flat`: no tube's curve or scanlines, so a capture lies pixel for pixel on the film
	if Harness.arg("look") == "flat":
		DisplaySettings.set_look(DisplaySettings.Look.FLAT)
	var room := Harness.arg("room", "korvan")
	var cs := await _pick_screen()
	# Solari's casting bed needs Solari open: a won Korvan flight on the scratch record opens it
	if room == "solari" and cs != null and not Unlocks.unlocked(&"solari"):
		Run.fit_chassis(&"korvan", HullData.Weight.MEDIUM, 0)
		Run.launched_as = &"korvan"
		RunHistory.record(RunHistory.Outcome.WON, "ShipRoomShot")
		cs = await _pick_screen()
	if cs == null:
		print("shiproomshot: no hull pick")
		get_tree().quit(1)
		return
	cs._select(0 if room == "korvan" else 1)
	# (should the record still not open it, its set stands in its room anyway)
	if room == "solari" and cs._yard.room.id != &"solari":
		cs._yard.show_set(&"solari", true, 0)
	var pick := Harness.arg("pick", "")
	if pick != "":
		cs._pick_weight({"light": HullData.Weight.LIGHT, "medium": HullData.Weight.MEDIUM,
			"heavy": HullData.Weight.HEAVY}[pick])
	var y := cs._yard
	_banner_args(y)
	print("shiproomshot: %s room, %s set" % [y.room.id, y.manufacturer])
	for w: HullData.Weight in y.sets:
		var s: YardStandSet = y.sets[w]
		print("  %-6s thing %s posts %s top %d feet %d guns %s" % [HullData.weight_name(w), s.thing, s.post_x,
			s.post_top, s.feet, s.guns])
	var film := float(Harness.arg("film", "0"))
	if film > 0.0:
		var t0 := y.room.t
		while y.room.t - t0 < film:
			await get_tree().process_frame
		print("shiproomshot: filmed %.1f s" % film)
		get_tree().quit()
		return
	if Harness.arg("perf") == "1":
		await _perf(y)
		get_tree().quit()
		return
	if Harness.arg("bt") != "":
		await _banner_shots(y, room)
		get_tree().quit()
		return
	var ats: Array[float] = []
	for a in Harness.arg("at", "0,5,10").split(",", false):
		ats.append(float(a))
	ats.sort()
	for a in ats:
		while y.room.t < a:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_shot("%s_%05.1f" % [room, a])
	print("shiproomshot: done, %s" % _out)
	get_tree().quit()


func _banner_args(y: YardFront) -> void:
	_yard = y
	if Harness.arg("banners") == "off":
		y.cloth.show_cloth(false)
	var ev := Harness.arg("events")
	if ev != "":
		_events = JSON.parse_string(FileAccess.get_file_as_string(ev))
	get_tree().process_frame.connect(_drive)


## The pointer's script, pushed before the cloth's frame `f` (its clock at f / 30 s): moves, clicks, a leave.
func _drive() -> void:
	if _yard == null or _yard.cloth == null:
		return
	var f := roundi(_yard.cloth.clock * 30.0)
	while _ev < _events.size() and int(_events[_ev][0]) <= f:
		var e: Array = _events[_ev]
		_ev += 1
		var at := _yard.get_global_transform_with_canvas() * Vector2(float(e[2]), float(e[3]))
		if e[1] == "leave":
			_yard.cloth.leave()
			continue
		if e[1] == "move":
			var mm := InputEventMouseMotion.new()
			mm.position = at
			mm.global_position = at
			get_viewport().push_input(mm)
		else:
			for pressed in [true, false]:
				var mb := InputEventMouseButton.new()
				mb.position = at
				mb.global_position = at
				mb.button_index = MOUSE_BUTTON_LEFT
				mb.pressed = pressed
				get_viewport().push_input(mb)


## Stills at the cloth's own clock (`bt`), each with the banners' crop and the GPU state if asked.
func _banner_shots(y: YardFront, room: String) -> void:
	var bts: Array[float] = []
	for a in Harness.arg("bt").split(",", false):
		bts.append(float(a))
	bts.sort()
	for a in bts:
		while y.cloth.clock < a - 1e-4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var name := "%s_b%05.2f" % [room, a]
		var img := get_tree().root.get_texture().get_image()
		img.save_png("%s/%s.png" % [_out, name])
		if Harness.arg("strip") == "1":
			var k := img.get_width() / ShipRoom.W
			img.get_region(Rect2i(0, 0, ShipRoom.W * k, YardCloth.WALL.y * k)).save_png("%s/%s_strip.png" % [_out, name])
		var st := y.cloth.state_image() if Harness.arg("state") == "1" else null
		if st != null:
			st.save_png("%s/%s_state.png" % [_out, name])
		print("  wrote %s (cloth clock %.4f, steps %d, t %.4f)" % [name, y.cloth.clock, y.cloth.steps, y.cloth.t_sim])
	print("shiproomshot: done, %s" % _out)


## What the banners cost a frame: the cloth's own process time, and each of its viewports' render time
## on the CPU and the GPU, over 300 frames (run without --fixed-fps).
func _perf(y: YardFront) -> void:
	var vps := y.cloth.viewports()
	for v in vps:
		RenderingServer.viewport_set_measure_render_time(v.get_viewport_rid(), true)
	await Harness.frames(get_tree(), 30)
	var cpu := PackedFloat64Array([0.0, 0.0, 0.0])
	var gpu := PackedFloat64Array([0.0, 0.0, 0.0])
	var proc := 0.0
	var frames := 300
	for f in frames:
		await RenderingServer.frame_post_draw
		for i in vps.size():
			cpu[i] += RenderingServer.viewport_get_measured_render_time_cpu(vps[i].get_viewport_rid())
			gpu[i] += RenderingServer.viewport_get_measured_render_time_gpu(vps[i].get_viewport_rid())
		proc += y.cloth.last_us
	for i in vps.size():
		print("  perf %-5s cpu %.3f ms gpu %.3f ms" % [["sim", "lit", "wall"][i], cpu[i] / frames, gpu[i] / frames])
	print("  perf YardCloth._process %.3f ms a frame, %d fps" % [proc / frames / 1000.0, Engine.get_frames_per_second()])


## A new run's hull pick, once its room is up.
func _pick_screen() -> ChassisSelect:
	Router.new_run(4242)
	for i in 600:
		var cs := Router.current as ChassisSelect
		if cs != null and cs._yard != null and cs._yard.room != null:
			return cs
		await get_tree().process_frame
	return null


func _shot(name: String) -> void:
	var img := get_tree().root.get_texture().get_image()
	img.save_png("%s/%s.png" % [_out, name])
	print("  wrote %s/%s.png (%dx%d)" % [_out, name, img.get_width(), img.get_height()])
