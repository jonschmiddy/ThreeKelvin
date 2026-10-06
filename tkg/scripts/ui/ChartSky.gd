class_name ChartSky
extends Node2D

## THE STAR CHART'S SKY IN THE SIMPLIFIED STYLE: direction C, "Alive", from the
## Oct 5 showcase (scratchpad `showcase/C/chart/`), THE DEFAULT of the rendering
## styles (`DisplaySettings.render_style`). PAINTED draws with `ChartPainted`'s
## passes on this node; LEGACY with a node of its own, `ChartLegacy`, which this
## one hands the chart to and draws nothing. The
## chart's own layered look refined and set in slow motion: an arm-model disc
## and a cored bulge as gathered light, crisp dust lanes, sparse stars, four
## depth sheets you wade through as you zoom, gas streaming along the arms,
## knots that breathe and bloom, a rare supernova and its light echo, nebulae
## in the arms with weather of their own, and C's black hole at the core
## (`LegacyHole`). Everything a MapChart draws behind its systems is drawn here;
## the systems, routes, rings, labels and the ship stay the chart's own marks.
##
## TWO HALVES.
##   * ONCE A GALAXY (`_begin_bake` and the stages after it, on a node of its
##     own so a bake finishes even if the chart that asked closes): two bakes on
##     the GPU, read back and mip-mapped -- generic noise fields and this
##     galaxy's arm structure, face-on (`chart_c_bake`); the chart's own star
##     field cut down to the stars bright enough to be seen one at a time, as
##     data textures; the knots on the arms; then THE PALETTE, cut once for the
##     galaxy and never swapped while you move: the place pass rendered at the
##     hero views unquantised, read back, and a k-means in OKLab on another
##     thread anchored by fixed ramps for the key hues, the hole's bands and the
##     event colours; and its lookup, on the GPU (`chart_c_lut`).
##   * EVERY FRAME, three viewports at half the chart's size, so each of their
##     pixels is one 2x2 block: the stars splatted into a light buffer
##     (`chart_c_stars`), the place pass (`chart_c_place`, every block worked out
##     afresh, so a zoom redraws and nothing is stretched), and the composite
##     (`chart_c_comp`: toned, then the palette, dithered only on gradients).
##     The blocks are anchored to the galaxy's centre on a whole pixel, so a pan
##     moves the picture in whole blocks and the dither moves with it.
##
## Every animated thing is a pure function of the chart's clock
## (`MapChart.clock`): the turn, the currents, the knots' breathing, the
## supernovae, the weather, the hole's spin. Reduced motion turns the events off
## and halves the drift.
##
## THE TURN. The galaxy turns as one, once every `TURN_MINUTES`, a view-only
## angle (`MapChart.turn`): systems, routes and rings turn with it.

const TILT := 0.38
## One turn of the whole galaxy, in minutes: twelve hours, so at a glance it
## does not seem to move at all.
const TURN_MINUTES := 720.0
const OMEGA := TAU / (TURN_MINUTES * 60.0)
## The hole's size against the galaxy's own (`hole`), the same at every zoom,
## held under a fifth of the bulge.
const HOLE_K := 2.0
## How far out the hole's disc reaches, in shadow radii (`legacy_hole`'s LH_OUT).
const DISC_K := 3.0
## The showcase's units: view px a galaxy unit at zoom 1. The place pass works
## in them and is handed an effective zoom, so a chart of any size (the title
## screen's is a square as wide as the screen's diagonal) draws the same picture
## at the same scale on screen.
const K0 := 622.25
## The bakes cover -EXT..EXT galaxy units.
const EXT := 1.2
const NOISE_N := 1024
const STRUCT_N := 2048
const EXPOSURE := 1.2
const BURN := 2.5
## Mip bias for the bakes: above 0 keeps block-scale aliasing (zoom shimmer) out.
const LODB := 0.5
const MAX_CL := 12
const MAX_KN := 64
const MAX_EXTRA := 128
## The palette's probes: the showcase's 655 x 435 frame, in blocks.
const PROBE := Vector2i(328, 218)
const PROBE_RES := Vector2(655.0, 435.0)

const BAKE_SH := preload("res://shaders/chart_c_bake.gdshader")
const PLACE_SH := preload("res://shaders/chart_c_place.gdshader")
const PLACE_LOW_SH := preload("res://shaders/chart_c_place_low.gdshader")
const STARS_SH := preload("res://shaders/chart_c_stars.gdshader")
const COMP_SH := preload("res://shaders/chart_c_comp.gdshader")
const LUT_SH := preload("res://shaders/chart_c_lut.gdshader")

## Each galaxy's bake, by key: its textures, its constants, its palette. A run
## is one galaxy, so a new one drops the rest (`MapChart._build_stars`).
static var _baked: Dictionary = {}
## The one node that runs bakes, under the scene's root.
static var _baker: ChartSky = null
## A galaxy whose bakes are in but whose palette is still being cut: drawable,
## unquantised, so a new galaxy (the title's, on a first launch) shows its sky a
## few hundred milliseconds sooner instead of the void. Moved to `_baked` whole
## once the palette's lookup is in.
static var _early: Dictionary = {}
## THE PALETTE'S SIZE, which is much of the zoom's flicker: two near colours
## dithered or swapped at a block are a flip each time the zoom moves the
## gradient past them. The fixed ramps are kept whole (only exact twins go);
## `pal_merge` is how near (OKLab) a colour the cut finds may sit to one already
## kept before it is dropped, `pal_free` how many the cut adds. Measured on the
## grand-design's slow zooms (flip_back_mean, budget 0.0035): the showcase's
## 0.03 / 12 with its dither gating gave core 0.0051, hole 0.0069; 0.06 / 10
## with the stricter gating below, 0.0030 / 0.0035.
## Tuning: `-- sheet=ChartLook palmerge=M palfree=N`.
static var pal_merge := 0.03
static var pal_free := 12
## The composite's dither, 1 as made, 0 nearest colour only (tuning).
static var dith := 1.0
## The palette pass on (false shows the place before it; tuning).
static var quant := true
static var dith_gs := 0.006
static var dith_coh := 0.5

var chart: StarchartScreen.MapChart = null
## THE LEGACY STYLE draws with a renderer of its own (`ChartLegacy`, the chart as
## it was before the port): this node hands it the chart and draws nothing.
var _legacy: ChartLegacy = null

## Seconds between frames of the sky's own motion. 0 is every frame. See
## `MapChart.set_anim_interval`.
var interval := 0.0
var _since := 0.0

var _key := ""
var _job: Dictionary = {}
## Whether the run's systems belong to this galaxy (the title screen's do not).
var _use_map := true
var _bake_due := false
## The baker's copy of the chart's star field.
var _src: Dictionary = {}

## Runtime: the composite's viewport (what is drawn), the place pass's inside
## it and the stars' inside that, so each is rendered before the one reading it.
var _vp: SubViewport = null
var _pvp: SubViewport = null
var _svp: SubViewport = null
var _place: ColorRect = null
var _comp: ColorRect = null
var _stars: MeshDraw = null
var _m_place: ShaderMaterial = null
var _m_comp: ShaderMaterial = null
var _m_stars: ShaderMaterial = null
var _low_now := false
## The painted style's extra pass, its band memory (`ChartPainted`).
var _tvp: SubViewport = null
var _state: ColorRect = null
var _m_state: ShaderMaterial = null
## Whether the composite has the palette yet (see `_early`).
var _lut_on := false
var _vp_origin := Vector2.ZERO
## THE ZOOM'S HOLD (the showcase's fix for zoom shimmer). The blocks are anchored
## to the galaxy's centre on a whole pixel, and during a zoom off the centre that
## whole pixel re-rounds every frame, jittering the picture by up to half a block
## (measured: 0.116 of pixels flipping back on a slow zoom at a nebula). So while
## the zoom changes, and for about a second after (an eased wheel zoom has gaps),
## the place is sampled at the exact centre and the dither holds still on the
## screen; then it settles onto the snapped grid over two frames.
var _last_zoom := -1.0
var _since_zoom := 999
var _hold_d := Vector2.ZERO
var _hold_c := Vector2.ZERO
## RADIANT's safety: the sky's own GPU time over its first frames (`_radiant_safety`).
var _radiant_probe: Dictionary = {}
## The colour held (`chart_c_comp`'s `hyst`): where the blocks were anchored last frame.
var _hold_b0 := Vector2(INF, INF)
var _hold_z := -1.0
## the view's pan last frame: the zoom hold lets go when it moves
var _last_pan := Vector2(INF, INF)
## How near (sRGB, 0-1) a block's light may stay to its last colour and keep it.
static var hyst := 0.035


## A mesh drawn as one item, its quads placed by its shader.
class MeshDraw extends Node2D:
	var mesh: ArrayMesh = null

	func _draw() -> void:
		if mesh != null:
			draw_mesh(mesh, null)


static func galaxy_key() -> String:
	return "%d|%d|%.3f|%.4f" % [Run.galaxy_kind, Run.galaxy_seed, float(Run.galaxy.get("squash", 0.62)), Run.galaxy_spin]


## How flat the galaxy's light is drawn: EVERY GALAXY lies in the sector map's
## own plane, TILT ("increase the angle of the starchart to match the sector",
## Jon), the ball-shaped ones too.
static func eff_of(_g: Dictionary) -> float:
	return TILT


## Everything baked for a galaxy that is not the current one goes.
static func drop_others() -> void:
	ChartLegacy.drop_others()
	var keep := galaxy_key()
	for k in _baked.keys():
		if not (k as String).begins_with(keep):
			_baked.erase(k)
	for k in _early.keys():
		if not (k as String).begins_with(keep):
			_early.erase(k)


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _ready() -> void:
	if not Sig.render_style_changed.is_connected(_on_style):
		Sig.render_style_changed.connect(_on_style)
	if not _warmed and DisplayServer.get_name() != "headless":
		_warmed = true
		_warm.call_deferred(get_tree().root)


