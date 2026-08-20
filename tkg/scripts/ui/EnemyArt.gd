class_name EnemyArt
extends TextureRect

## Procedural enemy sprites. Ships get riveted industrial plating; fauna get
## dithered organic segments. The Hulk's "winding up" telegraph lights its ram
## prow — art and mechanics doing the same job.
##
## Everything below obeys ART_CONTRACT's two-plane rule, and `_hull` is that
## rule written once: a lit top face, a bright lip, a front wall falling away
## into shadow, and a 1px ink outline around the silhouette. The first version
## of these sprites filled rectangles with one flat colour each, which is why
## the Hulk read as a brown box with three orange boxes on it and the fauna read
## as a bar chart. The shapes were never really the problem — nothing was
## lighting them, and every silhouette was a rectangle because a rectangle is
## what `px()` draws.
##
## So the two things this file adds are a ramp and a profile. A ramp is six
## value stops out of ART_CONTRACT section 3, spaced widely enough to survive
## being looked at from across a screen. A profile is a handful of control
## points that `_hull` tapers between, so a hull can be a shape.

## The box the ship occupies inside this canvas, in local pixels. See set_enemy.
var _used: Rect2i = Rect2i(0, 0, 240, 120)
var _bounds: Rect2i = Rect2i()
var _track: bool = false

func used_rect() -> Rect2i:
	return _used

const W := 240
const H := 120

var _img: Image
var _tex: ImageTexture

## What the current image was drawn from. See set_enemy.
var _sig: String = ""

## Six stops, darkest first: shadow, wall, lit wall, deck, lit deck, rim.
##
## Sampled from ART_CONTRACT section 3. Do not add a seventh stop to one of
## these — add a whole ramp, which is how a new manufacturer is supposed to
## enter the game. The gap between stop 1 and stop 3 is the two-plane break and
## it is deliberately large; closing it is how you get a flat sprite back.
var _steel: Array[Color] = [Color("#131a23"), Color("#232d3a"), Color("#344254"),
	Color("#4a5c72"), Color("#6c8098"), Color("#92aac4")]
var _brass: Array[Color] = [Color("#2c2212"), Color("#4a3a20"), Color("#6c542e"),
	Color("#927440"), Color("#bc9a5c"), Color("#d8bc84")]
var _chitin: Array[Color] = [Color("#182636"), Color("#283e56"), Color("#3a5876"),
	Color("#4d7096"), Color("#6a90b2"), Color("#9cc4de")]
var _gun: Array[Color] = [Color("#0e1116"), Color("#1a1e26"), Color("#2a3038"),
	Color("#3a404c"), Color("#5c6474"), Color("#7d8698")]
## The only warm ramp any of these are allowed, and only where something emits.
var _heat: Array[Color] = [Color("#5c280c"), Color("#964214"), Color("#cc641c"),
	Color("#ffa63c"), Color("#ffdca0"), Color("#fff6e2")]
var _ink: Color = Color("#0b0f16")

func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Draw at native size, centred. KEEP_ASPECT_CENTERED rescales the texture to
	# whatever rect it is handed, so the enemy changed size whenever a side rail
	# opened — and scaled pixel art by arbitrary fractions while doing it.
	stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	# A TextureRect takes its minimum size FROM ITS TEXTURE unless told not to,
	# so custom_minimum_size could never shrink this below the 240x120 canvas —
	# which is why cropping the empty margin appeared to do nothing at all and
	# the health bar stayed a canvas-height away from the hull. IGNORE_SIZE
	# hands the decision back to us; clip_contents keeps the overflow off screen.
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	clip_contents = true
	custom_minimum_size = Vector2(W, H)
	_img = Image.create(W, H, false, Image.FORMAT_RGBA8)
	_tex = ImageTexture.create_from_image(_img)
	texture = _tex

