extends Node

## THE HEAVY LIFT (`ShipLift`, Jon's L1, Nov 12) on the front door's LAUNCH and the
## deck's UNDOCK: each runs to its end and lands where it should, LAUNCH once, no
## click on the hall meanwhile, reduced motion a cut. Headless, `--fixed-fps 60`.
## Why: docs/why/ShipLift.md#test

var _tree: SceneTree
var h := Harness.new()
var _t := 0.0


func _ok(what: String, c: bool) -> bool:
	return h._ok(what, c)


func _process(delta: float) -> void:
	_t += delta


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_tree = get_tree()
	await Harness.frames(_tree, 2)
	Router.animate_in_harness = true
	var rm_was := DisplaySettings.reduced_motion
	DisplaySettings.reduced_motion = false
	await _launch()
	await _launch_reduced()
	await _undock()
	DisplaySettings.reduced_motion = rm_was
	h.verdict("shiplifttest")
	_tree.quit(h.code())


func _hull_pick() -> ChassisSelect:
	h.seed_run(4242)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Router.show_chassis_select()
	await Harness.frames(_tree, 6)
	var cs := Router.current as ChassisSelect
	if cs == null or not cs._yard.ready_hall:
		return null
	cs._pick_weight(HullData.Weight.MEDIUM)
	await Harness.frames(_tree, 3)
	return cs


