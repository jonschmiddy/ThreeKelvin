extends Node

## The science desk's rooms as the game draws them, at the approved page's own times, for
## `tools/desk/diff_desk.py` to set beside the page's frames. Windowed (`render.sh`): the room is lit
## on the GPU. Each frame is 1920 x 1080, the page's canvas, from a viewport of that size.
##   -- sheet=DeskRooms frames=<the page's manifest.json> out=<dir>
## Why: docs/why/DeskScene.md#the-plan

var _tree: SceneTree


func _ready() -> void:
	_run.call_deferred()


func _arg(k: String) -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return ""


func _run() -> void:
	_tree = get_tree()
	if _arg("play") != "":
		await _play(float(_arg("play")))
		return
	var out := _arg("out")
	var manifest := _arg("frames")
	if out == "" or manifest == "":
		print("deskrooms: give frames=<manifest.json> out=<dir>")
		_tree.quit(2)
		return
	var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest))
	if not doc is Dictionary:
		print("deskrooms: cannot read %s" % manifest)
		_tree.quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	var vp := SubViewport.new()
	vp.size = Vector2i(1920, 1080)
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var room := DeskRoom.new()
	room.size = Vector2(1920, 1080)
	vp.add_child(room)
	if not room.setup(String(doc.room)):
		_tree.quit(1)
		return
	var dbg := _arg("dbg")
	var wrote := 0
	if dbg != "":
		var f0: Dictionary = (doc.frames as Array)[(doc.frames as Array).size() - 9]
		for d in 8:
			room.show_at(float(f0.ts), float(f0.real), false)
			room.debug(d)
			await Harness.frames(_tree, 4)
			var im := vp.get_texture().get_image()
			im.save_png(out.path_join("dbg_%d.png" % d))
		_tree.quit(0)
		return
	for f: Dictionary in doc.frames:
		room.show_at(float(f.ts), float(f.real), bool(f.leaving))
		await Harness.frames(_tree, 4)
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		if img.save_png(out.path_join(String(f.name))) == OK:
			wrote += 1
	print("deskrooms: wrote %d of %d frames to %s" % [wrote, (doc.frames as Array).size(), out])
	_tree.quit(0 if wrote == (doc.frames as Array).size() else 1)


## `play=S`: a real visit in the window (`DeskScene` on GameClock), S seconds then LEAVE, back to
## the end; prints the frame times (the room and the tube each frame, plus the CPU layers).
func _play(secs: float) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var d := DeskScene.new()
	d.size = get_viewport().get_visible_rect().size
	layer.add_child(d)
	var take := func() -> Dictionary: return {ok = true, text = "A test reading: nothing is taken."}
	if not d.open(DeskScene.room_for(null), "", Vector2(-1, -1), take):
		_tree.quit(1)
		return
	var ms: Array[float] = []
	var t0 := Time.get_ticks_usec()
	var gone := [false]
	d.left.connect(func() -> void: gone[0] = true)
	var shot := _arg("shot")
	while not gone[0]:
		await _tree.process_frame
		var t := Time.get_ticks_usec()
		ms.append((t - t0) / 1000.0)
		t0 = t
		if not d.leaving and d.real >= secs:
			if shot != "":
				_tree.root.get_texture().get_image().save_png(shot)
			d.leave()
		if ms.size() > 60 * 120:
			break
	ms.sort()
	var n := ms.size()
	print("deskrooms play: %d frames, median %.2f ms, 95th %.2f ms, worst %.2f ms; left: %s" % [n, ms[n / 2], ms[int(n * 0.95)], ms[n - 1], str(gone[0])])
	_tree.quit(0 if gone[0] else 1)
