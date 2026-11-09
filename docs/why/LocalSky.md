The reasoning behind `tkg/scripts/ui/LocalSky.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Sky design

Above `const SkyBakeS := preload("res://scripts/ui/sysmap/SkyBake.gd")`:

```text
LOCAL'S SKY: what is out there behind the fight, the jump and the approach,
in the rendering style Jon picked (`DisplaySettings.render_style`) -- the
SAME system the sector map draws, seen side on.

THE SECTOR MAP looks down on the system's plane at a slant (`SystemView`,
TILT 0.38); LOCAL is the same system from nearly in that plane, the camera a
little above it: the plane is a thin band across the top of the view, the
system's own star on it (its kind, its colour, breathing, now and then a
prominence; the pulsar and its beams; the core's black hole, the one every
style shares, `CoreLegacy` on `legacy_hole.gdshaderinc`), its own worlds
along it where their orbits have them (`PlanetView`, the map's painter, the
same worlds), and behind it all the nebula the system sits in, as the map's
sky draws it from inside (`sky_nebula.gdshader`, the same kind, shape,
colours and seed, its gas streaming on its currents and lit by that star),
and behind that the far sky every chart style keeps -- distant galaxies and
three depths of stars (`local_far.gdshader` on `chart_bg.gdshaderinc`).

THE STYLES, as the map draws them:
  * SIMPLIFIED: the cloud lit by the sun, set to the system's own short
    palette (`map_palette`, found from its first picture) in 2x2 blocks;
  * PAINTED: the far picture painted on B's curated ramps with its band
    memory (`SectorPainted`), the sun and the worlds painting themselves, the
    life of it in held poses;
  * RADIANT: the cloud as a volume the sun shines through, the worlds'
    shadows as shafts in the lit gas.
  (LEGACY, LOCAL as it was before the port, went with that style on Nov 7.)

