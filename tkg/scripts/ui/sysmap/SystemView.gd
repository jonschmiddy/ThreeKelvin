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
## near: [count, faintest, brightest, share with a plus, parallax]. The last is
## a scatter of dim dust motes, nearest of all.
const PARALLAX_VEIL := 0.28
const FIELDS := [[420, 0.08, 0.25, 0.0, 0.03], [260, 0.15, 0.45, 0.03, 0.09],
	[140, 0.3, 0.7, 0.08, 0.22], [50, 0.5, 1.0, 0.2, 0.36], [26, 0.1, 0.22, 0.0, 0.55]]
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
## as the star chart draws it (`sky_nebula.gdshader`), with the old baked gas
## kept faint under it (NEB_GAS_K) and the depth sheets over it; and now and
## then its weather (`_Weather`). `nebsky=0` on a harness's command line shows
## the old sky.
const NEB_SKY := preload("res://shaders/sky_nebula.gdshader")
static var neb_sky := true
const NEB_GAS_K := 0.6
const NEB_DUST_K := 0.55
## how far it slides as the camera pans: nearer than the far stars, farther
## than the veil
const PARALLAX_NEB := 0.1
var _neb_mat: ShaderMaterial
var _neb_t0 := 0.0
var _weather: _Weather
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
const SunViewS := preload("res://scripts/ui/sysmap/SunView.gd")
const PulsarViewS := preload("res://scripts/ui/sysmap/PulsarView.gd")
const CoreViewS := preload("res://scripts/ui/sysmap/CoreView.gd")

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
var _beat_off := 0.0
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
	for c in get_children():
		c.queue_free()
	_views.clear()
	_rq.clear()
	_kq = -1.0
	_sky_z = -1.0
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
	# THE DEPTHS: the far star fields, the veil of nearer gas, the twinkling
	# stars, then the nearer fields and the motes
	_sky_look = SkyBakeS.look_for(n, kind)
	var pal: Array = _sky_look.pal
	var neb_on: bool = neb_sky and _sky_look.has("neb") and not ("nebsky=0" in OS.get_cmdline_user_args())
	if neb_on:
		_sky_look.thick = float(_sky_look.thick) * NEB_GAS_K
		# and its far dust lanes thinner: over the cloud's glow, full strength,
		# they set into black blots in the palette
		_sky_look.dust = float(_sky_look.dust) * NEB_DUST_K
	_neb_mat = null
	_weather = null
	for fi in FIELDS.size():
		var spec: Array = FIELDS[fi]
		var f := _Field.new()
		f.setup(n.index * 31 + 5 + fi * 977, spec[0], spec[1], spec[2], spec[3])
		f.rate = spec[4]
		_fields.append(f)
	_scene.add_child(_fields[0])
	_scene.add_child(_fields[1])
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
		neb.material = _neb_mat
		neb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_scene.add_child(neb)
		_neb_t0 = _Weather.now() - 1.0
		_weather = _Weather.new()
		_weather.setup(self, n.index, int(_sky_look.neb))
		_scene.add_child(_weather)
	depth_k = DEPTH_K if bool(_sky_look.get("nebula", true)) else DEPTH_K_CLEAR
	for a_d in OS.get_cmdline_user_args():
		if (a_d as String).begins_with("depth="):
			depth_k = clampf(float((a_d as String).substr(6)), 0.0, 1.0)
	_depth = []
	if depth_k > 0.0:
		veil.visible = false
		for fd: Array in DEPTH_FAR:
			var fk: Array = fd.duplicate()
			fk[1] = float(fd[1]) * depth_k
			_scene.add_child(_depth_sheet(fk, -1, pal, n.index))
	_twinkle = _Twinkle.new()
	_scene.add_child(_twinkle)
	for fi in range(2, _fields.size()):
		_scene.add_child(_fields[fi])
	_belts = _Belts.new()
	_belts.view = self
	_scene.add_child(_belts)
	_shadows = ColorRect.new()
	_shadows.size = Vector2(960, 540)
	_shadow_mat = ShaderMaterial.new()
	_shadow_mat.shader = SHADOWS
	_shadow_mat.set_shader_parameter("px_scale", 2.0)
	_shadows.material = _shadow_mat
	_shadows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shadows.visible = layout.star != SystemLayout.StarKind.PULSAR
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
		SystemLayout.StarKind.CORE:
			star = CoreViewS.new()
			star.position = Vector2(CX, CY)
		_:
			star = SunViewS.new()
			star.position = Vector2(CX, CY)
			star.call("setup", kind, n.index, layout.star_r)
	# the near sheets: in front of everything the palette sets, sparse wisps
	if depth_k > 0.0:
		for sl in DEPTH_NEAR:
			_scene.add_child(_depth_sheet([-1.0, DEPTH_NEAR_K * depth_k, 0, 260.0, 0.62], sl, pal, n.index))
	_palette = ColorRect.new()
	_palette.size = Vector2(960, 540)
	_palette_mat = ShaderMaterial.new()
	_palette_mat.shader = PALETTE
	_palette_mat.set_shader_parameter("pal_n", 0)
	# its dither cell is one pixel of the half-size picture: a 2x2 block
	_palette_mat.set_shader_parameter("cell", 1)
	_palette.material = _palette_mat
	_palette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scene.add_child(_palette)
	# THE SHADOWS AFTER THE PALETTE, so their fade is not snapped to its colours
	_scene.move_child(_shadows, _palette.get_index())
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
	# THE STAR'S OWN DITHER IN BLOCKS, and the black hole's lens reading the
	# half-size screen a block at a time
	_set_deep(star, "cell", 2)
	_set_deep(star, "px_scale", 2.0)
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
	# THE INSTRUMENTS, single pixels over the place: the fabric, then the orbits
	_fabric = _Fabric.new()
	_fabric.view = self
	add_child(_fabric)
	_lines = _Lines.new()
	_lines.view = self
	add_child(_lines)
	# the moons over them, single pixels like the lines (in the blocky picture
	# their 2x2 orbits read as chunky blue rings across a giant's face)
	_moons = _Moons.new()
	_moons.view = self
	add_child(_moons)
	_step_bodies()
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


