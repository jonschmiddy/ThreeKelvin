class_name HullScars
extends RefCounted

## What a cheap yard's hull has that a good one's does not, drawn on the hull's own pixels
## (Jon, Nov 17: "C is not messed up enough"). Three ideas on trial; HullGrade.DRAMA picks.
## Why: docs/why/HullScars.md#hull-scars

enum Idea { NONE, GRIME, BATTLE, JUNKER }
## How much of the scarring each grade carries: C, B, A, S. B's scars are the first of C's.
const AMT := [1.0, 0.5, 0.18, 0.0]


## Scars `img` (already graded) in place. Where they go is read off `base`, the ungraded
## picture, and seeded by `hull`, so every grade of a hull scars the same places.
static func scar(img: Image, base: Image, r: HullGrade._Ramps, grade: int, idea: int, hull: String, at: Dictionary) -> void:
	var amt: float = AMT[clampi(grade, 0, 3)]
	if idea == Idea.NONE or amt <= 0.0:
		return
	var m := _Mask.new(img, at)
	var hs := absi(hull.hash()) % 99991 + 13
	match idea:
		Idea.GRIME:
			_soot(img, r, m, amt, hs, 1.0)
			_rust(img, base, r, m, amt, hs, 1.0)
		Idea.BATTLE:
			_battle(img, r, m, amt, hs)
		Idea.JUNKER:
			_panels(img, base, r, m, amt, hs)
			_soot(img, r, m, amt, hs, 0.55)
			_rust(img, base, r, m, amt, hs, 0.6)
			var n := _count(m, 9000.0, amt)
			for i in n:
				var p := m.place(Vector2i(10, 7), hs + 400 + i * 7)
				if p.x >= 0:
					_patch(img, r, m, Rect2i(p, Vector2i(10, 7)).grow(-int(2.0 * (1.0 - amt))), hs + i)


## Which pixels may be scarred: two in from the silhouette, off the lights and markings.
class _Mask extends RefCounted:
	var w := 0
	var h := 0
	var deep := PackedByteArray()
	var area := 0
	var top := PackedInt32Array()      ## each column's first opaque row, -1 for none
	var bottom := PackedInt32Array()
	var taken: Array[Rect2i] = []

	func _init(img: Image, at: Dictionary) -> void:
		w = img.get_width()
		h = img.get_height()
		var solid := PackedByteArray()
		solid.resize(w * h)
		top.resize(w)
		bottom.resize(w)
		for x in w:
			top[x] = -1
			bottom[x] = -1
			for y in h:
				if img.get_pixel(x, y).a > 0.0:
					solid[y * w + x] = 1
					if top[x] < 0:
						top[x] = y
					bottom[x] = y
		deep.resize(w * h)
		for y in range(2, h - 2):
			for x in range(2, w - 2):
				var ok := true
				for d: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
						Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2), Vector2i(1, 1),
						Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
					if solid[(y + d.y) * w + x + d.x] == 0:
						ok = false
						break
				if ok:
					deep[y * w + x] = 1
					area += 1
		# the lights and markings stay clean, so a scar never sits on a pane
		for wi: Array in at.get("windows", []):
			_keep(Rect2i(int(wi[0]), int(wi[1]), int(wi[2]), int(wi[3])).grow(2))
		for nv: Array in at.get("nav", []):
			_keep(Rect2i(int(nv[0]), int(nv[1]), 2, 2).grow(2))
		for mk: Array in at.get("markers", []):
			_keep(Rect2i(int(mk[0]), int(mk[1]), 1, 1).grow(2))
		if at.has("registry"):
			_keep(Rect2i(int(at.registry[0]), int(at.registry[1]), 26, 5).grow(2))
		if at.has("chevrons"):
			_keep(Rect2i(int(at.chevrons[0]) - 14, int(at.chevrons[1]) - 5, 15, 11))

	func _keep(rc: Rect2i) -> void:
		for y in range(maxi(rc.position.y, 0), mini(rc.end.y, h)):
			for x in range(maxi(rc.position.x, 0), mini(rc.end.x, w)):
				if deep[y * w + x] == 1:
					deep[y * w + x] = 0
					area -= 1

	func ok(x: int, y: int) -> bool:
		return x >= 0 and y >= 0 and x < w and y < h and deep[y * w + x] == 1

	## A free spot for a `size` box wholly on the hull, or (-1, -1); the n-th try of `salt`.
	func place(size: Vector2i, salt: int) -> Vector2i:
		for k in 60:
			var x := int(HullGrade.noise(k, 1, salt) * float(w - size.x))
			var y := int(HullGrade.noise(k, 2, salt) * float(h - size.y))
			var rc := Rect2i(x, y, size.x, size.y)
			var clear := true
			for t: Rect2i in taken:
				if t.grow(2).intersects(rc):
					clear = false
					break
			if not clear:
				continue
			var all := true
			for yy in range(y, y + size.y):
				for xx in range(x, x + size.x):
					if not ok(xx, yy):
						all = false
						break
				if not all:
					break
			if all:
				taken.append(rc)
				return Vector2i(x, y)
		return Vector2i(-1, -1)


