extends Harness

## THE CUTAWAY'S MOVES, through the cutaway's own handlers, headless:
##   godot --headless --path . -- cutawaytest
##
## `CutawayView` moves parts with Run's rule (`lift_part`, `fit_at_mount`,
## `stow_at`) and claims loot with the calls SECTOR LOOT makes (`take_item`,
## `take_from_jetsam`), so the refit screen, the map's loot popup and the
## cutaway cannot disagree. This drives the view's own drop handlers -- what a
## real drag ends in -- and checks both the model AND what the view draws (its
## hold's icons, its popup's grid), because a model that moved and a screen
## that did not is the bug the transfer screen had three times. Then the
## picture itself on every hull: see `_check_layouts`.

## Where LOCAL's SECTOR LOOT sits, on the bottom bar under the cutaway.
const BAR_BUTTON := Rect2(770, 466, 94, 20)

var _tree: SceneTree
var _cut: CutawayView
var _node: MapGen.MapNode


func run(tree: SceneTree) -> void:
	_tree = tree
	await tree.process_frame
	Rng.reseed(4242, 0)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	_node = Run.node_at()
	_node.jetsam.clear()
	_node.taken.clear()
	Run.cargo.clear()

	var host := Control.new()
	host.size = Vector2(960, 459)
	tree.root.add_child(host)
	_cut = CutawayView.open_over(host, null)
	for i in 4:
		await tree.process_frame
	_ok("the cutaway opens without LOCAL's hull (headless, reduced)", _cut != null and is_instance_valid(_cut))
	_ok("and picks a push-in scale (%dx)" % _cut.k, _cut.k == 1 or _cut.k == 2)

	# a weapon mount with something on it, and a spare weapon in the hold
	var w := ModuleData.Slot.WEAPON
	var on: ModuleData = null
	var at_mount := -1
	for i in Run.slots_for(w):
		if Run.module_at(w, i) != null:
			on = Run.module_at(w, i)
			at_mount = i
			break
	if not _ok("the ship has a gun fitted", on != null):
		return _finish()
	var spare := _module_of(w)
	_ok("a spare gun goes in the hold", Run.place_in_hold(spare))
	await _settle()
	_ok("the hold draws it (%d icon)" % _icons(_cut._hold), _icons(_cut._hold) == Run.cargo.size())

	# 1. hold -> occupied mount: the spare is fitted, the resident goes to the hold
	await _cut._on_mount_drop({module = spare, origin = &"cargo"}, w, at_mount)
	await _settle()
	_ok("a part from the hold onto an occupied mount is fitted there",
		Run.module_at(w, at_mount) == spare)
	_ok("and the part it displaced is in the hold", Run.cargo.has(on) and not Run.installed.has(on))
	_ok("and the hold draws it as it is (%d icons, %d in cargo)" % [_icons(_cut._hold), Run.cargo.size()],
		_icons(_cut._hold) == Run.cargo.size())

	# 2. a lift that never lands goes back where it was
	var mount_was := spare.mount
	_cut._on_lift(spare)
	_ok("lifting takes it off the ship", not Run.installed.has(spare))
	_cut._on_release()
	_ok("a lift that never landed puts it back on its mount",
		Run.installed.has(spare) and spare.mount == mount_was)

	# 3. lifted onto another occupied mount of its kind: the two trade
	var other := -1
	for i in Run.slots_for(w):
		if i != spare.mount and Run.module_at(w, i) != null:
			other = i
			break
	if other >= 0:
		var there := Run.module_at(w, other)
		var from := spare.mount
		_cut._on_lift(spare)
		await _cut._on_mount_drop({module = spare, origin = &"hull"}, w, other)
		_ok("a fitted part moved onto another fitted one trades places",
			Run.module_at(w, other) == spare and Run.module_at(w, from) == there)
	else:
		print("  --   (one weapon mount fitted: the trade is not exercised)")

	# 4. off the ship into the hold
	var cell := _free_cell(spare)
	_cut._on_lift(spare)
	await _cut._on_hold_drop({module = spare, origin = &"hull"}, cell)
	await _settle()
	_ok("a fitted part dropped on the hold is stored there",
		Run.cargo.has(spare) and not Run.installed.has(spare) and spare.mount == -1)
	_ok("and the hold draws it (%d icons)" % _icons(_cut._hold), _icons(_cut._hold) == Run.cargo.size())

	# 5. this system's loot: its popup (LOCAL's SECTOR LOOT opens it beside the
	# button on the bottom bar), and into the hold with the claim SECTOR LOOT makes
	var pile := Run.sector_jetsam(_node, true)
	var loose := MaterialData.of(MaterialTable.all()[0])
	pile.items.append(loose)
	_cut._refresh()
	_cut.open_popup(pile, BAR_BUTTON)
	await _settle()
	_ok("this system's pile opens in a popup (%d drawn)" % (_icons(_cut._pop_grid) if _cut._pop_grid != null else -1),
		_cut.popup_open() and _cut._pop_jetsam == pile and _icons(_cut._pop_grid) == 1)
	await _cut._on_hold_drop({module = loose, origin = &"bag"}, _free_cell(loose))
	await _settle()
	_ok("loot dragged to the hold is taken", Run.cargo.has(loose))
	_ok("and claimed, so SECTOR LOOT shows it gone (%d left)" % Run.jetsam_left(_node, pile),
		Run.jetsam_left(_node, pile) == 0)
	_ok("and the popup stops drawing it (%d), and says so" % _icons(_cut._pop_grid),
		_icons(_cut._pop_grid) == 0 and _cut._pop_empty.visible)

	# 6. a wreck's bay, as the click on the wreck opens it: a gun straight onto
	# an empty mount
	var wreck := Run.new_wreck(_node, DB.enemies[&"cutter"])
	var prize := _module_of(w)
	wreck.items.append(prize)
	wreck.items.append(MaterialData.of(MaterialTable.all()[1]))
	_cut.open_popup(wreck, Rect2(700, 120, 120, 60))
	await _settle()
	_ok("a wreck's bay opens in the popup, one popup at a time (%d drawn)" % _icons(_cut._pop_grid),
		_cut._pop_jetsam == wreck and _icons(_cut._pop_grid) == 2 and _popups() == 1)
	var empty := -1
	for i in Run.slots_for(w):
		if Run.module_at(w, i) == null:
			empty = i
			break
	if empty >= 0:
		await _cut._on_mount_drop({module = prize, origin = &"bag"}, w, empty)
		await _settle()
		_ok("a wreck's part dropped on an empty mount is fitted", Run.module_at(w, empty) == prize)
		_ok("and claimed out of the wreck", Run.jetsam_left(_node, wreck) == 1)

	# 7. TAKE ALL
	_cut._pop_take.pressed.emit()
	for i in 4:
		await _tree.process_frame
	_ok("TAKE ALL empties the wreck into the hold", Run.jetsam_left(_node, wreck) == 0)
	_ok("and the bay is drawn empty (%d)" % _icons(_cut._pop_grid), _icons(_cut._pop_grid) == 0)

	# 7b. Esc shuts the popup first, then the cutaway
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	_cut._input(esc)
	await _settle()
	_ok("Esc shuts the popup and leaves the cutaway open", not _cut.popup_open() and _cut.is_open())

	# 7c. CLICKS: on the sky with a popup open, the popup alone shuts; on a tag
	# or an empty mount's ring, nothing; a drag let go of over the sky puts the
	# part back and shuts nothing
	_cut.open_popup(wreck, Rect2(700, 120, 120, 60))
	await _settle()
	_cut._sky_click(_cut.get_global_rect().position + Vector2(_cut.size.x - 6, 6))
	await _settle()
	_ok("a click on the sky with a popup open shuts the popup, not the cutaway",
		not _cut.popup_open() and _cut.is_open())
	var tag_hit := Vector2.INF
	for d in _cut._mounts.drawn_rects():
		if d.kind == "tag":
			tag_hit = (d.rect as Rect2).get_center()
			break
	if tag_hit.x < INF:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = true
		mb.position = tag_hit
		mb.global_position = _cut._mounts.get_global_transform() * tag_hit
		_cut._on_hull_input(mb)
		await _settle()
		_ok("a click on a part's tag shuts nothing", _cut.is_open())
	var held := Run.installed[0]
	var held_at := held.mount
	_cut._on_lift(held)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.global_position = _cut.get_global_rect().position + Vector2(_cut.size.x - 6, 6)
	_cut._gui_input(up)
	_cut._mounts.released.emit()
	await _settle()
	_ok("a drag let go of over the sky puts the part back and shuts nothing",
		Run.installed.has(held) and held.mount == held_at and _cut.is_open())

	# 8. a full hold refuses a swap BEFORE anything moves
	var fill := 0
	while fill < 40:
		fill += 1
		var junk := MaterialData.of(MaterialTable.all()[0])
		if not Run.place_in_hold(junk):
			break
	var big := _module_of(w, Vector2i(3, 1))
	var resident: ModuleData = null
	var rm := -1
	for i in Run.slots_for(w):
		if Run.module_at(w, i) != null:
			resident = Run.module_at(w, i)
			rm = i
			break
	if big != null and resident != null:
		var before_fit := Run.installed.duplicate()
		var before_hold := Run.cargo.duplicate()
		big.hold_at = -Vector2i.ONE
		# from nowhere (a part not in the hold) onto an occupied mount, hold full
		await _cut._on_mount_drop({module = big, origin = &"cargo"}, w, rm)
		_ok("a full hold refuses the swap and nothing moves",
			Run.installed == before_fit and Run.cargo == before_hold and Run.module_at(w, rm) == resident)

	# 9. closing puts nothing in limbo
	var n_before := Run.installed.size() + Run.cargo.size()
	_cut._on_lift(Run.installed[0])
	_cut.close()
	for i in 3:
		await tree.process_frame
	_ok("closing with a part in hand puts it back (%d -> %d)" % [n_before, Run.installed.size() + Run.cargo.size()],
		Run.installed.size() + Run.cargo.size() == n_before)
	host.queue_free()

	# 10. the picture itself, on every hull
	await _check_layouts()
	_finish()


