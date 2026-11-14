class_name HudBar
extends PanelContainer

## Built once, updated in place: remaking children flickered tabs and doubled the bar's width.
## Why: docs/why/HudBar.md#built-once

## The gap between readouts must exceed the gap inside one, or labels bind to the wrong number.
## Why: docs/why/HudBar.md#readout-gaps
const STAT_GAP := 4
const ECON_GAP := 8

## Wide enough to read as a break, narrow enough that CARDS stays in the bar's left half.
const MID_GAP := 24
## The fuel bar's empty well.
const FUEL_WELL := Color("#10161f")

var _row: HBoxContainer
var _built: bool = false

var _tab_sector: Button
## Tab names follow Jon: SECTOR for the map; LOCAL reads COMBAT or STATION; berth greys it.
## Why: docs/why/HudBar.md#nav-tabs
var _tab_system: Button
var _tab_chart: Button
var _tab_cards: Button
var _tab_parts: Button
## Built unconditionally, as a party can form before the HUD exists or outlive it.
var _tab_party: Button
## QUESTS (Jon, Oct 22, design A) never shows a count, so it never changes size.
var _tab_quests: Button
## COMMS was asked for by playtester Jeremy (Oct 23); the row measured 702 of 932 px with it.
## With DATA (Nov 4) it reads 750 (880 dev); the worst case wants 927, five pixels to spare.
## Why: docs/why/HudBar.md#nav-tabs
var _tab_comms: Button

var _hull_label: Label
var _hull: BoxGauge
var _hull_text: Label
var _heat_label: Label
var _heat: BoxGauge
var _heat_text: Label
var _scrap: HBoxContainer
var _fuel: HBoxContainer
## DATA (science, pick 1A): what your readings are worth, spent only at a lab.
## Last in the money group, after FUEL, shown from launch at 0 (plan call 9) so
## the bar never changes shape the first time a reading pays.
var _data: HBoxContainer
## The tank as a bar between FUEL and "23/45" (Jon: "warn:A"). Drawn, flat and
## not a control anyone presses; see `FuelBar`.
var _fuel_bar: FuelBar
## The goal and the next step, under the bar (`GoalLine`).
var goal: GoalLine = null

func _ready() -> void:
	add_theme_stylebox_override("panel", UITheme.bevel(UITheme.PANEL, 5, 6))
	# The bar sits in a clipping wrapper with zero minimum, so it cannot widen every screen.
	# Why: docs/why/HudBar.md#bar-width
	var clip := Control.new()
	clip.clip_contents = true
	clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip.custom_minimum_size = Vector2(0, ROW_H)
	add_child(clip)

	_row = HBoxContainer.new()
	# Row separation is five, not ten: twenty children made the gaps alone two hundred pixels.
	# Why: docs/why/HudBar.md#bar-width
	_row.add_theme_constant_override("separation", 5)
	_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip.add_child(_row)
	_build()
	# The goal line sits in the bar's column after the screens, under the escape menu.
	goal = GoalLine.new()
	get_parent().add_child.call_deferred(goal)
	Sig.resources_changed.connect(refresh)
	Sig.ship_changed.connect(refresh)
	Sig.screen_changed.connect(refresh)
	Sig.dev_mode_changed.connect(_rebuild)
	refresh()

## The dev switch decides which tabs exist, so the bar is rebuilt, clearing the old tabs first.
## Why: docs/why/HudBar.md#rebuild
const ROW_H := 20

func _rebuild() -> void:
	Widgets.clear(_row)
	_build()
	refresh()

