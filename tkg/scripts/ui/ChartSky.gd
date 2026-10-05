class_name ChartSky
extends Node2D

## THE STAR CHART'S SKY, in the sector map's style: Jon's pick of the galaxy
## mockups ("sector style, a LOT", round three, 2x2 blocks, at the sector map's
## angle). Everything a MapChart draws behind its systems is drawn here: the
## galaxy, its stars, the black hole and its lens, the gas swirling round it,
## and the sky behind.
##
## TWO HALVES.
##   * ONCE A GALAXY, on the GPU, a BAKE (`_begin_bake` and the stages after
##     it): the chart's own star field (`MapChart._build_stars`) re-tilted to
##     the sector map's angle, added up and blurred into the galaxy's standing
##     fields -- its stars' light, its arms, its dark clouds, its gas -- in the
##     mockup's own pixels (the chart's opening view), and a short palette for
##     each zoom (`_make_palette`), from the galaxy's own colours. Three frames,
##     then read back into textures and kept for the run (`_baked`).
##   * EVERY FRAME, a half-size viewport (`_vp`) the chart shows at twice its
##     size, so each of its pixels is one 2x2 block: the field
##     (`chart_field.gdshader`, every block worked out afresh, so the zoom
##     redraws and the galaxy turns with nothing stretched or rebuilt), the
##     bright stars (`chart_galaxy_stars`), the lens (`chart_hole_lens`), the
##     hole (`chart_hole`), then the palette (`chart_palette`).
##
## THE TURN. The galaxy turns as one, once every `TURN_MINUTES` (`MapChart.turn`),
## a view-only angle from the chart's clock: systems, routes and rings turn with
## it (MapChart's projection). Only inside the innermost ring does it go faster,
## climbing toward the hole (`_law`), so no system ever leaves the arm and the
## gas it started on.

const BAKE := Vector2i(896, 616)
const BAKE_O := Vector2(448.0, 308.0)
## The probe a palette is measured from: the zoom's window round the centre,
## one block in four.
const PROBE := Vector2i(224, 154)
## The zooms the mockup was built at; each has its own palette and its own grid
## of extra stars. A zoom between two uses the nearer.
const LEVELS: Array[float] = [0.42, 0.59, 0.84, 1.18, 1.66, 2.35, 3.3, 4.65, 6.0]
const TILT := 0.38
const DISC := 2.05
## One turn of the whole galaxy, in minutes: twelve hours, so at a glance it
## does not seem to move at all. The mockup's dial said half an hour, which
## read as "like 5x too fast"; two and a half hours was "still rotating too
## fast" -- and what was moving then was mostly not the disc but the climb
## round the hole (see `params`, `rb`) and the gas's brightness waves.
const TURN_MINUTES := 720.0
const OMEGA := TAU / (TURN_MINUTES * 60.0)
## The hole is traced once (`core_trace.gdshader`) at this radius and read at
## every other size.
const TRACE_RH := 40.0
## The hole's size against the galaxy's own (`hole_r`), the same at every zoom.
const HOLE_K := 2.0
## How far out the hole's disc reaches, in hole radii: 3, down from 4 when the
## hole stopped shrinking as you zoom in, so at the closest zoom the disc
## does not fill the whole chart.
const DISC_K := 3.0
## How far the dust is spread in the bake, in its pixels (see `_stage_fields`).
const DUST_SPREAD := 2.0

const SPLAT_SH := preload("res://shaders/chart_bake_splat.gdshader")
const BLUR_SH := preload("res://shaders/chart_bake_blur.gdshader")
const BASE_SH := preload("res://shaders/chart_bake_base.gdshader")
const FIELD_SH := preload("res://shaders/chart_field.gdshader")
const STARS_SH := preload("res://shaders/chart_galaxy_stars.gdshader")
const LENS_SH := preload("res://shaders/chart_hole_lens.gdshader")
const HOLE_SH := preload("res://shaders/chart_hole.gdshader")
const PAL_SH := preload("res://shaders/chart_palette.gdshader")
const LUT_SH := preload("res://shaders/chart_palette_lut.gdshader")
const TRACE_SH := preload("res://shaders/core_trace.gdshader")
const SystemPaletteS := preload("res://scripts/ui/sysmap/SystemPalette.gd")

## The extra stars' colours, and the star sets every palette carries.
const STAR_WARM := [Color8(196, 214, 255), Color8(255, 242, 214), Color8(255, 214, 140),
	Color8(250, 160, 80), Color8(214, 92, 40)]
const STAR_COOL := [Color8(184, 208, 244), Color8(232, 238, 246), Color8(250, 222, 150),
	Color8(240, 150, 80)]
## The hole's own colours (`core_hole.gdshader`), darkest first.
const BHPAL := [Color8(30, 8, 4), Color8(74, 20, 6), Color8(132, 40, 12), Color8(194, 74, 20),
	Color8(236, 122, 38), Color8(255, 176, 84), Color8(255, 220, 150), Color8(255, 246, 226)]

## Each galaxy's bake, by `galaxy_key`: textures, constants, palettes. A run is
## one galaxy, so a new one drops the rest (`MapChart._build_stars`).
static var _baked: Dictionary = {}
## HOW THE NAMED CLOUDS ARE DRAWN: 4, each kind remade for the gas volume
## (`chart_field`'s `neb_v2`; Jon, 2026-10-04: "These are nice"). The others,
## for comparison with `-- sheet=ChartLook neblook=N`: 1 "of the galaxy" (his
## pick of 2026-10-03), 0 each kind's shape with an edge and a moat ("look
## bad"), 2 "pixel-art objects", 3 "quiet until wanted".
static var nebula_look := 4
## (4: the clouds remade for the new chart, while Jon picks -- vivid, each
## kind as the thing itself, rising and churning with the gas.
## `-- sheet=ChartLook neblook=4`.)

## HOW MANY STARS ("I honestly feel like there might be too many stars?"):
## 4, about an eighth of what shipped -- level 3 was still "about 2x too
## high", Jon -- with true white kept for the few brightest; 3 about a
## quarter, his first pick ("stars as accents, so the gas and dust carry the
## galaxy"); 2 about half; 1 as it first shipped, kept so the others can
## still be photographed. Thinned by brightness, never at random: the
## galaxy's own stars keep their brightest (and every globular cluster), the
## extra stars deep in lose their dim half first, the sky behind its dimmest
## colours first. `-- sheet=ChartLook starlevel=N`.
static var star_level := 4

## HOW THE BLACK HOLE IS DRAWN ("black hole still kinda weird", Jon), while
## he picks (`chart_hole.gdshader`'s `look`): 0 as it is (the disc laid over
## the bulge, the ring over the top); 1 the sector map's hole (`core_hole`,
## his pick #11), its wide disc and added gas and glow; 2 the textbook look,
## the disc crossing in front of a round shadow ringed all the way round.
## `-- sheet=ChartLook holelook=N`.
static var hole_look := 0
## HOW THE HOLE'S LIGHT IS SHADED, in the shape Jon picked (look 0), lit like
## his reference ("clean, flat, concentric bands"), while he picks: 0 as it
## is, stepped and dithered; 1 flat bands in the hole's warm colours; 2 flat
## bands in cream, pink, magenta and purple. `-- sheet=ChartLook holebands=N`.
static var hole_bands := 0
## How far C's light goes toward the warm bands ("can we do steps between
## this?"): 0 as it is, 1 the warm bands, between a blend of the two -- the
## streaks smoothing, fewer steps, less dither, the outer band melting into the
## bulge less, the ring, outline and glow coming in. `holeband=0.5`. Jon's
## pick, 0.25: the streaks kept, eight cleaner steps, little dither, still
## melting at the edge, and no bright line round the shadow.
static var hole_band_amt := 0.25

## DEPTH ("I almost want the sectors and galaxies to look fluffy and deep",
## `chart_field`'s `depth_look`): 3, Jon's pick, both -- the layers you pass
## through and the fluffy lit cloud -- as strong as `depth_amt`; 0 as it was;
## 1 the layers alone; 2 the cloud alone. `-- sheet=ChartLook depthlook=N`.
static var depth_look := 3
## How strong look 3 is, both of its parts alike: 0 none, 1 both in full.
## 0.9, Jon's pick from four levels (2026-10-04: "let's do 0.9. That looks
## great"). `-- sheet=ChartLook depthamt=A`.
static var depth_amt := 0.9

