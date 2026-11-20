class_name SolariScars
extends RefCounted

## Three ideas of a worn Solari hull, on trial (Jon, Nov 20: "Retry the wear. It's so-so"),
## each drawn on the hull's own structure (its furnace, its line, its bells, plates, seams
## and rivets) rather than noise. `amt` is HullScars.AMT: 1 at C, 0 at S.
## Why: docs/why/SolariScars.md#solari-wear


# ------------------------------------------------------------------ structure

## The furnace ring's centre and radii from the hull's placements, or a zero size for none.
static func ring(at: Dictionary) -> Rect2:
	var lit: Dictionary = at.get("lit", {})
	var rs: Array = lit.get("rings", [])
	if rs.is_empty():
		return Rect2()
	var q: Array = rs[0]
	return Rect2(float(q[0]), float(q[1]), float(q[2]), float(q[3]))


## Each line run's points from the furnace outward, with their distance along the run.
static func line_pts(at: Dictionary) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var lit: Dictionary = at.get("lit", {})
	var lines: Array = lit.get("lines", [])
	for li in lines.size():
		var pts: Array = lines[li]
		var run: Array[Vector3i] = []
		for i in range(pts.size() - 1):
			var a: Array = pts[i]
			var b: Array = pts[i + 1]
			for x in range(int(a[0]), int(b[0]) + 1):
				var t := 0.0 if int(b[0]) == int(a[0]) else float(x - int(a[0])) / float(int(b[0]) - int(a[0]))
				run.append(Vector3i(x, int(round(lerpf(float(a[1]), float(b[1]), t))), 0))
		if li == 0:
			run.reverse()
		for k in run.size():
			out.append(Vector3i(run[k].x, run[k].y, k))
	return out


## Rivet heads: one or two pixels lighter than everything round them.
static func rivets(base: Image, m: HullScars._Mask) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(1, m.h - 1):
		for x in range(1, m.w - 1):
			if not m.ok(x, y):
				continue
			var l := HullGrade.luma(base.get_pixel(x, y))
			var hi := true
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if HullGrade.luma(base.get_pixel(x + d.x, y + d.y)) > l - 0.1:
					hi = false
					break
			if hi:
				out.append(Vector2i(x, y))
	return out


## Seam pixels: the dark lines between plates.
static func seams(base: Image, m: HullScars._Mask) -> PackedByteArray:
	var s := PackedByteArray()
	s.resize(m.w * m.h)
	var sum := 0.0
	var k := 0
	for y in m.h:
		for x in m.w:
			if m.ok(x, y):
				sum += HullGrade.luma(base.get_pixel(x, y))
				k += 1
	var cut := sum / maxf(1.0, float(k)) * 0.62
	for y in m.h:
		for x in m.w:
			if m.ok(x, y) and HullGrade.luma(base.get_pixel(x, y)) < cut:
				s[y * m.w + x] = 1
	return s


static func _hs(i: int, j: int, salt: int) -> float:
	return HullGrade.noise(i, j, salt)


## A solid stain's shape: soft noise cut at a level, so its edge is ragged but every pixel
## is in or out (no checker). Cells of `sx` x `sy`.
static func blob(x: int, y: int, sx: int, sy: int, salt: int) -> float:
	return HullGrade.smooth(x, y, sx, sy, salt)


## Marks a pixel as worn, so a later layer leaves it to the one that put it there.
static func _take(busy: PackedByteArray, m: HullScars._Mask, x: int, y: int) -> void:
	if not busy.is_empty():
		busy[y * m.w + x] = 1


static func _free(busy: PackedByteArray, m: HullScars._Mask, x: int, y: int) -> bool:
	return busy.is_empty() or busy[y * m.w + x] == 0


# ------------------------------------------------------------------ A  heat-scarred

