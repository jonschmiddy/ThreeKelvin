class_name SpaceBackdrop
extends Control

## The sky follows from the place and is fixed for the run; it stays dim as depth, not subject.
## Why: docs/why/SpaceBackdrop.md#sky-rules

## One per sector; DEEP is a real answer, as empty sky is what most space looks like.
enum Kind { DEEP, PLANET, GIANT, ASTEROIDS, STAR, FLEET, CORE }

## Class picks palette and texture together: an ice cap on a giant reads as a mistake.
enum World { ROCK, DESERT, ICE, VERDANT, CINDER, BANDED }

## Not `UITheme` constants: a planet is meant to have a colour nobody chose, then mixed to VOID.
## Why: docs/why/SpaceBackdrop.md#palette
const HUES := {
	World.ROCK:    [0.07, 0.05, 0.18, 0.52],
	World.DESERT:  [0.09, 0.04, 0.42, 0.62],
	World.ICE:     [0.55, 0.08, 0.20, 0.80],
	World.VERDANT: [0.42, 0.14, 0.36, 0.50],
	World.CINDER:  [0.03, 0.03, 0.30, 0.26],
	World.BANDED:  [0.00, 1.00, 0.34, 0.58],  ## hue rolled free; giants are anything
}

## A held object, as `_surface()` runs tens of thousands of times and a long arg list misorders.
class Recipe extends RefCounted:
	var cls: int = 0
	## Five shades, dark to light.
	var pal: Array = []
	var salt: int = 0
	var bands: float = 8.0
	var warp: float = 0.5
	var relief: float = 2.4
	## Longitude, latitude, radius — all in radians on the sphere, so a crater
	## keeps its size as it turns toward the limb.
	var craters: Array[Vector3] = []
	var storm: bool = false
	var storm_at: Vector2 = Vector2.ZERO
	var storm_r: float = 0.2
	var caps: bool = false
	var lit: bool = false
	var lit_p: float = 0.05
	## Where the system's star is, in the sphere's own space.
	var light: Vector3 = Vector3(0.0, 0.0, 1.0)


var _index: int = -1
var _seed: int = 0
var _kind: int = Kind.DEEP
## One unit vector for the star, so the light in a sector comes from one place.
var _light: Vector2 = Vector2(-0.6, -0.5)
## Chosen on arrival, as the limb light is baked from it: one light, decided once.
var _star_tint: Color = Color("#c8dcf0")
var _star_edge: Color = Color("#6f9fc8")
var _dust: Color = Color("#41505f")
var _accent: Color = Color("#8fa3ba")
var _density: float = 1.0
var _has_sun: bool = true

# Rings and moon bake into one image, so the ring passes behind then in front with no ordering.
var _body: ImageTexture
var _body_px: int = 3     ## integer upscale; pixel art is never scaled by a fraction
var _body_at: Vector2 = Vector2(0.5, 0.5)   ## centre, as a fraction of the view
## `frame_in` places the disc, not the picture, for rooms covering the bottom third.
## Why: docs/why/SpaceBackdrop.md#framing
var frame_in: Rect2 = Rect2()
var _disc_top := 0.0
var _disc_r := 0.0
## The bake waits for a size, as a Control has none inside setup(), and re-runs on height change.
## Why: docs/why/SpaceBackdrop.md#bake-timing
var _node: MapGen.MapNode = null
var _baked_h: float = 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

## Called on every refresh, so the early-out is load-bearing: bake on arrival only.
func setup(n: MapGen.MapNode) -> void:
	if n == null or n.index == _index:
		return
	_index = n.index
	# Two constants apart from the name hash, so a system's sky and its name are
	# not correlated in some way you could learn to read.
	_seed = ((n.index + 1) * 1103515245 + 12345) & 0x7fffffff
	var r := RandomNumberGenerator.new()
	r.seed = _seed

	_light = Vector2(-1.0, -0.55) if r.randf() < 0.5 else Vector2(1.0, -0.55)
	_light = _light.normalized()
	# Uses the node's own star as the map draws it; the draw is kept so later rolls hold.
	r.randf()
	match n.star:
		MapGen.Star.RED:
			_star_tint = Color("#ffc29a")
			_star_edge = Color("#c8603c")
		MapGen.Star.BLUE:
			_star_tint = Color("#eaf4ff")
			_star_edge = Color("#6f9fe0")
		_:
			_star_tint = Color("#f6f2e4")
			_star_edge = Color("#b2a486")
	_dust = MapGen.star_colour(n)
	_accent = _dust
	if n.manufacturer != &"":
		_accent = DB.manufacturer_colour(n.manufacturer)
	_kind = _pick(n, r)
	# Its own gas giant, present only where the map has one, so the two views agree.
	if n.type != MapGen.NodeType.PULSAR and n.type != MapGen.NodeType.CORE and n.type != MapGen.NodeType.START:
		if n.gas_giant and _kind != Kind.GIANT:
			_kind = Kind.GIANT
		elif not n.gas_giant and _kind == Kind.GIANT:
			_kind = Kind.PLANET
	_has_sun = _kind != Kind.STAR and _kind != Kind.CORE
	# Empty sky shows more stars because nothing is washing them out, and a
	# nebula shows fewer because you are looking through gas.
	_density = 1.0
	if _kind == Kind.DEEP:
		_density = 1.45
	elif _kind == Kind.CORE:
		_density = 2.1
	if n.in_nebula:
		_density *= 0.55

	_node = n
	_body = null
	_baked_h = 0.0
	_bake_if_ready()
	queue_redraw()

