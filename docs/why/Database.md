The reasoning behind `tkg/scripts/autoload/Database.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Content database

Above `const ACTIVE_MANUFACTURERS: Array[StringName] = [&"korvan", &"solari"]`:

```text
Content database.

Content is authored here as plain dictionaries and seeded into typed
Resources at boot. Two reasons: it diffs cleanly in git, and tools/
export_resources.gd can dump it to .tres files once you want to edit
modules in the Godot inspector instead. Either way the rest of the
codebase only ever sees ModuleData / HullData / EnemyTemplate.
```

## Loot pool gate

Above `const ACTIVE_MANUFACTURERS: Array[StringName] = [&"korvan", &"solari"]`:

```text
Loot-pool gate. While this is non-empty, only these manufacturers can drop;
an empty array means every manufacturer is live. Nothing is deleted — all 33 modules
stay authored and seeded, so flipping a manufacturer back on is a one-word edit and
the sim can A/B a narrow pool against the full one.

Manufacturer-agnostic modules are never gated: Exotic is harvested and Artifact is
precursor tech, so they have no manufacturer to gate on.

NARROWED TO KORVAN, deliberately, and this is the second time. It was opened
to all seven when manufacturer hulls landed, because a chassis select offering
seven manufacturers over a Korvan-only loot pool would have made six choices
unplayable. STARTABLE has now been cut to match, so that objection is answered
rather than ignored: there is one manufacturer, and it is the only one you can fly.

The reason is depth over breadth. Seven manufacturers at three modules each is seven
shallow loot streams; one manufacturer with a full ladder is a run where the next
wreck can plausibly hold something you want. Korvan is the one to do first —
ballistics and charged ordnance, no gimmick, the tutorial manufacturer.

Restoring the others means putting this back to [] and STARTABLE back to all
seven. Nothing else is gated on it.

SOLARI JOINS (Oct 17), the second manufacturer with a full ladder: 25 parts,
40 cards, its own three hulls and their mounts and engines. A Solari run can
now find its second and third Solari part, so its 3+ and 5+ sets are
reachable, and a Solari Territory rolls Solari rather than falling back to
unbranded. The cost is Korvan's: a Korvan run's branded drops are now split
two ways. `-- sim runs=200 seed=777` before and after is in the commit.

