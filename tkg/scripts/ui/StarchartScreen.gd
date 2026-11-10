class_name StarchartScreen
extends Control

## Icons tinted by region, not labelled squares: a label under each node clipped STATION.
## Ship stats and cargo live on the ship screen. This one answers where next and the cost.
## Why: docs/why/StarchartScreen.md#chart-overview

var _chart: MapChart
var _layer_cells: HBoxContainer
var _layer_text: Label
var _all_btn: Button
var _icons_btn: Button
var _links_btn: Button
var _region_btn: Button
var _sight_btn: Button
var _reach_btn: Button

## Static because `show_starchart` rebuilds the screen on every jump.
## Not saved: it is how the map is viewed this session, not part of the run.
## Why: docs/why/StarchartScreen.md#static-view-state
static var _sight_on := true
static var _reach_on := true
## A toggle, not a jump, because a press has an obvious undo and a jump does not.
static var _region_on: bool = false
## And whether the filter is off entirely.
static var _show_all: bool = false

## Stores the view itself: `frame_region` in `_build` saw `size` zero and clamped to ZOOM_MIN.
## A new galaxy throws the saved view away, as the old pan means nothing in it.
## Why: docs/why/StarchartScreen.md#static-view-state
static var _view_zoom: float = 0.0
static var _view_pan: Vector2 = Vector2.ZERO
static var _view_map: int = -1
const REGION_LABEL := "LOCAL REGION"

var _dest_name: Label
## The line under the name. Usually EMPTY -- see where it is filled.
var _dest_class: Label
var _dest_blurb: Label
var _rows: VBoxContainer
var _hint: Label
var _neigh: VBoxContainer
## The box holding it, resized to the list.
var _neigh_scroll: ScrollContainer
## A quest shown from the quests table, taken up by the chart that opens.
static var focus: Dictionary = {}
## The quest shown (its contract id), -1 for none, and whether its route is up.
var _picked_quest: int = -1
var _plot := false

## One row plus its separation, for sizing the box to the list.
const NEIGH_ROW := 16.0
var _jump: Button
## The star's name on the JUMP plate (C3): the one action is the biggest thing on the screen.
var _jump_to: Label
## Docked, the line that stands where JUMP would (`_berth_lock`).
var _undock_first: Label

## -1 is no selection, which is how the chart opens: the galaxy first, and a
## destination only once you have chosen to look at one.
var _selected: int = -1

## The overlay itself, or null once it has been dismissed.
var _primer: Control = null

## Holds the galaxy seed, not a bool: the trail starts at [0], so it is never empty.
## Static outlives the rebuilt screen, and a second run in one session is primed again.
## Why: docs/why/StarchartScreen.md#primer-gate
static var _primed_for: int = -1

## One 17px height whether the row holds buttons or not, so the two rows line up.
## Shared by the chart and the sector map (Jon asked for the same height).
## Why: docs/why/StarchartScreen.md#toolbar-row
const BAR_H := 17


## The toolbar row's whole height as it stands: the row, and on the field its
## plate's margins (`NavField.row_plate`).
static func row_h() -> float:
	return float(BAR_H) + (2.0 * NavField.ROW_PAD_V if NavField.used() else 0.0)


static func toolbar_row() -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 7)
	r.custom_minimum_size = Vector2(0, BAR_H)
	return r


## A button on that row, its width held so the row does not shuffle as its
## word changes (SHOW / HIDE).
static func bar_button(text: String, action: Callable, w: float) -> Button:
	var b := Widgets.button(text, action)
	b.custom_minimum_size = Vector2(w, 14)
	return b


## The row's pips: `n` blocks, each the colour `colour(i)` says.
static func fill_pips(cells: HBoxContainer, n: int, colour: Callable) -> void:
	for c in cells.get_children():
		cells.remove_child(c)
		c.queue_free()
	for i in n:
		var cell := Panel.new()
		cell.custom_minimum_size = Vector2(11, 5)
		cell.add_theme_stylebox_override("panel",
			UITheme.flat(colour.call(i), Color(0, 0, 0, 0), 0, 0, 0))
		cells.add_child(cell)


func setup() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	Sig.map_changed.connect(_refresh)
	Sig.resources_changed.connect(_refresh)
	# Roster pushes arrive unasked, so the chart must be told: a partner's jump needs a redraw.
	Sig.party_changed.connect(_refresh)
	Sig.party_map_changed.connect(_refresh)
	apply_focus()
	_refresh()


## Take up a quest the QUESTS table asked to be shown (`focus`), if any.
func apply_focus() -> void:
	if focus.is_empty():
		return
	var id := int(focus.get("id", -1))
	_plot = bool(focus.get("route", false))
	focus = {}
	var place := _quest_place(id)
	if place < 0:
		return
	_picked_quest = id
	_selected = place
	if is_inside_tree():
		_refresh()
	_frame_focus(place)


## Waits until the chart has its size and remembered view, a frame or two after build.
func _frame_focus(place: int) -> void:
	if not is_inside_tree():
		await tree_entered
	for i in 2:
		await get_tree().process_frame
	if not is_instance_valid(_chart) or _selected != place:
		return
	var here := Run.node_at()
	_chart.frame_region(here, maxf(0.12, MapGen.hop_distance(here, Run.map[place]) + 0.03), false)
	_chart.queue_redraw()

