class_name LocalSky
extends Control

## LOCAL'S SKY: what is out there behind the fight, the jump and the approach,
## in the rendering style Jon picked (`DisplaySettings.render_style`) -- the
## SAME system the sector map draws, seen side on.
##
## THE SECTOR MAP looks down on the system's plane at a slant (`SystemView`,
## TILT 0.38); LOCAL is the same system from nearly in that plane, the camera a
## little above it: the plane is a thin band across the top of the view, the
## system's own star on it (its kind, its colour, breathing, now and then a
## prominence; the pulsar and its beams; the core's black hole, the one every
## style shares, `CoreLegacy` on `legacy_hole.gdshaderinc`), its own worlds
## along it where their orbits have them (`PlanetView`, the map's painter, the
## same worlds), and behind it all the nebula the system sits in, as the map's
## sky draws it from inside (`sky_nebula.gdshader`, the same kind, shape,
## colours and seed, its gas streaming on its currents and lit by that star),
## and behind that the far sky every chart style keeps -- distant galaxies and
## three depths of stars (`local_far.gdshader` on `chart_bg.gdshaderinc`).
##
## THE STYLES, as the map draws them:
##   * SIMPLIFIED: the cloud lit by the sun, set to the system's own short
##     palette (`map_palette`, found from its first picture) in 2x2 blocks;
##   * PAINTED: the far picture painted on B's curated ramps with its band
##     memory (`SectorPainted`), the sun and the worlds painting themselves, the
##     life of it in held poses;
##   * RADIANT: the cloud as a volume the sun shines through, the worlds'
##     shadows as shafts in the lit gas;
##   * LEGACY: LOCAL as it was before the port -- the view's wash, tinted by
##     the system's star toward the right, its plain grey starfield, and the
##     gas blowing through (`NebulaWeather`, the view's) -- with the map's old
##     cloud (`sky_nebula_legacy`) and the system's band, set to its palette
##     as the map's LEGACY is.
##
## THE CAMERA moves when the ship does: it follows the hull's approach and its
## departure a little over half way (`CAM_FOLLOW`), and every layer slides by its own depth --
## the far stars and galaxies least, the cloud more, the system's band most --
## in whole 2x2 blocks. Otherwise it holds still: the motion is the gas, the
## star and the weather.
##
## READABILITY FIRST. The fight is played across the middle of the view, so the
## sky there is dimmed and its highlights pressed down a soft knee
## (`local_grade.gdshader`, PLAY), whatever the system; the bright things --
## the star, the hole, the lit heart of the cloud -- sit in the band above it.
## The weather is the map's own events, rarer (`WX_SLOW`), placed above the
## fight and never one that flashes; none at all with reduced motion.
##
## Cheap: one 480x270 picture of 2x2 blocks for the whole screen (the view is
## a window onto it, so the map's shaders work in their own 960x540 frame),
## its cloud baked once a system (`SkyBake.field`, kept for the next visit).

const SkyBakeS := preload("res://scripts/ui/sysmap/SkyBake.gd")
const SunViewS := preload("res://scripts/ui/sysmap/SunView.gd")
const PulsarViewS := preload("res://scripts/ui/sysmap/PulsarView.gd")
const CoreLegacyS := preload("res://scripts/ui/sysmap/CoreLegacy.gd")
const SystemViewS := preload("res://scripts/ui/sysmap/SystemView.gd")
const SkyWeatherS := preload("res://scripts/ui/sysmap/SkyWeather.gd")
const SectorPaintedS := preload("res://scripts/ui/sysmap/SectorPainted.gd")
const SkyGalaxiesS := preload("res://scripts/ui/sysmap/SkyGalaxies.gd")
const SystemPaletteS := preload("res://scripts/ui/sysmap/SystemPalette.gd")
const NEB_SKY := preload("res://shaders/sky_nebula.gdshader")
const NEB_SKY_LEGACY := preload("res://shaders/sky_nebula_legacy.gdshader")
const FAR := preload("res://shaders/local_far.gdshader")
const GRADE := preload("res://shaders/local_grade.gdshader")
const PALETTE := preload("res://shaders/map_palette.gdshader")
const KIND_NAMES := ["ORDINARY", "RED", "BLUE", "PULSAR", "CORE"]

## THE SYSTEM'S BAND, in the 960x540 game frame: the plane's line (y), how far
## the star may sit either side of the middle, and how far the system's
## outermost orbit reaches either side of the star.
const HORIZON := 76.0
const SUN_X := Vector2(410.0, 550.0)
const SPAN := 470.0
## the plane seen from just above it: a world's depth on its orbit times this
const TILT := 0.07
## the star drawn at this share of its map size, by kind
const SUN_K := {"ORDINARY": 0.62, "RED": 0.44, "BLUE": 0.52}
const PULSAR_K := 0.42
const HOLE_K := 0.30
const MIN_WORLD_R := 3.0
## THE CAMERA: how much of the ship's travel it follows, and how far each layer
## slides for a pixel of the camera's (the far sky's own depths are in
## `chart_bg`: stars 0.04, 0.10, 0.20, galaxies 0.05)
const CAM_FOLLOW := 0.6
const F_CLOUD := 0.08
const F_BAND := 0.16
## THE PLAY: the game frame below its top band is where the fight is played,
## and the sky there is held under its budget (`local_grade`): dimmed from
## PLAY.x down, wholly by PLAY.y (game px)
const PLAY := Vector2(70.0, 140.0)
## PAINTED's sky is painted after the budget on B's curated ramps, which pick
## a step by where a block falls on them, so its puffed masses come out as
## vivid as ever: the painted picture is dimmed again, evenly (its bands kept
## apart), by this much below the top band -- or its spread behind the play
## went over the budget, 0.053 against 0.04
const PAINTED_DIM := 0.72
## the cloud's sky pixel at the star: high in its bake, so the view below the
## star stays inside the baked field
const CC := Vector2(480.0, 150.0)
## THE WEATHER: the map's medium events, this many times rarer
const WX_SLOW := 2.5

