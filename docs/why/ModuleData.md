The reasoning behind `tkg/scripts/data/ModuleData.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Grade ladder

Above `enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY, EXOTIC, ARTIFACT,`:

```text
THE GRADE LADDER, and it is a ladder of PROVENANCE as much as of power.

Common through Legendary is one manufacturer doing its job better. Exotic and
Artifact leave the manufacturers entirely — grown and precursor, which is why
LootGen gates both behind `allow_unbranded`.

CONTRABAND is the eighth and the only one that is a fact about WHO, not
about what: a part nobody will admit to selling. RULING, NOT YET BUILT —
contraband comes only from the Probate Combine, Redline and Cygnet, the
scrappers, the hackers and the technologists, because those are the three
manufacturers with a reason to move something off the manifest. Recorded here
rather than in a note because the enum is what a future module will pick
from; the sourcing belongs in LootGen's pool filter beside the
`allow_unbranded` gate, which currently swallows CONTRABAND along with
EXOTIC and ARTIFACT and will need saying differently when the parts exist.
```

## Passive gauges

Above `@export_group("Passive")`:

```text
What this part adds to the SHIP'S GAUGES — not to a display number.

These were missing, and the gap was invisible because the two above are not.
Sensors and Stealth had no gauge anywhere in the game, so they were summed
across `installed` from the day they existed. The other four attributes are
derived from hp, heat and dodge — gauges that predate modules having any
passive stat at all — so `RunState.max_hp()` returned `hull.max_hull` and
stopped there. A ship with three armour plates bolted on had exactly the hull
of a ship with none, on the ship tab AND in every fight.

Deliberately the same field names as HullData, because the sum is literally
`hull.x + Σ module.x` and two vocabularies for one quantity is how the two
halves drift apart.

`fuel_factor` is signed and does DOUBLE DUTY: it drives Thrust upward and the
price of a jump upward with it, which is the trade a bigger engine is. No
module in the catalog carries a value for it today — see _seed_module_passives.
```

## Thrust

Above `@export var thrust: int = 0`:

```text
How far this part raises the ship's THRUST.

SEPARATE FROM `fuel_factor`, which it used to be welded to. THRUST read
`fuel_factor * 4.7`, so the gauge and the cost of a jump were one number:
a part that made the ship thriftier also made it worse at thrust checks,
which is precisely backwards. Fuel is what a jump COSTS; thrust is what the
engine can DO.
```

## Reactor

Above `@export var reactor: int = 0`:

```text
How far this part raises the ship's REACTOR, in levels.

LEVELS AND NOT CELLS, since the reactor turned round. A coupling used to
grant six cells and the gauge worked out what that was worth; now it grants
two levels and RunState.REACTOR_TABLE says what those are worth — six cells
and, at some steps, a point of energy. The part's number and the number on
the bar are the same number.

SELF-LIMITING BY CONSTRUCTION, which is why it is safe on a module at all: a
part that grants capacity also OCCUPIES capacity, so a 2x2 armature granting
six cells leaves two. The ceiling is how many mounts the frame has.
```

## Starter parts

Above `@export var starter_only: bool = false`:

```text
Issued with a ship, never found on one.

The generic kit every chassis launches with. Kept out of the loot pool
deliberately: they exist so the deck has a floor, and a floor that keeps
turning up in wrecks would crowd out the branded parts you are flying around
to collect. You start with them and you replace them.
```

## Mounts

Above `@export var mount: int = -1`:

```text
WHICH hardpoint this is bolted to, within its slot type. -1 when in the hold.

ShipView has always drawn the fitted modules at fixed places on the hull —
weapon 0 is the dorsal ordnance, 1 the ventral barrels, 2 the aft mount — but
it read that index from the ORDER of the installed array, so the positions
were an accident of how you happened to fit things and shuffled when you
removed something. Storing it makes a mount a place you choose: leave the
dorsal empty and hang everything off the spine if that is the ship you want.

Runtime state, not content. Every template in DB carries -1; the value only
means anything on the duplicate actually bolted to a hull, and SaveGame
carries it so a reloaded ship looks like the one you built.
```

## Hold size

Above `@export var flipped: bool = false`:

```text
How much room the part takes UP IN THE HOLD, in grid cells. Never on the ship.

The hold is a grid you pack; a hardpoint still takes exactly one module
however big it is. Those are two different questions — "will this fit in the
truck" and "does this ship have a mount for it" — and tying them together
would put cell counts into `slots_used()`, set-bonus counting, `Policy` and
`HeadlessSim`, none of which are asking about volume.

