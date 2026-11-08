The reasoning behind `tkg/scripts/sim/MapLagTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Map lag

Above `var _tree: SceneTree`:

```text
The sector map's worlds keep up with the camera, headless:
  godot --headless --path . -- maplagtest

Jon: "When moving the view left to right in the sector view, the planets seem
to lag behind." Each world's picture is eased onto its place on the grid as a
zoom settles (`SystemView._live`); the ease once chased the place on a pan
too, so the picture trailed its own orbit ring, label and beacons by about
2.4 frames of the pan (13 px at 6 px a frame, 30 at 12, on a 30 fps window;
more on a faster one). Through the real map: zoomed in and settled, then
panned 6 px a frame both ways, and every world's picture must sit on its place
(`SystemView.world_lag`) on every frame of the pan. The used state, not the
fresh one: the zoom has just moved and settled before the pan starts, and the
pan turns round halfway.
```
