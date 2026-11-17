class_name TransferScreen
extends Control

## The one screen drawing two hulls: a swap is when you choose between things you own.
## The purchase is final on arrival; two facing grids say more than a strip under the hold.
## Why: docs/why/TransferScreen.md#transfer-overview

## Drawn at full size: each ship has 450 px of width and a heavy is about 340 across at 1x.
## Why: docs/why/TransferScreen.md#full-size-ships
const SHIP_H := 132
## Rows of air round the taller ship in the two ship boxes.
const SHIP_AIR := 8.0
## Each portrait's box, view and drawn ship, so the two boxes can share a height.
var _portraits: Array = []

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
	# Anchors and offsets: the anchors-only preset collapsed every container under it.
	# Why: docs/why/TransferScreen.md#full-rect-anchors
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

	# One line of heading: two lines left a heavy's hold 44 px short and scrolling (Jon).
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 8)
	heading.add_child(UITheme.body("MOVING ABOARD", UITheme.COLD, UITheme.FS_SMALL))
	heading.add_child(UITheme.body(Run.hull.display_name().to_upper(),
		DB.manufacturer_colour(Run.hull.manufacturer), UITheme.FS_SMALL))
	page.add_child(heading)
	page.add_child(UITheme.hsep())

	# --- THE TWO HOLDS, FACING.
	var pair := HBoxContainer.new()
	pair.add_theme_constant_override("separation", 20)
	pair.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(pair)

	_oldhead = UITheme.body("", UITheme.LEAVE, UITheme.FS_SMALL)
	_old = OldHold.new()
	# (no old ship to draw: a save from before it was written, `RunState.mend_loadout`)
	pair.add_child(_column(Run.old_hull, "THE SHIP YOU ARE LEAVING" if Run.old_hull != null
		else "LEFT ON THE PAD", _oldhead, _old, true))

	# The arrow is the instruction, so it is drawn, not typed at caption size.
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override("separation", 4)
	mid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mid.add_child(_arrow())
	var carry := UITheme.body("CARRY
ACROSS", UITheme.COLD, UITheme.FS_SMALL)
	carry.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(carry)
	# No key hint under it: the arrow says only what to do (Jon).
	pair.add_child(mid)

	_newhead = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	_new = HoldGrid.new()
	_new.dropped.connect(_on_drop)
	pair.add_child(_column(Run.hull, "YOUR NEW SHIP", _newhead, _new, false))
	# Both ship boxes one height, the taller ship's, so the two holds start on one line.
	var tall := 0.0
	for pv: Array in _portraits:
		var drawn: Rect2i = pv[2]
		var sv: ShipView = pv[1]
		tall = maxf(tall, float(drawn.size.y * sv._k))
	for pv2: Array in _portraits:
		var box: Control = pv2[0]
		var view: ShipView = pv2[1]
		box.custom_minimum_size.y = tall + SHIP_AIR
		view.custom_minimum_size.y = tall + SHIP_AIR

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

	# TAKE IT ALL is one click: most swaps strand little, so yes must not cost twelve drags.
	# The hatch: contraband can be unsellable and CAST OFF is refused while cargo remains.
	# Why: docs/why/TransferScreen.md#take-all-and-jettison
	var bin := JettisonBin.new()
	bin.dumped.connect(func(_m: HoldItem) -> void: _refresh())
	bin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	acts.add_child(bin)
	acts.add_child(Widgets.button("TAKE WHAT FITS", _take_all))
	_sell = Widgets.button("SELL THE REST", _sell_rest)
	# A FOUND HULL IS TAKEN IN SPACE, where nobody is buying: the hatch and the
	# two holds are the whole of it there.
	_sell.visible = Router.docked
	acts.add_child(_sell)
	# The way out is why the old frame is drawn: a reversible buy is judged with both hulls.
	# Why: docs/why/TransferScreen.md#back-out
	_back = Widgets.button("BACK OUT", _back_out)
	acts.add_child(_back)
	_done = Widgets.button("CAST OFF", _cast_off)
	acts.add_child(_done)

	Sig.ship_changed.connect(_refresh)
	_refresh()


## `foreign` picks whose hardpoints: the left hull is no longer `Run.hull`, so it refuses drops.
## Why: docs/why/TransferScreen.md#ship-column
func _column(h: HullData, title: String, head: Label, grid: Control,
		foreign: bool) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	# Both halves take the slack, or the grid draws in zero pixels.
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var cap := HBoxContainer.new()
	cap.add_theme_constant_override("separation", 8)
	cap.add_child(UITheme.body(title, UITheme.COLD, UITheme.FS_SMALL))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.add_child(gap)
	# The mount count is the number being worked against: live on the right, total on the left.
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
	# The grid scrolls, not the page: a heavy hold is five rows of 40, and ships must stay.
	var box := ScrollContainer.new()
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(grid)
	col.add_child(box)

	# A plate under each ship, so the page reads as two objects, as the Yard does.
	var wrap := Widgets.panel_with(Widgets.pad(col, 10, 8))
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return wrap


## Holds differ in shape, so both are pinned to the top and the slack falls below, to read across.
## Why: docs/why/TransferScreen.md#grid-alignment


func _portrait(h: HullData, foreign: bool) -> Control:
	# A centre container around a stack of the ship's exact size: hand offsets broke on expand.
	# The mounts layer anchors to its parent, so that parent must be exactly the canvas.
	# Why: docs/why/TransferScreen.md#portrait-centring
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
		# The old ship keeps its guns: `Run.installed` is empty, so parts come from the pad.
		v.setup_build(ShipBuild.fitted_out(h, Run.pad))
	else:
		v.setup_preview(h, 0, 1)
		# The ship you fly hums; the old frame on the dock is already traded in.
		v.hums = true

	# Mounts are a child of the view, so every coordinate is the ship's own, as when refitting.
	# The picture claims the ship, not its canvas: two heavies ran the dock off screen (Jon).
	# Why: docs/why/TransferScreen.md#portrait-mounts
	var ink := v.ink_rect()
	var cw := float(v._w * v._k)
	var claim := float(ink.size.x * v._k) + 8.0
	if int(cw - claim) % 2 != 0:
		claim += 1.0
	v.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	v.custom_minimum_size = Vector2(minf(cw, claim), float(v._h * v._k))
	holder.add_child(v)
	# Centred on the ship, not its picture: across by extent, down by mass (Jon).
	# Measured once, so a part bolted on later does not make the hull jump.
	# Why: docs/why/TransferScreen.md#portrait-centring
	var mid := _mass_middle(v._img) - float(v._bob_off)
	var across := v.ship_offset_x()
	_portraits.append([holder, v, ink])
	holder.sort_children.connect(func() -> void:
		var k := float(v._k)
		var lift := floorf((float(v._h) * 0.5 - mid) * k + 0.5)
		var oy := v.position.y + floorf((v.size.y - float(v._h) * k) * 0.5)
		var top := oy + float(ink.position.y) * k
		var bot := oy + float(ink.end.y) * k
		v.position.y += clampf(lift, -top, holder.size.y - bot)
		var ox := v.position.x + floorf((v.size.x - float(v._w) * k) * 0.5)
		var left := ox + float(ink.position.x) * k
		var right := ox + float(ink.end.x) * k
		v.position.x += clampf(floorf(0.5 - across), -left, holder.size.x - right))

	var pts := MountPoints.new()
	if foreign:
		pts.ship = h
		pts.fitted = Run.pad
	else:
		pts.dropped.connect(_on_mount_drop)
		# Without lift and drop, the part stayed in `Run.installed` and unbolting did nothing.
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


## The mean row of opaque pixels: a mast moves it a few pixels, the hull most of them.
static func _mass_middle(img: Image) -> float:
	if img == null:
		return 0.0
	var w := img.get_width()
	var data := img.get_data()
	var total := 0.0
	var n := 0
	for y in img.get_height():
		var row := y * w * 4
		for x in w:
			if data[row + x * 4 + 3] >= 128:
				total += float(y)
				n += 1
	return total / float(n) if n > 0 else float(img.get_height()) * 0.5


## Drawn, not typed: the font tops out at a 16px glyph and this must read across the screen.
## Why: docs/why/TransferScreen.md#arrow
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
	# The old ship's picture is derived, so rebuild it the frame a gun crosses.
	if _oldpts != null:
		_oldpts.fitted = Run.pad
		if _oldview != null:
			_oldview.setup_build(ShipBuild.fitted_out(Run.old_hull, Run.pad))
		_oldpts.refresh()
	if _newpts != null:
		_newpts.refresh()
	var left := Run.pad.size()
	# Bolted on and stowed are counted apart, as the grid shows only the stowed ones.
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

	# `Market.bid` is 0 for contraband where it does not trade, so say what a SELL will skip.
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
		_back.tooltip_text = Widgets.tip("Put the %s back on the blocks and keep flying the %s. You get your credits back. Anything you already sold or dumped stays gone." % [
			Run.hull.name, Run.old_hull.name]) if Run.can_abandon_move() else ""
	if left == 0:
		_money.text = "Everything is aboard."
	elif not Router.docked:
		_money.text = "%d left. Carry it across, or dump what you will not take." % left
	elif refused > 0:
		_money.text = "%d left · worth %d cr here · %d no one will buy, so you can only dump those." % [
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
		# Unbolted on the way in: a drop can arrive without a lift, so no part is in two places.
		Run.installed.erase(m)
		var mod := m as ModuleData
		if mod != null:
			mod.mount = -1
	elif Run.cargo.has(m):
		Run.take_from_hold(m)
	if not Run.place_in_hold(m, at):
		# A refused drop costs nothing: an old-ship part stays in the cell it was drawn in.
		if from_pad:
			m.hold_at = was
			Run.pad.append(m)
		elif was.x >= 0:
			Run.place_in_hold(m, was)
	_refresh()


## R turns what you carry, as on the refit screen: a 3x1 spine must stand on end to fit.
## The old grid is not turnable: it is a source you empty, and repacking it has no outcome.
## Why: docs/why/TransferScreen.md#turn-and-flip-keys
func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	# R turns in the hold, F mirrors on the hull, as on the refit screen: learn it once.
	if k.is_action_pressed(&"part_flip"):
		if _flip_pointed():
			get_viewport().set_input_as_handled()
		return
	if not k.is_action_pressed(&"hold_turn"):
		return
	if _turn_carried() or _turn_in_new_hold():
		get_viewport().set_input_as_handled()


## New ship only: a key silently doing nothing on half the screen is worse than doing nothing.
## Why: docs/why/TransferScreen.md#turn-and-flip-keys
func _flip_pointed() -> bool:
	if _newpts == null:
		return false
	var m := _newpts.part_under(_newpts.get_local_mouse_position())
	if m == null:
		return false
	m.flipped = not m.flipped
	# F on a mounted part is the same gesture as R in the hold, so it makes
	# the same sound (Jon asked).
	Audio.play(&"hold_turn", 0.10)
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
	# The turn sound for a part in the hand too, not only one in the hold:
	# turning while carrying is the common case and it was silent.
	Audio.play(&"hold_turn", 0.10)
	if ItemIcon.carried != null and is_instance_valid(ItemIcon.carried):
		ItemIcon.carried.fit_footprint()
		ItemIcon.carried.spin()
	return true


## A take-out-and-put-back that must fail cleanly: the part ends up exactly where it started.
func _turn_in_new_hold() -> bool:
	if _new == null:
		return false
	# `item_at`, not `icon_at`: a crate in the hold turns the way a gun does.
	var icon := _new.item_at(_new.get_global_mouse_position())
	if icon == null or icon.held_item() == null:
		return false
	var m: HoldItem = icon.held_item()
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


## Off the new ship into the hand, as on refit: a mount reading full cannot be dragged out.
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


## Three journeys end here; a part moved one hardpoint along must not go through `install`.
## Why: docs/why/TransferScreen.md#mount-drops
func _on_mount_drop(payload: Dictionary, slot: ModuleData.Slot, index: int) -> void:
	var m := Widgets.dragged_module(payload)
	if m == null or m.slot != slot:
		return
	if Run.pad.has(m):
		if not Run.pad_to_mount(m, slot, index):
			# Refused is not lost: `pad_to_mount` changes nothing on a no, so the gun stays drawn.
			_refresh()
			return
	elif Run.installed.has(m):
		if Run.module_at(slot, index) == null:
			m.mount = index
	elif m == _lifted:
		# The part is in the hand, not on the ship: the same rule ShipScreen uses.
		if Run.fit_at_mount(m, slot, index, _lifted_mount) != Run.Refit.REFUSED:
			_lifted = null
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
	# Hardpoints first: a bolted gun costs no cells, a stowed one costs four, so this strands less.
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

	# Biggest first: a 4x1 spine packed after 1x1s have speckled the grid has nowhere to go.
	var queue := Run.pad.duplicate()
	queue.sort_custom(func(a: HoldItem, b: HoldItem) -> bool:
		return a.cells() > b.cells())
	for m in queue:
		Run.pad_to_hold(m)
	_refresh()


func _sell_rest() -> void:
	if not Router.docked:
		return
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
	Router.leave_transfer()


func _cast_off() -> void:
	if not Run.pad.is_empty():
		return
	# Released here, not when the pad empties: `old_hull` draws the left half.
	Run.old_hull = null
	Router.leave_transfer()