## How big a world is drawn on screen now.
func draw_r(b: SystemLayout.Body) -> float:
	if b.world == &"":
		return b.r * zoom
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
	if _kq > 0.0:
		return _kq
	return _star_k_raw()


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
	return maxf(zoom, minf(1.0, MIN_SCREEN_STAR / maxf(layout.star_r if layout != null else 16.0, 1.0)))


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
		star.call("step", t)
	else:
		# ON THE BEAT OF ITS SOUND: the beam points at you on each pass of
		# `amb_pulsar`. The map's clock keeps running smoothly and is only
		# shifted to sit on the loop, so the cloud never jumps.
		var heard := Audio.room_clock(&"amb_pulsar")
		if heard >= 0.0:
			var loop: float = PulsarViewS.LOOP_S
			_beat_off = wrapf(heard - fposmod(t, loop), -loop / 2.0, loop / 2.0)
		star.call("step", t + _beat_off)
		var ang: float = star.get("beam_angle")
		_sky_mat.set_shader_parameter("beam_on", not is_nan(ang))
		_sky_mat.set_shader_parameter("beam_angle", 0.0 if is_nan(ang) else ang)
		var f: float = star.get("sky_flash")
		_flash.visible = f > 0.0
		_flash.color = Color(PulsarViewS.SKY_FLASH_COLOR.r * f, PulsarViewS.SKY_FLASH_COLOR.g * f, PulsarViewS.SKY_FLASH_COLOR.b * f, 1.0)


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
	m.set_shader_parameter("center", Vector2(CX, CY))
	m.set_shader_parameter("seed", float(sd) * 1.37 + float(_depth.size()) * 11.3)
	r.material = m
	_depth.append([m, float(fd[0]), slot, float(fd[1]), sd])
	return r


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
		m.set_shader_parameter("pan", pan)
		m.set_shader_parameter("star_at", o)
		m.set_shader_parameter("alpha", a)
		m.set_shader_parameter("strength", float(e[3]))


## A supernova now, for a harness (SystemShot and FlightClip `nova`): at a
## point on screen, or anywhere clear of the discs.
func nova_now(at := Vector2.INF) -> void:
	if _nova != null:
		_nova.start(at)


## The nebula's weather now, for a harness (SystemShot `wclip`): at a point on
## screen, or anywhere in view.
func weather_now(at := Vector2.INF) -> void:
	if _weather != null:
		_weather.start(at)


