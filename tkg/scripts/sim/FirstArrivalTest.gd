extends Node

## A SYSTEM'S FIRST MAP OPENS ALL THE WAY OUT (Jon, Nov 21), headless:
##   -- sheet=FirstArrivalTest
## A new wide pair and new one-sun systems open at `zoom_min`; LOCAL and back,
## a second visit and a restored run open on `open_zoom` as they always did.

var h := Harness.new()


func _ready() -> void:
	_run.call_deferred()


func _idle() -> void:
	for i in 900:
		if not ZoomLadder.busy() and ZoomLadder.chain == &"":
			return
		await get_tree().process_frame


## The map up for system `n`, its ship in place, or null.
func _map_of(n: MapGen.MapNode) -> SystemMapScreen:
	await _idle()
	for i in 300:
		var m := Router.current as SystemMapScreen
		if m != null and m.flight != null and m.view.layout != null and m.view.node == n:
			await Harness.frames(get_tree(), 4)
			return m
		await get_tree().process_frame
	return null


## A system the ship can jump to now: no ambush, a full tank.
func _jumpable(want: Callable) -> MapGen.MapNode:
	Run.fuel = 999
	for raw in Run.map:
		var c: MapGen.MapNode = raw
		if c.index == Run.at or c.visited or c.region == MapGen.Region.FAUNA or not want.call(c):
			continue
		c.sensed = true
		if Run.can_jump_to(c):
			c.ambush_rolled = true
			c.ambush_pending = false
			return c
	return null


func _jump(n: MapGen.MapNode, through_router: bool) -> SystemMapScreen:
	Run.fuel = 999
	n.ambush_rolled = true
	n.ambush_pending = false
	if through_router:
		Router.commit_jump(n.index)
	else:
		# (the arrival flag is not set: as when LOCAL took it for an ambush)
		Run.jump_to(n.index)
	return await _map_of(n)


func _out(m: SystemMapScreen, what: String) -> void:
	h._ok("%s: the map opens all the way out (zoom %.4f, zoom_min %.4f, looking at %s)" % [
		what, m.view.zoom, m.zoom_min, m._look_at()],
		absf(m.view.zoom - m.zoom_min) < 1e-6 and m._look_at().length() < 0.5)


func _as_before(m: SystemMapScreen, what: String) -> void:
	h._ok("%s: the map opens on its opening framing (zoom %.4f, open_zoom %.4f, looking at %s, home %s)" % [
		what, m.view.zoom, m.open_zoom, m._look_at(), m.home_at],
		absf(m.view.zoom - m.open_zoom) < 1e-6 and m._look_at().distance_to(m.home_at) < 0.5)


