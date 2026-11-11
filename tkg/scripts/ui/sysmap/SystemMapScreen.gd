class_name SystemMapScreen
extends Control

## The sector map: a Starfield-like system view laid out like the star chart (Jon).
## Drawn into its own 960x540 picture, as its shaders read pixels at a fixed position.
## Why: docs/why/SystemMapScreen.md#sector-map

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
## Camera: the wheel zooms about the cursor, a drag pans, LOCATION holds on your ship.
const ZOOM_STEP := 1.12
const ZOOM_LOCATION := 2.0
## THE ARROWS PAN at this many screen pixels a second, eased, the same at every zoom.
const PAN_SPEED := 360.0
const LOCATION_LABEL := "LOCATION"
## Scale bar: 80 plane pixels per AU, kept when systems grew three times wider.
const BAR_STEPS := [0.05, 0.1, 0.2, 0.5, 1.0, 2.0, 5.0, 10.0, 20.0, 50.0]
const BAR_MAX_PX := 140.0
const BAR_PAD := 12.0
const BAR_LABEL_H := 15.0

const MAP := Vector2i(960, 540)
## The KEY's beacons, in the drawer's own order of what matters.
const KEY := [[&"fight", "FIGHT"], [&"hazard", "HAZARD"], [&"salvage", "SALVAGE"],
	[&"science", "SCIENCE"], [&"signal", "SIGNAL"], [&"contract", "CONTRACT"], [&"quest", "QUEST"], [&"dock", "DOCK"]]

## Where the ship was left, by system. Saved with the run; per player, not on the wire.
static var _parked := {}
## Where the map last flew the ship; LOCAL plays its arrival once a flight (Jon, Oct 21).
static var flown_to := {}
## the flights counted, this run (each flight's `n`)
static var flights := 0
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
var _danger_text: Label
var _danger_cells: HBoxContainer
var _tier_text: Label
var _names_btn: Button
var _orbits_btn: Button
## Static view toggles: the screen is rebuilt every visit. A session preference.
static var names_on := true
static var orbits_on := true
var _transfer: TransferView = null
## The beacon the cursor is on, as [body, beacon], so its card lights while it is.
var _lit: Array = []
var _taking := false
## the zoom down onto the ship before LOCAL (`_zoom_down`, without the ladder):
## the camera is the move's, and the map takes no input at all
var _diving := false
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
## LOCATION was let go of by its button or L: glide back out to the opening
## framing (`open_zoom`, `home_at`).
var _homing := false
## Camera glide: zoom and look-at point ease together on one curve (Jon: no jolt).
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
## What the ship was on or turning onto last frame (`_orbit_now`): a change to
## a place is a flight (`flown_to`).
var _flown_ob := -9
## What LOCATION is holding: the ship, or the world it orbits.
var _follow_key := ""
## The zoom that shows the whole system, worked out for its edge and the frame:
## the furthest out the wheel goes.
var zoom_min := 1.0
## The opening framing and home: the whole system, or a wide pair's own part (Jon, Nov 1).
var open_zoom := 1.0
var home_at := Vector2.ZERO
## How much of the frame a wide pair's own part fills as the map opens
## (`open_view`): the share the binary-gap sheet showed Jon.
const PAIR_FILL := 0.6
## The edge marks show at the opening zoom and further out (`SystemOverlay.mark_zoom`),
## with this much slack for the wheel's ease settling onto it.
const MARK_ZOOM_K := 1.002
## A ship put back this close to the frame's edge (screen px) or past it takes
## the opening framing out to it, with this much room round it (plane px).
const SHIP_IN := 24.0
const SHIP_PAD := 60.0
## A harness holding keys has no keyboard to check them against.
var harness_keys := false
## Last input time, so weather holds for a zoom and an idle player gets events sooner.
var last_input_t := 0.0
var last_zoom_t := -100.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# The gas-cloud sky is drawn past the picture, behind everything (Jon, Oct 18).
	if NavField.used():
		_gas_ext = TextureRect.new()
		_gas_ext.name = "GasPastPicture"
		_gas_ext.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_gas_ext.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_gas_ext.stretch_mode = TextureRect.STRETCH_SCALE
		_gas_ext.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		var em := ShaderMaterial.new()
		em.shader = NavField.EXT
		em.set_shader_parameter("fade", NavField.EDGE_FADE)
		_gas_ext.material = em
		_gas_ext.visible = false
		add_child(_gas_ext)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 4)
	add_child(root)

	# The toolbar copies the chart's row (Jon): DANGER and tier plus two toggles, no reach.
	_strip = StarchartScreen.toolbar_row()
	# (DANGER at the row's own start: the goal is below the plate, at the
	# picture's top left -- Jon, Oct 20 -- not in the row: `GoalLine.fixed_at`)
	_danger_text = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	_strip.add_child(_danger_text)
	_danger_cells = HBoxContainer.new()
	_danger_cells.add_theme_constant_override("separation", 2)
	_strip.add_child(_danger_cells)
	_tier_text = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	_strip.add_child(_tier_text)
	var strip_gap := Control.new()
	strip_gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_strip.add_child(strip_gap)
	_names_btn = StarchartScreen.bar_button("", _on_names, 112)
	_strip.add_child(_names_btn)
	_orbits_btn = StarchartScreen.bar_button("", _on_orbits, 112)
	_strip.add_child(_orbits_btn)
	if NavField.used():
		_row_plate = NavField.row_plate(_strip)
		root.add_child(_row_plate)
	else:
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
	if NavField.used():
		wrap.add_theme_stylebox_override("panel", NavField.window_style())
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
	if NavField.used():
		view.set("field_under", true)
		_box.material = NavField.key_material()
	_vp.add_child(view)
	_cursor = SectorCursorS.new()
	_cursor.set("view", view)
	_vp.add_child(_cursor)
	overlay = SystemOverlayS.new()
	overlay.view = view
	_vp.add_child(overlay)
	# Edge arrows sit over the framed picture, out of the key shader's edge fade.
	var marks := _Marks.new()
	marks.screen = self
	marks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(marks)
	overlay.marks_drawn.connect(marks.queue_redraw)
	# THE INSTRUMENT, over the picture in the frame: the scale bar and LOCATION
	var bar := _Scale.new()
	bar.screen = self
	bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(bar)
	_scale_bar = bar
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
	var side_wrap := Widgets.panel_with(panel)
	if NavField.used():
		side_wrap.add_theme_stylebox_override("panel", NavField.plate_style())
	mid.add_child(side_wrap)

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
	root.add_child(_key_foot(key))
	_key_row = key


## THE KEY ON LOCAL'S STRIP (Jon, Nov 11): under the map and the panel, the screen's width, the row centred.
## The band and the row are siblings, so the ladder fades each once (`ladder_chrome`).
func _key_foot(key: HBoxContainer) -> HBoxContainer:
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 5)
	var hold := Control.new()
	hold.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.add_child(hold)
	var sb := UITheme.quiet_strip(SectorScreen.DRAWER_A, true)
	_key_band = Panel.new()
	_key_band.name = "KeyBand"
	_key_band.add_theme_stylebox_override("panel", sb)
	_key_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_key_band.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hold.add_child(_key_band)
	var mid := CenterContainer.new()
	mid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_child(key)
	hold.add_child(mid)
	var fit := func() -> void:
		hold.custom_minimum_size.y = key.get_combined_minimum_size().y + sb.get_minimum_size().y
	key.minimum_size_changed.connect(fit)
	fit.call()
	return foot


## A beacon kind's colour: the drawer's tag colours, and the dock in ice.
static func key_colour(tag: StringName) -> Color:
	if tag == &"dock":
		return UITheme.ICE
	return EncounterDrawer.tag_colour({"tags": [tag]})


## THE STAR IN THE MIDDLE OF THE FRAME (Jon: "can we center the star"),
## whatever size the frame is.
func _place_map() -> void:
	var at: Vector2 = (_frame.size / 2.0 - Vector2(view.CX, view.CY)).round()
	# Map blocks sit on LOCAL's pixel grid and 8-pixel step, so a handed-over world matches.
	# Why: docs/why/SystemMapScreen.md#pixel-grid
	var g := _frame.global_position + at
	var sx := posmod(roundi(g.x), 8)
	var sy := posmod(roundi(g.y), 8)
	at -= Vector2(sx if sx < 4 else sx - 8, sy if sy < 4 else sy - 8)
	_box.position = at
	view.window = Rect2(-at, _frame.size)