Four shapes, and the shape is a description rather than a rating:

  1x1  a fitting        sights, a patch kit, a coolant line
  1x2  a compact unit   most systems, a short weapon
  1x3  something LONG   a barrel, a lance, a rail
  2x2  something BULKY  a bay, an array, heavy plating, a reactor

So a hold full of long things is visibly a hold full of guns, before any word
is read. Deliberately NOT keyed to rarity: a Legendary sight is still a sight,
and making the good ones big would turn packing into a second power budget
rather than a physical one.
Moved to `HoldItem`, which every hold function now takes. The vocabulary
note above is the reason it is worth having at all.
```

## Hold turning

Above `@export var flipped: bool = false`:

```text
Turned on its side in the hold. A 1x3 lance laid flat is a 3x1.

Kept as a FLAG rather than by rewriting `size`, so the part's authored shape
survives being turned and turned back — and so a hull swap, which repacks the
whole hold, does not slowly grind every long thing into whatever orientation
it last happened to fit in.
Moved to `HoldItem`.
```

## Hull mirroring

Above `@export var flipped: bool = false`:

```text
MIRRORED ON THE HULL, top to bottom. Per fitted part, and nothing to do
with `turned`: that one is about packing a shape into the hold, this is
about which way up the object reads once it is bolted on. A gun on the
ventral line is the same gun as one on the spine, hanging the other way.

Drawing only. It moves no number, so nothing in the sim reads it.
```

## Hold position

Above `@export var affixes: Array[AffixData] = []`:

```text
WHERE in the hold grid, top-left cell. (-1, -1) while not in the hold.

Runtime state exactly as `mount` is, and stored for the same reason: the hold
is a place you arrange, so a part has to come back where you left it. Deriving
it from array order would re-pack the hold every time something was removed,
which is the behaviour `mount` was changed away from.
Moved to `HoldItem`.
```

## Affix sums

Above `func affix_raw(field: StringName) -> float:`:

```text
What this part's affixes add to one raw passive field.

The sums in RunState read this beside the authored value. It is COMPUTED
rather than baked into the fields for the reason AffixData.raw_for gives:
a saved module comes back as a fresh template plus a list of affix names, so
a baked bonus does not survive being loaded.
```

## Scrap value

Above `const SCRAP_VALUE := [8, 16, 30, 55, 95, 120, 160]`:

```text
What a part is worth broken down, by rarity.

Lived in three files — Database's seeder, LootGen's roller and MarketTest's
fixture — all spelling the same seven numbers. That is the same "one price,
defined once" discipline the rest of the economy is held to by Market.gd, and
a rarity tuning pass had to be remembered in three places, one of them a test
that would have gone on agreeing with an old table.
```

## Rarity colours

Above `static func rarity_colour(r: Rarity) -> Color:`:

```text
WHAT A GRADE IS. The ground its plate is painted on, and — for seven of
the eight — the colour its name is written in as well.

Exotic is PINK and Artifact is RED. Exotic was a teal that sat two steps
from Rare's blue, so the two rarest branded grades read as cool neighbours
of the middle of the ladder instead of as the end of it. Pink and red are
the two hues nothing else on the ladder uses, and they are warm where
Common through Epic are cold, so the top of the ladder now separates from
the body of it before any name is read.

COMMON IS NEUTRAL GREY AND UNCOMMON IS A REAL GREEN, and measuring the old
pair says the same thing the Epic one did. Common was #8fa3ba at 23%
saturation and Uncommon #7fb89a at 31%: 60 degrees of hue between them and
it did not matter, because at that saturation and that lightness they were
two tints of the same pale nothing.

The bigger find was that Common was BLUE — 208 degrees, five degrees off
Rare's 213 — so the bottom of the ladder was in Rare's own hue family and
told apart only by being washed out. Making Common a near-neutral grey
fixes both collisions with one value, and it is what Common should have
been anyway: the grade that has no colour, because it has no claim.

EPIC IS A DEEPER VIOLET for the same reason one rung lower, and the fix is
SATURATION rather than hue. It was #a97fd4, and measuring it says why that
did not work: 270 degrees against Rare's 213, which is a real 57 degrees of
separation — but at 40% saturation and the same blue channel, so two
adjacent rungs arrived as one pale cool family and the word underneath was
doing all the work. #8b4fd4 is the same hue at 63%. The plate is 30 pixels
across and the name is not on it.

