The reasoning behind `tkg/scripts/sim/FlyinFilm.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Flyin film

Above `var _tree: SceneTree`:

```text
LOCAL'S OWN ARRIVAL AND THE STATION'S WAKE, FILMED WITH THEIR SOUND (Jon,
Oct 21, "station:BC"):
  godot --path . --windowed --resolution 1920x1080 --fixed-fps 30
      --write-movie <dir>/x.avi -- sheet=FlyinFilm [route=world|station] [seed=N]
A run in a station's system, the ladder on, its clock stepped by the game's
own. `route=world`: the map with your ship alongside the station, FLY HERE to
a world, and LOCAL by the HUD's tab: your ship flies in and settles.
`route=station`: the map with your ship at that world, FLY HERE to the
station, LOCAL: it flies in, settles, and the station wakes, heard; then the
map and LOCAL again with no flight between, parked, the station lit. Prints
the frame each step began on (`mark`). Needs a window.
```
