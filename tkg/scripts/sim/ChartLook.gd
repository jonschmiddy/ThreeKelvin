extends Node

## The star chart photographed twice at each view, whole and with its systems
## hidden, for mocking up a new look for its sky with the systems laid back on
## top unchanged:
##   godot --path . -- sheet=ChartLook out=<dir> [squash=S]
## `squash=S` tilts the galaxy to S (how foreshortened the disc is; the sector
## map's plane is at 0.38) before the chart is drawn.
## Writes <view>_full.png and <view>_sky.png. Needs a window; leave it alone
## while it runs (a Tab or a click changes screens under it).

var out := "user://chartlook"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with("out="):
			out = (a as String).substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	get_viewport().gui_disable_input = true
	Rng.forced = 4242
	Run.start_new_run(&"korvan", 1)
	for a2 in OS.get_cmdline_user_args():
		if (a2 as String).begins_with("squash="):
			Run.galaxy["squash"] = float((a2 as String).substr(7))
	print("  chartlook: galaxy %s at squash %.2f" % [Run.galaxy.get("name", "?"), float(Run.galaxy.get("squash", 1.0))])
	Router.show_starchart()
	var warm := Time.get_ticks_msec()
	while Time.get_ticks_msec() - warm < 2500:
		await get_tree().process_frame
	(Router.current as StarchartScreen).dismiss_primer()
	for _i in 30:
		await get_tree().process_frame
	var chart = (Router.current as StarchartScreen)._chart
	for v in [["default", 0.42, Vector2.ZERO], ["mid", 1.0, Vector2.ZERO], ["close", 2.9, Vector2(60, -30)]]:
		chart._go_to(v[1], v[2], false)
		chart.show_icons = true
		chart._repaint_sky()
		await _shot("%s_full" % v[0])
		chart.show_icons = false
		chart._repaint_sky()
		await _shot("%s_sky" % v[0])
	chart.show_icons = true
	get_tree().quit()


func _shot(name: String) -> void:
	for _i in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
