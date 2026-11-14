extends Node

## The cutaway photographed through the real screen; needs a window.
## Its clock steps 1/30 s a frame, so the push-in shows its true 0.4 s however slowly it drew.
## Why: docs/why/CutawayShot.md#shot-purpose

## The thirteen Solari parts `proc` fits. They had no picture when it was
## written; every one has a picture now, so `proc` shows them as drawn.
const PROC: Array[StringName] = [&"heliostat", &"plasma", &"sunheart", &"crucible", &"starfurnace",
	&"heathaze", &"mirrorarray", &"radiatorsail", &"annealer", &"flare", &"heliograph",
	&"incinerator", &"bleedvalve"]

var _args: PackedStringArray
var _dir := ""
var _every := 1
var _rec := false
var _k := 0
var _tick := 0


func _ready() -> void:
	_args = OS.get_cmdline_user_args()
	_run.call_deferred()


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
	_dir = Harness.arg("clip")
	if _dir != "":
		DirAccess.make_dir_recursive_absolute(_dir)
	_every = int(Harness.arg("every", "1"))
	CutawayView.fixed_step = 1.0 / 30.0
	# (and every hull's bob on the same clock, or a slow window films it fast)
	ShipView.shot_clock = 0.0
	if "bobcheck" in _args:
		CutawayView.fixed_step = 0.0
		ShipView.shot_clock = -1.0
	Rng.forced = Harness.seed_arg(4242)
	var wt: int = {"light": HullData.Weight.LIGHT, "medium": HullData.Weight.MEDIUM, "heavy": HullData.Weight.HEAVY}.get(Harness.arg("weight", "medium"), HullData.Weight.MEDIUM)
	# `manufacturer` and `grade` pick a chassis with its starter kit; `fit=full` fills every mount.
	var mk := StringName(Harness.arg("manufacturer", "korvan"))
	Run.start_new_run(mk, int(wt))
	if Harness.arg("grade", "") != "":
		Run.fit_chassis(mk, wt as HullData.Weight, int(Harness.arg("grade", "0")))
	if Harness.arg("fit", "") == "full":
		_fit_full()
	# `carry=<slot>` wants an empty mount of that slot to show: a hull that
	# launches with all of them fitted has one part of it taken off, to the hold
	var cs := {"weapon": ModuleData.Slot.WEAPON, "system": ModuleData.Slot.SYSTEM, "utility": ModuleData.Slot.UTILITY}.get(Harness.arg("carry"), -1) as int
	if cs >= 0:
		var css := cs as ModuleData.Slot
		if Run.slots_for(css) > 0 and Run.slots_used(css) >= Run.slots_for(css):
			Run.uninstall_module(Run.module_at(css, 0))
	# `proc`: Solari's thirteen parts, fitted where free and the rest in the hold and wreck.
	var proc_left: Array[ModuleData] = []
	# `takemap` wears candidate pictures over procedural drawing, to judge takes before install.
	if Harness.arg("takemap") != "":
		var tm: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Harness.arg("takemap")))
		var k := int(Harness.arg("takeslot", "0"))
		for tid: String in tm:
			var paths: Array = tm[tid]
			if k < paths.size() and DB.modules.has(StringName(tid)):
				var img := Image.load_from_file(String(paths[k]))
				if img != null:
					(DB.modules[StringName(tid)] as ModuleData).sprite = ImageTexture.create_from_image(img)
					print("cutawayshot: %s wears %s" % [tid, String(paths[k]).get_file()])
	var proc_ids: Array = PROC
	if Harness.arg("procset") != "":
		proc_ids = Array(Harness.arg("procset").split(",")).map(func(x: String) -> StringName: return StringName(x))
	if "proc" in _args:
		Run.installed.clear()
		for pid: StringName in proc_ids:
			var pm := (DB.modules[pid] as ModuleData).duplicate(true) as ModuleData
			if Run.slots_used(pm.slot) < Run.slots_for(pm.slot):
				Run.install_module(pm)
			else:
				proc_left.append(pm)
		Sig.ship_changed.emit()
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
	var wreck := Run.new_wreck(n, DB.enemies[&"cutter"])
	if "proc" in _args:
		for i in proc_left.size():
			if i < 3:
				Run.stow(proc_left[i])
			else:
				wreck.items.append(proc_left[i])
		# `takeshot`: the fitted parts again, in the hold where they fit and in
		# the wreck after that, for the transfer screen
		if "takeshot" in _args:
			for im: ModuleData in Run.installed:
				var cp := im.duplicate(true) as ModuleData
				if not Run.stow(cp):
					wreck.items.append(cp)
	else:
		for i in 3:
			Run.stow(LootGen.roll_module(3, mk))
		wreck.items.append(LootGen.roll_module(4, mk))
	wreck.items.append(MaterialData.of(MaterialTable.all()[2]))
	if Harness.arg("loot", "yes") != "no":
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
	if "swaps" in _args:
		_swap_ship()
	Router.show_local()
	await _frames(60)
	var sc := Router.current as SectorScreen
	if sc == null:
		print("cutawayshot: not on LOCAL")
		tree.quit()
		return
	# 1. pointing at your own ship
	_rec = true
	if "transfer" in _args:
		_still("00_local")
		sc._open_jetsam(wreck, "Rustjaw Cutter", true)
		await _frames(60)
		_still("16_transfer")
		tree.quit()
		return
	if "yard" in _args:
		await _yard()
		tree.quit()
		return
	if "bobcheck" in _args:
		await _bobcheck(sc)
		tree.quit()
		return
	_still("00_local")
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
	# `takeshot`: the cutaway, then the wreck's transfer screen, and stop
	if "takeshot" in _args:
		cut.close_now()
		await _frames(30)
		sc._open_jetsam(wreck, "Rustjaw Cutter", true)
		await _frames(60)
		_still("16_transfer")
		tree.quit()
		return
	print("cutawayshot: push-in %dx, left panel %dx%d, hull %s" % [cut.k, cut._hold_w, cut.size.y, Run.hull.display_name()])
	if "swaps" in _args:
		await _swaps(cut)
		tree.quit()
		return
	_report_fit(cut)
	print("cutawayshot: %s" % cut.fit_note)
	# THE ZOOMED SKY, held, for `frames.py` (`skyclip=<dir>`): the cutaway open,
	# its ship, parts and panel hidden for 90 frames, saved at the game's 1x
	var sky_dir := Harness.arg("skyclip")
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
				var r := cut._mounts.part_rect(pm, sp.slot, cut._mounts.part_drawn_at(sp), cut._mounts.part_mag())
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
	# A carried part rings and pulses its empty mounts; at rest an empty mount is not drawn.
	var carried: ModuleData = in_hold
	var shown: ModuleData = carried
	var want := {"weapon": ModuleData.Slot.WEAPON, "system": ModuleData.Slot.SYSTEM, "utility": ModuleData.Slot.UTILITY}.get(Harness.arg("carry"), -1) as int
	for slot in [ModuleData.Slot.WEAPON, ModuleData.Slot.SYSTEM, ModuleData.Slot.UTILITY]:
		if want >= 0 and slot != want:
			continue
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
		if want >= 0:
			# where each empty mount's words landed, in the game's px, for crops
			for d in cut._mounts.drawn_rects():
				if d.kind == "label":
					var g: Rect2 = cut._mounts.get_global_transform() * (d.rect as Rect2)
					print("cutawayshot: label %s at %d,%d %dx%d" % [d.text, g.position.x, g.position.y, g.size.x, g.size.y])
			for sp in cut._mounts.spots():
				if sp.held == null and (sp.slot as ModuleData.Slot) == shown.slot:
					var a: Vector2 = cut._mounts.get_global_transform() * (sp.at as Vector2)
					print("cutawayshot: ring %s at %d,%d" % [MountPoints.empty_text(int(sp.slot)), a.x, a.y])
			tree.quit()
			return
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
	# A click on the wreck is a click on the sky and shuts the cutaway (Jon); reopened after.
	# Why: docs/why/CutawayShot.md#wreck-click
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
		_still("14a_fight")
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


