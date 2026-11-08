The reasoning behind `tkg/scripts/sim/FaunaTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Fauna motion

Above `const SkyWeatherS := preload("res://scripts/ui/sysmap/SkyWeather.gd")`:

```text
THE CUSTODIAN'S AND THE MEGAFAUNA'S OWN MOVEMENT, LIVE (`FaunaMotion`,
`EnemySlot._fauna_*`, the two hooks in `SectorScreen`), headless:
  godot --headless --path . -- sheet=FaunaTest
One: the cut, for each of the three, at full size and from a half sheet (the
picture sampled the way `tools/enemy_sprites.py` makes them): it finds its
parts and lights; idle moves something within six seconds; the wind-up
(the Custodian's charge, a creature's strike) takes it further -- the charge
lit full, the swell to its deepest; `settle()` is back at rest in four frames
or fewer and then draws the very picture it was cut from.
Two: the real fight, animated (`Router.animate_in_harness`), on each of the
three: the slot's art hands its picture to the motion (its texture off, the
motion a child of it) and takes its bob from the motion's steps; the
Custodian's Charging intent winds it up and another intent lets go; a
creature's attack, played through END TURN, winds it up a third of a second
before the shot leaves (wound up when it does); a kill settles it
before the breakup is cut (at rest on the frame the art is hidden), and the
dead slot is the art's own wreck again, no motion left. With reduced motion
there is no motion at all.
No pixels are looked at here (headless draws nothing): the flicker and the
hand-off to the pixel are `-- sheet=FaunaSheet`'s, in a window.
```
