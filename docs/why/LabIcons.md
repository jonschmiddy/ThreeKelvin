The reasoning behind `tkg/scripts/ui/LabIcons.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## The labs bitmaps

Above `const ICONS := {`:

```text
THE LAB'S BITMAPS (Phase 12, S9): the board's twelve routine icons, the flight
computer, the eight affix icons AUGMENT offers, the three recipes, and the DATA and CREDITS marks.
Ported as data from the approved star-chart mockup (tk-scratch/science/sheet2/
tree/build/icons.py, Jon's 1C, Nov 4). Each is rows of one character a pixel:
"#" full ink, "+" half ink (the ink mixed halfway to the glass), "." clear,
"O" white. Keyed by the routine's NAME as the board prints it, so a routine
renamed in Database.gd needs its key renamed here.
```
