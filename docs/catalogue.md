# The catalogue

Every rule that decides what a module is, what cards it grants, and what those
cards may be called. Written down because the catalogue is about a quarter
built — 63 parts and 73 cards against a target of 63 and 300 — and the last
two hundred and twenty-seven cards will be written by somebody who was not in
the room when these were decided.

Most of what follows is **enforced**. That is the important half of this
document: a rule that lives only in prose is a rule that holds until the first
tired afternoon, and four duplicate cards shipped that way before anything
checked. Where a rule is enforced, this says which check enforces it. Where it
is judgement, this says that too, so the difference is never guessed at.

    godot --headless --path tkg -- holdtest      # every rule below marked "gate"
    godot --headless --path tkg -- reactor       # what every frame launches with
    godot --headless --path tkg -- attrtest      # the attribute ladder, round trip
    godot --headless --path tkg -- content       # how much is written, per house
    godot --headless --path tkg -- content json  # the export the manifest is built from

---

## §1 What a module is

A part you find in a wreck, pack in the hold, and bolt to a hardpoint. It has a
**shape** in cells, a **slot** (weapon, system, utility), a **house**, a
**grade**, a line of flavour, and the **cards it grants**.

The cards are the point. A module is not a stat stick; it is a way of putting
particular verbs into a deck. Everything below is about keeping that honest.

Modules live in one place — `tkg/scripts/autoload/Database.gd`, in `_module()`
calls. There is no editor and no resource file per part, deliberately: sixty
parts in one file can be read top to bottom, and reading them top to bottom is
the only way anybody has ever noticed two of them were the same.

---

## §2 The Grant Count Law

**Every module grants exactly two cards.** `ModuleData.grant_count()`.

Fixed by module **class**, never by grade. A legendary drop must not make the
deck clumsier, because "declining the reward" arithmetic has no place in a loot
game. Rarity buys better verbs and bigger magnitudes; it never buys more cards.

Making the count a function of class rather than a per-module number makes the
invariant *a rarer module never produces a larger deck than its common sibling*
true by construction. There is no review step to forget.

It was 2 for weapons and systems and 1 for utilities, on the reading that a
utility is the situational third slot. The reading was sound and the result was
not: a utility was a part you found, packed and bolted on for a single card,
which made half the catalogue feel like a rounding error next to a gun.

**Verity Ateliers grants one.** The exception is a ruling, not an oversight —
the thin perfect deck the house is named for, made mechanical instead of
flavourful. It is why a Verity card is allowed to be stronger than its
neighbours at the same grade.

Affixes may move the count. Nothing else may.

---

## §3 The Card Rarity Law

**The grades of the two cards are decided by the module's SHAPE, not by its
grade alone.** `ModuleData.card_rarities()`, enforced by the gate.

| Module | Card grades |
| --- | --- |
| 1–2 cells | one at the module's grade, one **below** it |
| 3–4 cells | **both** at the module's grade |

An epic 4-cell bay grants two epic cards. An epic 2-cell system grants one epic
and one rare. The part that takes up half your hold is the part that pays you
twice.

This settles a question that has no good answer from grade alone: two legendary
cards off one part is too much, and one legendary plus a common is a reward with
a shrug attached. Shape is the dial that was already there.

**It also decides which parts MAY be a pair, which is stronger than a
guideline.** A pair is two copies of one card, so both copies are at one grade —
which the law only permits for commons (nothing below to drop to) and for 3–4
cell parts. An uncommon 2×1 cannot be a pair; its second card has to sit below
it. Nothing had to be told this.

**Gate:** `ok every module obeys the card rarity law`. Order-insensitive — which
card a module lists first is a fact about typing, not about the card.

---

## §4 A house's parts grant that house's cards

Korvan modules grant Korvan cards. Unbranded modules grant unbranded cards. The
exception is the shared library (§6), which anyone may draw on.

**Judgement, not gate.** A card carries no house field; the association is that
it is authored inside the module's `_module()` call. The check that would
enforce this is worth writing when the catalogue is larger and the cost of
getting it wrong is higher.

A house's cards should be recognisable as that house *without the name*:

