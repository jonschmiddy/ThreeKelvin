extends Node2D

## THE CORE ON THE SYSTEM MAP: the supermassive black hole Jon picked, with
## all five of its motions -- the gas swirling faster in close, clumps of it
## spiralling in and gone behind the hole, the glow breathing, a star circling
## and being eaten with its stream hidden round the far side, and the map
## behind it bent into arcs. A port of the mockup's `coreDraw`, `coreLens`,
## `coreGlow` and its BH renderer (`sysmap/template.html`, the page built as
## `sysmap/page/index.html`), with the map's settings: hole 15, disc to 110,
## tilted 0.38 like the orbits.
##
## Put it at the hole's centre, in whole game pixels, call `setup()` once and
## `step(t)` every frame. It draws nothing until `setup()` has traced the light
## (one frame of GPU work, awaited; `ready_to_draw` and the `traced` signal say
## when). Two layers:
##   * `lens` -- the map behind bent round the hole. It reads the screen, so it
##     must come AFTER whatever it bends (the sky, the far worlds) and BEFORE
##     the hole. It is this node's first child, so by default it is drawn just
##     before the hole; a screen that wants it elsewhere can `take_lens()` and
##     put it anywhere in its own draw order. A taken lens is moved to this
##     node's position by `set_zoom()` and `step()`, so it follows a pan.
##   * the hole itself (`core_hole.gdshader`): the disc and its light, laid on
##     as light added to what is behind, the shadow opaque.
##
## ZOOM (`set_zoom(k)`, 1 to 4, every frame while the map's zoom eases): the
## hole is drawn again k times bigger in single game pixels -- hole, photon
## ring, disc and its streaks, clumps, the eaten star and its stream, glow and
## lens all k times the size, never the picture stretched. The light's paths
## are traced for one size at a time, so:
##   * the lens is worked out per pixel each frame, so it is always at k;
##   * the hole draws the nearest trace it has, stretched by k / that trace's k
##     (the hole's own ColorRect is scaled, never this node), for a moment
##     soft or stepped;
##   * once k has held still SETTLE seconds, the light is traced again at k
##     (one GPU frame and a read back) and the hole drawn from it, sharp.
## Traces are kept, one per ZOOM_BIN of k, shared by every Core, up to
## CACHE_BYTES; going back to a zoom already traced is instant.
##
## The mockup draws all of it between the worlds behind the hole and the
## worlds in front of it, so that is where this node belongs.

signal traced
## A trace at `k` has come in and the hole is now drawn from it, sharp.
signal zoom_traced(k: float)

const TRACE := preload("res://shaders/core_trace.gdshader")
const HOLE := preload("res://shaders/core_hole.gdshader")
const LENS := preload("res://shaders/core_lens.gdshader")

## The renderer's picture at zoom 1, centred on the hole (build.py's 330 x
## 210); at zoom k, 2 * ceil(165 k) x 2 * ceil(105 k).
const W := 330
const H := 210
## The map's settings (`CORE_P` in the template), at zoom 1.
const TILT := 0.38
const RH := 15.0
const RIN := RH * 1.16
const ROUT := 110.0
## How far out the trace's radii are packed (the shaders' R_MAX), at zoom 1.
const R_MAX := 140.0
## The lens: the ring at TE game px, the patch it bends 160 px round.
const LENS_TE := 41.63448  # sqrt(52) * 15 / 2.598
const LENS_R := 160

## The eaten star's orbit is tilted 0.3 rad out of the disc.
const TIDE_I := 0.3

## Colour numbers in the `dots` picture: 0 is nothing, n is the shader's
## colour n - 1 (the palette's eight, then the eaten star and its rim).
const D_TSTAR := 9
const D_TRIM := 10

