class_name SystemMapScreen
extends Control

## THE SECTOR MAP (Jon: "a system map like Starfield's"): the system's star and
## the worlds going round it, a beacon on whatever holds an encounter, your ship
## among them. The picture is `SystemView`; what is drawn over it -- beacons,
## selection, ship, hover tip -- is `SystemOverlay`; the panel holds the sector,
## a body, or an encounter (`SystemPanel`).
##
## LAID OUT LIKE THE STAR CHART (Jon: "style the system page like the starchart
## page"): a strip along the top, the map framed on the left with the star in
## the middle of it, the panel on the right with the way on at its foot, and a
## KEY along the bottom.
##
## THE MAP DRAWS INTO ITS OWN 960x540 PICTURE, shown in the frame. Its shadows,
## palette, lens and star masks all read pixels off the screen, and a screen
## that is the map's own cannot sit anywhere but where the map thinks it is.
## Drawn straight into the game's picture it sat ten pixels under where it
## assumed, because the HUD had grown, and every planet's shadow came off it
## crooked (Jon: "the shadow of the planet being delayed").
##
## Clicking a beacon flies your ship to its body in about a second and then
## opens it; clicking a world or the star selects it; clicking empty space
## selects the star (Jon: "when clicking on empty space, let's just have the star
## selected").

signal beacon_opened(body: int, beacon)
signal selection_changed(body: int)

const SystemViewS := preload("res://scripts/ui/sysmap/SystemView.gd")
const SystemOverlayS := preload("res://scripts/ui/sysmap/SystemOverlay.gd")
const SystemPanelS := preload("res://scripts/ui/sysmap/SystemPanel.gd")
const KeyGlyphS := preload("res://scripts/ui/sysmap/KeyGlyph.gd")
const SectorCursorS := preload("res://scripts/ui/sysmap/SectorCursor.gd")
## The chart's scan: a blip every this many pixels the cursor travels.
const SCAN_STEP := 26.0
const SCAN_LIMIT_MS := 38
## THE CAMERA (Jon: "maybe allow to zoom? and include the same type of distance
## graph ... [ ] LOCATION which would zoom you onto the planet or location you
## are at"). The wheel zooms in steps the chart's size about the cursor, eased;
## a drag pans; LOCATION zooms onto your ship and keeps it in the middle.
const ZOOM_STEP := 1.12
const ZOOM_LOCATION := 3.0
const LOCATION_LABEL := "LOCATION"
## The scale bar, in AU (80 of the plane's pixels to one), sized like the chart's.
const BAR_STEPS := [0.05, 0.1, 0.2, 0.5, 1.0, 2.0, 5.0, 10.0]
const BAR_MAX_PX := 140.0
const BAR_PAD := 12.0
const BAR_LABEL_H := 15.0

const MAP := Vector2i(960, 540)
## The KEY's beacons, in the drawer's own order of what matters.
const KEY := [[&"fight", "FIGHT"], [&"hazard", "HAZARD"], [&"salvage", "SALVAGE"],
	[&"signal", "SIGNAL"], [&"contract", "CONTRACT"], [&"quest", "QUEST"], [&"dock", "DOCK"]]

## WHERE THE SHIP WAS LEFT, by system: coming back from a fight, a dock or the
## ship screen puts it at the body it last flew to. Not saved -- a reload puts
## it at the edge, which is where a ship that has just arrived would be.
static var _parked := {}
## LOCATION is held for the session, across screens and systems, like the
## chart's LOCAL REGION: on, every arrival zooms onto your ship.
static var _location_on := false

