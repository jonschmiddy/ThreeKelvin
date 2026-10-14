class_name HullGrade
extends RefCounted

## ONE HULL PER WEIGHT, FOUR GRADES DRAWN FROM IT (Jon, Oct 14: "Instead of
## generating 12 ships per manufacturer. We just do Three... use shader code to
## modify each ship at each heaviness to make them more shitty (C tier) or brand
## new looking (S-tier)").
##
## A BAKE, NOT A LIVE SHADER: one pass per hull and grade, cached, so it costs a
## frame nothing, and every operation ends on a colour the sprite ALREADY HAS (a
## step along its own ramp, its amber turned to the grey of the same lightness,
## its own lightest colour) -- the ruling that generated art may not drift the
## palette holds by construction, as it does in HullWear, and `palette()` before
## and after can prove it.
##
## GRADE IS BUILD QUALITY, DAMAGE IS CONDITION. HullWear draws what the fights
## did, off hull points; this draws what the yard did. The three looks below are
## three ideas of what a C has that an S does not, on trial (Jon picks one):
##   A  wear:   age -- grime in the panels, drips under the seams, the amber faded
##   B  paint:  livery -- C in primer with odd panels, B chipped, S trimmed
##   C  finish: light -- C flat and dull, S crisp with lit edges and lit ports
## A is the one that leans on condition's register; that is a known risk against
## the "a class is a SPECIFICATION, not a condition" ruling, and why B and C exist.

enum Look { WEAR, PAINT, FINISH, MARKS, LIGHTS, KIT }
const LOOKS := {&"A": Look.WEAR, &"B": Look.PAINT, &"C": Look.FINISH,
	&"D": Look.MARKS, &"E": Look.LIGHTS, &"F": Look.KIT}
## C, B, A, S: how far from the yard's best each grade is (1 the worst).
const AGE := [1.0, 0.55, 0.2, 0.0]


## The graded copy. `grade` 0..3 is C..S. The source is never touched.
static func bake(src: Image, grade: int, look: int, seed_in: int = 7) -> Image:
	return bake_mix(src, grade, [look], seed_in)


## More than one look on one hull (Jon: "the combinations of wear using A B and
## C"). Always in the same order whatever order they are asked in -- the paint
## the yard put on, then the age on top of the paint, then the light falling on
## all of it -- and every pass steps along the ramps read off the SOURCE, so a
## pass after the paint still knows the amber the paint took away.
static func bake_mix(src: Image, grade: int, looks: Array, seed_in: int = 7) -> Image:
	var img := src.duplicate() as Image
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var r := _Ramps.new(img)
	# the silhouette first, then the yard's paint, the age over it, the marks,
	# then the lights shining through the grime
	if Look.KIT in looks:
		_kit(img, r, grade, seed_in)
	if Look.PAINT in looks:
		_paint(img, r, grade, seed_in)
	if Look.WEAR in looks:
		_wear(img, r, AGE[grade], seed_in)
	# after the age: the S clean-up wipes lone pixels, and a stencil is made of them
	if Look.MARKS in looks:
		_marks(img, r, grade, seed_in)
	if Look.LIGHTS in looks:
		_lights(img, r, grade, seed_in)
	if Look.FINISH in looks:
		_finish(img, r, grade, seed_in)
	return img


# ------------------------------------------------------------------- the ramps

