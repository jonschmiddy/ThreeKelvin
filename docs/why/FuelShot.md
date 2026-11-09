The reasoning behind `tkg/scripts/sim/FuelShot.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Fuel shot

Above `const HINT_S := 0.6`:

```text
THE FUEL READOUT AND THE FUEL HINT, as the game draws them:
  godot --path . --windowed --resolution 1920x1080 -- sheet=FuelShot hints out=<dir>

LOCAL at a system with a dock in reach, the tank at full, a third and near
empty (`hud_full`, `hud_third`, `hud_near_empty`: the whole window, and a 4x
crop of the readout beside each), then the fuel hint on LOCAL and on the
chart (`hint_local`, `hint_chart`), each `HINT_S` after it shows. Every other
hint is marked seen first, so nothing else comes up. Needs a window.
```
