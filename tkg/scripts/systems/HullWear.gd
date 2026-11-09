class_name HullWear
extends RefCounted

## Wear is code, not art: 63 damaged sprites would cost about 13,860 generations.
## Every op snaps to a colour the sprite already has, so no new colour can appear.
## Why: docs/why/HullWear.md#design

## Staining fades by ordered dither, as alpha would blend toward off-palette colours.
## `palette` is the one shared count behind the no-drift ruling.
## Why: docs/why/HullWear.md#palette-check
static func palette(img: Image) -> Dictionary:
	var d := {}
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0:
				d[(int(c.r * 255.0) << 16) | (int(c.g * 255.0) << 8) | int(c.b * 255.0)] = 1
	return d



const BAYER := [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]

## Twelve kinds, some lightening, so a wreck reads shot and not merely dirty.
## Hulls do not scar or bruise: someone has to weld them.
## Why: docs/why/HullWear.md#damage-kinds
enum Substance { METAL, ORGANIC }

const OPS_METAL := [
	{id = &"stain",  n = [0, 4, 8, 14]},
	{id = &"streak", n = [0, 3, 5, 8]},
	{id = &"pit",    n = [0, 2, 4, 6]},
	{id = &"bare",   n = [0, 1, 3, 5]},
	{id = &"crack",  n = [0, 1, 2, 4]},
	{id = &"weld",   n = [0, 1, 2, 3]},
	{id = &"gouge",  n = [0, 1, 3, 6]},
	{id = &"burn",   n = [0, 1, 2, 4]},
	{id = &"buckle", n = [0, 0, 2, 3]},
	{id = &"patch",  n = [0, 0, 1, 2]},
	{id = &"hole",   n = [0, 0, 1, 3]},
	{id = &"impact", n = [0, 0, 1, 2]},
]

## Organic hulls share the space ops but swap out the fabricated-surface ones.
## Why: docs/why/HullWear.md#organic-ops
const OPS_ORGANIC := [
	{id = &"bruise",   n = [0, 5, 9, 15]},
	{id = &"weep",     n = [0, 2, 5, 9]},
	{id = &"pit",      n = [0, 1, 3, 5]},
	{id = &"scar",     n = [0, 2, 3, 5]},
	{id = &"barnacle", n = [0, 2, 3, 4]},
	{id = &"crack",    n = [0, 1, 2, 4]},
	{id = &"gash",     n = [0, 1, 3, 6]},
	{id = &"burn",     n = [0, 0, 1, 3]},
	{id = &"necrosis", n = [0, 0, 2, 4]},
	{id = &"torn",     n = [0, 0, 1, 3]},
	{id = &"hole",     n = [0, 0, 1, 2]},
	{id = &"impact",   n = [0, 0, 1, 2]},
]

static func ops_for(sub_: int) -> Array:
	return OPS_ORGANIC if sub_ == Substance.ORGANIC else OPS_METAL

## A per-ship mix gives a hull character; a zero weight means that kind is absent.
## Why: docs/why/HullWear.md#damage-profile
const MIX := [0.0, 0.0, 0.5, 1.0, 1.0, 1.5, 2.0]

static func _profile(seed_in: int, sub_: int) -> Dictionary:
	var r := Lcg.new(_mix(seed_in, 0x5EED))
	var out := {}
	# Stain and streak are never absent: a hole with no grime reads as assembled.
	for op in ops_for(sub_):
		var w: float = MIX[r.upto(MIX.size())]
		# The ambient layer is never absent, or a hole alone looks assembled, not damaged.
		if op.id == &"stain" or op.id == &"streak" or op.id == &"bruise":
			w = maxf(w, 1.0)
		out[op.id] = w
	return out

## Built once per ship: `ShipView.refresh()` runs several times a second on a 16k pixel pass.
static var _cache: Dictionary = {}

static func clear_cache() -> void:
	_cache.clear()


## Same generator as the Python prototype, bit for bit. Never `Rng.*`: this is cosmetic.
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
		# Keep the original opacity so a punched hole cannot make later ops think it was open.
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

	## Wear never touches the outermost pixels, so every grade keeps the same profile.
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


