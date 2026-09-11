class_name HudBar
extends PanelContainer

## Persistent top bar: navigation, hull, heat, and the economy.
##
## SHIP and MAP live here rather than inside each screen, so they are in the same
## place everywhere. SHIP greys out during combat instead of disappearing — you
## cannot refit mid-fight, and a button that says so beats one that vanishes.
##
## BUILT ONCE, UPDATED IN PLACE. It used to free every child and remake them on
## each of three signals, which cost more than it looks:
##
## - The tabs were destroyed and remade under the cursor, losing hover state and
##   flickering — very visible when clicking through chassis on the select
##   screen, which emits ship_changed on every click.
## - Freeing is deferred to end of frame, so for one frame the bar held both
##   sets of children and reported twice its real width. Everything above it
##   grew to match; on the star chart, whose sky is cached against panel width,
##   that threw the cache away and rebuilt forty thousand stars — about 180ms,
##   on every screen change, for a layout nobody ever saw.
##
## So refresh() now only writes values and states. Nothing here is constructed
## after _ready.

## How far a readout's label sits from its number, and how far one readout sits
## from the next. THE SECOND MUST BE THE LARGER -- that is the whole of the rule,
## and it was inverted once: six inside against the row's five between, so
## "CREDITS 40 EXOTIC 2" bound 40 to EXOTIC rather than to its own word.
##
## TWELVE CAME DOWN TO EIGHT. Twelve was set while the economy sat in the middle
## of the bar with a divider on either side of it; at the right-hand end, with
## nothing after FUEL, that much air read as the readouts drifting apart rather
## than as a group. Eight against four is still plainly two to one, which is all
## the rule asks.
const STAT_GAP := 4
const ECON_GAP := 8

## Air between the ship's gauges and the two dev catalogues. Wide enough to read
## as a break, narrow enough that CARDS still belongs to the left-hand half of
## the bar rather than floating in the middle of it.
const MID_GAP := 24

var _row: HBoxContainer
var _built: bool = false

var _tab_ship: Button
var _tab_sector: Button
var _tab_chart: Button
var _tab_cards: Button
var _tab_parts: Button
## Only ever visible in a party. Built unconditionally, because a party can form
## before the HUD exists and can also outlive it — hiding a built button is one
## state to keep in step, and rebuilding the bar when somebody joins is a whole
## screen redrawn for one tab.
var _tab_party: Button
## The archive. Always built and always available: what you have read survives
## the ship, so unlike SHIP and PARTY there is no run state that makes reading a
## page wrong. It does NOT grey during a fight — see refresh().
var _tab_archive: Button

var _hull_label: Label
var _hull: BoxGauge
var _hull_text: Label
var _heat_label: Label
var _heat: BoxGauge
var _heat_text: Label
var _scrap: HBoxContainer
var _fuel: HBoxContainer

func _ready() -> void:
	add_theme_stylebox_override("panel", UITheme.bevel(UITheme.PANEL, 5, 6))
	# THE BAR MUST NOT BE ABLE TO WIDEN THE GAME.
	#
	# A PanelContainer takes its minimum from its child, and this row's minimum is
	# the sum of every tab, gauge and readout on it — 983px with dev mode on. The
	# HUD is the first child of `Main`'s column, so that minimum became the
	# column's, and the column's became the MarginContainer's, and every SCREEN
	# below inherited it: at a 960 window each page was laid out 983 wide and hung
	# 23px off the right edge. One row nobody could fit made every panel in the
	# game overflow, and it looked like each screen had a margin bug of its own.
	#
	# The row now lives in a clipping wrapper whose own minimum is zero, so the
	# window sizes the HUD rather than the HUD sizing the window. If the bar ever
	# genuinely does not fit, it loses its right-hand end instead of shoving the
	# rest of the interface off screen — a readout you cannot see is a smaller
	# problem than a layout nobody can trust.
	#
	# This is the third tab added to this bar in a day. The next one costs
	# nothing.
	var clip := Control.new()
	clip.clip_contents = true
	clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip.custom_minimum_size = Vector2(0, ROW_H)
	add_child(clip)

	_row = HBoxContainer.new()
	# Six, not ten. The bar carries about twenty children, so the separation
	# alone was two hundred pixels — more than any single readout on it — and
	# four of those pixels per gap is the difference between the whole bar
	# fitting a 960 window and losing its last readout off the end. Nothing is
	# removed and nothing is renamed; the air between things is just slightly
	# less generous.
	#
	# FIVE NOW, and the same lever for the same reason. `-- stationshot` prints
	# what the row wants against what it has, so the next person to add
	# something here can check rather than guess.
	_row.add_theme_constant_override("separation", 5)
	_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip.add_child(_row)
	_build()
	Sig.resources_changed.connect(refresh)
	Sig.ship_changed.connect(refresh)
	Sig.screen_changed.connect(refresh)
	Sig.dev_mode_changed.connect(_rebuild)
	refresh()

