The reasoning behind `tkg/scripts/ui/jump/JumpHull.gd`; each heading is referenced from the code by a `Why:` line.

## Bake

The films move, light, invert, shrink and dissolve the hull, so the shaders need it as
textures. `ShipSlot` clips its ShipView, so a hull leaving its slot needs a stand-in anyway.

What is baked, once per look (hull, pilot, wear band, half sheet, canvas size; four kept):

- The picture: a fresh ShipView with the same build, size and zoom as the live one, with
  `MountPoints` passive, rendered to a transparent SubViewport and read back. The live view's
  CPU canvas (`ShipView.canvas()`) lacks the fitted parts, so it is only the headless fallback.
  Read at the live view's own size, the canvas has the same parity rows and the stand-in drawn
  at the canvas's screen origin differs from the live view by 0 px in the hull's box (the spike
  measured it; at 240x120 it was 11,782 px off, since this hull's canvas is 324 px wide).
- Seams (`hl < 0.78 box3(hl)` inside a 2 px erosion, as r4.py), the inner distance, the
  hole-of-light index (R12's 5-step ramp by hull luminance between its 8th and 92nd
  percentiles, Bayer-dithered by canvas pixel), up and down facing weights and the 4 px edge
  (R4's `UPF`/`DNF`), packed as two RGBA8 textures.
- A signed distance round the hull on a grid padded 48 px, two bytes a texel, by
  Felzenszwalb and Huttenlocher's two 1D passes in GDScript. The near field (the skin 7 px
  off the hull, the ink shadow round the hole) wants the true distance; the far field is
  handed to a capsule in the shader (`docs/why/JumpStage.md#shader-includes`).

The bake takes two frames to render and a fraction of a second on the CPU, during the film's
settled opening; cached, the next jump pays nothing.
