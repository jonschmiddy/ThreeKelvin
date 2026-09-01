class_name Market
extends RefCounted

## Every price in the game. One file, because a price that exists in two places
## eventually disagrees with itself — and this game's difficulty IS its economy,
## so a disagreement here is a difficulty bug nobody can see.
##
## THE INVARIANT, and the reason this file exists at all:
##
##     A STATION NEVER PAYS MORE FOR A PART THAN IT CHARGES FOR ONE.
##
## It used to. `_stock_up()` stamped a price at 1.2x scrap value while a
## `salvage_rack` hull melted the same part down for 1.5x, so buying a shelf out
## and scrapping it was free money — and the shelf restocked the moment it went
## empty, so it was free money on a loop. That was not a tuning error, it was a
## structural one: the buy price and the melt price were computed by two files
## that had never heard of each other.
##
## The fix is structural too. Every number below is a fraction of ONE base
## value, so the ordering is true by construction rather than by review:
##
##     melt  <=  MELT * MELT_PERK  =  1.12         (what a part melts down to)
##     bid   =   ask * SPREAD                       (what a station pays for it)
##     ask   >=  ASK_FLOOR         =  1.20          (what a station charges)
##
## 1.12 < 1.20, at every station in the galaxy, for every hull perk. There is no
## review step to forget and no second table to keep in step.
##
## WHAT REPLACES THE EXPLOIT. Round-tripping a part in one place is now a
## guaranteed loss, and that is correct: a scrapyard is not a market. The profit
## moved to where it belongs — the distance between two places. A manufacturer's own
## yard is thick with its own parts and buys them back at a glut price; a rival's
## yard needs parts it cannot press itself and pays for them. Buy Korvan in
## Korvan space, sell it in a Solari capital. The route is the trade.
##
## Prices are PURE FUNCTIONS of a place and a part. Nothing is stamped on the
## item and nothing is saved, which is why the "price" meta this file replaced is
## gone from SaveGame: a stored price is a second copy of a derivable number, and
## a station whose stored price came back missing quietly held a sale.

# ------------------------------------------------------------------ base value

## What a part is worth before anybody haggles. LootGen already rolls this per
## drop (the rarity table times 0.8-1.3), so rarity, roll luck and the whole
## ladder are already in it.
static func base_value(m: ModuleData) -> int:
	return m.scrap_value

# ----------------------------------------------------------------- the two axes

## How dear goods are HERE, before anyone asks which goods.
##
## Development is the supply chain: a capital has yards, brokers and competition;
## an outpost has one trader who knows you are not going anywhere else. Depth
## adds a little on top, because the deep galaxy is a long way from anything that
## presses parts.
## Null is a real input, not a defensive habit. The chassis select runs with a
## hull and no galaxy — you are picking a ship before there is anywhere to fly
## it — and it draws a HUD that asks what repairs cost. The honest answer with no
## place to stand in is the baseline, so both indices say 1.0 rather than
## indexing a node that does not exist yet.
static func ask_index(n: MapGen.MapNode) -> float:
	if n == null:
		return 1.0
	var dev: float = [1.14, 1.06, 1.00, 0.94, 0.88][clampi(int(n.development), 0, 4)]
	return dev * (1.0 + 0.02 * float(MapGen.tier(n.danger) - 1))

## How badly THIS place wants THAT manufacturer. The whole cross-system economy is these
## four lines.
##
## Derived from `berths`, which the chart already prints on every system, so the
## trade map is a map the player is already reading. No new state, nothing to
## discover by trial, and it survives a save because it is not stored.
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

## Contraband trades at a premium where nobody asks, and not at all where they
## do. This is the economic half of contraband — until now the tag only ever
## cost you a fine, which made it a pure downside with a damage number attached.
const CONTRABAND_CEILING := 3     ## security above this will not touch it
const CONTRABAND_FENCE := 2       ## security at or below this pays over the odds

static func trades_contraband(n: MapGen.MapNode) -> bool:
	return n.security <= CONTRABAND_CEILING

