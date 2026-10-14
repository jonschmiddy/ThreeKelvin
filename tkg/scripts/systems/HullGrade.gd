class_name HullGrade
extends RefCounted

## ONE HULL PER WEIGHT, FOUR GRADES DRAWN FROM IT (Jon, Oct 14: "Instead of
## generating 12 ships per manufacturer. We just do Three... use shader code to
## modify each ship at each heaviness to make them more shitty (C tier)" or new
## looking at S).
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
static func bake(src: Image, grade: int, look: int, seed_in: int = 7, hull: String = "") -> Image:
	return bake_mix(src, grade, [look], seed_in, hull)


## More than one look on one hull (Jon: "the combinations of wear using A B and
## C"). Always in the same order whatever order they are asked in -- the paint
## the yard put on, then the age on top of the paint, then the light falling on
## all of it -- and every pass steps along the ramps read off the SOURCE, so a
## pass after the paint still knows the amber the paint took away.
## `hull` is the hull's key in art/hull_grade.json ("korvan/hull_medium_a"): the
## markings and the lights are placed by hand there, and a hull with no entry
## gets neither.
static func bake_mix(src: Image, grade: int, looks: Array, seed_in: int = 7, hull: String = "") -> Image:
	var img := src.duplicate() as Image
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var r := _Ramps.new(img)
	var at := places(hull)
	# the silhouette first, then the yard's paint, the age over it, the marks,
	# then the lights shining through the grime
	if Look.KIT in looks:
		_kit(img, r, grade, seed_in, at)
	if Look.PAINT in looks:
		_paint(img, r, grade, seed_in)
	if Look.WEAR in looks:
		_wear(img, r, AGE[grade], seed_in)
	# after the age: the S clean-up wipes lone pixels, and a stencil is made of them
	if Look.MARKS in looks:
		_marks(img, r, grade, seed_in, at)
	if Look.LIGHTS in looks:
		_lights(img, r, grade, at)
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
			# the manufacturer's colour is always still there (Jon, Oct 14)
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
## pulled from other hulls, and the manufacturer's colour dulled and worn through in
## patches -- never gone, because the band is how a manufacturer is known. B has its livery chipped
## (the amber dithered out where it would have worn). A is as the yard paints it.
## S adds a trim line in the manufacturer's colour along the hull's top edge.
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
					# THE MANUFACTURER'S COLOUR STAYS (Jon, Oct 14: "there should be SOME COLOR even
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


# --------------------------------------------------------- the hand placements

const PLACES_PATH := "res://art/hull_grade.json"
static var _places: Dictionary = {}

## A hull's hand-placed spots, or {} when it has none.
static func places(hull: String) -> Dictionary:
	if _places.is_empty() and FileAccess.file_exists(PLACES_PATH):
		var d = JSON.parse_string(FileAccess.get_file_as_string(PLACES_PATH))
		if d is Dictionary:
			_places = d
	return _places.get(hull, {})


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

## MARKINGS: the registry painted straight on the hull where its entry puts it
## (a plate behind it looked stuck on: Jon, "Can't we have it more integrated
## into the ship?"), in a grey that reads on that panel. Scraped at C (a few
## strokes left), faded through a dither at B, clean at A, fresh at S -- the
## lightest ink -- with two amber chevrons on the nose.
static func _marks(img: Image, r: _Ramps, grade: int, seed_in: int, at: Dictionary) -> void:
	if not at.has("registry"):
		return
	var reg: Array = at.registry
	var text := "K-%d%02d" % [2 + seed_in % 7, (seed_in * 37) % 100]
	var light := String(reg[2]) != "dark"
	var n := r.grey.size()
	var ink: Color = r.grey[int(n * (0.92 if grade == 3 else 0.78))] if light else r.grey[int(n * 0.08)]
	var cx := int(reg[0])
	var y0 := int(reg[1])
	for ch in text:
		var glyph: Array = STENCIL.get(ch, STENCIL["-"])
		for gy in 5:
			for gx in 3:
				if String(glyph[gy])[gx] != "1":
					continue
				var x := cx + gx
				var y := y0 + gy
				if not _inner(img, x, y):
					continue
				var on := true
				match grade:
					0: on = noise(x, y, seed_in + 11) < 0.3
					1: on = float(HullWear.BAYER[y % 4][x % 4]) / 16.0 < 0.55
				if on:
					img.set_pixel(x, y, ink)
		cx += 4
	if grade == 3 and at.has("chevrons") and not r.accent.is_empty():
		var amber: Color = r.accent[r.accent.size() / 2]
		var tip := Vector2i(int(at.chevrons[0]), int(at.chevrons[1]))
		for k in 2:
			var tx := tip.x - k * 6
			for d in 5:
				for t in 2:
					for p in [Vector2i(tx - d - t, tip.y - d), Vector2i(tx - d - t, tip.y + d)]:
						if _inner(img, p.x, p.y):
							img.set_pixel(p.x, p.y, amber)


