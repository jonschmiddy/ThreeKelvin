extends Node

## LOCAL'S "WOW" PROTOTYPES FILMED (`LocalWow`), each the same frame with the
## idea off and on:
##   godot --path . --windowed --position 3840,0 --fixed-fps 30 -- sheet=LocalWowShot
##       wow=<idea>[,<idea>] out=<dir> [cases=giant,settled,...] [frames=240]
##       [warm=70] [style=simplified] [measure] [nofilm]
## For each case: a new run (its seed), the ship parked as the sector map leaves
## it, LOCAL shown; then `frames` frames, each saved TWICE -- as played, the
## ideas on (`<case>/after/f_####.png`), and the same frame drawn again with
## every idea off (`LocalWow.shown` false, nothing's clock moved, the worlds'
## surface memories held: `<case>/before/f_####.png`). The game's 960x540
## picture. The clocks step 1/30 s a frame (run with `--fixed-fps 30`).
## `measure`: the ideas' cost, in blocks of 60 played frames with them asked
## for and not, alternated four times: the script's process time and every
## viewport's GPU time summed, ms a frame, printed. Needs a window.

const SkyWeatherS := preload("res://scripts/ui/sysmap/SkyWeather.gd")
## name: [sky, seed, orbit]
const CASES := {
	"giant": ["reflection", 4242, "giant"],
	"world": ["reflection", 4242, "world"],
	"emission": ["emission", 1, ""],
	"calm": ["calm", 4242, ""],
	"star": ["reflection", 4242, "star"],
	"edge": ["reflection", 4242, "edge"],
	"core": ["core", 4242, ""],
	"pulsar": ["pulsar", 4242, ""],
	"planetary": ["planetary", 4242, ""],
	"dark": ["dark", 4242, ""],
	"belt": ["calm", 4242, "belt"],
	# a settled system, orbiting a world with ground under its air
	"settled": ["*", 4242, "settled"],
	"settled2": ["*", 77, "settled"],
	"capital": ["*", 4242, "capital"],
	"station": ["*", 1, "station"],
	"ringed": ["*", 4242, "giant"],
	"ringed2": ["*", 77, "giant"],
}
const GROUND := [&"rock", &"desert", &"iron", &"ice", &"verdant", &"ocean", &"toxic", &"city", &"hurricane",
	&"aurora", &"swamp", &"eyeball", &"cracked", &"megacity", &"crystal", &"haze"]

var _args: PackedStringArray
var _tree: SceneTree


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
	var out := _arg("out", "user://wow")
	var cases: PackedStringArray = _arg("cases", "giant").split(",")
	var nf := int(_arg("frames", "240"))
	for cname in cases:
		if not CASES.has(cname):
			print("wow: no case ", cname)
			continue
		var c: Array = CASES[cname]
		if not await _show(String(c[0]), int(c[1]), String(c[2])):
			print("wow: %s: no system" % cname)
			continue
		await _frames(int(_arg("warm", "70")))
		var sc := Router.current as SectorScreen
		var view: EncounterView = sc._view if sc != null else null
		var sky: LocalSky = view.backdrop if view != null else null
		if sky == null:
			print("wow: %s: no sky" % cname)
			continue
		var n := sky.node
		print("wow: %s node %d %s dev %d orbit %d kind %s" % [cname, n.index, MapGen.star_name(n), int(n.development), sky.orbit_target, sky.kind])
		if "debug" in _args:
			var sv := sky.cam_ship
			print("wow:   ship %s material %s" % [sv, sv.material if sv != null else null])
			if sv != null and sv.material is ShaderMaterial:
				for u in ["l_dir", "l_col", "l_k", "b_k"]:
					print("wow:     %s = %s" % [u, (sv.material as ShaderMaterial).get_shader_parameter(u)])
		var dir := "%s/%s" % [out, cname]
		if not "nofilm" in _args:
			DirAccess.make_dir_recursive_absolute(dir + "/after")
			DirAccess.make_dir_recursive_absolute(dir + "/before")
			for k in nf:
				await _frames(1)
				_img().save_png("%s/after/f_%04d.png" % [dir, k])
				_draw_again(sky, false)
				_img().save_png("%s/before/f_%04d.png" % [dir, k])
				_draw_again(sky, true)
			print("wow: %s: %d frames each way" % [cname, nf])
		if "measure" in _args:
			await _measure(sky, cname)
	print("wow: done")
	_tree.quit()


## The frame just drawn, drawn again with the ideas shown or not: no clock moves
## (nothing processes in a forced draw) and the worlds' memories are held, so it
## is the same frame but for the ideas.
func _draw_again(sky: LocalSky, shown: bool) -> void:
	LocalWow.shown = shown
	sky.wow_sync()
	if shown:
		return
	var held: Array = []
	_hold_mems(_tree.root, held)
	RenderingServer.force_draw(false, 0.0)
	for h: Array in held:
		(h[0] as SubViewport).render_target_update_mode = h[1]


func _hold_mems(nd: Node, held: Array) -> void:
	for ch in nd.get_children():
		if ch is PlanetView:
			for k in ["_mem_vp", "_mem_copy"]:
				var v: Variant = ch.get(k)
				if v is SubViewport and (v as SubViewport).render_target_update_mode != SubViewport.UPDATE_DISABLED:
					held.append([v, (v as SubViewport).render_target_update_mode])
					(v as SubViewport).render_target_update_mode = SubViewport.UPDATE_DISABLED
		_hold_mems(ch, held)


## The ideas' cost: blocks of 60 frames played with them asked for and not.
func _measure(sky: LocalSky, cname: String) -> void:
	var wanted: Array[StringName] = []
	for nm in LocalWow.NAMES:
		if LocalWow.asked(nm):
			wanted.append(nm)
	var vps: Array[Viewport] = []
	var res := {true: [0.0, 0.0, 0], false: [0.0, 0.0, 0]}
	for rep in 6:
		var on := rep % 2 == 1
		for nm in wanted:
			LocalWow.set_asked(nm, on)
		sky.wow_sync()
		await _frames(10)
		vps.clear()
		_viewports(_tree.root, vps)
		for v in vps:
			RenderingServer.viewport_set_measure_render_time(v.get_viewport_rid(), true)
		await _frames(2)
		for i in 60:
			await _frames(1)
			var g := 0.0
			for v in vps:
				if is_instance_valid(v):
					g += RenderingServer.viewport_get_measured_render_time_gpu(v.get_viewport_rid())
			res[on][0] += g
			res[on][1] += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			res[on][2] += 1
	for nm in wanted:
		LocalWow.set_asked(nm, true)
	sky.wow_sync()
	var a: Array = res[false]
	var b: Array = res[true]
	print("wow: %s cost of %s: gpu %.3f -> %.3f ms (%+.3f), process %.3f -> %.3f ms (%+.3f), %d viewports" % [cname, ",".join(wanted),
		a[0] / a[2], b[0] / b[2], b[0] / b[2] - a[0] / a[2], a[1] / a[2], b[1] / b[2], b[1] / b[2] - a[1] / a[2], vps.size()])


func _viewports(nd: Node, out: Array[Viewport]) -> void:
	if nd is Viewport:
		out.append(nd)
	for ch in nd.get_children():
		_viewports(ch, out)


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
			if orbit == "settled" or orbit == "capital":
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
			"belt":
				if b.kind == &"belt":
					return i
	return -1
