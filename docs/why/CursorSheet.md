The reasoning behind `tkg/scripts/sim/CursorSheet.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Cursor sheet

Above `const NAMES: Array[String] = ["reticle", "reticle_hot"]`:

```text
The candidate cursors, on the screen they have to work on:
  godot --path . -- cursorsheet

NEEDS A WINDOW, like every shot -- `--headless` never emits
`frame_post_draw`.

A CURSOR CANNOT BE SCREENSHOTTED. `Input.set_custom_mouse_cursor` hands the
image to the operating system and the viewport capture never sees it, so
comparing three of them by setting each and taking a picture is not a thing
that works. They are BLITTED instead: the same PNG the OS would be given,
drawn into the frame at the size it would be drawn at.

OVER FOUR GROUNDS, which is the whole question. A cursor crosses a lit hull,
an empty sky, a panel and a card in one sweep, and a shape that reads on any
one of those alone will vanish on another. The strip down the right is the
same three at 6x, for judging the shape rather than the legibility.
```
