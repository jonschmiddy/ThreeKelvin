The reasoning behind `tkg/scripts/ui/ChartRadiant.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Radiant style

Above `const NOISE_SH := preload("res://shaders/chart_r_bake_noise.gdshader")`:

```text
THE STAR CHART'S SKY IN THE RADIANT STYLE (`DisplaySettings.render_style`
`&"radiant"`, or a harness's `style=radiant`): direction A of the Oct 5
showcase, "Light through gas" (scratchpad `showcase/A/chart/`). The galaxy as
a true density volume lit by single scattering from the core, the arms' young
stars and the clouds' lamps; dust that reddens and stops light; god rays cut
through the haze by the billows; billows lit on the side facing the core and
in their own shade on the other; the near dust lane in silhouette over the
bulge. SIMPLIFIED's black hole (`legacy_hole`), lit as this style lights
things, and SIMPLIFIED's animations as light: the gas streaming through the
arms, knots that breathe as lamps, a supernova that lights the gas round it
and an echo of it sweeping through the dust, lightning that scatters through
its cloud. Jon: RADIANT is "for photos probably" -- it is the HEAVY style.

It runs on `ChartSky`'s own pipeline (its stars, its palette cut from hero
views, its composite and zoom hold), with its own bakes and place pass:
  * the BAKES, once a galaxy (once a session for the noise): a periodic 3D
    noise volume (`chart_r_bake_noise`), the face-on disc as two half-float
    maps (`chart_r_bake_disc`: star light, young light, H-alpha, dust; arm gas,
    billow height, blockers, core swirl), read back and mip-mapped, then the
    core's horizon map from them (`chart_r_bake_hor`, the god rays' shadows);
  * the PLACE pass (`chart_r_place`), a march down each block's view ray.
LOW (GRAPHICS LOW) marches no billows (one lit sheet), fewer steps, one phase.