func _build() -> void:
	# Optional tab fields are forgotten first: a freed button is rejected at a typed argument.
	# Why: docs/why/HudBar.md#freed-tab-fields
	_tab_cards = null
	_tab_parts = null

	# One tab, two names (STATION or LOCAL), set at click; SHIP and ARCHIVE tabs cut (Jon).
	# Why: docs/why/HudBar.md#nav-tabs
	_tab_sector = _tab("STATION", _go_here)
	# (greyed at the berth it takes no press, but a click is a try to leave)
	_tab_sector.gui_input.connect(func(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT \
				and _tab_sector.disabled and _at_berth():
			Router.cast_off())
	# Hold the tab at the longer word's width, measured after `add_child` for the theme font.
	# Why: docs/why/HudBar.md#nav-tabs
	_row.add_child(_tab_sector)
	_tab_sector.custom_minimum_size = Vector2(
		_tab_sector.get_combined_minimum_size().x, 0)
	_tab_system = _tab("SECTOR", func() -> void: Router.show_system())
	_row.add_child(_tab_system)
	_tab_chart = _tab("STARCHART", func() -> void: Router.show_starchart())
	_row.add_child(_tab_chart)
	_tab_quests = _tab("QUESTS", func() -> void: QuestPanel.toggle())
	_row.add_child(_tab_quests)
	_tab_comms = _tab("COMMS", func() -> void: CommsPanel.toggle())
	_tab_comms.name = "Comms"
	_row.add_child(_tab_comms)
	# Hidden when there is no party; built unconditionally, as a party can form before the HUD.
	_tab_party = _tab("PARTY", func() -> void: Router.show_party())
	_row.add_child(_tab_party)

	_row.add_child(_divider())

	# Hull reads as ten cells because the useful question is what fraction is left.
	_hull_label = UITheme.body("HULL", UITheme.COLD, UITheme.FS_SMALL)
	_row.add_child(_hintable(_hull_label))
	_hull = BoxGauge.new()
	_row.add_child(_hull)
	# The figure answers what a repair costs; the cells answer how close to dying.
	_hull_text = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	_reserve(_hull_text, "000/000")
	_row.add_child(_hintable(_hull_text))

	# A rule between readouts: hull and heat side by side read as one long gauge.
	_row.add_child(_divider())

	# Heat reads as countable cells; the number beside it names the cost when
	# you are over cap, because that is the only time the number matters.
	_heat_label = UITheme.body("HEAT", UITheme.COLD, UITheme.FS_SMALL)
	_row.add_child(_hintable(_heat_label))
	_heat = BoxGauge.new()
	_row.add_child(_heat)
	_heat_text = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	# No width is reserved for heat: the economy is pinned right, so the spacer absorbs growth.
	# Why: docs/why/HudBar.md#heat-width
	_row.add_child(_hintable(_heat_text))

	# No set-bonus chips here: the ship screen already shows them; `SetChip` stays for it.

	# The catalogues sit in a fixed gap: the 1:3 spacer ratio was measured to move nothing.
	# Why: docs/why/HudBar.md#catalogue-gap
	if DevMode.enabled:
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(MID_GAP, 0)
		_row.add_child(gap)

	# Catalogues are dev only and not built otherwise; they stay live in combat.
	# Why: docs/why/HudBar.md#dev-catalogues
	if DevMode.enabled:
		_tab_cards = _tab("CARDS", func() -> void: Router.show_cards())
		_row.add_child(_tab_cards)
		# Cards and modules are two catalogues because they answer two different questions.
		_tab_parts = _tab("MODULES", func() -> void: Router.show_modules())
		_row.add_child(_tab_parts)

	# All the slack is here, so the economy stays pinned to the right-hand end.
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_row.add_child(sp)

	# Economy readouts group by proximity (four in, twelve between), not by dividers.
	# Why: docs/why/HudBar.md#economy-readouts
	var econ := HBoxContainer.new()
	econ.add_theme_constant_override("separation", ECON_GAP)
	_scrap = Widgets.stat("credits", "")
	_scrap.add_theme_constant_override("separation", STAT_GAP)
	econ.add_child(_hintable(_scrap))
	# No cargo here, and fuel sits inside `econ`, or readouts bind to the wrong pair.
	# DATA is the one other pool: it only comes from places, takes no hold room, never sells.
	# Why: docs/why/HudBar.md#economy-readouts
	_fuel = Widgets.stat("fuel", "")
	_fuel.add_theme_constant_override("separation", STAT_GAP)
	# The fuel figure is held at the width of `45/45` so the bar does not move as the tank drains.
	_fuel_bar = FuelBar.new()
	_fuel.add_child(_fuel_bar)
	_fuel.move_child(_fuel_bar, 1)
	_reserve(_fuel.get_node("Value") as Label, "%d/%d" % [Run.FUEL_TANK, Run.FUEL_TANK])
	econ.add_child(_hintable(_fuel))
	# DATA LAST, after the clock.
	# Why: docs/why/HudBar.md#data-last
	_data = Widgets.stat("data", "")
	_data.add_theme_constant_override("separation", STAT_GAP)
	_reserve(_data.get_node("Value") as Label, "00")
	econ.add_child(_hintable(_data))
	_row.add_child(econ)

	# The run history and frame counter are gone: the counter was cut first when the row ran out.
	# Why: docs/why/HudBar.md#removed-readouts
	_built = true

func refresh() -> void:
	if not _built or Run.hull == null:
		return


	# (and until the fight has handed over: its screen still up after the last
	# kill, `Router.fight_up` -- a tab there raced the hand-off to LOCAL)
	var fighting := Router.in_combat() or Router.fight_up()
	# Choosing a chassis locks the bar: a SHIP tab before launch would change a hull behind it.
	var choosing := Router.current is ChassisSelect
	var choose_lock := "Choose a chassis first." if choosing else ""
	var lock := choose_lock if choosing else ("Locked during combat." if fighting else "")

	# Combat outranks the other two tab states; the clicked tab lights at once (`lit_rank`).
	# Why: docs/why/HudBar.md#tab-lighting
	var lit := ZoomLadder.lit_rank()
	# Docked, LOCAL is shut and greyed (Jon, Oct 27, after Jeremy), as UNDOCK is the only way out.
	# Why: docs/why/HudBar.md#berth-tab
	var at_berth := Router.docked and not fighting and lit == ZoomLadder.STATION
	var here_lock := choose_lock
	if at_berth and here_lock == "":
		here_lock = Router.DOCKED_LINE
	if fighting:
		_tab_sector.text = "COMBAT"
	elif Router.docked and lit != ZoomLadder.LOCAL and not at_berth:
		_tab_sector.text = "STATION"
	else:
		_tab_sector.text = "LOCAL"
	var here_hint := "Your ship, side on, where you are."
	if fighting:
		here_hint = "The fight you are in."
	elif _tab_sector.text == "STATION":
		here_hint = "The station you are docked at."
	_state(_tab_sector,
		lit == ZoomLadder.LOCAL or lit == ZoomLadder.STATION or fighting,
		here_lock, here_hint)
	# In a binary the line is said of both stars (ruling 20; Jon, Nov 1: call it Binary).
	# Why: docs/why/HudBar.md#binary-wording
	var here_n := Run.here()
	var two := here_n != null and here_n.twin and MapGen.twin_ok(here_n)
	_state(_tab_system, lit == ZoomLadder.MAP, lock,
		"This binary system's stars, what orbits them, and any threats nearby." if two
		else "This system's star, what orbits it, and any threats nearby.")
	_state(_tab_chart, lit == ZoomLadder.CHART, lock, "Where to go next.")
	# (open mid-fight: reading changes nothing out there; its SHOW ON STARCHART
	# waits for the fight to end)
	_state_toggle(_tab_quests, QuestPanel.is_open(), choose_lock,
		"The quests you have signed, where they are and what they pay.")
	_state_toggle(_tab_comms, CommsPanel.is_open(), choose_lock,
		"Everything A.S.H. has said this run. Play her lines again.")
	_state(_tab_parts, Router.current is ModuleGalleryScreen, choose_lock,
		"Every part in the game. Dev only.")
	_state(_tab_cards, Router.current is CardGalleryScreen, choose_lock,
		"Every card in the game.")
	_tab_party.visible = Net.is_networked()
	_state(_tab_party, Router.current is PartyScreen, lock,
		"Everyone you are flying with.")

	# Tooltips say what a gauge is first; no repair rate, as it is priced per station.
	# Why: docs/why/HudBar.md#tooltips
	var hull_note := "At zero the ship is lost; a station repairs it for credits."
	# WHAT THE FIGHT HAS SHOWN SO FAR, while a turn plays out on screen: the
	# hull drops as each shot lands rather than on the click (combat polish).
	var hp := Run.hp if SectorScreen.shown_hull < 0 else SectorScreen.shown_hull
	var heat := Run.heat if SectorScreen.shown_heat < 0 else SectorScreen.shown_heat
	# AND WHAT AN EVENT'S RESULT IS STILL FLYING UP HERE (`OutcomeRow.held`, look
	# C): the number changes when its flight lands, not before
	hp = int(OutcomeRow.held.get("hp", hp))
	heat = int(OutcomeRow.held.get("heat", heat))
	_hull.set_hull(hp, Run.max_hp())
	_hint(_hull_label, hull_note)
	_hull.tooltip_text = Widgets.tip(hull_note)
	# Colour carries it without the word: the label was a third copy of a working signal.
	_hull_text.text = "%d/%d" % [hp, Run.max_hp()]
	_hull_text.add_theme_color_override("font_color",
		UITheme.LEAVE if hp < Run.max_hp() * 0.35 else UITheme.COLD)
	_hint(_hull_text, hull_note)

	var over := heat - Run.heat_cap()
	# Heat's second line changes when over cap, since then the rule has become a bill.
	var shed: int = maxi(1, Run.dissipation())
	# The tooltip once said vents on its own, false since the end-of-turn shed was deleted.
	var heat_note := "Past %d, each point over burns 1 hull at the end of the turn." % Run.heat_cap()
	if over > 0:
		heat_note = "You are %d over the cap, so %d hull burns at the end of the turn." % [over, over]
	_heat.setup(BoxGauge.Mode.HEAT, Run.heat_cap(), heat)
	_heat.tooltip_text = Widgets.tip(heat_note)
	_hint(_heat_label, heat_note)
	_heat_text.text = ("%d — %d HULL" % [heat, over]) if over > 0 \
		else "%d/%d" % [heat, Run.heat_cap()]
	_heat_text.add_theme_color_override("font_color",
		UITheme.FLARE if over > 0 else UITheme.COLD)
	_hint(_heat_text, heat_note)

	_value(_scrap, str(int(OutcomeRow.held.get("credits", Run.credits))))
	# One sentence each, in one place (`CreditChit`). CREDITS says both: the two never trade.
	_hint(_scrap, "%s\n%s" % [CreditChit.WHAT_MONEY_IS, CreditChit.WHAT_DATA_IS])
	# (a reading counting up holds the figure back: `OutcomeRow.held`)
	_value(_data, str(int(OutcomeRow.held.get("data", Run.data))))
	_hint(_data, CreditChit.WHAT_DATA_IS)
	# Amber at a third of the tank (where the hint fires); red if the dearest jumps would empty it.
	var state := fuel_state()
	# (an outcome counting up holds the figure back: `OutcomeRow.held`)
	var shown := int(OutcomeRow.held.get("fuel", Run.fuel))
	_value(_fuel, "%d/%d" % [shown, Run.fuel_cap()])
	var fv := _fuel.get_node_or_null("Value") as Label
	if fv != null:
		fv.add_theme_color_override("font_color", FUEL_INK[state])
	_fuel_bar.set_tank(shown, Run.fuel_cap(), state)
	_hint(_fuel, "Every jump burns some; run dry between stations and the run ends.")

## 0 the tank is fine, 1 low (a third or less), 2 critical (under two of the
## dearest jump on offer). Public for the harnesses.
static func fuel_state() -> int:
	if Run.fuel_critical():
		return 2
	return 1 if Run.fuel_low() else 0

## The figure's colour in each state: the bar's own ice, amber, the hull's red.
const FUEL_INK: Array[Color] = [UITheme.ICE, UITheme.WARN, Color("#d4614f")]

## Read at click time so the label and destination cannot disagree (UNDOCK only, Jon, Oct 27).
func _go_here() -> void:
	if _at_berth():
		Router.cast_off()
	elif Router.docked:
		Router.show_station()
	else:
		Router.show_local()


## On the station itself, docked: where the first tab reads LOCAL, greyed.
func _at_berth() -> bool:
	return Router.docked and ZoomLadder.lit_rank() == ZoomLadder.STATION

## Label ignores the mouse by default, so `tooltip_text` alone is silently a no-op.
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

## Gauge figures change length with play and shoved the bar; widths are measured off the font.
## Why: docs/why/HudBar.md#reserved-widths
func _reserve(l: Label, widest: String) -> void:
	var f := UITheme.pixel_font()
	l.custom_minimum_size = Vector2(f.get_string_size(
		widest, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x, 0)

func _divider() -> Control:
	var d := Panel.new()
	d.custom_minimum_size = Vector2(1, 14)
	d.add_theme_stylebox_override("panel", UITheme.flat(UITheme.LINE, Color(0, 0, 0, 0), 0, 0, 0))
	return d

## No button click on tabs: the page change has its own sound, and both was a double click (Jon).
## Why: docs/why/HudBar.md#tab-click-sound
func heat_rect() -> Rect2:
	return _merged([_heat_label, _heat, _heat_text])


func fuel_rect() -> Rect2:
	return _merged([_fuel])


## The DATA readout, its word and figure.
func data_rect() -> Rect2:
	return _merged([_data])


## The hull gauge with its word and number (the hull lesson's subject).
func hull_rect() -> Rect2:
	return _merged([_hull_label, _hull, _hull_text])


## The fuel readout's pieces, for the box test: the word, the bar, the figure.
func fuel_parts() -> Array:
	return _fuel.get_children() if _fuel != null else []


func tab_rect(which: StringName) -> Rect2:
	match which:
		&"chart":
			return _merged([_tab_chart])
		&"sector":
			return _merged([_tab_system])
		&"local":
			return _merged([_tab_sector])
	return Rect2()


## THE READOUT A STAT LIVES IN, for an event's result to fly its change to
## (`OutcomeRow`, look C): "hp" "heat" "credits" "fuel" "data". Not one of them
## takes a click, and the result only flickers them.
func stat_nodes(key: String) -> Array:
	match key:
		"hp":
			return [_hull_label, _hull, _hull_text]
		"heat":
			return [_heat_label, _heat, _heat_text]
		"credits":
			return [_scrap]
		"fuel":
			return [_fuel]
		"data":
			return [_data]
	return []


## A tab, for the same: flickered, never moved.
func tab_nodes(which: StringName) -> Array:
	match which:
		&"chart":
			return [_tab_chart]
	return []


## Where the goal line is, global; empty while it is not up.
func goal_rect() -> Rect2:
	return goal.rect() if goal != null and is_instance_valid(goal) else Rect2()


func _merged(cs: Array) -> Rect2:
	if not is_visible_in_tree():
		return Rect2()
	var r := Rect2()
	for c in cs:
		if c != null and is_instance_valid(c) and (c as Control).is_visible_in_tree():
			var g := (c as Control).get_global_rect()
			r = g if r.size == Vector2.ZERO else r.merge(g)
	return r


## `_state` for a tab that opens and shuts something over the screen: lit
## while it is open, and still pressable then, to shut it.
func _state_toggle(b: Button, active: bool, lock: String, hint: String) -> void:
	_state(b, active, lock, hint)
	if active and lock == "":
		b.disabled = false
		b.add_theme_color_override("font_color", UITheme.HOT)
		b.add_theme_stylebox_override("hover", UITheme.bevel(Color("#5a3410"), 3, 5))
	else:
		b.remove_theme_color_override("font_color")
		b.remove_theme_stylebox_override("hover")


## Where the QUESTS tab is, global (for the tests and the table).
func quests_tab_rect() -> Rect2:
	return _merged([_tab_quests])


## Where the COMMS tab is, global (for the tests).
func comms_tab_rect() -> Rect2:
	return _merged([_tab_comms])


func _tab(label: String, action: Callable) -> Button:
	return Widgets.button(label, action, false)

## A lock reason explains a greyed tab; lit styleboxes are added and removed so no tab stays amber.
## Why: docs/why/HudBar.md#tab-state
func _state(b: Button, active: bool, lock: String, hint: String) -> void:
	# A tab dev mode did not build is null: guarded here, the one place they all pass.
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


## The chip is 16 px as the Phase 9 gate names; it shows set bonuses that were hidden.
## Why: docs/why/HudBar.md#set-chip
class SetChip extends Control:
	const PLATE := 16.0
	## Seconds for one full breath at the top tier.
	const PULSE := 1.6

	var manufacturer: StringName = &""
	var mark: Color = UITheme.CHILL
	var field: Color = UITheme.PANEL
	## It counts parts rather than tiers, so pips can say two of the three you need.
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

	## Only the top tier ticks: redrawing every frame for a static state is waste.
	func setup(n: int, parts: int = 0) -> void:
		count = n
		fitted = parts
		set_process(n >= 5)
		_t = 0.0
		# The trigger only: the plain text stays a readable fallback if the panel fails to build.
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
		# Scale 1: emblems are authored in whole pixels; other scales land on half pixels.
		CardView.draw_emblem(self, manufacturer, Vector2(PLATE, PLATE) * 0.5,
			1.0, ink, bg)
		# Count pips sit in columns 13 and 14, free on all seven marks, stacking bottom-up.
		for i in mini(count, 5):
			draw_rect(Rect2(13.0, PLATE - 3.0 - i * 2.0, 2.0, 1.0), ink, true)


## The tank is a flat, continuous gauge so it does not read as pressable or as a third row of cells.
## Why: docs/why/HudBar.md#fuel-bar
class FuelBar extends Control:
	const W := 24
	const H := 5
	const FILL: Array[Color] = [UITheme.GOOD, UITheme.WARN, Color("#d4614f")]
	var ratio := 1.0
	var state := 0

	func _init() -> void:
		custom_minimum_size = Vector2(W, H)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		focus_mode = Control.FOCUS_NONE

	func set_tank(have: int, cap: int, s: int) -> void:
		ratio = clampf(float(have) / float(maxi(1, cap)), 0.0, 1.0)
		state = s
		queue_redraw()

	## How many of the bar's inner pixels are lit. One while anything is left,
	## so the bar is empty only when the tank is.
	func lit_px() -> int:
		var inner := W - 2
		if ratio <= 0.0:
			return 0
		return clampi(int(round(ratio * inner)), 1, inner)

	func _draw() -> void:
		# +1 for the same optical reason as BoxGauge: Silkscreen's caps sit high.
		var y: float = floor((size.y - H) * 0.5) + 1.0
		draw_rect(Rect2(0, y, W, H), FUEL_WELL, true)
		draw_rect(Rect2(0, y, W, H), UITheme.LINE, false, 1.0)
		var px := lit_px()
		if px > 0:
			draw_rect(Rect2(1, y + 1, px, H - 2), FILL[state], true)