## Gouges run along the hull; the lit lip comes in runs, as an unbroken one is a white line.
## Why: docs/why/HullWear.md#gouges
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


## A hole is painted as a cavity, not an absence; `punch` decides if the silhouette changes.
## Why: docs/why/HullWear.md#holes
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


## Pitting is what the cold does to an old hull: scattered single pixels, never a pattern.
static func _pit(p: Plate, r: Lcg, n: int) -> void:
	for _i in n:
		var at := _spot(p, r)
		if at.x < 0:
			continue
		# Tighter and fewer than the first cut, which read as static; a cluster says a swarm.
		var spread := r.between(3, 8)
		var count := r.between(4, 9)
		for _k in count:
			var x := at.x + r.between(-spread, spread)
			var y := at.y + r.between(-spread / 2, spread / 2)
			if not p.inside(x, y, 1):
				continue
			p.darken(x, y, 0.34)
			if r.upto(4) == 0 and p.live(x, y - 1):
				p.put(x, y - 1, p.scaled(p.img.get_pixel(x, y - 1), 1.35))


## Bare lightens: all else is shadow, and shadows alone read as dirty, not damaged.
static func _bare(p: Plate, r: Lcg, n: int) -> void:
	for _i in n:
		var at := _spot(p, r)
		if at.x < 0:
			continue
		var rx := r.between(3, 8)
		var ry := r.between(2, 5)
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
					p.put(x, y, p.scaled(p.img.get_pixel(x, y), 1.34))
		# A scrape has an edge where the paint is still lifting.
		for x in range(at.x - rx, at.x + rx + 1):
			if p.inside(x, at.y + ry, 1) and r.upto(2) == 0:
				p.darken(x, at.y + ry, 0.7)


## A fracture, walking and branching. Thin, dark, no highlight — a crack is a
## gap rather than a groove, so it catches no light on either lip.
static func _crack(p: Plate, r: Lcg, n: int, depth: int = 2) -> void:
	for _i in n:
		var at := _spot(p, r)
		if at.x < 0:
			continue
		_crawl(p, r, at.x, at.y, r.between(6, 16), r.between(-2, 2), depth)


static func _crawl(p: Plate, r: Lcg, x: int, y: int, ln: int, bias: int,
		depth: int) -> void:
	var cx := x
	var cy := y
	for i in ln:
		if not p.inside(cx, cy, 1):
			return
		p.darken(cx, cy, 0.36)
		cx += 1 if bias >= 0 else -1
		if r.upto(3) == 0:
			cy += 1 if r.upto(2) == 0 else -1
		# Fractures fork. One level of branching reads as a crack; unlimited
		# recursion reads as a spider and eats the hull.
		if depth > 0 and r.upto(7) == 0:
			_crawl(p, r, cx, cy, ln / 2, -bias, depth - 1)


## A ridge lit on top and dark below, the two-plane rule that stops it reading as a scratch.
static func _buckle(p: Plate, r: Lcg, n: int) -> void:
	for _i in n:
		var at := _spot(p, r)
		if at.x < 0:
			continue
		var ln := r.between(9, 22)
		var amp := r.between(1, 2)
		for i in ln:
			var cx := at.x + i
			var cy := at.y + int(round(sin(float(i) * 0.45) * float(amp)))
			if not p.inside(cx, cy, 2):
				break
			p.put(cx, cy, p.scaled(p.img.get_pixel(cx, cy), 1.4))
			if p.live(cx, cy + 1):
				p.darken(cx, cy + 1, 0.5)


## A weld is repair: a raised, brighter seam, the hole simply closed where `patch` covers it.
static func _weld(p: Plate, r: Lcg, n: int) -> void:
	for _i in n:
		var at := _spot(p, r)
		if at.x < 0:
			continue
		var ln := r.between(7, 18)
		var vert := r.upto(4) == 0
		for i in ln:
			var cx := at.x + (0 if vert else i)
			var cy := at.y + (i if vert else 0)
			if not p.inside(cx, cy, 1):
				break
			var wob := 1 if r.upto(3) == 0 else 0
			p.put(cx, cy + wob, p.scaled(p.img.get_pixel(cx, cy + wob), 1.45))
			if p.live(cx, cy + wob + 1):
				p.darken(cx, cy + wob + 1, 0.72)


