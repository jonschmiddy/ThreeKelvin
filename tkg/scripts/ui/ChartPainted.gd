class_name ChartPainted
extends RefCounted

## THE STAR CHART IN THE PAINTED STYLE: direction B of the Oct 5 showcase
## (scratchpad `showcase/B/chart/`, "a pixel artist's hand"), drawn by `ChartSky`
## when the rendering style is PAINTED. Every pixel looks placed on purpose:
## cel-banded light from the core on curated hue-shifted ramps, 1-block checker
## transitions between bands, outlines on the shadow side of big shapes and a
## rim of light on their lit side, see-through gas as 25/50/75% patterns (never
## alpha), sparkle sprites, and a band memory so band edges do not flicker.
## It shares the simplified chart's view, anchoring and zoom hold (`ChartSky._push`),
## its black hole (C's, `legacy_hole.gdshaderinc`) and its life -- the currents,
## the knots, the supernova and its echo, the weather -- drawn here as hand
## animation: held poses that step, slow, never a one-frame flash.
##
## Four passes a frame, each one block a pixel: the sparkles (`chart_b_stars`),
## the G-buffer (`chart_b_place`: what every block is and how lit), the band
## memory (`chart_b_state`) and the paint (`chart_b_paint`). Baked once a galaxy:
## the billow puff table (`chart_b_bake`, two 120 x 120 float textures, read back)
## and the stars as data. The palette is curated, the same table the painted
## sector map uses (bible 4.2): nothing is cut.

const BAKE_SH := preload("res://shaders/chart_b_bake.gdshader")
const PLACE_SH := preload("res://shaders/chart_b_place.gdshader")
const PLACE_LOW_SH := preload("res://shaders/chart_b_place_low.gdshader")
const STARS_SH := preload("res://shaders/chart_b_stars.gdshader")
const STATE_SH := preload("res://shaders/chart_b_state.gdshader")
const PAINT_SH := preload("res://shaders/chart_b_paint.gdshader")

## THE CURATED PALETTE (bible 4.2), ramps darkest first, by material id (the
## G-buffer's R). Shadows turn toward blue-violet, lights toward warm yellow.
const RAMPS: Array = [
	["#070a12", "#0b1020", "#121a30"],                                     # 0 sky
	["#0f1230", "#1d2a5c", "#2f4c91", "#4f7bc6", "#86b2e8", "#cfe6fb"],    # 1 arm blue
	["#4a1638", "#9c3266", "#e2678f", "#ffb3c4"],                          # 2 knots
	["#2a0d1e", "#5e1c1e", "#9c3a1e", "#d26a26", "#f0a040", "#fbd27a", "#fff3d0"],   # 3 bulge
	["#08060c", "#140d14", "#26171a", "#3e2620"],                          # 4 dust
	["#141228", "#2b2142", "#50345a", "#8a5062", "#c87b62", "#f1b583"],    # 5 billow gas
	["#2e0a22", "#6b1434", "#b8274a", "#ef5068", "#ff9c9a"],               # 6 H-alpha
	["#0b2f3a", "#157a7e", "#38c4ad", "#a6f5df"],                          # 7 OIII
	["#0d1638", "#1c3478", "#3462bf", "#6a9cf0", "#bcd8ff"],               # 8 reflection
	["#08060c", "#140d14", "#26171a", "#3e2620"],                          # 9 pillar
	["#0b1020", "#121a30", "#1d2a5c", "#2b2142", "#50345a"],               # 10 halo
	["#08060c", "#140d14", "#26171a", "#3e2620"],                          # 11 dark cloud
	["#1e0804", "#4a1406", "#84280c", "#c24a14", "#ec7a26", "#ffb054", "#ffdc96", "#fff6e2"],   # 12 the hole (C's own bands)
	["#4f7bc6", "#86b2e8", "#d6e4ff", "#fff6e2"],                          # 13 star, cool
	["#d26a26", "#f0a040", "#ffd8a0", "#fff6e2"],                          # 14 star, warm
	["#9c3a1e", "#c24a14", "#ff9e6a", "#ffd8a0"],                          # 15 star, red
	["#9c3266", "#e2678f", "#ffb3c4", "#fff6e2"],                          # 16 star, pink
	["#121a30", "#2b2142", "#50345a", "#8a5062", "#c87b62", "#f1b583"],    # 17 ball
	["#8a84d0", "#d8d0ff", "#fff6e2"],                                     # 18 a lightning bolt (C's violet-white)
]
## The lit-side rim and the shadow-side outline of a material's big shapes.
const RIM := {4: "#8a5062", 5: "#f1b583", 9: "#ff9c9a", 11: "#c87b62", 1: "#cfe6fb"}
const OUTLINE := {1: "#0f1230", 6: "#2e0a22", 8: "#0d1638"}
## Materials whose bands meet without a checker (sparkles and the bolt are crisp).
const NOTRANS := [13, 14, 15, 16, 18]

