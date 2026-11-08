class_name ChartLegacy
extends Node2D

## Legacy chart style: one GPU bake per galaxy, then a half-size 2x2-block viewport redrawn
## every frame.
## Why: docs/why/ChartLegacy.md#legacy-chart-sky

const BAKE := Vector2i(896, 616)
const BAKE_O := Vector2(448.0, 308.0)
## The probe a palette is measured from: the zoom's window round the centre,
## one block in four.
const PROBE := Vector2i(224, 154)
## The zooms the mockup was built at; each has its own palette and its own grid
## of extra stars. A zoom between two uses the nearer.
const LEVELS: Array[float] = [0.42, 0.59, 0.84, 1.18, 1.66, 2.35, 3.3, 4.65, 6.0]
## A ball's story's light in this style's own (`ChartSky.ball_story`)
const STORY_GAIN_L := 3.0
const TILT := 0.38
const DISC := 2.05
## Twelve hours a turn: half an hour read 5x too fast, 2.5 hours still did, mostly from the
## hole climb.
## Why: docs/why/ChartLegacy.md#galaxy-turn-speed
const TURN_MINUTES := 720.0
const OMEGA := TAU / (TURN_MINUTES * 60.0)
## The hole's size against the galaxy's own (`hole_r`), the same at every zoom.
const HOLE_K := 2.0
## Disc reaches 3 hole radii, down from 4 once the hole stopped shrinking on zoom.
const DISC_K := 3.0
## How far the dust is spread in the bake, in its pixels (see `_stage_fields`).
const DUST_SPREAD := 2.0

const SPLAT_SH := preload("res://shaders/chart_l_bake_splat.gdshader")
const BLUR_SH := preload("res://shaders/chart_l_bake_blur.gdshader")
const BASE_SH := preload("res://shaders/chart_l_bake_base.gdshader")
const FIELD_SH := preload("res://shaders/chart_l_field.gdshader")
const STARS_SH := preload("res://shaders/chart_l_stars.gdshader")
const HOLE_SH := preload("res://shaders/chart_l_hole.gdshader")
const PAL_SH := preload("res://shaders/chart_l_palette.gdshader")
const LUT_SH := preload("res://shaders/chart_l_palette_lut.gdshader")
const SOLID_BAKE_SH := preload("res://shaders/chart_l_bake_solid.gdshader")
## THE SOLID LOOK'S TWO FIELDS (`chart_l_bake_solid`): how big, and over how much of
## the plane (gu either way), as SIMPLIFIED's noise bake is.
const SOLID_BAKE := 1024
const SOLID_EXT := 1.2
## How much further out than the shared radii LEGACY's edge fades (`_push`).
const EDGE_K := 1.2
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
## Nebula look 4 (Jon, 2026-10-04: "These are nice"). Others kept for comparison via
## `ChartLook neblook=N`.
## Why: docs/why/ChartLegacy.md#look-settings
static var nebula_look := 4
## Look 4 remade the clouds for the new chart, pending Jon's pick: vivid, rising and
## churning with the gas.
## Why: docs/why/ChartLegacy.md#look-settings

## Star level 4 is about an eighth of what shipped, as level 3 was still 2x too high (Jon).
## Thinned by brightness.
## Why: docs/why/ChartLegacy.md#look-settings
static var star_level := 4

## Depth look 3 is Jon's pick, layers and fluffy cloud both, as strong as `depth_amt`.
## Why: docs/why/ChartLegacy.md#look-settings
static var depth_look := 3
## Depth amount 0.9, Jon's pick from four levels (2026-10-04: "That looks great").
## Why: docs/why/ChartLegacy.md#look-settings
static var depth_amt := 0.9

## Disc volume 3, tall billows, Jon's pick (2026-10-04: "I like 3").
## Why: docs/why/ChartLegacy.md#look-settings
static var volume_look := 3
const VOLUME_H := [0.0, 4.0, 7.0, 11.0]
## Gas look 3 for now, dense puffy gas, for Jon to try in game.
## Why: docs/why/ChartLegacy.md#look-settings
static var gas_look := 3
## Gas churns (Jon: billow slightly and move); still under reduced motion. On, for Jon to
## try.
## Why: docs/why/ChartLegacy.md#look-settings
static var gas_billow := true
## Globular clusters as a soft warm glow, as Jon said the block-star version looked like
## popcorn.
## Why: docs/why/ChartLegacy.md#look-settings
static var cluster_look := 1
const GAS_K := [0.0, 0.06, 0.16, 0.35]
## The star field as textures, by `MapChart._star_key`: a chart opened again
## on the same galaxy finds them made.
static var _pts_cache: Dictionary = {}
## The one node that runs bakes (`_request_bake`), under the scene's root, so
## a bake finishes even if the chart that asked for it has closed.
static var _baker: ChartLegacy = null
var chart: StarchartScreen.MapChart = null
## The ChartSky this renderer draws for (its parent; none for the baker): THE SOLID
## LOOK's camera and uniforms are its (`solid_frame`, `push_solid`, `push_solid_stars`).
var sky: ChartSky = null

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
var _hole: ColorRect = null
var _pal: ColorRect = null
var _m_field: ShaderMaterial = null
var _m_stars: ShaderMaterial = null
var _m_hole: ShaderMaterial = null
var _m_pal: ShaderMaterial = null
var _vp_origin := Vector2.ZERO
var _shown_li := -1
## The zoom's hold (see `_push`).
var _last_zoom := -1.0
var _since_zoom := 999
var _hold_d := Vector2.ZERO
var _hold_c := Vector2.ZERO
## the view's pan last frame: the zoom's hold lets go when it moves (`_push`)
var _last_pan := Vector2(INF, INF)
## Colour hold, as SIMPLIFIED's: last frame's copy feeds the palette pass, with its anchor
## and zoom.
var _hvp: SubViewport = null
var _hold_b0 := Vector2(INF, INF)
var _hold_z := -1.0
var _hold_frame := -1
var _hold_ref := Vector2(INF, INF)
var _hold_ref_z := -1.0
var _hold_ref_c := Vector2.ZERO
var _hold_ref_o := Vector2.ZERO
var _hold_c_now := Vector2.ZERO
var _hold_o_now := Vector2.ZERO
var _hold_bad := false
var _frame_pan := false
var _frame_zoom := false
## the solid look's camera as each frame drew (`_push`): on, the camera, where it
## looked, screen px a gu -- this frame's and the last drawn frame's, for the hold
var _cam_now := Vector4.ZERO
var _cam_now_t := Vector2.ZERO
var _kgu_now := 0.0
var _sol_now := false
var _cam_ref := Vector4.ZERO
var _cam_ref_t := Vector2.ZERO
var _kgu_ref := 0.0
var _sol_ref := false
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
	return ChartSky.galaxy_key() + "|legacy"


