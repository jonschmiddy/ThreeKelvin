class_name HudBar
extends PanelContainer

## Persistent top bar: navigation, hull, heat, economy, frame, and live set-bonus
## progress.
##
## SHIP and MAP live here rather than inside each screen, so they are in the same
## place everywhere. SHIP greys out during combat instead of disappearing — you
## cannot refit mid-fight, and a button that says so beats one that vanishes.
##
## BUILT ONCE, UPDATED IN PLACE. It used to free every child and remake them on
## each of three signals, which cost more than it looks:
##
## - The frame counter was recreated blank and stayed blank until its next
##   quarter-second sample, so any refit made the FPS readout blink out.
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
var _tab_history: Button

var _hull_label: Label
var _hull: BoxGauge
var _hull_text: Label
var _heat_label: Label
var _heat: BoxGauge
var _heat_text: Label
var _scrap: HBoxContainer
var _fuel: HBoxContainer
var _materials: HBoxContainer
## Which materials the row currently holds a readout for. Rebuilt only when this
## changes; a count moving is a text update.
var _mat_ids: Array = []

func _ready() -> void:
	add_theme_stylebox_override("panel", UITheme.bevel(UITheme.PANEL, 5, 6))
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 10)
	add_child(_row)
	set_process(true)
	_build()
	Sig.resources_changed.connect(refresh)
	Sig.ship_changed.connect(refresh)
	Sig.screen_changed.connect(refresh)
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

	# Card gallery, top right beside the frame rate — the two development
	# readouts together, away from the three tabs that are part of the game.
	# It never greys out during combat: looking at the catalog changes nothing,
	# and mid-fight is exactly when you want to check what a card was supposed
	# to say. It DOES grey while choosing a chassis, which is the one moment
	# there is no run to come back to.
	_tab_cards = _tab("CARDS", func() -> void: Router.show_cards())
	_row.add_child(_tab_cards)
	# The record sits beside the catalog: both are things you read rather than
	# places you go, and neither changes the run.
	_tab_history = _tab("HISTORY", func() -> void: Router.show_history())
	_row.add_child(_tab_history)
	_row.add_child(_divider())

	# Frame rate, far right. Lives on the HUD rather than on the chart because
	# the chart is only where the cost is currently obvious — knowing what the
	# rest of the game runs at is the comparison that makes the number mean
	# anything.
	_fps = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	_row.add_child(_fps)
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
	_state(_tab_cards, Router.current is CardGalleryScreen, choose_lock,
		"Every card in the game.")
	_state(_tab_history, Router.current is HistoryScreen, choose_lock,
		"Every run you have finished.")

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
	_hull.tooltip_text = hull_note
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
	var heat_note := "Weapons and systems run hot — heat is what they leave behind.\nPast %d it burns 1 hull a point at end of turn. Vents %d a turn on its own." % [
		Run.heat_cap(), shed]
	if over > 0:
		heat_note = "Weapons and systems run hot — heat is what they leave behind.\n%d over the cap: %d hull at end of turn. Vents %d a turn on its own." % [
			over, over, shed]
	_heat.setup(BoxGauge.Mode.HEAT, Run.heat_cap(), Run.heat)
	_heat.tooltip_text = heat_note
	_hint(_heat_label, heat_note)
	_heat_text.text = ("%d — %d HULL" % [Run.heat, over]) if over > 0 \
		else "%d/%d" % [Run.heat, Run.heat_cap()]
	_heat_text.add_theme_color_override("font_color",
		UITheme.FLARE if over > 0 else UITheme.COLD)
	_hint(_heat_text, heat_note)

	_value(_scrap, str(Run.credits))
	_hint(_scrap, "Credits are the only currency.\nRepairs, upgrades and purchases all come out of the same balance.")
	_refresh_materials()
	_value(_fuel, str(Run.fuel))
	_hint(_fuel, "Fuel burns on every jump, priced by how far it is.\nRun dry between stations and the run ends adrift.")

## Sampled a few times a second rather than every frame: a counter that updates
## sixty times a second is unreadable, and averaging over a short window is what
## makes a stutter visible as a dip instead of a blur.
var _fps: Label
var _fps_t: float = 0.0

func _process(delta: float) -> void:
	if _fps == null:
		return
	_fps_t += delta
	if _fps_t < 0.25:
		return
	_fps_t = 0.0
	var f := Engine.get_frames_per_second()
	var col := UITheme.COLD
	if f < 30:
		col = Color("#c8503c")
	elif f < 50:
		col = Color("#b8923f")
	_fps.text = "%d FPS" % f
	_fps.add_theme_color_override("font_color", col)

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
	c.tooltip_text = text
	for child in c.get_children():
		var cc := child as Control
		if cc != null:
			cc.tooltip_text = text

## One readout per material held. Rebuilt only when the SET changes — picking up
## a material you had none of, or spending the last of one. A count going from 3
## to 2 is a text write, which is the common case by a wide margin.
func _refresh_materials() -> void:
	var stock := Run.material_stock()
	var ids: Array = []
	for s in stock:
		ids.append(s.id)
	if ids != _mat_ids:
		_mat_ids = ids
		for c in _materials.get_children():
			_materials.remove_child(c)
			c.queue_free()
		for s in stock:
			var row := Widgets.stat(str(s.name).to_lower(), str(s.count),
				DB.material_colour(s.id))
			row.name = "mat_" + String(s.id)
			_materials.add_child(_hintable(row))
	for s in stock:
		var row2 := _materials.get_node_or_null("mat_" + String(s.id)) as HBoxContainer
		if row2 == null:
			continue
		_value(row2, str(s.count))
		var d := DB.material(s.id)
		_hint(row2, "%s\n%s" % [str(s.name), str(d.get("text", ""))])

func _value(row: HBoxContainer, text: String) -> void:
	var v := row.get_node_or_null("Value") as Label
	if v != null:
		v.text = text

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
	var locked := lock != ""
	b.disabled = locked or active
	b.tooltip_text = lock if locked else hint
	if active and not locked:
		# Lit, not greyed: an active tab is a statement, not an unavailable option.
		b.add_theme_stylebox_override("normal", UITheme.bevel(Color("#4a2a0c"), 3, 5))
		b.add_theme_stylebox_override("disabled", UITheme.bevel(Color("#4a2a0c"), 3, 5))
		b.add_theme_color_override("font_disabled_color", UITheme.HOT)
	else:
		b.remove_theme_stylebox_override("normal")
		b.remove_theme_stylebox_override("disabled")
		b.remove_theme_color_override("font_disabled_color")
