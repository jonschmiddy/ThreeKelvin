The reasoning behind `tkg/scripts/sim/RingSheet.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Ring sheet

Above `const ScreenS := preload("res://scripts/ui/sysmap/SystemMapScreen.gd")`:

```text
A RINGED WORLD IN EVERY RING LOOK, photographed in the game (Jon: "can these
rings be a bit nicer? they're flat"):
  godot --path . -- sheet=RingSheet out=<dir> [node=N] [body=B] [at=S] [seed=N]
The real system map, centred on the world, at zoom 1, 2 and 4; the panel's
portrait of it; and the world alone at one pixel a pixel, as `-- planetsheet`
draws it, lit as the portrait is and then from the ring's dark side -- once
for each of `Rings.Look` (the dots as they are, then A, B and C). Each picture is saved as <dir>/<look>_<what>.png at game scale for a
sheet to be made from. Without `node=`, the first system holding a ringed
giant. Needs a window: a shader draws nothing headless.
```
