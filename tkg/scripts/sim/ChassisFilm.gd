extends Node

## THE CHASSIS SELECT, FILMED (the coded engine flame going live, Oct 13):
##   godot --path . --fixed-fps 30 --windowed --position 3840,0 -- sheet=ChassisFilm
##       out=<dir> [frames=150]
## Opens the chassis select the way the title does (`Router.show_chassis_select`),
## lets its showroom hull burn (CRUISE) and the rest idle, and saves the window every
## frame as f_####.png. Every hull's bob and flame run on `ShipView.shot_clock`,
## stepped 1/30 s a frame, so the frames at 30 fps are true speed however
## slowly the window drew. Waits for the flames' pictures (built off the main
## thread) before the first frame.

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
