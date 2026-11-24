# ShipRoomSolari

Solari's ship-select room, the Casting bed, ported from Jon's approved film (Nov 24: `tk-scratch/shipselect/
life2/solari/r14/show18.mp4`, drawn by `show18.py` and its imports). The film's code is the source of truth;
`tk-scratch/shipselect/port/solari/export.py` imports it and writes everything static into
`art/sprites/station/shiprooms/solari/`.

## light

show18 lights the room as `engine.Lights` does: every light is a field on a 2x2 cell grid (480 x 270). A cell sums
field x weight x colour (l3), the weights (s0) and the weights x breath (s1). The sum is stepped into sixths (below
1.5 steps it runs smooth), what passes 1 is kept as a little extra brightness, and the breath multiplies after the
stepping, so a breathing furnace never makes its band edges creep. The room is `albedo x m x 1.7`, the burning layer
over it unlit.

The static fields are baked by the exporter from the film's own functions (`fields.png`, 32 channels, 4 to a layer):
the lamps, the bed and front-lane lights and the ring band's steady fill as one RGB+weight layer; each furnace's
wall, foot and floor glow; each pour's floor fan with the posts', hulls', lift's and fettler's shadows in it (an
area light, `shadows13.area`); the posts' backlit faces; the roar's flood out of furnace 2 at five openings, which
is where the long ship shadows on the floor come from; the arc at the welder's three torch positions; the grinder's
and the lamp tech's spills; the tired lamp; the ring band and the inner lips. The pools that move (a pour's wall
glow and landing, a mould's heat, the jib lamps, a carried plate, the beacon's sweep, the drone) are computed in the
shader from a list set each frame, with the film's own pool shapes: on the wall round 14's soft bump (never a box),
on the floor the ellipse. The people walking through a pour's or the roar's light cut their shadows out of it
analytically (`shadows13.point`).

The shadow fields were baked round the GAME's posts, not the film's: the game moves the posts off the belly guns
(Korvan's gun rule), so Solari's posts stand 13 to 51 px from where the film's stood. The posts the bake used are in
`layout.json` (`solari.game_posts`); if a hull's kit ever moves them, run the exporter again.

The hulls are lit as `show18.light_hulls`: core2's warm key from the furnace wall, shaded toward the belly; the room's
hull lights (the furnaces, the pours, the cooling moulds, the roar, the arc, the grinder, the lamp tech's lamp);
the floor's light under the hull bouncing up into the belly with a steady warm fill; the rim stepped in three and
only where the outline faces one of those lights (Jon, round 10: "the outer glow on the Solari ships is odd"); the
brass catching more as the fire flares. The hull's own furnace is the game's (`SolariFurnace`), drawn over it.

## cycle

No conveyor: six moulds sit still under the six taps, and one tap opens every 5 s in the order 2 5 3 6 4 1, so the
light jumps across the hall. A bay's clock u runs from its tap opening: the pour 0-2.73 s (white-core stream,
splash, sparks, the fill rising), the full mould white-yellow to 5 s, a crust and the cooling bands to 15 s, the
quench 15-17 s from the fixed nozzle on the bed's lip (spray and round steam puffs), the jib 19-25.5 s lifting the
plate onto the bay's stack, then the mould waits empty. Every state is a pure function of the clock, as in the film,
so the loop wraps without a seam.