## Throw the bar away and build it again.
##
## The dev switch decides which tabs EXIST, not which are visible, so repainting
## is not enough — the row has to be constructed a second time. Widgets.clear()
## rather than a bare queue_free(): the old tabs must be gone before the new ones
## are added, or the row lays out both for a frame.
## How tall the bar is, now that its wrapper cannot take a height from the row.
const ROW_H := 20

func _rebuild() -> void:
	Widgets.clear(_row)
	_build()
	refresh()

func _build() -> void:
	# THE OPTIONAL TABS ARE FORGOTTEN FIRST, and this is a bug fix rather than
	# tidiness.
	#
	# `_rebuild` frees every child of the row and builds it again. When dev mode
	# goes OFF, the branch that makes these two does not run -- so the fields
	# went on holding the buttons that had just been freed, and every refresh
	# after that handed a dead Object to `_state`.
	#
	# IT DID NOT FAIL WHERE YOU WOULD EXPECT. `_state` opens with `if b == null`,
	# and a freed reference is not null -- but it never reached that line either:
	# the call is REJECTED AT THE ARGUMENT, because a typed parameter will not
	# accept a previously-freed object. No guard inside the function can catch
	# it.
	#
	# It also did not fail immediately. `Widgets.clear` calls queue_free, which
	# is deferred, so the rebuild's own refresh still saw live buttons and wrote
	# correct values; the throw waited for the NEXT refresh a frame later. That
	# is why turning dev off ON THE LAUNCHER -- where there is no run and refresh
	# returns early -- gave a bar that only broke once a run started: every tab
	# and gauge built, SHIP through ARCHIVE lit correctly, and then nothing.
	# PARTY still showing, both gauges empty, no credits and no fuel, because the
	# throw landed between the tab states and the values.
	_tab_cards = null
	_tab_parts = null

	# --- LEFT: where you can go.
	#
	# Ship | Sector | Starchart | Archive. The page you are on is lit rather than
	# merely disabled, so the nav says where you are as well as where you can go.
	_tab_ship = _tab("SHIP", func() -> void: Router.show_ship())
	_row.add_child(_tab_ship)
	# ONE TAB, TWO NAMES. Docked, this reads STATION and goes to the station;
	# flying, it reads SECTOR and goes to the sector. It is the same slot either
	# way because it is the same idea -- "the place I am parked" -- and a second
	# tab that appears and disappears at a station would move STARCHART and
	# ARCHIVE sideways every time you tied up.
	#
	# The action dispatches at CLICK time rather than being rebound on docking:
	# nothing on this bar is constructed after _ready, and swapping a Callable
	# is one more piece of state to keep in step with the label.
	_tab_sector = _tab("STATION", _go_here)
	# HELD AT THE WIDTH OF THE LONGER WORD. STATION is a character wider than
	# SECTOR, and without this the two tabs to its right -- and with them the
	# gauges, and with them the whole middle of the bar -- shuffled six pixels
	# sideways every time you tied up or let go.
	#
	# MEASURED AFTER add_child, NOT BEFORE. A Button takes its font from the
	# theme it inherits through the tree, so an unparented one measures itself in
	# Godot's default face and reserves the wrong number. `_row` is already in
	# the tree by the time _build() runs, so the child is too the moment it is
	# added, and the minimum is then taken in Silkscreen.
	_row.add_child(_tab_sector)
	_tab_sector.custom_minimum_size = Vector2(
		_tab_sector.get_combined_minimum_size().x, 0)
	_tab_chart = _tab("STARCHART", func() -> void: Router.show_starchart())
	_row.add_child(_tab_chart)
	# The archive joined the nav rather than sitting off at the right-hand end
	# with the catalogues. It is a place in the game — a thing the run gives you
	# and you go and read — where CARDS and MODULES are authoring views, and the
	# bar now separates those two ideas by position instead of by nothing.
	_tab_archive = _tab("ARCHIVE", func() -> void: Router.show_archive())
	_row.add_child(_tab_archive)
	# Hidden entirely when there is no party — a tab that is permanently greyed
	# out in the solo game is a tab that teaches the player to ignore it. Built
	# unconditionally, because a party can form before the HUD exists and can
	# also outlive it.
	_tab_party = _tab("PARTY", func() -> void: Router.show_party())
	_row.add_child(_tab_party)

	_row.add_child(_divider())

	# Hull reads as cells, like heat beside it. Ten of them whatever the frame,
	# because the useful question is what FRACTION is left — the exact figure is
	# on the tooltip, and the two ships either side of this bar disagree about
	# what a big number even is.
	_hull_label = UITheme.body("HULL", UITheme.COLD, UITheme.FS_SMALL)
	_row.add_child(_hintable(_hull_label))
	_hull = BoxGauge.new()
	_row.add_child(_hull)
	# The figure beside the cells, as heat has. The cells answer "how close am I
	# to dying"; this answers "how much does the repair cost", and the tooltip
	# should not be the only place the second one exists.
	_hull_text = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	_reserve(_hull_text, "000/000")
	_row.add_child(_hintable(_hull_text))

	# A rule between each readout. Hull and heat are both rows of cells and sat
	# directly beside each other, so at a glance the bar read as one long gauge
	# with a label in the middle of it — which is exactly the wrong impression,
	# since one is what you have left and the other is what you are spending.
	_row.add_child(_divider())

	# Heat reads as countable cells; the number beside it names the cost when
	# you are over cap, because that is the only time the number matters.
	_heat_label = UITheme.body("HEAT", UITheme.COLD, UITheme.FS_SMALL)
	_row.add_child(_hintable(_heat_label))
	_heat = BoxGauge.new()
	_row.add_child(_heat)
	_heat_text = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	# NO WIDTH RESERVED HERE ANY MORE, and it is the layout that retired it
	# rather than a change of mind.
	#
	# It reserved the over-cap form -- "00 — 00 HULL" -- because that is the long
	# one and it appears mid-fight, which is the worst possible moment for the
	# bar to jump sideways. That was true while the economy sat directly to its
	# right in the middle of the row. It does not sit there now: everything after
	# this is either a fixed gap or the slack, and the economy is pinned to the
	# right-hand end, so heat growing is absorbed by the spacer and nothing a
	# player can see moves at all.
	#
	# MEASURED, because it was not free: the reservation was 78 pixels against
	# the 21 that "0/22" actually draws, and those 57 pixels of held-open air
	# were the gap between the gauges and the catalogues. Twenty-four of MID_GAP
	# was moving the pair four pixels, because the wall it was pushing off was
	# this and not the heat number.
	#
	# The one thing that still moves is CARDS and MODULES, sliding right when you
	# go over cap. They are dev-only and they are the only things between here
	# and the slack.
	_row.add_child(_hintable(_heat_text))

	# NO SET-BONUS CHIPS HERE. They were on this bar and are not any more: the
	# ship screen already shows every allegiance you hold a part of, in a corner
	# with room to name the bonus and count the parts, and a mark repeated on a
	# bar that follows you everywhere was the same fact stated twice in the
	# smaller of the two places. `SetChip` itself stays -- ShipScreen builds it.

	# --- MIDDLE: the catalogues, and nothing else.
	#
	# A FIXED GAP, not a share of the slack. The bar reads in three groups —
	# where you can go, what the ship is, what you are carrying — and the two
	# dev-only catalogues belong to none of them, so they get air on both sides
	# and no rule.
	#
	# It was two expanding spacers, then two at a 1:3 ratio to pull the pair
	# left. MEASURED: the pair did not move -- 582 either way -- so the ratio was
	# doing nothing that could be seen, and a lever that does not move the thing
	# it is aimed at is worse than no lever. A fixed gap puts them a known
	# distance from the gauges instead of somewhere in the middle of whatever
	# space happens to be left over.
	if DevMode.enabled:
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(MID_GAP, 0)
		_row.add_child(gap)

	# Dev only. Every card in the game on one page is an authoring view, and a
	# player who reads it has been handed the answer to a game about finding out
	# what things do. Not built at all rather than hidden — see DevMode.
	#
	# Neither greys out during combat: looking at the catalog changes nothing,
	# and mid-fight is exactly when you want to check what a card was supposed
	# to say. They DO grey while choosing a chassis, which is the one moment
	# there is no run to come back to.
	if DevMode.enabled:
		_tab_cards = _tab("CARDS", func() -> void: Router.show_cards())
		_row.add_child(_tab_cards)
		# Its sibling. A card is what a module DOES and the module is the thing
		# you actually find, pack and bolt on — two catalogues, because they
		# answer two different questions and one page showing both would be a
		# list of cards with a picture beside each.
		_tab_parts = _tab("MODULES", func() -> void: Router.show_modules())
		_row.add_child(_tab_parts)

	# ALL THE SLACK IN ONE PLACE, and it is here: whatever the window has spare
	# opens up between the catalogues and the money, so the economy stays pinned
	# to the right-hand end and everything else stays where it was put.
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_row.add_child(sp)

	# --- RIGHT: what you are carrying, grouped by PROXIMITY rather than by
	# dividers.
	#
	# Every readout on this bar explains itself on hover. The bar is where the
	# whole economy is stated and none of it is self-evident: credits are one
	# currency competing with itself, fuel is priced by chart distance, and heat
	# is a second health bar you are allowed to spend.
	#
	# The gap inside a readout was SIX and the gap between two readouts was the
	# row's own five, so "CREDITS 40 EXOTIC 2" bound the wrong pairs -- 40 sat
	# closer to EXOTIC than to the word it belongs to. Nothing was misaligned;
	# the spacing simply said the opposite of the grouping. Four in, twelve
	# between, and the eye does the rest without a rule being drawn.
	var econ := HBoxContainer.new()
	econ.add_theme_constant_override("separation", ECON_GAP)
	_scrap = Widgets.stat("credits", "")
	_scrap.add_theme_constant_override("separation", STAT_GAP)
	econ.add_child(_hintable(_scrap))
	# NO CARGO UP HERE. Materials had a readout each, by name, and three pickups
	# of common salvage pushed FUEL off the end of the bar -- to say what the
	# storage grid already shows crate by crate. Sat beside CREDITS they also read
	# as a second currency, and there is only one: materials are cargo, sold for
	# credits at the Exchange.
	# Fuel joins the group rather than sitting behind a rule of its own. It IS a
	# different kind of thing -- credits are money, fuel is the
	# clock -- but ECON_GAP already says "separate readout", and a vertical bar
	# at the very end of the row was drawing a compartment with one thing in it.
	#
	# INSIDE `econ`, not beside it. Dropping the rule and leaving fuel on the row
	# left it on the row's own separation of five against the group's twelve, so
	# "RELIC 1 FUEL 279" bound the wrong pair -- exactly the mistake ECON_GAP was
	# introduced to fix, reintroduced by removing the divider that was hiding it.
	_fuel = Widgets.stat("fuel", "")
	_fuel.add_theme_constant_override("separation", STAT_GAP)
	econ.add_child(_hintable(_fuel))
	_row.add_child(econ)

	# THE RUN HISTORY IS NOT HERE ANY MORE. It is FLIGHT RECORD on the title
	# screen, which is the only place it was ever read: it is the list of runs
	# you have FINISHED, so consulting it mid-run is looking up somebody else's
	# ship. Removing it also bought the row back about sixty pixels, which is
	# what let the economy move to the right-hand end without clipping.
	#
	# THE FRAME COUNTER IS GONE TOO, and the bar is the better for the room.
	#
	# It was the last thing on the row, so when the row ran out of width it was
	# the thing that got cut — and it was cut at a standard window size, which is
	# how the whole overflow was found. Reserving its width made the row 948
	# against 944 available and it was still clipped; putting it behind the dev
	# switch fixed it for players and left it broken for the only people who
	# wanted it.
	#
	# So: removed. It measured the renderer rather than the game, nothing on this
	# bar was ever decided by it, and it was costing the row about fifty pixels
	# that the readouts people actually use now have.
	_built = true

