The reasoning behind `tkg/scripts/systems/MaterialTable.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Material catalogue

Above `const SOURCES` (it was above `const NAMED := &"named"`, gone in draft 2):

```text
Everything a system can hand you that is not a module.

DRAFT 1, 68 items, authored 2026-08-27 (two artifacts added 2026-09-04). `docs/briefs/MATERIALS_NOTE.md` is
the contract
this is built to and is worth reading before editing: materials are becoming a
second ITEM CLASS in the existing spatial hold -- tiers, shaped cells, sold at
stations -- not a new storage system and not a currency. `RunState` still says
CREDITS ARE THE ONLY CURRENCY; these sell, they never price.

WHAT IS REAL TONIGHT AND WHAT IS NOT. The catalogue is real: ids, tiers,
shapes, values and text all ship. The ITEM is not -- there is no instance, no
hold cell, no sale screen. `grant()` therefore rolls a real row and pays its
`value` in credits, which is the shim `MATERIALS_NOTE` specifies in as many
words: one function body to swap when the hold learns about items.

`cells` is carried unused for exactly that reason. It is the shape the item
will occupy, it was authored with the rest of the row, and deriving it later
from a name would be guessing at what somebody already decided.

THE ZERO-MIGRATION RULE. `exotic` and `relic` are live ids in the material
ledger today and appear here with their values and text unchanged, so recipes,
combat drops and saved runs keep working. Every other row is additive.

`drops` is a LOOT-TABLE KEY and never a fiction: which table a row rolls from.
Five of them roll; `named` is the sixth and nothing asks for it -- see `NAMED`.
Precursor pieces sit in `wreck` because the lore says fragments come off deep
wrecks and nowhere else.

    tier    artifact 7 · common 16 · contraband 8 · epic 9 · exotic 10 · legendary 5 · rare 13
    table   event 20 · fauna 8 · fight 7 · mining 2 · named 7 · wreck 24
    cells   1x1 42 · 2x1 14 · 2x2 6 · 3x1 4 · 4x1 2

WHAT LEAVING COSTS THE TABLES, because it is a real thinning at the top and
not only tidiness: `event` loses its only ARTIFACT and `wreck` both of its
EXOTICS. Nothing can roll empty -- every table keeps a grade open at every
depth, and its commons stand in when nothing else is (see `roll`) -- but a
deep-galaxy event can no longer pay out a hundred and ninety credits in one
row. If it should, the answer is a generic artifact authored for the table,
not a story item borrowed back into it.

