class_name HullFit
extends RefCounted

## What a CLASS bolts on. The other half of HullWear.
##
## HullWear takes a hull away — scoring, soot, holes. This puts things on it:
## vents, sensor blisters, conduit runs, running lights, an antenna. Same
## engine, opposite direction, and they compose in that order because a bolt-on
## should be able to get shot.
##
## WHY IT EXISTS. DB.TIER_DELTA grants an A-class frame an extra weapon hardpoint
## and an S-class one a system mount and the reactor to run it, and until now
## none of that was visible: a C and an S were the same picture with different
## numbers behind them. A ship carrying more should look like it is carrying
## more.
##
## SIZED BY WHAT THE HULL CAN TAKE, not by what would be nice. Measured on the
## medium: 1,226 places a 3x3 fits without covering something already drawn, 273
## for a 6x4, and 3 for a 10x6. So everything here is small. That is also the
## correct answer artistically — a bolt-on is a vent or a blister, and anything
## slab-sized is not a fitting, it is a different ship.
##
## Reuses HullWear's Plate and Lcg rather than carrying its own, so the palette
## guarantee holds identically: every pixel written here snaps to a colour the
## sprite already contains.

## Bolt-ons per class, worst to best. C adds NOTHING — it is the frame as drawn,
## and everything above it is the same frame with more welded to it.
##
## The jump from A to S is deliberately the largest. A class is a specification
## and the top of a range should look like somebody spent money.
const KIT := {
	&"vent":    [0, 1, 2, 3],
	&"blister": [0, 1, 2, 3],
	&"pipe":    [0, 1, 2, 4],
	&"plate":   [0, 0, 2, 3],
	&"light":   [0, 0, 1, 3],
	&"mast":    [0, 0, 0, 2],
}

## Order matters: flat things first, raised things last, so a blister sits ON a
## plate rather than being cut in half by one.
const ORDER: Array[StringName] = [&"plate", &"vent", &"pipe", &"blister",
	&"light", &"mast"]

static var _cache: Dictionary = {}

static func clear_cache() -> void:
	_cache.clear()


## Somewhere this fitting can sit without covering anything already drawn.
##
## FLAT means every pixel under the footprint is the same colour — which is how
## a hull says "this is bare plating" without anyone having to author anchors.
## The alternative was HullData's weapon_anchors, empty on all 21 frames and
## needing a human to place them; this reads the art instead.
static func _room(p: HullWear.Plate, r: HullWear.Lcg, bw: int, bh: int) -> Vector2i:
	for _try in 90:
		var x := r.upto(p.w - bw)
		var y := r.upto(p.h - bh)
		if not p.inside(x, y, 1):
			continue
		var c0 := p.img.get_pixel(x, y)
		var ok := true
		for dy in bh:
			for dx in bw:
				if not p.inside(x + dx, y + dy, 1) \
						or not p.img.get_pixel(x + dx, y + dy).is_equal_approx(c0):
					ok = false
					break
			if not ok:
				break
		if ok:
			return Vector2i(x, y)
	return Vector2i(-1, -1)


## A grille. Alternating lit and shadowed rows, which is the cheapest thing that
## reads as a hole with slats in it at this size.
static func _vent(p: HullWear.Plate, r: HullWear.Lcg, n: int) -> void:
	for _i in n:
		var bw := r.between(4, 6)
		var bh := r.between(3, 4)
		var at := _room(p, r, bw + 2, bh + 2)
		if at.x < 0:
			continue
		var base := p.img.get_pixel(at.x, at.y)
		for y in range(at.y + 1, at.y + 1 + bh):
			var lit := (y - at.y) % 2 == 1
			for x in range(at.x + 1, at.x + 1 + bw):
				p.put(x, y, p.scaled(base, 0.52 if lit else 0.86))
		# The rim: lit along the top, shadowed along the bottom.
		for x in range(at.x, at.x + bw + 2):
			p.put(x, at.y, p.scaled(base, 1.3))
			p.put(x, at.y + bh + 1, p.scaled(base, 0.62))


## A sensor dome. Lit top-left, shadowed bottom-right, because that is where the
## light comes from in this game and a blister that disagrees reads as a hole.
static func _blister(p: HullWear.Plate, r: HullWear.Lcg, n: int) -> void:
	for _i in n:
		var d := r.between(3, 4)
		var at := _room(p, r, d + 1, d + 1)
		if at.x < 0:
			continue
		var base := p.img.get_pixel(at.x, at.y)
		var cx := at.x + d / 2
		var cy := at.y + d / 2
		for y in range(at.y, at.y + d):
			for x in range(at.x, at.x + d):
				var dx := x - cx
				var dy := y - cy
				if dx * dx + dy * dy > (d * d) / 4 + 1:
					continue
				var f := 1.34 if (dx + dy) < 0 else (0.6 if (dx + dy) > 1 else 1.0)
				p.put(x, y, p.scaled(base, f))


