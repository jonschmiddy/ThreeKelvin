The reasoning behind `tkg/scripts/ui/WelcomePopup.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Welcome note

Above `const SECTION := "hints"`:

```text
JON'S WELCOME NOTE (`AlphaNotes.ALPHA_WELCOME`), over the title screen, as a
letter (`NoteCard`).

ONCE PER PROFILE on its own: the first time the title screen opens, and never
again once it has been CLOSED (a player who quits with it still up sees it
next time, since they never got past it). The seen flag sits beside the
hints', `[hints] welcome` in settings.cfg (`DisplaySettings.hints_path`) --
so under a harness it is the per-process scratch file. Never shown by itself
under a harness unless asked (`-- welcome`), so no other harness meets it on
the title screen.

There is no opening tour after it any more (tutorial direction B, Oct 17):
the next thing after this note and the hull pick is the game, with the goal
line under the HUD (`GoalLine`).

The title menu's MESSAGE FROM JON opens it again at any time. ITS BUTTON SAYS
WHERE IT GOES (Jon): START YOUR JOURNEY the first time, when the next thing is
the game; CLOSE from the menu, where it only puts the note away. Escape shuts
it either way.
```
