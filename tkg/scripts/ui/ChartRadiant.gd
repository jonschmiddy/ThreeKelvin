class_name ChartRadiant
extends RefCounted

## The heavy RADIANT sky; it falls back to SIMPLIFIED if the GPU cannot hold it.
## Why: docs/why/ChartRadiant.md#radiant-style

const NOISE_SH := preload("res://shaders/chart_r_bake_noise.gdshader")
const DISC_SH := preload("res://shaders/chart_r_bake_disc.gdshader")
const HOR_SH := preload("res://shaders/chart_r_bake_hor.gdshader")
const PLACE_SH := preload("res://shaders/chart_r_place.gdshader")
const PLACE_LOW_SH := preload("res://shaders/chart_r_place_low.gdshader")

## The bakes' reach (galaxy units each side) and sizes.
const EXT := 1.3
const DISC_N := 1024
const HOR_SIZE := Vector2i(1024, 256)
const RMAX := 1.3
## The composite's exposure, burn and vibrance (the showcase's, set by eye at 2x).
const EXPOSURE := 1.0
const BURN := 3.0
const VIB := 0.5
## CHIAROSCURO (Nov 7, Jon: "super dramatic"): one dominant light, the core; the rest to black.
## `u_drama`: (toe, core gain, arms' young light, god-ray haze gain);
## `u_dramaR`: (core light's reach, billows' lit side, gain after the toe, billows' shade fill).
## Why: docs/why/ChartRadiant.md#chiaroscuro
const DRAMA := Vector4(0.18, 2.0, 0.25, 2.2)
const DRAMA_R := Vector4(1.5, 1.25, 2.8, 0.3)
## A BALL's (toe, gain): its drama is the hill made steep; near no toe so it fades, no rim.
## Why: docs/why/ChartRadiant.md#ball-drama
const DRAMA_BALL := Vector2(0.004, 2.1)
## ...AND COMING IN: from the opening to LOCAL REGION's zoom the toe rises to A's own,
## so a close ball's outskirts fall to black instead of one haze.
## Why: docs/why/ChartRadiant.md#ball-toe-near
const BALL_TOE_NEAR := 0.15
const BALL_TOE_Z := Vector2(0.5, 1.0)


## A ball's `u_drama` at the chart's zoom `z` (1 = LOCAL REGION's).
static func ball_drama(z: float) -> Vector4:
	var toe := lerpf(DRAMA_BALL.x, BALL_TOE_NEAR, smoothstep(BALL_TOE_Z.x, BALL_TOE_Z.y, z))
	return Vector4(toe, DRAMA.y, 1.0, DRAMA.w)
const GOD_RAYS := 1.0
## A lobe's dy is in the chart's flattened frame; this takes it to the plane.
const FLAT := 0.46341 / 0.38
## Fall back past the budget: an RTX 3070 measures 0.6 to 1.6 ms, so four times is too slow.
## Why: docs/why/ChartRadiant.md#safety-budget
const FALLBACK_MS := 6.0
## 16 steps with jitter read the same as the showcase's 22, which cost 2.5 ms on an RTX 3070.
## Why: docs/why/ChartRadiant.md#march-steps
const STEPS := 11.0
## 0.02, not SIMPLIFIED's 0.06: that left a fan of rose twins that flickered on slow zoom.
## Why: docs/why/ChartRadiant.md#palette-merge
static var PAL_MERGE := 0.02
## Gates of 1: the colour hold stops flicker, and 2 and 1.25 had flattened gradients to plates.
## Why: docs/why/ChartRadiant.md#dither-gates
const DITH_GS := 0.5
const DITH_COH := 0.8
## How many colours the palette's cut adds to the reserved ones (the showcase's
## A spent 56 colours in all; a cut of 12 drew the haze in grey plates).
const PAL_FREE := 40
## THE GLOW AND COLOUR (direction C, Nov 7, `RadiantGlow`): halos, deep violet shade;
## over A's hard light it blooms only the hottest gas and draws no rays.
## Why: docs/why/ChartRadiant.md#glow-and-colour
const GLOW_HOLE := 1.35
const GLOW_LOOK := {"thr": 0.6, "knee": 0.16, "gain": 1.2, "steps": 4.0, "band": 0.2, "rays": 0.0, "ray_len": 0.7,
	"halo_a": Vector3(0.4, 0.6, 0.8), "halo_b": Vector3(0.9, 0.7, 0.5), "wide_k": 0.7,
	"shade_tint": Vector3(0.30, 0.16, 0.78), "shade": 0.65, "dark_hi": 0.1, "crush": 0.0, "vib": 0.3, "white_at": 1.5,
	"keep_lo": 0.085}
## How many drawn frames the safety averages (after a few to settle).
const PROBE_FRAMES := 90

## The noise volume: the same for every galaxy, baked once a session.
static var _noise: ImageTexture = null
## The safety has fallen back this session: RADIANT is not drawn again until
## the player chooses it again.
static var fell_back := false