## A conduit run. Straight, with a joint or two — the thing that makes a hull
## look plumbed rather than moulded.
static func _pipe(p: HullWear.Plate, r: HullWear.Lcg, n: int) -> void:
	for _i in n:
		var ln := r.between(7, 14)
		var vert := r.upto(4) == 0
		var at := _room(p, r, 2 if vert else ln, ln if vert else 2)
		if at.x < 0:
			continue
		var base := p.img.get_pixel(at.x, at.y)
		for i in ln:
			var x := at.x + (0 if vert else i)
			var y := at.y + (i if vert else 0)
			p.put(x, y, p.scaled(base, 1.24))
			p.put(x + (1 if vert else 0), y + (0 if vert else 1),
				p.scaled(base, 0.66))
			# Joints, every few pixels.
			if i % r.between(4, 6) == 0:
				p.put(x, y, p.scaled(base, 0.5))


## A bolted armour patch. Rivets included, because a plate without fasteners
## reads as a sticker.
static func _plate(p: HullWear.Plate, r: HullWear.Lcg, n: int) -> void:
	for _i in n:
		var bw := r.between(6, 9)
		var bh := r.between(4, 6)
		var at := _room(p, r, bw, bh)
		if at.x < 0:
			continue
		var base := p.img.get_pixel(at.x, at.y)
		var face := p.scaled(base, 1.12)
		for y in range(at.y, at.y + bh):
			for x in range(at.x, at.x + bw):
				p.put(x, y, face)
		for x in range(at.x, at.x + bw):
			p.put(x, at.y, p.scaled(base, 1.34))
			p.put(x, at.y + bh - 1, p.scaled(base, 0.6))
		var rivet := p.scaled(base, 0.52)
		for x in range(at.x + 1, at.x + bw - 1, 3):
			p.put(x, at.y + 1, rivet)
			p.put(x, at.y + bh - 2, rivet)


## A running light. The brightest thing the palette owns, one pixel of it, with
## a dimmer ring — and it has to stay COLD, because warm light in this game
## means combustion and a navigation lamp is not on fire.
static func _light(p: HullWear.Plate, r: HullWear.Lcg, n: int) -> void:
	var cool := _coldest_bright(p)
	for _i in n:
		var at := _room(p, r, 3, 3)
		if at.x < 0:
			continue
		var base := p.img.get_pixel(at.x + 1, at.y + 1)
		p.put(at.x + 1, at.y + 1, cool)
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			p.put(at.x + 1 + d.x, at.y + 1 + d.y, p.scaled(base, 1.3))


## An antenna, on the DORSAL EDGE rather than anywhere flat — a mast in the
## middle of a hull is a pole stuck through a roof. Walks up from a flat spot
## until it finds the outside of the ship, then stands proud of it.
##
## The only fitting that can change the silhouette, which is why S gets it and
## nothing else does: the top of a range should read differently in outline.
static func _mast(p: HullWear.Plate, r: HullWear.Lcg, n: int) -> void:
	for _i in n:
		var at := _room(p, r, 3, 3)
		if at.x < 0:
			continue
		var x := at.x + 1
		var y := at.y
		# Up to the skin.
		while y > 0 and p.solid(x, y - 1):
			y -= 1
		var base := p.img.get_pixel(x, y)
		var h := r.between(4, 8)
		for i in h:
			var yy := y - 1 - i
			if yy < 1:
				break
			p.img.set_pixel(x, yy, p.scaled(base, 0.5 if i % 2 == 0 else 0.86))
		# A crossbar, so it is an aerial and not a stick.
		var bar := y - 1 - h / 2
		if bar > 0:
			for k in [-1, 1]:
				if x + k > 0 and x + k < p.w:
					p.img.set_pixel(x + k, bar, p.scaled(base, 0.7))


## The palest colour the sprite owns that is NOT warm. Running lights have to
## come out of the existing palette like everything else, and the brightest
## entry on a Korvan hull is amber — which would put a fire on the nose.
static func _coldest_bright(p: HullWear.Plate) -> Color:
	var best := p.cols[0]
	var score := -1.0
	for c in p.cols:
		if c.r - c.b > 0.08:
			continue
		var lum := 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
		if lum > score:
			score = lum
			best = c
	return best


## A frame at a class. Returns a DUPLICATE; the catalogue's image is shared by
## every ship in the game and must never be written through.
static func fitted(src: Image, cls: int, seed_in: int) -> Image:
	var out := src.duplicate() as Image
	if out.get_format() != Image.FORMAT_RGBA8:
		out.convert(Image.FORMAT_RGBA8)
	var c := clampi(cls, 0, 3)
	if c == 0:
		return out
	var p := HullWear.Plate.new(out)
	for i in ORDER.size():
		var id: StringName = ORDER[i]
		var n: int = (KIT[id] as Array)[c]
		if n <= 0:
			continue
		var r := HullWear.Lcg.new(seed_in * 613 + i + 1)
		match id:
			&"plate": _plate(p, r, n)
			&"vent": _vent(p, r, n)
			&"pipe": _pipe(p, r, n)
			&"blister": _blister(p, r, n)
			&"light": _light(p, r, n)
			&"mast": _mast(p, r, n)
	return out


static func fitted_cached(tex: Texture2D, cls: int, seed_in: int) -> Image:
	if tex == null:
		return null
	var key := "%s|%d|%d" % [tex.resource_path, cls, seed_in]
	if _cache.has(key):
		return _cache[key]
	var img := fitted(tex.get_image(), cls, seed_in)
	_cache[key] = img
	return img
