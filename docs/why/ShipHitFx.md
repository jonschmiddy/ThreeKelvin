The reasoning behind `tkg/scripts/ui/ShipHitFx.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Hit overlay

Above `signal moment(kind: StringName, strength: float, length: float)`:

```text
HITS ON A SHIP, made of the death styles' pieces (Oct 13, mockups for a pick
page; nothing here is in a fight yet).

Jon loved the deaths and wants "these effects used during the fight, for
damage and so on", then: "The bullet holes from chain are also GREAT", and
then that he wants all of it, for variety, the way deaths roll. So a hit is
one of four KINDS, rolled per hit from the fight's seeded generator:
  SCORCH  a sharp flash and a spray of sparks; a scorch mark stays.
  HOLE    E CHAIN's blast hole: a ragged bite punched in, scorched round,
          its chips flying off, its lip glowing and cooling.
  CRACK   cracks run from the hit along a network laid over the hull,
          white-hot, cooling to dark lines, joining up as hits add up.
  VENT    a puncture at the edge, air jetting out; from then on, while the
          hull is low, the hole sputters now and then.
Small hits lean to scorch, big ones to holes and cracks; venting only once
the hull is at half or less (`roll`). Every mark stays and they build up
together, each placed clear of the others on the side the shots come from,
so a badly hurt ship is a mix and not a pile.

AN OVERLAY, NEVER A REDRAW. The ship is drawn by its owner (EnemyArt,
ShipView); this is handed its pixels only to know where the hull is and what
a scorched pixel becomes. What stays is a picture of the changed pixels
alone, transparent elsewhere, drawn over the ship and never moved: it cannot
shimmer. Everything that moves is light or a mote, in whole pixels, stepped,
and out within half a second, except a vent's sputters (a short puff
seconds apart).

THE MARKS OUTLIVE THE SHIP. `damaged(img)` is the ship's picture with every
mark on it; hand that to ShipBreakup.setup and to wreck_image and the pieces
and the wreck keep the damage (one blend; the owner keeps that image for the
wreck instead of the clean one).

`moment` names each visible event for sound, as ShipBreakup's does.
```

## Hit looks

Above `static var look := _look_arg()`:

```text
WHICH LOOK A SHIP'S HULL TAKES ITS HITS IN. Jon picked D (Oct 17): A, B and C
mixed per hit (`HullHitFx`), so D is the game's. 0 is this file's marks,
Chain's holes and all, which only the Custodian still wears (`HitLayers`:
it is grown, not built); 1 A battle-worn, 2 B heat and stress and 3 C crack
and peel are D's parts, kept as looks of their own for comparing.
`-- hull=today|A|B|C|D` on the command line plays one.
```
