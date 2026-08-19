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
var _icons_btn: Button
var _all_btn: Button

var _dest_name: Label
var _dest_class: Label
var _dest_blurb: Label
var _rows: VBoxContainer
var _hint: Label
var _neigh: VBoxContainer
var _jump: Button

## -1 is no selection, which is how the chart opens: the galaxy first, and a
## destination only once you have chosen to look at one.
var _selected: int = -1

func setup() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	Sig.map_changed.connect(_refresh)
	Sig.resources_changed.connect(_refresh)
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
	_icons_btn = Widgets.button("HIDE SYSTEMS", _on_toggle_icons)
	_icons_btn.custom_minimum_size = Vector2(112, 14)
	strip.add_child(_icons_btn)
	# Debug: drop the "visited or reachable" filter and draw the whole map.
	# Useful for looking at generation — whether the shells are spaced sensibly,
	# whether a galaxy rolled something odd — which the play view deliberately
	# hides.
	_all_btn = Widgets.button("SHOW ALL SYSTEMS", _on_toggle_all)
	_all_btn.custom_minimum_size = Vector2(136, 14)
	strip.add_child(_all_btn)
	root.add_child(strip)

	# --- chart | destination
	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 5)
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(mid)

	_chart = MapChart.new()
	_chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chart.node_picked.connect(_on_node_picked)
	_chart.cleared.connect(_on_chart_cleared)
	var chart_wrap := Widgets.panel_with(_chart)
	chart_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_child(chart_wrap)

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
	_dest_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dest_name.custom_minimum_size = Vector2(228, 0)
	right.add_child(_dest_name)
	_dest_class = UITheme.body("", UITheme.THEM, UITheme.FS_SMALL)
	_dest_class.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dest_class.custom_minimum_size = Vector2(228, 0)
	right.add_child(_dest_class)
	_dest_blurb = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	_dest_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dest_blurb.custom_minimum_size = Vector2(228, 0)
	right.add_child(_dest_blurb)
	right.add_child(UITheme.hsep())

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 3)
	right.add_child(_rows)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(spacer)

	_hint = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size = Vector2(228, 0)
	right.add_child(_hint)
	_neigh = VBoxContainer.new()
	_neigh.add_theme_constant_override("separation", 1)
	right.add_child(_neigh)
	_jump = Widgets.button("JUMP", _on_jump)
	_jump.custom_minimum_size = Vector2(0, 24)
	right.add_child(_jump)

	mid.add_child(Widgets.panel_with(right))

	# --- key: icons are only better than labels if you can learn them
	var key := HBoxContainer.new()
	key.add_theme_constant_override("separation", 8)
	key.add_child(UITheme.body("KEY", UITheme.COLD, UITheme.FS_SMALL))
	for pair in [
			[MapGen.NodeType.FIGHT, "FIGHT", UITheme.CHILL],
			[MapGen.NodeType.STATION, "STATION", Color("#8ec8e6")],
			[MapGen.NodeType.EVENT, "EVENT", Color("#b08ad0")],
			[MapGen.NodeType.DERELICT, "DERELICT", Color("#8a6a3a")],
			[MapGen.NodeType.PULSAR, "PULSAR", Color("#8fd2e0")],
			[MapGen.NodeType.GOAL, "CORE", Color("#d4614f")]]:
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 3)
		var g := Glyph.new()
		g.setup(pair[0] as MapGen.NodeType, pair[2] as Color)
		item.add_child(g)
		item.add_child(UITheme.body(pair[1] as String, UITheme.COLD, UITheme.FS_SMALL))
		key.add_child(item)
	root.add_child(key)

