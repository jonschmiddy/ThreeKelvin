class_name StarchartScreen
extends Control

## The star chart.
##
## Nodes are icons tinted by region, not squares with names under them: a label
## under every node is what forced the old chart to clip STATION to STATIO, and
## it made a spatial decision read like a list. You pick a node, the panel tells
## you what is there, and one button commits.
##
## Ship stats and cargo used to live here too. They belong to the SHIP screen —
## this one answers a single question: where next, and what will it cost.

var _chart: MapChart
var _layer_cells: HBoxContainer
var _layer_text: Label
var _all_btn: Button
var _icons_btn: Button
var _links_btn: Button
var _region_btn: Button
var _sight_btn: Button
var _reach_btn: Button

## Which rings the chart draws. Both on by default: they are how the two
## limits are read, and a player who has never seen them cannot know to
## look for them.
## HOW THE CHART IS BEING LOOKED AT, and STATIC because the screen is not.
##
## `show_starchart` builds a fresh StarchartScreen on every arrival, so anything
## held on the instance is a preference the player re-enters after every single
## jump. Reported for LOCAL REGION -- "it's kinda annoying always having to zoom
## into my local region every jump" -- and the other three are the same control
## in the same corner, so they would have been reported next.
##
## Static rather than saved: these describe how somebody is looking at the map
## this session, not anything about the run. A save that restored a zoom level
## would be a save that could restore a WRONG one.
static var _sight_on := true
static var _reach_on := true
## Whether the view is held on the local region. A TOGGLE rather than a
## jump, because the press has an obvious undo and a jump does not: you
## would otherwise have to find the way back out by hand every time.
static var _region_on: bool = false
## And whether the filter is off entirely.
static var _show_all: bool = false

## WHERE THE CHART WAS POINTED, kept for the same reason the toggles are.
##
## LOCAL REGION persisted and the VIEW did not, which reads as the toggle being
## broken: it stayed lit while the chart sat fully zoomed out. The cause is that
## `frame_region` divides by `size`, and during `_build` the control has not been
## laid out yet -- so `size` is zero, the wanted zoom is zero, and it clamps to
## ZOOM_MIN. It was re-deriving the view at the one moment it could not.
##
## Storing the view itself sidesteps that entirely, and answers the actual ask:
## the zoom and the position stay put across a jump, whether they came from the
## region button, the wheel or a drag.
##
## `_view_map` is a crude galaxy fingerprint. A new run is a new galaxy and the
## old pan means nothing in it, so a mismatch throws the saved view away.
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

## One row plus its separation, for sizing the box to the list.
const NEIGH_ROW := 16.0
var _jump: Button

## -1 is no selection, which is how the chart opens: the galaxy first, and a
## destination only once you have chosen to look at one.
var _selected: int = -1

## The overlay itself, or null once it has been dismissed.
var _primer: Control = null

## WHICH RUN HAS ALREADY BEEN PRIMED, as a galaxy seed.
##
## GALAXY_SCALE.md section 5 says to gate on `Run.trail.is_empty()` and spend no
## save key on this. THE FIRST HALF OF THAT IS WRONG ABOUT THE CODE: a run
## starts with `trail = PackedInt32Array([0])`, the system you begin on, so the
## trail is never empty and a primer gated on emptiness would never once appear.
## `size() <= 1` is the same intent -- you have not jumped yet -- and does work.
##
## The brief then accepts re-showing the card if you open the chart, dismiss it
## and reopen before jumping. That is cheap to do better: this is static, so it
## outlives a screen that is rebuilt on every open, and holding the SEED rather
## than a bool means a second run in the same session is primed again rather
## than silently skipped. Still no save key, still nothing on the wire.
static var _primed_for: int = -1

func setup() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	Sig.map_changed.connect(_refresh)
	Sig.resources_changed.connect(_refresh)
	# Where the others are, and what they have used up. Both arrive as roster
	# pushes rather than as anything this screen asked for, so the chart has to
	# be told — a partner who jumps while you are staring at the map is exactly
	# the case a redraw-on-input would miss.
	Sig.party_changed.connect(_refresh)
	Sig.party_map_changed.connect(_refresh)
	_refresh()

func _build() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 4)
	add_child(root)

	# --- depth strip: the greed clock, always visible
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 7)
	_layer_text = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	strip.add_child(_layer_text)
	_layer_cells = HBoxContainer.new()
	_layer_cells.add_theme_constant_override("separation", 2)
	strip.add_child(_layer_cells)
	strip.add_child(UITheme.body("CORE", UITheme.THEM, UITheme.FS_SMALL))
	var strip_gap := Control.new()
	strip_gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip.add_child(strip_gap)
	# All three of these are dev only. They exist to look at GENERATION — whether
	# the shells are spaced sensibly, how the lattice is wired, whether a galaxy
	# rolled something odd — and every one of them shows the player the map they
	# are supposed to be earning. See DevMode.
	if DevMode.enabled:
		_icons_btn = Widgets.button("HIDE SYSTEMS", _on_toggle_icons)
		_icons_btn.custom_minimum_size = Vector2(112, 14)
		strip.add_child(_icons_btn)

	# Debug: the lattice MapGen actually built, rather than the slice of it you
	# are allowed to use. Pairs with the button beside it — that one shows every
	# system, this one shows how they are wired, and a generation problem is
	# usually only visible with both on.
		_links_btn = Widgets.button("SHOW REACH", _on_toggle_links)
		_links_btn.custom_minimum_size = Vector2(128, 14)
		strip.add_child(_links_btn)

	# And the systems those links run to. Without this the one above draws the
	# whole lattice over a chart that is still hiding most of the galaxy.
		_all_btn = Widgets.button("SHOW ALL SYSTEMS", _on_toggle_all)
		_all_btn.custom_minimum_size = Vector2(140, 14)
		strip.add_child(_all_btn)
	root.add_child(strip)

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
	_chart.cleared.connect(_on_chart_cleared)
	_chart.view_dragged.connect(_on_view_dragged)
	var chart_wrap := Widgets.panel_with(_chart)
	chart_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_child(chart_wrap)

	# OVER THE CHART, bottom right, sitting on the scale bar it belongs with.
	# Both answer "where am I and how big is this", so together they read as
	# one instrument in the corner rather than a toolbar item at one end of
	# the screen and a decoration at the other.
	#
	# A child of the CHART rather than of the panel around it, so it follows
	# the chart's rect and needs no second set of margins to stay put.
	_region_btn = _corner_toggle(_on_region, 0, 112.0)
	# TOP right, not stacked under the scale block. These two answer "how far
	# can I see and go", which is a question you ask while reading the map --
	# the scale bar and LOCAL REGION are about the view itself and belong
	# together down there.
	# THRUSTER REACH first because it is the LONGER label. These are right
	# aligned, so the longest line on top gives a clean descending edge; the
	# other order notches inward and then back out.
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
	# Wraps to a second line instead of widening the panel. A Label reports the
	# width of its longest unbroken line as its minimum size, so a name like
	# OMEGA CALLOUS SECUNDUS at head size pushed the whole sidebar out and the
	# chart shrank to make room — the panel changing width as you point at
	# different systems is far worse than a name taking two lines.
	#
	# AND THE HEIGHT IS RESERVED, because that fix only moved the problem onto
	# the other axis. A wrapped name is TALLER, the panel's height is its
	# content's, and the chart shares a row with it -- so selecting THETA ABYSSAL
	# SECUNDUS pushed every row below it down and resized the chart, while OMEGA
	# WICK REACH did not. Two lines' worth is always held whether the name needs
	# it or not, so nothing below can move.
	#
	# `-- namefit` still wraps every name five galaxies generate at this font
	# and this width -- 94.4% one line, 5.6% two, none three -- and still fails
	# if that stops being true. It is a WIDTH check now rather than the evidence
	# for a height: the name sizes to its own lines like everything else here.
	#
	# NO RESERVED HEIGHT, AND THE SLACK LIVES BELOW THE ROWS INSTEAD.
	#
	# This block held a fixed height so that a long blurb could not push the
	# rows down -- and it worked, and the cost was a fixed gap under every short
	# description, which is most of them. Both readings of that trade have now
	# been looked at on screen and the gap is the worse one.
	#
	# What makes giving it up cheap is that the panel ALREADY anchors its bottom
	# half: there is an expanding spacer between the rows and the in-range list,
	# so IN RANGE and JUMP sit where they sit no matter what happens above them.
	# Letting the header size to its own text spends that spacer rather than
	# moving anything a hand is aimed at. The rows shift by a line or two
	# between systems; the buttons do not move at all.
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

	# NO SPACER HERE ANY MORE. It used to hold the slack between the rows and
	# the in-range list, which meant the list itself had to declare a height --
	# and a declared height is a demand. The list expands instead, so it IS the
	# slack: it swells when there is little above it and shrinks when there is
	# much, and either way the thing below it stays on the screen.

	_hint = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size = Vector2(228, 0)
	right.add_child(_hint)
	_neigh = VBoxContainer.new()
	_neigh.add_theme_constant_override("separation", 1)
	# A CEILING, because the list is as long as the galaxy is generous and JUMP
	# sits under it. Seventeen rows in a built-up ship's range pushed the button
	# off the bottom of the panel outright -- the one control the screen exists
	# to reach. Any list that grows without a bound will do that eventually; this
	# one just got there first.
	#
	# Scrolled rather than truncated, because every row is somewhere you can
	# legally fly and hiding a destination is worse than making it a scroll.
	#
	# AND THE CEILING WAS A FLOOR, which is why the button went off the bottom
	# again. `NEIGH_H` was written to `custom_minimum_size`, and a minimum size
	# is a DEMAND: with eleven rows of system facts above it the panel no longer
	# had 128 pixels spare, and the list took them anyway. Twelve systems in
	# range and JUMP was below the screen.
	#
	# It expands into what is left instead. The floor is one row, so it never
	# vanishes; everything past that is whatever the header and the rows have
	# not already spent, and the button underneath cannot be pushed anywhere.
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

	mid.add_child(Widgets.panel_with(right))

	# --- key: icons are only better than labels if you can learn them
	var key := HBoxContainer.new()
	key.add_theme_constant_override("separation", 8)
	key.add_child(UITheme.body("KEY", UITheme.COLD, UITheme.FS_SMALL))
	# THE COLOURS COME FROM `MapGen.swatch` NOW, not from five literals here.
	#
	# They had gone wrong. This drew SYSTEM in violet and STATION in pale blue,
	# which is what the chart used when a system was tinted by who HELD it. The
	# colours have been starlight for a while now and every glyph on the map is
	# `star_colour` -- so the legend was naming two colours that appear nowhere
	# on the thing it is a legend for, which is worse than having no legend.
	for item in _legend_items():
		key.add_child(item)
	root.add_child(key)

	# THE VIEW THE PLAYER LEFT IT IN. The toggles above are static, so this is
	# where a freshly built screen catches up with them -- painting the labels,
	# handing the rings to the chart, and re-framing if the region was held.
	_paint_rings()
	_paint_region()
	_chart.show_all = _show_all
	if _all_btn != null:
		_all_btn.text = "SHOW KNOWN ONLY" if _show_all else "SHOW ALL SYSTEMS"
	# The VIEW itself is restored by the chart on its first resize -- see
	# `_view_zoom`. Re-framing here would run before layout and land on ZOOM_MIN,
	# which is the bug that made LOCAL REGION look like it had stopped working.

	# LAST, so it is the last child and therefore the top one. There is no
	# CanvasLayer on this screen and it does not need one: sibling order is draw
	# order, and the primer is the only thing that has ever wanted to be above
	# the chart.
	_build_primer()

## THE FIRST TIME YOU OPEN THE CHART IN A RUN, what this galaxy is and how to
## read the thing you are looking at.
##
## GALAXY_SCALE.md section 5. Two halves, and the second is the one that earns
## it: the chart draws systems as coloured glyphs, hangs two range rings off
## your ship and puts danger and fuel on every row of the list, and until now
## nothing anywhere said what any of that meant. The galaxy blurb on its own
## would have been a popup; the legend is the reason to build it.
##
## It is NOT the only home for this. The no-selection destination panel says the
## galaxy's name, type and blurb permanently, and says so in its own comment:
## the card is the moment, the panel is the reference at jump forty.
func _build_primer() -> void:
	if Run.trail.size() > 1 or _primed_for == Run.galaxy_seed:
		return
	_primed_for = Run.galaxy_seed

	# STOP, so the scrim eats the click that dismisses it rather than letting it
	# fall through onto a system glyph. Dismissing and selecting a destination
	# with one press would make the card feel like it had swallowed the click.
	_primer = Control.new()
	_primer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_primer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_primer)

	var scrim := ColorRect.new()
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(UITheme.VOID.r, UITheme.VOID.g, UITheme.VOID.b, 0.82)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_primer.add_child(scrim)

	# A CenterContainer, NOT `set_anchors_preset(PRESET_CENTER)`. The preset moves
	# the anchors to the middle and leaves the offsets alone, so the card lays
	# itself out from the centre point going down and right and hangs off the
	# bottom of the screen -- which is exactly what it did.
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


## The half of the card that does not change with the galaxy.
##
## SHORTER, NOT RESHAPED. These were three long sentences that came to seven
## lines of small caps -- a wall you skip rather than a legend you read. Tried as
## keyed rows first, which cut the length and read as a spec sheet: COLOUR and
## CIRCLES are not things on the chart you can point at, so labelling them made
## instructions look like data. They stay sentences and lose half their words.
##
## TWO OF THE THREE WERE ALSO WRONG, which is worse in teaching text than
## anywhere else in the game:
##
## "Outrunning your dish means arriving somewhere you never surveyed" promised
## exactly what `can_jump_to` forbids -- it wants `sensed`, so a system past your
## sight is drawn, priced and REFUSED. Reach can outrun sight on purpose (see
## `sense_radius_of`); what that buys is range you cannot spend, which is the
## opposite of the danger this line invented.
##
## "A short danger bar beside a long fuel one is a cheap trip somewhere awful"
## is inside out. `_neighbour_row` has said it correctly for months: a FULL
## danger gauge beside a NEARLY EMPTY fuel one is the cheap trip into somewhere
## awful. This was a paraphrase of that comment that inverted it.
const PRIMER_LEGEND: Array[String] = [
	"A system's colour is its star: pale is ordinary, red and blue are rarer.",
	"You fly as far as THRUSTER REACH and see as far as SENSOR RANGE. Past your sight a jump is priced and then refused: NOT SCANNED.",
	"Each row shows danger, then fuel. Full danger beside empty fuel is a cheap trip somewhere awful.",
	"Danger climbs in five named steps -- EASY, ROUGH, HARD, BRUTAL, LETHAL -- and what a system is willing to offer you climbs with it.",
]


## One wrapped paragraph at the card's width.
func _primer_para(text: String, colour: Color) -> Label:
	var l := UITheme.body(text, colour, UITheme.FS_SMALL)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(PRIMER_W - 28, 0)
	return l


## What this galaxy does to a fuel tank, in the words section 4 made authorable.
##
## `reach` and `density` are archetype constants and `roll()` does not jitter
## them, so these thresholds do not move under a re-roll -- unlike `squash`,
## which is jittered and is why the tilt line is decided per run rather than per
## kind.
func _primer_cost() -> Array[String]:
	var out: Array[String] = []
	var reach: float = float(Run.galaxy.get("reach", 1.0))
	var dens: float = float(Run.galaxy.get("density", 1.0))
	# SENTENCES, NOT ROWS. The legend above is instruction and reads better cut
	# to the bone; this is the galaxy talking about itself, in the same voice as
	# the blurb directly over it, and clipping it to "Tight." lost the half that
	# was worth reading.
	if reach >= 1.08:
		out.append("A wide disc. The crossings are long and every one of them is fuel.")
	elif reach <= 0.85:
		out.append("A tight disc. Everything is close, and a tank goes further here than it looks.")
	if dens >= 1.15:
		out.append("It is thick with systems -- there will be more places to stop than you can afford to.")
	elif dens <= 0.80:
		out.append("It is thin of systems. Expect stretches with nothing in them.")
	# THE ANISOTROPY, AND IT RUNS THE OTHER WAY FROM THE BRIEF.
	#
	# GALAXY_SCALE.md section 4 describes north-south jumps as costing 1.5x to
	# 3.6x LESS and lists measuring un-squashed as the alternative it did not
	# take. The code took it: `hop_distance` DIVIDES y by squash, so fuel is
	# spent on the round distance and not on the drawn one. The brief's note is
	# stale and section 4's "still open" ruling has already been decided by the
	# implementation.
	#
	# MEASURED on a Lenticular at squash 0.372: the same drawn gap of 0.200
	# costs 3 fuel sideways and 6 up-and-down. So the player-facing fact is the
	# one section 4 warned about as the price of this choice -- two systems that
	# look equally far apart are not -- and this is the line that says so.
	var sq: float = float(Run.galaxy.get("squash", 1.0))
	if sq < 0.5:
		out.append("It is steeply tilted, and the drawing lies about distance: a gap up or down costs far more than the same gap sideways.")
	if out.is_empty():
		out.append("Ordinary to cross: no unusual distances, and no unusual gaps.")
	return out


## The five shapes, in the colours the map actually paints them.
func _primer_glyphs() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	for item in _legend_items():
		row.add_child(item)
	return row


## The five node types, glyph and name, in the colours the map actually paints
## them. The corner KEY and the primer draw the same legend, so the list of
## what a legend contains lives once.
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


## Any press at all, which is the whole contract: it must never be a thing to
## get past. Handled as `_input` rather than `_gui_input` so a key works without
## the overlay having to hold focus -- and consumed, so the press that dismisses
## it does not also pick a destination.
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


## IS THERE ANYWHERE TO GO AT ALL -- asked of the whole map, the way every other
## part of the game asks it.
##
## This used to walk `Run.node_at().links` and say NOWHERE if none of THOSE was
## jumpable. But links are TOPOLOGY -- the lines the chart draws -- and travel is
## not link-gated: `reachable_from` is pure geometry, `in_range_of` scans the
## whole map with it, and `can_jump_to` never mentions links. A node has a
## handful of links and a great many systems in range.
##
## So the panel announced NOWHERE over a list of places you could fly to, any
## time your few linked neighbours were the unaffordable ones. Rare enough to be
## hard to reproduce on purpose, which is why it survived: it needs the links to
## be expensive while the rest of the neighbourhood is not.
##
## `has_legal_jump()` is the same question asked by `check_stranded()`, which
## ENDS THE RUN when it answers no. That is the right authority for a panel whose
## message is "the tank is dry": the header now says NOWHERE exactly when the run
## is one resolution away from being over, and never merely because the drawn
## lines went somewhere costly.
func _anywhere_to_go() -> bool:
	return Run.has_legal_jump()

func _on_node_picked(index: int) -> void:
	_selected = index
	_refresh()

func _refresh() -> void:
	var here: MapGen.MapNode = Run.node_at()

	_layer_text.text = "LAYER %d/%d" % [here.layer + 1, MapGen.LAYERS]
	_clear(_layer_cells)
	for i in MapGen.LAYERS:
		var cell := Panel.new()
		cell.custom_minimum_size = Vector2(11, 5)
		var col := UITheme.LINE
		if i < here.layer:
			col = UITheme.COLD
		elif i == here.layer:
			col = UITheme.FLARE
		cell.add_theme_stylebox_override("panel",
			UITheme.flat(col, Color(0, 0, 0, 0), 0, 0, 0))
		_layer_cells.add_child(cell)

	if _selected >= Run.map.size():
		_selected = -1
	_chart.set_state(_selected)

	_clear(_rows)

	if _selected < 0:
		_fill_neighbours(here)
		# Two different nothings: nothing chosen, versus nothing possible.
		if _anywhere_to_go():
			# With nothing selected the panel describes the galaxy itself. It is
			# the one thing on this screen that is always true, and a run should
			# know where it is happening.
			_dest_name.text = Run.galaxy_title.to_upper()
			_class("%s - %s" % [
				Run.galaxy_name, GalaxyGen.type_name(Run.galaxy_kind).to_upper()])
			_dest_blurb.text = GalaxyGen.blurb(Run.galaxy_kind)
			# AND THE COUNT STAYS. `_fill_neighbours` set it four lines up and
			# this blanked it, so the one state you are guaranteed to see -- the
			# start of a run, nothing selected -- was the one state with a list
			# and no number above it. The hint was an instruction back when it
			# read "pick somewhere"; it is a count of the rows underneath it now,
			# and those rows are right there.
		else:
			_dest_name.text = "NOWHERE"
			_class("")
			_dest_blurb.text = "No jump you can afford. The tank is dry."
			# Except here, where the header has already said it. "Nothing in
			# range" above an empty list under "No jump you can afford" is the
			# same sentence twice, and this panel has been shedding those.
			_hint.text = ""
		_jump.disabled = true
		return

	var t: MapGen.MapNode = Run.map[_selected]

	# A SYSTEM YOU ONLY KNOW ABOUT BECAUSE SOMEBODY IS PAYING YOU TO GO THERE.
	#
	# It answers exactly one question — why is this circled — and refuses the
	# rest. No CONTAINS, no development, no security, no operators, because none
	# of that was in the offer: the manufacturer said go here, it did not say what here
	# is. Reading the panel and reading the contract give the same information,
	# which is correct, because the contract is the only source there is.
	#
	# The jump button is left alone. Whether you can reach it is a question about
	# fuel and adjacency rather than about knowledge, and the answer does not
	# change because the place is unexplored.
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
		return

	# The name is the place; the classification is what kind of place it is -
	# how built up, how policed, and whose it is, in that order.
	_dest_name.text = MapGen.star_name(t)
	# NO CLASS LINE ON A SYSTEM AT ALL. Name, then blurb, with nothing between.
	#
	# MEASURED: 7.0% of systems are inside a cloud (161 of 2289 across seven
	# galaxies), so the line this replaced was EMPTY for nineteen systems in
	# twenty -- and an empty Label still reserves a line of its font, so the gap
	# between a name and its description was a blank fact almost every time.
	#
	# It read "PGC 5055 - SETTLEMENT" once: a galaxy catalogue number identical
	# for every system in the run, and a development word the DEVELOPMENT row
	# says again three lines below. Cutting that back to the nebula kept the one
	# part that was not noise -- but the panel was ALREADY saying it, down in the
	# WARNING group, and the header had been holding a line open to repeat it.
	_class("")
	_dest_blurb.text = MapGen.place_blurb(t)

	# THREE ANSWERS, IN THE ORDER YOU WANT THEM, and the order is the change.
	#
	# It used to run CONTAINS, DEVELOPMENT, SECURITY, OPERATORS, MARKET, STAR,
	# BODIES, NEARBY, DANGER, FUEL -- which put the sky between the market and
	# the fuel bill, so the physical facts about a place were interrupted by
	# trade and then resumed as travel. Eleven rows in one column with no shape
	# to them is a list you read from the top every time.
	#
	# WHAT IT IS, then WHO IS THERE, then WHAT IT COSTS. That is the order the
	# questions actually arrive in: you look at a system to find out what it is,
	# decide whether you want what is being sold, and commit the fuel last. The
	# gaps are four pixels rather than rules, because three separators in a
	# panel this narrow reads as three panels.
	_rows.add_child(_row("CONTAINS", _contains(t)))
	# WHAT IS IN THE SKY, which is the half of a system the panel never said.
	#
	# It decides what you will be offered: a red hypergiant is the only place
	# `corona` and `flare_shelter` exist, a blue one is the only place the wind,
	# the glare and the scouring do, and a giant is what `slipping_orbit` needs.
	# The chart has painted this since the star colours landed -- this is the
	# row that says what the colour MEANS, so it can be learned rather than
	# guessed at.
	#
	# In the star's own colour, so the swatch on the map and the words here are
	# obviously the same fact.
	_rows.add_child(_row("STAR", MapGen.star_kind(t), MapGen.star_colour(t)))
	# Only when there IS one, and under labels that are true: a gas giant is a
	# body IN this system and a pulsar is a neighbour, so neither of them is
	# "also". A row reading NONE for the commonest possible answer is blank four
	# times in nine and says nothing the other five.
	if t.gas_giant:
		_rows.add_child(_row("BODIES", "GAS GIANT"))
	if t.near_pulsar and t.type != MapGen.NodeType.PULSAR:
		_rows.add_child(_row("NEARBY", "PULSAR", Color("#8fd2e0")))
	# AND NO NEBULA ROW HERE, though one was written and taken out again.
	# `MapGen.hazards()` already returns "NEBULA" for an `in_nebula` system, so
	# the panel says it in the WARNING group at the bottom -- where it belongs,
	# because being inside gas is a thing that acts on the ship rather than a
	# thing to look at. A second row above would have been the same fact twice
	# in one panel, which is what this rework has spent its time deleting.
	#
	# What that costs is the cloud's NAME, which the class line used to carry
	# and nothing here does now. It is still on the chart itself: hovering the
	# gas names it. If it should be on the panel too, the honest place is inside
	# the existing warning rather than in a row of its own.

	_rows.add_child(_gap())
	# The three axes get their own rows. They are what the place IS, and reading
	# them off a single run-on classification line meant scanning a sentence to
	# answer "how policed is it".
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
		# "NONE", NOT "UNCLAIMED", and the word is the whole change.
		#
		# `DEVELOPMENT_NAMES[0]` is "Unclaimed" -- a real rung on the development
		# scale -- and this was a bare literal that happened to pick the same
		# word. Measured across 1938 systems in six galaxies: 416 are
		# development-zero, 484 have no berths, and 341 are BOTH -- so 18% of
		# systems printed UNCLAIMED on two consecutive rows.
		#
		# The row is not dropped, though dropping it was the tempting fix. The
		# two facts are not the same one: 143 systems have no berths while being
		# a real outpost or settlement, and "nobody operates this place" is worth
		# saying about those. NONE is already this panel's word for an absence --
		# SECURITY: NONE on the Core, SURVEY: NONE on a contract system.
		var who := "NONE"
		if not t.berths.is_empty():
			var names: Array[String] = []
			for m in t.berths:
				names.append(DB.short_name(DB.manufacturer_name(m)).to_upper())
			who = " / ".join(names)
		_rows.add_child(_row("OPERATORS", who))
		# The trade half of the same fact. Who operates a place decides what its
		# market is short of, so this belongs directly under OPERATORS — it is a
		# reading of that row, not a new fact about the system. Reading it before
		# committing the fuel is the whole point: a haul you plan is a trade and
		# a haul you discover on arrival is luck.
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
		if not Run.reachable(t):
			_rows.add_child(_row("FUEL", "OUT OF RANGE", Color("#7c6a58")))
		elif not t.sensed:
			# Quoting a price for a system the dish has not resolved is the same
			# mistake as quoting one for a system out of range: it answers a
			# question the ship cannot ask yet.
			_rows.add_child(_row("FUEL", "NOT SCANNED", Color("#7c6a58")))
		else:
			var cost := Run.fuel_cost_to(t)
			_rows.add_child(_fuel_row(cost, cost <= Run.fuel))
		var heading := "LATERAL" if t.layer == here.layer else "COREWARD  L%d" % (t.layer + 1)
		_rows.add_child(_row("HEADING", heading, UITheme.FLARE if t.layer > here.layer else UITheme.CHILL))

	# Hazards last, so the thing that might kill you is the thing your eye
	# stops on. The key is only written on the first line: three rows each
	# saying WARNING reads as three separate alarms rather than one list.
	var hz := MapGen.hazards(t)
	for i in hz.size():
		_rows.add_child(_row("WARNING" if i == 0 else "", hz[i], _WARN))

	# What is actually in reach, by name. "3 lateral hops left at this depth"
	# was a true sentence about a fact nobody can act on — it named a count
	# without naming the places, so you still had to go hunting on the chart for
	# them. The list is the same information you can click.
	_fill_neighbours(here)

	# Two different reasons a jump is impossible, and they need different words:
	# no route at all, versus a route you cannot currently pay for.
	_jump.disabled = not Run.can_jump_to(t)
	if not _jump.disabled:
		_jump.text = "JUMP"
	elif t.index == here.index:
		_jump.text = "YOU ARE HERE"
	elif not Run.reachable(t):
		_jump.text = "TOO FAR TO REACH"
	elif not t.sensed:
		# THE THIRD REASON, and it used to fall through to the fuel message.
		# `can_jump_to` is `sensed and reachable and afford`; the chain tested two
		# of the three and blamed the last one for everything left over, so a
		# ship with a full tank was told it was broke.
		_jump.text = "NOT SCANNED"
	else:
		_jump.text = "NOT ENOUGH FUEL"

