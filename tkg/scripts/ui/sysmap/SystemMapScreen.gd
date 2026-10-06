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
## FLOWN, NOT PARKED (Jon picked the arcade orbits, F, of six mocked): WASD flies
## your ship (`ShipFlight`); a world's ring takes it into orbit when you let go
## inside it slowly, and a place's events open only while you are in orbit of it
## or alongside it. Click once to select a place (the panel shows it, the map
## holds a reticle on it); click it again to fly there on a transfer orbit;
## click empty space to go back to the sector's list (Jon: "click once on an
## object to update the focus of the right panel. click again on an object ...
## travels to that object"). A choice taken anywhere else flies you there first.
## The arrows and a drag pan the view; [ and ] step the events.

signal beacon_opened(body: int, beacon)
signal selection_changed(body: int)

const SystemViewS := preload("res://scripts/ui/sysmap/SystemView.gd")
const SystemOverlayS := preload("res://scripts/ui/sysmap/SystemOverlay.gd")
const SystemPanelS := preload("res://scripts/ui/sysmap/SystemPanel.gd")
const KeyGlyphS := preload("res://scripts/ui/sysmap/KeyGlyph.gd")
const SectorCursorS := preload("res://scripts/ui/sysmap/SectorCursor.gd")
const ShipFlightS := preload("res://scripts/ui/sysmap/ShipFlight.gd")
## The chart's scan: a blip every this many pixels the cursor travels.
const SCAN_STEP := 26.0
const SCAN_LIMIT_MS := 38
## THE CAMERA (Jon: "maybe allow to zoom? and include the same type of distance
## graph ... [ ] LOCATION which would zoom you onto the planet or location you
## are at"). The wheel zooms in steps the chart's size about the cursor, eased;
## a drag pans; LOCATION zooms onto your ship and keeps it in the middle.
const ZOOM_STEP := 1.12
const ZOOM_LOCATION := 2.0
## THE ARROWS PAN at this many screen pixels a second, eased, the same at every zoom.
const PAN_SPEED := 360.0
const LOCATION_LABEL := "LOCATION"
## The scale bar, in AU (80 of the plane's pixels to one, kept when the system
## grew three times wider: the worlds now read 2 to 12 AU, which is what a real
## system's span is), sized like the chart's.
const BAR_STEPS := [0.05, 0.1, 0.2, 0.5, 1.0, 2.0, 5.0, 10.0, 20.0, 50.0]
const BAR_MAX_PX := 140.0
const BAR_PAD := 12.0
const BAR_LABEL_H := 15.0

const MAP := Vector2i(960, 540)
## The KEY's beacons, in the drawer's own order of what matters.
const KEY := [[&"fight", "FIGHT"], [&"hazard", "HAZARD"], [&"salvage", "SALVAGE"],
	[&"signal", "SIGNAL"], [&"contract", "CONTRACT"], [&"quest", "QUEST"], [&"dock", "DOCK"]]

