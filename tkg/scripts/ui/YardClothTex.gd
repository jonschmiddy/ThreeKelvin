class_name YardClothTex
extends RefCounted

## A banner's cloth as a material: the flat cloth (`YardBanner.flat_cloth`) made into what hangs, and
## the pixel font's words drawn into a cloth. Canvas is the material on Jon's banner page (Nov 24);
## another material plugs in at `make`.
## Why: docs/why/YardBanner.md#material

const W := YardBanner.BW
const H := YardBanner.CLOTH


## A cloth made in its material: its pixels (alpha 0 or 255), which are painted marks, each row's field colour.
class Made extends RefCounted:
	var data: Image
	## 1 where a painted mark is (it takes whole light steps and the glint).
	var ink: PackedByteArray
	## Each row's field colour, rgb (the rim light's colour on that row).
	var field: PackedByteArray


## The cloth in `material`.
static func make(src: Image, material: StringName = &"canvas") -> Made:
	match material:
		_:
			return canvas(src)


## Heavy canvas (the page's prepTex): a two-pixel weave, the rod sleeve and its seam, a hem stitched every
## three, rubbed fork tips, a few frayed notches in the fork's edge, and the marks sat into the cloth.
## Why: docs/why/YardBanner.md#material
static func canvas(src: Image) -> Made:
	var s := src.get_data()
	var d := s.duplicate()
	var ink := PackedByteArray()
	ink.resize(W * H)
	var field := PackedByteArray()
	field.resize(H * 3)
	var dist := _dist(s)
	var cls := _classes(s, dist, ink, field)
	for y in H:
		for x in W:
			var t := y * W + x
			if cls[t] != 2:
				continue
			var k := 1.015 if ((x >> 1) + (y >> 1)) & 1 else 0.985
			if y <= 3:
				k *= 0.86
			elif y == 4:
				k = 0.72
			elif y == 5:
				k *= 1.07
			elif dist[t] == 3:
				k = 1.1 if (x + y) % 3 == 0 else 0.8
			if y >= 92 and (x <= 5 or x >= 42) and hash01(x, y) < 0.3:
				k *= 1.16
			if (y > 0 and ink[t - W] != 0) or (y > 0 and x > 0 and ink[t - W - 1] != 0):
				k *= 0.8
			for c in 3:
				d[t * 4 + c] = clampi(roundi(float(s[t * 4 + c]) * k), 0, 255)
	for y in range(91, H):
		for x in range(3, W - 3):
			var t := y * W + x
			if cls[t] == 1 and hash01(x * 7, y * 3) < 0.14:
				d[t * 4 + 3] = 0
				ink[t] = 0
	var m := Made.new()
	m.data = Image.create_from_data(W, H, false, Image.FORMAT_RGBA8, d)
	m.ink = ink
	m.field = field
	return m


## Each opaque pixel's ring distance to a hole (1-5): a transparent pixel, or past the left, right or foot
## (never past the top, which meets the rod).
static func _dist(s: PackedByteArray) -> PackedByteArray:
	var hd := PackedByteArray()
	hd.resize(W * H)
	for y in H:
		for x in W:
			var best := mini(mini(x + 1, W - x), 5)
			for dx in range(1, best):
				if (x - dx >= 0 and s[(y * W + x - dx) * 4 + 3] == 0) or (x + dx < W and s[(y * W + x + dx) * 4 + 3] == 0):
					best = dx
					break
			hd[y * W + x] = 0 if s[(y * W + x) * 4 + 3] == 0 else best
	var dist := PackedByteArray()
	dist.resize(W * H)
	for y in H:
		for x in W:
			if s[(y * W + x) * 4 + 3] == 0:
				continue
			var k := 5
			for dy in range(-4, 5):
				var yy := y + dy
				if yy < 0:
					continue
				var h := 0 if yy >= H else int(hd[yy * W + x])
				k = mini(k, maxi(absi(dy), h))
			dist[y * W + x] = maxi(1, k)
	return dist


## 0 none, 1 the outline, 2 the row's field, 3 a painted mark; each row's field is its commonest colour.
static func _classes(s: PackedByteArray, dist: PackedByteArray, ink: PackedByteArray, field: PackedByteArray) -> PackedByteArray:
	var cls := PackedByteArray()
	cls.resize(W * H)
	for y in H:
		var cnt := {}
		var best := 0
		var mode := 0
		for x in W:
			var i := (y * W + x) * 4
			if s[i + 3] == 0:
				continue
			var key := (s[i] << 16) | (s[i + 1] << 8) | s[i + 2]
			var c: int = cnt.get(key, 0) + 1
			cnt[key] = c
			if c > best:
				best = c
				mode = key
		field[y * 3] = mode >> 16
		field[y * 3 + 1] = (mode >> 8) & 255
		field[y * 3 + 2] = mode & 255
		for x in W:
			var i := (y * W + x) * 4
			var t := y * W + x
			if s[i + 3] == 0:
				continue
			var key := (s[i] << 16) | (s[i + 1] << 8) | s[i + 2]
			cls[t] = 2 if key == mode else (1 if dist[t] == 1 else 3)
			if cls[t] == 3:
				ink[t] = 1
	return cls


## The page's hash (JavaScript's 32-bit arithmetic, its one double product included), 0 to 1.
static func hash01(a: int, b: int) -> float:
	var h := (a * 374761393 + b * 668265263) & 0xFFFFFFFF
	if h >= 0x80000000:
		h -= 0x100000000
	h = h ^ ((h & 0xFFFFFFFF) >> 13)
	var m := fmod(float(h) * 1274126177.0, 4294967296.0)
	if m < 0.0:
		m += 4294967296.0
	var u := int(m)
	return float((u ^ (u >> 16)) & 0xFFFFFFFF) / 4294967296.0


## A word in the pixel font into a cloth as YardBanner drew it: centred, its top at row `top`, hard pixels.
static func word(img: Image, s: String, px: int, top: int, col: Color) -> void:
	var f := UITheme.pixel_font()
	var ts := TextServerManager.get_primary_interface()
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var pen := floorf((W - w) / 2.0 + 0.5)
	var base := floorf(top + f.get_ascent(px) + 0.5)
	var sz := Vector2i(px, 0)
	var rid := ts.create_shaped_text()
	ts.shaped_text_add_string(rid, s, f.get_rids(), px)
	for g: Dictionary in ts.shaped_text_get_glyphs(rid):
		var fr: RID = g["font_rid"]
		var gi: int = g["index"]
		ts.font_render_glyph(fr, sz, gi)
		var ti := ts.font_get_glyph_texture_idx(fr, sz, gi)
		if ti >= 0:
			var at := Vector2(pen, base) + (g["offset"] as Vector2) + ts.font_get_glyph_offset(fr, sz, gi)
			_blit(img, ts.font_get_texture_image(fr, sz, ti), ts.font_get_glyph_uv_rect(fr, sz, gi),
				Vector2i(roundi(at.x), roundi(at.y)), col)
		pen += float(g["advance"])
	ts.free_rid(rid)


static func _blit(img: Image, glyphs: Image, uv: Rect2, at: Vector2i, col: Color) -> void:
	for yy in int(uv.size.y):
		for xx in int(uv.size.x):
			var p := Vector2i(int(uv.position.x) + xx, int(uv.position.y) + yy)
			if glyphs.get_pixelv(p).a < 0.5:
				continue
			var q := at + Vector2i(xx, yy)
			if q.x >= 0 and q.x < W and q.y >= 0 and q.y < H and img.get_pixelv(q).a > 0.0:
				img.set_pixelv(q, col)
