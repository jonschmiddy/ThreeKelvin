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
at the thing (`point`: 1 above it, -1 below). It opens in OPEN = 0.2 s,
the scanlines wiping down, and then holds still (see Wears thin: the first
opening flickered, crawled and tore for a frame every 3.5 s, and in play that
was "too much flashing. Feels unstable"). Everything is whole pixels and
whole-pixel steps on GameClock (the movie writer runs the wall clock fast);
the box never moves or changes size; nothing bevels or presses (a tooltip is
not a button). Drawn with an age of INF it is the still frame, which the
chart's tip uses; the system map's tip passes how long its hover has been
open, so it wears like the rest.

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

## Wears thin

Above `const D_AFTER`:

```text
C-D (Jon, Nov 11). GLITCH flickered all the time and, in play, was "too much
flashing. Feels unstable." Four calmer takes were filmed (A tear-in only, B a
rare slip, C a drifting line, D steady then wearing thin) and Jon picked D:
the tag opens steady and only starts to glitch once it has been open D_AFTER
= 3 s, the time it takes to read it. Five strengths of the wear were filmed
(G1 barely there to G5 failing); Jon: "G2 is perfect. G3 and G4 can be used
when the ship hull is low", and G5 was "really cool, but it's unreadable", so
G5b keeps G5's damage in 0.3-0.5 s bursts with long still breaks.

The levels follow the hull (Jon, Nov 11): G2 above 50%; G3 at or under 50%
(LowHull.WORN_AT); G4 at or under 30%, with the red edge (TIER1_AT); G5b under
15% (DIRE_UNDER, strictly: 5 of 40 and below). Back to G2 on repair. Each step
is read off LowHull's eased `worn`, `on` and `dire`, which move at EASE_S on
the game's clock, and a burst keeps the level it began on, so the tag never
changes level mid-burst. Reduced motion stills it, as it stills the red.

The rhythm is the same at every level (Jon, Nov 11: "Each of them should
have 3-4 seconds of calm between bursts. The bursts intensity and the glitch
intensity should be the only thing increasing"): CALM_F to CALM_F +
CALM_JIT_F frames (3-4 s, uneven) of clean, still words between bursts, with
nothing drawn between them. A burst is a few 30 Hz frames, longer as the
level rises (G2 two frames, the flick he liked; G3 about 0.2 s; G4 about
0.25-0.3 s; G5b 0.3-0.5 s): torn bands of the box slid sideways (a line of
words under one goes with it), a red/cyan split of the words, letters
swapped for junk or dropped, static and bright rows, a dim, a 1-2 px nudge,
at G5b a frame blinked out. G3, G4 and G5b are a quarter stronger than
first filmed (H2, Jon, Nov 11); G2 stays as he passed it. Only the tag
moves; it takes no clicks. A hull
drop shows at the next burst, within 4 s: no burst is started early, as
that would break the calm he asked for.
`-- tagglitch=1..5|5b` holds a level for the films (`TagGlitchFilm`).
```
