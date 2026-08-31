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

## HOW TALL BOTH GRIDS ARE, in cells, whatever is in them.
##
## The popup used to size itself to its contents, which meant every change of
## contents changed its shape: fill the container and it grew, empty it and it
## shrank, and the moment a scrollbar appeared it got wider and everything
## jumped sideways. A window that moves while you are working in it is worse
## than one that is occasionally too big.
##
## Six rows fits a heavy hull's five with a row spare, and is the most a pile
## shows before it scrolls instead of growing.
const PANEL_ROWS := 6

## Room kept for a scrollbar whether or not there is one.
##
## Godot gives a ScrollContainer its bar out of the child's width, so the frame
## has to be wider than the grid by this much or the grid loses a column the
## instant the pile outgrows the view -- which is exactly when you least want
## the layout moving.
const BAR := 14

var _hold: HoldGrid
var _loose: SalvageGrid
var _title: Label
## The heading over the right-hand grid. It names the container rather than the
## direction: "OUT HERE" was a placeholder from when there was one bag per
## system and it read as a compass rather than as a thing.
var _loose_label: Label
var _node: MapGen.MapNode = null
## WHICH container. A system holds several -- one per hull you killed, plus its
## own floor -- and this screen is a view of exactly one of them at a time.
var _jetsam: MapGen.Jetsam = null
var _busy: bool = false
var _on_close: Callable


## `title` names the container -- SALVAGE, the wreck's name, whatever handed it
## to you. `n` is the system whose bag this is.
## `animate` is off for the harness, which counts VISIBLE icons -- a sweep in
## progress would have it measuring an empty container and calling it a bug.
##
## `title` OVERRIDES the container's own word, and exists for exactly one case:
## the instant an event resolution hands you something. See `Jetsam.title` --
## the pile is the system's floor either way, and PRIZE is a fact about the
## moment you are standing in rather than about the crate.
func setup(h: MapGen.Jetsam, n: MapGen.MapNode, on_close: Callable,
		animate: bool = true, title: String = "") -> void:
	_node = n
	_jetsam = h
	_on_close = on_close
	# WHAT IT IS, THEN WHOSE. The heading was the ship's name and the column
	# said SALVAGE, which read as a screen about the Rustjaw Cutter that
	# happened to contain salvage -- when it is a salvage screen that happens to
	# be about a Rustjaw Cutter. The name belongs over the grid it names.
	#
	# AND IT ASKS THE CONTAINER, because the heading was a constant and there is
	# more than one kind of pile. See `MapGen.Jetsam.title`.
	if title != "":
		_title.text = title
	else:
		_title.text = h.title() if h != null else "JETSAM"
	refresh()
	# ONCE PER CONTAINER. The sweep is what OPENING something looks like, and a
	# wreck you have already been through is not being opened -- replaying it
	# every visit would make walking back to a half-stripped pile feel like
	# finding it again, which is the one thing it must not say.
	# PER CONTAINER, not per system. Three wrecks in one sector are three
	# things found, and the second should sweep exactly as the first did.
	if animate and h != null and not h.scanned:
		h.scanned = true
		_loose.scan()
	else:
		_loose.skip_scan()


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# THE BACKDROP, and it is only a backdrop now.
	#
	# This used to be the whole screen: an opaque full-rect panel with the grids
	# laid out directly on it. That reads as a MODE -- the sector is gone and you
	# are somewhere else -- when the thing it describes is a crate on the floor
	# twenty metres away. Dimmed rather than replaced, so the system you are
	# standing in is still visibly there behind what you are sorting.
	#
	# Still STOP, and that has not changed for a reason: nothing behind may be
	# clicked through it, and a drop that misses both grids still has to land
	# somewhere that knows what to do with it.
	add_theme_stylebox_override("panel",
		UITheme.flat(Color(0.031, 0.043, 0.067, 0.72), Color(0, 0, 0, 0), 0,
			PAD, PAD))
	mouse_filter = Control.MOUSE_FILTER_STOP

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)

	# THE POPUP ITSELF. Sized to what is in it rather than to the window, with
	# an edge, so it reads as an object on top of the sector.
	#
	# IGNORE, not STOP: the frame is decoration and must not become a drop
	# target. Its children still receive everything -- the grids and their icons
	# are what answer a drop -- and anything that misses them falls through to
	# the backdrop, which is this view's own catch-all. A STOP frame would eat
	# exactly the drops that are currently reaching it.
	var popup := PanelContainer.new()
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.add_theme_stylebox_override("panel",
		UITheme.flat(UITheme.PANEL2, UITheme.LINE, 0, 16, 18))
	centre.add_child(popup)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	popup.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	col.add_child(head)
	_title = UITheme.body("", UITheme.ICE, UITheme.FS_HEAD)
	head.add_child(_title)
	# NO RUNNING TOTAL. "2 LEFT" and "PICKED CLEAN" were counting something you
	# are looking at: the grid on the right IS the answer, and a number beside
	# the name only competes with it. An empty container says it is empty by
	# being empty.
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	head.add_child(Widgets.button("DONE", func() -> void:
		if _on_close.is_valid():
			_on_close.call()))

	# NO CENTRING LAYER ANY MORE. The popup is the size of what is in it and
	# the popup is centred, so a second centring inside it was two answers to
	# one question -- and it was what made the grids sit in the corner of a
	# window-sized panel when this was full screen.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)

	# LISTEN TO THE MODEL, NOT TO EACH THING THAT CHANGES IT.
	#
	# This is the second time the same bug has been reported with a different
	# trigger. First a drop into the container moved the item and left it drawn
	# where it had been; now a RIGHT-CLICK does -- `Run.jettison` runs, the item
	# leaves the hold, and the screen carries on showing it until the next
	# action forces a repaint. Both times the symptom was "it goes back, then
	# reappears out here when I do something else", and both times the something
	# else was just the first redraw.
	#
	# Wiring the second trigger would leave a third. `ship_changed` is what
	# every one of them already emits -- jettison, stow, place, take -- so the
	# view now redraws because the SHIP changed, whatever did it.
	#
	# The `picked` connection above stays. It is redundant with this and it is
	# known to work, and while this screen is being hammered on I would rather
	# have two things agreeing than one clever one.
	Sig.ship_changed.connect(_on_ship_changed)

	# YOUR SHIP ON THE LEFT, always, matching the encounter view. Which side a
	# thing is on is how you know whose it is, and that has to be the same
	# answer everywhere or it is not a convention.
	# The hold's width is the hull's; the container's is its own constant. Both
	# are known before anything is in them, which is the point.
	row.add_child(_side("YOUR HOLD", _build_hold(), Run.hold_grid().x))
	# Empty, because the container names itself on refresh. See `_loose_label`.
	row.add_child(_side("", _build_loose(), SalvageGrid.COLS))


