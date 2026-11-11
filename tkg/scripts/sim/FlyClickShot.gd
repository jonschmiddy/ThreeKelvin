extends Node

## STILLS OF THE SECOND CLICK (F-C, Nov 11), windowed: `-- sheet=FlyClickShot out=<dir>`.
## Seed 4242's first one-sun system with two worlds, in orbit of the first: pointing at the
## other world unselected; selected and pointed at (the line lit, the tag's CLICK AGAIN: FLY);
## the pointer away (the panel with no FLY HERE); in orbit (its line); docked (UNDOCK FIRST).

var h := Harness.new()
var _tree: SceneTree
var _out := ""


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_tree = get_tree()
	await _tree.process_frame
	_out = Harness.arg("out", "user://flyclick")
	DirAccess.make_dir_recursive_absolute(_out)
	await _shots()
	h.verdict("flyclickshot")
	_tree.quit(h.code())


func _map() -> SystemMapScreen:
	Router.show_system()
	for i in 900:
		if not ZoomLadder.busy() and ZoomLadder.chain == &"":
			break
		await _tree.process_frame
	for i in 240:
		var m := Router.current as SystemMapScreen
		if m != null and m.flight != null and m.view.layout != null:
			await Harness.frames(_tree, 4)
			return m
		await _tree.process_frame
	return null


func _point(m: SystemMapScreen, p: Vector2) -> void:
	var mm := InputEventMouseMotion.new()
	mm.position = p + m._box.position
	mm.global_position = mm.position
	m._on_map_input(mm)


func _shot(name: String, m: SystemMapScreen) -> void:
	await Harness.frames(_tree, 3)
	await RenderingServer.frame_post_draw
	var tl: Array = m.overlay.tip_lines(m.overlay.hover)[0] if not m.overlay.hover.is_empty() else []
	print("  flyclick %s: tag %s; aimed %s" % [name, " / ".join(tl.map(func(l): return String(l[0]))), m.overlay.aimed()])
	get_viewport().get_texture().get_image().save_png(_out.path_join(name + ".png"))


func _shots() -> void:
	h.seed_run(4242)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var n: MapGen.MapNode = null
	var worlds: Array[int] = []
	for raw in Run.map:
		var m0: MapGen.MapNode = raw
		if m0.type != MapGen.NodeType.SYSTEM or m0.twin:
			continue
		OptionTable.ensure(m0)
		worlds.clear()
		for b in SystemLayout.of(m0).bodies:
			if b.world != &"":
				worlds.append(b.index)
		if worlds.size() >= 2:
			n = m0
			break
	if not h._ok("a one-sun system with two worlds", n != null):
		return
	var w0 := worlds[0]
	var w1 := worlds[1]
	Run.at = n.index
	n.visited = true
	SystemMapScreen._parked[n.index] = {"at": w0, "mode": &"rail"}
	Run.map_clock[n.index] = 30.0
	var m := await _map()
	if not h._ok("the map comes up in orbit of world %d" % w0, m != null and m.flight.reached() == w0):
		return
	for f in 600:
		if m.flight.can_fly():
			break
		await _tree.process_frame
	# 1. pointing at a world not selected: CLICK: SELECT, no line
	m.panel_back()
	_point(m, m.view.at[w1])
	await _shot("1_point_unselected", m)
	# 2. selected and pointed at: the line lit, the sight, CLICK AGAIN: FLY and nothing of sides
	m.select_body(w1)
	_point(m, m.view.at[w1])
	for f in 600:
		_point(m, m.view.at[w1])
		var pv = m.overlay._pv_plan
		if pv != null and int(pv.to) == w1 and ArriveSide.plan_matches(pv, m.flight.wish):
			break
		await _tree.process_frame
	var tl: Array = (m.overlay.tip_lines(m.overlay.hover)[0] as Array).map(func(l): return String(l[0]))
	h._ok("the tag ends CLICK AGAIN: FLY, no time, nothing of sides (%s)" % " / ".join(tl),
		tl[-1] == "CLICK AGAIN: FLY" and not tl.any(func(w: String) -> bool: return w.contains("SIDE") or w.contains("SHIFT")))
	await _shot("2_point_selected", m)
	# 3. the pointer away: the line faint, the panel facts only
	_point(m, m.view.window.position + Vector2(8.0, 8.0))
	await _shot("3_selected_panel", m)
	# 4. the world the ship orbits: its panel line, IN ORBIT; the tag YOU ARE HERE
	m.select_body(w0)
	_point(m, m.view.at[w0])
	await _shot("4_in_orbit", m)
	# 5. docked (set by hand for the still): UNDOCK FIRST in the panel and the tag
	Router.docked = true
	m.select_body(w1)
	_point(m, m.view.at[w1])
	await _shot("5_docked", m)
	Router.docked = false
	await _band(m)
	await _comet()


