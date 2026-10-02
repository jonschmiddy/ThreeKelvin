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
const PARALLAX_TWINKLE := 0.16
## MORE DEPTHS (Jon: "can we have more layers for the background parallax"): a
## veil of faint gas in front of the far nebula, and star fields from far to
## near: [count, faintest, brightest, share with a plus, parallax]. The last is
## a scatter of dim dust motes, nearest of all.
const PARALLAX_VEIL := 0.28
const FIELDS := [[420, 0.08, 0.25, 0.0, 0.03], [260, 0.15, 0.45, 0.03, 0.09],
	[140, 0.3, 0.7, 0.08, 0.22], [50, 0.5, 1.0, 0.2, 0.36], [26, 0.1, 0.22, 0.0, 0.55]]
const VEIL := preload("res://shaders/sky_veil.gdshader")
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
## The half-size picture the place is drawn into.
var _scene: SubViewport
var _belts: _Belts
var _shadows: ColorRect
var _shadow_mat: ShaderMaterial
var _star_layer: Node2D
## The star's own painter: a SunView, a PulsarView, or a CoreView.
var star: Node2D
var _flash: ColorRect
var _beat_off := 0.0
var _palette: ColorRect
var _palette_mat: ShaderMaterial
var _lines: _Lines
var _fabric: _Fabric
var _worlds: Node2D
var _moons: _Moons
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
	# THE DEPTHS: the far star fields, the veil of nearer gas, the twinkling
	# stars, then the nearer fields and the motes
	var pal: Array = SkyBakeS.PULSAR_PAL if kind == "PULSAR" else SkyBakeS.PALS[n.index % 4]
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
	_moons = _Moons.new()
	_moons.view = self
	_scene.add_child(_moons)
	# THE INSTRUMENTS, single pixels over the place: the fabric, then the orbits
	_fabric = _Fabric.new()
	_fabric.view = self
	add_child(_fabric)
	_lines = _Lines.new()
	_lines.view = self
	add_child(_lines)
	_step_bodies()
	# NO PICTURE TO READ BACK HEADLESS. The bots and the harnesses still build
	# this screen; its layout and its beacons are all they use.
	if headless():
		return
	_bake = SkyBakeS.new()
	await _bake.make(self, n.index, kind, n.in_nebula, layout.edge, CX, CY, TILT)
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
	return maxf(b.r, min_r) if b.world != &"" else b.r


## Where the star is on screen.
func origin() -> Vector2:
	return (Vector2(CX, CY) + pan).round()


## How far the sky has slid.
func sky_off() -> Vector2:
	return block((pan * PARALLAX).clamp(-Vector2.ONE * SkyBakeS.M, Vector2.ONE * SkyBakeS.M))


## A point on the place's grid of 2x2 blocks.
static func block(p: Vector2) -> Vector2:
	return (p / 2.0).floor() * 2.0


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
		at.append(screen(p.x, p.y).round())


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


