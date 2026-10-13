class_name ShipBreakup
extends Control

## A SHIP COMING APART, cut out of whatever picture the ship is.
##
## Jon (Oct 13): "Also can we do death animations?" -- for enemy ships. The
## enemy art is being replaced by kept PixelLab sprites while this is written,
## so nothing here may know what a ship looks like: it is handed the ship's own
## pixels (`EnemyArt`'s canvas, or any sprite) and cuts them up itself.
##
## THE CUT. A few large chunks (the "majors") split along jagged cracks -- a
## Voronoi of seeds spread along the hull, its boundaries roughened by value
## noise so a crack never runs straight -- and a band of shards along each crack,
## carved out of the majors and cut small. The shards are what flies; the majors
## drift a few pixels apart and STAY: their resting places are the wreck you
## loot, so the last frame of this and `wreck_image` are the same picture.
##
## LIGHT AS LIGHT (memory draw-light-as-light). The glow along the cracks is not
## a coloured outline: each major carries a light map built from its own crack
## pixels -- a white-hot core, falloff over five pixels, the outer steps
## dithered 2x2 -- drawn ADDITIVELY and cooled from white through orange to red
## by multiplying its colour. Its strength is stepped and eased, never sampled
## from noise, so it cannot flicker.
##
## WHOLE PIXELS. Positions round; a shard tumbles in quarter turns, which are the
## only rotations pixel art survives without shimmering (turn-pixel-art-in-
## whole-pixel-steps); a major never turns at all.
##
## SOUND FOLLOWS WHAT YOU SEE. `broke` fires on the frame a break becomes
## visible, with how big it is; the screen plays the explosion there. Nothing
## here plays a sound itself, so a harness can film it silent.
##
## TEN MORE (Oct 13). Jon on A, B and C: "these death animations are sick as
## FUCK ... Can you create like 10 more". D to M are each a different IDEA, not
## a re-timing: a reactor breach, a chain of blasts, an engine overload, a
## decompression, a beam slice, a disintegration, a collapse into a singularity,
## a shield popping first, a melt, a crumple. They share A-C's rules and add:
##   - SPACE, NOT EARTH. Nothing rises like smoke or falls "down": debris and
##     gas drift and tumble, embers leave a crack outward. (A-C's shards settle
##     a pixel or two downward; the new ones never do.)
##   - Each one's cut is its own (`_cut_new`): wedges round a hole for a breach,
##     one straight line for a slice, folds for a crumple, a front for a
##     disintegration. MELT and CRUMPLE deform the hull first, in a few held
##     steps, and are cut from the deformed picture, so the wreck is deformed.
##   - `moment` names every visible event a sound can follow (a pop, a hiss
##     that lasts, a crunch), with its length; `broke` still fires on the
##     explosive ones. `SOUND` lists them per style.
##   - The last frame is `wreck_image` exactly (`rest_image` proves it), with
##     nothing of light left over: every glow and mote is out before the end.

signal broke(strength: float)
## Every visible moment a sound can follow. `length` > 0 for one that lasts (a
## hiss, a drone), in seconds; `kind` names it -- `SOUND` lists each style's.
signal moment(kind: StringName, strength: float, length: float)
signal finished

enum Style { SNAP, BURN, IMPLODE, BREACH, CHAIN, OVERLOAD, VENT, SLICE, DISSOLVE, COLLAPSE,
	SHIELD, MELT, CRUMPLE, GLOWOUT, BLOOM, PART }

## How long each style runs to its resting wreck, seconds. A normal kill is held
## for this before the fight is allowed to end (audit item 2 as Jon ruled it).
const LIFE := {Style.SNAP: 1.15, Style.BURN: 1.6, Style.IMPLODE: 1.45,
	Style.BREACH: 1.6, Style.CHAIN: 1.75, Style.OVERLOAD: 1.5, Style.VENT: 1.7,
	Style.SLICE: 1.4, Style.DISSOLVE: 1.8, Style.COLLAPSE: 1.6, Style.SHIELD: 1.65,
	Style.MELT: 2.0, Style.CRUMPLE: 1.5,
	Style.GLOWOUT: 2.2, Style.BLOOM: 2.0, Style.PART: 2.0}
## Letter and name, as the pick page shows them.
const NAMES := {Style.SNAP: "A  SNAP", Style.BURN: "B  BURN", Style.IMPLODE: "C  IMPLODE",
	Style.BREACH: "D  BREACH", Style.CHAIN: "E  CHAIN", Style.OVERLOAD: "F  OVERLOAD",
	Style.VENT: "G  VENT", Style.SLICE: "H  SLICE", Style.DISSOLVE: "I  DISSOLVE",
	Style.COLLAPSE: "J  COLLAPSE", Style.SHIELD: "K  SHIELD", Style.MELT: "L  MELT",
	Style.CRUMPLE: "M  CRUMPLE", Style.GLOWOUT: "N  GLOW OUT", Style.BLOOM: "O  BLOOM",
	Style.PART: "P  PART"}
const BLURB := {
	Style.SNAP: "One flash, the hull cracks white and snaps apart, shards fly fast.",
	Style.BURN: "The cracks heat up and shed fire first, then the hull splits and peels away slowly.",
	Style.IMPLODE: "Light gathers in the cracks and the core, the hull pulls in, then a flash blows it outward.",
	Style.BREACH: "The reactor glows, then a white ball of light and a shock ring burst out and tear the hull open from the middle.",
	Style.CHAIN: "Small blasts run along the hull from the engines to the nose, then the whole ship breaks.",
	Style.OVERLOAD: "The engines flare white, the ship lurches forward, and the back end blows off.",
	Style.VENT: "Air jets out of two holes and shoves the ship, then it tears in half and the halves spin apart.",
	Style.SLICE: "A beam cuts one straight line through the middle; the two halves drift apart, glowing at the cut.",
	Style.DISSOLVE: "The hull turns to drifting sparks of light from the back, eating half the ship.",
	Style.COLLAPSE: "A tiny black hole forms inside, swallows the middle and pulls the pieces in, then pops.",
	Style.SHIELD: "A hex shield flickers and shatters into light, then the hull cracks and breaks.",
	Style.MELT: "The hull glows, goes soft and sags, blobs of molten metal float off, and it tears in two.",
	Style.CRUMPLE: "The hull folds up like crushed metal in four crunches, then rips apart at the folds.",
	Style.GLOWOUT: "Creatures. Its lights flare once and go out from head to tail while the body slowly curls and drifts, dimming.",
	Style.BLOOM: "Creatures. It flares, then a cloud of glowing spores blooms out of it and thins away as it goes still and dark.",
	Style.PART: "Creatures. It parts softly along its segments, glowing fluid drifting from the seams as its lights fade."}
## What a sound designer follows, per style: each `moment` kind, when (seconds
## from the death), and whether it lasts. Read off the code that draws it, and
## checked against what the harness records (DeathStyles writes them out).
const SOUND := {
	Style.SNAP: "0.00 break (the flash); 0.0-0.8 shards and sparks",
	Style.BURN: "0.00 burst (cracks catch, weak); 0.0-1.2 crackle of fire; 0.42 break",
	Style.IMPLODE: "0.0-0.42 rising gather (light pulls in); 0.42 break",
	Style.BREACH: "0.00 charge, 0.35 long (reactor whine); 0.35 breach (the boom); 0.35 shockwave, 0.75 long (a rushing sweep); 0.40 debris, 0.9 long",
	Style.CHAIN: "0.00 / 0.20 / 0.37 / 0.52 / 0.64 pop (five blasts, quickening, louder); 0.82 break; 0.86 debris, 0.8 long",
	Style.OVERLOAD: "0.00 spool, 0.55 long (engine whine rising); 0.40 lurch (a jolt); 0.55 blow (the engines go); 0.60 debris, 0.8 long",
	Style.VENT: "0.00 vent, 0.95 long; 0.15 vent, 0.85 long (two hisses, sputtering at the end); 0.70 split (tear); 0.70 gas, 0.45 long (rush); 0.74 debris; 1.00 / 1.12 sputter",
	Style.SLICE: "0.00 beam, 0.28 long (the cut); 0.30 sever (clunk, halves part); 0.30 sizzle, 1.0 long (cooling)",
	Style.DISSOLVE: "0.00 ignite; 0.00 fizz, 1.2 long (crackle, strongest at first); 1.20 fade, 0.35 long",
	Style.COLLAPSE: "0.00 form; 0.00 pull, 1.0 long (drone rising); 0.2-0.95 swallow ticks (each piece eaten); 1.00 collapse (the pop); 1.00 ring, 0.45 long",
	Style.SHIELD: "0.00 shield_up; 0.12 / 0.22 / 0.30 flicker; 0.42 shatter (glass); 0.60 crack, 0.22 long; 0.82 break; 0.86 debris, 0.7 long",
	Style.MELT: "0.00 heat, 0.6 long (sizzle up); 0.35 slump, 0.95 long (groan); 0.4-1.2 drip ticks; 1.30 tear; 1.35 cool, 0.6 long (ticking)",
	Style.CRUMPLE: "0.00 / 0.20 / 0.38 / 0.54 crunch (four, heavier each); 0.72 rip; 0.76 debris, 0.7 long",
	Style.GLOWOUT: "0.00 flare (a last pulse); 0.00 groan, 1.8 long; 0.30 curl, 1.3 long (stretch, creak); 0.35 / 0.65 / 0.95 / 1.25 dim (each part of it going dark); 1.70 still",
	Style.BLOOM: "0.00 flare; 0.25 bloom (a soft whump); 0.25 spores, 1.0 long (a breathy hiss, thinning); 0.70 / 0.90 / 1.10 dim; 1.30 still",
	Style.PART: "0.00 pulse; 0.15 / 0.35 / 0.55 tear (soft, wet, each a little bigger); 0.15 fluid, 1.4 long (drips, bubbles); 0.70 on, one dim a segment; 1.60 still"}
## The core's guard: a chain of bursts first, then the break, then a long cool.
const BOSS_PRELUDE := 1.5
const BOSS_EXTRA := 0.9

const HEAT_RAMP: Array[Color] = [Color("#fff6e2"), Color("#ffdca0"), Color("#ffa63c"),
	Color("#cc641c"), Color("#964214"), Color("#5c280c")]
const WRECK_TINT := Color(0.4, 0.4, 0.45)

var style: int = Style.SNAP
var boss: bool = false
var t: float = 0.0
var duration: float = 1.2
var done: bool = false
## Off for a harness that steps `advance` by hand.
var auto: bool = true

var _img: Image
var _origin: Vector2 = Vector2.ZERO   ## where the image's (0,0) sits, in this control
var _cut: Dictionary = {}
var _majors: Array = []   ## {tex, glow, at (Vector2i image px), off (final), crack (PackedVector2Array)}
var _shards: Array = []   ## {tex, at, v, spin, rot0, life, born}
var _motes: Array = []    ## {p, v, age, life, kind}
var _beats: Array = []    ## [time, strength, fired]
var _flash_tex: ImageTexture
var _flashes: Array = []  ## {p (Vector2), t0, r_scale}
var _light: Control
var _centre: Vector2
var _rng := RandomNumberGenerator.new()


class Layer extends Control:
	var paint: Callable
	func _draw() -> void:
		paint.call(self)


## `img` is the ship's whole canvas; `used` the ship's box in it (EnemyArt's
## `used_rect`, or the sprite's ink); `origin` where the canvas's top-left sits
## in this control's space. Same `seed`, same cut -- see `wreck_image`.
func setup(img: Image, used: Rect2i, origin: Vector2, the_style: int, seed: int,
		is_boss: bool = false) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_img = img
	_origin = origin.round()
	style = the_style
	boss = is_boss
	_rng.seed = seed * 7919 + 17
	if style >= Style.BREACH:
		_setup_new(img, used, seed)
		_add_layers()
		return
	_cut = cut(img, used, seed, is_boss)
	duration = float(LIFE[style]) + (BOSS_PRELUDE + BOSS_EXTRA if boss else 0.0)
	_centre = _origin + Vector2(_cut.centre)
	for m in _cut.majors:
		var tex := ImageTexture.create_from_image(m.image)
		var glow := ImageTexture.create_from_image(_glow_image(m.crack, m.image.get_size()))
		_majors.append({tex = tex, glow = glow, at = m.at, off = m.off, crack = m.crack})
	for s in _cut.shards:
		var tex2 := ImageTexture.create_from_image(s.image)
		var away: Vector2 = (Vector2(s.at) + Vector2(s.image.get_size()) * 0.5) - Vector2(_cut.centre)
		var dir := away.normalized() if away.length() > 0.5 else Vector2.RIGHT.rotated(_rng.randf() * TAU)
		_shards.append({tex = tex2, at = s.at, dir = dir, size = s.image.get_size(),
			speed = _rng.randf_range(0.6, 1.4), spin = _rng.randf_range(2.0, 7.0) * (1.0 if _rng.randf() < 0.5 else -1.0),
			rot0 = _rng.randi() % 4, delay = _rng.randf_range(0.0, 1.0)})
	_flash_tex = ImageTexture.create_from_image(_radial_light(34 if boss else 22))
	_plan_beats()
	_add_layers()


func _add_layers() -> void:
	var base := Layer.new()
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.paint = _paint_body
	add_child(base)
	_light = Layer.new()
	_light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_light.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_light.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_light.material = mat
	_light.paint = _paint_light
	add_child(_light)


# ------------------------------------------------------------------ the cut

## THE PARTITION, as data, deterministic in `seed`. Static so the wreck on
## LOCAL can be drawn from the same cut long after the animation is gone.
##   majors: [{image, at (Vector2i), off (Vector2i final drift), crack (PackedVector2Array local)}]
##   shards: [{image, at}]
##   centre: Vector2i
## D-M cut their own way (`_cut_new`); A-C's cut is untouched.
static func cut(img: Image, used: Rect2i, seed: int, is_boss: bool = false,
		the_style: int = Style.SNAP) -> Dictionary:
	if the_style >= Style.GLOWOUT:
		return _cut_creature(img, used, seed, the_style)
	if the_style >= Style.BREACH:
		return _cut_new(img, used, seed, is_boss, the_style)
	return _cut_classic(img, used, seed, is_boss)


static func _cut_classic(img: Image, used: Rect2i, seed: int, is_boss: bool) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var r := used.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var w := r.size.x
	var h := r.size.y
	var n := w * h
	var mask := PackedByteArray()
	mask.resize(n)
	for y in h:
		for x in w:
			var c := img.get_pixel(r.position.x + x, r.position.y + y)
			mask[y * w + x] = 1 if c.a > 0.6 else 0
	# Lone pixels are the canvas's starfield, not hull.
	var keep := PackedByteArray()
	keep.resize(n)
	var cx := 0.0
	var cy := 0.0
	var count := 0
	for y in h:
		for x in w:
			if mask[y * w + x] == 0:
				continue
			var nb := 0
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					if dx == 0 and dy == 0:
						continue
					var xx: int = x + dx
					var yy: int = y + dy
					if xx >= 0 and yy >= 0 and xx < w and yy < h and mask[yy * w + xx] == 1:
						nb += 1
			if nb >= 2:
				keep[y * w + x] = 1
				cx += x
				cy += y
				count += 1
	if count == 0:
		return {majors = [], shards = [], centre = r.get_center()}
	cx /= count
	cy /= count
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


## How far each style throws the chunks apart, from the cut's own direction.
## The wreck is drawn from the same number, so the last frame is the wreck.
const DRIFT := {Style.SNAP: 1.7, Style.BURN: 1.3, Style.IMPLODE: 1.0}

