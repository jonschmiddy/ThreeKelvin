class_name StationScreen
extends Control

## Stations are paid campfires. Every service costs credits, and credits are the same
## currency you would rather spend on modules — that tension IS the difficulty.
##
## A station is now four things rather than two: a shelf, a service desk, a
## BUYER for what is in your hold, and — where the place is developed enough to
## have a laboratory — a fabricator. Every price on the screen comes from
## `Market` or `Fabricator`, and none of them is stored: a price is a function of
## this place and that part, so there is nothing here to drift, to save, or to
## come back from a save as a discount.

var _header: RichTextLabel
## The door. Held as a member because whether it opens is run state -- see
## `_refresh_undock` -- and the rail that builds it is built once.
var _undock: Button
var _bench: VBoxContainer
## The recipes' holder on the lab's screen, which the power-on's scan opens.
var _bench_clip: Control
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
## YOUR SHIP OPENED UP, in the yard (Jon: "Couldn't clicking on your ship while
## in the shipyard do this?"): the same cutaway LOCAL opens, over the station,
## the yard itself zoomed onto the ship on its stands. The refit a berth used
## to send you to the SHIP page for (that page has no tab now).
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
## The Shipyard: Jon's hall for this level, the ships on their stands, the
## services on drones over yours and the deal on a TV (`YardScene`). Built once
## per visit and kept: a purchase moves the drones, it does not rebuild the yard.
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
## What kind of place this is, in its own words. Fills the column under the
## services with something worth reading rather than with nothing.
## The count line under each deck name, refreshed with everything else.
var _deck_note: Dictionary = {}

var _pages: Dictionary = {}
var _tabs: Dictionary = {}
var _tab: StringName = &"services"
## Which tabs this station actually has. An unbranded desk posts no work and a
## station with no laboratory builds nothing.
var _tabs_on: Dictionary = {}
## How tall the hull portrait is. Enough for a heavy at 2x without the panel
## growing past the service column beside it.
## Sized off the deepest hull plus the bob, at 1x. See ShipScreen for why the
## magnification came down. 140 rows of heavy canvas and the bob's four: the
## heavy grew from 100 rows when the hull art was redrawn, and this number is
## derived from it rather than chosen, so it moves whenever that does.
##
## WITH SIX ROWS OF SLACK, matching ShipScreen. The bare derivation is 144 -- the
## heavy's 140-row canvas plus the bob's four -- and at exactly 144 this sits on
## a knife edge: `ShipView._resize_canvas` sets `clip_contents` when the canvas
## is TALLER than the view, so any hull one row deeper, or one call asking for a
## bob of three, starts clipping the ship's top and bottom rows as it bobs. Rows
## winking in and out at the edges of a moving sprite is not a loud failure; it
## reads as the ship shimmering.
func setup() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# THE ROOM YOU ARE STANDING IN is chosen by Router._swap now, which is the
	# one place that sees every screen change -- see `_room_for` for why the
	# station could not keep doing it itself once open space had a room too.
	_build()
	Sig.resources_changed.connect(_refresh)
	Sig.ship_changed.connect(_refresh)
	# Somebody else bought something off this shelf. The stock is one list the
	# whole party is standing in front of, so it has to empty while you watch
	# rather than the next time you happen to reopen the screen.
	Sig.party_map_changed.connect(_refresh)
	Sig.map_changed.connect(_refresh)
	_stock_up()
	_inspect()
	_refresh()

## FIVE PAGES, NOT FIVE PANELS STACKED.
##
## A station does five things — repair you, post work, sell you parts, buy what
## you are carrying, and build things where there is a laboratory — and all five
## were on screen at once in one scrolling column. At a developed station that is
## a service desk, two contracts, four shelf parts, twelve hold slots and a
## recipe list, and the player has to scroll past the thing they came in for.
##
## Tabs, because these are five separate ERRANDS rather than five parts of one.
## Nobody buys a gun and sells a plate in the same gesture; they do one, then
## decide. A column implies a reading order that does not exist.
##
## Every page is built once and hidden, not built on demand: the shelf has to be
## able to empty while you are looking at the hold — `Sig.party_map_changed`
## fires when a partner buys something — and a page that only exists while it is
## visible cannot be refreshed when it is not.
const TABS := [
	[&"services", "SERVICES"],
	[&"work", "WORK"],
	[&"stock", "STOCK"],
	[&"hold", "HOLD"],
	[&"bench", "FABRICATOR"],
]

## THE SAME FIVE ERRANDS, DRAWN AS A BUILDING RATHER THAN A TAB STRIP.
##
## A row of five identical buttons says these are five views of one thing. They
## are not: they are five different counters, and the tab strip's real cost is
## that it hides four fifths of the station behind whichever one you are on --
## you cannot see that there is work posted while you are looking at the shelf.
##
## Stacked as DECKS the strip becomes a section through the station, which does
## three things a row cannot. It is always fully visible, so nothing is hidden.
## It has room for a second line, so each deck can say what is on it and how
## much. And it puts your own berth at the bottom of the stack with your ship in
## it, which is the one fact the old screen never showed: you are inside a place
## and the place has a shape.
##
## ORDERED HIGH TO LOW, berth last. The order is not arbitrary and is not the
## TABS order: a player reads the rail downward and arrives at their own ship,
## which is where UNDOCK belongs.
const DECKS := [
	[&"stock", "PROMENADE", "THE SHELF"],
	[&"services", "SHIPYARD", "REPAIRS"],
	[&"hold", "EXCHANGE", "YOUR HOLD"],
	[&"work", "HIRING BOARD", "WORK POSTED"],
	[&"bench", "LABORATORY", "FABRICATOR"],
]
## How wide the section is. Wide enough for "HIRING BOARD" plus a count at
## FS_SMALL without either wrapping, which is what sets it -- not a round number.
const RAIL_W := 156
## How tall one deck cell is. Two lines of FS_SMALL plus the padding that keeps
## the highlight from touching the text.
const DECK_H := 44
## The air above a heading's LABEL BOX, and below it.
##
## TWO NUMBERS, ONE PIXEL APART, AND THAT PIXEL IS THE WHOLE POINT. Centring the
## label's box does not centre the WORD: Silkscreen has an ascent of 17 and a
## descent of 4, so the capitals occupy rows 7 to 17 of a 21-pixel box and sit
## three pixels below its middle. Everything under the row -- the two pixels of
## separation before the rule -- counts as air below as well.
##
## Measured off a real frame rather than reasoned about, twice. The ink was
## landing at rows 105 to 114 in a band running 84 to 126 -- 21 above and 12
## below. At 10 and 11 it came out 16 and 19, still a pixel and a half high; at
## 11 and 10 it is 17 and 18, which is as square as an even band and an odd
## number of leftover rows allows.
const HEAD_TOP := 11
const HEAD_BOT := 10
## Every row on this screen is this tall. One number, so a service, a contract
## and a shelf entry sit on the same rhythm instead of three.
const ROW_H := 22