## `arrived`: the ship has just jumped in, so it warps in at the edge (in a
## station's system, alongside the station: arrive:B).
func show_system(n: MapGen.MapNode, t0: float = 0.0, arrived: bool = true) -> void:
	_keep_ship()
	# A flight under way when the map is redrawn hands its errand to the new ship.
	# Else its callback is lost and `_taking` keeps the map shut (Oct 31).
	# Why: docs/why/SystemMapScreen.md#restyle-during-flight
	var going: Dictionary = {}
	if flight != null and not arrived and view.node == n:
		going = flight.hand_over()
	var taking := _taking
	view.t = t0
	overlay.selected = -2
	overlay.hover = {}
	# The selection's flight names the old layout's index, so replan it for the new ship.
	overlay.preview_to = -9
	overlay.flight = null
	flight = null
	# every visit opens on its opening framing (the whole sector but in a wide
	# pair), then zooms onto you if LOCATION is held
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
	var ov := open_view(view.layout, view.node, _frame.size if _frame.size.x > 10.0 else SystemLayout.FIT_FRAME, t0)
	open_zoom = float(ov.zoom)
	var oc: Vector2 = ov.at
	home_at = Vector2(oc.x, oc.y * view.TILT)
	overlay.mark_zoom = open_zoom * MARK_ZOOM_K
	view.zoom = open_zoom
	view.pan = -home_at * open_zoom
	# (the sky, the gas and the lights are scaled from the whole system's zoom,
	# as the binary-gap sheet showed a wide pair opened nearer)
	view.home_zoom = zoom_min
	_zoom_to = open_zoom
	# The ship starts at the frame's right edge on arrival, else where it was left.
	flight = ShipFlightS.new()
	var ex := minf(view.layout.edge, home_at.x + (view.window.end.x - view.CX - 26.0) / open_zoom)
	flight.setup(view.layout, Vector2(ex, oc.y - 210.0 * (zoom_min / open_zoom)), t0)
	# (where a jump into this system puts a ship: a partner just arrived is
	# drawn there, `partner_points`)
	_arrival_p = flight.f.p
	if not arrived:
		_restore_ship(_parked.get(n.index, {}))
	elif n.type == MapGen.NodeType.STATION and view.layout.dock_place() >= 0:
		# (a jump into a station's system arrives alongside the station:
		# arrive:B, `Router._on_jumped`)
		flight.place_at(view.layout.dock_place(), t0)
	# A wide pair's framing that leaves the ship off is widened to take it in.
	if view.layout.pair_box(t0).size != Vector2.ZERO:
		var sp := _ship_plane(t0)
		var fs := _frame.size if _frame.size.x > 10.0 else SystemLayout.FIT_FRAME
		var on: Vector2 = Vector2(view.CX, view.CY) + view.pan + Vector2(sp.x, sp.y * view.TILT) * open_zoom
		# Before layout the window is empty and shrinking it went negative, so use the frame.
		var win: Rect2 = view.window
		if win.size.x <= SHIP_IN * 2.0 or win.size.y <= SHIP_IN * 2.0:
			win = Rect2(Vector2(view.CX, view.CY) - fs * 0.5, fs)
		if not win.grow(-SHIP_IN).has_point(on):
			var ov2 := open_view(view.layout, n, fs, t0, sp)
			open_zoom = float(ov2.zoom)
			var oc2: Vector2 = ov2.at
			home_at = Vector2(oc2.x, oc2.y * view.TILT)
			overlay.mark_zoom = open_zoom * MARK_ZOOM_K
			view.zoom = open_zoom
			view.pan = -home_at * open_zoom
			_zoom_to = open_zoom
	overlay.flight = flight
	_was_at = flight.reached()
	# (put back or brought in, not flown: `flown_to` is written by a flight)
	_flown_ob = flight.orbit_body()
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
	# (nothing is being taken on a ship just made: a GO carried on takes again)
	_taking = false
	if not going.is_empty():
		_carry_on(going, taking)


## A redrawn map finishes the flight's errand once, so clicking never loses anything.
## Why: docs/why/SystemMapScreen.md#flight-errand-handover
func _carry_on(going: Dictionary, taking: bool) -> void:
	var to := int(going.to)
	var done: Callable = going.done
	_taking = taking
	if flight.reached() == to:
		done.call()
		return
	if not flight.fly_bg(to, view.t, done, going.get("prefer", {})):
		# (no flight could start from where it was put: in orbit there, as
		# `_fly` does)
		flight.place_at(to, view.t)
		done.call()
		return
	if SystemLayout.is_place(flight.heading_to()):
		_was_at = -9


## Where your ship is on the plane: on the world or star it is in orbit of or
## alongside, else where it is flying.
func _ship_plane(t: float) -> Vector2:
	var on: int = flight.orbit_body()
	var p: Vector3 = flight.center(on, t) if SystemLayout.is_place(on) else flight.where3()
	return Vector2(p.x, p.z)


## Before the frame is laid out use the layout's own `open_zoom`, so the two cannot drift.
func _fit_zoom() -> float:
	var L: SystemLayout = view.layout
	if _frame.size.x <= 10.0:
		return _twin_floor(L, view.node, SystemLayout.FIT_FRAME, SystemLayout.open_zoom(L.edge))
	return zoom_for(L, view.node, _frame.size)


## Opening zoom: the edge fitted in the frame, two suns no further out than their rings.
static func zoom_for(L: SystemLayout, n: MapGen.MapNode, fs: Vector2) -> float:
	return _twin_floor(L, n, fs, fit_zoom_in(L.edge, fs))


## A wide pair opens on its own part (Jon, Nov 1) so a world is not drawn tiny against a sun.
## Why: docs/why/SystemMapScreen.md#opening-view
static func open_view(L: SystemLayout, n: MapGen.MapNode, fs: Vector2, _t: float, ship := Vector2.INF) -> Dictionary:
	# (the zoom a float, not a vector's single-precision part: one sun opens at
	# exactly the zoom it always did)
	var whole := zoom_for(L, n, fs)
	# (the pair as laid out, as Jon picked its framing: held still, it is the
	# pair at every t)
	var box := L.pair_box(0.0)
	if box.size == Vector2.ZERO:
		return {"at": Vector2.ZERO, "zoom": whole}
	if ship.is_finite():
		box = box.merge(Rect2(ship - Vector2.ONE * SHIP_PAD, Vector2.ONE * SHIP_PAD * 2.0))
	var half := box.size * 0.5 / PAIR_FILL
	var z := clampf(minf(fs.x / (2.0 * (half.x + 20.0)), fs.y / (2.0 * (half.y + 20.0) * SystemLayout.SLANT + 60.0)), 0.1, 1.0)
	if L.pair_n == 0.0:
		return {"at": box.get_center(), "zoom": maxf(z, whole)}
	# A turning pair opens on its balance point, so the framing holds for the whole visit.
	# Why: docs/why/SystemMapScreen.md#turning-pair-framing
	var reach := Vector2.ONE * pair_reach(L)
	if ship.is_finite():
		reach = reach.max((ship - L.bary).abs() + Vector2.ONE * SHIP_PAD)
	z = minf(z, clampf(minf(fs.x / (2.0 * (reach.x + 20.0)), fs.y / (2.0 * (reach.y + 20.0) * SystemLayout.SLANT + 60.0)), 0.1, 1.0))
	return {"at": L.bary, "zoom": maxf(z, whole)}


## Reach of a turning pair at any angle; the turn is rigid, so the same at every t.
static func pair_reach(L: SystemLayout) -> float:
	var r := 0.0
	for p in L.stars():
		r = maxf(r, absf(L._pair_r(p)) + L.star_radius(p) + SystemLayout.PAIR_SUN_PAD)
	for b in L.bodies:
		if SystemLayout.is_star(b.host_id):
			r = maxf(r, absf(L._pair_r(b.host_id)) + b.orbit + SystemLayout.reach_of(b))
	return r + SystemLayout.PAIR_PAD


## Twins open no further out than their rings were fitted to (measured 0.9924 on seed 4242).
## Why: docs/why/SystemMapScreen.md#two-suns-zoom-floor
static func _twin_floor(L: SystemLayout, n: MapGen.MapNode, fs: Vector2, z: float) -> float:
	if not L.twin or L.fit_zoom <= 0.0 or z >= L.fit_zoom or posted_past(L, n):
		return z
	if fs.x / (2.0 * L.fit_zoom) < L.edge or fs.y / (2.0 * L.fit_zoom * SystemLayout.SLANT) < L.edge:
		return z
	return L.fit_zoom


