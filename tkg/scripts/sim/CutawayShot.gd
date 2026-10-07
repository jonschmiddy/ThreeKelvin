extends Node

## THE CUTAWAY, photographed through the real screen (`CutawayView` on
## `SectorScreen`):
##   godot --path . --windowed --position 3840,0 -- sheet=CutawayShot keepwindow
##       clip=<dir> [weight=light|medium|heavy] [loot=no] [style=...] [seed=N]
##       [every=1] [nopause] [nofight] [yard] [bobcheck] [skyclip=<dir>] [orbit]
## A run at a system with a wreck you killed, parts in the hold and (unless
## `loot=no`) something loose in the system. Saves the game's picture every
## `every` frames through: the hover outline on your ship, the push-in (backdrop
## breaking up, the left panel sliding in), a fitted part and a module in the
## hold pointed at (the MODULES page's popup beside each), a part carried (its
## rings pulsing), the drop onto a mount, a click on the wreck behind (it shuts
## the cutaway and opens nothing), SECTOR LOOT on the bottom bar (this system's
## pile in the popup) and a module in it pointed at, the close; then the real
## escape menu over the same scene (for the backdrop beside it), then a fight
## with a card pointed at (its part lit on the hull). `yard` instead docks at a
## station and does it in the Shipyard: your ship on its stands, the outline,
## the push-in onto ship and stands, a part and a hold module pointed at, the
## close back to the yard. Prints the push-in scale and what 2x needs against
## the room. Needs a window.
## THE CUTAWAY'S CLOCK IS STEPPED 1/30 s A FRAME (`CutawayView.fixed_step`), so
## the frames, encoded at 30 a second (every=1), show the real 0.4 s push-in
## however slowly the window drew them; nothing is saved before the hover.

var _args: PackedStringArray
var _dir := ""
var _every := 1
var _rec := false
var _k := 0
var _tick := 0


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
		if ShipView.shot_clock >= 0.0:
			ShipView.shot_clock += CutawayView.fixed_step
		_tick += 1
		if _rec and _dir != "" and _tick % _every == 0:
			get_tree().root.get_texture().get_image().save_png("%s/f_%04d.png" % [_dir, _k])
			_k += 1


func _still(name: String) -> void:
	if _dir != "":
		get_tree().root.get_texture().get_image().save_png("%s/%s.png" % [_dir, name])
	print("cutawayshot: %s" % name)