static func drift(off: Vector2i, the_style: int) -> Vector2i:
	return Vector2i((Vector2(off) * float(DRIFT.get(the_style, 1.0))).round())


## A dead ship's engines are out: the flame and the lit ports, the brightest
## warm pixels, go to the darkest ember the heat ramp has.
static func _dead_pixel(c: Color) -> Color:
	if c.a > 0.0 and c.r > 0.75 and c.r >= c.b + 0.25 and c.get_luminance() > 0.55:
		return Color(HEAT_RAMP[5].r, HEAT_RAMP[5].g, HEAT_RAMP[5].b, c.a)
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


## THE WRECK THIS LEAVES, on a canvas the size of `img`: every major at its
## resting drift, nothing else. Not darkened -- the slot greys a dead hull with
## `modulate` already, and the animation's last frame uses the same tint.
static func wreck_image(img: Image, used: Rect2i, seed: int, is_boss: bool = false,
		the_style: int = Style.SNAP) -> Image:
	var c := cut(img, used, seed, is_boss, the_style)
	var out := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	for m in c.majors:
		var im: Image = m.image
		# D-P carry their whole resting offset in `off` (drift 1). BURN's chunks
		# sag a pixel after the break (`_major_pos`) and stay there, so its wreck
		# does too -- without this the hand-off jumped a pixel (found by
		# DeathStyles' `each` check, Oct 13).
		var at: Vector2i = m.at + drift(m.off, the_style)
		if the_style == Style.BURN:
			at.y += 1
		out.blend_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), at)
	return out


## The wreck as this breakup left it, composed the way `wreck_image` composes
## one, from what is drawn now: a harness proves the two are the same picture.
func rest_image() -> Image:
	var out := Image.create(_img.get_width(), _img.get_height(), false, Image.FORMAT_RGBA8)
	for m in _majors:
		var im: Image
		var p: Vector2
		if style >= Style.BREACH:
			im = (m.images as Array)[_stage_of(m)]
			p = _major_pos_new(m) - _origin
		else:
			im = (m.tex as ImageTexture).get_image()
			p = _major_pos(m) - _origin
		out.blend_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i(p.round()))
	return out


## One major's crack light: a white core on its crack pixels, falling off over
## five, the outer steps dithered. Padded so the light spills past the metal.
const GLOW_PAD := 3

func _glow_image(crack: PackedVector2Array, sz: Vector2i) -> Image:
	var w := sz.x + GLOW_PAD * 2
	var h := sz.y + GLOW_PAD * 2
	var dist := PackedInt32Array()
	dist.resize(w * h)
	dist.fill(99)
	var q: Array[Vector2i] = []
	for p in crack:
		var v := Vector2i(int(p.x) + GLOW_PAD, int(p.y) + GLOW_PAD)
		dist[v.y * w + v.x] = 0
		q.append(v)
	var head := 0
	while head < q.size():
		var cur := q[head]
		head += 1
		var d := dist[cur.y * w + cur.x]
		if d >= GLOW_PAD:
			continue
		for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = cur.x + o.x
			var ny: int = cur.y + o.y
			if nx >= 0 and ny >= 0 and nx < w and ny < h and dist[ny * w + nx] > d + 1:
				dist[ny * w + nx] = d + 1
				q.append(Vector2i(nx, ny))
	var im := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var bayer := [0.0, 0.5, 0.75, 0.25]
	for y in h:
		for x in w:
			var d2 := dist[y * w + x]
			if d2 > GLOW_PAD:
				continue
			var thr: float = bayer[(y % 2) * 2 + (x % 2)]
			var c: Color = HEAT_RAMP[mini(d2, HEAT_RAMP.size() - 1)]
			# Outer steps dither out: present on half, then a quarter, of the
			# grid, so the falloff has no hard ring.
			if d2 == 2 and thr >= 0.5:
				continue
			if d2 == 3 and thr >= 0.25:
				continue
			var k := 1.0 if d2 == 0 else (0.7 if d2 == 1 else 0.45)
			im.set_pixel(x, y, Color(c.r * k, c.g * k, c.b * k, 1.0))
	return im


## A gathered light for the flash: a core and a stepped, dithered falloff.
static func _radial_light(radius: int) -> Image:
	var s := radius * 2 + 1
	var im := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var bayer := [0.0, 0.5, 0.75, 0.25]
	for y in s:
		for x in s:
			var d := Vector2(x - radius, y - radius).length() / float(radius)
			if d > 1.0:
				continue
			var e := pow(1.0 - d, 2.2)
			var thr: float = bayer[(y % 2) * 2 + (x % 2)]
			# Four steps, the last two dithered.
			var lvl := 0.0
			if e > 0.55:
				lvl = 1.0
			elif e > 0.28:
				lvl = 0.62
			elif e > 0.12:
				lvl = 0.36 if thr < 0.75 else 0.2
			elif e > 0.03:
				lvl = 0.18 if thr < 0.5 else 0.0
			if lvl <= 0.0:
				continue
			var c := HEAT_RAMP[0].lerp(HEAT_RAMP[2], 1.0 - lvl)
			im.set_pixel(x, y, Color(c.r * lvl, c.g * lvl, c.b * lvl, 1.0))
	return im


# ------------------------------------------------------------------ the clock

## When things happen, per style, as fractions of the base life. The boss runs
## a prelude of local bursts first, each one a beat of its own.
var _split_at := 0.0     ## when the majors start to drift and the shards fly
var _split_dur := 0.3

func _plan_beats() -> void:
	var lead := 0.0
	if boss:
		# Three to four bursts across the body, quickening, each a flash at a
		# crack and a sound.
		var times := [0.0, 0.55, 0.95, 1.25]
		for i in times.size():
			var m: Dictionary = _majors[i % _majors.size()] if not _majors.is_empty() else {}
			var p := _centre
			if not m.is_empty() and not (m.crack as PackedVector2Array).is_empty():
				var cr: PackedVector2Array = m.crack
				p = _origin + Vector2(m.at) + cr[_rng.randi() % cr.size()]
			_beats.append([float(times[i]), 0.45 + 0.1 * i, false, p])
		lead = BOSS_PRELUDE
	match style:
		Style.SNAP:
			_split_at = lead
			_split_dur = 0.22
			_beats.append([lead, 1.0, false, _centre])
		Style.BURN:
			_split_at = lead + 0.42
			_split_dur = 0.6
			_beats.append([lead, 0.45, false, _centre])
			_beats.append([lead + 0.42, 1.0, false, _centre])
		Style.IMPLODE:
			_split_at = lead + 0.42
			_split_dur = 0.25
			_beats.append([lead + 0.42, 1.0, false, _centre])


func _process(delta: float) -> void:
	if auto and not done:
		advance(delta)


## One step of the clock. Public so a film can step it 1/30 s a frame.
func advance(delta: float) -> void:
	if done:
		return
	var was := t
	t += delta
	for b in _beats:
		if not b[2] and t >= float(b[0]):
			b[2] = true
			_on_beat(float(b[1]), b[3])
	if style >= Style.BREACH:
		_advance_new(delta)
		return
	_step_motes(delta)
	if was < _split_at and t >= _split_at:
		_burst_sparks(_centre, 26 if not boss else 44, 210.0)
	if t >= duration:
		done = true
		finished.emit()
	queue_redraw()
	for c in get_children():
		(c as CanvasItem).queue_redraw()


func _on_beat(strength: float, at: Vector2) -> void:
	_flashes.append({p = at, t0 = t, s = strength})
	_burst_sparks(at, int(10 + 14 * strength), 150.0 * (0.6 + strength))
	moment.emit(&"break" if strength >= 0.9 else &"burst", strength, 0.0)
	broke.emit(strength)


# ------------------------------------------------------------------ motion

