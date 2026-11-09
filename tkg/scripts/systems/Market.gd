class_name Market
extends RefCounted

## A station never pays more for a part than it charges: every price is a fraction of one base
## value. Prices are pure functions of place and part, so nothing is stamped on the item or saved.
## Why: docs/why/Market.md#price-invariant

# ------------------------------------------------------------------ base value

## LootGen already rolls this per drop, so rarity, roll luck and the whole ladder are in it.
static func base_value(m: ModuleData) -> int:
	return m.scrap_value

# ----------------------------------------------------------------- the two axes

## Development is the supply chain; depth adds a little. A null node reads 1.0, as the chassis
## select has a hull and no galaxy yet.
## Why: docs/why/Market.md#price-indices
static func ask_index(n: MapGen.MapNode) -> float:
	if n == null:
		return 1.0
	var dev: float = [1.14, 1.06, 1.00, 0.94, 0.88][clampi(int(n.development), 0, 4)]
	return dev * (1.0 + 0.02 * float(MapGen.tier(n.danger) - 1))

## Derived from `berths`, which the chart already prints: no new state, and nothing to save.
## Why: docs/why/Market.md#demand
static func demand(n: MapGen.MapNode, manufacturer: StringName) -> float:
	if n == null:
		return 1.0
	if manufacturer == &"":
		# Unbranded: relic and organic tech. Nobody presses more of it anywhere,
		# so it is scarce in every market and never falls to a glut price.
		return 1.25
	if n.berths.has(manufacturer):
		return 0.78      # the manufacturer's own yard, thick with its own parts
	if n.berths.is_empty():
		return 1.00      # nobody's space, no opinion either way
	return 1.26          # a rival's yard: they need what they cannot press

## Contraband trades at a premium where nobody asks;
## the tag used to be only a fine, a pure downside.
const CONTRABAND_CEILING := 3     ## security above this will not touch it
const CONTRABAND_FENCE := 2       ## security at or below this pays over the odds

static func trades_contraband(n: MapGen.MapNode) -> bool:
	return n.security <= CONTRABAND_CEILING

static func _contraband_factor(n: MapGen.MapNode, m: ModuleData) -> float:
	if not m.contraband:
		return 1.0
	return 1.35 if n.security <= CONTRABAND_FENCE else 1.0

# --------------------------------------------------------------- the three prices

## MARKUP 1.5 is not free: the shop markups it replaced were 1.2, 1.5 and 1.9,
## so it keeps prices where they were. A restructuring, not a revaluation.
## Why: docs/why/Market.md#price-scale
const MARKUP := 1.5
## ASK_FLOOR 1.20 was measured: at 1.10 the margin was 9% and 200 sim runs came in four points
## below the old economy, so both moved up together.
## Why: docs/why/Market.md#price-scale
const ASK_FLOOR := 1.20
## A station's bid as a fraction of its own ask. The dealer's cut, and the reason
## selling a part back where you bought it is a loss.
const SPREAD := 0.62
## Melting pays a discount by design: full base value out-earned a shelf price.
## It is what you take when no market is in reach.
## Why: docs/why/Market.md#melting
const MELT := 0.80
const MELT_PERK := 1.4

## What the station charges for it.
static func ask(n: MapGen.MapNode, m: ModuleData) -> int:
	var v := float(base_value(m))
	var p := v * MARKUP * ask_index(n) * demand(n, m.manufacturer) * _contraband_factor(n, m)
	return maxi(1, int(round(maxf(p, v * ASK_FLOOR))))

## Standing pays only on the bid: a discount on ask big enough to notice puts melt above ask.
## bid stays a fraction of ask (0.62 x 1.20 is 0.744), so the sell-back loop stays closed.
## Why: docs/why/Market.md#bid
static func bid(n: MapGen.MapNode, m: ModuleData) -> int:
	if m.contraband and not trades_contraband(n):
		return 0
	var over := 1.0
	if n != null and n.manufacturer != &"":
		over += Run.standing_bid_bonus(n.manufacturer)
	return maxi(1, int(round(float(ask(n, m)) * SPREAD * _saturation(n) * over)))

## A filled market stops paying full price, or the haul question collapses into
## carrying everything to the best system. Mild: three sales cost a fifth, never below 60%.
## Why: docs/why/Market.md#saturation
static func _saturation(n: MapGen.MapNode) -> float:
	return maxf(0.6, pow(0.93, float(n.trades)))

## Melt does not depend on place: it is something the
## ship does, and a changing number would read as a bug.
static func melt(m: ModuleData) -> int:
	var v := float(base_value(m)) * MELT
	if Run.hull != null and Run.hull.has_perk(&"salvage_rack"):
		v *= MELT_PERK
	return maxi(1, int(round(v)))

# -------------------------------------------------------------------- materials

