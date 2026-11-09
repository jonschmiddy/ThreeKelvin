extends Node

## Photographed on the real title screen on a profile that has read the note; needs a window.
## Why: docs/why/NewThingsShot.md#new-things-shots


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await RenderingServer.frame_post_draw


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(path)
	print("newthingsshot: %s" % path)


func _run() -> void:
	var out := Harness.arg("out")
	DirAccess.make_dir_recursive_absolute(out)
	WelcomePopup.mark_seen(true)
	NewThings.forget()
	Router.show_launcher()
	await _frames(int(Harness.arg("wait", "120")))
	await _save(out + "/menu_mark.png")
	var ls := Router.current as LauncherScreen
	ls.open_new_things()
	await _frames(30)
	await _save(out + "/page_top.png")
	var pop := Harness.first(ls, func(n: Node) -> bool: return n is NewThingsPopup and not n.is_queued_for_deletion()) as NewThingsPopup
	if pop != null:
		var sc := pop.card.note_scroll()
		sc.scroll_vertical = int(sc.get_v_scroll_bar().max_value)
		await _frames(4)
		await _save(out + "/page_end.png")
		pop.close()
	await _frames(4)
	await _save(out + "/menu_seen.png")
	get_tree().quit()