## Everything within reach, nearest first, as a list you can click. Cleared
## systems stay on it — knowing the nearby ground is already stripped is the
## information that decides whether you farm on or dive.
func _fill_neighbours(here: MapGen.MapNode) -> void:
	_clear(_neigh)
	# WHAT YOU CAN SEE, not merely what is in engine range. `in_range_of` is
	# geometry -- it answers "could the drive cross that gap" and knows nothing
	# about the dish. Listing the unscanned ones here named every system in
	# thrust range, its type and its danger, for a ship that has never seen them.
	var near: Array = []
	for n in Run.in_range():
		if (n as MapGen.MapNode).sensed:
			near.append(n)
	# TELEGRAPHED FIRST, then nearest. Distance alone buried the four places the
	# chart actually names among fourteen it deliberately does not: RULING 1 says
	# every system but a station looks identical until you fly to it, so a list
	# sorted by distance is a list of near-identical rows with the notable ones
	# scattered through it.
	#
	# This orders by what the chart ALREADY tells you and never by what a system
	# holds -- reading `options` here would be the chart answering the question
	# arrival is for.
	near.sort_custom(func(x, y):
		var rx := _notable(x)
		var ry := _notable(y)
		if rx != ry:
			return rx < ry
		return MapGen.hop_distance(here, x) < MapGen.hop_distance(here, y))
	if near.is_empty():
		_hint.text = "Nothing in range. The tank is too low to reach anything."
		return
	# ONE NUMBER, because it is the only one the list below does not already
	# give you. This line used to carry two more.
	#
	# "N UNTOUCHED" counted cleared systems six lines above a list that dims a
	# cleared system's name to `#55647a`, row by row. "N NAMED FIRST" counted the
	# ones `_notable` pins to the top -- each of which draws its own glyph, so a
	# station in the list is legible as a station without a number promising one.
	# Both were the panel reading its own rows aloud.
	#
	# The count survives because you cannot see it: it is the number that decides
	# farm or dive, and it decides it before you have read a single row.
	#
	# The pinning itself stays -- `_notable` still sorts. What is gone is the
	# warning about it, which existed to stop a player reading the list as
	# distance-ordered. Nothing in a row invites that reading: there is no
	# distance column, only a name, a danger gauge and a fuel cost. The label was
	# guarding against a misreading the panel never offered, and asking a
	# question of its own to do it.
	_hint.text = "IN RANGE - %d SYSTEM%s" % [
		near.size(), "" if near.size() == 1 else "S"]
	for n in near:
		_neigh.add_child(_neighbour_row(n))
	# AND NOTHING IS SET HERE ANY MORE.
	#
	# This wrote `min(rows, NEIGH_H)` to `custom_minimum_size`, which reads like
	# a ceiling and is a DEMAND: Godot will not size a control under its minimum
	# for any reason, so with eleven rows of system facts above it the panel had
	# no 128 pixels spare and the list took them regardless. Twelve systems in
	# range and JUMP was off the bottom of the screen.
	#
	# The container expands into what is left instead -- see where it is built.
	# A short list leaves its slack inside its own box rather than above it,
	# which is the same hole in a better place, and a long one scrolls.

## How far up the in-range list a system sits. Lower is higher.
##
## ONLY WHAT THE CHART TELEGRAPHS. A contract target because somebody paid you to
## find it, the core because it is the run, a station because it is the one node
## type the chart names, a pulsar because it is placed against a nebula and you
## can see the shell. Everything else is an ordinary system and they are
## interchangeable from here BY DESIGN -- which is exactly why they sort below.
##
## Cleared last, and still listed: knowing the nearby ground is already stripped
## is what decides whether you farm on or dive.
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
	g.setup(n.type, MapGen.star_colour(n))
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

	# Danger and fuel are quantities you count, and this game already says
	# countable quantities in boxes — heat and energy both do. Rendering them as
	# "D1 1F" made a place in a galaxy read like a row in a spreadsheet.
	var dg := MicroGauge.new()
	dg.setup(MapGen.DANGER_MAX, n.danger, MicroGauge.Mode.DANGER)
	row.add_child(dg)
	var cost := Run.fuel_cost_to(n)
	var fg := MicroGauge.new()
	# Same cell count as danger so the two columns line up. A jump never costs
	# ten, and that is the point: a full-looking danger gauge beside a nearly
	# empty fuel one is the shape of a cheap trip into somewhere awful.
	fg.setup(MapGen.DANGER_MAX, cost,
		MicroGauge.Mode.FUEL if afford else MicroGauge.Mode.UNAFFORDABLE)
	row.add_child(fg)
	# The exact numbers are still one hover away, which is where precision
	# belongs once the shape of the thing is readable at a glance.
	# THE RUNG BY NAME, beside the number. "danger 7 of 10" is precise and
	# says nothing about how bad 7 IS. The ladder it sits on has been driving
	# enemy pools, loot gates, hull tiers and station stock since the scale
	# widened, and it has never once been spoken. See `MapGen.tier_name`.
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

## Empty a container NOW, not at the end of the frame.
##
## queue_free() defers to the end of the frame while add_child() is immediate,
## so a rebuild left the old children and the new ones in the container together
## for one frame before the old set vanished. In a VBoxContainer that reads as
## the list doubling in length and then collapsing — which is why every click
## made things appear and disappear. Removing from the tree first makes the
## rebuild atomic; the nodes are still freed, just not while they are visible.
func _clear(host: Node) -> void:
	for c in host.get_children():
		host.remove_child(c)
		c.queue_free()

## Hazard red. Warmer and louder than THEM, which is an enemy's colour and
## already spoken for — a warning has to win against a panel that is otherwise
## entirely cold blues.
const _WARN := Color("#d4614f")

## The class line under the name — and NOTHING AT ALL when it has nothing to
## say. An empty Label is not a zero-height Label: Godot reserves a line of the
## font whether or not there is text on it, so a blank class pushed the blurb
## down by a line and left a gap that read as a mistake. A hidden child is
## skipped by the container outright, which is the only way to actually get the
## space back.
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

## THE GAUGE PLUS THE WORD. The cells say how much; the word says what that
## amount is CALLED -- and the word is the half that transfers. A player
## learns BRUTAL once and can then read every system in the galaxy against
## it, where "seven cells" has to be counted again every time.
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

## Back to just the galaxy. Deliberately -1 rather than -2: the next refresh
## must not helpfully pick a system again.
## Everything the chart draws over the galaxy, off. Worth having as a button
## rather than a debug flag: the galaxy is the best thing on this screen and the
## systems are, unavoidably, 190 icons sitting on top of it.
## Frame the neighbourhood the ship is standing in. Reads the CURRENT node
## rather than the selection: the button is about where you are, and a
## selected system three rings away is where you are going.
## Lit while the view is held on your region, dim while it is not. EMBER and
## QUOTE are the launcher's own pair, so the two toggles in the game read as
## one idea rather than as two designs that happen to use brackets.
## Dragging away UNTICKS the box and leaves the view alone.
##
## The box says "the view is held on your region", and once you have dragged
## it somewhere else that is simply no longer true. Zooming back out on top
## of that would undo the drag you just made — the box is reporting, not
## commanding.
func _on_view_dragged() -> void:
	if not _region_on:
		return
	_region_on = false
	_paint_region()

## One pressable label in the chart's bottom-right corner, `row` lines up.
##
## Extracted from LOCAL REGION rather than copied. That control carries a
## paragraph of measured offsets and three of them drifting apart is the exact
## failure its comments exist to prevent.
func _corner_toggle(cb: Callable, row: int, wide: float, top := false) -> Button:
	var b := Widgets.button("", cb)
	# NO CHROME, the same treatment the launcher gives DEVELOPER MODE. A button
	# plate over a starfield reads as a dialog dropped on the galaxy; this is a
	# label you can press, not a form control.
	b.add_theme_font_size_override("font_size", UITheme.FS_SMALL)
	b.add_theme_color_override("font_hover_color", UITheme.ICE)
	b.add_theme_color_override("font_pressed_color", UITheme.HOT)
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, UITheme.empty())
	b.set_anchors_preset(Control.PRESET_TOP_RIGHT if top else Control.PRESET_BOTTOM_RIGHT)
	# Clear of the bar by its own padding, plus the height of the bar and
	# its label. Measured off the chart's own constants so the two cannot
	# drift apart when either is retuned.
	b.offset_left = -(wide + MapChart.BAR_PAD)
	b.offset_right = -MapChart.BAR_PAD
	# AND THE TEXT SITS AT THAT EDGE. The box was already flush with the
	# bar; a Button centres its label inside it, so the words stopped some
	# thirteen pixels short and the three lines of one instrument each
	# ended somewhere different.
	b.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# 8px of clear air over the SCALE BLOCK, not over the bar's rule. The
	# label is drawn above the rule, so the block's real top is the rule
	# minus the baseline offset and the cap height — measured off the
	# chart's own numbers rather than eyeballed, so retuning either moves
	# both together. `row` then stacks upward one line at a time.
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

## L IS THE LOCAL REGION, on the screen rather than on the chart control.
##
## It belongs here because the toggle does: `_on_region` repaints a button this
## screen owns and then tells the chart what to do, and a shortcut that reached
## past that would have the key and the button doing two different amounts.
##
## `_unhandled_key_input`, so WASD keeps its own handler on the chart and
## anything focused has had first refusal.
func _unhandled_key_input(e: InputEvent) -> void:
	var k := e as InputEventKey
	if k == null or not k.pressed or k.echo or k.keycode != KEY_L:
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
		# SAYS WHAT IT DOES NOW. It read "ALL LINKS" while it drew the whole
		# lattice; it draws one system's REACH, and the label has to keep up or
		# it is describing the version that was replaced.
		_links_btn.text = "SHOW REACH" if not _chart.show_links else "HIDE REACH"
	_chart.queue_redraw()

func _on_chart_cleared() -> void:
	_selected = -1
	_refresh()

func _on_jump() -> void:
	if _selected >= 0:
		Router.jump_to(_selected)


## A node glyph. Shape carries the type, tint carries the region — so the chart
## stays readable without a word under every node.
## Countable cells, small enough to live in a list row.
##
## The heat and energy gauges are the same idea at full size; this is the same
## language shrunk to fit beside a star's name, so a glance reads "nearly full,
## and red" without reading a number at all.
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
						# Green, because the danger ramp already owns blue,
						# amber and red. Sharing amber with mid danger meant a
						# cheap jump and a dangerous one looked the same.
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
	## A system, drawn as an object rather than a letter in a box.
	##
	## The old glyphs were abstract marks on a raised tile — and the tile was
	## most of the problem: 173 of them turned the chart into a lattice of UI
	## chips laid over a galaxy instead of places inside one. These are
	## free-standing silhouettes with their own 1px outline, which is what lets
	## them sit on a starfield without a plate underneath.
	##
	## Authored as pixel maps because that is how pixel art is authored. Working
	## them out as draw_rect arithmetic is how you end up with two bars and a
	## crossbar and call it a station.
	##
	## Eleven inks, not four. The first set had outline, ink, one shade and one
	## emissive, which draws a SHAPE and cannot draw an OBJECT — every
	## glyph came out as a flat silhouette with a light in it. The extra stops
	## are what the hull sprites already use and what ART_CONTRACT calls the
	## single most important rule: a bright top face, a darker front wall, and a
	## bright lip where the two meet. Thirteen pixels is plenty of room for that
	## break; it was the palette that was short.
	##
	##   .  empty          o  outline          %  lit face / rim
	##   #  ink (tint)     +  shaded wall      -  recess / underside
	##   *  emissive hot   @  emissive core    :  emissive falloff
	##   =  glass          ~  glass, shaded    !  cold light (beam)
	##
	## Everything except the emissives is derived from the region tint, so a
	## glyph still tells you whose space you are looking at.

	var type: MapGen.NodeType = MapGen.NodeType.SYSTEM
	var tint: Color = Color.WHITE

	func setup(t: MapGen.NodeType, c: Color) -> void:
		type = t
		tint = c
		custom_minimum_size = Vector2(13, 13)
		queue_redraw()

	func _draw() -> void:
		draw_glyph(self, Vector2.ZERO, type, tint, false, false)

	## Hostile: a dart nosing left, because enemies face left everywhere else in
	## the game and the chart should not be the exception.
	##
	## Lit along the leading edge and dark under the belly, so the wedge reads as
	## a hull banked toward you rather than a triangle. Two pixels of glass sit
	## behind the nose and the thruster burns at the tail — the only warmth on
	## it, and pointing the way it is running.
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

	## A hab ring with its lights on. Warm pixels are the tell: a station is the
	## only friendly thing out here, and warmth is only ever emitted, never ambient.
	##
	## The ring is a torus seen at the same three-quarter tilt as everything
	## else: the top arc catches the light, the bottom arc falls away, and the
	## hub burns in the middle. Drawn flat it was a letter O with a spark in it.
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

	## An unknown signal: a burst, radiating. Reads at a glance as "something is
	## transmitting here" without resorting to a question mark.
	##
	## Every ray falls off along its length — hot core, then the region tint, then
	## almost nothing at the frame edge. That gradient is the whole of the depth
	## here; there is no object to light. The uniform version read as a snowflake.
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

	## NOT DRAWN SINCE THE TYPE COLLAPSE, and kept rather than deleted. Every
	## system wears `_EVENT` now, but these are authored pixel art and the option
	## detail view is the obvious place a wreck or a contact wants a picture --
	## see ENCOUNTER_FLOW.md. Delete them if that never happens.
	##
	## A hulk with a bite out of it and its pieces drifting off. Asymmetric on
	## purpose — a regular wreck reads as a building.
	##
	## The torn edge is the darkest ink in the glyph and the intact plating above
	## it is the lightest, which is what makes the bite read as a hole through
	## the hull instead of a shape painted on it.
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

	## The hole itself: an accretion disc seen nearly edge-on, with the far side
	## of it lensed up over the top and down under the bottom.
	##
	## Read it as three things. The wide bright band through the middle is the
	## disc; it breaks either side of the centre because the far side of it
	## passes BEHIND the shadow, and the unbroken band just below is the near
	## side passing in front. The arcs over and under are that same disc again,
	## bent right around the hole — which is the one piece of a black hole that
	## no other object in the sky does, and so the piece worth spending pixels
	## on at this size.
	##
	## The middle is left EMPTY rather than drawn dark, and that is deliberate:
	## the glyph sits exactly on the galaxy centre, where the live layer is
	## turning a real accretion disc around a real shadow. Leaving the shadow
	## transparent means the marker frames the animation instead of covering it.
	##
	## The disc runs hot and the lensed arcs run cold, and that split is doing
	## the work: warm is the light source, the tint is the matter it is falling
	## through, and the arc under the hole is drawn a stop darker than the arc
	## over it. Flat, the whole thing was one red ring.
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

	## An open ring with a beam tick either side.
	##
	## The middle is deliberately EMPTY. The live layer flashes the actual
	## neutron star at this exact point, and the first version of this glyph was
	## a solid cross that sat on top of it — so the one node type with its own
	## animation was the one node type whose animation you could not see. The
	## ring says "something is here" and then gets out of the way.
	##
	## The ring is lit from the top and falls to a recess at the bottom, so it
	## reads as a shell of ejecta seen at an angle. The beam ticks are the only
	## COLD light in the set — a neutron star is not a furnace, and drawing its
	## beam in the same warm ink as a station window said the wrong thing.
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

	## Where the run began: your own hull, nosing right.
	##
	## It was drawn as the FIGHT dart mirrored, "because it is the same
	## shipyard", and read as one more contact among a hundred. The dart is not
	## drawn any more, so this is the only ship-shaped mark on the chart and is
	## unique by subtraction rather than by redesign.
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

	static func art_for(t: MapGen.NodeType) -> Array:
		match t:
			MapGen.NodeType.STATION: return _STATION
			MapGen.NodeType.CORE: return _GOAL
			MapGen.NodeType.PULSAR: return _PULSAR
			MapGen.NodeType.START: return _START
			# EVERY SYSTEM WEARS THE SAME MARK. It used to be three -- a dart, a
			# hulk, a beacon -- which told you what was waiting before you flew
			# there. What is at a system is `options` now and the chart does not
			# say what they are, so the star is what every one of them gets.
			_: return _EVENT

	static func draw_glyph(ci: CanvasItem, o: Vector2, t: MapGen.NodeType,
			tint_in: Color, here: bool, selected: bool) -> void:
		# Region colours sit quietly behind sprites; as a glyph on a dark chart
		# they need lifting or the icon reads as a smudge. The ramp is built
		# from the tint every call rather than stored, because the tint is the
		# argument — a cleared system is drawn in dead grey and a Core system in
		# red from the same seven pixel maps.
		#
		# Spacing is the point. lightened(0.62) against darkened(0.52) is a big
		# enough value break to survive being 13 pixels wide on a starfield;
		# closer stops than that and the shading turns back into one flat mass,
		# which is what the four-colour version was.
		var ramp := {
			"o": Color("#070b11"),
			"%": tint_in.lightened(0.62),
			"#": tint_in.lightened(0.34),
			"+": tint_in.darkened(0.22),
			"-": tint_in.darkened(0.52),
			"*": UITheme.HOT,
			"@": Color("#fff6e2"),
			":": UITheme.EMBER,
			"=": Color("#8ec8e6"),
			"~": Color("#3a6b8c"),
			"!": Color("#dff6ff"),
		}
		var art := art_for(t)
		for y in art.size():
			var row: String = art[y]
			for x in row.length():
				var ch := row[x]
				if ch == ".":
					continue
				ci.draw_rect(Rect2(o + Vector2(x, y), Vector2.ONE),
					ramp.get(ch, ramp["#"]) as Color, true)

		# Corner brackets, not a box. A box is a tile by another name, and the
		# tile is what we just removed.
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


## The moving parts, on a canvas of their own.
##
## The backdrop is cached precisely because it is expensive, so animating it
## would undo the optimisation that made the chart usable — forty thousand stars
## cannot be redrawn sixty times a second. This layer redraws every frame and
## costs about seven hundred pixels: the handful of stars currently twinkling,
## some gas drifting along the arms, and the churn around the black hole.
## Everything static stays static and cached underneath.
class SkyAnim extends Control:
	var chart: MapChart

	## Seconds between redraws; zero is every frame.
	##
	## Zero is right for the CHART. It was capped to thirty while the backdrop
	## moved at sixty, which is invisible when the view is still and obvious the
	## moment you drag — the core stepped along half a beat behind the galaxy
	## around it. Costing four milliseconds instead of fifty, it can simply keep
	## up.
	##
	## The launcher sets it, because none of that applies there: nothing drags,
	## and the galaxy turns at two thousandths of a radian a second. What the
	## launcher has instead is a fixed budget it keeps overrunning, and this is
	## twelve thousand particles a frame it does not need to spend.
	var interval: float = 0.0
	var _t: float = 0.0

	func _process(delta: float) -> void:
		if interval <= 0.0:
			queue_redraw()
			return
		_t += delta
		if _t < interval:
			return
		_t = 0.0
		queue_redraw()

	## Guarded on the chart alone. draw_anim() reads nothing but the precomputed
	## arrays, and those are built from the GALAXY — which exists before any run
	## does. The map guard that used to be here was borrowed from the layers that
	## draw systems, and it kept the sky blank on the one screen that wants the
	## sky and nothing else: the launcher.
	func _draw() -> void:
		if chart != null:
			chart.draw_anim(self)


## The galaxy, on a canvas of its own so that highlighting a system does not
## repaint forty-eight thousand stars.
## A Node2D RATHER THAN A CONTROL, because this layer is MOVED every frame of
## a drag instead of being repainted, and moving a Control repaints it: its
## rect changed, so Godot invalidates the draw list. Measured -- the slide was
## in place and the backdrop still drew 1.08 times a frame.
##
## Nothing here wanted Control anyway. `draw_backdrop` is a method on MapChart
## and reads MAPCHART's `size`, never this node's, so the layer has no use for
## anchors, and mouse_filter is moot on something that ignores the mouse.
class Backdrop extends Node2D:
	var chart: MapChart

	## See SkyAnim above: the galaxy is not the map, and this layer needs only
	## the galaxy.
	func _draw() -> void:
		if chart != null:
			chart.draw_backdrop(self)


## Everything behind our galaxy: the flat black, and the distant galaxies.
##
## Split onto its own canvas so it can be held STILL while the galaxy turns.
## Those are other galaxies, millions of light years past this one — they have
## no reason to share its rotation, and a title screen that swings them around
## with the arms reads as a picture being spun rather than a galaxy turning.
class DeepField extends Control:
	var chart: MapChart

	func _draw() -> void:
		if chart != null:
			chart.draw_deep(self)


