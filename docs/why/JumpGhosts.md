The reasoning behind `tkg/scripts/ui/jump/JumpGhosts.gd` and `tkg/shaders/jump/jump_ghost.gdshader`; each heading is referenced from the code by a `Why:` line.

## Ghosts

R5's 64 probable ships are each the hull drawn as light: its outline (the 1 px edge, 0.95,
and the 2 px edge, 0.20), its seams (0.45) and a faint fill of its own shading to the 1.6
(0.16), as `r5.py` baked GHOST. The texture is baked once per hull from `JumpHull`'s image
and seam mask, stored over 2 so it fits a byte, with mipmaps.

The ghosts are one `MultiMesh` of quads, each placed in GDScript (whole pixels) and weighted
through its custom data, stamped additively into a light buffer as density: red for the ships
behind the hull, green for those in front, blue for the cloud as it froze, which the haze is
blurred from after the snap. The world pass colours the density by the interference field
(teal crests, rose troughs), so the ghosts' colour costs nothing per ghost.

The same instances are drawn again into a quarter-size buffer read through the mipmaps: the
film's haze was a box blur of the cloud, and a ghost drawn at a quarter from its mipmap is the
mean of its pixels, so a few taps over the quarter buffer stand in for the blur.

The ships behind are drawn at 0.8 and 0.62 of the hull, a little brighter, as the film's
pre-scaled ghosts were.
