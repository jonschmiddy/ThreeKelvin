# ShipRoom

## rooms

The ship-select screen stands each manufacturer's three hulls in a room of its own (Jon, Nov 22 to 24, the
approved films in `tk-scratch/shipselect/life2/`): Korvan's Parts depot (`mix18.mp4`), Solari's Casting bed
(`show18.mp4`) and the Old hangar (`A16.mp4`), where a locked manufacturer's tarps wait. The rooms replaced the
Shipyard deck's city hall, which the front door had borrowed since Nov 12.

A room is two layers, not one node, because the hulls sit between them: `under` holds the room's picture
and everything behind the stands (the wall's crew, the crane, the furnaces), and `above` holds what passes in
front of the hulls (the front lane, the forklift, the dust) and the room's air (haze, sheen). `YardFront`
puts `under` first, the three stand sets after it, then `above`, the floor's fade, the banners and the blur.
Nothing that can be clicked moves; life only passes behind or in front of it.

The base class draws the port package's static light (`tk-scratch/shipselect/final/PORT.md`, "Lighting"):
`lit = albedo x 2 light x gain`, the emissive over it unlit, sprites and posts lit at their own pixels, hulls
`rgb x (amb + 0.5 L) x rows`. Each room's class (`ShipRoomKorvan`, `ShipRoomSolari`, `ShipRoomOld`) carries
its film's own light model and life on top.

A locked manufacturer shows the Old hangar; Solari open shows the Casting bed; every other open manufacturer (Korvan, and the
five whose rooms are not drawn yet, which only developer mode opens) shows Korvan's depot.

## contact-shadows

PORT.md's contact shadow, one per post: an ellipse round the feet `rx = half the post + 2 + 3`, `ry = 6`, solid
where `k > 0.35` and ordered-dithered (4x4 Bayer on the frame's grid) in its rim, multiplying what is there by
`1 - 0.5 clip(0.45 + k)`. It only multiplies, so floor lines show through it darkened and are never cut. This
fixed Jon's "weird shadow under stand", a near-rectangular block. It is baked once when the posts are placed and
drawn as a multiply over the room, under the stands.

## posts-clear-the-guns

PORT.md's stand rule (Jon, Nov 22: "The stands go through the guns?" and "Why are the clamps over the ship?").
The old fixed `CENTRE +- APART/2` posts ran straight through the belly guns (the mining laser under the Korvan
light, medium and heavy). Now:

1. The belly guns are the launch kit's gun pixels that hang below the body's median underside less 6 rows, each
   run of four columns or more, plus 3 px each side.
2. A post (39 px, centred) may stand at a column only when its whole width clears every span, the hull alone has
   an underside over all 17 columns of its +-8 (their median is its seat), and it is 12 px inside the hull's ends.
3. Of the clear pairs at least 80 % of the berth's old spread apart (and not touching), the one that moves least
   from the old posts wins. Both posts are level: their top is the higher of the two seats less the tuck (3; the
   Old hangar's 4), so the top rows hide behind the belly and the hull rests on them.
4. A post is rebuilt to its height from the room's tallest: its top 41 rows (saddle, cradle) kept, the shaft cut
   or row 47 repeated.
5. The posts draw behind the hull, never over it, with a 1 px dark line (x0.45) on the post's pixels in the first
   row under the hull with its kit, so the cradle reads as holding it. Saddle rows over the hull read as grey clamps
   pasted on its side at game scale.

No clear pair is an error that names the hull and the span; it never falls back to a post through a gun (the
posts stand at the old spots only so the screen still draws). A tarp is measured the same way with no guns.
Korvan's launch kit gives heavy 377/521 top 258, light 128/266 top 278, medium 696/783 top 284 (PORT.md's table).

## fade-into-the-band

Jon, Nov 24: "I like how the scene fades into the bottom panel gradually like in the solari", then "the light
to dark transition can be smoother". The floor runs on under the band (there is no panel) and blends toward the
band's colour from row 372 to the frame's foot in 12 flat steps, each a twelfth more, with the first two rows of
each step a checkerboard of it and the one above, so no boundary reads as a line. It only ever grows down the
frame, and the last step is the band's colour. Each room has its own near-black (Korvan 14,16,22; Solari 12,8,6;
the Old hangar 9,8,7). This replaced the old 40-row fall to 8 % black, which sat the band on a slab with a hard
top. Life and light dim under it with the floor, so a lamp that goes out leaves no edge at the fade
(the Old hangar's A16 and A17).

## banners

Jon, Nov 24, on the rooms' films: "what's up with the flags? why do they have a weird thing behind them?",
"The banners still have weird artifacts on them", "The animation for the banners can be smoother", "The
Solari banner could be a brighter colour" and, of Korvan's, "like the gray and orange".

The cloth is drawn in code (`life2/bandfix.py`): three flat field bands (head rows 0-21, mid 22-85, the shaded
foot 86-99), the emblem, and a 1 px ink outline round the silhouette, the forked foot included, never a lit
fold pattern or anything behind it. Korvan's is a mid steel-grey (#7e848e, #6a707a, #565a62) with its name and
emblem in its hull-stripe orange #e0882e, a thin orange trim just inside the forked foot, outline #14161a.
Solari's is a rich amber (#eca034, #d68c2a, #b27020) with dark ink #2c1a0c, outline #28160a: the brightest cloth
in every room. The ??? cloths keep the films' dark tones. The five manufacturers not redrawn yet (developer mode only)
take their own field in the same three bands.

The sway is a slow wave travelling down the cloth instead of the old whole-cloth shear that snapped between nine
poses: `offset(r) = 1.5 (r/99)^1.5 sin(2 pi t / P - (pi/100) r + phase)`, P one of 5, 6, 7.5 and 10 s and a phase
per banner. Each row is laid at its rounded offset; the edge column past it takes the fraction as alpha, so the
outline creeps less than a pixel between whole steps. Over the cloth's top half the wave never reaches half a
pixel, so the name, the emblem and the ??? never move. The rod and chains never move. `SWAY_PX` went with it.
