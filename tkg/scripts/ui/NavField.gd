class_name NavField
extends Control

## THE SPACE THE THREE NAVIGATION SCREENS ARE BUILT ON (Jon, Oct 18: "I just
## want the swap to feel smooth and cohesive. Why don't we have stars fill the
## entire panel edge-to-edge ... Let's have the panels built ON TOP of this
## screen"). One field of stars and far galaxies across the whole screens' area,
## behind LOCAL, the sector map and the star chart alike, that never cuts,
## fades or changes when you move between them: a hop changes what is in front
## of it, never it.
##
## IT IS LOCAL'S OWN FAR SKY (`LocalSky`: `local_far.gdshader` on
## `chart_bg.gdshaderinc`, the far galaxies and three depths of stars every chart
## style keeps, toned by LOCAL's play tone and cut to the system's palette),
## drawn the same way in the same frame -- a 480x270 picture of 2x2 blocks with
## the window as its frame -- so on LOCAL, where the sky is drawn whole over it,
## the stars LOCAL shows are this field's stars, pixel for pixel, wherever the
## system's cloud and worlds are not. While a LOCAL sky is up its far sky's
## settings are copied here (its camera's slide, its palette once cut), so the
## field is LOCAL's far sky as it last stood when LOCAL goes. The one thing left
## out is the clear sky's glow round the system's star: that is the star's light,
## and it goes with LOCAL.
##
## Above it: the map's and the chart's pictures with their own far stars off and
## their empty sky keyed away (`nav_key.gdshader`), the panels and the toolbar
## rows as glass plates. The ladder holds a screen's picture with this field
## keyed out of it (`ZoomLadder`, `calm_ladder.gdshader`), so a move carries the
## things in front and the stars stay where they are.
##
## Router's, next above `SpaceLayer` (which the three screens hide), inert
## headless but there, so the harness can hold it to the same instance.

const FAR := preload("res://shaders/local_far.gdshader")
const GRADE := preload("res://shaders/local_grade.gdshader")
const PALETTE := preload("res://shaders/map_palette.gdshader")
const KEY := preload("res://shaders/nav_key.gdshader")
## how far in from a picture's edge what it holds fades out (px), never cut
const EDGE_FADE := 24.0


## THE SWITCH: `-- field=off` puts the map's and the chart's own skies back, in
## their opaque frames (a harness's before).
static func used() -> bool:
	return not ("field=off" in OS.get_cmdline_user_args())


## The map's or the chart's picture keyed onto the field (its empty sky let
## through).
static func key_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = KEY
	m.set_shader_parameter("fade", EDGE_FADE)
	return m


## HOW MUCH OF THE FIELD A PLATE LETS THROUGH (Jon, Oct 18: "Let's have the top
## part also be a panel. Let's make both panels slightly see through like the
## other panels"): the side panel and the toolbar row on the map and the chart,
## glass over the stars at LOCAL's own event drawer's alpha
## (`SectorScreen.DRAWER_A`, the plate already over this sky), a shade more
## open than `UITheme.PANEL_A`.
const PLATE_A := 0.80


## The plates' one look: the panel's colour at `PLATE_A`, its line, its margins
## (`Widgets.panel_with`'s, so nothing on them moves).
static func plate_style() -> StyleBoxFlat:
	return UITheme.flat(Color(UITheme.PANEL, PLATE_A), UITheme.LINE, 0, 12, 12)


## A TOOLBAR ROW ON ITS PLATE (Jon, Oct 18: "the size of that panel also
## doesn't seem big enough... the border comes right up to the button's
## edges"): the row inside a plate of the side panel's own look and margins
## (`plate_style`, 12 px every side), so its line stands as clear of the row's
## buttons as the side panel's does of its own. The ladder's `ladder_bar`.
static func row_plate(row: Control) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", plate_style())
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(row)
	return pc


## A picture's frame on the field: its margin alone, no line, nothing filled,
## so the stars inside it and round it are the same stars.
static func window_style() -> StyleBox:
	# (no line either: Jon, Oct 18, "why is there a box around the galaxy
	# panel?" -- the picture's edge is its soft fade, `nav_key.gdshader`)
	var sb := StyleBoxEmpty.new()
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	return sb

