extends Node

## Photographs Jon's welcome note on the real title. Needs a window: `-- sheet=WelcomeShot`.
## Why: docs/why/WelcomeShot.md#welcome-note-shot

var _args: PackedStringArray


func _ready() -> void:
	_args = OS.get_cmdline_user_args()
	_run.call_deferred()


func _arg(k: String, d: String = "") -> String:
	for a in _args:
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d


func _frames(n: int) -> void:
	for i in n:
		await RenderingServer.frame_post_draw


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(path)
	print("welcomeshot: %s" % path)


func _run() -> void:
	var out := _arg("out")
	DirAccess.make_dir_recursive_absolute(out)
	Router.show_launcher()
	await _frames(int(_arg("wait", "120")))
	await _save(out + "/title.png")
	var ls := Router.current as LauncherScreen
	for first in [true, false]:
		ls.open_welcome(first)
		await _frames(30)
		await _save(out + ("/welcome.png" if first else "/welcome_menu.png"))
		var w := _find(ls) as WelcomePopup
		if w != null:
			w.close()
		await _frames(4)
	get_tree().quit()


func _find(root: Node) -> Node:
	if root is WelcomePopup and not root.is_queued_for_deletion():
		return root
	for c in root.get_children():
		var f := _find(c)
		if f != null:
			return f
	return null
