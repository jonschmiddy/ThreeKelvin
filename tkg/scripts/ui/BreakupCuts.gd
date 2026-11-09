class_name BreakupCuts
extends RefCounted
## The breakup cuts: the static, seed-deterministic part of ShipBreakup, from the hull
## image to the pieces and the plan. Pure CPU on Images and arrays, so a worker may run it.


static func _cut_classic(img: Image, used: Rect2i, seed: int, is_boss: bool) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	# Lone pixels are the canvas's starfield, not hull: `_hull_pic` drops them.
	var H := _hull_pic(img, used, 0)
	var r: Rect2i = H.r
	if int(H.n) == 0:
		return {majors = [], shards = [], centre = r.get_center()}
	var w: int = H.w
	var h: int = H.h
	var n := w * h
	var keep: PackedByteArray = H.mask
	var cx: float = H.cx
	var cy: float = H.cy
	# Seeds spread along the hull's length, jittered: hulls are long, so the
	# cracks should run across them rather than along them.
	var k := 4 if is_boss else 3
	if w < 70:
		k = 2
	var seeds: Array[Vector2] = []
	for i in k:
		var sx := (float(i) + 0.5) / float(k) * w + rng.randf_range(-0.12, 0.12) * w
		var sy := cy + rng.randf_range(-0.25, 0.25) * h
		seeds.append(Vector2(sx, sy))
	# Value noise on a coarse grid, one field per seed, so neighbouring borders
	# wander independently.
	var cell := 5
	var gw := w / cell + 2
	var gh := h / cell + 2
	var fields: Array = []
	for i in k:
		var f := PackedFloat32Array()
		f.resize(gw * gh)
		for j in f.size():
			f[j] = rng.randf_range(-1.0, 1.0)
		fields.append(f)
	var amp := 0.11 * float(w) / float(k)
	var label := PackedInt32Array()
	label.resize(n)
	for y in h:
		for x in w:
			var idx := y * w + x
			if keep[idx] == 0:
				label[idx] = -1
				continue
			var best := 1e9
			var bi := 0
			for i in k:
				var d := Vector2(x, y).distance_to(seeds[i]) \
					+ amp * _noise(fields[i], gw, float(x) / cell, float(y) / cell)
				if d < best:
					best = d
					bi = i
			label[idx] = bi
	# The crack band: every hull pixel within a jagged radius of a border
	# between two majors becomes shard material.
	var border := PackedByteArray()
	border.resize(n)
	for y in h:
		for x in w:
			var idx2 := y * w + x
			if label[idx2] < 0:
				continue
			for o in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, 1)]:
				var xx2: int = x + o.x
				var yy2: int = y + o.y
				if xx2 >= 0 and yy2 >= 0 and xx2 < w and yy2 < h:
					var l2 := label[yy2 * w + xx2]
					if l2 >= 0 and l2 != label[idx2]:
						border[idx2] = 1
						border[yy2 * w + xx2] = 1
	var bandf := PackedFloat32Array()
	bandf.resize(gw * gh)
	for j2 in bandf.size():
		bandf[j2] = rng.randf_range(0.0, 1.0)
	var shard := PackedByteArray()
	shard.resize(n)
	var reach := 2 if not is_boss else 3
	for y in h:
		for x in w:
			if border[y * w + x] == 0:
				continue
			var rad := 1 + int(_noise(bandf, gw, float(x) / cell, float(y) / cell) * (reach - 0.4))
			for dy2 in range(-rad, rad + 1):
				for dx2 in range(-rad, rad + 1):
					var xx3: int = x + dx2
					var yy3: int = y + dy2
					if xx3 >= 0 and yy3 >= 0 and xx3 < w and yy3 < h and label[yy3 * w + xx3] >= 0 \
							and dx2 * dx2 + dy2 * dy2 <= rad * rad:
						shard[yy3 * w + xx3] = 1
	# Chips off the outline too, so the silhouette breaks and not only its
	# middle: a few bites along the hull's edge.
	var bites := 5 if not is_boss else 9
	for b in bites:
		for tries in 40:
			var px := rng.randi_range(0, w - 1)
			var py := rng.randi_range(0, h - 1)
			var id3 := py * w + px
			if label[id3] < 0:
				continue
			var edge := false
			for o2 in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var ex: int = px + o2.x
				var ey: int = py + o2.y
				if ex < 0 or ey < 0 or ex >= w or ey >= h or label[ey * w + ex] < 0:
					edge = true
			if not edge:
				continue
			var br := rng.randi_range(2, 4)
			for dy4 in range(-br, br + 1):
				for dx4 in range(-br, br + 1):
					var bx: int = px + dx4
					var by: int = py + dy4
					if bx >= 0 and by >= 0 and bx < w and by < h and label[by * w + bx] >= 0 \
							and dx4 * dx4 + dy4 * dy4 <= br * br:
						shard[by * w + bx] = 1
			break
	# Majors: what is left of each label. The crack is every major pixel that
	# touches shard material or another major.
	var majors: Array = []
	for i in k:
		var minx := w
		var miny := h
		var maxx := -1
		var maxy := -1
		for y in h:
			for x in w:
				var id4 := y * w + x
				if label[id4] == i and shard[id4] == 0:
					minx = mini(minx, x)
					miny = mini(miny, y)
					maxx = maxi(maxx, x)
					maxy = maxi(maxy, y)
		if maxx < 0:
			continue
		var bw := maxx - minx + 1
		var bh := maxy - miny + 1
		var im := Image.create(bw, bh, false, Image.FORMAT_RGBA8)
		var crack := PackedVector2Array()
		for y in range(miny, maxy + 1):
			for x in range(minx, maxx + 1):
				var id5 := y * w + x
				if label[id5] != i or shard[id5] != 0:
					continue
				im.set_pixel(x - minx, y - miny, _dead_pixel(img.get_pixel(r.position.x + x, r.position.y + y)))
				var on_crack := false
				for o3 in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var qx: int = x + o3.x
					var qy: int = y + o3.y
					if qx >= 0 and qy >= 0 and qx < w and qy < h:
						var q := qy * w + qx
						if (label[q] >= 0 and shard[q] == 1) or (label[q] >= 0 and label[q] != i):
							on_crack = true
				if on_crack:
					crack.append(Vector2(x - minx, y - miny))
		# Drift away from the hull's middle, a few whole pixels: enough that the
		# cracks read as gaps, little enough that the wreck is still the ship.
		var mid := Vector2((minx + maxx) * 0.5, (miny + maxy) * 0.5)
		var away := mid - Vector2(cx, cy)
		var reach_px := rng.randf_range(2.5, 5.0) * (0.8 if is_boss else 1.0)
		var off := Vector2i((away.normalized() * reach_px).round()) if away.length() > 1.0 \
			else Vector2i(0, rng.randi_range(-2, 2))
		off.y += rng.randi_range(-1, 1)
		majors.append({image = im, at = r.position + Vector2i(minx, miny), off = off, crack = crack})
	# Shards: the band cut small, by a Voronoi of seeds spaced through it.
	var spts: Array[Vector2i] = []
	for y in h:
		for x in w:
			if shard[y * w + x] == 1 and rng.randf() < 0.035:
				spts.append(Vector2i(x, y))
	if spts.is_empty():
		spts.append(Vector2i(int(cx), int(cy)))
	var groups := {}
	for y in h:
		for x in w:
			if shard[y * w + x] == 0:
				continue
			var bj := 0
			var bd := 1 << 30
			for j3 in spts.size():
				var d2 := (spts[j3] - Vector2i(x, y)).length_squared()
				if d2 < bd:
					bd = d2
					bj = j3
			if not groups.has(bj):
				groups[bj] = []
			(groups[bj] as Array).append(Vector2i(x, y))
	var shards: Array = []
	for g in groups.values():
		var arr: Array = g
		var mn := Vector2i(1 << 20, 1 << 20)
		var mx := Vector2i(-1, -1)
		for p in arr:
			mn = Vector2i(mini(mn.x, p.x), mini(mn.y, p.y))
			mx = Vector2i(maxi(mx.x, p.x), maxi(mx.y, p.y))
		var sz := mx - mn + Vector2i.ONE
		# A piece must be square to turn in quarter steps about its middle
		# without walking off its own pixels.
		var side := maxi(sz.x, sz.y)
		var im2 := Image.create(side, side, false, Image.FORMAT_RGBA8)
		var pad := (Vector2i(side, side) - sz) / 2
		for p2 in arr:
			var q2: Vector2i = p2
			im2.set_pixel(q2.x - mn.x + pad.x, q2.y - mn.y + pad.y,
				img.get_pixel(r.position.x + q2.x, r.position.y + q2.y))
		shards.append({image = im2, at = r.position + mn - pad})
	return {majors = majors, shards = shards, centre = r.position + Vector2i(int(cx), int(cy))}


## A dead ship's engines are out: the flame and the lit ports, the brightest
## warm pixels, go to the darkest ember the heat ramp has.
static func _dead_pixel(c: Color) -> Color:
	if c.a > 0.0 and c.r > 0.75 and c.r >= c.b + 0.25 and c.get_luminance() > 0.55:
		return Color(ShipBreakup.HEAT_RAMP[5].r, ShipBreakup.HEAT_RAMP[5].g, ShipBreakup.HEAT_RAMP[5].b, c.a)
	return c