## the system it is the sky of (`setup`), and whose LOCAL sky last fed it
var node_index := -1
## counts every time what it draws changed (a new system, LOCAL's sky copied
## with a difference): the harness holds a hop to it not moving
var version := 0
## whether it is drawn: under LOCAL, the map and the chart (`Router`)
var on := false

var _box: SubViewportContainer = null
var _scene: SubViewport = null
var _far: ColorRect = null
var _far_mat: ShaderMaterial = null
var _grade_mat: ShaderMaterial = null
var _pal: ColorRect = null
var _pal_mat: ShaderMaterial = null
var _copy2: BackBufferCopy = null
## the uniforms as last drawn, to tell a change
var _sig := ""
var _enabled := true


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	visible = false
	if DisplayServer.get_name() == "headless" or "sim" in OS.get_cmdline_user_args():
		_enabled = false


func _ready() -> void:
	set_process(true)


func _build() -> void:
	if not _enabled or _box != null:
		return
	_box = SubViewportContainer.new()
	_box.stretch = false
	_box.size = Vector2(480, 270)
	_box.scale = Vector2(2, 2)
	_box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	_scene = SubViewport.new()
	_scene.size = Vector2i(480, 270)
	_scene.size_2d_override = Vector2i(960, 540)
	_scene.size_2d_override_stretch = true
	_scene.transparent_bg = false
	_scene.disable_3d = true
	_scene.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_scene.render_target_update_mode = SubViewport.UPDATE_ONCE
	_box.add_child(_scene)
	_far = _rect()
	_far_mat = ShaderMaterial.new()
	_far_mat.shader = FAR
	_far.material = _far_mat
	_scene.add_child(_far)
	var copy := BackBufferCopy.new()
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	_scene.add_child(copy)
	var grade := _rect()
	_grade_mat = ShaderMaterial.new()
	_grade_mat.shader = GRADE
	_grade_mat.set_shader_parameter("ramp", LocalSky.PLAY)
	grade.material = _grade_mat
	_scene.add_child(grade)
	_copy2 = BackBufferCopy.new()
	_copy2.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	_scene.add_child(_copy2)
	_pal = _rect()
	_pal_mat = ShaderMaterial.new()
	_pal_mat.shader = PALETTE
	_pal_mat.set_shader_parameter("pal_n", 0)
	_pal_mat.set_shader_parameter("cell", 1)
	_pal_mat.set_shader_parameter("x0", 0.0)
	_pal.material = _pal_mat
	_pal.visible = false
	_scene.add_child(_pal)


func _rect() -> ColorRect:
	var r := ColorRect.new()
	r.size = Vector2(960, 540)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## The sky of system `n`: LOCAL's far sky as its own setup makes it, until a
## LOCAL sky up over the system is copied.
func setup(n: MapGen.MapNode) -> void:
	if n == null or n.index == node_index:
		return
	node_index = n.index
	version += 1
	if not _enabled:
		return
	_build()
	for k: String in LocalSky.far_defaults(n).keys():
		_far_mat.set_shader_parameter(k, LocalSky.far_defaults(n)[k])
	_far_mat.set_shader_parameter("glow_k", 0.0)
	var cached: Array = LocalSky.palette_for(n)
	_set_palette(cached)
	_redraw()


func _set_palette(cached: Array) -> void:
	if cached.is_empty():
		_pal.visible = false
		_pal_mat.set_shader_parameter("pal_n", 0)
	else:
		_pal_mat.set_shader_parameter("pal", cached[0])
		_pal_mat.set_shader_parameter("pal_n", cached[1])
		_pal.visible = true


func _redraw() -> void:
	if _scene != null:
		_scene.render_target_update_mode = SubViewport.UPDATE_ONCE


