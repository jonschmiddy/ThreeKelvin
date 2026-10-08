class_name ChartRadiant
extends RefCounted

## THE STAR CHART'S SKY IN THE RADIANT STYLE (`DisplaySettings.render_style`
## `&"radiant"`, or a harness's `style=radiant`): direction A of the Oct 5
## showcase, "Light through gas" (scratchpad `showcase/A/chart/`). The galaxy as
## a true density volume lit by single scattering from the core, the arms' young
## stars and the clouds' lamps; dust that reddens and stops light; god rays cut
## through the haze by the billows; billows lit on the side facing the core and
## in their own shade on the other; the near dust lane in silhouette over the
## bulge. SIMPLIFIED's black hole (`legacy_hole`), lit as this style lights
## things, and SIMPLIFIED's animations as light: the gas streaming through the
## arms, knots that breathe as lamps, a supernova that lights the gas round it
## and an echo of it sweeping through the dust, lightning that scatters through
## its cloud. Jon: RADIANT is "for photos probably" -- it is the HEAVY style.
##
## It runs on `ChartSky`'s own pipeline (its stars, its palette cut from hero
## views, its composite and zoom hold), with its own bakes and place pass:
##   * the BAKES, once a galaxy (once a session for the noise): a periodic 3D
##     noise volume (`chart_r_bake_noise`), the face-on disc as two half-float
##     maps (`chart_r_bake_disc`: star light, young light, H-alpha, dust; arm gas,
##     billow height, blockers, core swirl), read back and mip-mapped, then the
##     core's horizon map from them (`chart_r_bake_hor`, the god rays' shadows);
##   * the PLACE pass (`chart_r_place`), a march down each block's view ray.
## LOW (GRAPHICS LOW) marches no billows (one lit sheet), fewer steps, one phase.
##
## THE SAFETY: if the sky's own GPU time over its first seconds says this
## machine cannot hold it, the chart falls back to SIMPLIFIED with one line in
## the log (`ChartSky._radiant_probe`).

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
const VIB := 0.35
## A lobe's dy is in the chart's flattened frame; this takes it to the plane.
const FLAT := 0.46341 / 0.38
## THE SAFETY'S BUDGET: the sky's own GPU time, ms a frame, averaged over its
## first seconds of drawing; past it the chart falls back to SIMPLIFIED. An RTX
## 3070 measures 0.6-1.6 here; a machine at four times that is not one to show
## photos on.
const FALLBACK_MS := 6.0
## The slab's march: steps through it (halved near the plane), HIGH. The
## showcase's 22 cost 2.5 ms a frame on a full-screen chart at zoom 1 on an RTX
## 3070; 16, with the start jittered, reads the same.
const STEPS := 11.0
## How near (OKLab) a colour the palette's cut may add to one already kept;
## SIMPLIFIED's is 0.06 (`ChartSky.pal_merge`). Measured on the nebula's slow
## zoom: 0.06 left a fan of rose twins across the remnant's shell that flickered.
static var PAL_MERGE := 0.02
## The composite's dither gates, against SIMPLIFIED's (`ChartSky.dith_gs`,
## `dith_coh`). 1: the same; the colour hold (`ChartSky.hyst`) keeps the dither
## from flickering, so it can carry the soft gradients light through gas makes
## (2 and 1.25 had flattened them into plates).
const DITH_GS := 0.5
const DITH_COH := 0.8
## How many colours the palette's cut adds to the reserved ones (the showcase's
## A spent 56 colours in all; a cut of 12 drew the haze in grey plates).
const PAL_FREE := 40
## How many drawn frames the safety averages (after a few to settle).
const PROBE_FRAMES := 90

## The noise volume: the same for every galaxy, baked once a session.
static var _noise: ImageTexture = null
## The safety has fallen back this session: RADIANT is not drawn again until
## the player chooses it again.
static var fell_back := false


