class_name Ladder
extends RefCounted

## THE TIERS: the eleven rungs of the ascension ladder as the player meets them
## (Jon's picks, Nov 7). The player's word is Tier; the code's is still
## `Run.ascension`, which the saves and the record keep.
## Why: docs/why/Ladder.md#the-ladder

enum Form { SPIRAL, DISC, BALL, DWARF }

## name, form, the one-line rule
const RUNGS := [
	["THE SPIRAL AS IT IS", Form.SPIRAL, "The spiral as it is today."],
	["PICKED SHELVES", Form.SPIRAL, "Traders got here first. Dock shelves carry fewer parts."],
	["THICK GAS", Form.SPIRAL, "Jumps into a nebula cost 1 more fuel."],
	["HIDDEN IN GAS", Form.SPIRAL, "Raiders wait inside nebulae, so an ambush there is more likely."],
	["SHORT TANK", Form.DISC, "Fuel is rationed here, so you launch with 35 fuel in a 45 tank."],
	["FEWER DOCKS", Form.DISC, "Few people ever settled this old galaxy, so there are a quarter fewer docks."],
	["SCARCE PARTS", Form.DISC, "Nothing is built here any more, so repairs cost half again as much."],
	["THE HELLBENDER", Form.BALL, "Nothing here flies in lanes, so the Hellbender starts closer and moves more often."],
	["THICK PLATING", Form.BALL, "The hot gas here burns thin hulls, so enemy ships carry 15% more hull."],
	["ACTIVE CORE", Form.BALL, "The black hole at the core is feeding, so the Custodian gets stronger from jump 12, not 15."],
	["TORN AWAY", Form.DWARF, "A bigger galaxy is pulling this one apart. From jump 4, the outer ring is lost each jump. Keep moving in."],
]
const FORM_NAME := ["SPIRAL GALAXY", "DISC GALAXY", "BALL GALAXY", "TORN DWARF"]
## Danger reads in the lamp colour: the spiral rungs cool, the disc amber, the ball red, the dwarf hot.
const FORM_COLOUR := [Color8(150, 215, 205), Color8(240, 160, 67), Color8(238, 96, 58), Color8(255, 70, 90)]
## The galaxy kinds that are dwarfs: the torn one is one of these.
const DWARF_KINDS := ["Blue Compact Dwarf", "Dwarf Spheroidal"]


static func count() -> int:
	return RUNGS.size()


static func rung_name(tier: int) -> String:
	return String(RUNGS[clampi(tier, 0, RUNGS.size() - 1)][0])


static func form(tier: int) -> Form:
	return RUNGS[clampi(tier, 0, RUNGS.size() - 1)][1] as Form


static func rule(tier: int) -> String:
	return String(RUNGS[clampi(tier, 0, RUNGS.size() - 1)][2])


static func form_name(tier: int) -> String:
	return FORM_NAME[int(form(tier))]


static func colour(tier: int) -> Color:
	return FORM_COLOUR[int(form(tier))]


## The form a galaxy kind takes: `ChartSky.form_of`, with the dwarfs their own.
static func form_of_kind(kind: int) -> Form:
	if GalaxyGen.type_name(kind) in DWARF_KINDS:
		return Form.DWARF
	match ChartSky.form_of(kind):
		0: return Form.SPIRAL
		2: return Form.DISC
	return Form.BALL


## The kinds a tier flies: a spiral at the spiral rungs, and so on.
static func kinds_of(tier: int) -> Array[int]:
	var out: Array[int] = []
	var f := form(tier)
	for k in GalaxyGen.count():
		if form_of_kind(k) == f:
			out.append(k)
	if out.is_empty():
		for k in GalaxyGen.count():
			out.append(k)
	return out


## One draw from `rng` (the world stream, in the seed's order): at tier 0 any
## kind, as every seed rolled until now (the pinned galaxies and the seeded
## tests keep their worlds); from tier 1 a kind of the tier's form.
static func roll_kind(tier: int, rng: RandomNumberGenerator) -> int:
	if tier <= 0:
		return rng.randi() % GalaxyGen.count()
	var ks := kinds_of(tier)
	return ks[rng.randi() % ks.size()]


## The highest tier won on the flight record, or -1 with no win; a win from
## before tiers is a tier 0 win.
static func best_won() -> int:
	var best := -1
	for r in RunHistory.load_all():
		var e: Dictionary = r
		if int(e.get("outcome", -1)) != int(RunHistory.Outcome.WON):
			continue
		best = maxi(best, clampi(int(e.get("ascension", 0)), 0, Run.ASCENSION_MAX))
	return best


## The unlock-by-winning rule: a tier up to one past the best won; developer
## mode opens them all, as it opens every manufacturer.
static func can_pick(tier: int) -> bool:
	if tier < 0 or tier > Run.ASCENSION_MAX:
		return false
	if DevMode.enabled:
		return true
	return tier <= best_won() + 1


## The line under a tier's rule that says the lower tiers' rules still hold
## (Jon's T-A, Nov 11); none at tiers 0 and 1.
## Why: docs/why/Ladder.md#the-stack
static func still_line(tier: int) -> String:
	if tier <= 1:
		return ""
	if tier == 2:
		return "TIER 1 STILL APPLIES."
	if tier == 3:
		return "TIERS 1 AND 2 STILL APPLY."
	return "TIERS 1 TO %d STILL APPLY." % (tier - 1)


## The tiers whose rules a run at `tier` flies under, newest first: tier 0 has none.
static func in_force(tier: int) -> Array[int]:
	var out: Array[int] = []
	for k in range(clampi(tier, 0, RUNGS.size() - 1), 0, -1):
		out.append(k)
	return out