## A harness's `style=legacy` can draw it while DisplaySettings refuses a style not built
## everywhere.
static func wanted() -> bool:
	return DisplaySettings.render_style == &"legacy" or "style=legacy" in OS.get_cmdline_user_args()


## Every galaxy lies in the sector map's plane (TILT, per Jon); a ragged spiral used to be
## drawn rounder.
static func eff_of(_g: Dictionary) -> float:
	# Ball-shaped galaxies read face-on and a pulsar sat 62px off its remnant. One plane now
	# (Jon).
	# Why: docs/why/ChartLegacy.md#one-plane-for-all
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
	sky = get_parent() as ChartSky
	# (the sky's camera is the run's chart's only, as its own draw would have it: the
	# title screen's galaxy is drawn flat)
	if sky != null:
		sky._use_map = _use_map
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
		_baker = ChartLegacy.new()
		_baker.name = "ChartLegacyBake"
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
	# Supernova sites follow SIMPLIFIED's rule: bright disc star between bulge and rim.
	# Pulsars in the plane.
	var sq := float(Run.galaxy.get("squash", 0.62))
	var cand := PackedVector2Array()
	var in_glob := PackedByteArray()
	in_glob.resize(c._star_pos.size())
	for k in c._glob_i.size() / 2:
		for j in range(c._glob_i[k * 2], mini(c._glob_i[k * 2 + 1], c._star_pos.size())):
			in_glob[j] = 1
	for i in c._star_pos.size():
		if c._star_big[i] == 2 or in_glob[i] == 1:
			continue
		var cc := c._star_col[i]
		if c._star_big[i] == 0 and maxf(cc.r, maxf(cc.g, cc.b)) < 0.075:
			continue
		if (0.3 * cc.r + 0.59 * cc.g + 0.11 * cc.b) * 255.0 < 60.0:
			continue
		var pl := Vector2(c._star_pos[i].x / r_max, c._star_pos[i].y / r_max / sq)
		if pl.length() > 0.16 and pl.length() < 0.9:
			cand.append(pl)
	out["sn_cand"] = cand
	var puls := PackedVector2Array()
	for pp: Vector2 in c._pulsar:
		puls.append(Vector2(pp.x / r_max, pp.y / r_max / sq))
	out["pulsars"] = puls
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
	# SIMPLIFIED's hole (its shadow's radius in galaxy radii), drawn here as there
	var c_hole: float = ChartSky.params(use_map).hole_r
	var arm_k := 0.0
	if arms > 0:
		arm_k = clampf(1.0 - chaos * 1.8, 0.0, 1.0) * (0.75 if arms >= 5 else 1.0)
	var p := {
		"sq": sq, "arms": arms, "chaos": chaos, "gas": gas, "dk": dk, "eff": eff,
		"bsq": bsq, "big_r": big_r, "bul": bul, "shadow": shadow, "arm_k": arm_k, "c_hole": c_hole,
		"bar": float(g.get("bar", 0.0)), "twist": float(g.get("twist", 3.0)),
		"spin": Run.galaxy_spin,
		"sd": fmod(float(Run.galaxy_kind) * 7.31 + Run.galaxy_spin, 50.0),
		"lane": minf(1.1, gas) * 0.95 if (arms > 0 and gas >= 0.35) else 0.0,
	}
	_nebula_lobes(p, sq)
	var pals := _gas_palette(gas)
	p["pal0"] = pals[0]
	p["pal1"] = pals[1]
	_ball_params(p)
	# The climb toward the hole stays inside the innermost ring of systems.
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
	# The climb stops at the hole's edge: running to the ring whirled the bulge 100s of times
	# too fast.
	# Why: docs/why/ChartLegacy.md#hole-climb-limit
	p["rb"] = rin_p * 1.05
	# the innermost ring's reach, which still bounds the lens and the swirl
	p["rb_ring"] = maxf(rin_p * 1.05, 0.85 * ring - 2.0)
	return p


## A ball in this style's hand (Nov 5, direction A): the bulge's own light, cool gas only where
## the kind has gas. (look, how far out the warm light holds in ball radii, how lumpy 0..1,
## how irregular its outline 0..1)
## Why: docs/why/ChartLegacy.md#ball-in-this-style
static func ball_kind(ball: Vector4) -> Vector4:
	match int(ball.w):
		1:
			return Vector4(1.0, 0.25, 1.0, 0.35)
		2:
			return Vector4(2.0, 9.0, 0.25, 0.1)
		3:
			return Vector4(3.0, 1.1, 0.5, 0.3)
	return Vector4(0.0, 9.0, 0.3, 0.0)


## A ball's body (`ball_light`'s `ball_f`): (size against its ball radius, how steeply its light
## falls, where it ends in ball radii, its globular-cluster halo 0..1); PAINTED's, a blue
## compact dwarf's fall gentler.
## Why: docs/why/ChartLegacy.md#ball-body
static func ball_form(kind: int) -> Vector4:
	if GalaxyGen.type_name(kind) == "Blue Compact Dwarf":
		return Vector4(1.0, 1.0, 2.4, 0.0)
	return ChartPainted.ball_form(kind)


## How much of the disc's gas a ball keeps (`chart_l_field`'s volume of puffs, `ball_gas`):
## its puffs stand where its light is, so an old ball's are few and low.
static func ball_gas(ball: Vector4) -> float:
	match int(ball.w):
		1:
			# (not all of a disc's: its puffs stand up off the plane, and at a disc's
			# volume a blue compact dwarf's light rose well above its core, BallHaloTest)
			return 0.6
		2:
			return 0.15
		3:
			# (low as an old ball's: its puffs' dim sides fell on the palette's crimson, red
			# stains over its warm body)
			return 0.2
	return 0.3