static func _noise(f: PackedFloat32Array, gw: int, x: float, y: float) -> float:
	var x0 := int(x)
	var y0 := int(y)
	var fx := x - x0
	var fy := y - y0
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var a := f[y0 * gw + x0]
	var b := f[y0 * gw + x0 + 1]
	var c := f[(y0 + 1) * gw + x0]
	var d := f[(y0 + 1) * gw + x0 + 1]
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)


const SOOT := Color(0.17, 0.12, 0.10)


## Lone pixels are the canvas starfield, as in `cut`.
static func _hull_pic(img: Image, used: Rect2i, margin: int) -> Dictionary:
	var canvas := Rect2i(Vector2i.ZERO, img.get_size())
	var u := used.intersection(canvas)
	var r := u.grow(margin).intersection(canvas)
	var w := r.size.x
	var h := r.size.y
	var n := w * h
	var raw := PackedColorArray()
	raw.resize(n)
	var pre := PackedByteArray()
	pre.resize(n)
	for y in h:
		for x in w:
			var g := r.position + Vector2i(x, y)
			if not u.has_point(g):
				continue
			var c := img.get_pixel(g.x, g.y)
			raw[y * w + x] = c
			if c.a > 0.6:
				pre[y * w + x] = 1
	var mask := PackedByteArray()
	mask.resize(n)
	var col := PackedColorArray()
	col.resize(n)
	var sx := 0.0
	var sy := 0.0
	var cnt := 0
	var x0 := w
	var x1 := -1
	var y0 := h
	var y1 := -1
	for y in h:
		for x in w:
			var i := y * w + x
			if pre[i] == 0:
				continue
			var nb := 0
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					var xx: int = x + dx
					var yy: int = y + dy
					if xx >= 0 and yy >= 0 and xx < w and yy < h and pre[yy * w + xx] == 1:
						nb += 1
			if nb < 2:
				continue
			mask[i] = 1
			col[i] = _dead_pixel(raw[i])
			sx += x
			sy += y
			cnt += 1
			x0 = mini(x0, x)
			x1 = maxi(x1, x)
			y0 = mini(y0, y)
			y1 = maxi(y1, y)
	if cnt == 0:
		return {n = 0, r = r, w = w, h = h}
	return {r = r, w = w, h = h, raw = raw, col = col, mask = mask, n = cnt,
		cx = sx / cnt, cy = sy / cnt, x0 = x0, x1 = x1, y0 = y0, y1 = y1}


## The hull's ink box in the image, without the margin round it.
static func _ink_box(r: Rect2i, H: Dictionary, bw: float, bh: float) -> Rect2i:
	return Rect2i(r.position + Vector2i(int(H.x0), int(H.y0)), Vector2i(int(bw), int(bh)))


## Value noise on a coarse grid, -1..1, sampled anywhere (clamped at the edges).
static func _field(rng: RandomNumberGenerator, w: int, h: int, cell: int) -> Dictionary:
	var gw := w / cell + 3
	var gh := h / cell + 3
	var f := PackedFloat32Array()
	f.resize(gw * gh)
	for j in f.size():
		f[j] = rng.randf_range(-1.0, 1.0)
	return {f = f, gw = gw, gh = gh, cell = cell}


static func _nz(fd: Dictionary, x: float, y: float) -> float:
	var c := float(fd.cell)
	var gx := clampf(x / c, 0.0, float(fd.gw) - 1.001)
	var gy := clampf(y / c, 0.0, float(fd.gh) - 1.001)
	return _noise(fd.f, int(fd.gw), gx, gy)


static func _pic_image(H: Dictionary, col: PackedColorArray, mask: PackedByteArray) -> Image:
	var w: int = H.w
	var h: int = H.h
	var im := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			if mask[y * w + x] == 1:
				im.set_pixel(x, y, col[y * w + x])
	return im


# ---------------------------------------------------------------- deformations

## Melt: pixels fetched from further out so the hull slumps; thin parts run off as drips.
## Seeded.
## Why: docs/why/BreakupCuts.md#melt-and-crumple
static func _melt_pic(H: Dictionary, seed: int, k: float, given: Dictionary = {}) -> Dictionary:
	var w: int = H.w
	var h: int = H.h
	var src: PackedColorArray = H.col
	var smask: PackedByteArray = H.mask
	var cx: float = H.cx
	var cy: float = H.cy
	var fld: Dictionary = given if not given.is_empty() else _melt_field(H, seed)
	var ox: PackedFloat32Array = fld.ox
	var oy: PackedFloat32Array = fld.oy
	var col := PackedColorArray()
	col.resize(w * h)
	var mask := PackedByteArray()
	mask.resize(w * h)
	for y in h:
		for x in w:
			var sx := cx + (float(x) - cx) * (1.0 + 0.06 * k) + k * ox[y * w + x]
			var sy := cy + (float(y) - cy) * (1.0 + 0.3 * k) + k * oy[y * w + x]
			var ix := roundi(sx)
			var iy := roundi(sy)
			if ix < 0 or iy < 0 or ix >= w or iy >= h:
				continue
			var j := iy * w + ix
			if smask[j] == 0:
				continue
			mask[y * w + x] = 1
			col[y * w + x] = src[j]
	var passes := int(floor(k * 3.0 + 0.001))
	for p in passes:
		var gone: Array[int] = []
		for y in h:
			for x in w:
				var i := y * w + x
				if mask[i] == 0:
					continue
				var nb := 0
				if x > 0 and mask[i - 1] == 1: nb += 1
				if x < w - 1 and mask[i + 1] == 1: nb += 1
				if y > 0 and mask[i - w] == 1: nb += 1
				if y < h - 1 and mask[i + w] == 1: nb += 1
				if nb < 2:
					gone.append(i)
		for i in gone:
			mask[i] = 0
	if k >= 0.5:
		var a := 0.4 * (k - 0.4)
		var out := col.duplicate()
		for y in h:
			for x in w:
				var i := y * w + x
				if mask[i] == 0:
					continue
				var sum := col[i]
				var cnt := 1
				for o in [-1, 1, -w, w]:
					var q: int = i + o
					if q >= 0 and q < w * h and mask[q] == 1:
						sum += col[q]
						cnt += 1
				var mean := sum / float(cnt)
				var c2 := col[i].lerp(mean, a)
				c2.a = col[i].a
				out[i] = c2
		col = out
	return {col = col, mask = mask}


## MELT's wander, worked out once a hull (noise is the slow part) and kept for
## its steps: each pixel's sideways and up-down reach, the far edges most.
static var _melt_cache := {}
## Breakups and wrecks are cut on several workers at once.
static var _melt_lock := Mutex.new()

static func _melt_field(H: Dictionary, seed: int) -> Dictionary:
	var key := "%d:%d:%d:%d:%d" % [seed, int(H.w), int(H.h), int(H.n), (H.r as Rect2i).position.x]
	_melt_lock.lock()
	var had: Dictionary = _melt_cache.get(key, {})
	_melt_lock.unlock()
	if not had.is_empty():
		return had
	var w: int = H.w
	var h: int = H.h
	var cy: float = H.cy
	var hb := maxf(4.0, (float(H.y1) - float(H.y0) + 1.0) * 0.5)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 131 + 7
	var fx := _field(rng, w, h, 7)
	var fy := _field(rng, w, h, 7)
	var ox := PackedFloat32Array()
	ox.resize(w * h)
	var oy := PackedFloat32Array()
	oy.resize(w * h)
	for y in h:
		var reach := 0.6 + absf(float(y) - cy) / hb
		for x in w:
			ox[y * w + x] = 4.0 * reach * _nz(fx, x, y)
			oy[y * w + x] = 3.0 * reach * _nz(fy, x, y)
	var made := {ox = ox, oy = oy}
	_melt_lock.lock()
	if _melt_cache.size() > 16:
		_melt_cache.clear()
	_melt_cache[key] = made
	_melt_lock.unlock()
	return made


static func _fold_x(fx: float, tilt: float, jag: Dictionary, i: int, y: float, cy: float) -> float:
	return fx + tilt * (y - cy) + 1.5 * _nz(jag, float(i) * 13.0, y)


