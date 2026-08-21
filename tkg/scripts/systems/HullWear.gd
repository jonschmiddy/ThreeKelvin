class_name HullWear
extends RefCounted

## Battle damage, drawn rather than drawn ON.
##
## A hull sprite is authored once, intact. This beats it up in proportion to how
## close the ship is to dying, by scoring, staining, streaking, holing and
## patching the pixels it already has.
##
## IT USED TO BE KEYED ON TIER, and that was two ideas wearing one letter. Tier
## grows a ship HARDPOINTS at A and a reactor at S — that is a specification, and
## a well-kept ship does not sprout a weapon mount. Condition and specification
## are different axes and only one of them belongs on a surface. So the letters
## keep the spec and this takes the damage, which is the half that was always
## missing: `ShipBuild.damage()` has returned hp-over-max since the convoy strip
## needed it, the procedural path spent it on two flat dark rectangles, and the
## real-art path ignored it completely — a hull with a sprite looked showroom
## fresh at one hull point.
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
## Every distinct RGB in an image, as a set. Alpha-zero pixels do not count.
##
## This is the measurement behind the ruling that generated art may not drift the
## palette: the wear operations are checked by counting the colours before and
## after and requiring the difference to be zero. Three contact sheets — FitSheet,
## BestiarySheet and WearSheet — each carried a byte-identical private copy, which
## is a strange thing for the number that proves the invariant to be.
static func palette(img: Image) -> Dictionary:
	var d := {}
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0:
				d[(int(c.r * 255.0) << 16) | (int(c.g * 255.0) << 8) | int(c.b * 255.0)] = 1
	return d



const BAYER := [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]

## Twelve kinds of damage, and how many of each a band earns.
##
## The first version of this had five, and all five DARKENED — stain, streak,
## gouge, hole, patch. That is one register, and a hull can only get so
## interesting while every mark on it is a shadow. `bare`, `buckle` and `weld`
## work the other way, lightening toward the metal under the paint, and they are
## what stop a wrecked ship reading as a dirty one.
##
## Ordered roughly from atmosphere to event: the grime at the top happens to a
## ship that is merely OLD, the wounds at the bottom happen to a ship that was
## HIT. A band earns more of everything, but the shape of the list is why a
## marked hull looks neglected and a wrecked one looks shot.
## WHAT THE THING IS MADE OF. Not called Material — Godot already owns that name
## and shadowing it in a class_name script is a debugging afternoon nobody needs.
##
## A weld bead on a whale is nonsense, and so is a riveted patch, and so is
## buckled plating. The reverse holds too: a hull does not bruise and it does not
## SCAR, because scarring is a thing a body does afterwards and a machine has no
## afterwards — somebody has to come and weld it. That asymmetry is the most
## useful thing in this enum. It is the difference between damage that happened
## TO a thing and damage the thing then lived through.
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

## Living things, and megafauna in particular. Shares the ops that are about
## SPACE rather than about metal — pitting, scorching, cracking, impact — and
## replaces everything that assumes a fabricated surface.
##
## `barnacle` is not damage at all and belongs here anyway: the art direction
## asks for "barnacles and scars on megafauna" by name, and a leviathan that has
## been alive long enough to be shot at has been alive long enough to be lived
## ON. `scar` is the other one that is not damage — it is damage SURVIVED, and
## it is why an old whale reads differently from a beaten ship.
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

## What KIND of damage this hull takes, decided once per ship from its seed.
##
## Without this, every ship in the game suffers the same twelve things in the
## same proportions and runs differ only in where the marks land — which is
## variety of PLACEMENT, and reads as one ship photographed from twelve angles.
## Weighting the mix gives a hull a character: this one is pitted and cracked
## from a long time in the cold, that one is gouged and scorched because
## something shot at it.
##
## Weights are coarse on purpose. A zero means that kind of damage is simply
## absent from this ship, which is a stronger statement than "less of it" and is
## most of where the variety comes from.
const MIX := [0.0, 0.0, 0.5, 1.0, 1.0, 1.5, 2.0]

