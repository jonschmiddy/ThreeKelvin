The reasoning behind `tkg/scripts/ui/LabBoard.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## The labs research board

Above `signal buy(b: int)`:

```text
THE LAB'S RESEARCH BOARD, AS A STAR CHART (science S9; Jon's 1C, Nov 4): the
run's dealt board drawn on the Lab's big screen with the camera zoomed into
the glass (`LabZoom`). Three arms, FRAME, CORE and DRIVE, spiral out of the
FLIGHT COMPUTER on the galaxy's core; each arm is a branch's three steps in
the order they are bought. A step that is running is teal and lit, the next
one EMBER with its price (muted, its price red, when the DATA is short), and
the steps after it dim. The strip at the bottom says what the step in hand
does, and holds the one key that spends: BUY, on the next step only.

PORTED FROM THE APPROVED MOCKUP, NOT REDRAWN: every position, ink, ring,
dither, arm curve and label rule is `build.py`'s (tk-scratch/science/sheet2/
tree/build/), on the same 960x540 board, so the screen is the picture Jon
picked. The galaxy and the glass's finish are shaders (`lab_chart`,
`lab_finish_*`); the icons are `LabIcons`. The labels go where the mockup's
`Placer` puts them: off every step, every other label and every arm line,
outward first, so what reads where depends on the deal and on nothing else.

THE SAME BOARD AT EVERY LAB. The arms, the steps and the words stand where
they stand at a capital and at an outpost; only the glass's tint changes.

BUILT ONCE. The board is drawn, not made of nodes, except BUY: one Button,
made with the board and only moved, retitled and shown or hidden, so a click
on it survives the `resources_changed` its own purchase sends.
```
