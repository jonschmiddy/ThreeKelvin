The reasoning behind `tkg/scripts/sim/CombatClip.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Combat clip

Above `var _args: PackedStringArray`:

```text
A FIGHT, PLAYED THE WAY A PLAYER PLAYS IT, AND FILMED (combat polish audit,
Oct 13). Every card goes through the real gesture -- a pointer rests on it,
presses, carries it up out of the drawer, holds over the target long enough
to read the preview, lets go -- pushed into the game's own viewport, so the
aim line, the lift, the readout and the targeting brackets are all the ones a
person gets. END TURN, FLEE, HAIL and the confirm panels are clicked the same
way. Nothing calls `Combat.play` behind the screen's back.

  godot --path . --fixed-fps 30 --windowed --position 3840,0 -- sheet=CombatClip
      out=<dir> fight=<id>[,<id>...] [end=win|lose|flee|hail] [seed=N]
      [manufacturer=korvan] [weight=light|medium|heavy] [danger=N] [hp=N] [heat=N]
      [after=150] [maxframes=N] [nofilm] [timing] [hints] [rest]
      [prefer=defence] [youblock=N] [at=core]

`out=<dir>` gets `f_####.png` (the window as seen: 1920x1080, the game at
2x), `events.json` (every signal that matters, by frame: card released, shot
landed, damage resolved, bar moved, turn, the end) and `tape.json` (every
sound `Audio` actually played, by frame). `nofilm` saves no pictures;
`timing` (run WITHOUT --fixed-fps) records each real frame's length, so a
stall on a card play shows up as a number rather than a hunch.

A software pointer is drawn over the game (an arrow, hidden while the aim's
reticle is the pointer, as the game hides the real one), because a pushed
event moves no hardware cursor and a film without one shows cards moving by
themselves.

`end=win` plays `Policy`'s best card every time it has one, else END TURN.
`end=lose` plays nothing and ends turns until the hull goes (start it low
with `hp=`). `end=flee` / `end=hail` open the exit on turn one and take it.
`rest` holds the pointer still on the first card for 1.4 s, so its keyword
panel opens. `hints` lets the first-run hints show (they are reset first, in
the harness's own settings file).
```

## Pushed events

Inside `_click()`, above `var fired := [false]`:

```text
PUSHED EVENTS DO NOT PRESS A BUTTON. A card takes its press through its own
`gui_input` and the screen's `_input`, and those work from a pushed event;
`BaseButton` decides "released inside" from the viewport's pointer, which a
pushed event into the game's SubViewport does not move (SectorShot calls the
handlers directly for the same reason). So the press is pushed -- the button
shows its pressed face -- and if it did not fire, the release is delivered
the one way that reaches it. Logged either way.
```