## Colours every radiant palette keeps, so small vivid things are never starved by the cut.
static func fixed_palette() -> PackedColorArray:
	var out := PackedColorArray()
	for h in ["#070a12", "#0b1020", "#0f1529", "#141b33"]:
		out.append(Color(h))
	for i in range(1, 8):
		out.append(LegacyHole.PALETTE[i])
	var ramps := [[Vector3(1.0, 0.2, 0.3), [0.15, 0.4, 0.9, 1.7]], [Vector3(0.2, 0.95, 0.85), [0.25, 0.7, 1.5]],
		[Vector3(1.0, 0.16, 0.13), [0.3, 0.9]], [Vector3(0.32, 0.52, 1.0), [0.15, 0.45, 1.0]],
		# (LIGHT THAT MOVES: the core's flare and the young stars' flares, which the
		# cut never sees -- it is cut from the scene at rest -- kept at the lights they
		# reach, up into the burn: the hue-keeping tone tops out at the cut's brightest
		# tan, and a flare pressed the inner gas flat onto it; past `BURN` it goes
		# toward white as the composite's tone does, so a flare's heart has whites)
		[Vector3(1.0, 0.66, 0.36), [0.35, 0.8, 1.6, 3.0, 5.0, 8.0, 14.0]], [Vector3(0.62, 0.78, 1.0), [0.6, 1.5, 3.2, 7.0, 14.0]]]
	# (no bulge ramp: the cut takes the bulge's tans from what is on screen; a
	# reserved amber drew a saturated orange ring round every elliptical)
	for r: Array in ramps:
		var col: Vector3 = r[0]
		for m: float in r[1]:
			var h := col * m
			var mx := maxf(h.x, maxf(h.y, h.z))
			var mt := 1.0 - exp(-mx)
			var c := (h * (mt / mx)).lerp(Vector3(mt, mt, mt), smoothstep(BURN, BURN * 3.0, mx))
			out.append(Color(ChartSky.linear_to_srgb(c.x), ChartSky.linear_to_srgb(c.y), ChartSky.linear_to_srgb(c.z)))
	# (the void itself and the burnt-out whites: chiaroscuro's two ends; after the
	# hole's bands, which `ChartSky` keeps exact by their place, 4 to 11)
	for h in ["#020306", "#fffaf0", "#ffe9c4"]:
		out.append(Color(h))
	return out


## A harness's `style=radiant` is honoured though unbuilt, as the chart can draw it.
static func wanted() -> bool:
	if fell_back:
		return false
	return DisplaySettings.render_style == &"radiant" or "style=radiant" in OS.get_cmdline_user_args()


## The safety's budget, ms: `FALLBACK_MS`, or a harness's `radiantprobe=MS`
## (which also lets the safety act on a harness's `style=radiant`, to test it).
static func budget_ms() -> float:
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with("radiantprobe="):
			return float((a as String).substr(13))
	return FALLBACK_MS


static func probe_forced() -> bool:
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with("radiantprobe="):
			return true
	return false


## Per-kind showcase numbers generalised by shape; balls use a lower peak and halo (Jon, Oct 18).
## Why: docs/why/ChartRadiant.md#galaxy-look
const STORY_GAIN_R := 1.0
## (A+B+C: the base's 0.8 / 0.06 and nucleus 1.5 again; C's 0.55 / 0.03 / 2.6 were
## set against C's own tone, and over A's ball grade (`DRAMA_BALL`) the nucleus
## burnt out and the body ended in a hard orb)
const BALL_BODY := 0.8
const BALL_HALO := 0.06
## A halo's fall (`u_haloFall`): its power, where a ball's halo starts and stops
## ending (in its scales), and how much harder it dithers out at its edge
const HALO_FALL := Vector4(1.7, 0.8, 2.8, 0.0)

## A ball as its own kind in this style (`u_ballK`, `chart_r_place`, `chart_r_bake_disc`): (its
## kind as `ChartSky.ball_of` numbers it, its young gas and star birth 0..1, how lopsided 0..1,
## its globular-cluster halo 0..1).
## Why: docs/why/ChartRadiant.md#ball-kinds
static func ball_kind(p: Dictionary) -> Vector4:
	var ball: Vector4 = p.ball
	match int(ball.w):
		1:
			return Vector4(1.0, 1.0, 0.0, 0.0)
		2:
			return Vector4(2.0, 0.0, 0.0, 0.0)
		3:
			return Vector4(3.0, 0.35, 0.6, 0.0)
	return Vector4(0.0, 0.0, 0.0, 1.0 if GalaxyGen.type_name(int(p.kind)) == "Giant Elliptical" else 0.0)


## A ball's body in this style: (size against its ball radius; where its light starts to fade
## and where it is gone, in its outer scale; its roundness, the bulge's c/R).
## Why: docs/why/ChartRadiant.md#ball-body
static func ball_form(p: Dictionary) -> Vector4:
	match GalaxyGen.type_name(int(p.kind)):
		"Flattened Elliptical":
			return Vector4(1.05, 0.4, 1.6, 0.54)
		"Giant Elliptical":
			return Vector4(1.15, 0.45, 2.3, 0.72)
		"Dwarf Spheroidal":
			return Vector4(0.75, 0.3, 2.4, 0.8)
		"Blue Compact Dwarf":
			return Vector4(1.0, 0.45, 1.8, 0.72)
	return Vector4(1.0, 0.5, 1.9, 0.72)


