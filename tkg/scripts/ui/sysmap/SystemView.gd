extends Control

## THE PICTURE OF ONE SYSTEM, as the approved mockup draws it (scratchpad
## `sysmap/template.html`, `frame()`), in its order:
##   1. the sky: its own nebula, baked once, its gas drifting (`SkyBake`,
##      `sky.gdshader`), a few stars twinkling;
##   2. the asteroid belts, lit warmer and brighter near the star;
##   3. each world's shadow thrown across the plane away from the star;
##   4. the star;
##   5. THE PALETTE PASS: all of the above set to the system's own short
##      palette (`SystemPalette`, `map_palette.gdshader`);
##   6. the faint grey fabric of space sinking under the star and each body,
##      and the faint grey orbits, each with a trail behind its body -- after
##      the palette, so faint lines are not rounded away;
##   7. the worlds (`PlanetView`, `ShatteredView`) in their own colours, nearest
##      last, a world behind the star hidden by its disc; their moons.
## The beacons, the ship, the selection and the panel are the screen's.
##
## Everything is in game pixels on the 960 x 540 canvas, the orbital plane seen
## at a slant (`TILT`). THE CAMERA: the map zooms (`zoom`, 1 to 4) and pans
## (`pan`), so a point (x, z) on the plane is at origin() + (x, z * TILT) * zoom
## on screen, with the star at origin(). Zoomed, nothing is stretched: the
## worlds, the star and the lines are drawn again at the new size, and the sky
## slides behind them by a tenth of the pan (Jon: "a parallax background").

## The panel sits beside the map now, not over it.
const PANEL := 0
## THE STAR IN THE MIDDLE (Jon: "can we center the star"); the screen centres
## this point in its frame.
const CX := 480
const CY := 270
const TILT := 0.38
## THE SKY IN LAYERS, like the star chart's (Jon: "the parallax background needs
## to be at multiple layers"): for a pixel of pan, the baked nebula and its faint
## stars slide this far, a field of stars (with the twinkling ones) further, and
## a sparse field of nearer, brighter stars further still. Each reads as its own
## depth because each moves at its own speed.
const PARALLAX := 0.05
## THE SKY IS AT INFINITY, SO ZOOMING DOES NOT MOVE IT (Jon: "When I zoom in,
## the stars in the background of the sector map move a LOT ... The panning
## movement makes sense for the parallax, just not the zoom"): the layers slide
## by where the camera looks on the plane (the pan over the zoom), not by the
## pan in screen pixels -- which grew with the zoom while the view held a world
## or the ship, and slid the stars hundreds of pixels. PARALLAX_AT is the zoom at
## which a pixel of pan slides each layer by its rate, as it always did.
const PARALLAX_AT := 0.5
const PARALLAX_TWINKLE := 0.16
## MORE DEPTHS (Jon: "can we have more layers for the background parallax"): a
## veil of faint gas in front of the far nebula, and star fields from far to
## near: [count, faintest, brightest, share with a plus, parallax]. Five depths
## of stars (Jon: "No distant stars or galaxies parallax in the background"),
## the nearer bigger, warmer and sliding more; the last a scatter of dim dust
## motes, nearest of all. Behind them all the distant galaxies (`SkyGalaxies`).
const PARALLAX_VEIL := 0.28
const FIELDS := [[420, 0.08, 0.25, 0.0, 0.03], [260, 0.15, 0.45, 0.03, 0.09],
	[140, 0.3, 0.7, 0.08, 0.22], [50, 0.5, 1.0, 0.2, 0.36], [22, 0.6, 1.0, 0.7, 0.46], [26, 0.1, 0.22, 0.0, 0.55]]
