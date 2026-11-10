The reasoning behind `tkg/scripts/ui/SceneZoom.gd`; each heading is referenced from the code by a `Why:` line.

## One camera for every push-in

Above `var _scenes: Array[Control] = []`:

```text
THE CUTAWAY'S CAMERA, LIFTED OUT. `CutawayView` zooms LOCAL's scene round your
ship when it opens: each scene control (the event's subject, the row of ships
and wrecks, the dust, the effects) is scaled about one point and moved so that
point lands where the opened ship is drawn, and the sky's layers zoom by their
depth (`LocalSky.set_zoom`). The loot view (stripped-down UI A2, Jon, Nov 9)
wants the same move with a different subject: a wreck, or your ship for the
system's pile. So the move is one helper with the subject as an argument,
rather than a second copy of the cutaway's arithmetic that would drift from it.

It restores by OFFSETS, not position, for the cutaway's reason: a window
resized while the camera is in puts an anchored control back where its anchors
say for the new size, where a stored position would put it back wrong.

`CutawayView` still carries its own copy of this arithmetic: it also hides
LOCAL's hull, lifts the yard's parts off it and slides the elevator out, and
moving all of that onto the helper is a refactor for its own day.
```