# ---- what SectorPainted and the map's helpers read, by SystemView's names
var node: MapGen.MapNode
var layout: SystemLayout
var kind: String = "ORDINARY"
## seconds on this sky's clock
var t := 0.0
var _scene: SubViewport
var _sky_look: Dictionary = {}
## (no baked sky here: PAINTED writes its look onto it, and nothing reads it)
var _sky_mat: ShaderMaterial
var _neb_mat: ShaderMaterial
var _pt := {}

## the style this sky is drawn in
var style: StringName = &"simplified"
var legacy := false
var painted := false
var radiant := false
## the ship the camera follows (`EncounterView`), and the camera's travel now
var cam_ship: Control = null
var cam := Vector2.ZERO

var _box: SubViewportContainer
var _far: ColorRect
var _far_mat: ShaderMaterial
var _neb: ColorRect
var _grade_mat: ShaderMaterial
var _palette: ColorRect
var _palette_mat: ShaderMaterial
var star: Node2D = null
var _worlds: Node2D
var _views := {}
var _key := ""
var _gen := 0
var _ready_sky := false
var _palette_built := false
var _frame := 0
var _sun := Vector2(480.0, HORIZON)
var _s := 0.5
var _sd := 0.0
var _tint := Vector3.ONE
var _flare := 0.0
var _low_skip := false
var _low_dt := 0.0
## the cloud's bake, kept for the next visit: key -> [field0, field1, field2]
static var _baked := {}
const BAKED_MAX := 3

## THE WEATHER's two slots, as the map's (`SkyWeather`): A one medium event, B
## one small one; each {name, ev, age, end, at, dir, seed, k, pre, size}
var _wx_rng := RandomNumberGenerator.new()
var _wa := {}
var _wb := {}
var _wx_clock := 0.0
var _wx_next_a := 0.0
var _wx_next_b := 0.0
var _wx_sky: StringName = &""
var _wx_force: StringName = &""
## per sky: the medium events LOCAL plays (none that flash), [name, w_ev, lasts,
## precursor], and its small one; the map's cadence (`SkyWeather.CADENCE`)
const WX_M := {
	&"emission": [[&"tide", 1, 10.0, 0.0], [&"jet", 2, 14.0, 0.0]],
	&"reflection": [[&"shaft", 0, 9.0, 2.0], [&"breathe", 2, 28.0, 0.0], [&"spoke", 1, 18.0, 0.0]],
	&"planetary": [[&"ringrun", 0, 8.0, 0.0], [&"halo", 2, 26.0, 0.0]],
	&"remnant": [[&"shock", 0, 6.0, 1.5]],
	&"dark": [[&"rays", 1, 14.0, 0.0]],
}
const WX_S := {
	&"emission": [&"glints", 1, 5.1],
	&"reflection": [&"glitter", 1, 5.0],
	&"planetary": [&"lamps", 1, 8.0],
	&"dark": [&"dawn", 1, 7.5],
}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false


func _ready() -> void:
	if not Sig.render_style_changed.is_connected(_restyle):
		Sig.render_style_changed.connect(_restyle)


## The style the sky is drawn in: the setting, or a harness's `style=`.
static func style_now() -> StringName:
	for s: StringName in [&"legacy", &"painted", &"radiant", &"simplified"]:
		if ("style=%s" % s) in OS.get_cmdline_user_args():
			return s
	return DisplaySettings.render_style


## Point the sky at a system. Cheap to call again for the same one.
func setup(n: MapGen.MapNode) -> void:
	if n == null:
		return
	var key := "%d|%s|%s" % [n.index, style_now(), DisplaySettings.graphics_low]
	if key == _key:
		return
	_key = key
	node = n
	_build()


func _restyle() -> void:
	if node != null:
		setup(node)


static func headless() -> bool:
	return DisplayServer.get_name() == "headless" or "sim" in OS.get_cmdline_user_args()


# ------------------------------------------------------------------ building

