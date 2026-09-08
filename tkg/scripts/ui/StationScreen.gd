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
var _trade: Label
## What kind of place this is, in its own words. Fills the column under the
## services with something worth reading rather than with nothing.
## The ship in the rail, and the scale that makes it fit. See `_fit_berth`.
var _berth_art: ShipView
var _hull_offer: VBoxContainer
var _services: VBoxContainer
## What is posted at this station and what you can close here. Above the shelf,
## because it is the part of a station that is about WHERE YOU GO NEXT.
var _work: VBoxContainer
var _hold: VBoxContainer
var _bench: VBoxContainer

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
	[&"services", "YARD", "REPAIRS"],
	[&"hold", "EXCHANGE", "YOUR HOLD"],
	[&"work", "HIRING HALL", "WORK POSTED"],
	[&"bench", "LABORATORY", "FABRICATOR"],
]
## How wide the section is. Wide enough for "HIRING HALL" plus a count at
## FS_SMALL without either wrapping, which is what sets it -- not a round number.
const RAIL_W := 156

## WHAT `MapGen` CAN ACTUALLY PRODUCE TODAY: `_roll_axes` wants at most 3, on
## 35% of cities and 60% of capitals, so three is common rather than rare. This
## rail no longer depends on the number -- it builds one flag per berth and steps
## the scale down until they fit -- but it is worth writing down what the number
## is, so the next person to raise it can check the arithmetic in `_flag_scale`
## rather than discover it on a screenshot.
##
## MEASURED, at FLAG_GAP: 3 fit at scale 3 (131 of 156) and 4 at scale 2 (125).
## Five need scale 1, which is a 13x22 flag and not worth flying.
const MAX_BERTHS := 3
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
## How tall the ship's picture stands in the rail.
##
## MEASURED AGAINST THE CANVAS. `ShipView` composites your build onto a 324x112
## canvas at 1x, and this box was 44 -- so the rail showed a horizontal slice
## through the middle of the ship and cut the masts off the top and the fins off
## the bottom.
##
## 84 RATHER THAN THE FULL 112, because the rail has five deck cells, a flag and
## an UNDOCK button to fit as well, and 112 pushed the button off the bottom of
## the screen. The ship sits centred in its canvas with margin above and below,
## so 84 still shows every row that has anything drawn in it -- what it trims is
## the canvas, not the ship.
##
## THE WIDTH CANNOT BE HONOURED THE SAME WAY and that is worth writing down: 324
## will not go into a 156 rail, and the only ways to make it would be a
## fractional downscale -- which is the one thing this game's art may never do --
## or moving the ship off the rail entirely. So the picture is a true 1x with its
## nose and tail cropped, which is what looking into a berth is actually like.
const BERTH_H := 56
## The count line under each deck name, refreshed with everything else.
var _deck_note: Dictionary = {}

var _pages: Dictionary = {}
var _tabs: Dictionary = {}
var _tab: StringName = &"services"
## Which tabs this station actually has. An unbranded desk posts no work and a
## station with no laboratory builds nothing.
var _tabs_on: Dictionary = {}
## How wide the service column is. A price belongs beside the thing it prices.
const SERVICE_W := 420
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
const HULL_H := 150
## And how wide the window onto it is. A cap, not a measurement: it bounds the
## control's minimum so the row cannot overflow the way it did when a doubled
## 474-wide hull sat beside 420 of services. At 1x the widest hull is 392 -- the
## heavy's full sheet, exhaust pad included -- so the cap keeps a little slack
## and the portrait is centred in it. It was 380 against a 324-wide heavy, which
## would now crop the nose off rather than bound the row.
const HULL_W := 400
## How wide the station's name line is allowed to be before it wraps. Bounded on
## purpose — see the note in _build().
const HEADER_W := 560
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
	for entry in DECKS:
		var id: StringName = entry[0]
		var cell := _deck_cell(id, String(entry[1]), String(entry[2]))
		_tabs[id] = cell
		rail.add_child(cell)
	# The berth is the bottom of the section, and UNDOCK lives in it.
	#
	# It used to sit in the tab row, grouped left, because pinned to the right of
	# an expanding row it was at the mercy of the window width -- on a 960
	# screenshot it came back sliced in half. In a fixed-width rail that failure
	# cannot happen: the column is RAIL_W whatever the window does, so the button
	# can go where it belongs instead of where it is safe.
	var pusher := Control.new()
	pusher.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rail.add_child(pusher)
	rail.add_child(_berth_cell())

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
	body_col.add_child(_header)
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

