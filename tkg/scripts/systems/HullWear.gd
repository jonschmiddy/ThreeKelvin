class_name HullWear
extends RefCounted

## Condition damage, drawn rather than drawn ON.
##
## A hull sprite is authored once, pristine. This wears it down to a grade — the
## same ship, kept badly — by scoring, staining, streaking, holing and patching
## the pixels it already has.
##
## WHY THIS IS CODE AND NOT ART. Seven manufacturers times three weight classes
## is 21 hulls, and four condition grades makes 84 sprites. Generating the 63
## damaged ones costs about 13,860 PixelLab generations at eleven masked tiles
## apiece — near three months of allowance, for hulls alone, before a single
## module or enemy or station. Drawn here it costs nothing, on the twenty hulls
## that do not exist yet as readily as on the one that does.
##
## THE PROPERTY THAT MATTERS MOST is not the price, though. Every operation below
## ends by SNAPPING its result to a colour the sprite already contains, so wear
## cannot introduce a colour — measured at 0 new colours on all four grades. The
## generated attempts drifted 17 to 41 new colours per tile, and a single pass
## over the whole hull invented an entirely new palette and threw away every
## amber panel Korvan flies. Arithmetic cannot do that. There is nowhere for a
## new colour to come from.
##
## What it is good at is GRIME: soot, staining, streaking, wear. That is most of
## what separates a kept ship from a neglected one, and it is exactly the sort of
## thing arithmetic does well. What it is NOT good at is spectacle — a torn
## opening with ideas in it, where something specific clearly happened. If that
## is ever wanted, the cheap answer is a handful of generated wound decals
## stamped on top of this, once, and reused across all 84.

## 4x4 ordered dither. Staining has to FADE, and a fade in pixel art is a
## pattern, not an alpha ramp — alpha would blend toward colours off the palette
## and undo the whole guarantee above.
const BAYER := [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]

## How much of each operation per grade: gouges, stains, streaks, holes, patches.
##
## Deliberately LOW on gouges and high on staining. Gouges say ATTACKED; grime
## says NEGLECTED, and a condition grade is mostly the second thing. The first
## cut of this table ran sixteen gouges at C and the ship looked scribbled on.
const GRADES := [
	[0, 0, 0, 0, 0],
	[1, 4, 3, 0, 0],
	[3, 8, 5, 1, 1],
	[6, 14, 8, 3, 2],
]

## Worn images, keyed by sprite path, grade and seed. `ShipView.refresh()` runs
## every time the idle bob changes offset — several times a second — and this is
## a whole-image pass over sixteen thousand pixels. It is built once per ship.
static var _cache: Dictionary = {}

static func clear_cache() -> void:
	_cache.clear()


## The same generator the Python prototype used, kept bit-for-bit so a grade
## rendered here matches the one that was reviewed. Never Rng.* — this is
## cosmetic and per-sprite, and must not draw from a stream a run replays.
class Lcg extends RefCounted:
	const MASK := 0x7fffffff
	var s: int = 1

	func _init(seed_in: int) -> void:
		s = (seed_in * 2654435761) & MASK
		if s == 0:
			s = 1

	func nxt() -> int:
		s = (s * 1103515245 + 12345) & MASK
		return s

	func upto(n: int) -> int:
		return nxt() % n if n > 0 else 0

	func between(a: int, b: int) -> int:
		return a + upto(b - a + 1)

	func unit() -> float:
		return float(nxt()) / float(MASK)