## Whether a job or the Hellbender has a place past the layout's own edge:
## they come and go, and the map opens out to show them.
static func posted_past(L: SystemLayout, n: MapGen.MapNode) -> bool:
	for b in L.bodies:
		for bc in b.beacons:
			if bc.hellbender:
				return true
			if n != null and bc.opt >= 0 and bc.opt < n.options.size() and OptionTable.is_job(n.options[bc.opt]):
				return true
	return false


## `open_zoom` for a frame of size `fs`: edge, 20 px margin, 60 px for the words.
static func fit_zoom_in(edge: float, fs: Vector2) -> float:
	return clampf(minf(fs.x / (2.0 * (edge + 20.0)), fs.y / (2.0 * (edge + 20.0) * SystemLayout.SLANT + 60.0)), 0.1, 1.0)


# ---------------------------------------------------------------- the party
# Spots are sent as offsets from a world or sun, as each machine runs its own clock.
# Why: docs/why/SystemMapScreen.md#party-spot
func _report_spot(held := false) -> void:
	if flight == null or view.node == null or view.layout == null or not Net.is_networked():
		return
	if view.node.index != Run.at:
		return
	var p3: Vector3 = flight.where3()
	var body: int = flight.orbit_body()
	var p := Vector2(p3.x, p3.z)
	# (open space settled round one sun goes off that sun, `f.cen_id`; round
	# both suns' balance point, which holds still, or flying, as it is)
	var host := -9
	if body == -9 and flight.star_orbiting():
		host = int(flight.f.cen_id)
	p -= NetSession.spot_anchor(view.layout, body, host, view.t)
	Net.report_spot(Run.at, body, p, float(flight.ang), false, view.t, host, held)


## Your flight, said once as it starts (PROTOCOL 17, `NetSession.report_flight`): its whole path,
## so a partner draws the arc it flies; let go of before it lands, said too.
## Why: docs/why/SystemMapScreen.md#flight-said-once
var _said_key := 0
var _said_end := 0.0
var _said_to := -9
const FLIGHT_SAY_DT := 1.0 / 60.0
func _report_flight() -> void:
	if flight == null or view.node == null or view.layout == null or not Net.is_networked() or view.node.index != Run.at:
		return
	var pl = flight.plan
	if pl != null and pl.get_instance_id() != _said_key:
		var sp: Array = flight.said_path(view.t, FLIGHT_SAY_DT)
		if sp.size() == 4:
			var dep: Dictionary = pl.dep
			_said_key = pl.get_instance_id()
			_said_end = view.t + float(sp[3])
			_said_to = int(pl.to)
			var shape := PackedFloat64Array([float(dep.get("host", -9)), float(sp[2]), float(sp[3])])
			Net.report_flight(Run.at, _said_key, int(dep.get("place", -9)), _said_to, view.t, FLIGHT_SAY_DT, sp[0], sp[1], view.t, shape)
			return
	if _said_key != 0 and (pl == null or pl.get_instance_id() != _said_key):
		if view.t < _said_end - 0.05 and flight.heading_to() != _said_to and flight.orbit_body() != _said_to:
			Net.report_flight_off(Run.at)
		_said_key = 0


## Where a jump arrival puts a ship, so a partner who just arrived is drawn there.
var _arrival_p := Vector2.INF


## Partners on the plane at this machine's clock; what the overlay draws and `-- cojoin` reads.
func partner_points() -> Array:
	var out: Array = []
	if view == null or view.node == null or view.layout == null or flight == null:
		return out
	var at: int = view.node.index
	for s in Net.partners():
		var id := int(s.id)
		if Net.where_is(id) != at:
			continue
		# ON ITS WAY (PROTOCOL 17): on the path it said as it left, its ends
		# moved with their places to this clock (`NetSession.flight_point`)
		var fl := Net.flight_of(id, at)
		if not fl.is_empty():
			var fp := NetSession.flight_point(fl, view.layout, view.t, Time.get_ticks_msec(), Net.spot_of(id, at))
			if not fp.is_empty():
				out.append([id, fp[0], float(fp[1]), String(s.get("name", "")).to_upper(), -9, true])
				continue
		var sp := Net.spot_of(id, at)
		var body := int(sp.get("body", -10))
		var q: Vector2
		if sp.is_empty() or body == -10:
			# JUST ARRIVED: where a jump into this system puts a ship -- by the
			# station in a station's system, else the frame's edge (`show_system`)
			var dp: int = view.layout.dock_place() if view.node.type == MapGen.NodeType.STATION else -1
			if dp >= 0:
				var c0: Vector3 = flight.center(dp, view.t)
				q = Vector2(c0.x, c0.z) + Vector2(14.0, 0.0)
			elif _arrival_p != Vector2.INF:
				# On the arrival orbit use this map's own ship point; the edge point was off.
				q = _arrival_p
			else:
				q = Vector2(view.layout.edge, -210.0)
		else:
			# Each spot is put back at this machine's clock, so a sun-orbit partner draws right.
			q = Vector2(float(sp.x), float(sp.z)) \
				+ NetSession.spot_anchor(view.layout, body, int(sp.get("host", -9)), view.t)
		out.append([id, q, float(sp.get("ang", PI)), String(s.get("name", "")).to_upper(), body if not sp.is_empty() else -10])
	return out


## The partners' ships on screen, as drawn. For `-- cojoin`.
func partner_marks() -> Array:
	var out: Array = []
	for e in overlay.partner_at:
		out.append(e[1])
	return out


## Your ship on screen, as drawn. For `-- cojoin`.
func own_mark() -> Vector2:
	return overlay._ship_at


## the flight the map was left on, counted there once (`_keep_ship`)
var _left_on_way = null


## Where the ship is, kept for the session when the screen leaves this system.
func _keep_ship() -> void:
	if flight == null or view.node == null:
		return
	# (a map put away after a new run began -- a restart from its menu -- keeps
	# nothing: its system is the last run's)
	if view.node.index >= Run.map.size() or Run.map[view.node.index] != view.node:
		return
	# Keep the map clock with the ship; never move it back, as LOCAL's or a partner's stands.
	Run.map_clock[view.node.index] = maxf(view.t, Run.map_t(view.node.index))
	# (and the partners told it holds there: map time does not run off the map)
	_report_spot(true)
	var at := ship_place()
	# A flight left on its way lands where it was going, once, though the map is put away twice.
	if flight.mode == &"fly" and SystemLayout.is_place(at) and flight.plan != _left_on_way:
		_left_on_way = flight.plan
		flights += 1
		flown_to[view.node.index] = {"at": at, "n": flights}
	var e := {"at": at, "p": flight.f.p, "v": flight.f.v, "head": flight.f.head, "mode": flight.mode}
	# SETTLED ON A WIDE ORBIT: round what, how wide and which way, so it is put
	# back on that very orbit (`ShipFlight.restore_free`)
	if flight.star_orbiting():
		e["cen"] = int(flight.f.cen_id)
		e["r"] = float(flight.f.orbit_r)
		e["sense"] = float(flight.f.sense)
	_parked[view.node.index] = e


## Where the ship is as LOCAL is told; `Router.at_station` reads this while LOCAL is built ahead.
## Why: docs/why/SystemMapScreen.md#ship-place
func ship_place() -> int:
	if flight == null:
		return -9
	var at: int = flight.reached()
	# Burning onto an orbit counts as being at the world (Jon, Oct 21); riding out is the old one.
	# Why: docs/why/SystemMapScreen.md#ship-place
	if not SystemLayout.is_place(at) and (flight.mode == &"rail" or flight.mode == &"keep"):
		at = flight.orbit_body()
	# A flight under way counts as at its destination, so leaving the map mid-flight loses nothing.
	# Why: docs/why/SystemMapScreen.md#ship-place
	elif not SystemLayout.is_place(at) and flight.mode == &"fly" and SystemLayout.is_place(flight.fly_to):
		at = flight.fly_to
	return at