## Repair, refuel, and the ship they are being done to.
##
## THE HULL EARNS ITS PLACE HERE AND NOWHERE ELSE. It used to sit in a permanent
## rail on the right of every page, which is decoration: you can see your ship on
## the sector screen and the refit page, and at a station it was answering no
## question you had walked in with. Beside the repair prices it answers one — a
## hull with its plating opened up, next to the number it costs to close it. That
## is the only place on this screen where looking at the ship is the point.
func _page_services() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var box := Widgets.section("services")
	_services = VBoxContainer.new()
	_services.add_theme_constant_override("separation", 5)
	box.add_child(_services)
	# A COLUMN, NOT THE WHOLE WIDTH. A service is a line of text and a price, and
	# stretched across 700px the price ends up half a screen from the thing it is
	# the price of. This is the width that keeps them together.
	# THE PANEL IS AS TALL AS THE LIST, not as tall as the page. Five services in
	# a page-height box is four hundred pixels of empty panel, which reads as a
	# screen that failed to load rather than as a short menu.
	# HALF THE PAGE, AND ALL OF ITS HEIGHT. Both columns take an equal share and
	# both fill down to the bottom edge, so the two panels are the same size as
	# each other and the page has no ragged corner. A stretch ratio rather than a
	# pixel width, because the window is resizable and a fixed 420 is only ever
	# correct at one size.
	var wrap := Widgets.panel_with(Widgets.pad(box))
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.size_flags_stretch_ratio = 1.0
	wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(wrap)

	# NO HULL PORTRAIT HERE ANY MORE, because the section rail carries one on
	# every deck. It used to earn its place by being the only ship on the screen;
	# now it would be the second, forty pixels from the first.
	#
	# It also no longer FITS. `crop(HULL_W, HULL_H)` is a hard 400-wide minimum
	# and the comment above it records why it cannot simply shrink: at 1x the
	# widest hull is 392, so any narrower window clips a heavy's nose or tail.
	# 420 of services plus 400 of hull needed 820 and the rail leaves 780, so the
	# choice was a clipped ship, a squeezed service column, or no second ship.
	# The rail already answers the question this panel was asking.
	# --- WHAT THE YARD HAS ON THE BLOCKS, and nothing else.
	#
	# This column used to be YOUR HULL: the hull and heat gauges, and the place
	# blurb under them. Both gauges are in the top bar on every screen in the
	# game, so restating them here was the same two numbers twice on one page --
	# and the blurb describes the SYSTEM, not the yard, so it has gone up to the
	# facts line with the rest of what is true about where you are standing.
	#
	# What is left is the one thing you can only find out here.
	var ship := Widgets.section("on the blocks")

	# Hulls used to be sold on the Promenade, on the shelf with the parts, because
	# that was the only page with a shop on it. A hull is not a part -- it is the
	# thing parts are bolted to -- and it belongs on the deck that deals in whole
	# ships, beside the prices for putting one back together.
	#
	# NOT EVERY YARD HAS ONE. The block says so in a line rather than leaving the
	# panel blank: an empty half-page reads as a screen that failed to load, and
	# "no hull here" is a real answer to the question you came to this deck with.
	_hull_offer = VBoxContainer.new()
	_hull_offer.add_theme_constant_override("separation", 3)
	ship.add_child(_hull_offer)

	var sw := Widgets.panel_with(Widgets.pad(ship))
	sw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sw.size_flags_stretch_ratio = 1.0
	sw.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(sw)
	return row


## A label, a gauge and a figure, on the row height everything else uses.
func _page_work() -> Control:
	var box := Widgets.section("work")
	_work = VBoxContainer.new()
	_work.add_theme_constant_override("separation", 5)
	var sc := Widgets.scroller(_work, 90)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(sc)
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
## Card art is 93x60 in CardView's window and the inspect view is an exact 2x of
## it. Same number here, for the same reason: those are the only two scales this
## art has, and anything between them lands the frame on half-pixels.
const ART_K := 2
## How tall a row in the list beside it stands. The module sprite is the tallest
## thing in it -- a BULK part is 31 art pixels -- plus a little air.
const SHELF_ROW_H := 38

## WHAT IS OPEN ON THE SHELF: an index into `n.shop`.
##
## AN INDEX RATHER THAN THE ModuleData, because the shop list is rebuilt from the
## node on every refresh and a reference would point at the copy from the last
## one.
var _pick: int = 0
var _shelf: VBoxContainer


func _page_stock() -> Control:
	# NO SECTION HEADING AT THE TOP. "STOCK" over a rule, above a part that
	# already names itself in 16px, was a title for a page with one thing on it
	# -- and it cost thirty pixels off the top of the only band that is short of
	# them. The word moved down to the list it actually labels.
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	# A COLUMN, not a row. The deck reads in two bands now: what you are looking
	# at across the top, and everything else you could look at along the bottom.
	# See `mocks 06 · Cards Underneath`, with its two halves swapped -- the part
	# on the left, the cards it grants on the right, and the shelf given the full
	# width underneath where four prices line up in one glance.
	_shelf = VBoxContainer.new()
	_shelf.add_theme_constant_override("separation", 8)
	_shelf.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_shelf)
	return Widgets.panel_with(Widgets.pad(box))


## The hold, with a buyer standing in front of it.
func _page_hold() -> Control:
	var box := Widgets.section("your hold")
	_hold = VBoxContainer.new()
	_hold.add_theme_constant_override("separation", 6)
	var sc := Widgets.scroller(_hold, 90)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(sc)
	return Widgets.panel_with(Widgets.pad(box))


func _page_bench() -> Control:
	var box := Widgets.section("fabricator")
	_bench = VBoxContainer.new()
	_bench.add_theme_constant_override("separation", 5)
	box.add_child(_bench)
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
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func() -> void: _show_tab(id))

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 9
	box.offset_top = 6
	box.offset_right = -7
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


