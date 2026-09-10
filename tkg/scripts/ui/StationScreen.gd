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
## Whose yard this is. Null on a station nobody holds.
## The berths this station is held by, flown at the head of the rail.
##
## BUILT FROM THE NODE, not a fixed set of slots. It was two banners, then three,
## and each time the count went up the extra berth was dropped in silence -- a
## screen that shows two of three manufacturers is worse than one that shows
## none, because it looks correct. One flag per berth, however many that is, and
## `_flag_scale` shrinks them until they fit.
var _flagrow: HBoxContainer
## The door. Held as a member because whether it opens is run state -- see
## `_refresh_undock` -- and the rail that builds it is built once.
var _undock: Button
var _bench: VBoxContainer
## The Exchange: your hold, and the two places you can carry things to.
var _hold_grid: HoldGrid
var _hold_head: Label
var _sell_desk: TradeCounter
var _sell_note: Label
## The Promenade: the till across the front of the shop.
var _till: TradeCounter
## The room the two of them stand in.
var _shop: ShopScene
var _till_note: Label
var _hull_offer: VBoxContainer
## The service list, a GRID of two so seven short rows are four lines.
## The yard's machines, standing in the hangar's front bay.
var _rigs: HBoxContainer
## How wide one machine's slot in the bay is.
const RIG_W := 92
## What is posted at this station and what you can close here. Above the shelf,
## because it is the part of a station that is about WHERE YOU GO NEXT.
var _work: VBoxContainer
## The station in section, the frame it slides inside, and the ride.
var _spine: StationSpine
var _building: Control
var _lift: Tween
## The fault picker, while it is open. Null the rest of the time.
var _purge_prompt: Control
## The deal, in the shipyard's heading row: the sum in words, the number that
## leaves your account, and the button that does it.
var _yard_ask: Label
var _yard_trade: Label
var _yard_price: Label
var _yard_take: Button
## The berth, and the four things standing in or over it.
var _scene: YardScene
var _scene_ship: ShipView
## Your own ship, standing in the left berth with its parts on it.
var _mine_view: ShipView
var _scene_hit: Control
var _scene_slab: Control
var _scene_hint: Label
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
	[&"work", "HIRING HALL", "WORK POSTED"],
	[&"bench", "LABORATORY", "FABRICATOR"],
]
## How wide the section is. Wide enough for "HIRING HALL" plus a count at
## FS_SMALL without either wrapping, which is what sets it -- not a round number.
const RAIL_W := 156
## Air between two flags.
const FLAG_GAP := 7
## How big the berth flags fly, in pixels per banner unit, biggest first.
##
## `Banner.S` is 3 and that is the size on a chassis card; this is the head of
## the screen, so it starts at 4 and steps down only when it has to.
##
## WHOLE NUMBERS ONLY. The banner draws its hem and emblem at multiples of this,
## so a fractional scale puts the whole flag on half-pixels -- 3.5 would fit
## three at 45.5 wide and would be the wrong answer.
const FLAG_STEPS: Array[float] = [4.0, 3.0, 2.0, 1.0]


## The biggest whole scale at which `count` flags fit the rail side by side.
##
## MEASURED, not chosen: three at 4 come to 170 against a 156 rail, which is why
## the constant could not simply be one number. Three at 3 come to 131.
static func _flag_scale(count: int) -> float:
	var n := maxi(1, count)
	for k in FLAG_STEPS:
		var wide := float(n) * float(ChassisSelect.Banner.UNITS_W) * k 			+ float(n - 1) * float(FLAG_GAP)
		if wide <= float(RAIL_W):
			return k
	return FLAG_STEPS[FLAG_STEPS.size() - 1]
## How tall one deck cell is. Two lines of FS_SMALL plus the padding that keeps
## the highlight from touching the text.
const DECK_H := 44
## How wide the station's name line is allowed to be before it wraps. Bounded on
## purpose — see the note in _build().
const HEADER_W := 560
## How deep the band holding that line is. The line is centred in it, so this is
## the whole of the air between the HUD and the first panel -- one number rather
## than a margin above and a separation below that have to be kept in step.
const HEADER_BAND := 34
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
	_header.custom_minimum_size = Vector2(HEADER_W, 0)
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
	rail.add_theme_constant_override("separation", 3)
	rail.custom_minimum_size = Vector2(RAIL_W, 0)
	rail.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_flagrow = HBoxContainer.new()
	_flagrow.add_theme_constant_override("separation", FLAG_GAP)
	_flagrow.alignment = BoxContainer.ALIGNMENT_CENTER
	rail.add_child(_flagrow)
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
	var headband := CenterContainer.new()
	headband.custom_minimum_size = Vector2(0, HEADER_BAND)
	headband.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	headband.add_child(_header)
	body_col.add_child(headband)
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


## THE YARD: one hangar, with the ship for sale in the berth and the yard's own
## machines standing in the bay in front of it.
##
## THE SERVICES USED TO BE A TABLE ON TOP OF THE PICTURE. A panel of four rows --
## label, price, a stripe and some pips -- sitting over a drawn hangar, so the
## deck said where you were and a spreadsheet said what you could do there. They
## are `ServiceRig`s now: a welding cart, an overhaul gantry, a fuel bowser and a
## fault post, standing on a floor `YardScene` grew for them. Same four actions,
## same four prices, no table.
##
## The panel is gone rather than emptied, so the hangar gets its hundred and
## fifteen pixels back and the bay has somewhere to be.
func _page_services() -> Control:
	# NO HEADING, AND NO PANEL AROUND IT EITHER.
	#
	# The word SHIPYARD sat over a rule above a drawn hangar with two ships in
	# it, which is a caption on a photograph of a room you are standing in. The
	# deck rail already says SHIPYARD and the picture already says so; thirty
	# pixels of the only deck that can use them went to saying it a third time.
	#
	# THE DEAL WENT WITH IT, into the bay under the ship it is the price of. It
	# was up in the heading row so it could never be the thing the hover hid --
	# but the bay is not hidden by anything, and a price under the hull it buys
	# needs no explaining at all.
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	_hull_offer = VBoxContainer.new()
	_hull_offer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_hull_offer.add_theme_constant_override("separation", 0)
	var yw := _flat_panel(_hull_offer)
	yw.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(yw)
	return col


