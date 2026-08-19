class_name NebulaField
extends RefCounted

## Where the galaxy's gas clouds are.
##
## Placement only — how a cloud is DRAWN stays in the chart, which has a great
## deal of machinery for it. This exists because two different parts of the game
## need to agree about where the gas is: the chart draws it, and the sector
## screen has to know whether the system you are standing in is sitting inside
## one. Deriving that twice from the same seed would work right up until someone
## adjusted one copy.
##
## Everything here is in NORMALISED galaxy units — the same space MapGen.gal
## uses, where 1.0 is the disc radius — so a cloud and a system can be compared
## without either knowing how big the chart happens to be drawn.

## Cloud centres sit between these radii, and a cloud is placed on an arm where
## the galaxy has arms: star formation happens where the density wave piles the
## gas up, so a cloud floating between the arms would be a cloud in the one
## place nothing is being born.
const R_MIN := 0.22
const R_SPAN := 0.68

## How much of a lobe counts as the cloud.
##
## ONE number, used by everything: whether a system is in the gas, whether the
## cursor is over it, and where the boundary is drawn. They were separate — the
## outline took the whole lobe while membership took the dense middle — so the
## chart drew a ring around systems that the panel then said were not in a
## nebula. Any answer is defensible; three different answers are not.
##
## Set where the gas actually stops: the falloff kills most of a cloud past
## about six tenths of each lobe, so a boundary drawn further out circles empty
## sky.
const EXTENT := 0.62

## Five kinds of cloud, which are five different objects rather than five
## palettes. They differ in what lights them, and that decides everything else:
## whether the middle is full or hollow, how big they get, and whether they add
## light to the chart or take it away.
enum Kind {
	EMISSION,    ## gas lit from inside by the stars forming in it
	REFLECTION,  ## gas lit from outside; it only catches what is already there
	PLANETARY,   ## a dying star's shed envelope: small, hollow, sharply lit
	REMNANT,     ## a supernova's expanding shell: hollow, filamentary, wide
	DARK,        ## a cloud that emits nothing and hides what is behind it
}

## What a planetary nebula actually looks like.
##
## They are the prettiest objects in the sky and almost none of them are the
## plain ring the textbook picture suggests. What shapes one is what the dying
## star was doing on the way out: a companion or a fast rotation leaves a dense
## torus round the equator, the wind escapes through the poles instead, and you
## get an hourglass. A jet that stalls in the surrounding gas leaves a bright
## knot on either side. Only the quiet ones come out round.
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
	## How much of the middle is empty, as a fraction. A planetary nebula and a
	## supernova remnant are both shells — the star that lit them threw them
	## outward — so drawing them solid is drawing the wrong object.
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

	## What the boundary is drawn in. Separate from the fill, because a dark
	## nebula fills with a hole in the light and darkening THAT for an outline
	## gives you a line you cannot see — the one kind whose edge you most need
	## drawn, since the cloud itself is defined by absence.
	func edge_colour() -> Color:
		match kind:
			Kind.DARK: return Color("#6b5f7d")
			# Derived, so a violet planetary does not get a green outline.
			Kind.PLANETARY: return _planetary_hue().darkened(0.42)
			Kind.REMNANT: return Color("#4d7f8c")
			Kind.EMISSION: return Color("#8f4a52")
			_: return Color("#4e6390")

	## The hue each kind pulls toward. Emission is hydrogen rose, reflection the
	## cold blue it borrows, planetaries the doubly-ionised oxygen green that
	## makes them unmistakable in a photograph, remnants a hot filament teal,
	## and a dark cloud is not a colour at all — it is a hole in the light.
	func base_colour() -> Color:
		match kind:
			Kind.EMISSION: return Color("#c46a72")
			Kind.PLANETARY: return _planetary_hue()
			Kind.REMNANT: return Color("#6fa8b8")
			Kind.DARK: return Color("#120f18")
			_: return Color("#6a86c4")

	## Planetaries come in every colour there is, and one palette entry made
	## every one of them the same object.
	##
	## The green is doubly-ionised oxygen and it IS the classic — the Ring, the
	## Dumbbell — so it keeps the largest share. But which lines dominate
	## depends on the temperature of the star that shed the envelope and how
	## far the shell has expanded since, and those vary hugely from one to the
	## next: hydrogen and nitrogen give the reds, helium the hard blues, and a
	## thin old shell around a very hot core comes out violet. Unlike an
	## emission cloud, whose colour is just "what hydrogen does", this is a
	## property of the individual star.
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
	## Which way this particular cloud's colour leans, 0 to 1. Only planetaries
	## read it, and only because they are the one kind whose colour is a
	## property of the individual object rather than of the category.
	var hue_roll: float = 0.0
	## Which morphology this planetary took. Ignored by every other kind.
	var shape: Shape = Shape.RING
	## Three overlapping lobes, which is what the cloud actually IS — a single
	## radius was only ever an approximation of it. Held here rather than rolled
	## in the renderer so the outline, the tooltip region and the question of
	## whether a system sits in the gas are all answered by the same shape.
	var lobes: PackedVector2Array = PackedVector2Array()
	var lobe_r: PackedFloat32Array = PackedFloat32Array()

	## Inside the cloud. `reach` scales the lobes: the dense middle for deciding
	## whether a system is in the gas, the full extent for deciding whether the
	## cursor is over it.
	func holds(p: Vector2, reach: float) -> bool:
		for i in lobes.size():
			if (p - pos - lobes[i]).length() < lobe_r[i] * reach:
				return true
		return false

