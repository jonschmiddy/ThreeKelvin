class_name HudBar
extends PanelContainer

## Persistent top bar: navigation, hull, heat, economy, and live set-bonus
## progress.
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

var _row: HBoxContainer
var _built: bool = false

var _tab_ship: Button
var _tab_sector: Button
var _tab_chart: Button
var _tab_cards: Button
var _tab_parts: Button
var _tab_history: Button
## Only ever visible in a party. Built unconditionally, because a party can form
## before the HUD exists and can also outlive it — hiding a built button is one
## state to keep in step, and rebuilding the bar when somebody joins is a whole
## screen redrawn for one tab.
var _tab_party: Button
## The archive. Always built and always available: what you have read survives
## the ship, so unlike SHIP and PARTY there is no run state that makes reading a
## page wrong. It greys during a fight anyway — see refresh().
var _tab_archive: Button

var _hull_label: Label
var _hull: BoxGauge
var _hull_text: Label
var _heat_label: Label
var _heat: BoxGauge
var _heat_text: Label
var _scrap: HBoxContainer
var _fuel: HBoxContainer
var _materials: HBoxContainer
## What _mat_budget() answered when the strip was last folded -- see
## _refresh_materials for why a moved budget refolds.
var _mat_budget_used := -1.0
## Which materials the row currently holds a readout for. Rebuilt only when this
## changes; a count moving is a text update.
var _mat_ids: Array = []

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
	_row.add_theme_constant_override("separation", 6)
	_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip.add_child(_row)
	_build()
	Sig.resources_changed.connect(refresh)
	Sig.ship_changed.connect(refresh)
	Sig.screen_changed.connect(refresh)
	Sig.dev_mode_changed.connect(_rebuild)
	# The material fold is budgeted against the row's own width, so the row
	# changing width has to re-ask -- without this, shrinking the window keeps
	# a fold made for the wide bar and clips the tabs until the next jump.
	# The 24px guard in _refresh_materials keeps a resize storm from
	# rebuilding the strip once per pixel.
	_row.resized.connect(_refresh_materials)
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
	# Ship | Sector | Starchart. The page you are on is lit rather than merely
	# disabled, so the nav says where you are as well as where you can go.
	_tab_ship = _tab("SHIP", func() -> void: Router.show_ship())
	_row.add_child(_tab_ship)
	_tab_sector = _tab("SECTOR", func() -> void: Router.show_sector())
	_row.add_child(_tab_sector)
	_tab_chart = _tab("STARCHART", func() -> void: Router.show_starchart())
	_row.add_child(_tab_chart)

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
	# The over-cap form is the long one and it is the one that appears mid-fight,
	# which is the worst possible moment for the whole bar to jump sideways.
	_reserve(_heat_text, "00 — 00 HULL")
	_row.add_child(_hintable(_heat_text))

	_row.add_child(_divider())
	# Every readout on this bar explains itself on hover. The bar is where the
	# whole economy is stated and none of it is self-evident: scrap is one
	# currency competing with itself, fuel is priced by chart distance, and heat
	# is a second health bar you are allowed to spend.
	_scrap = Widgets.stat("credits", "")
	_row.add_child(_hintable(_scrap))
	# Materials are the one part of this bar whose CHILD COUNT is not fixed —
	# one readout per material held, none for a material you have none of,
	# because the bar is narrow and empty counters cost the space the ones that
	# matter are read in.
	#
	# So they get their own container and their own rebuild, and it fires only
	# when the SET of materials changes rather than when a count does. That keeps
	# the thing this class exists to guarantee: the tabs and the frame counter
	# are never rebuilt, whatever the economy is doing.
	_materials = HBoxContainer.new()
	_materials.add_theme_constant_override("separation", 10)
	_row.add_child(_materials)
	# Materials stay on the scrap side of this rule: both are things you are
	# carrying. Fuel is not — it is the clock — so it gets its own compartment.
	_row.add_child(_divider())
	_fuel = Widgets.stat("fuel", "")
	_row.add_child(_hintable(_fuel))

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_row.add_child(sp)

	# Card gallery, top right, away from the three tabs that are part of the game.
	# It never greys out during combat: looking at the catalog changes nothing,
	# and mid-fight is exactly when you want to check what a card was supposed
	# to say. It DOES grey while choosing a chassis, which is the one moment
	# there is no run to come back to.
	# Dev only. Every card in the game on one page is an authoring view, and a
	# player who reads it has been handed the answer to a game about finding out
	# what things do. Not built at all rather than hidden — see DevMode.
	if DevMode.enabled:
		_tab_cards = _tab("CARDS", func() -> void: Router.show_cards())
		_row.add_child(_tab_cards)
		# Its sibling. A card is what a module DOES and the module is the thing
		# you actually find, pack and bolt on — two catalogues, because they
		# answer two different questions and one page showing both would be a
		# list of cards with a picture beside each.
		_tab_parts = _tab("MODULES", func() -> void: Router.show_modules())
		_row.add_child(_tab_parts)
	# Beside the three tabs that are part of the game rather than beside the two
	# readouts, because who you are flying with is a thing you act on: it is
	# where you learn that somebody is four shells deeper than you and running
	# hot. Hidden entirely when there is no party — a tab that is permanently
	# greyed out in the solo game is a tab that teaches the player to ignore it.
	_tab_party = _tab("PARTY", func() -> void: Router.show_party())
	_row.add_child(_tab_party)

	# The archive sits with the record and the catalog: three things you READ
	# rather than three places you go, and none of them changes the run.
	_tab_archive = _tab("ARCHIVE", func() -> void: Router.show_archive())
	_row.add_child(_tab_archive)

	# The record sits beside the catalog: both are things you read rather than
	# places you go, and neither changes the run.
	_tab_history = _tab("HISTORY", func() -> void: Router.show_history())
	_row.add_child(_tab_history)

	# THE FRAME COUNTER IS GONE, and the bar is the better for the room.
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
	# Combat happens in the sector, so the tab stays lit through a fight rather
	# than greying out as if you had left.
	_state(_tab_sector, Router.current is SectorScreen or fighting, choose_lock,
		"What is around you.")
	_state(_tab_chart, Router.current is StarchartScreen, lock, "Where to go next.")
	_state(_tab_parts, Router.current is ModuleGalleryScreen, choose_lock,
		"Every part in the game. Dev only.")
	_state(_tab_cards, Router.current is CardGalleryScreen, choose_lock,
		"Every card in the game.")
	_state(_tab_history, Router.current is HistoryScreen, choose_lock,
		"Every run you have finished.")
	# Locked during a fight for the same reason SHIP is: it is a page you read
	# while deciding where to go, and the decision it feeds does not exist while
	# something is shooting at you. The convoy strip covers the fight.
	# Greys while choosing a chassis for the same reason CARDS does — there is no
	# run to come back to — but NOT during a fight. Mid-fight is exactly when a
	# player looks something up, and reading a fifty-year-old manifest changes
	# nothing about the frigate in front of them.
	_state(_tab_archive, Router.current is ArchiveScreen, choose_lock,
		"What you have recovered and read.")
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
	_refresh_materials()
	_value(_fuel, str(Run.fuel))
	_hint(_fuel, "Fuel burns on every jump, priced by how far it is.\nRun dry between stations and the run ends adrift.")

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

