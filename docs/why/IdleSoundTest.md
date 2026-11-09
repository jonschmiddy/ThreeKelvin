The reasoning behind `tkg/scripts/sim/IdleSoundTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Idle sound

Above `var _tree: SceneTree`:

```text
YOUR IDLE IS HEARD EXACTLY WHILE IT IS SEEN (Jon, Oct 13: "Let's have a low
burn sound for the idle engines"):
  godot --headless --fixed-fps 60 --path . -- sheet=IdleSoundTest

`Audio` makes no sound headless, but it still decides every frame whether the
bed should be up (`Audio.idle_want`) and runs the fade (`Audio.idle_level`),
and that decision is the whole of the wiring. Read here against the picture,
which is `ShipView._thrust_now()` and where the hull is:
  - a new run's first arrival on LOCAL: silent through the clean burn, up from
    the first gap after it, and up, at full, once the ship has parked;
  - only your ship hums: one view in the tree, and no enemy's;
  - a hyperdrive's dark (engines off) takes it down, within the fade; so does
    a departure's FULL; parking brings it back;
  - a fight: your ship idles there, and it is heard there;
  - the star chart (no ship on screen): silent;
  - the refit and the transfer: your ship's idle flame is drawn there, so it is
    heard there too, and only by that one view (the transfer's old frame is
    quiet);
  - back on LOCAL: heard again.
The fade itself: up and down in IDLE_FADE_S, give or take a frame.
```
