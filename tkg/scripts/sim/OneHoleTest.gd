extends Node

## Jon, Oct 13: two black holes at the core, as the place picture redrew the sky's star.
## Why: docs/why/OneHoleTest.md#one-hole

var h := Harness.new()
## how many of the core's looks were opened and measured (a run that errored
## out of them must not pass by checking nothing)
var _looked := 0


func _ok(what: String, c: bool) -> bool:
	return h._ok(what, c)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	var seen := {}
	for seed in [4242, 31337, 7, 99]:
		Rng.forced = seed
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
		var area := AreaView.new()
		for n: MapGen.MapNode in Run.map:
			area.node = n
			var what := area.place_name()
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
				# A STATION'S RING ONLY AT THE STATION (dock:A): none at the edge
				# of its system, its own picture once parked beside it
				MapGen.NodeType.STATION:
					SystemMapScreen._parked.erase(n.index)
					_ok("seed %d node %d: a station's system draws no ring away from the station" % [seed, n.index],
						area.place_name() == &"")
					Router.park_at_station(n)
					what = area.place_name()
					seen[what] = int(seen.get(what, 0)) + 1
					if what != &"station":
						_ok("seed %d node %d: a station keeps its picture at the station (%s)" % [seed, n.index, what], false)
					SystemMapScreen._parked.erase(n.index)
				_:
					seen[what] = int(seen.get(what, 0)) + 1
					if what == &"":
						_ok("seed %d node %d (type %d) keeps its place picture" % [seed, n.index, n.type], false)
		area.free()
	# Real LOCAL at the core in every hole look; the huge glow runs off the play on purpose.
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
	h.verdict("oneholetest")
	get_tree().quit(h.code())


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
		view._area.place_name() == &"" and sky._near.is_empty())
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
