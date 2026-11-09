The reasoning behind `tkg/scripts/sim/QuestLogTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Quest log test

Above `var _fails := 0`:

```text
THE QUESTS TAB AND ITS TABLE, headless:
  godot --headless --path . -- sheet=QuestLogTest

Jon's design A (Oct 22): a QUESTS tab on the HUD after STARCHART opens a
table of the quests you hold (`QuestPanel`, read off `QuestLog`); a row
picked shows the note, SHOW ON STARCHART and PLOT ROUTE, which open the chart
on the quest's place with its tag, and for PLOT ROUTE its route from YOU. On
three galaxies, through the real screens:

- the QUESTS tab is the same rect with none, one and five quests held (Jon:
  "no number after quests", so it never changes size), and the HUD's row
  fits with it;
- with none, the table says so in a plain line;
- a row for every quest, with its mark, state, task, where (the system and
  its layer from 1, or any of the poster's yards and the nearest), jumps,
  pay and the poster; READY and heat quests stand on the nearest paying yard;
- a picked row shows the note and its two buttons; PLOT ROUTE opens the
  chart, the quest's place the destination, its one tag and its route a
  chain of legal jumps from YOU; SHOW ON STARCHART does the same without the
  route; a star picked off the chart drops both;
- FIT MEANS NOTHING OVERLAPS: the table clear of the HUD, the goal line and
  A.S.H., on LOCAL, the sector map, the chart and a station; the chart's tag
  clear of them, of the chart's words and of every star a click could pick;
- the escape menu, and any change of screen, shut the table.

And EVENT QUESTS and COMPLETED (Jon, Oct 22), on the first galaxy:
- taking the runner's "Hide it aboard" adds a row beside a signed job:
  MARKED, its task, where (system, layer, jumps), ON ARRIVAL, THE RUNNER,
  its note the runner's own line; the head says 1 SIGNED · 1 MARKED;
- its SHOW ON STARCHART and PLOT ROUTE open the chart on its system, its
  route from YOU for PLOT ROUTE;
- taking PAID IN FULL takes the row out of the open ones (and the chart's
  mark off) and lists it under COMPLETED with what it paid; delivering the
  job moves its row there too, newest first, with its credits and standing;
  COMPLETED rows are greyed, open their note and have no PLOT ROUTE;
- a save from before the records (VERSION 34, no `event_quests` and no
  `quests_done`) loads with its open event quest still listed, who gave it
  and where, and its delivered job under COMPLETED with its pay;
- the QUESTS tab never changes size through any of it.
```

## The huds row

Above `func _hud_fits(when: String) -> void:`:

```text
The HUD's row: every piece inside the bar, none over another.

THE BAR IS ITS CLIP, 932 at a 960 window, not the panel's 944: the panel's
six-pixel padding each side is not row, and a row wider than the clip is cut
off at its right-hand end (HudBar._ready), where DATA now sits. Against 944,
a row up to twelve pixels too wide passed with its end not drawn.
```