func _build() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 4)
	add_child(root)

	# --- depth strip: the greed clock, always visible
	var strip := toolbar_row()
	# Dev buttons are narrower but still held, so SHOW / HIDE does not shuffle the row.
	# The row matches the map's height so the plate never changes between them.
	# Why: docs/why/StarchartScreen.md#toolbar-row
	var dev_host: HBoxContainer = strip
	var narrow := {112.0: 96.0, 128.0: 96.0, 140.0: 124.0, 150.0: 124.0}
	var dev_w := func(w: float) -> float: return float(narrow.get(w, w)) if NavField.used() else w
	_layer_text = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	strip.add_child(_layer_text)
	_layer_cells = HBoxContainer.new()
	_layer_cells.add_theme_constant_override("separation", 2)
	strip.add_child(_layer_cells)
	strip.add_child(UITheme.body("CORE", UITheme.THEM, UITheme.FS_SMALL))
	var strip_gap := Control.new()
	strip_gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip.add_child(strip_gap)
	# Dev only: they show the generated map that the player is meant to be earning.
	if DevMode.enabled:
		_icons_btn = bar_button("HIDE SYSTEMS", _on_toggle_icons, dev_w.call(112.0))
		dev_host.add_child(_icons_btn)

	# Debug: the lattice MapGen built, which with the button beside it exposes generation faults.
		_links_btn = bar_button("SHOW REACH", _on_toggle_links, dev_w.call(128.0))
		dev_host.add_child(_links_btn)

	# And the systems those links run to. Without this the one above draws the
	# whole lattice over a chart that is still hiding most of the galaxy.
		_all_btn = bar_button("SHOW ALL SYSTEMS", _on_toggle_all, dev_w.call(140.0))
		dev_host.add_child(_all_btn)

	# Dev: re-rolls the galaxy under the same ship. Not in co-op, where the galaxy is the party's.
		var regen := bar_button("REGENERATE GALAXY", _on_regenerate, dev_w.call(150.0))
		if Net.is_networked():
			regen.disabled = true
			regen.tooltip_text = "Not in a co-op session: the galaxy belongs to the whole party."
		dev_host.add_child(regen)
	if NavField.used():
		_row_plate = NavField.row_plate(strip)
		root.add_child(_row_plate)
	else:
		root.add_child(strip)
	_strip_row = strip

	# --- chart | destination
	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 5)
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(mid)

	_chart = MapChart.new()
	# THIS one is navigated, so this one remembers. See `remembers_view`.
	_chart.remembers_view = true
	_chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chart.node_picked.connect(_on_node_picked)
	_chart.quest_avoid = _quest_avoid
	_chart.cleared.connect(_on_chart_cleared)
	_chart.view_dragged.connect(_on_view_dragged)
	var chart_wrap := Widgets.panel_with(_chart)
	if NavField.used():
		_chart.on_field = true
		chart_wrap.add_theme_stylebox_override("panel", NavField.window_style())
		# The chart sky is drawn behind the whole screen so the galaxy does not vanish at panels.
		# The picture keeps the clicks and marks (`MapChart.sky_out`).
		# Why: docs/why/StarchartScreen.md#sky-under-the-glass
		if not ("skyhost=off" in OS.get_cmdline_user_args()):
			var host := Node2D.new()
			host.name = "SkyPastPicture"
			add_child(host)
			move_child(host, 0)
			_chart.host_sky(host)
	chart_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_child(chart_wrap)

	# Bottom right, on the scale bar it belongs with: both read as one instrument.
	# A child of the chart, so it follows the chart's rect with no second set of margins.
	# Why: docs/why/StarchartScreen.md#corner-toggles
	_region_btn = _corner_toggle(_on_region, 0, 112.0)
	# Top right, apart from the scale block: these answer how far can I see and go.
	# Longest label first, as right-aligned lines give a clean descending edge.
	# Why: docs/why/StarchartScreen.md#corner-toggles
	_reach_btn = _corner_toggle(_on_reach, 0, 150.0, true)
	_sight_btn = _corner_toggle(_on_sight, 1, 150.0, true)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 4)
	right.custom_minimum_size = Vector2(236, 0)
	# The chart takes whatever is left, so the sidebar must never ask for more
	# than its minimum however long the text inside it gets.
	right.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	right.add_child(UITheme.body("DESTINATION", UITheme.COLD, UITheme.FS_SMALL))
	_dest_name = UITheme.body("", UITheme.ICE, UITheme.FS_HEAD)
	# The name wraps instead of widening the panel: a Label's minimum width is its longest line.
	# No reserved height: the header sizes to its text and the spacer below takes the slack.
	# Why: docs/why/StarchartScreen.md#destination-name-height
	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 4)
	right.add_child(head)
	_dest_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dest_name.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_dest_name.custom_minimum_size = Vector2(228, 0)
	head.add_child(_dest_name)
	_dest_class = UITheme.body("", UITheme.THEM, UITheme.FS_SMALL)
	_dest_class.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dest_class.custom_minimum_size = Vector2(228, 0)
	head.add_child(_dest_class)
	_dest_blurb = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	_dest_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dest_blurb.custom_minimum_size = Vector2(228, 0)
	head.add_child(_dest_blurb)
	right.add_child(UITheme.hsep())

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 3)
	right.add_child(_rows)

	# No spacer: the in-range list expands and is the slack, instead of demanding a height.
	# Why: docs/why/StarchartScreen.md#in-range-list-sizing

	_hint = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size = Vector2(228, 0)
	right.add_child(_hint)
	_neigh = VBoxContainer.new()
	_neigh.add_theme_constant_override("separation", 1)
	# Capped and scrolled, so a long list cannot push JUMP off the bottom of the panel.
	# It expands into what is left: a custom minimum size is a demand, not a ceiling.
	# Why: docs/why/StarchartScreen.md#in-range-list-sizing
	_neigh_scroll = ScrollContainer.new()
	_neigh_scroll.custom_minimum_size = Vector2(0, NEIGH_ROW)
	_neigh_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_neigh_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_neigh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_neigh_scroll.add_child(_neigh)
	right.add_child(_neigh_scroll)
	_jump = Widgets.button("JUMP", _on_jump)
	_jump_plate(_jump)
	right.add_child(_jump)

	_ladder_side = Widgets.panel_with(right)
	if NavField.used():
		_ladder_side.add_theme_stylebox_override("panel", NavField.plate_style())
	mid.add_child(_ladder_side)

	# --- key: icons are only better than labels if you can learn them
	var key := HBoxContainer.new()
	key.add_theme_constant_override("separation", 8)
	key.add_child(UITheme.body("KEY", UITheme.COLD, UITheme.FS_SMALL))
	# Colours come from `MapGen.swatch`: the old literals named colours not on the map.
	# Why: docs/why/StarchartScreen.md#legend-colours
	for item in _legend_items():
		key.add_child(item)
	root.add_child(key)
	_key_row = key

	# Catches a fresh screen up with the static toggles: labels, rings and the held region.
	_paint_rings()
	_paint_region()
	# Only in developer mode: the toggle outlives the switch, and a reveal left
	# on must not follow the player into the game with no button to undo it.
	_chart.show_all = _show_all and DevMode.enabled
	if _all_btn != null:
		_all_btn.text = "SHOW KNOWN ONLY" if _show_all else "SHOW ALL SYSTEMS"
	# The chart restores the view on its first resize; framing here would land on ZOOM_MIN.
	# Why: docs/why/StarchartScreen.md#static-view-state

	# No first survey card (Jon, Oct 13). The card is built only for ChartShot's `primer` photo.
	# Why: docs/why/StarchartScreen.md#first-survey-card
	if "primer" in OS.get_cmdline_user_args():
		_build_primer()