static var _tables: Dictionary = {}


## The palette and its lookups, built once: the palette texture, the ramp entry
## -> palette index table, each material's start and length, its rim and
## outline, whether it checkers, and the OKLab lightness of every ramp entry
## (the place pass compares layers by it).
static func tables() -> Dictionary:
	if not _tables.is_empty():
		return _tables
	var pal: Array[Color] = []
	var index := {}
	var add := func(h: String) -> int:
		var key := h.to_lower()
		if not index.has(key):
			index[key] = pal.size()
			pal.append(Color(key))
		return index[key]
	for h in ["#070a12", "#fff6e2", "#ffd8a0", "#d6e4ff", "#ff9e6a"]:
		add.call(h)
	var idx := PackedInt32Array()
	var mstart := PackedInt32Array()
	var mlen := PackedInt32Array()
	var trans := PackedInt32Array()
	mstart.resize(24)
	mlen.resize(24)
	trans.resize(24)
	for m in RAMPS.size():
		mstart[m] = idx.size()
		mlen[m] = (RAMPS[m] as Array).size()
		trans[m] = 0 if NOTRANS.has(m) else 1
		for h: String in RAMPS[m]:
			idx.append(add.call(h))
	var rim := PackedInt32Array()
	var outl := PackedInt32Array()
	rim.resize(24)
	outl.resize(24)
	rim.fill(-1)
	outl.fill(-1)
	for m: int in RIM:
		rim[m] = add.call(RIM[m])
	for m: int in OUTLINE:
		outl[m] = add.call(OUTLINE[m])
	var Y := PackedFloat32Array()
	Y.resize(96)
	for i in idx.size():
		Y[i] = ChartSky._oklab(pal[idx[i]]).x
	idx.resize(96)
	var img := Image.create(64, 1, false, Image.FORMAT_RGBA8)
	for i in mini(64, pal.size()):
		img.set_pixel(i, 0, pal[i])
	_tables = {"pal": ImageTexture.create_from_image(img), "idx": idx, "mstart": mstart, "mlen": mlen,
		"rim": rim, "out": outl, "trans": trans, "Y": Y, "n": pal.size()}
	return _tables


## Whether a chart draws in the painted style: the player's style, or a harness's
## `style=painted` while PAINTED is not built yet (DisplaySettings will not take
## a style it cannot draw everywhere; the chart can, so a shot can ask for it).
static func wanted() -> bool:
	return DisplaySettings.render_style == &"painted" or "style=painted" in OS.get_cmdline_user_args()


# ------------------------------------------------------------------ the bake

## The galaxy's constants as the painted pass reads them (the showcase's G0-G7,
## and G8 for what every kind needs beyond its three).
static func galaxy_uniforms(p: Dictionary) -> Dictionary:
	var g: Dictionary = Run.galaxy
	var form: int = p.form
	var arms := int(p.arms)
	var chaos: float = p.chaos
	var arm_k := 0.0
	if form == 0 and arms > 0:
		arm_k = clampf(1.0 - chaos * 1.8, 0.35, 1.0) * (0.75 if arms >= 5 else 1.0)
	var ball: Vector4 = p.ball
	return {
		"u_g0": Vector4(float(maxi(arms, 1)), float(p.twist), float(p.bar), float(p.spread)),
		"u_g1": Vector4(float(p.spin), arm_k, float(p.lane), float(p.gas)),
		"u_g2": Vector4(float(g.get("dust", 1.6)), float(p.bulge_r), ball.y if form == 1 else 0.86, float(p.hole_r)),
		"u_g3": Vector4(1.0 if form == 1 else 0.0, ball.y, float(p.hole_r) * ChartSky.DISC_K, float(Run.galaxy_kind) * 0.137),
		"u_g4": Vector4(0.102, 0.0, 0.0, 0.18),
		"u_g5": Vector4(0.5 if float(p.bar) > 0.0 else 0.6, 0.4, 0.35, 1.6),
		"u_g6": Vector4(0.12, 0.06, 1.25, 0.8),
		"u_g7": Vector4(0.4, 0.72, 0.16, 0.7 if arms == 2 else 0.0),
		"u_g8": Vector4(ball.x, ball.z / 0.085, chaos, 1.0 if p.tail else 0.0),
	}


