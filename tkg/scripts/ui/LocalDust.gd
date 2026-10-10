class_name LocalDust
extends Control

## LOCAL'S FOREGROUND DUST (Jon: "can we add some dust to the local? something
## in the more frontal layer?"; of the first take, "it kinda pops in and out and
## looks low res"; and of the second, with the chart and the map, "dust
## disappearing, dust looking flat and not visually interesting"): dust drifting
## between the camera and the fight, the nearest layers of all, in front of the
## ships -- and held to one rule above the look of it: it never covers a ship, a
## shot's line, a damage number, an intent or a name.
##
## DEPTH: five kinds of dust at their own distances, each with its own size,
## speed and slide with the camera (`LAYERS`) -- far specks a pixel across,
## crawling and sliding least; motes of gathered light; near motes, bigger and
## softer, faster; a few out-of-focus discs right in front of the lens, faint
## and quick; and now and then a thread of dust (a filament) or a knot of grains
## (a clump) drifting through at middle distance. The nearer, the faster it
## drifts and the further it slides when the camera moves.
##
## LIGHT: each is gathered light added over the sky (`local_dust.gdshader`), lit
## from the system's own star -- brighter on its side toward the star, brighter
## the nearer it hangs in front of the star in the picture (dust scatters the
## light that comes past it toward you), its core the star's colour. Now and then
## a mote turns and GLINTS: its core flares and a short cross of light grows from
## it, over most of a second, eased, never a flash.
##
## ZOOM ONLY ADDS DETAIL (Jon: "zooming in causes artifacts like pixels missing
## ... dust disappearing, dust looking flat"): the dust is drawn per GAME PIXEL
## whatever its own scale. Under the cutaway's push-in and the zoom ladder the
## scene scales this control; the dust takes that scale out and draws each mote
## again where the zoom puts it and at the size it puts it -- the nearer, the
## more it grows (`s^(1 + DEPTH_ZOOM * z)`), so the dust parts round the camera as
## it pushes in -- a speck growing a falloff, a mote a soft rim. Pulled back
## below LOCAL's own scale (the map's zoom, 2C) it fades out, as the map has no
## dust.
##
## NOTHING POPS: a mote's visibility (`vis`) eases toward what its place allows
## -- fading out over a ship's margin, the shots' band or the view's top edge,
## in over the clear sky -- a step of its dither at a time (`FADE_IN`,
## `FADE_OUT` a second), worked out every frame; the motes wrap round a strip
## wider than the view, so they come and go off screen; and a mote's place, its
## light and its glint each move on only once they have moved a whole step past
## where they were shown (hysteresis), so none of them goes A, B, A. Inside a
## ship's picture, a label or a gauge no pixel of dust is ever drawn (`keep`, a
## last guard). `LocalShot dustcheck` measures what it covers and how fast it
## fades; `dustonly` films it alone.
##
## BY STYLE: SIMPLIFIED light in dithered steps; PAINTED flat hand-picked steps,
## a held highlight at each mote's middle, the motes moved in held poses (eight a
## second); RADIANT the star's light spilling softly round each mote; LEGACY the
## old starfield's blue-greys, no glints.