## Teaches what the glyphs, rings and gauges mean the first time the chart opens in a run.
## The destination panel is the permanent reference; the card is the moment.
## Why: docs/why/StarchartScreen.md#primer-card
func _build_primer() -> void:
	if Run.trail.size() > 1 or _primed_for == Run.galaxy_seed:
		return
	_primed_for = Run.galaxy_seed

	# STOP, so the click that dismisses the card does not also pick a system glyph.
	_primer = Control.new()
	_primer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_primer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_primer)

	var scrim := ColorRect.new()
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(UITheme.VOID.r, UITheme.VOID.g, UITheme.VOID.b, 0.82)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_primer.add_child(scrim)

	# A CenterContainer, not a centre anchor preset, which left the card hanging off the bottom.
	var mid_c := CenterContainer.new()
	mid_c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mid_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_primer.add_child(mid_c)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel",
		UITheme.flat(UITheme.PANEL, UITheme.LINE, 0, 12, 14))
	card.custom_minimum_size = Vector2(PRIMER_W, 0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid_c.add_child(card)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	card.add_child(col)

	col.add_child(UITheme.body("FIRST SURVEY", UITheme.EMBER, UITheme.FS_SMALL))
	var title := UITheme.body(Run.galaxy_title.to_upper(), UITheme.ICE, UITheme.FS_HEAD)
	col.add_child(title)
	col.add_child(UITheme.body("%s - %s" % [Run.galaxy_name,
		GalaxyGen.type_name(Run.galaxy_kind).to_upper()], UITheme.THEM, UITheme.FS_SMALL))
	col.add_child(_primer_para(GalaxyGen.blurb(Run.galaxy_kind), UITheme.COLD))

	col.add_child(_gap())
	col.add_child(UITheme.hsep())
	col.add_child(_gap())
	col.add_child(UITheme.body("WHAT IT COSTS TO CROSS", UITheme.CHILL, UITheme.FS_SMALL))
	for line in _primer_cost():
		col.add_child(_primer_para(line, UITheme.COLD))

	col.add_child(_gap())
	col.add_child(UITheme.hsep())
	col.add_child(_gap())
	col.add_child(UITheme.body("READING THE CHART", UITheme.CHILL, UITheme.FS_SMALL))
	col.add_child(_primer_glyphs())
	# The shapes are a picture and the rows under them are prose; butted
	# together they read as one block and the glyphs stop being a legend.
	col.add_child(_gap())
	for line in PRIMER_LEGEND:
		col.add_child(_primer_para(line, UITheme.COLD))

	col.add_child(_gap())
	col.add_child(UITheme.body("PRESS ANYTHING TO CONTINUE", UITheme.EMBER,
		UITheme.FS_SMALL))


## Wide enough for the blurbs, narrow enough that a line of it is one glance.
const PRIMER_W := 460


## Shorter, not reshaped: keyed rows read as a spec sheet, so these stay sentences.
## Two of the three lines were wrong: one promised what `can_jump_to` forbids, one inverted.
## Why: docs/why/StarchartScreen.md#primer-legend-text
const PRIMER_LEGEND: Array[String] = [
	"A system's colour is its star: pale is ordinary, red and blue are rarer.",
	"You fly as far as THRUSTER REACH, and two rings deeper a jump at most. You see as far as SENSOR RANGE. Past your sight a jump is refused: NOT SCANNED.",
	"Each row shows danger, then fuel. Full danger beside empty fuel is a cheap, deadly jump.",
	"Danger has five steps: EASY, ROUGH, HARD, BRUTAL and LETHAL. A more dangerous system offers more.",
]

## A star inside the reach ring is refused on its FUEL row: a jump goes two rings deeper at most.
## Named so `-- maptest` can hold it to the rule's count (Jon, Oct 27 and Oct 29).
## Why: docs/why/StarchartScreen.md#too-deep-refusal
const DEPTH_ROW := "TWO RINGS IN AT MOST"


## One wrapped paragraph at the card's width.
func _primer_para(text: String, colour: Color) -> Label:
	var l := UITheme.body(text, colour, UITheme.FS_SMALL)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(PRIMER_W - 28, 0)
	return l


## These thresholds do not move on a re-roll: `reach` and `density` are archetype constants.
## `squash` is jittered, so the tilt line is decided per run and not per kind.
## Why: docs/why/StarchartScreen.md#primer-cost-text
func _primer_cost() -> Array[String]:
	var out: Array[String] = []
	var reach: float = float(Run.galaxy.get("reach", 1.0))
	var dens: float = float(Run.galaxy.get("density", 1.0))
	# Sentences, not rows: this is the galaxy talking, and 'Tight.' lost the good half.
	if reach >= 1.08:
		out.append("A wide disc. The crossings are long, and each one costs fuel.")
	elif reach <= 0.85:
		out.append("A tight disc. Systems sit close together, so a tank goes further here.")
	if dens >= 1.15:
		out.append("It has many systems. There are more places to stop than you can afford.")
	elif dens <= 0.80:
		out.append("It has few systems. Some stretches have nothing in them.")
	# `hop_distance` divides y by squash, so fuel follows round distance, not drawn distance.
	# Measured on a Lenticular: the same drawn gap costs 3 fuel sideways and 6 vertically.
	# Why: docs/why/StarchartScreen.md#squash-anisotropy
	var sq: float = float(Run.galaxy.get("squash", 1.0))
	if sq < 0.5:
		out.append("It is steeply tilted, so the chart misleads on distance. A gap up or down costs far more than the same gap sideways.")
	if out.is_empty():
		out.append("It is ordinary to cross, with no unusual distances or gaps.")
	return out


## The five shapes, in the colours the map actually paints them.
func _primer_glyphs() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	for item in _legend_items():
		row.add_child(item)
	return row


## The five node types in the map's colours; the corner KEY and the primer share one list.
func _legend_items() -> Array[Control]:
	var out: Array[Control] = []
	for pair in [
			[MapGen.NodeType.START, "START"],
			[MapGen.NodeType.SYSTEM, "SYSTEM"],
			[MapGen.NodeType.STATION, "STATION"],
			[MapGen.NodeType.PULSAR, "PULSAR"],
			[MapGen.NodeType.CORE, "CORE"]]:
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 3)
		var g := Glyph.new()
		g.setup(pair[0] as MapGen.NodeType,
			MapGen.swatch(pair[0] as MapGen.NodeType))
		item.add_child(g)
		item.add_child(UITheme.body(pair[1] as String, UITheme.COLD, UITheme.FS_SMALL))
		out.append(item)
	return out


## Any press dismisses it. `_input` so no focus is needed, and consumed so it picks nothing.
func _input(e: InputEvent) -> void:
	if _primer == null:
		return
	var press := (e is InputEventKey and (e as InputEventKey).pressed) \
		or (e is InputEventMouseButton and (e as InputEventMouseButton).pressed) \
		or e is InputEventJoypadButton
	if not press:
		return
	dismiss_primer()
	get_viewport().set_input_as_handled()


## Take the card down. Public because the shot harness needs the chart without
## it, and because a screen that is being torn down should not leave one up.
func dismiss_primer() -> bool:
	if _primer == null:
		return false
	_primer.queue_free()
	_primer = null
	return true


## Asked of the whole map: travel is not link-gated, so linked neighbours are the wrong test.
## `has_legal_jump()` is the question `check_stranded()` ends the run on.
## Why: docs/why/StarchartScreen.md#nowhere-to-go
func _anywhere_to_go() -> bool:
	return Run.has_legal_jump()

func _on_node_picked(index: int) -> void:
	# The chart is drawn rather than built of buttons, so picking a system made
	# no sound at all. Guarded on the file: silent until one is picked.
	if index != _selected and ResourceLoader.exists(Audio.SFX_PATH % &"chart_select"):
		Audio.play(&"chart_select", 0.04, 60)
	_selected = index
	# a star picked off the chart is not the quest shown from the table
	if _picked_quest >= 0 and _quest_place(_picked_quest) != index:
		_picked_quest = -1
		_plot = false
	_refresh()

## A sensor return, slower than the screen fade: the dish finishing its work.
const SETTLE_S := 0.22
## Which system the panel last resolved for, so pointing at the same one twice
## does not make it think again.
var _settled_on: int = -2