## WHERE THE SHIP WAS LEFT, by system: coming back from a fight, a dock or the
## ship screen puts it back -- in orbit where it was, or where it was flying.
## Not saved -- a reload puts it at the edge, which is where a ship that has
## just arrived would be.
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
## Which choice made that result, and whether the ship flew to make it: the
## result says YOU CHOSE and YOUR SHIP FLEW TO.
var _res_choice := -1
var _res_flew := false
## The beacon the cursor is on, as [body, beacon], so its card lights while it is.
var _lit: Array = []
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
## whether a flight could start, last frame (`ShipFlight.can_fly`)
var _could_fly := false
## LOCATION was let go of by its button or L: glide back out to the whole sector.
var _homing := false
## A CAMERA GLIDE (Jon: "You zoom in and then jolt to the player's location"):
## the zoom and the point looked at, eased together on one curve from where they
## are to where they are going -- {kind ("loc", "body", "home"), body, z0, z1,
## f0 (the point looked at, in the map's zoom-1 pixels), t0, dur}; {} for none
var _glide: Dictionary = {}
## THE PLACE A RIGHT-CLICK ZOOMED ONTO, held in the middle as it moves (-1 the
## star), or -9
var _focus_body := -9
const GLIDE_S := 0.75
## how close a right-click zooms onto a place
const ZOOM_FOCUS := 3.0
## THE SHIP, flown; and the keys held for it, and the arrows held for the view.
var flight
var _wasd := {"w": false, "a": false, "s": false, "d": false}
var _arrows := Vector2.ZERO
var _pan_v := Vector2.ZERO
## What the ship was in orbit of last frame, so the panel follows a change.
var _was_at := -9
## What LOCATION is holding: the ship, or the world it orbits.
var _follow_key := ""
## The zoom that shows the whole system, worked out for its edge and the frame.
var zoom_min := 1.0
## A harness holding keys has no keyboard to check them against.
var harness_keys := false
## WHEN THE PLAYER LAST DID ANYTHING, and last zoomed (the wall clock, s): the
## weather holds still for a zoom, and an idle player gets the next event sooner
## (`SkyWeather`)
var last_input_t := 0.0
var last_zoom_t := -100.0


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
		_cursor.queue_redraw()
		overlay.hover = {}
		_light_from_map({}))
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
	_keep_ship()
	view.t = t0
	overlay.selected = -2
	overlay.hover = {}
	overlay.flight = null
	flight = null
	# every visit opens on the whole sector, then zooms onto you if LOCATION is held
	view.pan = Vector2.ZERO
	_anchor = Vector2(-1, -1)
	_locked = false
	_homing = false
	_glide = {}
	_focus_body = -9
	_tick_level = _zoom_level()
	_tick_from = Time.get_ticks_msec() + 400
	_fill_strip(n)
	_place_map()
	await view.show_system(n)
	last_input_t = Time.get_ticks_msec() / 1000.0
	zoom_min = _fit_zoom()
	view.zoom = zoom_min
	view.home_zoom = zoom_min
	_zoom_to = zoom_min
	# THE SHIP: at the frame's edge as arrived (at the opening zoom), or back where
	# it was left in this system
	flight = ShipFlightS.new()
	var ex := minf(view.layout.edge, (view.window.end.x - view.CX - 26.0) / zoom_min)
	flight.setup(view.layout, Vector2(ex, -210.0), t0)
	if not arrived:
		_restore_ship(_parked.get(n.index, {}))
	overlay.flight = flight
	_was_at = flight.reached()
	# THE WEATHER sees the ship, the labels and the panel; a fresh warp-in pushes
	# a ring into the dust round the ship as the streak ends
	if view._weather != null:
		view._weather.screen = self
		if arrived:
			view._weather.arrive(flight.warp_t)
	# LOCATION held: one glide onto the ship from the whole sector
	if _location_on:
		_glide_to("loc", -9, ZOOM_LOCATION)
	panel.show_system()


## THE ZOOM THAT SHOWS IT ALL: the system's edge with a margin, in the frame.
func _fit_zoom() -> float:
	var L: SystemLayout = view.layout
	var fs := _frame.size if _frame.size.x > 10.0 else Vector2(655, 420)
	return clampf(minf(fs.x / (2.0 * (L.edge + 20.0)), fs.y / (2.0 * (L.edge + 20.0) * view.TILT + 60.0)), 0.1, 1.0)


## Where the ship is, kept for the session when the screen leaves this system.
func _keep_ship() -> void:
	if flight == null or view.node == null:
		return
	var at: int = flight.reached()
	_parked[view.node.index] = {"at": at, "p": flight.f.p, "v": flight.f.v, "head": flight.f.head, "mode": flight.mode}


func _restore_ship(d: Dictionary) -> void:
	if d.is_empty():
		flight.place_at(-3, view.t)
		return
	if int(d.at) >= -1:
		flight.place_at(int(d.at), view.t)
	elif StringName(d.mode) == &"free":
		flight.mode = &"free"
		flight.f.p = d.p
		flight.f.v = Vector2.ZERO
		flight.f.head = d.head
		flight.ang = d.head
	else:
		flight.place_at(-3, view.t)


func _enter_tree() -> void:
	if not Sig.render_style_changed.is_connected(_on_style):
		Sig.render_style_changed.connect(_on_style)