## THE DISC AS A VOLUME, while Jon picks ("I want the actual arms of the
## galaxy and the galaxy itself to have a height", `chart_field`'s `vol_h`):
## 0 flat, as it is; 1 a thin slab; 2 medium; 3 tall billows.
## 3, Jon's pick (2026-10-04: "I like 3"). `-- sheet=ChartLook volume=N`.
static var volume_look := 3
const VOLUME_H := [0.0, 4.0, 7.0, 11.0]
## AND AS GAS, while Jon picks ("too solid?", `chart_field`'s `gas_k`): 0 the
## solid surface, as it is; 1 thin gas; 2 puffy gas; 3 dense puffy gas.
## 3 for now, the billowing column of the pick page, for Jon to try in game.
## `-- sheet=ChartLook gas=N`.
static var gas_look := 3
## Whether the gas churns ("billow slightly and move", Jon): its puffs swell
## and lean, its wisps drift, slowly, each region on its own phase; still when
## reduced motion is on. On, for Jon to try in game. `-- sheet=ChartLook billow`.
static var gas_billow := true
## THE GLOBULAR CLUSTERS ("these pixelated clusters of stars ... look like
## popcorn", Jon): 1, each a soft warm glow, brightest in the middle, a couple
## of its stars seen at its edge only when you are close; 0 as they were, every
## star a block. `-- sheet=ChartLook clusters=N`.
static var cluster_look := 1
const GAS_K := [0.0, 0.06, 0.16, 0.35]
## The second banding's colours, kept in the palette when it is drawn.
const BHUE := [Color8(255, 236, 214), Color8(246, 160, 178), Color8(208, 78, 150),
	Color8(136, 46, 130), Color8(74, 26, 90), Color8(26, 10, 34)]

## The hole's trace, once a process: it depends on nothing but the angle.
## The star field as textures, by `MapChart._star_key`: a chart opened again
## on the same galaxy finds them made.
static var _pts_cache: Dictionary = {}
## The one node that runs bakes (`_request_bake`), under the scene's root, so
## a bake finishes even if the chart that asked for it has closed.
static var _baker: ChartSky = null
static var _trace: ImageTexture = null
static var _trace_size := Vector2.ZERO
static var _trace_pack := 1.0
## How far out (in hole radii) the trace's disc reaches: it is traced again
## when the look wants another.
static var _trace_rk := 0.0
static var _trace_tilt := 0.0

var chart: StarchartScreen.MapChart = null

## Seconds between frames of the sky's own motion. 0 is every frame. See
## `MapChart.set_anim_interval`.
var interval := 0.0
var _since := 0.0

var _key := ""
var _job: Dictionary = {}
## Whether the run's systems belong to this galaxy (the title screen's do not).
var _use_map := true
## The baker's copy of what a bake reads from the chart that asked for it.
var _src_big := PackedByteArray()
var _src_col := PackedColorArray()
var _src_core := PackedColorArray()
var _level0 := 0
var _pts: Dictionary = {}
var _pts_key := ""

var _vp: SubViewport = null
var _field: ColorRect = null
var _stars: MeshDraw = null
var _lens: ColorRect = null
var _hole: ColorRect = null
var _pal: ColorRect = null
var _m_field: ShaderMaterial = null
var _m_stars: ShaderMaterial = null
var _m_lens: ShaderMaterial = null
var _m_hole: ShaderMaterial = null
var _m_pal: ShaderMaterial = null
var _vp_origin := Vector2.ZERO
var _shown_li := -1
## Palettes being worked out on other threads: bucket -> task.
var _tasks: Dictionary = {}
## Lookups being made on the GPU: bucket -> [viewport, frame, palette image].
var _luts: Dictionary = {}


## A mesh drawn as one item, its quads placed by its shader.
class MeshDraw extends Node2D:
	var mesh: ArrayMesh = null

	func _draw() -> void:
		if mesh != null:
			draw_mesh(mesh, null)


static func galaxy_key() -> String:
	return "%d|%d|%.3f" % [Run.galaxy_kind, Run.galaxy_seed, float(Run.galaxy.get("squash", 0.62))]


## How flat the galaxy's light is drawn: EVERY GALAXY lies in the sector map's
## own plane, TILT ("increase the angle of the starchart to match the sector",
## Jon) -- its light, its clouds, its systems, routes and rings
## (`StarchartScreen.MapChart._eff`). A ragged spiral was drawn rounder, part
## way to its own `squash`; then a ball still was, up to 0.88.
static func eff_of(_g: Dictionary) -> float:
	# EVERY GALAXY, the ball-shaped ones too ("why does this galaxy not look
	# edge on? ... In the main menu it looks at the proper angle", Jon): an
	# elliptical, a dwarf or a merger kept most of its own roundness, up to
	# 0.88, and read as seen face-on -- and its clouds were drawn at that
	# roundness while its systems lay at TILT, so a pulsar sat up to 62 px off
	# the middle of its own remnant. One plane for all of it now; a ball keeps
	# a little of its roundness only in its middle (`params`, `bsq`).
	return TILT


## Everything baked for a galaxy that is not the current one goes.
static func drop_others() -> void:
	_pts_cache.clear()
	var keep := galaxy_key()
	for k in _baked.keys():
		if not (k as String).begins_with(keep + "|") and k != keep:
			_baked.erase(k)


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _exit_tree() -> void:
	# A palette still being worked out finishes; its answer goes nowhere.
	for b in _tasks:
		WorkerThreadPool.wait_for_task_completion(int(_tasks[b][0]))
	_tasks.clear()


## Whether this galaxy's fields are baked.
func ready_baked() -> bool:
	return (_baked.get(_key, {}) as Dictionary).has("sl")


## Whether the galaxy can be drawn yet.
func ready_to_draw() -> bool:
	var g: Dictionary = _baked.get(_key, {})
	return not g.is_empty() and g.has("sl") and _vp != null


# ------------------------------------------------------------------ the points

## The chart's star field as textures, straight from its packed arrays (no loop
## over the stars), and the bake if this galaxy has none.
func setup(c: StarchartScreen.MapChart) -> void:
	chart = c
	_use_map = c.run_galaxy
	var pk: String = c._star_key
	if pk != _pts_key:
		_pts_key = pk
		if not _pts_cache.has(pk):
			_pts_cache[pk] = _point_textures(c)
		_pts = _pts_cache[pk]
		if _m_stars != null:
			_feed_points(_m_stars)
			_stars.mesh = StarchartScreen.MapChart._quads(int(_pts.n_star) + int(_pts.n_core))
			_stars.queue_redraw()
	# The law takes its innermost ring from the run's map, so a galaxy drawn
	# without one (the title screen's) is a bake of its own.
	var key := galaxy_key() + ("|map" if _use_map else "")
	if key != _key:
		_key = key
		_shown_li = -1
		# Deferred: this is asked from the sky's draw, and nodes are not made
		# while the canvas is drawing.
		if not _baked.has(key) and not _bake_due:
			_bake_due = true
			_request_bake.call_deferred()
		elif _baked.has(key):
			_runtime.call_deferred()


var _bake_due := false

## Hand this galaxy to the baker, unless it is already on it.
func _request_bake() -> void:
	_bake_due = false
	# Headless there is no renderer to bake with, and nothing to look at.
	if _baked.has(_key) or chart == null or DisplayServer.get_name() == "headless":
		return
	if _baker == null or not is_instance_valid(_baker):
		_baker = ChartSky.new()
		_baker.name = "ChartSkyBake"
		get_tree().root.add_child(_baker)
	if _baker._key == _key and not _baker._job.is_empty():
		return
	_baker._drop_job()
	_baker._key = _key
	_baker._pts = _pts
	_baker._use_map = _use_map
	_baker._src_big = chart._star_big
	_baker._src_col = chart._star_col
	_baker._src_core = chart._core_col
	_baker._level0 = level_of(_z())
	_baker._begin_bake()


func _point_textures(c: StarchartScreen.MapChart) -> Dictionary:
	var r_max: float = c._radius() * DISC
	var out := {
		"pos": StarchartScreen.MapChart._data_tex(c._star_pos.to_byte_array(), c._star_pos.size(), 8, Image.FORMAT_RGF),
		"col": StarchartScreen.MapChart._data_tex(c._star_col.to_byte_array(), c._star_col.size(), 16, Image.FORMAT_RGBAF),
		"big": StarchartScreen.MapChart._data_tex(c._star_big.duplicate(), c._star_big.size(), 1, Image.FORMAT_R8),
		"cr": StarchartScreen.MapChart._data_tex(c._core_rad.to_byte_array(), c._core_rad.size(), 4, Image.FORMAT_RF),
		"ca": StarchartScreen.MapChart._data_tex(c._core_ang.to_byte_array(), c._core_ang.size(), 4, Image.FORMAT_RF),
		"cc": StarchartScreen.MapChart._data_tex(c._core_col.to_byte_array(), c._core_col.size(), 16, Image.FORMAT_RGBAF),
		"n_star": c._star_pos.size(),
		"n_core": c._core_rad.size(),
		"r_max": r_max,
	}
	var gi := PackedInt32Array()
	var gc := PackedVector2Array()
	for k in mini(32, c._glob_c.size()):
		gi.append(c._glob_i[k * 2])
		gi.append(c._glob_i[k * 2 + 1])
		gc.append(c._glob_c[k])
	out["glob_i"] = gi
	out["glob_c"] = gc
	return out


