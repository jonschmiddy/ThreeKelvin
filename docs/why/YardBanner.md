# YardBanner

The ship-select screen's seven banners. `YardBanner` is each one's click target and its flat cloth; `YardCloth`
hangs and moves all seven; `YardClothAir` is what moves them, `YardClothLight` the rooms' light on them,
`YardClothMesh` their meshes and uniforms, `YardClothTex` the cloth's material. The source is Jon's banner page
(Nov 24, `bananim/wow_src_v1_canvas.html`, copied with its tools to `tk-scratch/shipselect/port/banner/ref/`):
"THIS IS EXACTLY WHAT I WANTED ... The movement is PERFECT".

## cloth

The flat cloth is built in code as the final banner page builds it (`bananim/make_cloths.py`, Jon Nov 24): three
flat lighting bands (head rows 0-21 lifted 15 % but at most 22 a channel, the body, the foot 86-99 at 82 %), the
emblem from `EMBLEM` in the manufacturer's colour, the name (or the ??? marks) in the pixel font, a 1 px outline
round the silhouette with its forked foot. Korvan's and Solari's keep their own tones, outline and Korvan's trim
(`MANUFACTURER_CLOTH`); the other five take their field as the cloth, their colour as the mark and an outline at
20 % of the field, and on a light field (Verity's, Calyx's: the three channels over 1.76 x 255) the name is dark
ink (34,24,14) while the emblem keeps the manufacturer's colour. The ??? cloth (Jon: dark grey main, light grey
accent) is `LOCKED_FIELD` #262830 in the same bands with an outline at 35 % and both ??? marks light grey
#a8adb8. The words are drawn into the cloth (`YardClothTex.word`, from the font's own glyph images, so it works
headless too), because the cloth bends and the marks bend with it. Every flat cloth comes out pixel for pixel the
page's (`ref/cmp_tex2.py`). Every ??? cloth is the same cloth, built once a session (`cloth_key`).

The click target did not change: the cloth at rest, forked foot and all (`on_cloth`, `_has_point`), at the same
rect, with the tooltip and the hover ring. The moving picture never moves what can be clicked. The old travelling
wave (`_wave`, `WAVE_*`) is gone with the old drawing. The hover's 1.18 brightening went too: the cloth's light is
now the room's stepped light, and a flat multiply over it broke the steps; the ring and the cloth's own shove when
the pointer comes onto it are the hover.

## material

Tapestry (Jon, Nov 24: of canvas, felt, silk, oilcloth and tapestry). `YardClothTex.make(src, key)` turns the flat
cloth into what hangs, so another material would go in at that one function. It is the page's `prepTex` tapestry
branch line for line: each row's commonest colour is its field; a pixel is the outline within one of a hole, a
painted mark otherwise when it is not the field; the field (x0.9) carries the manufacturer's damask tone on tone
from six rows down and five in (`PATTERNS`: Korvan's stacked chevrons, Solari's four-point stars in half-offset
rows, the ???'s faint twill, Probate's stencilled claim diamond, Redline's paired forward slashes, Verity's fine
lozenge with a centre stitch, Cygnet's hive cells, Calyx's its emblem shrunk to an 8 x 8 tile by the page's rule);
the rod sleeve is darker (rows 0-3 x0.8, the seam x0.66); two and three pixels in from the edge runs a two-tone
border in the manufacturer's accent (`ACCENT`: Korvan #e0882e / #96561a, Solari #b8401a / #76260e, Probate
verdigris, Redline red, Verity claret, Cygnet cyan, Calyx green, the ??? light grey); the field under a mark sits
in (x0.82); the whole field is saturated x1.12; a short fringe hangs off the fork's edge every other column in the
accent's dark tone (it is texture, so it moves with the grid); the marks are embroidered (a satin stitch, a lighter
stitch along the top of each broad mark). The border and fringe are accent threads: they glint and carry their own
colour as the rim's. Bytes are stored as the page's Uint8ClampedArray stores them (half to even), and its hash is
the page's, JavaScript's 32-bit arithmetic and its one double product included. Each cloth is baked once a session
(`YardClothMesh.made`, about 25 ms a cloth), never per frame.

Tapestry also takes light its own way (the page's MATS.tapestry): folds read x1.8 deeper, every light wraps 0.15
further (at most 0.9), the cloth's stepped brightness goes through a 1.05 power (a mark's whole steps do not), and
a mark or an accent thread glints past 0.05, the thread toward warm white.

## light

