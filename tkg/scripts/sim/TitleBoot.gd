extends Node

## The title screen's galaxy on a cold start: when it first draws, and what the
## screen shows before it does.
##   godot --path . -- sheet=TitleBoot out=<dir>
## Prints how long after the title's first frame its sky is drawing and the
## longest frame, and saves the frame at 0.5, 1, 2 and 4 s (`boot_<ms>.png`). For
## a first launch's cold shader compile, run it with the user's shader cache
## moved aside. Needs a window.

var out := "user://titleboot"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with("out="):
			out = (a as String).substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	get_viewport().gui_disable_input = true
	_run.call_deferred()


func _run() -> void:
	var t0 := Time.get_ticks_msec()
	print("TITLEBOOT the harness started %d ms from the engine's start" % t0)
	var marks := [500, 1000, 2000, 4000]
	var ready_at := -1
	var first_at := -1
	var worst := 0
	var last := t0
	while Time.get_ticks_msec() - t0 < 6000:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_msec() - t0
		worst = maxi(worst, now + t0 - last)
		last = now + t0
		var ls := Router.current as LauncherScreen
		if ls != null and ls._sky != null:
			var sky := ls._sky._sky as ChartSky
			# drawn at all (unquantised, while its palette is cut), and drawn whole
			# (the legacy style draws with a renderer of its own, `ChartLegacy`)
			var drawn := sky._vp != null or (sky._legacy != null and sky._legacy._vp != null)
			if first_at < 0 and drawn:
				first_at = now
			if ready_at < 0 and sky.ready_to_draw():
				ready_at = now
		if not marks.is_empty() and now >= int(marks[0]):
			GameShell.instance.view.get_texture().get_image().save_png(out.path_join("boot_%04d.png" % int(marks[0])))
			marks.pop_front()
	print("TITLEBOOT the galaxy drew %d ms after the title's first frame, with its palette at %d ms; the longest frame %d ms" % [first_at, ready_at, worst])
	get_tree().quit()
