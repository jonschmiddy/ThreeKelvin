The reasoning behind `tkg/scripts/sim/PlanetSheet.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Planet sheet

Above `const CW := 96`:

```text
Every kind of world the system map draws, on one sheet, as the GPU paints it:
  godot --path . -- planetsheet=<png> [planettime=S]

The same worlds, seeds, sizes and light as the approved gallery page
("Thirty-Four Worlds"), so the two can be set side by side: world i is seed
(i + 1) * 3 + 11, radius 24 (a giant 20, ringed on even cards), lit from the
upper left. Needs a window: a shader draws nothing headless.

`planetclip=<dir> [planetframes=150] [planetrate=1] [planetcell=1]`: then
films the sheet turning, `f_####.png`, the clock stepped 1/30 s a frame times
`planetrate` (run with `--fixed-fps 30`), in `planetcell` blocks (2: as the
map and LOCAL draw them), to measure each world's shimmer on its card.
`worldmem=off` films them as before the worlds' memory (`PixelTurn`).
```
