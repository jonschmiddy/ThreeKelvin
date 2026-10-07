class_name LocalDust
extends ColorRect

## LOCAL'S FOREGROUND DUST (Jon: "can we add some dust to the local? something
## in the more frontal layer?"; then, of the first take, "it kinda pops in and
## out and looks low res"): motes drifting between the camera and the fight,
## the nearest layer of all, in front of the ships -- and held to one rule above
## the look of it: it never covers a ship, a shot's line, a damage number, an
## intent or a name.
##
## FINER THAN THE SKY, NEVER A SQUARE: drawn per game pixel by
## `local_dust.gdshader`, each mote gathered light -- a small bright core and a
## 1 px falloff in an ordered dither -- or, a few, a very faint out-of-focus
## disc with a dithered rim; the wisps are 1 px strands, half there. Each
## pattern is anchored to its own mote, so a mote moves whole, a pixel at a
## time, at its own speed (the near ones step often, which at 1 px reads as
## smooth).
##
## NOTHING POPS: a mote's visibility (`vis`) eases toward what its place allows
## -- fading out over a ship's margin, the shots' band or the view's top edge,
## in over the clear sky -- a step of its dither at a time (`FADE_IN`,
## `FADE_OUT` a second), worked out every frame; and the motes wrap round a strip
## wider than the view, so they come and go off screen. Inside a ship's picture,
## a label or a gauge no pixel of dust is ever drawn (`keep`, a last guard).
##
## WHERE, HOW FAST: in the band above the fight and the strip under it; each
## drifts slowly on its own (held still with reduced motion) and slides with the
## camera 0.6 to 0.9 of its travel, the bigger the faster. ITS COLOUR, the
## system's: in a nebula the cloud's own, darkened, in a clear sky a warm grey,
## the core the lit step; per style -- PAINTED a held highlight at each mote's
## middle, RADIANT its core in the star's light, LEGACY the old starfield's
## greys. `LocalShot dustcheck` measures what it covers and how fast it fades.

const SH := preload("res://shaders/local_dust.gdshader")
## how many motes, and on GRAPHICS LOW
const MOTES := 64
const MOTES_LOW := 30
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

var sky: LocalSky = null
var view: Control = null
var _mat: ShaderMaterial
var _motes: Array = []
var _t := 0.0
var _key := ""
## the largest change of any mote's visibility in a frame, and how many frames
## changed one by more than ABRUPT (`LocalShot dustcheck`)
const ABRUPT := 0.1
var worst_step := 0.0
var abrupt := 0
## the rects drawn over last (`LocalShot dustcheck`): every mote's box, this
## control's px
var boxes: Array[Rect2] = []
static var off := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color(1, 1, 1, 1)
	_mat = ShaderMaterial.new()
	_mat.shader = SH
	material = _mat


func _process(delta: float) -> void:
	if off:
		visible = false
		return
	if sky == null or sky.node == null:
		return
	var key := "%d|%s|%s" % [sky.node.index, sky.style, DisplaySettings.graphics_low]
	if key != _key:
		_key = key
		_seed_motes()
	var dt := minf(delta, 1.0 / 30.0)
	if not DisplaySettings.reduced_motion:
		_t += dt
	var rects := _keep_out()
	var mv := PackedVector4Array()
	var ex := PackedVector4Array()
	boxes.clear()
	# (the star where it is drawn, in this layer's own px: under the cutaway's
	# zoom the dust is scaled with the ship and the star all but holds)
	var star_x: float = (get_global_transform().affine_inverse() * (sky.get_global_transform() * sky.origin())).x
	var step := 0.0
	for m: Dictionary in _motes:
		var p := _at(m)
		var R: float = m.r
		var want := _allow(p, R + 2.0, rects)
		var v: float = m.vis
		var nv := v + clampf(want - v, -FADE_OUT * dt, FADE_IN * dt)
		step = maxf(step, absf(nv - v))
		m.vis = nv
		mv.append(Vector4(p.x, p.y, R, float(m.kind)))
		ex.append(Vector4(nv, m.seed, m.len, 1.0 if star_x > p.x else -1.0))
		if nv > 0.0:
			var h: float = float(m.len) * 0.5 if int(m.kind) == 2 else R + 1.0
			boxes.append(Rect2(p - Vector2(h, maxf(R, 4.0) + 1.0), Vector2(h * 2.0 + 1.0, maxf(R, 4.0) * 2.0 + 3.0)))
	worst_step = maxf(worst_step, step)
	if step > ABRUPT:
		abrupt += 1
	var kp := PackedVector4Array()
	for r in rects:
		if kp.size() >= 40:
			break
		kp.append(Vector4(r.position.x - 1.0, r.position.y - 1.0, r.size.x + 2.0, r.size.y + 2.0))
	var nk := kp.size()
	kp.resize(40)
	var nm := mv.size()
	mv.resize(96)
	ex.resize(96)
	_mat.set_shader_parameter("motes", mv)
	_mat.set_shader_parameter("extra", ex)
	_mat.set_shader_parameter("n_motes", nm)
	_mat.set_shader_parameter("keep", kp)
	_mat.set_shader_parameter("n_keep", nk)
	_mat.set_shader_parameter("view_size", size)


func _h(a: int, b: int) -> float:
	return LocalSky.SkyBakeS.hash2(a, b)


