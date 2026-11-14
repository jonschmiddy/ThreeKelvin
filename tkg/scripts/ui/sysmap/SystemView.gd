extends Control

## Layer order follows the approved mockup; the palette pass runs before the faint lines.
## Why: docs/why/SystemView.md#sector-map-picture

## The panel sits beside the map now, not over it.
const PANEL := 0
## THE STAR IN THE MIDDLE (Jon: "can we center the star"); the screen centres
## this point in its frame.
const CX := 480
const CY := 270
const TILT := 0.38
## Each sky layer slides at its own rate per pixel of pan, so each reads as its own depth.
const PARALLAX := 0.05
## Layers slide by where the camera looks, not by screen pan, which grew with the zoom.
## Why: docs/why/SystemView.md#sky-parallax
const PARALLAX_AT := 0.5
const PARALLAX_TWINKLE := 0.16
## More depths of stars and gas behind the plane, nearer ones bigger, warmer and faster.
## Why: docs/why/SystemView.md#sky-parallax
const PARALLAX_VEIL := 0.28
const FIELDS := [[420, 0.08, 0.25, 0.0, 0.03], [260, 0.15, 0.45, 0.03, 0.09],
	[140, 0.3, 0.7, 0.08, 0.22], [50, 0.5, 1.0, 0.2, 0.36], [22, 0.6, 1.0, 0.7, 0.46], [26, 0.1, 0.22, 0.0, 0.55]]
const SkyGalaxiesS := preload("res://scripts/ui/sysmap/SkyGalaxies.gd")
var _galaxies: Node2D
const VEIL := preload("res://shaders/sky_veil.gdshader")
## One dial, `DEPTH_K`, scales every dust sheet from the old map (0) to full strength (1).
## Why: docs/why/SystemView.md#dust-depth
const DEPTH_K := 0.9
const DEPTH := preload("res://shaders/sky_depth.gdshader")
static var depth_k := DEPTH_K
## Every sheet at full strength: [distance beyond the plane, strength, look (0
## wisps, 1 fluff), cloud size, cover]; and the near wisps' full strength.
const DEPTH_FAR := [[3.5, 0.12, 0, 520.0, 0.5], [2.2, 0.8, 1, 560.0, 0.5], [1.5, 0.11, 0, 420.0, 0.52],
	[0.8, 0.75, 1, 420.0, 0.54], [0.6, 0.1, 0, 320.0, 0.55]]
const DEPTH_NEAR_K := 0.08
## the system's sky, by where it is (`SkyBake.look_for`): in a nebula or clear
var _sky_look: Dictionary = {}
## the dust's dial outside a nebula: very sparse thin dust
const DEPTH_K_CLEAR := 0.15
## Inside a nebula the sky is the cloud itself, lit by the system's sun.
## Why: docs/why/SystemView.md#nebula-sky
const NEB_SKY := preload("res://shaders/sky_nebula.gdshader")
static var neb_sky := true
## SIMPLIFIED bakes the cloud once and lights it per frame; the old gas and dust are gone.
## Why: docs/why/SystemView.md#rendering-styles
const STYLE_SIMPLIFIED := &"simplified"
## Over the star-chart field the sky leaves out its own far stars, as the field supplies them.
## Why: docs/why/SystemView.md#field-under
var field_under := false
## PAINTED draws SIMPLIFIED's far picture, then paints it on the scene's palette in held poses.
const STYLE_PAINTED := &"painted"
const SectorPaintedS := preload("res://scripts/ui/sysmap/SectorPainted.gd")
## this system drawn in PAINTED (set as it is shown)
var painted := false
## RADIANT lights the SIMPLIFIED cloud as a volume the sun shines through.
## Why: docs/why/SystemView.md#rendering-styles
const STYLE_RADIANT := &"radiant"
## how many bodies throw shadows at once: the worlds, then their moons
const SHADOW_CASTERS := 24
var radiant := false
## RADIANT's key light on the map: the sun's light halves this far out on screen
## (`sky_nebula`'s `r_key`)
const SECTOR_KEY_PX := 100.0
## RADIANT's glow (`RadiantGlow`): the place's picture wrapped
var _glow: SubViewport = null
## and its look here: the sun's rays through the gas, a deep violet shade;
## the rays' reach 0.4 of the frame and no `crush`; `GLOW_CORE_RAYS` round the core.
## Why: docs/why/SystemView.md#radiant-glow-look
const GLOW_LOOK := {"wide_smooth": true, "thr": 0.55, "knee": 0.16, "gain": 2.2, "self_k": 0.9, "steps": 5.0, "band": 0.22, "rays": 1.1, "ray_len": 0.4,
	"halo_a": Vector3(1.0, 0.7, 0.45), "halo_b": Vector3(0.6, 0.45, 0.3), "wide_k": 0.7,
	"shade_tint": Vector3(0.28, 0.16, 0.8), "shade": 0.5, "dark_hi": 0.06, "crush": 0.0, "vib": 0.0,
	"keep_lo": 0.085}
const GLOW_CORE_RAYS := 0.3
## THE RED GIANT'S GLOW (Jon, Nov 7, RC:2B): only the star and its hottest gas glow,
## about half as far out; LOCAL keeps its look.
## Why: docs/why/SystemView.md#red-giant-glow
const GLOW_GIANT := {"thr": 0.8, "halo_b": Vector3(0.75, 0.3, 0.0), "ray_len": 0.2}
## the painted pass's viewports and materials (`SectorPainted.build`)
var _pt := {}
## the emission cloud's bubble round the sun, on the plane: a sphere in the
## system, so the worlds never slide across its wall as the map zooms
var bubble_r := 400.0
## Reserved steps per cloud kind keep its gradients from snapping to a plate or the void.
## Why: docs/why/SystemView.md#reserved-palette-steps
const C_RESERVED := {
	# The strike's pale pinks are left out: they took the cloud's brightest rose as a candy plate.
	# Why: docs/why/SystemView.md#reserved-palette-steps
	0: ["#1e3233", "#283f3f", "#33504e", "#3f625f", "#4a7672", "#558a85", "#ffe8f0", "#4a1426", "#6a1c34", "#8c2842", "#b03452", "#130a13", "#1a0a14", "#2c121e", "#1a1026"],
	1: ["#f2f2ff", "#d6defc", "#b2c2f2", "#8ea4e2", "#0d1226", "#141c3c", "#1e2a52"],
	5: ["#4a1406", "#84280c", "#c24a14", "#ec7a26", "#ffb054", "#ffdc96", "#1c1624", "#2a2236", "#3c3048", "#110b11", "#160c12"],
}
const R_CORE := ["#4a1406", "#84280c", "#c24a14", "#ec7a26", "#ffb054", "#ffdc96", "#110b11", "#1e1214", "#2e1c1c", "#432824", "#5c3830", "#77493c", "#93604c", "#b07a62"]
## the star's light (linear) on the worlds' lit sides, and a flare's height now
var _tint := Vector3.ONE
var _flare := 0.0
## each world's catch of a pulsar's beam, eased so a sweep never strobes
var _beam_k := {}
## how far it slides as the camera pans: nearer than the far stars, farther
## than the veil
const PARALLAX_NEB := 0.1
var _neb_mat: ShaderMaterial
var _neb_t0 := 0.0
## THE WEATHER, every system's (`SkyWeather`): it schedules and places each
## event and drives the layers that draw it
var _weather
const SkyWeatherS := preload("res://scripts/ui/sysmap/SkyWeather.gd")
## the in-system pictures some of it draws in: a comet, a dust puff in a belt,
## a far star drifting behind the black hole
var _comet
var _puff
var _drift
## Hot points of cloud events draw over the depth sheets, or dust dims a white star to a grey speck.
var _points
## A HARNESS'S CLOCK for everything the weather and the gas read off the wall
## clock (SystemShot's clips step it a frame at a time); -1: the wall clock
var hclock := -1.0
## the weather's own colours left out of the palette (SystemShot `wramp=0`)
static var no_ramp := false
## the sheets behind the plane, by distance beyond it (the plane is 1/zoom from
## the camera), and those in front, every DEPTH_RHO times nearer from DEPTH_D0
const DEPTH_D0 := 0.02
const DEPTH_RHO := 1.6
const DEPTH_NEAR := 4
const FABRIC := preload("res://shaders/map_fabric.gdshader")
## Sky, stars and worlds draw at half size and show at twice, so all sit on one 2x2 grid.
## Why: docs/why/SystemView.md#block-grid
const SCENE := Vector2i(480, 270)
const ZOOM_MAX := 4.0
const SkyBakeS := preload("res://scripts/ui/sysmap/SkyBake.gd")
const SystemPaletteS := preload("res://scripts/ui/sysmap/SystemPalette.gd")
const SKY := preload("res://shaders/sky.gdshader")
const PALETTE := preload("res://shaders/map_palette.gdshader")
const SHADOWS := preload("res://shaders/map_shadows.gdshader")
const BELT_DUST := preload("res://shaders/map_belt.gdshader")
var _belt_dust: ColorRect
var _belt_mat: ShaderMaterial
const SunViewS := preload("res://scripts/ui/sysmap/SunView.gd")
const PulsarViewS := preload("res://scripts/ui/sysmap/PulsarView.gd")
const CoreViewS := preload("res://scripts/ui/sysmap/CoreView.gd")
const CoreLegacyS := preload("res://scripts/ui/sysmap/CoreLegacy.gd")

const KIND_NAMES := ["ORDINARY", "RED", "BLUE", "PULSAR", "CORE"]

var node: MapGen.MapNode
var layout: SystemLayout
var kind: String = "ORDINARY"
## Seconds on this system's clock; the screen moves it on.
var t: float = 0.0
## Where each body is this frame, on the plane, and on screen.
var pos: Array[Vector2] = []
var at: Array[Vector2] = []

var _bake
var _sky: ColorRect
var _sky_mat: ShaderMaterial
var _twinkle: _Twinkle
var _fields: Array = []
var _veil_mat: ShaderMaterial
## the dust sheets: [material, behind (distance beyond the plane) or -1 for a
## near slot, slot, strength, look]
var _depth: Array = []
## The half-size picture the place is drawn into.
var _scene: SubViewport
## The picture is 960 px but the area runs on under the side panel, so the cloud continues there.
## Why: docs/why/SystemView.md#strip-past-the-picture
var _past: SubViewport
## [the picture's material, the strip's copy of it], for the layers drawn
## from their own pixel (`px_span`, `px0`)
var _past_mats: Array = []
## [the picture's layer, the strip's twin of it]
var _past_twins: Array = []
const PAST_X0 := 928
const PAST_W := 192
var _belts: _Belts
var _shadows: ColorRect
var _shadow_mat: ShaderMaterial
var _star_layer: Node2D
## The star's own painter: a SunView, a PulsarView, or a CoreView.
var star: Node2D
## Star B is its own `SunView`, sized like A but smaller, warmer and rolled apart from A's.
## Why: docs/why/SystemView.md#twin-suns
var star2: Node2D = null
var _kq2 := -1.0
var _klive2 := -1.0
var _kcor2 := -1.0
## star B's light (linear, its brightest channel 1), and its colour as the sky
## and the dust take it (`STARCOL`'s, warmer)
var _tint2 := Vector3.ONE
const STAR_B_COL := Vector3(1.0, 0.74, 0.48)
## B's prominences run behind A's so the two suns are rarely at their height together.
## Why: docs/why/SystemView.md#twin-suns
const STAR_B_PROM := 23.0
## star B's prominence's envelope this frame (0 with one sun): the flare of the
## worlds it lights
var _flare2 := 0.0
var _flash: ColorRect
## A distant supernova, now and then, in the far sky.
var _nova: _Nova
## Sizes are held in whole blocks with hysteresis: redrawn at every zoom fraction they flickered.
## Why: docs/why/SystemView.md#held-sizes
const HOLD_PX := 1.4
var _kq := -1.0
var _sky_z := -1.0
var _rq := {}
## While zooming, worlds draw at true radius and centre; once still, they ease back onto the grid.
## Only the settle is eased: easing the centre every frame made the picture lag behind a pan.
## Why: docs/why/SystemView.md#smooth-zoom
var _live := {}
var _at_last := {}
var _klive := -1.0
## The corona follows the true zoom while it moves, then eases back onto the disc's size.
var _kcor := -1.0
var _zlast := -1.0
var _zstill := 1.0
const SETTLE_S := 0.18
const LIVE_Q := 0.5
static var _nosmooth := "nosmooth" in OS.get_cmdline_user_args()
const SETTLE_EASE := 0.08
## Pulsar centre is carried like a world's `_live`, then settles back onto its block.
var _plive := Vector2.INF
var _plast := Vector2.ZERO
var _beat_off := 0.0
## how long the pulsar's beat takes to follow the sound's clock (`beat_follow`)
const BEAT_FOLLOW_S := 0.5
var _palette: ColorRect
var _palette_mat: ShaderMaterial
var _lines: _Lines
## The worlds' orbit rings drawn (the map's toolbar, HIDE ORBITS)
var orbits_on := true
var _fabric: _Fabric
var _worlds: Node2D
var _moons: _Moons
## Only these worlds draw their moons' orbits; the moons themselves always show.
var moon_focus: Dictionary = {}
var _views: Dictionary = {}
var _ready_sky := false
var _palette_built := false
var _frame := 0
## The first row of the game picture the map is seen in (under the HUD).
var top := 0
## The part of the picture the frame shows: the ship warps in at its edge and
## the hover tip stays inside it.
var window := Rect2(0, 0, 960, 540)
## THE CAMERA, set by the screen.
var zoom := 1.0
var pan := Vector2.ZERO
## The size the worlds were last drawn at, so they are redrawn only on a change.
var _drawn_zoom := 1.0
## THE BELT POINTED AT, and how far its hover has eased in: its rocks brighten.
var belt_lit := -1
var belt_t := 0.0
## Minimum drawn size only, so a small world reads as a world; its orbit and layout are unchanged.
static var min_r := 10.0
## PROFILING (`-- sheet=ZoomProf`): microseconds by part, kept only while on.
static var prof := {}
static var prof_on := false


func _init() -> void:
	size = Vector2(960, 540)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## The strip repeats the sky layers from `PAST_X0`; worlds, belts and stars are not carried.
## Why: docs/why/SystemView.md#strip-past-the-picture
func _past_build(hold: bool) -> void:
	_past = SubViewport.new()
	_past.size = Vector2i(PAST_W / 2, SCENE.y)
	_past.size_2d_override = Vector2i(PAST_W, 540)
	_past.size_2d_override_stretch = true
	_past.transparent_bg = false
	_past.disable_3d = true
	_past.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_past.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_past)
	_past_mats.clear()
	_past_twins.clear()
	for ch in _scene.get_children():
		if not (ch is ColorRect):
			continue
		var cr := ch as ColorRect
		var tw := ColorRect.new()
		tw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tw.color = cr.color
		var sm := cr.material as ShaderMaterial
		if sm == null or sm == _neb_mat:
			# (a flat rect -- the pulsar's flash -- or the cloud: the whole width,
			# its corner PAST_X0 back)
			tw.position = Vector2(-PAST_X0, 0)
			tw.size = Vector2(PAST_X0 + PAST_W, 540)
			tw.material = cr.material
		elif sm == _palette_mat:
			if hold:
				continue
			tw.size = Vector2(PAST_W, 540)
			tw.material = sm
		elif _has_uniform(sm.shader, &"px_span"):
			var pm := sm.duplicate() as ShaderMaterial
			pm.set_shader_parameter("px_span", Vector2(PAST_W, 540))
			pm.set_shader_parameter("px0", Vector2(PAST_X0, 0))
			tw.size = Vector2(PAST_W, 540)
			tw.material = pm
			_past_mats.append([sm, pm])
		else:
			continue
		_past.add_child(tw)
		_past_twins.append([cr, tw])
	# (copied just before each frame is drawn, after everything has moved)
	if not RenderingServer.frame_pre_draw.is_connected(_past_sync):
		RenderingServer.frame_pre_draw.connect(_past_sync)


static func _has_uniform(sh: Shader, nm: StringName) -> bool:
	if sh == null:
		return false
	for u: Dictionary in sh.get_shader_uniform_list():
		if StringName(u.get("name", "")) == nm:
			return true
	return false


## The strip is drawn as the picture is this frame, so its gas is lit and moved alike.
func _past_sync() -> void:
	if _past == null or not is_instance_valid(_past):
		return
	for tw: Array in _past_twins:
		var src := tw[0] as ColorRect
		var dst := tw[1] as ColorRect
		if is_instance_valid(src) and is_instance_valid(dst):
			dst.visible = src.visible
			dst.color = src.color
			dst.modulate = src.modulate
	for pair: Array in _past_mats:
		var src := pair[0] as ShaderMaterial
		var dst := pair[1] as ShaderMaterial
		for u: Dictionary in src.shader.get_shader_uniform_list():
			var nm: StringName = u.get("name", &"")
			if nm == &"" or nm == &"px_span" or nm == &"px0":
				continue
			dst.set_shader_parameter(nm, src.get_shader_parameter(nm))