static func _profile(seed_in: int, sub_: int) -> Dictionary:
	var r := Lcg.new(_mix(seed_in, 0x5EED))
	var out := {}
	# Staining and streaking are never absent. Every hull that has been anywhere
	# is dirty, and a ship with no grime at all but a hole in it looks assembled
	# rather than damaged.
	for op in ops_for(sub_):
		var w: float = MIX[r.upto(MIX.size())]
		# The ambient layer is never absent. Every hull that has been anywhere is
		# dirty and every animal that has been alive is marked; a subject with a
		# hole in it and nothing else looks assembled rather than damaged.
		if op.id == &"stain" or op.id == &"streak" or op.id == &"bruise":
			w = maxf(w, 1.0)
		out[op.id] = w
	return out

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


## Micrometeorite pitting. The one kind of damage nobody did to you — it is what
## the cold does to a hull that has simply been out there a long time. Scattered
## single pixels, occasionally with a lit rim, never in a pattern.
static func _pit(p: Plate, r: Lcg, n: int) -> void:
	for _i in n:
		var at := _spot(p, r)
		if at.x < 0:
			continue
		# TIGHTER AND FEWER than the first cut, which put 16 specks over a wide
		# radius and covered the ship in what read as static rather than as
		# pitting. A cluster says a swarm went past on one side; an even scatter
		# says the renderer is noisy.
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


## Paint scraped back to the metal underneath. LIGHTENS, which is the whole
## point of it: everything else here is a shadow, and a hull covered only in
## shadows reads as dirty rather than damaged. This is the one that takes the
## livery off in patches instead of dimming it.
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


## Plating pushed out of true. A ridge: lit along the top where it rises, dark
## underneath where it falls away — the same two-plane rule as everything else,
## which is what stops it reading as another scratch.
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


## A weld bead. Repair, not damage — a raised seam of remelted metal, brighter
## than the plate, with the heat-stain of the weld either side of it. Pairs with
## `patch`: one is a plate bolted over a hole, this is the hole simply closed.
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


## Scorching, fanning DOWNSTREAM from a point. Directional on purpose: a burn
## has a source, and a cone says something arrived from somewhere where a blob
## says the hull spontaneously got dirty.
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


## Subdermal. Spreads soft and wide with NO edge and NO highlight, which is what
## separates it from a stain: dirt sits on a surface and has a boundary, a bruise
## is under one and does not. Two overlapping bruises deepen where they meet,
## because darken() reads what is already there.
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


## An opened cut. Wider and more irregular than a gouge, and crucially NOT
## straight — a gouge is something dragged across a surface, a gash is something
## that went in. Dark trough, torn pale edge on both lips rather than one,
## because flesh parts on both sides where plate only lifts on the lit one.
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


## Tissue gone, and the lighter stuff underneath showing. Ragged by
## construction: the radius wobbles per column, so no part of the boundary is a
## curve anybody drew.
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


## Fluid, running down and drying out. Same gravity rule as grime streaking, but
## it starts DARK and thins rather than fading evenly, because it came out of
## something rather than settling on it.
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


## Dead tissue. The only operation that DESATURATES rather than darkening or
## lightening: it pulls a colour toward its own grey instead of toward black,
## which is what makes a patch read as dying rather than as shadowed.
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


## NOT DAMAGE. Damage survived — a raised line of new tissue, paler than what is
## around it. This is the operation a machine can never have: a hull that is cut
## stays cut until somebody welds it, where a body closes its own wounds and
## keeps the record. An animal covered in scars has WON several times, and that
## reads completely differently from a ship covered in patches.
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


## Also not damage. Things that live on a thing that has been alive a long time,
## which the art direction asks for by name. Clusters rather than a scatter,
## because barnacles colonise: dark shells with one lit pixel each.
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


