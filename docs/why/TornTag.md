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
