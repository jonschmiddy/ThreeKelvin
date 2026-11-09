class_name PartyScale
extends RefCounted

## The party's size sets the enemy's hull and the pay, globally, not per fight (Jon, Nov 5).
## The count is the host's; an open fight keeps its count. Hull only, never damage.
## Why: docs/why/PartyScale.md#party-scale

## What each player past the first adds to every enemy's hull, as a share of
## its solo hull. Measured so a party of two with both ships in the fight
## takes about as many rounds as one ship alone.
const HULL_PER := 1.1
## What each player past the first adds to what a kill or an event pays, as a
## share of the solo pay: one more player, one more share, so a party that
## splits every wreck and every event evenly is each paid what a lone pilot is.
const LOOT_PER := 1.0


## The enemy's hull multiplier for a game of `n` players.
static func hull(n: int) -> float:
	return 1.0 + HULL_PER * float(_n(n) - 1)


## The pay multiplier for a game of `n` players.
static func loot(n: int) -> float:
	return 1.0 + LOOT_PER * float(_n(n) - 1)


## The players in this game now, as the host says: 1 alone.
static func players() -> int:
	return Net.party_count()


## `v` credits, or any count of things paid, for `n` players (-1: this game's
## count now). Rounded; never less than `v`, so a pay of 1 is never cut.
static func pay(v: int, n: int = -1) -> int:
	var k := _n(players() if n < 0 else n)
	if k <= 1 or v <= 0:
		return v
	return maxi(v, int(round(float(v) * loot(k))))


## A hull built for `n` players, from one built for one: the Hellbender opens
## at the hull it carries between fights times the party's share.
static func party_hull(solo_hp: int, n: int) -> int:
	return maxi(1, int(round(float(solo_hp) * hull(n))))


## And back: what a hull built for `n` players is for one, so the Hellbender's
## hull between fights stays in one ship's terms whoever fought it.
static func solo_hull(hp: int, n: int) -> int:
	return maxi(1, int(round(float(hp) / hull(n))))


static func _n(n: int) -> int:
	return clampi(n, 1, NetTransport.MAX_PLAYERS)