func px(x: int, y: int, w: int, h: int, c: Color) -> void:
	# While _track is on, every stroke widens the hull's bounding box. It has to
	# be measured this way rather than from the finished image: the canvas gets
	# a starfield painted across it first, so get_used_rect() on the image
	# correctly answers "all of it" and tells you nothing about the ship.
	if _track:
		var r := Rect2i(x, y, maxi(w, 1), maxi(h, 1))
		_bounds = r if _bounds.size == Vector2i.ZERO else _bounds.merge(r)
	for j in h:
		for i in w:
			var xx := x + i
			var yy := y + j
			if xx >= 0 and xx < W and yy >= 0 and yy < H:
				_img.set_pixel(xx, yy, c)

func dither(x: int, y: int, w: int, h: int, c: Color, density: float) -> void:
	var thresholds := [0.0, 0.5, 0.75, 0.25]
	for j in h:
		for i in w:
			var t: float = thresholds[(i % 2) + (j % 2) * 2]
			if t < density:
				px(x + i, y + j, 1, 1, c)

func rivets(x: int, y: int, count: int, step: int, c: Color) -> void:
	for i in count:
		px(x + i * step, y, 1, 1, c)


# --- The two-plane kit -------------------------------------------------------

## Control points (x, top, bottom) filled in for every column between them.
##
## Authoring a hull as six points and letting this interpolate the taper is the
## whole difference between a ship and a rectangle. It is also what lets a
## silhouette be raked — the Cutter's top edge falls away toward the nose while
## its belly stays flat, and tapering both edges by the same amount is exactly
## what made the first attempt read as an airship.
func _profile(pts: Array) -> Dictionary:
	var out := {}
	for i in range(pts.size() - 1):
		var a: Vector3i = pts[i]
		var b: Vector3i = pts[i + 1]
		for x in range(a.x, b.x + 1):
			var t := 0.0 if b.x == a.x else float(x - a.x) / float(b.x - a.x)
			out[x] = Vector2i(
				int(round(lerpf(float(a.y), float(b.y), t))),
				int(round(lerpf(float(a.z), float(b.z), t))))
	return out

## One body, lit from the top of the frame.
##
## Column by column, because the shape changes column by column: rim, top face,
## the bright lip where the deck turns, then the wall dropping through two
## dithered steps into the shadow it sits in. `deck` is how much of the height
## the top face takes — high for something seen more from above, low for a
## strake hanging off the underside.
##
## `cap` closes the two ends with ink. Turn it off for a piece that runs into
## another one, or you get a black seam where they meet.
func _hull(prof: Dictionary, r: Array, deck: float = 0.55, cap: bool = true) -> void:
	var xs := prof.keys()
	xs.sort()
	if xs.is_empty():
		return
	for x in xs:
		var span: Vector2i = prof[x]
		var t: int = span.x
		var b: int = span.y
		var h := b - t
		if h < 2:
			continue
		var d: int = maxi(2, int(round(h * deck)))
		px(x, t, 1, d, r[3])
		px(x, t, 1, 1, r[4])
		dither(x, t + 1, 1, mini(3, d - 1), r[4], 0.5)
		px(x, t + d - 1, 1, 1, r[5])
		px(x, t + d, 1, h - d, r[1])
		px(x, t + d, 1, mini(2, h - d), r[2])
		dither(x, t + d + 2, 1, maxi(1, (h - d) / 2), r[2], 0.4)
		dither(x, b - 4, 1, 3, r[0], 0.45)
		px(x, b - 1, 1, 1, r[0])
		px(x, t - 1, 1, 1, _ink)
		px(x, b, 1, 1, _ink)
	if cap:
		for raw in [[int(xs[0]), -1], [int(xs[xs.size() - 1]), 1]]:
			var pair: Array = raw
			var e: Vector2i = prof[pair[0]]
			px(int(pair[0]) + int(pair[1]), e.x - 1, 1, e.y - e.x + 2, _ink)

## Anything slung UNDER a hull sits in that hull's shadow, so it takes the same
## ramp shifted two stops down. Given the deck ramp it reads as a separate
## object floating below the ship rather than a part of it.
func _under(r: Array) -> Array:
	return [r[0], r[0], r[1], r[1], r[2], r[3]]