## The sprite's own colours, split into its greys and its accent (Korvan's
## amber), each sorted dark to light. Every move below is along one of these.
class _Ramps extends RefCounted:
	var grey: Array = []
	var accent: Array = []
	var _where := {}           ## colour key -> [is_accent, index]

	func _init(img: Image) -> void:
		var seen := {}
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a > 0.0:
					seen[HullGrade.key(c)] = c
		for k in seen:
			var c: Color = seen[k]
			if c.s > 0.28 and c.v > 0.25:
				accent.append(c)
			else:
				grey.append(c)
		var by := func(a: Color, b: Color) -> bool: return HullGrade.luma(a) < HullGrade.luma(b)
		grey.sort_custom(by)
		accent.sort_custom(by)
		for i in grey.size():
			_where[HullGrade.key(grey[i])] = [false, i]
		for i in accent.size():
			_where[HullGrade.key(accent[i])] = [true, i]

	func is_accent(c: Color) -> bool:
		var w = _where.get(HullGrade.key(c))
		return w != null and w[0]

	## `k` steps lighter (or darker, negative) along the colour's own ramp.
	func step(c: Color, k: int) -> Color:
		var w = _where.get(HullGrade.key(c))
		if w == null:
			return c
		var ramp: Array = accent if w[0] else grey
		return ramp[clampi(int(w[1]) + k, 0, ramp.size() - 1)]

	## The grey of the same lightness: an accent with its paint gone.
	func to_grey(c: Color) -> Color:
		var best: Color = c
		var d := 9.0
		for g in grey:
			var e := absf(HullGrade.luma(g) - HullGrade.luma(c))
			if e < d:
				d = e
				best = g
		return best

	## Toward the middle of its ramp by `t` (0 none, 1 all the way): a dull finish.
	func flatten(c: Color, t: float) -> Color:
		var w = _where.get(HullGrade.key(c))
		if w == null:
			return c
		var ramp: Array = accent if w[0] else grey
		var mid := (ramp.size() - 1) * 0.5
		var i := int(round(lerpf(float(w[1]), mid, t)))
		return ramp[clampi(i, 0, ramp.size() - 1)]

	func lightest_grey() -> Color:
		return grey[grey.size() - 1]

	func light_accent() -> Color:
		return accent[accent.size() - 1] if not accent.is_empty() else lightest_grey()


static func key(c: Color) -> int:
	return (int(c.r * 255.0) << 16) | (int(c.g * 255.0) << 8) | int(c.b * 255.0)


static func luma(c: Color) -> float:
	return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b


## A stable 0..1 per cell, so a grade looks the same every time it is drawn.
static func noise(x: int, y: int, seed_in: int) -> float:
	var h := (x * 374761393 + y * 668265263 + seed_in * 2147483647) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float(h & 0xffff) / 65535.0


