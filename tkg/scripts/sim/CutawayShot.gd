extends Node

## THE CUTAWAY, photographed through the real screen (`CutawayView` on
## `SectorScreen`):
##   godot --path . --windowed --position 3840,0 -- sheet=CutawayShot keepwindow
##       clip=<dir> [weight=light|medium|heavy] [loot=no] [style=...] [seed=N]
##       [every=1] [nopause] [nofight]
## A run at a system with a wreck you killed, parts in the hold and (unless
## `loot=no`) something loose in the system. Saves the game's picture every
## `every` frames through: the hover outline on your ship, the push-in (backdrop
## breaking up), a part pointed at, a part carried (its rings pulsing), the drop
## onto a mount, TAKE ALL on the wreck, the close; then the real escape menu over
## the same scene (for the backdrop beside it), then a fight with a card pointed
## at (its part lit on the hull). Prints the push-in scale, where the shelf sits,
## and whether any lifted part or tag reaches into the shelf. Needs a window.
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
	print("cutawayshot: push-in %dx%s, shelf top %.0f, hull %s" % [cut.k, " (panel on hover)" if cut.hover_panel else "", cut._shelf_top, Run.hull.display_name()])
	_report_fit(cut)
	print("cutawayshot: %s" % cut.fit_note)
	# 2b. a shelf resting low (the heavy) rises to the pointer
	if cut._shelf_rest > cut._shelf_top:
		cut._shelf_up = true
		await _frames(20)
		_still("02b_shelf_raised")
		cut._shelf_up = false
		await _frames(20)
	# 3. a fitted part pointed at
	if not Run.installed.is_empty():
		var pm: ModuleData = Run.installed[0]
		# where a pointer on it would be (the heavy's panel docks away from it)
		for sp in cut._mounts.spots():
			if sp.held == pm:
				cut._last_gp = cut._mounts.get_global_transform() * cut._mounts._part_at(sp)
		cut._show(pm)
		cut._mounts.focus(pm)
	await _frames(12)
	_still("03_part_pointed")
	cut._mounts.focus(null)
	# 4. a part from the hold carried: its rings pulse
	var carried: ModuleData = null
	for m in Run.cargo:
		if m is ModuleData:
			carried = m
			break
	if carried != null:
		# (carrying: beside the panel it shows the part; on the heavy's rung the
		# panel goes, so it cannot cover a ring)
		if cut.hover_panel:
			cut._show(null)
		else:
			cut._show(carried)
		cut._mounts.light(carried)
		await _frames(24)
		_still("04_carrying")
		cut._mounts.light(null)
		# 5. dropped onto a mount of its kind: an empty one if there is one
		var at := 0
		for i in Run.slots_for(carried.slot):
			if Run.module_at(carried.slot, i) == null:
				at = i
				break
		await cut._on_mount_drop({module = carried, origin = &"cargo"}, carried.slot, at)
		await _frames(20)
		_still("05_fitted")
	# 6. TAKE ALL on the wreck
	if cut._wreck != null:
		await cut._take_all(cut._wreck)
		await _frames(20)
		_still("06_wreck_taken")
	# 7. the close
	cut.close()
	await _frames(40)
	_still("07_closed")
	# 8. THE ESCAPE MENU over the same scene, for its backdrop beside the cutaway's
	if not "nopause" in _args:
		var main := get_parent()
		if main != null and main.has_method("toggle_menu"):
			main.toggle_menu()
			await _frames(40)
			_still("08_pause_menu")
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
					_still("09_fight_card_lights_part")
					print("cutawayshot: pointed at %s (from %s)" % [cv.card.name, cv.card.source_id])
					break
	tree.quit()


## Whether anything lifted reaches into the shelf or past the panel's edge.
func _report_fit(cut: CutawayView) -> void:
	var mp := cut._mounts
	var g := mp.get_global_transform()
	var top_y := cut.get_global_transform() * Vector2(0, cut._shelf_rest)
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
	print("cutawayshot: %d parts lifted; lowest edge %.0f against the shelf at %.0f: %s" % [n, worst, top_y.y,
		"clear" if worst <= top_y.y else "OVERLAPS"])