func _build() -> void:
	# Margin on the outside, once. Without it the header panel runs to x=0 and
	# x=960 and UNDOCK is sliced in half by the window — every panel on this
	# screen sits inside this one box.
	var frame := MarginContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# NO SIDE MARGIN OF ITS OWN. `Main` already insets every screen by 8, and a
	# second inset here put the station on a different left edge from the HUD
	# above it and from every other screen in the game. Uniform means agreeing
	# with the rest of the interface, not being individually tidy.
	for side in ["top", "bottom"]:
		frame.add_theme_constant_override("margin_" + side, 4)
	add_child(frame)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	frame.add_child(root)

	# --- the header, and the way out.
	#
	# UNDOCK is a button on this line rather than a panel of its own on a column
	# of its own. It was three hundred pixels wide inside a three-hundred-pixel
	# rail, for a control that is pressed once and is never the reason anybody
	# opened this screen. Leaving is not an errand.
	_header = RichTextLabel.new()
	_header.bbcode_enabled = true
	_header.fit_content = true
	# WRAPS, AT A WIDTH THIS SCREEN CHOOSES.
	#
	# Both obvious settings are wrong here and they are wrong in opposite
	# directions. Autowrap ON inside a shrinking panel collapses to the narrowest
	# legal width and stacks the line into a column. Autowrap OFF reports the
	# WHOLE UNWRAPPED LINE as a minimum width -- and a Control is never laid out
	# smaller than its minimum, even when anchored -- so the header grew the
	# entire screen to 983 inside a 960 window and every panel on it hung off the
	# right edge. The symptom looked exactly like a missing margin.
	#
	# A fixed width and wrapping is the only combination that is neither.
	_header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_header.custom_minimum_size = Vector2(RAIL_W, 0)
	_header.scroll_active = false
	_header.add_theme_stylebox_override("normal", UITheme.empty())

	# --- WHOSE YARD THIS IS, at the top of the rail.
	#
	# It was a panel of its own across the full width, and it was mostly air: a
	# flag is 39x66 and the two lines of text beside it are 24, so eighty of the
	# hundred and ten pixels that band cost were empty. The rail is already the
	# column that says where you are standing -- the flag belongs at the head of
	# it, over the decks it holds, and the sentence about the place goes on one
	# line above the page it describes.
	#
	# The FLAG rather than the badge, because this is a place and not a listing:
	# the chassis list badges seven manufacturers you are choosing between, and
	# this is the one you are inside of.
	#
	# ONE BANNER PER BERTH, not one for the station. A contested station is held
	# by two or three manufacturers, and the header named all of them in a trade
	# clause while the rail flew one flag -- so the screen said "GLUT
	# SOLARI/CYGNET/KORVAN" and showed a single Solari banner. Flags say it
	# without a sentence.
	#
	# --- the section: the berths, five decks and a berth, down the left
	var rail := VBoxContainer.new()
	_rail = rail
	rail.add_theme_constant_override("separation", 3)
	rail.custom_minimum_size = Vector2(RAIL_W, 0)
	rail.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# THE STATION'S PARTICULARS, WHERE THE BANNERS WERE.
	#
	# The head of the rail held the manufacturers' banners, and the particulars sat
	# in a band across the top of the deck. The banners are in the rooms now --
	# hung in the hangar, pinned to the board, over the till -- so the facts about
	# the place move up here, one to a line, and the deck gets its band back.
	rail.add_child(_header)
	# NO NAMES UNDER THEM. A flag that has to be captioned is a flag that failed,
	# and the manufacturers are named all over this screen anyway -- on every part
	# on the shelf, and in the trade clause at the top of the page.
	rail.add_child(UITheme.hsep())

	# --- THE DECKS ARE FLOORS OF ONE BUILDING.
	#
	# They were five buttons in a column, which tells you which page you are on.
	# A cutaway tells you where you are STANDING, costs the same vertical, and is
	# the only one of the two that makes the station a place. The cells sit OVER
	# the drawing with their plates taken off, so the room shows through and the
	# labels stay on top of it.
	#
	# The berth that used to close this column is gone. It drew your own ship at
	# the bottom of a rail whose whole subject is the station you are standing
	# in, and it was the second place on the screen the hull appeared. What it
	# was using is ninety pixels, and the floors have them now: five rooms at
	# sixty-odd rows each instead of five slivers at forty-six.
	# A LIFT SHAFT: the window clips, and the building inside it is TALLER than
	# the window and slides. Picking a deck moves the station, not a highlight.
	#
	# The overflow is deliberately small -- see `FLOOR_H`. A building that
	# scrolled far enough to hide a floor would be a navigation bar you cannot
	# navigate with: every deck has to stay clickable at every scroll position,
	# so the travel is forty pixels and the worst-clipped floor still shows half
	# of itself.
	var shaft := Control.new()
	shaft.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shaft.clip_contents = true
	shaft.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# SIZED IN A CALLBACK WITH A GUARD, not by anchors. An early version ran the
	# sizing before the shaft had a size and got five floors sharing zero height
	# -- three rendered and two vanished. The guard is the whole fix: nothing is
	# sized until the shaft has been.
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
	# The berth is the bottom of the section, and UNDOCK lives in it.
	#
	# It used to sit in the tab row, grouped left, because pinned to the right of
	# an expanding row it was at the mercy of the window width -- on a 960
	# screenshot it came back sliced in half. In a fixed-width rail that failure
	# cannot happen: the column is RAIL_W whatever the window does, so the button
	# can go where it belongs instead of where it is safe.
	# NO SPACER. There was one here, pushing UNDOCK to the floor of a column
	# whose other children were all fixed height. The building expands now, so
	# the button is already at the bottom -- and an expanding spacer beside an
	# expanding building is two things splitting the slack down the middle,
	# which is exactly what it did: the station got 178 pixels of 362 and read
	# as a cutaway that had been cropped.
	# THE WAY OUT, and nothing else. `_berth_cell` used to hand back a panel with
	# your ship in it and this button under it; the panel is gone and the button
	# is not, because leaving is still a thing you do from here.
	rail.add_child(_undock_cell())

	# --- the pages, all built, one visible
	var body_col := VBoxContainer.new()
	body_col.add_theme_constant_override("separation", 3)
	body_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# ONE LINE, NOT TWO ENDS OF ONE. What this market is short of used to be its
	# own amber label pinned to the right-hand edge, half a screen from the
	# sentence it belongs to -- and read as the station's name rather than as a
	# price signal. It is a clause of the same sentence now, in the same amber, so
	# it is still the one thing on the line you can act on.
	# CENTRED IN THE BAND IT HAS, rather than sitting on the floor of it.
	#
	# The line has about fifty pixels of air between the HUD and the first panel
	# and occupies sixteen of them, and a `RichTextLabel` in a VBox takes its own
	# height and pins to the top of whatever is left -- so the sentence sat low
	# against the panel below and the gap read as a hole under the bar rather
	# than as margin around a line.
	# NO HEADBAND. The station's particulars sat here in a band across the top of
	# the deck; they head the rail now, where the banners were, and every deck is
	# that much taller for it.
	# NO PLACE BLURB HERE AT ALL. It lived in the Yard's right-hand column, where
	# a sentence about megafauna and salvage read as something the repair shop was
	# telling you, and moving it to the top of the page only made it wrong on five
	# decks instead of one. The starchart already says what a system is like, and
	# that is the screen you read before deciding to come here -- by the time you
	# are docked it is a fact about a choice you have already made.

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
	# `-- station tab=stock` opens on a named page. Four of the five are only
	# reachable by clicking, and a screenshot cannot click.
	for a in OS.get_cmdline_user_args():
		if a.begins_with("tab="):
			_tab = StringName(a.split("=")[1])
	_show_tab(_tab)

## Repair, refuel, and the yard that sells whole ships.
##
## TWO PANELS STACKED, not two columns side by side. The services are a list of
## one-line prices and the shipyard is two ships being compared; side by side,
## the ships got half a page to do the harder job in and the price list got the
## other half to print seven short rows in. Stacked, each gets the shape it
## wants -- the list is wide and short, the comparison is wide and tall.
## A panel heading, in a band with its capitals actually centred.
##
## The panel below it is built with NO vertical stylebox margin -- see
## `_flat_panel` -- so this row owns all of the air above the rule and can make
## it symmetric. Left to `panel_with`'s twelve, the top of the band was fixed at
## twelve and the bottom at two, and no amount of centring inside the row could
## make up a ten-pixel head start.
func _heading(title: String) -> MarginContainer:
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_top", HEAD_TOP)
	pad.add_theme_constant_override("margin_bottom", HEAD_BOT)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.name = "Row"
	row.add_child(UITheme.header(title, UITheme.FS_HEAD))
	pad.add_child(row)
	return pad


## A panel with horizontal padding and none at all vertically.
##
## `Widgets.panel_with` gives twelve all round, which is right for a panel whose
## first child is content. These two open with a heading over a rule, and there
## the twelve is a head start the heading cannot spend symmetrically.
func _flat_panel(child: Control) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel",
		# (bg, border, radius, PAD_V, PAD_H) -- vertical first, and getting that
		# order wrong gives a panel with no side padding and twelve top and
		# bottom, which is the opposite of what this is for.
		UITheme.flat(UITheme.PANEL, UITheme.LINE, 0, 0, 12))
	p.add_child(child)
	return p


## THE YARD: one hall per development level, your ship and the one for sale on
## their stands, and the four services flying over yours on the station's drones.
##
## THE SERVICES USED TO BE A TABLE ON TOP OF THE PICTURE, and then four machines
## standing on its floor (`ServiceRig`), which Jon found "feel weird". They are
## drones now, as on the Yard Drones page he judged the Yard on: each carries its
## offer on a screen of its level's make, a click buys, and a drone with nothing
## left to do after a sale says so and flies off. Same four actions, same four
## prices. `YardScene` draws all of it; this deck only feeds it the offers and
## does the buying.
func _page_services() -> Control:
	# NO HEADING, AND NO PANEL AROUND IT EITHER.
	#
	# The word SHIPYARD sat over a rule above a drawn hangar with two ships in
	# it, which is a caption on a photograph of a room you are standing in. The
	# deck rail already says SHIPYARD and the picture already says so.
	#
	# THE YARD IS 766 x 482, the size the Yard Drones page was drawn at and every
	# number in it is in: seven pixels either side of it and one under it are
	# what this panel keeps of the twelve it used to, so the hall Jon passed lands
	# pixel for pixel.
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


## THE SHIPS, stood again only when they changed: your hull and what is fitted
## to it, and whatever is on the blocks.
##
## BOTH SHIPS STAND IN THE HALL NOW, on the level's own stands, with their names
## over them the way the Yard Drones page wrote them -- yours amber, the one for
## sale ice, and what each one is under it. Pointing at either still brings up
## its figures against the other.
func _yard_ships(h: HullData) -> void:
	var key := "%s|%s|%s" % [Run.display_name(), str(Run.hull.get_instance_id()) if Run.hull != null else "",
		str(h.get_instance_id()) if h != null else "none"]
	if Run.hull != null:
		for m in Run.installed:
			key += "|" + str(m)
	if key == _yard_ships_key:
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
		# `ShipBuild.fitted_out` plus a `MountPoints` in display mode is the pair the
		# refit and moving-day screens already use: the view blits the hull and the
		# mounts put the guns on it. PASSIVE: a picture of your ship, not a place
		# to change it.
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


## Pointing at the ship swaps the hint for the numbers.
func _on_ship_hover(on: bool) -> void:
	if _scene_slab != null:
		_scene_slab.visible = on


## The gauges, the mounts and the perks, on a slab dark enough to read over art.
##
## ONE BLOCK WITH A SIGNED CHANGE COLUMN, not two blocks to diff by eye. The
## first version of this comparison painted your value as the floor and the
## offer as the fill: compact, and unreadable, because the base cells take the
## manufacturer accent -- so wherever that accent is itself red, four gauges on
## which the new frame was BETTER came out red under a legend saying red meant
## loss. A signed number cannot be misread by anybody.
func _offer_slab(h: HullData, against: HullData, title: String) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mark := DB.manufacturer_colour(h.manufacturer)

	# --- WHAT IT IS, AND WHAT THE PLUSES AND MINUSES ARE AGAINST.
	#
	# ONE SLAB FOR EITHER SHIP. Pointing at the hull for sale reads its figures
	# against yours; pointing at yours reads them against the hull for sale. The
	# same panel both ways round, so the comparison is symmetrical and there is
	# one thing to learn. `against` is null when the yard has nothing on the
	# blocks, and then there is simply nothing to subtract.
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
		# WRAPPED ONLY IF IT NEEDS WRAPPING. An autowrap width is the narrowest a
		# Label may be, not the widest -- so setting it on every perk made the
		# slab 448 wide to carry one short line, which is the empty half of the
		# box. Measured before autowrap is switched on, because with it on the
		# minimum is the number just written rather than the text.
		if pk.get_minimum_size().x > float(SLAB_W - 22):
			pk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			pk.custom_minimum_size = Vector2(SLAB_W - 22, 0)
		col.add_child(pk)

	# OPAQUE, and FRAMED IN THE COLOUR OF THE SHIP IT DESCRIBES. It sat at 86%
	# once, and what showed through was a hull -- grey plating behind grey
	# figures, the one background text cannot be read on.
	var slab := PanelContainer.new()
	slab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slab.add_theme_stylebox_override("panel",
		UITheme.flat(Color(0.031, 0.043, 0.066, 0.98),
			Color(mark.r, mark.g, mark.b, 0.55), 0, 8, 11))
	slab.add_child(col)
	return slab


