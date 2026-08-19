class_name GalaxyGen
extends RefCounted

## Which galaxy this run takes place in.
##
## Pure presentation. Systems are laid out on rings by MapGen and placed on
## rings by the chart, so the shape of the galaxy behind them can vary freely
## without moving a single jump or changing a single fuel cost. That separation
## is what makes fourteen of these cheap.
##
## Content is data, not code: a new galaxy is a dictionary entry, and the
## renderer already knows how to draw every field in it.
##
## Fields:
##   arms        0 for no spiral structure at all (ellipticals, irregulars)
##   twist       radians of winding across the full disc; higher is tighter
##   bar         fraction of the radius held by a straight bar, 0 for none
##   squash      vertical foreshortening; 1.0 is face-on round, 0.3 is edge-on
##   core_share  fraction of stars belonging to the concentrated population
##   core_pow    falloff of that population; higher packs harder into the middle
##   halo_pow    falloff of the extended population that reaches the rim
##   spread      how far stars stray off the arm ridge
##   chaos       positional noise; what makes an irregular irregular
##   ring        inner radius of a hole, as a fraction; 0 for a filled disc
##   bulge       radius of the burning core, as a fraction of the disc
##   dust        falloff of the wash between the arms
##   gas         how much star-forming material is left; scales nebulae,
##               dust lanes and supernova remnants. Spirals are rich, the
##               ellipticals and lenticulars that ran out are nearly bare
##   tail        draw a tidal stream flung off one side

