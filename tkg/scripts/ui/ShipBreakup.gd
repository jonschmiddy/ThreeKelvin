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
	SHIELD, MELT, CRUMPLE, GLOWOUT, BLOOM, PART,
	CUST_CASCADE, CUST_UNMAKING, CUST_SUPERNOVA, HELL_CHAIN, HELL_BURNOUT, HELL_UNCOIL,
	CUST_COLLAPSE, CUST_SPLIT }

## How long each style runs to its resting wreck, seconds. A normal kill is held
## for this before the fight is allowed to end (audit item 2 as Jon ruled it).
const LIFE := {Style.SNAP: 1.15, Style.BURN: 1.6, Style.IMPLODE: 1.45,
	Style.BREACH: 1.6, Style.CHAIN: 1.75, Style.OVERLOAD: 1.5, Style.VENT: 1.7,
	Style.SLICE: 1.4, Style.DISSOLVE: 1.8, Style.COLLAPSE: 1.6, Style.SHIELD: 1.65,
	Style.MELT: 2.0, Style.CRUMPLE: 1.5,
	Style.GLOWOUT: 2.2, Style.BLOOM: 2.0, Style.PART: 2.0,
	Style.CUST_CASCADE: 7.5, Style.CUST_UNMAKING: 8.0, Style.CUST_SUPERNOVA: 7.0,
	Style.HELL_CHAIN: 7.5, Style.HELL_BURNOUT: 8.0, Style.HELL_UNCOIL: 9.5,
	Style.CUST_COLLAPSE: 7.5, Style.CUST_SPLIT: 7.5}
## Letter and name, as the pick page shows them.
const NAMES := {Style.SNAP: "A  SNAP", Style.BURN: "B  BURN", Style.IMPLODE: "C  IMPLODE",
	Style.BREACH: "D  BREACH", Style.CHAIN: "E  CHAIN", Style.OVERLOAD: "F  OVERLOAD",
	Style.VENT: "G  VENT", Style.SLICE: "H  SLICE", Style.DISSOLVE: "I  DISSOLVE",
	Style.COLLAPSE: "J  COLLAPSE", Style.SHIELD: "K  SHIELD", Style.MELT: "L  MELT",
	Style.CRUMPLE: "M  CRUMPLE", Style.GLOWOUT: "N  GLOW OUT", Style.BLOOM: "O  BLOOM",
	Style.PART: "P  PART", Style.CUST_CASCADE: "C1a  SHATTER OUTWARD", Style.CUST_UNMAKING: "C2  UNMAKING",
	Style.CUST_SUPERNOVA: "C3  SUPERNOVA", Style.HELL_CHAIN: "H1  CHAIN REACTION", Style.HELL_BURNOUT: "H2  BURN-OUT",
	Style.HELL_UNCOIL: "H3  UNCOIL", Style.CUST_COLLAPSE: "C1b  COLLAPSE INWARD",
	Style.CUST_SPLIT: "C1c  SPLIT ALONG THE SPINE"}
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
	Style.PART: "Creatures. It parts softly along its segments, glowing fluid drifting from the seams as its lights fade.",
	Style.CUST_CASCADE: "The Custodian. Its facets crack one by one along the spine, each shooting a beam of white light, and a ball of light swells at its centre. Then a white blast from the centre: the facets fly outward as big tumbling, glinting shards and slow, settling into the wreck.",
	Style.CUST_COLLAPSE: "The Custodian. The same cracks and beams and the swelling centre; then the implosion crushes the cluster in on its centre, and a ring of light blows the pieces back out in layers, the outer ones first.",
	Style.CUST_SPLIT: "The Custodian. The same cracks and beams and the swelling centre; then a blast at the centre runs along the silver spine to both ends, and the guardian breaks in half, the halves drifting apart, glass shedding from the break.",
	Style.CUST_UNMAKING: "The Custodian. It loses cohesion: the facets drift apart on the spine, its lights go out one by one, then each facet shatters in turn, in slow motion, the glass glinting.",
	Style.CUST_SUPERNOVA: "The Custodian. A rising whine, the core white-hot through the glass until the whole body glows; a flash fills the enemy's half, a dark ring follows, and the body is left charred and smoking.",
	Style.HELL_CHAIN: "The Hellbender. Reactor alarms strobe, blasts march through the hull from the stern, the holds burst and spill glowing stolen cargo, then the main reactor goes and the hull splits in two.",
	Style.HELL_BURNOUT: "The Hellbender. Fire spreads from the salamander device, which glows red-hot; blasts walk through it; it lists nose-down and breaks apart, the pieces trailing fire.",
	Style.HELL_UNCOIL: "The Hellbender. Gold light climbs its ribs' own seams from the hold outward; the salamander device heats red, then white, flames licking off it, and bursts; alarms and shakes build; the holds burst, spilling glowing stolen crates and canisters; then the light breaks out in a huge blast and the hull flies apart rib section by rib section, tumbling, trailing gold, settling as scattered wreckage."}
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
	Style.PART: "0.00 pulse; 0.15 / 0.35 / 0.55 tear (soft, wet, each a little bigger); 0.15 fluid, 1.4 long (drips, bubbles); 0.70 on, one dim a segment; 1.60 still",
	Style.CUST_CASCADE: "0.25 on, every 0.32 s, eight times: crack (shake 1) with a beam (a hum held to 4.4); 3.00 swell, 1.4 long + duck 3.5; 4.40 implode 0.5 + slowmo 0.35 for 0.7 s; 4.90 blast + flash 1.0 + shake 6 + stinger; 4.90 shatter, 1.5 long (big glass, tumbling); 5.00 debris, 2.0 long; 5.60 cool, 1.8 long",
	Style.CUST_COLLAPSE: "0.25 on, every 0.32 s: crack (shake 1) with a beam (held to 4.2); 3.00 swell + duck 3.5; 4.20 crush, 0.8 long (grinding, shake 2) + slowmo 0.35 from 4.6; 5.00 blast + flash 1.0 + shake 6 + stinger; 5.00 layer (the outer pieces); 5.25 layer (the inner); 5.30 debris, 2.0 long; 5.80 cool, 1.6 long",
	Style.CUST_SPLIT: "0.25 on, every 0.32 s: crack (shake 1) with a beam (held to 4.4); 3.00 swell + duck 3.5; 4.40 implode + slowmo 0.35; 4.90 blast + flash 1.0 + shake 6 + stinger; 4.95 run, 0.5 long (tearing along the spine) with pops out to both ends; 5.50 split (a deep crack, shake 3); 5.50 shed, 1.5 long (glass); 5.80 cool, 1.6 long",
	Style.CUST_UNMAKING: "0.00 groan, 2.8 long + duck 7.5; 0.8-3.2 light_out (one per light, a falling ping); 3.20 on, every 0.42 s, eight times: shatter (glass, slowed) + shake 1; slowmo 0.6 from 3.2 for 3.6 s; stinger at the last shatter; 6.60 settle, 1.2 long",
	Style.CUST_SUPERNOVA: "0.00 whine, 2.6 long (rising); 1.00 duck 4.0; 1.60 shake 1, 2.20 shake 2; 2.60 nova + flash 1.0 (0.45) + slowmo 0.3 + shake 9 + stinger; 2.90 ring, 1.2 long (a deep rush); 3.00 smoulder, 4.0 long; 3.4 / 4.1 / 4.9 / 5.8 crackle",
	Style.HELL_CHAIN: "0.00 alarm, 2.8 long (klaxon, faster from 1.6) + duck 6.5; 1.20 / 1.55 / 1.85 / 2.15 / 2.40 / 2.62 blast (marching, louder) + shake 2; 3.00 and 3.20 rupture; 3.00 spill, 1.6 long (a rush of loose cargo); 4.60 reactor + flash 0.7 + slowmo 0.4 + shake 7 + stinger; 4.70 debris, 2.0 long; 5.50 cool, 1.8 long",
	Style.HELL_BURNOUT: "0.00 ignite; 0.00 roar, 5.4 long (fire) + duck 7.5; 2.60 / 3.00 / 3.35 / 3.90 / 4.30 blast + shake 2.5; 3.00 list, 2.0 long (groaning metal); 5.20 break + shake 4 + stinger; 5.30 debris, 2.0 long",
	Style.HELL_UNCOIL: "0.00 hum, 3.0 long + duck 9.0; 0.3-2.7 charge (one per rib section, from the middle out, rising); 1.50 emblem_heat, 4.1 long (a rising sizzle); 2.00 flames, 3.6 long (a roar); 3.00 alarm, 3.4 long (klaxon, quickening); shakes 1, 2, 3, 4 at 3.5, 4.3, 5.0, 5.8; 5.60 emblem_burst (a sharp bang); 6.00 and 6.15 rupture; 6.00 spill, 1.5 long; 6.3-7.6 pop (crates bursting, ticks); 7.00 burst + flash 1.0 (0.45) + shake 9 + slowmo 0.3 + stinger; 7.05 scatter, 1.6 long (a whoosh and a clatter); 8.60 cool, 0.9 long"}
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
	if the_style >= Style.CUST_CASCADE:
		return _cut_boss(img, used, seed, the_style)
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
			if int(m.get("rot_final", 0)) == 2:
				im = im.duplicate()
				im.rotate_180()
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
		rng: RandomNumberGenerator, per: int = 26, density: float = 0.035) -> Array:
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
			if rng.randf() < density:
				seeds.append(p)
		var want := maxi(1, pts.size() / per)
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
	if _is_boss(style):
		_setup_boss(img, used, seed)
		return
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
	if _is_boss(style):
		if kind in [&"blast", &"reactor", &"nova", &"break", &"burst", &"shatter", &"crack"]:
			broke.emit(s)
		_fire_boss(e)
		return
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
	if _is_boss(style):
		_tick_boss(delta)
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
	if _is_boss(style):
		return _boss_pos(m)
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
	if _is_boss(style):
		return _boss_stage(m)
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
	if _is_boss(style):
		_paint_boss_body(ci)
		return
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
	if _is_boss(style):
		_paint_boss_light(ci)
		morphing = true
	elif style >= Style.GLOWOUT:
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
			8:
				# stolen cargo, glowing: gold-white, cooling to amber, a plus while young
				var gi8 := 0 if f2 < 0.25 else (1 if f2 < 0.5 else (2 if f2 < 0.8 else 3))
				var l8: float = [1.0, 0.85, 0.6, 0.35][gi8]
				var g8 := _lv(GOLD[gi8], l8)
				ci.draw_rect(Rect2(p, Vector2(2, 2) if mo.big and f2 < 0.4 else Vector2.ONE), g8)
				if mo.big and f2 < 0.6:
					for o8 in [Vector2(2, 0), Vector2(-1, 0), Vector2(0, 2), Vector2(0, -1)]:
						ci.draw_rect(Rect2(p + o8, Vector2.ONE), _lv(GOLD[gi8], l8 * 0.4))
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


# ================================================================== BOSS SET PIECES
#
# Jon (Oct 13): "The custodian (and hellbender) these need ACTUAL epic death
# sequences." A boss's death is its own set piece, 7-8 s in phases, not the
# ship styles' burst run. Three for each:
#   THE CUSTODIAN (glass octahedra on a spine, orange pinpoint lights, a core)
#     C1 CASCADE    the facets crack one by one along the spine, each spilling a
#                   beam of white light; the core swells; everything is pulled
#                   in; a white blast and a shock ring; glass shards rain out
#                   and cool.
#     C2 UNMAKING   it loses cohesion: the facets drift apart on the spine, the
#                   lights go out one by one, then each facet shatters in turn,
#                   in slow motion, glass glinting as it turns.
#     C3 SUPERNOVA  a rising whine, the core white-hot through the glass until
#                   the whole body glows, a flash that fills the enemy's half,
#                   a dark ring, and the body left charred and smoking.
#   THE HELLBENDER (a rival harvester, its holds glowing with what it took)
#     H1 CHAIN      reactor alarms strobing, blasts marching through the hull,
#                   the holds rupturing and spilling glowing stolen cargo, then
#                   the main reactor: the hull splits in two.
#     H2 BURN-OUT   fire spreads from the salamander device, which glows
#                   red-hot; blasts walk through it; it lists (nose down, in
#                   whole-pixel slices) and breaks apart trailing fire.
#     H3 UNCOIL     (ours) the stolen light breaks out ring by ring: its ribs
#                   light gold from the hold outward, the hull stretches apart
#                   rib from rib, and the light bursts out, leaving a husk.
#
# The same rules as every death: pieces move in whole pixels (cut, never
# turned), light is drawn as light, nothing rises or falls, and the last frame
# is `wreck_image` exactly. Each piece's way to its rest is keyframed
# (`keys`), its picture changes at set times (`stage_t`), and the lights,
# beams, spheres, rings and emitters are data the clock plays.
#
# SCREEN HOOKS, AS MOMENTS (nothing here moves the screen): `shake` (s = px,
# length), `slowmo` (s = clock scale, length in screen time), `flash` (s =
# white's peak over the whole screen, length), `duck` (s = how far the music
# drops, length), `stinger` (a music hit). The harness applies them so the film
# shows the whole effect; SectorScreen can do the same later.

