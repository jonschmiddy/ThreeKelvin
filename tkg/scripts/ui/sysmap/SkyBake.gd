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
	# eight bits a channel, a 64th of a unit a step: the brightest star is under four
	var bytes := PackedByteArray()
	bytes.resize(BW * BH * 4)
	for i: int in touched:
		bytes[i * 4] = mini(255, int(lb[i * 3] * 64.0))
		bytes[i * 4 + 1] = mini(255, int(lb[i * 3 + 1] * 64.0))
		bytes[i * 4 + 2] = mini(255, int(lb[i * 3 + 2] * 64.0))
		bytes[i * 4 + 3] = 255
	var stars := Image.create_from_data(BW, BH, false, Image.FORMAT_RGBA8, bytes)
	var stars_tex := ImageTexture.create_from_image(stars)

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
	m.set_shader_parameter("pulsar", kind == "PULSAR")
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
