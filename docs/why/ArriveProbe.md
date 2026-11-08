The reasoning behind `tkg/scripts/sim/ArriveProbe.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Arrive probe

Above `var _args: PackedStringArray`:

```text
A NEW RUN'S FIRST ARRIVAL ON LOCAL, measured a frame at a time:
  godot --path . --windowed --position 3840,0 -- sheet=ArriveProbe out=<file.tsv>
      [secs=11] [mouse=<x>,<y>] [hover=<frame>]
A new run launched the way the hull pick launches it (`Router.show_local`),
and for every real frame: its wall length (ms, the hitch is a wall question),
the game clock, what the engines are doing (`ShipView._thrust_now`, -1 = no
flame), the arrival window, whether the cutaway outline shows, the screen's
phase, and every mouse event the ship's slot was handed. `mouse=x,y` puts
the pointer there (window pixels) before the run starts and leaves it: the
pointer left over the launch button, with the parked ship ending up under
it (not on the hidden render desktop, which has no pointer to warp). `hover=N` shows the cutaway outline from frame N, as a pointer resting
on the parked ship would, to time what drawing it costs. Prints the hull's
rect at rest, to aim it with. Run it
WITHOUT --fixed-fps: a fixed step hides the frames that stall. Needs a window.
```
