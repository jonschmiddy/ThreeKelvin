The reasoning behind `tkg/scripts/ui/jump/SeqUnravel.gd`, `tkg/shaders/jump/jump_r9.gdshader` and `tkg/shaders/jump/jump_r9_threads.gdshaderinc` (with its two shaders); each heading is referenced from the code by a `Why:` line.

## Unravel

R9 UNRAVEL as Jon approved it (round 3, Nov 10: "R9 goes crazy"; its sound is the v5 mix, the
transformer drone with the sail take's crackle put back, "perfect"), ported act for act from
`tk-scratch/jump-drive/round3/_r9/r9.py`. The clock is the film's: wake 0.6, the first plate
at 2.3 and the last by 5.05, taut 5.3, hold 5.85, the zip 6.08, the snap 6.15, afterglow to
9.0, the commit at 9.0 on a settled sky. The mix is cut at 5.8, in the true silence the film
keeps from 5.45 to the snap, so the hit cue fires on the frame the clock crosses it.

What is the same: the eight plates (the film's own columns, fitted to this hull's length), each
row's delay, the 24 bands' wave, twist, rise and hue (the film's rolls, kept as constants), the
thread formula sample for sample at 0.55 px of arc, the paint dithered out at the root, the
curtain rays on every third sample, the afterglow's four lags at 30 fps, the ghost of the
curtains from the same four moments, the corona, the burst of 54 rays, the bar, the ring, the
160 sparks and 90 motes, the flash (3 frames, its 0.30 floor, 200 px falloff, mint-violet), the
fringe and the 5 px shake at 16 Hz.

What differs, and why:

- The afterglow is drawn again from the past, not kept. The plan had a ping-pong buffer; the
  film adds the ribbons as they were 1, 2, 3 and 5 thirtieths of a second ago, and drawing
  those four instants again costs the GPU little, keeps the film pure in t (a skip or a seek
  shows the right frame) and needs no feedback buffer, whose 8 bits would never decay to zero.
- The light the ribbons throw on the sky and the hull (`box(rib_lum, 4 / 8 / 10x2)`) is read
  from a quarter-size buffer through a tent of bilinear taps: the same soft spread, a little
  smoother.
- The 18 loose fibres are picked from this hull's stern outline with Godot's generator (the
  film's pick was of its own sprite); the tremble's coin flips are hashes. Same statistics.
- The HUD does not flash with the snap (the film lifted it 35%); the HUD never changes.

## Threads

Every ink row is a thread, sampled every 0.55 px of arc up to its pulled length: about 41,000
samples at the peak, so they are placed on the GPU. A mesh of empty quads (`MapChart._quads`)
is drawn with `VERTEX_ID` naming the row and the sample; the vertex shader works the film's
`ribbon_samples` out for that sample and sets its quad on the whole pixel it rounds to, so the
light sums there as the film's `deposit` did. Rows get a fixed number of slots (the hull's
length pulled out); unused slots fall off screen. One include, two shaders: light (added) and
the paint (opaque, the back band at alpha a half, the front band whole, so the world pass lays
each on its side of the hull).

The light goes into 8-bit buffers, so each is pre-scaled to fit: lines x0.25 (they peak near 4),
curtains x2 (they peak near 0.5 and their tails are tiny), the afterglow x0.5, the ghost x0.25.

## World pass

One `canvas_item` shader does `frame()`: the sky (drawn toward the corona while taut and rung by
the snap), brightened where the ribbons light it; what is left of the hull (the ink right of its
row's front) lit by its seams, pulses, plate warnings, the burning front and the ribbons; the
glow (curtains, afterglow, the ghost drifting up through its stretched dissolve, the drive, the
front, the corona, the burst); then the film's order: back light, glow, back paint, hull, front
paint, front light. The finish pass adds the bloom, flash, fringe and shake.

## Specks

The fibres, sparks and motes are a few hundred whole-pixel specks a frame at most, so they are
drawn on the CPU as 1 px rects, added into the front band's buffer as the film put them into its
front light.