## Show system `n`. Returns once its sky is baked.
func show_system(n: MapGen.MapNode) -> void:
	node = n
	layout = SystemLayout.of(n)
	kind = KIND_NAMES[layout.star]
	painted = is_painted()
	radiant = not painted and is_radiant()
	_pt = {}
	for c in get_children():
		c.queue_free()
	_past = null
	_past_mats.clear()
	_past_twins.clear()
	_views.clear()
	_rq.clear()
	_kq = -1.0
	_live.clear()
	_at_last.clear()
	_klive = -1.0
	_kcor = -1.0
	star2 = null
	_kq2 = -1.0
	_klive2 = -1.0
	_kcor2 = -1.0
	_zlast = -1.0
	_plive = Vector2.INF
	_sky_z = -1.0
	_rprobe = {}
	_fields.clear()
	_ready_sky = false
	_palette_built = false
	_frame = 0
	_glow = null
	# THE PLACE'S OWN PICTURE, half the size, shown at twice
	var box := SubViewportContainer.new()
	box.stretch = false
	box.size = Vector2(SCENE)
	box.scale = Vector2(2, 2)
	box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_scene = SubViewport.new()
	_scene.size = SCENE
	_scene.size_2d_override = Vector2i(960, 540)
	_scene.size_2d_override_stretch = true
	_scene.transparent_bg = false
	_scene.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_scene.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	box.add_child(_scene)
	_sky = ColorRect.new()
	_sky.size = Vector2(960, 540)
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = SKY
	_sky.material = _sky_mat
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scene.add_child(_sky)
	# THE PULSAR'S SKY FLASH, for the systems that rolled it: the whole map
	# brightens blue on the beat.
	_flash = ColorRect.new()
	_flash.position = Vector2.ZERO
	_flash.size = Vector2(960, 540)
	_flash.color = Color(0, 0, 0, 1)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_flash.material = add
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.visible = false
	_scene.add_child(_flash)
	# THE FARTHEST THING: a supernova now and then, under the gas and everything
	_nova = _Nova.new()
	_nova.setup(self, n.index)
	_scene.add_child(_nova)
	# a far star drifting behind the black hole, read by its lens
	_drift = SkyWeatherS.Drift.new()
	_drift.view = self
	_scene.add_child(_drift)
	# THE DISTANT GALAXIES, farthest of all, seeded per system
	_galaxies = SkyGalaxiesS.new()
	_galaxies.call("setup", n.index, painted)
	_scene.add_child(_galaxies)
	# THE DEPTHS: the far star fields, the veil of nearer gas, the twinkling
	# stars, then the nearer fields and the motes
	_sky_look = SkyBakeS.look_for(n, kind)
	# SIMPLIFIED's core: the galaxy's heart is a cloud too (`sky_nebula` kind 5),
	# warm gas swirling round the hole and lit by its disc
	if layout.star == SystemLayout.StarKind.CORE:
		_sky_look.neb = 5
		_sky_look.shape = 0
		_sky_look.hue = Vector3(0.62, 0.32, 0.2)
	var pal: Array = _sky_look.pal
	var neb_on: bool = neb_sky and _sky_look.has("neb") and not ("nebsky=0" in OS.get_cmdline_user_args())
	if neb_on:
		# SIMPLIFIED: the cloud is all of the gas and the dust; the bake under it is
		# the stars and the void alone
		_sky_look.thick = 0.0
		_sky_look.dust = 0.0
	elif not bool(_sky_look.get("nebula", true)):
		# SIMPLIFIED's clear sky has no gas, dust or glow: this faint they set to grey smog.
		_sky_look.thick = 0.0
		_sky_look.dust = 0.0
		# (PAINTED's band is set in its band memory by B's own rule, two tones
		# with a checkered edge: `sector_b_state`)
		_sky_look.band_glow = 0.0
	bubble_r = _bubble_r()
	if painted:
		# (PAINTED: B's small teal heart round the sun, the rose lit all round it)
		bubble_r *= 0.45
	_tint = star_light()
	_tint2 = _lin_top(STAR_B_COL)
	_beam_k.clear()
	_neb_mat = null
	_weather = null
	for fi in FIELDS.size():
		var spec: Array = FIELDS[fi]
		var f := _Field.new()
		f.setup(n.index * 31 + 5 + fi * 977, spec[0], spec[1], spec[2], spec[3])
		# (PAINTED: bare blocks; the paint gives the stars their pluses and sparkles,
		# and an arm drawn here was matched as a speck of halo or galaxy)
		f.bare = painted
		f.rate = spec[4]
		_fields.append(f)
	# Far star fields sit behind the cloud, as gas hides what is behind it.
	for fi in 4:
		_scene.add_child(_fields[fi])
	# the twinkling stars behind it too
	_twinkle = _Twinkle.new()
	_scene.add_child(_twinkle)
	var veil := ColorRect.new()
	veil.size = Vector2(960, 540)
	_veil_mat = ShaderMaterial.new()
	_veil_mat.shader = VEIL
	_veil_mat.set_shader_parameter("pal0", pal[0])
	_veil_mat.set_shader_parameter("pal1", pal[1])
	_veil_mat.set_shader_parameter("sd", float(n.index) * 1.913 + 40.0)
	veil.material = _veil_mat
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scene.add_child(veil)
	# THE CLOUD ROUND THE SYSTEM, behind the dust sheets, and its weather
	if neb_on:
		var neb := ColorRect.new()
		neb.size = Vector2(960, 540)
		_neb_mat = ShaderMaterial.new()
		_neb_mat.shader = NEB_SKY
		_neb_mat.set_shader_parameter("kind", int(_sky_look.neb))
		_neb_mat.set_shader_parameter("shape", int(_sky_look.shape))
		_neb_mat.set_shader_parameter("hue", _sky_look.hue)
		_neb_mat.set_shader_parameter("sd", float(n.index % 97) * 0.731 + 3.0)
		# (a reflection cloud only scatters light: a little dimmer, so it is deep
		# navy far from the sun and never a pale periwinkle wash)
		_neb_mat.set_shader_parameter("exposure", {NebulaField.Kind.REFLECTION: 0.8, NebulaField.Kind.EMISSION: 1.05}.get(int(_sky_look.neb), 1.0))
		neb.material = _neb_mat
		neb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_scene.add_child(neb)
		_neb_t0 = wclock() - 1.0
		# (the distant galaxies seen through the cloud, faint: at full strength they
		# sat on the lit gas like stickers)
		_galaxies.modulate = Color(0.35, 0.35, 0.35)
	# THE WEATHER, for every system: after the cloud, or the veil
	_weather = SkyWeatherS.new()
	_scene.add_child(_weather)
	depth_k = DEPTH_K if bool(_sky_look.get("nebula", true)) else DEPTH_K_CLEAR
	if painted and _neb_mat != null and layout.star != SystemLayout.StarKind.PULSAR and int(_sky_look.neb) != NebulaField.Kind.DARK:
		# (PAINTED's cloud is B's three sheets, depth and all: SIMPLIFIED's dust sheets
		# over it set in jagged maroon plates)
		depth_k = 0.0
	for a_d in OS.get_cmdline_user_args():
		if (a_d as String).begins_with("depth="):
			depth_k = clampf(float((a_d as String).substr(6)), 0.0, 1.0)
	_depth = []
	if depth_k > 0.0:
		veil.visible = false
		# GRAPHICS LOW: the two fluffy sheets only, no far wisps, no near ones
		var low := gfx_low()
		# A sheet that draws nothing is not built: those passes were most of the dust's GPU time.
		# Why: docs/why/SystemView.md#dust-sheets
		var blank := _wisps_blank()
		var sk := 0
		for fd: Array in DEPTH_FAR:
			if low and int(fd[2]) == 0:
				continue
			if blank and int(fd[2]) == 0:
				sk += 1
				continue
			var fk: Array = fd.duplicate()
			fk[1] = float(fd[1]) * depth_k
			_scene.add_child(_depth_sheet(fk, -1, pal, n.index, sk))
			sk += 1
	_points = SkyWeatherS.Points.new()
	_scene.add_child(_points)
	for fi in range(4, _fields.size()):
		_scene.add_child(_fields[fi])
		if painted and _neb_mat != null:
			# (PAINTED in a cloud: the nearest stars and motes as light added over the
			# gas -- drawn over it as they are, the dim motes set as dark specks in it)
			var am := CanvasItemMaterial.new()
			am.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			_fields[fi].material = am
	# THE BELTS' DUST (C): a faint lit band under the rocks, so a belt reads as
	# a band from afar
	_belt_dust = ColorRect.new()
	_belt_dust.size = Vector2(960, 540)
	_belt_dust.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_belt_mat = ShaderMaterial.new()
	_belt_mat.shader = BELT_DUST
	_belt_mat.set_shader_parameter("star_col", SkyBakeS.STARCOL.get(kind, SkyBakeS.STARCOL.ORDINARY))
	_belt_mat.set_shader_parameter("strength", 0.55 if layout.star == SystemLayout.StarKind.PULSAR else 1.0)
	_belt_dust.material = _belt_mat
	_belt_dust.visible = layout.bodies.any(func(bb: SystemLayout.Body) -> bool: return bb.kind == &"belt")
	_scene.add_child(_belt_dust)
	_belts = _Belts.new()
	_belts.view = self
	_scene.add_child(_belts)
	# the comet and the collision's dust: in the system, under the palette and the worlds
	_comet = SkyWeatherS.Comet.new()
	_comet.view = self
	_scene.add_child(_comet)
	_puff = SkyWeatherS.Puff.new()
	_puff.view = self
	_scene.add_child(_puff)
	_shadows = ColorRect.new()
	_shadows.size = Vector2(960, 540)
	_shadow_mat = ShaderMaterial.new()
	_shadow_mat.shader = SHADOWS
	_shadow_mat.set_shader_parameter("px_scale", 2.0)
	_shadows.material = _shadow_mat
	_shadows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# RADIANT in a cloud: shadows are shafts through the lit gas, so this flat darkening goes.
	_shadows.visible = layout.star != SystemLayout.StarKind.PULSAR and not (radiant and _neb_mat != null)
	if radiant:
		_sky_mat.set_shader_parameter("radiant", true)
		_sky_mat.set_shader_parameter("tilt", TILT)
		if _neb_mat != null:
			_neb_mat.set_shader_parameter("radiant", true)
			# (a touch lower: the haze and the shafts' light added a tenth, and round the
			# sun the gas went to a flat pale plate)
			_neb_mat.set_shader_parameter("exposure", float(_neb_mat.get_shader_parameter("exposure")) * 0.86)
			# (CHIAROSCURO, proto/radiant-a: the sun's light falls off across the map's
			# window, a quarter of LOCAL's frame narrower; at LOCAL's 160 px the map's gas
			# still read lit edge to edge)
			_neb_mat.set_shader_parameter("r_key", SECTOR_KEY_PX)
	_scene.add_child(_shadows)
	# Sun and pulsar draw under the palette; the black hole draws among the worlds its lens bends.
	_star_layer = Node2D.new()
	_scene.add_child(_star_layer)
	match layout.star:
		SystemLayout.StarKind.PULSAR:
			star = PulsarViewS.new()
			star.position = Vector2(CX, CY)
			_star_layer.add_child(star)
			star.call("setup", n.index, Rect2(0, 0, 960, 540))
			# The sky's own shell replaces the web, whose noise shimmered on every zoom.
			# Why: docs/why/SystemView.md#pulsar-web
			(star.get("_web_mat") as ShaderMaterial).set_shader_parameter("web_on", false)
		SystemLayout.StarKind.CORE:
			# SIMPLIFIED: direction C's hole, Jon's pick for every style (`CoreLegacy`)
			star = CoreLegacyS.new()
			star.position = Vector2(CX, CY)
		_:
			star = SunViewS.new()
			star.position = Vector2(CX, CY)
			star.call("setup", kind, n.index, layout.star_r)
			if radiant and n.in_nebula:
				# (RADIANT in a cloud: the gas round the sun is its glow, lit by it; the
				# sun's own painted glow on top read as a pale ring A never drew)
				var sm: ShaderMaterial = star.get("_mat")
				sm.set_shader_parameter("glow_i", float((star.get("P") as Dictionary).glow_i) * 0.3)
			if layout.twin:
				# STAR B, a second sun painted the same way (`sun_setup`)
				star2 = SunViewS.new()
				star2.position = Vector2(CX, CY)
				sun_setup(star2, SystemLayout.STAR_B, layout.star2_r)
				if radiant and n.in_nebula:
					var sm2: ShaderMaterial = star2.get("_mat")
					sm2.set_shader_parameter("glow_i", float((star2.get("P") as Dictionary).glow_i) * 0.3)
	# Near sheets draw in front of the palette; none where a wisp draws nothing.
	if depth_k > 0.0 and not gfx_low() and not _wisps_blank():
		for sl in DEPTH_NEAR:
			_scene.add_child(_depth_sheet([-1.0, DEPTH_NEAR_K * depth_k, 0, 260.0, 0.62], sl, pal, n.index))
	_palette = ColorRect.new()
	_palette.size = Vector2(960, 540)
	_palette_mat = ShaderMaterial.new()
	_palette_mat.shader = PALETTE
	_palette_mat.set_shader_parameter("pal_n", 0)
	# its dither cell is one pixel of the half-size picture: a 2x2 block
	_palette_mat.set_shader_parameter("cell", 1)
	# Round a pulsar the colour is read whole and held, as one-level wobbles flipped dither pixels.
	# Why: docs/why/SystemView.md#pulsar-palette-hold
	var hold := layout.star == SystemLayout.StarKind.PULSAR and not ("palhold=0" in OS.get_cmdline_user_args())
	_palette_mat.set_shader_parameter("fine", hold)
	if hold and not painted:
		var mem := SubViewport.new()
		mem.size = SCENE
		mem.transparent_bg = false
		mem.disable_3d = true
		mem.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		var last := TextureRect.new()
		last.texture = _scene.get_texture()
		mem.add_child(last)
		_scene.add_child(mem)
		_palette_mat.set_shader_parameter("prev", mem.get_texture())
		_palette_mat.set_shader_parameter("hold_k", 1.0)
	_palette.material = _palette_mat
	_palette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scene.add_child(_palette)
	# (the cloud drawn on past the picture's end: `_past`)
	if _neb_mat != null and not painted:
		_past_build(hold)
	# THE SHADOWS AFTER THE PALETTE, so their fade is not snapped to its colours
	_scene.move_child(_shadows, _palette.get_index())
	if painted:
		# PAINTED puts everything far into the far picture, which the paint pass reads.
		_shadow_mat.set_shader_parameter("painted", true)
		var near := [_belts, _palette]
		var far: Array[Node] = []
		for ch in _scene.get_children():
			if not near.has(ch):
				far.append(ch)
		var svp := SectorPaintedS.build(self)
		# (the distant galaxies in a clear sky only: a cloud's palette has no steps
		# for them, and they came out as specks of its gas)
		_galaxies.visible = SectorPaintedS.sky_key(self) == &"calm"
		for ch in far:
			ch.reparent(svp, false)
		_palette.visible = false
		_scene.move_child(_pt.tvp, 0)
		_scene.move_child(_pt.rect, 1)
	_worlds = Node2D.new()
	_scene.add_child(_worlds)
	# Sun and hole draw among the worlds, so a world behind the sun is covered by its face.
	if layout.star == SystemLayout.StarKind.CORE:
		_worlds.add_child(star)
		if not headless():
			star.call("setup")
	elif layout.star != SystemLayout.StarKind.PULSAR:
		# (a twin's star B among the worlds too, painted as star A: every style
		# draws both through this one path)
		for sn: Node2D in ([star, star2] if star2 != null else [star]):
			_worlds.add_child(sn)
			(sn.get("_mat") as ShaderMaterial).set_shader_parameter("half_pal", true)
			# B FOR EVERY SUN (Jon: "the red hypergiant needs to look more pixellated ...
			# I think it would look good for ALL the stars"): its dither in 2x2 blocks
			(sn.get("_mat") as ShaderMaterial).set_shader_parameter("cell", 2)
			if painted:
				(sn.get("_mat") as ShaderMaterial).set_shader_parameter("painted", true)
	# THE STAR'S OWN DITHER IN BLOCKS, and the black hole's lens reading the
	# half-size screen a block at a time
	for sn: Node2D in ([star, star2] if star2 != null else [star]):
		_set_deep(sn, "cell", 2)
		_set_deep(sn, "px_scale", 2.0)
		if painted:
			_set_deep(sn, "painted", true)
		if radiant:
			_set_deep(sn, "radiant", true)
	for i in layout.bodies.size():
		var b := layout.bodies[i]
		if b.world == &"":
			continue
		var v: WorldView = Worlds.view_for(b.world)
		v.set_world(b.world, b.seed, world_r(b))
		# EVERY WORLD IN 2x2 BLOCKS, the small ones too (Jon)
		v.set_cell(2)
		_worlds.add_child(v)
		_views[i] = v
		if painted:
			SectorPaintedS.paint_world(self, v)
		if radiant:
			_set_deep(v, "radiant", true)
	# RADIANT'S GLOW AND COLOUR (`RadiantGlow`): the place's picture wrapped, its
	# light glowing in steps, its shade deep; the instruments stay over it, unlit
	if radiant:
		_glow = RadiantGlow.wrap(_scene, Vector2(960, 540), GLOW_LOOK.merged(GLOW_GIANT, true) if layout.star == SystemLayout.StarKind.RED else GLOW_LOOK)
		RadiantGlow.glow_mat(_glow).set_shader_parameter("light", Vector2(CX, CY) / Vector2(960, 540))
		if layout.star == SystemLayout.StarKind.CORE:
			RadiantGlow.glow_mat(_glow).set_shader_parameter("rays", GLOW_CORE_RAYS)
	# THE INSTRUMENTS, single pixels over the place: the fabric, then the orbits
	_fabric = _Fabric.new()
	_fabric.view = self
	add_child(_fabric)
	_Fabric.warm(layout.edge)
	_lines = _Lines.new()
	_lines.view = self
	add_child(_lines)
	# the moons over them, single pixels like the lines (in the blocky picture
	# their 2x2 orbits read as chunky blue rings across a giant's face)
	_moons = _Moons.new()
	_moons.view = self
	add_child(_moons)
	_step_bodies()
	_weather.setup(self, n.index)
	# NO PICTURE TO READ BACK HEADLESS. The bots and the harnesses still build
	# this screen; its layout and its beacons are all they use.
	if headless():
		return
	_bake = SkyBakeS.new()
	_bake.no_stars = field_under
	var skc := sky_c()
	await _bake.make(self, n.index, kind, n.in_nebula, layout.edge, skc.x, skc.y, TILT, _sky_look)
	_sky_mat.set_shader_parameter("base", _bake.base)
	_sky_mat.set_shader_parameter("gas", _bake.gas)
	_sky_mat.set_shader_parameter("pulsar", kind == "PULSAR")
	_sky_mat.set_shader_parameter("star_col", SkyBakeS.STARCOL.get(kind, SkyBakeS.STARCOL.ORDINARY))
	_sky_mat.set_shader_parameter("margin", float(SkyBakeS.M))
	# the remnant worked out again close in, from the bake's own recipe
	_sky_mat.set_shader_parameter("rem_sd", _bake.bake_sd)
	_sky_mat.set_shader_parameter("rem_on", kind == "PULSAR" and bool(_sky_look.get("c_remnant", true)))
	if _neb_mat != null:
		# THE CLOUD, baked once (SIMPLIFIED): its density for the sun to light
		await _bake.field(self, int(_sky_look.neb), int(_sky_look.shape), float(n.index % 97) * 0.731 + 3.0, skc)
		_neb_mat.set_shader_parameter("t0", _bake.field0)
		_neb_mat.set_shader_parameter("t1", _bake.field1)
		_neb_mat.set_shader_parameter("t2", _bake.field2)
		_neb_mat.set_shader_parameter("ftex", Vector2(SkyBakeS.FIELD_W, SkyBakeS.FIELD_H))
		_neb_mat.set_shader_parameter("fmb", float(SkyBakeS.FIELD_MB))
		_neb_mat.set_shader_parameter("cc_em", skc)
		if painted:
			# PAINTED's cloud built as B's (Jon: "fluffy and full and connected")
			await SectorPaintedS.bake_puffs(self, _bake.field0)
		_neb_mat.set_shader_parameter("bubble_r", bubble_r)
		_neb_mat.set_shader_parameter("star_light", star_light())
		# the sky's own glow round the star is the cloud's light now
		_sky_mat.set_shader_parameter("light_k", 0.0)
	# STAR B'S GLOW ON THE SKY AND ITS LIGHT ON THE CLOUD (`_step_twin_sky`): how
	# bright it is against star A, 0 with one sun (the shaders then add nothing)
	_sky_mat.set_shader_parameter("star2_k", star2_light_k())
	# (its glow in its own warmer colour, as its SunView's and the palette's steps)
	_sky_mat.set_shader_parameter("star2_col", STAR_B_COL)
	if _neb_mat != null:
		_neb_mat.set_shader_parameter("star2_k", star2_light_k())
	_palette_mat.set_shader_parameter("x0", 0.0)
	_shadow_mat.set_shader_parameter("x0", 0.0)
	_twinkle.stars = _bake.twinkle
	_field_off()
	_ready_sky = true


## The far sky the field draws instead, not drawn here.
func _field_off() -> void:
	if not field_under:
		return
	for f: Variant in _fields:
		if is_instance_valid(f):
			(f as CanvasItem).visible = false
	for c: Variant in [_twinkle, _galaxies]:
		if c != null and is_instance_valid(c):
			(c as CanvasItem).visible = false


## A shader setting on every material under `n` (a star's box, its web, its lens).
func _set_deep(n: Node, key: String, value: Variant) -> void:
	if n is CanvasItem and (n as CanvasItem).material is ShaderMaterial:
		((n as CanvasItem).material as ShaderMaterial).set_shader_parameter(key, value)
	for c in n.get_children():
		_set_deep(c, key, value)


## THE STAR'S FACTS, by kind, for the panel and the hover tip.
const STAR_FACTS := {
	"ORDINARY": {"kind": "YELLOW DWARF", "cls": "G2", "temp": "5,700 K", "mass": "1.0 SOL", "radius": "1.0 SOL"},
	"RED": {"kind": "RED HYPERGIANT", "cls": "M4 IA", "temp": "3,500 K", "mass": "28 SOL", "radius": "1,400 SOL"},
	"BLUE": {"kind": "BLUE HYPERGIANT", "cls": "B0 IA", "temp": "24,000 K", "mass": "40 SOL", "radius": "60 SOL"},
	"PULSAR": {"kind": "NEUTRON STAR", "cls": "PULSAR", "temp": "600,000 K", "mass": "1.4 SOL", "radius": "11 KM"},
	"CORE": {"kind": "SUPERMASSIVE BLACK HOLE", "cls": "NONE", "temp": "THREE KELVIN", "mass": "4 MILLION SOL", "radius": "12 MILLION KM"},
}
const ATMOS := {&"eyeball": "N2 CO2", &"hotjup": "H2 HE, SEARING", &"cracked": "SO2, THIN", &"carbonA": "NONE", &"carbonB": "CO CH4, SMOG", &"carbonC": "NONE", &"hurricane": "N2 O2, STORMY", &"haze": "N2 CH4, THICK SMOG", &"volcanic": "SO2, ASH", &"biolum": "N2 O2 CH4", &"megacity": "N2 O2, FILTERED", &"shattered": "NONE", &"scorched": "NONE", &"rogue": "FROZEN OUT", &"aurora": "N2 O2", &"lightning": "N2 H2O, STORMS", &"comet": "H2 HE, ESCAPING", &"europa": "NONE", &"swamp": "N2 CH4, HUMID", &"rock": "NONE", &"moon": "NONE", &"desert": "THIN CO2", &"iron": "THIN CO2", &"ice": "THIN N2", &"lava": "SO2, THICK", &"verdant": "N2 O2", &"ocean": "N2 O2, HUMID", &"toxic": "CH4 SO2, TOXIC", &"city": "N2 O2, FILTERED", &"crystal": "TRACE ARGON", &"banded": "H2 HE", &"icegiant": "H2 HE CH4", &"storm": "H2 HE NH3", &"violet": "H2 HE, UNKNOWN"}
const WATER := {&"eyeball": "TWILIGHT SEA", &"hurricane": "GLOBAL OCEAN", &"europa": "UNDER THE ICE", &"swamp": "MARSH", &"aurora": "SEAS", &"biolum": "SEAS", &"carbonB": "TAR SEAS", &"megacity": "RECLAIMED", &"verdant": "SEAS", &"ocean": "GLOBAL OCEAN", &"ice": "FROZEN", &"city": "RECLAIMED", &"moon": "TRACE ICE"}


