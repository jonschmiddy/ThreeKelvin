class_name StationScreen
extends Control

## Prices are never stored: a price is a function of place
## and part, so none can drift or come back from a save.
## Why: docs/why/StationScreen.md#station-overview

var _header: RichTextLabel
## The door. Held as a member because whether it opens is run state -- see
## `_refresh_undock` -- and the rail that builds it is built once.
var _undock: Button
## The lab's glass in the room, which the power-on's scan opens: the owner's
## sign-on on it (`LabLogin`), and the key that is the glass itself.
var _bench_clip: Control
## THE LAB'S SCREEN IN THE ROOM (Jon, Nov 5): the owner's logo, a sign-in
## while you point at it, and the whole glass is the one key into it. Built
## once and restyled (`_refresh_bench`).
var _glass_press: Button
## The pointer was on the glass at the last look (`_process`), so its hover is
## heard once on arriving (`Audio.lab_hover`).
var _glass_on := false
## The sign-on, drawn into `_screen_vp` and shown on the glass by
## `_screen_pic`; the camera into the glass carries the same texture.
var _login: LabLogin
var _screen_vp: SubViewport
var _screen_pic: TextureRect
## THE CAMERA INTO THE LAB'S SCREEN (Jon's 1C, Nov 4): the Lab's pages at the
## board's own size, the glass filling the window (`LabZoom`).
var _lab_zoom: LabZoom
## The Exchange: your hold, and the two places you can carry things to.
var _hold_grid: HoldGrid
var _sell_desk: TradeCounter
var _sell_note: Label
## The Promenade: the till across the front of the shop.
var _till: TradeCounter
## The room the two of them stand in.
var _shop: ShopScene
## The rooms the other three decks happen in.
var _exchange: ExchangeScene
## The Hiring Hall's board, which is the whole of that deck.
var _board: PostingBoard
## The lamp over the board, the room it leaves dim, and its power-on.
var _board_lamp: BoardLamp
var _lab: LabScene
## Pointing at your own ship in the Shipyard, and the slab that answers it.
var _mine_hit: Control
var _mine_slab: Control
## Clicking your ship in the yard opens the same cutaway LOCAL opens, over the station.
var _cutaway: CutawayView = null
## the elevator down the left, which the cutaway's panel takes the place of
var _rail: Control = null
var _mine_outline: CutawayView.Outline = null
## How many clicks on your ship were refused with the thud (for `-- cutawaytest`).
var denied_clicks := 0
var _till_note: Label
var _hull_offer: VBoxContainer
## What is posted at this station and what you can close here. Above the shelf,
## because it is the part of a station that is about WHERE YOU GO NEXT.
var _work: Container
## The station in section, the frame it slides inside, and the ride.
var _spine: StationSpine
var _building: Control
var _lift: Tween
## The fault picker, while it is open. Null the rest of the time.
var _purge_prompt: Control
## Built once per visit and kept: a purchase moves the drones, it does not rebuild the yard.
var _scene: YardScene
## What the ships on the blocks are, so a refresh knows whether to stand them again.
var _yard_ships_key := ""
## The hull the TV's deal is for.
var _yard_hull: HullData = null
var _scene_ship: ShipView
## Your own ship, standing in the left berth with its parts on it.
var _mine_view: ShipView
var _scene_hit: Control
var _scene_slab: Control
## What kind of place this is, in its own words.
## The count line under each deck name, refreshed with everything else.
var _deck_note: Dictionary = {}

var _pages: Dictionary = {}
var _tabs: Dictionary = {}
var _tab: StringName = &"services"
## Every station has all five decks (Jon, Nov 3), so
## all are on; the switch stays for a deck that goes.
## Why: docs/why/StationScreen.md#five-decks-everywhere
var _tabs_on: Dictionary = {}
## Six rows of slack over the derived 144, or a hull one row deeper clips its edges as it bobs.
## Why: docs/why/StationScreen.md#hull-portrait-height
func setup() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The room is chosen by `Router._swap`, the one place that sees every screen change.
	_build()
	Sig.resources_changed.connect(_refresh)
	Sig.ship_changed.connect(_refresh)
	# Another player's purchase must empty this shelf live, as the stock is one shared list.
	Sig.party_map_changed.connect(_refresh)
	Sig.map_changed.connect(_refresh)
	Sig.undock_wanted.connect(_nudge_undock)
	# (a blink owed from the map or the chart, paid once this screen is up)
	Sig.screen_changed.connect(_nudge_undock)
	_stock_up()
	_inspect()
	_refresh()
	_nudge_undock.call_deferred()

## Page order for the harness (`StationShot deck=`); the rail is built from `DECKS`, below.
## Five pages, each built once and hidden so the shelf can refresh unseen.
## Why: docs/why/StationScreen.md#five-pages
const TABS := [
	[&"services", "SERVICES"],
	[&"work", "WORK"],
	[&"stock", "STOCK"],
	[&"hold", "HOLD"],
	[&"bench", "LABORATORY"],
]

## Decks are ordered high to low with the berth last, so the rail ends at UNDOCK.
## Why: docs/why/StationScreen.md#decks-as-a-building
const DECKS := [
	[&"stock", "PROMENADE", "THE SHELF"],
	[&"services", "SHIPYARD", "REPAIRS"],
	[&"hold", "EXCHANGE", "YOUR HOLD"],
	[&"work", "HIRING BOARD", "WORK POSTED"],
	[&"bench", "LABORATORY", "RESEARCH"],
]
## How wide the section is. Wide enough for "HIRING BOARD" plus a count at
## FS_SMALL without either wrapping, which is what sets it -- not a round number.
const RAIL_W := 156
## How tall one deck cell is. Two lines of FS_SMALL plus the padding that keeps
## the highlight from touching the text.
const DECK_H := 44

func _build() -> void:
	# The yard's hall runs on into the elevator's column while the elevator is away.
	_edge = _YardEdge.new()
	_edge.screen = self
	add_child(_edge)
	# One outer margin, or the header runs to x=0 and 960 and UNDOCK is sliced by the window.
	var frame := MarginContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# No side margin of its own: `Main` already insets
	# every screen by 8, and a second misaligned it.
	for side in ["top", "bottom"]:
		frame.add_theme_constant_override("margin_" + side, 4)
	add_child(frame)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	frame.add_child(root)

	# UNDOCK sits on the header line: it is pressed once and is never why anyone opened the screen.
	# Why: docs/why/StationScreen.md#header-and-undock
	_header = RichTextLabel.new()
	_header.bbcode_enabled = true
	_header.fit_content = true
	# Autowrap off grew the header to 983 in a 960 window, so use a fixed width and wrap.
	# Why: docs/why/StationScreen.md#header-wrapping
	_header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_header.custom_minimum_size = Vector2(RAIL_W, 0)
	_header.scroll_active = false
	_header.add_theme_stylebox_override("normal", UITheme.empty())

	# One banner per berth at the head of the rail, as
	# a contested station is held by several manufacturers.
	# Why: docs/why/StationScreen.md#rail-flags
	var rail := VBoxContainer.new()
	_rail = rail
	rail.add_theme_constant_override("separation", 3)
	rail.custom_minimum_size = Vector2(RAIL_W, 0)
	rail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Sliding away, the elevator keeps the screen's dark behind its header and gaps:
	# the hall run on into its column showed through them, the title afloat on it.
	rail.draw.connect(func() -> void:
		if _edge != null and _edge._on:
			rail.draw_rect(Rect2(Vector2.ZERO, rail.size), UITheme.VOID))

	# Station facts head the rail one to a line now that the banners hang in the rooms.
	# Why: docs/why/StationScreen.md#rail-particulars
	rail.add_child(_header)
	# No names under the flags: a flag that needs a caption has failed.
	rail.add_child(UITheme.hsep())

	# The decks are floors of one cutaway; the building slides, but every deck stays clickable.
	# Why: docs/why/StationScreen.md#decks-as-floors
	var shaft := Control.new()
	shaft.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shaft.clip_contents = true
	shaft.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Sized in a guarded callback: sizing before the shaft had a size left floors at zero height.
	# Why: docs/why/StationScreen.md#building-sizing
	_building = Control.new()
	_building.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shaft.add_child(_building)
	_spine = StationSpine.new()
	_spine.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_building.add_child(_spine)
	var cells := VBoxContainer.new()
	cells.add_theme_constant_override("separation", 0)
	cells.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_building.add_child(cells)
	shaft.resized.connect(_size_building)
	rail.add_child(shaft)

	for entry in DECKS:
		var id: StringName = entry[0]
		var cell := _deck_cell(id, String(entry[1]), String(entry[2]))
		_tabs[id] = cell
		cells.add_child(cell)
	# UNDOCK lives in the berth, with no spacer: an expanding one halves the building's height.
	# Why: docs/why/StationScreen.md#undock-cell
	rail.add_child(_undock_cell())

	# --- the pages, all built, one visible
	var body_col := VBoxContainer.new()
	body_col.add_theme_constant_override("separation", 3)
	body_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# The market's shortage is a clause of the same sentence; no headband or place blurb sits here.
	# Why: docs/why/StationScreen.md#page-header-line

	var body := Control.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_col.add_child(body)

	# Section beside pages, rather than strip above them.
	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 8)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(rail)
	split.add_child(body_col)
	root.add_child(split)

	_pages[&"services"] = _page_services()
	_pages[&"work"] = _page_work()
	_pages[&"stock"] = _page_stock()
	_pages[&"hold"] = _page_hold()
	_pages[&"bench"] = _page_bench()
	for id in _pages:
		var page: Control = _pages[id]
		page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		body.add_child(page)
	# THE LAB'S SCREEN, ZOOMED: over everything, the HUD too, once pressed
	_lab_zoom = LabZoom.new()
	_lab_zoom.lab = _lab
	_lab_zoom.screen = _screen_pic
	_lab_zoom.on_glass = [_lab.fx_layer()]
	_lab_zoom.station = self
	_lab_zoom.leaving.connect(func() -> void: _login.set_state(LabLogin.LOGO))
	add_child(_lab_zoom)
	# `-- station tab=stock` opens on a named page. Four of the five are only
	# reachable by clicking, and a screenshot cannot click.
	for a in OS.get_cmdline_user_args():
		if a.begins_with("tab="):
			_tab = StringName(a.split("=")[1])
	_show_tab(_tab)

## Services fly as drones over your ship, as on the
## Yard Drones page Jon judged; `YardScene` draws them.
## Why: docs/why/StationScreen.md#the-yard
func _page_services() -> Control:
	# The yard is 766 x 482 with seven pixels of margin,
	# so the hall Jon passed lands pixel for pixel.
	# Why: docs/why/StationScreen.md#yard-size
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	_hull_offer = VBoxContainer.new()
	_hull_offer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_hull_offer.add_theme_constant_override("separation", 0)
	var yw := PanelContainer.new()
	var sb := UITheme.flat(UITheme.PANEL, UITheme.LINE, 0, 0, 7)
	sb.content_margin_bottom = 1
	yw.add_theme_stylebox_override("panel", sb)
	yw.add_child(_hull_offer)
	yw.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(yw)
	return col


## THE YARD, built once for this station: the hall, and the layer the pointer
## targets and the ships' figures sit in over it.
func _yard_box(n: MapGen.MapNode) -> Control:
	var box := Control.new()
	box.clip_contents = true
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.custom_minimum_size = Vector2(YardScene.W, YardScene.H)
	_scene = YardScene.new()
	_scene.dev = int(n.development)
	_scene.manufacturer = n.manufacturer
	_scene.position = Vector2.ZERO
	_scene.size = Vector2(YardScene.W, YardScene.H)
	box.add_child(_scene)
	_scene.setup()
	_scene.service.connect(_on_yard_service)
	_scene.take.connect(_on_yard_take)
	_yard_ships_key = ""
	# The deck may already be the one on screen: the yard is built on the first
	# refresh, after the station opened on it.
	if _tab == &"services":
		_power_deck(&"services")
	return box


## Ships are stood again only when they changed: your hull and its fit, or the one on the blocks.
## Why: docs/why/StationScreen.md#yard-ships
func _yard_ships(h: HullData) -> void:
	var key := "%s|%s|%s" % [Run.display_name(), str(Run.hull.get_instance_id()) if Run.hull != null else "",
		str(h.get_instance_id()) if h != null else "none"]
	if Run.hull != null:
		for m in Run.installed:
			key += "|" + str(m)
	if key == _yard_ships_key:
		return
	# not under the cutaway, which hides this ship: every part moved in there
	# would bake a second one into the zoomed yard (#34). Its close stands them.
	if is_instance_valid(_cutaway):
		return
	_yard_ships_key = key
	var box := _scene.get_parent() as Control
	for c: Control in [_mine_hit, _mine_slab, _scene_hit, _scene_slab]:
		if c != null and is_instance_valid(c):
			c.queue_free()
	_mine_view = null
	_mine_hit = null
	_mine_slab = null
	_scene_ship = null
	_scene_hit = null
	_scene_slab = null
	if Run.hull != null:
		# PASSIVE: a picture of your ship from
		# `ShipBuild.fitted_out` and `MountPoints`, not an editor.
		var mine := ShipView.new()
		mine.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mine.self_clip = false
		mine.setup_build(ShipBuild.fitted_out(Run.hull, Run.installed))
		var mpts := MountPoints.new()
		mine.add_child(mpts)
		mpts.attach(mine)
		mpts.passive()
		_mine_view = mine
	if h != null:
		var v := ShipView.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.self_clip = false
		v.setup_preview(h, 0, 1)
		_scene_ship = v
	# `Run.display_name`, NOT `hull.name`: a ship you have named flies as its name.
	_scene.set_ships(_mine_view, Run.display_name().to_upper() if Run.hull != null else "",
		_scene_ship, h.name.to_upper() if h != null else "")
	# THE HOVER TARGETS ARE THE SHIPS' INK, not their canvases, and over the hall.
	if _mine_view != null:
		var mhit := Control.new()
		mhit.mouse_filter = Control.MOUSE_FILTER_STOP
		mhit.mouse_entered.connect(_on_mine_hover.bind(true))
		mhit.mouse_exited.connect(_on_mine_hover.bind(false))
		mhit.gui_input.connect(_on_mine_input)
		box.add_child(mhit)
		_mine_hit = mhit
		_mine_outline = CutawayView.Outline.new()
		_mine_outline.view = _mine_view
		_mine_outline.visible = false
		_mine_view.add_child(_mine_outline)
	if h != null:
		var hit := Control.new()
		hit.mouse_filter = Control.MOUSE_FILTER_STOP
		hit.mouse_entered.connect(_on_ship_hover.bind(true))
		hit.mouse_exited.connect(_on_ship_hover.bind(false))
		box.add_child(hit)
		_scene_hit = hit
		_scene_slab = _offer_slab(h, Run.hull, h.name.to_upper())
		_scene_slab.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_scene_slab.z_index = SLAB_Z
		_scene_slab.visible = false
		box.add_child(_scene_slab)
	_add_mine_slab(box, h)
	_place_scene_ship.call_deferred()


## Put the pointer targets on the ships' metal and float their figures over them.
func _place_scene_ship() -> void:
	if _scene == null:
		return
	var views: Array = [_mine_view, _scene_ship]
	var hits: Array = [_mine_hit, _scene_hit]
	var slabs: Array = [_mine_slab, _scene_slab]
	for i in 2:
		var P: Dictionary = _scene.placed[i]
		var v: ShipView = views[i]
		if P.is_empty() or v == null or not is_instance_valid(v):
			continue
		var hit: Control = hits[i]
		if hit != null and is_instance_valid(hit):
			hit.position = Vector2(float(P["x0"]), float(P["top"]))
			hit.size = Vector2(float(P["w"]), float(P["h"]))
		_float_slab(slabs[i], v, v.position)


## A ship's stats card draws over A.S.H.'s outline (z 49) and a hint card
## (100): the player pointing at a ship is reading the ship.
const SLAB_Z := 101


## Pointing at the ship swaps the hint for the numbers.
func _on_ship_hover(on: bool) -> void:
	if _scene_slab != null:
		_scene_slab.visible = on


