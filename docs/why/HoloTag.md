The reasoning behind `tkg/scripts/ui/HoloTag.gd`.

## One tag

Above `class_name HoloTag`:

```text
STRIPPED-DOWN UI T1 (Jon, Nov 9, from Shroom and Gloom): every tooltip in
the game was Godot's bevelled panel at the cursor with a CAPS title, a blank
line and the text wrapped at 32 letters, and three hand-drawn framed boxes
beside the thing (the chart's star, the map's body, the badge). Shroom and
Gloom has one tag sitting on the thing, one sentence. This is that tag, in
the box Jon picked: a hologram. First a torn black tag; then, on "it would
be cool if the borders of the tool tips were more sci fi", twenty boxes
drawn and animated (ten ideas, then ten takes on the hologram) and
rendered for him, and he picked 14 GLITCH from the close-ups (Nov 9). The
other nineteen are gone from the code.

The box: a near-black fill (FILL) with one dark scanline row in three
(SCAN), a 1 px mint edge (EDGE, the game's one highlight colour) with a
faint glow outside it (its outer pixel at a quarter, corners clear so it
reads as light, not a frame), the 8 px face in ICE, 6 and 5 px of padding,
11 px a line, and a 3 px pixel arrow off the edge that fills GAP and points
at the thing (`point`: 1 above it, -1 below). It opens in OPEN = 0.2 s: the
whole tag flickers (alpha 1, .45, 1, .6, 1 at 0.04 s a step), the scanlines
wipe down, the arrow blinks in, and a 3 px band of the box is drawn again
4 px to the side for a frame. Open, the scanlines crawl a row every 0.4 s
and the tear shows for one frame at the end of every 3.5 s. Everything is
whole pixels and whole-pixel steps on GameClock (the movie writer runs the
wall clock fast); the box never moves or changes size, so the words never
move; nothing bevels or presses (a tooltip is not a button). Drawn with an
age of INF it is the still frame, which the chart's and the map's
hand-drawn tips use.

`place` puts it centred above the thing with GAP clear, below when there is
no room above, slid inside the screen, never over the thing while both fit:
the tag must not cover what it describes (fit-means-nothing-overlaps).

Three faces: a Control (the layer's tooltips, T2's keyword tags), the static
`draw_tag` for the chart's and the map's tips, which are drawn by hand in
their own `_draw` and pass the arrow's direction, and `plate`, the same box
as a tiled StyleBox for the plates that wrap a rich body (a part's readout,
the badge's lines), with `TagLayer.PlateArrow` drawing the arrow on those.
`UITheme.build` takes a copy of the plate for Godot's own (switched off)
tooltip, so its margins never reach the shared one.
```