## THE SCREEN ITSELF CATCHES ANYTHING THE GRIDS DID NOT.
##
## `SalvageGrid` has its own `_can_drop_data` and it is correct -- driven
## directly it accepts the payload and moves the item every time. What could not
## be established is whether Godot ever ASKS it: hit-testing a drop through a
## scroll container, past PASS-filtered icons, onto a control that is one of
## several stacked full-rect siblings has too many places to fail quietly, and
## the harness cannot answer it either -- an unfocused window does not track a
## warped cursor, so simulated input measures itself rather than the game.
##
## So the decision moves to the one control that cannot be missed. This panel is
## topmost, covers everything, and is `MOUSE_FILTER_STOP`; a drop that reaches
## it is a drop the grids declined. Which side you let go over is then plain
## arithmetic on the x, which needs no hit-testing to be right.
##
## The grid keeps its own handler. Two answers to one question is not ideal, but
## they agree, and the alternative is removing the one that demonstrably works
## in favour of the one that may not be reached.
func _can_drop_data(at: Vector2, data: Variant) -> bool:
	return _side_of(at, data) != 0



## The take, by what it is. The ruling below stands -- packing is not a
## payout -- so every tier shares one dry handling layer and rarity only
## adds a small ring: common is hands, rare rings once, EPIC and up
## shimmer quietly, and credits are coins because they are coins.
static func _take_sound(m: HoldItem) -> StringName:
	if m is CreditChit:
		return &"take_credits"
	var mod := m as ModuleData
	if mod == null:
		return &"take_common"
	match mod.rarity:
		ModuleData.Rarity.COMMON, ModuleData.Rarity.UNCOMMON:
			return &"take_common"
		ModuleData.Rarity.RARE:
			return &"take_rare"
		ModuleData.Rarity.EPIC:
			return &"take_epic"
		ModuleData.Rarity.LEGENDARY:
			return &"take_legendary"
		ModuleData.Rarity.EXOTIC:
			return &"take_exotic"
		_:
			return &"take_artifact"

