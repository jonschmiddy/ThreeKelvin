extends RefCounted

## THE SECTOR MAP IN THE PAINTED STYLE: direction B of the Oct 5 showcase
## (scratchpad `showcase/B/sector/`, "a pixel artist's hand"), drawn by
## `SystemView` when the rendering style is PAINTED. Every pixel looks placed on
## purpose: cel bands on curated hue-shifted ramps, 1-block checker transitions
## between bands, outlines on the shadow side of big shapes and a rim of light
## on their lit side, sparkle sprites, a band memory so band edges never
## flicker -- and the life the other styles have, drawn as HAND ANIMATION:
## held poses that step, slow, never a one-frame flash.
##
## The far picture (the sky, the cloud round the system, the dust sheets, the
## far weather) is SIMPLIFIED's, drawn into its own viewport, so the cloud is
## the same cloud lit by the same sun, and every event of the weather lands
## where SIMPLIFIED's does. Then it is painted: the band memory
## (`sector_b_state`) gives every block one entry of the scene's curated palette
## (bible 4.2: never cut), and the paint pass (`sector_b_paint`) finishes it as
## an artist would. Everything nearer -- the sun, the worlds and their rings and
## shadows, the belts, the hole, the pulsar -- paints itself in its own painted
## mode, on the same tokens.
##
## Three viewports, nested so each is drawn before the one that reads it: the
## place picture > the band memory > the far picture.

const STATE_SH := preload("res://shaders/sector_b_state.gdshader")
const PAINT_SH := preload("res://shaders/sector_b_paint.gdshader")
const SystemPaletteS := preload("res://scripts/ui/sysmap/SystemPalette.gd")
const SkyBakeS := preload("res://scripts/ui/sysmap/SkyBake.gd")

## B's tokens (bible 4.2; the painted chart's `ChartPainted.RAMPS` are the same).
const SKY := ["#070a12", "#0b1020", "#121a30"]
const ARM := ["#0f1230", "#1d2a5c", "#2f4c91", "#4f7bc6", "#86b2e8", "#cfe6fb"]
const KNOT := ["#4a1638", "#9c3266", "#e2678f", "#ffb3c4"]
const BULGE := ["#2a0d1e", "#5e1c1e", "#9c3a1e", "#d26a26", "#f0a040", "#fbd27a", "#fff3d0"]
const BILLOW := ["#141228", "#2b2142", "#50345a", "#8a5062", "#c87b62", "#f1b583"]
const DUST := ["#08060c", "#140d14", "#26171a", "#3e2620"]
const HA := ["#2e0a22", "#6b1434", "#b8274a", "#ef5068", "#ff9c9a"]
const OIII := ["#0b2f3a", "#157a7e", "#38c4ad", "#a6f5df"]
const REFL := ["#0d1638", "#1c3478", "#3462bf", "#6a9cf0", "#bcd8ff"]
const HOLE := ["#1e0804", "#4a1406", "#84280c", "#c24a14", "#ec7a26", "#ffb054", "#ffdc96", "#fff6e2"]
## the stars, dim to bright in three families (cool, warm, red): a sparkle's arms
## are the step below its heart
const STARS := [["#1c2236", "#3a4766", "#7d93c4", "#d6e4ff"], ["#2a2420", "#6e5e48", "#ffd8a0", "#fff6e2"], ["#3a1c1a", "#8a4a38", "#ff9e6a"]]

## ramp flags: SOFT its bands checker, SHAPE outline and rim, SPARK a sprite,
## DARK no checker on its lowest steps
const SOFT := 1
const SHAPE := 2
const SPARK := 4
const DARKF := 8