func _restore_ship(d: Dictionary) -> void:
	if d.is_empty():
		flight.place_at(-3, view.t)
		return
	# A body the layout no longer has is the edge, not an index error.
	var at := int(d.at)
	if at == SystemLayout.STAR_B and not view.layout.twin:
		at = -1
	if SystemLayout.is_place(at) and at < view.layout.bodies.size() and StringName(d.get("mode", &"")) == &"rail" \
			and d.has("p") and (d.get("v", Vector2.ZERO) as Vector2) != Vector2.ZERO:
		# On its ring, the place is where it was at the kept clock, so `p` and `v` still hold.
		var c3: Vector3 = flight.center(at, view.t)
		var cv3: Vector3 = flight.center_vel(at, view.t)
		var rel: Vector2 = (d.p as Vector2) - Vector2(c3.x, c3.z)
		var vr: Vector2 = (d.v as Vector2) - Vector2(cv3.x, cv3.z)
		flight.rail_back(at, rel, -1.0 if rel.x * vr.y - rel.y * vr.x < 0.0 else 1.0, view.t)
	elif SystemLayout.is_place(at) and at < view.layout.bodies.size():
		flight.place_at(at, view.t)
	elif StringName(d.mode) == &"free":
		# (on the wide orbit it was settled on, else coasting on from where it
		# was: never on the arrival orbit `setup` has just made)
		flight.restore_free(view.t, d.get("p", Vector2.ZERO), d.get("v", Vector2.ZERO), float(d.get("head", PI)),
			int(d.get("cen", -99)), float(d.get("r", -1.0)), float(d.get("sense", 0.0)))
	else:
		flight.place_at(-3, view.t)


func _enter_tree() -> void:
	if not Sig.render_style_changed.is_connected(_on_style):
		Sig.render_style_changed.connect(_on_style)


## Written as the map is put away: `Router._swap` builds LOCAL before this one is freed.
## Why: docs/why/SystemMapScreen.md#writing-on-put-away
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible:
		_keep_ship()


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
	fill_danger(_danger_text, _danger_cells, _tier_text, n)
	_paint_toggles()


## A system's danger on a toolbar: DANGER n/10, its pips, its tier (the map's
## row, and LOCAL's when it keeps a band, `SectorScreen._build_band`).
static func fill_danger(text: Label, cells: HBoxContainer, tier: Label, n: MapGen.MapNode) -> void:
	text.text = "DANGER %d/%d" % [n.danger, MapGen.DANGER_MAX]
	# (lit in the danger ramp the jump gauges use: blue, amber, red as it runs
	# deeper; dark past it, as the chart's layers to come)
	StarchartScreen.fill_pips(cells, MapGen.DANGER_MAX, func(i: int) -> Color:
		if i >= n.danger:
			return UITheme.LINE
		if i < 3:
			return Color("#5d7a93")
		return UITheme.WARN if i < 6 else UITheme.BAD)
	tier.text = MapGen.tier_name(n.danger)
	tier.add_theme_color_override("font_color", UITheme.WARN if n.danger >= 7 else UITheme.COLD)


## The toolbar's two toggles, saying what a press does now, and what they
## change set on the view and the overlay.
func _paint_toggles() -> void:
	_names_btn.text = "HIDE NAMES" if names_on else "SHOW NAMES"
	_orbits_btn.text = "HIDE ORBITS" if orbits_on else "SHOW ORBITS"
	if overlay != null:
		overlay.names_on = names_on
		overlay.queue_redraw()
	if view != null:
		view.orbits_on = orbits_on
		if view._lines != null and is_instance_valid(view._lines):
			view._lines.queue_redraw()


func _on_names() -> void:
	names_on = not names_on
	_paint_toggles()


func _on_orbits() -> void:
	orbits_on = not orbits_on
	_paint_toggles()


func _process(delta: float) -> void:
	var hold := clock_held()
	var held := frozen or hold
	if not held:
		view.t += delta
		_catch_up(delta)
	_step_ship(delta, hold)
	comet_catch().step()
	_report_spot(held)
	_report_flight()
	# A CLICK MADE WHILE THE SHIP SPUN DOWN onto its ring (`_after_spin`), now
	# it is on it
	if _after_spin.is_valid() and flight != null and not flight.spinning():
		var c := _after_spin
		_after_spin = Callable()
		if flight.can_fly():
			c.call()
	_step_camera(delta)
	overlay.mark_keep = mark_keep()
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


## The comet's catch (`CometCatch`): its spots, the race to them and the pass. Made once.
var _catch: Node = null
const CometCatchS := preload("res://scripts/ui/sysmap/CometCatch.gd")
func comet_catch() -> Node:
	if _catch == null:
		_catch = CometCatchS.new()
		_catch.screen = self
		add_child(_catch)
	return _catch


## The map clock holds during a ladder move so both pictures show the pair at one angle.
## The ship holds with it (Jon, Nov 2), or it moves against a still picture.
## Why: docs/why/SystemMapScreen.md#clock-hold
func clock_held() -> bool:
	return cam_held or ZoomLadder.busy() or ZoomLadder.prebuilt_screen() == self or not is_visible_in_tree()


## A map behind a partner runs faster until level, never past it and never back (PROTOCOL 14).
## Why: docs/why/SystemMapScreen.md#catching-up-with-party
const CATCH_K := 0.25
const CATCH_S := 4.0
const CATCH_MAX := 2.0
func _catch_up(delta: float) -> void:
	if not Net.is_networked() or view.node == null or view.node.index != Run.at or flight == null:
		return
	if flight.plan != null or flight.mode == &"fly":
		return
	var pt := Net.party_t(Run.at)
	if pt > view.t:
		view.t = minf(view.t + delta * clampf((pt - view.t) / CATCH_S, CATCH_K, CATCH_MAX), pt)


## The ship is stepped by no time while the clock holds; a harness's `frozen` clock still steps it.
func _step_ship(delta: float, hold := false) -> void:
	# (flight plans let go of, a freed ship's among them, waited for once done:
	# never in a frame before they are, `ShipFlight.reap`)
	ShipFlightS.reap()
	if flight == null or view.layout == null:
		return
	_settle_keys()
	var free := _transfer == null and is_visible_in_tree()
	var target := -_arrows.normalized() * PAN_SPEED if free else Vector2.ZERO
	_pan_v = _pan_v.lerp(target, 1.0 - exp(-delta * 10.0))
	if _pan_v.length() > 1.0:
		_let_go_of_view()
		view.pan += _pan_v * delta
	# WASD FROM THE BERTH is refused, and says to press UNDOCK (`Router.cast_off`;
	# Jon, Oct 27: UNDOCK is the only way out)
	if Router.docked and free and not _taking and (_wasd.w or _wasd.a or _wasd.s or _wasd.d) 			and not Router.cast_off():
		for k in _wasd:
			_wasd[k] = false
	var keys: Dictionary = _wasd if free and not _taking else {"w": false, "a": false, "s": false, "d": false}
	# (and while a GO flies the tip offers no click, as none is taken)
	overlay.clicks_held = _taking
	var t_fly := Time.get_ticks_usec()
	var level: float = flight.step(0.0 if hold else delta, view.t, keys)
	view.tick("flight step", t_fly)
	var t_pred := Time.get_ticks_usec()
	flight.predict(view.t, keys)
	view.tick("predict", t_pred)
	Audio.ship_thrust(level)
	# A FLIGHT ONTO AN ORBIT, from the moment it turns onto it (burning in), as
	# LOCAL already counts the ship there (`ship_place`)
	var ob: int = flight.orbit_body()
	if ob != _flown_ob:
		_flown_ob = ob
		if SystemLayout.is_place(ob) and view.node != null:
			flights += 1
			flown_to[view.node.index] = {"at": ob, "n": flights}
	# THE FLIGHT A SECOND CLICK WOULD FLY, drawn before you fly it (star B too)
	overlay.preview_to = overlay.selected if SystemLayout.is_place(overlay.selected) else -9
	# (and its arrival: the lit side, with the spin, `ArriveSide`)
	flight.wish = ArriveSide.wish_now(overlay, view, flight)
	_aim_sight()
	# WHETHER A FLIGHT CAN START changed (settled into an orbit, or left one):
	# the tag's click line and the choices say so
	var cf: bool = flight.can_fly()
	if cf != _could_fly:
		_could_fly = cf
		_refresh_panel()
	var now: int = flight.reached()
	if now != _was_at:
		var was := _was_at
		_was_at = now
		if SystemLayout.is_place(now) and not _taking:
			# In orbit the panel opens that place, unless another place was picked on the way.
			if overlay.selected == now:
				_sound(&"chart_select", 0.04, 60)
			if SystemLayout.is_place(overlay.selected) and overlay.selected != now:
				_refresh_panel()
			else:
				select_body(now)
		elif SystemLayout.is_place(was) and panel.mode == &"list" and (panel.filter == was or (SystemLayout.is_star(was) and panel.filter == -2)):
			panel.show_body(panel.filter)