# ------------------------------------------------------------------ the ramp walks

## `c` walked down its own ramp until it is `dl` darker (or as dark as the ramp goes).
static func down(r: HullGrade._Ramps, c: Color, dl: float) -> Color:
	var want := HullGrade.luma(c) - dl
	var out := c
	for k in range(1, 40):
		var n := r.step(c, -k)
		if HullGrade.key(n) == HullGrade.key(out):
			break
		out = n
		if HullGrade.luma(n) <= want:
			break
	return out


static func up(r: HullGrade._Ramps, c: Color, dl: float) -> Color:
	var want := HullGrade.luma(c) + dl
	var out := c
	for k in range(1, 40):
		var n := r.step(c, k)
		if HullGrade.key(n) == HullGrade.key(out):
			break
		out = n
		if HullGrade.luma(n) >= want:
			break
	return out


## The grey nearest a lightness, from the hull's own greys.
static func grey_at(r: HullGrade._Ramps, l: float) -> Color:
	return r.lift(Color(0, 0, 0), l)


## Rust: the darker half of the manufacturer's warm ramp, matched to the paint's lightness.
static func rust(r: HullGrade._Ramps, c: Color) -> Color:
	if r.accent.is_empty():
		return down(r, c, 0.1)
	var want := HullGrade.luma(c) * 0.65
	var best: Color = r.accent[0]
	for i in maxi(1, int(r.accent.size() * 0.45)):
		var a: Color = r.accent[i]
		if absf(HullGrade.luma(a) - want) < absf(HullGrade.luma(best) - want):
			best = a
	return best


## A 2x2-celled ordered dither, so a soft edge steps in clumps, never single pixels.
static func dith(x: int, y: int) -> float:
	return (float(HullWear.BAYER[(y / 2) % 4][(x / 2) % 4]) + 0.5) / 16.0


static func _count(m: _Mask, per: float, amt: float) -> int:
	return int(round(float(m.area) / per * amt))


# ------------------------------------------------------------------ 1  grime

## Soot from the engines forward and grime pooled along the belly, in soft dithered clumps.
static func _soot(img: Image, r: HullGrade._Ramps, m: _Mask, amt: float, hs: int, k: float) -> void:
	var src := img.duplicate() as Image
	for y in m.h:
		for x in m.w:
			if not m.ok(x, y):
				continue
			var aft := 1.0 - float(x) / float(m.w)
			var span := maxf(1.0, float(m.bottom[x] - m.top[x]))
			var low := clampf((float(y - m.top[x]) / span - 0.45) / 0.55, 0.0, 1.0)
			var d := 0.8 * HullGrade.smooth(x, y, 13, 8, hs + 21) + 0.42 * pow(aft, 1.3) + 0.28 * low * low
			d = d * amt * k + (dith(x, y) - 0.5) * 0.16
			var c := src.get_pixel(x, y)
			if d > 0.86:
				img.set_pixel(x, y, down(r, c, 0.2))
			elif d > 0.66:
				img.set_pixel(x, y, down(r, c, 0.13))
			elif d > 0.48:
				img.set_pixel(x, y, down(r, c, 0.06))