## Crumple: fold lines shove segments toward the middle, stair-stepped like bent metal.
## Why: docs/why/BreakupCuts.md#melt-and-crumple
static func _crumple_pic(H: Dictionary, seed: int, k: float) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 173 + 11
	var w: int = H.w
	var h: int = H.h
	var src: PackedColorArray = H.col
	var smask: PackedByteArray = H.mask
	var cx: float = H.cx
	var cy: float = H.cy
	var bw := float(int(H.x1) - int(H.x0) + 1)
	var nf := 3 if bw >= 90.0 else 2
	var fxs: Array[float] = []
	var tilts: Array[float] = []
	for i in nf:
		fxs.append(float(H.x0) + bw * ((float(i) + 1.0) / float(nf + 1) + rng.randf_range(-0.05, 0.05)))
		tilts.append(rng.randf_range(-0.3, 0.3))
	var jag := _field(rng, w, h, 4)
	# each fold's x on each row, once (the noise is the slow part)
	var fl := PackedFloat32Array()
	fl.resize(nf * h)
	for f in nf:
		for y in h:
			fl[f * h + y] = _fold_x(fxs[f], tilts[f], jag, f, y, cy)
	var segl := PackedInt32Array()
	segl.resize(w * h)
	segl.fill(-1)
	var sums := PackedFloat32Array()
	sums.resize(nf + 1)
	var cnts := PackedInt32Array()
	cnts.resize(nf + 1)
	for y in h:
		for x in w:
			var i := y * w + x
			if smask[i] == 0:
				continue
			var j := 0
			for f in nf:
				if float(x) > fl[f * h + y]:
					j = f + 1
			segl[i] = j
			sums[j] += x
			cnts[j] += 1
	var segcx := PackedFloat32Array()
	segcx.resize(nf + 1)
	for j in nf + 1:
		segcx[j] = sums[j] / float(cnts[j]) if cnts[j] > 0 else cx
	var col := PackedColorArray()
	col.resize(w * h)
	var mask := PackedByteArray()
	mask.resize(w * h)
	var seg := PackedInt32Array()
	seg.resize(w * h)
	seg.fill(-1)
	for j in nf + 1:
		var sgn := 1.0 if j % 2 == 0 else -1.0
		var dx := roundi(-(segcx[j] - cx) * 0.24 * k)
		for y in h:
			for x in w:
				var i := y * w + x
				if segl[i] != j:
					continue
				var dy := roundi(sgn * 3.0 * k + sgn * 0.14 * k * (float(x) - segcx[j]))
				var tx: int = x + dx
				var ty: int = y + dy
				if tx < 0 or ty < 0 or tx >= w or ty >= h:
					continue
				var dl := 999.0
				var dr := 999.0
				if j > 0:
					dl = float(x) - fl[(j - 1) * h + y]
				if j < nf:
					dr = fl[j * h + y] - float(x)
				var near := minf(dl, dr)
				var shade := 1.0
				if near <= 1.5:
					shade = (1.0 - 0.55 * k) if ((dl < dr) == (j % 2 == 0)) else (1.0 + 0.35 * k)
				elif near <= 3.0:
					shade = 1.0 - 0.2 * k
				if k >= 0.5 and absf(float(x) - segcx[j]) < 0.75:
					shade *= 1.0 - 0.25 * k
				var c := src[i]
				var ti := ty * w + tx
				col[ti] = Color(minf(1.0, c.r * shade), minf(1.0, c.g * shade), minf(1.0, c.b * shade), c.a)
				mask[ti] = 1
				seg[ti] = j
	var folds: Array = []
	var r: Rect2i = H.r
	for f in nf:
		folds.append(Vector2(r.position) + Vector2(fxs[f] - (fxs[f] - cx) * 0.24, cy))
	return {col = col, mask = mask, seg = seg, folds = folds, nf = nf}


# ---------------------------------------------------------------- partitions

static func _lab_voronoi(H: Dictionary, mask: PackedByteArray, k: int, rng: RandomNumberGenerator) -> PackedInt32Array:
	var w: int = H.w
	var h: int = H.h
	var bw := float(int(H.x1) - int(H.x0) + 1)
	var bh := float(int(H.y1) - int(H.y0) + 1)
	var seeds: Array[Vector2] = []
	for i in k:
		seeds.append(Vector2(float(H.x0) + ((float(i) + 0.5) / float(k) + rng.randf_range(-0.1, 0.1)) * bw,
			float(H.cy) + rng.randf_range(-0.25, 0.25) * bh))
	var fields: Array = []
	for i in k:
		fields.append(_field(rng, w, h, 5))
	var amp := 0.11 * bw / float(k)
	var lab := PackedInt32Array()
	lab.resize(w * h)
	for y in h:
		for x in w:
			var idx := y * w + x
			if mask[idx] == 0:
				lab[idx] = -1
				continue
			var best := 1e9
			var bi := 0
			for i in k:
				var d := Vector2(x, y).distance_to(seeds[i]) + amp * _nz(fields[i], x, y)
				if d < best:
					best = d
					bi = i
			lab[idx] = bi
	return lab


## Wedges round the middle, measured in the hull's own proportions so a long
## hull still gets wedges across it, their borders wandering.
static func _lab_radial(H: Dictionary, mask: PackedByteArray, k: int, rng: RandomNumberGenerator) -> PackedInt32Array:
	var w: int = H.w
	var h: int = H.h
	var cx: float = H.cx
	var cy: float = H.cy
	var bw := float(int(H.x1) - int(H.x0) + 1)
	var bh := float(int(H.y1) - int(H.y0) + 1)
	var rot := rng.randf() * TAU
	var fd := _field(rng, w, h, 6)
	var lab := PackedInt32Array()
	lab.resize(w * h)
	for y in h:
		for x in w:
			var idx := y * w + x
			if mask[idx] == 0:
				lab[idx] = -1
				continue
			var a := atan2((float(y) - cy) / bh, (float(x) - cx) / bw) + 0.5 * _nz(fd, x, y) + rot
			lab[idx] = clampi(int(fposmod(a, TAU) / (TAU / float(k))), 0, k - 1)
	return lab


## Shard material along every border between two pieces, a jagged 1..reach wide.
static func _mark_band(H: Dictionary, lab: PackedInt32Array, sm: PackedByteArray, reach: int,
		rng: RandomNumberGenerator) -> void:
	var w: int = H.w
	var h: int = H.h
	var border := PackedByteArray()
	border.resize(w * h)
	for y in h:
		for x in w:
			var idx := y * w + x
			if lab[idx] < 0:
				continue
			for o in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, 1)]:
				var xx: int = x + o.x
				var yy: int = y + o.y
				if xx >= 0 and yy >= 0 and xx < w and yy < h:
					var l2 := lab[yy * w + xx]
					if l2 >= 0 and l2 != lab[idx]:
						border[idx] = 1
						border[yy * w + xx] = 1
	var bandf := _field(rng, w, h, 5)
	for y in h:
		for x in w:
			if border[y * w + x] == 0:
				continue
			var rad := 1 + int((0.5 + 0.5 * _nz(bandf, x, y)) * (float(reach) - 0.4))
			for dy in range(-rad, rad + 1):
				for dx in range(-rad, rad + 1):
					var xx: int = x + dx
					var yy: int = y + dy
					if xx >= 0 and yy >= 0 and xx < w and yy < h and dx * dx + dy * dy <= rad * rad:
						var q := yy * w + xx
						if lab[q] >= 0 and sm[q] == 0:
							sm[q] = 1


## Bites off the outline, so the silhouette breaks and not only its middle.
static func _mark_bites(H: Dictionary, lab: PackedInt32Array, sm: PackedByteArray, count: int,
		rng: RandomNumberGenerator, mark: int) -> void:
	var w: int = H.w
	var h: int = H.h
	for b in count:
		for tries in 40:
			var px := rng.randi_range(0, w - 1)
			var py := rng.randi_range(0, h - 1)
			if lab[py * w + px] < 0:
				continue
			var edge := false
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var ex: int = px + o.x
				var ey: int = py + o.y
				if ex < 0 or ey < 0 or ex >= w or ey >= h or lab[ey * w + ex] < 0:
					edge = true
			if not edge:
				continue
			var br := rng.randi_range(2, 4)
			for dy in range(-br, br + 1):
				for dx in range(-br, br + 1):
					var bx: int = px + dx
					var by: int = py + dy
					if bx >= 0 and by >= 0 and bx < w and by < h and dx * dx + dy * dy <= br * br:
						var q := by * w + bx
						if lab[q] >= 0 and sm[q] == 0:
							sm[q] = mark
			break


## A ragged disc of shard material, tagged `mark` (a blast's hole, a reactor's).
static func _mark_disc(H: Dictionary, lab: PackedInt32Array, sm: PackedByteArray, p: Vector2,
		rad: float, fd: Dictionary, mark: int) -> void:
	var w: int = H.w
	var h: int = H.h
	for y in range(int(p.y - rad) - 3, int(p.y + rad) + 4):
		for x in range(int(p.x - rad) - 3, int(p.x + rad) + 4):
			if x < 0 or y < 0 or x >= w or y >= h:
				continue
			var q := y * w + x
			if lab[q] < 0 or sm[q] != 0:
				continue
			if Vector2(x, y).distance_to(p) <= rad + 1.2 * _nz(fd, x, y):
				sm[q] = mark


static func _nearest_hull(H: Dictionary, mask: PackedByteArray, tgt: Vector2) -> Vector2i:
	var w: int = H.w
	var h: int = H.h
	var best := 1e12
	var bp := Vector2i(int(H.cx), int(H.cy))
	for y in h:
		for x in w:
			if mask[y * w + x] == 0:
				continue
			var d := Vector2(x, y).distance_squared_to(tgt)
			if d < best:
				best = d
				bp = Vector2i(x, y)
	return bp


## The hull's top or bottom edge in column `x` (or the nearest column with hull).
static func _edge_point(H: Dictionary, mask: PackedByteArray, x: int, top: bool) -> Vector2i:
	var w: int = H.w
	var h: int = H.h
	for off in [0, 1, -1, 2, -2, 3, -3, 4, -4, 6, -6, 8, -8]:
		var xx: int = clampi(x + int(off), 0, w - 1)
		var ys := range(h) if top else range(h - 1, -1, -1)
		for y in ys:
			if mask[int(y) * w + xx] == 1:
				return Vector2i(xx, int(y))
	return Vector2i(int(H.cx), int(H.cy))


## Outward from the hull at `p`: away from the mean of the hull round it.
static func _normal_at(H: Dictionary, mask: PackedByteArray, p: Vector2i) -> Vector2:
	var w: int = H.w
	var h: int = H.h
	var s := Vector2.ZERO
	var n := 0
	for dy in range(-5, 6):
		for dx in range(-5, 6):
			var x: int = p.x + dx
			var y: int = p.y + dy
			if x >= 0 and y >= 0 and x < w and y < h and mask[y * w + x] == 1 and dx * dx + dy * dy <= 25:
				s += Vector2(x, y)
				n += 1
	if n == 0:
		return Vector2.UP
	var v := Vector2(p) - s / float(n)
	return v.normalized() if v.length() > 0.2 else Vector2.UP