## A raised box on the deck. Same lighting as a hull, no taper.
func _plate(x: int, y: int, w: int, h: int, r: Array, deck: float = 0.6) -> void:
	_hull(_profile([Vector3i(x, y, y + h), Vector3i(x + w, y, y + h)]), r, deck)

## A panel seam: a dark line with the light catching the plate edge beside it.
func _seam(x: int, y: int, h: int, r: Array) -> void:
	px(x, y, 1, h, r[0])
	px(x + 1, y, 1, h, r[4])

## Weathering. It runs DOWN the wall, because that is the direction things run.
func _streak(x: int, y: int, h: int, r: Array) -> void:
	dither(x, y, 2, h, r[0], 0.55)

## A thruster wash: the only warmth a hull is allowed, and it falls off. Solid
## near the nozzle, dithered out to nothing, so the plume has an edge without
## having a boundary.
func _glow(x: int, y: int, half: int, length: int) -> void:
	for i in length:
		var t := float(i) / float(length)
		var hh: int = maxi(1, int(round(float(half) * (1.0 - t * 0.72))))
		var col: Color = _heat[1]
		if t < 0.10:
			col = _heat[5]
		elif t < 0.24:
			col = _heat[4]
		elif t < 0.44:
			col = _heat[3]
		elif t < 0.68:
			col = _heat[2]
		if t < 0.34:
			px(x + i, y - hh, 1, hh * 2, col)
		else:
			dither(x + i, y - hh, 1, hh * 2, col, 0.9 - t * 0.85)

## A radiator louvre, glowing from inside its recess.
func _vent(x: int, y: int, w: int, h: int) -> void:
	px(x - 1, y - 1, w + 2, h + 2, _ink)
	px(x, y, w, h, _heat[0])
	px(x, y, w, maxi(1, h / 2), _heat[1])
	px(x, y, w, 1, _heat[2])

## A hole, not a decal.
##
## Scorch first, in three rings of falling size and rising density so the edge
## has no boundary; then a ragged core built from three offset boxes, because a
## single box reads as a sticker someone put on the ship; then whatever is still
## burning at the bottom of it.
func _wound(cx: int, cy: int, w: int, h: int, ember: bool = true) -> void:
	var rings := [
		[-7, -5, 14, 10, 0.25], [-4, -2, 9, 5, 0.5], [-2, -1, 5, 3, 0.85]]
	for i in rings.size():
		var g: Array = rings[i]
		dither(cx - w / 2 + int(g[0]), cy - h / 2 + int(g[1]),
			w + int(g[2]), h + int(g[3]),
			Color("#1c1409") if i == 0 else Color("#120c06"), float(g[4]))
	for raw in [[0, 0, w, h], [-3, 2, w - 4, h - 4], [4, -2, w - 6, h - 3]]:
		var q: Array = raw
		px(cx - int(q[2]) / 2 + int(q[0]), cy - int(q[3]) / 2 + int(q[1]),
			int(q[2]), int(q[3]), Color("#0a0805"))
	if ember:
		px(cx - 2, cy + h / 2 - 3, 6, 3, _heat[0])
		px(cx - 1, cy + h / 2 - 3, 3, 2, _heat[1])
		px(cx + 5, cy - h / 2 + 1, 3, 2, _heat[0])


# --- The enemies -------------------------------------------------------------

