The reasoning behind `tkg/scripts/ui/LocalDust.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Local dust

Above `const SH := preload("res://shaders/local_dust.gdshader")`:

```text
LOCAL'S FOREGROUND DUST (Jon: "can we add some dust to the local? something
in the more frontal layer?"; of the first take, "it kinda pops in and out and
looks low res"; and of the second, with the chart and the map, "dust
disappearing, dust looking flat and not visually interesting"): dust drifting
between the camera and the fight, the nearest layers of all, in front of the
ships -- and held to one rule above the look of it: it never covers a ship, a
shot's line, a damage number, an intent or a name.

DEPTH: five kinds of dust at their own distances, each with its own size,
speed and slide with the camera (`LAYERS`) -- far specks a pixel across,
crawling and sliding least; motes of gathered light; near motes, bigger and
softer, faster; a few out-of-focus discs right in front of the lens, faint
and quick; and now and then a thread of dust (a filament) or a knot of grains
(a clump) drifting through at middle distance. The nearer, the faster it
drifts and the further it slides when the camera moves.

LIGHT: each is gathered light added over the sky (`local_dust.gdshader`), lit
from the system's own star -- brighter on its side toward the star, brighter
the nearer it hangs in front of the star in the picture (dust scatters the
light that comes past it toward you), its core the star's colour. Now and then
a mote turns and GLINTS: its core flares and a short cross of light grows from
it, over most of a second, eased, never a flash.

ZOOM ONLY ADDS DETAIL (Jon: "zooming in causes artifacts like pixels missing
... dust disappearing, dust looking flat"): the dust is drawn per GAME PIXEL
whatever its own scale. Under the cutaway's push-in and the zoom ladder the
scene scales this control; the dust takes that scale out and draws each mote
again where the zoom puts it and at the size it puts it -- the nearer, the
more it grows (`s^(1 + DEPTH_ZOOM * z)`), so the dust parts round the camera as
it pushes in -- a speck growing a falloff, a mote a soft rim. Pulled back
below LOCAL's own scale (the map's zoom, 2C) it fades out, as the map has no
dust.

NOTHING POPS: a mote's visibility (`vis`) eases toward what its place allows
-- fading out over a ship's margin, the shots' band or the view's top edge,
in over the clear sky -- a step of its dither at a time (`FADE_IN`,
`FADE_OUT` a second), worked out every frame; the motes wrap round a strip
wider than the view, so they come and go off screen; and a mote's place, its
light and its glint each move on only once they have moved a whole step past
where they were shown (hysteresis), so none of them goes A, B, A. Inside a
ship's picture, a label or a gauge no pixel of dust is ever drawn (`keep`, a
last guard). `LocalShot dustcheck` measures what it covers and how fast it
fades; `dustonly` films it alone.

BY STYLE: SIMPLIFIED light in dithered steps; PAINTED flat hand-picked steps,
a held highlight at each mote's middle, the motes moved in held poses (eight a
second); RADIANT the star's light spilling softly round each mote.
```

Inside `_process()`, above `var sx: float = m.sx`:

```text
ITS PLACE, held until it has moved a whole step on (whole px, centres),
and held at least two frames once moved: a mote with any texture (a
disc's lit rim, a clump's grains) that stepped a pixel EVERY frame showed
each pixel under it a different part of it each frame, A, B, A -- read
as shimmer. A near mote faster than that steps two px at once instead.
(Not under a zoom or a fast camera: then it goes where it is carried.)
```