func _ease_out(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 1.0 - pow(1.0 - x, 3.0)


## Where a major is now, in whole pixels.
func _major_pos(m: Dictionary) -> Vector2:
	var base := _origin + Vector2(m.at)
	var off := Vector2(drift(m.off, style))
	var k := 0.0
	if t >= _split_at:
		k = _ease_out((t - _split_at) / maxf(0.05, _split_dur * 2.2))
	var extra := Vector2.ZERO
	if style == Style.IMPLODE and t < _split_at and t > _split_at - 0.14:
		# The pull in before it lets go: one or two pixels toward the middle.
		var pull := (_centre - (base + Vector2((m.tex as ImageTexture).get_size()) * 0.5)).normalized()
		extra = (pull * 2.0).round()
	elif style == Style.BURN and t >= _split_at:
		# A slow sag after the break: the chunks keep drifting a little.
		extra = Vector2(0, (t - _split_at) * 1.5).round()
		extra.y = minf(extra.y, 1.0)
	return (base + off * k + extra).round()


func _shard_state(s: Dictionary) -> Dictionary:
	var start := _split_at
	if style == Style.BURN:
		# Peel off one by one rather than all at once.
		start += float(s.delay) * 0.55
	if t < start:
		return {p = _origin + Vector2(s.at), rot = 0, a = 1.0, out = false}
	var age := t - start
	var spd := (200.0 if style == Style.SNAP else (95.0 if style == Style.BURN else 170.0)) * float(s.speed)
	if boss:
		spd *= 0.8
	# Drag: distance travelled with exponential slowdown.
	var drag := 2.4
	var dist := spd * (1.0 - exp(-drag * age)) / drag
	var p: Vector2 = _origin + Vector2(s.at) + (s.dir as Vector2) * dist
	p.y += 6.0 * age * age   # a little settle, so it is not a perfect starburst
	var rot := (int(s.rot0) + int(floor(age * float(s.spin)))) % 4
	var life := 0.75 if style == Style.SNAP else (1.0 if style == Style.BURN else 0.85)
	var a := 1.0
	if age > life * 0.6:
		# Stepped fade, three levels.
		var f := (age - life * 0.6) / (life * 0.4)
		a = 0.66 if f < 0.34 else (0.33 if f < 0.67 else (0.0 if f >= 1.0 else 0.15))
	return {p = p.round(), rot = rot, a = a, out = age >= life}


## How hot the cracks are, 0..1, stepped in quarters so the glow holds rather
## than shimmering, and how far it has cooled (1 white-hot, 0 dull red).
func _crack_heat() -> Vector2:
	var lead := BOSS_PRELUDE if boss else 0.0
	var tt := t - lead
	var on := 0.0
	var heat := 1.0
	match style:
		Style.SNAP:
			on = 1.0 if tt < 0.15 else clampf(1.0 - (tt - 0.15) / 0.75, 0.0, 1.0)
			heat = clampf(1.0 - tt / 0.6, 0.0, 1.0)
		Style.BURN:
			on = clampf(tt / 0.3, 0.0, 1.0) if tt < 0.42 else clampf(1.0 - (tt - 0.9) / 0.7, 0.0, 1.0)
			heat = 1.0 if tt < 0.5 else clampf(1.0 - (tt - 0.5) / 0.9, 0.0, 1.0)
		Style.IMPLODE:
			on = clampf(tt / 0.35, 0.0, 1.0) if tt < 0.42 else clampf(1.0 - (tt - 0.5) / 0.7, 0.0, 1.0)
			heat = clampf(0.5 + tt, 0.0, 1.0) if tt < 0.42 else clampf(1.0 - (tt - 0.42) / 0.8, 0.0, 1.0)
	if boss and tt < 0.0:
		# The prelude: cracks wake one burst at a time.
		on = clampf((t + 0.2) / BOSS_PRELUDE, 0.0, 1.0) * 0.75
		heat = 0.7
	if boss and tt > 0.0 and tt < 0.6:
		on = minf(1.0, on + 0.25)
	return Vector2(snappedf(on, 0.25), snappedf(heat, 0.25))


# ------------------------------------------------------------------ motes

func _burst_sparks(at: Vector2, count: int, speed: float) -> void:
	for i in count:
		var a := _rng.randf() * TAU
		var v := Vector2(cos(a), sin(a)) * _rng.randf_range(0.35, 1.0) * speed
		_motes.append({p = at + Vector2(_rng.randf_range(-6, 6), _rng.randf_range(-3, 3)),
			v = v, age = 0.0, life = _rng.randf_range(0.14, 0.38), kind = 0})


## Fire: embers leave the hot cracks while they are hot.
func _step_motes(delta: float) -> void:
	var hv := _crack_heat()
	var rate := 0.0
	match style:
		Style.SNAP: rate = 40.0
		Style.BURN: rate = 230.0
		Style.IMPLODE: rate = 55.0
	if boss:
		rate *= 1.8
	rate *= hv.x
	var n := int(rate * delta + _rng.randf())
	for i in n:
		if _majors.is_empty():
			break
		var m: Dictionary = _majors[_rng.randi() % _majors.size()]
		var cr: PackedVector2Array = m.crack
		if cr.is_empty():
			continue
		var p := _major_pos(m) + cr[_rng.randi() % cr.size()]
		_motes.append({p = p, v = Vector2(_rng.randf_range(-14, 14), _rng.randf_range(-26, -6)),
			age = 0.0, life = _rng.randf_range(0.35, 0.9), kind = 1,
			big = _rng.randf() < 0.3})
	var kept: Array = []
	for mo in _motes:
		mo.age += delta
		if mo.age >= mo.life:
			continue
		mo.p += mo.v * delta
		mo.v *= (0.86 if mo.kind == 0 else 0.97)
		kept.append(mo)
	_motes = kept


# ------------------------------------------------------------------ drawing

func _paint_body(ci: CanvasItem) -> void:
	if style >= Style.BREACH:
		_paint_body_new(ci)
		return
	var k := 0.0
	if t > _split_at:
		k = clampf((t - _split_at) / maxf(0.2, duration - _split_at - 0.15), 0.0, 1.0)
	# The hull cools to the wreck's grey in three steps, landing exactly on
	# the tint the slot gives a dead ship.
	var steps := snappedf(k, 0.34)
	var tint := Color.WHITE.lerp(WRECK_TINT, minf(1.0, steps * 1.0))
	if done:
		tint = WRECK_TINT
	for m in _majors:
		ci.draw_texture(m.tex, _major_pos(m), tint)
	for s in _shards:
		var st := _shard_state(s)
		if st.out or float(st.a) <= 0.0:
			continue
		var sz: Vector2 = Vector2(s.size)
		var c := tint
		c.a = float(st.a)
		ci.draw_set_transform(Vector2(st.p) + sz * 0.5, float(st.rot) * PI * 0.5, Vector2.ONE)
		ci.draw_texture(s.tex, -sz * 0.5, c)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _paint_light(ci: CanvasItem) -> void:
	if style >= Style.BREACH:
		_paint_light_new(ci)
		return
	if t <= 0.0:
		return
	var hv := _crack_heat()
	if hv.x > 0.0:
		# Multiplying an additive light's colour cools it: white-hot keeps all
		# three channels, cooling drops blue then green.
		var heat := hv.y
		var col := Color(hv.x, hv.x * (0.45 + 0.55 * heat), hv.x * (0.15 + 0.85 * heat * heat), 1.0)
		for m in _majors:
			ci.draw_texture(m.glow, _major_pos(m) - Vector2(GLOW_PAD, GLOW_PAD), col)
	# Flashes: up at once, held two frames, falling in three steps.
	for f in _flashes:
		var age := t - float(f.t0)
		var life := 0.28 if not boss else 0.36
		if age > life:
			continue
		var lvl := 1.0 if age < 0.07 else (0.6 if age < 0.14 else (0.32 if age < 0.21 else 0.14))
		lvl *= clampf(float(f.s), 0.3, 1.0)
		var sz := _flash_tex.get_size()
		# NEVER SCALED: a resampled dither is mush. Strength is brightness.
		ci.draw_texture(_flash_tex, (Vector2(f.p) - Vector2(sz) * 0.5).round(), Color(lvl, lvl, lvl, 1.0))
	for mo in _motes:
		var f2: float = mo.age / mo.life
		var c: Color
		if mo.kind == 0:
			c = HEAT_RAMP[0] if f2 < 0.4 else (HEAT_RAMP[2] if f2 < 0.75 else HEAT_RAMP[4])
			var p: Vector2 = (mo.p as Vector2).round()
			ci.draw_rect(Rect2(p, Vector2.ONE), c)
			var tail: Vector2 = ((mo.p as Vector2) - (mo.v as Vector2).normalized() * 2.0).round()
			if tail != p:
				ci.draw_rect(Rect2(tail, Vector2.ONE), c * Color(0.5, 0.5, 0.5, 1))
		else:
			c = HEAT_RAMP[1] if f2 < 0.25 else (HEAT_RAMP[2] if f2 < 0.5 else (HEAT_RAMP[3] if f2 < 0.8 else HEAT_RAMP[5]))
			var sz := Vector2(2, 2) if mo.get("big", false) and f2 < 0.5 else Vector2.ONE
			ci.draw_rect(Rect2((mo.p as Vector2).round(), sz), c)


# ================================================================== D-M: THE CUTS
#
# Everything below is the ten newer styles. Static where the wreck needs it:
# `wreck_image` has to draw the same resting layout long after the animation is
# gone, so every deformation and offset is decided here from the seed alone.

## Room round the ship's box for a hull that deforms (MELT sags, CRUMPLE folds).
const HULL_PAD := 6
## How much of the hull a disintegration leaves: the front stops here (0 bow, 1 stern).
const DIS_END := 0.5
const MELT_STEPS := 8
const CRUMPLE_K: Array[float] = [0.0, 0.15, 0.3, 0.42, 0.55, 0.68, 0.8, 0.9, 1.0]
const CRUMPLE_AT: Array[float] = [0.0, 0.2, 0.38, 0.54]
const CHAIN_AT: Array[float] = [0.0, 0.2, 0.37, 0.52, 0.64]
## Vented air: white at the hole, thinning to a cold blue.
const GAS: Array[Color] = [Color("#f2fbff"), Color("#c4e6f6"), Color("#86b6d2"), Color("#4a7690")]
## Disintegration: a cold white-teal, nothing like fire.
const TEAL: Array[Color] = [Color("#eafffa"), Color("#97f2df"), Color("#45bcaa"), Color("#1f716b")]
const SHIELD_COL := Color("#7cd8ff")
const VOID_COL := Color("#dcd4ff")
const SOOT := Color(0.17, 0.12, 0.10)
## The moments that are explosions: `broke` fires on these too.
const BOOMS := [&"breach", &"pop", &"break", &"blow", &"split", &"shatter", &"rip", &"tear",
	&"crunch", &"collapse", &"sever"]


## The hull as a picture to work on: the canvas round the ship's box with room
## to deform into, its colours (engines already dark), which pixels are hull,
## its middle and its box. Lone pixels are the canvas's starfield, as in `cut`.
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

## MELT at `k` (0 whole, 1 slumped): the hull goes soft. Every pixel is fetched
## from a little further out and a little aside, so the hull draws in toward its
## own middle line and its outline wanders; the far edges (fins, guns) wander
## most. Thin parts with fewer than two neighbours run off, pass by pass -- those
## are the drips. Then the colours run together. Deterministic in `seed`, so the
## film's steps and the wreck agree.
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

static func _melt_field(H: Dictionary, seed: int) -> Dictionary:
	var key := "%d:%d:%d:%d:%d" % [seed, int(H.w), int(H.h), int(H.n), (H.r as Rect2i).position.x]
	if _melt_cache.has(key):
		return _melt_cache[key]
	if _melt_cache.size() > 16:
		_melt_cache.clear()
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
	_melt_cache[key] = {ox = ox, oy = oy}
	return _melt_cache[key]


static func _fold_x(fx: float, tilt: float, jag: Dictionary, i: int, y: float, cy: float) -> float:
	return fx + tilt * (y - cy) + 1.5 * _nz(jag, float(i) * 13.0, y)


## CRUMPLE at `k`: two or three fold lines across the hull; the segments
## between them are shoved toward the middle, kicked up and down in turn and
## sheared, so the plates stair-step like bent metal. Each fold gets a dark
## crease on one side and a lit ridge on the other, and each segment a buckle
## down its middle. Returns which segment every pixel landed in, for the cut.
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


## The engines, as points the plume streams from: the end of every row that
## reaches the stern (enemies face left, so the stern is the right), and every
## lit engine pixel (`_dead_pixel`'s test) in the back half.
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


## Shard material cut small, each kind of mark on its own (a blast's hole
## leaves as its own shards, at its own moment). Square, so a quarter turn keeps
## every pixel.
static func _shards_of(H: Dictionary, col: PackedColorArray, lab: PackedInt32Array, sm: PackedByteArray,
		rng: RandomNumberGenerator) -> Array:
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
			if rng.randf() < 0.035:
				seeds.append(p)
		var want := maxi(1, pts.size() / 26)
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
			if tv > DIS_END - 0.05:
				k = 0.45
			elif tv > DIS_END - 0.1 and ((lp.x + lp.y) & 1) == 0:
				k = 0.72
			if k < 1.0:
				var q := Color(p.r * k, p.g * k, p.b * k).lerp(SOOT, (1.0 - k) * 0.3)
				out.set_pixel(x, y, Color(q.r, q.g, q.b, p.a))
	return out


## A hot body's own light: brightest at its edges (thin metal heats first),
## falling off inward over three steps, a faint dithered fill inside and a
## dithered pixel of spill outside. Grey levels; coloured when drawn.
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
	var H := _hull_pic(img, used, HULL_PAD)
	var r: Rect2i = H.r
	if int(H.n) == 0:
		return {majors = [], shards = [], centre = r.get_center(), plan = {r = r, glob = Vector2i.ZERO,
			box = r}}
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
		box = Rect2i(r.position + Vector2i(int(H.x0), int(H.y0)), Vector2i(int(bw), int(bh)))}
	var seg := PackedInt32Array()
	if st == Style.MELT:
		var mp := _melt_pic(H, seed, 1.0)
		col = mp.col
		mask = mp.mask
	elif st == Style.CRUMPLE:
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
		Style.BREACH, Style.COLLAPSE:
			k = 6 if is_boss else 5
			lab = _lab_radial(H, mask, k, rng)
			var rh := clampf(minf(bw, bh) * 0.17, 4.0, 10.0)
			_mark_disc(H, lab, sm, c_loc, rh, _field(rng, w, h, 3), 99)
			_mark_band(H, lab, sm, 2, rng)
			if st == Style.BREACH:
				_mark_bites(H, lab, sm, 4, rng, 1)
			plan.hole = rh
		Style.CHAIN:
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
		Style.OVERLOAD:
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
		Style.VENT:
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
		Style.SLICE:
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
		Style.DISSOLVE:
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
					if tv > DIS_END:
						lab[i] = -1
						dp.append(rp + Vector2(x, y))
						dc.append(col[i])
						dt.append(tv)
					else:
						lab[i] = 0
						if tv > DIS_END - 0.08:
							ep.append(rp + Vector2(x, y))
							et.append(tv)
			plan.dis = {p = dp, c = dc, thr = dt}
			plan.edge = {p = ep, thr = et}
		Style.SHIELD:
			lab = _lab_voronoi(H, mask, k, rng)
			_mark_band(H, lab, sm, 2, rng)
			_mark_bites(H, lab, sm, 4, rng, 1)
		Style.MELT:
			k = 2
			lab = _lab_voronoi(H, mask, 2, rng)
			_mark_band(H, lab, sm, 1, rng)
		Style.CRUMPLE:
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
			Style.BREACH:
				own = Vector2i((dir * rng.randf_range(6.0, 9.0)).round())
				stages.append(_scorched(m.image, m.at, centre_c, float(plan.hole) + 9.0))
			Style.CHAIN:
				own = Vector2i((dir * rng.randf_range(3.0, 5.5)).round()) + Vector2i(0, rng.randi_range(-1, 1))
				for b in plan.blasts:
					stages.append(_scorched(stages.back(), m.at, b, 7.0))
			Style.OVERLOAD:
				if i == stern_i:
					own = Vector2i(rng.randi_range(9, 12), rng.randi_range(1, 3) * (1 if rng.randf() < 0.5 else -1))
				else:
					own = Vector2i((dir * rng.randf_range(2.0, 3.5)).round()) + Vector2i(-2, 0)
				stages.append(_scorched(m.image, m.at, plan.stern, 13.0))
			Style.VENT:
				var sg: int = plan.sgn
				if mj.size() > 1:
					own = Vector2i(-3, -6 * sg) if i == bow_i else Vector2i(3, 6 * sg)
			Style.SLICE:
				var sl: Dictionary = plan.slice
				var sd: Vector2 = sl.d
				var sn: Vector2 = sl.n
				own = Vector2i((-sn * 3.0 + sd).round()) if int(m.lab) == 0 else Vector2i((sn * 3.0 - sd).round())
			Style.COLLAPSE:
				own = Vector2i((dir * 2.0).round())
			Style.SHIELD:
				own = Vector2i((dir * rng.randf_range(3.0, 5.5)).round()) + Vector2i(0, rng.randi_range(-1, 1))
			Style.MELT:
				own = Vector2i((dir * rng.randf_range(2.0, 3.0)).round())
				stages.append(_slagged(m.image, 0.3))
				stages.append(_slagged(m.image, 0.6))
			Style.CRUMPLE:
				own = Vector2i(roundi(signf(away.x) * rng.randf_range(2.0, 4.0)), rng.randi_range(-1, 1))
			Style.DISSOLVE:
				stages.append(_charred(m.image, m.at, H, thr))
		m.own = own
		m.glob = plan.glob
		m.off = (plan.glob as Vector2i) + own
		m.dir = dir
		m.stages = stages
		m.image = stages.back()
	if st == Style.VENT:
		for j in plan.jets:
			j.major = 0
			for i in mj.size():
				if int(mj[i].lab) == int(j.lab):
					j.major = i
	var sh := _shards_of(H, col, lab, sm, rng)
	return {majors = mj, shards = sh, centre = r.position + Vector2i(int(cx), int(cy)), plan = plan}


# ================================================================== D-M: THE FILM

var _lead := 0.0          ## the boss's prelude, before a style's own clock starts
var _split_len := 0.4     ## how long the pieces take to reach their rest
var _shard_speed := 200.0
var _plan: Dictionary = {}
var _events: Array = []   ## {t, kind, s, len, p, fired}
var _rings: Array = []    ## {p, t0, r0, r1, dur, s, squash, col}
var _cells: Array = []    ## the shield's hex cells: {tex, at, dir, speed, drop}
var _plume := {}          ## engine plume light by length
var _stage_tex: Array = []    ## MELT / CRUMPLE: the whole hull at each held step
var _stage_mask: Array = []
var _stage_heat: Array = []
var _stage_at := Vector2.ZERO
var _last_stage := 0
var _dis_img: Image
var _dis_tex: ImageTexture
var _dis_order := PackedInt32Array()
var _dis_ptr := 0
var _dis_at := Vector2i.ZERO
var _last_tick := {}      ## rate limits on repeated moments

static var _warm_cache := {}
static var _white_cache := {}


static func _warm(r: int) -> ImageTexture:
	if not _warm_cache.has(r):
		_warm_cache[r] = ImageTexture.create_from_image(_radial_light(r))
	return _warm_cache[r]


## The same gathered light as `_radial_light`, in grey, to be coloured when drawn.
static func _white(r: int) -> ImageTexture:
	if _white_cache.has(r):
		return _white_cache[r]
	var im := _radial_light(r)
	for y in im.get_height():
		for x in im.get_width():
			var c := im.get_pixel(x, y)
			if c.a > 0.0:
				var l := maxf(c.r, maxf(c.g, c.b))
				im.set_pixel(x, y, Color(l, l, l, 1.0))
	_white_cache[r] = ImageTexture.create_from_image(im)
	return _white_cache[r]


## A light map's levels without its colour, to be coloured when drawn.
static func _grey(im: Image) -> Image:
	for y in im.get_height():
		for x in im.get_width():
			var c := im.get_pixel(x, y)
			if c.a > 0.0:
				var l := maxf(c.r, maxf(c.g, c.b))
				im.set_pixel(x, y, Color(l, l, l, 1.0))
	return im


static func _lv(c: Color, lvl: float) -> Color:
	return Color(c.r * lvl, c.g * lvl, c.b * lvl, 1.0)


