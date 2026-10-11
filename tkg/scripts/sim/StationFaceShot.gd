extends Node

## THE STATION'S SIDE ALONE, photographed (`StationFace`), its clocks frozen:
##   godot --path . --windowed --position 3840,0 -- sheet=StationFaceShot out=<dir>
##       [side=<id>] [interior=<id>|none] [powers=0,1] [clock=0.37] [dock=0]
## The pair (plate behind, front over it) on a plain dark 960 x 540 picture, the
## hallway at row 270, the star's light white, every clock stopped at `clock`
## seconds: one PNG per power, `<dir>/face_<side>_<interior>_p<power>.png`. The
## same frozen frame on two builds is the same picture, pixel for pixel, so a
## diff of two runs says whether a change moved anything. Needs a window.

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


func _run() -> void:
	_tree = get_tree()
	await _tree.process_frame
	var out := _arg("out", "user://facesshot")
	DirAccess.make_dir_recursive_absolute(out)
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color8(9, 12, 19)
	bg.size = Vector2(960, 540)
	layer.add_child(bg)
	var host := Control.new()
	# (`host_w=712`: the plate whole on the picture, from x 400, and the hull
	# it runs on into)
	host.size = Vector2(float(_arg("host_w", "960")), 540)
	layer.add_child(host)
	var side := _arg("side", "")
	var interior := _arg("interior", "none")
	var clock := float(_arg("clock", "0.37"))
	var dock := float(_arg("dock", "0"))
	for ps in _arg("powers", "0,1").split(",", false):
		var p := float(ps)
		for c in host.get_children():
			c.queue_free()
		await _tree.process_frame
		var pair: Array = StationFace.make_pair(null, host)
		for f: Control in pair:
			if f.has_method(&"use_side"):
				f.call(&"use_side", StringName(side), StringName(interior))
			host.add_child(f)
		await _tree.process_frame
		for f: Control in pair:
			f.set_process(false)
			f.set("ship_y", 270.0)
			f.set("tint", Color(1, 1, 1))
			f.set("_clock", clock)
			f.set("_chase", clock * 40.0)
			f.set("power", p)
			f.set("dock_k", dock)
			f.queue_redraw()
			var g: Variant = f.get("_glow")
			if g is CanvasItem:
				(g as CanvasItem).queue_redraw()
		for i in 3:
			await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var name := "face_%s_%s_p%s.png" % [side if side != "" else "default", interior, ps]
		img.save_png("%s/%s" % [out, name])
		print("  [faceshot] %s" % name)
	_tree.quit()