## LOCAL's sky over this system, as it stands: its far sky's settings, its tone,
## its palette. Copied whenever they differ from what is drawn.
func feed(sky: LocalSky) -> void:
	if not _enabled or sky == null or not is_instance_valid(sky) or sky.node == null:
		return
	if sky.node.index != node_index:
		return
	var fm: ShaderMaterial = sky.get("_far_mat")
	if fm == null or not bool(sky.get("_ready_sky")):
		return
	_build()
	var parts: Array = []
	for u: Dictionary in FAR.get_shader_uniform_list():
		var nm := String(u.name)
		var v: Variant = fm.get_shader_parameter(nm)
		if nm == "glow_k":
			v = 0.0
		if v != null:
			parts.append("%s=%s" % [nm, v])
			_far_mat.set_shader_parameter(nm, v)
	var gm: ShaderMaterial = sky.get("_grade_mat")
	if gm != null:
		for u: Dictionary in GRADE.get_shader_uniform_list():
			var nm := String(u.name)
			if nm == "screen":
				continue
			var v: Variant = gm.get_shader_parameter(nm)
			if v != null:
				parts.append("g%s=%s" % [nm, v])
				_grade_mat.set_shader_parameter(nm, v)
	var pm: ShaderMaterial = sky.get("_palette_mat")
	if pm != null and bool(sky.get("_palette_built")):
		for u: Dictionary in PALETTE.get_shader_uniform_list():
			var nm := String(u.name)
			if nm == "screen" or nm == "prev":
				continue
			var v: Variant = pm.get_shader_parameter(nm)
			if v != null:
				parts.append("p%s=%s" % [nm, hash(str(v))])
				_pal_mat.set_shader_parameter(nm, v)
		_pal.visible = int(pm.get_shader_parameter("pal_n")) > 0
	var sig := "|".join(PackedStringArray(parts))
	if sig != _sig:
		_sig = sig
		version += 1
		_redraw()


## The LOCAL sky up now over the system, if any (LOCAL at rest: never one
## arriving on a move, so the field holds still through every move).
static func live_local_sky() -> LocalSky:
	if ZoomLadder.busy():
		return null
	for s: Variant in [Router.current]:
		if s is SectorScreen and is_instance_valid(s):
			var v: EncounterView = (s as SectorScreen).get("_view")
			if v != null and is_instance_valid(v) and v.backdrop != null and is_instance_valid(v.backdrop):
				return v.backdrop
	return null


func _process(_delta: float) -> void:
	if not on:
		return
	# (the keys' frames headless too: the harness reads them)
	_frames_keyed()
	if not _enabled:
		return
	_place()
	var sky := live_local_sky()
	if sky != null:
		feed(sky)


## Each map's and chart's key told where its picture's frame stands now, for the
## soft edge (`nav_key.gdshader`): the screen up, and one built ahead or
## arriving on a move.
func _frames_keyed() -> void:
	var screens: Array = []
	if Router.content != null:
		for c: Node in Router.content.get_children():
			screens.append(c)
	var pb := ZoomLadder.prebuilt_screen()
	if pb != null:
		screens.append(pb)
	for s: Variant in screens:
		if not is_instance_valid(s):
			continue
		var m: Variant = null
		var r := Rect2()
		if s is SystemMapScreen and (s as SystemMapScreen)._box != null:
			m = (s as SystemMapScreen)._box.material
			r = (s as SystemMapScreen)._frame.get_global_rect()
		elif s is StarchartScreen and (s as StarchartScreen)._chart != null and (s as StarchartScreen)._chart._sky != null:
			m = (s as StarchartScreen)._chart._sky.material
			r = (s as StarchartScreen)._chart.get_global_rect()
		if m is ShaderMaterial and (m as ShaderMaterial).shader == KEY:
			(m as ShaderMaterial).set_shader_parameter("frame", Vector4(r.position.x, r.position.y, r.size.x, r.size.y))


## The field's picture lies on the window as LOCAL's does (`LocalSky._place_box`).
func _place() -> void:
	if _box == null:
		return
	var p := -(get_global_rect().position / 2.0).round() * 2.0
	if _box.position != p:
		_box.position = p


## The field as drawn (the harness, and the ladder keying it out of a held
## picture): its 480x270 picture, its frame on the window.
func picture() -> Texture2D:
	return _scene.get_texture() if _scene != null else null


## Shown or not (Router: under LOCAL, the map and the chart, and through a move
## between them).
func set_on(v: bool) -> void:
	on = v
	visible = v and _enabled
	if v:
		_build()
		_place()
		_redraw()
