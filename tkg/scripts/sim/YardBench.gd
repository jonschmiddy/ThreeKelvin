extends Node

## What a frame of the front door (the banner shipyard) costs, windowed: at rest,
## a ship picked (the held blur) and another pointed at. Manual, not in the gate.
## `-- sheet=YardBench [secs=20] [states=rest,picked,hover] [ablate] [out=<json>]`
## (state `steam`: a lift's steam held at full burn under the medium berth, its
## fullest; the lift itself leaves the hall, so it is measured standing)
## through `tools/dev/render.sh`. Vsync and the frame cap go off, so a frame lasts
## as long as its work. `ablate` adds 5 s samples with one part switched off.

var _game_rid := RID()
var _root_rid := RID()
var _cs: ChassisSelect = null
var _rows: Array = []
## The pointer sweeping the hall (state `sweep`): real input, not swallowed.
var _sweep := false
var _sweep_t := 0.0


func _ready() -> void:
	set_process(false)
	_run.call_deferred()


func _input(event: InputEvent) -> void:
	if _sweep:
		return
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		get_viewport().set_input_as_handled()


func _run() -> void:
	# (`steam=heavy|heavier`: the lift's steam at that weight, `LiftPlume.WEIGHTS`)
	LiftPlume.weight = int({"heavy": 1, "heavier": 2}.get(Harness.arg("steam", ""), 0))
	var tree := get_tree()
	await tree.process_frame
	if DisplayServer.get_name() == "headless":
		print("yardbench: needs a window")
		tree.quit(1)
		return
	tree.root.gui_disable_input = true
	_game_rid = GameShell.instance.view.get_viewport_rid() if GameShell.instance != null else get_viewport().get_viewport_rid()
	_root_rid = tree.root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_game_rid, true)
	RenderingServer.viewport_set_measure_render_time(_root_rid, true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	print("yardbench: %s; %s (%s); window %s" % [BuildInfo.line(), RenderingServer.get_video_adapter_name(),
		RenderingServer.get_current_rendering_driver_name(), DisplayServer.window_get_size()])
	await _secs(2.0)
	var u := Time.get_ticks_usec()
	Router.new_run(4242)
	print("  yardbench enter: new_run took %.1f ms" % [(Time.get_ticks_usec() - u) / 1000.0])
	await _enter(6.0)
	_cs = Router.current as ChassisSelect
	if _cs == null or not _cs._yard.ready_hall:
		print("yardbench: no banner shipyard")
		tree.quit(1)
		return
	_cs._yard.ship_hover.connect(func(_w: int) -> void: _hovers += 1)
	var secs := float(Harness.arg("secs", "20"))
	if Harness.arg("scale") != "":
		DisplaySettings.set_scale(int(Harness.arg("scale")))
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
	if Harness.arg("look") == "crt":
		DisplaySettings.set_look(DisplaySettings.Look.CRT_GENTLE)
	await _secs(1.0)
	print("yardbench: window %s, look %s" % [DisplayServer.window_get_size(), Harness.arg("look", "flat")])
	if OS.get_cmdline_user_args().has("clicks"):
		await _clicks()
	for st in Harness.arg("states", "rest,picked,hover").split(",", false):
		_state(st)
		await _secs(1.5)
		_report(st, await _sample(secs))
		if OS.get_cmdline_user_args().has("ablate"):
			for part in ["tick", "banners", "blur", "hall"]:
				var undo := _off(part)
				await _secs(0.5)
				_report("%s -%s" % [st, part], await _sample(5.0))
				undo.call()
				await _secs(0.5)
	var outp := Harness.arg("out")
	if outp != "":
		var f := FileAccess.open(outp, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(_rows, " "))
			print("wrote ", outp)
	tree.quit()


func _state(st: String) -> void:
	var heavy: YardStandSet = _cs._yard.set_of(HullData.Weight.HEAVY)
	_sweep = st == "sweep" or st == "tip"
	_hold = st == "tip"
	get_tree().root.gui_disable_input = not _sweep
	set_process(_sweep)
	match st:
		"rest":
			_cs.deselect()
		"picked":
			_cs._pick_weight(HullData.Weight.MEDIUM)
		"hover":
			_cs._pick_weight(HullData.Weight.MEDIUM)
			heavy.notification(Control.NOTIFICATION_MOUSE_ENTER)
		"sweep":
			heavy.notification(Control.NOTIFICATION_MOUSE_EXIT)
		"steam":
			_steam()


## The steam a lift throws up, at full burn and never cutting.
func _steam() -> void:
	var y := _cs._yard
	var s: YardStandSet = y.set_of(HullData.Weight.MEDIUM)
	var p := LiftPlume.new()
	p.setup(y.size.x, y.size.y, 220.0)
	p.floor_y = float(s.feet)
	p.lamps = ShipLift.lamps_of(y.scene.light, y.size.x)
	var r := Rect2(s.thing)
	p.hull = Rect2(r.position.x, r.position.y, r.size.x, r.size.y * 0.5)
	p.src = Vector2(r.get_center().x, r.position.y + r.size.y * 0.5)
	p.src_w = r.size.x * 0.2
	y.add_child(p.back_layer)
	y.add_child(p)
	p.thrust = 1.0
	p.fire()


## A pointer crossing the banners and the three ships, as a player looks round.
func _process(delta: float) -> void:
	_sweep_t += delta
	var k := float(DisplayServer.window_get_size().x) / 960.0
	var m := InputEventMouseMotion.new()
	var p := Vector2(480.0 + 400.0 * sin(_sweep_t * 0.9), 250.0 + 120.0 * sin(_sweep_t * 2.3)) * k
	if _hold:
		# onto the heavy's hull and still, so its tooltip comes up and stays
		var h: YardStandSet = _cs._yard.set_of(HullData.Weight.HEAVY)
		p = Vector2(h.thing.get_center()) * k
		if p == _last_p:
			return
	m.position = p
	m.global_position = p
	m.relative = p - _last_p
	_last_p = p
	Input.parse_input_event(m)


var _last_p := Vector2.ZERO
var _hovers := 0
var _hold := false


## A banner's click, piece by piece (as `YardFront.show_set` runs it).
func _profile_select(m: StringName) -> void:
	var y := _cs._yard
	var open := Unlocks.unlocked(m) or DevMode.enabled
	y.manufacturer = m
	y.locked = not open
	for w: HullData.Weight in y.sets:
		var u := Time.get_ticks_usec()
		var frame := DB.hull_for(&"korvan", w)
		var hull: HullData = DB.at_tier(DB.hull_for(m, w), 0) if open else null
		(y.sets[w] as YardStandSet).setup(y.scene, w, hull, frame, m)
		print("    %s setup %d: %.1f ms" % [m, w, (Time.get_ticks_usec() - u) / 1000.0])
	var u2 := Time.get_ticks_usec()
	var map := PackedByteArray()
	map.resize(960 * YardFront.HALL_H * 4)
	for w: HullData.Weight in y.sets:
		(y.sets[w] as YardStandSet).mask_into(map, 960)
	print("    %s mask_into x3: %.1f ms" % [m, (Time.get_ticks_usec() - u2) / 1000.0])
	u2 = Time.get_ticks_usec()
	y._rebake()
	print("    %s _rebake whole: %.1f ms" % [m, (Time.get_ticks_usec() - u2) / 1000.0])
	u2 = Time.get_ticks_usec()
	y.scene._bake_bay()
	print("    %s _bake_bay alone: %.1f ms" % [m, (Time.get_ticks_usec() - u2) / 1000.0])
	u2 = Time.get_ticks_usec()
	y._apply_light()
	print("    %s _apply_light: %.1f ms" % [m, (Time.get_ticks_usec() - u2) / 1000.0])


## What a click costs: each banner, then each ship picked and pointed at.
func _clicks() -> void:
	if OS.get_cmdline_user_args().has("profile"):
		for m: StringName in [&"korvan", &"solari"]:
			for w: HullData.Weight in [HullData.Weight.HEAVY, HullData.Weight.LIGHT]:
				var h := DB.at_tier(DB.hull_for(m, w), 0)
				var u0 := Time.get_ticks_usec()
				var im := h.sprite.get_image()
				var u1 := Time.get_ticks_usec()
				HullGrade._full(h)
				var u2 := Time.get_ticks_usec()
				HullGrade.band_ramp(HullGrade.key_for(h))
				HullGrade.places(HullGrade.key_for(h))
				print("    %s %d: get_image %.1f ms (%s %s), _full %.1f, tables %.1f" % [m, w, (u1 - u0) / 1000.0, im.get_size(), h.sprite.get_class(),
					(u2 - u1) / 1000.0, (Time.get_ticks_usec() - u2) / 1000.0])
		for w: HullData.Weight in [HullData.Weight.LIGHT, HullData.Weight.HEAVY]:
			var u := Time.get_ticks_usec()
			Run.fit_chassis(&"korvan", w, 0)
			print("    fit_chassis %d: %.1f ms" % [w, (Time.get_ticks_usec() - u) / 1000.0])
			u = Time.get_ticks_usec()
			_cs._hover = int(w)
			_cs._show_band()
			print("    _show_band %d: %.1f ms" % [w, (Time.get_ticks_usec() - u) / 1000.0])
		await _profile_select(&"korvan")
		await _profile_select(&"solari")
	for i in DB.STARTABLE.size() + 1:
		var u := Time.get_ticks_usec()
		_cs._select(i % DB.STARTABLE.size())
		print("  yardbench click banner %s: %.1f ms" % [DB.STARTABLE[i % DB.STARTABLE.size()], (Time.get_ticks_usec() - u) / 1000.0])
		await _secs(0.5)
	for w: HullData.Weight in [HullData.Weight.LIGHT, HullData.Weight.MEDIUM, HullData.Weight.HEAVY]:
		var u := Time.get_ticks_usec()
		_cs._pick_weight(w)
		print("  yardbench pick %d: %.1f ms" % [w, (Time.get_ticks_usec() - u) / 1000.0])
		await _secs(0.3)
		var s: YardStandSet = _cs._yard.set_of((int(w) + 1) % 3 as HullData.Weight)
		u = Time.get_ticks_usec()
		s.notification(Control.NOTIFICATION_MOUSE_ENTER)
		print("  yardbench point at %d: %.1f ms" % [(int(w) + 1) % 3, (Time.get_ticks_usec() - u) / 1000.0])
		await _secs(0.3)
		u = Time.get_ticks_usec()
		s.notification(Control.NOTIFICATION_MOUSE_EXIT)
		print("  yardbench point away: %.1f ms" % [(Time.get_ticks_usec() - u) / 1000.0])
		await _secs(0.3)
	_cs.deselect()


## One part switched off; the Callable puts it back.
func _off(part: String) -> Callable:
	var y := _cs._yard
	match part:
		"tick":
			y.scene.set_process(false)
			return func() -> void: y.scene.set_process(true)
		"banners":
			for b in y.banners:
				b.set_process(false)
			return func() -> void:
				for b in y.banners:
					b.set_process(true)
		"blur":
			var was: bool = y._blur.visible
			y._blur.visible = false
			return func() -> void: y._blur.visible = was
		"hall":
			y.scene.visible = false
			return func() -> void: y.scene.visible = true
	return func() -> void: pass


## The first seconds on the front door, second by second: the worst frame and the long ones.
func _enter(secs: float) -> void:
	var prev := Time.get_ticks_usec()
	var t0 := prev
	var worst := 0.0
	var long := 0
	var n := 0
	var sec := 0
	while Time.get_ticks_usec() - t0 < int(secs * 1000000.0):
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		var ms := float(now - prev) / 1000.0
		prev = now
		worst = maxf(worst, ms)
		long += 1 if ms > 33.4 else 0
		n += 1
		if int((now - t0) / 1000000) != sec:
			print("  yardbench enter second %d: %d frames, worst %.1f ms, %d over 33 ms" % [sec, n, worst, long])
			sec = int((now - t0) / 1000000)
			worst = 0.0
			long = 0
			n = 0


func _secs(s: float) -> void:
	var until := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < until:
		await RenderingServer.frame_post_draw


## Every frame for `secs`: its length, the script half (process to pre-draw), the
## render half, the GPU, draw calls, and whether the yard ticked in it.
func _sample(secs: float) -> Dictionary:
	var mark := {"proc": 0, "pre": 0}
	var on_proc := func() -> void: mark.proc = Time.get_ticks_usec()
	var on_pre := func() -> void: mark.pre = Time.get_ticks_usec()
	get_tree().process_frame.connect(on_proc)
	RenderingServer.frame_pre_draw.connect(on_pre)
	await RenderingServer.frame_post_draw
	var times: Array[float] = []
	var procs_tick: Array[float] = []
	var procs_idle: Array[float] = []
	var draw := 0.0
	var gpu := 0.0
	var rcpu := 0.0
	var calls := 0.0
	var prims := 0.0
	var sc := _cs._yard.scene
	var last_tick := sc._tick_n
	var prev := Time.get_ticks_usec()
	var until := prev + int(secs * 1000000.0)
	while Time.get_ticks_usec() < until:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		times.append(float(now - prev) / 1000.0)
		prev = now
		var p := float(int(mark.pre) - int(mark.proc)) / 1000.0
		if sc._tick_n != last_tick:
			procs_tick.append(p)
		else:
			procs_idle.append(p)
		last_tick = sc._tick_n
		draw += float(now - int(mark.pre)) / 1000.0
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(_root_rid) + RenderingServer.viewport_get_measured_render_time_gpu(_game_rid)
		rcpu += RenderingServer.viewport_get_measured_render_time_cpu(_root_rid) + RenderingServer.viewport_get_measured_render_time_cpu(_game_rid)
		calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	get_tree().process_frame.disconnect(on_proc)
	RenderingServer.frame_pre_draw.disconnect(on_pre)
	var n := times.size()
	var s := times.duplicate()
	s.sort()
	var mean := 0.0
	for t in times:
		mean += t
	mean /= float(n)
	var med: float = s[n / 2]
	var spikes := 0
	for t in times:
		if t > maxf(3.0 * med, 16.7):
			spikes += 1
	return {"frames": n, "mean": mean, "p50": med, "p95": s[int(n * 0.95)], "p99": s[int(n * 0.99)], "max": s[n - 1],
		"spikes": spikes, "proc_tick": _avg(procs_tick), "proc_idle": _avg(procs_idle), "ticks": procs_tick.size(),
		"draw": draw / n, "render_cpu": rcpu / n, "gpu": gpu / n, "calls": calls / n, "prims": prims / n,
		"objects": Performance.get_monitor(Performance.OBJECT_COUNT), "items": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)}


static func _avg(a: Array[float]) -> float:
	var t := 0.0
	for v in a:
		t += v
	return t / maxf(1.0, float(a.size()))


func _report(label: String, r: Dictionary) -> void:
	r["state"] = label
	r["hovers"] = _hovers
	r["tags"] = get_tree().root.find_children("*", "HoloTag", true, false).size()
	_hovers = 0
	_rows.append(r)
	print("  yardbench %-16s frame mean %6.2f p50 %6.2f p95 %6.2f p99 %6.2f max %6.2f ms (%.0f fps, %d frames, %d spikes) | proc tick %6.2f idle %5.2f (%d ticks) | draw %5.2f rcpu %5.2f gpu %5.2f | %.0f calls %.0f prims, %d hover changes, %d tags" % [
		label, r.mean, r.p50, r.p95, r.p99, r.max, 1000.0 / maxf(0.01, r.mean), r.frames, r.spikes,
		r.proc_tick, r.proc_idle, r.ticks, r.draw, r.render_cpu, r.gpu, r.calls, r.prims, r.hovers, r.tags])
