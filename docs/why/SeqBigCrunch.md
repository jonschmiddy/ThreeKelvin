The reasoning behind `tkg/scripts/ui/jump/SeqBigCrunch.gd` and `tkg/shaders/jump/jump_r14*.gdshader`; each heading is referenced from the code by a `Why:` line.

## Big crunch

R14 BIG CRUNCH as Jon approved it (round 3, Nov 10), ported from
`tk-scratch/jump-drive/round3/_r14/r14.py`, with the louder-pops mix. The clock is the film's:
the slam 0.40, fourteen gulps to 4.33, the sky empty at 4.5, four crunch beats from 4.62,
silence and the held point from 5.62, the burst 6.30, the commit at 8.8. The stand-in takes
the hull at 0.25, before the slam lights it.

The sink is the hull's ink centroid on screen (`JumpPlace.centroid`), not its box's middle,
as the film's was.

## Pour

Every pixel at distance r from the sink shows the world from further out along its ray,
`R0 = sqrt(r^2 + A^2) + B`, at six (A, B) pairs over the last 1/14 s for the smear. Where R0
lands past the window there is no sky left and the pixel is void, so space goes black from
every edge at once and the side nearest the ship empties first. The pass samples the whole
LOCAL view behind the stage, so suns, worlds, stations and comets pour for free; the HUD and
the goal line are drawn after the view and never pour.

The film's sky was a capture with the GOAL readout baked into it under its HUD box, and the
film patched that out of the art so the pour could not drag it. In the game the goal line is a
live Control drawn after EncounterView, not part of the picture the stage copies, so there is
nothing to patch: it stays where it is over the void, as the film's did.

## Stars

The sky's own stars are found once, on the GPU, from LOCAL's 480x270 sky picture (a peak 12
levels over the ring round it, not part of a bright blob), read back two frames in and
scanned a few rows a frame into `JumpSparkQuads`, so at rest each sits exactly on its sky
pixel. The film's 1,700 field stars (its rng 1414) are seen only while space moves; a tenth
of them pass in front of the hull.

## Compose

A second full-frame pass over the poured sky and the far streaks: the torn edge as light
(angular noise and three slow lobes), the aura from the hull's baked SDF, the white ball with
its inward threads, rim and violet halo, the hull darkened against it and crushed with it
about the sink by area sampling, the beats' pressure rings, the held point with its four
spikes, the slam's flare, and the burst's shock rings and ember. The near streaks and the
burst sparks are drawn over it.
