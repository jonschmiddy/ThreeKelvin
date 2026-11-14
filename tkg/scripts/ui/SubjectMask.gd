class_name SubjectMask
extends RefCounted

## The subject's pieces as pictures: the index's records, opaque-pixel masks, turned and small
## pictures, and what stands clear of what. Node-free; `SubjectPlan` and `LocalSubject` call it.
## Why: docs/why/LocalSubject.md#subject-staging

const INDEX_PATH := "res://art/subjects/index.json"

static var _index: Dictionary = {}
## Pieces turned at load (`turned`), by "id:degrees".
static var _turned: Dictionary = {}
## Which kept pool ships each role may be (`index.json` "roles").
static var _roles: Dictionary = {}
## Opaque-pixel masks of pieces as drawn (`mask_of`), and dilated ones.
static var _masks: Dictionary = {}


# --------------------------------------------------------------- the index

static func index() -> Dictionary:
	if _index.is_empty():
		var f := FileAccess.open(INDEX_PATH, FileAccess.READ)
		if f != null:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_index = (d as Dictionary).get("pieces", {})
				_roles = (d as Dictionary).get("roles", {})
	return _index


## The kept pool ships a role may be, by piece id.
static func role_ships(role: String) -> Array:
	index()
	return _roles.get(role, [])


## A piece's record, from the index.
static func piece_info(id: StringName) -> Dictionary:
	return index().get(String(id), {})


## The index record, with a painter moon cut to a lumpy outline when the stage asks.
static func rec_for(m: Dictionary) -> Dictionary:
	var p := piece_info(StringName(m.id))
	# (`world`: the moon recipe painted as another world -- a moon in pieces)
	if m.has("world") and String(p.get("kind", "")) == "painter":
		p = p.duplicate()
		p.world = String(m.world)
	if m.has("lumpy") and String(p.get("kind", "")) == "painter" and (p.get("lobes", []) as Array).is_empty():
		p = p.duplicate()
		p.lobes = [[float(p.cx), float(p.cy), float(p.r) * 1.17, float(m.lumpy)]]
		p.lo = 0.7
		p.amp = 0.34
	return p


## A piece's size on screen at scale 1, px (a painter piece's from its radius).
static func piece_size(id: StringName, r: float = 0.0) -> Vector2:
	var p: Dictionary = piece_info(id)
	if p.is_empty():
		return Vector2.ZERO
	if String(p.get("kind", "")) == "painter":
		var rr := r if r > 0.0 else float(p.get("r", 40))
		var k := rr / float(p.get("r", 40))
		return Vector2(float(p.w), float(p.h)) * k
	return Vector2(float(p.w), float(p.h))


