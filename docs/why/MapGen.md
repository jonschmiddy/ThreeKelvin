The reasoning behind `tkg/scripts/systems/MapGen.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Region enum

Above `enum Region { FRONTIER, TERRITORY, COSMOPOLITAN, LAWLESS, FAUNA, DEEP }`:

```text
Kept, but no longer authored - derived from the axes at generation time.
Loot bias, fauna pools, contraband stock and station inventory all branch on
it across five files, and collapsing three axes onto one label in exactly one
place beats teaching every one of those sites the new vocabulary.
WHERE YOU ARE, as a kind of place. Every value here is somewhere you visit
and the encounters gate on it.

`CORE` USED TO BE THE LAST ONE AND IT WAS NEVER A REGION. `_derive_region`
handed it to `NodeType.CORE` and to nothing else -- the boss at the centre --
and `OptionTable.ensure` refuses to roll options for the boss, so the gate
selected exactly the one node that would never be asked. Four authored
encounters were gated on it: the last lit dock, the barge on its final leg,
the relay counting down, the six ships holding. All four were committed,
reviewed, and impossible.

DEEP is the region those four were written for -- the approach, where the
claims have run out and the traffic has stopped. The word is the game's own:
it says "nobody disinterested comes this deep" in that very encounter.

Same ordinal, so a saved region still reads back as what it was.
```

## Node types

Above `enum NodeType { START, STATION, CORE, PULSAR, SYSTEM }`:

```text
WHAT KIND OF PLACE, never what is in it. FIGHT, EVENT and DERELICT were
removed 2026-08-27: what a system holds is `options` now, and those three were
only ever labels for what got rolled there.

The four that survive share one rule -- a type is a place the CHART NAMES and
that has its own interaction. A station is the telegraphed safe node with its
own screen; the core is one hand-authored boss; a pulsar is placed against a
nebula shell and harvested. SYSTEM is everything else, and 1 says so: every
system but a station looks identical from the chart.

THE ORDER IS A SAVE FORMAT, because `type` is serialised as an int. Removing
three values renumbered every one after them, which is only survivable because
`SaveGame.load` refuses a version mismatch outright -- the discard is the
migration and the version bump is what arms it. Change this list again and the
version goes with it, in the same commit.
```

## Option ids

Above `const OPTION_WHOLE := 0`:

```text
The option id meaning "the system itself, all of it".

Every encounter in the game today consumes the whole node: you strip the
wreck, you win the fight, you answer the hail, and there is nothing else
here. A system that offers three or four things to do consumes them one at a
time, and this is the id reserved for the case where there is only one.

Zero on purpose. It is what an absent field reads as, so a save or a message
written before options existed says "the system" rather than "option zero of
a list nobody wrote".
```

Above `const OPTION_SHOP := 100`:

```text
A station's shelf: `OPTION_SHOP + i` is the i-th part standing on it.

The shelf is the second contested thing in the game, and the first that is a
LIST. One station, four buyers, and one Legendary — the same shape as the
wreck, except that a wreck is taken whole and a shelf is taken a part at a
time. That is what the option id was for.

INDEXED, WHICH MEANS THE ARRAY MUST NOT SHRINK. `n.shop` used to have the
bought part erased out of it, which silently renumbered everything after it:
one purchase and every machine's idea of "slot 2" disagreed. So a sold part
stays on the shelf and is marked gone in `taken` instead, which is what that
field has always been for.

Based at 100 so the ids read as a namespace rather than as a count, and so a
fourth kind of option added later has somewhere obvious to live.
```

Above `const OPTION_BAG := 200`:

```text
What a shared kill left floating: `OPTION_BAG + i` is the i-th part in it.

The third contested thing, and the second that is a LIST — so it is the
shelf's shape rather than the wreck's, and for the same reason: a bag is taken
a part at a time. `MapNode.bag` therefore never shrinks either. See `taken`.

Based at 200 rather than 120 so the shelf keeps room to grow. A station that
one day stocks more than ten parts must not start renumbering into the bag.
```

Above `enum Star { ORDINARY, RED, BLUE }`:

```text
What a system holds: `OPTION_SITE + i` is the i-th option rolled at it.

The fourth contested thing, and the LIST the other three were rehearsals for
-- `OPTION_WHOLE`'s comment says almost apologetically that it is the id for
"the case where there is only one", and this is the case where there is not.

BASED AT 300 RATHER THAN 210, following the same reasoning `OPTION_BAG` gives
for not sitting at 120: the bag keeps room to grow, and a system may one day
hold more than the current 2-4. Never re-base an existing constant -- these
numbers are in saved `taken` arrays and in the co-op claims table.

AND THE LIST MUST NEVER SHRINK, which is the lesson `OPTION_SHOP` learned the
hard way: `n.shop` used to have the bought part erased out of it, silently
renumbering everything after it, so one purchase and every machine disagreed
about slot 2. A taken option stays in `MapNode.options` and is marked in
`taken`.
The sky over a system, for the options that describe it.

ORDINARY is most of them and says nothing. FLARE is a star that throws
tantrums, which is what `corona` and `flare_shelter` are both about, and it
is the one that has to be MUTUALLY EXCLUSIVE with a quiet star -- you cannot
shelter from a flare at a system whose star does not throw any.
RED and BLUE are both hypergiants -- the two ways a star can be big enough to
be a problem -- and ORDINARY is everything else, which is most of it.

`FLARE` was the first name for the red one, from when it existed only to gate
two encounters about a star throwing tantrums. It is RED now because the
chart paints it: what you see from three systems away is the colour, and a
name that describes the hazard rather than the star reads backwards the
moment the star is the thing on screen.
```

Above `const OPTION_JETSAM := 1000`:

```text
Every container in a system: `OPTION_JETSAM + h * JETSAM_STRIDE + i` is the
i-th thing in the h-th one.

The fifth contested list, and the first that is a list OF lists. A system used
to hold one bag, so `OPTION_BAG + i` was enough; it now holds one container
per hull you killed plus one of its own, and those are separate piles that
have to be claimed separately.

BASED AT 1000, and the reason is the one this file already gives twice: never
re-base an existing constant, because these numbers are in saved `taken`
arrays and in the co-op claims table. `OPTION_BAG` keeps its hundred slots and
keeps meaning what it always meant; nothing renumbers.

THE STRIDE IS A CEILING ON ONE CONTAINER, not on how many there are. Sixty-four
is far past what a wreck holds -- drops are single digits -- and the cost of
being wrong is two containers sharing a claim, so it is deliberately loose.
```

## Option results

Above `const R_SUCCESS := &"success"`:

```text
WHAT BECAME OF AN OPTION. `MapNode.results` holds one of these per spent
index, and the drawer turns it into the word stamped across the dead card.

`GONE` is the one that is not an outcome: it is the other half of an
exclusive set, closed by the choice you made rather than by anything you did
to it. Kept distinct from `DONE` because "you resolved this" and "you can no
longer resolve this" are opposite facts that would otherwise share a word.
```

## Jetsam

Above `const SITE_ANY := -99`:

```text
One container of loose things, sitting in a system.