static func _contraband_factor(n: MapGen.MapNode, m: ModuleData) -> float:
	if not m.contraband:
		return 1.0
	return 1.35 if n.security <= CONTRABAND_FENCE else 1.0

# --------------------------------------------------------------- the three prices

## The scale everything below sits on, and it is not a free parameter: the shop
## markups it replaced were 1.2 on the frontier, 1.5 at a crossroads and 1.9 at a
## fence, so 1.5 times an index that runs either side of 1.0 puts the new prices
## where the old ones were. This is a restructuring of the economy, not a
## revaluation of it.
const MARKUP := 1.5
## No station sells below this multiple of base value. It is what keeps the melt
## price underneath every ask in the galaxy — see the invariant at the top.
## Measured, not chosen. At 1.10 the floor sat under a melt price of 1.01 with a
## nine percent margin, and 200 sim runs came in four points below the economy it
## replaced — the discount on melting was doing more work than the premium on
## selling. Both moved up together, which keeps the ordering and returns the
## income.
const ASK_FLOOR := 1.20
## A station's bid as a fraction of its own ask. The dealer's cut, and the reason
## selling a part back where you bought it is a loss.
const SPREAD := 0.62
## What a part melts down to, and what a `salvage_rack` hull adds to that.
##
## Melting used to pay full base value, which is what let it out-earn a shelf
## price and is the arithmetic the exploit was made of. It now pays a discount —
## and the discount is the design, not a nerf looking for a home: an average
## market pays about what melting used to, a market that wants what you are
## carrying pays half again more, and melting is what you take when there is no
## market within reach. The floor moved down so that a ceiling could exist.
const MELT := 0.80
const MELT_PERK := 1.4

## What the station charges for it.
static func ask(n: MapGen.MapNode, m: ModuleData) -> int:
	var v := float(base_value(m))
	var p := v * MARKUP * ask_index(n) * demand(n, m.manufacturer) * _contraband_factor(n, m)
	return maxi(1, int(round(maxf(p, v * ASK_FLOOR))))

## What the station pays for it. Always below `ask` at the same station, by
## construction, whatever the part and whoever built it.
## STANDING PAYS HERE AND NOWHERE ELSE, and that is a constraint from the
## invariant at the top of this file rather than a design preference.
##
## Between `melt` at 1.12 and `ASK_FLOOR` at 1.20 there is about seven percent of
## room. Any discount on the ask large enough for a player to notice puts melt
## above ask, and buying a part to melt it becomes free money — which is the one
## thing this file exists to make impossible.
##
## Paying more for what you carry IN has no such edge. bid is a fraction of ask
## and stays one: 0.62 x 1.20 is 0.744, still comfortably under what the same
## station charges for the same part, so the sell-back loop stays closed.
static func bid(n: MapGen.MapNode, m: ModuleData) -> int:
	if m.contraband and not trades_contraband(n):
		return 0
	var over := 1.0
	if n != null and n.manufacturer != &"":
		over += Run.standing_bid_bonus(n.manufacturer)
	return maxi(1, int(round(float(ask(n, m)) * SPREAD * _saturation(n) * over)))

## A market you have already emptied your hold into stops paying full price.
##
## Without this, one good station absorbs an unlimited number of parts at the
## same rate, and the interesting question — which of these do I haul, and how
## far — collapses into "carry everything to the best system you have seen".
## Mild on purpose: three sales cost about a fifth, and it never falls past 60%.
static func _saturation(n: MapGen.MapNode) -> float:
	return maxf(0.6, pow(0.93, float(n.trades)))

## What it melts down to. Deliberately NOT a function of where you are: melting a
## part is something the ship does to it, not a deal you struck, and a number
## that changed as you flew would read as a bug on the SCRAP button. It is the
## floor under every part in the game — the price you can always get, anywhere,
## with no station and no route.
static func melt(m: ModuleData) -> int:
	var v := float(base_value(m)) * MELT
	if Run.hull != null and Run.hull.has_perk(&"salvage_rack"):
		v *= MELT_PERK
	return maxi(1, int(round(v)))

