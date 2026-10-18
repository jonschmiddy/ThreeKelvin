extends Node

## A.S.H. PHOTOGRAPHED where she is seen (`Ash`, `AshPortrait`). Needs a window.
##
##   godot --path . --windowed --resolution 1920x1080 --position 3840,0 -- sheet=AshShot keepwindow out=<dir> mode=stills
##       LOCAL with her launch line up, and a fight of three with her heat line
##       up, each held once the line is all out: `<name>.png` the 1080p window as
##       the player sees it, `<name>_1x.png` the game's own 960x540.
##   ... mode=options [screens=a,b] [spots=a,b]
##       Every spot she was considered for (`Ash.ALL_SPOTS`) on LOCAL and three
##       fights, her line up at each whatever is under it (`Ash.force_spot`):
##       `options/<screen>__<spot>.png` (1x), and `options.json`: each spot's
##       box and what it covers, named (`AshTest`'s own list).
##   godot --path . --fixed-fps 60 --windowed ... -- sheet=AshShot out=<dir> mode=closeup
##       Her launch line said on LOCAL, every frame from her first to her last
##       cropped round her at 1x into `closeup/f_####.png` (`crop.json` says
##       where), on the game's clock, so 60 a second is true speed.

var _args: PackedStringArray
var _tree: SceneTree
var _out := ""
var _test: Node = null

const SCREENS := ["local", "fight_one", "fight_pair", "fight_three"]


func _arg(k: String, d: String = "") -> String:
	for a in _args:
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d


func _ready() -> void:
	_args = OS.get_cmdline_user_args()
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await _tree.process_frame


func _run() -> void:
	_tree = get_tree()
	_out = _arg("out", "user://ashshot")
	DirAccess.make_dir_recursive_absolute(_out)
	await _frames(4)
	Ash.forced = true
	Ash.reload()
	Ash.set_on(true)
	_test = load("res://scripts/sim/AshTest.gd").new()
	match _arg("mode", "stills"):
		"stills":
			await _stills()
		"options":
			await _options()
		"closeup":
			await _closeup()
	_tree.quit()


## Up on `screen`, with nothing said and nothing waiting.
func _screen(screen: String) -> SectorScreen:
	var weight := HullData.Weight.MEDIUM
	var seed_v := int(_arg("seed", "4242"))
	Rng.forced = seed_v
	Run.start_new_run(&"korvan", weight)
	for m: MapGen.MapNode in Run.map:
		if m.type == MapGen.NodeType.SYSTEM and not Router.no_fights_at(m):
			Run.at = m.index
			break
	Run.map[Run.at].visited = true
	SectorScreen._approached_at = Run.at
	if screen == "local":
		Run.new_wreck(Run.node_at(), DB.enemies[&"cutter"], 0)
		Run.new_wreck(Run.node_at(), DB.enemies[&"marauder"], 0)
	Router.show_local()
	await _frames(90)
	var foes: Array = []
	match screen:
		"fight_one":
			foes = [&"cutter"]
		"fight_pair":
			foes = [&"marauder", &"cutter"]
		"fight_three":
			foes = [&"cutter", &"lancer", &"marauder"]
	if not foes.is_empty():
		var extras: Array = []
		for x in foes.slice(1):
			extras.append(DB.enemies[x])
		Run.node_at().danger = maxi(Run.node_at().danger, 4)
		Router.start_combat(DB.enemies[foes[0]], extras, false, false)
		await _frames(150)
	_quiet()
	return Router.current as SectorScreen


func _quiet() -> void:
	Ash.waiting.clear()
	if Ash.portrait != null:
		Ash.portrait.cut()
	Ash.poll(0.0)
	Ash._last_end = -INF