func star_name() -> String:
	return MapGen.star_name(node)


func star_class() -> String:
	return STAR_FACTS[kind].kind


## Star B reads as a K5 orange dwarf of 0.7 SOL, fitted to its drawn colour (Jon, Nov 1).
## Why: docs/why/SystemView.md#star-b-facts
const STAR_B_FACTS := {"kind": "ORANGE DWARF", "cls": "K5", "temp": "4,400 K", "mass": "0.7 SOL", "radius": "0.7 SOL"}


## Pair star facts change the words only: A reads as G2, B as K5; pull and drawing are unchanged.
## Why: docs/why/SystemView.md#star-b-facts
static func star_facts_of(L: SystemLayout, kind_name: String, p: int) -> Dictionary:
	var f: Dictionary = STAR_FACTS[kind_name]
	if L == null or not L.twin or p != SystemLayout.STAR_B:
		return f
	var out: Dictionary = f.duplicate()
	out.merge(STAR_B_FACTS, true)
	return out


func body_kind(b: SystemLayout.Body) -> String:
	if b.world != &"":
		return Worlds.display_name(b.world)
	return {&"belt": "ASTEROID BELT", &"derelict": "DERELICT HULK", &"contact": "CONTACT", &"station": "STATION"}.get(b.kind, "")


static func au(b: SystemLayout.Body) -> String:
	return "%.1f AU" % (b.orbit / 80.0)


## The binary panel names the centre BOTH STARS (Jon, Nov 1: call it Binary).
## Why: docs/why/SystemView.md#star-b-facts
func host_line(b: SystemLayout.Body) -> String:
	if layout == null or not layout.twin:
		return ""
	if b.host_id == SystemLayout.STAR_B:
		return "%s B" % star_name()
	if b.host_id == -1:
		return "%s A" % star_name()
	return "BOTH STARS"


## The label of that row. It was ROUND: the game's words say "around", never
## "round" in that sense (the encounter-prose rule for all player text, Nov 1).
const HOST_KEY := "AROUND"


## A body's facts for the panel: [label, value] rows. In a twin the ORBIT row is
## followed by AROUND, the star (or both) it circles (`host_line`).
func facts(b: SystemLayout.Body) -> Array:
	var rows := _facts(b)
	var hl := host_line(b)
	if hl != "":
		for k in rows.size():
			if String(rows[k][0]) == "ORBIT":
				rows.insert(k + 1, [HOST_KEY, hl])
				break
	return rows


func _facts(b: SystemLayout.Body) -> Array:
	match b.kind:
		&"belt":
			return [["TYPE", "ASTEROID BELT"], ["MADE OF", b.comp], ["WIDTH", "%.1f AU" % (b.orbit * 0.004)], ["ORBIT", au(b)], ["BEACONS", str(b.beacons.size())]]
		&"station":
			return [["TYPE", "STATION"], ["HELD BY", MapGen.place_line(node).split(" - ")[0]], ["ORBIT", au(b)]]
		&"derelict":
			return [["TYPE", "DERELICT HULK"], ["MASS", "40,000 T"], ["POWER", "NONE"], ["ORBIT", au(b)]]
		&"contact":
			return [["TYPE", "CONTACT"], ["SIGNATURE", "HOT"], ["ORBIT", au(b)]]
	var w := b.world
	var giant: bool = Worlds.WORLD[w].get("giant", false)
	var heat: float = {"ORDINARY": 1.0, "RED": 1.3, "BLUE": 2.2, "PULSAR": 0.6, "CORE": 0.2}[kind] / (0.3 + b.zone * 0.75)
	var temp := "SCORCHED" if heat > 2.2 else ("HOT" if heat > 1.4 else ("TEMPERATE" if heat > 0.9 else ("COLD" if heat > 0.6 else ("FROZEN" if heat > 0.35 else "DEEP FREEZE"))))
	if w == &"lava":
		temp = "SCORCHED"
	var grav := (1.6 + b.r * 0.12) if giant else (0.1 + b.r * 0.11)
	var v: Node2D = _views.get(b.index)
	var spec: Dictionary = v.get("spec") if v != null else {}
	var spin: float = spec.get("spin", 0.05)
	var day := roundi(22.0 * 0.055 / maxf(0.0001, absf(spin)))
	var fauna := ("MEGAFAUNA" if node.fauna else "PRESENT") if (w == &"verdant" or w == &"ocean") else "NONE"
	return [["TYPE", Worlds.display_name(w)], ["GRAVITY", "%.2f G" % grav], ["TEMPERATURE", temp], ["ATMOSPHERE", ATMOS.get(w, "NONE")],
		["WATER", WATER.get(w, "NONE")], ["FAUNA", fauna], ["MOONS", str(spec.get("moons", 0))],
		["DAY", ("LOCKED" if spin == 0.0 else "%d H%s" % [day, ", BACKWARD" if spin < 0.0 else ""])], ["ORBIT", au(b)]]


## How big a body is drawn: a world at least `min_r`, anything else as laid out.
func world_r(b: SystemLayout.Body) -> float:
	if b.world == &"":
		return b.r
	# ROUND A PULSAR the worlds are wreckage, and its light is the biggest thing
	# there (Jon: "the planet looks bigger than the pulsar itself"): drawn smaller
	if layout != null and layout.star == SystemLayout.StarKind.PULSAR:
		return maxf(b.r, min_r) * PULSAR_WORLD_K
	return maxf(b.r, min_r)


## Static so a harness (`WowClip`) can film the map without glints and the near half.
static var belt_glints := true
static var orbit_depth := true
## How big a pulsar's worlds are drawn against any other system's.
const PULSAR_WORLD_K := 0.45
## the zoom the map opened at (the screen sets it): a pulsar's remnant shell is
## the size it was baked at there, and zooms with the map from it
var home_zoom := 1.0


## Zoomed out a world would be a speck, so it keeps a few pixels of disc, redrawn and not stretched.
const MIN_SCREEN_R := 5.0
const MIN_SCREEN_R_GIANT := 7.0
## the star's eased floor of screen radius (px)
const STAR_FLOOR := 10.0


## How big a world is drawn on screen now.
func draw_r(b: SystemLayout.Body) -> float:
	if b.world == &"":
		return b.r * zoom
	if _live.has(b.index):
		return float(_live[b.index][0])
	if _rq.has(b.index):
		return _rq[b.index]
	return _draw_r_raw(b)


func _draw_r_raw(b: SystemLayout.Body) -> float:
	return maxf(world_r(b) * zoom, MIN_SCREEN_R_GIANT if b.kind == &"giant" else MIN_SCREEN_R)


## A size held in whole blocks: `held` until `raw` is HOLD_PX from it, then the
## nearest whole block (never under `least`).
static func _held(raw: float, held: float, least: float) -> float:
	if held > 0.0 and absf(raw - held) <= HOLD_PX:
		return held
	return maxf(roundf(raw / 2.0) * 2.0, ceilf(least / 2.0) * 2.0)


## Star scale is the zoom floored to a few pixels of disc; the black hole's trace needs zoom 1.
func star_k() -> float:
	if layout != null and layout.star == SystemLayout.StarKind.PULSAR:
		return PULSAR_OPEN_K * zoom / maxf(home_zoom, 0.01)
	if _klive > 0.0:
		return _klive
	if _kq > 0.0:
		return _kq
	return _star_k_raw()


## The zoom has moved within SETTLE_S: draw everything at its true size and place.
func zooming() -> bool:
	return _zstill < SETTLE_S


## Where world i's picture is centred now (its live centre, or its box's on the grid).
func world_c(i: int) -> Vector2:
	if _live.has(i):
		return _live[i][1]
	var b := layout.bodies[i]
	return at[i] + Vector2.ONE * float(Worlds.half_size(b.world, draw_r(b)) % 2)


## For the harnesses (`panclip`): the picture's offset from its grid place, 0 at rest.
func world_lag(i: int) -> Vector2:
	if not _live.has(i):
		return Vector2.ZERO
	var b := layout.bodies[i]
	var held: float = _rq.get(i, draw_r(b))
	return (_live[i][1] as Vector2) - (at[i] + Vector2.ONE * float(Worlds.half_size(b.world, held) % 2))


## A pulsar scales exactly with the zoom: block-held sizing made it sit still, then jump.
## Why: docs/why/SystemView.md#pulsar
const PULSAR_OPEN_K := 4.0 / 3.0


func _star_k_raw() -> float:
	return _star_k_raw_of(-1)


## True size before block holding; in a twin it is capped by `twin_floor`.
func _star_k_raw_of(p: int) -> float:
	if layout != null and layout.star == SystemLayout.StarKind.CORE:
		return maxf(zoom, 1.0)
	var sr := maxf(layout.star_radius(p) if layout != null else 16.0, 1.0)
	var k := sun_raw_k(sr, zoom)
	if twin_floor_on():
		k = minf(k, sun_raw_k(sr, layout.fit_zoom) * zoom / layout.fit_zoom)
	return k


## A sun of radius `sr` at zoom `z`: how many times its size it is drawn.
static func sun_raw_k(sr: float, z: float) -> float:
	# The floor eases the star up: held at 7 px it read as one more star at opening zoom.
	return maxf(z, sqrt(pow(sr * z, 2.0) + STAR_FLOOR * STAR_FLOOR) / sr)


## Below `fit_zoom` a twin sun's plane radius is capped, or rings drew inside their suns.
## Why: docs/why/SystemView.md#twin-sun-floor
func twin_floor_on() -> bool:
	return layout != null and layout.twin and layout.fit_zoom > 0.0 and zoom < layout.fit_zoom


## The largest held radius (game px) star p's disc may have now: INF but below
## a twin's fit (`twin_floor_on`).
func _held_cap(p: int) -> float:
	if not twin_floor_on():
		return INF
	return twin_held_cap(layout.star_radius(p), zoom, layout.fit_zoom)


## (static, for a harness to measure the drawing without a view)
static func twin_held_cap(sr: float, z: float, fz: float) -> float:
	var at_fit := maxf(roundf(sr * sun_raw_k(sr, fz) / 2.0) * 2.0, 2.0)
	return maxf(floorf(at_fit * z / fz / 2.0) * 2.0, 2.0)


## Star p's size factor as drawn now (star A: `star_k`).
func star_k_of(p: int) -> float:
	if p != SystemLayout.STAR_B:
		return star_k()
	if _klive2 > 0.0:
		return _klive2
	if _kq2 > 0.0:
		return _kq2
	return _star_k_raw_of(p)


## With two suns each sits where the pair has it at `t` (ruling 23), so star A leaves the origin.
func star_screen(p: int) -> Vector2:
	if layout == null or not layout.twin:
		return origin()
	var q := layout.star_pos(p, t)
	return block_round(screen(q.x, q.y))


## Off the block grid on purpose: a rounded place made the light flicker on every block hop.
func star_exact(p: int) -> Vector2:
	if layout == null or not layout.twin:
		return Vector2(CX, CY) + pan
	var q := layout.star_pos(p, t)
	return screen(q.x, q.y)


## In a twin the sky is baked round the balance point, since the gas holds still as the suns turn.
## Why: docs/why/SystemView.md#sky-centre
func sky_c() -> Vector2:
	var c := Vector2(CX, CY)
	if layout == null or not layout.twin:
		return c
	return (c + Vector2(layout.bary.x, layout.bary.y * TILT) * SystemLayout.open_zoom(layout.edge)).round()


## Star p's disc as drawn, its radius on screen (px): what hides a world behind
## it, stops the orbit lines and clears the fabric.
func star_disc(p: int) -> float:
	if layout == null:
		return 0.0
	return layout.star_radius(p) * star_k_of(p)


## How near the viewer star p is (`depth`): its own z where the pair has it at
## the map's t (one sun: 0).
func star_depth(p: int) -> float:
	return layout.star_pos(p, t).y if layout != null else 0.0


## Star B is rolled from its own seed, smaller and warmer (`SunView.setup`'s `second`).
func sun_setup(sv: Node2D, p: int, r: float) -> void:
	sv.call("setup", kind, node.index, r, p == SystemLayout.STAR_B)


## A pulsar block hop made every layer lead or lag the map, so the drawing shifts within the block.
## Why: docs/why/SystemView.md#pulsar
func _pulsar_at(o: Vector2, ez: float) -> Vector2:
	var tc: Vector2 = Vector2(CX, CY) + pan if zooming() and not _nosmooth else o
	if _plive.x == INF or zooming() or _nosmooth:
		_plive = tc
	else:
		_plive += o - _plast
		_plive = tc if _plive.distance_to(tc) < 0.02 else _plive.lerp(tc, ez)
	_plast = o
	return _plive


## How near the viewer a point on the plane is: what draws in front.
static func depth(p: Vector2) -> float:
	return p.y


## Where the star is on screen.
func origin() -> Vector2:
	return block_round(Vector2(CX, CY) + pan)


## How far the sky has slid.
func sky_off() -> Vector2:
	return block((_cam_pan() * PARALLAX).clamp(-Vector2.ONE * SkyBakeS.M, Vector2.ONE * SkyBakeS.M))


## The pan as the sky sees it: where the camera looks on the plane, in the
## screen pixels it would be at PARALLAX_AT -- unchanged by zooming.
func _cam_pan() -> Vector2:
	return pan / maxf(zoom, 0.01) * PARALLAX_AT


## A point on the place's grid of 2x2 blocks.
static func block(p: Vector2) -> Vector2:
	return (p / 2.0).floor() * 2.0


## The nearest point on it.
static func block_round(p: Vector2) -> Vector2:
	return (p / 2.0).round() * 2.0


## Round once, by the caller: rounding twice made a followed world shake by a pixel.
## Why: docs/why/SystemView.md#screen-rounding
func screen(x: float, z: float, dip: float = 0.0) -> Vector2:
	return Vector2(CX, CY) + pan + Vector2(x, z * TILT + dip) * zoom


## How much of the star's light reaches a point on the plane.
static func light_at(x: float, z: float) -> float:
	return 1.0 / (1.0 + (x * x + z * z) / (160.0 * 160.0))


## The light on a body at plane position p: from the star, in screen x, y, z.
static func light_for(p: Vector2) -> Vector3:
	var len := maxf(p.length(), 1.0)
	return Vector3(-p.x / len, -p.y / len * TILT, -p.y / len * 0.5 + 0.42).normalized()


## A world keeps one light, the weighted sum of both suns, so planet shaders keep their interface.
## Why: docs/why/SystemView.md#twin-light
func star_lum(p: int) -> float:
	return star_lum_of(layout, p)


static func star_lum_of(L: SystemLayout, p: int) -> float:
	if L == null or p != SystemLayout.STAR_B:
		return 1.0
	return pow(L.star2_r / float(SystemLayout.STAR_R[SystemLayout.StarKind.ORDINARY]), 2.0)


## How much light reaches plane point (x, z): `light_at`, and with two suns each
## star's by its own distance and brightness, held to 1.
func light_here(x: float, z: float) -> float:
	return light_here_of(layout, x, z, t)


## `t` is required so no caller reads the suns at a moment it never chose (ruling 23).
static func light_here_of(L: SystemLayout, x: float, z: float, t: float) -> float:
	if L == null or not L.twin:
		return light_at(x, z)
	var a := L.star_pos(-1, t)
	var b := L.star_pos(SystemLayout.STAR_B, t)
	return minf(1.0, light_at(x - a.x, z - a.y) + star_lum_of(L, SystemLayout.STAR_B) * light_at(x - b.x, z - b.y))


## Star B's share of the light at plane point p (0 with one sun): its brightness
## over the distance squared against both stars'.
func share_b(p: Vector2) -> float:
	return share_b_of(layout, p, t)


static func share_b_of(L: SystemLayout, p: Vector2, t: float) -> float:
	if L == null or not L.twin:
		return 0.0
	var wa := 1.0 / (p.distance_squared_to(L.star_pos(-1, t)) + 400.0)
	var wb := star_lum_of(L, SystemLayout.STAR_B) / (p.distance_squared_to(L.star_pos(SystemLayout.STAR_B, t)) + 400.0)
	return wb / (wa + wb)


## The one light on a body at plane point p (`light_for`): with two suns, toward
## each star by its share of the light there.
func light_for_at(p: Vector2) -> Vector3:
	if layout == null or not layout.twin:
		return light_for(p)
	var u := toward_light_of(layout, p, t)
	return Vector3(u.x, u.y * TILT, u.y * 0.5 + 0.42).normalized()


## Toward star A with one sun; with two, toward each by its share, posed at `t`.
static func toward_light_of(L: SystemLayout, p: Vector2, t: float) -> Vector2:
	if L == null or not L.twin:
		return -p / maxf(p.length(), 1.0)
	var sa := L.star_pos(-1, t)
	var sbp := L.star_pos(SystemLayout.STAR_B, t)
	var da := (sa - p) / maxf(p.distance_to(sa), 1.0)
	var sb := share_b_of(L, p, t)
	var db := (sbp - p) / maxf(p.distance_to(sbp), 1.0)
	var u := da * (1.0 - sb) + db * sb
	# (between the two, the pull of each nearly cancelling: lit from the brighter)
	if u.length() < 1e-3:
		return da if sb < 0.5 else db
	return u.normalized()


## `toward_light_of` for this system (for the weather, which holds the view
## untyped).
func toward_light(p: Vector2) -> Vector2:
	return toward_light_of(layout, p, t)


## Where a body at plane point p is lit from on screen: a point toward its light
## (the shadows' and the moons' source), `o` with one sun.
func light_screen(p: Vector2, at_s: Vector2) -> Vector2:
	if layout == null or not layout.twin:
		return origin()
	var u := toward_light_of(layout, p, t)
	var ds := Vector2(u.x, u.y * TILT)
	return at_s + ds / maxf(ds.length(), 1e-3) * 400.0


## The tint of the light on a body at plane point p: the star's (`_tint`), and
## with two suns star A's and B's by their shares there.
func tint_at(p: Vector2) -> Vector3:
	if layout == null or not layout.twin:
		return _tint
	return _tint.lerp(_tint2, share_b(p))


## How bright star B is against star A on the sky and the cloud (0 alone).
func star2_light_k() -> float:
	if layout == null or not layout.twin:
		return 0.0
	return star_lum(SystemLayout.STAR_B)


## A colour as light, its brightest channel 1 (`star_light`'s rule).
static func _lin_top(c: Vector3) -> Vector3:
	var l := Vector3(pow(c.x, 2.2), pow(c.y, 2.2), pow(c.z, 2.2))
	return l / maxf(l.x, maxf(l.y, l.z))


