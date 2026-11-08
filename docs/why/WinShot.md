The reasoning behind `tkg/scripts/sim/WinShot.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Win shot

Above `var _args: PackedStringArray`:

```text
A FIGHT WON, filmed through the real router (alpha blocker 4: after a won
fight you stay on LOCAL by the wrecks, where the pay is, instead of being sent
to the map):
  godot --path . --windowed --position 3840,0 -- sheet=WinShot keepwindow
      clip=<dir> [seed=N] [style=...] [every=3] [after=240]
Starts a run, opens a fight at a system the way an option's fight opens
(shared off, not clearing the system), plays it to a win (the enemy's hull
cut to one first, so the clip is short), and saves the game's picture every
`every` frames from a moment before the kill to `after` frames past it. Prints
which screen the router left you on and how many wrecks it draws. Needs a
window.
```
