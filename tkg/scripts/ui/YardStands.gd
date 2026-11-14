class_name YardStands
extends RefCounted

## The yard's stands, measured: a stand picture's cap, a stand cut to a height, the hull's
## ink box and middle, where a fitted part hangs. `YardScene` keeps the caches these fill.

## The opaque box of a picture, by the page's measure (alpha from 128).
static func ink(img: Image) -> Rect2i:
	var x0 := img.get_width()
	var y0 := img.get_height()
	var x1 := -1
	var y1 := -1
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a8 >= 128:
				x0 = mini(x0, x)
				x1 = maxi(x1, x)
				y0 = mini(y0, y)
				y1 = maxi(y1, y)
	if x1 < 0:
		return Rect2i()
	return Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)


## Mass middle, not box middle: a heavy's long nose put the box middle 27 px ahead of its bulk.
## Why: docs/why/YardScene.md#hull-middle
static func hull_mass_x(img: Image, ink: Rect2i) -> float:
	var sum := 0.0
	var n := 0.0
	for x in ink.size.x:
		var k := 0
		for y in ink.size.y:
			if img.get_pixel(ink.position.x + x, ink.position.y + y).a8 >= 128:
				k += 1
		sum += (float(x) + 0.5) * float(k)
		n += float(k)
	return sum / n if n > 0.0 else float(ink.size.x) * 0.5


## The ink columns where a fitted part hangs below the hull's own underside
## (`MountPoints.part_rects_canvas`): a stand is kept from under them.
static func hanging(v: ShipView, img: Image, ink: Rect2i, under: PackedInt32Array) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(ink.size.x)
	var mounts: MountPoints = null
	for c in v.get_children():
		if c is MountPoints:
			mounts = c
	if mounts == null:
		return out
	# (the view sized to its canvas, as it stands, so the parts are placed on it)
	v.size = Vector2(img.get_width(), img.get_height())
	for r: Rect2 in mounts.part_rects_canvas():
		var bottom := int(ceilf(r.end.y)) - 1 - ink.position.y
		for x in range(maxi(0, int(floorf(r.position.x)) - ink.position.x), mini(ink.size.x, int(ceilf(r.end.x)) - ink.position.x)):
			if under[x] < 0 or bottom > under[x]:
				out[x] = 1
	return out


## Seat row is the saddle's front edge, so no top face shows under the belly (Jon, B).
## Why: docs/why/YardScene.md#stand-meets-hull
static func stand_cap(si: Image, seat_rows: int, _cap_cache: Dictionary) -> Dictionary:
	var key := "%d:%d" % [si.get_instance_id(), seat_rows]
	if _cap_cache.has(key):
		return _cap_cache[key]
	var w := si.get_width()
	var tops := PackedInt32Array()
	tops.resize(w)
	var least := 1 << 30
	for x in w:
		tops[x] = 1 << 30
		for y in si.get_height():
			if si.get_pixel(x, y).a8 >= 128:
				tops[x] = y
				break
		least = mini(least, tops[x])
	var a := -1
	var b := -1
	for x in w:
		if tops[x] <= maxi(seat_rows - 1, least):
			if a < 0:
				a = x
			b = x
	var cap := {"top": tops, "a": a, "b": b, "mid": float(a + b + 1) * 0.5}
	_cap_cache[key] = cap
	return cap


static func stand_image(st: Dictionary, _stand_cache: Dictionary) -> Image:
	var name := String(st.get("picture", ""))
	if name == "":
		return null
	if not _stand_cache.has(name):
		var t := load(YardScene.DIR + name) as Texture2D
		var img: Image = t.get_image() if t != null else null
		if img != null and img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
		_stand_cache[name] = img
	return _stand_cache[name]


## A stand made h tall by repeating a row, or cutting rows where the sides match best.
static func sized(si: Image, st: Dictionary, h: int, level: String, dial: Dictionary) -> Image:
	var w := si.get_width()
	var sh := si.get_height()
	if h >= sh:
		var row := int(st.get("row", int(floorf(float(sh) * 0.6))))
		var extra := h - sh
		var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
		for y in h:
			var sy := y if y <= row else (row if y <= row + extra else y - extra)
			out.blit_rect(si, Rect2i(0, sy, w, 1), Vector2i(0, y))
		return out
	var n := sh - h
	var cut: Array = st.get("cut", [0, sh])
	if level == "outpost" and int(dial.get("columns", 60)) < 53 and st.has("cut_low"):
		cut = st["cut_low"]
	var lo := int(cut[0])
	var hi := int(cut[1])
	var data := si.get_data()
	var best_a := -1
	var best_t := 0
	var a := maxi(1, lo)
	while a + n <= mini(sh - 1, hi):
		var t := 0
		var r1 := (a - 1) * w * 4
		var r2 := (a + n) * w * 4
		for i in w * 4:
			t += absi(int(data[r1 + i]) - int(data[r2 + i]))
		if best_a < 0 or t < best_t:
			best_a = a
			best_t = t
		a += 1
	if best_a < 0:
		best_a = maxi(1, int(floorf(float(lo + hi - n) / 2.0 + 0.5)))
	var out2 := Image.create(w, h, false, Image.FORMAT_RGBA8)
	out2.blit_rect(si, Rect2i(0, 0, w, best_a), Vector2i.ZERO)
	out2.blit_rect(si, Rect2i(0, best_a + n, w, sh - best_a - n), Vector2i(0, best_a))
	return out2
