extends Node

## LOCAL'S LIFE FILMED (`LocalLife`: the air, the city lights, the moons, the
## traffic), each frame both ways:
##   godot --path . --windowed --position 3840,0 --fixed-fps 30 -- sheet=LocalLifeShot
##       out=<dir> [cases=<case>[:<hide>[:approach]],...] [hide=air|night|moons|traffic|all]
##       [frames=240] [warm=70] [style=simplified|painted|radiant|legacy]
##       [approach] [bench]
## For each case: a new run (its seed), the ship parked as the sector map leaves
## it, LOCAL shown; then `frames` frames, each saved TWICE -- as played
## (`<case>/after/f_####.png`), and the same frame drawn again with what `hide`
## names taken away (`LocalLife.hide`; no clock moved in a forced draw, the
## worlds' surface memories held: `<case>/before/f_####.png`) -- so the two
## differ by that alone (a case may name its own `hide`, and `approach`; its
## folder is then `<case>_<hide>`). The game's 960x540 picture. The clocks step 1/30 s a
## frame (run with `--fixed-fps 30`). `approach`: the ship flies in, as it does
## arriving from the map. `bench`: the air's and the city lights' GPU time, each
## drawn 40 times over in a viewport of its own, on and off alternated (the GPU
## is shared, and a sliver of a millisecond is lost in a whole frame's noise).
## LocalLife's own CPU a frame is printed for every case. Needs a window.

const SkyWeatherS := preload("res://scripts/ui/sysmap/SkyWeather.gd")
## name: [sky, seed, orbit]
const CASES := {
	"giant": ["reflection", 4242, "giant"],
	"world": ["reflection", 4242, "world"],
	"emission": ["emission", 1, ""],
	"calm": ["calm", 4242, ""],
	"star": ["reflection", 4242, "star"],
	"settled": ["*", 4242, "settled"],
	"settled2": ["*", 77, "settled"],
	"capital": ["*", 4242, "capital"],
	"station": ["*", 1, "station"],
	"ringed2": ["*", 77, "giant"],
	# everything at once: a settled system, a world with air, dry ground and moons
	"all": ["*", 4242, "all"],
}
const GROUND := [&"rock", &"desert", &"iron", &"ice", &"verdant", &"ocean", &"toxic", &"city", &"hurricane",
	&"aurora", &"swamp", &"eyeball", &"cracked", &"megacity", &"crystal", &"haze"]
const IDEAS: Array[StringName] = [&"air", &"night", &"moons", &"traffic"]

var _args: PackedStringArray
var _tree: SceneTree
var _hide: Array[StringName] = []
var _approach := false


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
		await RenderingServer.frame_post_draw
		if ShipView.shot_clock >= 0.0:
			ShipView.shot_clock += 1.0 / 30.0


func _img() -> Image:
	return GameShell.input_target(_tree).get_texture().get_image()


