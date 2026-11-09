class_name NebulaField
extends RefCounted

## Placement only, shared by the chart and sector screen so both agree where the gas is.
## Why: docs/why/NebulaField.md#cloud-placement

## Clouds sit on arms where there are arms: gas piles up and stars are born there.
const R_MIN := 0.22
const R_SPAN := 0.68

## One number for membership, hover and outline, which once disagreed.
## Set where the gas stops, about six tenths of each lobe.
## Why: docs/why/NebulaField.md#cloud-extent
const EXTENT := 0.62

## Five kinds are five objects: what lights them sets their size, hollowness and light.
enum Kind {
	EMISSION,    ## gas lit from inside by the stars forming in it
	REFLECTION,  ## gas lit from outside; it only catches what is already there
	PLANETARY,   ## a dying star's shed envelope: small, hollow, sharply lit
	REMNANT,     ## a supernova's expanding shell: hollow, filamentary, wide
	DARK,        ## a cloud that emits nothing and hides what is behind it
}

## Planetaries follow how the star died: torus, hourglass or knots. Only quiet ones are round.
## Why: docs/why/NebulaField.md#planetary-shapes
enum Shape {
	RING,        ## a torus seen near face-on, the classic
	ELLIPTICAL,  ## the same thing tipped well over
	BIPOLAR,     ## pinched at the waist, drawn out along the axis
	ANSAE,       ## a ring with a jet knot either side
}

class Cloud extends RefCounted:
	var pos: Vector2 = Vector2.ZERO
	var radius: float = 0.0
	var kind: Kind = Kind.REFLECTION
	## Shells (planetary, remnant) are hollow; drawing them solid is the wrong object.
	var hollow: float = 0.0

	## Kept because a good deal of code only wants to know whether the thing
	## makes its own light.
	var emission: bool:
		get:
			return kind == Kind.EMISSION or kind == Kind.PLANETARY \
				or kind == Kind.REMNANT

	func label() -> String:
		match kind:
			Kind.EMISSION: return "EMISSION NEBULA"
			Kind.PLANETARY: return "PLANETARY NEBULA"
			Kind.REMNANT: return "SUPERNOVA REMNANT"
			Kind.DARK: return "DARK NEBULA"
			_: return "REFLECTION NEBULA"

	## Edge colour is separate: darkening a dark nebula's hole gives an invisible outline.
	func edge_colour() -> Color:
		match kind:
			Kind.DARK: return Color("#6b5f7d")
			# Derived, so a violet planetary does not get a green outline.
			Kind.PLANETARY: return _planetary_hue().darkened(0.42)
			Kind.REMNANT: return Color("#4d7f8c")
			Kind.EMISSION: return Color("#8f4a52")
			_: return Color("#4e6390")

	## The hue each kind pulls toward; a dark cloud is a hole in the light, not a colour.
	func base_colour() -> Color:
		match kind:
			Kind.EMISSION: return Color("#c46a72")
			Kind.PLANETARY: return _planetary_hue()
			Kind.REMNANT: return Color("#6fa8b8")
			Kind.DARK: return Color("#120f18")
			_: return Color("#6a86c4")

	## Planetaries vary by star, so one palette entry made them one object; green keeps most share.
	## Why: docs/why/NebulaField.md#planetary-colour
	func _planetary_hue() -> Color:
		if hue_roll < 0.40:
			return Color("#6fe0ac")   # doubly-ionised oxygen — the classic
		if hue_roll < 0.58:
			return Color("#e0906f")   # nitrogen, in an old wide shell
		if hue_roll < 0.74:
			return Color("#7fb4e8")   # helium, off a very hot core
		if hue_roll < 0.88:
			return Color("#dd7f9c")   # hydrogen rose
		return Color("#a98fe0")       # thin, old, and hot enough to go violet
	## The same name the chart writes across it, so the sector can say where you
	## are and mean the place you were looking at.
	var name: String = ""
	## Colour lean 0 to 1, read only by planetaries, whose colour belongs to the individual object.
	var hue_roll: float = 0.0
	## Which morphology this planetary took. Ignored by every other kind.
	var shape: Shape = Shape.RING
	## Three lobes are the real shape; held here so outline, tooltip and membership share it.
	var lobes: PackedVector2Array = PackedVector2Array()
	var lobe_r: PackedFloat32Array = PackedFloat32Array()

	## `reach` scales the lobes: dense middle for systems, full extent for the cursor.
	func holds(p: Vector2, reach: float) -> bool:
		for i in lobes.size():
			if (p - pos - lobes[i]).length() < lobe_r[i] * reach:
				return true
		return false

