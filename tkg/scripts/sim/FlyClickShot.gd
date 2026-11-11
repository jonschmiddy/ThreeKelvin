extends Node

## STILLS OF THE SECOND CLICK (F-C, Nov 11), windowed: `-- sheet=FlyClickShot out=<dir>`.
## Seed 4242's first one-sun system with two worlds, in orbit of the first: pointing at the
## other world unselected; selected and pointed at (the line lit, the tag's CLICK AGAIN · time);
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
	# 2. selected and pointed at: the line lit, the sight, CLICK AGAIN: FLY · N S
	m.select_body(w1)
	_point(m, m.view.at[w1])
	for f in 600:
		_point(m, m.view.at[w1])
		if m.overlay.fly_s(w1) > 0:
			break
		await _tree.process_frame
	h._ok("the tag gives the flight's time (%d s)" % m.overlay.fly_s(w1), m.overlay.fly_s(w1) > 0)
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
	h._ok("the KEY row inside it, centred (%s; off by %.1f px)" % [key, absf(key.get_center().x - band.get_center().x)], band.encloses(key) and absf(key.get_center().x - band.get_center().x) <= 1.0)
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
		_crop("7_local_bottom", sc._quiet_wrap.get_global_rect().grow_individual(0, 60, 0, 4))


## A 2x crop of a still, nearest-neighbour, beside it.
func _crop(name: String, r: Rect2) -> void:
	var im := Image.load_from_file(_out.path_join(name + ".png"))
	if im == null:
		return
	var ri := Rect2i(r).intersection(Rect2i(Vector2i.ZERO, im.get_size()))
	var c := im.get_region(ri)
	c.resize(ri.size.x * 2, ri.size.y * 2, Image.INTERPOLATE_NEAREST)
	c.save_png(_out.path_join(name + "_2x.png"))
