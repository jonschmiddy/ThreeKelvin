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
	_jump.custom_minimum_size = Vector2(0, 24)
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
			_dest_blurb.text = GalaxyGen.blurb(Run.galaxy_kind)
			# The count stays: blanking it left the start of a run with a list and no number above.
			# Why: docs/why/StarchartScreen.md#neighbour-count-hint
		else:
			_dest_name.text = "NOWHERE"
			_class("")
			_dest_blurb.text = "No jump you can afford. The tank is dry."
			# Not repeated here, as the header already said it: the same sentence twice.
			_hint.text = ""
		_jump.disabled = true
		return

	var t: MapGen.MapNode = Run.map[_selected]

	# A system known only through a contract shows why it is circled and nothing more.
	# The jump button is left alone: reach is about fuel and adjacency, not knowledge.
	# Why: docs/why/StarchartScreen.md#contract-only-systems
	if Run.known_only_by_contract(_selected):
		var job := Run.contract_at(_selected)
		_dest_name.text = MapGen.star_name(t)
		_class("%s - POSITION ONLY" % Run.galaxy_name)
		_dest_blurb.text = job.text
		_rows.add_child(_row("CIRCLED BY",
			DB.manufacturer_name(job.manufacturer).to_upper(),
			DB.manufacturer_colour(job.manufacturer)))
		_rows.add_child(_row("PAYS", "%d CREDITS" % job.pay))
		# Said plainly rather than left as four blank rows. An absence the player
		# can read is information; an absence they have to notice is a bug.
		_rows.add_child(_row("SURVEY", "NONE"))
		_hint.text = "They gave you a position and nothing else."
		_jump.disabled = not Run.can_jump_to(t)
		_berth_lock()
		return

	# The name is the place; the classification is what kind of place it is -
	# how built up, how policed, and whose it is, in that order.
	_dest_name.text = MapGen.star_name(t)
	# No class line: only 7.0% of systems are in a cloud, so it was empty 19 times in 20.
	# An empty Label still reserves a line, and the WARNING group already names the nebula.
	# Why: docs/why/StarchartScreen.md#class-line-removed
	_class("")
	_dest_blurb.text = MapGen.place_blurb(t)

	# Rows run what it is, who is there, what it costs: the order the questions arrive.
	# Gaps are four pixels, not rules: three separators in a narrow panel read as three panels.
	# Why: docs/why/StarchartScreen.md#row-order
	_rows.add_child(_row("CONTAINS", _contains(t)))
	# Says what is in the sky, which decides what you are offered (corona, wind, slipping orbit).
	# In the star's own colour; BINARY for two suns (ruling 20; Jon, Nov 1).
	# Why: docs/why/StarchartScreen.md#star-row
	_rows.add_child(_row("STAR", MapGen.BINARY if t.twin and MapGen.twin_ok(t) else MapGen.star_kind(t), MapGen.star_colour(t)))
	# Only when there is one: NONE would be blank four times in nine and say nothing.
	if t.gas_giant:
		_rows.add_child(_row("BODIES", "GAS GIANT"))
	if t.near_pulsar and t.type != MapGen.NodeType.PULSAR:
		_rows.add_child(_row("NEARBY", "PULSAR", Color("#8fd2e0")))
	# No nebula row: `MapGen.hazards()` already says NEBULA in the WARNING group.
	# Why: docs/why/StarchartScreen.md#no-nebula-row

	_rows.add_child(_gap())
	# The three axes get their own rows, so nobody scans a run-on class line for how policed.
	if t.type == MapGen.NodeType.CORE:
		# Development and security are questions about a society. There is not
		# one here.
		_rows.add_child(_row("STRUCTURE", "PRECURSOR RUINS"))
		_rows.add_child(_row("SECURITY", "NONE", Color("#c8734f")))
		_rows.add_child(_row("OPERATORS", "NOTHING LIVING"))
	else:
		_rows.add_child(_row("DEVELOPMENT", MapGen.development_name(t.development).to_upper()))
		_rows.add_child(_row("SECURITY", MapGen.security_name(t.security).to_upper(),
			Color("#c8734f") if t.security <= 2 else UITheme.CHILL))
		# NONE, not UNCLAIMED: 18% of systems printed UNCLAIMED on two consecutive rows.
		# The row stays: 143 systems have no berths yet are real outposts or settlements.
		# Why: docs/why/StarchartScreen.md#none-vs-unclaimed
		var who := "NONE"
		# A dock desk (Jon, Nov 3: every station posts work): nobody holds the place.
		# Said, or the chart draws a delivery square on a place it calls unoperated.
		# Why: docs/why/StarchartScreen.md#dock-desks
		var desk := Contracts.dock_desk(t)
		if desk != &"":
			who = "NONE, %s DESK" % DB.short_name(DB.manufacturer_name(desk)).to_upper()
		if not t.berths.is_empty():
			var names: Array[String] = []
			for m in t.berths:
				names.append(DB.short_name(DB.manufacturer_name(m)).to_upper())
			who = " / ".join(names)
		_rows.add_child(_row("OPERATORS", who))
		# Sits under OPERATORS as a reading of it. Seen before the jump, a haul is a plan.
		var trade := Market.trade_line(t)
		if not trade.is_empty():
			_rows.add_child(_row("MARKET", trade, Color("#d99b29")))

	_rows.add_child(_gap())
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
		var heading := "LATERAL" if t.layer == here.layer \
			else ("COREWARD  L%d" if t.layer > here.layer else "OUTWARD  L%d") % (t.layer + 1)
		_rows.add_child(_row("HEADING", heading, UITheme.FLARE if t.layer > here.layer else UITheme.CHILL))

	# Hazards last, so the thing that might kill you is where the eye stops. The key shows once.
	var hz := MapGen.hazards(t)
	for i in hz.size():
		_rows.add_child(_row("WARNING" if i == 0 else "", hz[i], _WARN))

	# Names what is in reach: a bare count left you hunting the chart for the places.
	_fill_neighbours(here)

	# Two different reasons a jump is impossible, and they need different words:
	# no route at all, versus a route you cannot currently pay for.
	_jump.disabled = not Run.can_jump_to(t)
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


## Docked, a jump reads DOCKED and says how to leave; UNDOCK is the only way (Jon, Oct 27).
## With crates still on the pad it reads CANNOT UNDOCK.
## Why: docs/why/StarchartScreen.md#berth-lock
func _berth_lock() -> void:
	_jump.tooltip_text = ""
	if _jump.disabled or Router.may_cast_off():
		return
	_jump.disabled = true
	if Router.docked:
		_jump.text = "DOCKED"
		_jump.tooltip_text = Widgets.tip(Router.DOCKED_LINE)
	else:
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


## Pulsar and gamma-ray flashes over the 2x2 sky and under the systems; redrawn only while lit.
class Flashes extends Node2D:
	var chart: MapChart
	var _was := false

	func _process(_delta: float) -> void:
		if chart == null:
			return
		var lit := chart._flash_lit(MapChart.clock())
		if lit or _was:
			queue_redraw()
		_was = lit

	func _draw() -> void:
		if chart != null:
			chart._draw_flashes(self, MapChart.clock())


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