MINING IS THE THIN TABLE and is known to be -- the mining-flavoured options
are where its rolls come from, and the next materials batch should feed it.
```

DRAFT 2 (Nov 19, the list Jon approved on Nov 18: "All are good. Just some notes"). The
draft 1 text above is history (`const NAMED` is now a `named = true` field on the row).
Draft 2 gives each of six sources (wreck, mining, event, fight, fauna, cosmic) its own
list in one shape: 6 common, 5 uncommon, 4 rare, 2 epic, 1 legendary, 1 contraband, and at
the top 1 artifact (wreck, mining, event, fight) or 1 exotic (fauna, cosmic). That is 120
rolled rows, plus the 7 named ones, 127 in all. Values sit in per-tier bands (common 7-14,
uncommon 15-25, rare 26-44, epic 72-110, legendary 180-260, exotic 41-66, artifact 90-240,
contraband 64-130).

The list itself is `tkg/tools/fixtures/materials_draft2.json` (from the review page's
`tk-scratch/science/minigames/phone/src/materials.json`), and `ROWS` was generated from it,
so `MaterialTest` holds the two together: every row's name, tier, cells, value, source and
text, the per-source matrix, and every cut id resolving. A later edit to a row edits the
fixture in the same commit.

The table moved out of `all()` into a `const` because a 127-row function is a 260-line
function; the rows are data, and `code_check`'s length rule is about code.

What changed in place, with the reason the list gave: RELIC is PRECURSOR RELIC and Exotic
is EXOTIC TISSUE (both live ids, unchanged). Five fauna exotics moved along the ladder
(FLANK HORN and GRAVE SPORES to rare, SINGER'S OIL and NERVE SILK to epic, HEART FLUID to
legendary at 2x1). Wreck's five artifacts became one each: SINGING TINE to mining, CAGED
SPHERE to event, CLOSED-BAY KEY to fight, WRONG MASS down to a wreck epic, RELIC kept. The
encounters pay their story pieces by `material_id`, and none of those ids moved.

No sea or water words for a space creature (Jon, Nov 18, on SHOAL SHELLS, EGG CASES and
SHOAL GLUE: "Shoal? Water? in space?"); in the game a shoal is a dust cloud.

Nov 19, the same rule run over the rest (Jon's picks off a page of three options each):
BLOOD SALT is BLOOD CRYSTALS, SIEVE PLATES FEEDING COMBS (they read as baleen), EAR STONES
BALANCE STONES (a fish's), RENDERED FAT DEEP FAT (whaling), SINGER'S OIL SONG GLAND (whale
oil), CALYX AGAR CALYX GROWTH GEL (agar is seaweed), CHARGE WOOL CHARGE STRAND, NERVE SILK
NERVE CORD, CORONA AMBER CORONA SLAG (and the corona encounter's "amber" with it), and MOON
DUST is no longer "sold as ballast". Ids unchanged, so saves read the new names.

## Sources

Above `const SOURCES`:

```text
A source is two things at once: the table `roll` draws from, and the word the tooltip
says (Jon, Nov 18: the material tooltip lists NAME / TIER / SOURCE, one per line, plus
its one-line text; "just have it in the text", no stamps or tapes). So every row carries
`source`, the named rows too, though nothing rolls them (`named = true`): their source is
where the encounter that hands them over happens.

COSMIC was SKY until Nov 18 (Jon: "SKY is a weird name, we are in space"). It covers
stars, nebulae and gas giants. Two encounter outcomes at a star moved from mining to it,
because their own lines are cosmic: scooping a red star's dust cloud, and riding a
comet's tail.

FIGHT is paid by a beaten ship's wreck (Jon, Nov 19: "Yeah, fights can win materials"):
`Combat.WRECK_FIGHT_MATERIALS`, `docs/why/Combat.md#fight-materials`. Nothing paid it
before draft 2's first commit either.
```

## Retired ids

Above `const RETIRED`:

```text
A save stores a material by id and rebuilds the rest from the table, and a row that is
gone loads as nothing (`SaveGame._item_from`). Draft 2 cut nine rows; one of them
(SWEEP MIRRORS) is in a real save, Jon's 0.4.1 fixture. Rather than lose a carried item,
a cut id answers with the row that took its source and tier, which is never bigger, so a
saved cell still fits (and a load repacks anything that does not).

