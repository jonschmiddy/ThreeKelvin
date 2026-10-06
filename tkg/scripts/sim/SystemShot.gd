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
## THE WEATHER (`SkyWeather`), filmed with `wclip=<dir>` (see `_wclip`):
##   `sky=<key>`      the first system whose sky is emission, reflection,
##                    planetary, remnant, dark, calm, pulsar or core; `shape=0..3`
##                    narrows a planetary one, `star=RED|BLUE|ORDINARY` a calm one
##   `wlist`          the sky, its temperament, its favourite and its events
##   `wprobe`         a mark at every point the weather's ported noise finds

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
	var sky_key := ""
	var sky_shape := -1
	var sky_star := ""
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
		elif s.begins_with("sky="):
			sky_key = s.substr(4)
		elif s.begins_with("shape="):
			sky_shape = int(s.substr(6))
		elif s.begins_with("star="):
			sky_star = s.substr(5)
		elif s == "wramp=0":
			load("res://scripts/ui/sysmap/SystemView.gd").no_ramp = true
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
	elif sky_key != "":
		# `sky=<key>`: the first system whose sky is that, the busiest first (most
		# options, so worlds, beacons and labels are on the map with the weather)
		var SW = load("res://scripts/ui/sysmap/SkyWeather.gd")
		var best := -1
		for raw in Run.map:
			var m: MapGen.MapNode = raw
			if m.type != MapGen.NodeType.SYSTEM and m.type != MapGen.NodeType.PULSAR and m.type != MapGen.NodeType.CORE:
				continue
			OptionTable.ensure(m)
			if String(SW.sky_of_node(m)) != sky_key:
				continue
			var L := SystemLayout.of(m)
			if "belt" in OS.get_cmdline_user_args() and not L.bodies.any(func(bb: SystemLayout.Body) -> bool: return bb.kind == &"belt"):
				continue
			if sky_star != "" and ["ORDINARY", "RED", "BLUE", "PULSAR", "CORE"][L.star] != sky_star:
				continue
			if sky_shape >= 0:
				var cl = NebulaField.at(m.gal) if m.in_nebula else null
				if cl == null or int(cl.shape) != sky_shape:
					continue
			var score := m.options.size() * 10 + L.bodies.size()
			if score > best:
				best = score
				n = m
		if n == null:
			print("  systemshot: no system with sky %s (shape %d, star %s) in this run" % [sky_key, sky_shape, sky_star])
			get_tree().quit()
			return
		print("  systemshot: sky %s: system %d" % [sky_key, n.index])
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
	# `nebkind=K`: the cloud this system sits in made kind K for the shot (no
	# emission cloud rolls on seed 4242; the showcase re-kinded ESO 101, round
	# BETA BRINE-4, node 142, the same way)
	for a22 in OS.get_cmdline_user_args():
		if (a22 as String).begins_with("nebkind="):
			var cl22 = NebulaField.at(n.gal) if n.in_nebula else null
			if cl22 != null:
				cl22.kind = int((a22 as String).substr(8)) as NebulaField.Kind
	# `rmotion`: reduced motion for the shot, in memory only (the gas held still,
	# so two builds can be compared without their clocks)
	if "rmotion" in OS.get_cmdline_user_args():
		DisplaySettings.reduced_motion = true
	# `bodies`: each body's index, kind, world and orbit, to aim `focus=` at
	# `scanmoons`: every system's worlds with moons, ringed or not, and quit (to
	# find a moon's eclipse to film)
	if "scanmoons" in OS.get_cmdline_user_args():
		for raw in Run.map:
			var mn: MapGen.MapNode = raw
			if mn.type != MapGen.NodeType.SYSTEM:
				continue
			var Lm := SystemLayout.of(mn)
			for bi in Lm.bodies.size():
				var bm: SystemLayout.Body = Lm.bodies[bi]
				if bm.world == &"":
					continue
				var spm := Worlds.spec(bm.world, bm.seed, bm.r)
				if int(spm.get("moons", 0)) > 0:
					print("  systemshot: moons node %d body %d %s %s r %.1f moons %d ring %s" % [mn.index, bi, bm.kind, bm.world, bm.r, int(spm.moons), str(spm.get("ring", false))])
		get_tree().quit()
		return
	if "bodies" in OS.get_cmdline_user_args():
		var Lb := SystemLayout.of(n)
		for bi in Lb.bodies.size():
			var bb: SystemLayout.Body = Lb.bodies[bi]
			print("  systemshot: body %d %s %s orbit %.0f r %.1f" % [bi, bb.kind, bb.world, bb.orbit, bb.r])
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
	# FILMING THE WEATHER: the wall clocks the gas and the supernova read held
	# from the start, so the palette (found from the first picture) and every
	# frame after are the same run to run, and a clip differs from its baseline
	# by the event alone
	for a0 in OS.get_cmdline_user_args():
		if (a0 as String).begins_with("wclip=") or (a0 as String).begins_with("wrun="):
			scr.view.hclock = 1000.0
		# a slow zoom or pan measures the camera alone: the gas held on its clock too
		if (a0 as String).begins_with("zoomclip=") or (a0 as String).begins_with("panclip="):
			scr.view.hclock = 1000.0
	await scr.show_system(n, at)
	# `fielddump=<dir>`: the cloud's bake (SIMPLIFIED's `SkyBake.field`), its two
	# density pictures as PNGs, to see what the sun is lighting
	for a23 in OS.get_cmdline_user_args():
		if (a23 as String).begins_with("fielddump=") and scr.view._bake != null and scr.view._bake.field_img0 != null:
			var fd := (a23 as String).substr(10)
			DirAccess.make_dir_recursive_absolute(fd)
			scr.view._bake.field_img0.save_png(fd.path_join("field0.png"))
			scr.view._bake.field_img1.save_png(fd.path_join("field1.png"))
			for chn in 4:
				var ch: Image = scr.view._bake.field_img0.duplicate()
				ch.convert(Image.FORMAT_RGBA8)
				for y in ch.get_height():
					for x in ch.get_width():
						var c := ch.get_pixel(x, y)
						var v: float = [c.r, c.g, c.b, c.a][chn]
						ch.set_pixel(x, y, Color(v, v, v, 1.0))
				ch.save_png(fd.path_join("t0_%s.png" % ["gas", "dust", "b", "a"][chn]))
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
	# FILMING THE WEATHER: the palette found at the opening zoom first, as the game
	# finds it (set to another zoom straight away, the palette raced the zoom and
	# was found at one or the other, so a clip and its baseline differed everywhere)
	for a0 in OS.get_cmdline_user_args():
		if (a0 as String).begins_with("wclip=") or (a0 as String).begins_with("wrun="):
			while not scr.view._palette_built:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
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
		var keep := FileAccess.get_file_as_bytes(SaveGame.path) if FileAccess.file_exists(SaveGame.path) else PackedByteArray()
		SaveGame.save()
		var loaded := SaveGame.load_into_run()
		if keep.is_empty():
			SaveGame.clear()
		else:
			var fk := FileAccess.open(SaveGame.path, FileAccess.WRITE)
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
		# `zrel`: `zfrom` and `zto` as times the opening zoom (the bible's slow zoom:
		# zfrom=1 zto=1.1 zframes=60)
		if "zrel" in OS.get_cmdline_user_args():
			z0 *= scr.zoom_min
			z1 *= scr.zoom_min
		var wi := -9
		# `zbody=I`: held on body I instead
		for a24 in OS.get_cmdline_user_args():
			if (a24 as String).begins_with("zbody="):
				wi = int((a24 as String).substr(6))
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
			# and the weather and the far supernovae held off: only the camera moves
			if scr.view._weather != null:
				scr.view._weather.auto = false
			if scr.view._nova != null:
				scr.view._nova.auto = false
		# `tstep=S`: the clock run on S seconds a frame (a moon sliding into its world's
		# shadow, its shadow crossing the face), from the time the shot opened at
		# (`tstart=S`: S seconds after it)
		var tstep := 0.0
		var tstart := 0.0
		for a25 in OS.get_cmdline_user_args():
			if (a25 as String).begins_with("tstep="):
				tstep = float((a25 as String).substr(6))
			elif (a25 as String).begins_with("tstart="):
				tstart = float((a25 as String).substr(7))
		var t_open: float = scr.view.t + tstart
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
			if tstep > 0.0:
				scr.view.t = t_open + tstep * float(k9)
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
			# the moons: where each is, how far toward you, how deep in its world's shadow
			var mo9: Array = []
			for mm9: Dictionary in scr.view._moons.positions(0.0):
				mo9.append([int(mm9.i), (mm9.c as Vector2).x - w9.position.x, (mm9.c as Vector2).y - w9.position.y, float(mm9.z), float(mm9.ecl)])
			rows9.append({"zoom": z, "star": [o9.x, o9.y, scr.view.layout.star_r * scr.view.star_k()], "bodies": bods, "par": par9, "layers": lay9, "moons": mo9})
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
			# and the weather and the far supernovae held off: only the camera moves
			if scr.view._weather != null:
				scr.view._weather.auto = false
			if scr.view._nova != null:
				scr.view._nova.auto = false
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
	# `wlist`: the sky's weather, as this system rolled it
	if "wlist" in OS.get_cmdline_user_args() and scr.view._weather != null:
		var W = scr.view._weather
		print("  systemshot: weather: sky %s, temperament %s, favourite %s" % [W.sky, W.temper, W.fav])
		for nm: StringName in W.TABLE[W.sky]:
			var e: Array = W.TABLE[W.sky][nm]
			print("  systemshot:   %-12s %-2s weight %.1f%s, lasts %.1f s, %s" % [nm, W.TIER_NAMES[int(e[0])], float(e[1]), " (favourite)" if nm == W.fav else "", float(e[2]), e[3]])
		for nm2: StringName in W.SHARED:
			print("  systemshot:   %-12s shared, here: %s" % [nm2, W.hosts(nm2)])
	# `wclip=<dir>`: THE WEATHER, FILMED (see `_wclip`)
	for a18 in OS.get_cmdline_user_args():
		if (a18 as String).begins_with("wclip="):
			await _wclip(scr, (a18 as String).substr(6))
	# `wrun=S`: THE SCHEDULER AT WORK for S seconds on a fast clock (see `_wrun`)
	for a20 in OS.get_cmdline_user_args():
		if (a20 as String).begins_with("wrun="):
			await _wrun(scr, float((a20 as String).substr(5)))
	# `wprobe`: a mark at every point the weather's ported noise found (the
	# cluster, the pillar tips, the stars, the rim, the strands, the band)
	if "wprobe" in OS.get_cmdline_user_args() and scr.view._weather != null:
		var pr := _Probe.new()
		pr.pts = scr.view._weather.probe_points()
		scr._vp.add_child(pr)
		print("  systemshot: wprobe %d points" % pr.pts.size())
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