## Bakes once a view exists, and again if its height changes by over a quarter.
func _bake_if_ready() -> void:
	if _node == null or (_kind != Kind.PLANET and _kind != Kind.GIANT):
		return
	if size.y < 8.0:
		return
	if _body != null and absf(size.y - _baked_h) < _baked_h * 0.25:
		return
	_baked_h = size.y
	_bake_world(_node)
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_bake_if_ready()

## The node type answers first as the map's strongest statement; only open cases roll.
func _pick(n: MapGen.MapNode, r: RandomNumberGenerator) -> int:
	match n.type:
		MapGen.NodeType.STATION:
			# A station is built where there is something to service, hold or mine.
			return Kind.GIANT if n.fauna or r.randf() < 0.18 else Kind.PLANET
		MapGen.NodeType.SYSTEM:
			# An ordinary system gets the variety of the three types it replaced: mostly rocks.
			if r.randf() < 0.42:
				return Kind.ASTEROIDS
			return Kind.PLANET if r.randf() < 0.55 else Kind.DEEP
		MapGen.NodeType.START:
			# The one sector that is meant to have nothing in it, and the same
			# ruling that keeps AreaView from drawing a marker here.
			return Kind.DEEP
		MapGen.NodeType.PULSAR:
			# The beam IS the subject. Anything else in frame competes with it.
			return Kind.DEEP
		MapGen.NodeType.CORE:
			return Kind.CORE

		_:
			return _pick_open(n, r)

## One roll per question: a single number tested twice is not two independent chances.
## Why: docs/why/SpaceBackdrop.md#pick-rolls
func _pick_open(n: MapGen.MapNode, r: RandomNumberGenerator) -> int:
	if n.fauna:
		# Migration follows the giants. The whales are here because the gas is.
		return Kind.GIANT if r.randf() < 0.62 else Kind.DEEP
	if n.berths.size() >= 2 and r.randf() < 0.42:
		# Contested space is space with hulls in it.
		return Kind.FLEET
	var roll := r.randf()
	if n.development >= MapGen.Development.CITY:
		return Kind.PLANET if roll < 0.55 else Kind.FLEET
	if n.development == MapGen.Development.UNCLAIMED:
		# Nobody is here. Rocks, a dead world, a star nobody named, or nothing.
		if roll < 0.34:
			return Kind.ASTEROIDS
		if roll < 0.55:
			return Kind.PLANET
		if roll < 0.66:
			return Kind.STAR
		return Kind.DEEP
	if roll < 0.34:
		return Kind.PLANET
	if roll < 0.52:
		return Kind.ASTEROIDS
	if roll < 0.64:
		return Kind.FLEET
	if roll < 0.74:
		return Kind.STAR
	return Kind.DEEP

# ------------------------------------------------------------------ the world

## Development is the tell: a capital is terraformed or stripped, unclaimed space is rock and ice.
func _world_class(n: MapGen.MapNode, r: RandomNumberGenerator) -> int:
	if _kind == Kind.GIANT:
		return World.BANDED
	var roll := r.randf()
	if n.development >= MapGen.Development.SETTLEMENT:
		if roll < 0.42:
			return World.VERDANT
		if roll < 0.78:
			return World.DESERT
		return World.ICE
	if n.development >= MapGen.Development.OUTPOST:
		if roll < 0.40:
			return World.DESERT
		if roll < 0.68:
			return World.ROCK
		return World.ICE
	if roll < 0.40:
		return World.ROCK
	if roll < 0.62:
		return World.ICE
	if roll < 0.84:
		return World.DESERT
	return World.CINDER