const BOSS_HOOKS := [&"shake", &"slowmo", &"flash", &"duck", &"stinger"]
const GOLD: Array[Color] = [Color("#fff6d8"), Color("#ffd97a"), Color("#e8a23a"), Color("#8a5418")]
const GLASS := Color("#cfeaff")
const ALARM := Color("#ff3a2a")

var _bp: Dictionary = {}          ## the boss plan (static cut's plan)
var _blights: Array = []          ## {p (canvas), m (piece idx or -1), keys [[t, lvl, r]], col}
var _bbeams: Array = []           ## {p, dir, m, keys [[t, len, lvl]]}
var _bspheres: Array = []         ## {p (screen), t0, grow, hold, fade, r1}
var _bdark: Array = []            ## {p (screen), t0, dur, r0, r1}
var _bemit: Array = []            ## {t0, t1, rate, kind, pts, m, mode, dir, spread, v0, v1, l0, l1, col, big}
var _bmaps: Array = []            ## {stages [ImageTexture], keys [[t, stage, lvl]], col}
var _smoke: Array = []            ## body-layer motes: {p, v, age, life}


static func _is_boss(st: int) -> bool:
	return st >= Style.CUST_CASCADE


## The bright warm pixels (the Custodian's pinpoints, the Hellbender's specks),
## gathered into lights: {p (canvas), n}. Largest first.
static func _boss_lights(H: Dictionary) -> Array:
	var w: int = H.w
	var h: int = H.h
	var r: Rect2i = H.r
	var raw: PackedColorArray = H.raw
	var mask: PackedByteArray = H.mask
	var hot := PackedByteArray()
	hot.resize(w * h)
	for i in w * h:
		if mask[i] == 1:
			var c := raw[i]
			if c.r > 0.7 and c.r >= c.b + 0.22 and c.get_luminance() > 0.5:
				hot[i] = 1
	var seen := PackedByteArray()
	seen.resize(w * h)
	var out: Array = []
	for i2 in w * h:
		if hot[i2] == 0 or seen[i2] == 1:
			continue
		var q: Array[int] = [i2]
		seen[i2] = 1
		var head := 0
		var sum := Vector2.ZERO
		while head < q.size():
			var cur := q[head]
			head += 1
			var cx := cur % w
			var cy := cur / w
			sum += Vector2(cx, cy)
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					var nx: int = cx + dx
					var ny: int = cy + dy
					if nx < 0 or ny < 0 or nx >= w or ny >= h:
						continue
					var j := ny * w + nx
					if hot[j] == 1 and seen[j] == 0:
						seen[j] = 1
						q.append(j)
		out.append({p = Vector2(r.position) + sum / float(q.size()), n = q.size()})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.n) > int(b.n))
	return out


## Vertical slices with jagged seams, for a long hull (the Hellbender's ribs).
static func _lab_slices(H: Dictionary, mask: PackedByteArray, k: int, rng: RandomNumberGenerator) -> PackedInt32Array:
	var w: int = H.w
	var h: int = H.h
	var bw := float(int(H.x1) - int(H.x0) + 1)
	var cy: float = H.cy
	var jag := _field(rng, w, h, 4)
	var xs: Array[float] = []
	var tilts: Array[float] = []
	for i in k - 1:
		xs.append(float(H.x0) + bw * ((float(i) + 1.0) / float(k) + rng.randf_range(-0.03, 0.03)))
		tilts.append(rng.randf_range(-0.2, 0.2))
	var lab := PackedInt32Array()
	lab.resize(w * h)
	for y in h:
		for x in w:
			var i2 := y * w + x
			if mask[i2] == 0:
				lab[i2] = -1
				continue
			var j := 0
			for f in k - 1:
				if float(x) > _fold_x(xs[f], tilts[f], jag, f, y, cy):
					j = f + 1
			lab[i2] = j
	return lab


## UNMAKING's glass to shatter: each piece's rim, three pixels deep, tagged
## 10 + the piece, so each piece's shatter is its own.
static func _mark_rims(H: Dictionary, lab: PackedInt32Array, sm: PackedByteArray, depth: int) -> void:
	var w: int = H.w
	var h: int = H.h
	var dist := PackedInt32Array()
	dist.resize(w * h)
	dist.fill(99)
	var q: Array[int] = []
	for y in h:
		for x in w:
			var i := y * w + x
			if lab[i] < 0:
				continue
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + o.x
				var ny: int = y + o.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h or lab[ny * w + nx] != lab[i]:
					dist[i] = 0
					q.append(i)
					break
	var head := 0
	while head < q.size():
		var cur := q[head]
		head += 1
		var d := dist[cur]
		if d >= depth - 1:
			continue
		var cx := cur % w
		var cy := cur / w
		for o2 in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx2: int = cx + o2.x
			var ny2: int = cy + o2.y
			if nx2 < 0 or ny2 < 0 or nx2 >= w or ny2 >= h:
				continue
			var j := ny2 * w + nx2
			if lab[j] == lab[cur] and dist[j] > d + 1:
				dist[j] = d + 1
				q.append(j)
	for i2 in w * h:
		if lab[i2] >= 0 and dist[i2] < depth and sm[i2] == 0:
			sm[i2] = 10 + lab[i2]


## Charred: darker in held steps, warm soot, the edges darkest. Still the ship.
static func _charred_all(im: Image, amt: float) -> Image:
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
			var k := 1.0 - amt * (0.55 if not edge else 0.7)
			if ((x + y) & 1) == 0:
				k -= amt * 0.06
			var q := Color(p.r * k, p.g * k, p.b * k).lerp(SOOT, amt * 0.3)
			out.set_pixel(x, y, Color(q.r, q.g, q.b, p.a))
	return out


static func _cut_boss(img: Image, used: Rect2i, seed: int, st: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 4441 + st * 37
	var H := _hull_pic(img, used, 0)
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
	var col: PackedColorArray = H.col
	var mask: PackedByteArray = H.mask
	var rp := Vector2(r.position)
	var lights := _boss_lights(H)
	var core := rp + Vector2(cx, cy)
	if not lights.is_empty():
		core = lights[0].p
	if st == Style.CUST_CASCADE or st == Style.CUST_COLLAPSE or st == Style.CUST_SPLIT:
		# Jon: "The explosion needs to be centered on the custodian, not the
		# front." The centre of its bounding box (139.5, 70 on take 1), not of its
		# ink mass, which the big front octahedron pulls 9 px forward.
		core = rp + Vector2(float(int(H.x0) + int(H.x1) + 1), float(int(H.y0) + int(H.y1) + 1)) * 0.5
	var plan := {r = r, glob = Vector2i.ZERO, lights = lights, core = core, cx = cx, cy = cy, bw = bw, bh = bh,
		box = Rect2i(r.position + Vector2i(int(H.x0), int(H.y0)), Vector2i(int(bw), int(bh)))}
	var sm := PackedByteArray()
	sm.resize(n)
	var lab := PackedInt32Array()
	var k := 1
	match st:
		Style.CUST_CASCADE:
			k = 8
			lab = _lab_voronoi(H, mask, k, rng)
			_mark_band(H, lab, sm, 3, rng)
		Style.CUST_COLLAPSE:
			# wedges round the centre, each cut again into an inner and an
			# outer layer
			k = 16
			lab.resize(n)
			var lc := core - rp
			var rot := rng.randf() * TAU
			var fd := _field(rng, w, h, 6)
			for y in h:
				for x in w:
					var i5 := y * w + x
					if mask[i5] == 0:
						lab[i5] = -1
						continue
					var u := Vector2((float(x) - lc.x) / (bw * 0.5), (float(y) - lc.y) / (bh * 0.5))
					var a := atan2(u.y, u.x) + 0.15 * _nz(fd, x, y) + rot
					var wedge := clampi(int(fposmod(a, TAU) / (TAU / 8.0)), 0, 7)
					var outer := 1 if u.length() + 0.05 * _nz(fd, y, x) > 0.5 else 0
					lab[i5] = wedge * 2 + outer
			_mark_band(H, lab, sm, 2, rng)
		Style.CUST_SPLIT:
			# the facets, each cut again along the spine: top and bottom halves
			k = 16
			var v := _lab_voronoi(H, mask, 8, rng)
			lab.resize(n)
			var jag2 := _field(rng, w, h, 5)
			var sy := core.y - rp.y
			var spine := PackedVector2Array()
			for y in h:
				for x in w:
					var i6 := y * w + x
					if mask[i6] == 0:
						lab[i6] = -1
						continue
					var line := sy + 1.6 * _nz(jag2, x, 0.0)
					lab[i6] = v[i6] * 2 + (1 if float(y) > line else 0)
					if absf(float(y) - line) < 1.6:
						sm[i6] = 3
						spine.append(rp + Vector2(x, y))
			_mark_band(H, lab, sm, 2, rng)
			plan.spine_pts = spine
		Style.CUST_UNMAKING:
			k = 8
			lab = _lab_voronoi(H, mask, k, rng)
			_mark_band(H, lab, sm, 1, rng)
			_mark_rims(H, lab, sm, 3)
		Style.CUST_SUPERNOVA:
			k = 1
			lab.resize(n)
			for i in n:
				lab[i] = 0 if mask[i] == 1 else -1
		Style.HELL_CHAIN:
			k = 2
			var split := float(int(H.x0)) + 0.42 * bw
			var jag := _field(rng, w, h, 4)
			lab.resize(n)
			for y in h:
				for x in w:
					var i2 := y * w + x
					if mask[i2] == 0:
						lab[i2] = -1
						continue
					lab[i2] = 0 if float(x) < split + 2.5 * _nz(jag, x, y) + 0.15 * (float(y) - cy) else 1
			_mark_band(H, lab, sm, 2, rng)
			var blasts: Array = []
			var bf := _field(rng, w, h, 3)
			var fr := [0.9, 0.78, 0.66, 0.55, 0.3, 0.16]
			for i3 in fr.size():
				var alt := (0.25 if i3 % 2 == 0 else -0.22) * bh
				var p := _nearest_hull(H, mask, Vector2(float(H.x0) + float(fr[i3]) * bw, cy + alt))
				_mark_disc(H, lab, sm, Vector2(p), 3.5, bf, 2 + i3)
				blasts.append(rp + Vector2(p))
			plan.blasts = blasts
			plan.reactor = rp + Vector2(split, cy)
			plan.holds = [rp + Vector2(_nearest_hull(H, mask, Vector2(float(H.x0) + 0.58 * bw, cy - 0.5 * bh))),
				rp + Vector2(_nearest_hull(H, mask, Vector2(float(H.x0) + 0.72 * bw, cy + 0.5 * bh)))]
		Style.HELL_BURNOUT:
			k = 5
			lab = _lab_slices(H, mask, k, rng)
			_mark_band(H, lab, sm, 1, rng)
		Style.HELL_UNCOIL:
			# Jon: "let's have the cracks follow the actual contours of the
			# ship's ribs." The seams are traced off the picture (`_rib_curves`);
			# the hull is cut at every second one and all of them are cracks.
			var curves := _rib_curves(H)
			lab.resize(n)
			var cuts: Array = []
			for ci in curves.size():
				if ci % 2 == 1:
					cuts.append(curves[ci])
			k = cuts.size() + 1
			for y in h:
				for x in w:
					var i7 := y * w + x
					if mask[i7] == 0:
						lab[i7] = -1
						continue
					var j7 := 0
					for c in cuts:
						var cx7: int = (c as Dictionary).full[y]
						if x > cx7:
							j7 += 1
					lab[i7] = j7
			var pts := PackedVector2Array()
			for c2 in curves:
				var tr: PackedInt32Array = (c2 as Dictionary).traced
				for y2 in h:
					var x2 := tr[y2]
					if x2 >= 0 and mask[y2 * w + x2] == 1:
						sm[y2 * w + x2] = 1
						pts.append(rp + Vector2(x2, y2))
			plan.rib_pts = pts
			plan.rib_count = curves.size()
			# the salamander device: the brightest thing in the front third
			var best_l := -1.0
			for y8 in h:
				for x8 in int(float(int(H.x0)) + 0.35 * bw):
					var i8 := y8 * w + x8
					if mask[i8] == 1 and raw[i8].get_luminance() > best_l:
						best_l = raw[i8].get_luminance()
						plan.emblem = rp + Vector2(x8, y8)
			plan.holds = [rp + Vector2(_nearest_hull(H, mask, Vector2(float(H.x0) + 0.5 * bw, cy - 0.5 * bh))),
				rp + Vector2(_nearest_hull(H, mask, Vector2(float(H.x0) + 0.68 * bw, cy + 0.5 * bh)))]
			core = rp + Vector2(cx, cy)
			plan.core = core
	var lit := _majors_of(H, raw, lab, sm, k)
	var mj := _majors_of(H, col, lab, sm, k)
	for i4 in mj.size():
		var m: Dictionary = mj[i4]
		var away: Vector2 = (m.mid as Vector2) - core
		var dir := away.normalized() if away.length() > 1.0 else Vector2(0, -1)
		var own := Vector2i.ZERO
		var dead: Image = m.image
		var stages: Array = [lit[i4].image]
		var j: int = m.lab
		match st:
			Style.CUST_CASCADE:
				own = Vector2i((dir * rng.randf_range(11.0, 16.0)).round())
				stages.append(_scorched(dead, m.at, core, 0.4 * bw))
			Style.CUST_COLLAPSE:
				own = Vector2i((dir * (rng.randf_range(10.0, 14.0) if j % 2 == 1 else rng.randf_range(5.0, 8.0))).round())
				stages.append(_scorched(dead, m.at, core, 0.4 * bw))
			Style.CUST_SPLIT:
				var top := j % 2 == 0
				own = Vector2i(roundi(signf(away.x) * rng.randf_range(1.0, 3.0)), -rng.randi_range(10, 13) if top else rng.randi_range(10, 13))
				stages.append(_scorched(dead, m.at, core, 0.3 * bw))
			Style.CUST_UNMAKING:
				own = Vector2i(roundi(((m.mid as Vector2).x - (rp.x + cx)) / (bw * 0.5) * 13.0), rng.randi_range(-2, 2))
				stages.append(dead)
			Style.CUST_SUPERNOVA:
				stages.append(_charred_all(dead, 0.75))
			Style.HELL_CHAIN:
				own = Vector2i(-10, -3) if j == 0 else Vector2i(11, 4)
				var cum: Image = dead
				for b in plan.blasts:
					cum = _scorched(cum, m.at, b, 8.0)
					stages.append(cum)
				stages.append(_scorched(cum, m.at, plan.reactor, 22.0))
			Style.HELL_BURNOUT:
				own = Vector2i((j - 2) * 4, (2 - j) * 4)
				stages.append(_charred_all(dead, 0.45))
				stages.append(_charred_all(dead, 0.8))
			Style.HELL_UNCOIL:
				# the rib sections fly apart and settle scattered, each upright or
				# turned over (quarter turns in flight, landing on a half turn or none)
				var sc := (dir + Vector2(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.6, 0.6))).normalized()
				own = Vector2i((sc * rng.randf_range(14.0, 28.0)).round())
				stages.append(_charred_all(dead, 0.55))
				m.rot_final = 2 if rng.randf() < 0.4 else 0
				m.rot_total = 4 * rng.randi_range(1, 2) + int(m.rot_final)
		# THE REST STAYS ON THE CANVAS. A fight draws a ship on a fixed canvas
		# (EnemyArt's 240x120), and a wreck is that canvas: a piece settling
		# past its edge would be cut off the wreck at the hand-off. So where a
		# piece comes to rest is kept inside it (H3's sections fly out up to 28 px
		# and land back within the margin there is).
		var isz: Vector2i = (m.image as Image).get_size()
		own.x = clampi(own.x, -int(m.at.x), img.get_width() - isz.x - int(m.at.x))
		own.y = clampi(own.y, -int(m.at.y), img.get_height() - isz.y - int(m.at.y))
		m.own = own
		m.glob = Vector2i.ZERO
		m.off = own
		m.dir = dir
		m.stages = stages
		m.image = stages.back()
		if int(m.get("rot_final", 0)) == 2:
			var turned: Image = (stages.back() as Image).duplicate()
			turned.rotate_180()
			m.image = turned
	var sh := _shards_of(H, raw, lab, sm, rng, 70, 0.012) if st == Style.CUST_CASCADE else _shards_of(H, raw, lab, sm, rng)
	return {majors = mj, shards = sh, centre = r.position + Vector2i(int(cx), int(cy)), plan = plan}


