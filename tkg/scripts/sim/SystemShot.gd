extends Node

## The system map as the game shows it, photographed:
##   godot --path . -- sheet=SystemShot out=<png> [seed=N] [node=I] [at=S] [hover=b|w|s] [select=I]
## `hover=b` points at the first beacon, `w` at the first world, `s` at the star;
## `select=I` selects body I (-1 the star) and shows it in the panel; `open=K`
## opens the K-th beacon in the panel; `take=J` then takes its choice J and shows
## the result. Needs a window.
## The panel's states (the event list Jon picked, B with the stamp):
##   `takes=i:j,i:j`  takes option i's choice j, in order, before anything is
##                    shown -- walk-aways included -- so the list wears its stamps
##   `partner=i`      a partner, VEGA, claimed option i (and closed its set)
##   `hovercard=K`    points at the K-th card in the list
##   `hoverbeacon=K`  points at the K-th beacon on the map
##   `hoverchoice=J`  with `open=`, points at choice J on the event page
## `take=J` parks the ship at the event's world first, so the clock need not run.

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
	## `zoom=Z` holds the map at that zoom (the opening zoom, the whole system, if
	## not given); `loc` holds LOCATION on your ship
	var zoom := -1.0
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
	# `kinds`: the systems in each kind of nebula (`NebulaField.Kind`), with
	# their star's kind, and quit -- to find one of each to photograph
	if "kinds" in OS.get_cmdline_user_args():
		var by := {}
		for nk: MapGen.MapNode in Run.map:
			var ck = NebulaField.at(nk.gal) if nk.in_nebula else null
			var key: String = "clear" if ck == null else str(int(ck.kind))
			if not by.has(key):
				by[key] = []
			by[key].append("%d(s%d)" % [nk.index, SystemLayout.of(nk).star])
		for key: String in by:
			print("  systemshot: kind %s: %s" % [key, " ".join(PackedStringArray((by[key] as Array).slice(0, 14)))])
		get_tree().quit()
		return
	var n: MapGen.MapNode = null
	if idx >= 0:
		n = Run.map[idx]
	elif "belt" in OS.get_cmdline_user_args():
		# `belt`: the first system with an asteroid belt (for `hoverbelt`)
		for raw in Run.map:
			var m: MapGen.MapNode = raw
			OptionTable.ensure(m)
			if m.type == MapGen.NodeType.SYSTEM and SystemLayout.of(m).bodies.any(func(bb: SystemLayout.Body) -> bool: return bb.kind == &"belt"):
				n = m
				break
	elif "empty" in OS.get_cmdline_user_args():
		# `empty`: a sector with no events at all (the sector page alone): the
		# run's start, quiet on purpose
		n = Run.map[Run.at]
		print("empty: node %d, %s, %d bodies" % [n.index, MapGen.star_name(n), SystemLayout.of(n).bodies.size()])
	elif "core" in OS.get_cmdline_user_args():
		# `core`: the core (the black hole)
		for raw in Run.map:
			var m: MapGen.MapNode = raw
			if m.type == MapGen.NodeType.CORE:
				n = m
				break
	elif "pulsar" in OS.get_cmdline_user_args():
		# `pulsar`: the first pulsar (a star with an event of its own, HARVEST)
		for raw in Run.map:
			var m: MapGen.MapNode = raw
			if m.type == MapGen.NodeType.PULSAR:
				OptionTable.ensure(m)
				n = m
				break
	else:
		for raw in Run.map:
			var m: MapGen.MapNode = raw
			OptionTable.ensure(m)
			if m.type == MapGen.NodeType.SYSTEM and m.options.size() >= 3:
				n = m
				break
	# THE SHIP IS HERE, as it is whenever the game shows a system: resolving an
	# option records it on `Run.node_at()`, so photographing a system the run is
	# not at would stamp the wrong one
	Run.at = n.index
	# WHERE MAIN PUTS IT: the content area, under the HUD.
	var content := Control.new()
	# MAIN'S THEME, which a plain Node between Main and the screen cut off:
	# every photo before this was in Godot's default font, with 16 px buttons
	var main := get_parent() as Control
	content.theme = main.theme if main != null and main.theme != null else UITheme.build()
	content.position = Vector2(8, 32)
	content.size = Vector2(944, 501)
	add_child(content)
	var bake = load("res://scripts/ui/sysmap/SkyBake.gd")
	bake.no_rays = off == "rays"
	bake.no_dust = off == "dust"
	# `plain`: small worlds without the richer drawing, for comparing
	PlanetView.no_rich = "plain" in OS.get_cmdline_user_args()
	# `ring=A|B|C`: the painted rings Jon is choosing between, not the dots
	PlanetView.ring_style = Rings.look_from_args()
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
	# parked by hand, not flown in: the screen should not take it for an arrival
	scr._was_at = scr.flight.reached()
	# the list again, now the ship is parked, so YOU sits on the right card
	scr.panel.show_system()
	if zoom < 0.0:
		zoom = scr.zoom_min
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
	for a3 in OS.get_cmdline_user_args():
		var s3 := a3 as String
		if s3.begins_with("partner="):
			var pk := int(s3.substr(8))
			Net.roster[7] = {"name": "Vega"}
			var here: Dictionary = Net.claims.get(n.index, {})
			here[MapGen.OPTION_SITE + pk] = 7
			Net.claims[n.index] = here
			if not n.taken.has(MapGen.OPTION_SITE + pk):
				n.taken.append(MapGen.OPTION_SITE + pk)
			OptionTable.foreclose(n, pk)
		elif s3.begins_with("takes="):
			for pair in s3.substr(6).split(","):
				var ij := (pair as String).split(":")
				var r: Dictionary = await OptionResolve.take(n, int(ij[0]), int(ij[1]))
				print("  systemshot: took %s:%s ok %s stay %s" % [ij[0], ij[1], r.get("ok"), r.get("stay")])
	# `reload`: the run saved and loaded again before the shot, so the cards are
	# read back off the file (Jon: "left alone should survive a reload"). Any
	# save already on disk is put back afterwards.
	if "reload" in OS.get_cmdline_user_args():
		var keep := FileAccess.get_file_as_bytes(SaveGame.PATH) if FileAccess.file_exists(SaveGame.PATH) else PackedByteArray()
		SaveGame.save()
		var loaded := SaveGame.load_into_run()
		if keep.is_empty():
			SaveGame.clear()
		else:
			var fk := FileAccess.open(SaveGame.PATH, FileAccess.WRITE)
			fk.store_buffer(keep)
			fk.close()
		n = Run.map[n.index]
		Run.at = n.index
		await scr.show_system(n, at, false)
		scr.overlay.ship_park = 0
		print("  systemshot: saved and reloaded: %s" % loaded)
	# the list again, wearing whatever was taken above
	scr.panel.show_system()
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
						scr.overlay.ship_park = bi
						scr.take_choice(bc.opt, take)
						for _w in 6:
							await get_tree().process_frame
				k += 1
	# `focus=I`: the camera held on body I at the zoom given (a world close up)
	var focus := -9
	for a15 in OS.get_cmdline_user_args():
		if (a15 as String).begins_with("focus="):
			focus = int((a15 as String).substr(6))
	for _i in (90 if "loc" in OS.get_cmdline_user_args() else 10):
		if focus >= 0:
			scr._zoom_to = zoom
			scr.view.zoom = zoom
			scr.view.pan = -scr.overlay.place_rel(focus)
		await get_tree().process_frame
	if focus >= 0:
		var fb: SystemLayout.Body = scr.view.layout.bodies[focus]
		print("  systemshot: focus on %s (%s, %s), %d moons, drawn r %.1f, on the plane at %s" % [fb.name, fb.kind, fb.world, int(scr.view._views[focus].get("spec").get("moons", 0)) if scr.view._views.has(focus) else -1, scr.view.draw_r(fb), scr.flight.center(focus, scr.view.t).round()])
	for a4 in OS.get_cmdline_user_args():
		var s4 := a4 as String
		if s4.begins_with("hovercard="):
			var cards: Array = scr.panel._box.get_children().filter(func(c: Node) -> bool: return c.has_method("set_doomed"))
			var ci := int(s4.substr(10))
			if ci < cards.size():
				cards[ci].notification(Control.NOTIFICATION_MOUSE_ENTER)
		elif s4.begins_with("hoverbeacon="):
			var bi2 := int(s4.substr(12))
			if bi2 < scr.overlay.beacons_at.size():
				scr.overlay.hover = scr.overlay.hit(scr.overlay.beacons_at[bi2][0])
				scr._light_from_map(scr.overlay.hover)
		elif s4.begins_with("hoverchoice="):
			var plates: Array = scr.panel._box.get_children().filter(func(c: Node) -> bool: return c is EncounterDrawer.OptionCard)
			var pj := int(s4.substr(12))
			if pj < plates.size():
				plates[pj].notification(Control.NOTIFICATION_MOUSE_ENTER)
				plates[pj].mouse_entered.emit()
	for i3 in n.options.size():
		var st3 := EncounterDrawer.option_state(n, i3)
		print("  systemshot: option %d %s -- %s %s" % [i3, OptionTable.by_id(n.options[i3]).get("title", ""), st3.kind, st3.word])
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
	# THE FLOWN SHIP. `shipfree=x,z,vx,vz` puts it free on the plane, moving, so its
	# dotted line shows; `keys=w,d` holds those keys and `run=S` runs the clock S
	# seconds (with them held); `again=I` selects place I and clicks it again, and
	# the clock runs until the ship is in orbit there; `selectonly=I` selects it
	# and stops, so the flight a second click would fly is drawn; `hoverbelt`
	# points at the first belt's band.
	for a5 in OS.get_cmdline_user_args():
		var s5 := a5 as String
		if s5.begins_with("shipfree="):
			var q := s5.substr(9).split(",")
			scr.flight.mode = &"free"
			scr.flight.f.p = Vector2(float(q[0]), float(q[1]))
			scr.flight.f.v = Vector2(float(q[2]), float(q[3])) if q.size() >= 4 else Vector2.ZERO
			scr.flight.f.head = atan2(scr.flight.f.v.y * 0.38, scr.flight.f.v.x) if q.size() >= 4 else PI
			scr.flight.ang = scr.flight.f.head
			scr.panel.show_system()
			scr.overlay.selected = -2
		elif s5.begins_with("keys="):
			scr.harness_keys = true
			for kk in s5.substr(5).split(","):
				scr._wasd[kk] = true
		elif s5.begins_with("selectonly="):
			scr.select_body(int(s5.substr(11)))
		elif s5.begins_with("again="):
			var ai := int(s5.substr(6))
			scr.frozen = false
			scr.tap({"kind": &"star" if ai == -1 else &"body", "body": ai, "beacon": null, "at": Vector2.ZERO})
			scr.tap({"kind": &"star" if ai == -1 else &"body", "body": ai, "beacon": null, "at": Vector2.ZERO})
			var t1 := Time.get_ticks_msec()
			print("  systemshot: again: flying %s" % (scr.flight.mode == &"fly"))
			while scr.flight.reached() != ai and Time.get_ticks_msec() - t1 < 12000:
				await get_tree().process_frame
			for _w2 in 20:
				await get_tree().process_frame
			print("  systemshot: again: after %.1f s in orbit of %d: %s" % [(Time.get_ticks_msec() - t1) / 1000.0, ai, scr.flight.reached() == ai])
			scr.frozen = true
		elif s5.begins_with("fly="):
			# `fly=I`: flies to place I as a second click does, and goes on (with
			# `run=` after it, the ship is caught on the way)
			var fi := int(s5.substr(4))
			scr.select_body(fi)
			scr.fly_to_body(fi)
			print("  systemshot: fly: to %d, mode %s" % [fi, scr.flight.mode])
		elif s5.begins_with("run="):
			scr.frozen = false
			var t2 := Time.get_ticks_msec()
			while Time.get_ticks_msec() - t2 < int(float(s5.substr(4)) * 1000.0):
				# held keys are checked against the keyboard (a lost release), which a
				# harness has none of: hold them again every frame
				for kk2 in OS.get_cmdline_user_args():
					if (kk2 as String).begins_with("keys="):
						for k3 in (kk2 as String).substr(5).split(","):
							scr._wasd[k3] = true
				await get_tree().process_frame
			scr.frozen = true
			print("  systemshot: ran; mode %s at %s reached %d status %s; drawn at %s" % [scr.flight.mode, scr.flight.f.p.round(), scr.flight.reached(), scr.overlay.ship_status()[0], (scr.overlay._ship_at + scr._box.get_global_transform_with_canvas().origin).round()])
		elif s5 == "hoverbelt":
			for bi5 in scr.view.layout.bodies.size():
				var b5: SystemLayout.Body = scr.view.layout.bodies[bi5]
				if b5.kind == &"belt":
					var sp5: Vector2 = scr.view.screen(cos(2.4) * b5.orbit, sin(2.4) * b5.orbit)
					scr.overlay.hover = scr.overlay.hit(sp5)
					print("  systemshot: hoverbelt %s" % [scr.overlay.hover.get("kind", "")])
					break
	# `zoomclip=<dir>` (`zfrom=` `zto=` `zframes=` `zworld`): A SLOW ZOOM, filmed
	# frame by frame on a stopped clock (so only the zoom changes anything), the
	# map window saved each frame with where the star and each world are drawn
	# and how big (`frames.json`) -- to count what shimmers. About the star at
	# the middle, or with `zworld` held on the first world (as LOCATION holds it).
	for a8 in OS.get_cmdline_user_args():
		if not (a8 as String).begins_with("zoomclip="):
			continue
		var zdir := (a8 as String).substr(9)
		DirAccess.make_dir_recursive_absolute(zdir)
		var z0 := 0.6
		var z1 := 2.4
		var nz := 240
		for a9 in OS.get_cmdline_user_args():
			var s9 := a9 as String
			if s9.begins_with("zfrom="):
				z0 = float(s9.substr(6))
			elif s9.begins_with("zto="):
				z1 = float(s9.substr(4))
			elif s9.begins_with("zframes="):
				nz = int(s9.substr(8))
		var wi := -9
		if "zworld" in OS.get_cmdline_user_args():
			for bi9 in scr.view.layout.bodies.size():
				if scr.view.layout.bodies[bi9].world != &"":
					wi = bi9
					break
		scr.frozen = true
		scr._location_on = false
		# `zstill`: the room's sound stopped, so a pulsar's beat (set by what is
		# heard) holds still on the stopped clock and only the zoom changes it
		if "zstill" in OS.get_cmdline_user_args():
			Audio.room(&"", 0.01)
		# `zback`: the zoom run back from `zto` to `zfrom` after it
		var zback := "zback" in OS.get_cmdline_user_args()
		# `zhide=fabric,lines,belts,overlay`: those layers off, to find what flickers
		for a10 in OS.get_cmdline_user_args():
			if (a10 as String).begins_with("zhide="):
				for nm10 in (a10 as String).substr(6).split(","):
					var node10: CanvasItem = scr.overlay if nm10 == "overlay" else (scr.view.star if nm10 == "star" else scr.view.get("_" + nm10))
					if node10 != null:
						node10.visible = false
		var rows9: Array = []
		var origin9: Vector2 = scr._box.get_global_transform_with_canvas().origin
		for k9 in (nz * 2 + 1 if zback else nz + 1):
			var u9: float = float(k9) / float(nz)
			if u9 > 1.0:
				u9 = 2.0 - u9
			var z: float = z0 * pow(z1 / z0, u9)
			scr._zoom_to = z
			scr.view.zoom = z
			scr.view.pan = -scr.overlay.place_rel(wi) if wi >= 0 else Vector2.ZERO
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			var w9: Rect2 = scr.view.window
			var crop := Rect2i(Vector2i(origin9 + w9.position), Vector2i(w9.size))
			img.get_region(crop).save_png("%s/f_%04d.png" % [zdir, k9])
			var bods: Array = []
			for i9 in scr.view.at.size():
				var b9: SystemLayout.Body = scr.view.layout.bodies[i9]
				bods.append([i9, b9.world != &"", scr.view.at[i9].x - w9.position.x, scr.view.at[i9].y - w9.position.y, scr.view.draw_r(b9)])
			var o9: Vector2 = scr.view.origin() - w9.position
			# where each sky layer sits (its parallax offset): how far the stars slide
			var par9: Array = [[scr.view.sky_off().x, scr.view.sky_off().y]]
			for f9 in scr.view._fields:
				par9.append([f9.off.x, f9.off.y])
			# the scale each of a pulsar's layers was given: its own drawing and web
			# (`PulsarView.zoom`), and the remnant shell in the sky (`shell_k`)
			var lay9 := {}
			if scr.view.layout.star == SystemLayout.StarKind.PULSAR:
				lay9 = {"pulsar": float(scr.view.star.get("zoom")), "shell": float(scr.view._sky_mat.get_shader_parameter("shell_k")),
					"sky_z": scr.view._sky_z, "home": scr.view.home_zoom}
			rows9.append({"zoom": z, "star": [o9.x, o9.y, scr.view.layout.star_r * scr.view.star_k()], "bodies": bods, "par": par9, "layers": lay9})
		var fz := FileAccess.open(zdir + "/frames.json", FileAccess.WRITE)
		fz.store_string(JSON.stringify(rows9))
		fz.close()
		print("  systemshot: zoomclip %d frames, %.2f to %.2f, world %d" % [nz + 1, z0, z1, wi])
	# `panclip=<dir>` (`pzoom=Z`, `pframes=N`, `pdist=D`): A SLOW PAN across the
	# map at zoom Z, frame by frame on a stopped clock (only the camera moves),
	# the map window saved each frame -- to see the sky's depths slide
	for a13 in OS.get_cmdline_user_args():
		if not (a13 as String).begins_with("panclip="):
			continue
		var pdir := (a13 as String).substr(8)
		DirAccess.make_dir_recursive_absolute(pdir)
		var pz := 2.0
		var pn := 120
		var pd := 360.0
		for a14 in OS.get_cmdline_user_args():
			var s14 := a14 as String
			if s14.begins_with("pzoom="):
				pz = float(s14.substr(6))
			elif s14.begins_with("pframes="):
				pn = int(s14.substr(8))
			elif s14.begins_with("pdist="):
				pd = float(s14.substr(6))
		scr.frozen = true
		scr._location_on = false
		if "zstill" in OS.get_cmdline_user_args():
			Audio.room(&"", 0.01)
		var origin13: Vector2 = scr._box.get_global_transform_with_canvas().origin
		for k13 in pn + 1:
			var u13 := float(k13) / float(pn)
			scr._zoom_to = pz
			scr.view.zoom = pz
			scr.view.pan = Vector2(lerpf(pd, -pd, u13), lerpf(pd * 0.25, -pd * 0.25, u13))
			await RenderingServer.frame_post_draw
			var img13 := get_viewport().get_texture().get_image()
			var w13: Rect2 = scr.view.window
			img13.get_region(Rect2i(Vector2i(origin13 + w13.position), Vector2i(w13.size))).save_png("%s/f_%04d.png" % [pdir, k13])
		print("  systemshot: panclip %d frames at zoom %.2f" % [pn + 1, pz])
	# `camclip=<dir>` (`cam=loc|unloc|focus|home`, `cframes=N`): THE CAMERA'S
	# MOVE as the game makes it -- LOCATION pressed, pressed again, a right-click
	# on the selected world, a right-click out -- the window saved each frame with
	# the zoom and where the ship and the world are on screen (`cam.json`)
	for a16 in OS.get_cmdline_user_args():
		if not (a16 as String).begins_with("camclip="):
			continue
		var cdir := (a16 as String).substr(8)
		DirAccess.make_dir_recursive_absolute(cdir)
		var cn := 60
		var moves: Array = []
		for a17 in OS.get_cmdline_user_args():
			var s17 := a17 as String
			if s17.begins_with("cframes="):
				cn = int(s17.substr(8))
			elif s17.begins_with("cam="):
				moves = Array(s17.substr(4).split(","))
		scr.frozen = false
		var origin16: Vector2 = scr._box.get_global_transform_with_canvas().origin
		var rows16: Array = []
		var fr := 0
		for mv in moves:
			match String(mv):
				"loc", "unloc":
					scr._on_location()
				"focus":
					scr.select_body(0)
					scr.right_click({"kind": &"body", "body": 0})
				"home":
					scr.right_click({})
			for k16 in cn:
				await RenderingServer.frame_post_draw
				var img16 := get_viewport().get_texture().get_image()
				var w16: Rect2 = scr.view.window
				img16.get_region(Rect2i(Vector2i(origin16 + w16.position), Vector2i(w16.size))).save_png("%s/f_%04d.png" % [cdir, fr])
				var ship16: Vector2 = Vector2(scr.view.CX, scr.view.CY) + scr.view.pan + scr.overlay.ship_rel() - w16.position
				var w0: Vector2 = scr.view.at[0] - w16.position
				rows16.append({"zoom": scr.view.zoom, "ship": [ship16.x, ship16.y], "world0": [w0.x, w0.y], "move": mv})
				fr += 1
		var f16 := FileAccess.open(cdir + "/cam.json", FileAccess.WRITE)
		f16.store_string(JSON.stringify(rows16))
		f16.close()
		scr.frozen = true
		print("  systemshot: camclip %d frames" % fr)
	# `steady=S`: THE PLAN DRAWN BEFORE A FLIGHT, watched S seconds on a running
	# clock with the ship going round its orbit: how far the drawn path moves
	# from one frame to the next (its points, in map pixels), and how often it
	# jumps (a frame where some point moves more than 3 px)
	for a11 in OS.get_cmdline_user_args():
		if not (a11 as String).begins_with("steady="):
			continue
		scr.frozen = false
		var secs11 := float((a11 as String).substr(7))
		var t11 := Time.get_ticks_msec()
		var prev11 := PackedVector3Array()
		var worst11 := 0.0
		var jumps11 := 0
		var frames11 := 0
		var sum11 := 0.0
		while Time.get_ticks_msec() - t11 < int(secs11 * 1000.0):
			await get_tree().process_frame
			var cur11: PackedVector3Array = scr.overlay._pv_blend()
			if cur11.size() == prev11.size() and cur11.size() > 0:
				var m11 := 0.0
				for j11 in cur11.size():
					m11 = maxf(m11, cur11[j11].distance_to(prev11[j11]))
				worst11 = maxf(worst11, m11)
				sum11 += m11
				frames11 += 1
				if m11 > 3.0:
					jumps11 += 1
			prev11 = cur11
		scr.frozen = true
		print("  systemshot: steady %.0f s, %d frames: the drawn plan moves at most %.2f px a frame (mean %.2f), %d frames over 3 px; ship %s" % [secs11, frames11, worst11, sum11 / maxf(1.0, frames11), jumps11, scr.overlay.ship_status()[0]])
	# `plandump=<json>`: the plan the selected place's preview draws, its points,
	# burns and insertion, for finding a corner in it
	for a12 in OS.get_cmdline_user_args():
		if (a12 as String).begins_with("plandump="):
			var pl12 = scr.flight.make_plan(scr.overlay.selected, scr.view.t)
			var rows12 := {"samp": [], "burns": [], "tail": [], "esc_t": pl12.esc_t, "lead": pl12.lead, "kind": String(pl12.kind), "sdt": pl12.sdt}
			for q12 in pl12.samp:
				rows12.samp.append([q12.x, q12.y, q12.z])
			for b12 in pl12.burns:
				rows12.burns.append(b12)
			for q13 in pl12.tail:
				rows12.tail.append([q13.x, q13.y, q13.z])
			var f12 := FileAccess.open((a12 as String).substr(9), FileAccess.WRITE)
			f12.store_string(JSON.stringify(rows12))
			f12.close()
			print("  systemshot: plan dumped, %d points, tail %d, kind %s, escape %.2f" % [pl12.samp.size(), pl12.tail.size(), pl12.kind, pl12.esc_t])
	# `jetsam`: one thing left on this system's floor, then SECTOR LOOT
	# pressed as a player presses it -- so the button shows and opens the pile
	if "jetsam" in OS.get_cmdline_user_args():
		# (a material with nowhere to go lands on the system's floor)
		Run.add_material(Run.PULSAR_DROP, 1)
		scr.panel.show_system()
		await get_tree().process_frame
		var found_btn: Button = null
		for c14 in scr.panel._foot.get_children():
			if c14 is Button and (c14 as Button).text == "SECTOR LOOT":
				found_btn = c14
		print("  systemshot: jetsam: SECTOR LOOT %s" % ("shown" if found_btn != null else "hidden"))
		if found_btn != null:
			found_btn.pressed.emit()
			for _w14 in 6:
				await get_tree().process_frame
			print("  systemshot: jetsam: the pile opened: %s" % (scr._transfer != null))
	for c15 in scr.panel._foot.get_children():
		if c15 is Button:
			print("  systemshot: the panel's foot: %s" % (c15 as Button).text)
	if "cursor" in OS.get_cmdline_user_args():
		scr._cursor.set("at", Vector2(scr.view.CX + 150, scr.view.CY + 60))
		scr._cursor.queue_redraw()
	# `wclip=<dir>` (`wframes=N`, `wat=x,y` in from the map window's top left):
	# THE NEBULA'S WEATHER, one forced ten frames in, the window saved each
	# frame, the weather stepped a 30th of a second a frame
	for a18 in OS.get_cmdline_user_args():
		if not (a18 as String).begins_with("wclip="):
			continue
		var wdir := (a18 as String).substr(6)
		DirAccess.make_dir_recursive_absolute(wdir)
		var wn := 60
		var wat := Vector2.INF
		for a19 in OS.get_cmdline_user_args():
			var s19 := a19 as String
			if s19.begins_with("wframes="):
				wn = int(s19.substr(8))
			elif s19.begins_with("wat="):
				var wq := s19.substr(4).split(",")
				wat = scr.view.window.position + Vector2(float(wq[0]), float(wq[1]))
		if scr.view._weather == null:
			print("  systemshot: no weather here (not in a nebula)")
			continue
		scr.view._weather.step_s = 1.0 / 30.0
		var origin18: Vector2 = scr._box.get_global_transform_with_canvas().origin
		for k18 in wn:
			if k18 == 10:
				scr.view.weather_now(wat)
			await RenderingServer.frame_post_draw
			var img18 := get_viewport().get_texture().get_image()
			var w18: Rect2 = scr.view.window
			img18.get_region(Rect2i(Vector2i(origin18 + w18.position), Vector2i(w18.size))).save_png("%s/f_%04d.png" % [wdir, k18])
		print("  systemshot: wclip %d frames, weather kind %d" % [wn, scr.view._weather.kind])
	# `nova=S`: a distant supernova forced (at `novaat=x,y` in from the map
	# window's top left, or anywhere clear), photographed S seconds into it
	for a6 in OS.get_cmdline_user_args():
		if (a6 as String).begins_with("nova="):
			var nat := Vector2.INF
			for a7 in OS.get_cmdline_user_args():
				if (a7 as String).begins_with("novaat="):
					var nq := (a7 as String).substr(7).split(",")
					nat = scr.view.window.position + Vector2(float(nq[0]), float(nq[1]))
			scr.view.nova_now(nat)
			print("  systemshot: nova at %s, the window %s" % [nat, scr.view.window])
			await get_tree().create_timer(float((a6 as String).substr(5))).timeout
	for _i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	# where each world is in the saved picture, and how big, for cropping
	for i: int in scr.view._views:
		var b: SystemLayout.Body = scr.view.layout.bodies[i]
		var gp: Vector2 = scr.view.at[i] + scr._box.get_global_transform_with_canvas().origin
		print("  systemshot: world %d %s at %s r %.1f plane %s soi %.0f" % [i, b.world, gp.round(), b.r * scr.view.zoom, b.pos(scr.view.t).round(), b.soi])
	print("  systemshot: system %d (%s) to %s" % [n.index, MapGen.star_name(n), out])
	get_tree().quit()
