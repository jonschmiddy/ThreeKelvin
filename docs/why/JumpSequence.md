The reasoning behind `tkg/scripts/ui/jump/JumpSequence.gd`; each heading is referenced from the code by a `Why:` line.

## Sequence

A film is pure in t: `step(t)` works out this instant's numbers from the film's own curves and
hands them to the passes; nothing is kept between frames. So a harness can seek, the capture
is the same at any frame rate, and a hitch costs a frame, not a drift.

Two cues a film, cut from its approved mix by `audio/jump_cues.py` at the silence before the
hit (`cut_t`): the build from the first frame, the hit from the cut. Firing the hit on the
frame the clock crosses the cut re-syncs the sound to the picture there, so a build that
stuttered cannot put the boom off its frame. Both are played with no pitch variance and
`exact`, so `Audio.play` never round-robins a take.

REDUCE FLASHES (`DisplaySettings.reduce_flashes`, Jon's films flash the whole frame for a
frame or two): the flash loses its frame-wide floor and is capped at 0.35, so what is left is
a glow round the event; R12's two-frame full negative becomes a four-frame dithered crossfade.

The shake noise is the films' `smooth_noise` with its rolled frequencies and phases copied
out (seeds 1 and 2 at 15 Hz), so the game shakes the frames the films shook.
