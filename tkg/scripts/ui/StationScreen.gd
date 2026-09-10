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
## The fault picker, while it is open. Null the rest of the time.
var _purge_prompt: Control
## The deal, in the shipyard's heading row: the sum in words, the number that
## leaves your account, and the button that does it.
var _yard_sum: Label
var _yard_price: Label
var _yard_take: Button
var _trade: Label
## What kind of place this is, in its own words. Fills the column under the
## services with something worth reading rather than with nothing.
## The ship in the rail, and the scale that makes it fit. See `_fit_berth`.
var _berth_art: ShipView
## The name over the rail's picture, refreshed when the ship changes.
var _berth_name: Label
var _hull_offer: VBoxContainer
## The service list, a GRID of two so seven short rows are four lines.
var _services: GridContainer
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
## How deep the berth's picture is.
##
## 76, up from 56. The binding constraint on how big your ship can be drawn here
## is the rail's WIDTH -- a heavy is 296 art pixels of ink and a half of that is
## 148 -- and height was the one that ran out first at 56, dropping mediums to a
## quarter for want of three rows. Vertical is the cheap direction in a rail with
## five decks and a button in it.
const BERTH_H := 76

## How much of the rail's width the picture may use.
##
## The panel's own padding used to take 22 of 156 and the picture got 134, which
## is four pixels short of every heavy in the game at a half. Two pixels of pad
## instead of six buys those four and then some: 148 is exactly a heavy, and the
## border still reads as a border.
const BERTH_W := RAIL_W - 8
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


func _page_services() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)

	# THE SAME HEADING TREATMENT THE SHIPYARD GETS, and at the same weight.
	#
	# `Widgets.section` sets a title at FS_SMALL over an `hsep` with six pixels
	# of separation either side -- which is right for a subheading inside a
	# panel and undersized for the two headings that ARE the page. At 16 they
	# stop being captions and start being the names of the things below them,
	# and the six-pixel gaps come out because the rule already separates them.
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	# BANDED AND CENTRED, the same as the shipyard's. A 16px label dropped
	# straight into a VBox sits on its own ascender line, and the two panels then
	# put their headings at two different heights above two identical rules.
	# One band, one alignment, and both read as the same thing.
	box.add_child(_heading("services"))
	box.add_child(UITheme.hsep())
	# TWO COLUMNS. A service is a short label and a price, and across the full
	# 740 the row was nine tenths empty -- seven of them stacked took half the
	# page and pushed the shipyard's gauges off the bottom of it. Paired, the
	# same seven are four rows and the panel is half the height for no loss.
	_services = GridContainer.new()
	_services.columns = 2
	_services.add_theme_constant_override("h_separation", 8)
	_services.add_theme_constant_override("v_separation", 5)
	box.add_child(_services)
	# TIGHT ABOVE THE HEADING. `panel_with` already gives 12 of content margin and
	# `pad` was adding six more on top of it, so SERVICES sat eighteen pixels down
	# from a border it is the first thing inside. Two, and the page gets the
	# difference back where the shipyard needs it.
	# NO SECOND PAD. `panel_with` already gives twelve of content margin all
	# round; the `pad` on top of it was six more, and the two together put the
	# heading eighteen pixels inside a border it is the first thing after.
	col.add_child(_flat_panel(box))

	# SHIPYARD, not ON THE BLOCKS. The berth is a place, and the deck rail names
	# the other four for what they are; this one was named for what is standing
	# in it, which is empty most of the time.
	# THE HEADING ROW CARRIES THE DEAL.
	#
	# The price and the button used to sit at the FOOT of the offer's column,
	# under seven gauges and three perk lines -- which put the one control on the
	# panel wherever the longest column happened to end, and left the bottom
	# third of the page empty underneath it. A price belongs beside the heading
	# of the thing being priced, where it is in the same glance as the word
	# SHIPYARD and cannot move.
	var yardbox := VBoxContainer.new()
	yardbox.add_theme_constant_override("separation", 2)
	var yband := _heading("shipyard")
	var yhead := yband.get_node("Row") as HBoxContainer
	var yspacer := Control.new()
	yspacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yspacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	yhead.add_child(yspacer)
	# THE SUM IN WORDS, then the answer. `168 - 43 TRADE-IN` was arithmetic with
	# no nouns in it: the reader has to work out that 43 is what their own ship
	# is worth and that the difference is what leaves their account. Naming both
	# halves costs one line and removes the puzzle.
	_yard_sum = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	_yard_sum.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_yard_sum.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	yhead.add_child(_yard_sum)
	_yard_price = UITheme.body("", UITheme.EMBER, UITheme.FS_HEAD)
	_yard_price.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	yhead.add_child(_yard_price)
	_yard_take = _commit_button("TAKE IT", func() -> void: pass)
	_yard_take.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	yhead.add_child(_yard_take)
	yardbox.add_child(yband)
	yardbox.add_child(UITheme.hsep())

	_hull_offer = VBoxContainer.new()
	_hull_offer.add_theme_constant_override("separation", 4)
	# THE OFFER TAKES THE PANEL'S SLACK AND CENTRES IN IT. The heading row is
	# pinned to the top and the ship is one band of content -- without this the
	# band sits directly under the rule with a third of a panel of nothing
	# beneath it, which reads as a page that stopped halfway.
	_hull_offer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_hull_offer.alignment = BoxContainer.ALIGNMENT_CENTER
	yardbox.add_child(_hull_offer)
	var yw := _flat_panel(yardbox)
	yw.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(yw)
	return col


