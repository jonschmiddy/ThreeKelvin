The reasoning behind `tkg/scripts/ui/SideSwap.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Side bar swap

Above `const SHADER := preload("res://shaders/side_swap.gdshader")`:

```text
THE SIDE BAR'S SWAP (Jon, Oct 13: "When going from local to sector or sector
to starchart etc... the side bar goes blank and then draws the new side bar.
Can we not have it go blank and just have it transition to the new side
bar?"). It went blank because the side bar was part of each screen's UI
(`ladder_chrome`), which leaves before the camera moves and comes back after
it lands: the chart's and the map's panels faded out over 0.22 s, the side
column stood empty through the whole camera move, and the new panel faded in
over 0.4 s after it -- 60 to 122 frames of empty column at 60 fps a hop.

Now the side bar is not the screens' UI. The panel being left stays whole
while its camera moves (`ZoomLadder.preroll`), and from the swap -- the
arriving screen built, its panel laid out and live underneath -- this draws
over the side bar's rect, from the held picture's copy of the old panel to
the live new one, in the look picked (`ZoomLadder.SIDE_LOOK`), and goes once
the new one stands alone. The held picture leaves this rect to it
(`zoom_ladder.gdshader`'s `side`). The other UI keeps its three beats.

A hop with a side bar at one end only (LOCAL <-> the map) runs the same look
with the picture arriving (LOCAL's own, live) as the new, or, arriving from
LOCAL, the picture that was there as the old -- going on the held picture's
own curve, as the rest of it goes, the look kept at least level with it.

CLICKS (Jon on the Lab's rolling screen: anything that moves the rows "can
cause a misclick"): nothing a hand can click moves while it can be clicked.
`blocks` says where a click would land on content not yet resolved -- A
before the crossfade's middle, B and C until they are done, D below the
line, E and F a row or icon not yet written -- and the ladder eats a click
there (`ZoomLadder._input`), ending the move but landing on nothing.
```

## Slow decode

Above `const E_ROW := 0.45`:

```text
E, SLOW (Jon: "can we have the decode animation happen slowly and not so
fast?"): each line resolves left to right over `E_ROW`, the lines starting
one after another down the panel 60-80 ms apart, the whole about 1.1 s, or
to 0.3 s past the camera landing on a longer move; a hop shorter than that
(LOCAL -> map) lets the decode run on past the zoom rather than hurrying it
(`ZoomLadder._end` hands it on). The glyphs turn over `GLYPH_HZ` a second.
```