class MapChart extends Control:
	## Presentation only: MapGen still lays the run out in layers, so the sim sees no difference.

	signal node_picked(index: int)

	## The sky's clock; a harness sets `clock_override` to photograph the same instant. Off in game.
	static var clock_override: float = -1.0

	static func clock() -> float:
		if clock_override >= 0.0:
			return clock_override
		return float(Time.get_ticks_msec()) * 0.001

	## Per-layer drawing time, for `-- chartbench`. Off in the game: when it is
	## off each layer pays one bool test.
	static var prof := false
	static var prof_us: Dictionary = {}

	static func prof_add(key: String, us: int) -> void:
		prof_us[key] = int(prof_us.get(key, 0)) + us

	## Emitted on a drag, never a glide: a toggle that unticked itself would fight its tween.
	signal view_dragged
	## A click on empty space — not the end of a drag. Puts the chart back to
	## just the galaxy.
	signal cleared()

	## A missed key-up (WIN+SHIFT+S) leaves `_walk` down and the chart panning on its own.
	## Polled only to cancel movement, so a keystroke for a focused field cannot drive the chart.
	## Why: docs/why/StarchartScreen.md#held-keys
	func _settle_walk() -> void:
		if _walk == Vector2.ZERO:
			return
		if _walk.y < 0.0 and not Keys.held(&"chart_up"):
			_walk.y = 0.0
		if _walk.y > 0.0 and not Keys.held(&"chart_down"):
			_walk.y = 0.0
		if _walk.x < 0.0 and not Keys.held(&"chart_left"):
			_walk.x = 0.0
		if _walk.x > 0.0 and not Keys.held(&"chart_right"):
			_walk.x = 0.0


	func _walk_view(delta: float) -> void:
		_settle_walk()
		if _walk == Vector2.ZERO:
			return
		var before := pan
		pan -= _walk.normalized() * WALK_PX_PER_SEC * delta
		_clamp_pan()
		sky_pan += pan - before
		if pan != before:
			view_dragged.emit()
			_repaint_galaxy()

	## Low enough to frame the whole galaxy at once, which is how you plan a
	## route; 1.0 is the reading zoom.
	const ZOOM_MIN := 0.42
	const ZOOM_MAX := 6.0

	const DISC := 2.05

	## Turns normalised `gal` into real units so a bar can say a number.
	## 50,000 is chosen, not measured; the sim never reads it, so it only relabels.
	## Why: docs/why/StarchartScreen.md#scale-bar
	const RADIUS_LY := 50000.0

	## Bar lengths worth printing, stepping 1-2-5 as a map scale should.
	const BAR_STEPS := [10.0, 20.0, 50.0, 100.0, 200.0, 500.0, 1000.0,
		2000.0, 5000.0, 10000.0, 20000.0, 50000.0]
	const BAR_MAX_PX := 140.0
	const BAR_PAD := 12.0
	## How far the scale's label reaches above the rule: the 7px baseline
	## offset draw_string is given, plus the 8px face it is drawn at.
	const BAR_LABEL_H := 15.0

	## Halved: layers disagreeing on rate carries the depth, and full amplitude read as dragging.
	## One constant, so the two fields move as one sky.
	## Why: docs/why/StarchartScreen.md#sky-parallax
	const PARALLAX := 0.5

	## Half again for the far galaxies, so they read as behind the star shells, not just behind.
	## Why: docs/why/StarchartScreen.md#sky-parallax
	const FAR_PARALLAX := PARALLAX * 0.5

	## Every shape parameter comes from GalaxyGen, so a new galaxy type is a
	## dictionary entry rather than another branch in here.
	func _g() -> Dictionary:
		return Run.galaxy if _ahead_src.is_empty() else _ahead_src.galaxy

	func _squash() -> float:
		return _g().squash

	func _arms() -> int:
		return maxi(1, int(_g().arms))

	## The spiral has one definition, in MapGen, because system placement is
	## derived from it too and the two must not drift.
	func _shape_angle(r_norm: float, arm: int, along: float) -> float:
		if _ahead_src.is_empty():
			return MapGen.shape_angle(r_norm, arm, along)
		return MapGen.shape_angle_in(_ahead_src.galaxy, float(_ahead_src.spin), r_norm, arm, along)

	## Copied on the main thread before the worker starts, so a new run or load cannot change it.
	var _ahead_src: Dictionary = {}

	func _gseed() -> int:
		return Run.galaxy_seed if _ahead_src.is_empty() else int(_ahead_src.seed)

	func _gmap() -> Array:
		return Run.map if _ahead_src.is_empty() else _ahead_src.map

	func _clouds() -> Array:
		return NebulaField.clouds() if _ahead_src.is_empty() else (_ahead_src.clouds as Array).duplicate()

	## When false the chart draws the galaxy and nothing else — no systems, no
	## routes, no trail, no tooltip.
	var show_icons: bool = true
	## A key colour (pure green) that `chart_marks.gdshader` turns into the void over bright sky.
	## A solid rim everywhere was too thick (Jon).
	## Why: docs/why/StarchartScreen.md#mark-halo-key
	const _UNDER := Color(0.0, 1.0, 0.0, 0.65)
	const _UNDER_SOFT := Color(0.0, 1.0, 0.0, 0.45)
	const MARKS_SH := preload("res://shaders/chart_marks.gdshader")

	## False on the title screen, which draws its own galaxy over the leftover run map.
	var run_galaxy: bool = true
	## Off where the chart is only a backdrop: WASD must not work in the title menu (Jon).
	var keys: bool = true
	## Dev only, restored: the link overlay showed lines going nowhere while systems stayed hidden.
	## Reveals and never travels: jumping is still gated on `Run.can_jump_to()`.
	## Why: docs/why/StarchartScreen.md#show-all-debug
	var show_all: bool = false
	## Debug: draw every link in the map, not only the ones you could take.
	## Off by default — it is a diagnostic, not a view.
	var show_links: bool = false
	var selected: int = -1
	var hovered: int = -1
	var zoom: float = ZOOM_MIN
	var pan: Vector2 = Vector2.ZERO

	## 320 px a second is the pace of reading along a route, not of flying.
	## Divided by zoom, so it moves the same galaxy distance at every magnification.
	## Why: docs/why/StarchartScreen.md#wasd-pan-speed
	const WALK_PX_PER_SEC := 320.0
	## Which of WASD are down. Read every frame rather than on the event, so
	## holding two moves diagonally and releasing one keeps the other going.
	var _walk: Vector2 = Vector2.ZERO
	## Follows dragging only: zooming moves `pan`, and that slid the sky on the wheel.
	var sky_pan: Vector2 = Vector2.ZERO

	var _dragging: bool = false
	var _drag_from: Vector2 = Vector2.ZERO
	var _press_at: Vector2 = Vector2.ZERO
	var _drag_moved: bool = false
	## Eases in while the cursor rests on a system, so a tooltip does not flicker between points.
	var _hover_t: float = 0.0
	## Quest tags sit clear of what must not be covered; the picked route starts at YOU.
	var quest_tags: Array = []
	var quest_route: Array[int] = []
	## Where each tag was laid, local, in `quest_tags` order: what A.S.H. keeps
	## off and the tests read.
	var quest_rects: Array = []
	## The global rects a tag must keep off (`StarchartScreen._quest_avoid`),
	## asked each time the tags are laid: A.S.H. comes and goes.
	var quest_avoid: Callable
	## Every star a click could pick, as last drawn (screen positions), for the
	## tags to keep off.
	var _pickable: PackedVector2Array = PackedVector2Array()
	## What the tests read, so they check the picture's colours and not the rule.
	var drawn_ink: Dictionary = {}
	var drawn_dim: Dictionary = {}

	# ---- the instrument: reticle, scan and zoom tick. The navigated chart only
	# One wheel notch. A zoom level is a power of this, so the tick lands once per notch.
	# Why: docs/why/StarchartScreen.md#zoom-tick
	const ZOOM_STEP := 1.12
	## Faint: the reticle is felt more than seen. Dashed, so a little higher
	## than a solid line would be for the same presence.
	const CROSS_ALPHA := 0.12
	## The notches where the reticle meets the frame: the one bright part.
	const NOTCH_ALPHA := 0.45
	## The scan ticks every this many pixels of pointer travel, so the sound is the distance.
	const SCAN_STEP := 26.0
	## And no faster than this, or a flick becomes a buzz.
	const SCAN_LIMIT_MS := 38
	var _cross: Crosshair = null
	## Where the pointer is, in chart space; x < 0 when it is off the chart.
	var _cursor := Vector2(-1.0, -1.0)
	var _scan_px := 0.0
	var _tick_level := 0
	## No tick until this moment: opening the chart restores or frames the view
	## in one step, and nobody zoomed.
	var _tick_from := 0
	## Checked once: a chart opened before the tick file exists must not warn
	## "missing sfx" on every notch.
	var _has_tick := false
	var _has_scan := false

	func _ready() -> void:
		# the marks' dark rims, strong only over bright sky (`_UNDER`)
		var mm := ShaderMaterial.new()
		mm.shader = MARKS_SH
		material = mm
		if not remembers_view:
			return
		_cross = Crosshair.new()
		_cross.chart = self
		_cross.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cross.show_behind_parent = true
		add_child(_cross)
		_tick_level = _zoom_level()
		_tick_from = Time.get_ticks_msec() + 400
		_has_tick = ResourceLoader.exists(Audio.SFX_PATH % &"chart_tick")
		_has_scan = ResourceLoader.exists(Audio.SFX_PATH % &"chart_scan")

	func _zoom_level() -> int:
		return roundi(log(maxf(zoom, 0.0001)) / log(ZOOM_STEP))

	## Once a frame, from `_process`, so every way the zoom moves -- wheel,
	## glide, framing -- ticks, the same argument as the view memory there.
	func _instrument(_delta: float) -> void:
		if not remembers_view:
			return
		var level := _zoom_level()
		if level != _tick_level:
			if _has_tick and Time.get_ticks_msec() >= _tick_from:
				Audio.play(&"chart_tick", 0.03, 28)
			_tick_level = level
		# One tick a frame at most, so a hitch cannot queue a burst; the
		# remainder carries, so slow travel still adds up to a tick.
		if _scan_px >= SCAN_STEP:
			_scan_px = fmod(_scan_px, SCAN_STEP)
			if _has_scan:
				Audio.play(&"chart_scan", 0.08, SCAN_LIMIT_MS)

	## The sky, behind everything the chart draws itself (`ChartSky`), and the
	## flashes over it.
	var _sky: ChartSky
	## ON THE FIELD (`NavField`, the star chart's): the sky's own far stars off and
	## its empty sky keyed away, so the field's stars are the chart's
	var on_field := false:
		set(v):
			on_field = v
			if _sky != null:
				_sky.material = NavField.key_material() if v else null
	## Where the sky is drawn, in chart px; empty means the chart's own rect.
	var sky_out := Rect2()
	var _sky_host: Node2D = null

	## The sky moved behind the whole screen (`host`, the screen's first child),
	## kept on the chart's own px every frame (`_host_follow`).
	func host_sky(host: Node2D) -> void:
		_sky_host = host
		if _sky != null:
			_sky.get_parent().remove_child(_sky)
			host.add_child(_sky)

	func _host_follow() -> void:
		if _sky_host == null or not is_instance_valid(_sky_host) or not is_inside_tree():
			return
		var par := _sky_host.get_parent() as CanvasItem
		var at := global_position - (par.get_global_transform().origin if par != null else Vector2.ZERO)
		if _sky_host.position != at:
			_sky_host.position = at
		var c := Router.content.get_global_rect() if Router.content != null else get_global_rect()
		var so := Rect2(c.position - global_position, c.size)
		if so != sky_out:
			sky_out = so
			if _sky != null:
				_sky.queue_push()
				_sky.queue_redraw()
	var _flash: Flashes
	## Cached: wanted for every system on every redraw and every mouse motion.
	var _polar_cache: Dictionary = {}
	## The cloud under the cursor, if any.
	var _neb_hot: String = ""
	var _neb_hot_emit: bool = false
	var _neb_hot_kind: String = ""
	var _neb_hot_at: Vector2 = Vector2.ZERO

	## The galaxy as plain data, built once per galaxy rather than re-derived
	## per repaint. Re-deriving cost about 150ms a frame.
	var _star_pos: PackedVector2Array = PackedVector2Array()
	var _star_col: PackedColorArray = PackedColorArray()
	var _star_big: PackedByteArray = PackedByteArray()
	## Skipped during a drag: the dim wash carries no shape and costs over half a repaint.
	## Halving the whole field visibly dimmed the galaxy, so only this tier goes.
	## Why: docs/why/StarchartScreen.md#faint-star-tier
	var _star_dim: PackedByteArray = PackedByteArray()
	## Kept because the split decides which random numbers each star draws, so how the galaxy looks.
	var _core_skipped: int = 0
	## Kept as the real stars: a gold stand-in broke the blue-white lane on edge-on galaxies.
	## Why: docs/why/StarchartScreen.md#core-stars
	var _core_rad: PackedFloat32Array = PackedFloat32Array()
	var _core_col: PackedColorArray = PackedColorArray()
	## Size class travels with them, so a swallowed gas block comes back as a
	## gas block rather than as a one-pixel star.
	var _core_size: PackedByteArray = PackedByteArray()
	## Keeps each star's angle: a hashed angle broke the arms at the core and bunched an arc.
	## Why: docs/why/StarchartScreen.md#core-stars
	var _core_ang: PackedFloat32Array = PackedFloat32Array()
	## Each cluster's centre and its `_star_pos` range; the sky turns a cluster as one ball.
	var _glob_c: PackedVector2Array = PackedVector2Array()
	var _glob_i: PackedInt32Array = PackedInt32Array()
	var _star_key: String = ""

	## A list, so the cache is saved and restored as a set: a missed field draws stale dust lanes.
	## Only Packed arrays and ints: they snapshot, where an Array or Dictionary would alias.
	## Why: docs/why/StarchartScreen.md#sky-cache
	const SKY_FIELDS: Array[String] = [
		"_star_pos", "_star_col", "_star_big", "_star_dim",
		"_core_skipped", "_core_rad", "_core_col", "_core_size", "_core_ang",
		"_glob_c", "_glob_i",
		"_dark_c", "_dark_r",
		"_neb_pos", "_neb_top", "_neb_name", "_pulsar",
	]

	## Static: Router builds a new screen every visit, so an instance cache was lost each time.
	## Keyed by panel width as well as galaxy, so a resize still rebuilds.
	## Why: docs/why/StarchartScreen.md#sky-cache
	static var _sky_cache: Dictionary = {}
	## A run is one galaxy, so a cache for another is dropped wholesale, not accumulated.
	static var _sky_galaxy: String = ""
	## Dark clouds in drawn galaxy space, as flat lobes. See _extinct.
	var _dark_c: PackedVector2Array = PackedVector2Array()
	var _dark_r: PackedFloat32Array = PackedFloat32Array()

	## Only the name position and the supernova pulsar survive as objects; the rest is pixels.
	var _neb_pos: PackedVector2Array = PackedVector2Array()
	## Measured off the pixels that survived the dither: the nominal radius hung labels 200 px high.
	## Why: docs/why/StarchartScreen.md#nebula-label-height
	var _neb_top: PackedFloat32Array = PackedFloat32Array()
	var _neb_name: PackedStringArray = PackedStringArray()
	var _pulsar: PackedVector2Array = PackedVector2Array()

	## The star field's LCG behind two methods; the original passes keep their own copy.
	var _rng: int = 0

	## Behind the parent's draw; Godot keeps the draw list, so hover repaints glyphs only.
	func _make_backdrop() -> void:
		_sky = ChartSky.new()
		_sky.chart = self
		_sky.show_behind_parent = true
		add_child(_sky)
		# The sky draws pulsar beats and supernovae now; these strobes would double every pulsar.
		# The class stays, unused, for the harnesses that time it.
		# Why: docs/why/StarchartScreen.md#flashes-class
		_flash = null

	## `_build_stars` costs 350 to 420 ms and landed on whichever frame first painted the sky.
	## Calling it here moves that cost to a frame the caller chooses.
	## Why: docs/why/StarchartScreen.md#warm-sky
	func warm_sky() -> void:
		_build_stars()
		_ensure_gpu()

	## Whether the sky is drawn as it is meant to be, palette and all.
	func sky_drawn() -> bool:
		return _sky != null and _sky.ready_to_draw()

	## Builds the run's star field on a worker while the hull is picked (Oct 27, Jon's Mac).
	## Opening the chart held the screen 300 to 560 ms; now it finds the field in the cache.
	## Why: docs/why/StarchartScreen.md#chart-built-ahead
	const CHART_AT := Vector2(655.0, 419.0)
	## The navigated chart's size, the last time it built its field.
	static var last_size := Vector2.ZERO
	static var ahead_always := false
	## How many fields a drawn chart built itself, on the main thread (a test's).
	static var built_here := 0
	static var _ahead: ChartAhead = null

	static func build_ahead(at: Vector2 = Vector2.ZERO) -> void:
		if not ahead_always and (DisplayServer.get_name() == "headless" \
				or "sim" in OS.get_cmdline_user_args()):
			return
		_drop_ahead()
		if Run.map.is_empty() or Run.galaxy.is_empty():
			return
		var sz := at
		if sz == Vector2.ZERO:
			sz = last_size if last_size != Vector2.ZERO else CHART_AT
		var mc := MapChart.new()
		mc.size = sz
		var galaxy := "%d|%d" % [Run.galaxy_kind, Run.galaxy_seed]
		var key := "%s|%.1f|%.2f" % [galaxy, mc._radius() * DISC, mc._squash()]
		if galaxy == _sky_galaxy and _sky_cache.has(key):
			mc.free()
			return
		# (copied here, on the main thread: the worker reads nothing else)
		mc._ahead_src = {"galaxy": Run.galaxy.duplicate(true), "seed": Run.galaxy_seed,
			"spin": Run.galaxy_spin, "map": Run.map.duplicate(), "clouds": NebulaField.clouds()}
		var w := ChartAhead.new()
		w.name = "ChartAhead"
		w.chart = mc
		w.key = key
		w.galaxy = galaxy
		w.task = WorkerThreadPool.add_task(mc._build_field, false, "chart star field ahead")
		_ahead = w
		# (deferred: NEW RUN can come from Main's own _ready, with `-- nolauncher`,
		# while the root is still setting up its children)
		(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(w)

	## Waits for the worker if still going; a field built for another galaxy is left be.
	static func _take_ahead() -> void:
		if _ahead == null or not is_instance_valid(_ahead):
			_ahead = null
			return
		if _ahead.galaxy != _sky_galaxy:
			return
		_ahead.finish()
		if not _ahead.snap.is_empty():
			_sky_cache[_ahead.key] = _ahead.snap
		_ahead.queue_free()
		_ahead = null

	static func _drop_ahead() -> void:
		if _ahead != null and is_instance_valid(_ahead):
			_ahead.finish()
			_ahead.queue_free()
		_ahead = null

	## 0 is every frame; the title asks for a thirtieth, which is all a backdrop needs.
	func set_anim_interval(seconds: float) -> void:
		if _sky != null:
			_sky.interval = seconds

	## An extra turn on top of `turn`; kept so a harness can set an angle to photograph.
	func set_sky_rotation(r: float) -> void:
		sky_angle = r
		_repaint_galaxy()

	## 0.5 puts the rim at the near edge. `ex` is the nominal radius, so full pan shows empty sky.
	## Lower it if drifting into the void feels like being lost.
	## Why: docs/why/StarchartScreen.md#pan-slack
	const PAN_SLACK := 0.5

	## Whether each ring is drawn. Owned by the screen's corner toggles.
	var show_sight := true
	var show_reach := true

	## An extra angle on the galaxy's turn, radians. See set_sky_rotation.
	var sky_angle: float = 0.0
	## Redrawn when the turn moves the furthest system half a pixel, so a still chart is free.
	var _drawn_turn: float = 0.0

	## The sky gets the view at frame end, so a glide that moves it last still lands on its frame.
	func _repaint_galaxy() -> void:
		_polar_cache.clear()
		_drawn_turn = turn()
		if _sky != null:
			_sky.queue_push()
			_sky.queue_redraw()
		queue_redraw()

	## The same, for when the SCREEN changes rather than the view: the sky's
	## viewport is sized to the chart.
	func _repaint_sky() -> void:
		_repaint_galaxy()

	func _process(delta: float) -> void:
		_host_follow()
		_walk_view(delta)
		_instrument(delta)
		# Recorded once a frame: hooking every mutation (wheel, drag, glide) would miss one.
		# Not while the zoom ladder holds the view.
		# Why: docs/why/StarchartScreen.md#remembered-view
		if remembers_view and size.x > 0.0 and _lad.is_empty():
			StarchartScreen._view_zoom = zoom
			StarchartScreen._view_pan = pan
			StarchartScreen._view_map = Run.map.size()
		# Redrawn when the turn moves the furthest system half a pixel (about 1 Hz zoomed out).
		var tn := turn()
		if absf(angle_difference(_drawn_turn, tn)) * _radius() * DISC * zoom >= 0.5:
			_drawn_turn = tn
			queue_redraw()
		var target: float = 1.0 if hovered >= 0 else 0.0
		if is_equal_approx(_hover_t, target):
			return
		_hover_t = move_toward(_hover_t, target, delta * 9.0)
		queue_redraw()

	func _init() -> void:
		custom_minimum_size = Vector2(0, 220)
		mouse_filter = Control.MOUSE_FILTER_STOP
		clip_contents = true
		_make_backdrop()

	func set_state(sel: int) -> void:
		selected = sel
		queue_redraw()

	## For a sky on a control bigger than the view: `_radius()` is nearly twice the screen's.
	## A zoom picked against the chart put the title galaxy 1.6 screen-widths across.
	## Why: docs/why/StarchartScreen.md#framing-the-title
	func frame_to(screen: Vector2, fill: float) -> void:
		var r_max := _radius() * DISC
		if r_max <= 0.0 or screen.x <= 0.0:
			return
		zoom = fill * minf(screen.x, screen.y) * 0.5 / r_max
		_repaint_galaxy()

	## View memory is on the class, so the launcher's backdrop restored the run's off-centre pan.
	## Off by default; the screen that owns the real chart opts in.
	## Why: docs/why/StarchartScreen.md#navigated-chart-flag
	var remembers_view := false

	## Whether the saved view has been put back yet. One shot.
	var _restored := false

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_EXIT:
			# Motion goes to whatever is under the pointer now, so the hover is cleared here.
			hovered = -1
			_neb_hot = ""
			queue_redraw()
		if what == NOTIFICATION_MOUSE_EXIT and _cross != null:
			_cursor = Vector2(-1.0, -1.0)
			_cross.queue_redraw()
		if what == NOTIFICATION_RESIZED and remembers_view and not _restored \
				and size.x > 0.0:
			# The first moment `size` is real: anything derived from the panel must wait.
			_restored = true
			_arrive()
		if what == NOTIFICATION_RESIZED:
			# `_radius()` comes from size, so every cached position is stale, fixed layers too.
			_repaint_sky()

	## ON follows you on each arrival; OFF stays put so you can watch a far approach.
	## The toggle used to persist doing nothing on arrival, which read as broken.
	## Why: docs/why/StarchartScreen.md#arrival-framing
	func _arrive() -> void:
		if StarchartScreen._region_on:
			var here: MapGen.MapNode = Run.node_at()
			if here != null:
				# Snapped, not glided: nobody asked for this move.
				frame_region(here, 0.24, false)
				return
		# `_view_map` is a galaxy fingerprint: a new run is a new galaxy and an
		# old pan means nothing in it.
		if StarchartScreen._view_zoom > 0.0 \
				and StarchartScreen._view_map == Run.map.size():
			_go_to(StarchartScreen._view_zoom, StarchartScreen._view_pan, false)

	## The event horizon's shadow at build time, in drawn pixels: nothing is
	## placed inside it. (The hole the chart DRAWS is bigger: `ChartSky.hole_r`.)
	func _shadow_r() -> float:
		return _radius() * float(_g().get("hole", 0.034))

	## Ownership has its own curve: splitting by speed left static stars among moving ones.
	## The split is kept as it decides which random numbers each star draws.
	## Why: docs/why/StarchartScreen.md#core-ownership
	func _own_at(r: float, clear: float) -> float:
		# Total inside three quarters of the core: the old pow curve left 2200 static stars.
		# A sharp edge is safe: the two layers share one rule, so density stays flat.
		# Why: docs/why/StarchartScreen.md#core-ownership
		var x: float = clampf(r / maxf(1.0, clear), 0.0, 1.0)
		if x < 0.72:
			return 1.0
		var f: float = (1.0 - x) / 0.28
		return f * f * (3.0 - 2.0 * f)

	func _core_clear() -> float:
		# Every star here is redrawn at 60 fps, so this radius is the frame budget.
		# At 0.22 it was nine thousand moving particles and 23 ms a frame.
		# Why: docs/why/StarchartScreen.md#live-core-radius
		return maxf(_radius() * 0.21, _shadow_r() * 5.0)

	func _radius() -> float:
		# Twice the frame, so the chart is drawn large and navigated; ZOOM_MIN shows all of it.
		# Fitted to TILT, not squash: a squash fit made round galaxies small.
		# Why: docs/why/StarchartScreen.md#chart-scale
		return minf(size.x * 0.5 / DISC, size.y * 0.5 / (DISC * ChartSky.TILT)) * 1.9

	## Ring by layer, angle by where MapGen put the node, so a jump reads as a hop.
	func _polar(n: MapGen.MapNode) -> Vector2:
		return n.gal * (_radius() * DISC)

	## Built once a frame and shared with hit-testing, so drawn and clickable always agree.
	## Pointing at a reachable system adds its neighbourhood, or routes ran to hidden systems.
	## Why: docs/why/StarchartScreen.md#visible-set
	func _visible_set(here: MapGen.MapNode, reach: Array) -> Dictionary:
		var out: Dictionary = {}
		if show_all:
			for i in Run.map.size():
				out[i] = true
			return out
		# `Run.charted` is the rule and lives on the run, not here -- two test
		# harnesses need to measure it and both used to carry their own copy.
		for n in Run.map:
			if Run.charted(n):
				out[(n as MapGen.MapNode).index] = true
		out[here.index] = true
		# Engine range is not sight: `in_range()` is geometry, so unscanned systems showed.
		# Ruled 2026-08-28: you shouldn't see sectors beyond your sensor range.
		# Why: docs/why/StarchartScreen.md#sight-vs-reach
		if selected >= 0:
			out[selected] = true
		if hovered >= 0 and hovered < Run.map.size():
			out[hovered] = true
		return out

	## One projection for everything drawn; a click returns through `_to_galaxy`.
	## Why: docs/why/StarchartScreen.md#projection

	## One turn every `ChartSky.TURN_MINUTES`, from the chart's clock. View only.
	func turn() -> float:
		return fposmod(ChartSky.OMEGA * turn_speed * clock() + sky_angle, TAU)

	## Turn speed relative to the chart's; the title screen turns faster (Jon, Oct 6).
	var turn_speed: float = 1.0

	## The sky settles on an even pixel, so an odd centre left systems a pixel off their light.
	## Hidden until the top plate made the chart 419 px tall: solidtest 1.93 to 2.28 px.
	## Why: docs/why/StarchartScreen.md#centre-pixel
	func centre_px() -> Vector2:
		var c := (size * 0.5 + pan).floor()
		if _sky != null and is_instance_valid(_sky) and _sky.settled():
			c = (c / 2.0).floor() * 2.0
		return c

	## Always the sector map's TILT so geometry matches its orbits (Jon); balls keep `_sky_eff`.
	func _eff() -> float:
		return ChartSky.TILT

	## How flat the sky draws this galaxy's light, and so its named clouds
	## (`ChartSky.eff_of`): TILT for every galaxy with a disc.
	func _sky_eff() -> float:
		return ChartSky.eff_of(Run.galaxy)

	## `_proj` at the sky's own flatness, for what the sky draws (its clouds).
	func _proj_sky(g: Vector2, ang: float) -> Vector2:
		_proj_frame(ang)
		var d := Vector2(g.x, g.y * _pk_isq) * _pk_scale
		return _solid_px(Vector2(d.x * _pk_cos + d.y * _pk_sin, (d.y * _pk_cos - d.x * _pk_sin) * _sky_eff()), _pk_scale)

	## A point of the galaxy, at the galaxy angle `ang`, as screen pixels from
	## `centre_px()`.
	func _proj(g: Vector2, ang: float) -> Vector2:
		_proj_frame(ang)
		var d := Vector2(g.x, g.y * _pk_isq) * _pk_scale
		return _solid_px(Vector2(d.x * _pk_cos + d.y * _pk_sin, (d.y * _pk_cos - d.x * _pk_sin) * _pk_eff), _pk_scale)

	## The solid galaxy: marks share the sky's projection, so a click finds what is drawn.
	func _solid_on() -> bool:
		return run_galaxy and ChartSky.solid()

	## Flat view to camera point and back; `r` is px a gu when the caller has it.
	func _solid_px(o: Vector2, r: float = -1.0) -> Vector2:
		if not _solid_on():
			return o
		if r < 0.0:
			r = _radius() * DISC * zoom
		if r <= 0.0:
			return o
		return ChartSky.solid_fwd(o / r) * r

	func _solid_unpx(p: Vector2) -> Vector2:
		if not _solid_on():
			return p
		var r := _radius() * DISC * zoom
		if r <= 0.0:
			return p
		return ChartSky.solid_inv(p / r) * r

	## What `_proj` needs, worked out once for each view and angle rather than
	## for each of the hundreds of points a redraw projects.
	var _pk_key := Vector4(NAN, NAN, NAN, NAN)
	var _pk_gal := ""
	var _pk_scale := 1.0
	var _pk_isq := 1.0
	var _pk_eff := 1.0
	var _pk_cos := 1.0
	var _pk_sin := 0.0

	func _proj_frame(ang: float) -> void:
		var k := Vector4(ang, zoom, size.x, size.y)
		var gk: String = _star_key
		if k == _pk_key and gk == _pk_gal:
			return
		_pk_key = k
		_pk_gal = gk
		_pk_scale = _radius() * DISC * zoom
		_pk_isq = 1.0 / _squash()
		_pk_eff = _eff()
		_pk_cos = cos(ang)
		_pk_sin = sin(ang)

	## The same at zoom 1, for framing: where a point sits before the zoom.
	func _proj_unit(g: Vector2) -> Vector2:
		return _proj(g, _drawn_turn) / maxf(zoom, 0.0001)

	## A screen point back into the galaxy's own coordinates, where 1.0 is the
	## disc radius: the inverse of `_proj`, at the angle the systems are drawn.
	func _to_galaxy(p: Vector2) -> Vector2:
		var d := _to_plane(p)
		return Vector2(d.x, d.y * _squash())

	## A screen point into the disc's own plane (gal units, y not squashed).
	func _to_plane(p: Vector2, e: float = -1.0) -> Vector2:
		var r := _radius() * DISC * zoom
		if r <= 0.0:
			return Vector2.ZERO
		var q := _solid_unpx(p - centre_px()) / r
		q.y /= _eff() if e < 0.0 else e
		var c := cos(_drawn_turn)
		var s := sin(_drawn_turn)
		return Vector2(q.x * c - q.y * s, q.x * s + q.y * c)

	func _screen_pos(n: MapGen.MapNode) -> Vector2:
		return centre_px() + _proj(n.gal, _drawn_turn)

	## The sky keeps a cloud's shape about its centre, flattened to `flat`, so its outline does too.
	func _cloud_pt(cl: NebulaField.Cloud, o: Vector2) -> Vector2:
		var e := _sky_eff()
		var f := maxf(0.3, e / 0.82)
		var sq := _squash()
		var plane := Vector2(cl.pos.x + o.x, cl.pos.y / sq + o.y * f / e)
		return centre_px() + _proj_sky(Vector2(plane.x, plane.y * sq), _drawn_turn)

	## The cloud under a screen point, by the outline `_cloud_pt` draws:
	## NebulaField.at's rule, asked in each cloud's own shape.
	func _cloud_at(p: Vector2) -> NebulaField.Cloud:
		var plane := _to_plane(p, _sky_eff())
		var e := _sky_eff()
		var f := maxf(0.3, e / 0.82)
		var sq := _squash()
		var best: NebulaField.Cloud = null
		var closest := INF
		for raw in NebulaField.clouds():
			var cl: NebulaField.Cloud = raw
			var o := Vector2(plane.x - cl.pos.x, (plane.y - cl.pos.y / sq) * e / f)
			if cl.holds(cl.pos + o, NebulaField.EXTENT) and o.length() < closest:
				closest = o.length()
				best = cl
		return best

	## Held keys as state, so two move diagonally and releasing one leaves the other running.
	func _unhandled_key_input(e: InputEvent) -> void:
		var k := e as InputEventKey
		if k == null or k.echo or not keys:
			return
		# The four PAN keys are bindings (`Keys`), WASD and the arrows out of the box.
		var dir := Vector2.ZERO
		var action := &""
		for pair: Array in [[&"chart_up", Vector2.UP], [&"chart_down", Vector2.DOWN],
				[&"chart_left", Vector2.LEFT], [&"chart_right", Vector2.RIGHT]]:
			if k.is_action(pair[0]):
				action = pair[0]
				dir = pair[1]
				break
		if action == &"":
			return
		# A direction with two keys keeps going while the other is still down.
		if not k.pressed and Keys.held(action):
			accept_event()
			return
		# Accumulated rather than assigned: holding W and A is up AND left, and
		# releasing A must leave W running.
		_walk += dir if k.pressed else -dir
		_walk = _walk.clamp(-Vector2.ONE, Vector2.ONE)
		accept_event()


	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			match mb.button_index:
				MOUSE_BUTTON_WHEEL_UP:
					if mb.pressed:
						_zoom_at(mb.position, ZOOM_STEP)
				MOUSE_BUTTON_WHEEL_DOWN:
					if mb.pressed:
						_zoom_at(mb.position, 1.0 / ZOOM_STEP)
				MOUSE_BUTTON_LEFT:
					if mb.pressed:
						var hit := _node_at(mb.position)
						if hit >= 0:
							node_picked.emit(hit)
						else:
							_dragging = true
							_drag_from = mb.position
							_press_at = mb.position
							_drag_moved = false
					else:
						# Only a click clears: releasing after a pan must keep the selection.
						if _dragging and not _drag_moved:
							cleared.emit()
						var was := _dragging
						_dragging = false
						if was:
							_repaint_galaxy()
				MOUSE_BUTTON_MIDDLE:
					_dragging = mb.pressed
					_drag_from = mb.position
		elif event is InputEventGesture:
			var f := gesture_zoom(event, ZOOM_STEP)
			if f != 1.0:
				_zoom_at((event as InputEventGesture).position, f)
			accept_event()
		elif event is InputEventMouseMotion:
			var mm := event as InputEventMouseMotion
			if _cross != null:
				_cursor = mm.position
				_cross.queue_redraw()
				_scan_px += mm.relative.length()
			if _dragging:
				# The sky follows the galaxy's real movement, or it slides at the pan limit.
				var before := pan
				pan += mm.position - _drag_from
				_clamp_pan()
				sky_pan += pan - before
				if pan != before:
					view_dragged.emit()
				_drag_from = mm.position
				if mm.position.distance_to(_press_at) > 3.0:
					_drag_moved = true
				_repaint_galaxy()
			else:
				# A hidden overlay stops answering the cursor; nebulae do, being the galaxy.
				# Nothing under the Custodian's badge: its own tooltip opens there.
				# Why: docs/why/StarchartScreen.md#hidden-means-hidden
				var under_badge := CustodianBadge.covers(get_global_transform_with_canvas() * mm.position)
				var h := _node_at(mm.position) if show_icons and not under_badge else -1
				# A system wins over the gas it is sitting in: you can act on
				# one and only look at the other.
				var cloud: NebulaField.Cloud = null
				if h < 0 and not under_badge:
					# Same extent as the drawn boundary: inside always answers, outside never.
					cloud = _cloud_at(mm.position)
				var cname := "" if cloud == null else cloud.name
				if h != hovered or cname != _neb_hot:
					hovered = h
					_neb_hot = cname
					_neb_hot_emit = cloud != null and cloud.emission
					_neb_hot_kind = "" if cloud == null else cloud.label()
					_neb_hot_at = mm.position
					queue_redraw()

	## Zoom keeps the point under the cursor fixed. `SKY_ZOOM_POWER`: 1.0 follows the galaxy.
	const SKY_ZOOM_POWER := 0.25

	## THE ZOOM LADDER's hold on the view: from where it rests to your star at
	## the closest zoom, the sky solved at every step as `glide_to` solves it.
	var _lad := {}
	var ladder_hush := false
	## the chart's own words and instruments drawn over the galaxy (YOU, the
	## scale bar), faded with the screen's UI (`StarchartScreen.ladder_chrome`)
	var ui_a := 1.0

	func ladder_begin(off: Vector2 = Vector2.ZERO, reach: float = 0.0) -> void:
		if _glide != null and _glide.is_valid():
			_glide.kill()
		var here: MapGen.MapNode = Run.node_at() if not Run.map.is_empty() else null
		_lad = {"z0": zoom, "p0": pan, "s0": sky_pan, "off": off,
			"z1": minf(ZOOM_MAX, zoom * reach) if reach > 0.0 else ZOOM_MAX,
			"f1": _proj_unit(here.gal) if here != null else Vector2.ZERO}

	func ladder_at(k: float) -> void:
		if _lad.is_empty():
			return
		var z0: float = _lad.z0
		var z: float = z0 * pow(float(_lad.z1) / maxf(z0, 0.0001), k)
		var f0: Vector2 = -(_lad.p0 as Vector2) / maxf(z0, 0.0001)
		zoom = z
		# Your star travels a straight line across the picture, as far as this half (`split`) goes.
		var unit: Vector2 = _lad.f1
		var rel0 := (_lad.p0 as Vector2) + unit * z0
		var goal: Vector2 = _lad.off if (_lad.off as Vector2) != Vector2.ZERO else Vector2.ZERO
		var rel := rel0.lerp(goal, k * float(_lad.get("split", 1.0)))
		pan = rel - unit * z
		if f0 == Vector2.INF:
			pan = -f0 * z
		var c0 := size * 0.5
		sky_pan = c0 - (c0 - (_lad.s0 as Vector2)) * pow(z / maxf(z0, 0.0001), SKY_ZOOM_POWER) + (pan - (_lad.p0 as Vector2))
		_repaint_galaxy()

	## How far the chart's own step travels (log scale), and the map's after it.
	func ladder_spans() -> Vector2:
		if _lad.is_empty():
			return Vector2.ZERO
		return Vector2(absf(log(float(_lad.z1) / maxf(float(_lad.z0), 0.0001))), log(1.0 / 0.12))

	func ladder_end() -> void:
		_lad = {}
		if ladder_hush:
			ladder_hush = false
			queue_redraw()

	## THE CALM MOVE (`ZoomLadder`, Jon's pick A): the camera placed by where
	## your star is on screen and how far in it is against rest.
	func calm_begin() -> void:
		if _glide != null and _glide.is_valid():
			_glide.kill()
		_lad = {"calm": true, "z0": zoom, "p0": pan, "s0": sky_pan}
		_lad["rest"] = calm_star()

	## Where your star rests now: the rest camera, the galaxy turned as it is
	## this moment (it turns under the move too).
	func calm_rest_star() -> Vector2:
		var z := zoom
		var pn := pan
		zoom = _lad.z0
		pan = _lad.p0
		var at := calm_star()
		zoom = z
		pan = pn
		return at

	func calm_star() -> Vector2:
		if Run.map.is_empty():
			return global_position + size * 0.5
		return global_position + _screen_pos(Run.node_at())

	func calm_at(p: Vector2, s: float) -> void:
		if not _lad.has("calm"):
			return
		var z0: float = _lad.z0
		zoom = z0 * s
		pan = _lad.p0
		# (the solid galaxy's projection is not quite flat: a step or two more
		# puts your star where it is asked to be)
		for i in 3:
			pan += p - calm_star()
		var c0 := size * 0.5
		sky_pan = c0 - (c0 - (_lad.s0 as Vector2)) * pow(zoom / maxf(z0, 0.0001), SKY_ZOOM_POWER) + (pan - (_lad.p0 as Vector2))
		_repaint_galaxy()

	func calm_end() -> void:
		if _lad.has("calm"):
			zoom = _lad.z0
			pan = _lad.p0
			sky_pan = _lad.s0
			_repaint_galaxy()
		ladder_end()

	## The zoom factor of a Mac trackpad or Magic Mouse scroll (a pan gesture,
	## never the wheel's buttons; up is in, like the wheel) or a pinch; 1.0 for
	## anything else. Shared with `SystemMapScreen`.
	static func gesture_zoom(e: InputEvent, step: float) -> float:
		if e is InputEventPanGesture:
			var dy := (e as InputEventPanGesture).delta.y
			return 1.0 if is_zero_approx(dy) else pow(step, -dy)
		if e is InputEventMagnifyGesture:
			var m := (e as InputEventMagnifyGesture).factor
			return 1.0 if m <= 0.0 else m
		return 1.0

	func _zoom_at(at: Vector2, factor: float) -> void:
		var c0 := size * 0.5
		var before := (at - c0 - pan) / zoom
		var was := zoom
		zoom = clampf(zoom * factor, ZOOM_MIN, ZOOM_MAX)
		pan = at - c0 - before * zoom

		# The sky pivots about the cursor too: it agrees with the galaxy there, then diverges.
		# Only the offset pivots, so no pixel is rescaled; a clamped zoom leaves the sky still.
		# Why: docs/why/StarchartScreen.md#sky-zoom-pivot
		var eff: float = zoom / maxf(0.0001, was)
		var soft: float = pow(eff, SKY_ZOOM_POWER)
		sky_pan = at - c0 - (at - c0 - sky_pan) * soft
		_clamp_pan()
		_repaint_galaxy()

	## Past this you see unpainted space, a hard black rectangle that reads as a texture's end.
	func _pan_limit() -> Vector2:
		# The rim may reach the view's edge: `maxf(half screen, ex)` switched regimes at zoom 0.62.
		# Adding half a view gives one rule at every zoom and still cannot lose the galaxy.
		# Why: docs/why/StarchartScreen.md#pan-limit
		var ex := _radius() * DISC * zoom
		return Vector2(ex + size.x * PAN_SLACK, ex * _eff() + size.y * PAN_SLACK)

	## No pan limit: the escape menu's 66 px slack left a rim ship on the frame edge.
	var free_pan := false
	## The distance bar. Off in the escape menu's inset, where the corner it
	## claims is where the galaxy and sector names sit.
	var show_scale := true

	func _clamp_pan() -> void:
		if free_pan:
			return
		var lim := _pan_limit()
		pan.x = clampf(pan.x, -lim.x, lim.x)
		pan.y = clampf(pan.y, -lim.y, lim.y)
		# `sky_pan` is not clamped here: it only accumulates real movement, and a clamp disagreed.

	## `Run.in_range()` costs about 3 ms a call and was asked on every redraw and mouse motion.
	## Keyed on position, map, reach and tilt: a pan, zoom or hover changes none of them.
	## Why: docs/why/StarchartScreen.md#range-cache
	var _range_key: String = ""
	var _range_memo: Array = []
	var _deep_memo: Dictionary = {}

	func _in_range() -> Array:
		var key := "%d|%d|%d|%s|%s" % [Run.at, Run.galaxy_seed, Run.map.size(),
			Run.jump_range(), Run.galaxy.get("squash", 1.0)]
		if key != _range_key:
			_range_key = key
			_range_memo = Run.in_range()
			_deep_memo = _too_deep_of(Run.node_at())
		return _range_memo

	## Stars in the reach ring that a jump refuses (ruling 13 A, Jon, Oct 27), drawn dimmed.
	## Read through `Run.too_deep_only` only, so `DEPTH_STEP` can change under it.
	## Why: docs/why/StarchartScreen.md#too-deep-set
	func too_deep_set() -> Dictionary:
		_in_range()
		return _deep_memo

	static func _too_deep_of(here: MapGen.MapNode) -> Dictionary:
		var out: Dictionary = {}
		if here == null:
			return out
		for n in Run.map:
			var t: MapGen.MapNode = n
			# (only a star further in can be too deep: the rest skip the sums)
			if t.layer <= here.layer or t.type == MapGen.NodeType.CORE:
				continue
			if Run.too_deep_only(here, t):
				out[t.index] = true
		return out

	func _node_at(p: Vector2) -> int:
		var visible := _visible_set(Run.node_at(), _in_range())
		for n in Run.map:
			# Only what is on screen can be pointed at.
			if not visible.has((n as MapGen.MapNode).index):
				continue
			var node: MapGen.MapNode = n
			if _screen_pos(node).distance_to(p) < maxf(5.0, 12.0 * zoom):
				return node.index
		return -1

	## Asks once for all systems a click could pick in `r`: A.S.H.'s `covers` made 1,500 calls.
	## The game froze every tenth of a second (Jon, Oct 20).
	## Why: docs/why/StarchartScreen.md#hit-testing
	func nodes_near(r: Rect2) -> Dictionary:
		var visible := _visible_set(Run.node_at(), _in_range())
		var rad := maxf(5.0, 12.0 * zoom)
		var g := r.grow(rad + 1.0)
		var out: Array = []
		for n in Run.map:
			var node: MapGen.MapNode = n
			if not visible.has(node.index):
				continue
			var sp := _screen_pos(node)
			if g.has_point(sp):
				out.append([node.index, sp])
		return {nodes = out, rad = rad}

	## `_node_at` among `near` (`nodes_near`) alone: the same system for any
	## point inside the rect it was asked for.
	static func node_among(p: Vector2, near: Dictionary) -> int:
		var rad: float = near.rad
		for e: Array in near.nodes:
			if (e[1] as Vector2).distance_to(p) < rad:
				return int(e[0])
		return -1

	func _draw() -> void:
		var t0 := Time.get_ticks_usec()
		_draw_chart()
		if prof:
			prof_add("chart", Time.get_ticks_usec() - t0)

	func _draw_chart() -> void:
		if Run.map.is_empty():
			return
		var hr := _hole_px()
		# (where the camera shows the core, with the solid galaxy on)
		_hole_c = centre_px() + _solid_px(Vector2.ZERO)
		_hole_rr = (hr + 1.0) * (hr + 1.0) if hr > 0.0 else 0.0

		var here: MapGen.MapNode = Run.node_at()
		var hp := _screen_pos(here)
		var reach: Array = []

		# With the systems hidden, the chart is the galaxy alone: no routes, no
		# trail, no glyphs, no tooltip, and nothing that answers the cursor.
		if show_icons:
			# Shows one system's reach at a time: the reachable graph is denser than the links.
			# Links are not what travel uses, so the old all-links fog drew the wrong graph.
			# Why: docs/why/StarchartScreen.md#reach-overlay
			if show_links and hovered >= 0 and hovered < Run.map.size():
				var from: MapGen.MapNode = Run.map[hovered]
				var a3 := _screen_pos(from)
				for n3 in Run.map:
					var t3: MapGen.MapNode = n3
					if t3.index == from.index:
						continue
					# Same rule as the routes out of YOU: geometry is not sight.
					if Run.reachable_from(from, t3) and Run.charted(t3):
						draw_line(a3, _screen_pos(t3),
							Color(0.36, 0.56, 0.72, 0.38), 1.0)

			_draw_reach_ring(hp)

			# Been is solid white fact; could-go is dotted, dim and provisional.
			# Only to drawn systems: a route to a hidden place is worse than showing both.
			# Why: docs/why/StarchartScreen.md#route-lines
			reach = []
			for cand in _in_range():
				if Run.charted(cand):
					reach.append(cand)
			for r in reach:
				var rn2: MapGen.MapNode = r
				var afford: bool = Run.can_jump_to(rn2)
				_dotted(hp, _screen_pos(rn2),
					Color(0.42, 0.56, 0.70, 0.75) if afford else Color(0.34, 0.38, 0.44, 0.35))

			if Run.trail.size() > 1:
				for i in range(1, Run.trail.size()):
					var a := _screen_pos(Run.map[Run.trail[i - 1]])
					var b := _screen_pos(Run.map[Run.trail[i]])
					draw_line(a, b, _UNDER_SOFT, 3.0)
					draw_line(a, b, Color(0.86, 0.91, 0.97, 0.85), 1.0)

		# Hovering a candidate shows nothing beyond it: a second web competed with live options.

		var visible := _visible_set(here, reach)
		# Zoomed out a system is a point of light: 173 fixed-size glyphs made a wall of icons.
		var tiny := zoom < 0.78
		_pickable = PackedVector2Array()
		drawn_ink.clear()
		drawn_dim.clear()
		var deep: Dictionary = too_deep_set() if show_icons else {}
		for n in Run.map:
			var node2: MapGen.MapNode = n
			if not show_icons:
				continue
			if visible.has(node2.index):
				_pickable.append(_screen_pos(node2))
			# A record and a choice, not an atlas: unreachable unvisited systems were noise.
			if not visible.has(node2.index):
				continue
			var p := (_screen_pos(node2) - Vector2(6, 6)).round()
			var tint := MapGen.star_colour(node2)
			if node2.cleared and node2.type != MapGen.NodeType.CORE:
				tint = Color("#37424f")
			# Visited systems stay, dimmed, so lit ones are the dish's sight and the ring its edge.
			# Not `cleared`'s dead grey: these are real places you might route back through.
			# Why: docs/why/StarchartScreen.md#remembered-systems
			if not node2.sensed and node2.index != here.index:
				tint = tint.darkened(0.45)
			# In the ring and refused (ruling 13 A, Jon, Oct 27): one dim grey, even on hover.
			# Drawn like the rest, it read as reachable until JUMP said TOO DEEP.
			# Why: docs/why/StarchartScreen.md#too-deep-grey
			var dim: bool = deep.has(node2.index)
			# The core is its black hole: glyph, brackets and YOU sit on the shadow, no name (Jon).
			# The icon shows only in sensor range; the hole itself is sky and always there.
			# Why: docs/why/StarchartScreen.md#core-marker
			if node2.type == MapGen.NodeType.CORE and not (show_all or node2.index == here.index
					or node2.index == selected or node2.visited
					or MapGen.hop_distance(here, node2) <= Run.sense_radius()):
				continue
			if node2.type == MapGen.NodeType.CORE:
				# The middle of the visible black: the near disc covers the shadow's lower part.
				p = (_screen_pos(node2) - Vector2(6, 6 + _hole_px() * 0.38)).round()
				drawn_ink[node2.index] = Glyph.draw_glyph(self, p, node2.type, tint.lightened(0.12),
					node2.index == here.index, node2.index == selected, UITheme.FLARE)
			elif tiny:
				var lit: bool = node2.index == here.index \
					or node2.index == selected or node2.index == hovered
				# Systems you can actually go to hold their colour; the rest of
				# the galaxy sinks back, so the cluster reads without a label.
				var near: bool = lit or reach.has(node2)
				# Far systems keep some colour to stay findable; reachable ones get extra weight.
				var d: float = 3.0 if (lit or near) else 2.0
				var at := p + Vector2(6, 6) - Vector2(d, d) * 0.5
				# on a rim of the void a pixel out on its four sides (not its
				# corners), so it stands off the arms and the bulge
				draw_rect(Rect2(at - Vector2(1, 0), Vector2(d + 2.0, d)), _UNDER, true)
				draw_rect(Rect2(at - Vector2(0, 1), Vector2(d, d + 2.0)), _UNDER, true)
				var dot := tint.lightened(0.15) if near else tint.darkened(0.35)
				if dim:
					dot = Glyph.DIM
				draw_rect(Rect2(at, Vector2(d, d)), dot, true)
				drawn_ink[node2.index] = dot
				if node2.twin:
					# TWO SUNS, zoomed out: a pixel of a second, warmer star off the
					# dot's lower right corner, on its own rim of the void
					var c2 := at + Vector2(d + 1.0, d)
					draw_rect(Rect2(c2 - Vector2(1, 1), Vector2(3, 3)), _UNDER, true)
					draw_rect(Rect2(c2, Vector2.ONE), Glyph.DIM if dim else dot.lerp(UITheme.EMBER, 0.55), true)
			else:
				var near2: bool = node2.index == here.index or node2.index == selected \
					or node2.index == hovered or reach.has(node2)
				Glyph.draw_halo(self, p, node2.type, _UNDER, node2.twin)
				drawn_ink[node2.index] = Glyph.draw_glyph(self, p, node2.type,
					tint.lightened(0.12) if near2 else tint.darkened(0.2),
					node2.index == here.index, node2.index == selected, Glyph.BAND, dim, node2.twin)
			if dim:
				drawn_dim[node2.index] = true
			if node2.index == here.index:
				_draw_you(p, tiny)
			elif (node2.index == hovered or node2.index == selected) and node2.type != MapGen.NodeType.CORE:
				draw_string(UITheme.pixel_font(), p + Vector2(-40, 30),
					MapGen.star_name(node2), HORIZONTAL_ALIGNMENT_CENTER, 92, 8,
					UITheme.ICE if node2.index == hovered else UITheme.COLD)


		_draw_party()
		_draw_hellbender()
		_draw_quests()
		_draw_work()
		_draw_quest_route()
		_draw_quest_tags()
		_draw_neb_edges()

		if hovered >= 0 and hovered < Run.map.size() and _hover_t > 0.01:
			_draw_tip(Run.map[hovered], here)
		elif _neb_hot != "":
			_draw_neb_tip()

		if show_scale:
			_draw_scale()

	## Bottom left, the one corner nothing else claims: the tooltip and party markers move.
	## It saves the reader holding a scale in their head across every zoom step.
	## Why: docs/why/StarchartScreen.md#scale-bar
	func _draw_scale() -> void:
		# Pixels per light year at the current zoom. `_polar` scales a `gal`
		# of 1.0 by radius*DISC, and the view then scales by `zoom`.
		var per_gal := _radius() * DISC * zoom
		if per_gal <= 0.0:
			return
		var per_ly := per_gal / RADIUS_LY
		var ly := 0.0
		for step in BAR_STEPS:
			if float(step) * per_ly <= BAR_MAX_PX:
				ly = float(step)
		if ly <= 0.0:
			# Show the shortest step even if it overflows: an empty corner reads worse.
			ly = float(BAR_STEPS[0])
		var w := minf(ly * per_ly, BAR_MAX_PX)
		var y := size.y - BAR_PAD
		# Bottom right under MY REGION: both answer where am I and how big, so one instrument.
		var x := size.x - BAR_PAD - w
		var ink := Color(UITheme.COLD, UITheme.COLD.a * ui_a)
		if ui_a <= 0.01:
			return
		# A bar with end ticks, not a bare line: the ticks are what say where
		# it starts and stops on a field of stars.
		# (each with a shadow under it, as the chart's labels have: over a galaxy's warm
		# light close in the bar and its words were lost)
		var sh := Color(0, 0, 0, 0.85 * ui_a)
		for o: Vector2 in [Vector2(1, 1), Vector2.ZERO]:
			var c := sh if o != Vector2.ZERO else ink
			draw_line(Vector2(x, y) + o, Vector2(x + w, y) + o, c, 1.0)
			draw_line(Vector2(x, y - 4.0) + o, Vector2(x, y + 1.0) + o, c, 1.0)
			draw_line(Vector2(x + w, y - 4.0) + o, Vector2(x + w, y + 1.0) + o, c, 1.0)
		# Thousands read better than five digits on an 8px face.
		var txt := ("%d ly" % int(ly) if ly < 1000.0
			else "%dk ly" % int(ly / 1000.0))
		# Hung off the far tick: the near one moves with the step, so a label there slides on zoom.
		draw_string(UITheme.pixel_font(),
			Vector2(x + w - BAR_MAX_PX, y - 7.0) + Vector2(1, 1), txt,
			HORIZONTAL_ALIGNMENT_RIGHT, BAR_MAX_PX, 8, sh)
		draw_string(UITheme.pixel_font(),
			Vector2(x + w - BAR_MAX_PX, y - 7.0), txt,
			HORIZONTAL_ALIGNMENT_RIGHT, BAR_MAX_PX, 8, ink)

	## Frames the neighbourhood within `span` of you, the measure MapGen prices jumps by.
	## Framing the whole layer came out at ZOOM_MIN at the rim, so the button seemed dead.
	## Why: docs/why/StarchartScreen.md#local-region-framing
	var _glide: Tween = null

	## Settled every step: `_settle_sky` is a delta, so the whole journey at once slides the field.
	## Why: docs/why/StarchartScreen.md#glide
	func glide_to(z: float, p: Vector2, secs: float = 0.55) -> void:
		if _glide != null and _glide.is_valid():
			_glide.kill()
		var z0 := zoom
		var p0 := pan
		var z1 := clampf(z, ZOOM_MIN, ZOOM_MAX)
		# Work out where the sky ends up first: per-step settling accumulates and trails.
		# Why: docs/why/StarchartScreen.md#glide
		var pz := zoom
		var pp := pan
		var ps := sky_pan
		zoom = z1
		pan = p
		_clamp_pan()
		var p1 := pan
		var c0 := size * 0.5
		# Put it back where it was; the tween does the travelling.
		zoom = pz
		pan = pp
		_glide = create_tween()
		_glide.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		_glide.tween_method(func(t: float) -> void:
			zoom = lerpf(z0, z1, t)
			pan = p0.lerp(p1, t)
			# Solved at this zoom, not lerped: the sky offset is a pow of the zoom ratio.
			# Why: docs/why/StarchartScreen.md#glide
			var sf: float = pow(zoom / maxf(0.0001, z0), SKY_ZOOM_POWER)
			sky_pan = (c0 - (c0 - ps) * sf) + (pan - p0)
			_repaint_galaxy(), 0.0, 1.0, secs)

	## The pair to `frame_region`: the same route back, so the second press undoes the first.
	func frame_galaxy() -> void:
		glide_to(ZOOM_MIN, Vector2.ZERO)

	## `animate` false snaps, for an arrival: a glide made the screen visibly zoom itself in.
	## Why: docs/why/StarchartScreen.md#snap-on-arrival
	func frame_region(here: MapGen.MapNode, span: float = 0.24,
			animate: bool = true) -> void:
		if Run.map.is_empty() or here == null:
			return
		var lo := Vector2.INF
		var hi := -Vector2.INF
		var n := 0
		for node in Run.map:
			var mn: MapGen.MapNode = node
			if MapGen.hop_distance(here, mn) > span:
				continue
			var p := _proj_unit(mn.gal)
			lo = lo.min(p)
			hi = hi.max(p)
			n += 1
		# Every galaxy frames the systems near you (Jon, Oct 21, 0.3.0); a ball is out of frame.
		# Framing a ball whole took L to 0.42 to 0.84 against a spiral's 1.8, and read as nothing.
		# Why: docs/why/StarchartScreen.md#local-region-framing
		if n <= 1:
			# Nothing near you but you. Centre on the ship at a readable zoom
		# rather than dividing by a span of nothing.
			var solo := clampf(2.0, ZOOM_MIN, ZOOM_MAX)
			_go_to(solo, -_proj_unit(here.gal) * solo, animate)
			return
		var box := (hi - lo).max(Vector2.ONE)
		# A margin, or the outermost system sits on the frame edge with its name
		# label hanging off the chart.
		var want := minf(size.x / (box.x + 180.0), size.y / (box.y + 140.0))
		var z := clampf(want, ZOOM_MIN, ZOOM_MAX)
		_go_to(z, -((lo + hi) * 0.5) * z, animate)

	## Snap is the same two assignments the view restore makes; there is no third way to move.
	## `center_on_ship` exists as harnesses each hand-poked zoom and pan and forgot a step.
	## Why: docs/why/StarchartScreen.md#glide
	func center_on_ship(z: float) -> void:
		_go_to(z, -_proj_unit(Run.node_at().gal) * z, false)

	func _go_to(z: float, p: Vector2, animate: bool) -> void:
		if animate:
			glide_to(z, p)
			return
		zoom = z
		pan = p
		_clamp_pan()
		_repaint_sky()

	## The starfield has its own offset: setting zoom and pan directly left the galaxy behind.
	## `_repaint_galaxy` is the other half, as the starfield is cached and queue_redraw misses it.
	## Why: docs/why/StarchartScreen.md#sky-settle
	func _settle_sky(was: float, before: Vector2) -> void:
		var c0 := size * 0.5
		var soft: float = pow(zoom / maxf(0.0001, was), SKY_ZOOM_POWER)
		sky_pan = c0 - (c0 - sky_pan) * soft
		sky_pan += pan - before
		_repaint_galaxy()
		queue_redraw()

	## Only the cloud under the cursor: outlining every cloud competed with the systems.
	## The union boundary of its lobes, so the line agrees with the gas and the tooltip.
	## Why: docs/why/StarchartScreen.md#nebula-boundary
	func _draw_neb_edges() -> void:
		if _neb_hot == "":
			return
		var r_max := _radius() * DISC
		for raw in NebulaField.clouds():
			var cl: NebulaField.Cloud = raw
			if cl.name != _neb_hot:
				continue
			# Darker than the gas, so it sits under the cloud and is only found when sought.
			var col := cl.edge_colour()
			col.a = 0.85
			for i in cl.lobes.size():
				var centre: Vector2 = cl.pos + cl.lobes[i]
				var rad: float = cl.lobe_r[i] * NebulaField.EXTENT
				# Step in screen pixels, so a small cloud does not come out as a
				# polygon and a huge one does not cost a thousand rects.
				var px_r: float = rad * r_max * zoom
				# One sample per pixel of circumference and a little over, so the line is unbroken.
				var steps := clampi(int(px_r * 7.0), 64, 2600)
				for k in steps:
					var a: float = float(k) / float(steps) * TAU
					var pn := centre + Vector2(cos(a), sin(a)) * rad
					# Union, not three circles: skip anything another lobe holds.
					var buried := false
					for j in cl.lobes.size():
						if j == i:
							continue
						if (pn - cl.pos - cl.lobes[j]).length() < cl.lobe_r[j] * NebulaField.EXTENT:
							buried = true
							break
					if buried:
						continue
					var q := _cloud_pt(cl, pn - cl.pos)
					if q.x < 0.0 or q.y < 0.0 or q.x > size.x or q.y > size.y:
						continue
					draw_rect(Rect2(q.round(), Vector2.ONE), col, true)

	## A cloud's tooltip has no numbers: a nebula is somewhere you can be, not a jump target.
	func _draw_neb_tip() -> void:
		var f := UITheme.pixel_font()
		var l2 := _neb_hot_kind
		var w1 := f.get_string_size(_neb_hot, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var w2 := f.get_string_size(l2, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var box := Vector2(ceil(maxf(w1, w2)) + 11.0, 27.0)
		var o := _neb_hot_at + Vector2(14, -box.y * 0.5)
		if o.x + box.x > size.x - 2.0:
			o.x = _neb_hot_at.x - box.x - 14.0
		o.x = clampf(o.x, 2.0, maxf(2.0, size.x - box.x - 2.0))
		o.y = clampf(o.y, 2.0, maxf(2.0, size.y - box.y - 2.0))
		o = o.round()

		var edge := Color("#a98ab8") if _neb_hot_emit else Color("#6fa5b0")
		draw_rect(Rect2(o, box), Color(0.043, 0.067, 0.106, 0.94), true)
		draw_rect(Rect2(o, Vector2(box.x, 1)), edge, true)
		draw_rect(Rect2(o + Vector2(0, box.y - 1), Vector2(box.x, 1)), edge, true)
		draw_rect(Rect2(o, Vector2(1, box.y)), edge, true)
		draw_rect(Rect2(o + Vector2(box.x - 1, 0), Vector2(1, box.y)), edge, true)
		draw_string(f, o + Vector2(6, 11), _neb_hot,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UITheme.ICE)
		draw_string(f, o + Vector2(6, 22), l2,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 8, edge)

	## An ellipse, not a circle: `hop_distance` divides out squash, so reach is round in the galaxy.
	## Whole pixels and a radius-tied step count, or dashes land on fractions and shimmer on pan.
	## Why: docs/why/StarchartScreen.md#reach-ring
	func _draw_reach_ring(c: Vector2) -> void:
		# Two rings for two limits: the dish always outruns the engine (1.39x at no sensors).
		# Sight takes reach's weight and a longer dash, or the outer limit was lost on a dense sky.
		# Why: docs/why/StarchartScreen.md#sight-and-reach-rings
		if show_sight:
			_ring(c, Run.sense_radius(), Color(0.31, 0.69, 0.74, 0.50), 5, 9)
		if show_reach:
			_ring(c, Run.jump_range(), Color(0.83, 0.46, 0.24, 0.46))

	## A dashed ellipse; `on` and `period` are parameters so the two rings can be told apart.
	func _ring(c: Vector2, r: float, col: Color, on: int = 2, period: int = 5) -> void:
		if r <= 0.0:
			return
		var rx := r * _radius() * DISC * zoom
		# Flattened as the disc is (`_proj`): the reach is a circle in the disc's
		# plane, and a circle turns into itself, so the ring never turns.
		var ry := rx * _eff()
		# Under about six pixels it is a smudge on the ship rather than a ring,
		# and at that size the dotted lines already say everything it would.
		if rx < 6.0:
			return
		# One step per pixel of circumference, near enough, so the dash rhythm
		# stays the same length on screen at every zoom.
		var steps := clampi(int(rx * 1.6), 60, 480)
		# (through the solid galaxy's camera the ring is a circle on the disc seen in
		# perspective: each dot placed on the flat view, then through the camera)
		var co := _solid_unpx(c - centre_px())
		var rpx := _radius() * DISC * zoom
		for i in steps:
			if i % period >= on:
				continue
			var a := TAU * float(i) / float(steps)
			var q := (centre_px() + _solid_px(co + Vector2(cos(a) * rx, sin(a) * ry), rpx)).round()
			if _in_hole(q):
				continue
			_under_dot(q)
			draw_rect(Rect2(q, Vector2.ONE), col, true)

	## Dotted marks stop at the shadow's edge rather than running across it as a dashed seam.
	func _hole_px() -> float:
		return _sky.hole_px() if _sky != null else 0.0

	## (worked out once a draw, `_draw_chart`, not once a dot)
	var _hole_c := Vector2.ZERO
	var _hole_rr := 0.0

	func _in_hole(q: Vector2) -> bool:
		return _hole_rr > 0.0 and q.distance_squared_to(_hole_c) < _hole_rr

	## Whole pixels: `draw_dashed_line` works in continuous space and shimmers on pan.
	func _dotted(a: Vector2, b: Vector2, col: Color) -> void:
		var span := a.distance_to(b)
		if span < 1.0:
			return
		var step := (b - a) / span
		var i := 2.0
		while i < span - 2.0:
			# Two on, three off, each on a soft square of the void, so a route
			# still reads where it crosses the bright bulge or an arm.
			if int(i) % 5 < 2:
				var q := (a + step * i).round()
				if _in_hole(q):
					i += 1.0
					continue
				_under_dot(q)
				draw_rect(Rect2(q, Vector2.ONE), col, true)
			i += 1.0

	## The soft rim under one pixel of a route or ring: its four sides only.
	func _under_dot(q: Vector2) -> void:
		draw_rect(Rect2(q - Vector2(1, 0), Vector2(3, 1)), _UNDER_SOFT, true)
		draw_rect(Rect2(q - Vector2(0, 1), Vector2(1, 3)), _UNDER_SOFT, true)

	## The hover readout's four lines for `n` seen from `here`: name, kind,
	## place, and danger with what a jump there costs or why it cannot go.
	func tip_lines(n: MapGen.MapNode, here: MapGen.MapNode) -> PackedStringArray:
		var l1 := MapGen.star_name(n)
		var l2 := MapGen.type_label(n.type)
		if n.cleared and n.type != MapGen.NodeType.CORE:
			l2 = "CLEARED · " + l2
		var l3 := MapGen.place_line(n)
		var l4 := "DANGER %d/10" % n.danger
		# A too deep star says why on hover, before it is clicked; the chart draws it dimmed too.
		var deep := Run.too_deep_only(here, n)
		if deep:
			l4 += "   TOO DEEP"
		elif here.links.has(n.index):
			l4 += "   %d FUEL" % Run.fuel_cost_to(n)

		# The tooltip must withhold the survey too, or one hover undoes the panel's refusal.
		# Fuel and TOO DEEP survive: they are facts about your tank and link, not the place.
		# Why: docs/why/StarchartScreen.md#contract-tooltip
		if Run.known_only_by_contract(n.index):
			var job := Run.contract_at(n.index)
			l2 = "%s WANTS SOMETHING HERE" % DB.short_name(
				DB.manufacturer_name(job.manufacturer)).to_upper()
			l3 = "POSITION ONLY · NO SURVEY"
			l4 = "%d CREDITS" % job.pay
			if deep:
				l4 += "   TOO DEEP"
			elif here.links.has(n.index):
				l4 += "   %d FUEL" % Run.fuel_cost_to(n)
		return PackedStringArray([l1, l2, l3, l4])

	## Zoomed out every system is a two-pixel dot, so the tooltip is what makes places readable.
	func _draw_tip(n: MapGen.MapNode, here: MapGen.MapNode) -> void:
		var f := UITheme.pixel_font()
		var at := _screen_pos(n)

		# The reticle closes onto the system as the panel arrives, which points
		# the eye at which dot the panel is describing.
		var reach: float = lerpf(13.0, 7.0, _hover_t)
		var tick := 3.0
		for raw in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			var corner: Vector2 = raw
			var k: Vector2 = (at + corner * reach).round()
			draw_rect(Rect2(k - Vector2(0.0 if corner.x > 0 else tick - 1.0, 0),
				Vector2(tick, 1)), Color(1, 1, 1, 0.55 * _hover_t), true)
			draw_rect(Rect2(k - Vector2(0, 0.0 if corner.y > 0 else tick - 1.0),
				Vector2(1, tick)), Color(1, 1, 1, 0.55 * _hover_t), true)

		var lines := tip_lines(n, here)
		var l1 := lines[0]
		var l2 := lines[1]
		var l3 := lines[2]
		var l4 := lines[3]

		var w := 0.0
		for line in [l1, l2, l3, l4]:
			w = maxf(w, f.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x)
		var box := Vector2(ceil(w) + 11.0, 51.0)

		# Flip to the other side rather than hang off the edge, and slide in.
		var o := at + Vector2(14.0 - (1.0 - _hover_t) * 5.0, -box.y * 0.5)
		if o.x + box.x > size.x - 2.0:
			o.x = at.x - box.x - 14.0
		o.x = clampf(o.x, 2.0, maxf(2.0, size.x - box.x - 2.0))
		o.y = clampf(o.y, 2.0, maxf(2.0, size.y - box.y - 2.0))
		o = o.round()

		var a := _hover_t
		draw_rect(Rect2(o, box), Color(0.043, 0.067, 0.106, 0.94 * a), true)
		draw_rect(Rect2(o, Vector2(box.x, 1)), Color(0.235, 0.298, 0.376, a), true)
		draw_rect(Rect2(o + Vector2(0, box.y - 1), Vector2(box.x, 1)), Color(0.235, 0.298, 0.376, a), true)
		draw_rect(Rect2(o, Vector2(1, box.y)), Color(0.235, 0.298, 0.376, a), true)
		draw_rect(Rect2(o + Vector2(box.x - 1, 0), Vector2(1, box.y)), Color(0.235, 0.298, 0.376, a), true)
		# A colour chip: region identity is already carried by the dot's tint, so
		# repeating it here ties the panel to the point you are pointing at.
		draw_rect(Rect2(o + Vector2(1, 1), Vector2(2, box.y - 2)),
			Color(MapGen.star_colour(n), a), true)

		var tx := o + Vector2(7, 12)
		draw_string(f, tx, l1, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(UITheme.ICE, a))
		draw_string(f, tx + Vector2(0, 12), l2, HORIZONTAL_ALIGNMENT_LEFT, -1, 8,
			Color(UITheme.COLD, a))
		draw_string(f, tx + Vector2(0, 24), l3, HORIZONTAL_ALIGNMENT_LEFT, -1, 8,
			Color(UITheme.THEM, a))
		draw_string(f, tx + Vector2(0, 36), l4, HORIZONTAL_ALIGNMENT_LEFT, -1, 8,
			Color(0.541, 0.416, 0.227, a))

	## A stable hash from position, not a running sequence: bursts are timed and placed with it.
	func _hash2(i: int, j: int, salt: int) -> int:
		var h := (i * 374761393 + j * 668265263 + salt * 144665) & 0x7fffffff
		h = (h ^ (h >> 13)) & 0x7fffffff
		h = (h * 1274126177) & 0x7fffffff
		return (h ^ (h >> 16)) & 0x7fffffff

	func _frac(h: int) -> float:
		return float(h % 10000) / 10000.0


	## Drawn outside the visibility filter: a partner is the info you most want and least reach.
	## Fog will gate the position going onto the wire, so nothing here changes (coop-design.md).
	## Why: docs/why/StarchartScreen.md#party-markers
	func _draw_party() -> void:
		if not show_icons or Net.party_size() < 2:
			return
		for e: Array in party_marks():
			var slot: Dictionary = e[0]
			var c: Vector2 = e[1]
			var row: int = e[2]
			# Backed in ink: the deepest ship sits over the bright core and was unseeable.
			# Why: docs/why/StarchartScreen.md#party-markers
			_diamond(c, 6.0, _UNDER)
			_diamond(c, 5.0, UITheme.GOOD)
			# Stacked when two ships share a system, or one name prints on top of another.
			var label := String(slot.get("name", "")).to_upper()
			var at_text := c + Vector2(-46, -12 - row * 10) if row >= 0 else c + Vector2(8, 3)
			var align := HORIZONTAL_ALIGNMENT_CENTER if row >= 0 else HORIZONTAL_ALIGNMENT_LEFT
			draw_string(UITheme.pixel_font(), at_text + Vector2(1, 1), label,
				align, 92, 8, Color(0, 0, 0, 0.85))
			draw_string(UITheme.pixel_font(), at_text, label,
				align, 92, 8, UITheme.GOOD)

	## Off your own system: a partner there sat on your marker (Oct 22 playtest).
	## Diamonds stand upper right, one under another, names beside; elsewhere names stack above.
	## Why: docs/why/StarchartScreen.md#party-markers
	func party_marks() -> Array:
		var out: Array = []
		if Net.party_size() < 2 or Run.map.is_empty():
			return out
		var seen: Dictionary = {}
		var with_me := 0
		for slot in Net.partners():
			var at := int(slot.get("at", -1))
			if at < 0 or at >= Run.map.size():
				continue
			var c := _screen_pos(Run.map[at])
			if at == Run.at:
				# clear of YOU's brackets, whose corner reaches 17 px right
				out.append([slot, c + Vector2(26, -8 + with_me * 11), -1])
				with_me += 1
				continue
			var row := int(seen.get(at, 0))
			seen[at] = row + 1
			out.append([slot, c, row])
		return out

	## Outside any visibility filter: heat is the one signature you cannot hide.
	## A threat always visible is one you can route around, at a price in salvage.
	## Why: docs/why/StarchartScreen.md#hellbender-marker
	func _draw_hellbender() -> void:
		if not show_icons or not Run.hellbender_alive() \
				or Run.hellbender_at >= Run.map.size():
			return
		var c := _screen_pos(Run.map[Run.hellbender_at])
		_diamond(c, 7.0, _UNDER)
		_diamond(c, 6.0, UITheme.EMBER)
		var at_text := c + Vector2(-46, -14)
		draw_string(UITheme.pixel_font(), at_text + Vector2(1, 1), "THE HELLBENDER",
			HORIZONTAL_ALIGNMENT_CENTER, 92, 8, Color(0, 0, 0, 0.85))
		draw_string(UITheme.pixel_font(), at_text, "THE HELLBENDER",
			HORIZONTAL_ALIGNMENT_CENTER, 92, 8, UITheme.EMBER)

	## Invalidated by its only two inputs, the ledger and your position, so never stale.
	var _work_key: String = ""
	var _work_berths: Dictionary = {}

	## The chart is where a contract becomes playable, drawn outside the visibility filter.
	## Told apart by form: a square for a quest, a diamond for the hellbender, brackets for YOU.
	## Why: docs/why/StarchartScreen.md#quest-markers
	func _draw_quests() -> void:
		if not show_icons or Run.map.is_empty():
			return
		var gold := EncounterDrawer.TAG_QUEST
		for raw in Run.map:
			var n: MapGen.MapNode = raw
			if not OptionTable.holds_quest(n):
				continue
			var c := _screen_pos(n)
			# Backed in ink first, for the reason the party diamond is: the deep
			# systems sit over the core, which is the brightest thing here.
			var said := OptionTable.quest_name(n)
			if said == "":
				continue
			# Backed in ink first, for the reason the party diamond is: the deep
			# systems sit over the core, which is the brightest thing here.
			var box := Rect2(c - Vector2(7, 7), Vector2(14, 14))
			draw_rect(box.grow(1.0), _UNDER, false, 3.0)
			draw_rect(box, gold, false, 1.0)
			draw_string(UITheme.pixel_font(), c + Vector2(-46, -13), said,
				HORIZONTAL_ALIGNMENT_CENTER, 92, 8, gold)


	## THE PICKED QUEST'S ROUTE, hop by hop from YOU: the chart's dotted line
	## (`_dotted`) in the quest's gold, a jump to a hop.
	func _draw_quest_route() -> void:
		if not show_icons or quest_route.size() < 2:
			return
		var gold := EncounterDrawer.TAG_QUEST
		for i in range(quest_route.size() - 1):
			var a := _screen_pos(Run.map[quest_route[i]])
			var b := _screen_pos(Run.map[quest_route[i + 1]])
			var d := a.distance_to(b)
			var steps := int(d / 4.0)
			for k in range(1, steps):
				if k % 2 == 0:
					continue
				var q := a.lerp(b, float(k) / float(steps)).round()
				draw_rect(Rect2(q - Vector2(1, 1), Vector2(4, 4)), _UNDER, true)
				draw_rect(Rect2(q, Vector2(2, 2)), gold, true)

	## Takes the first side clear of stars, HUD, goal line, A.S.H., words and tags.
	func place_quest_tags() -> Array:
		var out: Array = []
		if quest_tags.is_empty():
			return out
		var f := UITheme.pixel_font()
		var inv := get_global_transform().affine_inverse()
		var avoid: Array = []
		if quest_avoid.is_valid():
			for g in quest_avoid.call():
				avoid.append(inv * (g as Rect2))
		# AN EVENT QUEST'S OWN NAME, which `_draw_quests` prints above its star:
		# the tag beside it must not sit on it
		for t in quest_tags:
			var qn: MapGen.MapNode = Run.map[int(t.index)]
			if show_icons and OptionTable.holds_quest(qn):
				var said := OptionTable.quest_name(qn)
				var sw := f.get_string_size(said, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
				var c := _screen_pos(qn)
				avoid.append(Rect2(c + Vector2(-sw * 0.5, -21), Vector2(sw, 10)))
		var rad := maxf(5.0, 12.0 * zoom)
		var frame := Rect2(Vector2(2, 2), size - Vector2(4, 4))
		for t in quest_tags:
			var at := _screen_pos(Run.map[int(t.index)]).round()
			var w := ceilf(f.get_string_size(String(t.text), HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x) + 8.0
			var best := Rect2()
			var best_hits := 1 << 30
			for d: float in [rad + 2.0, rad + 12.0, rad + 26.0, rad + 44.0]:
				for o: Vector2 in [Vector2(d, -d * 0.6 - 11.0), Vector2(d, d * 0.6),
						Vector2(-w - d, -d * 0.6 - 11.0), Vector2(-w - d, d * 0.6),
						Vector2(-w * 0.5, -d - 11.0), Vector2(-w * 0.5, d)]:
					var r := Rect2((at + o).round(), Vector2(w, 11))
					var hits := 0 if frame.encloses(r) else 100
					for a in avoid + out:
						if r.grow(1.0).intersects(a as Rect2):
							hits += 10
					var near := r.grow(rad)
					for sp in _pickable:
						if near.has_point(sp) and _rect_dist(r, sp) < rad:
							hits += 1
					if hits < best_hits:
						best_hits = hits
						best = r
					if hits == 0:
						break
				if best_hits == 0:
					break
			out.append(best)
		return out

	static func _rect_dist(r: Rect2, p: Vector2) -> float:
		var q := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
		return q.distance_to(p)

	## Each quest's number and word in a box, a leader to its star; the picked
	## one in the quest's gold, the rest in the chart's own cold ink.
	func _draw_quest_tags() -> void:
		quest_rects = []
		if not show_icons or quest_tags.is_empty() or ladder_hush:
			return
		quest_rects = place_quest_tags()
		var f := UITheme.pixel_font()
		for i in quest_tags.size():
			var t: Dictionary = quest_tags[i]
			var r: Rect2 = quest_rects[i]
			var col: Color = EncounterDrawer.TAG_QUEST if bool(t.get("picked", false)) else UITheme.CHILL
			var at := _screen_pos(Run.map[int(t.index)]).round()
			var lead := Vector2(clampf(at.x, r.position.x, r.end.x), clampf(at.y, r.position.y, r.end.y))
			draw_line(at, lead, _UNDER, 3.0)
			draw_line(at, lead, col, 1.0)
			draw_rect(r, Color(0.04, 0.055, 0.08, 0.92), true)
			draw_rect(r, col, false, 1.0)
			draw_string(f, r.position + Vector2(4, 9), String(t.text), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)

	func _draw_work() -> void:
		if not show_icons or Run.map.is_empty():
			return
		# Cached because this is inside `_draw()`, which reruns on every mouse motion.
		var key := "%d|%d" % [Run.at, Run.contracts.size()]
		if key != _work_key:
			_work_key = key
			_work_berths = {}
			for manufacturer in Run.delivery_manufacturers():
				_work_berths[manufacturer] = _nearest_berths(manufacturer, 3)
		for raw in Run.contracts:
			var job: ContractData = raw
			if job.state != ContractData.State.TAKEN:
				continue
			if job.at < 0 or job.at >= Run.map.size():
				continue
			var c := _screen_pos(Run.map[job.at])
			var col := DB.manufacturer_colour(job.manufacturer)
			# Backed in ink for the reason the party diamond is: the deep systems
			# sit over the core, which is the brightest thing on the chart.
			draw_arc(c, 9.0, 0.0, TAU, 20, _UNDER, 3.0)
			draw_arc(c, 9.0, 0.0, TAU, 20, col, 1.0)
			# A second, tighter ring for a hunt, so the two kinds are told apart
			# without a label. Fetch is an open circle; hunt has something in it.
			if job.kind == ContractData.Kind.HUNT:
				draw_arc(c, 4.0, 0.0, TAU, 12, col, 1.0)

		# Marks where a job is handed over: a filled square, since it is somewhere to land.
		# Only the nearest three berths: marking all twelve across the disc read as a rash.
		# Why: docs/why/StarchartScreen.md#delivery-berths
		for manufacturer in _work_berths:
			var hcol := DB.manufacturer_colour(manufacturer)
			for st in _work_berths[manufacturer]:
				var p := _screen_pos(st)
				draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 10)), _UNDER, false, 3.0)
				draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 10)), hcol, false, 1.0)
				draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), hcol, true)

	## Galaxy distance, not jumps: a straight line cannot know the route, so it only says which way.
	## Why: docs/why/StarchartScreen.md#delivery-berths
	func _nearest_berths(manufacturer: StringName, want: int) -> Array:
		var here := Run.node_at()
		var found: Array = []
		for raw in Run.map:
			var st: MapGen.MapNode = raw
			if ContractData.berth_of(st, manufacturer):
				found.append(st)
		found.sort_custom(func(a: MapGen.MapNode, b: MapGen.MapNode) -> bool:
			return a.gal.distance_squared_to(here.gal) \
				< b.gal.distance_squared_to(here.gal))
		return found.slice(0, want) if found.size() > want else found

	func _diamond(c: Vector2, d: float, col: Color) -> void:
		draw_polyline([c + Vector2(0, -d), c + Vector2(d, 0),
			c + Vector2(0, d), c + Vector2(-d, 0), c + Vector2(0, -d)], col, 1.0)

	## Label only: two nested bracket boxes (here and in `Glyph.draw_glyph`) read as a fault.
	## Why: docs/why/StarchartScreen.md#you-marker
	func _draw_you(p: Vector2, tiny: bool) -> void:
		# (not while the zoom ladder closes on your star: a label grown with the
		# picture is a smear of letter-sized blocks)
		if ladder_hush or ui_a <= 0.01:
			return
		var flare := Color(UITheme.FLARE, UITheme.FLARE.a * ui_a)
		var under := Color(_UNDER, _UNDER.a * ui_a)
		# Brackets stay only where the glyph draws none: zoomed out, removing them hid the ship.
		if tiny:
			var b := 5.0
			var o := p - Vector2(4, 4)
			var w := 21.0
			for corner in [
					[Vector2(0, 0), Vector2(1, 1)],
					[Vector2(w, 0), Vector2(-1, 1)],
					[Vector2(0, w), Vector2(1, -1)],
					[Vector2(w, w), Vector2(-1, -1)]]:
				var k: Vector2 = o + corner[0]
				var dd: Vector2 = corner[1]
				var h := Rect2(k + Vector2(0, -1 if dd.y < 0 else 0), Vector2(b * dd.x, 1)).abs()
				var v := Rect2(k + Vector2(-1 if dd.x < 0 else 0, 0), Vector2(1, b * dd.y)).abs()
				draw_rect(h.grow(1.0), under, true)
				draw_rect(v.grow(1.0), under, true)
				draw_rect(h, flare, true)
				draw_rect(v, flare, true)
		# the label on a rim of the void, so it reads over the bulge too
		for off: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
			draw_string(UITheme.pixel_font(), p + Vector2(-14, 30) + off, "YOU",
				HORIZONTAL_ALIGNMENT_CENTER, 40, 8, under)
		draw_string(UITheme.pixel_font(), p + Vector2(-14, 30), "YOU",
			HORIZONTAL_ALIGNMENT_CENTER, 40, 8, flare)

	## Built once: nothing here depends on pan or zoom.
	func _build_stars() -> void:
		var r_max := _radius() * DISC
		# The seed is part of the key: a new run means a new sky, and the cache
		# has to know that.
		var galaxy := "%d|%d" % [Run.galaxy_kind, Run.galaxy_seed]
		var key := "%s|%.1f|%.2f" % [galaxy, r_max, _squash()]
		if key == _star_key:
			return
		# A new run means a new sky, and every entry for the old one is unreachable.
		if galaxy != _sky_galaxy:
			_sky_cache.clear()
			ChartSky.drop_others()
			_sky_galaxy = galaxy
		if remembers_view:
			last_size = size
		# the first chart of a run: its field built while the hull was picked
		_take_ahead()
		if _sky_cache.has(key):
			_restore_sky(_sky_cache[key])
			_star_key = key
			return
		_star_key = key
		built_here += 1
		_build_field()
		_sky_cache[_star_key] = _snapshot_sky()

	## Runs on a worker too: nothing here may touch a node, the cache or other-thread writes.
	func _build_field() -> void:
		var g := _g()
		var r_max := _radius() * DISC
		_star_pos = PackedVector2Array()
		_star_col = PackedColorArray()
		_star_big = PackedByteArray()
		_star_dim = PackedByteArray()
		_core_skipped = 0
		_core_rad = PackedFloat32Array()
		_core_col = PackedColorArray()
		_core_size = PackedByteArray()
		_core_ang = PackedFloat32Array()

		var sq := _squash()
		var arms := _arms()

		# Dark clouds flattened to lobes first, because everything placed has to ask them.
		_dark_c = PackedVector2Array()
		_dark_r = PackedFloat32Array()
		for raw_dark in _clouds():
			var dc: NebulaField.Cloud = raw_dark
			if dc.kind != NebulaField.Kind.DARK:
				continue
			for l in dc.lobes.size():
				var dcen: Vector2 = (dc.pos + dc.lobes[l]) * r_max
				var drad: float = dc.lobe_r[l] * r_max
				_dark_c.append(dcen)
				_dark_r.append(drad)
		# Nothing static inside the cleared core; drawn-space measure keeps the shadow round.
		var shadow := _shadow_r()
		var clear := _core_clear()

		## Measured in drawn space, round: the unsquashed radius left static stars by the hole.
		## This also fixes the dark crescents above and below the core.
		## Why: docs/why/StarchartScreen.md#core-ownership


		# The wash between the arms: unlit space, as flat black makes the arms look like cutouts.
		var seed := (_gseed() * 2654435761 + 24601) & 0x7fffffff
		for i in 7000:
			seed = (seed * 1103515245 + 12345) & 0x7fffffff
			var t := float((seed >> 13) % 10000) / 10000.0
			seed = (seed * 1103515245 + 12345) & 0x7fffffff
			var t2 := float((seed >> 13) % 10000) / 10000.0
			seed = (seed * 1103515245 + 12345) & 0x7fffffff
			var t3 := float((seed >> 13) % 10000) / 10000.0
			var rr: float = pow(t, float(g.dust)) * (1.0 + 0.5 * pow(t, 8.0)) * r_max
			var a: float = t2 * TAU
			var near := 1.0 - clampf(rr / r_max, 0.0, 1.0)
			var col := Color("#0d1420")
			if t3 > 0.88:
				col = Color("#182231")
			elif near > 0.6 and t3 > 0.6:
				col = Color("#241c22")
			var pd := Vector2(cos(a), sin(a) * sq) * rr
			var e_pd: float = pd.length()
			if pd.length() < shadow:
				continue
			if t3 < _own_at(e_pd, clear):
				_core_skipped += 1
				_core_rad.append(e_pd)
				_core_col.append(col)
				_core_size.append(0)
				_core_ang.append(atan2(pd.y, pd.x))
				continue
			_star_pos.append(pd)
			_star_col.append(col)
			_star_big.append(1 if t3 > 0.94 else 0)
			_star_dim.append(1 if col.v < 0.19 else 0)

		# --- the clouds. Before the arms, so arm stars draw in front of them.
		_build_nebulae(r_max)

		# --- the arms themselves
		seed = (_gseed() * 2654435761 + 1337) & 0x7fffffff
		for i in 30000:
			seed = (seed * 1103515245 + 12345) & 0x7fffffff
			var t := float((seed >> 13) % 10000) / 10000.0
			seed = (seed * 1103515245 + 12345) & 0x7fffffff
			var t2 := float((seed >> 13) % 10000) / 10000.0
			seed = (seed * 1103515245 + 12345) & 0x7fffffff
			var t3 := float((seed >> 13) % 10000) / 10000.0
			seed = (seed * 1103515245 + 12345) & 0x7fffffff
			# Its own roll for extinction, or a cloud eats one side of an arm or bright stars only.
			var t4 := float((seed >> 13) % 10000) / 10000.0

			# Two populations rather than one falloff. A single exponent cannot
			# be both dense at the core and present at the rim.
			var inner: bool = float(i % 100) < float(g.core_share) * 100.0
			var u: float = pow(t, float(g.core_pow) if inner else float(g.halo_pow))
			var hole: float = g.ring
			if hole > 0.0:
				u = hole + u * (1.0 - hole)
			# The outer few percent stretch past the nominal edge so density decays, not truncates.
			# Why: docs/why/StarchartScreen.md#galaxy-rim
			u *= 1.0 + 0.55 * pow(t, 8.0)
			var rr: float = u * r_max
			var a: float = 0.0
			if int(g.arms) <= 0:
				# No spiral structure at all, which is what an elliptical is.
				a = t2 * TAU
			else:
				var loose: float = 2.6 if (i % 3 == 0) else 1.0
				var spread: float = (t2 - 0.5) * (0.55 + rr / r_max * 0.9) * loose * float(g.spread)
				a = _shape_angle(rr / r_max, i % arms, spread)
			var chaos: float = g.chaos
			if chaos > 0.0:
				a += (t3 - 0.5) * chaos * 4.0
				rr *= 1.0 + (t2 - 0.5) * chaos

			# Not clamped: the tail runs past 1.0 so the fringe fades rather than forming a rim.
			var far := rr / r_max
			var near := 1.0 - clampf(far, 0.0, 1.0)
			# Brightness thins with radius too, so the edge goes wispy and not just sparser.
			var col := Color("#141c28") if far > 0.7 else Color("#1b2534")
			if far > 1.0:
				col = Color("#101722")
			if t3 > 0.93 + minf(far, 1.0) * 0.05 and far < 1.05:
				col = Color("#9fb4cc")
			elif t3 > 0.78 + minf(far, 1.0) * 0.14 and far < 1.2:
				col = Color("#3d5064")
			elif near > 0.72:
				col = Color("#4a3a2c")
			var pa := Vector2(cos(a), sin(a) * sq) * rr
			# Behind a dark cloud: tempered to three quarters, as the diffuse field gives it body.
			var ext := _extinct(pa) * 0.74
			if ext > 0.02:
				if t4 < ext:
					continue
				# What survives is dimmed as well as thinned, so the cloud
				# reddens the field it covers rather than merely perforating it.
				col = col.darkened(ext * 0.5)
			var e_pa: float = pa.length()
			if pa.length() < shadow:
				continue
			if t3 < _own_at(e_pa, clear):
				_core_skipped += 1
				_core_rad.append(e_pa)
				_core_col.append(col)
				_core_size.append(0)
				_core_ang.append(atan2(pa.y, pa.x))
				continue
			_star_pos.append(pa)
			_star_col.append(col)
			_star_big.append(1 if (t3 > 0.97 and near > 0.4) else 0)
			_star_dim.append(1 if col.v < 0.19 else 0)

		# --- and the dark half of the same material, after the arms so that it
		# takes stars away instead of adding to them.
		_build_dust(r_max)

		# --- a tidal stream, for galaxies that are losing
		if g.tail:
			seed = (_gseed() * 2654435761 + 5150) & 0x7fffffff
			for i in 2600:
				seed = (seed * 1103515245 + 12345) & 0x7fffffff
				var t := float((seed >> 13) % 10000) / 10000.0
				seed = (seed * 1103515245 + 12345) & 0x7fffffff
				var t2 := float((seed >> 13) % 10000) / 10000.0
				seed = (seed * 1103515245 + 12345) & 0x7fffffff
				var t3 := float((seed >> 13) % 10000) / 10000.0
				# Thins along its length: the far end is already gone.
				if t3 < t * 0.75:
					continue
				var a: float = -0.9 + t * 1.7 + (t2 - 0.5) * (0.10 + t * 0.30)
				var rr: float = (0.55 + t * 1.5) * r_max
				var col := Color("#18202c")
				if t3 > 0.95:
					col = Color("#4e6076")
				elif t3 > 0.82:
					col = Color("#2b384a")
				var pt2 := Vector2(cos(a), sin(a) * sq) * rr
				var e_pt2: float = pt2.length()
				if pt2.length() < shadow:
					continue
				if t3 < _own_at(e_pt2, clear):
					_core_skipped += 1
					_core_rad.append(e_pt2)
					_core_col.append(col)
					_core_size.append(0)
					_core_ang.append(atan2(pt2.y, pt2.x))
					continue
				_star_pos.append(pt2)
				_star_col.append(col)
				_star_big.append(0)
				_star_dim.append(1 if col.v < 0.19 else 0)

		# Core built from pixels: draw_circle is smooth-edged and reads as a blurry sticker.
		var bulge := _radius() * float(g.bulge)
		seed = (_gseed() * 2654435761 + 4242) & 0x7fffffff
		for i in 600:
			seed = (seed * 1103515245 + 12345) & 0x7fffffff
			var u := float((seed >> 13) % 10000) / 10000.0
			seed = (seed * 1103515245 + 12345) & 0x7fffffff
			var v := float((seed >> 13) % 10000) / 10000.0
			# The bulge spans the whole core: the motion rule decides which stars survive.
			var frac: float = pow(u, 1.5)
			var rr2: float = shadow * 1.2 + frac * (bulge + clear)
			var aa: float = v * TAU
			var heat := 1.0 - clampf(rr2 / maxf(1.0, bulge), 0.0, 1.0)
			var col2 := Color("#7a3f16")
			if heat > 0.75:
				col2 = Color("#ffdca0")
			elif heat > 0.5:
				col2 = Color("#cc641c")
			var pb := Vector2(cos(aa), sin(aa) * sq) * rr2
			var e_pb: float = pb.length()
			if pb.length() < shadow:
				continue
			if v < _own_at(e_pb, clear):
				_core_skipped += 1
				_core_rad.append(e_pb)
				_core_col.append(col2)
				_core_size.append(0)
				_core_ang.append(atan2(pb.y, pb.x))
				continue
			_star_pos.append(pb)
			_star_col.append(col2)
			_star_big.append(0)
			_star_dim.append(0)

		# --- the halo and the wreckage, last, so they sit on top of the disc they
		# are in front of.
		_build_clusters(r_max)
		_build_remnants(r_max)

	## A builder missing from SKY_FIELDS is omitted silently, which is the one way this goes wrong.
	func _snapshot_sky() -> Dictionary:
		var out: Dictionary = {}
		for f in SKY_FIELDS:
			out[f] = get(f)
		return out

	func _restore_sky(snap: Dictionary) -> void:
		for f in SKY_FIELDS:
			set(f, snap[f])

	func _seed_rng(salt: int) -> void:
		_rng = (_gseed() * 2654435761 + salt) & 0x7fffffff

	func _rnd() -> float:
		_rng = (_rng * 1103515245 + 12345) & 0x7fffffff
		return float((_rng >> 13) % 10000) / 10000.0

	## Ordered dither keyed to galaxy space, not screen, or the pattern crawls on pan.
	## A fixed threshold pattern reads as gas; a random stipple reads as noise.
	## Why: docs/why/StarchartScreen.md#nebula-dither
	const _DITHER4 := [
		0.031, 0.531, 0.156, 0.656,
		0.781, 0.281, 0.906, 0.406,
		0.219, 0.719, 0.094, 0.594,
		0.969, 0.469, 0.844, 0.344,
	]

	## Clouds are drawn before the arms, so a dark one let the full field shine through it.
	## Smoothstepped for a visible edge; cheap per star, and zero if no dark clouds rolled.
	## Why: docs/why/StarchartScreen.md#dark-nebula-extinction
	func _extinct(p: Vector2) -> float:
		var e := 0.0
		for i in _dark_r.size():
			var d: float = (p - _dark_c[i]).length() / maxf(1.0, _dark_r[i])
			if d >= 1.0:
				continue
			var f: float = 1.0 - d
			e = maxf(e, f * f * (3.0 - 2.0 * f))
		# Returned raw: the diffuse field tempers it, but bright point sources need the full value.
		# Why: docs/why/StarchartScreen.md#dark-nebula-extinction
		return e

	func _dither(p: Vector2) -> float:
		return float(_DITHER4[(int(p.y) & 3) * 4 + (int(p.x) & 3)])

	## Cached pixels fade out across the band the live layer fades in, or a ring shows.
	## Lanes had no hole test: dust ran straight across an edge-on galaxy and into the hole.
	## Why: docs/why/StarchartScreen.md#static-pixel-gate
	func _static_ok(p: Vector2, t: float) -> bool:
		# Round, in drawn space: nothing is behind the hole.
		if p.length() < _shadow_r():
			return false
		# Round in drawn space: near the hole means near it on screen, not in galaxy coordinates.
		return t >= _own_at(p.length(), _core_clear())

	## Hand a piece of material to the live layer instead of dropping it.
	func _to_core(p: Vector2, col: Color, size: int) -> void:
		_core_rad.append(p.length())
		_core_ang.append(atan2(p.y, p.x))
		_core_col.append(col)
		_core_size.append(size)

	## Gas takes the nearest system's region colour, so the sky shows whose space you are in.
	## Why: docs/why/StarchartScreen.md#region-tint
	func _region_tint(at: Vector2) -> Color:
		var best := INF
		var col := Color("#3a4a5c")
		for n in _gmap():
			var node: MapGen.MapNode = n
			var d: float = (_polar(node) - at).length_squared()
			if d < best:
				best = d
				col = MapGen.star_colour(node)
		return col

	## Emission gas runs H-alpha rose, reflection blue, each pulled toward the region colour.
	const _NEB_EMIT := Color("#b8506a")
	const _NEB_REFLECT := Color("#4f74c0")

	## Three near-tone ramps per cloud: a single ramp reads as a splotch, not as interior.
	## Variants stay near each other; pushed apart the cloud stops being one object.
	## Why: docs/why/StarchartScreen.md#nebula-ramps
	func _neb_ramp(base: Color, hue: float, sat: float, val: float,
			emission: bool) -> PackedColorArray:
		var c := Color.from_hsv(fposmod(base.h + hue, 1.0),
			clampf(base.s * sat, 0.0, 1.0), clampf(base.v * val, 0.0, 1.0))
		var out := PackedColorArray()
		out.append(c.darkened(0.62))
		out.append(c.darkened(0.36))
		out.append(c)
		out.append(c.lightened(0.30 if emission else 0.14))
		return out

	## Appended before the arms so arm stars draw in front: occluding gas is a sticker.
	## The dark half is a separate pass after the arms, as a lane must hide stars.
	## Why: docs/why/StarchartScreen.md#nebula-layers
	func _pn_reach(kind: int, a: float) -> float:
		match kind:
			NebulaField.Shape.BIPOLAR:
				# Pinched waist: a dense torus blocks the wind, so it escapes through the poles.
				return 0.30 + 0.98 * pow(absf(sin(a)), 0.72)
			NebulaField.Shape.ANSAE:
				# A ring with a knot either side where a jet stalled; the power keeps knots tight.
				return 1.0 + 0.42 * pow(absf(cos(a)), 16.0)
			_:
				return 1.0

	## How much a planetary is squashed on screen — its inclination, mostly.
	func _pn_squash(kind: int) -> float:
		match kind:
			NebulaField.Shape.ELLIPTICAL:
				return 0.32
			NebulaField.Shape.BIPOLAR:
				# Nearly round, because the shape is carried by the reach above
				# and squashing it as well would flatten the lobes away.
				return 0.94
			_:
				return 0.58

	func _build_nebulae(r_max: float) -> void:
		_neb_pos = PackedVector2Array()
		_neb_top = PackedFloat32Array()
		_neb_name = PackedStringArray()
		var g := _g()
		# Placement is `NebulaField`'s answer: the sector screen needs it, and copies would drift.
		var field := _clouds()
		if field.is_empty():
			return
		for k in field.size():
			var cloud: NebulaField.Cloud = field[k]
			var centre := cloud.pos * r_max
			var rad := cloud.radius * r_max
			var emission: bool = cloud.emission
			# A stream per cloud, so later detail cannot shift the next one's placement.
			_seed_rng(90210 + k * 7919)
			# Weighted toward the gas: region colours are chrome and made clouds panel-coloured.
			# A shell keeps more of its own colour; at 0.68 planetary and remnant looked alike.
			# Why: docs/why/StarchartScreen.md#cloud-colour
			var pull: float = 0.88 if cloud.hollow > 0.0 else 0.68
			var base: Color = _region_tint(centre).lerp(cloud.base_colour(), pull)
			# Pulled back in saturation and value: full H-alpha rose was magenta and drowned arms.
			base = Color.from_hsv(base.h, base.s * 0.82, base.v * 0.72)

			# Three near-tones give a hotter and a cooler half, as real objects do.
			var ramps: Array[PackedColorArray] = []
			ramps.append(_neb_ramp(base, 0.0, 1.0, 1.0, emission))
			if emission:
				ramps.append(_neb_ramp(base, 0.038, 1.10, 1.07, true))
				ramps.append(_neb_ramp(base, -0.062, 0.86, 0.91, true))
			else:
				ramps.append(_neb_ramp(base, -0.036, 0.92, 1.05, false))
				ramps.append(_neb_ramp(base, 0.034, 1.10, 0.93, false))

			# Three lobes. One blob is a smudge; overlapping lobes give the thing
			# a shape, and where two of them meet it comes out brighter for free.
			var lobes: Array[Vector2] = []
			var lobe_r: Array[float] = []
			# Shape comes from NebulaField, like the position: the outline and
			# the tooltip have to agree with what is drawn here.
			for l in cloud.lobes.size():
				lobes.append(cloud.lobes[l] * r_max)
				lobe_r.append(cloud.lobe_r[l] * r_max)

			var twist_k: float = _rnd() * TAU
			# Tone frequency scales with the cloud; fixed ones left small clouds one flat tone.
			var tf: float = 5.0 / maxf(1.0, rad)
			# The highest pixel this cloud manages to place, for the label.
			var top := 0.0
			# Enough samples that blocks overlap in the middle; at a third the clouds hid.
			# Raised with the halved block size: the wash is static arrays, one rect apiece.
			# Why: docs/why/StarchartScreen.md#nebula-sampling
			var px := clampi(int(rad * rad * 0.62), 1200, 12000)
			if cloud.kind == NebulaField.Kind.DARK:
				# Denser, because a dark cloud has to actually obscure.
				px = int(float(px) * 1.5)
			elif cloud.hollow > 0.0:
				# The planetary is the smallest object and budget goes with radius squared.
				# The remnant spends its budget on a wide faint band and discards most at arc gaps.
				# Why: docs/why/StarchartScreen.md#nebula-sampling
				px = int(float(px) * (4.0 if cloud.kind == NebulaField.Kind.PLANETARY else 3.4))
			# `lobes.size()`, not a literal 3: shells have one lobe, so samples read out of bounds.
			# Why: docs/why/StarchartScreen.md#shell-lobes
			var nl := lobes.size()
			for i in px:
				var lobe := i % nl
				var lr: float = lobe_r[lobe]
				var local: Vector2
				var d := 0.0
				if cloud.hollow > 0.0:
					var remnant: bool = cloud.kind == NebulaField.Kind.REMNANT
					# Sample the shell as a shell: carving it from a solid cloud wasted samples.
					# Why: docs/why/StarchartScreen.md#shell-wall
					var wall: float = NebulaField.EXTENT * 0.80
					var th: float = wall * (1.0 - cloud.hollow) * 0.7
					if remnant:
						# A remnant is a region, not a ring: its front has broken up.
						# Why: docs/why/StarchartScreen.md#shell-wall
						wall = NebulaField.EXTENT * 0.64
						th = wall * 0.46
					# Two rolls summed: dense along the wall, thinning to either
					# side of it. One roll would give a band with hard edges.
					var off: float = (_rnd() + _rnd() - 1.0) * th
					var a2: float = _rnd() * TAU
					var u: float = (wall + off) * lr
					# Interior fill has its brightness decided below, not from the wall falloff.
					var filled := false
					if remnant:
						# A shock front ploughs lumpy gas: a wobbling wall with whole arcs missing.
						# Why: docs/why/StarchartScreen.md#remnant-ragged
						var wob: float = sin(a2 * 3.0 + twist_k) * 0.36 \
							+ sin(a2 * 7.0 - twist_k * 2.1) * 0.21 \
							+ sin(a2 * 13.0 + twist_k * 0.7) * 0.13
						u += wob * th * 1.5 * lr
						# Thin arcs are dropped outright: an old remnant is bright ropes and haze.
						var arc: float = 0.16 + 0.66 * maxf(0.0,
							sin(a2 * 2.0 + twist_k * 1.3))
						if _rnd() > arc:
							continue
						local = lobes[lobe] \
							+ Vector2(cos(a2) * u, sin(a2) * u * 0.82)
					elif _rnd() < 0.44:
						# A planetary's inside glows, as its star still ionises it.
						# Why: docs/why/StarchartScreen.md#planetary-interior
						filled = true
						var ai: float = _rnd() * TAU
						var ui: float = pow(_rnd(), 0.55) * wall * lr 							* _pn_reach(cloud.shape, ai)
						local = lobes[lobe] + Vector2(cos(ai) * ui,
							sin(ai) * ui * _pn_squash(cloud.shape)) 							.rotated(twist_k * 0.5)
						# Brightest just inside the rim: depth through a shell peaks there.
						var fi: float = ui / maxf(0.001, wall * lr * _pn_reach(cloud.shape, ai))
						d = 0.17 + 0.38 * fi * fi
					else:
						# Smooth, elliptical by tilt, not torn like the remnant.
						# Why: docs/why/StarchartScreen.md#planetary-shape
						var pu: float = u * _pn_reach(cloud.shape, a2)
						local = lobes[lobe] + Vector2(cos(a2) * pu,
							sin(a2) * pu * _pn_squash(cloud.shape)) 							.rotated(twist_k * 0.5)
					if not filled:
						d = clampf(1.0 - absf(off) / maxf(0.001, th), 0.0, 1.0)
						d = d * d * (3.0 - 2.0 * d)
						if remnant:
							# Held below top brightness: a remnant must not rival a planetary.
							d *= 0.58
						else:
							# Squared again: a planetary is a single shell with a sharp inner rim.
							d = d * d * (3.0 - 2.0 * d)
				else:
					var rr: float = pow(_rnd(), 0.8) * lr
					var a2: float = _rnd() * TAU
					local = lobes[lobe] \
						+ Vector2(cos(a2) * rr, sin(a2) * rr * 0.82)

					# Density is the strongest lobe, not the sum, so overlaps brighten, not double.
					for m in nl:
						d = maxf(d, 1.0 - minf(1.0,
							(local - lobes[m]).length() / maxf(1.0, lobe_r[m])))
					d = d * d * (3.0 - 2.0 * d)
				# Filaments. Gas is ropey, not spherical, and two sines that do
				# not divide into each other say so well enough at this size.
				var fil: float = 0.5 + 0.5 * sin(local.x * 0.085 + twist_k) \
					* sin(local.y * 0.11 - twist_k * 1.7)
				# A remnant is mostly filaments (the Veil is ropes), so it takes more from them.
				if cloud.kind == NebulaField.Kind.REMNANT:
					d *= 0.18 + 0.82 * fil
				else:
					d *= 0.52 + 0.48 * fil

				var world := centre + local
				var dith := _dither(world)
				if d < dith:
					continue
				var wash_moves := not _static_ok(world, _rnd())
				# Dither offsets the ramp boundaries too, so the cloud never shows a contour line.
				var lvl := d - dith * 0.18
				var step := 0
				if lvl > 0.60 and emission:
					step = 3
				elif lvl > 0.42:
					step = 2
				elif lvl > 0.24:
					step = 1
				# Tone uses a much lower frequency than the filaments, so the cloud does not band.
				# Three terms, none a multiple of another: two made bands that read as two clouds.
				# Why: docs/why/StarchartScreen.md#nebula-tone
				var tone: float = 0.5 + 0.20 * sin(local.x * tf + twist_k * 0.6) \
					+ 0.19 * sin(local.y * tf * 1.3 - twist_k * 1.9) \
					+ 0.15 * sin((local.x + local.y) * tf * 2.3 + twist_k)
				var vi := 0
				if tone > 0.64:
					vi = 1
				elif tone < 0.37:
					vi = 2
				var col: Color = ramps[vi][step]
				if wash_moves:
					# Close enough to the hole that it should be going round it.
					_to_core(world, col, 2)
					continue
				top = maxf(top, centre.y - world.y)
				_star_pos.append(world)
				_star_col.append(col)
				# Every tier is a block: a full-resolution core erased the interior, leaving a mat.
				# Why: docs/why/StarchartScreen.md#nebula-blocks
				_star_big.append(2)
				# Never flagged dim: a colour mass blinking out mid-drag shows; thinning stars not.
				_star_dim.append(0)

			# Only a cloud forming stars gets them; a planetary gets its one central star.
			# Why: docs/why/StarchartScreen.md#nebula-stars
			if cloud.kind == NebulaField.Kind.PLANETARY:
				for w in 5:
					var wob := Vector2(_rnd() - 0.5, _rnd() - 0.5) * rad * 0.05
					_star_pos.append(centre + wob)
					_star_col.append(Color("#ffffff") if w < 2 else Color("#bff0ff"))
					_star_big.append(0)
					_star_dim.append(0)

			if cloud.kind == NebulaField.Kind.EMISSION:
				var young := 5 + int(_rnd() * 5.0)
				for y in young:
					var sp: Vector2 = centre + lobes[y % lobes.size()] \
						+ Vector2(_rnd() - 0.5, _rnd() - 0.5) * rad * 0.5
					var young_moves := not _static_ok(sp, _rnd())
					var ycol := Color("#e8f2ff") if _rnd() > 0.5 \
						else Color("#a9c6e6")
					if young_moves:
						_to_core(sp, ycol, 1)
						continue
					_star_pos.append(sp)
					_star_col.append(ycol)
					_star_big.append(0)
					_star_dim.append(0)

			_neb_pos.append(centre)
			# A floor, for the pathological cloud whose lobes all fell below its
			# centre and which would otherwise wear its name through its middle.
			_neb_top.append(maxf(top, rad * 0.3))
			_neb_name.append(cloud.name)

	## Drawn by taking pixels away, so this pass must run after the arms, not with the nebulae.
	func _build_dust(r_max: float) -> void:
		var g := _g()
		var gas: float = float(g.get("gas", 1.0))
		var sq := _squash()
		var arms := _arms()
		_seed_rng(31337)
		# No arms or no gas means no lane; globules still run, as they belong to the clouds.
		# A lane runs along an arm's inner edge, where the wave piles material up.
		# Why: docs/why/StarchartScreen.md#dust-lanes
		var n := 0 if (int(g.arms) <= 0 or gas < 0.35) \
			else int(2800.0 * clampf(gas, 0.0, 1.6))
		for i in n:
			var rn: float = 0.18 + pow(_rnd(), 0.8) * 0.78
			# Narrow: arms are drawn wide, so a lane spread the same angle just thins the arm.
			var along: float = -0.38 + (_rnd() - 0.5) * 0.12
			var ang: float = _shape_angle(rn, i % arms, along + (_rnd() - 0.5) * 0.04)
			var rr: float = rn * r_max * (1.0 + (_rnd() - 0.5) * 0.02)
			var p := Vector2(cos(ang), sin(ang) * sq) * rr
			# Thins outward, like everything else in the disc.
			if _rnd() > 1.05 - rn * 0.55:
				continue
			var _moves_lane := not _static_ok(p, _rnd())
			var t := _rnd()
			var col := Color("#080c14")
			if t > 0.86:
				col = Color("#16121c")
			elif t > 0.6:
				col = Color("#0b1119")
			if _moves_lane:
				_to_core(p, col, 2)
				continue
			_star_pos.append(p)
			_star_col.append(col)
			# The gas size class: one dark block over four stars beats four dark pixels.
			_star_big.append(2)
			# Not dim: dropping these during a drag would uncover the stars and open the lanes.
			_star_dim.append(0)

		# Globules: the cold cores inside a cloud, where the next generation is
		# already collapsing. Without them a nebula is an even wash.
		for k in _neb_pos.size():
			var c: Vector2 = _neb_pos[k]
			# The drawn extent, near enough: `top` is vertical and foreshortened.
			var nr: float = _neb_top[k] * 1.3
			for b in 2:
				var off := Vector2(_rnd() - 0.5, _rnd() - 0.5) * nr
				var br: float = nr * (0.08 + _rnd() * 0.12)
				for m in int(br * br * 0.55) + 12:
					var q := off + Vector2(_rnd() - 0.5, _rnd() - 0.5) * 2.0 * br
					if q.distance_to(off) > br:
						continue
					var w := c + q
					if _dither(w) > 0.72:
						continue
					var _moves_globule := not _static_ok(w, _rnd())
					if _moves_globule:
						_to_core(w, Color("#070b12"), 0)
						continue
					_star_pos.append(w)
					_star_col.append(Color("#070b12"))
					_star_big.append(0)
					_star_dim.append(0)

	## Out of the plane, so a knot above the disc says the galaxy is solid, not a picture.
	## Not squashed: the halo is a sphere, a circle in projection however flat the disc.
	## Why: docs/why/StarchartScreen.md#globular-clusters
	func _build_clusters(r_max: float) -> void:
		_seed_rng(60613)
		_glob_c = PackedVector2Array()
		_glob_i = PackedInt32Array()
		var count := 11 + int(_rnd() * 9.0)
		for k in count:
			# Concentrated toward the middle but reaching well past the rim. The
			# outermost of these are barely bound to anything.
			var rr: float = (0.22 + pow(_rnd(), 1.9) * 1.25) * r_max
			var a: float = _rnd() * TAU
			var centre := Vector2(cos(a), sin(a)) * rr
			var rad: float = r_max * (0.008 + _rnd() * 0.014)
			var n := 44 + int(_rnd() * 56.0)
			_glob_c.append(centre)
			_glob_i.append(_star_pos.size())
			for m in n:
				# pow 2.6 is what makes it a cluster and not a smudge: nearly
				# all of it inside a fifth of the radius, a scattering outside.
				var d: float = pow(_rnd(), 2.6) * rad
				var a2: float = _rnd() * TAU
				var p := centre + Vector2(cos(a2), sin(a2) * 0.92) * d
				var _moves_cluster := not _static_ok(p, _rnd())
				var t := _rnd()
				# A globular is the brightest small thing, so one behind a dark cloud ruins it.
				var cext := _extinct(p)
				if cext > 0.02 and _rnd() < cext:
					continue
				# An old population. There is no blue left in one of these.
				var col := Color("#5d5442")
				if t > 0.82:
					col = Color("#e0d0aa")
				elif t > 0.5:
					col = Color("#9c8b68")
				if _moves_cluster:
					_to_core(p, col, 0)
					continue
				_star_pos.append(p)
				_star_col.append(col)
				_star_big.append(0)
				_star_dim.append(1 if t <= 0.5 else 0)
			_glob_i.append(_star_pos.size())

	## Only the star: pulsars live inside remnants and planetaries, already drawn.
	## Why: docs/why/StarchartScreen.md#pulsars
	func _build_remnants(r_max: float) -> void:
		_pulsar = PackedVector2Array()
		if not _gmap().is_empty():
			for nd in _gmap():
				var node: MapGen.MapNode = nd
				if node.type == MapGen.NodeType.PULSAR:
					_pulsar.append(_polar(node))
			return

		# With no map (the launcher) a remnant gets its neutron star at its centre.
		# Why: docs/why/StarchartScreen.md#pulsars
		for raw in _clouds():
			var cloud: NebulaField.Cloud = raw
			if cloud.kind == NebulaField.Kind.REMNANT:
				_pulsar.append(cloud.pos * r_max)

	## THE FLASHES: is anything lit at `t`? A pulsar on its beat, or a burst.
	func _flash_lit(t: float) -> bool:
		if _burst_lit(t):
			return true
		for i in _pulsar.size():
			var period := 1.1 + float(i) * 0.43
			if fmod(t, period) / period <= 0.16:
				return true
		return false

	## Each pulsar on its own beat so they never fall into step; a pixel either side at the peak.
	func _draw_flashes(ci: CanvasItem, t: float) -> void:
		var r_max := _radius() * DISC
		if r_max <= 0.0:
			return
		var c := centre_px()
		var ang := turn()
		for i in _pulsar.size():
			var period := 1.1 + float(i) * 0.43
			var ph := fmod(t, period) / period
			if ph > 0.16:
				continue
			var env := 1.0 - ph / 0.16
			var q := (c + _proj(_pulsar[i] / r_max, ang)).round()
			if q.x < 1.0 or q.y < 0.0 or q.x > size.x - 1.0 or q.y > size.y:
				continue
			ci.draw_rect(Rect2(q, Vector2.ONE), Color("#e6fbff") if env > 0.45 else Color("#6fb2c4"), true)
			if env > 0.55:
				ci.draw_rect(Rect2(q + Vector2(1, 0), Vector2.ONE), Color("#8fd2e0"), true)
				ci.draw_rect(Rect2(q - Vector2(1, 0), Vector2.ONE), Color("#8fd2e0"), true)
		_draw_bursts(ci, t, c, size.x, size.y)

	## Whether any of the three burst channels is lit at `t`: the first half of
	## `_draw_bursts`, so the burst canvas is redrawn only while there is one.
	func _burst_lit(t: float) -> bool:
		for slot in 3:
			var period: float = 13.0 + float(slot) * 8.0
			var idx := int(floor(t / period))
			if _frac(_hash2(idx, slot, 6021)) > 0.4:
				continue
			var age: float = t - float(idx) * period \
				- _frac(_hash2(idx, slot, 77)) * (period - 1.2)
			if age >= 0.0 and age <= 0.85:
				return true
		return false

	## Rare on purpose: the one caught in the corner of the eye makes the sky feel alive.
	## Why: docs/why/StarchartScreen.md#gamma-ray-bursts
	func _draw_bursts(ci: CanvasItem, t: float, c: Vector2, w: float, h: float) -> void:
		# Three independent channels on different periods, so bursts never fall
		# into a rhythm. Each period is a window in which one MAY fire.
		for slot in 3:
			var period: float = 13.0 + float(slot) * 8.0
			var idx := int(floor(t / period))
			var seed_h := _hash2(idx, slot, 6021)
			# Most windows pass without one.
			if _frac(seed_h) > 0.4:
				continue
			var age: float = t - float(idx) * period - _frac(_hash2(idx, slot, 77)) * (period - 1.2)
			if age < 0.0 or age > 0.85:
				continue

			# Fast rise, slower fall — a burst is not a fade in and out.
			var env: float = 0.0
			if age < 0.06:
				env = age / 0.06
			else:
				env = pow(1.0 - (age - 0.06) / 0.79, 2.2)
			if env <= 0.02:
				continue

			var where := Vector2.ZERO
			if _frac(_hash2(idx, slot, 131)) < 0.55 and not _star_pos.is_empty():
				# In our own galaxy: on top of a real star, so it belongs to the
				# thing it is happening in.
				var si := int(_frac(_hash2(idx, slot, 149)) * float(_star_pos.size()))
				var sp := _star_pos[clampi(si, 0, _star_pos.size() - 1)]
				where = c + _proj(sp / (_radius() * DISC), turn())
			else:
				# Out in the sky behind, and it parallaxes with it.
				where = size * 0.5 + sky_pan * 0.12 + Vector2(
					_frac(_hash2(idx, slot, 163)) * w,
					_frac(_hash2(idx, slot, 181)) * h) - Vector2(w, h) * 0.5 + size * 0.5
			if where.x < 0.0 or where.y < 0.0 or where.x > w or where.y > h:
				continue
			where = where.round()

			var core := Color("#ffffff") if env > 0.5 else Color("#dfe9ff")
			ci.draw_rect(Rect2(where, Vector2.ONE), core, true)
			# The cross, and a fainter diagonal, both scaled by the envelope.
			var arm := int(round(env * 7.0))
			for k in range(1, arm + 1):
				var fade := Color("#cfe0ff") if k <= arm / 2 else Color("#5c7ba8")
				ci.draw_rect(Rect2(where + Vector2(k, 0), Vector2.ONE), fade, true)
				ci.draw_rect(Rect2(where - Vector2(k, 0), Vector2.ONE), fade, true)
				ci.draw_rect(Rect2(where + Vector2(0, k), Vector2.ONE), fade, true)
				ci.draw_rect(Rect2(where - Vector2(0, k), Vector2.ONE), fade, true)
			var diag := int(round(env * 3.0))
			for k in range(1, diag + 1):
				var d2 := Color("#7f9dc8")
				ci.draw_rect(Rect2(where + Vector2(k, k), Vector2.ONE), d2, true)
				ci.draw_rect(Rect2(where + Vector2(-k, k), Vector2.ONE), d2, true)
				ci.draw_rect(Rect2(where + Vector2(k, -k), Vector2.ONE), d2, true)
				ci.draw_rect(Rect2(where + Vector2(-k, -k), Vector2.ONE), d2, true)

	## Texels per row of the star data textures (`ChartSky` places the stars
	## from them).
	const SKY_TEX_W := 2048

	## Meshes of n empty quads, by n. They hold nothing but their vertex count,
	## so every chart can share them.
	static var _quad_meshes: Dictionary = {}

	## Build the galaxy if it is not built, and hand it to the sky. False while
	## the chart has no size, when there is nothing to build it at.
	func _ensure_gpu() -> bool:
		if size.x <= 0.0 or size.y <= 0.0 or _sky == null:
			return false
		_build_stars()
		_sky.setup(self)
		return true

	## A float texture of `n` items from their raw bytes, SKY_TEX_W to a row.
	static func _data_tex(bytes: PackedByteArray, n: int, per: int,
			fmt: Image.Format) -> ImageTexture:
		var rows := maxi(1, ceili(float(n) / float(SKY_TEX_W)))
		bytes.resize(SKY_TEX_W * rows * per)
		return ImageTexture.create_from_image(
			Image.create_from_data(SKY_TEX_W, rows, false, fmt, bytes))

	## The two huge quads exist so the mesh's bounds never let the renderer cull the layer.
	static func _quads(n: int) -> ArrayMesh:
		if n <= 0:
			return null
		if _quad_meshes.has(n):
			return _quad_meshes[n]
		if _quad_meshes.size() >= 12:
			_quad_meshes.clear()
		var v := PackedVector2Array()
		v.resize(n * 6)
		v[0] = Vector2(-1e6, -1e6)
		v[1] = Vector2(1e6, 1e6)
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = v
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		_quad_meshes[n] = m
		return m

