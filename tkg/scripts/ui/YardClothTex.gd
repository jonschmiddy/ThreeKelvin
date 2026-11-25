class_name YardClothTex
extends RefCounted

## A banner's cloth as a material: the flat cloth (`YardBanner.flat_cloth`) made into what hangs, and
## the pixel font's words drawn into a cloth. Tapestry is the material (Jon, Nov 24, the banner page);
## another would plug in at `make`.
## Why: docs/why/YardBanner.md#material

const W := YardBanner.BW
const H := YardBanner.CLOTH
## How tapestry takes light (the page's MATS.tapestry): folds x1.8, light wrapped 0.15 further, darks
## deepened by a 1.05 power, and a mark or an accent thread glints past 0.05.
const NEX := 1.8
const WRAP := 0.15
const GAMMA := 1.05
const SPEC := 0.05
## Each manufacturer's damask, tone on tone (the page's PATTERNS; Jon's picks Nov 24: Probate A, Redline A,
## Verity B, Cygnet B; Calyx the page's rule from its emblem): rows, the pattern's tone, never offset.
const PATTERNS := {
	"korvan": [["#......#", ".#....#.", "..#..#..", "...##...", "........", "........"], 1.0, false],
	"solari": [["...#....", "...#....", ".##.##..", "...#....", "...#....", "........", "......#.", "........"], 1.0, false],
	"???": [["#...", ".#..", "..#.", "...#"], 0.935, true],
	"probate": [["...#....", "..#.#...", ".#...#..", "...#....", ".#...#..", "..#.#...", "...#....", "........"], 1.0, false],
	"redline": [["..##.##.", ".##.##..", "##.##...", "........", "........", "........"], 1.0, false],
	"verity": [["..#...", ".#.#..", "#.#.#.", ".#.#..", "..#...", "......"], 1.0, false],
	"cygnet": [["..####..", ".#....#.", "#......#", "#......#", ".#....#.", "..####.."], 1.0, false],
}
## The hem, border and fringe thread: each manufacturer's accent, two tones (the page's ACCENT).
const ACCENT := {
	"korvan": [Color8(224, 136, 46), Color8(150, 86, 26)],
	"solari": [Color8(184, 64, 26), Color8(118, 38, 14)],
	"???": [Color8(168, 173, 184), Color8(124, 129, 140)],
	"probate": [Color8(111, 154, 136), Color8(74, 106, 92)],
	"redline": [Color8(226, 75, 74), Color8(150, 44, 44)],
	"verity": [Color8(122, 42, 54), Color8(82, 26, 36)],
	"cygnet": [Color8(88, 200, 216), Color8(50, 128, 140)],
	"calyx": [Color8(63, 143, 107), Color8(40, 96, 70)],
}
## Alpha in the atlas: a cloth pixel, a painted mark, an accent thread.
const A_CLOTH := 255
const A_INK := 128
const A_GOLD := 192


## A cloth made in its material: its pixels (alpha 0 or 255), its painted marks and accent threads, and each
## pixel's field colour (the rim light's colour there).
class Made extends RefCounted:
	var data: Image
	## 1 where a painted mark is (it takes whole light steps and the glint).
	var ink := PackedByteArray()
	## 1 where an accent thread is (the hem, border and fringe: it glints).
	var gold := PackedByteArray()
	## Each pixel's field colour, rgb.
	var field := PackedByteArray()


## The cloth in its material; `key` is the cloth's (`YardBanner.cloth_key`), for its damask and accent.
static func make(src: Image, key: String) -> Made:
	return tapestry(src, key)


## Tapestry (the page's prepTex, its tapestry branch): the manufacturer's damask on the field, a darker rod
## sleeve, a two-tone border in its accent three pixels in, a short fringe off the fork's edge, the marks
## sat in and embroidered in satin stitch. Baked once a session, never per frame.
## Why: docs/why/YardBanner.md#material
static func tapestry(src: Image, key: String) -> Made:
	var s := src.get_data()
	var d := s.duplicate()
	var m := Made.new()
	m.ink.resize(W * H)
	m.gold.resize(W * H)
	m.field.resize(W * H * 3)
	var dist := _dist(s, 6)
	var cls := _classes(s, dist, m.ink, m.field)
	var pat: Array = PATTERNS.get(key, [_motif(YardBanner.EMBLEM.get(StringName(key), [[-3.5, -3.5, 7, 7]])), 1.0, false])
	var acc: Array = ACCENT.get(key, ACCENT["???"])
	for y in H:
		for x in W:
			var t := y * W + x
			if cls[t] != 2:
				continue
			var k := 0.9
			if y >= 6 and dist[t] >= 5 and _pattern_at(pat, x, y - 6):
				k = float(pat[1])
			if y <= 3:
				k = 0.8
			elif y == 4:
				k = 0.66
			if y >= 6 and (dist[t] == 2 or dist[t] == 3):
				_put(d, t, acc[0] if ((y + (x & 1) * 2) & 3) < 2 else acc[1])
				m.gold[t] = 1
				_field(m.field, t, acc[0])
				continue
			if (y > 0 and m.ink[t - W] != 0) or (y > 0 and x > 0 and m.ink[t - W - 1] != 0):
				k *= 0.82
			for c in 3:
				d[t * 4 + c] = u8(d[t * 4 + c] * k)
			var l := 0.3 * d[t * 4] + 0.59 * d[t * 4 + 1] + 0.11 * d[t * 4 + 2]
			for c in 3:
				d[t * 4 + c] = u8(l + (d[t * 4 + c] - l) * 1.12)
	_fringe(s, d, m, acc[1])
	_embroider(d, m.ink)
	m.data = Image.create_from_data(W, H, false, Image.FORMAT_RGBA8, d)
	return m


