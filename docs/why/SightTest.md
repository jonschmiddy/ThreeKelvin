The reasoning behind `tkg/scripts/sim/SightTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Sensor checks

Above `func run() -> void:`:

```text
What a dish actually shows you:
  godot --headless --path . -- sighttest

THREE CLAIMS FROM A SCREENSHOT, priced. Reported as "a ship with 0 sensors
sees this far -- kinda crazy", "no matter what the thrusters/sensors are the
circle is the same size", and "still drawing systems outside sensor range".

The first two are tuning and the third is a filter question, and none of them
can be settled by looking at one chart: how many systems a radius covers
depends on where you are standing in a galaxy whose density falls off with
depth. So it is measured across seeded galaxies at real positions.
```

## Reachable not sensed

Above `func _gap() -> void:`:

```text
Can a system be REACHABLE and not SENSED?

That combination is what the chart's jump button reports as "NOT ENOUGH FUEL",
because `can_jump_to` is `sensed and reachable and afford` and the screen's
if-chain treats anything left over as an affordability problem. With 279 fuel
and a 6-unit cap that message cannot be literally true.
```
