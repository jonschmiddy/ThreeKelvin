extends Node

## THE SIDE BAR'S SWAP, filmed (`SideSwap`):
##   godot --path . --windowed --position 3840,0 --fixed-fps 60 --quit-after 20000
##       -- sheet=SideBarShot out=<dir> [looks=A,B,C,D,E,F] [seed=N]
## For each look, one film of LOCAL -> map -> chart -> map -> LOCAL, then the
## dives LOCAL -> chart -> LOCAL (Tab, through black), through the
## Router's own doors on the default seams (1A, 2C), every frame of the game's
## 960x540 picture as <dir>/<look>/f_####.png. The ladder's clock and the
## swap's step 1/60 s a frame, and with `--fixed-fps 60` so does the game's,
## so the frames play at true speed at 60 fps however slowly the window drew.
## <dir>/<look>/meta.json: the frame each hop was asked on, and the side bar's
## rect. Runs on main too (no look there: `looks=-`), for the before. Needs a
## window.

var _tree: SceneTree
var _zl: Script = load("res://scripts/ui/ZoomLadder.gd")


func _arg(k: String, d: String = "") -> String:
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with(k + "="):
			return (a as String).substr(k.length() + 1)
	return d


func _ready() -> void:
	_run.call_deferred()


func _img() -> Image:
	return GameShell.input_target(_tree).get_texture().get_image()


func _frames(n: int) -> void:
	for i in n:
		await _tree.process_frame


func _set_look(l: String) -> void:
	for m in _zl.get_script_method_list():
		if m.name == "force_side_look":
			_zl.call(&"force_side_look", l)


## A SWAP THAT DID NOT DRAW (a shader that failed to compile draws its rect
## plain white, and nothing headless can see it): the side bar's rect mostly
## near-white on any frame is printed as a failure.
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
	var out := _arg("out", "user://sidebarshot")
	Router.animate_in_harness = true
	ZoomLadder.force = 1
	ZoomLadder.fixed_dt = 1.0 / 60.0
	Rng.forced = int(_arg("seed", "1"))
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	StarchartScreen._primed_for = Run.galaxy_seed
	var sys := Run.at
	var lay := SystemLayout.of(Run.node_at())
	for b in lay.bodies:
		if b.world != &"" and b.kind != &"belt":
			SystemMapScreen._parked[sys] = {"at": b.index, "mode": &"rail"}
			break
	SectorScreen._approached_at = sys
	ZoomLadder.force = 0
	Router.show_local()
	await _frames(90)
	ZoomLadder.force = 1
	var looks := _arg("looks", "A,B,C,D,E,F").split(",")
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
		await _frames(30)
	_set_look("")
	ZoomLadder.force = -1
	ZoomLadder.fixed_dt = -1.0
	print("  [sidebarshot] done, %d white frames%s" % [_white, "" if _white == 0 else " -- FAIL"])
	_tree.quit()
