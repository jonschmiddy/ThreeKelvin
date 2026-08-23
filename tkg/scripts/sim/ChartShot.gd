extends RefCounted

## The star chart, photographed. `godot --path . -- chartshot [region]`
##
## Same reason ShipShot exists: the scale bar changes with zoom and the region
## button is a click, and neither is visible in a headless render.
func run(tree: SceneTree) -> void:
	await tree.process_frame
	Run.start_new_run(&"korvan", 1)
	Router.show_starchart()
	for i in 120:
		await RenderingServer.frame_post_draw
	var tag := ""
	if "region" in OS.get_cmdline_user_args():
		var s := Router.current as StarchartScreen
		if s != null:
			s._on_region()
			tag = "_region"
		for i in 40:
			await RenderingServer.frame_post_draw
	var path := "user://chart%s.png" % tag
	tree.root.get_texture().get_image().save_png(path)
	print("wrote ", ProjectSettings.globalize_path(path))
	tree.quit()
