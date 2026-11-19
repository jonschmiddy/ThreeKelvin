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
fill of that colour at FILL_A (m, the flask's liquid), and accents from UITheme (I ice for a
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
