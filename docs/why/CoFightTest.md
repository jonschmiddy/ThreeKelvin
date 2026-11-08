The reasoning behind `tkg/scripts/sim/CoFightTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Test purpose

Above `const CODE_TAG := "[cofight] code "`:

```text
Two processes, one enemy. The end of the chain, flown rather than argued.

`-- nettest` proves `SharedFight` and `NetSession` in one process, and that
is as far as one process can go: `Run` is a singleton, so a single instance
holds exactly one ship. Everything in `Combat`'s shared path — attaching to
the party's enemy, adopting a push, taking a swing, waiting on the barrier —
therefore CANNOT execute in nettest, and without this it would first execute
in front of a person.

  godot --headless --path . -- cofight host
  godot --headless --path . -- cofight join CODE

or both at once, which is how it is actually run:

  tools/cofight.sh

What it proves: two machines open ONE fight at one system; the enemy is
scaled for two and both see the same hull; each ship's cards land on the
other's copy of it; the enemy does not swing until both have ended their
turn; it swings at exactly one of them; and when it dies BOTH ships are paid.

What it does not prove: any of it through a NAT. Nothing that runs on one
machine can.
```

## Race leg

Above `var _race: bool = false`:

```text
`-- cofight host race` / `-- cofight join CODE race`: THE SAME-SECOND RACE
(Nov 5), both orders, in two systems. One ship opens a fight; the other,
once it can see that fight, starts a different one at the same system
without looking (`Router.forced_race`), as a ship whose copy was still on
the wire would. Leg 1, host first: the host opens two hulls, the guest asks
for one. Leg 2, guest first: the guest opens one, the host asks for two, so
the answer path runs on the host too. Each leg is fought to the kill, and
the shell checks the pair from outside: the same ids, the same intent under
each hull, the same wrecks (`race1ids` ... `race2wreck`).
```

## Custodian

Inside `_fly()`, above `if _boss:`:

```text
ONE CUSTODIAN FOR THE GALAXY (PROTOCOL 16, Jon, Nov 4): the two ships at
different jumps, the guest ahead. Its presence says 17, the host folds it
and pushes it back, and both machines grow the boss and draw the badge on
the lead ship's 17 (the shell compares the `custodian` lines)
```

## Fight opening

Inside `_fly()`, above `var pool := DB.fight_pool(Run.node_at().danger, false)`:

```text
NO SYSTEM HOLDS A FIGHT ON ARRIVAL ANY MORE: its hostiles are an option
you choose, and waiting for one to open by itself waited forever. So
this opens the fight that option would, the same template on both
machines (picked by the node, not by either ship's stream), shared and
clearing the node as the old fight node did, which is what the bag and the
consumed-system checks below were written against.
```

## Shared window

Inside `_fly()`, above `var shared := await _until(func() -> bool: return cb.is_shared(), 15.0)`:

```text
Not immediately. `Router.start_combat` assigns `combat` and THEN asks the
party, so there is a real window — one round trip on a client, nothing on
the host — where the fight exists and is not yet shared. Checking inside it
is how this test failed the first time it ran, and the window is worth
knowing about: it is also a moment where a screen draws a fight with no
hand in it.
```

## Wreck bag

Above `func _bag(cb: Combat) -> void:`:

```text
One kill, one set of wrecks, and one hand on each part.

The third contested thing in the game, and the one the last playtest asked
for by name. Before the bag a shared kill paid each ship its own private
roll -- duplication solved and distribution never attempted: one frigate paid
the party twice. The bag became a WRECK per hull you killed (`Combat`,
`MapGen.Jetsam`), reached into with `Run.take_from_jetsam` / `take_item`;
what it guards did not change. It is checked from outside, because neither
process can see the other's hold.

Four claims, and they are not the same claim:
  the wrecks MATCH on both machines -- they belong to the system, so they are
    rolled positionally and every ship is looking at one pile (`wreck`);
  nothing was paid privately -- a hold with something already in it means a
    per-ship roll is still running somewhere;
  exactly ONE ship walks away with the part both reached for (`took`);
  and both machines agree WHO has it (`taker`), which is what the sector's
    "X took it" line and a later reach are built on.
```

## Shop leg

Above `func _shop() -> void:`:

```text
And then both ships dock at the same station and reach for the same part.

The shelf is the second contested thing in the game and the first that is a
LIST: a wreck is taken whole, a shelf is taken a part at a time. It is also
the one that looked correct in a playtest — the stock IS meant to be
identical on both machines, because it is one shop — so the bug was not in
the roll, it was that buying only emptied the local copy.
```

## Find a system

Above `func _find(t: MapGen.NodeType) -> int:`:

```text
The first system of a kind, skipping the one you start on.

One function rather than three. `_find_station`, `_find_fight` and
`_find_goal` were the same six lines with the type constant swapped, and
`ContractTest` — written the same day — had already generalised it. A third
copy was one type constant's worth of value.

`cleared` is honoured for a FIGHT because a spent contact is not a fight to
share; a station and the core do not go away. Migration-route fights are
skipped too, and that one was learned from a flaking run: a fauna kill pays
exotic and ZERO module drops by design, so there is no bag at the node and
the bag leg fails on a fight that behaved perfectly. The harness is here to
measure the shared kill's payout, which needs a kill that pays one.
```

## Bot scoring

Inside `_score()`, above `if c.vent > 0 and Run.heat > Run.heat_cap() * 0.7:`:

```text
NOT Policy.vent_cold, and deliberately not. `Policy` is the balance model
and its thresholds are a dial that gets swept -- see the sweep that set
them after the end-of-turn shed was deleted. This scorer only has to end a
fight, per the header above, and coupling it to a balance dial would mean
retuning the economy could change whether a CO-OP TEST passes.

0.7 still holds under the new heat rules for the reason it always did: it
is comfortably under the cap, and a vent card now sheds more than it
prints, so this bot cools better than it used to rather than worse.
```