## THE SCENE'S LOOK FOR ITS WORLDS (B's `LOOK`): the sky's ambient their night
## sides lean to, the outline, the bounce on their night limbs; by sky.
const LOOK := {
	&"emission": ["#50345a", "#12040e", "#9c3266"],
	&"reflection": ["#1d2a5c", "#060a18", "#3462bf"],
	&"planetary": ["#2b2142", "#0a0614", "#157a7e"],
	&"remnant": ["#2e0a22", "#0c0410", "#157a7e"],
	&"dark": ["#26171a", "#070508", "#3e2620"],
	&"calm": ["#121a30", "#05070c", "#121a30"],
	&"core": ["#5e1c1e", "#0e0404", "#9c3a1e"],
	&"pulsar": ["#2c2466", "#0a0818", "#157a7e"],
}
## THE STAR'S LIGHT ON A CLEAR SKY, by star: two banded rings stepped out into
## the sky (hand-picked: an OKLab mix of navy and orange passes through grey)
const HALO := {
	"ORDINARY": ["#15111f", "#2b1820", "#4e2a1c", "#7a4320"],
	"RED": ["#170b14", "#2e1018", "#541a16", "#86301a"],
	"BLUE": ["#0d1226", "#162246", "#24396e", "#3a5a9c"],
	"PULSAR": ["#0d1226", "#162246", "#24396e", "#3a5a9c"],
	"CORE": ["#1a0c10", "#3a1a12", "#5e2c14", "#8a4a1c"],
}


## The sky's key for a system as `SkyWeather` names it: the cloud's kind, or
## calm, the pulsar's or the core's.
static func sky_key(v) -> StringName:
	if v.layout.star == SystemLayout.StarKind.PULSAR:
		return &"pulsar"
	if v.layout.star == SystemLayout.StarKind.CORE:
		return &"core"
	if v._neb_mat == null:
		return &"calm"
	return [&"emission", &"reflection", &"planetary", &"remnant", &"dark"][clampi(int(v._sky_look.neb), 0, 4)]


## The scene's ramps: [name, colours darkest first, flags], by sky.
static func scene_ramps(v) -> Array:
	var key := sky_key(v)
	# (a clear sky's band checkers into the black at its edge, as B's: held flat,
	# its edge read as a cut-out shape)
	var out: Array = [["SKY", SKY, SOFT if key == &"calm" else SOFT | DARKF]]
	for i in STARS.size():
		out.append(["ST%d" % i, STARS[i], SPARK])
	# the distant galaxies (`SkyGalaxies`): their arm blues and the bulge's creams,
	# in a clear sky only (in a cloud they are hidden, and their steps caught the
	# cloud: a pulsar's violet shell set in galaxy blues)
	if key == &"calm":
		out.append(["GXA", [ARM[1], ARM[2], ARM[3], ARM[4]], SOFT])
		out.append(["GXB", [BULGE[1], BULGE[2], BULGE[3], BULGE[4], BULGE[5]], SOFT])
	match key:
		&"emission":
			# (B's own: violet undersides, plum, rose, the lit tops pink; the far gas
			# the cooler billow steps)
			out.append(["GM", [BILLOW[0], BILLOW[1], BILLOW[2], KNOT[1], HA[3], HA[4]], SOFT | SHAPE])
			out.append(["GF", [BILLOW[0], BILLOW[1], BILLOW[2], BILLOW[3]], SOFT | DARKF])
			# (the hot zone is big and smooth: two steps between the tokens, or it set
			# as one flat teal plate)
			out.append(["GO", [OIII[0], OIII[1], "#249e93", OIII[2], "#6edcc4", OIII[3]], SOFT])
			out.append(["DU", [DUST[0], BILLOW[0], BILLOW[1], KNOT[0]], SOFT | SHAPE | DARKF])
			out.append(["EV", ["#ffe8f0", "#b8f0e8"], SPARK])
		&"reflection":
			out.append(["GM", [REFL[0], REFL[1], ARM[2], REFL[2], REFL[3], REFL[4]], SOFT | SHAPE])
			out.append(["GF", [SKY[1], ARM[0], ARM[1]], SOFT | DARKF])
			out.append(["EV", ["#dcecff"], SPARK])
		&"planetary":
			out.append(["GO", OIII, SOFT | SHAPE])
			out.append(["GK", [BILLOW[1], BILLOW[2], BILLOW[3], KNOT[2], KNOT[3]], SOFT | SHAPE])
			out.append(["GM", HA, SOFT])
			out.append(["EV", ["#fff6e2"], SPARK])
		&"remnant":
			out.append(["GF", [BILLOW[0], BILLOW[1], BILLOW[2]], SOFT | DARKF])
			# (the strands' rose in the knots' softer steps: H-alpha's own top steps set
			# the lit tangles as hot red slabs)
			out.append(["GM", [HA[0], KNOT[0], HA[1], KNOT[1], KNOT[2]], SOFT | SHAPE])
			out.append(["GO", OIII, SOFT | SHAPE])
			out.append(["EV", ["#d6e4ff"], SPARK])
		&"dark":
			out.append(["DU", [DUST[0], DUST[1], BILLOW[0], BILLOW[1], BILLOW[2]], SOFT | SHAPE | DARKF])
			out.append(["GM", [BILLOW[3], BILLOW[4], BILLOW[5]], SOFT | SHAPE])
			out.append(["EV", ["#ffb054", "#d8d0ff"], SPARK])
		&"core":
			# (B's core: the galaxy's heart in warm puffs, dust brown to bulge cream)
			out.append(["GM", [DUST[1], BULGE[0], BULGE[1], BULGE[2], BULGE[3], BULGE[4], BULGE[5]], SOFT | SHAPE])
			out.append(["GF", [DUST[1], DUST[2], DUST[3], BULGE[1]], SOFT | DARKF])
			out.append(["DU", [DUST[0], DUST[1], DUST[2]], SOFT | SHAPE | DARKF])
			out.append(["EV", ["#fff6e2"], SPARK])
		&"pulsar":
			# (B's pulsar: a violet pool of its light, the shell's rim rose)
			out.append(["GF", ["#0b1020", "#1c1640", "#2c2466", "#463a94", "#7a6ad8", "#b8a8ff"], SOFT | DARKF])
			out.append(["GM", HA, SOFT | SHAPE])
			out.append(["BEAM", ["#4f9ce0", "#a8e0ff", "#eafcff"], SOFT])
		_:
			# a clear sky: the galaxy's band in two tones, the star's light in rings
			out.append(["GF", [ARM[0], ARM[1]], SOFT | DARKF])
			# (all four: the rings are stepped in the sky, so the faintest no longer
			# catches a long faint reach and sets the sky round the sun as a brown plate)
			out.append(["HALO", HALO.get(v.kind, HALO.ORDINARY), SOFT])
	# (B's form, the clouds built of sheets: their band edges are the domes' and
	# lobes' own curves, so no checker along them -- on those edges it read as a saw)
	if key in [&"emission", &"reflection", &"core"]:
		for r: Array in out:
			if String(r[0]) in ["GM", "GF", "GO", "DU"]:
				r[2] = int(r[2]) & ~SOFT
	return out


