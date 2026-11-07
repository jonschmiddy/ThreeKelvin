The reasoning behind `tkg/scripts/sim/TitleBoot.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Title boot

Above `var out := "user://titleboot"`:

```text
The title screen's galaxy on a cold start: when it first draws, and what the
screen shows before it does.
  godot --path . -- sheet=TitleBoot out=<dir>
Prints how long after the title's first frame its sky is drawing and the
longest frame, and saves the frame at 0.5, 1, 2 and 4 s (`boot_<ms>.png`). For
a first launch's cold shader compile, run it with the user's shader cache
moved aside. Needs a window.
```
