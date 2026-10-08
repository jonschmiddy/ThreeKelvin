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
## WHERE THE SHIP IS (Jon: "have LOCAL change depending on what you are orbiting
## and how far from the star you are"), read from the sector map's own record of
## it (`SystemMapScreen._parked`: what it is in orbit of, where it is on the
## plane), or, with none, at the edge where a ship warps in:
##   * ORBITING A WORLD: that world close and huge, rising from below behind the
##     fight, its rings across it and its moons above, lit from the star; the
##     star smaller beyond, at the world's own distance;
##   * ORBITING THE STAR: the star large and blazing, cut by the top of the
##     view, the worlds small along the band;
##   * HOW FAR OUT: the star's size, and how far its light reaches into the gas,
##     go with its nearness -- big and blazing close in, a small bright point at
##     the edge -- and so do the hole's and the pulsar's;
##   * ALONGSIDE A BELT OR A WRECK: its rocks, or the hulk and its shards, close by.
## The near things are drawn in a picture of their own (`local_near`), in front
## of the band: solid bodies, their light pressed as the gas's is, their dark
## never lifted.
##
## THE CAMERA moves when the ship does: it follows the hull's approach and its
## departure a little over half way (`CAM_FOLLOW`), and every layer slides by its
## own depth -- the far stars and galaxies least, the system's star all but
## still, then the cloud, the band's worlds, and the world it orbits most -- in
## whole 2x2 blocks. Otherwise it holds still: the motion is the gas, the
## star and the weather.
##
## READABILITY FIRST. The fight is played across the middle of the view, so the
## sky there is made a soft backdrop -- its range pressed in toward a mid-tone,
## its light and colour kept (`local_grade.gdshader`, PLAY), whatever the
## system -- and nothing is drawn behind the ships or their words (shadows
## round them were tried: Jon, "they're odd", "the text doesn't need a
## shadow"); the bright things -- the star, the hole, the lit heart of the
## cloud -- sit in the band above it.
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
## HOW FAR OUT THE SHIP IS: at REF_K of the way to the system's edge the star is
## drawn at SUN_K; nearer bigger, further smaller, as (that distance over the
## ship's)^SIZE_POW, held between these
const REF_K := 0.45
const SIZE_POW := 0.85
const SIZE_LO := 0.4
const SIZE_HI := 4.0
## THE WORLD IT ORBITS: its radius on screen (a giant's, a planet's), and how far
## it slides for a pixel of the camera's travel (it is near)
const NEAR_GIANT_R := 175.0
const NEAR_WORLD_R := 125.0
const F_NEAR := 0.3
const NEAR := preload("res://shaders/local_near.gdshader")
const HAND := preload("res://shaders/ladder_world.gdshader")
## THE CAMERA: how much of the ship's travel it follows, and how far each layer
## slides for a pixel of the camera's (the far sky's own depths are in
## `chart_bg`: stars 0.04, 0.10, 0.20, galaxies 0.05)
const CAM_FOLLOW := 0.6
const F_CLOUD := 0.05
const F_BAND := 0.12
## THE LAYERS BY DISTANCE (Jon: "the sun moves a ton in the parallax ...
## shouldn't it be more still since it's so distant?"): the far sky least -- its
## galaxies and three depths of stars at SKY_K of `chart_bg`'s own depths, all
## under 0.012 of the camera's travel -- then the system's star (the black hole,
## the pulsar) all but still, then the cloud, the band's worlds, and the world
## the ship orbits most of all. Each in whole 2x2 blocks; the camera eases in
## and out, so a step never goes back.
const SKY_K := 0.06
const F_STAR := 0.015
## THE PLAY: the game frame below its top band is where the fight is played,
## and the sky there is a soft backdrop (`local_grade`): its range pressed in
## from PLAY.x down, wholly by PLAY.y (game px), its light kept
const PLAY := Vector2(70.0, 140.0)
## PAINTED's paint toned again behind the play: the light above the mid-tone
## kept to this much of its distance (the sky's own tone keeps 0.55)
const PAINTED_KEEP := 0.4
## and RADIANT's lit volume, toned once
const RADIANT_KEEP := 0.38
## RADIANT's wash of the gas over a world close by (planet.gdshader's r_haze:
## all over, more at the limb, the gas's brightness); the band's worlds keep the
## shader's 0.22 / 0.45
const NEAR_HAZE := Vector3(0.0, 0.1, 16.0)
## the cloud's sky pixel at the star: high in its bake, so the view below the
## star stays inside the baked field
const CC := Vector2(480.0, 150.0)
## how many more colours LOCAL's cut of a cloud keeps than the map's: seen side on,
## the lit rims of the masses facing the star and the glow's long fall into the
## gas are much of the picture, and with the map's count they shared too few
## steps (Jon: the masses "more backlit" on one arrival than another)
const PAL_MORE := 6
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
## the camera's real travel this frame (`cam` is held at rest for the frames the
## palette is found from); what the foreground dust follows
var cam_follow := Vector2.ZERO
var _cam_rest := false
var _t_saved := 0.0

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
## where the ship is: what it orbits (a body, -1 the star, -9 nothing), its
## distance from the star (plane px) and that as the star's size factor
var orbit_target := -9
var orbit_d := 0.0
var _dk := 1.0
## the near things: their own picture, the world the ship orbits and its moons,
## a belt's rocks, a wreck (each [node, screen position before parallax,
## parallax, radius])
var _near_vp: SubViewport = null
var _near_mat: ShaderMaterial = null
var _near: Array = []
## the picture the near layer is drawn onto (for the cutaway's zoom)
var _near_rect: ColorRect = null
## the world you orbit, as drawn (`near_info`); a great storm an event holds on
## its face (`_hold_storm`); how far the gas has closed in (`set_closed`)
var _near_world: Node2D = null
var near_storm: Dictionary = {}
var closed := 0.0

## THE CUTAWAY'S ZOOM (`CutawayView`, Jon: "LOCAL should zoom the real scene
## too"): the camera pushed in `zoom` times on the point `_zoom_fixed` (this
## view's px), which it carries to `_zoom_to`. Each layer goes by its depth --
## the world you orbit all the way with the ship, the band's worlds a little,
## the star all but still; the far stars and the cloud are drawn on the screen's
## own grid and hold. 1 is no zoom, which is all play outside the cutaway sees.
var zoom := 1.0
var _zoom_fixed := Vector2.ZERO
var _zoom_to := Vector2.ZERO
var _glow_r := 70.0
const Z_STAR := 0.04
const Z_BAND := 0.15
const Z_NEAR := 1.0