## THE SHADERS COMPILED ON THE FIRST FRAME, which the boot splash still covers.
## A fresh profile has no shader cache, and the place pass takes a second or
## more to compile (1.7 s on an RTX 3070, measured with the cache bypassed;
## 6.1 s before its layers were each inlined once), so the title's galaxy --
## the first thing a player sees -- was a black screen for that long. Drawn
## here once, off screen, in the formats the bake and the frame use, from the
## first ChartSky made (the title's), and thrown away.
static var _warmed := false

static func _warm(root: Node) -> void:
	var holder := Node.new()
	holder.name = "ChartSkyWarm"
	root.add_child(holder)
	var shaders: Array = [[PLACE_LOW_SH if DisplaySettings.graphics_low else PLACE_SH, true],
		[STARS_SH, true], [COMP_SH, false], [BAKE_SH, false], [LUT_SH, false]]
	if ChartRadiant.wanted():
		# the radiant chart's own place pass and bakes beside SIMPLIFIED's stars,
		# composite and lookup (it shares them)
		shaders = [[ChartRadiant.PLACE_LOW_SH if DisplaySettings.graphics_low else ChartRadiant.PLACE_SH, true],
			[STARS_SH, true], [COMP_SH, false], [LUT_SH, false], [ChartRadiant.DISC_SH, true],
			[ChartRadiant.HOR_SH, true], [ChartRadiant.NOISE_SH, true]]
	elif ChartLegacy.wanted():
		# the legacy chart's own passes instead: its field and stars, its hole and
		# palette in 8-bit, its bake in HDR
		shaders = [[ChartLegacy.FIELD_SH, false], [ChartLegacy.STARS_SH, false],
			[ChartLegacy.HOLE_SH, false], [ChartLegacy.PAL_SH, false], [ChartLegacy.LUT_SH, false],
			[ChartLegacy.SPLAT_SH, true], [ChartLegacy.BLUR_SH, true], [ChartLegacy.BASE_SH, true]]
	elif ChartPainted.wanted():
		# the painted chart's own passes instead, in its formats (its G-buffer is 8-bit)
		shaders = [[ChartPainted.PLACE_LOW_SH if DisplaySettings.graphics_low else ChartPainted.PLACE_SH, false],
			[ChartPainted.STARS_SH, false], [ChartPainted.STATE_SH, false], [ChartPainted.PAINT_SH, false],
			[ChartPainted.BAKE_SH, true]]
	for e: Array in shaders:
		var vp := SubViewport.new()
		vp.size = Vector2i(4, 4)
		vp.use_hdr_2d = bool(e[1])
		vp.disable_3d = true
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		holder.add_child(vp)
		var m := ShaderMaterial.new()
		m.shader = e[0]
		var r := _rect(m)
		r.size = Vector2(4, 4)
		vp.add_child(r)
	# gone once it has been drawn
	root.get_tree().create_timer(1.0).timeout.connect(holder.queue_free)


func _exit_tree() -> void:
	if _job.has("task"):
		WorkerThreadPool.wait_for_task_completion(int(_job.task))


## Another rendering style was chosen: the picture is made again, by the
## style's own renderer (`setup`, at the next draw).
func _on_style() -> void:
	if _vp != null:
		_vp.queue_free()
		_vp = null
	# keyed afresh at the next draw: each style keeps a bake of its own
	_key = ""
	queue_redraw()


## Whether this galaxy is baked, palette and all.
func ready_baked() -> bool:
	if _legacy != null:
		return _legacy.ready_baked()
	return bool((_baked.get(_key, {}) as Dictionary).get("ready", false))


## Whether the galaxy is drawn as it is meant to be, palette and all (what a
## harness waits for).
func ready_to_draw() -> bool:
	if _legacy != null:
		return _legacy.ready_to_draw() and _legacy._palette_for(ChartLegacy.level_of(_legacy._z())) >= 0
	return ready_baked() and _vp != null and _lut_on


## The galaxy's bake: complete, or early (bakes in, palette to come), or empty.
func _g_for() -> Dictionary:
	if _baked.has(_key):
		return _baked[_key]
	return _early.get(_key, {})


# ------------------------------------------------------------------ setup

## Hand the chart over; bake its galaxy if nobody has.
func setup(c: StarchartScreen.MapChart) -> void:
	chart = c
	if ChartLegacy.wanted():
		if _vp != null:
			_vp.queue_free()
			_vp = null
		_key = ""
		if _legacy == null:
			_legacy = ChartLegacy.new()
			_legacy.name = "Legacy"
			add_child(_legacy)
		_legacy.interval = interval
		_legacy.setup(c)
		return
	if _legacy != null:
		_legacy.queue_free()
		_legacy = null
	_use_map = c.run_galaxy
	# the style is part of the key: a simplified bake and a painted one differ
	var key := galaxy_key() + ("|map" if _use_map else "") + ("|painted" if ChartPainted.wanted() else "") 		+ ("|radiant" if ChartRadiant.wanted() and not ChartPainted.wanted() else "")
	if key != _key:
		_key = key
		if _vp != null:
			_vp.queue_free()
			_vp = null
		if not _baked.has(key) and not _bake_due:
			_bake_due = true
			_request_bake.call_deferred()


## Hand this galaxy to the baker, unless it is already on it.
func _request_bake() -> void:
	_bake_due = false
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
	_baker._use_map = _use_map
	_baker._src = _snapshot_stars(chart)
	_baker._begin_bake()


## What the bake reads from the chart, copied: the chart may close mid-bake.
static func _snapshot_stars(c: StarchartScreen.MapChart) -> Dictionary:
	return {
		"r_max": c._radius() * StarchartScreen.MapChart.DISC,
		"pos": c._star_pos.duplicate(), "col": c._star_col.duplicate(), "big": c._star_big.duplicate(),
		"cr": c._core_rad.duplicate(), "ca": c._core_ang.duplicate(), "cc": c._core_col.duplicate(),
		"gc": c._glob_c.duplicate(), "gi": c._glob_i.duplicate(), "pulsar": c._pulsar.duplicate(),
	}


# ------------------------------------------------------------------ the galaxy's constants

## The kind's shape: 0 a spiral disc, 1 a ball (the ellipticals, the dwarfs,
## the merger), 2 an armless disc (the lenticulars). Read off the kind's own
## archetype, so a rolled squash cannot tip a lenticular into a ball.
static func form_of(kind: int) -> int:
	var base := GalaxyGen.params(kind)
	if int(base.arms) > 0:
		return 0
	return 2 if float(base.squash) < 0.4 else 1


## A ball's size, roundness on screen, centre light and look (0 old, 1 a blue
## compact dwarf, 2 a faint thin dwarf, 3 a merger's remnant with shells).
static func ball_of(kind: int, g: Dictionary) -> Vector4:
	var b := Vector4(0.30, 0.74, 0.085, 0.0)
	match GalaxyGen.type_name(kind):
		"Flattened Elliptical":
			b = Vector4(0.28, 0.55, 0.085, 0.0)
		"Giant Elliptical":
			b = Vector4(0.40, 0.70, 0.10, 0.0)
		"Merger Remnant":
			b = Vector4(0.30, 0.68, 0.085, 3.0)
		"Blue Compact Dwarf":
			b = Vector4(0.16, 0.80, 0.07, 1.0)
		"Dwarf Spheroidal":
			b = Vector4(0.34, 0.82, 0.022, 2.0)
	var base_bulge := float(GalaxyGen.params(kind).bulge)
	b.x *= clampf(float(g.get("bulge", base_bulge)) / maxf(base_bulge, 0.01), 0.8, 1.25)
	return b


## The rolled galaxy as the place pass's constants.
static func params(_use_map: bool = true) -> Dictionary:
	var g: Dictionary = Run.galaxy
	var kind := Run.galaxy_kind
	var form := form_of(kind)
	var arms := int(g.get("arms", 2)) if form == 0 else 0
	var gas := float(g.get("gas", 1.0))
	var bulge := float(g.get("bulge", 0.3))
	var shadow := float(g.get("hole", 0.03)) / StarchartScreen.MapChart.DISC
	var bulge_r := bulge / StarchartScreen.MapChart.DISC
	var hole_r := shadow * clampf(0.2 * bulge_r / maxf(shadow, 1e-4), 1.0, HOLE_K)
	return {
		"kind": kind, "form": form, "arms": arms, "gas": gas,
		"twist": float(g.get("twist", 8.0)), "bar": minf(float(g.get("bar", 0.0)), 0.9),
		"spread": float(g.get("spread", 1.0)), "chaos": float(g.get("chaos", 0.0)),
		"spin": Run.galaxy_spin, "squash": float(g.get("squash", 0.62)),
		"bulge_r": bulge_r, "hole_r": hole_r,
		"lane": minf(1.1, gas) * 0.95 if (arms > 0 and gas >= 0.35) else 0.0,
		"young": clampf(gas, 0.15, 1.0),
		"tail": bool(g.get("tail", false)),
		"ball": ball_of(kind, g),
		"arm_gain": 1.1 if GalaxyGen.type_name(kind) == "Starburst Spiral" else 1.0,
	}


## THE HOLE's shadow radius on the screen now, in chart px (0 before the sky is
## made): the chart keeps its marks out of it.
func hole_px() -> float:
	if _legacy != null:
		return _legacy.hole_px()
	if chart == null or _g_for().is_empty():
		return 0.0
	return float(_g_for().p.hole_r) * _k() * chart.zoom


## Chart px a galaxy unit at zoom 1: the chart's own projection.
func _k() -> float:
	return chart._radius() * StarchartScreen.MapChart.DISC


# ------------------------------------------------------------------ the bake

func _pass_vp(holder: Node, size: Vector2i, item: CanvasItem, hdr: bool) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = true
	vp.use_hdr_2d = hdr
	vp.disable_3d = true
	vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	holder.add_child(vp)
	if item is Control:
		(item as Control).size = Vector2(size)
	vp.add_child(item)
	return vp


