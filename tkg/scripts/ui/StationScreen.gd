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
var _trade: Label
## What kind of place this is, in its own words. Fills the column under the
## services with something worth reading rather than with nothing.
var _blurb: Label
var _hull_gauge: HBoxContainer
var _heat_gauge: HBoxContainer
var _services: VBoxContainer
var _stock: VBoxContainer
var _hull_box: VBoxContainer
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
## magnification came down.
const HULL_H := 120
## And how wide the window onto it is. A cap, not a measurement: it bounds the
## control's minimum so the row cannot overflow the way it did when a doubled
## 474-wide hull sat beside 420 of services. At 1x the widest hull is 248, so
## the cap is slack on purpose and the portrait is centred in it.
const HULL_W := 380
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
	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 2)
	_header = RichTextLabel.new()
	_header.bbcode_enabled = true
	_header.fit_content = true
	# NEVER WRAPS. Sized to its content and left to be as wide as it is — inside a
	# shrinking panel an autowrapping label collapsed to its narrowest legal width
	# and stacked "CITY STATION · HIGH / SECURITY · DANGER / 5" into a column.
	# One line is the only shape this sentence has.
	# WRAPS, AT A WIDTH THIS SCREEN CHOOSES.
	#
	# Both obvious settings are wrong here and they are wrong in opposite
	# directions. Autowrap ON inside a shrinking panel collapses to the narrowest
	# legal width and stacks the line into a column. Autowrap OFF reports the
	# WHOLE UNWRAPPED LINE as a minimum width — and a Control is never laid out
	# smaller than its minimum, even when anchored — so the header grew the entire
	# screen to 983 inside a 960 window and every panel on it hung off the right
	# edge. The symptom looked exactly like a missing margin.
	#
	# A fixed width and wrapping is the only combination that is neither: the
	# header is as wide as this screen says and no wider, and it is the screen
	# that decides rather than the sentence.
	_header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_header.custom_minimum_size = Vector2(HEADER_W, 0)
	_header.scroll_active = false
	_header.add_theme_stylebox_override("normal", UITheme.empty())
	head.add_child(_header)
	# Who this market is short of, said in words. The rule behind the prices is
	# simple enough to state, so state it — a trade economy the player has to
	# reverse-engineer from receipts is a puzzle, not an economy.
	_trade = UITheme.body("", Color("#d99b29"), UITheme.FS_SMALL)
	head.add_child(_trade)
	# SHRINK, NOT FILL. A RichTextLabel with `fit_content` derives its minimum
	# width from its own unwrapped text, and inside an expanding panel that
	# minimum won the argument — the header ran past the frame and sliced UNDOCK
	# in half against the window. Sized to its content, it cannot push anything.
	# FULL WIDTH, like the tab row and the page under it. A header that stops
	# two thirds of the way across is the first thing that makes a screen look
	# unaligned, and every block below it starts and ends at the same two x's.
	var head_wrap := Widgets.panel_with(Widgets.pad(head))
	head_wrap.size_flags_horizontal = Control.SIZE_FILL
	root.add_child(head_wrap)

	# --- the tab bar
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 4)
	for entry in TABS:
		var id: StringName = entry[0]
		var b := Widgets.button(String(entry[1]), func() -> void: _show_tab(id))
		b.custom_minimum_size = Vector2(104, 20)
		_tabs[id] = b
		bar.add_child(b)
	# UNDOCK sits WITH the tabs rather than pushed to the far right of the row.
	#
	# Pinned to the right it was the one control on the screen whose position
	# depended on the window being exactly as wide as expected, and the window is
	# resizable — so on a wider window it sat correctly and in a 960 screenshot it
	# was sliced in half, which cost most of an afternoon to not-diagnose. A
	# control at the end of an expanding row is a control at the mercy of the
	# row's width. Grouped left, it is at the mercy of nothing.
	#
	# It reads fine there anyway: the row is the things you can do at a station
	# and leaving is one of them.
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(20, 0)
	bar.add_child(spacer)
	var out := Widgets.button("UNDOCK", func(): Router.show_sector())
	out.custom_minimum_size = Vector2(104, 20)
	bar.add_child(out)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(gap)
	root.add_child(bar)

	# --- the pages, all built, one visible
	var body := Control.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(body)

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
	_blurb = UITheme.body("", UITheme.QUOTE, UITheme.FS_SMALL)
	_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_blurb.custom_minimum_size = Vector2(SERVICE_W - 24, 0)
	box.add_child(UITheme.hsep())
	box.add_child(_blurb)
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

	var ship := Widgets.section("your hull")
	var art := ShipView.new()
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 1x AND cropped to a fixed window, in that order. The doubling lives in the
	# art now — hulls are authored at 2x their box — so magnifying here applies
	# it twice and a heavy becomes 496 wide on a 960px viewport. See boxes.py.
	#
	# The crop stays regardless of the scale: `magnify` alone sizes the control
	# to the whole canvas, and 420 of services plus an unbounded hull overflowed
	# the row and shoved the whole screen seven pixels past the right edge of the
	# window. That bug looked like a missing margin and was a minimum nobody had
	# bounded, which is still true at any magnification.
	art.magnify(1, HULL_H)
	art.crop(HULL_W, HULL_H)
	# Centred in its column rather than left-aligned in it. The column is wider
	# than the portrait and a picture pinned to one side of a panel is the other
	# half of "nothing lines up".
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ship.add_child(art)
	# The two gauges the column to the left is selling. Hull is what REPAIR buys
	# and heat cap is what the coolant buys, so the numbers those services move
	# are on the same page as their prices — and the +2 that used to look like it
	# did nothing is now visible from the button that does it.
	ship.add_child(UITheme.hsep())
	_hull_gauge = _gauge_row("HULL")
	ship.add_child(_hull_gauge)
	_heat_gauge = _gauge_row("HEAT")
	ship.add_child(_heat_gauge)

	var sw := Widgets.panel_with(Widgets.pad(ship))
	sw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sw.size_flags_stretch_ratio = 1.0
	sw.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(sw)
	return row


