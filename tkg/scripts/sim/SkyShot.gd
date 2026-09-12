extends RefCounted

## The screens that are not the sector, photographed against the sky.
##
##   godot --path . -- skyshot
##
## `SpaceLayer` gave a world to nine screens that had been panels on the clear
## colour, and "the refit bay has a sky now" is not a claim anybody should make
## from reading a diff. This opens each of them on a real run and saves a frame,
## so the answer is a picture.
##
## It also photographs the two that must NOT change — the station, which is an
## interior, and the starchart, which draws its own galaxy — because the way
## this feature breaks is not by failing to appear. It is by appearing somewhere
## it was ruled out of.
##
## NOT HEADLESS. The dummy display server never emits `frame_post_draw`, so a
## headless run of this hangs and looks exactly like a crash. Same note as
## StationShot, for the same reason.

## Screen name -> the Router call that opens it. Ordered so the two controls
## come last and the eye ends on them.
const SHOTS := [
	[&"ship", &"show_ship"],
	[&"transfer", &"show_transfer"],
	[&"cards", &"show_cards"],
	[&"modules", &"show_modules"],
	[&"archive", &"show_archive"],
	[&"history", &"show_history"],
	[&"station", &"show_station"],
	[&"chart", &"show_starchart"],
]


func run(tree: SceneTree) -> void:
	await tree.process_frame

	Rng.reseed(20260912, 0)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	# A system with something in the sky to see. The backdrop rolls its subject
	# off the node's own axes, so an empty rim system would photograph as stars
	# and prove nothing about the planet path.
	Router.show_sector()
	await tree.process_frame

	for row in SHOTS:
		var name := String(row[0])
		var call := String(row[1])
		if not Router.has_method(call):
			print("  SKIP %-10s no %s()" % [name, call])
			continue
		Router.call(call)
		# Three frames: one to build the screen, one to lay it out, one to let
		# the layer bake and draw into the size it ended up with.
		for i in 3:
			await tree.process_frame
		await RenderingServer.frame_post_draw
		var lit := Router.sky != null and Router.sky.visible
		var path := "user://sky_%s.png" % name
		tree.root.get_texture().get_image().save_png(path)
		print("  %-10s sky %s  ->  %s"
			% [name, "ON " if lit else "off", ProjectSettings.globalize_path(path)])

	print("skyshot: done")
	tree.quit(0)
