The reasoning behind `tkg/scripts/systems/Market.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Price invariant

Above `static func base_value(m: ModuleData) -> int:`:

```text
Every price in the game. One file, because a price that exists in two places
eventually disagrees with itself — and this game's difficulty IS its economy,
so a disagreement here is a difficulty bug nobody can see.

THE INVARIANT, and the reason this file exists at all:

    A STATION NEVER PAYS MORE FOR A PART THAN IT CHARGES FOR ONE.

It used to. `_stock_up()` stamped a price at 1.2x scrap value while a
`salvage_rack` hull melted the same part down for 1.5x, so buying a shelf out
and scrapping it was free money — and the shelf restocked the moment it went
empty, so it was free money on a loop. That was not a tuning error, it was a
structural one: the buy price and the melt price were computed by two files
that had never heard of each other.

The fix is structural too. Every number below is a fraction of ONE base
value, so the ordering is true by construction rather than by review:

    melt  <=  MELT * MELT_PERK  =  1.12         (what a part melts down to)
    bid   =   ask * SPREAD                       (what a station pays for it)
    ask   >=  ASK_FLOOR         =  1.20          (what a station charges)

1.12 < 1.20, at every station in the galaxy, for every hull perk. There is no
review step to forget and no second table to keep in step.

WHAT REPLACES THE EXPLOIT. Round-tripping a part in one place is now a
guaranteed loss, and that is correct: a scrapyard is not a market. The profit
moved to where it belongs — the distance between two places. A manufacturer's own
yard is thick with its own parts and buys them back at a glut price; a rival's
yard needs parts it cannot press itself and pays for them. Buy Korvan in
Korvan space, sell it in a Solari capital. The route is the trade.

Prices are PURE FUNCTIONS of a place and a part. Nothing is stamped on the
item and nothing is saved, which is why the "price" meta this file replaced is
gone from SaveGame: a stored price is a second copy of a derivable number, and
a station whose stored price came back missing quietly held a sale.
```

## Price indices

Above `static func ask_index(n: MapGen.MapNode) -> float:`:

```text
How dear goods are HERE, before anyone asks which goods.

Development is the supply chain: a capital has yards, brokers and competition;
an outpost has one trader who knows you are not going anywhere else. Depth
adds a little on top, because the deep galaxy is a long way from anything that
presses parts.
Null is a real input, not a defensive habit. The chassis select runs with a
hull and no galaxy — you are picking a ship before there is anywhere to fly
it — and it draws a HUD that asks what repairs cost. The honest answer with no
place to stand in is the baseline, so both indices say 1.0 rather than
indexing a node that does not exist yet.
```

## Demand

Above `static func demand(n: MapGen.MapNode, manufacturer: StringName) -> float:`:

```text
How badly THIS place wants THAT manufacturer. The whole cross-system economy is these
four lines.

Derived from `berths`, which the chart already prints on every system, so the
trade map is a map the player is already reading. No new state, nothing to
discover by trial, and it survives a save because it is not stored.
```

## Price scale

Above `const MARKUP := 1.5`:

```text
The scale everything below sits on, and it is not a free parameter: the shop
markups it replaced were 1.2 on the frontier, 1.5 at a crossroads and 1.9 at a
fence, so 1.5 times an index that runs either side of 1.0 puts the new prices
where the old ones were. This is a restructuring of the economy, not a
revaluation of it.
```

Above `const ASK_FLOOR := 1.20`:

```text
No station sells below this multiple of base value. It is what keeps the melt
price underneath every ask in the galaxy — see the invariant at the top.
Measured, not chosen. At 1.10 the floor sat under a melt price of 1.01 with a
nine percent margin, and 200 sim runs came in four points below the economy it
replaced — the discount on melting was doing more work than the premium on
selling. Both moved up together, which keeps the ordering and returns the
income.
```

## Melting

Above `const MELT := 0.80`:

```text
What a part melts down to, and what a `salvage_rack` hull adds to that.

Melting used to pay full base value, which is what let it out-earn a shelf
price and is the arithmetic the exploit was made of. It now pays a discount —
and the discount is the design, not a nerf looking for a home: an average
market pays about what melting used to, a market that wants what you are
carrying pays half again more, and melting is what you take when there is no
market within reach. The floor moved down so that a ceiling could exist.
```

## Bid

Above `static func bid(n: MapGen.MapNode, m: ModuleData) -> int:`:

```text
What the station pays for it. Always below `ask` at the same station, by
construction, whatever the part and whoever built it.
STANDING PAYS HERE AND NOWHERE ELSE, and that is a constraint from the
invariant at the top of this file rather than a design preference.