## The bottom of the section: your own berth, your ship in it, and the way out.
func _berth_cell() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	# YOUR SHIP, not YOUR BERTH. The berth is the parking space; what you came to
	# look at is the thing parked in it -- and now that the picture below carries
	# every part you have bolted on, the label was naming the wrong half.
	box.add_child(UITheme.body("YOUR SHIP", UITheme.COLD, UITheme.FS_SMALL))

	# A LIVE ShipView, not the hull's bare sprite.
	#
	# The sprite is the frame as it left the yard. This is the one picture of
	# your ship on the station screen, and you spend the whole screen changing
	# what is bolted to it -- so a picture that could not show a single fitted
	# part was showing you somebody else's ship. A ShipView with no `_fixed` and
	# no peer follows YOUR build and repaints on ship_changed, so buying
	# something on the Promenade and fitting it is visible from here.
	#
	# magnify then crop, in that order: magnify re-fits the width to whatever the
	# composited canvas turns out to be, and crop then holds it to the rail. See
	# ShipView.magnify, whose own note records this pair.
	# FITTED TO THE BOX, which means a fractional scale, which this game normally
	# forbids. It is a deliberate exception and the alternative was worse.
	#
	# ShipView composites onto a 324x112 canvas and draws at whole multiples only,
	# so its smallest size is 1x -- and 324 will not go into the 134 the rail
	# leaves. At 1x the cell showed a horizontal slice through the ship's middle
	# with the nose and tail cut off, which is not a picture of your ship.
	#
	# So the view is built at its full canvas size and the CONTROL is halved. A
	# half is the one fraction that is clean on pixel art -- see BERTH_K -- and
	# this is a thumbnail in a rail, not art you read. The rule it bends exists to
	# stop the game's ART being resampled; nothing here is resampled twice or
	# shipped as an asset.
	_berth_art = ShipView.new()
	_berth_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The WRAPPER clips, not the view: a view that clips itself would cut the
	# canvas before the scale is applied.
	_berth_art.self_clip = false
	var berth_box := Control.new()
	berth_box.custom_minimum_size = Vector2(RAIL_W - 22, BERTH_H)
	berth_box.clip_contents = true
	berth_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	berth_box.add_child(_berth_art)
	box.add_child(berth_box)
	# Re-placed whenever the ship changes: the scale is fixed but the canvas is
	# not, and a hull swap moves where the centre of it is.
	Sig.ship_changed.connect(_fit_berth)
	_fit_berth()

	var wrap := Widgets.panel_with(Widgets.pad(box, 6, 5))
	var out := Widgets.button("UNDOCK", func() -> void: Router.show_sector())
	out.custom_minimum_size = Vector2(RAIL_W, 20)
	# THE ONE THING ON THE RAIL THAT LEAVES, and the only ember on it. Every deck
	# cell is somewhere you go and come back from; this is the door. It wears the
	# same ink BUY does on the shelf, because both are the moment you commit.
	for st in ["normal", "hover", "pressed"]:
		out.add_theme_stylebox_override(st,
			UITheme.flat(UITheme.PANEL2 if st == "hover" else Color("#0a0f17"),
				UITheme.EMBER, 0, 4, 8))
	out.add_theme_color_override("font_color", UITheme.EMBER)
	out.add_theme_color_override("font_hover_color", UITheme.HOT)
	out.add_theme_color_override("font_pressed_color", UITheme.HOT)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.add_child(wrap)
	col.add_child(out)
	return col


## Place the berth's ship, halved.
##
## EXACTLY 0.5, not a ratio worked out from the box. A half is the one fraction
## that is clean for pixel art: every 2x2 block becomes one pixel, uniformly,
## with nothing dropped unevenly the way 0.41 would drop it. Fitting to the box
## instead gave whatever number the canvas happened to make and a different one
## per hull.
##
## THE CANVAS OVERFLOWS AND THAT IS FINE. 324 halves to 162 against the 134 the
## rail leaves -- but the canvas is mostly margin, and the SHIP inside it is
## about 168 at 1x and so 84 here. What the crop takes is empty canvas on either
## side; the ship sits whole in the middle of it.
const BERTH_K := 0.5

func _fit_berth() -> void:
	if _berth_art == null or not is_instance_valid(_berth_art):
		return
	# Read off the view's own canvas rather than from a constant: `_w` is the
	# procedural 240 until a sprite is composited and whatever the sprite is
	# after, so a number written here would be right for one hull and wrong for
	# the next.
	var cw := float(_berth_art._w)
	var ch := float(_berth_art._h)
	if cw <= 0.0 or ch <= 0.0:
		return
	_berth_art.crop(int(cw), int(ch))
	_berth_art.scale = Vector2(BERTH_K, BERTH_K)
	_berth_art.position = Vector2((float(RAIL_W - 22) - cw * BERTH_K) * 0.5,
		(float(BERTH_H) - ch * BERTH_K) * 0.5).round()


