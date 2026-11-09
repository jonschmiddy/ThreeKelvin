The reasoning behind `tkg/scripts/ui/planets/Worlds.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Worlds

Above `const RAMP_ORDER := [`:

```text
THE WORLDS: every kind of planet the system map draws, what it is made of
and how it is lit, and each world's lasting facts from one seed.

A port of the approved mockup's planet painter (the scratchpad's
`sysmap/planets.js`, "Thirty-Four Worlds"). The painting itself is
`planet.gdshader`; this holds what the shader is told: the colour ramps (one
texture), what each kind of world has (air, caps, clouds, rings, storms,
lights), and `spec()`, which rolls a world's spin, tilt, craters, storms and
the rest from its seed exactly as the mockup did -- the same generator, the
same order of draws -- so a world here is the world Jon approved there.
```
