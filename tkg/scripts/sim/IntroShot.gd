extends Node

## THE FIRST-RUN INTRO, filmed (`FirstRunIntro`):
##   godot --path . --windowed --position 3840,0 -- sheet=IntroShot keepwindow intro
##       clip=<dir> [every=6] [secs=24] [reduced] [skip=S] [style=...] [seed=N]
## A new run launched the way the hull pick launches it (`Router.show_local`, then
## the intro), the game's picture saved every `every` frames for `secs` seconds.
## `skip=S` presses a key S seconds in. Prints where it ended and whether the seen
## flag was written -- to the harness's scratch settings, never the player's.
## `intro` on the command line is what lets it play under a harness. Needs a window.

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
	Router.animate_in_harness = true
	if "reduced" in _args:
		DisplaySettings.reduced_motion = true
	# a fresh player, as far as the scratch store knows
	FirstRunIntro.mark_seen(false)
	Rng.forced = int(_arg("seed", "4242"))
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Router.show_local()
	FirstRunIntro.maybe_start()
	var dir := _arg("clip")
	if dir != "":
		DirAccess.make_dir_recursive_absolute(dir)
	var every := int(_arg("every", "6"))
	var frames := int(float(_arg("secs", "24")) * 60.0)
	var skip_at := float(_arg("skip", "-1"))
	var t0 := Time.get_ticks_msec()
	var k := 0
	var skipped := false
	for i in frames:
		await RenderingServer.frame_post_draw
		if dir != "" and i % every == 0:
			tree.root.get_texture().get_image().save_png("%s/f_%04d.png" % [dir, k])
			k += 1
		if skip_at >= 0.0 and not skipped and (Time.get_ticks_msec() - t0) / 1000.0 >= skip_at:
			skipped = true
			var ev := InputEventKey.new()
			ev.keycode = KEY_SPACE
			ev.pressed = true
			Input.parse_input_event(ev)
			print("introshot: key pressed at %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	var sc := Router.current
	print("introshot: on %s, playing %s, seen %s (%s)" % [
		sc.get_script().get_global_name() if sc != null else "nothing",
		FirstRunIntro.playing != null, FirstRunIntro.seen(), FirstRunIntro.store_path()])
	tree.quit()
