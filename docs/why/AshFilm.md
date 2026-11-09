The reasoning behind `tkg/scripts/sim/AshFilm.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## A.S.H. film

Above `var _args: PackedStringArray`:

```text
A.S.H. IN A RUN, filmed with its sound, her lines coming at their own moments
and her own limits deciding when (`Ash`):
  godot --path . --resolution 1920x1080 --write-movie <dir>/film.avi --fixed-fps 30
      -- sheet=AshFilm ash [seed=N]
A new run: LOCAL as the ship comes in, and her launch line once it is at
rest. A fight with a pirate cutter, the hull already worn (`hull=` share,
0.32): a turn of skills, END TURN and its volley -- the hull drops under a
quarter -- and on the next turn the hull-failing line (a big moment: it does
not wait out the quiet). Attacks until the cutter dies; its wreck on LOCAL.
The wreck opened and its credits taken (a chit of HAUL_CREDITS and more is
put in it), the window shut, and her big-haul line when the quiet after the
last one is over. Each line in her voice: the lines with no take yet are
left out of her picks. Every clock is the game's (`GameClock`, timers), so the
movie writer's frames are true speed. Prints `mark <what> <seconds>`.
```
