The reasoning behind `tkg/scripts/ui/jump/JumpDirector.gd`; each heading is referenced from the code by a `Why:` line.

## Director

The jump used to be wired inside `SectorScreen` (`_begin_depart`, `_pulse_out`, the flare's
`peaked` signal committing the jump). That file is pinned at its code_check baseline, and the
jump became eleven films (tk-scratch/jump-drive/round3, Jon's picks of Nov 10), so the wiring
moved out into a director the screen adds as a child when it departs.

What it does, in order:

- Waits for the first frame the view has a size. `_begin_depart` is called from the screen's
  `setup`, before its first layout, and measuring then gave a window of nothing: every sample
  clamped to one column and the whole film was horizontal bands (slice 1's first capture).
- `art.depart(true)`: the hull goes still, no flame, no bob, as the films' hull was.
- Picks the film (`JumpRegistry.pick(Run.jumps)`), bakes or fetches the hull (`JumpHull`),
  measures where things go (`JumpPlace`), builds the stage last in EncounterView and the film
  on it.
- Steps the film on `GameClock` (never the wall clock: the movie writer runs the wall clock
  12.7x fast, `docs/why/GameClock.md`). The cues fire on the frame the clock crosses them,
  playing from inside the take by how late that frame was, so picture and sound stay within a
  frame however the frames fall. The film's t is snapped to 0.1 ms: GameClock sums 1/60
  steps, so frame 300 read 4.99999 and a hit at 5.0 (R1's launch frames) drew a frame late.
- Swaps the live hull for the baked stand-in at `swap_t` (0.6 s, before any light touches the
  hull) on a frame the two are pixel-identical (the spike measured 0 px of difference in the
  hull's box).
- Commits at the film's `commit_t` through `SectorScreen._commit`, which still owns the
  phase check and the tab-tick suppression. The sound's tail rolls on across the swap, since
  `Audio` is an autoload.

A skip (`SectorScreen._skip`, with CLICK TO SKIP JUMP on) hushes both cues, frees the stage
and lets the screen commit as skipped. Reduced motion never reaches here: `Router.begin_jump`
takes its instant path when `animating()` is false.

The old hyperdrive (`JumpFx`) is untouched: `ShipSlot` still owns one, the cine's strip modes
still film it, and `hyperjump.wav` still plays for an enemy escaping and for partners' slots.
Retiring it is slice 7.
