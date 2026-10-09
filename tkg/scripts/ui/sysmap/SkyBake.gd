extends RefCounted

## THE SYSTEM'S SKY, worked out once per system: its own nebula, thousands of
## stars, the star's light on the space round it, the shafts through the dust.
## A port of the approved mockup's `bakeLook` (scratchpad `sysmap/template.html`)
## for the look Jon picked: Sky C "its own nebula", Light B "shafts and shadows,
## gentle", the nebula's detail as it was ("the detail is perfect now"), drawn
## in 2x2 blocks for the chunky pixel palette.
##
## Two pictures come out of it, both made by `sky_bake.gdshader` in one pass
## each through a SubViewport:
##   * `base`: the sky WITHOUT the gas -- void, stars, the star's glow and
##     shafts, darkened where dust lies in front;
##   * `gas`: what the gas adds to each pixel (RGB), so `sky.gdshader` can roll
##     slow waves of brightness through it every frame (the gas drifting), and,
##     round a pulsar, how much gas there is (A), for the beam to light.
## The stars are placed here, from the mockup's own generator in its order of
## draws, so a system's sky is its sky in the mockup.

const BAKE := preload("res://shaders/sky_bake.gdshader")

const W := 960
const H := 540
## THE SKY IS BAKED BIGGER THAN THE MAP by M on every side, so it has room to
## slide behind the orbits when the map pans (`SystemView.sky_off`). Map
## coordinates run from -M; the bake's own pixels from 0.
const M := 128
const BW := W + 2 * M
const BH := H + 2 * M
## As many stars per pixel as when the sky was 704 x 540.
const MORE := float(BW * BH) / (704.0 * 540.0)
## Harness switches (SystemShot `off=`): the sun's rays and the dust, off.
static var no_rays := false
## THE STARS LAID OUT ONCE A SYSTEM (Jon on 2C: "still has a small delay/hitch"):
## the few thousand stars are placed by noise worked out a star at a time, about
## a tenth of a second of one frame, and a map is built new every visit -- the
## way back out of LOCAL built it again for the system it had just shown. The
## same system always places the same stars, so they are kept for the session
## (key -> [stars texture, twinkle list]), the last few systems.
static var _stars_kept := {}
const STARS_KEPT_MAX := 6
static var no_dust := false

## Star colours by temperature, and how common each is.
const TEMPS := [Vector3(0.62, 0.74, 1.0), Vector3(0.86, 0.9, 1.0), Vector3(1.0, 0.96, 0.9), Vector3(1.0, 0.84, 0.64), Vector3(1.0, 0.66, 0.46)]
const TW := [0.12, 0.3, 0.3, 0.18, 0.1]
## The nebula's two colours, by system; a pulsar's shell is its own blues.
const PALS := [
	[Vector3(0.15, 0.6, 0.72), Vector3(0.82, 0.24, 0.55)],
	[Vector3(0.95, 0.55, 0.2), Vector3(0.5, 0.25, 0.85)],
	[Vector3(0.25, 0.45, 1.0), Vector3(0.2, 0.8, 0.55)],
	[Vector3(0.9, 0.3, 0.3), Vector3(0.3, 0.5, 0.9)],
]
const PULSAR_PAL := [Vector3(0.22, 0.42, 1.0), Vector3(0.56, 0.3, 0.95)]


