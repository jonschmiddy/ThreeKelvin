The reasoning behind `tkg/scripts/sim/PopPlaceTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Pop placement

Above `var _tree: SceneTree`:

```text
WHERE THE NUMBERS SIT, on every hull:
  godot --headless --path . -- sheet=PopPlaceTest

Jon, Oct 13 ("Pops: B"): held over a ship, the card's number is ON it,
centred on the hull's ink both ways; landed, the pop is ABOVE the ship,
centred across on the ink and clear of its top, stacking upward. Measured
off the ink, not the canvas: BLOCKED 5 sat right of your hull's middle
because the canvas carries the exhaust's clearance on one side.

For every enemy picture (`DB.enemies`) and every player hull (each
manufacturer at each weight), in a real fight:
  - the preview's letters (`EnemySlot` / `ShipSlot.preview_rect`) are
    centred on the hull's ink within 1 px, both ways;
  - every pop a landing makes (-6, BLOCKED 5, MISS, stacked) is centred
    across on the ink within 1 px, and its letters and their outline are
    wholly above the ink's top;
  - on an enemy, above its intent words too (Jon, "C"), and no pop, at rest
    or risen, touches any ship's intent words or its name/bar readout;
  - and every pop, risen, is on screen under the top HUD.
Lone ships, and packs (each in the current formation, every ship checked).
```