## Baked not drawn: per-pixel lighting is costly in `_draw`, and an Image orders ring and planet.
## Why: docs/why/SpaceBackdrop.md#world-bake
func _bake_world(n: MapGen.MapNode) -> void:
	# Own stream salted off the seed, so the world does not change when setup() draws more.
	var r := RandomNumberGenerator.new()
	r.seed = _seed ^ 0x5bf03635
	var cls := _world_class(n, r)

	# `frac` is a radius, not diameter (corners hit 300 px); top-left stays clear for text.
	# Why: docs/why/SpaceBackdrop.md#composition
	var shot := r.randf()
	var big: bool = n.type == MapGen.NodeType.STATION
	var frac: float
	if big and shot < 0.62:
		# Right of centre and low: the dock is on the right, your hull on the left.
		frac = r.randf_range(0.5, 0.72)
		_body_at = Vector2(r.randf_range(0.42, 0.86), r.randf_range(1.16, 1.42))
	elif shot < 0.42:
		frac = r.randf_range(0.16, 0.26)
		_body_at = Vector2(r.randf_range(0.64, 0.92), r.randf_range(0.08, 0.26))
	elif shot < 0.72:
		frac = r.randf_range(0.17, 0.28)
		_body_at = Vector2(r.randf_range(0.08, 0.28), r.randf_range(0.74, 0.96))
	else:
		frac = r.randf_range(0.06, 0.11)
		_body_at = Vector2(r.randf_range(0.52, 0.94), r.randf_range(0.16, 0.42))

	# Source resolution follows draw size; the ceiling is measured: radius 64 is 95 ms, 78 is 140.
	# Why: docs/why/SpaceBackdrop.md#world-bake
	var want: float = maxf(40.0, frac * maxf(size.y, 240.0))
	var rr := int(clampf(want / 3.0, 14.0, 64.0))
	_body_px = clampi(int(round(want / float(rr))), 2, 4)

	var rings: bool = cls == World.BANDED and r.randf() < 0.66
	if cls != World.BANDED and r.randf() < 0.10:
		rings = true
	var tilt := r.randf_range(0.16, 0.38)
	var ring_in := r.randf_range(1.32, 1.5)
	var ring_out := ring_in + r.randf_range(0.42, 0.9)
	var moon: bool = r.randf() < 0.34
	var moon_r := int(maxf(3.0, float(rr) * r.randf_range(0.13, 0.22)))
	var moon_ang := r.randf_range(0.0, TAU)
	var moon_at := Vector2(cos(moon_ang), sin(moon_ang) * 0.7) * float(rr) * r.randf_range(1.6, 2.3)

	# The box has to hold whichever of the three sticks out furthest.
	var hx := float(rr) + 3.0
	var hy := float(rr) + 3.0
	if rings:
		hx = maxf(hx, float(rr) * ring_out + 3.0)
		hy = maxf(hy, float(rr) * ring_out * tilt + 3.0)
	if moon:
		hx = maxf(hx, absf(moon_at.x) + float(moon_r) + 2.0)
		hy = maxf(hy, absf(moon_at.y) + float(moon_r) + 2.0)
	var w := int(hx) * 2 + 1
	var h := int(hy) * 2 + 1
	var cx := int(hx)
	var cy := int(hy)

	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var rec := Recipe.new()
	rec.cls = cls
	rec.pal = _palette(cls, r)
	rec.salt = int(r.randi() & 0xffff)
	# Bands have to agree with themselves all the way round the sphere, so the
	# count is rolled here and read per pixel rather than rolled per pixel.
	rec.bands = r.randf_range(5.0, 13.0)
	rec.warp = r.randf_range(0.25, 1.1)
	rec.relief = r.randf_range(1.6, 3.4)
	if cls == World.ROCK or cls == World.ICE or cls == World.CINDER:
		for i in r.randi_range(4, 11):
			rec.craters.append(Vector3(r.randf_range(-1.2, 1.2), r.randf_range(-1.0, 1.0),
				r.randf_range(0.10, 0.30)))
	# A storm is one oval that disagrees with the bands around it. Often enough
	# to be a feature of giants, rare enough to be worth seeing.
	rec.storm = cls == World.BANDED and r.randf() < 0.55
	rec.storm_at = Vector2(r.randf_range(-0.55, 0.55), r.randf_range(-0.6, 0.6))
	rec.storm_r = r.randf_range(0.16, 0.30)
	rec.caps = cls == World.VERDANT or cls == World.ICE \
		or (cls == World.DESERT and r.randf() < 0.4)
	# Lit windows are the one warm thing allowed, and only where people live.
	rec.lit = cls != World.BANDED and n.development >= MapGen.Development.SETTLEMENT
	# Sparse: realistic density turns the night side into orange sparks that read as damage.
	rec.lit_p = 0.018 + 0.014 * float(int(n.development) - int(MapGen.Development.SETTLEMENT))
	# Slightly toward the viewer as well as to the side, so the terminator falls
	# across the visible face instead of exactly down the limb.
	rec.light = Vector3(_light.x, _light.y, 0.62).normalized()
	for py in h:
		for px in w:
			var dx := float(px - cx)
			var dy := float(py - cy)
			var col := Color(0, 0, 0, 0)
			var u := 0.0
			if rings:
				u = sqrt((dx / float(rr)) * (dx / float(rr))
					+ (dy / (float(rr) * tilt)) * (dy / (float(rr) * tilt)))
			var on_ring: bool = rings and u >= ring_in and u <= ring_out \
				and _ring_gap(u, ring_in, ring_out, rec.salt)
			# Back half first, then the sphere over it, then the near half over
			# both. Three writes, and the occlusion falls out for free.
			if on_ring and dy < 0.0:
				col = _ring_colour(u, ring_in, ring_out, rec)
			var nx := dx / float(rr)
			var ny := dy / float(rr)
			var rad := nx * nx + ny * ny
			if rad <= 1.0:
				col = _surface(nx, ny, rec, px, py)
			elif rad <= 1.30 and col.a == 0.0:
				col = _halo(nx, ny, rad, rec)
				if not _sieve(px, py, col.a * 2.2):
					col = Color(0, 0, 0, 0)
				else:
					col.a = minf(1.0, col.a * 2.4)
			if on_ring and dy >= 0.0:
				col = _ring_colour(u, ring_in, ring_out, rec)
			if moon:
				var mx := (dx - moon_at.x) / float(moon_r)
				var my := (dy - moon_at.y) / float(moon_r)
				if mx * mx + my * my <= 1.0:
					col = _moon_px(mx, my, rec)
			if col.a > 0.0:
				img.set_pixel(px, py, col)

	_body = ImageTexture.create_from_image(img)
	_disc_top = float((cy - rr) * _body_px)
	_disc_r = float(rr * _body_px)