## FIT puts clouds in arms because RIDGE hung them off the edge (Jon, Oct 4).
## Measured: Grand-Design clouds inside their arm went from 46% to 87%.
## Why: docs/why/NebulaField.md#arm-fit-placement
enum Placement { RIDGE, FIT }
static var placement := Placement.FIT

## How many places FIT tries for a cloud, all hashed from the run's seed.
const FIT_TRIES := 40
## How much of a cloud FIT wants inside the arm before it stops shrinking it,
## how much smaller each step makes it, and the smallest it may get.
const FIT_INSIDE := 0.75
const FIT_SHRINK := 0.85
const FIT_SMALLEST := 0.4
## Arms stop counting past about 0.7 of the disc, where the chart thins and dims its stars.
const FIT_EDGE := 0.78

static var _cache: Array = []
static var _cache_key := 0

## Worked out once a galaxy: `at()` asks per system and FIT is not free.
static func clouds() -> Array:
	var key := [Run.galaxy_seed, Run.galaxy_spin, Run.galaxy, int(placement), keep_core].hash()
	if key != _cache_key or _cache.is_empty():
		_cache = _build()
		_cache_key = key
	return _cache.duplicate()

static func _build() -> Array:
	var g: Dictionary = Run.galaxy
	var gas: float = float(g.get("gas", 1.0))
	# A galaxy that stopped forming stars gets no clouds: absence makes a lenticular finished.
	var count := clampi(int(round(gas * 4.0)), 0, 9)
	var out: Array = []
	# Whether a remnant has been rolled yet. See below.
	var has_host := false
	if count <= 0:
		return out

	var sq := float(g.get("squash", 0.62))
	var arms := maxi(1, int(g.get("arms", 2)))
	var spiral: bool = int(g.get("arms", 2)) > 0
	# Own stream seeded off the run: the chart's shared stream could not be reproduced elsewhere.
	var rng := (Run.galaxy_seed * 2654435761 + 90210) & 0x7fffffff

	for k in count:
		rng = (rng * 1103515245 + 12345) & 0x7fffffff
		var a1 := float((rng >> 13) % 10000) / 10000.0
		rng = (rng * 1103515245 + 12345) & 0x7fffffff
		var a2 := float((rng >> 13) % 10000) / 10000.0
		rng = (rng * 1103515245 + 12345) & 0x7fffffff
		var a3 := float((rng >> 13) % 10000) / 10000.0
		rng = (rng * 1103515245 + 12345) & 0x7fffffff
		var a4 := float((rng >> 13) % 10000) / 10000.0
		rng = (rng * 1103515245 + 12345) & 0x7fffffff
		# Own roll for kind: sharing `a3` tied kind to arm position, so one edge got the rarest.
		var a5 := float((rng >> 13) % 10000) / 10000.0

		var c := Cloud.new()
		var rn: float = R_MIN + a1 * R_SPAN
		# One cloud sits close in so gas and black hole can meet; they never overlapped before.
		# Why: docs/why/NebulaField.md#core-cloud
		if k == 1:
			rn = 0.05 + a1 * 0.16
		var ang: float = a2 * TAU
		if spiral:
			ang = MapGen.shape_angle(rn, k % arms, (a3 - 0.5) * 0.55)
		c.pos = Vector2(cos(ang), sin(ang) * sq) * rn
		# One landmark per galaxy, plainly bigger: same-sized clouds read as texture.
		c.radius = (0.16 + a4 * 0.08) if k == 0 else (0.06 + a4 * 0.07)
		if k == 1:
			# Big enough to reach well past the hole, so what orbits is a cloud
			# rather than a handful of stray blocks.
			c.radius = 0.13 + a4 * 0.07
		# Armless galaxies skipped FIT's shrink, so their landmark was too big (0.24 vs 0.13).
		# Why: docs/why/NebulaField.md#landmark-size
		if not spiral and k == 0:
			c.radius *= FIT_SHRINK * FIT_SHRINK * FIT_SHRINK
		# Weighted to quiet kinds, but toward planetary and remnant, as a pulsar needs one.
		# Why: docs/why/NebulaField.md#kind-weights
		var roll := a5
		if roll < 0.18:
			c.kind = Kind.REFLECTION
		elif roll < 0.36:
			c.kind = Kind.DARK
		elif roll < 0.54:
			c.kind = Kind.EMISSION
		elif roll < 0.86:
			c.kind = Kind.REMNANT
		else:
			c.kind = Kind.PLANETARY
		# Every star-forming galaxy gets a remnant: 85 of 200 rolled none, so no pulsar could be.
		# Why: docs/why/NebulaField.md#forced-shell
		if c.kind == Kind.REMNANT:
			has_host = true
		elif k == count - 1 and not has_host:
			c.kind = Kind.REMNANT

		match c.kind:
			Kind.PLANETARY:
				# Planetaries stay smallest, but not so small that a system rarely fell inside one.
				# Why: docs/why/NebulaField.md#planetary-size
				c.radius *= 0.72
				c.hollow = 0.62
			Kind.REMNANT:
				# Wide, thin-walled: a shock front still travelling outward.
				c.radius *= 1.25
				c.hollow = 0.48
			Kind.DARK:
				c.radius *= 1.1
		# Own draw: colour is independent of position and size, and the stream stays aligned.
		rng = (rng * 1103515245 + 12345) & 0x7fffffff
		c.hue_roll = float((rng >> 13) % 10000) / 10000.0
		rng = (rng * 1103515245 + 12345) & 0x7fffffff
		var shape_roll := float((rng >> 13) % 10000) / 10000.0
		# Weighted to the round ones, but only just. Bipolars are common in the
		# real catalogue and they are the ones worth looking at.
		if shape_roll < 0.34:
			c.shape = Shape.RING
		elif shape_roll < 0.56:
			c.shape = Shape.ELLIPTICAL
		elif shape_roll < 0.84:
			c.shape = Shape.BIPOLAR
		else:
			c.shape = Shape.ANSAE
		c.name = GalaxyGen.nebula_name((Run.galaxy_seed >> 3) + k * 7919)
		# A shell is one lobe; three offset ones read as three explosions.
		if c.hollow > 0.0:
			c.lobes.append(Vector2.ZERO)
			c.lobe_r.append(c.radius)
		else:
			# Three offset unequal lobes read as a shape, and overlaps glow brighter for free.
			for l in 3:
				rng = (rng * 1103515245 + 12345) & 0x7fffffff
				var b1 := float((rng >> 13) % 10000) / 10000.0
				rng = (rng * 1103515245 + 12345) & 0x7fffffff
				var b2 := float((rng >> 13) % 10000) / 10000.0
				rng = (rng * 1103515245 + 12345) & 0x7fffffff
				var b3 := float((rng >> 13) % 10000) / 10000.0
				c.lobes.append(Vector2((b1 - 0.5) * c.radius * 1.1,
					(b2 - 0.5) * c.radius * 0.8))
				c.lobe_r.append(c.radius * (0.45 + b3 * 0.5))
		# Placed last, once its shape is known; hashed so later clouds roll what they did before.
		if spiral and k != 1 and placement == Placement.FIT:
			_fit(c, k, arms)
		_keep_clear(c, g)
		out.append(c)
	return out