The save's shape did not change -- still `{kind, id, hold_at, turned}` -- so
`SaveGame.VERSION` stays where it was. `by_id` is the one door, so a found frame's strip
pay (`found_scrap.material`) and a market price read through it too.
```

## Picking a grade

Above `static func pick(`:

```text
`roll` draws every open row alike, so the grade follows from the list's shape and the
danger. A science mini game decides the grade first, from its score and the sector, then
needs a row of that grade from the site's source. `pick` is that seam: the exact grade if
the source has one, else the nearest grade under it (an artifact asked of fauna or cosmic
pays its exotic). Contraband is never walked into, because a better score must not hand
you the thing the scanners look for.
```

## Named pool

Above the named rows at the end of `ROWS` (it was above `const NAMED := &"named"`, gone in draft 2):

```text
THE POOL THAT NOTHING ROLLS. A material written FOR one encounter is handed
over by name -- `{material_id = &"counting_core"}` -- and has no business in a
generic table: a delivery drone paid out COUNTING CORE, whose own flavour text
is about a relay counting down on an approach three encounters away, because
it was sitting in `event` alongside the ration bricks.

`roll` filters on `drops`, so parking them under a table nobody asks for is
the whole mechanism. They are still reachable, and only the way they were
written to be reached.
```

## Tier gates

Above `const TIER_MIN: Dictionary = {`:

```text
The lowest TIER (`MapGen.tier`, 1-5) each grade may roll at.

THE SAME GATES `LootGen` USES FOR MODULES, deliberately and by reference:
rarity is a property of where you are standing, so a rim system cannot hand
out the good stuff and the deep galaxy is worth the trip. Artifact opens with
Legendary, the top of the manufactured ladder.

THEY WERE DANGER, AND THAT WAS THE BUG. Authored as 3 / 4 / 4 against RAW
danger (742bb953, Aug 27), nine days after danger widened to 1-10 and
`roll_module` began reading it through `tier()` (6226d1d0, Aug 18). Same
numbers, different scale: Epic materials opened at danger 3 and Legendary
and Artifact at 4, against Epic and Legendary modules at 5 and 7.

Two exceptions, both from `MATERIALS_NOTE`. CONTRABAND is ungated because its
gate IS the risk -- security scans care what you are carrying, so a rim run
with contraband aboard is already paying for it. EXOTIC is ungated because it
is live today and gating it would be a migration.
```

## Grant

Above `static func grant(row: Dictionary) -> String:`:

```text
Hand one over, and say what it was.

THE SHIM IS GONE, and this is the body it was always going to become. It paid
the row's `value` in credits because the hold could not carry an object; the
hold can, so this makes the object and puts it in the system beside you --
`RunState.add_material` -- and a station is where it turns back into money.

The note promised no option, no screen and no policy would have to be touched
when this changed. That held: the payload still says `{material = &"wreck"}`.
```

## Pictured materials

Inside `ROWS`, above SINGING TINE (it was inside `all()`):

```text
THE FIRST TWO MATERIALS WITH A PICTURE, and the first artifacts that are
not 1x1. Both were drawn as module art and were too good to spend on a
plate you bolt on and stop looking at -- a thing you CARRY and decide
whether to keep four cells clear for is the better job for them.

2x2 at artifact value is the whole point: four cells is a quarter of a
small hold, so carrying one out is a decision rather than a pickup.
```

## Deep wrecks

Above `const WRECK_SHARES`:

```text
Draft 2 gave every source the same shape (6 common, 5 uncommon, 4 rare, 2 epic, 1
legendary, 1 top, 1 contraband), and `roll` drew every open row alike. Deep, that cut what
a WRECK roll was worth: at tier 4 and 5 the old wreck table held five artifacts and paid
about 110 a roll; draft 2's paid 61, mostly uncommons and rares. Jon, Nov 19: "Bump it I
think. but they can also get artifacts, too."

So the wreck source, and only it, has shares by depth (`WRECK_SHARES`): a grade's rows
count that many times in the roll, 0 closes the grade, anything unlisted is 1. And from
the Legendary tier (`WRECK_PRECURSOR_TIER`) a wreck also turns up the precursor pieces the
list put in other sources' top slots (SINGING TINE, CAGED SPHERE, CLOSED-BAY KEY), beside
its own PRECURSOR RELIC and WRONG MASS: the list's own notes say precursor pieces come off
deep wrecks. Such a piece still says its own source on the tooltip.

Expected value of a wreck roll and its odds, from the list (tier: before -> after):
  tier 3   44 -> 52    epic 17% -> 29%
  tier 4   61 -> 103   uncommon 36% -> 0, rare 29 -> 42, epic 14 -> 21, legendary 7 -> 11,
                       artifact 7 -> 21 (relic, tine, sphere, key), contraband 7 -> 5
  tier 5   61 -> 122   rare 30, epic 22, legendary 15, artifact 30, contraband 4
Tiers 1-2 are unchanged, draw for draw. Mining, event, fight, fauna and cosmic stay at
every row alike (63, 65, 64, 55, 60 deep): Jon's call was about wrecks.

Measured against two other tables: closing uncommons at tier 4 with epic and up doubled
paid 103 at both deep tiers, flat rather than rising; doubling every deep grade with
uncommons kept paid 87.
```