func set_enemy(e: Combat.EnemyState, telegraphing: bool) -> void:
	var wounded := float(e.hp) / float(maxi(1, e.max_hp))
	# Rebuilding a 240x120 image column by column is not free, and bind() runs
	# on every combat refresh — every card played, every intent that changes.
	# Nothing below reads anything except which art, whether it is winding up,
	# roughly how hurt it is and how big it is, so the redraw is skipped unless
	# one of those four actually moved. Skipping is safe for the layout too:
	# _used and custom_minimum_size are left from the draw that still matches.
	var sig := "%s|%d|%d|%d" % [e.template.art, int(telegraphing),
		int(wounded * 20.0), int(e.max_hp > 60)]
	if sig == _sig:
		return
	_sig = sig

	# Transparent: the encounter draws one starfield behind everything, and an
	# opaque fill turns the sprite into a box sitting on top of it.
	_img.fill(Color(0, 0, 0, 0))
	_starfield(77, 26)
	# Bounds tracking starts AFTER the starfield and stops before the wound
	# tint, so what it measures is the ship and nothing else. A 240x120 canvas
	# carries a hull about 150 wide; anything aiming at the canvas is aiming at
	# a lot of empty pixels, which costs real estate as soon as two enemies
	# share the arena.
	_bounds = Rect2i()
	_track = true
	match e.template.art:
		&"cutter": _draw_cutter(wounded)
		&"hulk": _draw_hulk(wounded, telegraphing)
		_: _draw_fauna(wounded, e.max_hp > 60)
	_track = false
	_used = _bounds if _bounds.size != Vector2i.ZERO else Rect2i(0, 0, W, H)

	# And the Control shrinks to fit it. The canvas is a fixed 240x120 while a
	# hull is about 150 wide and 40 tall, so the Control was carrying eighty
	# pixels of empty image below the ship — which is what held the health bar
	# and the intent so far away from it. Nothing that reads as "near the ship"
	# can be, while the ship's own box is mostly not ship.
	#
	# Sized symmetrically about the canvas centre because the texture is drawn
	# KEEP_CENTERED: taking the larger half-extent on each axis crops the margin
	# without ever moving the hull inside the frame.
	var cx := W * 0.5
	var cy := H * 0.5
	var half_w: float = maxf(absf(float(_used.position.x) - cx), absf(float(_used.end.x) - cx))
	var half_h: float = maxf(absf(float(_used.position.y) - cy), absf(float(_used.end.y) - cy))
	clip_contents = true
	custom_minimum_size = Vector2(half_w, half_h) * 2.0 + Vector2(6, 6)
	if wounded < 0.3:
		_blend_rect(0, 0, W, H, Color(0.031, 0.043, 0.067, 0.35))
	_tex.update(_img)

## Rustjaw Cutter: a blade with an engine bolted to the back of it, nosing left.
func _draw_cutter(wounded: float) -> void:
	var body := _profile([
		Vector3i(40, 66, 71), Vector3i(50, 58, 75), Vector3i(62, 50, 77),
		Vector3i(78, 44, 78), Vector3i(100, 41, 79), Vector3i(130, 41, 78),
		Vector3i(146, 43, 75), Vector3i(158, 46, 71), Vector3i(166, 49, 68)])

	# Dorsal blade first, so the hull's own rim light cuts across its foot and
	# it reads as growing out of the deck rather than floating over it.
	_hull(_profile([
		Vector3i(90, 40, 46), Vector3i(100, 31, 46), Vector3i(110, 26, 46),
		Vector3i(118, 25, 46), Vector3i(134, 33, 46), Vector3i(146, 41, 46)]),
		_steel, 0.62, false)
	# Ventral strake, in the hull's shadow.
	_hull(_profile([
		Vector3i(100, 75, 85), Vector3i(112, 75, 89), Vector3i(128, 75, 87),
		Vector3i(136, 75, 80)]), _under(_steel), 0.3, false)
	_hull(body, _steel, 0.56)

	# Seams stop at the lip. A seam drawn across it flattens the one value break
	# that is holding the whole sprite up.
	for x in [92, 110, 128]:
		var span: Vector2i = body[x]
		_seam(x, span.x + 2, int(float(span.y - span.x) * 0.56) - 3, _steel)
	rivets(84, 47, 20, 4, _steel[1])
	rivets(84, 71, 20, 4, _steel[0])
	# Recessed deck hatches: a well loses its top face but is still lit by the
	# sky, so it goes one stop down and keeps a bright lip on its far side.
	# Drawn near black it reads as a hole punched through the sprite.
	for raw in [[94, 12], [110, 9], [123, 12]]:
		var hatch: Array = raw
		var hx: int = hatch[0]
		var hw: int = hatch[1]
		px(hx, 47, hw, 6, _steel[1])
		px(hx, 47, hw, 2, _steel[0])
		dither(hx, 49, hw, 2, _steel[2], 0.4)
		px(hx, 52, hw, 1, _steel[4])
	# Hull number, stencilled. Four glyphs of three pixels: enough to read as
	# writing, not enough to pretend it says anything.
	for i in 4:
		var bits: int = [0b111, 0b010, 0b101, 0b110][i]
		for b in 3:
			if (bits >> (2 - b)) & 1:
				px(136 + i * 4, 62 + b, 2, 1, _steel[5])
	for x in [84, 100, 116, 132, 146]:
		_streak(x, 66, 11, _steel)

	# Canopy, set into the deck behind the nose.
	px(68, 49, 18, 8, _ink)
	px(69, 50, 16, 6, Color("#162e40"))
	px(69, 50, 16, 3, Color("#3a6b8c"))
	px(70, 50, 10, 2, Color("#8ec8e6"))
	px(70, 50, 6, 1, Color("#cfe8f5"))

	# Korvan gun, slung under the prow with the barrel out front.
	_hull(_profile([Vector3i(58, 72, 84), Vector3i(84, 72, 84)]), _brass, 0.5)
	for i in 4:
		px(61 + i * 6, 78, 3, 2, Color("#a8873f"))
	px(46, 75, 13, 5, _ink)
	px(46, 76, 12, 3, _gun[2])
	px(46, 76, 12, 1, _gun[4])
	px(40, 77, 6, 1, _gun[1])

	# Engine block, louvres and the wash it throws.
	_hull(_profile([Vector3i(166, 48, 70), Vector3i(178, 50, 68)]), _gun, 0.5)
	_vent(158, 51, 8, 5)
	_vent(158, 62, 8, 5)
	px(178, 53, 5, 12, _ink)
	px(178, 54, 5, 10, _gun[1])
	px(178, 54, 5, 1, _gun[3])
	_glow(183, 59, 6, 20)

	# Mast, with a running light on it.
	px(107, 22, 3, 8, _gun[2])
	px(106, 21, 5, 2, _gun[4])
	px(107, 19, 3, 2, Color("#d64a3a"))

	if wounded < 0.5:
		_wound(112, 58, 17, 12)