## A ship drawn at HALF, the same exception the berth in the rail makes.
##
## `ShipView` draws at whole multiples only, so its smallest is 1x -- and two
## ships at 1x are 648 pixels of a 740-wide page before either has a gauge
## beside it. A half is the one fraction that is clean on pixel art: every 2x2
## block becomes one, uniformly. The wrapper clips; the view must not clip
## itself, or it would cut the canvas before the scale is applied.
## A ship at FULL SIZE, centred on the metal rather than on the sheet.
##
## IT WAS DRAWN AT A HALF and that was the wrong economy. The half exists on the
## rail because a thumbnail there has 134 pixels to live in; this panel has 300
## a side and was spending them on air -- two ships at a half came to 120 across
## in a 300 column, and the modules bolted to yours were five pixels long and
## invisible, which read as a ship with nothing on it.
##
## Ink, not canvas: a 324x112 sheet holds 241x106 of actual hull, so measuring
## the sheet would have said 1x does not fit when it does. See `ShipView.ink_rect`.
func _ship_half(h: HullData, box_w: int, kitted: bool = false) -> Control:
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(box_w, SHIP_BOX_H)
	wrap.clip_contents = true
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := ShipView.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.self_clip = false
	# YOUR SHIP WEARS ITS GUNS; THE ONE ON THE BLOCKS DOES NOT.
	#
	# Both were drawn bare, which made the comparison a lie in one direction: a
	# stripped hull beside a stripped hull says the two ships are equivalent
	# objects, when one of them is a frame you have spent a run building on and
	# the other is a shell. It is also the single fact this page most needs to
	# carry -- everything you own stays yours, and the thing being sold is the
	# frame under it.
	if kitted:
		v.setup_build(ShipBuild.fitted_out(h, Run.installed))
	else:
		v.setup_preview(h, 0, 1)
	wrap.add_child(v)
	var ink := v.ink_rect()
	var mid := Vector2(float(ink.position.x) + float(ink.size.x) * 0.5,
		float(ink.position.y) + float(ink.size.y) * 0.5)
	v.position = (Vector2(float(box_w), float(SHIP_BOX_H)) * 0.5 - mid).round()
	return wrap