## Heat tint round the furnace and along the line, soot at the bells and trailing aft,
## and cracks run out from the ring with a warped plate beside it.
static func heat(img: Image, base: Image, r: HullGrade._Ramps, m: HullScars._Mask, amt: float, hs: int, at: Dictionary,
		busy: PackedByteArray = PackedByteArray()) -> void:
	var src := img.duplicate() as Image
	var rg := ring(at)
	if rg.size.x > 0.0:
		var reach := 0.85 * amt
		for y in m.h:
			for x in m.w:
				if not m.ok(x, y):
					continue
				var q := Vector2(float(x) - rg.position.x, float(y) - rg.position.y) / rg.size
				var d := q.length() - 1.0
				# heat rises: the tint reaches further above the ring than below
				var lim := reach * (1.5 if q.y < 0.0 else 0.8)
				# tongues: the reach rises and falls round the ring, its edge ragged
				var sa := (atan2(q.y, q.x) + PI) * 5.0
				var fa := sa - floorf(sa)
				fa = fa * fa * (3.0 - 2.0 * fa)
				lim *= 0.4 + 1.2 * lerpf(_hs(int(sa), 0, hs + 61), _hs(int(sa) + 1, 0, hs + 61), fa)
				lim *= 0.85 + 0.3 * blob(x, y, 4, 3, hs + 62)
				if d < 0.0 or d > lim:
					continue
				var u := d / maxf(lim, 0.001)
				var c := src.get_pixel(x, y)
				if u < 0.2:
					c = HullScars.rust(r, HullScars.down(r, c, 0.06))
				elif u < 0.7:
					c = HullScars.down(r, c, 0.16)
				else:
					c = HullScars.down(r, c, 0.07)
				img.set_pixel(x, y, c)
				_take(busy, m, x, y)
	# the line scorches the plates either side of it, for a length that falls with the grade
	for p in line_pts(at):
		var near := float(p.z) < 60.0 * amt * (0.8 + 0.4 * _hs(p.x, 1, hs + 63))
		var far := float(p.z) < 34.0 * amt
		for dy in [-3, 3, -4, 4]:
			var y: int = p.y + dy
			var outer := absi(dy) == 4
			if not m.ok(p.x, y) or (outer and not far) or (not outer and not near):
				continue
			img.set_pixel(p.x, y, HullScars.down(r, src.get_pixel(p.x, y), 0.07 if outer else 0.15))
			_take(busy, m, p.x, y)
	_bell_soot(img, src, r, m, at, amt, hs, busy)
	_aft_soot(img, src, r, m, amt, hs, rg, busy)
	_cracks(img, src, r, m, amt, hs, rg, busy)


## The bells blacken back from the mouth, each row its own ragged length.
static func _bell_soot(img: Image, src: Image, r: HullGrade._Ramps, m: HullScars._Mask, at: Dictionary, amt: float, hs: int,
		busy: PackedByteArray) -> void:
	for b: Array in at.get("bells", []):
		var mx := int(b[0])
		for y in range(int(b[1]), int(b[2]) + 1):
			var span := int(round(20.0 * amt * (0.7 + 0.6 * _hs(mx, y, hs + 64))))
			for x in range(mx, mx + span):
				if x >= img.get_width() or img.get_pixel(x, y).a <= 0.0:
					continue
				var u := float(x - mx) / maxf(1.0, float(span))
				img.set_pixel(x, y, HullScars.down(r, src.get_pixel(x, y), 0.3 if u < 0.5 else 0.15))
				if m.ok(x, y):
					_take(busy, m, x, y)


## Soot streaks trailing aft from the ring's stern side, long at C and gone by S.
static func _aft_soot(img: Image, src: Image, r: HullGrade._Ramps, m: HullScars._Mask, amt: float, hs: int, rg: Rect2,
		busy: PackedByteArray) -> void:
	if rg.size.x <= 0.0:
		return
	var n := int(round(12.0 * amt))
	for i in n:
		var ang := PI * (0.72 + 0.56 * _hs(i, 1, hs + 71))
		var x0 := int(rg.position.x + cos(ang) * rg.size.x)
		var y0 := int(rg.position.y + sin(ang) * rg.size.y)
		var ln := int((20.0 + 40.0 * _hs(i, 2, hs + 71)) * amt)
		var wide := _hs(i, 3, hs + 71) < 0.7
		for dy in (2 if wide else 1):
			# the second row is shorter: a streak tapers
			var lr := ln if dy == 0 else int(float(ln) * 0.6)
			for k in lr:
				var x := x0 - k
				var y := y0 + dy
				if not m.ok(x, y):
					continue
				img.set_pixel(x, y, HullScars.down(r, src.get_pixel(x, y), 0.26 if k < lr * 2 / 3 else 0.12))
				_take(busy, m, x, y)


