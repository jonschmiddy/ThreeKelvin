The reasoning behind `tkg/scripts/sim/RunStartFilm.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Run start film

Above `var _t := 0.0`:

```text
A NEW RUN FROM THE HULL PICK TO ITS FIRST FIGHT, filmed with its sound:
  godot --path . --resolution 1920x1080 --write-movie <dir>/f.png --fixed-fps 30
      -- sheet=RunStartFilm [manufacturer=solari] [weight=medium] [seed=N]
The chassis select as the title opens it, the manufacturer's row pressed, a
breath on its detail, LAUNCH; LOCAL as a new run lands on it; then a jump to
the next system, where something is waiting (the ambush `FightOpenFilm`
films), the fight opening and the starter gun fired once.

A manufacturer past Korvan is locked until a win with the one before it
(`Unlocks`), so the harness's own scratch flight record (never the player's)
is given that win first: this is the hull pick of a player who has earned it.
Every wait is in game seconds (`_process`), never the wall clock: the movie
writer runs the clock at its own rate. Prints `mark <name> <frame>`.
```