## The bob's period, live: LOCAL's hull then the cutaway's, each sampled every frame.
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


## The shipyard: docked, ship on its stands, outline, push-in, then shut.
func _yard() -> void:
	var here: MapGen.MapNode = Run.node_at()
	here.type = MapGen.NodeType.STATION
	here.development = MapGen.Development.CITY
	here.security = 4
	Router.park_at_station(here)
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
			var r := cut._mounts.part_rect(sp.held, sp.slot, cut._mounts.part_drawn_at(sp), cut._mounts.part_mag())
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


## Holds the yard clock and hides panel, parts and blur, saving each push-in frame's transform.
## Laid over the first frame, anything not mapping to itself sits where the zoom does not reach.
## Why: docs/why/CutawayShot.md#zoom-study
func _yard_study(st: StationScreen) -> void:
	if _dir == "":
		print("cutawayshot: yardstudy needs clip=<dir>")
		return
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
		var r := mp.part_rect(m, s.slot, mp.part_drawn_at(s), mp.part_mag())
		var bottom := (g * r.end).y
		worst = maxf(worst, bottom)
		n += 1
	print("cutawayshot: %d parts lifted; lowest edge %.0f against the bottom bar at %.0f: %s" % [n, worst, top_y.y,
		"clear" if worst <= top_y.y else "OVERLAPS"])


## Every mount filled with the hull's own manufacturer's parts, as MouthSize does.
func _fit_full() -> void:
	var own: Array[ModuleData] = []
	for mid in DB.modules:
		var m: ModuleData = DB.modules[mid]
		if m.manufacturer == Run.hull.manufacturer:
			own.append(m)
	own.sort_custom(func(x: ModuleData, y: ModuleData) -> bool:
		if x.reactor != y.reactor:
			return x.reactor > y.reactor
		return x.cells() < y.cells())
	for p in 2:
		for m: ModuleData in own:
			if p == 0 and Run.installed.any(func(on: ModuleData) -> bool: return on.id == m.id):
				continue
			if Run.slots_used(m.slot) < Run.slots_for(m.slot) and Run.can_power(m):
				Run.install_module(m.duplicate(true) as ModuleData)
	print("cutawayshot: fit=full, %d parts on %s" % [Run.installed.size(), Run.hull.display_name()])