## How much the far picture's colour is pushed before it is matched: SIMPLIFIED's
## cloud is muted where B's tokens are vivid, and matched as it is, a dim rose
## fell to the nearest grey-violet and the cloud set in blotches of two families.
static func chroma_boost(v) -> float:
	return {&"emission": 1.6, &"reflection": 1.5, &"planetary": 1.4, &"remnant": 1.3, &"dark": 1.3, &"core": 1.15, &"pulsar": 1.5}.get(sky_key(v), 1.3)


## The palette and its lookups for a scene: the palette texture, each entry's
## ramp and step and OKLab, each ramp's length and flags, the stars' entries.
static func tables(v) -> Dictionary:
	var ramps := scene_ramps(v)
	var cols: Array[Color] = []
	var grp := PackedInt32Array()
	var stp := PackedInt32Array()
	var lab := PackedVector3Array()
	var glen := PackedInt32Array()
	var gfl := PackedInt32Array()
	var star0 := -1
	var star_n := 0
	var halo0 := -1
	var wisp0 := -1
	for gi in ramps.size():
		var r: Array = ramps[gi]
		var rc: Array = r[1]
		glen.append(rc.size())
		gfl.append(int(r[2]))
		if String(r[0]) == "HALO":
			halo0 = cols.size()
		if String(r[0]) == "GF" and sky_key(v) == &"calm":
			wisp0 = cols.size()
		if (int(r[2]) & SPARK) != 0 and String(r[0]).begins_with("ST"):
			if star0 < 0:
				star0 = cols.size()
			star_n += rc.size()
		for si in rc.size():
			var c := Color(String(rc[si]))
			cols.append(c)
			grp.append(gi)
			stp.append(si)
			lab.append(SystemPaletteS.oklab(Vector3(c.r, c.g, c.b)))
	var n := cols.size()
	var img := Image.create(128, 1, false, Image.FORMAT_RGBA8)
	for i in mini(128, n):
		img.set_pixel(i, 0, cols[i])
	grp.resize(96)
	stp.resize(96)
	lab.resize(96)
	glen.resize(32)
	gfl.resize(32)
	return {"pal": ImageTexture.create_from_image(img), "grp": grp, "step": stp, "lab": lab, "glen": glen,
		"gfl": gfl, "n": n, "star0": maxi(star0, 0), "star_n": star_n, "cols": cols, "halo0": halo0, "wisp0": wisp0}