func set_zoom(z: float, fixed: Vector2, to: Vector2) -> void:
	zoom = z
	_zoom_fixed = fixed
	_zoom_to = to


## A layer at depth `f` under the zoom: its scale, and where a point `p` of it
## lands (on the sky's 2 px grid).
func _zl(f: float) -> float:
	return 1.0 + (zoom - 1.0) * f


func _zp(p: Vector2, f: float) -> Vector2:
	return _block_round(_zoom_fixed + (_zoom_to - _zoom_fixed) * f + (p - _zoom_fixed) * _zl(f))


## A whole layer (a Node2D or a Control at the origin) put under the zoom.
func _zlayer(n: CanvasItem, f: float) -> void:
	if n == null or not is_instance_valid(n):
		return
	var at := _zp(Vector2.ZERO, f)
	var sc := Vector2.ONE * _zl(f)
	if n is Node2D:
		(n as Node2D).position = at
		(n as Node2D).scale = sc
	elif n is Control:
		(n as Control).position = at
		(n as Control).scale = sc
var _low_dt := 0.0
## the cloud's bake, kept for the next visit: key -> [field0, field1, field2]
static var _baked := {}
## Each system's cut palette this session, by `_key` (system, style, LOW), so a
## new screen over a system already seen shows its finished sky at once.
static var _pal_cache := {}
const PAL_CACHE_MAX := 64
## The most forced draws `_prime` spends finishing a sky (the cut waits for 8,
## the bake for a handful more): a ceiling, not a cost.
const PRIME_MAX := 48
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
	_situate()
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
	_glow_r = 70.0 * (1.5 if layout.star == SystemLayout.StarKind.RED else 1.0)
	_far_mat.set_shader_parameter("glow_r", _glow_r)
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
		star.call("set_zoom", star_k())
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
	# (PAINTED's ramps pick a step by brightness, so a smooth ease through them
	# is one hard line across the sky: stepped there, dithered)
	_grade_mat.set_shader_parameter("stepped", painted)
	if radiant:
		# (RADIANT's lit volume fills the play evenly, near as bright as the
		# band above: its light pressed in harder)
		_grade_mat.set_shader_parameter("keep_hi", RADIANT_KEEP)
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
		# (and its paint toned again after: B's curated ramps pick a step by
		# where a block falls on them, so its puffed masses come out as vivid as
		# ever whatever went in -- the same play tone, pressed harder, eased in
		# smoothly, as nothing cuts it after)
		var pcopy := BackBufferCopy.new()
		pcopy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
		_scene.add_child(pcopy)
		_scene.move_child(pcopy, 2)
		var pgrade := _rect()
		var pgm := ShaderMaterial.new()
		pgm.shader = GRADE
		pgm.set_shader_parameter("ramp", PLAY)
		pgm.set_shader_parameter("keep_hi", PAINTED_KEEP)
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
		star.set("hole_k", star_k())
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
		if radiant:
			_set_deep(star, "radiant", true)
	for i in layout.bodies.size():
		var b := layout.bodies[i]
		if b.world == &"" or i == orbit_target:
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
	_build_near()
	_apply_closed()
	_wx_setup()
	_place_box()
	_step(0.0)
	# THE FIRST FRAME ANYBODY SEES IS THE FINISHED ONE (Jon, of the arrival:
	# frames 0-2 smooth and unpaletted, then the cut; then of a hold that
	# showed the dark wash first, "the black starfield AND THEN the nebula loads
	# in looks bad"; and every later rebuild -- a new screen over the same
	# system, a style or LOW change -- blinked the same way). So the sky is
	# finished before it is shown: held clear while `_prime` drives the cloud's
	# bake and the palette's cut through forced, unpresented draws, in this
	# same frame, then shown. The palette is kept per system and style
	# (`_pal_cache`), so a system already seen this session is cut once.
	_box.modulate.a = 0.0 if _palette_mat != null else 1.0
	var cached: Array = _pal_cache.get(_key, [])
	if _palette_mat != null and not cached.is_empty():
		_palette_mat.set_shader_parameter("pal", cached[0])
		_palette_mat.set_shader_parameter("pal_n", cached[1])
		_palette_built = true
		_box.modulate.a = 1.0
	if neb_on:
		_bake_cloud(_gen)
	else:
		_ready_sky = true
	_prime()


## Finish the sky before it is first shown: forced draws (never presented)
## until the cloud is baked and the palette cut, the coroutines that await a
## drawn frame (`SkyBake.field`, `_build_palette`) running on each. A hitch of
## a few renders on a system's first arrival -- behind the jump's flare -- and
## none on a revisit, when both are cached. Not headless (nothing renders).
func _prime() -> void:
	if headless() or _scene == null:
		_box.modulate.a = 1.0
		return
	# (set up before it is in the tree: finished on the way in, still unseen)
	if not is_inside_tree():
		if not tree_entered.is_connected(_prime):
			tree_entered.connect(_prime, CONNECT_ONE_SHOT)
		return
	var gen := _gen
	var t0 := Time.get_ticks_usec()
	var draws := 0
	_set_update(SubViewport.UPDATE_ALWAYS)
	for i in PRIME_MAX:
		if _ready_sky and (_palette_mat == null or _box.modulate.a > 0.0):
			break
		_step(0.0)
		RenderingServer.force_draw(false, 0.0)
		draws += 1
		if gen != _gen or not is_inside_tree():
			return
	# (whatever happened, never leave the sky clear)
	_box.modulate.a = 1.0
	print_verbose("LocalSky primed %s in %d draws, %.0f ms" % [_key, draws, (Time.get_ticks_usec() - t0) / 1000.0])


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
	var f := clampf(pow(_dk, SIZE_POW), SIZE_LO, SIZE_HI)
	if layout.star == SystemLayout.StarKind.PULSAR:
		return PULSAR_K * f
	if layout.star == SystemLayout.StarKind.CORE:
		return HOLE_K * f
	return float(SUN_K.get(kind, 0.6)) * f


func star_light() -> Vector3:
	var c: Vector3 = SkyBakeS.STARCOL.get(kind, SkyBakeS.STARCOL.ORDINARY)
	var l := Vector3(pow(c.x, 2.2), pow(c.y, 2.2), pow(c.z, 2.2))
	return l / maxf(l.x, maxf(l.y, l.z))


