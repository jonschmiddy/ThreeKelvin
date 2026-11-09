The reasoning behind `tkg/scripts/sim/PlaceSheet.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Place contact sheet

Above `const W := 420`:

```text
Contact sheet for the moving parts of a sector:

  godot --path . -- placesheet

`SkyTest` shoots one frame per place, which is the right tool for judging a
composition and the wrong one for judging an animation. Two things in a
sector move -- the beacon's rings and a station's navigation strobes -- and a
single frame cannot tell a ring travelling outward from five circles that
happen to be drawn at those radii.

So this is the same place across one full cycle, left to right. A row that
reads as five different pictures is working. A row where the eye cannot find
what changed is an animation nobody will ever notice, and should be cut
rather than kept for the changelog.

NOT HEADLESS: it renders through SubViewports and needs a real display, the
same as every other sheet in this folder.
```

## Place frame

Above `func _frame(tree: SceneTree, n: MapGen.MapNode, at: float) -> Image:`:

```text
One frame of one place, with the clock wound to `at`.

The clock is SET rather than waited for. `_process` would get there on its
own in a few seconds a frame, and a sheet that takes ten seconds to render is
a sheet nobody runs twice -- and worse, the frames would land wherever the
frame rate put them rather than on even divisions of the cycle.
```
