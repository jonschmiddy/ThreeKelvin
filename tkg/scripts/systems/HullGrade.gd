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

enum Look { WEAR, PAINT, MARKS, LIGHTS, KIT }
const LOOKS := {&"A": Look.WEAR, &"B": Look.PAINT, &"D": Look.MARKS, &"E": Look.LIGHTS, &"F": Look.KIT}
## WHAT SHIPS (Jon, Oct 14: "AB+DEF"). A finish-and-light look (C) was tried
## and cut ("kinda sucks"); git has it.
const SHIPPED := [Look.WEAR, Look.PAINT, Look.MARKS, Look.LIGHTS, Look.KIT]
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
	_band(img, hull)
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
			# warm only: a navy grey is saturated too (the light and heavy
			# sprites' shadow side is #2f3348), and was being worn as if it
			# were the band. Korvan's band is amber; another manufacturer's
			# band hue goes here when it has one.
			if c.s > 0.28 and c.v > 0.25 and (c.h < 0.17 or c.h > 0.95):
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

	## The grey nearest `dl` lighter (or darker) than this colour: a fixed step
	## in lightness, where `step` is a step along a ramp whose shades may be
	## crowded together.
	func lift(c: Color, dl: float) -> Color:
		var want := HullGrade.luma(c) + dl
		var best: Color = c
		var d := 9.0
		for g in grey:
			var e := absf(HullGrade.luma(g) - want)
			if e < d:
				d = e
				best = g
		return best

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


## The same field, but soft: `noise` at the corners of `sx` x `sy` cells,
## eased between, so a threshold on it cuts round patches rather than a checker
## of cells (Jon, Oct 14: "All of the C tiers should have a degraded band, but
## have it be less pixelated").
static func smooth(x: int, y: int, sx: int, sy: int, seed_in: int) -> float:
	var gx := floori(float(x) / sx)
	var gy := floori(float(y) / sy)
	var fx := float(x - gx * sx) / sx
	var fy := float(y - gy * sy) / sy
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var a := lerpf(noise(gx, gy, seed_in), noise(gx + 1, gy, seed_in), fx)
	var b := lerpf(noise(gx, gy + 1, seed_in), noise(gx + 1, gy + 1, seed_in), fx)
	return lerpf(a, b, fy)


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
			# the amber dulls in patches and wears through to the grey in a few:
			# the manufacturer's colour is always still there (Jon, Oct 14).
			# Soft patches, no speckle: on the band a checker of cells read as
			# pixelation, not as paint worn off
			if r.is_accent(c):
				var f := smooth(x, y, 6, 5, seed_in + 2)
				if f < age * 0.2:
					c = r.to_grey(c)
				elif f < age * 0.62:
					c = r.step(c, -1)
				img.set_pixel(x, y, c)
				continue
			# grime: 3x2 blotches, with a speckled edge
			var blot := noise(x / 3, y / 2, seed_in)
			if blot < age * 0.18:
				c = r.step(c, -2)
			elif blot < age * 0.45 and noise(x, y, seed_in + 1) < 0.8:
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
						if smooth(x, y, 7, 6, seed_in + 7) < 0.3:
							c = r.to_grey(c)
						else:
							c = r.step(c, -1)
						img.set_pixel(x, y, c)
						continue
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


# ------------------------------------------------------------------- the band

## THE MANUFACTURER'S BAND IN ITS OWN AMBER on every weight (Jon, Oct 14: "can
## we make the orange band ... as vibrantly orange as the medium?"). Today's
## light and heavy sprites were generated apart and their band came out a
## duller, browner orange, with its lower half in shadow. The band's colours
## are the manufacturer's, so they are read off one sprite (the medium's) and
## every other hull's band is put onto them by lightness. The palette lock
## still holds, against the sprite's own colours AND the manufacturer's ramp.
const BAND_FROM := {"korvan": "res://art/sprites/hulls/korvan/hull_medium_a.png"}
## A warm run smaller than this is a rust speck, not the band, and keeps its colour.
const BAND_MIN := 40
static var _band_ramps: Dictionary = {}


## The manufacturer's band colours, dark to light, or [] for a hull with none.
static func band_ramp(hull: String) -> Array:
	var who := hull.get_slice("/", 0)
	if not BAND_FROM.has(who):
		return []
	if not _band_ramps.has(who):
		var img := (load(BAND_FROM[who]) as Texture2D).get_image()
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		_band_ramps[who] = _Ramps.new(img).accent
	return _band_ramps[who]


