The reasoning behind `tkg/scripts/ui/LegacyHole.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Legacy hole

Above `const BMAX := 24.0`:

```text
THE BLACK HOLE IN THE LEGACY STYLE, the CPU half of
`legacy_hole.gdshaderinc` (read its header for the interface): direction C's
hole from the Oct 5 showcase, Jon's pick for every style, on the star chart's
core and the sector map's core system.

The photon table is traced ONCE, here, and kept for the process: for each
impact parameter b (Schwarzschild radius 1) the orbit u'' = -u + 1.5 u^2
(u = 1/r) is integrated over the path angle, RK4, and the table keeps u at
every angle and, for a ray that escapes, how far it was bent. It depends on
nothing but the physics, so it is the same for every galaxy and every system.
Traced in GDScript it takes about a second, so it is shipped (`TABLE_PATH`,
written by `-- sheet=LegacyLensBake`) and only traced here when that file is
missing.

A material that includes the hole gets everything it needs from `apply`.
```
