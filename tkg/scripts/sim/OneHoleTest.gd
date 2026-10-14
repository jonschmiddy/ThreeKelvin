extends Node

## ONE BLACK HOLE AT THE CORE, ONE PULSAR AT A PULSAR, headless:
##   godot --headless --path . -- sheet=OneHoleTest
## Jon, Oct 13, at the core: "why are there two black holes lololool". LOCAL's
## sky draws the system's own star -- the core's hole (`CoreLegacy`, the hole
## every style shares) and a pulsar with its beams -- and the encounter's place
## picture (`EncounterView.AreaView`) drew it a second time beside your ship.
## For several galaxies: at the core and at every pulsar the place picture is
## empty while the sky's star is that star; every other kind of system keeps
## its place picture (a station, a beacon, a battlefield, a derelict). Then the
## real LOCAL at the core in every look of its hole (`LocalSky.core_look`): drawn
## once, centred, its black shadow whole between the HUD and the bottom strip
## (the large look's whole disc too; the huge look's glow runs off on purpose,
## the high ones' off the top).

var _fails := 0
## how many of the core's looks were opened and measured (a run that errored
## out of them must not pass by checking nothing)
var _looked := 0


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
	# THE REAL LOCAL AT THE CORE, in every look of its hole (`LocalSky.core_look`):
	# no place picture, no near world, the one hole centred, its black shadow
	# whole in the play (under the HUD, over the bottom strip), its disc too
	# but for the huge look, whose glow runs off the play on purpose
	var was: StringName = LocalSky.core_look
	for look in LocalSky.CORE_LOOKS:
		LocalSky.core_look = look
		for seed in [4242, 31337]:
			await _local_core(seed, look)
	LocalSky.core_look = was
	_ok("every look of the core opened and measured (%d)" % _looked, _looked == LocalSky.CORE_LOOKS.size() * 2)
	print("  places seen: %s" % str(seen))
	_ok("the core was seen", int(seen.get(&"core", 0)) > 0)
	_ok("a pulsar was seen", int(seen.get(&"pulsar", 0)) > 0)
	_ok("stations and systems still have their pictures",
		int(seen.get(&"station", 0)) > 0 and int(seen.get(&"beacon", 0)) + int(seen.get(&"battlefield", 0)) > 0)
	print("oneholetest: %s (%d failed)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(1 if _fails > 0 else 0)


func _local_core(seed: int, look: StringName) -> void:
	Rng.forced = seed
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
	var tag := "look %s seed %d" % [look, seed]
	if not _ok("%s: LOCAL opens at the core" % tag, sc != null and sc._view != null):
		return
	var view: EncounterView = sc._view
	var sky: LocalSky = view.backdrop
	_ok("%s: no place picture and no near world at the core" % tag,
		view._area._place_name() == &"" and sky._near.is_empty())
	var hole := sky.hole_box()
	var c := sky.origin()
	var sr := sky.core_shadow_r() * 1.25
	var shadow := Rect2(c - Vector2(sr, sr), Vector2(sr * 2.0, sr * 2.0))
	_ok("%s: the hole (%s) is centred" % [tag, str(hole)], absf(c.x - 480.0) <= 24.0)
	# the play: under the HUD, over the strip along the bottom
	var top := 42.0
	var bottom := 540.0
	for ctl: Control in [sc._quiet_wrap, sc._events]:
		if ctl != null and ctl.is_visible_in_tree():
			bottom = minf(bottom, ctl.get_global_rect().position.y)
	var play := Rect2(8.0, top, 944.0, bottom - top)
	_ok("%s: its black shadow (%s) is whole in the play (%s)" % [tag, str(shadow), str(play)], play.encloses(shadow))
	if look == &"b":
		_ok("%s: its glow runs off the play's top and bottom" % tag, hole.position.y < top and hole.end.y > bottom)
	elif look == &"a":
		_ok("%s: its disc is in the play" % tag, play.encloses(hole))
	_looked += 1