## THE STAR ON SCREEN this frame, on the block grid (its own, near-still layer),
## and under the cutaway's zoom where its depth (Z_STAR) carries it. Everything
## that belongs to the star asks this one point: its disc, the far sky's glow,
## its light on the cloud (and PAINTED's), the worlds' shafts and shadows, the
## near world's light, the dust (`LocalDust`) and the subjects (`LocalSubject`).
## Jon: "When zooming into the ship, the light of the star moves?" -- the disc
## sat inside the band's layer and took its zoom on top of its own, while the
## glow held still, so the two came apart.
func origin() -> Vector2:
	return _zp(rest_origin(), Z_STAR)


## The star with no zoom: what the layout and the palette are laid out from.
func rest_origin() -> Vector2:
	return _block_round(_sun - cam * F_STAR)


## the band's centre this frame: where the worlds' orbits are laid out from
func band_origin() -> Vector2:
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
	if _near_vp != null:
		_near_vp.render_target_update_mode = m
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
	# (the palette's own frames: the sky at its clock's start, see `_build_palette`)
	if _cam_rest:
		_t_saved += delta if not still else 0.0
		t = 0.0
	# THE CAMERA follows the ship's own travel: its approach and departure
	var cx := 0.0
	if cam_ship != null and is_instance_valid(cam_ship) and cam_ship.is_inside_tree():
		cx = cam_ship.position.x * CAM_FOLLOW
	cam = Vector2(roundf(cx), 0.0)
	cam_follow = cam
	# (while the palette is being found the sky is laid out at rest, behind a
	# still of itself: see `_build_palette`)
	if _cam_rest:
		cam = Vector2.ZERO
	var o := rest_origin()
	var so := origin()
	var vr := get_global_rect()
	_far_mat.set_shader_parameter("wash", Vector2(vr.position.x, vr.size.x))
	# (`chart_bg` slides a layer with its pan: the sky's pan is the world's
	# travel on screen, against the camera's)
	_far_mat.set_shader_parameter("u_skyPan", -cam * SKY_K)
	_far_mat.set_shader_parameter("star_at", so)
	_far_mat.set_shader_parameter("glow_r", _glow_r * _zl(Z_STAR))
	_far_mat.set_shader_parameter("breath", SystemViewS.breath(pose(t, 4.0)))
	if _neb_mat != null:
		_neb_mat.set_shader_parameter("off", neb_off())
		_neb_mat.set_shader_parameter("time", 0.0 if still else pose(t, 4.0))
		_neb_mat.set_shader_parameter("low", gfx_low())
		if not legacy:
			_neb_mat.set_shader_parameter("star_at", Vector2(so))
			# (the star's light reaches as far into the gas as it is near: the map's
			# zoom, which opens the light out, stands in for nearness)
			var lz := clampf(pow(_dk, 0.8), 0.45, 2.4)
			_neb_mat.set_shader_parameter("zoom", lz)
			_neb_mat.set_shader_parameter("lzoom", lz)
			_neb_mat.set_shader_parameter("home_zoom", 1.0)
			_neb_mat.set_shader_parameter("lscale", 1.35)
			_neb_mat.set_shader_parameter("breath", SystemViewS.breath(pose(t, 4.0)))
			_neb_mat.set_shader_parameter("hole_r", 116.0 * star_k() * _zl(Z_STAR))
	if painted:
		SectorPaintedS.push(self)
	_step_star(o)
	_step_worlds(o)
	_step_near(o)
	_zlayer(_worlds, Z_BAND)
	# (the map's own world, handed over, is placed and sized live in its own
	# pixels, not scaled as a picture: `adopt_near`)
	if _hand.is_empty() or bool(_hand.get("self", false)):
		_zlayer(_near_rect, Z_NEAR)
	elif _near_rect != null:
		_near_rect.position = Vector2.ZERO
		_near_rect.scale = Vector2.ONE
	_wx_step(delta)
	if _ready_sky and not _palette_built and _frame > 8 and _palette_mat != null:
		_build_palette()


func _step_star(o: Vector2) -> void:
	if star == null:
		return
	# AT ITS OWN DEPTH, wherever it hangs: the pulsar on the far sky, which does
	# not zoom; the sun and the core inside the band's layer (for the worlds that
	# pass in front of it), which zooms at Z_BAND, so the band's zoom is taken
	# back out of it
	var at := _zp(o, Z_STAR)
	var k := _zl(Z_STAR)
	if star.get_parent() == _worlds:
		var wk := _zl(Z_BAND)
		at = (at - _zp(Vector2.ZERO, Z_BAND)) / wk
		k /= wk
	star.position = at
	star.scale = Vector2.ONE * k
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
		var at := _block_round(band_origin() + Vector2(p.x, p.y * TILT) * _s)
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
		# (the star's disc as this layer sees it: where `_step_star` put it, at
		# its own depth, in the band's coordinates)
		var sr := float(layout.star_r) * star_k() * (star.scale.x if star != null else 1.0)
		var so: Vector2 = star.position if star != null else o
		v.call("step", t, light, kl, so if behind else Vector2(-9999, -9999), sr if behind else 0.0)
		var vm: ShaderMaterial = v.get("_mat")
		if vm != null:
			if not legacy:
				vm.set_shader_parameter("star_tint", _tint)
				vm.set_shader_parameter("night_fill", Vector3(0.02, 0.02, 0.03))
			vm.set_shader_parameter("flare", _flare)
			vm.set_shader_parameter("lift", 0.0 if legacy else 1.0)
		# (the shafts are cast on the cloud, which does not zoom: each world where
		# the band's zoom shows it, at the size it is drawn)
		if bp.size() < 24:
			var wp := _zp(v.position, Z_BAND)
			var wr := _world_r(b) * _zl(Z_BAND)
			bp.append(Vector4(wp.x, wp.y, wr, wr))
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
##
## FOUND FROM THE SKY AT REST (Jon, of an arrival: "the nebula on the left are more
## backlit by the sun than the ones on the right" -- one arrival's sky set flatter
## than another's): a palette cut from a frame early in the approach, with the
## camera still out where the ship flies in from, was a palette of that frame --
## other gas, the star elsewhere on it -- and the lit rims and the glow's reach
## at rest fell between its colours (and a palette cut a second later was cut
## from other gas). So for the two frames it takes, the sky is laid out at rest
## and at its clock's start, behind a still of what was on screen, and the
## palette is cut from that: the same palette however and whenever the ship
## arrives.
func _build_palette() -> void:
	_palette_built = true
	var freeze: TextureRect = null
	if _box != null:
		# (a still over the sky while it is laid out at rest -- only when the sky
		# is already showing; held clear, there is nothing to cover, and the still
		# would be the unpaletted picture)
		if _box.modulate.a > 0.0:
			freeze = TextureRect.new()
			freeze.texture = ImageTexture.create_from_image(_scene.get_texture().get_image())
			freeze.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			freeze.mouse_filter = Control.MOUSE_FILTER_IGNORE
			freeze.position = _box.position
			freeze.scale = Vector2(2, 2)
			add_child(freeze)
		_t_saved = t
		_cam_rest = true
		_step(0.0)
		await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	if _cam_rest:
		t = _t_saved
	_cam_rest = false
	if freeze != null:
		freeze.queue_free()
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
	var pal: PackedVector3Array = SystemPaletteS.build(img, 0, Vector2(rest_origin()) / 2.0, float(layout.star_r) * star_k() / 2.0, kind, 0,
		SystemPaletteS.K_NEBULA + PAL_MORE if cloud else SystemPaletteS.K, extra, legacy or not cloud,
		not legacy and cloud and int(_sky_look.neb) <= NebulaField.Kind.REFLECTION, SystemPaletteS.MERGE, not legacy)
	var arr := PackedVector3Array(pal)
	arr.resize(72)
	_palette_mat.set_shader_parameter("pal", arr)
	_palette_mat.set_shader_parameter("pal_n", mini(72, pal.size()))
	_pal_cache[_key] = [arr, mini(72, pal.size())]
	if _pal_cache.size() > PAL_CACHE_MAX:
		_pal_cache.erase(_pal_cache.keys()[0])
	# (and now it may be seen: the scene renders before the screen does, so the
	# frame that shows it is already cut)
	if _box != null:
		_box.modulate.a = 1.0
	# (a harness's `palprint`: the palette found, to compare two arrivals)
	if "palprint" in OS.get_cmdline_user_args():
		var hx: Array = []
		for c: Vector3 in pal:
			hx.append(Color(c.x, c.y, c.z).to_html(false))
		hx.sort()
		print("  localsky palette (%d, cam %s): %s" % [pal.size(), cam_follow, ",".join(hx)])


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


