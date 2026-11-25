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

The lift arc's floor pool is round 20's (mix20, Jon: "no shadows on the stands from the guy welding"): it
reaches past the posts (`soft12(clip(E x 1.3) ^ 1.25)`, no longer `E ^ 2`) and the heavy's posts and the lift throw
shadows straight away from the arc's floor point, cut out of it with a pair-dithered edge (`floor_shadow20`). It
is exported from the game's own post positions (x 359 and 503, a pixel right of the film's), and it flickers
with the arc because the whole pool is scaled by the arc's level each frame.

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

## life

The film's life is ported from its own code (mix18.py and what it imports or execs): the same plans, paces,
poses, timings and positions, each piece drawn where and when the film drew it, in the film's order (behind
the hulls in `under`, in front of them in `above`). A piece is a `ShipRoomKorvanPaint` layer that is cleared
and redrawn each film frame from rects and sprite regions, and lit the way the film lit it: a sprite at its own
pixels under the object light (`blit(light=L + k)`), at one point of it (`shade_at`), code-drawn colours times
a clamped light level (`kl_at`), the room's light for the film's albedo edits (the hoist block, the door panel,
the heat shimmer), or as drawn for what burns. Contact shadows are multiplies (`core.contact`), glows and beams
adds. The code-drawn pieces (the lift risen to the seam, the forklift, the crane's parts and trolley, the
drones, the corridor, the tinted crew) are exported once into `atlas.png`; the Yard's own crew strips are read
from the Yard's art.

## air

The film's air (`hero.py`, mix18's `post_light` and `_finish`) is in two places, as the film laid it:

- behind the hulls, added over the room: each wall tube's shaft at its own tube's weight (the shafts never
  overlap, so one field and an index of whose it is), the berth lamps' shafts down onto the hulls' tops (the
  crane's load cuts them under it), the door's shaft while it is open, and round 20's faint cool haze high in the
  hall inside the cones (atmos20's four dithered levels), so the cones read as volume;
- in front of the hulls (mix21's after_hulls, Jon approved mix20 and mix21): atmos20's 200 motes, seen only in the
  lamps' cones and the berth shafts, each held to whole pixels as the film held them (their place per frame is
  baked, `motes20.png`), glinting slowly; and the weld smoke, thin wisps rising from the lift's arc and the
  ladder welder's while they burn, drifting in the hall's draught, each a dithered puff lit by the room (and the
  arc near the arc);
- over everything under the banners, one pass reading the screen: the worn deck's sheen (what is bright over
  each line where things meet the floor, mirrored, blurred a pixel, stepped in sixths of 48), the haze (the
  room blurred 21 px wide, dimmed, mixed in by the film's stepped depth map: thick high on the far wall, clear on
  the near floor, light on hulls and stands, and only 0.17 on the crane so it stays crisp) and bloom (a 7 px and
  a 19 px box of the bright part, stepped in sixths of 72).

The haze's wide blur is read from the screen's mipmaps (a 5 x 5 grid of 4 px cells) and bloom's wide box from a
3 px grid, instead of the film's exact box sums: the same widths at a fraction of the reads. The bloom's source
takes the haze at each sample by the same depth map, with the blurred colour of the pixel being finished.

## crane-rail

Jon picked B1 for the rail the crane runs on (mix21): `rail_B1.png`, a seamless 140 px box-section track tile, repeated
across the top band with its rod row (12) on frame row 11, so the box spans rows -1 to 8 and the cab's wheels (row 9)
ride its lower lip. It is lit as wall art (an ambient 0.95 plus 0.9 of the room's light, clamped 0.4 to 1.6) and drawn
before the shafts and the haze. It replaced round 11's code-drawn grey girder.

## cost

The room's life is built on the film's 30 fps step, not every frame: on this PC it costs about 1.6 ms of GDScript a
film frame (0.8 ms a frame at 60), down from about 7.5 ms. What took the time, and what was done:

- every spark (the lift's arc, the ladder welder's, the grinder's, the bench grinder's) is baked per film frame from
  the film's own throws into `sparks.png` (a column per spark, a row per frame); each set is a fixed list of 1 px
  rects drawn once and moved by `ship_room_korvan_fx.gdshader`. The motes are the same (`motes20.png`). No particle
  is touched by GDScript;
- a contact shadow is one rect worked out by `ship_room_korvan_contact.gdshader`, not a rect a pixel;
- the holo-table's turning hull is drawn on the GPU (`ship_room_korvan_holo.gdshader`, the film's pixel lines);
- what never changes is drawn once and kept (the platforms, the floor lamp and its beam, the desk, the rail, the holo
  room's walls, cone and table); what changes with a few numbers is drawn once per state and recalled (the office's
  clerks, the hoist's chain, the lamp tech's arm and beam by where he aims, the crane's rigging by its swing, moved
  with the trolley);
- a layer's ops sit in packed arrays, and a light setting or a shader parameter is sent only when it changed.

## instance-slots

Godot keeps every canvas item's instance uniforms in one global buffer (4096 vec4 slots for the whole screen), and
each instance uniform a shader declares takes a slot on every item drawn with it. The room's life shader declared
six (rows, lmode, lp, lk4, ladd, lsrc) and the contact shadow two: 172 items used 980 slots, so two Korvan rooms
alive for one frame (a screen swapped while the old one waits to be freed) filled the buffer and items lost theirs.

Each item now carries everything it needs in ONE slot (`li`): a hull its top and foot rows; a life layer its light
mode, the door's warm add as one bit and its light point's whole pixel packed into one exact integer, its offset,
its clamp packed as hundredths, its multiplier; a weld wisp its centre's whole pixel, radius, density and which arc
(the two arcs' places are plain uniforms), the centre's fraction riding in its rect's colour (the item's origin is
not usable: batching can bake it into the vertices). A contact shadow packs its darkness with its length. 172
items now use 172 slots, and the picture is the same to the pixel.