THE SAFETY: if the sky's own GPU time over its first seconds says this
machine cannot hold it, the chart falls back to SIMPLIFIED with one line in
the log (`ChartSky._radiant_probe`).
```

## Safety budget

Above `const FALLBACK_MS := 6.0`:

```text
THE SAFETY'S BUDGET: the sky's own GPU time, ms a frame, averaged over its
first seconds of drawing; past it the chart falls back to SIMPLIFIED. An RTX
3070 measures 0.6-1.6 here; a machine at four times that is not one to show
photos on.
```

## March steps

Above `const STEPS := 11.0`:

```text
The slab's march: steps through it (halved near the plane), HIGH. The
showcase's 22 cost 2.5 ms a frame on a full-screen chart at zoom 1 on an RTX
3070; 16, with the start jittered, reads the same.
```

## Palette merge

Above `static var PAL_MERGE := 0.02`:

```text
How near (OKLab) a colour the palette's cut may add to one already kept;
SIMPLIFIED's is 0.06 (`ChartSky.pal_merge`). Measured on the nebula's slow
zoom: 0.06 left a fan of rose twins across the remnant's shell that flickered.
```

## Dither gates

Above `const DITH_GS := 0.5`:

```text
The composite's dither gates, against SIMPLIFIED's (`ChartSky.dith_gs`,
`dith_coh`). 1: the same; the colour hold (`ChartSky.hyst`) keeps the dither
from flickering, so it can carry the soft gradients light through gas makes
(2 and 1.25 had flattened them into plates).
```

## Galaxy look

Above `const STORY_GAIN_R := 1.0`:

```text
The galaxy's look: the showcase's per-kind numbers (set by eye for the
grand design, the barred spiral and the elliptical), generalised by shape and
by the galaxy's own bulge, gas and arms.
A BALL'S BODY AND HALO (Jon, Oct 18, "radiant:yes": the balls bloomed into a big orb
with a hard edge): the outer component's peak, and the halo's light, a ball is
lit by. The showcase's were 0.95 and 0.03.
A ball's story's light in this style's own (`ChartSky.ball_story`)
```

## Cloud lobes

Inside `cloud_uniforms()`, above `var cl0 := Vector2(main.x, main.y * FLAT)`:

```text
(an emission cloud's cluster at its biggest lobe, as the showcase's A had it.
It was moved 0.6 of the way in when the teal heart barely showed on the
Starburst Spiral, but the cause was the lobes: `feed_events` puts this
style's own back, which SIMPLIFIED's had been overwriting)
```

Inside `feed_events()`, above `if not g.has("r_lobe"):`:

```text
THE CLOUDS' OWN LOBES AGAIN. `ChartSky._feed_events` runs first, every frame
and for every palette probe, and sets the same `u_lobe` to SIMPLIFIED's: its
clouds sorted by where they sit on screen and their lobes turned into each
cloud's round frame. Read here, cloud k took another cloud's lobes, turned
-- so an emission cloud's gas lay off its own cluster and its teal heart
(the cavity round the cluster) sat at the thin edge of the wrong gas, or
outside it (the Starburst's ESO 101 shown as emission: a flat rose band
with a sliver of teal, where the showcase's A has a teal heart).
```

## Ball kinds

Above `static func ball_kind(p: Dictionary) -> Vector4:`:

```text
A BALL AS ITS OWN KIND in this style (Nov 5, Jon's direction A for PAINTED, "This
could also be applied for the other art styles"): each ball drawn as this style
draws a spiral -- smooth light from the middle, the gas lit by it -- shaped to its
kind. `u_ballK` (`chart_r_place`, `chart_r_bake_disc`): (its kind as `ChartSky.ball_of`
numbers it -- 0 an elliptical, 1 a blue compact dwarf, 2 a dwarf spheroidal, 3 a
merger's remnant; its young gas and star birth 0..1; how lopsided it is 0..1; its
halo of globular clusters 0..1). An elliptical old, warm and smooth; a blue compact
dwarf young, blue and lumpy with the spirals' pink knots; a dwarf spheroidal faint
and grey; a merger's remnant warm, a little lopsided, its tidal stream of gas
curling off one side with a few knots in it; a giant ringed by globular clusters.
```

## Ball body

Above `static func ball_form(p: Dictionary) -> Vector4:`:

```text
A BALL'S BODY in this style: (its size against its ball radius; where its light
starts to fade out and where it is gone, in its outer scale; its roundness, the
bulge's c/R). The three ellipticals told apart by more than their colour: a round
one the plain profile; a flattened one a lens, squashed and ending sooner; a giant
bigger, its light running out slowly into a wide envelope. A dwarf spheroidal
small and thin, a blue compact dwarf's light ending soon past its gas.
```

## Light that moves

Above `static var drama_on := true`:

```text
LIGHT THAT MOVES (Nov 7, direction B of Jon's "redo radiant to be super dramatic
with the lighting effects"): the drama is in time, and each light is a thing's. The
core's disc breathes, now and then flares (eased in, held, let go) and its light
reaches far further out through the gas; it throws its light two ways, turning,
so two bright sectors sweep round the core over the billows and the haze; young
stars in the arms flare for a breath and light the gas round them. (The turning
beams were cut in review the same day: they were the "light beams from the core"
Jon cut on Oct 11, and most of the frame's crawl.) Pure functions
of the clock (`GameClock` through the chart's own), so films run true. `drama_on`
false (a cost bench's turn) or `still` (reduced motion, a palette probe): all off.
```

## Dwarf halo

Above `L.halo = Vector4(L.halo.x * 1.3, L.halo.y, L.halo.z, 0.0)`:

```text
(its halo a light that falls off, Nov 7: the dwarf is small and dim, and over
A's ball grade its body's fall met the palette's darkest step at 0.34 gu and
stopped there, a rim -- BallHaloTest's fade 0.39 at rest. A halo 1.6x bright
carried the fall out but sat as a flat navy disc. Its halo's fall is longer
(1.3, not 1.7), ends from half its scale out, and dithers twice as hard across
the palette's last steps, so it thins into space: B: 1.3x bright, fade 0.49 at rest)
```

## Glow and colour

Above `const GLOW_HOLE := 1.35`:

```text
THE GLOW AND COLOUR (direction C, Nov 7, `RadiantGlow`): the chart's look of
it. Layered halos round everything bright, the core's rays through the dust,
deep violet shade.
(A+B+C, Nov 7: over A's hard light the glow blooms only the hottest gas -- `thr`
0.42 to 0.6, `gain` 1.6 to 1.2 -- and draws no rays: A's core is big and hot, so
the bright buffer summed along the line to it was near even over the whole inner
disc and its steps laid one flat tan plate, dithered at its edge, over the core
(and a hard-rimmed orb round every ball). A's god rays, in the volume and shadowed
by the billows, are the rays here. No `crush` (was 0.6): A's grade is the one tone
step, and the two stacked sank the arms' faint gas twice.)
the hole's shadow as the glow spares it, in its radii
```

## Ball toe near

Above `const BALL_TOE_NEAR := 0.15`:

```text
...AND COMING IN (A+B+C review, Nov 7): from the opening to LOCAL REGION's zoom the
toe rises to A's own (`BALL_TOE_NEAR`), over `BALL_TOE_Z` (the chart's zoom against
its opening's 0.42). Seen whole, a ball must fade softly into space (BallHaloTest,
at the opening); come in close, it fills the frame, and at the opening's toe its
outskirts lay one amber-violet haze over every corner -- 2% of the frame under 15
against A's 28%, the far galaxies and the field stars gone. At A's toe they fall
to black and the sky behind shows through again.
```

## Ball drama

Above `const DRAMA_BALL := Vector2(0.004, 2.1)`:

```text
A BALL's (toe, gain): a ball is all starlight, one smooth hill of it with no gas
for a lamp to light, so its drama is the hill made steep -- the nucleus burning
white round the hole, the body falling off fast into black
(A+B+C: toe 0.15 -> 0.004 and gain 2.4 -> 2.1. At 0.15 the faint outskirts went as
the square of their light and four ball kinds ended in a hard rim (BallHaloTest's
fade under 0.42; the blue compact dwarf at 0.28). Near no toe the ball's drama is
its nucleus burning white and its body still falling into black; 2.1 keeps a
merger's story within the test's cream budget.)
```

## Chiaroscuro

Above `const DRAMA := Vector4(0.18, 2.0, 0.25, 2.2)`:

```text
CHIAROSCURO (proto/radiant-a, Nov 7; Jon: "redo radiant to be super dramatic
with the lighting effects"): one dominant light, the core, and what it does
not reach falling to black. VIB was 0.35. (A soft wash before: no render had
more than 2.2% of its pixels over 200; now the light's gain after the toe takes
the hot gas past BURN, so it burns to white, the hole's disc kept exact.)
(A+B+C: C's burn 2.0 and exposure 1.1 not taken -- over this gain they burnt the
core to one white plate; C's glow is the bloom, B's flares the moments of white.)
`u_drama`: (the toe, light under it crushed toward black; the core's light gain;
the arms' own young light, a share; the god-ray haze's gain, was 0.35).
`u_dramaR`: (the core light's reach, a factor on its falloff's scale; the
billows' lit side, a gain; the light's gain after the toe; the billows' shade
fill, a share). The god rays' shadows at full strength (`u_gr`, was 0.45), no
ambient (`u_amb`, was a navy 0.02).
```
