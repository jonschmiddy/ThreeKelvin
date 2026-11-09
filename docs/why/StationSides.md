The reasoning behind `tkg/scripts/ui/StationSides.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Station sides

Above `const IDS: Array[StringName] = [&"drum1", &"drum3", &"pile1", &"pile3", &"pile4", &"shanty3", &"terraces"]`:

```text
THE STATION SIDES JON KEPT (Oct 10-11): seven sides and twelve interiors,
the pool every station on LOCAL is drawn from (`StationFace`).

THE SIDES: the Drum takes 1 and 3, the Container Pile takes 1, 3 and 4, the
Shanty take 3 and the Terraces (s115_1). Every one carries the Drum's
entrance at the same rows, so the hallway, the recess, the inner door, the
lips and the camera's numbers are the Drum's for all of them (`StationFace`'s
SLOT, RECESS, DOOR_X, LIP_X, EDGE_X). All seven are lit and split by
`art/stations/sides.py` (Jon's 1A for lights and depth, "all of it"): the star's
rim, shaded undersides, near-over-far layers (the piles' boxes) that move
by whole pixels as the camera comes in, the bay lit from its inner door, and
the lamps drawn as light, Drum take 1 too (Jon's 2B). Every side's hallway is
48 rows taller than painted (`art/stations/mouth.py`: one mouth for every
ship, tall enough for the tallest). The five sides recovered from LOCAL frames (Drum 3, the Piles, the Shanty)
had their right ends painted by PixelLab (Jon's 1B, `art/stations/src/
painted/`), so the camera following your ship in sees the side's own hull,
not a repeat.

THE INTERIORS (Jon: "For the entrance I wanted this part changed"): the
recess only, plate x 84..211, rows 206..331, drawn over the bay; the lips, the
gold frame and the lamp strip are the side's own. Each was made 48 rows taller
from its own art (`sides.py`'s `interiors`: rows that repeat, copied) -- the
six hallways and four cargo bays; the three irises, whose rings would have
stretched to pills, repainted at the new height (Jon's "Irises: A"); iris
90_1 was then cut ("this is the only one that looks bad. you can just cut it").

WHICH ONE A STATION GETS: decided by the station alone -- this galaxy's seed
and the station's place among the map's stations -- so it is the same on
every visit, after SAVE & EXIT and CONTINUE, and nothing is rolled for it
(the run's random streams are never touched). The map's stations take the
sides in turn from a start the seed sets, so neighbours differ while there
are sides to go round; the interiors the same way, on their own start and
stride.
```