## A short fringe under the fork's edge, every other column, one thread and sometimes a second, darker.
static func _fringe(s: PackedByteArray, d: PackedByteArray, m: Made, f2: Color) -> void:
	for x in range(0, W, 2):
		for y in range(86, H - 1):
			if s[(y * W + x) * 4 + 3] == 0 or s[((y + 1) * W + x) * 4 + 3] != 0:
				continue
			var t1 := (y + 1) * W + x
			_put(d, t1, f2)
			m.gold[t1] = 1
			_field(m.field, t1, f2)
			if y + 2 < H and s[((y + 2) * W + x) * 4 + 3] == 0 and hash01(x, 3) < 0.6:
				var t2 := t1 + W
				d[t2 * 4] = u8(f2.r8 * 0.75)
				d[t2 * 4 + 1] = u8(f2.g8 * 0.75)
				d[t2 * 4 + 2] = u8(f2.b8 * 0.75)
				d[t2 * 4 + 3] = 255
				_field(m.field, t2, f2)
			break


## The marks embroidered: satin stitch, a lighter stitch along the top of each broad mark.
static func _embroider(d: PackedByteArray, ink: PackedByteArray) -> void:
	for y in H:
		for x in W:
			var t := y * W + x
			if ink[t] == 0:
				continue
			var k := 1.08 if (x + y) & 1 else 1.0
			if y > 20 and not _ink_at(ink, x, y - 1) and int(_ink_at(ink, x - 1, y)) + int(_ink_at(ink, x + 1, y)) >= 1:
				k = 1.25
			for c in 3:
				d[t * 4 + c] = u8(minf(255.0, d[t * 4 + c] * k + (18.0 if k > 1.2 else 0.0)))


static func _ink_at(ink: PackedByteArray, x: int, y: int) -> bool:
	return x >= 0 and x < W and y >= 0 and y < H and ink[y * W + x] != 0


static func _put(d: PackedByteArray, t: int, c: Color) -> void:
	d[t * 4] = c.r8
	d[t * 4 + 1] = c.g8
	d[t * 4 + 2] = c.b8
	d[t * 4 + 3] = 255


static func _field(f: PackedByteArray, t: int, c: Color) -> void:
	f[t * 3] = c.r8
	f[t * 3 + 1] = c.g8
	f[t * 3 + 2] = c.b8


static func _pattern_at(p: Array, x: int, y: int) -> bool:
	var rows: Array = p[0]
	var ph := rows.size()
	var pw := (rows[0] as String).length()
	var off := 0 if p[2] else ((y / ph) & 1) * (pw >> 1)
	return (rows[y % ph] as String)[(x + off) % pw] == "#"


## The page's rule for a manufacturer with no damask drawn (Calyx): its emblem shrunk to six cells of an 8 x 8 tile.
static func _motif(rects: Array) -> Array[String]:
	var g: Array[PackedByteArray] = []
	for y in 8:
		var row := PackedByteArray()
		row.resize(8)
		g.append(row)
	for e: Array in rects:
		var x0 := _jsround(_cell(float(e[0])))
		var y0 := _jsround(_cell(float(e[1])))
		var x1 := maxi(x0 + 1, _jsround(_cell(float(e[0]) + float(e[2]))))
		var y1 := maxi(y0 + 1, _jsround(_cell(float(e[1]) + float(e[3]))))
		for yy in range(y0, mini(8, y1)):
			for xx in range(x0, mini(8, x1)):
				g[yy][xx] = 1
	var rows: Array[String] = []
	for row in g:
		var r := ""
		for v in row:
			r += "#" if v else "."
		rows.append(r)
	return rows


static func _cell(u: float) -> float:
	return 1.0 + (u + 4.5) * 6.0 / 9.0


static func _jsround(v: float) -> int:
	return int(floorf(v + 0.5))


## A byte as JavaScript's Uint8ClampedArray stores one: clamped, rounded half to even.
static func u8(v: float) -> int:
	return clampi(YardBanner.even(v), 0, 255)


## Each opaque pixel's ring distance to a hole (1 to `cap`): a transparent pixel, or past the left, right or
## foot (never past the top, which meets the rod).
static func _dist(s: PackedByteArray, cap: int) -> PackedByteArray:
	var hd := PackedByteArray()
	hd.resize(W * H)
	for y in H:
		for x in W:
			var best := mini(mini(x + 1, W - x), cap)
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
			var k := cap
			for dy in range(1 - cap, cap):
				var yy := y + dy
				if yy < 0:
					continue
				var h := 0 if yy >= H else int(hd[yy * W + x])
				k = mini(k, maxi(absi(dy), h))
			dist[y * W + x] = maxi(1, k)
	return dist


## 0 none, 1 the outline, 2 the row's field, 3 a painted mark; each pixel's field is its row's commonest colour.
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
		for x in W:
			var i := (y * W + x) * 4
			var t := y * W + x
			if s[i + 3] == 0:
				continue
			field[t * 3] = mode >> 16
			field[t * 3 + 1] = (mode >> 8) & 255
			field[t * 3 + 2] = mode & 255
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
