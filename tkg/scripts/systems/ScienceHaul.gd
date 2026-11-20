class_name ScienceHaul
extends RefCounted

## What a science mini game pays. Its score and the sector decide the tier (the prototype's
## `tierOf`: depth raises the ceiling, not the floor, and a failure still pays common), and the
## tier pays one material from the site's source (`MaterialTable.pick`, then `grant`).
## Why: docs/why/MiniGame.md#the-haul

## The material each site group pays (Jon, Nov 18 groups; the material list's sources, Nov 19).
const SOURCE := {&"rock": &"mining", &"sky": &"cosmic", &"pulsar": &"cosmic", &"life": &"fauna", &"wreck": &"wreck"}
## The group a reading's site is in: worlds, belts and comets are rock (today's science readings),
## stars and giants sky, derelicts wreck. A group's own name stands for itself.
const GROUP := {&"barren": &"rock", &"belt": &"rock", &"comet": &"rock", &"star": &"sky", &"giant": &"sky",
	&"derelict": &"wreck"}


## Sector 1 tops out at RARE, 3 at EPIC, 5 at LEGENDARY; only a near-perfect run reaches the top.
static func tier_of(score: float, depth: int) -> int:
	var top := mini(4, 2 + (clampi(depth, 1, 5) - 1) / 2)
	return maxi(0, mini(top, int(floorf(clampf(score, 0.0, 1.0) * top + 0.15))))


## The tier's key in the material ladder (`MaterialTable.TIERS`: common .. artifact).
static func tier_key(tier: int) -> StringName:
	return MaterialTable.TIERS[clampi(tier, 0, MaterialTable.TIERS.find(&"artifact"))]


## The source a site's haul comes from: its group's, rock when the site is not a science place.
static func source_of(site: StringName) -> StringName:
	return SOURCE.get(GROUP.get(site, site), &"mining")


## Pays the haul at the science site `site` of system `n`: one material of the tier (or the nearest
## lower one the source has), into the system as every grant goes. Returns {name, tier} (the row's
## own tier), or {} when nothing was paid.
static func pay(tier: int, site: StringName, n: MapGen.MapNode) -> Dictionary[String, Variant]:
	var out: Dictionary[String, Variant] = {}
	if n == null:
		return out
	var row := MaterialTable.pick(source_of(site), tier_key(tier), Rng.derive(&"science_haul", n.index))
	if not row.is_empty():
		out.assign({name = MaterialTable.grant(row), tier = StringName(row.tier)})
	return out
