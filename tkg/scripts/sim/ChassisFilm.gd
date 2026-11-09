extends Node

## Bob and flame run on `ShipView.shot_clock`, stepped per frame, so 30 fps is true speed.
## Why: docs/why/ChassisFilm.md#chassis-film

var _args: PackedStringArray


func _ready() -> void:
	_args = OS.get_cmdline_user_args()
	_run.call_deferred()


func _arg(k: String, d: String = "") -> String:
	for a in _args:
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d


func _run() -> void:
	var tree := get_tree()
	await tree.process_frame
	var dir := _arg("out")
	DirAccess.make_dir_recursive_absolute(dir)
	var frames := int(_arg("frames", "150"))
	Router.show_chassis_select()
	ShipView.shot_clock = 0.0
	# Let the screen settle and the flames' pictures land.
	for i in 90:
		await tree.process_frame
	var views: Array = []
	_collect(tree.root, views)
	print("chassisfilm: %d ship views" % views.size())
	for f in frames:
		ShipView.shot_clock = float(f) / 30.0
		await RenderingServer.frame_post_draw
		tree.root.get_texture().get_image().save_png("%s/f_%04d.png" % [dir, f])
	ShipView.shot_clock = -1.0
	tree.quit()


func _collect(n: Node, out: Array) -> void:
	if n is ShipView:
		out.append(n)
	for c in n.get_children():
		_collect(c, out)
