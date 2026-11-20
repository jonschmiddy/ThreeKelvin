The reasoning behind `tkg/scripts/ui/SolariFurnace.gd` and `tkg/shaders/solari_furnace.gdshader`; each heading is referenced from the code by a `Why:` line.

## Furnace light

Jon, Nov 20, on Solari's lighting: "I would really like the lighting to be very different
from Korvan. The circle grate is a FURNACE... a burning light, and the energy from that
emanates from the center through the light pipes. Pulsing. Burning. C would have a chaotic
and almost unpredictable sputtering nature of the furnace, while an S tier ship is more
powerful but way more controlled. The cabin lights are steady on the S tier and kinda
flicker on the C tier." Three ideas were filmed as mockups (tk-scratch/hulls2/solari/lights);
he picked C, embers and flare-ups ("I really LOVE C"), with two changes: the pulses go aft
too ("Right now the left side is fully on or fully off"), and only the glass flickers ("The
frame of the windows shouldn't flicker lol").

How it is drawn: the hull's `lit` placements in art/hull_grade.json (the furnace's glow
disc, the forward and aft runs of the line, the cap's lens, the cab's glass pane runs) are
turned once into a light map, a texture the size of the hull: each lit pixel's part, its
distance from the furnace along its line (or its radius in the disc) and the art's own
lightness there. The shader sets each lit pixel to a colour off its part's ramp, made of
the art's own colours (the most saturated at each lightness step, and a white-hot top), at
a level times the art's lightness, stepped with a 4x4 Bayer dither, so the light falls off
in whole pixels and never adds a colour the art lacks apart from the white-hot top. A pixel
at its rest level is left as the bake drew it.

What moves, on the game clock (`ShipView` passes `GameClock.now()` or its shot clock):
the ember bed (each 2 px cell its own glow, nine changes a second), sparks rising through
the grate, and the flare-ups. Each flare eases up, holds at S, falls, and runs out both
ways from the furnace at one speed, to the cap (whose lens flashes when it arrives) and to
the stern clamp. The flares come from slots fixed by the hull and the time, never rolled
per frame, so a film and the game agree. `chaos` runs from 1 at C to 0 at S: at C the slots
jitter, some are skipped, some misfire weakly and die partway (each side on its own), some
cough twice, and the fall is quicker; at S they come every 1.4 s. The cab's glass is steady
but for a rare short, shallow dip: about one every 2 to 4 s at C, one every 8 s or so at B,
none at A and S.

Jon, Nov 20, on the first in-game film: "At the C tier, let's have the lights flicker a
biiiit less lol" and, of the cab, "looks like a rave going on there". `chaos` was 1, 0.6,
0.25, 0 for C to S and is now 0.65, 0.4, 0.18, 0: a C's flares jitter, misfire and cough
about a third less and fall a little slower, still clearly unlike S. The glass lost its
stutter (half a second of on-off at 12 a second) and its jitter outright. The halo round the rim and the lens
is added with the other hull lights.