func _build() -> void:
	_gen += 1
	for c in get_children():
		c.queue_free()
	_views.clear()
	_pt = {}
	_neb_mat = null
	_neb = null
	_palette = null
	_palette_mat = null
	star = null
	_ready_sky = false
	_palette_built = false
	_frame = 0
	t = 0.0
	_wa = {}
	_wb = {}
	style = style_now()
	legacy = style == &"legacy"
	painted = style == &"painted"
	radiant = style == &"radiant"
	layout = SystemLayout.of(node)
	kind = KIND_NAMES[layout.star]
	_sd = float(node.index % 97) * 0.731 + 3.0
	_sun = Vector2(roundf(lerpf(SUN_X.x, SUN_X.y, SkyBakeS.hash2(node.index, 401)) / 2.0) * 2.0, HORIZON)
	_s = SPAN / maxf(layout.edge + 20.0, 120.0)
	_tint = star_light()
	# THE SKY AS THE MAP SEES IT (`SystemView.show_system`): the cloud the system
	# sits in, by its kind; SIMPLIFIED's core a cloud of warm gas round the hole
	_sky_look = SkyBakeS.look_for(node, kind)
	if layout.star == SystemLayout.StarKind.CORE and not legacy:
		_sky_look.neb = 5
		_sky_look.shape = 0
		_sky_look.hue = Vector3(0.62, 0.32, 0.2)
	if layout.star == SystemLayout.StarKind.PULSAR:
		# A PULSAR'S SHELL: the remnant of the star that made it, in its own blues
		# (the map lays it in its baked sky; seen side on it is the cloud round
		# the system, a remnant's tangled filaments lit near the pulsar)
		_sky_look.neb = NebulaField.Kind.REMNANT
		_sky_look.shape = 0
		_sky_look.hue = Vector3(0.3, 0.45, 0.95)
	var neb_on := _sky_look.has("neb")
	if headless():
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
	_scene.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_box.add_child(_scene)
	_sky_mat = ShaderMaterial.new()
	var far_group: Array[Node] = []
	# THE FAR SKY
	_far = _rect()
	_far_mat = ShaderMaterial.new()
	_far_mat.shader = FAR
	_far_mat.set_shader_parameter("legacy", legacy)
	_far_mat.set_shader_parameter("u_skySeed", float(node.index % 97) * 0.37)
	_far_mat.set_shader_parameter("star_light", _tint)
	# (LEGACY: the view's own wash, its star's tint toward the right)
	var wt := MapGen.star_colour(node).darkened(0.72)
	_far_mat.set_shader_parameter("wash_tint", Vector3(wt.r, wt.g, wt.b))
	var st: Color = Color("#ffc29a") if layout.star == SystemLayout.StarKind.RED else (Color("#eaf4ff") if layout.star == SystemLayout.StarKind.BLUE else Color("#f6f2e4"))
	_far_mat.set_shader_parameter("old_tint", Vector3(st.r, st.g, st.b))
	var clear: bool = not bool(_sky_look.get("nebula", true)) and layout.star < SystemLayout.StarKind.PULSAR
	_far_mat.set_shader_parameter("glow_k", 1.0 if clear else 0.0)
	_far_mat.set_shader_parameter("glow_r", 70.0 * (1.5 if layout.star == SystemLayout.StarKind.RED else 1.0))
	var ba := float(node.index) * 0.731 * 2.7
	_far_mat.set_shader_parameter("band_n", Vector2(-sin(ba), cos(ba)))
	_far_mat.set_shader_parameter("band_off", (SkyBakeS.hash2(node.index, 403) - 0.5) * 300.0)
	_far_mat.set_shader_parameter("band_w", 70.0 if clear else 0.0)
	_far.material = _far_mat
	_scene.add_child(_far)
	far_group.append(_far)
	# THE CLOUD THE SYSTEM SITS IN, as the map's sky draws it from inside
	if neb_on:
		_neb = _rect()
		_neb_mat = ShaderMaterial.new()
		_neb_mat.shader = NEB_SKY_LEGACY if legacy else NEB_SKY
		_neb_mat.set_shader_parameter("kind", int(_sky_look.neb))
		_neb_mat.set_shader_parameter("shape", int(_sky_look.shape))
		_neb_mat.set_shader_parameter("hue", _sky_look.hue)
		_neb_mat.set_shader_parameter("sd", _sd)
		if not legacy:
			_neb_mat.set_shader_parameter("exposure", {NebulaField.Kind.REFLECTION: 0.8, NebulaField.Kind.EMISSION: 0.88}.get(int(_sky_look.neb), 1.0))
			_neb_mat.set_shader_parameter("cc_em", CC)
			_neb_mat.set_shader_parameter("bubble_r", _bubble_r())
			_neb_mat.set_shader_parameter("star_light", _tint)
			if radiant:
				_neb_mat.set_shader_parameter("radiant", true)
				_neb_mat.set_shader_parameter("exposure", float(_neb_mat.get_shader_parameter("exposure")) * 0.86)
		_neb.material = _neb_mat
		_neb.visible = false
		_scene.add_child(_neb)
		far_group.append(_neb)
	# THE PULSAR draws with the far sky (its beams sweep the whole frame)
	if layout.star == SystemLayout.StarKind.PULSAR:
		star = PulsarViewS.new()
		star.position = _sun
		_scene.add_child(star)
		star.call("setup", node.index, Rect2(0, 0, 960, 540))
		star.call("set_zoom", PULSAR_K)
		(star.get("_web_mat") as ShaderMaterial).set_shader_parameter("web_on", legacy)
		far_group.append(star)
	# THE BUDGET over all of it
	var copy := BackBufferCopy.new()
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	_scene.add_child(copy)
	far_group.append(copy)
	var grade := _rect()
	_grade_mat = ShaderMaterial.new()
	_grade_mat.shader = GRADE
	_grade_mat.set_shader_parameter("ramp", PLAY)
	grade.material = _grade_mat
	_scene.add_child(grade)
	far_group.append(grade)
	# THE SYSTEM'S OWN PALETTE (SIMPLIFIED, RADIANT, LEGACY), from its first picture
	if not painted:
		var copy2 := BackBufferCopy.new()
		copy2.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
		_scene.add_child(copy2)
		_palette = _rect()
		_palette_mat = ShaderMaterial.new()
		_palette_mat.shader = PALETTE
		_palette_mat.set_shader_parameter("pal_n", 0)
		_palette_mat.set_shader_parameter("cell", 1)
		_palette_mat.set_shader_parameter("x0", 0.0)
		_palette.material = _palette_mat
		_scene.add_child(_palette)
	if painted:
		# PAINTED: everything far into the far picture, painted on B's ramps
		var svp := SectorPaintedS.build(self)
		for ch in far_group:
			ch.reparent(svp, false)
		_scene.move_child(_pt.tvp, 0)
		_scene.move_child(_pt.rect, 1)
		var pcopy := BackBufferCopy.new()
		pcopy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
		_scene.add_child(pcopy)
		_scene.move_child(pcopy, 2)
		var pgrade := _rect()
		var pgm := ShaderMaterial.new()
		pgm.shader = GRADE
		pgm.set_shader_parameter("ramp", PLAY)
		pgm.set_shader_parameter("dim", PAINTED_DIM)
		pgm.set_shader_parameter("cap", 1.0)
		pgrade.material = pgm
		_scene.add_child(pgrade)
		_scene.move_child(pgrade, 3)
	# THE STAR AND THE WORLDS along the band
	_worlds = Node2D.new()
	_scene.add_child(_worlds)
	if layout.star == SystemLayout.StarKind.CORE:
		star = CoreLegacyS.new()
		star.position = _sun
		_worlds.add_child(star)
		star.call("setup")
		star.set("hole_k", HOLE_K)
	elif layout.star != SystemLayout.StarKind.PULSAR:
		star = SunViewS.new()
		star.position = _sun
		_worlds.add_child(star)
		star.call("setup", kind, node.index, layout.star_r)
		star.call("set_zoom", star_k())
		var sm := star.get("_mat") as ShaderMaterial
		sm.set_shader_parameter("half_pal", true)
		sm.set_shader_parameter("cell", 2)
		if painted:
			sm.set_shader_parameter("painted", true)
	if star != null:
		_set_deep(star, "cell", 2)
		_set_deep(star, "px_scale", 2.0)
		if painted:
			_set_deep(star, "painted", true)
	for i in layout.bodies.size():
		var b := layout.bodies[i]
		if b.world == &"":
			continue
		var v: Node2D = Worlds.view_for(b.world)
		v.call("set_world", b.world, b.seed, _world_r(b))
		v.call("set_cell", 2)
		_worlds.add_child(v)
		_views[i] = v
		if painted:
			SectorPaintedS.paint_world(self, v)
		if radiant:
			_set_deep(v, "radiant", true)
	_wx_setup()
	_place_box()
	_step(0.0)
	if neb_on:
		_bake_cloud(_gen)
	else:
		_ready_sky = true


