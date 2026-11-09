The reasoning behind `tkg/scripts/sim/MaterialTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Catalogue check

Above `func run() -> void:`:

```text
Every catalogue row becomes an item the hold can actually hold.

`MaterialTable` authored 64 rows before anything could carry one, so its
shapes, values and ids have never been checked against the thing that has to
accept them. This is that check, and it is the gate
`docs/briefs/MATERIALS_NOTE.md` §4 asks for.

The point is the SHAPE. A row whose `cells` reads "5x1" parses fine, builds a
fine instance, and can never be placed in a four-wide hold -- it would roll,
drop, and refuse to go anywhere, and nothing would say why. That is precisely
the failure a table authored ahead of its consumer produces.
```

## Carry check

Inside `run()`, above `Run.start_new_run(&"korvan", int(HullData.Weight.LIGHT))`:

```text

Placed for real, into a real hold, one at a time. `parse_cells` returning
a sane Vector2i is not the same claim as `place_in_hold` accepting it.
The LIGHTEST hull, matching the shape check above: placing into a heavy's
hold would pass rows that a light can never carry.
```

## Save check

Inside `run()`, above `Run.cargo.clear()`:

```text

A material stores only its id and its cell; everything else is rebuilt from
the catalogue. That is the right way round, and it is also the half that
can silently fail -- a row rebuilt from a table is a row that can come back
as something else, or as nothing.
```

## Jettison

Inside `run()`, above `Run.cargo.clear()`:

```text

The ruling is that jettison DESTROYS NOTHING: it moves the item into the
bag at the system you are standing in, so it is recoverable until you jump.
Both halves are checked, because a jettison that removed the item and
forgot to append it would look identical from the hold.
```

## Take back

Inside `run()`, above `Run.cargo.clear()`:

```text

`stow` is what TAKE calls once the claim is won, and it was the last
`ModuleData` on the path from a bag to a hold. The failure was the bad
kind: `take_from_bag` marked the option taken FIRST and then stowed, so a
crate spent its claim and stayed on the floor -- gone from the bag's point
of view and never in your hold.
```

## Drag target

Inside `run()`, above `Run.cargo.clear()`:

```text

The ghost centres the plate on the pointer, so the cell a 3x1 lands on is
a cell and a half LEFT of the pointer -- and `target_for` was reading the
pointer as the item's top-left. For a 1x1 the two answers agree, which is
why it looked fine until something long was dragged.

Pointer at the centre of cell (2,1) is (100, 60) at a 40px cell. A 3x1
centred there starts at x=40, which is column 1.
--- an inspection of a hold with a material in it -------------------------
contraband_count read `contraband` off every cargo item; a material has none
```

## Full-hold swap

Inside `run()`, above `Run.cargo.clear()`:

```text

Dragging a stowed part onto an occupied hardpoint takes the resident off
the hull and puts the new one on. The resident lands in the cells the new
one is that instant giving up, so a swap for a part of the same size or
smaller cannot fail -- and a full hold refused all of them, because the
room test ran while the departing part was still counted as in the way.
```

## Repeated throw

Inside `run()`, above `Run.cargo.clear()`:

```text

Taking from a bag marks the index claimed rather than removing the entry,
so jettison used to APPEND -- and the second throw put a second reference
to one object in the bag. `find()` answers with the first, which is the
spent one, so `take_from_bag` saw a claimed index and refused. Anything
you had thrown out more than once could not be picked back up.
```

## Cancelled turn

Inside `run()`, above `Run.cargo.clear()`:

```text

Pressing R mid-drag flips `turned` on the item while it is still sitting
in the hold at the cell it was picked up from. If the drag is then
cancelled, that cell now holds a different shape -- a 4x1 in the bottom
row becomes a 1x4 hanging off the bottom of the grid, over whatever it
crosses. That is the state this reproduces and `Run.settle` is what
answers it.
```

## Money takes no room

Inside `run()`, above `Run.cargo.clear()`:

```text

A chit is a HoldItem that lies: it has a footprint so a container can draw
it, and it never occupies a cell. The claim worth checking is that a FULL
hold still takes it -- that is the one item in the game where "do I have
room" is not a question, and the whole point of it.
```
