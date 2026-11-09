The reasoning behind `tkg/scripts/systems/Unlocks.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Meta progression

Above `const CHAIN: Array[StringName] = [`:

```text
Which manufacturers you have earned the right to fly.

META-PROGRESSION, AND IT REVERSES A RULING. `CLAUDE.md` said "the flight
record is a record, not meta-progression — nothing in RunHistory feeds back
into a run", on the grounds that identity is assembled mid-run and a history
that granted a starting bonus would be the first crack in that. This is that
crack, opened deliberately.

What makes it survivable: an unlock grants no POWER. Every manufacturer is balanced
against every other, so finishing the chain widens the choice at run start and
changes nothing about how hard a run is. A locked player is not a weaker
player, they are a player with fewer doors. That is the only shape of
meta-progression this game can take without repealing the greed clock.

DERIVED, NEVER STORED. There is no unlock file to desync, migrate or cheat —
the answer is a fold over the flight record. The cost is that runs recorded
before `chassis_manufacturer` existed cannot say who flew them, so they unlock
nothing; a save wiped is progress wiped, which is the same deal the record
already offered.
```

## Old key

Inside `won_with()`, above `var m := StringName(str(e.get("chassis_manufacturer",`:

```text
THE OLD KEY IS STILL HONOURED, and here that is the fix rather than a
courtesy. The vocabulary pass renamed this field to
`chassis_manufacturer`; every record already on disk says
`chassis_maker`, so reading only the new name reports an empty
manufacturer for every run ever flown and silently re-locks the lot.

A VERSION BUMP WOULD BE WORSE. RunHistory discards the whole file on a
mismatch, so raising its number would delete the flight record and take
every unlock with it -- destroying exactly what this read exists to
recover. The file still parses at version 1; two field names moved
inside it, and the record is append-only and never rewritten on load.
A run flown in July is meant to keep counting.
```

## Blank manufacturer

Inside `won_with()`, above `if m == &"":`:

```text
A WIN WITH NO MANUFACTURER IS STILL A WIN (Geno, Oct 23). Before
`launched_as`, the record took the manufacturer of the hull flown at
the end, and a run that swapped onto an unbranded derelict frame
recorded "". It launched as someone the chain had opened, so it
counts for the first opened manufacturer not yet won with: on a
fresh profile, Korvan, which is the only possible launch.
```

## New run world

Above `static func open_now() -> Array[StringName]:`:

```text
Every manufacturer this profile has unlocked, in chain order. Korvan at least.

WHAT A NEW RUN'S WORLD MAY HOLD (Jon, Oct 20: "Solari things should NOT show
up in the game until Solari is unlocked (win the game once)"). A locked
manufacturer's parts and hulls drop nowhere, sell nowhere and come off no
derelict: `LootGen.can_appear` reads this, as `Run.unlocked_manufacturers`,
with `DB.ACTIVE_MANUFACTURERS` on top. The record is read ONCE, at run
start (`for_new_run`), and the run keeps the answer and its save carries it,
so a win recorded mid-run, or a CONTINUE on a profile that has moved on
since, cannot change what a run already under way can find.

One fold over the record rather than `unlocked()` seven times, which would
read the file seven times.
```

## Party unlocks

Above `static func for_new_run() -> Array[StringName]:`:

```text
What a run starting now keeps as its `Run.unlocked_manufacturers`.

IN A PARTY, THE HOST'S. The galaxy is one galaxy: a wreck holds what a wreck
holds and a shelf is one shelf on every machine (`Rng.derive`), so the pool
those positional rolls draw from has to be one pool too, or two ships at one
derelict would open two different hulls. The host's profile decides it and
sends it with the seed (`NetSession._begin_dive`, PROTOCOL 10). What each
player may FLY is still their own record, read by the chassis select.
```

## Lock line

Above `static func lock_line(manufacturer: StringName) -> String:`:

```text
What the chassis select prints for a locked manufacturer.

The prerequisite is NAMED only if you have already unlocked it. Otherwise it
is ???, so the chain reveals itself one rung at a time rather than laying the
whole ladder out on the first run — which would make six locked rows into a
checklist instead of a horizon.
```