## Dreg Hulk: tonnage. The hull steps at both ends and the deck is stacked, so
## the mass reads as decks and containers instead of one filled rectangle.
func _draw_hulk(wounded: float, telegraphing: bool) -> void:
	var body := _profile([
		Vector3i(42, 46, 70), Vector3i(50, 34, 84), Vector3i(56, 29, 91),
		Vector3i(58, 28, 92), Vector3i(146, 28, 92), Vector3i(150, 29, 91),
		Vector3i(156, 34, 86), Vector3i(164, 40, 80)])

	# Containers first: the hull's outline then cuts their feet off, which is
	# what puts them ON the deck rather than behind it.
	for raw in [[60, 24, 13], [88, 28, 16], [122, 22, 12]]:
		var box: Array = raw
		var bx: int = box[0]
		var bw: int = box[1]
		var bh: int = box[2]
		_plate(bx, 30 - bh, bw, bh, _brass, 0.66)
		rivets(bx + 3, 32 - bh, (bw - 6) / 4, 4, _brass[1])
	_hull(body, _brass, 0.52)

	for x in [74, 98, 122, 146]:
		var span: Vector2i = body[x]
		var d := int(float(span.y - span.x) * 0.52)
		_seam(x, span.x + 2, d - 3, _brass)
		_streak(x + 3, span.x + d + 4, 22, _brass)
	rivets(58, 33, 26, 4, _brass[1])
	rivets(58, 56, 26, 4, _brass[0])
	# Hazard banding along the deck edge, and cargo tie-down points. Density is
	# what makes tonnage read as tonnage.
	for i in 11:
		px(64 + i * 8, 37, 4, 2, Color("#a8873f"))
	for i in 8:
		px(66 + i * 11, 44, 2, 2, _brass[0])
		px(66 + i * 11, 44, 2, 1, _brass[4])
	# Cargo wells, open, with something down in each of them.
	for raw2 in [[64, 16], [86, 20], [112, 14], [132, 12]]:
		var well: Array = raw2
		var hx: int = well[0]
		var hw: int = well[1]
		px(hx, 48, hw, 9, _brass[1])
		px(hx, 48, hw, 2, _brass[0])
		dither(hx, 50, hw, 4, _brass[2], 0.4)
		px(hx + 2, 52, hw - 4, 4, _brass[2])
		px(hx + 2, 52, hw - 4, 1, _brass[3])
		px(hx, 56, hw, 1, _brass[4])
	# Lit portholes: there is a crew aboard. This looks like ambient warmth and
	# is not — every one of these pixels is a window with a light behind it.
	for i in 11:
		px(58 + i * 9, 70, 4, 3, _heat[0])
		px(58 + i * 9, 70, 4, 1, _heat[2])
	for i in 9:
		px(62 + i * 10, 82, 3, 2, _brass[0])
		px(62 + i * 10, 82, 3, 1, _brass[2])
	# Ventral pod, so the underside is not one uninterrupted wall.
	_hull(_profile([
		Vector3i(86, 86, 98), Vector3i(100, 86, 103), Vector3i(122, 86, 101),
		Vector3i(134, 86, 93)]), _under(_brass), 0.25, false)

	# Bridge blister aft.
	_plate(126, 20, 24, 12, _brass, 0.5)
	px(130, 24, 16, 5, Color("#162e40"))
	px(130, 24, 16, 2, Color("#3a6b8c"))
	px(131, 24, 9, 1, Color("#8ec8e6"))

	# Stern engine bank.
	_hull(_profile([Vector3i(166, 40, 80), Vector3i(182, 44, 76)]), _gun, 0.5)
	for y in [46, 58, 70]:
		_vent(158, y, 8, 6)
	px(182, 50, 6, 20, _ink)
	px(182, 51, 6, 18, _gun[1])
	px(182, 51, 6, 1, _gun[3])
	_glow(188, 60, 10, 18)

	# The ram prow. Telegraphing lights it, so the tell and the weapon are the
	# same object — you learn what the glow means by being hit by it once.
	_hull(_profile([Vector3i(30, 50, 66), Vector3i(44, 46, 70)]), _brass, 0.5)
	if telegraphing:
		px(24, 51, 8, 14, _heat[2])
		px(24, 51, 8, 3, _heat[4])
		px(18, 54, 6, 8, _heat[4])
		px(13, 56, 5, 4, _heat[5])
		dither(4, 48, 12, 20, _heat[3], 0.5)
		dither(0, 52, 5, 12, _heat[2], 0.3)
	else:
		px(24, 51, 8, 14, _ink)
		px(25, 52, 7, 12, _brass[2])
		px(25, 52, 7, 2, _brass[4])

	if wounded < 0.5:
		_wound(100, 58, 24, 17)