## Opaque pixels as drawn, at the half or quarter picture and turn the piece really has.
static func mask_of(m: Dictionary) -> Dictionary:
	var id := StringName(m.id)
	var sc := float(m.scale)
	var turn := float(m.get("turn", 0.0))
	var r := float(m.get("r", 0.0))
	var flip := bool(m.get("flip", false))
	var key := "%s|%s|%s|%s|%s|%s" % [id, sc, turn, r, flip, m.get("lumpy", "")]
	if _masks.has(key):
		return _masks[key]
	var p := rec_for(m)
	if p.is_empty():
		return {}
	var img: Image = null
	var base := 1.0
	match String(p.get("kind", "")):
		"painter":
			var r0 := float(p.r)
			var k := (r / r0) if r > 0.0 else 1.0
			var w := int(roundf(float(p.w) * k))
			var h := int(roundf(float(p.h) * k))
			if not (p.get("lobes", []) as Array).is_empty():
				img = lumpy_mask(w, h, k, p)
			else:
				img = Image.create(w, h, false, Image.FORMAT_RGBA8)
				var c := Vector2(float(p.cx), float(p.cy)) * k
				for yy in h:
					for xx in w:
						if Vector2(float(xx) + 0.5, float(yy) + 0.5).distance_to(c) <= r0 * k:
							img.set_pixel(xx, yy, Color(1, 0, 0, 1))
		_:
			var path := String(p.file)
			if sc <= 0.25 + 0.001 and p.has("quarter"):
				path = String(p.quarter)
				base = 0.25
			elif sc <= 0.5 + 0.001 and p.has("half"):
				path = String(p.half)
				base = 0.5
			img = _image_of(path)
			# (a kept piece with no small picture of its own: one made the flyby's
			# way, `small_image`)
			if base == 1.0 and sc <= 0.5 + 0.001 and img != null:
				var kk := 4 if sc <= 0.25 + 0.001 else 2
				var sm := small_image(path, kk)
				if sm != null:
					img = sm.duplicate()
					base = 1.0 / float(kk)
	if img == null:
		return {}
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	if not is_zero_approx(turn):
		img = turned_image(img, turn)
	if flip:
		img.flip_x()
	var f := sc / base
	if not is_equal_approx(f, 1.0):
		img.resize(maxi(1, int(roundf(float(img.get_width()) * f))), maxi(1, int(roundf(float(img.get_height()) * f))), Image.INTERPOLATE_NEAREST)
	var w2 := img.get_width()
	var h2 := img.get_height()
	var bits := PackedByteArray()
	bits.resize(w2 * h2)
	var painter := String(p.get("kind", "")) == "painter"
	for yy in h2:
		for xx in w2:
			var c2 := img.get_pixel(xx, yy)
			bits[yy * w2 + xx] = 1 if (c2.r > 0.5 if painter else c2.a > 0.5) else 0
	var d := {w = w2, h = h2, bits = bits, key = key}
	_masks[key] = d
	return d


## A picture's pixels: from the imported texture (what an export carries), or
## from the file itself where there is no renderer to ask (a headless test).
static func _image_of(path: String) -> Image:
	var tex := load(path) as Texture2D
	var img: Image = tex.get_image() if tex != null else null
	if img == null or img.is_empty():
		img = Image.load_from_file(path)
	return img


## Small pictures made here, by "path:k".
static var _smalls: Dictionary = {}


## Reduced the flyby's way, so pixel art stays pixel art, not every k-th pixel of the big one.
## Why: docs/why/LocalSubject.md#small-pictures
static func small_image(path: String, k: int) -> Image:
	var key := "%s:%d" % [path, k]
	if _smalls.has(key):
		return _smalls[key]
	var src := _image_of(path)
	if src == null:
		return null
	src = src.duplicate()
	if src.is_compressed():
		src.decompress()
	src.convert(Image.FORMAT_RGBA8)
	var w := src.get_width()
	var h := src.get_height()
	# its own colours, the commonest 24 opaque ones
	var counts := {}
	for y in h:
		for x in w:
			var c := src.get_pixel(x, y)
			if c.a > 0.5:
				var hx := c.to_rgba32()
				counts[hx] = int(counts.get(hx, 0)) + 1
	var keys := counts.keys()
	keys.sort_custom(func(a: int, b: int) -> bool: return int(counts[a]) > int(counts[b]))
	var pal: Array[Color] = []
	for i in mini(24, keys.size()):
		var cc := Color.hex(int(keys[i]))
		pal.append(cc)
	var W := (w + k - 1) / k
	var H := (h + k - 1) / k
	var out := Image.create(W, H, false, Image.FORMAT_RGBA8)
	for by in H:
		for bx in W:
			var cov := 0.0
			var acc := Vector3.ZERO
			for yy in k:
				for xx in k:
					var x := bx * k + xx
					var y := by * k + yy
					if x >= w or y >= h:
						continue
					var c := src.get_pixel(x, y)
					cov += c.a
					acc += Vector3(c.r, c.g, c.b) * c.a
			if cov / float(k * k) < 0.5:
				continue
			var avg := acc / maxf(cov, 1e-6)
			var best := Color(avg.x, avg.y, avg.z)
			var bd := 1e9
			for pc in pal:
				var d := Vector3(pc.r - avg.x, pc.g - avg.y, pc.b - avg.z).length_squared()
				if d < bd:
					bd = d
					best = pc
			best.a = 1.0
			out.set_pixel(bx, by, best)
	_smalls[key] = out
	return out


