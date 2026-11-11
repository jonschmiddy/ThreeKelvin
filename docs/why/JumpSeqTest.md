The reasoning behind `tkg/scripts/sim/JumpSeqTest.gd`; each heading is referenced from the code by a `Why:` line.

## Jump sequence test

A film is ten seconds of shaders nobody can read in a log, so the test holds what can be held
in numbers, on `--fixed-fps 60` with `Router.animate_in_harness`, through `Router.begin_jump`:

- the director begins and the jump commits once, within two frames of the film's `commit_t`,
  landing on the system map (the arrival at the edge, Jon, Nov 10);
- the build cue is taped on the film's first frame and the hit cue on the frame the clock
  crosses the cut, playing from inside the take by exactly how late that frame was, against
  `jump_cues.json` as `audio/jump_cues.py` wrote it;
- nothing else plays through the film;
- the HUD's rect never changes and the viewport's canvas transform stays identity (the whole
  canvas once shook with `Main._kick`);
- the stage is the last child of EncounterView every frame and is gone with the director at
  the commit;
- the live hull is hidden at the swap time and not before;
- the shake is whole pixels;
- a skip two seconds in commits, hushes both cues and leaves nothing;
- picks are the same twice from one seed and every landed film is drawn in forty;
- REDUCE FLASHES caps the flash and drops its frame-wide floor; without it the floor is the
  film's (`JumpSequence.flash_floor`: 0.10, R10 0.14).

Headless there is no render, so the bake falls back to the CPU canvas and the shaders are
never compiled: what the picture looks like is `JumpCine whole` and `films`, judged by eye
against the approved strips (`tools/dev/jump_compare.py`).