## A label, a gauge and a figure, on the row height everything else uses.
func _page_work() -> Control:
	# --- THE WHOLE DECK IS THE BOARD.
	#
	# It was a board hung on a hall's wall, with a door and a terminal and benches
	# round it -- a room with a noticeboard in it. A hiring hall IS its board: the
	# paper is what you came for, and the paper is also how the rest of the
	# station's life shows. So the cork runs edge to edge in a wooden frame, the
	# work is pinned down the left wherever there was room, and the right is
	# the town's own -- see `PostingBoard`.
	var stack := Control.new()
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board = PostingBoard.new()
	_board.tab_picked.connect(func(_i: int) -> void: _refresh())
	_board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_child(_board)

	# THE WORK, down the left of the board, in one straight column. The notices
	# hung at staggered offsets for a pass, to look pinned by hand, and a stagger
	# reads as crooked -- a notice is something to read, and a column is how.
	# SQUARE NOTES, THREE TO A ROW (Jon: "Can you put the quests in a square
	# note?"): a flow that wraps, each contract its own square of paper.
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


## THE PROMENADE: one part shown large, the rest as a list beside it.
##
## It was a scrolling column of full-width rows, every one carrying its name,
## manufacturer, slot, affixes, both card faces and a price -- four parts stated
## at identical weight, so nothing on the shelf was bigger than anything else and
## none of the art we drew appeared anywhere on the screen.
##
## Now the shelf has a FOCUS. One part is open at full size with its card
## illustration at double scale, and the others are a compact list you click to
## bring forward. See `mocks C · The Cutaway`, which is the layout Jon picked.
## HOW WIDE THE OPEN PART'S COLUMN IS, and it is fixed rather than fitted so
## that the cards beside it start at the same x whatever is open.
##
## TWO NUMBERS SET IT, and both are the widest case rather than the common one:
##
##   the plate   a SPINE part is 4x1, which at CELL is 176 -- plus the size
##               caption beside it, about 60 more.
##   the name    "Widowmaker Siege Driver" is 23 characters, and Silkscreen at
##               FS_HEAD advances 10.5 a character. 242.
##
## 256 clears both. Fitted to the CONTENT instead, the column was 176 and the
## cards jumped sideways every time you opened a part with a different footprint
## -- a 1x1 sight and a 4x1 rail moved the whole right-hand half of the panel.
const PICK_W := 256

## How tall the block between the name and the price stands, whatever is in it.
## See where it is built for the arithmetic.
const DESC_H := 86
## What stands in the shop: the rack, placed where the station's room puts it.
## The counter is `_till`, beside it in the same stack.
var _shelf: Control


func _page_stock() -> Control:
	# NO SECTION HEADING AT THE TOP. "STOCK" over a rule, above a part that
	# already names itself in 16px, was a title for a page with one thing on it
	# -- and it cost thirty pixels off the top of the only band that is short of
	# them. The word moved down to the list it actually labels.
	# --- THE WHOLE DECK IS ONE ROOM, and it is one of Jon's fifteen.
	#
	# The rack and the counter used to stand in a row the screen laid out, in
	# one of four orders, on a wall `ShopScene` drew round them. The room is his
	# layout now (see `ShopScene`): the rack and the counter stand exactly where
	# he put them, and the room is drawn in layers around them -- the wall and
	# what is seen through it behind, the lamps, the light and the glow in
	# front. Nothing here places anything by itself.
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 5)
	var stack := Control.new()
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shop = ShopScene.new()
	_shop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_child(_shop)

	# The rack stands in a holder of its own, which `_refresh_stock` empties
	# and restocks; the counter is built once.
	_shelf = Control.new()
	_shelf.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shelf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(_shelf)

	# --- AND THE TILL YOU CARRY IT TO.
	#
	# A SHELF IS NOT A SHOP UNTIL THERE IS SOMEWHERE TO PAY. The stock was
	# objects standing on boards and the way to buy one was to click the little
	# price card under it -- three hundred credits gone on a single click, with
	# nothing carried anywhere, which is exactly the gesture this game threw out
	# of the hold when right-click-to-jettison was cut.
	#
	# THE SAME COUNTER THE EXCHANGE HAS, turned around. See `TradeCounter.Side`:
	# one is where a market pays you and the other is where it charges you, and
	# they are the two sides of one spread that `MarketTest` proves cannot be
	# farmed. Carrying a part off the shelf to the till is the same gesture as
	# carrying one out of your hold to the counter, which is the point -- a
	# station should have one way of doing business, not one per deck.
	_till = TradeCounter.new()
	_till.side = TradeCounter.Side.CHARGES
	_till.fitted = true
	_till.lit_elsewhere = ShopScene.lit_marks
	_till.took.connect(_on_till)
	stack.add_child(_till)
	_shop.till_node = _till

	# THE ROOM'S OWN LAYERS go on last, over the rack and the counter: what
	# stands in front of them and the lamps, the light over all of it, and the
	# glow -- dust, lamp glass, lit panels, the prices -- over the light.
	# No foreground cables: the shop wears no livery (see `ShopScene`).
	for layer in [_shop.front_layer(), _shop.light_layer(), _shop.glow_layer()]:
		var c: Control = layer
		c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stack.add_child(c)
	# A room's art arrives when it is first drawn; the furniture is placed then.
	_shop.room_loaded.connect(_place_shop_furniture)
	outer.add_child(stack)
	# THE NOTE IS OUTSIDE THE ROOM, under it. Inside the right-hand column it sat
	# below the till, which pushed the counter off the floor and left the two
	# pieces of furniture standing at two different heights.
	_till_note = UITheme.body("", UITheme.QUOTE, UITheme.FS_SMALL)
	_till_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(_till_note)
	return Widgets.panel_with(Widgets.pad(outer))


## A part was carried off the shelf to the till.
##
## THE TILL HAS ALREADY SAID YES. `TradeCounter.refusal` checked the price, the
## credits and the room before it let go, so this is the purchase and not a
## second opinion about it -- `_on_action` re-checks anyway, because it is also
## the thing that races the other players for the slot.
func _on_till(item: HoldItem) -> void:
	var m := item as ModuleData
	if m == null:
		return
	_on_action("buy", m)


## THE EXCHANGE: your hold, and a buyer standing in front of it.
##
## ONE COUNTER AND ONE PRICE. There was a scrap chute beside this, paying a
## lower flat rate for the same part, and it made a module into two prices in
## two places -- which is a second currency wearing a verb's clothes even when
## both of them pay credits. A market is somewhere you sell things. What this
## place will bear is the only number on the deck.
##
## DRAGGING IS THE CONFIRMATION. Carrying a thing across the deck is the
## deliberation, which is the same argument that let the refit screen's hatch
## destroy a part without asking -- and it is why the counter needs no button:
## the hardpoints are on your ship (click it in the Shipyard), and this is where things become money.
##
## And the hold is the REAL grid, not a list of its contents. It is the thing
## you pack, it already drags, and every part on it already answers a hover with
## its own readout and cards.
func _page_hold() -> Control:
	# --- THE DECK IS ONE ROOM, and it is one of Jon's five.
	#
	# It was a loading dock `ExchangeScene` drew round the grid -- a shutter, a
	# crane, a painted bay and a cage off the grid's own rect -- with the counter
	# in a column of its own. It is the shop's room turned to face the other way
	# now (see `ExchangeScene`): the hold stands in its frame where he stood it,
	# the counter where he stood it, and the room is drawn in layers round both,
	# exactly as the Promenade's is. Nothing here places anything by itself.
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 5)
	var stack := Control.new()
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_exchange = ExchangeScene.new()
	_exchange.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_child(_exchange)

	# THE HOLD IS THE REAL GRID, untouched: it is still the thing you pack, it
	# still takes every drop and answers every hover. It stands in the frame's
	# opening, which was fitted to it cell for cell.
	_hold_grid = HoldGrid.new()
	_hold_grid.dropped.connect(_on_hold_move)
	stack.add_child(_hold_grid)

	# THE SAME COUNTER THE SHOP HAS, on the side that pays. See `TradeCounter.Side`.
	_sell_desk = TradeCounter.new()
	_sell_desk.side = TradeCounter.Side.PAYS
	_sell_desk.fitted = true
	_sell_desk.lit_elsewhere = ShopScene.lit_marks
	_sell_desk.took.connect(_on_counter)
	stack.add_child(_sell_desk)
	_exchange.till_node = _sell_desk

	# The room's own layers over the hold and the counter, as the shop's are.
	for layer in [_exchange.front_layer(), _exchange.light_layer(), _exchange.glow_layer()]:
		var c: Control = layer
		c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stack.add_child(c)
	_exchange.room_loaded.connect(_place_exchange_furniture)
	outer.add_child(stack)
	_sell_note = UITheme.body("Carry something to the counter to be paid for it.",
		UITheme.QUOTE, UITheme.FS_SMALL)
	_sell_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(_sell_note)
	return Widgets.panel_with(Widgets.pad(outer))


## The hold and the counter, where this station's Exchange stands them. Again
## whenever the room's art arrives, and whenever the hull -- and so the frame --
## may have changed.
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
	# --- ONE OF JON'S FIVE LABS, WITH THE RECIPES ON ITS SCREEN.
	#
	# The deck was a room drawn in code with the fabricator standing in it as a
	# fume hood, the recipes behind its glass. It is a painted lab per development
	# level now (`LabScene`), and the recipes stand where the prototype drew them:
	# on the lab's own big screen, in `LabScene.win_rect`. Three layers: the lab,
	# lit and running; the rows, in a holder the power-on's scan opens; and what
	# the big screen does, over the rows.
	var stack := Control.new()
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lab = LabScene.new()
	_lab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_child(_lab)

	# THE ROWS' HOLDER CLIPS, so the scan can bring them up a line at a time. It
	# is placed at the screen once the station's level is known (`_refresh_bench`).
	_bench_clip = Control.new()
	_bench_clip.clip_contents = true
	_bench_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(_bench_clip)
	_bench = VBoxContainer.new()
	_bench.add_theme_constant_override("separation", 4)
	_bench_clip.add_child(_bench)
	_lab.rows_clip = _bench_clip

	var glass := _lab.fx_layer()
	glass.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_child(glass)
	return Widgets.panel_with(Widgets.pad(stack))