const SH := preload("res://shaders/local_dust.gdshader")
## THE LAYERS, far to near: [count, count on GRAPHICS LOW, kind (0 mote, 1
## out-of-focus disc, 2 speck, 3 filament, 4 clump), depth z (lo, hi), radius
## px (lo, hi; a filament's half length), light (lo, hi), drift px/s (lo, hi),
## slide with the camera (lo, hi), share that glint]
const LAYERS := [
	[72, 34, 2, 0.0, 0.3, 0.6, 1.0, 0.4, 0.8, 1.5, 3.5, 0.5, 0.65, 0.0],
	[40, 18, 0, 0.3, 0.7, 1.4, 2.6, 0.6, 1.0, 4.0, 8.0, 0.72, 0.92, 0.4],
	[16, 8, 0, 0.7, 0.9, 2.8, 4.2, 0.45, 0.7, 9.0, 14.0, 0.98, 1.12, 0.3],
	[7, 3, 1, 0.9, 1.0, 6.0, 12.0, 0.8, 1.0, 14.0, 20.0, 1.2, 1.35, 0.0],
	[3, 1, 3, 0.45, 0.6, 45.0, 90.0, 0.7, 0.9, 2.0, 4.0, 0.8, 0.85, 0.0],
	[3, 1, 4, 0.5, 0.7, 10.0, 18.0, 0.7, 0.9, 3.0, 6.0, 0.82, 0.9, 0.0],
]
## how much more than the ship's own plane the nearest dust grows under a zoom
const DEPTH_ZOOM := 0.5
## round a ship, a label or a gauge: no dust within KEEP (px), thinning in over THIN
const KEEP := 14.0
const THIN := 30.0
## the middle band, as fractions of the arena's height (297 px of the view above
## the hand): the dust fades out over FEATHER px into it
const ARENA_H := 297.0
const SHOTS := Vector2(0.28, 0.78)
const FEATHER := 18.0
## how fast a mote's visibility may change, a second
const FADE_IN := 0.8
const FADE_OUT := 2.5
## the strip the motes wrap round, past each side of the view (px): wide enough
## that the wrap stays off screen until the dust has faded on a pull back
const WRAP := 300.0
## dust scattering the star's light toward you: up to this much brighter right
## in front of the star, over this reach (px)
const SCATTER := Vector2(1.1, 260.0)
## the steps a mote's place, light and glint must move past before they are
## shown moved (hysteresis: no A, B, A)
const HOLD_PX := 0.75
const HOLD_L := 0.035
const HOLD_G := 0.06
const HOLD_V := 0.05
const HOLD_A := 0.15

var sky: LocalSky = null
var view: Control = null
var _mat: ShaderMaterial
var _mm: MultiMesh
var _mmi: MultiMeshInstance2D
var _motes: Array = []
var _t := 0.0
var _key := ""
var _style := 0
var _buf := PackedFloat32Array()
## frames drawn (a mote's last step is counted in them)
var _n := 0
## the largest change of any mote's visibility in a frame, and how many frames
## changed one by more than ABRUPT (`LocalShot dustcheck`)
const ABRUPT := 0.1
var worst_step := 0.0
var abrupt := 0
## the rects drawn over last (`LocalShot dustcheck`): every mote's box, px from
## this control's global position
var boxes: Array[Rect2] = []
static var off := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = SH
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_2D
	_mm.use_colors = true
	_mm.use_custom_data = true
	_mm.mesh = _quad()
	_mmi = MultiMeshInstance2D.new()
	_mmi.multimesh = _mm
	_mmi.material = _mat
	_mmi.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_mmi)


