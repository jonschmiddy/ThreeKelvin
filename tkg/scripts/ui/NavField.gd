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
const EXT := preload("res://shaders/nav_ext.gdshader")
## how far in from a picture's edge what it holds fades out (px), never cut
const EDGE_FADE := 24.0


## THE SWITCH: `-- field=off` puts the map's and the chart's own skies back, in
## their opaque frames (a harness's before).
static func used() -> bool:
	return not ("field=off" in OS.get_cmdline_user_args() or harness_off)


## A harness's own `field=off`, for a screen built after it is set: `BallHaloTest`
## judges a ball's light on the chart's own sky, not on the field let through it.
static var harness_off := false


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
## edges"): the row inside a plate of the side panel's own look, its line as
## far from the row's ends as the side panel's is from its contents (12 px),
## and close above and below (`ROW_PAD_V`: "The row is good on the width...
## but a bit excessive on the height"). The ladder's `ladder_bar`.
const ROW_PAD_V := 5
static func row_plate(row: Control) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := plate_style()
	# (hugging the row top and bottom: Jon, "a bit excessive on the height")
	sb.content_margin_top = ROW_PAD_V
	sb.content_margin_bottom = ROW_PAD_V
	pc.add_theme_stylebox_override("panel", sb)
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
## THE FIELD'S DRIFT (Jon: "Why is the parallax gone from the sector and
## starchart views?"): its far layers slide by `pan` (`chart_bg`'s `u_skyPan`,
## whole game px: the far nebulae 0.02 of it, the far galaxies 0.05, the three
## depths of stars 0.04, 0.10 and 0.20) -- on the chart by the chart's own sky
## pan (`MapChart.sky_pan`, exactly as its own far sky slid), on the map by the
## map's (`SystemView._cam_pan`, at MAP_K: its old five fields slid 0.03-0.55
## of it), on LOCAL by LOCAL's camera (copied, `feed`). Each screen moves it by
## how far its own pan has gone since it came up, from wherever it stood, so a
## hop never puts it back; and through a move it holds still (a move is not a
## pan: `ZoomLadder.busy`).
var pan := Vector2.ZERO
const MAP_K := 0.9
## the screen moving it now, its own pan when it took over, the field's then
var _pan_src: Object = null
var _pan_ref := Vector2.ZERO
var _pan_base := Vector2.ZERO
var _drift_off := "drift=off" in OS.get_cmdline_user_args()

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
## PAINTED (styles:now): the field through the style's own whole pass, a LOCAL
## sky of its own with nothing in front of its far sky (`LocalSky.field_only`)
var _painted: LocalSky = null
var _style: StringName = &""


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
	if n == null or (n.index == node_index and LocalSky.style_now() == _style):
		return
	node_index = n.index
	_style = LocalSky.style_now()
	version += 1
	if not _enabled:
		return
	if _style == &"painted":
		_paint_field(n)
		return
	if _painted != null and is_instance_valid(_painted):
		_painted.queue_free()
		_painted = null
	_build()
	_box.visible = true
	for k: String in LocalSky.far_defaults(n).keys():
		_far_mat.set_shader_parameter(k, LocalSky.far_defaults(n)[k])
	_far_mat.set_shader_parameter("glow_k", 0.0)
	# (where it had slid to: a new system's sky does not snap back)
	_far_mat.set_shader_parameter("u_skyPan", pan)
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


## PAINTED: a LOCAL sky of the field's own, far sky only, through B's whole
## paint (its tables, its ramps, its band memory), so the stars LOCAL paints and
## the field's are the same where its cloud is not.
func _paint_field(n: MapGen.MapNode) -> void:
	if _box != null:
		_box.visible = false
	if _painted == null or not is_instance_valid(_painted):
		_painted = LocalSky.new()
		_painted.field_only = true
		_painted.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_painted.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(_painted)
	_painted.sky_pan_hold = pan
	_painted.setup(n)


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
	if _painted != null and is_instance_valid(_painted):
		# (PAINTED: LOCAL's camera and its cloud's closing in, held by the field's
		# own painted sky)
		var moved: bool = _painted.cam_hold != sky.cam or not is_equal_approx(_painted.closed, sky.closed)
		_painted.cam_hold = sky.cam
		var lfm: ShaderMaterial = sky.get("_far_mat")
		var lpp: Variant = lfm.get_shader_parameter("u_skyPan") if lfm != null and bool(sky.get("sky_took")) else null
		if lpp is Vector2 and lpp != pan:
			pan = lpp
			_painted.sky_pan_hold = pan
			moved = true
		if not is_equal_approx(_painted.closed, sky.closed):
			_painted.set_closed(sky.closed)
		if moved:
			version += 1
		return
	var fm: ShaderMaterial = sky.get("_far_mat")
	if fm == null or not bool(sky.get("_ready_sky")):
		return
	# (LOCAL's own slide is the field's while it is up -- once it has taken the
	# field over where it stood: `LocalSky.sky_took`)
	var took := bool(sky.get("sky_took"))
	var lp: Variant = fm.get_shader_parameter("u_skyPan")
	if took and lp is Vector2:
		pan = lp
	_build()
	var parts: Array = []
	for u: Dictionary in FAR.get_shader_uniform_list():
		var nm := String(u.name)
		var v: Variant = fm.get_shader_parameter(nm)
		if nm == "glow_k":
			v = 0.0
		if nm == "u_skyPan":
			v = pan
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
	# (and its drift: the harness holds a move to it)
	_drift()
	if not _enabled:
		return
	_place()
	var sky := live_local_sky()
	if sky != null:
		feed(sky)