## Where the gaps in a ring are. A solid band reads as a plate; the gaps are the
## whole reason a ring looks like billions of separate rocks.
func _ring_gap(u: float, a: float, b: float, salt: int) -> bool:
	var t := (u - a) / maxf(0.001, b - a)
	return _noise(t * 26.0, 3.5, salt + 71) > 0.36

func _ring_colour(u: float, a: float, b: float, rec: Recipe) -> Color:
	var t := (u - a) / maxf(0.001, b - a)
	var v := _noise(t * 18.0, 1.5, rec.salt + 71)
	var c: Color = (rec.pal[1] as Color).lerp(rec.pal[3] as Color, v)
	# Rings are seen edge-on and are mostly empty, so they never sit at full
	# strength — they are the dimmest thing on the body by design.
	c.a = 0.34 + 0.30 * v
	return c.lerp(UITheme.VOID, 0.30)

## One pixel of sphere: surface value, then light, then the pull toward the void.
func _surface(nx: float, ny: float, rec: Recipe, px: int, py: int) -> Color:
	var nz := sqrt(maxf(0.0, 1.0 - nx * nx - ny * ny))
	# Longitude and latitude, so the texture wraps a ball and detail crowds the limb.
	var lon := atan2(nx, maxf(0.001, nz))
	var lat := asin(clampf(ny, -1.0, 1.0))
	var v := 0.0
	match rec.cls:
		World.BANDED:
			var wob := _fbm(lon * 1.4, lat * 3.0, rec.salt) - 0.5
			v = 0.5 + 0.5 * sin(lat * rec.bands + wob * rec.warp * 3.0)
			v = clampf(v * 0.78 + _fbm(lon * 3.0, lat * 6.0, rec.salt + 5) * 0.22, 0.0, 1.0)
			if rec.storm:
				var sd := Vector2((lon - rec.storm_at.x) / rec.storm_r,
					(lat - rec.storm_at.y) / (rec.storm_r * 0.55)).length()
				if sd < 1.0:
					v = lerpf(v, 0.92, 1.0 - sd * sd)
		World.VERDANT:
			# Sea level thresholded out of noise. Two levels, not a gradient:
			# a coastline is the readable part of a habitable world.
			var e := _fbm(lon * rec.relief, lat * rec.relief * 1.4, rec.salt)
			v = (0.18 + 0.10 * e) if e < 0.5 else (0.55 + 0.9 * (e - 0.5))
		World.DESERT:
			v = _fbm(lon * rec.relief * 1.2, lat * rec.relief * 2.2, rec.salt)
			v = clampf(0.35 + v * 0.6 + 0.12 * sin(lat * rec.bands * 0.6), 0.0, 1.0)
		World.CINDER:
			var e2 := _fbm(lon * rec.relief * 1.6, lat * rec.relief * 1.6, rec.salt)
			v = 0.10 + 0.25 * e2
			# Cooling cracks stay dull: the only real warmth in this game is combustion.
			if absf(e2 - 0.5) < 0.035:
				v = 0.96
		_:
			v = clampf(_fbm(lon * rec.relief * 1.5, lat * rec.relief * 1.5, rec.salt) * 0.9 + 0.1, 0.0, 1.0)

	for c in rec.craters:
		var d := Vector2(lon - c.x, lat - c.y).length() / c.z
		if d <= 1.0:
			# Bright rim, dark floor. Two facts about a crater, one test.
			v = 0.86 if d > 0.78 else clampf(v * 0.55, 0.0, 1.0)
	if rec.caps:
		var polar := absf(lat) / 1.5708
		if polar > 0.74 + _noise(lon * 5.0, 2.0, rec.salt + 12) * 0.12:
			v = 1.0

	var base := _ramp(rec.pal, v)
	var lam := clampf(nx * rec.light.x + ny * rec.light.y + nz * rec.light.z, 0.0, 1.0)
	var col := _quantise(base, lam, px, py)

	# Windows on the dark side only, where the eye is not already busy.
	if rec.lit and lam < 0.13 and v > 0.58 and _hash(px * 3, py * 7, rec.salt + 91) < rec.lit_p:
		return UITheme.EMBER.lerp(UITheme.HOT, _hash(px, py, rec.salt + 92)).darkened(0.15)
	# Limb light. A hard bright edge on the sun side is what stops a shaded
	# circle from reading as a flat disc.
	if nx * nx + ny * ny > 0.90 and lam > 0.45:
		col = col.lerp(_star_tint, 0.30)
	return col