## RADIANT's sun flares on the map: glow, haze and the worlds' day sides swell (Nov 7, B).
## Why: docs/why/SystemView.md#radiant-flares
const SECTOR_FLARE_R := 200.0
const SECTOR_FLARE_GAIN := 0.9
func _radiant_flares() -> void:
	if not radiant or layout.star == SystemLayout.StarKind.PULSAR or layout.star == SystemLayout.StarKind.CORE:
		return
	_flare = maxf(_flare, ChartRadiant.sun_flare(pose(t, 6.0)))
	if star2 != null:
		_flare2 = maxf(_flare2, ChartRadiant.sun_flare(pose(t + STAR_B_PROM, 6.0), 7))
	if star != null:
		var sm: ShaderMaterial = star.get("_mat")
		if sm != null:
			sm.set_shader_parameter("r_flare", _flare)
	if star2 != null:
		var sm2: ShaderMaterial = star2.get("_mat")
		if sm2 != null:
			sm2.set_shader_parameter("r_flare", _flare2)
	if _sky_mat != null:
		_sky_mat.set_shader_parameter("r_flare", _flare)
	# (through the palette's pass every frame: the cloud's own `r_flare` updates too rarely)
	if _palette_mat != null:
		_palette_mat.set_shader_parameter("r_lift", Vector4(star_exact(-1).x, star_exact(-1).y, SECTOR_FLARE_R, SECTOR_FLARE_GAIN * _flare))
		var sl := star_light()
		var mx := maxf(sl.x, maxf(sl.y, sl.z))
		_palette_mat.set_shader_parameter("r_lift_c", (sl / maxf(mx, 1e-4)).lerp(Vector3.ONE, 0.35))


## If this machine cannot hold RADIANT's GPU budget, later maps fall back to SIMPLIFIED.
## Why: docs/why/SystemView.md#radiant-safety
var _rprobe := {}


func _radiant_safety() -> void:
	if _rprobe.has("done") or _scene == null:
		return
	var f: int = int(_rprobe.get("frames", 0)) + 1
	_rprobe.frames = f
	var rid := _scene.get_viewport_rid()
	if f == 1:
		RenderingServer.viewport_set_measure_render_time(rid, true)
		return
	if f < 12:
		return
	_rprobe.gpu = float(_rprobe.get("gpu", 0.0)) + RenderingServer.viewport_get_measured_render_time_gpu(rid)
	_rprobe.n = int(_rprobe.get("n", 0)) + 1
	if int(_rprobe.n) < ChartRadiant.PROBE_FRAMES:
		return
	_rprobe["done"] = true
	var avg := float(_rprobe.gpu) / float(_rprobe.n)
	_rprobe["avg_ms"] = avg
	print_verbose("RADIANT the sector map's GPU time: %.2f ms a frame over %d frames" % [avg, int(_rprobe.n)])
	if avg > ChartRadiant.budget_ms() and ((DisplaySettings.render_style == STYLE_RADIANT and not DisplaySettings.harness_style()) 			or ChartRadiant.probe_forced()):
		push_warning("RADIANT sector measured %.1f ms a frame on this machine; drawing SIMPLIFIED" % avg)
		Run.log_line("RADIANT is too heavy for this machine, so the sector map is drawn SIMPLIFIED.", &"them")
		# Fall back from the next picture: switching under a still view changed its brightness.
		# Why: docs/why/SystemView.md#radiant-safety
		ChartRadiant.fell_back = true
		DisplaySettings.fall_back_style(STYLE_SIMPLIFIED)


## SIMPLIFIED is the default; PAINTED and RADIANT are the others (`DisplaySettings.STYLES`).
static func style() -> StringName:
	return DisplaySettings.render_style


## The style can also come from a harness's `-- style=` argument.
static func is_radiant() -> bool:
	# (not once the safety has fallen back this session: the chart's and the
	# sector's share it, `ChartRadiant.fell_back`)
	if ChartRadiant.fell_back:
		return false
	return style() == STYLE_RADIANT or "style=radiant" in OS.get_cmdline_user_args()


static func is_painted() -> bool:
	return style() == STYLE_PAINTED or "style=painted" in OS.get_cmdline_user_args()


## PAINTED steps its clock in poses, as an animator draws on twos and threes.
func pose(x: float, fps: float = 8.0) -> float:
	return floor(x * fps) / fps if painted else x


## Graphics low is the cheaper sky, read every frame for the sky and at entry for the sheets.
static func gfx_low() -> bool:
	return DisplaySettings.graphics_low


## THE SUN BREATHES (C): its corona's radius 1 +- 0.06 on a slow noise, the
## light near it with it; held still with reduced motion.
static func breath(time: float) -> float:
	if DisplaySettings.reduced_motion:
		return 1.0
	var n := 0.6 * sin(time / 8.0 * 2.31 + 1.0) + 0.4 * sin(time / 8.0 * 5.17 + 2.0)
	return 1.0 + 0.06 * n


## One prominence per 40 s slot at a hashed moment; none with reduced motion.
static func prominence(time: float) -> Vector4:
	if DisplaySettings.reduced_motion:
		return Vector4.ZERO
	var best := Vector4.ZERO
	var n := floori(time / 40.0)
	for k in [n - 1, n]:
		if k < 0:
			continue
		var u: float = time - (40.0 * k + 6.0 + SkyBakeS.hash2(k, 11) * 14.0)
		if u < 0.0 or u > 19.0:
			continue
		var e := smoothstep(0.0, 4.0, u) if u < 4.0 else (1.0 if u < 7.0 else 1.0 - smoothstep(7.0, 19.0, u))
		if e > best.z:
			best = Vector4(-PI * (0.15 + 0.7 * SkyBakeS.hash2(k, 12)), (0.75 + 0.6 * SkyBakeS.hash2(k, 13)) * e, e, 0.55 + 0.40 * SkyBakeS.hash2(k, 14))
	return best


## Caught fast and let go over a third of a second, so a sweep reads as light, not a strobe.
func beam_on(d: Vector2, key: Variant = null) -> float:
	var ang: float = star.get("beam_angle") if star != null else NAN
	var k := 0.0
	if not is_nan(ang) and d.length() > 1.0:
		var a := atan2(d.y, d.x)
		var da := minf(absf(wrapf(a - ang, -PI, PI)), absf(wrapf(a - ang - PI, -PI, PI)))
		k = exp(-pow(da / 0.18, 2.0))
	if key == null:
		return k
	var was: float = _beam_k.get(key, 0.0)
	var held := maxf(k, was * exp(-get_process_delta_time() / 0.33))
	_beam_k[key] = held
	return held


## Night-side sky light on a world, by cloud kind, stronger nearer the sun.
func night_fill(p: Vector2) -> Vector3:
	# (from star A where the pair has it now: the plane's origin with one sun)
	var pa := p - layout.star_pos(-1, t)
	var s := Vector2(pa.x, pa.y * TILT * 1.15) * zoom
	var lz := pow(maxf(zoom, 0.01) / maxf(home_zoom, 0.01), 0.42) * clampf(window.size.x / 700.0, 0.5, 1.4)
	var dl := s.length() / maxf(lz, 0.01)
	var js := 1.0 / (1.0 + pow(dl / 155.0, 2.0))
	if layout.twin:
		# (two suns: star B's light on the gas round it too, by its brightness)
		var q := p - layout.star_pos(SystemLayout.STAR_B, t)
		var dl2 := (Vector2(q.x, q.y * TILT * 1.15) * zoom).length() / maxf(lz, 0.01)
		js = minf(1.0, js + star_lum(SystemLayout.STAR_B) / (1.0 + pow(dl2 / 155.0, 2.0)))
	if layout.star == SystemLayout.StarKind.PULSAR:
		return Vector3(0.03, 0.05, 0.10) * (0.3 + js)
	if layout.star == SystemLayout.StarKind.CORE:
		return Vector3(0.10, 0.04, 0.015) * (0.3 + js)
	if _neb_mat == null:
		return Vector3(0.006, 0.006, 0.010)
	var h: Vector3 = _sky_look.get("hue", Vector3(0.5, 0.5, 0.6))
	var hl := Vector3(pow(h.x, 2.2), pow(h.y, 2.2), pow(h.z, 2.2))
	match int(_sky_look.neb):
		NebulaField.Kind.EMISSION:
			# The wall radius is in light px, so its plane radius grows as the map zooms in.
			if (p - bubble_c()).length() * zoom < bubble_r * home_zoom * pow(maxf(zoom, 0.001) / maxf(home_zoom, 0.001), 0.42):
				return Vector3(0.2, 0.95, 0.85) * 0.30 * js + Vector3(1.0, 0.2, 0.3) * 0.015
			return Vector3(1.0, 0.2, 0.3) * 0.07 * (0.5 + js)
		NebulaField.Kind.REFLECTION:
			return Vector3(0.32, 0.52, 1.0) * 0.07 * (0.4 + js * 1.3)
		NebulaField.Kind.DARK:
			return Vector3(0.03, 0.02, 0.04)
	return hl * 0.07 * (0.5 + js)


## The star's light in linear colour, its brightest channel 1: what it lights
## the cloud, the dust and the worlds with.
func star_light() -> Vector3:
	var c: Vector3 = SkyBakeS.STARCOL.get(kind, SkyBakeS.STARCOL.ORDINARY)
	var l := Vector3(pow(c.x, 2.2), pow(c.y, 2.2), pow(c.z, 2.2))
	return l / maxf(l.x, maxf(l.y, l.z))


## The bubble sits in an orbit gap no world stands on, so the rose cloud round it is in view.
func _bubble_r() -> float:
	var E := layout.edge
	# where it should be: about four fifths of the way to the frame's edge at the
	# opening zoom (which fits the edge, plus 20, into the frame's width)
	var want := 0.8 * (E + 20.0)
	if layout.twin:
		return bubble_gap(layout, want, bubble_c())
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
	return best


## In a twin the bubble centres on the balance point: the cavity is the pair's and holds still.
func bubble_c() -> Vector2:
	return layout.bary if layout != null and layout.twin else Vector2.ZERO


## The bubble's centre on screen, exact (`bubble_c`; one sun: star A's exact
## place, `star_exact(-1)`, as the cloud's bubble always sat).
func bubble_exact() -> Vector2:
	if layout == null or not layout.twin:
		return Vector2(CX, CY) + pan
	return screen(layout.bary.x, layout.bary.y)


## A body circling star B sweeps a band of distances, so the gap is sought between merged bands.
## Why: docs/why/SystemView.md#bubble-gap
static func bubble_gap(L: SystemLayout, want: float, centre := Vector2.ZERO) -> float:
	var bands: Array = [[0.0, 0.0]]
	# Distances use bodies at t 0, as the pair turns rigidly and they hold at every t.
	for b in L.bodies:
		var h := (b.host0 - centre).length()
		var w := 28.0 if b.kind == &"belt" else 0.0
		bands.append([maxf(0.0, absf(h - b.orbit) - w), h + b.orbit + w])
	# Each sun's disc sits in the band of its distance from the centre, at t 0.
	for p: int in L.stars():
		var d := (L.star_pos(p, 0.0) - centre).length()
		bands.append([d, d])
	bands.append([L.edge + centre.length() + 400.0, L.edge + centre.length() + 400.0])
	bands.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	var best := want
	var bd := INF
	var reach := float(bands[0][1])
	for i in range(1, bands.size()):
		var lo := reach + 24.0
		var hi := float(bands[i][0]) - 24.0
		reach = maxf(reach, float(bands[i][1]))
		if hi <= lo:
			continue
		var at := clampf(want, lo, hi)
		if absf(at - want) < bd:
			bd = absf(at - want)
			best = at
	return best


## The star's colour on things near it; things far from it darker. (Two suns:
## by the light of both, `light_here`; one sun, `light_at` itself.)
func tone(x: float, z: float, base: Vector3) -> Vector3:
	var k := light_here(x, z)
	var dim := base.lerp(Vector3(base.x * 0.55, base.y * 0.55, base.z * 0.6), 1.0 - minf(1.0, k * 2.2))
	return dim.lerp(SkyBakeS.STARCOL.get(kind, Vector3.ONE), k * 0.45)


func _step_bodies() -> void:
	pos.clear()
	at.clear()
	for b in layout.bodies:
		var p := b.pos(t)
		pos.append(p)
		# ON THE BLOCK GRID: an odd position is half a pixel of the half-size
		# picture, and a world sliding over it as the map zooms flickered
		at.append(block_round(screen(p.x, p.y)))


func _process(_delta: float) -> void:
	step()


## The star's clock, and what the pulsar's beam does to the sky.
func _step_star() -> void:
	if star == null:
		return
	if layout.star != SystemLayout.StarKind.PULSAR:
		# (PAINTED: the star and the hole drawn in held poses, a few a second)
		star.call("step", pose(t, 4.0 if layout.star != SystemLayout.StarKind.CORE else 8.0))
		if layout.star != SystemLayout.StarKind.CORE:
			# ALIVE: the corona breathes, and now and then a prominence erupts
			var sm: ShaderMaterial = star.get("_mat")
			sm.set_shader_parameter("c_breath", breath(pose(t, 4.0)))
			sm.set_shader_parameter("c_prom", prominence(pose(t, 6.0)))
			sm.set_shader_parameter("halo_cut", 72.0)
		if star2 != null:
			# Star B runs `STAR_B_PROM` s behind A so the suns are never at their height together.
			star2.call("step", pose(t, 4.0))
			var sm2: ShaderMaterial = star2.get("_mat")
			sm2.set_shader_parameter("c_breath", breath(pose(t, 4.0) + STAR_B_PROM))
			sm2.set_shader_parameter("c_prom", prominence(pose(t + STAR_B_PROM, 6.0)))
			sm2.set_shader_parameter("halo_cut", 72.0)
	else:
		# The beam points at you on each pass of `amb_pulsar`; the clock is shifted, never jumped.
		# A harness holding the clock holds the beat too.
		var heard := Audio.room_clock(&"amb_pulsar") if hclock < 0.0 else -1.0
		if heard >= 0.0:
			var loop: float = PulsarViewS.LOOP_S
			_beat_off = beat_follow(_beat_off, wrapf(heard - fposmod(t, loop), -loop / 2.0, loop / 2.0), get_process_delta_time())
		star.call("step", pose(t + _beat_off))
		var ang: float = star.get("beam_angle")
		_sky_mat.set_shader_parameter("beam_on", not is_nan(ang))
		_sky_mat.set_shader_parameter("beam_angle", 0.0 if is_nan(ang) else ang)
		var f: float = star.get("sky_flash")
		_flash.visible = f > 0.0
		_flash.color = Color(PulsarViewS.SKY_FLASH_COLOR.r * f, PulsarViewS.SKY_FLASH_COLOR.g * f, PulsarViewS.SKY_FLASH_COLOR.b * f, 1.0)


## The beat follows the sound over half a second: its per-frame clock wobbled and the beams lurched.
## Why: docs/why/SystemView.md#pulsar-beat
func beat_follow(off: float, want: float, dt: float) -> float:
	var d := wrapf(want - off, -PulsarViewS.LOOP_S / 2.0, PulsarViewS.LOOP_S / 2.0)
	if absf(d) > 0.1:
		return want
	return off + d * (1.0 - exp(-clampf(dt, 0.0, 0.1) / BEAT_FOLLOW_S))


static func headless() -> bool:
	return DisplayServer.get_name() == "headless"


## Add the time since `t0` to part `key` of the profile, when profiling.
static func tick(key: String, t0: int) -> void:
	if prof_on:
		prof[key] = int(prof.get(key, 0)) + Time.get_ticks_usec() - t0


## Dust sheet: [distance, strength, look, cloud size, cover]; `seed_n` is its seed slot.
func _depth_sheet(fd: Array, slot: int, pal: Array, sd: int, seed_n: int = -1) -> ColorRect:
	var r := ColorRect.new()
	r.size = Vector2(960, 540)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = DEPTH
	m.set_shader_parameter("look", int(fd[2]))
	m.set_shader_parameter("size", float(fd[3]))
	m.set_shader_parameter("cover", float(fd[4]))
	m.set_shader_parameter("pal0", pal[0])
	m.set_shader_parameter("pal1", pal[1])
	m.set_shader_parameter("star_col", SkyBakeS.STARCOL.get(kind, SkyBakeS.STARCOL.ORDINARY))
	# a fluff's core lit faintly by the cloud round it, when the sky is the cloud
	if _neb_mat != null and int(_sky_look.neb) != NebulaField.Kind.DARK:
		m.set_shader_parameter("core_lift", (_sky_look.hue as Vector3) * 0.25)
	# SIMPLIFIED: dark cores in the sky's own shade, sides toward the sun lit
	var dl: Array = _depth_look()
	m.set_shader_parameter("painted", painted)
	m.set_shader_parameter("dark_col", dl[0])
	m.set_shader_parameter("lit_far", dl[1])
	m.set_shader_parameter("lit_near", dl[2])
	m.set_shader_parameter("wisp_col", dl[3])
	m.set_shader_parameter("center", Vector2(CX, CY))
	m.set_shader_parameter("seed", float(sd) * 1.37 + float(_depth.size() if seed_n < 0 else seed_n) * 11.3)
	r.material = m
	_depth.append([m, float(fd[0]), slot, float(fd[1]), sd])
	return r


## A clear sky's wisp colour is black, so such a sheet changes no pixel.
func _wisps_blank() -> bool:
	return (_depth_look()[3] as Vector3) == Vector3.ZERO


## Dust sheet colours in SIMPLIFIED follow the sky kind, near nothing in a clear sky.
func _depth_look() -> Array:
	if layout.star == SystemLayout.StarKind.PULSAR:
		return [Vector3(0.02, 0.03, 0.05), Vector3(0.16, 0.20, 0.26), Vector3(0.22, 0.28, 0.36), Vector3(0.06, 0.07, 0.12)]
	if layout.star == SystemLayout.StarKind.CORE:
		return [Vector3(0.05, 0.02, 0.02), Vector3(0.30, 0.18, 0.10), Vector3(0.45, 0.30, 0.16), Vector3(0.14, 0.08, 0.05)]
	if _neb_mat == null:
		# Clear sky sheets only darken and never go below the void, or they showed as black blots.
		return [Vector3(0.027, 0.039, 0.071), Vector3(0.034, 0.044, 0.074), Vector3(0.040, 0.048, 0.078), Vector3(0.0, 0.0, 0.0)]
	match int(_sky_look.neb):
		NebulaField.Kind.EMISSION:
			return [Vector3(0.13, 0.05, 0.09), Vector3(0.46, 0.22, 0.27), Vector3(0.34, 0.50, 0.47), Vector3(0.30, 0.08, 0.12)]
		NebulaField.Kind.REFLECTION:
			return [Vector3(0.07, 0.09, 0.16), Vector3(0.24, 0.32, 0.46), Vector3(0.42, 0.52, 0.66), Vector3(0.10, 0.16, 0.30)]
		NebulaField.Kind.DARK:
			return [Vector3(0.018, 0.014, 0.024), Vector3(0.30, 0.20, 0.14), Vector3(0.62, 0.60, 0.62), Vector3(0.05, 0.04, 0.07)]
	var h: Vector3 = _sky_look.get("hue", Vector3(0.5, 0.5, 0.6))
	return [h * 0.14 + Vector3(0.02, 0.015, 0.03), h * 0.45, h * 0.7, h * 0.18]


## Each sheet is sized and slid by the camera's distance, and faded near it and near the plane.
func _step_depth(_o: Vector2) -> void:
	if _depth.is_empty():
		return
	var D := 1.0 / maxf(zoom, 0.01)
	var kmax := floori(log(0.9 * D / DEPTH_D0) / log(DEPTH_RHO))
	for e: Array in _depth:
		var m: ShaderMaterial = e[0]
		var q := 1.0
		var a := 1.0
		if int(e[2]) < 0:
			q = D / (D + float(e[1]))
		else:
			var k: int = kmax - int(e[2])
			var dl := DEPTH_D0 * pow(DEPTH_RHO, float(k))
			var x := dl / D
			q = D / maxf(D - dl, 0.02 * D)
			# FROM NOTHING TO NOTHING (no pop): a slot takes the next sheet in only
			# where it is invisible -- in at x = 0.9 / RHO^NEAR, out at 0.9
			var x_in := 0.9 / pow(DEPTH_RHO, float(DEPTH_NEAR))
			a = smoothstep(x_in, x_in * 2.2, x) * (1.0 - smoothstep(0.5, 0.9, x))
			m.set_shader_parameter("seed", float(e[4]) * 1.37 + float(k) * 7.31)
		m.set_shader_parameter("q", q)
		m.set_shader_parameter("dist", float(e[1]) if int(e[2]) < 0 else 0.0)
		m.set_shader_parameter("zoom", zoom)
		m.set_shader_parameter("home_zoom", home_zoom)
		m.set_shader_parameter("lscale", clampf(window.size.x / 700.0, 0.5, 1.4))
		m.set_shader_parameter("pan", pan)
		# Sheets stay lit from star A alone: a second light would grow a shader that compiles cold.
		m.set_shader_parameter("star_at", star_exact(-1))
		m.set_shader_parameter("alpha", a)
		m.set_shader_parameter("strength", float(e[3]))