## THE ZOOM. A trace is drawn as it is when it is within SAME of the zoom.
const ZOOM_MIN := 1.0
const ZOOM_MAX := 4.0
const ZOOM_BIN := 0.25
const SAME := 0.002
const SETTLE := 0.15
## What the kept traces may hold on the CPU (each view keeps the same again on
## the GPU, as textures). One at zoom 4 is 17.7 MB, at 1 1.1 MB; zoom 1's is
## never let go.
const CACHE_BYTES := 48 * 1024 * 1024

var ready_to_draw := false
var lens: Node2D
## The zoom asked for, and the zoom of the trace being drawn.
var zoom := 1.0
var drawn_zoom := 1.0
## The last trace's times, in ms: from asking to the picture being drawn
## (`trace_ms`, frames waited included) and the read back (`readback_ms`).
var trace_ms := 0.0
var readback_ms := 0.0
## How long the last switch to a kept trace took, in ms (its texture made,
## if this view had none, and the dots drawn again).
var use_ms := 0.0
var _lens_rect: ColorRect
var _lmat: ShaderMaterial
var _hole: ColorRect
var _hmat: ShaderMaterial
var _dots_img: Image
var _dots_tex: ImageTexture
var _dots := PackedByteArray()
## A dot's blob at this zoom: how many pixels across, where it starts, and
## its pixels as offsets into `_dots` and as x, y.
var _bn := 1
var _blo := 0
var _offs := PackedInt32Array()
var _offs_xy := PackedVector2Array()
## What was drawn last frame, to clear: pixels, and whole blobs by their middle.
var _dirty := PackedInt32Array()
var _dirty_b := PackedInt32Array()
## The trace being drawn: its zoom, picture size, and its bytes, read by the
## CPU's own hiding of the dots. Per pixel, in its first band: the disc radius
## it landed at (R, G) and the flags (B): kind (0 open sky, 1 fell in, 2
## landed on the disc), and 8 when it is the near band in front of the hole.
var _kt := 0.0
var _w := W
var _h := H
var _tb := PackedByteArray()
var _last_t := 0.0
var _changed_ms := 0
var _tracing := false
## This view's textures of the kept traces: bin -> [k, ImageTexture].
var _texs := {}
## The kept traces, every Core's: bin -> {"k": float, "img": Image, "used": int}.
static var _cache := {}
static var _clock := 0
## The clumps: phase, starting angle, how many seconds each takes to fall in.
static var _clumps: Array[Vector3] = []


func _init() -> void:
	lens = Node2D.new()
	lens.name = "CoreLens"
	# the screen as it stands at this point, for the lens to bend
	var copy := BackBufferCopy.new()
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	lens.add_child(copy)
	_lens_rect = ColorRect.new()
	_lens_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lmat = ShaderMaterial.new()
	_lmat.shader = LENS
	_lens_rect.material = _lmat
	lens.add_child(_lens_rect)
	add_child(lens)
	_fit_lens()
	_hole = ColorRect.new()
	_hole.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hmat = ShaderMaterial.new()
	_hmat.shader = HOLE
	_hmat.set_shader_parameter("tilt", TILT)
	_hole.material = _hmat
	add_child(_hole)
	lens.visible = false
	_hole.visible = false
	set_process(false)
	if _clumps.is_empty():
		for i in 26:
			_clumps.append(Vector3(hash2(i, 11) * 7.0, hash2(i, 12) * TAU, 5.0 + hash2(i, 13) * 3.0))


## Takes the lens out of this node, for the screen to place in its own draw
## order (it must be drawn after what it bends). `set_zoom` and `step` keep it
## at this node's position.
func take_lens() -> Node2D:
	if lens.get_parent() == self:
		remove_child(lens)
	return lens


## `raw` draws the renderer's own picture opaque, with no glow and no lens:
## the comparison against the mockup's `BH.draw`.
func set_raw(on: bool) -> void:
	_hmat.set_shader_parameter("raw", on)
	_hmat.set_shader_parameter("glow_on", not on)