## THE SHIP FOR SALE, and every number on it read against the one you fly.
##
## ONE COLUMN, NOT TWO. The yard drew both hulls side by side with a full gauge
## block each -- fourteen bars to answer one question, and the ship on the left
## was the same ship the rail draws at the bottom of every deck, eighty pixels
## away. What a buyer wants is not two readouts to diff by eye; it is the offer,
## and how much better or worse it is. So the comparison moved INTO the block as
## a signed column: `+3` beside a bar says the thing two bars side by side were
## being asked to imply.
##
## Your own ship is not gone from the screen. It is in the rail, where it is on
## the other four decks.
func _offer_column(h: HullData) -> VBoxContainer:
	# THE SHIP BESIDE THE NUMBERS, not above them.
	#
	# Stacked, the hull was centred across 700 pixels over a block of text that
	# starts at the left margin -- so the two did not line up on any edge, and
	# the right half of the panel below the ship was empty. Side by side each
	# takes about half the width and the panel has no dead quarter in it.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var art := _ship_half(h, OFFER_W, false)
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(art)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(col)
	col.add_child(UITheme.body(h.name.to_upper(),
		DB.manufacturer_colour(h.manufacturer), UITheme.FS_HEAD))

	var hand := h.hand_size - Run.hull.hand_size
	col.add_child(UITheme.body("%s · %s TIER · HAND %d%s" % [
		HullData.weight_name(h.weight).to_upper(), h.tier_letter(), h.hand_size,
		"" if hand == 0 else (" (%+d)" % hand)],
		UITheme.COLD, UITheme.FS_SMALL))

	# BOTH SIDES BARE, which is what makes the comparison honest.
	# `transfer_to_hull` carries nothing over by itself -- you move your own kit
	# across on the next screen -- so what a swap actually changes is the FRAME,
	# and the frame is what both of these numbers describe.
	var mine := Run.hull_attributes(Run.hull)
	var theirs := Run.hull_attributes(h)
	for i in mini(theirs.size(), mine.size()):
		theirs[i]["delta"] = int(theirs[i].value) - int(mine[i].value)
	var attrs := AttrBlock.new()
	attrs.setup(theirs, DB.manufacturer_colour(h.manufacturer))
	col.add_child(attrs)

	# AND THE HARDPOINTS, which is the part of a swap that can cost you a fitting:
	# a frame with fewer mounts of a slot is a frame some of your kit has nowhere
	# to go on, and the transfer screen will make you deal with that.
	var mounts := HBoxContainer.new()
	mounts.add_theme_constant_override("separation", 9)
	mounts.add_child(UITheme.body("MOUNTS", UITheme.COLD, UITheme.FS_SMALL))
	for sl in [ModuleData.Slot.WEAPON, ModuleData.Slot.SYSTEM,
			ModuleData.Slot.UTILITY]:
		var d := h.slots_for(sl) - Run.hull.slots_for(sl)
		mounts.add_child(UITheme.body("%s %d%s" % [
			ModuleData.slot_name(sl).to_upper().substr(0, 3), h.slots_for(sl),
			"" if d == 0 else (" (%+d)" % d)],
			UITheme.CHILL if d >= 0 else UITheme.LEAVE, UITheme.FS_SMALL))
	col.add_child(mounts)

	# AND WHAT THE FRAME ITSELF DOES, which is the one thing on this comparison
	# that no gauge can show: a perk is a rule, not a number, and two hulls with
	# identical bars can play nothing alike because of these two lines.
	for pid in h.perks():
		var pk := UITheme.body(DB.perk_text(pid), UITheme.EMBER, UITheme.FS_SMALL)
		pk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(pk)
	var wrap := VBoxContainer.new()
	wrap.add_child(row)
	return wrap


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

