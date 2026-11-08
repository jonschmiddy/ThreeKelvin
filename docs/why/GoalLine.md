The reasoning behind `tkg/scripts/ui/GoalLine.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Goal line

Above `const GOAL := "GOAL: REACH THE CORE"`:

```text
THE GOAL, ALWAYS, AND THE NEXT STEP WHILE ONE IS PENDING (tutorial direction
B, "learn by doing", Jon Oct 17). Two quiet lines under the HUD:

  GOAL: REACH THE CORE
  Open STARCHART. Pick a star in range, then JUMP.

The second line only while a step is pending, with the HUD tab it names
outlined (`cue`). The tour that used to say the goal once, for three seconds,
is gone; this says it for as long as a run lasts.

THE STEPS, each done once per profile (`Hints.STEPS`, `[hints] step_*`,
cleared by REPLAY TUTORIAL), and only where the hints are on (`Hints.enabled`,
so never under a harness that did not ask):
  step_jump   no jump made yet: open STARCHART, pick a star, JUMP. Done at the
              first jump.
  step_event  after it, in a system with an event open: click one, then GO.
              Done when an event's band is up on LOCAL.

HOSTED BY THE HUD (`HudBar`) and drawn beside it, in the HUD's own column
after the screens, so it is over the picture and under the escape menu. It
is `top_level`, so the column does not lay it out; it places itself.

ITS PLACE (`fixed_at`). Jon, Oct 18: "Can we have the goal: xxx always be in
this location?". Oct 20: not in the map's and the chart's top plate left of
their DANGER / LAYER, but just below it, at the top left of their picture.
Oct 20, "snug:B": on LOCAL, where there is no plate, snug under the HUD at
the same left, not low with an empty gap over it. Between the two it moves
only with the top plate ("Can we make it smooth animation as it drops down
or up"): on a move between LOCAL and the map or the chart it slides down or
up as the plate slides on or off, on the plate's own curve (`drop`, read off
its `PanelSlide`), in whole pixels; between the map and the chart it stays.
The step's line, while one is pending, directly under it (`step_at`), and
A.S.H.'s box under both, the three as one group.

SAID ONCE, NOT TWICE (Jon, Oct 20, "twice:hide"): while A.S.H. has a step to
say, or is saying it, the step's line is not shown; when she has finished it
comes back as the quiet reminder, "slowly pop in all smooth like": a fade
over `APPEAR_S` with a small settle up from `APPEAR_DY` px, eased, in whole
pixels, on the game's clock. Its room is kept all the while (`stack_rect`),
so nothing moves when it comes back; a step changing while she talks keeps
it hidden until she is done with that one too. Both have the
step's dim backing: they stand over the picture. The two lines' room is kept
whether a step is pending or not (`stack_rect`), so A.S.H., who keeps off it,
is never sent away by a step arriving. `-- sheet=GoalTest` holds both clear
of everything on every screen they show on (`avoid_rects` lists what that is).

IT IS NOT A CONTROL, and does not look like one: no plate, no edge, no hover,
no hand; it ignores the mouse, so a click goes through it. It stays up
through a move between LOCAL, the map and the chart (a piece of the HUD);
hidden over any other move, a jump's departure and an arrival (it comes up
when the ship stops), the cutaway, a wreck's window and the escape menu, and
off the three flight screens.

THE CUSTODIAN'S BADGE (`CustodianBadge`, badge 9b, Jon Nov 4) stands on the
goal's line, 6 blank px after its last letter, its middle row on the
capitals' middle (`badge_at`): the eye that wakes as the boss at the core
grows. It is part of the line: it shows when the line shows, fades and slides
with it, and its room is the line's (`size`, `stack_rect`), so what keeps off
the goal keeps off the badge. It is 15 px tall to the goal's 13, so the
step's line stands 2 px lower than it did (`_line_h`). Its arrival plays
here, once a rise in its count: on the first frame the line is fully up
after it (`RunState.custodian_seen`), and until then it holds the count last
shown.
```

## Custodian badge

Inside `refresh()`, above `var seen := Run.custodian_seen`:

```text
THE BADGE'S ARRIVAL, once a rise in the count, when the line is fully up
after it (not half way through its fade, which would eat half a 0.4 s
tick). Until then it holds the count last shown, the line fading out too:
a departure skipped on its first frame commits the jump while the old line
is still going. The count is the lead ship's in co-op
(`CustodianBadge.count`), so it can rise by more than one, or while you
sit still: it plays from the count last shown to the count now.
```