## The motes and wisps of this system, and its colours.
func _seed_motes() -> void:
	_motes.clear()
	var idx: int = sky.node.index
	var n := MOTES_LOW if DisplaySettings.graphics_low else MOTES
	for k in n:
		var hz := _h(idx * 31 + k, 1)
		# specks, small motes, motes, and now and then a faint out-of-focus disc
		var kind := 1 if hz > 0.9 else 0
		var r := 1.5 if hz < 0.45 else (2.5 if hz < 0.75 else (3.5 if hz < 0.9 else 5.0 + 4.0 * _h(idx * 31 + k, 7)))
		_motes.append({
			"x": _h(idx * 31 + k, 3) * 1400.0, "y": _h(idx * 31 + k, 2),
			"r": r, "kind": kind, "len": 0.0,
			"f": 0.6 + 0.3 * clampf(r / 9.0, 0.0, 1.0),
			"vx": (3.0 + 7.0 * _h(idx * 31 + k, 4)) * (1.0 if _h(idx, 9) < 0.5 else -1.0),
			"ph": _h(idx * 31 + k, 6) * 100.0,
			"seed": _h(idx * 31 + k, 8), "vis": 0.0,
		})
	for k in (2 if not DisplaySettings.graphics_low else 1):
		_motes.append({
			"x": _h(idx * 7 + k, 11) * 1400.0, "y": 0.04 if k == 0 else 0.97,
			"r": 1.0, "kind": 2, "len": 50.0 + 60.0 * _h(idx * 7 + k, 12),
			"f": 0.85, "vx": 4.0 * (1.0 if _h(idx, 9) < 0.5 else -1.0), "ph": 0.0,
			"seed": _h(idx * 7 + k, 13), "vis": 0.0,
		})
	_colours()


## The light the system's dust gathers, by style.
func _colours() -> void:
	var look: Dictionary = sky._sky_look
	_mat.set_shader_parameter("painted", sky.painted)
	# the light a mote gathers: the cloud's own colour
	# lifted, a warm grey in a clear sky, the star's light in RADIANT, the old
	# starfield's blue-grey in LEGACY
	var g := Color("#c8bcb0")
	if sky._neb_mat != null and look.has("hue"):
		var hh: Vector3 = look.hue
		g = Color(hh.x, hh.y, hh.z).lerp(Color("#d8d0c8"), 0.45)
	if sky.legacy:
		g = Color("#9fb0c8")
	elif sky.radiant:
		var sl2: Vector3 = sky.star_light()
		g = Color(sl2.x, sl2.y, sl2.z).lerp(g, 0.4)
	_mat.set_shader_parameter("glow", Vector3(g.r, g.g, g.b))


## Where a mote is now: its own slow drift, wrapped round a strip wider than the
## view (so it comes and goes off screen), and the camera's real travel at its
## depth; in whole pixels.
func _at(m: Dictionary) -> Vector2:
	var w := size.x + 300.0
	var x := fposmod(float(m.x) + float(m.vx) * _t - sky.cam_follow.x * float(m.f), w) - 150.0
	var hy: float = m.y
	var y: float
	if hy < 0.5:
		y = 8.0 + hy * 2.0 * (ARENA_H * SHOTS.x - 14.0)
	else:
		y = ARENA_H * SHOTS.y + (hy - 0.5) * 2.0 * (ARENA_H * (1.0 - SHOTS.y) + 60.0)
	y += sin(_t * 0.15 + float(m.ph)) * 3.0
	return Vector2(roundf(x), roundf(y))


## What the dust must keep clear of: every ship's picture, name, gauge, intent
## and chip in the view, in this control's own coordinates.
func _keep_out() -> Array[Rect2]:
	var out: Array[Rect2] = []
	if view == null:
		return out
	_collect(view, get_global_rect().position, out)
	return out


func _collect(n: Node, at: Vector2, out: Array[Rect2]) -> void:
	for c in n.get_children():
		if c == self or c == sky or not (c is CanvasItem) or not (c as CanvasItem).visible:
			continue
		# (a ship by the pixels it is drawn in, not its canvas: the canvas of a hull
		# fills its whole column, and kept the dust out of half the sky)
		if c is ShipView:
			var sr := (c as ShipView).ship_rect().grow(4.0)
			out.append(Rect2(sr.position + (c as Control).global_position - at, sr.size))
			continue
		if c is EnemyArt:
			var er := Rect2((c as EnemyArt).used_rect()).grow(4.0)
			out.append(Rect2(er.position + (c as Control).global_position - at, er.size))
			continue
		if c is Label or c is ProgressBar or c is TextureRect or c is Button:
			var r := (c as Control).get_global_rect()
			if r.size.x > 0.0 and r.size.y > 0.0:
				out.append(Rect2(r.position - at, r.size))
			continue
		if c is Control and not (c is Container) and c.get_child_count() == 0 and (c as Control).size.x * (c as Control).size.y < 200000.0:
			var r2 := (c as Control).get_global_rect()
			out.append(Rect2(r2.position - at, r2.size))
		_collect(c, at, out)


## How visible a mote of reach R at p may be: 1 in the clear, 0 within KEEP of
## anything it must not cover, easing between; easing out into the shots' band
## and at the view's top edge.
func _allow(p: Vector2, R: float, rects: Array[Rect2]) -> float:
	var y := p.y
	var w := 1.0
	var lo := ARENA_H * SHOTS.x
	var hi := ARENA_H * SHOTS.y
	if y + R > lo and y - R < hi:
		var into := minf(y + R - lo, hi - (y - R))
		w = minf(w, clampf(1.0 - into / FEATHER, 0.0, 1.0))
	w = minf(w, clampf((y - R) / 10.0, 0.0, 1.0))
	for r: Rect2 in rects:
		var d := Vector2(maxf(maxf(r.position.x - p.x, p.x - r.end.x), 0.0), maxf(maxf(r.position.y - p.y, p.y - r.end.y), 0.0)).length() - R
		if d < KEEP:
			return 0.0
		w = minf(w, clampf((d - KEEP) / THIN, 0.0, 1.0))
	return w * w * (3.0 - 2.0 * w)
