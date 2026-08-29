class_name TransferView
extends PanelContainer

## Your hold on the left, what is out there on the right, and a drag between.
##
## `MATERIALS_NOTE` 3.6: if something hands you a physical item, it hands you a
## CONTAINER, not the item. A kill fills one, an event pays out into one, and
## whatever you throw overboard lands in one. This is the screen for all of them,
## built once, so a wreck and a windfall are the same gesture.
##
## The reason it is one screen rather than three is 3.4. Nothing may be destroyed
## for you, which means no payout can ever force itself into a full hold -- so
## every payout has to be a place you reach into rather than a thing that
## arrives, and every one of them needs your hold visible beside it to reach
## from. Once that is true for one of them it is cheaper to make it true for all.
##
## BOTH DIRECTIONS ARE ONE GESTURE. Right to left is taking; left to right is
## jettison, which the ruling already defines as putting something down in the
## system you are standing in. They are the same motion because they are the same
## idea -- this is your ship, that is the floor.

const PAD := 24

var _hold: HoldGrid
var _loose: SalvageGrid
var _title: Label
var _count: Label
var _node: MapGen.MapNode = null
var _busy: bool = false
var _on_close: Callable


## `title` names the container -- SALVAGE, the wreck's name, whatever handed it
## to you. `n` is the system whose bag this is.
func setup(title: String, n: MapGen.MapNode, on_close: Callable) -> void:
	_node = n
	_on_close = on_close
	_title.text = title
	refresh()


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_theme_stylebox_override("panel",
		UITheme.flat(Color(0.031, 0.043, 0.067, 0.97), Color(0, 0, 0, 0), 0,
			PAD, PAD))
	# STOP, so nothing behind this can be clicked through it.
	mouse_filter = Control.MOUSE_FILTER_STOP

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	col.add_child(head)
	_title = UITheme.body("", UITheme.ICE, UITheme.FS_HEAD)
	head.add_child(_title)
	_count = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_count)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	head.add_child(Widgets.button("DONE", func() -> void:
		if _on_close.is_valid():
			_on_close.call()))

	# CENTRED, both ways. Two grids pinned to the top-left of a 960x540 screen
	# leave most of the panel as dead space and read as a dialog that failed to
	# lay out rather than as a place you are standing.
	var mid := CenterContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(mid)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_child(row)

	# YOUR SHIP ON THE LEFT, always, matching the encounter view. Which side a
	# thing is on is how you know whose it is, and that has to be the same
	# answer everywhere or it is not a convention.
	row.add_child(_side("YOUR HOLD", _build_hold()))
	row.add_child(_side("OUT HERE", _build_loose()))


func _side(label: String, body: Control) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var l := UITheme.body(label, UITheme.COLD, UITheme.FS_SMALL)
	box.add_child(l)
	# A CAP, not a fill. Both grids are exactly as big as their contents need,
	# and a scroll only appears when a pile outgrows the screen -- which is the
	# rare case, and the one where a fixed box would hide the last row.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, mini(360, 8 * HoldGrid.CELL))
	scroll.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	scroll.add_child(body)
	box.add_child(scroll)
	return box


func _build_hold() -> Control:
	_hold = HoldGrid.new()
	_hold.dropped.connect(_on_hold_drop)
	return _hold


func _build_loose() -> Control:
	_loose = SalvageGrid.new()
	return _loose


func refresh() -> void:
	if _node == null:
		return
	_hold.refresh()
	# The spent set is `n.taken`, translated back into indices of `n.bag`.
	var spent: Dictionary = {}
	for i in _node.bag.size():
		if _node.taken.has(MapGen.OPTION_BAG + i):
			spent[i] = true
	_loose.setup(_node.bag, spent, 5)
	var left := Run.bag_left(_node)
	_count.text = "%d LEFT" % left if left > 0 else "PICKED CLEAN"


## Something dragged INTO your hold.
##
## Two sources, and they cost different things. A part already in your cargo is
## being rearranged and is free. A part out of the bag has to be CLAIMED first --
## one bag, first hand in -- and the claim is a round trip in a party, which is
## why this awaits and why it refuses to run twice at once.
func _on_hold_drop(payload: Dictionary, at: Vector2i) -> void:
	var m: HoldItem = payload.get("module")
	if m == null or _busy:
		return
	if String(payload.get("origin", &"")) != "bag":
		# Yours already, so this is a rearrangement and it is free.
		#
		# ASKED BEFORE IT IS LIFTED. The first version took the item out of the
		# hold, tried the new cell, and put it back on failure -- which is one
		# `place_in_hold` away from losing it outright if BOTH calls refuse.
		# 3.4 does not allow a move to cost you the thing being moved, so the
		# question is answered while the item is still safely where it was.
		if m.hold_at != at and not Run.can_place(m, at):
			return
		var was := m.hold_at
		Run.take_from_hold(m)
		if not Run.place_in_hold(m, at) and not Run.place_in_hold(m, was):
			# Cannot happen -- the cell was checked a line ago and the old one
			# is definitionally free. If it ever does, the item goes back in the
			# hold somewhere rather than nowhere.
			Run.place_in_hold(m)
		refresh()
		return
	var i := _loose.index_of(m)
	if i < 0:
		return
	# ASKED BEFORE IT IS PLACED, and the order matters: `take_from_bag` checks
	# the hold has room BEFORE it spends the claim, so a full hold costs you
	# nothing. See its own note.
	_busy = true
	refresh()
	var got: bool = await Run.take_from_bag(_node, i)
	_busy = false
	if got:
		# It landed wherever the hold had room. Move it to the cell actually
		# aimed at, if that cell will still take it -- a drop is a decision about
		# WHERE, and silently ignoring the half of it you can honour is worse
		# than not offering the choice.
		if Run.can_place(m, at) or m.hold_at == at:
			Run.take_from_hold(m)
			if not Run.place_in_hold(m, at):
				Run.place_in_hold(m)
		# QUIET, and pitched down. `loot_drop` is written as a reward sting and
		# it is the wrong instrument here: taking a crate off the floor is a
		# thing you do six times in a system, and a fanfare on each one turns
		# packing a hold into a slot machine paying out. The same cue at a
		# fraction of the volume and below its written pitch reads as the object
		# arriving rather than as you winning.
		Audio.play(&"loot_drop", -12.0, 70)
	refresh()
