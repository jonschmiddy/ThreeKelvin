The reasoning behind `tkg/scripts/sim/FirstRunFilm.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## First run film

Above `const READ_WPS := 4.0   # 240 words a minute, a quick adult reader`:

```text
A NEW PLAYER'S FIRST RUN, filmed: from the title screen to the first
fight won and its wreck looted, clicked the way a new player clicks. Made for
the tutorial audit (Oct 17) and kept as the sheet that re-films it, so a
change to how the game teaches itself is measured against the same seed and
the same bot. Run under the movie writer for a film with sound:
  godot --path . --resolution 1920x1080 --write-movie <dir>/film.avi --fixed-fps 30
      -- sheet=FirstRunFilm welcome hints asrelease out=<dir> [seed=N]
Prints `mark <name> <frame> <game_s>` at each teaching moment and writes
`<out>/marks.json`: FIRST CONTROL (the ship stopped, the controls yours), the
first card, every click and which only put something away. Reading pauses are
modelled at READ_WPS words a second: the welcome note skimmed, each hint and
the goal line read in full, then the click the player was going to make
anyway. The pointer is a software arrow (CombatClip's), since pushed events
move no hardware cursor. Needs a window.
```