# ------------------------------------------------------------------ where the ship is

## What the ship orbits and how far out it is, from the sector map's record of
## it (`SystemMapScreen._parked`), or at the warp-in edge.
func _situate() -> void:
	var d: Dictionary = SystemMapScreen._parked.get(node.index, {})
	orbit_target = -9
	var p := Vector2(layout.edge, -210.0)
	if not d.is_empty():
		orbit_target = int(d.get("at", -9))
		if orbit_target >= 0 and orbit_target < layout.bodies.size():
			p = layout.bodies[orbit_target].pos(0.0)
			if p.length() < 1.0:
				p = Vector2(layout.bodies[orbit_target].orbit, 0.0)
		elif orbit_target == -1:
			p = Vector2(float(layout.star_r) + 71.0, 0.0)
		elif StringName(d.get("mode", &"")) == &"free":
			p = d.get("p", p)
	if orbit_target < -1 or orbit_target >= layout.bodies.size():
		orbit_target = -9
	orbit_d = maxf(p.length(), float(layout.star_r) + 20.0)
	_dk = REF_K * (layout.edge + 20.0) / orbit_d
	# A BIG STAR rides up into the top of the view, cut by it, blazing
	if layout.star != SystemLayout.StarKind.PULSAR:
		var R := float(layout.star_r) * star_k() * (0.3 if layout.star == SystemLayout.StarKind.CORE else 1.0)
		_sun.y = HORIZON - roundf(clampf(R - 20.0, 0.0, 36.0) / 2.0) * 2.0


## The near things' own picture and what is in it.
func _build_near() -> void:
	_near.clear()
	_near_vp = null
	_near_world = null
	near_storm = {}
	if orbit_target < 0:
		return
	var tgt: SystemLayout.Body = layout.bodies[orbit_target]
	_near_vp = SubViewport.new()
	_near_vp.size = Vector2i(480, 270)
	_near_vp.size_2d_override = Vector2i(960, 540)
	_near_vp.size_2d_override_stretch = true
	_near_vp.transparent_bg = true
	_near_vp.disable_3d = true
	_near_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_near_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_scene.add_child(_near_vp)
	var h := SkyBakeS.hash2(node.index, 811 + orbit_target)
	# opposite the star, across the view from it
	var side := 1.0 if _sun.x < 480.0 else -1.0
	# AN EVENT ON THIS WORLD (`site`, `OptionTable`: the giant fills the sky):
	# drawn on the event's side, right of your ship, where its subject stands --
	# and with what the event's text gives it (`near`: rings, a great storm)
	var wants := _near_wants()
	if not wants.is_empty():
		side = 1.0
	near_storm = wants.get("storm", {})
	if tgt.world != &"":
		var giant := tgt.kind == &"giant"
		var R := roundf((NEAR_GIANT_R if giant else NEAR_WORLD_R) * clampf(tgt.r / (22.0 if giant else 12.0), 0.8, 1.25) / 2.0) * 2.0
		var at := _block_round(Vector2(480.0 + side * (190.0 + 60.0 * h), 339.0 + 0.2 * R))
		var over := {}
		if bool(wants.get("ring", false)):
			over.ring = true
		var spec := Worlds.spec(tgt.world, tgt.seed, R)
		spec.merge(over, true)
		var v: Node2D = Worlds.view_for(tgt.world)
		v.call("set_world", tgt.world, tgt.seed, R, over)
		_near_world = v
		v.call("set_cell", 2)
		_near_vp.add_child(v)
		_dress(v)
		_near.append([v, at, F_NEAR, R])
		# ITS MOONS, small above it
		var nm := mini(int(spec.get("moons", 0)), 3)
		for k in nm:
			var hk := SkyBakeS.hash2(tgt.seed, 41 + k)
			var a := -PI * (0.2 + 0.6 * (float(k) + hk) / float(maxi(nm, 1)))
			var mr := roundf((5.0 + 6.0 * SkyBakeS.hash2(tgt.seed, 61 + k)) / 2.0) * 2.0
			var mp := _block_round(at + Vector2(cos(a) * R * (1.3 + 0.3 * hk), sin(a) * R * (1.15 + 0.25 * hk)))
			var mv := PlanetView.new()
			mv.set_world(&"moon", tgt.seed + 17 * (k + 1), mr)
			mv.set_cell(2)
			_near_vp.add_child(mv)
			_dress(mv)
			_near.append([mv, mp, F_NEAR * 1.1, mr])
	elif tgt.kind == &"belt":
		# A BELT'S ROCKS, close by: a drifting band of them behind the fight, the
		# nearer bigger
		for k in 16:
			var hx := SkyBakeS.hash2(node.index * 7 + k, 901)
			var hy := SkyBakeS.hash2(node.index * 7 + k, 902)
			var hz := SkyBakeS.hash2(node.index * 7 + k, 903)
			var rr := roundf((4.0 + 18.0 * hz * hz) / 2.0) * 2.0
			var rp := _block_round(Vector2(40.0 + 880.0 * hx, 150.0 + 0.12 * (880.0 * hx - 440.0) * side + 150.0 * (hy - 0.5)))
			var rv := PlanetView.new()
			rv.set_world(&"rock" if hz < 0.6 else &"iron", node.index * 13 + k, rr)
			rv.set_cell(2)
			_near_vp.add_child(rv)
			_dress(rv)
			_near.append([rv, rp, 0.25 + 0.3 * hz, rr])
	elif tgt.kind == &"derelict":
		# A WRECK: the hulk close by, broken, its shards round it
		var w := _Wreck.new()
		w.seed = node.index * 31 + orbit_target
		w.light_from = Vector2(-side, -0.6)
		_near_vp.add_child(w)
		# (high, over the fight's band, toward the side away from the star: the
		# shots fly through the middle at the ships' height)
		_near.append([w, _block_round(Vector2(480.0 + side * 150.0, 118.0)), F_NEAR, 0.0])
	if _near.is_empty():
		_near_vp.queue_free()
		_near_vp = null
		return
	var rect := _rect()
	_near_rect = rect
	_near_mat = ShaderMaterial.new()
	_near_mat.shader = NEAR
	_near_mat.set_shader_parameter("tex", _near_vp.get_texture())
	_near_mat.set_shader_parameter("ramp", PLAY)
	# (solid: its light pressed as the gas's is, in the style's own measure,
	# its dark never lifted)
	_near_mat.set_shader_parameter("keep_lo", 1.0)
	if radiant:
		_near_mat.set_shader_parameter("keep_hi", RADIANT_KEEP)
	rect.material = _near_mat
	_scene.add_child(rect)


