# ShipRoomKorvan

## light

Korvan's Parts depot is lit exactly as its approved film (`tk-scratch/shipselect/life2/korvan/r18/mix18.mp4`,
Jon, Nov 24) was. The film's light model (`core.py`) is ported to `ship_room_korvan.gdshader`, and every field
it stepped is exported offline from the film's own code (`tk-scratch/shipselect/port/korvan/export.py`), so
the game reads the very same stepped values:

- the static light is each wall tube's stepped cone (top, middle and low rows of tubes, 24 in all) times its own
  weight this frame, the rails' stripes on the top and middle cones, and the floor's even overhead light; the
  crane's load keeps the lamps off the wall under it;
- the moving light goes into the film's four buffers: `dyn` (the wall and floor), `dobj` (things standing up),
  `dsh` (the hulls) and floor-only pools. Point lights are worked out in the shader as the film's
  `core.point` (six steps, the outer quarter of each dithered) or, below a round shape, round 18's twelve
  ordered-dithered levels; the burner's, the door's, the arc's and the ladder lights' fields are the film's,
  each scaled by one number a frame;
- a lit pixel is `core.shade`: the brightest channel is how much light, the ratios its colour, strong light
  washing over dark paint, times the film's gain 1.45;
- the emissive goes on over the lit room, each tube's and the door lamps' following their weight;
- posts take the stands' own light (`stand_light x 0.9 x WORK`) plus the moving light, lit on the side facing a
  work light (`shadows6.side_lit`) and backlit by the loading door (`door7.stand_backlight`);
- hulls take mix18's `hull_light`: the berth lamps' ship field times a stepped row light (lit top, a hard
  terminator a little below the middle, the floor's bounce on the belly), plus `dsh`, capped at 0.98.

The floor is the film's code-drawn plate grid (round 18 laid it after `stands5.rebuild`): flat plates, straight
joins, a rivet at each plate corner, no painted cracks.

## clock

The film is a seamless 30 s loop at 30 fps, and the room runs on its clock: the room's time is snapped to the
film's frames (`f = round(t x 30) mod 900`, `t = f / 30`) and every plan, event and light is the film's own
function of that time, so the room plays the film's 30 frames a second and wraps where the film wrapped (its
seam was measured as close as one frame's step). Python's `round` is half-to-even and the film placed things
with it, so the port does too (`pyround`).

Everything the film drew from numpy's generator (`core.rngk`: a lamp's dips and stutters, the arc's strength
and ragged pixels, the burner's rim and flicker, sparks' throws, the heat shimmer's rows, the burnt part's
embers, the drones' prop blur) is not re-rolled: `export.py data` writes those draws into `film.json` per frame
or per tenth of a second, so the game shows the very same ones. Anything worked out without the generator
(walks, eases, swings, door and burn curves) is ported as code.