## Enemies face left, so the stern is the right: engines are row ends there plus lit pixels
## in the back half.
static func _engines(H: Dictionary) -> PackedVector2Array:
	var w: int = H.w
	var h: int = H.h
	var mask: PackedByteArray = H.mask
	var raw: PackedColorArray = H.raw
	var r: Rect2i = H.r
	var x1: int = H.x1
	var out := PackedVector2Array()
	for y in h:
		var xr := -1
		for x in w:
			if mask[y * w + x] == 1:
				xr = x
		if xr >= x1 - 5:
			out.append(Vector2(r.position) + Vector2(xr + 1, y))
	for y in h:
		for x in w:
			if mask[y * w + x] == 0 or float(x) < float(H.cx):
				continue
			var c := raw[y * w + x]
			if c.r > 0.75 and c.r >= c.b + 0.25 and c.get_luminance() > 0.55:
				out.append(Vector2(r.position) + Vector2(x, y))
	return out


# ---------------------------------------------------------------- pieces

static func _majors_of(H: Dictionary, col: PackedColorArray, lab: PackedInt32Array, sm: PackedByteArray,
		k: int) -> Array:
	var w: int = H.w
	var h: int = H.h
	var r: Rect2i = H.r
	var out: Array = []
	for i in k:
		var minx := w
		var miny := h
		var maxx := -1
		var maxy := -1
		for y in h:
			for x in w:
				var id := y * w + x
				if lab[id] == i and sm[id] == 0:
					minx = mini(minx, x)
					miny = mini(miny, y)
					maxx = maxi(maxx, x)
					maxy = maxi(maxy, y)
		if maxx < 0:
			continue
		var im := Image.create(maxx - minx + 1, maxy - miny + 1, false, Image.FORMAT_RGBA8)
		var crack := PackedVector2Array()
		for y in range(miny, maxy + 1):
			for x in range(minx, maxx + 1):
				var id2 := y * w + x
				if lab[id2] != i or sm[id2] != 0:
					continue
				im.set_pixel(x - minx, y - miny, col[id2])
				var on_crack := false
				for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var qx: int = x + o.x
					var qy: int = y + o.y
					if qx >= 0 and qy >= 0 and qx < w and qy < h:
						var q := qy * w + qx
						if lab[q] >= 0 and (sm[q] != 0 or lab[q] != i):
							on_crack = true
				if on_crack:
					crack.append(Vector2(x - minx, y - miny))
		out.append({image = im, at = r.position + Vector2i(minx, miny), crack = crack, lab = i,
			mid = Vector2(r.position) + Vector2((minx + maxx) * 0.5, (miny + maxy) * 0.5)})
	return out


## Square shards so a quarter turn keeps every pixel; each mark kind leaves as its own
## shards.
static func _shards_of(H: Dictionary, col: PackedColorArray, lab: PackedInt32Array, sm: PackedByteArray,
		rng: RandomNumberGenerator, per: int = 26, density: float = 0.035) -> Array:
	var w: int = H.w
	var h: int = H.h
	var r: Rect2i = H.r
	var by := {}
	for y in h:
		for x in w:
			var i := y * w + x
			var m := int(sm[i])
			if m == 0 or m == 200 or lab[i] < 0:
				continue
			if not by.has(m):
				by[m] = []
			(by[m] as Array).append(Vector2i(x, y))
	var shards: Array = []
	var keys := by.keys()
	keys.sort()
	for mk in keys:
		var pts: Array = by[mk]
		var seeds: Array[Vector2i] = []
		for p in pts:
			if rng.randf() < density:
				seeds.append(p)
		var want := maxi(1, pts.size() / per)
		while seeds.size() < want:
			seeds.append(pts[rng.randi() % pts.size()])
		var groups := {}
		for p in pts:
			var pv: Vector2i = p
			var bj := 0
			var bd := 1 << 30
			for j in seeds.size():
				var d2 := (seeds[j] - pv).length_squared()
				if d2 < bd:
					bd = d2
					bj = j
			if not groups.has(bj):
				groups[bj] = []
			(groups[bj] as Array).append(pv)
		for g in groups.values():
			var arr: Array = g
			var mn := Vector2i(1 << 20, 1 << 20)
			var mx := Vector2i(-1, -1)
			for p2 in arr:
				var q: Vector2i = p2
				mn = Vector2i(mini(mn.x, q.x), mini(mn.y, q.y))
				mx = Vector2i(maxi(mx.x, q.x), maxi(mx.y, q.y))
			var sz := mx - mn + Vector2i.ONE
			var side := maxi(sz.x, sz.y)
			var im := Image.create(side, side, false, Image.FORMAT_RGBA8)
			var pad := (Vector2i(side, side) - sz) / 2
			for p3 in arr:
				var q2: Vector2i = p3
				im.set_pixel(q2.x - mn.x + pad.x, q2.y - mn.y + pad.y, col[q2.y * w + q2.x])
			shards.append({image = im, at = r.position + mn - pad, mark = int(mk)})
	return shards


# ---------------------------------------------------------------- what the metal keeps

## Soot round a blast: darker toward its middle in held steps, the outer two
## dithered, pulled a little toward a warm black. Darkening, so no light rules.
static func _scorched(im: Image, at: Vector2i, c: Vector2, rad: float) -> Image:
	var out: Image = im.duplicate()
	for y in out.get_height():
		for x in out.get_width():
			var p := out.get_pixel(x, y)
			if p.a <= 0.0:
				continue
			var d := (Vector2(at + Vector2i(x, y)) - c).length() / rad
			if d >= 1.0:
				continue
			var odd := ((x + at.x + y + at.y) & 1) == 0
			var k := 1.0
			if d < 0.45:
				k = 0.36
			elif d < 0.7:
				k = 0.52
			elif d < 0.88:
				k = 0.68 if odd else 0.84
			else:
				k = 0.82 if odd else 1.0
			var q := Color(p.r * k, p.g * k, p.b * k).lerp(SOOT, (1.0 - k) * 0.35)
			out.set_pixel(x, y, Color(q.r, q.g, q.b, p.a))
	return out


## Cooled slag: the metal's light and dark kept, its colour gone to a warm dark
## grey, darkest at the edges.
static func _slagged(im: Image, amt: float) -> Image:
	var out: Image = im.duplicate()
	var w := im.get_width()
	var h := im.get_height()
	for y in h:
		for x in w:
			var p := im.get_pixel(x, y)
			if p.a <= 0.0:
				continue
			var edge := false
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var ex: int = x + o.x
				var ey: int = y + o.y
				if ex < 0 or ey < 0 or ex >= w or ey >= h or im.get_pixel(ex, ey).a <= 0.0:
					edge = true
			# kept light enough that the wreck still reads once the slot greys it
			var l := p.get_luminance()
			var tgt := Color(0.62, 0.55, 0.5) * (0.6 + l * 0.6)
			if edge:
				tgt = tgt * 0.75
			var q := p.lerp(tgt, amt)
			out.set_pixel(x, y, Color(q.r, q.g, q.b, p.a))
	return out


## The edge a disintegration stopped at, burnt dark.
static func _charred(im: Image, at: Vector2i, H: Dictionary, thr: PackedFloat32Array) -> Image:
	var out: Image = im.duplicate()
	var r: Rect2i = H.r
	var w: int = H.w
	for y in out.get_height():
		for x in out.get_width():
			var p := out.get_pixel(x, y)
			if p.a <= 0.0:
				continue
			var lp := at - r.position + Vector2i(x, y)
			var tv := thr[lp.y * w + lp.x]
			var k := 1.0
			if tv > ShipBreakup.DIS_END - 0.05:
				k = 0.45
			elif tv > ShipBreakup.DIS_END - 0.1 and ((lp.x + lp.y) & 1) == 0:
				k = 0.72
			if k < 1.0:
				var q := Color(p.r * k, p.g * k, p.b * k).lerp(SOOT, (1.0 - k) * 0.3)
				out.set_pixel(x, y, Color(q.r, q.g, q.b, p.a))
	return out


## Brightest at the edges as thin metal heats first, falling inward over three dithered
## steps.
static func _heat_light(mask: PackedByteArray, w: int, h: int, pad: int) -> Image:
	var W := w + pad * 2
	var Hh := h + pad * 2
	var dist := PackedInt32Array()
	dist.resize(W * Hh)
	dist.fill(99)
	var q: Array[Vector2i] = []
	for y in Hh:
		for x in W:
			var lx := x - pad
			var ly := y - pad
			var inside := lx >= 0 and ly >= 0 and lx < w and ly < h and mask[ly * w + lx] == 1
			if not inside:
				dist[y * W + x] = 0
				q.append(Vector2i(x, y))
	var head := 0
	while head < q.size():
		var cur := q[head]
		head += 1
		var d := dist[cur.y * W + cur.x]
		if d >= 5:
			continue
		for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = cur.x + o.x
			var ny: int = cur.y + o.y
			if nx >= 0 and ny >= 0 and nx < W and ny < Hh and dist[ny * W + nx] > d + 1:
				dist[ny * W + nx] = d + 1
				q.append(Vector2i(nx, ny))
	var im := Image.create(W, Hh, false, Image.FORMAT_RGBA8)
	for y in Hh:
		for x in W:
			var d2 := dist[y * W + x]
			var odd := ((x + y) & 1) == 0
			var lv := 0.0
			if d2 == 0:
				# outside: one dithered pixel of spill round the edge
				var near := false
				for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx2: int = x + o.x
					var ny2: int = y + o.y
					if nx2 >= 0 and ny2 >= 0 and nx2 < W and ny2 < Hh and dist[ny2 * W + nx2] == 1:
						near = true
				lv = 0.3 if near and odd else 0.0
			elif d2 == 1:
				lv = 0.9
			elif d2 == 2:
				lv = 0.62
			elif d2 == 3:
				lv = 0.42
			else:
				lv = 0.3 if odd else 0.2
			if lv > 0.0:
				im.set_pixel(x, y, Color(lv, lv, lv, 1.0))
	return im