var view
var overlay
var panel
## A harness can hold the clock still.
var frozen := false
var _frame: Control
var _box: SubViewportContainer
var _vp: SubViewport
var _strip: HBoxContainer
var _transfer: TransferView = null
## The option whose result is showing, for REWARD.
var _res_opt := -1
var _res_out: Dictionary = {}
var _taking := false
var _cursor: Node2D
var _scan_px := 0.0
var _zoom_to := 1.0
## The map point a wheel zoom pivots on; x < 0 for the frame's middle.
var _anchor := Vector2(-1, -1)
var _dragging := false
var _drag_from := Vector2.ZERO
var _press_at := Vector2.ZERO
var _drag_moved := false
var _tick_level := 0
var _tick_from := 0
var _loc_btn: Button
## LOCATION has reached the ship and now holds it exactly, rather than chasing.
var _locked := false
## LOCATION was let go of by its button or L: glide back out to the whole sector.
var _homing := false


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 4)
	add_child(root)

	_strip = HBoxContainer.new()
	_strip.add_theme_constant_override("separation", 7)
	root.add_child(_strip)

	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 5)
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(mid)

	_frame = Control.new()
	_frame.clip_contents = true
	_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_frame.gui_input.connect(_on_map_input)
	_frame.resized.connect(_place_map)
	_frame.mouse_exited.connect(func() -> void:
		_cursor.set("at", Vector2(-1, -1))
		_cursor.queue_redraw())
	var wrap := Widgets.panel_with(_frame)
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_child(wrap)
	_box = SubViewportContainer.new()
	_box.stretch = false
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.size = Vector2(MAP)
	_frame.add_child(_box)
	_vp = SubViewport.new()
	_vp.size = MAP
	_vp.transparent_bg = false
	_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_vp.snap_2d_transforms_to_pixel = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_box.add_child(_vp)
	view = SystemViewS.new()
	_vp.add_child(view)
	_cursor = SectorCursorS.new()
	_cursor.set("view", view)
	_vp.add_child(_cursor)
	overlay = SystemOverlayS.new()
	overlay.view = view
	_vp.add_child(overlay)
	# THE INSTRUMENT, over the picture in the frame: the scale bar and LOCATION
	var bar := _Scale.new()
	bar.screen = self
	bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(bar)
	_loc_btn = Widgets.button("", _on_location)
	_loc_btn.add_theme_font_size_override("font_size", UITheme.FS_SMALL)
	_loc_btn.add_theme_color_override("font_hover_color", UITheme.ICE)
	_loc_btn.add_theme_color_override("font_pressed_color", UITheme.HOT)
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		_loc_btn.add_theme_stylebox_override(st, UITheme.empty())
	# BOTTOM RIGHT, where the chart keeps its LOCAL REGION and its scale
	_loc_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_loc_btn.offset_left = -(112.0 + BAR_PAD)
	_loc_btn.offset_right = -BAR_PAD
	_loc_btn.offset_top = -(14.0 + BAR_PAD + BAR_LABEL_H)
	_loc_btn.offset_bottom = -(BAR_PAD + BAR_LABEL_H)
	_loc_btn.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_frame.add_child(_loc_btn)
	_paint_location()

	panel = SystemPanelS.new()
	panel.screen = self
	mid.add_child(Widgets.panel_with(panel))

	var key := HBoxContainer.new()
	key.add_theme_constant_override("separation", 8)
	key.add_child(UITheme.body("KEY", UITheme.COLD, UITheme.FS_SMALL))
	for k in KEY:
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 3)
		var g: Control = KeyGlyphS.new()
		g.set("glyph", k[0])
		g.set("colour", key_colour(k[0]))
		item.add_child(g)
		item.add_child(UITheme.body(k[1], UITheme.COLD, UITheme.FS_SMALL))
		key.add_child(item)
	root.add_child(key)


## A beacon kind's colour: the drawer's tag colours, and the dock in ice.
static func key_colour(tag: StringName) -> Color:
	if tag == &"dock":
		return UITheme.ICE
	return EncounterDrawer.tag_colour({"tags": [tag]})


## THE STAR IN THE MIDDLE OF THE FRAME (Jon: "can we center the star"),
## whatever size the frame is.
func _place_map() -> void:
	var at: Vector2 = (_frame.size / 2.0 - Vector2(view.CX, view.CY)).round()
	_box.position = at
	view.window = Rect2(-at, _frame.size)


## `arrived`: the ship has just jumped in, so it warps in at the edge.
func show_system(n: MapGen.MapNode, t0: float = 0.0, arrived: bool = true) -> void:
	view.t = t0
	overlay.selected = -2
	overlay.hover = {}
	overlay.ship_park = -3 if arrived else int(_parked.get(n.index, -3))
	overlay.ship_fly_t0 = -1.0
	overlay.ship_warp_t = t0 if arrived else -100.0
	# every visit opens on the whole sector, then zooms onto you if LOCATION is held
	view.zoom = 1.0
	view.pan = Vector2.ZERO
	_zoom_to = ZOOM_LOCATION if _location_on else 1.0
	_anchor = Vector2(-1, -1)
	_locked = false
	_homing = false
	_tick_level = _zoom_level()
	_tick_from = Time.get_ticks_msec() + 400
	_fill_strip(n)
	_place_map()
	await view.show_system(n)
	panel.show_system()


