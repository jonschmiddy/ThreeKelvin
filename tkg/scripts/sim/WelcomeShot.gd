extends Node

## Photographs Jon's welcome note on the real title. Needs a window: `-- sheet=WelcomeShot`.
## Why: docs/why/WelcomeShot.md#welcome-note-shot


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await RenderingServer.frame_post_draw


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(path)
	print("welcomeshot: %s" % path)


func _run() -> void:
	var out := Harness.arg("out")
	DirAccess.make_dir_recursive_absolute(out)
	Router.show_launcher()
	await _frames(int(Harness.arg("wait", "120")))
	await _save(out + "/title.png")
	var ls := Router.current as LauncherScreen
	for first in [true, false]:
		ls.open_welcome(first)
		await _frames(30)
		await _save(out + ("/welcome.png" if first else "/welcome_menu.png"))
		var w := Harness.first(ls, func(n: Node) -> bool: return n is WelcomePopup and not n.is_queued_for_deletion()) as WelcomePopup
		if w != null:
			w.close()
		await _frames(4)
	get_tree().quit()

