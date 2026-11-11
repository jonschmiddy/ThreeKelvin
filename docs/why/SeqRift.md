The reasoning behind `tkg/scripts/ui/jump/SeqRift.gd` and `tkg/shaders/jump/jump_r3_*.gdshader`; each heading is referenced from the code by a `Why:` line.

## Rift

R3 THE RIFT as Jon approved it (round 3, Nov 10: "Holy shit these are fucking insane. I LOVE
THEM ALL"; round 3b took the zoom out), ported from `tk-scratch/jump-drive/round3/_r3/rift.py`.
The clock is the film's: the flame sputters out and a pin of dark opens at 0.6, the lens grows
to an Einstein radius of 80 px by 3.25, the inhale draws it back, the tear at 3.6 (one white
frame, the crack, the throat snapping open with a ring-down wobble), the fall to 6.2, the hold,
the heal at 7.0, the shut and the quadrupole ring-down at 7.3, motes out by 9.6, the commit at
9.6 on a settled sky.

The sound is the film's mix cut in the inhale's dip (3.322 s, about -45 dBFS: the mix never
falls silent there, so `jump_cues.py` takes it as a hard cut) into a build cue and a hit cue;
the hit's onset lands 16 ms after the tear, inside a 60th.

Where it stands: the rift is 275 px ahead of the nose and 16.5 px above the hull's middle line,
as filmed. `JumpPlace.ahead` scales the whole rift about that point (every distance in the
shaders is the film's, `(screen - Tg) / S`), so a convoy pad with less room ahead gets a smaller
rift at the same distance in nose lengths, and the same clock.

What differs, and why:

- The ion flame. The film's flame burned to 0.6 and flickered out over a quarter second. The
  live hull keeps its idle flame to 0.6 (`JumpSequence.flame_s`, worked by the director) and
  blinks it out on the film's 30 fps frames, and the stand-in takes over at 0.85, after it is
  out (before any light touches the hull: the film's hull light at 0.85 is under 3%).
- The seams are found by the film's own rule on the game's hull (`docs/why/JumpWarpField.md#seams`),
  so another hull gets its own seams the same way.
- The crack's jitter and the motes' rolls are other draws of the same distributions (Godot's
  generator seeded with the film's seeds; hashes for the motes). The scar is still the tear's
  first frame, re-drawn longer, as filmed.
- The fringe and the shake are the finish pass's, on the composite: the fringe is the film's
  flat 4 px slide by quadrant (`fringe_px`), the shake the film's hash at 24 Hz in whole
  pixels. At the window's edge the shaken picture clamps where the film's had more sky.

## Ship pass

The film drew its hull in the source plane, through the inverse of the fall, and then lensed
everything (`sample_ship`). The ship pass does the same, before the lens.

- Before the tear the hull is drawn pixel for pixel (drawn back 3 px in the inhale), so the
  swap from the live hull is exact.
- The fall: a part D0 px from the rift closes on a horizon Dh on its own clock,
  `D = Dh + (D0 - Dh) exp(-(u / tau)^1.6)`, tau growing as D0^1.5 (nose first, so the hull
  stretches), never reaching the centre. The shader needs D0 for a D, so SeqRift fills a
  512-texel table each frame (one exp a grid point, its inverse by one walk) in an RF texture.
  The table is spaced by the square root of D: near the horizon the whole hull piles into a
  few pixels of depth, where an even spacing (3 px a texel) would smear it.
- Once falling, each pixel takes nine sub-samples through the table, so the stretching hull does
  not crawl (`docs/why/JumpWarpField.md#warp-field`).
- The light is the film's: plates brighter near the rift, the outline facing it stepped violet,
  the seam pulses tail to nose, and after the tear the red shift by depth toward crimson,
  dimmed, and the fade.

## Warp pass

Nine taps a pixel through the tear's pressure front and the heal's quadrupole ring-down (in that
order), then the point-mass lens `beta = theta (1 - rE^2 / r^2 e^(-(r / reach)^2))`, turned by
frame dragging, black inside the throat. The sky past the window is mirrored back in, as the
film padded it. Then the light, in screen space: before the tear the lip round the pin of dark
and up to seven tidal arcs (their numbers from the film's `hash01`, ported exactly); after it the
photon ring, its violet bloom, the faint Einstein ring, the crimson inner lip and the lit gas;
the crack (its glow the film's blurred line as a gaussian across it), the flashes, the pressure
front, the shut's pinpoint and the crests of the ring-down; and the motes from the light buffer.
All of it is summed and stepped once, as the film's `add_light` did.

## Points

The 120 infall motes (each a head and a five-pixel trail, spiralling into the throat on their
own 1.3 to 2.8 s cycles) and the 34 motes the shut throws out (each a pixel and a 3x3 glow) are
quads in the warp field's light buffer, placed in their vertex shader from the clock alone.