## The chart's strip, for this sector: how dangerous it is. What it is goes in
## the panel.
func _fill_strip(n: MapGen.MapNode) -> void:
	Widgets.clear(_strip)
	_strip.add_child(UITheme.body("DANGER", UITheme.COLD, UITheme.FS_SMALL))
	var g := StarchartScreen.MicroGauge.new()
	g.setup(MapGen.DANGER_MAX, n.danger, StarchartScreen.MicroGauge.Mode.DANGER)
	_strip.add_child(g)
	_strip.add_child(UITheme.body(MapGen.tier_name(n.danger),
		UITheme.WARN if n.danger >= 7 else UITheme.COLD, UITheme.FS_SMALL))


func _process(delta: float) -> void:
	if not frozen:
		view.t += delta
	_step_camera(delta)


func _zoom_level() -> int:
	return roundi(log(maxf(view.zoom, 0.0001)) / log(ZOOM_STEP))


## The zoom eases to where the wheel sent it, pivoting on the point that was
## under the cursor; LOCATION draws the ship to the middle as it goes.
func _step_camera(delta: float) -> void:
	if view.layout == null:
		return
	var c := Vector2(view.CX, view.CY)
	var z: float = view.zoom
	var a: Vector2 = c if _anchor.x < 0.0 or _homing else _anchor
	if absf(z - _zoom_to) > 0.0005:
		var nz := lerpf(z, _zoom_to, 1.0 - exp(-delta * 14.0))
		if absf(nz - _zoom_to) < 0.002:
			nz = _zoom_to
		if not _location_on:
			var o: Vector2 = c + view.pan
			view.pan = a + (o - a) * (nz / z) - c
		view.zoom = nz
	if _location_on:
		# THE SHIP, worked out from its orbit at this moment and at this zoom:
		# eased onto at first, then held exactly, so it does not shake
		var target: Vector2 = -overlay.ship_rel()
		if _locked:
			view.pan = target
		else:
			view.pan = view.pan.lerp(target, 1.0 - exp(-delta * 8.0))
			if view.pan.distance_to(target) < 0.5:
				_locked = true
	else:
		if _homing:
			view.pan = view.pan.lerp(Vector2.ZERO, 1.0 - exp(-delta * 8.0))
			if view.pan.length() < 0.25 and absf(view.zoom - 1.0) < 0.002:
				view.pan = Vector2.ZERO
				_homing = false
		_clamp_pan()
	var level := _zoom_level()
	if level != _tick_level:
		if Time.get_ticks_msec() >= _tick_from:
			_sound(&"chart_tick", 0.03, 28)
		_tick_level = level


## Far enough to look round the edge of the sector, never off it.
func _clamp_pan() -> void:
	var L: SystemLayout = view.layout
	if L == null:
		return
	var z: float = view.zoom
	var reach := Vector2((L.edge + 40.0) * z, ((L.edge + 40.0) * view.TILT + 40.0) * z)
	var lim := (reach - _frame.size * 0.25).max(Vector2.ZERO)
	view.pan = view.pan.clamp(-lim, lim)


func _zoom_by(f: float, at: Vector2) -> void:
	_zoom_to = clampf(_zoom_to * f, 1.0, view.ZOOM_MAX)
	_anchor = at
	_homing = false


## LOCATION, by its button or L. On, it zooms onto your ship and holds it;
## off, it glides back out to the whole sector (Jon: "unclicking location should
## zoom you all the way out").
func _on_location() -> void:
	_location_on = not _location_on
	_paint_location()
	_locked = false
	if _location_on:
		_zoom_to = ZOOM_LOCATION
		_homing = false
	else:
		_zoom_to = 1.0
		_anchor = Vector2(-1, -1)
		_homing = true


## L FOR LOCATION, as on the star chart (`StarchartScreen._unhandled_key_input`).
func _unhandled_key_input(e: InputEvent) -> void:
	var k := e as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if _transfer != null or not is_visible_in_tree():
		return
	if k.keycode == KEY_L:
		_on_location()
		accept_event()
	elif k.keycode == KEY_LEFT or k.keycode == KEY_RIGHT:
		step_body(-1 if k.keycode == KEY_LEFT else 1)
		accept_event()


func _paint_location() -> void:
	Widgets.paint_toggle(_loc_btn, LOCATION_LABEL, _location_on)


## The chart's instrument sounds, guarded on the file as the chart guards them.
static func _sound(name: StringName, vary: float, limit_ms: int) -> void:
	if ResourceLoader.exists(Audio.SFX_PATH % name):
		Audio.play(name, vary, limit_ms)