static func _band(img: Image, hull: String) -> void:
	var ramp := band_ramp(hull)
	if ramp.size() < 3 or hull == "" or BAND_FROM[hull.get_slice("/", 0)].ends_with(hull.get_slice("/", 1) + ".png"):
		return
	var own := _Ramps.new(img).accent
	if own.size() < 2:
		return
	var lo := luma(own[0])
	var hi := luma(own[own.size() - 1])
	# own lightest onto the ramp's face colour (one under its highlight), own
	# darkest onto its second step; the curve lifts the shaded half, which is
	# what made the band read dull
	var t_lo := luma(ramp[1])
	var t_hi := luma(ramp[ramp.size() - 2])
	var to := {}
	for c: Color in own:
		var t := pow(clampf((luma(c) - lo) / maxf(hi - lo, 0.001), 0.0, 1.0), 0.6)
		var want := lerpf(t_lo, t_hi, t)
		var best: Color = ramp[0]
		for rc: Color in ramp:
			if absf(luma(rc) - want) < absf(luma(best) - want):
				best = rc
		to[key(c)] = best
	# only runs big enough to be the band: 4-connected, over the warm pixels
	var w := img.get_width()
	var h := img.get_height()
	var seen := PackedByteArray()
	seen.resize(w * h)
	for y0 in h:
		for x0 in w:
			if seen[y0 * w + x0] or not to.has(key(img.get_pixel(x0, y0))) or img.get_pixel(x0, y0).a <= 0.0:
				continue
			var run: Array[Vector2i] = [Vector2i(x0, y0)]
			seen[y0 * w + x0] = 1
			var i := 0
			while i < run.size():
				var p := run[i]
				i += 1
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var q := p + d
					if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h or seen[q.y * w + q.x]:
						continue
					var cq := img.get_pixel(q.x, q.y)
					if cq.a > 0.0 and to.has(key(cq)):
						seen[q.y * w + q.x] = 1
						run.append(q)
			if run.size() < BAND_MIN:
				continue
			for p: Vector2i in run:
				img.set_pixel(p.x, p.y, to[key(img.get_pixel(p.x, p.y))])


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
## THE REGISTRY'S LOOK, on trial (Jon, Oct 15: "THE TEXT PLACEMENT HERE LOOKS
## BAD AND PRINTED ON", of the white number on L1 and H3): "" the white stencil
## as it was; &"A" tone on tone, each stroke the panel under it two shades
## lighter; &"B" the number alone, in dark paint across the band; &"C" no
## number. A pick page sets it; the game keeps "" until Jon picks.
static var reg_look: StringName = &""


static func _marks(img: Image, r: _Ramps, grade: int, seed_in: int, at: Dictionary) -> void:
	if not at.has("registry") or reg_look == &"C":
		_chevrons(img, r, grade, at)
		return
	var reg: Array = at.registry
	var num := "%d%02d" % [2 + seed_in % 7, (seed_in * 37) % 100]
	var light := String(reg[2]) != "dark"
	var n := r.grey.size()
	var ink: Color = r.grey[int(n * (0.92 if grade == 3 else 0.78))] if light else r.grey[int(n * 0.08)]
	# where each glyph goes: in a row from the placement, or stacked down the band
	var cells: Array = []
	if reg_look == &"B":
		var band := _band_box(img, r)
		if band.size.x < 3:
			_chevrons(img, r, grade, at)
			return
		# across the band's biggest piece, in the middle of it
		var x0 := band.position.x + (band.size.x - 11) / 2
		var y0b := band.position.y + (band.size.y - 5) / 2
		for i in num.length():
			cells.append([num[i], Vector2i(x0 + i * 4, y0b)])
		ink = r.accent[0] if not r.accent.is_empty() else r.grey[0]
	else:
		var cx := int(reg[0])
		for ch in "K-" + num:
			cells.append([ch, Vector2i(cx, int(reg[1]))])
			cx += 4
	var src := img.duplicate() as Image
	for cell in cells:
		var glyph: Array = STENCIL.get(cell[0], STENCIL["-"])
		var at0: Vector2i = cell[1]
		for gy in 5:
			for gx in 3:
				if String(glyph[gy])[gx] != "1":
					continue
				var x := at0.x + gx
				var y := at0.y + gy
				if not _inner(img, x, y):
					continue
				# on the band, only where the band is (it reads painted on it)
				if reg_look == &"B" and not r.is_accent(src.get_pixel(x, y)):
					continue
				var on := true
				match grade:
					0: on = noise(x, y, seed_in + 11) < 0.3
					1: on = float(HullWear.BAYER[y % 4][x % 4]) / 16.0 < 0.55
				if not on:
					continue
				if reg_look == &"A":
					img.set_pixel(x, y, r.lift(src.get_pixel(x, y), 0.1 if light else -0.1))
				else:
					img.set_pixel(x, y, ink)
	_chevrons(img, r, grade, at)