## How far the nebula seen from inside has slid.
func neb_off() -> Vector2:
	return block(_cam_pan() * PARALLAX_NEB)


## Move everything to time `t` (the screen sets `t`).
func step() -> void:
	if layout == null:
		return
	var t_step := Time.get_ticks_usec()
	_frame += 1
	_step_bodies()
	var o := origin()
	if layout.star_r > 0.0 and layout.star != SystemLayout.StarKind.PULSAR:
		var rk := _held(layout.star_r * _star_k_raw(), layout.star_r * _kq, 2.0) / layout.star_r
		if layout.star == SystemLayout.StarKind.CORE:
			rk = maxf(rk, 1.0)
		_kq = rk
	_sky_mat.set_shader_parameter("time", t)
	_sky_mat.set_shader_parameter("star_at", o)
	# THE STAR'S LIGHT ON THE SKY held too, stepped 3% at a time: its rays and
	# glow, redrawn at every fraction of a zoom, flickered through the palette
	if _sky_z < 0.0 or absf(zoom / _sky_z - 1.0) > 0.03:
		_sky_z = zoom
	_sky_mat.set_shader_parameter("zoom", _sky_z)
	if layout.star == SystemLayout.StarKind.PULSAR:
		_sky_mat.set_shader_parameter("shell_k", zoom / maxf(home_zoom, 0.01))
		_sky_mat.set_shader_parameter("bake_star", Vector2(CX, CY))
	_sky_mat.set_shader_parameter("sky_off", sky_off())
	if star != null:
		star.position = o
		if star.has_method("set_zoom"):
			star.call("set_zoom", star_k())
	var t_star := Time.get_ticks_usec()
	_step_star()
	tick("star", t_star)
	_twinkle.t = t
	_twinkle.off = block(_cam_pan() * PARALLAX_TWINKLE)
	if _nova != null:
		_nova.off = sky_off()
	for f in _fields:
		f.off = block(_cam_pan() * float(f.rate))
		f.queue_redraw()
	if _veil_mat != null:
		_veil_mat.set_shader_parameter("off", block(_cam_pan() * PARALLAX_VEIL))
	if _neb_mat != null:
		_neb_mat.set_shader_parameter("off", neb_off())
		# the gas's own slow clock, held still with reduced motion
		_neb_mat.set_shader_parameter("time", 0.0 if DisplaySettings.reduced_motion else _Weather.now() - _neb_t0)
	_step_depth(o)
	_twinkle.queue_redraw()
	_belts.queue_redraw()
	# the shadows: each world where its picture is drawn and how big (as
	# `_step_worlds` places it below, held size and odd-size nudge and all), so
	# the shadow leaves the disc at every zoom
	var bp := PackedVector4Array()
	for i in layout.bodies.size():
		var b := layout.bodies[i]
		if b.world != &"" and bp.size() < 12:
			var rr := draw_r(b)
			var hs := Worlds.half_size(b.world, rr)
			var ca: Vector2 = at[i] + Vector2.ONE * float(hs % 2)
			bp.append(Vector4(ca.x, ca.y, rr, world_r(b) * zoom))
	for i in range(bp.size(), 12):
		bp.append(Vector4.ZERO)
	_shadow_mat.set_shader_parameter("bodies", bp)
	_shadow_mat.set_shader_parameter("n_bodies", layout.bodies.filter(func(b): return b.world != &"").size())
	_shadow_mat.set_shader_parameter("star_at", o)
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
		var hs := Worlds.half_size(layout.bodies[i].world, draw_r(layout.bodies[i]))
		v.position = at[i] + Vector2.ONE * float(hs % 2)
		var behind: bool = dep.call(i) < 0.0 and not core
		v.call("step", t, light_for(p), 0.7 + 0.55 * light_at(p.x, p.y), o if behind else Vector2(-9999, -9999), layout.star_r * star_k() if behind else 0.0)
	if core and not core_placed:
		_worlds.move_child(star, -1)
	tick("worlds", t_worlds)
	_moons.queue_redraw()
	_lines.queue_redraw()
	var t_fab := Time.get_ticks_usec()
	_fabric.update()
	tick("fabric", t_fab)
	tick("step (all)", t_step)
	# THE PALETTE, found from the system's own first full picture
	if _ready_sky and not _palette_built and _frame > 6:
		_palette_built = true
		await RenderingServer.frame_post_draw
		# from the place's own half-size picture, so in its pixels
		var img := _scene.get_texture().get_image()
		# a cloud seen from inside has more colours to keep than open space
		var pal: PackedVector3Array = SystemPaletteS.build(img, 0, Vector2(CX, CY) / 2.0, layout.star_r / 2.0, kind, 0,
			SystemPaletteS.K_NEBULA if _neb_mat != null else SystemPaletteS.K)
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

	func setup(v, index: int) -> void:
		view = v
		_rng.seed = hash([index, Time.get_ticks_usec()])
		_next = _now() + _rng.randf_range(FIRST.x, FIRST.y)
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = add

	static func _now() -> float:
		return float(Time.get_ticks_msec()) / 1000.0

	## One now, at `at` on screen, or at a clear point anywhere.
	func start(at := Vector2.INF) -> void:
		var p := at if at != Vector2.INF else _spot()
		if p == Vector2.INF:
			_next = _now() + 20.0
			return
		_ev = {"q": p - off, "t0": _now(), "I": _rng.randf_range(1.4, 1.9), "tint": TINTS[_rng.randi() % TINTS.size()]}

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
		if _ev.is_empty() and now >= _next:
			start()
			_next = now + _rng.randf_range(EVERY.x, EVERY.y)
		if not _ev.is_empty():
			if now - float(_ev.t0) > RISE + HOLD + GLOW:
				_ev = {}
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


