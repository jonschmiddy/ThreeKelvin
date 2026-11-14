The reasoning behind `tkg/scripts/ui/BoardCork.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Cork board pool

Above `const SHADE := PostingBoard.SHADE`:

```text
WHAT IS PINNED TO A CHEAP CORKBOARD, an unclaimed station's and an outpost's,
besides the work. A pool to pick from (Jon: "Not 20X on the board, just a big
pool to pick from for diversity"): `PostingBoard` takes a handful of these per
station, by the station's number, and pins them where it likes around the
work, overlapping a little, as a real board's paper does.

Every piece is drawn in its own box, `size_of(i)` from (0, 0): its paper, the
shadow it throws down and to the right (inside the box), and its pins through
`b.pin_at`, which makes a push pin on cork and a magnet on enamel.

The first five are drawn by hand below. The rest are rows of `POOL`, each a
kind of paper (`k`) and what is on it, painted by the `_kind` funcs further
down. Square paper only: pixel text turned on its side goes to stair-steps.
The top 24 pixels of a piece are its title, which nothing else lands over.
```