## Where something hit. The only COMPOSITE operation: a crater, short gouges
## thrown radially out of it, and a burn trailing off downstream.
##
## It exists because the rest of this file draws damage that merely EXISTS, and
## a hull wants at least one mark on it that clearly HAPPENED — with a direction
## and an order of events. One impact does more for a ship reading as attacked
## than a dozen more gouges would.
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
	# ONE STREAM PER OPERATION, AND THE BAND IS NOT IN THE SEED. Both halves are
	# required for damage to accumulate rather than reshuffle.
	#
	# The band was in the seed and every operation shared one stream, which meant
	# a ship crossing from marked to mauled drew an entirely different set of
	# scars — measured at 16% overlap, which is chance. The dent taken at half
	# hull healed, and a new one opened somewhere else. A hull is a record of
	# what has happened to it, and that made it a record of nothing.
	#
	# Seeded per operation rather than per pass so the counts cannot interfere:
	# sharing one stream, drawing eight stains instead of four would leave the
	# streaks starting from a different place in the sequence, and they would
	# move too. Given its own stream, each operation's first N draws are the same
	# at every band and a worse band simply draws MORE of them.
	# IN OPS ORDER, which is grime first and wounds last, so a gouge cuts THROUGH
	# the staining rather than being buried under it and an impact lands on top
	# of everything. Reordering this list reorders the ship's history.
	for i in ops.size():
		var op: Dictionary = ops[i]
		var base: int = op.n[t]
		if base == 0:
			continue
		var n := int(round(float(base) * float(mixw.get(op.id, 1.0))))
		if n <= 0:
			continue
		# One stream per operation, seeded independently of the band and of the
		# other operations. Both matter: without the first a worse band redraws
		# the ship from scratch, and without the second changing one operation's
		# count shifts every operation after it.
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


## Worn, and remembered. ShipView repaints whenever the idle bob moves, so this
## is the entry every caller should use — the uncached one is a whole-image pass
## and would run several times a second otherwise.
##
## Keyed on the SPRITE's path rather than the hull's, because a looted hull is a
## duplicate() of a catalogue frame: same art, different stats, and two of them
## at the same grade should wear identically.
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


## How beaten up, as one of four bands. QUANTISED on purpose: `worn()` is a pass
## over every pixel in the sprite, and hull points change constantly in a fight.
## Four bands means a ship rebuilds its damage at most three times in a run
## rather than on every point it loses, and the cache holds all four after that.
##
## The first band is deliberately wide. Losing a few points should not visibly
## scar a ship — a hull is not a progress bar, and the first mark ought to mean
## something went wrong rather than that the fight started.
static func band_for(damage: float) -> int:
	if damage < 0.22:
		return 0
	if damage < 0.48:
		return 1
	if damage < 0.74:
		return 2
	return 3


## A wear seed: THE SHIP, THE PILOT, AND THE RUN.
##
## Deliberately not the band — a worse band must draw further along the same
## sequence, not a different one, or damage reshuffles instead of accumulating.
## Everything else varies, and each part earns its place:
##
##   the HULL, so a Bastion does not wear a Cutter's scars.
##   the PILOT, so two Ironsides in one party are two ships and not one drawn
##     twice. `ShipBuild.pilot` is already on the wire for the convoy strip.
##   the RUN, so the same chassis flown again is scarred differently. This is
##     what makes damage feel like something that happened rather than something
##     the hull was shipped with.
##
## PASSED IN RATHER THAN READ. `Rng.master` is the obvious source for the run
## and this could reach for it directly, but then a headless sheet would render
## a different ship on every invocation and there would be no way to ask for a
## specific one. The caller knows which run it means.
##
## Co-op holds because every part is agreed: a peer's ship is drawn from THEIR
## HullData and THEIR pilot name on YOUR machine, and the master seed is shared
## — that is what puts four players in one galaxy. Both machines compute the
## same scars for the same ship.
static func seed_for(h: HullData, pilot: String = "", run_seed: int = 0) -> int:
	if h == null:
		return 0
	var v := absi(hash(h.name))
	v = _mix(v, absi(hash(pilot)))
	v = _mix(v, absi(run_seed))
	return v % 100003


## Avalanche two integers together. Same shape as Rng._mix and for the same
## reason: three seed sources added rather than mixed would collide constantly,
## because hull names and pilot names are short and their hashes are not spread.
static func _mix(a: int, b: int) -> int:
	var v := (a ^ (b + 0x9E3779B9 + (a << 6) + (a >> 2))) & 0x7FFFFFFF
	v = (v ^ (v >> 15)) * 0x2545F491
	return absi(v) & 0x7FFFFFFF