func _setup_new(img: Image, used: Rect2i, seed: int) -> void:
	if style >= Style.GLOWOUT:
		_setup_creature(img, used, seed)
		return
	_lead = BOSS_PRELUDE if boss else 0.0
	duration = float(LIFE[style]) + (BOSS_PRELUDE + BOSS_EXTRA if boss else 0.0)
	_cut = cut(img, used, seed, boss, style)
	_plan = _cut.get("plan", {})
	_centre = _origin + Vector2(_cut.centre)
	_flash_tex = ImageTexture.create_from_image(_radial_light(34 if boss else 22))
	_plan_events()
	for m in _cut.majors:
		var stex: Array = []
		for im in m.stages:
			stex.append(ImageTexture.create_from_image(im))
		var mi: Image = m.image
		var gim := _glow_image(m.crack, mi.get_size())
		if style == Style.COLLAPSE:
			gim = _grey(gim)
		var d := {tex = stex.back(), stages = stex, images = m.stages, at = m.at, off = m.off,
			own = m.own, glob = m.glob, crack = m.crack, dir = m.dir,
			glow = ImageTexture.create_from_image(gim)}
		if style == Style.MELT:
			d.heat = ImageTexture.create_from_image(_heat_light(_alpha_mask(mi), mi.get_width(), mi.get_height(), 2))
		_majors.append(d)
	_shard_speed = {Style.BREACH: 220.0, Style.CHAIN: 170.0, Style.OVERLOAD: 200.0, Style.VENT: 120.0,
		Style.SHIELD: 200.0, Style.MELT: 55.0, Style.CRUMPLE: 120.0}.get(style, 180.0)
	var rmax := 1.0
	for s in _cut.shards:
		var im2: Image = s.image
		var sz := im2.get_size()
		var mid := Vector2(s.at) + Vector2(sz) * 0.5
		var away := mid - Vector2(_cut.centre)
		var dir := away.normalized() if away.length() > 0.5 else Vector2.RIGHT.rotated(_rng.randf() * TAU)
		var mk: int = s.mark
		var sd := {tex = ImageTexture.create_from_image(im2), at = s.at, size = sz, dir = dir, mark = mk,
			speed = _rng.randf_range(0.6, 1.4), spin = _rng.randf_range(2.0, 7.0) * (1.0 if _rng.randf() < 0.5 else -1.0),
			rot0 = _rng.randi() % 4, release = _split_at + _rng.randf_range(0.0, 0.05), life = 0.75, mode = 0}
		match style:
			Style.BREACH:
				sd.life = 0.8
				if mk == 99:
					sd.speed = float(sd.speed) * 1.1
			Style.CHAIN:
				sd.life = 0.7
				if mk >= 2:
					var bp: Vector2 = _plan.blasts[mk - 2]
					sd.release = _lead + CHAIN_AT[mk - 2] + 0.02
					var bd := mid - bp
					sd.dir = bd.normalized() if bd.length() > 0.3 else dir
					sd.speed = float(sd.speed) * 0.9
			Style.OVERLOAD:
				var stern: Vector2 = _plan.stern
				if mid.x > stern.x - 30.0:
					sd.dir = (dir + Vector2(1.4, 0.0)).normalized()
			Style.VENT:
				if mk >= 2:
					var jet: Dictionary = _plan.jets[mk - 2]
					sd.release = _lead + float(jet.t) + 0.02
					sd.dir = (jet.n as Vector2).rotated(_rng.randf_range(-0.4, 0.4))
					sd.speed = _rng.randf_range(1.0, 1.6)
			Style.COLLAPSE:
				sd.mode = 1
				var rel := mid - Vector2(_cut.centre)
				sd.r0 = rel.length()
				sd.a0 = atan2(rel.y, rel.x)
				rmax = maxf(rmax, rel.length())
			Style.SHIELD:
				sd.life = 0.72
			Style.MELT:
				sd.life = 0.55
				sd.release = _split_at + _rng.randf_range(0.0, 0.1)
			Style.CRUMPLE:
				sd.life = 0.62
		_shards.append(sd)
	if style == Style.COLLAPSE:
		# Nearest first: the hole goes, then the cracks, all of it eaten before
		# the pop at 1.0.
		for sd2 in _shards:
			var f := clampf(float(sd2.r0) / rmax, 0.0, 1.0)
			var rel_t := (0.08 + 0.35 * f) if int(sd2.mark) == 99 else (0.3 + 0.45 * f)
			sd2.release = _lead + rel_t
			sd2.T = minf(0.25 + float(sd2.r0) / 150.0, 0.97 - rel_t)
	match style:
		Style.SHIELD:
			_build_shield()
		Style.MELT, Style.CRUMPLE:
			var H := _hull_pic(img, used, HULL_PAD)
			_stage_at = Vector2((H.r as Rect2i).position)
			var ks: Array = []
			if style == Style.MELT:
				for s2 in MELT_STEPS + 1:
					ks.append(float(s2) / float(MELT_STEPS))
			else:
				ks = CRUMPLE_K.duplicate()
			# Built on worker threads from here, picked up when first shown
			# (`_stage_get`): nine steps at once held the kill frame for most of
			# a second, and one at a time on the main thread cost 80 ms a step.
			_stage_H = H
			_stage_seed = seed
			_stage_ks = ks
			_stage_tex.resize(ks.size())
			_stage_mask.resize(ks.size())
			_stage_heat.resize(ks.size())
			_stage_data.resize(ks.size())
			if style == Style.MELT:
				_stage_fld = _melt_field(H, seed)
			_stage_get(0)
			for i in range(1, ks.size()):
				_stage_jobs[i] = WorkerThreadPool.add_task(_stage_build.bind(i), false, "ShipBreakup step")
		Style.DISSOLVE:
			var dd: Dictionary = _plan.dis
			var rr: Rect2i = _plan.r
			_dis_at = rr.position
			_dis_img = Image.create(rr.size.x, rr.size.y, false, Image.FORMAT_RGBA8)
			var dp: PackedVector2Array = dd.p
			var dc: PackedColorArray = dd.c
			var dt: PackedFloat32Array = dd.thr
			var order: Array = []
			for i in dp.size():
				var lp := Vector2i(dp[i]) - rr.position
				_dis_img.set_pixel(lp.x, lp.y, dc[i])
				order.append(i)
			order.sort_custom(func(a: int, b: int) -> bool: return dt[a] > dt[b])
			_dis_order = PackedInt32Array(order)
			_dis_tex = ImageTexture.create_from_image(_dis_img)
	if boss:
		_plan_beats()


var _stage_H: Dictionary = {}
var _stage_seed := 0
var _stage_ks: Array = []
var _stage_fld: Dictionary = {}
var _stage_data: Array = []
var _stage_jobs := {}
var _stage_lock := Mutex.new()


## One held step's pictures, on a worker thread: nothing here touches the
## scene or a shared cache (the melt's wander was worked out before).
func _stage_build(i: int) -> void:
	var kk: float = _stage_ks[i]
	var H := _stage_H
	var pic: Dictionary = _melt_pic(H, _stage_seed, kk, _stage_fld) if style == Style.MELT \
		else _crumple_pic(H, _stage_seed, kk)
	var d := {img = _pic_image(H, pic.col, pic.mask), mask = pic.mask}
	if style == Style.MELT:
		d.heat = _heat_light(pic.mask, int(H.w), int(H.h), 2)
	_stage_lock.lock()
	_stage_data[i] = d
	_stage_lock.unlock()


## A held step of MELT / CRUMPLE: waits for its worker if it is not done yet
## (it always has been, in the films), then makes its textures here.
func _stage_get(i: int) -> ImageTexture:
	if _stage_tex[i] == null:
		if _stage_jobs.has(i):
			WorkerThreadPool.wait_for_task_completion(_stage_jobs[i])
			_stage_jobs.erase(i)
		else:
			_stage_build(i)
		_stage_lock.lock()
		var d: Dictionary = _stage_data[i]
		_stage_lock.unlock()
		_stage_tex[i] = ImageTexture.create_from_image(d.img)
		_stage_mask[i] = d.mask
		if style == Style.MELT:
			_stage_heat[i] = ImageTexture.create_from_image(d.heat)
	return _stage_tex[i]


func _exit_tree() -> void:
	# never leave a worker writing into a freed breakup
	for i in _stage_jobs.keys():
		WorkerThreadPool.wait_for_task_completion(_stage_jobs[i])
	_stage_jobs.clear()


func _ev(at: float, kind: StringName, s: float, len: float = 0.0, p: Vector2 = Vector2.INF,
		extra: Dictionary = {}) -> void:
	var e := {t = _lead + at, kind = kind, s = s, len = len,
		p = _centre if p == Vector2.INF else p, fired = false}
	e.merge(extra)
	_events.append(e)


## Every style's clock: when its visible events happen, each one a `moment`.
func _plan_events() -> void:
	var o := _origin
	var rel_split := 0.4
	if style >= Style.GLOWOUT:
		rel_split = _plan_creature()
	match style:
		Style.BREACH:
			rel_split = 0.35
			_split_len = 0.45
			_ev(0.0, &"charge", 0.4, 0.35)
			_ev(0.35, &"breach", 1.0)
			_ev(0.35, &"shockwave", 0.7, 0.75)
			_ev(0.4, &"debris", 0.5, 0.9)
		Style.CHAIN:
			for i in CHAIN_AT.size():
				_ev(CHAIN_AT[i], &"pop", 0.35 + 0.07 * i, 0.0, o + (_plan.blasts[i] as Vector2))
			rel_split = 0.82
			_split_len = 0.35
			_ev(0.82, &"break", 1.0)
			_ev(0.86, &"debris", 0.5, 0.8)
		Style.OVERLOAD:
			var stern: Vector2 = _plan.stern
			rel_split = 0.55
			_split_len = 0.4
			_ev(0.0, &"spool", 0.5, 0.55, o + stern)
			_ev(0.4, &"lurch", 0.6, 0.0, o + stern)
			_ev(0.55, &"blow", 1.0, 0.0, o + stern + Vector2(_plan.glob))
			_ev(0.6, &"debris", 0.5, 0.8)
		Style.VENT:
			for j in _plan.jets:
				_ev(float(j.t), &"vent", 0.5, float(j.len), o + (j.p as Vector2))
			rel_split = 0.7
			_split_len = 0.55
			_ev(0.7, &"split", 0.8)
			_ev(0.7, &"gas", 0.6, 0.45)
			_ev(0.74, &"debris", 0.4, 0.8)
			_ev(1.0, &"sputter", 0.25)
			_ev(1.12, &"sputter", 0.2)
		Style.SLICE:
			rel_split = 0.3
			_split_len = 0.95
			_ev(0.0, &"beam", 0.7, 0.28)
			_ev(0.3, &"sever", 0.7)
			_ev(0.3, &"sizzle", 0.3, 1.0)
		Style.DISSOLVE:
			rel_split = 0.3
			_split_len = 1.0
			var box: Rect2i = _plan.box
			_ev(0.0, &"ignite", 0.4, 0.0, o + Vector2(box.end.x, box.get_center().y))
			_ev(0.0, &"fizz", 0.5, 1.2)
			_ev(1.2, &"fade", 0.2, 0.35)
		Style.COLLAPSE:
			rel_split = 1.0
			_split_len = 0.3
			_ev(0.0, &"form", 0.4)
			_ev(0.0, &"pull", 0.6, 1.0)
			_ev(1.0, &"collapse", 1.0)
			_ev(1.0, &"ring", 0.5, 0.45)
		Style.SHIELD:
			rel_split = 0.82
			_split_len = 0.3
			_ev(0.0, &"shield_up", 0.4)
			_ev(0.12, &"flicker", 0.3)
			_ev(0.22, &"flicker", 0.3)
			_ev(0.3, &"flicker", 0.35)
			_ev(0.42, &"shatter", 0.8)
			_ev(0.6, &"crack", 0.4, 0.22)
			_ev(0.82, &"break", 1.0)
			_ev(0.86, &"debris", 0.5, 0.7)
		Style.MELT:
			rel_split = 1.3
			_split_len = 0.45
			_ev(0.0, &"heat", 0.4, 0.6)
			_ev(0.35, &"slump", 0.5, 0.95)
			_ev(1.3, &"tear", 0.6)
			_ev(1.35, &"cool", 0.2, 0.6)
		Style.CRUMPLE:
			var folds: Array = _plan.folds
			for i in CRUMPLE_AT.size():
				_ev(CRUMPLE_AT[i], &"crunch", 0.5 + 0.1 * i, 0.0, o + (folds[(i + 1) % folds.size()] as Vector2))
			rel_split = 0.72
			_split_len = 0.35
			_ev(0.72, &"rip", 1.0)
			_ev(0.76, &"debris", 0.5, 0.7)
	_split_at = _lead + rel_split
	_events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.t) < float(b.t))


# ---------------------------------------------------------------- the clock

func _advance_new(delta: float) -> void:
	for e in _events:
		if not e.fired and t >= float(e.t):
			e.fired = true
			_fire(e)
	_style_tick(delta)
	var kept: Array = []
	for mo in _motes:
		mo.age += delta
		if mo.age >= mo.life:
			continue
		mo.p += mo.v * delta
		var dr: float = mo.get("drag", 0.0)
		if dr > 0.0:
			mo.v *= exp(-dr * delta)
		kept.append(mo)
	_motes = kept
	if t >= duration:
		done = true
		# Nothing of light is left by now; anything that is goes, so the last
		# frame is the wreck alone.
		_motes.clear()
		_flashes.clear()
		_rings.clear()
		finished.emit()
	queue_redraw()
	for c in get_children():
		(c as CanvasItem).queue_redraw()


func _fire(e: Dictionary) -> void:
	var kind: StringName = e.kind
	var s: float = e.s
	moment.emit(kind, s, float(e.len))
	if style >= Style.GLOWOUT:
		# A creature dies without an explosion: no `broke`, only moments.
		_fire_creature(e)
		return
	if kind in BOOMS:
		broke.emit(s)
	var p: Vector2 = e.p
	match kind:
		&"breach":
			_ring(p, 10.0, 100.0, 0.75, 0.42, 1.0, HEAT_RAMP[1])
			_spray(p, 44, 270.0)
		&"pop":
			_flash(p, 12, 0.8, Color(), 0.24)
			_ring(p, 3.0, 15.0, 0.2, 1.0, 0.6, HEAT_RAMP[1])
			_spray(p, 14, 170.0, Vector2.ZERO, Vector2(2, 2))
		&"break":
			_flash(p, 22, 1.0)
			_spray(p, 30, 220.0)
		&"lurch":
			_spray(p, 10, 120.0, Vector2(1.5, 0.0), Vector2(1, 4))
		&"blow":
			_flash(p, 26, 1.0)
			_ring(p, 6.0, 50.0, 0.4, 0.6, 0.8, HEAT_RAMP[1])
			_spray(p, 36, 240.0, Vector2(1.2, 0.0), Vector2(3, 6))
		&"vent":
			_spray(p, 8, 130.0, Vector2.ZERO, Vector2(1, 1))
		&"split":
			_flash(p, 12, 0.5)
			_spray(p, 16, 160.0)
			for i in 70:
				var m: Dictionary = _majors[_rng.randi() % _majors.size()]
				var cr: PackedVector2Array = m.crack
				if cr.is_empty():
					continue
				var q := _major_pos_new(m) + cr[_rng.randi() % cr.size()]
				var dv := ((m.dir as Vector2) + (q - _centre).normalized() * 0.5).normalized()
				_mote(q, dv.rotated(_rng.randf_range(-0.6, 0.6)) * _rng.randf_range(40.0, 110.0),
					_rng.randf_range(0.25, 0.55), 2, _rng.randf() < 0.4, Color.WHITE, 1.2)
		&"sever":
			var sl: Dictionary = _plan.slice
			var kp: PackedVector2Array = sl.kp
			var sn: Vector2 = sl.n
			var sd: Vector2 = sl.d
			for i in range(0, kp.size(), 2):
				var side := 1.0 if _rng.randf() < 0.5 else -1.0
				_mote(_origin + kp[i], sn * side * _rng.randf_range(10.0, 40.0) + sd * _rng.randf_range(-12.0, 12.0),
					_rng.randf_range(0.15, 0.35), 0, false, Color.WHITE, 4.5)
		&"shatter":
			var box: Rect2i = _plan.box
			_flash(_origin + Vector2(box.get_center()), 22, 0.45, SHIELD_COL, 0.28)
		&"crunch":
			_flash(p, 9, 0.55, Color(), 0.2)
			_spray(p, 10, 140.0, Vector2.ZERO, Vector2(1, 6))
		&"rip":
			_flash(p, 18, 0.85)
			_spray(p, 24, 190.0)
		&"tear":
			_flash(p, 14, 0.5)
			_spray(p, 12, 90.0)
		&"collapse":
			_flash(p, 24, 1.0, VOID_COL, 0.32)
			_ring(p, 4.0, 48.0, 0.45, 1.0, 1.0, VOID_COL)
			_spray(p, 26, 220.0, Vector2.ZERO, Vector2(1, 1))
		&"ignite":
			_spray(p, 8, 60.0, Vector2(1.0, 0.0), Vector2(1, 8))


func _flash(p: Vector2, r: int, s: float, col: Color = Color(), life: float = 0.28) -> void:
	_flashes.append({p = p, t0 = t, s = s, r = r, col = col, life = life})


func _ring(p: Vector2, r0: float, r1: float, dur: float, squash: float, s: float, col: Color) -> void:
	_rings.append({p = p, t0 = t, r0 = r0, r1 = r1, dur = dur, squash = squash, s = s, col = col})


## A mote, never outliving the animation: by the last frame every light is out.
func _mote(p: Vector2, v: Vector2, life: float, kind: int, big: bool = false, c: Color = Color.WHITE,
		drag: float = 0.0) -> void:
	var room := duration - t - 0.04
	if room < 0.08:
		return
	_motes.append({p = p, v = v, age = 0.0, life = minf(life, room), kind = kind, big = big, c = c, drag = drag})


func _spray(at: Vector2, count: int, speed: float, bias: Vector2 = Vector2.ZERO,
		jitter: Vector2 = Vector2(6, 3)) -> void:
	for i in count:
		var a := _rng.randf() * TAU
		var v := (Vector2(cos(a), sin(a)) + bias).normalized() * _rng.randf_range(0.35, 1.0) * speed
		_mote(at + Vector2(_rng.randf_range(-jitter.x, jitter.x), _rng.randf_range(-jitter.y, jitter.y)), v,
			_rng.randf_range(0.14, 0.38), 0, false, Color.WHITE, 4.5)


