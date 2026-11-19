# ChartGlyphs

## The icons

Above `class_name ChartGlyphs`:

```text
THE STAR CHART IN THE SECTOR'S STYLE (Jon, Nov 18). After the sector beacons were
redrawn as 11 px pictures (MapGlyphs), the chart was redrawn to match, from a pick
page of two ideas per icon. His reply: "start:B station:A pulsar:A core:A quest:A
hellbender:B you:A party:A".

  start       B  a flag planted: where the run began
  station     A  the sector's DOCK, an arrow into a bay
  pulsar      A  a spinning star throwing two beams, its middle open
  core        A  the sector's black hole in its ring (MapGlyphs &"core", shared)
  quest       A  the sector's map pin (MapGlyphs &"quest", shared), standing on its star
  hellbender  B  a skull with burning eyes: danger must be obvious at a glance
  you         A  the old corner brackets drawn thick, a hot pixel at each corner
  party       A  the old diamond drawn thick, the star showing inside

PLAIN SYSTEMS STAY DOTS, at every zoom and in the in-range list. They are most of the
chart, and a quiet field is what lets the few places that matter stand out. Before
this, zoomed in, every system wore a 13 px burst, and stations and pulsars were only
dots at the opening zoom.

One source per picture wherever the size allows: the pin and the black hole are
MapGlyphs' own 11 px grids. The bay is MapGlyphs &"dock" redrawn at 9 and 7, because
the 11 px dock does not fit the chart's spacing.

The style is MapGlyphs': a 1 px outline in the mark's colour, a fill of it at
FILL_A, ice, hot and chill accents. FILL_A is shared, so the chart took the sector's
heavier fill (0.47 to 0.7, Nov 18, for the CRT look) with it: the chart is seen
through the same tube, and the pick page Jon chose from had the lighter fill. Node icons are tinted as the old glyphs were
(`MapGen.star_colour`, lightened near you and darkened far), and the ink is then
lifted by LIFT, as the old glyph's body ink was (`ramp_for`'s '#'). Unlifted, a far
station on a red star went a muddy brown. A star in reach that is TOO DEEP is drawn
flat in `Glyph.DIM`, its accents grey too, as ruling 13 A has it.

Every mark keeps a void rim on its four sides, in MapChart's `_UNDER` key, which
`chart_marks.gdshader` darkens only over bright sky.
```

## Sizes

Above `const BIG := 9`:

```text
MEASURED, seed 777, mid-run on layer 7 (Nov 18): the nearest neighbour of each
system drawn on the chart.

  opening zoom (0.42)          min 6.0 px, median 10.7
  LOCAL REGION zoom (1.3-1.6)  min 19-21 px, median 28-33
  zoom 0.78 (glyphs begin)     about 11 px min, scaled from the above

At 0.78, the zoom where the chart stops drawing dots, 11 px icons would touch and 9 px
leave a 2 px gap. So stations, pulsars and the start are 9 zoomed in. At the opening
zoom they are 7, the most that fits between two systems 6 px apart: two
specials that close overlap by a pixel, and against a dot neighbour about 1.5 px
stays clear. The core is always the sector's 11, alone on its hole. The quest pin and
the hellbender are 11 (the old marks were 13 to 14), and a partner is 9.

YOU's brackets are 19 px zoomed in and 23 zoomed out. That is the old marks' size
plus the thicker stroke, round a 9 or 7 px icon and its nearest neighbours.
```

## Ink

Above `const NEAR_LIFT := 0.12`:

```text
Jon, Nov 18, in play: "The star chart icons in game are kinda... dull? Is it the same
CRT issue?" Mostly it was not the tube. Measured as MapGlyphs' "Ink for the tube"
measures: stroke contrast is the brightest quarter of a mark's box minus the median of a
ring 3 to 6 px outside it. Flat frames came from the game, and the default CRT look was
applied by crtfix's numpy copy of screen_filter at 2x. Seed 777, mid-run on layer 7,
LOCAL REGION (zoom 1.31) and the opening view (0.42). Values are flat / CRT, medians.

  what it cost a station you can no longer see (most of a mid-run chart's stations)
    the unseen darken (x0.45 before the icon's own)   region +42/+43, opening +14/+14
    the far darken (0.2 zoomed in, 0.35 out)          region +20/+22, opening +21/+19
    a red star's tint (ink #846a67 against #87898c)   -26 on the ink, the brown ones
    ChartGlyphs.LIFT 0.34 (it was helping)            without it -37/-41, the core -34/-26
    the _UNDER rim (sky-conditional)                  0 to 7 either way: not a cause
    the tube, mid-chart                               none: the look's gain lifts strokes
    the tube, on the KEY strip                        -25 to -30%: START 210 -> 144

So the floor moved, not the meaning. Near: the star's colour lightened by NEAR_LIFT.
Far: darkened by FAR_DIM (0.12), and out of sight a further UNSEEN_DIM (0.25), so quieter
still reads quieter. No ink goes below FLOOR_V (HSV value 0.7), which keeps the hue: a
red star's station stays red, not brown. Then the ink is boosted as the sector's beacons
are (`MapGlyphs.boost`), with NODE_LIFT 0.3, close to the old glyph body's 0.34; the
sector's 0.15 alone left a red core dimmer than before. Markers (pin, skull, diamond,
YOU) take the sector's own boost. The KEY takes KEY_LIFT for the vignette, as the
sector's KEY does. A spent place is SPENT, a flat grey and never boosted, as the
sector's spent beacon is. The plain-system dot is unchanged.

                        mock      before    after (flat / CRT, medians)
  station, unseen       116/129   116/129   181/186   (region)
                        123/143   123/143   152/184   (opening; worst one 67 -> 101)
  station, near         170/196   170/196   184/199
  pulsar, near          209/221   209/223   225/228
  core (opening)         54/80     54/81     64/87
  quest pin             139/157   139/160   171/177
  hellbender            128/133   127/135   154/162
  partner               122/148   123/150   163/176
  KEY start / core      210/143   210/144   225/154 / 165/131
Every mark measures at or above the mockup Jon picked from.
```
