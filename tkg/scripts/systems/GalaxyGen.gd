class_name GalaxyGen
extends RefCounted

## Layout is not purely presentation: squash changed system counts (132 vs 188). Ring holes
## were removed.
## Why: docs/why/GalaxyGen.md#galaxy-kinds

const KINDS := [
	{
		name = "Grand-Design Spiral", arms = 2, twist = 8.6, bar = 0.0,
		squash = 0.62, density = 1.00, reach = 1.00, core_share = 0.5, core_pow = 2.4, halo_pow = 0.92,
		spread = 1.0, chaos = 0.0, ring = 0.0, bulge = 0.30, dust = 1.6,
		tail = false, gas = 1.0,
		blurb = "Two unbroken arms, wound over ten billion years. No galaxy has come close enough to disturb it since the disc cooled.",
	},
	{
		name = "Barred Spiral", arms = 2, twist = 8.6, bar = 0.34,
		squash = 0.60, density = 1.00, reach = 1.00, core_share = 0.5, core_pow = 2.5, halo_pow = 0.95,
		spread = 1.0, chaos = 0.0, ring = 0.0, bulge = 0.32, dust = 1.6,
		tail = false, gas = 1.0,
		blurb = "The disc grew unstable and collapsed into a bar. The bar has funnelled gas in to the centre ever since.",
	},
	{
		name = "Multi-Arm Spiral", arms = 4, twist = 6.4, bar = 0.0,
		squash = 0.66, density = 1.05, reach = 1.00, core_share = 0.45, core_pow = 2.2, halo_pow = 0.9,
		spread = 1.1, chaos = 0.0, ring = 0.0, bulge = 0.26, dust = 1.5,
		tail = false, gas = 1.15,
		blurb = "A spiral with four arms of about the same size. Its density waves never settled into one pattern.",
	},
	{
		name = "Flocculent Spiral", arms = 7, twist = 5.2, bar = 0.0,
		squash = 0.64, density = 1.00, reach = 1.05, core_share = 0.4, core_pow = 2.0, halo_pow = 0.88,
		spread = 2.4, chaos = 0.18, ring = 0.0, bulge = 0.22, dust = 1.3,
		tail = false, gas = 1.25,
		blurb = "Short, patchy spurs of new stars, with no overall pattern. It has made stars in fits and starts for as long as anyone has watched.",
	},
	{
		name = "Anemic Spiral", arms = 2, twist = 8.0, bar = 0.0,
		squash = 0.56, density = 0.95, reach = 0.98, core_share = 0.58, core_pow = 2.7, halo_pow = 1.08,
		spread = 0.7, chaos = 0.0, ring = 0.0, bulge = 0.34, dust = 2.3,
		tail = false, gas = 0.22,
		blurb = "It fell into a cluster, and the gas was stripped off it on the way in. The arms still turn, but they have no gas left to make new stars.",
	},
	{
		name = "Magellanic Irregular", arms = 1, twist = 2.8, bar = 0.44,
		squash = 0.80, density = 1.00, reach = 1.00, core_share = 0.32, core_pow = 1.7, halo_pow = 0.84,
		spread = 2.6, chaos = 0.30, ring = 0.0, bulge = 0.11, dust = 1.2,
		tail = false, gas = 1.55,
		blurb = "One arm trails off a bar that sits well away from the middle. A larger neighbour has pulled on it for a billion years and made this shape.",
	},
	{
		name = "Lenticular", arms = 0, twist = 0.0, bar = 0.0,
		squash = 0.36, density = 0.85, reach = 0.90, core_share = 0.62, core_pow = 2.8, halo_pow = 1.1,
		spread = 0.0, chaos = 0.0, ring = 0.0, bulge = 0.40, dust = 2.2,
		tail = false, gas = 0.12,
		blurb = "A spiral that ran out of gas. The disc remains but the arms are gone. No new star has formed in it for a very long time.",
	},
	{
		name = "Barred Lenticular", arms = 0, twist = 0.0, bar = 0.42,
		squash = 0.34, density = 0.85, reach = 0.90, core_share = 0.6, core_pow = 2.9, halo_pow = 1.1,
		spread = 0.0, chaos = 0.0, ring = 0.0, bulge = 0.42, dust = 2.2,
		tail = false, gas = 0.1,
		blurb = "An old disc with a fossil bar across it. The bar stopped feeding gas to the centre aeons ago.",
	},
	{
		name = "Round Elliptical", arms = 0, twist = 0.0, bar = 0.0,
		squash = 0.92, density = 1.20, reach = 1.05, core_share = 0.7, core_pow = 3.0, halo_pow = 1.4,
		spread = 0.0, chaos = 0.0, ring = 0.0, bulge = 0.34, dust = 2.6,
		tail = false, gas = 0.06,
		blurb = "A dozen galaxies merged and settled into this sphere. Its stars all orbit different ways, and none of them turn together.",
	},
	{
		name = "Flattened Elliptical", arms = 0, twist = 0.0, bar = 0.0,
		squash = 0.44, density = 0.95, reach = 0.95, core_share = 0.68, core_pow = 2.9, halo_pow = 1.35,
		spread = 0.0, chaos = 0.0, ring = 0.0, bulge = 0.32, dust = 2.5,
		tail = false, gas = 0.08,
		blurb = "Two large galaxies met head-on and merged into this one. Its shape still shows the direction they hit from.",
	},
	{
		name = "Giant Elliptical", arms = 0, twist = 0.0, bar = 0.0,
		squash = 0.78, density = 1.25, reach = 1.15, core_share = 0.72, core_pow = 2.5, halo_pow = 1.7,
		spread = 0.0, chaos = 0.0, ring = 0.0, bulge = 0.46, dust = 2.9,
		tail = false, gas = 0.05,
		blurb = "It sits at the centre of its cluster and has absorbed every galaxy that came near. Its halo is full of stars taken from them.",
	},
	{
		name = "Irregular", arms = 3, twist = 1.6, bar = 0.0,
		squash = 0.72, density = 1.00, reach = 1.00, core_share = 0.34, core_pow = 1.7, halo_pow = 0.8,
		spread = 3.2, chaos = 0.42, ring = 0.0, bulge = 0.14, dust = 1.1,
		tail = false, gas = 1.4,
		blurb = "It has no clear shape. A large galaxy passed close enough to tear the disc apart, and the disc has not had time to reform.",
	},
	{
		name = "Interacting Pair", arms = 2, twist = 7.2, bar = 0.0,
		squash = 0.64, density = 1.10, reach = 1.10, core_share = 0.46, core_pow = 2.3, halo_pow = 0.94,
		spread = 1.4, chaos = 0.12, ring = 0.0, bulge = 0.28, dust = 1.5,
		tail = true, gas = 1.5,
		blurb = "A neighbour is pulling it apart. The tidal stream flung off the far side holds a hundred million stars, and they are already leaving.",
	},
	{
		name = "Merger Remnant", arms = 0, twist = 0.0, bar = 0.0,
		squash = 0.68, density = 1.10, reach = 1.05, core_share = 0.70, core_pow = 2.6, halo_pow = 1.5,
		spread = 0.0, chaos = 0.16, ring = 0.0, bulge = 0.38, dust = 2.7,
		tail = true, gas = 0.30,
		blurb = "Two galaxies merged into this one a long time ago. The stream hanging off one side is all that is left of the smaller one, and it is moving away.",
	},
	{
		name = "Blue Compact Dwarf", arms = 0, twist = 0.0, bar = 0.0,
		squash = 0.84, density = 0.60, reach = 0.76, core_share = 0.78, core_pow = 3.5, halo_pow = 1.85,
		spread = 0.0, chaos = 0.20, ring = 0.0, bulge = 0.44, dust = 1.9,
		tail = false, gas = 1.75,
		blurb = "A small galaxy making stars at a rate it cannot keep up. This one burst will use up all the gas it has.",
	},
	{
		name = "Dwarf Spheroidal", arms = 0, twist = 0.0, bar = 0.0,
		squash = 0.86, density = 0.55, reach = 0.80, core_share = 0.5, core_pow = 2.0, halo_pow = 1.15,
		spread = 0.0, chaos = 0.08, ring = 0.0, bulge = 0.12, dust = 2.0,
		tail = false, gas = 0.15,
		blurb = "A small, old, thin galaxy. A larger neighbour has taken its stars for so long that what is left barely holds together.",
	},
	{
		name = "Starburst Spiral", arms = 2, twist = 9.4, bar = 0.22,
		squash = 0.60, density = 1.15, reach = 0.95, core_share = 0.58, core_pow = 3.4, halo_pow = 0.9,
		spread = 1.2, chaos = 0.0, ring = 0.0, bulge = 0.44, dust = 1.7,
		tail = false, gas = 1.9,
		blurb = "The core burns its gas far faster than it can be replaced. For a galaxy, a burst like this is brief, and it is happening now.",
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

## Rolled once per run and stored on RunState, since node layout derives from squash and
## twist.
## Why: docs/why/GalaxyGen.md#rolling-a-galaxy
static func roll(kind: int, r: RandomNumberGenerator = Rng.world) -> Dictionary:
	var g: Dictionary = params(kind).duplicate()
	g.twist = float(g.twist) * r.randf_range(0.86, 1.16)
	g.squash = clampf(float(g.squash) + r.randf_range(-0.07, 0.07), 0.28, 0.95)
	g.core_share = clampf(float(g.core_share) + r.randf_range(-0.07, 0.07), 0.2, 0.85)
	g.core_pow = maxf(1.1, float(g.core_pow) + r.randf_range(-0.3, 0.3))
	g.halo_pow = maxf(0.6, float(g.halo_pow) + r.randf_range(-0.1, 0.1))
	g.spread = maxf(0.0, float(g.spread) * r.randf_range(0.8, 1.25))
	g.bulge = clampf(float(g.bulge) * r.randf_range(0.8, 1.25), 0.08, 0.5)
	g.dust = maxf(0.8, float(g.dust) + r.randf_range(-0.25, 0.25))
	# Gas can floor at zero so a dead galaxy has no nebulae at all, not a scattering of faint
	# ones.
	g.gas = maxf(0.0, float(g.gas) * r.randf_range(0.75, 1.3))
	# Hole scales off the bulge, which correlates with central mass, then rolls wide for
	# variety.
	g.hole = clampf(float(g.bulge) * r.randf_range(0.05, 0.13), 0.012, 0.046)
	g.chaos = maxf(0.0, float(g.chaos) * r.randf_range(0.7, 1.4))
	if float(g.ring) > 0.0:
		g.ring = clampf(float(g.ring) + r.randf_range(-0.05, 0.05), 0.2, 0.7)
	# Arm count varies where the type does not depend on an exact number.
	if int(g.arms) >= 4:
		g.arms = int(g.arms) + r.randi_range(-1, 2)
	return g

static func count() -> int:
	return KINDS.size()

static func params(kind: int) -> Dictionary:
	return KINDS[clampi(kind, 0, KINDS.size() - 1)]

static func type_name(kind: int) -> String:
	return params(kind).name

static func blurb(kind: int) -> String:
	return params(kind).blurb

## Both names are rolled once per run: a galaxy that renames itself between visits is not a
## place.
static func roll_name(r: RandomNumberGenerator = Rng.world) -> String:
	return "%s %d" % [Rng.pick(r, _CATALOGUE), r.randi_range(102, 9899)]

static func roll_title(r: RandomNumberGenerator = Rng.world) -> String:
	return "The %s %s" % [Rng.pick(r, _ADJ), Rng.pick(r, _NOUN)]

const _NEB_ADJ := [
	"Weeping", "Drowned", "Hanged", "Sundered", "Cold", "Burning", "Pale",
	"Hollow", "Quiet", "Bitter", "Long", "Salt", "Broken", "Waking", "Blind",
]
const _NEB_NOUN := [
	"Gate", "Veil", "Mouth", "Lantern", "Shroud", "Furnace", "Cradle", "Wound",
	"Chapel", "Net", "Kiln", "Wake", "Fathom", "Mantle", "Bell",
]

## Named from a hash, not rolled: the chart rebuilds stars on resize and a landmark must
## not rename.
## Why: docs/why/GalaxyGen.md#nebula-names
static func nebula_name(h: int) -> String:
	h = absi(h)
	if h % 2 == 0:
		return "%s %d" % [_CATALOGUE[(h >> 5) % _CATALOGUE.size()], (h >> 9) % 8899 + 100]
	return "THE %s %s" % [
		_NEB_ADJ[(h >> 5) % _NEB_ADJ.size()], _NEB_NOUN[(h >> 13) % _NEB_NOUN.size()]]


## Lives here, not in NetSession: it also kept `version_guard.py` from demanding a PROTOCOL
## bump for no wire change.
## Why: docs/why/GalaxyGen.md#table-fingerprint
static func table_fingerprint() -> String:
	var parts: PackedStringArray = []
	for k in KINDS:
		var kind: Dictionary = k
		parts.append("%s/%.2f/%.2f" % [kind.name,
			float(kind.get("density", 1.0)), float(kind.get("reach", 1.0))])
	return "|".join(parts)