## The colours every radiant palette keeps (the showcase's A): the void and the
## navy steps above it, the hole's bands, and the key hues as the tone maps them
## at several lights -- H-alpha, OIII, the remnant's red, the reflection's blue --
## so small vivid things are never starved by the cut.
static func fixed_palette() -> PackedColorArray:
	var out := PackedColorArray()
	for h in ["#070a12", "#0b1020", "#0f1529", "#141b33"]:
		out.append(Color(h))
	for i in range(1, 8):
		out.append(LegacyHole.PALETTE[i])
	var ramps := [[Vector3(1.0, 0.2, 0.3), [0.15, 0.4, 0.9, 1.7]], [Vector3(0.2, 0.95, 0.85), [0.25, 0.7, 1.5]],
		[Vector3(1.0, 0.16, 0.13), [0.3, 0.9]], [Vector3(0.32, 0.52, 1.0), [0.15, 0.45, 1.0]]]
	# (no bulge ramp: the cut takes the bulge's tans from what is on screen; a
	# reserved amber drew a saturated orange ring round every elliptical)
	for r: Array in ramps:
		var col: Vector3 = r[0]
		for m: float in r[1]:
			var h := col * m
			var mx := maxf(h.x, maxf(h.y, h.z))
			var c := h * ((1.0 - exp(-mx)) / mx)
			out.append(Color(ChartSky._l2s(c.x), ChartSky._l2s(c.y), ChartSky._l2s(c.z)))
	return out


## Whether a chart draws in the radiant style: the player's style, or a
## harness's `style=radiant` while RADIANT is not built (DisplaySettings will not
## take a style it cannot draw everywhere; the chart can, so a shot can ask).
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


## The galaxy's look: the showcase's per-kind numbers (set by eye for the
## grand design, the barred spiral and the elliptical), generalised by shape and
## by the galaxy's own bulge, gas and arms.
static func look(p: Dictionary) -> Dictionary:
	var form: int = p.form
	var br: float = p.bulge_r
	var ell := form == 1
	var ball: Vector4 = p.ball
	var pals: Array = ChartLegacy._gas_palette(float(p.gas))
	var blue: Vector3 = pals[0]
	var arms := int(p.arms)
	var chaos: float = p.chaos
	var arm_k := 0.0
	if arms > 0:
		arm_k = clampf(1.0 - chaos * 1.8, 0.35, 1.0) * (0.75 if arms >= 5 else 1.0)
	var L := {}
	if ell:
		var re: float = ball.x
		L.bulge = Vector4(0.23 * re, 1.0 * re, 0.72, 0.08 * re)
		L.peaks = Vector4(1.5, 0.95 * clampf(float(ball.z) / 0.085, 0.4, 1.3), 0.25, 1.4)
		L.halo = Vector4(0.03, maxf(0.3, 1.4 * re), 0.72, 1.0)
		# (no disc under a ball: the showcase's faint one drew a flat plate with a
		# hard rim round the small ones)
		L.discK = Vector4(0.0, 0.0, 0.0, 0.0)
		L.gasK = Vector4(34.0, 0.0, 0.6, 0.2)
		L.rd = 0.3
		L.young = Vector3(0.8, 0.85, 1.0)
		L.oldIn = Vector3(1.0, 0.8, 0.56)
		L.oldOut = Vector3(0.95, 0.78, 0.6)
	else:
		# (the showcase's two spirals: 0.04 / 0.13 / 0.02 gu at bulge 0.128 and
		# 0.045 / 0.155 / 0.022 at 0.187: the bulge's light grows slower than its
		# radius, or a big bulge washed over the billows round it)
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
		L.halo = Vector4(L.halo.x, L.halo.y, L.halo.z, 0.0)
	L.arm_k = arm_k
	L.gas = 0.0 if ell else float(p.gas)
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
		out.append(sky._pass_vp(holder, Vector2i(DISC_N, DISC_N), ChartSky._rect(m), true))
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
	out.append(sky._pass_vp(holder, Vector2i(512, 512), ChartSky._rect(mk), false))
	if _noise == null:
		var mn := ShaderMaterial.new()
		mn.shader = NOISE_SH
		out.append(sky._pass_vp(holder, Vector2i(528, 528), ChartSky._rect(mn), true))
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
	if imgs.size() > 3:
		_noise = ImageTexture.create_from_image(imgs[3])
	g["noise_r"] = _noise
	for vp: SubViewport in vps:
		vp.queue_free()
	var m := ShaderMaterial.new()
	m.shader = HOR_SH
	feed_common(m, g.p, g.look)
	m.set_shader_parameter("u_rmax", RMAX)
	m.set_shader_parameter("u_ext", EXT)
	m.set_shader_parameter("u_discB", g.discB)
	return sky._pass_vp(holder, HOR_SIZE, ChartSky._rect(m), true)


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
	m.set_shader_parameter("u_discK", L.discK)
	m.set_shader_parameter("u_gasK", L.gasK)
	m.set_shader_parameter("u_nebK", Vector4(13.0, 15.0, 7.0, 16.0))
	m.set_shader_parameter("u_steps", 8.0 if DisplaySettings.graphics_low else STEPS)
	m.set_shader_parameter("u_holeR", float(p.hole_r))
	m.set_shader_parameter("u_holeLight", Vector3(0.9, 0.42, 0.14))
	var cl := cloud_uniforms(g.clouds)
	for k in cl:
		m.set_shader_parameter(k, cl[k])