## THE BIG DWARF's envelope in this style (`ChartTorn.ball_v`, `chart_r_place`'s): its
## light and the power it falls by, by kind. Measured off the chart: lit to about
## `ChartTorn.LIT_K` of its reach, on its colours' bottom steps.
const BIG_ENV := {14: Vector2(0.08, 1.0), 15: Vector2(0.08, 1.0)}


static func ball_env(kind: int) -> Vector4:
	var e: Vector2 = BIG_ENV.get(kind, Vector2(0.05, 1.2))
	return ChartTorn.ball_v(e.x, e.y)


## THE KNOTS OF A BALL THAT MAKES STARS (Nov 5): a blue compact dwarf full of them,
## a merger's remnant a few along its stream -- the spirals' own knots (`ChartSky`'s
## format: they breathe and bloom as a spiral's do, and the knot map draws them), in
## the plane, where this style's bake lays the young gas (`chart_r_bake_disc`'s ball).
## None for the others.
static func ball_knots(p: Dictionary) -> Array:
	var out: Array = []
	if int(p.form) != 1:
		return out
	var bk := ball_kind(p)
	var re: float = (p.ball as Vector4).x
	var n := 14 if int(bk.x) == 1 else (5 if int(bk.x) == 3 else 0)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([Run.galaxy_seed, int(p.kind), 4471])
	for i in n:
		var xy: Vector2
		if int(bk.x) == 1:
			var a := rng.randf() * TAU
			var r := re * 0.85 * sqrt(rng.randf())
			# (a big dwarf's, `ChartTorn.big`: a few through its envelope too)
			if i >= 10 and ChartTorn.big_on(int(p.kind)):
				r = (0.25 + 0.4 * sqrt(rng.randf())) * ChartTorn.cover()
			xy = Vector2(cos(a), sin(a)) * r
		else:
			xy = stream_at(0.15 + 0.75 * rng.randf(), re) + Vector2(rng.randf() - 0.5, rng.randf() - 0.5) * 0.04 * re
		out.append({"xy": xy, "size": 0.004 + 0.006 * rng.randf(), "T": 20.0 + 40.0 * rng.randf(),
			"ph": rng.randf() * TAU, "st": []})
	return out


## A point a share f (0..1) along a merger's tidal stream on the plane (gu): out from
## the body's edge, curling round one side (`chart_r_bake_disc`'s `streamD`, the same arc).
static func stream_at(f: float, re: float) -> Vector2:
	var a := 0.3 + 2.4 * f
	var r := re * (0.95 + 1.2 * f)
	return Vector2(cos(a), sin(a)) * r


## The gas's two colours from the galaxy's gas and its kinds of cloud (moved
## here from the LEGACY chart's renderer when that style went, Nov 7).
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