## Cracks out from the ring, a dark line with its lower lip lit; the nearest plate warped.
static func _cracks(img: Image, src: Image, r: HullGrade._Ramps, m: HullScars._Mask, amt: float, hs: int, rg: Rect2,
		busy: PackedByteArray) -> void:
	if rg.size.x <= 0.0:
		return
	var n := int(round(10.0 * amt))
	for i in n:
		var ang := _hs(i, 4, hs + 81) * TAU
		var p := Vector2(rg.position.x + cos(ang) * (rg.size.x + 1.0), rg.position.y + sin(ang) * (rg.size.y + 1.0))
		var dir := Vector2(cos(ang), sin(ang))
		var ln := 10 + int(_hs(i, 5, hs + 81) * 14.0)
		for k in ln:
			# a jagged walk: a pixel off the line every few steps
			var side := Vector2(-dir.y, dir.x) * (float(int(_hs(i, k, hs + 83) * 3.0)) - 1.0) * 0.8
			var q := p + dir * float(k) + side
			var x := int(round(q.x))
			var y := int(round(q.y))
			if not m.ok(x, y):
				continue
			img.set_pixel(x, y, HullScars.grey_at(r, 0.04))
			_take(busy, m, x, y)
			if m.ok(x, y + 1):
				img.set_pixel(x, y + 1, HullScars.up(r, src.get_pixel(x, y + 1), 0.2))
	# the warped plate: the one nearest the ring, buckled in bands
	if amt < 0.5:
		return
	var best: Array = []
	var bd := 1e9
	for pl: Array in HullScars.find_panels(src, m):
		var box: Rect2i = pl[2]
		var dd := (Vector2(box.get_center()) - rg.position).length()
		if dd < bd and dd > rg.size.x:
			bd = dd
			best = pl
	if best.is_empty():
		return
	var bx: Rect2i = best[2]
	for p: Vector2i in best[0]:
		var w := sin(float(p.x - bx.position.x) * 0.5 + float(p.y - bx.position.y) * 0.9)
		var c := src.get_pixel(p.x, p.y)
		if w > 0.45:
			img.set_pixel(p.x, p.y, HullScars.up(r, c, 0.1))
		elif w < -0.45:
			img.set_pixel(p.x, p.y, HullScars.down(r, c, 0.14))
		_take(busy, m, p.x, p.y)


# ------------------------------------------------------------------ B  patched junker