## `wclip=<dir>`: THE WEATHER, FILMED. The map window saved each frame, the
## weather stepped a 30th of a second a frame (`wfps=60`: a 60th), and with it
## every clock that moves the picture -- the map's (the worlds, the stars'
## twinkle, the pulsar's beat with its sound stopped), the gas's churn and the
## supernova's -- so a clip and its baseline differ by the event alone.
##   `wev=<name>`   that event, forced ten frames in, once the palette is a
##                  second old; `wev=none` films the baseline; no `wev`, the
##                  system's original weather (today's `wclip`)
##   `wframes=N`    how many frames (for a named event: all of it and a second)
##   `wat=x,y`      where, in from the map window's top left
##   `wfreeze`      the clocks held still, only the event moves
##   `wup=0`        today's version of an upgraded event
##   `wreduce=N`    reduced motion switched on at frame N (the event should be
##                  gone the frame after)
## Writes `f_NNNN.png`, `peak.png` (the frame at the event's height) and
## `meta.json`: for each frame the event's age and where the ship, the labels,
## the worlds and the star are, in the saved picture's pixels.
func _wclip(scr: Control, wdir: String) -> void:
	DirAccess.make_dir_recursive_absolute(wdir)
	var view = scr.view
	var W = view._weather
	if W == null:
		print("  systemshot: no weather here")
		return
	var wn := -1
	var wat := Vector2.INF
	var fps := 30.0
	var ev_name := ""
	var freeze := false
	var reduce_at := -1
	## `wstill=A`: the event held at age A (a still at that moment, 14 frames)
	var still_at := -999.0
	## `wzoom=Z`: the map zooms to Z over the clip, eased (in-system things grow,
	## the far sky stays put)
	var zoom_to := -1.0
	for a19 in OS.get_cmdline_user_args():
		var s19 := a19 as String
		if s19.begins_with("wframes="):
			wn = int(s19.substr(8))
		elif s19.begins_with("wat="):
			var wq := s19.substr(4).split(",")
			wat = view.window.position + Vector2(float(wq[0]), float(wq[1]))
		elif s19.begins_with("wfps="):
			fps = float(s19.substr(5))
		elif s19.begins_with("wev="):
			ev_name = s19.substr(4)
		elif s19 == "wfreeze":
			freeze = true
		elif s19 == "wup=0":
			W.up = false
		elif s19.begins_with("wreduce="):
			reduce_at = int(s19.substr(8))
		elif s19.begins_with("wstill="):
			still_at = float(s19.substr(7))
		elif s19.begins_with("wzoom="):
			zoom_to = float(s19.substr(6))
	if ev_name != "" and ev_name != "none" and not W.hosts(StringName(ev_name)):
		print("  systemshot: " + W.force(StringName(ev_name)))
		return
	# the harness owns every clock now: no events of their own, nothing from
	# the player's own settings, the pulsar's beat off the map clock alone
	DisplaySettings.reduced_motion = false
	W.auto = false
	view._nova.auto = false
	# (the ship was put here as if it had just warped in: no arrival bowshock
	# over the first seconds of every clip)
	W._bow_at = -1.0
	var stp := 1.0 / fps
	W.step_s = stp
	scr.frozen = true
	Audio.room(&"", 0.01)
	# THE SCREEN ON THE HARNESS'S CLOCK TOO: no mouse or keys reach the map (the
	# window is off to the side, where a pointer may pass), the camera held where
	# it is, and the ship flown a fixed step a frame instead of the frame's own
	scr.set_process(false)
	scr.set_process_unhandled_key_input(false)
	scr._frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scr.overlay.hover = {}
	var z0: float = view.zoom
	var pan0: Vector2 = view.pan
	var zst := {"z": z0}
	var hold_cam := func() -> void:
		view.zoom = float(zst.z)
		view.pan = pan0
		scr._zoom_to = float(zst.z)
		scr._step_ship(stp)
	while not view._palette_built:
		await get_tree().process_frame
	# the palette a second old, as the weather waits for it
	for _i in int(fps) + 2:
		await RenderingServer.frame_post_draw
		if not freeze:
			view.t += stp
			view.hclock += stp
		hold_cam.call()
	var origin: Vector2 = scr._box.get_global_transform_with_canvas().origin
	var w: Rect2 = view.window
	var rows: Array = []
	var ev: Dictionary = {}
	var peak_done := false
	var total := wn
	var k := 0
	while true:
		if k == 10:
			if ev_name == "":
				view.weather_now(wat)
			elif ev_name != "none":
				var err: String = W.force(StringName(ev_name), wat)
				if err != "":
					print("  systemshot: " + err)
					break
			for e: Dictionary in W.live():
				if ev_name == "" or String(e.name) == ev_name:
					ev = e
			if still_at > -100.0:
				W.hold_at = still_at
				if total < 0:
					total = 14
			if total < 0:
				total = 10 + (int((float(ev.pre) + float(ev.end) + 1.0) * fps) if not ev.is_empty() else int(fps * 4.0))
			print("  systemshot: wclip %s at %s, pre %.2f, lasts %.2f" % [ev.get("name", ev_name), ev.get("at", "-"), float(ev.get("pre", 0.0)), float(ev.get("end", 0.0))])
		if total < 0 and k > 10 + int(fps * 4.0):
			break
		if total >= 0 and k >= total:
			break
		if k == reduce_at:
			DisplaySettings.reduced_motion = true
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image().get_region(Rect2i(Vector2i(origin + w.position), Vector2i(w.size)))
		img.save_png("%s/f_%04d.png" % [wdir, k])
		var age = float(ev.age) if not ev.is_empty() else null
		if not ev.is_empty() and not peak_done and float(ev.age) >= float(W.PEAK.get(StringName(ev.name), 0.0)):
			img.save_png("%s/peak.png" % wdir)
			peak_done = true
		if k == reduce_at + 1 and reduce_at >= 0:
			var still: int = W.live().size()
			var wk := float(view._neb_mat.get_shader_parameter("w_k")) if view._neb_mat != null else 0.0
			print("  systemshot: reduced motion at frame %d: %d events live the frame after, w_k %.2f" % [reduce_at, still, wk])
		var worlds: Array = []
		for i: int in view._views:
			worlds.append([view.at[i].x - w.position.x, view.at[i].y - w.position.y, view.draw_r(view.layout.bodies[i])])
		var labels: Array = []
		for r: Rect2 in scr.overlay.label_rects:
			labels.append([r.position.x - w.position.x, r.position.y - w.position.y, r.size.x, r.size.y])
		var o: Vector2 = view.origin() - w.position
		var fo: Vector2 = W.focus(ev) - w.position if not ev.is_empty() else Vector2(-1, -1)
		rows.append({"f": k, "age": age, "focus": [fo.x, fo.y], "ship": [scr.overlay._ship_at.x - w.position.x, scr.overlay._ship_at.y - w.position.y],
			"labels": labels, "worlds": worlds, "star": [o.x, o.y, view.layout.star_r * view.star_k()], "zoom": view.zoom})
		if not freeze:
			view.t += stp
			view.hclock += stp
		if zoom_to > 0.0 and k >= 10 and total > 10:
			var zu := smoothstep(0.0, 1.0, float(k - 10) / float(total - 10))
			zst.z = lerpf(z0, zoom_to, zu)
		hold_cam.call()
		k += 1
	var f := FileAccess.open(wdir + "/meta.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"fps": fps, "event": ev_name, "win": [w.position.x, w.position.y], "sky": String(W.sky),
		"temper": String(W.temper), "system": view.node.index, "frames": rows}))
	f.close()
	print("  systemshot: wclip %d frames, sky %s" % [k, W.sky])