static func look(p: Dictionary) -> Dictionary:
	var form: int = p.form
	var br: float = p.bulge_r
	var ell := form == 1
	var ball: Vector4 = p.ball
	var pals: Array = _gas_palette(float(p.gas))
	var blue: Vector3 = pals[0]
	var arms := int(p.arms)
	var chaos: float = p.chaos
	var arm_k := 0.0
	if arms > 0:
		arm_k = clampf(1.0 - chaos * 1.8, 0.35, 1.0) * (0.75 if arms >= 5 else 1.0)
	var L := {}
	if ell:
		var bk := ball_kind(p)
		var bf := ball_form(p)
		var re: float = ball.x * bf.x
		L.bulge = Vector4(0.23 * re, 1.0 * re, bf.w, 0.08 * re)
		# (a dwarf spheroidal has no bright nucleus: its light is spread thin)
		L.peaks = Vector4(0.7 if int(bk.x) == 2 else 1.5, BALL_BODY * clampf(float(ball.z) / 0.085, 0.4, 1.3), 0.25, 1.4)
		L.halo = Vector4(BALL_HALO, maxf(0.3, 1.4 * re), bf.w, 1.0)
		# (no disc under a ball: the showcase's faint one drew a flat plate with a
		# hard rim round the small ones. Only a ball with young gas has one: its gas
		# and young light, baked about its middle (`chart_r_bake_disc`), lit and
		# billowing as a spiral's arms are)
		L.discK = Vector4(0.0, 1.35, 1.8, 0.6) * bk.y
		L.gasK = Vector4(34.0, 0.0, 0.6, 0.2)
		L.rd = 0.3
		L.young = Vector3(0.8, 0.85, 1.0)
		L.oldIn = Vector3(1.0, 0.8, 0.56)
		L.oldOut = Vector3(0.95, 0.78, 0.6)
	else:
		# The bulge's light grows slower than its radius, or a big bulge washes over the billows.
		var bk := br / 0.128
		L.bulge = Vector4(0.04 * pow(bk, 0.4), 0.13 * pow(bk, 0.5), 0.83, 0.02 * pow(bk, 0.3))
		L.peaks = Vector4(1.5, 1.0, 0.3, 1.6)
		L.halo = Vector4(0.026, 0.5, 0.62, 0.0)
		L.discK = Vector4(0.5, 1.35 * (1.0 if arms > 0 else 0.3), 1.2, 1.0)
		L.gasK = Vector4(34.0, 0.18 if arms > 0 else 0.08, 0.6, 0.2)
		L.rd = 0.25 + 0.02 * clampf((br - 0.128) / 0.06, 0.0, 1.0)
		L.young = blue * 0.75 + Vector3(0.42, 0.58, 1.0) * 0.25
		L.oldIn = Vector3(1.0, 0.82, 0.6)
		L.oldOut = Vector3(0.45, 0.56, 1.0)
	# the cavity: a narrow component taken out of the middle, so the hole sits in
	# a slightly darker ring
	var b: Vector4 = L.bulge
	var pk: Vector4 = L.peaks
	L.bulgeI = Vector4(pk.x, pk.y, pk.z * (pk.x / b.x + pk.y / b.y) * b.w, pk.w)
	# the bulge's light: amber to gold; a blue compact dwarf's young and blue
	L.bCore = Vector3(1.0, 0.6, 0.26)
	L.bInner = Vector3(1.0, 0.82, 0.55)
	L.bOuter = Vector3(0.95, 0.45, 0.17)
	if ell and int(ball.w) == 1:
		L.bCore = Vector3(0.95, 0.9, 1.0)
		L.bInner = Vector3(0.75, 0.82, 1.0)
		L.bOuter = Vector3(0.45, 0.58, 1.0)
		# (its halo falls off and dithers out, Jon's DH:B: 1.3x bright, fade 0.49 at rest)
		# Why: docs/why/ChartRadiant.md#dwarf-halo
		L.halo = Vector4(L.halo.x * 1.3, L.halo.y, L.halo.z, 0.0)
		L.haloFall = Vector4(1.3, 0.5, 3.0, 1.0)
		L.young = blue * 0.6 + Vector3(0.42, 0.58, 1.0) * 0.4
	elif ell and int(ball.w) == 2:
		# a dwarf spheroidal grey: old, faint starlight, barely warm
		L.bCore = Vector3(0.92, 0.86, 0.78)
		L.bInner = Vector3(0.8, 0.77, 0.74)
		L.bOuter = Vector3(0.6, 0.6, 0.62)
		L.halo = Vector4(L.halo.x * 0.6, L.halo.y, L.halo.z, 0.45)
	elif ell and int(ball.w) == 3:
		L.young = blue * 0.75 + Vector3(0.42, 0.58, 1.0) * 0.25
	L.arm_k = arm_k
	L.gas = (float(ball_kind(p).y) * maxf(float(p.gas), 0.8)) if ell else float(p.gas)
	L.ell = ell
	return L


## The galaxy's constants every pass reads (the arm model and its gas).
static func feed_common(m: ShaderMaterial, p: Dictionary, L: Dictionary) -> void:
	m.set_shader_parameter("u_arms", float(p.arms))
	m.set_shader_parameter("u_twist", float(p.twist))
	m.set_shader_parameter("u_bar", float(p.bar))
	m.set_shader_parameter("u_spread", float(p.spread))
	m.set_shader_parameter("u_spin", float(p.spin))
	m.set_shader_parameter("u_gas", float(L.gas))
	m.set_shader_parameter("u_armStr", float(L.arm_k))
	m.set_shader_parameter("u_laneStr", float(p.lane))
	m.set_shader_parameter("u_rd", float(L.rd))
	m.set_shader_parameter("u_seed", float(p.kind) * 0.37 + 1.3)
	m.set_shader_parameter("u_chaos", float(p.chaos))


# ------------------------------------------------------------------ the bakes

