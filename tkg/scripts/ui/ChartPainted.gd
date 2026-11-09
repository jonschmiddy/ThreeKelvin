class_name ChartPainted
extends RefCounted

## Direction B of the Oct 5 showcase: every pixel placed on purpose, with a band memory.
## Shares the simplified chart's view, hole and life, drawn as held poses.
## Why: docs/why/ChartPainted.md#painted-style

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
	["#1a120a", "#2e2010", "#422f16", "#563c1a", "#7c5a26", "#a0783a"],    # 19 old gold (the big dwarf spheroidal's body, Jon, Nov 8, "dim gold")
]
## The lit-side rim and the shadow-side outline of a material's big shapes.
const RIM := {4: "#8a5062", 5: "#f1b583", 9: "#ff9c9a", 11: "#c87b62", 1: "#cfe6fb"}
const OUTLINE := {1: "#0f1230", 6: "#2e0a22", 8: "#0d1638"}
## Materials whose bands meet without a checker (sparkles and the bolt are crisp).
const NOTRANS := [13, 14, 15, 16, 18]

static var _tables: Dictionary = {}


## Palette and lookups built once, including the OKLab lightness the place pass compares layers by.
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


## A harness `style=painted` is honoured while PAINTED is
## unbuilt; the chart can draw it where settings cannot.
static func wanted() -> bool:
	return DisplaySettings.render_style == &"painted" or "style=painted" in OS.get_cmdline_user_args()


# ------------------------------------------------------------------ the bake

## The galaxy's constants as the painted pass reads them (showcase G0 to G7, G8 for the rest).
const STORY_GAIN_B := 0.5


## A ball as its own kind (`chart_b_place`'s `u_ballK`): (look, how far out its old warm light
## holds in ball radii, its young gas and star birth 0..1, how irregular its outline 0..1).
## Why: docs/why/ChartPainted.md#ball-kinds
static func ball_kind(ball: Vector4) -> Vector4:
	match int(ball.w):
		1:
			return Vector4(1.0, 0.3, 1.0, 0.6)
		2:
			return Vector4(2.0, 0.6, 0.0, 0.15)
		3:
			return Vector4(3.0, 1.1, 0.3, 0.25)
	return Vector4(0.0, 1.25, 0.0, 0.0)


## A ball's body in this style (`chart_b_place`'s `u_ballF`): (size against its ball radius, how
## steeply its light falls, where it ends in ball radii, its globular-cluster halo 0..1).
## Why: docs/why/ChartPainted.md#ball-body
static func ball_form(kind: int) -> Vector4:
	match GalaxyGen.type_name(kind):
		"Flattened Elliptical":
			return Vector4(1.1, 1.55, 2.4, 0.0)
		"Giant Elliptical":
			return Vector4(1.15, 0.95, 3.0, 1.0)
		"Dwarf Spheroidal":
			return Vector4(0.75, 1.2, 2.4, 0.0)
	return Vector4(1.0, 1.3, 2.4, 0.0)


## THE BIG DWARF's envelope in this style (`ChartTorn.ball_v`, `chart_b_place`'s
## `ballEnv`): its level against the body's middle and the power its light falls by,
## by kind: the dwarf spheroidal's higher, its light is 0.4 of a ball's. Measured off
## the painted chart: lit to about LIT_K of its reach, on its ramps' bottom steps.
const BIG_ENV := {14: Vector2(0.3, 1.2), 15: Vector2(0.7, 0.5)}


static func ball_env(kind: int) -> Vector4:
	var e: Vector2 = BIG_ENV.get(kind, Vector2(0.2, 0.7))
	return ChartTorn.ball_v(e.x, e.y)


## How round a ball is drawn in this style: `ChartSky.ball_of`'s, a flattened elliptical's
## squashed further, so it is a lens beside a round one's ball (0.55 against 0.74 read
## as the same ball turned a little).
static func ball_squash(kind: int, ball: Vector4) -> float:
	return ball.y * (0.8 if GalaxyGen.type_name(kind) == "Flattened Elliptical" else 1.0)