## Where a planned piece's picture starts, its top-left pixel.
static func _corner(m: Dictionary, mk: Dictionary) -> Vector2i:
	# floor, not round: a half pixel rounds away from zero, so a piece moved by a
	# whole pixel across the middle would land a pixel off from its neighbours
	return Vector2i(((m.at as Vector2) - Vector2(float(mk.w), float(mk.h)) * 0.5).floor())


## Whether any opaque pixel of `a` (at `pa`) comes within `mx`, `my` px of an
## opaque pixel of `b` (at `pb`). 0, 0: whether they share a pixel.
static func touches(a: Dictionary, pa: Vector2i, b: Dictionary, pb: Vector2i, mx: int, my: int) -> bool:
	var ra := Rect2i(pa, Vector2i(int(a.w), int(a.h)))
	var rb := Rect2i(pb - Vector2i(mx, my), Vector2i(int(b.w) + mx * 2, int(b.h) + my * 2))
	var inter := ra.intersection(rb)
	if inter.size.x <= 0 or inter.size.y <= 0:
		return false
	var bd := _dilated(b, mx, my)
	var ab: PackedByteArray = a.bits
	var bb: PackedByteArray = bd.bits
	var aw := int(a.w)
	var bw := int(bd.w)
	var o := pb - Vector2i(mx, my)
	for y in range(inter.position.y, inter.end.y):
		for x in range(inter.position.x, inter.end.x):
			if ab[(y - pa.y) * aw + (x - pa.x)] != 0 and bb[(y - o.y) * bw + (x - o.x)] != 0:
				return true
	return false


## A mask grown by `mx`, `my` px each way.
static func _dilated(b: Dictionary, mx: int, my: int) -> Dictionary:
	if mx == 0 and my == 0:
		return b
	var key := "dil|%s|%d|%d" % [b.get("key", ""), mx, my]
	if _masks.has(key):
		return _masks[key]
	var w := int(b.w)
	var h := int(b.h)
	var W := w + mx * 2
	var H := h + my * 2
	var src: PackedByteArray = b.bits
	var row := PackedByteArray()
	row.resize(W * h)
	for y in h:
		for x in w:
			if src[y * w + x] != 0:
				for dx in range(0, mx * 2 + 1):
					row[y * W + x + dx] = 1
	var out := PackedByteArray()
	out.resize(W * H)
	for y in h:
		for x in W:
			if row[y * W + x] != 0:
				for dy in range(0, my * 2 + 1):
					out[(y + dy) * W + x] = 1
	var d := {w = W, h = H, bits = out}
	_masks[key] = d
	return d


## Whether planned piece `m` stands clear of every one of `others` by the drift
## the two can travel apart (`clear_of`'s rule, for placing one at a time).
static func _clear(m: Dictionary, others: Array) -> bool:
	var a := mask_of(m)
	if a.is_empty():
		return true
	var pa := _corner(m, a)
	var da := drift_of(m)
	for o: Dictionary in others:
		var b := mask_of(o)
		if b.is_empty():
			continue
		var d := da + drift_of(o)
		if touches(a, pa, b, _corner(o, b), int(ceilf(d.x)), int(ceilf(d.y))):
			return false
	return true


## How far a planned piece can travel from where it stands: its drift (as
## `_process` moves it) and the reach of its tumble at its ends.
static func drift_of(m: Dictionary) -> Vector2:
	if bool(m.get("structure", false)):
		return Vector2.ZERO
	var amp := 3.0 if float(m.far) > 0.0 else 5.0
	var d := Vector2(amp * 0.5, amp * 0.4)
	if bool(m.get("swim", false)):
		d = Vector2(amp * 1.6, 2.0)
	if bool(m.get("tether", false)):
		d = Vector2(0.0, 1.5)
	var tb := float(m.get("tumble", 0.0))
	if tb > 0.0:
		var sz := piece_size(StringName(m.id), float(m.get("r", 0.0))) * float(m.scale)
		d += Vector2(sz.y * 0.5, sz.x * 0.5) * sin(deg_to_rad(tb))
	if float(m.get("roll", 0.0)) != 0.0:
		# turning right over, its corners reach past its box
		var sz2 := piece_size(StringName(m.id)) * float(m.scale)
		var reach := (sz2.length() - minf(sz2.x, sz2.y)) * 0.5
		d += Vector2(reach, reach)
	return d