| House | What its cards do |
| --- | --- |
| Korvan Heavy Works | Ballistics, armour, cold. Big numbers, no heat. |
| Solari Foundry | Heat as a resource. Pays in temperature for everything. |
| The Probate Combine | Salvage, credits, taking things apart. |
| Redline Shipyards | Cheap, improvised, hot. Draw attached to everything. |
| Cygnet Dynamics | Drones. Things that keep fighting after the card is gone. |
| Verity Ateliers | One card, better. Precision and filtering. |
| Calyx Biosystems | Growth, healing, cards that change through use. |
| Unbranded | Exotic (grown) and artifact (precursor). No house voice. |

### Korvan ballistics run cold — and the mechanics already say which is which

The manufacturer line is *"Ex-military surplus parts. Ballistics run cold;
ordnance and armor run hot."* That needs no new field to enforce, because the
card data already tells the two apart:

| | banks the shot | fires |
| --- | --- | --- |
| field | `charge_turns` | `hits` / `salvo` |
| is | ordnance | ballistics |
| heat | **yes** | **no** |

**Gate:** a Korvan weapon card may cost heat if and only if it charges. Armour
is exempt and hot by the same sentence — Bulwark and Bulkhead pay heat to hold a
plate up.

Four cards failed it when the check was written, and every one was a gun whose
own flavour said ballistic: a rotary cannon, a three-barrel ripsaw, and both
cards off the KH-500. They cost the house the only advantage it has — **a Korvan
gun that heats you up is a worse Solari gun.**

A card that contradicts its house is a bug even when the numbers are fine —
Spinal Mount was a heat-scaling gun on the low-heat house, which made it a
Solari card wearing a Korvan name.

---

## §5 About a quarter of parts grant a pair

A **pair** is two copies of one card. It is how a part says *this is the only
thing I do, and I do it twice* — and it is right for exactly the parts whose
flavour already says so. Slug Thrower is "chemical propellant and a tube".
Ranging Scope "tells the guns where the thing is, that is all it does". Hull
Plating "does not have to be clever".

Target is roughly **one in four**. Above that the catalogue reads as smaller
than it is; below it, every part is a combination and nothing is a statement.

**Judgement, with a printed measurement.** The gate prints the shape rather than
failing on it, because the right number is a matter of feel:

    shape: 33 of 63 modules grant a pair (52%), 22 draw on shared cards (35%)

52% overall, because the six houses that have not been rewritten yet sit at 97%.
Korvan and the unbranded stock, which have been, sit at 25%. **Bringing the
other six houses down to a quarter is the largest single job left in the
catalogue.**

---

## §6 The shared library

Eleven common cards in `Database.SHARED` that any module may grant, by
`StringName` rather than by writing the card out again:

    &"brace" Bolt On      &"block" Hold Fast    &"vent" Bleed Heat
    &"reroute" Reroute    &"range" Range        &"slug" Slug
    &"cut" Cutting Beam   &"patch" Patch        &"scuttle" Scuttle
    &"sort" Sort          &"feed" Feed

**All eleven are common.** That is what makes them safe to hand out: under §3 a
common card can sit beneath any grade, so a shared card is always a legal second
card. A shared uncommon would be legal on some parts and not others, which is a
rule nobody would remember.

They exist so a part can be a **combination** rather than a verb with a name on
it — a house card and a plain one beside it. It is also what makes a catalogue
of sixty read as more than sixty things: two parts sharing a card while each
keeping something of their own are related without being the same.

Anything with a house's fingerprints on it stays written where it is granted.
That is what makes it that part's card.

---

## §7 No two cards are the same card

**Gate**, both directions:

    ok  no two names share one effect
    ok  no two effects share one name

The first is the catalogue claiming more than it has: 73 cards that are really
69, and a player offered a choice that is not one. The second is worse — two
different things printing the same word, and a deck list that lies.

They hide because nothing in the game ever puts two cards next to each other. A
card is authored on one module, drawn from a deck of fifteen, and rendered by
its own name, so two cards with one effect look like a varied catalogue from
every angle except the one nobody has: all of them, side by side.

Four were found by a person reading a list before this existed — Bolt On was
Brace, Sight In was Load was Lay the Guns, Range Finding was Range, and a card
called Hold Fast sat beside a different card called Hold Fast. The check found
two more the first time it ran.