## The world painter's look for this scene: (ambient, outline, bounce), linear.
static func world_look(v) -> Array:
	var l: Array = LOOK.get(sky_key(v), LOOK[&"calm"])
	var out: Array = []
	for h: String in l:
		var c := Color(h)
		out.append(Vector3(c.r, c.g, c.b))
	return out


## THE THREE VIEWPORTS (the far picture, its band memory, and the paint rect
## in the place picture), each one block a pixel. Returns the far picture's
## viewport, for the screen to put everything far into.
static func build(v) -> SubViewport:
	var T := tables(v)
	var tvp := SubViewport.new()
	tvp.size = Vector2i(480, 270)
	tvp.transparent_bg = false
	tvp.disable_3d = true
	tvp.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
	tvp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	tvp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	v._scene.add_child(tvp)
	var svp := SubViewport.new()
	svp.size = Vector2i(480, 270)
	svp.size_2d_override = Vector2i(960, 540)
	svp.size_2d_override_stretch = true
	svp.transparent_bg = false
	svp.disable_3d = true
	svp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	tvp.add_child(svp)
	var ms := ShaderMaterial.new()
	ms.shader = STATE_SH
	ms.set_shader_parameter("src", svp.get_texture())
	ms.set_shader_parameter("u_lab", T.lab)
	ms.set_shader_parameter("u_n", T.n)
	ms.set_shader_parameter("u_star0", T.star0)
	ms.set_shader_parameter("u_star_n", T.star_n)
	ms.set_shader_parameter("cboost", chroma_boost(v))
	ms.set_shader_parameter("calm", sky_key(v) == &"calm")
	ms.set_shader_parameter("u_halo0", int(T.get("halo0", -1)))
	ms.set_shader_parameter("u_wisp0", int(T.get("wisp0", -1)))
	# (the band's lie per system, about B's own)
	var ba := atan2(0.922, 0.387) + (fposmod(float(v.node.index) * 0.6180339, 1.0) - 0.5) * 1.1
	ms.set_shader_parameter("band_n", Vector2(cos(ba), sin(ba)))
	ms.set_shader_parameter("band_off", (fposmod(float(v.node.index) * 0.4142136, 1.0) - 0.5) * 160.0)
	var sr := ColorRect.new()
	sr.size = Vector2(480, 270)
	sr.material = ms
	sr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tvp.add_child(sr)
	var mp := ShaderMaterial.new()
	mp.shader = PAINT_SH
	mp.set_shader_parameter("state", tvp.get_texture())
	mp.set_shader_parameter("pal", T.pal)
	mp.set_shader_parameter("u_grp", T.grp)
	mp.set_shader_parameter("u_step", T.step)
	mp.set_shader_parameter("u_glen", T.glen)
	mp.set_shader_parameter("u_gfl", T.gfl)
	mp.set_shader_parameter("u_star0", T.star0)
	mp.set_shader_parameter("u_star_n", T.star_n)
	var pr := ColorRect.new()
	pr.size = Vector2(960, 540)
	pr.material = mp
	pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v._scene.add_child(pr)
	# (a clear sky's glow without its shafts: they set the rings ragged)
	v._sky_mat.set_shader_parameter("rays_k", 0.0)
	v._sky_mat.set_shader_parameter("painted", true)
	if v._neb_mat != null:
		v._neb_mat.set_shader_parameter("blk_flow", true)
		paint_cloud(v)
	v._pt = {"tvp": tvp, "svp": svp, "state": ms, "paint": mp, "rect": pr, "T": T, "frames": 0, "rock": ext_ramp(v, &"rock"), "moon": ext_ramp(v, &"moon")}
	return svp


