The reasoning behind `tkg/scripts/autoload/Rng.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Rng streams

Above `var master: int = 0`:

```text
Every roll that decides something, and where its seed comes from.

Before this, 175 call sites reached for the global `randi()`/`randf()`, which
is one generator shared by the galaxy, the loot, the enemies, the events and
the star field. That has three costs, and only the first one is about co-op:

1. **Four machines cannot share a galaxy.** A seed is only worth sending if
   the receiver draws the same numbers from it in the same order.
2. **A bug cannot be handed to anyone.** "It stranded me on jump 60" is not
   reproducible when the run cannot be replayed. With a master seed it is one
   number: `godot --path . -- seed 12345`.
3. **The balance sim cannot replay a failure.** It reports that 40% of runs
   strand. It could not, until now, show you one of them twice.

## Streams, and why there is more than one

One generator for everything means every draw moves every other system. Roll
one extra affix on a module and the next galaxy is different, because the
galaxy is downstream of the same cursor. That makes tuning impossible: you
change a loot weight, the whole world changes, and the sim reports a number
you cannot attribute to anything.

So each concern gets its own generator, each seeded from the master by a
different constant. Combat can draw ten thousand times without moving the
map by one system. This is the property that makes seeded runs useful rather
than merely deterministic.

## Streams versus positions

A stream is a cursor, so it only agrees across machines when everybody draws
from it in the same order. That holds for the world: it is generated once, at
run start, before anybody has done anything.

It does NOT hold for anything a player triggers. Four ships dock at four
stations in whatever order they choose, and a shared cursor would hand them
each other's shelves. So anything a player can reach out of order is seeded
from WHERE it is rather than from WHEN it was asked for — see derive(). The
codebase already had this instinct: `StarchartScreen`, `NebulaField` and
`MapGen.star_name()` all salt `Run.galaxy_seed` with a position. derive() is
that pattern, named and given a mixer that is better than `* 2654435761`.

## What is deliberately NOT here

Cosmetic rolls. Audio pitch variation, damage-number jitter, the launcher's
background galaxy. They decide nothing, they must not be identical on four
machines, and routing them through a stream would only let a particle effect
move the loot table. They keep the global generator, and that is correct.
```

## Seat

Above `var seat: int = 0`:

```text
WHICH SHIP IN THE PARTY THIS MACHINE IS. Zero when flying alone.

A shared seed gives four machines an identical galaxy, which is exactly what
is wanted for the WORLD and exactly wrong for anything paid to a PLAYER. The
streams below are cursors, not derivations: four machines that have made the
same number of draws are at the same place in them, so two ships that kill
the same frigate on the same turn are handed the same two modules — and a
party's loot is duplicated rather than distributed. Worse, the moment the
cursors drift apart the duplication stops for no reason anybody can see,
which makes it look like a network bug instead of a seeding one.

So the streams that decide what happens TO you are salted by your seat, and
`world` is not, because the galaxy has to agree. See reseed().

Zero is a real value and it is deliberately a NO-OP rather than a salt of
zero: a solo run must replay bit-for-bit from `-- seed N`, and every seed
anybody has ever written in a bug report was rolled without this.
```

## Reseed

Above `func reseed(seed_value: int, seat_index: int = 0) -> void:`:

```text
Start a run's rolls. Call once, before anything is generated.

`seat_index` is which ship in the party this machine is flying — see `seat`.
The galaxy is NOT salted with it: `world` builds the map, the regions and the
names, and four players who disagree about those are not in the same game.
Everything else here decides something that happens to one player, so it is
salted, and the whole party is not handed the same drop off the same kill.
```

## Derive

Above `func derive(tag: StringName, index: int) -> RandomNumberGenerator:`:

```text
A generator for a thing that has a place rather than a turn.

Use this wherever a player can reach the same content in a different order
than another player would: station shelves, a derelict's contents, whatever
is sitting at node 46. The result depends only on the master seed and the
salt, so all four ships find the same thing there, and finding it does not
move anything else.

`tag` is folded in so that two different things at the same node — the shop
and the hull on the rack — do not draw the same numbers.
```
