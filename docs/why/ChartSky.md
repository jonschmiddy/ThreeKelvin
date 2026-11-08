The reasoning behind `tkg/scripts/ui/ChartSky.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Chart sky design

Above `const TILT := 0.38`:

```text
THE STAR CHART'S SKY IN THE SIMPLIFIED STYLE: direction C, "Alive", from the
Oct 5 showcase (scratchpad `showcase/C/chart/`), THE DEFAULT of the rendering
styles (`DisplaySettings.render_style`). PAINTED draws with `ChartPainted`'s
passes on this node, RADIANT with `ChartRadiant`'s. The chart's own layered
look refined and set in slow motion: an arm-model disc
and a cored bulge as gathered light, crisp dust lanes, sparse stars, four
depth sheets you wade through as you zoom, gas streaming along the arms,
knots that breathe and bloom, a rare supernova and its light echo, nebulae
in the arms with weather of their own, and C's black hole at the core
(`LegacyHole`). Everything a MapChart draws behind its systems is drawn here;
the systems, routes, rings, labels and the ship stay the chart's own marks.

TWO HALVES.
  * ONCE A GALAXY (`_begin_bake` and the stages after it, on a node of its
    own so a bake finishes even if the chart that asked closes): two bakes on
    the GPU, read back and mip-mapped -- generic noise fields and this
    galaxy's arm structure, face-on (`chart_c_bake`); the chart's own star
    field cut down to the stars bright enough to be seen one at a time, as
    data textures; the knots on the arms; then THE PALETTE, cut once for the
    galaxy and never swapped while you move: the place pass rendered at the
    hero views unquantised, read back, and a k-means in OKLab on another
    thread anchored by fixed ramps for the key hues, the hole's bands and the
    event colours; and its lookup, on the GPU (`chart_c_lut`).
  * EVERY FRAME, three viewports at half the chart's size, so each of their
    pixels is one 2x2 block: the stars splatted into a light buffer
    (`chart_c_stars`), the place pass (`chart_c_place`, every block worked out
    afresh, so a zoom redraws and nothing is stretched), and the composite
    (`chart_c_comp`: toned, then the palette, dithered only on gradients).
    The blocks are anchored to the galaxy's centre on a whole pixel, so a pan
    moves the picture in whole blocks and the dither moves with it.

Every animated thing is a pure function of the chart's clock
(`MapChart.clock`): the turn, the currents, the knots' breathing, the
supernovae, the weather, the hole's spin. Reduced motion turns the events off
and halves the drift.

THE TURN. The galaxy turns as one, once every `TURN_MINUTES`, a view-only
angle (`MapChart.turn`): systems, routes and rings turn with it.
```

## Palette size

Above `static var pal_merge := 0.03`:

```text
THE PALETTE'S SIZE, which is much of the zoom's flicker: two near colours
dithered or swapped at a block are a flip each time the zoom moves the
gradient past them. The fixed ramps are kept whole (only exact twins go);
`pal_merge` is how near (OKLab) a colour the cut finds may sit to one already
kept before it is dropped, `pal_free` how many the cut adds. Measured on the
grand-design's slow zooms (flip_back_mean, budget 0.0035): the showcase's
0.03 / 12 with its dither gating gave core 0.0051, hole 0.0069; 0.06 / 10
with the stricter gating below, 0.0030 / 0.0035.
Tuning: `-- sheet=ChartLook palmerge=M palfree=N`.
```

## Zoom diagnostics

Above `static var diag := 0`:

```text
WHAT A ZOOM CHANGES, switched off one cause at a time (tuning, `diag=N` in
ChartLook; 0 as made): 1 the core's glare control, 2 every star (the chart's
and those the disc resolves into), 4 the detail the zoom adds (octaves, fine
grain, the bakes' mip held at zoom 1's), (8 was the gone LEGACY style's
palette), 16 the chart's own stars only, 32 the resolved stars only, (64 was
LEGACY's dust sheets), 128 the hole's own
zoom terms (the squeezed ring's cooling, the disc's clumps), 256 the resolved
stars adding their light on top as before, 512 no stars' light laid back
(`_star_debt`), 1024 the hole's cooling as far out as before, 2048 no supernova
remnants (`remnants`; to measure what they cost).
```

## Solid galaxy

Above `const SOLID_D := 2.2`:

```text
THE SOLID GALAXY (Oct 12; Jon's idea 21 from the "magnificent" list: "I don't want
the galaxies to look like they are flat?"). The galaxy was a flat picture tilted
like a poster, so anything floating round it still read as a poster. So in
SIMPLIFIED the chart is seen through a real camera (`chart_c_place`'s solid
section): the near half of the disc nearer and bigger, the far half smaller and
squashed; the core bulging out of the disc. ONE projection for the sky and for
every mark the chart draws over it (`solid_fwd`, `solid_inv`; `StarchartScreen`'s
`_proj` and `_to_plane` call them). The camera never turns: a drag slides the
picture as the flat chart's does, and a zoom only magnifies it (Jon, Oct 12: "no
tilt while dragging". A drag that carried the camera over the disc re-drew every
pixel from a new angle every frame, and every style shimmered.)
The camera at Jon's "moderate": 2.2 gu away, at the sector map's tilt, looking at
the core (the near rim drawn 1.7 times the middle, the far 0.7).
```

Above `const FLUFF := Vector2(1.6, 1.25)`:

```text
THE SOLID LOOK'S PARTS, all on in SIMPLIFIED (Jon approved them Oct 12: "THIS IS
PERFECT"); the other styles draw the flat chart. Each one's own section in
`chart_c_place` says what it is:
  * the gas with a body (`fluff`): round puffs lit from the core, standing up
    toward the camera (how strongly lit and how tall, how big the puffs);
  * the edge dissolving (`edge`): the outer disc thins over a long stretch into
    black space (where the fade starts gu, where it ends gu, how uneven gu);
  * the middle's relief (`terrain`): hills and valleys of dust lit from the core,
    their shadows cast outward (how much);
  * the nebulae's bodies (`nebulae`): the shells piled up at the rim with the
    oxygen's glow hugging its inside, the emission puffy, the dark ones mounds.
