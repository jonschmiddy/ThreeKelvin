The reasoning behind `tkg/scripts/sim/JumpCine.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Jump cinematic

Above `const SHOTS := {`:

```text
The jump, photographed frame by frame:
  godot --path . -- jumpcine [seed=N]

NEEDS A WINDOW, like every shot tool here: under `--headless` the dummy
display server never emits `frame_post_draw`, so nothing is captured and it
looks exactly like a hang.

AND IT IS DELIBERATELY NOT CALLED `jumpshot`. `Router.animating()` returns
false for any argument ending in "shot", which is what keeps the screenshot
tools from photographing half-finished tweens -- and the whole subject here
IS the tweens. A shot tool cannot see this sequence by construction, so this
one is named out of that rule rather than fighting it.

IT EXISTS BECAUSE A CINEMATIC IS A LAYOUT THAT MOVES. `sectorshot` proves the
end state and says nothing about the seven seconds before it: whether the
drawer is parked below the floor while the ship flies in, whether the name
card is still up when the hull arrives, whether anything is drawn in the band
the drawer will occupy. Those are questions about particular frames, and the
only honest way to answer them is to look at those frames.
```

## Jump strips

Above `const DEMO_W := 416`:

```text
Every jump style, as a strip of frames, straight out of the game.

ONE STRIP PER STYLE, frames laid left to right, cropped to the hull so the
flare fills the picture rather than sitting in a corner of a 960x540 screen.
Twenty of these is something you can look at side by side and choose from;
twenty descriptions of light is not.
```

## Jump film

Above `const FILM_FPS := 30.0`:

```text
The hyperdrive as a film, for reviewing it WITH its sound:
  godot --path . -- jumpcine film

Frames of the real departure, cropped around the hull and the spark, each
logged with the moment it was taken, plus the offsets the two clips start
at. A muxer lays the clips under the frames and makes one file to watch. A
strip of stills is not a review of a sound, and a sound on its own is not a
review of whether it lands on the picture.
```

## Ending strips

Above `const END_FRAMES := 32`:

```text
Every ending, as a strip, straight out of the game:
  godot --path . -- jumpcine endings

Only the part that differs is photographed. Each run SEEKS the flare to the
middle of the snap rather than sitting through the charge twenty times, so a
strip is the hull going, the beam running, and the ending.
```

## Bar strips

Above `const BAR_FRAMES := 44`:

```text
Every bar look, as a strip, straight out of the game:
  godot --path . -- jumpcine bars

From partway into the charge -- seeked there, so the whole charge is not sat
through twelve times -- to the end of the run, which is everywhere the bar is
on screen: growing on the hull, full at the snap, and running off.
```

## Spool strips

Above `const SPOOL_FRAMES := 40`:

```text
EVERY SPOOL LOOK, as a strip of frames: the hull through the whole charge.
  godot --path . -- jumpcine spools

The same harness as `bars`, started at the top of the charge instead of partway
in, since the looks are what the hull does as the spool STARTS. Forty frames
across CHARGE_S, cropped to the hull and nothing past it.
```

## Whole jump film

Above `const WHOLE_FPS := 60.0`:

```text
THE WHOLE JUMP, as a film with its sound:
  godot --path . -- jumpcine whole

Everything between pressing JUMP and the drawer settling, through the real
Router path -- `begin_jump`, the departure, the commit, the swap, the name
card, the approach, the drawer -- captured full-frame. Every effect that
actually plays is taped by `Audio` with the moment it played, so the muxer
lays the real sounds under the frames: which arrival clip was drawn, whether
the screen-change tick fired, none of it assumed.
```

Since the jump films (Nov 10) it runs at the films' own 60 fps on `--fixed-fps 60`, saving
every frame, with `film=r12` forcing the film (`JumpRegistry.forced`) and `out=` the folder.
The log holds each frame's clock, each taped cue with how far into its take it started, and
the wall clock per frame (median, p95, max; the png save included, so a ceiling). The jump
now lands on the system map at 8.8 s, so the last frames are the map, not LOCAL's drawer.
`tools/dev/jump_compare.py` muxes the taped cues under the frames (1x and 2x MP4s) and lays
the approved film's strip frames over the game's at the same moments, whole and as a 2x crop
of the ship's end: that side-by-side is what Jon judges.

## Film strips

Above `const STRIP_TS := {`:

```text
Every landed film's strip frames in one run: the approved strips' twelve moments (the films'
encode.py TS lists), each film jumped from a fresh LOCAL, so `jump_compare.py --strips` can
lay all of them beside the approved frames without a whole capture each.
```

## Hush test

Above `const HUSH_WAIT := 4.0`:

```text
THE SKIP HAS TO TAKE THE SOUND WITH IT:
  godot --path . -- jumpcine hush

A real jump, skipped on the frame the warp is loudest, and then a question
the sound tape cannot answer: what is STILL PLAYING? `Audio.tape` records
what started, so a five-second warp running on over a sector that has already
arrived leaves no mark in it at all -- which is how this shipped.

The voices are read directly rather than through an accessor. A harness
reaching into the thing it is checking is the point of a harness; adding a
public "what are you playing" to the mixer to serve one test would be a worse
trade than this line.
```