## A signed change column: gauges misread when the manufacturer accent was itself red.
## Why: docs/why/StationScreen.md#offer-slab
func _offer_slab(h: HullData, against: HullData, title: String) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mark := DB.manufacturer_colour(h.manufacturer)

	# One slab serves either ship, read against the
	# other; `against` is null with nothing on the blocks.
	# Why: docs/why/StationScreen.md#offer-slab
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(UITheme.body(title, mark, UITheme.FS_HEAD))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(gap)
	if against != null:
		# `display_name` when the other ship is YOURS, so a named ship is never
		# compared against its own chassis.
		var other := Run.display_name() if against == Run.hull else against.name
		var vs := UITheme.body("AGAINST %s" % other.to_upper(),
			UITheme.QUOTE, UITheme.FS_SMALL)
		vs.size_flags_vertical = Control.SIZE_SHRINK_END
		head.add_child(vs)
	col.add_child(head)

	var hand := 0 if against == null else h.hand_size - against.hand_size
	col.add_child(UITheme.body("%s · %s TIER · HAND %d%s" % [
		HullData.weight_name(h.weight).to_upper(), h.tier_letter(), h.hand_size,
		"" if hand == 0 else (" (%+d)" % hand)], UITheme.COLD, UITheme.FS_SMALL))
	col.add_child(UITheme.hsep())

	# BOTH SIDES BARE, which is what makes the comparison honest: nothing is
	# carried over by the swap itself, so what it changes is the FRAME.
	var theirs := Run.hull_attributes(h)
	if against != null:
		var base := Run.hull_attributes(against)
		for i in mini(theirs.size(), base.size()):
			theirs[i]["delta"] = int(theirs[i].value) - int(base[i].value)

	# --- SEVEN GAUGES IN TWO COLUMNS, so the slab fits in the band of wall above
	# the berths instead of lying across the ship it describes.
	var half := int(ceilf(float(theirs.size()) * 0.5))
	var pair := HBoxContainer.new()
	pair.add_theme_constant_override("separation", 22)
	pair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in 2:
		var part: Array[Dictionary] = []
		for i in theirs.size():
			if (i < half) == (side == 0):
				part.append(theirs[i])
		if part.is_empty():
			continue
		var blk := AttrBlock.new()
		blk.setup(part, mark)
		pair.add_child(blk)
	col.add_child(pair)

	var mounts := HBoxContainer.new()
	mounts.add_theme_constant_override("separation", 7)
	mounts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mounts.add_child(UITheme.body("MOUNTS", UITheme.COLD, UITheme.FS_SMALL))
	for sl in [ModuleData.Slot.WEAPON, ModuleData.Slot.SYSTEM,
			ModuleData.Slot.UTILITY]:
		var d := 0 if against == null else h.slots_for(sl) - against.slots_for(sl)
		mounts.add_child(UITheme.body("%s %d%s" % [
			ModuleData.slot_name(sl).to_upper().substr(0, 3), h.slots_for(sl),
			"" if d == 0 else (" (%+d)" % d)],
			UITheme.CHILL if d >= 0 else UITheme.LEAVE, UITheme.FS_SMALL))
	col.add_child(mounts)

	for pid in h.perks():
		var pk := UITheme.body(DB.perk_text(pid), UITheme.EMBER, UITheme.FS_SMALL)
		pk.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Wrap a perk only if it needs it: autowrap on every perk made the slab 448 wide.
		# Why: docs/why/StationScreen.md#offer-slab
		if pk.get_minimum_size().x > float(SLAB_W - 22):
			pk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			pk.custom_minimum_size = Vector2(SLAB_W - 22, 0)
		col.add_child(pk)

	# Opaque, framed in the ship's colour: at 86% a grey hull showed through grey figures.
	# Why: docs/why/StationScreen.md#offer-slab
	var slab := PanelContainer.new()
	slab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slab.add_theme_stylebox_override("panel",
		UITheme.flat(Color(0.031, 0.043, 0.066, 0.98),
			Color(mark.r, mark.g, mark.b, 0.55), 0, 8, 11))
	slab.add_child(col)
	return slab


func _page_work() -> Control:
	# The whole deck is the board: a hiring hall is its paper, so the cork runs edge to edge.
	# Why: docs/why/StationScreen.md#hiring-board
	var stack := Control.new()
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board = PostingBoard.new()
	_board.tab_picked.connect(func(_i: int) -> void: _refresh())
	_board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_child(_board)

	# Work notes sit in one straight column of square notes, as a stagger read as crooked.
	var column := HFlowContainer.new()
	column.add_theme_constant_override("h_separation", NOTE_GAP)
	column.add_theme_constant_override("v_separation", NOTE_GAP + 2)
	_work = column
	_work.set_anchors_preset(Control.PRESET_FULL_RECT)
	_work.anchor_right = PostingBoard.NOTICE_SHARE
	_work.offset_left = PostingBoard.FRAME_W + 8.0
	_work.offset_right = 0.0
	_work.offset_top = PostingBoard.FRAME_W + 10.0
	_work.offset_bottom = -(PostingBoard.FRAME_W + 8.0)
	stack.add_child(_work)
	_board.watch(_work)
	# AND THE PINS, OVER THE NOTICES. A control draws under its children and a pin
	# goes THROUGH the paper, so the pins are a layer of their own on top.
	stack.add_child(_board.make_pins())
	# AND THE LAMP, OVER ALL OF IT: it lights the paper as much as the cork.
	_board_lamp = BoardLamp.new()
	_board_lamp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_child(_board_lamp)
	return Widgets.panel_with(Widgets.pad(stack))


## One part shown large with the rest as a list (Jon picked mock C), not a column of equal rows.
## The open column is fixed at 256, the widest case, or the cards jump sideways between parts.
## Why: docs/why/StationScreen.md#promenade
const PICK_W := 256

## What stands in the shop: the rack, placed where the station's room puts it.
## The counter is `_till`, beside it in the same stack.
var _shelf: Control


func _page_stock() -> Control:
	# The deck is one of Jon's fifteen rooms: `ShopScene` places everything, nothing here does.
	# Why: docs/why/StationScreen.md#promenade-room
	_shop = ShopScene.new()
	# The note sits under the room: inside the right column it pushed the counter off the floor.
	_till_note = UITheme.body("", UITheme.QUOTE, UITheme.FS_SMALL)
	_till_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# A shelf needs a till: carrying a part to it is the same gesture the Exchange uses to sell.
	# Why: docs/why/StationScreen.md#till
	# No cables: the shop wears no livery.
	var made := _room_page(_shop, func(stack: Control) -> void:
		# The rack stands in a holder of its own, which `_refresh_stock` empties
		# and restocks; the counter is built once.
		_shelf = Control.new()
		_shelf.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_shelf.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(_shelf),
		TradeCounter.Side.CHARGES, _on_till, _place_shop_furniture, _till_note)
	_till = made[1] as TradeCounter
	return made[0] as Control


## The till already said yes; `_on_action` re-checks anyway as it races other players for the slot.
## Why: docs/why/StationScreen.md#till-purchase
func _on_till(item: HoldItem) -> void:
	var m := item as ModuleData
	if m == null:
		return
	_on_action("buy", m)


## One counter and one price; dragging is the confirmation, and the hold is the real grid.
## Why: docs/why/StationScreen.md#exchange
func _page_hold() -> Control:
	# The deck is one of Jon's five rooms, drawn in layers round the hold and the counter.
	# Why: docs/why/StationScreen.md#exchange-room
	_exchange = ExchangeScene.new()
	_sell_note = UITheme.body("Carry something to the counter to be paid for it.",
		UITheme.QUOTE, UITheme.FS_SMALL)
	_sell_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# THE SAME COUNTER THE SHOP HAS, on the side that pays. See `TradeCounter.Side`.
	var made := _room_page(_exchange, func(stack: Control) -> void:
		# The hold is the real grid, untouched; it stands in the frame's opening, fitted cell for cell.
		_hold_grid = HoldGrid.new()
		_hold_grid.dropped.connect(_on_hold_move)
		stack.add_child(_hold_grid),
		TradeCounter.Side.PAYS, _on_counter, _place_exchange_furniture, _sell_note)
	_sell_desk = made[1] as TradeCounter
	return made[0] as Control


## A room deck (Promenade, Exchange): the room, its furniture, a counter on `side`, the room's
## three layers over both, then `note` under it. Child order is draw order. Returns [panel, counter].
func _room_page(room: ShopScene, furniture: Callable, side: TradeCounter.Side,
		on_took: Callable, on_loaded: Callable, note: Label) -> Array[Control]:
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 5)
	var stack := Control.new()
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	room.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_child(room)
	furniture.call(stack)
	var counter := TradeCounter.new()
	counter.side = side
	counter.fitted = true
	counter.lit_elsewhere = ShopScene.lit_marks
	counter.took.connect(on_took)
	stack.add_child(counter)
	room.till_node = counter
	# The room's own layers go on last, over the furniture and the counter.
	for layer in [room.front_layer(), room.light_layer(), room.glow_layer()]:
		var c: Control = layer
		c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stack.add_child(c)
	# A room's art arrives when it is first drawn; the furniture is placed then.
	room.room_loaded.connect(on_loaded)
	outer.add_child(stack)
	outer.add_child(note)
	var made: Array[Control] = [Widgets.panel_with(Widgets.pad(outer)), counter]
	return made


## Placed again whenever the room's art arrives or the hull, and so the frame, may have changed.
func _place_exchange_furniture() -> void:
	if _exchange == null or _hold_grid == null or _sell_desk == null:
		return
	_sell_desk.art = _exchange.till_art()
	var tr := _exchange.till_rect()
	_sell_desk.position = tr.position
	_sell_desk.size = tr.size
	_sell_desk.visible = _sell_desk.art != null
	_sell_desk.queue_redraw()
	var grid := Run.hold_grid()
	_exchange.fit_hold(grid)
	var cells := Vector2(grid) * float(HoldGrid.CELL)
	var op := _exchange.hold_opening()
	# NO ROOM INSTALLED IS STILL A HOLD YOU CAN SELL FROM: it stands where the
	# heavy frame would, in the open.
	var at := Vector2(24.0, 60.0)
	if op.has_area():
		at = op.position + ((op.size - cells) * 0.5).floor()
	_hold_grid.position = at
	_hold_grid.size = cells


## A part moved inside the hold. The grid reports; this owns the change.
func _on_hold_move(payload: Dictionary, at: Vector2i) -> void:
	var m: HoldItem = payload.get("module")
	if m == null:
		return
	var was := m.hold_at
	if Run.cargo.has(m):
		Run.take_from_hold(m)
	if not Run.place_in_hold(m, at) and was.x >= 0:
		# A REFUSED MOVE COSTS NOTHING. The same rule the refit screen keeps:
		# picking a thing up is not a decision to put it somewhere worse.
		Run.place_in_hold(m, was)
	_refresh()


## Something was carried to the counter.
func _on_counter(item: HoldItem) -> void:
	var paid := TradeCounter.offer(item)
	if paid <= 0:
		return
	Run.take_from_hold(item)
	Run.add_credits(paid)
	Run.node_at().trades += 1
	Audio.play(&"shop_sell", 0.06)
	Run.log_line("Sold %s for %d credits." % [item.name, paid], &"good")
	_refresh()


func _page_bench() -> Control:
	# A painted lab per development level; its screen holds the owner's sign-on, and
	# pressing the glass moves the camera onto it (`LabZoom`, Jon, Nov 4-5).
	# Why: docs/why/StationScreen.md#laboratory
	var stack := Control.new()
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lab = LabScene.new()
	_lab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_child(_lab)

	# THE GLASS CLIPS, so the scan can bring the screen up a line at a time. It
	# is placed on the glass once the station's level is known (`_refresh_bench`).
	_bench_clip = Control.new()
	_bench_clip.clip_contents = true
	_bench_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(_bench_clip)
	# THE SIGN-ON, drawn into its own small viewport: the room shows it at 1:1,
	# and the camera into the glass draws the same pixels.
	_screen_vp = SubViewport.new()
	_screen_vp.transparent_bg = true
	_screen_vp.disable_3d = true
	_screen_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_screen_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
	_screen_vp.size = Vector2i(206, 110)
	_login = LabLogin.new()
	_screen_vp.add_child(_login)
	stack.add_child(_screen_vp)
	_screen_pic = TextureRect.new()
	_screen_pic.texture = _screen_vp.get_texture()
	_screen_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen_pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_screen_pic.stretch_mode = TextureRect.STRETCH_KEEP
	# (a transparent viewport's colour comes out premultiplied)
	var pm := CanvasItemMaterial.new()
	pm.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	_screen_pic.material = pm
	_bench_clip.add_child(_screen_pic)
	# THE WHOLE GLASS IS THE KEY, and the only one: pointed at, the screen
	# turns to its sign-in; pressed anywhere on it, the camera goes onto it.
	# It draws nothing of its own (only pressable things look pressable, and
	# the sign-in is how it says so).
	_glass_press = Button.new()
	_glass_press.focus_mode = Control.FOCUS_NONE
	_glass_press.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for st in ["normal", "pressed", "disabled", "focus", "hover"]:
		_glass_press.add_theme_stylebox_override(st, UITheme.empty())
	_glass_press.pressed.connect(Audio.click)
	_glass_press.pressed.connect(func() -> void: _open_lab(&"research"))
	_bench_clip.add_child(_glass_press)
	_lab.rows_clip = _bench_clip

	var glass := _lab.fx_layer()
	glass.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_child(glass)
	return Widgets.panel_with(Widgets.pad(stack))


## THE POINTER ON THE GLASS, or off it: the sign-in, or the logo. Read off the
## key each frame (its hover, as the GUI has it), so the pointer already on the
## glass when the camera comes back out shows the sign-in. Never while the
## camera is away from the room (the screen says SIGNING IN on the way in, and
## its logo on the way out).
func _process(_delta: float) -> void:
	_ride_step(_delta)
	if _deck_swap != null:
		_swap_decks()
	if _login == null or _glass_press == null or _tab != &"bench":
		_glass_on = false
		return
	if _lab_zoom != null and (_lab_zoom.is_open() or _lab_zoom.visible):
		return
	# (nor while the deck is still riding in: the glass is not where it will be)
	var on := _glass_press.is_visible_in_tree() and _glass_press.is_hovered() and not deck_changing()
	# THE HOVER IS HEARD ON THE EDGE, the frame the screen turns to its sign-in,
	# once until the pointer leaves. Not on the camera's way back out with the
	# pointer still on the glass: `_glass_on` is not touched while the camera is
	# away, so it is still on from the press.
	if on and not _glass_on:
		Audio.lab_hover()
	_glass_on = on
	_login.set_state(LabLogin.LOGIN if on else LabLogin.LOGO)


## THE KEY'S KEYBOARD AND PAD: Enter, Space or the pad's A on the lab's deck,
## its screen up, presses the glass, as a click does. Esc or the pad's B takes
## the camera back out (`LabZoom._input`).
func _unhandled_input(e: InputEvent) -> void:
	if _tab != &"bench" or _lab_zoom == null or _lab_zoom.is_open() or e.is_echo() or deck_changing():
		return
	# (the pad's A by name: the project's ui_accept has no pad button in it)
	var pad := e as InputEventJoypadButton
	var pad_a := pad != null and pad.pressed and pad.button_index == JOY_BUTTON_A
	if not pad_a and not e.is_action_pressed(&"ui_accept"):
		return
	if not deck_subject(&"bench").has_area():
		return
	get_viewport().set_input_as_handled()
	_glass_press.pressed.emit()


## Into the Lab's screen, on page `id`.
func _open_lab(id: StringName) -> void:
	# NOT WHILE THE DECK CHANGES (the review, Nov 5): `_tab` is the Lab from the
	# click on its floor, but the Lab is not in its place till the car stops, and
	# a zoom started then would start from a room that is still moving
	if _lab_zoom == null or _lab_zoom.is_open() or deck_changing():
		return
	# (heard only on the press that signs in, the same frame as its ui_click;
	# a press refused above clicks alone)
	Audio.lab_login()
	_login.set_state(LabLogin.SIGNING)
	_lab_zoom.open(id)


## The camera into the lab's screen. Public for the harnesses.
func lab_zoom() -> LabZoom:
	return _lab_zoom


## THE CAMERA INTO THE LAB CARRIES THE DECK'S PLATE (`LabZoom`, its `_frame`), so the deck's own
## is hidden by its self_modulate while the camera is off the room, never faded.
## Why: docs/why/StationScreen.md#the-camera-into-the-lab-carries
var _lab_chrome_a := {}


func lab_chrome(away: bool) -> void:
	var c := _pages.get(&"bench") as CanvasItem
	if c == null or not is_instance_valid(c):
		return
	var id := c.get_instance_id()
	if not away:
		if _lab_chrome_a.has(id):
			c.self_modulate.a = float(_lab_chrome_a[id])
			_lab_chrome_a.erase(id)
		return
	if not _lab_chrome_a.has(id):
		_lab_chrome_a[id] = c.self_modulate.a
	c.self_modulate.a = 0.0


## The deck page whose plate frames the lab's room, which the camera into the
## Lab draws with the room (`LabZoom._draw_frame`).
func lab_frame() -> Control:
	return _pages.get(&"bench") as Control


## THE CAMERA CARRIES THE ELEVATOR AND THE HUD OUT (Jon, Nov 5, of the zoom: "can we have a
## smoother transition with the elevator?").
## Why: docs/why/StationScreen.md#the-camera-carries-the-elevator-and
var _lab_carry := {}
var _lab_lift := false
## The rail's alpha while the camera has it: 0 once it is wholly out of the
## window, so a row laid out again under it cannot put it back over the board.
var _lab_rail_a := 1.0