The fingerprint is **every field but five**, by reflection rather than a hand
written list. Excluded: `name` (the thing under test), `copies` and `rarity`
(the same card at two grades is still one card), `lane` (a label), and
`source_rarity` (stamped on at grant time by whatever part handed it over).

### The near misses, printed and not failed

    one verb, block:   Chaff, Deflect, Hold Fast
    one verb, lock_on: Range, Bore Sight, Flare

A card that does exactly one thing has nothing but its number to tell it apart
from the next card that does that one thing, and that is the family every
duplicate so far has come out of. Different numbers make them legitimately
different cards, so this cannot be a gate — but three under one verb is worth a
look, and it is how Range was caught costing Korvan's own Bore Sight its reason
to exist.

---

## §8 A card is never named after a keyword

**Gate**, both forms:

    ok  no card is named after a keyword
    ok  no card repeats its own name in its effect

A keyword is the **rule**; a card is a **thing** that uses it. The shared brace
card is called Bolt On and not Brace for exactly this reason, and that comment
held for one card until something checked the rest — at which point Lock On,
Evoke, Launch Drone and Wasp Screen all walked in. The last two were the effect
line with the number taken off:

    Launch Drone  —  Launch drone 3.

A card whose name is its effect tells a player nothing they could not read off
the corner, and it costs the glossary its referent: "lock on" ends up meaning
both a mechanic and one piece of Korvan hardware.

**Two of those four were the keyword's fault.** "Wasp screen" was Cygnet's own
flavour standing in for a mechanic any house could have. A keyword has to be
house-neutral, so it prints "Screen drone" now and Wasp Screen keeps its name.
When a card and a keyword collide, ask which one is wearing the other's clothes.

The glossary the check tests against is **collected from the cards** —
`CardData.keywords()` is the only place a keyword is defined, and asking every
card in the game what it explains is the only version of this that survives a
keyword added next month. Its one blind spot is a keyword no card uses yet,
which cannot collide with anything until a card uses it.

---

## §9 The grade ladder

`ModuleData.Rarity`, and two colours per grade, not one.

| Grade | Colour | Notes |
| --- | --- | --- |
| Common | `#98a0a8` | Near-neutral grey. The grade with no colour, because it has no claim. |
| Uncommon | `#4fbf82` | |
| Rare | `#6a9ad4` | |
| Epic | `#8b4fd4` | |
| Legendary | `#d99b29` | |
| Exotic | `#e05fa8` | Grown. Unbranded only. |
| Artifact | `#e0402e` | Precursor. Unbranded only. |
| Contraband | `#05070a` | Black. **No parts yet** — see below. |

**`rarity_colour()` is the plate's ground; `rarity_ink()` is what the name is
written in.** They are the same for seven grades and different for Contraband,
whose black is darker than the screen — a contraband plate has no visible
ground, only a bone edge. Those looked like one job only while every grade was a
mid-tone.

**Gate:** every ink clears 3.0:1 on the void, and every one of the 56
house-by-grade pairings clears 3.0:1 for art on ground.

### The bar tracks the cells, not the energy

`attr_reactor` is `energy × 0.6 + (cells − 4) / 3`. **Cells are about two thirds
of every reading.**

| | cells | energy | REACTOR |
| --- | --- | --- | --- |
| C | 13 | 3 | 5 |
| B | 16 | 3 | 6 |
| A | 19 | 4 | 7 |
| S | 22 | 5 | 9 |

It was `(energy − 2) × 1.6 + (cells − 12) / 3`, where a C read **2** — 1.6 of it
from energy and 0.33 from cells. Four fifths of the bar was the energy number,
on the one attribute whose raw unit a player can *count*: the ship screen says
thirteen cells right under the mounts. Told that a pip is three cells, anyone
does the multiplication and gets six. Somebody did, and said six seemed low for
a C class. They were reading the bar exactly as it invited.

**The bar is not invertible.** REACTOR 10 is a threshold, not a loadout — 3
energy and 28 cells reads 10, and so does 6 energy and 22. The least that
reaches it:

    energy 3 → 28 cells    energy 5 → 24 cells
    energy 4 → 26 cells    energy 6 → 22 cells

### Reading a grade off a plate