func _drop_data(at: Vector2, data: Variant) -> void:
	var where := _side_of(at, data)
	var m: HoldItem = (data as Dictionary).module
	if where < 0:
		# Onto your own side, from out there: the same claim `_on_hold_drop`
		# makes, aimed at wherever the hold has room.
		var i := _jetsam.items.find(m)
		if i >= 0 and not _busy:
			_busy = true
			var got: bool = await Run.take_from_jetsam(_node, _jetsam, i)
			_busy = false
			if got:
				# The resource watcher would answer the same take with the
				# flat loot_drop / scrap_gain a frame later. This sound IS
				# that sound, better informed -- hold their tongues.
				Audio.suppress(&"loot_drop")
				Audio.suppress(&"scrap_gain")
				Audio.play(_take_sound(m), 0.05, 70, -4.0)
	elif where > 0 and Run.put_in(_node, _jetsam, m):
		pass
	refresh()


## -1 for your hold, +1 for out here, 0 for a drop that means nothing.
##
## The halves are decided by the grids' own rects rather than by the middle of
## the screen, so the answer stays right when either side changes size.
func _side_of(at: Vector2, data: Variant) -> int:
	if typeof(data) != TYPE_DICTIONARY or not (data as Dictionary).has("module"):
		return 0
	var m: HoldItem = (data as Dictionary).module
	if m == null or _node == null:
		return 0
	var from_bag := String((data as Dictionary).get("origin", &"")) == "bag"
	var split := (_hold.get_global_rect().end.x
		+ _loose.get_global_rect().position.x) * 0.5
	var out_here := get_global_position().x + at.x >= split
	if out_here:
		# Only your own things can be put down, and only once.
		return 1 if (not from_bag and Run.cargo.has(m)) else 0
	return -1 if from_bag else 0


## R TURNS WHAT YOU ARE CARRYING.
##
## The refit screen has had this since the hold became a grid, and this screen
## had none of it -- so a 4x1 that would only fit standing up could be seen not
## fitting and not be turned. Packing is the whole game of a hold; a view you
## pack in and cannot rotate in is a worse version of the one next door.
##
## Deliberately only the carried item. `ShipScreen` also turns a part sitting in
## the hold under the pointer, which is a second verb on a second target -- worth
## having there, and not worth two ways to do it here while this screen is young.
func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or k.keycode != KEY_R:
		return
	var carried: Variant = get_viewport().gui_get_drag_data()
	if typeof(carried) != TYPE_DICTIONARY \
			or not (carried as Dictionary).has("module"):
		return
	var m: HoldItem = (carried as Dictionary).module
	if m == null:
		return
	m.turned = not m.turned
	# The plate in your hand has to change shape too, or you are aiming a 4x1
	# while holding a picture of a 1x4.
	if ItemIcon.carried != null and is_instance_valid(ItemIcon.carried):
		ItemIcon.carried.fit_footprint()
		ItemIcon.carried.spin()
	get_viewport().set_input_as_handled()


## Redraw because something happened to the ship, whatever it was.
##
## Guarded on being in the tree: the signal outlives a closed view by however
## long the free takes, and refreshing a torn-down panel is a crash rather than
## a wasted frame.
func _on_ship_changed() -> void:
	if is_inside_tree() and _node != null:
		refresh()


func _side(label: String, body: Control, cols: int) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var l := UITheme.body(label, UITheme.COLD, UITheme.FS_SMALL)
	if label == "":
		_loose_label = l
	box.add_child(l)
	# A CAP, not a fill. Both grids are exactly as big as their contents need,
	# and a scroll only appears when a pile outgrows the screen -- which is the
	# rare case, and the one where a fixed box would hide the last row.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# FIXED, HERE, ONCE. `custom_minimum_size` is a floor -- this file has
	# already got that wrong once and clipped both grids to two rows -- so
	# setting it and never touching it again is what makes the popup one shape.
	# Nothing about the contents may reach this number.
	scroll.custom_minimum_size = Vector2(cols * HoldGrid.CELL + BAR,
		PANEL_ROWS * HoldGrid.CELL)
	scroll.size_flags_vertical = Control.SIZE_FILL
	scroll.add_child(body)
	box.add_child(scroll)
	return box


func _build_hold() -> Control:
	_hold = HoldGrid.new()
	_hold.dropped.connect(_on_hold_drop)
	return _hold


