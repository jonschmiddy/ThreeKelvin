The reasoning behind `tkg/scripts/ui/TagLayer.gd`.

## One tag at the thing

Above `class_name TagLayer`:

```text
STRIPPED-DOWN UI T1 (Jon, Nov 9): tooltips are one sentence, at the thing.
Godot places its tooltip at the cursor and there is no hook to move it, so
this layer is the tooltip system: it turns Godot's off by raising the delay
setting out of reach (the viewport reads it live), watches the hovered
control each frame, and after DELAY (0.25 s, the number the badge used to
read from the setting) shows a `HoloTag` right above the control, clear of
it, inside the screen. The text comes through `get_tooltip`, so the
per-position hooks (a wreck's hull, a mount, a yard drone) still answer, and
a text that changes under a resting pointer rebuilds the tag.

The CAPS title line the old tooltips opened with is dropped here (`plain`),
so 90 call sites did not have to change for the tag to read as a sentence;
the texts that were two or three sentences were rewritten at their sites.
A control that builds a rich tooltip (`_make_custom_tooltip`: a part's
readout with its cards, a perk list, a routine list, a manufacturer's set
tip) keeps that body on the same plate (`UITheme.tag_plate`), placed the same
way: the numbers in those are what the tooltip is for.

Nothing shows while the mouse button is down or a drag is on, as before.
`hold_off` lets a screen keep this tag off a control that has a tag of its
own: a card in the hand (T2's keyword tags).
```

A part's readout (the body `ModuleIcon.tip_for` builds, tagged with the
`module` meta) is the one rich body with no plate and no arrow (Jon, Nov 9:
"remove the square border around the whole thing"); its row draws its own
shadows. Every other rich body keeps the box and the arrow.