const KINDS := [
	{
		name = "Grand-Design Spiral", arms = 2, twist = 8.6, bar = 0.0,
		squash = 0.62, core_share = 0.5, core_pow = 2.4, halo_pow = 0.92,
		spread = 1.0, chaos = 0.0, ring = 0.0, bulge = 0.30, dust = 1.6,
		tail = false, gas = 1.0,
		blurb = "Two arms, unbroken, wound over ten billion years. Nothing has come close enough to disturb it since the disc first cooled.",
	},
	{
		name = "Barred Spiral", arms = 2, twist = 8.6, bar = 0.34,
		squash = 0.60, core_share = 0.5, core_pow = 2.5, halo_pow = 0.95,
		spread = 1.0, chaos = 0.0, ring = 0.0, bulge = 0.32, dust = 1.6,
		tail = false, gas = 1.0,
		blurb = "The disc grew unstable and collapsed into a bar. It has been funnelling gas inward ever since, feeding whatever is at the centre.",
	},
	{
		name = "Multi-Arm Spiral", arms = 4, twist = 6.4, bar = 0.0,
		squash = 0.66, core_share = 0.45, core_pow = 2.2, halo_pow = 0.9,
		spread = 1.1, chaos = 0.0, ring = 0.0, bulge = 0.26, dust = 1.5,
		tail = false, gas = 1.15,
		blurb = "Four arms, none of them dominant. The density waves here never settled into a single pattern and probably never will.",
	},
	{
		name = "Flocculent Spiral", arms = 7, twist = 5.2, bar = 0.0,
		squash = 0.64, core_share = 0.4, core_pow = 2.0, halo_pow = 0.88,
		spread = 2.4, chaos = 0.18, ring = 0.0, bulge = 0.22, dust = 1.3,
		tail = false, gas = 1.25,
		blurb = "No grand design — just scattered, patchy spurs of star formation. It has been making stars in fits and starts for as long as anyone has watched.",
	},
	{
		name = "Barred Ring Spiral", arms = 2, twist = 11.0, bar = 0.30,
		squash = 0.58, core_share = 0.44, core_pow = 2.6, halo_pow = 1.0,
		spread = 0.9, chaos = 0.0, ring = 0.34, bulge = 0.30, dust = 1.8,
		tail = false, gas = 0.85,
		blurb = "The bar swept the inner disc clean and piled it into a ring. Everything between the core and that ring was consumed building it.",
	},
	{
		name = "Lenticular", arms = 0, twist = 0.0, bar = 0.0,
		squash = 0.36, core_share = 0.62, core_pow = 2.8, halo_pow = 1.1,
		spread = 0.0, chaos = 0.0, ring = 0.0, bulge = 0.40, dust = 2.2,
		tail = false, gas = 0.12,
		blurb = "A spiral that ran out of gas. The disc is still here, the arms are not, and no new star has lit in it for a very long time.",
	},
	{
		name = "Barred Lenticular", arms = 0, twist = 0.0, bar = 0.42,
		squash = 0.34, core_share = 0.6, core_pow = 2.9, halo_pow = 1.1,
		spread = 0.0, chaos = 0.0, ring = 0.0, bulge = 0.42, dust = 2.2,
		tail = false, gas = 0.1,
		blurb = "An old disc with a fossil bar across it. Whatever the bar was feeding finished eating aeons ago.",
	},
	{
		name = "Round Elliptical", arms = 0, twist = 0.0, bar = 0.0,
		squash = 0.92, core_share = 0.7, core_pow = 3.0, halo_pow = 1.4,
		spread = 0.0, chaos = 0.0, ring = 0.0, bulge = 0.34, dust = 2.6,
		tail = false, gas = 0.06,
		blurb = "The wreckage of a dozen mergers, relaxed into a sphere. Every orbit here points somewhere different; nothing turns together any more.",
	},
	{
		name = "Flattened Elliptical", arms = 0, twist = 0.0, bar = 0.0,
		squash = 0.44, core_share = 0.68, core_pow = 2.9, halo_pow = 1.35,
		spread = 0.0, chaos = 0.0, ring = 0.0, bulge = 0.32, dust = 2.5,
		tail = false, gas = 0.08,
		blurb = "Two large galaxies met head-on and neither survived as itself. What is left still remembers the direction of the impact.",
	},
	{
		name = "Giant Elliptical", arms = 0, twist = 0.0, bar = 0.0,
		squash = 0.78, core_share = 0.72, core_pow = 2.5, halo_pow = 1.7,
		spread = 0.0, chaos = 0.0, ring = 0.0, bulge = 0.46, dust = 2.9,
		tail = false, gas = 0.05,
		blurb = "It sits at the centre of its cluster and has eaten everything that came near. The halo is full of stars that used to belong to something else.",
	},
	{
		name = "Irregular", arms = 3, twist = 1.6, bar = 0.0,
		squash = 0.72, core_share = 0.34, core_pow = 1.7, halo_pow = 0.8,
		spread = 3.2, chaos = 0.42, ring = 0.0, bulge = 0.14, dust = 1.1,
		tail = false, gas = 1.4,
		blurb = "No structure worth the name. Something large passed close enough to tear the disc apart, and it has not had time to reform.",
	},
	{
		name = "Interacting Pair", arms = 2, twist = 7.2, bar = 0.0,
		squash = 0.64, core_share = 0.46, core_pow = 2.3, halo_pow = 0.94,
		spread = 1.4, chaos = 0.12, ring = 0.0, bulge = 0.28, dust = 1.5,
		tail = true, gas = 1.5,
		blurb = "Currently being pulled apart by a neighbour. The tidal stream flung off the far side holds a hundred million stars that are already leaving.",
	},
	{
		name = "Collisional Ring", arms = 0, twist = 0.0, bar = 0.0,
		squash = 0.70, core_share = 0.30, core_pow = 3.2, halo_pow = 1.0,
		spread = 0.0, chaos = 0.06, ring = 0.52, bulge = 0.18, dust = 2.4,
		tail = false, gas = 1.1,
		blurb = "Something went straight through the middle. The shock is still travelling outward as a ring of new stars, and the centre never filled back in.",
	},
	{
		name = "Dwarf Spheroidal", arms = 0, twist = 0.0, bar = 0.0,
		squash = 0.86, core_share = 0.5, core_pow = 2.0, halo_pow = 1.15,
		spread = 0.0, chaos = 0.08, ring = 0.0, bulge = 0.12, dust = 2.0,
		tail = false, gas = 0.15,
		blurb = "Small, old and thin. It has been losing stars to a larger neighbour for so long that what remains barely holds itself together.",
	},
	{
		name = "Starburst Spiral", arms = 2, twist = 9.4, bar = 0.22,
		squash = 0.60, core_share = 0.58, core_pow = 3.4, halo_pow = 0.9,
		spread = 1.2, chaos = 0.0, ring = 0.0, bulge = 0.44, dust = 1.7,
		tail = false, gas = 1.9,
		blurb = "The core is burning through its gas far faster than it can be replaced. On this timescale that is an event, and you are inside it.",
	},
]

const _CATALOGUE := ["NGC", "IC", "UGC", "PGC", "ESO", "MCG"]
const _ADJ := [
	"Long", "Drowned", "Patient", "Broken", "Quiet", "Hollow", "Burning",
	"Last", "Cold", "Turning", "Salt", "Iron", "Pale", "Waking", "Sundered",
]
const _NOUN := [
	"Silence", "Wheel", "Reach", "Lantern", "Furnace", "Coil", "Harvest",
	"Crown", "Tide", "Anvil", "Choir", "Threshold", "Ember", "Verge", "Fathom",
]