## THE BERTH, WITH THE SHIP STANDING IN IT.
##
## FULL BLEED, AND THE NUMBERS ARRIVE WHEN YOU POINT AT THE SHIP. The Yard is
## the only deck in the game whose content is a SINGLE OBJECT -- the Promenade
## has a card fan, the Exchange a packed grid, the Hall a list of contracts --
## and that is the whole reason it can carry a scene. There is nothing here for
## a backdrop to sit behind and obscure.
##
## The price and TAKE IT stay up in the heading row, so the deal is never the
## thing that is hidden: what the hover reveals is the ARGUMENT for the deal,
## and what it hides while your hands are still is the room the ship is in.
func _offer_column(h: HullData) -> Control:
	var n: MapGen.MapNode = Run.node_at()
	var box := Control.new()
	box.clip_contents = true
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.custom_minimum_size = Vector2(0, SCENE_H)

	_scene = YardScene.new()
	_scene.dev = int(n.development)
	_scene.manufacturer = n.manufacturer
	_scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_child(_scene)

	# --- THE SHIP, AT 1x, STANDING ON THE CRADLE.
	#
	# Not centred in the panel. A hull floating at the vertical middle of a room
	# that has a floor in it reads as hovering, and the entire reason to draw a
	# berth is that the ship is IN one -- so it is placed off `cradle_y` and its
	# own ink, which is the only measurement that knows where its belly is.
	#
	# NULL IS A REAL ANSWER. Not every yard has a hull on the blocks, and the
	# hangar is the deck now rather than the offer's backdrop -- so an empty
	# berth is an empty berth with the machines still in it.
	# --- YOUR OWN SHIP, IN THE LEFT BERTH, WEARING EVERYTHING YOU FITTED.
	#
	# THE THING BEING TRADED IN WAS NEVER ON THE DECK. The yard drew the hull for
	# sale and reduced your own ship to a clause -- "less 25 for your Emberwright"
	# -- which is the half of the deal you actually own. Both ships stand in the
	# hangar now and the part exchange is a picture instead of a sentence.
	#
	# `ShipBuild.fitted_out` plus a `MountPoints` in display mode is the pair the
	# refit and moving-day screens already use: the view blits the hull and the
	# mounts put the guns on it. Nothing here is new machinery, only a second
	# place that needed it.
	if Run.hull != null:
		var mine := ShipView.new()
		mine.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mine.self_clip = false
		mine.setup_build(ShipBuild.fitted_out(Run.hull, Run.installed))
		mine.custom_minimum_size = Vector2(float(mine._w), float(mine._h))
		box.add_child(mine)
		_mine_view = mine
		# THE MOUNTS ARE A CHILD OF THE VIEW, never a sibling. `attach` anchors
		# them to their parent, so parenting them to the ship makes every
		# coordinate they draw the ship's own -- one place reasons about the bob,
		# the magnification and the centring.
		#
		# PASSIVE, WHICH IS THE WHOLE POINT. This is a PICTURE of your ship, not
		# a place to change it -- the same call the combat view makes for the
		# same reason. Without it the hull answered the pointer: hardpoints lit
		# up, fitted parts highlighted, and you could drag a gun off your own
		# ship in a shop that has nowhere to put it. `passive` stops all three
		# and hides the empty mounts as well, since a ring round a hardpoint is
		# an invitation to do something this deck cannot do.
		#
		# It also drops the `ship`/`fitted` override that was here: that pair is
		# for showing SOMEBODY ELSE'S hull, and this is your own, which is what
		# `MountPoints` reads by default.
		var mpts := MountPoints.new()
		mine.add_child(mpts)
		mpts.attach(mine)
		mpts.passive()

		var mine_name := VBoxContainer.new()
		mine_name.add_theme_constant_override("separation", 1)
		mine_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mine_name.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
		mine_name.offset_left = 10
		mine_name.offset_top = -34 - YardScene.BAY_H
		mine_name.offset_bottom = -6 - YardScene.BAY_H
		# `Run.display_name`, NOT `hull.name`. A ship you have named flies as its
		# chassis everywhere that forgets this -- the exact bug RunState's own
		# header records against the combat plate, arriving again on the one deck
		# where your ship stands next to somebody else's for comparison. Anything
		# that shows the player's ship TO the player calls that function.
		mine_name.add_child(UITheme.body(Run.display_name().to_upper(),
			DB.manufacturer_colour(Run.hull.manufacturer), UITheme.FS_HEAD))
		mine_name.add_child(UITheme.body("YOURS", UITheme.QUOTE, UITheme.FS_SMALL))
		box.add_child(mine_name)

	if h == null:
		_scene_ship = null
		_scene_hit = null
		_scene_slab = null
		_scene_hint = null
		var bare := UITheme.body("NOTHING ON THE BLOCKS",
			UITheme.COLD, UITheme.FS_SMALL)
		bare.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bare.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		bare.offset_left = -220
		bare.offset_right = -10
		bare.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		bare.offset_top = -26 - YardScene.BAY_H
		bare.offset_bottom = -8 - YardScene.BAY_H
		box.add_child(bare)
		_add_rigs(box)
		return box

	var v := ShipView.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.self_clip = false
	v.setup_preview(h, 0, 1)
	box.add_child(v)
	_scene_ship = v

	# THE HOVER TARGET IS THE SHIP'S INK, not its canvas. A hull sprite carries a
	# lot of transparent margin -- a 324x112 sheet holds 241x106 of hull -- so a
	# target the size of the sheet would fire from forty pixels of empty air.
	var hit := Control.new()
	hit.mouse_filter = Control.MOUSE_FILTER_STOP
	hit.mouse_entered.connect(_on_ship_hover.bind(true))
	hit.mouse_exited.connect(_on_ship_hover.bind(false))
	box.add_child(hit)
	_scene_hit = hit

	# --- WHAT IT IS, always. Bottom left, out of the berth.
	var name_col := VBoxContainer.new()
	name_col.add_theme_constant_override("separation", 1)
	name_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# UNDER ITS OWN BERTH, which is the right-hand one -- your ship's name is
	# under the left. And above the bay, not on the deck edge: the machines took
	# the bottom hundred pixels, and a hull's name across a fuel bowser is
	# neither a name nor a bowser.
	name_col.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	name_col.alignment = BoxContainer.ALIGNMENT_END
	name_col.offset_left = -260
	name_col.offset_right = -10
	name_col.offset_top = -34 - YardScene.BAY_H
	name_col.offset_bottom = -6 - YardScene.BAY_H
	name_col.add_child(UITheme.body(h.name.to_upper(),
		DB.manufacturer_colour(h.manufacturer), UITheme.FS_HEAD))
	# NOT "POINT AT THE SHIP". The deck has two hulls standing in it now and the
	# one thing a label under this one has to say is which of them you can buy.
	# How to read it is discoverable; which is which is not.
	_scene_hint = UITheme.body("FOR SALE", UITheme.QUOTE, UITheme.FS_SMALL)
	name_col.add_child(_scene_hint)
	box.add_child(name_col)

	# --- THE DEAL, IN THE BAY UNDER THE SHIP IT BUYS.
	#
	# It was a row across the top of the deck, above a rule, beside the word
	# SHIPYARD -- put there so the hover could never hide it. The bay is not
	# hidden by anything either, and down here the price is under the hull it is
	# the price OF, opposite the machines that work on the one you flew in.
	var deal := VBoxContainer.new()
	deal.add_theme_constant_override("separation", 3)
	deal.alignment = BoxContainer.ALIGNMENT_CENTER
	deal.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	deal.anchor_left = 0.58
	deal.offset_left = 0
	deal.offset_right = -12
	deal.offset_top = -YardScene.BAY_H + 12
	deal.offset_bottom = -12
	# THE SUM AS A RECEIPT, not as a sentence.
	#
	# It read "LESS 25 FOR YOUR IRONSIDE CUTTER", which was written when your own
	# ship appeared nowhere on this deck and the line had to say WHICH ship was
	# worth 25. It is standing in the left berth with its name under it now, so
	# the sentence spends most of itself repeating the picture -- and "less 43
	# for your Ironside Cutter" is an awkward thing to read besides.
	#
	# TWO ROWS AND A COLUMN OF FIGURES. A price you are subtracting from another
	# price is a sum, and a sum wants its numbers under each other; a right-
	# aligned line of prose cannot line up a column and a grid does it for free.
	var ledger := GridContainer.new()
	ledger.columns = 2
	ledger.add_theme_constant_override("h_separation", 12)
	ledger.add_theme_constant_override("v_separation", 1)
	ledger.size_flags_horizontal = Control.SIZE_SHRINK_END
	ledger.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for row in [["ASKING", true], ["YOUR SHIP", false]]:
		var cap := UITheme.body(String(row[0]), UITheme.QUOTE, UITheme.FS_SMALL)
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ledger.add_child(cap)
		var val := UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val.custom_minimum_size = Vector2(52, 0)
		val.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ledger.add_child(val)
		if bool(row[1]):
			_yard_ask = val
		else:
			_yard_trade = val
	deal.add_child(ledger)
	var buy := HBoxContainer.new()
	buy.add_theme_constant_override("separation", 10)
	buy.alignment = BoxContainer.ALIGNMENT_END
	_yard_price = UITheme.body("", UITheme.EMBER, UITheme.FS_HEAD)
	_yard_price.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_yard_price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buy.add_child(_yard_price)
	_yard_take = _commit_button("TAKE IT", func() -> void: pass)
	_yard_take.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buy.add_child(_yard_take)
	deal.add_child(buy)
	box.add_child(deal)

	# --- AND THE ARGUMENT, on the right, only while you are pointing.
	_scene_slab = _offer_slab(h)
	# OVER YOUR OWN SHIP, NOT OVER THE ONE YOU ARE POINTING AT.
	#
	# It was anchored top right, which is the corner the ship for sale now stands
	# in -- so pointing at a hull to read about it hid the hull. The slab has to
	# overlap SOMETHING; the free wall above the berths is a couple of hundred
	# pixels and the panel is more than that. The one it can afford to cover is
	# the ship whose numbers are already on it: every figure here is a delta
	# against your own frame, so the Long Way's contribution to this panel is the
	# arithmetic, not the silhouette.
	_scene_slab.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_scene_slab.offset_left = 8
	_scene_slab.offset_right = SLAB_W + 8
	_scene_slab.offset_top = 8
	# AND ITS HEIGHT COMES FROM ITS CONTENT, in `_place_scene_ship`.
	#
	# `set_anchors_and_offsets_preset` writes the control's CURRENT rect into the
	# offsets, so `offset_bottom` kept whatever height the panel happened to have
	# when the preset ran -- 293 for 189 of content, which is a hundred pixels of
	# nothing under the last perk line. The minimum is not knowable until the
	# panel is in the tree, so the one place that already runs after layout owns
	# it. Same family as the `set_anchors_preset` trap that collapsed the
	# transfer screen into its own top third.
	_scene_slab.visible = false
	box.add_child(_scene_slab)

	_add_rigs(box)
	box.resized.connect(_place_scene_ship)
	_place_scene_ship.call_deferred()
	return box