## A screen's own pan as the field slides by it (game px of `u_skyPan`), or
## null: LOCAL's is copied whole (`feed`), and a screen without one holds it.
static func screen_pan(s: Variant) -> Variant:
	if s is StarchartScreen and is_instance_valid(s) and (s as StarchartScreen)._chart != null:
		return (s as StarchartScreen)._chart.sky_pan
	if s is SystemMapScreen and is_instance_valid(s) and (s as SystemMapScreen).view != null:
		return (s as SystemMapScreen).view.call(&"_cam_pan") * MAP_K
	return null


func _drift() -> void:
	# (a harness's `drift=off`: the field still, as before)
	if ZoomLadder.busy() or _drift_off:
		_pan_src = null
		return
	var s: Variant = Router.current
	var q: Variant = screen_pan(s)
	if q == null:
		_pan_src = null
		return
	if _pan_src != s:
		_pan_src = s
		_pan_ref = q
		_pan_base = pan
		return
	set_pan((_pan_base + (q as Vector2) - _pan_ref).round())


## The field slid to `p` (whole game px), drawn again if it moved.
func set_pan(p: Vector2) -> void:
	if p == pan:
		return
	pan = p
	version += 1
	if _far_mat != null:
		_far_mat.set_shader_parameter("u_skyPan", pan)
		_redraw()
	if _painted != null and is_instance_valid(_painted):
		_painted.sky_pan_hold = pan


## THE MAP'S CLOUD PAST ITS PICTURE (cloud:A): in a system inside a cloud, the
## map's own sky, where its picture has it, across the screens' area, under the
## picture's own soft edge (`nav_ext.gdshader`); none in a clear sky.
func _gas_past(map: SystemMapScreen, frame: Rect2) -> void:
	var ext: TextureRect = map.get("_gas_ext")
	if ext == null or not is_instance_valid(ext):
		return
	var v = map.view
	# (in a clear sky too, Jon: "why does a galaxy disappear near the side
	# panel?" -- the map's worlds, orbits and its star's light run on past its
	# picture's frame to the field's own edges, under the glass, as a cloud's gas
	# does; only the picture is clicked)
	var drawn: bool = v != null and v.get("_scene") != null and bool(v.get("_ready_sky"))
	var cloud: bool = drawn and v.get("_neb_mat") != null
	ext.visible = drawn
	if not drawn:
		return
	var sc: SubViewport = v.get("_scene")
	if ext.texture != sc.get_texture():
		ext.texture = sc.get_texture()
	var at: Vector2 = map._frame.global_position + map._box.position
	var c := Router.content.get_global_rect() if Router.content != null else Rect2(at, Vector2(960, 540))
	# (on to the screens' own edges, the cloud drawn on past its end: `nav_ext`)
	var sz := Vector2(maxf(960.0, c.end.x - at.x), maxf(540.0, c.end.y - at.y))
	var r := Rect2(at, sz)
	ext.position = at - map.global_position
	ext.size = sz
	var o := r.intersection(c)
	var m := ext.material as ShaderMaterial
	m.set_shader_parameter("inner", Vector4(frame.position.x, frame.position.y, frame.size.x, frame.size.y))
	m.set_shader_parameter("outer", Vector4(o.position.x, o.position.y, o.size.x, o.size.y))
	m.set_shader_parameter("span", sz / Vector2(960, 540))
	# (past the sky's end, the same cloud drawn on: `SystemView` `_past`)
	var pv: Variant = v.get("_past")
	var pon: bool = pv is SubViewport and is_instance_valid(pv)
	m.set_shader_parameter("past_on", pon)
	# (a clear sky has nothing past its end but the field: no copy of its left)
	m.set_shader_parameter("past_cut", not cloud)
	if pon and m.get_shader_parameter("past_tex") != (pv as SubViewport).get_texture():
		m.set_shader_parameter("past_tex", (pv as SubViewport).get_texture())


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
			_gas_past(s as SystemMapScreen, r)
		elif s is StarchartScreen and (s as StarchartScreen)._chart != null and (s as StarchartScreen)._chart._sky != null:
			m = (s as StarchartScreen)._chart._sky.material
			r = (s as StarchartScreen)._chart.get_global_rect()
			# (its sky drawn on past the picture, to the field's own edges: it fades
			# out there, never at the picture's frame -- `MapChart.sky_out`)
			var so: Rect2 = (s as StarchartScreen)._chart.sky_out
			if so.has_area():
				r = Rect2((s as StarchartScreen)._chart.global_position + so.position, so.size)
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
	if _painted != null and is_instance_valid(_painted) and _painted.get("_scene") != null:
		return (_painted.get("_scene") as SubViewport).get_texture()
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