## The named clouds as uniform arrays: plane centre and size, kind (NebulaField's
## own order is the painted pass's), hollowness, shape, the lobe its cluster
## sits in, and the lobes in the cloud's own round frame.
static func cloud_uniforms(p: Dictionary) -> Dictionary:
	var cl := PackedVector4Array()
	var ck := PackedVector4Array()
	var lb := PackedVector4Array()
	var sq: float = p.squash
	for raw in NebulaField.clouds():
		if cl.size() >= ChartSky.MAX_CL:
			break
		var c: NebulaField.Cloud = raw
		var reach := 0.0
		var big := 0
		for l in c.lobes.size():
			reach = maxf(reach, (c.lobes[l] as Vector2).length() + c.lobe_r[l] * NebulaField.EXTENT)
			if c.lobe_r[l] > c.lobe_r[big]:
				big = l
		cl.append(Vector4(c.pos.x, c.pos.y / sq, c.radius, reach))
		ck.append(Vector4(float(int(c.kind)), c.hollow, float(int(c.shape)), float(mini(big, 2))))
		for j in 3:
			if j < c.lobes.size():
				lb.append(Vector4(c.lobes[j].x, c.lobes[j].y, c.lobe_r[j], 0.0))
			else:
				lb.append(Vector4.ZERO)
	var n := cl.size()
	cl.resize(ChartSky.MAX_CL)
	ck.resize(ChartSky.MAX_CL)
	lb.resize(ChartSky.MAX_CL * 3)
	return {"u_ncl": n, "u_cl": cl, "u_ck": ck, "u_lb": lb, "clouds": n}