## How many globular clusters ring a giant (`_ball_params`).
const BALL_GC := 24


## The ball's constants, on the galaxy's (`params`): none of them read for a disc.
static func _ball_params(p: Dictionary) -> void:
	var kind := Run.galaxy_kind
	var on := ChartSky.form_of(kind) == 1
	var ball := ChartSky.ball_of(kind, Run.galaxy)
	var bf := ball_form(kind)
	p["ball_on"] = on
	p["ball"] = ball
	p["ball_k"] = ball_kind(ball)
	p["ball_f"] = bf
	p["ball_sq"] = ChartPainted.ball_squash(kind, ball)
	# (the ball's radius in bake px: a galaxy radius is `big_r` of them, as the hole's is)
	p["ball_r"] = ball.x * bf.x * float(p.big_r)
	p["ball_gas"] = ball_gas(ball) if on else 1.0
	# A DWARF'S HOLE AT ITS OWN SIZE (`ChartSky.hole_of`): drawn at most
	# `ChartSky.DWARF_HOLE` of its ball, so a blue compact dwarf is not a hole with a
	# ring round it. Only the drawing: the chart keeps its marks clear of the hole's own
	# radius (`hole_px`, `rin_p`), as before.
	p["c_hole_draw"] = minf(float(p.c_hole), ChartSky.DWARF_HOLE * ball.x) \
		if on and (int(ball.w) == 1 or int(ball.w) == 2) else float(p.c_hole)
	# the giant's globular clusters, far past its body (`chart_l_field`'s `ball_gc`):
	# fixed in the galaxy, in screen-tilted bake px as `glob_c` are
	var gcs := PackedVector2Array()
	if on and bf.w > 0.0:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([Run.galaxy_seed, kind, 6113])
		var br: float = p.ball_r
		for i in BALL_GC:
			var a := rng.randf() * TAU
			var r := br * (0.9 + 1.8 * pow(rng.randf(), 0.8))
			gcs.append(Vector2(cos(a) * r, sin(a) * r * float(p.ball_sq)))
	p["ball_gc"] = gcs
	# the merger's stream: which side it curls off
	p["ball_side"] = 1.0 if absi(hash([Run.galaxy_seed, kind, 3307])) % 2 == 0 else -1.0


## The knots a young ball's gas is full of (a blue compact dwarf's; a few in a merger's
## remnant, lit by the merger), in `ChartSky._make_knots`'s own form, inside its body:
## the knots the field already draws for a spiral (pink cores, breathing, blooming).
static func _ball_knots(p: Dictionary) -> Array:
	var out: Array = []
	var ball: Vector4 = p.ball
	var want := 0
	match int(ball.w):
		1:
			want = 22
		3:
			want = 6
	if not bool(p.ball_on) or want == 0:
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([Run.galaxy_seed, Run.galaxy_kind, 978])
	var rg := ball.x * (p.ball_f as Vector4).x
	# (in the plane, as the field reads a knot: a screen offset's y over the tilt)
	var sqk: float = float(p.ball_sq) / float(p.eff)
	for i in want:
		var a := rng.randf() * TAU
		# (inside the gas: past it a knot was a red streak on the dark)
		var r := rg * (0.1 + (0.6 if int(ball.w) == 1 else 0.8) * sqrt(rng.randf()))
		var size := 0.003 + 0.006 * rng.randf()
		var st: Array[Vector3] = []
		var ns := 3 + int(rng.randf() * 3.0)
		for j in ns:
			var aa := rng.randf() * TAU
			var rr := size * (0.4 + 1.3 * rng.randf())
			st.append(Vector3(cos(aa) * rr, sin(aa) * rr, 0.35 + 0.6 * rng.randf()))
		out.append({"xy": Vector2(r * cos(a), r * sin(a) * sqk), "size": size, "T": 20.0 + 40.0 * rng.randf(),
			"ph": rng.randf() * TAU, "st": st})
	return out


## The drawn hole's radius in screen px (`hole_r`, a dwarf's held to its ball:
## `_ball_params`' `c_hole_draw`).
static func hole_draw(p: Dictionary, z: float) -> float:
	return float(p.c_hole_draw) * float(p.big_r) * z


## Each lobe sits where the bake put its gas, in the cloud's colour, with its cloud id so
## one breathes whole.
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
		# A shell is one shell (Jon: remnants should be hollow), drawn once round the cloud's
		# centre.
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


## Hole is 2x the galaxy's one scale at every zoom; easing 2.6x to 1.3x made it read as
## shrinking (Jon).
## Why: docs/why/ChartLegacy.md#hole-size
static func hole_r(p: Dictionary, z: float) -> float:
	return float(p.c_hole) * float(p.big_r) * z


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


## One frame per step: same-frame viewports draw in an unchosen order, and a blur before
## its points is black.
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
	_job = {"stage": 1, "frame": Engine.get_frames_drawn(), "holder": holder,
		"groups": [across, down, [probe]],
		"chains": chains, "probe": probe, "p": p, "key": _key}


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
	# a ball's body (`_ball_params`, `ball_light`)
	m.set_shader_parameter("ball_on", p.ball_on)
	if p.ball_on:
		for k in ["ball_k", "ball_f", "ball_sq", "ball_r", "ball_side"]:
			m.set_shader_parameter(k, p[k])
	return m


## The black hole's radius on the screen now, in screen pixels (0 before the
## sky is made): the chart keeps its marks out of it.
func hole_px() -> float:
	if chart == null or not _baked.has(_key):
		return 0.0
	# (through the solid look's camera the hole is drawn at the camera's scale at the
	# core, `_solid_on`)
	return hole_r(_baked[_key].p, _z()) * (_core_k() if _solid_on() else 1.0)


## Whether the chart is seen through the solid look's camera (`ChartSky.solid`, LEGACY's
## line in `SOLID_STYLES`): the run's chart, once its solid fields are baked.
func _solid_on() -> bool:
	return sky != null and _use_map and ChartSky.solid() and (_baked.get(_key, {}) as Dictionary).has("s_struct")