Their statics switch each off only for the cost bench (`ChartLook`'s costbench).
A harness's `chartflat` draws SIMPLIFIED flat, as before all this (a "before" to
film against).
```

Above `const SOLID_STYLES := {&"simplified": true, &"radiant": true, &"painted": true}`:

```text
WHICH STYLES DRAW THE SOLID LOOK. Each style's port turns its own line on in its
own branch (its place pass wired to `chart_solid.gdshaderinc`); everything that
follows from it -- the camera, the marks' projection, the
stars pass, the uniforms pushed -- reads `solid()` and needs nothing else. A
harness's `solidstyle=<style>[,<style>...]` turns styles on for filming before
their line does.
```

## Zoom hold

Above `var _last_zoom := -1.0`:

```text
THE ZOOM'S HOLD (the showcase's fix for zoom shimmer). The blocks are anchored
to the galaxy's centre on a whole pixel, and during a zoom off the centre that
whole pixel re-rounds every frame, jittering the picture by up to half a block
(measured: 0.116 of pixels flipping back on a slow zoom at a nebula). So while
the zoom changes, and for about a second after (an eased wheel zoom has gaps),
the place is sampled at the exact centre and the dither holds still on the
screen; then it settles onto the snapped grid over two frames.
```

## Shader warm up

Above `static var _warmed := false`:

```text
THE SHADERS COMPILED ON THE FIRST FRAME, which the boot splash still covers.
A fresh profile has no shader cache, and the place pass takes a second or
more to compile (1.7 s on an RTX 3070, measured with the cache bypassed;
6.1 s before its layers were each inlined once), so the title's galaxy --
the first thing a player sees -- was a black screen for that long. Drawn
here once, off screen, in the formats the bake and the frame use, from the
first ChartSky made (the title's), and thrown away.
```

## Machine pick

Above `func _gfx_step(delta: float) -> void:`:

```text
THE MACHINE'S PICK, a frame of it: on the title (whose galaxy is not the
run's), while nobody has set GRAPHICS, its sky's GPU time over its first
seconds, scaled to a full screen's, and the frames' length on the wall clock
(where the GPU reads 0: a Mac); then the pick (`GpuProbe.conclude`), and the
picked pass compiled if it changed. Only frames drawn with the window in
front count on the wall clock (a covered window is slowed by the system, not
by the sky), and none under a frame cap that would hide the machine.
```

## Ball depth

Above `const BALL_LOOK := 3`:

```text
A BALL'S DEPTH, three looks to compare (Jon, Oct 18: "Why do giant elliptical
galaxies look so much flatter than all the other galaxies?" -- a ball had only its
smooth glow and a broad mottle, none of the layers that give a spiral its body):
  0 today's ball;
  A (1) lit as a ball: a bright side toward the chart's key light (upper left, the
    painted style's `ballForm` light), a shaded side away, the light falling off
    toward the rim (limb darkening), so it reads as a sphere standing in space;
  B (2) the structure real ones have: a dust lane across SOME of them (seeded
    off the galaxy), faint shells of swallowed galaxies, a scatter of globular
    clusters round it, lumpier star clouds in its body;
  C (3) A and B together -- THE GAME'S (Jon picked it, Oct 18: "Galaxy depth: look:C
    lane:both", the lane in SIMPLIFIED and PAINTED alike).