## Traces the light at the zoom set (1 unless `set_zoom` came first), unless a
## trace of it is kept already. Must be in the tree. One frame of GPU work,
## then a read back.
func setup() -> void:
	var b := _bin(zoom)
	if not _cache.has(b) or absf(float(_cache[b]["k"]) - zoom) > SAME:
		await _trace(zoom)
	_use(b)
	ready_to_draw = true
	if is_instance_valid(lens):
		lens.visible = true
	_hole.visible = true
	traced.emit()


## THE MAP'S ZOOM, 1 to 4. Cheap: call it every frame while the zoom eases.
func set_zoom(k: float) -> void:
	k = clampf(k, ZOOM_MIN, ZOOM_MAX)
	if absf(k - zoom) > 0.00001:
		zoom = k
		_changed_ms = Time.get_ticks_msec()
		_fit_lens()
	_follow()
	if not ready_to_draw:
		return
	# the nearest trace kept, drawn stretched until the right one is in
	var best := -1
	var bd := INF
	for b: int in _cache:
		var d := absf(log(float(_cache[b]["k"]) / zoom))
		if d < bd:
			bd = d
			best = b
	if best >= 0 and absf(float(_cache[best]["k"]) - _kt) > 0.00001:
		_use(best)
	_place()
	if absf(_kt - zoom) > SAME:
		set_process(true)


func _process(_delta: float) -> void:
	if not ready_to_draw or _tracing:
		return
	if absf(_kt - zoom) <= SAME:
		set_process(false)
		return
	if Time.get_ticks_msec() - _changed_ms >= int(SETTLE * 1000.0):
		_retrace(zoom)


## The zoom has held still: trace it, and draw from it if it still holds.
func _retrace(k: float) -> void:
	await _trace(k)
	if absf(zoom - k) <= SAME and ready_to_draw:
		_use(_bin(k))
		_place()
		zoom_traced.emit(k)


static func _bin(k: float) -> int:
	return roundi(k / ZOOM_BIN)


## Half the picture's width (165 at zoom 1) or height (105), at zoom k.
static func _half(n: float, k: float) -> int:
	return ceili(n * k - 0.001)


## The lens at the zoom asked for: it needs no trace, so it is never stretched.
func _fit_lens() -> void:
	var rad := float(LENS_R) * zoom
	var e := _half(float(LENS_R), zoom)
	_lens_rect.position = Vector2(-e, -e)
	_lens_rect.size = Vector2(e * 2 + 1, e * 2 + 1)
	_lmat.set_shader_parameter("te", LENS_TE * zoom)
	_lmat.set_shader_parameter("radius", rad)
	_lmat.set_shader_parameter("extent", float(e))


## A lens the screen took stays on the hole.
func _follow() -> void:
	if is_instance_valid(lens) and lens.get_parent() != self and lens.is_inside_tree() and is_inside_tree():
		lens.global_position = global_position


## The hole at its trace's size, stretched to the zoom asked for until the
## zoom's own trace is in.
func _place() -> void:
	var s := 1.0 if absf(zoom - _kt) <= SAME else zoom / _kt
	_hole.scale = Vector2(s, s)
	_hole.position = Vector2(-_w / 2, -_h / 2) * s