## Stand both ships on their cradles and put the hover target on the offer's
## metal.
func _place_scene_ship() -> void:
	if _scene == null:
		return
	if _scene_slab != null and is_instance_valid(_scene_slab):
		_scene_slab.offset_bottom = _scene_slab.offset_top 			+ _scene_slab.get_combined_minimum_size().y
	_stand(_mine_view, 0)
	var at := _stand(_scene_ship, 1)
	if _scene_hit != null and _scene_ship != null 			and is_instance_valid(_scene_ship):
		var ink := _scene_ship.ink_rect()
		_scene_hit.position = Vector2(at.x + float(ink.position.x),
			at.y + float(ink.position.y)).round()
		_scene_hit.size = Vector2(float(maxi(1, ink.size.x)),
			float(maxi(1, ink.size.y)))


## Put one ship down in berth `i`, and report where its canvas landed.
##
## THE INK IS WHAT GETS PLACED, NEVER THE CANVAS. A hull sheet carries a lot of
## transparent margin -- a 324x112 holds 241x106 of actual ship -- so centring
## the canvas puts a ship visibly off its own cradle, by however much margin
## happens to be on one side.
func _stand(v: ShipView, berth: int) -> Vector2:
	if v == null or not is_instance_valid(v):
		return Vector2.ZERO
	var ink := v.ink_rect()
	var iw := float(maxi(1, ink.size.x))
	var ih := float(maxi(1, ink.size.y))
	var at := Vector2(
		_scene.size.x * YardScene.berth_x(berth) - iw * 0.5 - float(ink.position.x),
		_scene.cradle_y() - ih - float(ink.position.y) - 2.0)
	v.position = at.round()
	return v.position


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
func _offer_slab(h: HullData) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# --- WHAT IT IS, AND WHAT THE PLUSES AND MINUSES ARE AGAINST.
	#
	# THE DELTAS NEVER SAID WHAT THEY WERE MEASURED FROM. Every gauge carries a
	# "+1" or a "-2" and the panel simply assumed you knew those were against the
	# ship you flew in on. It is standing in the next berth with its name on it,
	# so naming it here closes the loop for one line.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(UITheme.body(h.name.to_upper(),
		DB.manufacturer_colour(h.manufacturer), UITheme.FS_HEAD))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(gap)
	var against := UITheme.body("AGAINST %s" % Run.display_name().to_upper(),
		UITheme.QUOTE, UITheme.FS_SMALL)
	against.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(against)
	col.add_child(head)

	var hand := h.hand_size - Run.hull.hand_size
	col.add_child(UITheme.body("%s · %s TIER · HAND %d%s" % [
		HullData.weight_name(h.weight).to_upper(), h.tier_letter(), h.hand_size,
		"" if hand == 0 else (" (%+d)" % hand)], UITheme.COLD, UITheme.FS_SMALL))
	col.add_child(UITheme.hsep())

	# BOTH SIDES BARE, which is what makes the comparison honest: nothing is
	# carried over by the swap itself, so what it changes is the FRAME.
	var mine := Run.hull_attributes(Run.hull)
	var theirs := Run.hull_attributes(h)
	for i in mini(theirs.size(), mine.size()):
		theirs[i]["delta"] = int(theirs[i].value) - int(mine[i].value)

	# --- SEVEN GAUGES IN TWO COLUMNS, NOT SEVEN STACKED ROWS.
	#
	# THE SLAB WAS TALLER THAN THE SHIP IT DESCRIBED. Stacked, the seven
	# attributes plus the perks made a column near three hundred pixels deep,
	# anchored over the berth -- so pointing at a hull to learn about it COVERED
	# the hull. Paired, the same seven are four rows, and the whole panel fits in
	# the band of empty wall above the ships where it hides nothing at all.
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
		blk.setup(part, DB.manufacturer_colour(h.manufacturer))
		pair.add_child(blk)
	col.add_child(pair)

	var mounts := HBoxContainer.new()
	mounts.add_theme_constant_override("separation", 7)
	mounts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mounts.add_child(UITheme.body("MOUNTS", UITheme.COLD, UITheme.FS_SMALL))
	for sl in [ModuleData.Slot.WEAPON, ModuleData.Slot.SYSTEM,
			ModuleData.Slot.UTILITY]:
		var d := h.slots_for(sl) - Run.hull.slots_for(sl)
		mounts.add_child(UITheme.body("%s %d%s" % [
			ModuleData.slot_name(sl).to_upper().substr(0, 3), h.slots_for(sl),
			"" if d == 0 else (" (%+d)" % d)],
			UITheme.CHILL if d >= 0 else UITheme.LEAVE, UITheme.FS_SMALL))
	col.add_child(mounts)

	# THE PERKS GET THE WHOLE WIDTH NOW, which is most of what was wrong with
	# them: at 230 pixels "SALVAGE RACK: SCRAPPING MODULES PAYS +40%" broke after
	# PAYS and left "+40%." alone on a line of its own.
	for pid in h.perks():
		var pk := UITheme.body(DB.perk_text(pid), UITheme.EMBER, UITheme.FS_SMALL)
		pk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pk.custom_minimum_size = Vector2(SLAB_W - 22, 0)
		pk.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(pk)

	# --- AND THE SLAB ITSELF.
	#
	# OPAQUE, WHICH IT SHOULD ALWAYS HAVE BEEN. It sat at 86% so the scene could
	# show through, and what showed through was a hull -- grey plating behind
	# grey figures, which is the one background text cannot be read on. Nothing
	# is gained by seeing a ship through its own numbers.
	#
	# FRAMED IN THE SELLER'S COLOUR, so the panel belongs to the ship it is
	# describing rather than to the screen it is floating on. The same mark the
	# name above it wears.
	var slab := PanelContainer.new()
	slab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mark := DB.manufacturer_colour(h.manufacturer)
	slab.add_theme_stylebox_override("panel",
		UITheme.flat(Color(0.031, 0.043, 0.066, 0.98),
			Color(mark.r, mark.g, mark.b, 0.55), 0, 8, 11))
	slab.add_child(col)
	slab.custom_minimum_size = Vector2(SLAB_W, 0)
	return slab