## A label, a gauge and a figure, on the row height everything else uses.
func _gauge_row(key: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size = Vector2(0, ROW_H)
	var k := UITheme.body(key, UITheme.COLD, UITheme.FS_SMALL)
	k.custom_minimum_size = Vector2(38, 0)
	k.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(k)
	var g := BoxGauge.new()
	g.name = "Gauge"
	row.add_child(g)
	var v := UITheme.body("", UITheme.CHILL, UITheme.FS_SMALL)
	v.name = "Value"
	v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(v)
	return row


func _page_work() -> Control:
	var box := Widgets.section("work")
	_work = VBoxContainer.new()
	_work.add_theme_constant_override("separation", 5)
	var sc := Widgets.scroller(_work, 90)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(sc)
	return Widgets.panel_with(Widgets.pad(box))


func _page_stock() -> Control:
	var box := Widgets.section("stock")
	_hull_box = VBoxContainer.new()
	_hull_box.add_theme_constant_override("separation", 6)
	box.add_child(_hull_box)
	_stock = VBoxContainer.new()
	_stock.add_theme_constant_override("separation", 6)
	var sc := Widgets.scroller(_stock, 90)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(sc)
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
		if on:
			b.add_theme_stylebox_override("normal", UITheme.bevel(Color("#4a2a0c"), 3, 5))
			b.add_theme_stylebox_override("disabled", UITheme.bevel(Color("#4a2a0c"), 3, 5))
			b.add_theme_color_override("font_disabled_color", UITheme.HOT)
		else:
			b.remove_theme_stylebox_override("normal")
			b.remove_theme_stylebox_override("disabled")
			b.remove_theme_color_override("font_disabled_color")


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
	if n.region != MapGen.Region.LAWLESS and r.randf() < 0.4:
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

	_trade.text = Market.trade_line(n)
	_blurb.text = MapGen.place_blurb(n)
	(_hull_gauge.get_node("Gauge") as BoxGauge).setup(
		BoxGauge.Mode.HULL, Run.max_hp(), Run.hp)
	(_hull_gauge.get_node("Value") as Label).text = "%d/%d" % [Run.hp, Run.max_hp()]
	(_heat_gauge.get_node("Gauge") as BoxGauge).setup(
		BoxGauge.Mode.HEAT, Run.heat_cap(), Run.heat)
	(_heat_gauge.get_node("Value") as Label).text = "%d/%d" % [Run.heat, Run.heat_cap()]


## Repair, fuel, coolant, and one row per material you are carrying.


func _refresh_services(n: MapGen.MapNode) -> void:
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


func _refresh_stock(n: MapGen.MapNode) -> void:
	Widgets.clear(_hull_box)
	# One deck build for the whole list, handed to every row — see Widgets.module_row.
	var deck := DeckBuilder.build().size()
	if n.shop_hull != null and not n.taken.has(MapGen.OPTION_SHOP_HULL):
		_hull_box.add_child(Widgets.hull_row(n.shop_hull, "PURCHASE",
			Market.hull_price(n, n.shop_hull), _on_action))

	Widgets.clear(_stock)
	# What is LEFT, which is not the same as what is on the shelf. A sold part
	# stays in `n.shop` so that everybody's slot numbers keep meaning the same
	# thing — see MapGen.OPTION_SHOP — and is hidden here instead.
	var left := 0
	for i in n.shop.size():
		if n.taken.has(MapGen.OPTION_SHOP + i):
			continue
		left += 1
		var m: ModuleData = n.shop[i]
		_stock.add_child(Widgets.module_row(m, Widgets.ModuleContext.SHOP,
			Market.ask(n, m), _on_action, "", deck))
	if left == 0:
		_stock.add_child(UITheme.body("Shelves bare. Nothing restocks — what was brought here is gone.",
			UITheme.COLD, UITheme.FS_SMALL))


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
	Run.log_line("Sold 1 %s for %d credits." % [DB.material_name(id).to_lower(), paid], &"good")

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
			Audio.play(&"hull_transfer", 0.03)
			Run.transfer_to_hull(h)
		"install":
			Audio.play(&"module_install", 0.04)
			Run.install_module(thing as ModuleData)
		"scrap":
			Audio.play(&"module_scrap", 0.05)
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

