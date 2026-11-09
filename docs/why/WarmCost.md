The reasoning behind `tkg/scripts/sim/WarmCost.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Warm cost

Above `var _tree: SceneTree`:

```text
WHAT EACH SHADER COSTS TO COMPILE THE FIRST TIME IT IS DRAWN, on this machine:
  tools/dev/render.sh --path tkg -- sheet=WarmCost [only=sky,planet,...] [mesh=map_fabric]
Each shader under res://shaders/ is drawn once into a 4x4 viewport of its own
(as a rect; `mesh=` names the ones also drawn as a mesh, the variant
`draw_mesh` binds): the frame that draws it, timed from its process step to
the end of its draw (`frame_post_draw`), against the median of frames that
compile nothing. (Not a `force_draw` straight after adding it: a new item's
draw list is made at the frame's end, so that draw held nothing to compile,
and every shader timed at under a millisecond.) Every run has a fresh profile, so this is
a cold compile -- what a launch costs where the driver keeps no program
binaries (Apple's OpenGL), or a first launch anywhere. Needs a window: the
dummy renderer compiles nothing.
```