func lab_carry(d: Vector2, on: bool) -> void:
	_lab_lift = on
	_lab_rail_a = 1.0
	for it: Array in [[_rail, Vector2(minf(0.0, d.x), 0.0)], [Router.hud, Vector2(0.0, minf(0.0, d.y))]]:
		var c := it[0] as Control
		if c == null or not is_instance_valid(c):
			continue
		var id := c.get_instance_id()
		# (by its offsets, not its position: a window resized mid-zoom puts it
		# back where its anchors say for the new size, not where it stood)
		if not on:
			if _lab_carry.has(id):
				var was: Array = _lab_carry[id]
				_set_offsets(c, was[0])
				c.z_index = was[1]
				c.modulate.a = was[2]
				_lab_carry.erase(id)
			continue
		if not _lab_carry.has(id):
			_lab_carry[id] = [Vector4(c.offset_left, c.offset_top, c.offset_right, c.offset_bottom), c.z_index, c.modulate.a]
		var rest: Array = _lab_carry[id]
		var off: Vector2 = it[1]
		_set_offsets(c, rest[0])
		c.position += off.round()
		c.z_index = 2
		var r := Rect2(c.get_global_rect().position, c.size)
		var gone := r.end.x <= 0.0 or r.end.y <= 0.0
		c.modulate.a = 0.0 if gone else float(rest[2])
		if c == _rail:
			_lab_rail_a = 0.0 if gone else 1.0


## UNDOCK FROM A DECK ABOVE THE YARD RIDES DOWN TO IT FIRST (Jon, Nov 5: the slide for every
## elevator choice).
## Why: docs/why/StationScreen.md#undock-from-a-deck-above-the
var _undock_wait := false


func _undock_press() -> void:
	if _undock_wait:
		return
	if _undock_rides():
		if _tab != &"services":
			_show_tab(&"services")
		if deck_changing():
			_undock_wait = true
			_deck_fade.finished.connect(_undock_after_ride)
			return
	Router.show_sector()


## Whether undocking from here plays the yard (`ladder_pre`), so must start on it.
func _undock_rides() -> bool:
	return _pages.has(&"services") and _tabs_on.get(&"services", true) 		and ZoomLadder.enabled() and ZoomLadder.design_for(3) in ["B", "D"]


func _undock_after_ride() -> void:
	if not _undock_wait:
		return
	_undock_wait = false
	if _tab == &"services" and is_inside_tree() and Router.current == self 			and _undock != null and not _undock.disabled:
		Router.show_sector()


static func _set_offsets(c: Control, o: Vector4) -> void:
	c.offset_left = o.x
	c.offset_top = o.y
	c.offset_right = o.z
	c.offset_bottom = o.w


## A Button with child Labels, as a Button draws one line in one colour; clicks fall through to it.
## Why: docs/why/StationScreen.md#deck-cells
func _deck_cell(id: StringName, deck: String, what: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(RAIL_W, DECK_H)
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func() -> void: _show_tab(id))
	# No plate in any state: `StationSpine` lights the floor you are on. Hover gets the one
	# outline (C1), where it got a faint wash.
	for st in ["normal", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, UITheme.empty())
	b.add_theme_stylebox_override("hover", UITheme.mark_box(Color(0, 0, 0, 0), 0, 0))

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 9
	box.offset_right = -7
	# Centred, not top-aligned: a clipped rail then takes air off a room and keeps the name.
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 1)

	var title := UITheme.body(deck, UITheme.CHILL, UITheme.FS_HEAD)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title)
	var note := UITheme.body(what, UITheme.COLD, UITheme.FS_SMALL)
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(note)
	b.add_child(box)

	# Kept by id so `_refresh` can retitle them without walking the tree.
	b.set_meta(&"title", title)
	_deck_note[id] = note
	return b


## The rail is a cutaway of the station, so your own hull no longer draws above the button.
## Why: docs/why/StationScreen.md#undock-cell
func _undock_cell() -> Control:
	# THE ONE THING ON THE RAIL THAT LEAVES. Every deck above it is somewhere you
	# go and come back from; this is the door, so it wears the same ink BUY does.
	var out := _commit_button("UNDOCK", _undock_press)
	# (big enough to read as the door, not a footnote under the floors)
	out.custom_minimum_size = Vector2(RAIL_W, UNDOCK_H)
	out.add_theme_font_size_override("font_size", UITheme.FS_HEAD)
	# SHRINK, not expand: the expanding button split
	# the rail, leaving the building 178 of 347 pixels.
	# Why: docs/why/StationScreen.md#undock-cell
	out.size_flags_vertical = Control.SIZE_SHRINK_END
	_undock = out
	return out


## UNDOCK's height on the rail, px.
const UNDOCK_H := 32
## UNDOCK's blink when another way out is refused: how long, s, and how often.
const NUDGE_S := 1.6
const NUDGE_BLINKS := 3
var _nudge_tween: Tween = null


## `Router.cast_off` refused a way out: UNDOCK blinks, or under reduced motion
## lights and holds. Off screen, the flag waits for the station to be up.
func _nudge_undock() -> void:
	if not Router.undock_nudge or not is_inside_tree() or Router.current != self:
		return
	Router.undock_nudge = false
	if _undock == null or not is_instance_valid(_undock) or _undock.disabled:
		return
	if _nudge_tween != null and _nudge_tween.is_valid():
		_nudge_tween.kill()
	var hot := Color(1.9, 1.7, 1.4)
	_nudge_tween = create_tween()
	if DisplaySettings.reduced_motion:
		_undock.modulate = hot
		_nudge_tween.tween_interval(NUDGE_S)
	else:
		var step := NUDGE_S / float(NUDGE_BLINKS * 2)
		for i in NUDGE_BLINKS:
			_nudge_tween.tween_property(_undock, "modulate", hot, step)
			_nudge_tween.tween_property(_undock, "modulate", Color.WHITE, step)
	_nudge_tween.tween_property(_undock, "modulate", Color.WHITE, 0.0)


## A deck powers on once per docking (Jon): `Router.powered` remembers, and undocking clears it.
## Why: docs/why/StationScreen.md#deck-power-on
func _power_deck(id: StringName) -> void:
	var settled: bool = Router.powered.has(id)
	if id == &"bench" and _lab != null:
		_lab.power_on(settled)
		# (riding in on a slide, the Lab comes in dark and its lamps strike as
		# the car stops, as they did after the dip: not mid-ride)
		if not settled and deck_changing() and deck_move == &"slide":
			_boot_on_arrival(_lab.delay_boot.bind(3600.0), _lab.boot_now)
	elif id == &"services" and _scene != null and is_instance_valid(_scene):
		_scene.power_on(settled)
	elif id == &"work" and _board_lamp != null:
		_board_lamp.power_on(settled)
		# (and the board's tubes strike as the car stops, as the Lab's lamps do)
		if not settled and deck_changing() and deck_move == &"slide":
			_boot_on_arrival(_board_lamp.hold_boot, _board_lamp.boot_now)
	else:
		return
	Router.powered[id] = true


func _show_tab(id: StringName) -> void:
	if not _pages.has(id) or not _tabs_on.get(id, true):
		return
	# (a floor picked on the way down to undock: the player changed their mind)
	_undock_wait = false
	# (a ride still going: the new one starts from what is on screen, under the
	# dark as it is, not from the deck it was going to)
	var from: Control = _deck_showing() if _tab != id or deck_changing() else null
	var a0 := 0.0
	if _deck_dark != null and is_instance_valid(_deck_dark):
		a0 = _deck_dark.color.a
	# (and on a slide, where the shaft stands, and the other deck in it)
	var y0 := from.position.y if from != null else 0.0
	var other: Control = null
	if deck_changing() and deck_move == &"slide":
		other = _deck_to if from == _deck_from else _deck_from
	_end_deck_fade(true)
	_tab = id
	for key in _pages:
		(_pages[key] as Control).visible = key == id
	_ride_s = 0.0
	_light_floor()
	# (a deck left is always a ride, the car's or -- no car to time it -- the
	# shortest one: never a cut)
	if from != null and (from != _pages[id] or a0 > 0.0 or y0 != 0.0) and Router.animating():
		var secs := maxf(_ride_s, DECK_MIN_S)
		if deck_move == &"slide":
			_slide_decks(from, _pages[id] as Control, secs, y0, other)
		else:
			_cross_decks(from, _pages[id] as Control, secs, a0)
	if not deck_changing():
		for key2 in _pages:
			(_pages[key2] as Control).position.y = 0.0
	# The lab and the yard's TV power on the first time you step onto the deck.
	_power_deck(id)
	for key in _tabs:
		var b: Button = _tabs[key]
		var on: bool = key == id
		b.disabled = on
		# The deck's own labels carry the colour, not the button's font, because
		# a Button's font colour cannot reach Labels parented inside it.
		var title := b.get_meta(&"title", null) as Label
		# No plate in either state: opaque plates hid the
		# whole cutaway, so the spine seemed not to render.
		# Why: docs/why/StationScreen.md#deck-cell-plates
		b.add_theme_stylebox_override("normal", UITheme.empty())
		b.add_theme_stylebox_override("disabled", UITheme.empty())
		if on:
			if title != null:
				title.add_theme_color_override("font_color", UITheme.HOT)
			_tint_note(key, true)
		else:
			if title != null:
				title.add_theme_color_override("font_color", UITheme.CHILL)
			_tint_note(key, false)


## THE LAB'S REMINDER (Jon, Nov 8, S1A): at LAB_REMIND DATA or more the Laboratory's line on
## the elevator reads "SPEND N DATA" in EMBER on every deck. One line, no panel.
## Why: docs/why/StationScreen.md#the-labs-reminder
const LAB_REMIND := 10

func lab_reminds() -> bool:
	return Run.data >= LAB_REMIND and not Run.science_off


## A deck's line under its name: EMBER on the deck you are on, COLD elsewhere, but the Lab's
## reminder is EMBER wherever you stand.
func _tint_note(key: StringName, on: bool) -> void:
	if not _deck_note.has(key):
		return
	var hot := on or (key == &"bench" and lab_reminds())
	(_deck_note[key] as Label).add_theme_color_override("font_color", UITheme.EMBER if hot else UITheme.COLD)


## THE DECKS CHANGE OVER THE RIDE, NOT AT THE CLICK (Jon, Nov 5: "a smoother transition with the
## elevator").
## Why: docs/why/StationScreen.md#the-decks-change-over-the-ride
var _ride_s := 0.0
var _deck_fade: Tween = null
var _deck_from: Control = null
var _deck_dark: ColorRect = null
var _deck_swap: Control = null
## How long the dark holds whole while the decks change hands (s).
const DECK_HOLD_S := 0.034


## The decks change hands under the dark (`_cross_decks`).
func _swap_decks() -> void:
	var to := _deck_swap
	_deck_swap = null
	if to == null or not is_instance_valid(to):
		return
	if _deck_from != null and is_instance_valid(_deck_from) and _pages.get(_tab) != _deck_from:
		_deck_from.visible = false
		_deck_from.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED
	to.visible = true


## From the deck `from` shown under a dark of `a0` (0, or how dark a ride cut
## short by this press had it) to the deck `to`. Pressed back to the deck still
## showing, the dark only goes back down.
func _cross_decks(from: Control, to: Control, secs: float, a0: float = 0.0) -> void:
	var body := to.get_parent() as Control
	if body == null:
		return
	_deck_dark = ColorRect.new()
	_deck_dark.color = Color(0, 0, 0, a0)
	_deck_dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_deck_dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.add_child(_deck_dark)
	_deck_fade = create_tween()
	_deck_fade.finished.connect(_end_deck_fade)
	if from == to:
		_deck_fade.tween_property(_deck_dark, ^"color:a", 0.0, secs * 0.5 * a0) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		return
	from.visible = true
	to.visible = false
	from.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
	_deck_from = from
	_deck_fade.tween_property(_deck_dark, ^"color:a", 1.0, secs * 0.5 * (1.0 - a0)) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	# (the hand-over on this screen's next `_process`, ahead of the decks' own:
	# a tween runs after them, and the Lab shown from here drew one frame on
	# its build's lit uniforms, its logo up, before its power-on had ticked)
	_deck_fade.tween_callback(func() -> void: _deck_swap = to)
	# (the dark held whole while the hand-over lands: two frames at 60)
	_deck_fade.tween_interval(DECK_HOLD_S)
	_deck_fade.tween_property(_deck_dark, ^"color:a", 0.0, secs * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## The deck on screen now: in a deck change before its hand-over, the deck
## being left, else the deck you are on.
func _deck_showing() -> Control:
	if deck_changing() and deck_move == &"slide":
		# (on a slide, whichever deck holds more of the panel)
		var best: Control = null
		for pg: Control in [_deck_from, _deck_to]:
			if pg != null and is_instance_valid(pg) and pg.visible \
					and (best == null or absf(pg.position.y) < absf(best.position.y)):
				best = pg
		if best != null:
			return best
	if deck_changing() and _deck_from != null and is_instance_valid(_deck_from) and _deck_from.visible:
		return _deck_from
	return _pages.get(_tab)


## Whether a deck change is still going down or coming up.
func deck_changing() -> bool:
	return _deck_fade != null and _deck_fade.is_valid()


## The deck change finished now: only the deck you are on shown, every deck in
## its place and taking clicks again, and the dark and the slab gone. `keep`
## (a new ride starting from this one) leaves the decks where they stand for it.
func _end_deck_fade(keep: bool = false) -> void:
	_boot_release()
	if _deck_fade != null and _deck_fade.is_valid():
		_deck_fade.kill()
	_deck_fade = null
	_deck_swap = null
	if _deck_from != null and is_instance_valid(_deck_from):
		_deck_from.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED
	if _deck_to != null and is_instance_valid(_deck_to):
		_deck_to.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED
	_deck_from = null
	_deck_to = null
	if _deck_dark != null and is_instance_valid(_deck_dark):
		_deck_dark.queue_free()
	_deck_dark = null
	if _deck_slab != null and is_instance_valid(_deck_slab):
		_deck_slab.queue_free()
	_deck_slab = null
	if _deck_body != null and is_instance_valid(_deck_body):
		_deck_body.clip_contents = _deck_clip
	_deck_body = null
	for pg: Control in _deck_page_clip:
		if is_instance_valid(pg):
			pg.clip_contents = bool(_deck_page_clip[pg][0])
			pg.z_index = int(_deck_page_clip[pg][1])
	_deck_page_clip.clear()
	if keep:
		return
	for key in _pages:
		var pg := _pages[key] as Control
		pg.visible = key == _tab
		pg.position.y = 0.0


## THE DECKS RIDE WITH THE CAR (the review of the dip, Nov 5: a fade to black is still a cut,
## and an elevator goes up and down).
## Why: docs/why/StationScreen.md#the-decks-ride-with-the-car
static var deck_move: StringName = &"slide"
## The floor slab between two decks on a slide (px), and the shortest ride a
## deck change takes (s): a one-floor hop at 0.24 s read as a blink.
const DECK_SLAB := 12
const DECK_MIN_S := 0.36
var _deck_to: Control = null
var _deck_secs := 0.0
var _deck_slab: Control = null
var _deck_clip := false
var _deck_body: Control = null
## Each riding deck's own clip and z as they were (`_slide_decks`).
var _deck_page_clip: Dictionary = {}


## THE RIDE NEVER JUMPS A LONG FRAME: the car and the slide step at most RIDE_STEP_S a frame,
## so a frame that stalls building a deck holds the shaft where it was.
## Why: docs/why/StationScreen.md#the-ride-never-jumps-a-long
const RIDE_STEP_S := 1.0 / 30.0
var _slide_tw: Tween = null


func _ride_step(delta: float) -> void:
	var dt := minf(delta, RIDE_STEP_S)
	if _lift != null and _lift.is_valid():
		_lift.custom_step(dt)
	if _slide_tw != null and _slide_tw.is_valid() and _slide_tw == _deck_fade:
		_slide_tw.custom_step(dt)
	else:
		_slide_tw = null


## A DECK'S POWER-ON WAITS FOR THE CAR: riding in, the deck is dark (`hold`),
## and its lights strike (`go`) a quarter second before the car stops, on the
## ride's own clock (a stalled frame holds the ride, so a power-on timed on
## any other clock struck early). A ride cut short by another press strikes it
## then (`_end_deck_fade`), so no deck is left dark.
var _boot_go: Array[Callable] = []


func _boot_on_arrival(hold: Callable, go: Callable) -> void:
	hold.call()
	_boot_go.append(go)
	_deck_fade.parallel().tween_callback(_boot_release).set_delay(maxf(0.0, _deck_secs - 0.25))


func _boot_release() -> void:
	var go := _boot_go
	_boot_go = []
	for g in go:
		if g.is_valid():
			g.call()


## The page whose deck this is, by its id.
func _page_id(page: Control) -> StringName:
	for key in _pages:
		if _pages[key] == page:
			return key
	return &""


## From the deck `from` (where it stands now, `y0` off its place) to `to`, over
## `secs`: the shaft moved, `from` out and `to` in.
func _slide_decks(from: Control, to: Control, secs: float, y0: float, other: Control) -> void:
	var body := to.get_parent() as Control
	if body == null:
		return
	var span := body.size.y + float(DECK_SLAB)
	# which way the shaft goes: by the floors, or (pressed back mid-ride) by
	# where the deck you go back to already stands
	var dir := 1.0
	var a := _spine.floors.find(_page_id(from)) if _spine != null else -1
	var b := _spine.floors.find(_page_id(to)) if _spine != null else -1
	if a >= 0 and b >= 0 and a != b:
		dir = 1.0 if b > a else -1.0
	var mate := to
	var y_end := -dir * span
	if from == to:
		# back to the deck still mostly showing: it rides back into its place,
		# the deck it was leaving for goes back out the way it came
		mate = other
		if mate == null or not is_instance_valid(mate):
			from.position.y = 0.0
			return
		dir = signf(mate.position.y - from.position.y)
		if dir == 0.0:
			dir = 1.0
		y_end = 0.0
	for key in _pages:
		var pg := _pages[key] as Control
		pg.visible = pg == from or pg == mate
		pg.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED if pg.visible else Control.MOUSE_BEHAVIOR_INHERITED
		if not pg.visible:
			pg.position.y = 0.0
	_deck_body = body
	_deck_secs = secs
	_deck_clip = body.clip_contents
	body.clip_contents = true
	# THE LOWER DECK OVER THE UPPER (the r5 film: from the yard up to the PROMENADE the yard
	# went dark on the press).
	# Why: docs/why/StationScreen.md#the-lower-deck-over-the-upper
	var lower := mate if dir > 0.0 else from
	for pg: Control in [from, mate]:
		if not _deck_page_clip.has(pg):
			_deck_page_clip[pg] = [pg.clip_contents, pg.z_index]
		pg.clip_contents = true
		pg.z_index = 1 if pg == lower else 0
	_deck_from = from
	_deck_to = mate
	_deck_slab = _Slab.new()
	_deck_slab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_deck_slab.z_index = 2
	_deck_slab.size = Vector2(body.size.x, DECK_SLAB)
	body.add_child(_deck_slab)
	var place := func(y: float) -> void:
		if not is_instance_valid(from) or not is_instance_valid(mate):
			return
		from.position.y = roundf(y)
		mate.position.y = roundf(y) + dir * span
		var top := minf(from.position.y, mate.position.y)
		_deck_slab.position = Vector2(0.0, top + body.size.y)
	place.call(y0)
	_deck_fade = create_tween()
	_deck_fade.finished.connect(_end_deck_fade)
	_deck_fade.tween_method(place, y0, y_end, secs).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# (stepped by this screen with the car, a frame at most RIDE_STEP_S)
	_deck_fade.pause()
	_slide_tw = _deck_fade


## The floor slab between two decks on a slide: the deck's dark, a lit edge
## on each face and a row of rivets, so the shaft reads as one building.
class _Slab extends Control:
	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(0, 0, w, h), Color("#0a0d12"))
		draw_rect(Rect2(0, 0, w, 1), Color("#3a4654"))
		draw_rect(Rect2(0, h - 1, w, 1), Color("#26303b"))
		draw_rect(Rect2(0, 3, w, 1), Color("#141a22"))
		var x := 6.0
		while x < w:
			draw_rect(Rect2(x, floorf(h / 2.0), 2, 2), Color("#222b35"))
			x += 24.0