func _run() -> void:
	await get_tree().process_frame
	h.seed_run(4242)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	SystemMapScreen._location_on = false
	await Harness.frames(get_tree(), 10)

	# A WIDE PAIR, first arrival through the jump's own door
	var pair := _jumpable(func(c: MapGen.MapNode) -> bool:
		return MapGen.twin_ok(c) and not SystemLayout.is_close(c))
	if not h._ok("a system to make a wide pair", pair != null):
		_end()
		return
	pair.twin = true
	var L := SystemLayout.of(pair)
	h._ok("it is laid out as a wide pair", L.twin and L.pair_box(0.0).size != Vector2.ZERO)
	var m := await _jump(pair, true)
	if not h._ok("the map comes up in %s after the jump" % MapGen.star_name(pair), m != null):
		_end()
		return
	h._ok("its opening framing is nearer than the whole system (%.4f against %.4f), so the two differ" % [
		m.open_zoom, m.zoom_min], m.open_zoom > m.zoom_min * 1.5)
	_out(m, "first arrival in a wide pair")
	h._ok("not a first arrival once the map has opened", not SystemMapScreen.first_arrival(pair))
	await _shots(m)

	# The same visit, down to LOCAL and back up: as it always was
	Router.show_local()
	await _idle()
	await Harness.frames(get_tree(), 4)
	Router.show_system()
	m = await _map_of(pair)
	if h._ok("the map comes back up after LOCAL", m != null):
		_as_before(m, "the same visit, back from LOCAL")

	# A ONE-SUN SYSTEM, its arrival flag taken before the map (an ambush's LOCAL)
	var one := _jumpable(func(c: MapGen.MapNode) -> bool:
		return c.type == MapGen.NodeType.SYSTEM and not c.twin)
	if not h._ok("a one-sun system to jump to", one != null):
		_end()
		return
	m = await _jump(one, false)
	if h._ok("the map comes up in %s" % MapGen.star_name(one), m != null):
		_out(m, "first arrival in one sun, the arrival flag already taken")

	# BACK INTO THE PAIR: a second visit opens as it always did
	if not h._ok("the pair can be jumped to again", Run.can_jump_to(pair) or _refuel_can(pair)):
		_end()
		return
	m = await _jump(pair, true)
	if h._ok("the map comes up in %s again" % MapGen.star_name(pair), m != null):
		h._ok("the pair is twice in the trail", Run.trail.count(pair.index) == 2)
		_as_before(m, "the second visit to the wide pair")

	# A FRESH SYSTEM, SAVED AND RESTORED: resuming is not arriving
	var third := _jumpable(func(c: MapGen.MapNode) -> bool:
		return c.type == MapGen.NodeType.SYSTEM and not c.twin)
	if h._ok("a third system to jump to", third != null):
		m = await _jump(third, true)
		if h._ok("the map comes up in %s" % MapGen.star_name(third), m != null):
			_out(m, "first arrival in a third system")
		SaveGame.save()
		var ok := SaveGame.load_into_run()
		h._ok("the run saves and loads", ok)
		h._ok("the trail comes back with the third system once (%d)" % Run.trail.count(third.index),
			Run.trail.count(third.index) == 1)
		h._ok("a restored run counts its map as opened (opened_jump %d, jumps %d)" % [
			SystemMapScreen.opened_jump, Run.jumps],
			SystemMapScreen.opened_jump == Run.jumps and not SystemMapScreen.first_arrival(Run.node_at()))
		var fourth := _jumpable(func(c: MapGen.MapNode) -> bool:
			return c.type == MapGen.NodeType.SYSTEM and not c.twin)
		if h._ok("a fourth system after the load", fourth != null):
			m = await _jump(fourth, true)
			if h._ok("the map comes up in %s" % MapGen.star_name(fourth), m != null):
				_out(m, "first arrival after a load")
	_end()


## `shots=<dir>` (windowed): the first arrival as it opens now, then the framing the map
## opened on before (`open_zoom`, `home_at`, as `show_system` set them), each at 2x.
func _shots(m: SystemMapScreen) -> void:
	var dir := Harness.arg("shots")
	if dir == "" or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(dir)
	await Harness.frames(get_tree(), 240)
	_save(dir.path_join("after_first_arrival_2x.png"))
	m.view.zoom = m.open_zoom
	m.view.pan = -m.home_at * m.open_zoom
	m._zoom_to = m.open_zoom
	await Harness.frames(get_tree(), 120)
	_save(dir.path_join("before_first_arrival_2x.png"))
	m.view.zoom = m.zoom_min
	m.view.pan = Vector2.ZERO
	m._zoom_to = m.zoom_min


func _save(path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	if img.get_width() < 1500:
		img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
	img.save_png(path)
	print("  shot %s (%dx%d)" % [path, img.get_width(), img.get_height()])


func _refuel_can(n: MapGen.MapNode) -> bool:
	Run.fuel = 999
	n.sensed = true
	return Run.can_jump_to(n)


func _end() -> void:
	SaveGame.clear()
	h.verdict("firstarrivaltest")
	get_tree().quit(h.code())