## THE COMET HIDDEN TILL CLICKED (Jon, Nov 11): its path and spots drawn only while it is selected.
func _comet() -> void:
	CometPath._force = 1
	var n: MapGen.MapNode = null
	for raw in Run.map:
		var m0: MapGen.MapNode = raw
		if m0.type == MapGen.NodeType.SYSTEM and not m0.twin and m0.index != Run.at:
			OptionTable.ensure(m0)
			if not m0.options.has(&"comet_coma"):
				m0.options.append(&"comet_coma")
			if SystemLayout.of(m0).comet != null:
				n = m0
				break
	if not h._ok("a system with a comet", n != null):
		return
	Run.at = n.index
	n.visited = true
	Run.map_clock[n.index] = SystemLayout.of(n).comet.t_in + 6.0
	var m := await _map()
	await Harness.frames(_tree, 20)
	var rc = m.view._weather.real_comet
	var hc: Dictionary = m.overlay.hit(m.overlay.comet_scr())
	m.overlay.hover = hc
	await _shot("8_comet_unselected", m)
	h._ok("unselected: no path, no spots (%d dots, %d spots)" % [rc.dots, m.overlay.spots_drawn], rc.dots == 0 and m.overlay.spots_drawn == 0)
	m.tap(hc)
	await _shot("9_comet_selected", m)
	h._ok("clicked: the path and three spots (%d dots, %d spots)" % [rc.dots, m.overlay.spots_drawn], rc.dots > 0 and m.overlay.spots_drawn == 3)
	CometPath._force = 0


## THE KEY BAND (Jon, Nov 11): LOCAL's strip under the map and the panel, full width, covering nothing
## drawn in the frame (the scale bar, LOCATION, the edge arrows, the comet's spots).
func _band(m: SystemMapScreen) -> void:
	m.panel_back()
	m.overlay.hover = {}
	await Harness.frames(_tree, 4)
	var band: Rect2 = m._key_band.get_global_rect()
	var frame: Rect2 = m._frame.get_global_rect()
	var wrap: Rect2 = (m._frame.get_parent() as Control).get_global_rect()
	var key: Rect2 = m._key_row.get_global_rect()
	h._ok("the band is under the map, clear of its frame (band %s, frame %s)" % [band, frame], not band.intersects(frame) and band.position.y >= wrap.end.y)
	var foot: Rect2 = (m._key_band.get_parent().get_parent() as Control).get_global_rect()
	h._ok("the band runs the whole row, map and panel (%.0f of %.0f)" % [band.size.x, foot.size.x], absf(band.size.x - foot.size.x) < 0.5 and band.position.x <= wrap.position.x + 0.5)
	var pad: float = UITheme.quiet_strip(SectorScreen.DRAWER_A, true).content_margin_left
	h._ok("the KEY row inside it, at its left padding as LOCAL's words (%s; %.1f px in, want %.0f)" % [key, key.position.x - band.position.x, pad],
		band.encloses(key) and absf(key.position.x - band.position.x - pad) <= 0.5 and absf(key.get_center().y - band.get_center().y) <= 1.0 and key.position == key.position.round())
	h._ok("the band's style is LOCAL's strip", m._key_band.get_theme_stylebox(&"panel") is StyleBoxFlat
		and (m._key_band.get_theme_stylebox(&"panel") as StyleBoxFlat).bg_color.is_equal_approx(UITheme.quiet_strip(SectorScreen.DRAWER_A, true).bg_color))
	for c: Control in [m._loc_btn, m._scale_bar]:
		h._ok("%s inside the map's frame, off the band (%s)" % [c.name, c.get_global_rect()], frame.grow(0.5).encloses(c.get_global_rect()) and not c.get_global_rect().intersects(band))
	await _shot("6_map_bottom", m)
	_crop("6_map_bottom", band.grow_individual(0, 60, 0, 4))
	# LOCAL's own strip, for comparison
	Router.show_local()
	for i in 900:
		if not ZoomLadder.busy() and ZoomLadder.chain == &"" and Router.current is SectorScreen:
			break
		await _tree.process_frame
	await Harness.frames(_tree, 30)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join("7_local_bottom.png"))
	var sc := Router.current as SectorScreen
	if sc != null and sc._quiet_wrap != null:
		# (the strip's own rect can still be unlaid here: the screen's bottom, as wide as the map's crop)
		_crop("7_local_bottom", Rect2(0.0, get_viewport().get_visible_rect().end.y - 90.0, get_viewport().get_visible_rect().size.x, 90.0))
	await _chart_band(band)