## A supernova now, for a harness (SystemShot and FlightClip `nova`): at a
## point on screen, or anywhere clear of the discs.
func nova_now(at := Vector2.INF) -> void:
	if _nova != null:
		_nova.start(at)


## The system's original weather now, for a harness (SystemShot `wclip`): at a
## point on screen, or anywhere in view.
func weather_now(at := Vector2.INF) -> void:
	if _weather != null:
		_weather.start_default(at)


## Star B's light is set each frame by `star2_light_k`, so one-sun systems add nothing.
func _step_twin_sky() -> void:
	if star2 == null:
		return
	var sb := star_screen(SystemLayout.STAR_B)
	_sky_mat.set_shader_parameter("star2_at", sb)
	if _neb_mat != null:
		_neb_mat.set_shader_parameter("star2_at", star_exact(SystemLayout.STAR_B))
	if painted and not _pt.is_empty():
		var ms: ShaderMaterial = _pt.get("state")
		if ms != null:
			ms.set_shader_parameter("star2_px", sb)
			ms.set_shader_parameter("sun2_r", star_disc(SystemLayout.STAR_B))
		# Silhouettes now face both suns: they faced star A alone, so the rims were wrong.
		# Why: docs/why/SystemView.md#twin-silhouettes
		var mp: ShaderMaterial = _pt.get("paint")
		if mp != null:
			mp.set_shader_parameter("star2_at", star_exact(SystemLayout.STAR_B))
			mp.set_shader_parameter("star2_k", star2_light_k())
			mp.set_shader_parameter("light_lz", paint_light_lz())


## Mirrors `sky_nebula`'s LZ so PAINTED's silhouettes reach as far as the cloud's light.
func paint_light_lz() -> float:
	return pow(maxf(zoom, 1e-3) / maxf(home_zoom, 1e-3), 0.42) * clampf(window.size.x / 700.0, 0.5, 1.4)


## The wall clock the weather and the gas read, or a harness's.
func wclock() -> float:
	return hclock if hclock >= 0.0 else SkyWeatherS.now()


## How far the nebula seen from inside has slid.
func neb_off() -> Vector2:
	return block(_cam_pan() * PARALLAX_NEB)


## Move everything to time `t` (the screen sets `t`).
func step() -> void:
	if painted:
		SectorPaintedS.push(self)
	if radiant:
		_radiant_safety()
	if layout == null:
		return
	var t_step := Time.get_ticks_usec()
	_frame += 1
	_step_bodies()
	# Star A is where the pair has it (ruling 23); a pulsar and the core are never a twin.
	var o := star_screen(-1)
	_flare = prominence(pose(t, 6.0)).z if layout.star != SystemLayout.StarKind.PULSAR and layout.star != SystemLayout.StarKind.CORE else 0.0
	# (two suns: star B's own eruptions, on its clock, for the worlds it lights)
	_flare2 = prominence(pose(t + STAR_B_PROM, 6.0)).z if star2 != null else 0.0
	_radiant_flares()
	if layout.star_r > 0.0 and layout.star != SystemLayout.StarKind.PULSAR:
		var rk := _held(layout.star_r * _star_k_raw(), layout.star_r * _kq, 2.0) / layout.star_r
		if layout.star == SystemLayout.StarKind.CORE:
			rk = maxf(rk, 1.0)
		# (a twin below its fit: never past the block the fit draws it at, scaled)
		_kq = minf(rk, _held_cap(-1) / layout.star_r)
	if star2 != null:
		var r2 := layout.star2_r
		_kq2 = minf(_held(r2 * _star_k_raw_of(SystemLayout.STAR_B), r2 * _kq2, 2.0), _held_cap(SystemLayout.STAR_B)) / r2
	# THE SMOOTH ZOOM: is the zoom moving; the star at its true size while it is
	var dtz := clampf(get_process_delta_time(), 1.0 / 240.0, 0.1)
	if _zlast < 0.0 or absf(zoom - _zlast) > 1e-7:
		_zstill = 0.0 if _zlast >= 0.0 else 1.0
	else:
		_zstill += dtz
	_zlast = zoom
	var ez := 1.0 - exp(-dtz / SETTLE_EASE)
	if layout.star_r > 0.0 and layout.star != SystemLayout.StarKind.PULSAR:
		# Nearest block, not one held back: its limb between blocks flickered with the corona.
		var kt := minf(maxf(roundf(layout.star_r * _star_k_raw() / 2.0) * 2.0, 2.0), _held_cap(-1)) / layout.star_r if zooming() else _kq
		if layout.star == SystemLayout.StarKind.CORE:
			kt = maxf(kt, 1.0)
		if _klive < 0.0 or absf(_klive - kt) < 0.002 * kt:
			_klive = kt
		elif zooming():
			_klive = kt
		else:
			_klive = lerpf(_klive, kt, ez)
		# Corona is true size while zooming, then eases onto the disc; not while a system opens.
		var smooth := zooming() and not _nosmooth and _palette_built
		var kc := _star_k_raw() if smooth else star_k()
		if _kcor < 0.0 or smooth or _nosmooth or not _palette_built or absf(_kcor - kc) < 0.002 * kc:
			_kcor = kc
		else:
			_kcor = lerpf(_kcor, kc, ez)
	if star2 != null:
		# STAR B'S SIZES as star A's: its disc in whole blocks, its corona true
		# while the zoom moves and eased onto the disc once it is still
		var r2 := layout.star2_r
		var kb := minf(maxf(roundf(r2 * _star_k_raw_of(SystemLayout.STAR_B) / 2.0) * 2.0, 2.0), _held_cap(SystemLayout.STAR_B)) / r2 if zooming() else _kq2
		if _klive2 < 0.0 or absf(_klive2 - kb) < 0.002 * kb or zooming():
			_klive2 = kb
		else:
			_klive2 = lerpf(_klive2, kb, ez)
		var smooth2 := zooming() and not _nosmooth and _palette_built
		var kc2 := _star_k_raw_of(SystemLayout.STAR_B) if smooth2 else star_k_of(SystemLayout.STAR_B)
		if _kcor2 < 0.0 or smooth2 or _nosmooth or not _palette_built or absf(_kcor2 - kc2) < 0.002 * kc2:
			_kcor2 = kc2
		else:
			_kcor2 = lerpf(_kcor2, kc2, ez)
	# and each world's radius and centre
	for i: int in _views:
		var bw := layout.bodies[i]
		var raw := _draw_r_raw(bw)
		var held: float = _rq.get(i, raw)
		var cbox: Vector2 = at[i] + Vector2.ONE * float(Worlds.half_size(bw.world, held) % 2)
		var tr := raw if zooming() else held
		var tc := screen(pos[i].x, pos[i].y) if zooming() else cbox
		var lv: Array = _live.get(i, [])
		# (carried with its place: a pan or its orbit moves the picture with the
		# ring the same frame; the zoom's own moves are left to the branches below)
		var al: Vector2 = _at_last.get(i, at[i])
		_at_last[i] = at[i]
		if not lv.is_empty() and not zooming():
			lv = [lv[0], (lv[1] as Vector2) + (at[i] - al)]
		if lv.is_empty():
			lv = [tr, tc]
		elif zooming():
			# (a quarter of a block at a time: moved every frame by a sliver, the
			# surface's fine detail flickered back and forth as it re-rasterised)
			var lr0: float = lv[0]
			var lc0: Vector2 = lv[1]
			lv = [tr if absf(tr - lr0) >= LIVE_Q else lr0, tc if tc.distance_to(lc0) >= LIVE_Q else lc0]
		else:
			var lr: float = lv[0]
			var lc: Vector2 = lv[1]
			lr = tr if absf(lr - tr) < 0.02 else lerpf(lr, tr, ez)
			lc = tc if lc.distance_to(tc) < 0.02 else lc.lerp(tc, ez)
			lv = [lr, lc]
		_live[i] = lv
	# (a harness's `nosmooth`: the old held sizes and nudges, to measure against)
	if _nosmooth:
		_live.clear()
		_klive = -1.0
		_klive2 = -1.0
	_sky_mat.set_shader_parameter("time", pose(t, 4.0))
	# (a pulsar's light and shell, and its whole drawing below, about its own centre)
	var pc := _pulsar_at(o, ez) if layout.star == SystemLayout.StarKind.PULSAR else o
	_sky_mat.set_shader_parameter("star_at", pc)
	# THE STAR'S LIGHT ON THE SKY held too, stepped 3% at a time: its rays and
	# glow, redrawn at every fraction of a zoom, flickered through the palette
	if _sky_z < 0.0 or absf(zoom / _sky_z - 1.0) > 0.03:
		_sky_z = zoom
	_sky_mat.set_shader_parameter("zoom", _sky_z)
	_sky_mat.set_shader_parameter("zk", _sky_z / maxf(home_zoom, 0.01))
	if layout.star == SystemLayout.StarKind.PULSAR:
		_sky_mat.set_shader_parameter("shell_k", zoom / maxf(home_zoom, 0.01))
		# the shell glimmers on each beat (C), still with reduced motion
		var ba := PulsarViewS.beat_age(t + _beat_off)
		_sky_mat.set_shader_parameter("beat", 0.0 if DisplaySettings.reduced_motion else exp(-ba / 0.7) * 0.5)
		_sky_mat.set_shader_parameter("glim_k", 0.0 if DisplaySettings.reduced_motion else 1.0)
		_sky_mat.set_shader_parameter("bake_star", Vector2(CX, CY))
	_sky_mat.set_shader_parameter("sky_off", sky_off())
	if star != null:
		star.position = o
		if _glow != null:
			RadiantGlow.glow_mat(_glow).set_shader_parameter("light", o / Vector2(960, 540))
			RadiantGlow.glow_mat(_glow).set_shader_parameter("pulse", RadiantGlow.sun_pulse(star))
			RadiantGlow.glow_mat(_glow).set_shader_parameter("hole", RadiantGlow.hole_of(star))
		if layout.star == SystemLayout.StarKind.PULSAR:
			star.set("sub", pc - o)
		if star is SunViewS and _kcor > 0.0:
			# (a sun: everything round its disc at the corona's zoom, the disc at its own)
			star.call("set_zoom", _kcor, star_k())
		elif star.has_method("set_zoom"):
			star.call("set_zoom", star_k())
		if layout.star == SystemLayout.StarKind.CORE:
			# The hole starts small and grows as zoom^0.53; at the old size it filled the frame.
			star.set("hole_k", 0.36 * pow(maxf(zoom, 0.01) / maxf(home_zoom, 0.01), 0.53) / maxf(star_k(), 0.01))
			(star.get("_hmat") as ShaderMaterial).set_shader_parameter("warm_glow", true)
	if star2 != null:
		star2.position = star_screen(SystemLayout.STAR_B)
		if _kcor2 > 0.0:
			star2.call("set_zoom", _kcor2, star_k_of(SystemLayout.STAR_B))
	_step_twin_sky()
	var t_star := Time.get_ticks_usec()
	_step_star()
	tick("star", t_star)
	_twinkle.t = pose(t, 4.0)
	_twinkle.off = block(_cam_pan() * PARALLAX_TWINKLE)
	if _nova != null:
		_nova.off = sky_off()
	if _galaxies != null:
		var go: Vector2 = block(_cam_pan() * float(_galaxies.get("rate")))
		if go != _galaxies.get("off"):
			_galaxies.set("off", go)
			_galaxies.queue_redraw()
	for f in _fields:
		f.off = block(_cam_pan() * float(f.rate))
		f.queue_redraw()
	if _veil_mat != null:
		_veil_mat.set_shader_parameter("off", block(_cam_pan() * PARALLAX_VEIL))
	if _neb_mat != null:
		_neb_mat.set_shader_parameter("off", neb_off())
		# the gas's own slow clock, held still with reduced motion
		_neb_mat.set_shader_parameter("time", 0.0 if DisplaySettings.reduced_motion else pose(wclock() - _neb_t0, 4.0))
		_neb_mat.set_shader_parameter("low", gfx_low())
	if _neb_mat != null:
		# Light from the star's exact place: a rounded place made the gas flicker on each hop.
		# Why: docs/why/SystemView.md#cloud-light
		_neb_mat.set_shader_parameter("star_at", star_exact(-1))
		if layout.twin:
			_neb_mat.set_shader_parameter("bubble_at", bubble_exact())
		_neb_mat.set_shader_parameter("zoom", zoom)
		_neb_mat.set_shader_parameter("lzoom", zoom)
		_neb_mat.set_shader_parameter("home_zoom", home_zoom)
		_neb_mat.set_shader_parameter("lscale", clampf(window.size.x / 700.0, 0.5, 1.4))
		_neb_mat.set_shader_parameter("breath", breath(t))
		# the core's hole: its disc's outer edge on screen, which lights the gas
		_neb_mat.set_shader_parameter("hole_r", 116.0 * star_k())
	_step_depth(o)
	_twinkle.queue_redraw()
	_belts.queue_redraw()
	if _belt_dust != null and _belt_dust.visible:
		var bv := PackedVector4Array()
		for bb in layout.bodies:
			if bb.kind == &"belt" and bv.size() < 3:
				bv.append(Vector4(bb.orbit, 17.0, t / bb.period * TAU, 1.0))
		var nb := bv.size()
		bv.resize(3)
		_belt_mat.set_shader_parameter("belts", bv)
		_belt_mat.set_shader_parameter("n_belts", nb)
		# (round what the belts circle: star A, or in a twin the balance point, where
		# every belt goes -- `SystemLayout._twin`)
		_belt_mat.set_shader_parameter("origin", screen(layout.bary.x, layout.bary.y) if layout.twin else Vector2(CX, CY) + pan)
		_belt_mat.set_shader_parameter("zoom", zoom)
		_belt_mat.set_shader_parameter("tilt", TILT)
	# Shadows follow each world's drawn place and size, so they leave the disc at every zoom.
	var ml: Array = _moons.positions(get_process_delta_time())
	var bp := PackedVector4Array()
	var rg := PackedFloat32Array()
	# Two suns: each shadow falls from its own light (`light_screen`); moons use their world's.
	var twin := layout.twin
	var from := PackedVector2Array()
	for i in layout.bodies.size():
		var b := layout.bodies[i]
		if b.world != &"" and bp.size() < SHADOW_CASTERS:
			var rr := draw_r(b)
			# (the shadow from the world's place on the grid: from its live centre it
			# slid by slivers and its dithered edge flickered through a zoom)
			var ca: Vector2 = at[i] + Vector2.ONE * float(Worlds.half_size(b.world, float(_rq.get(i, rr))) % 2)
			bp.append(Vector4(ca.x, ca.y, rr, world_r(b) * zoom))
			if twin:
				from.append(light_screen(pos[i], ca))
			# its rings' shadow too (C), as wide as their outer edge
			var vw: Node2D = _views.get(i)
			rg.append(2.1 if vw != null and bool((vw.get("spec") as Dictionary).get("ring", false)) else 0.0)
	# EACH MOON CASTS ITS OWN SHADOW (Jon: "shouldn't moons cast shadows?"), by the
	# worlds' rule from its own size, away from the star
	for mm: Dictionary in ml:
		if bp.size() >= SHADOW_CASTERS:
			break
		if bool(mm.hidden) or not window.grow(8.0).has_point(mm.c):
			continue
		var mc: Vector2 = mm.c
		bp.append(Vector4(mc.x, mc.y, float(mm.mrad), float(mm.mrad)))
		if twin:
			from.append(light_screen(pos[int(mm.i)], mc))
		rg.append(0.0)
	var n_cast := bp.size()
	rg.resize(SHADOW_CASTERS)
	_shadow_mat.set_shader_parameter("rings", rg)
	for i in range(bp.size(), SHADOW_CASTERS):
		bp.append(Vector4.ZERO)
	_shadow_mat.set_shader_parameter("bodies", bp)
	_shadow_mat.set_shader_parameter("n_bodies", n_cast)
	_shadow_mat.set_shader_parameter("star_at", o)
	if twin:
		from.resize(SHADOW_CASTERS)
		_shadow_mat.set_shader_parameter("cast_from", from)
		_shadow_mat.set_shader_parameter("per_body", true)
	if radiant and _neb_mat != null:
		# RADIANT: the shafts the worlds throw through the lit gas, and a flare
		_neb_mat.set_shader_parameter("r_bodies", bp)
		_neb_mat.set_shader_parameter("r_rings", rg)
		_neb_mat.set_shader_parameter("r_nb", n_cast)
		# The cloud's flare stays star A's: one uniform cannot flare each sun on its own clock.
		_neb_mat.set_shader_parameter("r_flare", _flare)
		if twin:
			_neb_mat.set_shader_parameter("r_from", from)
			_neb_mat.set_shader_parameter("r_per", true)
	# THE WORLDS DRAWN AGAIN AT THE NEW SIZE, not stretched
	var t_resize := Time.get_ticks_usec()
	for i: int in _views:
		var bw := layout.bodies[i]
		var least := MIN_SCREEN_R_GIANT if bw.kind == &"giant" else MIN_SCREEN_R
		var was: float = _rq.get(i, -1.0)
		var held := _held(_draw_r_raw(bw), was, minf(least, _draw_r_raw(bw)))
		if held != was:
			_rq[i] = held
			(_views[i] as WorldView).set_world(bw.world, bw.seed, held)
	tick("world resize", t_resize)
	var t_worlds := Time.get_ticks_usec()
	# the worlds, nearest drawn last; one behind the star hidden by its disc --
	# except the black hole's, which is drawn between the two groups instead
	var core := layout.star != SystemLayout.StarKind.PULSAR
	var order := range(layout.bodies.size())
	var dep := func(i: int) -> float: return depth(pos[i])
	order.sort_custom(func(a, b2): return dep.call(a) < dep.call(b2))
	var core_placed := false
	# Star B draws between the worlds behind and in front, so a world passes over then behind it.
	var star2_placed := star2 == null
	var d2 := star_depth(SystemLayout.STAR_B)
	# Either sun can be nearer as the pair turns, so the nearer draws over the farther.
	var da := star_depth(-1)
	for k in order.size():
		var i: int = order[k]
		if not _views.has(i):
			continue
		var v: WorldView = _views[i]
		var p := pos[i]
		# (the farther of the two suns first, should one world come after both)
		if not star2_placed and d2 < da and dep.call(i) >= d2:
			_worlds.move_child(star2, -1)
			star2_placed = true
		if core and not core_placed and dep.call(i) >= da:
			_worlds.move_child(star, -1)
			core_placed = true
		if not star2_placed and dep.call(i) >= d2:
			_worlds.move_child(star2, -1)
			star2_placed = true
		_worlds.move_child(v, -1)
		# its box's corner on the grid too: an odd half-size moves it a unit
		var hs := Worlds.half_size(layout.bodies[i].world, float(_rq.get(i, draw_r(layout.bodies[i]))))
		v.position = at[i] + Vector2.ONE * float(hs % 2)
		if _live.has(i) and v.has_method("set_live"):
			v.set_live(float(_live[i][0]), (_live[i][1] as Vector2) - v.position)
		var behind: bool = dep.call(i) < da and not core
		# (lit as the showcase lit them: a world far out still bright on its day side)
		# (two suns: the light of both, `light_here`; one sun, `light_at` itself)
		var lh := light_here(p.x, p.y)
		var kl := 0.95 + 0.35 * lh
		if layout.star == SystemLayout.StarKind.PULSAR:
			# THE BEAM CATCHES IT (C): dim between passes, lit as a beam sweeps by
			var bo := beam_on(at[i] - o, i)
			# (PAINTED: caught in three poses, held, never a smooth glide)
			if painted:
				bo = round(bo * 2.0) / 2.0
			kl = 0.55 + 0.9 * bo
		v.step(t, light_for_at(p), kl, o if behind else Vector2(-9999, -9999), layout.star_r * star_k() if behind else 0.0)
		# LIT BY ITS OWN STAR (C): the lit side in its colour, the night side
		# filled by the sky round it, brighter at a flare's height
		var vm: ShaderMaterial = v.world_mat()
		if vm != null:
			vm.set_shader_parameter("star_tint", tint_at(p))
			vm.set_shader_parameter("night_fill", night_fill(p))
			# (two suns: its own sun's flare, each by its share of the light here --
			# a world round star B flickers when B erupts, not when A does)
			vm.set_shader_parameter("flare", lerpf(_flare, _flare2, share_b(p)) if star2 != null else _flare)
			vm.set_shader_parameter("lift", 1.0)
			# Each moon's place about its world and size feed the shadows it casts on the face.
			var msh := PackedVector4Array()
			for mm: Dictionary in ml:
				if int(mm.i) == i and msh.size() < 4:
					var rel: Vector2 = (mm.c as Vector2) - world_c(i)
					msh.append(Vector4(rel.x, rel.y, float(mm.z), float(mm.mrad)))
			var nm := msh.size()
			msh.resize(4)
			vm.set_shader_parameter("moon_sh", msh)
			vm.set_shader_parameter("n_moon_sh", nm)
	if not star2_placed and d2 < da:
		_worlds.move_child(star2, -1)
		star2_placed = true
	if core and not core_placed:
		_worlds.move_child(star, -1)
	if not star2_placed:
		_worlds.move_child(star2, -1)
	tick("worlds", t_worlds)
	_moons.queue_redraw()
	_lines.queue_redraw()
	var t_fab := Time.get_ticks_usec()
	_Fabric.collect()
	_fabric.update()
	tick("fabric", t_fab)
	tick("step (all)", t_step)
	# THE PALETTE, found from the system's own first full picture
	if painted and _ready_sky and not _palette_built and _frame > 6:
		# PAINTED: no palette is cut; the curated one is the scene's
		_palette_built = true
	if _ready_sky and not _palette_built and _frame > 6:
		_palette_built = true
		var pk := _pal_key()
		if pal_cache_on and _pal_cache.has(pk):
			# BACK IN A SYSTEM ALREADY SEEN: the palette its first visit cut, set on
			# the same frame a cut would have been (`_pal_cache`)
			await RenderingServer.frame_post_draw
			_set_pal(_pal_cache[pk])
			return
		await RenderingServer.frame_post_draw
		# from the place's own half-size picture, so in its pixels
		var img := _scene.get_texture().get_image()
		var pal := pal_from(img)
		if _pal_cache.size() >= PAL_CACHE_MAX:
			_pal_cache.clear()
		_pal_cache[pk] = pal
		pal_cuts += 1
		_set_pal(pal)


