class_name TransferScreen
extends Control

## Moving day. Two ships, and everything you own between them.
##
## THE ONE SCREEN THAT DRAWS TWO HULLS AT ONCE, and it exists because a hull
## swap is the only moment in the game where you are choosing between objects
## you already own rather than deciding whether to acquire one. The Yard asks
## "do you want this ship"; this asks "which of your things come with you", and
## those are different questions on different screens.
##
## THE PURCHASE IS ALREADY FINAL when you arrive. There is no way back to the
## old frame -- it has been traded in, the credits have moved, and `Run.hull` is
## the new one. What is drawn on the left is the loading dock: your old hold,
## with whatever has not crossed yet still sitting in the cells it sat in.
##
## An earlier version of this was a STRIP under the hold on the refit screen.
## It worked and it was wrong: a strip says "here is some overflow", and the
## thing actually happening is that you are standing between two ships deciding
## what your run is going to be made of. Two grids facing each other say that;
## a caption under a widget does not.

## FULL SIZE, and the room for it comes from the screen having nothing else on
## it. The berth on the station rail draws at a half because it is a thumbnail
## in a 150-wide column; here each ship has 450 of width and this is the last
## time you will ever see the old one. A heavy is about 340 across at 1x, which
## clears that with room, so the halving the rail needs would be shrinking these
## for no reason but symmetry with a widget that is not on this page.
const SHIP_K := 1.0
const SHIP_H := 132
const COL_W := 300

var _oldmounts: Label
var _newmounts: Label
var _oldpts: MountPoints
var _oldview: ShipView
var _newpts: MountPoints
var _old: OldHold
var _new: HoldGrid
var _oldhead: Label
var _newhead: Label
var _money: Label
var _done: Button
var _back: Button
var _lifted: ModuleData = null
var _lifted_mount: int = -1
var _sell: Button

