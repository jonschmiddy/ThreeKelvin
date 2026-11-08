The reasoning behind `tkg/scripts/ui/DeathHandoff.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Death handoff

Above `const SHADER := preload("res://shaders/death_handoff.gdshader")`:

```text
FROM THE WRECK TO RUN ENDED (Jon, Oct 13: "the transition from this to this
is really abrupt"). It was a cut: the fight holding your wreck, then on the
next frame the RUN ENDED panel over a different sky with a planet in it.

Three ideas, one picked by `SectorScreen.DEATH_HANDOFF`:
  A  LINGER AND FADE: the hand lowers as it does on a win, and the whole
     picture, HUD and all, darkens and drains over 1.2 s with the wreck in
     view; RUN ENDED then fades and rises in over that picture.
  B  PULL BACK: the hand lowers, and LOCAL's own camera pulls back the way
     the one-camera move to the map does (`ladder_cam`): the wreck drifts
     small in the field as it dims; RUN ENDED fades in over that.
  C  SIGNAL LOST: the picture degrades like a dying feed -- scanlines
     thicken, colour drains, bands tear -- and collapses to a dim line; RUN
     ENDED then types in on the dark screen.
The last frame is kept (`still`) and RUN ENDED is drawn over it
(`GameOverScreen.setup`), so nothing is swapped under the panel.

Over everything in the game's picture, HUD included, and taking every click
until the panel's buttons are up.
```