func _run() -> void:
	var tree := get_tree()
	await tree.process_frame
	Router.animate_in_harness = true
	_dir = _arg("clip")
	if _dir != "":
		DirAccess.make_dir_recursive_absolute(_dir)
	_every = int(_arg("every", "1"))
	CutawayView.fixed_step = 1.0 / 30.0
	# (and every hull's bob on the same clock, or a slow window films it fast)
	ShipView.shot_clock = 0.0
	if "bobcheck" in _args:
		CutawayView.fixed_step = 0.0
		ShipView.shot_clock = -1.0
	Rng.forced = int(_arg("seed", "4242"))
	var wt: int = {"light": HullData.Weight.LIGHT, "medium": HullData.Weight.MEDIUM, "heavy": HullData.Weight.HEAVY}.get(_arg("weight", "medium"), HullData.Weight.MEDIUM)
	Run.start_new_run(&"korvan", int(wt))
	var idx := -1
	for n: MapGen.MapNode in Run.map:
		if n.type == MapGen.NodeType.SYSTEM and not n.cleared:
			idx = n.index
			break
	Run.at = idx
	Run.map[idx].visited = true
	SectorScreen._approached_at = idx
	var n: MapGen.MapNode = Run.node_at()
	# what a used ship carries: parts in the hold, a wreck you killed, loot
	for i in 3:
		Run.stow(LootGen.roll_module(3, &"korvan"))
	var wreck := Run.new_wreck(n, DB.enemies[&"cutter"])
	wreck.items.append(LootGen.roll_module(4, &"korvan"))
	wreck.items.append(MaterialData.of(MaterialTable.all()[2]))
	if _arg("loot", "yes") != "no":
		var pile := Run.sector_jetsam(n, true)
		pile.items.append(LootGen.roll_module(3))
		pile.items.append(MaterialData.of(MaterialTable.all()[5]))
	# `orbit`: parked in orbit of the system's first world, as the sector map
	# leaves you, so LOCAL draws it near (the layer that zooms with the ship)
	if "orbit" in _args:
		var Lo := SystemLayout.of(n)
		for bi in Lo.bodies.size():
			if (Lo.bodies[bi] as SystemLayout.Body).world != &"":
				SystemMapScreen._parked[idx] = {"at": bi, "p": Vector2(Lo.edge * 1.02, -210.0), "v": Vector2.ZERO, "head": 0.0, "mode": &"rail"}
				print("cutawayshot: in orbit of body %d" % bi)
				break
	Router.show_local()
	await _frames(60)
	var sc := Router.current as SectorScreen
	if sc == null:
		print("cutawayshot: not on LOCAL")
		tree.quit()
		return
	# 1. pointing at your own ship
	_rec = true
	if "yard" in _args:
		await _yard()
		tree.quit()
		return
	if "bobcheck" in _args:
		await _bobcheck(sc)
		tree.quit()
		return
	sc._ship_outline.visible = true
	sc._ship_outline.queue_redraw()
	await _frames(8)
	_still("01_hover_outline")
	print("cutawayshot: before, the row at %s, scale %s" % [sc._view._row.get_global_rect(), sc._view._row.scale])
	sc._ship_outline.visible = false
	# 2. the push-in
	var cut := sc.open_cutaway()
	if cut == null:
		print("cutawayshot: the cutaway would not open")
		tree.quit()
		return
	await _frames(40)
	_still("02_open")
	print("cutawayshot: push-in %dx, left panel %dx%d, hull %s" % [cut.k, cut._hold_w, cut.size.y, Run.hull.display_name()])
	_report_fit(cut)
	print("cutawayshot: %s" % cut.fit_note)
	# THE ZOOMED SKY, held, for `frames.py` (`skyclip=<dir>`): the cutaway open,
	# its ship, parts and panel hidden for 90 frames, saved at the game's 1x
	var sky_dir := _arg("skyclip")
	if sky_dir != "":
		DirAccess.make_dir_recursive_absolute(sky_dir)
		var art := sc._view.ship_view()
		cut._stage.visible = false
		cut._hold_panel.visible = false
		art.visible = false
		for i in 90:
			await RenderingServer.frame_post_draw
			if ShipView.shot_clock >= 0.0:
				ShipView.shot_clock += CutawayView.fixed_step
			var im := get_tree().root.get_texture().get_image()
			im.resize(im.get_width() / 2, im.get_height() / 2, Image.INTERPOLATE_NEAREST)
			im.save_png("%s/f_%04d.png" % [sky_dir, i])
		cut._stage.visible = true
		cut._hold_panel.visible = true
		art.visible = true
		print("cutawayshot: the zoomed sky held for 90 frames in %s" % sky_dir)
	# 3. a fitted part pointed at: its card beside it
	if not Run.installed.is_empty():
		var pm: ModuleData = Run.installed[0]
		for sp in cut._mounts.spots():
			if sp.held == pm:
				var r := cut._mounts.part_rect(pm, sp.slot, cut._mounts._part_at(sp), cut._mounts._mag())
				cut._point(cut._mounts.get_global_transform() * r.get_center())
		cut._mounts.focus(pm)
	await _frames(12)
	_still("03_hover_hull")
	cut._mounts.focus(null)
	cut._show(null)
	# 4. a module in the hold pointed at: the same card
	var in_hold: ModuleData = null
	for c in cut._hold.get_children():
		if c is ModuleIcon and (c as ModuleIcon).held_item() is ModuleData:
			in_hold = (c as ModuleIcon).held_item()
			cut._point((c as Control).get_global_rect().get_center())
			break
	await _frames(12)
	_still("04_hover_hold")
	cut._show(null)
	# 5. a part carried: the empty mounts of its kind ring and pulse (and only
	# then: at rest an empty mount is not drawn), no card. A part of a slot with
	# an empty mount, so there is a ring to see
	var carried: ModuleData = in_hold
	var shown: ModuleData = carried
	for slot in [ModuleData.Slot.WEAPON, ModuleData.Slot.SYSTEM, ModuleData.Slot.UTILITY]:
		if Run.slots_used(slot) < Run.slots_for(slot):
			for mid in DB.modules:
				if (DB.modules[mid] as ModuleData).slot == slot:
					shown = DB.modules[mid]
					break
			break
	if shown != null:
		cut._mounts.light(shown)
		await _frames(24)
		_still("05_carrying")
		cut._mounts.light(null)
	if carried != null:
		# 6. dropped onto a mount of its kind: an empty one if there is one
		var at := 0
		for i in Run.slots_for(carried.slot):
			if Run.module_at(carried.slot, i) == null:
				at = i
				break
		await cut._on_mount_drop({module = carried, origin = &"cargo"}, carried.slot, at)
		await _frames(20)
		_still("06_fitted")
	# 7. THE WRECK is not opened from in here: a click on it is a click on the sky
	# (Jon: "You shouldn't be able to open a wreck when your ship is clicked on
	# and in focus"), so it shuts the cutaway; reopened for the rest
	var made: Array = sc._view._made
	if not made.is_empty() and (made[0] as EnemySlot).art != null:
		cut._sky_click((made[0] as EnemySlot).art.get_global_rect().get_center())
		await _frames(30)
		_still("07_wreck_click_closes")
		print("cutawayshot: after, the row at %s, scale %s, cut valid %s" % [sc._view._row.get_global_rect(), sc._view._row.scale, is_instance_valid(cut)])
		print("cutawayshot: a click on the wreck %s, and opened %s" % ["shut the cutaway" if not is_instance_valid(cut) or not cut.is_open() else "LEFT IT OPEN",
			"its two-grid screen" if sc._transfer != null else "nothing"])
		cut = sc.open_cutaway()
		await _frames(30)
	# 10. SECTOR LOOT on the bottom bar: this system's pile in the same popup
	sc._open_loose()
	await _frames(20)
	_still("10_loot_popup")
	print("cutawayshot: the sector loot popup %s" % ("opened" if cut.popup_open() else "did not open (nothing loose here)"))
	if cut.popup_open():
		for c in cut._pop_grid.get_children():
			if c is ItemIcon and (c as ItemIcon).held_item() is ModuleData:
				cut._point((c as Control).get_global_rect().get_center())
				break
		await _frames(12)
		_still("11_hover_loot")
		cut._show(null)
		cut.close_popup()
	# 12. the close
	cut.close()
	await _frames(40)
	_still("12_closed")
	# 8. THE ESCAPE MENU over the same scene, for its backdrop beside the cutaway's
	if not "nopause" in _args:
		var main := get_parent()
		if main != null and main.has_method("toggle_menu"):
			main.toggle_menu()
			await _frames(40)
			_still("13_pause_menu")
			main.toggle_menu()
			await _frames(20)
	# 9. a fight: a card pointed at lights its part on the hull
	if not "nofight" in _args:
		Run.hand_size_override = 5
		Router.start_combat(DB.enemies[&"cutter"], [], false, false)
		await _frames(90)
		var fs := Router.current as SectorScreen
		if fs != null and fs._hand != null:
			var views: Array = []
			for c in fs._hand.find_children("*", "CardView", true, false):
				views.append(c)
			for v in views:
				var cv := v as CardView
				if cv.card != null and cv.card.source_id != &"":
					fs._on_card_hovered(cv, true)
					await _frames(16)
					_still("14_fight_card_lights_part")
					print("cutawayshot: pointed at %s (from %s)" % [cv.card.name, cv.card.source_id])
					break
	tree.quit()