## Rust bleeding down from under seams and rivets: brown runs, a pixel or two wide.
static func _rust(img: Image, base: Image, r: HullGrade._Ramps, m: _Mask, amt: float, hs: int, k: float) -> void:
	var src := img.duplicate() as Image
	for y in range(1, m.h):
		for x in m.w:
			if not m.ok(x, y) or not m.ok(x, y - 1):
				continue
			# a run starts where the panel comes out from under something dark
			if HullGrade.luma(base.get_pixel(x, y)) < HullGrade.luma(base.get_pixel(x, y - 1)) + 0.12:
				continue
			# rust gathers on some plates, not all, and is rarer at a better grade
			if HullGrade.smooth(x, y, 17, 11, hs + 40) > 0.55 or HullGrade.noise(x, y, hs + 31) > 0.07 * amt * k:
				continue
			var run := 4 + int(HullGrade.noise(x, y, hs + 32) * 13.0 * amt)
			var wide := HullGrade.noise(x, y, hs + 33) < 0.6
			for j in run:
				var yy := y + j
				if not m.ok(x, yy):
					break
				# the tail thins: the last third is lighter rust
				var c := src.get_pixel(x, yy)
				var col := rust(r, c) if j < run * 2 / 3 else rust(r, up(r, c, 0.08))
				img.set_pixel(x, yy, col)
				if wide and j < run / 2 and m.ok(x + 1, yy):
					img.set_pixel(x + 1, yy, rust(r, src.get_pixel(x + 1, yy)))


# ------------------------------------------------------------------ 2  battle

static func _battle(img: Image, r: HullGrade._Ramps, m: _Mask, amt: float, hs: int) -> void:
	var grow := 0.65 + 0.35 * amt
	var n := _count(m, 1500.0, 1.0)
	# one list, the same order at every grade: B and A carry the first of C's scars
	for i in int(round(float(n) * amt)):
		var kind := i % 4
		match kind:
			0:
				var rad := int(round((6.0 + HullGrade.noise(i, 5, hs) * 5.0) * grow))
				var p := m.place(Vector2i(rad * 3, rad * 2), hs + 100 + i)
				if p.x >= 0:
					_scorch(img, r, m, p + Vector2i(rad * 3 / 2, rad), rad, hs + i)
			1:
				var sz := Vector2i(int(16 * grow), int(9 * grow))
				var p := m.place(sz, hs + 200 + i)
				if p.x >= 0:
					_dent(img, r, m, Rect2i(p, sz))
			2:
				var sz := Vector2i(int((11 + HullGrade.noise(i, 6, hs) * 6.0) * grow), int((8 + HullGrade.noise(i, 7, hs) * 4.0) * grow))
				var p := m.place(sz, hs + 300 + i)
				if p.x >= 0:
					_patch(img, r, m, Rect2i(p, sz), hs + i)
			3:
				var sz := Vector2i(int(10 * grow), int(7 * grow))
				var p := m.place(sz, hs + 500 + i)
				if p.x >= 0:
					_breach(img, r, m, Rect2i(p, sz), hs + i)


## A blast mark: a black heart, a ragged dark ring, a few streaks thrown out.
static func _scorch(img: Image, r: HullGrade._Ramps, m: _Mask, at: Vector2i, rad: int, salt: int) -> void:
	var src := img.duplicate() as Image
	var rx := float(rad) * 1.5
	var ry := float(rad)
	for y in range(at.y - rad * 2, at.y + rad * 2 + 1):
		for x in range(at.x - rad * 3, at.x + rad * 3 + 1):
			if not m.ok(x, y):
				continue
			var dx := float(x - at.x) / rx
			var dy := float(y - at.y) / ry
			var ang := atan2(dy, dx)
			# a ragged rim: the radius wobbles with the angle
			var rim := 0.8 + 0.4 * HullGrade.noise(int((ang + PI) * 2.5), 0, salt)
			var d := sqrt(dx * dx + dy * dy) / rim
			var c := src.get_pixel(x, y)
			if d < 0.38:
				img.set_pixel(x, y, grey_at(r, 0.04))
			elif d < 0.7:
				img.set_pixel(x, y, down(r, c, 0.28))
			elif d < 1.0:
				img.set_pixel(x, y, down(r, c, 0.16))
			elif d < 1.5 and dith(x, y) < (1.5 - d) * 1.6:
				img.set_pixel(x, y, down(r, c, 0.08))
	# streaks thrown out, aft-ward (the ship flew on)
	for s in 3:
		var a := PI + (HullGrade.noise(s, 9, salt) - 0.5) * 1.6
		var ln := rad * 2 + int(HullGrade.noise(s, 10, salt) * float(rad))
		for t in range(rad, ln):
			var x := at.x + int(round(cos(a) * t * 1.4))
			var y := at.y + int(round(sin(a) * t * 0.7))
			if m.ok(x, y):
				img.set_pixel(x, y, down(r, src.get_pixel(x, y), 0.12 if t < ln - 2 else 0.06))


