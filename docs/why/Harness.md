The reasoning behind `tkg/scripts/sim/Harness.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Harness base

Above `var _fails: int = 0`:

```text
What every pass/fail harness in `scripts/sim/` counts and prints.

Four of them carried a byte-identical `_ok()` and a verdict line that differed
only in the name it printed. Harmless right up until the format changes, at
which point the merge gate's ERROR_PATTERNS have to match four spellings of
the same sentence.

NOT every harness extends this, deliberately. `HeadlessSim`, `MarketSim`,
`SaveTest`, `GlyphSheet` and `RepairSheet` report a MEASUREMENT rather than a
pass count — a win rate, a price sweep, a distribution — and folding those
into a failure counter would be imposing a shape on them rather than sharing
one they already had.
```

## Seed run

Above `func seed_run(n: int) -> int:`:

```text
THE NEXT RUN STARTS FROM SEED `n`: call it right before `Run.start_new_run`.

A `Rng.reseed(n)` there did nothing. `start_new_run` draws the run's own seed
first (`Rng.roll_master`: `Rng.forced`, or else the global generator) and
reseeds every stream from THAT, so each harness that reseeded drove a fresh
random galaxy, ship and hold every time it ran -- and a check that depended
on any of them came and went between gate runs (maptest, fittest and
subjecttest all did, Oct 11-12). This sets `Rng.forced`, which sticks.

`-- <harness> seed N` on the command line wins over `n`, so a failure's seed
(printed here and by `verdict`) replays it.
```

## Finding nodes

Above `func first(root: Node, matches: Callable) -> Node:`:

```text
The first node under `root` that `matches` accepts, depth-first, or null.

Godot's `find_child` matches on a NAME, and a harness driving a real screen
almost never knows the name — it knows the button reads "STOW", or that the
node it wants is an inner class the engine has no name for. Both of those are
a predicate, so this takes one. `ConvoyTest._find_slot` is the second copy of
this walk and is left alone until that file has some other reason to move.
```

## Totals over shards

Above `func total(key: String, what: String, expr: String, vars: Dictionary) -> bool:`:

```text
AN ASSERTION OVER EVERY CASE (a share, a count against a limit), which no
shard can judge on its own cases: unsplit it is `_ok(what, expr)`; split,
each shard prints its numbers and `ShardSum` adds them up across the shards'
logs and judges `expr` on the sums. `vars` are the expression's inputs:
lower-case names are added up, UPPER-case ones are constants every shard
must agree on. `key` names the assertion the same way in every shard.
```
