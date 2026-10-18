extends Node

## THE MOONS KEEP OUT OF WHAT IS STAGED, headless (`LocalLife`):
##   godot --headless --path . -- sheet=MoonTest
## Jon (Oct 11): a moon going round the world you orbit must never pass over an
## event's subject, a station, or your ship during the dock. So:
##  1. on every world with moons in a few runs' galaxies -- the station systems'
##     among them, their side and the corridor your ship docks along standing
##     there -- each moon's chosen orbit, run for ten minutes of quiet, never
##     overlaps your ship, the station's side or the dock's corridor (a moon with
##     no clear orbit hangs still where it always did); some moons go round;
##  2. with an event's subject up, every moon holds still, and none is over any
##     of the subject's pieces;
##  3. in a fight, every moon holds still;
##  4. through the dock (the ladder's move, the station waking, your ship going
##     in), every moon holds still and none is over the station or your ship.
## Places are the sky's plan's (`LocalSky.near_plan`), which is where the picture
## puts them.

var _fails := 0
var _tree: SceneTree


func _ok(what: String, c: bool) -> bool:
	print("  %s %s" % ["ok  " if c else "FAIL", what])
	if not c:
		_fails += 1
	return c


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await _tree.process_frame


func _sky() -> LocalSky:
	var sc := Router.current as SectorScreen
	if sc == null or sc._view == null:
		return null
	return sc._view.backdrop


## LOCAL at body `bi` of system `idx`, parked there as the map leaves you.
func _park(idx: int, bi: int, options: Array = []) -> LocalSky:
	var node: MapGen.MapNode = Run.map[idx]
	node.visited = true
	if not options.is_empty():
		node.options.assign(options)
	Run.at = idx
	SectorScreen._approached_at = idx
	SystemMapScreen._parked[idx] = {"at": bi, "p": Vector2(900.0, -210.0), "v": Vector2.ZERO, "head": 0.0, "mode": &"rail"}
	Router.show_local()
	await _frames(6)
	return _sky()


## Every world with moons in the galaxy: [system, body].
func _mooned() -> Array:
	var out: Array = []
	for n: MapGen.MapNode in Run.map:
		if n.type == MapGen.NodeType.START:
			continue
		var L := SystemLayout.of(n)
		for bi in L.bodies.size():
			var b := L.bodies[bi]
			if b.world != &"" and (b.kind == &"planet" or b.kind == &"giant") and int(Worlds.spec(b.world, b.seed, 100.0).get("moons", 0)) > 0:
				out.append([n.index, bi, n.type == MapGen.NodeType.STATION])
	return out


## The moons' clocks, to see whether they moved.
func _phases(sky: LocalSky) -> Array:
	var out: Array = []
	for m: Dictionary in sky.life.moons:
		out.append(float(m.get("phase", 0.0)))
	return out


## The visible moving moons over any of `rects` (this sky's px): how many.
func _over(sky: LocalSky, rects: Array[Rect2]) -> int:
	var w := sky.life._world()
	if w.is_empty():
		return 0
	var bad := 0
	var places := sky.life.moon_places()
	for i in places.size():
		var pl: Array = places[i]
		if bool(pl[2]):
			continue
		if not LocalLife.clear_at(w.c, pl[0], pl[1], float(w.R), float(sky.life.moons[i].r), rects):
			bad += 1
	return bad