# ---------------------------------------------------------------- the boss's clock

func _setup_boss(img: Image, used: Rect2i, seed: int) -> void:
	_lead = 0.0
	duration = float(LIFE[style])
	_cut = cut(img, used, seed, false, style)
	_plan = _cut.get("plan", {})
	_bp = _plan
	_centre = _origin + Vector2(_cut.centre)
	_flash_tex = ImageTexture.create_from_image(_radial_light(22))
	for m in _cut.majors:
		var stex: Array = []
		for im in m.stages:
			stex.append(ImageTexture.create_from_image(im))
		var mi: Image = m.image
		# H3's ribs are close together: a three-pixel glow would flood them, so
		# its light is the contour and a dithered pixel beside it
		var gim := _thin_glow(m.crack, mi.get_size()) if style == Style.HELL_UNCOIL else _glow_image(m.crack, mi.get_size())
		_majors.append({tex = stex.back(), stages = stex, images = m.stages, at = m.at, off = m.off, own = m.own,
			glob = m.glob, crack = m.crack, dir = m.dir, lab = m.lab, mid = m.mid, keys = [], stage_t = [],
			glow = ImageTexture.create_from_image(gim), glow_keys = [], glow_col = 0,
			rot_final = int(m.get("rot_final", 0)), rot_total = int(m.get("rot_total", 0))})
	for s in _cut.shards:
		var im2: Image = s.image
		var sz := im2.get_size()
		var mid := Vector2(s.at) + Vector2(sz) * 0.5
		var away := mid - Vector2(_bp.core)
		_shards.append({tex = ImageTexture.create_from_image(im2), at = s.at, size = sz, mark = int(s.mark),
			dir = away.normalized() if away.length() > 0.5 else Vector2.RIGHT.rotated(_rng.randf() * TAU),
			speed = _rng.randf_range(0.6, 1.4), spin = _rng.randf_range(1.5, 5.0) * (1.0 if _rng.randf() < 0.5 else -1.0),
			rot0 = _rng.randi() % 4, release = 99.0, life = 1.0, piece = _piece_of_point(mid), glass = false,
			glint = _rng.randf_range(0.2, 1.0), glint2 = -1.0})
	_shard_speed = 1.0
	_plan_boss()
	_events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.t) < float(b.t))
	_split_at = duration


## A crack's light one pixel wide: the crack itself at full, a dithered pixel
## either side. Same canvas as `_glow_image`, so it draws in the same place.
func _thin_glow(crack: PackedVector2Array, sz: Vector2i) -> Image:
	var w := sz.x + GLOW_PAD * 2
	var h := sz.y + GLOW_PAD * 2
	var im := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var core := {}
	for p in crack:
		core[Vector2i(int(p.x) + GLOW_PAD, int(p.y) + GLOW_PAD)] = true
	for q in core:
		var v: Vector2i = q
		im.set_pixel(v.x, v.y, Color(1, 1, 1, 1))
	for q2 in core:
		var v2: Vector2i = q2
		for o in [Vector2i(1, 0), Vector2i(-1, 0)]:
			var n: Vector2i = v2 + o
			if core.has(n) or ((n.x + n.y) & 1) == 1:
				continue
			im.set_pixel(n.x, n.y, Color(0.4, 0.4, 0.4, 1))
	return im


func _piece_of_point(p: Vector2) -> int:
	var best := 1e9
	var bi := -1
	for i in _majors.size():
		var d := (_majors[i].mid as Vector2).distance_to(p)
		if d < best:
			best = d
			bi = i
	return bi


## Keyframes: [t, value]; positions ease between keys, then round.
static func _keyed(keys: Array, t: float) -> Vector2:
	if keys.is_empty():
		return Vector2.ZERO
	if t <= float(keys[0][0]):
		return keys[0][1]
	for i in keys.size() - 1:
		var a: Array = keys[i]
		var b: Array = keys[i + 1]
		if t < float(b[0]):
			var f := clampf((t - float(a[0])) / maxf(0.001, float(b[0]) - float(a[0])), 0.0, 1.0)
			f = f * f * (3.0 - 2.0 * f)
			return (a[1] as Vector2).lerp(b[1] as Vector2, f)
	return keys.back()[1]


## Held keys: the latest key at or before t.
static func _held(keys: Array, t: float) -> Array:
	var cur: Array = []
	for k in keys:
		if float(k[0]) <= t:
			cur = k
		else:
			break
	return cur


func _boss_pos(m: Dictionary) -> Vector2:
	return (_origin + Vector2(m.at) + _keyed(m.keys, t)).round()


func _boss_stage(m: Dictionary) -> int:
	var n: int = (m.stages as Array).size()
	if done:
		return n - 1
	var i := 0
	for st in m.stage_t:
		if t >= float(st):
			i += 1
	return mini(i, n - 1)


## The piece a canvas point rides with, as an offset now.
func _ride(mi: int) -> Vector2:
	if mi < 0 or mi >= _majors.size():
		return Vector2.ZERO
	return _keyed(_majors[mi].keys, t).round()


func _blight(p: Vector2, keys: Array, col: Color) -> void:
	_blights.append({p = p, m = _piece_of_point(p), keys = keys, col = col})


func _beam(p: Vector2, dir: Vector2, keys: Array, unstable: bool = false) -> void:
	_bbeams.append({p = p, m = _piece_of_point(p), dir = dir.normalized(), keys = keys, unstable = unstable,
		id = _bbeams.size()})


## How unstable the beams are now: a little from the first crack, building with
## the swell, wild right up to the implosion (Jon: "can we have the light beams
## act more like unstable...?").
func _unstable_u() -> float:
	if not _bp.has("unst_t1"):
		return 0.3
	return 0.3 + 0.7 * clampf((t - float(_bp.unst_t0)) / maxf(0.1, float(_bp.unst_t1) - float(_bp.unst_t0)), 0.0, 1.0)


## A beam's length and light now, from its keys.
func _beam_state(b: Dictionary) -> Vector2:
	var keys: Array = b.keys
	var len := 0.0
	var lvl := 0.0
	if keys.is_empty() or t < float(keys[0][0]):
		return Vector2.ZERO
	for i in keys.size():
		if float(keys[i][0]) <= t:
			lvl = float(keys[i][2])
			if i + 1 < keys.size() and t < float(keys[i + 1][0]):
				var f := (t - float(keys[i][0])) / maxf(0.001, float(keys[i + 1][0]) - float(keys[i][0]))
				len = lerpf(float(keys[i][1]), float(keys[i + 1][1]), f)
			else:
				len = float(keys[i][1])
	return Vector2(len, lvl)


func _hook(at: float, kind: StringName, s: float, len: float) -> void:
	_ev(at, kind, s, len)


func _emit(t0: float, t1: float, rate: float, kind: int, pts: PackedVector2Array, opts: Dictionary) -> void:
	var e := {t0 = t0, t1 = t1, rate = rate, kind = kind, pts = pts, mode = &"out", dir = Vector2.ZERO,
		spread = 0.6, v0 = 10.0, v1 = 40.0, l0 = 0.5, l1 = 1.0, col = Color.WHITE, big = 0.3, decay = true}
	e.merge(opts, true)
	_bemit.append(e)