static func _rect(mat: ShaderMaterial) -> ColorRect:
	var r := ColorRect.new()
	r.material = mat
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Stage one: the CPU's share (stars, knots, clouds) and the two bakes queued.
func _begin_bake() -> void:
	var p := params(_use_map)
	var holder := Node.new()
	holder.name = "Bake"
	add_child(holder)
	if _key.ends_with("|painted"):
		# the painted style: its puff table and its stars; its palette is curated
		var gb := {"p": p, "ready": false, "times": {}, "painted": true}
		var bvps := ChartPainted.begin_bake(self, gb, holder)
		_job = {"stage": 10, "frame": Engine.get_frames_drawn(), "holder": holder, "g": gb, "bakes": bvps,
			"key": _key, "t0": Time.get_ticks_msec()}
		return
	var g := {"p": p, "ready": false, "times": {}}
	var c0 := Time.get_ticks_usec()
	_build_star_data(g, p)
	g["knots"] = _make_knots(p)
	g["clouds"] = _make_clouds(p, g)
	_add_knot_stars(g)
	g.times["cpu"] = (Time.get_ticks_usec() - c0) / 1000
	if _key.ends_with("|radiant"):
		# the radiant style: SIMPLIFIED's stars, knots and clouds, its own bakes
		g["radiant"] = true
		_job = {"stage": 20, "frame": Engine.get_frames_drawn(), "holder": holder, "g": g,
			"bakes": ChartRadiant.begin_bake(self, g, holder), "key": _key, "t0": Time.get_ticks_msec()}
		return
	var vps: Array[SubViewport] = []
	for mode in 2:
		var n := NOISE_N if mode == 0 else (STRUCT_N if (int(p.arms) > 0 or float(p.bar) > 0.0) else 16)
		var m := ShaderMaterial.new()
		m.shader = BAKE_SH
		m.set_shader_parameter("mode", mode)
		m.set_shader_parameter("ext", EXT)
		m.set_shader_parameter("arms", float(p.arms))
		m.set_shader_parameter("twist", float(p.twist))
		m.set_shader_parameter("bar", float(p.bar))
		m.set_shader_parameter("spin", float(p.spin))
		m.set_shader_parameter("spread", float(p.spread))
		m.set_shader_parameter("chaos", float(p.chaos))
		vps.append(_pass_vp(holder, Vector2i(n, n), _rect(m), false))
	_job = {"stage": 1, "frame": Engine.get_frames_drawn(), "holder": holder, "g": g, "bakes": vps, "key": _key,
		"t0": Time.get_ticks_msec()}


func _drop_job() -> void:
	if _job.has("key"):
		_early.erase(_job.key)
	if _job.has("task"):
		WorkerThreadPool.wait_for_task_completion(int(_job.task))
	if _job.has("holder") and is_instance_valid(_job.holder):
		(_job.holder as Node).queue_free()
	_job = {}


func _process(delta: float) -> void:
	if not _job.is_empty() and Engine.get_frames_drawn() > int(_job.frame):
		_advance()
	if chart == null or _legacy != null:
		return
	if _vp == null and not _g_for().is_empty():
		_runtime()
	if _vp == null:
		# the baker went on to another galaxy first: ask again
		if _key != "" and _g_for().is_empty() and not _bake_due \
				and (_baker == null or not is_instance_valid(_baker) or _baker._key != _key):
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
	match int(_job.stage):
		1:
			_stage_bakes()
		2:
			_stage_probes()
		3:
			_stage_palette()
		4:
			_stage_lut()
		20:
			var hv := ChartRadiant.mid_bake(self, _job.g, _job.bakes, _job.holder)
			if hv == null:
				_drop_job()
				return
			_job.bakes = [hv]
			_job.stage = 21
			_job.frame = Engine.get_frames_drawn()
		21:
			if not ChartRadiant.end_bake(_job.g, _job.bakes[0]):
				_drop_job()
				return
			_early[_key] = _job.g
			_queue_probes(_job.g)
		10:
			var gb: Dictionary = _job.g
			if not ChartPainted.finish_bake(gb, _job.bakes):
				_drop_job()
				return
			gb["bake_ms"] = Time.get_ticks_msec() - int(_job.t0)
			_baked[_key] = gb
			var holder: Node = _job.holder
			_job = {}
			holder.queue_free()


## Stage two: the bakes read back and mip-mapped; the palette's probes queued.
func _stage_bakes() -> void:
	var c0 := Time.get_ticks_usec()
	var g: Dictionary = _job.g
	var vps: Array = _job.bakes
	var imgs: Array[Image] = []
	for vp: SubViewport in vps:
		var img := vp.get_texture().get_image()
		if img == null:
			# a renderer that gives nothing back ends the bake
			_drop_job()
			return
		img.convert(Image.FORMAT_RGBA8)
		img.generate_mipmaps()
		imgs.append(img)
	g["noise"] = ImageTexture.create_from_image(imgs[0])
	g["struct"] = ImageTexture.create_from_image(imgs[1])
	for vp: SubViewport in vps:
		vp.queue_free()
	g.times["readback"] = (Time.get_ticks_usec() - c0) / 1000
	_early[_key] = g
	_queue_probes(g)


## The palette's probes: the place pass at the hero views, unquantised.
func _queue_probes(g: Dictionary) -> void:
	var radiant := g.has("radiant")
	var probes: Array[SubViewport] = []
	for view: Vector3 in _probe_views(g):
		var m := ShaderMaterial.new()
		if radiant:
			m.shader = ChartRadiant.PLACE_LOW_SH if DisplaySettings.graphics_low else ChartRadiant.PLACE_SH
			ChartRadiant.feed_static(m, g)
		else:
			m.shader = PLACE_LOW_SH if DisplaySettings.graphics_low else PLACE_SH
			_feed_static(m, g)
		var z := view.x
		var cp := PROBE_RES * 0.5 - Vector2(view.y, view.z) * z
		cp = cp.floor()
		_feed_view(m, g, Vector2(PROBE), Vector2(posmod(int(cp.x), 2) - 2, posmod(int(cp.y), 2) - 2),
			cp, PROBE_RES, z, 600.0, OMEGA * 600.0)
		_feed_events(m, g, 600.0, OMEGA * 600.0, z, false)
		if radiant:
			ChartRadiant.feed_events(m, g, 600.0, false, false)
		m.set_shader_parameter("u_stars_on", false)
		m.set_shader_parameter("u_tone_out", true)
		probes.append(_pass_vp(_job.holder, PROBE, _rect(m), false))
	_job.probes = probes
	_job.stage = 2
	_job.frame = Engine.get_frames_drawn()


## The hero views a palette is cut from (zoom, pan x, pan y in view px at the
## probe's turn): the opening, the core twice, a nebula twice, the hole, and
## YOU close and far; the nebula pair if there is one.
func _probe_views(g: Dictionary) -> Array[Vector3]:
	var phi := OMEGA * 600.0
	var out: Array[Vector3] = [Vector3(0.42, 0, 0), Vector3(1.5, 0, 0), Vector3(1.5, 0, 0), Vector3(6.0, 0, 0)]
	var clouds: Array = g.clouds
	var best := -1
	var best_s := INF
	for i in clouds.size():
		var c: Dictionary = clouds[i]
		if int(c.kind) == 4:
			continue
		var s: float = (c.xy as Vector2).length() - (1.0 if int(c.kind) == 0 else 0.0)
		if s < best_s:
			best_s = s
			best = i
	if best >= 0:
		var v := _to_view(clouds[best].xy, phi)
		out.append(Vector3(4.0, v.x, v.y))
		out.append(Vector3(4.0, v.x, v.y))
		# and the next cloud along, if it is a different kind
		for i in clouds.size():
			if i != best and int(clouds[i].kind) != int(clouds[best].kind) and int(clouds[i].kind) != 4:
				var v2 := _to_view(clouds[i].xy, phi)
				out.append(Vector3(4.0, v2.x, v2.y))
				break
	if _use_map and not Run.map.is_empty() and Run.node_at() != null:
		var n: MapGen.MapNode = Run.node_at()
		var y := _to_view(Vector2(n.gal.x, n.gal.y / float(g.p.squash)), phi)
		out.append(Vector3(1.5, y.x, y.y))
		out.append(Vector3(4.0, y.x, y.y))
	return out


static func _to_view(p: Vector2, phi: float) -> Vector2:
	var c := cos(phi)
	var s := sin(phi)
	return Vector2(p.x * c + p.y * s, (p.y * c - p.x * s) * TILT) * K0


## Stage three: the probes read back; the palette cut on another thread.
func _stage_probes() -> void:
	var samples := PackedByteArray()
	for vp: SubViewport in _job.probes:
		var img := vp.get_texture().get_image()
		if img == null:
			_drop_job()
			return
		img.convert(Image.FORMAT_RGB8)
		var d := img.get_data()
		# every 61st pixel: enough for the cut, little enough for GDScript
		var i := 0
		while i + 2 < d.size():
			samples.append(d[i])
			samples.append(d[i + 1])
			samples.append(d[i + 2])
			i += 3 * 61
		vp.queue_free()
	_job.probes = []
	var job := PaletteJob.new()
	job.samples = samples
	var emits := false
	for c: Dictionary in (_job.g as Dictionary).clouds:
		emits = emits or int(c.kind) == 0
	job.fixed = _fixed_palette(int((_job.g as Dictionary).p.form), emits)
	job.free_n = pal_free
	job.merge = pal_merge
	if (_job.g as Dictionary).has("radiant"):
		# the radiant sky is light through gas: long soft ramps, many of them dim
		# (the showcase's A: its own key hues reserved, a dark ramp read off the
		# scene, the rest cut evenly; the hold keeps it from flickering)
		job.fixed = ChartRadiant.fixed_palette()
		job.free_n = ChartRadiant.PAL_FREE
		job.merge = ChartRadiant.PAL_MERGE
		job.even = true
	if int((_job.g as Dictionary).p.form) != 0 and not (_job.g as Dictionary).has("radiant"):
		# a ball (and an armless disc) is one long smooth gradient with little texture to shimmer (its
		# zoom flicker measured 0.0009): it gets more of the cut's own colours,
		# closer together, or its pale tans fell to the nearest saturated amber
		# and drew a hard disc in the dwarf's middle
		job.free_n = pal_free + 6
		job.merge = pal_merge * 0.6
	_job.pjob = job
	_job.task = WorkerThreadPool.add_task(job.run, false, "simplified chart palette")
	_job.stage = 3
	_job.frame = Engine.get_frames_drawn()