## Clouds stay outside the bulge plus a margin: one over the core was messy (Jon, Oct 5).
## Why: docs/why/NebulaField.md#core-kept-clear
static func core_keep(g: Dictionary) -> float:
	# (2.05: the chart's DISC, `MapChart.DISC`, bulge to plane units)
	return 1.5 * float(g.get("bulge", 0.26)) / 2.05 + 0.04

static var keep_core := true

static func _keep_clear(c: Cloud, g: Dictionary) -> void:
	if not keep_core:
		return
	var sq := maxf(0.05, float(g.get("squash", 0.62)))
	var keep := core_keep(g)
	for _step in 6:
		# the cloud's nearest drawn point to the centre, in the un-tilted disc
		var q0 := Vector2(c.pos.x, c.pos.y / sq)
		var near := INF
		for l in c.lobes.size():
			var lq := Vector2(c.pos.x + c.lobes[l].x, (c.pos.y + c.lobes[l].y) / sq)
			near = minf(near, lq.length() - c.lobe_r[l] * EXTENT)
		if near >= keep:
			return
		var dir := q0.normalized() if q0.length() > 1e-4 else Vector2(1.0, 0.0)
		q0 += dir * (keep - near + 0.005)
		# past the disc's edge it is made smaller instead of pushed further
		if q0.length() > 0.86:
			q0 = dir * 0.86
			c.radius *= FIT_SHRINK
			for l in c.lobes.size():
				c.lobes[l] *= FIT_SHRINK
				c.lobe_r[l] *= FIT_SHRINK
		c.pos = Vector2(q0.x, q0.y * sq)

