The reasoning behind `tkg/scripts/ui/sysmap/SystemView.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Sector map picture

Above `const PANEL := 0`:

```text
THE PICTURE OF ONE SYSTEM, as the approved mockup draws it (scratchpad
`sysmap/template.html`, `frame()`), in its order:
  1. the sky: its own nebula, baked once, its gas drifting (`SkyBake`,
     `sky.gdshader`), a few stars twinkling;
  2. the asteroid belts, lit warmer and brighter near the star;
  3. each world's shadow thrown across the plane away from the star;
  4. the star;
  5. THE PALETTE PASS: all of the above set to the system's own short
     palette (`SystemPalette`, `map_palette.gdshader`);
  6. the faint grey fabric of space sinking under the star and each body,
     and the faint grey orbits, each with a trail behind its body -- after
     the palette, so faint lines are not rounded away;
  7. the worlds (`PlanetView`, `ShatteredView`) in their own colours, nearest
     last, a world behind the star hidden by its disc; their moons.
The beacons, the ship, the selection and the panel are the screen's.

Everything is in game pixels on the 960 x 540 canvas, the orbital plane seen
at a slant (`TILT`). THE CAMERA: the map zooms (`zoom`, 1 to 4) and pans
(`pan`), so a point (x, z) on the plane is at origin() + (x, z * TILT) * zoom
on screen, with the star at origin(). Zoomed, nothing is stretched: the
worlds, the star and the lines are drawn again at the new size, and the sky
slides behind them by a tenth of the pan (Jon: "a parallax background").
```

## Sky parallax

Above `const PARALLAX_AT := 0.5`:

```text
THE SKY IS AT INFINITY, SO ZOOMING DOES NOT MOVE IT (Jon: "When I zoom in,
the stars in the background of the sector map move a LOT ... The panning
movement makes sense for the parallax, just not the zoom"): the layers slide
by where the camera looks on the plane (the pan over the zoom), not by the
pan in screen pixels -- which grew with the zoom while the view held a world
or the ship, and slid the stars hundreds of pixels. PARALLAX_AT is the zoom at
which a pixel of pan slides each layer by its rate, as it always did.
```

Above `const PARALLAX_VEIL := 0.28`:

```text
MORE DEPTHS (Jon: "can we have more layers for the background parallax"): a
veil of faint gas in front of the far nebula, and star fields from far to
near: [count, faintest, brightest, share with a plus, parallax]. Five depths
of stars (Jon: "No distant stars or galaxies parallax in the background"),
the nearer bigger, warmer and sliding more; the last a scatter of dim dust
motes, nearest of all. Behind them all the distant galaxies (`SkyGalaxies`).
```

## Dust depth

Above `const DEPTH_K := 0.9`:

```text
DUST IN DEPTH (Jon: "can we make the space dust of the sectors ...
volumetric? ... I almost want the sectors and galaxies to look fluffy and
deep"; he picked C, both): sheets of dust at their own distances, each sized
and slid by where the camera is (`_step_depth`) -- wisps behind the plane,
fluffy masses lit from the star's side, and sparse wisps in front that you
pass through as you zoom.

HOW MUCH, ONE DIAL: 0 is the map as it was, 1 every sheet at full strength;
each sheet's strength is its full strength times DEPTH_K. Jon picked 0.9, to
match the star chart's. A harness or a try-out takes `-- depth=K`.
```

## Nebula sky

Above `const NEB_SKY := preload("res://shaders/sky_nebula.gdshader")`:

```text
THE NEBULA SEEN FROM INSIDE (Jon: "YES THAT WOULD BE SO COOL"): in a
nebula's systems the sky is the cloud itself, by its kind and its colours,
as the star chart draws it (`sky_nebula.gdshader`), lit by the system's sun,
with the depth sheets over it; and now and then its weather (`SkyWeather`).
`nebsky=0` on a harness's command line shows the old sky. (Before SIMPLIFIED the
old baked gas was kept faint under it, at 0.6, its dust at 0.55: the cloud
carries all of both now.)
```

## Rendering styles

Above `const STYLE_SIMPLIFIED := &"simplified"`:

```text
SIMPLIFIED (the rendering style Jon kept from the showcase as direction C,
"Alive", and the default): the cloud is baked once (`SkyBake.field`) and lit
every frame by the system's own sun, its gas streaming; the old gas and dust
of the bake under it are gone (the cloud carries all of it), and so is the
sky's own glow round the star (the cloud is lit by it instead).
The style setting itself is `DisplaySettings.render_style` (`style()`); the
screen draws the system again when it changes (`Sig.render_style_changed`).
```

Formerly above `const STYLE_LEGACY := &"legacy"`, gone Nov 7:

```text
(LEGACY, the sector map as it was before SIMPLIFIED, was a style of its own
until Nov 7: its old cloud, faint baked gas, the sky's glow round the star,
old dust sheets, grey belts and the pulsar's web all went with it.)
```

Above `const STYLE_RADIANT := &"radiant"`:

```text
RADIANT (`radiant`, `is_radiant()`): direction A, "light through gas". The
sky is SIMPLIFIED's cloud (so every event of the weather lands where it
does), lit as a volume the sun shines through: the worlds throw true shadow
shafts through the lit gas, the dust between a place and the sun dims its
light and reddens what shows through it, a flare lights the gas, a strike's
light scatters, a pulsar's beams light a fog; a clear sky keeps its plane's
faint dust lens (`sky_nebula` and `sky.gdshader`, `radiant`); a moon
goes dark in its giant's shadow; a world's air glows at its limb when lit
from behind.
```

## Field under

Above `var field_under := false`:

```text
ON THE FIELD (`NavField`, the sector map's: Jon, Oct 18, "stars fill the
entire panel edge-to-edge"): its own far stars, galaxies and twinkling ones
left out, the stars the picture shows are the field's under it
(`SystemMapScreen` keys its empty sky away, `nav_key.gdshader`)
```

## Reserved palette steps

Above `const C_RESERVED := {`:

```text
A CLOUD'S RESERVED STEPS in the palette (C's shared tokens), by kind: the
emission bubble's dark teal (its glow falls to a dark thin gas, and without
them the outer bubble set to one teal plate), the strike's white-hot core and
deep H-alpha steps, and dark wine and violet steps so dust in shadow never
snaps to the void; the reflection haze's light turning blue, and its deep
navy; the core's disc colours and its cool far smoke (5)
```

Above `0: ["#1e3233", "#283f3f", "#33504e", "#3f625f", "#4a7672", "#558a85", "#ffe8f0", "#4a1426", "#6a1c34", "#8c2842", "#b03452", "#130a13", "#1a0a14", "#2c121e", "#1a1026"],`:

```text
(the strike's pale pinks are left out: in the palette they took the cloud's
brightest rose for themselves and set it as a candy-pink plate; its deep
H-alpha steps instead, so the rose keeps its depth)
```

## Block grid

Above `const SCENE := Vector2i(480, 270)`:

```text
THE PLACE IN 2x2 BLOCKS (Jon: "everything looking like B would homogenize the
look"): the sky, its stars, the star, the worlds, their rings and moons, the
belts and the shadows are drawn into a picture half the size and shown at
twice, so all of it sits on one grid of 2x2 blocks. The orbits, the fabric,
the beacons, the cursor and the words stay single pixels on top, as the
chart's markings do over its galaxy.
```

## Strip past the picture

Above `var _past: SubViewport`:

```text
THE CLOUD PAST THE PICTURE'S END (Jon: "the mirror is visible"): the map's
picture is 960 px wide and the screens' area runs on past it on the right
(under the side panel); in a cloud the same cloud is drawn on there, its own
material on a second rect in a strip of its own, `PAST_X0`..`PAST_X0 +
PAST_W` of the sky's px (its first 32 px over the picture's last, for
`cloud_round.gdshaderinc` `sky_wide` to hand over in). Null with no cloud.
```

Above `func _past_build(hold: bool) -> void:`:

```text
THE STRIP PAST THE PICTURE'S END (`_past`): the picture's own sky layers
again, in their order, over the sky's px `PAST_X0`.. -- each rect drawn
from its own pixel the same way (the sky, its veil, the dust sheets: their
material's copy told its span, `px_span` / `px0`; the cloud: its own
material, which reads its pixel from the rect's corner, on a rect started
`PAST_X0` back; the palette last, which reads the screen, the strip starting
on its dither's cells). The worlds, belts and drawn stars are not carried:
the strip is the cloud. Not in PAINTED (its paint pass is the picture's).
`hold`: round a pulsar the palette reads the picture's last frame -- left off.
```

## Twin suns

Above `var star2: Node2D = null`:

```text
STAR B (ruling 20, Oct 30: two suns): its own SunView where the pair has it
(`star_screen`; the pair turns, ruling 23),
null with one sun. Sized as star A is, through the same 2x2 blocks and the
same hold (its own `_kq2` / `_klive2` / `_kcor2`), re-slotted among the worlds
by its own depth, and visibly another sun: its looks rolled apart from A's,
smaller, and warmer (`SunView.setup`'s `second`: the lighter star of a pair is
the cooler one, an orange K dwarf beside a yellow one).
```

Above `const STAR_B_PROM := 23.0`:

```text
how far star B's prominences run behind A's on the clock, so the two suns
are never at their height together (`prominence`: each erupts in a 40 s slot,
its start jittered over 14 s, for 19 s with 3 s at its height). They do
overlap at their edges: over four hours of the map's clock, star A erupting
47.5% of the time, both 8.1%, both above half strength 0.9%, both at their
height never (a model of `prominence` and `SkyBake.hash2`, Oct 31). Each
world's flare is its own sun's by its share of the light (`step`).
```

## Held sizes

Above `const HOLD_PX := 1.4`:

```text
SIZES HELD IN WHOLE BLOCKS (Jon: "why do the stars and planets kinda shimmer
when zooming in?"): redrawn at every fraction of a zoom, a world's surface and
the star's were resampled each frame and their blocks flickered (measured: 110
of every 1,000 of the star's pixels flipped back each frame of a slow zoom).
Each now grows a block of radius at a time, and holds it until the zoom has
moved HOLD_PX on -- the project's rule, whole-pixel steps with hysteresis.
```

## Smooth zoom

Above `var _live := {}`:

```text
THE SMOOTH ZOOM (Jon: "No matter the rendering style, it seems like the planets
resize and jitter as you zoom in"). While the zoom moves, each world is drawn at
its true radius and round its true centre, both continuous (`PlanetView.set_live`:
the box stays on the grid, the disc moves inside it), and so are the star, the
moons and the shadows; held sizes and the odd-size nudge made a slow zoom pop a
block of radius and shift a block now and then. Once the zoom has been still for
SETTLE_S, everything eases (SETTLE_EASE) back to the crisp held size on the grid.
Per world: [radius, centre].

THE EASE IS FOR THE SETTLE ALONE (Jon: "When moving the view left to right in
the sector view, the planets seem to lag behind"): it eased the centre toward
its place every frame, so a pan, which moves the place, left the picture
trailing its ring, label and beacons by ~2.4 frames of the pan. Now the live
centre is carried by however far its place on the grid moved (`_at_last`) --
the camera's pan and the world's own orbit -- and only what is left, the
settle onto the held size and the grid, is eased.
```

## Dust sheets

Inside `show_system()`, above `var blank := _wisps_blank()`:

```text
A WISP SHEET THAT DRAWS NOTHING IS NOT BUILT (`_wisps_blank`): in a clear
sky its colour is black, it adds nothing to any pixel, and three far and
four near full-screen passes of it were most of the dust's GPU time. Each
sheet still takes the seed it always had (`sk`, the count of sheets before
it as they were built: a skipped wisp still counts, a LOW one never did),
so the fluff's clouds stay where they were.
```

## Pulsar web

Inside `show_system()`, above `(star.get("_web_mat") as ShaderMaterial).set_shader_parameter("web_on", false)`:

```text
SIMPLIFIED: the remnant round it is the sky's own shell now, filaments and all
(C), so the old web of fine threads over it goes: its threads, a sixteenth
power of noise read at whole pixels of zoom 1, shimmered through every zoom
(half the pulsar's flicker on a slow zoom)
```

## Pulsar palette hold

Inside `show_system()`, above `var hold := layout.star == SystemLayout.StarKind.PULSAR and not ("palhold=0" in OS.get_cmdline_user_args())`:

```text
ROUND A PULSAR the colour is read whole and held (`map_palette`'s `fine` and
`hold_k`): its remnant shell grows with the map on every frame of a zoom, and
the one-level wobbles of the shell and the dust sheets over it flipped dither
pixels back and forth through every zoom (a slow zoom: 0.0042-0.0059 of the
map flipping back a frame against the 0.0035 budget; now 0.0008-0.0014).
The picture last frame, for the hold, is the place's own, copied each frame.
(a harness's `palhold=0`: neither, the pulsar's palette as it was, to measure against)
```

## Star B facts

Above `const STAR_B_FACTS := {"kind": "ORANGE DWARF", "cls": "K5", "temp": "4,400 K", "mass": "0.7 SOL", "radius": "0.7 SOL"}`:

```text
STAR B OF A PAIR, AS IT IS DRAWN (ruling 20): the lighter star, and the cooler,
an orange dwarf beside a yellow one (`SunView.WARM_B` and `GLOW_B`, the sky's
`STAR_B_COL`). Its class and surface are read off that colour: B's drawn light,
face and glow each against star A's, channel by channel in linear light, beside
a blackbody at each of K0 to K5 against one at G2's 5,770 K (Mamajek's dwarf
sequence), are all nearest K5 at 4,440 K (the best fits 4,290 to 4,450 K;
Nov 1). Its surface is rounded as G2's is to 5,700 K. It read YELLOW DWARF, G2,
5,700 K, star A's, under the orange sun the map draws.
ITS MASS AND RADIUS ARE A K5'S OWN, 0.7 SOL each, in every binary (Jon, Nov 1,
"starb:B"). They read its mass against A's as the stars' pulls are
(`star_share`: B / A = (1 - share) / share, 0.72 to 0.92 SOL) and its radius
the one it is drawn at against one sun's 16 px (0.77 to 0.94), where a real K5
weighs about 0.70; the pair then read 1.72 to 1.92 SOL while the map pulls as
one sun. The sheet he picked from showed 0.70 SOL; written 0.7 SOL, to one
place as the yellow dwarf's 1.0 SOL and the pulsar's 1.4 SOL are (Nov 1).
```

Above `static func star_facts_of(L: SystemLayout, kind_name: String, p: int) -> Dictionary:`:

```text
STAR p'S FACTS AS SHOWN, {kind, cls, temp, mass, radius}: its kind's
(`STAR_FACTS`), the same as ever with one sun. In a pair, star A is drawn as the
one sun is, so it reads as one does, a G2 of 1.0 SOL (it read its share of the
pair's pull, 0.52 to 0.58 SOL, which no G2 weighs). Star B is the K5 orange
dwarf it is drawn as, with a K5's own numbers (`STAR_B_FACTS`). Only the words:
the pull, the share and the drawing are as they were, so a flight feels star B
at 0.72 to 0.92 of star A's pull whatever its page says.
```

Above `func host_line(b: SystemLayout.Body) -> String:`:

```text
WHAT IT GOES AROUND, in a binary (ruling 20): its orbit in AU is about that
centre, so the panel says which. The stars are "<system> A" and "<system> B",
as the panel names them, and the pair BOTH STARS (it was BOTH SUNS beside
the page's BINARY: "Let's call it Binary instead of two suns", Nov 1; the
map's ORBITING words say the same, `SystemOverlay._settle_nm`). Empty with
one sun.
```

## Pulsar

Above `const PULSAR_OPEN_K := 4.0 / 3.0`:

```text
A PULSAR GROWS EXACTLY AS THE MAP DOES (Jon: "Pulsars still act REALLY weird
when zooming"): its cloud, beams, jets, spray, glow and web, all drawn by
`PulsarView` at one scale, are that scale times the map's zoom over the
zoom it opened at -- as its remnant shell in the sky already was
(`shell_k`). It was the sun's rule, the star's radius held in whole 2x2
blocks: for a 3 px star that is steps of a third, so the whole pulsar sat
still while the map zoomed and then jumped half as big again, and below
zoom 1 it did not shrink at all. At the opening zoom it is drawn as before.
```

Above `func _pulsar_at(o: Vector2, ez: float) -> Vector2:`:

```text
WHERE THE PULSAR IS DRAWN: on the block grid with its orbits at rest, and
while the zoom moves where the map truly puts it, as a world's picture is
(`_live`). Rounded to the grid as a wheel zoom carried it across the screen it
stood still and then hopped a whole block, x and y at different frames, ~8
times a second on a slow zoom, every layer of it -- core, beams, cloud, its
light and shell -- ahead of or behind the map by up to a pixel and back. The
block stays the box's place; the drawing is shifted within it (`sub`). Once
the zoom is still it is carried with its block and eased onto it.
```

## Twin sun floor

Above `func twin_floor_on() -> bool:`:

```text
THE TWIN SUN FLOOR (ruling 20's build, Oct 30). A twin's close rings and the
worlds round each star are fitted to its suns as drawn at `layout.fit_zoom`,
the zoom the system opens at with no job and no Hellbender out. A signed job
or the Hellbender out past its edge opens the map further out than that, and
the floor of screen radius (STAR_FLOOR, 10 px) then drew each sun wider on
the plane than the rings were fitted to: over 24 seeds' twins, with a fetch,
a hunt and the Hellbender all out, 184 star rings ran up to 2.5 plane px
inside their drawn suns and 550 worlds touched theirs (the layout's own
measure, Oct 30). So below `fit_zoom`, in a twin, a sun's drawn plane radius
never exceeds the one it has at `fit_zoom`: the floor shrinks with the zoom.
The zoom itself is not capped (the job's place must stay on screen). Its
true size (the corona's) at most `sun_raw_k` at the fit times zoom / fit; its
held disc at most the block it is held at there (the nearest), scaled the
same way and taken down to a whole block (`twin_held_cap`). One sun: never.
```

## Sky centre

Above `func sky_c() -> Vector2:`:

```text
WHERE THE SYSTEM SITS ON ITS SKY, in sky pixels at no pan: what the sky is
baked round once a system (`SkyBake.make`: the gas brightened near it, thinned
over the system, the dust's rims facing it; the cloud's field, its pillars
leaning in and its young cluster, `SkyBake.field`, `cc_em`). One sun: the
star, at the frame's centre, as it always was. Two suns: their balance point
where the opening zoom puts it (ruling 23): the pair turns, and the gas was
carved and is lit by both suns over thousands of turns, so what is baked
holds still round the point they circle, and only their light moves.
```

## Screen rounding

Above `func screen(x: float, z: float, dip: float = 0.0) -> Vector2:`:

```text
ROUNDED ONCE, by the caller: the exact pan plus the exact offset. Rounding the
star's pixel first and adding a fractional offset after rounded twice, and a
world the camera followed (LOCATION) shook by a pixel every few frames.
```

## Twin light

Above `func star_lum(p: int) -> float:`:

```text
TWO SUNS' LIGHT (ruling 20's build, Oct 30). Every world keeps ONE light, so
`planet.gdshader` and `planet_ring.gdshader` keep their interface (and the
planet shader its 13-16 s cold compile on the Mac): with two suns it is the
light of both made one -- its direction each star's, weighted by the light it
gives there, its strength their sum, its tint theirs by the same weights. A
world round one star of a pair takes 88 to 98% of its light from that star,
and its one light comes from within 6 degrees of it (the four systemtest
seeds' 213 twins as rolled, 426 such worlds, `-- sheet=TwinDrawTest`), so it
is lit from its own sun; a body round both is lit from between the two.
How bright star p is against a lone sun: by its drawn area, as
`SystemLayout.light_distance` weighs it (star A 1, star B (r_B / 16)^2).
```

## Radiant safety

Above `var _rprobe := {}`:

```text
RADIANT'S SAFETY, the sector's half of the chart's (`ChartSky._radiant_safety`,
the same budget, `ChartRadiant.budget_ms`, and the same fall-back): the place
picture's GPU time over its first seconds of drawing is averaged, and if this
machine cannot hold it every map drawn after this one is SIMPLIFIED (this one
keeps its look: a picture never changes under a still view), with one line in
the log. A harness's `style=radiant` is never overruled (it is measuring)
unless it asks with `radiantprobe=MS`.
```

Inside `_radiant_safety()`, above `ChartRadiant.fell_back = true`:

```text
FROM THE NEXT PICTURE, NOT THIS ONE (Jon: the picture holds its
brightness): it switched the style at once and the map, rebuilt under a
still view, dropped from RADIANT's lit gas to SIMPLIFIED's -- the whole
frame 16.9 -> 13.2 in a frame, settling at 14.6, three seconds in. The
map up keeps its look; the next system drawn, the chart's next build and
LOCAL's are SIMPLIFIED (`fell_back`, and the setting with it).
```

## Bubble gap

Above `static func bubble_gap(L: SystemLayout, want: float, centre := Vector2.ZERO) -> float:`:

```text
THE BUBBLE'S GAP IN A TWIN (ruling 20): the bubble is a sphere round
`centre` (on the map the balance point, `bubble_c`; in LOCAL the sun that
lights the ship's place, `LocalSky._lit`, at plane point `centre`), and a
body circling star B or the balance point sweeps a band of distances from
it, not one radius -- from |host - centre| - orbit to |host - centre| + orbit
(a belt 28 px wider each side). So the gap is looked for between those
bands, merged, never inside one. (The one-sun rule above, kept as it was,
treats each orbit as a point.)
```

## Pulsar beat

Above `func beat_follow(off: float, want: float, dt: float) -> float:`:

```text
THE BEAT FOLLOWS THE SOUND, SMOOTHLY (Jon: "the pulsar still slightly jitters
around when you zoom in"): the sound's clock as read each frame (the playback
position plus the time since the last mix) is right on average but wobbles by
a few ms from one frame to the next -- 3.4 ms sd, up to 13 ms, reversing 34
times a second, measured on this machine -- and set from it every frame the
beams, which turn once a second, lurched by up to 5 degrees a frame, a tip
270 px out shaking by 20 px, more the further in you zoom. Followed over half
a second the beat still sits on what is heard (the wobble averages out; the
two clocks run at one rate) and turns as evenly as the frames. A jump -- the
sound starting, a loop, the system changing -- is taken at once.
```

## Twin silhouettes

Inside `_step_twin_sky()`, above `var mp: ShaderMaterial = _pt.get("paint")`:

```text
AND ITS SILHOUETTES FACE BOTH SUNS (`sector_b_paint`): star B where it
truly is, as the cloud's light has it (star A's likewise, as
`SectorPainted.push` gives it: the pair turns, and a rounded place stepped
the rims at every block hop), as bright as the cloud has it
(`star2_light_k`) and the light reaching as far as on the cloud
(`sky_nebula`'s lzoom, home_zoom and lscale), so the rims are on the side
the cloud is lit from. They faced star A alone.
```

## Cloud light

Inside `step()`, above `_neb_mat.set_shader_parameter("star_at", star_exact(-1))`:

```text
THE SUN THAT LIGHTS IT, this frame: where, how far zoomed from the
opening, the frame against the showcase's, its breath
(the light from where the star truly is, not its pixel: rounded, it jumped
a block every few frames of a zoom held on a world while the light opened
out smoothly, and the lit gas flickered at every jump)
(two suns: star A's exact place where the pair has it now; the bubble and
RADIANT's zones round the balance point, `bubble_exact`, which holds still
as the suns circle it -- one sun, both are star A's exact place)
```

## Palette cut

Above `func pal_from(img: Image) -> PackedVector3Array:`:

```text
THE PALETTE CUT FROM THE PICTURE `img` (the place's half-size picture): the
system's own colours (`SystemPalette.build`) with the steps `pal_extra` keeps
for it. With two suns, star B's light too: a cut round its disc and its glow's
dark end in its own warmer hue (`pal_star2`), put in after star A's and only
as many of them as fit the pass's 72 (`SystemPalette.build`'s `star2_*`). A
one-sun system's call is the one it always was, argument for argument
(`-- sheet=TwinPalProof`, a scratch harness: every one-sun system's palette
over the four systemtest seeds the same as main's, from the same picture).
```

## Palette cache

Above `static var _pal_cache := {}`:

```text
THE PALETTE CUT ONCE A SYSTEM (the Mac's map, Oct 27: every visit read the
picture back from the GPU and ran the median cut in GDScript, a tenth of a
second or more on the main thread as the map opened). Memory only, for this
session: the palette `step` cut for a system, by everything that changes the
picture it is cut from -- the system itself (the MapNode, so a new or loaded
run never meets another's), its bodies, the style, GRAPHICS LOW, the field
under it, the frame and the opening zoom, and a harness's switches. Every
visit opens the system on its clock's zero, unpanned, at its opening zoom, so
the picture a revisit would cut from is the one its first visit cut from; only
the gas's wall clock and the frame the bake ends on can move it, by a frame
or so, and a revisit now keeps the first visit's steps instead of a recut a
step apart (`-- sheet=MapPerfTest palcache` measures both). `-- palcache=0`
(and `pal_cache_on`): every visit cuts, as before.
```

## Supernova

Above `class _Nova extends Node2D:`:

```text
A DISTANT SUPERNOVA (Jon: "these stars in the sector view are weird. can we
have them be the distant supernovas maybe? Like have them flash in briefly and
then disappear. it can be a rare event"). Once a minute to three, at random
(its own generator, seeded from the system and the clock, so it keeps time
with nothing), a point in the far sky brightens over 0.3 s into a bright star
with four spikes, holds a second, and fades over four, a faint tinted glow
left behind it a little longer. It slides with the far sky, under the gas, the
star and the worlds, in 2x2 blocks the palette pass maps like the rest, and
never comes up where a disc is. Silent.
```

## Belt performance

Inside `_pal_key()`, above `func _rocks() -> void:`:

```text
THE SAME ROCKS FOR LESS (the Mac's map, Oct 27): up to 1,200 rocks a belt
a frame, each with seven calls on the generator, two on an untyped view and
the star's tone that only LEGACY read. Now its draws come from the table
(`_rock_draws`), its place is worked out in place (as `screen` and `block`
work it, to the bit), a rock whose drawing (a glint's arms reach 4 px left
and 6 right, a big rock 2 up) falls wholly off the place's 960 x 540 is not
drawn. (The tone was worked out for LEGACY alone, gone Nov 7.)
```

## Belt glints

Inside `_pal_key()`, above `const GLINT_UP := 0.2`:

```text
GLINTS (Jon kept them, Oct 11): SUNLIGHT CATCHING A TUMBLING ROCK. Each of a
belt's first 300 rocks (the ones always there, so a closer look only
magnifies how many glint in a patch) flashes now and then as a flat face
turns to the sun: up over a fifth of a second, gone over most of a second, a
short bar of light along the row at its height -- never a cross, which read
as one more star. Brighter where the belt is seen lit full (`phase`). About
one rock in thirty is glinting at any moment; none round a pulsar, whose
beam already lights the rubble. In each style's own hand (`_glint`).
```

Inside `_pal_key()`, above `func _glint(s: Vector2, e0: float, phase: float, sc3: Vector3, rk: Array = []) -> void:`:

```text
The glint drawn over the rock at `s`, in 2x2 blocks:
  SIMPLIFIED: gathered light, eased, the star's white, the palette pass
    setting its steps;
  RADIANT: the same light through A's own exposure (`_Moons._tone`), so its
    core rolls off soft instead of clipping;
  PAINTED: B's hand -- held poses (8 a second) in the rock's own ramp `rk`
    (its core that ramp's top most of the way to white), three drawings from
    a lit speck to a bar with its tips, never a fade.
```

## Fabric and orbits

Above `class _Lines extends Node2D:`:

```text
THE FABRIC OF SPACE, faint and grey (Jon: "more smooth looking, more simple,
gray, and understated"): one grid across the system, turned 45 degrees so
none of its lines runs straight away from the eye (those read as vertical
lines), sinking into a funnel under the star -- softly capped, so the black
hole's does not swallow the view -- and a dent under each body. Its lines are
worked out ten times a second (the bodies move slowly) and drawn every frame.
THE ORBITS: faint grey rings, a soft lighter trail behind each body.
```

## Orbit culling

Inside `_pal_key()`, above `func orbit_runs(cull := true) -> Array:`:

```text
EVERY ORBIT'S LINE as drawn this frame, in drawing order: [[points, colours],
...], one entry for each unbroken stretch of a ring.

THE SAME LINES FOR LESS (the Mac's map, Oct 27): every ring was worked out a
point a pixel and a bit all the way round, up to 3,000 points, zoomed in
where most of it is off the frame -- each point through two calls on an
untyped view. Now the camera's values are read once, the point is worked
out in place (as `screen` and `orbit_point` work it, to the bit), and
SPAN points at a time are skipped whole when none of them can be in the
frame: a ring's point moves at most `orbit * zoom` px a radian on screen, so
nothing between two points is further from the nearer of them than that
times half the angle between; a stretch whose two ends, grown by that and 2
px more, miss the frame has no point in it (`cull` false works every point,
for `-- sheet=MapPerfTest` to hold the two to the same lines).
```

## Twin orbit holes

Inside `_pal_key()`, above `var d2: float = view.star_depth(SystemLayout.STAR_B)`:

```text
A STAR'S HOLE ONLY BEHIND IT, in a twin (the lines are drawn over the whole
picture, so the hole is all that hides them): a world round one star of a
pair passes in front of its sun at the near point of its circle, drawn
over it there (`step`'s depth order), and its ring's near half with it.
Cut wherever it crossed the disc, 26% of the near half of every such
ring was missing at the opening zoom, up to 38% (the four systemtest
seeds under twin=all, 1,710 worlds, review Oct 31). With one star the
hole cuts wherever a ring crosses it, as it always did (a sun's first
orbit is at least 243 px out, its near point 92 x zoom px below the star
against a hole of 16 x zoom + 2, so no ring's near half comes near it).
```

## Fabric

Above `class _Fabric extends Node2D:`:

```text
THE FABRIC OF SPACE, faint and grey (Jon: "more smooth looking, more simple,
gray, and understated"): one grid across the system, turned 45 degrees so no
line runs straight away from the eye, sinking into a funnel under the star
and a dent under each body. Laid out once as a mesh of short lines on the
plane, finer as the zoom doubles; `map_fabric.gdshader` sinks, places and
fades every point each frame, so moving the camera costs the CPU nothing.
```

## Fabric grids

Inside `_pal_key()`, above `static var _meshes := {}`:

```text
THE GRIDS, KEPT FOR EVERY MAP, laid out off the main thread (Jon on 2C:
"still has a small delay/hitch"). The finest grid is a quarter of a
million short lines; laid out on the spot, the frame the zoom first
crossed into it took 78 ms -- the map's first deep frame on the way out
of LOCAL every time (each map is new), and once mid-dive on the way in.
A grid depends only on its spacing and how far out it reaches, so it is
kept for the session, by level and reach (rounded up: past the edge the
shader fades it to nothing, so a larger one draws the same), and every
level of a new map's reach is started on worker threads the moment the
map is laid out (`warm`), long before the camera gets there.
```

## Fabric lines

Inside `_pal_key()`, above `var verts := PackedVector2Array()`:

```text
EACH SHORT LINE A THIN QUAD, its coverage worked out across it (Jon:
"lines being drawn weird"): drawn as one-pixel lines, a slow zoom slid
every segment by a sliver and its pixels hopped to the next row and back
-- the grid crawled, most where it is packed tight. Now each segment is
two pixels wide with a tent of coverage across it: on a pixel's middle it
is that one crisp pixel, between two it is half of each, and as it slides
the pixels fade over instead of hopping. Each corner carries its own
point (VERTEX), its partner's (UV), which side it is on, whether its line
is an odd one of its grid (the coarser level has only the even ones; the
odd fade in toward the next level) and whether it is the segment's start.
```

## Grid workers

Inside `_pal_key()`, above `func _exit_tree() -> void:`:

```text
NO GRID IS LEFT ON A WORKER when a map goes, and quitting is why: a task
nobody waits for hangs the process at exit (stowtest, killed by the gate's
watchdog on every push from 37811eb on). Each job is waited for and kept,
its id set to -1 so `_mesh` and `collect` take its points without waiting
twice.
```

## Giant wells

Inside `_pal_key()`, above `static func giant_well_w(b: SystemLayout.Body) -> float:`:

```text
A HEAVY GIANT'S WELL IS WIDER (ruling 20: giants 1/10 to 1/4 of their star,
"purely because it's more fun", felt by every autopilot flight): its width
grown with its weight, depth kept (the tanh cap at 45 swallows a deeper
well, so a deeper one barely shows). The lightest giant keeps today's
34 px -- before the ruling a giant pulled nothing and was drawn at 34, and
every giant now weighs more, so none is drawn lighter -- and the heaviest,
a quarter of its star, is 45 px: the width whose far reach (depth x
width^2, the shader's sum far out) is a quarter of an ORDINARY star's at
the giant's depth (21.6 x 44.6^2 is about 172,171 / 4). Between, by its
weight. Anything else, and a giant with no weight, as laid out.
```

## Moons

Above `class _Moons extends Node2D:`:

```text
A WORLD'S MOONS, over the picture at full size like the orbit lines (Jon:
"still weird rings on this giant"): each a small round dot lit on the star's
side, its orbit a faint line of single pixels at the map's own slant -- drawn
only for a world pointed at, selected or circled, and never across the
world's disc. A moon behind the world is hidden by it; one in front passes
over it. The orbits spread with the world's size, so they never bunch.
```

## Twin moons

Inside `_pal_key()`, above `func behind_star(i: int, s: Vector2, o: Vector2, hole: Vector2, o2: Vector2, hole2: Vector2) -> bool:`:

```text
A WORLD BEHIND A STAR, its moons with it: its centre `s` inside the star's
hole on screen (star A's at `o`, star B's at `o2`, `hole2` zero with one
sun; star A where the pair has it, ruling 23). In a twin, only while the
world is farther from you than that star (its own depth, which turns):
in front of it, at the near point of its circle, the world is drawn over
the sun and so are its moons (cut by the screen alone, a world round one
star of a pair lost its moons for 23% of its time in front of its sun, up
to 36%: the four systemtest seeds under twin=all, 573 worlds with moons,
review Oct 31). With one star the screen test stands as it was (no sun's
world in front comes near its hole: `_Lines.orbit_runs`).
```

## Moon orbits

Inside `_pal_key()`, above `func ring_slots(i: int, b: SystemLayout.Body, r: float, moons: int) -> Array:`:

```text
THE MOONS OF A RINGED WORLD SIT IN ITS GAPS (Jon: "The orbits of the moons
on a ringed planet don't follow the gaps in the rings"), as shepherd moons
do, or out past the outer edge -- never across a band. Read from the same
strip the painted rings draw from (`Rings.build`, at the size the world is
drawn), in world radii; the widest gaps first, then outside it all. Empty
for a world without painted rings.
```