## A label, a gauge and a figure, on the row height everything else uses.
func _page_work() -> Control:
	var box := Widgets.section("work")

	# --- THE WORK IS PINNED TO A BOARD.
	#
	# THE FURNITURE IS UNDER THE CONTENT, the same move the Promenade's shelf
	# makes. A contract is not a row in a table -- it is a notice somebody walked
	# up and pinned there, and the difference between those two things is a
	# frame, a pin and a shadow. The rows do not change at all; the board
	# measures itself off them.
	var stack := Control.new()
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var board := PostingBoard.new()
	board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_child(board)

	_work = VBoxContainer.new()
	_work.add_theme_constant_override("separation", 9)
	_work.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# INSIDE THE FRAME, with room for a pin above the first notice.
	_work.offset_left = PostingBoard.FRAME_W + 6.0
	_work.offset_right = -(PostingBoard.FRAME_W + 6.0)
	_work.offset_top = PostingBoard.FRAME_W + 9.0
	_work.offset_bottom = -(PostingBoard.FRAME_W + 6.0)
	stack.add_child(_work)
	board.watch(_work)
	box.add_child(stack)
	return Widgets.panel_with(Widgets.pad(box))


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
var _shelf: VBoxContainer


func _page_stock() -> Control:
	# NO SECTION HEADING AT THE TOP. "STOCK" over a rule, above a part that
	# already names itself in 16px, was a title for a page with one thing on it
	# -- and it cost thirty pixels off the top of the only band that is short of
	# them. The word moved down to the list it actually labels.
	# --- THE WHOLE DECK IS ONE ROOM, and the shop is two things standing in it.
	#
	# The rack was against one wall and the till against the other with a hole
	# between them -- two pieces of furniture floating on a panel. `ShopScene`
	# draws the floor they stand on, the wall behind them and the window over
	# them, which is the same move `YardScene` makes for the berth. Everything
	# below is laid out ON it, bottom-aligned, so both pieces sit on one floor.
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 5)
	var stack := Control.new()
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shop = ShopScene.new()
	_shop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_child(_shop)

	var box := HBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 14)

	_shelf = VBoxContainer.new()
	_shelf.add_theme_constant_override("separation", 8)
	_shelf.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# ITS OWN WIDTH, AND NO MORE -- exactly what the Exchange's hold does. The
	# rack is a fixed object now rather than something poured into the column, so
	# a column that claimed a share of the deck would leave a band of nothing
	# between the shelf and the till. What is left over goes to the till, which
	# is a room and can use it.
	_shelf.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.add_child(_shelf)

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
	# THE FLOOR BETWEEN THEM. With the rack shrunk to its own size the till took
	# every pixel that was left, so the place you PAY was half again the size of
	# the shop you were paying for -- which is the wrong way round. Both are
	# objects against opposite walls now and the slack is the space between them,
	# which is what a room is.
	var floorspace := Control.new()
	floorspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	floorspace.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(floorspace)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	# WIDE ENOUGH TO BE A ROOM AND NO WIDER: the counter needs a back wall to
	# stand against and somewhere to stack the day's takings, and that is about
	# this much.
	right.custom_minimum_size = Vector2(300, 0)
	right.size_flags_horizontal = Control.SIZE_SHRINK_END
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# AIR ABOVE IT, the same as the rack has, so the counter STANDS on the floor
	# `ShopScene` drew rather than hanging from the top of the deck.
	var air2 := Control.new()
	air2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	air2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(air2)
	_till = TradeCounter.new()
	_till.side = TradeCounter.Side.CHARGES
	# NO ROOM OF ITS OWN ANY MORE. `TradeCounter` builds a back wall and stacks
	# crates against it when it is given the height, and it was given the height
	# here -- so the deck had a room inside a room, in two different greys. It
	# gets exactly a desk now and stands in the one `ShopScene` draws.
	_till.custom_minimum_size = Vector2(0, TradeCounter.DESK_H)
	_till.size_flags_vertical = Control.SIZE_SHRINK_END
	_till.took.connect(_on_till)
	right.add_child(_till)
	box.add_child(right)

	stack.add_child(box)
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
## the hardpoints are on the SHIP page, and this is where things become money.
##
## And the hold is the REAL grid, not a list of its contents. It is the thing
## you pack, it already drags, and every part on it already answers a hover with
## its own readout and cards.
func _page_hold() -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 14)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_hold_head = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	left.add_child(_hold_head)
	_hold_grid = HoldGrid.new()
	# ITS OWN SIZE, ALWAYS. The grid draws a frame round the cells it holds, and
	# letting a container stretch it drew that frame out past the last column --
	# a four-wide hold in a six-wide box, which is a lie about how much room you
	# have.
	_hold_grid.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_hold_grid.dropped.connect(_on_hold_move)
	left.add_child(_hold_grid)
	var slack := Control.new()
	slack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(slack)
	box.add_child(left)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL

	right.add_child(UITheme.body("THE COUNTER", UITheme.COLD, UITheme.FS_SMALL))
	_sell_desk = TradeCounter.new()
	# IT TAKES THE WHOLE DECK NOW. With the chute gone the counter is the only
	# thing on this side, and a 76px slab floating over a column of nothing read
	# as a widget rather than as furniture. Grown, it is a service desk you walk
	# up to -- and the scale on it is drawn off the height, so it stands taller
	# with the counter instead of stretching.
	_sell_desk.custom_minimum_size = Vector2(0, 120)
	_sell_desk.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sell_desk.took.connect(_on_counter)
	right.add_child(_sell_desk)
	_sell_note = UITheme.body("Carry something here to be paid for it.",
		UITheme.QUOTE, UITheme.FS_SMALL)
	_sell_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_sell_note)
	box.add_child(right)
	return Widgets.panel_with(Widgets.pad(box))


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
	var box := Widgets.section("fabricator")

	# --- THE RECIPES ARE LOADED INTO A MACHINE.
	#
	# A recipe is a job you put INTO something, and what makes that read is a
	# hopper it goes in at, a body it happens in and a chute it comes out of. The
	# rows are untouched; `Fabricator` draws a bay behind each of them.
	var stack := Control.new()
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rig := FabricatorCase.new()
	rig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_child(rig)

	_bench = VBoxContainer.new()
	_bench.add_theme_constant_override("separation", 11)
	_bench.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# CLEAR OF THE HOPPER AND THE CHUTE, so the jobs sit in the body of the
	# machine rather than over its mouth.
	_bench.offset_left = FabricatorCase.CASE_W + 7.0
	_bench.offset_right = -(FabricatorCase.CASE_W + 7.0)
	_bench.offset_top = FabricatorCase.HOPPER_H + 9.0
	_bench.offset_bottom = -(FabricatorCase.CHUTE_H + 9.0)
	stack.add_child(_bench)
	rig.watch(_bench)
	box.add_child(stack)
	return Widgets.panel_with(Widgets.pad(box))


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

	var title := UITheme.body(deck, UITheme.CHILL, UITheme.FS_BODY)
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


