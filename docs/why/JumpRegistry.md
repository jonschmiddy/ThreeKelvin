The reasoning behind `tkg/scripts/ui/jump/JumpRegistry.gd`; each heading is referenced from the code by a `Why:` line.

## Pick

Jon, Nov 10 (the build plan's Q3): B, pure random with repeats allowed, not a shuffle bag. One
draw per jump from `Rng.derive(&"jump_film", jumps)`: positional, so a run's seed decides, a
save and load changes nothing, and no gameplay stream moves. Only landed films are in `ALL`;
each slice adds its two.

`-- jumpfilm=r4` forces a film for the harnesses and the captures (`JumpCine whole film=`),
read once from the command line.