func _hull_edge_points(step: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for m in _majors:
		var im: Image = (m.images as Array)[0]
		for y in range(0, im.get_height(), step):
			for x in range(0, im.get_width(), step):
				if im.get_pixel(x, y).a > 0.0 and (x == 0 or y == 0 or x == im.get_width() - 1 or y == im.get_height() - 1
						or im.get_pixel(x - 1, y).a <= 0.0 or im.get_pixel(x + 1, y).a <= 0.0
						or im.get_pixel(x, y - 1).a <= 0.0 or im.get_pixel(x, y + 1).a <= 0.0):
					out.append(Vector2(m.at) + Vector2(x, y))
	return out


func _crack_points(m: Dictionary) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in (m.crack as PackedVector2Array):
		out.append(Vector2(m.at) + p)
	return out


# ---------------------------------------------------------------- the six scripts

func _plan_boss() -> void:
	var core: Vector2 = _bp.core
	var cs := _origin + core
	var order: Array = range(_majors.size())
	order.sort_custom(func(a: int, b: int) -> bool: return (_majors[a].mid as Vector2).x > (_majors[b].mid as Vector2).x)
	match style:
		Style.CUST_CASCADE, Style.CUST_COLLAPSE, Style.CUST_SPLIT:
			_plan_c1(order, core, cs)
		Style.CUST_UNMAKING:
			_ev(0.0, &"groan", 0.5, 2.8)
			_hook(0.0, &"duck", 0.5, 7.5)
			for oi2 in order.size():
				var m2: Dictionary = _majors[order[oi2]]
				m2.glow_col = 1
				m2.glow_keys = [[0.3, 0.25, 0.0], [0.6, 0.5, 0.0], [3.0, 0.25, 0.0], [3.4, 0.0, 0.0]]
				m2.keys = [[0.0, Vector2.ZERO], [0.6, Vector2.ZERO], [3.0, Vector2(m2.own)], [LIFE[style], Vector2(m2.own)]]
			# the lights go out one by one; a piece goes dark with its last light
			var lt := 0.8
			var last_off := {}
			for L3 in _bp.lights:
				var lp2: Vector2 = L3.p
				var to := lt + _rng.randf_range(0.0, 0.1)
				_blight(lp2, [[0.0, 0.7, 3], [to, 1.0, 5], [to + 0.07, 0.45, 3], [to + 0.14, 0.0, 0]], HEAT_RAMP[1])
				var pi := _piece_of_point(lp2)
				last_off[pi] = maxf(float(last_off.get(pi, 0.0)), to + 0.07)
				_ev(to, &"light_out", 0.2)
				lt += 2.4 / float(maxi(1, _bp.lights.size()))
			for pi2 in _majors.size():
				_majors[pi2].stage_t = [float(last_off.get(pi2, 3.2))]
			# each facet shatters in turn, slowly, glass glinting
			for oi3 in order.size():
				var mi: int = order[oi3]
				var ts := 3.2 + 0.42 * oi3
				_ev(ts, &"shatter", 0.45 + 0.05 * oi3)
				_hook(ts, &"shake", 1.0, 0.15)
				for s2 in _shards:
					var lab_of: int = int(s2.mark) - 10 if int(s2.mark) >= 10 else -1
					if lab_of == int(_majors[mi].lab) or (int(s2.mark) < 10 and int(s2.piece) == mi):
						s2.release = ts + _rng.randf_range(0.0, 0.12)
						s2.speed = _rng.randf_range(12.0, 30.0)
						s2.life = minf(_rng.randf_range(1.3, 1.9), LIFE[style] - 0.15 - float(s2.release))
						s2.glass = true
						s2.spin = _rng.randf_range(1.2, 2.5) * (1.0 if _rng.randf() < 0.5 else -1.0)
			_hook(3.2, &"slowmo", 0.6, 3.6)
			_hook(3.2 + 0.42 * (order.size() - 1), &"stinger", 0.7, 0.0)
			_ev(6.6, &"settle", 0.2, 1.2)
		Style.CUST_SUPERNOVA:
			_ev(0.0, &"whine", 0.4, 2.6)
			_hook(1.0, &"duck", 0.8, 4.0)
			_hook(1.6, &"shake", 1.0, 0.6)
			_hook(2.2, &"shake", 2.0, 0.5)
			_bmaps.append({stages = _nova_maps(), keys = [[0.0, 0, 0.6], [0.35, 1, 0.7], [0.7, 2, 0.75], [1.05, 3, 0.8],
				[1.4, 4, 0.85], [1.75, 5, 0.9], [2.1, 6, 1.0], [2.65, -1, 0.0]], col = Color.WHITE, add = true})
			_blight(core, [[0.0, 0.6, 4], [0.7, 0.8, 7], [1.4, 1.0, 12], [2.1, 1.0, 20], [2.65, 0.0, 0]], HEAT_RAMP[0])
			for m3 in _majors:
				m3.stage_t = [2.66]
			_ev(2.6, &"nova", 1.0, 0.0, cs, {fx = &"nova"})
			_hook(2.6, &"flash", 1.0, 0.45)
			_hook(2.6, &"slowmo", 0.3, 0.6)
			_hook(2.6, &"shake", 9.0, 1.4)
			_hook(2.6, &"stinger", 1.0, 0.0)
			_ev(2.9, &"ring", 0.5, 1.2, cs, {fx = &"dark"})
			_bmaps.append({stages = [_ember_map()], keys = [[2.65, 0, 1.0], [3.5, 0, 0.75], [4.5, 0, 0.5], [5.5, 0, 0.25], [6.5, -1, 0.0]],
				col = HEAT_RAMP[2], add = true})
			_emit(3.0, 6.6, 40.0, 9, _hull_edge_points(3), {v0 = 5.0, v1 = 14.0, l0 = 1.0, l1 = 1.8})
			_ev(3.0, &"smoulder", 0.3, 4.0)
			for tc2 in [3.4, 4.1, 4.9, 5.8]:
				_ev(tc2, &"crackle", 0.15)
		Style.HELL_CHAIN:
			var alarm_pts: Array = []
			for L4 in _bp.lights:
				alarm_pts.append(L4.p)
				if alarm_pts.size() >= 6:
					break
			if alarm_pts.size() < 4:
				for f in [0.2, 0.45, 0.7]:
					alarm_pts.append(Vector2(_bp.box.position) + Vector2(float(_bp.bw) * f, 2.0))
			for ap in alarm_pts:
				var keys: Array = [[0.0, 0.0, 0]]
				var tt := 0.0
				while tt < 2.8:
					var period := 0.33 if tt < 1.6 else 0.2
					keys.append([tt, 1.0, 4])
					keys.append([tt + period * 0.4, 0.0, 0])
					tt += period
				keys.append([2.8, 0.0, 0])
				_blight(ap, keys, ALARM)
			_ev(0.0, &"alarm", 0.6, 2.8)
			_hook(0.0, &"duck", 0.5, 6.5)
			var bt := [1.2, 1.55, 1.85, 2.15, 2.4, 2.62]
			for i in bt.size():
				var bp: Vector2 = _bp.blasts[i]
				_ev(bt[i], &"blast", 0.4 + 0.08 * i, 0.0, _origin + bp, {fx = &"pop", mark = 2 + i})
				_hook(bt[i], &"shake", 2.0, 0.2)
				for s3 in _shards:
					if int(s3.mark) == 2 + i:
						s3.release = bt[i] + 0.02
						s3.life = _rng.randf_range(0.7, 1.0)
						s3.speed = _rng.randf_range(80.0, 160.0)
						var d3 := (Vector2(s3.at) + Vector2(s3.size) * 0.5 - bp)
						s3.dir = d3.normalized() if d3.length() > 0.3 else s3.dir
			for m4 in _majors:
				var st4: Array = []
				for i2 in bt.size():
					st4.append(bt[i2] + 0.03)
				st4.append(4.62)
				m4.stage_t = st4
				m4.keys = [[0.0, Vector2.ZERO], [4.6, Vector2.ZERO], [5.4, Vector2(m4.own)], [LIFE[style], Vector2(m4.own)]]
				m4.glow_keys = [[4.6, 1.0, 1.0], [5.2, 1.0, 0.7], [6.0, 0.6, 0.4], [6.8, 0.25, 0.1], [7.2, 0.0, 0.0]]
			# the holds burst and the stolen cargo spills, glowing
			_ev(3.0, &"rupture", 0.7, 0.0, _origin + (_bp.holds[0] as Vector2), {fx = &"hold"})
			_ev(3.2, &"rupture", 0.6, 0.0, _origin + (_bp.holds[1] as Vector2), {fx = &"hold"})
			_ev(3.0, &"spill", 0.5, 1.6)
			for hi in 2:
				var hp: Vector2 = _bp.holds[hi]
				var out := (hp - Vector2(_bp.r.position) - Vector2(float(_bp.cx), float(_bp.cy))).normalized()
				_emit(3.0 + 0.2 * hi, 4.6, 150.0, 8, PackedVector2Array([hp]), {mode = &"dir", dir = out, spread = 0.7,
					v0 = 20.0, v1 = 70.0, l0 = 0.9, l1 = 1.7, big = 0.45})
			# the main reactor
			_ev(4.6, &"reactor", 1.0, 0.0, _origin + (_bp.reactor as Vector2), {fx = &"reactor"})
			_hook(4.6, &"flash", 0.7, 0.3)
			_hook(4.6, &"slowmo", 0.4, 0.5)
			_hook(4.6, &"shake", 7.0, 1.0)
			_hook(4.6, &"stinger", 1.0, 0.0)
			for s4 in _shards:
				if int(s4.mark) == 1:
					s4.release = 4.6 + _rng.randf_range(0.0, 0.05)
					s4.life = _rng.randf_range(1.0, 1.6)
					s4.speed = _rng.randf_range(90.0, 200.0)
			_emit(4.6, 6.6, 60.0, 1, PackedVector2Array(), {mode = &"crack"})
			_ev(4.7, &"debris", 0.5, 2.0)
			_ev(5.5, &"cool", 0.2, 1.8)
		Style.HELL_BURNOUT:
			var emb: Vector2 = _bp.core
			var bowmost := 1e9
			for L5 in _bp.lights:
				if (L5.p as Vector2).x < bowmost:
					bowmost = (L5.p as Vector2).x
					emb = L5.p
			_bp.emblem = emb
			_ev(0.0, &"ignite", 0.5, 0.0, _origin + emb, {fx = &"ember_pop"})
			_ev(0.0, &"roar", 0.5, 5.4)
			_hook(0.0, &"duck", 0.5, 7.5)
			_blight(emb, [[0.0, 0.5, 4], [0.6, 0.7, 6], [1.2, 0.85, 8], [1.8, 1.0, 11], [5.0, 1.0, 11], [5.2, 0.0, 0]], Color("#ff4a1e"))
			_bmaps.append({stages = _fire_maps(emb), keys = [[0.0, 0, 0.7], [0.4, 1, 0.8], [0.8, 2, 0.85], [1.2, 3, 0.9],
				[1.6, 4, 0.95], [2.0, 5, 1.0], [2.4, 6, 1.0], [5.0, 6, 0.6], [5.2, -1, 0.0]], col = HEAT_RAMP[2], add = true})
			_emit(0.2, 5.2, 90.0, 1, PackedVector2Array(), {mode = &"fire"})
			var wt := [2.6, 3.0, 3.35, 3.9, 4.3]
			for i3 in wt.size():
				var xp: float = float(_bp.box.position.x) + float(_bp.bw) * _rng.randf_range(0.2, 0.9)
				var yp: float = float(_bp.box.position.y) + float(_bp.bh) * _rng.randf_range(0.3, 0.7)
				_ev(wt[i3], &"blast", 0.5, 0.0, _origin + Vector2(xp, yp), {fx = &"pop"})
				_hook(wt[i3], &"shake", 2.5, 0.25)
			for m5 in _majors:
				var j5: int = m5.lab
				var lst := Vector2(0, (2 - j5) * 2)
				m5.keys = [[0.0, Vector2.ZERO], [3.0, Vector2.ZERO], [5.0, lst], [5.2, lst], [7.0, Vector2(m5.own)], [LIFE[style], Vector2(m5.own)]]
				m5.stage_t = [2.0, 4.5]
				m5.glow_keys = [[5.2, 1.0, 0.9], [5.8, 0.9, 0.6], [6.5, 0.6, 0.35], [7.2, 0.3, 0.1], [7.6, 0.0, 0.0]]
				# trailing fire from each piece's broken edges, against its drift
				_emit(5.2, 7.4, 45.0, 1, PackedVector2Array(), {mode = &"trail", piece = _majors.find(m5)})
			_ev(3.0, &"list", 0.4, 2.0)
			_ev(5.2, &"break", 0.8, 0.0, _centre, {fx = &"break"})
			_hook(5.2, &"shake", 4.0, 0.6)
			_hook(5.2, &"stinger", 0.8, 0.0)
			for s5 in _shards:
				s5.release = 5.2 + _rng.randf_range(0.0, 0.06)
				s5.life = _rng.randf_range(0.9, 1.4)
				s5.speed = _rng.randf_range(50.0, 120.0)
			_ev(5.3, &"debris", 0.4, 2.0)
		Style.HELL_UNCOIL:
			_plan_h3()
	# every shard released lives out before the end
	for s7 in _shards:
		if float(s7.release) < 90.0:
			s7.life = minf(float(s7.life), LIFE[style] - 0.1 - float(s7.release))


## SUPERNOVA: the core's light through the glass, a step further each map.
func _nova_maps() -> Array:
	var out: Array = []
	var r: Rect2i = _bp.r
	var H := {}
	var core: Vector2 = _bp.core
	var maxd := 1.0
	var pts: Array = []
	for m in _majors:
		var im: Image = (m.images as Array)[0]
		for y in im.get_height():
			for x in im.get_width():
				if im.get_pixel(x, y).a > 0.0:
					var p := Vector2(m.at) + Vector2(x, y)
					pts.append(p)
					maxd = maxf(maxd, p.distance_to(core))
	for st in 7:
		var reach := maxd * (0.15 + 0.85 * float(st) / 6.0)
		var im2 := Image.create(r.size.x, r.size.y, false, Image.FORMAT_RGBA8)
		for p2 in pts:
			var d := (p2 as Vector2).distance_to(core)
			var lp := Vector2i(p2) - r.position
			var odd := ((lp.x + lp.y) & 1) == 0
			var lv := 0.0
			if d < reach * 0.4:
				lv = 1.0
			elif d < reach * 0.7:
				lv = 0.7
			elif d < reach:
				lv = 0.45 if odd or st == 6 else 0.3
			elif d < reach * 1.15 and odd:
				lv = 0.2
			if st == 6:
				lv = maxf(lv, 0.55)
			if lv > 0.0:
				var c: Color = HEAT_RAMP[0].lerp(HEAT_RAMP[2], clampf(d / maxd, 0.0, 1.0) * (1.0 - float(st) / 7.0))
				im2.set_pixel(lp.x, lp.y, Color(c.r * lv, c.g * lv, c.b * lv, 1.0))
		out.append(ImageTexture.create_from_image(im2))
	return out


## SUPERNOVA's embers: a scatter of hull pixels still glowing in the char.
func _ember_map() -> ImageTexture:
	var r: Rect2i = _bp.r
	var im2 := Image.create(r.size.x, r.size.y, false, Image.FORMAT_RGBA8)
	for m in _majors:
		var im: Image = (m.images as Array)[0]
		for y in im.get_height():
			for x in im.get_width():
				if im.get_pixel(x, y).a > 0.0 and _rng.randf() < 0.07:
					var lp := Vector2i(m.at) - r.position + Vector2i(x, y)
					var lv := 0.9 if _rng.randf() < 0.3 else 0.5
					im2.set_pixel(lp.x, lp.y, Color(lv, lv, lv, 1.0))
	return ImageTexture.create_from_image(im2)


## BURN-OUT: fire across the hull from the emblem, edges brightest.
func _fire_maps(from: Vector2) -> Array:
	var out: Array = []
	var r: Rect2i = _bp.r
	var maxd := 1.0
	var pts: Array = []
	var edges := {}
	for m in _majors:
		var im: Image = (m.images as Array)[0]
		for y in im.get_height():
			for x in im.get_width():
				if im.get_pixel(x, y).a <= 0.0:
					continue
				var p := Vector2(m.at) + Vector2(x, y)
				pts.append(p)
				maxd = maxf(maxd, p.distance_to(from))
				if x == 0 or y == 0 or x == im.get_width() - 1 or y == im.get_height() - 1 or im.get_pixel(x - 1, y).a <= 0.0 \
						or im.get_pixel(x + 1, y).a <= 0.0 or im.get_pixel(x, y - 1).a <= 0.0 or im.get_pixel(x, y + 1).a <= 0.0:
					edges[Vector2i(p)] = true
	for st in 7:
		var reach := maxd * (0.12 + 0.88 * float(st) / 6.0)
		var im2 := Image.create(r.size.x, r.size.y, false, Image.FORMAT_RGBA8)
		for p2 in pts:
			var d := (p2 as Vector2).distance_to(from)
			if d > reach:
				continue
			var lp := Vector2i(p2) - r.position
			var odd := ((lp.x + lp.y) & 1) == 0
			var lv := 0.0
			if edges.has(Vector2i(p2)):
				lv = 1.0
			elif d > reach - 6.0:
				lv = 0.6 if odd else 0.4
			else:
				lv = 0.35 if odd else 0.2
			im2.set_pixel(lp.x, lp.y, Color(lv, lv * 0.8, lv * 0.6, 1.0))
		out.append(ImageTexture.create_from_image(im2))
	return out


func _fire_boss(e: Dictionary) -> void:
	var p: Vector2 = e.p
	match e.get("fx", &""):
		&"blast":
			_bspheres.append({p = p, t0 = t, grow = 0.22, hold = 0.12, fade = 0.3, r1 = 62})
			_ring(p, 10.0, 260.0, 1.0, 0.45, 1.0, HEAT_RAMP[1])
			_spray(p, 60, 300.0)
		&"blast_small":
			_bspheres.append({p = p, t0 = t, grow = 0.18, hold = 0.1, fade = 0.3, r1 = 50})
			_ring(p, 8.0, 200.0, 0.8, 0.45, 0.9, HEAT_RAMP[1])
			_spray(p, 40, 260.0)
		&"ring_light":
			# the crushed cluster lets go: a big centred blast and a ring of white
			# light, round, flung outward through the layers
			_bspheres.append({p = p, t0 = t, grow = 0.2, hold = 0.1, fade = 0.3, r1 = 56})
			_ring(p, 6.0, 220.0, 0.9, 0.8, 1.0, GLASS)
			_ring(p, 4.0, 140.0, 0.7, 0.8, 0.7, HEAT_RAMP[0])
			_spray(p, 60, 300.0)
		&"spine_pop":
			_flash(p, 10, 0.8, Color(), 0.2)
			_spray(p, 10, 150.0)
		&"nova":
			_bspheres.append({p = p, t0 = t, grow = 0.35, hold = 0.15, fade = 0.4, r1 = 230})
			_spray(p, 50, 320.0)
		&"dark":
			_bdark.append({p = p, t0 = t, dur = 1.2, r0 = 20.0, r1 = 420.0})
		&"pop":
			_flash(p, 14, 0.9, Color(), 0.22)
			_ring(p, 3.0, 18.0, 0.2, 1.0, 0.6, HEAT_RAMP[1])
			_spray(p, 16, 180.0)
		&"hold":
			_flash(p, 12, 0.7, GOLD[1], 0.25)
			_spray(p, 10, 120.0)
		&"reactor":
			_bspheres.append({p = p, t0 = t, grow = 0.18, hold = 0.1, fade = 0.3, r1 = 46})
			_ring(p, 8.0, 200.0, 0.8, 0.45, 1.0, HEAT_RAMP[1])
			_spray(p, 50, 280.0)
		&"break":
			_flash(p, 22, 0.8)
			_spray(p, 30, 200.0)
		&"gold":
			_flash(p, 26, 1.0, GOLD[0], 0.32)
			_ring(p, 6.0, 140.0, 0.6, 0.5, 0.9, GOLD[1])
			for m in _majors:
				for i in 18:
					var cr: PackedVector2Array = m.crack
					if cr.is_empty():
						break
					var q := _boss_pos(m) + cr[_rng.randi() % cr.size()]
					var dv := (q - _centre).normalized().rotated(_rng.randf_range(-0.5, 0.5))
					_mote(q, dv * _rng.randf_range(30.0, 110.0), _rng.randf_range(0.6, 1.2), 8, _rng.randf() < 0.5, GOLD[0], 0.6)
		&"ember_pop":
			_flash(p, 8, 0.6, Color(), 0.2)
		&"emblem_burst":
			_flash(p, 16, 1.0, Color(), 0.26)
			_ring(p, 3.0, 26.0, 0.3, 1.0, 0.8, HEAT_RAMP[1])
			_spray(p, 26, 220.0)
		&"hold_cargo":
			var hp: Vector2 = _bp.holds[int(e.hold)]
			var out := (hp - Vector2((_bp.r as Rect2i).position) - Vector2(float(_bp.cx), float(_bp.cy))).normalized()
			_flash(p, 14, 0.8, GOLD[1], 0.25)
			_spray(p, 12, 140.0)
			_spill(p, out, 15)
		&"big_burst":
			# light, not a disc: brightest at the core, falling off in nested
			# additive steps, the outer ones faint, so the hull stays seen
			_bspheres.append({p = p, t0 = t, grow = 0.3, hold = 0.15, fade = 0.45, r1 = 170, soft = true})
			_ring(p, 10.0, 360.0, 1.2, 0.45, 1.0, HEAT_RAMP[1])
			_ring(p, 6.0, 200.0, 0.8, 0.8, 0.8, GOLD[1])
			_spray(p, 70, 320.0)


func _tick_boss(delta: float) -> void:
	var tt := t
	_tick_cargo(delta)
	for b in _bbeams:
		if not b.get("unstable", false):
			continue
		var st := _beam_state(b)
		if st.x < 4.0 or st.y <= 0.0:
			continue
		var u := _unstable_u()
		var nb := int(9.0 * u * delta + _rng.randf())
		for i0 in nb:
			var p0 := _origin + (b.p as Vector2) + _ride(int(b.m)) + (b.dir as Vector2) * _rng.randf_range(3.0, st.x)
			var sdir := Vector2((b.dir as Vector2).y, -(b.dir as Vector2).x) * (1.0 if _rng.randf() < 0.5 else -1.0)
			_mote(p0, (sdir + (b.dir as Vector2) * _rng.randf_range(-0.5, 0.5)).normalized() * _rng.randf_range(40.0, 120.0),
				_rng.randf_range(0.1, 0.25), 0, false, Color.WHITE, 4.5)
	for em in _bemit:
		if tt < float(em.t0) or tt >= float(em.t1):
			continue
		var f := (tt - float(em.t0)) / maxf(0.01, float(em.t1) - float(em.t0))
		var rate := float(em.rate) * (snappedf(1.0 - f, 0.25) if em.decay else 1.0)
		var n := int(rate * delta + _rng.randf())
		for i in n:
			var src := Vector2.ZERO
			var v := Vector2.ZERO
			match em.mode:
				&"crack", &"trail":
					var mi := _rng.randi() % _majors.size() if em.mode == &"crack" else int(em.piece)
					var m: Dictionary = _majors[mi]
					var cr: PackedVector2Array = m.crack
					if cr.is_empty():
						continue
					src = _boss_pos(m) + cr[_rng.randi() % cr.size()]
					if em.mode == &"trail":
						var drift := Vector2(m.own).normalized() if Vector2(m.own).length() > 0.1 else Vector2.RIGHT
						v = (-drift).rotated(_rng.randf_range(-0.6, 0.6)) * _rng.randf_range(float(em.v0), float(em.v1))
					else:
						v = (src - _centre).normalized().rotated(_rng.randf_range(-0.6, 0.6)) * _rng.randf_range(float(em.v0), float(em.v1))
				&"fire":
					# from the burning edge: where the fire front has got to
					var reach := float(_bp.bw) * (0.12 + 0.88 * clampf(tt / 2.4, 0.0, 1.0)) * 1.1
					var pts: PackedVector2Array = _bp.get("edge_pts", PackedVector2Array())
					if pts.is_empty():
						pts = _hull_edge_points(2)
						_bp.edge_pts = pts
					var tries := 0
					while tries < 6:
						var p := pts[_rng.randi() % pts.size()]
						if p.distance_to(_bp.emblem) <= reach:
							src = _origin + p + _ride(_piece_of_point(p))
							break
						tries += 1
					if src == Vector2.ZERO:
						continue
					v = (src - _centre).normalized().rotated(_rng.randf_range(-0.4, 0.4)) * _rng.randf_range(10.0, 35.0)
				&"dir":
					var pts2: PackedVector2Array = em.pts
					src = _origin + pts2[_rng.randi() % pts2.size()]
					v = (em.dir as Vector2).rotated(_rng.randf_range(-float(em.spread), float(em.spread))) * _rng.randf_range(float(em.v0), float(em.v1))
				_:
					var pts3: PackedVector2Array = em.pts
					if pts3.is_empty():
						continue
					var pp := pts3[_rng.randi() % pts3.size()]
					src = _origin + pp + _ride(_piece_of_point(pp))
					v = (src - _centre).normalized().rotated(_rng.randf_range(-0.6, 0.6)) * _rng.randf_range(float(em.v0), float(em.v1))
			var life := _rng.randf_range(float(em.l0), float(em.l1))
			if int(em.kind) == 9:
				var room := duration - t - 0.1
				if room > 0.2:
					_smoke.append({p = src, v = v, age = 0.0, life = minf(life, room)})
			else:
				var kind: int = em.kind
				if em.mode == &"fire" or em.mode == &"trail":
					life = _rng.randf_range(0.3, 0.6)
				_mote(src, v, life, kind, _rng.randf() < float(em.big), em.col, 0.5)
	var kept: Array = []
	for sm in _smoke:
		sm.age += delta
		if sm.age < sm.life:
			sm.p += sm.v * delta
			kept.append(sm)
	_smoke = kept


func _boss_glow_col(m: Dictionary, on: float, heat: float) -> Color:
	match int(m.glow_col):
		1:
			return Color(0.3 * on, 0.42 * on, 0.6 * on, 1.0)
		2:
			return _lv(GOLD[1], on)
	return Color(on, on * (0.45 + 0.55 * heat), on * (0.15 + 0.85 * heat * heat), 1.0)


func _paint_boss_body(ci: CanvasItem) -> void:
	var tint := Color.WHITE
	if done:
		tint = WRECK_TINT
	else:
		var k := clampf((t - (duration - 1.2)) / 1.0, 0.0, 1.0)
		tint = Color.WHITE.lerp(WRECK_TINT, snappedf(k, 0.34))
	for m in _majors:
		var rq := _boss_rot(m)
		if rq == 0:
			ci.draw_texture(m.stages[_boss_stage(m)], _boss_pos(m), tint)
		else:
			var tex: Texture2D = m.stages[_boss_stage(m)]
			var sz := Vector2(tex.get_size())
			ci.draw_set_transform(_boss_pos(m) + sz * 0.5, float(rq) * PI * 0.5, Vector2.ONE)
			ci.draw_texture(tex, -sz * 0.5, tint)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_paint_cargo(ci)
	for s in _shards:
		if t < float(s.release):
			var home := _origin + Vector2(s.at) + _ride(int(s.piece))
			ci.draw_texture(s.tex, home.round(), tint)
			continue
		var age := t - float(s.release)
		var life: float = s.life
		if age >= life:
			continue
		var dist := float(s.speed) * (1.0 - exp(-1.2 * age)) / 1.2
		var p := (_origin + Vector2(s.at) + _ride(int(s.piece)) + (s.dir as Vector2) * dist).round()
		var al := 1.0
		if age > life * 0.6:
			var f := (age - life * 0.6) / (life * 0.4)
			al = 0.66 if f < 0.34 else (0.33 if f < 0.67 else 0.15)
		var rot := posmod(int(s.rot0) + int(floor(age * float(s.spin))), 4)
		var sz := Vector2(s.size)
		var c := tint
		c.a = al
		ci.draw_set_transform(p + sz * 0.5, float(rot) * PI * 0.5, Vector2.ONE)
		ci.draw_texture(s.tex, -sz * 0.5, c)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if not done:
		for sm in _smoke:
			var f2: float = sm.age / sm.life
			var a := 0.5 if f2 < 0.3 else (0.35 if f2 < 0.6 else (0.2 if f2 < 0.85 else 0.1))
			var p2: Vector2 = (sm.p as Vector2).round()
			ci.draw_rect(Rect2(p2, Vector2(2, 2) if f2 < 0.5 else Vector2.ONE), Color(0.16, 0.15, 0.15, a))
		for dk in _bdark:
			var age2 := t - float(dk.t0)
			if age2 < 0.0 or age2 > float(dk.dur):
				continue
			var x := age2 / float(dk.dur)
			var rr := float(dk.r0) + (float(dk.r1) - float(dk.r0)) * (1.0 - pow(1.0 - x, 2.0))
			var al2 := 0.7 if x < 0.4 else (0.45 if x < 0.7 else 0.2)
			for band in 8:
				var rb := int(rr) - band
				if rb < 2:
					continue
				var pts := {}
				var n := int(ceil(TAU * rb)) + 8
				for i in n:
					var a2 := TAU * float(i) / float(n)
					pts[Vector2i(roundi(cos(a2) * rb), roundi(sin(a2) * rb * 0.55))] = true
				var ab := al2 * (1.0 - float(band) / 9.0)
				for q in pts:
					if band >= 5 and (((q as Vector2i).x + (q as Vector2i).y) & 1) == 1:
						continue
					ci.draw_rect(Rect2((dk.p as Vector2).round() + Vector2(q as Vector2i), Vector2.ONE), Color(0.0, 0.0, 0.02, ab))


func _paint_boss_light(ci: CanvasItem) -> void:
	for m in _majors:
		var h := _held(m.glow_keys, t)
		if h.is_empty() or float(h[1]) <= 0.0:
			continue
		var rq := _boss_rot(m)
		if rq == 0:
			ci.draw_texture(m.glow, _boss_pos(m) - Vector2(GLOW_PAD, GLOW_PAD), _boss_glow_col(m, float(h[1]), float(h[2])))
		else:
			var gsz := Vector2((m.glow as Texture2D).get_size())
			var isz := Vector2((m.stages[0] as Texture2D).get_size())
			ci.draw_set_transform(_boss_pos(m) + isz * 0.5, float(rq) * PI * 0.5, Vector2.ONE)
			ci.draw_texture(m.glow, -gsz * 0.5, _boss_glow_col(m, float(h[1]), float(h[2])))
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for mp in _bmaps:
		var hk := _held(mp.keys, t)
		if hk.is_empty() or int(hk[1]) < 0 or float(hk[2]) <= 0.0:
			continue
		var tex: ImageTexture = mp.stages[int(hk[1])]
		var c: Color = mp.col
		var lv := float(hk[2])
		ci.draw_texture(tex, _origin + Vector2((_bp.r as Rect2i).position), Color(c.r * lv, c.g * lv, c.b * lv, 1))
	for L in _blights:
		var hk2 := _held(L.keys, t)
		if hk2.is_empty() or float(hk2[1]) <= 0.0 or int(hk2[2]) <= 0:
			continue
		var tex2 := _white(int(hk2[2]))
		var p := _origin + (L.p as Vector2) + _ride(int(L.m))
		ci.draw_texture(tex2, (p - Vector2(tex2.get_size()) * 0.5).round(), _lv(L.col, float(hk2[1])))
	for b in _bbeams:
		var st := _beam_state(b)
		var len := st.x
		var lvl := st.y
		if len < 1.0 or lvl <= 0.0:
			continue
		var p0 := _origin + (b.p as Vector2) + _ride(int(b.m))
		var d: Vector2 = b.dir
		var side := Vector2(roundf(d.y), -roundf(d.x))
		var core_col := Color(1.0, 0.98, 0.94)
		var halo_col := GLASS
		var wide := 1
		var jit := Vector2.ZERO
		var hsh := 0
		var u := 0.0
		if b.get("unstable", false):
			# UNSTABLE: every 1/12 s the beam takes a new state from a hash of
			# itself and the step -- held for the step, so it flickers rather
			# than crawls -- and wilder as the swell builds
			u = _unstable_u()
			var step := int(t * 12.0)
			hsh = posmod(int(b.id) * 7919 + step * 104729 + 13, 1000003)
			var prev := posmod(int(b.id) * 7919 + (step - 1) * 104729 + 13, 1000003)
			if u > 0.25 and hsh % 11 == 0:
				continue   # cut out for a step
			if u > 0.25 and prev % 11 == 0:
				lvl = 1.0   # reignites bright
			var flick: float = [1.0, 0.7, 0.9, 0.5, 0.85][hsh % 5]
			lvl *= lerpf(1.0, flick, u)
			var surge: float = [1.0, 1.18, 0.72, 1.3, 0.86, 1.08][(hsh / 5) % 6]
			len *= lerpf(1.0, surge, u)
			if u > 0.4 and (hsh / 7) % 2 == 0:
				wide = 2
			if u > 0.3 and (hsh / 11) % 4 == 0:
				jit = side * (1.0 if (hsh & 1) == 0 else -1.0)
			var pick := (hsh / 13) % 3
			if u > 0.35 and pick == 1:
				core_col = HEAT_RAMP[0]
				halo_col = HEAT_RAMP[1]
			elif u > 0.2 and pick == 2:
				core_col = GLASS.lerp(Color.WHITE, 0.5)
				halo_col = Color(0.55, 0.75, 1.0)
		var last := Vector2.INF
		var s := 0.0
		while s <= len:
			# anchored: the first pixels never leave the crack
			var q := (p0 + d * s).round() + (jit if s > 3.0 else Vector2.ZERO)
			if q != last:
				# a three-pixel shaft (five when it swells), white at the core,
				# coloured at its sides, a dithered glow beyond, fading along it
				var fall := 1.0 - 0.65 * s / len
				var l2 := lvl * (1.0 if fall > 0.8 else (0.75 if fall > 0.6 else (0.55 if fall > 0.45 else 0.4)))
				ci.draw_rect(Rect2(q, Vector2.ONE), _lv(core_col, l2))
				ci.draw_rect(Rect2(q + side, Vector2.ONE), _lv(halo_col, l2 * 0.75))
				ci.draw_rect(Rect2(q - side, Vector2.ONE), _lv(halo_col, l2 * 0.75))
				if wide >= 2:
					ci.draw_rect(Rect2(q + side * 2.0, Vector2.ONE), _lv(halo_col, l2 * 0.5))
					ci.draw_rect(Rect2(q - side * 2.0, Vector2.ONE), _lv(halo_col, l2 * 0.5))
				if ((int(q.x) + int(q.y)) & 1) == 0:
					var o3 := 3.0 if wide >= 2 else 2.0
					ci.draw_rect(Rect2(q + side * o3, Vector2.ONE), _lv(halo_col, l2 * 0.3))
					ci.draw_rect(Rect2(q - side * o3, Vector2.ONE), _lv(halo_col, l2 * 0.3))
				last = q
			s += 1.0
		# now and then an arc jumps off the beam: a short jagged line of light
		if b.get("unstable", false) and u > 0.4 and hsh % 9 == 4:
			var s0 := len * (0.3 + 0.05 * float((hsh / 3) % 10))
			var a := (p0 + d * s0).round()
			var sg := 1.0 if (hsh & 2) == 0 else -1.0
			for k in 5:
				a += side * sg + d * (1.0 if k % 2 == 0 else -1.0)
				ci.draw_rect(Rect2(a, Vector2.ONE), _lv(core_col, lvl * (0.9 - 0.12 * k)))
	for sp in _bspheres:
		if sp.has("keys"):
			var ks: Array = sp.keys
			if t < float(ks[0][0]) or t >= float(ks.back()[0]):
				continue
			var R2 := 0.0
			var l4 := 0.0
			for i4 in ks.size() - 1:
				if t >= float(ks[i4][0]) and t < float(ks[i4 + 1][0]):
					var f4 := (t - float(ks[i4][0])) / maxf(0.001, float(ks[i4 + 1][0]) - float(ks[i4][0]))
					R2 = lerpf(float(ks[i4][1]), float(ks[i4 + 1][1]), f4)
					l4 = float(ks[i4][2])
			if R2 >= 1.0:
				_draw_sphere(ci, sp.p, int(R2), l4)
			continue
		var a := t - float(sp.t0)
		var g: float = sp.grow
		var hold: float = sp.hold
		var fd: float = sp.fade
		if a < 0.0 or a > g + hold + fd:
			continue
		var R := float(sp.r1) * _ease_out(a / g) if a < g else float(sp.r1) + 4.0 * (a - g) / maxf(0.01, hold + fd)
		var lvl2 := 1.0 if a < g + hold else (0.6 if a < g + hold + fd * 0.33 else (0.35 if a < g + hold + fd * 0.66 else 0.15))
		if sp.get("soft", false):
			_draw_soft_light(ci, sp.p, int(R), lvl2)
		else:
			_draw_sphere(ci, sp.p, int(R), lvl2)
	for dk in _bdark:
		var age2 := t - float(dk.t0)
		if age2 < 0.0 or age2 > float(dk.dur):
			continue
		var x := age2 / float(dk.dur)
		var rr := float(dk.r0) + (float(dk.r1) - float(dk.r0)) * (1.0 - pow(1.0 - x, 2.0))
		_draw_ring(ci, dk.p, int(rr) + 1, 0.55, 0.5 if x < 0.5 else 0.25, Color(0.85, 0.9, 1.0))
	# C1c: the blast running along the spine, white-hot where it has just
	# passed, cooling behind it
	if style == Style.CUST_SPLIT and _bp.has("spine_pts"):
		var cxs: float = (_bp.core as Vector2).x
		var maxd := float(_bp.bw) * 0.5
		for sp2 in (_bp.spine_pts as PackedVector2Array):
			var tr := 4.95 + 0.5 * absf(sp2.x - cxs) / maxd
			var ag := t - tr
			if ag < 0.0 or ag >= 0.8:
				continue
			var lc: Color = HEAT_RAMP[0] if ag < 0.1 else (HEAT_RAMP[1] if ag < 0.25 else (HEAT_RAMP[2] if ag < 0.45 else HEAT_RAMP[3]))
			var lv := 1.0 if ag < 0.1 else (0.8 if ag < 0.25 else (0.55 if ag < 0.45 else 0.3))
			ci.draw_rect(Rect2(_origin + sp2, Vector2.ONE), _lv(lc, lv))
	# glass catching the light as it turns
	# the stolen goods glow
	for c in _bcargo:
		var tg := _white(3)
		ci.draw_texture(tg, ((c.p as Vector2) + Vector2(c.size) * 0.5 - Vector2(tg.get_size()) * 0.5).round(), _lv(c.col, 0.55))
	for sh in _shards:
		if not sh.glass or t < float(sh.release):
			continue
		var age3 := t - float(sh.release)
		var gl: float = sh.glint
		var gl2: float = sh.glint2
		if ((age3 >= gl and age3 < gl + 0.067) or (gl2 > 0.0 and age3 >= gl2 and age3 < gl2 + 0.067)) and age3 < float(sh.life) * 0.8:
			var dist2 := float(sh.speed) * (1.0 - exp(-1.2 * age3)) / 1.2
			var p3 := _origin + Vector2(sh.at) + _ride(int(sh.piece)) + (sh.dir as Vector2) * dist2 + Vector2(sh.size) * 0.5
			ci.draw_texture(sh.tex, (p3 - Vector2(sh.size) * 0.5).round(), Color(0.6, 0.7, 0.8, 1))


# ---------------------------------------------------------------- C1: the cascade, three ways to end

## Jon picked C1, centred, with "some variants of the explosion and how the
## ship falls apart". All three open the same way -- the facets crack one by
## one along the spine, each shooting a beam, while a ball of light swells at
## the true centre -- and end differently:
##   C1a SHATTER OUTWARD  a white blast; the facets fly out and slow into the
##                        wreck; big glass shards tumble out, glinting.
##   C1b COLLAPSE INWARD  the cluster crushed in on its centre, then a ring of
##                        light blows the pieces out in layers, outer first.
##   C1c SPLIT            a blast that runs along the spine from the centre to
##                        both ends; the guardian breaks in half, glass shedding.
func _plan_c1(order: Array, core: Vector2, cs: Vector2) -> void:
	var n := order.size()
	var crush_at := 4.2 if style == Style.CUST_COLLAPSE else 4.4
	var blast_at := 5.0 if style == Style.CUST_COLLAPSE else 4.9
	# 1 the cascade, crack by crack from the small end to the big one
	for oi in n:
		var m: Dictionary = _majors[order[oi]]
		var tc := 0.25 + 0.32 * float(oi) * 8.0 / float(n)
		m.glow_keys = [[tc, 0.5, 1.0], [tc + 0.1, 0.75, 1.0], [crush_at, 1.0, 1.0], [blast_at, 1.0, 1.0],
			[blast_at + 0.5, 1.0, 0.75], [blast_at + 1.0, 0.75, 0.5], [blast_at + 1.5, 0.5, 0.25],
			[blast_at + 2.0, 0.25, 0.0], [7.3, 0.0, 0.0]]
		m.stage_t = [blast_at + 0.02]
		if n > 8 and oi % 2 == 1:
			continue
		_ev(tc, &"crack", 0.35 + 0.05 * oi * 8.0 / float(n))
		_hook(tc, &"shake", 1.0, 0.15)
		var cr := _crack_points(m)
		if cr.is_empty():
			continue
		var cm := Vector2.ZERO
		for p in cr:
			cm += p
		cm /= float(cr.size())
		var up := -1.0 if (oi / (2 if n > 8 else 1)) % 2 == 0 else 1.0
		var L := _rng.randf_range(80.0, 140.0)
		_beam(cm, Vector2(_rng.randf_range(-0.35, 0.35), up), [[tc, 0.0, 1.0], [tc + 0.12, L, 1.0], [crush_at, L, 1.0],
			[crush_at + 0.2, L * 0.4, 0.7], [crush_at + 0.35, 0.0, 0.0]], true)
		_flash(_origin + cm, 10, 0.7, GLASS, 0.2)
		_ev(tc + 0.02, &"beam", 0.3, crush_at - tc)
	for L2 in _bp.lights:
		_blight(L2.p, [[0.0, 0.5, 3], [1.0 + _rng.randf() * 1.5, 0.9, 4], [blast_at, 0.0, 0]], HEAT_RAMP[1])
	_bp.unst_t0 = 3.0
	_bp.unst_t1 = crush_at
	# 2 the centre swells: a ball of light at the true middle
	_bspheres.append({p = cs, keys = [[3.0, 2.0, 0.6], [3.4, 6.0, 0.75], [3.8, 11.0, 0.9], [crush_at, 18.0, 1.0],
		[blast_at - 0.05, 3.0, 1.0], [blast_at, 0.0, 0.0]]})
	_ev(3.0, &"swell", 0.6, crush_at - 3.0)
	_hook(3.0, &"duck", 0.7, 3.5)
	var lifeT: float = LIFE[style]
	match style:
		Style.CUST_CASCADE:
			_ev(4.4, &"implode", 0.8, 0.5)
			_hook(4.4, &"slowmo", 0.35, 0.7)
			for m2 in _majors:
				var d: Vector2 = m2.dir
				m2.keys = [[0.0, Vector2.ZERO], [4.4, Vector2.ZERO], [4.85, -d * 4.0], [4.9, -d * 4.0],
					[5.2, Vector2(m2.own) * 0.75], [6.4, Vector2(m2.own)], [lifeT, Vector2(m2.own)]]
			_ev(4.9, &"blast", 1.0, 0.0, cs, {fx = &"blast"})
			_ev(4.9, &"shatter", 0.8, 1.5)
			for s in _shards:
				s.release = 4.9 + _rng.randf_range(0.0, 0.05)
				s.life = _rng.randf_range(1.8, 2.4)
				s.speed = _rng.randf_range(70.0, 160.0)
				s.spin = _rng.randf_range(1.5, 3.0) * (1.0 if _rng.randf() < 0.5 else -1.0)
				s.glass = true
				s.glint2 = float(s.glint) + _rng.randf_range(0.4, 0.8)
		Style.CUST_COLLAPSE:
			_ev(4.2, &"crush", 0.8, 0.8)
			_hook(4.2, &"shake", 2.0, 0.8)
			_hook(4.6, &"slowmo", 0.35, 0.6)
			for m3 in _majors:
				var d3: Vector2 = m3.dir
				var outer := int(m3.lab) % 2 == 1
				var crush := d3 * (-9.0 if outer else -5.0)
				var go := 5.0 if outer else 5.25
				m3.keys = [[0.0, Vector2.ZERO], [4.2, Vector2.ZERO], [4.85, crush], [go, crush],
					[go + 0.25, Vector2(m3.own) * 0.8], [go + 1.2, Vector2(m3.own)], [lifeT, Vector2(m3.own)]]
			_ev(5.0, &"blast", 1.0, 0.0, cs, {fx = &"ring_light"})
			_ev(5.0, &"layer", 0.8)
			_ev(5.25, &"layer", 0.6)
			for s3 in _shards:
				var dist := (Vector2(s3.at) - core).length()
				var outer2 := dist > 0.3 * float(_bp.bw)
				s3.release = (5.0 if outer2 else 5.25) + _rng.randf_range(0.0, 0.05)
				s3.life = _rng.randf_range(1.3, 1.9)
				s3.speed = _rng.randf_range(70.0, 150.0)
				s3.glass = true
		Style.CUST_SPLIT:
			_ev(4.4, &"implode", 0.8, 0.5)
			_hook(4.4, &"slowmo", 0.35, 0.6)
			for m4 in _majors:
				var d4: Vector2 = m4.dir
				m4.keys = [[0.0, Vector2.ZERO], [4.4, Vector2.ZERO], [4.85, -d4 * 3.0], [5.0, -d4 * 3.0],
					[5.6, Vector2(m4.own) * 0.6], [6.8, Vector2(m4.own)], [lifeT, Vector2(m4.own)]]
			_ev(4.9, &"blast", 1.0, 0.0, cs, {fx = &"blast_small"})
			_ev(4.95, &"run", 0.7, 0.5)
			var maxd := float(_bp.bw) * 0.5
			for k5 in 4:
				var dx := maxd * float(k5 + 1) / 4.5
				for side in [-1.0, 1.0]:
					var tp := 4.95 + 0.5 * dx / maxd
					_ev(tp, &"pop", 0.3, 0.0, cs + Vector2(side * dx, 0.0), {fx = &"spine_pop"})
			_ev(5.5, &"split", 0.9)
			_hook(5.5, &"shake", 3.0, 0.4)
			_ev(5.5, &"shed", 0.4, 1.5)
			for s4 in _shards:
				var mid4 := Vector2(s4.at) + Vector2(s4.size) * 0.5
				if int(s4.mark) == 3:
					s4.release = 4.95 + 0.5 * absf(mid4.x - core.x) / maxd + _rng.randf_range(0.0, 0.04)
					s4.dir = Vector2(_rng.randf_range(-0.4, 0.4), signf(mid4.y - core.y + 0.01)).normalized()
					s4.speed = _rng.randf_range(25.0, 70.0)
				else:
					s4.release = 5.5 + _rng.randf_range(0.0, 0.15)
					s4.speed = _rng.randf_range(40.0, 100.0)
				s4.life = _rng.randf_range(1.2, 1.8)
				s4.glass = true
	_hook(blast_at, &"flash", 1.0, 0.3)
	_hook(blast_at, &"shake", 6.0, 0.9)
	_hook(blast_at, &"stinger", 1.0, 0.0)
	_emit(blast_at, 6.8, 70.0, 1, PackedVector2Array(), {mode = &"crack"})
	_ev(blast_at + 0.1, &"debris", 0.5, 2.0)
	_ev(blast_at + 0.7, &"cool", 0.2, 1.6)


## H3's rib seams, traced off the picture: the luminance smoothed down each
## column (the ribs run near vertical, so this keeps the seams and loses the
## plating's grain), its dips along each row, and the dips linked row to row
## from the middle outward into curves. A curve that does not reach half the
## hull's height there is grain, not a seam. Each curve: `traced` (its x per
## row, -1 where it was not found) and `full` (carried on to every row, so a
## cut runs the whole height).
static func _rib_curves(H: Dictionary) -> Array:
	var w: int = H.w
	var h: int = H.h
	var mask: PackedByteArray = H.mask
	var raw: PackedColorArray = H.raw
	var L := PackedFloat32Array()
	L.resize(w * h)
	for i in w * h:
		if mask[i] == 1:
			L[i] = raw[i].get_luminance()
	var Ls := PackedFloat32Array()
	Ls.resize(w * h)
	for y in h:
		for x in w:
			if mask[y * w + x] == 0:
				continue
			var sum := 0.0
			var cnt := 0
			for yy in range(y - 2, y + 3):
				if yy >= 0 and yy < h and mask[yy * w + x] == 1:
					sum += L[yy * w + x]
					cnt += 1
			Ls[y * w + x] = sum / float(cnt)
	var mins := PackedByteArray()
	mins.resize(w * h)
	for y2 in h:
		for x2 in range(3, w - 3):
			var i2 := y2 * w + x2
			if mask[i2 - 3] == 0 or mask[i2 + 3] == 0:
				continue
			var v := Ls[i2]
			if v < Ls[i2 - 1] and v <= Ls[i2 + 1] and v <= Ls[i2 - 2] and v <= Ls[i2 + 2] \
					and (Ls[i2 - 3] + Ls[i2 + 3]) * 0.5 - v > 0.03:
				mins[i2] = 1
	var cy := int(H.cy)
	var curves: Array = []
	for x0 in w:
		if mins[cy * w + x0] == 0:
			continue
		var tr := PackedInt32Array()
		tr.resize(h)
		tr.fill(-1)
		tr[cy] = x0
		var count := 1
		for d in [-1, 1]:
			var x := x0
			var y3 := cy
			var miss := 0
			while true:
				y3 += int(d)
				if y3 < 0 or y3 >= h:
					break
				var best := -1
				for xx in range(x - 2, x + 3):
					if xx >= 0 and xx < w and mins[y3 * w + xx] == 1:
						if best < 0 or absi(xx - x) < absi(best - x):
							best = xx
				if best >= 0:
					x = best
					tr[y3] = x
					count += 1
					miss = 0
				else:
					miss += 1
					if miss > 2 or mask[y3 * w + x] == 0:
						break
					tr[y3] = x
					count += 1
		var colh := 0
		for y4 in h:
			if mask[y4 * w + x0] == 1:
				colh += 1
		if count >= colh / 2:
			curves.append({traced = tr, x = x0})
	curves.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.x) < int(b.x))
	var kept: Array = []
	for c in curves:
		if not kept.is_empty() and int(c.x) - int(kept.back().x) < 3:
			continue
		kept.append(c)
	for c2 in kept:
		var tr2: PackedInt32Array = c2.traced
		var full := tr2.duplicate()
		var first := -1
		var last := -1
		for y5 in h:
			if tr2[y5] >= 0:
				if first < 0:
					first = y5
				last = y5
		for y6 in h:
			if y6 < first:
				full[y6] = tr2[first]
			elif y6 > last:
				full[y6] = tr2[last]
			elif full[y6] < 0:
				full[y6] = full[y6 - 1]
		c2.full = full
	return kept