func _rect() -> ColorRect:
	var r := ColorRect.new()
	r.size = Vector2(960, 540)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## The cloud's density, baked once a system and kept (`SkyBake.field`).
func _bake_cloud(gen: int) -> void:
	var key := "%d|%s|%s" % [node.index, "L" if legacy else "C", int(_sky_look.neb)]
	var f: Array = _baked.get(key, [])
	if f.is_empty():
		var bake := SkyBakeS.new()
		await bake.field(self, int(_sky_look.neb), int(_sky_look.shape), _sd, CC, legacy)
		if gen != _gen or not is_inside_tree():
			return
		f = [bake.field0, bake.field1, bake.field2]
		if _baked.size() >= BAKED_MAX:
			_baked.erase(_baked.keys()[0])
		_baked[key] = f
	_neb_mat.set_shader_parameter("t0", f[0])
	_neb_mat.set_shader_parameter("t1", f[1])
	if not legacy:
		_neb_mat.set_shader_parameter("t2", f[2])
	_neb_mat.set_shader_parameter("ftex", Vector2(SkyBakeS.FIELD_W, SkyBakeS.FIELD_H))
	_neb_mat.set_shader_parameter("fmb", float(SkyBakeS.FIELD_MB))
	if painted:
		# PAINTED's cloud built as B's, the map's own way (`SectorPainted.bake_puffs`:
		# its sheets of domed masses laid where the cloud is), kept with the field
		if f.size() > 3:
			_neb_mat.set_shader_parameter("p_sheets", f[3])
			_neb_mat.set_shader_parameter("p_sheets_on", true)
		else:
			await SectorPaintedS.bake_puffs(self, f[0])
			if gen != _gen or not is_inside_tree():
				return
			var ps = _neb_mat.get_shader_parameter("p_sheets")
			if ps != null:
				f.append(ps)
	_neb.visible = true
	_ready_sky = true