## `wrun=S`: THE SCHEDULER AT WORK, as the game runs it -- its own picks, its own
## placement against the real map, the supernova on its own clock too -- for S
## seconds on a fixed step (`wfps=`, default 10 a second, so minutes take
## seconds), the ship parked and no input (no idle pull unless `widle`). Prints
## every start, the rate per tier a minute, how much of the time something is
## live, and any moment two things overlap that should not: a showpiece with a
## supernova or with a small event, or a supernova over a far-sky event.
## `wrunshots=<dir>` saves the window every `wrunevery=` frames (default 10).
func _wrun(scr: Control, secs: float) -> void:
	var view = scr.view
	var W = view._weather
	if W == null:
		print("  systemshot: no weather here")
		return
	var fps := 10.0
	var shots := ""
	var every := 10
	for a21 in OS.get_cmdline_user_args():
		var s21 := a21 as String
		if s21.begins_with("wfps="):
			fps = float(s21.substr(5))
		elif s21.begins_with("wrunshots="):
			shots = s21.substr(10)
		elif s21.begins_with("wrunevery="):
			every = int(s21.substr(10))
	var idle := "widle" in OS.get_cmdline_user_args()
	if shots != "":
		DirAccess.make_dir_recursive_absolute(shots)
	DisplaySettings.reduced_motion = false
	W.log_on = true
	W.log_starts = []
	var stp := 1.0 / fps
	W.step_s = stp
	Audio.room(&"", 0.01)
	scr.set_process(false)
	scr.set_process_unhandled_key_input(false)
	scr._frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scr.overlay.hover = {}
	var z0: float = view.zoom
	var pan0: Vector2 = view.pan
	while not view._palette_built:
		await get_tree().process_frame
	var origin: Vector2 = scr._box.get_global_transform_with_canvas().origin
	var w: Rect2 = view.window
	var n := int(secs * fps)
	var novas: Array = []
	var was_nova := false
	var busy := 0
	var bad: Array = []
	var t := 0.0
	for k in n:
		await RenderingServer.frame_post_draw
		if shots != "" and k % every == 0:
			var img := get_viewport().get_texture().get_image().get_region(Rect2i(Vector2i(origin + w.position), Vector2i(w.size)))
			img.save_png("%s/r_%05d.png" % [shots, k / every])
		view.t += stp
		view.hclock += stp
		t += stp
		view.zoom = z0
		view.pan = pan0
		scr._zoom_to = z0
		scr._step_ship(stp)
		if not idle:
			scr.last_input_t = Time.get_ticks_msec() / 1000.0
		var nv: bool = not (view._nova._ev as Dictionary).is_empty()
		if nv and not was_nova:
			novas.append(snappedf(t, 0.1))
		was_nova = nv
		var a: Dictionary = W._a
		var b: Dictionary = W._b
		if not a.is_empty() or not b.is_empty():
			busy += 1
		var a_sp: bool = not a.is_empty() and int(a.tier) == W.SP
		if a_sp and nv:
			bad.append("%.1f showpiece %s under a supernova" % [t, a.name])
		if a_sp and not b.is_empty():
			bad.append("%.1f small %s under showpiece %s" % [t, b.name, a.name])
		if nv and W.far_busy() and float(a.age) > 0.0 and k > 0:
			bad.append("%.1f supernova over far-sky %s" % [t, a.name])
	var per := {0: 0, 1: 0, 2: 0, 3: 0}
	for e: Array in W.log_starts:
		per[int(e[3])] += 1
		print("  systemshot: wrun %6.1f s  %-12s slot %s %-2s lasts %.1f" % [float(e[0]), e[1], "B" if int(e[2]) == 1 else ("A" if int(e[2]) == 0 else "-"), W.TIER_NAMES[int(e[3])], float(e[4])])
	var mins := t / 60.0
	print("  systemshot: wrun sky %s temperament %s favourite %s: %.1f min, M %.2f/min, S %.2f/min, SP %d, R %d, supernovas %d %s; something live %.0f%% of the time" % [
		W.sky, W.temper, W.fav, mins, per[1] / mins, per[0] / mins, per[2], per[3], novas.size(), novas, 100.0 * busy / maxf(1.0, float(n))])
	# (deduplicated: one line a second at most)
	var last := ""
	var shown := 0
	for s22: String in bad:
		var key := s22.substr(s22.find(" "))
		if key != last and shown < 20:
			print("  systemshot: wrun OVERLAP " + s22)
			shown += 1
		last = key
	print("  systemshot: wrun overlaps %d frames" % bad.size())


## The weather's ported points, marked over the map (`wprobe`).
class _Probe extends Node2D:
	var pts: Array = []

	func _draw() -> void:
		for e: Array in pts:
			var p: Vector2 = e[1]
			var c := Color(1, 1, 0) if String(e[0]) in ["cc", "rim"] else Color(0, 1, 0.4)
			draw_line(p - Vector2(4, 0), p + Vector2(4, 0), c)
			draw_line(p - Vector2(0, 4), p + Vector2(0, 4), c)