## Plates swapped for others in another bronze, welded in with a bead; rivet patches; a
## plate gone down to the ribs. With `busy`, only plates the heat left alone, and fewer.
static func patched(img: Image, base: Image, r: HullGrade._Ramps, m: HullScars._Mask, amt: float, hs: int,
		busy: PackedByteArray = PackedByteArray(), avoid: PackedByteArray = PackedByteArray()) -> void:
	var src := img.duplicate() as Image
	var mixed := not busy.is_empty()
	if mixed and amt < 0.5:
		return
	# which plates may be swapped is fixed by C's heat, so every grade picks from the same ones
	var foot := avoid if not avoid.is_empty() else busy
	var panels: Array[Array] = []
	for pl: Array in HullScars.find_panels(base, m):
		var px: Array = pl[0]
		var hit := 0
		var band := 0
		for p: Vector2i in px:
			if not _free(foot, m, p.x, p.y):
				hit += 1
			if r.is_accent(base.get_pixel(p.x, p.y)):
				band += 1
		# in the mix: the big plain plates, clear of the heat and off the band
		if mixed and (hit > px.size() / 20 or band > px.size() / 4 or px.size() < 120):
			continue
		panels.append(pl)
	panels.sort_custom(func(a: Array, b: Array) -> bool:
		return HullGrade.noise(a[1].x, a[1].y, hs) < HullGrade.noise(b[1].x, b[1].y, hs))
	var swaps := int(round(float(panels.size()) * (0.4 if mixed else 0.55) * amt))
	var torn_max := (1 if amt >= 1.0 else 0) if mixed else (2 if amt >= 1.0 else (1 if amt >= 0.5 else 0))
	var torn := 0
	for i in mini(swaps, panels.size()):
		var px: Array = panels[i][0]
		var box: Rect2i = panels[i][2]
		for p: Vector2i in px:
			_take(busy, m, p.x, p.y)
		if torn < torn_max and px.size() >= 60 and px.size() <= 500:
			torn += 1
			HullScars.torn(img, r, box, px)
			continue
		var inside := {}
		for p: Vector2i in px:
			inside[p] = true
		var warm := i % 2 == 0
		var dl: float = [0.18, -0.16, 0.12, -0.22][i % 4]
		for p: Vector2i in px:
			# the band's orange stays on a swapped plate: the manufacturer's colour is never lost
			var c0 := src.get_pixel(p.x, p.y)
			if not r.is_accent(c0):
				img.set_pixel(p.x, p.y, tone(r, c0, dl, warm))
		_weld(img, src, r, m, px, inside, busy)
	var n := int(round(float(HullScars.count_on(m, 6000.0 if not mixed else 9000.0)) * amt))
	for i in n:
		var sz := Vector2i(9 + int(_hs(i, 1, hs) * 6.0), 6 + int(_hs(i, 2, hs) * 3.0))
		var p := m.place(sz, hs + 600 + i)
		if p.x < 0:
			continue
		var clear := true
		for yy in range(p.y, p.y + sz.y):
			for xx in range(p.x, p.x + sz.x):
				if not _free(busy, m, xx, yy):
					clear = false
		if clear:
			HullScars.patch(img, r, m, Rect2i(p, sz), hs + i)
			for yy in range(p.y, p.y + sz.y):
				for xx in range(p.x, p.x + sz.x):
					_take(busy, m, xx, yy)


## The weld: a bead along the plate's top and stern edges (two lit pixels to a dark one,
## a run, never a checker) with a solid scorched line outside it.
static func _weld(img: Image, src: Image, r: HullGrade._Ramps, m: HullScars._Mask, px: Array, inside: Dictionary,
		busy: PackedByteArray) -> void:
	for p: Vector2i in px:
		var top := not inside.has(p + Vector2i(0, -1))
		var aft := not inside.has(p + Vector2i(-1, 0))
		if not (top or aft):
			continue
		var k := p.x if top else p.y
		var c := HullScars.up(r, src.get_pixel(p.x, p.y), 0.24) if k % 3 != 0 else HullScars.down(r, src.get_pixel(p.x, p.y), 0.1)
		img.set_pixel(p.x, p.y, c)
		var o := p + (Vector2i(0, -1) if top else Vector2i(-1, 0))
		if m.ok(o.x, o.y):
			img.set_pixel(o.x, o.y, HullScars.down(r, src.get_pixel(o.x, o.y), 0.12))
			_take(busy, m, o.x, o.y)


## A colour of another bronze: `dl` lighter or darker, and redder or yellower than `c`,
## from the hull's own colours.
static func tone(r: HullGrade._Ramps, c: Color, dl: float, warm: bool) -> Color:
	var want := HullGrade.luma(c) + dl
	var best := c
	var score := 1e9
	for g: Color in r.grey:
		var e := absf(HullGrade.luma(g) - want)
		if e > 0.05:
			continue
		# redder is a lower hue, yellower a higher one, among the browns
		var hue := g.h if g.h < 0.5 else g.h - 1.0
		var s2 := e * 4.0 + (hue if warm else -hue)
		if s2 < score:
			score = s2
			best = g
	return best


# ------------------------------------------------------------------ C  old bronze

