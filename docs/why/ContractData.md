The reasoning behind `tkg/scripts/data/ContractData.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Contract rules

Above `enum Kind {`:

```text

THIS FILE IS PART OF THE SAVE FORMAT, and nothing said so out loud until it
broke. `to_wire`/`from_wire` read like a network pair and contracts never go
over the net -- SaveGame is the only caller. So renaming a key here changes
the shape of every save on disk, guarded by a number in another file.

The annotation above is read by .github/scripts/version_guard.py, which
fails when the keys below move and that number does not.

One piece of work a manufacturer has posted at a station.

`docs/lore.md` §6 specified these as "an offer to take delivery, not a quest —
no objectives, no waypoints". That line is AMENDED rather than broken, and the
amendment is worth stating because the reasoning behind the original still
holds: what §6 was protecting is the third pillar, *greed is the clock, deaths
are self-authored*. A contract that expires, or that pushes you deeper on
somebody else's schedule, replaces a death you chose with one that was imposed.

A waypoint does none of that so long as three things stay true, and they are
the design of this class rather than notes about it:

**Nothing expires.** There is no clock on a contract and there never will be.
It sits in your ledger until you deliver it or die holding it.
**Refusing is free and normal.** Most offers should be declined. An offer you
always take is a tax with extra steps.
**It names a place, it does not send you there.** The pay is set against the
trip, so a contract to somewhere you were not going is priced like one — and
going anyway because the money is good is a greedy decision, which is the
correct kind.
```

## Status line

Inside `status_line()`, above `var who := DB.short_name(DB.manufacturer_name(manufacturer))`:

```text
The WHAT comes from the kind and the WHERE from the state, so a heat
contract — which has no target node and never will — is never asked to
describe a place. It used to fall through to _where() and answer
"somewhere out there" on the board, which is a heat contract describing
itself as a fetch.
```
