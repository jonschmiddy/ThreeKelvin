extends Node

## JON'S WELCOME NOTE, PHOTOGRAPHED on the real title screen:
##   godot --path . --windowed --position 3840,0 -- sheet=WelcomeShot out=<dir> [wait=120]
## The title is given `wait` frames to bring its galaxy up and saved alone
## (`title.png`); then the note opens as on a first launch (START YOUR JOURNEY,
## `welcome.png`) and from MESSAGE FROM JON (CLOSE, `welcome_menu.png`), each
## saved once its fade has settled. Needs a window.

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