func _show_tab(id: StringName) -> void:
	if not _pages.has(id) or not _tabs_on.get(id, true):
		return
	_tab = id
	for key in _pages:
		(_pages[key] as Control).visible = key == id
	_light_floor()
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
	_tabs_on[id] = on
	if _tabs.has(id):
		(_tabs[id] as Button).visible = on
	if not on and _tab == id:
		_show_tab(&"services")


## One service, as a ROW rather than as a wide button with centred text.
##
## A price belongs at the right edge of the row it prices, in a column with the
## other prices, so the eye reads a list of costs down one line. Centring the
## whole string put every price at a different x and turned five services into
## five unrelated sentences.
##
## The price is a child of the Button, anchored right and passing its mouse
## through — so the whole row is still one click target and the text is still
## two columns. Godot has no two-column Button; this is the cheapest thing that
## behaves like one.
## One thing the station will do to your ship, as a row you press.
##
## IT WAS A LABEL AND A NUMBER IN A BOX, four times over -- a price list, and it
## read like one. Nothing on it said what KIND of thing you were buying, or what
## the money would actually move, so the only way to tell the hull repair from
## the refuelling was to read both.
##
## Three things fix that without adding a word. A STRIPE down the left in the
## ink of what it touches -- green for the hull, blue for the tank, red for what
## is wrong with you -- so the four rows sort by colour before they are read. A
## GLYPH beside it, drawn rather than written, for the same reason the cards
## carry silhouettes. And, where the service moves a gauge you can already see
## at the top of the screen, PIPS: eight white cells appended to your hull bar
## is the answer to "what does +8 mean" given in the same shape the HUD gives it.
func _service(label: String, price_text: String, action: Callable,
		tone: Color = UITheme.CHILL, glyph: StringName = &"",
		pips: Vector2i = Vector2i.ZERO) -> Button:
	var b := Widgets.button("      " + label, action)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, ROW_H)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# ONE CHILD FOR ALL THE DRAWING. A stripe, a glyph and a row of pips as three
	# nodes is three more things for the layout to have opinions about; as one
	# `_draw` over the button's own rect they are just marks in known places.
	var art := Control.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.name = "Art"
	art.draw.connect(_draw_service.bind(art, tone, glyph, pips))
	b.add_child(art)

	var p := UITheme.body(price_text, UITheme.ICE, UITheme.FS_SMALL)
	p.name = "Price"
	p.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	p.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	p.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# NARROWER RESERVE, now that the row is half the page. 120 was most of a
	# two-column row and the label ran under the price.
	p.offset_left = -78
	p.offset_right = -8
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(p)
	return b


## THE YARD'S MACHINES, along the bay in front of the berth.
##
## INSIDE THE SCENE, not above it. They are the reason `YardScene` has a front
## bay at all, and putting them anywhere else would be the old table again with
## better pictures on it. Anchored to the bottom and given the bay's exact depth,
## so every rig stands on the line the cradle's posts come down to.
func _add_rigs(box: Control) -> void:
	_rigs = HBoxContainer.new()
	_rigs.alignment = BoxContainer.ALIGNMENT_CENTER
	_rigs.add_theme_constant_override("separation", 8)
	_rigs.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	# ON YOUR SIDE OF THE BAY, under YOUR ship.
	#
	# They were centred across the whole floor, which put a fuel bowser as near
	# to the hull for sale as to the one it would be fuelling. Every one of these
	# machines acts on the ship in the LEFT berth, and standing them under it is
	# the entire argument for taking them out of a table in the first place.
	_rigs.anchor_right = 0.55
	_rigs.offset_top = -YardScene.BAY_H
	_rigs.offset_left = 10
	_rigs.offset_right = 0
	box.add_child(_rigs)