## Stage four: the palette in, its lookup made on the GPU.
func _stage_palette() -> void:
	if not WorkerThreadPool.is_task_completed(int(_job.task)):
		return
	WorkerThreadPool.wait_for_task_completion(int(_job.task))
	_job.erase("task")
	var cols: PackedColorArray = (_job.pjob as PaletteJob).out
	var g: Dictionary = _job.g
	var img := Image.create(128, 1, false, Image.FORMAT_RGBA8)
	for i in mini(128, cols.size()):
		img.set_pixel(i, 0, cols[i])
	g["pal"] = ImageTexture.create_from_image(img)
	g["pal_cols"] = cols
	g.times["kmeans"] = (_job.pjob as PaletteJob).ms
	var m := ShaderMaterial.new()
	m.shader = LUT_SH
	m.set_shader_parameter("pal", g.pal)
	m.set_shader_parameter("n", mini(128, cols.size()))
	m.set_shader_parameter("near", 0.11)
	# a ball's faint outskirts are a slow gradient, not flat dark: let them dither
	# a little deeper, or they end in rings
	m.set_shader_parameter("dark", 0.13 if (int(g.p.form) != 0 or g.has("radiant")) else 0.20)
	if g.has("radiant"):
		# the hole's bands, kept for the hole (`ChartRadiant.fixed_palette`: after the four navies)
		m.set_shader_parameter("exact_lo", 4)
		m.set_shader_parameter("exact_hi", 11)
		m.set_shader_parameter("lchr", 2.5)
		m.set_shader_parameter("near", 0.10)
	_job.lut = _pass_vp(_job.holder, Vector2i(1024, 32), _rect(m), false)
	_job.stage = 4
	_job.frame = Engine.get_frames_drawn()


## Stage five: the lookup read back; the galaxy is ready.
func _stage_lut() -> void:
	var img := (_job.lut as SubViewport).get_texture().get_image()
	if img == null:
		_drop_job()
		return
	var g: Dictionary = _job.g
	g["lut"] = ImageTexture.create_from_image(img)
	g["ready"] = true
	g["bake_ms"] = Time.get_ticks_msec() - int(_job.t0)
	_baked[_key] = g
	_early.erase(_key)
	var holder: Node = _job.holder
	_job = {}
	holder.queue_free()


# ------------------------------------------------------------------ the stars as data

## The chart's star field cut down to what the simplified sky draws as stars: every
## point bright enough to be seen alone at some zoom (luminance 60 and up of
## 255), the core's points, the globulars as knots, and the knots' young stars.
## As three float textures (`chart_c_stars`).
func _build_star_data(g: Dictionary, p: Dictionary) -> void:
	var r_max: float = _src.r_max
	var sq: float = p.squash
	var a := PackedFloat32Array()
	var b := PackedFloat32Array()
	var c := PackedFloat32Array()
	var pos: PackedVector2Array = _src.pos
	var col: PackedColorArray = _src.col
	var big: PackedByteArray = _src.big
	var gi: PackedInt32Array = _src.gi
	var glob_of := PackedInt32Array()
	glob_of.resize(pos.size())
	glob_of.fill(-1)
	for k in gi.size() / 2:
		for j in range(gi[k * 2], mini(gi[k * 2 + 1], pos.size())):
			glob_of[j] = k
	var cand := PackedVector2Array()
	var n := 0
	for i in pos.size():
		if big[i] == 2:
			continue
		var cc := col[i]
		var val := maxf(cc.r, maxf(cc.g, cc.b))
		if big[i] == 0 and val < 0.075:
			continue
		var lum := (0.3 * cc.r + 0.59 * cc.g + 0.11 * cc.b) * 255.0
		if lum < 60.0:
			continue
		var pl := Vector2(pos[i].x / r_max, pos[i].y / r_max / sq)
		var lin := cc.srgb_to_linear()
		var kind := 2 if glob_of[i] >= 0 else 0
		a.append_array([pl.x, pl.y, lum, float(kind)])
		b.append_array([lin.r, lin.g, lin.b, LegacyHole.hash01(n, 7)])
		c.append_array([0.0, 0.0, 0.0, 0.0])
		if kind == 0 and pl.length() > 0.16 and pl.length() < 0.9:
			cand.append(pl)
		n += 1
	var cr: PackedFloat32Array = _src.cr
	var ca: PackedFloat32Array = _src.ca
	var ccol: PackedColorArray = _src.cc
	for i in cr.size():
		var cc := ccol[i]
		var lum := (0.3 * cc.r + 0.59 * cc.g + 0.11 * cc.b) * 255.0
		if lum < 60.0:
			continue
		var pl := Vector2(cos(ca[i]) * cr[i], sin(ca[i]) * cr[i] / sq) / r_max
		var lin := cc.srgb_to_linear()
		a.append_array([pl.x, pl.y, lum, 1.0])
		b.append_array([lin.r, lin.g, lin.b, LegacyHole.hash01(n, 7)])
		c.append_array([LegacyHole.hash01(i, 404), LegacyHole.hash01(i, 405), 0.0, 0.0])
		n += 1
	# the globulars, each a tight knot below zoom 2: its middle and four members
	var gcs: PackedVector2Array = _src.gc
	for k in gcs.size():
		var gp := Vector2(gcs[k].x / r_max, gcs[k].y / r_max / sq)
		var cnt := float(gi[k * 2 + 1] - gi[k * 2]) if k * 2 + 1 < gi.size() else 60.0
		for j in range(-1, 4):
			a.append_array([gp.x, gp.y, cnt, 4.0])
			b.append_array([LegacyHole.hash01(k * 17 + j, 31), LegacyHole.hash01(k * 17 + j, 32),
				LegacyHole.hash01(k * 17 + j, 33), float(j)])
			c.append_array([0.0, 0.0, 0.0, 0.0])
			n += 1
	g["sn_cand"] = cand
	g["n_data"] = n
	g["st_a"] = a
	g["st_b"] = b
	g["st_c"] = c


## The knots' young stars go in with the rest of the data once the knots are made.
func _add_knot_stars(g: Dictionary) -> void:
	var a: PackedFloat32Array = g.st_a
	var b: PackedFloat32Array = g.st_b
	var c: PackedFloat32Array = g.st_c
	var n: int = g.n_data
	var knots: Array = g.knots
	for i in knots.size():
		var kn: Dictionary = knots[i]
		for o: Vector3 in kn.st:
			a.append_array([kn.xy.x + o.x, kn.xy.y + o.y, float(i), 3.0])
			b.append_array([o.z, 0.0, 0.0, 0.0])
			c.append_array([0.0, 0.0, 0.0, 0.0])
			n += 1
	g["n_star"] = n
	g["tex_a"] = _data_tex(a, n)
	g["tex_b"] = _data_tex(b, n)
	g["tex_c"] = _data_tex(c, n)


static func _data_tex(f: PackedFloat32Array, n: int) -> ImageTexture:
	var w := StarchartScreen.MapChart.SKY_TEX_W
	var rows := maxi(1, ceili(float(n) / float(w)))
	f.resize(w * rows * 4)
	return ImageTexture.create_from_image(Image.create_from_data(w, rows, false, Image.FORMAT_RGBAF, f.to_byte_array()))


## THE KNOTS: pink gathered light on the arms' star-forming fronts, placed once a
## galaxy from its own seed, as many as its gas allows; each with a little
## cluster of hot young stars.
static func _make_knots(p: Dictionary) -> Array:
	var out: Array = []
	var arms: int = p.arms
	if arms <= 0:
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([Run.galaxy_seed, Run.galaxy_kind, 977])
	var want := clampi(roundi((64.0 if p.arm_gain > 1.0 else 56.0) * clampf(float(p.gas), 0.0, 1.15)), 0, MAX_KN)
	var bar: float = p.bar
	for i in want:
		var k := int(rng.randf() * float(arms)) % arms
		var r := 0.12 + 0.82 * pow(rng.randf(), 0.85)
		if r < bar * 1.2:
			r = bar * 1.2 + 0.05 * rng.randf()
		var w := 0.5 * (0.55 + 0.9 * r) * float(p.spread)
		var gs := 0.2 + (rng.randf() + rng.randf() - 1.0) * 0.35
		var ang := float(k) * TAU / float(arms) + float(p.spin) + maxf(r - bar, 0.0) / (1.0 - bar) * float(p.twist) + gs * w
		var size := 0.003 + 0.007 * rng.randf()
		var st: Array[Vector3] = []
		var ns := 3 + int(rng.randf() * 3.0)
		for j in ns:
			var aa := rng.randf() * TAU
			var rr := size * (0.4 + 1.3 * rng.randf())
			st.append(Vector3(cos(aa) * rr, sin(aa) * rr, 0.35 + 0.6 * rng.randf()))
		out.append({"xy": Vector2(r * cos(ang), r * sin(ang)), "size": size, "T": 20.0 + 40.0 * rng.randf(),
			"ph": rng.randf() * TAU, "st": st})
	return out