## Air, seen edge-on past the limb. Only on the lit side: an atmosphere is not a
## glow, it is sunlight in gas.
func _halo(nx: float, ny: float, rad: float, rec: Recipe) -> Color:
	var lam := clampf(nx * rec.light.x + ny * rec.light.y, 0.0, 1.0)
	if lam <= 0.08:
		return Color(0, 0, 0, 0)
	var fall := clampf(1.0 - (sqrt(rad) - 1.0) / 0.14, 0.0, 1.0)
	var c: Color = (rec.pal[3] as Color).lerp(_star_tint, 0.35)
	c.a = fall * fall * lam * 0.5
	return c

## Dither not alpha: a smooth ramp makes pixel art look resized, so air thins by losing pixels.
func _sieve(px: int, py: int, keep: float) -> bool:
	const CELL := [0.06, 0.56, 0.19, 0.69, 0.81, 0.31, 0.94, 0.44,
		0.25, 0.75, 0.13, 0.63, 1.00, 0.50, 0.88, 0.38]
	return keep > float(CELL[(py & 3) * 4 + (px & 3)])

func _moon_px(mx: float, my: float, rec: Recipe) -> Color:
	var mz := sqrt(maxf(0.0, 1.0 - mx * mx - my * my))
	var v := _fbm(mx * 4.0, my * 4.0, rec.salt + 400)
	var base := Color(0.44, 0.46, 0.5).lerp(Color(0.62, 0.63, 0.66), v)
	var lam := clampf(mx * rec.light.x + my * rec.light.y + mz * rec.light.z, 0.0, 1.0)
	return _quantise(base, lam, int(mx * 40.0), int(my * 40.0))

## Five bands with a 2x2 dither over the joins, as five hard bands read as rings.
func _quantise(base: Color, lam: float, px: int, py: int) -> Color:
	const BAYER := [0.0, 0.5, 0.75, 0.25]
	var b: float = BAYER[(py & 1) * 2 + (px & 1)]
	var step := clampi(int(pow(lam, 0.75) * 5.0 + b * 0.9), 0, 4)
	var out := base
	match step:
		0: out = base.darkened(0.86)
		1: out = base.darkened(0.62)
		2: out = base.darkened(0.34)
		3: out = base
		_: out = base.lightened(0.16)
	# Cold light, warm ship: mixing to the void keeps the backdrop behind without an alpha.
	out = out.lerp(UITheme.VOID, 0.35 if step > 1 else 0.5)
	return out

## Five shades from one hue: the ramp a pixel artist would mix by hand, only
## rolled. Ordered dark to light, so _ramp() can index it with a surface value.
func _palette(cls: int, r: RandomNumberGenerator) -> Array:
	var row: Array = HUES[cls]
	var hue: float = fposmod(float(row[0]) + r.randf_range(-float(row[1]), float(row[1])), 1.0)
	var sat: float = clampf(float(row[2]) * r.randf_range(0.75, 1.25), 0.05, 0.75)
	var val: float = clampf(float(row[3]) * r.randf_range(0.85, 1.15), 0.12, 0.9)
	var out: Array = []
	for i in 5:
		var t := float(i) / 4.0
		# Shadows shift blue and highlights toward the hue, so the ramp looks mixed, not computed.
		out.append(Color.from_hsv(
			fposmod(hue + (0.06 * (1.0 - t)) * (1.0 if hue < 0.5 else -1.0), 1.0),
			clampf(sat * (1.25 - 0.45 * t), 0.0, 1.0),
			clampf(val * (0.45 + 0.75 * t), 0.0, 1.0)))
	return out

func _ramp(pal: Array, v: float) -> Color:
	return pal[clampi(int(clampf(v, 0.0, 0.999) * 5.0), 0, 4)] as Color

# -------------------------------------------------------------------- painting

func _draw() -> void:
	if size.x < 8.0 or size.y < 8.0:
		return
	# Reseeded each frame: cheaper than caching a few hundred positions, and resize reflows.
	var r := RandomNumberGenerator.new()
	r.seed = _seed
	_stars(r)
	if _has_sun:
		_far_sun(r)
	match _kind:
		Kind.PLANET, Kind.GIANT:
			_paint_body()
		Kind.ASTEROIDS:
			_asteroids(r)
		Kind.STAR:
			_near_star(r)
		Kind.FLEET:
			_fleet(r)
		Kind.CORE:
			_core(r)
		_:
			# Deep space is not nothing: it is the one place far enough from
			# everything that you can see other galaxies.
			if (_seed >> 9) % 3 == 0:
				_far_galaxy(r)