## How tall the block between the name and the price stands, whatever is in it.
## See where it is built for the arithmetic.
const DESC_H := 86
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
## Which item in the hold is open. Same idea as `_pick`, its own field because
## the two lists are different lists.
var _hold_pick: int = 0
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
	# NO SECTION HEADING AND NO SCROLLER, the same as the Promenade: the thing
	# open across the top names itself in 16px, and the list underneath is pinned
	# to the bottom of a fixed panel rather than scrolling inside one.
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_hold = VBoxContainer.new()
	_hold.add_theme_constant_override("separation", 8)
	_hold.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_hold)
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
	# THE SHIP'S OWN NAME, not the words YOUR SHIP.
	#
	# "Your ship" is true of it on every screen and says nothing; the thing you
	# actually want off a rail you are scrolling past is WHICH ship, and after
	# the renaming work that is a name you chose. It falls back to the frame's
	# own when you have not named it, which is what the masthead does.
	#
	# In the manufacturer's colour, so the rail's bottom cell agrees with the
	# banner at the top of it about who built what you are flying.
	_berth_name = UITheme.body("", UITheme.CHILL, UITheme.FS_SMALL)
	_berth_name.clip_text = true
	box.add_child(_berth_name)

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
	# THE GUNS ARE A LAYER, NOT PART OF THE SHIP SPRITE.
	#
	# `ShipView.refresh` blits the hull sprite and stops -- its own header says
	# so: "the modules are their own sprites". So a bare ShipView draws a bare
	# hull however much is bolted on, and this cell showed an empty frame for as
	# long as it has existed. The refit screen only looks right because it has a
	# `MountPoints` over its view; this is the same layer, in the display-only
	# mode the sector strip uses -- no drop targets, no empty hardpoint rings, no
	# tractor beam. Just a ship with its guns on it.
	var berth_pts := MountPoints.new()
	_berth_art.add_child(berth_pts)
	berth_pts.attach(_berth_art)
	berth_pts.passive()
	var berth_box := Control.new()
	berth_box.custom_minimum_size = Vector2(BERTH_W, BERTH_H)
	berth_box.clip_contents = true
	berth_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	berth_box.add_child(_berth_art)
	box.add_child(berth_box)
	# Re-placed whenever the ship changes: the scale is fixed but the canvas is
	# not, and a hull swap moves where the centre of it is.
	Sig.ship_changed.connect(_fit_berth)
	_fit_berth()

	var wrap := Widgets.panel_with(Widgets.pad(box, 2, 5))
	# THE ONE THING ON THE RAIL THAT LEAVES. Every deck cell is somewhere you go
	# and come back from; this is the door, so it wears the same ink BUY does.
	var out := _commit_button("UNDOCK", func() -> void: Router.show_sector())
	out.custom_minimum_size = Vector2(RAIL_W, 20)
	_undock = out

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

## Every scale the berth is allowed to draw at, largest first.
##
## Whole-block reductions only: 1x, then 2x2 into one pixel, then 4x4 into one.
## The biggest frames are 392 art pixels across and the rail leaves 134, so
## without the last rung there is no scale on this list that fits them.
const BERTH_STEPS: Array[float] = [1.0, 0.5, 0.25]