## With two suns the palette also keeps star B's steps; a one-sun call is unchanged.
## Why: docs/why/SystemView.md#palette-cut
func pal_from(img: Image) -> PackedVector3Array:
	var cloud := _neb_mat != null
	var extra := pal_extra()
	if not layout.twin:
		return SystemPaletteS.build(img, 0, Vector2(CX, CY) / 2.0, layout.star_r / 2.0, kind, 0,
			SystemPaletteS.K_NEBULA if cloud else SystemPaletteS.K, extra, not cloud,
			cloud and int(_sky_look.neb) <= NebulaField.Kind.REFLECTION, SystemPaletteS.MERGE, true)
	# Suns are placed as at the system's opening, in the half-size picture the palette is cut from.
	return SystemPaletteS.build(img, 0, star_screen(-1) / 2.0, layout.star_r / 2.0, kind, 0,
		SystemPaletteS.K_NEBULA if cloud else SystemPaletteS.K, extra, not cloud,
		cloud and int(_sky_look.neb) <= NebulaField.Kind.REFLECTION, SystemPaletteS.MERGE, true,
		star_screen(SystemLayout.STAR_B) / 2.0, star_disc(SystemLayout.STAR_B) / 2.0, pal_star2(), PAL_N)


## How many colours the palette pass holds (`map_palette.gdshader`'s `pal`).
const PAL_N := 72


## Star B's steps only outside a cloud (lit by it instead).
func pal_star2() -> PackedVector3Array:
	var out := PackedVector3Array()
	if star2 == null or _neb_mat != null:
		return out
	var sc := STAR_B_COL
	var deep := Vector3(pow(sc.x, 3.0), pow(sc.y, 3.0), pow(sc.z, 3.0))
	deep /= maxf(deep.x, maxf(deep.y, deep.z))
	for kq: float in [0.07, 0.11, 0.17, 0.26, 0.38]:
		out.append(deep * kq)
	return out


## Which colours the palette reserves depends on the sky and the style.
func pal_extra() -> PackedVector3Array:
	# A cloud seen from inside has more colours to keep, so weather steps take none from the sky.
	var extra: PackedVector3Array = PackedVector3Array() if no_ramp or _weather == null else SkyWeatherS.ramp(_weather.sky)
	var cloud := _neb_mat != null
	# Galaxy tones are added in a clear sky only: seven more steps in a cloud flicker its gas.
	if not cloud:
		for gt: Vector3 in SkyGalaxiesS.TONES:
			extra.append(gt)
	if cloud:
		# RADIANT's core uses `R_CORE`: SIMPLIFIED's cool violet steps set its haze mauve.
		var res: Array = R_CORE if radiant and int(_sky_look.neb) == 5 else C_RESERVED.get(int(_sky_look.neb), [])
		for h: String in res:
			var cr := Color(h)
			extra.append(Vector3(cr.r, cr.g, cr.b))
		# Only the sun painter's warm steps, not its greys and blues, which caught the cloud.
		for h: String in ["#fff6e2", "#ffdc96", "#ffb054", "#ec7a26", "#c24a14", "#84280c", "#ff8a50"]:
			var cw := Color(h)
			extra.append(Vector3(cw.r, cw.g, cw.b))
	elif layout.star == SystemLayout.StarKind.PULSAR:
		# the remnant's hydrogen reds and oxygen teals (the pulsar's own palette is blues)
		for h: String in ["#3a0e14", "#6a1a20", "#a02a32", "#d0505a", "#16302e", "#24504c", "#357a72", "#56b0a2"]:
			var cr := Color(h)
			extra.append(Vector3(cr.r, cr.g, cr.b))
	elif layout.star != SystemLayout.StarKind.CORE:
		# a clear sky's sun: its glow's dark end in its own hue, so the halo
		# falls off through warm steps to the void and never onto a grey plate
		var sc: Vector3 = SkyBakeS.STARCOL.get(kind, SkyBakeS.STARCOL.ORDINARY)
		var deep := Vector3(pow(sc.x, 3.0), pow(sc.y, 3.0), pow(sc.z, 3.0))
		deep /= maxf(deep.x, maxf(deep.y, deep.z))
		for kq: float in [0.07, 0.11, 0.17, 0.26, 0.38]:
			extra.append(deep * kq)
		if radiant:
			# (RADIANT: A's warm haze round the sun, its dim browns; the cut set it grey)
			for h: String in ["#0b0603", "#191209", "#22190e", "#2b2014", "#34291b", "#443b2e", "#504535"]:
				var ch := Color(h)
				extra.append(Vector3(ch.r, ch.g, ch.b))
	return extra


## The palette pass given its colours.
func _set_pal(pal: PackedVector3Array) -> void:
	var arr := PackedVector3Array(pal)
	arr.resize(72)
	_palette_mat.set_shader_parameter("pal", arr)
	_palette_mat.set_shader_parameter("pal_n", mini(72, pal.size()))


## The palette is cut once per system per session: each visit's GPU readback cost 0.1 s or more.
## Why: docs/why/SystemView.md#palette-cache
static var _pal_cache := {}
const PAL_CACHE_MAX := 64
static var pal_cache_on := not ("palcache=0" in OS.get_cmdline_user_args())
## palettes cut this session (a harness counts them)
static var pal_cuts := 0


func _pal_key() -> Array:
	var bodies := PackedStringArray()
	for b in layout.bodies:
		bodies.append("%s:%s:%s" % [b.kind, b.world, b.seed])
	return [node.get_instance_id(), node.index, kind, style(), painted, radiant, gfx_low(), field_under,
		neb_sky, no_ramp, depth_k, ",".join(bodies), window, home_zoom]


# ---------------------------------------------------------------- the twinkling stars
class _Twinkle extends Node2D:
	var stars: Array = []
	var t := 0.0
	## the sky's slide, so they move with it
	var off := Vector2.ZERO

	func _draw() -> void:
		for s in stars:
			var I: float = s[2]
			var ph: float = s[4]
			var k := I * (0.55 + 0.45 * sin(t * (0.8 + ph * 0.02) + ph))
			var c: Vector3 = Vector3(0.03, 0.04, 0.07).lerp(s[3], minf(1.0, k * 1.4))
			# wrapping round the bake's whole tile, so a long pan never empties it
			var bw := float(SkyBakeS.BW)
			var bh := float(SkyBakeS.BH)
			var m := float(SkyBakeS.M)
			var p := Vector2(fposmod(roundf(s[0]) + m + off.x, bw) - m, fposmod(roundf(s[1]) + m + off.y, bh) - m)
			draw_rect(Rect2((p / 2.0).floor() * 2.0, Vector2(2, 2)), Color(c.x, c.y, c.z))


# ---------------------------------------------------------------- a distant supernova
# A rare, silent supernova flashes in the far sky, never where a disc is.
# Why: docs/why/SystemView.md#supernova
class _Nova extends Node2D:
	const RISE := 0.3
	const HOLD := 1.0
	const FADE := 4.0
	## the glow outlasts the star by this much
	const GLOW := 5.5
	## the first one comes this long after the map opens, then each after the last
	const FIRST := Vector2(30.0, 150.0)
	const EVERY := Vector2(60.0, 180.0)
	## the glow's tints: a shell of hydrogen red, oxygen teal, or a dusty amber
	const TINTS := [Color(1.0, 0.42, 0.36), Color(0.36, 0.9, 0.86), Color(1.0, 0.7, 0.36)]
	var view
	## the far sky's slide (`SystemView.sky_off`)
	var off := Vector2.ZERO
	var _rng := RandomNumberGenerator.new()
	var _next := 0.0
	var _ev := {}

	## when the last one went out (the wall clock, or the harness's)
	var _gone := -1e9
	## a harness's: none of its own starts
	var auto := true

	func setup(v, index: int) -> void:
		view = v
		_rng.seed = hash([index, Time.get_ticks_usec()])
		_next = _now() + _rng.randf_range(FIRST.x, FIRST.y)
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = add

	func _now() -> float:
		return view.wclock() if view != null else float(Time.get_ticks_msec()) / 1000.0

	## Is one live, or did one go out less than `s` seconds ago?
	func busy_within(s: float) -> bool:
		return not _ev.is_empty() or _now() - _gone < s

	## One now, at `at` on screen, or at a clear point anywhere.
	func start(at := Vector2.INF) -> void:
		var p := at if at != Vector2.INF else _spot()
		if p == Vector2.INF:
			_next = _now() + 20.0
			return
		_ev = {"q": p - off, "t0": _now(), "I": _rng.randf_range(1.4, 1.9), "tint": TINTS[_rng.randi() % TINTS.size()]}
		# (one started for the weather -- behind the black hole -- holds the next
		# of its own off a while: two went off seven seconds apart)
		_next = maxf(_next, _now() + EVERY.x)

	## A point on the map clear of the star's disc and every world's.
	func _spot() -> Vector2:
		var w: Rect2 = view.window
		for _i in 24:
			var p := Vector2(_rng.randf_range(w.position.x + 30.0, w.end.x - 30.0), _rng.randf_range(w.position.y + 30.0, w.end.y - 30.0))
			if p.distance_to(view.star_screen(-1)) < view.layout.star_r * view.star_k() + 40.0:
				continue
			if view.star2 != null and p.distance_to(view.star_screen(SystemLayout.STAR_B)) < view.star_disc(SystemLayout.STAR_B) + 40.0:
				continue
			var clear := true
			for i in view.at.size():
				if p.distance_to(view.at[i]) < view.draw_r(view.layout.bodies[i]) + 24.0:
					clear = false
					break
			if clear:
				return p
		return Vector2.INF

	func _process(_d: float) -> void:
		if view == null or view.layout == null:
			return
		var now := _now()
		# NOT WITH REDUCED MOTION (it ignored the setting before the weather came);
		# and never over the far sky's weather: it waits ten seconds for it
		if DisplaySettings.reduced_motion:
			if not _ev.is_empty():
				_ev = {}
				queue_redraw()
			return
		if auto and _ev.is_empty() and now >= _next:
			if view._weather != null and view._weather.far_busy():
				_next = now + 10.0
			else:
				start()
				_next = now + _rng.randf_range(EVERY.x, EVERY.y)
		if not _ev.is_empty():
			if now - float(_ev.t0) > RISE + HOLD + GLOW:
				_ev = {}
				_gone = now
			queue_redraw()

	func _block(p: Vector2, c: Color) -> void:
		draw_rect(Rect2((p / 2.0).floor() * 2.0, Vector2(2, 2)), c)

	func _draw() -> void:
		if _ev.is_empty():
			return
		var a := _now() - float(_ev.t0)
		var lit := RISE + HOLD
		# the star: up fast, held, then out
		var k := 1.0
		if a < RISE:
			k = ease(a / RISE, 0.5)
		elif a > lit:
			k = clampf(1.0 - (a - lit) / FADE, 0.0, 1.0)
			k *= k
		# the glow: up with the star, faint, and slower to go
		var g := clampf(a / lit, 0.0, 1.0) * clampf(1.0 - (a - lit) / GLOW, 0.0, 1.0)
		var p: Vector2 = ((_ev.q as Vector2) + off) / 2.0
		p = p.floor() * 2.0
		var tint: Color = _ev.tint
		# THE GLOW, a round patch of tinted blocks, dithered out at its edge
		if g > 0.0:
			for bx in range(-5, 6):
				for by in range(-5, 6):
					var d := Vector2(bx, by).length() / 5.5
					if d >= 1.0:
						continue
					if d > 0.55 and (bx + by) % 2 != 0:
						continue
					_block(p + Vector2(bx, by) * 2.0, Color(tint, g * 0.22 * pow(1.0 - d, 1.2)))
		if k <= 0.0:
			return
		var I: float = float(_ev.I) * k
		var core := Color(0.9, 0.95, 1.0)
		# the star and its plus
		_block(p, Color(core, minf(1.0, I)))
		for d2 in [Vector2(2, 0), Vector2(-2, 0), Vector2(0, 2), Vector2(0, -2)]:
			_block(p + d2, Color(core, minf(1.0, I * 0.55)))
		# THE SPIKES, longer the brighter it is, falling off as the sky's stars' did
		var reach := 6.0 + 16.0 * k
		var s := 4.0
		while s <= reach:
			var f := I * 0.5 * exp(-s / (3.0 + I * 3.0))
			for d3 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				_block(p + d3 * s, Color(core.lerp(tint, 0.25), minf(1.0, f)))
			s += 2.0


# ---------------------------------------------------------------- the star fields
# A star field at one depth, on a tile larger than the view that wraps as it slides.
class _Field extends Node2D:
	const TW := 1280.0
	const TH := 800.0
	var off := Vector2.ZERO
	## how far it slides for a pixel of pan
	var rate := 0.0
	var _stars: Array = []
	## Weather: a microlens swells one star; a globule hides the stars behind its centre.
	var lens: Dictionary = {}
	var hide := Vector3(-9999, -9999, 0)
	## no pluses: each star one block (PAINTED, whose paint draws them)
	var bare := false

	## where star i is drawn this frame
	func star_at(i: int) -> Vector2:
		var s: Array = _stars[i]
		var ox := (TW - 960.0) / 2.0
		var oy := (TH - 540.0) / 2.0
		return Vector2(fposmod(float(s[0]) + off.x, TW) - ox, fposmod(float(s[1]) + off.y, TH) - oy).floor()

	## `count` stars, brightness from `lo` to `hi`, a share `plus` of them with a plus.
	func setup(seed: int, count: int, lo: float, hi: float, plus: float) -> void:
		var R := Worlds.XRng.new(float(seed))
		_stars.clear()
		for k in count:
			var x := R.next() * TW
			var y := R.next() * TH
			var I := lo + (hi - lo) * pow(R.next(), 2.0)
			var u := R.next()
			var c: Vector3 = SkyBakeS.TEMPS[mini(4, int(u * 5.0))]
			_stars.append([x, y, I, c, R.next() < plus])

	func _draw() -> void:
		var ox := (TW - 960.0) / 2.0
		var oy := (TH - 540.0) / 2.0
		var li: int = int(lens.get("i", -1))
		for si in _stars.size():
			var s: Array = _stars[si]
			var p := Vector2(fposmod(s[0] + off.x, TW) - ox, fposmod(s[1] + off.y, TH) - oy).floor()
			if p.x < -2.0 or p.y < -2.0 or p.x > 962.0 or p.y > 542.0:
				continue
			if hide.z > 0.0 and p.distance_to(Vector2(hide.x, hide.y)) < hide.z:
				continue
			var I: float = s[2]
			if si == li:
				I = minf(1.0, I * float(lens.A))
			var c: Vector3 = Vector3(0.03, 0.04, 0.07).lerp(s[3], I)
			# (the nearest stars warmer, and bigger: a plus round each)
			var near := rate >= 0.4 and rate < 0.5
			if near:
				c = c.lerp(Vector3(1.0, 0.86, 0.66) * I, 0.35)
			var col := Color(c.x, c.y, c.z)
			var q := (p / 2.0).floor() * 2.0
			draw_rect(Rect2(q, Vector2(2, 2)), col)
			if bare:
				continue
			if near and s[4]:
				var arm := Color(col, 0.6)
				for d in [Vector2(2, 0), Vector2(-2, 0), Vector2(0, 2), Vector2(0, -2)]:
					draw_rect(Rect2(q + d, Vector2(2, 2)), arm)
				continue
			if si == li and I > 0.8:
				# a dim plus at its height, and no spikes: not a supernova
				for d in [Vector2(2, 0), Vector2(-2, 0), Vector2(0, 2), Vector2(0, -2)]:
					draw_rect(Rect2(q + d, Vector2(2, 2)), Color(col, 0.3 * (I - 0.8) / 0.2))
			elif s[4]:
				var dim := Color(col, 0.45)
				for d in [Vector2(2, 0), Vector2(-2, 0), Vector2(0, 2), Vector2(0, -2)]:
					draw_rect(Rect2(q + d, Vector2(2, 2)), dim)