## THE STAR CHART'S KEY on the same band (Jon, Nov 11): under the chart and its panel, the map's height,
## the row at the left padding, and nothing of the chart's (LOCAL REGION, the scale bar, the toggles) on it.
func _chart_band(map_band: Rect2) -> void:
	Router.show_starchart()
	for i in 900:
		if not ZoomLadder.busy() and ZoomLadder.chain == &"" and Router.current is StarchartScreen:
			break
		await _tree.process_frame
	await Harness.frames(_tree, 30)
	var cs := Router.current as StarchartScreen
	if not h._ok("the star chart is up", cs != null and cs._key_band != null):
		return
	var band: Rect2 = cs._key_band.get_global_rect()
	var chart: Rect2 = cs._chart.get_global_rect()
	var side: Rect2 = cs.ladder_side().get_global_rect()
	var key: Rect2 = cs._key_row.get_global_rect()
	h._ok("the chart's band is the map's: the same place and size (%s; map %s)" % [band, map_band], band.position.is_equal_approx(map_band.position) and band.size.is_equal_approx(map_band.size))
	h._ok("under the chart and its panel, clear of both (chart %s, panel %s)" % [chart, side], not band.intersects(chart) and not band.intersects(side))
	var pad: float = UITheme.quiet_strip(SectorScreen.DRAWER_A, true).content_margin_left
	h._ok("its KEY row inside it at the left padding (%s; %.1f px in)" % [key, key.position.x - band.position.x], band.encloses(key) and absf(key.position.x - band.position.x - pad) <= 0.5)
	for c: Control in [cs._region_btn, cs._reach_btn, cs._sight_btn]:
		h._ok("%s inside the chart, off the band (%s)" % [c.text, c.get_global_rect()], chart.grow(0.5).encloses(c.get_global_rect()) and not c.get_global_rect().intersects(band))
	h._ok("the scale bar drawn inside the chart, above the band (its line at y %.0f, the band from %.0f)" % [chart.end.y - MapChart.BAR_PAD, band.position.y], chart.end.y - MapChart.BAR_PAD < band.position.y)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join("10_chart_bottom.png"))
	_crop("10_chart_bottom", band.grow_individual(0, 60, 0, 4))


## A 2x crop of a still, nearest-neighbour, beside it.
func _crop(name: String, r: Rect2) -> void:
	var im := Image.load_from_file(_out.path_join(name + ".png"))
	if im == null:
		return
	var ri := Rect2i(r).intersection(Rect2i(Vector2i.ZERO, im.get_size()))
	if ri.size.x <= 0 or ri.size.y <= 0:
		return
	var c := im.get_region(ri)
	c.convert(Image.FORMAT_RGB8)
	c.resize(ri.size.x * 2, ri.size.y * 2, Image.INTERPOLATE_NEAREST)
	c.save_png(_out.path_join(name + "_2x.png"))