## How much the camera magnifies the core (the shader's solidCoreK).
static func _core_k() -> float:
	var w := ChartSky.solid_cam()
	return w.x / (w.x + ChartSky.SOLID_T.y * w.z)


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
	var chains: Array[SubViewport] = _job.chains
	var outs := []
	for mode in [1, 2, 3, 4]:
		var m := _base_mat(chains, p, mode)
		for k in norms:
			m.set_shader_parameter(k, norms[k])
		var size := Vector2i(BAKE.x / 2, BAKE.y / 2) if mode == 3 else BAKE
		m.set_shader_parameter("out_size", Vector2(size))
		outs.append(_pass_vp(_job.holder, size, _rect(m)))
	# Dust is blurred here: at a bake pixel a lane is a one-pixel crease that every zoom
	# magnifies to a crack.
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
	var g := {"p": _job.p, "pals": {}, "held": _held_level(), "one": _use_map}
	# SIMPLIFIED's knots, supernovae and pulsars, placed as it places them
	g["knots"] = _ball_knots(_job.p) if _job.p.ball_on else ChartSky._make_knots(ChartSky.params(_use_map))
	g["sn_cand"] = _pts.get("sn_cand", PackedVector2Array())
	g["pulsars"] = _pts.get("pulsars", PackedVector2Array())
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
	# THE SOLID LOOK's two fields, from this bake (`chart_l_bake_solid`): read back with
	# the palettes' probes and mip-mapped, as SIMPLIFIED's bakes are
	var p: Dictionary = g.p
	var sv := []
	for mode in 2:
		var ms := ShaderMaterial.new()
		ms.shader = SOLID_BAKE_SH
		ms.set_shader_parameter("mode", mode)
		ms.set_shader_parameter("ext", SOLID_EXT)
		ms.set_shader_parameter("aux_tex", g.aux)
		ms.set_shader_parameter("dust_tex", g.dust)
		ms.set_shader_parameter("bake_size", Vector2(BAKE))
		ms.set_shader_parameter("bake_origin", BAKE_O)
		for k in ["big_r", "eff", "arm_k", "sd"]:
			ms.set_shader_parameter(k, p[k])
		ms.set_shader_parameter("lane_amt", p.lane)
		sv.append(_pass_vp(_job.holder, Vector2i(SOLID_BAKE, SOLID_BAKE), _rect(ms), false))
	_job.solid = sv
	_job.stage = 3
	_job.frame = Engine.get_frames_drawn()


## Palette worked out here so the chart never opens on wrong colours. Near twins merged for
## zooms in.
## Why: docs/why/ChartLegacy.md#palette-stage
const HELD_MERGED := 100


func _stage_palettes() -> void:
	var probes: Array = _job.probes
	var stars := _star_hist()
	var now := _level_now()
	var each := not _use_map or diag & 8
	for li in probes.size():
		if li != now and not each:
			continue
		var img := (probes[li] as SubViewport).get_texture().get_image()
		if li == now:
			var pal := _make_palette(img, stars, _bulge_box(li), _cloud_hues(), _merge_of(li))
			_bake_lut(li, pal)
			if _use_map:
				_bake_lut(HELD_MERGED, _merge_near(pal, pal_merge * 1.3))
		else:
			var job := PaletteJob.new()
			job.probe = img
			job.stars = stars
			job.bulge = _bulge_box(li)
			job.hues = _cloud_hues()
			job.merge = _merge_of(li)
			var id := WorkerThreadPool.add_task(job.run, false, "chart palette")
			_tasks[li] = [id, job, _key]
	var sv: Array = _job.get("solid", [])
	if sv.size() == 2 and _baked.has(_key):
		var gk: Dictionary = _baked[_key]
		for i in 2:
			var im := (sv[i] as SubViewport).get_texture().get_image()
			if im != null:
				im.generate_mipmaps()
				gk["s_noise" if i == 0 else "s_struct"] = ImageTexture.create_from_image(im)
	var holder: Node = _job.holder
	_job = {}
	holder.queue_free()


func _level_now() -> int:
	return _held_level()


## One palette at every zoom (Oct 11, Jon): per-zoom cuts leaned purple and teal deep in
## the arms.
## Why: docs/why/ChartLegacy.md#one-palette
func _held_level() -> int:
	return 0 if _use_map else _level0


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
	var merge := 0.0
	var out := PackedColorArray()

	func run() -> void:
		out = ChartLegacy._make_palette(probe, stars, bulge, hues, merge)


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


## Median cut weighted to vivid and rare hues so a small patch of pink gas is not averaged
## away.
## Why: docs/why/ChartLegacy.md#palette-of-one-zoom
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


static func _make_palette(probe: Image, stars: Dictionary, bulge: Rect2i, cloud_hues: PackedColorArray,
		merge: float = 0.0) -> PackedColorArray:
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
	# The bulge's own cut: a large share of the picture in a narrow warm band would give only
	# a cream or two.
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
	# Two steps between sky and each dark gas colour, so gas thins in steps, not sky-to-brown
	# (Jon: blocky islands).
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
	for c: Color in STAR_WARM + STAR_COOL:
		out.append(c)
		out.append(Color(c.r * 0.72, c.g * 0.72, c.b * 0.72))
	# The bulge's own amber-to-gold steps, toned like the field, so its gradient survives the
	# palette.
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
	return _merge_near(out, merge)


## Near twins merged (`pal_merge`): measured on a slow zoom, flip-backs were mostly between
## near-identical browns.
## Why: docs/why/ChartLegacy.md#palette-near-twins
static var pal_merge := 26.0

## Jon's call: false keeps the flicker guards (under 0.0035 flip-backs); true keeps the old
## grain, 0.0146 to 0.0172.
## Why: docs/why/ChartLegacy.md#grain-or-flicker
const KEEP_OLD_GRAIN := false
## What a zoom changes, one cause at a time switched off (tuning; `ChartSky.diag`).
static var diag := 0


static func _merge_of(li: int) -> float:
	if KEEP_OLD_GRAIN:
		return 0.0
	return pal_merge * _aa_of(LEVELS[li])


## How strict the flicker's guards are at a zoom (SIMPLIFIED's units, 622.25
## screen px a galaxy radius): none at the opening view (0.42), in full from 0.7.
static func _aa_of(zc: float) -> float:
	if KEEP_OLD_GRAIN:
		return 0.0
	return _sm(0.42, 0.7, zc)


