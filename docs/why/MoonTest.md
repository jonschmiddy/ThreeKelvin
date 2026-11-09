The reasoning behind `tkg/scripts/sim/MoonTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Moon exclusion

Above `var _fails := 0`:

```text
THE MOONS KEEP OUT OF WHAT IS STAGED, headless (`LocalLife`):
  godot --headless --path . -- sheet=MoonTest
Jon (Oct 11): a moon going round the world you orbit must never pass over an
event's subject, a station, or your ship during the dock. So:
 1. on every world with moons in a few runs' galaxies -- the station systems'
    among them, their side and the corridor your ship docks along standing
    there -- each moon's chosen orbit, run for ten minutes of quiet, never
    overlaps your ship, the station's side or the dock's corridor (a moon with
    no clear orbit hangs still where it always did); some moons go round;
 2. with an event's subject up, every moon holds still, and none is over any
    of the subject's pieces;
 3. in a fight, every moon holds still;
 4. through the dock (the ladder's move, the station waking, your ship going
    in), every moon holds still and none is over the station or your ship.
Places are the sky's plan's (`LocalSky.near_plan`), which is where the picture
puts them.
```
