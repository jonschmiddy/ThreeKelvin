The reasoning behind `tkg/scripts/sim/ContractTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Contract loop

Above `func run() -> void:`:

```text
The whole contract loop, flown headless:
  godot --headless --path . -- contracttest

Signing, reaching, killing, docking hot, being paid, and the one thing that
can go quietly and expensively wrong — standing feeding back into `Market` and
reopening the buy-and-melt hole that file exists to close.

That last check is the reason this test is not optional. `-- market` proves
the invariant at standing zero, which is the only standing it has ever been
able to reach; every price in the game is fine until a player delivers four
contracts to one manufacturer.
```

## Every station posts

Above `func _every_station_posts() -> void:`:

```text
EVERY STATION POSTS WORK (Jon, Nov 3: all five decks at every station, the
HIRING BOARD among them). A station with no berth posts for its dock desk
(`Contracts.dock_desk`), every offer has a manufacturer and a price, and a desk
job is handed in at the desk that posted it. A bare board is legal only
where no ordinary system lies within reach and both offers wanted one, which
is rare: at most one station in a hundred.
```

## Salvage hush rule

Above `func _salvage_hush() -> void:`:

```text
The salvage rail's dismissal rule, which is pure logic on `Run` and has been
wrong twice.

It lives in this file rather than its own because this is the gate's test of
RunState transitions and a second Godot boot to assert four booleans is not
worth twenty seconds on every commit. If a third RunState rule needs covering,
split them out then.

First version put the flag on `SectorScreen`, which is REBUILT ON EVERY JUMP,
so stowing was forgotten the moment you left. Second version moved it to `Run`
and asked whether the state MATCHED the dismissal — so walking away from a bag
changed the state and re-opened the rail. The rule is "is anything new".
```

## Work at the named place

Above `const JOB_SEEDS := [11, 23, 47, 101, 233, 512, 777, 1009, 2048, 4099, 31337, 65521]`:

```text
THE WORK IS WHERE THE NOTE SAYS IT IS, flown end to end on many galaxies.

Jon, Oct 22: "Quests don't show up in the sectors they say they are." Three
things were wrong and the checks above could see none of them, because they
called `reach_contract_target(mine.at)` on the index and never read the note:

- THE NAME MEANT TWO PLACES. `MapGen.star_name` hashed the index and gave
  38% of systems a name another system also had, so a note naming "OMEGA
  THORN REACH" sent the reader to whichever one they found;
- THE LAYER WAS ONE SHORT. The note printed `layer` from zero; the chart and
  the sector count from one;
- NOTHING WAS THERE. No contract put anything on the named system's map: a
  fetch closed itself on arrival with one log line (a quarter of them at a
  station), and a hunt waited for a fight that was gone if you had won it
  before you signed.

So for every kind, on every seed: sign at a station, read the note, find the
one system it names, fly there hop by hop through `Run.jump_to` and the
arrival door (`Router.settle_arrival`), see the work on that system's map,
do it, fly to a yard and DELIVER. A third of the targets are emptied before
signing and a third after (a cleared system refuses every event), and every
other hunt is fled and found again on the next arrival.
```
