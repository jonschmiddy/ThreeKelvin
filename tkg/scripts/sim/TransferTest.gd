extends Harness

## Counts drawn icons, not the model: the same stale-screen bug came back under three triggers.
## Why: docs/why/TransferTest.md#transfer-test

var _tree: SceneTree
var _view: TransferView
var _node: MapGen.MapNode


func run(tree: SceneTree) -> void:
	_tree = tree
	await tree.process_frame

	seed_run(4242)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	_node = Run.node_at()
	_node.jetsam.clear()
	_node.taken.clear()
	Run.cargo.clear()
	# ONE CONTAINER, made the way a kill makes one, so this exercises the real
	# shape rather than a bag propped up beside it.
	var wreck := Run.new_wreck(_node, DB.enemies[&"cutter"])

	# Something in the hold and something on the floor, which is the only state
	# this screen exists for.
	var mine := LootGen.roll_module(3)
	if not _ok("a part goes in the hold", Run.place_in_hold(mine)):
		return _finish()
	wreck.items.append(LootGen.roll_module(3))
	wreck.items.append(MaterialData.of(MaterialTable.all()[0]))

	_view = TransferView.new()
	tree.root.add_child(_view)
	# No sweep: this harness counts what is VISIBLE, and a reveal in progress
	# would have it measuring an empty container and reporting a bug.
	_view.setup(wreck, _node, func() -> void: pass, false)
	await tree.process_frame
	await tree.process_frame

	var hold0 := _icons(_view._hold)
	var out0 := _icons(_view._loose)
	if not _ok("the view draws one in the hold and two out here (%d, %d)"
			% [hold0, out0], hold0 == 1 and out0 == 2):
		return _finish()

	# --- a drop into the container -------------------------------------------
	# Driven at the grid with nothing refreshed by hand: the screen must redraw itself.
	var payload := {module = mine, origin = &"cargo"}
	_ok("the container accepts one of yours",
		_view._loose._can_drop_data(Vector2(20, 20), payload))
	_view._loose._drop_data(Vector2(20, 20), payload)
	await tree.process_frame
	_ok("and the hold stops drawing it (%d)" % _icons(_view._hold),
		_icons(_view._hold) == hold0 - 1)
	_ok("and it is drawn out here instead (%d)" % _icons(_view._loose),
		_icons(_view._loose) == out0 + 1)

	# --- and a right-click, which must now do NOTHING ------------------------
	# Inverted rather than deleted: a quietly returning binding would reach players first.
	# Why: docs/why/TransferTest.md#right-click
	var back: HoldItem = wreck.items[0]
	_ok("something comes back into the hold", Run.stow(back))
	await tree.process_frame
	var hold1 := _icons(_view._hold)
	var icon := _find_icon(_view._hold, back)
	if not _ok("the hold is drawing it", icon != null):
		return _finish()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	icon._gui_input(click)
	await tree.process_frame
	_ok("right-click leaves it exactly where it was (%d)" % hold1,
		_icons(_view._hold) == hold1)
	# Put the hold back the way the next section expects to find it.
	Run.take_from_hold(back)
	await tree.process_frame

	# --- shift-click, the other way ------------------------------------------
	# Shift-click mirrors right-click and goes through no drop handler either.
	while Run.cargo.size() > 0:
		Run.take_from_hold(Run.cargo[0])
	await _tree.process_frame
	var grab := _first_icon(_view._loose)
	if grab != null:
		var out_was := _icons(_view._loose)
		var shift := InputEventMouseButton.new()
		shift.button_index = MOUSE_BUTTON_LEFT
		shift.pressed = true
		shift.shift_pressed = true
		await grab._gui_input(shift)
		await _tree.process_frame
		_ok("shift-click brings it aboard (%d in the hold)"
			% _icons(_view._hold), _icons(_view._hold) == 1)
		_ok("and out here stops drawing it (%d -> %d)"
			% [out_was, _icons(_view._loose)],
			_icons(_view._loose) == out_was - 1)

	# --- taking one out must not move the others -----------------------------
	var where: Dictionary = {}
	for k in _view._loose._at:
		where[k] = _view._loose._at[k]
	var tall := _view._loose._rows
	# (not the first: the shift-click above claimed it, and a claimed item cannot be taken again)
	var i := wreck.items.size() - 1
	while i >= 0 and _node.taken.has(wreck.option(i)):
		i -= 1
	if _ok("an item is still unclaimed and has room in the hold", i >= 0 and Run.has_room_for(wreck.items[i])):
		await Run.take_from_jetsam(_node, wreck, i)
		await tree.process_frame
		var moved := 0
		for k2 in _view._loose._at:
			if where.has(k2) and where[k2] != _view._loose._at[k2]:
				moved += 1
		_ok("nothing else in the pile moved (%d)" % moved, moved == 0)
		_ok("and the container did not shrink (%d -> %d)"
			% [tall, _view._loose._rows], _view._loose._rows >= tall)

	# --- one at a time, in reading order (Jon, Nov 18) ------------------------
	# Replaced the glitch's blink count: the vertical sweep and its glitch are gone.
	# Why: docs/why/TransferTest.md#reveal-order
	var w3 := Run.new_wreck(_node, DB.enemies[&"cutter"])
	for k in 3:
		w3.items.append(LootGen.roll_module(2 + k))
	var rv := TransferView.new()
	_tree.root.add_child(rv)
	rv.setup(w3, _node, func() -> void: pass)
	await _tree.process_frame
	var g: SalvageGrid = rv._loose
	_ok("on opening nothing is shown yet (%d of %d)" % [_icons(g), g._items.size()],
		g.revealing() and _icons(g) == 0)
	var first: Array = []
	g.revealed.connect(func(m: HoldItem, _i: int) -> void: first.append([m, _icons(g)]))
	var t0 := Time.get_ticks_msec()
	while first.is_empty() and Time.get_ticks_msec() - t0 < 5000:
		await _tree.process_frame
	var want: HoldItem = g._order[0] if not g._order.is_empty() else null
	var top_left := Vector2i(99, 99)
	for m in g._order:
		var at: Vector2i = g._at[m]
		if at.y < top_left.y or (at.y == top_left.y and at.x < top_left.x):
			top_left = at
	_ok("the first to land is the top-left one, alone (%s at %s, %d shown)"
		% [first[0][0].name if not first.is_empty() else "none", g._at.get(want, -Vector2i.ONE), first[0][1] if not first.is_empty() else -1],
		not first.is_empty() and first[0][0] == want and g._at[want] == top_left and int(first[0][1]) == 1)
	_ok("and the next is still hidden", g._order.size() < 2 or not g.shown(g._order[1]))
	rv.queue_free()
	await _tree.process_frame
	# reduced motion: the same turns, each a plain fade, no prism (Jon, Nov 18: "YES")
	var was_calm := DisplaySettings.reduced_motion
	DisplaySettings.reduced_motion = true
	w3.scanned = false
	var rc := TransferView.new()
	_tree.root.add_child(rc)
	rc.setup(w3, _node, func() -> void: pass)
	var gc: SalvageGrid = rc._loose
	var fading := -1.0
	t0 = Time.get_ticks_msec()
	while fading < 0.0 and Time.get_ticks_msec() - t0 < 5000:
		await _tree.process_frame
		for c in gc.get_children():
			if c is ItemIcon and (c as ItemIcon).held_item() == gc._order[0] and (c as Control).visible 					and (c as Control).modulate.a > 0.05 and (c as Control).modulate.a < 0.95:
				fading = (c as Control).modulate.a
	_ok("with reduced motion the first fades in (seen at %.2f) and nothing else is drawn for it" % fading,
		fading > 0.0 and gc._fx == null)
	DisplaySettings.reduced_motion = was_calm
	rc.queue_free()
	_node.jetsam.erase(w3)
	await _tree.process_frame

	# --- the sweep is a first-visit thing ------------------------------------
	# Opening a container sweeps it once; reopening the same one is not discovery.
	wreck.scanned = false
	var open_a := TransferView.new()
	_tree.root.add_child(open_a)
	open_a.setup(wreck, _node, func() -> void: pass)
	await _tree.process_frame
	_ok("the first open reveals", open_a._loose.revealing())
	_ok("and the container remembers it", wreck.scanned)
	open_a.queue_free()

	var open_b := TransferView.new()
	_tree.root.add_child(open_b)
	open_b.setup(wreck, _node, func() -> void: pass)
	await _tree.process_frame
	_ok("the second open does not", not open_b._loose.revealing())
	_ok("and everything is visible straight away",
		_icons(open_b._loose) == open_b._loose._items.size())
	open_b.queue_free()
	await _tree.process_frame

	# --- the popup does not change shape -------------------------------------
	# The six-row floor is gone, not the ruling: size is measured once when the container arrives.
	# Why: docs/why/TransferTest.md#popup-shape
	var frame := _view._loose.get_parent() as Control
	await _tree.process_frame
	var shape_now := frame.size

	for _pad in 40:
		wreck.items.append(MaterialData.of(MaterialTable.all()[0]))
	_view.refresh()
	await _tree.process_frame
	await _tree.process_frame
	_ok("stuffing the container does not resize it (%s vs %s)"
		% [frame.size, shape_now], frame.size == shape_now)

	wreck.items.clear()
	_node.taken.clear()
	_view.refresh()
	await _tree.process_frame
	await _tree.process_frame
	_ok("emptying it does not resize it either (%s vs %s)"
		% [frame.size, shape_now], frame.size == shape_now)
	var rows := int(frame.size.y) / HoldGrid.CELL
	_ok("and it is between two and six rows, fitted when it opened (%d rows)"
		% rows, rows >= 2 and rows <= TransferView.PANEL_ROWS)

	_finish()


## How many items this grid is actually drawing.
func _icons(g: Control) -> int:
	var n := 0
	for c in g.get_children():
		if c is ItemIcon and (c as Control).visible:
			n += 1
	return n


func _first_icon(g: Control) -> ItemIcon:
	for c in g.get_children():
		var ic := c as ItemIcon
		if ic != null and ic.visible:
			return ic
	return null


func _find_icon(g: Control, m: HoldItem) -> ItemIcon:
	for c in g.get_children():
		var ic := c as ItemIcon
		if ic != null and ic.held_item() == m:
			return ic
	return null


func _finish() -> void:
	if _view != null and is_instance_valid(_view):
		_view.queue_free()
	verdict("transfertest")
	_tree.quit()