func _popups() -> int:
	var n := 0
	for c in _cut.get_children():
		if c == _cut._popup:
			n += 1
		elif c is PanelContainer and c != _cut._panel and c != _cut._hold_panel and not c.is_queued_for_deletion():
			n += 1
	return n


## THE CUTAWAY'S PICTURE, per hull, read off what is DRAWN (`MountPoints`'s
## rects, the controls' own rects), not off the layout's own bookkeeping:
##  - every word clear of every other word and of the hull's own pixels, every
##    lifted part off the hull and off every other part, all of it right of the
##    left panel and inside the view;
##  - the left panel (the ship's numbers, its hold, DONE) the
##    content area's full height, every hold cell and button in it on screen and
##    uncovered;
##  - each popup (a wreck's bay, this system's pile) right of the left panel,
##    on screen, every cell and button in it too;
##  - pointing at a module in each of the four places -- the hold, the hull, a
##    wreck's bay, this system's pile -- puts THAT module in the card, which is
##    clear of the left panel, of the thing pointed at and of the open popup;
##  - and the heavy, the biggest ship, drawn at least as big as the medium.
func _check_layouts() -> void:
	var widths := {}
	for pair in [["light", HullData.Weight.LIGHT], ["medium", HullData.Weight.MEDIUM], ["heavy", HullData.Weight.HEAVY]]:
		var wname: String = pair[0]
		Rng.reseed(4242, 0)
		Run.start_new_run(&"korvan", int(pair[1]))
		var node := Run.node_at()
		node.jetsam.clear()
		node.taken.clear()
		Run.cargo.clear()
		# something in every place the pointer can find a module
		var in_hold := _module_of(ModuleData.Slot.SYSTEM)
		Run.place_in_hold(in_hold)
		var wreck := Run.new_wreck(node, DB.enemies[&"cutter"])
		var in_wreck := _module_of(ModuleData.Slot.UTILITY)
		wreck.items.append(in_wreck)
		wreck.items.append(MaterialData.of(MaterialTable.all()[2]))
		var in_loot := _module_of(ModuleData.Slot.WEAPON)
		Run.sector_jetsam(node, true).items.append(in_loot)
		# (LOCAL's content area between the HUD and its bottom bar: what the cutaway covers)
		var host := Control.new()
		host.size = Vector2(960, 459)
		_tree.root.add_child(host)
		var cut := CutawayView.open_over(host, null)
		for i in 4:
			await _tree.process_frame
		var view := cut.get_global_rect()
		var left := cut._hold_panel.get_global_rect()
		print("  ..   %s: %dx, left panel %dx%d; %s" % [wname, cut.k, left.size.x, left.size.y, cut.fit_note])

		# THE EXPLODED SHIP
		var mp := cut._mounts
		var to_cut := cut.get_global_transform().affine_inverse() * mp.get_global_transform()
		var img := cut._ship.canvas()
		var origin := cut._ship.canvas_to_local(Vector2.ZERO)
		var sc := cut._ship.art_scale()
		var rects := mp.drawn_rects()
		var words := 0
		var clash: Array[String] = []
		var on_hull: Array[String] = []
		var outside: Array[String] = []
		for i in rects.size():
			var a: Dictionary = rects[i]
			var ra: Rect2 = a.rect
			if a.kind != "part":
				words += 1
			if _opaque_in(img, Rect2((ra.position - origin) / sc, ra.size / sc)):
				on_hull.append("%s %s" % [a.kind, a.text])
			var g := to_cut * ra
			if g.position.x < cut._hold_w or g.position.y < 0.0 or g.end.x > cut.size.x or g.end.y > cut.size.y:
				outside.append("%s %s (%d,%d %dx%d)" % [a.kind, a.text, g.position.x, g.position.y, g.size.x, g.size.y])
			for j in range(i + 1, rects.size()):
				var b: Dictionary = rects[j]
				if ra.intersects(b.rect):
					clash.append("%s %s / %s %s" % [a.kind, a.text, b.kind, b.text])
		_ok("%s: no word or part overlaps another (%s)" % [wname, ", ".join(clash) if not clash.is_empty() else "%d drawn" % rects.size()], clash.is_empty())
		_ok("%s: no word or lifted part sits on the hull's pixels (%s)" % [wname, ", ".join(on_hull) if not on_hull.is_empty() else "%d words" % words], on_hull.is_empty())
		_ok("%s: the ship is right of the left panel and inside the view (%s)" % [wname,
			", ".join(outside) if not outside.is_empty() else "clear"], outside.is_empty())

		# THE LEFT PANEL: full height, every hold cell and button on it, on screen
		_ok("%s: the left panel is the content area's full height (%d of %d)" % [wname, left.size.y, view.size.y],
			is_equal_approx(left.size.y, view.size.y) and is_equal_approx(left.position.y, view.position.y))
		_ok("%s: the left panel's contents fit it (%d of %d tall)" % [wname, cut._hold_panel.get_combined_minimum_size().y, left.size.y],
			cut._hold_panel.get_combined_minimum_size().y <= left.size.y + 0.5)
		var g2 := Run.hold_grid()
		var hold_rect := cut._hold.get_global_rect()
		var bad_cells := 0
		for y in g2.y:
			for x in g2.x:
				var c := Rect2(hold_rect.position + Vector2(x, y) * float(HoldGrid.CELL + HoldGrid.GAP), Vector2.ONE * float(HoldGrid.CELL))
				if not view.encloses(c) or not left.encloses(c):
					bad_cells += 1
		_ok("%s: all %d hold cells are on screen and in the left panel, %d px each (%d not)" % [wname, g2.x * g2.y, HoldGrid.CELL, bad_cells],
			bad_cells == 0 and cut._hold.mouse_filter == Control.MOUSE_FILTER_STOP)
		var dr := cut._done.get_global_rect()
		_ok("%s: DONE · ESC is on screen at the foot of the left panel" % wname,
			cut._done.is_visible_in_tree() and view.encloses(dr) and left.encloses(dr) and dr.end.y >= left.end.y - 40.0)

		# POINTING: the hold and the hull, no popup open
		await _point_at(cut, wname, "hold", in_hold, _icon_for(cut._hold, in_hold))
		var on_ship: ModuleData = null
		var ship_at := Vector2.ZERO
		for s in mp.spots():
			if s.held != null:
				on_ship = s.held
				var pr := mp.part_rect(s.held, s.slot, mp._part_at(s), mp._mag())
				ship_at = mp.get_global_transform() * pr.get_center()
				break
		await _point_gp(cut, wname, "hull", on_ship, ship_at)

		# EACH POPUP over this hull, and a module in it pointed at
		for which in ["wreck", "loose"]:
			if which == "wreck":
				# beside where LOCAL draws a wreck: the sky's right side
				cut.open_popup(wreck, Rect2(cut.get_global_rect().position + Vector2(cut.size.x - 220, 150), Vector2(160, 80)))
			else:
				cut.open_popup(Run.sector_jetsam(node, false), BAR_BUTTON)
			await _settle()
			var pop := cut._popup.get_global_rect() if cut._popup != null else Rect2()
			var bad := 0
			for c in cut._pop_grid.get_children():
				if c is ItemIcon and (c as Control).is_visible_in_tree():
					var r := (c as Control).get_global_rect()
					if not view.encloses(r) or not pop.encloses(r) or r.intersects(left):
						bad += 1
			var tr := cut._pop_take.get_global_rect()
			_ok("%s: the %s popup is on screen, right of the left panel, every cell and TAKE ALL in it (%d cells off)" % [wname, which, bad],
				cut.popup_open() and view.encloses(pop) and not pop.intersects(left) and bad == 0 and pop.encloses(tr) and _popups_of(cut) == 1)
			var want: ModuleData = in_wreck if which == "wreck" else in_loot
			await _point_at(cut, wname, which, want, _icon_for(cut._pop_grid, want))
			cut.close_popup()
			await _settle()
		widths[wname] = float(cut._ship.ink_rect().size.x) * sc
		# REAL CLICKS, through the viewport: anywhere on the left panel -- its
		# empty foot included -- shuts nothing; one on the empty sky shuts it
		await _click(left.position + Vector2(left.size.x * 0.5, left.size.y - 60.0))
		await _click(left.position + Vector2(6, 6))
		_ok("%s: clicks on the left panel, even its empty space, leave the cutaway open" % wname,
			is_instance_valid(cut) and cut.is_open())
		await _click(view.position + Vector2(view.size.x - 6, 6))
		_ok("%s: a click on the empty sky shuts the cutaway" % wname, not is_instance_valid(cut) or not cut.is_open())
		if is_instance_valid(cut):
			cut.queue_free()
		host.queue_free()
		await _settle()
	_ok("the heavy is drawn at least as big as the medium (%d px wide against %d)" % [int(widths.heavy), int(widths.medium)],
		widths.heavy >= widths.medium)