func _fit_berth() -> void:
	if _berth_name != null and Run.hull != null:
		_berth_name.text = (Run.ship_name if Run.ship_name != ""
			else Run.hull.name).to_upper()
		_berth_name.add_theme_color_override("font_color",
			DB.manufacturer_colour(Run.hull.manufacturer))
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
	# MEASURED ON THE SHIP, NOT ON THE SHEET, and at the largest clean step that
	# actually fits.
	#
	# A flat half was right for most of the range and wrong for the top of it:
	# hull sheets run to 392x140 and the rail leaves 134x56, so the biggest
	# frames were cut fourteen to thirty pixels at each end. Centred, but a ship
	# with its nose and its engines missing does not read as centred.
	#
	# Two changes fix it together. A QUARTER IS AS CLEAN AS A HALF -- 2x2 into
	# one pixel, 4x4 into one, both uniform -- so the ladder is a real ladder and
	# not a fractional fit; `_flag_scale` does the same for the banners. And the
	# fit is measured on the INK: a 324x112 sheet holds 241x106 of actual hull,
	# and scaling to the sheet spends the rail on empty pixels. Ten of the twelve
	# sheet sizes clear the box at a half once the margin is discounted.
	# CROP FIRST, MEASURE SECOND. `ink_rect` reads the composited image, and
	# `crop` is what composites it -- asking before it has run gets the
	# full-canvas fallback, so the very first layout centred the SHEET and left
	# the ship sitting right of middle with a hole beside it. It corrected itself
	# the next time the ship changed, which is why it looked intermittent.
	_berth_art.crop(int(cw), int(ch))
	var ink := _berth_art.ink_rect()
	var iw := float(maxi(1, ink.size.x))
	var ih := float(maxi(1, ink.size.y))
	var box := Vector2(float(BERTH_W), float(BERTH_H))
	var k := BERTH_STEPS[BERTH_STEPS.size() - 1]
	for step in BERTH_STEPS:
		if iw * step <= box.x and ih * step <= box.y:
			k = step
			break
	# THE CANVAS STAYS WHOLE AND THE WRAPPER CLIPS THE MARGIN. Cropping the view
	# to the ink would re-centre the SHEET in a smaller control and cut the ship
	# instead of the emptiness -- `crop` sizes the control, and the texture is
	# drawn centred inside whatever it is given.
	_berth_art.scale = Vector2(k, k)
	var ink_mid := Vector2(float(ink.position.x) + iw * 0.5,
		float(ink.position.y) + ih * 0.5)
	_berth_art.position = (box * 0.5 - ink_mid * k).round()


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
	_yard_take.visible = up
	_yard_price.visible = up
	_yard_sum.visible = up
	if not up:
		# A LINE RATHER THAN A BLANK PANEL. Not every yard has a ship, and an
		# empty half-page reads as a screen that failed to load -- "no hull here"
		# is a real answer to the question you came to this deck with.
		_hull_offer.add_child(UITheme.body(
			"Nothing on the blocks. This yard does repairs.",
			UITheme.COLD, UITheme.FS_SMALL))
	else:
		var ask := Market.hull_price(n, h)
		var part_ex := Market.hull_bid(n, Run.hull)
		var price: int = maxi(0, ask - part_ex)
		_yard_sum.text = "%d ASKING
LESS %d FOR YOUR %s" % [ask, part_ex,
			Run.hull.name.to_upper()]
		_yard_price.text = "%d CR" % price
		_yard_take.disabled = Run.credits < price
		# REBOUND EVERY REFRESH, because the hull on the blocks is not the same
		# object between visits and a Callable bound to the last one would buy a
		# ship that is not there.
		for c in _yard_take.pressed.get_connections():
			_yard_take.pressed.disconnect(c.callable)
		_yard_take.pressed.connect(_on_action.bind("take_hull", h))

		_hull_offer.add_child(_offer_column(h))

	Widgets.clear(_services)
	var missing := Run.max_hp() - Run.hp

	# THE PIPS ARE THE HULL BAR AT THE TOP OF THE SCREEN, at the same eight-cell
	# resolution the HUD uses -- so "+8" is shown in the shape you already read
	# your hull in rather than as a number you have to place.
	var full_hp := maxi(1, Run.max_hp())
	var eight := mini(8, maxi(1, missing))
	var eight_cost := Market.repair_price(n, eight)
	var repair := _service("HULL REPAIR +%d" % eight, "%d cr" % eight_cost,
		_repair.bind(eight), UITheme.GOOD, &"repair",
		Vector2i(int(round(float(eight) * 10.0 / float(full_hp))), 10))
	_set_service_enabled(repair, missing > 0 and Run.credits >= eight_cost)
	repair.tooltip_text = Widgets.tip("%.1f credits a point here. Work is dear on the frontier and cheap in a capital." % Market.repair_rate(n))
	_services.add_child(repair)

	var full_cost := Market.repair_price(n, missing)
	var full := _service("FULL HULL REPAIR", "%d cr" % full_cost,
		_repair.bind(missing), UITheme.GOOD, &"repair",
		Vector2i(int(round(float(missing) * 10.0 / float(full_hp))), 10))
	_set_service_enabled(full, missing > 0 and Run.credits >= full_cost)
	_services.add_child(full)

	var refuel_cost := Market.refuel_price(n)
	var refuel := _service("REFUEL +%d" % Market.REFUEL_UNITS,
		"%d cr" % refuel_cost, _refuel, UITheme.CHILL, &"fuel")
	_set_service_enabled(refuel, Run.credits >= refuel_cost)
	_services.add_child(refuel)

	# SYSTEM REPAIR: ONE ROW, AND A PICKER BEHIND IT.
	#
	# It was one row per distinct malfunction, which was right about the CHOICE
	# and wrong about where to put it. Four things wrong with your ship made four
	# service rows and pushed repair and refuelling off the top of a panel that
	# only ever has room for four -- so the more you needed the yard, the less of
	# it you could see. A picker moves the list to a place that can be as long as
	# the list is, and leaves the deck showing what the deck is for.
	#
	# The row still says HOW MANY, because that is the part you need before you
	# decide to open anything.
	var purge_cost := Market.purge_price(n)
	var dross_n := Run.dross_count()
	if dross_n > 0:
		var pb := _service("SYSTEM REPAIR — %d FAULT%s" % [dross_n,
			"" if dross_n == 1 else "S"], "%d cr" % purge_cost,
			_open_purge, UITheme.LEAVE, &"purge")
		pb.tooltip_text = Widgets.tip("Choose which one comes out. Each costs the same and clears exactly one.")
		_set_service_enabled(pb, Run.credits >= purge_cost)
		_services.add_child(pb)

	# NO +2 HEAT CAP, AND NO SELLING MATERIALS HERE.
	#
	# Heat capacity is what a thermal module is FOR. Buying two points of it off a
	# counter for credits made the whole thermal ladder optional -- there is no
	# reason to fit a heat sink, or to want one on a shelf, if the yard will sell
	# you the same number without a hardpoint.
	#
	# And selling an exotic was a row here AND a row on the Exchange, which is the
	# deck that exists to answer "what will you give me for what I am carrying".
	# The Exchange prices materials with the same `Market.material_price` this
	# used, so nothing about the trade changed except where it is done.


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