## Every frame: where the star is, the clock, the far picture's slide.
static func push(v) -> void:
	var pt: Dictionary = v._pt
	if pt.is_empty():
		return
	var ms: ShaderMaterial = pt.state
	var mp: ShaderMaterial = pt.paint
	var blk: Vector2 = -v.neb_off() / 2.0
	var low: bool = v.gfx_low()
	pt.frames = int(pt.frames) + 1
	ms.set_shader_parameter("reset", int(pt.frames) < 3)
	ms.set_shader_parameter("sky_blk", blk)
	ms.set_shader_parameter("low", low)
	ms.set_shader_parameter("star_px", v.origin())
	ms.set_shader_parameter("sun_r", float(v.layout.star_r) * float(v.star_k()))
	mp.set_shader_parameter("star_at", v.origin())
	mp.set_shader_parameter("time", v.pose(v.t))
	mp.set_shader_parameter("sky_blk", blk)
	mp.set_shader_parameter("low", low)


## A world painted (B): its cel bands, its night side leaning to the sky's
## ambient, its outline and bounce, on it and on its rings.
static func paint_world(v, node: Node) -> void:
	var lk := world_look(v)
	_deep(node, "painted", true)
	_deep(node, "p_amb", lk[0])
	_deep(node, "p_out", lk[1])
	_deep(node, "p_bounce", lk[2])


static func _deep(n: Node, key: String, value: Variant) -> void:
	if n is CanvasItem and (n as CanvasItem).material is ShaderMaterial:
		((n as CanvasItem).material as ShaderMaterial).set_shader_parameter(key, value)
	for c in n.get_children():
		_deep(c, key, value)


## Two colours mixed in OKLab (B's `mixOk`), `dl` added to the lightness.
static func mix_ok(a: Color, b: Color, t: float, dl: float = 0.0) -> Color:
	var A: Vector3 = SystemPaletteS.oklab(Vector3(a.r, a.g, a.b))
	var B: Vector3 = SystemPaletteS.oklab(Vector3(b.r, b.g, b.b))
	var L := A.lerp(B, t) + Vector3(dl, 0.0, 0.0)
	var l := L.x + 0.3963377774 * L.y + 0.2158037573 * L.z
	var m := L.x - 0.1055613458 * L.y - 0.0638541728 * L.z
	var s := L.x - 0.0894841775 * L.y - 1.2914855480 * L.z
	l = l * l * l
	m = m * m * m
	s = s * s * s
	var lin := Vector3(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s, -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s, -0.0041960771 * l - 0.7034186147 * m + 1.7076147010 * s)
	var f := func(x: float) -> float: return 12.92 * x if x <= 0.0031308 else 1.055 * pow(x, 1.0 / 2.4) - 0.055
	return Color(clampf(f.call(maxf(lin.x, 0.0)), 0.0, 1.0), clampf(f.call(maxf(lin.y, 0.0)), 0.0, 1.0), clampf(f.call(maxf(lin.z, 0.0)), 0.0, 1.0))


## B's extended ramp for a world's stuff (`extRamp`): outline, night and dusk
## (leaning to the sky's ambient), its own steps 1..4, its brightest warmed by
## the star's own light. For the belts' rocks and the moons.
static func ext_ramp(v, name: StringName) -> Array[Color]:
	var r: Array = Worlds.RAMP.get(name, Worlds.RAMP[&"rock"])
	var lk: Array = LOOK.get(sky_key(v), LOOK[&"calm"])
	var amb := Color(String(lk[0]))
	var sl: Vector3 = v.star_light()
	var star := Color(pow(sl.x, 1.0 / 2.2), pow(sl.y, 1.0 / 2.2), pow(sl.z, 1.0 / 2.2))
	var out: Array[Color] = [Color(String(lk[1])), mix_ok(Color(String(r[0])), amb, 0.5), mix_ok(Color(String(r[1])), amb, 0.34)]
	for i in range(1, 5):
		out.append(Color(String(r[i])))
	out.append(mix_ok(Color(String(r[5])), star, 0.3))
	return out


