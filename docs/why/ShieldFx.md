The reasoning behind `tkg/scripts/ui/ShieldFx.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Shield bubble

Above `signal moment(kind: StringName, strength: float, length: float)`:

```text
BLOCK, DRAWN AS K's HEX BUBBLE (Oct 13, mockups for a pick page; nothing
here is in a fight yet). In the sim block soaks damage first and is cleared
when the enemy's turn opens.

Round two, Jon's picks on round one: the BUBBLE, with changes --
  - fitted: an oval round the picture's own ink, a few pixels out, grown
    until no hull pixel is under its rim or outside it (`fit`; the harness's
    `fitcheck` proves it on every enemy picture, the Custodian takes and the
    player hulls);
  - the same at rest whatever block is left: no cells dropping per hit, no
    brightness steps;
  - alive: now and then (every 3-6 s, seeded per ship) a soft ripple crosses
    it, or a glitch -- a torn band, a one-pixel jump, a band flickering --
    for two to four frames; between those it holds still;
  - a soaked hit shimmers over the whole bubble for 0.4 s, brightest where
    it struck;
  - at 0 block it FIZZLES (sputters, flickers and dies over 0.7 s) rather
    than shattering, and so does leftover block at turn start;
  - a hit that breaks through still carries on to the hull (`through`).

Every change is held for whole frames and comes from an event or the idle
schedule; the rest frame is one still picture.
```

## Idle events

Above `func _start_idle() -> void:`:

```text
The idle life, one event at a time:
  ripple  a wave of light (one, or two from different points at once)
          spreading over the whole bubble in 0.7 s, lifting the cells it
          crosses and the rim with them;
  tear    a band of rows jumping 1-3 px sideways, 3-6 frames;
  slice   a taller band of cells jumping 3 px, then back;
  patch   a patch of cells going out, back, out, back;
  stutter the whole bubble dropping dim for a frame or two.
```
