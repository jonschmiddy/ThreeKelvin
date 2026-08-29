extends Harness

## The container, checked on what is DRAWN rather than on what is true.
##
## THIS IS THE TEST THAT SHOULD HAVE EXISTED FOUR ROUNDS AGO. The same bug was
## reported three times with three different triggers -- a drop into the
## container, a right-click, and a drag that appeared to be refused -- and every
## time the report was some version of "it will not move, then it appears out
## there when I do something else". Every time, the model was already correct:
## the item had left the hold, entered the bag, and the SCREEN had not been told.
## The something else was only ever the first redraw.
##
## Every probe written to chase it asserted on `Run.cargo` and `n.bag`, which is
## exactly the half that was never broken. So this one refuses to look at them.
## It counts ICONS, because an icon is what a player can see, and a view that
## agrees with the model is the only claim worth making here.
##
## Headless, on purpose. `-- sectorshot transfer` photographs this screen and
## needs a window; this needs no pixels, only the tree, so it can sit in the
## merge gate where a regression gets caught by a machine rather than by
## somebody playing.

var _tree: SceneTree
var _view: TransferView
var _node: MapGen.MapNode


func run(tree: SceneTree) -> void:
	_tree = tree
	await tree.process_frame

	Rng.reseed(4242, 0)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	_node = Run.node_at()
	_node.bag.clear()
	_node.taken.clear()
	Run.cargo.clear()

	# Something in the hold and something on the floor, which is the only state
	# this screen exists for.
	var mine := LootGen.roll_module(3)
	if not _ok("a part goes in the hold", Run.place_in_hold(mine)):
		return _finish()
	_node.bag.append(LootGen.roll_module(3))
	_node.bag.append(MaterialData.of(MaterialTable.all()[0]))
	_node.bagged = true

	_view = TransferView.new()
	tree.root.add_child(_view)
	# No sweep: this harness counts what is VISIBLE, and a reveal in progress
	# would have it measuring an empty container and reporting a bug.
	_view.setup("SALVAGE", _node, func() -> void: pass, false)
	await tree.process_frame
	await tree.process_frame

	var hold0 := _icons(_view._hold)
	var out0 := _icons(_view._loose)
	if not _ok("the view draws one in the hold and two out here (%d, %d)"
			% [hold0, out0], hold0 == 1 and out0 == 2):
		return _finish()

	# --- a drop into the container -------------------------------------------
	#
	# Driven at the grid, and then NOTHING is refreshed by hand. That is the
	# whole assertion: the screen has to redraw itself.
	var payload := {module = mine, origin = &"cargo"}
	_ok("the container accepts one of yours",
		_view._loose._can_drop_data(Vector2(20, 20), payload))
	_view._loose._drop_data(Vector2(20, 20), payload)
	await tree.process_frame
	_ok("and the hold stops drawing it (%d)" % _icons(_view._hold),
		_icons(_view._hold) == hold0 - 1)
	_ok("and it is drawn out here instead (%d)" % _icons(_view._loose),
		_icons(_view._loose) == out0 + 1)

	# --- and a right-click, which goes through no drop handler at all --------
	# `n.bag` is untyped, so the element needs saying out loud.
	var back: HoldItem = _node.bag[0]
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
	_ok("right-click takes it out of the hold's picture (%d -> %d)"
		% [hold1, _icons(_view._hold)], _icons(_view._hold) == hold1 - 1)

	# --- shift-click, the other way ------------------------------------------
	#
	# The mirror of right-click, and it goes through no drop handler either.
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
	var first: HoldItem = _node.bag[0]
	var i := _node.bag.find(first)
	if i >= 0 and Run.has_room_for(first):
		await Run.take_from_bag(_node, i)
		await tree.process_frame
		var moved := 0
		for k2 in _view._loose._at:
			if where.has(k2) and where[k2] != _view._loose._at[k2]:
				moved += 1
		_ok("nothing else in the pile moved (%d)" % moved, moved == 0)
		_ok("and the container did not shrink (%d -> %d)"
			% [tall, _view._loose._rows], _view._loose._rows >= tall)

	# --- the sweep is a first-visit thing ------------------------------------
	#
	# Opening a container sweeps it; opening the SAME one again does not. A
	# wreck you have already been through is not being discovered, and replaying
	# the reveal would say it was.
	_node.scanned = false
	var open_a := TransferView.new()
	_tree.root.add_child(open_a)
	open_a.setup("SALVAGE", _node, func() -> void: pass)
	await _tree.process_frame
	_ok("the first open sweeps (%.0f)" % open_a._loose._scan,
		open_a._loose._scan >= 0.0)
	_ok("and the node remembers it", _node.scanned)
	open_a.queue_free()

	var open_b := TransferView.new()
	_tree.root.add_child(open_b)
	open_b.setup("SALVAGE", _node, func() -> void: pass)
	await _tree.process_frame
	_ok("the second open does not (%.0f)" % open_b._loose._scan,
		open_b._loose._scan < 0.0)
	_ok("and everything is visible straight away",
		_icons(open_b._loose) == open_b._loose._items.size())
	open_b.queue_free()
	await _tree.process_frame

	# --- the popup does not change shape -------------------------------------
	#
	# It used to size itself to its contents, so filling the container grew it,
	# emptying it shrank it, and a scrollbar appearing made it wider -- a window
	# that moves while you are working in it. Three states, one size: as it
	# stands, stuffed past scrolling, and stripped bare.
	var frame := _view._loose.get_parent() as Control
	await _tree.process_frame
	var shape_now := frame.size

	for _pad in 40:
		_node.bag.append(MaterialData.of(MaterialTable.all()[0]))
	_view.refresh()
	await _tree.process_frame
	await _tree.process_frame
	_ok("stuffing the container does not resize it (%s vs %s)"
		% [frame.size, shape_now], frame.size == shape_now)

	_node.bag.clear()
	_node.taken.clear()
	_view.refresh()
	await _tree.process_frame
	await _tree.process_frame
	_ok("emptying it does not resize it either (%s vs %s)"
		% [frame.size, shape_now], frame.size == shape_now)
	_ok("and it is six rows tall (%s)" % frame.size,
		int(frame.size.y) == TransferView.PANEL_ROWS * HoldGrid.CELL)

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