## Scorch fans downstream from a source: a cone says something arrived, a blob says dirt.
static func _burn(p: Plate, r: Lcg, n: int) -> void:
	for _i in n:
		var at := _spot(p, r)
		if at.x < 0:
			continue
		var dir := 1 if r.upto(2) == 0 else -1
		var ln := r.between(10, 26)
		for i in ln:
			var cx := at.x + dir * i
			var spread := 1 + (i * 4) / maxi(1, ln)
			for k in range(-spread, spread + 1):
				var cy := at.y + k
				if not p.inside(cx, cy, 1):
					continue
				var falloff := 15.0 * (1.0 - float(i) / float(ln)) 					* (1.0 - absf(float(k)) / float(spread + 1))
				if falloff > float(BAYER[cy & 3][cx & 3]):
					p.darken(cx, cy, 0.5)


## A bruise has no edge or highlight, unlike a stain; overlaps deepen as `darken()` reads below.
static func _bruise(p: Plate, r: Lcg, n: int) -> void:
	for _i in n:
		var at := _spot(p, r)
		if at.x < 0:
			continue
		var rx := r.between(6, 14)
		var ry := r.between(4, 9)
		for y in range(at.y - ry, at.y + ry + 1):
			for x in range(at.x - rx, at.x + rx + 1):
				if not p.inside(x, y, 1):
					continue
				var dx := float(x - at.x) / float(rx)
				var dy := float(y - at.y) / float(ry)
				var d := dx * dx + dy * dy
				if d > 1.0:
					continue
				# Softer falloff than a stain, and no hard cut at the rim.
				if (1.0 - d) * 13.0 > float(BAYER[y & 3][x & 3]):
					p.darken(x, y, 0.78)


## A gash is not straight and has a torn pale edge on both lips, unlike a gouge.
static func _gash(p: Plate, r: Lcg, n: int) -> void:
	for _i in n:
		var at := _spot(p, r)
		if at.x < 0:
			continue
		var ln := r.between(8, 20)
		var cx := at.x
		var cy := at.y
		for i in ln:
			if not p.inside(cx, cy, 2):
				break
			var wide := 1 + (1 if (i > ln / 4 and i < (ln * 3) / 4) else 0)
			for k in range(-wide, wide + 1):
				p.darken(cx, cy + k, 0.34)
			if p.live(cx, cy - wide - 1):
				p.put(cx, cy - wide - 1, p.scaled(p.img.get_pixel(cx, cy - wide - 1), 1.4))
			if p.live(cx, cy + wide + 1):
				p.put(cx, cy + wide + 1, p.scaled(p.img.get_pixel(cx, cy + wide + 1), 1.4))
			cx += 1
			if r.upto(2) == 0:
				cy += 1 if r.upto(2) == 0 else -1


## Torn tissue: the radius wobbles per column so no boundary looks drawn.
static func _torn(p: Plate, r: Lcg, n: int) -> void:
	var ranked := _by_luma(p.cols)
	var inner: Color = ranked[mini(ranked.size() - 2, ranked.size() * 3 / 4)]
	for _i in n:
		var at := _spot(p, r)
		if at.x < 0:
			continue
		var rx := r.between(4, 9)
		for x in range(at.x - rx, at.x + rx + 1):
			var t := 1.0 - absf(float(x - at.x)) / float(rx)
			var half := int(round(t * float(r.between(3, 6)))) + r.upto(2) - 1
			for y in range(at.y - half, at.y + half + 1):
				if not p.inside(x, y, 2):
					continue
				if absi(y - at.y) >= half - 1:
					p.put(x, y, inner)
				else:
					p.darken(x, y, 0.4)


