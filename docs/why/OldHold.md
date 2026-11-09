The reasoning behind `tkg/scripts/ui/OldHold.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Old hold

Above `const CELL := HoldGrid.CELL`:

```text
The hold of the ship you are LEAVING, with whatever is still in it.

A SOURCE, NEVER A TARGET, and that is what keeps it cheap. `HoldGrid` is
coupled to `Run` all the way down -- `hold_grid`, `hold_taken`, `fits_at`,
`cargo` -- because it has to answer "does this fit here" on every frame of a
drag. None of that applies to a ship being abandoned: you drag things OUT of
this and never arrange anything in it, so it needs no fit test, no beam and
no drop handler. Generalising HoldGrid to cover both would have meant
threading a second hold through five methods of the one widget the whole
refit screen rests on, to buy a feature this side does not want.

It reads `Run.pad` for its contents and `Run.old_hull` for its shape.
```

## Strays

Inside `refresh()`, above `var taken := {}`:

```text
THE STRAYS SIT WHERE THEY SAT. `transfer_to_hull` preserves `hold_at` for
anything that does not make the crossing, so the grid you are looking at
is the hold you packed rather than a bin the leftovers were tipped into.

The exception is a thing with no cell of its own in this grid: a part that
came off a HARDPOINT with no old ship to draw it on, or a cell outside the
grid, or one something else already sits in. Each of those takes the first
gap that fits, and below the lattice when the lattice is full -- never at
a cell on top of something else, and never in one long row out past the
edge of the column, which is how a pad of fourteen used to draw.
```

Inside `refresh()`, above `var mod := m as ModuleData`:

```text
WHAT IS BOLTED ON IS NOT IN THE HOLD. A pad module remembers the
hardpoint it was fitted to, and the ship above this grid draws it
there -- so listing it here as well put every gun on screen twice,
once on the hull and once in a row of leftovers spilling out past the
edge of a hold it was never in. UNLESS THERE IS NO SHIP above it to
draw it (`Run.old_hull` null): then here is the only place it shows.
```

## Lattice ink

Above `func _draw() -> void:`:

```text
The lattice, in the ink the rest of the game uses for something being lost.

NOT the hold's own grey. This grid sits three inches from a live one and the
two say opposite things -- that is where your things go, this is where your
things are stranded -- so drawing them the same would read as one hold with
nine rows rather than as two ships.
```
