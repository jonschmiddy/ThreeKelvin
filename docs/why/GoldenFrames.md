The reasoning behind `tkg/scripts/sim/GoldenFrames.gd`, written with it; each heading is referenced from the code by a `Why:` line.

## Golden frames

Above `const DeathStylesS`:

```text
A refactor of drawing code has one rule, that no pixel changes, and nothing in
the gate compared a frame. This is run on demand: capture into a temp folder
before the refactor and again after, then `tools/dev/golden_diff.py A B`. It is
not in the gate and no capture is kept, because the game is still changing.

Why a frame is the same twice: Rng.forced is 4242, effects and breakups are
stepped by hand a thirtieth of a second at a time, and screens run on
`GameClock` under --fixed-fps 60, each frame a counted number of frames after
the screen opens. Checked by six captures, two of them at once with the CPU
loaded.
What reads the wall clock or the global generator anyway:
  - `BoardLamp`'s dust and flicker: the lamp is hidden.
  - `StationSpine`'s lit floor: the lift car is parked (`car = -1`).
  - The LCD marketplace (`PostingBoard._t()`): `boards/lcd_dev3_live` is written
    under `_varies/`, which the diff skips.
  - `FaunaBrace._flake` shuffles with the global generator: `hitfx/fauna_brace_hit`
    and `hitfx/fauna_hit0` (the brace is up) are written under `_varies/`.
  - Left out, not repeatable: the sector screen (its sky and system map seed
    from the wall clock) and the station's SERVICES deck (the yard's flames).
```
