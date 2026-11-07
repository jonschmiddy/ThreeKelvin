The reasoning behind `tkg/scripts/ui/sysmap/SectorPainted.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Painted style

Above `const STATE_SH := preload("res://shaders/sector_b_state.gdshader")`:

```text
THE SECTOR MAP IN THE PAINTED STYLE: direction B of the Oct 5 showcase
(scratchpad `showcase/B/sector/`, "a pixel artist's hand"), drawn by
`SystemView` when the rendering style is PAINTED. Every pixel looks placed on
purpose: cel bands on curated hue-shifted ramps, 1-block checker transitions
between bands, outlines on the shadow side of big shapes and a rim of light
on their lit side, sparkle sprites, a band memory so band edges never
flicker -- and the life the other styles have, drawn as HAND ANIMATION:
held poses that step, slow, never a one-frame flash.

The far picture (the sky, the cloud round the system, the dust sheets, the
far weather) is SIMPLIFIED's, drawn into its own viewport, so the cloud is
the same cloud lit by the same sun, and every event of the weather lands
where SIMPLIFIED's does. Then it is painted: the band memory
(`sector_b_state`) gives every block one entry of the scene's curated palette
(bible 4.2: never cut), and the paint pass (`sector_b_paint`) finishes it as
an artist would. Everything nearer -- the sun, the worlds and their rings and
shadows, the belts, the hole, the pulsar -- paints itself in its own painted
mode, on the same tokens.

Three viewports, nested so each is drawn before the one that reads it: the
place picture > the band memory > the far picture.
```

## Band hold

Inside `push()`, above `var twin: bool = "home_zoom" in v and v.layout != null and v.layout.twin`:

```text
AND IT HOLDS NO BAND BEHIND A MOVING LIGHT (the sector map; LOCAL's sky,
which shares this, keeps the full hold): how far the sun's light moved this
frame, in blocks -- the sun's own slide, and on a zoom its light opening out
(`sky_nebula`'s light px go as zoom^0.42; its lit bands' edges lie some
LIGHT_R light px out) -- and the hold cut so a band edge trails it by about
a block (TRAIL_BLK), the full HOLD once it is still
(two suns, ruling 23: the pair turns, so the light moves as each sun creeps
round the balance point -- measured from both suns' exact places, the one
that moved further: a rounded place moves a whole block on the frame it hops
and none between, and the memory flushed and the bands flickered at every
hop. One sun: star A's drawn place, as it always was.)
```