static func _merge_near(pal: PackedColorArray, merge: float) -> PackedColorArray:
	if merge <= 0.0:
		return pal
	var out := PackedColorArray()
	var lim := merge * merge
	for c in pal:
		var keep := true
		for k in out:
			var dr := (c.r - k.r) * 255.0
			var dg := (c.g - k.g) * 255.0
			var db := (c.b - k.b) * 255.0
			if dr * dr * 2.0 + dg * dg * 4.0 + db * db * 3.0 < lim:
				keep = false
				break
		if keep:
			out.append(c)
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
		LegacyHole.apply(_m_field, TILT)
		_field = _rect(_m_field)
		_vp.add_child(_field)
		_vp.add_child(_bbc())
		_m_stars = ShaderMaterial.new()
		_m_stars.shader = STARS_SH
		_stars = MeshDraw.new()
		_stars.material = _m_stars
		_vp.add_child(_stars)
		_vp.add_child(_bbc())
		_m_hole = ShaderMaterial.new()
		_m_hole.shader = HOLE_SH
		LegacyHole.apply(_m_hole, TILT)
		_hole = _rect(_m_hole)
		_vp.add_child(_hole)
		_vp.add_child(_bbc())
		_m_pal = ShaderMaterial.new()
		_m_pal.shader = PAL_SH
		_pal = _rect(_m_pal)
		_vp.add_child(_pal)
		# A copy made once a frame, so the palette pass always reads the frame before.
		_hvp = SubViewport.new()
		_hvp.transparent_bg = false
		_hvp.disable_3d = true
		_hvp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(_hvp)
		var copy := TextureRect.new()
		copy.texture = _vp.get_texture()
		copy.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hvp.add_child(copy)
		_m_pal.set_shader_parameter("prev_tex", _hvp.get_texture())
		_hold_b0 = Vector2(INF, INF)
		_hold_frame = -1
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
	m.set_shader_parameter("old_grain", KEEP_OLD_GRAIN)
	m.set_shader_parameter("diag_sheets", bool(diag & 64))
	# (the dust sheets held at the opening's nearness: the chart's opening zoom, or
	# the title screen's own, which never zooms)
	m.set_shader_parameter("sheet_z", 1.0 if _use_map else z)
	m.set_shader_parameter("core_wide", not _use_map)
	m.set_shader_parameter("sl_tex", g.sl)
	m.set_shader_parameter("aux_tex", g.aux)
	m.set_shader_parameter("gc_tex", g.gc)
	m.set_shader_parameter("dust_tex", g.dust)
	m.set_shader_parameter("bake_size", Vector2(BAKE))
	m.set_shader_parameter("bake_origin", BAKE_O)
	m.set_shader_parameter("z", z)
	m.set_shader_parameter("zf", 1.0)
	for k in ["eff", "bsq", "bul", "sd", "gas", "pal0", "pal1", "rin_p", "rb", "rb_ring"]:
		m.set_shader_parameter(k, p[k])
	m.set_shader_parameter("dk_g", p.dk)
	m.set_shader_parameter("ball_core", ChartSky.form_of(Run.galaxy_kind) == 1 and _use_map)
	# a ball's own (`_ball_params`): how much of the disc's gas it keeps, its globular clusters
	m.set_shader_parameter("ball_on", p.ball_on)
	if p.ball_on:
		m.set_shader_parameter("ball_gas", p.ball_gas)
		# (the glow no wider than its warm light: a blue compact dwarf's warm heart is a
		# quarter of its ball, and a glow at its whole ball was a brown plate round its gas)
		m.set_shader_parameter("ball_rpx", float(p.ball_r) * clampf((p.ball_k as Vector4).y * 1.6, 0.4, 1.3))
		# (its outer haze, in the ball's own frame: its radius, and the plane's y to it)
		m.set_shader_parameter("ball_hz", Vector2(float(p.ball_r), float(p.eff) / maxf(float(p.ball_sq), 0.05)))
		var bgc: PackedVector2Array = (p.ball_gc as PackedVector2Array).duplicate()
		m.set_shader_parameter("n_ball_gc", bgc.size())
		bgc.resize(BALL_GC)
		m.set_shader_parameter("ball_gc", bgc)
	ChartSky.push_story(m, STORY_GAIN_L if _use_map else 0.0)
	m.set_shader_parameter("arm_k", p.arm_k)
	m.set_shader_parameter("big_r", p.big_r)
	m.set_shader_parameter("lane_amt", p.lane)
	m.set_shader_parameter("neb_a", p.neb_a)
	m.set_shader_parameter("neb_b", p.neb_b)
	m.set_shader_parameter("neb_n", p.neb_n)
	var gas: float = p.gas
	var nuc := 0.0
	if gas >= 0.35 and float(p.dk) > 0.5:
		nuc = minf(1.0, gas) * 1.1 * 0.45
	m.set_shader_parameter("nuc_amt", nuc)
	var rh := hole_draw(p, z)
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
	# Zooming only magnifies (Oct 11): light and exposure are held at the opening zoom; only
	# detail is added.
	# Why: docs/why/ChartLegacy.md#zoom-only-magnifies
	var zfd := minf(zf, 1.0 / LEVELS[0]) if diag & 4 else zf
	var extra := maxf(0.0, log(zfd) / log(2.0))
	m.set_shader_parameter("oct", minf(extra, 4.0))
	m.set_shader_parameter("det_k", minf(1.0, extra / 2.0))
	m.set_shader_parameter("zoom_dim", 0.0)
	m.set_shader_parameter("resolved", 1.0)
	m.set_shader_parameter("dz", 0.0)
	m.set_shader_parameter("res2", 1.0)
	# the core's own glare, the one thing the zoom still turns down: the bulge's glow
	m.set_shader_parameter("core_res", 1.0 if diag & 1 else 1.0 / (1.0 + 0.4 * (zf - 1.0)))
	m.set_shader_parameter("core_dz", 0.0 if diag & 1 else _sm(1.8, 8.0, zf))
	m.set_shader_parameter("te_b", 2.7756 * rh / z * 1.6)
	# (the old hole's swirl of gas round it goes: SIMPLIFIED's disc is the hole)
	m.set_shader_parameter("swirl_amp", 0.0)
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
	# During a zoom the blocks work about the exact centre on a screen-held grid, since whole-
	# pixel rounding jittered.
	# Why: docs/why/ChartLegacy.md#zoom-hold
	var exact: Vector2 = chart.size * 0.5 + chart.pan
	var zooming := _last_zoom > 0.0 and absf(log(chart.zoom / _last_zoom)) > 1e-7
	_last_zoom = chart.zoom
	var was_held := _since_zoom < 61
	# The hold lets go on a pan, not a clock: timed release popped a pixel a second after
	# every zoom (Oct 10).
	# Why: docs/why/ChartLegacy.md#zoom-hold
	var panned := chart.pan != _last_pan
	_last_pan = chart.pan
	if zooming:
		_since_zoom = 0
	elif panned:
		_since_zoom = mini(maxi(_since_zoom, 59) + 1, 999)
	elif _since_zoom < 59:
		_since_zoom += 1
	var zw := 1.0 if _since_zoom < 60 else maxf(0.0, 1.0 - float(_since_zoom - 59) * 0.5)
	var ccon := cpix + (exact - cpix) * zw
	if zw > 0.0 and not was_held:
		_hold_c = cpix
	var anchor := _hold_c if zw > 0.0 else cpix
	# Galaxy on an even pixel (Oct 13, Jon): the 2x2 grid hopped far stars back on a slow pan.
	if zw <= 0.0:
		var even := (cpix / 2.0).floor() * 2.0
		ccon += even - cpix
		cpix = even
		anchor = even
	# only the part of the chart that can be seen (the title's chart is a square
	# bigger than the screen), a block's margin round it
	var vis := _visible_rect()
	var vx := floorf(vis.position.x)
	var vy := floorf(vis.position.y)
	_vp_origin = Vector2(vx - posmod(int(vx) - int(anchor.x), 2) - 2.0, vy - posmod(int(vy) - int(anchor.y), 2) - 2.0)
	# The same size whichever way the blocks fall: a viewport resized on every
	# odd pixel of a drag reallocates its picture every other frame.
	var vsz := Vector2i(ceili(vis.size.x / 2.0) + 3, ceili(vis.size.y / 2.0) + 3)
	var resized := _vp.size != vsz
	if resized:
		_vp.size = vsz
		if _hvp != null:
			_hvp.size = vsz
			(_hvp.get_child(0) as Control).size = Vector2(vsz)
		for r: ColorRect in [_field, _hole, _pal]:
			r.size = Vector2(vsz)
	var vs := Vector2(vsz)
	# the dither's anchor: the galaxy's centre, or, while held, the screen
	var b0 := ((_vp_origin - cpix) / 2.0).floor()
	var bs := (_vp_origin / 2.0).floor()
	if zw > 0.0:
		if not was_held:
			_hold_d = b0 - bs
		b0 = bs + _hold_d
	var m := _m_field
	_feed_field(m, g, z)
	m.set_shader_parameter("vp_size", vs)
	m.set_shader_parameter("vp_origin", _vp_origin)
	m.set_shader_parameter("cpix", ccon)
	m.set_shader_parameter("phi", phi)
	m.set_shader_parameter("t", t)
	m.set_shader_parameter("probe", false)
	m.set_shader_parameter("lens_shadow", hole_draw(p, z))
	m.set_shader_parameter("sky_pan", chart.sky_pan.round())
	m.set_shader_parameter("u_skyPan", chart.sky_pan.round())
	m.set_shader_parameter("u_skySeed", float(posmod(Run.galaxy_seed, 997)))
	m.set_shader_parameter("sky_seed", (Run.galaxy_seed % 100003) * 31)
	# ON THE FIELD (`NavField`): its own sky behind off, the field's stars the
	# chart's (`StarchartScreen.MapChart.on_field`, the key on `ChartSky`)
	var fld := chart != null and bool(chart.get("on_field"))
	m.set_shader_parameter("sky_own", not fld)
	m.set_shader_parameter("u_bgOn", 0.0 if fld else 1.0)
	var glow := _nebula_glow(p)
	m.set_shader_parameter("neb_glow", glow)
	m.set_shader_parameter("neb_style", nebula_look)
	# the extra stars deep in: the scale of the mockup's density (the shader
	# works out each of its fixed grids' share, `chart_l_field`)
	m.set_shader_parameter("filler_k", (0.0 if diag & 2 else 1.0) * float(p.eff) * 0.25 * [1.0, 1.0, 0.5, 0.25, 0.125][clampi(star_level, 1, 4)])
	m.set_shader_parameter("star_level", star_level)
	_feed_events(m, g, t, phi, z)
	# Solid look: the sky steps the camera once a frame and feeds the uniforms in LEGACY's own
	# units.
	# Why: docs/why/ChartLegacy.md#solid-look
	var sol := false
	if sky != null and _use_map and g.has("s_struct"):
		sol = sky.solid_frame(t)
	var kgu := z * float(p.big_r)
	if sky != null:
		sky.push_solid(m, sol)
	# Legacy keeps its own size (Jon, "2B"): its disc is lit further out, so the edge fades at
	# 1.2x radii.
	if sol and ChartSky.edge_on():
		var ed := ChartSky.edge()
		m.set_shader_parameter("u_edge", Vector4(ed.x * EDGE_K, ed.y * EDGE_K, ed.z, 1.0))
	# (tuning, `diag`: the solid look's parts off one at a time -- 65536 the puffs,
	# 131072 the relief, 262144 the edge, 524288 the nebulae's bodies)
	if diag & 65536:
		m.set_shader_parameter("u_fluff", 0.0)
	if diag & 131072:
		m.set_shader_parameter("u_terr", 0.0)
	if diag & 262144:
		m.set_shader_parameter("u_edge", Vector4.ZERO)
	if diag & 524288:
		m.set_shader_parameter("u_neb", 0.0)
	m.set_shader_parameter("u_k", kgu)
	m.set_shader_parameter("u_phi", phi)
	m.set_shader_parameter("u_laneStr", float(p.lane))
	if g.has("s_struct"):
		m.set_shader_parameter("u_struct", g.s_struct)
		m.set_shader_parameter("u_noise", g.s_noise)
	var pc := ChartSky.solid_fwd(Vector2.ZERO) * kgu if sol else Vector2.ZERO
	var kc := _core_k() if sol else 1.0
	# (the harness's solidtest, `ChartSky.diag` 4096: the field writes the plane point
	# it shows, into a picture of floats, with nothing drawn over it)
	var dg := (ChartSky.diag & 4096) != 0
	m.set_shader_parameter("diag_plane", dg)
	if _vp.use_hdr_2d != dg:
		_vp.use_hdr_2d = dg
	for it: CanvasItem in [_stars, _hole, _pal]:
		it.visible = not dg

	var ms := _m_stars
	if sky != null:
		sky.push_solid_stars(ms, sol)
	ms.set_shader_parameter("kgu", kgu)
	ms.set_shader_parameter("vp_origin", _vp_origin)
	ms.set_shader_parameter("cpix", ccon)
	ms.set_shader_parameter("z", z)
	ms.set_shader_parameter("diag", diag)
	ms.set_shader_parameter("phi", phi)
	ms.set_shader_parameter("t", t)
	ms.set_shader_parameter("rin_p", p.rin_p)
	ms.set_shader_parameter("rb", p.rb)
	ms.set_shader_parameter("star_level", star_level)
	ms.set_shader_parameter("near_r", hole_draw(p, z) * DISC_K * 1.3)

	# SIMPLIFIED's hole at its size and zooms, in this chart's units of 622.25 screen px a
	# radius.
	var zc := z * float(p.big_r) / ChartSky.K0
	var mh := _m_hole
	mh.set_shader_parameter("vp_size", vs)
	mh.set_shader_parameter("vp_origin", _vp_origin)
	mh.set_shader_parameter("cpix", ccon + pc)
	mh.set_shader_parameter("shadow", hole_draw(p, z) * kc)
	mh.set_shader_parameter("t", t)
	mh.set_shader_parameter("clumps", 0.0 if diag & 128 else _sm(2.6, 4.0, zc))
	mh.set_shader_parameter("cool_amt", 0.0 if diag & 128 else _sm(3.0, 6.0, zc))
	mh.set_shader_parameter("cool_wide", diag & 1024 != 0)
	mh.set_shader_parameter("hot_on", 0.0 if DisplaySettings.reduced_motion else 1.0)

	var mp := _m_pal
	mp.set_shader_parameter("vp_size", vs)
	mp.set_shader_parameter("block0", b0)
	# Compared with the last frame drawn: a moving view pushes twice a frame and the second
	# measures no shift.
	var fd := Engine.get_process_frames()
	if fd != _hold_frame:
		_hold_frame = fd
		_hold_ref = _hold_b0
		_hold_ref_c = _hold_c_now
		_hold_ref_o = _hold_o_now
		_hold_ref_z = _hold_z
		_cam_ref = _cam_now
		_cam_ref_t = _cam_now_t
		_kgu_ref = _kgu_now
		_sol_ref = _sol_now
		_hold_bad = false
		_frame_pan = false
		_frame_zoom = false
	_hold_bad = _hold_bad or resized
	# (through the solid look's camera what is held follows the camera, `cam_on`:
	# nothing held as it comes on or goes off)
	_hold_bad = _hold_bad or sol != _sol_ref
	_frame_pan = _frame_pan or panned
	_frame_zoom = _frame_zoom or zooming
	# Nothing held on a pure drag: held to the galaxy's shift the far sky's dim colours
	# streaked the halo.
	var dragging := _frame_pan and not _frame_zoom
	var jump := _hold_ref_z > 0.0 and absf(log(z / _hold_ref_z)) > 0.03
	_hold_z = z
	_hold_c_now = ccon
	_hold_o_now = _vp_origin
	var valid := _hold_ref.x != INF and not _hold_bad and not jump and not dragging and (b0 - _hold_ref).length() < 8.0
	# last frame's view, to find where each block's piece of the galaxy was drawn
	mp.set_shader_parameter("cur_c", ccon)
	mp.set_shader_parameter("cur_o", _vp_origin)
	mp.set_shader_parameter("prev_c", _hold_ref_c)
	mp.set_shader_parameter("prev_o", _hold_ref_o)
	mp.set_shader_parameter("prev_k", (_hold_ref_z / z) if valid else 1.0)
	mp.set_shader_parameter("hyst", ChartSky.hyst if valid else 0.0)
	_cam_now = ChartSky.solid_cam()
	_cam_now_t = ChartSky.SOLID_T
	_kgu_now = kgu
	_sol_now = sol
	mp.set_shader_parameter("cam_on", sol and _sol_ref)
	mp.set_shader_parameter("cam_cur", _cam_now)
	mp.set_shader_parameter("cam_cur_t", _cam_now_t)
	mp.set_shader_parameter("cam_prev", _cam_ref)
	mp.set_shader_parameter("cam_prev_t", _cam_ref_t)
	mp.set_shader_parameter("kgu_cur", kgu)
	mp.set_shader_parameter("kgu_prev", _kgu_ref)
	_hold_b0 = b0
	mp.set_shader_parameter("aa_k", _aa_of(z * float(p.big_r) / ChartSky.K0))
	# One palette at every zoom, near twins merged in as the flicker guards come in by zoom
	# 0.7.
	var lo := int(g.get("held", 0))
	var hi := HELD_MERGED
	var fr := _aa_of(z * float(p.big_r) / ChartSky.K0)
	if diag & 8 or not g.get("one", true):
		lo = 0
		for i in LEVELS.size() - 1:
			if z >= LEVELS[i + 1] / LEVELS[0]:
				lo = i + 1
		hi = mini(lo + 1, LEVELS.size() - 1)
		fr = 0.0
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