## A point in the frame, as a point on the map.
func _map_at(p: Vector2) -> Vector2:
	return p - _box.position


func _on_map_input(e: InputEvent) -> void:
	if _transfer != null or _taking:
		return
	if e is InputEventMouseMotion:
		var mm := e as InputEventMouseMotion
		if _dragging:
			view.pan += mm.position - _drag_from
			_drag_from = mm.position
			if mm.position.distance_to(_press_at) > 3.0:
				_drag_moved = true
			# MOVING THE VIEW LETS GO OF LOCATION, as dragging the chart lets go
			# of its region
			if _drag_moved and _location_on:
				_location_on = false
				_locked = false
				_paint_location()
			_homing = false
			_clamp_pan()
		overlay.hover = overlay.hit(_map_at(mm.position))
		# THE CHART'S SCAN: the cursor moves, and every so far it blips
		_cursor.set("at", _map_at(mm.position))
		_cursor.queue_redraw()
		_scan_px += mm.relative.length()
		if _scan_px >= SCAN_STEP:
			_scan_px = fmod(_scan_px, SCAN_STEP)
			_sound(&"chart_scan", 0.08, SCAN_LIMIT_MS)
	elif e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					_zoom_by(ZOOM_STEP, _map_at(mb.position))
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					_zoom_by(1.0 / ZOOM_STEP, _map_at(mb.position))
			MOUSE_BUTTON_LEFT:
				if mb.pressed:
					var h: Dictionary = overlay.hit(_map_at(mb.position))
					if h.is_empty():
						# empty space: a drag pans; a click selects the star
						_dragging = true
						_drag_from = mb.position
						_press_at = mb.position
						_drag_moved = false
					elif h.kind == &"star":
						select_body(-1)
					elif h.kind == &"body":
						select_body(h.body)
					else:
						open_beacon(h.body, h.beacon)
				else:
					if _dragging and not _drag_moved:
						select_body(-1)
					_dragging = false
			MOUSE_BUTTON_MIDDLE:
				_dragging = mb.pressed
				_drag_from = mb.position
				_press_at = mb.position
				_drag_moved = true
		_frame.accept_event()


# ---------------------------------------------------------------- panel calls
func select_body(i: int) -> void:
	if i != overlay.selected:
		_sound(&"chart_select", 0.04, 60)
	overlay.selected = i
	selection_changed.emit(i)
	panel.show_body(i)


## Flies the ship to the beacon's body, then opens it. The pulsar's own beacon
## (body -1) is on the star.
## OPENS IT, AND ONLY THAT (Jon: "clicking on a beacon and immediately moving
## there is kinda disorienting"): the encounter comes up in the panel and its
## world is selected; the ship stays put until you choose something.
func open_beacon(body: int, bc) -> void:
	_sound(&"chart_select", 0.04, 60)
	overlay.selected = body
	beacon_opened.emit(body, bc)
	panel.show_beacon(body, bc)


## THE TRIP COMES WITH THE CHOICE: fly to `body` and then do `then`, or just do
## it if the ship is already parked there. The map takes no clicks on the way.
func _go_then(body: int, then: Callable) -> void:
	if overlay.ship_park == body and overlay.ship_fly_t0 < 0.0:
		then.call()
		return
	_taking = true
	_parked[view.node.index] = body
	overlay.fly_to(body, func() -> void:
		_taking = false
		then.call())


## Which body holds beacon `bc` (-1 the star, for the pulsar's own).
func _body_of_beacon(bc) -> int:
	if bc == null:
		return -1
	for bi in view.layout.bodies.size():
		if view.layout.bodies[bi].beacons.has(bc):
			return bi
	return -1


## Your ship to body `i` (-1 the star), parked there; the panel stays on it.
func fly_to_body(i: int) -> void:
	_sound(&"chart_select", 0.04, 60)
	overlay.selected = i
	_parked[view.node.index] = i
	overlay.fly_to(i, func() -> void:
		if overlay.selected == i:
			panel.show_body(i))


## The star and the bodies in orbit order, round and round: the panel's < and >
## and the arrow keys.
func step_body(d: int) -> void:
	var n: int = view.layout.bodies.size()
	var cur: int = overlay.selected if overlay.selected >= -1 else -1
	var nxt := cur + d
	if nxt >= n:
		nxt = -1
	elif nxt < -1:
		nxt = n - 1
	select_body(nxt)


func panel_back() -> void:
	_res_opt = -1
	overlay.selected = -2
	panel.show_system()


