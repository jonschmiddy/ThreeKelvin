class_name ScienceHaul
extends RefCounted

## What a science mini game pays. Its score and the sector decide the tier (the prototype's
## `tierOf`: depth raises the ceiling, not the floor, and a failure still pays common), and the
## tier pays one material (`pay`, the single seam the materials-by-source work replaces).
## Why: docs/why/MiniGame.md#the-haul

const TIER_NAMES: Array[String] = ["COMMON", "UNCOMMON", "RARE", "EPIC", "LEGENDARY", "EXOTIC", "ARTIFACT"]
const TIER_KEYS: Array[StringName] = [&"common", &"uncommon", &"rare", &"epic", &"legendary", &"exotic", &"artifact"]
## Where a science site's material comes from: a reading at a world, a belt or a comet is rock.
const SOURCE := {&"barren": &"mining", &"belt": &"mining", &"comet": &"mining"}
## The catalogue's rolled tables, the site's own first (`NAMED` drops are story pieces, never rolled).
const TABLES: Array[StringName] = [&"mining", &"wreck", &"event", &"fight", &"fauna"]


## Sector 1 tops out at RARE, 3 at EPIC, 5 at LEGENDARY; only a near-perfect run reaches the top.
static func tier_of(score: float, depth: int) -> int:
	var top := mini(4, 2 + (clampi(depth, 1, 5) - 1) / 2)
	return maxi(0, mini(top, int(floorf(clampf(score, 0.0, 1.0) * top + 0.15))))


## A catalogue row of `tier` from `source` if it has one, else from any rolled table, else the
## nearest lower tier that has one; {} when the catalogue holds nothing at or under it.
static func row_for(tier: int, source: StringName, r: RandomNumberGenerator) -> Dictionary[String, Variant]:
	var out: Dictionary[String, Variant] = {}
	for t in range(clampi(tier, 0, TIER_KEYS.size() - 1), -1, -1):
		var own: Array[Dictionary] = []
		var any: Array[Dictionary] = []
		for row in MaterialTable.all():
			if row.tier != TIER_KEYS[t] or not TABLES.has(row.drops):
				continue
			any.append(row)
			if row.drops == source:
				own.append(row)
		var pool := own if not own.is_empty() else any
		if not pool.is_empty():
			out.assign(pool[r.randi() % pool.size()])
			return out
	return out


## Pays the haul at the science site `site` of system `n`: one material, into the system as every
## grant goes (`MaterialTable.grant`). Returns {name, tier} (its own tier), or {} when nothing was paid.
static func pay(tier: int, site: StringName, n: MapGen.MapNode) -> Dictionary[String, Variant]:
	var out: Dictionary[String, Variant] = {}
	if n == null:
		return out
	var row := row_for(tier, StringName(SOURCE.get(site, &"mining")), Rng.derive(&"science_haul", n.index))
	if not row.is_empty():
		out.assign({name = MaterialTable.grant(row), tier = StringName(row.tier)})
	return out
