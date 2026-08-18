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
	for c in _layer_cells.get_children():
		c.queue_free()
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

	for c in _rows.get_children():
		c.queue_free()

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
	_dest_class.text = "%s - %s" % [
		Run.galaxy_name, MapGen.development_name(t.development).to_upper()]
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
	for c in _neigh.get_children():
		c.queue_free()
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

	## The thing at the centre: a bright accretion ring around nothing at all.
	## The hole has to be drawn as absence — pixels that are not there — because
	## any colour dark enough to read as a black hole would just read as a dark
	## sprite against a dark chart.
	const _GOAL := [
		".............",
		"....*****....",
		"..**ooooo**..",
		".*oo.....oo*.",
		".*o.......o*.",
		"**o.......o**",
		"**o.......o**",
		"**o.......o**",
		".*o.......o*.",
		".*oo.....oo*.",
		"..**ooooo**..",
		"....*****....",
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

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if chart != null and not Run.map.is_empty():
			chart.draw_anim(self)


## The galaxy, on a canvas of its own so that highlighting a system does not
## repaint forty-eight thousand stars.
class Backdrop extends Control:
	var chart: MapChart

	func _draw() -> void:
		if chart != null and not Run.map.is_empty():
			chart.draw_backdrop(self)


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
	## Screen positions are pure functions of the node and the transform, and
	## they are wanted for every system on every redraw AND on every mouse
	## motion, so they are worth remembering.
	var _polar_cache: Dictionary = {}

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
	var _star_key: String = ""

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

	func _make_backdrop() -> void:
		_backdrop = Backdrop.new()
		(_backdrop as Backdrop).chart = self
		_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# A Control draws itself BEFORE its children, so without this the galaxy
		# is painted over the systems it is supposed to sit behind.
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

	## Anything that moves the galaxy on screen, as opposed to merely changing
	## what is highlighted.
	func _repaint_galaxy() -> void:
		_polar_cache.clear()
		if _backdrop != null:
			_backdrop.queue_redraw()
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
	func _orbital_omega(r: float) -> float:
		var sh := _shadow_r()
		var clear := _core_clear()
		var kep: float = 0.25 * pow(sh / maxf(r, sh * 0.6), 1.5)
		var fade: float = clampf(1.0 - r / maxf(1.0, clear), 0.0, 1.0)
		# Smoothstep, so it eases out of motion rather than ramping linearly
		# into stillness.
		fade = fade * fade * (3.0 - 2.0 * fade)
		return kep * fade

	func _core_clear() -> float:
		# Never smaller than the disc needs: a galaxy that rolled a large hole
		# would otherwise have its accretion disc pushed through the boundary.
		return maxf(_radius() * 0.22, _shadow_r() * 4.6)

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
				var h := _node_at(mm.position)
				if h != hovered:
					hovered = h
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
		for n in Run.map:
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

		# With the systems hidden, the chart is the galaxy alone — but they are
		# still THERE, and pointing at one brings it back. Hiding them is a way
		# to look past the interface, not a way to turn the map off.
		if show_icons:
			# The route you have taken. Drawn under everything else and kept dim
			# — it is history, not a decision, but a run should leave a mark.
			if Run.trail.size() > 1:
				for i in range(1, Run.trail.size()):
					var a := _screen_pos(Run.map[Run.trail[i - 1]])
					var b := _screen_pos(Run.map[Run.trail[i]])
					draw_line(a, b, Color(0.42, 0.31, 0.18, 0.55), 1.0)

			# The local cluster: everything the drive can reach from here. Where
			# you can go is not an inspection tool, it is the question the screen
			# exists to answer.
			reach = Run.in_range()
			for r in reach:
				var rn2: MapGen.MapNode = r
				var afford: bool = Run.can_jump_to(rn2)
				draw_line(hp, _screen_pos(rn2),
					Color(0.30, 0.44, 0.58, 0.55) if afford else Color(0.30, 0.34, 0.40, 0.28),
					1.0)

		# Whatever you are pointing at, in full: where you could go from there.
		# Charted links would be the wrong thing to show — they are a generation
		# detail now, not what travel is measured by.
		if hovered >= 0 and hovered < Run.map.size() and hovered != here.index:
			var f: MapGen.MapNode = Run.map[hovered]
			var fp := _screen_pos(f)
			for r2 in Run.in_range_of(f):
				draw_line(fp, _screen_pos(r2), Color(0.26, 0.34, 0.43, 0.40), 1.0)

		# Glyphs are a fixed pixel size, so at low zoom 173 of them tile into a
		# wall of identical icons — which is most of why the chart read as
		# regular. Zoomed out, a system is a point of light; the glyph is detail
		# you zoom in for.
		var tiny := zoom < 0.78
		for n in Run.map:
			var node2: MapGen.MapNode = n
			# Hidden: only the one under the cursor is drawn.
			if not show_icons and node2.index != hovered:
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


		if hovered >= 0 and hovered < Run.map.size() and _hover_t > 0.01:
			_draw_tip(Run.map[hovered], here)

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
		# Same idea for the deep shell: the tile grid coarsens during a drag, so
		# the far galaxies thin rather than vanish. They are the dimmest thing
		# on screen and the least missed while the view is sweeping.
		_far_layer(ci, 86.0 if not _dragging else 150.0, 0.12, 1.5, 3.5, 0.5, 0.92, 3)
		_far_layer(ci, 260.0, 0.28, 4.0, 9.0, 1.0, 0.84, 11)
		_far_layer(ci, 780.0, 0.58, 9.0, 20.0, 1.0, 0.52, 41)

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

					var pt := (q + local).round()
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
	func _draw_halo(ci: CanvasItem) -> void:
		_star_layer(ci, 12.0, 0.20, 0.52, 0.55, 29)
		_star_layer(ci, 17.0, 0.48, 0.40, 1.0, 5)

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

		for i in range(i0, i1 + 1):
			for j in range(j0, j1 + 1):
				var h := _hash2(i, j, _sky(salt))
				var w := float(h % 1000) / 1000.0
				# Most tiles are empty sky. Bail before touching anything else.
				if w < empty:
					continue
				var u := float((h / 1000) % 1000) / 1000.0
				var v := float((h / 1000000) % 1000) / 1000.0
				var q := (c + Vector2((float(i) + u) * cell, (float(j) + v) * cell) * zf).round()
				if q.x < 0 or q.y < 0 or q.x > size.x or q.y > size.y:
					continue
				# Thin out over the disc so the halo never competes with the arms.
				if w < 0.88 and (q - here).length() < disc:
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
		var key := "%d|%d|%.1f|%.2f" % [Run.galaxy_kind, Run.galaxy_seed, r_max, _squash()]
		if key == _star_key:
			return
		_star_key = key
		_star_pos = PackedVector2Array()
		_star_col = PackedColorArray()
		_star_big = PackedByteArray()
		_star_dim = PackedByteArray()

		var sq := _squash()
		var arms := _arms()
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
		var inv_sq := 1.0 / maxf(0.05, sq)
		## Where the cached field starts fading in. Below this it is absent
		## entirely; above `clear` it is at full strength. The live layer fades
		## out across the same band, so the two sum to a constant — an abrupt
		## handover at a single radius shows as a ring however well the speeds
		## match, because the populations either side are never quite identical.
		var blend_in := clear * 0.7

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
			var e_pd: float = Vector2(pd.x, pd.y * inv_sq).length()
			if e_pd < blend_in or t3 > (e_pd - blend_in) / (clear - blend_in):
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
			var e_pa: float = Vector2(pa.x, pa.y * inv_sq).length()
			if e_pa < blend_in or t3 > (e_pa - blend_in) / (clear - blend_in):
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
				var e_pt2: float = Vector2(pt2.x, pt2.y * inv_sq).length()
				if e_pt2 < blend_in or t3 > (e_pt2 - blend_in) / (clear - blend_in):
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
			# pow 2.4 crowded almost every bulge star against the inner edge,
			# and since that edge is now a hard boundary — everything inside is
			# cleared for the live layer — the crowd became a bright static rim
			# around the hole. A gentler exponent spreads them out.
			var frac: float = pow(u, 1.5)
			var rr2: float = blend_in + frac * (bulge + clear - blend_in)
			# No fade-in any more. It existed to soften a hard edge against an
			# empty core, and the core is not empty — it is full of orbiting
			# stars at matching density, so fading in here only reopened the gap
			# it was meant to hide.
			var aa: float = v * TAU
			var heat := 1.0 - clampf(rr2 / maxf(1.0, bulge), 0.0, 1.0)
			var col2 := Color("#7a3f16")
			if heat > 0.75:
				col2 = Color("#ffdca0")
			elif heat > 0.5:
				col2 = Color("#cc641c")
			var pb := Vector2(cos(aa), sin(aa) * sq) * rr2
			var e_pb: float = Vector2(pb.x, pb.y * inv_sq).length()
			if e_pb < blend_in or v > (e_pb - blend_in) / (clear - blend_in):
				continue
			_star_pos.append(pb)
			_star_col.append(col2)
			_star_big.append(0)
			_star_dim.append(0)

		# The accretion ring is NOT built here. It used to be, and the live layer
		# drew a churning one at the same radius on top of it — so the bright
		# ring you actually saw was the static copy underneath, and no amount of
		# animation above it could make it move. The live layer owns the ring
		# outright now, exactly as it owns the orbiting stars.

		# --- the halo and the wreckage, last, so they sit on top of the disc they
		# are in front of.
		_build_clusters(r_max)
		_build_remnants(r_max)

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
	func _static_ok(p: Vector2, t: float) -> bool:
		var clear := _core_clear()
		var blend_in := clear * 0.7
		var e: float = Vector2(p.x, p.y / maxf(0.05, _squash())).length()
		if e < blend_in:
			return false
		return t <= (e - blend_in) / (clear - blend_in)

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
	func _build_nebulae(r_max: float) -> void:
		_neb_pos = PackedVector2Array()
		_neb_top = PackedFloat32Array()
		_neb_name = PackedStringArray()
		var g := _g()
		var gas: float = float(g.get("gas", 1.0))
		# A galaxy that has stopped forming stars gets none at all, rather than a
		# scattering of faint ones. That absence does real work: it is what makes
		# a lenticular read as finished beside a starburst, and it is free.
		var count := clampi(int(round(gas * 4.0)), 0, 9)
		if count <= 0:
			return

		var sq := _squash()
		var arms := _arms()
		var spiral: bool = int(g.arms) > 0
		_seed_rng(90210)
		for k in count:
			var rn: float = 0.22 + _rnd() * 0.68
			var ang: float = _rnd() * TAU
			if spiral:
				# On an arm. Star formation happens where the density wave
				# piles the gas up, so a cloud floating between the arms would
				# be a cloud in the one place nothing is being born.
				ang = _shape_angle(rn, k % arms, (_rnd() - 0.5) * 0.55)
			var centre := Vector2(cos(ang), sin(ang) * sq) * rn * r_max
			# One landmark per galaxy, plainly bigger than the rest. A field of
			# same-sized clouds reads as texture; one large one with smaller
			# company reads as a place you could point at.
			var big: bool = k == 0
			var rad: float = r_max * (0.16 + _rnd() * 0.08) if big \
				else r_max * (0.06 + _rnd() * 0.07)
			# Tilted toward reflection. Emission gas is the warm half, and this
			# is a game about a cold universe with one warm thing in it — the
			# core — so the loud clouds have to stay in the minority or the
			# brightest thing on the chart stops being the thing that burns.
			var emission: bool = _rnd() > 0.58
			# Weighted toward the gas rather than the region: region colours are
			# chrome, chosen to sit quietly behind an icon, and a cloud built out
			# of one at full strength comes out the colour of the panel border.
			# The region pulls the hue over; it does not set it.
			var base: Color = _region_tint(centre).lerp(
				_NEB_EMIT if emission else _NEB_REFLECT, 0.68)
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
			for l in 3:
				lobes.append(Vector2((_rnd() - 0.5) * rad * 1.1,
					(_rnd() - 0.5) * rad * 0.8))
				lobe_r.append(rad * (0.45 + _rnd() * 0.5))

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
			var px := clampi(int(rad * rad * 0.15), 300, 3000)
			for i in px:
				var lobe := i % 3
				var lr: float = lobe_r[lobe]
				var rr: float = pow(_rnd(), 0.8) * lr
				var a2: float = _rnd() * TAU
				var local: Vector2 = lobes[lobe] \
					+ Vector2(cos(a2) * rr, sin(a2) * rr * 0.82)

				# Density is the STRONGEST lobe at this point, not the sum, so
				# overlaps brighten rather than merely doubling the dot count.
				var d := 0.0
				for m in 3:
					d = maxf(d, 1.0 - minf(1.0,
						(local - lobes[m]).length() / maxf(1.0, lobe_r[m])))
				d = d * d * (3.0 - 2.0 * d)
				# Filaments. Gas is ropey, not spherical, and two sines that do
				# not divide into each other say so well enough at this size.
				var fil: float = 0.5 + 0.5 * sin(local.x * 0.085 + twist_k) \
					* sin(local.y * 0.11 - twist_k * 1.7)
				d *= 0.52 + 0.48 * fil

				var world := centre + local
				var dith := _dither(world)
				if d < dith:
					continue
				if not _static_ok(world, _rnd()):
					continue
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

			# The stars that lit it. Only emission clouds get these, and that IS
			# the difference between the two kinds: one glows because something
			# inside it is burning, the other only catches light from elsewhere.
			if emission:
				var young := 5 + int(_rnd() * 5.0)
				for y in young:
					var sp: Vector2 = centre + lobes[y % 3] \
						+ Vector2(_rnd() - 0.5, _rnd() - 0.5) * rad * 0.5
					if not _static_ok(sp, _rnd()):
						continue
					_star_pos.append(sp)
					_star_col.append(Color("#e8f2ff") if _rnd() > 0.5
						else Color("#a9c6e6"))
					_star_big.append(0)
					_star_dim.append(0)

			_neb_pos.append(centre)
			# A floor, for the pathological cloud whose lobes all fell below its
			# centre and which would otherwise wear its name through its middle.
			_neb_top.append(maxf(top, rad * 0.3))
			_neb_name.append(GalaxyGen.nebula_name(
				(Run.galaxy_seed >> 3) + k * 7919))

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
			if not _static_ok(p, _rnd()):
				continue
			var t := _rnd()
			var col := Color("#080c14")
			if t > 0.86:
				col = Color("#16121c")
			elif t > 0.6:
				col = Color("#0b1119")
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
					if not _static_ok(w, _rnd()):
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
				if not _static_ok(p, _rnd()):
					continue
				var t := _rnd()
				# An old population. There is no blue left in one of these.
				var col := Color("#5d5442")
				if t > 0.82:
					col = Color("#e0d0aa")
				elif t > 0.5:
					col = Color("#9c8b68")
				_star_pos.append(p)
				_star_col.append(col)
				_star_big.append(0)
				_star_dim.append(1 if t <= 0.5 else 0)

	## Supernova remnants, and the pulsars they leave behind.
	##
	## Lit by shock rather than by starlight, so they come out cold-bright —
	## the one thing in the disc that is neither a warm core nor a blue arm — and
	## each is small enough that finding one is a reward for zooming in rather
	## than another texture at overview scale.
	func _build_remnants(r_max: float) -> void:
		_pulsar = PackedVector2Array()
		var g := _g()
		var gas: float = float(g.get("gas", 1.0))
		# Massive stars are the ones that end this way, and they only exist
		# where stars are still being made. So this scales off gas like the rest.
		var count := clampi(int(round(gas * 1.6)), 0, 3)
		if count <= 0:
			return
		var sq := _squash()
		var arms := _arms()
		var spiral: bool = int(g.arms) > 0
		_seed_rng(19870223)
		for k in count:
			# Small. The first pass drew them at twice this and they came out as
			# clean bright hoops that read as interface rather than as sky —
			# the brightest thing on the chart after the core, which is exactly
			# backwards for the rarest.
			var shell: float = r_max * (0.008 + _rnd() * 0.012)
			var centre := Vector2.ZERO
			# Kept off the systems. A remnant is the one thing out here drawn as
			# a ring, and a ring that lands around a station glyph stops reading
			# as a shock front and starts reading as a selection reticle — the
			# chart already draws one of those, in orange, and it means something
			# specific. Not every position can work, so this re-rolls a few times
			# and takes what it gets rather than searching for perfection.
			for attempt in 8:
				var rn: float = 0.25 + _rnd() * 0.6
				var ang: float = _rnd() * TAU
				if spiral:
					ang = _shape_angle(rn, k % arms, (_rnd() - 0.5) * 0.4)
				centre = Vector2(cos(ang), sin(ang) * sq) * rn * r_max
				var clash := false
				for nd in Run.map:
					var node: MapGen.MapNode = nd
					if _polar(node).distance_to(centre) < shell * 3.0:
						clash = true
						break
				if not clash:
					break
			var phase: float = _rnd() * TAU
			for m in 260:
				var a2: float = _rnd() * TAU
				# Filamentary, not a ring. A shock front breaks up as it runs
				# into whatever is out there, and an even circle of dots reads
				# as a drawn outline rather than as something that exploded.
				if _rnd() > 0.28 + 0.72 * absf(sin(a2 * 3.0 + phase)):
					continue
				var rr: float = shell * (0.78 + pow(_rnd(), 0.5) * 0.24)
				var p := centre + Vector2(cos(a2), sin(a2) * 0.94) * rr
				if not _static_ok(p, _rnd()):
					continue
				var t := _rnd()
				var col := Color("#24534f")
				if t > 0.94:
					col = Color("#7fd0c2")
				elif t > 0.68:
					col = Color("#3f8f88")
				elif t > 0.56:
					col = Color("#70415f")
				_star_pos.append(p)
				_star_col.append(col)
				_star_big.append(0)
				# The dimmest tier only, matched to the colour test above rather
				# than to a round number, so a drag never takes a lit filament.
				_star_dim.append(1 if t <= 0.56 else 0)
			_pulsar.append(centre)

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
		var lit_step := maxi(1, _star_pos.size() / 2600)
		for i in range(0, _star_pos.size(), lit_step):
			var sp := _star_pos[i]
			var q := c + sp * zoom
			if q.x < 0.0 or q.y < 0.0 or q.x > w or q.y > h:
				continue
			var ang := atan2(sp.y, sp.x)
			var rn: float = sp.length() / maxf(1.0, _radius() * DISC)
			# Two-armed, and wound: the wave lags with radius exactly as the arms
			# do, so it travels along them rather than sweeping across them.
			var phase := ang * 2.0 - rn * 5.0 - t * 0.085

			var glow := sin(phase)
			if glow < 0.93:
				continue
			var col := Color("#43566d")
			if rn < 0.32:
				col = Color("#8a6134")
			elif rn < 0.62:
				col = Color("#5f7590")
			ci.draw_rect(Rect2(q.round(), one), col, true)

		# --- the inner stars, in orbit.
		#
		# This is the one place fast motion is honest. A galaxy takes a couple of
		# hundred million years to turn, which is why the disc is static — but
		# stars this close to a supermassive black hole go round in years, and
		# the ones we have watched do it in decades. The backdrop leaves this
		# annulus empty precisely so these can move without a static twin
		# sitting at the same radius.
		var sh := _shadow_r()
		var clear := _core_clear()
		var sq := _squash()
		# Hashed per star rather than walked along an LCG. Taking `% 10000` off
		# the LOW bits of a linear congruential generator is the classic way to
		# get points that lie on a lattice — invisible in a field of forty
		# thousand, and immediately obvious as arcs and spokes in a few hundred.
		# The accretion disc is a CIRCLE and the orbiting field is an ELLIPSE, so
		# no single starting radius can meet it: pick one that closes the gap at
		# the sides and the top and bottom overlap, pick one that works top and
		# bottom and a dark ring opens at the sides. That ring is what has been
		# left over each time.
		#
		# So the field starts from the middle and is cut against the disc's
		# actual drawn edge instead. The boundary is then the disc's own shape by
		# construction, whatever the squash happens to be.
		var d_out := sh * 2.7
		# Fewer orbiting stars mid-drag. Motion is unreadable while the whole
		# view is sweeping anyway, so this is invisible in practice.
		var orbit_n := 4000 if not _dragging else 1500
		for i in orbit_n:
			var ou := _frac(_hash2(i, 1, 4711))
			var ov := _frac(_hash2(i, 2, 4711))
			var ob := _frac(_hash2(i, 3, 4711))

			# Spread by AREA, so the density is flat right out to the boundary.
			# Spacing them evenly in RADIUS thinned them steadily outward, and
			# the static bulge fades IN at that same radius — two fades meeting,
			# each sparse where the other was, which drew a dark ring exactly at
			# the join. Neither was wrong on its own.
			var blend_in := clear * 0.7
			var orad: float = sqrt(lerpf(sh * sh, clear * clear * 1.16, ou))
			# Complementary fade: thins out exactly as fast as the cached field
			# thickens, so the total stays flat across the handover.
			if orad > blend_in:
				var oc := _frac(_hash2(i, 13, 4711))
				if oc < (orad - blend_in) / (clear - blend_in):
					continue
			# Keplerian. The gradient is the point: brisk just outside the
			# accretion disc, slowing steadily out to the edge of the hole's
			# neighbourhood, where it is slow enough to hand over to the static
			# field without the join being visible.
			var rel: float = orad / maxf(1.0, clear)
			var omega: float = _orbital_omega(orad)
			var oa: float = ov * TAU + t * omega
			var off := Vector2(cos(oa), sin(oa) * sq) * orad
			# Cut against the disc's drawn edge: anything the disc already
			# covers is dropped, and the rest packs right up against it.
			if off.length() < d_out:
				continue
			var q2 := c + off * zoom
			if q2.x < 0.0 or q2.y < 0.0 or q2.x > w or q2.y > h:
				continue
			# Warm near the hole, cooling outward into the colours the static
			# bulge uses, so the boundary between live and cached is invisible.
			var ocol := Color("#c8a06a")
			if rel < 0.45:
				ocol = Color("#ffe6bd") if ob > 0.8 else Color("#d99b52")
			elif rel < 0.75:
				ocol = Color("#e0b077") if ob > 0.7 else Color("#9c7a4a")
			else:
				ocol = Color("#8a6a44") if ob > 0.5 else Color("#5f5238")
			ci.draw_rect(Rect2(q2.round(), one), ocol, true)

		# --- the accretion disc.
		#
		# A ring of scattered dots at one radius was never going to read as a
		# disc: what makes an accretion disc legible is that it has WIDTH, and
		# that the matter in it shears — the inner edge laps the outer edge. So
		# this is a proper annulus with a radial density falloff, orbiting
		# Keplerian, and slowly. The shear does the work; nothing here spins as
		# a rigid body.
		#
		# Two touches of real physics because both are cheap and both are what
		# the eye recognises. Temperature: the inner edge is white-hot and it
		# cools outward through gold to a dull ember. Doppler beaming: the side
		# rotating toward you is brighter, which is the asymmetry that stops a
		# disc looking like a decal.
		var d_in := sh * 1.06
		var disc_n := 1500 if not _dragging else 600
		for i in disc_n:
			var dv := _frac(_hash2(i, 3, 8675))
			var da := _frac(_hash2(i, 5, 8675))
			var db := _frac(_hash2(i, 11, 8675))

			# Crowded toward the hot inner edge, thinning outward.
			var rn2: float = pow(dv, 1.9)
			var dr: float = d_in + rn2 * (d_out - d_in)
			# Keplerian, and slow: about forty seconds for the inner edge to go
			# round, and the outer edge takes several times that.
			var ang2: float = da * TAU + t * _orbital_omega(dr)
			# Churn, not rotation. Matter in an accretion disc does not travel
			# in tidy circles — it is turbulent, and orbits that shear past each
			# other at different speeds do not stay smooth. A slow radial
			# breathing keyed to each particle's own phase is enough to suggest
			# that: the band roils instead of turning.
			dr *= 1.0 + 0.07 * sin(t * 0.42 + da * 19.0)
			# Circular. Flattening it was meant to read as inclination and did
			# not — it read as a squashed hoop, and because the cleared core is
			# round it left a dark void above and below the disc where nothing
			# was drawn at all.
			var q3 := c + Vector2(cos(ang2), sin(ang2)) * dr * zoom
			if q3.x < 0.0 or q3.y < 0.0 or q3.x > w or q3.y > h:
				continue

			# Doppler: brightest where the matter is coming toward the viewer.
			var beam: float = 0.6 + 0.4 * cos(ang2)
			# Hot and cool patches drift around the band independently of the
			# rotation, which is most of what makes it look like it is boiling.
			# Two frequencies that do not divide into each other, or the pattern
			# closes on itself and draws four tidy arcs instead of turbulence.
			var churn: float = 0.86 + 0.16 * sin(ang2 * 4.0 - t * 0.55 + dv * 11.0) \
				+ 0.13 * sin(ang2 * 7.0 + t * 0.31 + dv * 23.0)
			var heat: float = (1.0 - rn2) * beam * churn
			var dcol := Color("#7a4418")
			if heat > 0.82:
				dcol = Color("#fffaf0")
			elif heat > 0.62:
				dcol = Color("#ffe2ae")
			elif heat > 0.42:
				dcol = Color("#f0a942")
			elif heat > 0.24:
				dcol = Color("#c46f24")
			# A few percent of it flickers, so the disc is never quite steady.
			if db > 0.97:
				dcol = Color("#fffdf6")
			ci.draw_rect(Rect2(q3.round(), one), dcol, true)

		# --- pulsars. What a supernova leaves turning at the middle of its own
		# wreckage. Everything else on this chart drifts, churns or fades; these
		# are the only thing on it that keeps time, and each one runs at its own
		# rate so they never fall into step with each other.
		for i in _pulsar.size():
			var period: float = 1.1 + float(i) * 0.43
			var ph: float = fmod(t, period) / period
			if ph > 0.16:
				continue
			var env: float = 1.0 - ph / 0.16
			var pq := c + _pulsar[i] * zoom
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
	func draw_backdrop(ci: CanvasItem) -> void:
		ci.draw_rect(Rect2(Vector2.ZERO, size), Color("#070a10"), true)
		_build_stars()
		_draw_far_galaxies(ci)

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
		var gk: float = clampf(round(zoom * 2.6), 2.0, 5.0)
		var gas_px := Vector2(gk, gk)
		# Every star, every frame, including while dragging. Halving the density
		# during a drag was cheaper, but a galaxy that visibly dims the moment
		# you touch it is worse than one that repaints a little slower — and
		# since the field became precomputed data the repaint is affordable.
		var cheap := _dragging
		for i in _star_pos.size():
			if cheap and _star_dim[i] == 1:
				continue
			var q := c + _star_pos[i] * zoom
			if q.x < 0.0 or q.y < 0.0 or q.x > w or q.y > h:
				continue
			var sz := one
			match _star_big[i]:
				1: sz = two
				2: sz = gas_px
			ci.draw_rect(Rect2(q.round(), sz), _star_col[i], true)

		_draw_halo(ci)

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
				var lbl: String = _neb_name[i]
				var lw: float = f.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
				var at := (q - Vector2(lw * 0.5, _neb_top[i] * zoom + 6.0)).round()
				ci.draw_string(f, at, lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 8,
					Color(UITheme.COLD, la))
