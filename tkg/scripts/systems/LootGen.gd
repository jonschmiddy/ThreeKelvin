class_name LootGen
extends RefCounted

## Rolls modules and hulls. Rarity ladder: Common..Legendary are manufactured,
## Exotic is grown/harvested, Artifact is precursor. Region biasing is what
## makes set bonuses reachable by route choice rather than luck.

static func roll_module(danger_in: int, force_manufacturer: StringName = &"",
		allow_unbranded: bool = false,
		r: RandomNumberGenerator = Rng.loot) -> ModuleData:
	# Every threshold below was tuned against the five-tier ladder. Read the
	# wider scale through tier() rather than restating all of them.
	var danger := MapGen.tier(danger_in)
	# A Territory region can force a manufacturer that the active-manufacturer gate has switched
	# off. Honouring that would empty the pool and collapse every drop in the
	# region to the fallback, so treat it as an unbranded roll instead.
	if force_manufacturer != &"" and not _manufacturer_active(force_manufacturer):
		force_manufacturer = &""

	var pool: Array[StringName] = []
	for id in DB.modules.keys():
		var m: ModuleData = DB.modules[id]
		# Yard stock is issued, not found. A wreck full of the same Hull Plating
		# you launched with would crowd out the branded parts that a run is
		# spent collecting, and the whole point of the generic kit is that it is
		# the thing you are trying to replace.
		if m.starter_only:
			continue
		if m.rarity >= ModuleData.Rarity.EXOTIC and not allow_unbranded:
			continue
		if not _manufacturer_active(m.manufacturer):
			continue
		if force_manufacturer != &"" and m.manufacturer != force_manufacturer:
			continue
		# Deep loot appears deeper.
		if m.rarity == ModuleData.Rarity.EPIC and danger < 3:
			continue
		if m.rarity == ModuleData.Rarity.LEGENDARY and danger < 4:
			continue
		pool.append(id)
	if pool.is_empty():
		pool = [&"kh20"]

	var template: ModuleData = DB.modules[Rng.pick(r, pool)]
	var m := template.duplicate(true) as ModuleData

	# Small chance to upgrade rarity with depth.
	if m.rarity < ModuleData.Rarity.LEGENDARY and r.randf() < 0.06 * danger:
		m.rarity = int(m.rarity) + 1

	m.affixes = _roll_affixes(_affix_count(m.rarity), danger, r)
	m.scrap_value = int(round(ModuleData.SCRAP_VALUE[m.rarity] * r.randf_range(0.8, 1.3)))
	return m

## True when a manufacturer may drop. Manufacturer-agnostic modules (manufacturer &"") always
## pass — see DB.ACTIVE_MANUFACTURERS.
static func _manufacturer_active(manufacturer: StringName) -> bool:
	return manufacturer == &"" or DB.ACTIVE_MANUFACTURERS.is_empty() or DB.ACTIVE_MANUFACTURERS.has(manufacturer)

## EIGHT ENTRIES FOR AN EIGHT-VALUE ENUM. This was seven long against a Rarity
## that ends at CONTRABAND, so `_affix_count(CONTRABAND)` indexed past the end.
## Nothing in the module tables is authored contraband today and the rarity
## upgrade roll caps at LEGENDARY, so it was unreachable rather than broken —
## which is the kind of thing that stays unreachable right up until somebody
## authors the first contraband part.
static func _affix_count(r: ModuleData.Rarity) -> int:
	return [0, 1, 2, 3, 3, 3, 2, 3][r]

static func _roll_affixes(n: int, danger: int, r: RandomNumberGenerator) -> Array[AffixData]:
	var out: Array[AffixData] = []
	if n <= 0:
		return out
	var avail := DB.affixes.duplicate()
	for i in n:
		if avail.is_empty():
			break
		var pick: AffixData = avail[r.randi() % avail.size()]
		# Contraband is rarer in policed space; the caller decides where it lands.
		if pick.contraband and r.randf() > 0.35 + 0.05 * danger:
			avail.erase(pick)
			continue
		# AND SOME AFFIXES ARE SIMPLY SCARCER. A reactor pip is three cells of
		# capacity and half a point of energy a turn, against one currency for
		# every other gauge, so the two that pay it are rolled less often rather
		# than made weaker — see AffixData.weight. Erased either way, so a
		# refused pick costs the roll rather than looping on the same affix.
		if pick.weight < 1.0 and r.randf() > pick.weight:
			avail.erase(pick)
			continue
		avail.erase(pick)
		out.append(pick)
	return out