func _run() -> void:
	_tree = get_tree()
	await _tree.process_frame
	Router.animate_in_harness = true
	ZoomLadder.force = 1
	ZoomLadder.fixed_dt = 1.0 / 30.0

	# 1. every chosen orbit clear of your ship, and at a station of its side and
	# the dock's corridor, over ten minutes
	var n_worlds := 0
	var n_station := 0
	var moving := 0
	var held := 0
	var bad: Array[String] = []
	var station_world := []
	var giant_world := []
	for seed in [4242, 77, 1, 9]:
		Rng.forced = seed
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
		var list := _mooned()
		# (the station systems' worlds all, the rest a sample)
		var picked: Array = []
		var plain := 0
		for e: Array in list:
			if bool(e[2]):
				picked.append(e)
			elif plain < 14:
				picked.append(e)
				plain += 1
		for e: Array in picked:
			var sky := await _park(int(e[0]), int(e[1]))
			if sky == null or sky.life == null:
				bad.append("seed %d system %d body %d: no LOCAL" % [seed, e[0], e[1]])
				continue
			var station: bool = e[2]
			# (the station's side is drawn only AT the station, whose place has no
			# world and no moons: at a world of its system there is none -- dock:A)
			if station and sky.life.keep_out(true).size() > 1:
				bad.append("seed %d system %d: the station's side drawn at a world of its system" % [seed, e[0]])
			var a := sky.life.audit(600.0)
			n_worlds += 1
			if station:
				n_station += 1
				if station_world.is_empty():
					station_world = [seed, e[0], e[1]]
			moving += int(a.moving)
			held += int(a.held)
			for s: String in a.bad:
				bad.append("seed %d system %d body %d%s: %s" % [seed, e[0], e[1], " (station)" if station else "", s])
			if giant_world.is_empty() and not station and int(a.moving) > 0 and SystemLayout.of(Run.map[int(e[0])]).bodies[int(e[1])].kind == &"giant":
				giant_world = [seed, e[0], e[1]]
	_ok("%d worlds with moons (%d at stations): %d moons go round, %d hang still; over ten minutes none crosses your ship, a station's side or the dock's corridor (%s)" % [n_worlds,
		n_station, moving, held, "; ".join(bad.slice(0, 6)) if not bad.is_empty() else "clear"], bad.is_empty() and moving > 0 and n_station > 0)

	# 2. an event's subject up: every moon holds, none over its pieces
	if _ok("a giant with moons that go round to stage an event at", not giant_world.is_empty()):
		Rng.forced = int(giant_world[0])
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
		var tried := 0
		var still := true
		var over := 0
		var subjects := 0
		for oid: StringName in [&"the_rings", &"the_storm", &"slipping_orbit", &"the_scoop", &"dropped_load"]:
			if OptionTable.by_id(oid).is_empty():
				continue
			# (opened as the map opens one: the event asked for, the ship parked where
			# it sits, LOCAL shown -- `SubjectTest._open_at`)
			var node: MapGen.MapNode = Run.map[int(giant_world[1])]
			node.visited = true
			node.options.assign([oid])
			Run.at = node.index
			SectorScreen._approached_at = node.index
			SystemMapScreen._parked[node.index] = {"at": LocalEventDrawer.body_of(node, 0), "p": Vector2(900.0, -210.0), "v": Vector2.ZERO, "head": 0.0, "mode": &"rail"}
			LocalEventDrawer.quiet = true
			LocalEventDrawer.request(node.index, 0)
			Router.show_local()
			await _frames(25)
			var sky := _sky()
			LocalEventDrawer.quiet = false
			if sky == null or sky.life == null or sky.life._world().is_empty():
				continue
			if sky == null:
				continue
			var sub := LocalSubject.of(sky.get_parent())
			if sub == null or sub.drawn_rects().is_empty():
				continue
			subjects += 1
			tried += 1
			var p0 := _phases(sky)
			for f in 90:
				await _frames(1)
				over += _over(sky, sky.life.keep_out(false))
			if _phases(sky) != p0 or sky.life.quiet():
				still = false
		_ok("with an event's subject up (%d events), every moon holds still and none is over its pieces (%d frames over)" % [subjects, over],
			subjects > 0 and still and over == 0)
		# 3. a fight
		await _park(int(giant_world[1]), int(giant_world[2]))
		Router.start_combat(DB.enemies[&"cutter"], [], false)
		await _frames(20)
		var sky_f := _sky()
		if _ok("a fight opens on LOCAL at the giant", sky_f != null and sky_f.life != null):
			var p1 := _phases(sky_f)
			await _frames(90)
			_ok("in a fight every moon holds still", _phases(sky_f) == p1 and not sky_f.life.quiet())

	# 4. THE DOCK IS ONLY AT THE STATION (Jon, Oct 18, "dock:A"), whose own place
	# has no world and so no moons: a moon can never be over the station or your
	# ship through a dock. From a world with moons in a station's system there
	# is no station side, no DOCK, and the door refuses.
	if _ok("a station system with a world with moons", not station_world.is_empty()):
		Rng.forced = int(station_world[0])
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
		await _park(int(station_world[1]), int(station_world[2]))
		await _frames(30)
		var loc := Router.current as SectorScreen
		Router.show_station()
		await _frames(60)
		_ok("at a world of a station's system: no station side, no DOCK, and docking refused (still on LOCAL, docked %s)" % Router.docked,
			Router.current == loc and not Router.docked and loc._face == null and loc.find_child("Dock", true, false) == null)
	print("moontest: %s" % ("PASS" if _fails == 0 else "%d FAILURES" % _fails))
	_tree.quit(1 if _fails > 0 else 0)
