The reasoning behind `RadiantGlow`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Radiant glow

```text
RADIANT'S GLOW AND COLOUR (direction C, Nov 7; Jon: "redo radiant to be super
dramatic with the lighting effects"). One pass over a finished, palette-cut
picture, at its own 2x2 blocks: what is bright glows in layered halos of its
own colour, cut into flat steps with a dithered band at each edge; the key
light's rays stream out through gaps in the dust; the darks go deep and
coloured, never grey. The same pass on the chart, the sector map and LOCAL.

A glow viewport WRAPS the picture's own viewport (`wrap`): the picture is
drawn as a child, so it is drawn first each frame, then
  1. `radiant_bright`: what of it glows, alone;
  2. a back buffer copy, whose blurred levels are the halos;
  3. `radiant_glow`: the picture, its shade, and the glow in steps.
Nothing of it is built in any other style.
```