## LAUNCH: the medium lifts, sinks its stands, smokes, burns off right; once.
func _launch() -> void:
	var cs := await _hull_pick()
	if not _ok("the hull pick opens on the city hall with a medium picked", cs != null and cs.launchable()):
		return
	var fired := [0]
	cs.launched.connect(func() -> void: fired[0] += 1)
	var berth := cs._yard.set_of(HullData.Weight.MEDIUM)
	# PARKED ON THE STANDS, ENGINES OUT (Jon, Nov 13): no rear flame, no nozzle glow
	var lit_parked := 0
	for w: HullData.Weight in cs._yard.sets:
		var pv: ShipView = (cs._yard.sets[w] as YardStandSet)._view
		if pv != null and (pv._thrust_now() >= 0 or not pv.engine_glow().is_empty()):
			lit_parked += 1
	_ok("the front door's parked hulls show no rear flame or glow (%d lit)" % lit_parked, lit_parked == 0)
	var x0 := berth.position.x
	var y0 := berth.position.y
	var key := Harness.button_with_text(cs, "LAUNCH")
	Audio.taping = true
	Audio.tape.clear()
	key.pressed.emit()
	var t0 := _t
	await Harness.frames(_tree, 1)
	var lift := cs._yard.lift
	_ok("LAUNCH starts the shared lift (`ShipLift`), not the run", lift != null and Router.current == cs and fired[0] == 0)
	if lift == null:
		return
	var lat: Array = []
	lift.lateral.connect(func(on: bool, v: float) -> void: lat.append([on, v, _t - t0, Engine.get_process_frames()]))
	# a second press, by the key and by the code, starts nothing more
	key.pressed.emit()
	cs._launch()
	await Harness.frames(_tree, 1)
	_ok("a second LAUNCH starts no second lift and no run", cs._yard.lift == lift and fired[0] == 0)
	# a click on another banner and on the floor while it flies changes nothing
	var b2 := cs._yard.banners[1].get_global_rect().get_center()
	for at: Vector2 in [b2, Vector2(300, 380)]:
		for pressed in [true, false]:
			var ev := InputEventMouseButton.new()
			ev.position = at
			ev.global_position = at
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = pressed
			cs.get_viewport().push_input(ev)
			await Harness.frames(_tree, 1)
	_ok("no click reaches the hall while the ship is in the air (manufacturer %s, pick %d)" % [cs.manufacturer(), cs._picked],
		cs._sel == 0 and cs._picked == int(HullData.Weight.MEDIUM))
	var top := 0.0
	var right := 0.0
	var sunk := 0
	var lamps0 := cs._yard.scene.light.lamp_gain.duplicate()
	var lamps_moved := 0
	var light_jump := 0.0
	var light_prev := -1.0
	var smoke := 0
	var landed_at := -1.0
	var left_lit := 0
	var flame_at := -1.0
	var jets_f := -1
	var loop_f := -1
	for i in 900:
		if Router.current != cs:
			landed_at = _t - t0
			break
		if _t - t0 > ShipLift.exit_s() + 0.1 and _left_behind(lift, cs._yard.scene):
			left_lit += 1
		if flame_at < 0.0 and lift.view._thrust_now() >= 0:
			flame_at = _t - t0
		if jets_f < 0 and lift.plume.fired():
			jets_f = Engine.get_process_frames()
		if loop_f < 0 and Audio.ship_want > 0.0:
			loop_f = Engine.get_process_frames()
		top = minf(top, berth.position.y - y0)
		right = maxf(right, berth.position.x - x0)
		sunk = maxi(sunk, berth.retract)
		if cs._yard.scene.light.lamp_gain != lamps0:
			lamps_moved += 1
		var lv := lift.plume.light_level()
		if light_prev >= 0.0:
			light_jump = maxf(light_jump, absf(lv - light_prev))
		light_prev = lv
		smoke = maxi(smoke, lift.plume.puffs())
		await _tree.process_frame
	_ok("it rises off its stands (%.0f px), the stands sink (%d rows), the smoke rolls (%d puffs)" % [-top, sunk, smoke],
		top <= -40.0 and sunk >= 40 and smoke >= 20)
	# (Jon's F1: no flicker -- the hall's lamps hold, the engines' light eases)
	_ok("the hall's lamps hold steady through the lift (%d frames moved), and its own light eases (at most %.3f a frame)" % [
		lamps_moved, light_jump], lamps_moved == 0 and light_jump <= 0.12)
	_ok("off the picture, nothing of it is left at the edge: its engines dark, no jet, nozzle or smoke light (%d frames lit)" % left_lit,
		left_lit == 0)
	_ok("it burns off the right edge (%.0f px across, off past %d)" % [right, YardFront.W],
		x0 + right > float(YardFront.W))
	_ok("the mains' sideways burn is reported once each way, going right, from %.2f s (%s)" % [ShipLift.MAINS_ON, lat],
		lat.size() == 2 and bool(lat[0][0]) and float(lat[0][1]) >= 0.0 and not bool(lat[1][0])
			and float(lat[0][2]) >= ShipLift.MAINS_ON - 0.02 and float(lat[0][2]) < ShipLift.exit_s())
	var lat_at := float(lat[0][2]) if not lat.is_empty() else -1.0
	_ok("no main flame through the rise: it lights with the sideways burn, on `MAINS_ON` (flame from %.3f s, the burn's signal at %.3f s, the beat %.2f s)" % [
		flame_at, lat_at, ShipLift.MAINS_ON], flame_at >= 0.0 and lat_at >= 0.0 and absf(flame_at - lat_at) < 0.02
			and flame_at >= ShipLift.MAINS_ON - 0.001)
	var heard := {}
	for tp: Array in Audio.tape:
		if tp.size() > 5 and not heard.has(String(tp[0])):
			heard[String(tp[0])] = int(tp[5])
	Audio.taping = false
	var mains_f := int(lat[0][3]) if not lat.is_empty() else -99
	var depart := String(ShipView.DEPART_SFX[int(HullData.Weight.MEDIUM)])
	var take_f := int(heard.get(String(ShipLift.LIFT_TAKE), -99))
	_ok("THE TAKEOFF HEARD: the take (%s) on the jets' first frame (frame %d, the jets at %d), within a frame" % [
		ShipLift.LIFT_TAKE, take_f, jets_f], jets_f >= 0 and absi(take_f - jets_f) <= 1)
	_ok("and the LTC layer on `MAINS_ON`: the departure burn (%s at frame %d) and the drive loop (from frame %d) with the burn's signal (frame %d), within a frame" % [
		depart, int(heard.get(depart, -99)), loop_f, mains_f],
		absi(int(heard.get(depart, -99)) - mains_f) <= 1 and absi(loop_f - mains_f) <= 1)
	_ok("the run starts when the lift ends (%.2f s; the lift %.2f s)" % [landed_at, ShipLift.front_s()],
		landed_at >= ShipLift.front_s() - 0.05 and landed_at <= ShipLift.front_s() + 0.2)
	await Harness.frames(_tree, 10)
	_ok("LOCAL, launched once (%d), in the picked hull" % fired[0], Router.current is SectorScreen and fired[0] == 1
		and Run.hull != null and Run.hull.weight == HullData.Weight.MEDIUM)