# ---------------------------------------------------------------- belts
# Belt rocks are lit on the star's side, with a few bigger ones tumbling.
class _Belts extends Node2D:
	var view

	func _draw() -> void:
		var t0 := Time.get_ticks_usec()
		_rocks()
		view.tick("belts", t0)

	## Rock draws are cached per belt, as a rock's draws never depend on the rock count.
	var _rtab := {}

	func _rock_draws(b: SystemLayout.Body, n: int) -> PackedFloat64Array:
		var key := floorf(b.orbit * 13.0)
		var e: Array = _rtab.get(b.index, [])
		if e.is_empty() or float(e[0]) != key:
			e = [key, Worlds.XRng.new(key), PackedFloat64Array()]
			_rtab[b.index] = e
		var tab: PackedFloat64Array = e[2]
		var have := tab.size() / 7
		if have < n:
			var R: Worlds.XRng = e[1]
			tab.resize(n * 7)
			for k in range(have * 7, n * 7):
				tab[k] = R.next()
			e[2] = tab
		return tab

	## Rock draws come from a table and positions work in place: 1,200 rocks a frame cost too much.
	## Why: docs/why/SystemView.md#belt-performance
	func _rocks() -> void:
		var L: SystemLayout = view.layout
		var glints: bool = view.belt_glints
		var painted: bool = view.painted
		var vt: float = view.t
		var zm: float = view.zoom
		var base: Vector2 = Vector2(CX, CY) + (view.pan as Vector2)
		var lit_belt: int = view.belt_lit
		var lit_t: float = view.belt_t
		var sc3: Vector3 = SkyBakeS.STARCOL.get(view.kind, SkyBakeS.STARCOL.ORDINARY)
		var rk_all: Array = (view._pt as Dictionary).get("rock", []) if painted else []
		for b in L.bodies:
			if b.kind != &"belt":
				continue
			# (which of its first 300 rocks are glinting now, and how far in: worked
			# out from a table made once a belt, so the rocks that are not cost nothing)
			var gl := _glints_now(b.index, view.pose(vt, 8.0) if painted else vt) if glints else {}
			var spin: float = vt / b.period * TAU
			var pulsar: bool = L.star == SystemLayout.StarKind.PULSAR
			var o: Vector2 = view.origin()
			# New rocks come in faint, as they popped in at full strength a few per zoom frame.
			var n_rocks := 300.0 * maxf(zm, 0.8)
			var nr := ceili(n_rocks)
			var D := _rock_draws(b, nr)
			var orbit: float = b.orbit
			var lit_on := b.index == lit_belt
			# ROUND ITS OWN CENTRE (ruling 20: in a twin every belt circles the pair's
			# balance point), sided by where on its own circle a rock is
			var bh: Vector2 = b.host_at(vt)
			var hx: float = bh.x
			var hz: float = bh.y
			for i in nr:
				var fade_in := clampf((n_rocks - float(i)) / 60.0, 0.0, 1.0) if i >= 300 else 1.0
				var d := i * 7
				var a := D[d] * TAU + spin * (0.9 + D[d + 1] * 0.2)
				var rr := orbit + (D[d + 2] - 0.5) * 33.0 * (0.5 + D[d + 3])
				var big := D[d + 4]
				var shade := D[d + 5]
				var lift := (D[d + 6] - 0.5) * 2.0
				var x := hx + cos(a) * rr
				var z := hz + sin(a) * rr
				var s: Vector2 = ((base + Vector2(x, z * TILT + lift) * zm) / 2.0).floor() * 2.0
				if s.x < -16.0 or s.x > 976.0 or s.y < -16.0 or s.y > 556.0:
					continue
				if painted and fade_in < 0.5:
					# (PAINTED: a new rock is there or not, from half way in)
					continue
				if painted:
					# PAINTED rocks light on the star side in their ramp, by the beam at a pulsar.
					var rk: Array = rk_all
					var lv := (0.62 + 0.38 * clampf(-sin(a) * 0.9 + 0.3, 0.0, 1.0)) * (0.85 + 0.3 * shade)
					if pulsar:
						lv *= 0.55 + 0.9 * round(view.beam_on(s - o) * 2.0) / 2.0
					var ci := 6 if lv > 0.98 else (5 if lv > 0.82 else (4 if lv > 0.66 else 3))
					if lit_on and lit_t > 0.5:
						ci = mini(ci + 2, 7)
					var plt: Color = rk[ci]
					var pdk: Color = rk[maxi(ci - 2, 1)]
					var psx := -1 if x - hx > 0.0 else 1
					if big < 0.86:
						draw_rect(Rect2(s, Vector2(2, 2)), plt if shade < 0.8 else pdk)
					elif big < 0.97:
						draw_rect(Rect2(s, Vector2(4, 2)), pdk)
						draw_rect(Rect2(s + Vector2(2 if psx > 0 else 0, 0), Vector2(2, 2)), plt)
					else:
						draw_rect(Rect2(s - Vector2(2, 2), Vector2(6, 4)), rk[maxi(ci - 1, 2)])
						draw_rect(Rect2(s + Vector2(psx * 2, -2), Vector2(2, 2)), rk[mini(ci + 1, 7)])
						draw_rect(Rect2(s + Vector2(-psx * 2, 0), Vector2(2, 2)), rk[1])
					if gl.has(i) and not pulsar:
						_glint(s, float(gl[i]), 0.62 + 0.38 * clampf(-sin(a) * 0.9 + 0.3, 0.0, 1.0), Vector3.ONE, rk)
					continue
				# Lit rubble, never a ring of dark specks; round a pulsar, lit as the beam sweeps.
				var phase := 0.62 + 0.38 * clampf(-sin(a) * 0.9 + 0.3, 0.0, 1.0)
				var alb := 0.78 + 0.32 * shade
				var kb := 1.0
				if pulsar:
					kb = 0.45 + 1.1 * view.beam_on(s - o)
				# Light rock, lighter than the gas: dimmed grey rock read as dark specks.
				var litv: Vector3 = Vector3(0.80, 0.78, 0.74).lerp(sc3, 0.3) * (0.78 + 0.22 * (1.0 / (1.0 + (x * x + z * z) / (160.0 * 160.0))))
				litv = (litv * (phase * alb * kb)).clamp(Vector3.ZERO, Vector3.ONE)
				var lit := Color(litv.x, litv.y, litv.z)
				var dark := lit.darkened(0.18)
				if lit_on and lit_t > 0.0:
					lit = lit.lerp(Color.WHITE, 0.45 * lit_t)
					dark = dark.lerp(lit, 0.6 * lit_t)
				lit.a = fade_in
				dark.a = fade_in
				var sx := -1 if x - hx > 0.0 else 1
				# in blocks of 2x2, as the whole place is
				if big < 0.86:
					draw_rect(Rect2(s, Vector2(2, 2)), lit if shade < 0.85 else dark)
				elif big < 0.97:
					draw_rect(Rect2(s, Vector2(4, 2)), dark)
					draw_rect(Rect2(s + Vector2(2 if sx > 0 else 0, 0), Vector2(2, 2)), lit)
				else:
					var tw := int(floor(vt * 0.8 + i)) & 1
					draw_rect(Rect2(s - Vector2(2, 2), Vector2(6, 4)), dark)
					draw_rect(Rect2(s + Vector2(sx * 2 * (1 - tw), -2), Vector2(2, 2)), lit.lightened(0.15))
					draw_rect(Rect2(s + Vector2(-sx * 2, 0), Vector2(2, 2)), dark.darkened(0.3))
				if gl.has(i) and not pulsar:
					_glint(s, float(gl[i]), phase, sc3)

	## Glints are sunlight on a tumbling rock, on the first 300 rocks only, as bars never a cross.
	## Why: docs/why/SystemView.md#belt-glints
	const GLINT_UP := 0.2
	const GLINT_S := 1.0

	## each belt's first 300 rocks' glints: [period, offset] a rock, made once
	var _gtab := {}

	## The rocks of belt `belt` glinting at time `t`: rock -> how far into its
	## glint, 0 to 1 (up over GLINT_UP, gone by GLINT_S), before the light's angle.
	func _glints_now(belt: int, t: float) -> Dictionary:
		if not _gtab.has(belt):
			var tab := PackedFloat32Array()
			for i in 300:
				# (each rock's own turn: 20 to 44 s between its glints)
				var period := 20.0 + 24.0 * SkyBakeS.hash2(i, belt * 7 + 3)
				tab.append(period)
				tab.append(SkyBakeS.hash2(i, belt * 7 + 4) * period)
			_gtab[belt] = tab
		var tb: PackedFloat32Array = _gtab[belt]
		var out := {}
		for i in 300:
			var u := fposmod(t + tb[i * 2 + 1], tb[i * 2])
			if u < GLINT_S:
				out[i] = smoothstep(0.0, GLINT_UP, u) * (1.0 - smoothstep(GLINT_UP, GLINT_S, u))
		return out

	## Each style draws the glint in its own hand (`_glint`).
	## Why: docs/why/SystemView.md#belt-glints
	func _glint(s: Vector2, e0: float, phase: float, sc3: Vector3, rk: Array = []) -> void:
		# (brighter where the belt is seen lit full)
		var k := 0.55 + 0.45 * clampf((phase - 0.62) / 0.38, 0.0, 1.0)
		if view.painted:
			var ep := e0 * k
			if ep < 0.15:
				return
			# (the ramp's top warmed by the star is the brightest a lit rock gets, so
			# the glint's core is that step taken most of the way to white)
			var hot: Color = (rk[7] as Color).lerp(Color.WHITE, 0.6)
			draw_rect(Rect2(s, Vector2(2, 2)), hot if ep >= 0.35 else rk[7])
			if ep >= 0.35:
				for d: Vector2 in [Vector2(2, 0), Vector2(-2, 0)]:
					draw_rect(Rect2(s + d, Vector2(2, 2)), rk[7] if ep >= 0.65 else rk[6])
			if ep >= 0.65:
				for d: Vector2 in [Vector2(4, 0), Vector2(-4, 0)]:
					draw_rect(Rect2(s + d, Vector2(2, 2)), rk[6])
			return
		var e := e0 * k
		if e < 0.04:
			return
		var c := Vector3(1.0, 1.0, 1.0).lerp(sc3, 0.25)
		var core: Color
		var arm: Color
		var tip: Color
		if view.radiant:
			# (linear light, toned as A tones every light: the bar's core, arms, tips)
			var cl := Vector3(pow(c.x, 2.2), pow(c.y, 2.2), pow(c.z, 2.2))
			core = _Moons._tone(cl * 2.6 * e)
			arm = _Moons._tone(cl * 1.1 * e)
			tip = _Moons._tone(cl * 0.7 * maxf(e - 0.45, 0.0))
			core.a = minf(1.0, e * 2.0)
			arm.a = minf(1.0, e * 1.6)
			tip.a = minf(1.0, (e - 0.45) * 2.4)
		else:
			core = Color(c.x, c.y, c.z, minf(1.0, e * 1.35))
			arm = Color(c.x, c.y, c.z, minf(1.0, e * 0.7))
			tip = Color(c.x, c.y, c.z, (e - 0.45) * 0.6)
		draw_rect(Rect2(s, Vector2(2, 2)), core)
		for d: Vector2 in [Vector2(2, 0), Vector2(-2, 0)]:
			draw_rect(Rect2(s + d, Vector2(2, 2)), arm)
		if e > 0.45:
			for d: Vector2 in [Vector2(4, 0), Vector2(-4, 0)]:
				draw_rect(Rect2(s + d, Vector2(2, 2)), tip)

# ---------------------------------------------------------------- the fabric and the orbits
# The fabric is turned 45 degrees so no line runs straight from the eye.
# Why: docs/why/SystemView.md#fabric-and-orbits
class _Lines extends Node2D:
	var view
	var _fabric: Array = []
	var _last := -1.0
	var _last_cam := Vector3(-1, 0, 0)

	## Whether a point is on a world's disc: the lines now draw over the place, so
	## they stop at each world rather than crossing it.
	func _on_world(sp: Vector2) -> bool:
		for i: int in view._views:
			var r: float = view.draw_r(view.layout.bodies[i]) + 1.5
			if sp.distance_squared_to(view.at[i]) < r * r:
				return true
		return false

	## The star's hole in the lines: its disc, or the black hole's disc and glow.
	func _star_hole() -> Vector2:
		var L: SystemLayout = view.layout
		if L.star == SystemLayout.StarKind.CORE:
			var ck: float = view.star_k()
			return Vector2(116.0 * ck, 116.0 * TILT * ck + 22.0 * ck)
		var k: float = view.star_k()
		return Vector2(L.star_r * k + 2.0, L.star_r * k + 2.0)

	## Star B's hole in the lines, as star A's (`Vector2.ZERO` with one sun).
	func _star2_hole() -> Vector2:
		if view.star2 == null:
			return Vector2.ZERO
		var r2: float = view.star_disc(SystemLayout.STAR_B)
		return Vector2(r2 + 2.0, r2 + 2.0)

	func _draw() -> void:
		# (HIDE ORBITS on the map's toolbar)
		if not view.orbits_on:
			return
		var t1 := Time.get_ticks_usec()
		for run: Array in orbit_runs():
			draw_polyline_colors(run[0], run[1], 1.0)
		view.tick("lines draw", t1)

	## How many of a ring's points `orbit_runs` tests against the frame at once.
	const SPAN := 32

	## Orbit lines skip stretches wholly off frame; 3,000 points a ring were worked out on the Mac.
	## Why: docs/why/SystemView.md#orbit-culling
	func orbit_runs(cull := true) -> Array:
		var runs: Array = []
		var L: SystemLayout = view.layout
		var zm: float = view.zoom
		var base: Vector2 = Vector2(CX, CY) + (view.pan as Vector2)
		var win: Rect2 = view.window.grow(4.0)
		# (star A's hole where its disc is drawn, at its own depth: the pair turns,
		# so A leaves the plane's origin -- one sun, the origin and 0)
		var o: Vector2 = view.star_screen(-1)
		var da: float = view.star_depth(-1)
		var hole := _star_hole()
		# (two suns: star B's disc stops the lines too)
		var hole2 := _star2_hole()
		var o2: Vector2 = view.star_screen(SystemLayout.STAR_B)
		var two := hole2.x > 0.0
		# In a twin the star's hole cuts only behind it: a world in front hid 26% of its ring.
		# Why: docs/why/SystemView.md#twin-orbit-holes
		var d2: float = view.star_depth(SystemLayout.STAR_B)
		var odepth: bool = view.orbit_depth
		var painted: bool = view.painted
		var vt: float = view.t
		var views: Dictionary = view._views
		var ats: Array[Vector2] = view.at
		var c_far := Vector3(0.55, 0.58, 0.62)
		var c_near := Vector3(0.82, 0.85, 0.9)
		for bi in L.bodies.size():
			var b := L.bodies[bi]
			if b.kind == &"belt":
				continue
			# A POINT EVERY PIXEL AND A BIT of the ellipse as drawn (Jon: "why are some
			# of the planet orbits wobbly?"): its perimeter on screen, Ramanujan's
			var orbit: float = b.orbit
			# Orbits are round their own centre: star A, star B or the balance point (ruling 20).
			var hh: Vector2 = b.host_at(view.t)
			var hx: float = hh.x
			var hz: float = hh.y
			var ea: float = orbit * zm
			var eb: float = ea * TILT
			var per: float = PI * (3.0 * (ea + eb) - sqrt((3.0 * ea + eb) * (ea + 3.0 * eb)))
			var n := clampi(int(per / 1.2), 64, 3000)
			var fn := float(n)
			var own: bool = views.has(bi)
			var own_r: float = view.draw_r(b) + 1.5
			var own_r2 := own_r * own_r
			var at_b: Vector2 = ats[bi]
			# The orbit stops at a ringed world's ring edge, as it crossed the face of the rings.
			var ring_ab := Vector2.ZERO
			if own:
				var vw: Node2D = views[bi]
				var vm: ShaderMaterial = vw.get("_mat")
				var rmode: Variant = vm.get_shader_parameter("ring_mode") if vm != null else null
				var rout: Variant = vm.get_shader_parameter("ring_out") if vm != null else null
				if rmode != null and rout != null and int(rmode) == 1 and bool((vw.get("spec") as Dictionary).get("ring", false)):
					var ra: float = float(rout) * (own_r - 1.5) + 2.0
					ring_ab = Vector2(ra, ra * 0.28 + 1.5)
			var rings := ring_ab.x > 0.0
			var wc: Vector2 = view.world_c(bi) if rings else Vector2.ZERO
			var a0: float = b.phase + (vt / b.period) * TAU
			var orb1 := maxf(orbit, 1.0)
			# (how far a stretch of SPAN points can bow from its ends, and a margin)
			var bow := ea * (TAU * float(SPAN) / fn) * 0.5 + 2.0
			var pts := PackedVector2Array()
			var cols := PackedColorArray()
			var i := 0
			while i <= n:
				if cull and i % SPAN == 0 and i + SPAN <= n:
					var j := i + SPAN
					var ai := float(i) / fn * TAU
					var aj := float(j) / fn * TAU
					var pi_ := base + Vector2(hx + cos(ai) * orbit, (hz + sin(ai) * orbit) * TILT) * zm
					var pj := base + Vector2(hx + cos(aj) * orbit, (hz + sin(aj) * orbit) * TILT) * zm
					if not Rect2(pi_, Vector2.ZERO).expand(pj).grow(bow).intersects(win, true):
						# none of i .. j-1 is on the frame: the line breaks there, once
						if pts.size() > 1:
							runs.append([pts, cols])
						pts = PackedVector2Array()
						cols = PackedColorArray()
						i = j
						continue
				var a := float(i) / fn * TAU
				i += 1
				# (`orbit_point` and `screen`, as they work it: the plane point held in
				# 32 bits as a Vector3's is)
				var op := Vector2(hx + cos(a) * orbit, hz + sin(a) * orbit)
				var sp: Vector2 = base + Vector2(op.x, op.y * TILT + 0.0) * zm
				# off the frame, in the star, or on its own world (the only one on its ring)
				var off_world := own and sp.distance_squared_to(at_b) < own_r2
				if rings and not off_world:
					var rq: Vector2 = (sp - wc) / ring_ab
					off_world = rq.length_squared() < 1.0
				if not win.has_point(sp) or off_world \
						or ((not two or op.y < da) and pow((sp.x - o.x) / hole.x, 2.0) + pow((sp.y - o.y) / hole.y, 2.0) < 1.0) \
						or (two and op.y < d2 and pow((sp.x - o2.x) / hole2.x, 2.0) + pow((sp.y - o2.y) / hole2.y, 2.0) < 1.0):
					if pts.size() > 1:
						runs.append([pts, cols])
					pts = PackedVector2Array()
					cols = PackedColorArray()
					continue
				# Whole screen pixels: snapped to 2x2 blocks the rings stair-stepped and wobbled.
				var q: Vector2 = sp.round()
				var np := pts.size()
				if np > 0 and pts[np - 1] == q:
					continue
				pts.append(q)
				var behind := fposmod(a0 - a, TAU)
				var tr := pow(1.0 - behind / 2.1, 1.6) if behind < 2.1 else 0.0
				var c := c_far.lerp(c_near, tr)
				# The near half is bolder so the plane reads as lying back, never by zoom.
				var dk := 1.0
				if odepth:
					var dz := smoothstep(-1.0, 1.0, (op.y - hz) / orb1)
					if painted:
						dz = 0.0 if dz < 0.33 else (0.5 if dz < 0.67 else 1.0)
					dk = lerpf(0.6, 1.45, dz)
				cols.append(Color(c.x, c.y, c.z, (0.14 + tr * 0.38) * dk))
			if pts.size() > 1:
				runs.append([pts, cols])
		return runs