## WEATHER IN THE NEBULA (Jon: "maybe weather effects like lightning?"): now
## and then, as the supernovas come, something happens in the cloud round the
## system, drawn by its sky (`sky_nebula.gdshader`, the `w_*` uniforms): in an
## emission or a dark cloud a distant discharge lighting a patch of it from
## within, every 20 to 60 seconds; in a remnant a shock front glimmering along
## the filaments; in a reflection cloud a shaft of a lighting star's light
## sweeping slowly through the haze. A planetary nebula has none; nor does
## anywhere with reduced motion.
class _Weather extends Node:
	## the first comes this long after the map opens, then each this long after
	## the last began, by the cloud's kind (`NebulaField.Kind`)
	const FIRST := Vector2(8.0, 30.0)
	const EVERY := {0: Vector2(20.0, 60.0), 4: Vector2(20.0, 60.0), 3: Vector2(30.0, 80.0), 1: Vector2(35.0, 90.0)}
	## how long each lasts, by kind
	const LASTS := {0: 1.6, 4: 1.6, 3: 6.0, 1: 9.0}
	var view
	var kind := 0
	## a harness's fixed step a frame (SystemShot's clip); 0: real time
	var step_s := 0.0
	var _rng := RandomNumberGenerator.new()
	var _next := 0.0
	var _ev := {}

	func setup(v, index: int, k: int) -> void:
		view = v
		kind = k
		_rng.seed = hash([index, Time.get_ticks_usec(), 7])
		_next = now() + _rng.randf_range(FIRST.x, FIRST.y)

	static func now() -> float:
		return float(Time.get_ticks_msec()) / 1000.0

	## One now, at `at` on screen, or somewhere in view.
	func start(at := Vector2.INF) -> void:
		if not EVERY.has(kind) or view == null:
			return
		var w: Rect2 = view.window
		var p := at
		if p == Vector2.INF:
			p = Vector2(_rng.randf_range(w.position.x + 70.0, w.end.x - 70.0), _rng.randf_range(w.position.y + 50.0, w.end.y - 50.0))
		_ev = {"q": p - view.neb_off(), "t0": now(), "age": 0.0, "k": _rng.randf_range(0.75, 1.0)}

	func _process(_d: float) -> void:
		if view == null or view._neb_mat == null:
			return
		var m: ShaderMaterial = view._neb_mat
		var t := now()
		if DisplaySettings.reduced_motion:
			_ev = {}
		elif _ev.is_empty() and t >= _next and EVERY.has(kind):
			start()
			var ev: Vector2 = EVERY[kind]
			_next = t + _rng.randf_range(ev.x, ev.y)
		if not _ev.is_empty():
			_ev.age = float(_ev.age) + step_s if step_s > 0.0 else t - float(_ev.t0)
			if float(_ev.age) > float(LASTS[kind]):
				_ev = {}
		if _ev.is_empty():
			m.set_shader_parameter("w_k", 0.0)
			return
		m.set_shader_parameter("w_at", _ev.q)
		m.set_shader_parameter("w_age", float(_ev.age))
		m.set_shader_parameter("w_k", float(_ev.k))


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
		for s in _stars:
			var p := Vector2(fposmod(s[0] + off.x, TW) - ox, fposmod(s[1] + off.y, TH) - oy).floor()
			if p.x < -2.0 or p.y < -2.0 or p.x > 962.0 or p.y > 542.0:
				continue
			var I: float = s[2]
			var c: Vector3 = Vector3(0.03, 0.04, 0.07).lerp(s[3], I)
			var col := Color(c.x, c.y, c.z)
			var q := (p / 2.0).floor() * 2.0
			draw_rect(Rect2(q, Vector2(2, 2)), col)
			if s[4]:
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
				var lit := Color(litv.x, litv.y, litv.z)
				var dark := Color("#3e444c")
				if b.index == view.belt_lit and view.belt_t > 0.0:
					lit = lit.lerp(Color.WHITE, 0.45 * view.belt_t)
					dark = dark.lerp(lit, 0.6 * view.belt_t)
				var sx := -1 if x > 0.0 else 1
				# in blocks of 2x2, as the whole place is
				if big < 0.86:
					draw_rect(Rect2(s, Vector2(2, 2)), lit if shade < 0.35 else dark)
				elif big < 0.97:
					draw_rect(Rect2(s, Vector2(4, 2)), dark)
					draw_rect(Rect2(s + Vector2(2 if sx > 0 else 0, 0), Vector2(2, 2)), lit)
				else:
					var tw := int(floor(view.t * 0.8 + i)) & 1
					draw_rect(Rect2(s - Vector2(2, 2), Vector2(6, 4)), Color("#4a5058"))
					draw_rect(Rect2(s + Vector2(sx * 2 * (1 - tw), -2), Vector2(2, 2)), Color("#b0b6be"))
					draw_rect(Rect2(s + Vector2(-sx * 2, 0), Vector2(2, 2)), Color("#2a2e34"))


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
	var _meshes := {}
	var _level := -1
	var _mat: ShaderMaterial

	func _init() -> void:
		_mat = ShaderMaterial.new()
		_mat.shader = FABRIC
		material = _mat

	## The grid at spacing 30 / 2^level, out to where it has faded.
	func _mesh(level: int) -> ArrayMesh:
		if _meshes.has(level):
			return _meshes[level]
		var L: SystemLayout = view.layout
		var E: float = L.edge + 20.0
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
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = pts
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
		_meshes[level] = m
		return m

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
			var s: Vector2 = view.at[i] + Vector2.ONE * float(Worlds.half_size(b.world, r) % 2)
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
			for m in moons:
				var a: float = view.t * (0.25 + m * 0.12) + m * 2.1
				var mr: float = float(slots[m]) * r if not slots.is_empty() else orbit_r(r, m, gap)
				var c: Vector2 = s + Vector2(cos(a) * mr, sin(a) * mr * sq)
				if sin(a) < 0.0 and c.distance_squared_to(s) < r2:
					continue
				if not win.has_point(c):
					continue
				var dim := 1.0 if sin(a) >= 0.0 else 0.8
				if mrad < 1.2:
					# small: a dot of a pixel or two, its lit pixel toward the star
					var q := c.round()
					var lp := Vector2(signf(lit_dir.x), 0.0) if absf(lit_dir.x) >= absf(lit_dir.y) else Vector2(0.0, signf(lit_dir.y))
					draw_rect(Rect2(q, Vector2(1, 1)), Color(0.48, 0.52, 0.58) * Color(dim, dim, dim))
					draw_rect(Rect2(q + lp, Vector2(1, 1)), Color(0.82, 0.85, 0.9) * Color(dim, dim, dim))
				else:
					# larger: a tiny disc, its star side lit
					var cq := c.round() + Vector2(0.5, 0.5)
					draw_circle(cq, mrad, Color(0.34, 0.37, 0.43) * Color(dim, dim, dim))
					draw_circle(cq + lit_dir * mrad * 0.35, mrad * 0.68, Color(0.8, 0.83, 0.88) * Color(dim, dim, dim))