## Stage one: the noise volume (if this session has none) and the two disc maps.
static func begin_bake(sky: ChartSky, g: Dictionary, holder: Node) -> Array[SubViewport]:
	var p: Dictionary = g.p
	var L := look(p)
	g["look"] = L
	var out: Array[SubViewport] = []
	for pass_i in 2:
		var m := ShaderMaterial.new()
		m.shader = DISC_SH
		feed_common(m, p, L)
		m.set_shader_parameter("u_ext", EXT)
		m.set_shader_parameter("u_pass", pass_i)
		m.set_shader_parameter("u_isEll", 1.0 if L.ell else 0.0)
		m.set_shader_parameter("u_ballK", ball_kind(p) if L.ell else Vector4.ZERO)
		m.set_shader_parameter("u_ballR", float((p.ball as Vector4).x) if L.ell else 0.3)
		out.append(sky.pass_viewport(holder, Vector2i(DISC_N, DISC_N), ChartSky.shader_rect(m), true))
	# (a ball that makes stars has knots of its own: none came from `ChartSky._make_knots`,
	# which lays them on arms)
	if L.ell and (g.knots as Array).is_empty():
		g["knots"] = ball_knots(p)
	# the knot map: the nearest knot to each texel (8-bit, 512 square)
	var mk := ShaderMaterial.new()
	mk.shader = DISC_SH
	feed_common(mk, p, L)
	mk.set_shader_parameter("u_ext", EXT)
	mk.set_shader_parameter("u_pass", 2)
	var kn := PackedVector4Array()
	for k: Dictionary in g.knots:
		var xy: Vector2 = k.xy
		kn.append(Vector4(xy.x, xy.y, float(k.size), 1.0))
	mk.set_shader_parameter("u_nkn", kn.size())
	kn.resize(64)
	mk.set_shader_parameter("u_kn", kn)
	out.append(sky.pass_viewport(holder, Vector2i(512, 512), ChartSky.shader_rect(mk), false))
	if _noise == null:
		var mn := ShaderMaterial.new()
		mn.shader = NOISE_SH
		out.append(sky.pass_viewport(holder, Vector2i(528, 528), ChartSky.shader_rect(mn), true))
	# Height fields read SIMPLIFIED's two bakes, so puffs and terrain stand where its do.
	g["_s_at"] = out.size()
	for mode in 2:
		var n := ChartSky.NOISE_N if mode == 0 else (ChartSky.STRUCT_N if (int(p.arms) > 0 or float(p.bar) > 0.0) else 16)
		var ms := ShaderMaterial.new()
		ms.shader = ChartSky.BAKE_SH
		ms.set_shader_parameter("mode", mode)
		ms.set_shader_parameter("ext", ChartSky.EXT)
		ms.set_shader_parameter("arms", float(p.arms))
		ms.set_shader_parameter("twist", float(p.twist))
		ms.set_shader_parameter("bar", float(p.bar))
		ms.set_shader_parameter("spin", float(p.spin))
		ms.set_shader_parameter("spread", float(p.spread))
		ms.set_shader_parameter("chaos", float(p.chaos))
		out.append(sky.pass_viewport(holder, Vector2i(n, n), ChartSky.shader_rect(ms), false))
	return out


## Stage two: the disc maps read back and mip-mapped; the horizon map queued.
static func mid_bake(sky: ChartSky, g: Dictionary, vps: Array, holder: Node) -> SubViewport:
	var imgs: Array[Image] = []
	for vp: SubViewport in vps:
		var img := vp.get_texture().get_image()
		if img == null:
			return null
		imgs.append(img)
	imgs[0].generate_mipmaps()
	imgs[1].generate_mipmaps()
	g["discA"] = ImageTexture.create_from_image(imgs[0])
	g["discB"] = ImageTexture.create_from_image(imgs[1])
	g["knotMap"] = ImageTexture.create_from_image(imgs[2])
	var s_at := int(g.get("_s_at", imgs.size()))
	if s_at > 3:
		_noise = ImageTexture.create_from_image(imgs[3])
	g["noise_r"] = _noise
	# (SIMPLIFIED's bakes for the solid look, as `ChartSky._stage_bakes` keeps them)
	if imgs.size() >= s_at + 2:
		for i in 2:
			imgs[s_at + i].convert(Image.FORMAT_RGBA8)
			imgs[s_at + i].generate_mipmaps()
		g["noise"] = ImageTexture.create_from_image(imgs[s_at])
		g["struct"] = ImageTexture.create_from_image(imgs[s_at + 1])
	for vp: SubViewport in vps:
		vp.queue_free()
	var m := ShaderMaterial.new()
	m.shader = HOR_SH
	feed_common(m, g.p, g.look)
	m.set_shader_parameter("u_rmax", RMAX)
	m.set_shader_parameter("u_ext", EXT)
	m.set_shader_parameter("u_discB", g.discB)
	return sky.pass_viewport(holder, HOR_SIZE, ChartSky.shader_rect(m), true)


## Stage three: the horizon map read back. The galaxy's bakes are in.
static func end_bake(g: Dictionary, vp: SubViewport) -> bool:
	var img := vp.get_texture().get_image()
	if img == null:
		return false
	g["hor"] = ImageTexture.create_from_image(img)
	vp.queue_free()
	return true


# ------------------------------------------------------------------ the place pass

