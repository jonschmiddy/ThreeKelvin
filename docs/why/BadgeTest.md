The reasoning behind `tkg/scripts/sim/BadgeTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Badge test

Above `const GoalTestScript := preload("res://scripts/sim/GoalTest.gd")`:

```text
THE CUSTODIAN'S BADGE (`CustodianBadge`, on `GoalLine`), on the real screens,
headless:
  godot --headless --fixed-fps 60 --path . -- sheet=BadgeTest

Badge 9b, "The eye opens, loud" (eye-1b), approved by Jon on Nov 4. Through
a real run, the real HUD and its goal line, and the real Router; no stub.

  1. THE LADDER FROM DATA: the core boss is the one ENGAGE fights at the core
     (`DB.core_boss`), it wakes at 16 and is at full strength from 33 by its
     own growth (`EnemyTemplate.hull_at`), and every jump 0 to 40 has the
     page's stage, tier, countdown and transition.
  2. THE APPROVED PIXELS: every frame in `badge_golden.json` (the page's own
     code drawing them, `tools/dev/badge/dump_golden.py`): `paint` gives the
     same bytes, the digits too; the digits table is the game font's glyphs;
     every transition ends on its stage's idle frame 0.
  3. ON EVERY SCREEN, every jump 0 to 40: LOCAL, the map, the chart and a
     fight. Up with the line, 6 blank columns after GOAL: REACH THE CORE, its
     middle row on the capitals' middle, inside the line's room; the union of
     every frame it inks clear of everything `GoalTest` keeps the line off
     (its own list), of the step's line under it and of A.S.H.'s spots.
     On screen, every frame watched, the badge's own Image is `frame()` at
     the clock it shows (`_screen_bad`; its texture too where it renders).
  4. THE ARRIVAL, ONCE A JUMP: at 10 steps a second on the game's clock,
     ending in idle; never again moving between screens, after a save is
     loaded, or on the chart a real jump left from; and, animated, never
     before the ship has stopped and the line is fully up; the jump before
     at rest until then, a departure skipped on its first frame too.
  5. IDLE, PER SECOND: each stage's changes a second as the page measured
     them, never above 12, no frame shorter than its rate, FULL the same every
     second; on screen it repaints only when the frame changes.
  6. THE TOOLTIP: after the HUD's quarter second, gone on leaving, the page's
     lines under the boss's name from data (renaming it renames them), no hull
     figure, on the theme's tooltip plate, clear of the goal, the badge and
     everything on the screen.
  7. THE MOUSE: nothing in it takes the mouse or looks pressable, the picture
     under it is what the pointer is over, a press there reaches the chart,
     the chart's and the map's hover keep off it (one tooltip at a time),
     and nothing clickable moves for it.
  8. ONE CUSTODIAN FOR THE GALAXY (Jon, Nov 4: "The custodian strength and
     icon should be the same for everyone in the galaxy, even if they join
     late."): it shows the lead ship's jumps (`CustodianBadge.count`). Every
     single-step arrival is the page's; a rise of several plays the biggest
     edge crossed, from the count last shown (14 to 17 the wake, ending on
     S1; 18 to 26 the worse one from S2; 30 to 40 the full one); a partner's
     jump plays once with no jump of yours and never again on a screen
     change; the door's quiet push at 0, 16, 20 and 33 plays nothing; your
     own jump behind the lead plays nothing; the hover box is the look on
     show and follows the count; the party's tooltip words. Solo, none of
     this moves a frame: the goldens above are the same bytes. The one solo
     change: an arrival that never showed (a second jump begun inside the
     line's fade in, 15 shown and 17 jumps) plays the wake from 15, where
     the jump before (16) played nothing.
```

## Tooltip hover

Above `func _picture_hover_under_badge(which: String) -> void:`:

```text
ONE TOOLTIP UNDER THE POINTER: a system on the chart (a world on the map)
brought right under the badge, the pointer resting there, the badge's
tooltip opens and the picture under it hovers nothing, so its own tooltip
does not open under the badge's; brought a little right of the badge, the
picture hovers it as ever (so the test is driving its hover at all). The
picture's motion is handed to it as the GUI hands it a real pointer's:
headless, the GUI delivers no hover.
```