## THE SKY BY WHERE THE SYSTEM IS (Jon: "Maybe we can have the sectors that are
## in a nebula have all the clouds, and the sectors that aren't in a nebula have
## something more simple"). Inside a cloud the gas is the cloud's own, in its
## kind's colours, as the star chart paints it; outside one the sky is clear --
## stars, a faint distant band of the galaxy, a little thin dust. A pulsar and
## the core keep their own skies.
static func look_for(n: MapGen.MapNode, kind: String) -> Dictionary:
	if kind == "PULSAR":
		return {"pal": PULSAR_PAL, "thick": 1.6 if n.in_nebula else 1.0, "band": 0.0, "dust": 1.0, "nebula": true}
	if kind == "CORE":
		return {"pal": PALS[n.index % 4], "thick": 1.6 if n.in_nebula else 1.0, "band": 0.0, "dust": 1.0, "nebula": true}
	var cloud = NebulaField.at(n.gal) if n.in_nebula else null
	if cloud == null:
		# CLEAR SKY: the gas all but gone, a faint band of the galaxy, sparse dust
		return {"pal": [Vector3(0.42, 0.46, 0.62), Vector3(0.58, 0.5, 0.62)], "thick": 0.18, "band": 1.0, "dust": 0.35, "nebula": false}
	var c0: Color = cloud.base_colour()
	var c1: Color = cloud.edge_colour()
	var p0 := Vector3(c0.r, c0.g, c0.b)
	# the second colour: the cloud's own edge, lifted to sit as gas beside it
	var p1 := Vector3(c1.r, c1.g, c1.b).lerp(p0, 0.25) * 1.5
	var thick := 1.6
	var dust := 1.0
	if cloud.kind == NebulaField.Kind.DARK:
		# A DARK CLOUD lights nothing: dim violet gas, thick dust that hides
		# what is behind it
		p0 = Vector3(0.24, 0.2, 0.32)
		p1 = Vector3(0.32, 0.26, 0.4)
		thick = 0.7
		dust = 1.6
	elif cloud.kind == NebulaField.Kind.REFLECTION:
		thick = 1.3
	# and the cloud itself, for the sky seen from inside it (`sky_nebula`):
	# its kind, its shape, its own colour
	return {"pal": [p0, p1], "thick": thick, "band": 0.0, "dust": dust, "nebula": true, "cloud": cloud.label(),
		"neb": int(cloud.kind), "shape": int(cloud.shape), "hue": Vector3(c0.r, c0.g, c0.b)}
## The star's own light, by kind.
const STARCOL := {"ORDINARY": Vector3(1.0, 0.86, 0.62), "RED": Vector3(1.0, 0.5, 0.3), "BLUE": Vector3(0.6, 0.75, 1.0), "PULSAR": Vector3(0.62, 0.8, 1.0), "CORE": Vector3(1.0, 0.64, 0.36)}

var base: ImageTexture
var gas: ImageTexture
## Stars that twinkle each frame instead of being baked: [x, y, strength, colour, phase].
var twinkle: Array = []

## THE CLOUD SEEN FROM INSIDE, BAKED (SIMPLIFIED, direction C: `field`): its
## density, its billows and far gas, and their gradients, one texel a 2x2 block
## of the sky with FIELD_MB blocks of margin for the slide and the flow, for
## `sky_nebula.gdshader` to light and stream every frame.
const FIELD := preload("res://shaders/sky_field.gdshader")
const FIELD_MB := 48
const FIELD_W := W / 2 + 2 * FIELD_MB
const FIELD_H := H / 2 + 2 * FIELD_MB
var field0: ImageTexture
var field1: ImageTexture
var field2: ImageTexture
## the same, read back, for anything on the CPU that wants the cloud's shape
var field_img0: Image
var field_img1: Image


## THE PILLARS of an emission (or reflection) cloud, rising toward its sun
## (C: dark columns with shoulders and knotted heads, their star-facing rims
## lit): four to six, most from the dust bank below the star, each [base, tip,
## width at the base, width at the head, its own seed], in sky pixels. Worked
## out here and handed to the bake, so the weather knows where the tips are
## (a jet leaves one) without guessing from the picture.
static func em_pillars(sd: float, cc: Vector2) -> Array:
	var s := int(sd * 1000.0)
	var out: Array = []
	var n := 4 + int(hash2(s, 71) * 2.99)
	for k in n:
		var h := hash2(s + k * 31, 73)
		var a: float
		if k < (n + 1) / 2:
			# from the bank below the star, leaning in
			a = PI * 0.5 + (h - 0.5) * 2.0 + (float(k) - float(n) * 0.25) * 0.55
		else:
			a = hash2(s + k * 17, 74) * TAU
		var dir := Vector2(cos(a), sin(a))
		# the ones from the bank reach in close; the others stop further out
		var tip_r := (95.0 + 55.0 * hash2(s + k * 13, 75)) if k < (n + 1) / 2 else (130.0 + 70.0 * hash2(s + k * 13, 75))
		var ln := 260.0 + 160.0 * hash2(s + k * 7, 76)
		var tip := cc + dir * tip_r
		# a little off the radial line, so they do not all point at the sun's centre
		var base := cc + dir.rotated((hash2(s + k * 5, 77) - 0.5) * 0.5) * (tip_r + ln)
		var w1 := 12.0 + 10.0 * hash2(s + k * 3, 78)
		out.append([base, tip, w1 * (2.2 + 0.8 * hash2(s + k * 11, 79)), w1, float(k) * 1.37 + sd])
	return out