WHERE THE SHIP IS (Jon: "have LOCAL change depending on what you are orbiting
and how far from the star you are"), read from the sector map's own record of
it (`SystemMapScreen._parked`: what it is in orbit of, where it is on the
plane), or, with none, at the edge where a ship warps in:
  * ORBITING A WORLD: that world close and huge, rising from below behind the
    fight, its rings across it and its moons above, lit from the star; the
    star smaller beyond, at the world's own distance (how big: `near_size`);
  * ORBITING THE STAR: the star large and blazing, cut by the top of the
    view, the worlds small along the band;
  * HOW FAR OUT: the star's size, and how far its light reaches into the gas,
    go with its nearness -- big and blazing close in, a small bright point at
    the edge -- and so do the hole's and the pulsar's;
  * ALONGSIDE A BELT OR A WRECK: its rocks, or the hulk and its shards, close by.
The near things are drawn in a picture of their own (`local_near`), in front
of the band: solid bodies, their light pressed as the gas's is, their dark
never lifted.

THE CAMERA moves when the ship leaves: it follows the hull's departure a
little over half way (`CAM_FOLLOW`; never its arrival, `_follow`), and every
layer slides by its own depth -- the far stars and galaxies least, the system's star all but
still, then the cloud, the band's worlds, and the world it orbits most -- in
whole 2x2 blocks. Otherwise it holds still: the motion is the gas, the
star and the weather.

READABILITY FIRST. The fight is played across the middle of the view, so the
sky there is made a soft backdrop -- its range pressed in toward a mid-tone,
its light and colour kept (`local_grade.gdshader`, PLAY), whatever the
system -- and nothing is drawn behind the ships or their words (shadows
round them were tried: Jon, "they're odd", "the text doesn't need a
shadow"); the bright things -- the star, the hole, the lit heart of the
cloud -- sit in the band above it.
The weather is the map's own events, rarer (`WX_SLOW`), placed above the
fight and never one that flashes; none at all with reduced motion.

Cheap: one 480x270 picture of 2x2 blocks for the whole screen (the view is
a window onto it, so the map's shaders work in their own 960x540 frame),
its cloud baked once a system (`SkyBake.field`, kept for the next visit).
```

## Core hole

Above `static var core_look := &"a"`:

```text
THE CORE'S HOLE IS THE BACKDROP (Jon, Oct 13: "shouldn't the black hole be
bigger in the background though?", then "can this be more large and
centered in the middle back? i'm just worried that the custodian is going to
sit right on the black hole and be weird"). At the core the system's star --
the shared hole (`CoreLegacy`, its photon table traced once a process) --
is drawn big behind everything, in the scene with the cloud so its lens
bends it, on the far star's depth (all but still as the camera moves). Where
and how big is `core_look`, Jon's pick "a" (Oct 13; `CORE_LOOKS`: its
centre in the game frame and its disc's outer edge in px):
  a  centred, large: the middle of the play, the edge 250 px out;
  b  centred, huge: the edge 330 px out, its glow off the play's top and
     bottom, the shadow whole;
  c  centred, set back high: as a, raised so the shadow is in the upper
     middle and the ships stand on its lower glow.
Measured in the Custodian's fight (`-- sheet=CoreFightFilm`): its picture
stands on the black in none of them (tetra 0 px in each; take 1, laid on
the same place, 0 / 698 / 52 px, 0 / 3.4 / 0.3 %) -- the shadow is between
the two ships, the Custodian on the disc's right glow.
There is no hole on the band and no world drawn near at the core.
```

## Two suns

Above `const FAR_MOST := 0.75`:

```text
TWO SUNS ON THE BAND, A CLOSE PAIR'S TOO (Jon, Nov 1, "Binary kinds:
close:B"). A close pair's suns are 150 to 170 px apart, so from either sun's
close orbit both are near and held at or close to SIZE_HI, and laid out by
their places alone the two discs ran into each other on the band (by up to 7
px, TwinDrawTest, 10 of 73 close pairs) and the far sun came out bigger than
the near one (1). So the far sun is drawn at most FAR_MOST of the near one's
size, and star B stands at least SUNS_APART px clear of star A, out along the
way its place puts it (the block grid can take a px of it back). A CLOSE
PAIR'S ALONE: a wide pair's band is drawn as it was before the ruling. Held
to it too, the cap redrew a wide pair's far sun at 654 of 1,008 places
round both suns (seeds 7, 4242 and 1999), to 0.73 to 1.0 of its size; its
suns are 46 px or more apart there and never meet.
```

Above `var star2: Node2D = null`:

```text
TWO SUNS (ruling 20, Oct 30). `star2`: star B's SunView on the band beside
star A, null with one sun -- placed where the band puts its place on the
plane, each sun sized by the ship's own distance from it (`_dk_a`, `_dk_b`),
so the far one is the smaller. `_lit`: the sun that lights where the ship is
(-1 star A, STAR_B star B), the one giving it more light (`SystemView.share_b`);
`origin`, `star_light`, `star_px` and `star_k` are its, and so is everything
that asks them -- the far glow, the cloud's light, the near world's light, the
dust (`LocalDust`), the subjects (`LocalSubject`) and the life (`LocalLife`).
Star A keeps the band: it is laid out round A's place (`_sun`), as always.
```

Inside `_bubble_r()`, above `return SystemViewS.bubble_gap(layout, want, layout.star_pos(_lit, 0.0)) * _s`:

```text
(two suns: the bubble is round the cloud's sun here, the one that lights
the ship's place (`_lit`, the neb's `star_at`), so its gap is between the
bands of distance from that sun each body sweeps, `SystemView.bubble_gap`;
measured from star A while drawn round B, its wall could run through
the band's worlds)
(at t 0, as `bubble_gap` measures the bodies: the pair turns rigidly)
```

Above `func _sun_at(p: int) -> Vector2:`:

```text
Where star p hangs on the band at rest: star A at `_sun`, star B where the
band puts its place on the plane from star A, as the pair was left (`_tm`:
across by its x, a little lower the nearer it is, at the band's scale), on
the block grid -- on the side the map shows it, held for the visit. A close
pair's out that way to SUNS_APART clear of star A's disc while the pair lies
as a layout lays one (within TWIN_TURN of level); turned on toward end on
(stacked:A, Jon, Nov 1), less and less, till end on the suns stand where the
band has them, one in front of the other, the nearer drawn over the farther
(`_step_worlds`).
```

Inside `_situate()`, above `var d_b := maxf(p.distance_to(_star_rel(SystemLayout.STAR_B)), float(layout.star2_r) + 20.0)`:

```text
EACH SUN BY ITS OWN DISTANCE (ruling 20): a world round star B is some
350 px from star A but 65 to 100 from its own sun, which lights it and is
drawn the bigger; `orbit_d` is the distance from the sun that lights the
ship's place (`_lit`, the one giving it more light). Each distance as the
pair was left (star A at zero here), and `_lit` chosen once, here, for
the visit: the cloud's sun never swaps under a held view.
```

## Near world

Above `static var near_size := &"large"`:

```text
THE WORLD IT ORBITS, CLOSE (Jon, Oct 21: "I want the planet you are orbiting
to be large in the background (you are close to it)"). Its radius on screen
(a giant's, a planet's, before its own size nudges it, x0.8 to x1.25 by the
body's map radius) and where its middle sits under the band (y0 + dy * R),
by look -- `near_size`, one line to switch:
  before  as it was to Oct 21: a planet 100 px, a giant 140-148, its middle
          at y 360, wholly inside the view (6% / 13% of the frame);
  medium  a planet 160, a giant ~210, its lower limb at the bottom bar;
  large   a planet 220, a giant ~280, its lower limb off the bottom: close;
  huge    a planet 300, a giant ~380, a wall of it, off the bottom and a side.
Each is the world's own painter drawing it at that radius on the 2x2 block
grid (never a picture scaled), lit from the star, behind your ship.
```

Above `static func near_lead() -> int:`:

```text
THE WORLD YOU ORBIT, SLID ALONG AS YOUR SHIP LEAVES: the camera follows the
ship out (`CAM_FOLLOW` of its travel, at most the view's width and
`ShipView.DEPART_OVER` past it) and the world slides `F_NEAR` of that to the
left, bringing in what lay past the picture's right edge. In its 2 px blocks,
how far past that edge its surface's memory is worked out all along
(`PlanetView.mem_clip_lead`), so what comes in was never left out.
```

## Camera layers

Above `const SKY_K := 0.06`:

```text
THE LAYERS BY DISTANCE (Jon: "the sun moves a ton in the parallax ...
shouldn't it be more still since it's so distant?"): the far sky least -- its
galaxies and three depths of stars at SKY_K of `chart_bg`'s own depths, all
under 0.012 of the camera's travel -- then the system's star (the black hole,
the pulsar) all but still, then the cloud, the band's worlds, and the world
the ship orbits most of all. Each in whole 2x2 blocks; the camera eases in
and out, so a step never goes back.
```

## Pair clock

Above `var _tm := 0.0`:

```text
THE PAIR AS THE MAP LEFT IT (ruling 23, Jon, Nov 1: "Orbiting pair"): a
binary's suns turn round their balance point on the map's clock, and map
time does not run off the map, so LOCAL holds the pair still for the visit
at the system's kept map clock (`Run.map_t`, the party's in co-op:
`NetSession.adopt_clock`), and the map opens on that very angle again. `_tm`
is that clock; `_a0` star A's place on the plane then, which the band is
laid round (every plane point LOCAL draws is taken from it, `_rel`); `_turn`
how far the pair has turned from the way it was laid out (0 alone or held
still, where all of this is exactly what it was). Read once, in `_build`.
```

Above `func _hold_pair() -> void:`:

```text
Takes the system's kept map clock and holds the pair there for the visit
(`_tm`, `_a0`, `_turn`). Handed the pair by its map (`Router.pair_handed`:
the zoom down, GO, Tab), the very clock that map kept, so the pair stands
where it stood. For the system the ship is in opened any other way (a
fight's end, the dock), the party's: a partner's map further on is taken,
as the map takes it (`NetSession.adopt_clock`). Another system's sky (a
field under the chart) reads its clock as kept.
```

Above `func _laid(q: Vector2) -> Vector2:`:

```text
A band point (from star A) turned back to the pair as it was laid out (star
A at the origin, star B at `star2_at0`), where the map's static light
helpers measure the two suns from (`SystemView.share_b_of`, `light_here_of`,
`toward_light_of`). The pair turns rigidly, so each sun's distance -- all the
light's share and strength ask -- is the same either way; a way to the light
is turned on again by `_turn`.
```

## Cutaway zoom

Above `var zoom := 1.0`:

```text
THE CUTAWAY'S ZOOM (`CutawayView`, Jon: "LOCAL should zoom the real scene
too"): the camera pushed in `zoom` times on the point `_zoom_fixed` (this
view's px), which it carries to `_zoom_to`. Each layer goes by its depth --
the world you orbit all the way with the ship, the band's worlds a little,
the star all but still; the far stars and the cloud are drawn on the screen's
own grid and hold. 1 is no zoom, which is all play outside the cutaway sees.
```

## First frame

Inside `_build()`, above `_box.modulate.a = 0.0`:

```text
THE FIRST FRAME ANYBODY SEES IS THE FINISHED ONE (Jon, of the arrival:
frames 0-2 smooth and unpaletted, then the cut; then of a hold that
showed the dark wash first, "the black starfield AND THEN the nebula loads
in looks bad"; and every later rebuild -- a new screen over the same
system, a style or LOW change -- blinked the same way). So the sky is
finished before it is shown: held clear while `_prime` drives the cloud's
bake and the palette's cut through forced, unpresented draws, in this
same frame, then shown. The palette is kept per system and style
(`_pal_cache`), so a system already seen this session is cut once.
```

Inside `_prime()`, above `if _bake_on_real:`:

```text
(the cloud's bake waits on real frames now, and the palette is cut from
the cloud: forcing more draws only made the open hitch, 48 of them,
~200 ms, for nothing)
```

Above `const FADE_IN := 0.25`:

```text
THE SKY SHOWN ONLY WHOLE (Jon: a pop is a failure). LOCAL opened straight --
not through the map's zoom, which builds it ahead -- showed its first eight
or so frames with no cloud and then the cloud arrived (the whole frame 24 to
47): the cloud's bake cannot finish inside `_prime`'s forced draws (they read
its pictures back empty; it bakes again on the next real frames), and the
prime ended by showing the sky whatever it held. Now the sky stays clear
until the cloud is in and the palette cut, then comes up whole: at once if
nobody has seen a frame of it yet, else eased in over FADE_IN seconds, so the
held frames end in a fade rather than a jump.
```

## Empty bake

Inside `_bake_cloud()`, above `for attempt in 4:`:

```text
BAKED UNTIL IT HOLDS GAS (PAINTED's LOCAL showed bare stars on every
arrival: built PAINTED, the bake ran inside the sky's priming draws and
read its three pictures back empty -- no cloud, and no sheets for its
masses). An empty bake is done again on the next real frames.
```

Inside `_bake_cloud()`, above `for attempt in 4:`:

```text
(THE SHEETS CAME OUT EMPTY on LOCAL, every time: baked inside the sky's
priming draws, the bake's picture was read back blank, and PAINTED's
LOCAL had no cloud at all -- emission, reflection and the core showed
bare stars. Baked again on the next real frames until it holds gas.)
```

## Star on screen

Above `func origin() -> Vector2:`:

```text
THE STAR ON SCREEN this frame, on the block grid (its own, near-still layer),
and under the cutaway's zoom where its depth (Z_STAR) carries it. Everything
that belongs to the star asks this one point: its disc, the far sky's glow,
its light on the cloud (and PAINTED's), the worlds' shafts and shadows, the
near world's light, the dust (`LocalDust`) and the subjects (`LocalSubject`).
Jon: "When zooming into the ship, the light of the star moves?" -- the disc
sat inside the band's layer and took its zoom on top of its own, while the
glow held still, so the two came apart.
```

## Camera

Above `func _follow() -> void:`:

```text
THE CAMERA follows the ship's own travel as it leaves (`CAM_FOLLOW` of it),
and holds still while it arrives (Jon, Oct 21, for 0.3.0, as docking has
since Oct 20: "The dust move too much"): an arrival takes the hull off the
view's left edge and flies it back to its mooring, and following that moved
the dust about 209 px on its first frame and slid it back over the approach.
Held where it was instead, so the sky and the dust keep their own drift and
the ship alone moves; at rest the hull is at its mooring (`position` 0), so
the camera the arrival hands back is the one it held. `cam_hold` (the dock)
over both.
```

## Zoom redraw

Inside `_step()`, above `_zlayer(_worlds, 0.0)`:

```text
UNDER THE ZOOM NOTHING HERE IS A PICTURE SCALED UP (Jon: "zooming in causes
artifacts like pixels missing, lines being drawn weird"): the band's worlds,
the star and the near things are each drawn again where the zoom puts them
and at the size it gives them, on the sky's own 2 px grid -- so a push-in
only ever adds detail. (Their layers were scaled as pictures: the band's by
1.15 drew every seventh block twice, the near world's by 2 drew it in 4 px
blocks, and the zoom ladder's pull back to 0.3 dropped most of its pixels.)
```

## Band order

Above `static func band_order(d2: float, ys: Array, with_a := true, with_b := true) -> Array:`:

```text
THE BAND'S DRAWING ORDER, farthest first: the worlds at depths `ys` (sorted,
nearest last; the band is from star A, so A is at 0) with star A among them
(`with_a`) and star B at its depth `d2` (`with_b`, `suns_depth`). Each entry
is an index into `ys`, -1 for star A or `SystemLayout.STAR_B`. The nearer
sun goes in after the farther, so a pair turned end on draws its near sun
over the far (stacked:A). Pure, so a headless test can see it: LOCAL's suns
are not built headless, and a flipped order passed every sheet (review 2).
```

## Palette

Above `func _build_palette() -> void:`:

```text
The palette from the system's own first picture (`SystemView`'s, with the
same reserved steps), once the cloud is in.

FOUND FROM THE SKY AT REST (Jon, of an arrival: "the nebula on the left are more
backlit by the sun than the ones on the right" -- one arrival's sky set flatter
than another's): a palette cut from a frame early in the approach, with the
camera still out where the ship flies in from, was a palette of that frame --
other gas, the star elsewhere on it -- and the lit rims and the glow's reach
at rest fell between its colours (and a palette cut a second later was cut
from other gas). So for the two frames it takes, the sky is laid out at rest
and at its clock's start, behind a still of what was on screen, and the
palette is cut from that: the same palette however and whenever the ship
arrives.
```

## Zoom ladder

Above `var _hand := {}`:

```text
THE MAP'S OWN WORLD, HANDED OVER (`ZoomLadder`, 2C; Jon: "it's SO CLOSE, but i
want it pixel perfect"). The sector map's picture of the world you orbit -- the
very node, its surface's memory and all -- is taken into this sky's near
picture in place of the one this sky built, at the map's size, place, light,
time and tone, and eased from there to this sky's own; at the end it IS the
near world. So the world never changes identity: the frame the map drew is the
frame drawn here. {view, own, from (the map's shader values), light, world,
seed, held, at (this sky's px), r, mix (0 the map's look, 1 this sky's)}.
```

Above `func hand_own(at: Vector2) -> bool:`:

```text
THE WORLD YOU ORBIT, CARRIED OUT IN ITS OWN PICTURE (2C, LOCAL to the map;
Jon: "a small jitter of the planet"): the near world itself moved as
`adopt_near` moves the map's in -- drawn again at every size, its picture
slid by fractions of a pixel -- instead of shrunk as a picture on the 2 px
grid, which wobbled it a pixel back and forth. `near_hand` drives it the
same way, played the other way round; `end_hand` puts it back.
```