## Three layers at three depths. One layer of dots is static; three with
## different sizes and brightnesses is distance.
func _stars(r: RandomNumberGenerator) -> void:
	var n := int(size.x * size.y / 760.0 * _density)
	for i in n:
		var x := floorf(r.randf() * size.x)
		var y := floorf(r.randf() * size.y)
		var t := r.randf()
		var c: Color
		var w := 1.0
		if t < 0.72:
			c = Color("#232d39")
		elif t < 0.94:
			c = Color("#4d5f73")
		else:
			# Near layer only: a blue-white star reads nearer, but tinting all tints the screen.
			c = _star_tint if r.randf() < 0.5 else Color("#9fc0e0")
			w = 2.0
		draw_rect(Rect2(Vector2(x, y), Vector2(w, w)), c, true)

## The system's own star, small and far, on the side the light comes from. It is
## the reason every shadow in the sector points the way it does.
func _far_sun(r: RandomNumberGenerator) -> void:
	# Plus, not minus: `_light` points at the star, and wrong lit every world from the far side.
	# Why: docs/why/SpaceBackdrop.md#light-direction
	var at := size * 0.5 + _light * Vector2(size.x * 0.46, size.y * 0.44)
	var glow := _star_tint
	for i in range(7, 1, -1):
		var a := 0.030 * float(8 - i)
		draw_rect(Rect2(at - Vector2(i, i) * 1.4, Vector2(i, i) * 2.8),
			Color(glow.r, glow.g, glow.b, a), true)
	draw_rect(Rect2(at - Vector2(6, 0), Vector2(12, 1)), Color(glow.r, glow.g, glow.b, 0.35), true)
	draw_rect(Rect2(at - Vector2(0, 6), Vector2(1, 12)), Color(glow.r, glow.g, glow.b, 0.35), true)
	draw_rect(Rect2(at - Vector2(1.5, 1.5), Vector2(3, 3)), Color("#e8f4ff"), true)

func _paint_body() -> void:
	if _body == null:
		return
	var dim := Vector2(_body.get_width(), _body.get_height()) * float(_body_px)
	var at := (size * _body_at - dim * 0.5).floor()
	if frame_in.has_area():
		at.x = floorf(frame_in.get_center().x - dim.x * 0.5)
		if _disc_r * 2.0 <= frame_in.size.y * 0.8:
			at.y = floorf(frame_in.get_center().y - dim.y * 0.5)
		else:
			at.y = floorf(frame_in.position.y + frame_in.size.y * 0.4) - _disc_top
	draw_texture_rect(_body, Rect2(at, dim), false)

## A belt has a direction that reads as an orbit; near rocks sit at the edges, off the middle.
## Why: docs/why/SpaceBackdrop.md#asteroids
func _asteroids(r: RandomNumberGenerator) -> void:
	var lane := r.randf_range(0.25, 0.75)
	var slope := r.randf_range(-0.5, 0.5)
	var spread := r.randf_range(0.22, 0.4)
	for i in int(190.0 * _density):
		var x := r.randf() * size.x
		var y := _belt(x, lane, slope, spread, r)
		if y < 0.0 or y >= size.y:
			continue
		draw_rect(Rect2(Vector2(floorf(x), floorf(y)), Vector2.ONE),
			Color("#39485a") if r.randf() < 0.3 else Color("#28323f"), true)
	for i in 34:
		var x2 := r.randf() * size.x
		var y2 := _belt(x2, lane, slope, spread, r)
		if y2 < 0.0 or y2 >= size.y:
			continue
		_rock(Vector2(x2, y2), r.randf_range(3.0, 9.0), 0.5, r)
	for i in 7:
		var edge: float = r.randf_range(-0.02, 0.14) if r.randf() < 0.5 else r.randf_range(0.86, 1.02)
		_rock(Vector2(edge * size.x, r.randf() * size.y), r.randf_range(12.0, 26.0), 1.0, r)

## A normal spread off the belt, as rocks far off the plane are the rare ones.
func _belt(x: float, lane: float, slope: float, spread: float,
		r: RandomNumberGenerator) -> float:
	return size.y * (lane + (x / size.x - 0.5) * slope) + r.randfn(0.0, size.y * spread)

## Rows of different widths, none centred: a circle reads as a ball and a planet.
func _rock(at: Vector2, rad: float, near: float, r: RandomNumberGenerator) -> void:
	var lit: Color = _dust.lerp(Color("#93a3b6"), 0.30 + 0.35 * near).lerp(UITheme.VOID, 0.30)
	var mid := lit.darkened(0.34)
	var dark := lit.darkened(0.66)
	var rows := int(maxf(3.0, rad * 1.4))
	var skew := r.randf_range(-0.35, 0.35)
	var up: bool = _light.y < 0.0
	for j in rows:
		var t := float(j) / float(rows)
		# Widest above the middle rather than at it. A lopsided silhouette is
		# what stops a field of these reading as a tray of eggs.
		var bulge := sin(pow(t, 0.8) * PI)
		var w := maxf(1.0, rad * (0.45 + 0.75 * bulge) * r.randf_range(0.7, 1.2))
		var x := at.x - w * 0.5 + skew * rad * (t - 0.5) * 2.0
		var y := at.y - rad * 0.7 + float(j)
		var lam: float = (1.0 - t) if up else t
		var c: Color = dark
		if lam > 0.62:
			c = lit
		elif lam > 0.3:
			c = mid
		draw_rect(Rect2(Vector2(floorf(x), floorf(y)), Vector2(floorf(w), 1.0)), c, true)
		# The sunward edge of a near rock catches a hard highlight, the same two
		# planes the hulls are lit with. Not worth the pixels further out.
		if near > 0.8 and lam > 0.55:
			var ex: float = x if _light.x < 0.0 else x + w - 1.0
			draw_rect(Rect2(Vector2(floorf(ex), floorf(y)), Vector2.ONE),
				lit.lightened(0.3), true)