## The emission bubble's radius (`SystemView._bubble_r`), in this frame's px:
## in a gap between orbits near four fifths of the way out.
func _bubble_r() -> float:
	var E := layout.edge
	var want := 0.8 * (E + 20.0)
	var rs: Array[float] = [0.0]
	for b in layout.bodies:
		if b.kind == &"belt":
			rs.append(b.orbit - 28.0)
			rs.append(b.orbit + 28.0)
		else:
			rs.append(b.orbit)
	rs.append(E + 400.0)
	rs.sort()
	var best := want
	var bd := INF
	for i in rs.size() - 1:
		var lo: float = rs[i] + 24.0
		var hi: float = rs[i + 1] - 24.0
		if hi <= lo:
			continue
		var at := clampf(want, lo, hi)
		if absf(at - want) < bd:
			bd = absf(at - want)
			best = at
	return best * _s


func _world_r(b: SystemLayout.Body) -> float:
	var r := maxf(b.r, SystemViewS.min_r) * _s
	if layout.star == SystemLayout.StarKind.PULSAR:
		r *= SystemViewS.PULSAR_WORLD_K
	return maxf(roundf(r), MIN_WORLD_R)


static func _set_deep(n: Node, key: String, value: Variant) -> void:
	if n is CanvasItem and (n as CanvasItem).material is ShaderMaterial:
		((n as CanvasItem).material as ShaderMaterial).set_shader_parameter(key, value)
	for c in n.get_children():
		_set_deep(c, key, value)


# ------------------------------------------------------------------ what the map's helpers ask

## the star's size against its map size
func star_k() -> float:
	if layout == null:
		return 1.0
	if layout.star == SystemLayout.StarKind.PULSAR:
		return PULSAR_K
	if layout.star == SystemLayout.StarKind.CORE:
		return HOLE_K
	return float(SUN_K.get(kind, 0.6))


func star_light() -> Vector3:
	var c: Vector3 = SkyBakeS.STARCOL.get(kind, SkyBakeS.STARCOL.ORDINARY)
	var l := Vector3(pow(c.x, 2.2), pow(c.y, 2.2), pow(c.z, 2.2))
	return l / maxf(l.x, maxf(l.y, l.z))


## the star on screen this frame, on the block grid
func origin() -> Vector2:
	return _block_round(_sun - cam * F_BAND)


## the cloud's slide: its sky pixel CC at the star, and its own depth
func neb_off() -> Vector2:
	return _block_round(_sun - CC - cam * F_CLOUD)


func pose(x: float, fps: float = 8.0) -> float:
	return floor(x * fps) / fps if painted else x


static func gfx_low() -> bool:
	return DisplaySettings.graphics_low


static func _block_round(p: Vector2) -> Vector2:
	return (p / 2.0).round() * 2.0


# ------------------------------------------------------------------ every frame

func _process(delta: float) -> void:
	if _scene == null:
		return
	# GRAPHICS LOW: the cloud reads its field once (`sky_nebula`'s `low`), and
	# the whole sky is drawn every other frame -- its gas steps a block every
	# few seconds and the star redraws at 30 a second anyway (`SunView`), so
	# nothing in it moves faster than that
	if gfx_low():
		_low_skip = not _low_skip
		_set_update(SubViewport.UPDATE_ONCE if not _low_skip else SubViewport.UPDATE_DISABLED)
		if _low_skip:
			_low_dt += delta
			return
		delta += _low_dt
		_low_dt = 0.0
	elif _scene.render_target_update_mode != SubViewport.UPDATE_ALWAYS:
		_set_update(SubViewport.UPDATE_ALWAYS)
	_step(delta)


## The sky's pictures drawn this frame or not (PAINTED's far picture and its
## band memory with it).
func _set_update(m: SubViewport.UpdateMode) -> void:
	_scene.render_target_update_mode = m
	if not _pt.is_empty():
		(_pt.tvp as SubViewport).render_target_update_mode = m
		(_pt.svp as SubViewport).render_target_update_mode = m


func _place_box() -> void:
	if _box == null:
		return
	var p := -(get_global_rect().position / 2.0).round() * 2.0
	if _box.position != p:
		_box.position = p


func _step(delta: float) -> void:
	_frame += 1
	_place_box()
	# REDUCED MOTION: the sky holds still -- its gas, its star, the hole's disc,
	# the pulsar's beams -- and the weather never comes
	var still := DisplaySettings.reduced_motion
	if not still:
		t += delta
	# THE CAMERA follows the ship's own travel: its approach and departure
	var cx := 0.0
	if cam_ship != null and is_instance_valid(cam_ship) and cam_ship.is_inside_tree():
		cx = cam_ship.position.x * CAM_FOLLOW
	cam = Vector2(roundf(cx), 0.0)
	var o := origin()
	var vr := get_global_rect()
	_far_mat.set_shader_parameter("wash", Vector2(vr.position.x, vr.size.x))
	_far_mat.set_shader_parameter("u_skyPan", (cam / 2.0).round() * 2.0)
	_far_mat.set_shader_parameter("star_at", o)
	_far_mat.set_shader_parameter("breath", SystemViewS.breath(pose(t, 4.0)))
	if _neb_mat != null:
		_neb_mat.set_shader_parameter("off", neb_off())
		_neb_mat.set_shader_parameter("time", 0.0 if still else pose(t, 4.0))
		_neb_mat.set_shader_parameter("low", gfx_low())
		if not legacy:
			_neb_mat.set_shader_parameter("star_at", Vector2(o))
			_neb_mat.set_shader_parameter("zoom", 1.0)
			_neb_mat.set_shader_parameter("lzoom", 1.0)
			_neb_mat.set_shader_parameter("home_zoom", 1.0)
			_neb_mat.set_shader_parameter("lscale", 1.35)
			_neb_mat.set_shader_parameter("breath", SystemViewS.breath(pose(t, 4.0)))
			_neb_mat.set_shader_parameter("hole_r", 116.0 * HOLE_K)
	if painted:
		SectorPaintedS.push(self)
	_step_star(o)
	_step_worlds(o)
	_wx_step(delta)
	if _ready_sky and not _palette_built and _frame > 8 and _palette_mat != null:
		_build_palette()