## A dent, lit from above: its upper lip in shadow, its lower rim catching the light.
static func _dent(img: Image, r: HullGrade._Ramps, m: _Mask, rc: Rect2i) -> void:
	var src := img.duplicate() as Image
	var cx := rc.position.x + rc.size.x / 2.0
	var cy := rc.position.y + rc.size.y / 2.0
	var rx := rc.size.x / 2.0
	var ry := rc.size.y / 2.0
	for y in range(rc.position.y, rc.end.y):
		for x in range(rc.position.x, rc.end.x):
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - cy) / ry
			var d := dx * dx + dy * dy
			if d > 1.0 or not m.ok(x, y):
				continue
			var c := src.get_pixel(x, y)
			if dy < -0.2:
				img.set_pixel(x, y, down(r, c, 0.28 if d > 0.4 else 0.16))
			elif dy > 0.35 and d > 0.4:
				img.set_pixel(x, y, up(r, c, 0.2))
			else:
				img.set_pixel(x, y, down(r, c, 0.08))


## A hole plated over with whatever was to hand: an odd plate, a dark seam, rivets.
static func _patch(img: Image, r: HullGrade._Ramps, m: _Mask, rc: Rect2i, salt: int) -> void:
	var src := img.duplicate() as Image
	var sum := 0.0
	var k := 0
	for y in range(rc.position.y, rc.end.y):
		for x in range(rc.position.x, rc.end.x):
			sum += HullGrade.luma(src.get_pixel(x, y))
			k += 1
	var under := sum / maxf(1.0, float(k))
	var kind := int(HullGrade.noise(salt, 3, 77) * 3.0)
	var face: Color
	match kind:
		0: face = grey_at(r, under + 0.16)        # a bright new plate
		1: face = grey_at(r, under - 0.15)        # a dark scrap plate
		_: face = rust(r, Color(under, under, under))    # a rusted plate
	var lit := up(r, face, 0.1) if kind != 2 else grey_at(r, HullGrade.luma(face) + 0.1)
	var seam := grey_at(r, minf(under, HullGrade.luma(face)) - 0.22)
	for y in range(rc.position.y, rc.end.y):
		for x in range(rc.position.x, rc.end.x):
			if not m.ok(x, y):
				continue
			var edge := x == rc.position.x or y == rc.position.y or x == rc.end.x - 1 or y == rc.end.y - 1
			var c := face
			if edge:
				c = seam
			elif y == rc.position.y + 1:
				c = lit
			# rivets: a lit head in from each corner, then every third along the top and bottom
			var ix := x - rc.position.x - 1
			var inner_row := y == rc.position.y + 1 or y == rc.end.y - 2
			if not edge and inner_row and (ix % 3 == 0) and x < rc.end.x - 2:
				c = seam if y == rc.end.y - 2 else grey_at(r, HullGrade.luma(face) + 0.22)
			img.set_pixel(x, y, c)


## A hole punched through: black inside, the torn metal round it lit on its lower lip.
static func _breach(img: Image, r: HullGrade._Ramps, m: _Mask, rc: Rect2i, salt: int) -> void:
	var src := img.duplicate() as Image
	var cx := rc.position.x + rc.size.x / 2.0
	var cy := rc.position.y + rc.size.y / 2.0
	for y in range(rc.position.y, rc.end.y):
		for x in range(rc.position.x, rc.end.x):
			if not m.ok(x, y):
				continue
			var dx := (x + 0.5 - cx) / (rc.size.x / 2.0)
			var dy := (y + 0.5 - cy) / (rc.size.y / 2.0)
			var d := dx * dx + dy * dy + (HullGrade.noise(x / 2, y / 2, salt) - 0.5) * 0.5
			var c := src.get_pixel(x, y)
			if d < 0.45:
				img.set_pixel(x, y, grey_at(r, 0.0))
			elif d < 1.0:
				img.set_pixel(x, y, up(r, c, 0.18) if dy > 0.0 else down(r, c, 0.25))