## Show one page. The lit stylebox is the HUD's, so an active tab looks the same
## wherever the player meets one.
## One deck of the section.
##
## A Button with Labels inside it rather than a Button with text, because a
## Godot Button draws ONE line in ONE colour and a deck needs two of each -- the
## name, and what is on it. Children set to MOUSE_FILTER_IGNORE let every click
## fall through to the button underneath, so this keeps the focus, hover and
## disabled behaviour of the control it replaces and only changes what it looks
## like.
func _deck_cell(id: StringName, deck: String, what: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(RAIL_W, DECK_H)
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func() -> void: _show_tab(id))
	# NO PLATE OF ITS OWN, IN ANY STATE. The room behind it is the plate now --
	# `StationSpine` lights the floor you are standing on, which is the same
	# statement the pressed style used to make and a better one, because it is
	# made of somewhere rather than of a rectangle. A hover still needs to say
	# something, so it says it in the faintest wash the theme has.
	for st in ["normal", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, UITheme.empty())
	b.add_theme_stylebox_override("hover",
		UITheme.flat(Color(0.85, 0.90, 1.0, 0.05), Color(0, 0, 0, 0), 0, 0, 0))

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 9
	box.offset_right = -7
	# CENTRED, NOT TOP-ALIGNED. The cells are floors of a building that moves
	# now, so whichever end of the rail is clipped loses the top or bottom of a
	# room -- and a label pinned six pixels from the ceiling is the first thing
	# to go. Centred, the clip takes air off a room and leaves the name.
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


## The bottom of the rail: the way out, and nothing else.
##
## This used to draw your own ship in a berth above the button. It went for two
## reasons -- the rail is a cutaway of the STATION now and a picture of your hull
## is not a floor of it, and the hull was already on screen on the Yard whenever
## there was anything to compare it against.
func _undock_cell() -> Control:
	# THE ONE THING ON THE RAIL THAT LEAVES. Every deck above it is somewhere you
	# go and come back from; this is the door, so it wears the same ink BUY does.
	var out := _commit_button("UNDOCK", func() -> void: Router.show_sector())
	out.custom_minimum_size = Vector2(RAIL_W, 22)
	# SHRINK, NOT EXPAND. `_commit_button` hands back a control that takes the
	# slack -- which is right where it is one of two things in a row and wrong
	# here, because the other thing in this column is the STATION. The two of
	# them split the rail down the middle and the building got 178 pixels of a
	# 347-pixel column, which looked like the cutaway had been cropped when what
	# had happened is that a button was as tall as five floors.
	out.size_flags_vertical = Control.SIZE_SHRINK_END
	_undock = out
	return out


## A DECK POWERS ON ONCE A DOCKING. Jon: once a station's or a lab's power-on
## has played, going to the star chart and back must not play it again. Coming
## back builds this screen afresh, so `Router.powered` remembers which decks are
## on; those come up settled, quiet and already running. Undocking clears it.
func _power_deck(id: StringName) -> void:
	var settled: bool = Router.powered.has(id)
	if id == &"bench" and _lab != null:
		_lab.power_on(settled)
	elif id == &"services" and _scene != null and is_instance_valid(_scene):
		_scene.power_on(settled)
	elif id == &"work" and _board_lamp != null:
		_board_lamp.power_on(settled)
	else:
		return
	Router.powered[id] = true


func _show_tab(id: StringName) -> void:
	if not _pages.has(id) or not _tabs_on.get(id, true):
		return
	_tab = id
	for key in _pages:
		(_pages[key] as Control).visible = key == id
	_light_floor()
	# THE LAB POWERS ON the first time you step onto its deck here: the lamps
	# strike, the room fades up and the screen scans the recipes on. THE YARD'S
	# TV POWERS ON the first time you step onto the deck, and the drones fly in
	# after it.
	_power_deck(id)
	for key in _tabs:
		var b: Button = _tabs[key]
		var on: bool = key == id
		b.disabled = on
		# The deck's own labels carry the colour, not the button's font, because
		# a Button's font colour cannot reach Labels parented inside it.
		var title := b.get_meta(&"title", null) as Label
		# NO PLATE ON EITHER STATE ANY MORE.
		#
		# The active cell used to paint a brown bevel and the inactive ones used
		# to REMOVE the override and fall back to the theme's Button plate. Both
		# of those are opaque rectangles over the top of a drawing of a room, so
		# between them they hid the entire cutaway -- the rail looked exactly as
		# it always had and the spine appeared not to be rendering at all.
		#
		# `StationSpine` says which floor you are on by turning its lights on,
		# which is the same statement made out of somewhere instead of out of a
		# rectangle. The labels still carry the colour.
		b.add_theme_stylebox_override("normal", UITheme.empty())
		b.add_theme_stylebox_override("disabled", UITheme.empty())
		if on:
			if title != null:
				title.add_theme_color_override("font_color", UITheme.HOT)
			if _deck_note.has(key):
				(_deck_note[key] as Label).add_theme_color_override(
					"font_color", UITheme.EMBER)
		else:
			if title != null:
				title.add_theme_color_override("font_color", UITheme.CHILL)
			if _deck_note.has(key):
				(_deck_note[key] as Label).add_theme_color_override(
					"font_color", UITheme.COLD)


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
		# THE CUTAWAY HAS TO HEAR ABOUT IT TOO. Hiding the cell is half the job:
		# `StationSpine` divides the shaft by the floors it was last told about,
		# so a rail showing three decks behind a building drawn in fifths puts
		# every room -- and the car -- off its own label. Only `_show_tab` used
		# to say so, which is why it corrected itself the moment you clicked
		# anything and looked fine in every screenshot that clicked first.
		#
		# NOT A RIDE. The deck set settles on arrival; a car that travels because
		# a station turned out to have no laboratory is answering a journey
		# nobody made. See `_ride_to`.
		_light_floor(false)


