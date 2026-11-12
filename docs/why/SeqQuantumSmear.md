The reasoning behind `tkg/scripts/ui/jump/SeqQuantumSmear.gd` and `tkg/shaders/jump/jump_r5.gdshader`; each heading is referenced from the code by a `Why:` line.

## Quantum smear

R5 QUANTUM SMEAR as Jon approved it (round 3b, Nov 10; the boomier ending; no ship at the
point), ported from `tk-scratch/jump-drive/round3/_r5/r5.py`. The clock is the film's: wake
0.8, smear 2.4, hold 6.2 (silence from 6.42), snap 6.6, the pop at 6.933, the commit at 8.8.

What is the same: the smear curve, the 64 probable ships with the film's own rolls copied
out (along, across, lean, weight, depth, rank), their wobble, the 10 Hz hops and blinks on a
held clock, the interference field and its colours, the haze, the sky's waver, the glint and
its bar, the hull's certainty falling to 55% with its tremble and fringes, the snap's frames
(ghosts halfway with lines, then lines converging and draining over two more), the held
point with its shrinking halo, the pop's cross flare, the two banded rings, the foam and the
last speck, the flashes, the fringe and the 4 px shake.

Jon, Nov 10: "The ship showing up at the last second before disappearing is weird." No whole
ship is drawn at the point: the ghosts pour into a held point, which pops.

What differs, and why:

- The hop and blink coins are hashes, not numpy's rolls, except on the two ticks the cloud
  freezes on (61 and 62): those are the film's own draws, copied out with the wobble's rates
  and phases, so the frozen cloud of the hold is the film's poster ship for ship. With hashed
  hops the hold spread its ships wider and lost the film's hot overlap in the middle.
- The haze is taps over a quarter-size buffer (`docs/why/JumpGhosts.md#ghosts`), not two box
  blurs at full size.
- The bloom is sparse taps (`docs/why/JumpStage.md#finish-pass`).

## World pass

One `canvas_item` shader does `frame()`: the field F, the haze from the quarter buffer, the
sky wavering inside the cloud and bent by the rings after, the ghosts (density from
`JumpGhosts`) coloured by F, the glint, the hull at its certainty under its fringes and rim,
the point, the pop, the rings and the speck. The finish adds R5's bloom, its flash (floor
0.16, 200 px falloff, teal) and fringe.