## THE BOB'S PERIOD, LIVE (`bobcheck`, real clock): LOCAL's own hull for some
## seconds, then the cutaway's, each sampled every frame -- the seconds between
## upward crossings of rest, how many steps a second, and the pixels a step
## moves on screen.
func _bobcheck(sc: SectorScreen) -> void:
	var src := sc._view.ship_view()
	var a := await _bob_period(src, 8.0)
	var cut := sc.open_cutaway()
	await _frames(30)
	var b := await _bob_period(cut._ship, 8.0)
	print("cutawayshot: bob on LOCAL: period %.2f s, %.1f steps/s, %d px a step (amp %d art px, %.2f Hz)" % [a[0], a[1], int(src.art_scale()), src._bob_amp, src._bob_hz])
	print("cutawayshot: bob in the cutaway: period %.2f s, %.1f steps/s, %d px a step (amp %d art px, %.2f Hz)" % [b[0], b[1], int(cut._ship.art_scale()), cut._ship._bob_amp, cut._ship._bob_hz])


func _bob_period(v: ShipView, secs: float) -> Array:
	var t0 := Time.get_ticks_msec()
	var last := v.bob_offset()
	var ups: Array[float] = []
	var steps := 0
	while Time.get_ticks_msec() - t0 < int(secs * 1000.0):
		await get_tree().process_frame
		var o := v.bob_offset()
		if o != last:
			steps += 1
			if last <= 0 and o > 0:
				ups.append(float(Time.get_ticks_msec() - t0) / 1000.0)
			last = o
	var per := 0.0
	if ups.size() >= 2:
		per = (ups[ups.size() - 1] - ups[0]) / float(ups.size() - 1)
	return [per, float(steps) / secs]