## WHICH FAULT COMES OUT, chosen from the cards themselves.
##
## THE CARD IS THE QUESTION. A malfunction is a card that will be dealt into
## your hand, and the thing you are weighing is which of them you least want to
## draw -- so a list of names in grey is the one presentation that withholds the
## deciding fact. `CardView` already draws them, keyword tooltips and all.
##
## Priced per removal and not per fault: `clear_dross` takes out exactly one, so
## carrying three of a thing means paying three times, and the count on each
## card says so before you spend the first one.
func _open_purge() -> void:
	if _purge_prompt != null or Run.dross_count() <= 0:
		return
	var n: MapGen.MapNode = Run.node_at()
	var cost := Market.purge_price(n)

	# The shade eats input so the deck underneath cannot be clicked through, and
	# a click on the dim margin closes -- the same dismissal every other prompt
	# in the game uses.
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.05, 0.80)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.gui_input.connect(func(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_close_purge())
	add_child(shade)
	_purge_prompt = shade

	var mid := CenterContainer.new()
	mid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.add_child(mid)

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
			# REOPENED WHILE THERE IS STILL SOMETHING TO CLEAR, because clearing
			# one of four is not the end of the job and closing on you would make
			# the next three four clicks each.
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


## Give the building its height, once the shaft has one.
##
## IT FILLS THE SHAFT. An earlier version made it taller and slid the whole
## station when you picked a floor, which was the wrong object to move: the
## building is not what travels in a building. Sliding it also meant a floor was
## always partly out of frame, and this rail is the navigation for the screen.
func _size_building() -> void:
	if _building == null:
		return
	var shaft := _building.get_parent() as Control
	if shaft == null or shaft.size.y <= 0.0:
		return
	_building.position = Vector2.ZERO
	_building.size = shaft.size


## Send the car to a floor.
##
## THE CAR MOVES AND THE STATION DOES NOT. It is a lit frame one floor tall, and
## it travels THROUGH the rooms between where it was and where it is going --
## so picking the Laboratory from the Promenade takes it down past the Yard, the
## Exchange and the Hall, brightening each as it passes and letting it go again.
## That is the whole of the elevator, and it is why `StationSpine.car` is a float
## rather than an index.
##
## `ride` is false on arrival at the station and on a resize: a car that travels
## because a panel got wider is a bug you can watch happen.
func _ride_to(index: int, ride: bool = true) -> void:
	if _spine == null or index < 0:
		return
	if _lift != null and _lift.is_valid():
		_lift.kill()
	if not ride or _spine.car < 0.0:
		_car_step(float(index))
		return
	# LONG ENOUGH TO BE A JOURNEY, and scaled by how far it is going: two floors
	# should take longer than one, because in a building they do.
	#
	# FOUND BY BRACKETING IT. A second longer read as a wait; half the original
	# was "WAY too fast" -- a one-floor hop at 0.13 s is barely a movement and
	# was nearly all landing. Then: "maybe slightly slower than where it was".
	# So a THIRD longer than the original, which is 0.34 s for one floor where
	# the original was 0.26 and the fast one 0.13.
	#
	# Both wrong answers left something behind: the long one found the tick
	# buried at 0.46 s in the fan take, and the fast one made the fade a
	# fraction of the ride instead of a constant.
	var span := absf(float(index) - _spine.car)
	var secs := clampf(0.21 + 0.13 * span, 0.24, 0.72)
	# THE CAR SETS OFF WITH A SOUND, and only when it actually travels: arrival
	# and resizes snap it (above) and stay silent. Throttled, because clicking
	# down the floor list fast restarts the ride each time.
	Audio.play(&"station_lift", 0.05, 150)
	_lift = create_tween()
	_lift.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_lift.tween_method(_car_step, _spine.car, float(index), secs)
	# THE SOUND LASTS EXACTLY AS LONG AS THE RIDE. Jon: "calculate how long it
	# takes for the elevator animation ... that should be how long the sound
	# lasts." A ride is 0.24-0.72 s by distance, so the file is longer than any
	# ride and is faded out on the frame the car stops. A ride cut short by a
	# new pick is killed above and never finishes; the new ride's own sound
	# carries on instead.
	#
	# AND THE FADE IS A FRACTION OF THE RIDE, NOT A CONSTANT. It is 60 ms at
	# every length that matters here, so at this pace it changes nothing -- it
	# is kept because it is the correct shape: a sound that is mostly its own
	# fade never lands, which is what a flat 60 ms did to a 0.13 s ride when the
	# lift was briefly twice this speed.
	#
	# AND THE CAR ARRIVES WITH A SOUND OF ITS OWN: "a ca chunk where the
	# animation ends". It cannot be the tail of the ride -- the ride is cut to
	# however far the car travels, so a chunk baked into the file would land
	# wherever the fade did, which is to say never on the stop. Its own sound,
	# played on the frame the tween finishes, lands every time. Two dB under the
	# ride, because the first pass at it was four dB over and "too loud".
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


## Tell the cutaway which rooms it has and which one you are in.
##
## THE FLOORS ARE THE DECKS THAT EXIST, not always five. An outpost has no
## Laboratory, and a spine that drew one would be a picture of a building with a
## room you cannot get to -- so the list comes from the tabs that are actually
## enabled, in rail order.
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
	# RIDE ONLY WHEN THE FLOOR ACTUALLY CHANGED, and never on the first one.
	# `_light_floor` runs on every refresh -- a car that sets off each time a
	# price ticks is a car nobody believes in, and one that travels on arrival at
	# the station is answering a journey the player did not make.
	_ride_to(_spine.active, ride and was >= 0 and was != _spine.active)
	_spine.manufacturer = Run.node_at().manufacturer if not Run.map.is_empty() \
		else &""
	_spine.queue_redraw()


## Roll what is on the shelf, ONCE per system per run.
##
## The guard used to be `shop.is_empty()`, and that was an exploit rather than a
## style choice: buying the shelf out emptied the array, so leaving and coming
## back re-rolled a full one. An unlimited supply of parts at a fixed price is an
## unlimited supply of money the moment any part is worth more melted than
## bought, which is exactly what happened. `stocked` says what was meant — this
## station has been visited, and what somebody brought here is what there is.
##
## Nothing is priced here any more. Market prices a part from the place it is
## standing in, so the shelf holds parts and not price tags.
## THE TWO LIMITS ON A SHOP, and they are not the same limit.
##
## `SHOP_CELLS` is the most stock a shop can carry, counted as the parts' own
## area. A shelf is four cells across and two high and the rack has two of them,
## so a full rack is sixteen cells and that is the ceiling.
##
## `SHOP_COLS` is what the rack can physically stand. PARTS DO NOT STACK -- they
## stand side by side on a board -- so a 1x1 fitting occupies a whole one-wide
## column and leaves the cell above it empty. Eight columns is the rack, and it
## binds long before the cell ceiling does: eight 1x1 fittings fill the rack
## having spent only eight of the sixteen cells.
##
## A shop rolls its fill in COLUMNS, half a rack to a full one, because columns
## are the thing you can see: a rack with two bare columns reads as a thin shop,
## whereas the same stock rolled on cells fills the rack anyway and only changes
## how tall the parts on it happen to be. Depth is not in here. Depth is
## rarity, below.
const SHOP_CELLS := 16
const SHOP_COLS := ShelfDisplay.SHELF_COLS * 2


func _stock_up() -> void:
	var n: MapGen.MapNode = Run.node_at()
	if n.stocked:
		return
	n.stocked = true
	# Positional. What is on a station's shelf belongs to the station, and
	# `n.stocked` already says the shelf is rolled once and kept — this is the
	# same rule, now expressed so that four ships docking in four different
	# orders see one shelf instead of four. See Rng.derive().
	var r := Rng.derive(&"shop", n.index)
	# UP TO SIXTEEN CELLS OF STOCK, counted as the parts' own area, and never
	# more columns than the rack has. A hub used to carry five parts, which is
	# depth expressed as QUANTITY -- more of the same rather than better. What a
	# deep station has that a rim one does not is RARITY, and that is the axis
	# below.
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
		# DEPTH IS THE RARITY. `n.danger` is set from the ring, so it already says
		# how deep this is; the shop used to knock two off it, which flattened the
		# ladder and left "deeper" meaning only "more items". Lawless space still
		# runs hotter than the ring it sits in.
		var danger := n.danger + 3 if n.region == MapGen.Region.LAWLESS else n.danger
		var m := LootGen.roll_module(danger, force, n.region == MapGen.Region.LAWLESS, r)
		# Legitimate markets do not move Legendary and above.
		if n.region == MapGen.Region.COSMOPOLITAN and m.rarity > ModuleData.Rarity.EPIC:
			m.rarity = ModuleData.Rarity.EPIC
		# A part that will not fit what is left is put back: the shelf is a shelf,
		# not a bag, and a four-cell rail simply does not go in two cells. Its
		# WIDTH is checked separately, because that is the space it takes up on a
		# board whether or not it is tall enough to use the cells above it.
		var cells := maxi(1, m.size.x) * maxi(1, m.size.y)
		var cols := maxi(1, m.size.x)
		if cells > cells_left or cols > cols_left:
			continue
		# AND IT HAS TO STAND ON TWO BOARDS. Eight columns is two boards of four
		# only if the parts divide that way: two three-wide parts and a two-wide
		# one are eight columns that no two boards hold. The rack used to grow a
		# third board for that; a shop room's rack is the two-board one Jon
		# placed, so a part that would not stand on it is put back like one that
		# does not fit the cells.
		var trial: Array = n.shop.duplicate()
		trial.append(m)
		if not ShelfDisplay.stands_on(trial, 2):
			continue
		cells_left -= cells
		cols_left -= cols
		n.shop.append(m)
	# WHETHER THIS YARD HAS A HULL ON THE BLOCKS, by how built-up the place is.
	#
	# It was a flat 0.4 everywhere, which meant six stations in a row with
	# nothing was a 5% event -- and 5% events happen. Worse, it made an outpost
	# and a capital equally likely to have a ship for sale, which is backwards:
	# a yard is a thing a place builds once it can afford one.
	#
	# Lawless space still never has one. A hull is the largest legitimate
	# purchase in the game and a fence does not sell you a chassis.
	var hull_odds := 0.0
	match n.development:
		MapGen.Development.UNCLAIMED: hull_odds = 0.15
		MapGen.Development.OUTPOST: hull_odds = 0.35
		MapGen.Development.SETTLEMENT: hull_odds = 0.55
		MapGen.Development.CITY: hull_odds = 0.75
		MapGen.Development.CAPITAL: hull_odds = 0.9
	if n.region != MapGen.Region.LAWLESS and r.randf() < hull_odds:
		n.shop_hull = LootGen.roll_hull(n.danger, r)

## High-law space inspects; lawless space does not.
##
## Its own function, and called on every dock rather than from inside the stock
## roll. It used to sit under that early return, which meant the customs officer
## only ever looked at you on the visit that happened to roll the shelves — dock
## clean, fly out, come back carrying, and nobody checked. `n.inspected` is what
## makes it once per system; the shelf has nothing to do with it.
func _inspect() -> void:
	var n: MapGen.MapNode = Run.node_at()
	if n.region == MapGen.Region.COSMOPOLITAN and not n.inspected and Run.contraband_count() > 0:
		n.inspected = true
		var c := Run.contraband_count()
		var fine := 20 * c
		Run.add_credits(-fine)
		Run.log_line("Inspection: %d illegal part%s found. Fined %d credits." % [
			c, "" if c == 1 else "s", fine], &"heat")

## Everything on screen. One function per tab body, mirroring `_refresh_work`,
## which was already broken out on its own.
##
## This was one 110-line run that rebuilt the header, both gauges and all five
## tab bodies in sequence, so a reader looking for where the shelf is drawn had
## to read the repair prices to get there.
func _refresh() -> void:
	var n: MapGen.MapNode = Run.node_at()
	_refresh_header(n)
	_refresh_work(n)
	_refresh_services(n)
	_refresh_stock(n)
	_refresh_hold(n)
	_refresh_bench(n)
	_refresh_undock()


## Whether the door opens, and if not, what is holding it.
##
## THE GATE IS ON UNDOCKING AND NOWHERE ELSE, and that placement is the whole
## design rather than the obvious spot. The first instinct is to stop the JUMP
## -- but `has_legal_jump()` loops `can_jump_to`, and `check_stranded()` ends
## the run the moment that returns false for every system. A pad that blocked
## jumps would not stop you leaving; it would kill you for buying a ship.
##
## Gating the door instead is both safe and sufficient: the Yard is the only
## place in the game that hands you a hull, so a loaded pad cannot reach the
## star chart if it cannot get off the station.
##
## THE REASON IS ON THE BUTTON. A disabled control with no explanation is the
## worst version of this -- you are standing on a screen with five decks and no
## idea which one owes you something. `ready_to_fly` returns the reasons rather
## than a boolean for exactly this line.
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
	_undock.tooltip_text = Widgets.tip("%s.
Click your ship in the Shipyard to stow it in the hold, or sell it at the Exchange."
		% "; ".join(why).capitalize())


## The banner, the trade line, and the two gauges on the hull panel.


## The banner, the trade line, and the two gauges on the hull panel.


func _refresh_header(n: MapGen.MapNode) -> void:
	# ONE FACT TO A LINE, at the head of the rail.
	#
	# It was a sentence across the top of the deck -- "city station · high security
	# · danger 5 · glut solari/cygnet" -- which is four separate facts wearing
	# punctuation. Stacked in the rail's head they read as what they are, and the
	# place's name gets to be a title.
	var note := ""
	match n.region:
		MapGen.Region.COSMOPOLITAN: note = "stock from many manufacturers, strict inspections"
		MapGen.Region.LAWLESS: note = "fenced goods, no questions"
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


## Repair, refuelling, purges -- and the ship on the pad beside your own.
##
## WORK ONLY. Everything on the top panel is something the station DOES to the
## ship you flew in on; what you are carrying, and what it is worth, is the
## Exchange's question and is asked there.


## Repair, refuelling, purges -- and the ship on the pad beside your own.
##
## WORK ONLY. Everything on the top panel is something the station DOES to the
## ship you flew in on; what you are carrying, and what it is worth, is the
## Exchange's question and is asked there.


func _refresh_services(n: MapGen.MapNode) -> void:
	var h: HullData = n.shop_hull
	var up := h != null and not n.taken.has(MapGen.OPTION_SHOP_HULL)
	# THE YARD IS BUILT ONCE, and a refresh only tells it what changed: a
	# purchase is a drone dipping to the hull and flying off when its job is
	# done, and a rebuilt yard would have taken the drones, the TV and everyone
	# on the floor back to the start.
	if _scene == null or not is_instance_valid(_scene):
		Widgets.clear(_hull_offer)
		_hull_offer.add_child(_yard_box(n))
	_yard_ships(h if up else null)
	_yard_hull = h if up else null

	# --- THE DEAL, ON THE TV AT THE BOTTOM RIGHT.
	#
	# A RECEIPT, as it was: what they ask, what your ship is worth to them, and
	# the difference that leaves your account, over TAKE IT.
	if up:
		var ask := Market.hull_price(n, h)
		var part_ex := Market.hull_bid(n, Run.hull)
		var price: int = maxi(0, ask - part_ex)
		_scene.set_deal({"ask": ask, "trade": part_ex, "price": price, "ok": Run.credits >= price})
	else:
		_scene.set_deal({})

	# --- AND THE FOUR SERVICES, EACH ON A DRONE OVER YOUR SHIP.
	#
	# The same four the machines in the bay sold, at the same prices: a drone
	# carries what it will do and what it costs, and when there is nothing left
	# for it to do its screen says why and it flies off. REFUEL never goes,
	# because a tank has no top here; FAULTS opens the picker.
	var missing := Run.max_hp() - Run.hp
	var eight := mini(8, maxi(1, missing))
	var eight_cost := Market.repair_price(n, eight)
	var full_cost := Market.repair_price(n, missing)
	var refuel_cost := Market.refuel_price(n)
	var dross_n := Run.dross_count()
	var purge_cost := Market.purge_price(n)
	var offers: Array = [
		{"label": "PATCH +%d" % eight, "cost": eight_cost, "done": "" if missing > 0 else "HULL FULL",
			"tip": "%.1f credits a point here. Work is dear on the frontier and cheap in a capital." % Market.repair_rate(n)},
		{"label": "REPAIR +%d" % missing, "cost": full_cost, "done": "" if missing > 0 else "HULL FULL",
			"tip": "Every point of it, in one go."},
		{"label": "REFUEL +%d" % Market.REFUEL_UNITS, "cost": refuel_cost, "done": "",
			"tip": "A tankful. Fuel is what a jump costs (see the starchart's reach ring)."},
		{"label": "FAULTS %d" % dross_n, "cost": purge_cost, "done": "" if dross_n > 0 else "NO FAULTS",
			"tip": "Choose which one comes out. Each costs the same and clears exactly one."},
	]
	for o: Dictionary in offers:
		o["ok"] = Run.credits >= int(o["cost"])
	_scene.set_offers(offers)



## The shelf: a chassis if one is for sale, then whatever parts are left on it.


## THE PART ITSELF, ON THE CELLS IT WILL TAKE UP IN THE HOLD.
##
## The module sprite and the card illustration were drawn for different jobs and
## the panel needs both: the sprite is the OBJECT -- a silhouette drawn to read
## at twenty pixels bolted to a ship -- and the card is what owning it does to
## your deck. So the part gets its sprite and the cards get their own faces,
## and neither is a crop of the other.
##
## ON A GRID, because that makes the second picture answer a question the first
## cannot. "2×1" is a string you have to convert; two squares is the shape of the
## hole it leaves in a hold you are already packing.
##
## FORTY-FOUR, and it follows from the art rather than from taste. Module sprites
## are authored at twenty pixels to the cell, so a cell of 44 holds one drawn at
## exactly 2x with two pixels of air around it -- and 2x is the only enlargement
## this art has, the same rule the card window follows.
const CELL := 44


func _hold_plate(m: ModuleData) -> Control:
	var cells := Vector2i(maxi(1, m.size.x), maxi(1, m.size.y))
	var box := Control.new()
	box.custom_minimum_size = Vector2(cells) * CELL
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
		sq.custom_minimum_size = Vector2(CELL, CELL)
		sq.add_theme_stylebox_override("panel",
			UITheme.flat(Color("#0a0f17"), Color("#1b2735"), 0, 0, 0))
		grid.add_child(sq)

	# ON TOP OF THE GRID, not inside a cell. The sprite spans the whole
	# footprint -- that is what a footprint IS -- so it is a sibling laid over
	# the squares rather than a child of one of them.
	var mid := CenterContainer.new()
	mid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(mid)
	var art := TextureRect.new()
	art.texture = m.sprite
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if m.sprite != null:
		# EXACTLY DOUBLE, computed from the texture rather than fitted to the
		# box. Fitting would scale a 20x20 sprite into a 44x44 cell at 2.2x,
		# which lands the whole thing on half-pixels -- the one thing this art
		# may never do.
		art.stretch_mode = TextureRect.STRETCH_SCALE
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.custom_minimum_size = m.sprite.get_size() * 2.0
	mid.add_child(art)
	return box


## THE OPEN PART'S LEFT-HAND COLUMN: what the thing IS.
##
## SHARED BY THE PROMENADE AND THE EXCHANGE, because they are the same panel
## asked two different questions -- one about a part on a shelf and one about a
## part in your hold -- and the answer to "what is this" cannot be allowed to
## differ between them. It was written twice for a day and the two copies had
## already drifted on the flavour line.
##
## Everything above the actions, and nothing below: the caller owns the buttons,
## because buying and selling are the half that genuinely differs.
func _part_column(mod: ModuleData) -> VBoxContainer:
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	left.custom_minimum_size = Vector2(PICK_W, 0)
	# SHRINK_BEGIN, so PICK_W is the width and not merely the floor. Left to
	# expand, a column with nothing beside it takes the whole band.
	left.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	var plate := HBoxContainer.new()
	plate.add_theme_constant_override("separation", 10)
	# TALL ENOUGH FOR THE TALLEST FOOTPRINT, always. Every shape in the game is
	# one cell deep except BULK, which is two -- so opening a 2x2 after a 2x1
	# would push everything under it down by a whole cell. The plate is centred
	# in the reserved height, so a one-deep part sits in the middle of it.
	plate.custom_minimum_size = Vector2(0, CELL * 2)
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

	# THE NAME CARRIES THE GRADE, in the ink the rest of the game grades things
	# in. On a shelf the question is not what the part is called but how good it
	# is, and that used to be a word in grey somewhere else.
	var title := UITheme.body(mod.name.to_upper(),
		ModuleData.rarity_ink(mod.rarity), UITheme.FS_HEAD)
	# ONE LINE. A two-line name pushed everything under it down twenty pixels on
	# exactly the parts with the longest names, so the panel changed height as
	# you clicked along the list. `clip_text` is the guard rather than the plan.
	title.clip_text = true
	title.custom_minimum_size = Vector2(PICK_W, 0)
	left.add_child(title)

	# THE MANUFACTURER IN ITS OWN COLOUR, the slot beside it in grey. Two labels
	# rather than one string, because they are two kinds of fact: who built it is
	# an allegiance, and the slot is a spec.
	var mrow := HBoxContainer.new()
	mrow.add_theme_constant_override("separation", 5)
	mrow.add_child(UITheme.body(
		DB.manufacturer_name(mod.manufacturer).to_upper(),
		DB.manufacturer_colour(mod.manufacturer), UITheme.FS_SMALL))
	mrow.add_child(UITheme.body("· %s" % ModuleData.slot_name(mod.slot).to_upper(),
		UITheme.COLD, UITheme.FS_SMALL))
	left.add_child(mrow)

	# NO FIXED HEIGHT HERE ANY MORE. This box was padded to DESC_H so that the
	# price and its button, which used to sit underneath it, would land at the
	# same y on every part -- a part with one affix and a one-line flavour is two
	# labels where a part with a two-line flavour is one, and the extra
	# separation moved the button four pixels. The money is its own column now,
	# so nothing below this has to be held still and the text can simply be as
	# long as it is.
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
	# WHAT THE THING IS LIKE, under what it does. In QUOTE, the ink this game
	# reserves for writing that is not a rule.
	if mod.flavour != "":
		var fl := UITheme.body(mod.flavour, UITheme.QUOTE, UITheme.FS_SMALL)
		fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fl.custom_minimum_size = Vector2(PICK_W, 0)
		desc.add_child(fl)
	return left


## THE BUTTON THAT SPENDS SOMETHING, in the one ink this screen reserves for it.
##
## BUY, INSTALL, TAKE IT, MAKE and UNDOCK are the five controls on this station
## that actually commit -- money, a hardpoint, a material, or the berth itself.
## Everything else is navigation. They were the same grey box as a deck tab, so
## the moment of paying looked like the moment of browsing, and UNDOCK had been
## given ember by hand while BUY had not.
##
## DISABLED IS SPELLED OUT, and it has to be: an override on `normal` alone
## leaves the disabled state ember too, so a BUY you cannot afford would look
## exactly like one you can. It goes to LINE on VOID, which is the quietest
## thing on the page.
func _commit_button(text: String, action: Callable) -> Button:
	var b := Widgets.button(text, action)
	b.add_theme_stylebox_override("normal",
		UITheme.flat(Color("#0a0f17"), UITheme.EMBER, 0, 5, 14))
	b.add_theme_stylebox_override("hover",
		UITheme.flat(Color("#1d1409"), UITheme.FLARE, 0, 5, 14))
	b.add_theme_stylebox_override("pressed",
		UITheme.flat(UITheme.EMBER, UITheme.HOT, 0, 5, 14))
	b.add_theme_stylebox_override("disabled",
		UITheme.flat(Color("#0a0e15"), UITheme.LINE, 0, 5, 14))
	b.add_theme_color_override("font_color", UITheme.EMBER)
	b.add_theme_color_override("font_hover_color", UITheme.HOT)
	b.add_theme_color_override("font_pressed_color", UITheme.VOID)
	b.add_theme_color_override("font_disabled_color", UITheme.COLD.darkened(0.3))
	return b
## WHAT IT PUTS IN YOUR DECK, as the cards themselves.
##
## THE REAL CARD FACE, not the illustration lifted out of it. Cropping `Z_ART`
## and reprinting the rules line underneath in grey is a card taken apart and
## laid out again worse -- the face already carries the art, the name, the cost
## and the text, drawn by the one class that knows how a card in this game looks.
func _card_fan(mod: ModuleData, heading: String) -> VBoxContainer:
	var deck := VBoxContainer.new()
	deck.add_theme_constant_override("separation", 5)
	deck.add_child(UITheme.body(heading, UITheme.COLD, UITheme.FS_SMALL))
	var fan := HBoxContainer.new()
	fan.add_theme_constant_override("separation", 8)
	deck.add_child(fan)
	# ONE FACE PER COPY. `resolved_cards` hands back an entry for every copy the
	# Grant Count Law awards, and folding them into one face with an "x2" under
	# it is a receipt for two cards rather than a picture of them.
	for c in mod.resolved_cards():
		var v := CardView.new()
		# `can_play` TRUE, where nothing can be played. The flag greys the face,
		# and it means "you cannot afford this right now" in a hand -- said about
		# a card in a shop window it reads as the card being broken.
		v.setup(c, true, 1)
		# THE POINTER REACHES IT, and that is the whole of the keyword help:
		# `CardView._make_custom_tooltip` answers with `Widgets.card_readout`,
		# which lists every term the card can explain. `tooltip_text` has to be
		# non-empty or Godot never asks for the custom panel; it is never drawn.
		v.mouse_filter = Control.MOUSE_FILTER_STOP
		v.tooltip_text = " "
		fan.add_child(v)
	return deck
## How deep the berth is. The panel gives it everything under the heading; this
## is the floor under that, so the scene never collapses on a short page.
## The details slab's WIDEST, not its width. Wide and short rather than narrow
## and tall -- two columns of gauges fit in the band of empty wall above the two
## berths, where a single column could only fit by lying across the ship it was
## describing. It is a ceiling because it was read as a floor for a while and
## the slab came out 470 wide whatever was in it, with the right third empty on
## every hull whose perk fits on one line. Only a perk long enough to need
## wrapping ever reaches it now.
const SLAB_W := 470
func _refresh_stock(n: MapGen.MapNode) -> void:
	Widgets.clear(_shelf)

	# WHAT IS LEFT, which is not the same as what is on the shelf. A sold part
	# stays in `n.shop` so that everybody's slot numbers keep meaning the same
	# thing -- see MapGen.OPTION_SHOP -- and is hidden here instead.
	# NO HULL ON THIS SHELF. The Promenade is where parts are laid out and a hull
	# is not a part -- it is the thing you bolt them to. It sold here because this
	# was the only page with a shop on it; the Yard has one now, beside the gauges
	# for the ship you are standing in.
	var on_offer: Array = []
	for i in n.shop.size():
		if n.taken.has(MapGen.OPTION_SHOP + i):
			continue
		var m: ModuleData = n.shop[i]
		on_offer.append({pick = i, thing = m, price = Market.ask(n, m)})

	# WHAT THE TILL IS FOR, said once under it rather than on every ticket. It
	# also carries the one fact a price cannot: a part bought here goes into the
	# HOLD, not onto the ship, so a full hold is a reason you cannot shop.
	if _till_note != null:
		_till_note.text = ("Shelves bare." if on_offer.is_empty()
			else "Carry a part down to the till to buy it. It goes into your hold%s"
				% (", and your hold is full." if Run.hold_full() else "."))
	# THE ROOM KNOWS WHERE IT IS: how built-up the station is picks which of
	# its level's three rooms this shop is, and the station itself picks the
	# backdrop behind the wall. A bare shelf keeps its rack and its counter --
	# they are the room's furniture, and an empty rack is how a shop says it is
	# out of stock.
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

	# NO OPEN PART, NO CARD FAN, NO BUY COLUMN.
	#
	# THE SHELF ANSWERS ALL THREE NOW. The top band existed because a list of
	# names cannot tell you what a part is -- so one of them was opened at a time,
	# blown up on the left with its cards beside it and a price with a button. The
	# stock is OBJECTS on a shelf now, and pointing at one gets you the identical
	# readout and the identical cards from `ModuleIcon` without displacing
	# anything. A panel that shows you one part at a time, above a shelf showing
	# you all of them, is a worse version of the shelf.
	#
	# What went with it is the whole top half of the deck, which the shelf takes:
	# boards down the full height instead of one board and a readout.

	# --- AND THE STOCK IS STANDING ON A SHELF.
	#
	# IT WAS A LIST OF ROWS. A rack drawn under that list was better than a
	# picture behind it and was still a table of names -- what is actually on a
	# shelf is THINGS, at the size and shape they are. A four-cell rail takes
	# four cells of board and a fitting takes one, so the shelf says what you are
	# buying before you have read a word of it.
	#
	# The hover comes free: `ModuleIcon` already answers with the part's readout
	# and every card it grants, which is the same panel the refit screen uses.
	var shelf := ShelfDisplay.new()
	# THE ROOM'S RACK, AT ITS OWN SIZE AND SCALED BY TWO. The bench draws the
	# rack and its stock at 1x and doubles the lot, so the parts stand at the
	# hold's 40px cell and the tags double with them; a node scaled by two is
	# that, pixel for pixel. Its boards are the rows the rack was cut with.
	shelf.art_override = art
	shelf.board_rows = _shop.rack_boards()
	shelf.lit_elsewhere = ShopScene.lit_marks
	var rr := _shop.rack_rect()
	shelf.position = rr.position
	shelf.size = Vector2(art.get_size())
	shelf.scale = Vector2(2.0, 2.0)
	# NOTHING TO CONNECT. Pointing at a part tells you everything about it and
	# dragging it to the till buys it; the shelf has no button on it at all, so
	# the gesture that reads and the gesture that spends cannot be confused.
	_shelf.add_child(shelf)
	_shop.shelf_node = shelf
	shelf.stock(on_offer)


## What you brought, priced at what this place will pay for it.
##
## THE SAME TWO BANDS THE PROMENADE HAS, and deliberately so: one thing open
## across the top, everything else as a list along the bottom. The two decks ask
## the same question about a part -- what is it and what does it put in my deck --
## and the only honest difference is the buttons, so `_part_column` and
## `_card_fan` are shared and this file owns nothing but the actions.
##
## It was a scrolling column of full-width rows, each carrying the name, the
## manufacturer, the slot, the affixes, both card faces, a deck count and three
## buttons. Four of those is more text than the Promenade ever showed, on the one
## page where you already know what you are carrying.
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

	# HOW FULL THE HOLD IS, and what the counter is paying today, said once under
	# the room. The count was stencilled on the old cage's plate; the frames are
	# Jon's pictures now and have no plate in common. A market's rate is a
	# property of the PLACE -- see `Market.bid` and its saturation note -- so it
	# belongs here and not repeated beside each thing standing near it.
	_sell_note.text = "Hold %d/%d%s. Carry something to the counter to be paid for it. %s" % [
		Run.cargo_used(), Run.cargo_slots(), "" if stray == 0 else ", %d on the pad" % stray,
		"This market has taken a lot today; it is paying less than it was."
		if n.trades >= 3 else "Prices are what this place will bear."]
## The recipes this place can support, and the tab that hides when it cannot.


func _refresh_bench(n: MapGen.MapNode) -> void:
	_dress_room(_lab, n)
	_lab.load_level()
	# ON THE LAB'S SCREEN. The holder is the screen's window; the rows keep its
	# full height whatever the scan has opened, so they do not re-flow as it goes.
	var win := _lab.win_rect()
	_bench_clip.position = win.position
	_bench_clip.size = win.size
	_bench.position = Vector2.ZERO
	_bench.custom_minimum_size = Vector2(win.size.x, 0.0)
	_bench.size = Vector2(win.size.x, win.size.y)
	Widgets.clear(_bench)
	var recipes := Fabricator.available(n)
	# The TAB goes, not the page. A page that hides itself leaves a lit tab
	# pointing at nothing, and `_show_tab` would happily select it.
	_enable_tab(&"bench", not recipes.is_empty())
	# A ROW, NOT A BUTTON THE WIDTH OF THE PAGE.
	#
	# Each recipe was one wide button whose whole label was "NAME · COST", so the
	# thing you get was a tooltip and the page was two grey bars. What a recipe
	# makes is the reason to stand here; it goes on the row in the ink the rest of
	# the station prices things in.
	for r in recipes:
		var can := Fabricator.can_make(n, r)
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)

		# TWO LINES, NAME AND MAKE THEN THE COST: the settlement's screen is two
		# hundred pixels wide, and one line of all three did not fit it.
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 8)
		var name_l := UITheme.body(str(r.name).to_upper(),
			UITheme.ICE if can else UITheme.COLD, UITheme.FS_BODY)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(name_l)
		var b := _commit_button("MAKE", _fabricate.bind(r))
		b.disabled = not can
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(b)
		row.add_child(head)
		# THE COST IN AMBER WHEN YOU CAN PAY IT, grey when you cannot -- the same
		# read as a BUY button greying out, said in the one place the answer is.
		row.add_child(UITheme.body(Fabricator.cost_line(n, r).to_upper(),
			UITheme.EMBER if can else UITheme.QUOTE, UITheme.FS_SMALL))

		var what := UITheme.body(str(r.text), UITheme.COLD, UITheme.FS_SMALL)
		what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(what)
		_bench.add_child(Widgets.panel_with(Widgets.pad(row, 8, 6)))

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
			if Run.credits < Market.refuel_price(n):
				return
			_scene.serving(2)
			_refuel()
			_scene.served(2, "+%d FUEL" % Market.REFUEL_UNITS)
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
	var cost := Market.refuel_price(Run.node_at())
	if Run.credits < cost:
		return
	Run.add_credits(-cost)
	# No emit. `fuel` has a setter now — see RunState. This line was the third
	# copy of the write-then-remember-to-emit shape that three of today's bugs
	# came out of.
	Run.fuel += Market.REFUEL_UNITS
	Run.log_line("Refuelled.", &"good")