func _show_tab(id: StringName) -> void:
	if not _pages.has(id) or not _tabs_on.get(id, true):
		return
	_tab = id
	for key in _pages:
		(_pages[key] as Control).visible = key == id
	for key in _tabs:
		var b: Button = _tabs[key]
		var on: bool = key == id
		b.disabled = on
		# The deck's own labels carry the colour, not the button's font, because
		# a Button's font colour cannot reach Labels parented inside it.
		var title := b.get_meta(&"title", null) as Label
		if on:
			b.add_theme_stylebox_override("normal", UITheme.bevel(Color("#4a2a0c"), 3, 5))
			b.add_theme_stylebox_override("disabled", UITheme.bevel(Color("#4a2a0c"), 3, 5))
			if title != null:
				title.add_theme_color_override("font_color", UITheme.HOT)
			if _deck_note.has(key):
				(_deck_note[key] as Label).add_theme_color_override(
					"font_color", UITheme.EMBER)
		else:
			b.remove_theme_stylebox_override("normal")
			b.remove_theme_stylebox_override("disabled")
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
func _service(label: String, price_text: String, action: Callable) -> Button:
	var b := Widgets.button("  " + label, action)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, ROW_H)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var p := UITheme.body(price_text, UITheme.ICE, UITheme.FS_SMALL)
	p.name = "Price"
	p.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	p.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	p.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.offset_left = -120
	p.offset_right = -10
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(p)
	return b


## Grey the price with the row. A disabled Button dims its own text through the
## theme; a child Label is not its text and stays bright, which reads as a price
## you can pay on a row you cannot press.
func _set_service_enabled(b: Button, on: bool) -> void:
	b.disabled = not on
	var p := b.get_node_or_null("Price") as Label
	if p != null:
		p.modulate = Color(1, 1, 1, 1.0 if on else 0.30)


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



## Repair, fuel, coolant, and one row per material you are carrying.


func _refresh_services(n: MapGen.MapNode) -> void:
	# --- the hull on the blocks, if this yard has one.
	Widgets.clear(_hull_offer)
	var h: HullData = n.shop_hull
	var up := h != null and not n.taken.has(MapGen.OPTION_SHOP_HULL)
	if not up:
		_hull_offer.add_child(UITheme.body(
			"Nothing on the blocks. This yard does repairs.",
			UITheme.COLD, UITheme.FS_SMALL))
	if up:
		_hull_offer.add_child(_hull_art(h))
		_hull_offer.add_child(UITheme.body(h.name.to_upper(), UITheme.HOT,
			UITheme.FS_HEAD))
		_hull_offer.add_child(UITheme.body("%s CHASSIS · %s TIER · HAND %d" % [
			HullData.weight_name(h.weight).to_upper(), h.tier_letter(),
			h.hand_size], UITheme.COLD, UITheme.FS_SMALL))
		# THE SEVEN GAUGES, in the same block the refit screen draws them in.
		#
		# It used to print "47 HULL · 7 NRG · HAND 5 · HEAT 16/2", which is four
		# raw fields in the units the code stores them in -- and the number a
		# player compares a chassis on is the PIP, because that is what every
		# skill check and set bonus is counted in. A hull you are deciding whether
		# to buy has to be readable against the one you are standing in, and the
		# one you are standing in is drawn as cells on the ship tab.
		#
		# BARE, with nothing fitted: this is the frame, not the frame plus your
		# parts. See `RunState.hull_attributes`.
		var attrs := AttrBlock.new()
		attrs.setup(Run.hull_attributes(h), DB.manufacturer_colour(h.manufacturer))
		_hull_offer.add_child(attrs)
		for pid in h.perks():
			var pk := UITheme.body(DB.perk_text(pid), UITheme.EMBER,
				UITheme.FS_SMALL)
			pk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			pk.custom_minimum_size = Vector2(HULL_W, 0)
			_hull_offer.add_child(pk)
		var pay := HBoxContainer.new()
		pay.add_theme_constant_override("separation", 11)
		var price := Market.hull_price(n, h)
		var cr := UITheme.body("%d CR" % price, UITheme.EMBER, UITheme.FS_HEAD)
		cr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pay.add_child(cr)
		var take := Widgets.button("TAKE IT", _on_action.bind("take_hull", h))
		take.disabled = Run.credits < price
		pay.add_child(take)
		_hull_offer.add_child(pay)

	Widgets.clear(_services)
	var missing := Run.max_hp() - Run.hp

	var eight := mini(8, maxi(1, missing))
	var eight_cost := Market.repair_price(n, eight)
	var repair := _service("HULL REPAIR +%d" % eight, "%d cr" % eight_cost,
		_repair.bind(eight))
	_set_service_enabled(repair, missing > 0 and Run.credits >= eight_cost)
	repair.tooltip_text = Widgets.tip("%.1f credits a point here. Work is dear on the frontier and cheap in a capital." % Market.repair_rate(n))
	_services.add_child(repair)

	var full_cost := Market.repair_price(n, missing)
	var full := _service("FULL HULL REPAIR", "%d cr" % full_cost, _repair.bind(missing))
	_set_service_enabled(full, missing > 0 and Run.credits >= full_cost)
	_services.add_child(full)

	var refuel_cost := Market.refuel_price(n)
	var refuel := _service("REFUEL +%d" % Market.REFUEL_UNITS,
		"%d cr" % refuel_cost, _refuel)
	_set_service_enabled(refuel, Run.credits >= refuel_cost)
	_services.add_child(refuel)

	# SYSTEM REPAIR: one row per malfunction you are actually carrying, and each
	# one takes out that one and nothing else.
	#
	# It was a single PURGE button that removed the mildest, which made the
	# service worse the more it mattered — the thing you wanted gone was the
	# Slag welded into the rack, and what you paid for was a Hairline Crack. A
	# choice is the whole value here, and the rows already exist as a pattern,
	# so it needs no picker and no modal.
	var purge_cost := Market.purge_price(n)
	var seen: Dictionary = {}
	for id in Run.dross:
		if seen.has(id):
			continue
		seen[id] = true
		var card := DB.malfunction(id)
		var many := Run.dross.count(id)
		var b := _service("SYSTEM REPAIR — %s%s" % [card.name.to_upper(),
			"" if many < 2 else " (%d)" % many], "%d cr" % purge_cost,
			_purge.bind(id))
		b.tooltip_text = Widgets.tip("%s
Removes one. %s"
			% [card.describe(), "You are carrying %d." % many if many > 1 else "The only one aboard."])
		_set_service_enabled(b, Run.credits >= purge_cost)
		_services.add_child(b)

	var coolant_cost := Market.coolant_price(n)
	var coolant := _service("+2 HEAT CAP", "%d cr" % coolant_cost, _coolant)
	_set_service_enabled(coolant, Run.credits >= coolant_cost)
	_services.add_child(coolant)

	# One row per material you are carrying, rather than the single hardcoded
	# exotic row this replaced. Materials are worth more where there is somebody
	# who can use them, so a capital pays half again what an outpost does — which
	# makes hauling an organ inward a trade, and not just inventory.
	for stock in Run.material_stock():
		var mid: StringName = stock.id
		var paid := Market.material_price(n, mid)
		var b := _service("SELL 1 %s" % str(stock.name).to_upper(),
			"+%d cr" % paid, _sell_material.bind(mid))
		b.tooltip_text = Widgets.tip("You have %d. Laboratories pay for these; mining outposts use them as ballast." % int(stock.count))
		_services.add_child(b)


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