## Embers leave a hot crack OUTWARD, drifting -- in space nothing rises.
func _crack_embers(delta: float, rate: float) -> void:
	var n := int(rate * delta + _rng.randf())
	for i in n:
		if _majors.is_empty():
			return
		var m: Dictionary = _majors[_rng.randi() % _majors.size()]
		var cr: PackedVector2Array = m.crack
		if cr.is_empty():
			continue
		var p := _major_pos_new(m) + cr[_rng.randi() % cr.size()]
		var v := (p - _centre).normalized() * _rng.randf_range(5.0, 18.0) \
			+ Vector2(_rng.randf_range(-5.0, 5.0), _rng.randf_range(-5.0, 5.0))
		_mote(p, v, _rng.randf_range(0.3, 0.7), 1, _rng.randf() < 0.3, Color.WHITE, 0.5)


func _rate_limited(kind: StringName, gap: float) -> bool:
	if t - float(_last_tick.get(kind, -9.0)) < gap:
		return false
	_last_tick[kind] = t
	return true


## What each style does every frame besides its events.
func _style_tick(delta: float) -> void:
	var tt := t - _lead
	if tt < 0.0:
		return
	if style >= Style.GLOWOUT:
		_tick_creature(delta, tt)
		return
	if (style == Style.MELT or style == Style.CRUMPLE) and t < _split_at:
		_stage_get(_stage_now())
	var hv := _heat_new(tt)
	match style:
		Style.BREACH:
			if tt >= 0.35:
				_crack_embers(delta, 70.0 * hv.x)
		Style.CHAIN:
			if tt < 0.82:
				for i in CHAIN_AT.size():
					if tt >= CHAIN_AT[i]:
						var bp: Vector2 = _origin + (_plan.blasts[i] as Vector2)
						var n := int(16.0 * delta + _rng.randf())
						for j in n:
							var dv := Vector2.RIGHT.rotated(_rng.randf() * TAU)
							_mote(bp + dv * 2.0, dv * _rng.randf_range(5.0, 16.0), _rng.randf_range(0.3, 0.55), 1,
								_rng.randf() < 0.3, Color.WHITE, 0.5)
			else:
				_crack_embers(delta, 50.0 * hv.x)
		Style.OVERLOAD:
			if tt >= 0.15 and tt < 0.55:
				var eng: PackedVector2Array = _plan.engine
				var n2 := int(36.0 * delta + _rng.randf())
				for j in n2:
					if eng.is_empty():
						break
					var ep := _origin + eng[_rng.randi() % eng.size()] + _hull_shift()
					_mote(ep, Vector2(_rng.randf_range(60.0, 160.0), _rng.randf_range(-25.0, 25.0)),
						_rng.randf_range(0.1, 0.25), 0, false, Color.WHITE, 4.5)
			elif tt >= 0.55:
				_crack_embers(delta, 50.0 * hv.x)
		Style.VENT:
			for j in _plan.jets:
				var a: float = tt - float(j.t)
				var jl: float = j.len
				if a < 0.0 or a > jl:
					continue
				var on := 1.0
				if a > jl * 0.7:
					on = 1.0 if int((a - jl * 0.7) / 0.06) % 2 == 0 else 0.0
				var n3 := int(240.0 * on * delta + _rng.randf() * on)
				var m: Dictionary = _majors[int(j.major)] if int(j.major) < _majors.size() else _majors[0]
				var jp := _major_pos_new(m) + ((j.p as Vector2) - Vector2(m.at))
				for i in n3:
					var dv2 := (j.n as Vector2).rotated(_rng.randf_range(-0.35, 0.35))
					_mote(jp, dv2 * _rng.randf_range(60.0, 150.0), _rng.randf_range(0.3, 0.6), 2,
						_rng.randf() < 0.6, Color.WHITE, 1.2)
			if tt >= 0.7 and tt < 1.15:
				var rate := 90.0 if tt < 0.85 else (45.0 if tt < 1.0 else 22.0)
				var n4 := int(rate * delta + _rng.randf())
				for i in n4:
					var m2: Dictionary = _majors[_rng.randi() % _majors.size()]
					var cr: PackedVector2Array = m2.crack
					if cr.is_empty():
						continue
					var q := _major_pos_new(m2) + cr[_rng.randi() % cr.size()]
					_mote(q, (m2.dir as Vector2).rotated(_rng.randf_range(-0.7, 0.7)) * _rng.randf_range(30.0, 90.0),
						_rng.randf_range(0.2, 0.45), 2, _rng.randf() < 0.3, Color.WHITE, 1.2)
		Style.SLICE:
			var sl: Dictionary = _plan.slice
			var sn: Vector2 = sl.n
			var sd: Vector2 = sl.d
			if tt < 0.28:
				var tip := _origin + (sl.c as Vector2) + sd * _slice_tip_u()
				for i in 4:
					var side := 1.0 if _rng.randf() < 0.5 else -1.0
					var dv3 := (sn * side * _rng.randf_range(0.4, 1.0) + sd * _rng.randf_range(-0.3, 0.8)).normalized()
					_mote(tip, dv3 * _rng.randf_range(60.0, 170.0), _rng.randf_range(0.1, 0.28), 0, false, Color.WHITE, 4.5)
			elif tt >= 0.3 and tt < 1.05:
				var n5 := int(28.0 * hv.x * delta + _rng.randf())
				for i in n5:
					var mi := _rng.randi() % _majors.size()
					var m3: Dictionary = _majors[mi]
					var cr2: PackedVector2Array = m3.crack
					if cr2.is_empty():
						continue
					var q2 := _major_pos_new(m3) + cr2[_rng.randi() % cr2.size()]
					var face := sn if (q2 - _centre).dot(sn) < 0.0 else -sn
					_mote(q2, face * _rng.randf_range(2.0, 6.0) + sd * _rng.randf_range(-10.0, 10.0),
						_rng.randf_range(0.4, 0.8), 4, _rng.randf() < 0.3, Color.WHITE, 0.4)
		Style.DISSOLVE:
			_dissolve_tick(tt)
		Style.COLLAPSE:
			var eaten := 0
			for s in _shards:
				if s.get("gone", false) or t < float(s.release):
					continue
				var st := _shard_new(s)
				if st.out:
					s.gone = true
					eaten += 1
			if eaten > 0 and _rate_limited(&"swallow", 0.08):
				moment.emit(&"swallow", 0.15, 0.0)
				_flash(_centre, 4, 0.6, VOID_COL, 0.1)
			if tt >= 1.0:
				_crack_embers(delta, 40.0 * hv.x)
		Style.SHIELD:
			if tt >= 0.82:
				_crack_embers(delta, 45.0 * hv.x)
		Style.MELT:
			var si := _stage_now()
			if si != _last_stage and t < _split_at:
				_stage_get(si)
				_stage_get(_last_stage)
				var a2: PackedByteArray = _stage_mask[_last_stage]
				var b2: PackedByteArray = _stage_mask[si]
				var w2 := (_stage_tex[0] as ImageTexture).get_width()
				var spawned := 0
				var idxs: Array = []
				for i in a2.size():
					if a2[i] == 1 and b2[i] == 0:
						idxs.append(i)
				idxs.shuffle()
				for i in idxs:
					if spawned >= 26:
						break
					var q3 := _origin + _stage_at + Vector2(int(i) % w2, int(i) / w2)
					var dv4 := (q3 - _centre).normalized()
					_mote(q3, dv4 * _rng.randf_range(6.0, 20.0) + Vector2(_rng.randf_range(-4.0, 4.0), _rng.randf_range(-4.0, 4.0)),
						_rng.randf_range(0.6, 1.0), 4, _rng.randf() < 0.35, Color.WHITE, 0.6)
					spawned += 1
				if spawned > 3 and _rate_limited(&"drip", 0.12):
					moment.emit(&"drip", 0.2, 0.0)
				_last_stage = si
			if tt >= 1.3:
				_crack_embers(delta, 30.0 * hv.x)
		Style.CRUMPLE:
			if tt >= 0.72:
				_crack_embers(delta, 40.0 * hv.x)


## Where the beam's cutting point is along the cut (`d`), from above the hull
## to below it in 0.28 s.
func _slice_tip_u() -> float:
	var tt := t - _lead
	var sl: Dictionary = _plan.slice
	var u0: float = float(sl.u0) - 4.0
	var u1: float = float(sl.u1) + 4.0
	if tt >= 0.28:
		return u1 + 999.0
	return u0 + (u1 - u0) * clampf(tt / 0.28, 0.0, 1.0)


## How far the disintegration has eaten: 1.14 (none) to DIS_END, fast at first.
func _front(tt: float) -> float:
	var x := clampf(tt / 1.2, 0.0, 1.0)
	return 1.14 - (1.14 - DIS_END) * (1.0 - (1.0 - x) * (1.0 - x))


func _dissolve_tick(tt: float) -> void:
	var dd: Dictionary = _plan.dis
	var thr: PackedFloat32Array = dd.thr
	var dp: PackedVector2Array = dd.p
	var dc: PackedColorArray = dd.c
	var f := _front(tt)
	var changed := false
	while _dis_ptr < _dis_order.size():
		var i := _dis_order[_dis_ptr]
		if thr[i] <= f:
			break
		var lp := Vector2i(dp[i]) - _dis_at
		_dis_img.set_pixel(lp.x, lp.y, Color(0, 0, 0, 0))
		changed = true
		if _rng.randf() < 0.5:
			var pp := _origin + dp[i]
			var v := Vector2(_rng.randf_range(6.0, 26.0),
				signf(pp.y - _centre.y) * _rng.randf_range(2.0, 14.0) + _rng.randf_range(-5.0, 5.0))
			_mote(pp, v, _rng.randf_range(0.45, 0.85), 3, false, dc[i], 0.0)
		_dis_ptr += 1
	if changed:
		_dis_tex.update(_dis_img)


# ---------------------------------------------------------------- motion

## Moves the whole hull makes before it parts: the overload's lurch forward,
## the vent's one-pixel jolts away from each jet as it opens.
func _hull_shift() -> Vector2:
	var tt := t - _lead
	var s := Vector2.ZERO
	if style >= Style.GLOWOUT:
		# a creature's slow drift, a whole pixel at a time
		var x := clampf(tt / (duration - 0.3), 0.0, 1.0)
		return (Vector2(_plan.glob) * (x * x * (3.0 - 2.0 * x))).round()
	if style == Style.OVERLOAD:
		if tt >= 0.4:
			s = Vector2(_plan.glob) * _ease_out((tt - 0.4) / 0.12)
	elif style == Style.VENT:
		for j in _plan.jets:
			var a: float = tt - float(j.t)
			if a >= 0.0 and a < 0.1:
				s -= (j.n as Vector2)
	return s.round()


func _major_pos_new(m: Dictionary) -> Vector2:
	var tt := t - _lead
	var base := _origin + Vector2(m.at) + _hull_shift()
	var k := 0.0
	if t >= _split_at:
		k = _ease_out((t - _split_at) / _split_len)
	var extra := Vector2.ZERO
	if style == Style.PART:
		# Each seam opens on its own clock and pushes the two sides apart.
		var j: int = m.lab
		var sx := 0.0
		for i in int(_plan.nb) - 1:
			if tt >= PART_TEAR[i]:
				sx += (2.5 if i < j else -2.5) * _ease_out((tt - PART_TEAR[i]) / 1.2)
		var sy := (2.0 if j % 2 == 0 else -2.0) * (_ease_out((tt - 0.15) / 1.2) if tt >= 0.15 else 0.0)
		# rounded on its own, as the cut rounds `own` (x.5 rounds away from 0)
		return base.round() + Vector2(sx, sy).round()
	if style == Style.COLLAPSE:
		var dir: Vector2 = m.dir
		if tt < 1.0:
			# pulled in, a whole pixel at a time, faster as the hole grows
			extra = -dir * floorf(4.0 * pow(clampf(tt, 0.0, 1.0), 2.0))
		else:
			extra = -dir * 4.0 * (1.0 - _ease_out((tt - 1.0) / 0.3))
	return (base + Vector2(m.own) * k + extra).round()


func _stage_of(m: Dictionary) -> int:
	var n: int = (m.stages as Array).size()
	if n <= 1:
		return 0
	if done:
		return n - 1
	var tt := t - _lead
	var i := 0
	match style:
		Style.BREACH:
			i = 1 if tt >= 0.37 else 0
		Style.CHAIN:
			for e in _events:
				if e.kind == &"pop" and e.fired:
					i += 1
		Style.OVERLOAD:
			i = 1 if tt >= 0.57 else 0
		Style.MELT:
			i = 0 if tt < 1.5 else (1 if tt < 1.72 else 2)
		Style.DISSOLVE:
			i = 1 if tt >= 1.22 else 0
	return mini(i, n - 1)


## MELT / CRUMPLE: which held step of the deformation shows.
func _stage_now() -> int:
	var tt := t - _lead
	if style == Style.MELT:
		if tt < 0.35:
			return 0
		return mini(MELT_STEPS, 1 + int((tt - 0.35) / (0.9 / float(MELT_STEPS))))
	var idx := 0
	for i in CRUMPLE_AT.size():
		if tt >= CRUMPLE_AT[i]:
			idx = 2 * i + 1
		if tt >= CRUMPLE_AT[i] + 0.034:
			idx = 2 * i + 2
	return mini(idx, _stage_tex.size() - 1)


func _shard_new(s: Dictionary) -> Dictionary:
	var rel: float = s.release
	var home := _origin + Vector2(s.at) + _hull_shift()
	if t < rel:
		return {p = home.round(), rot = 0, a = 1.0, out = false}
	var age := t - rel
	var rot := posmod(int(s.rot0) + int(floor(age * float(s.spin))), 4)
	if int(s.mode) == 1:
		# Into the singularity, round and in, faster as it nears.
		var T: float = s.T
		var f := clampf(age / maxf(0.05, T), 0.0, 1.0)
		var rr := float(s.r0) * (1.0 - f * f)
		if rr < 2.5:
			return {p = Vector2.ZERO, rot = 0, a = 0.0, out = true}
		var a := float(s.a0) + 2.6 * f * f
		var sz := Vector2(s.size)
		var p := _centre + Vector2(cos(a), sin(a)) * rr - sz * 0.5
		return {p = p.round(), rot = rot, a = 1.0, out = false}
	var spd: float = float(s.speed) * _shard_speed
	var drag := 2.4
	var dist := spd * (1.0 - exp(-drag * age)) / drag
	var p2 := home + (s.dir as Vector2) * dist
	var life: float = s.life
	var al := 1.0
	if age > life * 0.6:
		var f2 := (age - life * 0.6) / (life * 0.4)
		al = 0.66 if f2 < 0.34 else (0.33 if f2 < 0.67 else (0.0 if f2 >= 1.0 else 0.15))
	return {p = p2.round(), rot = rot, a = al, out = age >= life}