## One malfunction, named, and only one. `clear_dross` removes a single entry,
## so paying once to clear three copies of the same thing is not a thing that
## can happen by accident.
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

func _fabricate(r: Dictionary) -> void:
	var line := Fabricator.make(Run.node_at(), r)
	if line.is_empty():
		return
	Audio.play(&"fabricate", 0.04)
	Run.log_line(line, &"good")

func _on_action(action: String, thing: Variant) -> void:
	var n: MapGen.MapNode = Run.node_at()
	match action:
		"buy":
			var m := thing as ModuleData
			var slot := n.shop.find(m)
			var price := Market.ask(n, m)
			if slot < 0 or Run.credits < price:
				return
			# Before the money, not after. Buying into a full hold used to take
			# the credits, erase the part off the shelf and then log "left
			# behind" â€” the module was gone from both places and paid for.
			# FOR THIS PART'S SHAPE, not one free cell: a wide part into a hold
			# with a single gap passed a `hold_full` test and was then paid for
			# and lost when `stow` found nowhere to put it.
			if not Run.has_room_for(m):
				Run.log_line("The hold is full. Nowhere to put it.", &"them")
				return
			# One shelf, four buyers. ASK, and pay only if you won â€” a purchase
			# that charged first and lost the race would take credits for a part
			# somebody else is carrying. See RunState.take_option().
			if not await Run.take_option(n, MapGen.OPTION_SHOP + slot):
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
			# Every sale here moves this market's price down a notch. One good
			# system must not absorb an unlimited hold at the same rate, or the
			# question stops being "how far do I haul this" and becomes "carry
			# everything to the best place I have seen".
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
			# THE NET, NOT THE ASK. The yard takes your frame in part exchange,
			# so what leaves your account is the difference -- and it is worked
			# out from the same two calls the panel printed, so the number you
			# agreed to is the number you pay. Computed BEFORE `take_option`,
			# because `Run.hull` is about to stop being the ship being valued.
			var price2: int = maxi(0, Market.hull_price(n, h)
				- Market.hull_bid(n, Run.hull))
			if Run.credits < price2:
				return
			# One rack, one hull. Same race as the shelf above, and the same
			# order: ask, then pay.
			if not await Run.take_option(n, MapGen.OPTION_SHOP_HULL):
				var who2 := Net.taker_name(n.index, MapGen.OPTION_SHOP_HULL)
				Run.log_line("Gone.%s" % (" %s is flying it." % who2.to_upper()
					if who2 != "" else ""), &"them")
				_refresh()
				return
			Run.add_credits(-price2)
			Audio.act(&"hull_transfer")
			# THE PRICE AND THE RACK GO WITH IT, so the move can be called off.
			# `abandon_move` needs to know what to refund and which shelf to put
			# the hull back on, and this is the only place that knows either.
			Run.transfer_to_hull(h, price2, n)
			# STRAIGHT TO THE DOCK. Always, even when nothing was carried -- the
			# new frame arrives BARE now, so a swap with an empty pad is still a
			# ship with no guns on it and a decision to make about that.
			Router.show_transfer()
			return
	_refresh()


