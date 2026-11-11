The reasoning behind `tkg/scripts/ui/jump/SeqMaelstrom.gd`, `tkg/shaders/jump/jump_r8*.gdshader*` and `tkg/art/jump/r8_gas.png`; each heading is referenced from the code by a `Why:` line.

## Maelstrom

R8 MAELSTROM as Jon approved it (round 3, Nov 10: "All 10 are GOOD"), ported from
`tk-scratch/jump-drive/round3/_r8/maelstrom.py`. Its sound is the third mix (Nov 10: the pitched
whooshes were "too cartoony", then "the groan is weird"; v3 has no pitched layer and ends on a
storm blowing itself out). The clock is the film's: the flame sputters out and the gas ahead
starts to turn at 0.6, the spin-up to 3.6 (0 to 1.5 rad/s, three arms), the current takes the
ship at 3.6 and spins it down the drain in four faster half-laps, the hush at 5.95, the swallow
at 6.2 (two near-white frames, the pressure ring, the fringe, a 7 px shake), the coast, the
unwind from 7.0 to 9.45 with its one small overshoot, the commit at 9.5.

The sound is the film's mix cut in the hush (6.065 s, the dip's lowest, about -30 dBFS: the
hush is a 32 dB gate, not silence, so `jump_cues.py` takes it as a hard cut); the hit's onset
lands on the swallow to the millisecond.

Where it stands: the eye is 330 px ahead of the nose and 28.5 px above the hull's middle line,
as filmed; the laps stay in the window because the disc is tilted (KY 0.62). `JumpPlace.ahead`
scales the storm about the eye, so with less room ahead the whole storm is smaller and the
clock the same.

What differs, and why:

- The ion flame: as R3 (`docs/why/SeqRift.md#rift`).
- The ship's normals: the film blurred the sprite's alpha for its rim's normals; here they are
  the slope of `JumpHull`'s distance field, which points the same way at the outline.
- The streaks', embers' and motes' rolls are hashes (`docs/why/JumpWarpField.md#light-buffer`).
- A far streak is hidden where the hull covers its pixel's centre; the film used the pixel's
  nine-sample coverage.

## Storm

The twist, its inflow and the ship's own map are shared by the three R8 shaders
(`jump_r8.gdshaderinc`): a point d in the disc's plane (y over KY) is turned by
`-phi / (1 + (r / RC)^2)` and scaled by `1 + inflow e^(-r/240)`. phi is the spin rate's
integral, summed at a millisecond as the film did, then unwound with the film's ease and
overshoot. The ship turns with the storm only by its weight `wk` (rigid at its centre's rate,
plus 30% of the shear), then by its own extra turn and scale.

## Ship in the twist

The film sampled its hull at each sight line's point in the disc, before the inflow and with
its own, weaker twist (rigid at its centre's rate plus 30% of the shear), while the world got
the full twist and the inflow. R8 was first built as R3 is, with a ship pass that drew the hull
into the world where the twist would fetch it (undoing the world's twist and inflow per pixel).
Measured, that crawled: the hull went through two roundings, one into the ship pass's pixel and
one out of it in the warp, and as the inflow and twist grew every frame the pixels it picked
slipped. Its crawl on the hull (`tk-scratch/jump-drive/slice5/shimmer.py`, the residual after
block matching) was 10.8 at 3.0 s against the film's 5.5, and already 3.2 at 1.0 s, when the
film's hull is still.

So R8's warp pass reads the hull itself, at each of its nine taps, at that tap's point in the
disc (`jump_r8_hull.gdshaderinc`): one rounding, exactly the film's model, and the hull is still
inside the twist. There is no separate ship pass for R8 (`JumpWarpField.build` with none). The
light is the film's: the side facing the eye, the stepped rim on the outline facing it (the
outline and the ring inside it, from the baked inner distance), the seam pulses, then the
storm's magenta and the white burn.

## Warp pass

Nine taps a pixel: each sight line turned and scaled into the source plane (kicked out by the
swallow's front), the world read there (mirrored past the window), the gas's back layer read at
the same point, the front layer at a twist 1.18x faster (parallax), and the hull's coverage
(the gas is not drawn over the hull). Then the light: the gas as light (density^1.6 in a disc
whose reach grows from the eye, a core boost, a drain, coloured by radius, and lighting the
scene's own nebula by multiplying), the eye's pinpoint and turning sea-green lip, the dark
throat, the ship's burning point, the swallow's flashes and ring, and the light buffer.

**The gas** is the film's own two layers (`r8_gas.png`), cropped 1536 x 960 round the eye from
maelstrom.py's arrays (`tk-scratch/jump-drive/slice5/bake_gas.py`), red the back layer over its
maximum 1.276, green the front. Baking it in the game would be fbm and polar grain over a
million and a half pixels per jump; the crop is 0.8 MB once. Past the crop the disc's envelope
has the gas under 2% of its peak.

## Points

The 260 streaks (six-pixel trails on their own flow clock, a quarter of them near with a 3x3
glow), the 60 embers the swallow flings out along the arms, and the wake (the ship's last 39
places, 12 ms apart, worked out on the CPU from the forward map) are quads in the warp field's
light buffer, placed in their vertex shaders.
