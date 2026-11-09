The reasoning behind `tkg/scripts/sim/PlayerDeathTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Player death test

Above `var _tree: SceneTree`:

```text
YOUR SHIP BREAKS UP BEFORE THE RUN ENDS:
  godot --headless --path . -- sheet=PlayerDeathTest

Jon, Oct 13: "When you die... let's have your ship crack and explode...
pause for a beat... then the run ended popup shows up."

The same fight twice from the same seed, at 5 hull against a cutter's Strafe
5, through END TURN as the button presses it:
  - ANIMATED (`Router.animate_in_harness`): the killing shot lands, your hull
    comes apart (`SectorScreen.loss`: a ship style, the boss-length cut, drawn
    mirrored because your ship faces right, over the hull's own place, the
    hull hidden), the explosion played on its breaks, and the run's
    screen appears only once the breakup has finished AND the wreck has been
    held for WRECK_HOLD_S;
  - WITHOUT MOTION: no breakup, the run's screen at once;
  - and the run each leaves behind identical: dead, the reason, hull, heat,
    fuel, credits, hold, jumps, kills, the record written once as a loss.
```

## Feedback after death

Above `func _feedback_after_death() -> void:`:

```text
A SHIP KILLED BY A HIT RETURNS NO FEEDBACK (Oct 29). The Custodian at 1 hull
lands Annihilate on a ship at 5 hull carrying feedback: the ship dies, the
Custodian lives, and the run is not won. Feedback ran before the death check
and killed it on the way back, so the run ended as a death and a win at once.
Then the same hit on a ship that lives: the feedback still kills it, and wins.
```
