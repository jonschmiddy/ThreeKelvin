The reasoning behind `tkg/scripts/sim/SaveTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Round trip method

Above `var fails: int = 0`:

```text
Round-trip test for SaveGame and RunHistory.

  godot --headless --path . -- savetest

RUN THIS AFTER TOUCHING EITHER FILE. A save system fails silently by nature:
a field someone forgot to serialise does not crash, it just comes back as a
default, and the run continues around it looking almost right. The only way
to catch that is to compare a run against itself.

The method is deliberately blunt. Play a run forward into a messy state,
fingerprint every field that matters, save, SCRAMBLE the live state so
nothing can survive by accident, load, and fingerprint again. A field the
save does not carry shows up as a mismatch rather than as a value that
happened to already be right.

Floats are compared to nine decimals. JSON does not round-trip doubles
bit-exactly — see the note in SaveGame.save() — and nine decimals is three
orders of magnitude stricter than anything the game can observe while still
catching a genuinely wrong number.

Loaded by path rather than by class_name, so a test costs nothing in the
global class cache that every screen pays to look through.
```

## History file

Above `const HISTORY := "user://savetest_history.json"`:

```text
The flight record the history checks write and clear. `RunHistory.path`
points here while they run: clearing the real one deleted the player's whole
record, and every unlock read from it, on every gate run.
```

## Ambush fingerprint

Inside `fingerprint()`, above `n.ambush_pending, n.ambush_rolled])`:

```text
WHETHER A FIGHT IS OWED HERE, and whether the roll has happened at
all. Never covered before this: the old `ambush` array was not in
the fingerprint either, so the save could have dropped it silently
for as long as it existed. Losing `ambush_pending` hands back a
system that quietly forgets it was about to jump you; losing
`ambush_rolled` re-rolls it on the next redraw until something
bites, which is worse.
```

## Grade perks

Inside `fingerprint()`, above `hull = "%s|%d|%d|%d|%d|%d|%.9f|%d|%.9f|%d|%d|%d|%s|%s" % [`:

```text
THE GRADE'S PERKS ARE IN THE FINGERPRINT, and they have to be. The
loader does not call `at_tier`, so nothing regrants them on the way
back in — an S-tier ship that lost all three would come back with
every number here identical and three perks missing, and this test
would have said PASS. `perk_id` alone could not see it: that one is
the MANUFACTURER's and survives on the frame.
```

## Old hull

Inside `fingerprint()`, above `old_hull = "%s|%d|%d|%s" % [Run.old_hull.name, Run.old_hull.tier,`:

```text
THE FRAME THE PAD CAME OFF (VERSION 36). The move draws its left half,
and the parts still bolted to it, from this; a save without it came
back with those parts drawn nowhere (Jon, Oct 23). Fixtured below by
the `transfer_to_hull` that fills the pad.
```

## Pad fixture

Inside `run()`, above `for stranded in [&"plate", &"coolant"]:`:

```text
TWO THINGS ON THE DOCK. `pad` is populated by a hull swap that overflowed,
and no probe in this file buys a hull -- so without a fixture the round
trip would be checking that an empty array survives being written as an
empty array. Placed by hand rather than through `transfer_to_hull` for the
same reason the materials above are: a probe wants the STATE, not the
journey that usually produces it.
```

## Material fixtures

Inside `run()`, above `for seeded in [&"exotic", &"exotic", &"exotic", &"relic", &"relic"]:`:

```text
All three materials, not just the one that used to be a bare field. A
ledger keyed by StringName and reloaded from JSON's String keys is exactly
the kind of thing that comes back looking right and compares wrong.
ABOARD, because the probe is asking whether a save keeps what you are
CARRYING. `add_material` leaves them in the sector, which is the right
answer for a reward and the wrong one for a fixture.
```

## Hold arrangement

Inside `run()`, above `if not Run.cargo.is_empty():`:

```text
ARRANGE the hold, do not just fill it.

Everything above lands by first fit, and the loader re-packs anything that
comes back without a position by running that same first fit — so a save
that dropped every cell still reproduced the identical layout and this test
passed. Verified by deliberately breaking the writer: it did not fail.

Moving one part somewhere first fit would never have put it is what makes
the saved value load-bearing, which is what a player rearranging their hold
does every time they touch it.
```

## Version rules

Above `func run_version_test() -> void:`:

```text
A file from the version before this one is REFUSED, and a flight record
from before a rename is still READ. The two rules look contradictory and
are not, which is exactly why neither had a test.

Both were broken at once by the vocabulary pass: it renamed keys in three
serialisers and raised none of the numbers guarding them. Nothing failed.
A save stamped 10 was read with keys that were not in it and came back as a
galaxy with no berths and no contracts, and every past run stopped
unlocking its manufacturer because the record said `chassis_maker` and the
reader had moved on to `chassis_manufacturer`.

THE SAVE DISCARDS AND THE RECORD DOES NOT, because they are different
kinds of file. A suspend save is one run in progress; refusing it costs
that run and protects everything else. The flight record is append-only
and holds every run ever flown, so refusing it deletes the lot -- which is
why RunHistory keeps VERSION at 1 and reads the old key instead.
```

Inside `run_version_test()`, above `check("this build writes VERSION 40", 40, SaveGame.VERSION)`:

```text
THE LEAD SHIP'S JUMPS (VERSION 40, Jon, Nov 4): this build writes 40. The
Custodian grows on `Run.custodian_jumps()`, the lead ship's jumps in co-op,
so they are saved; a 39 save has none and grows on its own jumps, as a 39
build did. The load counts the count as seen, so CONTINUE replays no
arrival; a new run clears it.
```