CONTRABAND IS BLACK, and black is darker than the screen it is drawn on.
That is deliberate and it is the reason `rarity_ink` exists below: a
contraband plate has no ground you can see, only an edge — the shape of a
part with nothing filled in, which is what a thing that is not on the
manifest should look like.
```

## Rarity ink

Above `static func rarity_ink(r: Rarity) -> Color:`:

```text
WHAT A GRADE IS WRITTEN IN. The same colour, except where the colour
cannot be written.

Black text on a black background is not a style, it is a card whose name
you cannot read — and rarity_colour is used as an ink in five places (the
card's name, three readouts, and the plate's edge) as well as a ground in
one. Those are two different jobs and they only looked like one job while
every grade happened to be a mid-tone.

Contraband's ink is BONE, not white: white is the theme's emphasis colour
and would make the rarest thing in the game read as merely selected.
Enforced by `-- holdtest`, which will not let an ink onto the void the eye
cannot separate from it.
```

## Grant count law

Above `func grant_count() -> int:`:

```text
THE GRANT COUNT LAW.

How many cards this module puts in the deck. Fixed by module CLASS, never by
rarity — a legendary drop must not make the deck clumsier, because "declining
the reward" arithmetic has no place in a loot game. Rarity buys better verbs
and bigger magnitudes; it never buys more cards.

Making the count a function of class rather than a per-module number means
the invariant "a rarer module never produces a larger deck than its common
sibling" is true BY CONSTRUCTION. There is no review step to forget.

Manufacturer is allowed to vary it, because that is build identity with a
number behind it: Verity grants fewer, better cards — the thin perfect deck
the manufacturer is named for, made mechanical instead of flavourful.
TWO, FROM EVERY MODULE. It was 2 for weapons and systems and 1 for utilities,
on the reading that a utility is the situational third slot — and the reading
was sound but the result was not: a utility was a part you found, packed and
bolted on for a single card, which made half the catalogue feel like a
rounding error next to a gun.

Two lets a module be a COMBINATION rather than a verb with a name on it. A
part can carry its headline card and a plain one beside it, and two parts can
share a card while each keeping something of their own — which is what makes
a catalogue of sixty read as more than sixty things.

Measured before and after at seed 4242 over 200 runs; the numbers are in the
commit that made the change.

VERITY IS THE EXCEPTION AND STILL GRANTS ONE. That is a ruling, not an
oversight — the manufacturer is named for the thin perfect deck and this is the only
place that claim is mechanical rather than flavour. It does now mean "every
module grants two" is true of six manufacturers out of seven.
```

## Card rarity law

Above `func card_rarities() -> Array[int]:`:

```text
Cards with affixes baked in, ready for the deck.

Exactly grant_count() of them, drawn from the authored list and cycling if
the module authors fewer distinct verbs than it grants. `copies` on a card is
now a WEIGHT within that draw rather than a count of its own — the number of
cards is the class's business, not the card's.
THE CARD RARITY LAW. What the two cards a module grants are allowed to be.

Decided by how many CELLS the part occupies, because that is what it costs
you. A part you can slip into any gap gives one card at its own grade and one
plainer; a part you gave three or four cells of hold to gives two at grade.

  1-2 cells   one at the module's rarity, one BELOW it
  3-4 cells   two at the module's rarity

"Below it" and not "one step below": the second card may be anything lower,
which is what lets the shared commons sit on a legendary 1x1 without a
special case. A common module has nothing below it, so both of its cards are
common and the rule collapses to the obvious thing.

Which means a legendary 4x1 does grant two legendary cards — and that is
fine, because it costs a whole row of a light hull's twelve. The power is
bought with space rather than handed over. A legendary 1x1 could not be
allowed the same thing and this is the line that says so.

Like `grant_count`, a function of the part rather than a number typed per
module, so "a small part never grants two top-grade cards" is true BY
CONSTRUCTION and there is no review step to forget.
```

## Shared card identity

Inside `resolved_cards()`, above `if not c.shared:`:

```text
THE PART'S IDENTITY IS NOT THE CARD'S, for anything out of the shared
vocabulary. Branding a shared card with whatever granted it put four
Ranges in the catalogue under two manufacturers and three rarity ticks,
all with the same rules line. `source_module`/`source_id` still point
back at the part, because "where did this come from" is a real question
-- it is the LOOK that has to stay common and unbranded.
```