## Turn a tab on or off for this station, and get off it if you are standing on
## one that just went away.
func _enable_tab(id: StringName, on: bool) -> void:
	var was: bool = _tabs_on.get(id, true)
	_tabs_on[id] = on
	if _tabs.has(id):
		(_tabs[id] as Button).visible = on
	if not on and _tab == id:
		_show_tab(&"services")
	elif was != on:
		# Tell `StationSpine` when a deck is hidden, or its rooms and car drift off their labels.
		# Not a ride: a car that travels over a journey nobody made would be wrong. See `_ride_to`.
		# Why: docs/why/StationScreen.md#cutaway-deck-count
		_light_floor(false)


## Pick the fault from the cards themselves, priced per removal as `clear_dross` takes exactly one.
## Why: docs/why/StationScreen.md#purge-picker
func _open_purge() -> void:
	if _purge_prompt != null or Run.dross_count() <= 0:
		return
	var n: MapGen.MapNode = Run.node_at()
	var cost := Market.purge_price(n)

	# The shade eats input so the deck below cannot be clicked through; the dim margin closes it.
	var mid := Widgets.prompt(self, _close_purge)
	_purge_prompt = mid.get_parent() as Control

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.add_child(UITheme.body("SYSTEM REPAIR", UITheme.ICE, UITheme.FS_HEAD))
	col.add_child(UITheme.body("%d credits clears one fault. Which one?" % cost,
		UITheme.COLD, UITheme.FS_SMALL))
	col.add_child(UITheme.hsep())

	var fan := HBoxContainer.new()
	fan.add_theme_constant_override("separation", 8)
	col.add_child(fan)
	var tally: Dictionary = {}
	for id in Run.dross:
		tally[id] = int(tally.get(id, 0)) + 1
	for id in tally:
		var card := DB.malfunction(id)
		if card == null:
			continue
		var one := VBoxContainer.new()
		one.add_theme_constant_override("separation", 4)
		var cv := CardView.new()
		cv.setup(card, true, 1)
		cv.mouse_filter = Control.MOUSE_FILTER_STOP
		cv.tooltip_text = " "
		one.add_child(cv)
		var many: int = tally[id]
		if many > 1:
			var x := UITheme.body("YOU HAVE %d" % many, UITheme.LEAVE,
				UITheme.FS_SMALL)
			x.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			one.add_child(x)
		var pick := Widgets.button("CLEAR", func() -> void:
			_purge(id)
			_close_purge()
			# Reopens while there is something left to clear,
			# so clearing four is not four extra clicks.
			if Run.dross_count() > 0 and Run.credits >= Market.purge_price(
					Run.node_at()):
				_open_purge())
		pick.disabled = Run.credits < cost
		one.add_child(pick)
		fan.add_child(one)

	col.add_child(UITheme.hsep())
	var back := Widgets.button("LEAVE IT", _close_purge)
	back.add_theme_color_override("font_color", UITheme.LEAVE)
	col.add_child(back)

	var card_panel := Widgets.panel_with(Widgets.pad(col, 14, 12))
	# The card stops the press, so only the dim margin dismisses.
	card_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	mid.add_child(card_panel)


func _close_purge() -> void:
	if _purge_prompt == null:
		return
	_purge_prompt.queue_free()
	_purge_prompt = null
	_refresh()


## The building fills the shaft: sliding it left a floor partly out of frame on a navigation rail.
## Why: docs/why/StationScreen.md#building-height
func _size_building() -> void:
	if _building == null:
		return
	var shaft := _building.get_parent() as Control
	if shaft == null or shaft.size.y <= 0.0:
		return
	_building.position = Vector2.ZERO
	_building.size = shaft.size


## The car moves through the rooms, not the station; `ride` is false on arrival and on resize.
## Why: docs/why/StationScreen.md#elevator-car
func _ride_to(index: int, ride: bool = true) -> void:
	if _spine == null or index < 0:
		return
	if _lift != null and _lift.is_valid():
		_lift.kill()
	if not ride or _spine.car < 0.0:
		_car_step(float(index))
		return
	# Found by bracketing with Jon: 0.34 s for one floor, a third over the original 0.26.
	# Why: docs/why/StationScreen.md#ride-timing
	var span := absf(float(index) - _spine.car)
	var secs := clampf(0.21 + 0.13 * span, 0.24, 0.72)
	# (and the decks change over it: `_cross_decks`)
	_ride_s = secs
	# Sound only when the car travels, throttled as clicking fast down the list restarts the ride.
	Audio.play(&"station_lift", 0.05, 150)
	_lift = create_tween()
	_lift.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_lift.tween_method(_car_step, _spine.car, float(index), secs)
	# (stepped by this screen, a frame at most RIDE_STEP_S: `_ride_step`)
	_lift.pause()
	# The sound lasts exactly the ride (Jon) and is
	# faded on the stop frame; arrival has its own chunk.
	# Why: docs/why/StationScreen.md#ride-sound
	var fade := int(clampf(secs * 250.0, 25.0, 60.0))
	_lift.finished.connect(func() -> void:
		Audio.hush([&"station_lift"] as Array[StringName], fade)
		Audio.play(&"station_lift_stop"))


## One frame of the ride.
func _car_step(at: float) -> void:
	if _spine == null:
		return
	_spine.car = at
	_spine.queue_redraw()


## Floors are the enabled decks, not always five, so the spine never draws a room you cannot reach.
## Why: docs/why/StationScreen.md#cutaway-floors
func _light_floor(ride: bool = true) -> void:
	if _spine == null:
		return
	var live: Array[StringName] = []
	for entry in DECKS:
		var id: StringName = entry[0]
		if _tabs_on.get(id, true):
			live.append(id)
	var was := _spine.active
	_spine.floors = live
	_spine.active = live.find(_tab)
	_size_building()
	# Ride only when the floor changed and never on
	# the first, or ticking prices would move the car.
	_ride_to(_spine.active, ride and was >= 0 and was != _spine.active)
	_spine.manufacturer = Run.node_at().manufacturer if not Run.map.is_empty() \
		else &""
	_spine.queue_redraw()


## Stocked once per system per run: guarding on `shop.is_empty()` let a buyout re-roll for free
## money. `SHOP_CELLS` caps area at 16; `SHOP_COLS` caps what the rack can stand and binds first.
## Why: docs/why/StationScreen.md#shop-stocking
const SHOP_CELLS := 16
const SHOP_COLS := ShelfDisplay.SHELF_COLS * 2


func _stock_up() -> void:
	var n: MapGen.MapNode = Run.node_at()
	if n.stocked:
		return
	n.stocked = true
	# Positional via `Rng.derive`, so ships docking in any order see one shelf.
	var r := Rng.derive(&"shop", n.index)
	# Up to 16 cells of stock, never more columns than the rack has. Depth is rarity, not quantity.
	var cells_left := SHOP_CELLS
	var cols_left := r.randi_range(SHOP_COLS - 3, SHOP_COLS)
	var tries := 0
	while cells_left > 0 and cols_left > 0 and tries < 16:
		tries += 1
		var force := &""
		if n.region == MapGen.Region.TERRITORY:
			force = n.manufacturer
		elif n.region == MapGen.Region.COSMOPOLITAN:
			# Cosmopolitan hubs carry multiple manufacturers side by side.
			force = Rng.pick(r, DB.manufacturers.keys())
		# Depth is rarity: `n.danger` already says how deep, and lawless space runs hotter.
		var danger := n.danger + 3 if n.region == MapGen.Region.LAWLESS else n.danger
		var m := LootGen.roll_module(danger, force, n.region == MapGen.Region.LAWLESS, r)
		# Legitimate markets do not move Legendary and above.
		if n.region == MapGen.Region.COSMOPOLITAN and m.rarity > ModuleData.Rarity.EPIC:
			m.rarity = ModuleData.Rarity.EPIC
		# A part that will not fit what is left is put back; width is checked apart from cells.
		var cells := maxi(1, m.size.x) * maxi(1, m.size.y)
		var cols := maxi(1, m.size.x)
		if cells > cells_left or cols > cols_left:
			continue
		# Parts must also divide onto two boards of four, as
		# the room's rack is the two-board one Jon placed.
		# Why: docs/why/StationScreen.md#shop-stocking
		var trial: Array = n.shop.duplicate()
		trial.append(m)
		if not ShelfDisplay.stands_on(trial, 2):
			continue
		cells_left -= cells
		cols_left -= cols
		n.shop.append(m)
	# Odds scale with development, as a flat 0.4 made
	# empty runs likely; lawless space never has one.
	# Why: docs/why/StationScreen.md#hull-on-the-blocks
	var hull_odds := 0.0
	match n.development:
		MapGen.Development.UNCLAIMED: hull_odds = 0.15
		MapGen.Development.OUTPOST: hull_odds = 0.35
		MapGen.Development.SETTLEMENT: hull_odds = 0.55
		MapGen.Development.CITY: hull_odds = 0.75
		MapGen.Development.CAPITAL: hull_odds = 0.9
	if n.region != MapGen.Region.LAWLESS and r.randf() < hull_odds:
		n.shop_hull = LootGen.roll_hull(n.danger, r)

## Its own function, run on every dock: under the stock roll's early return it only ran once.
## Why: docs/why/StationScreen.md#customs-inspection
func _inspect() -> void:
	var n: MapGen.MapNode = Run.node_at()
	if n.region == MapGen.Region.COSMOPOLITAN and not n.inspected and Run.contraband_count() > 0:
		n.inspected = true
		var c := Run.contraband_count()
		var fine := 20 * c
		Run.add_credits(-fine)
		Run.log_line("Customs found %d illegal part%s and fined you %d credits." % [
			c, "" if c == 1 else "s", fine], &"heat")

## One function per tab body, mirroring `_refresh_work`, instead of one 110-line run.
## Why: docs/why/StationScreen.md#refresh-split
func _refresh() -> void:
	var n: MapGen.MapNode = Run.node_at()
	_refresh_header(n)
	_refresh_work(n)
	_refresh_services(n)
	_refresh_stock(n)
	_refresh_hold(n)
	_refresh_bench(n)
	_refresh_undock()