## The chart's star field as the painted sparkles read it: every point bright
## enough to be drawn alone, its colour class and sprite tier (the showcase's
## rule), dimmest first; then the globulars as knots and the pulsars.
static func star_data(sky: ChartSky, g: Dictionary, p: Dictionary) -> void:
	var src: Dictionary = sky._src
	var r_max: float = src.r_max
	var sq: float = p.squash
	var ball := int(p.form) == 1
	var rows: Array = []
	var pos: PackedVector2Array = src.pos
	var col: PackedColorArray = src.col
	var big: PackedByteArray = src.big
	var gi: PackedInt32Array = src.gi
	var glob_of := PackedInt32Array()
	glob_of.resize(pos.size())
	glob_of.fill(-1)
	for kk in gi.size() / 2:
		for j in range(gi[kk * 2], mini(gi[kk * 2 + 1], pos.size())):
			glob_of[j] = kk
	var add := func(pl: Vector2, c: Color, lum: float, kind: int, i: int) -> void:
		var h := LegacyHole.hash01(i, 0)
		var h2 := LegacyHole.hash01(i, 11)
		var h3 := LegacyHole.hash01(i, 12)
		var cls := 1
		if ball:
			cls = 0 if h3 < 0.12 else 1
		elif c.b > c.r * 1.04:
			cls = 0
		elif c.g > c.r * 0.72:
			cls = 1
		else:
			cls = 2
		var tier := 1
		if kind == 1 or kind == 2:
			tier = 2 if h2 < 0.01 else 1
		elif lum >= 170.0 and h2 < 0.03:
			tier = 3
		elif lum >= 120.0 and h2 < 0.12:
			tier = 2
		var hz := 0.0
		if ball:
			var rr := pl.length()
			hz = (h3 * 2.0 - 1.0) * 0.62 * sqrt(maxf(0.0, 0.9 - minf(0.9, rr * rr))) * rr * 1.2
		rows.append([lum, pl.x, pl.y, kind, cls, tier, h, hz, h2, h3, 0.0])
	var n := 0
	var cand := PackedVector2Array()
	for i in pos.size():
		if big[i] == 2:
			continue
		var c := col[i]
		if big[i] == 0 and maxf(c.r, maxf(c.g, c.b)) < 0.075:
			continue
		var lum := (0.3 * c.r + 0.59 * c.g + 0.11 * c.b) * 255.0
		if lum < 60.0:
			continue
		var pl := Vector2(pos[i].x / r_max, pos[i].y / r_max / sq)
		add.call(pl, c, lum, 2 if glob_of[i] >= 0 else 0, n)
		if glob_of[i] < 0 and pl.length() > 0.16 and pl.length() < 0.9:
			cand.append(pl)
		n += 1
	var cr: PackedFloat32Array = src.cr
	var ca: PackedFloat32Array = src.ca
	var cc: PackedColorArray = src.cc
	for i in cr.size():
		var c := cc[i]
		var lum := (0.3 * c.r + 0.59 * c.g + 0.11 * c.b) * 255.0
		if lum < 60.0:
			continue
		add.call(Vector2(cos(ca[i]) * cr[i], sin(ca[i]) * cr[i] / sq) / r_max, c, lum, 1, n)
		n += 1
	rows.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	var gcs: PackedVector2Array = src.gc
	for kk in gcs.size():
		var cnt := float(gi[kk * 2 + 1] - gi[kk * 2]) if kk * 2 + 1 < gi.size() else 60.0
		rows.append([0.0, gcs[kk].x / r_max, gcs[kk].y / r_max / sq, 4, 1, 2, 0.0, 0.0, 0.0, 0.0, cnt])
	var pulsars: PackedVector2Array = src.pulsar
	for pp in pulsars:
		rows.append([255.0, pp.x / r_max, pp.y / r_max / sq, 5, 0, 3, 0.0, 0.0, 0.0, 0.0, 0.0])
	var a := PackedFloat32Array()
	var b := PackedFloat32Array()
	var c3 := PackedFloat32Array()
	for row: Array in rows:
		a.append_array([row[1], row[2], row[0], float(row[3])])
		b.append_array([float(row[4]), float(row[5]), row[6], row[7]])
		c3.append_array([row[8], row[9], row[10], 0.0])
	g["b_n"] = rows.size()
	g["b_sn"] = cand
	g["b_a"] = ChartSky._data_tex(a, rows.size())
	g["b_b"] = ChartSky._data_tex(b, rows.size())
	g["b_c"] = ChartSky._data_tex(c3, rows.size())


## The puff table's two bake passes, queued.
static func begin_bake(sky: ChartSky, g: Dictionary, holder: Node) -> Array[SubViewport]:
	var p: Dictionary = g.p
	var gu := galaxy_uniforms(p)
	var cu := cloud_uniforms(p)
	g["gu"] = gu
	g["cu"] = cu
	star_data(sky, g, p)
	var PN := 120
	var PCS := 0.016
	var org := -float(PN) * PCS / 2.0
	g["puffP"] = Vector4(float(PN), PCS, org, org)
	var out: Array[SubViewport] = []
	for part in 2:
		var m := ShaderMaterial.new()
		m.shader = BAKE_SH
		for key in gu:
			m.set_shader_parameter(key, gu[key])
		for key in ["u_ncl", "u_cl", "u_ck", "u_lb"]:
			m.set_shader_parameter(key, cu[key])
		m.set_shader_parameter("u_phi", 0.0)
		m.set_shader_parameter("u_part", part)
		m.set_shader_parameter("u_puffP", g.puffP)
		out.append(sky._pass_vp(holder, Vector2i(PN, PN), ChartSky._rect(m), true))
	return out


## The puff table read back: the galaxy is ready (its palette needs no cut).
static func finish_bake(g: Dictionary, vps: Array) -> bool:
	var texs: Array[ImageTexture] = []
	for vp: SubViewport in vps:
		var img := vp.get_texture().get_image()
		if img == null:
			return false
		texs.append(ImageTexture.create_from_image(img))
	g["puffA"] = texs[0]
	g["puffB"] = texs[1]
	g["ready"] = true
	return true


