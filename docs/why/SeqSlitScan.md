The reasoning behind `tkg/scripts/ui/jump/SeqSlitScan.gd` and `tkg/shaders/jump/jump_r4.gdshader`; each heading is referenced from the code by a `Why:` line.

## Slit scan

R4 SLIT-SCAN CORRIDOR as Jon approved it (round 3b, Nov 10), ported from
`tk-scratch/jump-drive/round3/_r4/r4.py`. The clock is the film's: wake 0.7, slit 0.9, the
corridor out of the slit from 1.5, the rush, the breath 4.7 (silence from 4.73), the swallow
5.0, the fold 5.5, the pinch 6.0, the shut 6.26, the commit at 8.8.

What is the same: the speed curve and its integral (sampled 600 times a second, as the film
did), the mouth, the fold, the gain, the whiten, the lanes and ribs with their hashes, the
ship's tremble, 5 px draw-back, jolt and dive about the point, the six outline echoes, the
26 near dashes and the 90 shards with the film's own rolls copied out, both flashes, both
fringes, both shakes.

What differs, and why:

- The stars do not drift outward from the point. The film moved its star dots alone by up to
  12%; the game's sky is one picture, and moving it would be a zoom, which Jon ruled out.
- The bloom is sparse taps, not two box blurs (`docs/why/JumpStage.md#finish-pass`).
- The HUD does not brighten on the flash (the film lifted its HUD rows 30%); the HUD is off
  limits to the stage.
- The lanes' hashes run in float32, so a lane's rolled width or colour is not the film's to
  the digit.

## World pass

One `canvas_item` shader on the stage does `corridor()` and `frame()`: the four planes'
light and cover at four subsamples, the sky dimmed by the cover and bent by the shut's ring,
the slit, the point, the slot, the fold's lines, the hull lit by its pulses, the planes and
the ribs crossing it, the dive and its echoes, the streak and the pip, the scar and the
shards, composited as the film did (back light behind the hull, glow, hull, near light). The
finish pass adds the bloom, the flash, the fringe and the shake.
