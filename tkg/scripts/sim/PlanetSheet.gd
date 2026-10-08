extends Node

## Every kind of world the system map draws, on one sheet, as the GPU paints it:
##   godot --path . -- planetsheet=<png> [planettime=S]
##
## The same worlds, seeds, sizes and light as the approved gallery page
## ("Thirty-Four Worlds"), so the two can be set side by side: world i is seed
## (i + 1) * 3 + 11, radius 24 (a giant 20, ringed on even cards), lit from the
## upper left. Needs a window: a shader draws nothing headless.
##
## `planetclip=<dir> [planetframes=150] [planetrate=1] [planetcell=1]`: then
## films the sheet turning, `f_####.png`, the clock stepped 1/30 s a frame times
## `planetrate` (run with `--fixed-fps 30`), in `planetcell` blocks (2: as the
## map and LOCAL draw them), to measure each world's shimmer on its card.
## `worldmem=off` films them as before the worlds' memory (`PixelTurn`).

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
	var clip := ""
	var nf := 150
	var rate := 1.0
	var cell := 1
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with("planetclip="):
			clip = (a as String).substr(11)
		elif (a as String).begins_with("planetframes="):
			nf = int((a as String).substr(13))
		elif (a as String).begins_with("planetrate="):
			rate = float((a as String).substr(11))
		elif (a as String).begins_with("planetcell="):
			cell = int((a as String).substr(11))
	# (filmed in a picture of its own: a window placed off every screen is not
	# drawn again, and its own picture stays the first frame)
	var host: Node = self
	var film: SubViewport = null
	if clip != "":
		film = SubViewport.new()
		film.size = Vector2i(960, 540)
		film.disable_3d = true
		film.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(film)
		host = film
	var bg := ColorRect.new()
	bg.color = Color("#070a12")
	bg.size = Vector2(960, 540)
	host.add_child(bg)
	# `ring=A|B|C`: the painted rings Jon is choosing between, not the dots
	PlanetView.ring_style = Rings.look_from_args()
	var views: Array[Node2D] = []
	for i in Worlds.WORLD_ORDER.size():
		var w: StringName = Worlds.WORLD_ORDER[i]
		var num := i + 1
		var giant: bool = Worlds.WORLD[w].get("giant", false)
		var pv := Worlds.view_for(w)
		var cx := (i % COLS) * CW + CW / 2
		var cy := (i / COLS) * CH + CH / 2 - 4
		pv.position = Vector2(cx, cy)
		host.add_child(pv)
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
		host.add_child(lab)
	if cell > 1:
		for pv in views:
			pv.call("set_cell", cell)
	for pv in views:
		pv.call("step", _t, Vector3(-0.83, -0.31, 0.47))
	for _i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := (film if film != null else get_viewport()).get_texture().get_image()
	if _path != "":
		img.save_png(_path)
		print("  planetsheet: %d worlds to %s" % [views.size(), _path])
	if clip != "":
		DirAccess.make_dir_recursive_absolute(clip)
		for k in nf + 3:
			for pv in views:
				pv.call("step", _t + rate * float(k) / 30.0, Vector3(-0.83, -0.31, 0.47))
			await RenderingServer.frame_post_draw
			if k >= 3:
				film.get_texture().get_image().save_png("%s/f_%04d.png" % [clip, k - 3])
		print("  planetsheet: %d frames to %s" % [nf, clip])
	get_tree().quit()