## THE HULL, WHICH HAS NO CARDS. A frame is the one thing on the shelf that puts
## nothing in your deck, so the cards column has nothing to show and the picture
## of the ship takes that job instead.
##
## SIZED TO A HULL rather than to the card window. It used to reserve 186x120 --
## `Z_ART` doubled -- which is the shape of a card illustration and not of a
## ship: hull sprites run about 392x140, so the box held sixty pixels of ship
## above and below sixty pixels of nothing, and the tiles underneath were pushed
## off the bottom of the panel.
const HULL_ART_H := 72
## As wide as the Yard's right-hand column has to spare. The shelf's own column
## sized this before hulls moved here, which was a coincidence rather than a
## reason.
const HULL_ART_W := 300

func _hull_art(h: HullData) -> Control:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel",
		UITheme.flat(Color("#0a0f17"), UITheme.EMBER, 0, 4, 4))
	var art := TextureRect.new()
	art.texture = h.sprite
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.custom_minimum_size = Vector2(HULL_ART_W, HULL_ART_H)
	frame.add_child(art)
	return frame


## One part on the shelf, as a line in the list along the bottom.
##
## STILL A BUTTON, because clicking it is how you open a part -- but styled as a
## row rather than as a box. The chrome is what made the tiles read as buttons:
## four bordered boxes under BUY, all the same weight, so the one that spends
## your credits looked like one of four. This has no border at rest and lights
## its whole line under the pointer, which is what a list does.
const ROW_TALL := 34
## The inset from the row's edge to its contents. The thumbnail is sized against
## ROW_TALL MINUS TWICE THIS, and getting that wrong is what let a 2x2 part hang
## out of its own box: the picture asked for `ROW_TALL - 6` = 26 of height inside
## a row that only had 20 to give, the HBox took its minimum from the picture,
## and the whole row grew past the button drawn around it.
const ROW_PAD := 6