# ---------------------------------------------------------------- H3, bigger (Jon: "more")

var _bcargo: Array = []       ## stolen goods spilling: {tex, p, v, spin, rot0, t0, pop, life, size, col}
var _cargo_tex: Array = []


## A piece's quarter turns now: none until the burst, tumbling as it flies,
## landing on its final turn (none or a half turn) for good.
func _boss_rot(m: Dictionary) -> int:
	var total: int = int(m.get("rot_total", 0))
	if total == 0 or t < 7.0:
		return 0
	if done or t >= 8.6:
		return int(m.rot_final)
	var f := clampf((t - 7.0) / 1.6, 0.0, 1.0)
	f = 1.0 - pow(1.0 - f, 2.0)
	return roundi(f * float(total)) % 4


## The Hellbender's stolen goods: amber crates and glowing canisters, a few
## pixels each, outlined so they read against anything.
func _make_cargo() -> void:
	var crate := Image.create(5, 4, false, Image.FORMAT_RGBA8)
	for y in 4:
		for x in 5:
			var c := Color(0.92, 0.66, 0.24)
			if x == 0 or y == 0 or x == 4 or y == 3:
				c = Color(0.25, 0.14, 0.06)
			elif y == 1:
				c = Color(1.0, 0.85, 0.45)
			crate.set_pixel(x, y, c)
	crate.set_pixel(2, 2, Color(1.0, 0.95, 0.7))
	var can := Image.create(3, 6, false, Image.FORMAT_RGBA8)
	for y2 in 6:
		for x2 in 3:
			var c2 := Color(0.72, 0.96, 1.0)
			if y2 == 0 or y2 == 5:
				c2 = Color(0.2, 0.3, 0.36)
			elif x2 == 0:
				c2 = Color(0.95, 1.0, 1.0)
			can.set_pixel(x2, y2, c2)
	var box := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	for y3 in 4:
		for x3 in 4:
			var c3 := Color(1.0, 0.9, 0.5)
			if x3 == 0 or y3 == 0 or x3 == 3 or y3 == 3:
				c3 = Color(0.45, 0.28, 0.08)
			box.set_pixel(x3, y3, c3)
	_cargo_tex = [ImageTexture.create_from_image(crate), ImageTexture.create_from_image(can), ImageTexture.create_from_image(box)]