# ------------------------------------------------------------------ the frame

## The four viewports, each one block a pixel, nested so each is drawn before
## the one that reads it: paint > band memory > place > sparkles.
static func runtime(sky: ChartSky, g: Dictionary) -> void:
	var T := tables()
	sky._low_now = DisplaySettings.graphics_low
	sky._vp = SubViewport.new()
	sky._vp.transparent_bg = false
	sky._vp.disable_3d = true
	sky._vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sky.add_child(sky._vp)
	sky._tvp = SubViewport.new()
	sky._tvp.transparent_bg = false
	sky._tvp.disable_3d = true
	sky._tvp.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
	sky._tvp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sky._vp.add_child(sky._tvp)
	sky._pvp = SubViewport.new()
	sky._pvp.transparent_bg = false
	sky._pvp.disable_3d = true
	sky._pvp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sky._tvp.add_child(sky._pvp)
	sky._svp = SubViewport.new()
	sky._svp.transparent_bg = true
	sky._svp.disable_3d = true
	sky._svp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	sky._svp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sky._pvp.add_child(sky._svp)
	var ms := ShaderMaterial.new()
	ms.shader = STARS_SH
	ms.set_shader_parameter("st_a", g.b_a)
	ms.set_shader_parameter("st_b", g.b_b)
	ms.set_shader_parameter("st_c", g.b_c)
	ms.set_shader_parameter("tex_w", StarchartScreen.MapChart.SKY_TEX_W)
	ms.set_shader_parameter("n_star", int(g.b_n))
	ms.set_shader_parameter("k", ChartSky.K0)
	ms.set_shader_parameter("bulge_r", float(g.p.bulge_r))
	sky._m_stars = ms
	sky._stars = ChartSky.MeshDraw.new()
	sky._stars.material = ms
	sky._stars.mesh = StarchartScreen.MapChart._quads(int(g.b_n))
	sky._svp.add_child(sky._stars)
	var mp := ShaderMaterial.new()
	mp.shader = PLACE_LOW_SH if sky._low_now else PLACE_SH
	LegacyHole.apply(mp, ChartSky.TILT)
	for key in g.gu:
		mp.set_shader_parameter(key, g.gu[key])
	for key in ["u_ncl", "u_cl", "u_ck", "u_lb"]:
		mp.set_shader_parameter(key, g.cu[key])
	mp.set_shader_parameter("u_k", ChartSky.K0)
	mp.set_shader_parameter("u_puffA", g.puffA)
	mp.set_shader_parameter("u_puffB", g.puffB)
	mp.set_shader_parameter("u_puffP", g.puffP)
	mp.set_shader_parameter("u_Y", T.Y)
	mp.set_shader_parameter("u_mstart", T.mstart)
	mp.set_shader_parameter("u_mlen", T.mlen)
	mp.set_shader_parameter("u_stars", sky._svp.get_texture())
	sky._m_place = mp
	sky._place = ChartSky._rect(mp)
	sky._pvp.add_child(sky._place)
	var mt := ShaderMaterial.new()
	mt.shader = STATE_SH
	mt.set_shader_parameter("gbuf", sky._pvp.get_texture())
	mt.set_shader_parameter("u_mlen", T.mlen)
	sky._m_state = mt
	sky._state = ChartSky._rect(mt)
	sky._tvp.add_child(sky._state)
	var mc := ShaderMaterial.new()
	mc.shader = PAINT_SH
	mc.set_shader_parameter("gbuf", sky._pvp.get_texture())
	mc.set_shader_parameter("state", sky._tvp.get_texture())
	mc.set_shader_parameter("pal", T.pal)
	mc.set_shader_parameter("u_idx", T.idx)
	mc.set_shader_parameter("u_mstart", T.mstart)
	mc.set_shader_parameter("u_mlen", T.mlen)
	mc.set_shader_parameter("u_rim", T.rim)
	mc.set_shader_parameter("u_out", T.out)
	mc.set_shader_parameter("u_trans", T.trans)
	sky._m_comp = mc
	sky._comp = ChartSky._rect(mc)
	sky._vp.add_child(sky._comp)
	sky._lut_on = true