# ------------------------------------------------------------------- E  lights

## RUNNING LIGHTS where the hull's entry puts them: its own dark glass (the
## ports' panes, the bridge windows) and the nav lights. Dead at C; at B a third
## of the panes and the white nose light; at A two thirds and every nav light; at
## S every pane. Lit panes are warm, in the manufacturer's colour. A nav light is
## 2x2 with a glow round it: the hull a step or two lighter along its own ramp,
## so the light spills without a colour the sprite does not have. Which panes
## light is fixed by their order, never rolled.
static func _lights(img: Image, r: _Ramps, grade: int, at: Dictionary) -> void:
	var warm := r.light_accent()
	var glass: Color = r.grey[0]
	var wins: Array = at.get("windows", [])
	for i in wins.size():
		var on := false
		match grade:
			1: on = i % 3 == 1
			2: on = i % 3 != 2
			3: on = true
		var w: Array = wins[i]
		for dy in int(w[3]):
			for dx in int(w[2]):
				var x := int(w[0]) + dx
				var y := int(w[1]) + dy
				if _opaque(img, x, y):
					img.set_pixel(x, y, warm if on else (glass if grade == 0 else img.get_pixel(x, y)))
	if grade == 0:
		return
	for nv in at.get("nav", []):
		var kind := String(nv[2])
		if grade == 1 and kind != "white":
			continue
		var c: Color = r.lightest_grey() if kind == "white" else warm
		var x0 := int(nv[0])
		var y0 := int(nv[1])
		# the glow first, one and two pixels out, then the light itself
		for dy in range(-2, 4):
			for dx in range(-2, 4):
				var x := x0 + dx
				var y := y0 + dy
				if not _opaque(img, x, y):
					continue
				var ring := maxi(maxi(-dx, dx - 1), maxi(-dy, dy - 1))
				if ring == 1:
					img.set_pixel(x, y, r.step(img.get_pixel(x, y), 2))
				elif ring == 2 and grade == 3:
					img.set_pixel(x, y, r.step(img.get_pixel(x, y), 1))
		for dy in 2:
			for dx in 2:
				if _opaque(img, x0 + dx, y0 + dy):
					img.set_pixel(x0 + dx, y0 + dy, c)


# ---------------------------------------------------------------------- F  kit

## KIT. Every thin thing standing proud of the hull's top edge -- masts,
## antennas, the small fittings on the roof and the nose -- is DETAIL, and the
## grades take it away: S is the sprite exactly as drawn, A loses the top third
## of each, B two thirds, C all of it. Nothing is ever drawn, only removed (Jon,
## Oct 14: "I don't want you to DRAW pixels for S. I want you to remove details
## towards C"). A thin thing: a column's top pixels while the row's run of
## opaque pixels through them is three wide or narrower.
static func _kit(img: Image, r: _Ramps, grade: int, seed_in: int, at: Dictionary) -> void:
	if grade >= 3:
		return
	var src := img.duplicate() as Image
	var w := src.get_width()
	var h := src.get_height()
	var keep: float = [0.0, 0.34, 0.67][grade]
	# every row's run widths, once: each pixel's run, 0 where clear
	var runs := PackedInt32Array()
	runs.resize(w * h)
	for y in h:
		var x0 := 0
		while x0 < w:
			if src.get_pixel(x0, y).a <= 0.0:
				x0 += 1
				continue
			var x1 := x0
			while x1 < w and src.get_pixel(x1, y).a > 0.0:
				x1 += 1
			for k in range(x0, x1):
				runs[y * w + k] = x1 - x0
			x0 = x1
	for x in w:
		var top := -1
		for y in h:
			if src.get_pixel(x, y).a > 0.0:
				top = y
				break
		if top < 0:
			continue
		var y := top
		while y < h and runs[y * w + x] > 0 and runs[y * w + x] <= 3:
			y += 1
		var n := y - top
		if n < 2:
			continue
		# cut from the top down, leaving the lower `keep` of it
		var cut := n - int(round(float(n) * keep))
		for k in cut:
			img.set_pixel(x, top + k, Color(0, 0, 0, 0))
