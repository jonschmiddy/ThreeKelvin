extends Node

## Stills of docking by the mouth (Jon, Nov 15): LOCAL at a station at rest and with the pointer
## on the mouth, moored left and right, a 2x crop of each mouth, and the yard's ship card steady
## and mid-glitch. Windowed, through tools/dev/render.sh, `--resolution 1920x1080`:
##   tools/dev/render.sh --path tkg --resolution 1920x1080 -- sheet=DockMouthShot out=<dir> [side=<id>] [interior=<id>]
## Why: docs/why/DockMouth.md#the-mouth-is-the-button

var _tree: SceneTree
var _dir := ""


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await RenderingServer.frame_post_draw


func _snap(name: String) -> Image:
	await RenderingServer.frame_post_draw
	var img := get_tree().root.get_texture().get_image()
	img.save_png("%s/%s.png" % [_dir, name])
	print("dockmouthshot: wrote %s/%s.png" % [_dir, name])
	return img


## The mouth's box (and some of the space it spills into) from a window still, at 2x.
func _crop(img: Image, loc: SectorScreen, name: String) -> void:
	var m := loc.find_child("DockMouth", true, false) as DockMouth
	if m == null:
		return
	var box := UiRect.of(m)
	# (the view's pixels to the window's: the shell's frame scales the game up)
	var fr: SubViewportContainer = GameShell.instance._frame if GameShell.instance != null else null
	var k := float(fr.stretch_shrink) if fr != null else 1.0
	var o := fr.get_global_transform() * Vector2.ZERO if fr != null else Vector2.ZERO
	var r := Rect2(o + box.position * k, box.size * k).grow(60.0 * k)
	r = r.intersection(Rect2(Vector2.ZERO, Vector2(img.get_size())))
	var c := img.get_region(Rect2i(r))
	c.resize(c.get_width() * 2, c.get_height() * 2, Image.INTERPOLATE_NEAREST)
	c.save_png("%s/%s.png" % [_dir, name])
	print("dockmouthshot: wrote %s/%s.png (%s of the window, x2)" % [_dir, name, r])


func _run() -> void:
	_tree = get_tree()
	await _tree.process_frame
	_dir = Harness.arg("out", "user://dockmouth")
	DirAccess.make_dir_recursive_absolute(_dir)
	Router.animate_in_harness = true
	ZoomLadder.force = 1
	if Harness.arg("side", "") != "":
		StationSides.force_side = StringName(Harness.arg("side", ""))
	if Harness.arg("interior", "") != "":
		StationSides.force_interior = StringName(Harness.arg("interior", ""))
	DockMouth.forget(true)
	Rng.forced = Harness.seed_arg(7)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var st := -1
	for raw in Run.map:
		if (raw as MapGen.MapNode).type == MapGen.NodeType.STATION:
			st = (raw as MapGen.MapNode).index
			break
	Run.at = st
	Run.map[st].visited = true
	SectorScreen._approached_at = st
	Router.park_at_station()
	for right in [false, true]:
		Moored.at = -1
		if right:
			Moored.moor(st)
		Router.show_local()
		var loc: SectorScreen = null
		for i in 900:
			await _tree.process_frame
			loc = Router.current as SectorScreen
			if loc != null and not ZoomLadder.busy() and loc.settled_local() and loc.find_child("DockMouth", true, false) != null:
				break
		await _frames(60)
		loc = Router.current as SectorScreen
		loc.station_awake()
		var side := "right" if right else "left"
		var m := loc.find_child("DockMouth", true, false) as DockMouth
		var rest := await _snap("local_%s_rest" % side)
		_crop(rest, loc, "local_%s_rest_mouth2x" % side)
		m.over = true
		await _frames(30)
		var lit := await _snap("local_%s_hover" % side)
		_crop(lit, loc, "local_%s_hover_mouth2x" % side)
		m.over = false
		await _frames(20)
	await _yard()
	_tree.quit()


## The yard's ship card: steady, then on the first burst's frame (its clock set to it).
func _yard() -> void:
	Router.animate_in_harness = false
	Router.show_station()
	var st: StationScreen = null
	for i in 600:
		await _tree.process_frame
		st = Router.current as StationScreen
		if st != null and st._mine_slab != null and is_instance_valid(st._mine_slab) and not ZoomLadder.busy():
			break
	await _frames(60)
	st = Router.current as StationScreen
	if st == null or st._mine_slab == null:
		print("dockmouthshot: no yard card")
		return
	var slab := st._mine_slab
	var wear: HoloTag.Wear = null
	for k in slab.get_children():
		if k is HoloTag.Wear:
			wear = k
	slab.visible = true
	await _frames(30)
	await _snap("yard_card_steady")
	# (each burst frame of the first burst, and of a few after it: torn bands differ frame to frame)
	var shots := 0
	for f in 240:
		if wear == null:
			break
		var idle := HoloTag.D_AFTER + float(f) / HoloTag.G_HZ
		var g := HoloTag.glitch_at(idle, wear.get_instance_id())
		if g == null or not g.on or g.tears.is_empty():
			continue
		wear._born = GameClock.now() - (HoloTag.OPEN + idle + 0.005)
		await _frames(1)
		await _snap("yard_card_glitch_%d" % shots)
		shots += 1
		if shots >= 3:
			break
