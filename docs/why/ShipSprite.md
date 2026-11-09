The reasoning behind `tkg/scripts/ui/ShipSprite.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Ship sprite

Above `const HEAT_SHADER := "res://shaders/heat.gdshader"`:

```text
Composites the ship from real sprites: hull + one Sprite2D per installed module,
placed at the hull's deck anchors. This is what keeps the design pillar alive —
the ship on screen is always the build you assembled.

Falls back to the procedural ShipView when the hull has no sprite yet, so the
game stays playable through a partial art migration. You will not generate all
~90 assets in one sitting.

STILL NOT INSTANTIATED, and now one step further behind. `ShipView` draws
from a `ShipBuild` — a hull, a list of hardpoints and two gauges — so it can
draw a ship being flown on somebody else's machine; this class reads `Run`
and can therefore only ever draw yours. Anything that revives it has to take
the same subject.

That matters because this is the file that closes the one gap the party
display still has: a hull WITH real art is blitted whole and its modules are
not drawn on it, which today means a medium chassis shows no fitted weapons
for anybody. The fix is module sprites plus populated
`HullData.weapon_anchors`, which is exactly what the loop below already
expects — see `docs/art/ART_CONTRACT.md` for the order the assets arrive in.
```