func _spill(at: Vector2, out: Vector2, count: int) -> void:
	if _cargo_tex.is_empty():
		_make_cargo()
	for i in count:
		var k := _rng.randi() % 3
		var tex: ImageTexture = _cargo_tex[k]
		var v := out.rotated(_rng.randf_range(-0.8, 0.8)) * _rng.randf_range(25.0, 75.0)
		var pops := _rng.randf() < 0.4
		_bcargo.append({tex = tex, p = at, v = v, spin = _rng.randf_range(3.0, 7.0) * (1.0 if _rng.randf() < 0.5 else -1.0),
			rot0 = _rng.randi() % 4, t0 = t, pop = t + _rng.randf_range(0.3, 1.1) if pops else 99.0,
			life = minf(_rng.randf_range(1.5, 2.6), duration - 0.2 - t), size = Vector2(tex.get_size()),
			col = GOLD[1] if k != 1 else Color(0.7, 0.95, 1.0)})


func _tick_cargo(delta: float) -> void:
	var kept: Array = []
	for c in _bcargo:
		var age := t - float(c.t0)
		if t >= float(c.pop):
			# it bursts: a flash of the stolen light and its sparks
			_flash(c.p, 8, 0.8, c.col, 0.18)
			for j in 8:
				_mote(c.p, Vector2.RIGHT.rotated(_rng.randf() * TAU) * _rng.randf_range(30.0, 90.0), _rng.randf_range(0.3, 0.6),
					8, _rng.randf() < 0.3, GOLD[0], 1.5)
			if _rate_limited(&"pop", 0.08):
				moment.emit(&"pop", 0.25, 0.0)
			continue
		if age >= float(c.life):
			continue
		c.p += (c.v as Vector2) * delta
		c.v *= exp(-0.7 * delta)
		kept.append(c)
	_bcargo = kept


