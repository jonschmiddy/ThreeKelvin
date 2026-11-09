The reasoning behind `tkg/scripts/ui/FightLog.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Fight log

Above `const SECTION := "fight"`:

```text
THE FIGHT LOG, HIDDEN UNTIL YOU ASK FOR IT (Jon, Oct 18, "fightlog:hidden":
"Hidden. Open it with a button if you want it."). The running list of what
happened each turn of a fight -- your shots, their moves, heat, hull -- under a
TURN line per turn. It went from the screen with the side rail ("every line
was a transcript of an animation you had just watched"), and the lines never
stopped being written (`Combat._log`, `Sig.log_line`); this brings them back
for whoever wants the transcript, and nobody else.

LOG, a small button at the right end of the band under the HUD, shows and
hides it. The choice is kept (`[fight] log_open` in the settings file, the
harness's own under a harness), so a player who wants it open has it open in
every fight after. Off on a fresh profile.

IT RECORDS WHILE HIDDEN. The recorder (`lines`) listens from the first fight
of the session whether or not anything shows it, so opening the log mid-fight
shows the whole fight so far.

NOTHING MOVES FOR IT. Both are drawn over the screen, placed in game px, and
nothing in the hand or the picture is laid out round them: the button stands
where nothing else does (the band under the HUD is the goal line's, at its
left end, and A.S.H. never stands in it), and the open log stands in the top
left corner of the picture, under that band and above your ship, cut short of
your hull, its shield and every enemy. A.S.H., the goal line and the hint
cards keep off both (`rects`). The open log is a readout, not a control: no
edge, a dim backing like the goal line's, and the mouse goes through it.
`-- sheet=FightLogTest` holds all of it.
```
