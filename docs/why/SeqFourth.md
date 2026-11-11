The reasoning behind `tkg/scripts/ui/jump/SeqFourth.gd`, `tkg/shaders/jump/jump_r2.gdshader`, `tkg/shaders/jump/jump_r2.gdshaderinc` and `tkg/shaders/jump/jump_r2_cube.gdshader`; each heading is referenced from the code by a `Why:` line.

## Fourth dimension

R2 THE FOURTH DIMENSION as Jon approved it (round 3b, Nov 10, with no zoom), ported act for act
from `tk-scratch/jump-drive/round3/_r2/r2.py`. The clock is the film's: wake 0.75, the four
unfolds 1.25 1.85 2.40 2.90, the turn 3.05 to 5.30, the hush 5.40, gone along W from 5.72,
the bang 5.92, the motes to 9.3, the commit at 9.4. Its mix (`_r2/sound/mix.wav`) is cut at
5.6, inside the hush.

The hypercube is drawn about the hull's own axis, so with the ship at the left of LOCAL it
runs past the window's left edge during the turn by up to about 100 px. Jon's call (Nov 10,
Q5): leave it as filmed.

What differs, and why:

- The ion flame's four-step gutter (0.55-0.8 s) is not drawn: the ship's engines go off when
  the jump begins (`ShipView.depart`), as for every film.
- The stars echoed along W are the sky less the mean of a ring 2 px round each pixel (the film
  took the sky less its 5 x 5 median): the same stars, a little more of the nebula's grain.
- The glow's blurs (sigma 1, 3.5, 18 and 40 px) are 5 x 5 gaussian taps on buffers drawn at
  full, half, an eighth and a sixteenth size; the film blurred subsampled copies.
- The thickness along W is read from the hull's baked inner distance (to 32 px, a sixteenth
  short of the film's 34 at the spine), and the seams by the film's rule on the unturned hull.
- The shake's draws are hashes, not numpy's rolls.

## The 4D hull

The hull is a 4D solid: the picture thickened along W by `70 (d / dmax)^0.55`, d its inner
distance. Each frame shows its cut at w = w0 after the turn R = R_xw(a) R_yw(b): for a screen
point (x, y) about the turn's axis, (u, v, w) = R^T (x, y, 0, 0); the hull is there where the
picture has ink at (u, v) and |w - w0| is within its thickness. So it bulges (an oblique cut is
longer), is carved along its distance contours, shows its inside at 90 degrees, comes back
mirrored, and as w0 rises at the end it shrinks to its spine. Its two copies are the same cut of
a hull turned a little further and a little less, offset and scaled by W perspective. The space
turn clamps u at the 90-degree pole, as the film did.

## Hypercube

16 corners turned by R_xw R_yw R_zw and projected 4D to 3D (W perspective) and 3D to 2D are
worked out on the CPU each frame; the 32 edges are then stepped a pixel at a time on the GPU
(one quad a step, by `VERTEX_ID`), with two energy beads per edge, the 16 corner glints and,
after the bang, the 120 motes, summed into light buffers as the film's `deposit` did. Each
step that lies behind the hull asks the hull's cut at its pixel (the include) and is hidden or
dimmed as the film's `behind`. The cells' panes are a second small mesh, drawn into their own
buffer and hidden behind the hull per pixel.

## World pass

One `canvas_item` shader does `frame()`: space sheared by the turn inside the hypercube and
rippled by the bang, dimmed; the star echoes; the copies and the hull's cut with its tint and
burning edge and its 1 px rim; the drive's glow, seam light and glint; the bang's frame light,
point and ring; then the hypercube's light (hot lines, the glow's blurs, the broad light on the
hull, the panes), R2's own tone map (ten steps, a 4 x 4 dither, white when hot), the lit hull
and the lines burning over it. The finish pass adds the shake and the fringe, a sideways slip
of red and blue (its centre put far to the left, so the radial slip is horizontal everywhere).