A grade is read off a 30-pixel rectangle, not off a word. The ground is the
colour mixed `ModuleIcon.GROUND` of the way into the void — **0.82**, pulled
back from 0.88 because at 0.88 the whole ladder was squashed into a band 22
CIELAB units wide and the closest pair of plates sat at 2.5, against a
just-noticeable difference of 2.3. Two grades were, to an eye, one grade.

The ceiling is **Verity's `#8a7340`**, the darkest house colour, against a green
ground. Nothing else binds. Brightening that one colour is what would buy real
room; 0.80 is the most the current colours allow and clears the floor by three
hundredths.

### Contraband: a ruling, not yet built

Contraband is the one grade that is a fact about **who sold you the thing**
rather than how well it was made. It comes only from **the Probate Combine,
Redline and Cygnet** — the scrappers, the hackers and the technologists, the
three houses with a reason to move something off the manifest.

Not implemented. `LootGen` currently gates `rarity >= EXOTIC` behind
`allow_unbranded`, which swallows Contraband along with Exotic and Artifact —
that filter needs saying differently before the first contraband part exists, or
it will drop from wrecks like a precursor relic.

---

## §10 Malfunctions are not modules

They live in `Database.MALFUNCTIONS`, sixteen of them, and nothing grants them.
A module that made a malfunction was a bug once — a dead `dross` module nothing
could hand out, which also made the content counter report one malfunction when
there were sixteen.

A malfunction arrives unasked, costs a hand slot, and charges you **at the end
of your turn**. That timing is the design: a card that hurt you on the draw is a
tax you cannot see coming and cannot answer, because it has happened by the time
you know about it. Charged at the end, the same card is a question — you are
holding something that will cost you, and you have a turn to find a way to throw
it away.

Three keywords, and they combine:

| Keyword | What it does |
| --- | --- |
| **Corrode N** | N damage at end of turn, while it is still in hand. |
| **Smoulder N** | N heat at end of turn, while it is still in hand. |
| **Fused** | Not discarded at end of turn. Discarding works; it costs you a card. |

Fused is the only one that **compounds** — everything else charges once and goes
with the hand. Answered by the discard verbs, and permanently by
`SYSTEM REPAIR` at a station, which removes one malfunction of the player's
choice.

---

## §11 Shape

Sizes are stored **width × height**, so a "1×2" in conversation is `2×1` in the
data. Parts rotate in the hold, so orientation is the player's choice and only
the shape is fixed.

Holds are 4×3 (light, 12), 5×4 (medium, 20) and 6×5 (heavy, 30).

Five shapes: **1×1** (14 parts), **2×1** (31), **3×1** (8), **2×2** (12) and
**4×1** (3).

**4×1 is the light-hull tax.** It fills an entire row of the twelve cells a
skiff has, and stood on end it does not fit at all — the grid refuses it,
because 1×4 runs off the bottom of a 3-deep hold. That makes hull weight bite in
the *hold*, where until now it only bit in the mount count. Three guns carry it,
and they are the three whose names already said so: a siege driver, a drumfire
and a rail are things a frame is built around.

**Gate:** every part fits the smallest hold. A 5-wide part could never be picked
up by anyone flying a light and would fail by being silently left behind at
every wreck.

A 4×1 fills an entire row of a light's twelve cells and does not fit at all
stood upright. That is a real decision rather than a side effect: it makes the
longest guns something a light frame pays dearly to carry.

---

## §12 The reactor

**One number. Everything else is read off it.**

`HullData.reactor` is a level, and two lines of arithmetic turn it into the
things that matter: **three cells a level**, and a step of energy every second
level.

| REACTOR | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 12 | 14 | 16 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| cells | 12 | 15 | 18 | 21 | 24 | 27 | 30 | 36 | 42 | 48 |
| energy | 3 | 3 | 4 | 4 | 5 | 5 | 6 | 7 | 8 | 9 |
| | C | B | | A | S | | | | | |

`attr_reactor` returns the level and nothing else — no weighting, no offset, no
formula. **REACTOR 10 is thirty cells and six energy**, so a player who reads
the bar and multiplies is right.

**And it does not stop at 10.** Attributes go over (§13), and this was the one
that silently did not: it was an eleven-row table, and a lookup clamps at its
own length. Four Jumper Cables on an S frame is REACTOR 16, 48 cells, 9 energy.
Arithmetic has no length; the ladder above is kept as a *table* because that is
the part anyone wants to read.