AND ONLY ONCE UNLOCKED (Jon, Oct 20: "Solari things should NOT show up in the
game until Solari is unlocked (win the game once)"). This list says what MAY
drop; the run's `Run.unlocked_manufacturers` says what this profile has
earned, and a part or hull appears only where both agree
(`LootGen.can_appear`). A fresh profile's world is Korvan plus unbranded;
a Korvan win adds Solari. Putting Probate on this list later works the same
way: it appears once a Solari win has unlocked it.
```

## Starting kit

Above `const GENERIC_KIT: Array[StringName] = [&"beam", &"plating", &"board", &"coolline"]`:

```text
ONE branded weapon, and yard stock for the rest.

This used to hand you a manufacturer's whole catalogue — five Korvan modules,
four Redline — which meant the run opened with its set bonus already earned
and its identity already finished. Nothing you found afterwards could change
what you were; the best it could do was be a slightly better version of it.

Now the manufacturer gives you a gun and a hull, which is two of the three a set
needs. Everything else is generic. The third piece is out there in a wreck or
behind a station's counter, and until you go and get it you are flying a
chassis with a good weapon bolted to it — which is a much better description
of the start of a run than "a finished Korvan build".

It also puts CLAUDE.md's ruling back the right way up. Identity is assembled
mid-run again; choosing a manufacturer picks the direction, not the
destination.
What every ship is issued, in the order it goes on. Seven cards between them
— two attacks, two brace, two draws, one vent — against the two the branded
weapon grants. Nine to open with, which is the shape a starting deck wants:
enough that a hand of five is a draw rather than your whole hand, and thin
enough that one good find changes it.
```

## Starter weapon

Above `const STARTER_WEAPON: Dictionary = {`:

```text
The one module each yard sends you off with. Common or Uncommon — never Rare,
which it used to be for three of them.

The rule was "each manufacturer's cheapest weapon", which sounded even and was not:
Probate, Verity and Calyx had no common weapon at all, so their floor was C2.
That leaked somewhere invisible. Market.melt() reads scrap_value, which is a
table indexed by RARITY, so a Probate player could scrap their free gun for
roughly four times what a Korvan player got before anything had happened —
with salvage_rack multiplying exactly that. An economic head start nothing on
screen accounted for, in a game whose difficulty lives in the economy.

Breaker Cannon, Verity Mark I and Calyx Barb were written to close it, and
they also even out a common tier of the drop pool that was six-sevenths
Korvan.

STILL UNEVEN, deliberately for now: Redline and Cygnet start on Uncommons,
which melt for 16 against Korvan's 8. Solari did too, until its common Ember
Lance was written (Jon, Oct 15); the Plasma Lance is now its first upgrade.
```

## Startable manufacturers

Above `const STARTABLE: Array[StringName] = [`:

```text
The manufacturers you can start as, in the order the chassis select shows them.
Korvan first because it is the tutorial ship: no gimmick, all three slots
filled, nothing that needs explaining before the first fight.

ALL SEVEN, even though only Korvan and Solari parts drop — see ACTIVE_MANUFACTURERS. The focus
is on what gets BUILT, not on what you may fly, and the run-start choice is
the one place the other six manufacturers still pay for themselves: seven attribute
signatures, seven hulls, seven palettes, all authored and all reachable.

THE COST, on the record. A loot pool gated to Korvan and Solari means a
Probate ship finds no second Probate part, so the 3+ and 5+ set bonuses of the
other five are unreachable for as long as ACTIVE_MANUFACTURERS is narrowed. You
can fly them; you cannot complete them.
```

## Manufacturer backstory

Above `const BACKSTORY := {`:

```text
Who each manufacturer is, as opposed to what flying it does.

Kept out of the table above because that table is already ten columns wide
and these are paragraphs; a wall of prose wedged into positional array
indices is unreadable and unmergeable. Keyed by id so a missing one is blank
rather than a shifted column.

The rule for writing these: company, not mechanics. `identity` already says
what the set bonuses do. A player picking a chassis at run start is choosing
an allegiance before they can evaluate a single number, and this is what they
are actually choosing between.
```

## Malfunctions

Above `const MALFUNCTIONS: Array = [`:

```text
SIXTEEN MALFUNCTIONS, out of three keywords.

Written as combinations rather than as sixteen sentences. Sixteen sentences is
what this was first drafted as and it came out as three behaviours with
different numbers on them; three keywords and a number each is sixteen cards a
player can read at a glance, which is how Brace, Salvo and Charge already work.

  CORRODE n   damage at the end of your turn while it is in your hand
  SMOULDER n  heat, the same way
  FUSED       not discarded at end of turn — it stays until you deal with it

FUSED IS THE ONLY ONE THAT COMPOUNDS. The others charge you once and go with
the hand. A fused card charges you again every turn and holds a hand slot the
whole time, which is what makes it worth spending a Discard on — and a
Decommission if you would rather it did not come back at all.

Eight of these are severities of the same two verbs, and that is deliberate:
Corrode 1/2/3 and Smoulder 2/3/4 are a ladder you learn to read, not eight
separate rules to remember.
```

Above `func roll_malfunction(danger: int, r: RandomNumberGenerator = Rng.foe) -> StringName:`:

```text
Which malfunction lodges in you, weighted so the mild ones are common.

Rolled from `Rng.foe` rather than the global generator, because what an enemy
does to you is part of the fight and has to replay from the seed. The weights
are the row's own position: the table is written mildest-first, so the front
of it is common and the compounding ones at the back are rare.
```

## Affixes

Inside `_seed_affixes()`, above `var raw := [`:

```text
TEN, PAID IN SHIP ATTRIBUTES. See AffixData for why they stopped paying in
card numbers: a card whose face changes with the module that granted it is
a card nobody can learn, and three affixes grew the text out of the bottom
of a 93-pixel box.

All seven gauges are reachable, so no attribute is a dead end for loot.
Three names survive the change — Reinforced, Cryo-Lined and Deregulated —
because they still mean what they say; the other seven meant card verbs
and had nothing to be renamed to.

`weight` prices the two reactor entries. A reactor pip is three cells of
capacity AND half a point of energy a turn; every other gauge pays in one
currency, so these are made SCARCE rather than weakened.

NO `text` FIELD HERE. It is generated from the pips by
`AffixData.gauge_text()` below, so the sentence on the panel cannot say
something the numbers do not -- and the gauge names come from
`RunState.ATTR_SHORT`, which is the same table the attributes panel labels
its rows from.
```

## Shared cards

Above `const SHARED := {`:

```text
THE SHARED VOCABULARY. Cards more than one module is allowed to grant.

Every card used to be a literal written inside the one module that granted
it, which meant nothing could be shared even when it plainly should be: a
Korvan plate and an unbranded plate both Brace, and writing that twice makes
two cards that have to be kept in step by somebody remembering to.

So a module's card list takes either a Dictionary — a card only it has — or a
StringName naming one of these. That is what lets the catalogue have three
shapes rather than one:

  two shared      yard stock. Honest, dull, and the thing better parts beat
  one and one     the common case: a headline card and a plain one beside it
  two special     a part that is entirely itself, and rare because of it

EVERY ONE OF THESE IS COMMON, and that is what makes them shareable: a card a
legendary bay and a starter plate both grant cannot be worth more on one than
the other. It is also why they slot into the second half of the rarity law
without ever breaking it.

Deliberately NOT a card for every verb. These are the ones a dozen parts
could plausibly grant; anything with a manufacturer's fingerprints on it stays
written where it is granted, because that is what makes it that part's card.
```

Inside `_seed_affixes()`, above `&"range":    {name = "Range", energy = 0, rarity = 0, lock_on = 2},`:

```text
+2 AND NOT +3, so that Korvan's own Lock On has a reason to cost energy.
At +3 the shared card was 0 energy for one point less than a 1-energy
manufacturer card, which is a full energy for one point of mark — nobody would
ever pay it, and the Targeting Servo was a worse Ranging Optics. Surfaced
by holdtest's single-verb report, which exists to put exactly this kind of
near-twin next to itself.
```

## Korvan ladder

Inside `_seed_modules()`, above `_module(&"kh40", "KH-40 Ripsaw", &"korvan", W, C1,`:

```text
The nine rungs Korvan was missing, and the shape they were authored to.

RARITY BUYS A VERB, NOT A NUMBER. A Legendary is not a bigger lump of a
Common, it is a cleverer one. Where a rung below already says the thing, the
rung above says a different thing rather than the same thing louder.

The spine of the weapon line is SALVO, and that is not a preference. Korvan's
five-piece set makes salvo fire on the FIRST attack of the turn
(CardResolver, `has_set(&"korvan", 5)`), so every point of it is worth double
to a committed Korvan build and nothing at all to a tourist. It is the one
number in this catalog that measures how far in you are.

Utility is built on LOCK-ON for the mirror reason: lock-on adds per HIT, so
it multiplies by the thing Korvan's guns already do. Servo into Jackhammer
was the manufacturer's best combo and its only one; there are now four rungs of it.

What Korvan does NOT get, however well it would fit: heat_scale and
damage_equals_heat (Solari IS weaponised heat), credit_gain (Probate),
drones and evoke (Cygnet), negate_next (Redline), adapt and heal (Calyx).
A manufacturer that borrows another's verb at a higher rarity does not read as
stronger, it reads as the other manufacturer.
```

## Solari line

Inside `_seed_modules()`, above `_module(&"emberlance", "Ember Lance", &"solari", W, C0,`:

```text
--- Solari, the rest of the line (Jon, Oct 15: "Let's make the modules and
cards now", from the manufacturer plan's Solari tab). Two checks hold it to
the motto (HoldTest `_solari_runs_hot`, `_solari_heat_not_waste`): every
Solari attack costs heat or reads it, and every Solari vent buys something.

The issued gun, and a COMMON, so Solari launches on a common like Korvan.
Glowshot is weak cold and fair at eight heat; Kindle is free and exists to
start the gauge climbing.
```

## Verity cards

Inside `_seed_modules()`, above `[{name = "Foresight", energy = 0, draw = 3, discard = 1, copies = 2}])`:

```text
DRAW THREE AND THROW ONE, not draw two — which is what this said until
the twin check put it next to Redline's Jury-Rig and they were the same
card. Both manufacturers want cards; only one of them wants THE RIGHT card,
and that is a filter, not a bigger number. Verity grants one card where
everyone else grants two, so the one is allowed to be the better one.
```

## Calyx balance

Inside `_seed_modules()`, above `_module(&"barb", "Calyx Barb", &"calyx", W, C0,`:

```text
Issued weapon. Bites and knits at once, which is the manufacturer in miniature.

Trimmed from 5/heal 2. Calyx measured strongest of the seven at every
weight, and sustain is why: a weapon that repairs while it fires is worth
more than one that hits harder, and two points of healing on two copies of
a card in a nine-card deck was quietly the best starter in the game.

THE FIGURE THAT USED TO BE HERE IS OUT OF DATE, and it is left corrected
rather than deleted because the decision it justified still stands. It said
hull loss causes half the deaths, and its first correction said 56% were
running the tank dry, which was the old sim counting its own pilot's dead
ends. Re-measured 2026-10-17 (seed 777, 200 runs, the corrected sim): of 192
deaths, events 45%, fights 28%, heat 27%, a dry tank none (1% once the tank
became 45, Oct 17).

The trim was still right — Calyx was strongest and this is why — but
anybody reaching for "sustain decides the game" as a reason to refuse
something should reach for the current number instead.
```

## Repair cards

Inside `_seed_modules()`, above `_module(&"weldkit", "Field Weld Kit", &"korvan", U, C1,`:

```text

Healing used to be Calyx's and nobody else's — Knit, Barb and Bloom, plus
the yard's Patch Kit and the Voidwhale Ganglion. Every other manufacturer had to
buy its hull back at a station, which is correct as an economy and wrong as
a deck: a build with no answer to being hurt has one answer to being hurt,
and it is "leave".

So all seven can repair now, and NOT ONE OF THEM DOES IT THE SAME WAY. A
heal card handed identically to seven manufacturers is seven manufacturers minus their
differences, and the differences are the class system. Each of these pays
for its hull points in the currency its manufacturer already trades in: Korvan in
tempo, Solari in heat, Probate in credits, Redline in nothing much and not
much back, Verity in energy, Cygnet in time.

THEY ARE ALL LIFELINES, AND THAT IS THE SECOND REWRITE OF THIS BLOCK.

The first pass priced them as economy cards — flat heals, two and three
energy — and priced them for a HEALTHY turn, which is the one turn that does
not need them. At three hull and one energy left, a card that costs two is
not a card. Every one of these now costs at most one energy (Verity's costs
two, and one under Bespoke, which is that manufacturer answering the question its
own way) and every one of them scales on hull MISSING rather than paying a
flat number. See CardData.heal_scale.

The shape that buys: nearly dead weight at full hull, the biggest card in
the deck at three. Worth exactly as much as the trouble you are in.

CALYX IS FLAT AND STAYS FLAT, which is now a real distinction rather than an
omission: Calyx heals you all fight and the other six save you at the end of
one. Knit for 5 twice over is better than any of these on a turn you are
winning and worse than all of them on a turn you are not. That is the manufacturer
that grows hulls versus the manufacturers that patch them.

CALYX GETS NOTHING HERE, deliberately. It already has three, it is the
sustain manufacturer, and `barb` above records what happened last time sustain was
handed out freely: Calyx measured strongest of the seven at every weight.
Widening the thing that made it strongest is not how the other six catch up.
Every rate below is deliberately worse than Knit's 10 hull for 2 energy.
```

## Dross

Inside `_seed_modules()`, above `_module(&"scuttle", "Scuttle Chute", &"", U, C0,`:

```text

THE MALFUNCTION TABLE lives in `_seed_malfunctions` below, because a
malfunction is not a module and never was. See the ruling.

THERE IS NO DROSS MODULE. There was one, and it was unreachable: the loot
pool skipped it by id, and the only thing that could hand it over was
`LootGen.make_dross()`, which nothing called. It still showed up in the
module gallery and still counted toward the unbranded catalogue, so the
yard looked like it stocked a part nobody could ever be given.

Dross is a COUNT, not a part. `Run.dross` goes up when a spore enemy
breathes on you and `DeckBuilder` turns it into unplayable cards at
deck-build time — junk in the deck without a hold cell or a hardpoint,
which is what junk arriving unasked should be. Two mechanisms for one idea
is one too many, and this was the dead one.
```

## Clearing the deck

Inside `_seed_modules()`, above `_module(&"scuttle", "Scuttle Chute", &"", U, C0,`:

```text

There has to be an ANSWER to junk or it is only arithmetic. A malfunction
now charges you at the end of the turn if you are still holding it, which
makes it a question — and these are what you answer it with. Spread across
manufacturers rather than sold by one, because every ship gets junk and a mechanic
only one manufacturer can address is a mechanic six of them play around.
COMMON, not uncommon. It grants two shared cards and nothing of its own,
which is the definition of yard stock — and the rarity law is what caught
it: an uncommon part has to bring one uncommon card and this brings none.
```

## Yard stock

Inside `_seed_modules()`, above `_module(&"beam", "Mining Laser", &"", W, C0,`:

```text

Deliberately dull. These are the colourless commons of the game: a beam, a
plate, a coolant line. They do one obvious thing at a fair price and none
of them is a reason to do anything — which is the point, because the
branded module you find in the next wreck has to be visibly better than
something.

Unbranded, so they count toward no set. A ship launches with its hull and
ONE weapon from its manufacturer, which is two of the three you need — the third
is out there.
Three of each slot, so a frame of any shape can fill itself from stock.
The kit is one shape and the frames are not — four manufacturers drop a weapon
mount, three add a utility — so without a spread here the top-up ran out
of things that fit and fell back on bolting on a second identical plate.
```

## Patch Kit

Inside `_seed_modules()`, above `_module(&"patchkit", "Patch Kit", &"", U, C0,`:

```text
YARD STOCK, AND THE FIRST LIFELINE ANYBODY HOLDS. Scaled like the branded
repairs below it rather than left flat, because the turn this card exists
for is the same turn theirs do — and a run whose only repair is a flat 4 is
a run that learns repair does not save you before it ever finds one that
does.
THE SHARED CARD, not a literal copy of it. This authored its own Patch --
same energy, same heal, same scale as `&"patch"` in SHARED above, written
out a second time -- which is exactly the duplication the shared
vocabulary exists to stop. holdtest found it as "Patch is 2 different
cards", and the only thing that actually differed between them was the
`shared` flag.
```

## Attribute ladder gaps

Inside `_seed_modules()`, above `_module(&"cryobat", "Cryogenic Battery", &"korvan", S, C4,`:

```text

THE LADDER HAD HOLES IN IT. Every gauge is supposed to be reachable at +1,
+2, +3 and +4, and thermal stopped at +2 while sensors skipped +2 entirely.
A rung nobody can buy is a rung that does not exist, and a player building
for an attribute finds that out by not finding the part.
```

## Reactor capacity

Inside `_seed_modules()`, above `_module(&"buscoupling", "Bus Coupling", &"", S, C0,`:

```text

A hull's REACTOR LEVEL decides the cells of hardware it can carry, and these
are how a build buys more of it without finding a better frame. THEY ARE
SELF-LIMITING BY CONSTRUCTION — a part that grants capacity also occupies
it, and it occupies a mount that could have held a gun. The most any of
them nets is +2, which `-- reactor` enforces: two cells is one small part's
worth, so a ship that gives half its mounts to couplings has bought itself
about one extra weapon and has nowhere left to put it.

THE ATTRIBUTE LADDER DOES NOT GOVERN THESE, and that is a ruling. Every
other passive in the game takes its size from the part grade; capacity does
not, and the nets are nearly flat across all five — +1, +2, +2, +2, +2.

Capacity is a BUDGET rather than power. A legendary plate giving three times
a common one gives you more hull; a legendary coupling giving three times a
common one changes how much SHIP you can hold, which compounds through every
part you fit afterwards. Same number, much bigger swing, so the ladder stops
at the reactor door.

ALWAYS READ THE NET. The grant alone means nothing: a 4-cell armature
granting 6 leaves room for 2, which is exactly what a 1-cell cable granting
3 leaves. Printing the grant made the armature look like three times the
cable, and somebody asked why, which is how the display got fixed.

CAPACITY ONLY, NEVER OUTPUT. None of them hands out energy per turn. Energy
is the axis every card is priced against — three of it plays two cards and
five plays four — so it stays with the hull, the `overspec_reactor` perk and
the Verity five-set, where there are exactly three of it and it can be
reasoned about. What these sell is ROOM.

Four manufacturers and the yard, and not the other three, because a power bus is a
thing a manufacturer has an opinion about: Solari runs the reactor, the Combine
pulls one out of something else, Redline adds cable, and Korvan overbuilds
the armature. Cygnet, Verity and Calyx have nothing to say about it.
```

Inside `_seed_module_sizes()`, above `for id in [&"buscoupling", &"foundrybus", &"trunkline", &"jumper", &"mainbus"]:`:

```text
WHAT THE REACTOR CAN CARRY, granted by a part. Here rather than in the
`_module` call because `_module` takes what a part IS and the passives are
seeded in a pass of their own, the same as sensors and stealth.
EVERY COUPLING RAISES REACTOR BY THE SAME +2 LEVELS, which the table turns
into six cells and, where the step falls, a point of energy. The part's
number and the number on the bar are now the same number — somebody asked
why the armature granted six, and the honest answer used to be that six was
picked to make its net come out at two.

FLAT ACROSS ALL FIVE. Capacity is a budget and does not climb with grade;
what differs is what each part COSTS to run, so a 1-cell cable keeps more of
its own six than a 2x2 armature does.
```

## Module sizes

Above `func _seed_module_sizes() -> void:`:

```text
Sensors and Stealth, laid on modules that already exist.

Adding six attribute-bearing modules would have been the obvious move and the
wrong one — CLAUDE.md's fifth priority is to resist adding content until the
loop feels good. Every one of these already reads as the thing it now does:
an Auspex Array is a sensor, a Ghost Drive hides you, a flare rack does the
exact opposite. The attribute was latent in the catalog; this names it.

Kept in one table rather than as two more arguments on _module() because it
is a property of six modules out of thirty-four, and thirty-four call sites
carrying `0, 0` would bury the six that matter.
How much hold each part takes. See ModuleData.size for what a shape MEANS.

A default per slot and a list of exceptions, rather than 55 sizes written out
one at a time. The default is the honest claim — a system is a compact unit, a
utility is a fitting — and every entry below is a part whose NAME already says
it is not: a Lance is long, a Bay is bulky, a Scope is neither.

The test applied to each was "would you be surprised to see this shape in the
hold". A Precursor Lattice at 2x2 is not surprising; a Coolant Line at
anything but 1x1 would be.
```

Inside `_seed_module_sizes()`, above `const SPINE := Vector2i(4, 1)`:

```text
FOUR ACROSS, and the only shape a light hull cannot rotate. A light hold is
4x3, so a spinal gun fills an entire row of the twelve cells a skiff has and
stood on end does not fit at all — the grid refuses it, because 1x4 runs off
the bottom. That is a real decision rather than a side effect: it makes hull
weight bite in the HOLD, where until now it only bit in the mount count.

Four parts carry it: the three guns whose names already said so (a siege
driver, a drumfire and a rail are things a frame is built around) and
Solari's Heliostat.
```

## Attribute ladder

Above `const RUNSTATE := preload("res://scripts/autoload/RunState.gd")`:

```text
THE ATTRIBUTE LADDER. What a grade is worth, in PIPS on the one gauge a part
moves. Indexed by ModuleData.Rarity.

    COMMON 0   UNCOMMON 0   RARE 1   EPIC 2   LEGENDARY 3
    EXOTIC 3   ARTIFACT 4   CONTRABAND 2

COMMON AND UNCOMMON GIVE NOTHING, which is a statement and not an oversight:
yard stock is CARDS. Hull Plating used to carry +3 hull while a Brace Frame,
which is two grades rarer, carried +2 — the table was authored one part at a
time and had drifted into saying a common was better than a rare at the thing
the rare is named for. A ladder cannot drift.

The cost of that is real and worth knowing: a run now opens with no passive
stats at all, because the entire starting kit is common. The first rare part
you bolt on is the first pip you have ever had.

EXOTIC MATCHES LEGENDARY AND PAYS FOR IT somewhere else. Grown things are
alive and inconvenient, and the trade is the identity rather than a bigger
number — a Voidwhale Ganglion hears everything in the system, and everything
in the system hears it. ARTIFACT is the top of the found ladder and there are
two of them. CONTRABAND sits at Epic on purpose: it is not a quality grade at
all, it is a fact about who sold it to you, so it performs like an epic and
carries risk instead of power.
The script, not the singleton. RunState carries no class_name and Database
is the autoload BEFORE it, so `Run.PER_PIP` is a null dereference at the
moment the catalogue is built. A preload reaches the constants without
needing the node to exist.
```

Above `const PASSIVE_AXIS := {`:

```text
WHICH GAUGE A PART MOVES. The size is not here — it comes from the grade,
through ATTR_BUMP and RunState.PER_PIP. This table only answers "which one".

ONE GAUGE FOR MOST PARTS, AND TWO FOR A FEW. Cold Sights used to carry vent AND
sensors, Ghost Drive dodge AND stealth, the Fire Director initiative AND
sensors — so "a rare part is worth one pip" could not be true of any of them,
and a part quietly moving two gauges was worth double its grade with nothing
on the screen saying so. The axis is the one the NAME picks: sights see, a
drive is how you are not there, a director decides.

A part with no entry moves nothing, and most of the catalogue has none. That
is deliberate as well: the axis has to be latent in what the part IS, and a
gun is not a claim about any of the six.
```

Above `const PASSIVE_COST := {`:

```text
WHAT A PART COSTS YOU, in pips, on a gauge that is not its own.

Not a grade bump and not on the ladder — these are prices, authored per part,
and they are what lets the ladder stay flat at the top. A Solari flare rack
lights you up. A Voidwhale Ganglion is a living antenna and transmits as well
as it listens. Both were true in the flavour before they were true in the
numbers.
```

Above `func _seed_module_passives() -> void:`:

```text
Every passive in the catalogue, derived rather than authored.

This replaces two hand-written tables of raw numbers — one for sensors and
stealth, one for the four gauges under them — and the point of replacing them
is that a hand-written number cannot be checked against a rule. It is now
impossible to author a common that out-plates a rare, because nobody authors
the plating: the grade does.

Rounded into the field it lands in. `dodge` is a float and keeps its
fraction; everything else is an int, so a pip of venting is 2 rather than
1.5. That rounding is exactly why `-- attrtest` measures the gauge instead of
trusting this.
```

Above `func _lay_pips(m: ModuleData, axis: StringName, pips: int) -> void:`:

```text
Move one gauge by `pips`, through every field that gauge is made of.

THERMAL and MANEUVER each have two, and BOTH move. That is the whole point
of a gauge being one entry: a part says +1 MANEUVER and gets faster and
harder to hit, because those are not two things a player weighs separately
while reading one bar.

`+=` and not `=`, so a part can take a bump on one axis and a price on
another without the second overwriting the first. The Voidwhale Ganglion is
the part that needs it, and it would have silently lost its bump.
```

## Regrading

Above `func regrade(m: ModuleData, rarity: int) -> void:`:

```text
A PART'S GRADE AND ITS PIPS MOVE TOGETHER. Every copy of a part starts as
a duplicate of its catalogue entry, whose pips were laid for the catalogue
grade (`_seed_module_passives`). Loot can roll a part a grade up
(`LootGen.roll_module`), and a save rebuilds a part from its entry plus the
grade it was saved at (`SaveGame._module_from`). Both used to set `rarity`
alone: the readout prints pips from the grade, the gauge reads the fields,
and an Uncommon Ranging Optics rolled Rare showed SENSORS +1 and moved
nothing (Geno, Oct 22). This lays the difference between the two grades.
```

## Hull baselines

Above `const WEIGHT_BASE := {`:

```text
Twenty-four hulls: each of seven manufacturers in all three weight classes,
plus the three unbranded salvage frames.

AUTHORED AS BASELINE + SIGNATURE, not as twenty-four stat blocks. Weight class
decides the shape of a ship — a light frame is fast and thin whoever welded
it — and the manufacturer decides how that shape is bent. Writing all
twenty-four out by hand would scatter each manufacturer's identity across three
rows, so "what IS Solari" would only be answerable by diffing three tables,
and a signature could drift between weights without anyone noticing.

Here it is one line per manufacturer. Solari is +8 heat capacity, -1 dissipation and
-2 stealth, on every frame it builds. That is the whole manufacturer.

DISSIPATION IS SMALL ON PURPOSE — one or two a turn, four at the very top.
It used to run to eight, which vented a full combat's worth of heat for free
and made the cooling cards decorative: you could fire the hot weapon every
turn and the hull paid it off behind you. Passive venting is now a trickle,
so getting heat off is something you spend a card on, and capacity is what
decides how long you can put that off.
```

Inside `_lay_pips()`, above `HullData.Weight.LIGHT: {`:

```text
Two system mounts, not one. A light frame has the BIGGEST hand and the
FEWEST mounts, and those compound the wrong way: fewer mounts is fewer
modules is fewer cards, so the ship that draws six was the ship with a
five-card deck. Measured, an Atelier Yacht opened with four cards against
a hand of five — every turn identical, nothing to sequence, no deck at all.
The extra system slot is where the floor comes from.
```

Inside `_lay_pips()`, above `HullData.Weight.MEDIUM: {`:

```text
A second utility mount, because the middle had nothing of its own.

Measured across 250 runs on each of twenty-one chassis, mediums averaged
15.2% against 20.2% for lights and 21.7% for heavies — and Switchback, the
worst ship in the game, was the worst case of that rather than its own
problem. A medium had six mounts like a light and a hand of five like
nothing else: strictly between the two, with no compensating advantage.
Seven mounts is the compensation, and versatility is a coherent thing for
the middle of a range to be.
```

## Hull grades

Above `const TIER_DELTA := [`:

```text
The four specification classes a frame comes in, worst to best. A hull is a
SHAPE and a CLASS: an S-class Ironside is the same yard's answer to the same
job, built to a better standard — not a C-class that somebody looked after.

That distinction is load-bearing and was got wrong once. This table grows
HARDPOINTS at A and S, which no amount of maintenance does; condition is a
separate axis entirely, lives on hull points, and is drawn by HullWear onto
the sprite. One letter cannot mean both.

Tier has existed on HullData since the beginning and was never authored — it
was a bag of random bumps inside LootGen.roll_hull, applied to whatever frame
came out of the pick. That had two problems worth naming. It was NOT
REPRODUCIBLE as a description: "an A-class Bastion" named a distribution
rather than a ship, and two of them could differ by a hardpoint, because a
weapon mount was granted on a coin flip at B. And it was invisible — nothing
in the interface has ever shown the player a letter.

SCALE rather than flat bonuses, so a grade is the same PROPORTIONAL upgrade on
every frame it is applied to. A flat +21 hull is 87% of a light and 40% of a
heavy; +52% is +52% of both. The numbers below compound to roughly half again
the hull from C to S, which is about what the random bumps averaged out to —
the one thing here chosen to match the old behaviour rather than improve on it.

MOUNTS ARE THE REWARD, and only at the top two grades. A is where a frame
grows a weapon hardpoint; S adds a system one and the reactor to run it. That
is deliberately a bigger jump than more hull, because a mount is a card, and a
card is the thing this game is actually made of.

Applied ONLY to a tier-0 frame. `at_tier` SCALES, so handing it a hull that
already carries a grade compounds it silently. Everything in `hull_frames` is
tier 0 by construction; nothing else should be passed.
Named in HullData, which owns what a grade IS. This table owns what it DOES,
and the two are indexed the same — keep them the same length.
THE REACTOR LEVEL IS SET, NOT ADDED. Every other field here is a delta on
the frame; this one is absolute, because the grade letter is the only thing
that decides it. It used to be the weight class with a delta on top — heavy
carried a reactor of 4 and S added one — which meant C and B were the same
ship twice and the letter told a player almost nothing.

4 / 5 / 7 / 8, which RunState.REACTOR_TABLE turns into:

    C   12 cells, 3 energy       A   21 cells, 4 energy
    B   15 cells, 3 energy       S   24 cells, 5 energy

A AND S SKIP A RUNG EACH, which is where the energy steps are. The gap from
B to A is the largest on the ladder and it is meant to be: it is the one
that buys a fourth point of energy, and energy is the axis every card is
priced against.

24 AT THE TOP STILL BITES. A fully mounted S heavy is five weapons, three
systems and a utility, and the catalogue averages 2.80 / 2.55 / 1.57 cells
for those — 23.2 to fill it, against 24 with nothing spare for a big gun.
The best hull in the game still cannot run everything it can bolt on.
```

Inside `at_tier()`, above `h.tier_perks = tier_perks_for(h.manufacturer, t)`:

```text
AND THE ART. A class grants hardpoints and a reactor, and now it grants a
different hull — which is the whole point of the letter and was invisible
until there were four sprites to choose between.

The plume has to move with it. Each sprite is cropped tight to its own
ship, so the four mediums are 54 to 81 pixels tall; swapping the texture
and keeping the frame's offset would hang the flame off the bottom of the
short ones.
THE GRADE'S PERKS, alongside the reactor and the hardpoints it already
grants. Cumulative and authored — see TIER_PERKS.

See TIER_PERKS on why every manufacturer ends up with the same four at S.
```

## Hull names

Inside `_lay_pips()`, above `perk_id = &"baffled_vents",`:

```text
ONE NAME PER WEIGHT, the same C through S (Jon, Oct 15: "I just want
them to have their own unique names. One for each weight. C>S for each
weight would have the same name"). The four Korvan names a weight had
(Picket, Warden, Halberd, Sabre Cutter) are retired with the other
per-grade art: a grade is one ship graded in code now, so it is one
ship by name too, and the letter says the grade.
```

## Redline balance

Inside `_lay_pips()`, above `&"redline": {`:

```text
Measured worst in the game by a wide margin — a Switchback won 8.6% where a
Greatvine won 31.8% — and the trade is why: -6 hull off a 35-point medium
is seventeen per cent of the ship, bought with three per cent of dodge.
That was never going to pay.

It also had the one perk we PROVED does nothing. cheap_parts halves repair
prices, and cutting repair prices by 40% across the whole game moved the
win rate inside its own noise band — so Redline was effectively flying
without a perk. It takes salvage_rack instead: a chop shop that registers
no serials is a salvage yard with a shopfront. It had spare_bay for a
while, which suited the refit business and asked for a hardpoint no hull
was rigged to carry -- see the note in _seed_perks.
```

## Hull art

Above `func hull_sprite(w: HullData.Weight, cls: int = 0, half: bool = false,`:

```text
The art for a weight class at a specification class, or null to fall back to
ShipView's procedural drawing.

ONE FOLDER PER MANUFACTURER THAT HAS ART (`HULL_ART`), and Korvan's for
everyone else. Solari got its own three (Jon, Oct 15) and flies them; the
five without pictures, and the unbranded salvage frames, still wear Korvan's.
That last part is knowingly wrong -- a Calyx hull in Korvan amber -- and it
stands until each manufacturer's three are drawn: a picture in the wrong
livery is a better placeholder than a procedural box.

KEYED ON CLASS AS WELL AS WEIGHT, which is what finally makes C through S
something a player can SEE. TIER_DELTA has granted an A-class frame an extra
weapon hardpoint and an S-class one a system mount since it was written, and
none of it was visible — a C and an S were the same picture with different
numbers behind them.

Four sprites per weight rather than a base plus composited fittings. That was
the other plan and it lost: bays measured off the medium, a fitting engine to
bolt things into them, a template pipeline to force the profile. Every part
worked and the sum was worse than picking four hulls out of thirty. The
fitting engine survives in HullFit for whenever a hull has room for it.

ALL THREE WEIGHTS, twelve sprites, so the procedural path no longer draws any
player hull. `hull_medium_cold.png` stays on disk and stays the canonical
style reference every generation is seeded from — it is simply no longer the
thing rendered.
`half` asks for the reduced set the convoy column draws from. Same filenames
one folder down, so the two can never describe different hulls.
```

## Sprite lookups

Above `func module_sprite(id: StringName) -> Texture2D:`:

```text
THE SPRITE BOLTED TO A HULL for a module, or null while it has none.

Guarded on `ResourceLoader.exists` rather than handed straight to `load()`,
and that is not politeness. A missing path makes `load()` log an error every
call, and on the day this lands every one of forty-three modules is missing —
which is not a warning, it is a wall of them, hiding whatever real error
arrives next. Null is the honest answer and every drawing site already has a
procedural fallback for it.

One folder, keyed on the module's own id, for the same reason the hulls are:
the filename cannot then describe a different part than the data does.
```

Above `func material_sprite(id: StringName) -> Texture2D:`:

```text
A MATERIAL'S PICTURE, or null while it has none.

Same convention as `module_sprite`, one directory over. Materials had no art
at all until two artifacts earned some, and the forty rows of deck plate and
coil stock are expected to keep the drawn container forever -- see
`MaterialIcon`, which argues cargo should read as cargo.
```

Above `func enemy_sprite(id: StringName, look: int = 0, half: bool = false) -> Texture2D:`:

```text

Sector places, the station and every enemy are painted procedurally, and that
was a decision rather than a gap: the compositions were settled in rectangles
so that a prompt could describe a picture already checked. `StationSpine`:
"If art lands it replaces the body of `_draw`; if it never does, this is the
rail."

These three are the door that art comes through. Same shape as
`module_sprite` and for the same reasons -- guarded, null on miss, one folder
keyed on the id the data already uses. Every caller keeps its procedural body
underneath, so a family can land one file at a time and a missing file is a
drawn picture rather than a hole.
```

Above `func place_sprite(name: StringName) -> Texture2D:`:

```text
A SECTOR PLACE'S PICTURE, or null while it has none.

Keyed on a name rather than on `MapGen.NodeType`, because the picture does not
follow the type: a SYSTEM draws a battlefield, a derelict or a beacon
depending on its option tags, and a battlefield draws two ways depending on
whether it is cleared. `EncounterView.AreaView` decides which name it wants
and asks for it; the enum never reaches this function.
```

## Enemy sprites

Above `func enemy_sprite(id: StringName, look: int = 0, half: bool = false) -> Texture2D:`:

```text
AN ENEMY'S PICTURE, or null while it has none.

KEYED ON `id`, NOT ON `art`, AND THE DIFFERENCE IS THE WHOLE POINT. Nine
enemy kinds share four drawings today: `art` names the procedural BRANCH, so
the Corsair Lancer and the Vex Marauder both draw as `cutter`, and the game's
boss draws as a salvage barge. `id` is already unique per kind.

Keying the sprite on `id` therefore opens nine slots without touching the
data, and -- this is the part that matters -- WITHOUT CHANGING WHAT IS DRAWN
TODAY. Had `art` been split instead, five enemies would have got a new key
the moment the data changed, `EnemyArt`'s match would have missed on all five,
and its `_:` fallback would have quietly turned the boss into a fauna before
a single sprite existed. The fallback has to keep drawing exactly what it
draws now, or the seam is a regression wearing a plan's clothes.

SEVERAL PICTURES PER KIND, ONE PER FIGHT (Jon, 2026-10-13). An enemy id can
own a list of kept pool ships (`art/sprites/enemies/index.json`, written by
`tools/enemy_sprites.py`) and `look` picks one, wrapping: the fight stores it
on the `EnemyState` (`Combat.look_for`, positional, so every machine and the
wreck it leaves agree). An id with no list falls back to `<id>.png`.

`half` takes the picture's HALF SHEET instead (a fight with three or more
ships draws them all from it, the way the convoy draws hulls; see
`EncounterView._layout_pack`).
```

## Station plates

Above `func station_sprite(id: StringName, layer: StringName = &"wall") -> Texture2D:`:

```text
A STATION PLATE, or null while it has none.

TWO LAYERS PER PLATE, WHICH IS WHY THIS TAKES A LAYER ARGUMENT. Livery tints
the TRIM and never the walls -- `StationRoom._tint` records why: out of a
colour as dark as `#0d141d` a lerp does not tint a wall, it desaturates it,
and the shop's wall came out a neutral warm grey at every weight tried. So a
plate ships as `<id>_wall.png` and `<id>_trim.png`, the wall is drawn flat and
only the trim is tinted. A baked one-layer room would lose the livery
entirely, which is the one thing the station has that says whose it is.
```

## Hull mounts

Above `func apply_hull_lines(h: HullData) -> void:`:

```text
Copy the measured dorsal, ventral and flank lines onto a hull.

Called wherever the SPRITE is set, and for the same reason `exhaust_offset`
is: the lines are measured against one specific image, so a hull carrying
another hull's lines mounts its guns in mid-air. Keeping the two assignments
adjacent is what stops them drifting apart.
Copy the placed mounts AND the fallback lines onto a hull.
```

Above `const HULL_MOUNTS := {`:

```text
Where things bolt on, PLACED BY HAND in the rigging bench
(`art/tools/rig_bench.py korvan`) rather than measured off the
silhouette. Sprite pixel coordinates on the padded hulls.

GENERATED. Re-run the bench after replacing a hull sprite: a point
placed against art that has since changed puts a gun in mid-air,
and nothing about that fails loudly. `-- mounts` is what makes it
fail loudly.

These SUPERSEDE HULL_LINES where they exist; the lines remain the
fallback for a manufacturer whose slot count this rigging does not cover.
See HullData.mounts_along().
RE-RIGGED against the redrawn hulls. The previous 89 were placed on the
sprites that shipped before the Korvan redraw and `-- mounts` failed 18 of
them outright; these were placed in the bench on the art that is actually
here. The measured lines in HULL_LINES remain the fallback for a manufacturer
whose slot count this rigging does not cover.
```

Inside `apply_hull_lines()`, above `"solari/hull_light_a": {`:

```text
SOLARI (Oct 17), placed against Jon's three picks the way Korvan's were:
the guns on the hull's top and bottom edge ahead of the brass rings,
pointing forward, a third down the nose's spine; the systems on the ring
section, where the hull is deepest; utilities on the centre line and the
radiator crest. Clear of the stern bells, which the flame comes out of.
Listed in the order the grades open them (C first, then A's gun, then S's
system), so a C-grade ship is never missing its front pair.
```

Above `const HULL_LINES := {`:

```text
Measured off each hull's own silhouette by `art/tools/anchors.py`.

GENERATED. Re-run the tool after replacing a hull sprite; a line measured
against art that has since changed puts mounts in mid-air, and nothing about
that fails loudly. `-- mounts` is what makes it fail loudly.

Lines rather than points, because a hull carries one to five mounts of a kind
depending on weight, class and manufacturer — a fixed list of five used two at a time
clusters both at one end of the ship. See HullData.mounts_along().

Plain Vector2 arrays, not PackedVector2Array: the packed constructor is a CALL
and a `const` needs an expression the compiler can fold. Converted on assignment.
```

## Widest hull

Above `static var _widest: int = 0`:

```text
The widest canvas any player hull draws into, measured rather than typed.

Anything that CROPS a hull has to know this, and the one place that does —
the convoy strip — had it as a literal. That literal was correct against the
procedural drawing it was written for and quietly wrong the moment real art
landed: the sprites are cropped tight to their ships and run from 152 to 237
across, so a constant sized for the old canvas took the nose off every heavy
in the party. The strip's own comment said "nothing is ever cropped
nose-first, which reads as a mistake rather than as distance", which is
exactly what it then did.

So it is asked rather than remembered. Twelve `load()` calls behind Godot's
resource cache, once, on the first ask — the same twelve textures the hulls
are already built from.
```

## Exhaust plumes

Above `const DEFAULT_EXHAUST := 0`:

```text
How many strips live in art/sprites/exhaust/, named exhaust_0 .. exhaust_N-1.

A LIBRARY, not a mapping. Any ship can fly any of them; nothing here consults
weight class. 0 is the plume the game shipped with and stays the default so
this change is invisible until something picks another.

They differ in every dimension a plume can: frame 28x13 to 76x42, four
colours to thirty-one, heat through plasma, violet and viridian. That is why
the frame height below is READ rather than declared — it used to be a
constant 32, which was true of the one strip that existed and would silently
mis-centre almost every one now here.

0 IS HALF OF WHAT IT USED TO BE. The shipped plume was a TWIN — two flames
stacked in one 48x32 frame, with an empty two-pixel gap between them, which
only reads as two once it sits beside a single. It is cut at that gap and the
twin is gone: one engine per strip, and a hull that wants two draws two.

THE IDS ARE CONTIGUOUS AND MUST STAY THAT WAY. exhaust_art() indexes straight
into the filename, so a deleted file in the middle is a null texture and an
engine that silently stops burning. Removing one means renumbering the tail
down — that is what `-- exhaust` checks on every run.
24 was every plume PixelLab generated. 25 is those plus exhaust_24, which is
exhaust_3 masked to heavy_s's stern by `tools/crop_flame.py`. Only the part
inside the recess is touched -- it narrows from the cavity mouth to the apex
so the fire PLUGS INTO the wedge instead of painting over the stern. Outboard
of the mouth the plume is left exactly as drawn: that is open space, and every
profile imposed on it only cost the flare that makes it read as thrust. A new
id rather than an edit in place: hull_light_s flies on exhaust_3 too, and its
stern is a different shape.
The plume an unrigged hull falls back to. Only reachable by a hull with art
that nobody has taken through the bench; all twelve Korvan frames are rigged.
```

Above `func hull_exhaust_at(w: HullData.Weight, cls: int = 0, id: int = 0,`:

```text
Where the plume attaches, DERIVED from the hull it attaches to.

It used to be one constant, which was correct while there was one medium
sprite and silently wrong the moment there were four: each is cropped tight to
its own ship, so they are 54 to 81 pixels tall and a fixed offset would hang
the flame off the bottom of the shortest. Every medium is composed with 38px
of clearance to the left of its engines — the geometry the one hull already
had — so the plume centres on the hull's own canvas and nothing needs a table
that a new sprite could fall out of step with.
```

## Hull class names

Above `const CLASS_NAMES := {`:

```text
What each manufacturer CALLS its three weight classes.

AUTHORED BUT NOT DISPLAYED, anywhere now: the party screen and the fight's
party strip printed them too until Jon, Oct 15, "change to light medium
heavy". The screens print plain LIGHT / MEDIUM / HEAVY,
because that is what reads for a player: weight class is the fact you compare
ACROSS manufacturers, and this turns one shared word into twenty-one to learn. Kept
because the names are content rather than code, and the moment there is
somewhere flavour costs nothing — a tooltip, a shipyard, a flight record —
hull_class() is already here.

Real vessel types, one coherent family per manufacturer, escalating in size. This is
free identity: a Probate heavy called a Barge and a Verity heavy called a
Barque tell you who built them before you have read the manufacturer name, and the
hull names were already doing this work while the line underneath them said a
flat "HEAVY CHASSIS".

Korvan and Solari are the two warship lines because they are the two manufacturers
that mirror each other mechanically. Probate gets working boats: nobody names a
barge to impress you. Redline gets fast rigs and a smuggling term. Cygnet gets
the three real vessel types that exist to carry OTHER vessels, which is the
manufacturer motto stated as a hull class. Verity gets sailing rigs, where the rig
itself is the craftsmanship. Calyx gets the three real hulls with no cut
timber and no metal in them at all: a coracle is woven willow under a stretched
hide, a pirogue is one hollowed tree, and an umiak is driftwood ribs under
sewn skin, big enough to carry a whole crew. Grown, not built, literally.

The MECHANICAL word is not replaced by these, only fronted. Weight class is
what a player compares across manufacturers, and this turns one shared word into
twenty-one — so `HullData.weight_name()` stays, and the screens print both.
```

## Tier perks

Above `const TIER_PERKS := {`:

```text
WHAT EACH GRADE ADDS, per manufacturer, in order. C takes none, B the first, A the
first two, S all three — cumulative, so upgrading a hull only ever adds.

Authored rather than rolled. A hull is a thing you recognise: two Bastions
have to be the same ship, and a perk that came out of the RNG would make the
grade letter a lottery ticket instead of a promise.

WEAKEST FIRST, STRONGEST LAST, so a grade is worth what it costs. The pool
is not flat: +1 energy a turn is a fifth of a whole turn's budget forever,
+1 utility mount is a permanent extra part, and +40% on scrap is money you
still have to go and earn. The strongest one a manufacturer can get is its S.

`spare_bay` IS GONE FROM THE GAME, and for a harder reason than balance:
it granted a utility HARDPOINT, and a hardpoint is a place on a hull that
somebody put there by hand. `HullData.mounts_along` prefers the anchors
authored for a sprite and falls back to a derived line when asked for more
mounts than there are anchors -- so the perk did not add a mount where a
mount belongs, it added one wherever the arithmetic landed. A perk that
moves geometry needs the geometry rigged first, and none of these hulls
are. Three perks that move only numbers replaced it.

`cheap_parts` IS IN NO LADDER, and that is not an oversight — this file
already records that halving repair prices across a whole game moved the
win rate inside its own noise band. It is the one perk measured to do
nothing, and a grade whose reward is a proven no-op is a grade that lies.
Which leaves four working perks and a manufacturer owning one: every ladder is
therefore the other three, and TWO S-TIER SHIPS OF DIFFERENT MAKES NOW
CARRY THE SAME FOUR PERKS. The grades separate; the manufacturers stop separating
at the top. Widening the pool with perks that work is the fix, and until
there are some, this is the honest arrangement rather than a varied one
built out of a perk that does nothing.

NO `heat_sink`, AND THE FOUR LADDERS IT WAS IN GOT A SUBSTITUTE RATHER THAN A
GAP. Heat capacity is what a thermal module is for; a frame that hands you
two points of it for free is competing with the parts you bolt to it. The
replacement sits at the SAME INDEX the old perk did, because the index is the
grade -- 0 is B, 1 is A, 2 is S -- and dropping an entry would have made an
S-tier solari, probate, verity or calyx confer nothing over an A.

Each pick is the one that reads as the manufacturer rather than the one that
balances flattest: an overspec reactor for the foundry whose tagline is that
the line between reactor and weapon is philosophy, a salvage rack for the
combine that invoices other people's disasters, baffled vents for the atelier
that makes things properly, deep tanks for the company that grows them.
```

Inside `_seed_perks()`, above `&"deep_tanks": {name = "Deep Tanks", text = "Every jump costs 10% less fuel."},`:

```text
NO `spare_bay`. It granted a utility HARDPOINT, and a hardpoint is a
place on a hull that somebody put there by hand -- `mounts_along` falls
back to a derived line when asked for more mounts than a sprite has
anchors, so the perk did not add a mount where a mount belongs, it
added one wherever the arithmetic landed. A perk that moves geometry
needs the geometry rigged first, and none of these hulls are.

The three below ask nothing of any sprite. Every one of them moves a
number that already exists and is already consumed somewhere, which is
the property `cheap_parts` turned out not to have.
```

## Materials

Above `const RECIPES: Array[Dictionary] = [`:

```text

The second half of the economy: things you take OFF a wreck rather than out of
it. Credits are the currency and stay the only one — the ruling has not moved,
only the name has — but a currency cannot be a prerequisite. A recipe that costs
"40 credits" is a purchase; a recipe that costs "one precursor fragment" is a
reason to have gone somewhere. Materials are what crafting is made of, and
credits are what it costs.

`exotic` is not new. It has existed since megafauna did, as a bare int on
RunState, and it is now simply the first row of this table — same number, same
sources, one ledger. Everything that said `Run.exotic` still does.
```

Above `const RECIPES: Array[Dictionary] = [`:

```text
THE TABLE LIVES IN `MaterialTable`, not here. This file briefly carried a
two-row shadow of it (exotic and relic, with their own accessors), and the two
catalogues immediately diverged: every material authored only over there sold
for the 1-credit fallback and never appeared in a stock list, because half the
game was still reading this one. One catalogue, one `by_id`.
```

## Recipes

Above `const RECIPES: Array[Dictionary] = [`:

```text

The fabricator, as data. Every recipe is {what it costs} -> {one effect the
game already knows how to apply}, so adding one is a dictionary entry and
never a new branch — the same law modules and cards are held to.

`dev` is the minimum Development the place needs. RELIC ANALYSIS was dev 3 (a
laboratory needed a city) until Jon's Nov 3 ruling that every station has all
five decks at every level, so it is dev 0 now and a lab at an outpost reads a
relic too. What a developed system still buys is the price: the bill is scaled
by the place's service index, 45 credits on unclaimed ground down to 30 at a
capital. The `dev` gate stays for a recipe that ever needs more than a dock.

Deliberately few: one today, and there were four before alloy was retired. This is the stage crafting is built on, not crafting: the
ledger, the recipe shape, the resolver and the place it happens. Recipes that
reach into a specific module in the hold need a picker and a target, which is
the next piece of work and not this one.
```

## Enemy hull scaling

Inside `_seed_enemies()`, above `_enemy(&"cutter", "Rustjaw Cutter", "pirate skirmisher", 104, 0, 15, &"cutter", [`:

```text
HULL x4 FOR EVERY ORDINARY ENEMY, ships and creatures alike: twice the x2 of
ruling 14 (Oct 29). Jon, Nov 3, "Enemy hull: D", after he turned down a
second combat resource: "Enemies should have more health and the fights
should last longer. That's all." The study (tk-scratch/hull-study/STUDY.md,
400 runs a level, a fresh Korvan profile, the human pilot) had x4 take a
fight from 6.4 turns to 10.8, fights lost from 23% to 28%, and run wins
from 33 to 23 of 400. Fewer ships reach the core; the built ship that does
beats the Custodian 61% of the time (55% at x2). Each number below is four
times the original (cutter 26, lancer 34, hulk 52, marauder 46, sentinel
58, calf 40, leviathan 88). Danger scaling still applies on top
(`Combat._spawn`). Enemy damage did not change. The Hellbender (90) and the
Custodian (200) are tuned by hand and keep their own.
Ships run fixed loops — machines are predictable.
```

## The Hellbender

Inside `_seed_enemies()`, above `_enemy(&"hellbender", "The Hellbender", "rival harvester · a salamander device on the hull", 90, 6, 90, &"hellbender", [`:

```text
THE HELLBENDER: the galaxy's other harvester crew, and the only enemy with a
position instead of an address. Hand-tuned like the custodian — it is a
set piece wherever you catch it, so danger scaling would make WHERE you
fight it matter more than WHETHER you are ready to. Its guns sit between
the sentinel and the custodian: a party kills it comfortably, one ship
kills it with a good build and a reason. Few do: the Nov 3 study killed it
19 times in 156 fights, over all four hull levels; it mostly breaks off
first. Its hull does not sit between them: it keeps 90 under enemy hull x4
(Nov 3), so every ordinary enemy flying alone, the cutter (104) too, now
carries more. A pack's cutter (0.6 share, Combat.plan) can carry less: 62
at danger 1. Below 35% hull it spools an
escape burn and leaves — see Combat.escape_intent() — so the loop below
is what it does while it still thinks it is winning.

The name is a real salamander, and the crew is in on the joke: the hull
flies the heraldic salamander — the beast drawn sitting unharmed in
flames — which is what a ship built to drink heat would paint on itself.
The device lives in the tag, described and never explained. Nobody
explains anything in this galaxy; see docs/lore.md.
```

## The Custodian

Inside `_seed_enemies()`, above `_enemy(&"custodian", "The Custodian", "guardian of the light", 200, 8, 120, &"hulk", [`:

```text
Boss: unscaled, tuned by hand. HULL 200, up from 120 (Jon, Oct 22: "custodian
health at 200. I want this to be a hard game"): a bare starter heavy beat
the 120 one 49% of the time, and a built ship 86-100%. Hull alone stopped
starters (0%) but a built ship with deep loot still won 81%, so (Jon, Oct
22, "Option 1") the loop lost Plated Up and Annihilate went 22 -> 40: it
lands every third turn, and a built ship wins 56% of arrivals (sim, seeds
777 and 977), a human-like pilot 39%. Those sims flew one ring deeper a
jump at most. RE-RUN AT TWO RINGS UNDER ENEMY HULL x2 (Oct 29, the same
flags: Korvan only, `sturdy` for the built ship, `human`, seeds 777 and 977,
200 runs each): a built ship wins 55% of arrivals and the human pilot wins
8.25% of its runs, against Oct 22's 56% and 8%. At 150 hull those were 68%
and 9.5%; at 120, 73% and 11.25%. Jon kept 200 (Oct 30, "Custodian: A").
CHECKED AGAIN UNDER ENEMY HULL x4 (Nov 3, the same flags, 400 runs): a
built ship wins 61.4% of arrivals (59% and 65% by seed) and the human pilot
5.75% of its runs. Fewer ships arrive, and the ones that do are stronger.
It keeps 200, so a deep Hulk (291) or Sentinel (325) now carries more hull
than it does; Jon left that as it is.

IT GROWS WITH THE RUN (Jon, Nov 3: rule G3 with cap B). 200 through jump
15, then 200 x 1.04 for every jump past it, compounding, rounded, capped at
twice its hull: 208 at jump 16, 243 at 20, 390 at 32, 400 from 33 on. Hull
only; its attacks do not change. Read off `Run.custodian_jumps()` (your
jumps alone, the lead ship's in co-op, Jon, Nov 4) when its fight is
built (`Combat._spawn`, `EnemyTemplate.hull_at`), so the template below
stays 200 and nothing adds up across runs. `bossonly` flies in at 0 jumps
and meets 200. The station study (tk-scratch/station-study/STUDY.md, Nov 3,
S3 stations, `custgrow=G3` with no cap, 400 runs) had the built ship meet a
median of 253 at the core (200 to 600; the cap now stops it at 400) and win
68.9% of arrivals, against 75.5% with no growth. Its pilots shopped at every
deck, which the game's sim pilots do not, so the 61.4% above is not yet
measured again under growth.
```
