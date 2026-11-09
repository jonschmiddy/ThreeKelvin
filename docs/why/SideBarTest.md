The reasoning behind `tkg/scripts/sim/SideBarTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Side bar test

Above `var _fails := 0`:

```text
THE SIDE BAR NEVER GOES BLANK (Jon, Oct 13: "When going from local to sector
or sector to starchart etc... the side bar goes blank and then draws the new
side bar. Can we not have it go blank and just have it transition to the new
side bar?"), headless:
  godot --headless --path . -- sheet=SideBarTest [looks=A,B,C,D,E,F]
Every hop that has a side bar at one end -- LOCAL -> map, map -> chart,
chart -> map, map -> LOCAL -- through the Router's own doors with the
animation on and the ladder's clock stepped 1/60 s a frame, for every look the
swap has (`ZoomLadder.SIDE_LOOKS`). Each frame the screen up has a side bar,
how much of its rect shows content is measured: the live panel's own opacity,
or, while a swap is drawn over it (`SideSwap`), the swap's old and new at a
grid of points across it. A frame under half is a BLANK frame, and any blank
frame fails. Also: no more than the crossfade's middle shows both contents
half and half; a click is only let through where the new content stands
resolved (A: from the crossfade's middle on); and with the animation off
(headless, reduced motion) the new side bar is whole the very frame it is
asked for. Prints the blank frames per hop, which is the number on main.
THE TOOLBAR the same (Jon: "these buttons" -- the chart's LAYER row, the
map's DANGER strip, `ladder_bar`): never blank, decoded on every hop, and a
click on a button in it before it has resolved eaten.
Written to run on main too (it reaches the swap only by name), so it can be
watched failing there.
```

## Calm move with LOCAL

Inside `_hop()`, above `var from_local := Router.current is SectorScreen`:

```text
THE CALM MOVE WITH LOCAL AT ONE END (Jon, Oct 17): out of LOCAL the side
panel comes on only after the camera has landed, into LOCAL it goes before
the camera moves -- so with LOCAL at one end there is no side bar to show
while the camera moves. Blank is counted out of LOCAL from the decode on
(it must never go blank once it is there), and not at all into LOCAL.
```

## Calm decode

Inside `_hop()`, above `var dsecs := letter_frames / 60.0`:

```text
THE CALM MOVE: the decode runs after the camera has landed, never under
it, over its dial (`ZoomLadder.CALM_DECODE_S`: Jon's "slowly" was 1.1 s
when it ran under the camera; after it, that second was the hop's)
```