## One machine in the bay.
func _rig(kind: int, label: String, price: int, action: Callable,
		live: bool, gauge: Vector2i = Vector2i.ZERO) -> ServiceRig:
	var r := ServiceRig.new()
	r.kind = kind
	r.label = label
	r.price = price
	r.gauge = gauge
	r.disabled = not live
	r.custom_minimum_size = Vector2(RIG_W, YardScene.BAY_H)
	r.pressed.connect(action)
	_rigs.add_child(r)
	return r


## The stripe, the glyph and the gauge preview on one service row.
##
## Everything is in whole pixels off the row's own height, so the marks sit on
## the same baseline whatever `ROW_H` becomes.
func _draw_service(c: Control, tone: Color, glyph: StringName,
		pips: Vector2i) -> void:
	var h := c.size.y
	var mid := floorf(h * 0.5)
	# THE STRIPE, full height and hard against the edge: it is the row's
	# category, not a decoration on it.
	c.draw_rect(Rect2(0.0, 0.0, 3.0, h), tone)

	# THE GLYPH, in a 10x10 box starting six pixels in. Drawn from rectangles
	# rather than loaded, because three marks at ten pixels is less work than an
	# asset pipeline for three marks at ten pixels -- and it inherits the tone,
	# so a row is one colour rather than a colour and a picture.
	var gx := 8.0
	var gy := mid - 5.0
	match glyph:
		&"repair":
			# A plate over a crack: a bar, and a bar across it.
			c.draw_rect(Rect2(gx, gy + 3.0, 10.0, 4.0), tone)
			c.draw_rect(Rect2(gx + 3.0, gy, 4.0, 10.0), tone)
		&"fuel":
			# A drum: a body, a band, and a spout.
			c.draw_rect(Rect2(gx + 1.0, gy + 1.0, 8.0, 9.0), tone)
			c.draw_rect(Rect2(gx + 1.0, gy + 4.0, 8.0, 2.0), UITheme.VOID)
			c.draw_rect(Rect2(gx + 3.0, gy - 1.0, 4.0, 2.0), tone)
		&"purge":
			# A break: two bars offset, with the gap between them the point.
			c.draw_rect(Rect2(gx, gy + 1.0, 4.0, 3.0), tone)
			c.draw_rect(Rect2(gx + 6.0, gy + 6.0, 4.0, 3.0), tone)
			c.draw_rect(Rect2(gx + 3.0, gy + 4.0, 4.0, 2.0), tone)

	# THE PIPS, right of the label and left of the price. `pips.x` of them are
	# what you are buying and light up; the rest are the room it goes into.
	if pips.y > 0:
		var cell := 4.0
		var gap := 1.0
		var n: int = mini(pips.y, 16)
		var w := float(n) * (cell + gap) - gap
		var x := c.size.x - 88.0 - w
		for i in n:
			var lit := i < pips.x
			c.draw_rect(Rect2(x + float(i) * (cell + gap), mid - 2.0,
				cell, 4.0), tone if lit else tone.lerp(UITheme.VOID, 0.72))


## Grey the price with the row. A disabled Button dims its own text through the
## theme; a child Label is not its text and stays bright, which reads as a price
## you can pay on a row you cannot press.
func _set_service_enabled(b: Button, on: bool) -> void:
	b.disabled = not on
	var p := b.get_node_or_null("Price") as Label
	if p != null:
		p.modulate = Color(1, 1, 1, 1.0 if on else 0.30)


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
	var span := absf(float(index) - _spine.car)
	var secs := clampf(0.16 + 0.10 * span, 0.18, 0.55)
	_lift = create_tween()
	_lift.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_lift.tween_method(_car_step, _spine.car, float(index), secs)


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
func _light_floor() -> void:
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
	_ride_to(_spine.active, was >= 0 and was != _spine.active)
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
	var count := 5 if n.region == MapGen.Region.COSMOPOLITAN else 3
	for i in count:
		var force := &""
		if n.region == MapGen.Region.TERRITORY:
			force = n.manufacturer
		elif n.region == MapGen.Region.COSMOPOLITAN:
			# Cosmopolitan hubs carry multiple manufacturers side by side.
			force = Rng.pick(r, DB.manufacturers.keys())
		var danger := n.danger + 3 if n.region == MapGen.Region.LAWLESS else maxi(1, n.danger - 2)
		var m := LootGen.roll_module(danger, force, n.region == MapGen.Region.LAWLESS, r)
		# Legitimate markets do not move Legendary and above.
		if n.region == MapGen.Region.COSMOPOLITAN and m.rarity > ModuleData.Rarity.EPIC:
			m.rarity = ModuleData.Rarity.EPIC
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
Stow it in the hold on the SHIP page, or sell it at the Exchange."
		% "; ".join(why).capitalize())


## The banner, the trade line, and the two gauges on the hull panel.


## The banner, the trade line, and the two gauges on the hull panel.


