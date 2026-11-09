The reasoning behind `tkg/scripts/sim/ShellTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Window shell test

Above `const LOOKS := [["flat", DisplaySettings.Look.FLAT],`:

```text
THE WINDOW SHELL FROM OUTSIDE: what the player's window shows around and
through the glass, in every shape of window, and what it costs.
  tools/dev/render.sh --path tkg -- sheet=ShellTest [out=<dir>] [checks] [stills] [bench]

NEEDS A WINDOW, because the shell IS the window. It resizes that window
through 1X, 2X, 3X, a letterboxed size and BORDERLESS (which covers the whole
screen for a few seconds). 3X only where the screen allows it: a Retina Mac's
window stops at 2X (Oct 27, `DisplaySettings.RETINA_MAX_SCALE`), so there w3
is left out and the run says so; BORDERLESS is still the big window. With none of the three parts named it runs all of
them; `out=` is where the stills and `shell.json` go.

  checks  A pointer moved through the WINDOW onto your ship on LOCAL lights
          the cutaway's outline and moving off puts it out (the input path
          through the hidden container, `GameShell._frame`); the container
          is culled and still takes input; the game frame keeps drawing
          under the glass; the black is drawn only over the letterbox bands
          and every pixel of them is black.
  stills  The window photographed in each shape and look, with a fixed
          picture in the game frame (a pattern of edges, gradients, single
          pixels and bright whites, and a station backdrop), so a before and
          an after set can be diffed pixel for pixel. Named
          `<window>_<look>.png`.
  bench   Each shape at the default look with vsync off: frame ms (median,
          p95), the ROOT viewport's GPU ms (the shell's own passes, which
          headless cannot see) and the draw calls a frame.

THE GAME IS STOPPED for the stills and the bench: its viewports frozen, its
screens hidden and a still picture put over it, so the only thing that
changes from one run to the next is the shell. The checks run first, on the
real game.
```

## Borderless last

Inside `_run()`, above `await _window("bl")`:

```text
BORDERLESS LAST. Leaving it, a Mac keeps the window zoomed to the screen's
visible frame (2880x1694 on a 1440x900 Retina) whatever size is asked
for, so nothing windowed after it is the window it says. That zoomed
window is photographed too (`w3z`): bands top and bottom at a whole 3X.
```