## Weeping starts dark and thins, as fluid came out of something and did not settle on it.
static func _weep(p: Plate, r: Lcg, n: int) -> void:
	for _i in n:
		var at := _spot(p, r)
		if at.x < 0:
			continue
		var ln := r.between(8, 22)
		var w := r.between(1, 2)
		for i in ln:
			var yy := at.y + i
			var narrow := w if i < ln / 2 else 0
			for k in range(-narrow, narrow + 1):
				var xx := at.x + k
				if not p.inside(xx, yy, 1):
					continue
				if (15 - (i * 11) / maxi(1, ln)) > BAYER[yy & 3][xx & 3]:
					p.darken(xx, yy, 0.56 if i < ln / 3 else 0.72)


## Necrosis desaturates toward grey, so a patch reads as dying and not as shadowed.
static func _necrosis(p: Plate, r: Lcg, n: int) -> void:
	for _i in n:
		var at := _spot(p, r)
		if at.x < 0:
			continue
		var rx := r.between(4, 10)
		var ry := r.between(3, 7)
		for y in range(at.y - ry, at.y + ry + 1):
			for x in range(at.x - rx, at.x + rx + 1):
				if not p.inside(x, y, 1):
					continue
				var dx := float(x - at.x) / float(rx)
				var dy := float(y - at.y) / float(ry)
				if dx * dx + dy * dy > 1.0:
					continue
				if (1.0 - dx * dx - dy * dy) * 14.0 <= float(BAYER[y & 3][x & 3]):
					continue
				var c := p.img.get_pixel(x, y)
				var g := 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
				p.put(x, y, p.snap(Color(lerpf(c.r, g, 0.75), lerpf(c.g, g, 0.75),
					lerpf(c.b, g, 0.75), 1.0)))


## Scar is damage survived: a machine stays cut, a body keeps the record.
static func _scar(p: Plate, r: Lcg, n: int) -> void:
	for _i in n:
		var at := _spot(p, r)
		if at.x < 0:
			continue
		var ln := r.between(6, 16)
		var cx := at.x
		var cy := at.y
		for i in ln:
			if not p.inside(cx, cy, 2):
				break
			p.put(cx, cy, p.scaled(p.img.get_pixel(cx, cy), 1.38))
			if r.upto(3) == 0 and p.live(cx, cy + 1):
				p.darken(cx, cy + 1, 0.82)
			cx += 1
			if r.upto(3) == 0:
				cy += 1 if r.upto(2) == 0 else -1


## Barnacles are not damage: dark shell clusters, as barnacles colonise.
static func _barnacle(p: Plate, r: Lcg, n: int) -> void:
	var ranked := _by_luma(p.cols)
	var shell: Color = ranked[mini(1, ranked.size() - 1)]
	for _i in n:
		var at := _spot(p, r)
		if at.x < 0:
			continue
		var spread := r.between(4, 10)
		for _k in r.between(3, 7):
			var x := at.x + r.between(-spread, spread)
			var y := at.y + r.between(-spread / 2, spread / 2)
			var w := r.between(1, 2)
			for dy in range(w):
				for dx in range(w + 1):
					if p.inside(x + dx, y + dy, 2):
						p.put(x + dx, y + dy, shell)
			if p.live(x, y - 1):
				p.put(x, y - 1, p.scaled(p.img.get_pixel(x, y - 1), 1.45))


## Impact is the one composite op, so a hull has a mark that clearly happened.
## Why: docs/why/HullWear.md#impact
static func _impact(p: Plate, r: Lcg, n: int) -> void:
	var ranked := _by_luma(p.cols)
	var dark: Color = ranked[0]
	for _i in n:
		var at := _spot(p, r)
		if at.x < 0:
			continue
		var rad := r.between(2, 4)
		for y in range(at.y - rad, at.y + rad + 1):
			for x in range(at.x - rad, at.x + rad + 1):
				if not p.inside(x, y, 2):
					continue
				var d := Vector2(x - at.x, y - at.y).length()
				if d <= float(rad) * 0.6:
					p.put(x, y, dark)
				elif d <= float(rad):
					p.put(x, y, p.scaled(p.img.get_pixel(x, y), 1.5))
		# Thrown outward, short and straight.
		for _k in r.between(3, 6):
			var ang := r.unit() * TAU
			var ln := r.between(3, 9)
			for i in range(rad, rad + ln):
				var x := at.x + int(round(cos(ang) * float(i)))
				var y := at.y + int(round(sin(ang) * float(i) * 0.6))
				if not p.inside(x, y, 1):
					break
				p.darken(x, y, 0.44)
		_burn(p, r, 1)