## The sprite being worn, plus the palette it is allowed to use.
class Plate extends RefCounted:
	var img: Image
	var w: int
	var h: int
	var cols: PackedColorArray = PackedColorArray()
	var _snap: Dictionary = {}
	var _alpha: PackedByteArray = PackedByteArray()

	func _init(src: Image) -> void:
		img = src
		w = img.get_width()
		h = img.get_height()
		# The ORIGINAL opacity, kept aside. Everything asks `solid()` about the
		# sprite as authored, so punching a hole cannot make the next operation
		# think the hull was always open there — otherwise damage erodes outward
		# from whatever was drawn first.
		_alpha.resize(w * h)
		var seen := {}
		for y in h:
			for x in w:
				var c := img.get_pixel(x, y)
				var op := c.a > 0.0
				_alpha[y * w + x] = 1 if op else 0
				if op:
					seen[_key(c)] = c
		for k in seen:
			cols.append(seen[k])

	static func _key(c: Color) -> int:
		return (int(c.r * 255.0) << 16) | (int(c.g * 255.0) << 8) | int(c.b * 255.0)

	func solid(x: int, y: int) -> bool:
		if x < 0 or y < 0 or x >= w or y >= h:
			return false
		return _alpha[y * w + x] == 1

	func live(x: int, y: int) -> bool:
		if x < 0 or y < 0 or x >= w or y >= h:
			return false
		return img.get_pixel(x, y).a > 0.0

	## Well inside the silhouette. Wear never touches the outermost pixels, so
	## every grade keeps the same profile against the void — which is what makes
	## an S and a C read as one ship in two conditions rather than two ships.
	func inside(x: int, y: int, pad: int = 1) -> bool:
		for dy in range(-pad, pad + 1):
			for dx in range(-pad, pad + 1):
				if not solid(x + dx, y + dy):
					return false
		return true

	## The nearest colour the sprite already owns. This is the guarantee.
	func snap(c: Color) -> Color:
		var k := _key(c)
		if _snap.has(k):
			return _snap[k]
		var best := cols[0]
		var bd := 1e20
		for p in cols:
			var dr := p.r - c.r
			var dg := p.g - c.g
			var db := p.b - c.b
			var d := dr * dr + dg * dg + db * db
			if d < bd:
				bd = d
				best = p
		_snap[k] = best
		return best

	func scaled(c: Color, f: float) -> Color:
		return snap(Color(minf(1.0, c.r * f), minf(1.0, c.g * f), minf(1.0, c.b * f), 1.0))

	func put(x: int, y: int, c: Color) -> void:
		if not live(x, y):
			return
		img.set_pixel(x, y, Color(c.r, c.g, c.b, 1.0))

	func darken(x: int, y: int, f: float) -> void:
		if live(x, y):
			put(x, y, scaled(img.get_pixel(x, y), f))

	func cut(x: int, y: int) -> void:
		if x >= 0 and y >= 0 and x < w and y < h:
			img.set_pixel(x, y, Color(0, 0, 0, 0))


static func _spot(p: Plate, r: Lcg, tries: int = 64) -> Vector2i:
	for _i in tries:
		var x := r.upto(p.w)
		var y := r.upto(p.h)
		if p.inside(x, y, 2):
			return Vector2i(x, y)
	return Vector2i(-1, -1)


## Raking gouges. A strike arrives at a shallow angle, so these run mostly along
## the hull with a slight rise — a vertical scratch reads as a panel line and
## vanishes into the ones already drawn.
##
## Dark trough, bare metal on the lit lip, and the lip appears in RUNS rather
## than continuously: an unbroken highlight at full brightness is a white line
## drawn on top of the ship, where metal only shows where the gouge bit deepest.
static func _gouge(p: Plate, r: Lcg, n: int) -> void:
	for _i in n:
		var at := _spot(p, r)
		if at.x < 0:
			continue
		var ln := r.between(14, 34)
		var slope := r.between(4, 9)
		var rise := -1 if r.upto(2) == 1 else 1
		var drift := r.upto(2)
		for i in ln:
			var cx := at.x + i
			var cy := at.y + (i * rise) / slope
			if not p.inside(cx, cy, 1):
				break
			# A gouge has a middle: deepest through the centre of its run.
			var deep := 0.30 if (i > ln / 4 and i < (ln * 3) / 4) else 0.46
			p.darken(cx, cy, deep)
			if drift == 1 and p.inside(cx, cy + 1, 1) and i % 3 != 0:
				p.darken(cx, cy + 1, 0.52)
			if i % 7 < 4 and p.live(cx, cy - 1):
				p.put(cx, cy - 1, p.scaled(p.img.get_pixel(cx, cy - 1), 1.22))


