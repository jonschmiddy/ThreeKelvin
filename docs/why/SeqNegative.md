The reasoning behind `tkg/scripts/ui/jump/SeqNegative.gd` and `tkg/shaders/jump/jump_r12.gdshader`; each heading is referenced from the code by a `Why:` line.

## Negative

R12 NEGATIVE as Jon approved it (round 3, Nov 10: "R12 is great"), ported act for act from
`tk-scratch/jump-drive/round3/_r12/r12.py`. The clock is the film's: wake 0.7, wave 1.9, hang
4.2, the four tighten beats 4.50 4.86 5.16 5.40 to 330 150 56 7 px off the hull, silence from
5.62, collapse 5.92 over eight frames, the point, the snap at 6.103, the afterimage gone by
8.57, the commit at 8.8 on a settled sky.

What is the same: every curve (`spread_r`, `reach`, `throb`, `collapse_f`), the nine pulse
times, the wobble's three sines, the bends, the rim, the ink shadow, the hole-of-light ramp,
the afterimage's erosion, the ring, the 6 px shake and the fringe.

What differs, and why:

- The negative's palette. The film median-cut 26 colours from the negative of its own scene.
  The game cannot afford that per jump, so the palette is the ramp's fixed colours plus this
  LOCAL's own palette put through the negative (`LocalSky.palette_for`), or the film's cut
  where the sky kept none; the pair dither is the film's. The paper reads a shade smoother.
- The far field of the hull's distance is a capsule (`docs/why/JumpStage.md#shader-includes`),
  so the pocket at 56 px is a little rounder than the film's.
- The tremble's coin flips and the afterimage's per-pixel thresholds are hashes, not numpy's
  rolls: the same statistics, other pixels.

## World pass

One `canvas_item` shader on the stage does `frame()`: the field F from the mode (wave: a
distance round the drive with the wobble; tighten: the hull's SDF less the reach; collapse:
the SDF sampled at the shrunken hull; point: a 3 px disc), the bends as a sample offset on the
sky, the hull from its baked textures (3x3 supersampled while it shrinks), the negative
(`neg_raw` then the pair-dithered palette), the mask against the 4x4 Bayer, the rim and its
ink shadow, the afterimage and the glint. Dust is in the copy already (`JumpSpecks`). The
finish pass adds the fringe and the shake.
