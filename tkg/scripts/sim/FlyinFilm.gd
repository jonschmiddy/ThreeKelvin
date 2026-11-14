extends Node

## Films LOCAL's arrival and the station's wake with sound (Jon, Oct 21, 'station:BC').
## Why: docs/why/FlyinFilm.md#flyin-film

var _tree: SceneTree


func _ready() -> void:
	_run.call_deferred()


func _idle() -> void:
	for i in 900:
		await _tree.process_frame
		if not ZoomLadder.busy() and ZoomLadder.chain == &"":
			break


func _mark(what: String) -> void:
	print("mark %s frame %d (%.2f s)" % [what, Engine.get_frames_drawn(), float(Engine.get_frames_drawn()) / 30.0])


## The map's ship flown to `b`, until it is settled in orbit.
func _fly(b: int) -> bool:
	var m := Router.current as SystemMapScreen
	if m == null:
		return false
	for i in 300:
		if m.flight != null and m.flight.can_fly():
			break
		await _tree.process_frame
	_mark("fly to body %d" % b)
	m.fly_to_body(b)
	# (a flight on map time takes up to 30 s and its ride 4.4 s first, ruling 20)
	for i in 3600:
		await _tree.process_frame
		if not is_instance_valid(m):
			return false
		if m.flight.reached() == b and m.flight.can_fly():
			await Harness.frames(_tree, 15)
			return true
	return false


## LOCAL by the HUD's tab, and held until its arrival and the station's wake are
## over, then `hold` frames more.
func _local(what: String, hold: int) -> void:
	_mark("LOCAL pressed (%s)" % what)
	Router.hud._tab_sector.pressed.emit()
	await Harness.frames(_tree, 1)
	await _idle()
	var sc := Router.current as SectorScreen
	for i in 600:
		await _tree.process_frame
		if sc == null or not is_instance_valid(sc):
			break
		if sc._flyin:
			continue
		if not sc._flyin_wait and not sc._wake_owed and sc._wake_t < 0.0 and sc._phase == SectorScreen.Phase.NONE:
			break
	_mark("%s settled (fly-ins so far %d, station lit %s)" % [what, SectorScreen.flyins,
		sc._face.power if sc != null and is_instance_valid(sc) and sc._face != null else -1.0])
	await Harness.frames(_tree, hold)


func _run() -> void:
	_tree = get_tree()
	await _tree.process_frame
	Router.animate_in_harness = true
	ZoomLadder.force = 1
	ZoomLadder.fixed_dt = 1.0 / 30.0
	Rng.forced = Harness.seed_arg(11)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	StarchartScreen._primed_for = Run.galaxy_seed
	var st := -1
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		n.ambush_rolled = true
		n.ambush_pending = false
		if st < 0 and n.type == MapGen.NodeType.STATION:
			st = n.index
	if st < 0:
		print("no station")
		_tree.quit(1)
		return
	Run.at = st
	Run.map[st].visited = true
	Run.fuel = 99
	SectorScreen._approached_at = st
	var L := SystemLayout.of(Run.map[st])
	var dock := L.dock_place()
	var world := -1
	for b in L.bodies:
		if b.index != dock and b.world != &"" and b.kind != &"belt":
			world = b.index
			break
	if world < 0:
		print("no world beside the station")
		_tree.quit(1)
		return
	var route := Harness.arg("route", "world")
	if route == "world":
		Router.park_at_station()
	else:
		ParkedShips.spots[st] = {"at": world, "mode": &"rail"}
	Router.show_system()
	await _idle()
	await Harness.frames(_tree, 30)
	_mark("map")
	if route == "world":
		if await _fly(world):
			await _local("the world", 45)
	else:
		if await _fly(dock):
			await _local("the station", 45)
			_mark("to the map, no flight")
			Router.show_system()
			await _idle()
			await Harness.frames(_tree, 30)
			await _local("the station again", 60)
	_mark("end")
	_tree.quit(0)
