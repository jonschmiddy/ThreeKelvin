The reasoning behind `tkg/scripts/sim/SystemDump.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## System dump

Above `func _choice(c: Dictionary) -> Dictionary:`:

```text
Real systems, written out as JSON, for laying out the system map against the
game's own data:  godot --path . -- systemdump=<path> [seed=N]

Six of them, chosen to cover the cases the map has to draw: a red star with
a gas giant and options, a station, a pulsar, a deep system holding an
exclusive group, a system inside a nebula, and the core. Each with its star
and sky facts, its place line, and every
option it rolled -- title, full text, tags, group, and each choice with its
check, cost and flags, and the text of one outcome (taken by running it, so
the run this harness made up is spent: it quits straight after).
```
