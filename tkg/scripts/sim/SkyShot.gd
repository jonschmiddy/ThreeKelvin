extends RefCounted

## Photographs the nine sky screens and the two that must not change: it breaks by appearing.
## Not headless: the dummy display never emits `frame_post_draw`, so it hangs like a crash.
## Why: docs/why/SkyShot.md#sky-shot

## Screen name -> the Router call that opens it. Ordered so the two controls
## come last and the eye ends on them.
const SHOTS := [
	[&"ship", &"show_ship"],
	[&"transfer", &"show_transfer"],
	[&"cards", &"show_cards"],
	[&"modules", &"show_modules"],
	[&"history", &"show_history"],
	[&"station", &"show_station"],
	[&"chart", &"show_starchart"],
	## The end of a run, which is otherwise only reachable by dying and so was
	## the one screen in the game nobody could photograph on purpose.
	[&"gameover", &"show_game_over"],
]

## A real one, and one of the longer ones, because the panel autowraps and a
## width that flatters a short sentence is not a width.
const DEATH := "A survey frame let go at the wrong moment and took the forward hold with it. You were still counting the hours to the next station."


func run(tree: SceneTree) -> void:
	await tree.process_frame

	# (forced, not reseeded: `start_new_run` draws its own seed and a reseed
	# before it was thrown away; `seed N` on the command line wins)
	if Rng.forced == 0:
		Rng.forced = 20260912
	print("  [seed] %d" % Rng.forced)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	# A system with something in the sky, as an empty rim
	# system would prove nothing about the planet path.
	Router.show_sector()
	await tree.process_frame

	Run.death_reason = DEATH
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