## Draws from the kept trace in bin b from now on.
func _use(b: int) -> void:
	var t0 := Time.get_ticks_usec()
	var e: Dictionary = _cache[b]
	e["used"] = _bump()
	var k: float = e["k"]
	var img: Image = e["img"]
	var tex: ImageTexture = null
	if _texs.has(b) and absf(float(_texs[b][0]) - k) <= 0.00001:
		tex = _texs[b][1]
	else:
		# the texture is this view's own: a static one would outlive the renderer
		tex = ImageTexture.create_from_image(img)
		_texs[b] = [k, tex]
	# let go of textures whose trace was let go of, or traced again at another k
	for o: int in _texs.keys():
		if not _cache.has(o) or absf(float(_cache[o]["k"]) - float(_texs[o][0])) > 0.00001:
			_texs.erase(o)
	_kt = k
	drawn_zoom = k
	_w = 2 * _half(float(W) / 2.0, k)
	_h = 2 * _half(float(H) / 2.0, k)
	_tb = img.get_data()
	_hmat.set_shader_parameter("trace", tex)
	_hmat.set_shader_parameter("kz", k)
	_hmat.set_shader_parameter("size", Vector2(_w, _h))
	_hmat.set_shader_parameter("rh", RH * k)
	_hmat.set_shader_parameter("rin", RIN * k)
	_hmat.set_shader_parameter("rout", ROUT * k)
	_hole.size = Vector2(_w, _h)
	_place()
	_dots = PackedByteArray()
	_dots.resize(_w * _h)
	_dirty.clear()
	_dirty_b.clear()
	_fit_blob()
	_dots_img = Image.create_from_data(_w, _h, false, Image.FORMAT_R8, _dots)
	_dots_tex = ImageTexture.create_from_image(_dots_img)
	_hmat.set_shader_parameter("dots", _dots_tex)
	if ready_to_draw:
		step(_last_t)
	use_ms = float(Time.get_ticks_usec() - t0) / 1000.0


static func _bump() -> int:
	_clock += 1
	return _clock


## Traces the light at zoom k into the kept traces: draws every ray once into
## a SubViewport and reads the picture back.
func _trace(k: float) -> void:
	_tracing = true
	var t0 := Time.get_ticks_usec()
	var vp := trace_viewport(k)
	add_child(vp)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var t1 := Time.get_ticks_usec()
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	var t2 := Time.get_ticks_usec()
	vp.queue_free()
	readback_ms = float(t2 - t1) / 1000.0
	trace_ms = float(t2 - t0) / 1000.0
	_keep(k, img)
	_tracing = false


## The SubViewport that traces the light at zoom k (W x 4H at that zoom),
## drawn once when it enters the tree.
static func trace_viewport(k: float) -> SubViewport:
	var w := 2 * _half(float(W) / 2.0, k)
	var h := 2 * _half(float(H) / 2.0, k)
	var vp := SubViewport.new()
	vp.size = Vector2i(w, h * 4)
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var rect := ColorRect.new()
	rect.size = Vector2(w, h * 4)
	var m := ShaderMaterial.new()
	m.shader = TRACE
	m.set_shader_parameter("tilt", TILT)
	m.set_shader_parameter("rh", RH * k)
	m.set_shader_parameter("rin", RIN * k)
	m.set_shader_parameter("rout", ROUT * k)
	m.set_shader_parameter("kz", k)
	m.set_shader_parameter("size", Vector2(w, h))
	rect.material = m
	vp.add_child(rect)
	return vp


## Keeps a trace, letting go of the longest unused ones (never zoom 1's, nor
## the one being drawn) while they hold more than CACHE_BYTES.
func _keep(k: float, img: Image) -> void:
	var b := _bin(k)
	_cache[b] = {"k": k, "img": img, "used": _bump()}
	while true:
		var total := 0
		var old := -1
		var oldest := 0x7FFFFFFFFFFFFFFF
		for o: int in _cache:
			var e: Dictionary = _cache[o]
			total += (e["img"] as Image).get_data().size()
			if o != b and o != _bin(ZOOM_MIN) and absf(float(e["k"]) - _kt) > 0.00001 and int(e["used"]) < oldest:
				oldest = e["used"]
				old = o
		if total <= CACHE_BYTES or old < 0:
			break
		_cache.erase(old)


## What the kept traces hold on the CPU, in bytes.
static func cache_bytes() -> int:
	var total := 0
	for o: int in _cache:
		total += (_cache[o]["img"] as Image).get_data().size()
	return total


## The zooms kept traced.
static func cache_zooms() -> Array[float]:
	var out: Array[float] = []
	for o: int in _cache:
		out.append(float(_cache[o]["k"]))
	out.sort()
	return out


