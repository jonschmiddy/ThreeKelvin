The reasoning behind `tkg/scripts/sim/ShipDriftTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Ship drift

Above `func run(tree: SceneTree) -> void:`:

```text
Does the ship move when you change its loadout?
  godot --headless --path . -- shipdrift

IT SHOULD NOT. Where the hull sits in its window is a fact about the hull and
the window. Bolting a gun on may add a gun; it may not slide the ship.

Reported twice. The first report blamed moving a part in the hold and the
cause was a stuck pan flag, fixed in `_on_clip_input`. The second blamed
unmounting a module, and this is a different fault with the same symptom:
`ShipView.ship_offset_x()` measures `_img.get_used_rect()`, the bounding box
of everything DRAWN -- and `_draw_modules` draws the fitted parts into that
same image. So the box moves with the loadout, `ShipScreen._ship_x()`
subtracts the offset, and the hull slides.

Headless is fine: this measures the composited image, not a rendered frame.
```