## Materials read off development, not the goods index:
## labs are where materials become worth something.
static func material_price(n: MapGen.MapNode, id: StringName) -> int:
	var base: float = float(int(MaterialTable.by_id(id).get("value", 1)))
	var dev := 2 if n == null else int(n.development)
	return maxi(1, int(round(base * (0.80 + 0.10 * float(dev)))))

# --------------------------------------------------------------------- services

## Centred on the outpost, as a table centred on SETTLEMENT made the common case 14% dearer.
## Recentring is not a difficulty change: 200 runs either side are inside each other's noise.
## Why: docs/why/Market.md#service-prices
static func service_index(n: MapGen.MapNode) -> float:
	if n == null:
		return 1.0
	return [1.12, 1.00, 0.88, 0.80, 0.74][clampi(int(n.development), 0, 4)]

## A float on purpose: an int priced three quarters of the ladder identically.
## This is the first lever for difficulty, so read CLAUDE.md's tuning rule before moving it.
## Why: docs/why/Market.md#repair-price
const REPAIR_BASE := 2.0

static func repair_rate(n: MapGen.MapNode) -> float:
	var r := REPAIR_BASE * service_index(n)
	if Run.hull != null and Run.hull.has_perk(&"cheap_parts"):
		r *= 0.5
	return r

static func repair_price(n: MapGen.MapNode, points: int) -> int:
	if points <= 0:
		return 0
	return maxi(1, int(round(repair_rate(n) * float(points))))

const REFUEL_UNITS := 25

## 32, up from 12 (Jon, Oct 18, fuel:A): at 12 fuel was 8 to 10% of a run's spending against
## repairs' 72 credits (balance check, seed 777, 2,600 runs), so it cost stops, never money.
## Why: docs/why/Market.md#refuel-price
const REFUEL_BASE := 32.0

static func refuel_price(n: MapGen.MapNode) -> int:
	return maxi(1, int(round(REFUEL_BASE * service_index(n))))

static func purge_price(n: MapGen.MapNode) -> int:
	return maxi(1, int(round(15.0 * service_index(n))))

## THE LAB'S TWO SERVICES ON A PART (science, pick 3A), the credits half of the
## bill; `Science.AUGMENT_DATA` and `STRIP_DATA` are the DATA half. Work, not
## goods, so they read off the service index like REPAIR and PURGE: AUGMENT is
## 22/20/18/16/15 from the rim to a capital, STRIP 11/10/9/8/7.
##
## NEITHER MOVES THE PART'S PRICE. `ask`, `bid` and `melt` read `scrap_value`,
## which is set once at the drop, so an augmented part sells for what the plain
## one does (`-- market` checks it). A part whose price rose with its affixes
## would turn DATA into credits, the one thing DATA must never be.
static func augment_price(n: MapGen.MapNode) -> int:
	return maxi(1, int(round(20.0 * service_index(n))))

static func strip_price(n: MapGen.MapNode) -> int:
	return maxi(1, int(round(10.0 * service_index(n))))

## A flyable hull on the pad. Goods, not work, so it reads off the goods index —
## and off the manufacturer who built it, exactly like a module does.
static func hull_price(n: MapGen.MapNode, h: HullData) -> int:
	# No MARKUP on hulls: the ladder already is the asking price, unlike a module's scrap value.
	var base := float(80 + h.tier * 70)
	return maxi(1, int(round(base * ask_index(n) * demand(n, h.manufacturer))))

## The hull had no exit: swapping ships was a full-price purchase, so upgrades were walls.
## Condition tracks `hp/max_hp`, or the exploit is flying a hull into the ground and selling it.
## Why: docs/why/Market.md#hull-trade-in
static func hull_bid(n: MapGen.MapNode, h: HullData) -> int:
	if h == null:
		return 0
	# The same SPREAD every other sale in this file uses. A hull is not a special
	# case of trading; it is the largest ordinary one.
	var condition := 1.0
	if Run.hull == h:
		condition = clampf(float(Run.hp) / float(maxi(1, Run.max_hp())),
			0.45, 1.0)
	return maxi(1, int(round(float(hull_price(n, h)) * SPREAD * condition)))


# ------------------------------------------------------------------- readouts

## States who the market is short of and glutted with, so the player need not infer it from prices.
static func trade_line(n: MapGen.MapNode) -> String:
	if n == null:
		return ""
	if n.type == MapGen.NodeType.CORE:
		return ""
	if n.berths.is_empty():
		# Two words is a state; the sentence repeated a tutorial the price already says.
		return "NO MARKET"
	var short: Array[String] = []
	for id in DB.STARTABLE:
		if not n.berths.has(id):
			short.append(DB.short_name(DB.manufacturer_name(id)).to_upper())
	var glut: Array[String] = []
	for id in n.berths:
		glut.append(DB.short_name(DB.manufacturer_name(id)).to_upper())
	# Only the glut is listed: naming five manufacturers it pays for is a list, not information.
	var out := "GLUT " + "/".join(glut)
	if short.size() <= 3:
		out += " - PAYS FOR " + "/".join(short)
	return out