func _paint_cargo(ci: CanvasItem) -> void:
	if done:
		return
	for c in _bcargo:
		var age := t - float(c.t0)
		var life: float = c.life
		var al := 1.0 if age < life * 0.7 else (0.6 if age < life * 0.85 else 0.3)
		var rot := posmod(int(c.rot0) + int(floor(age * float(c.spin))), 4)
		var sz: Vector2 = c.size
		ci.draw_set_transform((c.p as Vector2).round() + sz * 0.5, float(rot) * PI * 0.5, Vector2.ONE)
		ci.draw_texture(c.tex, -sz * 0.5, Color(1, 1, 1, al))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _plan_h3() -> void:
	var lifeT: float = LIFE[style]
	var emb: Vector2 = _bp.get("emblem", _bp.core)
	var es := _origin + emb
	# 1 the hum, and gold climbing the ribs' seams from the hold outward
	var mid_i := (_majors.size() - 1) / 2
	var step6 := 2.4 / maxf(1.0, float(mid_i))
	for m6 in _majors:
		var j6: int = m6.lab
		var ton := 0.3 + absf(float(j6 - mid_i)) * step6
		m6.glow_col = 2
		m6.glow_keys = [[ton, 0.5, 0.0], [ton + 0.1, 0.75, 0.0], [5.6, 1.0, 0.0], [7.0, 1.0, 0.0], [7.6, 0.75, 0.0],
			[8.2, 0.5, 0.0], [8.8, 0.25, 0.0], [9.2, 0.0, 0.0]]
		m6.keys = [[0.0, Vector2.ZERO], [7.0, Vector2.ZERO], [7.5, Vector2(m6.own) * 0.7], [8.6, Vector2(m6.own)], [lifeT, Vector2(m6.own)]]
		m6.stage_t = [7.05]
		_ev(ton, &"charge", 0.2 + 0.05 * absf(float(j6 - mid_i)))
		# each section trails gold and sparks as it flies
		_emit(7.0, 8.4, 26.0, 8, PackedVector2Array(), {mode = &"trail", piece = _majors.find(m6), v0 = 10.0, v1 = 30.0})
		_emit(7.0, 8.0, 16.0, 0, PackedVector2Array(), {mode = &"trail", piece = _majors.find(m6), v0 = 40.0, v1 = 110.0})
	_ev(0.0, &"hum", 0.3, 3.0)
	_hook(0.0, &"duck", 0.5, 9.0)
	# 2 the salamander device heats red, then white, and burns
	_blight(emb, [[1.5, 0.7, 6], [2.0, 0.8, 8], [2.6, 0.0, 0]], Color(1.0, 0.2, 0.12))
	_blight(emb, [[2.6, 0.9, 10], [3.7, 0.0, 0]], HEAT_RAMP[2])
	_blight(emb, [[3.7, 1.0, 12], [4.6, 1.0, 16], [5.6, 0.0, 0]], HEAT_RAMP[0])
	_bspheres.append({p = es, keys = [[3.7, 2.0, 0.8], [4.6, 4.0, 1.0], [5.55, 5.0, 1.0], [5.6, 0.0, 0.0]]})
	_ev(1.5, &"emblem_heat", 0.4, 4.1)
	_ev(2.0, &"flames", 0.4, 3.6)
	_emit(2.0, 5.6, 140.0, 1, PackedVector2Array([emb]), {v0 = 12.0, v1 = 45.0, l0 = 0.3, l1 = 0.6, decay = false, big = 0.5})
	_ev(5.6, &"emblem_burst", 0.7, 0.0, es, {fx = &"emblem_burst"})
	_hook(5.6, &"shake", 3.0, 0.3)
	# 3 alarms and shakes building
	var alarm_pts: Array = []
	for L4 in _bp.lights:
		if (L4.p as Vector2).distance_to(emb) > 6.0:
			alarm_pts.append(L4.p)
		if alarm_pts.size() >= 6:
			break
	for ap in alarm_pts:
		var keys: Array = [[0.0, 0.0, 0]]
		var tt := 3.0
		while tt < 6.4:
			var period := 0.3 if tt < 5.0 else 0.18
			keys.append([tt, 1.0, 4])
			keys.append([tt + period * 0.4, 0.0, 0])
			tt += period
		keys.append([6.4, 0.0, 0])
		_blight(ap, keys, ALARM)
	_ev(3.0, &"alarm", 0.6, 3.4)
	_hook(3.5, &"shake", 1.0, 0.3)
	_hook(4.3, &"shake", 2.0, 0.3)
	_hook(5.0, &"shake", 3.0, 0.4)
	_hook(5.8, &"shake", 4.0, 0.4)
	# 4 the holds burst, spilling the stolen goods
	for hi in 2:
		var hp: Vector2 = _bp.holds[hi]
		_ev(6.0 + 0.15 * hi, &"rupture", 0.7, 0.0, _origin + hp, {fx = &"hold_cargo", hold = hi})
		var out := (hp - Vector2((_bp.r as Rect2i).position) - Vector2(float(_bp.cx), float(_bp.cy))).normalized()
		_emit(6.0 + 0.15 * hi, 7.0, 130.0, 8, PackedVector2Array([hp]), {mode = &"dir", dir = out, spread = 0.7,
			v0 = 20.0, v1 = 70.0, l0 = 0.8, l1 = 1.5, big = 0.45})
	_ev(6.0, &"spill", 0.5, 1.5)
	# 5 the light breaks out
	_ev(7.0, &"burst", 1.0, 0.0, _centre, {fx = &"big_burst"})
	_hook(7.0, &"flash", 1.0, 0.45)
	_hook(7.0, &"shake", 9.0, 1.5)
	_hook(7.0, &"slowmo", 0.3, 0.7)
	_hook(7.0, &"stinger", 1.0, 0.0)
	# 6 the rib sections fly apart, tumbling, and settle
	_ev(7.05, &"scatter", 0.6, 1.6)
	for s6 in _shards:
		s6.release = 7.0 + _rng.randf_range(0.0, 0.05)
		s6.life = _rng.randf_range(1.0, 1.6)
		s6.speed = _rng.randf_range(60.0, 160.0)
	_ev(8.6, &"cool", 0.2, 0.9)



