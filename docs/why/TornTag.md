The reasoning behind `tkg/scripts/ui/TornTag.gd`.

## One tag

Above `class_name TornTag`:

```text
STRIPPED-DOWN UI T1 (Jon, Nov 9, from Shroom and Gloom): every tooltip in
the game was Godot's bevelled panel at the cursor with a CAPS title, a blank
line and the text wrapped at 32 letters, and three hand-drawn framed boxes
beside the thing (the chart's star, the map's body, the badge). Shroom and
Gloom has one torn black tag sitting on the thing, one sentence. This is
that tag: a near-black fill (FILL), a 1 px grey edge (EDGE) that steps in a
pixel here and there from a fixed hash of the position so it never shimmers,
the 8 px face in ICE, 5 and 4 px of padding, 11 px a line. On the game's
dark scenes the grey edge is what shows it (the audit's note).

`place` puts it centred above the thing with GAP clear, below when there is
no room above, slid inside the screen, never over the thing while both fit:
the tag must not cover what it describes (fit-means-nothing-overlaps).

Two faces: a Control (the layer's tooltips, T2's keyword tags) and the static
`draw_tag` for the chart's and the map's tips, which are drawn by hand in
their own `_draw`. `UITheme.torn_box` is the same look as a StyleBox, for
the plates that wrap a rich body (a part's readout, the badge's lines).
```

## Tip looks

Above `static var look: int = 0` (and `class_name TipFrames`):

```text
Jon, Nov 9, after the torn tag landed: "It would be cool if we could have
the borders of the tool tips be more sci fi", then widened to the whole box
(fill, edges, corners), ten of them, each a different idea and not a tweak
of another; the words, the font and the placing unchanged. They are picked
by `-- tiplook=N` (Main reads it beside `btn=`; UiHighlightShot too) and
the default stays at 0 until he picks from
tk-scratch/ui-build/tips/tip_frame_options*.png.

Each look is a small pixel texture (8 to 18 px square, built once in
`TipFrames.box`) 9-sliced by a StyleBoxTexture, stretched for a flat fill
or tiled for a pattern (2 HOLO's scanlines, 6 SCOPE's dot grid), so one
drawing fits any text length in whole pixels and never blurs (the rule in
rect-drawn-frames-read-as-programmer-art). What a slice cannot carry (a
band along one side, a spine, a notch at the thing) `TipFrames.draw` adds
by hand, in whole pixels. `TornTag.measure` takes each look's own padding
(`TipFrames.pad`, left/top/right/bottom), so the box grows round the words
and never clips them; `UITheme.torn_box` hands back the same slice for a
rich body's plate, so a part's readout wears the pick too (without the
hand-drawn extras).

The ten: 1 PLATE, a chamfered hull plate with a 2 px steel edge and a
rivet in each corner; 2 HOLO, a 1 px mint edge with a faint halo, scanline
fill and a 3 px leader notch that points at the thing (`point`, set by
TagLayer and the word tag); 3 HUD, corner brackets only, a short mint
header tab, the words typed on over 0.12 s (under the 0.15 s limit, and
the tag never moves); 4 GLASS, a pale rounded pane with a reflection
streak; 5 SLATE, a steel spine down the left with status lights; 6 SCOPE,
a green edge, dot grid, crosshair ticks past the corners; 7 HAZARD, a
stencilled plate with warning stripes top and bottom; 8 ORGANIC, a rounded
green shell with an inner membrane; 9 BLUEPRINT, blue fill, edge lines run
past the corners, dimension ticks; 10 TRANSPONDER, a punched hole and a
seam before the words, clipped corners. None has a bevel or a raised face:
a tooltip is not a button (only-pressable-things-look-pressable).

Jon, after the sheet: "animate all of them, the ones that make sense to
animate". Each look opens in `OPEN` seconds (0.12 to 0.25, done before it
can be read) in whole-pixel steps, and five keep a slow idle loop; the box
never moves or changes size, so the words stay put, and the slice is drawn
by hand (`slice`: corners, edge runs to a fraction, the fill) so an edge
can draw out. The age comes from `GameClock` (the movie writer runs the
wall clock fast), and `idle_phase` is the one clock every loop reads, 0 the
resting step, so the first frame after the open is the still frame and
TagTest can hold it. The opens: 1 the edge draws round from the top-left
corner clockwise; 2 flickers on (alpha 1, .45, 1, .6, 1 at 0.04 s a step),
the scanlines wipe down and the arrow blinks in; 3 the brackets snap from
the centre to the corners in four steps while the words type on from
0.06 s; 4 a glint crosses the pane once, 2 px a step; 5 the lights come on
in turn; 6 a sweep line crosses the grid; 7 the stripes slide in 12 px; 8
the rim swells out 3 px to its size; 9 the lines draw out from the top-left
corner, the far corners and the ticks following; 10 the beacon blinks
twice. The loops: 2 the scanlines crawl a row every 0.4 s; 5 the top light
dims for 0.5 s of every 2; 6 the sweep crosses again in the last quarter
second of every 2.5; 8 the rim breathes in a pixel for 0.6 s of every 2;
10 the beacon blinks for 0.1 s at the end of every 1.5. Still once open:
1, 3, 4, 7, 9 (a plate, a terminal, glass, tape and a drawing have no
reason to move). The films: tk-scratch/ui-build/tips/films (UiTipFilm).
```
