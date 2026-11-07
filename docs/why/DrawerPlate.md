The reasoning behind `tkg/scripts/ui/DrawerPlate.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Drawer plates

Above `const PLATE_H := 40.0`:

```text
The drawers' buttons: the escape menu's and Settings'. A chamfered plate,
drawn rather than composed from styleboxes, because a chamfer, a pixel icon
and text that all change colour together on hover are one drawing, not four
nodes to keep in step.

Two shapes. A PLATE is a menu line -- a doubled-pixel icon, a label, and a
second line saying what the choice does (Jon's pick: chamfered + two lines).
A CHIP is one choice among several, one line, centred; the one in force is
edged in ember like RESUME, so "what is set" reads the same as "where Esc
goes".
```
