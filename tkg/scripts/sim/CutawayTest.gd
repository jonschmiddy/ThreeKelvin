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

	# 6. the pile again, with a gun in it: straight onto an empty mount
	var wreck := pile
	var prize := _module_of(w)
	wreck.items.append(prize)
	wreck.items.append(MaterialData.of(MaterialTable.all()[1]))
	_cut.open_popup(wreck, BAR_BUTTON)
	await _settle()
	_ok("the pile opens in the popup, one popup at a time (%d drawn)" % _icons(_cut._pop_grid),
		_cut._pop_jetsam == wreck and _icons(_cut._pop_grid) == 2 and _popups() == 1)
	var empty := -1
	for i in Run.slots_for(w):
		if Run.module_at(w, i) == null:
			empty = i
			break
	if empty >= 0:
		await _cut._on_mount_drop({module = prize, origin = &"bag"}, w, empty)
		await _settle()
		_ok("a part from the pile dropped on an empty mount is fitted", Run.module_at(w, empty) == prize)
		_ok("and claimed out of the pile", Run.jetsam_left(_node, wreck) == 1)

	# 7. TAKE ALL
	_cut._pop_take.pressed.emit()
	for i in 4:
		await _tree.process_frame
	_ok("TAKE ALL empties the pile into the hold", Run.jetsam_left(_node, wreck) == 0)
	_ok("and the popup is drawn empty (%d)" % _icons(_cut._pop_grid), _icons(_cut._pop_grid) == 0)

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
	_cut.open_popup(wreck, BAR_BUTTON)
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

	# 8b. R TURNS A PART IN THE HOLD, F FLIPS ONE ON THE HULL (the refit
	# screen's own calls), and the pencil opens the refit screen's own prompt
	Run.cargo.clear()
	var long := _module_of(w, Vector2i(2, 1))
	if long == null:
		long = _module_of(w, Vector2i(3, 1))
	if long != null and Run.place_in_hold(long):
		_cut._refresh()
		await _settle()
		var ic := _icon_for(_cut._hold, long)
		var was_turned := long.turned
		if ic != null:
			ShipScreen.turn_in_hold(_cut._hold, ic.get_global_rect().get_center())
		_ok("R turns a part in the cutaway's hold (%s)" % long.name, long.turned != was_turned and Run.cargo.has(long))
	var fitted := Run.installed[0]
	var was_flipped := fitted.flipped
	for sp in _cut._mounts.spots():
		if sp.held == fitted:
			var pr := _cut._mounts.part_rect(fitted, sp.slot, _cut._mounts._part_at(sp), _cut._mounts._mag())
			ShipScreen.flip_at(_cut._mounts, pr.get_center())
	_ok("F mirrors a part on the cutaway's hull", fitted.flipped != was_flipped)
	fitted.flipped = was_flipped
	_cut.open_rename()
	await _settle()
	_ok("the pencil opens the refit screen's rename prompt over the cutaway", _cut._rename != null and is_instance_valid(_cut._rename))
	var esc2 := InputEventKey.new()
	esc2.keycode = KEY_ESCAPE
	esc2.pressed = true
	_cut._input(esc2)
	await _settle()
	_ok("Esc shuts the prompt and leaves the cutaway open", _cut._rename == null and _cut.is_open())

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
	# 11. the real LOCAL: a wreck in the sky behind is not opened from in here,
	# and outside it opens its own screen; in a fight your ship is a dead button
	await _check_local()
	# 12. the MODULES page still builds its own popup through the one builder
	var gm := _module_of(ModuleData.Slot.WEAPON)
	var gi := ModuleIcon.new()
	gi.setup(gm, &"gallery")
	var gt := gi._make_custom_tooltip("") as Control
	_ok("the MODULES page's icon builds its popup with ModuleIcon.tip_for",
		gt != null and gt.has_meta(&"module") and gt.get_meta(&"module") == gm)
	if gt != null:
		gt.free()
	gi.free()
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
##  - the popup (this system's pile) right of the left panel,
##    on screen, every cell and button in it too;
##  - pointing at a module in each place -- the hold, the hull, this system's
##    pile -- shows the MODULES page's own popup for THAT module, clear of the
##    left panel, of the thing pointed at and of the open popup, and nothing in
##    here carries Godot's own tooltip as well;
##  - a bob step carries every part, tag and label with the hull;
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
		var in_loot := _module_of(ModuleData.Slot.WEAPON)
		Run.sector_jetsam(node, true).items.append(in_loot)
		# and two malfunctions in the deck, so their line is there to be measured
		var junk: Array[StringName] = [DB.MALFUNCTIONS[0][0], DB.MALFUNCTIONS[0][0]]
		Run.dross = junk
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
		var origin := cut._ship.canvas_to_local(Vector2(0, -float(cut._ship._bob_amp + cut._ship._bob_off)))
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
		_ok("%s: the hold is above the attributes (Jon: hold on top)" % wname,
			cut._hold.get_global_rect().end.y <= cut._attrs.get_global_rect().position.y)
		# THE REFIT SCREEN'S PIECES, here now
		_ok("%s: the mounts line carries the hand and the deck (%s)" % [wname, cut._mount_line.text.replace("
", " / ")],
			cut._mount_line.text.contains("A TURN") and cut._mount_line.text.contains("IN THE DECK"))
		_ok("%s: the perks and set chips are in the left panel (%d pieces)" % [wname, cut._perks.get_child_count()],
			cut._perks.get_child_count() > 0 and left.encloses(cut._perks.get_global_rect()))
		_ok("%s: MALFUNCTIONS · 2 IN YOUR DECK is in it (%s)" % [wname, cut._dross.text],
			cut._dross.is_visible_in_tree() and cut._dross.text.contains("2") and left.encloses(cut._dross.get_global_rect()))
		cut._point(cut._dross.get_global_rect().get_center())
		await _tree.process_frame
		var dcard := cut._panel.get_global_rect()
		_ok("%s: pointing at it shows the malfunction's card on the same plate, clear of the left panel" % wname,
			cut._panel.visible and cut._panel_box.find_children("*", "CardView", true, false).size() == 1
			and not dcard.intersects(left))
		cut._show(null)
		_ok("%s: the R and F keys are named at the foot (%s)" % [wname, cut._keys.text],
			cut._keys.is_visible_in_tree() and left.encloses(cut._keys.get_global_rect()))
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
		for which in ["loose"]:
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
			var want: ModuleData = in_loot
			await _point_at(cut, wname, which, want, _icon_for(cut._pop_grid, want))
			_ok("%s: nothing in the hold or the popup carries Godot's own tooltip (one hover, one popup)" % wname,
				_tipless(cut._hold) and _tipless(cut._pop_grid))
			cut.close_popup()
			await _settle()
		_ok("%s: the hull's parts give no tooltip of their own in here" % wname,
			ship_at != Vector2.ZERO and mp._get_tooltip(mp.get_global_transform().affine_inverse() * ship_at) == "")
		# THE BOB: the hull stepped two pixels down, every part, tag and ring rides
		# with it by exactly that, and a part is still found where it is drawn
		var before := mp.drawn_rects()
		cut._ship._bob_off += 2
		mp._process(0.0)
		var after := mp.drawn_rects()
		var moved := before.size() == after.size() and not before.is_empty()
		var want_d := Vector2(0, 2.0 * cut._ship.art_scale())
		for i in mini(before.size(), after.size()):
			if not ((after[i].rect as Rect2).position - (before[i].rect as Rect2).position).is_equal_approx(want_d):
				moved = false
		var hit_part := false
		for d in after:
			if d.kind == "part":
				hit_part = mp.part_under((d.rect as Rect2).get_center()) != null
				break
		_ok("%s: a bob step moves every part, tag and label with the hull, and the parts are hit where drawn" % wname,
			moved and hit_part)
		cut._ship._bob_off -= 2
		mp._process(0.0)
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
	_ok("%s: pointing at a module in the %s shows the MODULES page's popup for it (%s)" % [wname, where,
		cut._shown.name if cut._shown != null else "nothing"],
		cut._shown == want and cut._panel.visible and _is_tip_for(cut, want))
	_ok("%s: and the card is on screen, clear of the left panel, the %s module%s" % [wname, where, " and the popup" if pop.has_area() else ""],
		cut.get_global_rect().encloses(card) and not card.intersects(left) and not card.intersects(item)
		and (not pop.has_area() or not card.intersects(pop)))
	cut._show(null)


## A left click at a point on screen, pressed and let go, as the pointer would.
## Pushed into the viewport `on` is drawn in -- the game's own, under Main's
## screen effect, for a screen; the root for a bare host.
func _click(gp: Vector2, on: Node = null) -> void:
	var vp: Viewport = on.get_viewport() if on != null else _tree.root
	# (headless, the window is 64 px square and a click past it goes nowhere)
	if vp == _tree.root and _tree.root.size.x < 1000:
		_tree.root.size = Vector2i(1920, 1080)
		await _settle()
	for down in [true, false]:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = down
		mb.position = gp
		mb.global_position = gp
		vp.push_input(mb)
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


## The card is `ModuleIcon.tip_for(m)` -- the builder the MODULES page's icons
## call -- and shows every card the module grants.
func _is_tip_for(cut: CutawayView, m: ModuleData) -> bool:
	if cut._panel_box.get_child_count() != 1:
		return false
	var tip := cut._panel_box.get_child(0)
	return tip.has_meta(&"module") and tip.get_meta(&"module") == m \
		and tip.find_children("*", "CardView", true, false).size() == m.resolved_cards().size()


## Whether a point is on the opened ship: its hull's pixels, a part, a tag, a
## ring -- what a click keeps the cutaway open on.
func _on_opened_ship(cut: CutawayView, gp: Vector2) -> bool:
	var lp := cut._mounts.get_global_transform().affine_inverse() * gp
	return cut._mounts.part_under(lp) != null or cut._mounts.hit_drawn(lp) or CutawayView.on_hull(cut._ship, lp)


## A point on the wreck's own metal, on screen, and (with the cutaway open) not
## on the opened ship; INF if none.
func _wreck_point(slot: EnemySlot, cut: CutawayView) -> Vector2:
	var view := slot.get_viewport().get_visible_rect()
	var r := slot.art.get_global_rect() if slot.art != null else slot.get_global_rect()
	for yy in range(int(r.position.y), int(r.end.y), 2):
		for xx in range(int(r.end.x) - 1, int(r.position.x), -2):
			var p := Vector2(xx, yy)
			if not view.has_point(p) or not slot._on_hull(slot.get_global_transform().affine_inverse() * p):
				continue
			if cut != null and (_on_opened_ship(cut, p) or cut._hold_panel.get_global_rect().has_point(p) 					or not cut.get_global_rect().has_point(p)):
				continue
			return p
	return Vector2.INF


func _tipless(g: Control) -> bool:
	if g == null:
		return true
	for c in g.get_children():
		if c is ItemIcon and (c as Control).tooltip_text != "":
			return false
	return true


## THE REAL LOCAL. A wreck you killed here, your ship, and the screen itself:
##  - with the cutaway open, a click where the wreck is drawn opens nothing and
##    shuts the cutaway (Jon: "You shouldn't be able to open a wreck when your
##    ship is clicked on and in focus");
##  - with it shut, the same click opens the wreck's own two-grid screen;
##  - in a fight, a click on your ship opens nothing and asks for the thud a dead
##    button makes (Jon: "the same thud sound when you try and click on a button
##    that doesn't work"), with no outline on it.
func _check_local() -> void:
	Rng.reseed(4242, 0)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var idx := -1
	for n: MapGen.MapNode in Run.map:
		if n.type == MapGen.NodeType.SYSTEM and not n.cleared:
			idx = n.index
			break
	if idx < 0:
		_ok("a system to stand in", false)
		return
	Run.at = idx
	Run.map[idx].visited = true
	SectorScreen._approached_at = idx
	var node: MapGen.MapNode = Run.node_at()
	var wreck := Run.new_wreck(node, DB.enemies[&"cutter"])
	wreck.items.append(_module_of(ModuleData.Slot.UTILITY))
	Router.show_local()
	for i in 40:
		await _tree.process_frame
	var sc := Router.current as SectorScreen
	if not _ok("LOCAL is up", sc != null):
		return
	var made: Array = sc._view._made
	if not _ok("the wreck is drawn on LOCAL", not made.is_empty()):
		return
	var row_was := sc._view._row.get_global_rect()
	var ship_was := sc._view.ship_view().get_global_rect()
	# (animated, as in play: the push-in and the ease back out)
	Router.animate_in_harness = true
	var cut := sc.open_cutaway()
	var t1 := Time.get_ticks_msec()
	while cut.t < 1.0 and Time.get_ticks_msec() - t1 < 3000:
		await _tree.process_frame
	_ok("your ship opens up on LOCAL", cut != null and is_instance_valid(cut) and cut.is_open())
	# YOUR SHIP IN THE ZOOMED SCENE IS THE ONE THE PARTS COME OFF: LOCAL's own
	# hull and the cutaway's (undrawn) one at the same place and scale
	var own := sc._view.ship_view()
	var a0 := own.get_global_transform() * own.canvas_to_local(Vector2.ZERO)
	var b0 := cut._ship.get_global_transform() * cut._ship.canvas_to_local(Vector2.ZERO)
	var sa := own.art_scale() * own.get_global_transform().get_scale().x
	var sb := cut._ship.art_scale() * cut._ship.get_global_transform().get_scale().x
	_ok("LOCAL's own ship, zoomed, is where the parts come off (%s vs %s, %.2fx vs %.2fx)" % [a0, b0, sa, sb],
		a0.distance_to(b0) <= 1.0 and is_equal_approx(sa, sb))
	var slot := made[0] as EnemySlot
	# THE SCENE ZOOMED WITH IT: the wreck is drawn bigger, round your ship
	_ok("the wreck is zoomed with the scene (%.1fx)" % slot.get_global_transform().get_scale().x,
		slot.get_global_transform().get_scale().x > 1.5)
	# a point on the wreck's own metal, as the slot itself reads it, on screen
	# and not covered by the opened ship; at 2x the wreck may be off the screen
	var wreck_at := _wreck_point(slot, cut)
	if wreck_at.x < INF:
		await _click(wreck_at, sc)
		_ok("with it open, a click on the wreck opens nothing and shuts the cutaway",
			sc._transfer == null and (not is_instance_valid(cut) or not cut.is_open()))
	else:
		print("  --   (the wreck is off the screen at 2x: nothing of it to click)")
		cut.close()
	var t0 := Time.get_ticks_msec()
	while is_instance_valid(cut) and Time.get_ticks_msec() - t0 < 3000:
		await _tree.process_frame
	await _settle()
	Router.animate_in_harness = false
	_ok("shut, the scene is back at its own size and place (row %s -> %s, ship %s -> %s)" % [row_was, sc._view._row.get_global_rect(), ship_was, sc._view.ship_view().get_global_rect()],
		is_equal_approx(slot.get_global_transform().get_scale().x, 1.0) and sc._view._row.get_global_rect().is_equal_approx(row_was)
		and sc._view.ship_view().get_global_rect().is_equal_approx(ship_was))
	wreck_at = _wreck_point(slot, null)
	await _click(wreck_at, sc)
	_ok("with it shut, a click on the wreck opens its own screen (TransferView)", sc._transfer != null)
	sc._close_transfer()
	await _settle()
	# a fight
	Router.start_combat(DB.enemies[&"cutter"], [], false, false)
	for i in 40:
		await _tree.process_frame
	var fs := Router.current as SectorScreen
	if not _ok("a fight is up", fs != null and fs.fighting()):
		return
	var art := fs._view.ship_view()
	var ink := Rect2(art.ink_rect())
	var on := Vector2.INF
	var c0 := art.canvas_to_local(Vector2(ink.get_center().x, ink.get_center().y - float(art._bob_amp)))
	for rad in range(0, 200, 2):
		for p in [c0 + Vector2(rad, 0), c0 - Vector2(rad, 0), c0 + Vector2(0, rad), c0 - Vector2(0, rad)]:
			if on.x == INF and CutawayView.on_hull(art, p):
				on = art.get_global_transform() * p
	var was := fs.denied_clicks
	await _click(on, fs)
	_ok("in a fight, a click on your ship opens nothing and asks for the dead-button thud (%d)" % (fs.denied_clicks - was),
		fs._cutaway == null and fs.denied_clicks == was + 1)
	_ok("and it wears no outline", not fs._ship_outline.visible)


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