func _first_reachable() -> int:
	for idx in Run.node_at().links:
		if Run.can_jump_to(Run.map[idx]):
			return idx
	return -1

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
		if _first_reachable() < 0:
			_dest_name.text = "NOWHERE"
			_dest_class.text = ""
			_dest_blurb.text = "No jump you can afford. The tank is dry."
		else:
			# With nothing selected the panel describes the galaxy itself. It is
			# the one thing on this screen that is always true, and a run should
			# know where it is happening.
			_dest_name.text = Run.galaxy_title.to_upper()
			_dest_class.text = "%s - %s" % [
				Run.galaxy_name, GalaxyGen.type_name(Run.galaxy_kind).to_upper()]
			_dest_blurb.text = GalaxyGen.blurb(Run.galaxy_kind)
		_hint.text = ""
		_jump.disabled = true
		return

	var t: MapGen.MapNode = Run.map[_selected]
	# The name is the place; the classification is what kind of place it is -
	# how built up, how policed, and whose it is, in that order.
	_dest_name.text = MapGen.star_name(t)
	# Galaxy, then the cloud if it is in one, then what kind of place it is —
	# outermost thing first, narrowing to the system. The nebula belongs in this
	# line rather than in the rows below: the rows are facts ABOUT the place,
	# and the cloud is part of its address.
	var addr := "%s - " % Run.galaxy_name
	if t.in_nebula:
		var cl := NebulaField.at(t.gal)
		if cl != null:
			addr += "%s - " % cl.name.to_upper()
	_dest_class.text = addr + MapGen.development_name(t.development).to_upper()
	_dest_blurb.text = MapGen.place_blurb(t)

	_rows.add_child(_row("CONTAINS", _contains(t)))
	# The three axes get their own rows. They are what the place IS, and reading
	# them off a single run-on classification line meant scanning a sentence to
	# answer "how policed is it".
	if t.type == MapGen.NodeType.GOAL:
		# Development and security are questions about a society. There is not
		# one here.
		_rows.add_child(_row("STRUCTURE", "PRECURSOR RUINS"))
		_rows.add_child(_row("SECURITY", "NONE", Color("#c8734f")))
		_rows.add_child(_row("OPERATORS", "NOTHING LIVING"))
	else:
		_rows.add_child(_row("DEVELOPMENT", MapGen.development_name(t.development).to_upper()))
		_rows.add_child(_row("SECURITY", MapGen.security_name(t.security).to_upper(),
			Color("#c8734f") if t.security <= 2 else UITheme.CHILL))
		var who := "UNCLAIMED"
		if not t.makers.is_empty():
			var names: Array[String] = []
			for m in t.makers:
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
	else:
		_jump.text = "NOT ENOUGH FUEL"

## Everything within reach, nearest first, as a list you can click. Cleared
## systems stay on it — knowing the nearby ground is already stripped is the
## information that decides whether you farm on or dive.
func _fill_neighbours(here: MapGen.MapNode) -> void:
	_clear(_neigh)
	var near := Run.in_range()
	near.sort_custom(func(x, y):
		return MapGen.hop_distance(here, x) < MapGen.hop_distance(here, y))
	if near.is_empty():
		_hint.text = "Nothing in range. The tank is too low to reach anything."
		return
	var fresh := 0
	for n in near:
		if not (n as MapGen.MapNode).cleared:
			fresh += 1
	_hint.text = "IN RANGE - %d SYSTEM%s, %d UNTOUCHED" % [
		near.size(), "" if near.size() == 1 else "S", fresh]
	for n in near:
		_neigh.add_child(_neighbour_row(n))

## One system in the list: its icon, its name, its danger and what it costs.
func _neighbour_row(n: MapGen.MapNode) -> Control:
	var afford := Run.can_jump_to(n)
	var b := Button.new()
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
	g.setup(n.type, MapGen.region_colour(n))
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(g)

	var dim := Color("#55647a")
	var name_col := UITheme.ICE if afford else dim
	if n.cleared and n.type != MapGen.NodeType.GOAL:
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
	b.tooltip_text = "%s\ndanger %d of %d · %d fuel" % [
		MapGen.place_line(n), n.danger, MapGen.DANGER_MAX, cost]
	return b

func _contains(t: MapGen.MapNode) -> String:
	if t.cleared:
		return "PICKED CLEAN"
	match t.type:
		MapGen.NodeType.FIGHT: return "HOSTILE x1"
		MapGen.NodeType.STATION: return "DOCK - REPAIR, REFUEL, STOCK"
		MapGen.NodeType.EVENT: return "UNKNOWN SIGNAL"
		MapGen.NodeType.DERELICT: return "SALVAGE"
		MapGen.NodeType.GOAL: return "THE CUSTODIAN"
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

func _row(key: String, value: String, colour: Color = UITheme.CHILL) -> Control:
	var row := HBoxContainer.new()
	row.add_child(UITheme.body(key, UITheme.COLD, UITheme.FS_SMALL))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	row.add_child(UITheme.body(value, colour, UITheme.FS_SMALL))
	return row

func _danger_row(danger: int) -> Control:
	return _gauge_row("DANGER", danger, MicroGauge.Mode.DANGER)

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
func _on_toggle_icons() -> void:
	_chart.show_icons = not _chart.show_icons
	_icons_btn.text = "HIDE SYSTEMS" if _chart.show_icons else "SHOW SYSTEMS"
	_chart.queue_redraw()