static func clouds() -> Array:
	var g: Dictionary = Run.galaxy
	var gas: float = float(g.get("gas", 1.0))
	# A galaxy that has stopped forming stars gets none at all, rather than a
	# scattering of faint ones. That absence does real work: it is what makes a
	# lenticular read as finished beside a starburst.
	var count := clampi(int(round(gas * 4.0)), 0, 9)
	var out: Array = []
	# Whether a shell — remnant or planetary — has been rolled yet. See below.
	var has_host := false
	if count <= 0:
		return out

	var sq := float(g.get("squash", 0.62))
	var arms := maxi(1, int(g.get("arms", 2)))
	var spiral: bool = int(g.get("arms", 2)) > 0
	# Its own stream, seeded off the run. The chart used to roll these inline
	# and then keep drawing from the same sequence, which meant the positions
	# could not be reproduced anywhere else without replaying every value the
	# renderer happened to consume after them.
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
		# The kind gets its own roll. It used to share a3 with the arm spread,
		# which quietly meant a cloud's kind decided where in the arm it sat:
		# the rarest kind was drawn from one end of the range, so it only ever
		# appeared along one edge of the spiral.
		var a5 := float((rng >> 13) % 10000) / 10000.0

		var c := Cloud.new()
		var rn: float = R_MIN + a1 * R_SPAN
		# One cloud is put in close, where the black hole can get at it. Every
		# cloud used to be placed outside 0.22 of the disc while the turning core
		# reaches 0.21 — so gas and hole had never once overlapped, and the code
		# that hands gas over to orbit had never had anything to hand. Real
		# galactic centres are thick with molecular gas; this is the one place
		# the game had none.
		if k == 1:
			rn = 0.05 + a1 * 0.16
		var ang: float = a2 * TAU
		if spiral:
			ang = MapGen.shape_angle(rn, k % arms, (a3 - 0.5) * 0.55)
		c.pos = Vector2(cos(ang), sin(ang) * sq) * rn
		# One landmark per galaxy, plainly bigger than the rest. A field of
		# same-sized clouds reads as texture; one large one with smaller company
		# reads as a place you could point at.
		c.radius = (0.16 + a4 * 0.08) if k == 0 else (0.06 + a4 * 0.07)
		if k == 1:
			# Big enough to reach well past the hole, so what orbits is a cloud
			# rather than a handful of stray blocks.
			c.radius = 0.13 + a4 * 0.07
		# Weighted toward the quiet kinds. This is a game about a cold universe
		# with one warm thing in it, so the loud clouds stay in the minority.
		# Rebalanced toward the two kinds a star DIED in. They are not just
		# scenery any more — a pulsar can only exist where one of these is, so
		# a 12% planetary meant most galaxies rolled none at all and the rarest
		# object in the game had nowhere it was allowed to be.
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
		# Every galaxy still forming stars gets at least one shell in it. Left
		# purely to the dice, 85 galaxies in 200 rolled neither a remnant nor a
		# planetary — and since a pulsar can now only exist inside one of those,
		# that was 40% of runs in which the rarest thing in the game was not
		# merely rare but structurally impossible.
		#
		# Forced on the LAST cloud, and only when nothing earlier obliged, so a
		# galaxy that already has shells is untouched. A galaxy with no gas at
		# all still gets nothing, which is right: no star formation means no
		# massive stars, and no massive stars means nothing left to explode.
		# REMNANT only. A planetary used to count here, back when a pulsar
		# could sit in one — now that only a core-collapse supernova leaves a
		# neutron star, a galaxy whose one shell was a planetary was being
		# recorded as satisfied and then producing no pulsar at all.
		if c.kind == Kind.REMNANT:
			has_host = true
		elif k == count - 1 and not has_host:
			c.kind = Kind.REMNANT

		match c.kind:
			Kind.PLANETARY:
				# Small and sharply hollow. A planetary is the envelope of one
				# star, not a star-forming region — at nebula scale it is tiny,
				# and drawing it the size of the others loses the distinction.
				# Still the smallest by a distance, but no longer a third of
				# the others: at 0.34 it was small enough that a system rarely
				# fell inside one, and now that a pulsar needs to fall inside
				# one, "rarely" was doing real damage.
				c.radius *= 0.72
				c.hollow = 0.62
			Kind.REMNANT:
				# Wide, thin-walled: a shock front still travelling outward.
				c.radius *= 1.25
				c.hollow = 0.48
			Kind.DARK:
				c.radius *= 1.1
		# Its own draw, so the colour of a planetary is independent of where it
		# sits and how big it is. Rolled for every cloud and ignored by the
		# rest, which is cheaper than branching and keeps the stream aligned.
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
		# A shell is ONE shell. Planetaries and remnants are gas thrown outward
		# from a single point, so they get a single lobe on that point — built
		# from three offset ones they came out as three separate rings, which is
		# three explosions rather than one.
		if c.hollow > 0.0:
			c.lobes.append(Vector2.ZERO)
			c.lobe_r.append(c.radius)
			out.append(c)
			continue
		# Otherwise three of them, offset and unequal. One circle reads as a
		# bubble; three overlapping read as a shape, and where two meet the gas
		# comes out brighter for free.
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
		out.append(c)
	return out

## Which cloud a point sits inside, or null. Uses the drawn ellipse, since that
## is the shape both the chart and the player see.
static func at(p: Vector2, reach: float = EXTENT) -> Cloud:
	var best: Cloud = null
	var closest := INF
	for c in clouds():
		var cl: Cloud = c
		var d := (p - cl.pos).length()
		# Well inside, not merely touching the outermost wisp: the falloff kills
		# most of a cloud past about six tenths of its nominal radius, so
		# anything beyond that is clear sky with a few pixels in it.
		# Against the lobes, not against a radius: the cloud is not a disc, and
		# testing it as one meant the tooltip fired over empty sky on one side
		# and refused inside plain gas on the other.
		#
		# `reach` scales them: the dense middle for whether a SYSTEM sits in the
		# gas, since the falloff kills most of a cloud past about six tenths of
		# each lobe, and the full extent for whether the CURSOR is over it.
		if cl.holds(p, reach) and d < closest:
			closest = d
			best = cl
	return best
