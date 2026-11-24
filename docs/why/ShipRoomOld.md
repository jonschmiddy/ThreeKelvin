# ShipRoomOld

The Old hangar (Mothball racks): the room a locked maker's three tarped ships wait in. Jon approved the
film `tk-scratch/shipselect/life2/old/A16.mp4` on Nov 24 and then asked for A17's lamp ("there is a bit of
light on the floor of old when the lights are off"). The film's code is the source of truth:
`life2/old/A5.py` (TK_VARIANT=A17), `oldbase.py`, `tarp_wind.py`, `gen/old7.py`, `gen/stands8.py`. Everything
static is exported from that code by `tk-scratch/shipselect/port/old/export.py`, so it matches the film exactly.

## two-layers

The hangar is lit as two layers. `amb.png` is the ambient light alone (the cool `(0.19, 0.19, 0.23)` with
its rise to the wall's foot); `lamp.png` is the lamp's own light (the cone up the back wall, the floor pool,
the glow at the mouth, the spill onto the side berths and the heavy tarp's shade under it), lamp on minus
ambient. Both are the film's stepped maps (6 levels, the film's 2x2 dither), stored x48 so each step is a
whole byte. A frame is `albedo x (ambient + lamp x level)`: with the lamp out (level 0) it is the ambient
frame exactly, with nothing lamp-shaped left. That was A17's fix: A16 dimmed each pixel by a "lamp share"
measured on a picture that had the A11 floor lift and a palette baked in, so a warm remnant of the pool stayed.

- The A11 floor lift (rows 378-439, the lamp-lit floor running down to the floor's own level over 56 rows
  instead of stopping dead at the berth lips) is the lamp's: it multiplies lamp-on light by `f`, so it goes
  on and off with the lamp. `f` (1 to 5.1) rides in `lamp.png`'s alpha as `255 - (f - 1) x 48`.
- The lamp's box (rows 0-30, x 462-503) has no ambient: its housing goes dark with the bulb. The bulb's
  pixels (`emissive.png`) are drawn times the level.
- The bulb's glow is the film's halo: 4 stepped levels round the mouth, the top 40 % of each step dithered,
  screened on in the sodium colour `(255, 208, 142)` times `min(1, level)`.
- Posts, hoses and anything standing in the room are lit as the room is at their pixels (they were albedo in
  the film). Tarps are lit as the film lit sprites: `rgb x (0.35 + 0.5 clip(L, 0, 1)) x rows`, rows 1.08 at
  the posed sprite's top to 0.78 at its foot, with the same blended light.

YardFront's fade into the band blends toward the room's near-black `(9, 8, 7)` over the room after this, so a
dimmed room fades with no edge.

## the-lamp

The lamp is A17's schedule on the film's 10 s loop (`A5.lamp`): two long outages (2.05 s for 0.75 s, 5.55 s for
1.30 s) at level 0, each stuttering back on frame by frame; five bursts of flickers; and a steady hum of
`1 + 0.018 sin(2 pi 3t/10) + 0.012 sin(2 pi 7t/10 + 1)`. Frames are 30 fps steps (`round((t - t0) x 30)`), so a
flicker lasts as long as it did in the film at any frame rate. The level multiplies after the stepping, so no
band edge ever moves. A launch's beat (`lamp_k`) multiplies it too.

## dust

The dust is the film's own: A5's 700 far motes (behind the tarps), 400 mid motes (a quarter of them flakes that
glint once or twice a loop), 18 near motes with two dimmer halo pixels, and the dust a gust shakes off each tarp's
top as it reaches it (a kick up, a sink down the face, a drift outward). `export.py` runs the film's code and keeps
each mote's track: its pixel each frame (the film's slow ellipse, snapped with hysteresis so it never steps back
and forth) and its brightness there (how lit the air is at that pixel, its glint, its fade). A mote is never drawn
where the air is unlit. The game draws them all in one MultiMesh per layer; the shader reads the track at the
frame (30 a second on the 10 s loop, which the film made seamless) and screens the mote onto what is under it in
the sodium colour times the lamp's level, so the dust goes out with the lamp.

- The far motes are in `under`, so they pass behind the posts as well as the tarps (in the film they were drawn
  over the posts, which were painted into the room). They hang in the air behind the tarps, where the posts are.
- The near and mid motes and the shaken dust are in `above`: over the tarps and under the banners, so they pass
  behind the banners with no masking (the film masked the banner's silhouette by hand, A12).
- Overlapping motes: the film kept the brighter; here the later one is drawn. They rarely overlap.
- The shaken dust starts at Solari's tarps' tops (the film's). Another maker's tarp is the same size with a
  slightly different top edge, so its dust may start a pixel or two off the cloth.