### Why it points this way

It started as a **score**: a hull carried an energy number and a cell budget,
and the attribute weighed them into 0–10. That could not be read backwards —
REACTOR 10 meant *at least this good*, not any particular ship — and on the one
gauge whose raw unit is printed directly underneath it, being unreadable
backwards is the entire complaint. The bar said 2 and the ship screen said
thirteen cells, and nothing connected them.

It is the only attribute that works this way and it earned it. HULL scores your
plating and THERMAL weighs capacity against vent because nobody counts either of
those; the ship screen counts cells, under the mounts, on the same panel.

**A table and not a formula**, because energy is a step, and a step written as
arithmetic is a floor division nobody can read. Eleven rows is the whole thing.

### The grade sets it, and nothing else

`TIER_DELTA` sets 4 / 5 / 7 / 8 — absolute, where every other field there is a
delta. Weight classes used to carry their own reactor (heavy had 4) with S
adding one on top, which meant C and B were the same ship twice.

**A and S skip a rung each**, and that is where the energy steps fall. B→A is
the biggest gap on the ladder because it buys a fourth point of energy, and
energy is the axis every card is priced against.

**24 at the top still bites.** A fully mounted S heavy is five weapons, three
systems and a utility; the catalogue averages 2.80 / 2.55 / 1.57 cells for
those — 23.2 to fill it, against 24 with nothing spare for a big gun. The best
hull in the game still cannot run everything it can bolt on.

### The hold is what you can haul; this is what you can run

Before this existed, a part's shape decided everything in the hold and nothing
on the hull — a 1-cell sight took a utility mount exactly like a 4-cell mast
did, so the shape system stopped mattering the moment a part was installed.

**It does not replace the slot counts. Both have to be satisfied**, and they
fail differently, so they clear differently: no mount takes the worst part *in
that slot* off, because a weapon cannot free a system mount; no capacity takes
the worst part *anywhere* off, because every cell draws on the one reactor.

### Couplings raise the level

`ModuleData.reactor`. Five parts carry it and all five grant **+2 levels** —
six cells, and a point of energy where the step falls.

| Part | Grade | Cells to run | Free |
| --- | --- | --- | --- |
| Jumper Cable | Uncommon | 1 | **+5** |
| Bus Coupling | Common | 2 | **+4** |
| Foundry Bus | Rare | 2 | **+4** |
| Salvaged Trunk Line | Uncommon | 3 | **+3** |
| Main Bus Armature | Rare | 4 | **+2** |

**Flat across all five, and grade does not decide it** — the one passive the
attribute ladder (§13) does not govern. Capacity is a **budget**, not power: a
legendary plate giving three times a common one gives you more hull, but a
legendary coupling giving three times a common one changes *how much ship you
can hold*, which compounds through every part you fit afterwards.

**What differs is size, and it cuts the other way.** A coupling occupies
capacity as well as granting it, so the 1-cell Jumper Cable keeps five of its
six and the 2×2 Main Bus Armature keeps two. The small part is the efficient
one; the big one is paid for in its cards. Worth watching — the rarer, larger
part is the weaker *power* part, the same shape as the domination Range and
Lock On had.

**A ruling this reversed:** couplings used to be forbidden from granting energy,
on the grounds that energy is the axis every card is priced against. That cannot
survive a model where the level hands out both — raising the level raises
everything the level decides. Measured at seed 4242 over 200 runs it took the
win rate from 15% to 20% and average jumps from 47 to 60, so it is a real buff
and a deliberate one.

**Gate:** `-- reactor` bolts each coupling onto a live frame and reads the
gauge, checking the **level** rather than the cells. It replaced a check on the
net (*nothing nets more than +2*), a proxy invented before the gauge was the
unit and now wrong by design — the nets legitimately run +2 to +5.

---

## §13 Attributes are not capped

`ATTR_MAX` is **how many cells the bar draws**, not a ceiling on the value.
A stealth build that reads 14 says 14.

Pillar 5 — *the ceiling is meant to break* — and a gauge that clamps hides the
exact moment the loot loop was paying out for. **The floor stays**: zero is
still zero, and nothing reads negative — see §14.