## The part of the chart that can be seen: all of it on the chart, the screen's
## share of the title's square (which is bigger than the screen).
func _visible_rect() -> Rect2:
	# (drawn on past the picture, under the glass: `MapChart.sky_out`)
	if chart.sky_out.has_area():
		return chart.sky_out
	var full := Rect2(Vector2.ZERO, chart.size)
	if chart.clip_contents or not chart.is_inside_tree():
		return full
	var xf := chart.get_global_transform_with_canvas().affine_inverse()
	var vr := chart.get_viewport_rect()
	var a := xf * vr.position
	var b := xf * vr.end
	var seen := Rect2(a, Vector2.ZERO).expand(b)
	return full.intersection(seen) if full.intersects(seen) else full


# ------------------------------------------------------------------ the events

## SIMPLIFIED's animations in the old look, all pure functions of the clock.
func _feed_events(m: ShaderMaterial, g: Dictionary, t: float, phi: float, z: float) -> void:
	var p: Dictionary = g.p
	var big_r: float = p.big_r
	var calm := DisplaySettings.reduced_motion
	var zc := z * big_r / ChartSky.K0
	m.set_shader_parameter("flow_t", t * (0.5 if calm else 1.0))
	m.set_shader_parameter("wx", 0.0 if calm else _sm(2.4, 3.2, zc))
	# the knots, as SIMPLIFIED places them, in this chart's plane (bake px)
	var knots: Array = g.knots
	var kn := PackedVector4Array()
	for i in knots.size():
		var a := ChartSky._knot_amp(knots, i, t, calm)
		var xy: Vector2 = knots[i].xy
		kn.append(Vector4(xy.x * big_r, xy.y * big_r, float(knots[i].size) * big_r, a))
	m.set_shader_parameter("n_kn", knots.size())
	kn.resize(ChartSky.MAX_KN)
	m.set_shader_parameter("kn", kn)
	# what the last minutes' supernovae left, in this chart's plane (bake px)
	var rm: Array = ChartSky.remnants(g.sn_cand, t, calm)
	var rl: PackedVector4Array = rm[1]
	for i in int(rm[0]):
		rl[i] = Vector4(rl[i].x * big_r, rl[i].y * big_r, rl[i].z, rl[i].w)
	# (none on a ball, as PAINTED's: a ring round a supernova read as a mark on a ball's
	# smooth body, and an old ball makes few)
	if p.ball_on:
		rm[0] = 0
	m.set_shader_parameter("n_rem", int(rm[0]))
	m.set_shader_parameter("rem", rl)
	# a supernova now and then, among the disc's own stars, and its light echo
	var sv := ChartSky._supernova(g.sn_cand, t, calm)
	if sv.is_empty():
		m.set_shader_parameter("sn", Vector4.ZERO)
		m.set_shader_parameter("echo", Vector4.ZERO)
	else:
		var sp := ChartSky._to_view(sv.xy, phi) / ChartSky.K0 * big_r * z
		m.set_shader_parameter("sn", Vector4(sp.x, sp.y, float(sv.g), float(sv.age)))
		var e: Vector2 = sv.xy * big_r
		m.set_shader_parameter("echo", Vector4.ZERO if p.ball_on else Vector4(e.x, e.y, 0.004 * float(sv.age) * big_r, float(sv.echo)))
	# lightning in the emission and dark clouds, at a point of each lobe's own frame
	var lt := PackedVector4Array()
	lt.resize(32)
	if not calm:
		var na: PackedVector4Array = p.neb_a
		var owner: PackedInt32Array = p.neb_owner
		for i in int(p.neb_n):
			var kind := int(na[i].w + 0.5) & 7
			if kind == 0 or kind == 4:
				lt[i] = _flash(owner[i], i, t)
	m.set_shader_parameter("neb_lt", lt)
	# the pulsars' beat: one bright second in five
	var pv := PackedVector4Array()
	var pul: PackedVector2Array = g.pulsars
	var beat := 0.45 + 1.1 * pow(0.5 + 0.5 * cos(TAU * t / 5.0), 8.0)
	if calm:
		beat = 0.8
	for pp in pul:
		if pv.size() >= 4:
			break
		var sp := ChartSky._to_view(pp, phi) / ChartSky.K0 * big_r * z
		pv.append(Vector4(sp.x, sp.y, beat, 0.0))
	var npv := pv.size()
	pv.resize(4)
	m.set_shader_parameter("n_puls", npv)
	m.set_shader_parameter("puls", pv)


