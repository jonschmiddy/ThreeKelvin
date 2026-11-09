The reasoning behind `tkg/scripts/sim/ShowcaseDump.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Showcase dump

Above `var out := "user://showcasedump"`:

```text
The star chart's galaxy as raw data, for prototypes drawn outside the game:
  godot --path . -- sheet=ShowcaseDump out=<dir> [kinds=0,8,16]

For seed 4242 and each kind asked for (forced as ChartLook's `kind=N` does
it: roll the kind, lay the map out again), writes <dir>/raw_kind_NN.json:
the rolled galaxy, the sky's own constants (`ChartSky.params`), the chart's
geometry, every point of the chart's star field (drawn pixels at zoom 1,
the galaxy's own squash, colours as indices into a table) and the turning
core's points, the named clouds with their lobes, the globular clusters,
the pulsars, every system with its links, YOU and the Hellbender.
Nothing is drawn or photographed; GalaxyDump and ChartLook do that.
```