## A star close enough to be a disc. Spectral class picks the colour, which is
## why the whole sector's light changes with it.
func _near_star(r: RandomNumberGenerator) -> void:
	var core := _star_tint
	var edge := _star_edge
	var at := size * Vector2(r.randf_range(0.62, 0.95), r.randf_range(0.12, 0.4))
	var rad := size.y * r.randf_range(0.10, 0.17)
	# Dithered rings out from the disc. Alpha alone gives a smooth ball of fog;
	# dropping every other pixel on the outer rings keeps it pixel art.
	for ring in range(10, 0, -1):
		var t := float(ring) / 10.0
		var rr := rad * (1.0 + t * 2.2)
		var a := (1.0 - t) * 0.09
		var steps := int(rr * 3.0)
		for sp in steps:
			if (sp + ring) % 2 == 0 and t > 0.4:
				continue
			var ang := float(sp) / float(steps) * TAU
			draw_rect(Rect2((at + Vector2(cos(ang), sin(ang)) * rr).floor(),
				Vector2(2, 2)), Color(edge.r, edge.g, edge.b, a), true)
	for j in int(rad * 2.0):
		var y := -rad + float(j)
		var half := sqrt(maxf(0.0, rad * rad - y * y))
		var c: Color = core if absf(y) < rad * 0.6 else core.lerp(edge, 0.5)
		draw_rect(Rect2(Vector2(at.x - half, at.y + y).floor(),
			Vector2(half * 2.0, 1.0)), c, true)


## Silhouettes far away; running lights take the holder's mark colour, its only sector-wide use.
func _fleet(r: RandomNumberGenerator) -> void:
	var lane := r.randf_range(0.16, 0.34) if r.randf() < 0.5 else r.randf_range(0.66, 0.86)
	var n := r.randi_range(4, 8)
	for i in n:
		var depth := r.randf()
		var w := lerpf(7.0, 26.0, depth * depth)
		var at := Vector2(size.x * r.randf_range(0.06, 0.94),
			size.y * (lane + r.randf_range(-0.09, 0.09)))
		_hull_silhouette(at, w, depth, r)
	# Something big, once, behind the rest. A formation with nothing to escort
	# is a formation of strays.
	if r.randf() < 0.6:
		_hull_silhouette(Vector2(size.x * r.randf_range(0.3, 0.8),
			size.y * (lane + r.randf_range(-0.04, 0.04))), r.randf_range(34.0, 58.0), 1.0, r)

func _hull_silhouette(at: Vector2, w: float, depth: float, r: RandomNumberGenerator) -> void:
	var h: float = maxf(2.0, w * r.randf_range(0.16, 0.26))
	var plate: Color = Color("#1b2634").lerp(Color("#3a4a5e"), depth * 0.7)
	draw_rect(Rect2(at.floor(), Vector2(floorf(w), floorf(h))), plate, true)
	draw_rect(Rect2(at.floor(), Vector2(floorf(w), 1.0)), plate.lightened(0.22), true)
	# Nose right like your own ship, tapered in two steps: a plain bar is a bar.
	var nose := maxf(2.0, w * 0.22)
	draw_rect(Rect2((at + Vector2(w, 0.0)).floor(),
		Vector2(floorf(nose * 0.6), floorf(h))), plate, true)
	draw_rect(Rect2((at + Vector2(w + nose * 0.6, maxf(1.0, h * 0.25))).floor(),
		Vector2(floorf(nose * 0.5), maxf(1.0, floorf(h * 0.5)))), plate, true)
	if w > 10.0:
		# A spine, or a tower. Whatever it is, it breaks the top line.
		draw_rect(Rect2((at + Vector2(w * 0.5, -1.0)).floor(),
			Vector2(maxf(2.0, w * 0.22), 1.0)), plate.lightened(0.1), true)
		draw_rect(Rect2((at + Vector2(w * 0.12, h)).floor(),
			Vector2(maxf(2.0, w * 0.3), 1.0)), plate.darkened(0.4), true)
	# One running light, in the holding manufacturer's mark colour.
	draw_rect(Rect2((at + Vector2(w * 0.2, h * 0.5)).floor(), Vector2(1, 1)), _accent, true)
	# Engines, cold and blue at this distance.
	draw_rect(Rect2((at - Vector2(2.0, -h * 0.35)).floor(), Vector2(2, 1)),
		Color("#5f8fb0"), true)


