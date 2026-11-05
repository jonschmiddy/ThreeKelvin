extends Node

## THE MAP_FLY LINE ON THE SECTOR MAP, as the game draws it:
##   godot --path . --windowed --resolution 1920x1080 -- sheet=MapFlyShot ash hints out=<dir> [seed=4242] [node=N]
##
## A run under way (its jump made, every other hint and step seen), the ship
## circling the star as it arrived, in a one-sun system with one world
## (`one.png`), one with the most worlds (`many.png`), the first binary
## (`binary.png`, ORBITING BOTH STARS) and, with `node=N`, system N
## (`nodeN.png`): A.S.H. says "Click a
## world twice and we fly there. Or fly us by hand." with her outline on the
## world nearest the ship (Jon, Nov 4: "Shouldn't a world be highlighted here
## and not my ship?"). Each still is the whole window and a crop round the
## outline and the ship at window scale (`_crop.png`). Prints the system, the
## world and the boxes. Needs a window.

var _args: PackedStringArray
var _out := ""
var _tree: SceneTree


func _arg(k: String, d: String = "") -> String:
	for a in _args:
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d


func _ready() -> void:
	_args = OS.get_cmdline_user_args()
	_run.call_deferred()


func _secs(s: float) -> void:
	var t0 := GameClock.now()
	while GameClock.now() - t0 < s:
		await _tree.process_frame


func _worlds(L: SystemLayout) -> int:
	var n := 0
	for b in L.bodies:
		if b.kind == &"planet" or b.kind == &"giant":
			n += 1
	return n


func _run() -> void:
	_tree = get_tree()
	_out = _arg("out", "user://mapflyshot")
	DirAccess.make_dir_recursive_absolute(_out)
	await _tree.process_frame
	Ash.forced = true
	Ash.reload()
	Ash.set_on(true)
	Hints.forced = true
	Hints.reset()
	Ash.reload()
	Rng.forced = int(_arg("seed", "4242"))
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Ash.mark_intro(true)
	for id in Hints.ORDER:
		if id != &"map_fly":
			Hints.mark_seen(id)
	for id in Hints.STEPS:
		Hints.mark_seen(id)
	for id in Hints.STEP_LINES:
		Hints.mark_seen(StringName("said_" + String(id)))
	Run.jumps = 1
	# the systems: one sun, no station; one world, and the most worlds
	var one: MapGen.MapNode = null
	var many: MapGen.MapNode = null
	var twin: MapGen.MapNode = null
	var most := 0
	for raw in Run.map:
		var m: MapGen.MapNode = raw
		if m.type != MapGen.NodeType.SYSTEM:
			continue
		var L := SystemLayout.of(m)
		if L.twin:
			if twin == null and _worlds(L) > 0:
				twin = m
			continue
		var w := _worlds(L)
		if w == 1 and one == null:
			one = m
		if w > most:
			most = w
			many = m
	var shots: Array = [[one, "one"], [many, "many"], [twin, "binary"]]
	var nn := int(_arg("node", "-1"))
	if nn >= 0 and nn < Run.map.size():
		shots.append([Run.map[nn], "node%d" % nn])
	for pair in shots:
		var m: MapGen.MapNode = pair[0]
		if m == null:
			print("[mapflyshot] MISSING %s: no such system on seed %s" % [pair[1], _arg("seed", "4242")])
			continue
		Hints.mark_seen(&"map_fly", false)
		Run.at = m.index
		m.visited = true
		Router.show_system()
		var t0 := GameClock.now()
		while GameClock.now() - t0 < 20.0 and not (Ash.lesson == &"map_fly" and Ash.portrait != null
				and Ash.portrait.phase == AshPortrait.Phase.HOLDING):
			await _tree.process_frame
		if Ash.lesson != &"map_fly":
			print("[mapflyshot] MISSING map_fly on %s" % pair[1])
			continue
		await _secs(0.5)
		await RenderingServer.frame_post_draw
		var map := Router.current as SystemMapScreen
		var p := Hints._map_fly_probe(map, Hints._hud_rect())
		var w := int(p.get("world", -1))
		var L: SystemLayout = map.view.layout
		var g := map._box.get_global_transform()
		var ship: Vector2 = g * map.overlay._ship_at
		var img := _tree.root.get_texture().get_image()
		img.save_png("%s/%s.png" % [_out, pair[1]])
		var k := float(img.get_width()) / get_viewport().get_visible_rect().size.x
		var o := Ash.outline_rect()
		var r := o.expand(ship).grow(40.0)
		var px := Rect2i(Vector2i(r.position * k), Vector2i(r.size * k)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		img.get_region(px).save_png("%s/%s_crop.png" % [_out, pair[1]])
		print("[mapflyshot] %s: system %d (%d worlds, %s), ship %s (%s); outline %s on body %d %s (%s), at %s" % [
			pair[1], m.index, _worlds(L), map.view.layout.bodies.size(), ship, map.overlay.ship_status()[0], o, w,
			L.bodies[w].name if w >= 0 else "the ship", L.bodies[w].kind if w >= 0 else &"", g * map.view.at[w] if w >= 0 else ship])
		Hints.spend()
		await _secs(1.0)
	Ash.forced = false
	Hints.forced = false
	_tree.quit(0)