## One unit quad, -0.5..0.5, its UVs 0..1 left to right and top to bottom.
static func _quad() -> ArrayMesh:
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)])
	a[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	a[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	return m


func _process(delta: float) -> void:
	if off:
		visible = false
		return
	if sky == null or sky.node == null or size.x <= 0.0:
		return
	var key := "%d|%s|%s" % [sky.node.index, sky.style, DisplaySettings.graphics_low]
	if key != _key:
		_key = key
		_seed_motes()
	var dt := minf(delta, 1.0 / 30.0)
	_n += 1
	if not DisplaySettings.reduced_motion:
		_t += dt
	# (PAINTED: the dust moves in held poses, eight a second)
	var tt := floorf(_t * 8.0) / 8.0 if _style == 1 else _t
	var X := get_global_transform()
	var s_own := X.get_scale().x
	var Xi := X.affine_inverse()
	# THE ZOOM: how far the scene is pushed in (or pulled back), and the point it
	# is pushed in on, in the game's own px
	var zs := 1.0
	var zp := X.origin
	if is_instance_valid(sky) and not is_equal_approx(sky.zoom, 1.0):
		zs = sky.zoom
		zp = sky.scene_to_global(sky._zoom_to)
	# (pulled back toward the map's scale, the dust fades out: the map has none)
	var zv := 1.0 if zs >= 1.0 else smoothstep(0.55, 0.92, zs)
	var rects := _keep_out()
	# (the star where it is drawn, in the game's px)
	var star := sky.star_global()
	var step := 0.0
	boxes.clear()
	var n := 0
	var cap := _motes.size()
	if _buf.size() != cap * 16:
		_buf.resize(cap * 16)
	var origin := X.origin
	for m: Dictionary in _motes:
		var p := _rest_at(m, tt)
		var e := 1.0 + DEPTH_ZOOM * float(m.z)
		var ze := pow(zs, e)
		# where the zoom puts it, and how big
		var g := zp + (X * p - zp) * (ze / zs) if zs != 1.0 else X * p
		var R := float(m.r) * ze
		var kind := int(m.kind)
		if kind == 2 and R > 1.2:
			# (a far speck seen closer: a mote, with its fall of light)
			kind = 0
		# ITS GLINT: a slow turn catching the light, eased; held a step
		var gl := 0.0
		if float(m.gw) > 0.0 and _style != 3:
			gl = pow(maxf(0.0, sin(tt * float(m.gw) + float(m.gph))), 14.0)
		if absf(gl - float(m.gl_shown)) > HOLD_G or (gl == 0.0 and float(m.gl_shown) < HOLD_G):
			m.gl_shown = gl
		var ext := _ext(kind, R, float(m.aux) * ze, float(m.gl_shown))
		var want := _allow(p, float(m.ry), g, ext, rects)
		var v: float = m.vis
		var nv := v + clampf(want - v, -FADE_OUT * dt, FADE_IN * dt)
		step = maxf(step, absf(nv - v))
		m.vis = nv
		# ITS PLACE, held until it has moved a whole step on (whole px, centres),
		# and held at least two frames once moved: a mote with any texture (a
		# disc's lit rim, a clump's grains) that stepped a pixel EVERY frame showed
		# each pixel under it a different part of it each frame, A, B, A -- read
		# as shimmer. A near mote faster than that steps two px at once instead.
		# (Not under a zoom or a fast camera: then it goes where it is carried.)
		var sx: float = m.sx
		var sy: float = m.sy
		var lag := maxf(absf(g.x - sx), absf(g.y - sy))
		if is_nan(sx) or is_nan(sy) or (lag >= HOLD_PX and (_n - int(m.mf) >= 2 or lag > 2.5 or zs != 1.0)):
			if is_nan(sx) or absf(g.x - sx) >= HOLD_PX:
				sx = floorf(g.x) + 0.5
			if is_nan(sy) or absf(g.y - sy) >= HOLD_PX:
				sy = floorf(g.y) + 0.5
			m.mf = _n
		m.sx = sx
		m.sy = sy
		# ITS LIGHT: the star's light scattered toward you, the nearer it hangs in
		# front of the star the more; held until it moves a step
		var sd := Vector2(sx, sy).distance_to(star)
		var li := float(m.inten) * (1.0 + SCATTER.x * _scatter_k() * exp(-sd / SCATTER.y))
		if absf(li - float(m.l_shown)) > HOLD_L:
			m.l_shown = snappedf(li, HOLD_L * 0.5)
		# ITS VISIBILITY AND THE SIDE IT IS LIT FROM, as drawn: held until they move
		# a step on, like its place -- a mote whose light sat on a dither step's
		# edge tipped a pixel on and off as the fade crept (A, B, A)
		var show := nv * zv
		if show <= 0.002:
			m.v_shown = 0.0
			continue
		if absf(show - float(m.v_shown)) >= HOLD_V or (show >= 0.999 and float(m.v_shown) < 1.0):
			m.v_shown = minf(snappedf(show, HOLD_V * 0.5), 1.0)
		show = maxf(float(m.v_shown), 0.004)
		var c := Vector2(sx, sy)
		var ang := (star - c).angle()
		if absf(angle_difference(ang, float(m.a_shown))) >= HOLD_A:
			m.a_shown = ang
		ang = float(m.a_shown)
		# the quad: centre and size in this control's own px (its scale taken out)
		var lc := Xi * c
		var qx := (2.0 * ext.x + 1.0) / s_own
		var qy := (2.0 * ext.y + 1.0) / s_own
		var o := n * 16
		_buf[o] = qx
		_buf[o + 1] = 0.0
		_buf[o + 2] = 0.0
		_buf[o + 3] = lc.x
		_buf[o + 4] = 0.0
		_buf[o + 5] = qy
		_buf[o + 6] = 0.0
		_buf[o + 7] = lc.y
		_buf[o + 8] = float(m.l_shown)
		_buf[o + 9] = float(m.aux) * ze if kind == 3 else float(m.gl_shown)
		_buf[o + 10] = show
		_buf[o + 11] = ext.x
		_buf[o + 12] = R if kind != 3 else float(m.r) * ze
		_buf[o + 13] = float(kind)
		_buf[o + 14] = float(m.seed)
		_buf[o + 15] = ang
		n += 1
		boxes.append(Rect2(c - ext - Vector2(0.5, 0.5) - origin, ext * 2.0 + Vector2.ONE))
	worst_step = maxf(worst_step, step)
	if step > ABRUPT:
		abrupt += 1
	if _mm.instance_count != cap:
		_mm.instance_count = cap
	# (only the first `n` drawn)
	_mm.buffer = _buf
	_mm.visible_instance_count = n
	var kp := PackedVector4Array()
	for r in rects:
		if kp.size() >= 40:
			break
		kp.append(Vector4(r.position.x - 1.0, r.position.y - 1.0, r.size.x + 2.0, r.size.y + 2.0))
	var nk := kp.size()
	kp.resize(40)
	_mat.set_shader_parameter("keep", kp)
	_mat.set_shader_parameter("n_keep", nk)
	var vp := get_viewport()
	if vp != null:
		_mat.set_shader_parameter("view_px", Vector2(vp.get_visible_rect().size))


## How far a mote's quad reaches from its middle, px: its radius and a pixel of
## fall (a glint's cross further), a filament its half length and height.
static func _ext(kind: int, R: float, H: float, gl: float) -> Vector2:
	if kind == 3:
		return Vector2(ceilf(R) + 2.0, ceilf(H) + 2.0)
	var h := ceilf(R) + 2.0
	if kind == 0:
		h = ceilf(R + 1.0 + 5.0 * maxf(gl, 0.0)) + 1.0
	return Vector2(h, h)


func _scatter_k() -> float:
	match _style:
		2:
			return 1.8
		3:
			return 0.5
	return 1.0


func _h(a: int, b: int) -> float:
	return LocalSky.SkyBakeS.hash2(a, b)


## The dust of this system, layer by layer, and its colours.
func _seed_motes() -> void:
	_motes.clear()
	_style = {&"painted": 1, &"radiant": 2, &"legacy": 3}.get(sky.style, 0)
	var idx: int = sky.node.index
	var low := DisplaySettings.graphics_low
	var wind := 1.0 if _h(idx, 9) < 0.5 else -1.0
	var k := 0
	for li in LAYERS.size():
		var L: Array = LAYERS[li]
		var cnt: int = L[1] if low else L[0]
		for j in cnt:
			k += 1
			var hs := idx * 131 + k * 7
			var z := lerpf(L[3], L[4], _h(hs, 1))
			var depth_k := _h(hs, 2)
			var r := lerpf(L[5], L[6], depth_k)
			var kind: int = L[2]
			# (the vertical half reach: a filament's height, a clump's or a disc's radius)
			var aux := 0.0
			var ry := r + 1.0
			if kind == 3:
				aux = 8.0 + 9.0 * _h(hs, 3)
				ry = aux + 2.0
			var glint := _h(hs, 4) < float(L[13])
			_motes.append({
				"x": _h(hs, 5) * 2000.0, "y": _h(hs, 6), "z": z, "kind": kind, "r": r, "aux": aux, "ry": ry,
				"inten": lerpf(L[7], L[8], _h(hs, 7)),
				"vx": lerpf(L[9], L[10], _h(hs, 8)) * wind,
				"f": lerpf(L[11], L[12], depth_k),
				"ph": _h(hs, 10) * 100.0, "bob": 0.8 + 2.2 * z,
				"seed": _h(hs, 11),
				"gw": (0.22 + 0.3 * _h(hs, 12)) if glint else 0.0, "gph": _h(hs, 13) * TAU,
				"vis": 0.0, "sx": NAN, "sy": NAN, "l_shown": 0.0, "gl_shown": 0.0, "v_shown": 0.0, "a_shown": 0.0, "mf": -9,
			})
	_colours()


## The light the system's dust gathers, by style.
func _colours() -> void:
	var look: Dictionary = sky._sky_look
	_mat.set_shader_parameter("style", _style)
	# its body: the cloud's own colour lifted, a warm grey in a clear sky, the old
	# starfield's blue-grey in LEGACY; its core: the star's light
	var g := Color("#c8bcb0")
	if sky._neb_mat != null and look.has("hue"):
		var hh: Vector3 = look.hue
		g = Color(hh.x, hh.y, hh.z).lerp(Color("#d8d0c8"), 0.45)
	var sl: Vector3 = sky.star_light()
	var core := Color(sl.x, sl.y, sl.z).lerp(Color(1, 1, 1), 0.55)
	if _style == 3:
		g = Color("#9fb0c8")
		core = Color("#c8d4e4")
	elif _style == 2:
		g = Color(sl.x, sl.y, sl.z).lerp(g, 0.4)
		core = Color(sl.x, sl.y, sl.z).lerp(Color(1, 1, 1), 0.35)
	_mat.set_shader_parameter("glow", Vector3(g.r, g.g, g.b))
	_mat.set_shader_parameter("core_col", Vector3(core.r, core.g, core.b))


## Where a mote is at rest (this control's own px, unzoomed): its own drift,
## wrapped round a strip wider than the view (so it comes and goes off screen),
## the camera's real travel at its depth, a slow bob.
func _rest_at(m: Dictionary, tt: float) -> Vector2:
	var w := size.x + WRAP * 2.0
	var x := fposmod(float(m.x) + float(m.vx) * tt - sky.cam_follow.x * float(m.f), w) - WRAP
	var hy: float = m.y
	var y: float
	var top := 8.0 + float(m.ry)
	if hy < 0.5:
		y = top + hy * 2.0 * maxf(ARENA_H * SHOTS.x - 14.0 - top, 4.0)
	else:
		y = ARENA_H * SHOTS.y + (hy - 0.5) * 2.0 * (ARENA_H * (1.0 - SHOTS.y) + 60.0)
	y += sin(tt * 0.15 + float(m.ph)) * float(m.bob)
	return Vector2(x, y)


## What the dust must keep clear of: every ship's picture, name, gauge, intent
## and chip in the view, in the game's own px.
func _keep_out() -> Array[Rect2]:
	var out: Array[Rect2] = []
	if view == null:
		return out
	_collect(view, out)
	return out


static func _xrect(xf: Transform2D, r: Rect2) -> Rect2:
	var a := xf * r.position
	var b := xf * r.end
	return Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs())


func _collect(n: Node, out: Array[Rect2]) -> void:
	for c in n.get_children():
		if c == self or c == sky or not (c is CanvasItem) or not (c as CanvasItem).visible:
			continue
		# (a ship by the pixels it is drawn in, not its canvas: the canvas of a hull
		# fills its whole column, and kept the dust out of half the sky)
		if c is ShipView:
			out.append(_xrect((c as Control).get_global_transform(), (c as ShipView).ship_rect().grow(4.0)))
			continue
		if c is EnemyArt:
			out.append(_xrect((c as Control).get_global_transform(), Rect2((c as EnemyArt).used_rect()).grow(4.0)))
			continue
		if c is Label or c is ProgressBar or c is TextureRect or c is Button:
			var r := (c as Control).get_global_rect()
			if r.size.x > 0.0 and r.size.y > 0.0:
				out.append(r)
			continue
		if c is Control and not (c is Container) and c.get_child_count() == 0 and (c as Control).size.x * (c as Control).size.y < 200000.0:
			out.append((c as Control).get_global_rect())
		_collect(c, out)


## How visible a mote may be: 1 in the clear, 0 within KEEP of anything it must
## not cover (its whole box, `g` +- `ext`, in the game's px), easing between;
## easing out into the shots' band and at the view's top edge (its place at rest,
## `p`, reaching `ry` up and down).
func _allow(p: Vector2, ry: float, g: Vector2, ext: Vector2, rects: Array[Rect2]) -> float:
	var y := p.y
	var w := 1.0
	var lo := ARENA_H * SHOTS.x
	var hi := ARENA_H * SHOTS.y
	if y + ry > lo and y - ry < hi:
		var into := minf(y + ry - lo, hi - (y - ry))
		w = minf(w, clampf(1.0 - into / FEATHER, 0.0, 1.0))
	w = minf(w, clampf((y - ry) / 10.0, 0.0, 1.0))
	if w <= 0.0:
		return 0.0
	var reach := KEEP + THIN
	for r: Rect2 in rects:
		var dx := maxf(maxf(r.position.x - (g.x + ext.x), (g.x - ext.x) - r.end.x), 0.0)
		if dx >= reach:
			continue
		var dy := maxf(maxf(r.position.y - (g.y + ext.y), (g.y - ext.y) - r.end.y), 0.0)
		if dy >= reach:
			continue
		var d := sqrt(dx * dx + dy * dy)
		if d < KEEP:
			return 0.0
		w = minf(w, clampf((d - KEEP) / THIN, 0.0, 1.0))
	return w * w * (3.0 - 2.0 * w)