Each room's lights are the page's ROOMS, placed where the room shows their sources over the whole hall rather
than the page's 304 px strip: Korvan's ceiling cone lamps at its top tubes' centres (x 22 to 919, y 13, z 22) and
the cool rim light; Solari's furnace rings behind every tap (`ShipRoomSolariCycle.TAPS`, y 100-102, z -16, each
with its own flicker phase) and the floor's bounce; the Old hangar's sodium lamp at (483, 24, 16). The exposure
puts the brightest of all seven banners' faces at the room's level, as the page does over its three, so each
room's look holds. Each banner throws its shadow from its nearest shadow lamp, as strong as that lamp is there
(Solari's, with none in front, a soft contact shadow), and its rig takes the light at its rod.

Two things follow the room where the page had none: the Old hangar's lamp fails with the room's own lamp
(`ShipRoomOld.lamp_at`), so the banners go dark when it does instead of glowing under a dead lamp, and a launch's
stutter (`ShipRoom.lamp_k`) takes every lamp.

## gpu

The page's cloth is a 13 x 25 Verlet grid (`HS` 1/120 s, damping 0.996 a step, gravity 560): the slack across
the lower cloth, the stiff head, the forked foot's two free flaps and the centre strand, shear and bend springs,
six Gauss-Seidel sweeps, the tethers from the rod and the wall 8 px behind. Seven of them at 120 Hz is about
1900 constraints x 6 sweeps x 7 x 120 a second: some 20 ms a step a banner in GDScript, so it runs on the GPU.
The renderer is gl_compatibility (no compute), so the state is a 78 x 175 viewport that is never cleared, one
texel a value (Px Py Pz Ox Oy Oz of each node, 24-bit fixed point in RGB, 1/32768 px; RGBA16F is too coarse for
Verlet's velocities), and each pass is a ColorRect that reads the state as the screen texture after a
BackBufferCopy and writes it back. A frame's passes: one that puts the bake in where nothing is written yet, then
per step an integration (the page's forces, uniforms from `YardClothAir`; the rod's swing from the cloth's moment
in one texel a banner) and 14 relaxation passes, the last with the tethers and the wall.

Gauss-Seidel cannot run in parallel, so the GPU relaxes every constraint at once (Jacobi): each node moves by 0.55
x the sum of its constraints' corrections. Measured on the page's own scene (`ref/tune.py`: the hang, a sweep, a
click, a slow drag, the stir): 14 passes at 0.55 hang and swing within 0.18 px RMS (worst 1.8 px in a push) of the
page's six sweeps in its calm air and 0.23 px (worst 1.7) in its breezy one, with the same frame-to-frame jitter;
above 0.6 it chatters, at 0.8 it blows up. The game's GPU
cloth against the page's code running that same solver (`ref/sheet.py`, the GPU state read back) is 0.02-0.15 px
RMS over 20 s of pointer and stir: float32 against doubles.

The page builds its springs with one quirk kept: its shear loop runs one past the grid's right edge and wraps, so
each row's left and right edges are tied across (rest length the row's width, the shear's stiffness). It is part
of how the approved cloth holds its width and its fork, so the shader keeps it.

Two bugs found on the way: the fixed point must round half to even before the offset (adding 256 first rounds the
negative values to a finer grid and then up, which drifted every cloth 0.4 px toward you in a second); and the
bake comes in by its own pass each frame, because a screen texture cannot be passed into a shader function in
Godot, so the integration cannot read "the state or the bake" through one.

The steps are whole 1/120 s steps on the cloth's own clock (process time), at most four a frame: two at 60 fps,
four in a `--fixed-fps 30` film, so films run at true speed with the page's step. The page hangs its cloths 3 s
before its first frame; the game starts from that hang, baked by the page's code with the GPU's solver
(`ref/bake.py` -> `banner/hung.png`), at the page's tSim of 3 s. Headless (the tests) there is no renderer: the
banners keep their click targets and the cloth hangs at rest. Cost, measured (`ShipRoomShot perf=1`, RTX 3070,
the window at 72 fps): `YardCloth._process` 0.03 ms; render CPU 0.19 ms (state), 0.10 (lit), 0.08 (wall); GPU
0.21, 0.06 and 0.56 ms. Nothing is built per frame.

## pointer

`YardClothAir` is the page's wind, stir and pointer on the game's seven banners. Each banner's lean and turn
period and phase and fold phase are the page's seven-banner hall's (its MAKERS7: lean 8.3 s + (1.37 i mod 2.6),
turn 6.4 s + (0.97 i mod 2.5)). The air is the page's breezy (Jon, Nov 24: lean 76, twist 12, fold 48, breeze 21,
gust 1). The gust walks the hall banner to banner, left to right, at the page's 70 px/s from the page strip's left
edge (frame x 108), and lets go once it is past the seventh banner, not the page's third (8 s plus 6.4 s). The pointer is the page's: a shove the way the hand was moving on coming onto a banner (1.2 +
speed/70 up to 3.8, dying over 0.35 s), a continued push while it moves (0.12 + speed/90 up to 3.1, radius 18),
a click a straight-in push (2.4); its speed is smoothed over its moves on the cloth's clock, so a film's pushed
events move the cloth as a hand does. A click pushes only inside the banner's box (the page's strip was only the
gantry, so it pushed the column). With nobody pointing for 5 s a stir sweeps across one banner over 1.8 s every 7
to 12 s, the banners in turn. Its random is a seeded MINSTD shared with the reference, so a film is the same
every run and lies beside the page's code frame for frame.

## pixels

The game draws at 1x and the shell scales it, so the cloth is drawn into its own 1x viewports and shown nearest:
the lit cloth is an orthographic 3D render (960 x 320: the lit cloth over the field colour each pixel shows),
depth-tested as the page's z-buffer is, the cloth's texture nearest; each fragment is the page's lightAt (the
room's lights summed, its brightness stepped in 0.1 steps with a narrow Bayer band at each step on the frame's
grid, whole steps on a painted mark so it never speckles, folds read deeper x2, the glint on a mark). The shown
picture (`yard_cloth_show`) adds the rims (the outermost edge pixel whole, the one inside it half and dithered,
stepped in quarters, in the row's field colour), the rig (chains leaning with the rod on fixed mounts, the rod
with its bent ends, swung up to 1.6 px, in its light) and the hover ring, where the banners always were in
`YardFront`. The shadow is a 960 x 208 mask (the wall to its foot: the page's strip cut it at row 160) of the
cloth, rod and chains thrown onto the wall, multiplied into the room with a dithered penumbra as the last thing
in the room's `under`, under everything that is not the wall.