`-- balllook=0|A|B|C` draws another (a harness's, in memory: 0 is the ball before,
for a before and an after); `balllane=0|1` forces the lane off or on, to show it.
Read by SIMPLIFIED's `ellBall` and PAINTED's ball.
```

## Headless bake

Above `static var stand_in_bake := false`:

```text
A HEADLESS HARNESS'S BAKE (`-- menutest`, the machine's pick on the real
title): headless never bakes, because the dummy renderer reads nothing back
and draws no frames to wait on, so the sky never built its viewports and the
title's pick could never be driven without a window. With this on, the CPU's
share is the real bake's and the GPU's four products (noise, structure,
palette, lookup) are blank stand-ins, ready at once; the sky then builds,
pushes and measures as it does in the game. SIMPLIFIED only. Never in the game.
```

## Star light debt

Above `const DEBT_N := 48`:

```text
THE STARS' LIGHT IS KEPT AS YOU ZOOM (Oct 11; Jon: the zoom "still changes a
little"). A star is one block, whatever the zoom, so the galaxy it covers
shrinks as you zoom in and its share of a patch's light with it: a patch of
the arms darkened 0.7 from zoom 1 to 4.5 as its stars went from blocks to
points. What the chart's stars no longer bring a patch, against what they
brought it at the opening, is laid back into the patch as the diffuse light of
stars too faint to see one by one (`chart_c_place`'s `starDebt`). This is the
stars' light a plane area at each of a run of zooms (each `chart_c_stars`
shows as that shader shows it, times the plane area of a block at that zoom,
less the 1 / zoom^2 the shader puts back), in a grid over the plane, the
zooms side by side.
```

## Void darkest

Inside `_ramp()`, above `if even and L2.x < ChartSky._oklab(fixed[0]).x:`:

```text
NOTHING BELOW THE VOID (the radiant cut, which weighs every colour
alike): it found the shadow's pure black and kept it beside the void's
navy-black, and the hole's middle -- light 0, exactly between the two
once toned -- flipped from one to the other and back as the zoom moved
(a third of the hole's blocks, Oct 10 polish). The void is the darkest
colour, as in every other style.
```

## Supernova remnants

Above `const REMNANT_N := 10`:

```text
WHAT A SUPERNOVA LEAVES (Jon's idea 18 from the "magnificent" list, kept Oct
12): the last ten minutes' supernovae, on `_supernova`'s own schedule and among
the same stars, each a remnant that every style draws as its own -- a ragged
shell that grows fast at first and slower after and fades out over the ten
minutes. (count, then (plane x, y, age s, seed) each, ten at most.) None under
reduced motion, which has no supernovae.
```

## Whole block panning

Inside `_push()`, above `if zw <= 0.0:`:

```text
PAINTED MOVES IN WHOLE BLOCKS. Its far sky (the little galaxies, the tiered
stars, the wisps) slides by its own depth, far slower than the galaxy, and is
drawn on the same grid of 2x2 blocks; a grid that followed the galaxy's
centre pixel by pixel swapped parity on every pixel of a pan, and each far
block hopped a pixel to and fro (0.0063 of the pixels flipping back on a
slow pan at zoom 4). The galaxy is set on the even pixel nearest its centre
instead, so a pan moves it a block at a time and the far sky only ever
steps one way.
EVERY STYLE, NOT ONLY PAINTED (Oct 13; Jon, on SIMPLIFIED's and RADIANT's
chart: "jitter in the background stars ... like they're almost bouncing around
as you pan"). Their far stars are drawn on the same 2x2 grid, and with the grid
following the galaxy's centre pixel by pixel a far star could not slide at a
fraction of the pan without hopping a pixel back every other pixel: measured on
a slow steady drag at Jon's framing (`tour=skypan`), 0.82 back-steps a star a
second in SIMPLIFIED and 0.34 in RADIANT, against PAINTED's 0.05. The galaxy
moves a whole block of its own art at a time instead.
```

## Block hold

Inside `_push()`, above `var fd := Engine.get_process_frames()`:

```text
the blocks' anchor moved by whole blocks on a pan: where each was last frame
(not across a jump of the view: a block's colour from another place is no
colour to hold)
AGAINST THE LAST FRAME DRAWN, not the last push: a moving view pushes twice
a frame (`_process`, then the chart's `queue_push`), and measured against the
first push of the same frame the shift came out 0 -- each block was held to
the colour of whatever stood there on the screen a frame before, so a pan
dragged the colours with the screen instead of the galaxy (Oct 10 polish)
```

## Radiant safety

Above `func _radiant_safety() -> void:`:

```text
RADIANT'S SAFETY: it is the heavy style ("for photos probably", Jon). Over its
first seconds of drawing the sky's own viewports' GPU time is averaged; if
this machine cannot hold it (`ChartRadiant.FALLBACK_MS`), the chart falls
back to SIMPLIFIED from its next build (this one keeps its look), with one
line in the log. A harness's `style=radiant` is never overruled (it is
measuring) unless it asks with `radiantprobe=MS`. (The measure is every
style's now, `GpuProbe`: the same one picks GRAPHICS on the title.)
NOT BEFORE THE MACHINE'S PICK. On a RADIANT profile where nobody set
GRAPHICS, the title's sky is measured for the pick too, and both read the same
HIGH frames: the safety gave up on RADIANT (SIMPLIFIED, saved) as the pick
turned LOW on, so the player lost RADIANT that LOW may have held. So the title
waits while the pick is to come, and no picture judges a pass it is only
holding (`DisplaySettings.low_held`): RADIANT is judged on the pass it will
be drawn with, at the next chart built.
```