## One line for stars, glow and lanes; dithered rows, as a translucent rect reads as a UI panel.
## Why: docs/why/SpaceBackdrop.md#galactic-core
func _core(r: RandomNumberGenerator) -> void:
	var mid := size.y * r.randf_range(0.35, 0.6)
	var slope := r.randf_range(-0.18, 0.18)
	var thick := size.y * r.randf_range(0.16, 0.24)
	var haze := UITheme.EMBER.lerp(Color("#5f6f9a"), 0.45)
	for x in int(size.x):
		var band := mid + (float(x) - size.x * 0.5) * slope
		for j in int(thick * 2.0):
			var y := band - thick + float(j)
			if y < 0.0 or y >= size.y:
				continue
			var d := absf(y - band) / thick
			var glow := (1.0 - d * d) * 0.55
			if _sieve(x, int(y), glow):
				draw_rect(Rect2(Vector2(float(x), floorf(y)), Vector2.ONE),
					Color(haze.r, haze.g, haze.b, 0.14 + 0.22 * glow), true)
	for i in int(size.x * size.y / 90.0):
		var sx := r.randf() * size.x
		var sband := mid + (sx - size.x * 0.5) * slope
		var sy := sband + r.randfn(0.0, thick * 0.8)
		if sy < 0.0 or sy >= size.y:
			continue
		var c := Color("#8fa3ba") if r.randf() < 0.22 else Color("#3b4a5c")
		draw_rect(Rect2(Vector2(floorf(sx), floorf(sy)), Vector2.ONE), c, true)
	# Dust: along the band rather than across the frame, and broken into runs.
	# An unbroken line is a scratch on the lens.
	for i in r.randi_range(2, 4):
		var off := r.randf_range(-thick * 0.8, thick * 0.8)
		var h := r.randf_range(1.0, 4.0)
		var x2 := 0.0
		while x2 < size.x:
			var run := r.randf_range(20.0, 90.0)
			if r.randf() < 0.75:
				var y2 := mid + (x2 - size.x * 0.5) * slope + off + r.randf_range(-2.0, 2.0)
				draw_rect(Rect2(Vector2(floorf(x2), floorf(y2)), Vector2(run, h)),
					Color(0.03, 0.04, 0.06, 0.6), true)
			x2 += run + r.randf_range(4.0, 30.0)


## Another galaxy, seen from outside it. Small, tilted and rare — it is the
## thing that says the empty sector is empty because it is far from everything.
func _far_galaxy(r: RandomNumberGenerator) -> void:
	var at := size * Vector2(r.randf_range(0.55, 0.9), r.randf_range(0.15, 0.8))
	var rad := size.y * r.randf_range(0.05, 0.09)
	var tilt := r.randf_range(0.2, 0.45)
	var turn := r.randf_range(0.0, PI)
	for i in 240:
		var t := r.randf()
		var ang := t * TAU * 1.6 + turn
		var d := rad * t * r.randf_range(0.7, 1.15)
		var p := Vector2(cos(ang) * d, sin(ang) * d * tilt).rotated(turn * 0.3)
		var a: float = 0.5 - 0.35 * t
		draw_rect(Rect2((at + p).floor(), Vector2.ONE),
			Color(0.64, 0.71, 0.82, a), true)
	draw_rect(Rect2((at - Vector2(1, 1)).floor(), Vector2(2, 2)),
		Color(0.85, 0.88, 0.95, 0.6), true)

# ----------------------------------------------------------------------- noise

## Hashed not stored: every texture must answer the same per pixel on each redraw.
func _hash(x: int, y: int, salt: int) -> float:
	var h := (x * 374761393 + y * 668265263 + salt * 1442695) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float((h ^ (h >> 16)) & 0xffff) / 65535.0

## Value noise, not gradient: at planet sizes the difference is invisible and it is half the maths.
func _noise(x: float, y: float, salt: int) -> float:
	var xi := int(floorf(x))
	var yi := int(floorf(y))
	var xf := x - float(xi)
	var yf := y - float(yi)
	var u := xf * xf * (3.0 - 2.0 * xf)
	var v := yf * yf * (3.0 - 2.0 * yf)
	return lerpf(
		lerpf(_hash(xi, yi, salt), _hash(xi + 1, yi, salt), u),
		lerpf(_hash(xi, yi + 1, salt), _hash(xi + 1, yi + 1, salt), u), v)

## Three octaves. Two looks like blobs and four costs a third more for detail
## that is smaller than the pixel it lands in.
func _fbm(x: float, y: float, salt: int) -> float:
	var sum := 0.0
	var amp := 0.5
	var freq := 1.0
	for o in 3:
		sum += _noise(x * freq, y * freq, salt + o * 17) * amp
		amp *= 0.5
		freq *= 2.1
	return clampf(sum / 0.875, 0.0, 1.0)