func _exit_tree() -> void:
	_keep_ship()
	Audio.ship_thrust_off()
	if Sig.render_style_changed.is_connected(_on_style):
		Sig.render_style_changed.disconnect(_on_style)


## ANOTHER RENDERING STYLE (`DisplaySettings.render_style`): the system is drawn
## again, its sky baked again in the new style, the ship where it was.
func _on_style() -> void:
	if view != null and view.node != null and is_inside_tree():
		show_system(view.node, view.t, false)


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
	_step_ship(delta)
	_step_camera(delta)
	# THE BELT POINTED AT (or selected) brightens, eased in with the hover
	var lit := -1
	var lt := 0.0
	if overlay.hover.get("kind", &"") == &"belt":
		lit = int(overlay.hover.body)
		lt = overlay._hover_t
	elif overlay.selected >= 0 and view.layout != null and view.layout.bodies[overlay.selected].kind == &"belt":
		lit = overlay.selected
		lt = 0.7
	view.belt_lit = lit
	view.belt_t = lt


## THE SHIP AND THE VIEW, a frame on: the arrows pan (eased), WASD flies, the
## dotted line is run forward, and the panel follows the ship into an orbit.
func _step_ship(delta: float) -> void:
	if flight == null or view.layout == null:
		return
	_settle_keys()
	var free := _transfer == null and is_visible_in_tree()
	var target := -_arrows.normalized() * PAN_SPEED if free else Vector2.ZERO
	_pan_v = _pan_v.lerp(target, 1.0 - exp(-delta * 10.0))
	if _pan_v.length() > 1.0:
		_let_go_of_view()
		view.pan += _pan_v * delta
	var keys: Dictionary = _wasd if free and not _taking else {"w": false, "a": false, "s": false, "d": false}
	var level: float = flight.step(delta, view.t, keys)
	flight.predict(view.t, keys)
	Audio.ship_thrust(level)
	# THE FLIGHT A SECOND CLICK WOULD FLY, drawn before you fly it
	overlay.preview_to = overlay.selected if overlay.selected >= -1 else -9
	# WHETHER A FLIGHT CAN START changed (settled into an orbit, or left one):
	# FLY HERE and the choices say so
	var cf: bool = flight.can_fly()
	if cf != _could_fly:
		_could_fly = cf
		_refresh_panel()
	var now: int = flight.reached()
	if now != _was_at:
		var was := _was_at
		_was_at = now
		if now >= -1 and not _taking:
			# IN ORBIT: the panel opens that place, its events now open; heard
			# even when it was already the one selected -- unless another place
			# was picked on the way, which stays picked (its flight shows now)
			if overlay.selected == now:
				_sound(&"chart_select", 0.04, 60)
			if overlay.selected >= -1 and overlay.selected != now:
				_refresh_panel()
			else:
				select_body(now)
		elif was >= -1 and panel.mode == &"list" and (panel.filter == was or (was == -1 and panel.filter == -2)):
			panel.show_body(panel.filter)


## THE KEYS ARE BINDINGS (`Keys`): the four that fly the ship, by the w/a/s/d
## names `ShipFlight` and `-- sheet=FlightClip` read, and the four that pan the
## view. WASD and the arrows out of the box.
const FLY_KEYS := {&"ship_thrust": "w", &"ship_left": "a", &"ship_brake": "s", &"ship_right": "d"}
const PAN_KEYS := {&"map_left": Vector2.LEFT, &"map_right": Vector2.RIGHT,
	&"map_up": Vector2.UP, &"map_down": Vector2.DOWN}


## A key's release can go missing (a shortcut, a lost window): held keys are
## checked against the keyboard, and can only ever be let go here.
func _settle_keys() -> void:
	if harness_keys:
		return
	for a: StringName in FLY_KEYS:
		if _wasd[FLY_KEYS[a]] and not Keys.held(a):
			_wasd[FLY_KEYS[a]] = false
	if _arrows.x < 0.0 and not Keys.held(&"map_left"):
		_arrows.x = 0.0
	if _arrows.x > 0.0 and not Keys.held(&"map_right"):
		_arrows.x = 0.0
	if _arrows.y < 0.0 and not Keys.held(&"map_up"):
		_arrows.y = 0.0
	if _arrows.y > 0.0 and not Keys.held(&"map_down"):
		_arrows.y = 0.0


