The reasoning behind `tkg/scripts/sim/SensorDump.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Sensor dump

Above `func run(tree: SceneTree) -> void:`:

```text
Real galaxy data for the sensor-ladder study:
  godot --headless --path . -- sensordump

Writes `user://sensor_study.json`. Everything an outside tool needs to draw
what a given SENSORS rating shows you, taken from the running game rather
than reconstructed -- system positions, the galaxy's squash, the base radius
at a real node, and the constants sight and reach are built from.

The point is that the ladder is judged against the galaxy that ships. A
hand-made field of dots would answer a question about the dots.
```
