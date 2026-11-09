The reasoning behind `tkg/scripts/sim/ShipShot.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Shot purpose

Above `const WEIGHTS := {`:

```text
The refit screen, photographed, one weight at a time.

  godot --path . -- shipshot            the heavy, which is the tight one
  godot --path . -- shipshot medium
  godot --path . -- shipshot all        one PNG per weight
  godot --path . -- shipshot medium turn

NOT `--headless`. The settle waits on `frame_post_draw`, which the dummy
display server never emits, so a headless run sits in that loop until it is
killed and writes nothing. It looks exactly like a hang because it is one.

WHY THIS EXISTS. The refit screen's layout is a budget between two panels: the
masthead is as deep as the ship in it and the workbench gets what is left. The
question every change to it asks is "does the deepest hold still fit", and the
deepest hold belongs to the heavy — 6x5 cells against the light's 4x3. That is
not a question you can answer by opening the screen on whatever ship a new run
happened to roll, and it is not one a still of the wrong weight can answer at
all.

Same shape as ConvoyTest's `convoy` mode and for the same reason: it needs a
window, it cannot assert anything, and it exists because layout questions are
answered by looking.
```

## Moved shot

Inside `_shot()`, above `if "moved" in OS.get_cmdline_user_args():`:

```text
`-- shipshot light moved` photographs the screen the MOMENT AFTER A HULL
SWAP, which is the one state the dock exists for and the only one no
amount of clicking reaches quickly: you have to find a yard with a smaller
frame on the blocks and be carrying enough to overflow it.

Built by flying a HEAVY and moving into whatever this shot was asked for,
so the squeeze is real arithmetic and not a hand-placed fixture -- 30 cells
of loadout and hold going into a light's 12 strands about half of it.
```

## Settle wait

Inside `_shot()`, above `var t0 := Time.get_ticks_msec()`:

```text
The ship flies in and the mounts settle behind it, and this waits for
THE ANIMATION rather than for a number of frames.

A fixed 200 was five minutes on a machine whose headless frames run at
better than a second each -- the loop's job is `the arrival is over`,
and a frame count only means that where frames are cheap. Tweens run on
the same delta the frames do, so waiting on the clock finishes the
arrival in two slow frames or in eighty fast ones, and either is right.
The frame cap stays as a stop, not as the measure.
```

## Tip panel

Inside `_shot()`, above `if "tippanel" in OS.get_cmdline_user_args():`:

```text
`tippanel` builds what a chip answers with and parks it on the screen.

`hover` below warps the mouse and waits, which does NOT work: warping the
pointer does not synthesise the motion event Godot's GUI uses to start a
tooltip timer, so the shot comes back with no tooltip and no error. This
builds the panel directly instead and wraps it in the plate Godot would
have wrapped it in -- `bevel(PANEL2)`, which is what `perk_readout`'s own
comment records the tooltip theme using.
```

## Zoom and turn shots

Inside `_shot()`, above `if "turn" in OS.get_cmdline_user_args():`:

```text
`-- shipshot heavy zoom` photographs the doubled view, which is the only
way to see it without a hand on the mouse: the zoom is a click and a
drag, and neither exists in a headless render.
`-- shipshot medium turn` PACKS EVERY PART SIDEWAYS AND FLIPS HALF OF
THEM, which is the only way to photograph the two states a fitted part
can be in that a fresh run never produces. It is a rendering question
and the answer is a picture, so the tool that takes the picture is the
one that has to be able to set it up.
```
