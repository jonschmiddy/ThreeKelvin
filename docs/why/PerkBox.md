The reasoning behind `tkg/scripts/ui/PerkBox.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Perk box

Above `func _make_custom_tooltip(_for_text: String) -> Object:`:

```text
The perk names in the masthead's corner, and the one panel that explains them.

A NODE OF ITS OWN because `_make_custom_tooltip` is a method: a plain
VBoxContainer cannot be handed one, and a wrapped string is a poor way to
show four perks in two groups. Every other rich tooltip in the game is built
exactly this way — see `ModuleIcon` and `CardView`.

READS `Run.hull` rather than holding a reference, because the hull changes
under it: a chassis swap rebuilds the labels and this must not go on
describing the frame that was sold.
```
