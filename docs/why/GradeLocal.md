The reasoning behind `tkg/scripts/sim/GradeLocal.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Graded hull

Above `var _args: PackedStringArray`:

```text
A GRADED HULL WHERE IT IS SEEN: your ship refitted to a Korvan frame at one
grade and parked on LOCAL, its lights live.
  godot --path . --resolution 1920x1080 --write-movie <dir>/f.png --fixed-fps 30
      -- sheet=GradeLocal [weight=medium] [grade=0..3] [hold=4] [seed=N] [manufacturer=solari]
`manufacturer=` flies that manufacturer's own chassis at the grade, its starter
kit on its own mounts and its flame from its own engines.
Prints `mark parked <frame>` so the film's held stretch can be cut out, and
the hull's art name and grade key, so a wrong base shows in the log.
```