## The band memory's longest hold, frames (`chart_b_state`), and while a zoom
## moves the frame's edge n blocks a frame, ZOOM_HOLD / n at most.
const HOLD := 40.0
const ZOOM_HOLD := 10.0


## Every frame: the view (worked out by ChartSky._push, shared with the simplified
## chart: the same anchoring and zoom hold), the clock and the events' poses.
static func push(sky: ChartSky, g: Dictionary, vs: Vector2, origin: Vector2, ccon: Vector2, res: Vector2,
		z: float, t: float, phi: float, b0: Vector2, resized: bool) -> void:
	var calm := DisplaySettings.reduced_motion
	var mp := sky._m_place
	mp.set_shader_parameter("u_vp_size", vs)
	mp.set_shader_parameter("u_vp_origin", origin)
	mp.set_shader_parameter("u_cpix", ccon)
	mp.set_shader_parameter("u_res", res)
	mp.set_shader_parameter("u_zoom", z)
	mp.set_shader_parameter("u_time", t)
	mp.set_shader_parameter("u_phi", phi)
	mp.set_shader_parameter("u_block0", b0)
	mp.set_shader_parameter("u_wxOn", 0.0 if calm else 1.0)
	mp.set_shader_parameter("u_flow", t * (0.5 if calm else 1.0))
	var gu4: Vector4 = g.gu.u_g4
	gu4.z = 1.0 if calm else 0.0
	mp.set_shader_parameter("u_g4", gu4)
	feed_events(mp, g, t, phi, calm)
	var ms := sky._m_stars
	ms.set_shader_parameter("vp_origin", origin)
	ms.set_shader_parameter("cpix", ccon)
	ms.set_shader_parameter("zoom", z)
	ms.set_shader_parameter("phi", phi)
	ms.set_shader_parameter("t", t)
	ms.set_shader_parameter("calm", 1.0 if calm else 0.0)
	var mt := sky._m_state
	mt.set_shader_parameter("vp_size", vs)
	mt.set_shader_parameter("block0", b0)
	# a resized memory holds nothing of the old picture: start it afresh
	mt.set_shader_parameter("reset", resized)
	# THE MEMORY TURNS WITH THE GALAXY: the frame's turn, and the view to undo it in
	# (last frame's turn, kept per frame like the view below: pushed twice in a
	# frame, the second push read the first's turn as last frame's and undid none)
	var fr := Engine.get_process_frames()
	if int(g.get("_view_fr", -1)) != fr:
		g["_view_fr"] = fr
		g["_phi_prev"] = g.get("_phi_cur", phi)
		g["_view_prev"] = g.get("_view_cur", [z, ccon, origin, b0])
	g["_phi_cur"] = phi
	var pd := wrapf(phi - float(g.get("_phi_prev", phi)), -PI, PI)
	mt.set_shader_parameter("phi_d", pd if absf(pd) < 0.2 else 0.0)
	mt.set_shader_parameter("origin", origin)
	mt.set_shader_parameter("cpix", ccon)
	mt.set_shader_parameter("zoom", z)
	# AND ZOOMS WITH IT: last frame's view, to find where each block's piece of
	# the galaxy was drawn (`chart_b_state`) -- the view the memory was last
	# DRAWN with, kept per frame: the chart can be pushed more than once a frame
	# (a glide's late push), and a second push would take the first's view for
	# last frame's and undo nothing
	g["_view_cur"] = [z, ccon, origin, b0]
	var pv: Array = g["_view_prev"]
	mt.set_shader_parameter("zoom0", float(pv[0]))
	mt.set_shader_parameter("cpix0", pv[1])
	mt.set_shader_parameter("origin0", pv[2])
	mt.set_shader_parameter("block00", pv[3])
	# AND WHAT A ZOOM CHANGES IS NOT HELD PAST IT: a zoom redraws the gas at a new
	# scale (its finest octaves fade in and out), so some bands truly change;
	# held through the zoom, they were let go in the second and a half after it
	# stopped, the cloud changing with nothing moving. The hold is cut by how far
	# the zoom moved the frame's edge this frame (blocks): a slow zoom -- the
	# flicker the memory is for, a third of a block a frame -- keeps about 30
	# frames of it, a turn of the wheel almost none, so what it changes changes
	# while it moves.
	var zmove := absf(log(maxf(z, 1e-4) / maxf(float(pv[0]), 1e-4))) * vs.length() * 0.5
	if not bool(g.get("_hold_fixed", false)):
		mt.set_shader_parameter("hold", HOLD if zmove < 1e-4 else minf(HOLD, ZOOM_HOLD / zmove))
	var mc := sky._m_comp
	mc.set_shader_parameter("vp_size", vs)
	mc.set_shader_parameter("block0", b0)
	sky._stars.queue_redraw()