func _point_at(cut: CutawayView, wname: String, where: String, want: ModuleData, icon: Control) -> void:
	if icon == null:
		_ok("%s: a module is there to point at in the %s" % [wname, where], false)
		return
	await _point_gp(cut, wname, where, want, icon.get_global_rect().get_center(), icon.get_global_rect())


func _point_gp(cut: CutawayView, wname: String, where: String, want: ModuleData, gp: Vector2, item := Rect2()) -> void:
	if want == null:
		_ok("%s: a module is there to point at on the %s" % [wname, where], false)
		return
	cut._show(null)
	cut._point(gp)
	await _tree.process_frame
	var card := cut._panel.get_global_rect()
	var left := cut._hold_panel.get_global_rect()
	var pop := cut._popup.get_global_rect() if cut._popup != null else Rect2()
	if not item.has_area():
		item = Rect2(gp - Vector2(4, 4), Vector2(8, 8))
	_ok("%s: pointing at a module in the %s shows it, picture and cards, in the card (%s)" % [wname, where,
		cut._shown.name if cut._shown != null else "nothing"],
		cut._shown == want and cut._panel.visible and _has_pic(cut, want) and _has_cards(cut))
	_ok("%s: and the card is on screen, clear of the left panel, the %s module%s" % [wname, where, " and the popup" if pop.has_area() else ""],
		cut.get_global_rect().encloses(card) and not card.intersects(left) and not card.intersects(item)
		and (not pop.has_area() or not card.intersects(pop)))
	cut._show(null)