## WHAT AN EVENT ON THE WORLD YOU ORBIT ASKS OF IT: only an event sited there by
## its text (`site`, `OptionTable`: "the giant fills the sky"), open here or
## about to open (`LocalEventDrawer.open_here`) -- its `near` (rings, a storm),
## and the world drawn on its side. {} for anything else: every other world is
## drawn as it always was.
func _near_wants() -> Dictionary:
	if node == null or orbit_target < 0:
		return {}
	var i := LocalEventDrawer.open_here(node)
	if i < 0 or i >= node.options.size():
		return {}
	var o := OptionTable.by_id(node.options[i])
	if StringName(o.get("site", &"")) != &"giant" or layout.place_of(i) != orbit_target:
		return {}
	var w: Dictionary = (o.get("near", {}) as Dictionary).duplicate()
	w.right = true
	return w


## THE WORLD YOU ORBIT, where it is drawn now: {at (global px), r (px), ring_in,
## ring_out (in its radii; 0 with no rings), open (the rings' squash), view}, or
## {} when there is none (`LocalSubject` stands things on it and in its rings).
func near_info() -> Dictionary:
	if _near_world == null or not is_instance_valid(_near_world) or _near.is_empty() or _box == null:
		return {}
	var e: Array = _near[0]
	var p: Vector2 = _block_round(Vector2(e[1]) - cam * float(e[2]))
	var at := _box.get_global_transform() * (_zp(p, Z_NEAR) * 0.5)
	var r := float(e[3]) * _zl(Z_NEAR) * _box.get_global_transform().get_scale().x * 0.5
	var d := {at = at, r = r, ring_in = 0.0, ring_out = 0.0, open = 0.28, view = _near_world}
	var spec: Dictionary = _near_world.get("spec")
	if spec != null and bool(spec.get("ring", false)):
		var mat := _near_world.get("_mat") as ShaderMaterial
		if mat != null:
			d.ring_in = float(mat.get_shader_parameter("ring_in"))
			d.ring_out = float(mat.get_shader_parameter("ring_out"))
		if d.ring_out <= 0.0:
			d.ring_in = 1.5
			d.ring_out = 2.2
	return d


## The star's centre on screen now, global px (its disc as drawn, zoom and all).
func star_global() -> Vector2:
	if _box == null:
		return get_global_transform() * origin()
	return _box.get_global_transform() * (origin() * 0.5)


## A point of the sky's own 960x540 frame on screen now, global px.
func scene_to_global(p: Vector2) -> Vector2:
	if _box == null:
		return get_global_transform() * p
	return _box.get_global_transform() * (p * 0.5)


## The star's drawn radius on screen now, px.
func star_px() -> float:
	if layout == null:
		return 0.0
	return float(layout.star_r) * star_k() * _zl(Z_STAR)


## THE GAS CLOSED IN (`no_stars`: "The gas has closed in. ... No stars"): the
## far stars and galaxies faded out and the cloud thickened, by `k` (0 as it
## always is). Kept, so a sky built after it is asked is built closed in.
func set_closed(k: float) -> void:
	closed = clampf(k, 0.0, 1.0)
	_apply_closed()


func _apply_closed() -> void:
	if _far_mat != null:
		_far_mat.set_shader_parameter("stars_seen", 1.0 - closed)
	if _neb_mat != null:
		_neb_mat.set_shader_parameter("strength", 1.0 + 0.9 * closed)


