The reasoning behind `tkg/scripts/sim/MouthSize.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Station mouth size

Above `var _tree: SceneTree`:

```text
HOW TALL THE STATION'S MOUTH MUST BE (Jon: "We need to have the ship door
opening always be the same size, no matter what ship you are in. We need to
have it as tall as the large ships."), headless:
  godot --headless --path . -- sheet=MouthSize [weights=heavy,medium,light]
Every manufacturer's hull at every weight asked for and every grade, every
mount filled with its own parts (`StationShot`'s fit=full rule), measured on
LOCAL at a station: where the whole fitted ship (its hull's ink and every part
bolted on, `ShipView.fitted_rect_global`) is on the station's plate as its
nose reaches the lips on the dock's approved curve (its size following `fly`
from its own to its berth size). Prints each, and the rows the tallest needs.
```
