The reasoning behind `tkg/scripts/sim/MeterFitTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Meter fit

Above `const MORE := ["ship", "cards", "modules"]`:

```text
THE FRAME COUNTER CLEARS EVERYTHING ON THE SCREEN (`FpsMeter`, Settings'
FRAME COUNTER), on the screens a player sits on: the title, the star chart,
the sector map, LOCAL in orbit of a giant, a fight there, a city's yard, and
the HUD's SHIP, CARDS and MODULES:

  tools/dev/godot.sh --headless --fixed-fps 60 --path tkg -- sheet=MeterFitTest
  tools/dev/render.sh --path tkg -- sheet=MeterFitTest [out=<dir>] [screens=a,b]

FIT MEANS NOTHING OVERLAPS, AND A LINE IS SOMETHING. The three-reading meter
(Oct 27) passed a box test of every Label, Button, RichTextLabel and
TextureRect, and its figures still ran through the bottom bar's 1 px frame
line on LOCAL and in a fight for all 158 px of it: a frame is a Panel's edge,
and that test never looked at one. So this takes the meter's INK -- where its
figures are drawn, from the font's own glyphs, not the label's box, which
has empty rows above the capitals -- grown by one pixel all round, and fails
  * on TEXT whose box meets it (a Label, Button, RichTextLabel or LineEdit);
  * on an EDGE passing through it of anything that draws: a Panel's or a
    PanelContainer's frame or fill, a Button's, a ColorRect, a TextureRect, a
    NinePatchRect, a SubViewportContainer, a control that draws itself. Each
    rect is first cut to what its clipping parents let show, and an edge on
    the window's own edge is the window's, not a line;
  * when the ink touches the window's edge or runs past it.
On the title the build stamp is also put where an export puts it (under no
developer switch: `LauncherScreen._add_build_stamp`) and checked.

Headless it reads the rects (the gate's way). With a window it also writes
each screen with the meter on and off (`out=`), finds the ink in the pixels
(the meter's colour, where on and off differ) and fails unless it is the
ink the glyphs give, to the pixel, so the two cannot drift apart. It shrinks
the window to 1x and keeps it on top while it runs.
```

## Unhideable window

Inside `_run()`, above `DisplaySettings.set_scale(1)`:

```text
A WINDOW THAT CANNOT BE HIDDEN: a Mac stops drawing a window that is
covered or minimised, and every wait for a drawn frame then waits
for ever (the first run, Oct 27, stopped on the chart at 3x, a
window the size of the screen). The game view is 960x540 at any size.
```

## Past-picture sky

Inside `_hits()`, above `if c.name == &"GasPastPicture":`:

```text
THE MAP'S SKY DRAWN AGAIN PAST ITS PICTURE (`SystemMapScreen`'s
GasPastPicture, `nav_ext.gdshader`): a backdrop sized past the window
and faded at its edges, with no line anywhere (`FieldEdgeTest` leaves
it out too). The meter sits over it as it sits over the title's sky;
in the margin band it drew nothing at all (Oct 27, the map's stills).
```
