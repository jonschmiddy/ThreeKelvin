The reasoning behind `tkg/scripts/sim/GradeSheet.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Grade sheet

Above `func _arg(k: String, d: String = "") -> String:`:

```text
ONE HULL, FOUR GRADES, in each of HullGrade's looks, as PNGs for a pick page:
  godot --headless --path . -- sheet=GradeSheet out=<dir> [weight=medium] [base=a] [manufacturer=korvan]

`base` is which of today's four sprites is the one hull (c, b, a, s). Writes
`<look>_<grade>.png` (A_c ... C_s, and the mixes AB, AC, BC, ABC) at the sprite's own size, today's four as
`today_<grade>.png`, and prints each bake's colour count against the base's:
a bake may only use colours the base already has.
```
