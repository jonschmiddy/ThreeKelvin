extends Node

## A RINGED WORLD IN EVERY RING LOOK, photographed in the game (Jon: "can these
## rings be a bit nicer? they're flat"):
##   godot --path . -- sheet=RingSheet out=<dir> [node=N] [body=B] [at=S] [seed=N]
## The real system map, centred on the world, at zoom 1, 2 and 4; the panel's
## portrait of it; and the world alone at one pixel a pixel, as `-- planetsheet`
## draws it, lit as the portrait is and then from the ring's dark side -- once
## for each of `Rings.Look` (the dots as they are, then A, B and C). Each picture is saved as <dir>/<look>_<what>.png at game scale for a
## sheet to be made from. Without `node=`, the first system holding a ringed
## giant. Needs a window: a shader draws nothing headless.

const ScreenS := preload("res://scripts/ui/sysmap/SystemMapScreen.gd")
const NAMES := ["dots", "A", "B", "C"]
const ZOOMS := [1.0, 2.0, 4.0]
## The picture kept round the world at each zoom, in game pixels.
const TILE := {1.0: Vector2i(120, 64), 2.0: Vector2i(220, 104), 4.0: Vector2i(400, 180)}


func _ready() -> void:
	var out := "user://rings"
	var idx := -1
	var bi := -1
	var at := 30.0
	Rng.forced = 4242
	for a in OS.get_cmdline_user_args():
		var s := a as String
		if s.begins_with("out="):
			out = s.substr(4)
		elif s.begins_with("node="):
			idx = int(s.substr(5))
		elif s.begins_with("body="):
			bi = int(s.substr(5))
		elif s.begins_with("at="):
			at = float(s.substr(3))
		elif s.begins_with("seed="):
			Rng.forced = int(s.substr(5))
	DirAccess.make_dir_recursive_absolute(out)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var n: MapGen.MapNode = null
	for raw in Run.map:
		var m: MapGen.MapNode = raw
		if m.type != MapGen.NodeType.SYSTEM or (idx >= 0 and m.index != idx):
			continue
		for b in SystemLayout.of(m).bodies:
			if (bi < 0 or b.index == bi) and Worlds.WORLD.get(b.world, {}).get("giant", false) and Worlds.spec(b.world, b.seed, b.r).ring:
				n = m
				bi = b.index
				break
		if n != null:
			break
	if n == null:
		push_error("ringsheet: no ringed giant there")
		get_tree().quit(1)
		return
	Run.at = n.index
	var content := Control.new()
	var main := get_parent() as Control
	content.theme = main.theme if main != null and main.theme != null else UITheme.build()
	content.position = Vector2(8, 32)
	content.size = Vector2(944, 501)
	add_child(content)
	var scr: Control = ScreenS.new()
	content.add_child(scr)
	scr.frozen = true
	await scr.show_system(n, at)
	scr.overlay.ship_park = -3
	# the brackets, the names and the beacons off the photographs
	scr.overlay.visible = false
	var view = scr.view
	var B: SystemLayout.Body = view.layout.bodies[bi]
	print("  ringsheet: system %d, body %d, %s, r %.1f" % [n.index, bi, B.world, B.r])
	for look in NAMES.size():
		PlanetView.ring_style = look
		for z: float in ZOOMS:
			var p: Vector2 = B.pos(view.t)
			scr._zoom_to = z
			view.zoom = z
			view.pan = -Vector2(p.x, p.y * view.TILT) * z
			view._drawn_zoom = z
			for i: int in view._views:
				var bw: SystemLayout.Body = view.layout.bodies[i]
				view._views[i].call("set_world", bw.world, bw.seed, view.world_r(bw) * z)
			scr.select_body(bi)
			for _i in 6:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			var c: Vector2 = view.at[bi] + scr._box.get_global_transform_with_canvas().origin
			var T: Vector2i = TILE[z]
			_crop(img, c, T).save_png("%s/%s_z%d.png" % [out, NAMES[look], int(z)])
			# the panel's portrait, once, at zoom 1
			if z == 1.0:
				var pv: Node2D = scr.panel.get("_portrait")
				if pv != null:
					_crop(img, pv.get_global_transform_with_canvas().origin, Vector2i(130, 70)).save_png("%s/%s_panel.png" % [out, NAMES[look]])
	# THE WORLD ALONE, one pixel a pixel, lit as the portrait is
	var bg := ColorRect.new()
	bg.color = Color("#070a12")
	bg.size = Vector2(960, 540)
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	layer.add_child(bg)
	# and again lit from below and a little behind, so the ring shows its dark
	# face: the light coming through it
	var solo: Array[Node2D] = []
	for row in 2:
		for look in NAMES.size():
			PlanetView.ring_style = look
			var pv2: Node2D = Worlds.view_for(B.world)
			pv2.position = Vector2(100 + look * 160, 100 + row * 120)
			layer.add_child(pv2)
			pv2.call("set_world", B.world, B.seed, 22.0)
			solo.append(pv2)
	for k in solo.size():
		solo[k].call("step", view.t, Vector3(-0.83, -0.31, 0.47) if k < NAMES.size() else Vector3(-0.85, 0.45, -0.15))
	for _i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img2 := get_viewport().get_texture().get_image()
	for look in NAMES.size():
		_crop(img2, solo[look].position, Vector2i(130, 70)).save_png("%s/%s_cell1.png" % [out, NAMES[look]])
		_crop(img2, solo[look + NAMES.size()].position, Vector2i(130, 70)).save_png("%s/%s_dark.png" % [out, NAMES[look]])
	PlanetView.ring_style = Rings.Look.ICY
	print("  ringsheet: to %s" % out)
	get_tree().quit()


func _crop(img: Image, c: Vector2, T: Vector2i) -> Image:
	var r := Rect2i(Vector2i(c.round()) - T / 2, T).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	return img.get_region(r)