Between `melt` at 1.12 and `ASK_FLOOR` at 1.20 there is about seven percent of
room. Any discount on the ask large enough for a player to notice puts melt
above ask, and buying a part to melt it becomes free money — which is the one
thing this file exists to make impossible.

Paying more for what you carry IN has no such edge. bid is a fraction of ask
and stays one: 0.62 x 1.20 is 0.744, still comfortably under what the same
station charges for the same part, so the sell-back loop stays closed.
```

## Saturation

Above `static func _saturation(n: MapGen.MapNode) -> float:`:

```text
A market you have already emptied your hold into stops paying full price.

Without this, one good station absorbs an unlimited number of parts at the
same rate, and the interesting question — which of these do I haul, and how
far — collapses into "carry everything to the best system you have seen".
Mild on purpose: three sales cost about a fifth, and it never falls past 60%.
```

## Service prices

Above `static func service_index(n: MapGen.MapNode) -> float:`:

```text
How dear WORK is here. Separate from `ask_index` because they are different
economies: a frontier outpost is short of parts AND short of the people who
fit them, and both shortages are steeper than the goods curve.
Centred on the OUTPOST, not on the middle of the ladder.

A run spends most of its jumps out where development rolls 0 or 1, so a table
centred on SETTLEMENT quietly made the common case 14% dearer than the flat
rate it replaced. Recentring is not a difficulty change and the simulator says
so — 200 runs either side of it are inside each other's noise. It is the
honest statement of the intent: this table adds a GRADIENT to service prices,
and an outpost still charges what everywhere used to charge.
```

## Repair price

Above `const REPAIR_BASE := 2.0`:

```text
Scrap per hull point. A float on purpose: rounding to an int gave a cliff
where a Settlement and an Outpost charged the same 2 and a City charged 2 as
well, so three quarters of the ladder priced identically.

This is the stated first lever for the whole game's difficulty. Read
CLAUDE.md's tuning rule before moving it.
```

## Refuel price

Above `const REFUEL_BASE := 32.0`:

```text
A can of REFUEL_UNITS at an outpost (index 1.00). 32, up from 12 (Jon,
Oct 18: "fuel:A"): a whole 45 tank from empty is a can and 20 units by the
unit, 32 + 26 = 58 credits at an outpost -- 65 on the frontier, 44 in a
capital. At 12 a tank cost 22 and fuel was 8-10% of a run's spending against
repairs' 72 credits (balance check, seed 777, 2,600 runs): it cost stops,
never money.
```

## Hull trade-in

Above `static func hull_bid(n: MapGen.MapNode, h: HullData) -> int:`:

```text
WHAT THE YARD WILL GIVE YOU FOR THE FRAME YOU FLEW IN ON.

THE HULL WAS THE ONLY OBJECT IN THE GAME WITH NO EXIT. A module has `bid` and
`melt`, a material has `material_price`, and a hull had `hull_price` and
nothing facing the other way -- so swapping ships was a PURCHASE, at full
asking price, with the most expensive thing you owned deleted to make room
for it. That made every upgrade a wall you saved at rather than a ladder you
climbed, and it made downgrading -- sell the heavy, fly a light, spend the
difference on parts -- not a play at all.

Priced off `hull_price` rather than off its own ladder, so the two can never
drift: this is the same frame seen from the other side of the counter, and
the discount between them is the yard's margin.

CONDITION IS THE SECOND TERM, and it is what stops the obvious exploit. If a
trade-in paid flat, the move would be to fly a hull into the ground, take the
full price for the wreck, and repeat -- so what it pays tracks `hp/max_hp`,
floored well above zero because even a burnt-out frame is worth its metal.
```

## The labs two services on a

Above `static func augment_price(n: MapGen.MapNode) -> int:`:

```text
THE LAB'S TWO SERVICES ON A PART (science, pick 3A), the credits half of the
bill; `Science.AUGMENT_DATA` and `STRIP_DATA` are the DATA half. Work, not
goods, so they read off the service index like REPAIR and PURGE: AUGMENT is
22/20/18/16/15 from the rim to a capital, STRIP 11/10/9/8/7.

NEITHER MOVES THE PART'S PRICE. `ask`, `bid` and `melt` read `scrap_value`,
which is set once at the drop, so an augmented part sells for what the plain
one does (`-- market` checks it). A part whose price rose with its affixes
would turn DATA into credits, the one thing DATA must never be.
```