## THE CLOUD PAINTED WITH FORM (round 2): the scene's cloud ramps handed to the
## cloud itself (`sky_nebula.gdshader`, `painted`), which picks its ramp and its
## place on it, builds its thick parts of lit puffs and pushes an event's light
## up the ramp; the band memory then bands it and holds the bands.
static func paint_cloud(v) -> void:
	var m: ShaderMaterial = v._neb_mat
	if m == null:
		return
	var ramps := scene_ramps(v)
	var key := sky_key(v)
	var cols: Array[Color] = []
	var lab := PackedVector3Array()
	var grp := PackedInt32Array()
	var start := PackedInt32Array()
	var ln := PackedInt32Array()
	var l0 := PackedFloat32Array()
	var l1 := PackedFloat32Array()
	var slot := {}
	for r: Array in ramps:
		var name := String(r[0])
		if name.begins_with("ST") or name.begins_with("GX") or name == "HALO" or name == "BEAM":
			continue
		var g := start.size()
		slot[name] = g
		start.append(cols.size())
		var rc: Array = r[1]
		ln.append(rc.size())
		var labs: Array[Vector3] = []
		for h: String in rc:
			var c := Color(h)
			var L: Vector3 = SystemPaletteS.oklab(Vector3(c.r, c.g, c.b))
			labs.append(L)
			if name != "EV":
				lab.append(L)
				grp.append(g)
			cols.append(c)
		l0.append(labs[0].x)
		l1.append(labs[labs.size() - 1].x)
	var img := Image.create(64, 1, false, Image.FORMAT_RGBA8)
	for i in mini(64, cols.size()):
		img.set_pixel(i, 0, cols[i])
	var ne := lab.size()
	lab.resize(64)
	grp.resize(64)
	for a in [start, ln]:
		(a as PackedInt32Array).resize(12)
	l0.resize(12)
	l1.resize(12)
	m.set_shader_parameter("painted", true)
	m.set_shader_parameter("p_pal", ImageTexture.create_from_image(img))
	m.set_shader_parameter("p_lab", lab)
	m.set_shader_parameter("p_grp", grp)
	m.set_shader_parameter("p_ne", ne)
	m.set_shader_parameter("p_start", start)
	m.set_shader_parameter("p_len", ln)
	m.set_shader_parameter("p_l0", l0)
	m.set_shader_parameter("p_l1", l1)
	m.set_shader_parameter("p_sky", int(slot.get("SKY", 0)))
	# (a dark cloud's puffs are its dust, lit at their edges)
	m.set_shader_parameter("p_gm", int(slot.get("DU", 0)) if key == &"dark" else int(slot.get("GM", slot.get("DU", 0))))
	m.set_shader_parameter("p_k", {&"emission": Vector3(1.2, 3.8, 1.4), &"reflection": Vector3(0.6, 3.8, 1.0), &"core": Vector3(1.0, 3.4, 1.4), &"dark": Vector3(0.4, 1.4, 1.2)}.get(key, Vector3(0.6, 3.6, 1.2)))
	m.set_shader_parameter("p_ev", int(slot.get("EV", -1)))
	m.set_shader_parameter("p_gf", int(slot.get("GF", -1)))
	m.set_shader_parameter("p_du", -1 if key == &"dark" else int(slot.get("DU", -1)))
	m.set_shader_parameter("p_cb", chroma_boost(v))
	m.set_shader_parameter("p_puffs", key in [&"emission", &"reflection", &"dark", &"core"])
	m.set_shader_parameter("p_cell", 110.0)
	m.set_shader_parameter("p_dim", 1.0)
	# (the core's gas lit by the disc breaks through only for the weather: the hole stays the star)
	m.set_shader_parameter("p_brk", 0.8)
	# B's form (`bake_puffs`): the scene, the hot zone's ramp, each sheet's look and the light
	m.set_shader_parameter("p_go", int(slot.get("GO", -1)))
	m.set_shader_parameter("p_scene", {&"emission": 0, &"reflection": 1, &"core": 3, &"dark": 5}.get(key, 0))
	m.set_shader_parameter("p_look", PUFF_LOOK.get(key, PUFF_LOOK[&"emission"]))
	m.set_shader_parameter("p_light", PUFF_LIGHT.get(key, PUFF_LIGHT[&"emission"]))
	# (how dense dust must be to stand as dust over the gas: the core's lanes only at
	# their spines, B's thin arcs; wide, they cut its heart into dark plates)
	m.set_shader_parameter("p_dust_tau", 0.9 if key == &"core" else 0.6)


