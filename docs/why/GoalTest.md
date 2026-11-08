The reasoning behind `tkg/scripts/sim/GoalTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Goal test

Above `var _tree: SceneTree`:

```text
THE GOAL LINE (`GoalLine`), on the real screens, headless:
  godot --headless --path . -- sheet=GoalTest

Tutorial direction B (Jon, Oct 17): "GOAL: REACH THE CORE" always, and the
next step under it while one is pending, quiet and small, under the HUD,
never covering anything, and not looking pressable. Walked through a new
run as it is played: LOCAL at launch (open STARCHART, the tab outlined), the
chart (pick a star), the first jump (that step done), the sector map with
events (click one, then GO), LOCAL (open SECTOR), an event's band up (that
step done), a fight; and hidden over the cutaway and the escape menu.

WHERE (Jon, Oct 20): just below the map's and the chart's top plate, at
their picture's top left; on LOCAL snug under the HUD at the same left
("snug:B"); the step directly under it on all three.

THE BOX TEST, on every screen it shows on: its rect is inside the picture
and clear of the HUD, the side bar, every piece of the toolbar row, LOCAL's
event band and the bar under it, the hand, your hull, every enemy's hull and
the words over and under it, and an event's subject. The list is gathered
here, apart from `GoalLine.avoid_rects`, so the line cannot pass by agreeing
with itself. Written against the node by its name, so it runs (and fails) on
a build without the line.

The steps are tutorial, so they follow the hints (`Hints.enabled`): on here
by hand, in the harness settings file; GOAL shows either way.
```
