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
	var x0 := berth.position.x
	var y0 := berth.position.y
	var key := Harness.button_with_text(cs, "LAUNCH")
	key.pressed.emit()
	var t0 := _t
	await Harness.frames(_tree, 1)
	var lift := cs._yard.lift
	_ok("LAUNCH starts the shared lift (`ShipLift`), not the run", lift != null and Router.current == cs and fired[0] == 0)
	if lift == null:
		return
	var lat: Array = []
	lift.lateral.connect(func(on: bool, v: float) -> void: lat.append([on, v, _t - t0]))
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
	var dim := 1.0
	var smoke := 0
	var landed_at := -1.0
	for i in 600:
		if Router.current != cs:
			landed_at = _t - t0
			break
		top = minf(top, berth.position.y - y0)
		right = maxf(right, berth.position.x - x0)
		sunk = maxi(sunk, berth.retract)
		dim = minf(dim, cs._yard.scene.light.lamp_k)
		smoke = maxi(smoke, lift.plume.puffs())
		await _tree.process_frame
	_ok("it rises off its stands (%.0f px), the stands sink (%d rows), the smoke rolls (%d puffs), the lamps stutter (%.2f)" % [
		-top, sunk, smoke, dim], top <= -40.0 and sunk >= 40 and smoke >= 20 and dim < 0.9)
	_ok("it burns off the right edge (%.0f px across, off past %d)" % [right, YardFront.W],
		x0 + right > float(YardFront.W))
	_ok("the mains' sideways burn is reported once each way, going right, from %.2f s (%s)" % [ShipLift.BURN_AT, lat],
		lat.size() == 2 and bool(lat[0][0]) and float(lat[0][1]) > 0.0 and not bool(lat[1][0])
			and float(lat[0][2]) >= ShipLift.BURN_AT and float(lat[0][2]) < ShipLift.exit_s())
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
	var rest := st._mine_view.position
	var t0 := _t
	Router.show_sector()
	var used := false
	var right := 0.0
	var top := 0.0
	var sunk := 0
	var smoke := 0
	var until := -1.0
	for i in 1200:
		await _tree.process_frame
		if Router.current == st and is_instance_valid(st) and st._heavy != null:
			used = true
			right = maxf(right, st._mine_view.position.x - rest.x)
			top = minf(top, st._mine_view.position.y - rest.y)
			sunk = maxi(sunk, st._scene.sink_mine)
			smoke = maxi(smoke, st._heavy.plume.puffs())
		if until < 0.0 and Router.current is SectorScreen and not ZoomLadder.busy():
			until = _t - t0
			break
	_ok("UNDOCK runs the shared lift on the deck", used)
	_ok("off its stands (%.0f px up), the stands sink (%d rows), the smoke rolls (%d puffs), and away to the RIGHT (%.0f px)" % [
		-top, sunk, smoke, right], top <= -25.0 and sunk >= 25 and smoke >= 20 and right > 200.0)
	_ok("it lands on LOCAL undocked (%.2f s; the yard's part %.2f s)" % [until, ZoomLadder.UNDOCK_YARD_S],
		until > ZoomLadder.UNDOCK_YARD_S and Router.current is SectorScreen and not Router.docked)
	ZoomLadder.force = -1
	ZoomLadder.fixed_dt = -1.0