func _on_toggle_all() -> void:
	_chart.show_all = not _chart.show_all
	_all_btn.text = "SHOW ALL SYSTEMS" if not _chart.show_all else "SHOW KNOWN ONLY"
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
							col = Color("#b8923f")
						else:
							col = Color("#c8503c")
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
	##   .  empty   o  outline   #  ink (region tint)   +  shaded   *  emissive

	var type: MapGen.NodeType = MapGen.NodeType.FIGHT
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
	const _FIGHT := [
		".............",
		".............",
		".........oo..",
		".......oo##o.",
		".....oo####o.",
		"...oo######o.",
		".oo########o.",
		"o##++++++##o.",
		".oo########o.",
		"...oo######o.",
		".....oo####o.",
		".......oo##o.",
		".........oo.."]

	## A hab ring with its lights on. Warm pixels are the tell: a station is the
	## only friendly thing out here, and warmth is only ever emitted, never ambient.
	const _STATION := [
		".............",
		"....ooooo....",
		"...o#####o...",
		"..o##ooo##o..",
		".o##o...o##o.",
		".o#o..*..o#o.",
		".o#o.*.*.o#o.",
		".o#o..*..o#o.",
		".o##o...o##o.",
		"..o##ooo##o..",
		"...o#####o...",
		"....ooooo....",
		"............."]

	## An unknown signal: a burst, radiating. Reads at a glance as "something is
	## transmitting here" without resorting to a question mark.
	const _EVENT := [
		".............",
		"......#......",
		"..#...#...#..",
		"...#..#..#...",
		"....#.#.#....",
		".....###.....",
		".##.##*##.##.",
		".....###.....",
		"....#.#.#....",
		"...#..#..#...",
		"..#...#...#..",
		"......#......",
		"............."]

	## A hulk with a bite out of it and its pieces drifting off. Asymmetric on
	## purpose — a regular wreck reads as a building.
	const _DERELICT := [
		".............",
		".............",
		"...ooo.......",
		"..o###oo.....",
		".o##++##o....",
		".o#++++#o.oo.",
		".o##++#o..o#o",
		"..oo##oo...o.",
		"....o#o......",
		".....o...o...",
		".......o.....",
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
	const _GOAL := [
		".............",
		".............",
		"....#####....",
		"..###...###..",
		"..#.......#..",
		"###.......###",
		"****.....****",
		"*************",
		"..#.......#..",
		"..###...###..",
		"....#####....",
		".............",
		"............."]

	## An open ring with a beam tick either side.
	##
	## The middle is deliberately EMPTY. The live layer flashes the actual
	## neutron star at this exact point, and the first version of this glyph was
	## a solid cross that sat on top of it — so the one node type with its own
	## animation was the one node type whose animation you could not see. The
	## ring says "something is here" and then gets out of the way.
	const _PULSAR := [
		".............",
		".....###.....",
		"...##...##...",
		"..#.......#..",
		".#.........#.",
		".#.........#.",
		"*#.........#*",
		".#.........#.",
		".#.........#.",
		"..#.......#..",
		"...##...##...",
		".....###.....",
		"............."]

	## Where the run began: your own hull, nosing right.
	const _START := [
		".............",
		".............",
		"..oo.........",
		".o##oo.......",
		".o####oo.....",
		".o######oo...",
		".o########oo.",
		".o##++++++##o",
		".o########oo.",
		".o######oo...",
		".o####oo.....",
		".o##oo.......",
		"..oo........."]

	static func art_for(t: MapGen.NodeType) -> Array:
		match t:
			MapGen.NodeType.STATION: return _STATION
			MapGen.NodeType.EVENT: return _EVENT
			MapGen.NodeType.DERELICT: return _DERELICT
			MapGen.NodeType.GOAL: return _GOAL
			MapGen.NodeType.PULSAR: return _PULSAR
			MapGen.NodeType.START: return _START
			_: return _FIGHT

	static func draw_glyph(ci: CanvasItem, o: Vector2, t: MapGen.NodeType,
			tint_in: Color, here: bool, selected: bool) -> void:
		# Region colours sit quietly behind sprites; as a glyph on a dark chart
		# they need lifting or the icon reads as a smudge.
		var ink := tint_in.lightened(0.34)
		var shade := tint_in.darkened(0.22)
		var line := Color("#070b11")
		var art := art_for(t)
		for y in art.size():
			var row: String = art[y]
			for x in row.length():
				var ch := row[x]
				if ch == ".":
					continue
				var col := line
				if ch == "#":
					col = ink
				elif ch == "+":
					col = shade
				elif ch == "*":
					col = UITheme.HOT
				ci.draw_rect(Rect2(o + Vector2(x, y), Vector2.ONE), col, true)

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
class Backdrop extends Control:
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
	## A click on empty space — not the end of a drag. Puts the chart back to
	## just the galaxy.
	signal cleared()

	## Low enough to frame the whole galaxy at once, which is how you plan a
	## route; 1.0 is the reading zoom.
	const ZOOM_MIN := 0.42
	const ZOOM_MAX := 6.0

	const DISC := 2.05

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
	var show_all: bool = false
	var selected: int = -1
	var hovered: int = -1
	var zoom: float = ZOOM_MIN
	var pan: Vector2 = Vector2.ZERO
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
	var _backdrop: Control
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
		_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
		for layer in [_deep, _backdrop, _halo]:
			if layer != null:
				layer.queue_redraw()
		queue_redraw()

	func _process(delta: float) -> void:
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

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			# _radius() is derived from size, so every cached position is stale.
			_repaint_galaxy()

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
		for n in Run.map:
			var t: MapGen.MapNode = n
			if show_all or t.visited:
				out[t.index] = true
		out[here.index] = true
		for r in reach:
			out[(r as MapGen.MapNode).index] = true
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
		# Scales with the disc, so the rim is reachable at any zoom. A fixed half
		# screen was fine when the galaxy fit the frame and strands you in the
		# middle now that it does not.
		var ex := _radius() * DISC * zoom
		return Vector2(maxf(size.x * 0.5, ex), maxf(size.y * 0.5, ex * _squash()))

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
			# Two kinds of line, and they should not look alike. Where you HAVE
			# been is settled fact: solid, white, unbroken. Where you COULD go is
			# a proposal: dotted, dim, obviously provisional. Drawing both as
			# plain lines in different colours made the chart look like one
			# network when it is really a record and a set of options.
			reach = Run.in_range()
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
			var tint := MapGen.region_colour(node2)
			if node2.cleared and node2.type != MapGen.NodeType.GOAL:
				tint = Color("#37424f")
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
				_draw_you(p)
			elif node2.index == hovered or node2.index == selected:
				draw_string(UITheme.pixel_font(), p + Vector2(-40, 30),
					MapGen.star_name(node2), HORIZONTAL_ALIGNMENT_CENTER, 92, 8,
					UITheme.ICE if node2.index == hovered else UITheme.COLD)


		_draw_neb_edges()

		if hovered >= 0 and hovered < Run.map.size() and _hover_t > 0.01:
			_draw_tip(Run.map[hovered], here)
		elif _neb_hot != "":
			_draw_neb_tip()

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
		if n.cleared and n.type != MapGen.NodeType.GOAL:
			l2 = "CLEARED · " + l2
		var l3 := MapGen.place_line(n)
		var l4 := "DANGER %d/10" % n.danger
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
			Color(MapGen.region_colour(n), a), true)

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
			_far_layer(ci, lerpf(150.0, 700.0, f), lerpf(0.09, 0.58, f),
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
			var parallax: float = lerpf(0.05, 0.62, f)
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
		var disc := _radius() * zoom * 1.1
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
				var over_disc: bool = (q - here).length() < disc
				if w < 0.88 and over_disc:
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
				if over_disc and not _dark_r.is_empty():
					var ex: float = _extinct((q - here) / maxf(0.001, zoom))
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

	func _draw_you(p: Vector2) -> void:
		var b := 5.0
		var o := p - Vector2(4, 4)
		var w := 21.0
		for corner in [
				[Vector2(0, 0), Vector2(1, 1)],
				[Vector2(w, 0), Vector2(-1, 1)],
				[Vector2(0, w), Vector2(1, -1)],
				[Vector2(w, w), Vector2(-1, -1)]]:
			var k: Vector2 = o + corner[0]
			var d: Vector2 = corner[1]
			draw_rect(Rect2(k + Vector2(0, -1 if d.y < 0 else 0), Vector2(b * d.x, 1)), UITheme.FLARE, true)
			draw_rect(Rect2(k + Vector2(-1 if d.x < 0 else 0, 0), Vector2(1, b * d.y)), UITheme.FLARE, true)
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
				col = MapGen.region_colour(node)
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

		var c := size * 0.5 + pan
		var w := size.x
		var h := size.y
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
				if q.x < 0.0 or q.y < 0.0 or q.x > w or q.y > h:
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
				if q.x < 0.0 or q.y < 0.0 or q.x > w or q.y > h:
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
			for i in _neb_pos.size():
				var q := c + _neb_pos[i] * zoom
				if q.x < -80.0 or q.y < 0.0 or q.x > w + 80.0 or q.y > h:
					continue
				# Nothing is written across the cloud any more. A name printed on
				# every nebula is a label on scenery: it competes with the system
				# names, which are the ones you actually act on, and it is on
				# screen permanently to tell you something you want once. It is
				# a hover tooltip now, like everything else that answers "what
				# is that".
				pass
