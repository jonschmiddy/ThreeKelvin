The reasoning behind `tkg/scripts/sim/ChartDeepTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Chart deep test

Above `var _tree: SceneTree`:

```text
TOO DEEP ON THE CHART, headless, through the real StarchartScreen:
  godot --headless --path . -- sheet=ChartDeepTest [depthcap=N]

Ruling 13 A (Jon, Oct 27). A star inside the reach ring that a jump refuses
because it lies deeper than one jump may go (`Run.too_deep_only`) looked
like any other until it was clicked; Geno met it near the top of the map,
where the tilted chart puts rings close together on the screen. Now it is
drawn dimmed. On three galaxies, the ship parked where stars in reach are
too deep and others are not, zoomed out (dots) and zoomed in (glyphs):

- every too-deep star in reach is drawn dimmed: its ink as drawn
  (`MapChart.drawn_ink`) has no colour in it and half its own star's value
  or less; zoomed in, every ink of its glyph is grey, lights and glass too;
  still so under the cursor and when picked;
- every star the ship can jump to is drawn in its own colour, lifted, and
  not dimmed;
- nothing else is dimmed: every star drawn dimmed is one the rule refuses
  for depth alone;
- its hover readout ends TOO DEEP, a reachable star's does not;
- picked, JUMP reads TOO DEEP and is off; a reachable star's does not.

The rule is read through `Run.too_deep_only` and `Run.reachable_from`, so
the sheet holds with any `RunState.DEPTH_STEP`. `depthcap=N` flies another
one for comparison (the study lever `-- sim depthcap` uses).
```
