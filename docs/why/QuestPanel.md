The reasoning behind `tkg/scripts/ui/QuestPanel.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Quests table

Above `static var _open: QuestPanel = null`:

```text
THE QUESTS TABLE, opened by the HUD's QUESTS tab (Jon, Oct 22, design A:
"I chose A, the JOBS tab", named QUESTS as the chart names them, and no count
on the tab "so it doesn't change size"). Every quest you hold (`QuestLog`), a
row each: its mark, its state, what to do, where (the system and its layer,
or any of the poster's yards and the nearest), the jumps from you, the pay
and the poster's flag and name. A row picked opens under itself: the note in
the poster's own words, SHOW ON STARCHART and PLOT ROUTE.

OVER WHATEVER IS UP -- LOCAL, the sector map, the chart, a station -- in the
HUD's own column after the screens (where the goal line and A.S.H. stand),
right of the goal line and of A.S.H.'s first place and under the HUD, so it
covers neither. Closed by its tab, by CLOSE, by any change of screen, and by
the escape menu opening over it.

Only this ship's quests: `Run` is one ship, and a partner's are on theirs.

AN EVENT QUEST IS A ROW TOO (Jon, Oct 22): what an event planted ahead of
you (`OptionTable.place`), MARKED, its pay ON ARRIVAL, from the event that
gave it. And FINISHED QUESTS STAY, under a plain COMPLETED heading below the
open ones, newest first, greyed a little, each with what it paid; a finished
row still opens its note and SHOW ON STARCHART, and has no PLOT ROUTE. No
heading when nothing is finished.
```