func setup() -> void:
	# ANCHORS **AND OFFSETS**. `set_anchors_preset` alone leaves the offsets
	# where they were, so the screen anchored to all four sides of a parent it
	# had no size inside of -- and every container under it collapsed to its
	# own content, which put a whole page in the top third and gave the two
	# hold grids no height at all to draw in. Every other screen in this game
	# uses the `_and_offsets_` spelling; this one now does too.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var frame := MarginContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_constant_override("margin_left", 16)
	frame.add_theme_constant_override("margin_right", 16)
	frame.add_theme_constant_override("margin_top", 12)
	frame.add_theme_constant_override("margin_bottom", 12)
	add_child(frame)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 6)
	frame.add_child(page)

	page.add_child(UITheme.body("MOVING ABOARD", UITheme.COLD, UITheme.FS_SMALL))
	page.add_child(UITheme.body(Run.hull.display_name().to_upper(),
		DB.manufacturer_colour(Run.hull.manufacturer), UITheme.FS_HEAD))
	page.add_child(UITheme.hsep())

	# --- THE TWO HOLDS, FACING.
	var pair := HBoxContainer.new()
	pair.add_theme_constant_override("separation", 20)
	pair.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(pair)

	_oldhead = UITheme.body("", UITheme.LEAVE, UITheme.FS_SMALL)
	_old = OldHold.new()
	pair.add_child(_column(Run.old_hull, "THE SHIP YOU ARE LEAVING",
		_oldhead, _old, true))

	# THE ARROW IS THE INSTRUCTION, and it was set in body text at the size of a
	# caption -- eleven pixels of punctuation carrying the only statement on the
	# page about which way things are meant to travel. A player who reads two
	# grids as two unrelated holds will try to drag the wrong way first, and the
	# arrow is the whole of what stops that, so it is drawn rather than typed.
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override("separation", 4)
	mid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mid.add_child(_arrow())
	var carry := UITheme.body("CARRY
ACROSS", UITheme.COLD, UITheme.FS_SMALL)
	carry.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(carry)
	# R IS NOT A KEY ANYBODY FINDS. The refit screen has the same gesture and
	# says so on its own hold; this is the screen where it matters most -- you
	# are packing a smaller hold than the one you came out of -- so it is worth
	# a line under the arrow rather than a thing you have to already know.
	var turn := UITheme.body("R TURNS
F FLIPS", UITheme.QUOTE, UITheme.FS_SMALL)
	turn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(turn)
	pair.add_child(mid)

	_newhead = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	_new = HoldGrid.new()
	_new.dropped.connect(_on_drop)
	pair.add_child(_column(Run.hull, "YOUR NEW SHIP", _newhead, _new, false))

	# --- WHAT TO DO ABOUT THE REST.
	page.add_child(UITheme.hsep())
	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation", 10)
	page.add_child(acts)

	_money = UITheme.body("", UITheme.QUOTE, UITheme.FS_SMALL)
	_money.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_money.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_money.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	acts.add_child(_money)

	# TAKE IT ALL IS ONE CLICK, and it is the button most swaps will use. Moving
	# into a bigger frame strands nothing and moving into an equal one strands
	# little, so the common case must not cost twelve drags to say yes to.
	# THE HATCH, because the status line was already naming it as the only way
	# out of something and this screen did not have one. `Market.bid` answers 0
	# for contraband where contraband does not trade, and CAST OFF is refused
	# while anything is still on the old ship -- so without a bin, one crate of
	# grey coolant at the wrong station was a hard stop with no move available.
	var bin := JettisonBin.new()
	bin.dumped.connect(func(_m: HoldItem) -> void: _refresh())
	bin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	acts.add_child(bin)
	acts.add_child(Widgets.button("TAKE WHAT FITS", _take_all))
	_sell = Widgets.button("SELL THE REST", _sell_rest)
	acts.add_child(_sell)
	# THE WAY OUT, and it is the reason the old frame is still drawn rather than
	# described. A purchase you cannot reverse has to be judged from the Yard,
	# which means judging a ship by its gauges; a purchase you can reverse can be
	# judged from HERE, with both hulls in front of you and your own guns on one
	# of them. The second is a better place to make the decision, so the button
	# that makes it possible earns its width.
	_back = Widgets.button("BACK OUT", _back_out)
	acts.add_child(_back)
	_done = Widgets.button("CAST OFF", _cast_off)
	acts.add_child(_done)

	Sig.ship_changed.connect(_refresh)
	_refresh()


## One ship: what it is, a portrait WITH ITS KIT ON IT, and its hold under it.
##
## `foreign` picks which ship the hardpoints belong to. The left-hand hull is
## not `Run.hull` any more -- the purchase already happened -- so its mounts
## come from `MountPoints.ship`/`fitted` and refuse every drop; the right-hand
## one IS `Run.hull`, so it is the ordinary live widget the refit screen uses
## and a gun dropped on it bolts straight on.
func _column(h: HullData, title: String, head: Label, grid: Control,
		foreign: bool) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	# BOTH HALVES TAKE THE SLACK. Without this the column is as tall as its own
	# content, the ScrollContainer under it gets nothing, and the grid -- which
	# is the entire point of the screen -- draws in zero pixels.
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var cap := HBoxContainer.new()
	cap.add_theme_constant_override("separation", 8)
	cap.add_child(UITheme.body(title, UITheme.COLD, UITheme.FS_SMALL))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.add_child(gap)
	# THE MOUNT COUNT, because this screen is now a place where hardpoints get
	# filled and "3 of 4" is the number you are working against. Live on the
	# right-hand side -- it goes up as you bolt things on -- and a plain total
	# on the left, which only ever goes down.
	if foreign:
		_oldmounts = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
		cap.add_child(_oldmounts)
	else:
		_newmounts = UITheme.body("", UITheme.CHILL, UITheme.FS_SMALL)
		cap.add_child(_newmounts)
	col.add_child(cap)

	col.add_child(UITheme.body(
		h.name.to_upper() if h != null else "—",
		DB.manufacturer_colour(h.manufacturer) if h != null else UITheme.COLD,
		UITheme.FS_HEAD))
	col.add_child(UITheme.body("%s · %s TIER · HAND %d" % [
		HullData.weight_name(h.weight).to_upper(), h.tier_letter(), h.hand_size]
		if h != null else "", UITheme.COLD, UITheme.FS_SMALL))

	col.add_child(_portrait(h, foreign))
	col.add_child(UITheme.hsep())
	col.add_child(head)
	# THE GRID SCROLLS RATHER THAN THE PAGE. A heavy hold is five rows of 40 --
	# more than the room under a full-size hull in a 540-tall window. Scrolling
	# the page instead would move the ships off screen, and the ships are the
	# point.
	var box := ScrollContainer.new()
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(grid)
	col.add_child(box)

	# A PLATE UNDER EACH SHIP, so the page reads as two objects with a gap
	# between them rather than as one field with things scattered on it. It is
	# the same treatment the Yard gives its two hulls, and this is the same
	# comparison one step later.
	var wrap := Widgets.panel_with(Widgets.pad(col, 10, 8))
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return wrap


## The two grids sit at the same height whatever is in them.
##
## THE HOLDS ARE DIFFERENT SHAPES -- a light is 4x3 and a heavy 6x5 -- so left
## and right are rarely the same number of rows, and a container that centred
## each in its own column would put the two lattices at two different heights.
## They are meant to be read across, so they are both pinned to the TOP of the
## space under the portraits and the slack falls below them.


func _portrait(h: HullData, foreign: bool) -> Control:
	# A CENTRE CONTAINER AROUND A STACK THE SHIP'S EXACT SIZE.
	#
	# The first version positioned the hull by hand against `COL_W` and laid the
	# mounts over it at the same offset. Both were wrong the moment the column
	# was allowed to EXPAND: the real width is about 440, so the arithmetic
	# centred the ship in a 300-wide box that was not there -- and the mounts
	# layer, which anchors to its PARENT, ended up over a rectangle the hull was
	# no longer inside. The rings drew, at coordinates nothing was at.
	#
	# Letting a container do the centring and giving the mounts a parent that is
	# exactly the canvas removes both sums and the class of bug they were in.
	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(0, SHIP_H)
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.mouse_filter = Control.MOUSE_FILTER_PASS
	if h == null:
		return holder

	var v := ShipView.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.self_clip = false
	if foreign:
		# THE OLD SHIP, STILL WEARING ITS GUNS. `Run.installed` is empty by now,
		# so the parts come from the pad -- which is where they went, and where
		# they still remember their hardpoints.
		v.setup_build(ShipBuild.fitted_out(h, Run.pad))
	else:
		v.setup_preview(h, 0, 1)

	# THE MOUNTS ARE A CHILD OF THE VIEW, not a sibling in a stack beside it.
	# `attach` anchors them to their PARENT, so parenting them to the ship makes
	# every coordinate they draw the ship's own -- which is what makes
	# `ShipView.canvas_to_local` the single place the bob, the magnification and
	# the centring are reasoned about. The refit screen has always done it this
	# way; a stack was a second set of numbers to keep in step, and it was
	# already out of step with the column's real width.
	v.custom_minimum_size = Vector2(float(v._w), float(v._h))
	holder.add_child(v)

	var pts := MountPoints.new()
	if foreign:
		pts.ship = h
		pts.fitted = Run.pad
	else:
		pts.dropped.connect(_on_mount_drop)
		# OFF THE HULL, INTO THE HAND. Without this pair the part stayed in
		# `Run.installed` for the whole drag -- so unbolting something on the new
		# ship did nothing at all: the mount still read as full, and the hold
		# refused a part it could see was already fitted.
		pts.lifted.connect(_on_lift)
		pts.released.connect(_on_release)
	v.add_child(pts)
	pts.attach(v)
	if foreign:
		_oldpts = pts
		_oldview = v
	else:
		_newpts = pts
	return holder


## The arrow, drawn rather than typed.
##
## `Control` with a `_draw`, because the biggest thing the font can do is a
## 16px glyph and this wants to read from across the screen. Two triangles and
## a shaft in EMBER, the ink this game uses for the thing you are meant to act
## on.
func _arrow() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(58, 46)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void:
		var w := c.size.x
		var midy := c.size.y * 0.5
		var ink := UITheme.EMBER
		c.draw_rect(Rect2(0.0, midy - 3.0, w - 20.0, 6.0), ink)
		c.draw_colored_polygon(PackedVector2Array([
			Vector2(w - 22.0, midy - 13.0),
			Vector2(w, midy),
			Vector2(w - 22.0, midy + 13.0)]), ink))
	return c


func _refresh() -> void:
	_old.refresh()
	_new.refresh()
	# THE OLD SHIP'S PICTURE IS DERIVED, so it has to be rebuilt rather than
	# left alone: a gun that just crossed is no longer in `Run.pad`, and the
	# hull it came off must stop drawing it in the same frame the new hull
	# starts to.
	if _oldpts != null:
		_oldpts.fitted = Run.pad
		if _oldview != null:
			_oldview.setup_build(ShipBuild.fitted_out(Run.old_hull, Run.pad))
		_oldpts.refresh()
	if _newpts != null:
		_newpts.refresh()
	var left := Run.pad.size()
	# BOLTED ON AND STOWED ARE COUNTED APART, because the grid underneath only
	# shows the second kind. A heading reading 16 over twelve visible plates is
	# a heading a player will spend a moment doubting.
	var fitted := _mounted_on_pad()
	if left == 0:
		_oldhead.text = "STRIPPED. NOTHING LEFT ABOARD."
	elif fitted > 0:
		_oldhead.text = "STILL ABOARD — %d FITTED, %d IN THE HOLD" % [
			fitted, left - fitted]
	else:
		_oldhead.text = "STILL ABOARD — %d IN THE HOLD" % left
	_newhead.text = "IN THE HOLD — %d of %d cells · DECK %d" % [Run.cargo_used(),
		Run.cargo_slots(), Run.deck_size()]
	if _oldmounts != null and Run.old_hull != null:
		_oldmounts.text = "FITTED %d" % _mounted_on_pad()
	if _newmounts != null:
		_newmounts.text = "FITTED %d OF %d" % [Run.installed.size(),
			Run.slots_for(ModuleData.Slot.WEAPON)
			+ Run.slots_for(ModuleData.Slot.SYSTEM)
			+ Run.slots_for(ModuleData.Slot.UTILITY)]

	# WHAT THE REST IS WORTH, and whether anyone here will pay it. `Market.bid`
	# answers 0 for contraband where contraband does not trade, so the total is
	# not simply "everything left" -- and a SELL that silently skipped the one
	# thing you were counting on would be worse than one that says so.
	var n: MapGen.MapNode = Run.node_at()
	var worth := 0
	var refused := 0
	for m in Run.pad:
		var p := _price(n, m)
		if p > 0:
			worth += p
		else:
			refused += 1
	_sell.disabled = worth <= 0
	_done.disabled = left > 0
	if _back != null:
		_back.disabled = not Run.can_abandon_move()
		_back.tooltip_text = Widgets.tip("Put the %s back on the blocks and fly the %s out of here. Your credits come back. Anything you have already sold or dumped stays sold or dumped." % [
			Run.hull.name, Run.old_hull.name]) if Run.can_abandon_move() else ""
	if left == 0:
		_money.text = "Everything is aboard."
	elif refused > 0:
		_money.text = "%d left · worth %d cr here · %d nobody will bid on, so the hatch is the only way out of those." % [
			left, worth, refused]
	else:
		_money.text = "%d left · worth %d cr here." % [left, worth]


## How many of the pad's modules are still bolted to the old frame.
func _mounted_on_pad() -> int:
	var n := 0
	for raw in Run.pad:
		var m := raw as ModuleData
		if m != null and m.mount >= 0:
			n += 1
	return n


## What this market pays for one thing, whichever kind it is.
static func _price(n: MapGen.MapNode, m: HoldItem) -> int:
	var mat := m as MaterialData
	if mat != null:
		return Market.material_price(n, mat.id)
	var mod := m as ModuleData
	return Market.bid(n, mod) if mod != null else 0


## Drag from the old hold into a chosen cell of the new one.
func _on_drop(payload: Dictionary, at: Vector2i) -> void:
	var m: HoldItem = payload.get("module")
	if m == null:
		return
	var from_pad := Run.pad.has(m)
	var was := m.hold_at
	if from_pad:
		Run.pad.erase(m)
	elif Run.installed.has(m):
		# UNBOLTED ON THE WAY INTO THE HOLD. `_on_lift` has usually already done
		# this, but a drop can arrive without one -- and a part left in
		# `installed` while `place_in_hold` appends it to `cargo` is a part in
		# two places, fitted and stowed at once.
		Run.installed.erase(m)
		var mod := m as ModuleData
		if mod != null:
			mod.mount = -1
	elif Run.cargo.has(m):
		Run.take_from_hold(m)
	if not Run.place_in_hold(m, at):
		# A REFUSED DROP COSTS NOTHING, and for something off the old ship that
		# means it is still on the old ship -- in the cell it was drawn in, not
		# merely back in the list.
		if from_pad:
			m.hold_at = was
			Run.pad.append(m)
		elif was.x >= 0:
			Run.place_in_hold(m, was)
	_refresh()


## R TURNS WHAT YOU ARE CARRYING, and what you are pointing at in the new hold.
##
## The same key the refit screen uses, because it is the same gesture on the
## same widget: a `HoldGrid` you are packing. It was missing here, which made
## this the one screen in the game where a 3x1 spine could not be stood on end
## to fit a gap -- on the screen whose entire subject is fitting things into a
## smaller hold than they came out of.
##
## THE OLD SHIP'S GRID IS NOT TURNABLE, and that is not an omission. Nothing on
## it is being packed: it is a source you are emptying, its cells are the ones
## the parts were already in, and rearranging a hold you are walking away from
## is work with no outcome.
func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	# TWO VERBS, TWO PLACES, and neither reaches into the other's. R turns a part
	# in the HOLD, which is a packing move; F mirrors one on the HULL, which is
	# about which way the gun points. The refit screen splits them exactly this
	# way and a player who learns it there should not have to learn it twice.
	if k.keycode == KEY_F:
		if _flip_pointed():
			get_viewport().set_input_as_handled()
		return
	if k.keycode != KEY_R:
		return
	if _turn_carried() or _turn_in_new_hold():
		get_viewport().set_input_as_handled()


## Mirror whatever is bolted to the NEW ship under the pointer.
##
## THE NEW SHIP ONLY. The old hull is a frame you are stripping -- which way its
## guns face is a fact about a ship that is about to stop being yours, and a key
## that silently did nothing on one half of the screen would be worse than one
## that does nothing at all.
func _flip_pointed() -> bool:
	if _newpts == null:
		return false
	var m := _newpts.part_under(_newpts.get_local_mouse_position())
	if m == null:
		return false
	m.flipped = not m.flipped
	_newpts.refresh()
	return true


## Turn the part currently in the hand. Works from either side, because a thing
## in the air belongs to neither ship.
func _turn_carried() -> bool:
	var d: Variant = get_viewport().gui_get_drag_data()
	if typeof(d) != TYPE_DICTIONARY or not (d as Dictionary).has("module"):
		return false
	var m: HoldItem = (d as Dictionary).module
	if m == null:
		return false
	m.turned = not m.turned
	if ItemIcon.carried != null and is_instance_valid(ItemIcon.carried):
		ItemIcon.carried.fit_footprint()
		ItemIcon.carried.spin()
	return true


## Turn a part already stowed on the NEW ship, in place if it still fits.
##
## A take-out-and-put-back, so it has to fail cleanly: a 3x1 in a hold with no
## three-tall gap has nowhere to go turned, and the part must end up exactly
## where it started rather than in the first hole a repack could find.
func _turn_in_new_hold() -> bool:
	if _new == null:
		return false
	var icon := _new.icon_at(_new.get_global_mouse_position())
	if icon == null or icon.module == null:
		return false
	var m: HoldItem = icon.module
	if m.footprint().x == m.footprint().y:
		# Square. Turning it changes nothing, and playing the animation would
		# say something happened that did not.
		return true
	var was := m.hold_at
	Run.take_from_hold(m)
	m.turned = not m.turned
	if not Run.place_in_hold(m, was) and not Run.place_in_hold(m):
		m.turned = not m.turned
		Run.place_in_hold(m, was)
		Run.log_line("No room to turn %s." % m.name, &"them")
		return true
	Audio.play(&"hold_turn", 0.10)
	_refresh()
	return true


## Off the new ship, into the hand. The same pair the refit screen keeps, and
## for the same reason: a mount that still reads as full while the thing filling
## it is being carried is a mount you cannot drag out of.
func _on_lift(m: ModuleData) -> void:
	if m == null or not Run.installed.has(m):
		return
	_lifted = m
	_lifted_mount = m.mount
	Audio.play(&"hold_lift", 0.08)
	Run.installed.erase(m)
	m.mount = -1
	_refresh()


## The drag ended. Anything lifted that never landed goes back where it was --
## picking a thing up is not a decision to get rid of it.
func _on_release() -> void:
	var m := _lifted
	_lifted = null
	if m == null or Run.installed.has(m) or Run.cargo.has(m) or Run.pad.has(m):
		return
	m.mount = _lifted_mount
	Run.installed.append(m)
	_refresh()


## A part dropped on a hardpoint of the NEW ship.
##
## THREE JOURNEYS END HERE and they are not the same. Off the old hull is the
## one this screen exists for: a gun going mount to mount, which never needs to
## be put down and so never asks whether the hold has room. Out of the new hold
## is an ordinary fitting. And a part already bolted to the new ship is being
## moved one hardpoint along, which is the case that looks like the others and
## must not go through `install`, because that would take it off and put it
## back and lose the arrangement.
func _on_mount_drop(payload: Dictionary, slot: ModuleData.Slot, index: int) -> void:
	var m := Widgets.dragged_module(payload)
	if m == null or m.slot != slot:
		return
	if Run.pad.has(m):
		if not Run.pad_to_mount(m, slot, index):
			# REFUSED IS NOT LOST. `pad_to_mount` changes nothing when it says
			# no -- a taken hardpoint, or a reactor that cannot power the part
			# -- so the gun is still on the old ship and still drawn there.
			_refresh()
			return
	elif Run.installed.has(m):
		if Run.module_at(slot, index) == null:
			m.mount = index
	elif Run.cargo.has(m):
		Run.take_from_hold(m)
		if Run.module_at(slot, index) == null and Run.can_power(m):
			m.mount = index
			Run.installed.append(m)
		else:
			Run.place_in_hold(m)
	_refresh()


## Everything that fits, in one click: onto the mounts, then into the hold.
func _take_all() -> void:
	# HARDPOINTS FIRST, HOLD SECOND. A gun bolted on is a gun doing its job and
	# costs no cells; the same gun stowed is four cells of hold spent on
	# something that is not working. Filling the mounts before packing therefore
	# strands strictly less, and it is also what a person would do.
	var guns := Run.pad.duplicate()
	guns.sort_custom(func(a: HoldItem, b: HoldItem) -> bool:
		return a.cells() > b.cells())
	for raw in guns:
		var mod := raw as ModuleData
		if mod == null:
			continue
		for i in Run.slots_for(mod.slot):
			if Run.pad_to_mount(mod, mod.slot, i):
				break

	# BIGGEST FIRST is not a nicety: a 4x1 spine packed after a dozen 1x1
	# fittings have speckled the grid has nowhere to go, so a naive pass in
	# carry order strands exactly the parts you most wanted and calls it full.
	var queue := Run.pad.duplicate()
	queue.sort_custom(func(a: HoldItem, b: HoldItem) -> bool:
		return a.cells() > b.cells())
	for m in queue:
		Run.pad_to_hold(m)
	_refresh()


func _sell_rest() -> void:
	var n: MapGen.MapNode = Run.node_at()
	var paid := 0
	for m in Run.pad.duplicate():
		var p := _price(n, m)
		if p <= 0:
			continue
		Run.take_from_hold(m)
		Run.add_credits(p)
		paid += p
	if paid > 0:
		Audio.play(&"shop_sell", 0.06)
		Run.log_line("Sold what would not fit for %d credits." % paid, &"good")
	_refresh()


## Call the whole thing off and fly the old ship out.
func _back_out() -> void:
	if not Run.can_abandon_move():
		return
	Audio.act(&"hull_transfer")
	Run.abandon_move()
	Router.show_station()


func _cast_off() -> void:
	if not Run.pad.is_empty():
		return
	# THE DOCK IS RELEASED HERE, not when the pad empties. `old_hull` is what
	# this screen draws its left half from, so clearing it the moment the last
	# crate crossed would blank the page you are still standing on.
	Run.old_hull = null
	Router.show_station()
