The reasoning behind `tkg/scripts/ui/YardLight.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Yard light

Above `const LW := 766`:

```text
One level's light in the Yard: the lamps `tools/yard_install.py` baked, the
clocks they burn on, and the few questions about the light that are asked
off the GPU.

THE PAGE IS THE REFERENCE. The Yard Drones page (v46, the artifact Jon passed
the Yard on) lights its hall in `lightWeights`, `syncStatic` and
`shadeRange`; every function here names the one it ports. The pools were
worked out ahead of time and live in the level's `.lmap` files -- what moves
is how hard each light burns this tick, and that is all this hands the
shader (`yard_light.gdshader`, four materials of it).

THE CLOCKS ARE THE PAGE'S, LINE FOR LINE: a bulb with a bad contact buzzing,
a loose one blinking, unclaimed's bad bulb popping in a shower of sparks,
neon stuttering, gold breathing, the tired lamp over the crane striking back
on. A beat changes a light's own pixels; only a light that really goes out
takes its pool with it ("pulses dim bands, never move them").

Asked off the GPU: the light at a point, for what is drawn after the light
(the drones take the light over the ships' row, the flyers the hall's light
as a whole, the deal TV the light at its feet) and for the dust, which shows
only where a cone is bright.
```
