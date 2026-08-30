class_name SpaceBackdrop
extends Control

## What is out there, behind the fight.
##
## The void is never flat black — but until this existed every sector WAS the
## same black with a different wash over it, so a shipyard in a capital and a
## beacon at the edge of nothing looked like the same place. This paints one
## large body per system, and a starfield whose density and colour follow the
## same seed.
##
## Two rules hold the whole file together.
##
## **It follows from the place.** A station orbits something, so a station
## sector has a planet in it. A beacon is put where there is nothing to put it
## near, so an event sector is empty sky. Derelicts drift where the rocks are,
## fauna follow the gas giants, and a fleet is only ever in space somebody
## holds. Nothing is rolled freely: the roll picks between the things that are
## true of that node, and the node's own axes — development, security, berths —
## decide which list it rolls on. That is what makes the sky readable. If you
## have learned that lit cities mean a settled world, an unlit one means
## something.
##
## **It is fixed for the run.** Everything derives from the node index, so a
## system has the same sky every time you fly back to it and none of it is
## saved. The planet texture is baked once into an Image on arrival; the rest is
## a few hundred rectangles regenerated from the seed each redraw, which is why
## nothing here is stored in an array.
##
## It draws between the wash and the nebula gas, never over the ship, and it is
## deliberately dim — this is depth, not subject matter. A planet you notice
## more than the thing shooting at you is a bug, so every surface colour is
## pulled toward VOID before it is written.

## What the sky is built around. One per sector, and DEEP is a real answer
## rather than a fallback: empty sky is what most of space looks like, and it is
## what makes the sectors that do have something in them land.
enum Kind { DEEP, PLANET, GIANT, ASTEROIDS, STAR, FLEET, CORE }

## How a world is surfaced. Class picks the palette AND the texture function
## together, because the two are not independent — an ice cap on a gas giant or
## bands on a cratered rock reads as a mistake, not as variety.
enum World { ROCK, DESERT, ICE, VERDANT, CINDER, BANDED }

## Palette anchors, in hue-sat-val, one row per world class:
## [hue, hue jitter, saturation, value]. Not UITheme constants, because a planet
## is the one thing in the game that is supposed to have a colour nobody chose —
## the theme's job is to keep the interface coherent, and this is sky. What
## keeps it in the game's register is the last step of _surface(): everything is
## mixed toward VOID and lit cold.
const HUES := {
	World.ROCK:    [0.07, 0.05, 0.18, 0.52],
	World.DESERT:  [0.09, 0.04, 0.42, 0.62],
	World.ICE:     [0.55, 0.08, 0.20, 0.80],
	World.VERDANT: [0.42, 0.14, 0.36, 0.50],
	World.CINDER:  [0.03, 0.03, 0.30, 0.26],
	World.BANDED:  [0.00, 1.00, 0.34, 0.58],  ## hue rolled free; giants are anything
}

## One world's recipe, rolled once and then read for every pixel of the disc.
## A held object rather than a sixteen-argument call: _surface() runs tens of
## thousands of times per world, so the values have to be gathered once, and a
## parameter list that long is unreadable and silently easy to mis-order.
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
## Where the system's own star sits, as a unit vector. The planet's terminator,
## the lit face of every asteroid and the far sun itself all read from this, so
## the light in a sector comes from one place.
var _light: Vector2 = Vector2(-0.6, -0.5)
## The system's star, in two colours: the core and the cooler edge of the
## disc. Chosen on arrival rather than while drawing, because the planet's limb
## light is baked from it and the near stars are tinted with it — the same
## light cannot be decided twice.
var _star_tint: Color = Color("#c8dcf0")
var _star_edge: Color = Color("#6f9fc8")
var _dust: Color = Color("#41505f")
var _accent: Color = Color("#8fa3ba")
var _density: float = 1.0
var _has_sun: bool = true

# The baked world. Rings and moon are baked into the same image so the ring
# passes behind the planet at the top and in front of it at the bottom without
# any draw ordering at all.
var _body: ImageTexture
var _body_px: int = 3     ## integer upscale; pixel art is never scaled by a fraction
var _body_at: Vector2 = Vector2(0.5, 0.5)   ## centre, as a fraction of the view
## The system whose sky this is, and the view height its world was baked for.
##
## Both exist because of when setup() is called. The sector screen tells this
## control where you are while it is still building itself, and a Control has no
## size until the layout pass at the end of the frame — so a world baked inside
## setup() is sized against a height of zero. The bake waits for a size instead,
## and runs again if the view ever changes height enough to matter.
var _node: MapGen.MapNode = null
var _baked_h: float = 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

