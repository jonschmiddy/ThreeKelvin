The reasoning behind `tkg/scripts/ui/jump/JumpWarpField.gd` and `tkg/shaders/jump/jump_warp.gdshaderinc`; each heading is referenced from the code by a `Why:` line.

## Warp field

R3 THE RIFT and R8 MAELSTROM bend the whole world, and the ship has to be bent with it: R3's
hull wraps round the Einstein ring as two arcs, R8's turns down the funnel with the gas. Both
films' NOTES name this as the hard part ("the ship has to live inside the lensed world"). So
the draw order for these two is, on the stage:

1. the specks and a back buffer copy (the stage's own, as for every film);
2. the film's **ship pass** (the stage's first pass): the world copied as it is, with the
   baked stand-in hull drawn into it where the film's *source plane* has it, lit as the film
   lit it (seams, rim, red shift, storm tint);
3. a second copy;
4. the film's **warp pass**: nine taps a pixel through the film's map (the lens, the twist),
   each reading the copy, averaged in linear light, then the film's light added in steps;
5. a third copy and the shared finish (shake, the flat fringe).

Because the hull is drawn in the source plane, the warp bends it exactly as it bends the sky,
and the warp itself is one shader that never needs to know about the hull. R3's hull falls in
its source plane (the fall is a table, `docs/why/SeqRift.md#ship-pass`).

R8 is the exception: its hull is turned by less than the world's twist and ignores the inflow,
so drawn into the world first it went through two roundings and crawled as the storm grew
(measured: `docs/why/SeqMaelstrom.md#ship-in-the-twist`). Its warp pass reads the hull at each
tap instead, as the film did, and it has no ship pass: specks, copy, warp, copy, finish.

The same draw order is what the plan had (JumpStage: HullStandIn, an optional second copy and
the lens). It is built by adding the warp pass and its copy before the stage's finish, so the
stage itself is unchanged.

**Nine taps, not four.** The films took 3x3 sub-samples a pixel in linear light (their SOFT rule,
so stars do not crawl as the bend changes every frame). The plan allowed 4+ rotated taps; nine
cost one texture read each and are the films' own sampling, so the shimmer is the films'
(measured in the films' docs).

**The sky past the window.** A strong bend samples sky from outside the window (R3's frame
dragging turns the top edge in; R8's twist turns the corners in). The films padded their world
by reflection; `jw_world` mirrors the index back into the window the same way (numpy's
`reflect`), so a bent sight line always lands on sky and never on the HUD or a clamped smear.

**The ship pass supersamples once the hull moves.** Before the fall the hull is drawn pixel for
pixel, so the swap from the live hull is exact. Once it turns, shrinks or stretches, one sample
a source pixel would alias (the warp's nine taps land on only a few source pixels where it
magnifies), so it takes nine sub-samples too, as the films did for every sight line.

## Light buffer

The films added hundreds of single-pixel lights (R3's 120 infall motes with five-pixel trails
and the shut's 34; R8's 260 streaks with six-pixel trails, 60 embers and the 39-point wake) into
the same light map as the rings and glows, then stepped the sum. Here they are quads drawn into
an additive SubViewport the size of the window, which the warp pass reads back and adds to its
light before the step, so they step with everything else as in the films.

- The buffer is 8-bit (GL Compatibility has no HDR 2D), so the points write their light
  pre-scaled by 0.25 and the warp reads it back times four: lights to 4.0 survive, ample for
  any point.
- Each point is a quad whose UV carries (point index, corner); the vertex shader places it in
  closed form from a few uniforms (the clock, the throat, the flow clock), whole pixels, so
  nothing is computed per point on the CPU. The mesh's own vertices span the window only so the
  layer is never culled.
- The films rolled each point's numbers from numpy's generator. Here they are an integer hash of
  (point, field), the same on every GPU: the films' statistics, other draws. The films' own
  `hash01` (the flicker of a mote, a shake) is ported exactly (`jw_hash2`), as it is plain
  32-bit arithmetic.

## Seams

R3 and R8 run the drive's light along the hull's plate seams with a halo round them. `JumpHull`'s
seam mask (shared with R12 and R4) is looser than the films' (on the films' own sprite it marks
3023 pixels against the films' 1808, with 1626 in common), and with the films' halo over it the
whole plates lit up (the first capture: the hull washed pale where the film showed lit lines).
So `film_seams` applies the films' own rule to the baked hull (dark pixels under 110 and 14
under their 3x3 mean, kept where they run as lines) and bakes the films' halo with it, once per
hull look, from the film's opening (the hull is baked by its third frame); the shader then reads
both from one texture instead of 25 taps a pixel.
