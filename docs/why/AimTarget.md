The reasoning behind `tkg/scripts/ui/AimTarget.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Aim preview

Above `func aim(on: bool, text: String = "") -> void:`:

```text
Light up under an aimed line, with what the card would do written on it.

The same `_hot` and `_drag_text` the drop path set, driven by the screen
instead of by the engine. `set_drag_preview` pinned the card over the target,
so the figure appeared at the exact moment the thing it applied to went
behind a 112x160 card; the line leaves the board visible and this puts the
number back on it.
```
