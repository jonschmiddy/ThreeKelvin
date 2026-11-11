The reasoning behind `tkg/scripts/ui/jump/SeqHyperspace.gd`, `tkg/shaders/jump/jump_r1.gdshader` and `tkg/shaders/jump/jump_r1.gdshaderinc`; each heading is referenced from the code by a `Why:` line.

## Hyperspace

R1 HYPERSPACE as Jon approved it (round 3b, Nov 10: no zoom; the stars' reset fixed), ported
from `tk-scratch/jump-drive/round3/_r1/r1.py`. The clock is the film's: wake 0.7, the pinhole
from 1.2, the lean from 1.7, the flow from 2.4, the hold 4.55 (silence from 4.86), the launch
5.0, the commit at 8.8.

What is the same: the spool, the stretch with its spring home (the lag fading with S after
the hit, so no star is thrown past home), the flow's speed integral (sampled 600 times a
second), the drive's pulses on the sound's formula, the pinhole, its rim light, the bend and
the shock ring, the two hand-set launch frames (stretch 1.6, then 3.6 squashed to 0.22,
white), the path of light, the afterimage, the 70 sparks with the film's own rolls copied
out (flickering only while they fly), the flash, the fringe and the shake.

What differs, and why:

- The stars are LOCAL's own, lifted off the frame (`docs/why/JumpStars.md#lift`), not the
  film's background; their lag and the 1500 faint extras are hashed, not numpy's rolls.
- The flow's 900 rolls are hashed too: the same depths, speeds and brightness, other angles.
- The bloom is sparse taps (`docs/why/JumpStage.md#finish-pass`).
- The shock ring's tear of the comet and station (filmed, left alone in the film) is still
  there, nearest-sampled as the film's.

## Stars

`jump_r1.gdshaderinc` holds the star law both the streak instances and the world pass use:
where a star at its home has leaned toward the pinhole at stretch S (head and tail), and how
much of its own dot stays on its home pixel. The world pass paints a lifted star's home bare
exactly while its streak is drawn, so a star is never in two places and never gone.

## World pass

One `canvas_item` shader does `frame()`: the sky bent toward the pinhole and rung by the
shock, the homes painted bare, the back light buffer (far and mid streaks, the stars), the
pinhole and its bar, the drive's glow, the hull lit by its pulses and the pinhole's rim (or
stretched on the launch frames), the aftermath's path, afterimage, point and ring, and the
front light buffer (the near streaks over the hull, the sparks). The finish adds R1's bloom,
its flash (floor 0.3, 200 px falloff, violet, the beam along the ship's line) and fringe.
