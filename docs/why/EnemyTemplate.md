The reasoning behind `tkg/scripts/data/EnemyTemplate.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Growth with the run

Above `@export var grow_after: int = -1`:

```text
GROWTH WITH THE RUN, by jumps flown (`Run.custodian_jumps()`: yours alone,
the lead ship's in co-op), for a set piece whose hull should follow how long
the ship took to get there. Off unless
`grow_after` is set. Hull only: the intents are not touched. Only the
Custodian grows (Jon, Nov 3, rule G3 with cap B; see its note in
`Database._seed_enemies`).

`grow_after`: the jumps that are free; -1 means it never grows.
`grow_rate`: the hull's multiple for each jump past them, compounding.
`grow_cap`: the most it can reach, as a multiple of `max_hull`, so the cap
stays "twice its strength" if the base ever moves.
```

## Hull cap rounding

Inside `hull_at()`, above `return roundi(minf(max_hull * grow_cap,`:

```text
Capped as a float, then rounded: rounding first turned a long run's
uncapped figure (past int64 near jump 994, or inf) into the most negative
int, which `mini` kept and `Combat._spawn` floored to a 1-hull boss.
```