static func _alpha_mask(im: Image) -> PackedByteArray:
	var m := PackedByteArray()
	m.resize(im.get_width() * im.get_height())
	for y in im.get_height():
		for x in im.get_width():
			if im.get_pixel(x, y).a > 0.0:
				m[y * im.get_width() + x] = 1
	return m


# ---------------------------------------------------------------- the cut, per style

static func _cut_new(img: Image, used: Rect2i, seed: int, is_boss: bool, st: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 7349 + st * 101 + 3
	var H := _hull_pic(img, used, ShipBreakup.HULL_PAD)
	var r: Rect2i = H.r
	if int(H.n) == 0:
		return {majors = [], shards = [], centre = r.get_center(), plan = {r = r, glob = Vector2i.ZERO, box = r}}
	var w: int = H.w
	var h: int = H.h
	var cx: float = H.cx
	var cy: float = H.cy
	var bw := float(int(H.x1) - int(H.x0) + 1)
	var bh := float(int(H.y1) - int(H.y0) + 1)
	var col: PackedColorArray = H.col
	var mask: PackedByteArray = H.mask
	var rp := Vector2(r.position)
	var c_loc := Vector2(cx, cy)
	var plan := {r = r, glob = Vector2i.ZERO,
		box = _ink_box(r, H, bw, bh)}
	var seg := PackedInt32Array()
	if st == ShipBreakup.Style.MELT:
		var mp := _melt_pic(H, seed, 1.0)
		col = mp.col
		mask = mp.mask
	elif st == ShipBreakup.Style.CRUMPLE:
		var cp := _crumple_pic(H, seed, 1.0)
		col = cp.col
		mask = cp.mask
		seg = cp.seg
		plan.folds = cp.folds
	var n := w * h
	var sm := PackedByteArray()
	sm.resize(n)
	var lab := PackedInt32Array()
	var k := 3
	if bw < 70.0:
		k = 2
	var thr := PackedFloat32Array()
	match st:
		ShipBreakup.Style.BREACH, ShipBreakup.Style.COLLAPSE:
			k = 6 if is_boss else 5
			lab = _lab_radial(H, mask, k, rng)
			var rh := clampf(minf(bw, bh) * 0.17, 4.0, 10.0)
			_mark_disc(H, lab, sm, c_loc, rh, _field(rng, w, h, 3), 99)
			_mark_band(H, lab, sm, 2, rng)
			if st == ShipBreakup.Style.BREACH:
				_mark_bites(H, lab, sm, 4, rng, 1)
			plan.hole = rh
		ShipBreakup.Style.CHAIN:
			lab = _lab_voronoi(H, mask, k, rng)
			var blasts: Array = []
			var bf := _field(rng, w, h, 3)
			var fr := [0.88, 0.72, 0.57, 0.43, 0.31]
			for i in fr.size():
				var alt := (0.22 if i % 2 == 0 else -0.2) * bh
				var p := _nearest_hull(H, mask, Vector2(float(H.x0) + float(fr[i]) * bw, cy + alt))
				_mark_disc(H, lab, sm, Vector2(p), 4.0 if is_boss else 3.0, bf, 2 + i)
				blasts.append(rp + Vector2(p))
			plan.blasts = blasts
			_mark_band(H, lab, sm, 2, rng)
			_mark_bites(H, lab, sm, 2, rng, 1)
		ShipBreakup.Style.OVERLOAD:
			lab = _lab_voronoi(H, mask, k, rng)
			_mark_band(H, lab, sm, 2, rng)
			_mark_bites(H, lab, sm, 3, rng, 1)
			var eng := _engines(H)
			plan.engine = eng
			var sp := Vector2.ZERO
			for e in eng:
				sp += e
			plan.stern = sp / float(eng.size()) if eng.size() > 0 else rp + Vector2(float(H.x1), cy)
			plan.glob = Vector2i(-5, 0)
		ShipBreakup.Style.VENT:
			k = 2
			lab = _lab_voronoi(H, mask, 2, rng)
			var sgn := 1 if rng.randf() < 0.5 else -1
			var jets: Array = []
			var jf := _field(rng, w, h, 3)
			for i in 2:
				var fx := 0.22 if i == 0 else 0.76
				var top := (sgn == -1) if i == 0 else (sgn == 1)
				var p := _edge_point(H, mask, int(float(H.x0) + fx * bw), top)
				var nrm := _normal_at(H, mask, p)
				var jl := lab[p.y * w + p.x]
				_mark_disc(H, lab, sm, Vector2(p), 3.0, jf, 2 + i)
				jets.append({p = rp + Vector2(p), n = nrm, lab = jl, t = 0.0 if i == 0 else 0.15,
					len = 0.95 if i == 0 else 0.85})
			plan.jets = jets
			plan.sgn = sgn
			_mark_band(H, lab, sm, 1, rng)
		ShipBreakup.Style.SLICE:
			k = 2
			var th := rng.randf_range(0.12, 0.3) * (1.0 if rng.randf() < 0.5 else -1.0)
			var d := Vector2(sin(th), cos(th))
			var nn := Vector2(cos(th), -sin(th))
			var c := Vector2(cx + rng.randf_range(-0.06, 0.06) * bw, cy)
			lab.resize(n)
			var kp := PackedVector2Array()
			var kc := PackedColorArray()
			var ku := PackedFloat32Array()
			var u0 := 1e9
			var u1 := -1e9
			for y in h:
				for x in w:
					var i := y * w + x
					if mask[i] == 0:
						lab[i] = -1
						continue
					var s := (Vector2(x, y) - c).dot(nn)
					lab[i] = 0 if s < 0.0 else 1
					if absf(s) < 0.5:
						sm[i] = 200
						var u := (Vector2(x, y) - c).dot(d)
						kp.append(rp + Vector2(x, y))
						kc.append(col[i])
						ku.append(u)
						u0 = minf(u0, u)
						u1 = maxf(u1, u)
			plan.slice = {c = rp + c, d = d, n = nn, kp = kp, kc = kc, ku = ku, u0 = u0, u1 = u1}
		ShipBreakup.Style.DISSOLVE:
			k = 1
			lab.resize(n)
			thr.resize(n)
			var fd := _field(rng, w, h, 4)
			var dp := PackedVector2Array()
			var dc := PackedColorArray()
			var dt := PackedFloat32Array()
			var ep := PackedVector2Array()
			var et := PackedFloat32Array()
			for y in h:
				for x in w:
					var i := y * w + x
					if mask[i] == 0:
						lab[i] = -1
						continue
					var tv := (float(x) - float(H.x0)) / bw + 0.1 * _nz(fd, x, y) + rng.randf_range(-0.03, 0.03)
					thr[i] = tv
					if tv > ShipBreakup.DIS_END:
						lab[i] = -1
						dp.append(rp + Vector2(x, y))
						dc.append(col[i])
						dt.append(tv)
					else:
						lab[i] = 0
						if tv > ShipBreakup.DIS_END - 0.08:
							ep.append(rp + Vector2(x, y))
							et.append(tv)
			plan.dis = {p = dp, c = dc, thr = dt}
			plan.edge = {p = ep, thr = et}
		ShipBreakup.Style.SHIELD:
			lab = _lab_voronoi(H, mask, k, rng)
			_mark_band(H, lab, sm, 2, rng)
			_mark_bites(H, lab, sm, 4, rng, 1)
		ShipBreakup.Style.MELT:
			k = 2
			lab = _lab_voronoi(H, mask, 2, rng)
			_mark_band(H, lab, sm, 1, rng)
		ShipBreakup.Style.CRUMPLE:
			k = int(plan.folds.size()) + 1
			lab = seg
			_mark_band(H, lab, sm, 1, rng)
			_mark_bites(H, lab, sm, 2, rng, 1)
	var mj := _majors_of(H, col, lab, sm, k)
	var centre_c := rp + c_loc
	var stern_i := -1
	var bow_i := -1
	for i in mj.size():
		if stern_i < 0 or (mj[i].mid as Vector2).x > (mj[stern_i].mid as Vector2).x:
			stern_i = i
		if bow_i < 0 or (mj[i].mid as Vector2).x < (mj[bow_i].mid as Vector2).x:
			bow_i = i
	for i in mj.size():
		var m: Dictionary = mj[i]
		var away: Vector2 = (m.mid as Vector2) - centre_c
		var dir := away.normalized() if away.length() > 1.0 else Vector2(0, 1 if rng.randf() < 0.5 else -1)
		var own := Vector2i.ZERO
		var stages: Array = [m.image]
		match st:
			ShipBreakup.Style.BREACH:
				own = Vector2i((dir * rng.randf_range(6.0, 9.0)).round())
				stages.append(_scorched(m.image, m.at, centre_c, float(plan.hole) + 9.0))
			ShipBreakup.Style.CHAIN:
				own = Vector2i((dir * rng.randf_range(3.0, 5.5)).round()) + Vector2i(0, rng.randi_range(-1, 1))
				for b in plan.blasts:
					stages.append(_scorched(stages.back(), m.at, b, 7.0))
			ShipBreakup.Style.OVERLOAD:
				if i == stern_i:
					own = Vector2i(rng.randi_range(9, 12), rng.randi_range(1, 3) * (1 if rng.randf() < 0.5 else -1))
				else:
					own = Vector2i((dir * rng.randf_range(2.0, 3.5)).round()) + Vector2i(-2, 0)
				stages.append(_scorched(m.image, m.at, plan.stern, 13.0))
			ShipBreakup.Style.VENT:
				var sg: int = plan.sgn
				if mj.size() > 1:
					own = Vector2i(-3, -6 * sg) if i == bow_i else Vector2i(3, 6 * sg)
			ShipBreakup.Style.SLICE:
				var sl: Dictionary = plan.slice
				var sd: Vector2 = sl.d
				var sn: Vector2 = sl.n
				own = Vector2i((-sn * 3.0 + sd).round()) if int(m.lab) == 0 else Vector2i((sn * 3.0 - sd).round())
			ShipBreakup.Style.COLLAPSE:
				own = Vector2i((dir * 2.0).round())
			ShipBreakup.Style.SHIELD:
				own = Vector2i((dir * rng.randf_range(3.0, 5.5)).round()) + Vector2i(0, rng.randi_range(-1, 1))
			ShipBreakup.Style.MELT:
				own = Vector2i((dir * rng.randf_range(2.0, 3.0)).round())
				stages.append(_slagged(m.image, 0.3))
				stages.append(_slagged(m.image, 0.6))
			ShipBreakup.Style.CRUMPLE:
				own = Vector2i(roundi(signf(away.x) * rng.randf_range(2.0, 4.0)), rng.randi_range(-1, 1))
			ShipBreakup.Style.DISSOLVE:
				stages.append(_charred(m.image, m.at, H, thr))
		m.own = own
		m.glob = plan.glob
		m.off = (plan.glob as Vector2i) + own
		m.dir = dir
		m.stages = stages
		m.image = stages.back()
	if st == ShipBreakup.Style.VENT:
		for j in plan.jets:
			j.major = 0
			for i in mj.size():
				if int(mj[i].lab) == int(j.lab):
					j.major = i
	var sh := _shards_of(H, col, lab, sm, rng)
	return {majors = mj, shards = sh, centre = r.position + Vector2i(int(cx), int(cy)), plan = plan}


static func _is_glow(c: Color) -> bool:
	return c.a > 0.6 and c.s > 0.45 and c.v > 0.55 and (c.h < 0.17 or c.h > 0.93)


## Columns lifted by whole pixels so head and tail bend into a slow C without shimmer.
static func _curl_dy(x: float, cu: Dictionary, k: float) -> int:
	var u := clampf((x - float(cu.xm)) / float(cu.half), -1.2, 1.2)
	return roundi(-float(cu.a) * k * u * u)


static func _curl_pic(H: Dictionary, col: PackedColorArray, mask: PackedByteArray, cu: Dictionary,
		k: float) -> Dictionary:
	var w: int = H.w
	var h: int = H.h
	var c2 := PackedColorArray()
	c2.resize(w * h)
	var m2 := PackedByteArray()
	m2.resize(w * h)
	for x in w:
		var dy := _curl_dy(x, cu, k)
		for y in h:
			var i := y * w + x
			if mask[i] == 0:
				continue
			var ty: int = y + dy
			if ty < 0 or ty >= h:
				continue
			c2[ty * w + x] = col[i]
			m2[ty * w + x] = 1
	return {col = c2, mask = m2}


static func _cut_creature(img: Image, used: Rect2i, seed: int, st: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 911 + st
	var H := _hull_pic(img, used, 12)
	var r: Rect2i = H.r
	if int(H.n) == 0:
		return {majors = [], shards = [], centre = r.get_center(), plan = {r = r, glob = Vector2i.ZERO, box = r}}
	var w: int = H.w
	var h: int = H.h
	var n := w * h
	var cx: float = H.cx
	var cy: float = H.cy
	var bw := float(int(H.x1) - int(H.x0) + 1)
	var bh := float(int(H.y1) - int(H.y0) + 1)
	var raw: PackedColorArray = H.raw
	var mask: PackedByteArray = H.mask
	var rp := Vector2(r.position)
	var col := PackedColorArray()
	col.resize(n)
	var gmask := PackedByteArray()
	gmask.resize(n)
	for i in n:
		if mask[i] == 0:
			continue
		var c := raw[i]
		if _is_glow(c):
			gmask[i] = 1
			col[i] = Color(c.r * 0.3, c.g * 0.3, c.b * 0.3, c.a)
		else:
			col[i] = c
	var plan := {r = r, glob = Vector2i.ZERO, creature = true,
		box = _ink_box(r, H, bw, bh)}
	var lab := PackedInt32Array()
	lab.resize(n)
	var sm := PackedByteArray()
	sm.resize(n)
	var k := 1
	var nb := 4 if st == ShipBreakup.Style.GLOWOUT else 3
	var body_col := col
	var body_mask := mask
	match st:
		ShipBreakup.Style.GLOWOUT:
			var cu := {a = clampf(0.1 * bw, 6.0, 20.0), xm = cx, half = bw * 0.5}
			plan.curl = cu
			var cp := _curl_pic(H, col, mask, cu, 1.0)
			body_col = cp.col
			body_mask = cp.mask
			plan.glob = Vector2i(3, -2)
		ShipBreakup.Style.BLOOM:
			plan.glob = Vector2i(-2, 1)
		ShipBreakup.Style.PART:
			k = 4 if bw >= 160.0 else 3
			nb = k
			var fxs: Array[float] = []
			var tilts: Array[float] = []
			for i in k - 1:
				fxs.append(float(H.x0) + bw * ((float(i) + 1.0) / float(k) + rng.randf_range(-0.04, 0.04)))
				tilts.append(rng.randf_range(-0.25, 0.25))
			var jag := _field(rng, w, h, 5)
			var sp := PackedVector2Array()
			var sc := PackedColorArray()
			var si := PackedInt32Array()
			for y in h:
				for x in w:
					var i := y * w + x
					if mask[i] == 0:
						continue
					var j := 0
					var near := 99.0
					var ni := 0
					for f in k - 1:
						var fx := _fold_x(fxs[f], tilts[f], jag, f, y, cy)
						if float(x) > fx:
							j = f + 1
						if absf(float(x) - fx) < near:
							near = absf(float(x) - fx)
							ni = f
					lab[i] = j
					if near < 1.0:
						sm[i] = 200
						sp.append(rp + Vector2(x, y))
						sc.append(col[i])
						si.append(ni)
			plan.seams = {p = sp, c = sc, i = si}
	if st != ShipBreakup.Style.PART:
		for i in n:
			lab[i] = 0 if body_mask[i] == 1 else -1
	else:
		for i in n:
			if mask[i] == 0:
				lab[i] = -1
	var mj := _majors_of(H, body_col, lab, sm, k)
	var centre_c := rp + Vector2(cx, cy)
	for m in mj:
		var away: Vector2 = (m.mid as Vector2) - centre_c
		m.dir = away.normalized() if away.length() > 1.0 else Vector2.UP
		var own := Vector2i.ZERO
		if st == ShipBreakup.Style.PART:
			var j2: int = m.lab
			var sx := 0.0
			for i in k - 1:
				sx += 2.5 if i < j2 else -2.5
			own = Vector2i(Vector2(sx, 2.0 if j2 % 2 == 0 else -2.0).round())
		m.own = own
		m.glob = plan.glob
		m.off = (plan.glob as Vector2i) + own
		m.stages = [m.image]
	# The lights, by band: four along the body for GLOW OUT (out head first),
	# three for BLOOM, one per segment for PART. Not in a seam (that is fluid).
	var gp := PackedVector2Array()
	var gc := PackedColorArray()
	var gb := PackedInt32Array()
	for y in h:
		for x in w:
			var i := y * w + x
			if gmask[i] == 0 or sm[i] != 0:
				continue
			gp.append(rp + Vector2(x, y))
			gc.append(raw[i])
			if st == ShipBreakup.Style.PART:
				gb.append(lab[i])
			else:
				gb.append(clampi(int((float(x) - float(H.x0)) / bw * nb), 0, nb - 1))
	plan.glow = {p = gp, c = gc, band = gb}
	plan.nb = nb
	return {majors = mj, shards = [], centre = r.position + Vector2i(int(cx), int(cy)), plan = plan}


## The bright warm pixels (the Custodian's pinpoints, the Hellbender's specks),
## gathered into lights: {p (canvas), n}. Largest first.
static func _boss_lights(H: Dictionary) -> Array:
	var w: int = H.w
	var h: int = H.h
	var r: Rect2i = H.r
	var raw: PackedColorArray = H.raw
	var mask: PackedByteArray = H.mask
	var hot := PackedByteArray()
	hot.resize(w * h)
	for i in w * h:
		if mask[i] == 1:
			var c := raw[i]
			if c.r > 0.7 and c.r >= c.b + 0.22 and c.get_luminance() > 0.5:
				hot[i] = 1
	var seen := PackedByteArray()
	seen.resize(w * h)
	var out: Array = []
	for i2 in w * h:
		if hot[i2] == 0 or seen[i2] == 1:
			continue
		var q: Array[int] = [i2]
		seen[i2] = 1
		var head := 0
		var sum := Vector2.ZERO
		while head < q.size():
			var cur := q[head]
			head += 1
			var cx := cur % w
			var cy := cur / w
			sum += Vector2(cx, cy)
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					var nx: int = cx + dx
					var ny: int = cy + dy
					if nx < 0 or ny < 0 or nx >= w or ny >= h:
						continue
					var j := ny * w + nx
					if hot[j] == 1 and seen[j] == 0:
						seen[j] = 1
						q.append(j)
		out.append({p = Vector2(r.position) + sum / float(q.size()), n = q.size()})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.n) > int(b.n))
	return out