## A hull off a wreck. Draws from all ten frames, so a derelict can offer either
## an unbranded salvage frame or somebody's chassis — and a found chassis moves
## your set count, which is what makes "should I take it" a question with more
## than one number in it.
##
## The perk is REROLLED even on a manufacturer hull, unlike the one you start
## with, which keeps the perk its manufacturer authored. A ship you were handed at the
## yard is to spec; a ship you cut out of a wreck is whatever it ended up as.
## WHAT GRADE A YARD AT EACH TIER CAN OFFER, authored rather than derived.
##
## It was `int(danger / 1.6) + randi() % 2`, which put C on tier 1 alone -- the
## first ring or two of a fifteen-layer galaxy, and half of those rolls came out
## B anyway. So the bottom grade barely existed, and "bad ships on the outskirts"
## was a thing the arithmetic technically allowed rather than a thing you saw.
##
## Weighted by repetition, which is the same trick `TIER_DELTA` uses: a grade
## listed twice is twice as likely. Read down the columns and the ladder is
## legible -- C through the outer half, S only in the inner.
##
##   tier 1  C C B        outskirts: scrap, and the occasional decent frame
##   tier 2  C B B
##   tier 3  C B B A      the middle: a C is still possible and still cheap
##   tier 4  B A A S      S becomes reachable
##   tier 5  A S S        the core, where a bad ship would be a story
const GRADES_AT := {
	1: [0, 0, 1],
	2: [0, 1, 1],
	3: [0, 1, 1, 2],
	4: [1, 2, 2, 3],
	5: [2, 3, 3],
}

static func roll_hull(danger_in: int, r: RandomNumberGenerator = Rng.loot) -> HullData:
	var danger := MapGen.tier(danger_in)
	var base: HullData = Rng.pick(r, DB.hull_frames)
	var t: int = Rng.pick(r, GRADES_AT[danger])
	# The grade itself is AUTHORED now — see DB.TIER_DELTA. What used to happen
	# here was the whole tier system: a bag of bumps with a hardpoint on a coin
	# flip, so two A-class Bastions could differ by a mount and neither was the
	# ship the letter named.
	var h := DB.at_tier(base, t)
	# Jitter stays, because "a god-rolled B can rival a bad A" is a good property
	# and the authored table alone would make every B identical. It is CENTRED ON
	# ZERO now rather than added on top: the grade supplies the increase, this
	# only says how well this particular hull wore it. It widens with the grade
	# because there is more ship to vary.
	var spread := 1 + t
	h.max_hull = maxi(1, h.max_hull + r.randi_range(-spread, spread))
	h.heat_cap = maxi(1, h.heat_cap + r.randi_range(-1, 1))
	# THE MANUFACTURER PERK IS REROLLED, THE GRADE'S ARE NOT. A derelict is somebody
	# else's ship with an unknown yard behind it, so its manufacturer perk is a roll --
	# but `at_tier` granted the ladder its GRADE earns, and overwriting the one
	# must not quietly discard the other.
	h.perk_id = Rng.pick(r, DB.hull_perks.keys())
	# A C-TIER CARRIES SOMETHING ODD, and this is the only reason to buy one.
	#
	# `DB.tier_perks_for` starts at B, so a C has exactly one perk -- the
	# manufacturer's -- which is also all a STARTER hull has. Against the ship you
	# launched in, a C on the blocks was smaller, weaker, had fewer mounts and
	# offered nothing the starter did not: a purchase with no argument for it at
	# any price. One extra perk is the argument. It is a cheap frame somebody
	# else fitted out, and what they left in it is the point.
	#
	# ON THE HULL, NOT THE LADDER. Putting it in `TIER_PERKS` would grant it to
	# every C in the game including the one the player starts in, which is a
	# different change and not this one.
	if t == 0:
		var spare: Array = DB.hull_perks.keys().filter(
			func(k: StringName) -> bool: return k != h.perk_id)
		if not spare.is_empty():
			h.tier_perks = [Rng.pick(r, spare)] as Array[StringName]
	return h
