The reasoning behind `tkg/scripts/ui/FpsMeter.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Frame meter

Above `const TICK := 0.25`:

```text
Frames per second, bottom right.

RESTORED AS AN OVERLAY, and the overlay part is the whole point. There was a
frame counter on `HudBar` until `872f546` removed it, and that commit is worth
reading before putting one back — it was not removed for being useless, it was
removed for being A CHILD OF THE ROW:

  "It was the last thing on the row, so it was what the row lost when the row
   ran out — clipped at a standard window size... Reserving its width put the
   row at 948 against 944 available and it was STILL clipped."

And the reason nobody caught it earlier, which is the good part: its label was
built empty and filled by `_process`, so its minimum width at build time was
NOTHING. The row fitted, and then the first frame put "120 FPS" into space
nobody had allocated.

So this is not on the row. It is top-level, positioned against the viewport,
and takes part in no layout at all — the bar cannot lose fifty pixels to
something that never asks it for any.

A SETTING, NOT A DEV FLAG. It rode on `DevMode` for one commit, which meant a
player could not read their frame rate without also unlocking the card gallery
and the whole star chart — DevMode's own tooltip says exactly that. A frame
counter is a diagnostic, not a cheat: a tester reporting "the chart felt
choppy" is worth far more with a number attached, and that should not cost
them the game's secrets. `DisplaySettings.fps_meter` owns it.

BUILT ALWAYS, SHOWN CONDITIONALLY, so the toggle takes effect immediately
rather than at the next launch.

THREE READINGS, AND THE LAST IS THE ONE THAT FINDS A HITCH: the rate, what
an average frame took, and the slowest single frame of the last second
(`60 FPS  16.7 MS  WORST 41.2 MS`). A rate is an average, and an average
hides the one long frame a player feels as a jolt: a second of fifty-eight
16 ms frames and one of 70 ms reads 59 FPS. The Mac investigation (Oct 27)
asked a tester to read this meter and found it could not show a spike at
all, so it does now. Both are in milliseconds because the thing a player is
reporting is a cost: 60 to 40 FPS sounds like a third gone and is 8 ms added
to a 16 ms frame.

ONE LINE, IN THE WINDOW'S BOTTOM MARGIN. Every screen sits inside Main's
margin, which stops 7 px short of the window's bottom edge, so the frames
end there: the bottom bar's line is row 532 of 540 on LOCAL and in a fight,
the yard's panel line row 528. The figures go under all of it, on rows 534
to 538, a row clear of the frames and a row clear of the window's edge.
Twice it sat inside the frame: a second line rose onto SCAN SECTOR and
DISCARD, and the first one-line reading (Oct 27, figures on rows 529-533)
ran through the bar's 1 px line for all 158 px of it, past a box test that
only looked at text. `-- sheet=MeterFitTest` checks the ink against every
text, frame and edge on each screen.
```

## Placement

Inside `_process()`, above `var vp := get_viewport_rect().size`:

```text
PLACED EVERY TICK RATHER THAN ANCHORED. A top-level Control is excluded
from its parent's layout, and that also means no anchor preset is applied
to it — so the corner is arithmetic. It has to be redone each tick because
the width changes when the reading goes from two digits to three.

BOTTOM RIGHT, under every screen's frame. The top right is the HUD row:
CARDS, MODULES and HISTORY run to within a few pixels of the edge, and
that crowding is precisely what got the last frame counter deleted. The
margin under the frames holds nothing else (`-- sheet=MeterFitTest`).
```