func refresh() -> void:
	if not _built or Run.hull == null:
		return


	var fighting := Router.in_combat()
	# Choosing a chassis locks the whole bar. Until you have launched there is no
	# sector to look at, no chart to plot on and nothing to refit — and a SHIP
	# tab that works before the run starts is an invitation to change a hull
	# behind the back of the screen whose entire job is choosing one.
	var choosing := Router.current is ChassisSelect
	var choose_lock := "Choose a chassis first." if choosing else ""
	var lock := choose_lock if choosing else ("Locked during combat." if fighting else "")

	_state(_tab_ship, Router.current is ShipScreen, lock, "Install and scrap modules.")
	# Lit on the station screen as well as the sector: both are "here", and the
	# name on the tab already says which of the three you are looking at. Combat
	# happens in the sector, so it stays lit through a fight rather than greying
	# out as if you had left.
	#
	# COMBAT OUTRANKS THE OTHER TWO. It is the one state you cannot leave, so the
	# tab that names where you are had better name that first -- and a tab
	# reading SECTOR while something is shooting at you is the bar's only
	# opportunity to be wrong about the most important thing on screen.
	#
	# All three fit the reserved width: STATION is the longest at seven, and the
	# button was built with that word for exactly this reason.
	if fighting:
		_tab_sector.text = "COMBAT"
	elif Router.docked:
		_tab_sector.text = "STATION"
	else:
		_tab_sector.text = "SECTOR"
	var here_hint := "What is around you."
	if fighting:
		here_hint = "The fight you are in."
	elif Router.docked:
		here_hint = "The station you are docked at."
	_state(_tab_sector,
		Router.current is SectorScreen or Router.current is StationScreen or fighting,
		choose_lock, here_hint)
	_state(_tab_chart, Router.current is StarchartScreen, lock, "Where to go next.")
	_state(_tab_parts, Router.current is ModuleGalleryScreen, choose_lock,
		"Every part in the game. Dev only.")
	_state(_tab_cards, Router.current is CardGalleryScreen, choose_lock,
		"Every card in the game.")
	# Greys while choosing a chassis for the same reason CARDS does — there is no
	# run to come back to — but NOT during a fight. Mid-fight is exactly when a
	# player looks something up, and reading a fifty-year-old manifest changes
	# nothing about the frigate in front of them.
	_state(_tab_archive, Router.current is ArchiveScreen, choose_lock,
		"Lore you have recovered.")
	_tab_party.visible = Net.is_networked()
	_state(_tab_party, Router.current is PartyScreen, lock,
		"Everyone you are flying with.")

	# These say what the gauge IS before they say anything about its numbers.
	# Someone hovering a bar they do not recognise is asking "what is this",
	# not "what is the arithmetic" — the figures are already beside the cells,
	# and a tooltip that opens with them answers a question nobody hovered to
	# ask. Description first, then the one consequence that matters, then the
	# live rate.
	# No repair rate here. It is priced per station now, so a number quoted on a
	# bar that follows you everywhere is only true where you happen to be
	# standing — and a figure that silently changes meaning is worse than no
	# figure. The station screen quotes it where it applies.
	var hull_note := "Your hull is the ship itself — this is your health.\nAt zero the run ends. Stations weld it back on, for credits."
	_hull.set_hull(Run.hp, Run.max_hp())
	_hint(_hull_label, hull_note)
	_hull.tooltip_text = Widgets.tip(hull_note)
	# Colour carries it, without the word. The cells already go green to ember to
	# red and the figure turns with them at the same third, so the label was a
	# third copy of a signal that was reading fine twice.
	_hull_text.text = "%d/%d" % [Run.hp, Run.max_hp()]
	_hull_text.add_theme_color_override("font_color",
		Color("#d4614f") if Run.hp < Run.max_hp() * 0.35 else UITheme.COLD)
	_hint(_hull_text, hull_note)

	var over := Run.heat - Run.heat_cap()
	# Same shape as hull: what heat IS, then what going past the cap costs you.
	# The second line changes when you are over because at that point the rule
	# has stopped being hypothetical and become a bill.
	var shed: int = maxi(1, Run.dissipation())
	# WHAT YOUR SHIP ADDS TO A VENT CARD. It used to say "vents %d a turn on
	# its own", which stopped being true the moment the end-of-turn shed was
	# deleted. Learned once from the gauge and true of every vent card you
	# own -- which is why the card face does not reprint it.
	var heat_note := "Weapons and systems run hot — heat is what they leave behind.\nPast %d it burns 1 hull a point at end of turn. Your vent cards shed %d more than they print." % [
		Run.heat_cap(), shed]
	if over > 0:
		heat_note = "Weapons and systems run hot — heat is what they leave behind.\n%d over the cap: %d hull at end of turn. Your vent cards shed %d more than they print." % [
			over, over, shed]
	_heat.setup(BoxGauge.Mode.HEAT, Run.heat_cap(), Run.heat)
	_heat.tooltip_text = Widgets.tip(heat_note)
	_hint(_heat_label, heat_note)
	_heat_text.text = ("%d — %d HULL" % [Run.heat, over]) if over > 0 \
		else "%d/%d" % [Run.heat, Run.heat_cap()]
	_heat_text.add_theme_color_override("font_color",
		UITheme.FLARE if over > 0 else UITheme.COLD)
	_hint(_heat_text, heat_note)

	_value(_scrap, str(Run.credits))
	# One sentence, in one place. See `CreditChit.WHAT_MONEY_IS`.
	_hint(_scrap, CreditChit.WHAT_MONEY_IS)
	_value(_fuel, str(Run.fuel))
	_hint(_fuel, "Fuel burns on every jump, priced by how far it is.\nRun dry between stations and the run ends adrift.")