**The bar needed no code for it.** Ten cells, and when the value is over ten
every one lights because `i < value` is true for all of them — the loop had
already answered the question. A special case in a hotter colour was written
first and removed; the only way to learn it was redundant was to delete it and
see nothing change.

**What does cap is every consumer, at its own call site.** The ambush roll
divides stealth by `ATTR_MAX` and would drive a probability *negative* at 17
stealth — a ship ambushed a negative fraction of the time. It clamps its own
ratio now: sixty per cent off is the most stealth can buy, however much you
have. That is the right place for it. The gauge reports what you built; each
rule decides how much of it it can use.

Measured at seed 4242 over 200 runs it changed **nothing** — same wins, same
deaths, same death causes. The simulated pilot never stacks couplings, so this
is not a balance change at all. It is headroom for a player who does.

---

## §14 The attribute ladder

**A part's grade decides how far it moves a gauge, in whole pips out of ten.**
`Database.ATTR_BUMP`, enforced by the gate.

| Grade | Pips |
| --- | --- |
| Common | 0 |
| Uncommon | 0 |
| Rare | +1 |
| Epic | +2 |
| Legendary | +3 |
| Exotic | +3, **and −1 on another gauge** |
| Artifact | +4 |
| Contraband | +2 |

**Common and uncommon give nothing, and that is a statement.** Yard stock is
*cards*. Hull Plating used to carry +3 hull while a Brace Frame, two grades
rarer, carried +2 — the old table was authored one part at a time and had
drifted into saying a common beat a rare at the thing the rare is named for. A
ladder cannot drift. The cost is real: a run now opens with no passive stats at
all, because the whole starting kit is common, and the first rare part you bolt
on is the first pip you have ever had.

**Exotic matches Legendary and pays for it somewhere else.** Grown things are
alive and inconvenient, and the trade is the identity rather than a bigger
number — a Voidwhale Ganglion hears everything in the system, and everything in
the system hears it. **Artifact** is the top of the found ladder and there are
two. **Contraband sits at Epic on purpose**: it is not a quality grade at all,
it is a fact about who sold it to you, so it performs like an epic and carries
risk instead of power.

### One gauge each

`Database.PASSIVE_AXIS` says *which* gauge; the grade says *how far*. There are
five a part can move, and **a gauge is one number**:

| Gauge | What a pip raises |
| --- | --- |
| HULL | max hull, 7 a pip |
| THERMAL | how much heat you hold **and** how fast you lose it |
| MANEUVER | dodge **and** initiative |
| SENSORS | sensors |
| STEALTH | stealth |

A part says **+1 MANEUVER** and gets faster *and* harder to hit. Those are not
two things a player weighs separately while reading one bar, so they are not two
entries. The same for THERMAL: capacity and vent both move, and there is nothing
to explain in brackets after the number.

Each half of a two-term gauge carries **half a pip**, which is what decides the
divisors in `attr_thermal` and `attr_maneuver`: half a pip has to be one whole
point in an int field. Dodge is a float and can carry a fraction; initiative and
dissipation cannot. Two hull readings moved when those divisors were set — a
light drops from THERMAL 2 to 1, and a heavy rises from MANEUVER 0 to 1.

**One gauge per part**, which was the other half of the change. Cold Sights used
to carry vent **and** sensors, Ghost Drive dodge **and** stealth, the Fire
Director initiative **and** sensors — so "a rare part is worth one pip" could not
be true of any of them, and a part quietly moving two gauges was worth double its
grade with nothing saying so.

The gauge is the one the **name** picks: sights see, a drive is how you are not
there, a director decides. Most of the catalogue has none at all, which is also
deliberate — a gun is not a claim about any of the five.

### Prices are authored, not laddered

`Database.PASSIVE_COST`. A Solari flare rack lights you up; a Voidwhale Ganglion
transmits as well as it listens. These are what let the top of the ladder stay
flat, and they were true in the flavour before they were true in the numbers.

### REACTOR is exempt, and it has to be

Capacity has its own rule (§12: net ≤ +2, self-limiting) and does **not** follow
the pip ladder. The two genuinely conflict — a legendary part at +3 pips would
be +12 cells, which breaks the budget the cells *are* — and the reason is that
REACTOR is the one attribute that is itself a constraint on installing modules.
A part that raises it is a feedback loop the other five do not have.

