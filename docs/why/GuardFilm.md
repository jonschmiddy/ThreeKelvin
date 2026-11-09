The reasoning behind `tkg/scripts/sim/GuardFilm.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Guard film

Above `const SkyWeatherS := preload("res://scripts/ui/sysmap/SkyWeather.gd")`:

```text
A CREATURE'S BLOCK, BRACE OR DAMAGE IN A REAL FIGHT, for a film (`FaunaGuard`).
  godot --path . --resolution 1920x1080 --write-movie <dir>/f.png --fixed-fps 60
      -- sheet=GuardFilm id=<leviathan|whale|custodian>
         def=<block|brace|guard|damage> [look=ship] [kind=0|1|2] [boxtest=1]
Through the real SectorScreen, one enemy: its fly-in, then (from the line
`guardfilm: start <frame>`, about 6 s):
  block   12 block gained; a 5 the block soaks (2.0 s); a 10 that breaks it,
          3 going on to the hull (3.6 s);
  brace   12 brace gained; 4 (1.7 s), 4 (2.9 s), then 6 that spends it, 2 to
          the hull (4.1 s);
  guard   12 brace and 10 block gained; a 6 the block soaks (1.8 s); an 8
          that breaks it and goes into the brace (3.2 s); a 6 (4.6 s); a 6
          that spends the brace, 4 to the hull (5.8 s);
  damage  from full hull, eight shots of 11.5% each, 0.8 s apart, to 8%
          (the kinds rolled as in play; `kind` forces one).
Shots go through `Combat.damage_enemy` (your ship fires, the volley lands,
`HitLayers.land`). `look=ship` turns the creature looks off (the ship
looks). Prints the crop (window px: the ship, its words
and its readout), each guard's shape changes per half second, and with
`boxtest=1` (no movie) compares the words' pixels with the guard drawn and
hidden, every 0.1 s: they must be the same.
```