## Patina gathered in the seams and on the lower plates, rust bled from the rivets, the
## band faded and chipped to the brass. With `busy`, only where nothing else has worn.
static func patina(img: Image, base: Image, r: HullGrade._Ramps, m: HullScars._Mask, amt: float, hs: int,
		busy: PackedByteArray = PackedByteArray()) -> void:
	var src := img.duplicate() as Image
	var sm := seams(base, m)
	# the seams fill and widen: the plate under and after each seam darkens, solid
	for y in range(1, m.h):
		for x in range(1, m.w):
			if not m.ok(x, y) or sm[y * m.w + x] == 1 or not _free(busy, m, x, y):
				continue
			var by_seam := sm[(y - 1) * m.w + x] == 1 or sm[y * m.w + x - 1] == 1
			var two := y > 1 and sm[(y - 2) * m.w + x] == 1
			if by_seam and amt >= 0.15:
				img.set_pixel(x, y, HullScars.down(r, src.get_pixel(x, y), 0.14 if amt >= 0.5 else 0.07))
			elif two and amt >= 0.5:
				img.set_pixel(x, y, HullScars.down(r, src.get_pixel(x, y), 0.07))
	# old bronze dulls from the belly up: a solid tide line, its top edge ragged
	for x in m.w:
		if m.top[x] < 0:
			continue
		var span := float(m.bottom[x] - m.top[x])
		var tide := 1.0 - amt + (blob(x, 0, 7, 1, hs + 97) - 0.5) * 0.25
		for y in range(m.top[x], m.bottom[x] + 1):
			if not m.ok(x, y) or not _free(busy, m, x, y):
				continue
			var low := (float(y - m.top[x]) / maxf(1.0, span) - 0.55) / 0.45
			if low > tide and amt > 0.0:
				img.set_pixel(x, y, HullScars.down(r, img.get_pixel(x, y), 0.08))
	# rust from the rivets: a run down from under each of some of them
	var rv := rivets(base, m)
	for i in rv.size():
		if _hs(rv[i].x, rv[i].y, hs + 91) > 0.55 * amt:
			continue
		var run := 3 + int(_hs(rv[i].x, rv[i].y, hs + 92) * 10.0 * amt)
		for k in range(1, run + 1):
			var x := rv[i].x
			var y := rv[i].y + k
			if not m.ok(x, y):
				break
			var c := src.get_pixel(x, y)
			img.set_pixel(x, y, HullScars.rust(r, c) if k < run * 2 / 3 + 1 else HullScars.rust(r, HullScars.up(r, c, 0.08)))
	_band_chips(img, src, r, m, amt, hs)


## The orange band faded a step, chipped to the brass in solid flakes and scratched.
static func _band_chips(img: Image, src: Image, r: HullGrade._Ramps, m: HullScars._Mask, amt: float, hs: int) -> void:
	for y in m.h:
		for x in m.w:
			var c := src.get_pixel(x, y)
			if c.a <= 0.0 or not r.is_accent(c):
				continue
			var out := r.step(c, -1) if amt >= 0.5 else c
			# flakes: solid blobs where the paint has gone to the brass
			if blob(x, y, 5, 4, hs + 95) < 0.36 * amt:
				out = r.to_grey(c)
			# scratches: thin diagonals down and aft
			elif (x + y * 2) % 11 == 0 and HullGrade.noise((x + y * 2) / 11, y / 6, hs + 96) < 0.5 * amt:
				out = r.to_grey(r.step(c, 1))
			img.set_pixel(x, y, out)


# ------------------------------------------------------------------ all three

## The three together, each in its place (Jon, Nov 20: "Can you do all three?"): the heat
## round the furnace, the line and the bells first; patches on the big plain plates it left;
## the bronze ageing in the seams, the rivets and the band where neither has been.
static func mixed(img: Image, base: Image, r: HullGrade._Ramps, m: HullScars._Mask, amt: float, hs: int, at: Dictionary) -> void:
	var busy := PackedByteArray()
	busy.resize(m.w * m.h)
	var foot := PackedByteArray()
	foot.resize(m.w * m.h)
	heat(img.duplicate() as Image, base, r, m, 0.8, hs, at, foot)
	heat(img, base, r, m, amt * 0.8, hs, at, busy)
	patched(img, base, r, m, amt, hs, busy, foot)
	patina(img, base, r, m, amt * 0.85, hs, busy)