func take_choice(i: int, j: int) -> void:
	if _taking:
		return
	var n: MapGen.MapNode = view.node
	var c: Dictionary = (OptionTable.by_id(n.options[i]).get("choices", []) as Array)[j]
	if not OptionResolve.affordable(c):
		return
	# WALKING AWAY GOES NOWHERE; anything else, the ship flies there first
	if bool(c.get("stay", false)):
		_resolve(i, j)
		return
	var body := -1
	for bi in view.layout.bodies.size():
		for bc in view.layout.bodies[bi].beacons:
			if bc.opt == i:
				body = bi
	_go_then(body, func() -> void: _resolve(i, j))


func _resolve(i: int, j: int) -> void:
	var n: MapGen.MapNode = view.node
	_taking = true
	var out: Dictionary = await OptionResolve.take(n, i, j)
	_taking = false
	if not out.ok:
		if out.why == "too_late":
			panel.show_system()
		return
	if out.dead:
		Router.show_game_over()
		return
	if out.fight_now:
		Router.start_ambush()
		return
	_res_opt = i
	_res_out = out
	panel.show_result(i, out)


## DOCK, HARVEST and the custodian: the same doors the sector's action button
## opens (`SectorScreen._on_action`).
func take_action(bc) -> void:
	if _taking:
		return
	_go_then(_body_of_beacon(bc), func() -> void: _act(bc))


func _act(bc) -> void:
	var n: MapGen.MapNode = view.node
	if Run.dead:
		Router.show_game_over()
		return
	if bc == null:
		if not n.cleared:
			Router.harvest_pulsar()
	elif bc.dock:
		Router.show_station()
	elif bc.core:
		if not (n.cleared or n.fled):
			Router.engage_here()


## The found hull, as the sector's rail handles it (`SectorScreen._on_salvage`).
func on_hull(what: String, h: Variant) -> void:
	match what:
		"take_hull":
			Audio.act(&"hull_transfer")
			Run.transfer_to_hull(h as HullData)
		"leave_hull":
			Run.found_hull = null
	panel.show_system()


func hush_hull() -> void:
	Run.salvage_hushed_hauls = Run.hauls
	Run.salvage_hushed_bag = bag_here()
	panel.show_system()


func bag_here() -> int:
	var n: MapGen.MapNode = view.node
	return n.index if Run.bag_left(n) > 0 else -1


func plot_next_jump() -> void:
	Router.show_starchart()


func open_sector_loot() -> void:
	_open_jetsam(Run.sector_jetsam(view.node, false))


func open_prize() -> void:
	_open_jetsam(Run.sector_jetsam(view.node, false), "REWARD")


func _open_jetsam(h: MapGen.Jetsam, title: String = "") -> void:
	if _transfer != null or h == null:
		return
	_transfer = TransferView.new()
	add_child(_transfer)
	Audio.play(&"wreck_open")
	_transfer.setup(h, view.node, _close_transfer, true, title)


func _close_transfer() -> void:
	if _transfer == null:
		return
	_transfer.queue_free()
	_transfer = null
	# REWARD greys once the pile is empty, so the result is drawn again.
	if _res_opt >= 0:
		panel.show_result(_res_opt, _res_out)


## THE SCALE BAR, the chart's (`MapChart._draw_scale`) in the bottom-right corner
## and in AU: the longest round distance that fits, and its name.
class _Scale extends Control:
	var screen

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var per_au: float = 80.0 * screen.view.zoom
		var au := 0.0
		for st in BAR_STEPS:
			if float(st) * per_au <= BAR_MAX_PX:
				au = float(st)
		if au <= 0.0:
			au = float(BAR_STEPS[0])
		var w := minf(au * per_au, BAR_MAX_PX)
		var x := size.x - BAR_PAD - w
		var y := size.y - BAR_PAD
		var ink := UITheme.COLD
		draw_line(Vector2(x, y), Vector2(x + w, y), ink, 1.0)
		draw_line(Vector2(x, y - 4.0), Vector2(x, y + 1.0), ink, 1.0)
		draw_line(Vector2(x + w, y - 4.0), Vector2(x + w, y + 1.0), ink, 1.0)
		var txt := "%d AU" % int(au) if au >= 1.0 else ("%.2f" % au).trim_suffix("0") + " AU"
		draw_string(UITheme.pixel_font(), Vector2(x + w - BAR_MAX_PX, y - 7.0), txt,
			HORIZONTAL_ALIGNMENT_RIGHT, BAR_MAX_PX, 8, ink)
