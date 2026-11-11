The reasoning behind `tkg/scripts/ui/jump/JumpSpecks.gd`; each heading is referenced from the code by a `Why:` line.

## Motes

R12's seventy dust motes are drawn into the world, before the stage's first copy, as whole
one- or two-pixel rects added over the sky. The world pass then sees them as sky: inside the
negative they come out as dark specks on the paper, which is what the film's did, with no
second code path for the motes' negative. Their places, brightness, drift and size are the
film's own rolls (r12.py, rng 1212), copied out, so they sit where Jon saw them.