## A GREAT STORM HELD ON THE FACE OF THE WORLD YOU ORBIT (`near_storm`: `sv`, the
## point of its face it stands on -- x, y in its radii from its centre, y down --
## and its size, `z` across and `w` tall in radians): the planet painter's own
## first great storm, put back there every frame against the world's turn and its
## winds, so it stays where the event's ship is while the bands stream past it.
func _hold_storm(pv: Node2D, t_now: float) -> void:
	var spec: Dictionary = pv.get("spec")
	var mat := pv.get("_mat") as ShaderMaterial
	if spec == null or mat == null or not (spec.get("storms", []) as Array).size() >= 2:
		return
	var sv2: Vector2 = near_storm.get("sv", Vector2(-0.45, -0.5))
	var sz := sqrt(maxf(0.0, 1.0 - sv2.length_squared()))
	var ang := float(spec.seed) + t_now * float(spec.spin)
	var ca := cos(ang)
	var sa := sin(ang)
	var tl := float(spec.tilt)
	var tx := sv2.x * cos(tl) - sv2.y * sin(tl)
	var ty := sv2.x * sin(tl) + sv2.y * cos(tl)
	var px3 := tx * ca + sz * sa
	var pz3 := -tx * sa + sz * ca
	var amp := 0.07 if StringName(spec.world) == &"icegiant" else 0.11
	var ja := t_now * amp * sin(ty * float(spec.bands) * 0.5 + float(spec.seed))
	var qx := px3 * cos(ja) - pz3 * sin(ja)
	var qz := px3 * sin(ja) + pz3 * cos(ja)
	var lon := atan2(qz, qx)
	var st: Array = spec.storms
	var first := Vector4(lon - t_now * 0.012, ty, float(near_storm.get("z", 0.55)), float(near_storm.get("w", 0.17)))
	var sp := PackedVector4Array([first, st[1]])
	mat.set_shader_parameter("storms", sp)
	# (the world is drawn from its surface's memory, worked out by its own pass)
	var mm: Variant = pv.get("_mem_mat")
	if mm is ShaderMaterial:
		(mm as ShaderMaterial).set_shader_parameter("storms", sp)


## A near world dressed for the style, as the band's are -- but in RADIANT
## with next to none of the gas's wash over it (`NEAR_HAZE`): a band world
## sits deep in the glowing cloud, whose light veils it, most at its limb; the
## world the ship orbits is close, with little gas between, and veiled as the
## band's are it read see-through.
func _dress(v: Node) -> void:
	if painted:
		SectorPaintedS.paint_world(self, v)
	if radiant:
		_set_deep(v, "radiant", true)
		_set_deep(v, "r_haze", NEAR_HAZE)


# ------------------------------------------------------------ the zoom ladder
## THE MAP'S OWN WORLD, HANDED OVER (`ZoomLadder`, 2C; Jon: "it's SO CLOSE, but i
## want it pixel perfect"). The sector map's picture of the world you orbit -- the
## very node, its surface's memory and all -- is taken into this sky's near
## picture in place of the one this sky built, at the map's size, place, light,
## time and tone, and eased from there to this sky's own; at the end it IS the
## near world. So the world never changes identity: the frame the map drew is the
## frame drawn here. {view, own, from (the map's shader values), light, world,
## seed, held, at (this sky's px), r, mix (0 the map's look, 1 this sky's)}.
var _hand := {}
## The near world's clock, behind or ahead of the sky's by this much: the map's,
## kept for the world it handed over.
var near_t_off := 0.0


func adopt_near(v: Node2D, at: Vector2, g: Dictionary) -> bool:
	if _near_vp == null or _near_world == null or _near.is_empty() or orbit_target != int(g.get("body", -9)) \
			or not (v is PlanetView) or not (_near_world is PlanetView):
		return false
	if v.get_parent() != null:
		v.get_parent().remove_child(v)
	# A PICTURE OF ITS OWN WHILE IT MOVES (`ladder_world.gdshader`): the near
	# layer's size and grid, laid over the sky at any fraction of a pixel, so the
	# world slides; into the near picture itself once it has come to rest
	var hvp := SubViewport.new()
	hvp.size = Vector2i(480, 270)
	hvp.size_2d_override = Vector2i(960, 540)
	hvp.size_2d_override_stretch = true
	hvp.transparent_bg = true
	hvp.disable_3d = true
	hvp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	hvp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(hvp)
	var hrect := _rect()
	var hmat := ShaderMaterial.new()
	hmat.shader = HAND
	hmat.set_shader_parameter("tex", hvp.get_texture())
	hmat.set_shader_parameter("ramp", PLAY)
	if _near_mat != null:
		for u in ["keep_lo", "keep_hi", "mid", "cap", "soft"]:
			var val: Variant = _near_mat.get_shader_parameter(u)
			if val != null:
				hmat.set_shader_parameter(u, val)
	hrect.material = hmat
	add_child(hrect)
	# (laid where the sky's own picture is: the window this view shows of it)
	hrect.position = _box.position
	hrect.size = Vector2(960, 540)
	(v as PlanetView).keep_mem = true
	hvp.add_child(v)
	(v as PlanetView).keep_mem = false
	# its memory as the map last drew it, handed in by hand: drawn from it this
	# frame, and the memory's next step taken from it (`_step_hand` lets go)
	var mem_left := 0
	if g.has("mem_img") and v.get("_mem_mat") != null:
		var tm := ImageTexture.create_from_image(g.mem_img)
		(v.get("_mat") as ShaderMaterial).set_shader_parameter("mem_now", tm)
		(v.get("_mem_mat") as ShaderMaterial).set_shader_parameter("mem_prev", tm)
		mem_left = 2
	# (its own world, carried out: the rest of the near layer stays, zoomed as
	# a picture round it -- `hand_own`)
	var own_world := v == _near_world
	if not own_world:
		_near_world.visible = false
		for i in range(1, _near.size()):
			(_near[i][0] as CanvasItem).visible = false
	# the world's own clock as the map last set it (the map steps its worlds on a
	# clock of its own, not its view's), carried on from here
	var pm: Dictionary = g.get("params", {})
	var wt := float(pm.get(&"time", g.get("t", t)))
	near_t_off = wt - t
	_hand = {"view": v, "own": _near_world, "from": g.get("params", {}), "light": g.get("light", Vector3(-0.83, -0.31, 0.47)),
		"world": g.get("world", &"rock"), "seed": int(g.get("seed", 0)), "held": float(g.get("spec_r", 10.0)),
		"at": at, "r": float((g.get("params", {}) as Dictionary).get("r", g.get("spec_r", 10.0))), "mix": float(g.get("mix", 0.0)),
		"freeze_t": wt if bool(g.get("freeze", false)) else -1.0, "mem_left": mem_left,
		"vp": hvp, "rect": hrect, "mat": hmat, "start": at, "grid": _block_round(at), "self": own_world, "ov": g.get("ov", {})}
	# (a measurement holds the surface's memory too, so the frame is the map's
	# last one exactly: the memory eases a step each frame on its own)
	var mv: Variant = v.get("_mem_vp")
	if bool(g.get("freeze", false)) and mv is SubViewport:
		(mv as SubViewport).render_target_update_mode = SubViewport.UPDATE_DISABLED
	_step_hand()
	return true