func _step_star(o: Vector2) -> void:
	if star == null:
		return
	star.position = o
	_flare = 0.0
	match layout.star:
		SystemLayout.StarKind.PULSAR:
			star.call("step", pose(t))
		SystemLayout.StarKind.CORE:
			star.call("step", pose(t, 8.0))
		_:
			star.call("step", pose(t, 4.0))
			_flare = SystemViewS.prominence(pose(t, 6.0)).z
			var sm: ShaderMaterial = star.get("_mat")
			sm.set_shader_parameter("c_breath", SystemViewS.breath(pose(t, 4.0)))
			sm.set_shader_parameter("c_prom", SystemViewS.prominence(pose(t, 6.0)))
			sm.set_shader_parameter("halo_cut", 36.0 if legacy else 72.0)


## Each world where its orbit has it now, seen from just above the plane: across
## by its x, a little lower the nearer it is; the ones behind the star drawn
## before it and hidden by its disc.
func _step_worlds(o: Vector2) -> void:
	if _views.is_empty():
		return
	var order: Array = _views.keys()
	var pos := {}
	for i: int in order:
		pos[i] = layout.bodies[i].pos(t)
	order.sort_custom(func(a: int, b: int) -> bool: return (pos[a] as Vector2).y < (pos[b] as Vector2).y)
	var star_placed := star == null or layout.star == SystemLayout.StarKind.PULSAR
	var bp := PackedVector4Array()
	for i: int in order:
		var p: Vector2 = pos[i]
		var v: Node2D = _views[i]
		if not star_placed and p.y >= 0.0:
			_worlds.move_child(star, -1)
			star_placed = true
		_worlds.move_child(v, -1)
		var b := layout.bodies[i]
		var at := _block_round(o + Vector2(p.x, p.y * TILT) * _s)
		var hs := Worlds.half_size(b.world, _world_r(b))
		v.position = at + Vector2.ONE * float(hs % 2)
		var behind := p.y < 0.0 and layout.star != SystemLayout.StarKind.CORE and star != null
		var len := maxf(p.length(), 1.0)
		# lit from the star: across, a little from above, and from behind for a
		# world in front of it
		var light := Vector3(-p.x / len, -p.y / len * TILT, -p.y / len * 0.8 + 0.3).normalized()
		var kl := 0.95 + 0.35 * SystemViewS.light_at(p.x, p.y)
		if layout.star == SystemLayout.StarKind.PULSAR:
			kl = 0.75
		var sr := float(layout.star_r) * star_k()
		v.call("step", t, light, kl, o if behind else Vector2(-9999, -9999), sr if behind else 0.0)
		var vm: ShaderMaterial = v.get("_mat")
		if vm != null:
			if not legacy:
				vm.set_shader_parameter("star_tint", _tint)
				vm.set_shader_parameter("night_fill", Vector3(0.02, 0.02, 0.03))
			vm.set_shader_parameter("flare", _flare)
			vm.set_shader_parameter("lift", 0.0 if legacy else 1.0)
		if bp.size() < 24:
			bp.append(Vector4(v.position.x, v.position.y, _world_r(b), _world_r(b)))
	if not star_placed:
		_worlds.move_child(star, -1)
	if radiant and _neb_mat != null:
		var rg := PackedFloat32Array()
		rg.resize(24)
		var n_cast := bp.size()
		bp.resize(24)
		_neb_mat.set_shader_parameter("r_bodies", bp)
		_neb_mat.set_shader_parameter("r_rings", rg)
		_neb_mat.set_shader_parameter("r_nb", n_cast)
		_neb_mat.set_shader_parameter("r_flare", _flare)