## Fades only the rows, and only on a new selection: the name is already known.
## Modulate carries to children added after the tween starts, so it is one line.
## Why: docs/why/StarchartScreen.md#settle-fade
func _settle() -> void:
	if _rows == null or not Router.animating():
		return
	if _selected == _settled_on:
		return
	_settled_on = _selected
	_rows.modulate.a = 0.0
	var tw := _rows.create_tween()
	tw.tween_property(_rows, "modulate:a", 1.0, SETTLE_S) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _refresh() -> void:
	var here: MapGen.MapNode = Run.node_at()

	_layer_text.text = "LAYER %d/%d" % [here.layer + 1, MapGen.LAYERS]
	fill_pips(_layer_cells, MapGen.LAYERS, func(i: int) -> Color:
		if i < here.layer:
			return UITheme.COLD
		return UITheme.FLARE if i == here.layer else UITheme.LINE)

	if _selected >= Run.map.size():
		_selected = -1
	_chart.set_state(_selected)

	_clear(_rows)
	_settle()
	_quest_marks()

	if _selected < 0:
		_fill_neighbours(here)
		# Two different nothings: nothing chosen, versus nothing possible.
		if _anywhere_to_go():
			# With nothing selected the panel describes the galaxy: the one thing always true here.
			_dest_name.text = Run.galaxy_title.to_upper()
			_class("%s - %s" % [
				Run.galaxy_name, GalaxyGen.type_name(Run.galaxy_kind).to_upper()])
			_blurb(GalaxyGen.blurb(Run.galaxy_kind))
			# The count stays: blanking it left the start of a run with a list and no number above.
			# Why: docs/why/StarchartScreen.md#neighbour-count-hint
		else:
			_dest_name.text = "NOWHERE"
			_class("")
			_blurb("No jump you can afford. The tank is dry.")
			# Not repeated here, as the header already said it: the same sentence twice.
			_hint.text = ""
		_lock_jump()
		return

	var t: MapGen.MapNode = Run.map[_selected]

	# A system known only through a contract shows why it is circled and nothing more.
	# The jump button is left alone: reach is about fuel and adjacency, not knowledge.
	# Why: docs/why/StarchartScreen.md#contract-only-systems
	if Run.known_only_by_contract(_selected):
		var job := Run.contract_at(_selected)
		_dest_name.text = MapGen.star_name(t)
		_class("%s - POSITION ONLY" % Run.galaxy_name)
		_blurb(job.text)
		_rows.add_child(_row("CIRCLED BY",
			DB.manufacturer_name(job.manufacturer).to_upper(),
			DB.manufacturer_colour(job.manufacturer)))
		_rows.add_child(_row("PAYS", "%d CREDITS" % job.pay))
		# Said plainly rather than left as four blank rows. An absence the player
		# can read is information; an absence they have to notice is a bug.
		_rows.add_child(_row("SURVEY", "NONE"))
		_hint.text = "They gave you a position and nothing else."
		_jump.disabled = not Run.can_jump_to(t)
		_jump_to.text = MapGen.star_name(t) if not _jump.disabled else ""
		_berth_lock()
		return

	# The name is the place; the classification is what kind of place it is -
	# how built up, how policed, and whose it is, in that order.
	_dest_name.text = MapGen.star_name(t)
	# No class line: only 7.0% of systems are in a cloud, so it was empty 19 times in 20.
	# An empty Label still reserves a line, and the WARNING group already names the nebula.
	# Why: docs/why/StarchartScreen.md#class-line-removed
	_class("")
	# No blurb and no survey rows with a star picked (C3; the rows went off the hover tag too,
	# Q1, Nov 9). The panel keeps what decides the jump: danger, fuel, warnings.
	# Why: docs/why/StarchartScreen.md#jump-plate
	_blurb("")
	_rows.add_child(_danger_row(t.danger))

	# Out of range is a different answer from "cannot afford it", and quoting a
	# price for a jump the drive cannot make at all is the wrong answer twice.
	if t.index == here.index:
		# You are standing in it. "Out of range" is true by the rule and absurd
		# to read, and a heading to where you already are is no better.
		_rows.add_child(_row("FUEL", "YOU ARE HERE", UITheme.FLARE))
	else:
		if Run.too_deep_only(here, t):
			# In the ring and refused: three rings in, and a jump goes two deeper at most.
			_rows.add_child(_row("FUEL", DEPTH_ROW, Color("#7c6a58")))
		elif not Run.reachable(t):
			_rows.add_child(_row("FUEL", "OUT OF RANGE", Color("#7c6a58")))
		elif not t.sensed:
			# No price for a system the dish has not resolved, as for one out of range.
			_rows.add_child(_row("FUEL", "NOT SCANNED", Color("#7c6a58")))
		else:
			var cost := Run.fuel_cost_to(t)
			_rows.add_child(_fuel_row(cost, cost <= Run.fuel))
		# OUTWARD is its own word: it read COREWARD, which was wrong and, now
		# that only the way in is limited, also the wrong advice.
		# (the heading is on the star's tag too, C3)

	# Hazards last, so the thing that might kill you is where the eye stops. The key shows once.
	var hz := MapGen.hazards(t)
	for i in hz.size():
		_rows.add_child(_row("WARNING" if i == 0 else "", hz[i], _WARN))

	# Names what is in reach: a bare count left you hunting the chart for the places.
	_fill_neighbours(here)

	# Two different reasons a jump is impossible, and they need different words:
	# no route at all, versus a route you cannot currently pay for.
	_jump.disabled = not Run.can_jump_to(t)
	_jump_to.text = MapGen.star_name(t) if not _jump.disabled else ""
	if not _jump.disabled:
		_jump.text = "JUMP"
	elif t.index == here.index:
		_jump.text = "YOU ARE HERE"
	elif Run.too_deep_only(here, t):
		# A FOURTH REASON (Oct 22): near enough, but three rings in or more.
		_jump.text = "TOO DEEP"
	elif not Run.reachable(t):
		_jump.text = "TOO FAR TO REACH"
	elif not t.sensed:
		# `can_jump_to` has three tests; the old chain blamed fuel for the third.
		# Why: docs/why/StarchartScreen.md#jump-button-reasons
		_jump.text = "NOT SCANNED"
	else:
		_jump.text = "NOT ENOUGH FUEL"
	_berth_lock()


## Nothing to jump to: JUMP off, or UNDOCK FIRST at the berth.
func _lock_jump() -> void:
	_jump.disabled = true
	_jump_to.text = ""
	_berth_lock()


## THE ONE ACTION IS THE BIGGEST THING (stripped-down UI C3, Jon, Nov 9): JUMP is a big ember
## plate, JUMP in the heading size and the star's name under it, the refusal word on a dark
## plate of the same size. The rows that filled the panel moved to the star's hover tag.
## Why: docs/why/StarchartScreen.md#jump-plate
const JUMP_H := 56

func _jump_plate(b: Button) -> void:
	b.custom_minimum_size = Vector2(0, JUMP_H)
	b.add_theme_font_size_override("font_size", UITheme.FS_HEAD)
	var boxes := {
		"normal": UITheme.flat(UITheme.EMBER, UITheme.HOT, 0, 4, 8),
		"hover": UITheme.mark_box(UITheme.EMBER, 4, 8),
		"pressed": UITheme.flat(UITheme.HOT, UITheme.HOT, 0, 4, 8),
		"focus": UITheme.flat(UITheme.EMBER, UITheme.HOT, 0, 4, 8),
		"disabled": UITheme.flat(UITheme.VOID, UITheme.LINE, 0, 4, 8),
	}
	for st: String in boxes:
		var sb: StyleBoxFlat = boxes[st]
		# the word sits in the upper half, the name's line under it
		sb.content_margin_bottom = 18
		b.add_theme_stylebox_override(st, sb)
	for st: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(st, UITheme.VOID)
	b.add_theme_color_override("font_disabled_color", UITheme.COLD)
	_jump_to = UITheme.body("", UITheme.VOID, UITheme.FS_SMALL)
	_jump_to.name = "JumpTo"
	_jump_to.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_jump_to.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_jump_to.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_jump_to.offset_top = -18
	_jump_to.offset_bottom = -6
	b.add_child(_jump_to)


## Docked, no JUMP: one plain line, UNDOCK FIRST, as UNDOCK is the only way (Jon,
## Oct 27; Nov 9, stripped-down UI 5). With crates still on the pad it reads CANNOT UNDOCK.
## Why: docs/why/StarchartScreen.md#berth-lock
func _berth_lock() -> void:
	if _undock_first == null:
		_undock_first = UITheme.body("UNDOCK FIRST", UITheme.COLD, UITheme.FS_SMALL)
		_undock_first.name = "UndockFirst"
		_undock_first.custom_minimum_size = Vector2(0, 24)
		_undock_first.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_undock_first.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_undock_first.mouse_filter = Control.MOUSE_FILTER_STOP
		_undock_first.tooltip_text = Widgets.tip(Router.DOCKED_LINE)
		_jump.add_sibling(_undock_first)
	_jump.tooltip_text = ""
	_jump.visible = not Router.docked
	_undock_first.visible = Router.docked
	if Router.docked or _jump.disabled or Router.may_cast_off():
		return
	_jump.disabled = true
	_jump.text = "CANNOT UNDOCK"


## Cleared systems stay listed: knowing the ground is stripped decides farm on or dive.
func _fill_neighbours(here: MapGen.MapNode) -> void:
	_clear(_neigh)
	# Filter by what you can see: `in_range_of` is geometry, and listed systems the dish never saw.
	var near: Array = []
	for n in Run.in_range():
		if (n as MapGen.MapNode).sensed:
			near.append(n)
	# Telegraphed systems first, then nearest: RULING 1 makes all others look identical.
	# Orders by what the chart tells you, never by `options`, which arrival is for.
	# Why: docs/why/StarchartScreen.md#neighbour-sorting
	near.sort_custom(func(x, y):
		var rx := _notable(x)
		var ry := _notable(y)
		if rx != ry:
			return rx < ry
		return MapGen.hop_distance(here, x) < MapGen.hop_distance(here, y))
	if near.is_empty():
		_hint.text = "Nothing in range. The tank is too low to reach anything."
		return
	# Only the count: it decides farm or dive before a row is read; the rest was rows read aloud.
	# Why: docs/why/StarchartScreen.md#neighbour-count-hint
	_hint.text = "IN RANGE - %d SYSTEM%s" % [
		near.size(), "" if near.size() == 1 else "S"]
	for n in near:
		_neigh.add_child(_neighbour_row(n))
	# Nothing set here: `custom_minimum_size` is a demand, and pushed JUMP off screen.
	# Why: docs/why/StarchartScreen.md#in-range-list-sizing