## The named clouds as the place pass marches them (the showcase's format): the
## plane centre, a bounding radius and the kind; a half height, a shell radius,
## the hollowness and a seed; the main lobe (the emission's ionising cluster,
## the reflection's lamp), the shape and a size; the lobes in the plane.
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
		# (an emission cloud's cluster at its biggest lobe, as the showcase's A had it.
		# It was moved 0.6 of the way in when the teal heart barely showed on the
		# Starburst Spiral, but the cause was the lobes: `feed_events` puts this
		# style's own back, which SIMPLIFIED's had been overwriting)
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


## The events at time t (after `ChartSky._feed_events` has fed the shared ones):
## the knots' breathing, a supernova and its echo in the plane, lightning in the
## emission and dark clouds -- all as light the volume scatters.
static func feed_events(m: ShaderMaterial, g: Dictionary, t: float, calm: bool, live: bool) -> void:
	var knots: Array = g.knots
	var kn := PackedVector4Array()
	for i in knots.size():
		var xy: Vector2 = knots[i].xy
		kn.append(Vector4(xy.x, xy.y, float(knots[i].size), ChartSky._knot_amp(knots, i, t, calm or not live)))
	m.set_shader_parameter("u_nkn", knots.size())
	kn.resize(ChartSky.MAX_KN)
	m.set_shader_parameter("u_kn", kn)
	var sv: Dictionary = {} if not live else ChartSky._supernova(g.sn_cand, t, calm)
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
	# THE CLOUDS' OWN LOBES AGAIN. `ChartSky._feed_events` runs first, every frame
	# and for every palette probe, and sets the same `u_lobe` to SIMPLIFIED's: its
	# clouds sorted by where they sit on screen and their lobes turned into each
	# cloud's round frame. Read here, cloud k took another cloud's lobes, turned
	# -- so an emission cloud's gas lay off its own cluster and its teal heart
	# (the cavity round the cluster) sat at the thin edge of the wrong gas, or
	# outside it (the Starburst's ESO 101 shown as emission: a flat rose band
	# with a sliver of teal, where the showcase's A has a teal heart).
	if not g.has("r_lobe"):
		g["r_lobe"] = cloud_uniforms(g.clouds).u_lobe
	m.set_shader_parameter("u_lobe", g.r_lobe)


## Distant lightning in an emission or dark cloud (SIMPLIFIED's schedule): a
## flash in most ten-second slots, two or three pulses (80 ms rise, 250 ms
## decay, 120 ms apart), at a point of one of its lobes. (envelope, plane offset
## x, y from the cloud's centre, the light's reach) or none.
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