func _shelf_row(thing: Variant, price: int, pick: int, open: bool) -> Button:
	var b := Widgets.button("", func() -> void:
		_pick = pick
		_refresh_stock(Run.node_at()))
	b.custom_minimum_size = Vector2(0, ROW_TALL)
	# CLIPPED, as a backstop rather than as the plan. The arithmetic above should
	# keep every picture inside the box; this makes a future sprite of some shape
	# nobody thought of lose its edge instead of drawing over the row above it.
	b.clip_contents = true
	# EACH ONE IN ITS OWN BOX. Bare lines with nothing round them ran together --
	# four parts reading as one block of text with prices in it, and no edge to
	# say where one thing stopped and the next began. A hairline and a gap is
	# enough; this is still a list and not the wall of tiles it was before.
	#
	# THE OPEN ONE IS LIT, and it is in the list rather than removed from it.
	# Pulling it out made the list shorter every time you clicked, so rows moved
	# under the cursor and the thing you had just chosen was the one thing you
	# could no longer see in context. Lit, the list never changes length and the
	# selection has somewhere to be.
	b.add_theme_stylebox_override("normal",
		UITheme.flat(UITheme.PANEL2 if open else Color("#0b1017"),
			UITheme.EMBER if open else UITheme.LINE, 0, 0, 0))
	b.add_theme_stylebox_override("hover",
		UITheme.flat(UITheme.PANEL2, UITheme.EMBER if open else UITheme.COLD,
			0, 0, 0))
	b.add_theme_stylebox_override("pressed",
		UITheme.flat(UITheme.PANEL2, UITheme.EMBER, 0, 0, 0))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT,
		Control.PRESET_MODE_MINSIZE, ROW_PAD)
	# EVERY CHILD IGNORES THE MOUSE. They are laid out inside a Button, and a
	# Label that answers the pointer eats the click meant for the row under it --
	# the same trap the deck cells in the rail hit.
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)

	var h := thing as HullData
	var m := thing as ModuleData
	var thumb := TextureRect.new()
	thumb.texture = h.sprite if h != null else (m.sprite if m != null else null)
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	thumb.custom_minimum_size = Vector2(46, ROW_TALL - ROW_PAD * 2)
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(thumb)

	# Graded here too, so the shelf reads as a shelf: four names in four inks and
	# you know which one is worth opening before you open it.
	var nm := UITheme.body((h.name if h != null else m.name).to_upper(),
		UITheme.ICE if h != null else ModuleData.rarity_ink(m.rarity),
		UITheme.FS_SMALL)
	nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(nm)

	# THE FLAG, NOT THE NAME. Every row printed "KORVAN HEAVY WORKS" in Korvan's
	# orange next to a name in its grade's colour, so a shelf of four parts was
	# eight coloured words and the eye had nowhere to rest. The flag says the same
	# thing in thirteen pixels and says it as a MARK, which is what allegiance
	# should be -- the name is already on the part you have open.
	#
	# Leftmost, so the flags line up in a column: whose yard stocked what is a
	# thing you scan down, not a thing you read across.
	var flag: Control = null
	if h == null:
		var mk: ManufacturerData = DB.manufacturers.get(m.manufacturer)
		if mk != null:
			var fl := ChassisSelect.Banner.new()
			# SCALE 1. The banner's emblem is centred 11 units down and its hem is
			# cut 6 up from the bottom, so the whole flag needs 22 units of height
			# to draw intact -- which at any larger scale is taller than a list
			# row has, and would be a flag with its emblem below the cut.
			fl.s = 1.0
			fl.custom_minimum_size = Vector2(ChassisSelect.Banner.UNITS_W, 0)
			fl.manufacturer = m.manufacturer
			fl.mark = mk.colour
			fl.field = mk.field
			flag = fl
	if flag == null:
		# A hull, or a part nobody made. The column still has to exist or the
		# names below it would not line up with the names above.
		flag = Control.new()
		flag.custom_minimum_size = Vector2(ChassisSelect.Banner.UNITS_W, 0)
	flag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(flag)

	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gap)

	var cr := UITheme.body("%d CR" % price, UITheme.EMBER, UITheme.FS_SMALL)
	cr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(cr)
	# The flag leads the row. Built last because it needs the part in hand, moved
	# first because a column of marks is only scannable if it is a column.
	row.move_child(flag, 0)
	return b


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

	if on_offer.is_empty():
		_shelf.add_child(UITheme.body(
			"Shelves bare. Nothing restocks — what was brought here is gone.",
			UITheme.COLD, UITheme.FS_SMALL))
		return

	# THE OPEN PART SURVIVES A PURCHASE, or falls to whatever is still here.
	# Buying the thing you are looking at removes it from the offer, and a
	# selection left pointing at it would open an empty panel on the one screen
	# where something just happened.
	var found := -1
	for i in on_offer.size():
		if int(on_offer[i].pick) == _pick:
			found = i
			break
	if found < 0:
		found = 0
		_pick = int(on_offer[0].pick)
	var open: Dictionary = on_offer[found]

	# --- TOP BAND: what it IS on the left, what it puts in your deck on the right.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	# THE TOP BAND TAKES THE SLACK, so the list underneath is pinned to the bottom
	# of the panel and never moves.
	#
	# It used to be as tall as whatever was open, and the open part is not a fixed
	# height: a 2x2 plate is 88 where a 2x1 is 44, and a part with two affixes and
	# a flavour line is forty pixels taller than one with neither. So clicking
	# down the shelf jogged the whole list up and down under the cursor -- and the
	# list is the thing you are aiming at.
	top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_shelf.add_child(top)

	# SHRINK_BEGIN, so PICK_W is the width and not merely the floor. A hull grants
	# no cards, so nothing sits beside this column -- and left to expand it took
	# the whole band, which pushed the shelf off the bottom of the panel.
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	left.custom_minimum_size = Vector2(PICK_W, 0)
	left.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	top.add_child(left)

	var mod := open.thing as ModuleData
	var plate := HBoxContainer.new()
	plate.add_theme_constant_override("separation", 10)
	plate.add_child(_hold_plate(mod))
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
	# in. It was HOT for everything, which is the colour of "this is the heading"
	# -- true and useless, because on a shelf the question is not what the part is
	# called but how good it is, and that was a word in grey somewhere else.
	var title := UITheme.body(mod.name.to_upper(),
		ModuleData.rarity_ink(mod.rarity), UITheme.FS_HEAD)
	# ONE LINE. It wrapped, and a two-line name pushed the manufacturer, the
	# affixes, the flavour and the price down by twenty pixels on exactly the
	# parts with the longest names -- so the panel changed height as you clicked
	# along the shelf. The column is sized for the longest name in the game
	# (see PICK_W); `clip_text` is the guard rather than the plan, so a name
	# longer than any that exists today loses its tail instead of reflowing the
	# screen.
	title.clip_text = true
	title.custom_minimum_size = Vector2(PICK_W, 0)
	left.add_child(title)

	# THE MANUFACTURER IN ITS OWN COLOUR, and the slot beside it in grey. Two
	# labels rather than one string, because they are two different kinds of fact:
	# who built it is an allegiance -- the thing set bonuses are counted in and
	# the thing the flags at the top of the rail are flying -- and the slot is a
	# spec. `manufacturer_colour` answers for the unbranded too, in a grey of its
	# own, so there is no branch here.
	var mrow := HBoxContainer.new()
	mrow.add_theme_constant_override("separation", 5)
	mrow.add_child(UITheme.body(
		DB.manufacturer_name(mod.manufacturer).to_upper(),
		DB.manufacturer_colour(mod.manufacturer), UITheme.FS_SMALL))
	mrow.add_child(UITheme.body("· %s" % ModuleData.slot_name(mod.slot).to_upper(),
		UITheme.COLD, UITheme.FS_SMALL))
	left.add_child(mrow)
	for a in mod.affixes:
		# THE GAUGE IN FULL. `a.text` is the abbreviated form, written for a
		# readout the width of a card; this column has room for the word.
		var af := UITheme.body("%s — %s" % [a.name.to_upper(),
				a.gauge_text(true)],
			UITheme.EMBER, UITheme.FS_SMALL)
		af.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		af.custom_minimum_size = Vector2(PICK_W, 0)
		left.add_child(af)
	# WHAT THE THING IS LIKE, under what it does. In QUOTE, which is the ink this
	# game reserves for writing that is not a rule -- so it reads as the catalogue
	# talking rather than as another number you have to weigh.
	if mod.flavour != "":
		var fl := UITheme.body(mod.flavour, UITheme.QUOTE, UITheme.FS_SMALL)
		fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fl.custom_minimum_size = Vector2(PICK_W, 0)
		left.add_child(fl)

	# NO EXPANDING SPACER ABOVE THE PRICE. It pushed the price to the bottom of
	# the column, which was right when the column was the full height of the
	# panel -- with the shelf underneath it now, all that spacer did was inflate
	# the top band until the tiles fell off the bottom edge.
	var pay := HBoxContainer.new()
	pay.add_theme_constant_override("separation", 11)
	left.add_child(pay)
	var price := UITheme.body("%d CR" % int(open.price), UITheme.EMBER,
		UITheme.FS_HEAD)
	price.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pay.add_child(price)
	var buy := Widgets.button("BUY", _on_action.bind("buy", open.thing))
	# CENTRED ON THE PRICE. A Button fills its row by default and the price beside
	# it is FS_HEAD, so the button sat tall against a number whose middle was
	# several pixels below its own -- the two things that belong on one line
	# reading as one above the other.
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buy.disabled = Run.credits < int(open.price)
	pay.add_child(buy)

	# --- WHAT IT PUTS IN YOUR DECK, as the cards themselves.
	#
	# THE REAL CARD FACE, not the illustration lifted out of it. The panel used
	# to crop `Z_ART` and print the rules line underneath in grey, which is a
	# card taken apart and laid out again worse -- the face already carries the
	# art, the name, the cost and the text, drawn by the one class that knows how
	# a card in this game looks. A part is bought FOR its cards; showing you the
	# cards you are buying is the whole of the panel's job.
	if true:
		var deck := VBoxContainer.new()
		deck.add_theme_constant_override("separation", 5)
		top.add_child(deck)
		# ADDS TO, not IN. "In your deck" says these cards are already there; the
		# whole point of the panel is that they are not yet, and buying the part
		# is what puts them in.
		deck.add_child(UITheme.body("ADDS TO YOUR DECK", UITheme.COLD,
			UITheme.FS_SMALL))
		var fan := HBoxContainer.new()
		fan.add_theme_constant_override("separation", 8)
		deck.add_child(fan)
		# ONE FACE PER COPY. `resolved_cards` hands back an entry for every copy
		# the Grant Count Law awards, and this used to fold them into one face
		# with an "x2" under it -- which is a receipt for two cards rather than a
		# picture of them. Two of the same card in a deck is two cards, and the
		# hand you will be holding has both in it.
		for c in mod.resolved_cards():
			var v := CardView.new()
			# `can_play` TRUE, on a shelf where nothing can be played. The flag
			# greys the face, and it means "you cannot afford this right now" in
			# a hand -- said about a card in a shop window it reads as the card
			# being broken. What you cannot afford here is the PART, and the
			# price says so.
			v.setup(c, true, 1)
			# THE POINTER REACHES IT, and that is the whole of the keyword help.
			# `CardView._make_custom_tooltip` already answers with
			# `Widgets.card_readout`, which lists every term this card can
			# explain -- Salvo, Brace, Charge, Vent -- straight out of
			# `CardData.keywords()`. Set to IGNORE it could not be hovered, so a
			# glossary that already existed was unreachable on the one screen
			# where you are deciding whether you understand the card.
			#
			# `tooltip_text` has to be non-empty or Godot never asks for the
			# custom panel; the string itself is never drawn.
			v.mouse_filter = Control.MOUSE_FILTER_STOP
			v.tooltip_text = " "
			fan.add_child(v)

	# --- BOTTOM BAND: everything else on the shelf, across the full width.
	#
	# A RULE ABOVE IT, because this is a change of subject rather than another
	# column of the same one -- above the line is the thing you are considering,
	# below it is what else there is.
	_shelf.add_child(UITheme.hsep())
	# STOCK, not THE REST OF THE SHELF. The open part is in this list too now, so
	# "the rest" stopped being true -- and a list you can see your own selection
	# in is a list you can navigate without losing your place in it.
	_shelf.add_child(UITheme.body("STOCK", UITheme.COLD, UITheme.FS_SMALL))
	# A LIST, one part to a line, across the full width.
	#
	# It was a row of tiles and they read as a second set of buttons competing
	# with BUY -- four boxed things of equal weight under the one boxed thing
	# that actually spends your money. A list is a list: names down the left,
	# prices down the right, and the only column you have to scan to compare four
	# parts is the one with the numbers in it.
	var rest := VBoxContainer.new()
	rest.add_theme_constant_override("separation", 5)
	_shelf.add_child(rest)
	for row in on_offer:
		rest.add_child(_shelf_row(row.thing, int(row.price), int(row.pick),
			int(row.pick) == _pick))