static func _opaque(img: Image, x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height() \
		and img.get_pixel(x, y).a > 0.0


## A pixel inside the hull: opaque, with opaque on all four sides (no outline).
static func _inner(img: Image, x: int, y: int) -> bool:
	return _opaque(img, x, y) and _opaque(img, x - 1, y) and _opaque(img, x + 1, y) \
		and _opaque(img, x, y - 1) and _opaque(img, x, y + 1)


# --------------------------------------------------------------------- A  wear

## AGE. Grime settles in blotches a few pixels across, dark drips run down from
## under the seams (a seam: a pixel clearly darker than the one above it), and
## the amber dulls in patches, worn through to the grey in a few. An S is the sprite cleaned: the single
## stray speckles (a pixel unlike both its neighbours) are wiped.
static func _wear(img: Image, r: _Ramps, age: float, seed_in: int) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var src := img.duplicate() as Image
	if age <= 0.0:
		for y in h:
			for x in range(1, w - 1):
				if not _inner(src, x, y):
					continue
				var c := src.get_pixel(x, y)
				var a := src.get_pixel(x - 1, y)
				var b := src.get_pixel(x + 1, y)
				if key(a) == key(b) and key(c) != key(a) and absf(luma(c) - luma(a)) > 0.08:
					img.set_pixel(x, y, a)
		return
	for y in h:
		for x in w:
			if not _inner(src, x, y):
				continue
			var c := src.get_pixel(x, y)
			# grime: 3x2 blotches, with a speckled edge
			var blot := noise(x / 3, y / 2, seed_in)
			if blot < age * 0.18:
				c = r.step(c, -2)
			elif blot < age * 0.45 and noise(x, y, seed_in + 1) < 0.8:
				c = r.step(c, -1)
			# the amber dulls in patches and wears through to the grey in a few:
			# the house colour is always still there (Jon, Oct 14)
			if r.is_accent(c):
				var f := noise(x / 4, y / 3, seed_in + 2)
				if f < age * 0.22:
					c = r.to_grey(c)
				elif f < age * 0.7:
					c = r.step(c, -1)
			img.set_pixel(x, y, c)
	# drips: down from under a seam, a few pixels, thinning out
	for y in range(1, h):
		for x in w:
			if not _inner(src, x, y):
				continue
			var above := src.get_pixel(x, y - 1)
			var here := src.get_pixel(x, y)
			if luma(here) > luma(above) - 0.12:
				continue
			if noise(x, y, seed_in + 3) > age * 0.32:
				continue
			var run := 2 + int(noise(x, y, seed_in + 4) * 8.0 * age)
			for k in range(1, run + 1):
				if not _inner(src, x, y + k):
					break
				if k > 2 and noise(x, y + k, seed_in + 5) < 0.35:
					break
				img.set_pixel(x, y + k, r.step(img.get_pixel(x, y + k), -1))


# -------------------------------------------------------------------- B  paint

## LIVERY. C is in primer: a few panels two shades off their neighbours, as if
## pulled from other hulls, and the house colour dulled and worn through in
## patches -- never gone, because the band is how a manufacturer is known. B has its livery chipped
## (the amber dithered out where it would have worn). A is as the yard paints it.
## S adds a trim line in the house colour along the hull's top edge.
static func _paint(img: Image, r: _Ramps, grade: int, seed_in: int) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var src := img.duplicate() as Image
	for y in h:
		for x in w:
			if not _inner(src, x, y):
				continue
			var c := src.get_pixel(x, y)
			match grade:
				0:
					# THE HOUSE COLOUR STAYS (Jon, Oct 14: "there should be SOME COLOR even
					# at C class. The color of the bands is really important for
					# manufacturer identity"): a shade darker and worn through to the
					# grey in patches, never gone
					if r.is_accent(c):
						if noise(x / 3, y / 3, seed_in + 7) < 0.35:
							c = r.to_grey(c)
						else:
							c = r.step(c, -1)
					# mismatched panels: 12x8 cells, two shades either way
					var p := noise(x / 12, y / 8, seed_in)
					if p < 0.2:
						c = r.step(c, -2)
					elif p > 0.8:
						c = r.step(c, 2)
				1:
					if r.is_accent(c):
						var d: int = HullWear.BAYER[y % 4][x % 4]
						if float(d) / 16.0 < 0.45 * noise(x / 3, y / 3, seed_in + 6) + 0.1:
							c = r.to_grey(c)
			img.set_pixel(x, y, c)
	if grade == 3 and not r.accent.is_empty():
		# the trim: the second row under the top edge, along every column
		var trim: Color = r.accent[r.accent.size() / 2]
		for x in w:
			var top := -1
			for y in h:
				if src.get_pixel(x, y).a > 0.0:
					top = y
					break
			if top < 0:
				continue
			var y2 := top + 2
			if _inner(src, x, y2) and _inner(src, x, y2 + 1):
				img.set_pixel(x, y2, trim)


# ------------------------------------------------------------------- C  finish

## LIGHT. C is flat: every colour pulled toward the middle of its ramp, so the
## shapes go soft and the ship reads as matte and tired. B a little less, A as
## drawn. S is crisp: every colour pushed away from the middle of its ramp (more
## contrast), and the top edge catches the light (its own lightest grey). Lit
## ports were tried and read as specks at game size.
static func _finish(img: Image, r: _Ramps, grade: int, seed_in: int) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var src := img.duplicate() as Image
	var flat: float = [0.55, 0.3, 0.0, 0.0][grade]
	if flat > 0.0:
		for y in h:
			for x in w:
				if _inner(src, x, y):
					img.set_pixel(x, y, r.flatten(src.get_pixel(x, y), flat))
		return
	if grade < 3:
		return
	for y in h:
		for x in w:
			if _inner(src, x, y):
				img.set_pixel(x, y, r.flatten(src.get_pixel(x, y), -0.22))
	var hi := r.lightest_grey()
	for x in w:
		for y in h:
			if not _inner(src, x, y):
				continue
			if not _opaque(src, x, y - 2):
				# the edge catching the light, every pixel but a broken few
				if noise(x, y, seed_in + 8) < 0.85:
					img.set_pixel(x, y, hi)
				break


# -------------------------------------------------------------------- D  marks

## A 3x5 stencil for the registry: K, a dash and the digits.
const STENCIL := {
	"K": ["1.1", "11.", "1..", "11.", "1.1"], "-": ["...", "...", "111", "...", "..."],
	"0": ["111", "1.1", "1.1", "1.1", "111"], "1": [".1.", "11.", ".1.", ".1.", "111"],
	"2": ["111", "..1", "111", "1..", "111"], "3": ["111", "..1", ".11", "..1", "111"],
	"4": ["1.1", "1.1", "111", "..1", "..1"], "5": ["111", "1..", "111", "..1", "111"],
	"6": ["111", "1..", "111", "1.1", "111"], "7": ["111", "..1", ".1.", ".1.", ".1."],
	"8": ["111", "1.1", "111", "1.1", "111"], "9": ["111", "1.1", "111", "..1", "111"],
}

## MARKINGS. A registry stencilled on the flank in the hull's own lightest grey,
## where the hull is plain enough to take it, and amber chevrons near the nose.
## C has had its numbers scraped (a few strokes left), B's are faded through a
## dither, A's are whole, S has them whole and the chevrons too.
static func _marks(img: Image, r: _Ramps, grade: int, seed_in: int) -> void:
	var box := img.get_used_rect()
	var text := "K-%d%02d" % [2 + seed_in % 7, (seed_in * 37) % 100]
	var tw := text.length() * 4 - 1
	# the plainest 5-row patch on the upper flank (42-58% down the hull, clear
	# of the nose): most inner pixels, least change from pixel to pixel
	var best := Vector2i(-1, -1)
	var best_score := -1.0
	var y0 := box.position.y + int(box.size.y * 0.42)
	var y1 := box.position.y + int(box.size.y * 0.58)
	for y in range(y0, maxi(y0 + 1, y1 - 5)):
		for x in range(box.position.x + 6, box.end.x - box.size.x / 6 - tw, 2):
			var ok := 0
			var calm := 0
			for dy in 5:
				for dx in tw:
					if _inner(img, x + dx, y + dy):
						ok += 1
						var c := img.get_pixel(x + dx, y + dy)
						if key(c) == key(img.get_pixel(x + dx + 1, y + dy)):
							calm += 1
			var score := float(ok) + float(calm) * 0.5
			if ok == 5 * tw and score > best_score:
				best_score = score
				best = Vector2i(x, y)
	if best.x < 0:
		return
	# dark stencil on light metal, light on dark
	var under := luma(img.get_pixel(best.x + tw / 2, best.y + 2))
	var ink: Color = r.grey[0] if under > 0.45 else r.lightest_grey()
	var keep: float = [0.25, 0.55, 1.0, 1.0][grade]
	var cx := best.x
	for ch in text:
		var glyph: Array = STENCIL.get(ch, STENCIL["-"])
		for gy in 5:
			for gx in 3:
				if String(glyph[gy])[gx] != "1":
					continue
				var px := cx + gx
				var py := best.y + gy
				var on := true
				if grade == 0:
					on = noise(px, py, seed_in + 11) < keep
				elif grade == 1:
					on = float(HullWear.BAYER[py % 4][px % 4]) / 16.0 < keep
				if on:
					img.set_pixel(px, py, ink)
		cx += 4
	if grade == 3 and not r.accent.is_empty():
		_chevrons(img, r, box)


## Three amber chevrons pointing forward, on the flank behind the nose.
static func _chevrons(img: Image, r: _Ramps, box: Rect2i) -> void:
	var amber: Color = r.accent[r.accent.size() / 2]
	var mid := box.position.y + box.size.y / 2
	var x0 := box.end.x - box.size.x / 5
	for k in 3:
		var x := x0 - k * 6
		for d in 4:
			for p in [Vector2i(x + d, mid - 3 + d), Vector2i(x + d, mid + 3 - d),
					Vector2i(x + d + 1, mid - 3 + d), Vector2i(x + d + 1, mid + 3 - d)]:
				if _inner(img, p.x, p.y):
					img.set_pixel(p.x, p.y, amber)


# ------------------------------------------------------------------- E  lights

## RUNNING LIGHTS. The hull's own window slots (runs of three or more of its
## darkest pixels with lighter metal above and below) and its nose light: dead
## at C, a few lit at B, most at A, every one at S, in the house colour.
static func _lights(img: Image, r: _Ramps, grade: int, seed_in: int) -> void:
	var lit := r.light_accent()
	var frac: float = [0.0, 0.3, 0.65, 1.0][grade]
	var w := img.get_width()
	var h := img.get_height()
	var src := img.duplicate() as Image
	var slot := func(x: int, y: int) -> bool:
		if not _inner(src, x, y):
			return false
		var l := luma(src.get_pixel(x, y))
		return luma(src.get_pixel(x, y - 1)) > l + 0.14 and luma(src.get_pixel(x, y + 1)) > l + 0.14
	for y in h:
		var x := 0
		while x < w:
			if not slot.call(x, y):
				x += 1
				continue
			var x1 := x
			while x1 < w and slot.call(x1, y):
				x1 += 1
			var n := x1 - x
			var framed := n >= 2 and n <= 7
			if framed and noise(x, y, seed_in + 12) < frac:
				for k in n:
					img.set_pixel(x + k, y, lit)
			x = x1
	if grade >= 2:
		# the nose light: the hull's forward-most pixel on its middle row
		var box := src.get_used_rect()
		var mid := box.position.y + box.size.y / 2
		for xx in range(box.end.x - 1, box.position.x, -1):
			if _inner(src, xx, mid):
				img.set_pixel(xx, mid, lit)
				break


# ---------------------------------------------------------------------- F  kit

## KIT. The thin things on top -- masts and antennas, a pixel or two wide with
## nothing beside them -- cut off at C and halved at B; at A as drawn; at S
## four pixels taller each, with an amber beacon on the tallest.
static func _kit(img: Image, r: _Ramps, grade: int, seed_in: int) -> void:
	var src := img.duplicate() as Image
	var w := src.get_width()
	var masts: Array = []      ## [x, top, base]
	for x in w:
		var top := -1
		for y in src.get_height():
			if src.get_pixel(x, y).a > 0.0:
				top = y
				break
		if top < 0:
			continue
		var y := top
		while y < src.get_height() and src.get_pixel(x, y).a > 0.0 \
				and not _opaque(src, x - 1, y) and not _opaque(src, x + 1, y):
			y += 1
		if y - top >= 3:
			masts.append([x, top, y])
	if masts.is_empty():
		return
	match grade:
		0, 1:
			for m in masts:
				var keep := 0 if grade == 0 else (int(m[2]) - int(m[1])) / 2
				for y in range(int(m[1]), int(m[2]) - keep):
					img.set_pixel(int(m[0]), y, Color(0, 0, 0, 0))
		3:
			var tallest: Array = masts[0]
			for m in masts:
				var c := src.get_pixel(int(m[0]), int(m[1]))
				for k in range(1, 5):
					if int(m[1]) - k >= 0:
						img.set_pixel(int(m[0]), int(m[1]) - k, c)
				if int(m[2]) - int(m[1]) > int(tallest[2]) - int(tallest[1]):
					tallest = m
			if not r.accent.is_empty() and int(tallest[1]) - 5 >= 0:
				img.set_pixel(int(tallest[0]), int(tallest[1]) - 5, r.light_accent())