## MOVING THE VIEW LETS GO OF LOCATION, as dragging the chart lets go of its
## region; the zoom stays.
func _let_go_of_view() -> void:
	if _location_on:
		_location_on = false
		_locked = false
		_paint_location()
	_homing = false
	_anchor = Vector2(-1, -1)
	_glide = {}
	_focus_body = -9


## The point in the middle of the view, in the map's zoom-1 pixels from the star.
func _look_at() -> Vector2:
	return -view.pan / maxf(view.zoom, 0.0001)


## Where a glide is going, this moment (the ship and the worlds move), in the
## map's zoom-1 pixels from the star.
func _glide_target(kind: String, body: int) -> Vector2:
	var z: float = maxf(view.zoom, 0.0001)
	match kind:
		"loc":
			var on_world: int = int(flight.rail.body) if flight != null and flight.mode == &"rail" and int(flight.rail.body) >= 0 else -9
			return (overlay.place_rel(on_world) if on_world >= 0 else overlay.ship_rel()) / z
		"body":
			return overlay.place_rel(body) / z if body >= 0 else Vector2.ZERO
	return Vector2.ZERO


func _glide_to(kind: String, body: int, z1: float, dur: float = GLIDE_S) -> void:
	last_zoom_t = Time.get_ticks_msec() / 1000.0
	_glide = {"kind": kind, "body": body, "z0": view.zoom, "z1": clampf(z1, zoom_min, view.ZOOM_MAX),
		"f0": _look_at(), "t0": float(Time.get_ticks_msec()) / 1000.0, "dur": dur}
	_zoom_to = float(_glide.z1)
	_anchor = Vector2(-1, -1)
	_homing = false
	_locked = false


## A glide a frame on: the zoom eased geometrically, the point looked at eased
## toward where its target is now, both on the same curve; at the end, held.
## Returns whether one is under way.
func _step_glide() -> bool:
	if _glide.is_empty():
		return false
	var u := clampf((float(Time.get_ticks_msec()) / 1000.0 - float(_glide.t0)) / float(_glide.dur), 0.0, 1.0)
	var e := u * u * (3.0 - 2.0 * u)
	var z0: float = _glide.z0
	var z1: float = _glide.z1
	var z := z0 * pow(z1 / z0, e)
	view.zoom = z
	var f: Vector2 = (_glide.f0 as Vector2).lerp(_glide_target(String(_glide.kind), int(_glide.body)), e)
	view.pan = -f * z
	_zoom_to = z1
	if u >= 1.0:
		match String(_glide.kind):
			"loc":
				_locked = true
				var ow: int = int(flight.rail.body) if flight != null and flight.mode == &"rail" and int(flight.rail.body) >= 0 else -9
				_follow_key = "w%d" % ow if ow >= 0 else "ship"
			"body":
				_focus_body = int(_glide.body)
			"home":
				view.pan = Vector2.ZERO
		_glide = {}
	return true


## RIGHT-CLICK (Jon: "If you right-click a planet that is selected, it should
## zoom the camera onto that planet. A second right-click zooms all the way
## out"): onto the selected place, held there as it moves; again, or on empty
## space, back out to the whole sector. A fixed control (a mouse button: the
## rebindable keys are keys), listed in Settings > CONTROLS.
func right_click(h: Dictionary) -> void:
	var b: int = int(h.get("body", -9)) if not h.is_empty() else -9
	if h.get("kind", &"") == &"star":
		b = -1
	if b >= -1 and b == overlay.selected and b != _focus_body:
		if _location_on:
			_location_on = false
			_paint_location()
		_glide_to("body", b, maxf(ZOOM_FOCUS, view.zoom))
		_focus_body = -9
	elif _focus_body >= -1 or b < -1 or b == _focus_body:
		_focus_body = -9
		_glide_to("home", -9, zoom_min)


func _zoom_level() -> int:
	return roundi(log(maxf(view.zoom, 0.0001)) / log(ZOOM_STEP))