### Zero is the floor

**An attribute stops at zero. It does not go under.** The clamp on each `attr_*`
return is what enforces it, and Sensors and Stealth are the only two that could
ever have needed it — they are summed straight off the hull and its modules,
where every other gauge is derived from a quantity already floored on the way
here (heat capacity at 1, dissipation and dodge at 0).

Above zero the arithmetic is plain: four stealth and a flare rack is three, and
that is a real pip the rack costs a stealth build. On a hull with no stealth at
all the rack costs nothing, because there was nothing to take. **Gate:**
`-- attrtest` measures the price both ways.

### The word is VENT

The card face says **Vent 3**, the field is called `dissipation`, and the gauge
is THERMAL. Those are three names for one quantity and that is already one too
many — do not add a fourth. "Shedding" appeared in these comments for exactly
one commit and was removed.

THERMAL is one gauge made of both, and a part raises both — see above. Worth
knowing that they are not equally valuable in a fight even though the gauge
treats them as equal: capacity is heat you can hold, vent is heat off you every
turn, forever. An event asking *can you sit in this* is answered by either. A
fight is not.

### The round trip is checked

**Gate:** `-- attrtest` bolts every part onto a bare medium C and reads the
gauge before and after.

    Reactive Plating Array  Legendary  hull       3      3
    Bulkhead Array          Epic       hull       2      2
    Brace Frame             Rare       hull       1      1
    Hull Plating            Common     hull       0      0

It exists because two things break silently. **Rounding** — a pip of venting
was 1.5, stored as an int 2, and read back as two pips; caught on the first run.
**A changed formula** — `RunState.PER_PIP` is inverted out of the `attr_*`
functions by hand, so retuning a divisor and not touching it puts a whole axis
off the ladder on every hull in the game.

`attr_thermal` divides by 2 and 1 rather than 2.1 and 1.5 **because of this** —
an int field cannot deliver a fractional pip. The readings barely moved; a
medium reads 3 either way.

`SENSE_SCALE` is 1.0 for the same reason: at 1.7 a rare and an epic both round
to a raw 1, and two grades reading identically is the failure THERMAL already
documents. What it costs is hull headroom; what it buys is that Sensors and
Stealth are axes you **build** rather than ones the frame hands you.

Measured at seed 4242, 200 runs: 18% → 16%. Commons losing their stats roughly
offsets rares and above gaining more.

---

## §15 The loop

1. Write parts in `Database.gd`.
2. `godot --headless --path tkg -- holdtest` — every gate in this document.
3. `godot --headless --path tkg -- content` — the shortfall, per house.
4. `godot --headless --path tkg -- content json` — the export.
5. `node tkg/tools/manifest.mjs out.html` — the Yard Manifest.
6. Publish `out.html` as an artifact and read the catalogue.

**The export and the page are both gated.** `-- content json` vets every row it
writes against a vocabulary built from the game itself — `PER_PIP` for gauges,
the `Rarity` enum for grades, `Slot` for slots — and `manifest.mjs` **throws** on
a gauge it does not recognise rather than rendering a blank cell. Both run as one
step in `validate.sh`.

That exists because neither was gated at all, and they drifted apart in silence:
`PASSIVE_AXIS` values became arrays while the exporter still called `String()` on
one, so a gauge arrived as the four characters `["hull"]`. The JSON stayed valid,
the page kept rendering, every gauge chip vanished, and nothing errored at either
end. It was found by looking at a table that had gone blank.

**Rendering nothing is how a broken contract gets to look like an empty
catalogue.** That is the general lesson and it is the second time it bit: the
manifest also printed reactor cells gross while `-- reactor` correctly printed
net. Both times the check was right and the page a person reads was wrong,
because the page was not checked. A gate only protects what it is looking at.

**Step 6 is not decoration.** Every duplicate found so far was found by a person
looking at a list where the cards sat next to each other; the manifest sorts
every card by *effect* rather than by name for exactly that reason. Two cards
that do the same thing end up adjacent instead of eleven screens apart.

