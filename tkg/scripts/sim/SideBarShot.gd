extends Node

## Frames step 1/60 s with `--fixed-fps 60`, so they play at true speed.
## Why: docs/why/SideBarShot.md#side-bar-film

var _tree: SceneTree
var _zl: Script = load("res://scripts/ui/ZoomLadder.gd")


func _ready() -> void:
	_run.call_deferred()


func _img() -> Image:
	return GameShell.input_target(_tree).get_texture().get_image()


func _set_look(l: String) -> void:
	for m in _zl.get_script_method_list():
		if m.name == "force_side_look":
			_zl.call(&"force_side_look", l)


## A shader that failed to compile draws plain white, unseen headless: near-white is a failure.
var _white := 0


func _check(im: Image, look: String, k: int) -> void:
	var lit := 0
	var n := 0
	for y in range(48, 500, 8):
		for x in range(700, 945, 8):
			n += 1
			if im.get_pixel(x, y).get_luminance() > 0.8:
				lit += 1
	if lit > n / 2:
		_white += 1
		if _white < 4:
			print("  FAIL [sidebarshot] %s frame %d: the side bar is a white rect (the swap's shader did not draw)" % [look, k])


func _run() -> void:
	_tree = get_tree()
	await _tree.process_frame
	var out := Harness.arg("out", "user://sidebarshot")
	Router.animate_in_harness = true
	ZoomLadder.force = 1
	ZoomLadder.fixed_dt = 1.0 / 60.0
	Rng.forced = Harness.seed_arg(1)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	StarchartScreen._primed_for = Run.galaxy_seed
	var sys := Run.at
	var lay := SystemLayout.of(Run.node_at())
	for b in lay.bodies:
		if b.world != &"" and b.kind != &"belt":
			ParkedShips.spots[sys] = {"at": b.index, "mode": &"rail"}
			break
	SectorScreen._approached_at = sys
	ZoomLadder.force = 0
	Router.show_local()
	await Harness.frames(_tree, 90)
	ZoomLadder.force = 1
	var looks := Harness.arg("looks", "A,B,C,D,E,F").split(",")
	for l in looks:
		_set_look(l)
		var d := "%s/%s" % [out, l]
		DirAccess.make_dir_recursive_absolute(d)
		var k := 0
		var hops: Array = []
		for i in 20:
			await _tree.process_frame
			_img().save_png("%s/f_%04d.png" % [d, k])
			k += 1
		for h in [["LOCAL>map", Router.show_system], ["map>chart", Router.show_starchart],
				["chart>map", Router.show_system], ["map>LOCAL", Router.show_local],
				["LOCAL>chart", Router.show_starchart], ["chart>LOCAL", Router.show_local]]:
			hops.append([h[0], k])
			(h[1] as Callable).call()
			var still := 0
			for i in 600:
				await _tree.process_frame
				var im := _img()
				im.save_png("%s/f_%04d.png" % [d, k])
				_check(im, l, k)
				k += 1
				still = still + 1 if not ZoomLadder.busy() else 0
				if still >= 30:
					break
		var f := FileAccess.open("%s/meta.json" % d, FileAccess.WRITE)
		f.store_string(JSON.stringify({"frames": k, "hops": hops, "fps": 60}))
		f.close()
		print("  [sidebarshot] %s: %d frames, hops %s" % [l, k, hops])
		# (back on LOCAL, at rest, for the next look)
		await Harness.frames(_tree, 30)
	_set_look("")
	ZoomLadder.force = -1
	ZoomLadder.fixed_dt = -1.0
	print("  [sidebarshot] done, %d white frames%s" % [_white, "" if _white == 0 else " -- FAIL"])
	_tree.quit(1 if _white > 0 else 0)
