extends Node

## ONE BLACK HOLE AT THE CORE, ONE PULSAR AT A PULSAR, headless:
##   godot --headless --path . -- sheet=OneHoleTest
## Jon, Oct 13, at the core: "why are there two black holes lololool". LOCAL's
## sky draws the system's own star -- the core's hole (`CoreLegacy`, the hole
## every style shares) and a pulsar with its beams -- and the encounter's place
## picture (`EncounterView.AreaView`) drew it a second time beside your ship.
## For several galaxies: at the core and at every pulsar the place picture is
## empty while the sky's star is that star; every other kind of system keeps
## its place picture (a station, a beacon, a battlefield, a derelict).

var _fails := 0


func _ok(what: String, c: bool) -> bool:
	print("  %s %s" % ["ok  " if c else "FAIL", what])
	if not c:
		_fails += 1
	return c


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	var seen := {}
	for seed in [4242, 31337, 7, 99]:
		Rng.forced = seed
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
		var area := EncounterView.AreaView.new()
		for n: MapGen.MapNode in Run.map:
			area.node = n
			var what := area._place_name()
			var star := SystemLayout.of(n).star
			match n.type:
				MapGen.NodeType.CORE:
					seen[&"core"] = int(seen.get(&"core", 0)) + 1
					if not _ok("seed %d: the core draws no place picture, the sky's star is its hole" % seed,
							what == &"" and star == SystemLayout.StarKind.CORE):
						print("        place %s, star %d" % [what, star])
				MapGen.NodeType.PULSAR:
					seen[&"pulsar"] = int(seen.get(&"pulsar", 0)) + 1
					if not _ok("seed %d node %d: a pulsar draws no place picture, the sky's star is the pulsar" % [seed, n.index],
							what == &"" and star == SystemLayout.StarKind.PULSAR):
						print("        place %s, star %d" % [what, star])
				MapGen.NodeType.START:
					pass
				_:
					seen[what] = int(seen.get(what, 0)) + 1
					if what == &"":
						_ok("seed %d node %d (type %d) keeps its place picture" % [seed, n.index, n.type], false)
		area.free()
	# THE REAL LOCAL AT THE CORE, in both looks: no place picture; look A's hole
	# up on the band, look B's big one clear of your ship and of the strip
	# along the bottom, inside the view
	for big in [false, true]:
		await _local_core(big)
	LocalSky.core_big = false
	print("  places seen: %s" % str(seen))
	_ok("the core was seen", int(seen.get(&"core", 0)) > 0)
	_ok("a pulsar was seen", int(seen.get(&"pulsar", 0)) > 0)
	_ok("stations and systems still have their pictures",
		int(seen.get(&"station", 0)) > 0 and int(seen.get(&"beacon", 0)) + int(seen.get(&"battlefield", 0)) > 0)
	print("oneholetest: %s (%d failed)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(1 if _fails > 0 else 0)


func _local_core(big: bool) -> void:
	LocalSky.core_big = big
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var core := -1
	for n: MapGen.MapNode in Run.map:
		if n.type == MapGen.NodeType.CORE:
			core = n.index
	Run.at = core
	SectorScreen._approached_at = core
	Router.show_local()
	for i in 6:
		await get_tree().process_frame
	var sc := Router.current as SectorScreen
	var look := "B" if big else "A"
	if not _ok("look %s: LOCAL opens at the core" % look, sc != null and sc._view != null):
		return
	var view: EncounterView = sc._view
	_ok("look %s: no place picture at the core" % look, view._area._place_name() == &"")
	var sky: LocalSky = view.backdrop
	var hole := sky.hole_box()
	if not big:
		_ok("look A: the hole is the band's star, up top (%s)" % str(hole), hole.get_center().y < 140.0)
		return
	var sv := view.ship_view()
	var sr: Rect2 = sv.ship_rect()
	var ship := Rect2(sv.get_global_rect().position + sr.position, sr.size)
	_ok("look B: the hole (%s) is clear of your ship (%s)" % [str(hole), str(ship)], not hole.intersects(ship))
	var vr := view.get_global_rect()
	_ok("look B: the hole is inside the view (%s)" % str(vr), vr.encloses(hole))
	for c: Control in [sc._quiet_wrap, sc._events]:
		if c != null and c.is_visible_in_tree():
			_ok("look B: the hole is clear of the strip along the bottom (%s)" % str(c.get_global_rect()),
				not hole.intersects(c.get_global_rect()))