## The keys are bindings (`Keys`): four fly the ship by the names `ShipFlight` reads.
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
			# (a world where it is now, or either star: `place_rel`)
			return overlay.place_rel(body) / z if SystemLayout.is_place(body) else Vector2.ZERO
	# home: the opening framing's middle
	return home_at


func _glide_to(kind: String, body: int, z1: float, dur: float = GLIDE_S) -> void:
	last_zoom_t = Time.get_ticks_msec() / 1000.0
	_glide = {"kind": kind, "body": body, "z0": view.zoom, "z1": clampf(z1, zoom_min, view.ZOOM_MAX),
		"f0": _look_at(), "t0": float(Time.get_ticks_msec()) / 1000.0, "dur": dur}
	_zoom_to = float(_glide.z1)
	_anchor = Vector2(-1, -1)
	_homing = false
	_locked = false


## Zoom eases geometrically and the look-at point eases to its target on the same curve.
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
				view.pan = -home_at * view.zoom
		_glide = {}
	return true


## Right-click zooms onto the selected place, again goes home (Jon). Fixed, not rebindable.
## Why: docs/why/SystemMapScreen.md#right-click
func right_click(h: Dictionary) -> void:
	var b: int = int(h.get("body", -9)) if not h.is_empty() else -9
	# (a star is the one under the pointer, -1 or STAR_B: `SystemOverlay.hit`)
	if h.get("kind", &"") == &"star" and not SystemLayout.is_star(b):
		b = -1
	if SystemLayout.is_place(b) and b == overlay.selected and b != _focus_body:
		if _location_on:
			_location_on = false
			_paint_location()
		_glide_to("body", b, maxf(ZOOM_FOCUS, view.zoom))
		_focus_body = -9
	elif SystemLayout.is_place(_focus_body) or not SystemLayout.is_place(b) or b == _focus_body:
		_focus_body = -9
		_glide_to("home", -9, open_zoom)


func _zoom_level() -> int:
	return roundi(log(maxf(view.zoom, 0.0001)) / log(ZOOM_STEP))


## The zoom eases to where the wheel sent it, pivoting on the point that was
## under the cursor; LOCATION draws the ship to the middle as it goes.
func _step_camera(delta: float) -> void:
	if view.layout == null:
		return
	# THE ZOOM LADDER HAS THE CAMERA for the length of a move (`ZoomLadder`)
	if cam_held:
		# (the calm move is heard at the click, not as the zoom crosses its
		# levels: the level kept, silently)
		if _lad.has("calm"):
			_tick_level = _zoom_level()
		else:
			_tick_zoom()
		return
	if _step_glide():
		_tick_zoom()
		return
	var c := Vector2(view.CX, view.CY)
	var z: float = view.zoom
	var a: Vector2 = c if _anchor.x < 0.0 or _homing else _anchor
	if SystemLayout.is_place(_focus_body):
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
		# Worked out for the ship at this zoom; in orbit the world, so the camera does not circle.
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
	elif SystemLayout.is_place(_focus_body):
		# HELD ON THE PLACE A RIGHT-CLICK ZOOMED ONTO, as it goes round
		view.pan = -_glide_target("body", _focus_body) * view.zoom
	else:
		if _homing:
			var hp: Vector2 = -home_at * view.zoom
			view.pan = view.pan.lerp(hp, 1.0 - exp(-delta * 8.0))
			if view.pan.distance_to(hp) < 0.25 and absf(view.zoom - open_zoom) < 0.002:
				view.pan = hp
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
	# (and never so tight that the opening framing is out of reach)
	lim = lim.max((home_at * z).abs())
	view.pan = view.pan.clamp(-lim, lim)


func _zoom_by(f: float, at: Vector2) -> void:
	last_zoom_t = Time.get_ticks_msec() / 1000.0
	# The wheel stops at either end: LOCAL and the chart are Tab and the tabs (`ZoomLadder`).
	if not _glide.is_empty():
		_glide = {}
		_zoom_to = view.zoom
	_zoom_to = clampf(_zoom_to * f, zoom_min, view.ZOOM_MAX)
	_anchor = at
	_homing = false


## On, LOCATION zooms onto the ship; off, it glides back to the opening framing (Jon).
func _on_location() -> void:
	_location_on = not _location_on
	_paint_location()
	_locked = false
	_focus_body = -9
	# ONE SMOOTH MOVE each way: zoom and the point looked at together
	if _location_on:
		_glide_to("loc", -9, ZOOM_LOCATION)
	else:
		_glide_to("home", -9, open_zoom)


## Movement keys are held states, so two keys go diagonal and letting one go keeps the other.
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


## During a GO the view stays the player's, but what would fly, select or open is refused (Nov 1).
## Why: docs/why/SystemMapScreen.md#go-in-flight
func _on_map_input(e: InputEvent) -> void:
	last_input_t = Time.get_ticks_msec() / 1000.0
	# No flight until the sky bake has made the ship: a tap before then has nothing to fly.
	if _transfer != null or _diving or flight == null:
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
		# (nothing under the Custodian's badge on the goal line: its tooltip
		# opens there, not this one under it too; a press there is still the map's)
		overlay.hover = {} if CustodianBadge.covers(_frame.get_global_transform_with_canvas() * mm.position) \
			else overlay.hit(_map_at(mm.position))
		_light_from_map(overlay.hover)
		# THE CHART'S SCAN: the cursor moves, and every so far it blips
		_cursor.set("at", _map_at(mm.position))
		_cursor.queue_redraw()
		_scan_px += mm.relative.length()
		if _scan_px >= SCAN_STEP:
			_scan_px = fmod(_scan_px, SCAN_STEP)
			_sound(&"chart_scan", 0.08, SCAN_LIMIT_MS)
	elif e is InputEventGesture:
		var f := MapChart.gesture_zoom(e, ZOOM_STEP)
		if f != 1.0:
			_zoom_by(f, _map_at((e as InputEventGesture).position))
		_frame.accept_event()
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
					if _dragging and not _drag_moved and not _taking:
						tap(overlay.hit(_map_at(mb.position)))
					_dragging = false
			MOUSE_BUTTON_MIDDLE:
				_dragging = mb.pressed
				if mb.pressed:
					_drag_from = mb.position
					_press_at = mb.position
					_drag_moved = false
			MOUSE_BUTTON_RIGHT:
				if mb.pressed:
					right_click(overlay.hit(_map_at(mb.position)))
				_drag_from = mb.position
				_press_at = mb.position
				_drag_moved = true
		_frame.accept_event()


# ---------------------------------------------------------------- panel calls
# One click selects, a second flies there, and empty space goes back to the list.
func tap(h: Dictionary) -> void:
	if h.is_empty():
		panel_back()
		return
	var body: int = h.body
	# The comet is only selected: a flight to something moving waits for its spots.
	if h.kind == &"comet":
		if overlay.selected != body:
			select_body(body)
		return
	var again: bool = overlay.selected == body and (h.kind != &"beacon" or panel.mode != &"list")
	if again:
		# A FLIGHT STARTS ONLY FROM AN ORBIT: on the way, or under thrust, a click
		# selects and no more
		if flight.orbit_body() != body and flight.can_fly():
			# (the lit side, with the spin, for this click: `ArriveSide`)
			overlay.hover = h
			flight.wish = ArriveSide.wish_now(overlay, view, flight)
			fly_to_body(body)
		return
	if h.kind == &"beacon":
		open_beacon(h.body, h.beacon)
	else:
		select_body(body)


## ON THE SELECTED PLACE, WHERE A CLICK FLIES (F-C, Nov 11): the pointer shuts to the
## game's sight, as over a button, and the map's own cursor rings in the flight's ink.
func _aim_sight() -> void:
	var aim: bool = overlay.aimed()
	_frame.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if aim else Control.CURSOR_ARROW
	if bool(_cursor.get("sight")) != aim:
		_cursor.set("sight", aim)
		_cursor.queue_redraw()


## Whether the ship is in orbit of (or alongside) place i: its events are open.
func ship_reached(i: int) -> bool:
	return flight != null and flight.reached() == i


func select_body(i: int) -> void:
	if i != overlay.selected:
		_sound(&"chart_select", 0.04, 60)
	overlay.selected = i
	selection_changed.emit(i)
	panel.show_body(i)


