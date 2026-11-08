The reasoning behind `tkg/scripts/sim/IntroShot.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Intro shot

Above `var _args: PackedStringArray`:

```text
A NEW RUN'S OPENING, filmed: the name card, the ship flying in, and the
controls handed over when it stops. There is no tour any more (tutorial
direction B, Oct 17; `FirstRunIntro` is gone), so what this films is the
opening alone and the goal line coming up under the HUD (`GoalLine`).
  godot --path . --windowed --position 3840,0 -- sheet=IntroShot keepwindow hints
      clip=<dir> [every=6] [secs=12] [reduced] [style=...] [seed=N]
A new run launched the way the hull pick launches it (`Router.show_local`),
the game's picture saved every `every` frames for `secs` seconds. Prints the
second the ship stopped (the arrival's phase over: control is yours) and
whether the goal line and its step were up then. `hints` turns the steps on
under the harness (their flags go to its scratch settings, never the
player's). Needs a window.
```
