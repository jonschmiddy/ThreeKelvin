The reasoning behind `tkg/scripts/ui/ShipLoss.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Ship loss

Above `static func style_for(node_index: int, who: int) -> int:`:

```text
A PLAYER'S SHIP COMING APART (Jon, Oct 13): "When you die... let's have your
ship crack and explode... pause for a beat... then the run ended popup shows
up."

The same `ShipBreakup` the enemies die in, cut from your own hull's picture
as `ShipView` paints it (the full sheet in the fight, the half sheet in a
convoy slot) with the parts bolted to it laid in, so a turret does not hang
in space over the wreck. Nothing else of the screen: not the stars, not the
plate, not the HUD.

THE BOSS-LENGTH VERSION, always: the losing ship gets the prelude of bursts a
boss does, because it is the last thing this run shows.

FACING. `ShipBreakup` reads a ship as facing LEFT, as every enemy does: the
stern is the right-hand end (`_engines`), and OVERLOAD blows the back off
from there. Your ship faces right. So the picture is mirrored before it is
cut and the breakup is drawn mirrored back (`scale.x` negative): the engines
it finds are your engines, and every pixel of the wreck lands where it was
drawn.

STYLE AND CUT are positional, as an enemy's are (`EnemyArt.death_style`):
from the system and the ship, so a seeded run loses the same way twice and a
partner's ship comes apart the same way on every screen in the party.
```
