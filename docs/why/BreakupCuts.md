# BreakupCuts

Reasoning moved out of `BreakupCuts.gd`'s comments; the rest of the breakup's is in `ShipBreakup.md`.

## Melt and crumple

Above `static func _melt_pic(H: Dictionary, seed: int, k: float, given: Dictionary = {}) -> Dictionary:`:

```text
MELT at `k` (0 whole, 1 slumped): the hull goes soft. Every pixel is fetched
from a little further out and a little aside, so the hull draws in toward its
own middle line and its outline wanders; the far edges (fins, guns) wander
most. Thin parts with fewer than two neighbours run off, pass by pass -- those
are the drips. Then the colours run together. Deterministic in `seed`, so the
film's steps and the wreck agree.
```

Above `static func _crumple_pic(H: Dictionary, seed: int, k: float) -> Dictionary:`:

```text
CRUMPLE at `k`: two or three fold lines across the hull; the segments
between them are shoved toward the middle, kicked up and down in turn and
sheared, so the plates stair-step like bent metal. Each fold gets a dark
crease on one side and a lit ridge on the other, and each segment a buckle
down its middle. Returns which segment every pixel landed in, for the cut.
```

## Rib seams

Above `static func _rib_curves(H: Dictionary) -> Array:`:

```text
H3's rib seams, traced off the picture: the luminance smoothed down each
column (the ribs run near vertical, so this keeps the seams and loses the
plating's grain), its dips along each row, and the dips linked row to row
from the middle outward into curves. A curve that does not reach half the
hull's height there is grain, not a seam. Each curve: `traced` (its x per
row, -1 where it was not found) and `full` (carried on to every row, so a
cut runs the whole height).
```