## Move everything to time `t` (the screen sets `t`).
func step() -> void:
	if layout == null:
		return
	var t_step := Time.get_ticks_usec()
	_frame += 1
	_step_bodies()
	var o := origin()
	_sky_mat.set_shader_parameter("time", t)
	_sky_mat.set_shader_parameter("star_at", o)
	_sky_mat.set_shader_parameter("zoom", zoom)
	_sky_mat.set_shader_parameter("sky_off", sky_off())
	if star != null:
		star.position = o
		if star.has_method("set_zoom"):
			star.call("set_zoom", zoom)
	var t_star := Time.get_ticks_usec()
	_step_star()
	tick("star", t_star)
	_twinkle.t = t
	_twinkle.off = block(pan * PARALLAX_TWINKLE)
	for f in _fields:
		f.off = block(pan * float(f.rate))
		f.queue_redraw()
	if _veil_mat != null:
		_veil_mat.set_shader_parameter("off", block(pan * PARALLAX_VEIL))
	_twinkle.queue_redraw()
	_belts.queue_redraw()
	# the shadows: each world on the plane, and how wide it is
	var bp := PackedVector4Array()
	for i in layout.bodies.size():
		var b := layout.bodies[i]
		if b.world != &"" and bp.size() < 12:
			bp.append(Vector4(pos[i].x, pos[i].y, world_r(b) * zoom, 0.0))
	for i in range(bp.size(), 12):
		bp.append(Vector4.ZERO)
	_shadow_mat.set_shader_parameter("bodies", bp)
	_shadow_mat.set_shader_parameter("n_bodies", layout.bodies.filter(func(b): return b.world != &"").size())
	_shadow_mat.set_shader_parameter("star_at", o)
	_shadow_mat.set_shader_parameter("zoom", zoom)
	# THE WORLDS DRAWN AGAIN AT THE NEW SIZE, not stretched
	var t_resize := Time.get_ticks_usec()
	if absf(zoom - _drawn_zoom) > 0.001:
		_drawn_zoom = zoom
		for i: int in _views:
			var bw := layout.bodies[i]
			_views[i].call("set_world", bw.world, bw.seed, world_r(bw) * zoom)
	tick("world resize", t_resize)
	var t_worlds := Time.get_ticks_usec()
	# the worlds, nearest drawn last; one behind the star hidden by its disc --
	# except the black hole's, which is drawn between the two groups instead
	var core := layout.star != SystemLayout.StarKind.PULSAR
	var order := range(layout.bodies.size())
	order.sort_custom(func(a, b2): return pos[a].y < pos[b2].y)
	var core_placed := false
	for k in order.size():
		var i: int = order[k]
		if not _views.has(i):
			continue
		var v: Node2D = _views[i]
		var p := pos[i]
		if core and not core_placed and p.y >= 0.0:
			_worlds.move_child(star, -1)
			core_placed = true
		_worlds.move_child(v, -1)
		v.position = at[i]
		var behind := p.y < 0.0 and not core
		v.call("step", t, light_for(p), 0.7 + 0.55 * light_at(p.x, p.y), o if behind else Vector2(-9999, -9999), layout.star_r * zoom if behind else 0.0)
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
		var pal: PackedVector3Array = SystemPaletteS.build(img, 0, Vector2(CX, CY) / 2.0, layout.star_r / 2.0, kind, 0)
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
			for i in int(300.0 * view.zoom):
				var a := R.next() * TAU + spin * (0.9 + R.next() * 0.2)
				var rr := b.orbit + (R.next() - 0.5) * 22.0 * (0.5 + R.next())
				var big := R.next()
				var shade := R.next()
				var lift := (R.next() - 0.5) * 2.0
				var x := cos(a) * rr
				var z := sin(a) * rr
				var s: Vector2 = view.block(view.screen(x, z, lift))
				var litv: Vector3 = view.tone(x, z, Vector3(0.66, 0.68, 0.72) if shade < 0.5 else Vector3(0.52, 0.54, 0.58))
				var lit := Color(litv.x, litv.y, litv.z)
				var dark := Color("#3e444c")
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
			var r: float = view.world_r(view.layout.bodies[i]) * view.zoom + 1.5
			if sp.distance_squared_to(view.at[i]) < r * r:
				return true
		return false

	## The star's hole in the lines: its disc, or the black hole's disc and glow.
	func _star_hole() -> Vector2:
		var L: SystemLayout = view.layout
		var z: float = view.zoom
		if L.star == SystemLayout.StarKind.CORE:
			return Vector2(116.0 * z, 116.0 * TILT * z + 22.0 * z)
		return Vector2(L.star_r * z + 2.0, L.star_r * z + 2.0)

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
			# a point every few pixels of the ring as drawn, not three a pixel of orbit
			var n := clampi(int(b.orbit * view.zoom * 0.9), 48, 1600)
			var own: bool = view._views.has(bi)
			var own_r: float = view.world_r(view.layout.bodies[bi]) * view.zoom + 1.5
			var a0: float = b.phase + (view.t / b.period) * TAU
			var pts := PackedVector2Array()
			var cols := PackedColorArray()
			for i in n + 1:
				var a := float(i) / float(n) * TAU
				var sp: Vector2 = view.screen(cos(a) * b.orbit, sin(a) * b.orbit)
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
				pts.append(sp)
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
		var stp := 5.0 if level == 0 else 2.5
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
		var level := clampi(int(floor(log(z) / log(2.0))), 0, 2)
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
		_mat.set_shader_parameter("hole", Vector2(116.0 * z, 116.0 * view.TILT * z + 22.0 * z) if core else Vector2(L.star_r * z + 2.0, L.star_r * z + 2.0))
		var worlds := PackedVector3Array()
		for i: int in view._views:
			if worlds.size() < 16:
				worlds.append(Vector3(view.at[i].x, view.at[i].y, view.world_r(L.bodies[i]) * z + 1.5))
		var nwo := worlds.size()
		worlds.resize(16)
		_mat.set_shader_parameter("worlds", worlds)
		_mat.set_shader_parameter("n_worlds", nwo)


# ---------------------------------------------------------------- moons
class _Moons extends Node2D:
	var view

	func _draw() -> void:
		var L: SystemLayout = view.layout
		for i in L.bodies.size():
			var b := L.bodies[i]
			if not view._views.has(i):
				continue
			var v: Node2D = view._views[i]
			var moons: int = v.get("spec").get("moons", 0)
			var s: Vector2 = view.at[i]
			var z: float = view.zoom
			for m in moons:
				var mr0: float = (view.world_r(b) + 5.0 + m * 4.0) * z
				var nn := int(floor(mr0 * 3.0))
				var k := 0
				while k < nn:
					var aa := float(k) / nn * TAU
					if not (sin(aa) < 0.0 and absf(cos(aa)) * mr0 < view.world_r(b) * z):
						draw_rect(Rect2(view.block(s + Vector2(cos(aa) * mr0, sin(aa) * mr0 * 0.4)), Vector2(2, 2)), Color("#3c5a7c", 0.7))
					k += 2
			for m in moons:
				var a: float = view.t * (0.25 + m * 0.12) + m * 2.1
				var mr: float = (view.world_r(b) + 5.0 + m * 4.0) * z
				draw_rect(Rect2(view.block(s + Vector2(cos(a) * mr, sin(a) * mr * 0.4)), Vector2(2, 2)), Color("#cfd6de") if sin(a) > 0.0 else Color("#7a8490"))
