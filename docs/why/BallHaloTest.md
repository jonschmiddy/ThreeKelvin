The reasoning behind `tkg/scripts/sim/BallHaloTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Ball halo

Above `const REACH_T := 6.0`:

```text
A BALL GALAXY ENDS AS FAR BELOW ITS CORE AS ABOVE IT, in every style that
draws one as a ball:
  godot --path . -- sheet=BallHaloTest [styles=simplified,painted,...] [shots=<dir>]

Jon, Oct 18 (STARCHART, PGC 6236 "The Drowned Coil", a giant elliptical):
"Galaxies like giant elliptical seem to have an issue where they extend
forever downward in painted and simplified rendering modes." The solid
galaxy's camera (`ChartSky.solid`) sees the disc's plane in perspective, its
near half nearer and bigger; SIMPLIFIED's `ellBall` and PAINTED's ball read
their light on that plane, so the camera stretched the ball's near half down
past the chart's bottom edge (the plane below the core runs out to the
camera's horizon, 2.38 gu out, before the ball's light does) and crushed its
far half up against the horizon: 0.47 gu of light above the core, the whole
chart below it. A ball is drawn about the core in the core's own frame now,
as the bulge is, round on the screen as the flat chart drew it.

For each style and each ball kind (Jon's own galaxy, seed 884043030 as rolled,
then the six ball kinds forced on that seed: its far sky is clear round the
core, where seed 4242's has a far cloud below it that a measure down the line
reads as the ball), the sky alone at the chart's opening zoom with the core in
the middle; down a vertical line through the core (each row the median of 81
px, so stars are ignored), the light over the void's own level:
  reach  how far out from the core the light stands REACH_T over the void
         without a break, above and below, out to the nearer frame edge
         ("edge": it was still lit there);
  asym   (below - above) / (below + above) of that light, summed out to the
         farther reach: 0 for a ball lit evenly round its core.
FAILS a ball whose reach below is more than REACH_MAX times its reach above
(or the other way) or whose |asym| is over ASYM_MAX. The old shader: SIMPLIFIED
1.72x and PAINTED 1.88x on Jon's galaxy, both still lit at the frame's bottom.
A spiral and a lenticular are printed for comparison and never fail: they are
discs, and a disc's near half IS bigger through the camera.
(LEGACY was judged too, by reach alone, until that style went on Nov 7.)
AND THE FRAME: LOCAL REGION's frame (`MapChart.frame_region`) of every galaxy, a
ball's as a spiral's, is the systems near you (Jon, Oct 21, for 0.3.0; his
"frame:A" of Oct 18 framed a ball whole, its core and lit radius, so L went from
0.42 to about 0.55 and read as doing nothing): from YOU and from the rim, every
system within the region's span and YOU in view, the zoom at least REGION_ZOOM.
A ball's depth (`ChartSky.ball_depth`): the game's look C unless `balllook=0|A|B`:
lit as a ball it is brighter on its upper left, but it must still END as far out
on its shaded side as on its lit one, so every look passes this as today's does.
Needs a window (it reads the drawn sky).
```

## Ball fade

Above `const FADE_MIN := 0.42`:

```text
A BALL FADES INTO SPACE (Jon, Oct 18, "radiant:yes": RADIANT's balls bloomed into a
big orb with a hard edge). `fade`: the share of the ball's reach its light takes to
go from 0.4 of its light at 0.1 gu out to nothing -- a hard-rimmed orb holds its
light and drops it at once. RADIANT's before: 0.24 to 0.40 (PGC 6236 0.26); after,
0.45 to 0.54; SIMPLIFIED's 0.49 to 0.67, PAINTED's 0.42 to 0.59. Judged in RADIANT
(its balls alone: every RADIANT ball before failed it), printed for every style.
```

## Chart sky

Inside `_ready()`, above `NavField.harness_off = true`:

```text
THE CHART'S OWN SKY, NOT THE FIELD THROUGH IT (Oct 18): since the chart's empty
sky lets the shared field through (`NavField`: its stars, far galaxies and the
system's own cloud) and fades what it holds out over its last 24 px, a ball's
light read off the screen took the field's cloud for the ball (PAINTED "lit to
the top edge") and the edge's fade for a hard rim (RADIANT's fade 0.35-0.42). The
ball is judged on the chart as it stands without the field, its own sky behind it.
(Subtracting the field instead took it off where the galaxy covers it too.)
```

## Radiant at rest

Above `ChartRadiant.drama_on = false`:

```text
RADIANT'S LIGHT THAT MOVES HELD OFF (Nov 7): its core's breath and flares and the
young stars' flares (`ChartRadiant.drama_on`, the cost bench's switch) are moments
on top of the ball's light; one lit at the test's clock had hidden the blue compact
dwarf's hard rim (0.43 with a core flare at 600, 0.39 at rest). The ball is judged
as it stands at rest, at any clock. `clock=T` (default 600) reads the chart at
another clock, and every clock must pass.
```