## Called on every refresh, so the early-out is load-bearing: baking a world is
## a few tens of thousands of pixels of noise and it must happen on arrival, not
## on every card you play.
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
	var spectral := r.randf()
	if spectral > 0.75:
		_star_tint = Color("#ffffff")
		_star_edge = Color("#8fb4d6")
	elif spectral > 0.40:
		_star_tint = Color("#f6f2e4")
		_star_edge = Color("#b2a486")
	else:
		_star_tint = Color("#dff0ff")
		_star_edge = Color("#6f9fc8")
	_dust = MapGen.star_colour(n)
	_accent = _dust
	if n.manufacturer != &"":
		_accent = DB.manufacturer_colour(n.manufacturer)
	_kind = _pick(n, r)
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

## Bakes the world once there is a view to size it against, and re-bakes it if
## the view has since changed height by more than a quarter. Cheap to call: it
## is a comparison and a return in every case but the two that matter.
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

## What is in this sector, decided by what the sector IS.
##
## The node type answers first because it is the strongest statement the map
## makes, and only the cases the type leaves open get rolled.
func _pick(n: MapGen.MapNode, r: RandomNumberGenerator) -> int:
	match n.type:
		MapGen.NodeType.STATION:
			# A station is built where there is something to service, hold or
			# mine. It never floats in nothing — that is the whole reason this
			# case is not a roll.
			return Kind.GIANT if n.fauna or r.randf() < 0.18 else Kind.PLANET
		MapGen.NodeType.SYSTEM:
			# An ordinary system, and it gets the variety the three types it
			# replaced used to supply between them: mostly rocks, because that is
			# where the traffic goes, sometimes a world, sometimes empty sky.
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

## FIGHT, and anything the map adds later: the axes decide.
##
## One roll per question, not one roll re-read. A single number tested against
## 0.42 and then against 0.55 is not two independent chances — passing the first
## test has already eaten most of the range the second one needed, and the
## weights stop meaning what they say.
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

## Which world hangs in this system. Development is the tell that matters: a
## capital is a world somebody terraformed or an ore body somebody stripped, and
## unclaimed space is rock and ice because nothing else pays to be there.
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

## Bakes the planet, its rings and its moon into one texture.
##
## Baked rather than drawn, for two reasons that both matter. A lit sphere is
## per-pixel work — normal, terminator, dithered ramp — and doing that in _draw
## would redo it every time a card moves. And an Image lets the ring occlude the
## planet at the top and the planet occlude the ring at the bottom by writing
## pixels in order, which draw calls cannot do without splitting the ring in
## half and hoping the seam lands somewhere invisible.
func _bake_world(n: MapGen.MapNode) -> void:
	# Its own stream, salted off the same seed. Rolling the world from the same
	# generator setup() used would mean the world changed whenever anything
	# above it drew one more number, and the bake no longer happens in that
	# function anyway.
	var r := RandomNumberGenerator.new()
	r.seed = _seed ^ 0x5bf03635
	var cls := _world_class(n, r)

	# Composition, in four shots, and `frac` is the RADIUS as a fraction of the
	# view's height — so 0.6 is a body wider than the frame with its centre off
	# the bottom edge, and 0.08 is a dot. Reading it as a diameter is how the
	# first pass ended up with corner accents three hundred pixels across.
	#
	# A limb rising out of the bottom edge is the shot that reads as "in orbit",
	# so stations get it most of the time and everything else is further away.
	# The top-left is never used: the sector readout is written there, and text
	# over a planet is text you cannot read.
	var shot := r.randf()
	var big: bool = n.type == MapGen.NodeType.STATION
	var frac: float
	if big and shot < 0.62:
		# Right of centre and low. The dock is drawn in the right half of the
		# frame and your hull sits in the left, so a world under the station
		# says the station orbits something AND stays off the ship.
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

	# Source resolution follows the size it will be drawn at, so a world is
	# about three screen pixels to the source pixel whether it fills the frame
	# or sits in a corner. Fixing the source instead would make big worlds mush
	# and small ones needlessly expensive.
	#
	# The ceiling is measured, not guessed. A lit sphere costs about five
	# microseconds a pixel in GDScript, so radius 64 is roughly 95 ms of bake
	# and radius 78 is 140 — one frame you do not notice on arrival against
	# eight you do. Past that a world grows by drawing its pixels bigger.
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
	# Lit windows are the one warm thing allowed out here, and only where people
	# are: a night side with cities on it is the difference between a world
	# somebody lives on and a rock with the same albedo.
	rec.lit = cls != World.BANDED and n.development >= MapGen.Development.SETTLEMENT
	# Sparse. A window is one lit pixel among many dark ones — at anything like
	# a realistic density the night side turns into a spray of orange sparks
	# that reads as damage, which is the one thing the warm end of this palette
	# is reserved for.
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
	# Longitude and latitude of the point, so the texture wraps around a ball
	# instead of being painted on a disc. It is what makes the detail crowd
	# toward the limb, which is the only cue that says "sphere" for free.
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
			# Cooling cracks. Kept dull and thin on purpose — the only real
			# warmth in this game is combustion, and a lava world that glows
			# competes with your own reactor.
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

	# Windows, on the dark side only. They are hidden by daylight in reality and
	# on screen, and putting them where the eye is not already busy is what
	# makes them worth drawing.
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

