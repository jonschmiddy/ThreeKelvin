The reasoning behind `tkg/scripts/sim/SoundMomentTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Sound moments

Above `var _tree: SceneTree`:

```text
THE EFFECTS' MOMENTS ARE HEARD, ONCE, ON THE FRAME THE PICTURE ACTS (the free
half of the sound plan, Oct 17: `Audio.FX`), headless:
  godot --headless --fixed-fps 60 --path . -- sheet=SoundMomentTest
Audio makes no sound headless, but while it tapes it runs every decision --
rate limits, suppression, the pick, the caps -- and writes down what would
have played (`Audio.tape`, `Audio.fx_heard`). Through the real screens with
the animation on, each picture's own `moment` written down as it is emitted:
  * the table: every row's files exist, and a row can be set back, silenced
    or given a file of its own;
  * a hulk's fight: the band rising (hold_lift), its plates going on and
    yours (module_install on the wave's start, and no shield_block from the
    card or the clamp), plates shed (jettison), a hit partly taken
    (shield_block -8 under the impact), its shield up and a hit taken whole
    (shield_block as before), three vents opened at once (one hiss) and ten
    seconds of their sputters (never closer than 0.4 s);
  * a cutter dying in G (its jets and sputters, the vent's);
  * the calf dying in N, O and P (fauna_falls on the first beat, -4 dB);
  * the Hellbender's furnace (in on the heat, out on the burst) and its pops,
    and the Custodian's C1c pops and split;
  * your ship lost: power_off as the handoff starts, the score ducked through
    the gap, and no page click on the swap into RUN ENDED;
  * the ladder: the chrome sliding (menu_open / menu_close as the column
    first moves) and the side bar's decode (a text_blip as each line starts,
    never more than two in the air).
Written to run on main too (it reaches the new parts by name): there it runs
in a window, where Audio is on and tapes what it plays, and fails.
```

## Kill boom

Above `const KILL_POOL := {&"explosion_small_3": -0.9, &"explosion_small_4": 2.1, &"explosion_small_5": -0.2}`:

```text
Jon, Oct 19: "the ship exploding ... is weak". A death's MAIN BREAK is one
layered boom (`Audio.kill_beat`): a heavy take at its own level, a sub thump
and buckling metal, all three on the frame of a boom the picture shows, each
once; and no break left to the old pool's luck.
```
