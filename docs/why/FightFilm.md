The reasoning behind `tkg/scripts/sim/FightFilm.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Fight film

Above `const SkyWeatherS := preload("res://scripts/ui/sysmap/SkyWeather.gd")`:

```text
A WHOLE FIGHT, PLAYED TO ITS END, for a full-screen film with its sound:
  godot --path . --resolution 1920x1080 --write-movie <dir>/f.png --fixed-fps 60
      -- sheet=FightFilm id=<enemy> [hp=6] [hold=2] [seed=N]
Godot's movie writer writes every frame of the window and the game's own mix
(`f########.png`, `f.wav`) at true speed. The fight, on one enemy alone:
its fly-in; a first turn of skills (nothing that hurts it), END TURN and its
move played out; a second turn of attacks until it dies -- the killing shot,
the death, the wreck, the hand lowering and everything easing into LOCAL --
then `hold` seconds on LOCAL arrived. The enemy starts on `hp` hull so the
second turn's attacks kill it; your hull is kept full. Quits at the end.
```