## Ordered dither over a 4x4 cell: true if this pixel survives at that strength.
##
## A smooth alpha ramp is the one thing that makes a pixel-art scene look like
## it was resized from something else. Air has to thin out by losing pixels, not
## by fading, and so does the haze around the galactic core.
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

## The light ramp, in five steps with a 2x2 ordered dither across the joins.
##
## Quantised because pixel art shades in bands, and dithered because five hard
## bands on a sphere the size of the frame is five visible rings. This is the
## same trick ShipView.dither() uses for the hull.
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
	# Cold light, warm ship. Everything out here is lit by a star and mixed
	# toward the void, which is what keeps the backdrop behind the subject
	# without having to dim it with an alpha.
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
		# Shadows shift toward blue and highlights toward the hue's own side —
		# the cheapest way to make a five-step ramp look mixed rather than
		# computed from one colour and a brightness slider.
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
	# Reseeded every frame rather than cached in arrays. A few hundred hashed
	# positions cost less than the memory churn of keeping them, and it means a
	# resize reflows the sky instead of stretching it.
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
			# The near layer only. Colour lives here because a blue-white star
			# among grey ones reads as a nearer star, and the same pixel spread
			# across every star reads as a tinted screen.
			c = _star_tint if r.randf() < 0.5 else Color("#9fc0e0")
			w = 2.0
		draw_rect(Rect2(Vector2(x, y), Vector2(w, w)), c, true)

## The system's own star, small and far, on the side the light comes from. It is
## the reason every shadow in the sector points the way it does.
func _far_sun(r: RandomNumberGenerator) -> void:
	# Plus, not minus: _light points at the star, so the star is that way. The
	# sign matters more than it looks — with it wrong, every world in the game
	# was lit from the opposite side of the frame to its own sun.
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
	draw_texture_rect(_body, Rect2(at, dim), false)

## Rock, in three depths, along a belt rather than scattered evenly. A field
## with a direction reads as an orbit you are crossing; the same rocks spread
## uniformly read as noise.
##
## The near rocks are pushed to the edges deliberately: a boulder across the
## middle of the frame sits between you and what you are shooting at, and the
## backdrop does not get to do that.
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

## A position on the belt: along it, and then off it by an amount that falls
## away. A normal spread rather than a flat one, because a belt has a plane and
## the rocks far off that plane are the rare ones.
func _belt(x: float, lane: float, slope: float, spread: float,
		r: RandomNumberGenerator) -> float:
	return size.y * (lane + (x / size.x - 0.5) * slope) + r.randfn(0.0, size.y * spread)

## One rock: a stack of rows of different widths, none of them centred, because
## a circle reads as a ball and a ball reads as a planet. Three tones, lit from
## the same star as everything else in frame.
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


## Somebody else's ships, far enough away to be silhouettes. Running lights take
## the holding manufacturer's mark colour, which is the only place its colour is
## allowed to describe a whole sector.
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
	# Nose right, the same way your own ship faces. A formation pointing the
	# other way looks like it is running out of frame.
	#
	# Tapered in two steps rather than squared off, because at this size the
	# silhouette is the only thing carrying "ship" — a plain bar is a bar.
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


## The core of the galaxy, from inside the disc: stars too dense to resolve,
## the haze they add up to, and the dust that cuts across it. The one place in
## the game where the sky is bright.
##
## Everything here follows one line — same centre, same slope — so the stars,
## the glow and the lanes read as one object seen edge-on. The glow is dithered
## rows rather than filled rectangles, because a rectangle of translucent
## colour over a starfield is a user-interface panel whatever colour it is.
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

## Hashed, not stored. Every texture in this file has to give the same answer
## for the same pixel on every redraw, and a hash is how that happens without
## keeping a single array alive between frames.
func _hash(x: int, y: int, salt: int) -> float:
	var h := (x * 374761393 + y * 668265263 + salt * 1442695) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float((h ^ (h >> 16)) & 0xffff) / 65535.0

## Value noise: hashed lattice, smoothstepped between. Not gradient noise —
## at the sizes a planet is drawn here the difference is invisible and this is
## half the arithmetic.
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
