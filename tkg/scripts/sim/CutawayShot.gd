extends Node

## THE CUTAWAY, photographed through the real screen (`CutawayView` on
## `SectorScreen`):
##   godot --path . --windowed --position 3840,0 -- sheet=CutawayShot keepwindow
##       clip=<dir> [weight=light|medium|heavy] [loot=no] [style=...] [seed=N]
##       [every=1] [nopause] [nofight]
## A run at a system with a wreck you killed, parts in the hold and (unless
## `loot=no`) something loose in the system. Saves the game's picture every
## `every` frames through: the hover outline on your ship, the push-in (backdrop
## breaking up, the left panel sliding in), a fitted part pointed at and a
## module in the hold pointed at (the card beside each), a part carried (its
## rings pulsing), the drop onto a mount, the wreck clicked where LOCAL draws it
## (its bay in a popup), a module in it pointed at, TAKE ALL, SECTOR LOOT on the
## bottom bar (this system's pile in the popup) and a module in it pointed at,
## the close; then the real escape menu over the same scene (for the backdrop
## beside it), then a fight with a card pointed at (its part lit on the hull).
## Prints the push-in scale, the left panel's size, and whether any lifted part
## or tag reaches past the cutaway's foot. Needs a window.
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
	Router.show_local()
	await _frames(60)
	var sc := Router.current as SectorScreen
	if sc == null:
		print("cutawayshot: not on LOCAL")
		tree.quit()
		return
	# 1. pointing at your own ship
	_rec = true
	sc._ship_outline.visible = true
	sc._ship_outline.queue_redraw()
	await _frames(8)
	_still("01_hover_outline")
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
	# 5. a part from the hold carried: its rings pulse, no card
	var carried: ModuleData = in_hold
	if carried != null:
		cut._mounts.light(carried)
		await _frames(24)
		_still("05_carrying")
		cut._mounts.light(null)
		# 6. dropped onto a mount of its kind: an empty one if there is one
		var at := 0
		for i in Run.slots_for(carried.slot):
			if Run.module_at(carried.slot, i) == null:
				at = i
				break
		await cut._on_mount_drop({module = carried, origin = &"cargo"}, carried.slot, at)
		await _frames(20)
		_still("06_fitted")
	# 7. THE WRECK, clicked where LOCAL draws it in the sky behind: its bay
	var wreck_rect := Rect2()
	var made: Array = sc._view._made
	if not made.is_empty() and (made[0] as EnemySlot).art != null:
		wreck_rect = (made[0] as EnemySlot).art.get_global_rect()
	if wreck_rect.has_area():
		cut._sky_click(wreck_rect.get_center())
	await _frames(20)
	_still("07_wreck_popup")
	print("cutawayshot: the wreck's popup %s" % ("opened" if cut.popup_open() else "DID NOT OPEN"))
	if cut.popup_open():
		# 8. a module in it pointed at
		for c in cut._pop_grid.get_children():
			if c is ItemIcon and (c as ItemIcon).held_item() is ModuleData:
				cut._point((c as Control).get_global_rect().get_center())
				break
		await _frames(12)
		_still("08_hover_wreck")
		cut._show(null)
		# 9. TAKE ALL
		await cut._take_all(cut._pop_jetsam)
		await _frames(20)
		_still("09_wreck_taken")
	cut.close_popup()
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
