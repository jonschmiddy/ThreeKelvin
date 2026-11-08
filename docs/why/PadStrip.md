The reasoning behind `tkg/scripts/ui/PadStrip.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Dock strip

Above `const CELL := HoldGrid.CELL`:

```text
The dock. What came off the old ship with nowhere in the new hold to go.

A SEPARATE CONTROL FROM `HoldGrid` BECAUSE IT IS NOT A GRID. The hold is a
packing problem -- a part sits at a cell, occupies its footprint, and the
whole widget exists to let you arrange it. Nothing on the pad has a position
and nothing here can be arranged: it is a queue of objects waiting for a
cell, drawn in the order they came off. Giving it `hold_at` semantics would
have meant inventing a second grid nobody flies.

It reads `Run.pad` and writes nothing. Picking something up is a Godot drag
with `origin` set to `&"pad"`, which `ShipScreen._on_hold_drop` reads to tell
an arrival from the dock apart from a move inside the hold -- the same way
`&"hull"` and `&"bag"` are already told apart.

IT IS ONLY ON SCREEN WHEN IT HAS SOMETHING ON IT. A permanent empty strip
under the hold would be a widget that means nothing on all but one screen of
one visit per run; `ShipScreen` hides it when `Run.pad` is empty, which is
almost always.
```

## Strip width

Above `var cols: int = 5`:

```text
How wide the strip is allowed to get before it wraps, in CELLS.

Set by the caller to the hold's own width, so the dock and the hold are the
same rectangle and the eye reads them as two halves of one problem. It is a
variable and not `Run.hold_grid().x` because the hold whose width matters is
the one drawn NEXT to this, and a widget that goes looking for global state
to size itself against is a widget that cannot be put anywhere else.
```

## Dock lattice

Above `func _draw() -> void:`:

```text
The empty cells behind the plates, in the LEAVE red rather than the hold's
own grey.

The hold's lattice says "this is where things go". This one says "these are
not stowed", which is a different statement and has to look like one -- the
strip sits directly under the grid, and two identical lattices stacked would
read as one hold with seven rows.
```
