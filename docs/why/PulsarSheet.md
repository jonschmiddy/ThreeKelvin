The reasoning behind `tkg/scripts/sim/PulsarSheet.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Pulsar sheet

Above `const PulsarView := preload("res://scripts/ui/sysmap/PulsarView.gd")`:

```text
The system map's pulsar as the GPU paints it, one picture per seed and
moment, to set against the mockup's (the scratchpad's `sysmap/page`):
  godot --path . -- sheet=PulsarSheet out=<dir> [seeds=11,3,0] [times=0.2,0.45]
      [layer=pulsar|web|gas|both] [gas=<png>] [zoom=<k>] [at=<x>,<y>] [perf]
  godot --path . -- sheet=PulsarSheet out=<dir> zoomsheet [zooms=1,2,3,4] [seeds=..] [times=..] [layer=..]

Each picture is the map's 960 x 540 on black, the pulsar where the map puts
it, saved as <dir>/g_<layer>_<seed>_<t>.png. `gas=` is the mockup's pulsar
gas brightness dumped as a 16-bit PNG (red high byte, green low, over 4),
to light it with the beam. `perf` instead times 240 frames with the
pulsar and 240 without, vsync off, and prints the difference. Needs a
window: a shader draws nothing headless.

`zoom=` draws at the map's zoom k (`set_zoom`); `at=` moves the pulsar there
after setting it up (a pan: its web should go with it). `perf` takes both,
and `copies=` (20).
`zoomsheet` draws each seed and moment at every zoom in `zooms`, the
pulsar set up where the game sets it (the map's centre, the map's own
rect) and then carried to the middle of a picture four times the map's
size, so zoom 4 shows the whole of what zoom 1 shows; saved as
<dir>/z_<layer>_<seed>_<t>_k<k>.png, 3840 x 2160.
```
