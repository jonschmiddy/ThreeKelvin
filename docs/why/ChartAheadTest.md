The reasoning behind `tkg/scripts/sim/ChartAheadTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Chart built ahead

Above `const SEEDS := [4242, 11, 777]`:

```text
THE RUN'S STAR CHART BUILT AHEAD, headless:
  godot --headless --path . -- sheet=ChartAheadTest

A new run builds its chart's star field on a worker while the hull is picked
(`MapChart.build_ahead`, from `Router.new_run`), so the first STARCHART or Tab
does not stand still for the build. On three galaxies, through the real doors:

- the chart the player opens is laid out at `MapChart.CHART_AT`, the size the
  field is built for: a layout that moves the chart fails here, instead of
  quietly building the field on the click again;
- opening it builds nothing on the main thread: the field built ahead is the
  one drawn, and it is the field the chart would have built itself, list for
  list (`SKY_FIELDS`), read off Run as before;
- THE WORKER READS ONLY ITS COPY: built while the main thread writes another
  galaxy over Run (as the title does with its own) and asks the clouds of that
  one, it still comes out the run's galaxy exactly; and it is not handed to a
  chart of the other galaxy;
- no engine error, worker or main thread.

And the shaders the title compiles ahead (`ShaderWarm`) are the very ones the
map and LOCAL draw with (the same resources, so the same programs), and none
of it starts headless; and no compile starts within its QUIET_MS of the
player's last input, the title's own included (seen before the warm began),
nor in the first QUIET_MS after it arrives.
```
