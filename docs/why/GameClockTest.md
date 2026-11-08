The reasoning behind `tkg/scripts/sim/GameClockTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Game clock bobs

Above `var h := Harness.new()`:

```text
THE BOBS RUN ON GAME TIME, NOT THE WALL'S (Jon, of the full fight films,
Oct 13: "the hovering animation is REALLY fast for some reason").
  godot --headless --path . -- sheet=GameClockTest
The movie writer steps the game 1/60 s a frame however long a frame takes to
write, so anything on `Time.get_ticks_msec()` raced through a film (the
cutter's bob: 0.375 s a cycle against 4.76) and ignored the hit-stop's slow
motion. Through the real SectorScreen, a pack of three, and your ship:
  a frozen frame: `Engine.time_scale` 0 and one frame held 2.6 s on the wall
    (over half of every bob's cycle): no bob moves;
  fast time: `time_scale` 20 for 0.4 s on the wall (8 s of game time, more
    than a cycle): every bob goes the whole way, top and bottom;
  a slot made later, at the first slot's place in the pack, bobs in step
    with it on the same frame (one clock for the pack, phases kept);
  `ShipView.shot_clock` still drives your ship's bob, for the harnesses.
```