## The points and the galaxy's constants, to a material that places points.
func _feed_points(m: ShaderMaterial) -> void:
	var p := params(_use_map)
	var to_base: float = p.big_r / float(_pts.r_max)
	m.set_shader_parameter("star_pos", _pts.pos)
	m.set_shader_parameter("star_col", _pts.col)
	m.set_shader_parameter("star_big", _pts.big)
	m.set_shader_parameter("core_r", _pts.cr)
	m.set_shader_parameter("core_a", _pts.ca)
	m.set_shader_parameter("core_col", _pts.cc)
	m.set_shader_parameter("tex_w", StarchartScreen.MapChart.SKY_TEX_W)
	m.set_shader_parameter("n_star", _pts.n_star)
	m.set_shader_parameter("n_core", _pts.n_core)
	m.set_shader_parameter("to_base", to_base)
	m.set_shader_parameter("sq", p.sq)
	m.set_shader_parameter("eff", p.eff)
	m.set_shader_parameter("dk", p.dk)
	m.set_shader_parameter("bul_r", p.bul * 1.35)
	m.set_shader_parameter("rim_r", p.big_r)
	var gi: PackedInt32Array = _pts.glob_i
	var ranges: Array[Vector2i] = []
	var centres := PackedVector2Array()
	for k in gi.size() / 2:
		ranges.append(Vector2i(gi[k * 2], gi[k * 2 + 1]))
		centres.append((_pts.glob_c as PackedVector2Array)[k] * to_base)
	while ranges.size() < 32:
		ranges.append(Vector2i.ZERO)
		centres.append(Vector2.ZERO)
	m.set_shader_parameter("glob", ranges)
	m.set_shader_parameter("glob_c", centres)
	m.set_shader_parameter("n_glob", gi.size() / 2)
	m.set_shader_parameter("cluster_look", cluster_look)
	# and the field, which draws their glow
	if _m_field != null:
		_m_field.set_shader_parameter("glob_c", centres)
		_m_field.set_shader_parameter("n_glob", gi.size() / 2)
		_m_field.set_shader_parameter("cluster_look", cluster_look)


# ---------------------------------------------------------- the galaxy's constants

## The rolled galaxy as the mockup's numbers. `use_map`: whether the run's
## systems are this galaxy's (the title screen draws a galaxy of its own).
static func params(use_map: bool = true) -> Dictionary:
	var g: Dictionary = Run.galaxy
	var sq := float(g.get("squash", 0.62))
	var arms := int(g.get("arms", 2))
	var chaos := float(g.get("chaos", 0.0))
	var gas := float(g.get("gas", 1.0))
	# How much of this galaxy is a disc: arms are a disc, no arms and thin is a
	# lenticular (also a disc), no arms and round is a ball and keeps its shape.
	var dk := maxf(0.5, 1.0 - chaos) if arms > 0 else (1.0 if sq < 0.4 else 0.12)
	var eff := eff_of(g)
	var bsq := 0.86 * dk + eff * (1.0 - dk)
	# a galaxy that is a ball: an oblate one seen at the tilt -- a quarter of its
	# own roundness in its middle, the rest of it in the plane
	if arms == 0 and sq >= 0.4:
		bsq = TILT + (sq - TILT) * 0.25
	# The mockup's pixels: the chart's opening view of a 655 x 435 panel.
	var big_r := minf(327.5, 217.5 / sq) * 1.9 * 0.42
	var bul := maxf(6.0, float(g.get("bulge", 0.2)) / DISC * big_r)
	var shadow := maxf(1.6, float(g.get("hole", 0.034)) / DISC * big_r)
	var arm_k := 0.0
	if arms > 0:
		arm_k = clampf(1.0 - chaos * 1.8, 0.0, 1.0) * (0.75 if arms >= 5 else 1.0)
	var p := {
		"sq": sq, "arms": arms, "chaos": chaos, "gas": gas, "dk": dk, "eff": eff,
		"bsq": bsq, "big_r": big_r, "bul": bul, "shadow": shadow, "arm_k": arm_k,
		"bar": float(g.get("bar", 0.0)), "twist": float(g.get("twist", 3.0)),
		"spin": Run.galaxy_spin,
		"sd": fmod(float(Run.galaxy_kind) * 7.31 + Run.galaxy_spin, 50.0),
		"lane": minf(1.1, gas) * 0.95 if (arms > 0 and gas >= 0.35) else 0.0,
	}
	_nebula_lobes(p, sq)
	var pals := _gas_palette(gas)
	p["pal0"] = pals[0]
	p["pal1"] = pals[1]
	# THE LAW: the climb toward the hole stays inside the innermost ring of
	# systems (0.85 of its radius, less a marker's reach); the CORE sits at the
	# centre and is not a ring.
	var rin_p := hole_r(p, 1.0) * 1.16
	var ring := INF
	if use_map:
		for raw in Run.map:
			var n: MapGen.MapNode = raw
			if n.type == MapGen.NodeType.CORE:
				continue
			ring = minf(ring, Vector2(n.gal.x, n.gal.y / sq).length() * big_r)
	if ring == INF:
		ring = 1.2 * bul
	p["rin_p"] = rin_p
	# The climb: nothing past the hole's own edge. It once ran out to the
	# innermost ring, and the bulge's stars and gas whirled round the hole at
	# hundreds of times the disc's turn, which is most of what read as "still
	# rotating too fast". Only the accretion disc spins now, at its own speed
	# (`chart_hole`), and the gas just outside it (the swirl).
	p["rb"] = rin_p * 1.05
	# the innermost ring's reach, which still bounds the lens and the swirl
	p["rb_ring"] = maxf(rin_p * 1.05, 0.85 * ring - 2.0)
	return p


## The named clouds as the field draws them (`chart_field`'s `nebulae`): a
## lobe each, where the bake put its gas, at the radius the chart outlines
## it at; in its own colour, richer and brighter; and which cloud it belongs
## to, so one in sensor range breathes as a whole.
static func _nebula_lobes(p: Dictionary, sq: float) -> void:
	var big_r: float = p.big_r
	var eff: float = p.eff
	var flat := maxf(0.3, eff / 0.82)
	var na := PackedVector4Array()
	var nb := PackedVector4Array()
	var owner := PackedInt32Array()
	var centres := PackedVector3Array()
	var names := PackedStringArray()
	var ci := 0
	for raw in NebulaField.clouds():
		var cl: NebulaField.Cloud = raw
		# (the new look draws the dark clouds too, their lit edges)
		if cl.kind == NebulaField.Kind.DARK and nebula_look != 4:
			continue
		var c := cl.base_colour()
		c = Color.from_hsv(c.h, clampf(c.s * 1.55, 0.0, 1.0), 1.0)
		# A SHELL IS ONE SHELL ("supernova remnants should have no stuff in the
		# middle ... it should be hollow", Jon): in the new look a remnant or a
		# planetary is drawn once, round the cloud's own centre, as wide as its
		# outline reaches -- a shell for each lobe crossed its own middle
		if nebula_look == 4 and (cl.kind == NebulaField.Kind.REMNANT or cl.kind == NebulaField.Kind.PLANETARY):
			var reach := 0.0
			for l2 in cl.lobes.size():
				reach = maxf(reach, cl.lobes[l2].length() + cl.lobe_r[l2] * NebulaField.EXTENT)
			if na.size() < 32:
				var kw2 := int(cl.kind) + (8 * int(cl.shape) if cl.kind == NebulaField.Kind.PLANETARY else 0)
				na.append(Vector4(cl.pos.x * big_r, cl.pos.y * big_r / sq * eff, reach * big_r, float(kw2)))
				nb.append(Vector4(c.r * 1.45, c.g * 1.45, c.b * 1.45, flat))
				owner.append(ci)
			centres.append(Vector3(cl.pos.x, cl.pos.y / sq, cl.radius))
			names.append(cl.name)
			ci += 1
			continue
		for l in cl.lobes.size():
			if na.size() >= 32:
				break
			var at := Vector2((cl.pos.x + cl.lobes[l].x) * big_r,
				cl.pos.y * big_r / sq * eff + cl.lobes[l].y * big_r * flat)
			# the kind, and a planetary's shape with it: kind + 8 x shape
			var kw := int(cl.kind) + (8 * int(cl.shape) if cl.kind == NebulaField.Kind.PLANETARY else 0)
			na.append(Vector4(at.x, at.y, cl.lobe_r[l] * big_r * NebulaField.EXTENT, float(kw)))
			nb.append(Vector4(c.r * 1.45, c.g * 1.45, c.b * 1.45, flat))
			owner.append(ci)
		centres.append(Vector3(cl.pos.x, cl.pos.y / sq, cl.radius))
		names.append(cl.name)
		ci += 1
	p["neb_n"] = na.size()
	p["neb_owner"] = owner
	p["neb_centres"] = centres
	p["neb_names"] = names
	na.resize(32)
	nb.resize(32)
	p["neb_a"] = na
	p["neb_b"] = nb


