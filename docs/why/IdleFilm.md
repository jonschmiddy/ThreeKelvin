The reasoning behind `tkg/scripts/sim/IdleFilm.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Idle film

Above `var _args: PackedStringArray`:

```text
YOUR IDLE, SEEN AND HEARD, for Jon to hear the bed where it plays:
  godot --path . --resolution 1920x1080 --write-movie <dir>/f.png --fixed-fps 60
      -- sheet=IdleFilm [mode=arrive|fight] [hold=4] [seed=N]
Godot's movie writer writes every frame and the game's own mix (`f.wav`) on
the game clock, so it plays back at true speed.
  arrive  a new run's first arrival on LOCAL: the name card, the drive, the
          clean burn, the coughs sputtering down to the idle, then `hold`
          seconds parked.
  fight   a fight with a cutter: it flies in, one card played, then `hold`
          seconds of the turn standing.
Prints `mark <name> <seconds>` for the edges, with the bed's state.
```
