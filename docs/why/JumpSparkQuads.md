The reasoning behind `tkg/scripts/ui/jump/JumpSparkQuads.gd` and `tkg/shaders/jump/jump_spark_quads.gdshader`; each heading is referenced from the code by a `Why:` line.

## Quads

R14's star streaks (the sky's own stars, found once, and the film's 1,700 field stars), its
burst sparks, and R10's ring sparks are thousands of short lines whose every position is a
closed form of the clock and a few rolled numbers. One MultiMesh per layer holds a unit quad
per line, its rolled numbers in the instance colour and custom data, and the vertex shader
stretches the quad from this instant's head to its tail on whole pixels. Nothing is moved
from GDScript per frame: the film sets a handful of uniforms (t, the pour's A and B now and
0.14 s ago, the burst's clock), so 2,600 streaks cost the same as one.

The name is slice 3's: slice 2 (R1, R5) built its own `JumpStars` and `JumpLines` at the same
time. When the films land together these can fold into one helper; the forms here are R10's
and R14's and stay with their films.

## Shader

Mode 0 is R14's stars: in the pour a star at rest radius R0 shows at
`r = sqrt((R0 - B)^2 - A^2)` along its ray from the sink and streaks back to where it was
0.14 s ago, hotter the faster it falls; the sky's own stars add only their heat and tail,
since the poured sky already shows the star. In the burst the field stars ride out behind the
shock front and spring about home (7% overshoot, damped). Mode 1 is the burst's sparks: thrown
from the point with drag, fading, never blinking. Mode 2 is R10's sparks: a white pixel with
a magenta plus when bright, flickering on a held 10 fps.