## Vertical slices with jagged seams, for a long hull (the Hellbender's ribs).
static func _lab_slices(H: Dictionary, mask: PackedByteArray, k: int, rng: RandomNumberGenerator) -> PackedInt32Array:
	var w: int = H.w
	var h: int = H.h
	var bw := float(int(H.x1) - int(H.x0) + 1)
	var cy: float = H.cy
	var jag := _field(rng, w, h, 4)
	var xs: Array[float] = []
	var tilts: Array[float] = []
	for i in k - 1:
		xs.append(float(H.x0) + bw * ((float(i) + 1.0) / float(k) + rng.randf_range(-0.03, 0.03)))
		tilts.append(rng.randf_range(-0.2, 0.2))
	var lab := PackedInt32Array()
	lab.resize(w * h)
	for y in h:
		for x in w:
			var i2 := y * w + x
			if mask[i2] == 0:
				lab[i2] = -1
				continue
			var j := 0
			for f in k - 1:
				if float(x) > _fold_x(xs[f], tilts[f], jag, f, y, cy):
					j = f + 1
			lab[i2] = j
	return lab


## UNMAKING's glass to shatter: each piece's rim, three pixels deep, tagged
## 10 + the piece, so each piece's shatter is its own.
static func _mark_rims(H: Dictionary, lab: PackedInt32Array, sm: PackedByteArray, depth: int) -> void:
	var w: int = H.w
	var h: int = H.h
	var dist := PackedInt32Array()
	dist.resize(w * h)
	dist.fill(99)
	var q: Array[int] = []
	for y in h:
		for x in w:
			var i := y * w + x
			if lab[i] < 0:
				continue
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + o.x
				var ny: int = y + o.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h or lab[ny * w + nx] != lab[i]:
					dist[i] = 0
					q.append(i)
					break
	var head := 0
	while head < q.size():
		var cur := q[head]
		head += 1
		var d := dist[cur]
		if d >= depth - 1:
			continue
		var cx := cur % w
		var cy := cur / w
		for o2 in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx2: int = cx + o2.x
			var ny2: int = cy + o2.y
			if nx2 < 0 or ny2 < 0 or nx2 >= w or ny2 >= h:
				continue
			var j := ny2 * w + nx2
			if lab[j] == lab[cur] and dist[j] > d + 1:
				dist[j] = d + 1
				q.append(j)
	for i2 in w * h:
		if lab[i2] >= 0 and dist[i2] < depth and sm[i2] == 0:
			sm[i2] = 10 + lab[i2]


