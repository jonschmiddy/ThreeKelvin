The reasoning behind `tkg/scripts/sim/CoreLookFilm.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Core look film

Above `func _ready() -> void:`:

```text
LOCAL AT THE CORE, filmed (its hole as the world you orbit, `LocalSky`):
  godot --path . --resolution 1920x1080 --write-movie <dir>/f.png --fixed-fps 60
      -- sheet=CoreLookFilm [secs=4]
Opens LOCAL at the core the way the sector map does (`Router.show_local`),
waits two seconds for the sky to come up whole, prints the frame the film
proper starts on, holds `secs` seconds and quits. Every clock in the picture
is the game's (the sky's `t`, the hole's `step`), and the hull's bob is put
on it too (`ShipView.shot_clock`), so the movie writer's frames are true
speed however slowly they were drawn.
```
