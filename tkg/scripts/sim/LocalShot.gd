extends Node

## LOCAL, photographed: the side-on view (`SectorScreen`, `EncounterView`) in a
## system of a chosen sky, quiet or mid-fight, in the style on the command line.
##
##   godot --path . --windowed --position 3840,0 -- sheet=LocalShot keepwindow
##       [style=simplified|legacy|painted|radiant] [graphics=low] [seed=N]
##       [sky=emission|reflection|planetary|remnant|dark|calm|pulsar|core] [node=I]
##       [combat [fire]] [approach] [wait=F] [out=<png>] [skyout=<png>]
##       [clip=<dir> clipframes=61 clipms=33] [stats=<json>] [bare=<png>] [reduced]
##
## `out=` is the whole screen, `skyout=` the backdrop alone (its own picture,
## one pixel a block), `clip=` that picture frame after frame for the flicker
## measure (`frames.py`), `stats=` what the backdrop puts behind the play (game
## y 140 to 330, where the ships, shots and numbers are): the
## mean, 95th centile and spread of its brightness there, and its brightest.
## Needs a window.

const SkyWeatherS := preload("res://scripts/ui/sysmap/SkyWeather.gd")

var _args: PackedStringArray


func _arg(k: String, d: String = "") -> String:
	for a in _args:
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d


func _ready() -> void:
	_args = OS.get_cmdline_user_args()
	_run.call_deferred()


func _run() -> void:
	var tree := get_tree()
	await tree.process_frame
	Rng.forced = int(_arg("seed", "4242"))
	if "reduced" in _args:
		DisplaySettings.reduced_motion = true
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var want := _arg("sky", "calm")
	var idx := int(_arg("node", "-1"))
	if idx < 0:
		for n: MapGen.MapNode in Run.map:
			if n.type == MapGen.NodeType.STATION or n.type == MapGen.NodeType.START:
				continue
			if String(SkyWeatherS.sky_of_node(n)) == want:
				idx = n.index
				break
	if idx < 0:
		print("no system with a %s sky on seed %d" % [want, Rng.forced])
		tree.quit()
		return
	Run.at = idx
	var node: MapGen.MapNode = Run.node_at()
	print("  node %d %s: sky %s, star %d, nebula %s, giant %s" % [idx, MapGen.star_name(node),
		SkyWeatherS.sky_of_node(node), SystemLayout.of(node).star, node.in_nebula, node.gas_giant])
	if not "approach" in _args:
		SectorScreen._approached_at = idx
	if "combat" in _args:
		Run.hand_size_override = 5
		Router.start_combat(DB.enemies[&"cutter"], [], false)
	else:
		Router.show_local()
	var wait := int(_arg("wait", "90"))
	for i in wait:
		await RenderingServer.frame_post_draw
	# A FIGHT IN PROGRESS: the first cards that can be played, played at the
	# enemy, and the picture taken with their shots in the air
	if "combat" in _args and "fire" in _args:
		var cb = Router.current.get("combat")
		if cb != null:
			var played := 0
			for k in 3:
				for i in (cb.hand as Array).size():
					if cb.can_play(cb.hand[i]):
						cb.play(i, 0)
						played += 1
						break
				for f in 7:
					await RenderingServer.frame_post_draw
			print("  played %d cards" % played)
	var view: EncounterView = null
	var sc = Router.current
	if sc != null and sc.get("_view") != null:
		view = sc.get("_view")
	var sky: Control = view.backdrop if view != null else null
	if view != null:
		var r := view.get_global_rect()
		print("  view %s  ship %s" % [r, view.ship_view().get_global_rect()])
	var outp := _arg("out")
	if outp != "":
		tree.root.get_texture().get_image().save_png(outp)
		print("wrote ", outp)
	if sky != null:
		var skyp := _arg("skyout")
		if skyp != "" and sky.has_method("picture"):
			var img: Image = sky.call("picture")
			if img != null:
				img.save_png(skyp)
				print("wrote ", skyp)
	if sky != null and sky.has_method("gpu_ms"):
		sky.call("gpu_ms")
		var gsum := 0.0
		for gi in 60:
			await RenderingServer.frame_post_draw
			gsum += float(sky.call("gpu_ms"))
		var gvp := GameShell.input_target(tree)
		RenderingServer.viewport_set_measure_render_time(gvp.get_viewport_rid(), true)
		await RenderingServer.frame_post_draw
		var ggame := 0.0
		for gi in 60:
			await RenderingServer.frame_post_draw
			ggame += RenderingServer.viewport_get_measured_render_time_gpu(gvp.get_viewport_rid())
		print("  sky gpu %.3f ms, game view gpu %.3f ms, fps %d" % [gsum / 60.0, ggame / 60.0, Engine.get_frames_per_second()])
	# THE SKY BARE: the ships, their labels and the shots hidden, the game's own
	# 960x540 picture (before the screen filter) read back
	var statp := _arg("stats")
	var clip := _arg("clip")
	var barep := _arg("bare")
	if view != null and (statp != "" or clip != "" or barep != ""):
		var hid: Array[CanvasItem] = []
		for c in view.get_children():
			if c is CanvasItem and c != view.backdrop and c != view.weather and (c as CanvasItem).visible:
				(c as CanvasItem).visible = false
				hid.append(c)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var vr := view.get_global_rect()
		var arena := Rect2i(int(vr.position.x), int(vr.position.y), int(vr.size.x), 297)
		var gv := GameShell.input_target(tree)
		if barep != "":
			gv.get_texture().get_image().save_png(barep)
			print("wrote ", barep)
		if statp != "":
			var st := _stats(gv.get_texture().get_image(), Rect2i(arena.position.x, 140, arena.size.x, 190))
			var f := FileAccess.open(statp, FileAccess.WRITE)
			f.store_string(JSON.stringify(st))
			print("  stats ", JSON.stringify(st))
		if clip != "":
			DirAccess.make_dir_recursive_absolute(clip)
			var nf := int(_arg("clipframes", "61"))
			var ms := int(_arg("clipms", "0"))
			for k in nf:
				if ms > 0:
					var t0 := Time.get_ticks_msec()
					while Time.get_ticks_msec() - t0 < ms:
						await RenderingServer.frame_post_draw
				else:
					await RenderingServer.frame_post_draw
				gv.get_texture().get_image().get_region(arena).save_png("%s/f_%04d.png" % [clip, k])
			print("wrote ", nf, " frames to ", clip)
		for c in hid:
			c.visible = true
	tree.quit()


## What the sky puts behind the play, in sRGB luma: mean, 95th and 99.5th
## centiles, spread, brightest.
func _stats(img: Image, r: Rect2i) -> Dictionary:
	var ls: Array[float] = []
	var sum := 0.0
	var sq := 0.0
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := img.get_pixel(x, y)
			var l := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
			ls.append(l)
			sum += l
			sq += l * l
	ls.sort()
	var n := float(ls.size())
	var mean := sum / n
	return {"mean": snappedf(mean, 0.0001), "p95": snappedf(ls[int(n * 0.95)], 0.0001),
		"p995": snappedf(ls[int(n * 0.995)], 0.0001), "std": snappedf(sqrt(maxf(sq / n - mean * mean, 0.0)), 0.0001),
		"max": snappedf(ls[ls.size() - 1], 0.0001)}
