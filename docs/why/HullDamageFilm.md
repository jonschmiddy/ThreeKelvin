The reasoning behind `tkg/scripts/sim/HullDamageFilm.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Hull damage film

Above `const SkyWeatherS := preload("res://scripts/ui/sysmap/SkyWeather.gd")`:

```text
A SHIP'S HULL MARKS FROM FULL HULL TO NEAR DEATH, IN A REAL FIGHT, FILMED
(hull damage looks, Oct 17: James, a playtester, on today's marks: "ships
can't really have holes in them"). Every hit goes through
`Combat.damage_enemy`, flies from your ship and lands through
`HitLayers.land`, as in play.

  one ship, cropped at 2x (the window is the game at 2x):
  godot --path . --resolution 1920x1080 --fixed-fps 30 -- sheet=HullDamageFilm
      id=<kind>[:<look>] hull=<today|A|B|C|D> crop=<dir> [boxtest=1]
  a pack of three and your ship, the whole window (with --write-movie):
  godot --path . --resolution 1920x1080 --write-movie <dir>/f.png --fixed-fps 30
      -- sheet=HullDamageFilm pack=<kind>[:<look>],<kind>[:<look>],<kind>[:<look>] hull=<...>

THE SAME HITS EVERY TIME: the ship's hull set to 100, then nine shots of
9 15 8 12 16 9 11 7 7 (94 in all, leaving 6), 1.1 s apart from 0.3 s, then
2.6 s held at 6 hull. A pack's three ships take the same nine, each a third
of a beat after the one before; your ship takes four shots of its own. The
kinds each hit rolls come from the fight's seeded stream, so a re-run is the
same film. `crop=` writes `c_####.png` every frame from 0.2 s before the
first shot (30 a second at --fixed-fps 30, so true speed), and prints the
crop (window px). `boxtest=1` (no film) draws every frame twice, the hull
marks shown and hidden, and counts the pixels of the ship's words, name and
bars that differ: they must not.
```