## The band's box: the biggest run of the manufacturer's colour.
static func _band_box(img: Image, r: _Ramps) -> Rect2i:
	var w := img.get_width()
	var h := img.get_height()
	var seen := PackedByteArray()
	seen.resize(w * h)
	var best := Rect2i()
	var best_n := 0
	for y0 in h:
		for x0 in w:
			if seen[y0 * w + x0] or img.get_pixel(x0, y0).a <= 0.0 or not r.is_accent(img.get_pixel(x0, y0)):
				continue
			var run: Array[Vector2i] = [Vector2i(x0, y0)]
			seen[y0 * w + x0] = 1
			var i := 0
			var box := Rect2i(x0, y0, 1, 1)
			while i < run.size():
				var p := run[i]
				i += 1
				box = box.expand(p).expand(p + Vector2i.ONE)
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var q := p + d
					if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h or seen[q.y * w + q.x]:
						continue
					if img.get_pixel(q.x, q.y).a > 0.0 and r.is_accent(img.get_pixel(q.x, q.y)):
						seen[q.y * w + q.x] = 1
						run.append(q)
			if run.size() > best_n:
				best_n = run.size()
				best = box
	return best


static func _chevrons(img: Image, r: _Ramps, grade: int, at: Dictionary) -> void:
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
	var glass: Color = r.grey[0]
	var wins: Array = at.get("windows", [])
	var amb := r.accent
	for i in wins.size():
		var on := _lit(i, grade)
		var w: Array = wins[i]
		var ww := int(w[2])
		for dy in int(w[3]):
			for dx in ww:
				var x := int(w[0]) + dx
				var y := int(w[1]) + dy
				if not _opaque(img, x, y):
					continue
				# a shaped pane: only its dark glass inside the box
				if w.size() > 4 and String(w[4]) == "glass" and luma(img.get_pixel(x, y)) > 0.2:
					continue
				if not on:
					if grade == 0:
						img.set_pixel(x, y, glass)
					continue
				# a lit pane is brightest in its middle, deeper amber at its ends
				var edge := dx == 0 or dx == ww - 1
				var c: Color = amb[amb.size() - 1] if not edge or ww <= 2 else amb[maxi(0, amb.size() - 3)]
				img.set_pixel(x, y, c)
	if grade == 0:
		return
	for nv in at.get("nav", []):
		if not _nav_on(String(nv[2]), grade):
			continue
		var c: Color = r.lightest_grey() if String(nv[2]) == "white" else r.light_accent()
		for dy in 2:
			for dx in 2:
				if _opaque(img, int(nv[0]) + dx, int(nv[1]) + dy):
					img.set_pixel(int(nv[0]) + dx, int(nv[1]) + dy, c)
	for mk in at.get("markers", []):
		if _marker_on(String(mk[3]), grade) and _opaque(img, int(mk[0]), int(mk[1])):
			img.set_pixel(int(mk[0]), int(mk[1]), r.lightest_grey() if String(mk[2]) == "white" else r.light_accent())


## Which panes light at a grade: fixed by their order, never rolled.
static func _lit(i: int, grade: int) -> bool:
	match grade:
		1: return i % 3 == 1
		2: return i % 3 != 2
		3: return true
	return false


## Surface markers, an aircraft's: on the hull at A and S; on a tip the kit
## trims below S, at S alone.
static func _marker_on(where: String, grade: int) -> bool:
	return grade == 3 or (grade == 2 and where == "hull")


static func _nav_on(kind: String, grade: int) -> bool:
	if kind == "beacon":
		return grade == 3
	return grade >= 2 or (grade == 1 and kind == "white")