## What you brought, priced at what this place will pay for it.


func _refresh_hold(n: MapGen.MapNode) -> void:
	Widgets.clear(_hold)
	# One deck build for the whole list, handed to every row — see Widgets.module_row.
	var deck := DeckBuilder.build().size()
	if Run.cargo.is_empty():
		_hold.add_child(UITheme.body("Hold empty.", UITheme.COLD, UITheme.FS_SMALL))
	for m in Run.cargo:
		# The hold holds two kinds of thing. The SHOP above still sells modules
		# only, so it keeps `module_row` and its stricter type.
		_hold.add_child(Widgets.item_row(m, Widgets.ModuleContext.HOLD,
			Market.bid(n, m), _on_action, "", deck))


## The recipes this place can support, and the tab that hides when it cannot.


func _refresh_bench(n: MapGen.MapNode) -> void:
	Widgets.clear(_bench)
	var recipes := Fabricator.available(n)
	# The TAB goes, not the page. A page that hides itself leaves a lit tab
	# pointing at nothing, and `_show_tab` would happily select it.
	_enable_tab(&"bench", not recipes.is_empty())
	for r in recipes:
		var b := Widgets.button("%s · %s" % [str(r.name), Fabricator.cost_line(n, r)],
			_fabricate.bind(r))
		b.disabled = not Fabricator.can_make(n, r)
		b.tooltip_text = Widgets.tip(str(r.text))
		_bench.add_child(b)

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