## Flags pairs closer than their drift, except own-rock, clamped and docked pieces.
static func clear_of(planned: Array) -> Array[String]:
	var bad: Array[String] = []
	var ms: Array = []
	for m: Dictionary in planned:
		ms.append(mask_of(m))
	for i in planned.size():
		for j in range(i + 1, planned.size()):
			var a: Dictionary = planned[i]
			var b: Dictionary = planned[j]
			if ms[i].is_empty() or ms[j].is_empty():
				continue
			var same := int(a.get("st_i", -1)) == int(b.get("st_i", -2))
			if same and ((bool(a.get("on_base", false)) and bool(b.get("base_of", false))) \
					or (bool(b.get("on_base", false)) and bool(a.get("base_of", false))) \
					or bool(a.get("welds", false)) or bool(b.get("welds", false))):
				continue
			var pa := _corner(a, ms[i])
			var pb := _corner(b, ms[j])
			var docked := int(a.get("dock_to", -1)) == j or int(b.get("dock_to", -1)) == i
			if docked:
				if touches(ms[i], pa, ms[j], pb, 0, 0) or not touches(ms[i], pa, ms[j], pb, 1, 1):
					bad.append("%s docked on %s (not touching along an edge)" % [a.id, b.id])
				continue
			var d := drift_of(a) + drift_of(b)
			if touches(ms[i], pa, ms[j], pb, int(ceilf(d.x)), int(ceilf(d.y))):
				bad.append("%s ~ %s" % [a.id, b.id])
	return bad


## `turned`'s pixels, for an Image.
static func turned_image(src: Image, deg: float) -> Image:
	var sw := src.get_width()
	var sh := src.get_height()
	var out_sz := turned_size(Vector2(sw, sh), deg)
	var ow := int(out_sz.x)
	var oh := int(out_sz.y)
	var img := Image.create(ow, oh, false, Image.FORMAT_RGBA8)
	var a := deg_to_rad(deg)
	var c := cos(a)
	var sn := sin(a)
	var ocx := float(ow) * 0.5
	var ocy := float(oh) * 0.5
	var scx := float(sw) * 0.5
	var scy := float(sh) * 0.5
	for y in oh:
		for x in ow:
			var dx := float(x) + 0.5 - ocx
			var dy := float(y) + 0.5 - ocy
			var sx := floori(dx * c + dy * sn + scx)
			var sy := floori(-dx * sn + dy * c + scy)
			if sx >= 0 and sy >= 0 and sx < sw and sy < sh:
				img.set_pixel(x, y, src.get_pixel(sx, sy))
	return img


## The box a `sz` picture needs once turned `deg` degrees.
static func turned_size(sz: Vector2, deg: float) -> Vector2:
	if is_zero_approx(deg):
		return sz
	var a := deg_to_rad(deg)
	var c := absf(cos(a))
	var sn := absf(sin(a))
	return Vector2(ceilf(sz.x * c + sz.y * sn), ceilf(sz.x * sn + sz.y * c))