## Her line up and all out, held a moment.
func _speak(sc: SectorScreen, line: String = "") -> bool:
	var kind := &"hot" if sc.fighting() else &"launch"
	if sc.fighting():
		Run.heat = Run.heat_cap() + 2
		Sig.resources_changed.emit()
	if line != "":
		Ash._bags[kind] = [line]
	Ash.arm(kind)
	for i in 400:
		await _tree.process_frame
		var p := Ash.portrait
		if p != null and p.phase == AshPortrait.Phase.HOLDING:
			await _frames(30)
			return true
	print("[ashshot] she did not speak (held by %s)" % Ash.held_by)
	return false


func _save(name: String, window: bool = true) -> void:
	await RenderingServer.frame_post_draw
	if window:
		_tree.root.get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	GameShell.input_target(_tree).get_texture().get_image().save_png("%s/%s_1x.png" % [_out, name])
	print("[ashshot] %s" % name)


func _stills() -> void:
	var sc := await _screen("local")
	if await _speak(sc, "Launch clearance granted. By me. I'm the only one here."):
		await _save("local")
	sc = await _screen("fight_three")
	if await _speak(sc, "Bold of you to treat the heat cap as a suggestion."):
		await _save("fight")
	Run.heat = 0


func _options() -> void:
	var screens := _arg("screens", ",".join(SCREENS)).split(",")
	var spots := _arg("spots", ",".join(Ash.ALL_SPOTS)).split(",")
	DirAccess.make_dir_recursive_absolute(_out + "/options")
	var doc := {}
	for scr in screens:
		var rows := {}
		for sp in spots:
			var sc := await _screen(scr)
			Ash.force_spot = StringName(sp)
			var said := await _speak(sc, "Fuel's full. Optimism's at about half." if not sc.fighting()
				else "I'd vent. But you're the pilot.")
			Ash.force_spot = &""
			if not said:
				continue
			var r: Rect2 = Ash.portrait.rect()
			var face := Ash.portrait.face_rect()
			var hits: Array = []
			for b: Array in _test._boxes(sc):
				var x: Rect2 = b[1]
				if x.size.x > 0.0 and x.size.y > 0.0 and r.intersects(x):
					hits.append({what = b[0], rect = [x.position.x, x.position.y, x.size.x, x.size.y]})
			rows[sp] = {rect = [r.position.x, r.position.y, r.size.x, r.size.y],
				face = [face.position.x, face.position.y, face.size.x, face.size.y], hits = hits}
			await _save("options/%s__%s" % [scr, sp], false)
			Run.heat = 0
		doc[scr] = rows
	var f := FileAccess.open(_out + "/options.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(doc, " "))
	f.close()


func _closeup() -> void:
	var sc := await _screen("local")
	var dir := _out + "/closeup"
	DirAccess.make_dir_recursive_absolute(dir)
	Ash._bags[&"launch"] = ["Autonomous Systems Handler, reporting. Please don't make me handle much."]
	Ash.arm(&"launch")
	var k := 0
	var crop := Rect2()
	var started := false
	for i in 1200:
		await RenderingServer.frame_post_draw
		var p := Ash.portrait
		if p == null:
			continue
		if not started:
			if not p.visible:
				continue
			started = true
			crop = p.rect().grow(8.0)
			var f := FileAccess.open(dir + "/crop.json", FileAccess.WRITE)
			f.store_string(JSON.stringify({x = crop.position.x, y = crop.position.y, w = crop.size.x, h = crop.size.y,
				fps = Engine.physics_ticks_per_second}))
			f.close()
		var img := GameShell.input_target(_tree).get_texture().get_image()
		img.get_region(Rect2i(crop)).save_png("%s/f_%04d.png" % [dir, k])
		k += 1
		if started and p.phase == AshPortrait.Phase.GONE:
			# a few frames of her gone, so the clip ends on the sky
			if k > 0 and i > 0:
				for j in 10:
					await RenderingServer.frame_post_draw
					GameShell.input_target(_tree).get_texture().get_image().get_region(Rect2i(crop)) \
						.save_png("%s/f_%04d.png" % [dir, k])
					k += 1
			break
	print("[ashshot] closeup %d frames" % k)
