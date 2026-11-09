The reasoning behind `tkg/scripts/sim/FightLogTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Fight log

Above `var _fails := 0`:

```text
THE FIGHT LOG, HIDDEN UNTIL ASKED FOR (Jon, Oct 18, "fightlog:hidden"):
  godot --headless --path . -- sheet=FightLogTest
`FightLog`. Headless, from a used settings file (other sections in it, the
log's key absent, as on a profile that played before the log came back):
a fight opens with LOG up and the log hidden; a turn played and ended with
it hidden is recorded all the same (a TURN line per turn, your shot, their
move); LOG clicked as a player clicks it shows the log with every line, and
nothing that can be clicked has moved (the hand's buttons, piles, energy,
turn, every card, the HUD's tabs); the choice is in the settings file and the
next fight opens with the log as it was left, read again from the file; LOG
again hides it and that is saved too. A.S.H., the goal line and the hint
cards keep off both. THE BOX TEST: in the light, medium and heavy hull,
against one ship, a pair, a pack of three and a creature, the button and the
open log against everything on the screen -- every label and button of the
HUD and the screen, the goal line, your hull, shield and plate, every enemy's
ship, words, bars and the numbers that pop over it (`Ash.avoid_rects`, less
the band under the HUD it reserves for the goal line) -- touching nothing,
inside the picture, and the log tall enough to read.

`shots=<dir>` (windowed, `--resolution 1920x1080`): the pack of three with
the log hidden and open, the whole window and the game's 960x540.
```
