The reasoning behind `tkg/scripts/ui/SideBand.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Toolbar band

Above `const OPEN_S := 0.3`:

```text
THE TOOLBAR'S BAND BETWEEN LOCAL AND A SCREEN WITH ONE (Jon, Oct 13: "When
going from the local to sector or starchart... the window drops abruptly,
can we have a smooth transition between those?"; and the half-decoded
letters of the map's toolbar hung over LOCAL's open space, "weird").

LOCAL's scene starts at the top of the screens' area; the map's and the
chart's picture start under their toolbar (`StarchartScreen.BAR_H`) and the
gap below it, 21 px lower. At the swap that edge moved in one frame. This
is the band that toolbar sits on, drawn over LOCAL:
  OPENING (LOCAL -> map): it grows down from the top over `OPEN_S`, eased
    out, while LOCAL's camera still moves, so by the swap it is exactly where
    the map's own band is; then it stays until nothing of LOCAL's held picture
    is left under it, and goes -- the map's own band is the same pixels.
  CLOSING (map -> LOCAL): it stands whole from the swap, the map's toolbar
    decoding away on it (`SideSwap.banded`), and once that is done it closes
    back up the same way, LOCAL's scene coming up under it.
The scene's top edge moves with it, a pixel or two a frame, never at once.
It takes the clicks on it: under it is either nothing yet or a scene it
hides. Out of LOCAL the ladder drives it with the move (`driven`); into
LOCAL the band leaves as a picture instead (`ChromeSlide`).
```