## Gate the door, not the jump: a blocked jump would trip `check_stranded` and kill the run.
## Why: docs/why/StationScreen.md#undock-gate
func _refresh_undock() -> void:
	if _undock == null:
		return
	var why := Run.ready_to_fly()
	_undock.disabled = not why.is_empty()
	if why.is_empty():
		_undock.text = "UNDOCK"
		_undock.tooltip_text = ""
		return
	_undock.text = "CANNOT UNDOCK"
	# The pad line points at clicking your ship, as the cutaway never showed the pad (Jon, Oct 23).
	# Why: docs/why/StationScreen.md#undock-gate
	var how := "Click your ship in the Shipyard and fit parts from the hold."
	if not Run.pad.is_empty():
		how = "Click your ship in the Shipyard to carry your things aboard."
	_undock.tooltip_text = Widgets.tip("%s.
%s" % ["; ".join(why).capitalize(), how])


## The banner, the trade line, and the two gauges on the hull panel.


## The banner, the trade line, and the two gauges on the hull panel.


func _refresh_header(n: MapGen.MapNode) -> void:
	# One fact to a line at the head of the rail, so the place's name can be a title.
	# Why: docs/why/StationScreen.md#rail-header
	var note := ""
	match n.region:
		MapGen.Region.COSMOPOLITAN: note = "stock from many manufacturers, strict inspections"
		MapGen.Region.LAWLESS: note = "stolen goods, no customs"
	_header.clear()
	_header.append_text("[font_size=%d][color=#%s]%s STATION[/color][/font_size]\n" % [
		UITheme.FS_HEAD, UITheme.ICE.to_html(false),
		MapGen.development_name(n.development).to_upper()])
	_header.append_text("[color=#%s]%s SECURITY\nDANGER %d[/color]" % [
		UITheme.CHILL.to_html(false),
		MapGen.security_name(n.security).to_upper(), n.danger])
	var tl := Market.trade_line(n)
	if tl != "":
		_header.append_text("\n[color=#%s]%s[/color]"
			% [Color("#d99b29").to_html(false), tl.to_upper()])
	if note != "":
		_header.append_text("\n[color=#%s]%s[/color]"
			% [UITheme.COLD.to_html(false), note.to_upper()])


## Work only: what the station does to your ship. The hold and its worth are the Exchange's.


## Work only: what the station does to your ship. The hold and its worth are the Exchange's.


func _refresh_services(n: MapGen.MapNode) -> void:
	var h: HullData = n.shop_hull
	var up := h != null and not n.taken.has(MapGen.OPTION_SHOP_HULL)
	# Built once; a refresh only says what changed, or the drones and TV would restart.
	if _scene == null or not is_instance_valid(_scene):
		Widgets.clear(_hull_offer)
		_hull_offer.add_child(_yard_box(n))
	_yard_ships(h if up else null)
	_yard_hull = h if up else null

	# The deal is a receipt on the TV: the ask, your
	# ship's worth, and the difference, over TAKE IT.
	if up:
		var ask := Market.hull_price(n, h)
		var part_ex := Market.hull_bid(n, Run.hull)
		var price: int = maxi(0, ask - part_ex)
		_scene.set_deal({"ask": ask, "trade": part_ex, "price": price, "ok": Run.credits >= price})
	else:
		_scene.set_deal({})

	# Four drone services at the old machines' prices;
	# a drone with nothing left says why and flies off.
	# Why: docs/why/StationScreen.md#yard-services
	var refuel := Run.refuel_offer(n)
	var refuel_cost := int(refuel.cost)
	var dross_n := Run.dross_count()
	var purge_cost := Market.purge_price(n)
	var offers: Array = YardDrones.repair_offers(n)
	offers.append_array([
		{"label": "REFUEL +%d" % maxi(1, int(refuel.units)), "cost": refuel_cost, "done": Run.refuel_blocked(n),
			"tip": Run.rescue_line(refuel) if refuel.get("rescue", false)
				else "Fuel costs more out on the frontier than in a capital."},
		{"label": "FAULTS %d" % dross_n, "cost": purge_cost, "done": "" if dross_n > 0 else "NO FAULTS",
			"tip": "Choose which fault comes out; each costs the same and clears one."},
	])
	for o: Dictionary in offers:
		o["ok"] = Run.credits >= int(o["cost"])
	_scene.set_offers(offers)



## The shelf: a chassis if one is for sale, then whatever parts are left on it.


## Sprite and card art do different jobs, so neither is a crop of the other.
## Cell is 44, not the hold's 40 (`HoldGrid.CELL`): module sprites are 20 px a cell, so 2x leaves two pixels of air.
## Why: docs/why/StationScreen.md#hold-plate
const PART_CELL := 44


func _hold_plate(m: ModuleData) -> Control:
	var cells := Vector2i(maxi(1, m.size.x), maxi(1, m.size.y))
	var box := Control.new()
	box.custom_minimum_size = Vector2(cells) * PART_CELL
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var grid := GridContainer.new()
	grid.columns = cells.x
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", 0)
	grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(grid)
	for i in cells.x * cells.y:
		var sq := PanelContainer.new()
		sq.custom_minimum_size = Vector2(PART_CELL, PART_CELL)
		sq.add_theme_stylebox_override("panel",
			UITheme.flat(Color("#0a0f17"), Color("#1b2735"), 0, 0, 0))
		grid.add_child(sq)

	# A sibling laid over the squares, as the sprite spans the whole footprint.
	var mid := CenterContainer.new()
	mid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(mid)
	var art := TextureRect.new()
	art.texture = m.sprite
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if m.sprite != null:
		# Exactly double, computed from the texture: fitting a 44 cell gives 2.2x and half-pixels.
		art.stretch_mode = TextureRect.STRETCH_SCALE
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.custom_minimum_size = m.sprite.get_size() * 2.0
	mid.add_child(art)
	return box


## Shared by the Promenade and the Exchange, as two copies had already drifted on their last line.
## Why: docs/why/StationScreen.md#part-column
func _part_column(mod: ModuleData) -> VBoxContainer:
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	left.custom_minimum_size = Vector2(PICK_W, 0)
	# SHRINK_BEGIN, so PICK_W is the width and not merely the floor. Left to
	# expand, a column with nothing beside it takes the whole band.
	left.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	var plate := HBoxContainer.new()
	plate.add_theme_constant_override("separation", 10)
	# Reserve the tallest footprint (BULK, two deep), or opening a 2x2 shifts everything below it.
	plate.custom_minimum_size = Vector2(0, PART_CELL * 2)
	var cells_box := _hold_plate(mod)
	cells_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	plate.add_child(cells_box)
	var szn := VBoxContainer.new()
	szn.add_theme_constant_override("separation", 1)
	szn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	szn.add_child(UITheme.body("%d×%d" % [mod.size.x, mod.size.y],
		UITheme.CHILL, UITheme.FS_SMALL))
	szn.add_child(UITheme.body("%d CELL%s" % [mod.cells(),
		"" if mod.cells() == 1 else "S"], UITheme.COLD, UITheme.FS_SMALL))
	plate.add_child(szn)
	left.add_child(plate)

	# The name carries the grade ink: on a shelf the question is how good, not what it is called.
	var title := UITheme.body(mod.name.to_upper(),
		ModuleData.rarity_ink(mod.rarity), UITheme.FS_HEAD)
	# One line: a two-line name changed the panel's height; `clip_text` is the guard.
	title.clip_text = true
	title.custom_minimum_size = Vector2(PICK_W, 0)
	left.add_child(title)

	# Manufacturer and slot are two labels: one is an allegiance, the other a spec.
	var mrow := HBoxContainer.new()
	mrow.add_theme_constant_override("separation", 5)
	mrow.add_child(UITheme.body(
		DB.manufacturer_name(mod.manufacturer).to_upper(),
		DB.manufacturer_colour(mod.manufacturer), UITheme.FS_SMALL))
	mrow.add_child(UITheme.body("· %s" % ModuleData.slot_name(mod.slot).to_upper(),
		UITheme.COLD, UITheme.FS_SMALL))
	left.add_child(mrow)

	# No fixed height: the money is its own column now, so nothing below needs holding still.
	# Why: docs/why/StationScreen.md#part-description
	var desc := VBoxContainer.new()
	desc.add_theme_constant_override("separation", 4)
	left.add_child(desc)
	for a in mod.affixes:
		# THE GAUGE IN FULL. `a.text` is the abbreviated form, written for a
		# readout the width of a card; this column has room for the word.
		var af := UITheme.body("%s — %s" % [a.name.to_upper(), a.gauge_text(true)],
			UITheme.EMBER, UITheme.FS_SMALL)
		af.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		af.custom_minimum_size = Vector2(PICK_W, 0)
		desc.add_child(af)
	# (no flavour line under it: Jon, Nov 9, "the flavor text can go away")
	return left


## One ink for the five controls that commit; disabled
## is spelled out or an unaffordable BUY looks live.
## Why: docs/why/StationScreen.md#commit-button
func _commit_button(text: String, action: Callable) -> Button:
	return Widgets.commit(Widgets.button(text, action))
## Show the real card face, not the art cropped out with the rules reprinted in grey.
## Why: docs/why/StationScreen.md#card-fan
func _card_fan(mod: ModuleData, heading: String) -> VBoxContainer:
	var deck := VBoxContainer.new()
	deck.add_theme_constant_override("separation", 5)
	deck.add_child(UITheme.body(heading, UITheme.COLD, UITheme.FS_SMALL))
	var fan := HBoxContainer.new()
	fan.add_theme_constant_override("separation", 8)
	deck.add_child(fan)
	# One face per copy: `resolved_cards` has an entry per copy the Grant Count Law awards.
	for c in mod.resolved_cards():
		var v := CardView.new()
		# `can_play` TRUE: the flag greys the face, which
		# in a shop window reads as the card broken.
		v.setup(c, true, 1)
		# `tooltip_text` must be non-empty or Godot never asks for the custom tooltip panel.
		v.mouse_filter = Control.MOUSE_FILTER_STOP
		v.tooltip_text = " "
		fan.add_child(v)
	return deck


## `SLAB_W` is a ceiling, not a width: read as a floor it left the right third empty.
## Why: docs/why/StationScreen.md#slab-width
const SLAB_W := 470


func _refresh_stock(n: MapGen.MapNode) -> void:
	Widgets.clear(_shelf)

	# A sold part stays in `n.shop` so slot numbers keep
	# their meaning (`MapGen.OPTION_SHOP`); it is hidden here.
	# Why: docs/why/StationScreen.md#shelf-stock
	var on_offer: Array = []
	for i in n.shop.size():
		if n.taken.has(MapGen.OPTION_SHOP + i):
			continue
		var m: ModuleData = n.shop[i]
		on_offer.append({pick = i, thing = m, price = Market.ask(n, m)})

	# Said once under the till: a bought part goes to the HOLD, so a full hold blocks shopping.
	if _till_note != null:
		_till_note.text = ("The shelves are empty." if on_offer.is_empty()
			else "Carry a part down to the till to buy it. It goes into your hold%s"
				% (", and your hold is full." if Run.hold_full() else "."))
	# Development picks the room's level variant; a bare rack stays, as it says out of stock.
	if _shop != null:
		_shop.dev = int(n.development)
		_shop.manufacturer = n.manufacturer
		_shop.place_seed = _place_seed(n)
		_shop.set_room(ShopScene.room_for(_shop.dev, _shop.place_seed))
		_shop.queue_redraw()
		_hang_banners(_shop, n, _shop.banner_spots())
	_shop_offer = on_offer
	_place_shop_furniture()


## What is on offer at this station, kept so the rack can be restocked when
## the room's art arrives after the stock does.
var _shop_offer: Array = []


## The rack and the counter, where this station's room stands them, and the
## stock on the rack. Again whenever the room's art arrives.
func _place_shop_furniture() -> void:
	if _shelf == null or _shop == null or _till == null:
		return
	_till.art = _shop.till_art()
	var tr := _shop.till_rect()
	_till.position = tr.position
	_till.size = tr.size
	_till.visible = _till.art != null
	_till.queue_redraw()
	Widgets.clear(_shelf)
	var art := _shop.rack_art()
	if art == null:
		return
	var on_offer := _shop_offer

	# The shelf answers what the top band did: hovering
	# gives the readout and cards from `ModuleIcon`.
	# Why: docs/why/StationScreen.md#shelf-display

	# Stock stands on a shelf at its true size, so a
	# four-cell rail says what it is before any text.
	# Why: docs/why/StationScreen.md#shelf-display
	var shelf := ShelfDisplay.new()
	# The room's rack at its own size scaled by two, as the bench draws it, so the tags double too.
	shelf.art_override = art
	shelf.board_rows = _shop.rack_boards()
	shelf.lit_elsewhere = ShopScene.lit_marks
	var rr := _shop.rack_rect()
	shelf.position = rr.position
	shelf.size = Vector2(art.get_size())
	shelf.scale = Vector2(2.0, 2.0)
	# Nothing to connect: the shelf has no button, so reading and spending cannot be confused.
	_shelf.add_child(shelf)
	_shop.shelf_node = shelf
	shelf.stock(on_offer)


## Same two bands as the Promenade, so `_part_column` and
## `_card_fan` are shared; this file owns the actions.
## Why: docs/why/StationScreen.md#hold-listing
func _refresh_hold(n: MapGen.MapNode) -> void:
	_dress_room(_exchange, n)
	if _exchange != null:
		_exchange.sky_node = n
		_exchange.set_room(ExchangeScene.exchange_room_for(_exchange.dev, _exchange.place_seed))
	if _hold_grid == null:
		return
	_hold_grid.refresh()
	_place_exchange_furniture()
	var stray := Run.pad.size()

	# Hold fullness and today's rate go under the room; a
	# market's rate belongs to the place (`Market.bid`).
	_sell_note.text = "Hold %d/%d%s. Carry something to the counter to be paid for it. %s" % [
		Run.cargo_used(), Run.cargo_slots(), "" if stray == 0 else ", %d on the pad" % stray,
		"This market has bought a lot today, so it pays less than it did."
		if n.trades >= 3 else "These are this market's usual prices."]
## The entry on the lab's screen, restyled, and the Lab's pages behind it.
func _refresh_bench(n: MapGen.MapNode) -> void:
	_dress_room(_lab, n)
	_lab.load_level()
	# ON THE LAB'S GLASS. The holder is the glass, the key all of it; the
	# sign-on stands in the screen's window, where the prototype drew its rows
	# (clear of the capital's and the den's flasks in front of the glass).
	var gr := _lab.glass_rect()
	var win := _lab.win_rect()
	_bench_clip.position = gr.position
	_bench_clip.size = gr.size
	_glass_press.position = Vector2.ZERO
	_glass_press.size = gr.size
	_screen_pic.position = win.position - gr.position
	_screen_pic.size = win.size
	if _screen_vp.size != Vector2i(win.size):
		_screen_vp.size = Vector2i(win.size)
	_login.size = win.size
	# THE SIGN-ON IS LAID OUT IN WHAT THE LANDED CAMERA KEEPS of the window
	# (`LabZoom.landed_view`), whole px inside it: its header was cut off at four
	# labs, where the landed glass is wider or taller than the screen
	var seen := LabZoom.landed_view(_lab).intersection(win)
	var sa := (seen.position - win.position).ceil()
	var sb := (seen.end - win.position).floor()
	_login.safe = Rect2i(Vector2i(sa), Vector2i(sb - sa))
	# EVERY STATION HAS ITS LABORATORY (Jon, Nov 3: all five decks at every
	# station, at every level).
	_enable_tab(&"bench", true)
	# RESTYLED, NEVER REBUILT: a key made again on every `resources_changed`
	# could not be clicked.
	var tn: Array = (_lab.lab.get("screen", {}) as Dictionary).get("tint", [190, 240, 235])
	_login.tint = Color8(int(tn[0]), int(tn[1]), int(tn[2]))
	_login.owner_id = n.manufacturer if n.manufacturer != &"" else (n.berths[0] if not n.berths.is_empty() else &"")
	_login.pilot = Run.display_name()
	_login.data = Run.data
	_login.lab = _lab
	# the order its savers come in is the station's own: the galaxy's seed and
	# the system, so a partner docked here and a film see the same (`LabSavers.list_for`)
	_login.station_key = hash("%d:%d" % [Run.galaxy_seed, n.index])
	if _deck_note.has(&"bench"):
		(_deck_note[&"bench"] as Label).text = ("SPEND %d DATA" if lab_reminds() else "DATA %d") % Run.data
		_tint_note(&"bench", _tabs.has(&"bench") and (_tabs[&"bench"] as Button).disabled)
	if _lab_zoom != null:
		_lab_zoom.refresh()

## A drone was pointed at and clicked: do what it sells, and tell the yard it
## happened, so the drone can dip to the hull and do the work.
func _on_yard_service(i: int) -> void:
	var n: MapGen.MapNode = Run.node_at()
	var missing := Run.max_hp() - Run.hp
	match i:
		0, 1:
			if missing <= 0:
				return
			var amount := mini(8, missing) if i == 0 else missing
			if Run.credits < Market.repair_price(n, amount):
				return
			_scene.serving(i)
			_repair(amount)
			_scene.served(i, "+%d HULL" % amount)
		2:
			var offer := Run.refuel_offer(n)
			if Run.credits < int(offer.cost) or Run.refuel_blocked(n) != "":
				return
			_scene.serving(2)
			_refuel()
			_scene.served(2, "+%d FUEL" % int(offer.units))
		3:
			# THE FAULTS DRONE OPENS THE PICKER, as the fault post did: which one
			# comes out is the decision, and a card is the only way to see it.
			_open_purge()
			return
	_refresh()


## TAKE IT, on the TV.
func _on_yard_take() -> void:
	if _yard_hull != null:
		_on_action("take_hull", _yard_hull)


func _repair(amount: int) -> void:
	var n: MapGen.MapNode = Run.node_at()
	var cost := Market.repair_price(n, amount)
	if Run.credits < cost:
		return
	Run.add_credits(-cost)
	# No sound of its own: the drone that does it is heard doing it.
	var healed := Run.heal(amount)
	Run.log_line("Repaired %d hull for %d credits." % [healed, cost], &"good")

func _refuel() -> void:
	# Through Run, so the fuel tuning's top and stock are one rule. No emit:
	# `fuel` has a setter -- see RunState.
	var o := Run.refuel_offer(Run.node_at())
	var line := Run.rescue_line(o) if o.get("rescue", false) else "Refuelled."
	if Run.buy_refuel(Run.node_at()):
		Run.log_line(line, &"good")

## One malfunction at a time: `clear_dross` removes a single entry, so paying thrice is deliberate.
func _purge(which: StringName) -> void:
	var cost := Market.purge_price(Run.node_at())
	if Run.credits < cost or Run.dross_count() <= 0:
		return
	var card := DB.malfunction(which)
	if _scene != null and is_instance_valid(_scene):
		_scene.serving(3)
	if not Run.clear_dross(which):
		return
	Run.add_credits(-cost)
	Run.log_line("%s cleared." % card.name, &"good")
	if _scene != null and is_instance_valid(_scene):
		_scene.served(3, "FIXED")

## Make a recipe at the Lab (`LabZoom._make`, from RECIPES' MAKE): the log
## line, or "" when it did not happen.
func _fabricate(r: Dictionary) -> String:
	var line := Fabricator.make(Run.node_at(), r)
	if line.is_empty():
		return ""
	Audio.play(&"fabricate", 0.04)
	Run.log_line(line, &"good")
	return line

## True while a co-op client waits on the host for a claim, so a second click cannot pay twice.
var _asking := false

func _on_action(action: String, thing: Variant) -> void:
	var n: MapGen.MapNode = Run.node_at()
	if _asking and (action == "buy" or action == "take_hull"):
		return
	match action:
		"buy":
			var m := thing as ModuleData
			var slot := n.shop.find(m)
			var price := Market.ask(n, m)
			if slot < 0 or Run.credits < price:
				return
			# Check room before the money, for this part's
			# shape: a wide part used to be paid for and lost.
			# Why: docs/why/StationScreen.md#buy-checks
			if not Run.has_room_for(m):
				Run.log_line("The hold is full. Nowhere to put it.", &"them")
				return
			# One shelf, four buyers: ask first and pay only if you won (`RunState.take_option`).
			_asking = true
			var won: bool = await Run.take_option(n, MapGen.OPTION_SHOP + slot)
			_asking = false
			if not won:
				var who := Net.taker_name(n.index, MapGen.OPTION_SHOP + slot)
				Run.log_line("Sold.%s" % (" %s got there first." % who.to_upper()
					if who != "" else ""), &"them")
				_refresh()
				return
			Run.add_credits(-price)
			Run.stow(m)
			Audio.play(&"shop_buy", 0.05)
			Run.log_line("Bought %s for %d credits." % [m.name, price], &"good")
			Sig.ship_changed.emit()
		"sell":
			# Every sale lowers this market's price, so one
			# good system cannot absorb an unlimited hold.
			var sm := thing as ModuleData
			var paid := Market.bid(n, sm)
			if paid <= 0:
				return
			Run.take_from_hold(sm)
			Audio.play(&"shop_sell", 0.06)
			Run.add_credits(paid)
			n.trades += 1
			Run.log_line("Sold %s for %d credits." % [sm.name, paid], &"good")
			Sig.ship_changed.emit()
		"take_hull":
			var h := thing as HullData
			# The net, not the ask, from the same calls the panel printed. Computed before
			# `take_option`, because `Run.hull` is about to stop being the ship being valued.
			var price2: int = maxi(0, Market.hull_price(n, h)
				- Market.hull_bid(n, Run.hull))
			if Run.credits < price2:
				return
			# One rack, one hull. Same race as the shelf above, and the same
			# order: ask, then pay.
			_asking = true
			var won2: bool = await Run.take_option(n, MapGen.OPTION_SHOP_HULL)
			_asking = false
			if not won2:
				var who2 := Net.taker_name(n.index, MapGen.OPTION_SHOP_HULL)
				Run.log_line("Gone.%s" % (" %s is flying it." % who2.to_upper()
					if who2 != "" else ""), &"them")
				_refresh()
				return
			Run.add_credits(-price2)
			Audio.act(&"hull_transfer")
			# Price and rack go with the move so `abandon_move` can refund and put the hull back.
			Run.transfer_to_hull(h, price2, n)
			# Straight to the dock even if nothing was carried: the new frame arrives bare.
			Router.show_transfer()
			return
	_refresh()


## Three groups in the order a player acts: paid now, agreed but not closable here, then the board.
## Why: docs/why/StationScreen.md#work-board


func _refresh_work(n: MapGen.MapNode) -> void:
	if _board != null:
		_board.posts = _board_posts(n)
		_board.dev = int(n.development)
		_board.station_seed = hash([n.layer, n.row, n.index])
		_board.queue_redraw()
	if _board_lamp != null and _board_lamp.dev != int(n.development):
		# (its setter throws away the whole light map, a per-pixel build)
		_board_lamp.dev = int(n.development)
	if _work != null:
		_work.offset_top = PostingBoard.FRAME_W + 10.0 + (PostingBoard.HEADER if _on_screen() else 0.0)
		_work.offset_bottom = -(PostingBoard.FRAME_W + 8.0 + (PostingBoard.TICKER if _on_screen() else 0.0))
	if _signed_at != n.index:
		_signed_at = n.index
		_signed_here.clear()
	var offers := Contracts.board(n)
	var ready := Run.deliverable_at(n)
	var hot := Run.heat_deliverable_at(n)
	var mine := _open_elsewhere(n)

	# Every station has a hiring board (Jon, Nov 3).
	# One with no manufacturer posts for its dock desk.
	# Why: docs/why/StationScreen.md#five-decks-everywhere
	_enable_tab(&"work", true)

	# The board as [what it says, how to make it], laid over what is up by `_sync_notes`.
	var want: Array = []
	# A job signed and payable here is paid off its own note, not a sticky that shifts the board.
	var pay_here := {}
	for job in ready:
		var c0: ContractData = job
		if _signed_here.has(_offer_key(c0)):
			pay_here[_offer_key(c0)] = [c0, "DELIVER"]
			continue
		want.append(["deliver|%d|%d|%s" % [c0.id, c0.pay, _on_screen()],
			_deliver_row.bind(c0, "DELIVER")])
	for job in hot:
		# Said with the number, because the heat on your hull is falling every
		# time you jump and the player is being asked to notice it.
		var c1: ContractData = job
		var say := "OFFLOAD %d HEAT" % c1.amount
		if _signed_here.has(_offer_key(c1)):
			pay_here[_offer_key(c1)] = [c1, say]
			continue
		want.append(["hot|%d|%d|%s" % [c1.id, c1.amount, _on_screen()],
			_deliver_row.bind(c1, say)])

	var elsewhere: Array[String] = []
	for job in mine:
		var c4: ContractData = job
		if not _signed_here.has(_offer_key(c4)):
			elsewhere.append(c4.status_line())
	if not elsewhere.is_empty():
		want.append(["mine|%s|%s" % [" / ".join(elsewhere), _on_screen()], _elsewhere_note.bind(elsewhere)])

	# Tabs count work by kind on a screen; your deliveries
	# stay up, and a job signed here still counts.
	var counts: Array[int] = [0, 0, 0, 0]
	for job in offers:
		var c3: ContractData = job
		if Run.holds_contract(c3) and not _signed_here.has(_offer_key(c3)):
			continue
		counts[0] += 1
		var at := PostingBoard.TAB_KINDS.find(int(c3.kind))
		if at > 0:
			counts[at] += 1
	if _board != null:
		_board.tab_counts = counts
	var only := -1
	if _on_screen() and _board != null:
		only = int(PostingBoard.TAB_KINDS[_board.tab])
	for job in offers:
		var c2: ContractData = job
		var key := _offer_key(c2)
		var held := Run.holds_contract(c2)
		# SIGNED ELSEWHERE, on an earlier visit: it is on the card above, not here
		if held and not _signed_here.has(key):
			continue
		if only >= 0 and int(c2.kind) != only:
			continue
		var state := "open"
		if held:
			state = "signed"
			if pay_here.has(key):
				state = "pay|%d|%s" % [(pay_here[key][0] as ContractData).id, pay_here[key][1]]
		want.append(["offer|%s|%s|%s" % [key, state, _on_screen()],
			_offer_row.bind(c2, state, pay_here.get(key, []))])
	# A bare board says so on a note, as an empty deck reads like a board that did not load.
	if want.is_empty() and counts[0] == 0:
		want.append(["empty|%s" % _on_screen(), _empty_note])
	_sync_notes(want)


## What a bare Hiring Board shows: one note that says there is no work.
const NO_WORK := "NO WORK POSTED."


func _empty_note() -> Control:
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 3)
	var say := UITheme.body(NO_WORK, _ink(&"head"), UITheme.FS_SMALL)
	say.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(say)
	return _note(PostingBoard.INDEX, card)