## Opening a beacon only selects its world; the ship stays put until you choose (Jon).
## Why: docs/why/SystemMapScreen.md#opening-a-beacon
func open_beacon(body: int, bc) -> void:
	_sound(&"chart_select", 0.04, 60)
	overlay.selected = body
	beacon_opened.emit(body, bc)
	panel.show_beacon(body, bc)


## The trip comes with the choice: into orbit, then do `then`. No clicks on the way.
func _go_then(body: int, then: Callable) -> void:
	if flight.reached() == body:
		then.call()
		return
	# ONLY OUT OF AN ORBIT (Jon: "You have to be IN AN ORBIT ... AND THEN CLICK
	# to go to another planet"): anywhere else the panel says so and nothing flies
	# (spinning down onto it after a fast flight, it flies once that is over)
	if _wait_spin(func() -> void: _go_then(body, then)):
		return
	if not flight.can_fly():
		return
	# (from the berth: refused, UNDOCK is the only way out, `Router.cast_off`)
	if not Router.cast_off():
		return
	_taking = true
	_fly(body, func() -> void:
		_taking = false
		then.call())


## Flights sound on the thrust loop; the old arrival flameout's sputter was the ticking Jon heard.
func _fly(body: int, done: Callable) -> void:
	# The callback decides what the panel shows, so the frame's arrival must not open the place.
	# The flight drawn is the flight flown: reuse the preview's plan or plan on a worker.
	# Why: docs/why/SystemMapScreen.md#flying
	var near: bool = overlay.preview_to == body and ArriveSide.plan_matches(overlay._pv_plan, flight.wish)
	if overlay.preview_to == body and not near:
		# (the line drawn is another side's or way's: planned afresh for this click)
		flight.drop_bg(&"preview")
	var prefer: Dictionary = overlay._pv_choice if near else {}
	var ok: bool = flight.fly_bg(body, view.t, func() -> void:
		_was_at = flight.reached()
		_sound(&"chart_select", 0.04, 60)
		done.call(), prefer, overlay._pv_plan if near else null)
	if not ok:
		# no flight could start from here: put the ship in orbit there rather
		# than leave the choice hanging
		flight.place_at(body, view.t)
		_was_at = flight.reached()
		done.call()
		return
	# (on its way, or being planned: not where it was; put there at once, the
	# callback has said where it is)
	if SystemLayout.is_place(flight.heading_to()):
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


## A CLICK WHILE THE SHIP SPINS DOWN ONTO ITS RING after a fast flight (at most
## `ShipFlight.SPIN_S`, when `can_fly` is false): kept and made once it is on
## it, where it was dropped (the code review, Nov 5). The last one made wins.
var _after_spin := Callable()
func _wait_spin(c: Callable) -> bool:
	if flight == null or not flight.spinning():
		return false
	_after_spin = c
	return true