## A big light that does not hide what is under it: nested discs added together,
## the core small and white, the outer rings faint, the outermost dithered.
func _draw_soft_light(ci: CanvasItem, c: Vector2, R: int, lvl: float) -> void:
	var cp := c.round()
	var rings := [[1.0, 0.07, true], [0.75, 0.09, false], [0.5, 0.14, false], [0.3, 0.22, false], [0.14, 0.45, false]]
	for rg in rings:
		var rr := int(float(R) * float(rg[0]))
		if rr < 1:
			continue
		var col := _lv(HEAT_RAMP[1].lerp(Color.WHITE, 1.0 - float(rg[0])), lvl * float(rg[1]))
		for dy in range(-rr, rr + 1):
			var half := int(floor(sqrt(float(rr * rr - dy * dy))))
			if rg[2]:
				# the outermost: whole rows inside 0.85, dithered pixels beyond
				var inner := int(floor(sqrt(maxf(0.0, float(rr * rr) * 0.72 - float(dy * dy)))))
				ci.draw_rect(Rect2(cp + Vector2(-inner, dy), Vector2(inner * 2 + 1, 1)), col)
				for x in range(inner + 1, half + 1):
					if ((x + dy) & 1) == 0:
						ci.draw_rect(Rect2(cp + Vector2(x, dy), Vector2.ONE), col)
						ci.draw_rect(Rect2(cp + Vector2(-x, dy), Vector2.ONE), col)
			else:
				ci.draw_rect(Rect2(cp + Vector2(-half, dy), Vector2(half * 2 + 1, 1)), col)