## What a galaxy's place pass keeps for good: its bakes, its look, its clouds.
static func feed_static(m: ShaderMaterial, g: Dictionary) -> void:
	var p: Dictionary = g.p
	var L: Dictionary = g.look
	LegacyHole.apply(m, ChartSky.TILT)
	feed_common(m, p, L)
	m.set_shader_parameter("u_noise", g.noise_r)
	# the solid look's height fields read SIMPLIFIED's bakes (`chart_solid`)
	m.set_shader_parameter("u_sNoise", g.get("noise"))
	m.set_shader_parameter("u_sStruct", g.get("struct"))
	m.set_shader_parameter("u_sExt", ChartSky.EXT)
	m.set_shader_parameter("u_isBall", bool(L.ell))
	# (set for every galaxy, a disc's to the defaults: a material that drew a ball before
	# must not lean a spiral's bulge or squash its outline)
	var bf := ball_form(p)
	m.set_shader_parameter("u_ballK", ball_kind(p) if L.ell else Vector4.ZERO)
	m.set_shader_parameter("u_ballF", Vector4(bf.y, bf.z, float((p.ball as Vector4).x) * bf.x, 0.72 / bf.w) if L.ell else Vector4(0.5, 1.8, 0.3, 1.0))
	m.set_shader_parameter("u_ballV", ball_env(int(p.kind)) if L.ell else Vector4(1.0, 0.0, 1.0, 0.0))
	m.set_shader_parameter("u_ballSq", float((p.ball as Vector4).y))
	ChartSky.push_story(m, STORY_GAIN_R)
	m.set_shader_parameter("u_discA", g.discA)
	m.set_shader_parameter("u_discB", g.discB)
	m.set_shader_parameter("u_hor", g.hor)
	m.set_shader_parameter("u_knotMap", g.knotMap)
	m.set_shader_parameter("u_k", ChartSky.K0)
	m.set_shader_parameter("u_ext", EXT)
	m.set_shader_parameter("u_rmax", RMAX)
	m.set_shader_parameter("u_H0", 0.11)
	m.set_shader_parameter("u_exp", EXPOSURE)
	m.set_shader_parameter("u_burn", BURN)
	m.set_shader_parameter("u_youngCol", L.young)
	m.set_shader_parameter("u_bCore", L.bCore)
	m.set_shader_parameter("u_bInner", L.bInner)
	m.set_shader_parameter("u_bOuter", L.bOuter)
	m.set_shader_parameter("u_oldIn", L.oldIn)
	m.set_shader_parameter("u_oldOut", L.oldOut)
	m.set_shader_parameter("u_bulge", L.bulge)
	m.set_shader_parameter("u_bulgeI", L.bulgeI)
	m.set_shader_parameter("u_halo", L.halo)
	m.set_shader_parameter("u_haloFall", L.get("haloFall", HALO_FALL))
	m.set_shader_parameter("u_discK", L.discK)
	m.set_shader_parameter("u_gasK", L.gasK)
	m.set_shader_parameter("u_nebK", Vector4(13.0, 15.0, 7.0, 16.0))
	m.set_shader_parameter("u_steps", 8.0 if DisplaySettings.graphics_low else STEPS)
	m.set_shader_parameter("u_holeR", ChartSky.hole_of(p))
	m.set_shader_parameter("u_holeLight", Vector3(0.9, 0.42, 0.14))
	# (a ball keeps its young gas's own light whole: a blue compact dwarf's outskirts
	# are that gas, and at A's quarter they ended in a rim)
	m.set_shader_parameter("u_drama", ball_drama(0.0) if L.ell else DRAMA)
	m.set_shader_parameter("u_dramaR", Vector4(DRAMA_R.x, DRAMA_R.y, DRAMA_BALL.y, DRAMA_R.w) if L.ell else DRAMA_R)
	m.set_shader_parameter("u_gr", GOD_RAYS)
	m.set_shader_parameter("u_amb", Vector3.ZERO)
	var cl := cloud_uniforms(g.clouds)
	for k in cl:
		m.set_shader_parameter(k, cl[k])


## Named clouds as the place pass marches them: centre, radius, kind, lobes and a seed.
static func cloud_uniforms(clouds: Array) -> Dictionary:
	var A := PackedVector4Array()
	var B := PackedVector4Array()
	var C := PackedVector4Array()
	var Lb := PackedVector4Array()
	for c: Dictionary in clouds:
		if A.size() >= 8:
			break
		# SIMPLIFIED numbers the kinds emission, reflection, remnant, planetary, dark;
		# the showcase's A emission, reflection, planetary, remnant, dark
		var kind: int = [0, 1, 3, 2, 4][int(c.kind)]
		var lobes: Array = c.lobes
		# (the main lobe is the biggest, as the showcase's A took it)
		var main: Vector3 = lobes[0]
		for l: Vector3 in lobes:
			if l.z > main.z:
				main = l
		var rb := 0.0
		for l: Vector3 in lobes:
			rb = maxf(rb, Vector2(l.x, l.y * FLAT).length() + l.z * 1.15)
		var cz := rb * 0.32
		var shell := 0.0
		var reach: float = c.reach
		if kind == 3:
			shell = reach
			rb = shell * 1.3
			cz = shell * 0.82 * 1.3
		elif kind == 2:
			shell = reach
			rb = shell * (1.9 if int(c.shape) == 3 else 1.75)
			cz = shell * 0.5 * 1.75
		var xy: Vector2 = c.xy
		A.append(Vector4(xy.x, xy.y, rb, float(kind)))
		B.append(Vector4(cz, shell, float(c.hollow), fmod(float(c.seed), 10.0)))
		# Cluster stays at the biggest lobe; the faint teal heart was the lobes, not this.
		# Why: docs/why/ChartRadiant.md#cloud-lobes
		var cl0 := Vector2(main.x, main.y * FLAT)
		C.append(Vector4(cl0.x, cl0.y, float(c.shape), shell if (kind == 2 or kind == 3) else float(c.radius)))
		for j in 3:
			var l: Vector3 = lobes[j] if j < lobes.size() else Vector3.ZERO
			# (SIMPLIFIED pads a cloud's lobes to three with copies: a copy counts once)
			var dup := false
			for jj in j:
				dup = dup or lobes[jj] == l
			if kind == 2 or kind == 3 or dup:
				Lb.append(Vector4.ZERO)
			else:
				Lb.append(Vector4(l.x, l.y * FLAT, l.z, 0.0))
	var n := A.size()
	A.resize(8)
	B.resize(8)
	C.resize(8)
	Lb.resize(24)
	return {"u_nCl": n, "u_clA": A, "u_clB": B, "u_clC": C, "u_lobe": Lb}