## The named clouds as the place pass draws them: kind numbered as the shader
## numbers them, the lobes biggest first in the cloud's own round frame, a seed,
## the emission cluster's stars, and the pulsar a remnant holds.
func _make_clouds(p: Dictionary, g: Dictionary) -> Array:
	var out: Array = []
	var sq: float = p.squash
	var r_max: float = _src.r_max
	var pulsars: PackedVector2Array = _src.pulsar
	var i := 0
	for raw in NebulaField.clouds():
		var cl: NebulaField.Cloud = raw
		var kind := 0
		match cl.kind:
			NebulaField.Kind.EMISSION:
				kind = 0
			NebulaField.Kind.REFLECTION:
				kind = 1
			NebulaField.Kind.REMNANT:
				kind = 2
			NebulaField.Kind.PLANETARY:
				kind = 3
			_:
				kind = 4
		var lobes: Array[Vector3] = []
		var reach := 0.0
		for l in cl.lobes.size():
			lobes.append(Vector3(cl.lobes[l].x, cl.lobes[l].y, cl.lobe_r[l]))
			reach = maxf(reach, (cl.lobes[l] as Vector2).length() + cl.lobe_r[l] * NebulaField.EXTENT)
		lobes.sort_custom(func(x: Vector3, y: Vector3) -> bool: return x.z > y.z)
		while lobes.size() < 3:
			lobes.append(lobes[0] if not lobes.is_empty() else Vector3(0, 0, cl.radius))
		var rng := RandomNumberGenerator.new()
		rng.seed = 1000 + i * 31
		var cluster: Array[Vector3] = []
		for j in 8:
			var aa := rng.randf() * TAU
			var rr := cl.radius * 0.10 * sqrt(rng.randf())
			cluster.append(Vector3(cos(aa) * rr, sin(aa) * rr, 0.5 + 0.8 * rng.randf()))
		var xy := Vector2(cl.pos.x, cl.pos.y / sq)
		var pulsar := Vector2(INF, INF)
		if kind == 2:
			for pp in pulsars:
				var pl := Vector2(pp.x / r_max, pp.y / r_max / sq)
				if pl.distance_to(xy) < reach:
					pulsar = pl
					break
		out.append({"name": cl.name, "kind": kind, "xy": xy, "radius": cl.radius, "reach": reach,
			"hollow": cl.hollow, "shape": float(int(cl.shape)), "seed": 1.3 + fmod(float(i) * 7.31, 10.0),
			"lobes": lobes, "cluster": cluster, "pulsar": pulsar, "i": i})
		i += 1
	return out


# ------------------------------------------------------------------ the palette

## The colours every simplified palette keeps whatever the cut finds: the void and
## the navy steps just above it, the hole's bands, the emission cavity's pale
## front, and ramps through the key hues -- the arms' blue, H-alpha, OIII, the
## bulge's amber and its dark end, the knots' pink, and the event colours
## (lightning, the supernova's flare) so events never mud.
static func _fixed_palette(form: int = 0, emits: bool = true) -> PackedColorArray:
	var out := PackedColorArray()
	for h in ["#070a12", "#0b1020", "#0e1327", "#0f1529", "#121830", "#141b33", "#171f3c"]:
		out.append(Color(h))
	for i in range(1, 8):
		out.append(LegacyHole.PALETTE[i])
	# the emission cavity's pale front, only where there is an emission cloud:
	# elsewhere the gold-lit billows round the bulge took the pale rose and drew
	# a lavender plate beside the hole
	if emits:
		for h in ["#e4aeb0", "#f3cfc6", "#cdeee4", "#a6e3d6"]:
			out.append(Color(h))
	var lt := _to_lch(Color("#d8d0ff"))
	var fl := _to_lch(Color("#ffe6b0"))
	var ramps: Array = [
		["#1c2650", 4, 0.17, 0.34, 0.0],
		["#4d78ff", 6, 0.38, 0.90, 0.0],
		["#ff4d6a", 7, 0.30, 0.88, 14.0],
		["#45e6d2", 7, 0.34, 0.93, 0.0],
		["#f6b06a", 5, 0.42, 0.94, 18.0],
		["#c87a1e", 3, 0.30, 0.60, 0.0],
		["#b8602a", 2, 0.24, 0.38, -10.0],
		["#ff4d9a", 2, 0.45, 0.70, 0.0],
		["#d8d0ff", 1, lt.x, lt.x, 0.0],
		["#ffe6b0", 2, fl.x - 0.22, fl.x, 0.0],
	]
	if form != 0:
		# a ball (or an armless disc) is one long warm gradient, gold heart to red outskirts: its own
		# steps, close enough to dither, down into the dim reds of its edge
		ramps.append(["#e09a60", 6, 0.30, 0.86, 16.0])
		ramps.append(["#a8483a", 3, 0.18, 0.34, -8.0])
	for r: Array in ramps:
		for c in _ramp(Color(r[0]), int(r[1]), float(r[2]), float(r[3]), float(r[4])):
			out.append(c)
	return out


static func _s2l(v: float) -> float:
	return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)


static func _l2s(v: float) -> float:
	v = maxf(0.0, v)
	return v * 12.92 if v <= 0.0031308 else 1.055 * pow(v, 1.0 / 2.4) - 0.055


static func _oklab(c: Color) -> Vector3:
	return _oklab_lin(_s2l(c.r), _s2l(c.g), _s2l(c.b))


static func _oklab_lin(r: float, g: float, b: float) -> Vector3:
	var l := 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
	var m := 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
	var s := 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
	l = signf(l) * pow(absf(l), 1.0 / 3.0)
	m = signf(m) * pow(absf(m), 1.0 / 3.0)
	s = signf(s) * pow(absf(s), 1.0 / 3.0)
	return Vector3(0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
		1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
		0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)


static func _from_oklab(L: Vector3) -> Vector3:
	var l := L.x + 0.3963377774 * L.y + 0.2158037573 * L.z
	var m := L.x - 0.1055613458 * L.y - 0.0638541728 * L.z
	var s := L.x - 0.0894841775 * L.y - 1.2914855480 * L.z
	l = l * l * l
	m = m * m * m
	s = s * s * s
	return Vector3(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
		-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
		-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s)


## OKLCH (L, C, hue degrees) to an sRGB colour, the chroma reduced until it fits.
static func _lch(L: float, C: float, hdeg: float) -> Color:
	var h := deg_to_rad(hdeg)
	for k in 40:
		var lin := _from_oklab(Vector3(L, C * cos(h), C * sin(h)))
		if lin.x >= -1e-4 and lin.y >= -1e-4 and lin.z >= -1e-4 and lin.x <= 1.0001 and lin.y <= 1.0001 and lin.z <= 1.0001:
			return Color(_l2s(lin.x), _l2s(lin.y), _l2s(lin.z))
		C *= 0.92
	var g := _from_oklab(Vector3(L, 0.0, 0.0))
	return Color(_l2s(g.x), _l2s(g.y), _l2s(g.z))


static func _to_lch(c: Color) -> Vector3:
	var L := _oklab(c)
	return Vector3(L.x, Vector2(L.y, L.z).length(), fposmod(rad_to_deg(atan2(L.z, L.y)), 360.0))


## A ramp of n steps through a key hue, darkest first (the showcase kit's
## `P.ramp`): OKLab lightness lo to hi, the hue turning hue_shift degrees from
## the dark end to the light, the chroma peaking in the middle steps.
static func _ramp(key: Color, n: int, lo: float, hi: float, hue_shift: float) -> Array[Color]:
	var lch := _to_lch(key)
	var out: Array[Color] = []
	for i in n:
		var u := 0.5 if n == 1 else float(i) / float(n - 1)
		var L := lo + (hi - lo) * u
		var C := lch.y * (1.0 - 0.55 * pow(absf(2.0 * u - 1.0), 2.0))
		var H := lch.z + hue_shift * (u - 0.5)
		var c := _lch(L, C, H)
		out.append(Color8(roundi(c.r * 255.0), roundi(c.g * 255.0), roundi(c.b * 255.0)))
	return out


## THE PALETTE'S CUT, on another thread: k-means in OKLab over samples of the
## unquantised hero views, weighted toward colour and light; the fixed colours
## take part in the assignment but never move, so the free ones fill what the
## ramps miss. Then the fixed and the free, near-duplicates dropped.
class PaletteJob extends RefCounted:
	var samples := PackedByteArray()
	var fixed := PackedColorArray()
	var free_n := 12
	var merge := 0.03
	## every colour counts alike, the dim ones too (the radiant style's cut)
	var even := false
	var out := PackedColorArray()

	var ms := 0

	func run() -> void:
		var c0 := Time.get_ticks_usec()
		var n := samples.size() / 3
		var lab := PackedVector3Array()
		lab.resize(n)
		var wts := PackedFloat32Array()
		wts.resize(n)
		for i in n:
			var L := ChartSky._oklab_lin(ChartSky._s2l(samples[i * 3] / 255.0),
				ChartSky._s2l(samples[i * 3 + 1] / 255.0), ChartSky._s2l(samples[i * 3 + 2] / 255.0))
			lab[i] = L
			wts[i] = (1.0 + 2.0 * Vector2(L.y, L.z).length()) if even else (0.2 + minf(1.0, L.x / 0.3)) * (1.0 + 3.0 * Vector2(L.y, L.z).length())
		var fl := PackedVector3Array()
		for c in fixed:
			fl.append(ChartSky._oklab(c))
		var dfix := PackedFloat32Array()
		dfix.resize(n)
		for i in n:
			var m := 1e9
			for f in fl:
				m = minf(m, lab[i].distance_squared_to(f))
			dfix[i] = m
		# k-means++ seeding, deterministic
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		var dmin := dfix.duplicate()
		var C := PackedVector3Array()
		for j in free_n:
			var tot := 0.0
			for i in n:
				tot += dmin[i] * wts[i]
			if tot <= 0.0:
				break
			var r := rng.randf() * tot
			var pick := 0
			for i in n:
				r -= dmin[i] * wts[i]
				if r <= 0.0:
					pick = i
					break
			C.append(lab[pick])
			for i in n:
				dmin[i] = minf(dmin[i], lab[i].distance_squared_to(C[j]))
		for it in 14:
			var sums := PackedVector3Array()
			sums.resize(C.size())
			var ws := PackedFloat32Array()
			ws.resize(C.size())
			for i in n:
				var bd := dfix[i]
				var best := -1
				for j in C.size():
					var d := lab[i].distance_squared_to(C[j])
					if d < bd:
						bd = d
						best = j
				if best >= 0:
					sums[best] += lab[i] * wts[i]
					ws[best] += wts[i]
			for j in C.size():
				if ws[j] > 0.0:
					C[j] = sums[j] / ws[j]
		var keep: Array[Vector3] = []
		for c in fixed:
			var L := ChartSky._oklab(c)
			if not _near(keep, L, 0.03):
				keep.append(L)
				out.append(c)
		for L in C:
			var lin := ChartSky._from_oklab(L)
			var c := Color8(roundi(clampf(ChartSky._l2s(lin.x), 0.0, 1.0) * 255.0),
				roundi(clampf(ChartSky._l2s(lin.y), 0.0, 1.0) * 255.0), roundi(clampf(ChartSky._l2s(lin.z), 0.0, 1.0) * 255.0))
			var L2 := ChartSky._oklab(c)
			# in the dark, where nothing is dithered, a near colour only swaps
			# with its neighbour block by block as the view moves: keep them apart
			if not _near(keep, L2, merge * (1.5 if L2.x < 0.36 else 1.0)):
				keep.append(L2)
				out.append(c)
		if out.size() > 128:
			out.resize(128)
		ms = (Time.get_ticks_usec() - c0) / 1000

	func _near(keep: Array[Vector3], L: Vector3, d: float) -> bool:
		for k in keep:
			if k.distance_to(L) < d:
				return true
		return false