## The fauna: an armoured, segmented thing. Not a ship, and lit like one anyway,
## because the light in this sector does not care what it is falling on. What
## separates it from the ships is that its light is COLD — nothing alive out
## here runs a furnace.
func _draw_fauna(wounded: float, big: bool) -> void:
	var segs := 12 if big else 10
	var seg_w := 11 if big else 10
	var span := 52.0 if big else 42.0
	var x0 := 54

	# Drawn tail first so each plate overlaps the one behind it. The trailing
	# edge is then laid down AFTER its own plate and never covered, because
	# everything drawn later is to the left of it — without that edge the
	# overlaps merge into one smooth teardrop, which is the exact failure the
	# flat version had.
	for k in segs:
		var i := segs - 1 - k
		var h := int(round(span - absf(float(i) - float(segs) / 2.0 + 0.5) * 4.4))
		var x := x0 + i * seg_w
		var t := 60 - int(float(h) * 0.52)
		var nxt := int(round(span - absf(float(i + 1) - float(segs) / 2.0 + 0.5) * 4.4))
		var nt := 60 - int(float(nxt) * 0.52)
		_hull(_profile([Vector3i(x, t, t + h),
			Vector3i(x + seg_w + 2, nt, nt + nxt)]), _chitin, 0.5, false)
		px(x + seg_w + 2, t - 1, 1, h + 3, _ink)
		px(x + seg_w + 1, t, 1, int(float(h) * 0.5), _chitin[5])
		px(x + seg_w + 1, t + int(float(h) * 0.5), 1,
			h - int(float(h) * 0.5), _chitin[0])
		# Dorsal ridge, and a bio-light in the shadow under the shell.
		px(x + 1, t + 1, seg_w - 1, 2, _chitin[5])
		if i % 2 == 0:
			px(x + 4, t + int(float(h) * 0.5) + 3, 3, 2, Color("#4fbfa8"))
			px(x + 4, t + int(float(h) * 0.5) + 3, 3, 1, Color("#a8f0dc"))
		if i >= 1 and i < segs - 1:
			px(x + 5, t + h, 2, 4 + (i % 3) * 2, _chitin[0])
			px(x + 5, t + h, 1, 3, _chitin[1])

	# Head: heavier than the body, and where the mouth is.
	_hull(_profile([Vector3i(26, 48, 68), Vector3i(34, 41, 76),
		Vector3i(44, 37, 82), Vector3i(56, 36, 84)]), _chitin, 0.48)
	px(30, 42, 24, 2, _chitin[5])

	# Mandibles. The lower one is a stop darker than the upper one for the same
	# reason everything else here is: the light comes from above.
	px(16, 44, 12, 5, _ink)
	px(16, 45, 12, 3, _chitin[3])
	px(16, 45, 12, 1, _chitin[5])
	px(16, 70, 12, 5, _ink)
	px(16, 71, 12, 3, _chitin[1])
	px(16, 71, 12, 1, _chitin[3])
	px(10, 47, 7, 2, _chitin[2])
	px(10, 72, 7, 2, _chitin[0])

	# Eye cluster. Four is a creature; one is a robot.
	for raw in [[32, 52], [39, 50], [33, 61], [41, 59]]:
		var eye: Array = raw
		var ex: int = eye[0]
		var ey: int = eye[1]
		px(ex - 1, ey - 1, 7, 6, _ink)
		px(ex, ey, 5, 4, Color("#1d3a4e"))
		px(ex, ey, 5, 2, Color("#5c82a4"))
		px(ex + 1, ey, 3, 1, Color("#cfe8f5"))

	var tx := x0 + segs * seg_w
	_hull(_profile([Vector3i(tx, 52, 68), Vector3i(tx + 10, 55, 65),
		Vector3i(tx + 18, 58, 62)]), _chitin, 0.5)

	if wounded < 0.55:
		for raw2 in [[-8, -6, 16, 12, 0.25, "#7a3a54"], [-5, -3, 10, 6, 0.5, "#5a2c44"],
				[-2, -1, 4, 2, 0.85, "#3a1c2e"]]:
			var g: Array = raw2
			dither(110 + int(g[0]), 51 + int(g[1]), 18 + int(g[2]),
				11 + int(g[3]), Color(String(g[5])), float(g[4]))
		for raw3 in [[0, 0, 16, 10], [-4, 3, 11, 6], [5, -2, 9, 5]]:
			var q: Array = raw3
			px(119 - int(q[2]) / 2 + int(q[0]), 51 - int(q[3]) / 2 + int(q[1]),
				int(q[2]), int(q[3]), Color("#20101c"))
		px(116, 54, 5, 2, Color("#4fbfa8"))
		px(116, 54, 3, 1, Color("#a8f0dc"))

func _starfield(seed_value: int, count: int) -> void:
	var s := seed_value
	for i in count:
		s = (s * 9301 + 49297) % 233280
		var x := int(float(s) / 233280.0 * W)
		s = (s * 9301 + 49297) % 233280
		var y := int(float(s) / 233280.0 * H)
		px(x, y, 1, 1, Color("#141c26"))

func _blend_rect(x: int, y: int, w: int, h: int, c: Color) -> void:
	for j in h:
		for i in w:
			var xx := x + i
			var yy := y + j
			if xx >= 0 and xx < W and yy >= 0 and yy < H:
				_img.set_pixel(xx, yy, _img.get_pixel(xx, yy).lerp(c, c.a))