## Events at time t, all as light the volume scatters: knots, supernova, echo, lightning.
static func feed_events(m: ShaderMaterial, g: Dictionary, t: float, calm: bool, live: bool) -> void:
	var knots: Array = g.knots
	var kn := PackedVector4Array()
	for i in knots.size():
		var xy: Vector2 = knots[i].xy
		kn.append(Vector4(xy.x, xy.y, float(knots[i].size), ChartSky._knot_amp(knots, i, t, calm or not live)))
	m.set_shader_parameter("u_nkn", knots.size())
	kn.resize(ChartSky.MAX_KN)
	m.set_shader_parameter("u_kn", kn)
	var sv: Dictionary = {} if not live else ChartSky.supernova_at(g.sn_cand, t, calm)
	if sv.is_empty():
		m.set_shader_parameter("u_sn", Vector4.ZERO)
		m.set_shader_parameter("u_echo", Vector4.ZERO)
	else:
		var xy: Vector2 = sv.xy
		m.set_shader_parameter("u_sn", Vector4(xy.x, xy.y, float(sv.g), float(sv.age)))
		m.set_shader_parameter("u_echo", Vector4(xy.x, xy.y, 0.004 * float(sv.age), float(sv.echo)))
	var lt := PackedVector4Array()
	var n := 0
	for c: Dictionary in g.clouds:
		if n >= 8:
			break
		lt.append(Vector4.ZERO if (calm or not live) else _flash(c, t))
		n += 1
	lt.resize(8)
	m.set_shader_parameter("u_lt", lt)
	# TORN AWAY: the clouds over the dwarf torn with it, in this style's order (after
	# SIMPLIFIED's, which holds them sorted on the screen; `ChartTorn.cloud_tear`)
	var txy: Array = []
	var trc: Array = []
	for c: Dictionary in g.clouds:
		if txy.size() >= 8:
			break
		txy.append(c.xy)
		trc.append(float(c.reach))
	var tear := ChartTorn.cloud_arrays(txy, trc, ChartTorn.last_phi, ChartSky.MAX_CL)
	m.set_shader_parameter("u_tornCl", tear.u_tornCl)
	m.set_shader_parameter("u_tornClD", tear.u_tornClD)
	# `feed_events` restores this style's lobes after SIMPLIFIED's overwrote them per frame.
	# Why: docs/why/ChartRadiant.md#cloud-lobes
	if not g.has("r_lobe"):
		g["r_lobe"] = cloud_uniforms(g.clouds).u_lobe
	m.set_shader_parameter("u_lobe", g.r_lobe)
	feed_drama(m, g, t, calm or not live)


# ------------------------------------------------------------------ light that moves

## LIGHT THAT MOVES (Nov 7, B): the core breathes and flares, young stars flare;
## pure functions of the clock; `drama_on` false or `still`: all off.
## Why: docs/why/ChartRadiant.md#light-that-moves
static var drama_on := true
## The core: its breath's period (s), the slot a flare may fall in (s) and how often
## one does, a flare's rise, hold and fall (s). (Jon, Nov 7: "the core could also
## flare less often": the slot 11 to 22 s, so about 2 flares a minute, not 3.9; each
## flare keeps its look, size and envelope, and the breath is untouched.)
const CORE_BREATH_S := 5.3
const CORE_SLOT_S := 22.0
const CORE_FLARE_P := 0.7
const CORE_ENV := Vector3(0.5, 1.1, 2.8)
## The young stars: slots (one star each), the first slot's period and each next one's
## more, how often a slot's turn flares, a flare's rise, hold and fall, its reach (gu).
## (Jon, Nov 7, RC:1B: the young stars flash half as often, 0.8 to 0.4 of turns. At
## 0.8 the chart at rest changed 11% of its pixels a second against A's 2%; each
## flare keeps its look.)
const STAR_SLOTS := 6
const STAR_PERIOD := Vector2(6.5, 1.3)
const STAR_P := 0.4
const STAR_ENV := Vector3(0.25, 0.55, 1.9)
const STAR_REACH := 0.035


## THE SUN'S FLARES in RADIANT (the sector map and LOCAL, `SystemView`, `LocalSky`):
## far more often than the prominences every style shares (one in 40 s), each eased in,
## held and let go -- its glow swells, its haze and its light run out across the cloud,
## the worlds' day sides brighten, LOCAL's band lets more of it through. The slot a
## flare may fall in (s), how often one does, its rise, hold and fall (s).
const SUN_SLOT_S := 9.0
const SUN_FLARE_P := 0.7
const SUN_ENV := Vector3(0.45, 0.9, 2.8)