## The mockup's 2D integer hash, to [0, 1).
static func hash2(x: int, y: int) -> float:
	var h := ((x * 374761393) ^ (y * 668265263)) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	return float((h ^ (h >> 16)) & 0xFFFFFFFF) / 4294967296.0


## JavaScript's Math.round: halves go up, never away from zero.
static func _jround(x: float) -> int:
	return floori(x + 0.5)


## The map's clock, in seconds.
func step(t: float) -> void:
	_follow()
	if not ready_to_draw:
		return
	_last_t = t
	# BREATHING: the disc swells and settles, and in most 4.2 s spells a flare
	# goes through it at the start
	var n := floori(t / 4.2)
	var u := t / 4.2 - n
	var flare := maxf(0.0, 1.0 - u * 5.0) * 0.75 if hash2(n, 77) > 0.35 else 0.0
	var breath := 1.0 + 0.13 * sin(t * 1.3) + 0.08 * sin(t * 3.1 + 1.0) + flare
	_hmat.set_shader_parameter("time", t)
	_hmat.set_shader_parameter("breath", breath)
	var ce := sqrt(1.0 - TILT * TILT)
	# EATING A STAR: where it is on its orbit just outside the disc
	var r0 := ROUT * _kt * 1.12
	var th := -0.55 + t * 0.22
	var q := _tide(r0, th, TIDE_I, ce)
	var star := Vector2(_w / 2.0 + q.x, _h / 2.0 + q.y)
	var behind := q.z < 0.0
	_hmat.set_shader_parameter("star", star)
	_hmat.set_shader_parameter("star_behind", behind)
	_draw_dots(t, star, behind, r0, th, ce)


## A point on the eaten star's tilted orbit: screen u, v and how far toward
## you it is in the disc's frame (z < 0 is the far side).
static func _tide(r: float, a: float, inc: float, ce: float) -> Vector3:
	var zc := sin(a) * r * cos(inc)
	var y := sin(a) * r * sin(inc)
	return Vector3(cos(a) * r, zc * TILT - y * ce, zc)


## A dot on the disc's far side at pixel xi, yi and disc radius r is hidden
## when the ray through that pixel fell into the hole, met the near band of
## disc, or landed on a part of the disc well in front of or behind it.
func _hidden(xi: int, yi: int, zc: float, r: float) -> bool:
	if zc >= 0.0:
		return false
	if xi < 0 or yi < 0 or xi >= _w or yi >= _h:
		return false
	var j := (yi * _w + xi) * 4
	var fl := _tb[j + 2]
	var kind := fl & 3
	if kind == 1 or fl & 8:
		return true
	return kind == 2 and absf(float(_tb[j] * 256 + _tb[j + 1]) / 65535.0 * R_MAX * _kt - r) > maxf(6.0 * _kt, r * 0.4)


func _plot(xi: int, yi: int, c: int) -> void:
	if xi < 0 or yi < 0 or xi >= _w or yi >= _h:
		return
	var i := yi * _w + xi
	if _dots[i] == 0:
		_dirty.append(i)
	_dots[i] = c


## One dot of gas at x, y: a single pixel at zoom 1, a round blob about k
## pixels across at zoom k (`_offs`). A blob on the far side is hidden whole
## when its middle and corners agree, else pixel by pixel (at an edge of what
## hides it).
func _blob(x: float, y: float, zc: float, r: float, c: int) -> void:
	var xi := _jround(x)
	var yi := _jround(y)
	if _bn == 1:
		if not _hidden(xi, yi, zc, r):
			_plot(xi, yi, c)
		return
	var lo := _blo
	var hi := _blo + _bn - 1
	var each := xi + lo < 0 or yi + lo < 0 or xi + hi >= _w or yi + hi >= _h
	if not each and zc < 0.0:
		var hide := _hidden(xi, yi, zc, r)
		each = _hidden(xi + lo, yi + lo, zc, r) != hide or _hidden(xi + hi, yi + lo, zc, r) != hide 			or _hidden(xi + lo, yi + hi, zc, r) != hide or _hidden(xi + hi, yi + hi, zc, r) != hide
		if hide and not each:
			return
	if each:
		for j in _offs_xy.size():
			var o := _offs_xy[j]
			if not _hidden(xi + o.x, yi + o.y, zc, r):
				_plot(xi + o.x, yi + o.y, c)
		return
	var base := yi * _w + xi
	_dirty_b.append(base)
	for o in _offs:
		_dots[base + o] = c