## The palette from the system's own first picture (`SystemView`'s, with the
## same reserved steps), once the cloud is in.
func _build_palette() -> void:
	_palette_built = true
	await RenderingServer.frame_post_draw
	if _scene == null or not is_inside_tree():
		return
	var img := _scene.get_texture().get_image()
	var cloud := _neb_mat != null
	var extra := PackedVector3Array()
	if not cloud:
		for gt: Vector3 in SkyGalaxiesS.TONES:
			extra.append(gt)
	if legacy:
		# (LEGACY: the old starfield's own greys, which a cut alone would lose)
		for h: String in ["#070a10", "#232d39", "#4d5f73", "#9fc0e0"]:
			var cl := Color(h)
			extra.append(Vector3(cl.r, cl.g, cl.b))
	elif cloud:
		for h: String in SystemViewS.C_RESERVED.get(int(_sky_look.neb), []):
			var cr := Color(h)
			extra.append(Vector3(cr.r, cr.g, cr.b))
		for h: String in ["#fff6e2", "#ffdc96", "#ffb054", "#ec7a26", "#c24a14", "#84280c", "#ff8a50"]:
			var cw := Color(h)
			extra.append(Vector3(cw.r, cw.g, cw.b))
	elif layout.star == SystemLayout.StarKind.PULSAR:
		for h: String in ["#3a0e14", "#6a1a20", "#a02a32", "#d0505a", "#16302e", "#24504c", "#357a72", "#56b0a2"]:
			var cr := Color(h)
			extra.append(Vector3(cr.r, cr.g, cr.b))
	elif layout.star != SystemLayout.StarKind.CORE:
		var sc: Vector3 = SkyBakeS.STARCOL.get(kind, SkyBakeS.STARCOL.ORDINARY)
		var deep := Vector3(pow(sc.x, 3.0), pow(sc.y, 3.0), pow(sc.z, 3.0))
		deep /= maxf(deep.x, maxf(deep.y, deep.z))
		for kq: float in [0.07, 0.11, 0.17, 0.26, 0.38]:
			extra.append(deep * kq)
	var pal: PackedVector3Array = SystemPaletteS.build(img, 0, Vector2(origin()) / 2.0, float(layout.star_r) * star_k() / 2.0, kind, 0,
		SystemPaletteS.K_NEBULA if cloud else SystemPaletteS.K, extra, legacy or not cloud,
		not legacy and cloud and int(_sky_look.neb) <= NebulaField.Kind.REFLECTION, SystemPaletteS.MERGE, not legacy)
	var arr := PackedVector3Array(pal)
	arr.resize(72)
	_palette_mat.set_shader_parameter("pal", arr)
	_palette_mat.set_shader_parameter("pal_n", mini(72, pal.size()))


# ------------------------------------------------------------------ the weather

func _wx_setup() -> void:
	_wx_sky = &""
	if _neb_mat == null:
		return
	var k := int(_sky_look.neb)
	if k >= 0 and k < SkyWeatherS.NEB_SKIES.size():
		_wx_sky = SkyWeatherS.NEB_SKIES[k]
	_wx_rng.seed = hash([node.index, Time.get_ticks_usec(), 11])
	_wx_clock = 0.0
	var cad: Vector2 = SkyWeatherS.CADENCE.get(_wx_sky, Vector2(15, 40)) * WX_SLOW
	_wx_next_a = _wx_rng.randf_range(cad.x * 0.5, cad.y * 0.6)
	_wx_next_b = _wx_rng.randf_range(30.0, 70.0)
	# a harness's `localwx=<name>`: that event, a second in (`LocalShot`)
	for arg in OS.get_cmdline_user_args():
		if (arg as String).begins_with("localwx="):
			_wx_force = StringName((arg as String).substr(8))
			_wx_next_a = 1.0
			_wx_next_b = 1.0


func _wx_step(dt: float) -> void:
	if _neb_mat == null or _wx_sky == &"":
		return
	if DisplaySettings.reduced_motion or not _ready_sky:
		if not _wa.is_empty() or not _wb.is_empty():
			_neb_mat.set_shader_parameter("w_k", 0.0)
			_neb_mat.set_shader_parameter("s_k", 0.0)
			_wa = {}
			_wb = {}
		return
	_wx_clock += dt
	var cad: Vector2 = SkyWeatherS.CADENCE.get(_wx_sky, Vector2(15, 40)) * WX_SLOW
	if _wa.is_empty() and _wx_clock >= _wx_next_a and WX_M.has(_wx_sky):
		var opts: Array = WX_M[_wx_sky]
		var pick: Array = opts[_wx_rng.randi() % opts.size()]
		if _wx_force != &"":
			pick = []
			for o: Array in opts:
				if o[0] == _wx_force:
					pick = o
		var ev := {} if pick.is_empty() else _wx_event(pick[0], int(pick[1]), float(pick[2]), float(pick[3]))
		if not ev.is_empty() and _wx_place(ev):
			_wa = ev
			_wx_send(ev, 0)
		_wx_next_a = _wx_clock + _wx_rng.randf_range(cad.x, cad.y)
	if _wb.is_empty() and _wx_clock >= _wx_next_b and WX_S.has(_wx_sky) and (_wx_force == &"" or WX_S[_wx_sky][0] == _wx_force):
		var sp: Array = WX_S[_wx_sky]
		var ev := _wx_event(sp[0], int(sp[1]), float(sp[2]), 0.0)
		if _wx_place(ev):
			_wb = ev
			_wx_send(ev, 1)
		_wx_next_b = _wx_clock + _wx_rng.randf_range(40.0, 100.0)
	for slot in 2:
		var ev: Dictionary = _wa if slot == 0 else _wb
		if ev.is_empty():
			continue
		ev.age = float(ev.age) + dt
		if float(ev.age) > float(ev.end):
			_neb_mat.set_shader_parameter("w_k" if slot == 0 else "s_k", 0.0)
			if slot == 0:
				_wa = {}
			else:
				_wb = {}
			continue
		_neb_mat.set_shader_parameter("w_age" if slot == 0 else "s_age", pose(float(ev.age)))