## A patch is repair: a derelict has holes, a working ship has patches.
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


## Returns a copy, never the shared source. Grime goes first so wounds cut through it.
## Why: docs/why/HullWear.md#op-order
static func worn(src: Image, band: int, seed_in: int, punch: bool = false,
		sub_: int = Substance.METAL) -> Image:
	var out := src.duplicate() as Image
	if out.get_format() != Image.FORMAT_RGBA8:
		out.convert(Image.FORMAT_RGBA8)
	var t := clampi(band, 0, 3)
	if t == 0:
		return out
	var p := Plate.new(out)
	var mixw := _profile(seed_in, sub_)
	var ops := ops_for(sub_)
	# One stream per op and no band in the seed, so damage accumulates and does not reshuffle.
	# Band in the seed measured 16% overlap between bands, which is chance.
	# Why: docs/why/HullWear.md#wear-seeding
	for i in ops.size():
		var op: Dictionary = ops[i]
		var base: int = op.n[t]
		if base == 0:
			continue
		var n := int(round(float(base) * float(mixw.get(op.id, 1.0))))
		if n <= 0:
			continue
		# One stream per op, seeded apart from the band and other ops so counts cannot shift.
		var r := Lcg.new(seed_in * 977 + i + 1)
		match op.id:
			# fabricated
			&"stain": _stain(p, r, n)
			&"streak": _streak(p, r, n)
			&"bare": _bare(p, r, n)
			&"weld": _weld(p, r, n)
			&"gouge": _gouge(p, r, n)
			&"buckle": _buckle(p, r, n)
			&"patch": _patch(p, r, n)
			# living
			&"bruise": _bruise(p, r, n)
			&"gash": _gash(p, r, n)
			&"torn": _torn(p, r, n)
			&"weep": _weep(p, r, n)
			&"necrosis": _necrosis(p, r, n)
			&"scar": _scar(p, r, n)
			&"barnacle": _barnacle(p, r, n)
			# either
			&"pit": _pit(p, r, n)
			&"crack": _crack(p, r, n)
			&"burn": _burn(p, r, n)
			&"hole": _hole(p, r, n, punch)
			&"impact": _impact(p, r, n)
	return out


## Keyed on the sprite path, not the hull: a looted hull is a duplicate of a catalogue frame.
## Why: docs/why/HullWear.md#wear-cache
static func worn_cached(tex: Texture2D, band: int, seed_in: int,
		punch: bool = false, sub_: int = Substance.METAL) -> Image:
	if tex == null:
		return null
	var key := "%s|%d|%d|%d|%d" % [tex.resource_path, band, seed_in,
		1 if punch else 0, sub_]
	if _cache.has(key):
		return _cache[key]
	var img := worn(tex.get_image(), band, seed_in, punch, sub_)
	_cache[key] = img
	return img


## Four bands, so a hull rebuilds at most three times a run; the first is wide on purpose.
## Why: docs/why/HullWear.md#wear-bands
static func band_for(damage: float) -> int:
	if damage < 0.22:
		return 0
	if damage < 0.48:
		return 1
	if damage < 0.74:
		return 2
	return 3


## Seed is ship, pilot and run, not band. The run is passed in so headless sheets are repeatable.
## Why: docs/why/HullWear.md#wear-seed
static func seed_for(h: HullData, pilot: String = "", run_seed: int = 0) -> int:
	if h == null:
		return 0
	var v := absi(hash(h.name))
	v = _mix(v, absi(hash(pilot)))
	v = _mix(v, absi(run_seed))
	return v % 100003


## Avalanche mix as in `Rng._mix`: short hull and pilot names would collide if added.
static func _mix(a: int, b: int) -> int:
	var v := (a ^ (b + 0x9E3779B9 + (a << 6) + (a >> 2))) & 0x7FFFFFFF
	v = (v ^ (v >> 15)) * 0x2545F491
	return absi(v) & 0x7FFFFFFF