# ------------------------------------------------------------------ the runtime

## The per-frame viewports, made once the galaxy is baked.
func _runtime() -> void:
	if _g_for().has("painted"):
		ChartPainted.runtime(self, _g_for())
		push()
		return
	_tvp = null
	_state = null
	_low_now = DisplaySettings.graphics_low
	_vp = SubViewport.new()
	_vp.transparent_bg = false
	_vp.disable_3d = true
	# drawn every frame (rendering only when pushed measured slower: the title's
	# frames stalled at 7-9 ms against 0.6)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	_pvp = SubViewport.new()
	_pvp.transparent_bg = false
	_pvp.use_hdr_2d = true
	_pvp.disable_3d = true
	_pvp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.add_child(_pvp)
	_svp = SubViewport.new()
	_svp.transparent_bg = true
	_svp.use_hdr_2d = true
	_svp.disable_3d = true
	_svp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_svp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_pvp.add_child(_svp)
	var g := _g_for()
	_lut_on = false
	_m_stars = ShaderMaterial.new()
	_m_stars.shader = STARS_SH
	_m_stars.set_shader_parameter("st_a", g.tex_a)
	_m_stars.set_shader_parameter("st_b", g.tex_b)
	_m_stars.set_shader_parameter("st_c", g.tex_c)
	_m_stars.set_shader_parameter("tex_w", StarchartScreen.MapChart.SKY_TEX_W)
	_m_stars.set_shader_parameter("n_star", int(g.n_star))
	_m_stars.set_shader_parameter("bulge_r", float(g.p.bulge_r))
	_m_stars.set_shader_parameter("k", K0)
	_stars = MeshDraw.new()
	_stars.material = _m_stars
	_stars.mesh = StarchartScreen.MapChart._quads(int(g.n_star) + MAX_EXTRA)
	_svp.add_child(_stars)
	_m_place = ShaderMaterial.new()
	if g.has("radiant"):
		_m_place.shader = ChartRadiant.PLACE_LOW_SH if _low_now else ChartRadiant.PLACE_SH
		ChartRadiant.feed_static(_m_place, g)
	else:
		_m_place.shader = PLACE_LOW_SH if _low_now else PLACE_SH
		_feed_static(_m_place, g)
	_m_place.set_shader_parameter("u_stars", _svp.get_texture())
	_place = _rect(_m_place)
	_pvp.add_child(_place)
	# never cleared: the composite holds a block's colour from the frame before
	_vp.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
	_hold_b0 = Vector2(INF, INF)
	_m_comp = ShaderMaterial.new()
	_m_comp.shader = COMP_SH
	_m_comp.set_shader_parameter("place", _pvp.get_texture())
	var radiant := g.has("radiant")
	_m_comp.set_shader_parameter("exposure", ChartRadiant.EXPOSURE if radiant else EXPOSURE)
	_m_comp.set_shader_parameter("burn", ChartRadiant.BURN if radiant else BURN)
	_m_comp.set_shader_parameter("vib", ChartRadiant.VIB if radiant else 0.0)
	_radiant_probe = {"frames": 0, "gpu": 0.0, "n": 0} if radiant else {}
	_comp = _rect(_m_comp)
	_vp.add_child(_comp)
	push()


## What a galaxy's place pass keeps for good: its bakes and its constants.
func _feed_static(m: ShaderMaterial, g: Dictionary) -> void:
	var p: Dictionary = g.p
	LegacyHole.apply(m, TILT)
	m.set_shader_parameter("u_noise", g.noise)
	m.set_shader_parameter("u_struct", g.struct)
	m.set_shader_parameter("u_k", K0)
	m.set_shader_parameter("u_ext", EXT)
	m.set_shader_parameter("u_form", int(p.form))
	m.set_shader_parameter("u_ball", p.ball)
	m.set_shader_parameter("u_bulgeR", float(p.bulge_r))
	m.set_shader_parameter("u_holeR", float(p.hole_r))
	m.set_shader_parameter("u_gasAmt", float(p.gas))
	m.set_shader_parameter("u_laneStr", float(p.lane))
	m.set_shader_parameter("u_armGain", float(p.arm_gain))
	m.set_shader_parameter("u_young", float(p.young))
	m.set_shader_parameter("u_tail", 1.0 if p.tail else 0.0)
	m.set_shader_parameter("u_armModel", Vector4(float(p.arms), float(p.twist), float(p.spin), float(p.bar)))
	m.set_shader_parameter("u_bCore", Vector3(1.0, 0.6, 0.26))
	m.set_shader_parameter("u_exp", EXPOSURE)
	m.set_shader_parameter("u_burn", BURN)


## The view: the viewport's blocks, where the galaxy's centre and the frame's
## centre are, the zoom (effective, in K0 units), the clock and the turn.
func _feed_view(m: ShaderMaterial, _g: Dictionary, vsz: Vector2, origin: Vector2, cpix: Vector2,
		res: Vector2, z: float, t: float, phi: float) -> void:
	m.set_shader_parameter("u_vp_size", vsz)
	m.set_shader_parameter("u_vp_origin", origin)
	m.set_shader_parameter("u_cpix", cpix)
	m.set_shader_parameter("u_res", res)
	m.set_shader_parameter("u_zoom", z)
	m.set_shader_parameter("u_time", t)
	m.set_shader_parameter("u_phi", phi)
	var block_gu := 2.0 / (z * K0)
	m.set_shader_parameter("u_lod", Vector2(maxf(0.0, log(block_gu / (2.0 * EXT / NOISE_N)) / log(2.0) + LODB),
		maxf(0.0, log(block_gu / (2.0 * EXT / STRUCT_N)) / log(2.0) + LODB)))


## The sky behind (`chart_bg.gdshaderinc`): how far it has been panned (the
## chart's `sky_pan`, screen px of panning, never of zooming) and its seed.
func _feed_sky(m: ShaderMaterial) -> void:
	m.set_shader_parameter("u_skyPan", chart.sky_pan.round())
	m.set_shader_parameter("u_skySeed", float(posmod(Run.galaxy_seed, 997)))


# ------------------------------------------------------------------ events, pure functions of t

