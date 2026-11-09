The reasoning behind `tkg/scripts/sim/ConvoySlideTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Test purpose

At the top of the file, under `extends Node`:

```text
THE CONVOY COLUMN COMES AND GOES BY SLIDING (J4 B, Jon, Nov 5), AND THE
STUNNED TAG:
  tools/dev/godot.sh --headless --path tkg --fixed-fps 60 -- sheet=ConvoySlideTest
  tools/dev/render.sh --path tkg --resolution 1920x1080 --fixed-fps 60 -- sheet=ConvoySlideTest out=<dir>
  tools/dev/render.sh --path tkg --resolution 1920x1080 --fixed-fps 30 --write-movie <dir>/slide.avi -- sheet=ConvoySlideTest film=1

Jon: "The column appears when a partner arrives. Your ship slides 220 px
right, and each enemy moves and drops to half size, under a card you may be
dragging. If that player leaves ... the column disappears and the ship
slides back to the single player view." Through a real fight on the game's
own session hosting a party (VELA a roster row, CoreWinTest's way), the
animations on (`Router.animate_in_harness`):
  - a card is aimed at an enemy, then VELA arrives: the column slides in,
    every frame a whole pixel (the column's room, the row's offset, your
    hull slot), never back, over `EncounterView.SLIDE_T`; your hull slot
    ends `column_w` + the row's separation right, the enemies move; the
    card stays in hand, armed, the same CardView all the way (nothing in the
    hand is made again); the pointer held still near the enemy's edge, the
    target lit at the slide's end is what is under it now, or none;
    released over an enemy at its new place, it is played;
  - the box test at rest: the column's hulls, your hull and its plate, and
    every enemy's boxes inside the picture and clear of each other;
  - MERCER walks in on turn 2, stunned: his slot carries STUNNED under its
    gauges, inside the label's 92 px and the slot, clear of the name and
    the bars; gone when the turn moves;
  - both leave, with a card aimed again: the column slides out, whole
    pixels, and every rect is back where it was before, to the pixel; the
    card is still armed and is played on release;
  - your own ship joining VELA's fight on turn 2: the drawer's "Stunned."
    line inside the hand's area and clear of END TURN and the piles.
`out=` photographs each state at 1920 x 1080 (2x); `film=1` plays only the
slide in and out, in real time, for `--write-movie`.
```
