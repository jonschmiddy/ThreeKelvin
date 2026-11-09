class_name LootGen
extends RefCounted

## Region biasing makes set bonuses reachable by route choice, not luck.

## THE RARITY GATES, IN TIERS (`MapGen.tier`, 1-5), not in danger. Materials read
## the same numbers (`MaterialTable.TIER_MIN`), so the two ladders cannot drift.
const EPIC_TIER := 3
const LEGENDARY_TIER := 4
const NO_COMMON_TIER := 3

static func roll_module(danger_in: int, force_manufacturer: StringName = &"",
		allow_unbranded: bool = false,
		r: RandomNumberGenerator = Rng.loot) -> ModuleData:
	# Every threshold below was tuned against the five-tier ladder. Read the
	# wider scale through tier() rather than restating all of them.
	var danger := MapGen.tier(danger_in)
	# A forced manufacturer that cannot appear is rolled as open, or the pool empties.
	if force_manufacturer != &"" and not can_appear(force_manufacturer):
		force_manufacturer = &""

	var pool: Array[StringName] = []
	for id in DB.modules.keys():
		var m: ModuleData = DB.modules[id]
		# Yard stock is issued, not found, so wrecks do not crowd out branded parts.
		if m.starter_only:
			continue
		if m.rarity >= ModuleData.Rarity.EXOTIC and not allow_unbranded:
			continue
		if not can_appear(m.manufacturer):
			continue
		if force_manufacturer != &"" and m.manufacturer != force_manufacturer:
			continue
		# Deep loot appears deeper.
		if m.rarity == ModuleData.Rarity.EPIC and danger < EPIC_TIER:
			continue
		if m.rarity == ModuleData.Rarity.LEGENDARY and danger < LEGENDARY_TIER:
			continue
		pool.append(id)
	# From danger 5 no COMMON rolls anywhere (Jon, Oct 22); removed from the pool first.
	# Why: docs/why/LootGen.md#shallow-loot
	if danger >= NO_COMMON_TIER:
		var deep: Array[StringName] = []
		for id in pool:
			if (DB.modules[id] as ModuleData).rarity != ModuleData.Rarity.COMMON:
				deep.append(id)
		if not deep.is_empty():
			pool = deep
	if pool.is_empty():
		pool = [&"kh20"]

	var template: ModuleData = DB.modules[Rng.pick(r, pool)]
	var m := template.duplicate(true) as ModuleData

	# Small chance to upgrade rarity with depth.
	if m.rarity < ModuleData.Rarity.LEGENDARY and r.randf() < 0.06 * danger:
		# Through DB.regrade, so the pips the readout promises are the pips
		# the gauge moves.
		DB.regrade(m, int(m.rarity) + 1)

	m.affixes = _roll_affixes(_affix_count(m.rarity), danger, r)
	m.scrap_value = int(round(ModuleData.SCRAP_VALUE[m.rarity] * r.randf_range(0.8, 1.3)))
	return m

## The one gate: every drop, shelf and hull rolls through here, and new part sources should ask it.
## Why: docs/why/LootGen.md#manufacturer-gate
static func can_appear(manufacturer: StringName) -> bool:
	if manufacturer == &"":
		return true
	if not DB.ACTIVE_MANUFACTURERS.is_empty() and not DB.ACTIVE_MANUFACTURERS.has(manufacturer):
		return false
	return Run.unlocked_manufacturers.has(manufacturer)

## Eight entries for the eight-value enum: `_affix_count(CONTRABAND)` indexed past the end.
## Why: docs/why/LootGen.md#affix-counts
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
		# Reactor affixes are scarcer, not weaker; a refused pick is erased so it cannot loop.
		if pick.weight < 1.0 and r.randf() > pick.weight:
			avail.erase(pick)
			continue
		avail.erase(pick)
		out.append(pick)
	return out

## Salvage frames plus unlocked manufacturers, so a fresh profile never meets chassis it cannot fly.
## Why: docs/why/LootGen.md#hull-pool
static func hull_pool() -> Array[HullData]:
	var out: Array[HullData] = []
	for h in DB.hull_frames:
		if can_appear(h.manufacturer):
			out.append(h)
	return out

## Grades are authored by repetition, not derived: the sum made C almost nonexistent.
## A derelict hull's perk is rerolled; a yard-issued ship keeps its authored one.
## Why: docs/why/LootGen.md#hull-grades
const GRADES_AT := {
	1: [0, 0, 1],
	2: [0, 1, 1],
	3: [0, 1, 1, 2],
	4: [1, 2, 2, 3],
	5: [2, 3, 3],
}

static func roll_hull(danger_in: int, r: RandomNumberGenerator = Rng.loot) -> HullData:
	var danger := MapGen.tier(danger_in)
	var base: HullData = Rng.pick(r, hull_pool())
	var t: int = Rng.pick(r, GRADES_AT[danger])
	# Grade is authored (`DB.TIER_DELTA`), so two same-class hulls no longer differ by a mount.
	var h := DB.at_tier(base, t)
	# Jitter is centred on zero and widens with grade, so a good B can rival a bad A.
	var spread := 1 + t
	h.max_hull = maxi(1, h.max_hull + r.randi_range(-spread, spread))
	h.heat_cap = maxi(1, h.heat_cap + r.randi_range(-1, 1))
	# Only the manufacturer perk is rerolled; the grade's perks must not be discarded.
	h.perk_id = Rng.pick(r, DB.hull_perks.keys())
	# A C carries one extra perk, the only argument for buying one; on the hull, not the ladder.
	# Why: docs/why/LootGen.md#c-tier-oddity
	if t == 0:
		var spare: Array = DB.hull_perks.keys().filter(
			func(k: StringName) -> bool: return k != h.perk_id)
		if not spare.is_empty():
			h.tier_perks = [Rng.pick(r, spare)] as Array[StringName]
	return h
