The reasoning behind `tkg/scripts/ui/HitLayers.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Hit layers

Above `signal moment(kind: StringName, strength: float, length: float)`:

```text
ONE SHIP'S DAMAGE, BLOCK AND BRACE, DRAWN (Jon's picks, Oct 13: "Hits: brace:I
go:A" -- hits B, the bubble shield, brace I). Laid over a ship's picture in a
fight, in that picture's canvas pixels, by whoever draws the ship:
  `hits`   HullHitFx (Jon's pick, D: dents, scrapes, heat blooms, knocked and
           peeled plates, mixed per hit, building up; no holes), or for the
           Custodian ShipHitFx's older marks (`ShipHitFx.look`);
  `shield` ShieldFx: block as the hex bubble, fitted to the ship;
  `brace`  BraceFx: brace as the plated overlay.
Driven only by what the screen has SHOWN: `land` on the frame a volley lands
(with its pop and its sound), `sync` when the screen catches its numbers up
(a card's block or brace, a turn's start), `expire_block` when a turn opens.
Nothing here reads the fight, so a held number and a held picture agree.

DETERMINISTIC from `seed` (the fight's node and the ship's place), so two
machines in a shared fight draw the same marks for the same landings.
```
