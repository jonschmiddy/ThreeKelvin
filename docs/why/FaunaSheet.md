The reasoning behind `tkg/scripts/sim/FaunaSheet.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Fauna film

Above `const SkyWeatherS := preload("res://scripts/ui/sysmap/SkyWeather.gd")`:

```text
THE CUSTODIAN AND THE MEGAFAUNA MOVING, filmed in the real fight
(`FaunaMotion` as `EnemySlot` wires it; nothing is overlaid by this sheet).
  godot --path . --fixed-fps 30 --windowed --position 3840,0 -- sheet=FaunaSheet
      out=<dir> [which=custodian,whale,leviathan] [today] [custodian=<png>]
      [secs=11.5] [seed=N] [restcheck]
For each enemy, a fight opened on it alone through `Router.start_combat`,
its fly-in waited out, then `<out>/<enemy>/f_####.png`, the game's own
960x540 picture, a frame every 1/30 s:
  0-4 s     idle;
  4 s       the Custodian's intent set to Charging... (6.5 s: its next); a
            creature's turn played through END TURN, so its attack strikes;
  8 s       the kill: its hull cut to one and a card played at it, through
            `Combat.play`, until it dies -- the motion settles, the breakup
            is cut, the wreck is left.
`today` films the same with `FaunaMotion.enabled` off: the still picture on
the slot's bob, as the game was. `custodian=<png>` wears that picture on The
Custodian by putting it in the resource cache under the name the index would
give it (take 1 lives on fix/pack-layout until it merges); nothing on disk
changes. Each folder gets meta.json: the frames each beat happened on (the
motion taking over, the wind-up, the kill, the settle, the cut), and the
motion's CPU a frame (`FaunaMotion.cost_us`).
`restcheck` films nothing: on each enemy, idle, it settles the motion, then
photographs the motion at rest and, the next frame, the art's own picture in
its place, and prints how many of the canvas's pixels differ (the bob
allowed its step between the two): 0 is a death cut from exactly what was
on screen.
```
