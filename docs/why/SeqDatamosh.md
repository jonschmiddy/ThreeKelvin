The reasoning behind `tkg/scripts/ui/jump/SeqDatamosh.gd` and its shaders `tkg/shaders/jump/jump_r15*.gdshader(inc)`; each heading is referenced from the code by a `Why:` line.

## Datamosh

R15 DATAMOSH as approved in round 3, ported from `tk-scratch/jump-drive/round3/_r15/r15.py`.
The clock is the film's: wake 0.7 (twelve drive pulses), mosh 2.2, full 4.9, rip 6.0, tape
stop 6.15, freeze 6.45, snap 7.05, the dead blocks out by 8.8, the commit at 8.9 on a clean
sky with no ship. The mix is the film's, cut at 6.48 (in the freeze's silence) into a build
cue and a hit cue (`audio/jump_cues.py`).

It echoes the GLITCH tooltip (`HoloTag.gd`): its fill `#061010`, scanline `#0a1a16` and mint
edge `#b8f5d8`; its tear (a band drawn again to the side, a dark gap, 1 px mint caps); its
scanlines, one dark row in three; its flicker steps at 0.04 s. After the snap the tag's mint
edge hangs where the hull was and flickers out, the tooltip closing.

It is a feedback picture: each tick is the last one moved, so it is stateful. It is stepped
tick by tick from its first frame on GameClock (60 ticks a second, the film's frames), never
sought; a slow frame runs the ticks it missed in one go, a fast one waits for the next tick.

The pipeline, in the order the viewports draw:

1. `JumpMirror`: the world again, no HUD, no stage (`docs/why/JumpMirror.md#mirror`).
2. The state: a SubViewport never cleared, reading its last tick through a BackBufferCopy
   (`#state-pass`).
3. The sort: the state with the dealt rows pixel-sorted (its own pass; inlined into the
   output's chain of slips and stamps, its loops made a shader the driver took minutes to
   compile).
4. The output: the sorted state as broken video (`#output-pass`).
5. The stage's world pass shows the output, then the frozen frame, then the snap (`#world-pass`).

The CPU side, per tick: the vectors (one deal per GOP of 0.42 s of tape, rng 9000 + g: a
weighted multiplier per block, rails of 4 to 21 blocks sharing one, a profile peaked on the
heading, a fan off it) are integrated per block and their whole pixels written into a 120x68
RG8 texture; the infection's front advances (each block's time baked once, rng 1515: the
distance from the hull scaled along, behind and off the axis, clumped noise, a few blocks
running ahead, the hull's blocks first); the deals for the sort, the slips, the stamps and the
tears are made on the tape clock.

The tape clock (`tape`) runs at 1 until 6.15 and grinds to a halt at 6.45 (rate 1 - u^2). The
vectors' speed, every deal, the tears and the slips read it; the mix's varispeed was cut on the
same curve, so the sound slows with the picture.

Measured against the film (changed pixels a frame, world window, by half second): wake
0.3-1.9% (film 0.2-2.0), mosh 2.2% rising to 15.8% (film 2.1-18.3), full 23-39% (film
25-38), freeze 0% (0), snap 5.5% (6.6), after 7.5 s 0.1% (0.1). Flick-back peaks at 6.6% in
the full act (film 7.4). Cost on Jon's PC: the CPU part 1.4 ms a tick (p95 5.2), the four
viewports 0.3 ms on the GPU (p95 0.7).

The freeze reads the last output back once (the frame is dead still, so the stall is not
seen), holds it as a texture, picks the dead blocks from it and frees the three viewports.

What differs from the film, and why:

- The numpy draws (vectors, infection noise, refresh, DC errors, deals) are Godot's RNG and
  per-block hashes: the same rules and rates, other blocks.
- The pixel sort is faked on the GPU: in each dealt span the bright run round a pixel (ends
  found on the band's middle row, so shared down the band, in 128 px chunks) is read at 16
  taps, sorted, and the pixel takes its rank's tap. The film sorted every pixel. The spans are
  dealt on the broken blocks, not found from the picture's brightness on the CPU, and the
  rows are capped at 40 a deal.
- The palette is the glitch's own colours, then this LOCAL's (`LocalSky.palette_for`) and
  their mint and rose halves, or the film's cut where the sky kept none: 64 at most.
- The halos (the tag's edge, the hanging edge, the tear caps) are approximated from the hull's
  distance field and the caps' rows rather than box-filtered.

With REDUCE FLASHES: the vectors are released at 4 Hz (every 15 ticks), and refresh and DC
errors land only on those ticks; no channel slips (no row slips, no pulse slip, no hull slip,
no snap slip); DC errors at half the rate and half the strength; the sort re-dealt at 4 Hz, the
stamps at 4 Hz; tears held at least a quarter second; the tag, the dead blocks and the hanging
edge fade instead of flickering; the scanlines do not crawl.

## Shader include

The three passes share the tooltip's colours, the slip's mint/rose weights (WA + WB = 1, so an
aligned slip gives back the picture), an integer hash for per-block draws, the hull's alpha and
1 px ring, and R12's pair-dithered palette snap done per pixel.

## State pass

Per pixel: the clean picture is the mirror with the baked hull lit by the drive (r15.py
`ship_lit`, mint, violet and white) and the drive's aura round it. A moving block is last
tick's state moved by its vector, edge-clamped to the world window so the bezel is never
dragged in. Intra refresh sends a few runs of blocks clean each tick (5% falling to 1.4%, less
in the heading's lane), or the sky drains off to the right and the frame goes black in about a
second. DC errors add flat mint, violet, rose, lilac or ink in runs along the heading, most on
the corruption's young front, and ride forward. The hull still being sent is the clean
picture until the rip, when it stops from the nose back.

## Output pass

One pass on the state, which it never writes: the sort, the mint/rose slip by row band, the
repeated blocks (the last stamp wins, reading the picture before any stamp), the hull still
being sent slipped by a pixel and nothing else (it is kept out of the sort, the slips and the
stamps, or it is gone by 5 s and the freeze has no ship in it), the pulse slip and the tag in
the wake, scanlines, the tears, then the palette snap only where the glitch changed a pixel
(the untouched sky would show a seam at the corruption's edge otherwise), then the caps' glow.

## World pass

The stage's pass shows the output through the mosh and the held frame through the freeze.
After the snap it is the clean world with no ship, 15 dead blocks of the frozen frame (8
bright, 7 coloured, going out from where the ship was to the right edge, each with the
tooltip's flicker run out), the hanging mint edge, and the snap's mint/rose slip closing up in
about 0.2 s, snapped to the palette where any of them touched. The shared finish pass does the
6 px whole-pixel shake.
