extends Node

## The system map as the game shows it, photographed:
##   godot --path . -- sheet=SystemShot out=<png> [seed=N] [node=I] [at=S] [hover=b|w|s] [select=I]
## `hover=b` points at the first beacon, `w` at the first world, `s` at the star;
## `select=I` selects body I (-1 the star) and shows it in the panel; `open=K`
## opens the K-th beacon in the panel; `take=J` then takes its choice J and shows
## the result. Needs a window.

const ScreenS := preload("res://scripts/ui/sysmap/SystemMapScreen.gd")


func _ready() -> void:
	var out := "user://system.png"
	var idx := -1
	var at := 30.0
	var hover := ""
	var select := -2
	var open := -1
	var take := -1
	## `off=shadows|rays|dust`: one layer switched off, to see what it does
	var off := ""
	## `zoom=Z` holds the map at that zoom; `loc` holds LOCATION on your ship
	var zoom := 1.0
	Rng.forced = 4242
	for a in OS.get_cmdline_user_args():
		var s := a as String
		if s.begins_with("out="):
			out = s.substr(4)
		elif s.begins_with("seed="):
			Rng.forced = int(s.substr(5))
		elif s.begins_with("node="):
			idx = int(s.substr(5))
		elif s.begins_with("at="):
			at = float(s.substr(3))
		elif s.begins_with("hover="):
			hover = s.substr(6)
		elif s.begins_with("select="):
			select = int(s.substr(7))
		elif s.begins_with("open="):
			open = int(s.substr(5))
		elif s.begins_with("zoom="):
			zoom = float(s.substr(5))
		elif s.begins_with("off="):
			off = s.substr(4)
		elif s.begins_with("take="):
			take = int(s.substr(5))
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var n: MapGen.MapNode = null
	if idx >= 0:
		n = Run.map[idx]
	else:
		for raw in Run.map:
			var m: MapGen.MapNode = raw
			OptionTable.ensure(m)
			if m.type == MapGen.NodeType.SYSTEM and m.options.size() >= 3:
				n = m
				break
	# WHERE MAIN PUTS IT: the content area, under the HUD.
	var content := Control.new()
	content.position = Vector2(8, 32)
	content.size = Vector2(944, 501)
	add_child(content)
	var bake = load("res://scripts/ui/sysmap/SkyBake.gd")
	bake.no_rays = off == "rays"
	bake.no_dust = off == "dust"
	# `plain`: small worlds without the richer drawing, for comparing
	PlanetView.no_rich = "plain" in OS.get_cmdline_user_args()
	# `small`: worlds at their laid-out size, not the 10 px minimum; `noship`: the ship left at the edge
	load("res://scripts/ui/sysmap/SystemView.gd").min_r = 0.0 if "small" in OS.get_cmdline_user_args() else 10.0
	var scr: Control = ScreenS.new()
	content.add_child(scr)
	scr.frozen = true
	await scr.show_system(n, at)
	# `blocks`: the worlds in 2x2 blocks too, like the suns (the whole map in B)
	if "blocks" in OS.get_cmdline_user_args():
		for v2 in scr.view._views.values():
			for c2 in v2.get_children():
				if c2 is CanvasItem and (c2 as CanvasItem).material is ShaderMaterial:
					((c2 as CanvasItem).material as ShaderMaterial).set_shader_parameter("cell", 2)
	scr.overlay.ship_park = -3 if "noship" in OS.get_cmdline_user_args() else 0
	scr._zoom_to = zoom
	# `sunlook=C,S`: the sun in C x C blocks, every S-th colour (the red giant review)
	for a2 in OS.get_cmdline_user_args():
		if (a2 as String).begins_with("sunlook="):
			var parts := (a2 as String).substr(8).split(",")
			var m: ShaderMaterial = scr.view.star.get("_mat")
			m.set_shader_parameter("cell", int(parts[0]))
			m.set_shader_parameter("pal_stride", int(parts[1]))
	scr.view.zoom = zoom
	if "loc" in OS.get_cmdline_user_args():
		scr._location_on = true
		scr._paint_location()
		scr._zoom_to = scr.ZOOM_LOCATION
	if off == "shadows":
		scr.view._shadows.visible = false
	if select >= -1:
		scr.select_body(select)
	if open >= 0:
		var k := 0
		for bi in scr.view.layout.bodies.size():
			for bc in scr.view.layout.bodies[bi].beacons:
				if k == open:
					scr.overlay.selected = bi
					scr.panel.show_beacon(bi, bc)
					if take >= 0 and bc.opt >= 0:
						await scr.take_choice(bc.opt, take)
				k += 1
	for _i in (90 if "loc" in OS.get_cmdline_user_args() else 10):
		await get_tree().process_frame
	if hover != "":
		var p := Vector2.ZERO
		if hover == "b" and not scr.overlay.beacons_at.is_empty():
			p = scr.overlay.beacons_at[0][0]
		elif hover == "w":
			p = scr.view.at[0]
		elif hover == "s":
			p = Vector2(scr.view.CX, scr.view.CY)
		scr.overlay.hover = scr.overlay.hit(p)
	# `wheel`: six notches in over the first world, then a drag to the left, as
	# a player's mouse would send them, and where the world ends up on screen
	if "wheel" in OS.get_cmdline_user_args():
		var w0: Vector2 = scr.view.at[0]
		var fp: Vector2 = w0 + scr._box.position
		print("  systemshot: world 0 at %s before" % w0)
		for _k in 6:
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_WHEEL_UP
			ev.pressed = true
			ev.position = fp
			scr._on_map_input(ev)
		for _i in 60:
			await get_tree().process_frame
		print("  systemshot: zoom %.2f, world 0 at %s (should stay near %s)" % [scr.view.zoom, scr.view.at[0], w0])
		var down := InputEventMouseButton.new()
		down.button_index = MOUSE_BUTTON_LEFT
		down.pressed = true
		down.position = Vector2(500, 300)
		scr._on_map_input(down)
		var mv := InputEventMouseMotion.new()
		mv.position = Vector2(400, 300)
		mv.relative = Vector2(-100, 0)
		scr._on_map_input(mv)
		var up := InputEventMouseButton.new()
		up.button_index = MOUSE_BUTTON_LEFT
		up.pressed = false
		up.position = Vector2(400, 300)
		scr._on_map_input(up)
		for _i in 3:
			await get_tree().process_frame
		print("  systemshot: after a 100 px drag left, pan %s, selected %d (should stay -2)" % [scr.view.pan, scr.overlay.selected])
	# `follow`: LOCATION held on a running clock; where the ship and its world are
	# drawn, frame by frame, once it has locked on -- both should hold still
	if "follow" in OS.get_cmdline_user_args():
		scr.frozen = false
		scr._location_on = false
		scr._on_location()
		for _i in 150:
			await get_tree().process_frame
		var ships := {}
		var worlds := {}
		for _i in 240:
			await get_tree().process_frame
			ships[scr.overlay._ship_at] = true
			worlds[scr.view.at[0]] = true
		print("  systemshot: locked %s, zoom %.2f; over 240 frames the ship was drawn at %d places %s, its world at %d %s" % [scr._locked, scr.view.zoom, ships.size(), ships.keys().slice(0, 4), worlds.size(), worlds.keys().slice(0, 4)])
		scr._on_location()
		for _i in 150:
			await get_tree().process_frame
		print("  systemshot: let go: zoom %.3f, pan %s" % [scr.view.zoom, scr.view.pan])
	# `commit`: the ship at the edge, a beacon opened, a choice taken on a running
	# clock: the ship should stay put on opening and fly before the result
	if "commit" in OS.get_cmdline_user_args():
		scr.frozen = false
		scr.overlay.ship_park = -3
		var first = null
		var fb := -1
		for bi in scr.view.layout.bodies.size():
			for bc in scr.view.layout.bodies[bi].beacons:
				if first == null and bc.opt >= 0:
					first = bc
					fb = bi
		scr.open_beacon(fb, first)
		for _i in 20:
			await get_tree().process_frame
		print("  systemshot: opened; ship park %d, flying %s (should be -3, false)" % [scr.overlay.ship_park, scr.overlay.ship_fly_t0 >= 0.0])
		scr.take_choice(first.opt, 0)
		await get_tree().process_frame
		print("  systemshot: chose; flying %s, result showing %s (should be true, false)" % [scr.overlay.ship_fly_t0 >= 0.0, scr._res_opt >= 0])
		var t0 := Time.get_ticks_msec()
		while scr._res_opt < 0 and Time.get_ticks_msec() - t0 < 4000:
			await get_tree().process_frame
		print("  systemshot: after %.1f s: parked at %d (body %d), result showing %s" % [(Time.get_ticks_msec() - t0) / 1000.0, scr.overlay.ship_park, fb, scr._res_opt >= 0])
	if "cursor" in OS.get_cmdline_user_args():
		scr._cursor.set("at", Vector2(scr.view.CX + 150, scr.view.CY + 60))
		scr._cursor.queue_redraw()
	for _i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	# where each world is in the saved picture, and how big, for cropping
	for i: int in scr.view._views:
		var b: SystemLayout.Body = scr.view.layout.bodies[i]
		var gp: Vector2 = scr.view.at[i] + scr._box.get_global_transform_with_canvas().origin
		print("  systemshot: world %d %s at %s r %.1f" % [i, b.world, gp.round(), b.r * scr.view.zoom])
	print("  systemshot: system %d (%s) to %s" % [n.index, MapGen.star_name(n), out])
	get_tree().quit()
