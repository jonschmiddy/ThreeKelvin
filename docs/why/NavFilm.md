The reasoning behind `tkg/scripts/sim/NavFilm.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Navigation audit

Above `var _args: PackedStringArray`:

```text
NAVIGATION AUDIT (Jon, Oct 17: "the movement between local > sector >
starchart ... EXTREMELY disorienting"). Every move between the distances a
player can make, made the way a player makes it -- a HUD tab clicked with a
pointer, Tab pressed, the wheel turned -- filmed under the movie writer with
sound, and every frame's state logged beside it for measuring.
  godot --path . --resolution 1920x1080 --write-movie <dir>/film.avi --fixed-fps 60
      -- sheet=NavFilm reel=<ladder|journey|dock|session> out=<dir> flow=c asrelease [seed=N] [at=nebula]
Writes <out>/frames.jsonl (one line a process frame: the screen up, the
ladder's phase, where your ship is on screen in game px, which HUD tab is lit,
the side bar's and toolbar's opacity, the map's zoom) and <out>/marks.json;
prints `mark <name> <drawn> <t>` at each action. The pointer is a software
arrow (FirstRunFilm's), since pushed events move no hardware cursor.

FILMED AT TRUE SPEED. The ladder, LOCAL and the side bar's swap all run on the
process delta. Two clocks on the map and the chart read the wall instead
(which races ~13x under the movie writer), so this harness drives their own
overrides from the game clock every frame: the chart's `MapChart.clock_override`
and the map view's `hclock`, and it re-bases the map's `_glide` start onto the
game clock. Nothing in the game is changed.
```
