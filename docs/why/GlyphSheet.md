The reasoning behind `tkg/scripts/sim/GlyphSheet.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Glyph sheet

Above `const CROWDED := 0.34`:

```text
Which picture every card in the game draws:
  godot --headless --path . -- glyphs

The card gallery shows one manufacturer at a time and the glyph problem is a
DISTRIBUTION problem — "they all look the same" is a claim about the whole set
that cannot be checked by looking at eight cards from one manufacturer. This
counts every card, prints the split, and names the cards behind each picture
so a glyph that has quietly become a catch-all is obvious in one screen.

It caught the thing it was written for: under the old five-kind scheme
`attack` drew 40% of the card set and `defend` another 20%, so three cards in
five were one of two pictures.
```