## A cloud wider than the arm shrinks a step at a time, keeping the biggest the arm can hold.
## Why: docs/why/NebulaField.md#arm-fit-placement
static func _fit(c: Cloud, k: int, arms: int) -> void:
	var scale := 1.0
	while true:
		_fit_place(c, k, arms)
		if arm_share(c) >= FIT_INSIDE or scale * FIT_SHRINK < FIT_SMALLEST - 0.001:
			return
		scale *= FIT_SHRINK
		c.radius *= FIT_SHRINK
		for l in c.lobes.size():
			c.lobes[l] *= FIT_SHRINK
			c.lobe_r[l] *= FIT_SHRINK

## FIT's places: the best of `FIT_TRIES` for the cloud as it now is.
static func _fit_place(c: Cloud, k: int, arms: int) -> void:
	var best := c.pos
	var best_share := arm_share(c)
	var salt := Run.galaxy_seed % 100003
	var sq := float(Run.galaxy.get("squash", 0.62))
	for t in range(1, FIT_TRIES):
		if best_share >= 0.98:
			break
		var f1 := MapGen._frac(MapGen._hash2(k * 977 + t, salt, 4241))
		var f2 := MapGen._frac(MapGen._hash2(k * 977 + t, salt, 4243))
		var rn := R_MIN + f1 * R_SPAN
		# Within the middle half of the arm's band, on any arm.
		var along := (f2 - 0.5) * MapGen.arm_half_width(rn)
		var ang := MapGen.shape_angle(rn, (k + t) % arms, along)
		c.pos = Vector2(cos(ang), sin(ang) * sq) * rn
		var share := arm_share(c)
		if share > best_share + 0.001:
			best_share = share
			best = c.pos
	c.pos = best

## Share of a cloud's drawn lobes inside the chart's arm band, 0 to 1; 1.0 with no arms.
static func arm_share(c: Cloud) -> float:
	var g: Dictionary = Run.galaxy
	var arms := int(g.get("arms", 0))
	if arms <= 0:
		return 1.0
	var sq := maxf(0.05, float(g.get("squash", 0.62)))
	var inside := 0
	var total := 0
	for l in c.lobes.size():
		var big_r := c.lobe_r[l] * EXTENT
		var h := c.hollow
		for i in 4:
			var rr := big_r * sqrt(h * h + (1.0 - h * h) * (float(i) + 0.5) / 4.0)
			var n_ang := 4 + i * 4
			for j in n_ang:
				var th := (float(j) + 0.5 * float(i % 2)) * TAU / float(n_ang)
				var p := c.pos + c.lobes[l] + Vector2(cos(th), sin(th)) * rr
				var q := Vector2(p.x, p.y / sq)
				var rn := q.length()
				total += 1
				if rn > FIT_EDGE:
					continue
				var a := atan2(q.y, q.x)
				var hw := MapGen.arm_half_width(rn)
				for arm in arms:
					if absf(wrapf(MapGen.shape_angle(rn, arm, 0.0) - a, -PI, PI)) <= hw:
						inside += 1
						break
	return float(inside) / float(maxi(1, total))

## Which cloud a point sits inside, or null. Uses the drawn ellipse, since that
## is the shape both the chart and the player see.
static func at(p: Vector2, reach: float = EXTENT) -> Cloud:
	var best: Cloud = null
	var closest := INF
	for c in clouds():
		var cl: Cloud = c
		var d := (p - cl.pos).length()
		# Test against the lobes with `reach`: a disc test fired tooltips over empty sky.
		# Why: docs/why/NebulaField.md#cloud-membership
		if cl.holds(p, reach) and d < closest:
			closest = d
			best = cl
	return best
