The reasoning behind `tkg/scripts/ui/jump/JumpStars.gd` and `tkg/shaders/jump/jump_star_detect.gdshader`; each heading is referenced from the code by a `Why:` line.

## Lift

The game has no star list: LOCAL's stars are drawn by `shaders/local_far.gdshader` into the
sky's SubViewport. The films that move stars (R1 now; R8 and R14 in the plan) need each one
as a thing, so the stars are lifted once, a few frames into the film, off the game's own
frame as it was drawn:

- `jump_star_detect.gdshader` marks a pixel a star the way the films' Python did: brighter
  than the mean of its 5x5 ring by 12/255 (the ring skips the 3x3, so a 2x2 star's own block
  does not count against it), the peak of its 3x3, inside the window by 4 px and off the
  hull's ink. It is drawn once into a SubViewport and read back.
- `poll()` reads the marks and drops clusters as the film's BLOB did: a standing-out pixel
  with more than five others in its 7x7 is dense, and a star within 6 px of a dense pixel is
  not a star (stations, comets, trails, the goal line). Counting only the peaks missed the
  comet, a solid bright sprite with few peaks, and tore it into thick streaks. The brightest
  3000 are kept. Each kept star has its
  light over the bare sky (the per-channel median of the eight pixels three off it), its
  brightness (the films' STAR_B: its brightest channel over 120/255, 0.08 to 1.6) and a lag
  rolled per star.
- The mask is the bare sky under each lifted star and its 3x3, its alpha carrying the lag, so
  the world pass can paint the star's home bare while the star is a streak and know where
  its streak is without a second texture.
- `add_faint(n)` adds the stars the sky never drew: R1's 1500 faint extras that fade in with
  the stretch, hashed (the film used numpy's rolls) so they are the same for a window every
  jump.

A 2x2 star is four stars, as it was in the films' frames. Headless there is no frame to
read, so nothing is lifted and the film plays without moving stars.

The image read (`get_image`) happens once, in the film's settled opening (0.1 s), never on
an act.