## The pixels of a blob at the zoom drawn: n across, the corners off from 3.
func _fit_blob() -> void:
	_bn = maxi(1, roundi(_kt))
	_blo = -((_bn - 1) >> 1)
	_offs = PackedInt32Array()
	_offs_xy = PackedVector2Array()
	var hi := _blo + _bn - 1
	for dy in range(_blo, hi + 1):
		for dx in range(_blo, hi + 1):
			if _bn >= 3 and (dy == _blo or dy == hi) and (dx == _blo or dx == hi):
				continue
			_offs.append(dy * _w + dx)
			_offs_xy.append(Vector2(dx, dy))


func _draw_dots(t: float, star: Vector2, behind: bool, r0: float, th: float, ce: float) -> void:
	for i in _dirty:
		_dots[i] = 0
	_dirty.clear()
	for b in _dirty_b:
		for o in _offs:
			_dots[b + o] = 0
	_dirty_b.clear()
	var k := _kt
	var cx := _w / 2.0
	var cy := _h / 2.0
	# the star's ribbon: its gas trailing ahead and spiralling down into the
	# disc, brightest where it leaves the star
	var r1 := ROUT * k * 0.86
	for i in 110:
		var u := fposmod(float(i) / 110.0 + t * 0.07, 1.0)
		var rr := r0 + (r1 - r0) * u
		var q := _tide(rr, th + 2.5 * u, TIDE_I * (1.0 - u), ce)
		var x := cx + q.x
		var y := cy + q.y - (1.0 - u) * 1.5 * k * float(i % 3 - 1)
		_blob(x, y, q.z, rr, 1 + mini(7, 3 + floori((1.0 - u) * 3.0)))
	# the star itself, in front: stretched toward the hole, blue-white with a
	# dark rim so it reads even over the white-hot disc
	if not behind:
		var hx := cx - star.x
		var hy := cy - star.y
		var hl := sqrt(hx * hx + hy * hy)
		if hl == 0.0:
			hl = 1.0
		var m := ceili(3.0 * k - 0.001)
		for y in range(-m, m + 1):
			for x in range(-m, m + 1):
				var along := (x * hx + y * hy) / hl
				var across := (-x * hy + y * hx) / hl
				var e := along * along / (9.0 * k * k) + across * across / (4.5 * k * k)
				if e <= 1.0:
					_plot(_jround(star.x + x), _jround(star.y + y), D_TRIM if e > 0.55 else (8 if along > 1.2 * k else D_TSTAR))
	# SWALLOWING: clumps of gas spiralling in, quicker as they fall, gone at
	# the edge of the hole
	for c in _clumps:
		var u := fposmod((t + c.x) / c.z, 1.0)
		var r := ROUT * k * 0.95 * pow(1.0 - u, 0.75) + RH * k * 0.9 * u
		var a := c.y + u * u * 14.0 + u * 3.0
		for j in 4:
			var aa := a - j * 0.12 * (1.0 + u * 3.0)
			var rr := r + j * 1.2 * k
			var xx := cos(aa) * rr
			var zz := sin(aa) * rr
			_blob(cx + xx, cy + zz * TILT, zz, rr, 1 + maxi(3, 7 - j - (2 if u < 0.2 else 0)))
	_dots_img.set_data(_w, _h, false, Image.FORMAT_R8, _dots)
	_dots_tex.update(_dots_img)