## SIMPLIFIED's lightning schedule: a flash in most ten-second slots, two or three pulses.
static func _flash(cloud: int, lobe: int, t: float) -> Vector4:
	var s := cloud * 13
	var n0 := floori(t / 10.0)
	for n in range(n0 - 1, n0 + 2):
		if LegacyHole.hash01(n, 101 + s) > 0.8:
			continue
		var tf := 10.0 * n + 8.0 * LegacyHole.hash01(n, 202 + s) - 4.0
		var tau := t - tf
		if tau < 0.0 or tau > 1.4:
			continue
		# one lobe of the cloud flashes
		if int(LegacyHole.hash01(n, 505 + s) * 3.0) % 3 != lobe % 3:
			continue
		var np := 2 + (1 if LegacyHole.hash01(n, 303 + s) > 0.5 else 0)
		var env := 0.0
		for j in np:
			var x := tau - 0.12 * j
			if x < 0.0:
				continue
			var amp := 1.0 if j == 0 else 0.5 + 0.4 * LegacyHole.hash01(n, 404 + s + j)
			env += amp * (x / 0.08 if x < 0.08 else exp(-(x - 0.08) / 0.083))
		return Vector4(env, (LegacyHole.hash01(n, 606 + s) - 0.5) * 0.9,
			(LegacyHole.hash01(n, 707 + s) - 0.5) * 0.9, 0.3)
	return Vector4.ZERO


## The palette to draw a zoom level with: its own, or the nearest made so far.
func _palette_for(li: int) -> int:
	var pals: Dictionary = _baked[_key].pals
	if pals.has(li):
		return li
	if li == HELD_MERGED:
		return _palette_for(int(_baked[_key].get("held", 0)))
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
	# Built at first draw, once layout has the real size: `_process` built it at the pre-
	# layout size twice.
	chart._ensure_gpu()
	if not ready_to_draw() or _palette_for(level_of(_z())) < 0:
		draw_rect(Rect2(Vector2.ZERO, chart.size), Color8(7, 10, 18), true)
	else:
		draw_texture_rect(_vp.get_texture(), Rect2(_vp_origin, Vector2(_vp.size) * 2.0), false)
	if StarchartScreen.MapChart.prof:
		StarchartScreen.MapChart.prof_add("sky", Time.get_ticks_usec() - t0)