## `swaps` fits the ship for swap marks: a carried part trades only with a smaller-or-equal one.
func _swap_ship() -> void:
	Run.cargo.clear()
	for slot in [ModuleData.Slot.WEAPON, ModuleData.Slot.SYSTEM, ModuleData.Slot.UTILITY]:
		var sizes := _swap_sizes(slot)
		var n := Run.slots_for(slot)
		for i in n:
			var was := Run.module_at(slot, i)
			if was != null:
				Run.installed.erase(was)
				was.mount = -1
			if n >= 2 and i == n - 1:
				continue
			var p := _swap_part(slot, sizes[i % sizes.size()])
			p.mount = i
			Run.installed.append(p)
		Run.place_in_hold(_swap_part(slot, sizes[0]))
	_pack_hold()
	Sig.ship_changed.emit()


func _pack_hold() -> void:
	for row in MaterialTable.all():
		if MaterialData.of(row).size == Vector2i.ONE:
			for i in 200:
				if not Run.place_in_hold(MaterialData.of(row)):
					break
			return


func _swap_sizes(s: ModuleData.Slot) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for id in DB.modules:
		var m: ModuleData = DB.modules[id]
		if m.slot == s and not m.starter_only and not out.has(m.size):
			out.append(m.size)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x * a.y < b.x * b.y or (a.x * a.y == b.x * b.y and a.x < b.x))
	return out


func _swap_part(s: ModuleData.Slot, size: Vector2i) -> ModuleData:
	for id in DB.modules:
		var m: ModuleData = DB.modules[id]
		if m.slot == s and not m.starter_only and m.size == size:
			return m.duplicate(true) as ModuleData
	return null


## Marks come from a real drag out of the hold, in both looks, then a weapon that can go nowhere.
## Why: docs/why/CutawayShot.md#swap-marks
func _swaps(cut: CutawayView) -> void:
	var shell := GameShell.instance
	var kk := float(shell._frame.stretch_shrink) if shell != null and shell._frame != null else 1.0
	var home: Vector2 = shell._home if shell != null else Vector2.ZERO
	var pic: Rect2 = cut.get_global_transform() * cut._pic
	print("cutawayshot: picture at %d,%d %dx%d in the window (x%d, home %d,%d)" % [
		home.x + pic.position.x * kk, home.y + pic.position.y * kk, pic.size.x * kk, pic.size.y * kk, kk, home.x, home.y])
	var cases := [["weapon", ModuleData.Slot.WEAPON], ["system", ModuleData.Slot.SYSTEM], ["utility", ModuleData.Slot.UTILITY]]
	for look in [0, 1]:
		MountPoints.swap_look = look
		for c in cases:
			await _swap_still(cut, c[1], "swap_%s_%s" % [c[0], ["frame", "corners"][look]])
	# NOTHING TO TRADE WITH: every weapon mount, the empty one too, holds the
	# biggest weapon there is; the smallest carried from the packed hold
	var sizes := _swap_sizes(ModuleData.Slot.WEAPON)
	for i in Run.slots_for(ModuleData.Slot.WEAPON):
		var was := Run.module_at(ModuleData.Slot.WEAPON, i)
		if was != null:
			Run.installed.erase(was)
			was.mount = -1
		var p := _swap_part(ModuleData.Slot.WEAPON, sizes[sizes.size() - 1])
		p.mount = i
		Run.installed.append(p)
	Sig.ship_changed.emit()
	await _frames(10)
	pic = cut.get_global_transform() * cut._pic
	print("cutawayshot: picture at %d,%d %dx%d in the window (nothing case)" % [
		home.x + pic.position.x * kk, home.y + pic.position.y * kk, pic.size.x * kk, pic.size.y * kk])
	for look in [0, 1]:
		MountPoints.swap_look = look
		await _swap_still(cut, ModuleData.Slot.WEAPON, "swap_nothing_%s" % ["frame", "corners"][look])
	MountPoints.swap_look = 0


func _swap_still(cut: CutawayView, slot: ModuleData.Slot, name: String) -> void:
	var mp := cut._mounts
	var m: ModuleData = null
	var icon: Control = null
	for ic in cut._hold.get_children():
		if ic is ItemIcon and (ic as ItemIcon).held_item() is ModuleData and ((ic as ItemIcon).held_item() as ModuleData).slot == slot:
			icon = ic
			m = (ic as ItemIcon).held_item()
			break
	if m == null:
		print("cutawayshot: no %s in the hold" % name)
		return
	icon.visible = false
	cut._hold.force_drag({module = m, origin = &"cargo"}, null)
	await _frames(24)
	_still(name)
	print("cutawayshot: %s carried %s (%dx%d): marked %s, %d framed, %d pinged" % [name, m.name, m.size.x, m.size.y,
		",".join(mp.marked), mp.swapped, mp.pinged])
	cut.get_viewport().gui_cancel_drag()
	await _frames(6)
	print("cutawayshot: %s after the cancel: %d marked" % [name, mp.marked.size()])
