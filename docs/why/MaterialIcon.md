The reasoning behind `tkg/scripts/ui/MaterialIcon.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Material icon

Above `var item: MaterialData = null`:

```text
A material sitting in the hold.

The counterpart to `ModuleIcon`, and deliberately NOT a variant of it. A
module icon draws the part -- a barrel, an array, a bay -- because the whole
reason it shares a silhouette with the thing on the hull is so you recognise
the gun you are about to bolt on. A material has no hull form to echo. It is
cargo: a crate, a spool, a drum, and what you actually need to read off it is
how much room it takes and how good it is.

So this draws a CONTAINER, sized to its footprint, coloured by its tier. Same
flat rectangles and same 40-pixel cell as the module icons beside it, so a
packed hold reads as one surface with two kinds of thing in it rather than as
two art styles sharing a grid.
```

## Plate scale

Above `var plate_scale: float = ModuleIcon.HOLD_K`:

```text
How big the picture inside is drawn. THE SAME NUMBER THE BOX WAS SIZED WITH,
which is not a free choice: the crate path below takes its dimensions from
`size` and would follow a rescaled icon while a hardcoded sprite scale did
not. That exact mismatch is what put a 3x box around a 2x sprite on the
module gallery -- see `ModuleIcon.plate_scale`, which carries the same field
for the same reason.
```

## Tooltip

Inside `setup()`, above `tooltip_text = tip_text(m)`:

```text
THE SAME SHAPE EVERY OTHER TOOLTIP USES: a name, a line of hard facts,
then the prose, wrapped by
`Widgets.tip` because Godot does not wrap tooltips at all -- a tooltip is
as wide as the longest line it was handed, so a paragraph given raw becomes
a banner across the screen.

The facts line carries what the crate cannot say by looking. Its tier is in
the colour and its footprint is in the shape, but what a station will PAY is
nowhere on the icon, and that is the number a packing decision turns on.
```

## Art or crate

Inside `_draw()`, above `if item.sprite != null:`:

```text
ART WHEN THERE IS ART, the crate underneath forever. The same door
`ModuleIcon.draw_body` opens and `ShipView` proved on hulls, and it is
deliberately the ONLY place that decides -- two places asking "does this
have a picture yet" drift the moment one of them is fixed.

The note above still stands for the forty rows of deck plate: cargo reads
as cargo, and a spool of wire does not need a portrait. What it did not
cover is the ARTIFACT tier, where the object IS the reason it is aboard.
Those get a picture; everything else keeps the container.
STOOD ON END WHEN IT IS TURNED, as a module's art is (`sprite_turn`), or
a turned 2x1 would draw its picture lying across the 1x2 box it occupies.
Both pictures tonight are 2x2, so this is for the next one.
```

## Tier colour

Inside `_draw()`, above `var tier := UITheme.tier_colour(item.tier)`:

```text
THE TIER IS AN ACCENT HERE, NOT THE WALL.

`rarity_colour` is the game's one grade ladder and it is a saturated set --
correctly, because everywhere it existed before it was an INK: a card's
name, a plate's edge, four readouts. A crate is not an ink, it is forty
pixels square of fill, and eight of those in the game's saturations turned
the container into the brightest object on a screen made of cold steel.

So the same colour is used twice at two strengths, which is the split
`rarity_ink` already admits exists. The BODY is the tier pulled most of the
way toward the ground -- enough to tell two crates apart, not enough to
shout -- and the EDGE and the pip stay full strength, because that is where
identity is read from down a row of them.
```