## A left click at a point on screen, pressed and let go, as the pointer would.
func _click(gp: Vector2) -> void:
	for down in [true, false]:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = down
		mb.position = gp
		mb.global_position = gp
		_tree.root.push_input(mb)
		await _tree.process_frame
	await _settle()


func _popups_of(cut: CutawayView) -> int:
	var n := 0
	for c in cut.get_children():
		if c is PanelContainer and c != cut._panel and c != cut._hold_panel and not c.is_queued_for_deletion():
			n += 1
	return n


func _icon_for(g: Control, m: HoldItem) -> Control:
	if g == null:
		return null
	for c in g.get_children():
		if c is ItemIcon and (c as ItemIcon).held_item() == m and (c as Control).is_visible_in_tree():
			return c
	return null


func _has_pic(cut: CutawayView, m: ModuleData) -> bool:
	for c in cut._panel_box.get_children():
		if c is CutawayView.Pic and (c as CutawayView.Pic).m == m:
			return true
	return false


func _has_cards(cut: CutawayView) -> bool:
	return not cut._panel_box.find_children("*", "CardView", true, false).is_empty()


func _opaque_in(img: Image, r: Rect2) -> bool:
	if img == null:
		return false
	for y in range(maxi(0, int(floor(r.position.y))), mini(img.get_height(), int(ceil(r.end.y)))):
		for x in range(maxi(0, int(floor(r.position.x))), mini(img.get_width(), int(ceil(r.end.x)))):
			if img.get_pixel(x, y).a > 0.1:
				return true
	return false


func _finish() -> void:
	verdict("cutawaytest")
	_tree.quit(code())


func _settle() -> void:
	for i in 2:
		await _tree.process_frame


func _icons(g: Control) -> int:
	if g == null:
		return 0
	var n := 0
	for c in g.get_children():
		if c is ItemIcon and (c as Control).visible:
			n += 1
	return n


func _free_cell(m: HoldItem) -> Vector2i:
	var g := Run.hold_grid()
	for y in g.y:
		for x in g.x:
			if Run.can_place(m, Vector2i(x, y)):
				return Vector2i(x, y)
	return -Vector2i.ONE


## A module of this slot from the catalogue (of this size, if asked), a copy.
func _module_of(s: ModuleData.Slot, want: Vector2i = Vector2i.ZERO) -> ModuleData:
	for id in DB.modules:
		var m: ModuleData = DB.modules[id]
		if m.slot != s or m.starter_only:
			continue
		if want != Vector2i.ZERO and m.size != want:
			continue
		return m.duplicate(true) as ModuleData
	return null
