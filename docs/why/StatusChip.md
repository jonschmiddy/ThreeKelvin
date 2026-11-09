The reasoning behind `tkg/scripts/ui/StatusChip.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Status chips

Above `const ICON := 12`:

```text
One thing currently true about a ship, drawn rather than spelled.

The status row under your hull used to be words in boxes -- "brace 5",
"lock +2", "salvo up". Words are unambiguous and they are also slow: a row of
five of them is a paragraph you have to read every turn, it grows wider than
the ship it belongs to, and at `FS_SMALL` under a sprite it competes with the
hull number that is the one thing there you must never misread.

An icon is read in the shape rather than in the letters, so five of them are
still one glance. The cost is that the NAME is gone, and a picture nobody can
name is worse than a word -- so every chip carries a tooltip that says the
word out loud, and the magnitude stays as a digit beside the glyph. The icon
is the index; the tooltip is the entry.

The glyphs are built from the same parts as `CardView`'s keyword art -- flat
rectangles on a small grid, no curves, no anti-aliasing -- but they are drawn
at a twelfth of the size, which means they are DIFFERENT drawings and not the
card art scaled down. A reticle that is legible at 44 pixels is four grey
smudges at 12.
```

## Glyph design

Above `_p(1, 0, 5, 4, dim)`:

```text
The round going through where the ship WAS. Absence, drawn --
the same joke the card's glyph tells, with fewer pixels.

The halves have to be BIG. Drawn as narrow stubs they stopped
reading as a ship at all and the whole glyph came off the
sheet as a division sign.
```

Above `_p(1, 2, 3, 1, dim)`:

```text
Two rounds away, with the tracers behind them. The second
volley, which is what the keyword pays for.

It was two chevrons and they did not touch: six two-pixel
blocks on a diagonal come off the sheet as a checkerboard,
not as ">>". Solid shapes read at this size; implied ones do
not.
```

Above `_p(4, 0, 4, 2, tint)`:

```text
The drone, standing over a shield. It is a drone that guards
rather than shoots, so it is the drone glyph above a tapered
plate of armour.

The first attempt was two flat bars, which read as neither.
```

Above `_p(1, 3, 10, 1, tint)`:

```text
Level. Nothing is happening and nothing is about to, so the
glyph is the absence of a shape: two rules, flat, with air
between them. Thin horizontals are the one thing nothing else
in the kit is made of; `block` is a solid mass.
```