func _refresh_header(n: MapGen.MapNode) -> void:
	var note := ""
	match n.region:
		MapGen.Region.COSMOPOLITAN: note = " · stock from many manufacturers, strict inspections"
		MapGen.Region.LAWLESS: note = " · fenced goods, no questions"
	_header.clear()
	# Named by what the place is, not by the derived region label — "Frontier
	# station" says less than "Settlement station, moderate security".
	_header.append_text("[color=#%s]%s station[/color] · %s security · danger %d[color=#%s]%s[/color]" % [
		UITheme.ICE.to_html(false), MapGen.development_name(n.development),
		MapGen.security_name(n.security).to_lower(), n.danger,
		UITheme.COLD.to_html(false), note])

	# The clause that used to be its own label at the right-hand edge. Amber,
	# because it is the only part of this line you can act on.
	var tl := Market.trade_line(n)
	if tl != "":
		_header.append_text("[color=#%s] · %s[/color]"
			% [Color("#d99b29").to_html(false), tl])

	# HIDDEN, not blanked, on a station nobody holds. An empty flag is a
	# manufacturer with no mark rather than an absence of manufacturers, and
	# lawless space having no berth is a fact worth reading off the screen.
	Widgets.clear(_flagrow)
	var fk := _flag_scale(n.berths.size())
	for mid in n.berths:
		var mk: ManufacturerData = DB.manufacturers.get(mid)
		# SKIPPED, not blanked. An empty flag is a manufacturer with no mark
		# rather than an absence of manufacturers, and lawless space having no
		# berth is a fact worth reading off the screen -- as an empty rail head.
		if mk == null:
			continue
		var fl := ChassisSelect.Banner.new()
		# ITS OWN MINIMUM DEPTH, which the class does not set. `Banner` fixes only
		# its width and fills whatever height it is given, and the hem is cut from
		# the bottom edge -- so given less it would be a flag stopping mid-emblem.
		fl.s = fk
		fl.custom_minimum_size = Vector2(
			float(ChassisSelect.Banner.UNITS_W) * fk,
			float(ChassisSelect.Banner.UNITS_H) * fk)
		fl.manufacturer = mid
		fl.mark = mk.colour
		fl.field = mk.field
		_flagrow.add_child(fl)


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
	# --- the shipyard: your frame beside the one for sale.
	Widgets.clear(_hull_offer)
	var h: HullData = n.shop_hull
	var up := h != null and not n.taken.has(MapGen.OPTION_SHOP_HULL)
	# THE HANGAR IS BUILT EITHER WAY.
	#
	# It used to be built only when there was a ship for sale, which was fine
	# while the deck was a panel of services over a picture -- an empty yard just
	# lost the picture. The machines live IN the picture now, so a yard with
	# nothing on the blocks would have lost its repairs with its hull. `_offer`
	# takes null and leaves the berth empty.
	_hull_offer.add_child(_offer_column(h if up else null))
	if up:
		var ask := Market.hull_price(n, h)
		var part_ex := Market.hull_bid(n, Run.hull)
		var price: int = maxi(0, ask - part_ex)
		_yard_ask.text = "%d" % ask
		# SIGNED, because it is the one number on the deck that comes OFF the
		# other one, and a column of bare figures cannot say which way a row goes.
		_yard_trade.text = "-%d" % part_ex
		_yard_price.text = "%d CR" % price
		_yard_take.disabled = Run.credits < price
		# REBOUND EVERY REFRESH, because the hull on the blocks is not the same
		# object between visits and a Callable bound to the last one would buy a
		# ship that is not there.
		for c in _yard_take.pressed.get_connections():
			_yard_take.pressed.disconnect(c.callable)
		_yard_take.pressed.connect(_on_action.bind("take_hull", h))

	# --- AND THE MACHINES IN THE BAY.
	#
	# The same four services the panel above the picture used to list, standing
	# on the yard's own floor as things. A rig knows three things -- what it does,
	# what it costs, and whether the yard will do it -- which is exactly what a
	# row knew, minus the row.
	if _rigs == null:
		return
	Widgets.clear(_rigs)
	var missing := Run.max_hp() - Run.hp
	var full_hp := maxi(1, Run.max_hp())

	# THE GAUGE IS THE HULL BAR AT THE TOP OF THE SCREEN, at the same ten-cell
	# resolution -- so "+8" is shown in the shape you already read your hull in
	# rather than as a number you have to place. Painted on the machine's own
	# face, which is where a machine puts a gauge.
	var eight := mini(8, maxi(1, missing))
	var eight_cost := Market.repair_price(n, eight)
	var weld := _rig(ServiceRig.Kind.WELD, "PATCH +%d" % eight,
		eight_cost if missing > 0 else -1, _repair.bind(eight),
		missing > 0 and Run.credits >= eight_cost,
		Vector2i(int(round(float(eight) * 10.0 / float(full_hp))), 10))
	weld.tooltip_text = Widgets.tip("%.1f credits a point here. Work is dear on the frontier and cheap in a capital." % Market.repair_rate(n))

	var full_cost := Market.repair_price(n, missing)
	var gantry := _rig(ServiceRig.Kind.GANTRY, "OVERHAUL",
		full_cost if missing > 0 else -1, _repair.bind(missing),
		missing > 0 and Run.credits >= full_cost,
		Vector2i(int(round(float(missing) * 10.0 / float(full_hp))), 10))
	gantry.tooltip_text = Widgets.tip("Every point of it, in one go.")

	var refuel_cost := Market.refuel_price(n)
	var bowser := _rig(ServiceRig.Kind.BOWSER, "REFUEL +%d" % Market.REFUEL_UNITS,
		refuel_cost, _refuel, Run.credits >= refuel_cost)
	bowser.tooltip_text = Widgets.tip("A tankful. Fuel is what a jump costs -- see the starchart's reach ring.")

	# THE FAULT POST IS ONLY IN THE BAY WHEN THERE ARE FAULTS.
	#
	# It was one row per distinct malfunction, which was right about the CHOICE
	# and wrong about where to put it: four things wrong with your ship made four
	# service rows and pushed repair and refuelling off a panel that only ever had
	# room for four. A picker moves the list somewhere that can be as long as the
	# list is, and the machine says HOW MANY -- which is the part you need before
	# you decide to open anything.
	var dross_n := Run.dross_count()
	if dross_n > 0:
		var purge_cost := Market.purge_price(n)
		var post := _rig(ServiceRig.Kind.POST, "FAULTS %d" % dross_n,
			purge_cost, _open_purge, Run.credits >= purge_cost)
		post.tooltip_text = Widgets.tip("Choose which one comes out. Each costs the same and clears exactly one.")

	# NO +2 HEAT CAP, AND NO SELLING MATERIALS HERE.
	#
	# Heat capacity is what a thermal module is FOR. Buying two points of it off a
	# counter for credits made the whole thermal ladder optional -- there is no
	# reason to fit a heat sink, or to want one on a shelf, if the yard will sell
	# you the same number without a hardpoint.
	#
	# And selling an exotic was a row here AND a row on the Exchange, which is the
	# deck that exists to answer "what will you give me for what I am carrying".


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
const SCENE_H := 250
## The details slab. WIDE AND SHORT rather than narrow and tall: two columns of
## gauges fit in the band of empty wall above the two berths, where a single
## column could only fit by lying across the ship it was describing.
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
	if _till != null:
		_till.visible = not on_offer.is_empty()
	# THE ROOM KNOWS WHERE IT IS. Same two fields the berth takes: development
	# sets how many lamps hang over the shop, and whoever holds the station tints
	# its plating. A Solari promenade and a Cygnet one are the same hall in two
	# liveries.
	if _shop != null:
		_shop.dev = int(n.development)
		_shop.manufacturer = n.manufacturer
		_shop.queue_redraw()

	if on_offer.is_empty():
		_shelf.add_child(UITheme.body(
			"Shelves bare. Nothing restocks — what was brought here is gone.",
			UITheme.COLD, UITheme.FS_SMALL))
		return

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
	# THE AIR ABOVE IT IS THE ROOM. An expanding spacer first, so the rack is
	# pushed down and STANDS ON THE DECK rather than hanging from the top of the
	# panel. Furniture sits on a floor; only a sign hangs.
	var air := Control.new()
	air.size_flags_vertical = Control.SIZE_EXPAND_FILL
	air.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shelf.add_child(air)

	var shelf := ShelfDisplay.new()
	# ITS OWN SIZE. It filled the whole deck for a while and drew boards all the
	# way down it, which is a warehouse aisle rather than a shop -- see `BOARDS`
	# and `RACK_W`. The empty boards that say "a shop with two things in it" are
	# still there; there are just three of them instead of nine.
	shelf.custom_minimum_size = Vector2(ShelfDisplay.RACK_W,
		ShelfDisplay.rack_height())
	shelf.size_flags_vertical = Control.SIZE_SHRINK_END
	shelf.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	# NOTHING TO CONNECT. Pointing at a part tells you everything about it and
	# dragging it to the till buys it; the shelf has no button on it at all, so
	# the gesture that reads and the gesture that spends cannot be confused.
	_shelf.add_child(shelf)
	# LAID OUT ON `resized`, because the wrap depends on how wide the deck is and
	# the deck has no width until the frame it is built in has been laid out.
	# `stock` refuses to run against a width of zero rather than putting the
	# whole shop on one board.
	shelf.resized.connect(func() -> void: shelf.stock(on_offer))
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
	if _hold_grid == null:
		return
	_hold_grid.refresh()
	var stray := Run.pad.size()
	_hold_head.text = "YOUR HOLD — %d of %d cells%s" % [Run.cargo_used(),
		Run.cargo_slots(),
		"" if stray == 0 else " · %d ON THE PAD" % stray]

	# WHAT THE COUNTER IS PAYING TODAY, said once rather than on every row. A
	# market's rate is a property of the PLACE -- see `Market.bid` and its
	# saturation note -- so it belongs on the counter and not repeated beside
	# each thing standing near it.
	_sell_note.text = "Carry something here to be paid for it. %s" % (
		"This market has taken a lot today; it is paying less than it was."
		if n.trades >= 3 else "Prices are what this place will bear.")