## THE WORLD YOU ORBIT, CARRIED OUT IN ITS OWN PICTURE (2C, LOCAL to the map;
## Jon: "a small jitter of the planet"): the near world itself moved as
## `adopt_near` moves the map's in -- drawn again at every size, its picture
## slid by fractions of a pixel -- instead of shrunk as a picture on the 2 px
## grid, which wobbled it a pixel back and forth. `near_hand` drives it the
## same way, played the other way round; `end_hand` puts it back.
func hand_own(at: Vector2) -> bool:
	if _near.is_empty() or not (_near_world is PlanetView) or not _hand.is_empty() \
			or float(_near[0][3]) <= 0.0:
		return false
	var v := _near_world as PlanetView
	var d := origin() - at
	var g := {"body": orbit_target, "world": v.spec.get("world", &"rock"), "seed": int(v.get("_seed")),
		"spec_r": float(_near[0][3]), "t": t + near_t_off, "light": Vector3(d.x, d.y, 140.0).normalized(),
		"params": {"lift": 0.0 if legacy else 1.0, "r": float(_near[0][3])}, "ov": {}, "mix": 1.0}
	for k in ["ring", "storm", "right"]:
		if v.spec.has(k):
			g.ov[k] = v.spec[k]
	return adopt_near(v, at, g)


## Where the handed-over world is this frame (this sky's px), how big, and how
## far it has come toward this sky's look.
func near_hand(at: Vector2, r: float, mix: float, end: Vector2 = Vector2.INF) -> void:
	if _hand.is_empty():
		return
	_hand.at = at
	if end != Vector2.INF:
		_hand.end = end
	_hand.drawn = _hand_target(at, clampf(mix, 0.0, 1.0))
	_hand.r = r
	_hand.mix = clampf(mix, 0.0, 1.0)
	if mix > 0.0 and float(_hand.freeze_t) >= 0.0:
		_hand.freeze_t = -1.0
		var mv: Variant = (_hand.view as Node).get("_mem_vp")
		if mv is SubViewport:
			(mv as SubViewport).render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE


## The move is over: the handed-over world becomes the near world for good.
func end_hand() -> void:
	if _hand.is_empty():
		return
	var v: PlanetView = _hand.view
	var own: Node2D = _hand.own
	var R := float(_near[0][3])
	var ov := {}
	if own is PlanetView:
		var os: Dictionary = (own as PlanetView).spec
		for k in ["ring", "storm", "right"]:
			if os.has(k):
				ov[k] = os[k]
	if v.get_parent() != null:
		v.get_parent().remove_child(v)
	v.keep_mem = true
	_near_vp.add_child(v)
	v.keep_mem = false
	for k in ["rect", "vp"]:
		var nd: Variant = _hand.get(k)
		if nd is Node and is_instance_valid(nd):
			(nd as Node).queue_free()
	_near[0][0] = v
	_near_world = v
	if is_instance_valid(own) and own != v:
		own.queue_free()
	v.set_world(StringName(_hand.world), int(_hand.seed), R, ov)
	v.call("set_cell", 2)
	v.set_live(R, Vector2.ZERO)
	# (where `_step_near` will stand it, now: not one frame wherever it was
	# standing in its own picture)
	var rest := _near_rest()
	var hsr := Worlds.half_size(StringName(_hand.world), R)
	if rest != Vector2.INF:
		v.position = rest - Vector2.ONE * float(Worlds.half_size(StringName(_hand.world), float(_near[0][3])) % 2) + Vector2.ONE * float(hsr % 2)
	_dress(v)
	for i in range(1, _near.size()):
		(_near[i][0] as CanvasItem).visible = true
	if _near_mat != null:
		_near_mat.set_shader_parameter("tone_k", 1.0)
	_hand = {}


func _step_hand() -> void:
	var v: PlanetView = _hand.view
	if not is_instance_valid(v):
		_hand = {}
		return
	# the memory handed in by hand, let go of once its own has stepped from it
	if int(_hand.get("mem_left", 0)) > 0 and float(_hand.freeze_t) < 0.0:
		_hand.mem_left = int(_hand.mem_left) - 1
		if int(_hand.mem_left) == 0:
			var mvp: Variant = v.get("_mem_vp")
			var mcp: Variant = v.get("_mem_copy")
			if mvp is SubViewport and mcp is SubViewport:
				(v.get("_mat") as ShaderMaterial).set_shader_parameter("mem_now", (mvp as SubViewport).get_texture())
				(v.get("_mem_mat") as ShaderMaterial).set_shader_parameter("mem_prev", (mcp as SubViewport).get_texture())
	var m := float(_hand.mix)
	var r := float(_hand.r)
	var at: Vector2 = _hand.at
	# grown the way the map grows a world: drawn again at a new size once it has
	# moved two pixels of radius on, and live (any fraction) between
	if absf(r - float(_hand.held)) > 2.0:
		_hand.held = roundf(r)
		v.set_world(StringName(_hand.world), int(_hand.seed), float(_hand.held), _hand.get("ov", {}))
		v.call("set_cell", 2)
	var hs := Worlds.half_size(StringName(_hand.world), float(_hand.held))
	# IN ITS OWN PICTURE IT HOLDS STILL: its middle where the map left it, eased
	# over the last stretch onto its own grid as LOCAL will draw it (the snap,
	# eased); THE PICTURE is what moves, by any fraction of a pixel
	var e := clampf((m - 0.8) / 0.2, 0.0, 1.0)
	var snap := e * e * (3.0 - 2.0 * e)
	var grid: Vector2 = _hand.grid
	var rest := _near_rest()
	var c_vp: Vector2 = (_hand.start as Vector2).lerp(grid + Vector2.ONE * float(hs % 2), snap)
	v.position = grid + Vector2.ONE * float(hs % 2)
	v.set_live(r, c_vp - v.position)
	var target := _hand_target(at, m)
	_hand.drawn = target
	var hm: ShaderMaterial = _hand.get("mat")
	if hm != null:
		hm.set_shader_parameter("shift", target - c_vp)
		hm.set_shader_parameter("tone_k", m)
	# its light: the map's, eased to this sky's (from where the star is here)
	var d := origin() - at
	var L_here := Vector3(d.x, d.y, 140.0).normalized()
	var L := (_hand.light as Vector3).normalized().lerp(L_here, m).normalized()
	var f: Dictionary = _hand.from
	var tt := t + near_t_off
	if float(_hand.freeze_t) >= 0.0:
		tt = float(_hand.freeze_t)
	v.step(tt, L, lerpf(float(f.get("k_light", 1.0)), 1.0, m))
	var vm: ShaderMaterial = v.get("_mat")
	if vm != null:
		var nf_here := Vector3(0.02, 0.02, 0.03)
		if not legacy:
			vm.set_shader_parameter("star_tint", (f.get("star_tint", _tint) as Vector3).lerp(_tint, m))
			vm.set_shader_parameter("night_fill", (f.get("night_fill", nf_here) as Vector3).lerp(nf_here, m))
		vm.set_shader_parameter("flare", lerpf(float(f.get("flare", _flare)), _flare, m))
		vm.set_shader_parameter("lift", lerpf(float(f.get("lift", 1.0)), 0.0 if legacy else 1.0, m))
		# the map's moons' shadows on its face, until it is this sky's
		for nm in f:
			if String(nm).begins_with("moon") and m < 0.5:
				vm.set_shader_parameter(nm, f[nm])
	if _near_mat != null:
		_near_mat.set_shader_parameter("tone_k", m)