func _wx_event(nm: StringName, ev_i: int, lasts: float, pre: float) -> Dictionary:
	return {"name": nm, "ev": ev_i, "age": -pre, "pre": pre, "end": lasts, "at": Vector2.INF,
		"dir": Vector2.RIGHT, "seed": _wx_rng.randf(), "k": 1.0, "size": 115.0}


## Where an event goes, in the cloud's own pixels: always above the fight.
func _wx_place(ev: Dictionary) -> bool:
	var off := neb_off()
	var top := Rect2(Vector2(60.0, 50.0), Vector2(840.0, PLAY.x - 70.0))
	match StringName(ev.name):
		&"tide", &"glints":
			ev.at = CC if not legacy else _nspot(1.0, Vector2(-160, -120), Vector2(1120, 660))
			return top.grow(80.0).has_point(Vector2(ev.at) + off)
		&"jet":
			var tips := SkyBakeS.em_pillars(_sd, CC)
			tips.shuffle()
			for p: Array in tips:
				var sp: Vector2 = p[1]
				if top.has_point(sp + off):
					ev.at = (sp / 2.0).floor() * 2.0 + Vector2.ONE
					var rad := (Vector2(ev.at) - CC).normalized()
					ev.dir = Vector2(-rad.y, rad.x) * (1.0 if _wx_rng.randf() < 0.5 else -1.0)
					return true
			return false
		&"breathe", &"spoke":
			for k in [0, 1, 2]:
				var sp := _nspot(float(k) + 2.0, Vector2(60, 50), Vector2(900, 490))
				if top.grow(20.0).has_point(sp + off):
					ev.at = sp
					return true
			return false
		&"ringrun", &"halo", &"lamps":
			var th := _pn_theta0(Vector2(480.0, 70.0) - off)
			ev.dir = Vector2(cos(th), sin(th))
			return true
		&"rays":
			return true
		&"dawn":
			ev.at = Vector2(480.0, 70.0) - off
			return true
		_:
			# shaft, shock, glitter: a spot above the fight
			var p := Vector2(_wx_rng.randf_range(top.position.x, top.end.x), _wx_rng.randf_range(top.position.y, top.end.y))
			ev.at = ((p - off) / 2.0).floor() * 2.0 + Vector2.ONE
			return true


func _wx_send(ev: Dictionary, slot: int) -> void:
	var m := _neb_mat
	if slot == 0:
		m.set_shader_parameter("w_ev", int(ev.ev))
		m.set_shader_parameter("w_at", ev.at)
		m.set_shader_parameter("w_k", float(ev.k))
		m.set_shader_parameter("w_dir", ev.dir)
		m.set_shader_parameter("w_seed", float(ev.seed))
		m.set_shader_parameter("w_size", float(ev.size))
		m.set_shader_parameter("w_pre", float(ev.pre))
		m.set_shader_parameter("w_up", true)
		var pts := PackedVector4Array()
		pts.resize(6)
		m.set_shader_parameter("w_pts", pts)
		m.set_shader_parameter("w_n", 0)
		m.set_shader_parameter("w_age", float(ev.age))
	else:
		m.set_shader_parameter("s_ev", int(ev.ev))
		m.set_shader_parameter("s_at", ev.at)
		m.set_shader_parameter("s_k", float(ev.k))
		m.set_shader_parameter("s_dir", ev.dir)
		m.set_shader_parameter("s_seed", float(ev.seed))
		m.set_shader_parameter("s_age", float(ev.age))
	# the guard round the ship: nothing of the weather's lands near it anyway
	m.set_shader_parameter("g_ship", Vector4(-9999.0, -9999.0, 30.0, 90.0))


## `SkyWeather`'s spot in the cloud (its `nspot`), for this cloud's seed.
func _nspot(k: float, lo: Vector2, hi: Vector2) -> Vector2:
	return lo + Vector2(SkyBakeS.hash2(floori(k * 13.0 + _sd * 17.0), 5), SkyBakeS.hash2(floori(k * 17.0 + _sd * 13.0), 9)) * (hi - lo)


## a planetary shell's rim direction nearest sky point vc (`SkyWeather.pn_theta0`)
func _pn_theta0(vc: Vector2) -> float:
	var cc := _nspot(1.0, Vector2(-80, -60), Vector2(1040, 600))
	var aa := SkyBakeS.hash2(floori(_sd), 77) * PI
	var d := vc - cc
	var dd := Vector2(d.x * cos(aa) - d.y * sin(aa), d.x * sin(aa) + d.y * cos(aa))
	if int(_sky_look.get("shape", 0)) == 1 or int(_sky_look.get("shape", 0)) == 2:
		dd.y *= 1.5
	return atan2(dd.y, dd.x)


# ------------------------------------------------------------------ harness

## The sky's own picture, one pixel a block (`LocalShot`).
func picture() -> Image:
	if _scene == null:
		return null
	return _scene.get_texture().get_image()


## The sky's own GPU time last frame, ms (`LocalShot`): measured once asked.
func gpu_ms() -> float:
	if _scene == null:
		return 0.0
	var rid := _scene.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	return RenderingServer.viewport_get_measured_render_time_gpu(rid)