## B'S FORM's numbers, by sky: each sheet's (amb, glow, light) -- how much a
## puff's shadow side keeps, the gas's own glow, what the star adds near it (B's
## `lookOf`) -- and the light (soft and hard radii, the hot zone's, its height;
## B's `LIGHT`, light px)
const PUFF_LOOK := {
	&"emission": [Vector3(0.66, 0.56, 0.40), Vector3(0.52, 0.74, 0.50), Vector3(0.42, 0.72, 0.58)],
	&"reflection": [Vector3(0.60, 0.40, 0.50), Vector3(0.42, 0.50, 0.80), Vector3(0.32, 0.46, 0.90)],
	&"core": [Vector3(0.60, 0.58, 0.45), Vector3(0.44, 0.48, 0.62), Vector3(0.34, 0.42, 0.70)],
	&"dark": [Vector3(0.60, 0.30, 0.40), Vector3(0.44, 0.34, 0.60), Vector3(0.34, 0.30, 0.66)],
}
const PUFF_LIGHT := {
	&"emission": Vector4(190.0, 52.0, 80.0, 90.0),
	&"reflection": Vector4(160.0, 45.0, 80.0, 85.0),
	&"core": Vector4(190.0, 30.0, 0.0, 100.0),
	&"dark": Vector4(160.0, 42.0, 0.0, 85.0),
}
const PUFFS_SH := preload("res://shaders/sector_b_puffs.gdshader")


## B'S FORM, baked once a system: the cloud's three gas sheets of domed masses and
## lobes (`sector_b_puffs`), laid where SIMPLIFIED's own cloud is (`field`, its
## density, smoothed heavily), for the cloud to paint from (`p_sheets`).
static func bake_puffs(v, field: Texture2D) -> void:
	var m: ShaderMaterial = v._neb_mat
	# (not a dark cloud: B has none, and built of sheets it lost its lit amber rims)
	if m == null or not (sky_key(v) in [&"emission", &"reflection", &"core"]):
		return
	var w: int = SkyBakeS.FIELD_W
	var h: int = SkyBakeS.FIELD_H
	var vp := SubViewport.new()
	vp.size = Vector2i(w, h * 4)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	var rect := ColorRect.new()
	rect.size = Vector2(w, h * 4)
	var bm := ShaderMaterial.new()
	bm.shader = PUFFS_SH
	bm.set_shader_parameter("src", field)
	bm.set_shader_parameter("tex", Vector2(w, h))
	bm.set_shader_parameter("mb", float(SkyBakeS.FIELD_MB))
	bm.set_shader_parameter("sd", float(v.node.index % 97) * 0.37)
	bm.set_shader_parameter("kind", int(v._sky_look.neb))
	# (the sheets' thresholds by sky: B's clouds fill the frame, the mid gas most of it)
	bm.set_shader_parameter("thr", {&"emission": Vector3(0.16, 0.36, 0.62), &"reflection": Vector3(0.16, 0.40, 0.64), &"core": Vector3(0.03, 0.22, 0.50), &"dark": Vector3(0.20, 0.45, 0.68)}.get(sky_key(v), Vector3(0.16, 0.40, 0.64)))
	rect.material = bm
	vp.add_child(rect)
	v.add_child(vp)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	# (a harness's `puffdump=<png>`: the sheets saved, to see their shapes)
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with("puffdump=") and img != null:
			img.save_png((a as String).substr(9))
	m.set_shader_parameter("p_sheets", ImageTexture.create_from_image(img))
	m.set_shader_parameter("p_sheets_on", true)