## WHAT IT COSTS AND WHAT YOU CAN DO, in a column of its own.
##
## THIRD COLUMN, NOT THE FOOT OF THE FIRST. The price used to sit under the
## description, which put it a long way down the page and made its y depend on
## how much the part had to say -- so the whole column had to be padded to a
## fixed height to stop the button moving as you clicked along the shelf.
##
## Beside the cards it is level with them, always in the same place, and it fills
## the two hundred pixels that were empty to the right of a two-card fan. The
## page now reads left to right as three answers: what it IS, what it GIVES you,
## what it COSTS.
func _money_column(price: int, buttons: Array) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	col.add_child(UITheme.body("%d CR" % price, UITheme.EMBER, UITheme.FS_HEAD))
	for b in buttons:
		var btn := b as Button
		btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		col.add_child(btn)
	return col


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
## Your own ship, shown small above the offer so the two can be compared. Half
## the offer's height: it is the reference, not the subject.
const HULL_MINI_H := 34
## How tall each ship stands in the shipyard comparison, and how wide its column
## is. The canvas is 324x112 at 1x, so a half is 162x56 -- two of those plus the
## gap is 340 of the 740 the page has, which leaves the gauges beside them room
## to be full width.
## How deep the shipyard's two portraits are.
##
## The tallest hull in the game is 110 art pixels of ink and they are drawn at
## 1x, so this is that plus a little air. It was 50, which was right when they
## were halved.
const SHIP_BOX_H := 118
## How wide the offer's portrait box is.
##
## The widest hull in the game is 296 art pixels of ink and it is drawn at 1x,
## so this is that plus air -- and it leaves the other half of a 740 panel for
## the gauges, which is the point of putting them side by side.
const OFFER_W := 340

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


## Open a different part on the shelf. See `_shelf_row`, which takes the setter
## as a Callable so one row builder serves both the Promenade and the Exchange.
func _pick_shelf(i: int) -> void:
	_pick = i
	_refresh_stock(Run.node_at())


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


