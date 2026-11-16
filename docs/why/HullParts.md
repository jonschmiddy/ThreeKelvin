The reasoning behind `tkg/scripts/data/HullParts.gd`; each heading is referenced from the code by a `Why:` line.

## Hull parts

Jon, Nov 15: "designate parts of the ship for each type of decision", for the current hulls and every
future one (the Solari rework among them). An event's choices sit on the parts of your ship that do the
work (`ShipParts`, `ShipChoices`); fractions of the hull's box put them roughly right on most hulls
but not on the feature (the bridge on a tower, the engines on the nozzles).

So every hull picture declares, by hand, a point on its own sprite for each part: bow, bridge, guns,
comm mast, radiators, engines, hold, flank and plating. They live in one table keyed by
`DB.hull_art_key`, beside `Database.HULL_MOUNTS` and `HULL_EXHAUST` (the same kind of measured,
per-picture data, kept by the same key), in a file of its own so `Database.gd` does not grow.
`ShipChoices` brackets the box round that point; a picture with no entry falls back to the fractions.

`-- sheet=HullPartsTest` fails any hull in `DB.hull_frames`, at any grade, whose picture does not
declare every part, or whose point is not on the picture's opaque pixels. A new hull picture is not
done until it declares its parts (docs/building-a-manufacturer.md). The points were placed on a 3x
sheet of each picture with the spots drawn (tk-scratch/shipchoices/stills/round6/hull_parts_sheet.png).
