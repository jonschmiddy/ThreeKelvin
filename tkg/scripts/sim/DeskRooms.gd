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
	var out := _arg("out")
	var man := _arg("frames")
	if out == "" or man == "":
		print("deskrooms: give frames=<manifest.json> out=<dir>")
		_tree.quit(2)
		return
	var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(man))
	if not doc is Dictionary:
		print("deskrooms: cannot read %s" % man)
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
	var wrote := 0
	for f: Dictionary in doc.frames:
		room.show_at(float(f.ts), float(f.real), bool(f.leaving))
		await Harness.frames(_tree, 4)
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		if img.save_png(out.path_join(String(f.name))) == OK:
			wrote += 1
	print("deskrooms: wrote %d of %d frames to %s" % [wrote, (doc.frames as Array).size(), out])
	_tree.quit(0 if wrote == (doc.frames as Array).size() else 1)
