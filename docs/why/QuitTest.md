The reasoning behind `tkg/scripts/sim/QuitTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Quit test

Above `var _tree: SceneTree`:

```text
Leaving a run from the pause menu, driven through the real screens:
  godot --headless --path . -- quittest

QUIT and SAVE & QUIT both end the same way -- `Run.hull = null`, then
`Router.show_launcher()` -- and the screen they leave is only QUEUED for
freeing, so it is still in the tree for the rest of that frame. Anything that
redraws it there draws a run with no ship in it. On the starchart that is
every reachable system asking how far this ship can jump: hundreds of
"Invalid access to property 'thrust' on Nil" in one frame, and nothing wrong
to look at, because the frame is never shown.

The two lines are run here rather than the pause menu's signals emitted. The
real QUIT handler also writes an ABANDONED run into the flight record, and a
test has no business putting runs in a player's history.
```

## Quit test waits

Inside `run()`, above `var chart: StarchartScreen.MapChart = null`:

```text
WAIT FOR THE CHART, DO NOT COUNT FRAMES AT IT. This was `for i in 3`, and
three frames is usually enough for the screen to build and usually is not a
test: it passed seven runs in a row and failed the eighth on the same
build. A bounded wait on the thing actually being looked for is the same
check without the race.
Wait for the starchart itself: until the swap lands, Router.current can
still be the launcher, whose backdrop is a MapChart with show_icons off.
The swap is timed in seconds and headless frames run fast, so the wait is
timed too (60 frames could end before a 0.13 s fade did, under load).
```
