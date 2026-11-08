The reasoning behind `tkg/scripts/sim/RegenTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Regenerate check

Above `var _fails: Array[String] = []`:

```text
The chart's REGENERATE GALAXY button (developer mode), pressed:
  godot --path . -- sheet=RegenTest [out=<png>]
Opens the star chart on a run, presses the button, and checks that a new
galaxy came of it -- a new seed, a map a new run would have (its start at 0,
its indices and links in range, its core present), the ship at the start with
its hull, credits and cargo kept, no contract left naming the old map -- and
that the chart was made again on the new galaxy, its sky baked for it.
Prints `regentest: PASS` or each failure. Needs a window (the chart bakes).
The button autosaves, so the run save on this machine is kept aside first
and put back after.
```