## Charred: darker in held steps, warm soot, the edges darkest. Still the ship.
static func _charred_all(im: Image, amt: float) -> Image:
	var out: Image = im.duplicate()
	var w := im.get_width()
	var h := im.get_height()
	for y in h:
		for x in w:
			var p := im.get_pixel(x, y)
			if p.a <= 0.0:
				continue
			var edge := false
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var ex: int = x + o.x
				var ey: int = y + o.y
				if ex < 0 or ey < 0 or ex >= w or ey >= h or im.get_pixel(ex, ey).a <= 0.0:
					edge = true
			var k := 1.0 - amt * (0.55 if not edge else 0.7)
			if ((x + y) & 1) == 0:
				k -= amt * 0.06
			var q := Color(p.r * k, p.g * k, p.b * k).lerp(SOOT, amt * 0.3)
			out.set_pixel(x, y, Color(q.r, q.g, q.b, p.a))
	return out


static func _cut_boss(img: Image, used: Rect2i, seed: int, st: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 4441 + st * 37
	var H := _hull_pic(img, used, 0)
	var r: Rect2i = H.r
	if int(H.n) == 0:
		return {majors = [], shards = [], centre = r.get_center(), plan = {r = r, glob = Vector2i.ZERO, box = r}}
	var w: int = H.w
	var h: int = H.h
	var n := w * h
	var cx: float = H.cx
	var cy: float = H.cy
	var bw := float(int(H.x1) - int(H.x0) + 1)
	var bh := float(int(H.y1) - int(H.y0) + 1)
	var raw: PackedColorArray = H.raw
	var col: PackedColorArray = H.col
	var mask: PackedByteArray = H.mask
	var rp := Vector2(r.position)
	var lights := _boss_lights(H)
	var core := rp + Vector2(cx, cy)
	if not lights.is_empty():
		core = lights[0].p
	if st == ShipBreakup.Style.CUST_CASCADE or st == ShipBreakup.Style.CUST_COLLAPSE or st == ShipBreakup.Style.CUST_SPLIT:
		# Centred on the bounding box, not ink mass: the front octahedron pulls it 9px forward
		# (Jon).
		core = rp + Vector2(float(int(H.x0) + int(H.x1) + 1), float(int(H.y0) + int(H.y1) + 1)) * 0.5
	var plan := {r = r, glob = Vector2i.ZERO, lights = lights, core = core, cx = cx, cy = cy, bw = bw, bh = bh,
		box = _ink_box(r, H, bw, bh)}
	var sm := PackedByteArray()
	sm.resize(n)
	var lab := PackedInt32Array()
	var k := 1
	match st:
		ShipBreakup.Style.CUST_CASCADE:
			k = 8
			lab = _lab_voronoi(H, mask, k, rng)
			_mark_band(H, lab, sm, 3, rng)
		ShipBreakup.Style.CUST_COLLAPSE:
			# wedges round the centre, each cut again into an inner and an
			# outer layer
			k = 16
			lab.resize(n)
			var lc := core - rp
			var rot := rng.randf() * TAU
			var fd := _field(rng, w, h, 6)
			for y in h:
				for x in w:
					var i5 := y * w + x
					if mask[i5] == 0:
						lab[i5] = -1
						continue
					var u := Vector2((float(x) - lc.x) / (bw * 0.5), (float(y) - lc.y) / (bh * 0.5))
					var a := atan2(u.y, u.x) + 0.15 * _nz(fd, x, y) + rot
					var wedge := clampi(int(fposmod(a, TAU) / (TAU / 8.0)), 0, 7)
					var outer := 1 if u.length() + 0.05 * _nz(fd, y, x) > 0.5 else 0
					lab[i5] = wedge * 2 + outer
			_mark_band(H, lab, sm, 2, rng)
		ShipBreakup.Style.CUST_SPLIT:
			# the facets, each cut again along the spine: top and bottom halves
			k = 16
			var v := _lab_voronoi(H, mask, 8, rng)
			lab.resize(n)
			var jag2 := _field(rng, w, h, 5)
			var sy := core.y - rp.y
			var spine := PackedVector2Array()
			for y in h:
				for x in w:
					var i6 := y * w + x
					if mask[i6] == 0:
						lab[i6] = -1
						continue
					var line := sy + 1.6 * _nz(jag2, x, 0.0)
					lab[i6] = v[i6] * 2 + (1 if float(y) > line else 0)
					if absf(float(y) - line) < 1.6:
						sm[i6] = 3
						spine.append(rp + Vector2(x, y))
			_mark_band(H, lab, sm, 2, rng)
			plan.spine_pts = spine
		ShipBreakup.Style.CUST_UNMAKING:
			k = 8
			lab = _lab_voronoi(H, mask, k, rng)
			_mark_band(H, lab, sm, 1, rng)
			_mark_rims(H, lab, sm, 3)
		ShipBreakup.Style.CUST_SUPERNOVA:
			k = 1
			lab.resize(n)
			for i in n:
				lab[i] = 0 if mask[i] == 1 else -1
		ShipBreakup.Style.HELL_CHAIN:
			k = 2
			var split := float(int(H.x0)) + 0.42 * bw
			var jag := _field(rng, w, h, 4)
			lab.resize(n)
			for y in h:
				for x in w:
					var i2 := y * w + x
					if mask[i2] == 0:
						lab[i2] = -1
						continue
					lab[i2] = 0 if float(x) < split + 2.5 * _nz(jag, x, y) + 0.15 * (float(y) - cy) else 1
			_mark_band(H, lab, sm, 2, rng)
			var blasts: Array = []
			var bf := _field(rng, w, h, 3)
			var fr := [0.9, 0.78, 0.66, 0.55, 0.3, 0.16]
			for i3 in fr.size():
				var alt := (0.25 if i3 % 2 == 0 else -0.22) * bh
				var p := _nearest_hull(H, mask, Vector2(float(H.x0) + float(fr[i3]) * bw, cy + alt))
				_mark_disc(H, lab, sm, Vector2(p), 3.5, bf, 2 + i3)
				blasts.append(rp + Vector2(p))
			plan.blasts = blasts
			plan.reactor = rp + Vector2(split, cy)
			plan.holds = [rp + Vector2(_nearest_hull(H, mask, Vector2(float(H.x0) + 0.58 * bw, cy - 0.5 * bh))),
				rp + Vector2(_nearest_hull(H, mask, Vector2(float(H.x0) + 0.72 * bw, cy + 0.5 * bh)))]
		ShipBreakup.Style.HELL_BURNOUT:
			k = 5
			lab = _lab_slices(H, mask, k, rng)
			_mark_band(H, lab, sm, 1, rng)
		ShipBreakup.Style.HELL_UNCOIL:
			# Cracks follow the ship's ribs traced off the picture (Jon); cut at every second seam.
			var curves := _rib_curves(H)
			lab.resize(n)
			var cuts: Array = []
			for ci in curves.size():
				if ci % 2 == 1:
					cuts.append(curves[ci])
			k = cuts.size() + 1
			for y in h:
				for x in w:
					var i7 := y * w + x
					if mask[i7] == 0:
						lab[i7] = -1
						continue
					var j7 := 0
					for c in cuts:
						var cx7: int = (c as Dictionary).full[y]
						if x > cx7:
							j7 += 1
					lab[i7] = j7
			var pts := PackedVector2Array()
			for c2 in curves:
				var tr: PackedInt32Array = (c2 as Dictionary).traced
				for y2 in h:
					var x2 := tr[y2]
					if x2 >= 0 and mask[y2 * w + x2] == 1:
						sm[y2 * w + x2] = 1
						pts.append(rp + Vector2(x2, y2))
			plan.rib_pts = pts
			plan.rib_count = curves.size()
			# the salamander device: the brightest thing in the front third
			var best_l := -1.0
			for y8 in h:
				for x8 in int(float(int(H.x0)) + 0.35 * bw):
					var i8 := y8 * w + x8
					if mask[i8] == 1 and raw[i8].get_luminance() > best_l:
						best_l = raw[i8].get_luminance()
						plan.emblem = rp + Vector2(x8, y8)
			plan.holds = [rp + Vector2(_nearest_hull(H, mask, Vector2(float(H.x0) + 0.5 * bw, cy - 0.5 * bh))),
				rp + Vector2(_nearest_hull(H, mask, Vector2(float(H.x0) + 0.68 * bw, cy + 0.5 * bh)))]
			core = rp + Vector2(cx, cy)
			plan.core = core
	var lit := _majors_of(H, raw, lab, sm, k)
	var mj := _majors_of(H, col, lab, sm, k)
	for i4 in mj.size():
		var m: Dictionary = mj[i4]
		var away: Vector2 = (m.mid as Vector2) - core
		var dir := away.normalized() if away.length() > 1.0 else Vector2(0, -1)
		var own := Vector2i.ZERO
		var dead: Image = m.image
		var stages: Array = [lit[i4].image]
		var j: int = m.lab
		match st:
			ShipBreakup.Style.CUST_CASCADE:
				own = Vector2i((dir * rng.randf_range(11.0, 16.0)).round())
				stages.append(_scorched(dead, m.at, core, 0.4 * bw))
			ShipBreakup.Style.CUST_COLLAPSE:
				own = Vector2i((dir * (rng.randf_range(10.0, 14.0) if j % 2 == 1 else rng.randf_range(5.0, 8.0))).round())
				stages.append(_scorched(dead, m.at, core, 0.4 * bw))
			ShipBreakup.Style.CUST_SPLIT:
				var top := j % 2 == 0
				own = Vector2i(roundi(signf(away.x) * rng.randf_range(1.0, 3.0)), -rng.randi_range(10, 13) if top else rng.randi_range(10, 13))
				stages.append(_scorched(dead, m.at, core, 0.3 * bw))
			ShipBreakup.Style.CUST_UNMAKING:
				own = Vector2i(roundi(((m.mid as Vector2).x - (rp.x + cx)) / (bw * 0.5) * 13.0), rng.randi_range(-2, 2))
				stages.append(dead)
			ShipBreakup.Style.CUST_SUPERNOVA:
				stages.append(_charred_all(dead, 0.75))
			ShipBreakup.Style.HELL_CHAIN:
				own = Vector2i(-10, -3) if j == 0 else Vector2i(11, 4)
				var cum: Image = dead
				for b in plan.blasts:
					cum = _scorched(cum, m.at, b, 8.0)
					stages.append(cum)
				stages.append(_scorched(cum, m.at, plan.reactor, 22.0))
			ShipBreakup.Style.HELL_BURNOUT:
				own = Vector2i((j - 2) * 4, (2 - j) * 4)
				stages.append(_charred_all(dead, 0.45))
				stages.append(_charred_all(dead, 0.8))
			ShipBreakup.Style.HELL_UNCOIL:
				# the rib sections fly apart and settle scattered, each upright or
				# turned over (quarter turns in flight, landing on a half turn or none)
				var sc := (dir + Vector2(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.6, 0.6))).normalized()
				own = Vector2i((sc * rng.randf_range(14.0, 28.0)).round())
				stages.append(_charred_all(dead, 0.55))
				m.rot_final = 2 if rng.randf() < 0.4 else 0
				m.rot_total = 4 * rng.randi_range(1, 2) + int(m.rot_final)
		# Rests stay on the 240x120 canvas, or a piece settling past its edge is cut off the
		# wreck.
		var isz: Vector2i = (m.image as Image).get_size()
		own.x = clampi(own.x, -int(m.at.x), img.get_width() - isz.x - int(m.at.x))
		own.y = clampi(own.y, -int(m.at.y), img.get_height() - isz.y - int(m.at.y))
		m.own = own
		m.glob = Vector2i.ZERO
		m.off = own
		m.dir = dir
		m.stages = stages
		m.image = stages.back()
		if int(m.get("rot_final", 0)) == 2:
			var turned: Image = (stages.back() as Image).duplicate()
			turned.rotate_180()
			m.image = turned
	var sh := _shards_of(H, raw, lab, sm, rng, 70, 0.012) if st == ShipBreakup.Style.CUST_CASCADE else _shards_of(H, raw, lab, sm, rng)
	return {majors = mj, shards = sh, centre = r.position + Vector2i(int(cx), int(cy)), plan = plan}


