The reasoning behind `tkg/scripts/ui/jump/JumpPlace.gd`; each heading is referenced from the code by a `Why:` line.

## Place

The films were drawn over one LOCAL: the Korvan medium hull at x90 y232, 236x93, in a 960x540
frame, with 622 px between its nose and the window's right edge. The game's LOCAL measured the
same ship at x89 y232, 241x90, with 622 px of room (the spike, Nov 10), so on this hull the
films land where they were drawn.

Another hull is another size, and a co-op convoy pad moves the ship about 240 px right. The
rule is the plan's: scale space, never time. Distances ahead of the nose (R4's vanishing
point, 446 px out) scale by the room this LOCAL has against the film's; distances measured in
hull lengths scale by the hull's length against the film's, clamped 0.7 to 1.3. The clock never
moves, so the sound stays true to the picture.

The drive sits 26% in from the tail and 56% down the hull on every film (r12.py's `CORE`);
the collapse point is the ink's centre.