func _run() -> void:
	_tree = get_tree()
	await _tree.process_frame
	Router.animate_in_harness = true
	ShipView.shot_clock = 0.0
	var out := _arg("out", "user://life")
	var nf := int(_arg("frames", "240"))
	for spec in _arg("cases", "giant").split(","):
		var bits := (spec as String).split(":")
		var cname := bits[0]
		var h := bits[1] if bits.size() > 1 else _arg("hide", "all")
		_approach = (bits.size() > 2 and bits[2] == "approach") or "approach" in _args
		_hide.clear()
		for nm in IDEAS:
			if h == "all" or String(nm) in h.split("+"):
				_hide.append(nm)
		if not CASES.has(cname):
			print("life: no case ", cname)
			continue
		var c: Array = CASES[cname]
		if not await _show(String(c[0]), int(c[1]), String(c[2])):
			print("life: %s: no system" % cname)
			continue
		await _frames(int(_arg("warm", "70")))
		var sc := Router.current as SectorScreen
		var view: EncounterView = sc._view if sc != null else null
		var sky: LocalSky = view.backdrop if view != null else null
		if sky == null or sky.life == null:
			print("life: %s: no sky" % cname)
			continue
		# (no hover: wherever the hidden desktop's pointer sits, the ship is not
		# outlined as pointed at)
		var slot := view.ship_view().get_parent() as Control
		if slot != null:
			slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if sc._ship_outline != null:
			sc._ship_outline.visible = false
			sc._ship_outline.view = null
		var n := sky.node
		var held := 0
		for m: Dictionary in sky.life.moons:
			if bool(m.held):
				held += 1
		print("life: %s %s node %d %s dev %d orbit %d kind %s, moons %d (held still %d)" % [cname, sky.style, n.index, MapGen.star_name(n),
			int(n.development), sky.orbit_target, sky.kind, sky.life.moons.size(), held])
		var dir := "%s/%s" % [out, cname if bits.size() < 2 else "%s_%s" % [cname, h]]
		DirAccess.make_dir_recursive_absolute(dir + "/after")
		DirAccess.make_dir_recursive_absolute(dir + "/before")
		LocalLife.cpu_us = 0
		for k in nf:
			await _frames(1)
			_img().save_png("%s/after/f_%04d.png" % [dir, k])
			_draw_again(sky, true)
			_img().save_png("%s/before/f_%04d.png" % [dir, k])
			_draw_again(sky, false)
		print("life: %s: %d frames each way; LocalLife's cpu %.3f ms a frame" % [cname, nf, float(LocalLife.cpu_us) / 1000.0 / float(maxi(nf, 1))])
		if "bench" in _args:
			await _bench(sky, cname)
	print("life: done")
	_tree.quit()


## The frame just drawn, drawn again with the hidden ideas taken away (or put
## back): no clock moves (nothing processes in a forced draw) and the worlds'
## memories are held, so it is the same frame but for them.
func _draw_again(sky: LocalSky, hidden: bool) -> void:
	LocalLife.hide.clear()
	if hidden:
		for nm in _hide:
			LocalLife.hide[nm] = true
	sky.life.sync()
	if not hidden:
		return
	var held: Array = []
	_hold_mems(_tree.root, held)
	RenderingServer.force_draw(false, 0.0)
	for hm: Array in held:
		(hm[0] as SubViewport).render_target_update_mode = hm[1]


func _hold_mems(nd: Node, held: Array) -> void:
	for ch in nd.get_children():
		if ch is PlanetView:
			for k in ["_mem_vp", "_mem_copy"]:
				var v: Variant = ch.get(k)
				if v is SubViewport and (v as SubViewport).render_target_update_mode != SubViewport.UPDATE_DISABLED:
					held.append([v, (v as SubViewport).render_target_update_mode])
					(v as SubViewport).render_target_update_mode = SubViewport.UPDATE_DISABLED
		_hold_mems(ch, held)


const COPIES := 40
## The air's and the lights' GPU time: COPIES of each in a viewport the sky's
## size (480x270 of 2x2 blocks), on and off alternated, the medians'
## difference over COPIES.
func _bench(sky: LocalSky, cname: String) -> void:
	for what in ["air", "night"]:
		var src: CanvasItem = sky.life._air if what == "air" else sky.life._night
		if src == null or not is_instance_valid(src):
			continue
		var vp := SubViewport.new()
		vp.size = Vector2i(480, 270)
		vp.size_2d_override = Vector2i(960, 540)
		vp.size_2d_override_stretch = true
		vp.transparent_bg = false
		vp.disable_3d = true
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(vp)
		var copies: Array[CanvasItem] = []
		for i in COPIES:
			var cp := src.duplicate() as CanvasItem
			cp.visible = true
			vp.add_child(cp)
			copies.append(cp)
		RenderingServer.viewport_set_measure_render_time(vp.get_viewport_rid(), true)
		var g := {true: [], false: []}
		for rep in 40:
			var on := rep % 2 == 1
			for cp in copies:
				cp.visible = on
			await _frames(4)
			for i in 8:
				await _frames(1)
				(g[on] as Array).append(RenderingServer.viewport_get_measured_render_time_gpu(vp.get_viewport_rid()))
		var a := _median(g[false])
		var b := _median(g[true])
		print("life: %s bench %s: %d copies %.3f -> %.3f ms; one frame of play pays %.4f ms" % [cname, what, COPIES, a, b, (b - a) / float(COPIES)])
		vp.queue_free()