## Where the world is drawn: where the move has it, with what is left between
## the move's end and where LOCAL truly draws it at rest taken up over the last
## stretch (so the settle onto LOCAL's own grid is eased, never a snap).
func _hand_target(at: Vector2, m: float) -> Vector2:
	var rest := _near_rest()
	var endp: Vector2 = _hand.get("end", Vector2.INF)
	if rest == Vector2.INF or endp == Vector2.INF:
		return at
	var e := clampf((m - 0.6) / 0.4, 0.0, 1.0)
	var snap := e * e * (3.0 - 2.0 * e)
	return at + (rest - endp) * snap


## Where the near world stands at rest, as `_step_near` draws it (its middle).
func _near_rest() -> Vector2:
	if _near.is_empty():
		return Vector2.INF
	var e0: Array = _near[0]
	var at := _block_round(Vector2(e0[1]) - cam * float(e0[2]))
	var hs := Worlds.half_size(StringName(_hand.get("world", &"rock")), float(e0[3]))
	return at + Vector2.ONE * float(hs % 2)


func _step_near(o: Vector2) -> void:
	if not _hand.is_empty():
		_step_hand()
	for e: Array in _near:
		if not _hand.is_empty() and (e[0] == _hand.own or not (e[0] as CanvasItem).visible):
			continue
		var n: Node2D = e[0]
		var at: Vector2 = _block_round(Vector2(e[1]) - cam * float(e[2]))
		# (a broken world too: left out, the shattered world you orbit stood still,
		# lit from the default side, its rubble frozen)
		if n is PlanetView or n is ShatteredView:
			var spec: Dictionary = n.get("spec")
			var hs := Worlds.half_size(StringName(spec.get("world", &"rock")), float(e[3]))
			n.position = at + Vector2.ONE * float(hs % 2)
			# lit from the star, across the view: from where the star is on screen
			# to where this world is, under the zoom, in this layer's own px
			var d := (origin() - _zp(at, Z_NEAR)) / _zl(Z_NEAR)
			var L := Vector3(d.x, d.y, 140.0).normalized()
			n.call("step", t + (near_t_off if n == _near_world else 0.0), L, 1.0)
			if n == _near_world and not near_storm.is_empty():
				_hold_storm(n, t)
			var vm: ShaderMaterial = n.get("_mat")
			if vm != null:
				if not legacy:
					vm.set_shader_parameter("star_tint", _tint)
					vm.set_shader_parameter("night_fill", Vector3(0.02, 0.02, 0.03))
				vm.set_shader_parameter("flare", _flare)
				vm.set_shader_parameter("lift", 0.0 if legacy else 1.0)
		elif n.position != at:
			n.position = at
			n.queue_redraw()


## A WRECK, close: a long broken hull in a few tones, lit along the edge that
## faces the star, a crack through it and its shards adrift round it, every
## piece in whole 2x2 blocks.
class _Wreck extends Node2D:
	var seed := 0
	var light_from := Vector2(-1.0, -0.6)
	const RAMP := [Color("#0c1219"), Color("#16202b"), Color("#22303f"), Color("#33455a"), Color("#465b73")]

	func _h(k: int) -> float:
		return SkyBakeS.hash2(seed, k)

	func _draw() -> void:
		var L := light_from.normalized()
		var len := 210.0 + 60.0 * _h(1)
		var thick := 30.0 + 10.0 * _h(2)
		var tilt := (_h(3) - 0.5) * 0.3
		var gap := (0.35 + 0.3 * _h(4)) * len - len * 0.5
		var x := -len * 0.5
		while x < len * 0.5:
			var y := -thick * 0.5
			while y < thick * 0.5:
				var nx := x / (len * 0.5)
				var taper := 1.0 - 0.35 * absf(nx) * absf(nx)
				var inside := absf(y) < thick * 0.5 * taper and absf(x - gap) > 6.0 + 4.0 * sin(y * 0.4)
				# decks: a notch every so often along the top edge
				if inside and y < -thick * 0.5 * taper + 4.0 and fmod(absf(x) + 1000.0, 28.0) < 6.0:
					inside = false
				if inside:
					var edge := absf(y) > thick * 0.5 * taper - 4.0
					var lit := (y < 0.0) == (L.y < 0.0)
					var shade := 2 + (1 if lit else -1) + (1 if edge and lit else 0)
					if fmod(absf(x * 0.7 + y) + 1000.0, 22.0) < 2.0:
						shade -= 1
					var p := Vector2(x, y + x * tilt)
					draw_rect(Rect2((p / 2.0).floor() * 2.0, Vector2(2, 2)), RAMP[clampi(shade, 0, 4)])
				y += 2.0
			x += 2.0
		# the shards
		for k in 7:
			var a := _h(20 + k) * TAU
			var dd := len * (0.35 + 0.3 * _h(30 + k))
			var c := Vector2(cos(a) * dd, sin(a) * dd * 0.45)
			var sz := 3.0 + 7.0 * _h(40 + k)
			var yy := -sz
			while yy < sz:
				var xx := -sz * 1.6
				while xx < sz * 1.6:
					if absf(xx) / 1.6 + absf(yy) < sz:
						var lit2 := (yy < 0.0) == (L.y < 0.0)
						draw_rect(Rect2(((c + Vector2(xx, yy)) / 2.0).floor() * 2.0, Vector2(2, 2)), RAMP[3 if lit2 else 1])
					xx += 2.0
				yy += 2.0


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