func _build_loose() -> Control:
	_loose = SalvageGrid.new()
	# THIS LINE IS THE WHOLE BUG. `SalvageGrid` jettisons on a drop and then
	# announces it -- and nothing was listening, so the model changed and the
	# screen did not. The item left your hold, went into the bag, and carried on
	# being drawn where it had been.
	#
	# Which is exactly what it looked like from outside: drop it out here and it
	# "goes back", then move anything else and the earlier one is suddenly out
	# there. The second action was not moving it. It was the first refresh since
	# it moved.
	#
	# The hold has to redraw too, not just the container, which is why this is
	# the view's refresh rather than the grid's own.
	_loose.picked.connect(func(_m: HoldItem) -> void: refresh())
	# INTO THE CONTAINER ON SCREEN. See `RunState.put_in`: with a wreck open,
	# dropping something in must put it in that hull rather than on the floor,
	# or the screen is lying about what it is showing.
	_loose.on_put = func(m: HoldItem) -> bool:
		return Run.put_in(_node, _jetsam, m)
	# FILLS ITS SIDE OF THE POPUP. It keeps the spare row `_layout` adds, so
	# there is always somewhere to put a thing down, and it stretches to
	# whichever side of the popup is taller so the two grids read as one pair
	# rather than as two objects of different heights.
	_loose.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_loose.size_flags_vertical = Control.SIZE_FILL
	return _loose


func refresh() -> void:
	if _node == null or _jetsam == null:
		return
	_hold.refresh()
	# SOMEBODY ELSE'S CLAIMS, not every claim.
	#
	# A taken entry is kept on screen greyed, because in a party a part with
	# somebody's name on it is the texture of flying together -- a part that
	# simply vanished would read as one that was never there.
	#
	# None of that is true of your OWN take. Alone, the greyed leftover sits in
	# the container next to the same object now in your hold, which reads as the
	# thing not having moved. So a claim with no other name on it leaves nothing
	# behind: it is in your hold, and that is where it is.
	var spent: Dictionary = {}
	for i in _jetsam.items.size():
		if not _node.taken.has(_jetsam.option(i)):
			continue
		if Net.taker_name(_node.index, _jetsam.option(i)) != "":
			spent[i] = true
	# What is still out here, plus whatever somebody else is holding. Your own
	# claims are gone from the list entirely -- see `spent` above.
	var showing: Array = []
	var showing_spent: Dictionary = {}
	for i in _jetsam.items.size():
		if _node.taken.has(_jetsam.option(i)) and not spent.has(i):
			continue
		if spent.has(i):
			showing_spent[showing.size()] = true
		showing.append(_jetsam.items[i])
	_loose.setup(showing, showing_spent, 5)
	_loose_label.text = _jetsam.label if _jetsam != null else "SECTOR LOOT"


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
	# THE BAG'S INDEX, not the grid's. The grid shows a filtered list now, so
	# its positions and `n.bag`'s stopped agreeing -- and `take_from_bag` claims
	# by index, which is exactly the kind of mismatch that claims the wrong thing
	# rather than failing.
	var i := _jetsam.items.find(m)
	if i < 0:
		return
	# ASKED BEFORE IT IS PLACED, and the order matters: `take_from_bag` checks
	# the hold has room BEFORE it spends the claim, so a full hold costs you
	# nothing. See its own note.
	_busy = true
	refresh()
	var got: bool = await Run.take_from_jetsam(_node, _jetsam, i)
	_busy = false
	if got:
		# It landed wherever the hold had room. Move it to the cell actually
		# aimed at, if that cell will still take it -- a drop is a decision about
		# WHERE, and silently ignoring the half of it you can honour is worse
		# than not offering the choice.
		# NOT MONEY. `stow` cashed a chit and did NOT put it in the hold, and
		# then this put it there anyway to honour the cell you aimed at -- so
		# it sat in cargo occupying cells that nothing could be dropped into,
		# and `HoldGrid` draws no icon for one, so the space was invisible.
		#
		# A chit has already landed by the time we are here. There is nothing
		# left to place.
		if not (m is CreditChit) and (Run.can_place(m, at) or m.hold_at == at):
			Run.take_from_hold(m)
			if not Run.place_in_hold(m, at):
				Run.place_in_hold(m)
		# A DIFFERENT SOUND, not the same one turned down.
		#
		# `loot_drop` is a reward sting and the problem with it here is its
		# CHARACTER, not its level: taking a crate off the floor is something
		# you do six times in a system, and a fanfare on each one turns packing
		# a hold into a slot machine paying out. `module_install` is the sound
		# of a part being handled -- mechanical, over quickly, no arrival in it.
		#
		# Down four anyway, and rate-limited, because a fast hand emptying a
		# bag fires this several times in a second and even a dry sound stacks.
		Audio.suppress(&"loot_drop")
		Audio.suppress(&"scrap_gain")
		Audio.play(_take_sound(m), 0.05, 70, -4.0)
	refresh()