## Reduced motion: LAUNCH is a cut to the run, no lift.
func _launch_reduced() -> void:
	DisplaySettings.reduced_motion = true
	var cs := await _hull_pick()
	if not _ok("reduced motion: the hull pick with a medium picked", cs != null and cs.launchable()):
		DisplaySettings.reduced_motion = false
		return
	var yard := cs._yard
	Harness.button_with_text(cs, "LAUNCH").pressed.emit()
	var lifted := yard.lift != null
	await Harness.frames(_tree, 2)
	_ok("reduced motion: LAUNCH cuts straight to LOCAL, no lift", Router.current is SectorScreen and not lifted)
	DisplaySettings.reduced_motion = false


## UNDOCK from the Shipyard deck: the same lift, off to the right, then LOCAL undocked.
func _undock() -> void:
	ZoomLadder.force = 1
	ZoomLadder.fixed_dt = 1.0 / 60.0
	h.seed_run(1)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	StarchartScreen._primed_for = Run.galaxy_seed
	var stn := -1
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		if n.type == MapGen.NodeType.STATION:
			stn = n.index
			break
	if not _ok("a station to dock at", stn >= 0):
		return
	Run.at = stn
	Run.map[stn].visited = true
	SectorScreen._approached_at = stn
	Router.park_at_station()
	ZoomLadder.force = 0
	Router.show_station()
	ZoomLadder.force = 1
	await Harness.frames(_tree, 120)
	var st := Router.current as StationScreen
	if not _ok("docked, on the Shipyard", st != null and Router.docked and st._mine_view != null):
		return
	_ok("on the deck's stands, your hull's engines are out: no rear flame, no glow (thrust %d)" % st._mine_view._thrust_now(),
		st._mine_view._thrust_now() < 0 and st._mine_view.engine_glow().is_empty())
	var rest := st._mine_view.position
	var t0 := _t
	Router.show_sector()
	var used := false
	var right := 0.0
	var top := 0.0
	var sunk := 0
	var smoke := 0
	var until := -1.0
	var left_lit := 0
	var t_lift := -1.0
	for i in 1500:
		await _tree.process_frame
		if Router.current == st and is_instance_valid(st) and st._heavy != null:
			if t_lift < 0.0:
				t_lift = _t
			if _t - t_lift > StationScreen.undock_elev_s() + ShipLift.exit_s() + 0.1 and _left_behind(st._heavy, st._scene):
				left_lit += 1
			used = true
			right = maxf(right, st._mine_view.position.x - rest.x)
			top = minf(top, st._mine_view.position.y - rest.y)
			sunk = maxi(sunk, st._scene.sink_mine)
			smoke = maxi(smoke, st._heavy.plume.puffs())
		if until < 0.0 and Router.current is SectorScreen and not ZoomLadder.busy():
			until = _t - t0
			break
	_ok("UNDOCK runs the shared lift on the deck", used)
	_ok("off the yard, nothing of it is left at the edge (%d frames lit)" % left_lit, left_lit == 0)
	_ok("off its stands (%.0f px up), the stands sink (%d rows), the smoke rolls (%d puffs), and away to the RIGHT (%.0f px)" % [
		-top, sunk, smoke, right], top <= -25.0 and sunk >= 25 and smoke >= 20 and right > 200.0)
	_ok("it lands on LOCAL undocked (%.2f s; the yard's part %.2f s)" % [until, ZoomLadder.UNDOCK_YARD_S],
		until > ZoomLadder.UNDOCK_YARD_S and Router.current is SectorScreen and not Router.docked)
	ZoomLadder.force = -1
	ZoomLadder.fixed_dt = -1.0


## Anything of the lift still lit on the picture once the hull is off it: its flame,
## the jets' or nozzle's light, or a small light it put in the yard's light (one
## still easing out past the picture's right edge, with the hull, is not on it).
func _left_behind(lift: ShipLift, sc: YardScene) -> bool:
	if lift.view._thrust_now() >= 0 or lift.lit() > 0:
		return true
	var edge := float(lift.host.size.x)
	var lit: Array = lift.plume.lights()
	if sc.life != null:
		lit.append_array(sc.life.extra)
	for l: Array in lit:
		if float(l[0]) - float(l[2]) < edge:
			return true
	return false
