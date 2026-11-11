The reasoning behind `tkg/scripts/ui/jump/SeqCoilRail.gd` and `tkg/shaders/jump/jump_r10.gdshader`; each heading is referenced from the code by a `Why:` line.

## Coil rail

R10 COIL RAIL as Jon approved it (round 3, Nov 10), ported from
`tk-scratch/jump-drive/round3/_r10/r10.py`. The clock is the film's: wake 0.6, the seven
rings thrown at 1.25 to 2.89, the charge from 3.62, the hold 4.62, silence from 4.86, the
fire 5.0, the bow through the last ring 5.405 and gone 5.424, the ring-outs from 6.05 every
0.31 s, the commit at 8.8.

The ring sounds are baked into the mix (v5: the clamps, the run's punches and the ring-outs
at one flat level each, the old fire take's crackle low-passed), so every ring keeps the
film's event time. Only space scales: the rail's distances are the film's times
`JumpPlace.ahead` (the room ahead of the nose over the film's 622 px, never under 0.35), and
the rings' size is the hull's (`hull_k`). The run's speed is scaled with the rail, so the bow
still crosses each ring on the frame its punch sounds. With a convoy pad or a co-op partner
ahead the rail shortens and the rings crowd; they never move off their times.

R10's mix is the one whose hit is a climb, not an onset: seven punches each louder into the
jump's boom. `jump_cues.py` lists it in RAMP, so its onset is recorded but not held to the
jump's time.

## World pass

One `canvas_item` shader on the stage draws the film's frame: the bow emitter and the seam
crawl, the rings as analytic ellipses (back arc behind the hull, front arc over it), each
with its thrown ghosts, glints, flare, bell wobble and pop; the rail, the chase pulses, the
field lines and the 15 fps arcs (rolled in GDScript on the held frame); the sky pinched toward
the rail; the run with its smear and heat from the bow back; the Mach cone as true envelopes
(each x's circle grows from when the bow passed it, `run_k` in closed form); the spear, the
point, the anamorphic bar and the shock ring. The sparks are `JumpSparkQuads` mode 2. The
finish pass adds the flash (a bar along the rail as well as round the point), the fringe and
the 17 Hz shake.
