The reasoning behind `tkg/scripts/ui/PanelSlide.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Panel slide

Above `static var live: Array = []`:

```text
A SCREEN'S OWN PANEL SLIDING, drawn as it is (Jon, Oct 18: "the panels should
be drawn in as they are coming into the frame, they come in blank now and
that's not good looking"). The calm move (`ZoomLadder`) carries the map's or
the chart's real side bar off to the right, or its toolbar row up, into
LOCAL, and on again out of it, with everything on them -- the title, the
text, the list, the buttons -- drawn the whole way: the control itself is
moved, never a picture of it nor an empty plate. Over the field (`NavField`)
it is glass sliding over the stars.

The control stays in its container: its place at rest is the one the
container gives it, and the slide's offset is put back on top of that every
time the container lays its children out again, so a panel whose contents
change as it moves still slides from where it will rest. The screen it is on
clips it at its own edge while it moves.
```