static func galaxy_uniforms(p: Dictionary) -> Dictionary:
	var g: Dictionary = Run.galaxy
	var form: int = p.form
	var arms := int(p.arms)
	var chaos: float = p.chaos
	var arm_k := 0.0
	if form == 0 and arms > 0:
		arm_k = clampf(1.0 - chaos * 1.8, 0.35, 1.0) * (0.75 if arms >= 5 else 1.0)
	var ball: Vector4 = p.ball
	var bd := ChartSky.ball_depth(Run.galaxy_kind)
	var story := ChartSky.ball_story(STORY_GAIN_B)
	return story.merged({
		"u_ballD": bd[0],
		"u_ballE": bd[1],
		"u_ballK": ball_kind(ball),
		"u_ballF": ball_form(Run.galaxy_kind),
		"u_ballV": ball_env(Run.galaxy_kind),
		"u_g0": Vector4(float(maxi(arms, 1)), float(p.twist), float(p.bar), float(p.spread)),
		"u_g1": Vector4(float(p.spin), arm_k, float(p.lane), float(p.gas)),
		"u_g2": Vector4(float(g.get("dust", 1.6)), float(p.bulge_r), ball_squash(Run.galaxy_kind, ball) if form == 1 else 0.86, ChartSky.hole_of(p)),
		"u_g3": Vector4(1.0 if form == 1 else 0.0, ball.y, ChartSky.hole_of(p) * ChartSky.DISC_K, float(Run.galaxy_kind) * 0.137),
		"u_g4": Vector4(0.102, 0.0, 0.0, 0.18),
		"u_g5": Vector4(0.5 if float(p.bar) > 0.0 else 0.6, 0.4, 0.35, 1.6),
		"u_g6": Vector4(0.12, 0.06, 1.25, 0.8),
		"u_g7": Vector4(0.4, 0.72, 0.16, 0.7 if arms == 2 else 0.0),
		"u_g8": Vector4(ball.x, ball.z / 0.085, chaos, 1.0 if p.tail else 0.0),
	})


## Named clouds as uniform arrays: plane centre and size, kind, hollowness, shape and lobes.
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


## The star field as sparkles read it: bright points
## with colour class and sprite tier, dimmest first.
static func star_data(sky: ChartSky, g: Dictionary, p: Dictionary) -> void:
	var src: Dictionary = sky._src
	var r_max: float = src.r_max
	var sq: float = p.squash
	var ball := int(p.form) == 1
	# (a blue compact dwarf's stars are young: mostly blue-white, as its gas is)
	var young := ball and int((p.ball as Vector4).w) == 1
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
			cls = 0 if h3 < (0.7 if young else 0.12) else 1
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
	var t0 := Time.get_ticks_usec()
	g["b_debt"] = _star_debt(rows, float(p.bulge_r))
	g.times["debt"] = (Time.get_ticks_usec() - t0) / 1000
	g["b_sn"] = cand
	g["b_a"] = ChartSky._data_tex(a, rows.size())
	g["b_b"] = ChartSky._data_tex(b, rows.size())
	g["b_c"] = ChartSky._data_tex(c3, rows.size())