## Offers signed this visit stay stamped where hung, so the board does not reshuffle (Jon, Oct 22).
## Why: docs/why/StationScreen.md#signed-offers
var _signed_here := {}
## The station `_signed_here` is for.
var _signed_at := -1


## A piece of work by what it is: the offer on the board and the job in your
## ledger made from it say the same (`Run.holds_contract` compares the same).
static func _offer_key(c: ContractData) -> String:
	return "%s|%d|%d|%d|%d" % [c.manufacturer, int(c.kind), c.at, c.amount, c.posted_at]


## Notes update in place: clearing and rebuilding flashed new paper and re-laid the whole board.
## Why: docs/why/StationScreen.md#board-sync
func _sync_notes(want: Array) -> void:
	if _work == null:
		return
	var have := _work.get_children()
	for i in want.size():
		var say: String = want[i][0]
		if i < have.size() and String((have[i] as Node).get_meta(&"note", "")) == say:
			continue
		var note: Control = (want[i][1] as Callable).call()
		note.set_meta(&"note", say)
		if i < have.size():
			var old: Node = have[i]
			_work.remove_child(old)
			old.queue_free()
		_work.add_child(note)
		_work.move_child(note, i)
		have = _work.get_children()
	for j in range(_work.get_child_count() - 1, want.size() - 1, -1):
		var extra := _work.get_child(j)
		_work.remove_child(extra)
		extra.queue_free()


## One card, not a heading and a list: loose pieces would be pinned and tilted apart.
func _elsewhere_note(lines: Array[String]) -> Control:
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 3)
	card.add_child(UITheme.body("SIGNED, ELSEWHERE", _ink(&"head"), UITheme.FS_SMALL))
	for line in lines:
		var row := UITheme.body("· %s" % line, _ink(&"ink"), UITheme.FS_SMALL)
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(row)
	return _note(PostingBoard.INDEX, card)


## Everything open that this desk cannot pay for. Named rather than listed in
## full: the ledger is your ship's own job (click it), and a station is where you act.
func _open_elsewhere(n: MapGen.MapNode) -> Array:
	var out: Array = []
	for c in Run.contracts:
		var job: ContractData = c
		if job.state == ContractData.State.CLOSED:
			continue
		if ContractData.berth_of(n, job.manufacturer) and job.state == ContractData.State.READY:
			continue
		if job.kind == ContractData.Kind.HEAT and ContractData.berth_of(n, job.manufacturer) \
				and Run.heat >= job.amount:
			continue
		out.append(job)
	return out


## A contract's note: a square of paper, this wide and at least this tall.
const NOTE := 136.0
const NOTE_GAP := 8
const NOTE_PAPER := Color("#e6dab0")
const NOTE_STICKY := Color("#f0d878")


## One square of paper with `body` written on it -- or, in a city or a
## capital, where the board is a screen, one square panel shown on it.
func _note(paper: Color, body: Control) -> Control:
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(NOTE, NOTE)
	if _on_screen():
		var edge := PostingBoard.LCD_CYAN if paper != NOTE_STICKY else PostingBoard.LCD_AMBER
		pc.add_theme_stylebox_override("panel", UITheme.flat(PostingBoard.LCD_GLASS, edge, 0, 7, 8))
	else:
		pc.add_theme_stylebox_override("panel", UITheme.flat(paper, paper.darkened(0.28), 0, 7, 8))
	pc.add_child(body)
	return pc


## Whether the board here is a screen (a city's or a capital's).
func _on_screen() -> bool:
	return _board != null and _board.screen()


## The note's inks: on paper, the board's; on a screen, light.
func _ink(which: StringName) -> Color:
	if _on_screen():
		match which:
			&"pay": return UITheme.EMBER
			&"soft": return UITheme.QUOTE
			&"head": return PostingBoard.LCD_BLUE
			_: return UITheme.CHILL
	match which:
		&"pay": return PostingBoard.RED
		&"soft": return PostingBoard.INK_SOFT
		&"head": return PostingBoard.BLUE
		_: return PostingBoard.INK


## A manufacturer's name in its colour: as it is on a screen, darkened to read on
## paper.
func _manufacturer_ink(m: StringName, dark: float) -> Color:
	var c := DB.manufacturer_colour(m)
	return c if _on_screen() else c.darkened(dark)


func _offer_row(c: ContractData, state: String = "open", pay: Array = []) -> Control:
	if _on_screen():
		return _listing(c, state, pay)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 5)
	# The flag beside the name: a contract is written in that manufacturer's own voice.
	var mk: ManufacturerData = DB.manufacturers.get(c.manufacturer)
	if mk != null:
		var fl := ChassisSelect.Banner.new()
		# Scale 1: the banner needs 22 units of height to draw its hem and emblem
		# intact, and two lines of text are about that.
		fl.s = 1.0
		fl.custom_minimum_size = Vector2(ChassisSelect.Banner.UNITS_W, 0)
		fl.manufacturer = c.manufacturer
		fl.mark = mk.colour
		fl.field = mk.field
		top.add_child(fl)
	var who := VBoxContainer.new()
	who.add_theme_constant_override("separation", 1)
	# the manufacturer's colour, darkened to read on paper
	var name_l := UITheme.body(DB.manufacturer_name(c.manufacturer).to_upper(),
		_manufacturer_ink(c.manufacturer, 0.45), UITheme.FS_SMALL)
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.add_child(name_l)
	# THE PAY, the reason to read the note, large and in the board's red ink.
	who.add_child(UITheme.body("%d CR" % c.pay, _ink(&"pay"), UITheme.FS_HEAD))
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(who)
	box.add_child(top)

	# The ask, in the manufacturer's own voice: the part a player reads twice.
	var ask := UITheme.body(c.text, _ink(&"ink"), UITheme.FS_SMALL)
	ask.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(ask)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(sp)

	var where := UITheme.body(c.status_line(), _ink(&"soft"), UITheme.FS_SMALL)
	where.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(where)
	box.add_child(_offer_foot(c, state, pay))
	return _note(NOTE_PAPER, box)


## A contract as a marketplace listing: emblem, pay, the ask, where it is, and SIGN.
func _listing(c: ContractData, state: String = "open", pay: Array = []) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	var mk: ManufacturerData = DB.manufacturers.get(c.manufacturer)
	var photo := Control.new()
	photo.custom_minimum_size = Vector2(0, 40)
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mid := c.manufacturer
	photo.draw.connect(func() -> void:
		var field := mk.field if mk != null else Color("#203040")
		photo.draw_rect(Rect2(Vector2.ZERO, photo.size), field)
		if mk != null:
			CardView.draw_emblem(photo, mid, Vector2(photo.size.x * 0.5, 20.0), 1.4, mk.colour, mk.field)
		photo.draw_string(UITheme.pixel_font(), Vector2(4.0, photo.size.y - 4.0),
			LowHull.scr(photo, DB.manufacturer_name(mid).to_upper(), UITheme.FS_SMALL), HORIZONTAL_ALIGNMENT_LEFT, -1,
			UITheme.FS_SMALL, Color(1, 1, 1, 0.85)))
	box.add_child(photo)
	box.add_child(UITheme.body("%d CR" % c.pay, UITheme.EMBER, UITheme.FS_HEAD))
	var ask := UITheme.body(c.text, UITheme.CHILL, UITheme.FS_SMALL)
	ask.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(ask)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(sp)
	var where := UITheme.body(c.status_line(), UITheme.QUOTE, UITheme.FS_SMALL)
	where.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(where)
	# how many are watching it and when it went up: the same for the same job
	var hh := absi(hash(c.text))
	box.add_child(UITheme.body("%d WATCHING, %dH AGO" % [2 + hh % 11, 1 + (hh / 11) % 20],
		Color("#4a7a96"), UITheme.FS_SMALL))
	box.add_child(_offer_foot(c, state, pay))
	return _note(NOTE_PAPER, box)


## SIGN is big enough to be the one thing on a note that reads as pressable.
func _sign_button(c: ContractData) -> Button:
	var take := Widgets.button("SIGN", func() -> void:
		Run.take_contract(c)
		# kept where it hangs, stamped (`_signed_here`), and the board updated
		# in place round it (`_sync_notes`)
		_signed_here[_offer_key(c)] = true
		_refresh())
	take.tooltip_text = Widgets.tip("Nothing here expires; sign it now, later or never.")
	take.add_theme_font_size_override("font_size", UITheme.FS_HEAD)
	take.custom_minimum_size = Vector2(72, 26)
	take.size_flags_horizontal = Control.SIZE_SHRINK_END
	return take


## Foot of a note: SIGN, then SIGNED once signed, plus DELIVER or OFFLOAD when payable here.
func _offer_foot(c: ContractData, state: String, pay: Array) -> Control:
	if state == "open":
		return _sign_button(c)
	if pay.size() == 2:
		var job: ContractData = pay[0]
		var go := Widgets.button(String(pay[1]), func() -> void:
			Run.deliver_contract(job)
			_refresh())
		go.size_flags_horizontal = Control.SIZE_SHRINK_END
		# SIGN's height, so the note keeps its own
		go.custom_minimum_size = Vector2(0.0, _sign_size().y)
		return go
	var stamp := _SignedStamp.new()
	stamp.screen = _on_screen()
	var room := _sign_size()
	var word := UITheme.pixel_font().get_string_size("SIGNED", HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_HEAD).x
	stamp.custom_minimum_size = Vector2(maxf(room.x, ceilf(word) + 12.0), room.y)
	stamp.size_flags_horizontal = Control.SIZE_SHRINK_END
	return stamp


## How big SIGN is, as laid out in this screen's theme, so the stamp that takes
## its place takes exactly its room and the note keeps its height. Measured once.
var _sign_measured := Vector2.ZERO
func _sign_size() -> Vector2:
	if _sign_measured == Vector2.ZERO:
		var probe := _sign_button(ContractData.new())
		probe.visible = false
		add_child(probe)
		_sign_measured = probe.get_combined_minimum_size()
		remove_child(probe)
		probe.free()
	return _sign_measured


## SIGNED in the board's own stamp: an ink outline, drawn not to look like a button.
class _SignedStamp extends Control:
	var screen := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var col := PostingBoard.LCD_ALARM if screen else PostingBoard.RED
		var r := Rect2(Vector2(1.0, 1.0), size - Vector2(2.0, 2.0))
		if screen:
			draw_rect(r, Color(0, 0, 0, 0.5))
		draw_rect(r, Color(col.r, col.g, col.b, 0.85), false, 2.0)
		var f := UITheme.pixel_font()
		var t := "SIGNED"
		var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_HEAD).x
		var base := floorf((size.y + f.get_ascent(UITheme.FS_HEAD) - f.get_descent(UITheme.FS_HEAD)) * 0.5)
		draw_string(f, Vector2(floorf((size.x - w) * 0.5), base), t, HORIZONTAL_ALIGNMENT_LEFT, -1,
			UITheme.FS_HEAD, Color(col.r, col.g, col.b, 0.85))