# -------------------------------------------------------------------- materials

## What a station pays for one unit of a raw material.
##
## Labs are where materials become worth something, so this reads off development
## rather than off the goods index — an exotic organ is worth more to a capital
## with a biology department than to a mining outpost that would use it as ballast.
static func material_price(n: MapGen.MapNode, id: StringName) -> int:
	var base: float = float(int(MaterialTable.by_id(id).get("value", 1)))
	var dev := 2 if n == null else int(n.development)
	return maxi(1, int(round(base * (0.80 + 0.10 * float(dev)))))

# --------------------------------------------------------------------- services

## How dear WORK is here. Separate from `ask_index` because they are different
## economies: a frontier outpost is short of parts AND short of the people who
## fit them, and both shortages are steeper than the goods curve.
## Centred on the OUTPOST, not on the middle of the ladder.
##
## A run spends most of its jumps out where development rolls 0 or 1, so a table
## centred on SETTLEMENT quietly made the common case 14% dearer than the flat
## rate it replaced. Recentring is not a difficulty change and the simulator says
## so — 200 runs either side of it are inside each other's noise. It is the
## honest statement of the intent: this table adds a GRADIENT to service prices,
## and an outpost still charges what everywhere used to charge.
static func service_index(n: MapGen.MapNode) -> float:
	if n == null:
		return 1.0
	return [1.12, 1.00, 0.88, 0.80, 0.74][clampi(int(n.development), 0, 4)]

## Scrap per hull point. A float on purpose: rounding to an int gave a cliff
## where a Settlement and an Outpost charged the same 2 and a City charged 2 as
## well, so three quarters of the ladder priced identically.
##
## This is the stated first lever for the whole game's difficulty. Read
## CLAUDE.md's tuning rule before moving it.
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

static func refuel_price(n: MapGen.MapNode) -> int:
	return maxi(1, int(round(12.0 * service_index(n))))

static func purge_price(n: MapGen.MapNode) -> int:
	return maxi(1, int(round(15.0 * service_index(n))))

static func coolant_price(n: MapGen.MapNode) -> int:
	return maxi(1, int(round(30.0 * service_index(n))))

## A flyable hull on the pad. Goods, not work, so it reads off the goods index —
## and off the manufacturer who built it, exactly like a module does.
static func hull_price(n: MapGen.MapNode, h: HullData) -> int:
	# The 80 + 70/tier ladder is unchanged; only where you buy it now matters.
	# No MARKUP on this one — the ladder already IS the asking price, unlike a
	# module's scrap value, which is what the part is worth rather than what a
	# yard wants for it.
	var base := float(80 + h.tier * 70)
	return maxi(1, int(round(base * ask_index(n) * demand(n, h.manufacturer))))

# ------------------------------------------------------------------- readouts

## One line naming who this market is short of and who it is glutted with, for
## the chart and the station header. This is the trade map made readable: the
## rule is simple enough to state, so state it rather than making the player
## infer it from prices they can only see after they arrive.
static func trade_line(n: MapGen.MapNode) -> String:
	if n == null:
		return ""
	if n.type == MapGen.NodeType.CORE:
		return ""
	if n.berths.is_empty():
		# The tail said what a flat rate MEANS, which the price beside it already
		# says every time you read one. Two words is a state; the sentence was a
		# tutorial repeated on every visit.
		return "NO MARKET"
	var short: Array[String] = []
	for id in DB.STARTABLE:
		if not n.berths.has(id):
			short.append(DB.short_name(DB.manufacturer_name(id)).to_upper())
	var glut: Array[String] = []
	for id in n.berths:
		glut.append(DB.short_name(DB.manufacturer_name(id)).to_upper())
	# Naming five manufacturers it pays for is a list, not information. The glut is the
	# short list and the actionable one — it is what you should not be carrying
	# in, and what you should be buying while you are here.
	var out := "GLUT " + "/".join(glut)
	if short.size() <= 3:
		out += " - PAYS FOR " + "/".join(short)
	return out