## THE GLOW, which the bake cannot make: a light is brighter than any colour the
## hull has, so it is a separate layer added over the hull where it is drawn
## (ThrusterFx.add_material, the flames' own blend), the one thing here off the
## palette, as a flame is. Three stepped rings round every lit pane and nav
## light, pixel-sharp, fading out (two round a surface marker); a hull with no
## entry gets none. `dy` moves it
## with a bake that moved the hull. Jon: "The lights look just like rectangular
## pixels."
const GLOW := [0.55, 0.28, 0.12]
## THE LIGHTS LIVE (Jon: "Can the lights on the surface flicker?"). `t` is
## the game clock in seconds; -1 draws every light at rest (a still, a test).
## A surface marker strobes: a short flash every 1.2-1.6 s on its own beat, a
## white one twice. The masthead beacon swells and fades once a second and a
## half. A window is steady, but now and then dips for a moment, as if someone
## crossed in front of it. Nav lights are steady, as a ship's are.
static func level(kind: String, i: int, t: float) -> float:
	if t < 0.0:
		return 1.0
	var ph := noise(i, 17, 31) * 10.0
	match kind:
		"marker_white", "marker_amber":
			var period := 1.2 + noise(i, 3, 7) * 0.4
			var u := fposmod(t + ph, period)
			if u < 0.08:
				return 1.0
			if kind == "marker_white" and u > 0.18 and u < 0.26:
				return 1.0
			return 0.0
		"beacon":
			return 0.25 + 0.75 * pow(0.5 + 0.5 * sin((t + ph) * TAU / 1.5), 2.0)
		"window":
			# a dip: 0.15 s at 55%, roughly once every eight seconds a pane
			var k := floori((t + ph) / 8.0)
			var at := noise(i, k, 5) * 7.5
			var u2 := fposmod(t + ph, 8.0)
			return 0.55 if u2 > at and u2 < at + 0.15 else 1.0
	return 1.0


static func light_layer(size: Vector2i, grade: int, hull: String, t: float = -1.0) -> Image:
	var out := Image.create(size.x, size.y, false, Image.FORMAT_RGBAF)
	var acc := light_layer_sparse(grade, hull, t)
	for p in acc:
		if p.x >= 0 and p.y >= 0 and p.x < size.x and p.y < size.y:
			out.set_pixel(p.x, p.y, acc[p])
	return out


## Every lit thing at a grade and time: [Rect2i, colour, glow reach, level].
static func _spots(grade: int, hull: String, t: float) -> Array:
	var spots: Array = []
	var at := places(hull)
	if grade == 0 or at.is_empty():
		return spots
	var warm := Color(1.0, 0.72, 0.32)
	var white := Color(0.95, 0.97, 1.0)
	var wins: Array = at.get("windows", [])
	for i in wins.size():
		if _lit(i, grade):
			var w: Array = wins[i]
			spots.append([Rect2i(int(w[0]), int(w[1]), int(w[2]), int(w[3])), warm, GLOW.size(), level("window", i, t)])
	var navs: Array = at.get("nav", [])
	for i in navs.size():
		var nv: Array = navs[i]
		if _nav_on(String(nv[2]), grade):
			var lv := level("beacon", i, t) if String(nv[2]) == "beacon" else 1.0
			spots.append([Rect2i(int(nv[0]), int(nv[1]), 2, 2), white if String(nv[2]) == "white" else warm, GLOW.size(), lv])
	var marks: Array = at.get("markers", [])
	for i in marks.size():
		var mk: Array = marks[i]
		if _marker_on(String(mk[3]), grade):
			spots.append([Rect2i(int(mk[0]), int(mk[1]), 1, 1), white if String(mk[2]) == "white" else warm, 2,
				level("marker_" + String(mk[2]), i, t)])
	return spots


## The hull with its light layer added, as the game draws them together: for a
## still, a film or a test, never for the palette check (the glow is light).
static func lit(baked: Image, grade: int, hull: String, t: float = -1.0) -> Image:
	var glow := light_layer(baked.get_size(), grade, hull, t)
	var out := baked.duplicate() as Image
	for y in out.get_height():
		for x in out.get_width():
			var g := glow.get_pixel(x, y)
			if g.r + g.g + g.b <= 0.0:
				continue
			var c := out.get_pixel(x, y)
			out.set_pixel(x, y, Color(minf(1.0, c.r + g.r), minf(1.0, c.g + g.g), minf(1.0, c.b + g.b),
				maxf(c.a, minf(1.0, (g.r + g.g + g.b) / 1.2))))
	return out


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