## What this manufacturer wants doing, and what you can close standing here.
##
## Three groups, in the order a player acts on them: things you can be PAID for
## right now, then things you have already agreed to that this desk cannot close,
## then the board. Money first — a player walking into a berth holding finished
## work should see that before anything else on the page.


func _refresh_work(n: MapGen.MapNode) -> void:
	if _board != null:
		_board.posts = _board_posts(n)
		_board.dev = int(n.development)
		_board.station_seed = hash([n.layer, n.row, n.index])
		_board.queue_redraw()
	if _board_lamp != null:
		_board_lamp.dev = int(n.development)
	if _work != null:
		_work.offset_top = PostingBoard.FRAME_W + 10.0 + (PostingBoard.HEADER if _on_screen() else 0.0)
		_work.offset_bottom = -(PostingBoard.FRAME_W + 8.0 + (PostingBoard.TICKER if _on_screen() else 0.0))
	Widgets.clear(_work)
	var offers := Contracts.board(n)
	var ready := Run.deliverable_at(n)
	var hot := Run.heat_deliverable_at(n)
	var mine := _open_elsewhere(n)

	# The TAB goes at a station with no manufacturer behind it — see the fabricator's
	# note. An empty board with a heading is a page telling you about a thing
	# that is not there.
	_enable_tab(&"work", not (offers.is_empty() and ready.is_empty()
		and hot.is_empty() and mine.is_empty()))
	if not _tabs_on.get(&"work", true):
		return

	for job in ready:
		_work.add_child(_deliver_row(job as ContractData, "DELIVER"))
	for job in hot:
		# Said with the number, because the heat on your hull is falling every
		# time you jump and the player is being asked to notice it.
		_work.add_child(_deliver_row(job as ContractData,
			"OFFLOAD %d HEAT" % (job as ContractData).amount))

	if not mine.is_empty():
		# ONE CARD, NOT A HEADING AND A LIST. On a board every child is a notice
		# somebody pinned up, and a loose heading with its rows under it would
		# have been pinned as separate scraps and tilted apart.
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation", 3)
		card.add_child(UITheme.body("SIGNED, ELSEWHERE", _ink(&"head"), UITheme.FS_SMALL))
		for job in mine:
			var c: ContractData = job
			var row := UITheme.body("· %s" % c.status_line(), _ink(&"ink"), UITheme.FS_SMALL)
			row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			card.add_child(row)
		_work.add_child(_note(PostingBoard.INDEX, card))

	# On a screen the tabs count the work by kind and show only the one picked;
	# your own deliveries stay up whichever is.
	var counts: Array[int] = [0, 0, 0, 0]
	for job in offers:
		var c3: ContractData = job
		if Run.holds_contract(c3):
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
		if Run.holds_contract(c2):
			continue
		if only >= 0 and int(c2.kind) != only:
			continue
		_work.add_child(_offer_row(c2))


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
		var edge := Color("#3ec8e0") if paper != NOTE_STICKY else Color("#f0c040")
		pc.add_theme_stylebox_override("panel", UITheme.flat(Color("#0c2034"), edge, 0, 7, 8))
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
			&"head": return Color("#7fd4ff")
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