static func _median(xs: Array) -> float:
	if xs.is_empty():
		return 0.0
	var s := xs.duplicate()
	s.sort()
	return float(s[s.size() / 2])


## A run at a system of that sky, parked as the map leaves you, LOCAL shown.
func _show(want: String, seed: int, orbit: String) -> bool:
	Rng.forced = seed
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var idx := -1
	var at := -9
	if orbit == "station":
		for n: MapGen.MapNode in Run.map:
			if n.type == MapGen.NodeType.STATION:
				idx = n.index
				break
		if idx < 0:
			return false
		Run.at = idx
		Run.map[idx].visited = true
		SectorScreen._approached_at = idx
		Router.show_local()
		return true
	for pass_i in 2:
		for n: MapGen.MapNode in Run.map:
			if n.type == MapGen.NodeType.STATION or n.type == MapGen.NodeType.START:
				continue
			if want != "*" and String(SkyWeatherS.sky_of_node(n)) != want:
				continue
			var Lo := SystemLayout.of(n)
			if orbit == "all":
				if int(n.development) < int(MapGen.Development.SETTLEMENT):
					continue
				var bi2 := -1
				for i in Lo.bodies.size():
					var b := Lo.bodies[i]
					if b.kind == &"planet" and b.world in LocalLife.NIGHT_GROUND and Worlds.WORLD[b.world].has("atm") 							and int(Worlds.spec(b.world, b.seed, 100.0).get("moons", 0)) > 0:
						bi2 = i
						break
				if bi2 < 0:
					continue
				at = bi2
			elif orbit == "settled" or orbit == "capital":
				if int(n.development) < (int(MapGen.Development.CAPITAL) if orbit == "capital" else int(MapGen.Development.SETTLEMENT)):
					continue
				var bi := -1
				for i in Lo.bodies.size():
					if Lo.bodies[i].kind == &"planet" and Lo.bodies[i].world in GROUND:
						bi = i
						break
				if bi < 0:
					continue
				at = bi
			elif orbit != "" and orbit != "star" and orbit != "edge":
				at = _body_for(Lo, orbit, pass_i == 0)
				if at < 0:
					continue
			idx = n.index
			break
		if idx >= 0:
			break
	if idx < 0:
		return false
	Run.at = idx
	var node: MapGen.MapNode = Run.node_at()
	SystemMapScreen._parked.erase(idx)
	if orbit != "":
		var Lo := SystemLayout.of(node)
		var mode := &"rail"
		match orbit:
			"star":
				at = -1
			"edge":
				mode = &"free"
		SystemMapScreen._parked[idx] = {"at": at, "p": Vector2(Lo.edge * 1.02, -210.0), "v": Vector2.ZERO, "head": 0.0, "mode": mode}
	# (`approach`: the ship flies in, as it does arriving from the map)
	if not _approach:
		SectorScreen._approached_at = idx
	Router.show_local()
	return true


func _body_for(Lo: SystemLayout, what: String, strict: bool) -> int:
	for i in Lo.bodies.size():
		var b := Lo.bodies[i]
		match what:
			"giant":
				if b.kind == &"giant" and b.world != &"" and (not strict or bool(Worlds.spec(b.world, b.seed, 100.0).get("ring", false))):
					return i
			"world":
				if b.kind == &"planet" and b.world != &"":
					return i
	return -1
