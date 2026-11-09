The reasoning behind `tkg/scripts/ui/HoldGrid.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Hold grid

Above `const CELL := 40`:

```text
The hold, as a grid you pack.

Not a GridContainer, and it cannot be one: a container gives every child a
cell, and half the catalogue is wider or taller than one. A part is placed at
`hold_at` and drawn across its own footprint, so the layout is arithmetic on
a fixed cell rather than something a container decides.

Everything here reads Run and writes nothing. Drops are reported upward and
the screen owns the state change — one place to read when a part ends up
somewhere it should not.
```

## Cell size

Above `const CELL := 40`:

```text
One cell.

30, up from 24 and 22 before that. The parts on the HULL now draw at the
hull's own magnification, which doubled them, and a hold plate has to hold
its own beside that — the two are meant to read as the same object and the
whole reason they share a silhouette is so you can recognise the gun you are
about to bolt on. ModuleIcon divides by 26 for its scale, so a 1x1 plate
went from 0.92 to 1.15 of the authored size for free.

FORTY, so the hull draws a cell at TWENTY.

A fitted part is sized at half the hold (MountPoints.part_rect), so this
number is really a decision about the ART: at 30 the hull cell was 15 and
every module footprint — 15x15 up to 62x15 — sat under PixelLab's floor of
1024px of area, so no module could be generated at the size it is drawn.
At 40 the hull cell is a round 20 and the boxes become 20x20, 40x20, 60x20,
80x20 and 40x40; the 3x1 and 4x1 clear the floor outright and can be
generated native, with no crop and no reduction.

It costs panel: 5 columns go from 154px to 200px. That is the trade, and it
was made knowingly — fidelity in the thing you look at, paid for in a
workbench that is a third larger.
```

## Cell gap

Above `const GAP := 0`:

```text
ZERO, and the lattice is now DRAWN rather than left as a hole.

It used to be background showing between cells, which was subtle and cost
nothing to maintain. It also made every cell 31 wide instead of 30, and a
part five cells long 154 instead of 155 — fine on its own, and not fine once
the hull's box is meant to be exactly half of it. A gap of one does not
halve. So the cells now abut and `_draw` strokes the boundaries, which reads
the same and divides cleanly.
```

## Mixed grid

Inside `refresh()`, above `var icon := ItemIcon.make(m, &"cargo")`:

```text
TWO KINDS IN ONE GRID. A module draws the part, because recognising
the gun you are about to bolt on is the whole point of it sharing a
silhouette with the thing on the hull. A material has no hull form to
echo, so it draws a crate. See `MaterialIcon`.
A chit should never be in here -- `stow` cashes it. If one is, it
is a bug, and a bug you can SEE beats an invisible occupied cell.
```

## Icon sizing

Inside `refresh()`, above `icon.custom_minimum_size = Vector2.ZERO`:

```text
SIZED AFTER add_child, AND the minimum cleared first. Both halves are
load-bearing and neither is obvious.

ModuleIcon.setup puts a 44x44 floor under itself, which is right for a
rack cell and is two hold cells wide. Assigning `size` before the node
entered the tree let the minimum-size pass on entry overwrite it, so a
1x1 fitting drew at 44 and hung a whole cell past the right edge of the
grid — visible only as plates overlapping, since the DATA underneath
was correctly in bounds the whole time. `-- holdtest` passes either way
and always would: this was never a packing bug.
```

## Draw extent

Inside `_draw()`, above `var extent := Vector2(_cols * (CELL + GAP) - GAP, _rows * (CELL + GAP) - GAP)`:

```text
THE CELLS' OWN EXTENT, NOT THE CONTROL'S.

The frame and the lattice were drawn to `size`, which is whatever the
container hands the grid -- and a container hands it more than its cells
whenever something above it in the same column is wider. The refit
screen's storage header, the cell count with the jettison hatch beside it,
is about 214 pixels against a five-wide hold's 200, so the frame and every
row line ran fourteen pixels past the last column. Drawn to the cells, the
grid is the size of the hold on every screen, whatever column it is in.
```

## Drop target

Above `func target_for(m: HoldItem, p: Vector2) -> Vector2i:`:

```text
Where would `m` land if dropped at `p`, and does it fit anywhere near?

NEAREST FREE CELL, within a couple of cells of the cursor, and NOTHING if
there is none. This used to fall back to `Run.find_hold_slot` — first fit,
scanning from the top-left — so nudging a part one cell to the left and
catching a corner of its neighbour teleported it to the other end of the
hold. Packing a grid is a game of small adjustments and that made every
imprecise one destructive.

Grabbed by the CELL UNDER THE CURSOR rather than by the part's top-left, so a
wide part dropped with the cursor over its middle does not jump a cell left.
Which cell the thing in your hand would land on.

MEASURED FROM THE ITEM, NOT FROM THE POINTER. `ItemIcon.Ghost` centres the
plate on the cursor -- that is what makes a drag feel like carrying something
-- but this read the raw pointer position as the item's TOP-LEFT cell. For a
1x1 the two agree and nothing looked wrong. For a 3x1 the highlight sat a cell
and a half to the right of the plate you were looking at, so the cells lit up
only when the CURSOR crossed them rather than when the item did.

Rounding, not flooring, once the half-footprint is taken off: with the plate
centred, the nearest cell boundary is the one it is visibly nearest to, and
flooring biases every drop up and to the left by half a cell.
```