## Turned once, pixel for pixel: a sprite rotated live on nearest filtering ripples.
static func turned(id: StringName, tex: Texture2D, deg: float) -> Texture2D:
	var k := "%s:%s" % [id, deg]
	if _turned.has(k):
		return _turned[k]
	var src := tex.get_image()
	if src == null:
		return tex
	if src.is_compressed():
		src.decompress()
	src.convert(Image.FORMAT_RGBA8)
	var sw := src.get_width()
	var sh := src.get_height()
	var out_sz := turned_size(Vector2(sw, sh), deg)
	var ow := int(out_sz.x)
	var oh := int(out_sz.y)
	var img := Image.create(ow, oh, false, Image.FORMAT_RGBA8)
	var a := deg_to_rad(deg)
	var c := cos(a)
	var sn := sin(a)
	var ocx := float(ow) * 0.5
	var ocy := float(oh) * 0.5
	var scx := float(sw) * 0.5
	var scy := float(sh) * 0.5
	for y in oh:
		for x in ow:
			# back from the turned box into the original
			var dx := float(x) + 0.5 - ocx
			var dy := float(y) + 0.5 - ocy
			var sx := floori(dx * c + dy * sn + scx)
			var sy := floori(-dx * sn + dy * c + scy)
			if sx >= 0 and sy >= 0 and sx < sw and sy < sh:
				img.set_pixel(x, y, src.get_pixel(sx, sy))
	var t := ImageTexture.create_from_image(img)
	_turned[k] = t
	return t


## The recipe's lumpy outline as a mask: R inside, G the cut's dark rim.
static func lumpy_mask(w: int, h: int, k: float, p: Dictionary) -> Image:
	var lobes: Array = p.get("lobes", [])
	var waist: Array = p.get("waist", [])
	var lo := float(p.get("lo", 0.72))
	var amp := float(p.get("amp", 0.32))
	var inside := PackedByteArray()
	inside.resize(w * h)
	for y in h:
		for x in w:
			var X := float(x) / k
			var Y := float(y) / k
			var hit := false
			for L: Array in lobes:
				var dx := X - float(L[0])
				var dy := Y - float(L[1])
				var a := atan2(dy, dx)
				var rr := float(L[2]) * (lo + amp * _fbm(cos(a) * 1.7 + float(L[3]), sin(a) * 1.7 + float(L[3]) * 2.1))
				if sqrt(dx * dx + dy * dy) < rr:
					hit = true
					break
			if not hit and waist.size() == 5:
				var x0 := float(waist[0])
				var y0 := float(waist[1])
				var x1 := float(waist[2])
				var y1 := float(waist[3])
				var t := clampf(((X - x0) * (x1 - x0) + (Y - y0) * (y1 - y0)) / ((x1 - x0) * (x1 - x0) + (y1 - y0) * (y1 - y0)), 0.0, 1.0)
				var px := x0 + (x1 - x0) * t
				var py := y0 + (y1 - y0) * t
				if Vector2(X - px, Y - py).length() < float(waist[4]) * (0.8 + 0.4 * _fbm(X / 30.0, Y / 30.0)):
					hit = true
			inside[y * w + x] = 1 if hit else 0
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			if inside[y * w + x] == 0:
				continue
			var edge := false
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					var X2 := x + dx
					var Y2 := y + dy
					if X2 < 0 or Y2 < 0 or X2 >= w or Y2 >= h or inside[Y2 * w + X2] == 0:
						edge = true
			img.set_pixel(x, y, Color(1.0, 1.0 if edge else 0.0, 0.0, 1.0))
	return img


## Value noise, two octaves -- the samples' `fbm2`, near enough: a lumpy outline,
## not the same lumps.
static func _fbm(x: float, y: float) -> float:
	var v := 0.0
	var a := 0.5
	var f := 1.0
	for o in 3:
		v += a * _vnoise(x * f, y * f)
		f *= 2.0
		a *= 0.5
	return v / 0.875


static func _vnoise(x: float, y: float) -> float:
	var ix := floori(x)
	var iy := floori(y)
	var fx := x - float(ix)
	var fy := y - float(iy)
	var ux := fx * fx * (3.0 - 2.0 * fx)
	var uy := fy * fy * (3.0 - 2.0 * fy)
	return lerpf(lerpf(_h2(ix, iy), _h2(ix + 1, iy), ux), lerpf(_h2(ix, iy + 1), _h2(ix + 1, iy + 1), ux), uy)


static func _h2(x: int, y: int) -> float:
	var n := x * 374761393 + y * 668265263
	n = (n ^ (n >> 13)) * 1274126177
	return float((n ^ (n >> 16)) & 0xFFFF) / 65535.0