## Rib seams traced from smoothed luminance dips linked row to row; short curves are grain,
## not seams.
## Why: docs/why/BreakupCuts.md#rib-seams
static func _rib_curves(H: Dictionary) -> Array:
	var w: int = H.w
	var h: int = H.h
	var mask: PackedByteArray = H.mask
	var raw: PackedColorArray = H.raw
	var L := PackedFloat32Array()
	L.resize(w * h)
	for i in w * h:
		if mask[i] == 1:
			L[i] = raw[i].get_luminance()
	var Ls := PackedFloat32Array()
	Ls.resize(w * h)
	for y in h:
		for x in w:
			if mask[y * w + x] == 0:
				continue
			var sum := 0.0
			var cnt := 0
			for yy in range(y - 2, y + 3):
				if yy >= 0 and yy < h and mask[yy * w + x] == 1:
					sum += L[yy * w + x]
					cnt += 1
			Ls[y * w + x] = sum / float(cnt)
	var mins := PackedByteArray()
	mins.resize(w * h)
	for y2 in h:
		for x2 in range(3, w - 3):
			var i2 := y2 * w + x2
			if mask[i2 - 3] == 0 or mask[i2 + 3] == 0:
				continue
			var v := Ls[i2]
			if v < Ls[i2 - 1] and v <= Ls[i2 + 1] and v <= Ls[i2 - 2] and v <= Ls[i2 + 2] \
					and (Ls[i2 - 3] + Ls[i2 + 3]) * 0.5 - v > 0.03:
				mins[i2] = 1
	var cy := int(H.cy)
	var curves: Array = []
	for x0 in w:
		if mins[cy * w + x0] == 0:
			continue
		var tr := PackedInt32Array()
		tr.resize(h)
		tr.fill(-1)
		tr[cy] = x0
		var count := 1
		for d in [-1, 1]:
			var x := x0
			var y3 := cy
			var miss := 0
			while true:
				y3 += int(d)
				if y3 < 0 or y3 >= h:
					break
				var best := -1
				for xx in range(x - 2, x + 3):
					if xx >= 0 and xx < w and mins[y3 * w + xx] == 1:
						if best < 0 or absi(xx - x) < absi(best - x):
							best = xx
				if best >= 0:
					x = best
					tr[y3] = x
					count += 1
					miss = 0
				else:
					miss += 1
					if miss > 2 or mask[y3 * w + x] == 0:
						break
					tr[y3] = x
					count += 1
		var colh := 0
		for y4 in h:
			if mask[y4 * w + x0] == 1:
				colh += 1
		if count >= colh / 2:
			curves.append({traced = tr, x = x0})
	curves.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.x) < int(b.x))
	var kept: Array = []
	for c in curves:
		if not kept.is_empty() and int(c.x) - int(kept.back().x) < 3:
			continue
		kept.append(c)
	for c2 in kept:
		var tr2: PackedInt32Array = c2.traced
		var full := tr2.duplicate()
		var first := -1
		var last := -1
		for y5 in h:
			if tr2[y5] >= 0:
				if first < 0:
					first = y5
				last = y5
		for y6 in h:
			if y6 < first:
				full[y6] = tr2[first]
			elif y6 > last:
				full[y6] = tr2[last]
			elif full[y6] < 0:
				full[y6] = full[y6 - 1]
		c2.full = full
	return kept
