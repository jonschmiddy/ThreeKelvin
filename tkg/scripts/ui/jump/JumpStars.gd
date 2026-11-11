class_name JumpStars
extends RefCounted

## The stars lifted off this LOCAL's sky once, for the films that move them (each star
## pixel found as the films' Python did, its light over the bare sky, and a mask painting
## the sky bare under it while it is away), plus the faint stars the sky never drew, hashed.
## Why: docs/why/JumpStars.md#lift

const DETECT := preload("res://shaders/jump/jump_star_detect.gdshader")
const MAX_STARS := 3000
## A cluster, as the films' BLOB: more than this many standing-out pixels in a 7x7, and every
## star within 3 px of one (stations, comets, trails).
const BLOB_N := 5

var world := Rect2()
## Each star's home pixel (screen px), its light over the bare sky (0..1), its brightness
## (the films' STAR_B) and its rolled lag (0..0.15).
var home := PackedVector2Array()
var add := PackedColorArray()
var bright := PackedFloat32Array()
var lag_u := PackedFloat32Array()
## The faint stars the sky never drew (R1's extras), hashed inside the window: each one's
## pixel, brightness and lag, rolled the same for a window every time (`add_faint`).
var faint_home := PackedVector2Array()
var faint_bright := PackedFloat32Array()
var faint_lag := PackedFloat32Array()
## Bare sky under every lifted star and its 3x3 (rgb), alpha 0 elsewhere, else the lag encoded.
var mask: ImageTexture = null
var ready := false
var _vp: SubViewport = null
var _img: Image = null
var _frames := 0


## Start the lift from `img` (the screen); null (headless) lifts nothing and is ready at once.
static func lift(host: Node, img: Image, world_rect: Rect2, keep_out: Rect2) -> JumpStars:
	var js := JumpStars.new()
	js.world = world_rect
	if img == null:
		js.ready = true
		return js
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	js._img = img
	js._vp = SubViewport.new()
	js._vp.size = Vector2i(world_rect.size)
	js._vp.transparent_bg = true
	js._vp.disable_3d = true
	js._vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var r := ColorRect.new()
	r.size = world_rect.size
	var m := ShaderMaterial.new()
	m.shader = DETECT
	m.set_shader_parameter(&"src", ImageTexture.create_from_image(img))
	m.set_shader_parameter(&"world", Vector4(world_rect.position.x, world_rect.position.y, world_rect.size.x, world_rect.size.y))
	m.set_shader_parameter(&"keep_out", Vector4(keep_out.position.x, keep_out.position.y, keep_out.size.x, keep_out.size.y))
	r.material = m
	js._vp.add_child(r)
	host.add_child(js._vp)
	return js


## `n` faint extras: whole pixels inside the window (2 px clear of its left, 10 of its
## right), brightness (0.10..0.45)^1.3, lag 0..0.15, as r1.py rolled them.
func add_faint(n: int) -> void:
	var w := world
	for j in n:
		faint_home.append(Vector2(w.position.x + 2.0 + JumpSequence.held_rand(j, 31) * (w.size.x - 12.0),
			w.position.y + JumpSequence.held_rand(j, 32) * (w.size.y - 2.0)).floor())
		faint_bright.append(pow(0.10 + 0.35 * JumpSequence.held_rand(j, 33), 1.3))
		faint_lag.append(JumpSequence.held_rand(j, 34) * 0.15)


## Once the detect pass has drawn, read it and build the lists; true when done.
func poll() -> bool:
	if ready:
		return true
	_frames += 1
	if _frames < 3 or _vp == null or _vp.get_texture() == null:
		return false
	var det := _vp.get_texture().get_image()
	_vp.queue_free()
	_vp = null
	if det != null:
		if det.get_format() != Image.FORMAT_RGBA8:
			det.convert(Image.FORMAT_RGBA8)
		_build(det)
	_img = null
	ready = true
	return true


## The star pixels from the detect image: clusters dropped, the brightest kept, their colours.
func _build(det: Image) -> void:
	var w := det.get_width()
	var h := det.get_height()
	var data := det.get_data()
	var cand := PackedByteArray()
	cand.resize(w * h)
	var cands: Array[Vector2i] = []
	var pts: Array[Vector2i] = []
	var at := data.find(255, 0)
	while at >= 0:
		var i := at / 4
		if at % 4 == 0:
			pts.append(Vector2i(i % w, i / w))
		else:
			cand[i] = 1
			cands.append(Vector2i(i % w, i / w))
		at = data.find(255, at + 1)
	var blob := PackedByteArray()
	blob.resize(w * h)
	for q in cands:
		if _near(cand, w, h, q, 3) > BLOB_N:
			blob[q.y * w + q.x] = 1
	var kept: Array = []
	for q in pts:
		if _near(blob, w, h, q, 6) > 0:
			continue
		var s := q + Vector2i(world.position)
		var bare := _bare(s)
		var px := _img.get_pixel(s.x, s.y)
		var a := Color(maxf(px.r - bare.r, 0.0), maxf(px.g - bare.g, 0.0), maxf(px.b - bare.b, 0.0), 1.0)
		var b := clampf(maxf(a.r, maxf(a.g, a.b)) * 255.0 / 120.0, 0.08, 1.6)
		kept.append([b, q, a, bare])
	kept.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) > float(y[0]))
	var mk := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for n in mini(kept.size(), MAX_STARS):
		var k: Array = kept[n]
		var q: Vector2i = k[1]
		var u := JumpSequence.held_rand(n, 11) * 0.15
		home.append(Vector2(q) + world.position)
		add.append(k[2])
		bright.append(float(k[0]))
		lag_u.append(u)
		var bare: Color = k[3]
		bare.a = (1.0 + roundf(u / 0.15 * 254.0)) / 255.0
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var x := q.x + dx
				var y := q.y + dy
				if x >= 0 and y >= 0 and x < w and y < h:
					mk.set_pixel(x, y, bare)
	mask = ImageTexture.create_from_image(mk)


## How many set bytes of `grid` lie within r of q (Chebyshev).
static func _near(grid: PackedByteArray, w: int, h: int, q: Vector2i, r: int) -> int:
	var n := 0
	for y in range(maxi(q.y - r, 0), mini(q.y + r + 1, h)):
		var row := y * w
		for x in range(maxi(q.x - r, 0), mini(q.x + r + 1, w)):
			n += grid[row + x]
	return n


## The sky under a star: the per-channel median of the eight pixels three off it.
func _bare(s: Vector2i) -> Color:
	var rs := PackedFloat32Array()
	var gs := PackedFloat32Array()
	var bs := PackedFloat32Array()
	for d: Vector2i in [Vector2i(3, 0), Vector2i(-3, 0), Vector2i(0, 3), Vector2i(0, -3),
			Vector2i(3, 3), Vector2i(-3, 3), Vector2i(3, -3), Vector2i(-3, -3)]:
		var p := s + d
		p.x = clampi(p.x, int(world.position.x), int(world.end.x) - 1)
		p.y = clampi(p.y, int(world.position.y), int(world.end.y) - 1)
		var c := _img.get_pixel(p.x, p.y)
		rs.append(c.r)
		gs.append(c.g)
		bs.append(c.b)
	rs.sort()
	gs.sort()
	bs.sort()
	return Color((rs[3] + rs[4]) * 0.5, (gs[3] + gs[4]) * 0.5, (bs[3] + bs[4]) * 0.5, 1.0)