## One galaxy, rolled from a type.
##
## KINDS holds the archetype; this returns a copy with every parameter nudged,
## so two Grand-Design Spirals are recognisably the same kind of object and not
## the same object. Rolled ONCE per run and stored on RunState, because the node
## layout is derived from squash and twist — re-rolling per call would move the
## systems out from under the player.
static func roll(kind: int) -> Dictionary:
	var g: Dictionary = params(kind).duplicate()
	g.twist = float(g.twist) * randf_range(0.86, 1.16)
	g.squash = clampf(float(g.squash) + randf_range(-0.07, 0.07), 0.28, 0.95)
	g.core_share = clampf(float(g.core_share) + randf_range(-0.07, 0.07), 0.2, 0.85)
	g.core_pow = maxf(1.1, float(g.core_pow) + randf_range(-0.3, 0.3))
	g.halo_pow = maxf(0.6, float(g.halo_pow) + randf_range(-0.1, 0.1))
	g.spread = maxf(0.0, float(g.spread) * randf_range(0.8, 1.25))
	g.bulge = clampf(float(g.bulge) * randf_range(0.8, 1.25), 0.08, 0.5)
	g.dust = maxf(0.8, float(g.dust) + randf_range(-0.25, 0.25))
	# Gas is the one parameter with a visible floor of zero: a galaxy that has
	# genuinely stopped forming stars should have no nebulae at all, not a
	# scattering of faint ones. That absence is what makes a lenticular read as
	# dead beside a starburst.
	g.gas = maxf(0.0, float(g.gas) * randf_range(0.75, 1.3))
	# The black hole. Scaled off the bulge, because the two really do correlate
	# — a galaxy with a big central bulge has a big central mass — and then
	# rolled wide, so one galaxy has a pinprick at its heart and the next has a
	# throat you can see from the rim.
	g.hole = clampf(float(g.bulge) * randf_range(0.05, 0.13), 0.012, 0.046)
	g.chaos = maxf(0.0, float(g.chaos) * randf_range(0.7, 1.4))
	if float(g.ring) > 0.0:
		g.ring = clampf(float(g.ring) + randf_range(-0.05, 0.05), 0.2, 0.7)
	# Arm count varies where the type does not depend on an exact number.
	if int(g.arms) >= 4:
		g.arms = int(g.arms) + randi_range(-1, 2)
	return g

static func count() -> int:
	return KINDS.size()

static func params(kind: int) -> Dictionary:
	return KINDS[clampi(kind, 0, KINDS.size() - 1)]

static func type_name(kind: int) -> String:
	return params(kind).name

static func blurb(kind: int) -> String:
	return params(kind).blurb

## A catalogue designation and the name people actually use for it. Both are
## rolled once per run and then fixed: a galaxy that renames itself between
## visits to the chart is not a place.
static func roll_name() -> String:
	return "%s %d" % [_CATALOGUE.pick_random(), randi_range(102, 9899)]

static func roll_title() -> String:
	return "The %s %s" % [_ADJ.pick_random(), _NOUN.pick_random()]

const _NEB_ADJ := [
	"Weeping", "Drowned", "Hanged", "Sundered", "Cold", "Burning", "Pale",
	"Hollow", "Quiet", "Bitter", "Long", "Salt", "Broken", "Waking", "Blind",
]
const _NEB_NOUN := [
	"Gate", "Veil", "Mouth", "Lantern", "Shroud", "Furnace", "Cradle", "Wound",
	"Chapel", "Net", "Kiln", "Wake", "Fathom", "Mantle", "Bell",
]

## The clouds between the systems. Named from a hash rather than rolled, because
## the chart rebuilds its star field whenever the panel resizes, and a landmark
## that renames itself when you drag the window is not a landmark.
##
## Half come out as catalogue entries and half as names people gave them, which
## is how a sky actually reads: the ones anyone has looked at long enough to
## describe got a name, and the rest got a number.
static func nebula_name(h: int) -> String:
	h = absi(h)
	if h % 2 == 0:
		return "%s %d" % [_CATALOGUE[(h >> 5) % _CATALOGUE.size()], (h >> 9) % 8899 + 100]
	return "THE %s %s" % [
		_NEB_ADJ[(h >> 5) % _NEB_ADJ.size()], _NEB_NOUN[(h >> 13) % _NEB_NOUN.size()]]
