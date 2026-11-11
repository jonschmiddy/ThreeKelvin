class_name JumpSeam
extends Control

## The hand-off from a jump film's last frame to the system map it lands on: the film's sky
## settles into the map's, then its paths, then the panels, then your ship warps in (Jon's T3,
## Nov 11; the cut before it read as a flash). Headless and the shot tools keep the cut.
## Why: docs/why/JumpSeam.md#seam

## The map's UI is still held back (the goal line asks, `GoalLine.shows_on`).
static var ui_held := false

## The film's sky into the map's, then its paths, then the panels, then the ship.
const SKY_S := 0.70
const ORBITS_AT := 0.60
const ORBITS_S := 0.50
const PANEL_AT := 1.00
const PANEL_S := 0.60
const SHIP_AT := 1.75
const SETTLE_END := 2.50
## A map that has not drawn its system by now is handed back as it stands.
const READY_LIMIT_S := 2.0

var map: SystemMapScreen
var _pic: TextureRect
var _t0 := 0.0
## When the map had its system drawn (its show_system awaits a sky bake), -1 before.
var _ready_t := -1.0
var _side: Control = null
var _side_x := NAN
var _bar: Control = null
var _shipped := false


## The film's last frame as the player saw it, the content area only (the HUD stays the HUD).
static func grab() -> Texture2D:
	# (headless has no picture to read: the harnesses take the cut)
	if Router.content == null or not Router.animating() or DisplayServer.get_name() == "headless":
		return null
	var im := Router.content.get_viewport().get_texture().get_image()
	if im == null or im.is_empty():
		return null
	var r := Rect2i(Router.content.get_global_rect()).intersection(Rect2i(Vector2i.ZERO, im.get_size()))
	if r.size.x < 2 or r.size.y < 2:
		return null
	return ImageTexture.create_from_image(im.get_region(r))


## After the commit: lay the seam over the map the jump landed on, or nothing.
static func begin(pic: Texture2D) -> void:
	if pic == null or not (Router.current is SystemMapScreen) or not Router.animating():
		return
	var s := JumpSeam.new()
	s.map = Router.current as SystemMapScreen
	s._build(pic)
	Router.content.add_child(s)


func _build(pic: Texture2D) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# (a press on a map nobody can see yet lands on nothing)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_pic = TextureRect.new()
	_pic.texture = pic
	_pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pic.size = pic.get_size()
	add_child(_pic)
	_t0 = GameClock.now()
	_hide_ui()
	_bare(0.0)


func _process(_d: float) -> void:
	if not is_instance_valid(map) or Router.current != map or not map.is_visible_in_tree():
		_finish()
		return
	var t := GameClock.now() - _t0 + 1e-4
	if _ready_t < 0.0:
		if map.flight == null:
			if t >= READY_LIMIT_S:
				_finish()
			return
		_ready_t = t
		_side = ZoomLadder.side_of(map)
		_bar = ZoomLadder.bar_of(map)
		if _side != null:
			_side_x = _side.position.x
		# the ship comes in last, so its warp is held back; the panel slides rather than fades
		map.overlay.hide_ship = true
		ZoomLadder.fade_chrome(_side, 0.0)
		_portrait(true)
	_settle(t - _ready_t)


func _settle(u: float) -> void:
	_pic.modulate.a = 1.0 - JumpSequence.ease3(u / SKY_S)
	# (presses pass once the map can be seen)
	mouse_filter = Control.MOUSE_FILTER_IGNORE if u > SKY_S * 0.5 else Control.MOUSE_FILTER_STOP
	_bare(JumpSequence.ease3((u - ORBITS_AT) / ORBITS_S))
	var p := clampf((u - PANEL_AT) / PANEL_S, 0.0, 1.0)
	# the side panel slides in on the calm ladder's sine; the toolbar and the key fade with it
	map.ladder_chrome(1.0 - JumpSequence.ease3(p))
	ui_held = p <= 0.0
	ZoomLadder.fade_chrome(_bar, 1.0 - JumpSequence.ease3(p))
	if _side != null and not is_nan(_side_x) and not DisplaySettings.reduced_motion:
		ZoomLadder.slide(_side, _side_x, cos(p * PI * 0.5))
	else:
		ZoomLadder.fade_chrome(_side, 1.0 - p)
	if u >= SHIP_AT and not _shipped:
		_shipped = true
		_warp_in()
	if u >= SETTLE_END:
		_finish()


## The map's own warp-in (its streak and the ring in the dust), from now.
func _warp_in() -> void:
	map.overlay.hide_ship = false
	if map.flight != null:
		map.flight.warp_t = float(map.view.t)
	if map.view._weather != null:
		map.view._weather.arrive(float(map.view.t))


## The map's paths, beacons and ship at a (0 none, 1 all).
func _bare(a: float) -> void:
	if map.overlay != null:
		map.overlay.modulate.a = clampf(a, 0.0, 1.0)


## The map's UI held back until the picture has arrived: side panel, toolbar, key row, words.
func _hide_ui() -> void:
	ui_held = true
	map.ladder_chrome(1.0)
	ZoomLadder.fade_chrome(ZoomLadder.bar_of(map), 1.0)
	ZoomLadder.fade_chrome(ZoomLadder.side_of(map), 1.0)
	_portrait(false)


## The side panel's star is drawn by a shader that ignores fades, so it is hidden, not faded.
func _portrait(on: bool) -> void:
	var p: Variant = map.panel.get(&"_portrait") if map.panel != null else null
	if p is CanvasItem and is_instance_valid(p):
		(p as CanvasItem).visible = on


## Everything put back exactly, and gone.
func _finish() -> void:
	set_process(false)
	ui_held = false
	if is_instance_valid(map):
		map.ladder_chrome(0.0)
		_portrait(true)
		ZoomLadder.fade_chrome(ZoomLadder.bar_of(map), 0.0)
		var sd := ZoomLadder.side_of(map)
		ZoomLadder.fade_chrome(sd, 0.0)
		if sd != null and not is_nan(_side_x):
			ZoomLadder.slide(sd, _side_x, 0.0)
		if map.overlay != null:
			map.overlay.modulate.a = 1.0
			if map.overlay.hide_ship:
				_warp_in()
	queue_free()


func _exit_tree() -> void:
	ui_held = false
