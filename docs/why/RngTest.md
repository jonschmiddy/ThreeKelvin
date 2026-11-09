The reasoning behind `tkg/scripts/sim/RngTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Determinism checks

Above `const SEED_A: int = 12345`:

```text
Determinism: the same seed twice, and streams that do not move each other.

  godot --headless --path . -- rngtest

RUN THIS AFTER TOUCHING Rng OR ANY GENERATOR. Determinism fails silently by
nature. A run that is 99% reproducible looks exactly like one that is
reproducible — the map matches, the galaxy matches, and then one call site
that still reaches for the global `randf()` puts four players in four
different games at jump 40, an hour into an evening they had scheduled.

The four properties, in the order they matter:

1. **Same seed, same galaxy.** The one the co-op design needs. A seed is only
   worth sending if the receiver draws the same numbers from it.
2. **Different seeds, different galaxies.** The check that catches a seed
   which is not actually being read — a generator stuck on its default is
   perfectly deterministic and completely useless.
3. **Streams do not move each other.** Ten thousand combat rolls must not
   move the map by one system. Without this, tuning a loot weight changes the
   world, and the balance sim reports numbers nobody can attribute.
4. **Position beats order.** What is at a node is the same whoever reaches it
   and whenever. This is the property that survives four players doing four
   different things at once, and a stream cannot provide it.
```

## Fingerprints

Above `func world_print() -> String:`:

```text

Everything the world is, flattened to a string. Deliberately over-inclusive:
a field left out of this is a field that can drift between two machines with
the test still green, and the whole point is to catch the one call site
somebody forgot.
```

## Station pass

Inside `_independence()`, above `Rng.reseed(SEED_A)`:

```text
THE STATION PASS DRAWS NOTHING FROM THE WORLD STREAM (Jon, Nov 3, S3):
it halves and spaces the stations off `Rng.derive`, so every roll the
world stream makes after it is the one it made before the pass existed.
Run again on a map that has had it once, so it has work to do: stations
to halve and, after `_pick_type`'s count, some too close to move.
```

## The science board deal

Above `func _board() -> void:`:

```text
--- 8. the science board -------------------------------------------------

THE DEAL DRAWS NOTHING (science, pick 2B). A run's board comes off
`Rng.derive(&"board", seat)` alone, so dealing it moves no stream: a run with
science rolls the world, the loot, every event and every fight exactly as a
run without it, which is what makes `-- sim science=off` a control cell.
```