## Star light kept across zoom: what the sparkles no longer bring a patch goes back into its gas.
static func _star_debt(rows: Array, bulge_r: float) -> ImageTexture:
	var zs := ChartSky.DEBT_Z
	var nz := zs.size()
	var N := ChartSky.DEBT_N
	var E := ChartSky.DEBT_E
	var acc := PackedFloat32Array()
	acc.resize(nz * N * N)
	acc.fill(0.0)
	var Ls := PackedFloat32Array()
	var keeps := PackedFloat32Array()
	for z in zs:
		var lz := log(z)
		Ls.append(150.0 if z <= 0.6 else (60.0 if z >= 3.0 else 150.0 + (60.0 - 150.0) * (lz - log(0.6)) / (log(3.0) - log(0.6))))
		keeps.append(0.4 if z <= 0.6 else (1.0 if z >= 2.0 else 0.4 + 0.6 * (lz - log(0.6)) / (log(2.0) - log(0.6))))
	for row: Array in rows:
		var px: float = row[1]
		var py: float = row[2]
		var tx := int((px / E * 0.5 + 0.5) * N)
		var ty := int((py / E * 0.5 + 0.5) * N)
		if tx < 0 or ty < 0 or tx >= N or ty >= N:
			continue
		var lum: float = row[0]
		var kind: int = row[3]
		var tier: int = row[5]
		var hs: float = row[6]
		var inner := Vector2(px, py).length() < bulge_r
		for zi in nz:
			var z: float = zs[zi]
			var lv := 0.0
			var sprite := 0
			if kind <= 2:
				var f := 1.0
				if kind == 1 and inner:
					f *= ChartSky._smooth(1.55, 2.3, z)
				if kind == 2:
					f *= ChartSky._smooth(1.6, 2.4, z)
				var kk := keeps[zi] * (0.25 if kind == 1 else 1.0)
				if lum >= Ls[zi] and hs < kk and f > 0.02:
					var fade := minf(1.0, (lum - Ls[zi]) / 30.0 + 0.15) * minf(1.0, (kk - hs) / 0.08 + 0.15) * f
					lv = minf(0.999, fade * pow(maxf(0.0, lum - 40.0) / 215.0, 0.7))
					if tier >= 3 and lv > 0.45:
						sprite = 2
					elif tier >= 2 and lv > 0.3 and (tier >= 3 or z >= 0.75 or float(row[8]) < 0.035):
						sprite = 1
			elif kind == 4:
				var gk := 1.0 - ChartSky._smooth(1.6, 2.4, z)
				if gk > 0.02:
					lv = minf(0.999, gk * (0.34 + minf(0.2, float(row[10]) / 500.0)))
					sprite = 1
			else:
				lv = 0.6
				sprite = 1
			if lv > 0.05:
				acc[zi * N * N + ty * N + tx] += pow(2.0, 7.0 * (lv - 1.0)) * [1.0, 1.8, 2.2][sprite]
	var k := 4.0 / (ChartSky.K0 * ChartSky.K0 * ChartSky.TILT) / pow(2.0 * E / N, 2.0)
	var out := PackedFloat32Array()
	out.resize(nz * N * N)
	for zi in nz:
		for y in N:
			for x in N:
				out[y * N * nz + zi * N + x] = acc[zi * N * N + y * N + x] * k
	return ImageTexture.create_from_image(Image.create_from_data(N * nz, N, false, Image.FORMAT_RF, out.to_byte_array()))


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
	# Solid look fields read SIMPLIFIED's own bakes at
	# fixed scales, so relief and puffs stand where its do.
	for mode in 2:
		var n := ChartSky.NOISE_N if mode == 0 else (ChartSky.STRUCT_N if (int(p.arms) > 0 or float(p.bar) > 0.0) else 16)
		var mb := ShaderMaterial.new()
		mb.shader = ChartSky.BAKE_SH
		mb.set_shader_parameter("mode", mode)
		mb.set_shader_parameter("ext", ChartSky.EXT)
		mb.set_shader_parameter("arms", float(p.arms))
		mb.set_shader_parameter("twist", float(p.twist))
		mb.set_shader_parameter("bar", float(p.bar))
		mb.set_shader_parameter("spin", float(p.spin))
		mb.set_shader_parameter("spread", float(p.spread))
		mb.set_shader_parameter("chaos", float(p.chaos))
		out.append(sky._pass_vp(holder, Vector2i(n, n), ChartSky._rect(mb), false))
	return out


