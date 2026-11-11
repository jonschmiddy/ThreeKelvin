class_name JumpSeam
extends Control

## The hand-off from a jump film's last frame to the system map it lands on: the film's sky
## settles into the map's, then its paths, then the panels slide in as the calm ladder brings
## them, then your ship warps in (Jon's T3, Nov 11; the cut before it read as a flash).
## Headless and the shot tools keep the cut.
## Why: docs/why/JumpSeam.md#seam

## The map's UI is still held back (the goal line asks, `GoalLine.shows_on`).
static var ui_held := false

## The film's sky into the map's, then its paths, then the panels, then the ship.
const SKY_S := 0.70
const ORBITS_AT := 0.60
const ORBITS_S := 0.50
## The side panel, top row and KEY band slide on together over the ladder's CALM_SLIDE_S on its
## curve, and the words come up after over its CALM_IN_S, as a calm move lands.
const PANEL_AT := 1.00
const SHIP_AT := 1.75
const SETTLE_END := 2.50
## A map that has not drawn its system by now is handed back as it stands.
const READY_LIMIT_S := 2.0

var map: SystemMapScreen
var _pic: TextureRect
var _t0 := 0.0
## When the map had its system drawn (its show_system awaits a sky bake), -1 before.
var _ready_t := -1.0
## The side panel, the top row and the KEY band, each a `PanelSlide` from off to on.
var _slides: Array[PanelSlide] = []
var _sliding := false
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
	mouse_filter = Control.MOUSE_FILTER_STOP
	_pic = TextureRect.new()
	_pic.texture = pic
	_pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pic.size = pic.get_size()
	add_child(_pic)
	_t0 = GameClock.now()
	ui_held = true
	_panels(1.0)
	_words(1.0)
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
		# the ship comes in last, so its warp is held back
		map.overlay.hide_ship = true
	_settle(t - _ready_t)


func _settle(u: float) -> void:
	_pic.modulate.a = 1.0 - JumpSequence.ease3(u / SKY_S)
	_bare(JumpSequence.ease3((u - ORBITS_AT) / ORBITS_S))
	if u >= PANEL_AT and not _sliding:
		_slide_on()
	var q := clampf((u - PANEL_AT) / ZoomLadder.CALM_SLIDE_S, 0.0, 1.0)
	for ps in _slides:
		if is_instance_valid(ps):
			ps.set_k(ZoomLadder._calm_slide_curve(q))
	var w := clampf((u - PANEL_AT - ZoomLadder.CALM_SLIDE_S) / ZoomLadder.CALM_IN_S, 0.0, 1.0)
	_words(1.0 - JumpSequence.ease3(w))
	if q >= 1.0 and not _slides.is_empty():
		_slides_done()
	if u >= SHIP_AT and not _shipped:
		_shipped = true
		_warp_in()
	if u >= SETTLE_END:
		_finish()


## The panels from hidden to drawn whole off the frame's edges, then slid on (`PanelSlide`,
## as `ZoomLadder._panels_slide` makes them): side right, top row up, KEY band down.
func _slide_on() -> void:
	_sliding = true
	ui_held = false
	var c := Router.content.get_global_rect()
	var sd := ZoomLadder.side_of(map)
	var br := ZoomLadder.bar_of(map)
	var held: Array = [sd, br, PanelSlide.foot_of(map)]
	_panels(0.0)
	if sd != null and sd.size.x > 2.0:
		var ps := PanelSlide.new()
		add_child(ps)
		# (the side panel's chrome sound is the ladder's, not a jump's: the film's tail rings on alone)
		ps._heard = true
		ps.setup(sd, &"side", Vector2(c.end.x - sd.get_global_rect().position.x + 2.0, 0.0), 0.0, map)
		_slides.append(ps)
	if br != null and br.size.y > 2.0:
		var pb := PanelSlide.new()
		add_child(pb)
		pb.setup(br, &"band", Vector2(0.0, -(br.get_global_rect().end.y - c.position.y + 2.0)), 0.0, map)
		_slides.append(pb)
	var pf := PanelSlide.for_foot(self, map, c, true)
	if pf != null:
		_slides.append(pf)
	# (anything that could not slide comes up where it stands)
	for h: Variant in held:
		if h != null and is_instance_valid(h) and not _slides.any(func(p: PanelSlide) -> bool: return p.target == h):
			ZoomLadder.fade_chrome(h as Control, 0.0)


func _slides_done() -> void:
	for ps in _slides:
		if is_instance_valid(ps):
			ps.set_k(1.0)
			ps.finish()
	_slides.clear()


## The side panel, top row and KEY band hidden (1) or put back (0) while they wait.
func _panels(k: float) -> void:
	for c: Variant in [ZoomLadder.side_of(map), ZoomLadder.bar_of(map), PanelSlide.foot_of(map)]:
		ZoomLadder.fade_chrome(c as Control, k)
	_portrait(k < 0.5)


## The map's words (labels, scale, LOCATION) k gone, as `ladder_chrome` takes them on a calm move.
func _words(k: float) -> void:
	k = clampf(k, 0.0, 1.0)
	for c: Variant in [map._scale_bar, map._loc_btn]:
		ZoomLadder.fade_chrome(c as CanvasItem, k)
	if map.overlay != null:
		map.overlay.label_a = 1.0 - k
		map.overlay.hush_labels = k >= 0.999
		map.overlay.queue_redraw()


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


## The side panel's star is drawn by a shader that ignores fades, so it is hidden, not faded.
func _portrait(on: bool) -> void:
	var p: Variant = map.panel.get(&"_portrait") if map.panel != null else null
	if p is CanvasItem and is_instance_valid(p):
		(p as CanvasItem).visible = on


## Presses: none until the map can be seen, then none on a panel still moving (as the ladder).
func _has_point(point: Vector2) -> bool:
	var u := GameClock.now() - _t0 - _ready_t if _ready_t >= 0.0 else 0.0
	if _ready_t < 0.0 or u < SKY_S * 0.5:
		return true
	var g := get_global_transform() * point
	for ps in _slides:
		if is_instance_valid(ps) and ps.at().has_point(g):
			return true
	return false


## Everything put back exactly, and gone.
func _finish() -> void:
	set_process(false)
	ui_held = false
	if is_instance_valid(map):
		_slides_done()
		_panels(0.0)
		_words(0.0)
		if map.overlay != null:
			map.overlay.modulate.a = 1.0
			if map.overlay.hide_ship:
				_warp_in()
	queue_free()


func _exit_tree() -> void:
	ui_held = false