## THE EVENTS AS HELD POSES, pure functions of t (the simplified chart's clocks,
## `ChartSky._supernova` and `_lightning`'s schedules, drawn by hand):
##   the supernova in four drawn frames (a spark, the full four-point star, a
##   shorter one, a fading plus) and its light echo as a ring stepping out every
##   1.5 s, in three strengths; a cloud's lightning as a bolt held for 0.35 s and
##   its afterglow for 0.6 s; the glimmers and shafts stepping a notch every 2 s.
static func feed_events(m: ShaderMaterial, g: Dictionary, t: float, phi: float, calm: bool) -> void:
	var sn: Dictionary = {} if calm else ChartSky._supernova(g.b_sn, t, false)
	if sn.is_empty():
		m.set_shader_parameter("u_sn", Vector4.ZERO)
		m.set_shader_parameter("u_echo", Vector4.ZERO)
	else:
		var age: float = sn.age
		var frame := 1 if age < 0.5 else (2 if age < 2.5 else (3 if age < 6.0 else (4 if age < 12.0 else 0)))
		var v := ChartSky._to_view(sn.xy, phi)
		m.set_shader_parameter("u_sn", Vector4(v.x, v.y, float(frame), 0.0))
		var step := floorf(age / 1.5) * 1.5
		var strength := 0.0
		if age > 1.5 and age < 36.0:
			# (two held steps and gone by 18 s: a late, faint step drew as a dashed
			# orange ring round the bulge with nothing to say what it was)
			strength = 3.0 if age < 8.0 else (2.0 if age < 18.0 else 0.0)
		m.set_shader_parameter("u_echo", Vector4(sn.xy.x, sn.xy.y, 0.004 * step, strength))
	var lt := PackedVector4Array()
	lt.resize(ChartSky.MAX_CL)
	if not calm:
		var i := 0
		for raw in NebulaField.clouds():
			if i >= ChartSky.MAX_CL:
				break
			var c: NebulaField.Cloud = raw
			if c.kind == NebulaField.Kind.EMISSION or c.kind == NebulaField.Kind.DARK:
				lt[i] = _bolt(c, i, t)
			i += 1
	m.set_shader_parameter("u_lt", lt)
	m.set_shader_parameter("u_glim", floorf(t / 2.0) * 0.3)
	m.set_shader_parameter("u_shaft", floorf(t / 2.0) * 0.12)


## A cloud's lightning, held: (pose 1 the bolt, 2 its afterglow, 0 none;
## round-frame x, y; the bolt's seed). The legacy schedule: a flash in most
## 10 s slots, at a point in one of the cloud's lobes.
static func _bolt(c: NebulaField.Cloud, i: int, t: float) -> Vector4:
	var s := i * 13
	var n0 := floori(t / 10.0)
	for n in range(n0 - 1, n0 + 2):
		if LegacyHole.hash01(n, 101 + s) > 0.8:
			continue
		var tf := 10.0 * n + 8.0 * LegacyHole.hash01(n, 202 + s) - 4.0
		var tau := t - tf
		if tau < 0.0 or tau >= 0.95:
			continue
		var j := int(LegacyHole.hash01(n, 505 + s) * float(c.lobes.size())) % maxi(1, c.lobes.size())
		var lo: Vector2 = c.lobes[j] if j < c.lobes.size() else Vector2.ZERO
		var lr: float = c.lobe_r[j] if j < c.lobe_r.size() else c.radius
		var at := lo + Vector2(LegacyHole.hash01(n, 606 + s) - 0.5, LegacyHole.hash01(n, 707 + s) - 0.4) * lr
		return Vector4(1.0 if tau < 0.35 else 2.0, at.x, at.y, float(n * 31 + i))
	return Vector4.ZERO