func _coolant() -> void:
	var cost := Market.coolant_price(Run.node_at())
	if Run.credits < cost:
		return
	Run.add_credits(-cost)
	# Through the mutator, so the gauge is told. Writing the field directly left
	# the only signal in this function firing before the change it was announcing.
	Run.add_heat_cap(2)
	Audio.play(&"svc_coolant", 0.04)
	Run.log_line("Coolant upgraded. Heat cap +2 to %d." % Run.heat_cap(), &"good")

func _sell_material(id: StringName) -> void:
	var n: MapGen.MapNode = Run.node_at()
	if not Run.spend_material(id, 1):
		return
	var paid := Market.material_price(n, id)
	Run.add_credits(paid)
	Run.log_line("Sold 1 %s for %d credits."
		% [str(MaterialTable.by_id(id).get("name", id)).to_lower(), paid], &"good")

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
			# behind" — the module was gone from both places and paid for.
			if Run.hold_full():
				Run.log_line("The hold is full. Nowhere to put it.", &"them")
				return
			# One shelf, four buyers. ASK, and pay only if you won — a purchase
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
			var price2 := Market.hull_price(n, h)
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
			Run.transfer_to_hull(h)
		"install":
			Audio.act(&"module_install")
			Run.install_module(thing as ModuleData)
		"scrap":
			Audio.act(&"module_scrap")
			Run.scrap_module(thing as ModuleData)
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
	top.add_theme_constant_override("separation", 6)
	top.add_child(UITheme.body(DB.manufacturer_name(c.manufacturer).to_upper(),
		DB.manufacturer_colour(c.manufacturer), UITheme.FS_SMALL))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	top.add_child(UITheme.body("%d cr" % c.pay, UITheme.ICE, UITheme.FS_SMALL))
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