## The material strip's fallback budget, for the one refresh that can run
## before the bar has been laid out and measured. Every later fold uses the
## row's own arithmetic -- see _mat_budget().
const MAT_BUDGET := 190.0

## How much of the bar the material strip may spend: whatever is left after
## every other readout and tab has taken its minimum. The strip is the only
## part of this bar whose child count follows the economy, and the economy
## grew: a hold carrying ballast sand, ledger stock and four more pushed
## ARCHIVE and HISTORY clean off the right edge of the window, which is worse
## than any count being hidden -- the tabs are navigation, and a reading is a
## tooltip away. Computed rather than constant because the neighbours move:
## the dev tabs are 120px that only exist with the switch on, and a constant
## tuned for either mode overflows the other.
func _mat_budget() -> float:
	if _row == null or _row.size.x <= 0.0:
		return MAT_BUDGET
	var sep := 6.0
	var rest := 0.0
	for c in _row.get_children():
		if c == _materials:
			continue
		var ctl := c as Control
		if ctl == null or not ctl.visible:
			continue
		rest += ctl.get_combined_minimum_size().x + sep
	# The slack absorbs what this pass cannot see coming: CREDITS growing a
	# digit, the heat figure taking its over-cap form. Both are small and both
	# already reserve where they can -- see _reserve().
	return maxf(0.0, _row.size.x - rest - 24.0)

