The reasoning behind `tkg/scripts/ui/jump/JumpStage.gd` and the shaders under `tkg/shaders/jump/`; each heading is referenced from the code by a `Why:` line.

## Stage

The film is drawn over the world and under the HUD. The spike (Nov 10) settled where:

- A `BackBufferCopy` (viewport mode) as a late child of `EncounterView` sees everything drawn
  before it in the game's 960x540 SubViewport: the sky, your hull and its parts, the dust, the
  effects. The HUD bar is drawn before the screens, so it IS in the copy, above the view; the
  goal line, the drawer and the name card are drawn after, so they are not. The stage is
  clipped to the view (`clip_contents`), and every sample is clamped into the view's window,
  so the HUD is never read and never written: it cannot move, flash or invert.
- One world pass per film, reading the copy and the hull's baked textures, does the whole
  per-pixel work of the film's Python `frame()` in float. The plan's separate 8-bit light
  buffer (pre-scaled by 0.25, proven in the spike to round-trip within two steps) is not
  needed by R12 or R4 and is kept for the films that layer more passes.
- A second copy and the shared finish pass (below), so the fringe and the shake see the
  finished composite, specks included.

The stage is a Control anchored to the view, so it follows the view's bleed and its resize.

## Finish pass

`jump_finish.gdshader` is what the films' `finish()` did after the world: the bloom (R4 only;
sparse taps standing in for the two box blurs), the full-frame flash, the chromatic fringe
radial from the event, and the whole-pixel shake as a sample offset, clamped into the window.
The order is fringe, bloom, flash: the films fringed last, but a fringe of the un-bloomed
picture then bloomed loses nothing anyone can see and saves a third pass.

The shake moves the picture, never the stage or the HUD (Jon's rule, BRIEF.md round 3b: a
whole-pixel shake only on the big moment, nothing else moves the camera). SCREEN SHAKE off
zeroes it.

## Shader includes

`jump_common.gdshaderinc` holds what every film's pass shares: the 2x2 and 4x4 Bayers the
films dithered with, the tone map and step (`1 - e^-L`, stepped, the glow dithered and the
lines not), light added over a picture by its brightest channel, a splat, the hash the lanes
are rolled from, the window-clamped screen read, and the hull's signed distance.

That distance is the baked field (`JumpHull`) inside its 48 px pad; outside the pad, a capsule
through the hull's ink, blended over the pad's last 16 px. Extrapolating from the padded box's
edge gave a faceted front in R12's tighten (a polygon where the film's was smooth lobes) at
reaches of 150 to 330 px; the capsule's far field is as smooth as the film's true distance
transform, and at 7 px off the hull, where the shape matters, the baked field is exact.

The hashes run in float32, so a lane's rolled width or colour is not the film's to the digit;
the statistics are.