static func _smooth(a: float, b: float, x: float) -> float:
	var u := clampf((x - a) / (b - a), 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


## A knot breathes (20 to 60 s); every 8 s one, chosen by hash, blooms 2.5x
## over 3 s, holds 4 and fades over 10.
static func _knot_amp(knots: Array, i: int, t: float, calm: bool) -> float:
	var kn: Dictionary = knots[i]
	var a := 0.75 + 0.25 * sin(TAU * t / float(kn.T) + float(kn.ph))
	if not calm:
		var n0 := floori(t / 8.0)
		for n in range(n0 - 2, n0 + 1):
			if int(floor(LegacyHole.hash01(n, 9) * knots.size())) != i:
				continue
			var tau := t - 8.0 * n
			var e := 0.0
			if tau >= 0.0:
				if tau < 3.0:
					e = _smooth(0.0, 3.0, tau)
				elif tau < 7.0:
					e = 1.0
				elif tau < 17.0:
					e = 1.0 - _smooth(7.0, 17.0, tau)
			a *= 1.0 + 1.5 * e
	return a


## A supernova: in slot n of 60 s, at 60n + 30 hash(n) s, at a disc star picked
## by hash; rises in 0.4 s, holds 1.5, decays over about 12. Its light echo is a
## ring sweeping out at 0.004 gu a second. Empty when there is none.
static func _supernova(cand: PackedVector2Array, t: float, calm: bool) -> Dictionary:
	if calm or cand.is_empty():
		return {}
	var n0 := floori(t / 60.0)
	for n: int in [n0, n0 - 1]:
		var t0: float = 60.0 * n + 30.0 * LegacyHole.hash01(n, 77)
		var age: float = t - t0
		if age < 0.0 or age > 40.0:
			continue
		var at := cand[int(LegacyHole.hash01(n, 78) * cand.size()) % cand.size()]
		var gain: float = age / 0.4 if age < 0.4 else (1.0 if age < 1.9 else exp(-(age - 1.9) / 4.0))
		return {"xy": at, "g": gain, "age": age, "echo": exp(-age / 11.0) * _smooth(0.0, 1.5, age)}
	return {}


## Distant lightning in an emission or dark cloud: a flash every 6 to 14 s at a
## point inside it, two or three pulses (80 ms rise, 250 ms decay, 120 ms
## apart). (envelope, round-frame x, y, radius) or a zero envelope.
static func _lightning(c: Dictionary, rl: Array[Vector3], t: float, calm: bool) -> Vector4:
	if calm or (int(c.kind) != 0 and int(c.kind) != 4):
		return Vector4(0, 0, 0, 1)
	var n0 := floori(t / 10.0)
	var s: int = int(c.i) * 13
	var best := Vector4(0, 0, 0, 1)
	for n in range(n0 - 1, n0 + 2):
		if LegacyHole.hash01(n, 101 + s) > 0.8:
			continue
		var tf := 10.0 * n + 8.0 * LegacyHole.hash01(n, 202 + s) - 4.0
		var tau := t - tf
		if tau < 0.0 or tau > 1.4:
			continue
		var np := 2 + (1 if LegacyHole.hash01(n, 303 + s) > 0.5 else 0)
		var env := 0.0
		for j in np:
			var x := tau - 0.12 * j
			if x < 0.0:
				continue
			var amp := 1.0 if j == 0 else 0.5 + 0.4 * LegacyHole.hash01(n, 404 + s + j)
			env += amp * (x / 0.08 if x < 0.08 else exp(-(x - 0.08) / 0.083))
		var lb: Vector3 = rl[int(LegacyHole.hash01(n, 505 + s) * 3.0) % 3]
		best = Vector4(env, lb.x + (LegacyHole.hash01(n, 606 + s) - 0.5) * lb.z,
			lb.y + (LegacyHole.hash01(n, 707 + s) - 0.5) * lb.z, 0.15 * float(c.radius))
	return best


## The clouds, knots and events at time t and turn phi, onto a place material;
## the clouds' own stars into `extra` (block x, y, plus; linear colour) when a
## frame wants them.
func _feed_events(m: ShaderMaterial, g: Dictionary, t: float, phi: float, _z: float, live: bool,
		extra: Array = []) -> void:
	var calm := (not live) or DisplaySettings.reduced_motion
	m.set_shader_parameter("u_drift", 0.5 if DisplaySettings.reduced_motion else 1.0)
	m.set_shader_parameter("u_wxOn", 0.0 if calm else 1.0)
	var clouds: Array = g.clouds
	var order: Array = []
	for c: Dictionary in clouds:
		order.append([c, _to_view(c.xy, phi)])
	order.sort_custom(func(x: Array, y: Array) -> bool: return (x[1] as Vector2).y < (y[1] as Vector2).y)
	var cl := PackedVector4Array()
	var clk := PackedVector4Array()
	var clp := PackedVector4Array()
	var cdir := PackedVector4Array()
	var lt := PackedVector4Array()
	var lobe := PackedVector4Array()
	var cs := cos(phi)
	var sn := sin(phi)
	var rls: Array = []
	for e: Array in order:
		if cl.size() >= MAX_CL:
			break
		var c: Dictionary = e[0]
		var v: Vector2 = e[1]
		var kind: int = c.kind
		cl.append(Vector4(v.x, v.y, float(c.radius), float(c.reach)))
		clk.append(Vector4(float(kind), float(c.hollow), float(c.shape), float(c.seed)))
		var xy: Vector2 = c.xy
		clp.append(Vector4(xy.x, xy.y, float(c.reach) if (kind == 2 or kind == 3) else float(c.radius), 0.0 if kind == 3 else 1.0))
		# lobe offsets turned with the galaxy, in the cloud's round frame
		var rl: Array[Vector3] = []
		for L: Vector3 in c.lobes:
			var dyp := L.y * 0.46341 / TILT
			rl.append(Vector3(L.x * cs + dyp * sn, (dyp * cs - L.x * sn) * TILT / 0.46341, L.z))
		for j in 3:
			lobe.append(Vector4(rl[j].x, rl[j].y, rl[j].z, 0.0))
		rls.append(rl)
		var ux := -v.x / K0
		var uy := -v.y / K0 / 0.46341
		var ul := maxf(Vector2(ux, uy).length(), 1e-6)
		cdir.append(Vector4(ux / ul, uy / ul, 0.0, 0.0))
		lt.append(_lightning(c, rl, t, calm))
	var ncl := cl.size()
	cl.resize(MAX_CL)
	clk.resize(MAX_CL)
	clp.resize(MAX_CL)
	cdir.resize(MAX_CL)
	lt.resize(MAX_CL)
	lobe.resize(MAX_CL * 3)
	m.set_shader_parameter("u_ncl", ncl)
	m.set_shader_parameter("u_cl", cl)
	m.set_shader_parameter("u_clk", clk)
	m.set_shader_parameter("u_clp", clp)
	m.set_shader_parameter("u_cdir", cdir)
	m.set_shader_parameter("u_lt", lt)
	m.set_shader_parameter("u_lobe", lobe)
	var knots: Array = g.knots
	var kn := PackedVector4Array()
	var amps := PackedFloat32Array()
	for i in knots.size():
		var a := _knot_amp(knots, i, t, calm)
		kn.append(Vector4(knots[i].xy.x, knots[i].xy.y, float(knots[i].size), a))
		amps.append(a)
	kn.resize(MAX_KN)
	amps.resize(MAX_KN)
	m.set_shader_parameter("u_nkn", knots.size())
	m.set_shader_parameter("u_kn", kn)
	var sv := Dictionary()
	if live:
		sv = _supernova(g.sn_cand, t, calm)
	if sv.is_empty():
		m.set_shader_parameter("u_sn", Vector4.ZERO)
		m.set_shader_parameter("u_echo", Vector4.ZERO)
	else:
		var v := _to_view(sv.xy, phi)
		m.set_shader_parameter("u_sn", Vector4(v.x, v.y, float(sv.g), float(sv.age)))
		m.set_shader_parameter("u_echo", Vector4(sv.xy.x, sv.xy.y, 0.004 * float(sv.age), float(sv.echo)))
	g["_amps"] = amps
	g["_order"] = order
	g["_rls"] = rls


## The clouds' own stars, this frame: an emission cloud's cluster, a reflection
## cloud's two lamps, a planetary's hot star and a pulsar's beat. (block x, y,
## plus) and linear colour pairs.
func _cloud_stars(g: Dictionary, t: float, phi: float, cpix: Vector2, z: float, origin: Vector2) -> Array:
	var pos := PackedVector4Array()
	var col := PackedVector4Array()
	var order: Array = g._order
	var rls: Array = g._rls
	for ci in mini(order.size(), rls.size()):
		var c: Dictionary = order[ci][0]
		var v: Vector2 = order[ci][1]
		var rl: Array[Vector3] = rls[ci]
		# (round-frame offset x, y, then the light), placed below
		var puts: Array[Vector3] = []
		match int(c.kind):
			0:
				var c0: Vector3 = rl[0]
				for o: Vector3 in c.cluster:
					puts.append(Vector3(c0.x * 0.6 + o.x, c0.y * 0.6 + o.y * 0.6, 0.0))
					puts.append(Vector3(0.9, 1.0, 1.3) * o.z)
			1:
				puts.append(Vector3(rl[0].x * 0.7, rl[0].y * 0.7, 0.0))
				puts.append(Vector3(1.6, 1.8, 2.3))
				puts.append(Vector3(rl[1].x * 0.8, rl[1].y * 0.8, 0.0))
				puts.append(Vector3(0.7, 0.8, 1.0))
			3:
				puts.append(Vector3.ZERO)
				puts.append(Vector3(1.8, 2.1, 2.6))
			2:
				var pp: Vector2 = c.pulsar
				if pp.x != INF:
					var beat := 0.45 + 1.1 * pow(0.5 + 0.5 * cos(TAU * t / 5.0), 8.0)
					var pv := _to_view(pp, phi)
					var s := cpix + pv * z
					if pos.size() < MAX_EXTRA:
						pos.append(Vector4(floorf((s.x - origin.x) * 0.5), floorf((s.y - origin.y) * 0.5), 0.0, 0.0))
						col.append(Vector4(0.55 * beat, 0.8 * beat, 1.3 * beat, 0.0))
		for q in range(0, puts.size(), 2):
			if pos.size() >= MAX_EXTRA:
				break
			var s := cpix + (v + Vector2(puts[q].x * K0, puts[q].y * 0.46341 * K0)) * z
			pos.append(Vector4(floorf((s.x - origin.x) * 0.5), floorf((s.y - origin.y) * 0.5), 0.0, 0.0))
			col.append(Vector4(puts[q + 1].x, puts[q + 1].y, puts[q + 1].z, 0.0))
	return [pos, col]


# ------------------------------------------------------------------ every frame

var _push_queued := false

## A push at the end of this frame, after whatever is still to move the view
## has moved it (a glide's tween runs after every _process).
func queue_push() -> void:
	if _legacy != null:
		_legacy.queue_push()
		return
	if _push_queued:
		return
	_push_queued = true
	_late_push.call_deferred()


func _late_push() -> void:
	_push_queued = false
	push()


## Every frame: the view, the turn and the clock, to the three passes.
func push() -> void:
	if _legacy != null:
		_legacy.interval = interval
		_legacy.push()
		return
	if chart == null or _vp == null or _g_for().is_empty():
		return
	var t_us := Time.get_ticks_usec()
	_push()
	if StarchartScreen.MapChart.prof:
		StarchartScreen.MapChart.prof_add("push", Time.get_ticks_usec() - t_us)


## The part of the chart that can be seen: all of it on the chart, the screen's
## share of the title's square (which is bigger than the screen).
func _visible_rect() -> Rect2:
	var full := Rect2(Vector2.ZERO, chart.size)
	if chart.clip_contents or not chart.is_inside_tree():
		return full
	var xf := chart.get_global_transform_with_canvas().affine_inverse()
	var vr := chart.get_viewport_rect()
	var a := xf * vr.position
	var b := xf * vr.end
	var seen := Rect2(a, Vector2.ZERO).expand(b)
	return full.intersection(seen) if full.intersects(seen) else full


func _push() -> void:
	var g := _g_for()
	if not _lut_on and g.has("lut"):
		_m_comp.set_shader_parameter("lut", g.lut)
		_m_comp.set_shader_parameter("pal", g.pal)
		_lut_on = true
	if chart.size.x <= 0.0 or chart.size.y <= 0.0:
		return
	var painted := g.has("painted")
	if DisplaySettings.graphics_low != _low_now:
		_low_now = DisplaySettings.graphics_low
		if painted:
			_m_place.shader = ChartPainted.PLACE_LOW_SH if _low_now else ChartPainted.PLACE_SH
		elif g.has("radiant"):
			_m_place.shader = ChartRadiant.PLACE_LOW_SH if _low_now else ChartRadiant.PLACE_SH
			_m_place.set_shader_parameter("u_steps", 8.0 if _low_now else ChartRadiant.STEPS)
		else:
			_m_place.shader = PLACE_LOW_SH if _low_now else PLACE_SH
	var k := _k()
	var z := chart.zoom * k / K0
	var t := StarchartScreen.MapChart.clock()
	var phi: float = chart.turn()
	var cpix: Vector2 = chart.centre_px()
	var exact: Vector2 = chart.size * 0.5 + chart.pan
	var zooming := _last_zoom > 0.0 and absf(log(chart.zoom / _last_zoom)) > 1e-7
	_last_zoom = chart.zoom
	var was_held := _since_zoom < 61
	# THE HOLD LETS GO ON A PAN, NOT ON A CLOCK: let go a second after a zoom, the
	# block grid went over from the screen's anchor to the galaxy centre's, and
	# when the two differed by a pixel the whole picture jumped a pixel with
	# nothing moving -- one of PAINTED's "weird pops" (5% of the frame's pixels on
	# one frame). Held until the view is dragged, the jump lands inside a move.
	var panned := chart.pan != _last_pan
	_last_pan = chart.pan
	if zooming:
		_since_zoom = 0
	elif panned or _since_zoom < 59:
		_since_zoom = mini(_since_zoom + 1, 999)
	var zw := 1.0 if _since_zoom < 60 else maxf(0.0, 1.0 - float(_since_zoom - 59) * 0.5)
	var ccon := cpix + (exact - cpix) * zw
	if zw > 0.0 and not was_held:
		_hold_c = cpix
	# while held, the block grid stays where it was on the screen too: a grid
	# that followed the centre's parity would shift the samples by a pixel
	var anchor := _hold_c if zw > 0.0 else cpix
	# PAINTED MOVES IN WHOLE BLOCKS. Its far sky (the little galaxies, the tiered
	# stars, the wisps) slides by its own depth, far slower than the galaxy, and is
	# drawn on the same grid of 2x2 blocks; a grid that followed the galaxy's
	# centre pixel by pixel swapped parity on every pixel of a pan, and each far
	# block hopped a pixel to and fro (0.0063 of the pixels flipping back on a
	# slow pan at zoom 4). The galaxy is set on the even pixel nearest its centre
	# instead, so a pan moves it a block at a time and the far sky only ever
	# steps one way.
	if painted and zw <= 0.0:
		var even := (cpix / 2.0).floor() * 2.0
		ccon += even - cpix
		cpix = even
		anchor = even
	var vis := _visible_rect()
	# The blocks are anchored to the galaxy's centre, so a pan by one pixel moves
	# the picture by one pixel rather than redrawing every block; a block's
	# margin on each side, and the same size whichever way the blocks fall (a
	# viewport resized every odd pixel of a drag reallocates every other frame).
	var vx := floorf(vis.position.x)
	var vy := floorf(vis.position.y)
	_vp_origin = Vector2(vx - posmod(int(vx) - int(anchor.x), 2) - 2.0, vy - posmod(int(vy) - int(anchor.y), 2) - 2.0)
	var vsz := Vector2i(ceili(vis.size.x / 2.0) + 3, ceili(vis.size.y / 2.0) + 3)
	var resized := _vp.size != vsz
	if resized:
		_vp.size = vsz
		_pvp.size = vsz
		_svp.size = vsz
		_place.size = Vector2(vsz)
		_comp.size = Vector2(vsz)
		if _tvp != null:
			_tvp.size = vsz
			_state.size = Vector2(vsz)
	var vs := Vector2(vsz)
	# the frame's centre: the middle of what can be seen
	var res := (vis.position + vis.size * 0.5) * 2.0
	# the dither's anchor: the galaxy's centre, or, while held, the screen
	var b0 := ((_vp_origin - cpix) / 2.0).floor()
	var bs := (_vp_origin / 2.0).floor()
	if zw > 0.0:
		if not was_held:
			_hold_d = b0 - bs
		b0 = bs + _hold_d
	if painted:
		ChartPainted.push(self, g, vs, _vp_origin, ccon, res, z, t, phi, b0, resized)
		_feed_sky(_m_place)
		queue_redraw()
		return
	var m := _m_place
	_feed_view(m, g, vs, _vp_origin, ccon, res, z, t, phi)
	_feed_sky(m)
	m.set_shader_parameter("u_block0", b0)
	_feed_events(m, g, t, phi, z, true)
	if g.has("radiant"):
		ChartRadiant.feed_events(m, g, t, DisplaySettings.reduced_motion, true)
		_radiant_safety()
	var ms := _m_stars
	ms.set_shader_parameter("vp_origin", _vp_origin)
	ms.set_shader_parameter("cpix", ccon)
	ms.set_shader_parameter("res", res)
	ms.set_shader_parameter("zoom", z)
	ms.set_shader_parameter("phi", phi)
	ms.set_shader_parameter("kn_amp", g._amps)
	var ex: Array = _cloud_stars(g, t, phi, ccon, z, _vp_origin)
	var epos: PackedVector4Array = ex[0]
	var ecol: PackedVector4Array = ex[1]
	var ne := epos.size()
	epos.resize(MAX_EXTRA)
	ecol.resize(MAX_EXTRA)
	ms.set_shader_parameter("extra_pos", epos)
	ms.set_shader_parameter("extra_col", ecol)
	ms.set_shader_parameter("n_extra", ne)
	var mc := _m_comp
	mc.set_shader_parameter("vp_size", vs)
	mc.set_shader_parameter("block0", b0)
	# the blocks' anchor moved by whole blocks on a pan: where each was last frame
	# (not across a jump of the view: a block's colour from another place is no
	# colour to hold)
	var jump := _hold_z > 0.0 and absf(log(z / _hold_z)) > 0.03
	_hold_z = z
	var valid := _hold_b0.x != INF and not resized and _lut_on and not jump 		and (b0 - _hold_b0).length() < 8.0
	mc.set_shader_parameter("prev_shift", (b0 - _hold_b0) if valid else Vector2.ZERO)
	mc.set_shader_parameter("hyst", hyst if valid else 0.0)
	_hold_b0 = b0
	mc.set_shader_parameter("dith", dith)
	mc.set_shader_parameter("quant", quant and _lut_on)
	# a ball has almost no texture to shimmer and one long gradient that needs
	# the dither, so it is let in on gentler slopes
	mc.set_shader_parameter("gs_lo", dith_gs * (0.3 if int(g.p.form) != 0 else 1.0) * (ChartRadiant.DITH_GS if g.has("radiant") else 1.0))
	mc.set_shader_parameter("coh_lo", minf(0.95, dith_coh * (0.75 if int(g.p.form) != 0 else 1.0) * (ChartRadiant.DITH_COH if g.has("radiant") else 1.0)))
	_stars.queue_redraw()
	queue_redraw()


## RADIANT'S SAFETY: it is the heavy style ("for photos probably", Jon). Over its
## first seconds of drawing the sky's own viewports' GPU time is averaged; if
## this machine cannot hold it (`ChartRadiant.FALLBACK_MS`), the chart falls
## back to SIMPLIFIED, with one line in the log. A harness's `style=radiant` is
## never overruled (it is measuring).
func _radiant_safety() -> void:
	if _radiant_probe.is_empty() or _radiant_probe.has("done"):
		return
	var f: int = int(_radiant_probe.frames) + 1
	_radiant_probe.frames = f
	var rids: Array[RID] = [_svp.get_viewport_rid(), _pvp.get_viewport_rid(), _vp.get_viewport_rid()]
	if f == 1:
		for r in rids:
			RenderingServer.viewport_set_measure_render_time(r, true)
		return
	if f < 12:
		return
	var ms := 0.0
	for r in rids:
		ms += RenderingServer.viewport_get_measured_render_time_gpu(r)
	_radiant_probe.gpu = float(_radiant_probe.gpu) + ms
	_radiant_probe.n = int(_radiant_probe.n) + 1
	if int(_radiant_probe.n) < ChartRadiant.PROBE_FRAMES:
		return
	_radiant_probe["done"] = true
	var avg := float(_radiant_probe.gpu) / float(_radiant_probe.n)
	_radiant_probe["avg_ms"] = avg
	print_verbose("RADIANT the sky's own GPU time: %.2f ms a frame over %d frames" % [avg, int(_radiant_probe.n)])
	if avg > ChartRadiant.budget_ms() and (DisplaySettings.render_style == &"radiant" or ChartRadiant.probe_forced()):
		push_warning("RADIANT measured %.1f ms a frame on this machine; drawing SIMPLIFIED" % avg)
		Run.log_line("RADIANT is too heavy for this machine, so the star chart is drawn SIMPLIFIED.", &"them")
		ChartRadiant.fell_back = true
		if DisplaySettings.render_style == &"radiant":
			DisplaySettings.set_render_style(&"simplified")
		else:
			Sig.render_style_changed.emit()


func _draw() -> void:
	if chart == null:
		return
	var t0 := Time.get_ticks_usec()
	# Built and handed over at the first draw, once the layout has given the
	# chart its real size.
	chart._ensure_gpu()
	if _legacy != null:
		# the legacy renderer draws itself, and asks for its own redraws
		_legacy.queue_redraw()
		return
	if _vp == null or _g_for().is_empty():
		draw_rect(Rect2(Vector2.ZERO, chart.size), Color8(7, 10, 18), true)
	else:
		draw_texture_rect(_vp.get_texture(), Rect2(_vp_origin, Vector2(_vp.size) * 2.0), false)
	if StarchartScreen.MapChart.prof:
		StarchartScreen.MapChart.prof_add("sky", Time.get_ticks_usec() - t0)
