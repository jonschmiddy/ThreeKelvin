The reasoning behind `tkg/scripts/sim/MapTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Map gate

Above `const ROLLS := 120`:

```text
Is the galaxy actually traversable, and how short is the short way?
  godot --headless --path . -- maptest

A GATE, not a measurement, unlike `-- content` and `-- rarity`. Everything it
checks is a thing that makes a run UNWINNABLE rather than merely unbalanced,
and none of it is visible from inside a run — a player meeting a ring with no
way inward does not see a generation fault, they see a game that stopped.

IT EXISTS BECAUSE OF THE SPARSE-LINK WORK. `_link()` currently gives EVERY
system a coreward link, so "can you get in" was true by construction and
needed no checking. Thinning those links removes that guarantee, and
`GALAXY_SCALE.md` §3 flags the exact hazard: the reachability pass guarantees
every forward system is reachable FROM somewhere, not that every ring has an
exit. A ring with no doors is a run that cannot be finished.

It also answers the question the design briefs kept guessing at. §0 opens "a
run is eight jumps long" — that is the FORCED path, and this measures it
rather than deriving it from the layer count, because reachability is not
only about `links`: `RunState.reachable_from` also lets a hop through when
either end thinks the other is close, so thinning links may not thin the
shortest path by as much as the link count suggests.
```

## Known bad seeds

Above `const KNOWN_BAD: Array[int] = [65867625]`:

```text
SEEDS THAT ONCE BROKE A GALAXY, rolled every time on top of the 120, so the
gate cannot pass by not happening to roll them. The 120 are pinned too (from
90210): until Oct 11 this gate rolled 120 FRESH galaxies a run, because
`start_new_run` draws its own seed and the reseed before it was thrown away,
and a failure came and went between runs.
  65867625  a Magellanic Irregular whose start sat alone in the dark at the
            rim, 0.243 from its nearest system (`MapGen._ensure_flyable`)
```

## Flyable route

Inside `run()`, above `var flyable := _shortest_by_range(map, start, goal)`:

```text
AND THE SAME QUESTION ASKED OF THE RULE THE SHIP FLIES. The search
above walks `links`, which is the graph the CHART draws and which
nothing in the jump path consults. This one walks `reachable_from` --
a radius, fixed since JUMP_RADIUS landed, so a gap wider than it is a
wall that the link graph knows nothing about.

Fuel is deliberately not considered: running dry is a RunState problem
and a different kind of stranding. This asks whether the geometry
permits the route at all.
```

Above `func _shortest_by_range(map: Array, start: int, goal: int) -> int:`:

```text
Fewest hops to the core under the rule the ship actually flies.

`reachable_from`, not `links`. Breadth-first, and deliberately blind to fuel:
this asks whether the GEOMETRY permits a route, which is the thing a galaxy
can be generated wrong. Running dry is a different failure with a different
fix.

O(n) per node because `reachable_from` has no index behind it, so this is
about n^2 a galaxy. At ~350 systems and 120 rolls that is affordable, and it
only runs in the harness.
```

## Depth rule

Above `func _depth_rule(map: Array) -> void:`:

```text
THE TWO-RING RULE, asked of every pair in one galaxy (`RunState.too_deep`).
A jump goes at most two rings deeper; outward and along a ring it goes as far
as the drive reaches; the core from the last ring always, from the ring
before it when in reach, and never from further out. And a star the rule
refuses from inside the reach ring is the case the chart has to name
(`too_deep_only`, TOO DEEP), so it has to say so.
```

## Kind sweep

Above `const KIND_SEEDS := 15`:

```text
EVERY GALAXY KIND IS COMPLETABLE UNDER THE DEPTH RULE, for the slowest
ship (thrust adds nothing, so the base `JUMP_RADIUS`): `seeds` galaxies of
each `GalaxyGen` kind (15 each of 17 kinds, 255 galaxies), laid out the way
the run-length study laid them out (seeds 900001 + kind * 1000 + i). The
study found a few that one ring a jump could not finish;
`MapGen._ensure_flyable` walks by the rule (two rings since Oct 27) and
bridges the gap, and this is the sweep that says it did.
```

## Label drift

Above `func _labels() -> void:`:

```text
Every enum value still has a name, and the name still belongs to it.

THE BUG THIS EXISTS FOR IS SILENT AND ALREADY HAPPENED. `type_label` was a
hand-written array indexed by the enum value; the 8a-2 collapse renumbered
`NodeType` and left the array alone, so STATION read "FIGHT", CORE read
"STATION", PULSAR read "EVENT" and SYSTEM read "DERELICT" -- four of five node
types naming themselves wrong on the sector screen for a day.

Nothing errored. The array was still seven long and every lookup was in
bounds, which is the whole hazard: a parallel array does not break when it
stops corresponding, it answers a different question. A warning comment sat
directly above the enum and survived the edit it was warning about, because
comments do not run.

`type_label` reads `NodeType.keys()` now and cannot drift. The other three
CANNOT do that and should not: `region_name` deliberately maps FAUNA to
"Migration Route" and CORE to "Precursor Ruins", which are prose, not keys.

So what is checked is LENGTH. The first cut of this looked for BLANK labels
and would have passed the very bug it was written for: the array was too LONG,
so every lookup was in bounds and every label was a real word -- just the
wrong one. A count is the only thing that actually drifted.
```
