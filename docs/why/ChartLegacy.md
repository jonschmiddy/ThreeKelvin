The reasoning behind `tkg/scripts/ui/ChartLegacy.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Legacy chart sky

Above `const BAKE := Vector2i(896, 616)`:

```text
THE STAR CHART'S SKY IN THE LEGACY STYLE (`DisplaySettings.render_style`
`&"legacy"`, or a harness's `style=legacy`): the chart as it was before the
Oct 5 port -- Jon's picks of the mockup ("sector style, a LOT", round three,
2x2 blocks, at the sector map's angle): depth look 3 at 0.9, the disc as a
volume (3) of dense puffy gas (3) that billows, the named clouds remade (look
4), sparse stars (level 4) -- with SIMPLIFIED's black hole (`legacy_hole`,
Jon: "I want this no matter what style we pick") and its animations fitted
to the old look: the arms' gas streaming through them, knots that breathe and
now and then bloom, a rare supernova and its light echo, lightning in the
emission and dark clouds, glimmers round a remnant's shell, shafts round a
reflection cloud's lamp, a pulsar's beat. `ChartSky` hands the chart to this
node when the style is LEGACY and draws nothing itself.

TWO HALVES, as before.
  * ONCE A GALAXY, on the GPU, a BAKE (`_begin_bake` and the stages after
    it): the chart's own star field (`MapChart._build_stars`) re-tilted to
    the sector map's angle, added up and blurred into the galaxy's standing
    fields -- its stars' light, its arms, its dark clouds, its gas -- in the
    mockup's own pixels (the chart's opening view), and a short palette for
    each zoom (`_make_palette`), from the galaxy's own colours. Three frames,
    then read back into textures and kept for the run (`_baked`).
  * EVERY FRAME, a half-size viewport (`_vp`) the chart shows at twice its
    size, so each of its pixels is one 2x2 block: the field
    (`chart_l_field`, every block worked out afresh, so the zoom redraws and
    the galaxy turns with nothing stretched or rebuilt), the bright stars
    (`chart_l_stars`), the hole and its lens (`chart_l_hole`, SIMPLIFIED's),
    then the palette (`chart_l_palette`).

THE TURN. The galaxy turns as one, once every `ChartSky.TURN_MINUTES`
(`MapChart.turn`), a view-only angle from the chart's clock.
```

## Galaxy turn speed

Above `const TURN_MINUTES := 720.0`:

```text
One turn of the whole galaxy, in minutes: twelve hours, so at a glance it
does not seem to move at all. The mockup's dial said half an hour, which
read as "like 5x too fast"; two and a half hours was "still rotating too
fast" -- and what was moving then was mostly not the disc but the climb
round the hole (see `params`, `rb`) and the gas's brightness waves.
```

## Look settings

Above `static var nebula_look := 4`:

```text
HOW THE NAMED CLOUDS ARE DRAWN: 4, each kind remade for the gas volume
(`chart_field`'s `neb_v2`; Jon, 2026-10-04: "These are nice"). The others,
for comparison with `-- sheet=ChartLook neblook=N`: 1 "of the galaxy" (his
pick of 2026-10-03), 0 each kind's shape with an edge and a moat ("look
bad"), 2 "pixel-art objects", 3 "quiet until wanted".
```

Above `static var star_level := 4`:

```text
(4: the clouds remade for the new chart, while Jon picks -- vivid, each
kind as the thing itself, rising and churning with the gas.
`-- sheet=ChartLook neblook=4`.)
```

Above `static var star_level := 4`:

```text
HOW MANY STARS ("I honestly feel like there might be too many stars?"):
4, about an eighth of what shipped -- level 3 was still "about 2x too
high", Jon -- with true white kept for the few brightest; 3 about a
quarter, his first pick ("stars as accents, so the gas and dust carry the
galaxy"); 2 about half; 1 as it first shipped, kept so the others can
still be photographed. Thinned by brightness, never at random: the
galaxy's own stars keep their brightest (and every globular cluster), the
extra stars deep in lose their dim half first, the sky behind its dimmest
colours first. `-- sheet=ChartLook starlevel=N`.
```

Above `static var depth_look := 3`:

```text
DEPTH ("I almost want the sectors and galaxies to look fluffy and deep",
`chart_field`'s `depth_look`): 3, Jon's pick, both -- the layers you pass
through and the fluffy lit cloud -- as strong as `depth_amt`; 0 as it was;
1 the layers alone; 2 the cloud alone. `-- sheet=ChartLook depthlook=N`.
```

Above `static var depth_amt := 0.9`:

```text
How strong look 3 is, both of its parts alike: 0 none, 1 both in full.
0.9, Jon's pick from four levels (2026-10-04: "let's do 0.9. That looks
great"). `-- sheet=ChartLook depthamt=A`.
```

Above `static var volume_look := 3`:

```text
THE DISC AS A VOLUME, while Jon picks ("I want the actual arms of the
galaxy and the galaxy itself to have a height", `chart_field`'s `vol_h`):
0 flat, as it is; 1 a thin slab; 2 medium; 3 tall billows.
3, Jon's pick (2026-10-04: "I like 3"). `-- sheet=ChartLook volume=N`.
```

Above `static var gas_look := 3`:

```text
AND AS GAS, while Jon picks ("too solid?", `chart_field`'s `gas_k`): 0 the
solid surface, as it is; 1 thin gas; 2 puffy gas; 3 dense puffy gas.
3 for now, the billowing column of the pick page, for Jon to try in game.
`-- sheet=ChartLook gas=N`.
```

Above `static var gas_billow := true`:

```text
Whether the gas churns ("billow slightly and move", Jon): its puffs swell
and lean, its wisps drift, slowly, each region on its own phase; still when
reduced motion is on. On, for Jon to try in game. `-- sheet=ChartLook billow`.
```

Above `static var cluster_look := 1`:

```text
THE GLOBULAR CLUSTERS ("these pixelated clusters of stars ... look like
popcorn", Jon): 1, each a soft warm glow, brightest in the middle, a couple
of its stars seen at its edge only when you are close; 0 as they were, every
star a block. `-- sheet=ChartLook clusters=N`.
```

## One plane for all

Inside `eff_of()`, above `return TILT`:

```text
EVERY GALAXY, the ball-shaped ones too ("why does this galaxy not look
edge on? ... In the main menu it looks at the proper angle", Jon): an
elliptical, a dwarf or a merger kept most of its own roundness, up to
0.88, and read as seen face-on -- and its clouds were drawn at that
roundness while its systems lay at TILT, so a pulsar sat up to 62 px off
the middle of its own remnant. One plane for all of it now; a ball keeps
a little of its roundness only in its middle (`params`, `bsq`).
```

## Hole climb limit

Inside `params()`, above `p["rb"] = rin_p * 1.05`:

```text
The climb: nothing past the hole's own edge. It once ran out to the
innermost ring, and the bulge's stars and gas whirled round the hole at
hundreds of times the disc's turn, which is most of what read as "still
rotating too fast". Only the accretion disc spins now, at its own speed
(`chart_hole`), and the gas just outside it (the swirl).
```

## Hole size

Above `static func hole_r(p: Dictionary, z: float) -> float:`:

```text
THE HOLE, BIGGER than the old chart's: 2x the galaxy's own at every zoom,
held under a fifth of the bulge. One scale, so it grows exactly as the map
does: it used to ease from 2.6x at the opening view to 1.3x at the closest,
so zooming in it grew more slowly than the disc and bulge round it and
read as shrinking ("the black hole seems to shrink when you zoom in",
Jon). `z` is screen pixels a bake pixel; the answer is in screen pixels.
```

## Palette stage

Above `const HELD_MERGED := 100`:

```text
Stage four: the palette. The one the chart holds at every zoom is worked out
here, so the chart never opens on the wrong colours, and with it the same
palette with its near twins merged (`HELD_MERGED`, for the zooms in, where a
colour a few steps from its neighbour flickers as the zoom moves). The title
screen's galaxy, which never zooms, and tuning (`diag` 8) keep the old palette
a zoom level, the others' worked out on other threads.
```

## One palette

Above `func _held_level() -> int:`:

```text
THE ONE PALETTE (Oct 11, Jon: the zoom "still changes a little"): the chart
holds the opening view's palette at every zoom. A palette a zoom level used to
be cut from that level's window round the centre, so deep in the arms took the
nearest of the core's colours and leaned purple and teal. The opening's is cut
from the whole galaxy, and the field keeps its light at every zoom, so its
colours are the ones every patch already has. (The title screen's galaxy, seen
at a zoom of its own, holds the palette of that zoom.)
```

## Palette of one zoom

Above `func _bulge_box(li: int) -> Rect2i:`:

```text
THE PALETTE OF ONE ZOOM, from its probe (the mockup's `buildPalette`): a
median cut of the zoom's picture with the galaxy's bright stars in it, more
from its vivid colours and more again from its rare hues, so a small patch
of pink gas is not averaged away; then the void, the hole's colours and the
extra stars' sets. The cuts are the sector map's (`SystemPalette`).
The bulge in a zoom level's probe: the probe is that zoom's window round
the centre, four pixels to one.
```

## Palette near twins

Above `static var pal_merge := 26.0`:

```text
THE PALETTE'S NEAR TWINS GO (the zoom's flicker): two colours a few steps
apart are a flip each time a block's light wavers across the line between
them as the zoom moves -- measured on the grand design's slow zoom at the
hole, most of the blocks flipping back went between two near-identical
browns. A colour within `pal_merge` (the palette lookup's own weighted
distance, 0-255) of one already kept is dropped; the cut's order puts its
commonest colours first, so they are the ones kept. Only from the zooms in:
at the opening view a zoom moves the picture little, and the old look's
full palette is kept (`_merge_of`).
```

## Grain or flicker

Above `const KEEP_OLD_GRAIN := false`:

```text
THE GRAIN, OR THE FLICKER (Jon's call): false keeps the guards against the
zoom's flicker (`chart_l_field`'s band-limited noise and soft 2-block star
grain, the palette's near twins merged and its dither kept to smooth slopes;
every slow zoom measured under 0.0035 of the blocks flipping back); true draws
the old grain exactly as before -- 1-block hard star specks, every octave, the
full palette dithered everywhere -- which flickered (0.0146 on a slow zoom at
the core, 0.0172 at the hole). One line.
```

## Zoom only magnifies

Inside `_feed_field()`, above `var zfd := minf(zf, 1.0 / LEVELS[0]) if diag & 4 else zf`:

```text
ZOOMING ONLY MAGNIFIES (Oct 11): what changed the field's light with the zoom
-- its stars' light "resolving" away (to a third by zoom 6), the gas thinning
(`res2`), the light dimmed and its contrast pushed deep in (`dz`), the ring of
dimming round the hole (`zoom_dim`), the nucleus's own glow coming up from
zoom 1.3 and the bulge's profile sharpening (`zf`), its exposure easing back
deep in, the nuclear dust thickening -- is held at the opening zoom's values.
Only detail is added as you zoom: the finer octaves (`oct`) and the grain
(`det_k`).
```

## Zoom hold

Inside `_push()`, above `var exact: Vector2 = chart.size * 0.5 + chart.pan`:

```text
THE ZOOM'S HOLD, as SIMPLIFIED's (`ChartSky._push`): the blocks are
anchored to the galaxy's centre on a whole pixel, and during a zoom off the
centre that whole pixel re-rounds every frame, jittering the picture by up
to half a block. So while the zoom changes, and for about a second after,
the picture is worked out about the exact centre on a grid held still on
the screen, its dither held with it; then it settles onto the snapped grid
over two frames.
```

Inside `_push()`, above `var panned := chart.pan != _last_pan`:

```text
THE HOLD LETS GO ON A PAN, NOT ON A CLOCK (SIMPLIFIED's rule, `ChartSky._push`;
Oct 10 polish): let go a second after a zoom stopped, the block grid went
over from the screen's anchor to the galaxy centre's, and where the two
differed by a pixel the whole picture jumped a pixel with nothing moving --
a pop a second after every zoom. Held until the view is dragged, the jump
lands inside a move -- on its first frame (held while dragged, the grid stays
on the screen and the galaxy slides under it, every block worked out afresh:
the first second of every pan after a zoom shimmered).
```

## Solid look

Inside `_push()`, above `var sol := false`:

```text
THE SOLID LOOK (`ChartSky.solid`, LEGACY's line in `SOLID_STYLES`): the camera
stepped once a frame by the sky (`solid_frame`), its uniforms on the field, the
stars and the hole. The field takes the include's contract in LEGACY's units
(`chart_l_field`'s solid section): screen px a gu now, the turn, the lanes, and
LEGACY's own two solid fields. The hole is drawn about the core's place on the
screen (`pc`) at the camera's scale there (`kc`).
```

## Ball in this style

Above `static func ball_kind(ball: Vector4) -> Vector4:`:

```text
A BALL IN THIS STYLE'S HAND (Nov 5, direction A, Jon: "This could also be applied
for the other art styles"). A ball galaxy (`ChartSky.form_of` 1) was drawn as a
lenticular of the disc's blue gas: its light from the chart's own points, blue as a
disc's, a hard-edged warm plate where its core's points ended, the disc's puffs over
all of it. Now its body is the bulge's own light (`chart_l_bake_base`'s `ball_light`):
the bulge's amber-to-gold climb, at the ball's own size and profile, grained by its
points as the bulge is, fading out into the dark; cool gas past the warm light only
where the kind has gas (the blue compact dwarf, the merger's remnant and its stream),
and the disc's puffs over it only as much as the kind has gas (`ball_gas`).
(look, how far out the warm light holds in ball radii, how lumpy 0..1, how irregular
its outline 0..1): an old elliptical warm to its edge; a blue compact dwarf blue and
lumpy round a small warm heart; a dwarf spheroidal faint, grey and smooth; a merger's
remnant warm, lopsided, its stream off one side.
```

## Ball body

Above `static func ball_form(kind: int) -> Vector4:`:

```text
A BALL'S BODY (`ball_light`'s `ball_f`): (its size against its ball radius, how steeply
its light falls (the power of its profile), where its light ends (ball radii), its
halo of globular clusters 0..1) -- PAINTED's (`ChartPainted.ball_form`): a round
elliptical the plain profile; a flattened one squashed further and steep, a lens; a
giant bigger, falling slowly into a wide envelope, ringed by globular clusters.
LEGACY's own, a blue compact dwarf's fall gentler (1.0): this style's palette drops its
faintest light to the void, and at PAINTED's 1.3 its gas ended at 0.14 gu below its core
while its story's satellites stood to 0.19 above (BallHaloTest x0.74).
```