const SkyGalaxiesS := preload("res://scripts/ui/sysmap/SkyGalaxies.gd")
var _galaxies: Node2D
const VEIL := preload("res://shaders/sky_veil.gdshader")
## DUST IN DEPTH (Jon: "can we make the space dust of the sectors ...
## volumetric? ... I almost want the sectors and galaxies to look fluffy and
## deep"; he picked C, both): sheets of dust at their own distances, each sized
## and slid by where the camera is (`_step_depth`) -- wisps behind the plane,
## fluffy masses lit from the star's side, and sparse wisps in front that you
## pass through as you zoom.
##
## HOW MUCH, ONE DIAL: 0 is the map as it was, 1 every sheet at full strength;
## each sheet's strength is its full strength times DEPTH_K. Jon picked 0.9, to
## match the star chart's. A harness or a try-out takes `-- depth=K`.
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
## THE NEBULA SEEN FROM INSIDE (Jon: "YES THAT WOULD BE SO COOL"): in a
## nebula's systems the sky is the cloud itself, by its kind and its colours,
## as the star chart draws it (`sky_nebula.gdshader`), lit by the system's sun,
## with the depth sheets over it; and now and then its weather (`SkyWeather`).
## `nebsky=0` on a harness's command line shows the old sky. (Before SIMPLIFIED the
## old baked gas was kept faint under it, at 0.6, its dust at 0.55: the cloud
## carries all of both now.)
const NEB_SKY := preload("res://shaders/sky_nebula.gdshader")
static var neb_sky := true
## SIMPLIFIED (the rendering style Jon kept from the showcase as direction C,
## "Alive", and the default): the cloud is baked once (`SkyBake.field`) and lit
## every frame by the system's own sun, its gas streaming; the old gas and dust
## of the bake under it are gone (the cloud carries all of it), and so is the
## sky's own glow round the star (the cloud is lit by it instead).
## The style setting itself is `DisplaySettings.render_style` (`style()`); the
## screen draws the system again when it changes (`Sig.render_style_changed`).
const STYLE_SIMPLIFIED := &"simplified"
## LEGACY (`legacy`, `is_legacy()`): the sector map as it was before SIMPLIFIED
## -- the old cloud (`sky_nebula_legacy.gdshader`, its gas now streaming on
## SIMPLIFIED's current), the old gas and dust of the bake kept faint under it
## (NEB_GAS_K, NEB_DUST_K), the sky's own glow round the star, the old dust
## sheets, palette, belts and pulsar web -- with what SIMPLIFIED brought that
## every style shares: direction C's black hole (`CoreLegacy`), the sun's breath
## and prominences, a flare brightening the worlds, the pulsar's beam lighting
## the worlds and the belt, and the weather.
const STYLE_LEGACY := &"legacy"
const NEB_SKY_LEGACY := preload("res://shaders/sky_nebula_legacy.gdshader")
const NEB_GAS_K := 0.6
const NEB_DUST_K := 0.55
## this system drawn in LEGACY (set as it is shown)
var legacy := false
## PAINTED (`painted`, `is_painted()`; `SectorPainted`): direction B, "a pixel
## artist's hand". The far picture is SIMPLIFIED's, drawn into its own viewport
## and painted on the scene's curated palette; the sun, the worlds, their rings
## and shadows, the belts, the hole and the pulsar paint themselves; the life
## of the place is drawn as hand animation, in held poses (`pose`).
const STYLE_PAINTED := &"painted"
const SectorPaintedS := preload("res://scripts/ui/sysmap/SectorPainted.gd")
## this system drawn in PAINTED (set as it is shown)
var painted := false
## RADIANT (`radiant`, `is_radiant()`): direction A, "light through gas". The
## sky is SIMPLIFIED's cloud (so every event of the weather lands where it
## does), lit as a volume the sun shines through: the worlds throw true shadow
## shafts through the lit gas, the dust between a place and the sun dims its
## light and reddens what shows through it, a flare lights the gas, a strike's
## light scatters, a pulsar's beams light a fog; a clear sky keeps its plane's
## faint dust lens (`sky_nebula` and `sky.gdshader`, `radiant`); a moon
## goes dark in its giant's shadow; a world's air glows at its limb when lit
## from behind.
const STYLE_RADIANT := &"radiant"
## how many bodies throw shadows at once: the worlds, then their moons
const SHADOW_CASTERS := 24
var radiant := false
## the painted pass's viewports and materials (`SectorPainted.build`)
var _pt := {}
## the emission cloud's bubble round the sun, on the plane: a sphere in the
## system, so the worlds never slide across its wall as the map zooms
var bubble_r := 400.0
## A CLOUD'S RESERVED STEPS in the palette (C's shared tokens), by kind: the
## emission bubble's dark teal (its glow falls to a dark thin gas, and without
## them the outer bubble set to one teal plate), the strike's white-hot core and
## deep H-alpha steps, and dark wine and violet steps so dust in shadow never
## snaps to the void; the reflection haze's light turning blue, and its deep
## navy; the core's disc colours and its cool far smoke (5)
const C_RESERVED := {
	# (the strike's pale pinks are left out: in the palette they took the cloud's
	# brightest rose for themselves and set it as a candy-pink plate; its deep
	# H-alpha steps instead, so the rose keeps its depth)
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
## and the hot points at the heart of a few of the cloud's events (a new star,
## the pearls' beads, the fan's hidden star), drawn over the depth sheets as the
## twinkling stars are: under them the dust dimmed a white star to a grey speck
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
## THE PLACE IN 2x2 BLOCKS (Jon: "everything looking like B would homogenize the
## look"): the sky, its stars, the star, the worlds, their rings and moons, the
## belts and the shadows are drawn into a picture half the size and shown at
## twice, so all of it sits on one grid of 2x2 blocks. The orbits, the fabric,
## the beacons, the cursor and the words stay single pixels on top, as the
## chart's markings do over its galaxy.
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
var _belts: _Belts
var _shadows: ColorRect
var _shadow_mat: ShaderMaterial
var _star_layer: Node2D
## The star's own painter: a SunView, a PulsarView, or a CoreView.
var star: Node2D
var _flash: ColorRect
## A distant supernova, now and then, in the far sky.
var _nova: _Nova
## SIZES HELD IN WHOLE BLOCKS (Jon: "why do the stars and planets kinda shimmer
## when zooming in?"): redrawn at every fraction of a zoom, a world's surface and
## the star's were resampled each frame and their blocks flickered (measured: 110
## of every 1,000 of the star's pixels flipped back each frame of a slow zoom).
## Each now grows a block of radius at a time, and holds it until the zoom has
## moved HOLD_PX on -- the project's rule, whole-pixel steps with hysteresis.
const HOLD_PX := 1.4
var _kq := -1.0
var _sky_z := -1.0
var _rq := {}
## THE SMOOTH ZOOM (Jon: "No matter the rendering style, it seems like the planets
## resize and jitter as you zoom in"). While the zoom moves, each world is drawn at
## its true radius and round its true centre, both continuous (`PlanetView.set_live`:
## the box stays on the grid, the disc moves inside it), and so are the star, the
## moons and the shadows; held sizes and the odd-size nudge made a slow zoom pop a
## block of radius and shift a block now and then. Once the zoom has been still for
## SETTLE_S, everything eases (SETTLE_EASE) back to the crisp held size on the grid.
## Per world: [radius, centre].
##
## THE EASE IS FOR THE SETTLE ALONE (Jon: "When moving the view left to right in
## the sector view, the planets seem to lag behind"): it eased the centre toward
## its place every frame, so a pan, which moves the place, left the picture
## trailing its ring, label and beacons by ~2.4 frames of the pan. Now the live
## centre is carried by however far its place on the grid moved (`_at_last`) --
## the camera's pan and the world's own orbit -- and only what is left, the
## settle onto the held size and the grid, is eased.
var _live := {}
var _at_last := {}
var _klive := -1.0
var _zlast := -1.0
var _zstill := 1.0
const SETTLE_S := 0.18
const LIVE_Q := 0.5
static var _nosmooth := "nosmooth" in OS.get_cmdline_user_args()
const SETTLE_EASE := 0.08
## THE PULSAR'S CENTRE, as a world's (`_live`): where the map truly puts it while
## the zoom moves, carried with its block and settled back onto it after (see
## `_pulsar_at`); and its block last frame
var _plive := Vector2.INF
var _plast := Vector2.ZERO
var _beat_off := 0.0
## how long the pulsar's beat takes to follow the sound's clock (`beat_follow`)
const BEAT_FOLLOW_S := 0.5
var _palette: ColorRect
var _palette_mat: ShaderMaterial
var _lines: _Lines
var _fabric: _Fabric
var _worlds: Node2D
var _moons: _Moons
## THE WORLDS WHOSE MOONS' ORBITS ARE DRAWN: the one pointed at, the one
## selected, the one the ship circles (the overlay sets it each frame); the
## moons themselves always show
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
## THE SMALLEST A WORLD IS DRAWN, in map pixels (Jon's C: at least 5 blocks of
## radius, so a small world reads as a world and not a smudge). Only how big it
## is drawn: its orbit and its place in the layout are its own.
static var min_r := 10.0
## PROFILING (`-- sheet=ZoomProf`): microseconds by part, kept only while on.
static var prof := {}
static var prof_on := false


func _init() -> void:
	size = Vector2(960, 540)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Show system `n`. Returns once its sky is baked.
func show_system(n: MapGen.MapNode) -> void:
	node = n
	layout = SystemLayout.of(n)
	kind = KIND_NAMES[layout.star]
	legacy = is_legacy()
	painted = not legacy and is_painted()
	radiant = not legacy and not painted and is_radiant()
	_pt = {}
	for c in get_children():
		c.queue_free()
	_views.clear()
	_rq.clear()
	_kq = -1.0
	_live.clear()
	_at_last.clear()
	_klive = -1.0
	_zlast = -1.0
	_plive = Vector2.INF
	_sky_z = -1.0
	_rprobe = {}
	_fields.clear()
	_ready_sky = false
	_palette_built = false
	_frame = 0
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
	if layout.star == SystemLayout.StarKind.CORE and not legacy:
		_sky_look.neb = 5
		_sky_look.shape = 0
		_sky_look.hue = Vector3(0.62, 0.32, 0.2)
	var pal: Array = _sky_look.pal
	var neb_on: bool = neb_sky and _sky_look.has("neb") and not ("nebsky=0" in OS.get_cmdline_user_args())
	if neb_on and legacy:
		# LEGACY: the old baked gas kept faint under the cloud, and its far dust
		# lanes thinner (over the cloud's glow, full strength, they set into black
		# blots in the palette)
		_sky_look.thick = float(_sky_look.thick) * NEB_GAS_K
		_sky_look.dust = float(_sky_look.dust) * NEB_DUST_K
	elif neb_on:
		# SIMPLIFIED: the cloud is all of the gas and the dust; the bake under it is
		# the stars and the void alone
		_sky_look.thick = 0.0
		_sky_look.dust = 0.0
	elif not bool(_sky_look.get("nebula", true)) and not legacy:
		# SIMPLIFIED's clear sky (C): clean black, crisp stars in depth, the galaxy's
		# band told by its crowd of faint stars -- no gas, no dust, no glow (any of
		# them this faint set to the palette's first step as a grey smog)
		_sky_look.thick = 0.0
		_sky_look.dust = 0.0
		# (PAINTED's band is set in its band memory by B's own rule, two tones
		# with a checkered edge: `sector_b_state`)
		_sky_look.band_glow = 0.0
	if legacy:
		# (LEGACY: the pulsar's old remnant shell, not SIMPLIFIED's)
		_sky_look.c_remnant = false
	bubble_r = _bubble_r()
	if painted:
		# (PAINTED: B's small teal heart round the sun, the rose lit all round it)
		bubble_r *= 0.45
	_tint = star_light()
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
	# the four far star fields behind the cloud (the showcase's: the gas hides what
	# is behind it, so a cloud is not dusted all over with stars); the nearest
	# stars and the motes in front of it
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
		_neb_mat.shader = NEB_SKY_LEGACY if legacy else NEB_SKY
		_neb_mat.set_shader_parameter("kind", int(_sky_look.neb))
		_neb_mat.set_shader_parameter("shape", int(_sky_look.shape))
		_neb_mat.set_shader_parameter("hue", _sky_look.hue)
		_neb_mat.set_shader_parameter("sd", float(n.index % 97) * 0.731 + 3.0)
		# (a reflection cloud only scatters light: a little dimmer, so it is deep
		# navy far from the sun and never a pale periwinkle wash)
		if not legacy:
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
		for fd: Array in DEPTH_FAR:
			if low and int(fd[2]) == 0:
				continue
			var fk: Array = fd.duplicate()
			fk[1] = float(fd[1]) * depth_k
			_scene.add_child(_depth_sheet(fk, -1, pal, n.index))
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
	_belt_dust.visible = not legacy and layout.bodies.any(func(bb: SystemLayout.Body) -> bool: return bb.kind == &"belt")
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
	# (RADIANT in a cloud: the worlds' shadows are shafts through the lit gas
	# itself, so this flat darkening goes; in a clear sky it carries the world's
	# thin shadow line through the dust lens)
	_shadows.visible = layout.star != SystemLayout.StarKind.PULSAR and not (radiant and _neb_mat != null)
	if radiant:
		_sky_mat.set_shader_parameter("radiant", true)
		_sky_mat.set_shader_parameter("tilt", TILT)
		if _neb_mat != null:
			_neb_mat.set_shader_parameter("radiant", true)
			# (a touch lower: the haze and the shafts' light added a tenth, and round the
			# sun the gas went to a flat pale plate)
			_neb_mat.set_shader_parameter("exposure", float(_neb_mat.get_shader_parameter("exposure")) * 0.86)
	_scene.add_child(_shadows)
	# THE STAR. The sun and the pulsar draw under the palette with the sky; the
	# black hole draws among the worlds (below), since its lens bends the worlds
	# behind it and the worlds in front pass over its disc.
	_star_layer = Node2D.new()
	_scene.add_child(_star_layer)
	match layout.star:
		SystemLayout.StarKind.PULSAR:
			star = PulsarViewS.new()
			star.position = Vector2(CX, CY)
			_star_layer.add_child(star)
			star.call("setup", n.index, Rect2(0, 0, 960, 540))
			# SIMPLIFIED: the remnant round it is the sky's own shell now, filaments and all
			# (C), so the old web of fine threads over it goes: its threads, a sixteenth
			# power of noise read at whole pixels of zoom 1, shimmered through every zoom
			# (half the pulsar's flicker on a slow zoom)
			# (LEGACY keeps its web)
			(star.get("_web_mat") as ShaderMaterial).set_shader_parameter("web_on", legacy)
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
	# the near sheets: in front of everything the palette sets, sparse wisps
	if depth_k > 0.0 and not gfx_low():
		for sl in DEPTH_NEAR:
			_scene.add_child(_depth_sheet([-1.0, DEPTH_NEAR_K * depth_k, 0, 260.0, 0.62], sl, pal, n.index))
	_palette = ColorRect.new()
	_palette.size = Vector2(960, 540)
	_palette_mat = ShaderMaterial.new()
	_palette_mat.shader = PALETTE
	_palette_mat.set_shader_parameter("pal_n", 0)
	# its dither cell is one pixel of the half-size picture: a 2x2 block
	_palette_mat.set_shader_parameter("cell", 1)
	# ROUND A PULSAR the colour is read whole and held (`map_palette`'s `fine` and
	# `hold_k`): its remnant shell grows with the map on every frame of a zoom, and
	# the one-level wobbles of the shell and the dust sheets over it flipped dither
	# pixels back and forth through every zoom (a slow zoom: 0.0042-0.0059 of the
	# map flipping back a frame against the 0.0035 budget; now 0.0008-0.0014).
	# The picture last frame, for the hold, is the place's own, copied each frame.
	# (a harness's `palhold=0`: neither, the pulsar's palette as it was, to measure against)
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
	# THE SHADOWS AFTER THE PALETTE, so their fade is not snapped to its colours
	_scene.move_child(_shadows, _palette.get_index())
	if painted:
		# PAINTED: everything far goes into the far picture, which the band memory
		# reads and the paint pass paints where the cut palette stood -- the pulsar
		# and the worlds' shadows too (the beam in the sky's bands, a shadow a step
		# or two down the ramp it falls on); the belts stay in the place, painting
		# themselves
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
	# THE SUN AND THE BLACK HOLE DRAW AMONG THE WORLDS, between the ones behind
	# and the ones in front: a world behind the sun is covered by its face and
	# lit by its glow, not drawn over it (Jon: "planet that should be behind the
	# sun isn't").
	if layout.star == SystemLayout.StarKind.CORE:
		_worlds.add_child(star)
		if not headless():
			star.call("setup")
	elif layout.star != SystemLayout.StarKind.PULSAR:
		_worlds.add_child(star)
		(star.get("_mat") as ShaderMaterial).set_shader_parameter("half_pal", true)
		# B FOR EVERY SUN (Jon: "the red hypergiant needs to look more pixellated ...
		# I think it would look good for ALL the stars"): its dither in 2x2 blocks
		(star.get("_mat") as ShaderMaterial).set_shader_parameter("cell", 2)
		if painted:
			(star.get("_mat") as ShaderMaterial).set_shader_parameter("painted", true)
	# THE STAR'S OWN DITHER IN BLOCKS, and the black hole's lens reading the
	# half-size screen a block at a time
	_set_deep(star, "cell", 2)
	_set_deep(star, "px_scale", 2.0)
	if painted:
		_set_deep(star, "painted", true)
	if radiant:
		_set_deep(star, "radiant", true)
	for i in layout.bodies.size():
		var b := layout.bodies[i]
		if b.world == &"":
			continue
		var v: Node2D = Worlds.view_for(b.world)
		v.call("set_world", b.world, b.seed, world_r(b))
		# EVERY WORLD IN 2x2 BLOCKS, the small ones too (Jon)
		v.call("set_cell", 2)
		_worlds.add_child(v)
		_views[i] = v
		if painted:
			SectorPaintedS.paint_world(self, v)
		if radiant:
			_set_deep(v, "radiant", true)
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
	await _bake.make(self, n.index, kind, n.in_nebula, layout.edge, CX, CY, TILT, _sky_look)
	_sky_mat.set_shader_parameter("base", _bake.base)
	_sky_mat.set_shader_parameter("gas", _bake.gas)
	_sky_mat.set_shader_parameter("pulsar", kind == "PULSAR")
	_sky_mat.set_shader_parameter("star_col", SkyBakeS.STARCOL.get(kind, SkyBakeS.STARCOL.ORDINARY))
	_sky_mat.set_shader_parameter("margin", float(SkyBakeS.M))
	_sky_mat.set_shader_parameter("simplified", not legacy)
	if _neb_mat != null and legacy:
		# THE OLD CLOUD'S NOISES, baked once (LEGACY), for it to stream on the current
		await _bake.field(self, int(_sky_look.neb), int(_sky_look.shape), float(n.index % 97) * 0.731 + 3.0, Vector2(CX, CY), true)
		_neb_mat.set_shader_parameter("t0", _bake.field0)
		_neb_mat.set_shader_parameter("t1", _bake.field1)
		_neb_mat.set_shader_parameter("ftex", Vector2(SkyBakeS.FIELD_W, SkyBakeS.FIELD_H))
		_neb_mat.set_shader_parameter("fmb", float(SkyBakeS.FIELD_MB))
	elif _neb_mat != null:
		# THE CLOUD, baked once (SIMPLIFIED): its density for the sun to light
		await _bake.field(self, int(_sky_look.neb), int(_sky_look.shape), float(n.index % 97) * 0.731 + 3.0, Vector2(CX, CY))
		_neb_mat.set_shader_parameter("t0", _bake.field0)
		_neb_mat.set_shader_parameter("t1", _bake.field1)
		_neb_mat.set_shader_parameter("t2", _bake.field2)
		_neb_mat.set_shader_parameter("ftex", Vector2(SkyBakeS.FIELD_W, SkyBakeS.FIELD_H))
		_neb_mat.set_shader_parameter("fmb", float(SkyBakeS.FIELD_MB))
		_neb_mat.set_shader_parameter("cc_em", Vector2(CX, CY))
		if painted:
			# PAINTED's cloud built as B's (Jon: "fluffy and full and connected")
			await SectorPaintedS.bake_puffs(self, _bake.field0)
		_neb_mat.set_shader_parameter("bubble_r", bubble_r)
		_neb_mat.set_shader_parameter("star_light", star_light())
		# the sky's own glow round the star is the cloud's light now
		_sky_mat.set_shader_parameter("light_k", 0.0)
	_palette_mat.set_shader_parameter("x0", 0.0)
	_shadow_mat.set_shader_parameter("x0", 0.0)
	_twinkle.stars = _bake.twinkle
	_ready_sky = true


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


func body_kind(b: SystemLayout.Body) -> String:
	if b.world != &"":
		return Worlds.display_name(b.world)
	return {&"belt": "ASTEROID BELT", &"derelict": "DERELICT HULK", &"contact": "CONTACT", &"station": "STATION"}.get(b.kind, "")


static func au(b: SystemLayout.Body) -> String:
	return "%.1f AU" % (b.orbit / 80.0)


## A body's facts for the panel: [label, value] rows.
func facts(b: SystemLayout.Body) -> Array:
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


## How big a pulsar's worlds are drawn against any other system's.
const PULSAR_WORLD_K := 0.45
## the zoom the map opened at (the screen sets it): a pulsar's remnant shell is
## the size it was baked at there, and zooms with the map from it
var home_zoom := 1.0


## THE SMALLEST A WORLD IS DRAWN ON SCREEN, whatever the zoom: zoomed out to the
## whole (three times wider) system a world at its zoomed size is a speck, so it
## stays a few pixels of disc (a giant a little more), redrawn at that size and
## never stretched.
const MIN_SCREEN_R := 5.0
const MIN_SCREEN_R_GIANT := 7.0
const MIN_SCREEN_STAR := 7.0
## the star's eased floor of screen radius, but in LEGACY (px)
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


## How many times its mockup size the star is drawn: the zoom, but never smaller
## than a few pixels of disc; the black hole's trace only exists from 1 up.
## A pulsar grows exactly with the map (`PULSAR_OPEN_K`).
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


## How far world i's picture is from its place on the grid -- where its orbit
## ring, its label and its beacons are drawn (`at`) -- this frame, screen px. 0
## at rest; the zoom's settle eases it back to 0. For the harnesses (`panclip`).
func world_lag(i: int) -> Vector2:
	if not _live.has(i):
		return Vector2.ZERO
	var b := layout.bodies[i]
	var held: float = _rq.get(i, draw_r(b))
	return (_live[i][1] as Vector2) - (at[i] + Vector2.ONE * float(Worlds.half_size(b.world, held) % 2))


## A PULSAR GROWS EXACTLY AS THE MAP DOES (Jon: "Pulsars still act REALLY weird
## when zooming"): its cloud, beams, jets, spray, glow and web, all drawn by
## `PulsarView` at one scale, are that scale times the map's zoom over the
## zoom it opened at -- as its remnant shell in the sky already was
## (`shell_k`). It was the sun's rule, the star's radius held in whole 2x2
## blocks: for a 3 px star that is steps of a third, so the whole pulsar sat
## still while the map zoomed and then jumped half as big again, and below
## zoom 1 it did not shrink at all. At the opening zoom it is drawn as before.
const PULSAR_OPEN_K := 4.0 / 3.0


func _star_k_raw() -> float:
	if layout != null and layout.star == SystemLayout.StarKind.CORE:
		return maxf(zoom, 1.0)
	var sr := maxf(layout.star_r if layout != null else 16.0, 1.0)
	if not legacy:
		# (both prototypes ease the star up to a floor of screen radius, the frame's
		# light source: C's sqrt((r z)^2 + 8^2), B's a little bigger; held at 7 px
		# it read as one more star at the opening zoom)
		return maxf(zoom, sqrt(pow(sr * zoom, 2.0) + STAR_FLOOR * STAR_FLOOR) / sr)
	return maxf(zoom, minf(1.0, MIN_SCREEN_STAR / sr))


## WHERE THE PULSAR IS DRAWN: on the block grid with its orbits at rest, and
## while the zoom moves where the map truly puts it, as a world's picture is
## (`_live`). Rounded to the grid as a wheel zoom carried it across the screen it
## stood still and then hopped a whole block, x and y at different frames, ~8
## times a second on a slow zoom, every layer of it -- core, beams, cloud, its
## light and shell -- ahead of or behind the map by up to a pixel and back. The
## block stays the box's place; the drawing is shifted within it (`sub`). Once
## the zoom is still it is carried with its block and eased onto it.
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


## ROUNDED ONCE, by the caller: the exact pan plus the exact offset. Rounding the
## star's pixel first and adding a fractional offset after rounded twice, and a
## world the camera followed (LOCATION) shook by a pixel every few frames.
func screen(x: float, z: float, dip: float = 0.0) -> Vector2:
	return Vector2(CX, CY) + pan + Vector2(x, z * TILT + dip) * zoom


## How much of the star's light reaches a point on the plane.
static func light_at(x: float, z: float) -> float:
	return 1.0 / (1.0 + (x * x + z * z) / (160.0 * 160.0))


## The light on a body at plane position p: from the star, in screen x, y, z.
static func light_for(p: Vector2) -> Vector3:
	var len := maxf(p.length(), 1.0)
	return Vector3(-p.x / len, -p.y / len * TILT, -p.y / len * 0.5 + 0.42).normalized()


## RADIANT'S SAFETY, the sector's half of the chart's (`ChartSky._radiant_safety`,
## the same budget, `ChartRadiant.budget_ms`, and the same fall-back): the place
## picture's GPU time over its first seconds of drawing is averaged, and if this
## machine cannot hold it the map is drawn SIMPLIFIED from then on, with one line
## in the log. A harness's `style=radiant` is never overruled (it is measuring)
## unless it asks with `radiantprobe=MS`.
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
	if avg > ChartRadiant.budget_ms() and (DisplaySettings.render_style == STYLE_RADIANT or ChartRadiant.probe_forced()):
		push_warning("RADIANT sector measured %.1f ms a frame on this machine; drawing SIMPLIFIED" % avg)
		Run.log_line("RADIANT is too heavy for this machine, so the sector map is drawn SIMPLIFIED.", &"them")
		ChartRadiant.fell_back = true
		if DisplaySettings.render_style == STYLE_RADIANT:
			DisplaySettings.set_render_style(STYLE_SIMPLIFIED)
		else:
			Sig.render_style_changed.emit()


## THE RENDERING STYLE (`DisplaySettings.render_style`): SIMPLIFIED is the
## default; LEGACY, SIMPLIFIED and PAINTED are built; RADIANT is in progress
## (behind `radiant`, not in BUILT).
static func style() -> StringName:
	return DisplaySettings.render_style


## LEGACY: chosen in the settings, or `-- style=legacy` on a harness's command
## line (read raw too, so a harness never has to save the setting).
static func is_legacy() -> bool:
	return style() == STYLE_LEGACY or "style=legacy" in OS.get_cmdline_user_args()


## PAINTED: chosen in the settings, or `-- style=painted` on a harness's command
## line (read raw too, as `ChartPainted.wanted` does).
## RADIANT: chosen in the settings, or `-- style=radiant` on a harness's command line.
static func is_radiant() -> bool:
	# (not once the safety has fallen back this session: the chart's and the
	# sector's share it, `ChartRadiant.fell_back`)
	if ChartRadiant.fell_back:
		return false
	return style() == STYLE_RADIANT or "style=radiant" in OS.get_cmdline_user_args()


static func is_painted() -> bool:
	return style() == STYLE_PAINTED or "style=painted" in OS.get_cmdline_user_args()


## HAND ANIMATION (PAINTED): a clock held in poses, `fps` of them a second, so
## whatever is drawn from it steps from pose to pose and holds each one, as an
## animator draws on twos and threes; the clock itself in the other styles.
func pose(x: float, fps: float = 8.0) -> float:
	return floor(x * fps) / fps if painted else x


## GRAPHICS LOW (`DisplaySettings.graphics_low`; `-- graphics=low` on a
## harness's command line): the cheaper sky -- one read a field, no flow, the
## two fluffy depth sheets alone. Read every frame for the sky, and at a
## system's entry for the sheets.
static func gfx_low() -> bool:
	return DisplaySettings.graphics_low


## THE SUN BREATHES (C): its corona's radius 1 +- 0.06 on a slow noise, the
## light near it with it; held still with reduced motion.
static func breath(time: float) -> float:
	if DisplaySettings.reduced_motion:
		return 1.0
	var n := 0.6 * sin(time / 8.0 * 2.31 + 1.0) + 0.4 * sin(time / 8.0 * 5.17 + 2.0)
	return 1.0 + 0.06 * n


## A PROMINENCE (C): in each slot of 40 s one erupts off the sun's limb at a
## hashed moment -- up over 4 s, held 3, faded over 12 -- at a hashed place on
## its upper limb, height and span: (angle, height in radii, envelope, span).
## None with reduced motion. Its envelope is also the flare's: the worlds' lit
## sides 10% brighter at its height, their auroras flickering.
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


## HOW MUCH OF A PULSAR'S BEAM falls on a thing at screen offset `d` from the
## pulsar (C: the worlds and the belt it sweeps catch its light): 1 on the beam,
## either end of it, falling off over 0.18 rad; caught fast, let go over a third
## of a second, so a sweep reads as light passing and never as a strobe.
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


## THE SKY'S LIGHT ON A WORLD'S NIGHT SIDE (C), linear: what the cloud round a
## world at plane point p glows with -- teal inside an emission cloud's bubble,
## rose outside it, blue in a reflection cloud's haze, the cloud's own colour
## in the others, next to nothing in a clear sky -- more of it nearer the sun.
func night_fill(p: Vector2) -> Vector3:
	var s := Vector2(p.x, p.y * TILT * 1.15) * zoom
	var lz := pow(maxf(zoom, 0.01) / maxf(home_zoom, 0.01), 0.42) * clampf(window.size.x / 700.0, 0.5, 1.4)
	var dl := s.length() / maxf(lz, 0.01)
	var js := 1.0 / (1.0 + pow(dl / 155.0, 2.0))
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
			# (inside the wall as it is drawn: in light px, so its plane radius grows
			# as the map zooms in)
			if p.length() * zoom < bubble_r * home_zoom * pow(maxf(zoom, 0.001) / maxf(home_zoom, 0.001), 0.42):
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


## THE BUBBLE'S RADIUS on the plane: in a gap between orbits, as near as it can
## be to four fifths of the frame at the opening zoom (the showcase's size), so it is a thing in the
## system that no world stands on, with the rose cloud round it in view.
func _bubble_r() -> float:
	var E := layout.edge
	# where it should be: about four fifths of the way to the frame's edge at the
	# opening zoom (which fits the edge, plus 20, into the frame's width)
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
	return best


## The star's colour on things near it; things far from it darker.
func tone(x: float, z: float, base: Vector3) -> Vector3:
	var k := light_at(x, z)
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
			sm.set_shader_parameter("halo_cut", 36.0 if legacy else 72.0)
			if legacy:
				# (LEGACY: the sky's own glow round the sun breathes with it)
				_sky_mat.set_shader_parameter("light_k", lerpf(1.0, breath(t), 0.6))
	else:
		# ON THE BEAT OF ITS SOUND: the beam points at you on each pass of
		# `amb_pulsar`. The map's clock keeps running smoothly and is only
		# shifted to sit on the loop, so the cloud never jumps.
		# (a harness holding the clock -- a clip, a still -- holds the beat with it:
		# the sound still playing out turned the beam under a stopped map)
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


## THE BEAT FOLLOWS THE SOUND, SMOOTHLY (Jon: "the pulsar still slightly jitters
## around when you zoom in"): the sound's clock as read each frame (the playback
## position plus the time since the last mix) is right on average but wobbles by
## a few ms from one frame to the next -- 3.4 ms sd, up to 13 ms, reversing 34
## times a second, measured on this machine -- and set from it every frame the
## beams, which turn once a second, lurched by up to 5 degrees a frame, a tip
## 270 px out shaking by 20 px, more the further in you zoom. Followed over half
## a second the beat still sits on what is heard (the wobble averages out; the
## two clocks run at one rate) and turns as evenly as the frames. A jump -- the
## sound starting, a loop, the system changing -- is taken at once.
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


## One dust sheet: [distance beyond the plane (-1: a near slot), strength, look,
## cloud size, cover].
func _depth_sheet(fd: Array, slot: int, pal: Array, sd: int) -> ColorRect:
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
	m.set_shader_parameter("simplified", not legacy)
	m.set_shader_parameter("dark_col", dl[0])
	m.set_shader_parameter("lit_far", dl[1])
	m.set_shader_parameter("lit_near", dl[2])
	m.set_shader_parameter("wisp_col", dl[3])
	m.set_shader_parameter("center", Vector2(CX, CY))
	m.set_shader_parameter("seed", float(sd) * 1.37 + float(_depth.size()) * 11.3)
	r.material = m
	_depth.append([m, float(fd[0]), slot, float(fd[1]), sd])
	return r


## THE DUST SHEETS' COLOURS in SIMPLIFIED (C), display colours: [the dense core,
## a lit side far from the sun, near it, the wisps], by the sky -- dark wine
## with rose turning teal in an emission cloud, navy and blue in a reflection
## one, near-black and cold round a pulsar, warm round the core, a faint shade
## of the cloud's own colour in the rest, and next to nothing in a clear sky.
func _depth_look() -> Array:
	if layout.star == SystemLayout.StarKind.PULSAR:
		return [Vector3(0.02, 0.03, 0.05), Vector3(0.16, 0.20, 0.26), Vector3(0.22, 0.28, 0.36), Vector3(0.06, 0.07, 0.12)]
	if layout.star == SystemLayout.StarKind.CORE:
		return [Vector3(0.05, 0.02, 0.02), Vector3(0.30, 0.18, 0.10), Vector3(0.45, 0.30, 0.16), Vector3(0.14, 0.08, 0.05)]
	if _neb_mat == null:
		# a clear sky's sheets only darken (C): any light on them this faint set
		# to a grey disc round the sun
		# (never darker than the void itself: set below it, they came out as black
		# blots on the clear sky once its palette kept the true void)
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


## THE DUST SHEETS WHERE THE CAMERA IS: the plane is 1/zoom from it; a sheet
## beyond the plane is smaller and slower (q < 1), one in front bigger and
## faster, and grows past the camera as you zoom in -- faded as it nears it, and
## as it sinks to the plane, while the next one along fades in.
func _step_depth(o: Vector2) -> void:
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
		m.set_shader_parameter("zoom", zoom)
		m.set_shader_parameter("home_zoom", home_zoom)
		m.set_shader_parameter("lscale", clampf(window.size.x / 700.0, 0.5, 1.4))
		m.set_shader_parameter("pan", pan)
		m.set_shader_parameter("star_at", Vector2(CX, CY) + pan)
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
	var o := origin()
	_flare = prominence(pose(t, 6.0)).z if layout.star != SystemLayout.StarKind.PULSAR and layout.star != SystemLayout.StarKind.CORE else 0.0
	if layout.star_r > 0.0 and layout.star != SystemLayout.StarKind.PULSAR:
		var rk := _held(layout.star_r * _star_k_raw(), layout.star_r * _kq, 2.0) / layout.star_r
		if layout.star == SystemLayout.StarKind.CORE:
			rk = maxf(rk, 1.0)
		_kq = rk
	# THE SMOOTH ZOOM: is the zoom moving; the star at its true size while it is
	var dtz := clampf(get_process_delta_time(), 1.0 / 240.0, 0.1)
	if _zlast < 0.0 or absf(zoom - _zlast) > 1e-7:
		_zstill = 0.0 if _zlast >= 0.0 else 1.0
	else:
		_zstill += dtz
	_zlast = zoom
	var ez := 1.0 - exp(-dtz / SETTLE_EASE)
	if layout.star_r > 0.0 and layout.star != SystemLayout.StarKind.PULSAR:
		# (the star in whole blocks of radius even while the zoom moves, but the nearest
		# block, not one held back: its limb between blocks flickered with its corona's
		# own life)
		var kt := maxf(roundf(layout.star_r * _star_k_raw() / 2.0) * 2.0, 2.0) / layout.star_r if zooming() else _kq
		if layout.star == SystemLayout.StarKind.CORE:
			kt = maxf(kt, 1.0)
		if _klive < 0.0 or absf(_klive - kt) < 0.002 * kt:
			_klive = kt
		elif zooming():
			_klive = kt
		else:
			_klive = lerpf(_klive, kt, ez)
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
	_sky_mat.set_shader_parameter("time", pose(t, 4.0))
	# (a pulsar's light and shell, and its whole drawing below, about its own centre)
	var pc := _pulsar_at(o, ez) if layout.star == SystemLayout.StarKind.PULSAR else o
	_sky_mat.set_shader_parameter("star_at", pc)
	# THE STAR'S LIGHT ON THE SKY held too, stepped 3% at a time: its rays and
	# glow, redrawn at every fraction of a zoom, flickered through the palette
	if _sky_z < 0.0 or absf(zoom / _sky_z - 1.0) > 0.03:
		_sky_z = zoom
	_sky_mat.set_shader_parameter("zoom", _sky_z)
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
		if layout.star == SystemLayout.StarKind.PULSAR:
			star.set("sub", pc - o)
		if star.has_method("set_zoom"):
			star.call("set_zoom", star_k())
		if layout.star == SystemLayout.StarKind.CORE and not legacy:
			# THE HOLE AT THE SHOWCASE'S SIZE (the fidelity pass): small at the
			# opening, opening out as the map zooms (as zoom^0.53, a ninth of the frame
			# across at zoom 2); drawn at the old size it filled the frame
			star.set("hole_k", 0.36 * pow(maxf(zoom, 0.01) / maxf(home_zoom, 0.01), 0.53) / maxf(star_k(), 0.01))
			(star.get("_hmat") as ShaderMaterial).set_shader_parameter("warm_glow", true)
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
	if _neb_mat != null and not legacy:
		# THE SUN THAT LIGHTS IT, this frame: where, how far zoomed from the
		# opening, the frame against the showcase's, its breath
		# (the light from where the star truly is, not its pixel: rounded, it jumped
		# a block every few frames of a zoom held on a world while the light opened
		# out smoothly, and the lit gas flickered at every jump)
		_neb_mat.set_shader_parameter("star_at", Vector2(CX, CY) + pan)
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
		_belt_mat.set_shader_parameter("origin", Vector2(CX, CY) + pan)
		_belt_mat.set_shader_parameter("zoom", zoom)
		_belt_mat.set_shader_parameter("tilt", TILT)
	# the shadows: each world where its picture is drawn and how big (as
	# `_step_worlds` places it below, held size and odd-size nudge and all), so
	# the shadow leaves the disc at every zoom
	# THE MOONS THIS FRAME (every style): where each is, and how deep in its
	# world's shadow, for the shadows they cast and the eclipses
	var ml: Array = _moons.positions(get_process_delta_time())
	var bp := PackedVector4Array()
	var rg := PackedFloat32Array()
	for i in layout.bodies.size():
		var b := layout.bodies[i]
		if b.world != &"" and bp.size() < SHADOW_CASTERS:
			var rr := draw_r(b)
			# (the shadow from the world's place on the grid: from its live centre it
			# slid by slivers and its dithered edge flickered through a zoom)
			var ca: Vector2 = at[i] + Vector2.ONE * float(Worlds.half_size(b.world, float(_rq.get(i, rr))) % 2)
			bp.append(Vector4(ca.x, ca.y, rr, world_r(b) * zoom))
			# its rings' shadow too (C), as wide as their outer edge
			var vw: Node2D = _views.get(i)
			rg.append(2.1 if not legacy and vw != null and bool((vw.get("spec") as Dictionary).get("ring", false)) else 0.0)
	# EACH MOON CASTS ITS OWN SHADOW (Jon: "shouldn't moons cast shadows?"), by the
	# worlds' rule from its own size, away from the star
	for mm: Dictionary in ml:
		if bp.size() >= SHADOW_CASTERS:
			break
		if bool(mm.hidden) or not window.grow(8.0).has_point(mm.c):
			continue
		var mc: Vector2 = mm.c
		bp.append(Vector4(mc.x, mc.y, float(mm.mrad), float(mm.mrad)))
		rg.append(0.0)
	var n_cast := bp.size()
	rg.resize(SHADOW_CASTERS)
	_shadow_mat.set_shader_parameter("rings", rg)
	for i in range(bp.size(), SHADOW_CASTERS):
		bp.append(Vector4.ZERO)
	_shadow_mat.set_shader_parameter("bodies", bp)
	_shadow_mat.set_shader_parameter("n_bodies", n_cast)
	_shadow_mat.set_shader_parameter("star_at", o)
	if radiant and _neb_mat != null:
		# RADIANT: the shafts the worlds throw through the lit gas, and a flare
		_neb_mat.set_shader_parameter("r_bodies", bp)
		_neb_mat.set_shader_parameter("r_rings", rg)
		_neb_mat.set_shader_parameter("r_nb", n_cast)
		_neb_mat.set_shader_parameter("r_flare", _flare)
	# THE WORLDS DRAWN AGAIN AT THE NEW SIZE, not stretched
	var t_resize := Time.get_ticks_usec()
	for i: int in _views:
		var bw := layout.bodies[i]
		var least := MIN_SCREEN_R_GIANT if bw.kind == &"giant" else MIN_SCREEN_R
		var was: float = _rq.get(i, -1.0)
		var held := _held(_draw_r_raw(bw), was, minf(least, _draw_r_raw(bw)))
		if held != was:
			_rq[i] = held
			_views[i].call("set_world", bw.world, bw.seed, held)
	tick("world resize", t_resize)
	var t_worlds := Time.get_ticks_usec()
	# the worlds, nearest drawn last; one behind the star hidden by its disc --
	# except the black hole's, which is drawn between the two groups instead
	var core := layout.star != SystemLayout.StarKind.PULSAR
	var order := range(layout.bodies.size())
	var dep := func(i: int) -> float: return depth(pos[i])
	order.sort_custom(func(a, b2): return dep.call(a) < dep.call(b2))
	var core_placed := false
	for k in order.size():
		var i: int = order[k]
		if not _views.has(i):
			continue
		var v: Node2D = _views[i]
		var p := pos[i]
		if core and not core_placed and dep.call(i) >= 0.0:
			_worlds.move_child(star, -1)
			core_placed = true
		_worlds.move_child(v, -1)
		# its box's corner on the grid too: an odd half-size moves it a unit
		var hs := Worlds.half_size(layout.bodies[i].world, float(_rq.get(i, draw_r(layout.bodies[i]))))
		v.position = at[i] + Vector2.ONE * float(hs % 2)
		if _live.has(i) and v.has_method("set_live"):
			v.call("set_live", float(_live[i][0]), (_live[i][1] as Vector2) - v.position)
		var behind: bool = dep.call(i) < 0.0 and not core
		# (lit as the showcase lit them: a world far out still bright on its day side)
		var kl := (0.7 + 0.55 * light_at(p.x, p.y)) if legacy else (0.95 + 0.35 * light_at(p.x, p.y))
		if layout.star == SystemLayout.StarKind.PULSAR:
			# THE BEAM CATCHES IT (C): dim between passes, lit as a beam sweeps by
			var bo := beam_on(at[i] - o, i)
			# (PAINTED: caught in three poses, held, never a smooth glide)
			if painted:
				bo = round(bo * 2.0) / 2.0
			kl = 0.55 + 0.9 * bo
		v.call("step", t, light_for(p), kl, o if behind else Vector2(-9999, -9999), layout.star_r * star_k() if behind else 0.0)
		# LIT BY ITS OWN STAR (C): the lit side in its colour, the night side
		# filled by the sky round it, brighter at a flare's height
		var vm: ShaderMaterial = v.get("_mat")
		if vm != null:
			if not legacy:
				vm.set_shader_parameter("star_tint", _tint)
				vm.set_shader_parameter("night_fill", night_fill(p))
			vm.set_shader_parameter("flare", _flare)
			vm.set_shader_parameter("lift", 0.0 if legacy else 1.0)
			# ITS MOONS' SHADOWS ON ITS FACE (Jon: "shouldn't moons cast eclipses on
			# their planets?"): each moon's place about the world (screen px, x
			# right, y down, z toward you) and its size
			var msh := PackedVector4Array()
			for mm: Dictionary in ml:
				if int(mm.i) == i and msh.size() < 4:
					var rel: Vector2 = (mm.c as Vector2) - world_c(i)
					msh.append(Vector4(rel.x, rel.y, float(mm.z), float(mm.mrad)))
			var nm := msh.size()
			msh.resize(4)
			vm.set_shader_parameter("moon_sh", msh)
			vm.set_shader_parameter("n_moon_sh", nm)
	if core and not core_placed:
		_worlds.move_child(star, -1)
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
		await RenderingServer.frame_post_draw
		# from the place's own half-size picture, so in its pixels
		var img := _scene.get_texture().get_image()
		# a cloud seen from inside has more colours to keep than open space
		# and the weather's own colours, so a strike's core or an echo's ring
		# has its step without taking any from the sky
		var extra: PackedVector3Array = PackedVector3Array() if no_ramp or _weather == null else SkyWeatherS.ramp(_weather.sky)
		var cloud := _neb_mat != null
		# the distant galaxies' own tones in a clear sky: a few blocks each, the cut
		# never found them, and they set to the void (in a cloud they are faint
		# behind it, and seven more steps there set its gas flickering between them)
		if not cloud:
			for gt: Vector3 in SkyGalaxiesS.TONES:
				extra.append(gt)
		if legacy:
			# LEGACY: the weather's colours alone, as before
			pass
		elif cloud:
			# SIMPLIFIED's cloud: its own reserved steps, so its gradients never plate
			# (RADIANT's core: A's heart is a rose-brown haze; SIMPLIFIED's cool violet
			# steps caught it and set it mauve)
			var res: Array = R_CORE if radiant and int(_sky_look.neb) == 5 else C_RESERVED.get(int(_sky_look.neb), [])
			for h: String in res:
				var cr := Color(h)
				extra.append(Vector3(cr.r, cr.g, cr.b))
			# and the sun painter's warm steps (not its greys and blues, which caught
			# the cloud): the weather's fire -- a jet's head, a fan of amber, an
			# ember, a flier -- keeps its colour
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
		var pal: PackedVector3Array = SystemPaletteS.build(img, 0, Vector2(CX, CY) / 2.0, layout.star_r / 2.0, kind, 0,
			SystemPaletteS.K_NEBULA if cloud else SystemPaletteS.K, extra, legacy or not cloud,
			not legacy and cloud and int(_sky_look.neb) <= NebulaField.Kind.REFLECTION, SystemPaletteS.MERGE, not legacy)
		var arr := PackedVector3Array(pal)
		arr.resize(72)
		_palette_mat.set_shader_parameter("pal", arr)
		_palette_mat.set_shader_parameter("pal_n", mini(72, pal.size()))


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
## A DISTANT SUPERNOVA (Jon: "these stars in the sector view are weird. can we
## have them be the distant supernovas maybe? Like have them flash in briefly and
## then disappear. it can be a rare event"). Once a minute to three, at random
## (its own generator, seeded from the system and the clock, so it keeps time
## with nothing), a point in the far sky brightens over 0.3 s into a bright star
## with four spikes, holds a second, and fades over four, a faint tinted glow
## left behind it a little longer. It slides with the far sky, under the gas, the
## star and the worlds, in 2x2 blocks the palette pass maps like the rest, and
## never comes up where a disc is. Silent.
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
			if p.distance_to(view.origin()) < view.layout.star_r * view.star_k() + 40.0:
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
## A field of stars at one depth: points, and a few with a plus round them,
## scattered over a tile larger than the view that wraps round as the field
## slides, so it never runs out however far the map pans.
class _Field extends Node2D:
	const TW := 1280.0
	const TH := 800.0
	var off := Vector2.ZERO
	## how far it slides for a pixel of pan
	var rate := 0.0
	var _stars: Array = []
	## THE WEATHER: a MICROLENS, one star swelling and settling ({"i": star,
	## "A": how many times as bright}); and a GLOBULE's hole, the stars behind
	## its centre (x, y on screen, radius) not drawn
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
## A band of rocks, lit on the side that faces the star, warmer and brighter
## near it; a few bigger ones tumbling.
class _Belts extends Node2D:
	var view

	func _draw() -> void:
		var t0 := Time.get_ticks_usec()
		_rocks()
		view.tick("belts", t0)

	func _rocks() -> void:
		var L: SystemLayout = view.layout
		for b in L.bodies:
			if b.kind != &"belt":
				continue
			var R := Worlds.XRng.new(floor(b.orbit * 13.0))
			var spin: float = view.t / b.period * TAU
			var pulsar: bool = L.star == SystemLayout.StarKind.PULSAR
			var o: Vector2 = view.origin()
			# more rocks the closer you look, the first 300 always the same
			for i in int(300.0 * maxf(view.zoom, 0.8)):
				var a := R.next() * TAU + spin * (0.9 + R.next() * 0.2)
				var rr := b.orbit + (R.next() - 0.5) * 33.0 * (0.5 + R.next())
				var big := R.next()
				var shade := R.next()
				var lift := (R.next() - 0.5) * 2.0
				var x := cos(a) * rr
				var z := sin(a) * rr
				var s: Vector2 = view.block(view.screen(x, z, lift))
				var litv: Vector3 = view.tone(x, z, Vector3(0.66, 0.68, 0.72) if shade < 0.5 else Vector3(0.52, 0.54, 0.58))
				if view.painted:
					# PAINTED (B): each rock lit on its star side, in the rock's own ramp
					# (its night and dusk leaning to the sky), brightest where we see its
					# lit face full; round a pulsar, caught by the beam in held poses
					var rk: Array = view._pt.rock
					var lv := (0.62 + 0.38 * clampf(-sin(a) * 0.9 + 0.3, 0.0, 1.0)) * (0.85 + 0.3 * shade)
					if pulsar:
						lv *= 0.55 + 0.9 * round(view.beam_on(s - o) * 2.0) / 2.0
					var ci := 6 if lv > 0.98 else (5 if lv > 0.82 else (4 if lv > 0.66 else 3))
					if b.index == view.belt_lit and view.belt_t > 0.5:
						ci = mini(ci + 2, 7)
					var plt: Color = rk[ci]
					var pdk: Color = rk[maxi(ci - 2, 1)]
					var psx := -1 if x > 0.0 else 1
					if big < 0.86:
						draw_rect(Rect2(s, Vector2(2, 2)), plt if shade < 0.8 else pdk)
					elif big < 0.97:
						draw_rect(Rect2(s, Vector2(4, 2)), pdk)
						draw_rect(Rect2(s + Vector2(2 if psx > 0 else 0, 0), Vector2(2, 2)), plt)
					else:
						draw_rect(Rect2(s - Vector2(2, 2), Vector2(6, 4)), rk[maxi(ci - 1, 2)])
						draw_rect(Rect2(s + Vector2(psx * 2, -2), Vector2(2, 2)), rk[mini(ci + 1, 7)])
						draw_rect(Rect2(s + Vector2(-psx * 2, 0), Vector2(2, 2)), rk[1])
					continue
				if view.legacy:
					# LEGACY's grey rubble, as before -- lit as the pulsar's beam sweeps
					# across it (as the worlds are)
					var bk: float = view.beam_on(s - o) if pulsar else 0.0
					var lkv: Vector3 = litv * ((0.7 + 0.8 * bk) if pulsar else 1.0)
					var lt := Color(minf(lkv.x, 1.0), minf(lkv.y, 1.0), minf(lkv.z, 1.0))
					var dk := Color("#3e444c").lerp(lt, 0.35 * bk)
					if b.index == view.belt_lit and view.belt_t > 0.0:
						lt = lt.lerp(Color.WHITE, 0.45 * view.belt_t)
						dk = dk.lerp(lt, 0.6 * view.belt_t)
					var sxl := -1 if x > 0.0 else 1
					if big < 0.86:
						draw_rect(Rect2(s, Vector2(2, 2)), lt if shade < 0.35 else dk)
					elif big < 0.97:
						draw_rect(Rect2(s, Vector2(4, 2)), dk)
						draw_rect(Rect2(s + Vector2(2 if sxl > 0 else 0, 0), Vector2(2, 2)), lt)
					else:
						var twl := int(floor(view.t * 0.8 + i)) & 1
						draw_rect(Rect2(s - Vector2(2, 2), Vector2(6, 4)), Color("#4a5058").lerp(lt, 0.3 * bk))
						draw_rect(Rect2(s + Vector2(sxl * 2 * (1 - twl), -2), Vector2(2, 2)), Color("#b0b6be").lerp(Color.WHITE, 0.4 * bk))
						draw_rect(Rect2(s + Vector2(-sxl * 2, 0), Vector2(2, 2)), Color("#2a2e34"))
					continue
				# LIT RUBBLE (C), never a ring of dark specks: each rock's lit face in
				# the star's colour, brightest where we see it full (the far side of
				# the belt, beyond the star), its night face only a step down;
				# round a pulsar, lit as the beam sweeps across it
				var phase := 0.62 + 0.38 * clampf(-sin(a) * 0.9 + 0.3, 0.0, 1.0)
				var alb := 0.78 + 0.32 * shade
				var kb := 1.0
				if pulsar:
					kb = 0.45 + 1.1 * view.beam_on(s - o)
				# (light rock, lighter than the gas it sits in: grey rock dimmed with
				# distance read as dark specks against a lit cloud)
				var sc3: Vector3 = SkyBakeS.STARCOL.get(view.kind, SkyBakeS.STARCOL.ORDINARY)
				litv = Vector3(0.80, 0.78, 0.74).lerp(sc3, 0.3) * (0.78 + 0.22 * view.light_at(x, z))
				litv = (litv * (phase * alb * kb)).clamp(Vector3.ZERO, Vector3.ONE)
				var lit := Color(litv.x, litv.y, litv.z)
				var dark := lit.darkened(0.18)
				if b.index == view.belt_lit and view.belt_t > 0.0:
					lit = lit.lerp(Color.WHITE, 0.45 * view.belt_t)
					dark = dark.lerp(lit, 0.6 * view.belt_t)
				var sx := -1 if x > 0.0 else 1
				# in blocks of 2x2, as the whole place is
				if big < 0.86:
					draw_rect(Rect2(s, Vector2(2, 2)), lit if shade < 0.85 else dark)
				elif big < 0.97:
					draw_rect(Rect2(s, Vector2(4, 2)), dark)
					draw_rect(Rect2(s + Vector2(2 if sx > 0 else 0, 0), Vector2(2, 2)), lit)
				else:
					var tw := int(floor(view.t * 0.8 + i)) & 1
					draw_rect(Rect2(s - Vector2(2, 2), Vector2(6, 4)), dark)
					draw_rect(Rect2(s + Vector2(sx * 2 * (1 - tw), -2), Vector2(2, 2)), lit.lightened(0.15))
					draw_rect(Rect2(s + Vector2(-sx * 2, 0), Vector2(2, 2)), dark.darkened(0.3))


# ---------------------------------------------------------------- the fabric and the orbits
## THE FABRIC OF SPACE, faint and grey (Jon: "more smooth looking, more simple,
## gray, and understated"): one grid across the system, turned 45 degrees so
## none of its lines runs straight away from the eye (those read as vertical
## lines), sinking into a funnel under the star -- softly capped, so the black
## hole's does not swallow the view -- and a dent under each body. Its lines are
## worked out ten times a second (the bodies move slowly) and drawn every frame.
## THE ORBITS: faint grey rings, a soft lighter trail behind each body.
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

	func _draw() -> void:
		var L: SystemLayout = view.layout
		var cam := Vector3(view.zoom, view.pan.x, view.pan.y)
		var t1 := Time.get_ticks_usec()
		var win: Rect2 = view.window.grow(4.0)
		var o: Vector2 = view.origin()
		var hole := _star_hole()
		for bi in L.bodies.size():
			var b := L.bodies[bi]
			if b.kind == &"belt":
				continue
			# A POINT EVERY PIXEL AND A BIT of the ellipse as drawn (Jon: "why are some
			# of the planet orbits wobbly?"): its perimeter on screen, Ramanujan's
			var ea: float = b.orbit * view.zoom
			var eb: float = ea * TILT
			var per: float = PI * (3.0 * (ea + eb) - sqrt((3.0 * ea + eb) * (ea + 3.0 * eb)))
			var n := clampi(int(per / 1.2), 64, 3000)
			var own: bool = view._views.has(bi)
			var own_r: float = view.draw_r(view.layout.bodies[bi]) + 1.5
			var a0: float = b.phase + (view.t / b.period) * TAU
			var pts := PackedVector2Array()
			var cols := PackedColorArray()
			for i in n + 1:
				var a := float(i) / float(n) * TAU
				var op: Vector3 = b.orbit_point(a)
				var sp: Vector2 = view.screen(op.x, op.z)
				# off the frame, in the star, or on its own world (the only one on its ring)
				var off_world := own and sp.distance_squared_to(view.at[bi]) < own_r * own_r
				if not win.has_point(sp) or pow((sp.x - o.x) / hole.x, 2.0) + pow((sp.y - o.y) / hole.y, 2.0) < 1.0 or off_world:
					if pts.size() > 1:
						draw_polyline_colors(pts, cols, 1.0)
					pts = PackedVector2Array()
					cols = PackedColorArray()
					continue
				var behind := fposmod(a0 - a, TAU)
				var tr := pow(1.0 - behind / 2.1, 1.6) if behind < 2.1 else 0.0
				var c := Vector3(0.55, 0.58, 0.62).lerp(Vector3(0.82, 0.85, 0.9), tr)
				# ON WHOLE PIXELS of the screen: the rings are drawn over the picture at
				# its full size (snapped to the half-size picture's 2x2 blocks, as they
				# were for a round, they stair-stepped and wobbled)
				var q: Vector2 = sp.round()
				if pts.size() > 0 and pts[pts.size() - 1] == q:
					continue
				pts.append(q)
				cols.append(Color(c.x, c.y, c.z, 0.14 + tr * 0.38))
			if pts.size() > 1:
				draw_polyline_colors(pts, cols, 1.0)
		view.tick("lines draw", t1)


# ---------------------------------------------------------------- the fabric
## THE FABRIC OF SPACE, faint and grey (Jon: "more smooth looking, more simple,
## gray, and understated"): one grid across the system, turned 45 degrees so no
## line runs straight away from the eye, sinking into a funnel under the star
## and a dent under each body. Laid out once as a mesh of short lines on the
## plane, finer as the zoom doubles; `map_fabric.gdshader` sinks, places and
## fades every point each frame, so moving the camera costs the CPU nothing.
class _Fabric extends Node2D:
	var view
	var _level := -1
	var _mat: ShaderMaterial
	## THE GRIDS, KEPT FOR EVERY MAP, laid out off the main thread (Jon on 2C:
	## "still has a small delay/hitch"). The finest grid is a quarter of a
	## million short lines; laid out on the spot, the frame the zoom first
	## crossed into it took 78 ms -- the map's first deep frame on the way out
	## of LOCAL every time (each map is new), and once mid-dive on the way in.
	## A grid depends only on its spacing and how far out it reaches, so it is
	## kept for the session, by level and reach (rounded up: past the edge the
	## shader fades it to nothing, so a larger one draws the same), and every
	## level of a new map's reach is started on worker threads the moment the
	## map is laid out (`warm`), long before the camera gets there.
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
		var pts := PackedVector2Array()
		for dir in 2:
			var a := ceilf(-lim / gap) * gap
			while a <= lim:
				var b := -lim
				while b < lim:
					var u0 := a if dir == 1 else b
					var v0 := b if dir == 1 else a
					var u1 := a if dir == 1 else b + stp
					var v1 := b + stp if dir == 1 else a
					var p0 := Vector2((u0 - v0) * kk, (u0 + v0) * kk)
					var p1 := Vector2((u1 - v1) * kk, (u1 + v1) * kk)
					if p0.length() < E or p1.length() < E:
						pts.append(p0)
						pts.append(p1)
					b += stp
				a += gap
		out[0] = pts

	## Every level of a map's grid that is not kept yet, started on worker threads.
	static func warm(edge: float) -> void:
		var E := reach_for(edge)
		# (only the levels it draws: zoomed out past 1x it draws none)
		for level in range(0, 3):
			var k := _key(level, E)
			if _meshes.has(k) or _jobs.has(k):
				continue
			var out: Array = [null]
			var id := WorkerThreadPool.add_task(_points.bind(level, E, out), false, "map fabric grid")
			_jobs[k] = {"id": id, "out": out}

	## The grid at spacing 30 / 2^level, out to where it has faded: kept, or
	## finished from its worker (waited for if it is still going), or laid out
	## here if nothing started it.
	func _mesh(level: int) -> ArrayMesh:
		var L: SystemLayout = view.layout
		var E := reach_for(L.edge)
		var k := _key(level, E)
		if _meshes.has(k):
			return _meshes[k]
		var pts: PackedVector2Array
		if _jobs.has(k):
			var job: Dictionary = _jobs[k]
			_jobs.erase(k)
			WorkerThreadPool.wait_for_task_completion(int(job.id))
			pts = (job.out as Array)[0]
		else:
			var out: Array = [null]
			_points(level, E, out)
			pts = out[0]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = pts
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
		if _meshes.size() >= MESHES_MAX:
			_meshes.erase(_meshes.keys()[0])
		_meshes[k] = m
		return m

	## The grids finished on their workers since last frame, made into meshes
	## while nothing is waiting on them (one a frame).
	static func collect() -> void:
		for k: String in _jobs.keys():
			var job: Dictionary = _jobs[k]
			if not WorkerThreadPool.is_task_completed(int(job.id)):
				continue
			_jobs.erase(k)
			WorkerThreadPool.wait_for_task_completion(int(job.id))
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = (job.out as Array)[0]
			var m := ArrayMesh.new()
			m.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
			if _meshes.size() >= MESHES_MAX:
				_meshes.erase(_meshes.keys()[0])
			_meshes[k] = m
			return

	func _draw() -> void:
		if _level >= 0:
			draw_mesh(_mesh(_level), null)

	## Each frame: the camera, the wells where the bodies are now, and the clear
	## discs of the star and the worlds. Redrawn only when the spacing changes.
	func update() -> void:
		var L: SystemLayout = view.layout
		var z: float = view.zoom
		var level := clampi(int(floor(log(z) / log(2.0))), -2, 2)
		if level != _level:
			_level = level
			queue_redraw()
		_mat.set_shader_parameter("origin", Vector2(view.CX, view.CY) + view.pan)
		_mat.set_shader_parameter("zoom", z)
		_mat.set_shader_parameter("tilt", view.TILT)
		_mat.set_shader_parameter("edge", L.edge + 20.0)
		_mat.set_shader_parameter("star_d", L.star_mass * 0.8)
		_mat.set_shader_parameter("star_w", 46.0 + L.star_r * 1.4)
		var wells := PackedVector4Array()
		for i in L.bodies.size():
			var b := L.bodies[i]
			if b.mass > 0.0 and wells.size() < 16:
				wells.append(Vector4(view.pos[i].x, view.pos[i].y, b.mass * 0.9, b.well_w))
		var nw := wells.size()
		wells.resize(16)
		_mat.set_shader_parameter("wells", wells)
		_mat.set_shader_parameter("n_wells", nw)
		var core := L.star == SystemLayout.StarKind.CORE
		var sk: float = view.star_k()
		_mat.set_shader_parameter("hole", Vector2(116.0 * sk, 116.0 * view.TILT * sk + 22.0 * sk) if core else Vector2(L.star_r * sk + 2.0, L.star_r * sk + 2.0))
		var worlds := PackedVector3Array()
		for i: int in view._views:
			if worlds.size() < 16:
				worlds.append(Vector3(view.at[i].x, view.at[i].y, view.draw_r(L.bodies[i]) + 1.5))
		var nwo := worlds.size()
		worlds.resize(16)
		_mat.set_shader_parameter("worlds", worlds)
		_mat.set_shader_parameter("n_worlds", nwo)


# ---------------------------------------------------------------- moons
## A WORLD'S MOONS, over the picture at full size like the orbit lines (Jon:
## "still weird rings on this giant"): each a small round dot lit on the star's
## side, its orbit a faint line of single pixels at the map's own slant -- drawn
## only for a world pointed at, selected or circled, and never across the
## world's disc. A moon behind the world is hidden by it; one in front passes
## over it. The orbits spread with the world's size, so they never bunch.
class _Moons extends Node2D:
	var view

	## RADIANT's gathered tone: linear light to an sRGB colour, never a flat white
	static func _tone(c: Vector3) -> Color:
		return Color(pow(1.0 - exp(-c.x * 1.15), 1.0 / 2.2), pow(1.0 - exp(-c.y * 1.15), 1.0 / 2.2), pow(1.0 - exp(-c.z * 1.15), 1.0 / 2.2))
	## how deep each moon ("world:moon") sits in its world's shadow, eased
	var _ecl := {}

	## THE MOONS THIS FRAME, as `_draw` places them: for each, its world, the
	## world's centre and drawn radius, the moon on screen and how far toward you
	## (px), its drawn radius, whether its world hides it; and its ECLIPSE, how
	## deep it sits in its world's shadow (the light toward the star from it
	## passes within the world), eased over a quarter second.
	func positions(dt: float) -> Array:
		var out: Array = []
		var L: SystemLayout = view.layout
		if L == null:
			return out
		var z: float = view.zoom
		var o: Vector2 = view.origin()
		var hole: Vector2 = view._lines._star_hole()
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
			if pow((s.x - o.x) / hole.x, 2.0) + pow((s.y - o.y) / hole.y, 2.0) < 1.0:
				continue
			var L3: Vector3 = view.light_for(view.pos[i]).normalized()
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

	## THE MOONS OF A RINGED WORLD SIT IN ITS GAPS (Jon: "The orbits of the moons
	## on a ringed planet don't follow the gaps in the rings"), as shepherd moons
	## do, or out past the outer edge -- never across a band. Read from the same
	## strip the painted rings draw from (`Rings.build`, at the size the world is
	## drawn), in world radii; the widest gaps first, then outside it all. Empty
	## for a world without painted rings.
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

	## How far apart the moons' orbits are: spread with the world's size, but
	## all of them inside the orbit a ship rides out at the edge of its ring
	## (`ShipFlight.orbit_r`), so the lines never cross it.
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
		var o: Vector2 = view.origin()
		var hole: Vector2 = view._lines._star_hole()
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
			var behind_star: bool = pow((s.x - o.x) / hole.x, 2.0) + pow((s.y - o.y) / hole.y, 2.0) < 1.0
			if behind_star:
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
			var lit_dir := (o - s).normalized() if o.distance_to(s) > 0.5 else Vector2(-1, 0)
			var mrad := clampf(0.35 + 0.42 * z, 0.5, 2.4)
			# (PAINTED: the moon's own ramp, its night leaning to the sky; held poses)
			var mk: Array = view._pt.get("moon", []) if view.painted else []
			# (RADIANT: lit as its world is -- grey rock in the star's colour on its lit
			# side, the gas's colour in its shade, through the same gathered tone)
			var c_lit := Color(0.8, 0.83, 0.88)
			var c_dark := Color(0.34, 0.37, 0.43)
			var c_dot := Color(0.48, 0.52, 0.58)
			if view.radiant:
				var tn: Vector3 = view._tint
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
