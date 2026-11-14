The reasoning behind `tkg/scripts/ui/BoardWhite.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Whiteboard pool

Above `const BLACK := Color("#2a2a30")`:

```text
WHAT IS DRAWN ON A SETTLEMENT'S WHITEBOARD, in marker, by hand. A pool to pick
from (Jon: "Not 20X on the board, just a big pool to pick from for
diversity"): `PostingBoard` takes a few of these per station, by the
station's number, and puts them where it likes around the work.

Every drawing is drawn in its own box, `size_of(i)` from (0, 0), with
`PostingBoard`'s marker helpers -- `hand_text` for words, `wobble_line`,
`wobble_rect` and `wobble_circle` for strokes -- so the lines bow and
overshoot the way the rest of the board's do. Nothing here may shimmer: the
wobble is seeded by the drawing's own number.

The first eight are drawn one by one, below. The rest are rows of `MORE`:
each names a kind of scribble (a list, a tally, a hangman game, a pie chart)
and what is written in it, and `_paint` draws it. The handwriting knows
A-Z, 0-9 and ! : - + Q ? . , ' / = # ( ) and nothing else, so every word in
the table is upper case and keeps to those.
```

Above `const MORE := [`:

```text
THE REST OF THE POOL, as rows: who scribbles on a hiring hall's board is
crew, dock hands, haulers and the people who live there, so it is lists and
games and grudges and doodles, not notices. `k` is the kind; the other keys
are what that kind needs. A row with no `s` sizes itself from its words.
---------------------------------------------------------------------------
```