## The parallax star layers, over the galaxy and also fixed.
##
## Twenty-two depths of foreground stars: the sky our galaxy is being seen
## THROUGH, not part of its disc. Same argument as DeepField — they stay put.
class Halo extends Control:
	var chart: MapChart

	func _draw() -> void:
		if chart != null:
			chart.draw_halo_layer(self)


class MapChart extends Control:
	## The galaxy from above. Layers are rings: you start on the rim and work in,
	## and the core burns at the centre. Presentation only — MapGen still
	## lays the run out in layers, so the simulator sees no difference.

	signal node_picked(index: int)

	## The view was moved by hand, so whatever was holding it no longer is.
	## Emitted on a DRAG, never on a glide: a toggle that switched itself off
	## while carrying out its own animation would fight the thing that pressed
	## it.
	signal view_dragged
	## A click on empty space — not the end of a drag. Puts the chart back to
	## just the galaxy.
	signal cleared()

	## WASD, held. The same move a drag makes, so it goes through the same three
	## lines: the sky follows what the galaxy ACTUALLY did after the clamp, not
	## what the key asked for, or the background slides under a stationary
	## galaxy at the edge of the chart.
	##
	## It counts as moving it by hand, so a held view lets go -- pressing a
	## direction is exactly as much "I am looking somewhere else" as dragging is.
	## A KEY-UP THAT NEVER ARRIVED CANNOT LEAVE THE CHART DRIVING.
	##
	## `_walk` accumulates on key-down and subtracts on key-up, so it depends on
	## seeing both halves of every press -- and WIN+SHIFT+S is a press of S
	## followed by the operating system taking focus for the snip overlay. The
	## release goes to Windows, `_walk` keeps its DOWN, and the chart pans on
	## its own until you press and release S again to balance the books.
	##
	## Checked here rather than only on focus loss because this covers every way
	## a release can go missing -- alt-tab, a shortcut, a lost window -- and it
	## can only ever CANCEL movement. That is what makes it safe next to
	## `_unhandled_key_input`: polling `Input` directly to START a pan would let
	## a keystroke meant for a focused field drive the chart, which is the exact
	## thing routing this through `_unhandled_key_input` was for.
	func _settle_walk() -> void:
		if _walk == Vector2.ZERO:
			return
		if _walk.y < 0.0 and not Input.is_key_pressed(KEY_W):
			_walk.y = 0.0
		if _walk.y > 0.0 and not Input.is_key_pressed(KEY_S):
			_walk.y = 0.0
		if _walk.x < 0.0 and not Input.is_key_pressed(KEY_A):
			_walk.x = 0.0
		if _walk.x > 0.0 and not Input.is_key_pressed(KEY_D):
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

	## How far across the galaxy is, so a bar can say a NUMBER.
	##
	## `MapNode.gal` is normalised — a fraction of the disc radius — which is
	## the right thing for a map that only has to be self-consistent, and no
	## use at all to a reader asking how far a jump is. One constant turns the
	## whole chart into real units.
	##
	## 50,000 is chosen rather than measured: it is roughly the Milky Way's
	## radius, so the bar reads as a galaxy instead of a solar system. Nothing
	## in the sim depends on it — MapGen prices jumps off `gal` directly — so
	## this is a label, and changing it relabels without rebalancing.
	const RADIUS_LY := 50000.0

	## Bar lengths worth printing. The bar picks the largest that still fits
	## in its allowance, so it steps 1-2-5 the way a map scale should rather
	## than showing whatever 120px happens to be.
	const BAR_STEPS := [10.0, 20.0, 50.0, 100.0, 200.0, 500.0, 1000.0,
		2000.0, 5000.0, 10000.0, 20000.0, 50000.0]
	const BAR_MAX_PX := 140.0
	const BAR_PAD := 12.0
	## How far the scale's label reaches above the rule: the 7px baseline
	## offset draw_string is given, plus the 8px face it is drawn at.
	const BAR_LABEL_H := 15.0

	## How hard the fixed sky slides against the galaxy when you drag.
	##
	## Halved. Both fields keep their own SPREAD of rates — seven shells of
	## distant galaxies, twenty-two of halo stars — and that spread is what
	## actually carries depth, since layers disagreeing about how fast they move
	## is the whole effect. Amplitude only sets how far they travel, and at full
	## strength the background covered enough ground to read as the sky being
	## dragged past rather than as distance behind the galaxy.
	##
	## One constant on purpose: the two fields have to move as one sky, so their
	## rates are not independently tunable numbers.
	const PARALLAX := 0.5

	## And HALF of it again for the distant galaxies.
	##
	## This is a deliberate exception to the sentence above, so it is written
	## down rather than folded into PARALLAX. The two fields still move as one
	## sky — one rate, one control — but they are not at one distance: the star
	## shells are foreground haze and the galaxies are supposed to be millions
	## of light years past everything, and at a shared rate they read as being
	## just behind the stars. Halving the far field is what puts them behind
	## it, and it costs nothing else, because nothing is measured against it.
	const FAR_PARALLAX := PARALLAX * 0.5

	## Every shape parameter comes from GalaxyGen, so a new galaxy type is a
	## dictionary entry rather than another branch in here.
	func _g() -> Dictionary:
		return Run.galaxy

	func _squash() -> float:
		return _g().squash

	func _arms() -> int:
		return maxi(1, int(_g().arms))

	## The spiral has one definition, in MapGen, because system placement is
	## derived from it too and the two must not drift.
	func _shape_angle(r_norm: float, arm: int, along: float) -> float:
		return MapGen.shape_angle(r_norm, arm, along)

	## When false the chart draws the galaxy and nothing else — no systems, no
	## routes, no trail, no tooltip.
	var show_icons: bool = true
	## Debug: ignore the visited/reachable filter and draw every system.
	##
	## RESTORED, dev-only, and the reason it came out is worth keeping: it
	## defeats the one thing the chart is for, which is the map you have EARNED.
	## That argument is about the PLAYER, and it still stands — this is behind
	## DevMode, like the card gallery and the manufacturer list, and for the same
	## reason. The three dev toggles exist to look at GENERATION: whether the
	## shells are spaced sensibly, how the lattice is wired, whether a galaxy
	## rolled something odd. None of that can be seen through a filter that hides
	## most of the galaxy.
	##
	## Its absence read as a bug rather than as a decision, which is the other
	## half of why it is back: the link overlay -- SHOW REACH now, and it drew
	## the whole `links` lattice then -- painted edges over a chart that was
	## still hiding the systems those edges ran to, so the diagnostic showed
	## lines going nowhere and stations floating in the dark, stations being the
	## one type the filter always let through.
	##
	## Nothing is reachable through it. Jumping has always been gated on
	## Run.can_jump_to(), so this reveals and never travels.
	var show_all: bool = false
	## Debug: draw every link in the map, not only the ones you could take.
	## Off by default — it is a diagnostic, not a view.
	var show_links: bool = false
	var selected: int = -1
	var hovered: int = -1
	var zoom: float = ZOOM_MIN
	var pan: Vector2 = Vector2.ZERO

	## HOW FAST WASD WALKS THE CHART, in screen pixels a second.
	##
	## 320 crosses a 960-wide view in three seconds at the reading zoom, which is
	## the pace of somebody looking rather than somebody travelling. A drag is
	## for going somewhere; this is for reading along a route, and it should feel
	## closer to leaning than to flying.
	##
	## Divided by the zoom, so it moves the same distance across the GALAXY at
	## every magnification -- otherwise zoomed in it crawls and zoomed out it
	## throws you across the disc, and the key stops meaning one thing.
	const WALK_PX_PER_SEC := 320.0
	## Which of WASD are down. Read every frame rather than on the event, so
	## holding two moves diagonally and releasing one keeps the other going.
	var _walk: Vector2 = Vector2.ZERO
	## The offset the parallax layers use. It follows dragging and ONLY
	## dragging. Zooming has to move `pan` to keep the point under the cursor
	## anchored, and feeding that to the deep field made the sky slide sideways
	## every time you touched the wheel — parallax on a translation reads as
	## depth, parallax on a zoom reads as the room tilting.
	var sky_pan: Vector2 = Vector2.ZERO

	var _dragging: bool = false
	var _drag_from: Vector2 = Vector2.ZERO
	var _press_at: Vector2 = Vector2.ZERO
	var _drag_moved: bool = false
	## Eases 0 to 1 while the cursor rests on a system. At overview zoom the
	## chart is a field of near-identical points, and a tooltip that snaps
	## between them reads as flicker.
	var _hover_t: float = 0.0

	## The galaxy lives on its own canvas. Godot keeps each CanvasItem draw list
	## until that item asks to redraw, so putting the star field on a separate
	## layer means hovering a system repaints two hundred glyphs rather than the
	## whole galaxy.
	var _backdrop: Node2D
	var _anim: Control
	## Static sky, either side of the galaxy: distant galaxies underneath,
	## parallax star layers on top. Neither turns. See set_sky_rotation.
	var _deep: Control
	var _halo: Control
	## Screen positions are pure functions of the node and the transform, and
	## they are wanted for every system on every redraw AND on every mouse
	## motion, so they are worth remembering.
	var _polar_cache: Dictionary = {}
	## Scratch for _lens, so a per-pixel call does not allocate.
	var _lens_out: Array = [Vector2.ZERO]
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
	## The faintest tier of the field, flagged once at build time. While a drag
	## is actually in flight these are skipped: they are the dim wash between
	## the bright structure, they carry no shape on their own, and dropping them
	## costs well over half the pixels in a repaint. Halving the field wholesale
	## was the earlier attempt and it visibly dimmed the galaxy — this leaves
	## every bright star, the arms, the core and the lanes exactly as they are.
	var _star_dim: PackedByteArray = PackedByteArray()
	## How many static stars the cleared core swallowed. The live layer draws
	## exactly this many back, which is the only way to guarantee the orbiting
	## stars match the density of the field they sit inside — guessing a count
	## meant the core was visibly thinner or denser than its surroundings, and
	## the gap moved every time a galaxy rolled a different concentration.
	var _core_skipped: int = 0
	## The stars the cleared core swallowed: their radius and their colour, kept
	## so the live layer can put THOSE STARS back in orbit rather than a separate
	## population standing in for them.
	##
	## A stand-in can match a count and still be obviously wrong. On an edge-on
	## galaxy the disc is a bright blue-white lane straight through the middle,
	## and replacing its stars with a warm gold field left the lane running up to
	## the core, stopping, and a different-coloured thing turning where it should
	## have continued. Inheriting radius and colour makes the core the same
	## galaxy as the rest of it — just the part that is moving.
	var _core_rad: PackedFloat32Array = PackedFloat32Array()
	var _core_col: PackedColorArray = PackedColorArray()
	## Size class travels with them, so a swallowed gas block comes back as a
	## gas block rather than as a one-pixel star.
	var _core_size: PackedByteArray = PackedByteArray()
	## The angle each one was already at. Orbits used to take a hashed angle,
	## which threw away where the star actually WAS — so the arms stopped dead at
	## the core and a scrambled cloud turned inside it. Worse, the hash was fed a
	## strided index once the core overflowed, and a multiplicative hash on an
	## arithmetic progression lands on a lattice: the whole cluster bunched into
	## one arc. Keeping the angle fixes both. The arms now run continuously into
	## the core and wind as it turns, which is what a galaxy does.
	var _core_ang: PackedFloat32Array = PackedFloat32Array()
	## The orbiting core, precomputed. Radius, starting angle, angular speed and
	## colour are all fixed for the life of a galaxy — only the angle advances —
	## so deriving them per particle per frame was paying for the same three
	## hashes, a square root and a colour decision seven thousand times, sixty
	## times a second. All that is left in the frame is an add, a sin, a cos and
	## a rect.
	var _orb_r: PackedFloat32Array = PackedFloat32Array()
	var _orb_a: PackedFloat32Array = PackedFloat32Array()
	var _orb_w: PackedFloat32Array = PackedFloat32Array()
	var _orb_col: PackedColorArray = PackedColorArray()
	var _orb_size: PackedByteArray = PackedByteArray()
	## Whether this particle's orbit can ever cross a dark lobe. Decided once
	## from its radius, because its radius never changes. See the orbit draw.
	var _orb_dark: PackedByteArray = PackedByteArray()
	var _star_key: String = ""

	## Everything above that _build_stars derives, by name.
	##
	## Kept as a list rather than as thirty-four static vars because the cache
	## has to be saved and restored as a SET — one field left out is a chart
	## that draws with last galaxy's dust lanes over this galaxy's stars, and a
	## list you can read against the declarations above catches that by eye.
	##
	## Everything in it is a Packed*Array or an int. Those are copy-on-write
	## value types, so storing one is a snapshot rather than an alias; a plain
	## Array or Dictionary in here would be shared by reference and the cache
	## would mutate under itself.
	const SKY_FIELDS: Array[String] = [
		"_star_pos", "_star_col", "_star_big", "_star_dim",
		"_core_skipped", "_core_rad", "_core_col", "_core_size", "_core_ang",
		"_orb_r", "_orb_a", "_orb_w", "_orb_col", "_orb_size", "_orb_dark",
		"_dark_c", "_dark_r", "_dark_orb_c", "_dark_orb_r",
		"_neb_pos", "_neb_top", "_neb_name", "_pulsar",
		"_disc_r", "_disc_a", "_disc_om", "_disc_rad", "_disc_b", "_disc_bp",
		"_disc_c1", "_disc_c2",
		"_wv_pos", "_wv_ph", "_wv_col",
	]

	## The built sky, shared by every MapChart this process makes.
	##
	## Router builds a NEW StarchartScreen on every visit, so an instance-level
	## cache was thrown away every time the player looked at the chart and
	## rebuilt from scratch on the next look — a quarter of a second of galaxy
	## maths to redraw a sky that had not changed. It is keyed by panel width as
	## well as by galaxy, so a resize still rebuilds; what it stops is paying for
	## the same sky twice.
	static var _sky_cache: Dictionary = {}
	## Which galaxy the entries belong to. A run is one galaxy for its whole
	## life, so anything cached for a different one is dead weight and is
	## dropped wholesale rather than accumulating a sky per run for the session.
	static var _sky_galaxy: String = ""
	## Dark clouds in drawn galaxy space, as flat lobes. See _extinct.
	var _dark_c: PackedVector2Array = PackedVector2Array()
	var _dark_r: PackedFloat32Array = PackedFloat32Array()
	## Just the lobes that reach into the region the live layer orbits material
	## through. Almost always empty, and when it is, the per-frame test in the
	## orbit loop costs one is_empty() for the whole galaxy. See _extinct_orbit.
	var _dark_orb_c: PackedVector2Array = PackedVector2Array()
	var _dark_orb_r: PackedFloat32Array = PackedFloat32Array()

	## Nebulae, clusters and remnants live in the same packed arrays as the
	## stars: built once per galaxy, a rect apiece at repaint, exactly like
	## everything else out there. Only two things about them have to survive as
	## objects rather than as pixels — where to write a name, and where a
	## supernova left a pulsar turning.
	var _neb_pos: PackedVector2Array = PackedVector2Array()
	## How far above its centre each cloud actually reached, MEASURED off the
	## pixels that survived the dither rather than taken from the radius it was
	## nominally built to. The two are nowhere near each other — lobes sit at
	## half to nine tenths of the nominal radius and the falloff then kills
	## everything past about six tenths of each lobe — so spacing the label off
	## the nominal figure hung it a couple of hundred pixels above the cloud
	## with clear sky in between, plainly labelling nothing.
	var _neb_top: PackedFloat32Array = PackedFloat32Array()
	var _neb_name: PackedStringArray = PackedStringArray()
	var _pulsar: PackedVector2Array = PackedVector2Array()

	## The same linear congruential generator the star field is built from,
	## behind two methods instead of three lines repeated at every random number.
	## The original field passes predate this and keep their own copy; everything
	## added since uses it.
	var _rng: int = 0

	## Four canvases, in paint order: the deep field, the galaxy, the live core,
	## the halo. All four sit behind the parent's own _draw, which is where the
	## systems go.
	##
	## The split is partly the old performance argument — Godot keeps a
	## CanvasItem's draw list until that item asks to redraw, so highlighting a
	## system repaints two hundred glyphs rather than forty-eight thousand stars
	## — and partly a rotation argument. Only the middle two are OUR galaxy. The
	## launcher turns those and leaves the other two alone, which it can only do
	## if they are separate canvases.
	func _make_backdrop() -> void:
		_deep = DeepField.new()
		(_deep as DeepField).chart = self
		_deep.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_deep.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# A Control draws itself BEFORE its children, so without this the sky is
		# painted over the systems it is supposed to sit behind.
		_deep.show_behind_parent = true
		add_child(_deep)

		_backdrop = Backdrop.new()
		(_backdrop as Backdrop).chart = self
		_backdrop.show_behind_parent = true
		add_child(_backdrop)

		# Added after the backdrop and also behind the parent, so it layers over
		# the static sky but under the systems — a twinkle must never sit on top
		# of a station you are trying to read.
		_anim = SkyAnim.new()
		(_anim as SkyAnim).chart = self
		_anim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_anim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_anim.show_behind_parent = true
		add_child(_anim)

		_halo = Halo.new()
		(_halo as Halo).chart = self
		_halo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_halo.show_behind_parent = true
		add_child(_halo)

	## Build the star field NOW, rather than on demand inside the first draw.
	##
	## _build_stars() is the expensive half of this class — 350 to 420ms for a
	## galaxy it has not seen — and draw_backdrop() calls it lazily, so the cost
	## lands on whichever frame first paints the sky. That frame is then a
	## quarter-second long, and a quarter-second frame is one the display gets to
	## show partway through.
	##
	## Calling it here moves the work to a frame of the caller's choosing, before
	## anything is visible or moving. The draw that follows finds the key
	## unchanged and returns immediately.
	func warm_sky() -> void:
		_build_stars()

	## How often the live core repaints. See SkyAnim.interval.
	func set_anim_interval(seconds: float) -> void:
		if _anim != null:
			(_anim as SkyAnim).interval = seconds

	## Turn OUR galaxy, and nothing else. The deep field and the halo keep still.
	##
	## The pivot comes from THIS control's size, not from each layer's. The
	## layers are anchored full-rect, so their size is resolved by the layout
	## pass — which means that in the frame after someone assigns a new size
	## here, `layer.size` is still the old one. Pivoting on a stale size turns
	## the galaxy about a point that is not its centre, which walks its edges
	## across the view instead of spinning it in place.
	## THE STAR FIELD TURNS IN DATA, NOT BY TRANSFORM.
	##
	## This is the whole reason the launcher looked like it was tearing. Rotating
	## a CanvasItem full of 1x1 rects makes the rasteriser resample them onto the
	## pixel grid — and draw_backdrop rounds each star to an integer pixel BEFORE
	## the transform, so what gets rotated is a grid. A grid resampled onto a
	## grid at a shallow angle is moiré: long strips of vertical and horizontal
	## lines that crawl as the angle changes.
	##
	## Rotating the positions first and rounding afterwards inverts that. The
	## source positions are scattered floats, so where each star lands is
	## decorrelated from its neighbours, and every star still ends up on an exact
	## pixel — crisp, which the transform could never be.
	##
	## The animated layer keeps the transform. It is a few hundred sparse points
	## and the core, far too thin to form a pattern, and it repaints every frame
	## anyway — so it gets the free version and lands on the same angle.
	func set_sky_rotation(r: float) -> void:
		sky_angle = r
		if _anim != null:
			_anim.pivot_offset = size * 0.5
			_anim.rotation = r
		if _backdrop == null:
			return
		_backdrop.rotation = 0.0
		# EVERY frame the angle moves, and batching this is a trap I already fell
		# into. Waiting for half a pixel of rim movement repainted about once a
		# second — and because a repaint moves every star that crossed a boundary
		# SINCE THE LAST ONE, they all stepped together. One synchronised jump a
		# second is chop; the same total movement spread over sixty frames is a
		# few hundred stars shifting a pixel each, which reads as drift.
		#
		# A star cannot move less than a pixel, so this is as smooth as pixel art
		# gets. What it buys is that the steps are UNCORRELATED in time as well
		# as in space.
		# Exact, not is_equal_approx. Its tolerance scales with magnitude — near a
		# full turn it is about 6e-5 — while one frame of this rotation is 3.5e-5,
		# so an approximate test would silently drop frames and reintroduce the
		# stepping in a form much harder to see in the code.
		if sky_angle == _drawn_angle:
			return
		_drawn_angle = sky_angle
		_backdrop.queue_redraw()

	## How far the backdrop may slide before it has to be repainted.
	##
	## The layer is grown by this much on every side, so stars within this
	## distance of the screen edge are already drawn and slide INTO view rather
	## than popping in. MapChart sets `clip_contents`, so the overdraw never
	## escapes the chart's own rect.
	##
	## Bigger means fewer repaints and more stars per repaint.
	## Over what fraction of the disc radius the foreground field thins out.
	##
	## The galaxy is meant to be seen through a sky that gets out of its way --
	## dim foreground stars scattered over the arms compete with the arms. Doing
	## that with a radius test draws a circle instead, so the transition is spread
	## over the outer third of it.
	##
	## Small enough and it is a rim again; large enough and the foreground thins
	## so far out that the galaxy sits in a permanent clearing.
	## How far past "the rim is in the middle of the view" a drag may go, as a
	## fraction of the view.
	##
	## 0.5 is the ordinary convention -- the rim reaches the near EDGE, so the
	## galaxy may be pushed exactly out of frame and no further. Worth knowing
	## before trusting that: `ex` is the disc's NOMINAL radius, and the stars fade
	## out well inside it, so at full pan the screen really is empty rather than
	## showing a sliver. Lower this if drifting into the void feels like being
	## lost rather than like looking away.
	const PAN_SLACK := 0.5

	const DISC_FEATHER := 0.34

	const SKY_MARGIN := 224.0

	## The view the backdrop was last actually PAINTED at.
	##
	## `pan` enters `draw_backdrop` exactly once, as `size * 0.5 + pan` -- so a
	## pan is a rigid translation of that layer and nothing else, and every star
	## is `.round()`-snapped on the way out. Moving the canvas by a whole number
	## of pixels is therefore not an approximation of the repaint, it IS the same
	## image. Zoom is not like this: it scales the field and grows the brush, so
	## a zoom always repaints.
	##
	## Measured with `-- chartbench`: the repaint was 16.6ms of a 38ms dragged
	## frame, for a result identical to sliding it.
	## Whether each ring is drawn. Owned by the screen's corner toggles.
	var show_sight := true
	var show_reach := true

	var _sky_pan := Vector2.ZERO
	var _sky_zoom := -1.0

	## The view the two STATIC sky layers were last drawn at.
	##
	## Separate from `_sky_pan` above, which is the backdrop's slide basis: this
	## pair is a staleness check, that one is an offset. INF so the first repaint
	## always happens.
	var _view_pan := Vector2(INF, INF)
	var _view_sky := Vector2(INF, INF)
	var _view_zoom := -1.0

	## The galaxy's rotation, in radians, applied to star positions at draw time.
	var sky_angle: float = 0.0
	var _drawn_angle: float = 0.0

	## Anything that moves the galaxy on screen, as opposed to merely changing
	## what is highlighted.
	## All four sky canvases, not just the galaxy: the deep field and the halo are
	## both derived from `size` and `sky_pan`, so a resize or a drag makes them
	## as stale as the arms. Leaving either out means dragging the chart slides
	## the galaxy across a deep field that stayed where it was.
	func _repaint_galaxy() -> void:
		_polar_cache.clear()
		# _anim IS IN THIS LIST, and leaving it out is what made the core lag.
		#
		# It queues its own redraw from _process, which is enough while the
		# view is still and wrong the moment the view MOVES: that redraw is
		# asked for before the thing that moves the view has moved it, so the
		# core draws with the pan from the frame before. Measured, not
		# guessed -- `ANIM f=N` printed exactly what `BACK f=N-1` had.
		#
		# One frame is enough to see because the backdrop carries a HOLE where
		# the core goes: the hole arrives on time and the core does not, so
		# what you see is an empty socket travelling ahead of its contents,
		# closing the instant the motion stops.
		# _deep IS IN THIS LIST, and taking it out was a REGRESSION I shipped.
		# `draw_deep` looks view-independent and `_draw_far_galaxies` looks it
		# too, but `_far_layer` two levels down positions every distant galaxy at
		# `size * 0.5 + sky_pan * parallax`, and reads `pan` and `zoom` besides.
		# Frozen, the depth layers stop separating as the view moves and the
		# whole field collapses into one flat furthest layer -- which is exactly
		# what it looked like.
		#
		# I MISSED IT WITH A REGEX: `pan` cannot match `sky_pan`, because an
		# underscore is a word character. Grep for the substring here, or read
		# the call tree to the bottom. Two levels of delegation is enough to hide
		# a dependency from a one-level check.
		#
		# _halo is here for the same reason, despite its class comment saying it
		# "stays put". That comment
		# is about ROTATION -- the halo does not turn with the arms -- and it is
		# not about the pan: `_star_layer` reads both `pan` and `zoom`, and the
		# whole point of the parallax is that those layers slide against the
		# galaxy as the view moves. Dropping it from here froze the foreground
		# sky mid-drag. It is only 2.4ms that is free here, not 7.5ms.
		#
		# _deep DOES restage when the window resizes, since it is drawn to
		# `size` -- that is what `_repaint_sky` below is for, and why the resize
		# notification calls that instead of this.
		# THE BACKDROP SLIDES WHEN IT CAN. It is 48,000 stars and the most
		# expensive layer on the screen, and a pan does nothing to it but move
		# it -- see `_sky_pan`. Repainting is kept for what a slide cannot
		# express: a change of zoom, or drifting past the margin.
		if _backdrop != null:
			var slide := (pan - _sky_pan).round()
			# Exact, not is_equal_approx: its tolerance scales with magnitude,
			# and at high zoom that is wide enough to swallow a real step. Same
			# argument as set_sky_rotation's.
			var far := absf(slide.x) > SKY_MARGIN or absf(slide.y) > SKY_MARGIN
			if _sky_zoom == zoom and not far:
				_slide_backdrop(slide)
			else:
				_sky_pan = pan
				_sky_zoom = zoom
				_slide_backdrop(Vector2.ZERO)
				_backdrop.queue_redraw()
		# _halo AND _deep ONLY WHEN THE VIEW MOVED. Both read `pan`, `zoom` and
		# `sky_pan` and nothing else -- no clock, no hover, no selection -- while
		# `_repaint_galaxy` is called for all of those other reasons as well.
		# Redrawing them on a frame where the view stood still costs about 8ms to
		# produce a pixel-identical result.
		#
		# That is nearly the whole title screen. The launcher turns the galaxy,
		# which repaints the backdrop through `set_sky_rotation`, and the view
		# itself never moves at all -- so before this, the deep field and the
		# halo were being rebuilt sixty times a second for a picture that could
		# not change. Measured with `-- chartbench`: 44ms a frame, which is the
		# 22fps the title screen was reported at.
		if pan != _view_pan or zoom != _view_zoom or sky_pan != _view_sky:
			_view_pan = pan
			_view_zoom = zoom
			_view_sky = sky_pan
			for layer in [_halo, _deep]:
				if layer != null:
					layer.queue_redraw()
		if _anim != null:
			_anim.queue_redraw()
		queue_redraw()

	## Move the backdrop canvas rather than repainting it.
	func _slide_backdrop(by: Vector2) -> void:
		if _backdrop != null:
			_backdrop.position = by

	## Everything, plus the backdrop's slide basis.
	##
	## For when the SCREEN changes rather than the view: the backdrop's offset is
	## measured from `size * 0.5`, which a resize moves, so no slide is valid any
	## more and the layer has to be repainted outright.
	func _repaint_sky() -> void:
		# -1.0 is a zoom nothing matches, which forces the repaint branch. The
		# static layers are sized to `size` too, so they are stale as well.
		_sky_zoom = -1.0
		_view_zoom = -1.0
		_repaint_galaxy()

	func _process(delta: float) -> void:
		_walk_view(delta)
		# RECORDED HERE RATHER THAN AT EVERY MUTATION. Zoom and pan are moved by
		# the wheel, by a drag, by `glide_to`'s animation and by both framing
		# helpers; hooking all of them would leave one out. Reading the result
		# once a frame cannot.
		if remembers_view and size.x > 0.0:
			StarchartScreen._view_zoom = zoom
			StarchartScreen._view_pan = pan
			StarchartScreen._view_map = Run.map.size()
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

	## Zoom so the galaxy's outer edge lands at `fill` times half the short side
	## of `screen`.
	##
	## For anything that draws the sky on a control BIGGER than the view. The
	## launcher does: its sky is a square as wide as the screen's diagonal, so
	## that rotating it can never sweep a corner into frame. _radius() is derived
	## from the control, so on that square it is nearly twice what it would be on
	## the screen, and a zoom picked by eye against the chart put the galaxy at
	## about 1.6 screen-widths across — a title screen showing only the core.
	##
	## Framing is a question about what the player can see, so it takes the view
	## as an argument rather than reading a size that is deliberately too big.
	func frame_to(screen: Vector2, fill: float) -> void:
		var r_max := _radius() * DISC
		if r_max <= 0.0 or screen.x <= 0.0:
			return
		zoom = fill * minf(screen.x, screen.y) * 0.5 / r_max
		_repaint_galaxy()

	## Whether this chart is the one the player navigates.
	##
	## `LauncherScreen` builds a MapChart too, as the menu's galaxy backdrop, and
	## the view memory lives on the CLASS -- so a chart panned in a run was
	## recorded by one instance and restored by the other, and quitting to the
	## menu showed a galaxy sitting off centre in exactly the way you had left the
	## starchart. Reported as, correctly, "LOL".
	##
	## Off by default so anything decorative stays where it was put; the screen
	## that owns the real chart opts in.
	var remembers_view := false

	## Whether the saved view has been put back yet. One shot.
	var _restored := false

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED and remembers_view and not _restored \
				and size.x > 0.0:
			# THE FIRST MOMENT `size` IS REAL, which is what the old build-time
			# call was missing. Everything that derives a view from the panel --
			# this, and `frame_region` -- has to wait for layout.
			_restored = true
			_arrive()
		if what == NOTIFICATION_RESIZED:
			# _radius() is derived from size, so every cached position is stale
			# -- including the two fixed layers, which is why this is the one
			# caller that wants `_repaint_sky` rather than `_repaint_galaxy`.
			_repaint_sky()

	## What an arrival does to the view, which is what LOCAL REGION is FOR.
	##
	## ON, the chart follows you: every arrival re-frames on the region you are
	## standing in, so the ship is always in the middle of what you are looking
	## at. OFF, the chart stays exactly where you left it -- same zoom, same pan
	## -- so you can park on a distant approach and keep watching it across
	## several jumps.
	##
	## The toggle used to persist while doing NOTHING on arrival, which read as
	## broken: it stayed lit and the view sat wherever the last jump had left it.
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

	## The event horizon's shadow, and the region around it that the ANIMATED
	## layer owns outright. The backdrop leaves that annulus empty so the stars
	## in it can orbit — a moving star drawn over a static one at the same
	## radius is the contradiction that made drifting gas look wrong.
	func _shadow_r() -> float:
		return _radius() * float(Run.galaxy.get("hole", 0.034))

	## How far the black hole's neighbourhood extends — the region the LIVE
	## layer owns outright, where nothing static is drawn and everything orbits.
	## Sized to hold the accretion disc plus enough room outside it for the
	## speed gradient to be visible before it hands over to the static field.
	## How fast anything at radius `r` goes round, for EVERYTHING in the core:
	## the accretion disc and the orbiting stars both ask this.
	##
	## They used to compute their own, from different bases normalised against
	## different radii, which meant the speed jumped at the boundary between
	## them — matter at the disc's outer edge and stars just beyond it were
	## moving at unrelated rates, and that discontinuity is what reads as things
	## sliding past each other for no reason.
	##
	## Keplerian in the middle, faded smoothly to a genuine standstill by the
	## time it reaches the edge of the core. So the black hole spins fast, the
	## disc churns, the stars beyond it turn slowly, and somewhere out there the
	## motion reaches zero and the live layer becomes the static galaxy without
	## a seam to find.
	## Takes sh and clear rather than fetching them, and that is not tidiness —
	## it is the difference between 19fps and playable. This runs once per
	## particle, ten thousand times a frame, and each fetch was a _radius()
	## computation plus a dictionary lookup into the rolled galaxy. Hoisting two
	## values out of the inner loop cost about 40ms a frame.
	## How much of the local star population is in motion at radius `r`: 1 right
	## against the hole, easing to 0 by the edge of the core.
	##
	## This is the single rule the core now follows. The cached field keeps a
	## star with probability (1 - motion) and the live layer keeps one with
	## probability motion, so the two always sum to the same density AND a star
	## is only ever static where the motion has genuinely stopped. Before this
	## the handover was a fixed band, which left stationary stars sitting behind
	## orbiting ones close in — the thing that gave it away.
	func _motion_at(r: float, clear: float) -> float:
		var fade: float = clampf(1.0 - r / maxf(1.0, clear), 0.0, 1.0)
		return fade * fade * (3.0 - 2.0 * fade)

	## Which layer OWNS the stars at this radius — a different question from how
	## fast they are going, and it needs a different curve.
	##
	## Splitting them by speed alone put half the stars in each layer wherever
	## the speed happened to be halfway, and at those radii the motion is still
	## plainly visible — so you got stationary stars sitting among obviously
	## moving ones. Weighting ownership hard toward the live layer keeps the
	## cached field out until the motion is genuinely almost nothing, which is
	## the only place a static star can hide next to a moving one.
	func _own_at(r: float, clear: float) -> float:
		# Total inside three quarters of the core, then a smooth handover.
		#
		# This was pow(motion, 0.30), which is a curve rather than a rule, and a
		# curve leaves a tail: measured, it left thirteen static stars in the
		# innermost fifth of the core but two hundred in the next and nearly a
		# thousand in the outermost — about twenty-two hundred motionless stars
		# sitting inside a region where everything is supposed to be turning.
		# A few percent of a very dense place is still a crowd.
		#
		# The live layer takes ALL of it out to 0.72 and hands back over the last
		# quarter. A sharp edge is safe here because the two layers share one
		# rule: whatever this gives up, the other picks up, so the total density
		# is flat across the seam however abrupt the split.
		var x: float = clampf(r / maxf(1.0, clear), 0.0, 1.0)
		if x < 0.72:
			return 1.0
		var f: float = (1.0 - x) / 0.28
		return f * f * (3.0 - 2.0 * f)

	func _orbital_omega(r: float, sh: float, clear: float) -> float:
		var q: float = sh / maxf(r, sh * 0.6)
		var kep: float = 0.19 * q * sqrt(q)
		return kep * _motion_at(r, clear)

	func _core_clear() -> float:
		# Never smaller than the disc needs: a galaxy that rolled a large hole
		# would otherwise have its accretion disc pushed through the boundary.
		# Every star in here is redrawn sixty times a second, and the count is
		# derived from the area, so this radius IS the frame budget. At 0.22 it
		# was nine thousand moving particles and 23ms a frame. The speed
		# gradient still reads across a smaller region; nine thousand stars
		# turning did not read any better than three thousand.
		return maxf(_radius() * 0.21, _shadow_r() * 5.0)

	func _radius() -> float:
		# Twice the frame. Twenty-four rings inside one screen puts them about
		# twenty pixels apart — closer than a system glyph is tall — so the chart
		# is drawn large and navigated. Zoom out to ZOOM_MIN to see all of it.
		return minf(size.x * 0.5 / DISC, size.y * 0.5 / (DISC * _squash())) * 1.9

	## Ring by layer, angle by where MapGen put the node. No per-ring rotation:
	## linked nodes stay angularly near, so a jump looks like a hop rather than a
	## line drawn across the whole galaxy.
	## The map owns where a system is, because it prices jumps by that distance.
	## The chart only scales it to the disc it is drawing.
	func _polar(n: MapGen.MapNode) -> Vector2:
		return n.gal * (_radius() * DISC)

	## Everything currently on screen, as a set of indices.
	##
	## Built once per frame and shared with hit-testing, because "what is drawn"
	## and "what can be clicked" answering differently is how you end up with a
	## tooltip hovering over empty space.
	##
	## Pointing at a reachable system adds ITS neighbourhood too — that is the
	## question you are asking by pointing at it. Without that the onward routes
	## were drawn to systems the filter had hidden, so hovering a candidate gave
	## you dotted lines running off to nothing.
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
		# ENGINE RANGE IS NOT SIGHT. This used to add everything `in_range()`
		# returns, which is pure geometry and knows nothing about the dish -- so a
		# ship with a big thruster and no sensors was shown systems it had never
		# resolved, could select them, and got a fuel quote for them.
		#
		# Ruled 2026-08-28: "you still shouldn't be able to SEE those sectors
		# unless you have the sensor range to see them." Reach beyond sight is
		# real and allowed -- it is simply range you cannot spend until you fit a
		# dish, and an unspendable range draws nothing.
		#
		# Nothing is lost by dropping the clause: anything reachable AND sensed is
		# already in by `Run.charted`.
		if selected >= 0:
			out[selected] = true
		if hovered >= 0 and hovered < Run.map.size():
			out[hovered] = true
		return out

	## Screen point to galaxy space — the coordinates NebulaField and MapGen.gal
	## both speak, where 1.0 is the disc radius.
	func _to_galaxy(p: Vector2) -> Vector2:
		var r := _radius() * DISC
		if r <= 0.0 or zoom <= 0.0:
			return Vector2.ZERO
		return (p - size * 0.5 - pan) / zoom / r

	func _screen_pos(n: MapGen.MapNode) -> Vector2:
		var p: Vector2 = _polar_cache.get(n.index, Vector2.INF)
		if p == Vector2.INF:
			p = _polar(n)
			_polar_cache[n.index] = p
		return size * 0.5 + pan + p * zoom

	## WASD, HELD. Read as a state rather than acted on per press, so two keys
	## move diagonally and letting one go leaves the other running.
	##
	## `_unhandled_key_input`, so anything with focus that wants a letter -- a
	## field, a shortcut on a button -- has already had it.
	func _unhandled_key_input(e: InputEvent) -> void:
		var k := e as InputEventKey
		if k == null or k.echo:
			return
		var dir := Vector2.ZERO
		match k.keycode:
			KEY_W: dir = Vector2.UP
			KEY_S: dir = Vector2.DOWN
			KEY_A: dir = Vector2.LEFT
			KEY_D: dir = Vector2.RIGHT
			_: return
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
						_zoom_at(mb.position, 1.12)
				MOUSE_BUTTON_WHEEL_DOWN:
					if mb.pressed:
						_zoom_at(mb.position, 1.0 / 1.12)
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
						# Only a click clears. Releasing after a pan is how you
						# stop panning, and it must not also throw the selection
						# away.
						if _dragging and not _drag_moved:
							cleared.emit()
						var was := _dragging
						_dragging = false
						if was:
							_repaint_galaxy()
				MOUSE_BUTTON_MIDDLE:
					_dragging = mb.pressed
					_drag_from = mb.position
		elif event is InputEventMouseMotion:
			var mm := event as InputEventMouseMotion
			if _dragging:
				# The sky follows the movement the galaxy ACTUALLY made, not the
				# movement the mouse asked for. Adding the raw delta to both let
				# you drag the sky on after the galaxy had hit its pan limit —
				# so at the edge of the chart the background slid under a
				# stationary galaxy, which is not parallax, it is a bug.
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
				# Hidden means hidden. The rule used to be that pointing at a
				# system brought it back — hiding as a way to look PAST the
				# interface rather than to turn it off — but a toggle that
				# still answers the cursor is not a toggle, and every hover
				# still drew a glyph and a tooltip over the galaxy you had just
				# asked to see on its own. The nebulae still answer, because
				# they are the galaxy.
				var h := _node_at(mm.position) if show_icons else -1
				# A system wins over the gas it is sitting in: you can act on
				# one and only look at the other.
				var cloud: NebulaField.Cloud = null
				if h < 0:
					# The same extent the boundary is drawn at, so pointing
					# inside the ring always answers and pointing outside it
					# never does.
					cloud = NebulaField.at(_to_galaxy(mm.position))
				var cname := "" if cloud == null else cloud.name
				if h != hovered or cname != _neb_hot:
					hovered = h
					_neb_hot = cname
					_neb_hot_emit = cloud != null and cloud.emission
					_neb_hot_kind = "" if cloud == null else cloud.label()
					_neb_hot_at = mm.position
					queue_redraw()

	## Zooming keeps whatever is under the cursor under the cursor, which is the
	## difference between zooming a map and zooming a picture of one.
	## How strongly the sky answers a zoom, as an exponent on the zoom factor.
	## 1.0 would move it exactly with the galaxy; 0.0 pins it to the frame.
	const SKY_ZOOM_POWER := 0.25

	func _zoom_at(at: Vector2, factor: float) -> void:
		var c0 := size * 0.5
		var before := (at - c0 - pan) / zoom
		var was := zoom
		zoom = clampf(zoom * factor, ZOOM_MIN, ZOOM_MAX)
		pan = at - c0 - before * zoom

		# The sky is anchored at the cursor too, and that is the whole point.
		# Zoom pivots the galaxy about the pointer, so the galaxy is perfectly
		# still THERE — and translating the sky by a share of the pan correction
		# moved it uniformly, hardest at the one spot the galaxy was guaranteed
		# not to move. Pivoting both about the same point means they agree under
		# the cursor and diverge with distance from it, which is what parallax
		# actually looks like.
		#
		# Only the offset is pivoted, never the contents: the objects translate
		# as a rigid group, so no pixel is ever rescaled and nothing crawls.
		# It also falls out correctly at the zoom limits — a clamped zoom gives
		# an effective factor of 1, so the sky simply does not move.
		var eff: float = zoom / maxf(0.0001, was)
		var soft: float = pow(eff, SKY_ZOOM_POWER)
		sky_pan = at - c0 - (at - c0 - sky_pan) * soft
		_clamp_pan()
		_repaint_galaxy()

	## How far the galaxy centre may travel from the middle of the frame. Past
	## this you are looking at unpainted space — a hard black rectangle with a
	## visible edge, which reads as the end of a texture rather than the end of
	## anything. The halo is sized (below) to cover exactly this much.
	func _pan_limit() -> Vector2:
		# THE RIM MAY BE PUSHED TO THE EDGE OF THE VIEW, NOT ONLY TO ITS MIDDLE.
		#
		# This was `maxf(half a screen, ex)`, which reads as a sensible floor and
		# is really a REGIME CHANGE. `ex` is the disc's radius in screen pixels,
		# so it overtakes half a screen at about zoom 0.62, and the two sides of
		# that switch behave differently: below it you may shift the galaxy 1.47
		# disc-radii off centre, above it exactly 1.00 and never more, because
		# panning by `ex` is by definition "put the rim in the middle of the
		# view". So the drag room collapsed as you leaned in and then stayed
		# pinned -- which is what "it stops too soon when I zoom in" was.
		#
		# Adding half a view instead of taking the larger of the two makes one
		# rule at every zoom: pan until the rim reaches the NEAR EDGE of the
		# view. That is strictly more room than before at every zoom, it is the
		# ordinary convention for panning something bigger than its window, and
		# it still cannot lose the galaxy -- one more pixel and it would be off
		# screen, so it never is.
		#
		# The `maxf` is gone rather than relaxed: `ex + half` is already at least
		# half a view, so the floor it provided is built in.
		var ex := _radius() * DISC * zoom
		return Vector2(ex + size.x * PAN_SLACK, ex * _squash() + size.y * PAN_SLACK)

	func _clamp_pan() -> void:
		var lim := _pan_limit()
		pan.x = clampf(pan.x, -lim.x, lim.x)
		pan.y = clampf(pan.y, -lim.y, lim.y)
		# sky_pan is deliberately NOT clamped here. It only ever accumulates
		# movement the galaxy really made, so it is bounded by the same limits
		# already — and clamping it separately is what let the two disagree
		# about when the edge had been reached.

	func _node_at(p: Vector2) -> int:
		var visible := _visible_set(Run.node_at(), Run.in_range())
		for n in Run.map:
			# Only what is on screen can be pointed at.
			if not visible.has((n as MapGen.MapNode).index):
				continue
			var node: MapGen.MapNode = n
			if _screen_pos(node).distance_to(p) < maxf(5.0, 12.0 * zoom):
				return node.index
		return -1

	func _draw() -> void:
		if Run.map.is_empty():
			return

		var here: MapGen.MapNode = Run.node_at()
		var hp := _screen_pos(here)
		var reach: Array = []

		# With the systems hidden, the chart is the galaxy alone: no routes, no
		# trail, no glyphs, no tooltip, and nothing that answers the cursor.
		if show_icons:
			# WHAT THE SYSTEM UNDER THE CURSOR CAN REACH.
			#
			# This used to draw every `links` entry from every system at once --
			# both ends, so each line twice -- and at four hundred systems that
			# is a grey fog rather than a diagram. It was also a picture of the
			# WRONG GRAPH: links are what the chart draws, while `can_jump_to` is
			# `sensed` plus `reachable_from` plus fuel and never consults them.
			#
			# Its old comment said it "answers the question no in-game view can:
			# whether MapGen wired the galaxy up sensibly", and that was true
			# while links gated movement. The modern form of the question is
			# whether a system can be flown out of, which is what this shows.
			#
			# ONE SYSTEM AT A TIME, because the reachable graph is DENSER than
			# the link graph, not sparser -- a radius reaches further than the
			# lattice does. Drawing all of it would be worse than what it
			# replaces. Pointing at a system is the question.
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

			# Two kinds of line, and they should not look alike. Where you HAVE
			# been is settled fact: solid, white, unbroken. Where you COULD go is
			# a proposal: dotted, dim, obviously provisional. Drawing both as
			# plain lines in different colours made the chart look like one
			# network when it is really a record and a set of options.
			# ONLY TO SYSTEMS THAT ARE DRAWN. `in_range` is geometry and knows
			# nothing about the dish, so a fast ship with no sensors got dotted
			# lines running out to nothing -- the destination glyph was correctly
			# hidden and the route to it was not. A line to an invisible place is
			# worse than either showing both or hiding both.
			reach = []
			for cand in Run.in_range():
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
					draw_line(a, b, Color(0.86, 0.91, 0.97, 0.85), 1.0)

		# Pointing at a candidate deliberately shows NOTHING beyond it. Its own
		# onward routes are a decision you have not made yet and cannot act on,
		# and drawing them put a second web on the chart that competed with the
		# one set of options that is actually live. Hover gives you the tooltip
		# and the reticle; that is the whole of it.

		var visible := _visible_set(here, reach)
		# Glyphs are a fixed pixel size, so at low zoom 173 of them tile into a
		# wall of identical icons — which is most of why the chart read as
		# regular. Zoomed out, a system is a point of light; the glyph is detail
		# you zoom in for.
		var tiny := zoom < 0.78
		for n in Run.map:
			var node2: MapGen.MapNode = n
			if not show_icons:
				continue
			# The chart is a record and a choice, not an atlas. A system you have
			# never been to and cannot currently reach is not information you can
			# act on — it was 190 icons of noise over the galaxy, and hiding it
			# leaves exactly the two things that matter: where you have been, and
			# where you can go next.
			if not visible.has(node2.index):
				continue
			var p := (_screen_pos(node2) - Vector2(6, 6)).round()
			var tint := MapGen.star_colour(node2)
			if node2.cleared and node2.type != MapGen.NodeType.CORE:
				tint = Color("#37424f")
			# REMEMBERED, NOT SEEN, and both are meant to be on the chart: where
			# you have been is a historical marker and stays, which is a ruling.
			#
			# So the whole job here is telling them apart. Drawn identically, a
			# chart carrying a run's worth of history looked like a dish reaching
			# far past its own ring, and the ring read as a lie. Dimmed, the lit
			# systems are the ones you can see RIGHT NOW and the ring is their
			# boundary; the dim ones are places you have been.
			#
			# Not `cleared`'s dead grey, which says "spent". These keep their
			# region colour because they are still real places you might route
			# back through -- they are simply not on the dish this minute.
			if not node2.sensed and node2.index != here.index:
				tint = tint.darkened(0.45)
			if tiny:
				var lit: bool = node2.index == here.index \
					or node2.index == selected or node2.index == hovered
				# Systems you can actually go to hold their colour; the rest of
				# the galaxy sinks back, so the cluster reads without a label.
				var near: bool = lit or reach.has(node2)
				# A system has to be findable against a field of stars, so even
				# the far ones keep some colour; the reachable ones get a pixel
				# of extra weight instead of the rest being crushed.
				var d: float = 3.0 if (lit or near) else 2.0
				draw_rect(Rect2(p + Vector2(6, 6) - Vector2(d, d) * 0.5,
					Vector2(d, d)), tint if near else tint.darkened(0.35), true)
			else:
				Glyph.draw_glyph(self, p, node2.type, tint,
					node2.index == here.index, node2.index == selected)
			if node2.index == here.index:
				_draw_you(p, tiny)
			elif node2.index == hovered or node2.index == selected:
				draw_string(UITheme.pixel_font(), p + Vector2(-40, 30),
					MapGen.star_name(node2), HORIZONTAL_ALIGNMENT_CENTER, 92, 8,
					UITheme.ICE if node2.index == hovered else UITheme.COLD)


		_draw_party()
		_draw_hellbender()
		_draw_quests()
		_draw_work()
		_draw_neb_edges()

		if hovered >= 0 and hovered < Run.map.size() and _hover_t > 0.01:
			_draw_tip(Run.map[hovered], here)
		elif _neb_hot != "":
			_draw_neb_tip()

		_draw_scale()

	## HOW FAR IS THAT, in light years.
	##
	## A zoomable map without one asks the reader to hold a scale in their
	## head across every zoom step. The bar is the standard answer and it is
	## cheap: pick the longest round number that fits the allowance, draw it,
	## print it.
	##
	## Bottom LEFT. The tooltip follows the cursor and the party markers sit
	## with the ships, and both of those move; this does not, so it goes in
	## the one corner nothing else claims.
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
			# Zoomed so far in that even the shortest step overflows. Show the
		# shortest anyway rather than nothing — a bar running off its
		# allowance still reads as a scale; an empty corner does not.
			ly = float(BAR_STEPS[0])
		var w := minf(ly * per_ly, BAR_MAX_PX)
		var y := size.y - BAR_PAD
		# BOTTOM RIGHT, under the MY REGION button. They answer the same kind
		# of question -- where am I, how big is this -- so they read as one
		# instrument in the corner rather than two ornaments at opposite ends.
		var x := size.x - BAR_PAD - w
		var ink := UITheme.COLD
		# A bar with end ticks, not a bare line: the ticks are what say where
		# it starts and stops on a field of stars.
		draw_line(Vector2(x, y), Vector2(x + w, y), ink, 1.0)
		draw_line(Vector2(x, y - 4.0), Vector2(x, y + 1.0), ink, 1.0)
		draw_line(Vector2(x + w, y - 4.0), Vector2(x + w, y + 1.0), ink, 1.0)
		# Thousands read better than five digits on an 8px face.
		var txt := ("%d ly" % int(ly) if ly < 1000.0
			else "%dk ly" % int(ly / 1000.0))
		# HUNG OFF THE FAR TICK, which is the one edge every part of this
		# instrument can share. The near tick cannot: it moves whenever the
		# step changes, so a label left-aligned on it slides sideways as you
		# zoom while the toggle above it stays put. The right edge is the
		# only one that holds still.
		draw_string(UITheme.pixel_font(),
			Vector2(x + w - BAR_MAX_PX, y - 7.0), txt,
			HORIZONTAL_ALIGNMENT_RIGHT, BAR_MAX_PX, 8, ink)

	## FRAME WHERE YOU ARE, not the ring you are on.
	##
	## The first version framed the whole LAYER, which is right in the abstract
	## and useless in practice: at the rim a layer is most of the galaxy's
	## circumference, so the fit came out at ZOOM_MIN and the button appeared to
	## do nothing on exactly the screen you start the run on.
	##
	## A neighbourhood instead: everything within `span` of you in galaxy
	## coordinates, which is the same measure MapGen prices jumps by. That is
	## the region you can actually reach, and it frames the same way whether you
	## are on the rim or in the core.
	## A view change in flight, so a second press can cancel the first.
	var _glide: Tween = null

	## Move the view to a zoom and a pan over time rather than at once.
	##
	## The sky is settled EVERY STEP, against the values from the step before.
	## `_settle_sky` is written as a delta — pivot by however much the zoom just
	## changed, translate by however far the pan just moved — so feeding it the
	## whole journey at the end would pivot the starfield about the wrong point
	## and slide it past where it belongs.
	func glide_to(z: float, p: Vector2, secs: float = 0.55) -> void:
		if _glide != null and _glide.is_valid():
			_glide.kill()
		var z0 := zoom
		var p0 := pan
		var z1 := clampf(z, ZOOM_MIN, ZOOM_MAX)
		# WORK OUT WHERE THE SKY ENDS UP FIRST, then travel to it.
		#
		# Settling per step against the step before accumulates: each frame
		# pivots by a pow() of a fraction of the zoom change, and a chain of
		# those does not add up to the single pivot the whole move deserves.
		# On screen the galaxy trailed the systems and caught up at the end,
		# which is exactly what an accumulating error looks like.
		#
		# The end state is computable in closed form, so the sky is simply
		# LERPED to it alongside the zoom and the pan. All three then move as
		# one and arrive together.
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
			# SOLVED AT THIS ZOOM, never interpolated towards the end.
			#
			# The sky's offset is a pow() of the zoom RATIO, and the zoom is
			# travelling on a cubic ease. Lerping the sky between its start and
			# end is therefore right at both ends and wrong everywhere between
			# them, which on screen is the galaxy trailing the systems and
			# catching up at the last moment. Evaluating the same closed form
			# against the CURRENT zoom is exact at every step.
			var sf: float = pow(zoom / maxf(0.0001, z0), SKY_ZOOM_POWER)
			sky_pan = (c0 - (c0 - ps) * sf) + (pan - p0)
			_repaint_galaxy(), 0.0, 1.0, secs)

	## THE WHOLE GALAXY, back out. The pair to frame_region: one press in, the
	## same press out, and both take the same route so the second undoes the
	## first rather than snapping to a different overview.
	func frame_galaxy() -> void:
		glide_to(ZOOM_MIN, Vector2.ZERO)

	## `animate` false SNAPS, which is what an ARRIVAL wants.
	##
	## `glide_to` tweens for half a second and repaints the galaxy on every frame
	## of it. That is right for a PRESS -- you asked for the view to move, and
	## watching it travel is how you keep your bearings -- and wrong for a jump,
	## where the screen is rebuilt at ZOOM_MIN and then visibly zooms itself in.
	## Reported as jitter with LOCAL REGION on, and absent with it off for exactly
	## this reason: the off path assigns and repaints once.
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
			var p := _polar(mn)
			lo = lo.min(p)
			hi = hi.max(p)
			n += 1
		if n <= 1:
			# Nothing near you but you. Centre on the ship at a readable zoom
		# rather than dividing by a span of nothing.
			var solo := clampf(2.0, ZOOM_MIN, ZOOM_MAX)
			_go_to(solo, -_polar(here) * solo, animate)
			return
		var box := (hi - lo).max(Vector2.ONE)
		# A margin, or the outermost system sits on the frame edge with its name
		# label hanging off the chart.
		var want := minf(size.x / (box.x + 180.0), size.y / (box.y + 140.0))
		var z := clampf(want, ZOOM_MIN, ZOOM_MAX)
		_go_to(z, -((lo + hi) * 0.5) * z, animate)

	## Travel there, or simply be there.
	##
	## The snap is the same two assignments the remembered-view restore makes,
	## and that path was already smooth -- there is no third way of moving the
	## chart, only the question of whether the move is watched.
	## Frame the ship at a given zoom. The screenshot harnesses both need
	## exactly this and were each poking zoom, pan, `_clamp_pan` and
	## `_repaint_sky` by hand -- and a zoom invalidates the backdrop's slide
	## basis outright, so the sky must be repainted rather than slid, which is
	## the part a caller doing it by hand forgets.
	func center_on_ship(z: float) -> void:
		_go_to(z, -_polar(Run.node_at()) * z, false)

	func _go_to(z: float, p: Vector2, animate: bool) -> void:
		if animate:
			glide_to(z, p)
			return
		zoom = z
		pan = p
		_clamp_pan()
		_repaint_sky()

	## Move the SKY to match a jump the view just made.
	##
	## The starfield is not drawn from `pan`. It has its own offset, and only
	## dragging and `_zoom_at` were maintaining it — so setting `zoom` and
	## `pan` directly moved the systems and left the galaxy where it was. On
	## screen that reads as the local region being pasted onto the middle of
	## an unmoved galaxy, and it corrected itself the moment you dragged,
	## which is what made it look like a repaint bug rather than a missing
	## term.
	##
	## Two motions, in the order the view made them: pivot about the frame
	## centre for the zoom, then translate by however far the pan moved.
	## `_repaint_galaxy` is the other half — the starfield is a cached image,
	## so a queue_redraw alone repaints everything except the thing that
	## moved.
	func _settle_sky(was: float, before: Vector2) -> void:
		var c0 := size * 0.5
		var soft: float = pow(zoom / maxf(0.0001, was), SKY_ZOOM_POWER)
		sky_pan = c0 - (c0 - sky_pan) * soft
		sky_pan += pan - before
		_repaint_galaxy()
		queue_redraw()

	## The boundary of the cloud under the cursor, and only that one.
	##
	## Every cloud outlined at once was a set of rings competing with the systems
	## for attention — and an outline is an answer to "what am I pointing at",
	## which is a question you are only asking about one of them.
	##
	## Drawn as the union boundary of its lobes: every point on a lobe that is
	## not inside another one. That is the actual silhouette, so the line agrees
	## with the gas rather than circling it approximately, and it is exactly the
	## region the tooltip answers for.
	func _draw_neb_edges() -> void:
		if _neb_hot == "":
			return
		var r_max := _radius() * DISC
		var c := size * 0.5 + pan
		for raw in NebulaField.clouds():
			var cl: NebulaField.Cloud = raw
			if cl.name != _neb_hot:
				continue
			# Darker than the gas it encloses. A boundary that is brighter than
			# the thing it is drawn around competes with it; this one should sit
			# under the cloud and only be found when you are looking for it.
			var col := cl.edge_colour()
			col.a = 0.85
			for i in cl.lobes.size():
				var centre: Vector2 = cl.pos + cl.lobes[i]
				var rad: float = cl.lobe_r[i] * NebulaField.EXTENT
				# Step in screen pixels, so a small cloud does not come out as a
				# polygon and a huge one does not cost a thousand rects.
				var px_r: float = rad * r_max * zoom
				# Dense enough that consecutive samples land on touching pixels,
				# so the boundary comes out as an unbroken line rather than a
				# dotted one. A circumference is 2*PI*r pixels, so one sample per
				# pixel of it and a little over.
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
					var q := c + pn * r_max * zoom
					if q.x < 0.0 or q.y < 0.0 or q.x > size.x or q.y > size.y:
						continue
					draw_rect(Rect2(q.round(), Vector2.ONE), col, true)

	## What cloud you are pointing at. Smaller than a system's tooltip and with
	## no numbers on it: a nebula is somewhere you can be, not something you can
	## jump to, so it answers what it is called and nothing else.
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

	## How far the ship can go, drawn where it can be seen.
	##
	## AN ELLIPSE, NOT A CIRCLE, and that is the whole of it. `galaxy_pos` draws
	## the disc foreshortened -- `Vector2(cos(a), sin(a) * squash)` -- and
	## `hop_distance` measures in the disc's own plane, dividing `gal.y` back out
	## by that same squash. So the reachable set is a circle in the galaxy and an
	## ELLIPSE on the chart: at squash 0.62 you reach about 1.6x further sideways
	## than you do up or down, in screen pixels.
	##
	## Reported as a bug -- a system plainly nearer than a reachable one that
	## could not be reached. It is not one; it was just impossible to see. A ring
	## that is visibly wide and flat says "down costs more than across" without a
	## word of explanation, and says the galaxy is tilted while it is at it.
	##
	## Whole pixels and a step count tied to the radius, for the reason `_dotted`
	## gives below: a ring walked in continuous space lands its dashes on
	## fractions of a pixel and shimmers as you pan.
	func _draw_reach_ring(c: Vector2) -> void:
		# TWO RINGS, BECAUSE THERE ARE TWO LIMITS AND THEY ARE NOT THE SAME ONE.
		# Sight is `base * (SENSE_FLOOR + sensors * SENSE_REACH)` and reach is
		# `base * thrust_reach()`, so the dish ALWAYS outruns the engine -- 1.39x
		# at no sensors at all, near 3x at ten.
		#
		# Only the inner one used to be drawn, which left the outer boundary with
		# no line on it: systems lit up outside the ring you could see and there
		# was nothing to say why. Reported as "I can see outside my range
		# circle?", which is exactly right and exactly the design.
		#
		# The gap between them is what a dish BUYS, and now it is a visible band
		# rather than an inference from which dots happen to be lit.
		# AND THE OUTER ONE HAS TO BE VISIBLE, which took a second report to
		# notice. Drawing it was not enough: at alpha 0.34 in single pixels, two
		# on and three off, on a ring with a far bigger circumference than the
		# inner one, the dots land further apart AND dimmer than reach's -- so on
		# a dense starfield the only boundary a player could actually find was the
		# orange one, and every system in the band between them read as a bug.
		# Measured after the fact by `-- chartfilter`: nothing was wrong with the
		# filter, the line saying where the limit was simply could not be seen.
		#
		# So sight carries reach's weight and a LONGER dash. Two boundaries at the
		# same rhythm in two colours are one boundary drawn twice; a long dash
		# reads as an outer limit and a short dot as an immediate one, which is
		# what they respectively are.
		if show_sight:
			_ring(c, Run.sense_radius(), Color(0.31, 0.69, 0.74, 0.50), 5, 9)
		if show_reach:
			_ring(c, Run.jump_range(), Color(0.83, 0.46, 0.24, 0.46))

	## One dashed ellipse at `r` galaxy units, centred on the ship.
	##
	## `on`/`period` is the dash rhythm. It is a parameter because the two rings
	## have to be TELLABLE APART at a glance -- see `_draw_reach_ring`.
	func _ring(c: Vector2, r: float, col: Color, on: int = 2, period: int = 5) -> void:
		if r <= 0.0:
			return
		var rx := r * _radius() * DISC * zoom
		var ry := rx * _squash()
		# Under about six pixels it is a smudge on the ship rather than a ring,
		# and at that size the dotted lines already say everything it would.
		if rx < 6.0:
			return
		# One step per pixel of circumference, near enough, so the dash rhythm
		# stays the same length on screen at every zoom.
		var steps := clampi(int(rx * 1.6), 60, 480)
		for i in steps:
			if i % period >= on:
				continue
			var a := TAU * float(i) / float(steps)
			draw_rect(Rect2((c + Vector2(cos(a) * rx, sin(a) * ry)).round(),
				Vector2.ONE), col, true)

	## A dashed run between two points, in whole pixels. draw_dashed_line exists
	## but works in continuous space, so its gaps land on fractions of a pixel
	## and the dashes shimmer as you pan — the one thing a pixel chart cannot
	## have.
	func _dotted(a: Vector2, b: Vector2, col: Color) -> void:
		var span := a.distance_to(b)
		if span < 1.0:
			return
		var step := (b - a) / span
		var i := 2.0
		while i < span - 2.0:
			# Two on, three off.
			if int(i) % 5 < 2:
				draw_rect(Rect2((a + step * i).round(), Vector2.ONE), col, true)
			i += 1.0

	## What this system is, at the cursor. Zoomed out every system is a two-pixel
	## dot, so without this the chart is unreadable — you can see the shape of the
	## galaxy and nothing about the places in it.
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

		var l1 := MapGen.star_name(n)
		var l2 := MapGen.type_label(n.type)
		if n.cleared and n.type != MapGen.NodeType.CORE:
			l2 = "CLEARED · " + l2
		var l3 := MapGen.place_line(n)
		var l4 := "DANGER %d/10" % n.danger
		if here.links.has(n.index):
			l4 += "   %d FUEL" % Run.fuel_cost_to(n)

		# THE SAME REFUSAL THE PANEL MAKES, and it has to be made twice or it is
		# not made at all: the tooltip prints type, place and danger, which is
		# precisely the survey the destination panel just declined to give. One
		# hover and the withholding is undone.
		#
		# Fuel survives, because reachability is a fact about your tank and the
		# link you are standing next to rather than about the place.
		if Run.known_only_by_contract(n.index):
			var job := Run.contract_at(n.index)
			l2 = "%s WANTS SOMETHING HERE" % DB.short_name(
				DB.manufacturer_name(job.manufacturer)).to_upper()
			l3 = "POSITION ONLY · NO SURVEY"
			l4 = "%d CREDITS" % job.pay
			if here.links.has(n.index):
				l4 += "   %d FUEL" % Run.fuel_cost_to(n)

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

	## Where a background pixel appears once the black hole has bent the light
	## from it, and whether it is visible at all.
	##
	## Two things were wrong before this. The deep field is drawn BEFORE the
	## galaxy, and nothing masked it, so distant stars and galaxies showed
	## straight through the hole — the one object in the game that light does not
	## come out of was the most transparent thing on screen.
	##
	## And a black hole does not merely block what is behind it, it wraps it: an
	## approximate Einstein deflection pushes background points radially outward
	## by r_s^2 / d, which piles them into a bright arc just outside the shadow
	## and clears a true void inside. Anything that lands within the shadow is
	## behind the hole and is not drawn at all.
	##
	## Returns false when the point is swallowed.
	func _lens(p: Vector2, centre: Vector2, r_s: float, out: Array) -> bool:
		var d := p - centre
		var far := d.length()
		if far < 0.001:
			return false
		if far <= r_s:
			return false
		var shifted := far + (r_s * r_s) / far
		out[0] = centre + d * (shifted / far)
		return true

	## A stable hash for a tile of the deep field. The far field has to be built
	## from position, not from a running sequence: a sequence re-rolls every star
	## the moment anything about the field changes, which is what made the sky
	## crawl when you zoomed.
	func _hash2(i: int, j: int, salt: int) -> int:
		var h := (i * 374761393 + j * 668265263 + salt * 144665) & 0x7fffffff
		h = (h ^ (h >> 13)) & 0x7fffffff
		h = (h * 1274126177) & 0x7fffffff
		return (h ^ (h >> 16)) & 0x7fffffff

	func _frac(h: int) -> float:
		return float(h % 10000) / 10000.0

	## The deep field is tiled by position and hashed from the tile coordinates,
	## which made it identical in every run: seeding the galaxy's own layers was
	## not enough, because none of the sky outside the disc came from those
	## seeds. Folding the run seed into the salt gives each run its own universe
	## while keeping a tile's contents fixed for as long as you look at it.
	func _sky(salt: int) -> int:
		return salt + (Run.galaxy_seed % 100003) * 31

	## Other galaxies, very far away. Field stars alone say "we are somewhere in
	## a galaxy"; these say "and it is one of many", which is the loneliness the
	## whole game is about. Drawn first so our own disc passes in front of them.
	##
	## Parallax is deliberate: they shift at a quarter of the chart's rate, so
	## they read as sitting far behind the galaxy rather than pasted onto it.
	## The deep field, in two layers at different parallax rates.
	##
	## One layer of anything reads as a backdrop; two layers moving at different
	## speeds read as distance. The far layer is smaller, dimmer and slower, so
	## panning separates them and the galaxy sits in something rather than on it.
	func _draw_far_galaxies(ci: CanvasItem) -> void:
		# Tighter tiling and a looser presence test: the deep shell is the one
		# that sells the distance, and it was sparse enough to read as a handful
		# of smudges rather than a sky full of them.
		# Three shells now. The deep one is tiled tight and keeps nearly every
		# tile — it is what makes the back of the sky busy rather than sparse —
		# while the near shell holds a handful of big, close galaxies that swing
		# properly when you drag. Without that near shell the deep field has no
		# top end: everything sits at one apparent distance and reads flat.
		# Seven shells of distant galaxies, on their own spread of depths, for the
		# same reason as the stars: three shells put every galaxy at one of three
		# speeds and they moved in obvious groups.
		for k in 7:
			var f := float(k) / 6.0
			_far_layer(ci, lerpf(150.0, 700.0, f), lerpf(0.09, 0.58, f) * FAR_PARALLAX,
				lerpf(1.5, 9.0, f), lerpf(3.5, 20.0, f),
				lerpf(0.5, 1.0, f), lerpf(0.92, 0.6, f), 3 + k * 53)

	## Six palettes for the deep field. Everything out there used to be the same
	## cold blue-grey, which is most of why a sky full of objects read as one
	## object repeated. Bright, mid and dim for each.
	const _FAR_PALETTES := [
		[Color("#6d7f96"), Color("#2f3d4e"), Color("#161e2a")],
		[Color("#a3856a"), Color("#4b3c30"), Color("#241d18")],
		[Color("#5e9b93"), Color("#2b4a47"), Color("#152726")],
		[Color("#8a6fa8"), Color("#403353"), Color("#211a2b")],
		[Color("#a86f78"), Color("#4e343a"), Color("#28191d")],
		[Color("#9fb4cc"), Color("#3d5064"), Color("#1b2534")],
	]

	## One shell of distant objects, tiled by position so they never move, with a
	## single hash per tile — the tile loop runs thousands of times a repaint and
	## hashing was most of the cost.
	##
	## Each tile rolls a KIND as well as a size and a palette. A deep field of
	## identical blobs is wallpaper; ellipticals beside edge-on slivers beside a
	## big ragged nebula is a sky.
	func _far_layer(ci: CanvasItem, cell: float, parallax: float,
			rad_min: float, rad_span: float, bright: float, density: float,
			salt: int) -> void:
		# Deliberately NOT scaled by zoom. Scaling each layer by pow(zoom,
		# parallax) is textbook depth, and it looked like the scene being
		# redrawn: every layer resized at its own rate, every pixel re-rounded
		# to a new integer, and a pixel-art starfield has no sub-pixel motion to
		# absorb that — it just crawls. Distance is carried by pan alone, which
		# is where the effect was doing its work anyway. Objects this far away
		# would not visibly change size for a move this small in any case.
		var zf: float = 1.0
		var c := size * 0.5 + sky_pan * parallax
		var here := size * 0.5 + pan
		var step := cell * zf
		var i0 := int(floor(-c.x / step)) - 1
		var i1 := int(floor((size.x - c.x) / step)) + 1
		var j0 := int(floor(-c.y / step)) - 1
		var j1 := int(floor((size.y - c.y) / step)) + 1
		var guard := _radius() * DISC * 0.95 * zoom
		var r_s := _shadow_r() * zoom * 1.05

		for i in range(i0, i1 + 1):
			for j in range(j0, j1 + 1):
				var h := _hash2(i, j, _sky(salt))
				var u := float(h % 1000) / 1000.0
				var v := float((h / 1000) % 1000) / 1000.0
				var w := float((h / 1000000) % 1000) / 1000.0
				var k := float((h / 7) % 1000) / 1000.0
				if float((h / 13) % 1000) / 1000.0 > density:
					continue

				# 0-1 elliptical · 2 spiral · 3 edge-on · 4 nebula · 5 cluster
				var kind := (h / 17) % 6
				var q := c + Vector2((float(i) + u) * cell, (float(j) + v) * cell) * zf
				var rad: float = (rad_min + w * rad_span) * maxf(0.35, zf)
				if kind == 4:
					# Nebulae are the big diffuse things. Making them merely
					# "another blob, slightly larger" is what made the whole
					# field read as one size.
					rad *= 2.2 + w * 2.4
				elif kind == 2:
					rad *= 1.5
				if q.x < -rad * 3.0 or q.y < -rad * 3.0 \
						or q.x > size.x + rad * 3.0 or q.y > size.y + rad * 3.0:
					continue
				# Nothing is culled outright: the disc travels at full rate while
				# this layer travels at `parallax`, so a hard cull on the centre
				# made objects pop in and out as the two slid past each other.
				var fade: float = clampf((q - here).length() / maxf(1.0, guard), 0.0, 1.0)
				if fade <= 0.02:
					continue

				var pal: Array = _FAR_PALETTES[(h / 23) % _FAR_PALETTES.size()]
				var tilt: float = k * PI
				var flat: float = 0.16 + w * 0.62
				var n := int((22.0 + w * 58.0) * bright)
				match kind:
					4: n = int((150.0 + w * 200.0) * bright)
					2: n = int((90.0 + w * 90.0) * bright)
					5: n = int((28.0 + w * 40.0) * bright)
				var seed := h

				for gi in n:
					seed = (seed * 1103515245 + 12345) & 0x7fffffff
					var t := float((seed >> 13) % 10000) / 10000.0
					seed = (seed * 1103515245 + 12345) & 0x7fffffff
					var t2 := float((seed >> 13) % 10000) / 10000.0
					seed = (seed * 1103515245 + 12345) & 0x7fffffff
					var t3 := float((seed >> 13) % 10000) / 10000.0

					var rr: float = 0.0
					var local := Vector2.ZERO
					match kind:
						2:
							# Spiral: two arms wound out of a bright middle.
							rr = pow(t, 0.75) * rad
							var arm: float = 0.0 if gi % 2 == 0 else PI
							var ang: float = arm + t * 3.4 + (t2 - 0.5) * 0.7
							local = Vector2(cos(ang) * rr, sin(ang) * rr * flat)
						3:
							# Edge-on: a sliver with a dust lane down the middle.
							var along: float = (t - 0.5) * 2.0 * rad
							var across: float = (t2 - 0.5) * rad * 0.30 \
								* (1.0 - absf(along) / maxf(1.0, rad) * 0.7)
							if absf(across) < rad * 0.035 and absf(along) > rad * 0.2:
								continue
							rr = absf(along)
							local = Vector2(along, across)
						4:
							# Nebula: a few overlapping clumps, ragged edges.
							var lobe := (gi % 3)
							var lx: float = (float((h / (37 + lobe)) % 100) / 100.0 - 0.5) * rad * 0.9
							var ly: float = (float((h / (53 + lobe)) % 100) / 100.0 - 0.5) * rad * 0.7
							rr = pow(t, 0.6) * rad * 0.62
							var na: float = t2 * TAU
							local = Vector2(lx + cos(na) * rr, ly + sin(na) * rr * 0.8)
							rr = local.length()
						5:
							# Cluster: loose knot of individual stars.
							rr = pow(t, 2.2) * rad
							var ca: float = t2 * TAU
							local = Vector2(cos(ca) * rr, sin(ca) * rr * 0.9)
						_:
							rr = pow(t, 1.9) * rad
							var ea: float = t2 * TAU
							local = Vector2(cos(ea) * rr, sin(ea) * rr * flat)
					local = local.rotated(tilt)

					var pt := q + local
					if not _lens(pt, here, r_s, _lens_out):
						continue
					pt = (_lens_out[0] as Vector2).round()
					if pt.x < 0 or pt.y < 0 or pt.x > size.x or pt.y > size.y:
						continue
					# Thins as it nears our own disc. t3 is deterministic per
					# pixel, so the same pixels drop out at the same distance.
					if t3 > fade:
						continue
					# Nebulae are gas, not stars: no bright cores, and holes in
					# them. Without the holes a big one is a solid lump.
					if kind == 4 and t3 > 0.62:
						continue

					var near := 1.0 - clampf(rr / maxf(1.0, rad), 0.0, 1.0)
					var col: Color = pal[2]
					if kind == 4:
						col = pal[1] if t3 > 0.34 else pal[2]
					elif kind == 5:
						col = pal[0] if t3 > 0.55 else pal[1]
					elif near > 0.82:
						col = pal[0]
					elif near > 0.52:
						col = pal[1]
					elif t3 > 0.86:
						col = pal[1]
					if bright < 1.0:
						col = col.darkened(1.0 - bright)
					ci.draw_rect(Rect2(pt, Vector2.ONE), col, true)

	## Field stars, also in two layers at different parallax rates. Without these
	## the galaxy is a blob in a box: the arms fade out and the corners go flat
	## black, which reads as the edge of a texture rather than the edge of a
	## galaxy. Tiled by position so a star stays put, and unbounded by
	## construction so there is no edge to pan off.
	## Twenty-two depths of field stars rather than two.
	##
	## Two layers meant every star moved at one of two speeds, and the eye finds
	## that instantly — you do not see depth, you see two sheets of glass sliding
	## over each other. With twenty-two, no two neighbouring stars are quite
	## agreeing about how fast they should move, which is what parallax actually
	## looks like.
	##
	## Each layer is correspondingly sparser (cell size scales with the square
	## root of the count) so the total star density and the total tile work are
	## about what they were with two.
	const DEPTHS := 22

	func _draw_halo(ci: CanvasItem) -> void:
		for k in DEPTHS:
			var f := float(k) / float(DEPTHS - 1)
			# Nearer layers are brighter and slightly denser: distance is carried
			# by speed, brightness and count together, not by speed alone.
			var parallax: float = lerpf(0.05, 0.62, f) * PARALLAX
			var cell: float = lerpf(62.0, 44.0, f)
			var bright: float = lerpf(0.42, 1.0, f)
			_star_layer(ci, cell, parallax, 0.34, bright, 5 + k * 37)

	func _star_layer(ci: CanvasItem, cell: float, parallax: float,
			empty: float, bright: float, salt: int) -> void:
		# Fixed under zoom, for the same reason as the galaxies above: a field
		# of single pixels cannot be rescaled without shimmering.
		var zf: float = 1.0
		var c := size * 0.5 + sky_pan * parallax
		var here := size * 0.5 + pan
		var step := cell * zf
		var i0 := int(floor(-c.x / step)) - 1
		var i1 := int(floor((size.x - c.x) / step)) + 1
		var j0 := int(floor(-c.y / step)) - 1
		var j1 := int(floor((size.y - c.y) / step)) + 1
		# TIMES DISC, which it was missing. `_polar` places a system at
		# `gal * _radius() * DISC`, and `_pan_limit` bounds the view by
		# `_radius() * DISC * zoom` -- its comment says outright that "the halo
		# is sized to cover exactly this much". This did not: without the DISC
		# factor of 2.05 the thinned region was less than half the galaxy's
		# drawn extent, so its edge fell INSIDE the systems and read as a hard
		# boundary ring drawn across the disc rather than around it.
		var disc := _radius() * DISC * zoom * 1.1
		var r_s := _shadow_r() * zoom * 1.05
		var core_px := _core_clear() * zoom

		for i in range(i0, i1 + 1):
			for j in range(j0, j1 + 1):
				var h := _hash2(i, j, _sky(salt))
				var w := float(h % 1000) / 1000.0
				# Most tiles are empty sky. Bail before touching anything else.
				if w < empty:
					continue
				var u := float((h / 1000) % 1000) / 1000.0
				var v := float((h / 1000000) % 1000) / 1000.0
				var q := (c + Vector2((float(i) + u) * cell, (float(j) + v) * cell) * zf)
				if not _lens(q, here, r_s, _lens_out):
					continue
				q = (_lens_out[0] as Vector2).round()
				if q.x < 0 or q.y < 0 or q.x > size.x or q.y > size.y:
					continue
				# Thin out over the disc so the halo never competes with the arms.
				# HOW FAR IN, 1.0 at the galaxy's centre and 0.0 at `disc`.
				var dr: float = (q - here).length() / maxf(1.0, disc)
				var fade: float = clampf((1.0 - dr) / DISC_FEATHER, 0.0, 1.0)
				# A BINARY TEST HERE DRAWS A CIRCLE. This dropped 88% of the
				# foreground field inside `disc` and none outside it, so the sky
				# changed density across a single pixel and the eye reads that
				# as an edge: a dark moat around the galaxy with a hard rim.
				# Measured on the radial profile at ZOOM_MIN, lit pixels went
				# 1.2% at r=192 to 0.5% at r=204 and stayed there until r=336.
				#
				# The moat is also why it looked like a ZOOM bug. `disc` scales
				# with zoom, so its rim sweeps outward as you lean in and the
				# visible band of ordinary sky between the galaxy and the rim
				# narrows until it leaves the screen.
				if w < 0.88 * fade:
					continue
				# And a dark cloud blocks whatever is behind it — including
				# this. These are the far sky, drawn straight through the galaxy
				# and never asked whether anything was in the way, so the twelve
				# percent that survive the thinning above were shining out of
				# the middle of every dark nebula on the chart. They are also
				# the BRIGHTEST twelve percent, which is why a cloud defined by
				# blocking light was the one place the sky looked busiest.
				#
				# The roll comes out of the tile hash rather than a live RNG:
				# these layers repaint on every pan, and anything not derived
				# from the tile itself would make the whole field crawl.
				# Faded by the same shoulder, or the extinction puts a second
				# hard rim back at exactly the radius the first one left.
				if fade > 0.0 and not _dark_r.is_empty():
					var ex: float = _extinct((q - here) / maxf(0.001, zoom)) * fade
					if ex > 0.02 and float((h / 7) % 1000) / 1000.0 < ex:
						continue
				# And nothing at all over the turning core. These are field
				# stars — sky, not galaxy — so no core rule had ever applied to
				# them, and the twelve percent that survive the thinning above
				# were sitting stock still among the orbiting material. A static
				# star anywhere near a moving one is the thing that gives the
				# whole effect away, whichever layer it belongs to.
				if (q - here).length() < core_px:
					continue
				var col := Color("#121a26")
				if w > 0.985:
					col = Color("#6f8399")
				elif w > 0.93:
					col = Color("#33445a")
				if bright < 1.0:
					col = col.darkened(1.0 - bright)
				ci.draw_rect(Rect2(q, Vector2.ONE), col, true)

	## Where the rest of the party is.
	##
	## Drawn OUTSIDE the visibility filter, deliberately. The chart otherwise
	## hides a system you have never been to and cannot reach, which is right for
	## a place and wrong for a person: a partner four shells coreward is the one
	## piece of information you most want and the one you can least reach. It is
	## also what makes `docs/coop-design.md` §7 legible — danger tracking the deepest
	## ship is only a leash if you can see how deep they are.
	##
	## `docs/coop-design.md` §9 rules that this should be gated on sensor range, with
	## a last-known position and an age stamp outside it. There is no fog in the
	## game yet, so this shows everybody. When fog arrives it gates the position
	## going ONTO the wire rather than coming off it, and nothing here changes.
	func _draw_party() -> void:
		if not show_icons or Net.party_size() < 2:
			return
		var seen: Dictionary = {}
		for slot in Net.partners():
			var at := int(slot.get("at", -1))
			if at < 0 or at >= Run.map.size():
				continue
			var c := _screen_pos(Run.map[at])
			# Backed in ink, and the name shadowed with it.
			#
			# Not a polish pass. The deepest ship is the one this marker exists
			# to show — `docs/coop-design.md` §7 makes everybody's danger track it —
			# and deep means over the core, which is the brightest thing on the
			# chart. Unbacked, the one marker that matters most was the only one
			# you could not see.
			_diamond(c, 6.0, UITheme.VOID)
			_diamond(c, 5.0, UITheme.GOOD)
			# Stacked when two ships are in the same system, which is the whole
			# point of flying together and would otherwise print one name on top
			# of another.
			var row := int(seen.get(at, 0))
			seen[at] = row + 1
			var label := String(slot.get("name", "")).to_upper()
			var at_text := c + Vector2(-46, -12 - row * 10)
			draw_string(UITheme.pixel_font(), at_text + Vector2(1, 1), label,
				HORIZONTAL_ALIGNMENT_CENTER, 92, 8, Color(0, 0, 0, 0.85))
			draw_string(UITheme.pixel_font(), at_text, label,
				HORIZONTAL_ALIGNMENT_CENTER, 92, 8, UITheme.GOOD)

	## The galaxy's other harvester, drawn wherever the host last said it was.
	##
	## OUTSIDE any visibility filter, like the party and the work, and the
	## fiction pays for it: the hellbender is the hottest thing flying, and heat is
	## the one signature this game says you cannot hide. That is also its
	## balance — a threat you can always see is a threat you can always route
	## around, and routing around it has a price the map charges in salvage.
	func _draw_hellbender() -> void:
		if not show_icons or not Run.hellbender_alive() \
				or Run.hellbender_at >= Run.map.size():
			return
		var c := _screen_pos(Run.map[Run.hellbender_at])
		_diamond(c, 7.0, UITheme.VOID)
		_diamond(c, 6.0, UITheme.EMBER)
		var at_text := c + Vector2(-46, -14)
		draw_string(UITheme.pixel_font(), at_text + Vector2(1, 1), "THE HELLBENDER",
			HORIZONTAL_ALIGNMENT_CENTER, 92, 8, Color(0, 0, 0, 0.85))
		draw_string(UITheme.pixel_font(), at_text, "THE HELLBENDER",
			HORIZONTAL_ALIGNMENT_CENTER, 92, 8, UITheme.EMBER)

	## The delivery berths `_draw_work` last worked out, and what they were
	## worked out for. Invalidated by the only two things that can change the
	## answer — the ledger moving and you moving — so a stale cache is impossible
	## rather than unlikely.
	var _work_key: String = ""
	var _work_berths: Dictionary = {}

	## Where the work is. A ring in the issuing manufacturer's colour, on every system an
	## open contract points at.
	##
	## THE CHART IS WHERE A CONTRACT BECOMES PLAYABLE. A fetch that names "Kappa
	## Thorn Reach" and then leaves you to find it is a memory test, and the
	## station board is four screens away from the only page that plots a jump.
	##
	## Drawn OUTSIDE the visibility filter, like the party markers above and for
	## the same reason: the filter is right about places and wrong about
	## intentions. A job you signed for is a fact about YOU, and hiding it until
	## you happen to fly within sensor range of it would hide it exactly while it
	## is still a decision.
	##
	## Not a route and not an arrow. It says where, and leaves the whether alone —
	## see ContractData's header on why nothing here pushes you anywhere.
	## A SYSTEM SOMEBODY PUT SOMETHING ON, and the name of the thing.
	##
	## A CHEVRON POINTING DOWN AT IT, and every other shape was taken. The chart
	## speaks in rings for contracts -- one for a fetch, two for a hunt -- in
	## diamonds for the party and the hellbender, and in four corner ticks for
	## YOU. Corner ticks were the first thing I drew here and they were wrong:
	## gold ticks beside amber ticks is the same marker in two colours, and the
	## one meaning "you are here" is the one you least want doubled.
	##
	## A SQUARE, and it took three tries to get there. A filled triangle was too
	## heavy -- nothing on this map is filled -- and an open chevron was two
	## strokes floating over a star with nothing tying them to it.
	##
	## The three markers are now three shapes at the same weight: a SQUARE for a
	## quest, a DIAMOND for the hellbender, and the corner brackets for YOU. All
	## outlines, all a pixel wide, told apart by form rather than by colour --
	## which matters most zoomed out, where colour is two pixels and shape is
	## the only thing left.
	##
	## The name rides above it, which no other marker carries and which is the
	## one thing a quest has that a contract ring does not.
	##
	## IT IGNORES THE VISIBILITY RULE, and that is the point of it. The chart
	## deliberately hides systems you have never been to and cannot reach,
	## because "a system you can neither see nor go to is not information you can
	## act on" -- and a quest is the one thing on the map that IS. You cannot act
	## on it this minute; you can route toward it, which is the entire reason it
	## was placed four jumps deeper instead of handed to you.
	##
	## The name goes ABOVE. Hovering already prints a system's own name below it,
	## and two labels on one node stacked on each other.
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
			draw_rect(box.grow(1.0), UITheme.VOID, false, 3.0)
			draw_rect(box, gold, false, 1.0)
			draw_string(UITheme.pixel_font(), c + Vector2(-46, -13), said,
				HORIZONTAL_ALIGNMENT_CENTER, 92, 8, gold)


	func _draw_work() -> void:
		if not show_icons or Run.map.is_empty():
			return
		# CACHED, because this runs inside _draw(). `_nearest_berths` scans all
		# ~190 systems and sorts them, once per paying manufacturer — and _draw() is
		# queued on every mouse-motion frame while panning and on every frame of
		# the hover ease. None of its inputs change during either, so the same
		# scan-and-sort was repeated for identical output several times a second.
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
			draw_arc(c, 9.0, 0.0, TAU, 20, UITheme.VOID, 3.0)
			draw_arc(c, 9.0, 0.0, TAU, 20, col, 1.0)
			# A second, tighter ring for a hunt, so the two kinds are told apart
			# without a label. Fetch is an open circle; hunt has something in it.
			if job.kind == ContractData.Kind.HUNT:
				draw_arc(c, 4.0, 0.0, TAU, 12, col, 1.0)

		# AND WHERE IT GETS HANDED OVER, which is the third thing to mark and the
		# one that was missing. A fetch and a hunt ring a place before you go; a
		# finished job and a heat contract have to ring a place you come BACK to,
		# and a heat contract never had a target at all. Every berth of that
		# manufacturer, because delivery is to the manufacturer rather than to the desk that
		# posted it.
		#
		# A square rather than a ring, and filled: this is not somewhere to look,
		# it is somewhere to land.
		# THE NEAREST FEW, NOT ALL OF THEM. A manufacturer holds berths all over the
		# galaxy and marking every one drew twelve squares across the disc, which
		# reads as a rash rather than as directions — and the question a player is
		# actually asking is not "where could I hand this over" but "where is the
		# closest place I can". Three is enough to offer a choice of routes and
		# few enough to be a marking.
		for manufacturer in _work_berths:
			var hcol := DB.manufacturer_colour(manufacturer)
			for st in _work_berths[manufacturer]:
				var p := _screen_pos(st)
				draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 10)), UITheme.VOID, false, 3.0)
				draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 10)), hcol, false, 1.0)
				draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), hcol, true)

	## The closest berths of one manufacturer, by galaxy distance from where you stand.
	##
	## Distance rather than jumps, deliberately. A route is a fuel question that
	## the neighbour list answers properly and a straight line cannot, and a chart
	## marking that pretended to know the route would be wrong the first time a
	## link did not exist. This says WHICH WAY, and leaves the how to the list.
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

	## THE LABEL ONLY. This used to draw corner brackets as well, at 21 pixels
	## with 5-pixel arms -- and `Glyph.draw_glyph` has always bracketed the
	## current node too, at 16 with 4, in the same FLARE. So the ship sat inside
	## two nested boxes that were meant to be one, close enough in size to read
	## as a rendering fault rather than as a design.
	##
	## The glyph's are kept because they are drawn WITH the node and scale with
	## it; this one is a label and does the job the glyph cannot.
	func _draw_you(p: Vector2, tiny: bool) -> void:
		# AND ITS BRACKETS ONLY WHERE THE GLYPH IS NOT DRAWING ANY. Zoomed out,
		# a system is a two-pixel rect and `Glyph.draw_glyph` never runs -- so
		# removing these outright to kill the double box took the ship's marker
		# off the chart at exactly the zoom where it is hardest to find.
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
				draw_rect(Rect2(k + Vector2(0, -1 if dd.y < 0 else 0),
					Vector2(b * dd.x, 1)), UITheme.FLARE, true)
				draw_rect(Rect2(k + Vector2(-1 if dd.x < 0 else 0, 0),
					Vector2(1, b * dd.y)), UITheme.FLARE, true)
		draw_string(UITheme.pixel_font(), p + Vector2(-14, 30), "YOU",
			HORIZONTAL_ALIGNMENT_CENTER, 40, 8, UITheme.FLARE)

	## Build the galaxy once: arms, the wash between them, the tidal stream and
	## the burning core, all as positions in galaxy space with their colours.
	## Nothing in here depends on pan or zoom, which is the entire point.
	func _build_stars() -> void:
		var g := _g()
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
			_sky_galaxy = galaxy
		if _sky_cache.has(key):
			_restore_sky(_sky_cache[key])
			_star_key = key
			return
		_star_key = key
		# Orbits are rebuilt with the field; _build_orbits is called at the end,
		# once _core_skipped has been counted.
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

		# The dark clouds, flattened to lobes in drawn galaxy space so the
		# passes below can take stars out from behind them. Built before
		# anything is placed, because everything placed has to ask.
		_dark_c = PackedVector2Array()
		_dark_r = PackedFloat32Array()
		_dark_orb_c = PackedVector2Array()
		_dark_orb_r = PackedFloat32Array()
		for raw_dark in NebulaField.clouds():
			var dc: NebulaField.Cloud = raw_dark
			if dc.kind != NebulaField.Kind.DARK:
				continue
			for l in dc.lobes.size():
				var dcen: Vector2 = (dc.pos + dc.lobes[l]) * r_max
				var drad: float = dc.lobe_r[l] * r_max
				_dark_c.append(dcen)
				_dark_r.append(drad)
				# Does this lobe reach into the turning region? Usually not —
				# clouds sit out in the disc and the live layer only owns the
				# middle. But NebulaField deliberately places one cloud at 0.05
				# to 0.21 of the disc so the black hole has gas within reach,
				# and when THAT one rolls dark it lands squarely in the orbits.
				if dcen.length() - drad < _core_clear():
					_dark_orb_c.append(dcen)
					_dark_orb_r.append(drad)
		# Nothing static is drawn inside the cleared core — not the arms, not the
		# dust, not the tidal tail, not the bulge. The hole itself is empty, and
		# the annulus around it belongs to the live layer, which orbits stars
		# through it. Measured on the drawn position, so it stays round however
		# flattened the galaxy is: a black hole's shadow is a sphere's shadow.
		var shadow := _shadow_r()
		var clear := _core_clear()

		## Whether a drawn position falls inside the region the live layer owns.
		## Measured in UNSQUASHED space, which is the fix for the dark crescents
		## above and below the core: the orbiting stars are laid out on the
		## galaxy's ellipse, but this test was a circle, so a band was cleared of
		## static stars that the orbiting ones never reached. The hole itself
		## stays round — that is the accretion disc's inner radius, not this.
		## Everything about the core is measured in DRAWN space, and is round.
		##
		## Ownership used the unsquashed radius so it would line up with the
		## ellipse the orbits were laid out on, and that was the root of a whole
		## family of bugs. On a flattened galaxy a star sitting a few pixels
		## above the hole has a large unsquashed radius: it reads as far out,
		## keeps its place in the static field, and sits there motionless right
		## beside the thing everything else is orbiting. Same arithmetic put
		## stars inside the hole earlier.
		##
		## A black hole is round on screen whatever the inclination of its
		## galaxy, and so is the cluster around it. Measuring the distance you
		## can actually see makes the rule mean what it says: near the hole is
		## near the hole.


		# --- the wash between the arms. The gaps are not empty space, they are
		# unlit space, and painting them flat black makes the arms look like
		# cutouts instead of the bright parts of something continuous.
		var seed := (Run.galaxy_seed * 2654435761 + 24601) & 0x7fffffff
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
		seed = (Run.galaxy_seed * 2654435761 + 1337) & 0x7fffffff
		for i in 30000:
			seed = (seed * 1103515245 + 12345) & 0x7fffffff
			var t := float((seed >> 13) % 10000) / 10000.0
			seed = (seed * 1103515245 + 12345) & 0x7fffffff
			var t2 := float((seed >> 13) % 10000) / 10000.0
			seed = (seed * 1103515245 + 12345) & 0x7fffffff
			var t3 := float((seed >> 13) % 10000) / 10000.0
			seed = (seed * 1103515245 + 12345) & 0x7fffffff
			# Its own roll, spent only on extinction. Reusing t2 or t3 would
			# tie which stars a dark cloud eats to their arm spread or their
			# brightness — so the cloud would swallow one side of an arm, or
			# every bright star and no faint one, instead of what is behind it.
			var t4 := float((seed >> 13) % 10000) / 10000.0

			# Two populations rather than one falloff. A single exponent cannot
			# be both dense at the core and present at the rim.
			var inner: bool = float(i % 100) < float(g.core_share) * 100.0
			var u: float = pow(t, float(g.core_pow) if inner else float(g.halo_pow))
			var hole: float = g.ring
			if hole > 0.0:
				u = hole + u * (1.0 - hole)
			# The outermost few percent of stars are stretched well past the
			# nominal edge. Without this the disc simply stops at r_max — every
			# star inside, none outside — and a galaxy with a hard boundary
			# reads as a picture pasted onto the starfield. Spreading the last
			# few percent over half again the radius makes density decay instead
			# of truncating, and only that outer tail moves at all.
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

			# Deliberately NOT clamped: the stretched tail runs past 1.0, and
			# letting it read as "beyond the edge" is what makes the fringe fade
			# rather than stack up into a rim.
			var far := rr / r_max
			var near := 1.0 - clampf(far, 0.0, 1.0)
			# Brightness thins with radius too, so the edge goes wispy rather
			# than merely sparser — dim pixels at full brightness still read as
			# a boundary no matter how few of them there are.
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
			# Behind a dark cloud. Most of what it covers is simply gone; what
			# survives is dimmed, so the cloud has a depth to it rather than a
			# clean bite taken out of the field.
			# Tempered to three quarters. The diffuse field is what gives the
			# cloud its body; take all of it and there is no cloud, just a hole.
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
			seed = (Run.galaxy_seed * 2654435761 + 5150) & 0x7fffffff
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

		# --- the core, built out of pixels like everything else. draw_circle is
		# smooth-edged, which in a game with no anti-aliasing anywhere reads as a
		# blurry sticker laid over the art.
		var bulge := _radius() * float(g.bulge)
		seed = (Run.galaxy_seed * 2654435761 + 4242) & 0x7fffffff
		for i in 600:
			seed = (seed * 1103515245 + 12345) & 0x7fffffff
			var u := float((seed >> 13) % 10000) / 10000.0
			seed = (seed * 1103515245 + 12345) & 0x7fffffff
			var v := float((seed >> 13) % 10000) / 10000.0
			# The bulge spans the whole core outward. It no longer needs to start
			# beyond a boundary: the motion rule decides which of its stars
			# survive, and near the hole none of them do.
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

		_build_orbits()
		_build_disc()
		# The accretion ring is NOT built here. It used to be, and the live layer
		# drew a churning one at the same radius on top of it — so the bright
		# ring you actually saw was the static copy underneath, and no amount of
		# animation above it could make it move. The live layer owns the ring
		# outright now, exactly as it owns the orbiting stars.

		# --- the halo and the wreckage, last, so they sit on top of the disc they
		# are in front of.
		_build_clusters(r_max)
		_build_remnants(r_max)
		# Last: the wave samples the finished field, and clusters and
		# remnants both append to it.
		_build_wave()

		_sky_cache[_star_key] = _snapshot_sky()

	## The built sky, by field name. Taken after the last builder has run, so a
	## builder added later is included the moment its output is listed in
	## SKY_FIELDS — and omitted silently if it is not, which is the one way this
	## can go wrong. Anything _build_stars derives belongs in that list.
	func _snapshot_sky() -> Dictionary:
		var out: Dictionary = {}
		for f in SKY_FIELDS:
			out[f] = get(f)
		return out

	func _restore_sky(snap: Dictionary) -> void:
		for f in SKY_FIELDS:
			set(f, snap[f])

	func _seed_rng(salt: int) -> void:
		_rng = (Run.galaxy_seed * 2654435761 + salt) & 0x7fffffff

	func _rnd() -> float:
		_rng = (_rng * 1103515245 + 12345) & 0x7fffffff
		return float((_rng >> 13) % 10000) / 10000.0

	## Ordered dither, 4x4, indexed by position in GALAXY space rather than on
	## screen. The art contract allows this and nothing else, and a nebula is
	## mostly edge: a random stipple where the gas thins out reads as noise on
	## the screen, a fixed threshold pattern reads as gas. Keying it to the
	## galaxy rather than to the viewport is what stops the pattern crawling
	## across the cloud when you pan.
	const _DITHER4 := [
		0.031, 0.531, 0.156, 0.656,
		0.781, 0.281, 0.906, 0.406,
		0.219, 0.719, 0.094, 0.594,
		0.969, 0.469, 0.844, 0.344,
	]

	## How much a dark nebula blocks whatever is behind it, 0 to 1.
	##
	## A dark nebula is the one kind defined by what it HIDES, and the clouds
	## are drawn BEFORE the arms so that arm stars sit in front of the gas —
	## which is right for gas that glows and exactly wrong for gas that does
	## not. The result was a dust cloud with the full star field shining
	## through it, which is the one thing a dark nebula must never look like.
	##
	## Smoothstepped so the cloud has an edge you can see into rather than a
	## rim, and cheap enough to ask per star: a few lobes, no trig, and an
	## instant zero in a galaxy that rolled no dark clouds at all.
	func _extinct(p: Vector2) -> float:
		var e := 0.0
		for i in _dark_r.size():
			var d: float = (p - _dark_c[i]).length() / maxf(1.0, _dark_r[i])
			if d >= 1.0:
				continue
			var f: float = 1.0 - d
			e = maxf(e, f * f * (3.0 - 2.0 * f))
		# Returned RAW. The diffuse arm field tempers this down at its own call
		# site, because taking every one of those left a smooth black disc with
		# a hard rim — a hole cut in the galaxy rather than dust in front of it.
		# Bright point sources are the opposite case and want the full value:
		# a globular or a foreground-bright field star showing through at even
		# a quarter strength is precisely what stops a dark cloud reading dark.
		return e

	## Extinction from the dark lobes that reach the orbiting region only.
	##
	## Separate from _extinct because this one is asked per particle per FRAME,
	## where that one is asked once per pixel at build time. The static field
	## can be tested where it is placed and never again; orbiting material
	## moves, so whether a cloud is in front of it is a question with a new
	## answer every frame.
	func _extinct_orbit(p: Vector2) -> float:
		var e := 0.0
		for i in _dark_orb_r.size():
			var d: float = (p - _dark_orb_c[i]).length() / maxf(1.0, _dark_orb_r[i])
			if d >= 1.0:
				continue
			var f: float = 1.0 - d
			e = maxf(e, f * f * (3.0 - 2.0 * f))
		return e

	func _dither(p: Vector2) -> float:
		return float(_DITHER4[(int(p.y) & 3) * 4 + (int(p.x) & 3)])

	## Whether a point in drawn galaxy space may hold a static pixel.
	##
	## The live layer owns the black hole's neighbourhood outright and fades in
	## across a band on the way out of it, so everything cached has to fade out
	## across the same band or the handover shows as a ring. `t` is the pixel's
	## own random number, which is what makes that fade dithered rather than a
	## hard edge. The four original field passes each inline this; everything
	## added since calls it.
	## Whether a piece of static material — nebula, dust lane, remnant — may sit
	## here. The nebulae, lanes and remnants go through this; the stars, arms and
	## bulge go through the same two rules inline.
	##
	## It was still using a fixed blend band from before the core was rewritten,
	## and it had no test against the hole at all. That is why the disc lane ran
	## straight across the middle of an edge-on galaxy: it is dust rather than
	## stars, so it never met either of the rules the stars were following, and
	## sat frozen among the orbiting field with a slice of it inside the hole.
	func _static_ok(p: Vector2, t: float) -> bool:
		# Round, in drawn space: nothing is behind the hole.
		if p.length() < _shadow_r():
			return false
		# And round, in drawn space: the cached field only keeps what the live
		# layer is not already carrying, and "near the hole" means near it on
		# screen rather than near it in the galaxy's own flattened coordinates.
		return t >= _own_at(p.length(), _core_clear())

	## Hand a piece of material to the live layer instead of dropping it.
	func _to_core(p: Vector2, col: Color, size: int) -> void:
		_core_rad.append(p.length())
		_core_ang.append(atan2(p.y, p.x))
		_core_col.append(col)
		_core_size.append(size)

	## What colour the gas around here is, taken from the nearest system.
	##
	## This is the art direction's rule about the void carrying region
	## signatures, applied to the only thing on the chart big enough to carry a
	## wash: a cloud sitting in Korvan space glows rusty amber, one on a
	## migration route glows teal, and the Core's neighbourhood glows red. So the
	## sky tells you whose space you are looking at before you point at anything.
	func _region_tint(at: Vector2) -> Color:
		var best := INF
		var col := Color("#3a4a5c")
		for n in Run.map:
			var node: MapGen.MapNode = n
			var d: float = (_polar(node) - at).length_squared()
			if d < best:
				best = d
				col = MapGen.star_colour(node)
		return col

	## Emission gas is lit from inside by the stars forming in it and runs
	## H-alpha rose; reflection gas is only catching light from outside and runs
	## blue. Neither is used neat — each is dragged part of the way toward the
	## local region colour, so a cloud says where it is as well as what it is.
	const _NEB_EMIT := Color("#b8506a")
	const _NEB_REFLECT := Color("#4f74c0")

	## One four-step ramp for one tone of one cloud: fringe, low, body, and a
	## lit core that only emission gas gets.
	##
	## Clouds are built from three of these at once rather than one, because a
	## single ramp is what makes a nebula read as a splotch — a shape filled in.
	## Real gas is not one temperature: it is patches of different ionisation
	## sitting against each other, and that is most of what gives a cloud its
	## interior. The variants stay NEAR each other on purpose — a few hundredths
	## of a turn of hue, a few percent of saturation. Push them further apart and
	## the cloud stops being one object.
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

	## Nebulae, as the art direction specifies them: layered translucent masses,
	## dithered edges, coloured per region.
	##
	## Appended BEFORE the arms so arm stars draw in front of them. Gas you can
	## see stars through is gas; gas that occludes them is a sticker laid over
	## the galaxy. The dark half of the same material is a separate pass that
	## runs AFTER the arms, because a dust lane only reads as a lane when it
	## hides the stars behind it.
	## How far out a planetary's gas reaches at this angle, as a multiple of its
	## nominal radius. Build-time only, so it can afford to be readable.
	func _pn_reach(kind: int, a: float) -> float:
		match kind:
			NebulaField.Shape.BIPOLAR:
				# Pinched at the waist and drawn far out along the axis. A dense
				# torus round the star's equator blocks the wind, so it escapes
				# through the poles instead and the shell comes out an hourglass
				# rather than a ball.
				return 0.30 + 0.98 * pow(absf(sin(a)), 0.72)
			NebulaField.Shape.ANSAE:
				# A ring with a knot on either side, where a jet ran into the
				# gas it was ploughing through and stalled. The power keeps the
				# knots tight — anything gentler smears them into an oval.
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
		# WHERE the clouds are is NebulaField's answer, not this function's. The
		# sector screen has to know whether the system you are in sits inside
		# one, and two copies of the placement would agree only until somebody
		# adjusted one of them. How a cloud is drawn stays here.
		var field := NebulaField.clouds()
		if field.is_empty():
			return
		for k in field.size():
			var cloud: NebulaField.Cloud = field[k]
			var centre := cloud.pos * r_max
			var rad := cloud.radius * r_max
			var emission: bool = cloud.emission
			# A stream per cloud, so the detail below cannot shift the placement
			# of the next one — which is what made the positions impossible to
			# reproduce anywhere else.
			_seed_rng(90210 + k * 7919)
			# Weighted toward the gas rather than the region: region colours are
			# chrome, chosen to sit quietly behind an icon, and a cloud built out
			# of one at full strength comes out the colour of the panel border.
			# The region pulls the hue over; it does not set it.
			# The kind decides the hue and the region pulls it over — a
			# planetary is oxygen green wherever it is, but a green one sitting
			# in Korvan space leans amber.
			# A shell keeps far more of its own colour than a diffuse cloud
			# does. The region tint is chrome — it exists so gas sits quietly
			# behind an icon — and at 0.68 it was pulling the planetary's
			# oxygen green and the remnant's filament teal to within a few
			# points of each other, which is most of why the two were hard to
			# tell apart. A shell is a bright, compact, high-contrast object;
			# it can afford to be its own colour.
			var pull: float = 0.88 if cloud.hollow > 0.0 else 0.68
			var base: Color = _region_tint(centre).lerp(cloud.base_colour(), pull)
			# Pulled back off full saturation, and well down in value. Straight
			# H-alpha rose came out magenta beside a palette that has no magenta
			# in it anywhere, and at full brightness the cloud sat at the same
			# value as the brightest stars in the arms — so the arms disappeared
			# into it. Gas is lit by the stars in it. It cannot outshine them.
			base = Color.from_hsv(base.h, base.s * 0.82, base.v * 0.72)

			# Three near-tones. Hue runs anticlockwise from rose into red-orange
			# and clockwise into violet, and from blue into cyan and into
			# indigo — so an emission cloud has a hotter and a cooler half and a
			# reflection cloud has a teal side and a purple one. Which is what
			# the real objects do, and it costs three arrays per cloud.
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
			# The tone field's frequency is scaled to the cloud, so a small
			# cloud gets the same couple of patches across it as a large one.
			# Fixed frequencies gave every small cloud a single flat tone and
			# left only the landmark looking like it had gas in it.
			var tf: float = 5.0 / maxf(1.0, rad)
			# The highest pixel this cloud manages to place, for the label.
			var top := 0.0
			# Enough samples that the blocks overlap through the middle and only
			# separate out at the fringe, which is the point at which a scatter
			# of dots stops reading as dots. The first pass ran at a third of
			# this and the clouds were invisible underneath their own labels.
			# Raised with the block size halved: a quarter of the area per pixel
			# needs more pixels to read as the same body of gas, and the wash
			# lives in the static arrays so it costs a rect apiece and nothing
			# to derive.
			var px := clampi(int(rad * rad * 0.62), 1200, 12000)
			if cloud.kind == NebulaField.Kind.DARK:
				# Denser, because a dark cloud has to actually obscure. It is
				# drawn from the same wash as the rest and simply dark, which is
				# how the dust lanes already work.
				px = int(float(px) * 1.5)
			elif cloud.hollow > 0.0:
				# A shell puts every pixel it has into a thin annulus rather
				# than spreading them through a volume, so it needs fewer than
				# a solid cloud of the same radius — but a planetary is also
				# the smallest object here by a distance, and the budget goes
				# with the SQUARE of the radius. Without a bump it was getting
				# about a tenth of the pixels of its neighbours and came out as
				# a faint smudge.
				# The remnant spends its budget over a much wider, fainter band
				# than the planetary and throws most of it away again at the
				# arc gaps, so it needs the larger share despite being the
				# larger object. The planetary now fills its interior as well
				# as its rim and wants enough left for both.
				px = int(float(px) * (4.0 if cloud.kind == NebulaField.Kind.PLANETARY else 3.4))
			# lobes.size(), NOT a literal 3. A planetary and a remnant are gas
			# thrown outward from a single point, so NebulaField gives them ONE
			# centred lobe — and this loop was indexing three of them. Two
			# thirds of every shell's pixels were read out of bounds: radius
			# zero, offset zero, the whole budget piled onto the exact centre,
			# where the hollow test then threw it away. That is why a supernova
			# remnant drew as an empty circle with a few strays in it.
			var nl := lobes.size()
			for i in px:
				var lobe := i % nl
				var lr: float = lobe_r[lobe]
				var local: Vector2
				var d := 0.0
				if cloud.hollow > 0.0:
					var remnant: bool = cloud.kind == NebulaField.Kind.REMNANT
					# A shell, sampled AS a shell. The wall used to be carved
					# out of a solid cloud by remapping the density falloff,
					# which had two problems: almost every sample fell outside
					# the band and was discarded, and because the falloff is
					# smoothstepped, the surviving wall landed at about a third
					# of the radius — a small faint ring adrift inside a large
					# boundary circle, with nothing between the two.
					#
					# Placing samples in the wall directly costs nothing, wastes
					# nothing, and puts the gas where the hover outline is.
					var wall: float = NebulaField.EXTENT * 0.80
					var th: float = wall * (1.0 - cloud.hollow) * 0.7
					if remnant:
						# Pulled in and spread wide. A remnant is thousands of
						# years past the explosion: the front has broken up,
						# slowed unevenly and begun mixing back into the medium
						# it swept. It is not a shell so much as a REGION, and
						# smearing it over half its own radius is what stops it
						# reading as a drawn ring. The centre comes in to match,
						# so the gas still mostly sits inside the outline.
						wall = NebulaField.EXTENT * 0.64
						th = wall * 0.46
					# Two rolls summed: dense along the wall, thinning to either
					# side of it. One roll would give a band with hard edges.
					var off: float = (_rnd() + _rnd() - 1.0) * th
					var a2: float = _rnd() * TAU
					var u: float = (wall + off) * lr
					# Whether this sample is interior fill rather than wall, in
					# which case its brightness is already decided below and
					# must not be recomputed from the wall falloff.
					var filled := false
					if remnant:
						# Ragged, and incomplete. A shock front does not expand
						# into a vacuum — it ploughs into gas that is lumpy, so
						# it runs ahead where the medium is thin and stalls
						# where it is thick. Three harmonics wobble the wall,
						# and a slower one takes whole arcs of it away, which is
						# what makes a remnant read as something torn rather
						# than something drawn.
						var wob: float = sin(a2 * 3.0 + twist_k) * 0.36 \
							+ sin(a2 * 7.0 - twist_k * 2.1) * 0.21 \
							+ sin(a2 * 13.0 + twist_k * 0.7) * 0.13
						u += wob * th * 1.5 * lr
						# Most of it is simply gone. What survives of an old
						# remnant is a few bright ropes and a haze where the
						# rest used to be, so the thin arcs are dropped outright
						# rather than merely dimmed.
						var arc: float = 0.16 + 0.66 * maxf(0.0,
							sin(a2 * 2.0 + twist_k * 1.3))
						if _rnd() > arc:
							continue
						local = lobes[lobe] \
							+ Vector2(cos(a2) * u, sin(a2) * u * 0.82)
					elif _rnd() < 0.44:
						# The inside of a planetary GLOWS. The star that shed
						# the envelope is still sitting in the middle of it and
						# still ionising it, so the interior is not empty — it
						# holds the same oxygen light as the rim, only fainter
						# for having less gas along the line of sight.
						#
						# Drawing it as a bare ring was the single thing that
						# made these read as remnants: a hollow outline is what
						# is left when something has gone, and this one has not
						# gone anywhere.
						filled = true
						var ai: float = _rnd() * TAU
						var ui: float = pow(_rnd(), 0.55) * wall * lr 							* _pn_reach(cloud.shape, ai)
						local = lobes[lobe] + Vector2(cos(ai) * ui,
							sin(ai) * ui * _pn_squash(cloud.shape)) 							.rotated(twist_k * 0.5)
						# Brightest just inside the rim, fading to the middle —
						# that is line-of-sight depth through a shell, where you
						# look through the most gas at the edge.
						var fi: float = ui / maxf(0.001, wall * lr * _pn_reach(cloud.shape, ai))
						d = 0.17 + 0.38 * fi * fi
					else:
						# A planetary is one star's envelope, thrown off in one
						# go and seen at whatever angle it happens to present:
						# smooth, unbroken, and elliptical because it is tilted
						# rather than because it is deformed. Where the remnant
						# is torn, this is intact — that contrast is the whole
						# distinction between the two.
						var pu: float = u * _pn_reach(cloud.shape, a2)
						local = lobes[lobe] + Vector2(cos(a2) * pu,
							sin(a2) * pu * _pn_squash(cloud.shape)) 							.rotated(twist_k * 0.5)
					if not filled:
						d = clampf(1.0 - absf(off) / maxf(0.001, th), 0.0, 1.0)
						d = d * d * (3.0 - 2.0 * d)
						if remnant:
							# And faint. Held below the top brightness step on
							# purpose: nothing about a dispersing remnant should
							# compete with a planetary, which is a live shell
							# around a star that is still lighting it.
							d *= 0.58
						else:
							# Squared again: a planetary has a sharp inner rim.
							# It is a single shell with an edge, not a front
							# that has been smearing outward for ten thousand
							# years.
							d = d * d * (3.0 - 2.0 * d)
				else:
					var rr: float = pow(_rnd(), 0.8) * lr
					var a2: float = _rnd() * TAU
					local = lobes[lobe] \
						+ Vector2(cos(a2) * rr, sin(a2) * rr * 0.82)

					# Density is the STRONGEST lobe at this point, not the sum,
					# so overlaps brighten rather than merely doubling the dot
					# count.
					for m in nl:
						d = maxf(d, 1.0 - minf(1.0,
							(local - lobes[m]).length() / maxf(1.0, lobe_r[m])))
					d = d * d * (3.0 - 2.0 * d)
				# Filaments. Gas is ropey, not spherical, and two sines that do
				# not divide into each other say so well enough at this size.
				var fil: float = 0.5 + 0.5 * sin(local.x * 0.085 + twist_k) \
					* sin(local.y * 0.11 - twist_k * 1.7)
				# A remnant is filaments almost to the exclusion of anything
				# else — the Veil is a bundle of ropes, not a wall — so it takes
				# far more of its brightness from this than a smooth cloud does.
				if cloud.kind == NebulaField.Kind.REMNANT:
					d *= 0.18 + 0.82 * fil
				else:
					d *= 0.52 + 0.48 * fil

				var world := centre + local
				var dith := _dither(world)
				if d < dith:
					continue
				var wash_moves := not _static_ok(world, _rnd())
				# Four steps, with the dither offsetting the boundaries between
				# them as well as the outer edge — so the ramp breaks up too and
				# the cloud never shows a contour line.
				var lvl := d - dith * 0.18
				var step := 0
				if lvl > 0.60 and emission:
					step = 3
				elif lvl > 0.42:
					step = 2
				elif lvl > 0.24:
					step = 1
				# Which tone, from a field at a much lower frequency than the
				# filaments — so brightness and temperature vary independently
				# and the cloud does not come out banded.
				# Three terms, none of them a multiple of another. Two put the
				# tones in clean diagonal bands across the cloud, which reads as
				# two clouds overlapping rather than as one with structure.
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
				# Every tier is a block, the bright ones included. Drawing the
				# core at full resolution and the wash at a quarter of it was
				# the obvious economy and it erased the cloud's whole interior:
				# single pixels of the bright steps disappeared between blocks
				# of the dim ones, so what was left was a flat even mat with no
				# middle to it. A nebula has to have a middle.
				_star_big.append(2)
				# Never flagged dim. The dim tier is dropped mid-drag, and a
				# star thinning out while you pan is invisible where a coloured
				# mass blinking out of existence is not.
				_star_dim.append(0)

			# The stars that lit it. Only a cloud that is actively forming them
			# gets them: a planetary is one dying star's envelope, a remnant is
			# what is left after the star went, and a dark cloud has nothing
			# lighting it at all.
			# The star that shed it, still sitting in the middle. A planetary is
			# the one nebula with an obvious source, and it is what makes the
			# ring read as a ring around something.
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

	## Dust lanes, and the dark globules inside the clouds. The same material as
	## a nebula with nothing lighting it, so it is drawn by taking pixels away
	## from the galaxy rather than adding them — which is the only reason this
	## pass has to run after the arms rather than with the nebulae.
	func _build_dust(r_max: float) -> void:
		var g := _g()
		var gas: float = float(g.get("gas", 1.0))
		var sq := _squash()
		var arms := _arms()
		_seed_rng(31337)
		# No arms, no density wave, nothing to pile the dust into a lane — and a
		# galaxy that has run out of gas has nothing to make one out of either.
		# The globules below still run: they belong to the clouds, not to the
		# arms, and a barless ring galaxy has clouds without having lanes.
		#
		# A lane runs along the INNER edge of an arm, which is where the wave
		# piles material up, and it is why a spiral arm has a bright side and a
		# dark side instead of fading off symmetrically both ways.
		var n := 0 if (int(g.arms) <= 0 or gas < 0.35) \
			else int(2800.0 * clampf(gas, 0.0, 1.6))
		for i in n:
			var rn: float = 0.18 + pow(_rnd(), 0.8) * 0.78
			# Narrow. The arms themselves are drawn wide — half a radian of
			# scatter either side of the ridge — so a lane spread over the same
			# angle just thins the arm evenly instead of cutting a line in it.
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
			# The gas size class, like the nebula wash and for both of the same
			# reasons: a lane is made of the stars it hides, so one dark block
			# over four of them beats four dark pixels — and a lane that broke
			# up into dashes on the way in would stop being a lane.
			_star_big.append(2)
			# Emphatically not dim. Dropping these during a drag would uncover
			# the stars underneath, so the lanes would open up every time you
			# moved the chart — the one change the eye is guaranteed to catch.
			_star_dim.append(0)

		# Globules: the cold cores inside a cloud, where the next generation is
		# already collapsing. Without them a nebula is an even wash.
		for k in _neb_pos.size():
			var c: Vector2 = _neb_pos[k]
			# The drawn extent, near enough: `top` is measured on the vertical,
			# which the sampling foreshortens, and a globule wants to sit well
			# inside the cloud rather than out on its edge.
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

	## Globular clusters. Old, dense, and out of the plane — which is the whole
	## point of drawing them. Everything else on this chart lies in the disc, so
	## a knot of stars plainly sitting above it is the cheapest thing available
	## that says the galaxy is a solid object rather than a picture of a spiral.
	##
	## Deliberately NOT squashed: the halo is a sphere, and a sphere in
	## projection is a circle however flattened the disc in front of it is.
	func _build_clusters(r_max: float) -> void:
		_seed_rng(60613)
		var count := 11 + int(_rnd() * 9.0)
		for k in count:
			# Concentrated toward the middle but reaching well past the rim. The
			# outermost of these are barely bound to anything.
			var rr: float = (0.22 + pow(_rnd(), 1.9) * 1.25) * r_max
			var a: float = _rnd() * TAU
			var centre := Vector2(cos(a), sin(a)) * rr
			var rad: float = r_max * (0.008 + _rnd() * 0.014)
			var n := 44 + int(_rnd() * 56.0)
			for m in n:
				# pow 2.6 is what makes it a cluster and not a smudge: nearly
				# all of it inside a fifth of the radius, a scattering outside.
				var d: float = pow(_rnd(), 2.6) * rad
				var a2: float = _rnd() * TAU
				var p := centre + Vector2(cos(a2), sin(a2) * 0.92) * d
				var _moves_cluster := not _static_ok(p, _rnd())
				var t := _rnd()
				# Globulars are the brightest small thing in the disc, so one
				# sitting behind a dark cloud is the most obvious way for the
				# cloud to fail to look dark.
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

	## The flashing star at each pulsar.
	##
	## This used to draw a small shock shell around every pulsar as well. That
	## shell is now redundant and was actively misleading: a pulsar only exists
	## inside a supernova remnant or a planetary nebula, and both of those are
	## already drawn — as hollow clouds, at their real size, by the nebula pass.
	## Ringing the system with a second, smaller shell of its own put two shock
	## fronts on the chart for one explosion.
	##
	## So all that is left is the star itself, which the live layer flashes.
	func _build_remnants(r_max: float) -> void:
		_pulsar = PackedVector2Array()
		if not Run.map.is_empty():
			for nd in Run.map:
				var node: MapGen.MapNode = nd
				if node.type == MapGen.NodeType.PULSAR:
					_pulsar.append(_polar(node))
			return

		# No map — the launcher. Pulsars are placed by MapGen, which marks a
		# SYSTEM inside a remnant as one, so with no systems there were no
		# pulsars and the title screen's remnants sat there with nothing at the
		# centre. A supernova remnant without its neutron star is the one thing
		# in this sky that is actually wrong rather than merely absent.
		#
		# Straight from the cloud instead: one per REMNANT, at its centre, which
		# is where the star that threw the shell has to be. Planetary nebulae get
		# nothing, same as in a real run — they are low-mass envelopes and leave
		# a white dwarf.
		for raw in NebulaField.clouds():
			var cloud: NebulaField.Cloud = raw
			if cloud.kind == NebulaField.Kind.REMNANT:
				_pulsar.append(cloud.pos * r_max)

	## Lay out the orbiting core. Runs with the rest of the build, because it
	## depends on how many stars the cleared region swallowed and that number is
	## only known once the field has been built.
	## The accretion disc, laid out once.
	##
	## Every one of these was recomputed sixty times a second for five thousand
	## two hundred particles, and none of it changes: the hashes are fixed per
	## index, the radius is a pow of a hash, the angular velocity is a function
	## of that radius, and the radial light profile is an exp of it. That is
	## three GDScript calls plus a pow and an exp per particle per frame —
	## around thirty thousand function calls a frame — to arrive at exactly the
	## numbers of the frame before.
	##
	## What actually varies with time is the ANGLE, and what follows from it. So
	## the disc is laid out here and the draw does trigonometry and nothing else.
	var _disc_r: PackedFloat32Array = PackedFloat32Array()
	var _disc_a: PackedFloat32Array = PackedFloat32Array()
	var _disc_om: PackedFloat32Array = PackedFloat32Array()
	var _disc_rad: PackedFloat32Array = PackedFloat32Array()
	var _disc_b: PackedFloat32Array = PackedFloat32Array()
	## Phase offsets, so each particle breathes and churns out of step.
	var _disc_bp: PackedFloat32Array = PackedFloat32Array()
	var _disc_c1: PackedFloat32Array = PackedFloat32Array()
	var _disc_c2: PackedFloat32Array = PackedFloat32Array()

	## The density wave's sample set, laid out once.
	##
	## The wave walks a fixed stride through the star field, so it visits the
	## same indices every frame and asked the same questions about each of them
	## every frame: an atan2 for the angle, a length for the radius, a colour
	## chosen from that radius, and an extinction lookup. None of it moves. Only
	## the phase advances.
	##
	## So the samples are resolved here down to a position, a phase offset and a
	## finished colour, and the draw is one sine and a rect.
	var _wv_pos: PackedVector2Array = PackedVector2Array()
	var _wv_ph: PackedFloat32Array = PackedFloat32Array()
	var _wv_col: PackedColorArray = PackedColorArray()

	func _build_wave() -> void:
		_wv_pos = PackedVector2Array()
		_wv_ph = PackedFloat32Array()
		_wv_col = PackedColorArray()
		var r_max: float = maxf(1.0, _radius() * DISC)
		var lit_step := maxi(1, _star_pos.size() / 2600)
		for i in range(0, _star_pos.size(), lit_step):
			# STARS only. _star_pos holds the nebula wash as well — gas and
			# stars share the array because they share the cache — and this
			# sampling took whatever it landed on. So the wave swept through the
			# clouds lighting the gas a few blocks at a time, which on a DARK
			# nebula is a contradiction in terms: the one kind of cloud whose
			# entire definition is that it does not emit was the one visibly
			# shimmering. Size 2 is the gas block, the same convention the
			# orbiting material uses.
			if _star_big[i] == 2:
				continue
			var sp := _star_pos[i]
			var ang := atan2(sp.y, sp.x)
			var rn: float = sp.length() / r_max
			var col := Color("#43566d")
			if rn < 0.32:
				col = Color("#8a6134")
			elif rn < 0.62:
				col = Color("#5f7590")
			# A star behind dust does not brighten to full when the wave reaches
			# it. The static field dims these where it places them, but the wave
			# OVERWRITES the colour rather than scaling it, so without this every
			# pass threw that dimming away and lit the survivors inside a dark
			# cloud as though nothing were in front of them.
			if not _dark_r.is_empty():
				var wex := _extinct(sp)
				if wex > 0.02:
					col = col.darkened(wex * 0.85)
			_wv_pos.append(sp)
			# Two-armed, and wound: the wave lags with radius exactly as the arms
			# do, so it travels along them rather than sweeping across them.
			_wv_ph.append(ang * 2.0 - rn * 5.0)
			_wv_col.append(col)

	func _build_disc() -> void:
		_disc_r = PackedFloat32Array()
		_disc_a = PackedFloat32Array()
		_disc_om = PackedFloat32Array()
		_disc_rad = PackedFloat32Array()
		_disc_b = PackedFloat32Array()
		_disc_bp = PackedFloat32Array()
		_disc_c1 = PackedFloat32Array()
		_disc_c2 = PackedFloat32Array()
		var sh := _shadow_r()
		var clear := _core_clear()
		var d_in := sh * 1.02
		var d_out := sh * 3.6
		var span := d_out - d_in
		for i in 5200:
			var dv := _frac(_hash2(i, 3, 8675))
			var da := _frac(_hash2(i, 5, 8675))
			var db := _frac(_hash2(i, 11, 8675))
			var x: float = pow(dv, 0.72)
			var dr: float = d_in + x * span
			var off: float = (x - 0.16) / 0.34
			_disc_r.append(dr)
			_disc_a.append(da * TAU)
			_disc_om.append(_orbital_omega(dr, sh, clear))
			_disc_rad.append(exp(-off * off))
			_disc_b.append(db)
			_disc_bp.append(da * 19.0)
			_disc_c1.append(dv * 11.0)
			_disc_c2.append(dv * 23.0)

	func _build_orbits() -> void:
		_orb_r = PackedFloat32Array()
		_orb_a = PackedFloat32Array()
		_orb_w = PackedFloat32Array()
		_orb_col = PackedColorArray()
		_orb_size = PackedByteArray()
		_orb_dark = PackedByteArray()

		var sh := _shadow_r()
		var clear := _core_clear()
		var sq_o := _squash()
		# One in N when the core swallowed more than the frame can carry. Taking
		# a slice keeps the radial spread and the colour mix of the whole set;
		# taking the first N would have kept whichever layer happened to be built
		# first and lost the others entirely.
		var total := _core_rad.size()
		if total == 0:
			return
		var stride := maxi(1, int(ceil(float(total) / 7000.0)))
		var i := 0
		while i < total:
			# (the walk below is by index; the angle now comes from the star
			# itself, so a strided walk can no longer bias the angular spread)
			var orad: float = _core_rad[i]
			# Nothing may start inside the hole; where it goes from there is
			# checked per frame, since that depends on its orbit.
			if orad > sh * 0.5:
				_orb_r.append(orad)
				_orb_a.append(_core_ang[i])
				_orb_w.append(_orbital_omega(orad, sh, clear))
				_orb_col.append(_core_col[i])
				_orb_size.append(_core_size[i])
				# The path this traces is an ellipse between orad*sq and orad,
				# so a dark lobe can only ever be in the way if its own radial
				# band overlaps that. Almost none do.
				var can_dark := 0
				for k in _dark_orb_r.size():
					var dl: float = _dark_orb_c[k].length()
					if orad >= dl - _dark_orb_r[k] and orad * sq_o <= dl + _dark_orb_r[k]:
						can_dark = 1
						break
				_orb_dark.append(can_dark)
			i += stride

	## The living part of the sky. Everything here is derived from the clock and
	## from data the backdrop already built, so it costs a few hundred pixels a
	## frame rather than a repaint of the galaxy.
	func draw_anim(ci: CanvasItem) -> void:
		if _star_pos.is_empty():
			return
		var t := float(Time.get_ticks_msec()) * 0.001
		var c := size * 0.5 + pan
		var w := size.x
		var h := size.y
		var one := Vector2.ONE

		# --- stars catching the light. Only a slice of the field is considered,
		# and only the few currently at the top of their cycle are drawn, so a
		# star brightens and fades rather than blinking on and off.
		# Slow, and narrow at the top. The first pass ran nearly five times this
		# rate with a low threshold, so a couple of hundred stars were lit at any
		# moment and each was on for well under a second — which is a Christmas
		# tree, not a sky. Now a few dozen are lit, they take a couple of seconds
		# to come up and go down, and they ramp through three brightnesses so
		# they fade rather than switch.
		var step := maxi(1, _star_pos.size() / 420)
		for i in range(0, _star_pos.size(), step):
			var phase := float((i * 2654435761) % 6283) * 0.001
			var pulse := sin(t * 0.15 + phase)
			if pulse < 0.955:
				continue
			var q := c + _star_pos[i] * zoom
			if q.x < 0.0 or q.y < 0.0 or q.x > w or q.y > h:
				continue
			var lit := Color("#8fa3ba")
			if pulse > 0.995:
				lit = Color("#f2f7ff")
			elif pulse > 0.98:
				lit = Color("#c9d8ea")
			ci.draw_rect(Rect2(q.round(), one), lit, true)

		# --- a density wave, turning through the disc.
		#
		# The first attempt at this drifted loose motes along orbits, and it was
		# wrong for a reason worth writing down: forty thousand stars behind them
		# are static, so anything that visibly travels reads as the background
		# sliding past a frozen galaxy. A galaxy takes a couple of hundred
		# million years to turn — at this timescale it IS still.
		#
		# So nothing moves. A brightness wave sweeps around the disc instead,
		# lighting the existing stars a few at a time. That is closer to what a
		# spiral arm actually is — a density wave that stars pass through and
		# brighten in, not a solid thing that rotates — and because it only ever
		# recolours pixels that are already there, it cannot contradict them.
		for i in _wv_ph.size():
			var q := c + _wv_pos[i] * zoom
			if q.x < 0.0 or q.y < 0.0 or q.x > w or q.y > h:
				continue
			if sin(_wv_ph[i] + t * 0.085) < 0.93:
				continue
			ci.draw_rect(Rect2(q.round(), one), _wv_col[i], true)

		# --- the inner stars, in orbit.
		#
		# This is the one place fast motion is honest. A galaxy takes a couple of
		# hundred million years to turn, which is why the disc is static — but
		# stars this close to a supermassive black hole go round in years. The
		# backdrop leaves this region empty precisely so these can move without a
		# static twin sitting at the same radius.
		var sh := _shadow_r()
		var clear := _core_clear()
		# Nearly round, whatever the galaxy is. On an edge-on disc these orbits
		# were squashed to a horizontal sliver, so every star slid ALONG the
		# band and the band itself never changed shape — the core read as frozen
		# while every particle in it was moving. Real nuclear clusters are
		# spheroidal anyway: the disc is flat, the knot around the hole is not,
		# and drawing that difference is what makes the motion visible.
		# Round, to match how ownership is measured. The cluster around a black
		# hole is spheroidal in any case: the disc is flat, the knot at its
		# centre is not.
		var sq := 1.0
		# The shadow, in drawn pixels. A star is behind the hole when it is
		# inside this, and that depends on where it has orbited to — which is why
		# it cannot be decided when the orbits are laid out.
		var hole_px := sh * zoom
		# Same block size the static wash uses, so orbiting gas and still gas
		# are the same material.
		var gk_o: float = clampf(round(zoom * 0.75), 1.0, 2.0)
		var hole_sq := hole_px * hole_px
		for i in _orb_r.size():
			var oa: float = _orb_a[i] - t * _orb_w[i]
			var orad: float = _orb_r[i]
			var oc := cos(oa)
			var osn := sin(oa) * sq
			var off := Vector2(oc, osn) * orad * zoom
			# Squared. This is asked of every orbiting particle every frame and
			# a square root is the wrong price for a comparison.
			if off.length_squared() < hole_sq:
				continue
			var q2 := c + off
			if q2.x < 0.0 or q2.y < 0.0 or q2.x > w or q2.y > h:
				continue
			# Gas that came from the cloud goes back as a block, at the same
			# zoom-scaled size the static wash uses, or an orbiting nebula
			# dissolves into single pixels the moment it starts moving.
			var osz := one
			match _orb_size[i]:
				1: osz = Vector2(2, 2)
				2: osz = Vector2(gk_o, gk_o)
			var ocol: Color = _orb_col[i]
			# A dark cloud in front of this. Everything static was tested for
			# occultation where it was placed, but orbiting material moves, so
			# whether a cloud is in front of it is a question with a new answer
			# every frame — and left untested, the one population that moves
			# swept through the cloud several times a second and lit it up on
			# the way past. A cloud that brightens when something passes behind
			# it is the exact opposite of dust.
			#
			# Asked only of particles whose orbit can actually reach a dark
			# lobe, which is decided once from their radius. Almost none can, so
			# almost none pay for the call.
			#
			# Dimmed rather than dropped: a particle winking out as it crossed
			# the boundary and back in on the far side would be a worse artifact
			# than the one being fixed.
			if _orb_dark[i] == 1:
				var oex := _extinct_orbit(Vector2(oc, osn) * orad)
				if oex > 0.02:
					ocol = ocol.darkened(oex * 0.88)
			ci.draw_rect(Rect2(q2.round(), osz), ocol, true)

		# --- the accretion disc, after M87*.
		#
		# The reference photograph is a THICK, CONTINUOUS annulus that fades
		# smoothly inward to the shadow and outward to nothing, with one limb
		# several times brighter than the other. Ours was a thin scatter spread
		# over a wide radius, which reads as a sprinkle of embers rather than as
		# a body of glowing matter — the difference is not the colours, it is
		# that the real one has no gaps.
		#
		# So: a narrow band, packed hard enough to be solid, with a smooth radial
		# falloff either side of a peak just outside the photon ring. Brightness
		# is the product of that profile and the Doppler beam, and the ramp runs
		# the length of the reference colour bar — black through deep red and
		# orange to white.
		for i in _disc_r.size():
			var ang2: float = _disc_a[i] - t * _disc_om[i]
			# The beam first, then cull. Churn can only push heat up by 14%, so
			# an upper bound built from it is enough to throw a particle away
			# before paying for the two sines that compute it exactly — and a
			# good half of the disc is thrown away every frame.
			var co := cos(ang2)
			var beam: float = clampf(0.20 + 0.80 * co, 0.0, 1.0)
			var radial: float = _disc_rad[i]
			var db: float = _disc_b[i]
			var hi: float = radial * beam * 1.14
			if hi < 0.055 or db > 0.55 + hi * 0.45:
				continue
			var churn: float = 0.88 + 0.14 * sin(ang2 * 4.0 - t * 0.55 + _disc_c1[i]) + 0.12 * sin(ang2 * 7.0 + t * 0.31 + _disc_c2[i])
			var heat: float = radial * beam * churn
			if heat < 0.055 or db > 0.55 + heat * 0.45:
				continue
			var dr: float = _disc_r[i] * (1.0 + 0.06 * sin(t * 0.42 + _disc_bp[i]))
			# sin from the cos already in hand. One sqrt and a quadrant test
			# against one more transcendental, for every particle that survives,
			# every frame.
			var si := sqrt(maxf(0.0, 1.0 - co * co))
			if fposmod(ang2, TAU) > PI:
				si = -si
			var q3 := c + Vector2(co, si) * dr * zoom
			if q3.x < 0.0 or q3.y < 0.0 or q3.x > w or q3.y > h:
				continue

			var dcol := Color("#3a1206")
			if heat > 0.80:
				dcol = Color("#ffffff")
			elif heat > 0.66:
				dcol = Color("#fff2cd")
			elif heat > 0.52:
				dcol = Color("#ffd070")
			elif heat > 0.39:
				dcol = Color("#f89b2c")
			elif heat > 0.27:
				dcol = Color("#d2661c")
			elif heat > 0.16:
				dcol = Color("#9c3a12")
			elif heat > 0.09:
				dcol = Color("#66200b")
			ci.draw_rect(Rect2(q3.round(), one), dcol, true)

		# --- pulsars. What a supernova leaves turning at the middle of its own
		# wreckage. Everything else on this chart drifts, churns or fades; these
		# are the only thing on it that keeps time, and each one runs at its own
		# rate so they never fall into step with each other.
		# Never hidden, and never filtered. A neutron star turning eleven times
		# a second is an OBJECT — it is out there whether or not you have
		# charted the system around it, and it would go on sweeping if the
		# chart were switched off entirely. Hiding the systems hides the
		# interface drawn over the galaxy; it does not empty the galaxy.
		#
		# So the icon obeys the toggles and the pulse does not. That split is
		# the whole rule: the glyph is a claim about somewhere you can go, and
		# the flash is a thing that is simply happening.
		for i in _pulsar.size():
			var period: float = 1.1 + float(i) * 0.43
			var ph: float = fmod(t, period) / period
			if ph > 0.16:
				continue
			var env: float = 1.0 - ph / 0.16
			var pq := c + _pulsar[i] * zoom
			# Behind the hole is behind the hole. Pulsars are the one thing on
			# the live layer that was not tested against it, so a remnant that
			# happened to sit near the middle blinked straight through.
			if (_pulsar[i] * zoom).length() < sh * zoom:
				continue
			if pq.x < 1.0 or pq.y < 0.0 or pq.x > w - 1.0 or pq.y > h:
				continue
			pq = pq.round()
			ci.draw_rect(Rect2(pq, one),
				Color("#e6fbff") if env > 0.45 else Color("#6fb2c4"), true)
			# A pixel either side at the peak. A pulsar is a lighthouse, and the
			# sweep of the beam is the entire reason it is visible at all.
			if env > 0.55:
				ci.draw_rect(Rect2(pq + Vector2(1, 0), one), Color("#8fd2e0"), true)
				ci.draw_rect(Rect2(pq - Vector2(1, 0), one), Color("#8fd2e0"), true)

		_draw_bursts(ci, t, c, w, h)

	## Gamma-ray bursts: a single pixel arriving brighter than anything else on
	## screen, with a cross of light around it, gone in under a second.
	##
	## Rare on purpose. The whole effect is that you mostly do not see one, and
	## the one you do catch out of the corner of your eye makes the sky feel
	## like somewhere things are still happening.
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
				where = c + _star_pos[clampi(si, 0, _star_pos.size() - 1)] * zoom
			else:
				# Out in the deep field, and it parallaxes with it.
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

	## The repaint. Deep field first, then the galaxy from the cache: a
	## multiply, an add, a bounds check and a rect per star, and no galaxy maths
	## at all.
	## The flat black and the distant galaxies. Everything on this canvas is
	## outside our galaxy and holds still while it turns.
	func draw_deep(ci: CanvasItem) -> void:
		ci.draw_rect(Rect2(Vector2.ZERO, size), Color("#070a10"), true)
		_draw_far_galaxies(ci)

	## The parallax star layers, over the galaxy and equally fixed.
	func draw_halo_layer(ci: CanvasItem) -> void:
		_draw_halo(ci)

	func draw_backdrop(ci: CanvasItem) -> void:
		_build_stars()

		# `_sky_pan`, NOT `pan`: this layer is SLID between repaints rather than
		# repainted, so what it must draw is the view it is currently offset
		# from. The live pan here would double-count the slide. See
		# _repaint_galaxy.
		var c := size * 0.5 + _sky_pan
		# The cull box is MapChart's, GROWN BY THE SLIDE MARGIN. This layer is
		# moved rather than repainted while the view is dragged, so a star
		# within SKY_MARGIN of the edge is off screen now and on screen after
		# the next slide -- it has to be in the draw list already, or the sky
		# grows in from the trailing edge as you pull it.
		var w := size.x + SKY_MARGIN
		var h := size.y + SKY_MARGIN
		var one := Vector2.ONE
		var two := Vector2(2, 2)
		# Gas is the one thing out here that is not made of points, so it is the
		# one thing whose brush grows with the zoom. The field is a fixed cloud
		# of samples: magnify it and the samples separate, which is right for
		# stars — you are resolving them — and wrong for a nebula, which thinned
		# into pink confetti the moment you leaned in. Scaling the block holds
		# the cloud together as a mass instead.
		# Halved. The block still grows with the zoom — a fixed cloud of samples
		# separates into confetti when you magnify it, which is right for stars
		# and wrong for gas — but at 2.6 the blocks were the largest objects on
		# screen by a wide margin and read as tiles rather than as cloud.
		var gk: float = clampf(round(zoom * 0.75), 1.0, 2.0)
		var gas_px := Vector2(gk, gk)
		# Every star, every frame, including while dragging. Halving the density
		# during a drag was cheaper, but a galaxy that visibly dims the moment
		# you touch it is worse than one that repaints a little slower — and
		# since the field became precomputed data the repaint is affordable.
		# Every star, every frame, dragging or not. Thinning the field while the
		# view swept was cheaper and it was the wrong trade: what you notice is
		# not the framerate, it is the galaxy visibly losing stars the moment you
		# touch it. If this needs to get faster it has to get faster without
		# drawing less.
		# Two loops rather than one with a branch in it: this runs 48,000 times a
		# repaint, and the chart — which never turns — should not pay for a test
		# whose answer is always no.
		if is_zero_approx(sky_angle):
			for i in _star_pos.size():
				var q := c + _star_pos[i] * zoom
				if q.x < -SKY_MARGIN or q.y < -SKY_MARGIN or q.x > w or q.y > h:
					continue
				var sz := one
				match _star_big[i]:
					1: sz = two
					2: sz = gas_px
				ci.draw_rect(Rect2(q.round(), sz), _star_col[i], true)
		else:
			# Rotate, THEN round. See set_sky_rotation for why that order is the
			# entire difference between a galaxy and a moiré pattern.
			var ca := cos(sky_angle)
			var sa := sin(sky_angle)
			for i in _star_pos.size():
				var p := _star_pos[i]
				var q := c + Vector2(p.x * ca - p.y * sa, p.x * sa + p.y * ca) * zoom
				if q.x < -SKY_MARGIN or q.y < -SKY_MARGIN or q.x > w or q.y > h:
					continue
				var sz := one
				match _star_big[i]:
					1: sz = two
					2: sz = gas_px
				ci.draw_rect(Rect2(q.round(), sz), _star_col[i], true)

		# --- and the names of the clouds. They are the only landmarks out here
		# that are not somewhere you can go, and naming them is what turns the
		# chart from a graph of a route into a chart of a galaxy. Held back until
		# the view is close enough that they are not stacked on top of each other,
		# and faded in over the same range so they arrive rather than appear.
		if zoom >= 0.85 and not _neb_pos.is_empty():
			var f := UITheme.pixel_font()
			var la: float = clampf((zoom - 0.85) / 0.45, 0.0, 1.0) * 0.55
			# The names carry 80px of text overhang of their own, and that stacks
			# with the slide margin rather than replacing it.
			var nlo := -SKY_MARGIN - 80.0
			var nhi := w + 80.0
			for i in _neb_pos.size():
				var q := c + _neb_pos[i] * zoom
				if q.x < nlo or q.x > nhi or q.y < -SKY_MARGIN or q.y > h:
					continue
				# Nothing is written across the cloud any more. A name printed on
				# every nebula is a label on scenery: it competes with the system
				# names, which are the ones you actually act on, and it is on
				# screen permanently to tell you something you want once. It is
				# a hover tooltip now, like everything else that answers "what
				# is that".
				pass