## The zoom eases to where the wheel sent it, pivoting on the point that was
## under the cursor; LOCATION draws the ship to the middle as it goes.
func _step_camera(delta: float) -> void:
	if view.layout == null:
		return
	if _step_glide():
		_tick_zoom()
		return
	var c := Vector2(view.CX, view.CY)
	var z: float = view.zoom
	var a: Vector2 = c if _anchor.x < 0.0 or _homing else _anchor
	if _focus_body >= -1:
		a = c
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
		# eased onto at first, then held exactly, so it does not shake; in orbit of
		# a world, the WORLD, so the camera does not circle with the ship
		var on_world: int = int(flight.rail.body) if flight != null and flight.mode == &"rail" and int(flight.rail.body) >= 0 else -9
		var key := "w%d" % on_world if on_world >= 0 else "ship"
		if key != _follow_key:
			_follow_key = key
			# ONTO THE WORLD (or back to the ship): glided across, not chased
			if _locked:
				_glide_to("loc", -9, view.zoom, 0.5)
				_step_glide()
				return
			_locked = false
		var target: Vector2 = -(overlay.place_rel(on_world) if on_world >= 0 else overlay.ship_rel())
		if _locked:
			view.pan = target
		else:
			view.pan = view.pan.lerp(target, 1.0 - exp(-delta * 8.0))
			if view.pan.distance_to(target) < 0.5:
				_locked = true
	elif _focus_body >= -1:
		# HELD ON THE PLACE A RIGHT-CLICK ZOOMED ONTO, as it goes round
		view.pan = -_glide_target("body", _focus_body) * view.zoom
	else:
		if _homing:
			view.pan = view.pan.lerp(Vector2.ZERO, 1.0 - exp(-delta * 8.0))
			if view.pan.length() < 0.25 and absf(view.zoom - zoom_min) < 0.002:
				view.pan = Vector2.ZERO
				_homing = false
		_clamp_pan()
	_tick_zoom()


## The zoom's tick, a level at a time.
func _tick_zoom() -> void:
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
	last_zoom_t = Time.get_ticks_msec() / 1000.0
	# a glide under way ends where it is, the wheel taking over
	if not _glide.is_empty():
		_glide = {}
		_zoom_to = view.zoom
	_zoom_to = clampf(_zoom_to * f, zoom_min, view.ZOOM_MAX)
	_anchor = at
	_homing = false


## LOCATION, by its button or L. On, it zooms onto your ship and holds it;
## off, it glides back out to the whole sector (Jon: "unclicking location should
## zoom you all the way out").
func _on_location() -> void:
	_location_on = not _location_on
	_paint_location()
	_locked = false
	_focus_body = -9
	# ONE SMOOTH MOVE each way: zoom and the point looked at together
	if _location_on:
		_glide_to("loc", -9, ZOOM_LOCATION)
	else:
		_glide_to("home", -9, zoom_min)