## How much each lobe breathes: its cloud is within your sensors.
func _nebula_glow(p: Dictionary) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(32)
	if not _use_map or Run.map.is_empty() or Run.node_at() == null:
		return out
	var here: MapGen.MapNode = Run.node_at()
	var me := Vector2(here.gal.x, here.gal.y / float(p.sq))
	var sense: float = Run.sense_radius()
	var centres: PackedVector3Array = p.neb_centres
	var owner: PackedInt32Array = p.neb_owner
	for i in owner.size():
		var c := centres[owner[i]]
		if Vector2(c.x, c.y).distance_to(me) <= sense + c.z:
			out[i] = 0.35
	return out


static func _gas_palette(gas: float) -> Array:
	var kinds := {}
	for raw in NebulaField.clouds():
		kinds[(raw as NebulaField.Cloud).kind] = true
	var a := Vector3(0.36, 0.52, 0.95)
	var b := Vector3(0.95, 0.36, 0.55)
	if gas > 1.6:
		a = Vector3(0.30, 0.70, 0.92)
		b = Vector3(0.98, 0.34, 0.62)
	elif kinds.has(NebulaField.Kind.REMNANT) and not kinds.has(NebulaField.Kind.EMISSION):
		b = Vector3(0.86, 0.42, 0.62)
	if kinds.has(NebulaField.Kind.EMISSION):
		b = Vector3(1.0, 0.38, 0.5)
	if gas < 0.4:
		a = Vector3(0.55, 0.62, 0.85)
		b = Vector3(0.85, 0.58, 0.5)
	return [a, b]


## THE HOLE, BIGGER than the old chart's: 2x the galaxy's own at every zoom,
## held under a fifth of the bulge. One scale, so it grows exactly as the map
## does: it used to ease from 2.6x at the opening view to 1.3x at the closest,
## so zooming in it grew more slowly than the disc and bulge round it and
## read as shrinking ("the black hole seems to shrink when you zoom in",
## Jon). `z` is screen pixels a bake pixel; the answer is in screen pixels.
static func hole_r(p: Dictionary, z: float) -> float:
	var cap := 0.2 * float(p.bul) / float(p.shadow)
	return float(p.shadow) * z * maxf(1.0, minf(HOLE_K, cap))


## The angular speed of the climb at r bake pixels, radians a second: nothing
## from the innermost ring out, then Keplerian toward the hole.
static func wk(p: Dictionary, r: float) -> float:
	var rb: float = p.rb
	if r >= rb:
		return 0.0
	var rin: float = p.rin_p
	return 1.1 * pow(maxf(r, rin) / rin, -1.5) * (1.0 - _sm(0.5 * rb, rb, r))


