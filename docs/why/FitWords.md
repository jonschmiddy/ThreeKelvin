The reasoning behind `tkg/scripts/sim/FitWords.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Word widths

Above `const PAD := 12`:

```text
How wide a word is on a rail button:
  godot --headless --path . -- fitwords

Every button on both combat rails is cut to `PileView.W`, so that width is set
by the LONGEST string any of them ever shows -- and picking that string by eye
is how the rail went to 100 to hold "NOT NEGOTIATING". This measures the
candidates at the real font and the real size, against the widths the rail
could plausibly be, so the choice is a table rather than a guess.

The button's own stylebox eats some of the width. `PAD` is the horizontal
content margin the flat boxes on FLEE and HAIL use, doubled.
```