## Soot and staining, falling off with distance and masked by BAYER — two
## palette colours in a pattern, never a blend.
static func _stain(p: Plate, r: Lcg, n: int) -> void:
	for _i in n:
		var at := _spot(p, r)
		if at.x < 0:
			continue
		var rx := r.between(4, 11)
		var ry := r.between(3, 7)
		for y in range(at.y - ry, at.y + ry + 1):
			for x in range(at.x - rx, at.x + rx + 1):
				if not p.inside(x, y, 1):
					continue
				var dx := float(x - at.x) / float(rx)
				var dy := float(y - at.y) / float(ry)
				var d := dx * dx + dy * dy
				if d > 1.0:
					continue
				if (1.0 - d) * 15.0 > float(BAYER[y & 3][x & 3]):
					p.darken(x, y, 0.62)


## Grime runs DOWN the flank. Weathering has a direction and it is gravity.
static func _streak(p: Plate, r: Lcg, n: int) -> void:
	for _i in n:
		var at := _spot(p, r)
		if at.x < 0:
			continue
		var ln := r.between(6, 18)
		for i in ln:
			var yy := at.y + i
			if not p.inside(at.x, yy, 1):
				break
			if (15 - (i * 14) / maxi(1, ln)) > BAYER[yy & 3][at.x & 3]:
				p.darken(at.x, yy, 0.74)


## Blown open, WITH AN INSIDE.
##
## The first version of this cut an ellipse to alpha and ringed it in black, and
## it read as a missing pixel rather than a wound. A hole in a hull is not an
## absence — it is a view of the frame behind the plating. So this paints a
## cavity: darkest colour for the void, structure running across it, a torn lip
## catching light on the top edge and shadow on the bottom.
##
## `punch` is the switch on whether a grade may change the SILHOUETTE. Off, the
## opening is painted and the outline is untouched, which is what keeps every
## grade the same ship. On, the middle is cut through as well.
static func _hole(p: Plate, r: Lcg, n: int, punch: bool) -> void:
	var ranked := _by_luma(p.cols)
	var dark: Color = ranked[0]
	var void_c: Color = ranked[mini(1, ranked.size() - 1)]
	var rib: Color = ranked[mini(ranked.size() / 4, ranked.size() - 1)]
	for _i in n:
		var at := _spot(p, r)
		if at.x < 0:
			continue
		var rx := r.between(4, 7)
		var ry := r.between(3, 5)
		var cells: Array[Vector2i] = []
		for y in range(at.y - ry, at.y + ry + 1):
			for x in range(at.x - rx, at.x + rx + 1):
				var dx := float(x - at.x) / float(rx)
				var dy := float(y - at.y) / float(ry)
				if dx * dx + dy * dy > 1.0 + (r.unit() - 0.5) * 0.3:
					continue
				if not p.inside(x, y, 2):
					continue
				cells.append(Vector2i(x, y))
		if cells.size() < 8:
			continue
		for c in cells:
			p.put(c.x, c.y, void_c if (c.x + c.y) % 2 == 1 else dark)
		for c in cells:
			if c.x % 3 == at.x % 3:
				p.put(c.x, c.y, rib)
		var top := {}
		var bot := {}
		for c in cells:
			if not top.has(c.x) or c.y < top[c.x]:
				top[c.x] = c.y
			if not bot.has(c.x) or c.y > bot[c.x]:
				bot[c.x] = c.y
		for x in top:
			if p.live(x, top[x] - 1):
				p.put(x, top[x] - 1, p.scaled(p.img.get_pixel(x, top[x] - 1), 1.5))
		for x in bot:
			if p.live(x, bot[x] + 1):
				p.put(x, bot[x] + 1, p.scaled(p.img.get_pixel(x, bot[x] + 1), 0.55))
		if punch:
			for c in cells:
				if absi(c.x - at.x) < rx / 2 and absi(c.y - at.y) < ry / 2:
					p.cut(c.x, c.y)


