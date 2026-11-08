The reasoning behind `tkg/scripts/sim/CoreFightFilm.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Core fight film

Above `var _t := 0.0`:

```text
THE CORE'S HOLE WHERE JON WILL SEE IT, in one look (`LocalSky.core_look`),
filmed with its sound:
  godot --path . --resolution 1920x1080 --write-movie <dir>/f.png --fixed-fps 60
      -- sheet=CoreFightFilm look=<a|b|c> out=<dir> [seed=N]
LOCAL at the core with your ship (the Custodian is not on LOCAL before you
ENGAGE: the core draws no place picture and its encounter stands nothing
there); ENGAGE (`Router.engage_here`), the Custodian's fight as the game opens
it, its fly-in and a held look; the kill, played through `Combat.play` with
its hull cut to one; its death; the fight ending into LOCAL, its body there.
Prints `mark <name> <frame>` for each (frames drawn, which the movie writer
numbers its pictures by), and once the fight is up writes `<out>/ink.png` and
`<out>/ink.json`: the Custodian's picture as its slot draws it and where
(game frame px), and the hole's centre and shadow radius, for the overlap.
Every clock is the game's, your hull's bob too (`ShipView.shot_clock`).
```
