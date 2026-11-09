The reasoning behind `tkg/scripts/ui/HintCard.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Hint card

Above `const GAP := 7.0`:

```text
ONE FIRST-RUN HINT ON SCREEN (`Hints`): two short lines in the first-run
intro's caption style, beside the thing it is about, with a small notch
pointing at it.

IT IS NOT A BUTTON, and it does not look like one. It has no hover, no hand
cursor and no edge that lights, and it ignores the mouse, so a click lands on
whatever is under it. No click dismisses it: it goes when the player has done
what it teaches (`Hints.DONE`; Jon, Oct 22). It never covers what it points
at: it is placed on
whichever side of its subject is clear of the subject, the things listed to
avoid, and the screen's edge.
```
