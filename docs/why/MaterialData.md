The reasoning behind `tkg/scripts/data/MaterialData.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Materials

Above `@export var id: StringName = &""`:

```text
One physical thing in your hold that is not a module.

`MaterialTable` is the catalogue -- 64 authored rows with ids, tiers, shapes,
values and text. This is the INSTANCE: the particular crate of deck plate you
are carrying, which knows where it sits.

Two rules from `docs/briefs/MATERIALS_NOTE.md` shape this class:

§3.1 -- materials DO NOT STACK. Two coil stock take two cells. Which is why
this is an instance rather than a tally on the hold, per §3.2: a tally cannot
say "one is here and the other is over there".

§1 -- credits are the only currency. A material carries a `value`, and that
value is what a station PAYS for it. It never prices anything.
```

## Material picture

Above `@export var sprite: Texture2D = null`:

```text
Its picture, or null while it has none.

THE SAME SHAPE `ModuleData.sprite` USES, and for the same reason: the icon
draws art when there is art and the authored container when there is not, so
a material without a picture is a crate rather than a hole. `MaterialIcon`'s
own note argues a material should read as cargo rather than as its contents,
and that argument still holds for the forty rows of deck plate and coil stock
-- what it did not anticipate is an ARTIFACT, which is the one tier where the
object itself is the reason you are carrying it.
```

## Material cells

Above `static func of(row: Dictionary) -> MaterialData:`:

```text
Build one from its catalogue row.

`cells` is a string in the table -- "2x1" -- because that is how it was
authored, and the note is explicit that the shape is a decision somebody
already made rather than something to derive from a name later. Parsing it
here is the one place that string becomes a shape.
```
