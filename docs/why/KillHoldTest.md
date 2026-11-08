The reasoning behind `tkg/scripts/sim/KillHoldTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Kill moves nothing

Above `var _fails := 0`:

```text
A KILL MOVES NOTHING, headless with the animations on:
  godot --headless --path . -- sheet=KillHoldTest
Jon, on the pack-of-three film: "The enemy dips down and then pops up after
the death animation?" The dying ship's readout lost its intent, the pack was
laid out again round the shorter block, and the breakup, anchored where the
art was mid-shake, handed back to a wreck drawn somewhere else.
For a seeded pack of three (drawn at half) and a pair (full size), the first
ship is killed outright and its breakup played to the end and one second on:
  - every slot, and every ship's resting place in it, stays exactly where it
    stood before the kill, every frame;
  - the breakup is drawn from the dying ship's resting place (riding its bob);
  - its last frame is the wreck the slot then draws, pixel for pixel.
And THE KILL TO LOCAL (`_window`): a lone ship killed, and in the stretch
after the fight is finished but before `Router.after_combat` has handed over,
Tab, NEXT SCREEN on another key and clicks on the SECTOR and STARCHART tabs
change nothing (`Router.fight_up`: they started a ladder move that raced the
hand-off), and the hand-off still lands on LOCAL and stays there.
```