## Sorts only on what the chart telegraphs; ordinary systems are interchangeable by design.
## Cleared systems sort last but stay listed.
## Why: docs/why/StarchartScreen.md#neighbour-sorting
func _quest_marks() -> void:
	var tags: Array = []
	var r: Array[int] = []
	if _picked_quest >= 0:
		# a contract or an event quest, open or finished (`QuestLog.find`)
		var e := QuestLog.find(_picked_quest)
		if not e.is_empty() and int(e.place) >= 0 and int(e.place) == _selected:
			tags.append({index = int(e.place), text = String(e.tag), picked = true})
			# a finished one has nowhere to go (its row has no PLOT ROUTE)
			if _plot and not bool(e.done):
				r = QuestLog.route(int(e.place))
	_chart.quest_tags = tags
	_chart.quest_route = r
	_chart.queue_redraw()


## The system quest `id`'s tag stands on, or -1.
func _quest_place(id: int) -> int:
	return int(QuestLog.find(id).get("place", -1))


## What a quest tag keeps off: the HUD, goal line, A.S.H. and the chart's own words.
func _quest_avoid() -> Array:
	var out: Array = []
	if Router.hud != null and is_instance_valid(Router.hud) and Router.hud.is_visible_in_tree():
		out.append(Router.hud.get_global_rect())
	var st := GoalLine.stack_rect(self)
	if st.size != Vector2.ZERO:
		out.append(st)
	if Ash.portrait != null and is_instance_valid(Ash.portrait) and Ash.portrait.visible:
		out.append(Ash.portrait.rect())
	var spots := Ash.tut_spot_boxes(self, Vector2(AshPortrait.W, AshPortrait.H))
	if not spots.is_empty():
		out.append((spots[0] as Dictionary).rect)
	Ash._chart_rects(self, out, false)
	return out


func _notable(n: MapGen.MapNode) -> int:
	if n.cleared and n.type != MapGen.NodeType.CORE:
		return 5
	if Run.contract_at(n.index) != null:
		return 0
	match n.type:
		MapGen.NodeType.CORE: return 1
		MapGen.NodeType.STATION: return 2
		MapGen.NodeType.PULSAR: return 3
	return 4


## One system in the list: its icon, its name, its danger and what it costs.
func _neighbour_row(n: MapGen.MapNode) -> Control:
	var afford := Run.can_jump_to(n)
	var b := Button.new()
	# which system the row is, for the fuel hint, which points at the dock it names
	b.set_meta(&"node", n.index)
	Widgets.wear_pointer(b)
	b.custom_minimum_size = Vector2(0, 15)
	b.focus_mode = Control.FOCUS_NONE
	b.flat = true
	b.pressed.connect(func() -> void:
		_selected = n.index
		_refresh())

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 4)
	# The row is decoration over the button; it must not eat the click.
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)

	var g := Glyph.new()
	# (a twin's row wears the chart's two-sun mark, as the chart beside it does)
	g.setup(n.type, MapGen.star_colour(n), n.twin)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(g)

	var dim := Color("#55647a")
	var name_col := UITheme.ICE if afford else dim
	if n.cleared and n.type != MapGen.NodeType.CORE:
		name_col = dim
	if n.index == _selected:
		name_col = UITheme.FLARE
	var label := UITheme.body(MapGen.star_name(n), name_col, UITheme.FS_SMALL)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_text = true
	row.add_child(label)

	# Gauges, not 'D1 1F': this game already says countable quantities in boxes.
	var dg := MicroGauge.new()
	dg.setup(MapGen.DANGER_MAX, n.danger, MicroGauge.Mode.DANGER)
	row.add_child(dg)
	var cost := Run.fuel_cost_to(n)
	var fg := MicroGauge.new()
	# Same cell count as danger so the columns line up. A jump never costs ten, which is the point.
	fg.setup(MapGen.DANGER_MAX, cost,
		MicroGauge.Mode.FUEL if afford else MicroGauge.Mode.UNAFFORDABLE)
	row.add_child(fg)
	# Exact numbers stay one hover away. The rung name says how bad 7 is; see `MapGen.tier_name`.
	# Why: docs/why/StarchartScreen.md#danger-names
	b.tooltip_text = "%s\ndanger %d of %d · %s · %d fuel" % [
		MapGen.place_line(n), n.danger, MapGen.DANGER_MAX,
		MapGen.tier_name(n.danger), cost]
	return b

func _contains(t: MapGen.MapNode) -> String:
	if t.cleared:
		return "PICKED CLEAN"
	match t.type:
		MapGen.NodeType.STATION: return "DOCK - REPAIR, REFUEL, STOCK"
		MapGen.NodeType.SYSTEM: return "SYSTEM"
		MapGen.NodeType.CORE: return "THE CUSTODIAN"
		_: return "-"

## `queue_free()` defers but `add_child()` does not, so a rebuild doubled the list a frame.
## Removing from the tree first makes the rebuild atomic.
## Why: docs/why/StarchartScreen.md#atomic-clear
func _clear(host: Node) -> void:
	for c in host.get_children():
		host.remove_child(c)
		c.queue_free()

## Hazard red, warmer than THEM (an enemy's colour), so a warning wins over the cold blues.
const _WARN := Color("#d4614f")

## The blurb the same way: shown for the galaxy at rest, hidden once a star is picked (C3).
func _blurb(s: String) -> void:
	_dest_blurb.text = s
	_dest_blurb.visible = s != ""


## Hidden when empty: an empty Label still reserves a font line, only hiding returns the space.
## Why: docs/why/StarchartScreen.md#class-line-hiding
func _class(s: String) -> void:
	_dest_class.text = s
	_dest_class.visible = not s.is_empty()


## Four pixels of nothing, to group the rows without drawing on them.
func _gap() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, 4)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _row(key: String, value: String, colour: Color = UITheme.CHILL) -> Control:
	var row := HBoxContainer.new()
	row.add_child(UITheme.body(key, UITheme.COLD, UITheme.FS_SMALL))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	row.add_child(UITheme.body(value, colour, UITheme.FS_SMALL))
	return row

## Gauge plus the word: a player learns BRUTAL once and can read every system against it.
func _danger_row(danger: int) -> Control:
	var row := _gauge_row("DANGER", danger, MicroGauge.Mode.DANGER)
	row.add_child(UITheme.body(" " + MapGen.tier_name(danger),
		_WARN if danger >= 7 else UITheme.COLD, UITheme.FS_SMALL))
	return row

## Fuel in the same boxes as danger, at the same count, so the two rows read as
## one comparison: what it costs against what it costs you.
func _fuel_row(cost: int, afford: bool) -> Control:
	return _gauge_row("FUEL", cost,
		MicroGauge.Mode.FUEL if afford else MicroGauge.Mode.UNAFFORDABLE)

func _gauge_row(key: String, value: int, mode: MicroGauge.Mode) -> Control:
	var row := HBoxContainer.new()
	row.add_child(UITheme.body(key, UITheme.COLD, UITheme.FS_SMALL))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	var pips := MicroGauge.new()
	pips.setup(MapGen.DANGER_MAX, clampi(value, 0, MapGen.DANGER_MAX), mode, true)
	row.add_child(pips)
	return row

## Dragging away unticks LOCAL REGION and leaves the view alone: the box reports, not commands.
## Back to the galaxy is -1, not -2, so the next refresh does not pick a system.
## Why: docs/why/StarchartScreen.md#region-toggle
func _on_view_dragged() -> void:
	if not _region_on:
		return
	_region_on = false
	_paint_region()