## Where the second nav tab goes: the station if you are tied up at one, the
## sector if you are flying it. Read at click time so the label and the
## destination cannot disagree.
func _go_here() -> void:
	if Router.docked:
		Router.show_station()
	else:
		Router.show_sector()

## Make a readout able to receive the hover that shows a tooltip. Label defaults
## to MOUSE_FILTER_IGNORE, so setting tooltip_text alone is silently a no-op —
## the text is set and the tooltip never appears. Containers need the same
## treatment plus their children, or the hover falls through the gaps between
## words.
func _hintable(c: Control) -> Control:
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	for child in c.get_children():
		var cc := child as Control
		if cc != null:
			cc.mouse_filter = Control.MOUSE_FILTER_STOP
	return c

func _hint(c: Control, text: String) -> void:
	c.tooltip_text = Widgets.tip(text)
	for child in c.get_children():
		var cc := child as Control
		if cc != null:
			cc.tooltip_text = Widgets.tip(text)

func _value(row: HBoxContainer, text: String) -> void:
	var v := row.get_node_or_null("Value") as Label
	if v != null:
		v.text = text

## Hold a label at the width of the longest thing it will ever say.
##
## The two gauge figures are the only readouts on this bar whose text LENGTH
## changes with play: hull runs "8/24" to "120/120", and heat turns from "0/23"
## into "25 — 2 HULL" the moment you cross the cap. Both sit left of CREDITS and
## FUEL, so every one of those changes shoved the rest of the bar sideways — and
## the heat one does it exactly when a fight is going badly, which is the worst
## moment to move the numbers somebody is watching.
##
## Measured off the font rather than guessed, for the same reason AttrBlock
## measures its label column: a guess is a minimum, so guessing low leaves the
## label at its natural width and buys nothing.
func _reserve(l: Label, widest: String) -> void:
	var f := UITheme.pixel_font()
	l.custom_minimum_size = Vector2(f.get_string_size(
		widest, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x, 0)

func _divider() -> Control:
	var d := Panel.new()
	d.custom_minimum_size = Vector2(1, 14)
	d.add_theme_stylebox_override("panel", UITheme.flat(UITheme.LINE, Color(0, 0, 0, 0), 0, 0, 0))
	return d

func _tab(label: String, action: Callable) -> Button:
	return Widgets.button(label, action)

## `lock` is empty when the tab is available, and otherwise says WHY it is not.
## A greyed control that cannot explain itself reads as a bug; one that says
## "choose a chassis first" reads as the game waiting for you.
##
## The lit styleboxes are ADDED when active and REMOVED when not. Leaving them
## on and hoping the next state overwrites them is how a tab stays amber after
## you have left the page it belongs to.
func _state(b: Button, active: bool, lock: String, hint: String) -> void:
	# A tab that dev mode did not build is null, not hidden. Guarded here rather
	# than at each call site, because this is the one place they all pass through
	# and the next optional tab should not have to remember.
	if b == null:
		return
	var locked := lock != ""
	b.disabled = locked or active
	b.tooltip_text = Widgets.tip(lock if locked else hint)
	if active and not locked:
		# Lit, not greyed: an active tab is a statement, not an unavailable option.
		b.add_theme_stylebox_override("normal", UITheme.bevel(Color("#4a2a0c"), 3, 5))
		b.add_theme_stylebox_override("disabled", UITheme.bevel(Color("#4a2a0c"), 3, 5))
		b.add_theme_color_override("font_disabled_color", UITheme.HOT)
	else:
		b.remove_theme_stylebox_override("normal")
		b.remove_theme_stylebox_override("disabled")
		b.remove_theme_color_override("font_disabled_color")


## ONE MANUFACTURER'S SET BONUS, LIT. Sixteen pixels square, which is not a
## rounded number -- it is the size the build plan's Phase 9 gate names. "Every
## emblem legible at 16px" was written as a test OF this chip, and until now the
## chip it was written for did not exist, so the gate had never been run against
## anything.
##
## The bonuses have been live in the sim the whole time: `Run.has_set` decides
## whether Solari plasma gains damage, whether Cygnet drones act twice, whether
## Redline negates the first attack. A player could be three modules into an
## identity, having it applied to every card they play, and be told nowhere.
## The only place set bonuses appeared was the chassis picker, which is the one
## screen you are not on while it matters.
class SetChip extends Control:
	const PLATE := 16.0
	## Seconds for one full breath at the top tier.
	const PULSE := 1.6

	var manufacturer: StringName = &""
	var mark: Color = UITheme.CHILL
	var field: Color = UITheme.PANEL
	## HOW MANY YOU HAVE, not which tier you reached. The chip is a tracker:
	## one part shows the mark greyed with one pip, three lights it, five sets
	## it breathing. Reading the count rather than a tier means the pips can say
	## "two of the three you need" instead of only ever saying "earned".
	var count: int = 0
	## How many of the count are PARTS. The panel names the hull's share, and
	## only the caller knows it.
	var fitted: int = 0

	var _t: float = 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(PLATE, PLATE)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		set_process(false)

	## ONLY THE TOP TIER TICKS. A chip that redraws every frame to show a state
	## that is not changing is the same waste as the bar rebuilding itself, and
	## this bar has a header about exactly that.
	func setup(n: int, parts: int = 0) -> void:
		count = n
		fitted = parts
		set_process(n >= 5)
		_t = 0.0
		# THE TRIGGER, not the content. Godot only asks for a tooltip when this
		# is non-empty, and `_make_custom_tooltip` replaces it with a panel --
		# but the plain form is set rather than a placeholder so a failure to
		# build the panel degrades to something readable. Same contract the perk
		# corner uses.
		tooltip_text = Widgets.tip(Widgets.set_tip(manufacturer, n, parts))
		queue_redraw()

	func _make_custom_tooltip(_for_text: String) -> Object:
		return Widgets.set_readout(manufacturer, count, fitted)

	func _process(delta: float) -> void:
		_t = fmod(_t + delta, PULSE)
		queue_redraw()

	func _draw() -> void:
		var lit := count >= 3
		# The breath. A cosine so it dwells at both ends instead of sweeping
		# evenly through -- an even ramp reads as a flicker at this size.
		var glow := 0.0
		if count >= 5:
			glow = (1.0 - cos(_t / PULSE * TAU)) * 0.5
		var ink := mark if lit else mark.darkened(0.55)
		if count >= 5:
			ink = ink.lerp(mark.lightened(0.45), glow)
		var bg := field if lit else field.darkened(0.35)

		var b := Rect2(Vector2.ZERO, Vector2(PLATE, PLATE))
		draw_rect(b, bg, true)
		draw_rect(b, ink.darkened(0.3), false, 1.0)
		# AT SCALE 1. draw_emblem's offsets are authored in whole pixels around a
		# centre, and the marks span nine to ten of them -- so a sixteen-pixel
		# plate is the emblem with three pixels of air, and any other scale is
		# the emblem on half-pixel boundaries.
		CardView.draw_emblem(self, manufacturer, Vector2(PLATE, PLATE) * 0.5,
			1.0, ink, bg)
		# The count, in the margin the emblem leaves. Every mark spans nine or
		# ten pixels of the sixteen, centred -- so columns 13 and 14 are free on
		# every one of the seven. Bottom-up, so the stack grows as the set does.
		for i in mini(count, 5):
			draw_rect(Rect2(13.0, PLATE - 3.0 - i * 2.0, 2.0, 1.0), ink, true)