## How hot the cracks are (x) and how white (y), stepped in quarters.
func _heat_new(tt: float) -> Vector2:
	var on := 0.0
	var heat := 1.0
	match style:
		Style.BREACH:
			if tt >= 0.2 and tt < 0.35:
				on = 0.25
			elif tt >= 0.35:
				on = 1.0 if tt < 0.9 else clampf(1.0 - (tt - 0.9) / 0.55, 0.0, 1.0)
				heat = clampf(1.0 - (tt - 0.35) / 0.9, 0.0, 1.0)
		Style.CHAIN:
			if tt < 0.82:
				var c := 0
				for a in CHAIN_AT:
					if tt >= a:
						c += 1
				on = minf(0.75, 0.2 * c)
				heat = 0.75
			else:
				on = 1.0 if tt < 1.2 else clampf(1.0 - (tt - 1.2) / 0.5, 0.0, 1.0)
				heat = clampf(1.0 - (tt - 0.82) / 0.8, 0.0, 1.0)
		Style.OVERLOAD:
			if tt >= 0.55:
				on = 1.0 if tt < 0.95 else clampf(1.0 - (tt - 0.95) / 0.5, 0.0, 1.0)
				heat = clampf(1.0 - (tt - 0.55) / 0.75, 0.0, 1.0)
		Style.VENT:
			if tt >= 0.7:
				on = 0.75 if tt < 0.9 else clampf(0.75 - (tt - 0.9) / 0.4, 0.0, 1.0)
				heat = 0.5
		Style.SLICE:
			if tt >= 0.3:
				on = 1.0 if tt < 0.95 else clampf(1.0 - (tt - 0.95) / 0.4, 0.0, 1.0)
				heat = 1.0 if tt < 0.45 else clampf(1.0 - (tt - 0.45) / 0.85, 0.0, 1.0)
		Style.COLLAPSE:
			if tt >= 0.3 and tt < 1.0:
				on = 0.25 + 0.5 * (tt - 0.3) / 0.7
				heat = 1.0
			elif tt >= 1.0:
				on = 1.0 if tt < 1.15 else clampf(1.0 - (tt - 1.15) / 0.4, 0.0, 1.0)
				heat = clampf(1.0 - (tt - 1.0) / 0.45, 0.0, 1.0)
		Style.SHIELD:
			if tt >= 0.6 and tt < 0.82:
				on = 0.5 + (tt - 0.6) / 0.44
			elif tt >= 0.82:
				on = 1.0 if tt < 1.1 else clampf(1.0 - (tt - 1.1) / 0.5, 0.0, 1.0)
				heat = clampf(1.0 - (tt - 0.82) / 0.7, 0.0, 1.0)
		Style.MELT:
			if tt >= 1.3:
				on = 0.75 if tt < 1.5 else clampf(0.75 - (tt - 1.5) / 0.35, 0.0, 1.0)
				heat = 0.5
		Style.CRUMPLE:
			if tt >= 0.72:
				on = 1.0 if tt < 0.9 else clampf(1.0 - (tt - 0.9) / 0.4, 0.0, 1.0)
				heat = clampf(0.8 - (tt - 0.72) / 0.6, 0.0, 1.0)
	if boss and tt < 0.0:
		on = clampf((t + 0.2) / BOSS_PRELUDE, 0.0, 1.0) * 0.75
		heat = 0.7
	return Vector2(snappedf(on, 0.25), snappedf(heat, 0.25))


# ---------------------------------------------------------------- the shield

## A hex shield round the hull: an ellipse of hexagon outlines, brighter toward
## its rim as a bubble is (seen edge-on), the faint middle dithered. Each cell
## is its own little picture, so the shield can lose cells and then shatter
## into them.
func _build_shield() -> void:
	var box: Rect2i = _plan.box
	var cc := Vector2(box.position) + Vector2(box.size) * 0.5
	var rx := float(box.size.x) * 0.5 + 9.0
	var ry := float(box.size.y) * 0.5 + 9.0
	var s := 6.0
	var dx := 1.5 * s
	var dy := sqrt(3.0) * s
	var x0 := int(floor(cc.x - rx)) - 1
	var y0 := int(floor(cc.y - ry)) - 1
	var W := int(ceil(2.0 * rx)) + 3
	var Hh := int(ceil(2.0 * ry)) + 3
	var ids := PackedInt32Array()
	ids.resize(W * Hh)
	ids.fill(-1)
	var rns := PackedFloat32Array()
	rns.resize(W * Hh)
	for y in Hh:
		for x in W:
			var px := float(x0 + x) + 0.5
			var py := float(y0 + y) + 0.5
			var rn := Vector2((px - cc.x) / rx, (py - cc.y) / ry).length()
			if rn > 1.0:
				continue
			var fi := floorf((px - cc.x) / dx)
			var best := 1e9
			var bid := 0
			for i in range(int(fi) - 1, int(fi) + 3):
				var ox := cc.x + float(i) * dx
				var oyoff := dy * 0.5 if (i & 1) == 1 else 0.0
				var fj := floorf((py - cc.y - oyoff) / dy)
				for j in range(int(fj) - 1, int(fj) + 3):
					var oy := cc.y + float(j) * dy + oyoff
					var d2 := (px - ox) * (px - ox) + (py - oy) * (py - oy)
					if d2 < best:
						best = d2
						bid = (i + 500) * 1000 + (j + 500)
			ids[y * W + x] = bid
			rns[y * W + x] = rn
	var cells := {}
	for y in Hh:
		for x in W:
			var i2 := y * W + x
			var id := ids[i2]
			if id < 0:
				continue
			var rn2 := rns[i2]
			var edge := false
			if x + 1 < W and ids[i2 + 1] >= 0 and ids[i2 + 1] != id:
				edge = true
			if y + 1 < Hh and ids[i2 + W] >= 0 and ids[i2 + W] != id:
				edge = true
			var rim := rn2 >= 0.93
			if not edge and not rim:
				continue
			var lvl := 0.0
			if rim:
				lvl = 1.0 if rn2 >= 0.965 else 0.7
			else:
				var fr := 0.22 + 0.78 * pow(rn2, 3.0)
				lvl = 1.0 if fr > 0.8 else (0.7 if fr > 0.55 else (0.45 if fr > 0.33 else 0.25))
				if lvl <= 0.25 and ((x0 + x + y0 + y) & 1) == 1:
					continue
			if not cells.has(id):
				cells[id] = []
			(cells[id] as Array).append([Vector2i(x0 + x, y0 + y), lvl])
	for id2 in cells:
		var arr: Array = cells[id2]
		var mn := Vector2i(1 << 20, 1 << 20)
		var mx := Vector2i(-(1 << 20), -(1 << 20))
		var sum := Vector2.ZERO
		for e in arr:
			var p: Vector2i = e[0]
			mn = Vector2i(mini(mn.x, p.x), mini(mn.y, p.y))
			mx = Vector2i(maxi(mx.x, p.x), maxi(mx.y, p.y))
			sum += Vector2(p)
		var im := Image.create(mx.x - mn.x + 1, mx.y - mn.y + 1, false, Image.FORMAT_RGBA8)
		for e2 in arr:
			var p2: Vector2i = e2[0]
			var l: float = e2[1]
			im.set_pixel(p2.x - mn.x, p2.y - mn.y, Color(l, l, l, 1.0))
		var c := sum / float(arr.size())
		var out := Vector2((c.x - cc.x) / rx, (c.y - cc.y) / ry)
		var dir := out.normalized() if out.length() > 0.05 else Vector2.RIGHT.rotated(_rng.randf() * TAU)
		_cells.append({tex = ImageTexture.create_from_image(im), at = Vector2(mn), dir = dir,
			speed = _rng.randf_range(40.0, 95.0),
			drop = _rng.randf_range(0.14, 0.4) if _rng.randf() < 0.3 else 99.0})


## The shield's strength before it goes: up, three drop-outs (each the length
## of two frames, so they read as flickers and not shimmer), a last surge.
func _shield_strength(tt: float) -> float:
	if tt < 0.04:
		return 0.5
	if tt < 0.12:
		return 1.0
	if tt < 0.18:
		return 0.0
	if tt < 0.22:
		return 0.75
	if tt < 0.27:
		return 0.25
	if tt < 0.3:
		return 0.75
	if tt < 0.37:
		return 0.0
	return 1.0


# ---------------------------------------------------------------- the plume

## The overload's exhaust: light streaming back from every engine point, its
## core blown white, falling off over `L` px in four held steps, the outer two
## dithered, the stream widening a little as it goes.
func _plume_tex(L: int) -> Dictionary:
	if _plume.has(L):
		return _plume[L]
	var em: PackedVector2Array = _plan.engine
	var lo := Vector2i(1 << 20, 1 << 20)
	var hi := Vector2i(-(1 << 20), -(1 << 20))
	for e in em:
		lo = Vector2i(mini(lo.x, int(e.x)), mini(lo.y, int(e.y)))
		hi = Vector2i(maxi(hi.x, int(e.x)), maxi(hi.y, int(e.y)))
	if em.is_empty():
		_plume[L] = {tex = null, at = Vector2.ZERO}
		return _plume[L]
	var at := lo - Vector2i(2, 8)
	var W := hi.x - lo.x + L + 6
	var Hh := hi.y - lo.y + 17
	var buf := PackedFloat32Array()
	buf.resize(W * Hh)
	for e2 in em:
		var ex := int(e2.x) - at.x
		var ey := int(e2.y) - at.y
		for d in L + 1:
			var fall := pow(1.0 - float(d) / float(L + 1), 1.3)
			var spread := 1 + int(float(d) * 0.12)
			for dyy in range(-spread, spread + 1):
				var v := fall * (1.0 - absf(float(dyy)) / float(spread + 1))
				var xx := ex + d
				var yy := ey + dyy
				if xx >= 0 and yy >= 0 and xx < W and yy < Hh:
					buf[yy * W + xx] = maxf(buf[yy * W + xx], v)
		if ex - 1 >= 0:
			buf[ey * W + ex - 1] = 1.0
	var im := Image.create(W, Hh, false, Image.FORMAT_RGBA8)
	var bayer := [0.0, 0.5, 0.75, 0.25]
	for y in Hh:
		for x in W:
			var v2 := buf[y * W + x]
			var thr: float = bayer[(y % 2) * 2 + (x % 2)]
			var c := Color()
			if v2 > 0.72:
				c = _lv(HEAT_RAMP[0], 1.0)
			elif v2 > 0.48:
				c = _lv(HEAT_RAMP[1], 0.8)
			elif v2 > 0.28:
				if thr >= 0.75:
					continue
				c = _lv(HEAT_RAMP[2], 0.55)
			elif v2 > 0.12:
				if thr >= 0.5:
					continue
				c = _lv(HEAT_RAMP[3], 0.4)
			else:
				continue
			im.set_pixel(x, y, c)
	_plume[L] = {tex = ImageTexture.create_from_image(im), at = Vector2(at)}
	return _plume[L]


# ---------------------------------------------------------------- drawing

func _paint_body_new(ci: CanvasItem) -> void:
	if style >= Style.GLOWOUT:
		_paint_creature_body(ci)
		return
	var k := 0.0
	if t > _split_at:
		k = clampf((t - _split_at) / maxf(0.2, duration - _split_at - 0.15), 0.0, 1.0)
	var tint := Color.WHITE.lerp(WRECK_TINT, minf(1.0, snappedf(k, 0.34)))
	if done:
		tint = WRECK_TINT
	var tt := t - _lead
	if (style == Style.MELT or style == Style.CRUMPLE) and t < _split_at and not _stage_tex.is_empty():
		ci.draw_texture(_stage_get(_stage_now()), _origin + _stage_at, Color.WHITE)
	else:
		for m in _majors:
			ci.draw_texture(m.stages[_stage_of(m)], _major_pos_new(m), tint)
		for s in _shards:
			if s.get("gone", false):
				continue
			var st := _shard_new(s)
			if st.out or float(st.a) <= 0.0:
				continue
			var sz: Vector2 = Vector2(s.size)
			var c := tint
			c.a = float(st.a)
			ci.draw_set_transform(Vector2(st.p) + sz * 0.5, float(st.rot) * PI * 0.5, Vector2.ONE)
			ci.draw_texture(s.tex, -sz * 0.5, c)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if style == Style.DISSOLVE and _dis_tex != null:
		ci.draw_texture(_dis_tex, _origin + Vector2(_dis_at), tint)
	if style == Style.SLICE and t < _split_at:
		# the line the beam has not reached yet is still hull
		var sl: Dictionary = _plan.slice
		var kp: PackedVector2Array = sl.kp
		var kc: PackedColorArray = sl.kc
		var ku: PackedFloat32Array = sl.ku
		var ut := _slice_tip_u()
		for i in kp.size():
			if ku[i] > ut:
				ci.draw_rect(Rect2(_origin + kp[i], Vector2.ONE), kc[i])
	if style == Style.COLLAPSE and tt >= 0.0 and tt < 1.0 and not done:
		# the singularity itself: a hole of true black over the hull
		var rc := 1 if tt < 0.4 else (2 if tt < 0.8 else 3)
		_draw_disc(ci, _centre, rc, Color(0, 0, 0, 1))


func _draw_disc(ci: CanvasItem, c: Vector2, r: int, col: Color) -> void:
	var cp := c.round()
	for dy in range(-r, r + 1):
		var half := int(floor(sqrt(float(r * r - dy * dy) + 0.25)))
		ci.draw_rect(Rect2(cp + Vector2(-half, dy), Vector2(half * 2 + 1, 1)), col)


## A ring of light in whole pixels: a one-pixel core, a dithered pixel either
## side. `squash` < 1 lays it flat, a shock front seen near edge-on.
## `trail`: how far it moved since the last frame. That stretch behind the
## front is lit too, falling off, so a fast ring is a travelling band and not a
## thin line lit for one frame at each place (which reads as strobing: the
## flip-back count halved with it).
func _draw_ring(ci: CanvasItem, c: Vector2, r: int, squash: float, lvl: float, col: Color,
		doppler: bool = false, trail: int = 0) -> void:
	if r < 1 or lvl <= 0.0:
		return
	var cp := c.round()
	var bands: Array = [0, 1, -1]
	for k in range(2, trail + 1):
		bands.append(-k)
	for band in bands:
		var rr: float = float(r + int(band))
		if rr < 1.0:
			continue
		if int(band) < -1:
			# the trail: solid near the front, dithered toward its tail
			var f := float(-int(band)) / float(trail + 1)
			var lt := lvl * 0.5 * (1.0 - f)
			var pts2 := {}
			var n2 := int(ceil(TAU * rr)) + 8
			for i2 in n2:
				var a2 := TAU * float(i2) / float(n2)
				pts2[Vector2i(roundi(cos(a2) * rr), roundi(sin(a2) * rr * squash))] = true
			for p2 in pts2:
				var q2: Vector2i = p2
				if f > 0.5 and ((q2.x + q2.y) & 1) == 1:
					continue
				ci.draw_rect(Rect2(cp + Vector2(q2), Vector2.ONE), _lv(col, lt))
			continue
		var pts := {}
		var n := int(ceil(TAU * rr)) + 8
		for i in n:
			var a := TAU * float(i) / float(n)
			pts[Vector2i(roundi(cos(a) * rr), roundi(sin(a) * rr * squash))] = true
		for p in pts:
			var q: Vector2i = p
			var l := lvl
			if band != 0:
				if ((q.x + q.y) & 1) == 1:
					continue
				l *= 0.45 if band == 1 else 0.3
			if doppler and q.x > 0:
				l *= 0.5
			ci.draw_rect(Rect2(cp + Vector2(q), Vector2.ONE), _lv(col, l))