## The recipes this place can support, and the tab that hides when it cannot.


func _refresh_bench(n: MapGen.MapNode) -> void:
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

		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 8)
		head.add_child(UITheme.body(str(r.name).to_upper(),
			UITheme.ICE if can else UITheme.COLD, UITheme.FS_BODY))
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(sp)
		# THE COST IN AMBER WHEN YOU CAN PAY IT, grey when you cannot -- the same
		# read as a BUY button greying out, said in the one place the answer is.
		head.add_child(UITheme.body(Fabricator.cost_line(n, r).to_upper(),
			UITheme.EMBER if can else UITheme.QUOTE, UITheme.FS_SMALL))
		var b := _commit_button("MAKE", _fabricate.bind(r))
		b.disabled = not can
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(b)
		row.add_child(head)

		var what := UITheme.body(str(r.text), UITheme.COLD, UITheme.FS_SMALL)
		what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(what)
		_bench.add_child(Widgets.panel_with(Widgets.pad(row, 8, 6)))

func _repair(amount: int) -> void:
	var n: MapGen.MapNode = Run.node_at()
	var cost := Market.repair_price(n, amount)
	if Run.credits < cost:
		return
	Run.add_credits(-cost)
	Audio.play(&"svc_repair", 0.05)
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
	Audio.play(&"svc_refuel", 0.04)
	Run.log_line("Refuelled.", &"good")

## One malfunction, named, and only one. `clear_dross` removes a single entry,
## so paying once to clear three copies of the same thing is not a thing that
## can happen by accident.
func _purge(which: StringName) -> void:
	var cost := Market.purge_price(Run.node_at())
	if Run.credits < cost or Run.dross_count() <= 0:
		return
	var card := DB.malfunction(which)
	if not Run.clear_dross(which):
		return
	Run.add_credits(-cost)
	Audio.play(&"svc_purge", 0.05)
	Run.log_line("%s cleared." % card.name, &"good")

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
			if Run.hold_full():
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
		_work.add_child(UITheme.body("SIGNED, ELSEWHERE", UITheme.COLD, UITheme.FS_SMALL))
		for job in mine:
			var c: ContractData = job
			var row := UITheme.body("· %s" % c.status_line(), UITheme.QUOTE, UITheme.FS_SMALL)
			row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_work.add_child(row)

	for job in offers:
		var c2: ContractData = job
		if Run.holds_contract(c2):
			continue
		_work.add_child(_offer_row(c2))


## Everything open that this desk cannot pay for. Named rather than listed in
## full: the ledger is the SHIP page's job, and a station is where you act.
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


func _offer_row(c: ContractData) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 7)
	# THE FLAG, beside the name rather than instead of it. On the shelf a part's
	# manufacturer is a mark and the name is redundant, but a contract is written
	# in that manufacturer's own voice -- you are being asked for something BY
	# somebody, and the somebody is half the row.
	var mk: ManufacturerData = DB.manufacturers.get(c.manufacturer)
	if mk != null:
		var fl := ChassisSelect.Banner.new()
		# Scale 1: the banner needs 22 units of height to draw its hem and emblem
		# intact, and a row of text is about that.
		fl.s = 1.0
		fl.custom_minimum_size = Vector2(ChassisSelect.Banner.UNITS_W, 0)
		fl.manufacturer = c.manufacturer
		fl.mark = mk.colour
		fl.field = mk.field
		top.add_child(fl)
	top.add_child(UITheme.body(DB.manufacturer_name(c.manufacturer).to_upper(),
		DB.manufacturer_colour(c.manufacturer), UITheme.FS_SMALL))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	# THE PAY IN EMBER AT HEAD SIZE. It is the reason to read the row, and it was
	# the same eight-pixel grey as the place name under it.
	top.add_child(UITheme.body("%d CR" % c.pay, UITheme.EMBER, UITheme.FS_HEAD))
	box.add_child(top)

	# The ask, in the manufacturer's own voice. The largest thing in the row, because it
	# is the only part a player reads twice.
	var ask := UITheme.body(c.text, UITheme.CHILL, UITheme.FS_SMALL)
	ask.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(ask)

	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 6)
	foot.add_child(UITheme.body(c.status_line(), UITheme.QUOTE, UITheme.FS_SMALL))
	var sp2 := Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(sp2)
	var take := Widgets.button("SIGN", func() -> void:
		Run.take_contract(c)
		_refresh())
	take.tooltip_text = Widgets.tip("Nothing here expires. Sign it and forget it, or never sign it at all.")
	foot.add_child(take)
	box.add_child(foot)
	return Widgets.panel_with(Widgets.pad(box, 6, 4))


func _deliver_row(c: ContractData, label: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var what := UITheme.body("%s · %d cr" % [
		DB.manufacturer_name(c.manufacturer).to_upper(), c.pay],
		DB.manufacturer_colour(c.manufacturer), UITheme.FS_SMALL)
	row.add_child(what)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	row.add_child(Widgets.button(label, func() -> void:
		Run.deliver_contract(c)
		_refresh()))
	return Widgets.panel_with(Widgets.pad(row, 6, 4))

