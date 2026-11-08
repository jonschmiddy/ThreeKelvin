The reasoning behind `tkg/scripts/sim/CoreWinShot.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Core win shot

Above `var _args: PackedStringArray`:

```text
THE CORE'S WIN, PHOTOGRAPHED AND FILMED through the real router:
  godot --path . --windowed --position 3840,0 --fixed-fps 30 -- sheet=CoreWinShot
      out=<dir> [seed=N] [every=2] [style=...]
A run with a used hold parked at the core, ENGAGE pressed, the custodian's
hull cut to one, then the kill played; the body opens over LOCAL, two parts
are taken out of it a second apart, DONE is pressed, and the win screen
holds. Writes `loot.png` (the body, its scan finished), `win.png` (the win
screen) and `clip/f_####.png` every `every` frames from the last hit to the
popup. The clock is the game's: run with `--fixed-fps 30` and frames encoded
at 30/every fps play at true speed. Needs a window. Audio is the Dummy
driver, so the clip is silent; it prints the music each step asked for.
```