## Bake the cloud of `kind` (`NebulaField.Kind`), `shape`, seed `sd` (the
## nebula shader's own), its emission cluster at sky pixel `cc`; `parent` hosts
## the one-shot viewport. Six frames on the GPU, once a system.
## `legacy`: LEGACY's noises instead, for `sky_nebula_legacy.gdshader` to stream.
func field(parent: Node, kind: int, shape: int, sd: float, cc: Vector2, legacy: bool = false) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(FIELD_W, FIELD_H)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	var rect := ColorRect.new()
	rect.size = Vector2(FIELD_W, FIELD_H)
	var m := ShaderMaterial.new()
	m.shader = FIELD
	m.set_shader_parameter("kind", kind)
	m.set_shader_parameter("shape", shape)
	m.set_shader_parameter("sd", sd)
	m.set_shader_parameter("tex", Vector2(FIELD_W, FIELD_H))
	m.set_shader_parameter("mb", float(FIELD_MB))
	m.set_shader_parameter("cc", cc)
	m.set_shader_parameter("legacy", legacy)
	var pa := PackedVector4Array()
	var pb := PackedVector4Array()
	for p: Array in em_pillars(sd, cc):
		pa.append(Vector4(p[0].x, p[0].y, p[1].x, p[1].y))
		pb.append(Vector4(p[2], p[3], p[4], 0.0))
	m.set_shader_parameter("n_pil", pa.size())
	pa.resize(8)
	pb.resize(8)
	m.set_shader_parameter("pil_a", pa)
	m.set_shader_parameter("pil_b", pb)
	rect.material = m
	vp.add_child(rect)
	parent.add_child(vp)
	var imgs: Array[Image] = []
	for mode in 3:
		m.set_shader_parameter("mode", mode)
		if mode == 2:
			m.set_shader_parameter("src", ImageTexture.create_from_image(imgs[0]))
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		imgs.append(vp.get_texture().get_image())
	vp.queue_free()
	field_img0 = imgs[0]
	field_img1 = imgs[1]
	field0 = ImageTexture.create_from_image(imgs[0])
	field1 = ImageTexture.create_from_image(imgs[1])
	field2 = ImageTexture.create_from_image(imgs[2])


# ---------------------------------------------------------------- the mockup's 2D noise
static func hash2(x: int, y: int) -> float:
	var h := ((x * 374761393) ^ (y * 668265263)) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	return float((h ^ (h >> 16)) & 0xFFFFFFFF) / 4294967296.0


static func noise2(x: float, y: float) -> float:
	var xi := floori(x)
	var yi := floori(y)
	var xf := x - xi
	var yf := y - yi
	var u := xf * xf * (3.0 - 2.0 * xf)
	var v := yf * yf * (3.0 - 2.0 * yf)
	var a := hash2(xi, yi)
	var b := hash2(xi + 1, yi)
	var c := hash2(xi, yi + 1)
	var d := hash2(xi + 1, yi + 1)
	return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v


static func fbm2(x: float, y: float, o: int) -> float:
	var a := 0.5
	var s := 0.0
	var n := 0.0
	for i in o:
		s += a * noise2(x, y)
		n += a
		x *= 2.03
		y *= 2.03
		a *= 0.5
	return s / n


