The reasoning behind `tkg/scripts/sim/ExhaustCheck.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Exhaust check

Above `func run(tree: SceneTree) -> void:`:

```text
Every exhaust strip in the library, loaded and measured.

  godot --headless --path . -- exhaust

WHY THIS EXISTS. A plume that fails to load is invisible rather than loud:
`exhaust` goes null, `ShipView` skips the blit, and the ship simply flies with
its engines out. Nothing throws and no test fails. The same is true of a strip
whose width is not a multiple of `EXHAUST_FRAMES` — the slicer takes a
truncated cell and the flame develops a seam that only shows in motion.

So this asserts the two things the art has to be true about, per file, and
prints the frame size and offset so a wrong-looking plume can be checked
against a number instead of an impression.
```
