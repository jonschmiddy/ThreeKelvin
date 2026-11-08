The reasoning behind `tkg/scripts/ui/PixelTurn.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Pixel turning

Above `enum Mode { SMOOTH, STEPPED, BLENDED, STILL, ROT8, SOFT, FADE }`:

```text
HOW PIXEL ART TURNS, game-wide (Jon: "can these rotate smoothly WITHOUT
shimmer? like can we just fix that for the whole game?").

A picture turned by a fraction of a pixel a frame re-picks its pixels every
frame, and where a thin line or a corner sits across the pixel grid a pixel
goes A, B, A: shimmer. Three ways to turn, one switch:

  SMOOTH   as the game has always done it (the default): a tumbling piece
           turned live on screen, a world's surface turned by any fraction
           of a pixel a frame, the mines a picture every 15 degrees.
  STEPPED  held still and moved a whole pixel at a time (the farthest pixel
           of a piece, a world's equator). No shimmer, but it ticks. Jon has
           turned this down twice ("i guess i kinda just liked the smoother
           one"); kept only to compare against.
  BLENDED  turned every frame and held steady: each pixel is worked out from
           many points across it (a piece: 16, the commonest colour wins; a
           world: 4, the commonest ground wins, its brightness the average),
           and a pixel keeps what it showed until the new answer is clearly
           better (hysteresis), letting go after `RELEASE` frames so nothing
           low-contrast freezes. A world's value is also eased 0.35 a frame.
           The star-chart mockup's planets, which Jon took, for every world
           and for every turning sprite (`Turner`, `pixel_turn.gdshader`).

WORLDS BLENDED, SPRITES SOFT. Every world the planet painter draws
(`PlanetView`: LOCAL's world and its moons and rocks, the painter's moons on
LOCAL, the map's worlds, the panel's portrait) turns BLENDED (`world_mode`;
Jon of the giant, the ice moon and a map world: "THESE LOOK GREAT!!!
Especially for rotating bodies"). The turning sprites (`mode`) turn SOFT:
BLENDED still shimmered to his eye ("This still shimmers a lot"), and of
the round-two trials he took the soft turn ("I kinda like C soft turn").
Harness switches: `turn=blended|stepped|smooth` sets both; `worldmem=off`
puts the worlds back on today's path, to measure against.
`rolllive` (harness): the mines' roll turned live in SMOOTH, for the
comparison page's left-hand clip.

THE SPRITE TRIALS (harness only, `turn=still|rot8|fade|small`, sprites alone;
the worlds stay BLENDED), after "This still shimmers a lot":
  STILL    not turned at all: the picture held whole, its drift in whole
           pixels, and the tumble (or the roll) shown in its LIGHT instead --
           the star's side swinging round it and a glint rolling across the
           hull (`local_subject.gdshader`'s `glint`), as a world's terminator
           and surface move while its outline stays put.
  ROT8     BLENDED from a picture blown up 8x by Scale2x three times
           (RotSprite's way: corners and diagonals rounded before the turn),
           so the turn re-picks fewer stair-steps.
  SOFT     turned with its 16 points averaged in linear light and its edge
           partly clear: a soft turn, no pixel ever picked.
  `small`  ROT8 with the tumble and the roll cut to `TUMBLE_K` (0.35).
  FADE     STEPPED's pictures -- each held whole, the next a whole pixel on at
           its farthest point -- but each step dissolved into the next over
           `FADE_F` frames in linear light, so the step is a soft move, not a
           tick, and between steps nothing changes at all.
```

## Turner

Above `class Turner extends RefCounted:`:

```text
A TURNING SPRITE, drawn by `pixel_turn.gdshader` into a picture of its own
(`texture`), never rotated on screen: show `texture` unrotated, unscaled and
centred where the sprite's middle is. The picture is even on both sides so
its pixels sit on the screen's.

BLENDED keeps the picture last frame (a second viewport copies it each frame,
as `map_palette`'s hold does) for the hold. The picture's alpha carries how
long a pixel has been held, so whatever shows it snaps alpha at a half
(`local_subject.gdshader`'s `snap_alpha`).
```
