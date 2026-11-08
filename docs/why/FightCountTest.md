The reasoning behind `tkg/scripts/sim/FightCountTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## No reinforcements

Above `var _fails := 0`:

```text
NOTHING JOINS A FIGHT, headless:
  godot --headless --path . -- sheet=FightCountTest [seeds=N]
Jon, Oct 13: "No reinforcements anywhere." A fight is the ships it was
planned with and only ever loses them. For every kind of enemy, alone and
(for the five that fly in packs) in a pack of two, over N seeded fights at a
lawless system of danger 5 or more (where the old wave was likeliest: 25% on
turn 3), the fight is played turn after turn -- your hull topped up so it
does not end early -- to turn 7 or its end, and the enemy count read after
every turn: it may never rise. The Custodian and the Hellbender are checked
to stand alone the whole way.

Calls only what a fight has always had (`Router.start_combat`, `end_turn`),
so it runs on a build that still had the wave -- and failed there.
```
