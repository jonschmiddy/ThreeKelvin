The reasoning behind `tkg/scripts/ui/sysmap/PulsarView.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Pulsar view

Above `const SHADER := preload("res://shaders/pulsar.gdshader")`:

```text
THE PULSAR on the system map, as Jon picked it: beams turning once a
second, a flash 0.55 s into each second (on the beat of its sound), a cloud
of gas turning faster near the star; the cloud, its pattern and its one or
two motions rolled from the system's seed, and laid at the map's own angle.
The mockup's renderer (`PS`, from "Six Pulsars", with the map's settings
from `pulsarDraw`) is `pulsar.gdshader`; this node works out each moment's
frame -- where the beams point, how hard the star flashes, the sprinkler's
spray -- and hands it over.

Put it at the pulsar's centre, in whole map pixels. Call `setup` once per
system and `step` every frame with the BEAT time: the time the pulsar's
ambience is at, so a flash lands on what is heard (the mockup ran both off
one clock, `syncT(t) = t`).

ZOOM (`set_zoom`): the map zooms by having the pulsar REDRAWN bigger by its
own shaders, never stretched: at zoom k every length -- the star's glow, the
cloud and its pattern, the beams, jets, starquake ring, the sprinkler's
paths, the web's ring and its threads -- is k times as long about the
pulsar's centre, worked out over k times the game pixels. Zoom 1 is the
look Jon picked, pixel for pixel. The map pans by moving this node: the box
and the web follow `position` (drawn at it rounded to a whole pixel).

Also here, because they are keyed to the beam: the WEB of filaments round
the pulsar (`web`, a rect over the whole map; add it under the orbits, it
is placed and kept up to date from here), the remnant gas lit by the beam
(`set_gas`), and the map-wide sky flash (`sky_flash`, read by the screen).
```

## Box growth

Inside `set_zoom()`, above `if need.x > _half.x or need.x < _half.x - 72:`:

```text
HELD, GROWN IN STEPS OF 32 PX WITH ROOM TO SPARE (SIMPLIFIED's flicker pass):
every time the box changed size the pulsar was drawn a frame off its own
grid, the cloud round the beams flashing for one frame (7% of the map's
pixels at once, twice in a slow 10% zoom). Only a few more pixels are drawn
for it; the picture is the same, its pixels where they were.
```

## Beam brightness

Inside `step()`, above `bi = 1.5 * (1.0 + 0.55 * wb)`:

```text
(twice the beam and twice the flash, as first built, clipped a
band of the beam's glow to flat white, ~1,300 blocks, every
minute or so; half again keeps the beat landing harder)
```