static func smooth_k(a: float, b: float, x: float) -> float:
	var u := clampf((x - a) / (b - a), 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


## Bake the sky of system `index` (its seed), with a star of `kind` at
## (`cx`, `cy`) and its outermost orbit at `edge`. `parent` hosts the
## one-shot viewport. Two frames, then both pictures are ready.
func make(parent: Node, index: int, kind: String, in_nebula: bool, edge: float, cx: float, cy: float, tilt: float, look: Dictionary = {}) -> void:
	var R := Worlds.XRng.new(float(index) * 7919.0 + 17.0)
	var sd := float(index) * 0.731
	var skey := "%d|%s|%s|%s|%s" % [index, kind, in_nebula, look.get("band", 0.0), look.get("band_glow", 0.06)]
	var stars_tex: ImageTexture = null
	if _stars_kept.has(skey):
		stars_tex = _stars_kept[skey][0]
		twinkle = (_stars_kept[skey][1] as Array).duplicate(true)
	else:
		stars_tex = _lay_stars(R, sd, look)
		if _stars_kept.size() >= STARS_KEPT_MAX:
			_stars_kept.erase(_stars_kept.keys()[0])
		_stars_kept[skey] = [stars_tex, twinkle.duplicate(true)]
	await _bake_rest(parent, index, kind, in_nebula, edge, cx, cy, tilt, look, sd, stars_tex)


## The stars' light (and the twinkling few, into `twinkle`), from the system's own
## random stream: the slow part of `make`, kept per system.
func _lay_stars(R: Worlds.XRng, sd: float, look: Dictionary) -> ImageTexture:
	var temp := func() -> Vector3:
		var u := R.next()
		var i := 0
		while i < 4 and u > TW[i]:
			u -= TW[i]
			i += 1
		return TEMPS[i]
	var dust_at := func(x: float, y: float) -> float:
		return smooth_k(0.56, 0.7, fbm2(x * 0.005 + 20.0 + sd, y * 0.008 + 3.0, 5))
	var density := func(x: float, y: float) -> float:
		return 1.0 - dust_at.call(x, y) * 0.9
	# the stars' light, as the mockup laid it: a point, a plus, spikes
	var lb := PackedFloat32Array()
	lb.resize(BW * BH * 3)
	# only the few thousand pixels a star touches are written out, not all half million
	var touched := {}
	var add := func(x: float, y: float, I: float, c: Vector3) -> void:
		# a 2x2 block on the place's grid: the sky is drawn half size, so a lone
		# pixel would show or vanish with its parity
		var bx := int(floor(roundf(x) / 2.0)) * 2 + M
		var by := int(floor(roundf(y) / 2.0)) * 2 + M
		if bx < 0 or by < 0 or bx + 1 >= BW or by + 1 >= BH:
			return
		for q in [0, 1, BW, BW + 1]:
			var k: int = by * BW + bx + q
			touched[k] = true
			lb[k * 3] += I * c.x
			lb[k * 3 + 1] += I * c.y
			lb[k * 3 + 2] += I * c.z
	for k in roundi(2800 * MORE):
		var x := -M + R.next() * BW
		var y := -M + R.next() * BH
		if R.next() < density.call(x, y) / 1.4:
			add.call(x, y, 0.05 + pow(R.next(), 6.0) * 0.5, temp.call())
	twinkle.clear()
	for k in roundi(420 * MORE):
		var x := -M + R.next() * BW
		var y := -M + R.next() * BH
		var c: Vector3 = temp.call()
		var I := 0.25 + R.next() * 0.45
		if R.next() > density.call(x, y):
			continue
		if k < roundi(140 * MORE):
			twinkle.append([x, y, I, c, R.next() * 40.0])
		else:
			add.call(x, y, I, c)
	for k in roundi(46 * MORE):
		var x := -M + R.next() * BW
		var y := -M + R.next() * BH
		var c: Vector3 = temp.call()
		var I := 0.7 + R.next() * 1.1
		if dust_at.call(x, y) > 0.6:
			continue
		add.call(x, y, I, c)
		add.call(x - 1, y, I * 0.32, c)
		add.call(x + 1, y, I * 0.32, c)
		add.call(x, y - 1, I * 0.32, c)
		add.call(x, y + 1, I * 0.32, c)
		# NO SPIKES on the brightest any more (Jon: "these stars in the sector
		# view are weird"): a spiked star is a distant supernova now, and comes and
		# goes (`SystemView._Nova`). Nothing here drew from R, so every other star
		# is where it was.
	# THE GALAXY'S BAND IN A CLEAR SKY (SIMPLIFIED): a crowd of faint stars along
	# it, thickest on its line, instead of a glow (drawn after every other star,
	# so those are where they were)
	if float(look.get("band", 0.0)) > 0.0 and float(look.get("band_glow", 0.06)) <= 0.0:
		var ang := sd * 2.7
		var along := Vector2(cos(ang), sin(ang))
		var nrm := Vector2(-sin(ang), cos(ang))
		for k in roundi(1100 * MORE):
			var tt := (R.next() - 0.5) * 2200.0
			var g := (R.next() + R.next() + R.next() - 1.5) * 120.0
			var p := Vector2(480, 270) + along * tt + nrm * g
			var I := 0.04 + pow(R.next(), 3.0) * 0.22
			add.call(p.x, p.y, I, temp.call())
	# eight bits a channel, a 64th of a unit a step: the brightest star is under four
	var bytes := PackedByteArray()
	bytes.resize(BW * BH * 4)
	for i: int in touched:
		bytes[i * 4] = mini(255, int(lb[i * 3] * 64.0))
		bytes[i * 4 + 1] = mini(255, int(lb[i * 3 + 1] * 64.0))
		bytes[i * 4 + 2] = mini(255, int(lb[i * 3 + 2] * 64.0))
		bytes[i * 4 + 3] = 255
	var stars := Image.create_from_data(BW, BH, false, Image.FORMAT_RGBA8, bytes)
	return ImageTexture.create_from_image(stars)


func _bake_rest(parent: Node, index: int, kind: String, in_nebula: bool, edge: float, cx: float, cy: float, tilt: float,
		look: Dictionary, sd: float, stars_tex: ImageTexture) -> void:

	# the rest is per pixel, on the GPU, once
	var pal: Array = look.get("pal", PULSAR_PAL if kind == "PULSAR" else PALS[index % 4])
	var vp := SubViewport.new()
	vp.size = Vector2i(BW, BH)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	var rect := ColorRect.new()
	rect.size = Vector2(BW, BH)
	var m := ShaderMaterial.new()
	m.shader = BAKE
	m.set_shader_parameter("stars", stars_tex)
	m.set_shader_parameter("sd", sd)
	m.set_shader_parameter("star_at", Vector2(cx, cy))
	m.set_shader_parameter("star_col", STARCOL.get(kind, STARCOL.ORDINARY))
	m.set_shader_parameter("pal0", pal[0])
	m.set_shader_parameter("pal1", pal[1])
	m.set_shader_parameter("thick", float(look.get("thick", 1.6 if in_nebula else 1.0)))
	m.set_shader_parameter("band", float(look.get("band", 0.0)))
	m.set_shader_parameter("band_glow", float(look.get("band_glow", 0.06)))
	m.set_shader_parameter("band_w", float(look.get("band_w", 150.0)))
	m.set_shader_parameter("band_wob", float(look.get("band_wob", 160.0)))
	m.set_shader_parameter("band_lump", float(look.get("band_lump", 0.0)))
	m.set_shader_parameter("pulsar", kind == "PULSAR")
	# SIMPLIFIED: round a pulsar, the remnant's shell as fields for the sky to
	# colour (LEGACY keeps the old shell: its look's `c_remnant` false)
	m.set_shader_parameter("c_remnant", kind == "PULSAR" and bool(look.get("c_remnant", true)))
	m.set_shader_parameter("edge", edge)
	m.set_shader_parameter("tilt", tilt)
	m.set_shader_parameter("x0", -1.0e6)
	m.set_shader_parameter("bake_size", Vector2(BW, BH))
	m.set_shader_parameter("margin", float(M))
	m.set_shader_parameter("rays_k", 0.0 if no_rays else 1.0)
	m.set_shader_parameter("dust_k", 0.0 if no_dust else float(look.get("dust", 1.0)))
	rect.material = m
	vp.add_child(rect)
	parent.add_child(vp)
	m.set_shader_parameter("mode", 0)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	base = ImageTexture.create_from_image(vp.get_texture().get_image())
	m.set_shader_parameter("mode", 1)
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	gas = ImageTexture.create_from_image(vp.get_texture().get_image())
	vp.queue_free()