## Work done and ready to hand in: a yellow sticky note, because it is the one
## thing on the board waiting for you.
func _deliver_row(c: ContractData, label: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	var who := UITheme.body(DB.manufacturer_name(c.manufacturer).to_upper(),
		_manufacturer_ink(c.manufacturer, 0.5), UITheme.FS_SMALL)
	who.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(who)
	box.add_child(UITheme.body("%d CR" % c.pay, _ink(&"pay"), UITheme.FS_HEAD))
	var said := UITheme.body("READY TO HAND IN.", _ink(&"ink"), UITheme.FS_SMALL)
	said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(said)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(sp)
	var go := Widgets.button(label, func() -> void:
		Run.deliver_contract(c)
		_refresh())
	go.size_flags_horizontal = Control.SIZE_SHRINK_END
	box.add_child(go)
	return _note(NOTE_STICKY, box)


## Your own ship's figures, on the same slab the hull for sale gets, floated
## directly above your ship by `_float_slab`.
func _add_mine_slab(box: Control, against: HullData) -> void:
	if Run.hull == null:
		return
	_mine_slab = _offer_slab(Run.hull, against, Run.display_name().to_upper())
	_mine_slab.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_mine_slab.z_index = SLAB_Z
	_mine_slab.visible = false
	box.add_child(_mine_slab)


## Pointing at your own ship swaps in its figures.
func _on_mine_hover(on: bool) -> void:
	if _mine_slab != null and is_instance_valid(_mine_slab):
		_mine_slab.visible = on and _cutaway == null
	if not on and _mine_outline != null and is_instance_valid(_mine_outline):
		_mine_outline.visible = false
		if _mine_hit != null and is_instance_valid(_mine_hit):
			_mine_hit.mouse_default_cursor_shape = Control.CURSOR_ARROW


## Rect2() until the deck is up and still; the first-visit hints (`Hints.DECK_HINTS`) point at it.
## Why: docs/why/StationScreen.md#deck-subject
func deck_subject(tab: StringName) -> Rect2:
	var page: Control = _pages.get(tab)
	if page == null or not page.is_visible_in_tree():
		return Rect2()
	match tab:
		&"services":
			if _scene == null or not is_instance_valid(_scene) or not _scene.is_visible_in_tree() or _scene.drones == null:
				return Rect2()
			var r := _scene.drones.services_rect()
			return _scene.get_global_transform() * r if r.has_area() else Rect2()
		&"stock":
			var sh: Control = _shop.shelf_node if _shop != null else null
			if sh == null or not is_instance_valid(sh) or not sh.is_visible_in_tree():
				return Rect2()
			return sh.get_global_transform() * Rect2(Vector2.ZERO, sh.size)
		&"hold":
			if _sell_desk == null or not _sell_desk.is_visible_in_tree():
				return Rect2()
			return _sell_desk.get_global_rect()
		&"work":
			if _work == null or not _work.is_visible_in_tree() or (_board_lamp != null and not _board_lamp.lit()):
				return Rect2()
			var r := Rect2()
			for c in _work.get_children():
				var k := c as Control
				if k != null and k.is_visible_in_tree() and k.size.x > 0.0:
					r = k.get_global_rect() if not r.has_area() else r.merge(k.get_global_rect())
			return r
		&"bench":
			if _bench_clip == null or not _bench_clip.is_visible_in_tree() or _lab == null:
				return Rect2()
			# (the scan opens the screen's holder a line at a time: whole once it has passed)
			if _bench_clip.size.y < _lab.glass_rect().size.y - 0.5:
				return Rect2()
			return _bench_clip.get_global_rect()
	return Rect2()


## Whether your ship can be opened up here now: on the yard, nothing over it.
func cutaway_ready() -> bool:
	return Run.hull != null and _cutaway == null and _mine_view != null and is_instance_valid(_mine_view) \
		and _mine_view.is_visible_in_tree() and (Router.dock == null or not is_instance_valid(Router.dock))


## The pointer on your ship in the yard: the amber outline on its own pixels, and
## a click opens it up -- or, when it cannot be, the thud a dead button makes.
func _on_mine_input(e: InputEvent) -> void:
	if _mine_view == null or not is_instance_valid(_mine_view):
		return
	var mev := e as InputEventMouse
	if mev == null:
		return
	var at := _mine_view.get_global_transform().affine_inverse() * (_mine_hit.get_global_transform() * mev.position)
	var on := CutawayView.on_hull(_mine_view, at)
	var ready := cutaway_ready()
	if _mine_outline != null and (on and ready) != _mine_outline.visible:
		_mine_outline.visible = on and ready
		_mine_outline.queue_redraw()
	_mine_hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if on and ready else Control.CURSOR_ARROW
	var mb := e as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT or not on:
		return
	_mine_hit.accept_event()
	if not ready:
		denied_clicks += 1
		Audio.denied()
		return
	# THE PAD LOADED: the move, not the cutaway. Your things on the pad are what
	# holds UNDOCK shut and the cutaway cannot see them (`Router.show_transfer`).
	if not Run.pad.is_empty():
		Router.show_transfer()
		return
	open_cutaway()


var _edge: _YardEdge = null
## how long the elevator takes to slide back in once your hull is down: a dial,
## `ZoomLadder.ELEVATOR_S`
## undocking: how long the elevator takes to go, before your ship lifts off (s)
## (three fifths of the time it takes to come back in, `ZoomLadder.ELEVATOR_S`)
static func undock_elev_s() -> float:
	return ZoomLadder.ELEVATOR_S * 0.6
## End speed 2.4 so undocking leaves at about the hull's LOCAL exit speed, 1130 px a second.
## Why: docs/why/StationScreen.md#yard-flight-speed
const YARD_M := 2.4


## Your ship's speed at the yard's left edge, for a flight of `dur` s (screen px
## a second): what the pan hands it, or takes from it.
func ladder_track_speed(dur: float) -> float:
	if _lad.is_empty():
		return 0.0
	return YARD_M * float(_lad.off) / maxf(dur, 0.001)
class _YardEdge extends Node:
	var screen: StationScreen

	## Whether the ladder is panning this screen in or out right now.
	func _panning() -> bool:
		return ZoomLadder.busy() and ZoomLadder.active._pan_view != null \
			and is_instance_valid(ZoomLadder.active._pan_view) and ZoomLadder.active._pan_view.visible
	var _rest_x := NAN
	var _on := false
	var _clipped: Array = []

	func _process(_d: float) -> void:
		var r := screen._rail if screen != null else null
		var sc: YardScene = screen._scene if screen != null else null
		if r == null or not is_instance_valid(r) or sc == null or not is_instance_valid(sc):
			return
		# (the elevator's own place: the ladder's note of it, or learned while it
		# stands in it)
		if not screen._lad.is_empty() and not is_nan(float(screen._lad.get("rail_x", NAN))):
			_rest_x = float(screen._lad.rail_x)
		elif (screen._lad_tw == null or not screen._lad_tw.is_valid()) and screen._rail_slide == null \
				and (screen._cutaway == null or not is_instance_valid(screen._cutaway)):
			_rest_x = r.position.x
		# (not while the cutaway has the yard zoomed: the hall is not where it was)
		var away := not is_nan(_rest_x) and r.position.x < _rest_x - 0.5 \
			and (screen._cutaway == null or not is_instance_valid(screen._cutaway))
		# The elevator fully away is not drawn, so the pan and flight never show it through.
		var gone := away and r.position.x <= _rest_x - r.size.x + 0.5
		# (and through the whole flight in, wherever its row puts it back for a
		# frame while the screen is laid out)
		if not screen._lad.is_empty() and not bool(screen._lad.get("out", false)):
			gone = true
		# (by its alpha, not `visible`: hidden, the row it stands in would close up)
		r.modulate.a = 0.0 if gone else screen._rail_a * screen._lab_rail_a
		r.z_index = 2 if screen._lab_lift else (1 if away and not gone and not _panning() else 0)
		if away == _on:
			return
		_on = away
		r.queue_redraw()
		# The yard's hall runs on into the elevator's
		# column, under the ships, with the elevator over it.
		sc.set_edge(away)
		# (every box between the yard and this screen that would clip it)
		if away:
			_clipped = []
			var c: Node = sc
			while c != null and c != screen:
				if c is Control and (c as Control).clip_contents:
					_clipped.append(c)
					(c as Control).clip_contents = false
				c = c.get_parent()
		else:
			for c in _clipped:
				if is_instance_valid(c):
					(c as Control).clip_contents = true
			_clipped = []


# ------------------------------------------------------------ the zoom ladder
# The station is the closest of four distances: the camera stays, its picture and your ship move.
func ladder_ready() -> bool:
	return _tab != &"services" or (_mine_view != null and is_instance_valid(_mine_view))


func ladder_picture() -> Rect2:
	if _scene != null and is_instance_valid(_scene) and _scene.is_visible_in_tree():
		return _scene.get_global_rect()
	return get_global_rect()


func ladder_scale() -> float:
	return 1.0


func ladder_anchor(_other: int, seam: int, design: String) -> Vector2:
	var h := ladder_hull()
	if (seam == 0 or (seam == 3 and (design == "B" or design == "D"))) and h.size.x > 1.0:
		return h.get_center()
	return ladder_picture().get_center()


## 3B undocking moves the yard first: the elevator out, then your ship off its
## stands and out to the left.
func ladder_pre(_target: int, seam: int, design: String) -> float:
	_lad_going = seam == 3 and (design == "B" or design == "D") and _mine_view != null and is_instance_valid(_mine_view)
	return 1.0 if _lad_going else 0.0


var _lad_going := false


## k is 1 with the hull off left and the elevator gone; the elevator slides back once it settles.
## Why: docs/why/StationScreen.md#yard-flight-in
var _lad := {}
var _lad_tw: Tween = null


func ladder_cam_begin(_other: int, seam: int, design: String) -> void:
	_lad = {}
	var going := _lad_going
	_lad_going = false
	if not (seam == 3 and (design == "B" or design == "D")) or _mine_view == null or not is_instance_valid(_mine_view):
		return
	# (the elevator still sliding in from the last dock: in its place first)
	rail_land()
	var rail_x := NAN
	if _rail != null and is_instance_valid(_rail):
		rail_x = _rail.position.x
	# (3B: from off the picture -- past the yard's own hall run on to the left --
	# so the yard is seen empty first, and your ship comes in)
	var past := YardScene.EDGE_W + 8.0 if design == "B" else 0.0
	_lad = {"pos": _mine_view.position, "rail_x": rail_x, "out": going,
		"off": _mine_view.position.x + float(_mine_view.size.x) + 24.0 + past, "design": design}
	# (docking: the elevator unseen from the first frame -- `_YardEdge` keeps it so)
	if not going and _rail != null and is_instance_valid(_rail):
		_rail.modulate.a = 0.0
	if _scene != null:
		_scene.hide_mine = true
		_scene.queue_redraw()


func ladder_cam(k: float) -> void:
	if _lad.is_empty() or not is_instance_valid(_mine_view):
		return
	if bool(_lad.out):
		ladder_pre_cam(k)
		return
	# The hull enters over the last 70% of the way, slowing, then settles onto its stands.
	var q := clampf((1.0 - k) / 0.7 - (0.3 / 0.7), 0.0, 1.0) if k < 1.0 else 0.0
	# (3B: the ladder gives the yard its own stretch after the pan, all of it
	# the flight in)
	if String(_lad.get("design", "")) == "B":
		q = clampf(1.0 - k, 0.0, 1.0)
	var b_motion := String(_lad.get("design", "")) == "B"
	# (3B: the ladder shapes the one motion -- `q` is already where it is)
	var fly := q if b_motion else 1.0 - pow(1.0 - q, 3.0)
	var settle := clampf((q - 0.7) / 0.3, 0.0, 1.0)
	var lift := 8.0 * (1.0 - settle * settle * (3.0 - 2.0 * settle)) if q < 1.0 else 0.0
	var p0: Vector2 = _lad.pos
	# (once the heavy set-down has it, on the yard's clock: `ladder_yard_t`)
	if _heavy == null:
		_mine_view.position = Vector2(p0.x - float(_lad.off) * (1.0 - fly), p0.y - lift)
	# the elevator stays out of the picture until the hull is down
	if _rail != null and is_instance_valid(_rail) and not is_nan(float(_lad.rail_x)):
		# (out until `ladder_cam_end` slides it back in -- set back at k 0, the
		# last frame of the move, the hall run on into its column blinked off)
		_rail.position.x = float(_lad.rail_x) - (_rail.size.x + 16.0)
	# (the yard's hall run on into the elevator's column from the first frame the
	# yard is up -- not a frame later, when this screen starts processing)
	if _edge != null and is_instance_valid(_edge):
		_edge._process(0.0)


## The landing is heard on the ladder's clock: roar, putter, silence, then the clamps. Reduced
## motion never flies it in, so it is never heard. The flight's path and timing are untouched.
## Why: docs/why/StationScreen.md#landing-sound
const YARD_ROAR_FROM_S := -0.2
## s after the flight starts that the roar gives way to the coughs
const YARD_COUGH_AT_S := 0.75
## s, at least, between the last cough and touchdown
const YARD_QUIET_S := 0.35


## A flameout row whose coughs fit before touchdown, picked at random, else the shortest.
static func yard_flameout(dur: float) -> Array:
	var room := dur - YARD_QUIET_S - YARD_COUGH_AT_S
	var fit: Array[int] = []
	var short := 0
	for r in ShipView.FLAMEOUTS.size():
		if ShipView.sputter_s(r) <= room + 0.0001:
			fit.append(r)
		if ShipView.sputter_s(r) < ShipView.sputter_s(short):
			short = r
	if not fit.is_empty():
		return [fit[randi() % fit.size()], YARD_COUGH_AT_S]
	return [short, maxf(dur - YARD_QUIET_S - ShipView.sputter_s(short), 0.0)]


func ladder_yard_t(t: float, dur: float) -> void:
	if _lad.is_empty() or bool(_lad.out) or not is_instance_valid(_mine_view):
		return
	# (a press that ended the move at once: on its stands, nothing heard --
	# `ladder_cam_end` hushes whatever had begun)
	if ZoomLadder.active != null and ZoomLadder.active._cut:
		return
	# (the ladder steps the pan twice on its first frame: one step a time)
	if is_equal_approx(t, float(_lad.get("yard_t", NAN))):
		return
	_lad["yard_t"] = t
	_lad["yard_dur"] = dur
	# THE HEAVY SET-DOWN (`ShipLift.land_at`): in high on the mains, a hover over
	# the stands on the jets, a slow descent in its smoke, the stands take the weight.
	var L := _deck_lift()
	if L != null:
		L.land_at(t)
	if not _lad.has("row"):
		var pick := yard_flameout(dur)
		_lad["row"] = pick[0]
		_lad["cough_at"] = pick[1]
	var row := int(_lad.row)
	var cough_at := float(_lad.cough_at)
	if t >= dur:
		_yard_engines_out()
		Router.pay_dock_clamps()
		return
	if t < YARD_ROAR_FROM_S:
		return
	if t < cough_at:
		if not bool(_lad.get("burning", false)):
			_lad["burning"] = true
			_mine_view.burn(true)
		Audio.ship_thrust(SectorScreen.DOCK_BURN_LEVEL)
		return
	if not _lad.has("cough_clip"):
		_lad["burning"] = false
		_mine_view.burn(false)
		Audio.ship_thrust_off()
		_lad["cough_clip"] = _mine_view.sputter(row)
		# the mains cough out and stay dark; the belly jets hold it (`ShipLift.land_at`)
		_mine_view.dark_idle = true
		_mine_view.refresh()
		Audio.play(_lad.cough_clip as StringName, 0.0, 0, Audio.SHIP_DB + linear_to_db(SectorScreen.DOCK_BURN_LEVEL), 1.0,
			ShipView.sputter_from_s(row) + (t - cough_at))
	_mine_view.sputter_step(t - cough_at)


## The landing's engines out: the burn and the coughs over, the idle drawn
## (`hush`: and whatever of them is still in the air faded out, a press).
func _yard_engines_out(hush: bool = false) -> void:
	if not is_instance_valid(_mine_view):
		return
	if bool(_lad.get("burning", false)):
		_lad["burning"] = false
		_mine_view.burn(false)
		Audio.ship_thrust_off()
	_mine_view.sputter_stop()
	# (down on its stands: its engines at the idle again, as a berthed hull's are)
	_mine_view.dark_idle = false
	_mine_view.refresh()
	if hush:
		Audio.ship_thrust_off()
		if _lad.has("cough_clip"):
			var hc: Array[StringName] = [_lad.cough_clip as StringName]
			Audio.hush(hc)


func ladder_cam_end() -> void:
	ladder_hide_hull(false)
	if _heavy != null:
		_heavy.release()
		_heavy = null
	# (the clamps, if the landing did not get to them: a press, or a dock that
	# flew no hull in)
	Router.pay_dock_clamps()
	if _lad.is_empty():
		return
	# (a press mid-dock: the landing's roar and coughs hushed at once)
	if not bool(_lad.get("out", false)):
		_yard_engines_out(ZoomLadder.active != null and ZoomLadder.active._cut)
	if is_instance_valid(_mine_view):
		_mine_view.position = _lad.pos
	if _scene != null and is_instance_valid(_scene):
		_scene.hide_mine = false
		_scene.queue_redraw()
	var rx := float(_lad.rail_x)
	_lad = {}
	if _rail == null or not is_instance_valid(_rail) or is_nan(rx):
		return
	# AND THEN THE ELEVATOR SLIDES IN, as the game's other panels do (a press
	# that cut the dock short wants the berth, not the slide: it is there)
	var cut := ZoomLadder.active != null and ZoomLadder.active._cut
	_rail.position.x = rx
	if Router.animating() and not cut:
		_rail_in()


## The elevator slides in as a `PanelSlide` with its
## own ground, so landing no longer pops the column.
## Why: docs/why/StationScreen.md#elevator-slide
var _rail_slide: PanelSlide = null
var _rail_back: Control = null
var _rail_block: Control = null
var _rail_back_x0 := 0.0
var _rail_rest_x := 0.0


## The column's ground at rest, cut from the panel's own style and drawn just under the elevator.
class _RailBack extends Control:
	var panel_rect := Rect2()
	var style: StyleBox = null

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), RenderingServer.get_default_clear_color(), true)
		if style != null and panel_rect.size.x > 0.0:
			draw_style_box(style, panel_rect)


