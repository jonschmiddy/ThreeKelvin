The reasoning behind `tkg/scripts/ui/ModuleCell.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Module cell

Above `enum Kind { HARDPOINT, STORAGE }`:

```text
A place a module can sit, and be dropped onto.

Two kinds — a hardpoint and a storage square — because they differ only in
what they ACCEPT and what happens on arrival, and building two controls to
express that would have been two copies of the same drag plumbing.

A hardpoint knows its slot type and takes nothing else. The moment you pick a
part up, every mount that WILL take it opens a tractor beam — so you find out
where a system can go before you have gone looking, and the mounts that refuse
it simply stay dark. See ModuleCell.Tractor for why that is the way round.
```

Above `var index: int = -1`:

```text
HARDPOINT only: WHICH mount of that type this is, counting from 0.

A mount is a place on the physical hull — weapon 0 is the dorsal ordnance,
weapon 1 the ventral barrels — so the cell has to carry its number through to
the module that lands on it. Storage squares are interchangeable and leave it
at -1.
```

Above `func _accepts(m: ModuleData) -> bool:`:

```text
Would this cell take that part?
A MOUNT, not a shelf. Materials live in the hold and never bolt to a hull --
they have no slot, no mount and no power draw -- so this stays typed to
`ModuleData` on purpose and the drop check below refuses anything else.
Before materials existed the type was the whole guard; now it has to say so.
```

## Mount pad

Above `class Pad extends Control:`:

```text
The ember outline of a free hardpoint, at the SIZE OF AN ICON.

It used to be the cell's own stylebox border, which made every empty mount
read visibly larger than a filled one: the panel is 48px and its content rect
is 44px, so a fitted module showed a 44px plate inset inside the border while
an empty mount showed the 48px border itself. Same cell, two apparent sizes,
and the empty ones looked inflated. Drawing the outline as a CHILD puts it in
the content rect, which is exactly where the icon would be.
```

## Tractor beam

Inside `_drop_data()`, above `const BEAM := 5`:

```text
A mount reaching for the part you are holding.

Shown the instant a drag starts, on every cell that ACCEPTS, so the answer
to "where can this go" is the whole board rather than one square at a time.

REPLACES a red cross on every hardpoint that would refuse it. The cross
was the louder signal by a distance — half a dozen of them lit up across
the rack the moment you picked anything up, so the screen answered a
question nobody asked ("where can this NOT go") in the most emphatic way
available, and the one mount that mattered was the only thing not marked.

Now the affordance is positive and the refusals are silent: a cell that
will take the part opens a beam, and a cell that will not does nothing at
all. Same information, inverted, and it points at the answer.
```
