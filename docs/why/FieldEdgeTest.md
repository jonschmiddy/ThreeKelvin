The reasoning behind `tkg/scripts/sim/FieldEdgeTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Test purpose

Above `var _fails := 0`:

```text
NO BOX ROUND THE PICTURE (Jon, Oct 18, of the star chart on the one field:
"The new field is close, but why is there a box around the galaxy panel?").
Windowed -- it reads the pictures as drawn:
  godot --path . --resolution 1920x1080 -- sheet=FieldEdgeTest [out=<dir>]
At rest on the sector map and on the star chart, the picture's former edges
(left, top and bottom; the side panel stands on the right) are read in strips
straddling them, 24 px either side, row by row (or column by column) as the
median of each line: the screen as drawn less the field as drawn alone
(`NavField.picture`). Inside the edge and outside it the two must agree --
no line, no step in the ground's tone or colour, nothing the picture adds at
its edge -- to within the field's own line-to-line variation, and the lines
either side of the edge never differ by more than the field's own step
there. `out=`: each strip written beside the screen, as PNGs, for a look.
In every style (`style=legacy|simplified|painted|radiant`, the game's own
switch) and in a system inside a cloud (`at=nebula`: the map's cloud runs
past its picture, cloud:A -- the edge is then read against the gas either
side of it, not the field). And LOCAL's stars ARE the field's (styles:now):
on LOCAL at rest, where the field has a star, LOCAL draws it there.
```

## Cloud past the picture

Above `func _cloud_past() -> void:`:

```text
THE CLOUD PAST THE MAP'S PICTURE IS THE CLOUD GOING ON (Jon: "the mirror is
visible"): the map's sky ends under the side panel; past it the same cloud is
drawn on (`SystemView._past`, the cloud's own material, read by `nav_ext`
with `past_on`), not a mirror or a copy of gas from elsewhere. Where the
strip starts over the picture's last 32 px it is the same gas, drawn the
same way: its light follows the picture's there (correlation 1.00 in
SIMPLIFIED and LEGACY on seed 4242's cloud; the picture's own gas mirrored
there 0.25, moved 16 px 0.19-0.34; the cloud alone without the sky and dust
sheets under it 0.24-0.57) at its level (within 2).
```

## Cloud hop

Above `func _cloud_hop() -> void:`:

```text
A CLOUD MADE SMALLER HAS NO STRAIGHT SIDE (Jon: "is there any way to have it
be less of a square when zooming out?"): the map in a cloud to the chart,
every frame the held cloud is drawn smaller and still half there, the cloud
as drawn (brighter than the field by 12 levels, the plates and the HUD left
out) found, and along its bounding box's four sides, 4 px in, how much of
each line is cloud: a rect would fill them; a cloud thinning out does not.
```

## Galaxy past the picture

Above `func _chart_edges() -> void:`:

```text
THE GALAXY RUNS ON PAST THE PICTURE (Jon: "why does a galaxy disappear near
the side panel?", "And also disappear in the corner?"): the chart's galaxy
set across each of the picture's four old edges in turn (its centre on the
edge's middle), and along each, in a band from 20 px inside to 24 px past it
(where it is open: clear of the field's own edge and its fade there, of the
plates, the words and the buttons), how much of the sky as the chart drew it stands on
the screen where the galaxy is bright -- the screen less the field over the
sky less the field, the median of each line. A picture cut or faded at its
old frame falls to nothing there; drawn on past it, every line is the sky's.
```

## See-through plates

Inside `_check()`, above `var words := _ui_rects(cur)`:

```text
(the picture's frame was 12 px of margin round it, then a line)
THE PLATES SEE-THROUGH (Jon, Oct 18: "make both panels slightly see
through like the other panels"): over the toolbar row's plate and the side
panel's, clear of their words, the screen follows the field under it by
about 1 - `NavField.PLATE_A` (fitted: the slope of the screen's luminance
on the field's)
```
