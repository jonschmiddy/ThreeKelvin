extends Node

## THE STATION SIDES ON LOCAL, photographed (`StationSides`, `StationFace`):
##   godot --path . --windowed --position 3840,0 --fixed-fps 30 -- sheet=StationSideShot
##       out=<dir> pairs=drum3:iris_90_0,pile1:cargo_130_0,... [seed=N]
## For each side:interior, LOCAL at the run's first station with that side and
## interior forced, built afresh, at rest: `<side>__<interior>__rest.png` (the
## lights standing by, as you find it) and `<side>__<interior>__on.png` (every
## lamp on, as the dock leaves it before the camera moves), the game's 960 x 540
## picture. Also writes `<side>__<interior>__bay.json`: where the plate's
## top-left is on the picture, for crops. Needs a window.

var _tree: SceneTree
var _args: PackedStringArray


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


func _img() -> Image:
	return GameShell.input_target(_tree).get_texture().get_image()


func _run() -> void:
	_tree = get_tree()
	await _tree.process_frame
	var out := _arg("out", "user://sideshot")
	DirAccess.make_dir_recursive_absolute(out)
	Router.animate_in_harness = true
	ZoomLadder.force = 1
	ZoomLadder.fixed_dt = 1.0 / 30.0
	Rng.forced = int(_arg("seed", "1"))
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	StarchartScreen._primed_for = Run.galaxy_seed
	var st := -1
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		if n.type == MapGen.NodeType.STATION:
			st = n.index
			break
	Run.at = st
	Run.map[st].visited = true
	SectorScreen._approached_at = st
	Router.park_at_station()
	Router.show_local()
	await _frames(120)
	for pr in _arg("pairs", "drum1:none").split(",", false):
		var bits := (pr as String).split(":")
		StationSides.force_side = StringName(bits[0])
		StationSides.force_interior = StringName(bits[1] if bits.size() > 1 else "none")
		# (LOCAL built again with this side)
		Router.show_system()
		while ZoomLadder.busy():
			await _tree.process_frame
		await _frames(20)
		Router.show_local()
		while ZoomLadder.busy():
			await _tree.process_frame
		await _frames(90)
		var loc := Router.current as SectorScreen
		if loc == null or loc._face == null:
			print("  [sideshot] %s: no station face" % pr)
			continue
		var tag := "%s__%s" % [bits[0], StationSides.force_interior]
		await RenderingServer.frame_post_draw
		_img().save_png("%s/%s__rest.png" % [out, tag])
		for f: StationFace in [loc._face, loc._face_front]:
			f.power = 1.0
		await _frames(12)
		await RenderingServer.frame_post_draw
		_img().save_png("%s/%s__on.png" % [out, tag])
		for f: StationFace in [loc._face, loc._face_front]:
			f.power = 0.0
		var o := loc._face.plate_g(Vector2.ZERO)
		var fa := FileAccess.open("%s/%s__bay.json" % [out, tag], FileAccess.WRITE)
		fa.store_string(JSON.stringify({"plate_at": [o.x, o.y], "side": bits[0], "interior": String(StationSides.force_interior)}))
		fa.close()
		print("  [sideshot] %s (plate at %s)" % [tag, o])
	StationSides.force_side = &""
	StationSides.force_interior = &""
	_tree.quit()
