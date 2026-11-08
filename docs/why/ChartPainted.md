The reasoning behind `tkg/scripts/ui/ChartPainted.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Painted style

Above `const BAKE_SH := preload("res://shaders/chart_b_bake.gdshader")`:

```text
THE STAR CHART IN THE PAINTED STYLE: direction B of the Oct 5 showcase
(scratchpad `showcase/B/chart/`, "a pixel artist's hand"), drawn by `ChartSky`
when the rendering style is PAINTED. Every pixel looks placed on purpose:
cel-banded light from the core on curated hue-shifted ramps, 1-block checker
transitions between bands, outlines on the shadow side of big shapes and a
rim of light on their lit side, see-through gas as 25/50/75% patterns (never
alpha), sparkle sprites, and a band memory so band edges do not flicker.
It shares the simplified chart's view, anchoring and zoom hold (`ChartSky._push`),
its black hole (C's, `legacy_hole.gdshaderinc`) and its life -- the currents,
the knots, the supernova and its echo, the weather -- drawn here as hand
animation: held poses that step, slow, never a one-frame flash.

Four passes a frame, each one block a pixel: the sparkles (`chart_b_stars`),
the G-buffer (`chart_b_place`: what every block is and how lit), the band
memory (`chart_b_state`) and the paint (`chart_b_paint`). Baked once a galaxy:
the billow puff table (`chart_b_bake`, two 120 x 120 float textures, read back)
and the stars as data. The palette is curated, the same table the painted
sector map uses (bible 4.2): nothing is cut.
```

## Zoom hold

Inside `push()`, above `var zmove := absf(log(maxf(z, 1e-4) / maxf(float(pv[0]), 1e-4))) * vs.length() * 0.5`:

```text
AND WHAT A ZOOM CHANGES IS NOT HELD PAST IT: a zoom redraws the gas at a new
scale (its finest octaves fade in and out), so some bands truly change;
held through the zoom, they were let go in the second and a half after it
stopped, the cloud changing with nothing moving. The hold is cut by how far
the zoom moved the frame's edge this frame (blocks): a slow zoom -- the
flicker the memory is for, a third of a block a frame -- keeps about 30
frames of it, a turn of the wheel almost none, so what it changes changes
while it moves.
```

## Held poses

Above `static func feed_events(m: ShaderMaterial, g: Dictionary, t: float, phi: float, calm: bool) -> void:`:

```text
THE EVENTS AS HELD POSES, pure functions of t (the simplified chart's clocks,
`ChartSky._supernova` and `_lightning`'s schedules, drawn by hand):
  the supernova in four drawn frames (a spark, the full four-point star, a
  shorter one, a fading plus) and its light echo as a ring stepping out every
  1.5 s, in three strengths; a cloud's lightning as a bolt held for 0.35 s and
  its afterglow for 0.6 s; the glimmers and shafts stepping a notch every 2 s.
```