The manifest is **generated, never typed**. A hand-copied catalogue is wrong the
day after it is copied, and a stale one is worse than none — the version that
still listed Range Finding cost a review that found two problems already fixed
and one card that had never shipped. It also runs the duplicate check itself
rather than quoting holdtest's verdict, because two implementations of one rule
disagreeing is information and a page repeating what the test said is not.

Standing artifact: **Yard Manifest**, republished in place each time.

---

## §16 What the catalogue measures

Numbers to check a pass against, not rules. All from `-- content json`.

### Strength against grade

    grade        n   avg power   avg cost   power per cost
    Common      26        5.4       0.97           5.5
    Uncommon    21        6.0       1.07           5.6
    Rare        22        7.7       1.22           6.3
    Epic         7       13.8       1.99           6.9
    Legendary    7       17.5       2.91           6.0
    Exotic       3       14.0       1.00          14.0
    Artifact     9       16.9       1.47          11.5

Power climbs cleanly and **efficiency stays flat from common to legendary** —
higher grades give more *and* cost more, which is the healthy shape. Two things
are worth knowing:

**Exotic and artifact are about twice as efficient as legendary.** Cheap and
strong. Under Pillar 5 that is arguably right — that is the tier meant to feel
broken — but it is a cliff rather than a gradient, and it is deliberate rather
than drift.

**Common to uncommon is a weak step**, 5.4 to 6.0. An uncommon barely reads as
an upgrade. If one thing gets tuned next, it is that.

### House neutrality

**0 of 26 unbranded cards lean on a house mechanic** — no drones (Cygnet), no
credits (Probate), no heat-scaling or brace-from-heat (Solari). Unbranded stock
has to work on any frame, and it does.

### Gauge coverage by house

    Korvan      hull 1/2/2/3   thermal 1/2/3   sensors 1/2/3   maneuver —   stealth —
    Unbranded   hull 4         thermal 4       sensors 3/4     maneuver 4   stealth 4

Korvan covers every gauge that is not stealth or maneuver, at +1, +2 and +3.
Unbranded covers all five and only at the top, which is right: exotic and
artifact are unbranded by definition, so the ceiling of every ladder is the
yard's.

---

## §17 Where it stands

    korvan          25 parts   40 cards   want 40   done
    (unbranded)     18         20         want 20   done
    solari           7          7         want 40   short 33
    probate          7          8         want 40   short 32
    redline          7          7         want 40   short 33
    cygnet           4          4         want 40   short 36
    verity           5          5         want 40   short 35
    calyx            4          4         want 40   short 36
    malfunctions     -         16         want 15   done

    95 unique cards across 77 modules; 205 still to write

A card counts toward the first house that uses it, so the ten shared cards are
counted once. Both `-- content` and the manifest do it that way; two answers to
one question is how a number stops being believed.

**Korvan and the unbranded stock are finished.** The five houses left are the
work: 205 cards, and their parts are still 97% pairs against a one-in-four
target.

### The gauge ladder, and what is still missing

Every gauge should be reachable at +1, +2, +3 and +4. A rung nobody can buy is a
rung that does not exist, and a player building for an attribute finds that out
by not finding the part.

| gauge | +1 | +2 | +3 | +4 |
| --- | --- | --- | --- | --- |
| HULL | Brace Frame | Bulkhead Array, Standfast Rig | Reactive Plating | Precursor Keel |
| THERMAL | Thermal Purge, Blowout Panel | Standfast Rig | Cryogenic Battery | Cold Sepulchre |
| MANEUVER | — | — | — | Singing Core |
| SENSORS | Cold Sights, Evoke Node | Gunnery Table | Fire Director | Oracle Shard |
| STEALTH | Ghost Drive | — | — | Precursor Lattice |

**Maneuver +1/+2/+3 and stealth +2/+3 are open on purpose.** Korvan is heavy,
slow and loud; unbranded yard stock is common and gives nothing, and its relics
already hold the +4s. Those rungs belong to **Redline** (dodge, stealth) and
**Cygnet**. Writing a nimble Korvan part to fill a table would be the Spinal
Mount mistake again — a card that contradicts its house is a bug even when the
numbers are fine (§4).

Exotic and Artifact are unbranded by definition, so **the top of every ladder is
the yard's problem and nobody else's**. Three of the five had no +4 at all.
