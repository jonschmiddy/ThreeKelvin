The reasoning behind `tkg/scripts/sim/HintShot.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Hint shot

Above `const HINT_S := 0.5`:

```text
THE FIRST-RUN HINTS AND THE GOAL LINE IN PLACE (`Hints`, `GoalLine`), one
still each as the game draws it:
  godot --path . --windowed --resolution 1920x1080 -- sheet=HintShot hints keepwindow out=<dir>

`hints` turns them on under the harness (the seen flags go to the harness
settings file, which this resets first). It walks the real screens:
  - LOCAL as a new run hands it over: the goal line and its first step;
  - the chart: its hint, and the step as it reads there;
  - the sector map after a jump, with events: its hint, and the next step;
  - LOCAL at an event's derelict, a loaded wreck and a pile: the band LOCAL
    opens there (as GO does, Jon Oct 21) first, then NOT NOW, wreck, loot;
  - the cutaway; the event band again, its text arrived and its choices up;
  - a wreck's window (salvage);
  - a fight: the hand, END TURN with nothing left to play, then turn 2's
    intent, heat and brace (held over the turn);
  - a station (dock), its decks the first time each is open, the shipyard's ship;
    the chart with the tank short (fuel).
Each still is the whole window (`<n>_<id>.png`, so 1080p at that resolution),
taken `HINT_S` after the hint shows, then it is dismissed with a click as a
player would. A hint that never shows is printed as `[hintshot] MISSING <id>`.
The deep tutorial's lessons (Oct 22) come up on the way and are passed.
Needs a window.
```