## The breach's ball of light: a blown-out core, then three falling steps, the
## outer two dithered.
func _draw_sphere(ci: CanvasItem, c: Vector2, R: int, lvl: float) -> void:
	var cp := c.round()
	var outer := R + 7
	for dy in range(-outer, outer + 1):
		var half := int(floor(sqrt(maxf(0.0, float(R * R - dy * dy)))))
		if absi(dy) <= R:
			ci.draw_rect(Rect2(cp + Vector2(-half, dy), Vector2(half * 2 + 1, 1)), _lv(Color(1, 1, 0.96), lvl))
		for dx in range(-outer, outer + 1):
			var d := sqrt(float(dx * dx + dy * dy))
			if d <= float(R) or d > float(outer):
				continue
			var odd := ((dx + dy) & 1) == 0
			var col := Color()
			if d <= float(R) + 2.0:
				col = _lv(HEAT_RAMP[1], lvl * 0.7)
			elif d <= float(R) + 4.0:
				if not odd and ((dx & 1) == 0):
					continue
				col = _lv(HEAT_RAMP[2], lvl * 0.42)
			else:
				if not odd:
					continue
				col = _lv(HEAT_RAMP[3], lvl * 0.2)
			ci.draw_rect(Rect2(cp + Vector2(dx, dy), Vector2.ONE), col)


func _paint_light_new(ci: CanvasItem) -> void:
	if t <= 0.0 or done:
		return
	var tt := t - _lead
	var hv := _heat_new(tt)
	var morphing := (style == Style.MELT or style == Style.CRUMPLE) and t < _split_at
	if style >= Style.GLOWOUT:
		_paint_creature_light(ci, tt)
		morphing = true
	if hv.x > 0.0 and not morphing:
		var heat := hv.y
		var col := Color(hv.x, hv.x * (0.45 + 0.55 * heat), hv.x * (0.15 + 0.85 * heat * heat), 1.0)
		if style == Style.COLLAPSE:
			# Cold light, bent toward the hole: not the breach's fire.
			col = _lv(VOID_COL, hv.x * (0.55 + 0.45 * heat))
		for m in _majors:
			ci.draw_texture(m.glow, _major_pos_new(m) - Vector2(GLOW_PAD, GLOW_PAD), col)
	match style:
		Style.BREACH:
			if tt >= 0.0 and tt < 0.35:
				var q := clampi(int(tt / 0.35 * 4.0), 0, 3)
				var rad: int = [4, 6, 9, 12][q]
				var lvl: float = [0.45, 0.6, 0.8, 1.0][q]
				var tex := _warm(rad)
				ci.draw_texture(tex, (_centre - Vector2(tex.get_size()) * 0.5).round(), Color(lvl, lvl, lvl, 1))
			var a := tt - 0.35
			if a >= 0.0 and a < 0.56:
				var R := 4.0 + 30.0 * _ease_out(a / 0.22) + (6.0 * (a - 0.3) / 0.26 if a > 0.3 else 0.0)
				var lv2 := 1.0 if a < 0.3 else (0.6 if a < 0.38 else (0.35 if a < 0.46 else 0.16))
				_draw_sphere(ci, _centre, int(R), lv2)
		Style.OVERLOAD:
			if tt >= 0.0 and tt < 0.55:
				var q2 := clampi(int(tt / 0.55 * 7.0), 0, 6)
				var L: int = [4, 8, 12, 16, 20, 24, 28][q2]
				var lv3: float = [0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 1.0][q2]
				var pl := _plume_tex(L)
				if pl.tex != null:
					ci.draw_texture(pl.tex, _origin + (pl.at as Vector2) + _hull_shift(), Color(lv3, lv3, lv3, 1))
		Style.SLICE:
			_light_slice(ci, tt)
		Style.DISSOLVE:
			_light_dissolve(ci, tt)
		Style.COLLAPSE:
			if tt >= 0.0 and tt < 1.0:
				var rc := 1 if tt < 0.4 else (2 if tt < 0.8 else 3)
				var lv4 := 0.5 if tt < 0.15 else (0.75 if tt < 0.5 else 1.0)
				_draw_ring(ci, _centre, rc + 1, 1.0, lv4, VOID_COL, true)
				_draw_ring(ci, _centre, rc + 4, 1.0, lv4 * 0.35, VOID_COL)
		Style.SHIELD:
			_light_shield(ci, tt)
		Style.MELT:
			_light_melt(ci, tt)
	for f in _flashes:
		var age := t - float(f.t0)
		var life: float = f.get("life", 0.36 if boss else 0.28)
		if age > life:
			continue
		var x := age / life
		var lvl2 := 1.0 if x < 0.25 else (0.6 if x < 0.5 else (0.32 if x < 0.75 else 0.14))
		lvl2 *= clampf(float(f.s), 0.3, 1.0)
		var r: int = f.get("r", 34 if boss else 22)
		var fc: Color = f.get("col", Color())
		var tex2 := _warm(r) if fc == Color() else _white(r)
		var mod := Color(lvl2, lvl2, lvl2, 1) if fc == Color() else _lv(fc, lvl2)
		ci.draw_texture(tex2, (Vector2(f.p) - Vector2(tex2.get_size()) * 0.5).round(), mod)
	for rg in _rings:
		var age2 := t - float(rg.t0)
		var dur: float = rg.dur
		if age2 > dur:
			continue
		var x2 := age2 / dur
		var rr := float(rg.r0) + (float(rg.r1) - float(rg.r0)) * _ease_out(x2)
		var lv5 := float(rg.s) * (1.0 if x2 < 0.25 else (0.7 if x2 < 0.5 else (0.45 if x2 < 0.75 else 0.22)))
		var rp_ := float(rg.r0) + (float(rg.r1) - float(rg.r0)) * _ease_out(maxf(0.0, age2 - 1.0 / 30.0) / dur)
		_draw_ring(ci, rg.p, int(rr), float(rg.squash), lv5, rg.col, false, clampi(int(rr) - int(rp_), 0, 8))
	for mo in _motes:
		var f2: float = mo.age / mo.life
		var p: Vector2 = (mo.p as Vector2).round()
		match int(mo.kind):
			0:
				var c := HEAT_RAMP[0] if f2 < 0.4 else (HEAT_RAMP[2] if f2 < 0.75 else HEAT_RAMP[4])
				ci.draw_rect(Rect2(p, Vector2.ONE), c)
				var tail: Vector2 = ((mo.p as Vector2) - (mo.v as Vector2).normalized() * 2.0).round()
				if tail != p:
					ci.draw_rect(Rect2(tail, Vector2.ONE), c * Color(0.5, 0.5, 0.5, 1))
			1:
				var c1 := HEAT_RAMP[1] if f2 < 0.25 else (HEAT_RAMP[2] if f2 < 0.5 else (HEAT_RAMP[3] if f2 < 0.8 else HEAT_RAMP[5]))
				var sz := Vector2(2, 2) if mo.big and f2 < 0.5 else Vector2.ONE
				ci.draw_rect(Rect2(p, sz), c1)
			2:
				var gi := 0 if f2 < 0.2 else (1 if f2 < 0.5 else (2 if f2 < 0.8 else 3))
				var gl: float = [1.0, 0.75, 0.5, 0.3][gi]
				var gc := _lv(GAS[gi], gl)
				ci.draw_rect(Rect2(p, Vector2.ONE), gc)
				if mo.big and f2 < 0.4:
					var arm := _lv(GAS[gi], gl * 0.4)
					for o in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
						ci.draw_rect(Rect2(p + o, Vector2.ONE), arm)
			3:
				var c3: Color
				if f2 < 0.22:
					c3 = mo.c
				elif f2 < 0.45:
					c3 = _lv(TEAL[0], 0.9)
				elif f2 < 0.7:
					c3 = _lv(TEAL[1], 0.7)
				elif f2 < 0.88:
					c3 = _lv(TEAL[2], 0.55)
				else:
					c3 = _lv(TEAL[3], 0.4)
				ci.draw_rect(Rect2(p, Vector2.ONE), c3)
			4:
				var c4 := HEAT_RAMP[1] if f2 < 0.2 else (HEAT_RAMP[2] if f2 < 0.45 else (HEAT_RAMP[3] if f2 < 0.7 else (HEAT_RAMP[4] if f2 < 0.88 else HEAT_RAMP[5])))
				var sz4 := Vector2(2, 2) if mo.big and f2 < 0.6 else Vector2.ONE
				ci.draw_rect(Rect2(p, sz4), c4)
			5, 6, 7:
				# Soft light (a creature's last light, its fluid, its spores):
				# held steps down, the big ones a gathered plus while young.
				var l5 := 1.0 if f2 < 0.3 else (0.6 if f2 < 0.55 else (0.35 if f2 < 0.8 else 0.18))
				var c5: Color = mo.c
				if int(mo.kind) == 7:
					c5 = SPORE[0 if f2 < 0.25 else (1 if f2 < 0.5 else (2 if f2 < 0.8 else 3))]
					l5 = 1.0 if f2 < 0.5 else (0.7 if f2 < 0.8 else 0.45)
				var lc := _lv(c5, l5 * (0.8 if int(mo.kind) == 6 else 1.0))
				if int(mo.kind) == 6 and mo.big and f2 < 0.6:
					ci.draw_rect(Rect2(p, Vector2(2, 2)), lc)
				else:
					ci.draw_rect(Rect2(p, Vector2.ONE), lc)
				if mo.big and f2 < 0.5 and int(mo.kind) != 6:
					var arm := _lv(c5, l5 * 0.4)
					for o in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
						ci.draw_rect(Rect2(p + o, Vector2.ONE), arm)


func _light_slice(ci: CanvasItem, tt: float) -> void:
	if tt < 0.0 or tt >= 0.36:
		return
	var sl: Dictionary = _plan.slice
	var c: Vector2 = _origin + (sl.c as Vector2)
	var d: Vector2 = sl.d
	var nn: Vector2 = sl.n
	var side := Vector2(roundf(nn.x), roundf(nn.y))
	var ut := _slice_tip_u()
	var lvl := 1.0 if tt < 0.28 else (0.55 if tt < 0.32 else 0.25)
	var u_end := minf(ut, float(sl.u1) + 40.0)
	var u := float(sl.u0) - 40.0
	var last := Vector2.INF
	while u <= u_end:
		var p := (c + d * u).round()
		if p != last:
			ci.draw_rect(Rect2(p, Vector2.ONE), _lv(Color(1.0, 0.97, 0.9), lvl))
			if ((int(p.x) + int(p.y)) & 1) == 0:
				ci.draw_rect(Rect2(p + side, Vector2.ONE), _lv(HEAT_RAMP[2], lvl * 0.5))
				ci.draw_rect(Rect2(p - side, Vector2.ONE), _lv(HEAT_RAMP[2], lvl * 0.5))
			last = p
		u += 1.0
	# the cut so far, white-hot
	var kp: PackedVector2Array = sl.kp
	var ku: PackedFloat32Array = sl.ku
	for i in kp.size():
		if ku[i] <= ut:
			ci.draw_rect(Rect2(_origin + kp[i], Vector2.ONE), _lv(HEAT_RAMP[0], lvl))
	if tt < 0.28:
		var tex := _warm(7)
		ci.draw_texture(tex, (c + d * ut - Vector2(tex.get_size()) * 0.5).round(), Color(1, 1, 1, 1))


func _light_dissolve(ci: CanvasItem, tt: float) -> void:
	if tt < 0.0:
		return
	var f := _front(tt)
	var fade := 1.0
	if tt >= 1.2:
		fade = 0.75 if tt < 1.3 else (0.5 if tt < 1.42 else (0.25 if tt < 1.55 else 0.0))
	if fade <= 0.0:
		return
	var dd: Dictionary = _plan.dis
	var thr: PackedFloat32Array = dd.thr
	var dp: PackedVector2Array = dd.p
	var i := _dis_ptr
	while i < _dis_order.size():
		var j := _dis_order[i]
		var tv := thr[j]
		if tv < f - 0.06:
			break
		_glow_px(ci, _origin + dp[j], f - tv, fade)
		i += 1
	var ed: Dictionary = _plan.edge
	var et: PackedFloat32Array = ed.thr
	var ep: PackedVector2Array = ed.p
	for k in ep.size():
		var tv2 := et[k]
		if tv2 >= f - 0.06 and tv2 <= f:
			_glow_px(ci, _origin + ep[k], f - tv2, fade)


func _glow_px(ci: CanvasItem, p: Vector2, depth: float, fade: float) -> void:
	if depth < 0.025:
		ci.draw_rect(Rect2(p, Vector2.ONE), _lv(TEAL[0], 0.8 * fade))
	elif ((int(p.x) + int(p.y)) & 1) == 0:
		ci.draw_rect(Rect2(p, Vector2.ONE), _lv(TEAL[1], 0.45 * fade))


func _light_shield(ci: CanvasItem, tt: float) -> void:
	if tt < 0.0:
		return
	if tt < 0.42:
		var st := _shield_strength(tt)
		if st <= 0.0:
			return
		for c in _cells:
			if tt >= float(c.drop):
				continue
			ci.draw_texture(c.tex, _origin + (c.at as Vector2), _lv(SHIELD_COL, st))
		return
	var age := tt - 0.42
	if age >= 0.42:
		return
	var lvl := 1.0 if age < 0.08 else (0.65 if age < 0.18 else (0.4 if age < 0.3 else 0.2))
	for c2 in _cells:
		if float(c2.drop) < 0.42:
			continue
		var dist := float(c2.speed) * (1.0 - exp(-2.6 * age)) / 2.6
		ci.draw_texture(c2.tex, (_origin + (c2.at as Vector2) + (c2.dir as Vector2) * dist).round(), _lv(SHIELD_COL, lvl))


func _light_melt(ci: CanvasItem, tt: float) -> void:
	if tt < 0.0:
		return
	var lvl := 0.0
	if tt < 0.15:
		lvl = 0.25
	elif tt < 0.3:
		lvl = 0.5
	elif tt < 0.45:
		lvl = 0.75
	elif tt < 1.3:
		lvl = 1.0
	elif tt < 1.45:
		lvl = 0.75
	elif tt < 1.6:
		lvl = 0.5
	elif tt < 1.78:
		lvl = 0.25
	if lvl <= 0.0:
		return
	var col: Color = HEAT_RAMP[1] if lvl >= 1.0 else (HEAT_RAMP[2] if lvl >= 0.75 else (HEAT_RAMP[3] if lvl >= 0.5 else HEAT_RAMP[4]))
	var mod := _lv(col, 0.55 + 0.45 * lvl)
	if t < _split_at:
		_stage_get(_stage_now())
		ci.draw_texture(_stage_heat[_stage_now()], _origin + _stage_at - Vector2(2, 2), mod)
	else:
		for m in _majors:
			if m.has("heat"):
				ci.draw_texture(m.heat, _major_pos_new(m) - Vector2(2, 2), mod)


# ================================================================== N-P: CREATURES
#
# Jon (Oct 13): the Voidwhale Calf and the Void Leviathan get "a more natural
# death animation that's different from the ships". No metal: nothing cracks
# white, nothing flies off in shards, no fire. Something living dying in space:
# its own lights go out, it curls, it blooms spores, it parts at its segments.
# Its glow is its OWN pixels (the warm, saturated, bright ones -- 7% of the
# calf, 3% of the Leviathan): the body is drawn with them dark, and the light
# layer gives them back as gathered light (the pixel, a halo brighter where
# they crowd, dithered at its edge), so "going out" is the light stepping down,
# never a colour swap.

## Bioluminescent spores: a pale green-white thinning to deep teal.
const SPORE: Array[Color] = [Color("#e2fff2"), Color("#97f0c9"), Color("#45b88f"), Color("#1d6650")]
const CURL_STEPS := 6
const PART_TEAR: Array[float] = [0.15, 0.35, 0.55]


static func _is_glow(c: Color) -> bool:
	return c.a > 0.6 and c.s > 0.45 and c.v > 0.55 and (c.h < 0.17 or c.h > 0.93)


