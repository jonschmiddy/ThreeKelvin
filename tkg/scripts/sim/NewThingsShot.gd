extends Node

## THE TITLE'S NEW THINGS, PHOTOGRAPHED on the real title screen:
##   tools/dev/render.sh --path tkg --resolution 1920x1080 -- sheet=NewThingsShot out=<dir> [wait=120]
## On a profile that has read Jon's note but never opened NEW THINGS, the title
## is given `wait` frames to bring its galaxy up and saved with the menu's mark
## (`menu_mark.png`); then the page opens from the menu (`page_top.png`), is
## scrolled to its end (`page_end.png`), and shuts, and the title is saved with
## the mark gone (`menu_seen.png`). Needs a window.

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
	print("newthingsshot: %s" % path)


func _run() -> void:
	var out := _arg("out")
	DirAccess.make_dir_recursive_absolute(out)
	WelcomePopup.mark_seen(true)
	NewThings.forget()
	Router.show_launcher()
	await _frames(int(_arg("wait", "120")))
	await _save(out + "/menu_mark.png")
	var ls := Router.current as LauncherScreen
	ls.open_new_things()
	await _frames(30)
	await _save(out + "/page_top.png")
	var pop := _find(ls) as NewThingsPopup
	if pop != null:
		var sc := pop.card.note_scroll()
		sc.scroll_vertical = int(sc.get_v_scroll_bar().max_value)
		await _frames(4)
		await _save(out + "/page_end.png")
		pop.close()
	await _frames(4)
	await _save(out + "/menu_seen.png")
	get_tree().quit()


func _find(root: Node) -> Node:
	if root is NewThingsPopup and not root.is_queued_for_deletion():
		return root
	for c in root.get_children():
		var f := _find(c)
		if f != null:
			return f
	return null
