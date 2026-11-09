The reasoning behind `tkg/scripts/sim/SkyShot.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Sky shot

Above `const SHOTS := [`:

```text
The screens that are not the sector, photographed against the sky.

  godot --path . -- skyshot

`SpaceLayer` gave a world to nine screens that had been panels on the clear
colour, and "the refit bay has a sky now" is not a claim anybody should make
from reading a diff. This opens each of them on a real run and saves a frame,
so the answer is a picture.

It also photographs the two that must NOT change — the station, which is an
interior, and the starchart, which draws its own galaxy — because the way
this feature breaks is not by failing to appear. It is by appearing somewhere
it was ruled out of.

NOT HEADLESS. The dummy display server never emits `frame_post_draw`, so a
headless run of this hangs and looks exactly like a crash. Same note as
StationShot, for the same reason.
```