# ------------------------------------------------------------------ 3  junker

## Whole panels swapped for odd ones, one or two torn off down to the frame.
static func _panels(img: Image, base: Image, r: HullGrade._Ramps, m: _Mask, amt: float, hs: int) -> void:
	var panels := _find_panels(base, m)
	if panels.is_empty():
		return
	# a fixed shuffle by the hull: the same panels go first at every grade
	panels.sort_custom(func(a: Array, b: Array) -> bool:
		return HullGrade.noise(a[1].x, a[1].y, hs) < HullGrade.noise(b[1].x, b[1].y, hs))
	var swaps := int(round(float(panels.size()) * 0.5 * amt))
	var torn := 0
	var torn_max := 2 if amt >= 1.0 else (1 if amt >= 0.5 else 0)
	var src := img.duplicate() as Image
	for i in mini(swaps, panels.size()):
		var px: Array = panels[i][0]
		if torn < torn_max and px.size() >= 60 and px.size() <= 500:
			torn += 1
			_torn(img, r, panels[i][2], px)
			continue
		var mode := i % 3
		for p: Vector2i in px:
			var c := src.get_pixel(p.x, p.y)
			match mode:
				0: c = up(r, c, 0.22)
				1: c = down(r, c, 0.24)
				2: c = rust(r, c)
			img.set_pixel(p.x, p.y, c)


## The hull's plates: runs of panel between the dark seams, [pixels, first pixel, box].
static func _find_panels(img: Image, m: _Mask) -> Array[Array]:
	var lum := 0.0
	var k := 0
	for y in m.h:
		for x in m.w:
			if m.ok(x, y):
				lum += HullGrade.luma(img.get_pixel(x, y))
				k += 1
	var mean := lum / maxf(1.0, float(k))
	var seam := mean * 0.62
	var seen := PackedByteArray()
	seen.resize(m.w * m.h)
	var out: Array[Array] = []
	for y0 in m.h:
		for x0 in m.w:
			if seen[y0 * m.w + x0] or not m.ok(x0, y0) or HullGrade.luma(img.get_pixel(x0, y0)) < seam:
				continue
			var run: Array[Vector2i] = [Vector2i(x0, y0)]
			seen[y0 * m.w + x0] = 1
			var box := Rect2i(x0, y0, 1, 1)
			var sum := 0.0
			var i := 0
			while i < run.size():
				var p := run[i]
				i += 1
				sum += HullGrade.luma(img.get_pixel(p.x, p.y))
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var q := p + d
					if not m.ok(q.x, q.y) or seen[q.y * m.w + q.x]:
						continue
					if HullGrade.luma(img.get_pixel(q.x, q.y)) < seam:
						continue
					seen[q.y * m.w + q.x] = 1
					run.append(q)
					box = box.expand(q)
			# a face in the light: a plate in the hull's shade swapped reads as nothing
			if run.size() >= 50 and run.size() <= 2600 and sum / run.size() >= mean:
				out.append([run, Vector2i(x0, y0), box])
	return out


## A plate gone: the dark inside, the frame's ribs, the plate's torn lower edge lit.
static func _torn(img: Image, r: HullGrade._Ramps, box: Rect2i, px: Array) -> void:
	var inside := {}
	for p: Vector2i in px:
		inside[p] = true
	var hole := grey_at(r, 0.03)
	var rib := grey_at(r, 0.16)
	var lip := grey_at(r, 0.3)
	for p: Vector2i in px:
		var c := hole
		if (p.x - box.position.x) % 4 == 2 or p.y == box.position.y + box.size.y / 2:
			c = rib
		if not inside.has(p + Vector2i(0, -1)):
			c = hole
		elif not inside.has(p + Vector2i(0, 1)):
			c = lip
		img.set_pixel(p.x, p.y, c)