## The puff table read back, and the solid look's two bakes mip-mapped: the galaxy
## is ready (its palette needs no cut).
static func finish_bake(g: Dictionary, vps: Array) -> bool:
	var texs: Array[ImageTexture] = []
	for i in vps.size():
		var img := (vps[i] as SubViewport).get_texture().get_image()
		if img == null:
			return false
		if i >= 2:
			img.convert(Image.FORMAT_RGBA8)
			img.generate_mipmaps()
		texs.append(ImageTexture.create_from_image(img))
	g["puffA"] = texs[0]
	g["puffB"] = texs[1]
	g["noise"] = texs[2]
	g["struct"] = texs[3]
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
	# (the solid look's fields: SIMPLIFIED's bakes, and the lanes' strength they cut)
	mp.set_shader_parameter("u_noise", g.noise)
	mp.set_shader_parameter("u_struct", g.struct)
	mp.set_shader_parameter("u_ext", ChartSky.EXT)
	mp.set_shader_parameter("u_laneStr", float(g.p.lane))
	mp.set_shader_parameter("u_Y", T.Y)
	mp.set_shader_parameter("u_mstart", T.mstart)
	mp.set_shader_parameter("u_mlen", T.mlen)
	mp.set_shader_parameter("u_stars", sky._svp.get_texture())
	if g.has("b_debt"):
		mp.set_shader_parameter("u_debt", g.b_debt)
		mp.set_shader_parameter("u_debtP", Vector4(log(ChartSky.DEBT_Z[0]), float(ChartSky.DEBT_Z.size() - 1)
			/ (log(ChartSky.DEBT_Z[-1]) - log(ChartSky.DEBT_Z[0])), float(ChartSky.DEBT_Z.size()), ChartSky.DEBT_E))
		mp.set_shader_parameter("u_debtOn", not (ChartSky.diag & 512))
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
	mp.set_shader_parameter("u_depth", ChartSky.depth_uniform(res, ccon, z))
	mp.set_shader_parameter("u_res", res)
	mp.set_shader_parameter("u_zoom", z)
	mp.set_shader_parameter("u_diag", ChartSky.diag)
	mp.set_shader_parameter("u_zopen", z * StarchartScreen.MapChart.ZOOM_MIN / maxf(sky.chart.zoom, 1e-4) if sky._use_map else z)
	mp.set_shader_parameter("u_time", t)
	mp.set_shader_parameter("u_phi", phi)
	mp.set_shader_parameter("u_block0", b0)
	mp.set_shader_parameter("u_wxOn", 0.0 if calm else 1.0)
	mp.set_shader_parameter("u_flow", t * (0.5 if calm else 1.0))
	var gu4: Vector4 = g.gu.u_g4
	gu4.z = 1.0 if calm else 0.0
	mp.set_shader_parameter("u_g4", gu4)
	feed_events(mp, g, t, phi, calm)
	# TORN AWAY (the dwarfs, when the run sets it; `ChartTorn`): the giant, the one stream, the dwarf drawn smaller
	ChartTorn.push(mp, sky._m_stars, phi, sky.chart.pan if sky._use_map and sky.chart != null else Vector2.ZERO, z if sky._use_map and sky.chart != null else 0.0)
	# (and the clouds over the dwarf torn with it, in this style's order: NebulaField's)
	if not g.has("_torn_cl"):
		var xs: Array = []
		var rs: Array = []
		var sq: float = (g.p as Dictionary).squash
		for raw in NebulaField.clouds():
			if xs.size() >= ChartSky.MAX_CL:
				break
			var c: NebulaField.Cloud = raw
			var reach := 0.0
			for l in c.lobes.size():
				reach = maxf(reach, (c.lobes[l] as Vector2).length() + c.lobe_r[l] * NebulaField.EXTENT)
			xs.append(Vector2(c.pos.x, c.pos.y / sq))
			rs.append(reach)
		g["_torn_cl"] = [xs, rs]
	var tear := ChartTorn.cloud_arrays(g._torn_cl[0], g._torn_cl[1], phi, ChartSky.MAX_CL)
	mp.set_shader_parameter("u_tornCl", tear.u_tornCl)
	mp.set_shader_parameter("u_tornClD", tear.u_tornClD)
	# Solid look uniforms go on the place pass and the
	# camera on the sparkles, so they follow the disc.
	var sol := ChartSky.solid() and sky._use_map
	sky.push_solid(mp, sol)
	sky.push_solid_stars(sky._m_stars, sol)
	# `solidtest` reads back the plane point, which no
	# 8-bit G-buffer holds, so those frames use half floats.
	var probe := (ChartSky.diag & 4096) != 0
	if sky._pvp.use_hdr_2d != probe:
		sky._pvp.use_hdr_2d = probe
	# The centre drawn about this frame, where `solidtest` measures marks from, as for SIMPLIFIED.
	sky._hold_c_now = ccon
	var ms := sky._m_stars
	ms.set_shader_parameter("vp_origin", origin)
	ms.set_shader_parameter("cpix", ccon)
	ms.set_shader_parameter("zoom", z)
	ms.set_shader_parameter("diag", ChartSky.diag)
	ms.set_shader_parameter("phi", phi)
	ms.set_shader_parameter("t", t)
	ms.set_shader_parameter("calm", 1.0 if calm else 0.0)
	var mt := sky._m_state
	mt.set_shader_parameter("vp_size", vs)
	mt.set_shader_parameter("block0", b0)
	# a resized memory holds nothing of the old picture: start it afresh
	mt.set_shader_parameter("reset", resized)
	# The turn is kept per frame: pushed twice a frame,
	# the second push read the first's turn as last frame's.
	var fr := Engine.get_process_frames()
	var cam_now := [ChartSky.solid_cam(), ChartSky.SOLID_T, sol]
	if int(g.get("_view_fr", -1)) != fr:
		g["_view_fr"] = fr
		g["_phi_prev"] = g.get("_phi_cur", phi)
		g["_view_prev"] = g.get("_view_cur", [z, ccon, origin, b0])
		g["_cam_prev"] = g.get("_cam_cur", cam_now)
	g["_phi_cur"] = phi
	g["_cam_cur"] = cam_now
	# Memory follows the camera, read from where each piece was
	# drawn last frame, or a held band stays while its gas moves on.
	var cp: Array = g["_cam_prev"]
	mt.set_shader_parameter("cam_on", sol and bool(cp[2]))
	mt.set_shader_parameter("cam_cur", cam_now[0])
	mt.set_shader_parameter("cam_cur_t", cam_now[1])
	mt.set_shader_parameter("cam_prev", cp[0])
	mt.set_shader_parameter("cam_prev_t", cp[1])
	mt.set_shader_parameter("cam_k", ChartSky.K0)
	var pd := wrapf(phi - float(g.get("_phi_prev", phi)), -PI, PI)
	mt.set_shader_parameter("phi_d", pd if absf(pd) < 0.2 else 0.0)
	mt.set_shader_parameter("origin", origin)
	mt.set_shader_parameter("cpix", ccon)
	mt.set_shader_parameter("zoom", z)
	# Last frame's view is kept per frame, as a second
	# push in a frame would take the first's for it.
	g["_view_cur"] = [z, ccon, origin, b0]
	var pv: Array = g["_view_prev"]
	mt.set_shader_parameter("zoom0", float(pv[0]))
	mt.set_shader_parameter("cpix0", pv[1])
	mt.set_shader_parameter("origin0", pv[2])
	mt.set_shader_parameter("block00", pv[3])
	# The band memory is cut by how far a zoom moved the edge: held through a zoom,
	# bands let go in the second after. A slow zoom keeps about 30 frames, a wheel turn none.
	# Why: docs/why/ChartPainted.md#zoom-hold
	var zmove := absf(log(maxf(z, 1e-4) / maxf(float(pv[0]), 1e-4))) * vs.length() * 0.5
	if not bool(g.get("_hold_fixed", false)):
		mt.set_shader_parameter("hold", HOLD if zmove < 1e-4 else minf(HOLD, ZOOM_HOLD / zmove))
	var mc := sky._m_comp
	mc.set_shader_parameter("vp_size", vs)
	mc.set_shader_parameter("block0", b0)
	sky._stars.queue_redraw()


## Events are held poses, pure functions of t, drawn by hand: supernova in four frames,
## echo ring every 1.5 s, lightning held 0.35 s.
## Why: docs/why/ChartPainted.md#held-poses
static func feed_events(m: ShaderMaterial, g: Dictionary, t: float, phi: float, calm: bool) -> void:
	# what the last minutes' supernovae left, among this style's own supernova stars
	var rm: Array = ChartSky.remnants(g.b_sn, t, calm)
	m.set_shader_parameter("u_nrem", int(rm[0]))
	m.set_shader_parameter("u_rem", rm[1])
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


## Lightning held: pose, round-frame x and y, seed.
## The legacy schedule is a flash in most 10 s slots.
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