## Takes every press over the moving elevator, and lands it.
class _RailBlock extends Control:
	var screen: StationScreen

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			accept_event()
			screen.rail_land()


func _rail_in() -> void:
	if _rail == null or not is_instance_valid(_rail):
		return
	_rail_land_now()
	_rail_rest_x = _rail.position.x
	var me := get_global_transform().affine_inverse()
	var rr := _rail.get_global_rect()
	# (where the yard's picture starts, and its panel round it: the column's
	# ground runs up to the picture, the panel's edge included)
	var yard_l := rr.end.x + 8.0
	var panel := Rect2()
	var panel_style: StyleBox = null
	if _scene != null and is_instance_valid(_scene) and _scene.is_visible_in_tree():
		yard_l = _scene.get_global_rect().position.x
		var pc := _scene.get_parent()
		while pc != null and pc != self:
			if pc is PanelContainer:
				panel = (pc as Control).get_global_rect()
				panel_style = (pc as Control).get_theme_stylebox(&"panel")
				break
			pc = pc.get_parent()
	var top := rr.position.y
	var bot := rr.end.y
	if panel.size.y > 0.0:
		top = minf(top, panel.position.y)
		bot = maxf(bot, panel.end.y)
	var g := Rect2(Vector2(minf(0.0, rr.position.x) - 2.0, top), Vector2.ZERO)
	g.end = Vector2(yard_l, bot)
	# (a box that clips, round the ground that draws: the panel's style is drawn
	# whole and only its edge up to the yard is kept)
	var back := Control.new()
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.clip_contents = true
	back.position = me * g.position
	back.size = g.size
	var ground := _RailBack.new()
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ground.size = g.size
	ground.style = panel_style
	ground.panel_rect = Rect2(panel.position - g.position, panel.size)
	back.add_child(ground)
	# (under the elevator, over the yard: the elevator is lifted while it is
	# away, `_YardEdge`, and this before it in the tree at the same height)
	back.z_index = 1
	add_child(back)
	move_child(back, 0)
	_rail_back = back
	_rail_back_x0 = back.position.x
	var blk := _RailBlock.new()
	blk.screen = self
	blk.mouse_filter = Control.MOUSE_FILTER_STOP
	blk.position = back.position
	blk.size = back.size
	add_child(blk)
	_rail_block = blk
	# (all of it off the view's left edge at the start, and in whole pixels)
	var ps := PanelSlide.new()
	add_child(ps)
	ps.setup(_rail, &"side", Vector2(-roundf(g.end.x + 2.0), 0.0), 0.0, null)
	_rail_slide = ps
	_rail_t = 0.0
	_rail_step(0.0)
	var tick := _RailTick.new()
	tick.screen = self
	ps.add_child(tick)


## The slide's clock: the game's, or the ladder's step where a harness steps it
## (`ZoomLadder.fixed_dt`), as the moves before it run on.
var _rail_t := 0.0


class _RailTick extends Node:
	var screen: StationScreen

	func _process(delta: float) -> void:
		var dt := ZoomLadder.fixed_dt if ZoomLadder.fixed_dt > 0.0 else delta
		screen._rail_t += dt
		var q := clampf(screen._rail_t / maxf(ZoomLadder.CALM_SLIDE_S, 0.001), 0.0, 1.0)
		screen._rail_step(q)
		if q >= 1.0:
			screen._rail_land_now()


func _rail_step(q: float) -> void:
	if _rail_slide == null or not is_instance_valid(_rail_slide):
		return
	_rail_slide.set_k(ZoomLadder._calm_slide_curve(q))
	if _rail_back != null and is_instance_valid(_rail_back):
		_rail_back.position.x = _rail_back_x0 + (_rail.position.x - _rail_slide.rest.x)


## The elevator in its place now (a press on it while it slides; another move).
func rail_land() -> void:
	if _lad_tw != null and _lad_tw.is_valid():
		_lad_tw.kill()
	_rail_land_now()


func _rail_land_now() -> void:
	var was := _rail_slide != null or _rail_back != null
	if _rail_slide != null and is_instance_valid(_rail_slide):
		_rail_slide.set_k(1.0)
		_rail_slide.finish()
	_rail_slide = null
	for c: Control in [_rail_back, _rail_block]:
		if c != null and is_instance_valid(c):
			c.queue_free()
	_rail_back = null
	_rail_block = null
	# (the yard's hall out of the column on the same frame the elevator stands
	# in it, not the next, when `_YardEdge` would see it there)
	if was and _edge != null and is_instance_valid(_edge):
		_edge._process(0.0)


## Undocking (3B): k 0 to 1 is the elevator out, then your ship's heavy lift off
## its stands and away to the RIGHT (Jon, Nov 12: L1 here as on the front door),
## then -- F -- the empty yard's beat and its fade, the smoke still drifting.
## Why: docs/why/ShipLift.md#deck
func ladder_pre_cam(k: float) -> void:
	if _lad.is_empty() or not is_instance_valid(_mine_view):
		return
	var f := ZoomLadder.seam3_fade() == "F"
	var tt := k * (ZoomLadder.UNDOCK_YARD_S + (ZoomLadder.YARD_BEAT_S + ZoomLadder.YARD_FADE_S if f else 0.0))
	var a := clampf(tt / undock_elev_s(), 0.0, 1.0)
	if _rail != null and is_instance_valid(_rail) and not is_nan(float(_lad.rail_x)):
		_rail.position.x = float(_lad.rail_x) - (_rail.size.x + 16.0) * (a * a * (3.0 - 2.0 * a))
	var L := _deck_lift()
	if L != null:
		L.lift_at(maxf(tt - undock_elev_s(), 0.0) if tt > undock_elev_s() else 0.0)


## THE HEAVY LIFT on the deck (`ShipLift`), made once per move with your hull at
## rest on its stands: smaller than the front door's, the hull shivering rather
## than the yard (the camera holds still on the deck).
var _heavy: ShipLift = null


func _deck_lift() -> ShipLift:
	if _heavy != null:
		return _heavy
	if _scene == null or not is_instance_valid(_scene) or _scene.placed.is_empty() or (_scene.placed[0] as Dictionary).is_empty():
		return null
	var Q: Dictionary = _scene.placed[0]
	var L := ShipLift.new()
	L.k = DECK_LIFT_K
	L.floor_y = float(Q["floor"])
	L.rise = float(ShipLift.RISE_PX.get(Run.hull.weight if Run.hull != null else HullData.Weight.MEDIUM, 46.0)) * DECK_LIFT_K
	L.exit_px = float(YardScene.W) + ShipLift.EXIT_CLEAR - float(Q["x0"])
	L.in_px = float(_lad.get("off", 300.0))
	# in high, its top 42 rows over the wall's foot: just under the lamp strings
	# along the wall, well clear of the stands (Jon, Nov 12: "far too low")
	L.approach_px = clampf(float(Q["top"]) - (float(YardScene.doc().get("wallrow", 207)) - 42.0), 30.0, 90.0)
	L.life = _scene.life
	L.light = _scene.light
	L.shiver_hull = true
	L.plume_k = 0.8
	# (out under the ceiling's lamp boxes, within the hall)
	L.ceiling_y = 64.0
	var sc := _scene
	L.sink = func(rows: int) -> void: sc.sink_mine = rows
	var v := _mine_view
	var p0: Vector2 = _lad.pos
	v.position = p0
	L.setup(v, _scene, _scene._ships.get_index())
	_heavy = L
	return L


## The deck's hulls stand this much smaller than the front door's front row.
const DECK_LIFT_K := 0.75


## The berth's UI leaves before the camera moves; the
## elevator is left alone when it is the move's own.
var _rail_a := 1.0


func ladder_chrome(k: float) -> void:
	if _scene != null and is_instance_valid(_scene):
		_scene.mine_a = 1.0 - k
		_scene.queue_redraw()
	var own := not _lad.is_empty() or (_lad_tw != null and _lad_tw.is_valid()) or _rail_slide != null
	# (where the move owns the elevator it is drawn whole, its slide the arrival)
	_rail_a = 1.0 if own else 1.0 - k
	if _rail != null and is_instance_valid(_rail) and _rail.modulate.a > 0.0:
		_rail.modulate.a = _rail_a


func ladder_hull() -> Rect2:

	if _mine_view == null or not is_instance_valid(_mine_view) or _mine_view._tex == null \
			or not _mine_view.is_visible_in_tree() and not _lad_hid:
		return Rect2()
	var g := _mine_view.get_global_transform()
	return Rect2(g * _mine_view.canvas_to_local(Vector2.ZERO),
		Vector2(_mine_view._w, _mine_view._h) * float(_mine_view._k) * g.get_scale())


func ladder_hull_texture() -> Texture2D:
	return _mine_view._tex if _mine_view != null and is_instance_valid(_mine_view) else null


var _lad_hid := false


func ladder_hide_hull(on: bool) -> void:
	if _mine_view == null or not is_instance_valid(_mine_view) or on == _lad_hid:
		return
	_lad_hid = on
	_mine_view.visible = not on


## Open your ship up in the yard. Public for the harnesses.
func open_cutaway() -> CutawayView:
	if not cutaway_ready():
		return null
	# (the elevator still sliding in: in its place, so the cutaway takes it from
	# there)
	rail_land()
	if _mine_outline != null:
		_mine_outline.visible = false
	if _mine_slab != null and is_instance_valid(_mine_slab):
		_mine_slab.visible = false
	_cutaway = CutawayView.open_over(self, _mine_view)
	# The yard itself zooms, without the name sign or
	# floor reflection, which would ghost under the blur.
	_cutaway.scenes = [_scene]
	# (its panel takes the elevator's place: the elevator slides out first)
	if _rail != null:
		_cutaway.slide_out = [_rail]
	if _scene != null:
		_scene.hide_mine = true
		_scene.queue_redraw()
	# THE STANDS COME WITH IT: where the yard seated them, from the hull's ink
	var P: Dictionary = _scene.placed[0] if _scene != null else {}
	if not P.is_empty():
		var corner := _mine_view.position + Vector2((P["ink"] as Rect2i).position)
		for sp: Dictionary in P["supports"]:
			_cutaway.stands.append({tex = sp["tex"], at = Vector2(float(sp["x"]), float(sp["y"])) - corner})
	_cutaway.closed.connect(func() -> void:
		_cutaway = null
		if _scene != null and is_instance_valid(_scene):
			_scene.hide_mine = false
			_scene.queue_redraw()
			_yard_ships(_yard_hull))
	return _cutaway


## One number per station, so it looks the same each visit and the next one along does not.
func _place_seed(n: MapGen.MapNode) -> int:
	return absi(hash([Run.galaxy_seed, n.index]))


## The same two fields for every room (development, holder) keep every deck one station.
func _dress_room(room: StationRoom, n: MapGen.MapNode) -> void:
	if room == null or not is_instance_valid(room) or n == null:
		return
	room.dev = int(n.development)
	room.manufacturer = n.manufacturer
	room.place_seed = _place_seed(n)
	room.queue_redraw()
	_hang_banners(room, n, room.banner_spots())


## Floats above the ship you point at, in the wall band that covers neither ship.
## Why: docs/why/StationScreen.md#figures-slab
func _float_slab(slab: Control, v: ShipView, at: Vector2) -> void:
	if slab == null or not is_instance_valid(slab):
		return
	if v == null or not is_instance_valid(v) or _scene == null:
		return
	var ink := v.ink_rect()
	var need := slab.get_combined_minimum_size()
	var mid := at.x + float(ink.position.x) + float(ink.size.x) * 0.5
	var x := clampf(mid - need.x * 0.5, 8.0, maxf(8.0, _scene.size.x - need.x - 8.0))
	var y := maxf(4.0, at.y + float(ink.position.y) - need.y - 8.0)
	slab.offset_left = roundf(x)
	slab.offset_top = roundf(y)
	slab.offset_right = slab.offset_left + need.x
	slab.offset_bottom = slab.offset_top + need.y


## Long and narrow: the rail's flag blown up in proportion read as a wall sign, not hung colours.
## Why: docs/why/StationScreen.md#hung-banners
const BANNER_K := 2.0
const BANNER_LEN := 148.0
const BANNER_GAP := 6.0
const BANNER_ROD := Color("#3d5273")


## Banners moved from the rail into the rooms, still
## real `ChassisSelect.Banner`s with their readouts.
## Why: docs/why/StationScreen.md#hung-banners
func _hang_banners(room: Control, n: MapGen.MapNode, spots: Array) -> void:
	if room == null or not is_instance_valid(room):
		return
	for kid in room.get_children():
		if kid.has_meta(&"station_banner"):
			room.remove_child(kid)
			kid.queue_free()
	if n == null or spots.is_empty():
		return
	var marks: Array[StringName] = []
	for mid in n.berths:
		if DB.manufacturers.has(mid):
			marks.append(mid)
	if marks.is_empty():
		return
	var bw := float(ChassisSelect.Banner.UNITS_W) * BANNER_K
	var bh := BANNER_LEN
	var span := float(marks.size()) * bw + float(marks.size() - 1) * BANNER_GAP
	for spot: Vector2 in spots:
		var bar := ColorRect.new()
		bar.color = BANNER_ROD
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.set_meta(&"station_banner", true)
		_anchor_at(bar, spot.x, -span * 0.5 - 6.0, spot.y - 4.0, span + 12.0, 3.0)
		room.add_child(bar)
		for i in marks.size():
			var mid2 := marks[i]
			var mk: ManufacturerData = DB.manufacturers.get(mid2)
			var fl := ChassisSelect.Banner.new()
			fl.s = BANNER_K
			fl.custom_minimum_size = Vector2(bw, bh)
			fl.manufacturer = mid2
			fl.mark = mk.colour
			fl.field = mk.field
			fl.set_meta(&"station_banner", true)
			_anchor_at(fl, spot.x, -span * 0.5 + float(i) * (bw + BANNER_GAP), spot.y, bw, bh)
			room.add_child(fl)


## Pin a control to a horizontal fraction of its parent, at a fixed size.
func _anchor_at(c: Control, frac_x: float, dx: float, top: float, w: float, h: float) -> void:
	c.anchor_left = frac_x
	c.anchor_right = frac_x
	c.anchor_top = 0.0
	c.anchor_bottom = 0.0
	c.offset_left = roundf(dx)
	c.offset_right = roundf(dx) + w
	c.offset_top = top
	c.offset_bottom = top + h


## Holder first, then the place's own flavour; at most three, as the board has three spots.
## Why: docs/why/StationScreen.md#board-posts
func _board_posts(n: MapGen.MapNode) -> Array[StringName]:
	var out: Array[StringName] = []
	if n == null:
		return out
	for mid in n.berths:
		if DB.manufacturers.has(mid) and out.size() < 3:
			out.append(mid)
	# A DOCK DESK hangs its notice first too: it is who posts the work here.
	var desk := Contracts.dock_desk(n)
	if desk != &"" and out.is_empty():
		out.append(desk)
	match n.region:
		MapGen.Region.LAWLESS:
			if not out.has(&"redline") and out.size() < 3:
				out.append(&"redline")
		MapGen.Region.COSMOPOLITAN:
			for k: int in [3, 5]:
				var mid2: StringName = DB.STARTABLE[(n.index * k + k) % DB.STARTABLE.size()]
				if not out.has(mid2) and out.size() < 3:
					out.append(mid2)
	return out