## One readout per material held, until they stop fitting. Rebuilt only when
## the SET changes — picking up a material you had none of, or spending the
## last of one. A count going from 3 to 2 is a text write, which is the common
## case by a wide margin. Everything past the budget is one "+N" readout whose
## tooltip carries the names and counts it folded.
func _refresh_materials() -> void:
	var stock := Run.material_stock()
	var ids: Array = []
	for s in stock:
		ids.append(s.id)
	var budget := _mat_budget()
	# Refold on a moved budget as well as a changed set: the first refresh of
	# a restored run happens before the bar has a size, so its fold was made
	# against the fallback and has to be remade against the measurement.
	if ids != _mat_ids or absf(budget - _mat_budget_used) > 24.0:
		_mat_ids = ids
		_mat_budget_used = budget
		Widgets.clear(_materials)
		var f := UITheme.pixel_font()
		# Row widths first, because whether the "+N" readout exists decides
		# how much room the named ones may spend: the chip is a row like any
		# other, and a fold that never charged for it clipped the tabs in
		# exactly the narrow band this function exists to close.
		var widths: Array[float] = []
		var total := 0.0
		for s in stock:
			# A label, a count and the box's own separation; the count is
			# measured at two digits so a 9 becoming a 10 cannot move the
			# fold.
			var w: float = f.get_string_size("%s 00" % str(s.name).to_upper(),
				HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x + 16.0
			widths.append(w)
			total += w
		if total > budget:
			budget -= f.get_string_size("+ 00", HORIZONTAL_ALIGNMENT_LEFT, -1,
				UITheme.FS_SMALL).x + 16.0
		var used := 0.0
		var shown := 0
		for s in stock:
			# Even the FIRST readout folds when it does not fit -- with the
			# dev tabs up the leftover can be smaller than one long name, and
			# a lone "+3" with the names a hover away beats HISTORY half off
			# the window.
			if used + widths[shown] > budget:
				break
			used += widths[shown]
			shown += 1
			var tier := StringName(MaterialTable.by_id(s.id).get("tier", &"common"))
			var row := Widgets.stat(str(s.name).to_lower(), str(s.count),
				UITheme.tier_colour(tier))
			row.name = "mat_" + String(s.id)
			_materials.add_child(_hintable(row))
		if shown < stock.size():
			var more := Widgets.stat("+", str(stock.size() - shown))
			more.name = "mat_overflow"
			_materials.add_child(_hintable(more))
	for s in stock:
		var row2 := _materials.get_node_or_null("mat_" + String(s.id)) as HBoxContainer
		if row2 == null:
			continue
		_value(row2, str(s.count))
		var d := MaterialTable.by_id(s.id)
		_hint(row2, "%s\n%s" % [str(s.name), str(d.get("text", ""))])
	# The folded readouts keep their counts current through the tooltip, which
	# is the only place they are stated.
	var over := _materials.get_node_or_null("mat_overflow") as HBoxContainer
	if over != null:
		var lines: PackedStringArray = ["ALSO CARRYING"]
		var listed := 0
		for s in stock:
			if _materials.get_node_or_null("mat_" + String(s.id)) == null:
				lines.append("%s %d" % [str(s.name), int(s.count)])
				listed += 1
		_value(over, str(listed))
		_hint(over, "\n".join(lines))

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
