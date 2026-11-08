The reasoning behind `tkg/scripts/sim/WelcomeTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Welcome test

Above `var _tree: SceneTree`:

```text
JON'S WELCOME NOTE, on a fresh profile and after it:
  godot --headless --path . -- sheet=WelcomeTest welcome
(`welcome` lets it open by itself under a harness; the seen flags go to this
process's scratch settings file, so the profile starts fresh every run.)

The title on a fresh profile opens the note, word for word, inside the screen;
showing it does not mark it seen, so a title opened again before it is closed
shows it again; CLOSE shuts it and marks it; the next title (the second
launch) does not open it. MESSAGE FROM JON sits directly above QUIT, styled as
its neighbours and reachable by focus, and opens it again; Escape shuts it.
And what follows it on a first launch (tutorial direction B, Oct 17): NEW
RUN on a fresh profile goes straight to the hull pick with no seed panel (the
panel stays once a save exists), and LAUNCH there puts you on LOCAL with no
tour and no note: the goal line under the HUD, and the controls yours.
```
