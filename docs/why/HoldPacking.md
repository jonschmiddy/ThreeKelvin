The reasoning behind `tkg/scripts/systems/HoldPacking.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Cells taken

Above `static func taken(cargo: Array[HoldItem], m: HoldItem = null, leaving: HoldItem = null) -> Dictionary:`:

```text
Every occupied cell of the hold, once. `m` and `leaving` are not counted --
the thing being placed, and a thing about to vacate its cells.

Public because the drag paths need it too: probing candidate cells through
`can_place` rebuilt this map per cell, which put an O(cells x cargo) scan on
every drag-over frame for an answer one map gives in one pass.
```

## Repacking the hold

Above `static func repack(g: Vector2i, cargo: Array[HoldItem]) -> Array[HoldItem]:`:

```text
Re-seat everything, largest first, after the grid changes shape.

Called when the hull is swapped: a heavy's 4x10 hold becomes a light's 4x5 and
every part below the fifth row is now outside the grid. Largest first because
first-fit on a fresh grid strands big parts behind small ones — the one place
a rule other than "leave it where it was" is worth having, since the player
did not arrange this and cannot be surprised by it.
```