## L FOR LOCATION, as on the star chart (`StarchartScreen._unhandled_key_input`).
## WASD and the arrows are HELD (a state, not a press: two keys move diagonally
## and letting one go leaves the other running), as on the star chart.
func _unhandled_key_input(e: InputEvent) -> void:
	var k := e as InputEventKey
	if k == null or k.echo:
		return
	last_input_t = Time.get_ticks_msec() / 1000.0
	if _transfer != null or not is_visible_in_tree():
		return
	# A direction with two keys keeps going while the other is still down.
	for a: StringName in FLY_KEYS:
		if k.is_action(a):
			_wasd[FLY_KEYS[a]] = k.pressed or Keys.held(a)
			accept_event()
			return
	var arrow := Vector2.ZERO
	for a: StringName in PAN_KEYS:
		if k.is_action(a):
			if not k.pressed and Keys.held(a):
				accept_event()
				return
			arrow = PAN_KEYS[a]
			break
	if arrow != Vector2.ZERO:
		# THE ARROWS PAN THE VIEW (Jon: "can the arrow keys pan the view?")
		if k.pressed:
			_arrows = (_arrows + arrow).clamp(-Vector2.ONE, Vector2.ONE)
		elif arrow.x != 0.0 and signf(_arrows.x) == arrow.x:
			_arrows.x = 0.0
		elif arrow.y != 0.0 and signf(_arrows.y) == arrow.y:
			_arrows.y = 0.0
		accept_event()
		return
	if not k.pressed:
		return
	if k.is_action_pressed(&"map_location"):
		_on_location()
		accept_event()
	elif k.is_action_pressed(&"event_prev") or k.is_action_pressed(&"event_next"):
		# [ AND ] STEP THE EVENTS (the arrows pan now), as the panel's < and > do
		panel.step(-1 if k.is_action_pressed(&"event_prev") else 1)
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
	last_input_t = Time.get_ticks_msec() / 1000.0
	if _transfer != null or _taking:
		return
	if e is InputEventMouseMotion:
		var mm := e as InputEventMouseMotion
		if _dragging:
			if mm.position.distance_to(_press_at) > 3.0:
				_drag_moved = true
			if _drag_moved:
				view.pan += mm.position - _drag_from
				_let_go_of_view()
				_clamp_pan()
			_drag_from = mm.position
		overlay.hover = overlay.hit(_map_at(mm.position))
		_light_from_map(overlay.hover)
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
				# A PRESS THAT MOVES MORE THAN 3 PX IS A DRAG, and pans; one that does
				# not is a click, decided when it lets go
				if mb.pressed:
					_dragging = true
					_drag_from = mb.position
					_press_at = mb.position
					_drag_moved = false
				else:
					if _dragging and not _drag_moved:
						tap(overlay.hit(_map_at(mb.position)))
					_dragging = false
			MOUSE_BUTTON_MIDDLE:
				_dragging = mb.pressed
			MOUSE_BUTTON_RIGHT:
				if mb.pressed:
					right_click(overlay.hit(_map_at(mb.position)))
				_drag_from = mb.position
				_press_at = mb.position
				_drag_moved = true
		_frame.accept_event()


# ---------------------------------------------------------------- panel calls
## ONE CLICK SELECTS (the panel shows the place, the map holds a reticle on it);
## A SECOND CLICK ON THE SELECTION FLIES THERE; empty space goes back to the list.
## A beacon selects its world with its event open; clicked again, it flies.
func tap(h: Dictionary) -> void:
	if h.is_empty():
		panel_back()
		return
	var body: int = h.body
	var again: bool = overlay.selected == body and (h.kind != &"beacon" or panel.mode != &"list")
	if again:
		# A FLIGHT STARTS ONLY FROM AN ORBIT: on the way, or under thrust, a click
		# selects and no more
		if flight.orbit_body() != body and flight.can_fly():
			fly_to_body(body)
		return
	if h.kind == &"beacon":
		open_beacon(h.body, h.beacon)
	else:
		select_body(body)


## Whether the ship is in orbit of (or alongside) place i: its events are open.
func ship_reached(i: int) -> bool:
	return flight != null and flight.reached() == i


func select_body(i: int) -> void:
	if i != overlay.selected:
		_sound(&"chart_select", 0.04, 60)
	overlay.selected = i
	selection_changed.emit(i)
	panel.show_body(i)


## Opens a beacon in the panel: an encounter's page, or for DOCK, HARVEST and
## the custodian the list narrowed to where it is, its card holding the button.
## The pulsar's own beacon (body -1) is on the star.
## OPENS IT, AND ONLY THAT (Jon: "clicking on a beacon and immediately moving
## there is kinda disorienting"): the encounter comes up in the panel and its
## world is selected; the ship stays put until you choose something.
func open_beacon(body: int, bc) -> void:
	_sound(&"chart_select", 0.04, 60)
	overlay.selected = body
	beacon_opened.emit(body, bc)
	panel.show_beacon(body, bc)


## THE TRIP COMES WITH THE CHOICE: into orbit of `body` (or alongside it) and then
## do `then`, or just do it if the ship is already there. The map takes no
## clicks on the way.
func _go_then(body: int, then: Callable) -> void:
	if flight.reached() == body:
		then.call()
		return
	# ONLY OUT OF AN ORBIT (Jon: "You have to be IN AN ORBIT ... AND THEN CLICK
	# to go to another planet"): anywhere else the panel says so and nothing flies
	if not flight.can_fly():
		return
	_taking = true
	_fly(body, func() -> void:
		_taking = false
		then.call())