# ---------------------------------------------------------------- the fabric
# The fabric is a mesh laid out once; `map_fabric.gdshader` moves it, so the camera costs no CPU.
# Why: docs/why/SystemView.md#fabric
class _Fabric extends Node2D:
	var view
	var _level := -1
	var _mat: ShaderMaterial
	## Grids are kept for the session and built on workers: the finest took 78 ms on the spot.
	## Why: docs/why/SystemView.md#fabric-grids
	static var _meshes := {}
	static var _jobs := {}
	const REACH_STEP := 64.0
	const MESHES_MAX := 15

	func _init() -> void:
		_mat = ShaderMaterial.new()
		_mat.shader = FABRIC
		material = _mat

	static func _key(level: int, reach: float) -> String:
		return "%d:%d" % [level, int(reach)]

	## How far a grid reaches for a map whose edge is `edge` (rounded up).
	static func reach_for(edge: float) -> float:
		return ceilf((edge + 20.0) / REACH_STEP) * REACH_STEP

	## The grid's points at spacing 30 / 2^level, out to `E`: pure arithmetic,
	## safe on a worker thread, written into `out[0]`.
	static func _points(level: int, E: float, out: Array) -> void:
		var gap := 30.0 / pow(2.0, float(level))
		var stp := gap / 6.0
		var kk := sqrt(0.5)
		var lim := E * 1.42
		# Each line is a thin quad with a tent of coverage, as one-pixel lines crawled on zoom.
		# Why: docs/why/SystemView.md#fabric-lines
		var verts := PackedVector2Array()
		var partner := PackedVector2Array()
		var cols := PackedColorArray()
		var idx := PackedInt32Array()
		for dir in 2:
			var a := ceilf(-lim / gap) * gap
			while a <= lim:
				var oddk := 1.0 if posmod(roundi(a / gap), 2) == 1 else 0.0
				var b := -lim
				while b < lim:
					var u0 := a if dir == 1 else b
					var v0 := b if dir == 1 else a
					var u1 := a if dir == 1 else b + stp
					var v1 := b + stp if dir == 1 else a
					var p0 := Vector2((u0 - v0) * kk, (u0 + v0) * kk)
					var p1 := Vector2((u1 - v1) * kk, (u1 + v1) * kk)
					if p0.length() < E or p1.length() < E:
						var n := verts.size()
						verts.append(p0)
						verts.append(p0)
						verts.append(p1)
						verts.append(p1)
						partner.append(p1)
						partner.append(p1)
						partner.append(p0)
						partner.append(p0)
						cols.append(Color(0.0, oddk, 1.0))
						cols.append(Color(1.0, oddk, 1.0))
						cols.append(Color(0.0, oddk, 0.0))
						cols.append(Color(1.0, oddk, 0.0))
						idx.append_array([n, n + 1, n + 2, n + 1, n + 3, n + 2])
					b += stp
				a += gap
		out[0] = [verts, partner, cols, idx]

	## The arrays `_points` laid out, as a mesh of quads.
	static func _make_mesh(res: Array) -> ArrayMesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = res[0]
		arrays[Mesh.ARRAY_TEX_UV] = res[1]
		arrays[Mesh.ARRAY_COLOR] = res[2]
		arrays[Mesh.ARRAY_INDEX] = res[3]
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return m

	## Every level of a map's grid that is not kept yet, started on worker threads.
	static func warm(edge: float) -> void:
		var E := reach_for(edge)
		# (the levels it draws: the finer of the two the zoom is between, -1 to 2)
		for level in range(-1, 3):
			var k := _key(level, E)
			if _meshes.has(k) or _jobs.has(k):
				continue
			var out: Array = [null]
			var id := WorkerThreadPool.add_task(_points.bind(level, E, out), false, "map fabric grid")
			_jobs[k] = {"id": id, "out": out}

	## Grid at spacing 30 / 2^level: kept, finished from its worker, or laid out here.
	func _mesh(level: int) -> ArrayMesh:
		var L: SystemLayout = view.layout
		var E := reach_for(L.edge)
		var k := _key(level, E)
		if _meshes.has(k):
			return _meshes[k]
		var res: Array
		if _jobs.has(k):
			var job: Dictionary = _jobs[k]
			_jobs.erase(k)
			if int(job.id) >= 0:
				WorkerThreadPool.wait_for_task_completion(int(job.id))
			res = job.out
		else:
			res = [null]
			_points(level, E, res)
		var m := _make_mesh(res[0])
		if _meshes.size() >= MESHES_MAX:
			_meshes.erase(_meshes.keys()[0])
		_meshes[k] = m
		return m

	## The grids finished on their workers since last frame, made into meshes
	## while nothing is waiting on them (one a frame).
	static func collect() -> void:
		for k: String in _jobs.keys():
			var job: Dictionary = _jobs[k]
			var id := int(job.id)
			if id >= 0 and not WorkerThreadPool.is_task_completed(id):
				continue
			_jobs.erase(k)
			if id >= 0:
				WorkerThreadPool.wait_for_task_completion(id)
			var m := _make_mesh((job.out as Array)[0])
			if _meshes.size() >= MESHES_MAX:
				_meshes.erase(_meshes.keys()[0])
			_meshes[k] = m
			return

	## Wait for every grid job on exit: an unwaited worker task hangs the process at quit.
	## Why: docs/why/SystemView.md#grid-workers
	func _exit_tree() -> void:
		for k: String in _jobs:
			var job: Dictionary = _jobs[k]
			if int(job.id) >= 0:
				WorkerThreadPool.wait_for_task_completion(int(job.id))
				job.id = -1

	func _draw() -> void:
		if _level >= 0:
			draw_mesh(_mesh(_level), null)

	## A heavy giant's well is wider, 34 to 45 px, so its far reach stays a quarter of a star's.
	## Why: docs/why/SystemView.md#giant-wells
	static func giant_well_w(b: SystemLayout.Body) -> float:
		if b.kind != &"giant" or b.gm_frac <= 0.0:
			return b.well_w
		var u := clampf((b.gm_frac - SystemLayout.GIANT_MIN) / (SystemLayout.GIANT_MAX - SystemLayout.GIANT_MIN), 0.0, 1.0)
		return b.well_w * lerpf(1.0, GIANT_W_MOST, u)

	## the heaviest giant's well against the laid-out width (34 px to 45)
	const GIANT_W_MOST := 45.0 / 34.0

	## Each frame: the camera, the wells where the bodies are now, and the clear
	## discs of the star and the worlds. Redrawn only when the spacing changes.
	func update() -> void:
		var L: SystemLayout = view.layout
		var z: float = view.zoom
		# The finer grid fades in over each zoom doubling, so half its lines never pop in at once.
		var lz := log(maxf(z, 0.01)) / log(2.0)
		var base := floori(lz)
		var level := clampi(base + 1, -1, 2)
		var fine := clampf(lz - float(base), 0.0, 1.0) if base + 1 == level else (1.0 if base + 1 > level else 0.0)
		_mat.set_shader_parameter("fine_k", fine * fine * (3.0 - 2.0 * fine))
		_mat.set_shader_parameter("gap", 30.0 / pow(2.0, float(level)))
		if level != _level:
			_level = level
			queue_redraw()
		_mat.set_shader_parameter("origin", Vector2(view.CX, view.CY) + view.pan)
		_mat.set_shader_parameter("zoom", z)
		_mat.set_shader_parameter("tilt", view.TILT)
		_mat.set_shader_parameter("edge", L.edge + 20.0)
		# With two suns the shader's own funnel is off; star A is a well where the pair has it.
		_mat.set_shader_parameter("star_d", 0.0 if L.twin else L.star_mass * 0.8)
		_mat.set_shader_parameter("star_w", 46.0 + L.star_r * 1.4)
		var wells := PackedVector4Array()
		# Star B's well uses A's law scaled by its mass share, so the lighter star dents less.
		if L.twin:
			var b2: Vector2 = L.star_pos(SystemLayout.STAR_B, view.t)
			wells.append(Vector4(b2.x, b2.y, L.star_mass * 0.8 * (1.0 - L.star_share) / L.star_share, 46.0 + L.star2_r * 1.4))
			var a2: Vector2 = L.star_pos(-1, view.t)
			wells.append(Vector4(a2.x, a2.y, L.star_mass * 0.8, 46.0 + L.star_r * 1.4))
		for i in L.bodies.size():
			var b := L.bodies[i]
			if b.mass > 0.0 and wells.size() < 16:
				wells.append(Vector4(view.pos[i].x, view.pos[i].y, b.mass * 0.9, giant_well_w(b)))
		var nw := wells.size()
		wells.resize(16)
		_mat.set_shader_parameter("wells", wells)
		_mat.set_shader_parameter("n_wells", nw)
		var core := L.star == SystemLayout.StarKind.CORE
		var sk: float = view.star_k()
		# (two suns: no hole at the origin; each sun's disc is left clear where it
		# is, as a world's is, below)
		_mat.set_shader_parameter("hole", Vector2(116.0 * sk, 116.0 * view.TILT * sk + 22.0 * sk) if core else (Vector2(0.01, 0.01) if L.twin else Vector2(L.star_r * sk + 2.0, L.star_r * sk + 2.0)))
		var worlds := PackedVector3Array()
		# (star B's disc left clear as a world's is, and star A's where the pair has
		# it, first so they always are)
		if view.star2 != null:
			var sb: Vector2 = view.star_screen(SystemLayout.STAR_B)
			worlds.append(Vector3(sb.x, sb.y, float(view.star_disc(SystemLayout.STAR_B)) + 2.0))
		if L.twin:
			var sa: Vector2 = view.star_exact(-1)
			worlds.append(Vector3(sa.x, sa.y, L.star_r * sk + 2.0))
		for i: int in view._views:
			if worlds.size() < 16:
				worlds.append(Vector3(view.at[i].x, view.at[i].y, view.draw_r(L.bodies[i]) + 1.5))
		var nwo := worlds.size()
		worlds.resize(16)
		_mat.set_shader_parameter("worlds", worlds)
		_mat.set_shader_parameter("n_worlds", nwo)


# ---------------------------------------------------------------- moons
# Moons draw at full size over the picture, only for the world pointed at, selected or circled.
# Why: docs/why/SystemView.md#moons
class _Moons extends Node2D:
	var view

	## RADIANT's gathered tone: linear light to an sRGB colour, never a flat white
	static func _tone(c: Vector3) -> Color:
		return Color(pow(1.0 - exp(-c.x * 1.15), 1.0 / 2.2), pow(1.0 - exp(-c.y * 1.15), 1.0 / 2.2), pow(1.0 - exp(-c.z * 1.15), 1.0 / 2.2))
	## how deep each moon ("world:moon") sits in its world's shadow, eased
	var _ecl := {}

	## In a twin a world hides behind a star only while farther than it, else moons vanished.
	## Why: docs/why/SystemView.md#twin-moons
	func behind_star(i: int, s: Vector2, o: Vector2, hole: Vector2, o2: Vector2, hole2: Vector2) -> bool:
		var two := hole2.x > 0.0
		var d: float = (view.pos[i] as Vector2).y
		if (not two or d < float(view.star_depth(-1))) and pow((s.x - o.x) / hole.x, 2.0) + pow((s.y - o.y) / hole.y, 2.0) < 1.0:
			return true
		return two and d < float(view.star_depth(SystemLayout.STAR_B)) \
			and pow((s.x - o2.x) / hole2.x, 2.0) + pow((s.y - o2.y) / hole2.y, 2.0) < 1.0

	## Per moon: world, centre, radii, screen place, depth and an eclipse eased over 0.25 s.
	func positions(dt: float) -> Array:
		var out: Array = []
		var L: SystemLayout = view.layout
		if L == null:
			return out
		var z: float = view.zoom
		var o: Vector2 = view.star_screen(-1)
		var hole: Vector2 = view._lines._star_hole()
		var hole2: Vector2 = view._lines._star2_hole()
		var o2: Vector2 = view.star_screen(SystemLayout.STAR_B)
		var mrad := clampf(0.35 + 0.42 * z, 0.5, 2.4)
		for i: int in view._views:
			var b := L.bodies[i]
			var v: Node2D = view._views[i]
			var moons: int = v.get("spec").get("moons", 0)
			if moons <= 0:
				continue
			var r: float = view.draw_r(b)
			var s: Vector2 = view.world_c(i)
			var r2 := (r + 1.0) * (r + 1.0)
			var gap := gap_for(b, r, moons)
			var slots := ring_slots(i, b, r, moons)
			var sq: float = 0.28 if not slots.is_empty() else TILT
			if behind_star(i, s, o, hole, o2, hole2):
				continue
			var L3: Vector3 = view.light_for_at(view.pos[i]).normalized()
			for m in moons:
				var a: float = view.pose(view.t) * (0.25 + m * 0.12) + m * 2.1
				var mr: float = float(slots[m]) * r if not slots.is_empty() else orbit_r(r, m, gap)
				var c: Vector2 = s + Vector2(cos(a) * mr, sin(a) * mr * sq)
				var mz := sin(a) * mr * sqrt(maxf(0.0, 1.0 - sq * sq))
				var M := Vector3(c.x - s.x, c.y - s.y, mz)
				var tl := M.dot(L3)
				var inside := tl < 0.0 and (M - L3 * tl).length() < r * 0.96
				var key := "%d:%d" % [i, m]
				var e: float = _ecl.get(key, 1.0 if inside else 0.0)
				e = move_toward(e, 1.0 if inside else 0.0, dt / 0.25)
				_ecl[key] = e
				out.append({"i": i, "m": m, "s": s, "r": r, "c": c, "z": mz, "mrad": mrad,
					"hidden": sin(a) < 0.0 and c.distance_squared_to(s) < r2, "ecl": e})
		return out
	## the ring's gaps for each ringed world this size: "i:r" -> [radii in world radii]
	var _slots := {}

	## Moons of a ringed world sit in its ring gaps, as shepherd moons do, never across a band.
	## Why: docs/why/SystemView.md#moon-orbits
	func ring_slots(i: int, b: SystemLayout.Body, r: float, moons: int) -> Array:
		var v: Node2D = view._views[i]
		var spec: Dictionary = v.get("spec")
		if not spec.get("ring", false) or PlanetView.ring_style == Rings.Look.DOTS or r < 2.0:
			return []
		var key := "%d:%d" % [i, roundi(r)]
		if _slots.has(key):
			return _slots[key]
		var cell: float = float(v.get("_cell")) if v.get("_cell") != null else 2.0
		var Rg := Rings.build(PlanetView.ring_style, b.world, b.seed, cell / r)
		var img: Image = (Rg.tex as ImageTexture).get_image()
		var rin: float = Rg.rin
		var rout: float = Rg.rout
		var n := img.get_width()
		# the gaps: runs where the ring stops little of the light, wide enough on
		# screen for a line and a moon (3 px)
		var gaps: Array = []
		var start := -1
		for k in n + 1:
			var thin: bool = k < n and img.get_pixel(k, 0).r < 0.15
			if thin and start < 0:
				start = k
			elif not thin and start >= 0:
				var a := rin + float(start) / float(n) * (rout - rin)
				var e := rin + float(k) / float(n) * (rout - rin)
				# not the clear space between the world and its innermost ring
				if (e - a) * r >= 3.0 and a > rin + 0.02:
					gaps.append([e - a, (a + e) * 0.5])
				start = -1
		gaps.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) > float(y[0]))
		var out: Array = []
		for g: Array in gaps:
			if out.size() < moons:
				out.append(float(g[1]))
		# the rest out past the outer edge, a few pixels apart
		var step := maxf(0.15, 7.0 / r)
		var k2 := 1
		while out.size() < moons:
			out.append(rout + step * float(k2))
			k2 += 1
		out.sort()
		_slots[key] = out
		if _slots.size() > 64:
			_slots.clear()
		return out

	## The moon m's orbit radius on screen round a world drawn at radius r, its
	## moons spaced `gap` apart.
	static func orbit_r(r: float, m: int, gap: float) -> float:
		return r + gap * float(m + 1)

	## Moon orbits stay inside the ship's `ShipFlight.orbit_r`, so the lines never cross it.
	func gap_for(b: SystemLayout.Body, r: float, moons: int) -> float:
		var ship_px: float = b.soi * 0.88 * float(view.zoom)
		var room := (ship_px * 0.85 - r) / float(maxi(moons, 1))
		return clampf(minf(maxf(7.0, r * 0.42), room), 3.0, 1e6)

	func _draw() -> void:
		var L: SystemLayout = view.layout
		if L == null:
			return
		var z: float = view.zoom
		var win: Rect2 = view.window.grow(4.0)
		var o: Vector2 = view.star_screen(-1)
		var hole: Vector2 = view._lines._star_hole()
		var hole2: Vector2 = view._lines._star2_hole()
		var o2: Vector2 = view.star_screen(SystemLayout.STAR_B)
		for i: int in view._views:
			var b := L.bodies[i]
			var v: Node2D = view._views[i]
			var moons: int = v.get("spec").get("moons", 0)
			if moons <= 0:
				continue
			var r: float = view.draw_r(b)
			# where the world's picture (and its rings) is centred, odd sizes and all
			var s: Vector2 = view.world_c(i)
			var r2 := (r + 1.0) * (r + 1.0)
			var gap := gap_for(b, r, moons)
			# a ringed world: in its gaps, at its ring's own squash
			var slots := ring_slots(i, b, r, moons)
			var sq: float = 0.28 if not slots.is_empty() else TILT
			# a world behind the star: its moons are behind it too
			if behind_star(i, s, o, hole, o2, hole2):
				continue
			if view.moon_focus.has(i):
				for m in moons:
					var mr: float = float(slots[m]) * r if not slots.is_empty() else orbit_r(r, m, gap)
					var ea := mr
					var eb := mr * sq
					var per: float = PI * (3.0 * (ea + eb) - sqrt((3.0 * ea + eb) * (ea + 3.0 * eb)))
					var n := clampi(int(per / 1.2), 48, 1600)
					var pts := PackedVector2Array()
					for k in n + 1:
						var a := float(k) / float(n) * TAU
						var q: Vector2 = (s + Vector2(cos(a) * ea, sin(a) * eb)).round()
						# stopped at the world's edge, both sides; off the frame too
						if q.distance_squared_to(s) < r2 or not win.has_point(q):
							if pts.size() > 1:
								draw_polyline(pts, Color(0.52, 0.62, 0.74, 0.16), 1.0)
							pts = PackedVector2Array()
							continue
						if pts.size() > 0 and pts[pts.size() - 1] == q:
							continue
						pts.append(q)
					if pts.size() > 1:
						draw_polyline(pts, Color(0.52, 0.62, 0.74, 0.16), 1.0)
			# the moons: hidden behind the world, over it in front
			# (toward its world's light: star A, or with two suns the light of both)
			var lo: Vector2 = view.light_screen(view.pos[i], s)
			var lit_dir := (lo - s).normalized() if lo.distance_to(s) > 0.5 else Vector2(-1, 0)
			var mrad := clampf(0.35 + 0.42 * z, 0.5, 2.4)
			# (PAINTED: the moon's own ramp, its night leaning to the sky; held poses)
			var mk: Array = view._pt.get("moon", []) if view.painted else []
			# (two suns: its brightest step warmed by its own world's light, as the
			# painted world's is (`tint_at`), not by star A's alone)
			if not mk.is_empty() and view.star2 != null:
				mk = mk.duplicate()
				mk[7] = SectorPaintedS.lit_step(&"moon", view.tint_at(view.pos[i]))
			# (RADIANT: lit as its world is -- grey rock in the star's colour on its lit
			# side, the gas's colour in its shade, through the same gathered tone)
			var c_lit := Color(0.8, 0.83, 0.88)
			var c_dark := Color(0.34, 0.37, 0.43)
			var c_dot := Color(0.48, 0.52, 0.58)
			if view.radiant:
				var tn: Vector3 = view.tint_at(view.pos[i])
				var nf: Vector3 = view.night_fill(view.pos[i])
				c_lit = _tone(Vector3(0.42, 0.42, 0.44) * tn * 1.7 + Vector3(0.42, 0.42, 0.44) * nf * 9.0 * 0.5)
				c_dark = _tone(Vector3(0.42, 0.42, 0.44) * nf * 9.0 * 0.7)
				c_dot = c_dark.lerp(c_lit, 0.45)
			for m in moons:
				var a: float = view.pose(view.t) * (0.25 + m * 0.12) + m * 2.1
				var mr: float = float(slots[m]) * r if not slots.is_empty() else orbit_r(r, m, gap)
				var c: Vector2 = s + Vector2(cos(a) * mr, sin(a) * mr * sq)
				if sin(a) < 0.0 and c.distance_squared_to(s) < r2:
					continue
				if not win.has_point(c):
					continue
				var dim := 1.0 if sin(a) >= 0.0 else 0.8
				# ECLIPSED (every style): a moon slides into its world's shadow and goes
				# dark, and out again, eased and in whole steps
				var ek: float = _ecl.get("%d:%d" % [i, m], 0.0)
				dim *= lerpf(1.0, 0.22, round(ek * 3.0) / 3.0)
				if mrad < 1.2:
					# small: a dot of a pixel or two, its lit pixel toward the star
					var q := c.round()
					var lp := Vector2(signf(lit_dir.x), 0.0) if absf(lit_dir.x) >= absf(lit_dir.y) else Vector2(0.0, signf(lit_dir.y))
					if not mk.is_empty():
						draw_rect(Rect2(q, Vector2(1, 1)), mk[2] if dim > 0.9 else mk[1])
						draw_rect(Rect2(q + lp, Vector2(1, 1)), mk[6] if dim > 0.9 else mk[4])
						continue
					draw_rect(Rect2(q, Vector2(1, 1)), c_dot * Color(dim, dim, dim))
					draw_rect(Rect2(q + lp, Vector2(1, 1)), c_lit * Color(dim, dim, dim))
				else:
					# larger: a tiny disc, its star side lit
					var cq := c.round() + Vector2(0.5, 0.5)
					if not mk.is_empty():
						draw_circle(cq, mrad, mk[1])
						draw_circle(cq + lit_dir * mrad * 0.35, mrad * 0.68, mk[5] if dim > 0.9 else mk[4])
						draw_rect(Rect2((cq + lit_dir * mrad * 0.55).floor(), Vector2(1, 1)), mk[7])
						continue
					draw_circle(cq, mrad, c_dark * Color(dim, dim, dim))
					draw_circle(cq + lit_dir * mrad * 0.35, mrad * 0.68, c_lit * Color(dim, dim, dim))