## One pressable corner label, `row` lines up. Extracted so three offset sets cannot drift.
func _corner_toggle(cb: Callable, row: int, wide: float, top := false) -> Button:
	var b := Widgets.button("", cb)
	# No chrome: a button plate over a starfield reads as a dialog dropped on the galaxy.
	b.add_theme_font_size_override("font_size", UITheme.FS_SMALL)
	b.add_theme_color_override("font_hover_color", UITheme.ICE)
	b.add_theme_color_override("font_pressed_color", UITheme.HOT)
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, UITheme.empty())
	# Black copies of the words a pixel each way behind the button (`show_behind_parent`), so
	# ember words stay readable over a galaxy's warm light.
	# Why: docs/why/StarchartScreen.md#corner-word-shadow
	var shs: Array[Label] = []
	for o: Vector2 in [Vector2(1, 1), Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		var sh := Label.new()
		sh.show_behind_parent = true
		sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sh.add_theme_font_size_override("font_size", UITheme.FS_SMALL)
		sh.add_theme_color_override("font_color", Color(0, 0, 0, 0.85))
		sh.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		sh.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		sh.set_anchors_preset(Control.PRESET_FULL_RECT)
		sh.offset_left = o.x
		sh.offset_top = o.y
		sh.offset_right = o.x
		sh.offset_bottom = o.y
		b.add_child(sh)
		shs.append(sh)
	b.draw.connect(func() -> void:
		for sh: Label in shs:
			if sh.text != b.text:
				sh.text = b.text)
	b.set_anchors_preset(Control.PRESET_TOP_RIGHT if top else Control.PRESET_BOTTOM_RIGHT)
	# Measured off the chart's own constants, so retuning either keeps the two together.
	b.offset_left = -(wide + MapChart.BAR_PAD)
	b.offset_right = -MapChart.BAR_PAD
	# Text sits at the edge: a Button centres its label, leaving the words short of the bar.
	b.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# 8px clear over the SCALE BLOCK, measured from the chart's numbers; `row` stacks upward.
	if top:
		# Down from the top edge instead, by the same padding the scale block
		# keeps off the bottom, so both corners sit the same distance in.
		b.offset_top = MapChart.BAR_PAD + 14.0 * float(row)
		b.offset_bottom = MapChart.BAR_PAD + 14.0 * float(row + 1)
	else:
		var scale_top := MapChart.BAR_PAD + MapChart.BAR_LABEL_H
		b.offset_top = -(14.0 * float(row + 1) + scale_top)
		b.offset_bottom = -(14.0 * float(row) + scale_top)
	_chart.add_child(b)
	return b

## The two ring toggles, tinted to the rings they govern so the corner reads
## as a key as well as a control.
func _paint_rings() -> void:
	if _sight_btn != null:
		Widgets.paint_toggle(_sight_btn, "SENSOR RANGE", _sight_on, UITheme.ICE)
	if _reach_btn != null:
		Widgets.paint_toggle(_reach_btn, "THRUSTER REACH", _reach_on)
	if _chart != null:
		_chart.show_sight = _sight_on
		_chart.show_reach = _reach_on
		_chart.queue_redraw()

func _on_sight() -> void:
	_sight_on = not _sight_on
	_paint_rings()

func _on_reach() -> void:
	_reach_on = not _reach_on
	_paint_rings()

func _paint_region() -> void:
	if _region_btn == null:
		return
	Widgets.paint_toggle(_region_btn, REGION_LABEL, _region_on)

## L lives on the screen, so the key and the button always do the same amount.
## `_unhandled_key_input` keeps WASD on the chart and lets focused fields refuse first.
## Why: docs/why/StarchartScreen.md#local-region-key
func _unhandled_key_input(e: InputEvent) -> void:
	var k := e as InputEventKey
	# LOCAL REGION is a binding (`Keys`), L out of the box.
	if k == null or not k.is_action_pressed(&"chart_region"):
		return
	_on_region()
	accept_event()


func _on_region() -> void:
	if _chart == null:
		return
	_region_on = not _region_on
	_paint_region()
	if not _region_on:
		_chart.frame_galaxy()
		return
	var here: MapGen.MapNode = Run.node_at()
	if here != null:
		_chart.frame_region(here)

func _on_regenerate() -> void:
	if not Run.dev_regenerate_galaxy():
		return
	Router._autosave()
	# the screen made again, from scratch, on the new galaxy: its sky baked
	# anew, its view framed on the new start
	Router.show_starchart()


func _on_toggle_all() -> void:
	_show_all = not _show_all
	_chart.show_all = _show_all
	if _all_btn != null:
		_all_btn.text = "SHOW KNOWN ONLY" if _show_all else "SHOW ALL SYSTEMS"
	_chart.queue_redraw()


func _on_toggle_icons() -> void:
	_chart.show_icons = not _chart.show_icons
	if _icons_btn != null:
		_icons_btn.text = "HIDE SYSTEMS" if _chart.show_icons else "SHOW SYSTEMS"
	_chart.queue_redraw()


func _on_toggle_links() -> void:
	_chart.show_links = not _chart.show_links
	if _links_btn != null:
		# Says what it does now: it draws one system's REACH, not the old ALL LINKS lattice.
		_links_btn.text = "SHOW REACH" if not _chart.show_links else "HIDE REACH"
	_chart.queue_redraw()

func _on_chart_cleared() -> void:
	_selected = -1
	_refresh()


# ------------------------------------------------------------ the zoom ladder
# The chart is the farthest of four distances (`ZoomLadder`): k 0 at rest, 1 at your star.
var _ladder_side: Control = null


func ladder_ready() -> bool:
	return _chart != null and _chart.size.x > 10.0


func ladder_picture() -> Rect2:
	return _chart.get_global_rect() if _chart != null else get_global_rect()


func ladder_scale() -> float:
	return _chart.zoom if _chart != null else 1.0


func ladder_anchor(_other: int, _seam: int, _design: String) -> Vector2:
	if not ladder_ready() or Run.map.is_empty():
		return get_global_rect().get_center()
	return _chart.global_position + _chart._screen_pos(Run.node_at())


func ladder_pre(_target: int, _seam: int, _design: String) -> float:
	return 1.0 if ladder_ready() and not Run.map.is_empty() else 0.0


var _lad_meet := Vector2.INF


func ladder_meet(at: Vector2, _world: Dictionary) -> void:
	_lad_meet = at


func ladder_cam_begin(_other: int, seam: int, design: String) -> void:
	if ladder_ready():
		# A short step toward your star, not the closest zoom, where the galaxy smears into blocks.
		var reach := 2.2 if seam == 1 and design == "A" else (3.0 if seam == 0 else 0.0)
		_chart.ladder_begin(Vector2.ZERO if _lad_meet == Vector2.INF else _lad_meet - _chart.get_global_rect().get_center(), reach)
		_lad_meet = Vector2.INF


func ladder_cam(k: float) -> void:
	if _chart != null:
		_chart.ladder_at(k)


## The key, corner toggles, YOU and scale bar fade with the camera move (`ZoomLadder`).
## The side bar and toolbar stay and swap in place (Jon, Oct 13).
## Why: docs/why/StarchartScreen.md#ladder-ui-fade
var _strip_row: Control = null
var _key_row: Control = null


func ladder_chrome(k: float) -> void:
	for c: CanvasItem in [_key_row, _region_btn, _reach_btn, _sight_btn]:
		ZoomLadder.fade_chrome(c, k)
	if _chart != null:
		_chart.ui_a = 1.0 - k
		_chart.queue_redraw()


## The side bar, for the ladder to swap in place (`SideSwap`).
func ladder_side() -> Control:
	return _ladder_side


## And the toolbar along the top -- LAYER, its pips, CORE, the view toggles --
## which decodes into the next screen's the same way (Jon: "these buttons").
func ladder_bar() -> Control:
	return _row_plate if _row_plate != null else _strip_row


## the toolbar row's plate, on the field (`NavField.row_plate`)
var _row_plate: PanelContainer = null


func ladder_spans() -> Vector2:
	return _chart.ladder_spans() if _chart != null else Vector2.ZERO


## How far across (0 to 1) the chart carries your star toward its middle; the
## map that takes over carries it the rest of the way.
func ladder_split(f: float) -> void:
	if _chart != null and not _chart._lad.is_empty():
		_chart._lad["split"] = clampf(f, 0.0, 1.0)


func ladder_cam_end() -> void:
	if _chart != null:
		_chart.ladder_end()


## THE CALM MOVE (`ZoomLadder`): your star is your ship out here.
func calm_begin() -> void:
	if ladder_ready():
		_chart.calm_begin()


func calm_ship() -> Vector2:
	return _chart.calm_star() if ladder_ready() else get_global_rect().get_center()


func calm_rest() -> Vector2:
	if _chart != null and _chart._lad.has("calm"):
		return _chart.calm_rest_star()
	return calm_ship()


func calm_at(p: Vector2, s: float) -> void:
	if _chart != null:
		_chart.calm_at(p, s)


func calm_end() -> void:
	if _chart != null:
		_chart.calm_end()


func _on_jump() -> void:
	if _selected >= 0:
		# `begin_jump` hands the sector a departure and spends nothing until the ship is gone.
		Router.begin_jump(_selected)


## Shape carries the type and tint the region, so no word sits under each node.
## MicroGauge is the heat and energy gauges shrunk to fit beside a star's name.
## Why: docs/why/StarchartScreen.md#glyph-and-gauge
class MicroGauge extends Control:
	enum Mode { DANGER, FUEL, UNAFFORDABLE }

	const CELL := Vector2(2, 5)
	const STEP := 3
	const CELL_BIG := Vector2(5, 8)
	const STEP_BIG := 7

	var cells: int = 10
	var filled: int = 0
	var mode: Mode = Mode.DANGER
	var big: bool = false

	func setup(n: int, f: int, m: Mode, large: bool = false) -> void:
		cells = maxi(1, n)
		filled = clampi(f, 0, cells)
		mode = m
		big = large
		var c := CELL_BIG if big else CELL
		var st := STEP_BIG if big else STEP
		custom_minimum_size = Vector2(cells * st - (st - int(c.x)), c.y + 2)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		queue_redraw()

	func _draw() -> void:
		var c := CELL_BIG if big else CELL
		var st := STEP_BIG if big else STEP
		var y: float = floor((size.y - c.y) * 0.5)
		for i in cells:
			var on := i < filled
			var col := Color("#1b2431")
			if on:
				match mode:
					Mode.FUEL:
						# Green: danger owns blue, amber and red, and shared amber blurred them.
						col = UITheme.GOOD
					Mode.UNAFFORDABLE:
						# Dimmed rather than reddened: red is reserved for
						# danger, so no colour in this panel means two things.
						col = UITheme.GOOD.darkened(0.55)
					_:
						# Danger reads warmer the deeper it runs, so the colour
						# says roughly what the count says before you count it.
						if i < 3:
							col = Color("#5d7a93")
						elif i < 6:
							col = UITheme.WARN
						else:
							col = UITheme.BAD
			draw_rect(Rect2(float(i * st), y, c.x, c.y), col, true)


class Glyph extends Control:
	## Free-standing pixel-map silhouettes with eleven inks, no tile plate under them.
	## Four inks drew a shape, not an object: the extra stops give the lit face and lip.
	## Why: docs/why/StarchartScreen.md#glyph-pixel-art

	var type: MapGen.NodeType = MapGen.NodeType.SYSTEM
	var tint: Color = Color.WHITE
	## a system of two suns (ruling 20): `_TWIN`, as the chart draws it
	var twin := false

	func setup(t: MapGen.NodeType, c: Color, two: bool = false) -> void:
		type = t
		tint = c
		twin = two
		custom_minimum_size = Vector2(13, 13)
		queue_redraw()

	func _draw() -> void:
		draw_glyph(self, Vector2.ZERO, type, tint, false, false, BAND, false, twin)

	## Hostile dart nosing left, as enemies face left everywhere else in the game.
	## Why: docs/why/StarchartScreen.md#glyph-pixel-art
	const _FIGHT := [
		".............",
		".........oooo",
		"........o%%%o",
		".....o%%%###o",
		"...o%%######o",
		".o%%##==####o",
		"o%####=~##*@o",
		".o--++++++::o",
		"...o--++++++o",
		".....o---+++o",
		"........o---o",
		".........oooo",
		"............."]

	## Hab ring with its lights on: warm pixels are the tell for the one friendly thing out here.
	## Why: docs/why/StarchartScreen.md#glyph-pixel-art
	const _STATION := [
		".............",
		"....ooooo....",
		"..oo%%%%%oo..",
		".o%%#*#*#%%o.",
		"o%%#ooooo#%%o",
		"o%#o..#..o#%o",
		"o##o.*@*.o##o",
		"o+#o..#..o#+o",
		"o++#ooooo#++o",
		".o++#*#*#++o.",
		"..oo+++++oo..",
		"....ooooo....",
		"............."]

	## Unknown signal as a radiating burst: each ray falls off along its length for depth.
	## Why: docs/why/StarchartScreen.md#glyph-pixel-art
	const _EVENT := [
		"......-......",
		"......+......",
		"..+...#...+..",
		"...#..#..#...",
		"....#.%.#....",
		".....%%%.....",
		"-+#%%*@*%%#+-",
		".....%%%.....",
		"....#.%.#....",
		"...#..#..#...",
		"..+...#...+..",
		"......+......",
		"......-......"]

	## Two suns (ruling 20, Oct 30): the burst with a small warm second star at lower right.
	## Same box, so nothing to click moves.
	## Why: docs/why/StarchartScreen.md#glyph-pixel-art
	const _TWIN := [
		"......-......",
		"......+......",
		"..+...#...+..",
		"...#..#..#...",
		"....#.%.#....",
		".....%%%.....",
		"-+#%%*@*%%#+-",
		".....%%%.....",
		"....#.%......",
		"...#..#...:..",
		"..+...#..:*:.",
		"......+...:..",
		"......-......"]

	## Not drawn since the type collapse; kept as authored art for the option detail view.
	## Delete them if that never happens.
	## Why: docs/why/StarchartScreen.md#glyph-pixel-art
	const _DERELICT := [
		".............",
		"..ooooo......",
		".o%%%%%oo....",
		".o%####%%oo..",
		"o%#+++##%%%o.",
		"o#++--++##%o.",
		"o+--..--++#o.",
		".o+-...-++#o.",
		"..o+--++##o.o",
		"...oo++##o.o.",
		".....oooo....",
		".............",
		"............."]

	## Accretion disc nearly edge-on with lensed arcs; the middle is left empty.
	## The glyph sits on the galaxy centre, so the transparent shadow frames the sky.
	## Why: docs/why/StarchartScreen.md#glyph-pixel-art
	const _GOAL := [
		".............",
		".....%%%.....",
		"...%%###%%...",
		"..%#.....#%..",
		".%#.......#%.",
		"%#.........#%",
		"*@@.......@@*",
		":*@@@@@@@@@*:",
		"+-.........-+",
		".+-.......-+.",
		"..+--...--+..",
		"...++---++...",
		".....---....."]

	## Open ring with beam ticks; the middle is empty so the pulsar's own flash stays visible.
	## The ticks are cold light: a neutron star is not a furnace.
	## Why: docs/why/StarchartScreen.md#glyph-pixel-art
	const _PULSAR := [
		".............",
		".....%%%.....",
		"...%%...%%...",
		"..%.......%..",
		".%.........%.",
		".#.........#.",
		"!=~%.....%~=!",
		".#.........#.",
		".+.........+.",
		"..+.......+..",
		"...++...++...",
		".....---.....",
		"............."]

	## Your own hull nosing right: unique by subtraction now the FIGHT dart is not drawn.
	## Why: docs/why/StarchartScreen.md#glyph-pixel-art
	const _START := [
		".............",
		"oooo.........",
		"o%%%o........",
		"o###%%%o.....",
		"o######%%o...",
		"o####==##%%o.",
		"o@*##~=####%o",
		"o::++++++--o.",
		"o++++++--o...",
		"o+++---o.....",
		"o---o........",
		"oooo.........",
		"............."]

	static func art_for(t: MapGen.NodeType, twin: bool = false) -> Array:
		if twin and t == MapGen.NodeType.SYSTEM:
			return _TWIN
		match t:
			MapGen.NodeType.STATION: return _STATION
			MapGen.NodeType.CORE: return _GOAL
			MapGen.NodeType.PULSAR: return _PULSAR
			MapGen.NodeType.START: return _START
			# Every system wears one mark: what waits there is `options`, which the chart hides.
			# Why: docs/why/StarchartScreen.md#glyph-pixel-art
			_: return _EVENT

	## The emissive band's own colour, where a caller does not give one.
	const BAND := Color("#fff6e2")

	## One grey for a star in reach that a jump refuses as too deep, so it reads as off.
	## Jon picked this darkest of three (Oct 30, 'Gray: B2'); it was #4a4e55.
	## Why: docs/why/StarchartScreen.md#too-deep-grey
	const DIM := Color("#303236")

	static func draw_glyph(ci: CanvasItem, o: Vector2, t: MapGen.NodeType,
			tint_in: Color, here: bool, selected: bool, band: Color = BAND,
			dim: bool = false, twin: bool = false) -> Color:
		var ramp := ramp_for(tint_in, band, dim)
		var art := art_for(t, twin)
		for y in art.size():
			var row: String = art[y]
			for x in row.length():
				var ch := row[x]
				if ch == ".":
					continue
				ci.draw_rect(Rect2(o + Vector2(x, y), Vector2.ONE),
					ramp.get(ch, ramp["#"]) as Color, true)

		draw_brackets(ci, o, here, selected)
		# (the body's ink, for `MapChart.drawn_ink`)
		return ramp["#"]

	## The inks a glyph is drawn in, by its pixel map's letters.
	static func ramp_for(tint_in: Color, band: Color = BAND, dim: bool = false) -> Dictionary:
		# Tints are lifted so a glyph is not a smudge; the ramp is built per call.
		# lightened(0.62) against darkened(0.52) is the break that survives 13 pixels.
		# Why: docs/why/StarchartScreen.md#glyph-ramp
		if dim:
			# Too deep: one grey ramp with no lift, as a lifted grey read as a lit star.
			var face := DIM.lightened(0.3)
			var wall := DIM.darkened(0.3)
			return {
				"o": Color("#070b11"),
				"%": face,
				"#": DIM,
				"+": wall,
				"-": DIM.darkened(0.55),
				"*": DIM,
				"@": face,
				":": wall,
				"=": DIM,
				"~": wall,
				"!": face,
			}
		return {
			"o": Color("#070b11"),
			"%": tint_in.lightened(0.62),
			"#": tint_in.lightened(0.34),
			"+": tint_in.darkened(0.22),
			"-": tint_in.darkened(0.52),
			"*": UITheme.HOT,
			"@": band,
			":": UITheme.EMBER,
			"=": Color("#8ec8e6"),
			"~": Color("#3a6b8c"),
			"!": Color("#dff6ff"),
		}


	## A one pixel dark rim on four sides only: eight sides filled in between a star's spikes.
	## Worked out once per glyph; its darkness depends on the sky under it.
	## Why: docs/why/StarchartScreen.md#glyph-halo
	static var _halo_cache: Dictionary = {}

	static func draw_halo(ci: CanvasItem, o: Vector2, t: MapGen.NodeType, col: Color, twin: bool = false) -> void:
		var hk: int = int(t) * 2 + (1 if twin else 0)
		var pts: PackedVector2Array = _halo_cache.get(hk, PackedVector2Array())
		if pts.is_empty():
			var art := art_for(t, twin)
			var on := {}
			for y in art.size():
				var row: String = art[y]
				for x in row.length():
					if row[x] != ".":
						on[Vector2i(x, y)] = true
			var rim := {}
			for c: Vector2i in on:
				for dq: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var q := c + dq
					if not on.has(q):
						rim[q] = true
			for q: Vector2i in rim:
				pts.append(Vector2(q))
			_halo_cache[hk] = pts
		for q in pts:
			ci.draw_rect(Rect2(o + q, Vector2.ONE), col, true)

	## Corner brackets, not a box. A box is a tile by another name, and the
	## tile is what we just removed.
	static func draw_brackets(ci: CanvasItem, o: Vector2, here: bool, selected: bool) -> void:
		if here or selected:
			var c := UITheme.FLARE if here else UITheme.ICE
			var n := 4.0
			var w := 16.0
			for raw in [
					[Vector2(0, 0), Vector2(1, 1)],
					[Vector2(w, 0), Vector2(-1, 1)],
					[Vector2(0, w), Vector2(1, -1)],
					[Vector2(w, w), Vector2(-1, -1)]]:
				var pair: Array = raw
				var k: Vector2 = o - Vector2(2, 2) + (pair[0] as Vector2)
				var d: Vector2 = pair[1]
				ci.draw_rect(Rect2(k + Vector2(0, -1 if d.y < 0 else 0),
					Vector2(n * d.x, 1)), c, true)
				ci.draw_rect(Rect2(k + Vector2(-1 if d.x < 0 else 0, 0),
					Vector2(1, n * d.y)), c, true)


## The sky is `ChartSky`, in the sector map's style and angle; it replaced four layers.


## The reticle sits behind the parent, so it runs under systems and tooltips, not through them.
class Crosshair extends Control:
	var chart: MapChart

	## Matches the sector map's cursor: lines run along the plane's diagonals at its slant.
	## Dashes count from the frame edge so they hold still; none cross the black hole's shadow.
	## Why: docs/why/StarchartScreen.md#crosshair
	const DASH := 2.0
	const GAP := 3.0
	const NOTCH := 4.0
	const CROSS_ALPHA := 0.4
	const NOTCH_ALPHA := 0.8
	const RING_ALPHA := 0.6
	const RING_R := 9.0

	func _draw() -> void:
		if chart == null or chart._cursor.x < 0.0:
			return
		var c := chart._cursor.floor()
		var line := Color(UITheme.ICE, CROSS_ALPHA)
		var notch := Color(UITheme.ICE, NOTCH_ALPHA)
		var tilt := ChartSky.TILT
		var hc := chart.centre_px() + chart._solid_px(Vector2.ZERO)
		var hr := chart._hole_px() + 1.0
		var hr2 := hr * hr if hr > 1.0 else -1.0
		for slope: float in [tilt, -tilt]:
			# one pixel a column, so the line steps; the dash pattern counts
			# columns from the frame's edge, so it holds still
			var x := 0.0
			while x < size.x:
				if fmod(x, DASH + GAP) < DASH:
					var y := floorf(c.y + (x - c.x) * slope)
					if y >= 0.0 and y < size.y and Vector2(x, y).distance_squared_to(hc) > hr2:
						draw_rect(Rect2(x, y, 1.0, 1.0), line)
				x += 1.0
			# a notch where the line meets each side of the frame
			for side: float in [0.0, size.x - NOTCH]:
				var y2 := floorf(c.y + (side - c.x) * slope)
				if y2 >= 0.0 and y2 < size.y:
					for k in int(NOTCH):
						draw_rect(Rect2(side + k, floorf(c.y + (side + k - c.x) * slope), 1.0, 1.0), notch)
		# the ring, flat on the plane: a circle seen at the plane's tilt
		var ring := Color(UITheme.ICE, RING_ALPHA)
		var n := 40
		for i in n:
			var a := float(i) / n * TAU
			var q := (c + Vector2(cos(a) * RING_R, sin(a) * RING_R * tilt)).floor()
			if q.distance_squared_to(hc) > hr2:
				draw_rect(Rect2(q, Vector2.ONE), ring)


## In the tree only so quitting waits for the worker: an unwaited task hangs the process at exit.
class ChartAhead extends Node:
	var chart: MapChart = null
	var task := -1
	var key := ""
	var galaxy := ""
	var snap: Dictionary = {}

	func _process(_delta: float) -> void:
		if task >= 0 and WorkerThreadPool.is_task_completed(task):
			finish()

	## On the main thread: the worker waited for (at once, if it is done), the
	## field's lists taken, the chart it was built on freed.
	func finish() -> void:
		if task >= 0:
			WorkerThreadPool.wait_for_task_completion(task)
			task = -1
		if chart != null:
			snap = chart._snapshot_sky()
			chart.free()
			chart = null
		set_process(false)

	func _exit_tree() -> void:
		finish()
