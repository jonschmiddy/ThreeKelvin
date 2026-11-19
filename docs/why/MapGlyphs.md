The reasoning behind `tkg/scripts/ui/sysmap/MapGlyphs.gd`; each heading is referenced from the code by a `Why:` line.

## The glyphs

Above `class_name MapGlyphs`, and `SystemOverlay.GLYPH`:

```text
Jon, Nov 18: the map's beacon icons redrawn in the style of the science flask he picked for
science sites ("the most science of the batch", "sooo cute"), then "Let's do it now": every
glyph, not just science. Four rounds of pick pages (scratchpad map_icons/), each idea drawn
at game size on real stills:
  fight     a gunsight             (round 1 A)    signal    three bars rising (round 1 A,
  contract  a page, corner folded  (round 1 A)              the old science bars, in signal blue)
  dock      an arrow into a bay    (round 1 A)    science   a sample flask (the first page, A)
  hazard    the radiation trefoil  (round 2 A)    quest     a map pin (round 2 B)
  core      a black hole, its ring (round 2 A)    salvage   a gear (round 4 B)
  harvest   four arrows pulling in (round 4 C)
Passed over: crossed swords, a warning triangle, a bolt, stripes, a blast (hazard); a crate, a
wrench, a claw, a magnet, a wreck, debris, a spilled pod, a torn plate (salvage); a flag, a
star, a ! diamond, a compass (quest); a scoop, a drop, a fuel cell, a gauge, the pulsar, a
siphon, a tank, field lines, a dish, a jerrycan, a bolt, a magnet with sparks (harvest); an
eye, a skull, a crown, a spiral (core). A wrench over a gear was tried and dropped: at 11 px
the gear broke up under it.

The old glyphs were 5x5 one-colour patterns drawn in 2 px cells (10 px). The new ones are
11x11 pictures drawn 1:1 in game pixels: a 1 px outline in the beacon's own colour (M), a
fill of that colour at FILL_A (m, the flask's liquid; 0.47 at first, 0.7 since the tube fix below), and accents from UITheme (I ice for a
glint, H hot for a light, C chill for the dock's pad). The beacon's colour is still
`beacon_look`'s, so a dimmed beacon (0.42, not here) and a rival (0.35) dim the accents with
it; a spent beacon is drawn flat in SPENT's grey, accents and all.

String grids in GDScript, as `LabIcons` and `QuestLog` keep theirs: no PNG to import, and the
key check (`SystemShot._key_check`) reads the same table to prove every entry has its own.
The centre stays the beacon's point: an 11 px glyph spans at-5..at+5 where the 10 px one
spanned at-4..at+5, so the stem (from at+7) and the pulse ring (from 6 px out) are unchanged,
and `beacon_box` is the 11 px square.
```

## The key

Above `KeyGlyph._draw`:

```text
The KEY under the map draws the same pictures (Jon, Nov 18), in the same order and colours
(`SystemMapScreen.KEY`, `key_colour`). The 12 px box is unchanged; the picture sits one row
down in it, so its middle row is the words' caps' middle, as the 10 px glyph's was at
offset 1. The BODY marks and the badges' ticks stay the 5x5 marks: they are not beacons.
SCIENCE is the flask (science-tagged encounters wear it until science sites exist), SIGNAL
the bars in signal blue.
```

## One icon, one thing

Above `QuestLog.MAP_MARK`:

```text
The quest log's fetch and hunt marks were copies of the map's QUEST cross and FIGHT diamond.
Copies drift, so they read MapGlyphs now: fetch the QUEST pin, hunt the FIGHT sight. The
event quest's box and the heat stack were never map glyphs and stay. The star chart draws
its own marks and is not changed here.
```

## Ink for the tube

Above `const INK_V := 1.25`:

```text
Jon, Nov 18: "Can we fix the CRT issue?" Through the default look (CRT, `screen_filter`: curve
0.03, scanlines 0.14 on every other game row, vignette 0.55, gain about 1.39, a knee at 0.85)
a 1 px stroke loses more than the old 2 px cells did: wherever the curve slides a pixel
boundary under a screen pixel, `sharp_uv` blends that pixel half into the sky beside it, and a
1 px line has no inside to keep. Measured on the KEY strip as stroke contrast (the brightest
quarter of the glyph's box minus the median of the strip round it), a numpy copy of the
shader matching the real CRT capture to within 2 to 5 levels:
                fight hazard salvage science signal contract quest dock
  flat, first ink   93   120     145     135     170    154     164   188
  CRT, first ink    60    78     110      97     143    121     128   165
  CRT, old glyphs   56    86     113     106     135    123     140   177  (emulated)
  CRT, this ink     93   107     153     133     174    157     168   191
  (the KEY's own words lose 30% through the tube there: FIGHT's 84 flat, 59 in CRT)
  On the pulsar's map, dimmed beacons, stroke against the sky / against its own box:
  harvest on the beam 64/78 -> 78/105, gear 65/63 -> 87/86, sight 39/44 -> 55/69,
  trefoil 58/49 -> 69/62 (CRT); flat before 71/64, 47/47, 55/46 for gear, sight, trefoil.
  Hazard is the one KEY glyph still under its flat number: orange has little light to give.
So the main colour is drawn brighter, the hue kept: value x INK_V, then INK_LIFT toward
white (KEY_LIFT on the KEY strip, low on the screen where the vignette takes most) (a spent beacon, drawn flat in SPENT's grey, is not lifted, so it stays dim); the fill
(m) is FILL_A 0.7, not 0.47; and a map beacon stands on a 1 px dark rim (the edge arrows' own
dark, at RIM_A), which is what keeps HARVEST readable on the pulsar's beam. The KEY strip and
the quest log sit on flat dark plates and take no rim. The same ink in every look: the flat
look's icons come out lighter but not loud (checked at 2x), and a per-look ink would leave the
KEY, which redraws only when built, a step behind a change in Settings.
An aside on the evidence: stills filmed with --write-movie through render.sh came out
softer again than the game (a DockFilm frame's sharpest edges about half a root capture's), so
the tube is judged on root-texture captures (MapFlyShot) and the shader's own maths.
```