NAMED FOR THE VERB. `jettison` is what you do to fill one, and jetsam is that
verb's own noun -- goods put over the side of a ship. The two words teach
each other, which no other candidate did: this was `Hoard`, which implied
treasure, and then `Flotsam`, which is wreckage that floats free rather than
anything anybody decided to drop.

A wreck's contents are the half this name fits least -- nobody threw those
overboard, the ship simply stopped being one. It is still the right word,
because the thing a player DOES here is throw things away and come back for
them, and the container is named after the action rather than the accident.

A WRECK IS ONE, AND SO IS THE FLOOR. What a hull was carrying when you killed
it and what you have put down here are both piles you reach into, and making
them the same class means the popup, the claim, the sweep and the save all
have one thing to know about.

They persist. Jump away and come back and your wrecks are still where you left
them with whatever you did not take still in them, which is the whole point of
it being the system's state rather than the fight's.
A wreck with no place: shown at every place in its system (see `Jetsam.site`).
```

Above `var site: int = -9`:

```text
WHERE IN THE SYSTEM IT LIES (Jon, Oct 14: "each planet or POI you can
visit should contain its own wrecks/fights"): the body your ship orbited
when the hull died, as `SystemMapScreen._parked` writes it -- -1 the
star, -9 open space, or `SITE_ANY` for a wreck from a save made before
wrecks had a place, which shows wherever you are, as it always did.
LOCAL draws only the wrecks of the place you are parked at.
```

Above `var opened: bool = false`:

```text
Whether you have looked inside this wreck. From then on whatever you
leave in it is also under the system's SECTOR LOOT (Jon, Oct 15: "When a
wreck is opened, and all or some of the parts are left behind, those
should also show up in the sector loot pool for that sector").
```

Above `func title() -> String:`:

```text
THE WORD OVER THE GRID, which is not one word.

Jetsam is what you throw over the side, and nothing was thrown over the
side of a ship you shot: it stopped being a ship and what it was carrying
is now yours to recover, which is the dictionary definition of salvage.
One class, because a pile is a pile and the popup, the claim, the sweep
and the save all want exactly one thing to know about -- but ONE class is
not one noun, and the screen should say the true one.

Asked of the container rather than set on it, because there is nothing
here a wreck knows that `art` does not already carry. A third kind (what
an event outcome hands you) needs a door in the sector before it needs a
field, so it is not invented here.
```

## Sector loot view

Above `class PileView extends Jetsam:`:

```text
SECTOR LOOT AS IT IS SHOWN: the system's own pile and what is left in every
wreck you have opened, in one grid (`RunState.sector_loot`). A VIEW, never
stored: each thing stays in the container it is in and is claimed there
(`option` answers that container's claim), so taking it here or out of the
wreck is one claim, and the lists still never shrink. Built fresh each time
the door is opened; something put down while it is open goes on the real
pile and onto the end of this (`RunState.put_in`).
```

## Ring layout

Above `const LAYERS := 15`:

```text
Eight shells, wide apart, rather than twenty-four thin ones.

Twenty-four rings put the systems in a shape where nothing was near anything:
a ring step was 0.03 of the disc while the gap between neighbours ON a rim
ring was 0.51, a factor of seventeen. Neighbours along your own ring were
half a galaxy away, and a system that looked adjacent was four rings deep and
therefore unreachable. Eight shells with populations set by perimeter puts
every neighbour at roughly the same distance in every direction, which is
what makes "fly to anything close enough" a rule you can actually see.

FIFTEEN, up from nine, and the paragraph above is why this is safe now.

The twenty-four-shell version failed because the ring STEP collapsed while
the gap along a ring did not. That was not a fact about the ring count -- it
was a fact about `target` below, which set the radial gap and the ring
POPULATION with one number. Shrink the gap and every ring inflated to match,
so the geometry that made nothing near anything came back at any layer count.

`RING_SPACING` now owns the gap and `LAYERS` owns the depth. With them apart,
fifteen shells is fifteen shells at the spacing that was hard-won.

WHY THE RUN GOT LONGER ANYWAY. `_link()` gives every system a coreward link,
so the shortest path to the core is one hop per ring: it was 8, it is now 14.
That is the forced minimum, not the typical run -- the sim takes 38 jumps
either way -- so what this buys is that the fast dive is longer, not that the
ordinary run is.
```

Above `const RING_SPACING := 0.1157`:

```text
How far apart systems sit ALONG a ring, as a fraction of the disc.

NOT THE GAP BETWEEN RINGS, despite being split out of a value that was. That
is the whole subtlety: `ring_count` divides a ring's perimeter by this to
decide how many systems it holds, so it sets the spacing AROUND a ring, and
the gap BETWEEN rings is (RIM - CORE) / (LAYERS - 2), which necessarily
shrinks as layers are added because the disc does not grow.

Holding it constant is the point of phase 3. It used to be the derived ring
gap, so adding layers shrank it and inflated every ring's population at the
same time -- LAYERS 15 gave 528 systems and pinned sixteen rings at RING_MAX.
Fixed at the value it had when the geometry was tuned, LAYERS 15 gives ~287.

The rings being closer together than the systems along them is fine and is
not the twenty-four-shell failure: `range_from` derives the jump radius from
your NEAREST neighbour, so a tighter ring stack gives a tighter radius rather
than a map where nothing is near anything.
```

## Door share

Above `const DOOR_SHARE := 1.00`:

```text
What share of a ring's systems carry a link inward.

The dial for phase 5. At 1.0 every system has a door, the shortest path is
one hop per ring, and lateral travel is decoration -- which is what it was.
Below that, crossing a ring becomes how you find the way down.

PARKED AT 1.00, WHICH TURNS THE FEATURE OFF. Every system carries a door, as
it always did, and the machinery below is inert until this moves.

The MAP is not the problem: `-- maptest` passes on 120 galaxies at 0.40, with
every ring enterable and the core always reachable, and the forced path rises
from a flat 14 to 17..21..28. What does not work is the simulated pilot --
`Policy.choose_jump` has no way to ROUTE. With a door under every system it
never needed one: take a forward link if there is one, farm otherwise. On a
sparse map it must walk to a door it cannot see, and instead it circles the
rim. Measured at 0.40: 98.8% of runs stranded, average danger reached 1.72,
seventy-seven jumps without leaving the first two rings.

So this waits on pathfinding in the sim, not on a different number here.
Turning it on before that would be tuning a game against a model that cannot
play it -- the mistake FUEL_PER_DISC_RADIUS's own comment warns about.

PICKED FROM MEASUREMENT, not from the 0.5-0.66 the brief suggests -- that
range was guessed against a mechanism that turned out to be inert, because
the old reachability pass restored a door for every forward system whatever
this said. With that relaxed, `-- maptest` over 120 galaxies gives:

    share   doors/ring   forced path  min .. mean .. max
    1.00       20.4          14  ..  14.0  ..  14      (what it was)
    0.55       11.0          15  ..  17.9  ..  22
    0.40        7.9          17  ..  21.2  ..  28      <- here
    0.30        6.1          18  ..  25.1  ..  33
    0.18        3.8          23  ..  34.8  ..  59

0.40 puts the fast dive at 21 against a farming run of about 38, so diving is
still faster and no longer nearly free. The spread matters as much as the
mean: the forced path used to be 14 in EVERY galaxy, and how hard a galaxy is
to descend is now a property of that galaxy.
```

## Ring radii

Above `const RIM := 0.92`:

```text
Where each ring sits, as a fraction of the disc radius. Lives here rather
than in the chart because the map's populations are derived from it: if the
two ever disagreed, ring counts would be weighted for radii the chart does
not draw.

RIM IS AUTHORED, and it was briefly derived from the ring spacing before the
starchart objected. `ring_radius()` spreads however many rings it is given
across RIM..CORE, so raising LAYERS packs them tighter rather than widening
the disc -- which looked like a fault worth fixing by deriving RIM upward.

IT IS NOT ONLY THE OUTER RING'S RADIUS. It is the extent the whole chart
normalises against: `StarchartScreen._radius()` is screen-derived and never
reads this constant, so node positions, the halo that paints the disc, and
the pan clamp all assume galaxy coordinates top out near here. Pushing RIM to
1.61 put the rim outside the painted halo -- a hard elliptical edge with
unpainted space inside it -- and outside the pan limit, so the sides of the
galaxy could not be reached while zoomed.

That is one constant doing two jobs, which is the same fault this phase set
out to fix in `target`. What made it hard to see is that the second job lives
in a file which does not import it.
```

Above `static func ring_radius(layer: int) -> float:`:

```text
The Core is not a ring, it is the middle. Spreading the schedule across all
LAYERS spent the innermost ring on the Core and then drew the Core at zero,
which left a third of the disc radius — the brightest part of the galaxy —
with nothing in it at all. The populated rings run RIM to CORE between them;
the Core sits inside the lot.
THE HOLE IS APPLIED HERE, so that everything asking where a ring is gets the
same answer. It used to be applied at the placement site only, which meant
`ring_count` sized a ring's population from the un-holed circle while
`galaxy_pos` drew that ring somewhere else entirely.

On a Collisional Ring (`ring = 0.52`) the innermost ring was counted for
radius 0.110 and drawn at 0.573 -- 5.2x the circumference, carrying the
population of the small one. The field thinned toward the middle, which is
the opposite of what the weighting in `ring_count` exists to do, and left
gaps a sensor-gated ship cannot see across.
```

## Ring population

Above `const DANGER_MAX := 10`:

```text
How many systems a ring holds: enough that the gap between neighbours along
it matches the gap between rings.

This is what makes the field even, and it is worth being clear about the
trade. Populations proportional to perimeter mean uniform density by AREA,
not density that follows the galaxy's light — a rim ring carries 42 systems
and a core ring 14 because the rim ring is enormous. Some light bias survives
anyway, because the rings themselves are packed toward the core, so systems
per unit area still rises as you go in. What is gone is the deliberate
coreward crowding; what is bought is a map where your neighbours are your
neighbours.
Danger runs 1 to 10. The number you see is the fine-grained one; the systems
whose balance was tuned against a five-tier ladder — enemy pools, loot rarity
gates, hull tiers, station stock — read it through tier() instead, so widening
the scale changed how precisely difficulty ramps without silently reweighting
every drop table in the game.
```

Inside `ring_count()`, above `var den := float(Run.galaxy.get("density", 1.0))`:

```text
DENSITY, NOT SQUASH. This used to read the galaxy's foreshortening --
`squash` is a CAMERA ANGLE, per its own docstring, "1.0 is face-on round,
0.3 is edge-on" -- and multiply ring populations by it. You do not lose a
fifth of a galaxy's stars by tilting the camera. Measured over 500 runs it
was worth 132 systems on a Lenticular against 188 on a Round Elliptical.

`density` is the same variation, authored per kind and said out loud.
```

Inside `ring_count()`, above `var target := RING_SPACING`:

```text
THE RING SPACING, not a value derived from LAYERS. It used to be
`(RIM - CORE) / (LAYERS - 2)`, which meant this divisor moved every time
the layer count did -- so adding rings inflated every ring's population as
well, and the node count grew faster than the shells. Measured: LAYERS 15
with the old derivation gives 528 systems and pins sixteen rings at
RING_MAX; with the spacing held it gives ~287.
```

Inside `ring_count()`, above `var perim := PI * r * (1.0 + SQUASH_REF) * den`:

```text
A ROUND ring's perimeter, referenced to the NOMINAL galaxy. It was
`PI * r * (1.0 + sq)` -- the squashed ellipse's -- which is where the
camera angle got in.

SQUASH_REF rather than 2.0, and that matters. The true circumference is
2*PI*r, and using it raised every ring's population by about a quarter
because the old formula was measuring a foreshortened ellipse: ~287
systems became ~360. Anchoring to the tilt of a nominal galaxy means
`density = 1.0` reproduces exactly what that galaxy always had, and no
galaxy's population depends on its own camera angle any more.
```

## Danger tiers

Above `const TIER_NAMES: Array[String] = ["", "EASY", "ROUGH", "HARD", "BRUTAL", "LETHAL"]`:

```text
THE FIVE RUNGS, IN WORDS. Display only.

The ladder was always there -- `tier()` has collapsed danger to five since the
scale widened, and enemy pools, loot gates, hull tiers and station stock have
all been read through it -- but it had no name a player could see, so the one
number they DO see (danger, 1 to 10) carried the whole ladder implicitly.

NEVER IN ENCOUNTER PROSE. An encounter says what is in front of you; naming
its tier would be the fiction reading its own gate out loud. This is for the
chart and the tooltip, where the question is "how bad is it over there".
```

## Ring weighting

Inside `ring_count()`, above `var depth_r := _ring_radius_raw(layer)`:

```text
Weighted toward the middle. Populations straight off the perimeter give
even spacing everywhere, which reads as a uniform grid of places — and it
puts most of the galaxy out on the rim, where the danger is lowest and
there is least reason to be. Tilting it inward means the frontier is
genuinely thin and the deep galaxy is genuinely crowded, which is the
shape of the run: sparse and safe at the edge, dense and lethal in.
The curve matters more than the endpoints. A linear tilt from 0.44 to 1.5
still put roughly the same number of systems on every ring — the perimeter
shrinks inward at almost the rate the weight grows, so they cancel and the
field comes out flat however the endpoints are set. Raising f to a power
breaks that cancellation: the weight stays low across the outer half and
then climbs steeply, which is what actually empties the frontier and packs
the deep galaxy. Areal density now runs about fifty to one from rim to
core, against six to one before.
DEPTH OFF THE UNHOLED SCHEDULE, not off where the ring is drawn. `r` above
is the drawn circle, and on a ring galaxy the drawn circles are compressed
into [hole, 1] -- so reading depth off it tells this weighting that every
ring is out near the rim, and the innermost gets the rim's weight of 0.14
where it wants the core's 3.3. Perimeter is geometry and weight is depth;
they were the same number only because the hole used to be applied later.

Identical for every galaxy with no hole, where the two radii are equal.
```

Inside `ring_count()`, above `var weight: float = lerpf(0.80, 1.80, pow(f, 1.6))`:

```text
FLATTENED, from 0.14-3.3, so that a FIXED jump radius can work at all.

The steep curve above is still the right description of what this used to
do and why -- it emptied the frontier and packed the deep galaxy, about
fifty to one by area. It is incompatible with a fixed range: options scale
as (R / spacing)^2, so a 3x spacing gradient is a 9x option gradient, and
no single radius serves both ends. Measured at R = 0.12, the rim offered
zero systems and the deep galaxy offered ten.

At 0.80-1.80 spacing varies 1.4x instead of 3x and every ring is jumpable.
What the galaxy loses in radial character it should get back from its
SHAPE -- dense along the arms, thin between them -- which is a property a
player can actually see, and which a fixed radius does not fight.
```

## System fields

Inside `ring_count()`, above `var star: Star = Star.ORDINARY`:

```text
WHAT THE STAR HERE IS. One per system, because a system has one star.

PULSAR IS DELIBERATELY NOT IN THIS LIST. `NodeType.PULSAR` already means
"a pulsar, and you can fly to it and harvest the beam" -- so a SYSTEM
whose star was also a pulsar would make some pulsars harvestable and
some not, which is two rules for one object. What an option like
`the_sweep` actually says is "a pulsar, CLOSE", and that is `near_pulsar`
below: a fact about the neighbourhood rather than about this star.
```

Inside `ring_count()`, above `var fled: bool = false`:

```text
Contact was broken here and you have not left since. NOT the same as
cleared: the hostile is still out there, so returning re-engages, and
nothing was salvaged. It exists because the sector has to be able to tell
"you have not fought this yet" from "you just ran from it" — the first
offers ENGAGE, the second must not, or the button that got you out of a
fight is the same button that puts you back in one.
```

## Twin suns

Inside `ring_count()`, above `var twin: bool = false`:

```text
TWO STARS (ruling 20, Oct 30): a second sun beside this system's own, with
worlds round each and round both (`SystemLayout.twin`). Ordinary SYSTEM
nodes only. Decided at generation off its own derive tag, never a shared
stream, and saved like `star`, so a save from before it loads with none.
```

Above `const TWIN_CHANCE := 0.25`:

```text
TWO SUNS (ruling 20, Oct 30): about one system in four that may have them
does (`twin_ok`). Rolled here, after `_seed_pulsars`, where a node's type and
star are final, and off a stream of the node's own (`Rng.derive(&"twin",
index)`, whose first draw this is; the layout draws the pair from the rest),
so no other roll in the galaxy moves.
```

Above `const BINARY := "BINARY"`:

```text
WHAT A SYSTEM WITH TWO SUNS IS CALLED wherever a player reads it: the sector
page's class line, the chart's STAR row (Jon, Nov 1: "Let's call it Binary
instead of two suns"; both read TWO SUNS). In a sentence, "a binary system".
```

## Option state

Inside `ring_count()`, above `var taken: PackedInt32Array = PackedInt32Array()`:

```text
Which of this system's options have been used up, by option id.

`cleared` says the system as a whole is finished; this says WHICH parts of
it are gone. They are not the same question the moment a system offers
more than one thing to do — one ship strips the wreck and another still
wants the fight, and a single boolean cannot hold that.

Option `MapGen.OPTION_WHOLE` is the system itself, which is what every
encounter that exists today consumes. So a node with one thing to do
carries exactly one entry and the two fields agree, which is why nothing
reading `cleared` had to change.

In a party this is a copy of what the host holds. See NetSession.claims.
```

Inside `ring_count()`, above `var results: Dictionary = {}`:

```text
WHAT EACH SPENT OPTION CAME TO, by its index in `options`.

`taken` says an option is done and nothing said what happened. That was
enough while a spent option vanished off the list; it is not enough now
that the card stays and says SUCCESS or BOTCHED across itself, and it has
to survive a jump away and back -- what you did in a system is a fact
about the system, exactly as its wrecks and its jetsam are.

One of `MapGen.RESULTS`. Absent means an option nobody has touched.
```

Inside `ring_count()`, above `var left: Dictionary = {}`:

```text
WHAT THE SYSTEM MAP'S CARDS SAY BESIDES THE STAMP, by option index, so it
survives a reload (Jon: "left alone should survive a reload").

`left` is a walk-away: the first line of what leaving said. Walking away
spends nothing -- the option is exactly as you found it and still takes --
but the card says LEFT ALONE, STILL OPEN, so you can see you looked.
Taking it later removes the entry.

`said` is a taken option's line, as [what moved, first line of the
outcome]: "FUEL -16" and "You put sixteen units across." The band is in
`results`; this is only the words.

YOURS ALONE IN A PARTY. Written only where you choose
(`OptionResolve.take`) and never claimed or synced, so a partner walking
away from something does not change your card. `results` is the same.
```

Inside `ring_count()`, above `var options: Array[StringName] = []`:

```text
What this system holds, as option IDS rather than definitions.

Ids so a save can rebuild the list after the table has changed underneath
it -- an unknown id is dropped with a warning rather than refusing the
save. Definitions are resolved lazily through `OptionTable.by_id`, never
stored: at ~290 systems, building every closure to answer "what is here"
is the pattern `ENCOUNTER_REBUILD.md` 5a warns about.

Rolled once in `Router._roll_here()` before the autosave, like `foes` and
`event_key`, so quitting and resuming cannot re-roll them.
```

## Ambush

Inside `ring_count()`, above `var ambush_pending: bool = false`:

```text
What followed your heat trail in, rolled once on arrival. Stored on the
node for the same reason `foes` is: an ambush that re-rolled on resume
would be a hostile you could refuse by quitting and coming back cold,
which is save-scumming through the front door.
Whether a fight is OWED here because your heat brought one in.

A FLAG RATHER THAN THE PACK. `ENCOUNTER_REBUILD.md` 6 asks for the node
state to go away entirely, and that cannot be taken literally: `_roll_here`
runs at Router:253 and the autosave at :263, so whatever arrival decided is
on disk BEFORE the ambush resolves at :272. With nothing stored, a player
who quits on arrival resumes with `ambush_rolled` already true and nothing
waiting -- which is exactly the refusal the safe-point rule exists to stop,
and which the comment above states in as many words.

What is waiting is not stored because it need not be: `_roll_foes` is
positional off `Rng.derive(&"foes", index)`, so it answers the same way
every time it is asked, on every machine.
```

## Loot pools

Inside `ring_count()`, above `var bag: Array = []`:

```text
What the party's kill left floating, as `ModuleData`. See
`MapGen.OPTION_BAG` and `RunState.open_bag()`.

ONE POOL, NOT ONE PER SHIP. Two ships used to each roll their own drop off
their own seat-salted stream, which is duplication solved and distribution
never attempted: the party was paid twice for one frigate. The bag is what
the kill was worth to the party, and who ends up carrying each part is a
decision somebody makes rather than a thing the game decides for them.

Like `shop`, THIS ARRAY MUST NOT SHRINK — a taken part stays in it and is
marked gone in `taken`, or two machines stop agreeing what "part 2" is.
```

Inside `ring_count()`, above `var jetsam: Array = []`:

```text
Every container in this system: wrecks in the order you made them, plus
the system's own pile whenever something has been put down here.

SEPARATE FROM `bag`, which stays exactly as it was. That array is the
shared-kill pool and its claims are numbered from `OPTION_BAG`; renumbering
it into here would break saved runs and the co-op claims table for no gain.
New work uses jetsam; `bag` is left alone until it has no callers.
```

## Station stock

Inside `ring_count()`, above `var stocked: bool = false`:

```text
Stocked ONCE, and never again.

Not the same test as `shop.is_empty()`, which is what this used to be, and
the difference was an exploit: buying a shelf out emptied the array, so the
next visit re-rolled a full one. A station was an infinite supply of parts
and — before Market closed the other half of it — an infinite supply of
money. A station is a place, not a vending machine. What is on the shelf is
what somebody brought here, and when it is gone it is gone.
```

## Rolled on arrival

Inside `ring_count()`, above `var foes: Array[StringName] = []`:

```text
What is waiting here, rolled on arrival and then fixed for the life of the
run. [0] opens the fight and the rest are the pack.

On the node rather than in Router for the same reason `shop` is: it has to
survive a save. Rolled at the moment the fight started, a force-quit and a
resume re-rolled the enemy, so a bad draw cost nothing to reject — which is
the one thing SaveGame's header says a suspend save must never buy.
```

## System names

Above `static func star_name(n: MapNode) -> String:`:

```text
A name, fixed for the life of the run. Hashed from the index rather than
rolled, so the same system is called the same thing every time you look.

AND NEVER TWO SYSTEMS TO ONE NAME. The hash alone gave the same name to
index 9 and 155, 10 and 122, and fifty other pairs below 300 -- every
galaxy had a dozen or more names that meant two places. A contract names its
system by name, so "OMEGA THORN REACH" sent the player to whichever of the
two they found first, and the work was not there (Jon, Oct 22: "Quests don't
show up in the sectors they say they are"). `_combo` keeps the hashed name
for the lower index and moves a later one to the next free suffix, so most
names are what they were and none is shared.
```

## System colour

Above `static func star_kind(n: MapNode) -> String:`:

```text
Colour follows the axes: one manufacturer flies its colours, several read as neutral
trade, and unclaimed space is dim.
What colour a system is drawn.

Five states you can name, and deliberately NOT one colour per manufacturer.

The manufacturer colours are accents: small highlights on a module sprite, where
being a few points apart is exactly right. Reused as the identity of a whole
system they stopped working — redline and calyx are both muted greens within
a hair of each other, probate and korvan are both browns, and cygnet sits on
top of the unclaimed grey-blue. On a chart of a hundred and fifty icons that
is not a code, it is noise that looks like a code.

Which manufacturer holds a place is a detail you read when you point at one, and the
tooltip and the panel both say it in words. What the chart has to carry at a
glance is whether anyone holds it at all.
THE STAR, IN WORDS. Beside `star_colour` because they are two readings of
one fact and the panel prints both -- the swatch says which and the words say
what, and a player who never learns the colour can still read the row.

`star_kind` and not `star_name`: that name was taken sixty lines up by the
thing that names a SYSTEM -- Epsilon Tallow III -- which is what you would
reach for first and would have compiled quietly in half the places it is
wrong.
```

Above `static func star_colour(n: MapNode) -> Color:`:

```text
WHAT COLOUR A PLACE IS, and it is the colour of its star.

This was a development gradient: two berths pale, one berth grey, none dark,
lawless-but-held amber. It read as a manufacturer map because more berths
meant brighter, and it meant the whole galaxy was tinted by PAPERWORK -- who
holds a claim here -- rather than by anything you could see out of a window.

It feeds more than the chart. `SpaceBackdrop` takes the dust from it,
`EncounterView` tints the whole sector with it, and the chart glyphs and
nebula wash both use it -- so standing in a red hypergiant's light now looks
like standing in a red hypergiant's light, everywhere at once.

WHAT IS LOST: fauna space was teal and lawless-but-held was amber, both
readable at a glance. Those are facts about people and animals rather than
about the sky, and they stay on the tooltip and in the destination panel.
A star is the thing a system IS.
```

Above `static func swatch(t: NodeType, star: Star = Star.ORDINARY) -> Color:`:

```text
THE SAME ANSWER WITHOUT A NODE TO ASK ABOUT, for the chart's key.

The key had its own hard-coded colours and they had gone wrong: it drew
SYSTEM in violet (#b08ad0) and STATION in pale blue (#8ec8e6) from back when
a system was tinted by who held it. Since the colours became STARLIGHT the
chart has drawn both in the colour of the star -- so the legend was naming
two colours that appear nowhere on the map it is a legend for.

A legend that disagrees with the picture is worse than no legend, and it is
the first thing the chart primer points at. So there is one implementation
and `star_colour` is a call to it: a key entry asks what an ORDINARY star of
some type looks like, a real system asks about itself, and neither can drift
from the other.
```

## Type labels

Above `static func type_label(t: NodeType) -> String:`:

```text
What kind of place this is, in a word.

FROM THE ENUM ITSELF, so it cannot drift from it. This was a hand-written
array indexed by the enum value, and the collapse on 2026-08-27 renumbered
every value without touching it: STATION read "FIGHT", CORE read "STATION",
PULSAR read "EVENT" and SYSTEM read "DERELICT". Four of five node types named
themselves wrong on the sector screen for a day.

Nothing failed. The array was still seven entries long and every lookup was
still in bounds, which is the whole hazard of a parallel array: it does not
break when it stops corresponding, it just answers a different question.

The warning was even written down, above the enum -- "type_label indexes this
by value, and inserting in the middle would silently relabel every node type
after it". It survived the edit it was warning about because it was a comment
and comments do not run. `keys()` does.
```

## Dock desk

Inside `place_blurb()`, above `var desk := Contracts.dock_desk(n)`:

```text
A STATION WITH NO BERTH still posts work (Jon, Nov 3), for its dock
desk (`Contracts.dock_desk`), and says who, so the chart's delivery
square on a place nobody holds has a reason under it.
```

## Start node

Inside `generate()`, above `nodes[0].taken.append(OPTION_WHOLE)`:

```text
And say so in the same vocabulary as everything else that finishes a
system. The start is consumed at generation rather than through
RunState.take_whole(), so without this it is the one node in the galaxy
whose `cleared` and `taken` disagree — and SaveGame infers the missing
entry when it reads an old save, which makes it disagree only AFTER a
round trip. That is exactly the shape of bug savetest exists to catch.
```

## Flyable core

Above `const FLY_MARGIN := 0.95`:

```text
THE CORE CAN ALWAYS BE FLOWN TO, by the slowest ship (Oct 11). Placement
decides where every system sits from the galaxy's brightness, and nothing in
it promised a route: seed 65867625, a Magellanic Irregular, put the start
alone in the dark at the rim, its nearest system 0.243 away against a jump
radius of 0.18 (0.234 with the starting engine), and the run could not leave
its first system. `-- maptest` caught it once in a gate run, because it was
rolling 120 fresh galaxies each time; the seed is pinned there now.

So after placement, walk the galaxy the way a ship with no thrust bonus flies
it (`Run.JUMP_RADIUS`, a little under, two rings deeper a jump at most, and
the last ring's free approach to the core, `RunState.reachable_from`). If the
core is out of reach:
  1. a start with no neighbour trades places with the rim system that has
     the most -- the start is just where the run begins, so this moves the
     ship and nothing else;
  2. any wall left is bridged where it is narrowest: the nearest system
     beyond it on a ring next to one already reached is moved round its own
     ring to beside that one, until the core is reached. Still a NEXT ring
     under the two-ring rule (Oct 27): a hop one ring in is legal under any
     cap, and moved beside its partner it sits one ring gap off (0.062), well
     inside the radius, so a bridge always crosses.
A galaxy that was already crossable is not touched (one walk, no moves).
```

## Pulsar neighbours

Above `static func _mark_pulsar_neighbours(nodes: Array) -> void:`:

```text
WHICH SYSTEMS HAVE A PULSAR FOR A NEIGHBOUR.

After `_seed_pulsars`, because it decides the types -- and before anything
reads it, because `admits` will ask this of every system for every option and
measuring a distance each time is a scan repeated for an answer that cannot
change once the map exists.

THE RADIUS IS THE ONE SIGHT USES. A beam that sweeps your arc every eleven
seconds is a thing you can see from where you are standing, so "close" here
means the same as "close" everywhere else on this map rather than a second
number nobody can reconcile with the first.
```

## Pulsar axes

Inside `_roll_axes()`, above `n.development = Development.UNCLAIMED`:

```text
Nothing is established beside a neutron star. The beam sterilises
whatever it sweeps and the wind strips the rest, so there is no
outpost to police, no manufacturer with a claim on it, and nothing living
that migrates through — a pulsar is weather, not territory.

Re-run rather than rolled in place: _seed_pulsars sets the type long
after the axes have been rolled, so it calls back into here to undo
them. The depth argument is ignored on this path.
```

## Sky roll

Inside `_roll_axes()`, above `var sky := Rng.world.randf()`:

```text
THE SKY, rolled here for the reason fauna is: it is a property of the
place, decided once off `Rng.world`, so four machines agree about it and a
save carries it without anything having to recompute.

A flare star is rarer than a gas giant and does not care where it is --
stars do not respect development. A giant is common because most systems
have one; it is furniture, and the option that wants it is about being
caught in the well rather than about the planet being unusual.
Rare on purpose, and rarer than the eighteen per cent the single FLARE
kind had: a sky worth remarking on has to be a minority of the sky. Twelve
and eight leaves four systems in five ordinary, which is what makes the
other one worth crossing the chart to look at.
```

## Hazards

Above `static func hazards(n: MapNode) -> PackedStringArray:`:

```text
Collapse the three axes back onto the old label, once, here. Order matters:
the most specific claim about a place wins.
What is wrong with a place, as short shouted words.

Kept here rather than in the panel that happens to draw it, because a hazard
is a fact about the sector and more than one screen wants to say it — the
chart warns you before you commit the fuel, the sector screen reminds you
once you are standing in it.

Deliberately a LIST. Somewhere can be both inside a nebula and on top of a
neutron star, and the honest answer then is both lines, not whichever one
the code happened to test first. New hazards get added here and appear
everywhere that asks, with no screen needing to learn about them.
```

## Region derivation

Inside `_derive_region()`, above `if n.layer >= DEEP_FROM:`:

```text
THEN DEPTH, over everything else. This first took the slot FRONTIER would
have had, on the reasoning that a deep system somebody still works is a
Territory first -- and that excluded the one encounter of the four that
needs a dock. "The last berth" is a lit counter with a clerk behind it and
no traffic since before her posting: a berth in the deep is not a
contradiction, it is the whole point of the piece.

So depth wins. Down here the claims have run out, and which manufacturer
nominally holds the paperwork stops being the thing worth knowing about a
system -- which is also why `roll_module` opens the unbranded pool for it,
the same treatment fauna space already gets.
```

## Arm pull

Above `static var arm_pull := 0.9`:

```text
HOW HARD SYSTEMS ARE DRAWN ONTO THE ARMS, as the two numbers `galaxy_pos`
uses: the share of the angle to the nearest arm a system moves by, and the
most it may move, in neighbour widths. Read only under `Placement.PULL`,
which is no longer the default (see `placement` below). The game never
assigns these, so the defaults ARE the values PULL ships with; `-- sheet=GalaxyDump pulls` sets them to
preview other strengths and measure what they do to flyability.

0.9 and 3.0, "stronger" (Jon, 2026-10-03: "lots of systems on arms... very
little in the dark areas between them"; he picked it over today's 0.75 / 2.0
and a strongest 1.0 / 4.5). Measured over 120 pinned seeds: no galaxy without
a route to its core, 5.53 jumps to it against 4.95, the Grand-Design's widest
gap on ring 8 105 degrees against 76. Strongest stranded 6 of 120 and would
need generation to guarantee a route first. Saves keep their positions, so
only new runs are laid out this way.
```

## Placement modes

Above `enum Placement { PULL, SPREAD }`:

```text
HOW A RING'S SYSTEMS ARE SET ROUND IT.

PULL is `galaxy_pos`: an even ring, each system then dragged toward the
nearest arm by up to `arm_pull_cap` neighbour widths. SPREAD is
`spread_positions`: the ring's systems laid out by how bright the galaxy is
round that ring, then pushed apart wherever two sit too close.

SPREAD, because PULL piles them up (Jon, 2026-10-04: "WAYYYY TOO MANY systems
in one spot, and then nothing anywhere"). A pull of three neighbour widths
does not move one system onto an arm, it moves a whole run of a ring onto the
same arm crossing: every system within three steps lands within a step of the
ridge, four to eight deep, and the stretch of arm either side of the crossing
is left with nothing. Even spacing along the ring was arithmetic under the old
cap of 0.6 and the pull broke it on purpose; SPREAD keeps "more on the arms"
and puts the evenness back along them.

Measured by `-- sheet=GalaxyDump spread`, every kind forced onto the same 120
pinned seeds, PULL then SPREAD. Nearest neighbour on the chart, 5th
percentile, in ring gaps: 0.10-0.16 on every spiral under PULL (half their
systems within 0.3 of another), 0.55-0.60 under SPREAD (none). Share of
systems on an arm against the share of the ring that is arm, Grand-Design:
83% on 35% under PULL, 73% on 35% under SPREAD -- the arms still hold three
systems in four. The widest hole inside an arm: 1.44 ring gaps to 1.22, and
on the Irregular, whose PULL piled everything onto three arms, 6.6 to 1.5.
Flyable everywhere either way (0 of 120 natural, 0 of 120 for each of the 17
kinds), and the dive to the core got shorter, 5.53 jumps to 4.87: the dark
between the arms is no longer emptied into the piles. Ellipticals change
only where the push-apart moved a crowded pair.

Both stay selectable. Saves keep their positions (`MapNode.gal`, saved whole),
so only new runs change and the save version does not move.
```

Above `static var arm_floor := 0.15`:

```text
SPREAD: the share of each ring's systems laid out as if the galaxy had no
arms. The rest follow the arms. A floor of zero would leave the dark between
the arms empty, which is a wall to a ship with a fixed jump radius. 0.15 and
0.05 draw nearly the same chart, because the arms fill to `spread_gap` first
and their surplus goes back to the ring either way; 0.25 put 71% of the
Grand-Design's systems on its arms against 76% (10 seeds).
```

Above `static func spread_positions(nodes: Array) -> PackedVector2Array:`:

```text
Every system's position under SPREAD, in the order of `nodes`, in units of the
disc radius (before `reach`, as `galaxy_pos`).

TWO STEPS. First each ring is laid out on its own: its radius and its count
are the ring's, as they always were (the rings decide danger, routing and
fuel), but the angles come from the galaxy's brightness round that ring -- the
k-th system sits where the brightness, added up from a starting angle, reaches
k of N. Where the arms cross the ring the systems come close together, in the
dark between they space out, and nowhere do two land on one spot, because the
k-th and (k+1)-th are always a slot of brightness apart. A galaxy without arms
has even brightness and comes out the even ring it always had.

Then the whole galaxy is pushed apart: any two systems closer on the chart
than `spread_gap` ring gaps, on one ring or on two, are moved round their
rings until they are not. That is what stops a narrow arm stacking a ring's
systems inside a glyph of each other, and what staggers neighbouring rings
where the tilt brings them close.

Hashed, never rolled, like `galaxy_pos`: it draws nothing from `Rng.world`,
so changing it moves no other roll in the run.
```

## Arm pull cap

Inside `galaxy_pos()`, above `if int(g.arms) > 0:`:

```text
Drawn toward the nearest arm so systems sit in the bright lanes -- and far
enough to ACTUALLY GATHER, which the old cap of 0.6 could not.

THE CAP IS COUNTED IN NEIGHBOUR WIDTHS. `astep` is the angle between
adjacent systems in the ring, so below 1.0 a system cannot overtake one and
the ring keeps even spacing BY ARITHMETIC, however bright the arm is. The
old value was not a weak setting, it was a disabled one: the starfield
gathered into lanes and the systems drifted evenly through them, so the
map's density said nothing about the galaxy drawn behind it. Everything
already agreed WHERE the arms are -- `shape_angle` is the one definition,
and the stars, the gas and the systems all read it -- they disagreed about
how much to believe it.

THE OLD CAP'S REASON HAS EXPIRED. It read "an uncapped pull sends adjacent
rows to opposite arms, which is how one-fuel jumps once crossed the whole
galaxy", which was about `links` built by ROW INDEX. Links are a suggestion
now, and the lateral pass was rebuilt in angular order.

Measured on a Grand-Design Spiral, widest void in ring 8 against an even
spacing of 15 degrees, with `-- maptest` asserting the core stays FLYABLE:

    0.6   34 deg,  2 of 24 gaps bunched   flyable 6.1 mean   ok
    2.0   76 deg, 10 of 24                        6.2        ok
    3.0  106 deg, 15 of 24                        7.4        ok
    4.0  136 deg, 21 of 24                        7.9        FAILS
    6.0  139 deg, 22 of 24                        9.9        ok

TWO THINGS THAT TABLE SAYS. It saturates: the real pull is `best * 0.75`,
so past about 4 nothing is being clipped and 5, 6 and uncapped draw the
same galaxy. And 4.0 FAILS the flyability gate -- one Grand-Design Spiral
in 120 ends up with no route to its core -- while 6.0, which draws a nearly
identical galaxy, passes. That pass is luck rather than safety, and the
honest fix is for generation to GUARANTEE a route the way MIN_DOORS
guarantees a ring has an exit. Until it does, staying well below 4 is not
a preference, it is the margin.

2.0 was chosen for how it LOOKS: it bought the lanes and almost no detour.
It is 3.0 now (`arm_pull_cap`, above), for the same reason, more so: the
arms should read as where the systems are.
```

## Arm brightness

Above `static func _arm_cdf(rn: float, base: float, rows: int) -> PackedFloat32Array:`:

```text
How bright the galaxy is round the ring at `rn`, added up from angle `base`
in `SPREAD_BINS` steps: element m is the share of the ring's systems that
belong before step m, so it runs 0 to 1.

THE ARMS AS THE CHART PAINTS THEM. The chart's arm stars sit off the ridge
(`shape_angle`) by an even spread of `(0.55 + 0.9 r) * spread / 2` either
side, a third of them 2.6 times wider, inside the bar 0.22 of that, and
`chaos` scatters them a further `2 * chaos`. Each is drawn here as a bell of
the same width, so the systems are thick where the stars are.
`arm_floor` of the ring is spread evenly on top.

AND NO STEP HOLDS MORE THAN FITS IN IT. A step round the ring is so long on
the chart (shorter at the ends of the ellipse, where the tilt foreshortens
it), and `rows` systems each wanting `spread_gap` ring gaps of it can only
put so many there. Brightness past that is handed to the rest of the ring in
proportion to what it already has, which carries a narrow arm's surplus out
along its own flanks first. That is what makes a crowded arm come out evenly
spaced rather than packed: without it the narrow arms asked the push-apart
below to open up whole runs of a ring, and forty passes did not finish.
```

## Jump distance

Above `static func hop_distance(a: MapNode, b: MapNode) -> float:`:

```text
How far apart two systems are, as the chart draws them, in disc radii.
How far apart two systems are, for pricing a jump.

MEASURED UN-SQUASHED. Ruled 2026-08-25 (D1). `galaxy_pos` foreshortens the
disc for drawing -- `sin(a) * squash` -- and this used to measure in that
same space, so a north-south jump cost 1.5x to 3.6x less than an east-west
one at the same apparent separation. Optimal routes hugged the minor axis,
invisibly, and nothing on screen said so.

Undoing the foreshortening restores the disc to the circle it actually is, so
a jump costs what it costs whichever way it points. THE COST OF THE RULING is
that the chart no longer promises "distance as drawn": on a strongly tilted
galaxy two systems that look equally far apart are not, because one pair is
further apart in the plane and only looks close from this angle.
```

## Pulsar seeding

Above `static func _seed_pulsars(nodes: Array) -> void:`:

```text
Put a neutron star at the heart of every shell that has a system in it.

Pulsars used to be rolled like any other node type, which put them wherever
the dice fell — including out in clean space, where nothing had ever
exploded. The object and its cause were unrelated.

Now the cloud comes first and the pulsar is derived from it: a supernova
remnant or a planetary nebula is a star's corpse, so if a system sits inside
one, THAT is the system with the corpse in it. The consequence is that
pulsars are properly scarce and unevenly spread — a galaxy can roll none,
and one that rolls three has three shells to show for them — and that the
ring you can see on the chart is the REASON the place is dangerous rather
than decoration sitting next to it.

Membership is NebulaField's own test at its own reach: the same one the
sector screen asks to decide whether you are standing in gas. Two answers to
"is this system inside that cloud" would agree exactly until one was edited.
```

Inside `_seed_pulsars()`, above `var reach: float = clampf(cl.radius * 2.2, 0.14, 0.20)`:

```text
How far a system may be dragged to become this shell's pulsar.

The test used to be "inside the cloud", which was the right question
when the pulsar stayed where it was. Now that it MOVES to the centre,
the only thing that matters is whether hauling it there wrecks the
layout — and a shell with no system quite inside it is a ring drawn
around nothing, which is worse than a system nudged half a cloud.

Floored, because a planetary is small enough that a radius-relative
reach alone would almost never catch anything.
```

Inside `_seed_pulsars()`, above `best.gal = cl.pos`:

```text
And it MOVES to the middle of the shell. Picking the nearest system
and leaving it where the layout happened to put it meant the neutron
star sat somewhere on the ring it had supposedly thrown off — usually
right in the wall of it. The shell is gas expanding away from a point,
and the point is the pulsar; anywhere else and the picture argues with
itself.

Safe to do here because gal is what everything downstream reads: _link
has not run yet, so the jump distances are measured from the new
position, and the chart draws from it too. The node keeps its layer,
so its depth and danger are untouched.
```

## Station thinning

Above `const STATION_KEEP := 0.5`:

```text
STATIONS ARE RARER AND SPACED (Jon, Nov 3, his pick S3: "make stations more
rare", "two stations next to each other should never happen"). `_pick_type`
still rolls 8 slots in 36 as STATION, and this pass then thins them, in the
order the station study flew them (tk-scratch/station-study, S3):
  1. HALF ARE KEPT (`STATION_KEEP`): round(0.5 x the count), the ones lowest
     in `Rng.derive(&"station_keep", index)` order. The rest are systems.
  2. NONE WITHIN A JUMP OF ANOTHER (`Run.JUMP_RADIUS`, 0.18): the kept ones
     are taken greedily in `Rng.derive(&"station_gap", index)` order, and
     one too close to a station already taken becomes a system. It moves to
     the nearest system in its ring or either neighbour that is clear of
     every station taken (the lower index on a tie), or is dropped if none is.
About 36 stations a galaxy, down from 73 (the study: 35.5 a galaxy over 200
galaxies from seed 777, against 73.0 before).

It makes NO `Rng.world` draw, so every roll in the world stream stays the
same: every other system is the one it was. It runs before the twins are
rolled, so a station turned back into a system may roll two suns like any
other. Its axes were rolled as any system's are (`_roll_axes` does not read
the type), so a moved station keeps the level and berths of the system it
lands on.

The radius is the bare drive's, a light hull's jump. A medium hull reaches
0.234 and a heavy 0.288 (`thrust_reach`), and 96% of stations still have
another within 0.288. Jon picked it knowing that a built ship that does not
plan its fuel ran dry between docks in 4.75% of the study's sim runs.

A save stores each node's type, so a map made before this keeps its stations.
```

## Type weights

Inside `_pick_type()`, above `var weights := [`:

```text
No PULSAR here. A neutron star is not scattered at random across the
galaxy: it is what a big star leaves when it goes, and the only places
that happened are the shells still hanging where it stood. They are placed
by _seed_pulsars, against the clouds, once positions exist.

The other weights are left exactly as they were, so removing pulsars from
the draw did not quietly change the mix of fights, stations, events and
wrecks along with it.
```

## Linking

Inside `_link()`, above `var doors := 0`:

```text
Coreward links go to whatever is actually nearest, not to whatever
shares a row index. Rings hold different numbers of systems and are
rotated and jittered against each other, so matching by index drew
routes that crossed other routes and skipped the neighbour in front.
NOT EVERY SYSTEM HAS A WAY INWARD. This used to connect unconditionally,
so the shortest path to the core was one hop per ring and nothing could
make it longer -- measured at exactly 14 in all 120 galaxies `--
maptest` rolls, with no variance at all.

Rolled from `Rng.world` so it is POSITIONAL: the galaxy is a property
of the seed, and four machines in a co-op session must agree about
which systems have doors. A roll off any other stream would give each
peer its own map.
```

Inside `_link()`, above `while doors < MIN_DOORS and doors < here.size():`:

```text
THE RING NEEDS DOORS. Each SYSTEM IN IT DOES NOT.

This used to guarantee that every forward system had an incoming link,
which orphaned nothing and also made thinning impossible: it restored
roughly one door per forward system, so doors per ring sat near 15
whether DOOR_SHARE was 0.55 or 0.15, and the forced path stayed at 14.

It is safe to relax because the lateral pass below builds a COMPLETE
CYCLE inside every ring -- every adjacent row pair, plus the closure
from last row to first -- so arriving anywhere in a ring means being
able to walk to everywhere in it. A ring with MIN_DOORS ways in is a
ring with every system reachable.

What it costs is that arriving no longer means arriving where you want
to be, which is the entire point of the phase.
```

Inside `_link()`, above `var ring: Array = here.duplicate()`:

```text
LATERAL LINKS GO TO ACTUAL NEIGHBOURS. This used to connect systems
whose ROW INDEX differed by one, plus a closure from the first row to
the last, on the assumption that row order tracks position around the
ring. It does not: a stranded ship probed here had lateral links of
length 1.60 and 1.09 on a disc of radius 0.92 -- straight across the
galaxy.

That was survivable only because every system also had a short forward
link, so `can_jump_to` filtered the long ones out and nobody noticed.
With sparse doors a system can have nothing BUT those links, and then
it strands on a full tank. Two nearest neighbours each still walks the
whole ring, which is what the row version was reaching for.
BY ANGLE AROUND THE RING, which is the only construction that closes.

Two earlier versions did not. Connecting by ROW INDEX assumed row order
tracks position, and it does not -- a stranded ship probed here had
lateral links of length 1.60 on a disc of radius 0.92, straight across
the galaxy. Connecting each system to its two NEAREST neighbours makes
short links but not necessarily one cycle: it can settle into separate
clusters, and `-- maptest` found 6 galaxies in 120 where the core was
unreachable because of it.

Sorting by angle and joining consecutive systems gives exactly one
cycle, every link short, every system reachable from every other. The
angle is taken from the drawn position, and the foreshortening does not
matter: scaling y by a positive constant preserves the ORDER of points
around a circle even though it changes the angles themselves.
```
