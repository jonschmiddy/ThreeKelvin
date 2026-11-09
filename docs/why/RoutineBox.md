The reasoning behind `tkg/scripts/ui/RoutineBox.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## The routines row on the ships

Above `func _make_custom_tooltip(_for_text: String) -> Object:`:

```text
THE ROUTINES ROW on the ship's left panel (science, Phase 12): one line,
"ROUTINES · 4 OF 9", and the one panel that names them on hover.

ONE LINE, NOT A LIST (plan open call 8): a heavy with malfunctions is the
fullest panel there is, and nine names wrapped under its perks pushed the
gaps between its blocks under `CutawayView.GAP_MIN`. The count is what a
glance wants; the names and what each does are a hover away.

APART FROM THE PERKS, on purpose. A perk is the hull's and goes with it at a
yard; a routine is the flight computer's and stays (SPEC: "so you can see it
stay after a swap"). `ShipScreen.fill_perks` stays the hull's only, and
`ShipScreen.fill_routines` fills this.

A NODE OF ITS OWN for the reason `PerkBox` is one: `_make_custom_tooltip` is
a method, and READS `Run` when asked rather than holding a list, because the
routines change under it (a step bought at a Lab).
```
