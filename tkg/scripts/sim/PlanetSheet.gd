extends Node

## Every kind of world the system map draws, on one sheet, as the GPU paints it:
##   godot --path . -- planetsheet=<png> [planettime=S]
##
## The same worlds, seeds, sizes and light as the approved gallery page
## ("Thirty-Four Worlds"), so the two can be set side by side: world i is seed
## (i + 1) * 3 + 11, radius 24 (a giant 20, ringed on even cards), lit from the
## upper left. Needs a window: a shader draws nothing headless.

const CW := 96
const CH := 76
const COLS := 10

var _path := ""
var _t := 3.0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with("planetsheet="):
			_path = (a as String).substr(12)
		elif (a as String).begins_with("planettime="):
			_t = float((a as String).substr(11))
	var bg := ColorRect.new()
	bg.color = Color("#070a12")
	bg.size = Vector2(960, 540)
	add_child(bg)
	var views: Array[Node2D] = []
	for i in Worlds.WORLD_ORDER.size():
		var w: StringName = Worlds.WORLD_ORDER[i]
		var num := i + 1
		var giant: bool = Worlds.WORLD[w].get("giant", false)
		var pv := Worlds.view_for(w)
		var cx := (i % COLS) * CW + CW / 2
		var cy := (i / COLS) * CH + CH / 2 - 4
		pv.position = Vector2(cx, cy)
		add_child(pv)
		var over := {}
		if giant:
			over["ring"] = num % 2 == 0
		pv.call("set_world", w, num * 3 + 11, 20.0 if giant else 24.0, over)
		views.append(pv)
		var lab := Label.new()
		lab.text = Worlds.display_name(w)
		lab.position = Vector2(cx - CW / 2 + 2, cy + 28)
		lab.add_theme_font_size_override("font_size", 8)
		lab.add_theme_color_override("font_color", Color("#8b97a4"))
		add_child(lab)
	for pv in views:
		pv.call("step", _t, Vector3(-0.83, -0.31, 0.47))
	for _i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_path)
	print("  planetsheet: %d worlds to %s" % [views.size(), _path])
	get_tree().quit()
