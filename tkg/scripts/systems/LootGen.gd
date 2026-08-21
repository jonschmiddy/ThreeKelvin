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
	# A Territory region can force a maker that the active-maker gate has switched
	# off. Honouring that would empty the pool and collapse every drop in the
	# region to the fallback, so treat it as an unbranded roll instead.
	if force_manufacturer != &"" and not _maker_active(force_manufacturer):
		force_manufacturer = &""

	var pool: Array[StringName] = []
	for id in DB.modules.keys():
		var m: ModuleData = DB.modules[id]
		if id == &"dross":
			continue
		# Yard stock is issued, not found. A wreck full of the same Hull Plating
		# you launched with would crowd out the branded parts that a run is
		# spent collecting, and the whole point of the generic kit is that it is
		# the thing you are trying to replace.
		if m.starter_only:
			continue
		if m.rarity >= ModuleData.Rarity.EXOTIC and not allow_unbranded:
			continue
		if not _maker_active(m.manufacturer):
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
	m.scrap_value = int(round([8, 16, 30, 55, 95, 120, 160][m.rarity] * r.randf_range(0.8, 1.3)))
	return m

## True when a maker may drop. Brand-agnostic modules (manufacturer &"") always
## pass — see DB.ACTIVE_MAKERS.
static func _maker_active(man: StringName) -> bool:
	return man == &"" or DB.ACTIVE_MAKERS.is_empty() or DB.ACTIVE_MAKERS.has(man)

static func _affix_count(r: ModuleData.Rarity) -> int:
	return [0, 1, 2, 3, 3, 3, 2][r]

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
		avail.erase(pick)
		out.append(pick)
	return out

static func make_dross() -> ModuleData:
	return (DB.modules[&"dross"] as ModuleData).duplicate(true) as ModuleData

## A hull off a wreck. Draws from all ten frames, so a derelict can offer either
## an unbranded salvage frame or somebody's chassis — and a found chassis moves
## your set count, which is what makes "should I take it" a question with more
## than one number in it.
##
## The perk is REROLLED even on a manufacturer hull, unlike the one you start
## with, which keeps the perk its maker authored. A ship you were handed at the
## yard is to spec; a ship you cut out of a wreck is whatever it ended up as.
static func roll_hull(danger_in: int, r: RandomNumberGenerator = Rng.loot) -> HullData:
	var danger := MapGen.tier(danger_in)
	var base: HullData = Rng.pick(r, DB.hull_frames)
	var t := clampi(int(danger / 1.6) + r.randi() % 2, 0, 3)
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
	h.perk_id = Rng.pick(r, DB.hull_perks.keys())
	return h