## A flight. Heard on the thrust loop, as every burn is (`ShipFlight.step`): the
## station's arrival flameout used to play here, and its gated sputter was the
## ticking Jon heard as each flight ended ("still getting a ticking noise when
## the thruster is activated or ends").
func _fly(body: int, done: Callable) -> void:
	# LANDING IS THE FLIGHT'S OWN BUSINESS: the callback decides what the panel
	# shows (a choice's result, or the place), so the frame's own "arrived in
	# orbit" must not open the place over it
	# the flight drawn before it is the one flown: the preview's own choice
	var prefer: Dictionary = overlay._pv_choice if overlay.preview_to == body else {}
	var pl = flight.fly(body, view.t, func() -> void:
		_was_at = flight.reached()
		_sound(&"chart_select", 0.04, 60)
		done.call(), prefer)
	if pl == null:
		# no manoeuvre would solve (the flight measure has never seen it): put the
		# ship in orbit there rather than leave the choice hanging
		flight.place_at(body, view.t)
		_was_at = flight.reached()
		done.call()
		return
	_was_at = -9


## The panel drawn again as it stands (a place's list, or an event's page).
func _refresh_panel() -> void:
	if panel.mode == &"list":
		if panel.filter == -2:
			panel.show_system()
		else:
			panel.show_body(panel.filter)
	elif panel.mode == &"event":
		panel.open_page(panel.open_opt)


## Which body holds beacon `bc` (-1 the star, for the pulsar's own).
func _body_of_beacon(bc) -> int:
	if bc == null:
		return -1
	for bi in view.layout.bodies.size():
		if view.layout.bodies[bi].beacons.has(bc):
			return bi
	return -1


## Your ship into orbit of place `i` (-1 the star), or alongside it; the panel
## stays on it and opens it there.
func fly_to_body(i: int) -> void:
	if _taking or not flight.can_fly():
		return
	_sound(&"chart_select", 0.04, 60)
	overlay.selected = i
	# ARRIVED: the place opens -- unless another was picked on the way, which
	# stays picked, its flight drawn now the ship is in orbit
	_fly(i, func() -> void:
		if overlay.selected == i or overlay.selected < -1:
			select_body(i)
		else:
			_refresh_panel())


## Option k's page, as clicking its beacon opens it: the panel's < and >, NEXT
## and CHOOSE AGAIN, and the arrow keys.
func open_option(k: int) -> void:
	for bi in view.layout.bodies.size():
		for bc in view.layout.bodies[bi].beacons:
			if bc.opt == k:
				open_beacon(bi, bc)
				return


## A card pointed at in the panel lights its beacon on the map, as pointing at
## the beacon would.
func card_hover(body: int, bc, on: bool) -> void:
	overlay.link_on = on
	overlay.linked = bc
	overlay.link_body = body


## The cursor on a beacon lights its card, and its rivals grey, as pointing at
## the card would. Only on a change, so the panel is not touched every frame.
func _light_from_map(h: Dictionary) -> void:
	var now: Array = [h.body, h.beacon] if h.get("kind", &"") == &"beacon" else []
	if now == _lit:
		return
	if not _lit.is_empty():
		panel.light(_lit[1], false)
	_lit = now
	if not _lit.is_empty():
		panel.light(_lit[1], true)


func panel_back() -> void:
	_res_opt = -1
	overlay.selected = -2
	overlay.link_on = false
	_lit = []
	panel.show_system()


func take_choice(i: int, j: int) -> void:
	if _taking:
		return
	var n: MapGen.MapNode = view.node
	var c: Dictionary = (OptionTable.by_id(n.options[i]).get("choices", []) as Array)[j]
	if not OptionResolve.affordable(c):
		return
	_res_choice = j
	_res_flew = false
	# WALKING AWAY GOES NOWHERE; anything else, the ship flies there first
	if bool(c.get("stay", false)):
		_resolve(i, j)
		return
	var body := -1
	for bi in view.layout.bodies.size():
		for bc in view.layout.bodies[bi].beacons:
			if bc.opt == i:
				body = bi
		_res_flew = flight.reached() != body
	overlay.link_on = false
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