# ------------------------------------------------------------------- in game

## The hull's key in art/hull_grade.json, or "" when its weight is not graded.
## Every manufacturer flies Korvan's pictures for now (Database.hull_sprite).
static func key_for(h: HullData) -> String:
	if h == null or not DB.graded(h.weight):
		return ""
	return "korvan/" + DB.hull_art_name(h.weight, h.tier)

static var _tex := {}

## The hull's picture at its grade, baked once and kept. `half` is the convoy's
## half sheet, brought down from the graded full picture the way the half sheets
## were made (every other pixel), so the two always agree. `seed_in` picks the
## registry number, so it is the ship's. Its resource path is set apart from the
## base's, because HullWear's cache is keyed by path.
static func graded_tex(h: HullData, half: bool, seed_in: int) -> Texture2D:
	var key := key_for(h)
	if key == "" or h.sprite == null:
		return h.sprite_half if half and h.sprite_half != null else h.sprite
	var ck := "%s|%d|%d|%d" % [key, h.tier, int(half), seed_in]
	if _tex.has(ck):
		return _tex[ck]
	var full := h.sprite.get_image()
	if full.is_compressed():
		full.decompress()
	full.convert(Image.FORMAT_RGBA8)
	var img := bake_mix(full, clampi(h.tier, 0, 3), SHIPPED, seed_in, key)
	if half and h.sprite_half != null:
		var small := Image.create(h.sprite_half.get_width(), h.sprite_half.get_height(), false, Image.FORMAT_RGBA8)
		for y in small.get_height():
			for x in small.get_width():
				if x * 2 < img.get_width() and y * 2 < img.get_height():
					small.set_pixel(x, y, img.get_pixel(x * 2, y * 2))
		img = small
	var tex := ImageTexture.create_from_image(img)
	tex.resource_path = "%s#grade%d%s%d" % [h.sprite.resource_path, h.tier, "h" if half else "", seed_in]
	_tex[ck] = tex
	return tex


## The lights as the game draws them: every lit spot's pixels and how bright,
## at time `t`. [Vector2i, Color] pairs in the full picture's pixels, the glow
## included; draw them additively (ThrusterFx.add_material).
static func light_pixels(grade: int, hull: String, t: float) -> Array:
	var out: Array = []
	var glow := light_layer_sparse(grade, hull, t)
	for k in glow:
		out.append([k, glow[k]])
	return out


## light_layer's sums, kept only where something shines.
static func light_layer_sparse(grade: int, hull: String, t: float) -> Dictionary:
	var acc := {}
	for sp in _spots(grade, hull, t):
		var rc: Rect2i = sp[0]
		var lv: float = sp[3]
		if lv <= 0.0:
			continue
		var col: Color = (sp[1] as Color) * lv
		var reach: int = sp[2]
		for y in range(rc.position.y - reach, rc.end.y + reach):
			for x in range(rc.position.x - reach, rc.end.x + reach):
				var dx := maxi(maxi(rc.position.x - x, x - (rc.end.x - 1)), 0)
				var dy := maxi(maxi(rc.position.y - y, y - (rc.end.y - 1)), 0)
				var d := dx + dy
				var a: float = 0.35 if d == 0 else (float(GLOW[d - 1]) if d <= reach else 0.0)
				if a <= 0.0:
					continue
				var p := Vector2i(x, y)
				var prev: Color = acc.get(p, Color(0, 0, 0, 1))
				acc[p] = Color(minf(1.0, prev.r + col.r * a), minf(1.0, prev.g + col.g * a),
					minf(1.0, prev.b + col.b * a), 1.0)
	return acc


## Draw the lights into `ci` (its material additive), in the picture's own
## pixels: the caller sets the transform from the picture to its canvas.
## `scale` 0.5 for a half sheet.
static func draw_lights(ci: CanvasItem, h: HullData, t: float, scale: float = 1.0) -> void:
	var key := key_for(h)
	if key == "":
		return
	for e in light_pixels(clampi(h.tier, 0, 3), key, t):
		var p: Vector2i = e[0]
		ci.draw_rect(Rect2(Vector2(p) * scale, Vector2(scale, scale)), e[1])