func _offer_row(c: ContractData) -> Control:
	if _on_screen():
		return _listing(c)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 5)
	# THE FLAG, beside the name rather than instead of it. A contract is written
	# in that manufacturer's own voice -- you are being asked for something BY
	# somebody, and the somebody is half the note.
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
	box.add_child(_sign_button(c))
	return _note(NOTE_PAPER, box)


## A contract as a marketplace listing, on a city's or a capital's screen:
## the manufacturer's emblem for its photo, the pay for its price, the ask for
## its description, where it is, and SIGN for "message seller".
func _listing(c: ContractData) -> Control:
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
			DB.manufacturer_name(mid).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1,
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
	box.add_child(_sign_button(c))
	return _note(NOTE_PAPER, box)


## SIGN, big enough to read as the one thing on a note you can press (Jon: "can
## the sign buttons be a bit bigger? I wanna make sure that the user still
## understands what can and cannot be clicked"). Nothing else on the board
## looks like a button.
func _sign_button(c: ContractData) -> Button:
	var take := Widgets.button("SIGN", func() -> void:
		Run.take_contract(c)
		_refresh())
	take.tooltip_text = Widgets.tip("Nothing here expires. Sign it and forget it, or never sign it at all.")
	take.add_theme_font_size_override("font_size", UITheme.FS_HEAD)
	take.custom_minimum_size = Vector2(72, 26)
	take.size_flags_horizontal = Control.SIZE_SHRINK_END
	return take


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


## Whether your ship can be opened up here now: on the yard, nothing over it.
func cutaway_ready() -> bool:
	return Run.hull != null and _cutaway == null and _mine_view != null and is_instance_valid(_mine_view) 		and _mine_view.is_visible_in_tree() and (Router.dock == null or not is_instance_valid(Router.dock))


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
	open_cutaway()


## Open your ship up in the yard. Public for the harnesses.
func open_cutaway() -> CutawayView:
	if not cutaway_ready():
		return null
	if _mine_outline != null:
		_mine_outline.visible = false
	if _mine_slab != null and is_instance_valid(_mine_slab):
		_mine_slab.visible = false
	_cutaway = CutawayView.open_over(self, _mine_view)
	# THE YARD ITSELF ZOOMS (Jon: "can we actually just zoom into the scene?"),
	# without your ship's name sign, which would stand over the lifted parts, or
	# its floor reflection, a ghost of the ship under the blur
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
			_scene.queue_redraw())
	return _cutaway


## Which station this is, as one number: the run's galaxy and the node's place
## in it. What a room's views, walkers and cables are picked from, so the same
## station looks the same every visit and the next one along does not.
func _place_seed(n: MapGen.MapNode) -> int:
	return absi(hash([Run.galaxy_seed, n.index]))


## Tell a room where it is: how built-up the station is and who holds it.
##
## THE SAME TWO FIELDS FOR EVERY ROOM, which is what lets every deck be the same
## station -- lamps by development, livery on the trim by manufacturer.
func _dress_room(room: StationRoom, n: MapGen.MapNode) -> void:
	if room == null or not is_instance_valid(room) or n == null:
		return
	room.dev = int(n.development)
	room.manufacturer = n.manufacturer
	room.place_seed = _place_seed(n)
	room.queue_redraw()
	_hang_banners(room, n, room.banner_spots())


## A ship's figures, directly above the ship.
##
## ABOVE THE SHIP YOU ARE POINTING AT, which is where the eye already is. It used
## to be parked over the OTHER ship, on the reasoning that it must not cover the
## one you are reading about -- but the band of wall over the berths is tall
## enough to hold it without covering either. Centred on the hull's ink, kept
## inside the hangar, and sized to its own content: all four offsets written here,
## because a preset writes the control's current rect into them.
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


## How a hung banner is sized, the gap between two, and the rod they hang from.
##
## LONG AND NARROW. Its own width units at `BANNER_K`, but `BANNER_LEN` tall
## rather than its own height: the rail's flag blown up to the same proportions
## read as a sign on a wall, where a hung length of it reads as colours. The
## emblem sits at the top and the manufacturer's hem at the foot, so the length
## between is plain field -- which is what a real hanging banner is.
const BANNER_K := 2.0
const BANNER_LEN := 148.0
const BANNER_GAP := 6.0
const BANNER_ROD := Color("#3d5273")


## Hang the station's manufacturer banners in a room.
##
## THE BANNERS LEFT THE RAIL AND WENT INTO THE ROOMS. At the head of the rail they
## were two flags over a list; in the rooms they are what a manufacturer actually
## does to a station it holds -- its colours hung in the hangar, pinned on the
## board, over the till. Still real `ChassisSelect.Banner`s rather than pictures of
## them, so pointing at one still gets the manufacturer's readout.
##
## Children of the ROOM, so they draw over its walls and under everything that
## stands in it. Each spot is a horizontal anchor fraction and a top; the whole set
## hangs side by side from a rod, centred on it.
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


## Which manufacturers have a notice of their own up on the Hiring Board.
##
## WHOEVER HOLDS THE STATION, first, because a notice is how a place says who runs
## it. Then the place itself: lawless space gets Redline's flyer, since Redline is
## never at the address on its invoices and a lawless board is exactly where it
## would turn up; a cosmopolitan station gets a couple of visitors, picked off the
## station's own index so the same station always carries the same ones. Three at
## most -- the board has three places to put them.
func _board_posts(n: MapGen.MapNode) -> Array[StringName]:
	var out: Array[StringName] = []
	if n == null:
		return out
	for mid in n.berths:
		if DB.manufacturers.has(mid) and out.size() < 3:
			out.append(mid)
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