## The sun's flare at t, 0..1 (`salt` a second sun's own clock). None under reduced motion.
static func sun_flare(t: float, salt: int = 0) -> float:
	if DisplaySettings.reduced_motion or not drama_on:
		return 0.0
	var n0 := floori(t / SUN_SLOT_S)
	var fl := 0.0
	for n in range(n0 - 1, n0 + 1):
		if LegacyHole.hash01(n, 1011 + salt) > SUN_FLARE_P:
			continue
		var t0 := SUN_SLOT_S * n + (SUN_SLOT_S - SUN_ENV.x - SUN_ENV.y - SUN_ENV.z) * LegacyHole.hash01(n, 1012 + salt)
		fl = maxf(fl, ease_hold(t - t0, SUN_ENV) * (0.7 + 0.3 * LegacyHole.hash01(n, 1013 + salt)))
	return fl


## An event's envelope at `age` s: eased up over rise, held, eased down over fall.
static func ease_hold(age: float, e: Vector3) -> float:
	if age < 0.0 or age > e.x + e.y + e.z:
		return 0.0
	if age < e.x:
		return smoothstep(0.0, e.x, age)
	if age < e.x + e.y:
		return 1.0
	return 1.0 - smoothstep(0.0, e.z, age - e.x - e.y)


## The core's clock at t: (breath -1..1, flare 0..1, 0, 0).
static func core_clock(t: float) -> Vector4:
	var n0 := floori(t / CORE_SLOT_S)
	var fl := 0.0
	for n in range(n0 - 1, n0 + 1):
		if LegacyHole.hash01(n, 811) > CORE_FLARE_P:
			continue
		var t0 := CORE_SLOT_S * n + (CORE_SLOT_S - CORE_ENV.x - CORE_ENV.y - CORE_ENV.z) * LegacyHole.hash01(n, 812)
		fl = maxf(fl, ease_hold(t - t0, CORE_ENV) * (0.75 + 0.25 * LegacyHole.hash01(n, 813)))
	var br := sin(t * TAU / CORE_BREATH_S)
	return Vector4(br, fl, 0.0, 0.0)


## Where a young star flares, slot k's n-th turn (plane gu): on a knot when the galaxy
## has them (the arms' star-forming fronts), else anywhere in a ball's body or on a disc.
static func star_spot(g: Dictionary, k: int, n: int) -> Vector2:
	var knots: Array = g.get("knots", [])
	var j := LegacyHole.hash01(n, 900 + k)
	var jx := LegacyHole.hash01(n, 920 + k) - 0.5
	var jy := LegacyHole.hash01(n, 940 + k) - 0.5
	if not knots.is_empty():
		var kn: Dictionary = knots[int(j * knots.size()) % knots.size()]
		return (kn.xy as Vector2) + Vector2(jx, jy) * 0.03
	var p: Dictionary = g.p
	var r := 0.0
	if int(p.form) == 1:
		r = float((p.ball as Vector4).x) * 0.7 * sqrt(LegacyHole.hash01(n, 960 + k))
	else:
		r = 0.15 + 0.7 * LegacyHole.hash01(n, 960 + k)
	var a := TAU * j
	return Vector2(cos(a), sin(a)) * r


static func feed_drama(m: ShaderMaterial, g: Dictionary, t: float, still: bool) -> void:
	var st := PackedVector4Array()
	st.resize(STAR_SLOTS)
	if still or not drama_on:
		m.set_shader_parameter("u_rbCore", Vector4.ZERO)
		m.set_shader_parameter("u_rbStar", st)
		return
	m.set_shader_parameter("u_rbCore", core_clock(t))
	for k in STAR_SLOTS:
		var per := STAR_PERIOD.x + STAR_PERIOD.y * k
		var n := floori(t / per)
		if LegacyHole.hash01(n, 880 + k) > STAR_P:
			continue
		var t0 := per * n + (per - STAR_ENV.x - STAR_ENV.y - STAR_ENV.z) * LegacyHole.hash01(n, 860 + k)
		var e := ease_hold(t - t0, STAR_ENV)
		if e <= 0.0:
			continue
		var xy := star_spot(g, k, n)
		st[k] = Vector4(xy.x, xy.y, e * (0.7 + 0.3 * LegacyHole.hash01(n, 870 + k)), STAR_REACH)
	m.set_shader_parameter("u_rbStar", st)


## Lightning follows SIMPLIFIED's schedule: a flash in most ten-second slots, 2 or 3 pulses.
static func _flash(c: Dictionary, t: float) -> Vector4:
	var kind: int = c.kind
	if kind != 0 and kind != 4:
		return Vector4.ZERO
	var s: int = int(c.i) * 13
	var n0 := floori(t / 10.0)
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
		var lobes: Array = c.lobes
		var lb: Vector3 = lobes[int(LegacyHole.hash01(n, 505 + s) * 3.0) % lobes.size()]
		var at := Vector2(lb.x + (LegacyHole.hash01(n, 606 + s) - 0.5) * lb.z,
			(lb.y + (LegacyHole.hash01(n, 707 + s) - 0.5) * lb.z) * FLAT)
		return Vector4(env, at.x, at.y, 0.3 * float(c.radius))
	return Vector4.ZERO