static func _sm(a: float, b: float, x: float) -> float:
	var u := clampf((x - a) / (b - a), 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


## The zoom level nearest a zoom (screen pixels a bake pixel).
static func level_of(z: float) -> int:
	var best := 0
	var bd := INF
	for i in LEVELS.size():
		var d := absf(log(z) - log(LEVELS[i] / LEVELS[0]))
		if d < bd:
			bd = d
			best = i
	return best


# ------------------------------------------------------------------- the bake

## A viewport for one pass of the bake, drawing `item`.
func _pass_vp(holder: Node, size: Vector2i, item: CanvasItem, hdr: bool = true,
		now: bool = true) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = true
	vp.use_hdr_2d = hdr
	vp.disable_3d = true
	vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE if now else SubViewport.UPDATE_DISABLED
	holder.add_child(vp)
	if item is Control:
		(item as Control).size = Vector2(size)
	vp.add_child(item)
	return vp


func _rect(mat: ShaderMaterial) -> ColorRect:
	var r := ColorRect.new()
	r.material = mat
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## A box blur of radius r three times over is a Gaussian of this spread.
static func _spread(s: float) -> float:
	var r := maxf(1.0, roundf(s))
	return sqrt(r * (r + 1.0))


func _blur_pair(holder: Node, src: Texture2D, src2: Texture2D, pre: int,
		sx: Vector2, sy: Vector2, across: Array[SubViewport], down: Array[SubViewport]) -> SubViewport:
	var mh := ShaderMaterial.new()
	mh.shader = BLUR_SH
	mh.set_shader_parameter("src", src)
	if src2 != null:
		mh.set_shader_parameter("src2", src2)
	mh.set_shader_parameter("pre", pre)
	mh.set_shader_parameter("dir", Vector2(1, 0))
	mh.set_shader_parameter("sig_rgb", sx.x)
	mh.set_shader_parameter("sig_a", sx.y)
	mh.set_shader_parameter("size", Vector2(BAKE))
	var h := _pass_vp(holder, BAKE, _rect(mh), true, false)
	across.append(h)
	var mv := ShaderMaterial.new()
	mv.shader = BLUR_SH
	mv.set_shader_parameter("src", h.get_texture())
	mv.set_shader_parameter("pre", 0)
	mv.set_shader_parameter("dir", Vector2(0, 1))
	mv.set_shader_parameter("sig_rgb", sy.x)
	mv.set_shader_parameter("sig_a", sy.y)
	mv.set_shader_parameter("size", Vector2(BAKE))
	var v := _pass_vp(holder, BAKE, _rect(mv), true, false)
	down.append(v)
	return v


## Stage one: the points added up, then blurred at the mockup's four scales,
## and a probe of what the normalisers are measured from. A frame for each
## step (`groups`): viewports drawn in the same frame are drawn in an order
## that is not theirs to choose, and a blur drawn before its points is black.
func _begin_bake() -> void:
	var p := params(_use_map)
	var holder := Node.new()
	holder.name = "Bake"
	add_child(holder)
	var mesh := StarchartScreen.MapChart._quads(int(_pts.n_star) + int(_pts.n_core))
	var splats: Array[SubViewport] = []
	for mode in 3:
		var m := ShaderMaterial.new()
		m.shader = SPLAT_SH
		_feed_points(m)
		m.set_shader_parameter("mode", mode)
		m.set_shader_parameter("origin", BAKE_O)
		var clouds := PackedVector4Array()
		for raw in NebulaField.clouds():
			var cl: NebulaField.Cloud = raw
			if clouds.size() >= 16:
				break
			var at: Vector2 = cl.pos * float(p.big_r)
			clouds.append(Vector4(at.x, at.y, cl.radius * float(p.big_r),
				1.0 if cl.kind == NebulaField.Kind.DARK else 0.0))
		var n_clouds := clouds.size()
		clouds.resize(16)
		m.set_shader_parameter("clouds", clouds)
		m.set_shader_parameter("n_clouds", n_clouds)
		var md := MeshDraw.new()
		md.mesh = mesh
		md.material = m
		splats.append(_pass_vp(holder, BAKE, md))
	var eff: float = p.eff
	var ys := maxf(eff, 0.45)
	var chains: Array[SubViewport] = []
	var across: Array[SubViewport] = []
	var down: Array[SubViewport] = []
	for s: float in [2.2, 6.0, 16.0, 34.0]:
		var sx := _spread(s)
		var sy := _spread(s * ys)
		chains.append(_blur_pair(holder, splats[0].get_texture(), null, 0,
			Vector2(sx, sx), Vector2(sy, sy), across, down))
	var bf_x := _spread(10.0)
	var bf_y := _spread(10.0 * float(p.bsq))
	chains.append(_blur_pair(holder, splats[0].get_texture(), splats[1].get_texture(), 1,
		Vector2(bf_x, bf_x), Vector2(bf_y, bf_y), across, down))
	# the clouds' gas at 2x2 blocks, as the mockup gathered it; their dust apart
	var gy := maxf(0.7, eff)
	chains.append(_blur_pair(holder, splats[2].get_texture(), splats[1].get_texture(), 2,
		Vector2(_spread(1.6) * 2.0, _spread(4.2)), Vector2(_spread(1.6 * gy) * 2.0, _spread(4.2 * gy)),
		across, down))
	var probe_size := Vector2i(BAKE.x / 8, (BAKE.y / 8) * 2)
	var mp := _base_mat(chains, p, 0)
	mp.set_shader_parameter("out_size", Vector2(probe_size))
	var probe := _pass_vp(holder, probe_size, _rect(mp), true, false)
	var trace: SubViewport = null
	if _trace == null or _trace_rk != hole_rk() or _trace_tilt != hole_tilt():
		trace = _trace_vp(holder)
	_job = {"stage": 1, "frame": Engine.get_frames_drawn(), "holder": holder,
		"groups": [across, down, [probe]],
		"chains": chains, "probe": probe, "trace": trace, "p": p, "key": _key}


func _base_mat(chains: Array[SubViewport], p: Dictionary, mode: int) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = BASE_SH
	for i in 4:
		m.set_shader_parameter("c%d" % i, chains[i].get_texture())
	m.set_shader_parameter("cbf", chains[4].get_texture())
	m.set_shader_parameter("cg", chains[5].get_texture())
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("size", Vector2(BAKE))
	m.set_shader_parameter("out_size", Vector2(BAKE))
	m.set_shader_parameter("origin", BAKE_O)
	for k in ["eff", "bsq", "bul", "sd", "chaos", "bar", "twist", "spin"]:
		m.set_shader_parameter(k, p[k])
	m.set_shader_parameter("arm_k", p.arm_k)
	m.set_shader_parameter("big_r", p.big_r)
	m.set_shader_parameter("arms", p.arms)
	return m


## The black hole's radius on the screen now, in screen pixels (0 before the
## sky is made): the chart keeps its marks out of it.
func hole_px() -> float:
	if chart == null or not _baked.has(_key):
		return 0.0
	return hole_r(_baked[_key].p, _z())


## How far out the hole's disc reaches, in hole radii: the sector map's 110 / 15
## for its look, else 4.
static func hole_rk() -> float:
	return 110.0 / 15.0 if hole_look == 1 else DISC_K


## The angle the hole's disc is seen at: the galaxy's own, but for the textbook
## look nearly edge on (about 6 degrees), so its near side is a thin band
## across the shadow with the shadow's foot and the lower arc under it (at 13
## degrees the band still covered the whole lower half).
static func hole_tilt() -> float:
	return 0.1 if hole_look == 2 else TILT


## The hole's trace, the sector map's own shader, at TRACE_RH.
func _trace_vp(holder: Node) -> SubViewport:
	var rh := TRACE_RH
	_trace_rk = hole_rk()
	_trace_tilt = hole_tilt()
	var rout := rh * _trace_rk
	var w := 2 * ceili(rout * 1.08) + 3
	var h := 2 * ceili(rout * _trace_tilt * 1.1 + rh * 3.2) + 3
	var kz := ceilf(rout / 140.0 * 10.0) / 10.0
	var m := ShaderMaterial.new()
	m.shader = TRACE_SH
	m.set_shader_parameter("tilt", _trace_tilt)
	m.set_shader_parameter("rh", rh)
	m.set_shader_parameter("rin", rh * 1.16)
	m.set_shader_parameter("rout", rout)
	m.set_shader_parameter("kz", kz)
	m.set_shader_parameter("size", Vector2(w, h))
	_trace_size = Vector2(w, h)
	_trace_pack = 140.0 * kz
	return _pass_vp(holder, Vector2i(w, h * 4), _rect(m), false)


func _process(delta: float) -> void:
	if not _job.is_empty() and Engine.get_frames_drawn() > int(_job.frame):
		_advance()
	_poll_palettes()
	if chart == null:
		return
	# the baker has finished this galaxy since the chart asked
	if _vp == null and ready_baked():
		_runtime()
	if _vp == null:
		# and if the baker went on to another galaxy first, ask again
		if _key != "" and not ready_baked() and not _bake_due 				and (_baker == null or not is_instance_valid(_baker) or _baker._key != _key):
			_bake_due = true
			_request_bake.call_deferred()
		return
	if interval > 0.0:
		_since += delta
		if _since < interval:
			return
		_since = 0.0
	push()


func _advance() -> void:
	if _job.key != _key:
		_drop_job()
		return
	# a renderer that gives nothing back (none, or a lost device) ends the bake
	var check: SubViewport = _job.probe if int(_job.stage) == 1 else null
	if check != null and (_job.get("groups", []) as Array).is_empty() 			and check.get_texture().get_image() == null:
		_drop_job()
		return
	var groups: Array = _job.get("groups", [])
	if not groups.is_empty():
		for vp: SubViewport in groups.pop_front():
			vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		_job.frame = Engine.get_frames_drawn()
		return
	match int(_job.stage):
		1:
			_stage_fields()
		2:
			_stage_textures()
		3:
			_stage_palettes()


func _drop_job() -> void:
	if _job.has("holder") and is_instance_valid(_job.holder):
		(_job.holder as Node).queue_free()
	_job = {}


## Stage two: the normalisers, from the probe, and the standing fields.
func _stage_fields() -> void:
	var p: Dictionary = _job.p
	var img := (_job.probe as SubViewport).get_texture().get_image()
	var raw := PackedFloat32Array()
	var wide := PackedFloat32Array()
	var mid := PackedFloat32Array()
	var dust := PackedFloat32Array()
	var gasv := PackedFloat32Array()
	var ph := img.get_height() / 2
	for y in ph:
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.r >= 0.0:
				raw.append(c.r)
			if c.g > 1e-5:
				wide.append(c.g)
			if c.b > 1e-4:
				mid.append(c.b)
			if c.a > 0.002:
				dust.append(c.a)
			var gc := img.get_pixel(x, y + ph)
			if gc.r > 2.5e-4:
				gasv.append(gc.r)
	var ref := _pct(wide, 0.5, 1e-3) * 0.15
	var gain := (1.45 - 0.3 * float(p.arm_k)) / _pct(raw, 0.99, 1e-3)
	var norms := {"ref": ref, "gain": gain, "aa_ref": _pct(mid, 0.97, 1.0),
		"cd_ref": _pct(dust, 0.85, 1.0), "gc_ref": _pct(gasv, 0.92, 1.0)}
	if _job.trace != null:
		var ti := (_job.trace as SubViewport).get_texture().get_image()
		_trace = ImageTexture.create_from_image(ti)
	var chains: Array[SubViewport] = _job.chains
	var outs := []
	for mode in [1, 2, 3, 4]:
		var m := _base_mat(chains, p, mode)
		for k in norms:
			m.set_shader_parameter(k, norms[k])
		var size := Vector2i(BAKE.x / 2, BAKE.y / 2) if mode == 3 else BAKE
		m.set_shader_parameter("out_size", Vector2(size))
		outs.append(_pass_vp(_job.holder, size, _rect(m)))
	# THE DUST, SPREAD. Worked out at a bake pixel and left there, a lane is a
	# crease one pixel wide, and every zoom magnifies the crease into a crack:
	# blurred here it is a band with soft edges that only widens as you go in.
	var across: Array[SubViewport] = []
	var down: Array[SubViewport] = []
	outs.append(_blur_pair(_job.holder, (outs[3] as SubViewport).get_texture(), null, 0,
		Vector2(DUST_SPREAD, DUST_SPREAD), Vector2(DUST_SPREAD, DUST_SPREAD), across, down))
	_job.groups = [across, down]
	_job.outs = outs
	_job.stage = 2
	_job.frame = Engine.get_frames_drawn()


static func _pct(a: PackedFloat32Array, q: float, fallback: float) -> float:
	if a.is_empty():
		return fallback
	a.sort()
	var v := a[clampi(int(floor(float(a.size()) * q)), 0, a.size() - 1)]
	return v if v > 0.0 else fallback


## Stage three: the fields read back and kept; probes for the palettes.
func _stage_textures() -> void:
	var outs: Array = _job.outs
	var g := {"p": _job.p, "pals": {}}
	g["sl"] = ImageTexture.create_from_image((outs[0] as SubViewport).get_texture().get_image())
	g["aux"] = ImageTexture.create_from_image((outs[1] as SubViewport).get_texture().get_image())
	g["gc"] = ImageTexture.create_from_image((outs[2] as SubViewport).get_texture().get_image())
	g["dust"] = ImageTexture.create_from_image((outs[4] as SubViewport).get_texture().get_image())
	_baked[_key] = g
	# the probes: every zoom's window round the centre, unpaletted
	var probes := []
	for li in LEVELS.size():
		var m := ShaderMaterial.new()
		m.shader = FIELD_SH
		_feed_field(m, g, LEVELS[li] / LEVELS[0])
		m.set_shader_parameter("probe", true)
		m.set_shader_parameter("vp_size", Vector2(PROBE))
		probes.append(_pass_vp(_job.holder, PROBE, _rect(m), false))
	_job.probes = probes
	_job.stage = 3
	_job.frame = Engine.get_frames_drawn()


## Stage four: the palettes. The one this view needs now is worked out here,
## so the chart never opens on the wrong colours; the rest on other threads.
func _stage_palettes() -> void:
	var probes: Array = _job.probes
	var stars := _star_hist()
	var now := _level_now()
	for li in probes.size():
		var img := (probes[li] as SubViewport).get_texture().get_image()
		if li == now:
			_bake_lut(li, _make_palette(img, stars, _bulge_box(li), _cloud_hues()))
		else:
			var job := PaletteJob.new()
			job.probe = img
			job.stars = stars
			job.bulge = _bulge_box(li)
			job.hues = _cloud_hues()
			var id := WorkerThreadPool.add_task(job.run, false, "chart palette")
			_tasks[li] = [id, job, _key]
	var holder: Node = _job.holder
	_job = {}
	holder.queue_free()


func _level_now() -> int:
	return _level0


## Screen pixels a bake pixel, at the chart's zoom.
func _z() -> float:
	var p: Dictionary = _baked[_key].p if _baked.has(_key) else params(chart.run_galaxy)
	return chart._radius() * DISC * chart.zoom / float(p.big_r)


## How often each of the galaxy's bright star colours turns up.
func _star_hist() -> Dictionary:
	var out := {}
	for i in _src_big.size():
		if _src_big[i] == 1:
			var c: Color = _src_col[i]
			out[c] = int(out.get(c, 0)) + 1
	for c: Color in _src_core:
		out[c] = int(out.get(c, 0)) + 1
	return out


## A palette worked out on another thread.
class PaletteJob extends RefCounted:
	var probe: Image
	var stars: Dictionary
	var bulge: Rect2i
	var hues: PackedColorArray
	var out := PackedColorArray()

	func run() -> void:
		out = ChartSky._make_palette(probe, stars, bulge, hues)


func _poll_palettes() -> void:
	for li in _tasks.keys():
		var t: Array = _tasks[li]
		if not WorkerThreadPool.is_task_completed(int(t[0])):
			continue
		WorkerThreadPool.wait_for_task_completion(int(t[0]))
		_tasks.erase(li)
		if t[2] == _key and _baked.has(_key):
			_bake_lut(li, (t[1] as PaletteJob).out)
	for li in _luts.keys():
		var l: Array = _luts[li]
		if Engine.get_frames_drawn() <= int(l[1]):
			continue
		_luts.erase(li)
		var vp: SubViewport = l[0]
		if l[3] == _key and _baked.has(_key):
			var lut := ImageTexture.create_from_image(vp.get_texture().get_image())
			(_baked[_key].pals as Dictionary)[li] = {"pal": l[2], "lut": lut}
			_shown_li = -1
		vp.get_parent().queue_free()


## The palette's lookup, on the GPU; read back a frame later.
func _bake_lut(li: int, pal: PackedColorArray) -> void:
	var img := Image.create(128, 1, false, Image.FORMAT_RGBA8)
	for i in mini(128, pal.size()):
		img.set_pixel(i, 0, pal[i])
	var tex := ImageTexture.create_from_image(img)
	var m := ShaderMaterial.new()
	m.shader = LUT_SH
	m.set_shader_parameter("pal", tex)
	m.set_shader_parameter("n", mini(128, pal.size()))
	var holder := Node.new()
	add_child(holder)
	var vp := _pass_vp(holder, Vector2i(256, 128), _rect(m), false)
	_luts[li] = [vp, Engine.get_frames_drawn(), tex, _key]


## THE PALETTE OF ONE ZOOM, from its probe (the mockup's `buildPalette`): a
## median cut of the zoom's picture with the galaxy's bright stars in it, more
## from its vivid colours and more again from its rare hues, so a small patch
## of pink gas is not averaged away; then the void, the hole's colours and the
## extra stars' sets. The cuts are the sector map's (`SystemPalette`).
## The bulge in a zoom level's probe: the probe is that zoom's window round
## the centre, four pixels to one.
func _bulge_box(li: int) -> Rect2i:
	var p: Dictionary = _job.p
	var r := clampf(float(p.bul) * LEVELS[li] / LEVELS[0] / 4.0 * 1.2, 4.0, float(PROBE.y) * 0.5)
	var c := Vector2(PROBE) * 0.5
	return Rect2i(Vector2i(c - Vector2(r, r * float(p.bsq))), Vector2i(Vector2(r, r * float(p.bsq)) * 2.0))


## The named clouds' own colours, once each.
func _cloud_hues() -> PackedColorArray:
	var out := PackedColorArray()
	# the new look's own colours, each kept in a few steps of light: hydrogen's
	# rose-red, oxygen's teal, the reflection's blue, the lit dust's amber
	if nebula_look == 4:
		for c: Color in [Color(1.0, 0.2, 0.3), Color(0.2, 0.95, 0.85), Color(0.32, 0.52, 1.0), Color(1.0, 0.62, 0.42)]:
			out.append(c)
	var nb: PackedVector4Array = _job.p.neb_b
	for i in int(_job.p.neb_n):
		var c := Color(nb[i].x, nb[i].y, nb[i].z) / 1.45
		if not out.has(c):
			out.append(c)
	return out


static func _make_palette(probe: Image, stars: Dictionary, bulge: Rect2i, cloud_hues: PackedColorArray) -> PackedColorArray:
	var img := probe.duplicate() as Image
	img.convert(Image.FORMAT_RGB8)
	var w := img.get_width()
	var h := img.get_height()
	var src := img.get_data()
	# the stars and the star sets, scaled to the probe (an eighth of the
	# mockup's window): every sample at an even x, which is what the cut reads
	var extra := PackedByteArray()
	for c: Color in stars:
		var n := maxi(1, roundi(float(stars[c]) / 8.0))
		for i in n:
			extra.append_array([c.r8, c.g8, c.b8])
	for c: Color in STAR_WARM + STAR_COOL:
		for i in 5:
			extra.append_array([c.r8, c.g8, c.b8])
	var all_img := _strip(src, w, h, extra)
	var cuts: PackedVector3Array = SystemPaletteS.median_cut(all_img, 20,
		Rect2i(0, 0, all_img.get_width(), all_img.get_height()))
	# and the bulge's own: a large part of the picture in a narrow band of warm
	# colours, which a cut of the whole gives one or two creams (the sector
	# map does the same for the light round its star)
	cuts.append_array(SystemPaletteS.median_cut(img, 10, bulge))
	var vivid := PackedByteArray()
	var hues := PackedInt32Array()
	hues.resize(12)
	var vivid_h := PackedInt32Array()
	for y in h:
		for x in range(0, w, 2):
			var o := (y * w + x) * 3
			var r := int(src[o])
			var g := int(src[o + 1])
			var b := int(src[o + 2])
			var mx := maxi(r, maxi(g, b))
			var mn := mini(r, mini(g, b))
			if mx > 50 and float(mx - mn) / float(mx) > 0.25:
				vivid.append_array([r, g, b])
				var hb := int(_hue(r, g, b) / 30.0) % 12
				hues[hb] += 1
				vivid_h.append(hb)
	var nv := vivid_h.size()
	if nv > 20:
		var vi := _strip(PackedByteArray(), 0, 0, vivid)
		cuts.append_array(SystemPaletteS.median_cut(vi, 10, Rect2i(0, 0, vi.get_width(), vi.get_height())))
	var rare := PackedByteArray()
	for i in nv:
		if float(hues[vivid_h[i]]) < float(nv) * 0.15:
			rare.append_array([vivid[i * 3], vivid[i * 3 + 1], vivid[i * 3 + 2]])
	if rare.size() / 3 > 8:
		var ri := _strip(PackedByteArray(), 0, 0, rare)
		cuts.append_array(SystemPaletteS.median_cut(ri, 6, Rect2i(0, 0, ri.get_width(), ri.get_height())))
	var out := PackedColorArray()
	for v in cuts:
		out.append(Color(v.x, v.y, v.z))
	# THE FAINT EDGE OF THE GAS IN STEPS: between the sky and each dark colour
	# of the gas the cut found, two steps more, so where the gas thins out it
	# falls off a step at a time instead of cutting from sky to brown in one
	# (with the dark never dithered, the cut drew "blocky brown islands", Jon)
	var sky := Vector3(7, 10, 18) / 255.0
	var faint := 0
	for v in cuts:
		var lv := _lum3(v) * 255.0
		if lv > 22.0 and lv < 90.0 and faint < 12:
			for tt: float in [0.35, 0.65]:
				var f := sky.lerp(v, tt)
				out.append(Color(f.x, f.y, f.z))
			faint += 2
	out.append(Color8(7, 10, 18))
	out.append(Color8(3, 4, 7))
	out.append(Color("#c9d8ea"))
	out.append(Color("#fff6e2"))
	for i in range(1, 7):
		out.append(BHPAL[i])
	if hole_bands == 2:
		for c: Color in BHUE:
			out.append(c)
	for c: Color in STAR_WARM + STAR_COOL:
		out.append(c)
		out.append(Color(c.r * 0.72, c.g * 0.72, c.b * 0.72))
	# THE BULGE'S OWN STEPS. It covers a large part of the picture in a narrow
	# band of warm colours, and the cut gave it one or two creams; these are
	# its amber-to-gold climb toward the nucleus, toned as the field tones
	# them, so the gradient survives the palette.
	var co := Vector3(0.95, 0.45, 0.17) / _lum3(Vector3(0.95, 0.45, 0.17))
	var ci := Vector3(1.0, 0.82, 0.55) / _lum3(Vector3(1.0, 0.82, 0.55))
	for wi: float in [0.15, 0.55, 0.9]:
		for l: float in [0.35, 0.6, 0.9, 1.3, 1.8, 2.6]:
			out.append(_tone(co.lerp(ci, wi) * l))
	# and the named clouds': each cloud's own colour in a few steps of light,
	# so a shell keeps its hue from rim to filament instead of one near-white
	for hc: Color in cloud_hues:
		for lv: float in [0.25, 0.5, 0.85]:
			if out.size() < 128:
				out.append(_tone(Vector3(hc.r, hc.g, hc.b) * lv))
	return out


static func _lum3(c: Vector3) -> float:
	return 0.3 * c.x + 0.59 * c.y + 0.11 * c.z


static func _tone1(x: float) -> float:
	return 0.0 if x <= 0.0 else 1.0 - exp(-minf(x, 10.0))


## `chart_galaxy.gdshaderinc`'s tone: light to the screen's colour.
static func _tone(c: Vector3) -> Color:
	var l := _lum3(c)
	var k := _tone1(l) / l if l > 1e-6 else 0.0
	var h := (c * k).min(Vector3.ONE)
	var t := h * 0.6 + Vector3(_tone1(c.x), _tone1(c.y), _tone1(c.z)) * 0.4
	var v := (Vector3(7, 10, 18) + (Vector3(255, 255, 255) - Vector3(7, 10, 18)) * t) / 255.0
	return Color(v.x, v.y, v.z)


static func _hue(r: int, g: int, b: int) -> float:
	var mx := maxi(r, maxi(g, b))
	var mn := mini(r, mini(g, b))
	var d := float(mx - mn) if mx != mn else 1.0
	var hh := 0.0
	if mx == r:
		hh = float(g - b) / d
	elif mx == g:
		hh = 2.0 + float(b - r) / d
	else:
		hh = 4.0 + float(r - g) / d
	return fposmod(hh * 60.0, 360.0)


## An RGB8 picture for `median_cut`: `rows` (w x h RGB, may be empty), then
## every sample of `extra` at an even x, the odd x beside it a copy.
static func _strip(rows: PackedByteArray, w: int, h: int, extra: PackedByteArray) -> Image:
	var width := w if w > 0 else 256
	var n := extra.size() / 3
	var per := width / 2
	var more := ceili(float(n) / float(per)) if n > 0 else 0
	var data := PackedByteArray()
	data.resize(width * (h + more) * 3)
	if h > 0:
		for i in rows.size():
			data[i] = rows[i]
	var base := width * h * 3
	for i in per * more:
		# the tail of the last row repeats the first samples rather than
		# counting as black
		var s := (i % n) * 3
		var o := base + i * 6
		for k in 3:
			data[o + k] = extra[s + k]
			data[o + 3 + k] = extra[s + k]
	return Image.create_from_data(width, h + more, false, Image.FORMAT_RGB8, data)


# --------------------------------------------------------------- the runtime

## The per-frame viewport, made once the galaxy is baked.
func _runtime() -> void:
	if _vp == null:
		_vp = SubViewport.new()
		_vp.transparent_bg = false
		_vp.disable_3d = true
		_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(_vp)
		_m_field = ShaderMaterial.new()
		_m_field.shader = FIELD_SH
		_field = _rect(_m_field)
		_vp.add_child(_field)
		_vp.add_child(_bbc())
		_m_stars = ShaderMaterial.new()
		_m_stars.shader = STARS_SH
		_stars = MeshDraw.new()
		_stars.material = _m_stars
		_vp.add_child(_stars)
		_vp.add_child(_bbc())
		_m_lens = ShaderMaterial.new()
		_m_lens.shader = LENS_SH
		_lens = _rect(_m_lens)
		_vp.add_child(_lens)
		_vp.add_child(_bbc())
		_m_hole = ShaderMaterial.new()
		_m_hole.shader = HOLE_SH
		_hole = _rect(_m_hole)
		_vp.add_child(_hole)
		_vp.add_child(_bbc())
		_m_pal = ShaderMaterial.new()
		_m_pal.shader = PAL_SH
		_pal = _rect(_m_pal)
		_vp.add_child(_pal)
	_feed_points(_m_stars)
	_stars.mesh = StarchartScreen.MapChart._quads(int(_pts.n_star) + int(_pts.n_core))
	_stars.queue_redraw()
	_shown_li = -1
	push()


func _bbc() -> BackBufferCopy:
	var b := BackBufferCopy.new()
	b.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	return b


## The field's constants for a galaxy at zoom `z` (screen pixels a bake pixel).
func _feed_field(m: ShaderMaterial, g: Dictionary, z: float) -> void:
	var p: Dictionary = g.p
	var zf := maxf(z, 1.0)
	m.set_shader_parameter("sl_tex", g.sl)
	m.set_shader_parameter("aux_tex", g.aux)
	m.set_shader_parameter("gc_tex", g.gc)
	m.set_shader_parameter("dust_tex", g.dust)
	m.set_shader_parameter("bake_size", Vector2(BAKE))
	m.set_shader_parameter("bake_origin", BAKE_O)
	m.set_shader_parameter("z", z)
	m.set_shader_parameter("zf", zf)
	for k in ["eff", "bsq", "bul", "sd", "gas", "pal0", "pal1", "rin_p", "rb", "rb_ring"]:
		m.set_shader_parameter(k, p[k])
	m.set_shader_parameter("dk_g", p.dk)
	m.set_shader_parameter("arm_k", p.arm_k)
	m.set_shader_parameter("big_r", p.big_r)
	m.set_shader_parameter("lane_amt", p.lane)
	m.set_shader_parameter("neb_a", p.neb_a)
	m.set_shader_parameter("neb_b", p.neb_b)
	m.set_shader_parameter("neb_n", p.neb_n)
	var gas: float = p.gas
	var nuc := 0.0
	if gas >= 0.35 and float(p.dk) > 0.5:
		nuc = minf(1.0, gas) * 1.1 * (0.45 + 0.55 * _sm(1.5, 5.0, zf))
	m.set_shader_parameter("nuc_amt", nuc)
	var rh := hole_r(p, z)
	m.set_shader_parameter("rh", rh)
	# stars drawn all the way in over the hole's disc and glow
	m.set_shader_parameter("near_r", rh * DISC_K * 1.3)
	m.set_shader_parameter("depth_look", depth_look)
	m.set_shader_parameter("depth_amt", depth_amt)
	m.set_shader_parameter("vol_h", VOLUME_H[clampi(volume_look, 0, 3)])
	m.set_shader_parameter("gas_k", GAS_K[clampi(gas_look, 0, 3)])
	var churn := gas_billow and gas_look > 0 and not DisplaySettings.reduced_motion
	m.set_shader_parameter("gas_t", (StarchartScreen.MapChart.clock() + 0.001) if churn else 0.0)
	if chart != null:
		m.set_shader_parameter("view_c", chart.size * 0.5)
	m.set_shader_parameter("disc_k", DISC_K)
	# and no dust round YOU, where the systems and routes are (the title
	# screen's galaxy is not the run's, so it has none)
	if chart != null and _use_map and not Run.map.is_empty():
		m.set_shader_parameter("you_rel", chart._screen_pos(Run.node_at()) - chart.centre_px())
		m.set_shader_parameter("you_r", 90.0)
	else:
		m.set_shader_parameter("you_r", 0.0)
	var extra := maxf(0.0, log(zf) / log(2.0))
	m.set_shader_parameter("oct", minf(extra, 4.0))
	m.set_shader_parameter("det_k", minf(1.0, extra / 2.0))
	m.set_shader_parameter("zoom_dim", _sm(1.4, 4.0, zf))
	m.set_shader_parameter("resolved", 1.0 / (1.0 + 0.4 * (zf - 1.0)))
	m.set_shader_parameter("dz", _sm(1.8, 8.0, zf))
	m.set_shader_parameter("res2", 1.0 / (1.0 + 0.15 * (zf - 1.0)))
	m.set_shader_parameter("te_b", 2.7756 * rh / z * 1.6)
	m.set_shader_parameter("swirl_amp", 0.45 + 0.55 * _sm(1.0, 4.5, zf))
	var g1: Vector3 = p.pal1
	m.set_shader_parameter("sw_gas", Vector3(0.5 * g1.x + 0.5, 0.5 * g1.y + 0.25, 0.5 * g1.z + 0.1))


var _push_queued := false

## A push at the end of this frame, after whatever is still to move the view
## has moved it (a glide's tween runs after every _process).
func queue_push() -> void:
	if _push_queued:
		return
	_push_queued = true
	_late_push.call_deferred()


func _late_push() -> void:
	_push_queued = false
	push()


## Every frame: the view, the turn and the clock, to the sky's passes.
func push() -> void:
	if chart == null or _vp == null or not _baked.has(_key):
		return
	var t_us := Time.get_ticks_usec()
	_push()
	if StarchartScreen.MapChart.prof:
		StarchartScreen.MapChart.prof_add("push", Time.get_ticks_usec() - t_us)


func _push() -> void:
	var g: Dictionary = _baked[_key]
	var p: Dictionary = g.p
	var size: Vector2 = chart.size
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var z := _z()
	var t := StarchartScreen.MapChart.clock()
	var phi: float = chart.turn()
	var cpix: Vector2 = chart.centre_px()
	# the blocks are anchored to the galaxy's centre, so a pan by one pixel
	# moves the picture by one pixel rather than redrawing every block
	_vp_origin = Vector2(posmod(int(cpix.x), 2) - 2, posmod(int(cpix.y), 2) - 2)
	# The same size whichever way the blocks fall: a viewport resized on every
	# odd pixel of a drag reallocates its picture every other frame.
	var vsz := Vector2i(ceili(size.x / 2.0) + 2, ceili(size.y / 2.0) + 2)
	if _vp.size != vsz:
		_vp.size = vsz
		for r: ColorRect in [_field, _lens, _hole, _pal]:
			r.size = Vector2(vsz)
	var vs := Vector2(vsz)
	var m := _m_field
	_feed_field(m, g, z)
	m.set_shader_parameter("vp_size", vs)
	m.set_shader_parameter("vp_origin", _vp_origin)
	m.set_shader_parameter("cpix", cpix)
	m.set_shader_parameter("phi", phi)
	m.set_shader_parameter("t", t)
	m.set_shader_parameter("probe", false)
	m.set_shader_parameter("sky_pan", chart.sky_pan.round())
	m.set_shader_parameter("sky_seed", (Run.galaxy_seed % 100003) * 31)
	var glow := _nebula_glow(p)
	m.set_shader_parameter("neb_glow", glow)
	m.set_shader_parameter("neb_style", nebula_look)
	if nebula_look == 3:
		# wanted: within your sensors, or the one under the pointer
		var want := PackedFloat32Array()
		want.resize(32)
		var names: PackedStringArray = p.neb_names
		var owner: PackedInt32Array = p.neb_owner
		for i in owner.size():
			var hot: bool = chart._neb_hot != "" and names[owner[i]] == chart._neb_hot
			want[i] = 1.0 if (hot or glow[i] > 0.0) else 0.0
		m.set_shader_parameter("neb_want", want)
	# the extra stars deep in: the scale of the mockup's density (the shader
	# works out each of its fixed grids' share, `chart_field`)
	m.set_shader_parameter("filler_k", float(p.eff) * 0.25 * [1.0, 1.0, 0.5, 0.25, 0.125][clampi(star_level, 1, 4)])
	m.set_shader_parameter("star_level", star_level)
	# the swirl's clumps, drifting inward on their own clocks
	var rh := hole_r(p, z)
	var rout := rh * DISC_K
	var rinl: float = float(p.rin_p) * z
	var clumps := PackedVector4Array()
	var kl := log(3.6)
	for c in 6:
		var f := t / 16.0 + float(c) / 6.0
		var life := floorf(f)
		var tau := f - life
		var r0 := minf(rout * 1.8, float(p.rb_ring) * z * 0.9)
		var r := r0 * exp(-kl * tau)
		var th0 := float(c) * 2.39 + life * 1.71 + float(Run.galaxy_kind)
		# (at 0.4 of the climb's pace, as the stars round the hole: calmer)
		var th := th0 - phi - 0.4 * 16.0 * 1.1 * pow(r0 / rinl, -1.5) * (exp(1.5 * kl * tau) - 1.0) / (1.5 * kl)
		var br := pow(sin(PI * tau), 0.8) * (0.6 + 0.4 * _hash01(c, int(life)))
		clumps.append(Vector4(log(r / rout), fposmod(th, TAU), br, 0.0))
	m.set_shader_parameter("clumps", clumps)

	var ms := _m_stars
	ms.set_shader_parameter("vp_origin", _vp_origin)
	ms.set_shader_parameter("cpix", cpix)
	ms.set_shader_parameter("z", z)
	ms.set_shader_parameter("phi", phi)
	ms.set_shader_parameter("t", t)
	ms.set_shader_parameter("rin_p", p.rin_p)
	ms.set_shader_parameter("rb", p.rb)
	ms.set_shader_parameter("star_level", star_level)
	ms.set_shader_parameter("near_r", hole_r(p, z) * DISC_K * 1.3)

	var hv := ((cpix - _vp_origin) / 2.0).floor()
	# the sector map's look keeps the chart's disc (DISC_K hole radii) and draws
	# the hole inside it at the sector map's proportion, smaller
	var rhd := rh * DISC_K / _trace_rk if _trace_rk > 0.0 else rh
	var ml := _m_lens
	ml.set_shader_parameter("vp_size", vs)
	ml.set_shader_parameter("hv", hv)
	# the lens's ring just inside the shadow, so the ring and the upside-down
	# picture inside it are hidden by the shadow and the sky round it is only
	# gently bent (at 2.8 hole radii the ring was a wide pale circle of the
	# bright nucleus round the whole disc)
	ml.set_shader_parameter("te", 0.9 * maxf(0.8, rhd / 2.0) * 2.0)
	ml.set_shader_parameter("rbl", float(p.rb_ring) * z)
	ml.set_shader_parameter("eff", p.eff)

	var mh := _m_hole
	if _trace != null:
		mh.set_shader_parameter("trace", _trace)
		mh.set_shader_parameter("trace_size", _trace_size)
		mh.set_shader_parameter("rh_c", TRACE_RH)
		mh.set_shader_parameter("r_pack", _trace_pack)
	mh.set_shader_parameter("vp_size", vs)
	mh.set_shader_parameter("hv", hv)
	mh.set_shader_parameter("rh_v", maxf(0.8, rhd / 2.0))
	mh.set_shader_parameter("z", z)
	mh.set_shader_parameter("phi", phi)
	mh.set_shader_parameter("t", t)
	mh.set_shader_parameter("rin_p", p.rin_p)
	mh.set_shader_parameter("rb", p.rb)
	mh.set_shader_parameter("look", hole_look)
	mh.set_shader_parameter("bands", hole_bands)
	mh.set_shader_parameter("band_amt", hole_band_amt)
	mh.set_shader_parameter("rout_k", _trace_rk)
	_hole.visible = _trace != null

	var mp := _m_pal
	mp.set_shader_parameter("vp_size", vs)
	mp.set_shader_parameter("block0", ((_vp_origin - cpix) / 2.0).floor())
	# the two levels either side of this zoom, and how far between them: the
	# change from one's palette to the next is a dissolve over the middle of
	# the stretch between them (`chart_palette`)
	var lo := 0
	for i in LEVELS.size() - 1:
		if z >= LEVELS[i + 1] / LEVELS[0]:
			lo = i + 1
	var hi := mini(lo + 1, LEVELS.size() - 1)
	var fr := 0.0
	if hi > lo:
		fr = clampf(log(z / (LEVELS[lo] / LEVELS[0])) / log(LEVELS[hi] / LEVELS[lo]), 0.0, 1.0)
	var use := _palette_for(lo)
	var use2 := _palette_for(hi)
	if use * 100 + use2 != _shown_li:
		_shown_li = use * 100 + use2
		var pals: Dictionary = g.pals
		if use >= 0:
			mp.set_shader_parameter("pal", pals[use].pal)
			mp.set_shader_parameter("lut", pals[use].lut)
			mp.set_shader_parameter("pal2", pals[use2].pal)
			mp.set_shader_parameter("lut2", pals[use2].lut)
		mp.set_shader_parameter("has_pal", use >= 0)
	mp.set_shader_parameter("pal_mix", _sm(0.25, 0.75, fr) if use2 != use else 0.0)
	queue_redraw()


## The palette to draw a zoom level with: its own, or the nearest made so far.
func _palette_for(li: int) -> int:
	var pals: Dictionary = _baked[_key].pals
	if pals.has(li):
		return li
	for d in range(1, LEVELS.size()):
		if pals.has(li - d):
			return li - d
		if pals.has(li + d):
			return li + d
	return -1


static func _hash01(x: int, y: int) -> float:
	var h := ((x * 374761393) ^ (y * 668265263)) & 0xffffffff
	h = (((h ^ (h >> 13)) * 1274126177) & 0xffffffff)
	h = h ^ (h >> 16)
	return float(h & 0xffffffff) / 4294967296.0


func _draw() -> void:
	if chart == null:
		return
	var t0 := Time.get_ticks_usec()
	# The galaxy is built and handed over at the first draw, once the layout
	# has given the chart its real size, and again whenever it changes (a new
	# run, a resize): building in _process built it at the size the panel had
	# before its first layout, then again at the real one.
	chart._ensure_gpu()
	if not ready_to_draw() or _palette_for(level_of(_z())) < 0:
		draw_rect(Rect2(Vector2.ZERO, chart.size), Color8(7, 10, 18), true)
	else:
		draw_texture_rect(_vp.get_texture(), Rect2(_vp_origin, Vector2(_vp.size) * 2.0), false)
	if StarchartScreen.MapChart.prof:
		StarchartScreen.MapChart.prof_add("sky", Time.get_ticks_usec() - t0)