## A plate welded over something worse. The one operation that reads as REPAIR
## rather than damage, which is what makes a hull look kept-going instead of
## merely broken — a derelict has holes, a working ship has patches.
static func _patch(p: Plate, r: Lcg, n: int) -> void:
	for _i in n:
		var at := _spot(p, r)
		if at.x < 0:
			continue
		var pw := r.between(6, 11)
		var ph := r.between(4, 7)
		var base := p.scaled(p.img.get_pixel(at.x, at.y), 0.86)
		var edge := p.scaled(base, 0.55)
		for yy in range(at.y, at.y + ph):
			for xx in range(at.x, at.x + pw):
				if not p.inside(xx, yy, 1):
					continue
				var rim := xx == at.x or xx == at.x + pw - 1 \
					or yy == at.y or yy == at.y + ph - 1
				p.put(xx, yy, edge if rim else base)
		var rivet := p.scaled(base, 0.62)
		for xx in range(at.x + 1, at.x + pw - 1, 3):
			p.put(xx, at.y + 1, rivet)
			p.put(xx, at.y + ph - 2, rivet)


static func _by_luma(cols: PackedColorArray) -> Array:
	var a: Array = []
	for c in cols:
		a.append(c)
	a.sort_custom(func(x: Color, y: Color) -> bool:
		return (0.299 * x.r + 0.587 * x.g + 0.114 * x.b) \
			< (0.299 * y.r + 0.587 * y.g + 0.114 * y.b))
	return a


## The public door. Returns a WORN COPY; the source image is never touched,
## because it is the catalogue's and every ship in the game shares it.
##
## Order is not arbitrary. Stain and streak go down first so gouges and holes cut
## THROUGH the grime rather than being buried under it, and patches land before
## the gouges so a plate can itself be scarred — a repair that is still pristine
## reads as newer than the ship around it, which is exactly wrong on a C.
static func worn(src: Image, tier: int, seed_in: int, punch: bool = false) -> Image:
	var out := src.duplicate() as Image
	if out.get_format() != Image.FORMAT_RGBA8:
		out.convert(Image.FORMAT_RGBA8)
	var t := clampi(tier, 0, GRADES.size() - 1)
	if t == 0:
		return out
	var g: Array = GRADES[t]
	var p := Plate.new(out)
	var r := Lcg.new(seed_in * 131 + t * 17)
	_stain(p, r, g[1])
	_streak(p, r, g[2])
	_patch(p, r, g[4])
	_gouge(p, r, g[0])
	_hole(p, r, g[3], punch)
	return out


## Worn, and remembered. ShipView repaints whenever the idle bob moves, so this
## is the entry every caller should use — the uncached one is a whole-image pass
## and would run several times a second otherwise.
##
## Keyed on the SPRITE's path rather than the hull's, because a looted hull is a
## duplicate() of a catalogue frame: same art, different stats, and two of them
## at the same grade should wear identically.
static func worn_cached(tex: Texture2D, tier: int, seed_in: int,
		punch: bool = false) -> Image:
	if tex == null:
		return null
	var key := "%s|%d|%d|%d" % [tex.resource_path, tier, seed_in, 1 if punch else 0]
	if _cache.has(key):
		return _cache[key]
	var img := worn(tex.get_image(), tier, seed_in, punch)
	_cache[key] = img
	return img


## A wear seed for a hull. Same ship at the same grade wears the same scars,
## which is the point: the grade is a description of the ship, not a die roll on
## top of one. Two A-class Ironsides look alike because they ARE alike.
static func seed_for(h: HullData) -> int:
	if h == null:
		return 0
	return absi(hash(h.name)) % 100003
