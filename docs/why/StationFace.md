The reasoning behind `tkg/scripts/ui/StationFace.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Station face

Above `const IN_FROM_RIGHT := 312.0`:

```text
THE STATION, PULLED UP TO (Jon, on the dock: "the station becomes something on
the far right of the screen that the ship flies into .... and THAT becomes the
shipyard"). LOCAL at a station, with the one-camera flow on (`ZoomLadder`):
the station's side, side on, pinned to the view's right edge and running off
it, its landing hallway open at your ship's height and facing you.

DOCKING (Jon: "it's an arrival, let it breathe"): your ship sets off from
where it sits and slowly flies in toward the station; the station's lights
flicker on to meet it (a welcome: the inner door's glow, then the seam's lamps
outward from the hallway, then the guide lights along both lips, which then
run in toward the door); your ship goes in behind the lips and on into the
bay, and once its tail is inside the camera pans sideways through the
station's own hull into the yard (`ZoomLadder`'s pan, `draw_hull`).
Undocking is all of it the other way round.

WHICH SIDE (`StationSides`): seven kept sides, each with one of twelve kept
interiors in its recess, picked per station from the station alone. Every
side carries the Drum's entrance at the same rows, so everything below about
the hallway, the recess, the mask and the camera holds for all of them.

ONE MOUTH FOR EVERY SHIP (Jon: "We need to have the ship door opening always
be the same size, no matter what ship you are in. We need to have it as tall
as the large ships."): every side's hallway is 48 rows taller than the art
was painted (`art/stations/mouth.py`), so the tallest fitted hull in the game
-- a C-grade heavy with its turrets, `sheet=MouthSize` -- goes in at its own
size along the curve Jon approved, with the medium's room about it; the light
and the medium go in with room to spare. Your ship's path on screen is as it
was; the plate sits so the mouth stands 60 px above its middle and 66 below
(`ROW`): the tallest passes the lips 10 px from each, the medium's room above
it as Jon approved its dock.

EVERY KEPT SIDE (`art/stations/sides.py`, Jon's 1A for lights and depth): the
hull in layers, far first, the star's rim and shaded undersides baked in, each
layer moved by whole pixels as the camera comes in (`par`: the far ones less,
so the near boxes slide over the far); a dark crevice under them all, so a gap
opened by the parallax is the hull's own shadow and never a window onto your
ship behind it; the bay lit from its inner door at the door's power; the
lamps over it at their own power, and their light drawn as light.

Two of these are made: the plate behind your ship (`front` false) and the
front layer over it (`front` true).
```

## Plate position

Above `const IN_FROM_RIGHT := 312.0`:

```text
where the plate stands: its left edge this far in from the view's right edge,
its row `ROW` level with your ship's middle. SHORTER ON SCREEN (Jon: "make
the length of the space station shorter horizontally"): pinned further right,
so of the drum only its end ring, the hallway with its door, and the seam's
groove and bend show -- `SHOWN` px of the view, where it was 317 -- and the
rest of its length runs on past the view's edge
```

## Recess mask

Above `const RECESS := Rect2(0, 206, 212, 126)`:

```text
INTO THE HOLE AND COVERED UP (Jon: "have the ship go INTO the hole and be
covered up"; then, "The mask is wrong here"): the only part of the station
your ship is ever seen in front of is the bay's RECESS -- its dark interior,
from the open end to its back corner (rows 206..331, x < 212). Everything else
is hull and is drawn OVER your ship (each side's layers are the plate less the
recess, `art/stations/sides.py`): the lips, the frame
round the opening, the lit strip beside it, the plating beyond. So your ship
flies down the hallway and on past the recess's end, behind the hull, its
tail in past the recess's end a few frames before the camera pans (it is
still moving then: `TAIL_IN` is where the curve ends, deeper in) -- none of
it seen when the pan starts. Its size at most, as it goes deeper:
```

## Power-on sound

Above `const POWER_CLUNK := &"lab_outpost_lamp"`:

```text
THE POWER-ON, HEARD (Jon, Oct 21: "Can we also get some sounds for when the
station turns on?"), out of the game's own sounds, nothing generated. Each
bank of lamps (the door, the side's own lamps, the guide lights) clunks on
as its first lamp lights -- a breaker, the outpost's lamp a step down -- and
buzzes through its stutter (`FLICKER`); the warning lights going green
chime. On the frame each is seen, from `power` and `warn` as they are set,
so the dock's POWER step and LOCAL's wake are heard alike. Levels against
their neighbours: the clunk's loudest tenth of a second about -22 dBFS (the
dock's entry burn -21.6, the arrival's flameout -10 to -18, the clamps -8.6),
the buzz under it near the idle bed (-39.5), the chime between.
```

## Parallax

Above `const PAR_GAIN := 0.06`:

```text
THE PARALLAX (the other sides): a layer of parallax p is moved (1 - p) x
`PAR_GAIN` of the camera's travel across the plate (its view's middle, in
plate px, since it was at rest), in whole pixels, holding each step until the
travel is `PAR_HOLD` px past it (no A, B, A at a step's edge). Over the dock
the camera crosses about 600 px of plate: the farthest boxes (0.8) end 7 px
behind the near ones.
```

## Station hull draw

Above `static func draw_hull(c: CanvasItem, r: Rect2, x0: float, row_y: float, mod: Color = Color(1, 1, 1), k: float = HULL_K,`:

```text
THE STATION'S OWN HULL, close: the side's own window (`SideArt.hull_src`) of
every layer -- the crevice, the layers at their parallax `pars`, the lamps at
`lamp_k` -- tiled across `r` (in `c`'s px) at scale `k`, the tiles starting at
`x0`, the plate's row `ROW` level with `row_y`; with `ink` the dark behind it
all (the pan's), or space (LOCAL's own). The camera pans through it into the
yard (`ZoomLadder`).
```