func _shelf_row(thing: Variant, price: int, pick: int, open: bool,
		on_pick: Callable) -> Button:
	var b := Widgets.button("", on_pick.bind(pick))
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

	# THREE KINDS OF THING GO DOWN THIS LIST. The Promenade only ever shows hulls
	# and modules, but the Exchange shows the hold -- which also carries
	# MATERIALS, and a material is neither. Casting to both and reading `.name`
	# off whichever was not null threw the moment an exotic reached the row.
	var h := thing as HullData
	var m := thing as ModuleData
	var mat := thing as MaterialData
	var nm_text: String = h.name if h != null else (m.name if m != null
		else (mat.name if mat != null else "?"))
	# Each kind grades itself in its own vocabulary: a hull has a tier letter and
	# says so on its own line, a module has a rarity, a material has a tier band.
	var nm_ink: Color = UITheme.ICE
	if m != null:
		nm_ink = ModuleData.rarity_ink(m.rarity)
	elif mat != null:
		nm_ink = UITheme.tier_colour(mat.tier)
	var thumb := TextureRect.new()
	thumb.texture = h.sprite if h != null else (m.sprite if m != null
		else (mat.sprite if mat != null else null))
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	thumb.custom_minimum_size = Vector2(46, ROW_TALL - ROW_PAD * 2)
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(thumb)

	# Graded here too, so the shelf reads as a shelf: four names in four inks and
	# you know which one is worth opening before you open it.
	var nm := UITheme.body(nm_text.to_upper(), nm_ink, UITheme.FS_SMALL)
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
	if m != null:
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

	var mod := open.thing as ModuleData
	var left := _part_column(mod)
	top.add_child(left)


	top.add_child(_card_fan(mod, "ADDS TO YOUR DECK"))
	var buy := _commit_button("BUY", _on_action.bind("buy", open.thing))
	buy.disabled = Run.credits < int(open.price)
	top.add_child(_money_column(int(open.price), [buy]))

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
			int(row.pick) == _pick, _pick_shelf))


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
	Widgets.clear(_hold)
	# THE PAD IS LISTED HERE TOO, and it has to be: this deck is the only place
	# in the game that pays for anything, and the pad is a list of things you
	# must clear before the ship will leave. A dock you could not sell from
	# would leave the hatch as the only exit -- throwing a rare part away to
	# undock, while standing in front of somebody who would have bought it.
	#
	# Appended rather than merged, so the things you are already carrying stay
	# in the order you arranged them and the strays sit together at the end.
	var aboard: Array[HoldItem] = []
	aboard.append_array(Run.cargo)
	aboard.append_array(Run.pad)
	if aboard.is_empty():
		_hold.add_child(UITheme.body("Hold empty.", UITheme.COLD, UITheme.FS_SMALL))
		return

	# THE OPEN ITEM SURVIVES A SALE, or falls to whatever is still aboard.
	# Selling the thing you are looking at removes it from the hold, and an index
	# left pointing at it would open an empty panel on the one screen where
	# something just happened.
	if _hold_pick >= aboard.size():
		_hold_pick = 0
	var item: HoldItem = aboard[_hold_pick]
	var mod := item as ModuleData
	var mat := item as MaterialData
	var price: int = Market.material_price(n, mat.id) if mat != null \
		else Market.bid(n, mod)

	# NO EXPAND ON THE TOP BAND HERE, unlike the Promenade. There the band takes
	# the slack so the short list is pinned to the bottom; here the SCROLLER
	# takes it, because the list is the part that can outgrow the page. Two
	# expanding children would split the space and give the scroller half a panel
	# whether it needed one or not.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	_hold.add_child(top)

	var left: VBoxContainer
	if mod != null:
		left = _part_column(mod)
	else:
		# A MATERIAL IS NOT A PART, and the panel says so by being shorter rather
		# than by filling the same shape with blanks. It has no slot, no affixes
		# and no cards -- what it has is a tier, a size and a sentence about where
		# it comes from, and that is the whole of it.
		left = VBoxContainer.new()
		left.add_theme_constant_override("separation", 4)
		left.custom_minimum_size = Vector2(PICK_W, 0)
		left.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		left.add_child(UITheme.body(mat.name.to_upper(),
			UITheme.tier_colour(mat.tier), UITheme.FS_HEAD))
		left.add_child(UITheme.body("%d×%d · %s" % [mat.size.x, mat.size.y,
			String(mat.tier).to_upper()], UITheme.COLD, UITheme.FS_SMALL))
		var blurb := UITheme.body(mat.text, UITheme.QUOTE, UITheme.FS_SMALL)
		blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		blurb.custom_minimum_size = Vector2(PICK_W, DESC_H)
		left.add_child(blurb)
	top.add_child(left)

	# --- WHAT IT IS WORTH AND WHAT YOU CAN DO, in the same third column the
	# Promenade prices things in.
	#
	# INSTALL first, because the reason to carry a part is to bolt it on, and the
	# other two are what you do once you have decided not to.
	var acts: Array = []
	if mod != null:
		# SWAP IN when every mount of that slot is taken, which is the same
		# question `Widgets.module_row` asks -- a button that says INSTALL and
		# then quietly displaces something is a button that lied.
		var full := Run.slots_used(mod.slot) >= Run.slots_for(mod.slot)
		acts.append(_commit_button("SWAP IN" if full else "INSTALL",
			_on_action.bind("install", mod)))
	# A MATERIAL SELLS THROUGH ITS OWN PATH. `_sell_material` spends one of that
	# id out of the hold and pays the flat price. This is the only place in the
	# game that sells a material now -- the Yard used to carry a row per material
	# as well, which is the same trade offered twice on two decks.
	var sell := Widgets.button("SELL", _sell_material.bind(mat.id) if mat != null
		else _on_action.bind("sell", item))
	# A MARKET THAT WILL NOT PAY SAYS SO ON THE BUTTON. `Market.bid` returns 0
	# for contraband where contraband does not trade, and a SELL that silently
	# does nothing is worse than one that is visibly refused.
	sell.disabled = price <= 0
	acts.append(sell)
	if mod != null:
		acts.append(Widgets.button("SCRAP", _on_action.bind("scrap", mod)))

	if mod != null:
		top.add_child(_card_fan(mod, "IN YOUR DECK"))
	top.add_child(_money_column(price, acts))

	# --- BOTTOM BAND: everything aboard, across the full width.
	_hold.add_child(UITheme.hsep())
	# THE HEADING COUNTS THE STRAYS, in the red the rest of the game reserves for
	# something being lost. It is the one line on this deck that explains why the
	# door downstairs is shut.
	if Run.pad.is_empty():
		_hold.add_child(UITheme.body("HOLD", UITheme.COLD, UITheme.FS_SMALL))
	else:
		_hold.add_child(UITheme.body("HOLD — %d ON THE PAD, NOT STOWED"
			% Run.pad.size(), UITheme.LEAVE, UITheme.FS_SMALL))
	# SCROLLED, WHERE THE SHELF IS NOT. A shop stocks at most five things and its
	# list can never outgrow the band; a hold is twenty cells and routinely
	# carries more rows than fit. Without this the last one is simply cut off by
	# the panel edge, which is the failure that hides cargo rather than showing
	# it -- the same class of bug as the crash this deck had an hour ago.
	var rest := VBoxContainer.new()
	rest.add_theme_constant_override("separation", 5)
	var sc := Widgets.scroller(rest, 60)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_hold.add_child(sc)
	for i in aboard.size():
		var it: HoldItem = aboard[i]
		var m2 := it as MaterialData
		var p2: int = Market.material_price(n, m2.id) if m2 != null \
			else Market.bid(n, it as ModuleData)
		rest.add_child(_shelf_row(it, p2, i, i == _hold_pick, _pick_hold))


## Open a different thing in the hold. Its own function because `_shelf_row`
## takes the setter as a Callable -- the Promenade sets `_pick` and this sets
## `_hold_pick`, and a row cannot know which list it is in.
func _pick_hold(i: int) -> void:
	_hold_pick = i
	_refresh_hold(Run.node_at())


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