## THE SHIPYARD (`yard`): docked at a station, your ship on its stands in the
## yard, pointed at (the outline), clicked open (the push-in onto it and its
## stands), a fitted part and a hold module pointed at, then shut.
func _yard() -> void:
	var here: MapGen.MapNode = Run.node_at()
	here.type = MapGen.NodeType.STATION
	here.development = MapGen.Development.CITY
	here.security = 4
	Router.show_station()
	await _frames(90)
	var st := Router.current as StationScreen
	if st == null or st._mine_view == null:
		print("cutawayshot: the yard did not draw your ship")
		return
	if "yardstudy" in _args:
		await _yard_study(st)
		return
	st._mine_outline.visible = true
	st._mine_outline.queue_redraw()
	await _frames(8)
	_still("yard_01_hover_outline")
	st._mine_outline.visible = false
	var cut := st.open_cutaway()
	if cut == null:
		print("cutawayshot: the yard's cutaway would not open")
		return
	await _frames(40)
	_still("yard_02_open")
	print("cutawayshot: yard push-in %dx, the yard zoomed %.1fx, %d stands kept clear, the ship %s; %s" % [cut.k,
		cut.scenes[0].scale.x if not cut.scenes.is_empty() else 0.0, cut.stands.size(),
		"bobbing" if cut._ship._bob_amp > 0 else "still", cut.fit_note])
	for sp in cut._mounts.spots():
		if sp.held != null:
			var r := cut._mounts.part_rect(sp.held, sp.slot, cut._mounts._part_at(sp), cut._mounts._mag())
			cut._point(cut._mounts.get_global_transform() * r.get_center())
			break
	await _frames(12)
	_still("yard_03_hover_hull")
	cut._show(null)
	for c in cut._hold.get_children():
		if c is ModuleIcon:
			cut._point((c as Control).get_global_rect().get_center())
			break
	await _frames(12)
	_still("yard_04_hover_hold")
	cut._show(null)
	cut.close()
	await _frames(40)
	_still("yard_05_closed")
	print("cutawayshot: back in the yard: %s" % (Router.current is StationScreen and st._cutaway == null))


## THE ZOOM, STUDIED (`yard yardstudy clip=<dir>`): the yard's clock held, the
## blur off, the cutaway's own hull, parts and panel hidden, and every frame of
## the push-in saved with the yard's transform on screen (`zoom.json`: scale and
## the screen point of the yard's origin, per frame). Laid back over the first,
## unzoomed frame, everything in the yard should map to itself; whatever does
## not is drawn somewhere the zoom does not reach.
func _yard_study(st: StationScreen) -> void:
	st._scene.step_to(6.0)
	CutawayView.harness_no_blur = true
	# the game's own picture (before Main's screen effect bends it), and the
	# yard's transform in it
	var vp := st.get_viewport()
	var rows: Array = []
	var shoot := func(i: int, t: float) -> void:
		var g := (st._scene as Control).get_global_transform_with_canvas()
		vp.get_texture().get_image().save_png("%s/z_%04d.png" % [_dir, i])
		rows.append({"i": i, "scale": g.get_scale().x, "origin": [g.origin.x, g.origin.y], "t": t})
	st._mine_view.visible = false
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	shoot.call(0, 0.0)
	st._mine_view.visible = true
	var cut := st.open_cutaway()
	await get_tree().process_frame
	cut._stage.visible = false
	cut._hold_panel.visible = false
	for i in range(1, 24):
		await RenderingServer.frame_post_draw
		shoot.call(i, cut.t)
	var f := FileAccess.open("%s/zoom.json" % _dir, FileAccess.WRITE)
	f.store_string(JSON.stringify(rows))
	f.close()
	CutawayView.harness_no_blur = false
	print("cutawayshot: yard study, %d frames" % rows.size())


## Whether anything lifted reaches past the cutaway's foot (LOCAL's bottom bar).
func _report_fit(cut: CutawayView) -> void:
	var mp := cut._mounts
	var g := mp.get_global_transform()
	var top_y := cut.get_global_transform() * Vector2(0, cut.size.y)
	var worst := -INF
	var n := 0
	for s in mp.spots():
		var m: ModuleData = s.held
		if m == null:
			continue
		var r := mp.part_rect(m, s.slot, mp._part_at(s), mp._mag())
		var bottom := (g * r.end).y
		worst = maxf(worst, bottom)
		n += 1
	print("cutawayshot: %d parts lifted; lowest edge %.0f against the bottom bar at %.0f: %s" % [n, worst, top_y.y,
		"clear" if worst <= top_y.y else "OVERLAPS"])
