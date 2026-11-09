The reasoning behind `tkg/scripts/systems/MaterialTable.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Material catalogue

Above `const NAMED := &"named"`:

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

## Named pool

Above `const NAMED := &"named"`:

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

Inside `all()`, above `{id = &"singing_tine", name = "SINGING TINE", tier = &"artifact", cells = "2x2",`:

```text
THE FIRST TWO MATERIALS WITH A PICTURE, and the first artifacts that are
not 1x1. Both were drawn as module art and were too good to spend on a
plate you bolt on and stop looking at -- a thing you CARRY and decide
whether to keep four cells clear for is the better job for them.

2x2 at artifact value is the whole point: four cells is a quarter of a
small hold, so carrying one out is a decision rather than a pickup.
```