## Your ship into orbit of place `i` or alongside; the panel stays on it and opens it.
func fly_to_body(i: int) -> void:
	if not _taking and _wait_spin(func() -> void: fly_to_body(i)):
		return
	if _taking or not flight.can_fly():
		return
	# (from the berth: refused, UNDOCK is the only way out, `Router.cast_off`)
	if not Router.cast_off():
		return
	_sound(&"chart_select", 0.04, 60)
	overlay.selected = i
	# ARRIVED: the place opens -- unless another was picked on the way, which
	# stays picked, its flight drawn now the ship is in orbit
	_fly(i, func() -> void:
		if overlay.selected == i or not SystemLayout.is_place(overlay.selected):
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
	# (an event sited on the star itself)
	for bc in view.layout.star_beacons:
		if bc.opt == k:
			open_beacon(-1, bc)
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
	overlay.selected = -2
	overlay.link_on = false
	_lit = []
	panel.show_system()


## GO flies to where the event stands, then zooms down to LOCAL, where it resolves (Jon).
func go_event(i: int) -> void:
	if _taking:
		return
	# Docked, GO is refused and says how to leave: it used to undock via LOCAL (Jon, Oct 27).
	if Router.docked:
		Router.cast_off()
		return
	var body := LocalEventDrawer.body_of(view.node, i)
	overlay.link_on = false
	# (a comet's reading is reached by its spots, `CometCatch`, never straight down)
	if body == SystemLayout.COMET:
		return
	if not SystemLayout.is_place(body):
		_zoom_down(i)
		return
	_go_then(body, func() -> void: _zoom_down(i))


## DOWN THE ZOOM LADDER (the one the first-run tour used to climb): onto the ship, then
## LOCAL. Reduced motion cuts.
const ZOOM_DOWN_S := 0.7
func _zoom_down(i: int) -> void:
	LocalEventDrawer.request(view.node.index, i)
	# THE ZOOM LADDER makes this move itself, all the way into LOCAL
	if ZoomLadder.enabled():
		# (the clock kept here is the one LOCAL opens on, and the map's holds
		# from here through the move: `clock_held`)
		_keep_ship()
		Router.show_local()
		return
	if Router.animating():
		_taking = true
		_diving = true
		_glide_to("loc", -9, ZOOM_LOCATION * 2.0, ZOOM_DOWN_S)
		await get_tree().create_timer(ZOOM_DOWN_S).timeout
		_taking = false
		_diving = false
		if not is_inside_tree():
			return
	# (where the ship is, before LOCAL is built from it: the Router's hide writes
	# it too, but a harness's map that is not `Router.current` is never hidden)
	_keep_ship()
	Router.show_local()


## DOCK, HARVEST and the custodian: the same doors the sector's action button
## opens (`SectorScreen._on_action`).
func take_action(bc) -> void:
	if _taking:
		return
	# DOCK only at the station (dock:A): the card is greyed and this door refuses too.
	if bc != null and bc.dock and not Router.docked and not ship_reached(_body_of_beacon(bc)):
		Audio.denied()
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
	elif bc.hellbender:
		Router.engage_hellbender()


## The found hull, as the sector's rail handles it (`SectorScreen._on_salvage`).
func on_hull(what: String, h: Variant) -> void:
	match what:
		"take_hull":
			Audio.act(&"hull_transfer")
			Run.transfer_to_hull(h as HullData)
			# Straight to the move (`SectorScreen._on_salvage`).
			Router.show_transfer()
			return
		"leave_hull":
			Run.found_hull = null
		"scrap_hull":
			Audio.act(&"module_scrap")
			Run.scrap_found_hull()
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
	_open_jetsam(Run.sector_loot(view.node))


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


# ------------------------------------------------------------ the zoom ladder
# The map as one distance of four: the ladder moves its camera for the length of a move.
# Why: docs/why/SystemMapScreen.md#zoom-ladder
var cam_held := false
var _lad := {}


func ladder_ready() -> bool:
	return flight != null and view.layout != null


func ladder_picture() -> Rect2:
	return _frame.get_global_rect()


func ladder_scale() -> float:
	return view.zoom


## Plane origin on screen; a pair's star A is there only at t 0, hence `_ladder_star`.
func _ladder_origin() -> Vector2:
	return _frame.global_position + _box.position + Vector2(view.CX, view.CY) + view.pan


## Star A where the pair has it now, or a move to the chart carried an empty point.
## Why: docs/why/SystemMapScreen.md#ladder-star
func _ladder_star() -> Vector2:
	return _ladder_origin() + overlay.place_rel(-1)


## The world the ship is in orbit of, or -9.
func _ladder_body() -> int:
	if flight == null or flight.mode != &"rail":
		return -9
	var b := int(flight.rail.body)
	return b if b >= 0 and b < view.layout.bodies.size() else -9


func _ladder_focus(other: int, seam: int, design: String) -> Vector2:
	if other == ZoomLadder.CHART:
		return overlay.place_rel(-1)
	var b := _ladder_body()
	if seam == 2 and design == "C" and b >= 0:
		return overlay.place_rel(b)
	return overlay.ship_rel()


func ladder_anchor(other: int, seam: int, design: String) -> Vector2:
	if not ladder_ready():
		return _frame.get_global_rect().get_center()
	if seam == 2 and design == "C" and not _world_peek.is_empty():
		return _world_peek.screen
	return _ladder_origin() + _ladder_focus(other, seam, design)


## How far the map moves before it hands over (a share of k), 0 for none.
func ladder_pre(_target: int, seam: int, design: String) -> float:
	if not ladder_ready():
		return 0.0
	if seam == 2 and design == "B":
		return 0.45
	return 1.0


var _lad_meet := Vector2.INF


## The held picture's anchor: at the far end of a move the map's own anchor is
## put there, so the two pictures move as one.
func ladder_meet(at: Vector2, _world: Dictionary) -> void:
	_lad_meet = at


func ladder_cam_begin(other: int, seam: int, design: String) -> void:
	if not ladder_ready():
		return
	# (placed again for where it stands now: a map built ahead was laid out
	# somewhere else, and its frame's place decides where its picture sits)
	_place_map()
	cam_held = true
	_glide = {}
	_homing = false
	_anchor = Vector2(-1, -1)
	var z0: float = view.zoom
	var f0 := _look_at()
	if _location_on and other != ZoomLadder.CHART:
		z0 = ZOOM_LOCATION
		f0 = _glide_target("loc", -9)
	var z1: float = view.ZOOM_MAX if other > ZoomLadder.MAP else zoom_min * 0.55
	if seam == 2 and design == "B":
		z1 = minf(view.ZOOM_MAX, z0 * 2.2)
	# 1A: out until the sun is no bigger than the chart draws your star (its floor),
	# the worlds drawn as small as they truly are on the way (`min_r`)
	if seam == 1 and design == "A":
		z1 = zoom_min * 0.12
		_lad_min_r = SystemViewS.min_r
	# 2C: the world grows on the map toward LOCAL's size, so the held picture has little to do.
	var aim := {}
	var b := _ladder_body()
	if seam == 2 and design == "C" and b >= 0 and other > ZoomLadder.MAP:
		var body: SystemLayout.Body = view.layout.bodies[b]
		var rest := ZoomLadder.rest_world(view.node.index, body)
		# (as drawn: the disc's own radius, not its place's)
		var wn := ladder_world()
		var r_now: float = maxf(float(wn.get("r", view.draw_r(body))), 1.0)
		var r_end := float(rest.r) * 0.62
		z1 = clampf(z0 * r_end / r_now, view.ZOOM_MAX, 9.0)
		var p0: Vector2 = _ladder_origin() + overlay.place_rel(b)
		aim = {"p0": p0, "rest": rest.c, "r0": r_now, "r_end": maxf(float(body.r) * z1, view.min_r), "R": float(rest.r)}
	_lad = {"z0": z0, "z1": z1, "f0": f0, "other": other, "seam": seam, "design": design,
		"side": panel.get_parent().position.x, "aim": aim, "body": b}
	_lad["off"] = Vector2.ZERO if _lad_meet == Vector2.INF else _lad_meet - _frame.get_global_rect().get_center()
	_lad_meet = Vector2.INF


## The map's worlds' smallest size before 1A shrank them, to put back.
var _lad_min_r := -1.0


## The sun on screen (1A): where and how big it is drawn this frame.
func ladder_sun() -> Dictionary:
	if not ladder_ready():
		return {}
	return {"c": _ladder_star(), "r": float(view.layout.star_r) * float(view.star_k())}


func ladder_cam(k: float) -> void:
	if _lad.is_empty() or not ladder_ready():
		return
	if _lad_min_r > 0.0:
		SystemViewS.min_r = lerpf(_lad_min_r, 1.0, clampf(k * 1.5, 0.0, 1.0))
	var z0: float = _lad.z0
	var z: float = z0 * pow(float(_lad.z1) / z0, k)
	view.zoom = z
	var f1 := _ladder_focus(int(_lad.other), int(_lad.seam), String(_lad.design)) / maxf(z, 0.0001)
	view.pan = -(_lad.f0 as Vector2).lerp(f1, k) * z + (_lad.off as Vector2) * k
	# 1A, OUT: the sun carried on a straight line toward where the chart (built
	# ahead) has your star's mark, as far along as this half goes
	if int(_lad.other) == ZoomLadder.CHART and _lad.has("split"):
		var ch: Control = ZoomLadder.prebuilt
		if ch is StarchartScreen and ch.call(&"ladder_ready"):
			if not _lad.has("sun0"):
				_lad["sun0"] = _ladder_star()
			var goal: Vector2 = ch.call(&"ladder_anchor", 0, 1, "A")
			var want: Vector2 = (_lad.sun0 as Vector2).lerp(goal, k * float(_lad.split))
			view.pan = want - (_frame.global_position + _box.position + Vector2(view.CX, view.CY)) - overlay.place_rel(-1)
	var aim: Dictionary = _lad.get("aim", {})
	if not aim.is_empty() and _lad_split > 0.0:
		# the world on a straight line from where it was toward where LOCAL will
		# have it, as far along as this half of the move goes (`_lad_split`)
		var fr := _frame.get_global_rect().grow(-float(aim.r_end) * 0.4)
		var want: Vector2 = (aim.p0 as Vector2).lerp(aim.rest, _lad_split * k)
		want = want.clamp(fr.position, fr.end)
		view.pan = want - (_frame.global_position + _box.position + Vector2(view.CX, view.CY)) \
			- overlay.place_rel(int(_lad.body))
	_zoom_to = z
	if not (_lad.get("aim", {}) as Dictionary).is_empty():
		overlay.visible = k < 0.75
		# Fabric and orbits thin away as the world nears, as LOCAL has neither.
		var fa := clampf((0.8 - k) / 0.3, 0.0, 1.0)
		for c: CanvasItem in [view._fabric, view._lines]:
			if c != null:
				c.modulate.a = fa


## Each half's travel on a log scale: this screen's zoom, then the held picture's growth.
func ladder_spans() -> Vector2:
	if _lad.is_empty():
		return Vector2.ZERO
	var aim: Dictionary = _lad.get("aim", {})
	if aim.is_empty():
		return Vector2(absf(log(float(_lad.z1) / maxf(float(_lad.z0), 0.0001))), 0.0)
	var a := log(float(aim.r_end) / maxf(float(aim.r0), 0.5))
	var c := log(float(aim.R) / maxf(float(aim.r_end), 0.5))
	_lad_split = a / maxf(a + c, 0.001)
	return Vector2(a, c)


## How far across (0 to 1) the map carries its sun toward the chart's mark (1A,
## out); the chart carries it the rest of the way.
func ladder_split(f: float) -> void:
	if not _lad.is_empty():
		_lad["split"] = clampf(f, 0.0, 1.0)


## The share of the whole move this screen's half travels (set with the spans).
var _lad_split := 0.0


func ladder_cam_end() -> void:
	_world_peek = {}
	for c: CanvasItem in [view._fabric, view._lines]:
		if c != null:
			c.modulate.a = 1.0
	if _lad_min_r > 0.0:
		SystemViewS.min_r = _lad_min_r
		_lad_min_r = -1.0
	_lad_split = 0.0
	overlay.visible = true
	cam_held = false
	_lad = {}
	_zoom_to = view.zoom
	_locked = false


# ------------------------------------------------------------ the calm move
# The calm move (Jon's pick A, Oct 17): zoom about your ship so it walks one straight line.

## The base of the map's picture: where the star is drawn with no pan.
func _calm_base() -> Vector2:
	return _frame.global_position + _box.position + Vector2(view.CX, view.CY)


func calm_begin() -> void:
	if not ladder_ready():
		return
	_place_map()
	_lad = {"calm": true, "z0": view.zoom, "pan0": view.pan, "locked": _locked, "zoom_to": _zoom_to}
	cam_held = true
	_glide = {}
	_homing = false
	_anchor = Vector2(-1, -1)


## Where your ship is drawn now (the map's marker for it).
func calm_ship() -> Vector2:
	return _ladder_origin() + overlay.ship_rel()


## Where your ship sits at rest, now: the rest camera with the ship where its
## orbit has it this moment.
func calm_rest() -> Vector2:
	if not _lad.has("calm"):
		return calm_ship()
	var p: Vector3 = flight.where3() if flight != null else Vector3.ZERO
	return _calm_base() + (_lad.pan0 as Vector2) + Vector2(p.x, p.z * view.TILT) * float(_lad.z0)


func calm_at(p: Vector2, s: float) -> void:
	if not _lad.has("calm") or not ladder_ready():
		return
	view.zoom = float(_lad.z0) * s
	_zoom_to = view.zoom
	view.pan = p - _calm_base() - overlay.ship_rel()


func calm_end() -> void:
	if not _lad.has("calm"):
		ladder_cam_end()
		return
	view.zoom = float(_lad.z0)
	view.pan = _lad.pan0
	var locked: bool = _lad.locked
	var zt: float = _lad.zoom_to
	ladder_cam_end()
	_locked = locked
	_zoom_to = zt


## The map's UI leaves before the camera moves and returns after; the panel and strip stay.
## Why: docs/why/SystemMapScreen.md#ladder-ui
var _key_row: Control = null
## LOCAL's strip behind the KEY row (`_key_foot`)
var _key_band: Panel = null
var _scale_bar: Control = null


## The toolbar along the top (DANGER), which decodes into the next screen's
## the way the side bar does (`SideSwap`).
func ladder_bar() -> Control:
	return _row_plate if _row_plate != null else _strip


## the toolbar row's plate, on the field (`NavField.row_plate`)
var _row_plate: PanelContainer = null
## the map's own sky drawn on past its picture (a system in a cloud)
var _gas_ext: TextureRect = null


## The side bar, for the ladder to swap in place (`SideSwap`).
func ladder_side() -> Control:
	return panel.get_parent() as Control if panel != null and is_instance_valid(panel) else null


func ladder_chrome(k: float) -> void:
	for c: CanvasItem in [_key_row, _key_band, _scale_bar, _loc_btn]:
		ZoomLadder.fade_chrome(c, k)
	if overlay != null:
		overlay.label_a = 1.0 - k
		overlay.hush_labels = k >= 0.999
		overlay.queue_redraw()


## THE WORLD YOU ORBIT, GIVEN AWAY (2C): the map's own picture of it -- the node,

## The world is taken as this frame will draw it, a frame behind what the map holds now.
## Why: docs/why/SystemMapScreen.md#world-handover
var _world_peek := {}


## Where LOCAL will have the world you orbit (2C), as the aim of this zoom took
## it, or INF.
func ladder_rest() -> Vector2:
	var aim: Dictionary = _lad.get("aim", {})
	return aim.rest if not aim.is_empty() else Vector2.INF


func ladder_peek() -> void:
	_world_peek = _world_now()


func _world_now() -> Dictionary:
	var b := _ladder_body()
	if b < 0 or not view._views.has(b):
		return {}
	var v: Node2D = view._views[b]
	if not (v is PlanetView):
		return {}
	var m: ShaderMaterial = v.get("_mat")
	var params := {}
	if m != null:
		for u: Dictionary in m.shader.get_shader_uniform_list():
			params[StringName(u.name)] = m.get_shader_parameter(StringName(u.name))
	var off: Variant = params.get(&"ctr_off", Vector2.ZERO)
	var centre: Vector2 = v.position + (off if off is Vector2 else Vector2.ZERO)
	return {"pos": v.position, "screen": _frame.global_position + _box.position + centre, "params": params,
		"t": view.t, "light": v.get("_light"), "r": float(params.get(&"r", 10.0)),
		"spec_r": float((v as PlanetView).spec.get("r", params.get(&"r", 10.0)))}


func ladder_give_world() -> Dictionary:
	var b := _ladder_body()
	if b < 0 or not view._views.has(b):
		return {}
	var v: Node2D = view._views[b]
	if not (v is PlanetView):
		return {}
	var m: ShaderMaterial = v.get("_mat")
	var params := {}
	if m != null:
		for u: Dictionary in m.shader.get_shader_uniform_list():
			params[StringName(u.name)] = m.get_shader_parameter(StringName(u.name))
	var body: SystemLayout.Body = view.layout.bodies[b]
	var centre := v.position + (params.get(&"ctr_off", Vector2.ZERO) as Vector2)
	var out := {"view": v, "screen": _frame.global_position + _box.position + centre, "params": params,
		"t": view.t, "world": body.world, "seed": body.seed, "body": b,
		"spec_r": float((v as PlanetView).spec.get("r", params.get(&"r", 10.0))), "light": v.get("_light")}
	# (as last drawn: see `ladder_peek`)
	if not _world_peek.is_empty():
		for k in ["screen", "params", "t", "light", "spec_r"]:
			out[k] = _world_peek[k]
	# Keep its surface memory, or the world came back a shade off in most pixels.
	var mvp: Variant = v.get("_mem_vp")
	if mvp is SubViewport and (mvp as SubViewport).get_texture() != null and DisplayServer.get_name() != "headless":
		var img := (mvp as SubViewport).get_texture().get_image()
		if img != null and not img.is_empty():
			out["mem_img"] = img
	view._views.erase(b)
	view._live.erase(b)
	view._rq.erase(b)
	v.get_parent().remove_child(v)
	return out


## The plane as drawn: your star on screen, plane to screen scale and the slant.
func ladder_plane() -> Dictionary:
	if not ladder_ready():
		return {}
	return {"o": _ladder_star(), "s": view.zoom, "tilt": view.TILT}


## The world the ship orbits: its centre on screen and its drawn radius.
func ladder_world() -> Dictionary:
	var b := _ladder_body()
	if b < 0:
		return {}
	if not _world_peek.is_empty():
		return {"c": _world_peek.screen, "r": float(_world_peek.r)}
	# AS DRAWN: the disc's own centre and radius this frame (while the zoom moves
	# it is drawn round its true centre, a little off its place on the grid)
	if view._views.has(b):
		var v: Node2D = view._views[b]
		var m: ShaderMaterial = v.get("_mat")
		if m != null and m.get_shader_parameter(&"r") != null:
			var off: Variant = m.get_shader_parameter(&"ctr_off")
			return {"c": _frame.global_position + _box.position + v.position + (off if off is Vector2 else Vector2.ZERO),
				"r": float(m.get_shader_parameter(&"r"))}
	return {"c": _ladder_origin() + overlay.place_rel(b), "r": view.draw_r(view.layout.bodies[b])}


## What the edge marks keep off that the overlay does not draw itself.
func mark_keep() -> Array:
	var o := _frame.global_position + _box.position
	var out: Array = []
	var g := GoalLine.stack_rect(self)
	if g.size != Vector2.ZERO:
		out.append(Rect2(g.position - o, g.size))
		# and the column under it, so no arrow hangs off it
		out.append(Rect2(g.position - o, g.size + Vector2(0.0, SystemOverlayS.MARK_UNDER_WORDS)))
	if _loc_btn != null and _loc_btn.visible:
		var lb := _loc_btn.get_global_rect()
		out.append(Rect2(lb.position - o, lb.size))
	var fs := _frame.size
	out.append(Rect2(Vector2(fs.x - BAR_PAD - BAR_MAX_PX, fs.y - BAR_PAD - BAR_LABEL_H) - _box.position,
		Vector2(BAR_MAX_PX, BAR_LABEL_H + 2.0)))
	return out


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
		draw_string(UITheme.pixel_font(), Vector2(x + w - BAR_MAX_PX, y - 7.0), LowHull.scr(self, txt, 8),
			HORIZONTAL_ALIGNMENT_RIGHT, BAR_MAX_PX, 8, ink)


## Edge arrows (Jon, Nov 2) draw over the picture, out of the key shader's fade.
## Why: docs/why/SystemMapScreen.md#edge-arrows
class _Marks extends Control:
	var screen
	## how many rects it drew last (a harness's)
	var drawn := 0
	## and how many names
	var named := 0

	func _process(_d: float) -> void:
		if drawn > 0:
			queue_redraw()

	func _draw() -> void:
		drawn = 0
		named = 0
		var ov = screen.overlay
		if ov == null or not ov.is_visible_in_tree() or not screen._box.is_visible_in_tree():
			return
		if not (screen._lad as Dictionary).is_empty():
			return
		var mat = screen._box.material
		if mat is ShaderMaterial:
			var rk: Variant = (mat as ShaderMaterial).get_shader_parameter(&"round_k")
			if rk != null and float(rk) > 0.001:
				return
		var o: Vector2 = screen._box.position
		var tip: Rect2 = ov.tip_rect
		for e: Array in ov.mark_rects:
			var r: Rect2 = e[0]
			if tip.has_area() and tip.intersects(r):
				continue
			draw_rect(Rect2(r.position + o, r.size), e[1])
			drawn += 1
		var f := UITheme.pixel_font()
		for e: Array in ov.mark_words:
			if tip.has_area() and tip.intersects(e[3]):
				continue
			var c: Color = e[2]
			var s := LowHull.scr(self, String(e[1]), UITheme.FS_SMALL, f)
			for d: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				draw_string(f, (e[0] as Vector2) + o + d, s, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL,
					Color(SystemOverlayS.MARK_DARK, 0.8 * c.a))
			draw_string(f, (e[0] as Vector2) + o, s, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL, c)
			named += 1