## GLOW OUT's curl: each column lifted by a whole number of pixels, more toward
## the ends, so head and tail bend the same way into a slow C. No column turns,
## so nothing shimmers; it only shears.
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
		box = Rect2i(r.position + Vector2i(int(H.x0), int(H.y0)), Vector2i(int(bw), int(bh)))}
	var lab := PackedInt32Array()
	lab.resize(n)
	var sm := PackedByteArray()
	sm.resize(n)
	var k := 1
	var nb := 4 if st == Style.GLOWOUT else 3
	var body_col := col
	var body_mask := mask
	match st:
		Style.GLOWOUT:
			var cu := {a = clampf(0.1 * bw, 6.0, 20.0), xm = cx, half = bw * 0.5}
			plan.curl = cu
			var cp := _curl_pic(H, col, mask, cu, 1.0)
			body_col = cp.col
			body_mask = cp.mask
			plan.glob = Vector2i(3, -2)
		Style.BLOOM:
			plan.glob = Vector2i(-2, 1)
		Style.PART:
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
	if st != Style.PART:
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
		if st == Style.PART:
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
			if st == Style.PART:
				gb.append(lab[i])
			else:
				gb.append(clampi(int((float(x) - float(H.x0)) / bw * nb), 0, nb - 1))
	plan.glow = {p = gp, c = gc, band = gb}
	plan.nb = nb
	return {majors = mj, shards = [], centre = r.position + Vector2i(int(cx), int(cy)), plan = plan}


# ---------------------------------------------------------------- the film

var _gl_tex: Array = []   ## [stage][band] -> {tex, at (canvas)}
var _fluid := Color("#e07a5a")
var _body_px := PackedVector2Array()
var _torn := PackedByteArray()


## Glowing pixels as gathered light: each pixel its own colour (added over the
## dark it is drawn with, so full light gives the art back exactly), a halo
## that adds up where they crowd, its faint edge dithered.
func _glow_band(pts: PackedVector2Array, cols: PackedColorArray, mean: Color) -> Dictionary:
	if pts.is_empty():
		return {tex = null, at = Vector2.ZERO}
	var lo := Vector2i(1 << 20, 1 << 20)
	var hi := Vector2i(-(1 << 20), -(1 << 20))
	for p in pts:
		lo = Vector2i(mini(lo.x, int(p.x)), mini(lo.y, int(p.y)))
		hi = Vector2i(maxi(hi.x, int(p.x)), maxi(hi.y, int(p.y)))
	lo -= Vector2i(3, 3)
	hi += Vector2i(3, 3)
	var W := hi.x - lo.x + 1
	var Hh := hi.y - lo.y + 1
	var acc := PackedFloat32Array()
	acc.resize(W * Hh)
	var core := {}
	for i in pts.size():
		var q := Vector2i(pts[i]) - lo
		core[q] = cols[i]
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var kk := 1.0 - sqrt(float(dx * dx + dy * dy)) / 3.0
				if kk > 0.0:
					acc[(q.y + dy) * W + q.x + dx] += kk
	var im := Image.create(W, Hh, false, Image.FORMAT_RGBA8)
	for y in Hh:
		for x in W:
			var q2 := Vector2i(x, y)
			if core.has(q2):
				var c: Color = core[q2]
				im.set_pixel(x, y, Color(c.r * 0.7, c.g * 0.7, c.b * 0.7, 1.0))
				continue
			var a := acc[y * W + x]
			if a >= 2.0:
				im.set_pixel(x, y, _lv(mean, 0.3))
			elif a >= 0.8 and ((x + lo.x + y + lo.y) & 1) == 0:
				im.set_pixel(x, y, _lv(mean, 0.16))
	return {tex = ImageTexture.create_from_image(im), at = Vector2(lo)}


func _setup_creature(img: Image, used: Rect2i, seed: int) -> void:
	_lead = 0.0
	duration = float(LIFE[style])
	_cut = cut(img, used, seed, false, style)
	_plan = _cut.get("plan", {})
	_centre = _origin + Vector2(_cut.centre)
	_flash_tex = ImageTexture.create_from_image(_radial_light(22))
	_plan_events()
	for m in _cut.majors:
		var mi: Image = m.image
		var tex := ImageTexture.create_from_image(mi)
		_majors.append({tex = tex, stages = [tex], images = [mi], at = m.at, off = m.off, own = m.own,
			glob = m.glob, crack = m.crack, dir = m.dir, lab = m.lab,
			glow = ImageTexture.create_from_image(_glow_image(m.crack, mi.get_size()))})
		for y in mi.get_height():
			for x in mi.get_width():
				if mi.get_pixel(x, y).a > 0.0 and _rng.randf() < 0.12:
					_body_px.append(Vector2(m.at) + Vector2(x, y))
	var gl: Dictionary = _plan.glow
	var gp: PackedVector2Array = gl.p
	var gc: PackedColorArray = gl.c
	var gb: PackedInt32Array = gl.band
	var nb: int = _plan.nb
	var mean := Color(0, 0, 0)
	for c in gc:
		mean += c
	if gc.size() > 0:
		mean = mean / float(gc.size())
		_fluid = Color(mean.r, mean.g, mean.b, 1.0)
	var steps := CURL_STEPS + 1 if style == Style.GLOWOUT else 1
	for s in steps:
		var row: Array = []
		for b in nb:
			var pts := PackedVector2Array()
			var cs := PackedColorArray()
			for i in gp.size():
				if gb[i] != b:
					continue
				var p := gp[i]
				if style == Style.GLOWOUT:
					var cu: Dictionary = _plan.curl
					var lx := p.x - float((_plan.r as Rect2i).position.x)
					p.y += _curl_dy(lx, cu, float(s) / float(CURL_STEPS))
				pts.append(p)
				cs.append(gc[i])
			row.append(_glow_band(pts, cs, _fluid))
		_gl_tex.append(row)
	if style == Style.GLOWOUT:
		var H := _hull_pic(img, used, 12)
		var raw: PackedColorArray = H.raw
		var mask: PackedByteArray = H.mask
		var col := PackedColorArray()
		col.resize(raw.size())
		for i in raw.size():
			if mask[i] == 1:
				var c2 := raw[i]
				col[i] = Color(c2.r * 0.3, c2.g * 0.3, c2.b * 0.3, c2.a) if _is_glow(c2) else c2
		_stage_at = Vector2((H.r as Rect2i).position)
		for s2 in CURL_STEPS + 1:
			var cp := _curl_pic(H, col, mask, _plan.curl, float(s2) / float(CURL_STEPS))
			_stage_tex.append(ImageTexture.create_from_image(_pic_image(H, cp.col, cp.mask)))
	if style == Style.PART:
		_torn.resize(PART_TEAR.size() + 2)


func _plan_creature() -> float:
	var nb: int = _plan.nb
	match style:
		Style.GLOWOUT:
			_ev(0.0, &"flare", 0.5)
			_ev(0.0, &"groan", 0.5, 1.8)
			_ev(0.3, &"curl", 0.3, 1.32)
			for b in nb:
				_ev(0.35 + 0.3 * b, &"dim", 0.3, 0.0, Vector2.INF, {band = b})
			_ev(1.7, &"still", 0.15)
			return 1.5
		Style.BLOOM:
			_ev(0.0, &"flare", 0.6)
			_ev(0.25, &"bloom", 0.8)
			_ev(0.25, &"spores", 0.5, 1.0)
			for b in nb:
				_ev(0.7 + 0.2 * b, &"dim", 0.3, 0.0, Vector2.INF, {band = b})
			_ev(1.3, &"still", 0.15)
			return 0.0
		Style.PART:
			_ev(0.0, &"pulse", 0.4)
			for i in nb - 1:
				_ev(PART_TEAR[i], &"tear", 0.4 + 0.1 * i, 0.0, Vector2.INF, {seam = i})
			_ev(0.15, &"fluid", 0.4, 1.4)
			for b in nb:
				_ev(0.7 + 0.2 * b, &"dim", 0.3, 0.0, Vector2.INF, {band = b})
			_ev(1.6, &"still", 0.15)
			return 0.15
	return 0.0


## How lit band `b` is: a last flare, held, then out in four held steps.
func _glow_lvl(b: int, tt: float) -> float:
	var out := 0.0
	var flare := 1.0
	match style:
		Style.GLOWOUT:
			out = 0.35 + 0.3 * b
			flare = 1.15 if tt < 0.08 else (1.3 if tt < 0.2 else 1.0)
		Style.BLOOM:
			out = 0.7 + 0.2 * b
			flare = 1.15 if tt < 0.1 else (1.4 if tt < 0.3 else 1.0)
		Style.PART:
			out = 0.7 + 0.2 * b
			flare = 1.2 if tt < 0.1 else 1.0
	if tt < out:
		return flare
	var a := tt - out
	return 0.6 if a < 0.08 else (0.3 if a < 0.16 else (0.12 if a < 0.26 else 0.0))


func _fire_creature(e: Dictionary) -> void:
	match e.kind:
		&"dim":
			# What light it had leaves it as a few motes, drifting off slowly.
			var gl: Dictionary = _plan.glow
			var gp: PackedVector2Array = gl.p
			var gc: PackedColorArray = gl.c
			var gb: PackedInt32Array = gl.band
			var mine: Array[int] = []
			for i in gp.size():
				if gb[i] == int(e.band):
					mine.append(i)
			for j in mini(12, mine.size()):
				var i2 := mine[_rng.randi() % mine.size()]
				var p := _creature_glow_pos(gp[i2], int(e.band))
				var v := (p - _centre).normalized() * _rng.randf_range(6.0, 16.0) \
					+ Vector2(_rng.randf_range(-4.0, 4.0), _rng.randf_range(-4.0, 4.0))
				_mote(p, v, _rng.randf_range(0.6, 1.0), 5, _rng.randf() < 0.3, gc[i2], 0.3)
		&"bloom":
			for j in 280:
				_spore()
		&"tear":
			var sd: Dictionary = _plan.seams
			var sp: PackedVector2Array = sd.p
			var si: PackedInt32Array = sd.i
			var seam: int = e.seam
			_torn[seam] = 1
			for i in sp.size():
				if si[i] != seam or _rng.randf() > 0.55:
					continue
				var side := 1.0 if _rng.randf() < 0.5 else -1.0
				_mote(_origin + sp[i], Vector2(side * _rng.randf_range(4.0, 14.0), _rng.randf_range(-6.0, 6.0)),
					_rng.randf_range(0.8, 1.3), 6, _rng.randf() < 0.35, _fluid, 0.4)


## Where a glow pixel is drawn now (it rides the curl, the drift, its segment).
func _creature_glow_pos(p: Vector2, band: int) -> Vector2:
	var q := _origin + p + _hull_shift()
	if style == Style.GLOWOUT:
		var lx := p.x - float((_plan.r as Rect2i).position.x)
		q.y += _curl_dy(lx, _plan.curl, float(_curl_stage()) / float(CURL_STEPS))
	elif style == Style.PART:
		for m in _majors:
			if int(m.lab) == band:
				q += _major_pos_new(m) - (_origin + Vector2(m.at))
	return q


func _spore() -> void:
	if _body_px.is_empty():
		return
	var gl: Dictionary = _plan.glow
	var gp: PackedVector2Array = gl.p
	var p: Vector2
	if _rng.randf() < 0.5 and not gp.is_empty():
		p = _origin + gp[_rng.randi() % gp.size()] + _hull_shift()
	else:
		p = _origin + _body_px[_rng.randi() % _body_px.size()] + _hull_shift()
	var v := (p - _centre).normalized() * _rng.randf_range(12.0, 46.0) \
		+ Vector2(_rng.randf_range(-8.0, 8.0), _rng.randf_range(-8.0, 8.0))
	_mote(p, v, _rng.randf_range(0.7, 1.2), 7, _rng.randf() < 0.55, Color.WHITE, 0.5)


func _tick_creature(delta: float, tt: float) -> void:
	match style:
		Style.BLOOM:
			if tt >= 0.25 and tt < 1.25:
				var rate := 440.0 * snappedf(1.0 - (tt - 0.25) / 1.0, 0.25)
				var n := int(rate * delta + _rng.randf())
				for i in n:
					_spore()
		Style.PART:
			var torn := 0
			for x in _torn:
				torn += int(x)
			if torn > 0 and tt < 1.3:
				var rate2 := 50.0 * float(torn) / float(maxi(1, int(_plan.nb) - 1)) * (1.0 if tt < 1.0 else 0.5)
				var n2 := int(rate2 * delta + _rng.randf())
				for i in n2:
					var m: Dictionary = _majors[_rng.randi() % _majors.size()]
					var cr: PackedVector2Array = m.crack
					if cr.is_empty():
						continue
					var q := _major_pos_new(m) + cr[_rng.randi() % cr.size()]
					var side := signf(q.x - (_major_pos_new(m).x + float((m.tex as ImageTexture).get_width()) * 0.5))
					_mote(q, Vector2(side * _rng.randf_range(3.0, 10.0), _rng.randf_range(-5.0, 5.0)),
						_rng.randf_range(0.6, 1.0), 6, _rng.randf() < 0.3, _fluid, 0.4)


func _curl_stage() -> int:
	var tt := t - _lead
	if tt < 0.3:
		return 0
	return mini(CURL_STEPS, 1 + int((tt - 0.3) / 0.22))


func _creature_tint() -> Color:
	if done:
		return WRECK_TINT
	var q := snappedf(clampf((t - 0.3) / (duration - 0.5), 0.0, 1.0), 0.25)
	return Color.WHITE.lerp(WRECK_TINT, q)


func _paint_creature_body(ci: CanvasItem) -> void:
	var tint := _creature_tint()
	if style == Style.GLOWOUT and t < _split_at and not _stage_tex.is_empty():
		ci.draw_texture(_stage_tex[_curl_stage()], _origin + _stage_at + _hull_shift(), tint)
	else:
		for m in _majors:
			ci.draw_texture(m.tex, _major_pos_new(m), tint)
	if style == Style.PART:
		var sd: Dictionary = _plan.seams
		var sp: PackedVector2Array = sd.p
		var sc: PackedColorArray = sd.c
		var si: PackedInt32Array = sd.i
		for i in sp.size():
			if _torn[si[i]] == 0:
				ci.draw_rect(Rect2(_origin + sp[i], Vector2.ONE), sc[i] * tint)


func _paint_creature_light(ci: CanvasItem, tt: float) -> void:
	var nb: int = _plan.nb
	var row: Array = _gl_tex[_curl_stage() if style == Style.GLOWOUT else 0]
	for b in nb:
		var l := _glow_lvl(b, tt)
		var g: Dictionary = row[b]
		if l <= 0.0 or g.tex == null:
			continue
		var at := _origin + (g.at as Vector2) + _hull_shift()
		if style == Style.PART:
			for m in _majors:
				if int(m.lab) == b:
					at += _major_pos_new(m) - (_origin + Vector2(m.at) + _hull_shift())
		ci.draw_texture(g.tex, at.round(), Color(l, l, l, 1.0))
	if style == Style.PART:
		var on := 0.0
		if tt >= 0.15:
			on = 1.0 if tt < 0.6 else (0.75 if tt < 0.9 else (0.5 if tt < 1.15 else (0.25 if tt < 1.4 else 0.0)))
		if on > 0.0:
			for m2 in _majors:
				ci.draw_texture(m2.glow, _major_pos_new(m2) - Vector2(GLOW_PAD, GLOW_PAD),
					Color(0.5 * on, 0.22 * on, 0.18 * on, 1.0))
